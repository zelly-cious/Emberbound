--!strict
--[[
	CombatService
	Location: ServerScriptService > CombatService (ModuleScript)

	Server-authoritative combat for every player:
	  - owns each player's combat state (stage, gold, tap damage, enemy HP)
	  - validates and rate-limits attack requests
	  - applies all damage through ONE function (ApplyDamage) so future damage
	    sources (hero DPS) share the exact same death/reward/stage logic
	  - sends authoritative updates only to the player they belong to

	The client never sends numbers. RequestAttack and ClientReady carry no
	arguments, and anything an exploiter adds to them is ignored.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

type CombatSnapshot = GameConfig.CombatSnapshot
type CombatUpdate = GameConfig.CombatUpdate
type DamageSource = GameConfig.DamageSource

type PlayerCombatState = {
	stage: number,
	gold: number,
	tapDamage: number,
	enemyId: number,
	enemyName: string,
	enemyHp: number,
	enemyMaxHp: number,
	lastTapAt: number, -- os.clock() of the last ACCEPTED tap
	lastSyncAt: number, -- os.clock() of the last full sync sent
}

local REMOTE_WAIT_TIMEOUT = 10

local remotesFolder = ReplicatedStorage:WaitForChild(GameConfig.Network.RemotesFolderName)

local function getRemoteEvent(remoteName: string): RemoteEvent
	local instance = remotesFolder:WaitForChild(remoteName, REMOTE_WAIT_TIMEOUT)
	if instance and instance:IsA("RemoteEvent") then
		return instance
	end
	error(`[CombatService] Missing RemoteEvent ReplicatedStorage.{GameConfig.Network.RemotesFolderName}.{remoteName}`)
end

local requestAttackRemote = getRemoteEvent(GameConfig.Network.RequestAttack)
local clientReadyRemote = getRemoteEvent(GameConfig.Network.ClientReady)
local combatUpdateRemote = getRemoteEvent(GameConfig.Network.CombatUpdate)

local playerStates: { [Player]: PlayerCombatState } = {}
local started = false

local CombatService = {}

local function countTrackedPlayers(): number
	local count = 0
	for _ in playerStates do
		count += 1
	end
	return count
end

local function logLifecycle(message: string)
	if GameConfig.Debug.LogPlayerLifecycle then
		print(`[CombatService] {message} (tracked players: {countTrackedPlayers()})`)
	end
end

-- Replaces the current enemy with a fresh one for the state's current stage.
local function spawnEnemy(state: PlayerCombatState)
	state.enemyId += 1
	state.enemyName = GameConfig.GetEnemyName(state.stage)
	state.enemyMaxHp = GameConfig.GetEnemyMaxHp(state.stage)
	state.enemyHp = state.enemyMaxHp
end

local function createState(): PlayerCombatState
	local combat = GameConfig.Combat
	local state: PlayerCombatState = {
		stage = combat.StartingStage,
		gold = combat.StartingGold,
		tapDamage = combat.StartingTapDamage,
		enemyId = 0,
		enemyName = "",
		enemyHp = 0,
		enemyMaxHp = 0,
		lastTapAt = -math.huge,
		lastSyncAt = -math.huge,
	}
	spawnEnemy(state)
	return state
end

local function buildSnapshot(state: PlayerCombatState): CombatSnapshot
	return {
		stage = state.stage,
		gold = state.gold,
		tapDamage = state.tapDamage,
		enemyId = state.enemyId,
		enemyName = state.enemyName,
		enemyHp = state.enemyHp,
		enemyMaxHp = state.enemyMaxHp,
	}
end

-- FireClient targets exactly one player, so updates are never broadcast.
local function sendUpdate(player: Player, update: CombatUpdate)
	if player.Parent ~= Players then
		return
	end
	combatUpdateRemote:FireClient(player, update)
end

local function getOrCreateState(player: Player): PlayerCombatState?
	if player.Parent ~= Players then
		return nil -- leaving or already gone; never recreate state for them
	end
	local existing = playerStates[player]
	if existing then
		return existing
	end
	local state = createState()
	playerStates[player] = state
	logLifecycle(`Created combat state for {player.Name}`)
	return state
end

local function isValidDamageAmount(amount: number): boolean
	return typeof(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

--[[
	The ONLY place damage is applied. Taps call it today; hero DPS can call it later.

	Exactly-once death processing: this function never yields, and Roblox runs
	each event handler to completion before starting the next one. The HP check,
	gold award, stage advance and next-enemy spawn therefore happen as one
	uninterrupted step. Any tap processed afterwards hits the NEW enemy (which
	has full HP), so the same enemy can never be rewarded twice.
]]
function CombatService.ApplyDamage(player: Player, amount: number, source: DamageSource): boolean
	local state = playerStates[player]
	if not state then
		return false
	end
	if not isValidDamageAmount(amount) then
		warn(`[CombatService] Rejected invalid damage amount {amount} for {player.Name}`)
		return false
	end

	local appliedDamage = math.min(amount, state.enemyHp)
	state.enemyHp -= appliedDamage

	if state.enemyHp > 0 then
		sendUpdate(player, {
			kind = "Hit",
			snapshot = buildSnapshot(state),
			damage = appliedDamage,
			source = source,
		})
		return true
	end

	-- Enemy defeated: reward for the stage it belonged to, then advance.
	local goldAwarded = GameConfig.GetGoldReward(state.stage)
	state.gold += goldAwarded
	state.stage += 1
	spawnEnemy(state)

	sendUpdate(player, {
		kind = "Defeated",
		snapshot = buildSnapshot(state),
		damage = appliedDamage,
		source = source,
		goldAwarded = goldAwarded,
	})
	return true
end

local function handleTapRequest(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end

	local now = os.clock()
	if now - state.lastTapAt < GameConfig.Combat.TapCooldown then
		return -- too soon: silently drop (no reply, so spam costs the server almost nothing)
	end
	state.lastTapAt = now

	-- Damage comes from server state, never from the client.
	CombatService.ApplyDamage(player, state.tapDamage, "Tap")
end

local function handleClientReady(player: Player)
	-- Created lazily as well, so the handshake works even if this event
	-- arrives before PlayerAdded was processed.
	local state = getOrCreateState(player)
	if not state then
		return
	end

	local now = os.clock()
	if now - state.lastSyncAt < GameConfig.Network.ClientReadyCooldown then
		return
	end
	state.lastSyncAt = now

	sendUpdate(player, {
		kind = "Sync",
		snapshot = buildSnapshot(state),
	})
end

function CombatService.AddPlayer(player: Player)
	getOrCreateState(player)
end

function CombatService.RemovePlayer(player: Player)
	if playerStates[player] then
		playerStates[player] = nil
		logLifecycle(`Removed combat state for {player.Name}`)
	end
end

-- Connects the remote handlers. Safe to call once; repeated calls are ignored.
function CombatService.Start()
	if started then
		warn("[CombatService] Start() was called more than once; ignoring.")
		return
	end
	started = true

	-- Extra arguments sent by a client are deliberately not read.
	requestAttackRemote.OnServerEvent:Connect(function(player: Player)
		handleTapRequest(player)
	end)

	clientReadyRemote.OnServerEvent:Connect(function(player: Player)
		handleClientReady(player)
	end)
end

return CombatService
