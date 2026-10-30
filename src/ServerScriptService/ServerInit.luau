--!strict
--[[
	ServerInit
	Location: ServerScriptService > ServerInit (Script)

	Server entry point. Starts the services' remote handlers, then the player
	lifecycle. PlayerSessionService picks up players who joined before this
	script ran, so startup order never matters.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local UpgradeService = require(ServerScriptService:WaitForChild("UpgradeService"))
local PlayerSessionService = require(ServerScriptService:WaitForChild("PlayerSessionService"))

-- The prototype has no avatar. This is also set in Studio; the runtime check is a safety net.
if Players.CharacterAutoLoads then
	warn("[ServerInit] Players.CharacterAutoLoads should be false (see setup guide). Disabling it at runtime.")
	Players.CharacterAutoLoads = false
end

-- Remote handlers first, then the lifecycle (which may immediately add players already in the game).
CombatService.Start()
UpgradeService.Start()
PlayerSessionService.Start()
