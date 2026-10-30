--!strict
--[[
	ServerInit
	Location: ServerScriptService > ServerInit (Script)

	Server entry point. Starts CombatService and ties it to the player
	lifecycle. Players who joined before this script ran are picked up by
	the loop at the bottom, so startup order never matters.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatService = require(ServerScriptService:WaitForChild("CombatService"))

-- The prototype has no avatar. This is also set in Studio; the runtime check is a safety net.
if Players.CharacterAutoLoads then
	warn("[ServerInit] Players.CharacterAutoLoads should be false (see setup guide). Disabling it at runtime.")
	Players.CharacterAutoLoads = false
end

CombatService.Start()

Players.PlayerAdded:Connect(function(player: Player)
	CombatService.AddPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	CombatService.RemovePlayer(player)
end)

-- AddPlayer is idempotent, so a player caught by both PlayerAdded and this loop is handled once.
for _, player in Players:GetPlayers() do
	CombatService.AddPlayer(player)
end
