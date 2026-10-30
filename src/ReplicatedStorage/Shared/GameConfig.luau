--!strict
--[[
	GameConfig
	Location: ReplicatedStorage > Shared > GameConfig (ModuleScript)

	Single source of truth for balancing values, scaling formulas and the
	client/server network contract. The server uses these values for all
	authoritative math; the client only uses them for display and for
	throttling its own requests. Changing a number here changes the game.
]]

-- Where a hit came from. Future systems (hero DPS) add their own source here.
export type DamageSource = "Tap"

-- Everything the client needs to render the current combat state.
export type CombatSnapshot = {
	stage: number,
	gold: number,
	tapDamage: number,
	enemyId: number, -- increments every time a new enemy spawns
	enemyName: string,
	enemyHp: number,
	enemyMaxHp: number,
}

export type CombatUpdateKind = "Sync" | "Hit" | "Defeated"

-- Payload of the CombatUpdate RemoteEvent (server -> one client).
export type CombatUpdate = {
	kind: CombatUpdateKind,
	snapshot: CombatSnapshot, -- always the full, authoritative state after the change
	damage: number?, -- damage applied by this hit ("Hit" and "Defeated")
	source: DamageSource?,
	goldAwarded: number?, -- only on "Defeated"
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
	ClientReadyCooldown = 1, -- seconds; limits how often a client can request a full sync
})

GameConfig.Debug = table.freeze({
	LogPlayerLifecycle = true, -- prints when combat state is created/removed (useful while prototyping)
})

local function scaleByStage(baseValue: number, multiplier: number, stage: number): number
	local stagesAboveFirst = math.max(stage - 1, 0)
	return math.floor(baseValue * multiplier ^ stagesAboveFirst)
end

-- EnemyMaxHP(stage) = floor(10 * 1.18^(stage - 1))
function GameConfig.GetEnemyMaxHp(stage: number): number
	local combat = GameConfig.Combat
	return math.max(1, scaleByStage(combat.StartingEnemyHp, combat.EnemyHpMultiplier, stage))
end

-- GoldReward(stage) = floor(5 * 1.12^(stage - 1))
function GameConfig.GetGoldReward(stage: number): number
	local combat = GameConfig.Combat
	return math.max(0, scaleByStage(combat.StartingGoldReward, combat.GoldRewardMultiplier, stage))
end

-- Only one enemy type exists in Milestone 1. Later milestones can vary this by stage.
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
end

validate()

return table.freeze(GameConfig)
