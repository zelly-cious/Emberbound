--!strict
--[[
	GameConfig
	Location: ReplicatedStorage > Shared > GameConfig (ModuleScript)

	Single source of truth for combat balancing values, scaling formulas and the
	client/server network contract. The server uses these values for all
	authoritative math; the client only uses them for display and for
	throttling its own requests.

	Milestone 2: the scaling formulas return BigNum values, and every large
	value crosses the network as a canonical BigNum string.
]]

local BigNum = require(script.Parent:WaitForChild("BigNum"))

type BigNum = BigNum.BigNum

-- Where a hit came from. Future systems (hero DPS) add their own source here.
export type DamageSource = "Tap"

-- Everything the client needs to render the current combat state.
-- Text fields hold canonical BigNum strings (BigNum.toString / BigNum.parse).
export type CombatSnapshot = {
	stage: number,
	tapDamage: string,
	enemyId: number, -- increments every time a new enemy spawns
	enemyName: string,
	enemyHp: string,
	enemyMaxHp: string,
}

-- "Stats" means a combat stat (tap damage) changed without a hit.
export type CombatUpdateKind = "Sync" | "Hit" | "Defeated" | "Stats"

-- Payload of the CombatUpdate RemoteEvent (server -> one client).
export type CombatUpdate = {
	kind: CombatUpdateKind,
	snapshot: CombatSnapshot, -- always the full, authoritative state after the change
	damage: string?, -- damage applied by this hit ("Hit" and "Defeated")
	source: DamageSource?,
	goldAwarded: string?, -- only on "Defeated"
}

-- Payload of the CurrencyUpdate RemoteEvent: every balance the player has, as BigNum strings.
export type CurrencyUpdate = {
	balances: { [string]: string },
}

-- One upgrade as the client sees it. Values are BigNum strings; next fields are nil at max level.
export type UpgradeView = {
	upgradeId: string,
	level: number,
	maxLevel: number,
	currencyId: string,
	currentValue: string,
	nextValue: string?,
	nextCost: string?,
}

-- EffectFailed (M2.1): the upgrade's new stat could not be applied, so nothing was charged. The client shows "Purchase failed".
export type PurchaseReason = "Ok" | "InsufficientFunds" | "MaxLevel" | "EffectFailed"

export type PurchaseResult = {
	requestId: number,
	upgradeId: string,
	success: boolean,
	reason: PurchaseReason,
}

export type UpgradeUpdateKind = "Sync" | "PurchaseResult"

-- Payload of the UpgradeUpdate RemoteEvent (server -> one client).
export type UpgradeUpdate = {
	kind: UpgradeUpdateKind,
	upgrades: { [string]: UpgradeView },
	result: PurchaseResult?,
}

local GameConfig = {}

GameConfig.Combat = table.freeze({
	StartingStage = 1,
	StartingGold = 0,
	StartingTapDamage = 1,

	StartingEnemyHp = 10,
	EnemyHpMultiplier = 1.18, -- per stage

	StartingGoldReward = 5,
	GoldRewardMultiplier = 1.12, -- per stage

	TapCooldown = 0.07, -- seconds between accepted taps (enforced by the server)

	DefaultEnemyName = "Forest Slime",
})

GameConfig.Network = table.freeze({
	RemotesFolderName = "Remotes",
	RequestAttack = "RequestAttack", -- client -> server, no arguments
	ClientReady = "ClientReady", -- client -> server, no arguments
	CombatUpdate = "CombatUpdate", -- server -> client, CombatUpdate payload
	RequestUpgrade = "RequestUpgrade", -- client -> server, (upgradeId: string, requestId: number)
	UpgradeUpdate = "UpgradeUpdate", -- server -> client, UpgradeUpdate payload
	CurrencyUpdate = "CurrencyUpdate", -- server -> client, CurrencyUpdate payload
	ClientReadyCooldown = 1, -- seconds; limits how often a client can request a full sync
	UpgradeRequestBurst = 10, -- upgrade requests a player may send back to back
	UpgradeRequestsPerSecond = 8, -- sustained upgrade request rate per player
})

GameConfig.Debug = table.freeze({
	LogPlayerLifecycle = true, -- prints when combat state is created/removed (useful while prototyping)
	LogEconomy = false, -- prints every Gold grant and spend
})

-- EnemyMaxHP(stage) = floor(10 * 1.18^(stage - 1)); never overflows, and matches Milestone 1 below 2^53.
function GameConfig.GetEnemyMaxHp(stage: number): BigNum
	local combat = GameConfig.Combat
	local hp = BigNum.scaledPower(combat.StartingEnemyHp, combat.EnemyHpMultiplier, math.max(stage - 1, 0))
	return BigNum.max(BigNum.floor(hp), BigNum.one)
end

-- GoldReward(stage) = floor(5 * 1.12^(stage - 1)); never overflows, and matches Milestone 1 below 2^53.
function GameConfig.GetGoldReward(stage: number): BigNum
	local combat = GameConfig.Combat
	return BigNum.floor(BigNum.scaledPower(combat.StartingGoldReward, combat.GoldRewardMultiplier, math.max(stage - 1, 0)))
end

-- Only one enemy type exists so far. Later milestones can vary this by stage.
function GameConfig.GetEnemyName(_stage: number): string
	return GameConfig.Combat.DefaultEnemyName
end

-- Fail fast on obviously broken balancing edits instead of producing silent bugs.
local function validate()
	local combat = GameConfig.Combat
	assert(combat.StartingStage >= 1 and combat.StartingStage % 1 == 0, "GameConfig: StartingStage must be a whole number >= 1")
	assert(combat.StartingGold >= 0, "GameConfig: StartingGold must be >= 0")
	assert(combat.StartingTapDamage > 0, "GameConfig: StartingTapDamage must be > 0")
	assert(combat.StartingEnemyHp >= 1, "GameConfig: StartingEnemyHp must be >= 1")
	assert(combat.EnemyHpMultiplier > 0, "GameConfig: EnemyHpMultiplier must be > 0")
	assert(combat.StartingGoldReward >= 0, "GameConfig: StartingGoldReward must be >= 0")
	assert(combat.GoldRewardMultiplier > 0, "GameConfig: GoldRewardMultiplier must be > 0")
	assert(combat.TapCooldown >= 0, "GameConfig: TapCooldown must be >= 0")

	local network = GameConfig.Network
	assert(network.UpgradeRequestBurst >= 1, "GameConfig: UpgradeRequestBurst must be >= 1")
	assert(network.UpgradeRequestsPerSecond > 0, "GameConfig: UpgradeRequestsPerSecond must be > 0")
end

validate()

return table.freeze(GameConfig)
