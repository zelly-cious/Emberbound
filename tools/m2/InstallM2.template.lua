--[[
	Emberbound Milestone 2: one-time Roblox Studio installer (task M2-TOOLS-001)
	Installer version {{INSTALLER_VERSION}}
	Frozen source commit {{FROZEN_COMMIT}}
	{{FILE_COUNT}} files; SHA-256 manifest: SOURCE_HASHES.txt, round 4 (BigNum DEFECT-001/001B adoption)

	GENERATED FILE. tools/m2/generate_installer.py builds it from the frozen commit and
	tools/m2/InstallM2.template.lua. Do not edit it, except the ONE setting marked below.

	WHAT IT DOES
	  Check mode (the default): checks this file and your place, prints a report in Output,
	  and changes nothing.
	  Install mode: in a FRESH Baseplate saved to a file, creates 3 folders, 6 RemoteEvents
	  and the 24 Milestone 2 scripts, and sets Players.CharacterAutoLoads to false.

	SAFETY
	  It refuses to run while a playtest is running or paused, in a place published to
	  Roblox, or when the place already holds any script or any object with a Milestone 2
	  name. It never replaces, edits or deletes anything that existed before it ran. If
	  something fails during installation, it removes only what this run created and puts
	  CharacterAutoLoads back. It does not publish, upload, use HTTP or DataStores, or run
	  the game.

	HOW TO USE: tools/m2/INSTALL_INSTRUCTIONS.md
	Afterwards, the independent Appendix B checker in M2_STUDIO_REGRESSION_GUIDE.md is what
	proves source parity. This installer's own messages are not a parity result.
]]

--[[ ======================================================================
     THE ONLY SETTING YOU MAY CHANGE
       false = CHECK ONLY. Nothing in your place is changed.
       true  = INSTALL. Use it only after a check run printed
               "Ready to install: YES" in this same place.
     ====================================================================== ]]
local ENABLE_INSTALLATION = false
--[[ ====================================================================== ]]

local INSTALLER_VERSION = "{{INSTALLER_VERSION}}"
local FROZEN_COMMIT = "{{FROZEN_COMMIT}}"
local PREFIX = "[M2 Installer]"
local EXPECTED_FILE_COUNT = {{FILE_COUNT}}

