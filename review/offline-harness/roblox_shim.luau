--[[
	roblox_shim.luau (offline review harness, NOT part of the game)

	Just enough of the Roblox engine to load Emberbound's server ModuleScripts in
	the plain Luau CLI: an Instance tree built from src/ paths, game:GetService,
	WaitForChild, require(ModuleScript), RemoteEvents, Players signals and a
	controllable os.clock. Deliberate differences from the real engine:
	  - signals and remotes run handlers immediately and synchronously
	    (Roblox may defer them); handler errors are caught and recorded
	  - WaitForChild never yields: it returns the child, nil after a timeout,
	    or errors when no timeout is given
	  - os.clock() is a fake clock advanced by the entry script
	  - Random is a seeded LCG: same API, different sequence than the engine
	  - the math library is the Luau CLI's, not the Roblox server's
	  - Milestone 3: task.spawn/defer run the callback at once; task.wait never
	    yields, it only advances the fake clock; task.delay timers fire from
	    Shim.advanceClock; os.time follows the fake clock. DataStoreService is an
	    in-memory fake with injectable failures. HttpService's JSON functions
	    deep-copy instead of producing text. BindToClose handlers run from
	    Shim.closeServer. Player:Kick only records the message.
]]

local Shim = {}

local warnings = {}
local handlerErrors = {}

local function shimWarn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local text = table.concat(parts, " ")
	table.insert(warnings, text)
	print("[warn] " .. text)
end

-- Signals ---------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

local function newSignal(label)
	return setmetatable({ label = label, handlers = {} }, Signal)
end

function Signal:Connect(handler)
	table.insert(self.handlers, handler)
	local handlers = self.handlers
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self.handlers) do
		local ok, problem = pcall(handler, ...)
		if not ok then
			table.insert(handlerErrors, `{self.label}: {problem}`)
			print(`[handler error] {self.label}: {problem}`)
		end
	end
end

-- Instances -------------------------------------------------------------

local Instance = {}
Instance.__index = Instance

local function newInstance(className, name, parent)
	local self = setmetatable({ ClassName = className, Name = name, Parent = nil, _children = {} }, Instance)
	if parent then
		self.Parent = parent
		table.insert(parent._children, self)
	end
	return self
end

function Instance:GetFullName()
	if self.Parent == nil or self.Parent.ClassName == "DataModel" then
		return self.Name
	end
	return self.Parent:GetFullName() .. "." .. self.Name
end

function Instance:FindFirstChild(name)
	for _, child in self._children do
		if child.Name == name and child.Parent == self then
			return child
		end
	end
	return nil
end

function Instance:WaitForChild(name, timeout)
	local child = self:FindFirstChild(name)
	if child == nil and timeout == nil then
		error(`Infinite yield: {self:GetFullName()}.{name} does not exist`, 2)
	end
	return child
end

function Instance:GetChildren()
	local result = {}
	for _, child in self._children do
		if child.Parent == self then
			table.insert(result, child)
		end
	end
	return result
end

function Instance:IsA(className)
	return className == "Instance" or self.ClassName == className
end

function Instance:Remove()
	if self.Parent then
		local siblings = self.Parent._children
		local index = table.find(siblings, self)
		if index then
			table.remove(siblings, index)
		end
	end
	self.Parent = nil
end

-- DataModel -------------------------------------------------------------

local game = newInstance("DataModel", "Game", nil)
local services = {}

local function addService(className)
	local service = newInstance(className, className, game)
	services[className] = service
	return service
end

function game:GetService(className)
	local service = services[className]
	if service == nil then
		error(`roblox_shim: service {className} is not emulated`, 2)
	end
	return service
end

local ReplicatedStorage = addService("ReplicatedStorage")
addService("ServerScriptService")
addService("StarterPlayer")

local RunService = addService("RunService")
local isStudio = true
function RunService:IsStudio()
	return isStudio
end
function Shim.setStudio(value)
	isStudio = value
end

-- Milestone 3 persistence ---------------------------------------------------

