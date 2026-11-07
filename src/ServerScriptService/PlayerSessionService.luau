--!strict
--[[
	PlayerSessionService
	Location: ServerScriptService > PlayerSessionService (ModuleScript)

	The single place that controls each player's lifecycle across services:
	  join  -> PlayerDataService loads and locks the profile (this yields), then
	           CurrencyService, CombatService, StatService, UpgradeService add the
	           player from it (in that order, without yielding)
	  ready -> the client's ClientReady triggers one full sync from every service
	  leave -> the current state is read in one step and handed to
	           PlayerDataService.Release, then the services remove the player in
	           reverse order

	Startup order never matters: players already in the game are added on
	Start(), and a ClientReady that arrives before a player is added (or while
	the profile load is running) is remembered and answered when ready.

	A failed load never starts the player on default data: the player is asked
	to rejoin, and their stored profile is left untouched. HeroService and
	SummonService later join the same add / sync / remove sequence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local StatService = require(ServerScriptService:WaitForChild("StatService"))
local UpgradeService = require(ServerScriptService:WaitForChild("UpgradeService"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))

type Profile = ProfileSchema.Profile

type Session = {
	ready: boolean,
	failed: boolean, -- the profile could not be loaded; the player has been asked to rejoin
	syncRequested: boolean,
	lastSyncAt: number,
	activeSeconds: number, -- carried from the loaded profile (decision 7; the counter is not built yet)
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

-- The player's current profile, read from the services in one step (no yields), so Gold,
-- stage and levels are always saved as one consistent set. nil if any service lacks the player.
local function buildProfile(player: Player): Profile?
	local session = sessions[player]
	if session == nil or not session.ready then
		return nil
	end
	local profile = ProfileSchema.new()
	for _, currency in ProgressionConfig.Currencies do
		local balance = CurrencyService.GetBalance(player, currency.id)
		if balance == nil then
			return nil
		end
		profile.currencies[currency.id] = balance
	end
	local stage = CombatService.GetStage(player)
	if stage == nil then
		return nil
	end
	profile.stage = stage
	for _, definition in ProgressionConfig.Upgrades do
		local level = UpgradeService.GetLevel(player, definition.id)
		if level == nil then
			return nil
		end
		profile.upgrades[definition.id] = level
	end
	profile.activeSeconds = session.activeSeconds
	return profile
end

local function removePlayer(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	-- Read the final state before the services forget the player. A load still in flight
	-- releases its own lock when it finishes (see addPlayer).
	PlayerDataService.Release(player, buildProfile(player))
	sessions[player] = nil
	UpgradeService.RemovePlayer(player)
	StatService.RemovePlayer(player)
	CombatService.RemovePlayer(player)
	CurrencyService.RemovePlayer(player)
end

local function addPlayer(player: Player)
	if sessions[player] or player.Parent ~= Players then
		return
	end
	local session: Session = {
		ready = false,
		failed = false,
		syncRequested = false,
		lastSyncAt = -math.huge,
		activeSeconds = 0,
	}
	sessions[player] = session

	local profile, message = PlayerDataService.Load(player, function(): boolean
		return sessions[player] == session and player.Parent == Players
	end)
	if sessions[player] ~= session or player.Parent ~= Players then
		PlayerDataService.Release(player, nil) -- left while loading: unlock, keep the stored profile
		if sessions[player] == session then
			sessions[player] = nil
		end
		return
	end
	if profile == nil then
		session.failed = true
		player:Kick(message)
		return
	end
	local loaded = profile :: Profile
	session.activeSeconds = loaded.activeSeconds

	local success, problem = pcall(function()
		CurrencyService.AddPlayer(player, loaded.currencies)
		CombatService.AddPlayer(player, loaded.stage)
		StatService.AddPlayer(player) -- needs CombatService; UpgradeService then reports the base tap damage
		UpgradeService.AddPlayer(player, loaded.upgrades)
	end)
	if not success then
		warn(`[PlayerSessionService] Could not start a session for {player.Name}: {problem}`)
		removePlayer(player) -- not ready, so the stored profile is kept; the client's ClientReady retry tries again
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
	if session == nil or session.failed then
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

	PlayerDataService.Start(buildProfile)
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	clientReadyRemote.OnServerEvent:Connect(function(player: Player)
		onClientReady(player)
	end)

	-- addPlayer is idempotent, so a player caught by both PlayerAdded and this loop is handled once.
	-- Each load yields, so every player already in the game loads in parallel.
	for _, player in Players:GetPlayers() do
		task.spawn(addPlayer, player)
	end
end

return PlayerSessionService