--[[ Expected hierarchy (Appendix A of M2_STUDIO_REGRESSION_GUIDE.md). ]]
local LAYOUT = {
{{LAYOUT}}
}
local FOLDERS = {
	{ path = "ReplicatedStorage/Shared", container = "ReplicatedStorage", name = "Shared" },
	{ path = "ReplicatedStorage/Remotes", container = "ReplicatedStorage", name = "Remotes" },
	{ path = "ServerScriptService/Tests", container = "ServerScriptService", name = "Tests" },
}
local REMOTES = { "RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate" }
--[[ Containers that already exist in every Baseplate. The installer only adds children to them. ]]
local CONTAINER_PATHS = { "ReplicatedStorage", "ServerScriptService", "StarterPlayer/StarterPlayerScripts" }
--[[ Same services as the Appendix B checker's "extra script" scan. ]]
local SCAN_SERVICES = { "Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" }

--[[ Embedded frozen sources: one escaped string per source line. ]]
local FILES = {}
{{FILES}}

--[[ ---------------------------------------------------------------------- ]]
--[[ Helpers                                                                  ]]
--[[ ---------------------------------------------------------------------- ]]

local function say(text)
	print(PREFIX .. " " .. text)
end

local function alert(text)
	warn(PREFIX .. " " .. text)
end

--[[ Same normalization and checksum as the Appendix B parity checker. ]]
local function normalizeSource(text)
	local result = string.gsub(text, "\r\n", "\n")
	result = string.gsub(result, "%s+$", "")
	return result .. "\n"
end

local function adler32(text)
	local a, b = 1, 0
	for i = 1, #text do
		a = (a + string.byte(text, i)) % 65521
		b = (b + a) % 65521
	end
	return b * 65536 + a
end

local function countLines(text)
	local _, count = string.gsub(text, "\n", "")
	return count
end

local function splitPath(path)
	return string.match(path, "^(.*)/([^/]+)$")
end

--[[ Looks a service up WITHOUT creating it (GetService would create a missing service).
     Returns false when the lookup itself fails, otherwise true and the service or nil. ]]
local function findService(serviceName)
	local ok, service = pcall(function()
		return game:FindService(serviceName)
	end)
	if ok then
		return true, service
	end
	return false, nil
end

local function safeChild(parent, childName)
	local ok, child = pcall(function()
		return parent:FindFirstChild(childName)
	end)
	if ok then
		return true, child
	end
	return false, nil
end

local function describe(instance)
	local ok, text = pcall(function()
		return instance:GetFullName() .. " (" .. instance.ClassName .. ")"
	end)
	if ok then
		return text
	end
	return "an object that could not be described"
end

--[[ Resolves "Service/Child/..." from the DataModel; nil if any step is missing. ]]
local function resolvePath(path)
	local node = nil
	for segment in string.gmatch(path, "[^/]+") do
		if node == nil then
			local ok, service = findService(segment)
			if not ok then
				return nil
			end
			node = service
		else
			local ok, child = safeChild(node, segment)
			if not ok then
				return nil
			end
			node = child
		end
		if node == nil then
			return nil
		end
	end
	return node
end

--[[ ---------------------------------------------------------------------- ]]
--[[ Preflight 1: the embedded source payload                                 ]]
--[[ ---------------------------------------------------------------------- ]]

local function checkPayload(problems)
	local sources = {}
	local entryCount = 0
	for _ in pairs(FILES) do
		entryCount = entryCount + 1
	end
	if entryCount ~= EXPECTED_FILE_COUNT or #LAYOUT ~= EXPECTED_FILE_COUNT then
		problems[#problems + 1] = "The embedded payload has " .. tostring(entryCount) .. " files; expected " .. tostring(EXPECTED_FILE_COUNT) .. ". The installer file is damaged: download it again."
		return nil
	end
	local seenPaths = {}
	local classCounts = { ModuleScript = 0, Script = 0, LocalScript = 0 }
	for index = 1, EXPECTED_FILE_COUNT do
		local entry = FILES[index]
		local expected = LAYOUT[index]
		local label = "file " .. tostring(index)
		if type(entry) ~= "table" or type(expected) ~= "table" then
			problems[#problems + 1] = label .. " is missing from the payload."
		elseif entry.path ~= expected.path or entry.className ~= expected.className then
			problems[#problems + 1] = label .. " (" .. tostring(entry.path) .. ", " .. tostring(entry.className) .. ") does not match the expected " .. expected.path .. " (" .. expected.className .. ")."
		elseif seenPaths[entry.path] then
			problems[#problems + 1] = entry.path .. " appears twice in the payload."
		elseif classCounts[entry.className] == nil then
			problems[#problems + 1] = entry.path .. " has an unsupported class " .. tostring(entry.className) .. "."
		elseif type(entry.text) ~= "table" or #entry.text == 0 then
			problems[#problems + 1] = entry.path .. " has no source text in the payload."
		else
			seenPaths[entry.path] = true
			classCounts[entry.className] = classCounts[entry.className] + 1
			local joined, source = pcall(table.concat, entry.text)
			if not joined or type(source) ~= "string" or #source == 0 then
				problems[#problems + 1] = entry.path .. ": the source text could not be rebuilt."
			elseif normalizeSource(source) ~= source then
				problems[#problems + 1] = entry.path .. ": the source text is not in the expected normalized form."
			elseif #source ~= entry.bytes or countLines(source) ~= entry.lines or adler32(source) ~= entry.adler32 then
				problems[#problems + 1] = entry.path .. ": checksum mismatch (" .. tostring(#source) .. " bytes, " .. tostring(countLines(source)) .. " lines, checksum " .. tostring(adler32(source)) .. "; expected " .. tostring(entry.bytes) .. ", " .. tostring(entry.lines) .. ", " .. tostring(entry.adler32) .. "). The installer file was changed or damaged: download it again."
			else
				sources[index] = source
			end
		end
	end
	if classCounts.Script ~= 2 or classCounts.LocalScript ~= 1 or classCounts.ModuleScript ~= 21 then
		problems[#problems + 1] = "The payload must hold 2 Scripts, 1 LocalScript and 21 ModuleScripts."
	end
	for index = 1, EXPECTED_FILE_COUNT do
		if sources[index] == nil then
			return nil
		end
	end
	return sources
end

--[[ ---------------------------------------------------------------------- ]]
--[[ Preflight 2: Studio must be in Edit mode, in a local unpublished place    ]]
--[[ ---------------------------------------------------------------------- ]]

local function checkStudioMode(problems)
	local _, RunService = findService("RunService")
	if RunService == nil then
		problems[#problems + 1] = "Could not reach RunService, so the installer cannot tell whether Studio is in Edit mode. Nothing will be changed."
		return "unknown"
	end
	local okStudio, isStudio = pcall(function()
		return RunService:IsStudio()
	end)
	local okEdit, isEdit = pcall(function()
		return RunService:IsEdit()
	end)
	local okRunning, isRunning = pcall(function()
		return RunService:IsRunning()
	end)
	if not (okStudio and okEdit and okRunning) or type(isStudio) ~= "boolean" or type(isEdit) ~= "boolean" or type(isRunning) ~= "boolean" then
		problems[#problems + 1] = "Could not determine whether Studio is in Edit mode, so nothing will be changed. Run the installer from the Command Bar in Edit mode."
		return "unknown"
	end
	if not isStudio then
		problems[#problems + 1] = "This is not Roblox Studio. The installer only runs from the Studio Command Bar."
		return "not Studio"
	end
	if isRunning then
		problems[#problems + 1] = "A playtest is running. Stop it (Shift+F5), then run the installer again in Edit mode."
		return "playtest running"
	end
	if not isEdit then
		problems[#problems + 1] = "Studio is not in Edit mode (a playtest may be paused). Stop it (Shift+F5), then run the installer again."
		return "not Edit mode (paused?)"
	end
	return "Edit mode"
end

local function checkLocalPlace(problems)
	local ok, placeId = pcall(function()
		return game.PlaceId
	end)
	local okGame, gameId = pcall(function()
		return game.GameId
	end)
	say("Place identity: PlaceId " .. (ok and tostring(placeId) or "unreadable") .. ", GameId " .. (okGame and tostring(gameId) or "unreadable") .. ".")
	if not ok or type(placeId) ~= "number" then
		problems[#problems + 1] = "Could not read the place's PlaceId, so the installer cannot confirm this is a local Baseplate."
		return
	end
	if placeId ~= 0 then
		problems[#problems + 1] = "This place reports PlaceId " .. tostring(placeId) .. ", which normally means it is published to Roblox, so the installer refuses it. If this is a NEW Baseplate that you only saved to a file, do not try to work around this: copy this Output and report it (INSTALL_INSTRUCTIONS.md, section 9)."
	else
		say("Place: not published to Roblox (PlaceId 0).")
	end
end

--[[ ---------------------------------------------------------------------- ]]
--[[ Preflight 3: destinations must exist and be free                          ]]
--[[ ---------------------------------------------------------------------- ]]

--[[ Names this installer adds directly under each existing container. ]]
local function reservedNames()
	local reserved = {}
	for _, containerPath in ipairs(CONTAINER_PATHS) do
		reserved[containerPath] = {}
	end
	for _, folder in ipairs(FOLDERS) do
		reserved[folder.container][folder.name] = true
	end
	for _, item in ipairs(LAYOUT) do
		local parentPath, name = splitPath(item.path)
		if reserved[parentPath] ~= nil then
			reserved[parentPath][name] = true
		end
	end
	return reserved
end

--[[ Returns the container instances by path, the Players service and CharacterAutoLoads.
     A missing scan-only service holds no scripts and is skipped; nothing is ever created. ]]
local function checkDestinations(problems, conflicts)
	local containers = {}
	for _, containerPath in ipairs(CONTAINER_PATHS) do
		local container = resolvePath(containerPath)
		if container == nil then
			problems[#problems + 1] = string.gsub(containerPath, "/", ".") .. " was not found. Start again from a new Baseplate."
		else
			containers[containerPath] = container
		end
	end
	local starterPlayerScripts = containers["StarterPlayer/StarterPlayerScripts"]
	if starterPlayerScripts ~= nil and starterPlayerScripts.ClassName ~= "StarterPlayerScripts" then
		problems[#problems + 1] = "StarterPlayer.StarterPlayerScripts is not the normal StarterPlayerScripts object. Start again from a new Baseplate."
		containers["StarterPlayer/StarterPlayerScripts"] = nil
	end
	local reserved = reservedNames()
	for _, containerPath in ipairs(CONTAINER_PATHS) do
		local container = containers[containerPath]
		if container ~= nil then
			local names = {}
			for name in pairs(reserved[containerPath]) do
				names[#names + 1] = name
			end
			table.sort(names)
			for _, name in ipairs(names) do
				local ok, existing = safeChild(container, name)
				if not ok then
					problems[#problems + 1] = "Could not inspect " .. string.gsub(containerPath, "/", ".") .. "."
				elseif existing ~= nil then
					conflicts[#conflicts + 1] = describe(existing) .. " already exists."
				end
			end
		end
	end
	for _, serviceName in ipairs(SCAN_SERVICES) do
		local found, service = findService(serviceName)
		if not found then
			problems[#problems + 1] = "Could not inspect " .. serviceName .. "."
		elseif service ~= nil then
			local ok, descendants = pcall(function()
				return service:GetDescendants()
			end)
			if not ok then
				problems[#problems + 1] = "Could not inspect the contents of " .. serviceName .. "."
			else
				for _, descendant in ipairs(descendants) do
					local isScriptOk, isScript = pcall(function()
						return descendant:IsA("LuaSourceContainer")
					end)
					if not isScriptOk then
						problems[#problems + 1] = "Could not inspect an object in " .. serviceName .. "."
					elseif isScript then
						conflicts[#conflicts + 1] = "Existing script " .. describe(descendant) .. "."
					end
				end
			end
		end
	end
	local _, Players = findService("Players")
	local okAutoLoads, autoLoads = false, nil
	if Players == nil then
		problems[#problems + 1] = "The Players service was not found. Start again from a new Baseplate."
	else
		okAutoLoads, autoLoads = pcall(function()
			return Players.CharacterAutoLoads
		end)
		if not okAutoLoads or type(autoLoads) ~= "boolean" then
			problems[#problems + 1] = "Could not read Players.CharacterAutoLoads."
		end
	end
	return containers, Players, autoLoads
end

--[[ ---------------------------------------------------------------------- ]]
--[[ Post-install verification (installer status only, not a parity result)  ]]
--[[ ---------------------------------------------------------------------- ]]

local function countNamed(parent, name)
	local count = 0
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name then
			count = count + 1
		end
	end
	return count
end

local function verifyInstalled(sources)
	local counts = { scripts = 0, remotes = 0, folders = 0 }
	for _, folder in ipairs(FOLDERS) do
		local node = resolvePath(folder.path)
		if node == nil or node.ClassName ~= "Folder" or countNamed(node.Parent, folder.name) ~= 1 then
			error("folder " .. folder.path .. " is missing or duplicated after installation", 0)
		end
		counts.folders = counts.folders + 1
	end
	local remotesFolder = resolvePath("ReplicatedStorage/Remotes")
	if #remotesFolder:GetChildren() ~= #REMOTES then
		error("ReplicatedStorage.Remotes does not hold exactly " .. tostring(#REMOTES) .. " objects after installation", 0)
	end
	for _, remoteName in ipairs(REMOTES) do
		local ok, remote = safeChild(remotesFolder, remoteName)
		if not ok or remote == nil or remote.ClassName ~= "RemoteEvent" or countNamed(remotesFolder, remoteName) ~= 1 then
			error("RemoteEvent " .. remoteName .. " is missing or duplicated after installation", 0)
		end
		counts.remotes = counts.remotes + 1
	end
	for index, entry in ipairs(FILES) do
		local node = resolvePath(entry.path)
		if node == nil or node.ClassName ~= entry.className then
			error(entry.path .. " is missing or has the wrong class after installation", 0)
		end
		if countNamed(node.Parent, node.Name) ~= 1 then
			error(entry.path .. " is duplicated after installation", 0)
		end
		if normalizeSource(node.Source) ~= sources[index] then
			error(entry.path .. ": the installed text differs from the embedded source", 0)
		end
		if entry.className ~= "ModuleScript" and node.Enabled ~= true then
			error(entry.path .. " is not enabled after installation", 0)
		end
		counts.scripts = counts.scripts + 1
	end
	return counts
end

--[[ ---------------------------------------------------------------------- ]]
--[[ Installation with rollback                                               ]]
--[[ ---------------------------------------------------------------------- ]]

--[[ Removes ONLY objects created by this run, then restores the one setting it changed.
     Objects come first so that a problem with the setting can never stop the cleanup. ]]
local function rollback(built, players, autoLoadsChanged, originalAutoLoads)
	local leftovers = 0
	for index = #built, 1, -1 do
		local instance = built[index]
		pcall(function()
			instance:Destroy()
		end)
	end
	for _, instance in ipairs(built) do
		local okParent, parent = pcall(function()
			return instance.Parent
		end)
		if not okParent or parent ~= nil then
			leftovers = leftovers + 1
			alert("Rollback: could not remove " .. describe(instance) .. ".")
		end
	end
	if autoLoadsChanged then
		local okRead, current = pcall(function()
			return players.CharacterAutoLoads
		end)
		if okRead and current == originalAutoLoads then
			say("Rollback: Players.CharacterAutoLoads is still " .. tostring(originalAutoLoads) .. ".")
		else
			local okWrite = pcall(function()
				players.CharacterAutoLoads = originalAutoLoads
			end)
			local okCheck, now = pcall(function()
				return players.CharacterAutoLoads
			end)
			if okWrite and okCheck and now == originalAutoLoads then
				say("Rollback: Players.CharacterAutoLoads restored to " .. tostring(originalAutoLoads) .. ".")
			else
				leftovers = leftovers + 1
				alert("Rollback: could not restore or confirm Players.CharacterAutoLoads = " .. tostring(originalAutoLoads) .. ". Check it in Properties.")
			end
		end
	end
	if leftovers == 0 then
		say("ROLLBACK COMPLETE: removed the " .. tostring(#built) .. " objects created by this run. Objects that existed before were not touched.")
	else
		alert("ROLLBACK INCOMPLETE: " .. tostring(leftovers) .. " item(s) above could not be undone.")
	end
	alert("Close this place WITHOUT saving, then start again from a new Baseplate.")
end

local function install(sources, containers, players, originalAutoLoads)
	local built = {}
	local autoLoadsChanged = false

	local function create(className, name, parent)
		local instance = Instance.new(className)
		built[#built + 1] = instance
		instance.Name = name
		if parent ~= nil then
			instance.Parent = parent
		end
		return instance
	end

	local ok, failure = pcall(function()
		--[[ Phase 1: build everything outside the place (no visible change yet). ]]
		local folderByPath = {}
		for _, folder in ipairs(FOLDERS) do
			folderByPath[folder.path] = create("Folder", folder.name, nil)
		end
		for _, remoteName in ipairs(REMOTES) do
			create("RemoteEvent", remoteName, folderByPath["ReplicatedStorage/Remotes"])
		end
		local parentByPath = {
			["ReplicatedStorage/Shared"] = folderByPath["ReplicatedStorage/Shared"],
			["ServerScriptService/Tests"] = folderByPath["ServerScriptService/Tests"],
		}
		local topLevel = {}
		for _, folder in ipairs(FOLDERS) do
			topLevel[#topLevel + 1] = { instance = folderByPath[folder.path], container = folder.container }
		end
		for index, entry in ipairs(FILES) do
			local parentPath, name = splitPath(entry.path)
			local scriptObject = create(entry.className, name, parentByPath[parentPath])
			if entry.className ~= "ModuleScript" then
				scriptObject.Enabled = true
			end
			scriptObject.Source = sources[index]
			if normalizeSource(scriptObject.Source) ~= sources[index] then
				error("Studio changed the text of " .. entry.path .. " while it was being set", 0)
			end
			if entry.className == "Script" then
				local okContext, runContext = pcall(function()
					return scriptObject.RunContext
				end)
				if not okContext then
					error("could not read RunContext of " .. entry.path, 0)
				end
				if runContext == Enum.RunContext.Client then
					error(entry.path .. " was created with RunContext = Client", 0)
				end
			end
			if entry.className == "LocalScript" then
				parentByPath[entry.path] = scriptObject
			end
			if parentByPath[parentPath] == nil then
				topLevel[#topLevel + 1] = { instance = scriptObject, container = parentPath }
			end
		end

		--[[ Phase 2: re-check that every destination is still free, then add everything. ]]
		local recheckProblems, recheckConflicts = {}, {}
		checkDestinations(recheckProblems, recheckConflicts)
		if #recheckProblems > 0 or #recheckConflicts > 0 then
			error("the place changed after the check; nothing was added", 0)
		end
		for _, item in ipairs(topLevel) do
			item.instance.Parent = containers[item.container]
		end

		--[[ Phase 3: the one setting. ]]
		if originalAutoLoads ~= false then
			autoLoadsChanged = true
			players.CharacterAutoLoads = false
		end
		if players.CharacterAutoLoads ~= false then
			error("Players.CharacterAutoLoads could not be set to false", 0)
		end

		--[[ Phase 4: confirm the result. ]]
		return verifyInstalled(sources)
	end)

	if not ok then
		alert("INSTALLATION FAILED: " .. tostring(failure))
		local rolledBack, rollbackError = pcall(rollback, built, players, autoLoadsChanged, originalAutoLoads)
		if not rolledBack then
			alert("ROLLBACK INCOMPLETE: the rollback stopped with an unexpected error: " .. tostring(rollbackError))
			alert("Close this place WITHOUT saving, then start again from a new Baseplate.")
		end
		return false
	end
	local counts = failure
	say("INSTALLATION COMPLETE")
	say("Scripts: " .. tostring(counts.scripts) .. "/" .. tostring(EXPECTED_FILE_COUNT))
	say("RemoteEvents: " .. tostring(counts.remotes) .. "/" .. tostring(#REMOTES))
	say("Required folders: " .. tostring(counts.folders) .. "/" .. tostring(#FOLDERS))
	if autoLoadsChanged then
		say("Players.CharacterAutoLoads: false (changed from " .. tostring(originalAutoLoads) .. " by this run)")
	else
		say("Players.CharacterAutoLoads: false (it was already false)")
	end
	say("These are installer status messages, not a parity result.")
	say("Next: save the place (File > Save to File), then run the Appendix B parity checker from M2_STUDIO_REGRESSION_GUIDE.md.")
	return true
end

--[[ ---------------------------------------------------------------------- ]]
--[[ Main                                                                     ]]
--[[ ---------------------------------------------------------------------- ]]

local function run()
	say("Emberbound Milestone 2 installer v" .. INSTALLER_VERSION)
	say("Frozen source commit: " .. FROZEN_COMMIT)
	if ENABLE_INSTALLATION == true then
		say("Mode: INSTALL (ENABLE_INSTALLATION = true). Checks run first; nothing is changed if any check fails.")
	else
		say("Mode: CHECK ONLY (ENABLE_INSTALLATION = false). Nothing will be changed.")
	end

	local problems, conflicts = {}, {}
	local sources = checkPayload(problems)
	if sources ~= nil then
		say("Embedded source: " .. tostring(EXPECTED_FILE_COUNT) .. "/" .. tostring(EXPECTED_FILE_COUNT) .. " files; sizes, line counts and checksums match the frozen commit.")
	end
	local studioMode = checkStudioMode(problems)
	say("Studio mode: " .. studioMode)
	checkLocalPlace(problems)
	local containers, players, originalAutoLoads = checkDestinations(problems, conflicts)

	if #conflicts == 0 then
		say("Existing objects: no conflicts.")
	else
		alert("Existing objects: " .. tostring(#conflicts) .. " conflict(s). This is not a fresh Baseplate:")
		for index, conflict in ipairs(conflicts) do
			if index > 15 then
				alert("  ... and " .. tostring(#conflicts - 15) .. " more.")
				break
			end
			alert("  " .. conflict)
		end
	end
	for _, problem in ipairs(problems) do
		alert("PROBLEM: " .. problem)
	end
	if type(originalAutoLoads) == "boolean" then
		say("Players.CharacterAutoLoads is currently " .. tostring(originalAutoLoads) .. (originalAutoLoads and "; installation sets it to false." or "; installation leaves it false."))
	end

	local ready = sources ~= nil and #problems == 0 and #conflicts == 0
	if not ready then
		say("Safe to modify this place: NO")
		say("Ready to install: NO")
		if #conflicts > 0 then
			say("Use a NEW Baseplate: File > New (Baseplate), then File > Save to File As... Emberbound_M2_QA.rbxl. The installer never overwrites or deletes existing objects.")
		end
		say("Nothing was changed.")
		return
	end
	say("Safe to modify this place: YES")
	say("Will create: " .. tostring(#FOLDERS) .. " folders, " .. tostring(#REMOTES) .. " RemoteEvents, " .. tostring(EXPECTED_FILE_COUNT) .. " scripts.")
	say("Ready to install: YES")
	if ENABLE_INSTALLATION ~= true then
		say("CHECK COMPLETE. Nothing was changed. To install: set ENABLE_INSTALLATION = true near the top of the file, then copy and paste the whole file into the Command Bar again.")
		return
	end
	install(sources, containers, players, originalAutoLoads)
end

local ranOk, unexpected = pcall(run)
if not ranOk then
	warn(PREFIX .. " The installer stopped because of an unexpected error: " .. tostring(unexpected))
	warn(PREFIX .. " Copy this Output and report it. If INSTALLATION FAILED or ROLLBACK lines appear above, close this place WITHOUT saving.")
end