game.PlaceId = 0
game.JobId = "shim-job"
local closeHandlers = {}
function game:BindToClose(handler)
	table.insert(closeHandlers, handler)
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		assert(type(key) == "string", "roblox_shim: stored tables may only have string keys")
		copy[key] = deepCopy(item)
	end
	return copy
end

local HttpService = addService("HttpService")
local guidCount = 0
local jsonValues = {}
function HttpService:GenerateGUID(_wrap)
	guidCount += 1
	return string.format("guid-%04d", guidCount)
end
function HttpService:JSONEncode(value)
	table.insert(jsonValues, deepCopy(value))
	return `json#{#jsonValues}`
end
function HttpService:JSONDecode(text)
	local index = tonumber(string.match(text, "^json#(%d+)$"))
	assert(index and jsonValues[index] ~= nil, "roblox_shim: JSONDecode of text that JSONEncode did not produce")
	return deepCopy(jsonValues[index])
end

local DataStoreService = addService("DataStoreService")
local dataStores = {}
local storeFaults = { failNext = 0, calls = 0 }
local function storeCall(operation)
	storeFaults.calls += 1
	if storeFaults.failNext > 0 then
		storeFaults.failNext -= 1
		error(`roblox_shim DataStore: injected {operation} failure`, 0)
	end
end
function DataStoreService:GetDataStore(name)
	if dataStores[name] then
		return dataStores[name]
	end
	local store = { name = name, records = {}, userIds = {} }
	function store:GetAsync(key)
		storeCall("GetAsync")
		return deepCopy(self.records[key])
	end
	function store:UpdateAsync(key, transform)
		storeCall("UpdateAsync")
		local hook = storeFaults.beforeUpdate
		if hook then
			storeFaults.beforeUpdate = nil
			hook(key)
		end
		local new, userIds = transform(deepCopy(self.records[key]), nil)
		if new ~= nil then
			self.records[key] = deepCopy(new)
			self.userIds[key] = userIds
		end
		return deepCopy(self.records[key])
	end
	dataStores[name] = store
	return store
end
Shim.dataStores = dataStores
Shim.storeFaults = storeFaults
Shim.deepCopy = deepCopy

function Shim.closeServer()
	for _, handler in closeHandlers do
		local ok, problem = pcall(handler)
		if not ok then
			table.insert(handlerErrors, `BindToClose: {problem}`)
			print(`[handler error] BindToClose: {problem}`)
		end
	end
end
function RunService:IsServer()
	return true
end

local Players = addService("Players")
Players.CharacterAutoLoads = false
Players.PlayerAdded = newSignal("Players.PlayerAdded")
Players.PlayerRemoving = newSignal("Players.PlayerRemoving")
function Players:GetPlayers()
	local result = {}
	for _, child in self:GetChildren() do
		if child.ClassName == "Player" then
			table.insert(result, child)
		end
	end
	return result
end

-- Remotes (as the Milestone 2 setup guide creates them in ReplicatedStorage.Remotes)
local remotesFolder = newInstance("Folder", "Remotes", ReplicatedStorage)
for _, remoteName in { "RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate" } do
	local remote = newInstance("RemoteEvent", remoteName, remotesFolder)
	remote.OnServerEvent = newSignal(`{remoteName}.OnServerEvent`)
	function remote:FireClient(player, payload)
		assert(player and player.ClassName == "Player", `{remoteName}:FireClient needs a Player`)
		table.insert(player.Inbox, { remote = remoteName, payload = payload })
	end
	function remote:FireAllClients()
		error(`{remoteName}:FireAllClients must never be used (updates are per player)`)
	end
end

-- Script tree from src/ paths ---------------------------------------------

local SCRIPT_CLASSES = {
	["ServerScriptService/ServerInit"] = "Script",
	["ServerScriptService/Tests/TestRunner"] = "Script",
}

local function ensurePath(segments, lastIndex)
	local node = game:GetService(segments[1])
	for i = 2, lastIndex do
		node = node:FindFirstChild(segments[i]) or newInstance("Folder", segments[i], node)
	end
	return node
