--!strict
--[[
	CombatService
	Location: ServerScriptService > CombatService (ModuleScript)

	Server-authoritative combat for every player:
	  - owns each player's combat state (stage, tap damage, enemy HP)
	  - validates and rate-limits attack requests
	  - applies all damage through ONE function (ApplyDamage), so future damage
	    sources (hero DPS) share the exact same death/reward/stage logic
	  - sends authoritative updates only to the player they belong to

	Milestone 2 changes:
	  - HP and damage are BigNums (exact below 2^53, unlimited above)
	  - the enemy rules live in CombatRules (pure, unit-tested)
	  - Gold lives in CurrencyService; a defeat calls CurrencyService.Grant
	  - SetTapDamage lets UpgradeService change tap damage
	  - the ClientReady handshake moved to PlayerSessionService

	The client never sends numbers. RequestAttack carries no arguments, and
	anything an exploiter adds to it is ignored.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local CombatRules = require(ServerScriptService:WaitForChild("CombatRules"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))

type BigNum = BigNum.BigNum
type CombatState = CombatRules.CombatState
type CombatSnapshot = GameConfig.CombatSnapshot
type CombatUpdate = GameConfig.CombatUpdate
type DamageSource = GameConfig.DamageSource

type PlayerCombatState = {
	combat: CombatState,
	lastTapAt: number, -- os.clock() of the last ACCEPTED tap
	synced: boolean, -- false until the client's first full sync; no partial updates before that
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

local function buildSnapshot(combat: CombatState): CombatSnapshot
	return {
		stage = combat.stage,
		tapDamage = BigNum.toString(combat.tapDamage),
		enemyId = combat.enemyId,
		enemyName = combat.enemyName,
		enemyHp = BigNum.toString(combat.enemyHp),
		enemyMaxHp = BigNum.toString(combat.enemyMaxHp),
	}
end

-- FireClient targets exactly one player, so updates are never broadcast.
local function sendUpdate(player: Player, state: PlayerCombatState, update: CombatUpdate)
	if not state.synced or player.Parent ~= Players then
		return
	end
	combatUpdateRemote:FireClient(player, update)
end

-- Accepts a BigNum or a plain number (Milestone 1 call shape); nil for anything invalid or not positive.
local function toDamage(amount: BigNum | number): BigNum?
	if typeof(amount) == "number" then
		if amount ~= amount or amount <= 0 or amount == math.huge then
			return nil
		end
		return BigNum.fromNumber(amount)
	end
	if not BigNum.isValid(amount) or BigNum.isZero(amount) then
		return nil
	end
	return amount
end

--[[
	The ONLY place damage is applied. Taps call it today; hero DPS can call it later.
	It never yields: the hit, any defeat, the Gold grant and the next spawn
	happen as one uninterrupted step, so an enemy is rewarded exactly once.
]]
function CombatService.ApplyDamage(player: Player, amount: BigNum | number, source: DamageSource): boolean
	local state = playerStates[player]
	if not state then
		return false
	end
	local damage = toDamage(amount)
	if damage == nil then
		warn(`[CombatService] Rejected invalid damage amount for {player.Name}`)
		return false
	end

	local outcome = CombatRules.resolveHit(state.combat, damage)

	if not outcome.defeated then
		sendUpdate(player, state, {
			kind = "Hit",
			snapshot = buildSnapshot(state.combat),
			damage = BigNum.toString(outcome.appliedDamage),
			source = source,
		})
		return true
	end

	if not BigNum.isZero(outcome.goldAwarded) then
		CurrencyService.Grant(player, ProgressionConfig.GoldCurrencyId, outcome.goldAwarded, "EnemyDefeated")
	end

	sendUpdate(player, state, {
		kind = "Defeated",
		snapshot = buildSnapshot(state.combat),
		damage = BigNum.toString(outcome.appliedDamage),
		source = source,
		goldAwarded = BigNum.toString(outcome.goldAwarded),
	})
	return true
end

-- Sets the damage each accepted tap deals. Called by UpgradeService.
function CombatService.SetTapDamage(player: Player, amount: BigNum): boolean
	local state = playerStates[player]
	if not state or not BigNum.isValid(amount) or BigNum.isZero(amount) then
		return false
	end
	state.combat.tapDamage = amount
	sendUpdate(player, state, {
		kind = "Stats",
		snapshot = buildSnapshot(state.combat),
	})
	return true
end

local function handleTapRequest(player: Player)
	local state = playerStates[player]
	if not state or not state.synced then
		return
	end

	local now = os.clock()
	if now - state.lastTapAt < GameConfig.Combat.TapCooldown then
		return -- too soon: silently drop (no reply, so spam costs the server almost nothing)
	end
	state.lastTapAt = now

	-- Damage comes from server state, never from the client.
	CombatService.ApplyDamage(player, state.combat.tapDamage, "Tap")
end

function CombatService.AddPlayer(player: Player)
	if playerStates[player] or player.Parent ~= Players then
		return
	end
	playerStates[player] = {
		combat = CombatRules.newState(),
		lastTapAt = -math.huge,
		synced = false,
	}
	logLifecycle(`Created combat state for {player.Name}`)
end

function CombatService.RemovePlayer(player: Player)
	if playerStates[player] then
		playerStates[player] = nil
		logLifecycle(`Removed combat state for {player.Name}`)
	end
end

function CombatService.HasPlayer(player: Player): boolean
	return playerStates[player] ~= nil
end

-- Sends the full combat state and allows hit/stat updates from now on.
function CombatService.SyncPlayer(player: Player)
	local state = playerStates[player]
	if not state then
		return
	end
	state.synced = true
	sendUpdate(player, state, {
		kind = "Sync",
		snapshot = buildSnapshot(state.combat),
	})
end

-- Connects the attack remote. Safe to call once; repeated calls are ignored.
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
end

return CombatService
