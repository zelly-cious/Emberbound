--[[
	Tests for tools/m2/InstallM2.lua using the fake engine in mock_roblox.lua (plain Lua 5.1).
	Review tooling only. Run through tools/m2/tests/run_tests.py, which prepares the fixtures:
	  lua5.1 installer_tests.lua <InstallM2.lua> <fixture dir> <dump file>
	The fixture dir holds layout.txt (Explorer path TAB class, Appendix A order) and
	01.luau ... 24.luau, the frozen sources read with git from the frozen commit.
	These tests run the real installer text; they do not run Roblox Studio.
]]

local scriptDir = string.match(arg[0], "^(.*)/[^/]*$") or "."
package.path = scriptDir .. "/?.lua;" .. package.path
local Mock = require("mock_roblox")

local installerPath, fixtureDir, dumpPath = arg[1], arg[2], arg[3]

local function readFile(path)
	local handle = assert(io.open(path, "rb"))
	local data = handle:read("*a")
	handle:close()
	return data
end

local INSTALLER = readFile(installerPath)
local LAYOUT = {}
for line in string.gmatch(readFile(fixtureDir .. "/layout.txt"), "[^\n]+") do
	local path, className = string.match(line, "^([^\t]+)\t(%a+)$")
	LAYOUT[#LAYOUT + 1] = { path = path, className = className, source = readFile(string.format("%s/%02d.luau", fixtureDir, #LAYOUT + 1)) }
end
assert(#LAYOUT == 24, "fixtures must hold 24 files")

local FLAG_OFF = "local ENABLE_INSTALLATION = false"
local FLAG_ON = "local ENABLE_INSTALLATION = true"
local REMOTES = { "RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate" }
local FOLDERS = { "ReplicatedStorage/Shared", "ReplicatedStorage/Remotes", "ServerScriptService/Tests" }
local ALLOWED_SERVICES = {
	RunService = true, Players = true, Workspace = true, ReplicatedFirst = true, ReplicatedStorage = true,
	ServerScriptService = true, ServerStorage = true, StarterGui = true, StarterPack = true,
	StarterPlayer = true, Lighting = true, SoundService = true,
}

local function check(condition, message)
	if not condition then
		error(message, 2)
	end
end

local function replaceOnce(text, old, new)
	local first, last = string.find(text, old, 1, true)
	check(first ~= nil, "text to replace not found: " .. old)
	check(string.find(text, old, last + 1, true) == nil, "text to replace occurs more than once: " .. old)
	return string.sub(text, 1, first - 1) .. new .. string.sub(text, last + 1)
end

local INSTALL = replaceOnce(INSTALLER, FLAG_OFF, FLAG_ON)

local function has(world, needle)
	return string.find(world.outputText(), needle, 1, true) ~= nil
end

local function attempted(world)
	return has(world, "INSTALLATION COMPLETE") or has(world, "INSTALLATION FAILED") or has(world, "ROLLBACK")
end

local function checkPrefixes(world)
	for _, line in ipairs(world.output) do
		check(line.kind ~= "uncaught", "uncaught error: " .. line.text)
		check(string.sub(line.text, 1, 15) == "[M2 Installer] ", "output line without the prefix: " .. line.text)
		check(string.find(line.text, "[Parity]", 1, true) == nil, "installer printed a [Parity] line")
		check(string.find(line.text, "unexpected error", 1, true) == nil, "the installer stopped with an unexpected error: " .. line.text)
	end
	--[[ M2-I02: GetService creates missing services, so the installer must never call it. ]]
	check(world.getServiceCalls == 0, "the installer called GetService " .. tostring(world.getServiceCalls) .. " times")
	check(#world.servicesCreated == 0, "a service was created: " .. table.concat(world.servicesCreated, ", "))
end

--[[ A Baseplate plus two unrelated objects that must survive everything. ]]
local function freshWorld()
	local world = Mock.newWorld()
	world.keepPart = world.add("Part", "KeepMe", world.services.Workspace)
	world.keepFolder = world.add("Folder", "Unrelated", world.services.ReplicatedStorage)
	world.add("RemoteEvent", "UnrelatedRemote", world.keepFolder)
	return world
end

local function checkUntouched(world, before)
	check(world.snapshot() == before, "the place changed")
	check(world.newCount == 0, "Instance.new was called " .. tostring(world.newCount) .. " times")
	check((world.preexistingSets or 0) == 0, "a property of an existing object was set")
end

local function runText(world, text)
	local compiled, compileError = Mock.run(world, text)
	check(compiled, "installer did not compile: " .. tostring(compileError))
	checkPrefixes(world)
end

local function checkRefused(world, before)
	check(has(world, "Ready to install: NO"), "expected Ready to install: NO")
	check(has(world, "Nothing was changed."), "expected 'Nothing was changed.'")
	check(not attempted(world), "an installation was attempted")
	checkUntouched(world, before)
end

local function checkInstalled(world, autoLoadsNote)
	check(has(world, "INSTALLATION COMPLETE"), "no INSTALLATION COMPLETE")
	check(has(world, "Scripts: 24/24"), "no Scripts: 24/24")
	check(has(world, "RemoteEvents: 6/6"), "no RemoteEvents: 6/6")
	check(has(world, "Required folders: 3/3"), "no Required folders: 3/3")
	check(has(world, autoLoadsNote), "missing CharacterAutoLoads note: " .. autoLoadsNote)
	for _, entry in ipairs(LAYOUT) do
		local node = world.resolve(entry.path)
		check(node ~= nil, entry.path .. " missing")
		check(node.ClassName == entry.className, entry.path .. " has class " .. node.ClassName)
		check(node.Source == entry.source, entry.path .. ": installed Source differs from the frozen file")
		if entry.className ~= "ModuleScript" then
			check(node.Enabled == true, entry.path .. " is disabled")
		end
		if entry.className == "Script" then
			check(tostring(node.RunContext) == "Enum.RunContext.Legacy", entry.path .. " RunContext " .. tostring(node.RunContext))
		end
		local siblings = 0
		for _, child in ipairs(node.Parent:GetChildren()) do
			if child.Name == node.Name then
				siblings = siblings + 1
			end
		end
		check(siblings == 1, entry.path .. " is duplicated")
	end
	for _, path in ipairs(FOLDERS) do
		local node = world.resolve(path)
		check(node ~= nil and node.ClassName == "Folder", path .. " is not a Folder")
	end
	local remotes = world.resolve("ReplicatedStorage/Remotes")
	check(#remotes:GetChildren() == 6, "Remotes does not hold 6 objects")
	for _, name in ipairs(REMOTES) do
		local remote = remotes:FindFirstChild(name)
		check(remote ~= nil and remote.ClassName == "RemoteEvent", name .. " is not a RemoteEvent")
	end
	check(world.services.StarterGui == nil or #world.services.StarterGui:GetChildren() == 0, "something was created in StarterGui")
	check(#world.services.StarterPlayer:FindFirstChild("StarterCharacterScripts"):GetChildren() == 0, "something was created in StarterCharacterScripts")
	check(world.services.Players.CharacterAutoLoads == false, "CharacterAutoLoads is not false")
	check(world.newCount == 33, "expected 33 created objects, got " .. tostring(world.newCount))
	check(world.keepPart.Parent == world.services.Workspace, "an unrelated Part was moved")
	check(world.keepFolder.Parent == world.services.ReplicatedStorage and world.keepFolder:FindFirstChild("UnrelatedRemote") ~= nil, "an unrelated Folder was changed")
	for name in pairs(world.servicesRequested) do
		check(ALLOWED_SERVICES[name], "unexpected service requested: " .. name)
	end
end

local function checkRolledBack(world, before, complete)
	check(has(world, "INSTALLATION FAILED"), "no INSTALLATION FAILED message")
	check(has(world, "Close this place WITHOUT saving"), "no close-without-saving advice")
	if complete then
		check(has(world, "ROLLBACK COMPLETE"), "no ROLLBACK COMPLETE message")
		check(world.snapshot() == before, "the place is not back to its state before the run")
		for _, instance in ipairs(world.created or {}) do
			check(instance.Parent == nil, "a created object is still in the place")
		end
	else
		check(has(world, "ROLLBACK INCOMPLETE"), "no ROLLBACK INCOMPLETE message")
	end
	check(world.keepPart.Parent == world.services.Workspace, "an unrelated Part was touched by the rollback")
	check(world.keepFolder.Parent == world.services.ReplicatedStorage and world.keepFolder:FindFirstChild("UnrelatedRemote") ~= nil, "an unrelated Folder was touched by the rollback")
end

local function dumpInstalled(world)
	local handle = assert(io.open(dumpPath, "wb"))
	local function hex(text)
		return (string.gsub(text, ".", function(c)
			return string.format("%02x", string.byte(c))
		end))
	end
	for _, serviceName in ipairs({ "Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" }) do
		for _, node in ipairs(world.services[serviceName]:GetDescendants()) do
			local path = string.gsub(node:GetFullName(), "%.", "/")
			if node:IsA("LuaSourceContainer") then
				local enabled = node:IsA("BaseScript") and tostring(node.Enabled) or "-"
				local context = node.ClassName == "Script" and tostring(node.RunContext) or "-"
				handle:write("SCRIPT\t", path, "\t", node.ClassName, "\t", enabled, "\t", context, "\t", hex(node.Source), "\n")
			else
				handle:write("OBJECT\t", path, "\t", node.ClassName, "\n")
			end
		end
	end
	handle:write("SETTING\tCharacterAutoLoads\t", tostring(world.services.Players.CharacterAutoLoads), "\n")
	handle:close()
end

local tests = {}
local function test(name, fn)
	tests[#tests + 1] = { name = name, fn = fn }
end

--[[ ---------------- installer text ---------------- ]]

test("the default setting is check-only", function()
	check(select(2, string.gsub(INSTALLER, FLAG_OFF, "")) == 1, "ENABLE_INSTALLATION = false must appear exactly once")
	check(string.find(INSTALLER, FLAG_ON, 1, true) == nil, "the file must not enable installation")
end)

--[[ ---------------- preflight ---------------- ]]

test("check mode on a fresh Baseplate reports ready and changes nothing", function()
	local world = freshWorld()
	local before = world.snapshot()
	runText(world, INSTALLER)
	check(has(world, "Mode: CHECK ONLY"), "mode line missing")
	check(has(world, "Embedded source: 24/24 files"), "payload line missing")
	check(has(world, "Studio mode: Edit mode"), "Studio mode line missing")
	check(has(world, "Existing objects: no conflicts."), "conflict line missing")
	check(has(world, "Safe to modify this place: YES"), "safe line missing")
	check(has(world, "Ready to install: YES"), "ready line missing")
	check(has(world, "CHECK COMPLETE. Nothing was changed."), "check complete line missing")
	check(not attempted(world), "check mode attempted an installation")
	checkUntouched(world, before)
end)

test("check mode in a place that is not fresh reports conflicts and changes nothing", function()
	local world = freshWorld()
	world.add("Folder", "Shared", world.services.ReplicatedStorage)
	local before = world.snapshot()
	runText(world, INSTALLER)
	check(has(world, "conflict(s)"), "conflict not reported")
	checkRefused(world, before)
end)

--[[ ---------------- installation ---------------- ]]

test("installation on a fresh Baseplate creates exactly the reviewed hierarchy", function()
	local world = freshWorld()
	runText(world, INSTALL)
	checkInstalled(world, "Players.CharacterAutoLoads: false (changed from true by this run)")
	dumpInstalled(world)
end)

test("installation when CharacterAutoLoads is already false leaves it false", function()
	local world = freshWorld()
	world.dataOf(world.services.Players).props.CharacterAutoLoads = false
	runText(world, INSTALL)
	checkInstalled(world, "Players.CharacterAutoLoads: false (it was already false)")
end)

test("a second run after a successful installation refuses and changes nothing", function()
	local world = freshWorld()
	runText(world, INSTALL)
	checkInstalled(world, "changed from true by this run")
	local createdBefore = world.newCount
	world.output = {}
	world.preexistingSets = 0
	local before = world.snapshot()
	runText(world, INSTALL)
	check(has(world, "already exists."), "existing Milestone 2 objects not reported")
	check(has(world, "Existing script"), "existing scripts not reported")
	check(has(world, "Ready to install: NO"), "second run not refused")
	check(not attempted(world), "second run attempted an installation")
	check(world.snapshot() == before and world.newCount == createdBefore, "second run changed the place")
end)

--[[ ---------------- collisions ---------------- ]]

local collisions = {
	{ "Folder Shared in ReplicatedStorage", "Folder", "Shared", "ReplicatedStorage" },
	{ "ModuleScript Shared in ReplicatedStorage (wrong class)", "ModuleScript", "Shared", "ReplicatedStorage" },
	{ "Folder Remotes in ReplicatedStorage", "Folder", "Remotes", "ReplicatedStorage" },
	{ "Folder Tests in ServerScriptService", "Folder", "Tests", "ServerScriptService" },
	{ "ModuleScript CombatService in ServerScriptService", "ModuleScript", "CombatService", "ServerScriptService" },
	{ "Part named ServerInit in ServerScriptService (not a script)", "Part", "ServerInit", "ServerScriptService" },
	{ "Folder named Wallet in ServerScriptService", "Folder", "Wallet", "ServerScriptService" },
	{ "LocalScript CombatClient in StarterPlayerScripts", "LocalScript", "CombatClient", "StarterPlayerScripts" },
	{ "Folder named CombatClient in StarterPlayerScripts", "Folder", "CombatClient", "StarterPlayerScripts" },
	{ "stray Script in Workspace", "Script", "Leftover", "Workspace" },
	{ "stray ModuleScript in ServerStorage", "ModuleScript", "OldModule", "ServerStorage" },
	{ "stray LocalScript in StarterGui", "LocalScript", "OldClient", "StarterGui" },
	{ "stray Script in StarterCharacterScripts", "Script", "OldCharacter", "StarterCharacterScripts" },
	{ "stray RemoteFunction named Remotes in ReplicatedStorage", "RemoteFunction", "Remotes", "ReplicatedStorage" },
}
for _, case in ipairs(collisions) do
	test("collision refused: " .. case[1], function()
		local world = freshWorld()
		local parent
		if case[4] == "StarterPlayerScripts" or case[4] == "StarterCharacterScripts" then
			parent = world.services.StarterPlayer:FindFirstChild(case[4])
		else
			parent = world.services[case[4]]
		end
		local existing = world.add(case[2], case[3], parent)
		local before = world.snapshot()
		runText(world, INSTALL)
		checkRefused(world, before)
		check(existing.Parent == parent, "the existing object was moved")
	end)
end

--[[ ---------------- Studio mode and place ---------------- ]]

local modes = {
	{ "playtest running", function(w) w.mode.edit = false; w.mode.running = true end, "A playtest is running" },
	{ "playtest paused", function(w) w.mode.edit = false; w.mode.running = false end, "not in Edit mode" },
	{ "not Roblox Studio", function(w) w.mode.studio = false end, "This is not Roblox Studio" },
	{ "IsEdit raises an error", function(w) w.mode.errors.IsEdit = true end, "Could not determine whether Studio is in Edit mode" },
	{ "IsRunning raises an error", function(w) w.mode.errors.IsRunning = true end, "Could not determine whether Studio is in Edit mode" },
	{ "IsStudio raises an error", function(w) w.mode.errors.IsStudio = true end, "Could not determine whether Studio is in Edit mode" },
	{ "IsEdit returns a non-boolean", function(w) w.mode.values.IsEdit = "yes" end, "Could not determine whether Studio is in Edit mode" },
	{ "RunService unavailable", function(w) w.faults.getServiceFails = function(name) return name == "RunService" end end, "Could not reach RunService" },
	{ "published place (non-zero PlaceId)", function(w) w.placeId = 123456789; w.gameId = 987654321 end, "Place identity: PlaceId 123456789, GameId 987654321" },
	{ "published place is refused with a report request", function(w) w.placeId = 123456789 end, "which normally means it is published to Roblox, so the installer refuses it" },
	{ "PlaceId unreadable", function(w) w.placeIdError = true end, "Could not read the place's PlaceId" },
	{ "StarterPlayerScripts missing", function(w) w.services.StarterPlayer:FindFirstChild("StarterPlayerScripts"):Destroy() end, "StarterPlayer.StarterPlayerScripts was not found" },
}
for _, case in ipairs(modes) do
	test("unsafe state refused: " .. case[1], function()
		local world = freshWorld()
		case[2](world)
		local before = world.snapshot()
		runText(world, INSTALL)
		check(has(world, case[3]), "expected message: " .. case[3])
		checkRefused(world, before)
	end)
end

--[[ ---------------- missing services (M2-I02) ---------------- ]]

for _, serviceName in ipairs({ "SoundService", "Lighting", "StarterPack", "StarterGui", "ServerStorage", "ReplicatedFirst" }) do
	test("a missing scan-only service is skipped and never created: " .. serviceName, function()
		local world = freshWorld()
		world.removeService(serviceName)
		local before = world.snapshot()
		runText(world, INSTALLER)
		check(has(world, "Ready to install: YES"), "check mode did not report ready")
		checkUntouched(world, before)
		local installWorld = freshWorld()
		installWorld.removeService(serviceName)
		runText(installWorld, INSTALL)
		checkInstalled(installWorld, "changed from true by this run")
		check(installWorld.services[serviceName] == nil, serviceName .. " was created by the installation")
	end)
end

local requiredServices = {
	{ "RunService", "Could not reach RunService" },
	{ "Players", "The Players service was not found" },
	{ "ReplicatedStorage", "ReplicatedStorage was not found" },
	{ "ServerScriptService", "ServerScriptService was not found" },
	{ "StarterPlayer", "StarterPlayer.StarterPlayerScripts was not found" },
}
for _, case in ipairs(requiredServices) do
	test("a missing required service is refused and never created: " .. case[1], function()
		local world = freshWorld()
		world.removeService(case[1])
		local before = world.snapshot()
		runText(world, INSTALL)
		check(has(world, case[2]), "expected message: " .. case[2])
		checkRefused(world, before)
		check(world.services[case[1]] == nil, case[1] .. " was created")
	end)
end

--[[ ---------------- damaged installer text ---------------- ]]

local function fileBlockStart(text, index)
	local start = string.find(text, "\nFILES[" .. tostring(index) .. "] = {\n", 1, true)
	check(start ~= nil, "FILES block not found")
	return start + 1
end

local damage = {
	{ "one character changed inside an embedded file", function(text)
		local start = fileBlockStart(text, 5)
		local body = string.find(text, "\n\t\t\"", start, true) + 4
		local original = string.sub(text, body, body)
		check(original ~= "\\", "picked an escape character")
		return string.sub(text, 1, body - 1) .. (original == "X" and "Y" or "X") .. string.sub(text, body + 1)
	end, "checksum mismatch" },
	{ "one embedded file removed", function(text)
		local start = fileBlockStart(text, 24)
		local finish = string.find(text, "\n}\n", start, true)
		return string.sub(text, 1, start - 1) .. string.sub(text, finish + 3)
	end, "The embedded payload has 23 files" },
	{ "a path duplicated", function(text)
		return replaceOnce(text, "\tpath = \"ReplicatedStorage/Shared/GameConfig\",\n", "\tpath = \"ReplicatedStorage/Shared/BigNum\",\n")
	end, "does not match the expected" },
	{ "a class changed", function(text)
		return replaceOnce(text, "\tpath = \"ServerScriptService/ServerInit\",\n\tclassName = \"Script\",", "\tpath = \"ServerScriptService/ServerInit\",\n\tclassName = \"ModuleScript\",")
	end, "does not match the expected" },
	{ "a recorded checksum changed", function(text)
		return replaceOnce(text, "\tadler32 = 3533007835,", "\tadler32 = 3533007836,")
	end, "checksum mismatch" },
	{ "one source line dropped", function(text)
		local start = fileBlockStart(text, 12)
		local lineStart = string.find(text, "\n\t\t\"", start, true)
		local lineEnd = string.find(text, "\n", lineStart + 1, true)
		return string.sub(text, 1, lineStart) .. string.sub(text, lineEnd + 1)
	end, "checksum mismatch" },
}
for _, case in ipairs(damage) do
	test("damaged installer refused: " .. case[1], function()
		local world = freshWorld()
		local before = world.snapshot()
		runText(world, case[2](INSTALL))
		check(has(world, case[3]), "expected message: " .. case[3])
		checkRefused(world, before)
	end)
end

test("truncated pastes never change the place", function()
	local cuts = {}
	for fraction = 0.05, 0.96, 0.05 do
		cuts[#cuts + 1] = math.floor(#INSTALL * fraction)
	end
	cuts[#cuts + 1] = string.find(INSTALL, "\nlocal ranOk", 1, true)
	cuts[#cuts + 1] = fileBlockStart(INSTALL, 24) + 200
	cuts[#cuts + 1] = #INSTALL - 60
	for _, cut in ipairs(cuts) do
		local world = freshWorld()
		local before = world.snapshot()
		Mock.run(world, string.sub(INSTALL, 1, cut))
		check(not attempted(world), "a truncated installer attempted an installation (cut at " .. tostring(cut) .. ")")
		checkUntouched(world, before)
	end
end)

test("installation works when line breaks become spaces", function()
	local world = freshWorld()
	runText(world, (string.gsub(INSTALL, "\n", " ")))
	checkInstalled(world, "changed from true by this run")
end)

test("installation works with Windows CRLF line endings", function()
	local world = freshWorld()
	runText(world, (string.gsub(INSTALL, "\n", "\r\n")))
	checkInstalled(world, "changed from true by this run")
end)

--[[ ---------------- failures during installation ---------------- ]]

local faults = {
	{ "Instance.new fails on the first object", function(w) w.faults.newFailsAt = 1 end, "Instance.new call 1" },
	{ "Instance.new fails on the first RemoteEvent", function(w) w.faults.newFailsAt = 4 end, "Instance.new call 4" },
	{ "Instance.new fails on the 10th object (a script)", function(w) w.faults.newFailsAt = 10 end, "Instance.new call 10" },
	{ "Instance.new fails on the last script", function(w) w.faults.newFailsAt = 33 end, "Instance.new call 33" },
	{ "setting Source fails for UpgradePanel", function(w)
		w.faults.onSet = function(_, data, key) if key == "Source" and data.name == "UpgradePanel" then error("mock fault: Source", 0) end end
	end, "mock fault: Source" },
	{ "Studio alters the text of Wallet", function(w)
		w.faults.transformSource = function(data, value) if data.name == "Wallet" then return value .. "print(1)\n" end return value end
	end, "Studio changed the text of ServerScriptService/Wallet" },
	{ "setting Enabled fails for TestRunner", function(w)
		w.faults.onSet = function(_, data, key) if key == "Enabled" and data.name == "TestRunner" then error("mock fault: Enabled", 0) end end
	end, "mock fault: Enabled" },
	{ "ServerInit reports RunContext = Client", function(w)
		w.faults.onGet = function(_, data, key) if key == "RunContext" and data.name == "ServerInit" then return true, w.Enum.RunContext.Client end return false end
	end, "RunContext = Client" },
	{ "adding Tests to ServerScriptService fails (after Shared and Remotes were added)", function(w)
		w.faults.onSet = function(_, data, key, value) if key == "Parent" and data.name == "Tests" and value == w.services.ServerScriptService then error("mock fault: Parent", 0) end end
	end, "mock fault: Parent" },
	{ "adding CombatClient fails (the last object added)", function(w)
		local target = w.services.StarterPlayer:FindFirstChild("StarterPlayerScripts")
		w.faults.onSet = function(_, data, key, value) if key == "Parent" and data.name == "CombatClient" and value == target then error("mock fault: Parent", 0) end end
	end, "mock fault: Parent" },
	{ "setting CharacterAutoLoads fails", function(w)
		w.faults.onSet = function(_, data, key) if key == "CharacterAutoLoads" then error("mock fault: CharacterAutoLoads", 0) end end
	end, "mock fault: CharacterAutoLoads" },
	{ "CharacterAutoLoads silently stays true", function(w) w.faults.ignoreAutoLoads = true end, "could not be set to false" },
	{ "final verification reads different text for BigNum", function(w)
		w.faults.onGet = function(proxy, data, key)
			if key == "Source" and data.name == "BigNum" and w.inPlace(proxy) then
				return true, "--!strict\nreturn {}\n"
			end
			return false
		end
	end, "the installed text differs" },
}
for _, case in ipairs(faults) do
	test("rollback after failure: " .. case[1], function()
		local world = freshWorld()
		case[2](world)
		local before = world.snapshot()
		runText(world, INSTALL)
		check(has(world, case[3]), "expected failure reason: " .. case[3])
		checkRolledBack(world, before, true)
		check(world.services.Players.CharacterAutoLoads == true, "CharacterAutoLoads was not restored")
	end)
end

--[[ M2-I01: a failing CharacterAutoLoads read or write during rollback must not stop the cleanup. ]]
local function failVerificationAfterCommit(w, onBigNumRead)
	return function(proxy, data, key)
		if key == "Source" and data.name == "BigNum" and w.inPlace(proxy) then
			if onBigNumRead then
				onBigNumRead()
			end
			return true, "--!strict\nreturn {}\n"
		end
		if key == "CharacterAutoLoads" and w.breakAutoLoadsRead then
			error("mock fault: reading CharacterAutoLoads", 0)
		end
		return false
	end
end

local rollbackSettingFaults = {
	{ "the CharacterAutoLoads read fails after the restore write", function(w)
		w.faults.onGet = failVerificationAfterCommit(w, nil)
		w.faults.onSet = function(_, _, key, value)
			if key == "CharacterAutoLoads" and value == true then
				w.breakAutoLoadsRead = true
			end
		end
	end, true },
	{ "every CharacterAutoLoads read fails during rollback", function(w)
		w.faults.onGet = failVerificationAfterCommit(w, function()
			w.breakAutoLoadsRead = true
		end)
	end, true },
	{ "the CharacterAutoLoads restore write fails", function(w)
		w.faults.onGet = failVerificationAfterCommit(w, nil)
		w.faults.onSet = function(_, _, key, value)
			if key == "CharacterAutoLoads" and value == true then
				error("mock fault: writing CharacterAutoLoads", 0)
			end
		end
	end, false },
}
for _, case in ipairs(rollbackSettingFaults) do
	test("rollback still removes every created object when " .. case[1], function()
		local world = freshWorld()
		case[2](world)
		local before = world.snapshot()
		runText(world, INSTALL)
		check(has(world, "the installed text differs"), "the verification failure did not trigger")
		checkRolledBack(world, before, false)
		check(has(world, "could not restore or confirm Players.CharacterAutoLoads"), "the setting problem was not reported")
		check(world.created ~= nil and #world.created == 33, "expected 33 created objects")
		for _, instance in ipairs(world.created) do
			check(instance.Parent == nil, "a created object is still in the place")
		end
		check(world.dataOf(world.services.Players).props.CharacterAutoLoads == case[3], "unexpected final CharacterAutoLoads")
	end)
end

test("rollback that cannot remove an object says so (documented limitation)", function()
	local world = freshWorld()
	local target = world.services.StarterPlayer:FindFirstChild("StarterPlayerScripts")
	world.faults.onSet = function(_, data, key, value)
		if key == "Parent" and data.name == "CombatClient" and value == target then
			error("mock fault: Parent", 0)
		end
	end
	world.faults.destroyFails = function(_, data)
		return data.name == "Remotes"
	end
	local before = world.snapshot()
	runText(world, INSTALL)
	checkRolledBack(world, before, false)
	check(has(world, "could not remove"), "the leftover object was not named")
	check(world.services.Players.CharacterAutoLoads == true, "CharacterAutoLoads changed")
end)

--[[ ---------------- run ---------------- ]]

local passed, failed = 0, 0
for _, case in ipairs(tests) do
	local ok, problem = pcall(case.fn)
	if ok then
		passed = passed + 1
		print("PASS " .. case.name)
	else
		failed = failed + 1
		print("FAIL " .. case.name .. ": " .. tostring(problem))
	end
end
print(string.format("[installer tests] %d passed, %d failed, %d declared", passed, failed, #tests))
os.exit(failed == 0 and 0 or 1)