end

local keys = {}
for key in SOURCES do
	table.insert(keys, key)
end
table.sort(keys)
for _, key in keys do
	-- Baseline copies (M1/..., AUDITED/...) stay out of the tree; Shim.loadDetached loads them.
	if services[string.split(key, "/")[1]] ~= nil then
		local segments = string.split(key, "/")
		local parent = ensurePath(segments, #segments - 1)
		local scriptInstance = newInstance(SCRIPT_CLASSES[key] or "ModuleScript", segments[#segments], parent)
		scriptInstance._key = key
	end
end

-- Random: deterministic stand-in (a 32-bit LCG). It is seeded like Roblox's
-- Random but produces a DIFFERENT sequence than the engine's generator.
local Random = {}
Random.__index = Random

function Random.new(seed)
	return setmetatable({ state = math.floor(seed or 0) % 4294967296 }, Random)
end

function Random:_next()
	self.state = (self.state * 1664525 + 1013904223) % 4294967296
	return self.state / 4294967296
end

function Random:NextInteger(min, max)
	return min + math.floor(self:_next() * (max - min + 1))
end

function Random:NextNumber(min, max)
	min = min or 0
	max = max or 1
	return min + self:_next() * (max - min)
end

-- Loader -------------------------------------------------------------------

local clockNow = 1000
local fakeOs = setmetatable({
	clock = function()
		return clockNow
	end,
	time = function()
		return 1700000000 + math.floor(clockNow)
	end,
}, { __index = os })

local timers = {}
local function runTask(label, callback, ...)
	local ok, problem = pcall(callback, ...)
	if not ok then
		table.insert(handlerErrors, `{label}: {problem}`)
		print(`[handler error] {label}: {problem}`)
	end
end
local fakeTask = {
	spawn = function(callback, ...)
		runTask("task.spawn", callback, ...)
	end,
	defer = function(callback, ...)
		runTask("task.defer", callback, ...)
	end,
	wait = function(seconds)
		clockNow += seconds or 0
		return seconds or 0
	end,
	delay = function(seconds, callback, ...)
		table.insert(timers, { at = clockNow + (seconds or 0), callback = callback, args = { n = select("#", ...), ... } })
	end,
}

local baseEnv = getfenv(1)
local moduleCache = {}
local loading = {}

local robloxRequire

local function runChunk(source, chunkName, scriptInstance)
	local chunk, compileError = loadstring(source, "=" .. chunkName)
	if chunk == nil then
		error(compileError, 0)
	end
	setfenv(chunk, setmetatable({
		script = scriptInstance,
		game = game,
		require = robloxRequire,
		warn = shimWarn,
		os = fakeOs,
		task = fakeTask,
		Random = Random,
	}, { __index = baseEnv }))
	return chunk()
end

function robloxRequire(moduleScript)
	if type(moduleScript) ~= "table" or moduleScript.ClassName ~= "ModuleScript" then
		error("require expects a ModuleScript", 2)
	end
	local cached = moduleCache[moduleScript]
	if cached ~= nil then
		return cached
	end
	assert(not loading[moduleScript], `cyclic require of {moduleScript:GetFullName()}`)
	loading[moduleScript] = true
	local result = runChunk(SOURCES[moduleScript._key], moduleScript._key .. ".luau", moduleScript)
	loading[moduleScript] = nil
	moduleCache[moduleScript] = result
	return result
end

-- Public helpers for the entry scripts ------------------------------------

function Shim.find(path)
	local segments = string.split(path, "/")
	return ensurePath(segments, #segments - 1):WaitForChild(segments[#segments])
end

function Shim.require(path)
	return robloxRequire(Shim.find(path))
end

function Shim.runScript(path)
	local scriptInstance = Shim.find(path)
	assert(scriptInstance.ClassName == "Script", `{path} is not a Script`)
	runChunk(SOURCES[scriptInstance._key], scriptInstance._key .. ".luau", scriptInstance)
end

-- Loads a source that is not part of the tree (the Milestone 1 baseline) in isolation.
function Shim.loadDetached(key)
	local source = SOURCES[key]
	if source == nil then
		return nil
	end
	local detachedScript = newInstance("ModuleScript", key, newInstance("Folder", "Detached", nil))
	return runChunk(source, key .. ".luau", detachedScript)
end

-- Adds a script with the given source to the tree after start-up (fault-injection probes).
function Shim.addSource(path, className, source)
	SOURCES[path] = source
	local segments = string.split(path, "/")
	local scriptInstance = newInstance(className, segments[#segments], ensurePath(segments, #segments - 1))
	scriptInstance._key = path
	return scriptInstance
end

--[[
	Independent check of a TestRunner run, so the harness never trusts the
	runner's own verdict alone: the last [Tests] line must be "ALL PASSED", no
	line may report a failure, and every expected suite must report its count.
	Returns (ok, problems).
]]
function Shim.checkTestRun(lines, expectedSuites)
	local problems = {}
	local testLines = {}
	for _, line in lines do
		local text = string.gsub(line, "^%[warn%] ", "")
		if string.sub(text, 1, 7) == "[Tests]" then
			table.insert(testLines, text)
			if string.find(text, "FAIL", 1, true) then
				table.insert(problems, text)
			end
		end
	end
	local last = testLines[#testLines]
	if last == nil or not string.find(last, "^%[Tests%] ALL PASSED %(%d+ tests%)$") then
		table.insert(problems, `final verdict was {last or "missing"}`)
	end
	for _, suiteName in expectedSuites do
		local reported = false
		for _, text in testLines do
			if string.find(text, `[Tests] {suiteName}: `, 1, true) then
				reported = true
			end
		end
		if not reported then
			table.insert(problems, `{suiteName} never reported (did it load?)`)
		end
	end
	return #problems == 0, problems
end

-- Names of the shipped test suites: every ServerScriptService/Tests module ending in "Tests".
function Shim.expectedSuites()
	local names = {}
	for key in SOURCES do
		local name = string.match(key, "^ServerScriptService/Tests/(%w+Tests)$")
		if name then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

-- Runs a Script and returns every line it printed or warned.
function Shim.captureScript(path)
	local lines = {}
	local realPrint = print
	local env = getfenv(1)
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		table.insert(lines, table.concat(parts, " "))
	end
	local ok, problem = pcall(Shim.runScript, path)
	env.print = realPrint
	if not ok then
		table.insert(lines, `[script error] {problem}`)
	end
	return lines
end

-- The fake os.time() the game code sees.
function Shim.time()
	return fakeOs.time()
end

-- Advances the fake clock and runs every task.delay timer that is now due, earliest first.
function Shim.advanceClock(seconds)
	clockNow += seconds
	while true do
		local nextIndex = nil
		for index, timer in timers do
			if timer.at <= clockNow and (nextIndex == nil or timer.at < timers[nextIndex].at) then
				nextIndex = index
			end
		end
		if nextIndex == nil then
			break
		end
		local timer = table.remove(timers, nextIndex)
		runTask("task.delay", timer.callback, table.unpack(timer.args, 1, timer.args.n))
	end
end

local nextUserId = 1000
function Shim.addPlayer(name, userId)
	local player = newInstance("Player", name, Players)
	player.Inbox = {}
	if userId == nil then
		nextUserId += 1
		userId = nextUserId
	end
	player.UserId = userId
	function player:Kick(message)
		self.KickMessage = message or ""
	end
	Players.PlayerAdded:Fire(player)
	return player
end

function Shim.removePlayer(player)
	Players.PlayerRemoving:Fire(player)
	player:Remove()
end

function Shim.fireServer(remoteName, player, ...)
	remotesFolder:WaitForChild(remoteName).OnServerEvent:Fire(player, ...)
end

Shim.game = game
Shim.warnings = warnings
Shim.handlerErrors = handlerErrors
