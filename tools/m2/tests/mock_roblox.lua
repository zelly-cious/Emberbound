--[[
	Minimal fake Roblox engine for testing tools/m2/InstallM2.lua with plain Lua 5.1.
	Review tooling only; NOT part of the game and never installed in Studio.

	It models just what the installer touches: a DataModel with the usual services,
	Instance.new, Name / Parent / ClassName / Source / Enabled / RunContext,
	FindFirstChild, GetChildren, GetDescendants, IsA, Destroy, GetFullName,
	RunService:IsStudio / IsEdit / IsRunning, game.PlaceId and
	Players.CharacterAutoLoads. Unknown properties raise errors like Roblox does.
	Fault hooks let tests make any of these operations fail.
	It does not model Roblox security, replication, undo history or the Command Bar.
]]

local Mock = {}

local CHAINS = {
	DataModel = { "DataModel", "ServiceProvider", "Instance" },
	Folder = { "Folder", "Instance" },
	RemoteEvent = { "RemoteEvent", "Instance" },
	RemoteFunction = { "RemoteFunction", "Instance" },
	ModuleScript = { "ModuleScript", "LuaSourceContainer", "Instance" },
	Script = { "Script", "BaseScript", "LuaSourceContainer", "Instance" },
	LocalScript = { "LocalScript", "Script", "BaseScript", "LuaSourceContainer", "Instance" },
	Part = { "Part", "BasePart", "PVInstance", "Instance" },
	SpawnLocation = { "SpawnLocation", "Part", "BasePart", "PVInstance", "Instance" },
	Camera = { "Camera", "Instance" },
	Terrain = { "Terrain", "BasePart", "PVInstance", "Instance" },
	Workspace = { "Workspace", "WorldRoot", "Model", "PVInstance", "Instance" },
	Players = { "Players", "Instance" },
	RunService = { "RunService", "Instance" },
	Lighting = { "Lighting", "Instance" },
	ReplicatedFirst = { "ReplicatedFirst", "Instance" },
	ReplicatedStorage = { "ReplicatedStorage", "Instance" },
	ServerScriptService = { "ServerScriptService", "Instance" },
	ServerStorage = { "ServerStorage", "Instance" },
	StarterGui = { "StarterGui", "BasePlayerGui", "Instance" },
	StarterPack = { "StarterPack", "Instance" },
	StarterPlayer = { "StarterPlayer", "Instance" },
	StarterPlayerScripts = { "StarterPlayerScripts", "Instance" },
	StarterCharacterScripts = { "StarterCharacterScripts", "StarterPlayerScripts", "Instance" },
	SoundService = { "SoundService", "Instance" },
}

local CREATABLE = { Folder = true, RemoteEvent = true, RemoteFunction = true, ModuleScript = true, Script = true, LocalScript = true, Part = true }

local SERVICES = { "Workspace", "Players", "RunService", "Lighting", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "SoundService" }

local function isA(className, wanted)
	local chain = CHAINS[className]
	if chain == nil then
		return className == wanted
	end
	for _, name in ipairs(chain) do
		if name == wanted then
			return true
		end
	end
	return false
end
Mock.isA = isA

local function enumItem(enumName, itemName)
	return setmetatable({ Name = itemName, EnumType = enumName }, {
		__tostring = function()
			return "Enum." .. enumName .. "." .. itemName
		end,
	})
end

