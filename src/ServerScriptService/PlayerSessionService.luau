--!strict
--[[
	PlayerSessionService
	Location: ServerScriptService > PlayerSessionService (ModuleScript)

	The single place that controls each player's lifecycle across services:
	  join  -> CurrencyService, CombatService, UpgradeService add the player (in that order)
	  ready -> the client's ClientReady triggers one full sync from every service
	  leave -> the services remove the player in reverse order

	Startup order never matters: players already in the game are added on
	Start(), and a ClientReady that arrives before a player is added (or while
	a future profile load is running) is remembered and answered when ready.

	Milestone 3 inserts PlayerDataService's profile load here, before the
	services add the player. HeroService and SummonService later join the same
	add / sync / remove sequence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))
local UpgradeService = require(ServerScriptService:WaitForChild("UpgradeService"))

type Session = {
	ready: boolean,
	syncRequested: boolean,
	lastSyncAt: number,
}

local REMOTE_WAIT_TIMEOUT = 10

local remotesFolder = ReplicatedStorage:WaitForChild(GameConfig.Network.RemotesFolderName)

local function getRemoteEvent(remoteName: string): RemoteEvent
	local instance = remotesFolder:WaitForChild(remoteName, REMOTE_WAIT_TIMEOUT)
	if instance and instance:IsA("RemoteEvent") then
		return instance
	end
	error(`[PlayerSessionService] Missing RemoteEvent ReplicatedStorage.{GameConfig.Network.RemotesFolderName}.{remoteName}`)
end

local clientReadyRemote = getRemoteEvent(GameConfig.Network.ClientReady)

local sessions: { [Player]: Session } = {}
local started = false

local PlayerSessionService = {}

-- Economy first and combat last: the combat sync is what lets the client start tapping.
local function syncPlayer(player: Player)
	CurrencyService.SyncPlayer(player)
	UpgradeService.SyncPlayer(player)
	CombatService.SyncPlayer(player)
end

local function removePlayer(player: Player)
	if sessions[player] == nil then
		return
	end
	sessions[player] = nil
	UpgradeService.RemovePlayer(player)
	CombatService.RemovePlayer(player)
	CurrencyService.RemovePlayer(player)
end

local function addPlayer(player: Player)
	if sessions[player] or player.Parent ~= Players then
		return
	end
	local session: Session = {
		ready = false,
		syncRequested = false,
		lastSyncAt = -math.huge,
	}
	sessions[player] = session

	local success, problem = pcall(function()
		CurrencyService.AddPlayer(player)
		CombatService.AddPlayer(player)
		UpgradeService.AddPlayer(player)
	end)
	if not success then
		warn(`[PlayerSessionService] Could not start a session for {player.Name}: {problem}`)
		removePlayer(player) -- the client's ClientReady retry will try again
		return
	end

	session.ready = true
	if session.syncRequested then
		session.syncRequested = false
		session.lastSyncAt = os.clock()
		syncPlayer(player)
	end
end

local function onClientReady(player: Player)
	if sessions[player] == nil then
		addPlayer(player) -- the handshake arrived before PlayerAdded was processed
	end
	local session = sessions[player]
	if session == nil then
		return
	end

	local now = os.clock()
	if now - session.lastSyncAt < GameConfig.Network.ClientReadyCooldown then
		return
	end
	if not session.ready then
		session.syncRequested = true
		return
	end
	session.lastSyncAt = now
	syncPlayer(player)
end

function PlayerSessionService.IsReady(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.ready
end

-- Connects the player lifecycle and the handshake, then adds players already in the game.
function PlayerSessionService.Start()
	if started then
		warn("[PlayerSessionService] Start() was called more than once; ignoring.")
		return
	end
	started = true

	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	clientReadyRemote.OnServerEvent:Connect(function(player: Player)
		onClientReady(player)
	end)

	-- addPlayer is idempotent, so a player caught by both PlayerAdded and this loop is handled once.
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

return PlayerSessionService
