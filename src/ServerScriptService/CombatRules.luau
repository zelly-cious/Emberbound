--!strict
--[[
	CombatRules
	Location: ServerScriptService > CombatRules (ModuleScript)

	Pure combat rules for one player's state: enemy spawning, applying a hit,
	defeat, reward and stage advance. No Roblox services, no networking, no
	yields, so the Milestone 1 guarantees can be unit-tested directly.
	CombatService owns one state per player and does the networking and Gold.

	Exactly-once defeat: resolveHit never yields. When HP reaches zero it
	computes the reward, advances the stage and spawns the next enemy (full HP)
	in the same step, so the next hit can only damage the new enemy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

type BigNum = BigNum.BigNum

export type CombatState = {
	stage: number,
	tapDamage: BigNum,
	enemyId: number, -- increments every time a new enemy spawns
	enemyName: string,
	enemyHp: BigNum,
	enemyMaxHp: BigNum,
}

export type HitOutcome = {
	appliedDamage: BigNum, -- never more than the HP the enemy had
	defeated: boolean,
	defeatedStage: number, -- the stage the hit happened on
	goldAwarded: BigNum, -- zero unless defeated
}

local CombatRules = {}

-- Replaces the current enemy with a fresh one for the state's current stage.
function CombatRules.spawnEnemy(state: CombatState)
	state.enemyId += 1
	state.enemyName = GameConfig.GetEnemyName(state.stage)
	state.enemyMaxHp = GameConfig.GetEnemyMaxHp(state.stage)
	state.enemyHp = state.enemyMaxHp
end

-- Milestone 1 starting state: stage 1, tap damage 1, a full-HP Forest Slime.
function CombatRules.newState(): CombatState
	local state: CombatState = {
		stage = GameConfig.Combat.StartingStage,
		tapDamage = BigNum.fromNumber(GameConfig.Combat.StartingTapDamage),
		enemyId = 0,
		enemyName = "",
		enemyHp = BigNum.zero,
		enemyMaxHp = BigNum.zero,
	}
	CombatRules.spawnEnemy(state)
	return state
end

-- Applies a validated, positive damage amount. Overkill does not carry over to the next enemy.
function CombatRules.resolveHit(state: CombatState, damage: BigNum): HitOutcome
	local appliedDamage = BigNum.min(damage, state.enemyHp)
	state.enemyHp = BigNum.sub(state.enemyHp, appliedDamage)

	if not BigNum.isZero(state.enemyHp) then
		return {
			appliedDamage = appliedDamage,
			defeated = false,
			defeatedStage = state.stage,
			goldAwarded = BigNum.zero,
		}
	end

	local defeatedStage = state.stage
	local goldAwarded = GameConfig.GetGoldReward(defeatedStage)
	state.stage += 1
	CombatRules.spawnEnemy(state)

	return {
		appliedDamage = appliedDamage,
		defeated = true,
		defeatedStage = defeatedStage,
		goldAwarded = goldAwarded,
	}
end

return table.freeze(CombatRules)