--[[ Creates a fresh world: a Baseplate-like DataModel in Edit mode. ]]
function Mock.newWorld()
	local world = {
		data = {},
		output = {},
		newCount = 0,
		propertySets = 0,
		servicesRequested = {},
		mode = { studio = true, edit = true, running = false, errors = {}, values = {} },
		placeId = 0,
		placeIdError = false,
		faults = {},
	}
	world.Enum = {
		RunContext = {
			Legacy = enumItem("RunContext", "Legacy"),
			Server = enumItem("RunContext", "Server"),
			Client = enumItem("RunContext", "Client"),
		},
	}

	local InstanceMeta = {}

	local function dataOf(proxy)
		local data = world.data[proxy]
		if data == nil then
			error("not a mock Instance", 3)
		end
		return data
	end

	local function fullName(proxy)
		local parts = {}
		local node = proxy
		while node ~= nil and world.data[node].className ~= "DataModel" do
			table.insert(parts, 1, world.data[node].name)
			node = world.data[node].parent
		end
		return table.concat(parts, ".")
	end

	local function detach(proxy)
		local data = world.data[proxy]
		if data.parent ~= nil then
			local siblings = world.data[data.parent].children
			for index, child in ipairs(siblings) do
				if child == proxy then
					table.remove(siblings, index)
					break
				end
			end
			data.parent = nil
		end
	end

	local function destroy(proxy)
		local data = world.data[proxy]
		if data.destroyed then
			return
		end
		if world.faults.destroyFails ~= nil and world.faults.destroyFails(proxy, data) then
			error("mock fault: Destroy failed for " .. data.name, 0)
		end
		local children = {}
		for _, child in ipairs(data.children) do
			children[#children + 1] = child
		end
		for _, child in ipairs(children) do
			destroy(child)
		end
		detach(proxy)
		data.destroyed = true
	end

	local function descendants(proxy, out)
		for _, child in ipairs(world.data[proxy].children) do
			out[#out + 1] = child
			descendants(child, out)
		end
		return out
	end

	local methods = {}
	function methods.FindFirstChild(self, name)
		for _, child in ipairs(dataOf(self).children) do
			if world.data[child].name == name then
				return child
			end
		end
		return nil
	end
	function methods.GetChildren(self)
		local result = {}
		for _, child in ipairs(dataOf(self).children) do
			result[#result + 1] = child
		end
		return result
	end
	function methods.GetDescendants(self)
		dataOf(self)
		return descendants(self, {})
	end
	function methods.IsA(self, className)
		return isA(dataOf(self).className, className)
	end
	function methods.Destroy(self)
		dataOf(self)
		destroy(self)
	end
	function methods.GetFullName(self)
		dataOf(self)
		return fullName(self)
	end
	function methods.GetService(self, name)
		local data = dataOf(self)
		if data.className ~= "DataModel" then
			error("GetService is not a valid member of " .. data.className, 2)
		end
		world.servicesRequested[name] = true
		if world.faults.getServiceFails ~= nil and world.faults.getServiceFails(name) then
			error("mock fault: GetService " .. name, 0)
		end
		local service = world.services[name]
		if service == nil then
			error("'" .. tostring(name) .. "' is not a valid Service name", 2)
		end
		return service
	end
	function methods.IsStudio(self)
		return world.runServiceCall(self, "IsStudio")
	end
	function methods.IsEdit(self)
		return world.runServiceCall(self, "IsEdit")
	end
	function methods.IsRunning(self)
		return world.runServiceCall(self, "IsRunning")
	end

	function world.runServiceCall(self, methodName)
		if dataOf(self).className ~= "RunService" then
			error(methodName .. " is not a valid member", 3)
		end
		if world.mode.errors[methodName] then
			error("mock fault: " .. methodName, 0)
		end
		if world.mode.values[methodName] ~= nil then
			return world.mode.values[methodName]
		end
		if methodName == "IsStudio" then
			return world.mode.studio
		elseif methodName == "IsEdit" then
			return world.mode.edit
		end
		return world.mode.running
	end

	local PROPERTY_OWNERS = {
		Source = "LuaSourceContainer",
		Enabled = "BaseScript",
		RunContext = "Script",
		CharacterAutoLoads = "Players",
		PlaceId = "DataModel",
	}

	InstanceMeta.__index = function(proxy, key)
		local data = dataOf(proxy)
		if key == "Name" then
			return data.name
		elseif key == "ClassName" then
			return data.className
		elseif key == "Parent" then
			return data.parent
		end
		local method = methods[key]
		if method ~= nil then
			return method
		end
		local owner = PROPERTY_OWNERS[key]
		if owner ~= nil and isA(data.className, owner) then
			if key == "PlaceId" then
				if world.placeIdError then
					error("mock fault: PlaceId", 0)
				end
				return world.placeId
			end
			if world.faults.onGet ~= nil then
				local replaced, value = world.faults.onGet(proxy, data, key)
				if replaced then
					return value
				end
			end
			return data.props[key]
		end
		error(tostring(key) .. " is not a valid member of " .. data.className .. " \"" .. data.name .. "\"", 2)
	end

	InstanceMeta.__newindex = function(proxy, key, value)
		local data = dataOf(proxy)
		world.propertySets = world.propertySets + 1
		if not data.created then
			world.preexistingSets = (world.preexistingSets or 0) + 1
		end
		if world.faults.onSet ~= nil then
			world.faults.onSet(proxy, data, key, value)
		end
		if key == "Name" then
			if type(value) ~= "string" then
				error("Name must be a string", 2)
			end
			data.name = value
			return
		elseif key == "Parent" then
			if data.destroyed then
				error("The Parent property of " .. data.name .. " is locked", 2)
			end
			if value ~= nil and world.data[value] == nil then
				error("Parent must be an Instance", 2)
			end
			detach(proxy)
			if value ~= nil then
				data.parent = value
				local siblings = world.data[value].children
				siblings[#siblings + 1] = proxy
			end
			return
		elseif key == "ClassName" then
			error("ClassName is read-only", 2)
		end
		local owner = PROPERTY_OWNERS[key]
		if owner == nil or key == "PlaceId" or not isA(data.className, owner) then
			error(tostring(key) .. " is not a valid member of " .. data.className, 2)
		end
		if key == "Source" then
			if type(value) ~= "string" then
				error("Source must be a string", 2)
			end
			if world.faults.transformSource ~= nil then
				value = world.faults.transformSource(data, value)
			end
		end
		if key == "CharacterAutoLoads" and world.faults.ignoreAutoLoads then
			return
		end
		data.props[key] = value
	end

	local function make(className, name, parent, created)
		local proxy = setmetatable({}, InstanceMeta)
		local data = { className = className, name = name or className, parent = nil, children = {}, props = {}, destroyed = false, created = created }
		world.data[proxy] = data
		if isA(className, "LuaSourceContainer") then
			data.props.Source = ""
		end
		if isA(className, "BaseScript") then
			data.props.Enabled = true
		end
		if isA(className, "Script") then
			data.props.RunContext = world.Enum.RunContext.Legacy
		end
		if className == "Players" then
			data.props.CharacterAutoLoads = true
		end
		if parent ~= nil then
			data.parent = parent
			local siblings = world.data[parent].children
			siblings[#siblings + 1] = proxy
		end
		return proxy
	end

	world.game = make("DataModel", "Game", nil, false)
	world.services = {}
	for _, name in ipairs(SERVICES) do
		world.services[name] = make(name, name, world.game, false)
	end
	local workspace = world.services.Workspace
	make("Camera", "Camera", workspace, false)
	make("Terrain", "Terrain", workspace, false)
	make("Part", "Baseplate", workspace, false)
	make("SpawnLocation", "SpawnLocation", workspace, false)
	make("StarterPlayerScripts", "StarterPlayerScripts", world.services.StarterPlayer, false)
	make("StarterCharacterScripts", "StarterCharacterScripts", world.services.StarterPlayer, false)

	--[[ For tests: add an object as if it existed before the installer ran. ]]
	function world.add(className, name, parent)
		return make(className, name, parent, false)
	end

	world.Instance = {
		new = function(className)
			world.newCount = world.newCount + 1
			if world.faults.newFailsAt ~= nil and world.faults.newFailsAt == world.newCount then
				error("mock fault: Instance.new call " .. tostring(world.newCount), 0)
			end
			if not CREATABLE[className] then
				error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 2)
			end
			local proxy = make(className, className, nil, true)
			world.created = world.created or {}
			world.created[#world.created + 1] = proxy
			return proxy
		end,
	}

	function world.dataOf(proxy)
		return world.data[proxy]
	end

	--[[ True when the object is inside the DataModel (not detached). ]]
	function world.inPlace(proxy)
		local node = world.data[proxy].parent
		while node ~= nil do
			if node == world.game then
				return true
			end
			node = world.data[node].parent
		end
		return false
	end

	function world.resolve(path)
		local node = nil
		for segment in string.gmatch(path, "[^/]+") do
			if node == nil then
				node = world.services[segment]
			else
				node = methods.FindFirstChild(node, segment)
			end
			if node == nil then
				return nil
			end
		end
		return node
	end

	--[[ Text snapshot of every service subtree plus the one setting, for before/after comparisons. ]]
	function world.snapshot()
		local lines = {}
		local function visit(proxy, depth)
			local data = world.data[proxy]
			local extra = ""
			if data.props.Source ~= nil then
				extra = extra .. " source#" .. tostring(#data.props.Source) .. ":" .. data.props.Source
			end
			if data.props.Enabled ~= nil then
				extra = extra .. " enabled=" .. tostring(data.props.Enabled)
			end
			if data.props.RunContext ~= nil then
				extra = extra .. " runContext=" .. tostring(data.props.RunContext)
			end
			lines[#lines + 1] = string.rep(" ", depth) .. data.className .. " " .. data.name .. " id=" .. tostring(proxy) .. extra
			for _, child in ipairs(data.children) do
				visit(child, depth + 1)
			end
		end
		visit(world.game, 0)
		lines[#lines + 1] = "CharacterAutoLoads=" .. tostring(world.data[world.services.Players].props.CharacterAutoLoads)
		return table.concat(lines, "\n")
	end

	function world.environment()
		local env = {
			game = world.game,
			Instance = world.Instance,
			Enum = world.Enum,
			print = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					parts[#parts + 1] = tostring((select(i, ...)))
				end
				world.output[#world.output + 1] = { kind = "print", text = table.concat(parts, " ") }
			end,
			warn = function(...)
				local parts = {}
				for i = 1, select("#", ...) do
					parts[#parts + 1] = tostring((select(i, ...)))
				end
				world.output[#world.output + 1] = { kind = "warn", text = table.concat(parts, " ") }
			end,
		}
		for _, name in ipairs({ "pcall", "error", "type", "tostring", "tonumber", "pairs", "ipairs", "select", "next", "string", "table", "math" }) do
			env[name] = _G[name]
		end
		return env
	end

	function world.outputText()
		local lines = {}
		for _, line in ipairs(world.output) do
			lines[#lines + 1] = line.text
		end
		return table.concat(lines, "\n")
	end

	return world
end

--[[ Compiles installer text and runs it in the world. Returns compiled (boolean) and the compile error. ]]
function Mock.run(world, text)
	local chunk, compileError = loadstring(text, "=InstallM2.lua")
	if chunk == nil then
		return false, compileError
	end
	setfenv(chunk, world.environment())
	local ok, runtimeError = pcall(chunk)
	if not ok then
		world.output[#world.output + 1] = { kind = "uncaught", text = tostring(runtimeError) }
	end
	return true, nil
end

return Mock
