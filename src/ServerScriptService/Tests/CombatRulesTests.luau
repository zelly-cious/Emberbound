--!strict
--[[
	CombatRulesTests
	Location: ServerScriptService > Tests > CombatRulesTests (ModuleScript)

	Milestone 1 regression for the combat rules: starting state, exact HP
	reduction, no overkill carry-over, and exactly one defeat and one reward
	per enemy even under a burst of hits.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local CombatRules = require(ServerScriptService:WaitForChild("CombatRules"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue

local function s(value: BigNum.BigNum): string
	return BigNum.toString(value)
end

local tests: { TestKit.TestCase } = {
	{
		name = "new state matches Milestone 1",
		run = function()
			local state = CombatRules.newState()
			expectEqual(state.stage, 1)
			expectEqual(state.enemyId, 1)
			expectEqual(state.enemyName, "Forest Slime")
			expectEqual(s(state.enemyHp), "10")
			expectEqual(s(state.enemyMaxHp), "10")
			expectEqual(s(state.tapDamage), "1")
		end,
	},
	{
		name = "a hit removes exactly its damage",
		run = function()
			local state = CombatRules.newState()
			local outcome = CombatRules.resolveHit(state, BigNum.one)
			expectEqual(s(outcome.appliedDamage), "1")
			expectTrue(not outcome.defeated, "not defeated")
			expectTrue(BigNum.isZero(outcome.goldAwarded), "no gold for a hit")
			expectEqual(s(state.enemyHp), "9")
		end,
	},
	{
		name = "overkill does not carry over to the next enemy",
		run = function()
			local state = CombatRules.newState()
			local outcome = CombatRules.resolveHit(state, BigNum.fromNumber(1000))
			expectEqual(s(outcome.appliedDamage), "10", "applied damage is capped at remaining HP")
			expectTrue(outcome.defeated, "defeated")
			expectEqual(outcome.defeatedStage, 1)
			expectEqual(s(outcome.goldAwarded), "5")
			expectEqual(state.stage, 2)
			expectEqual(state.enemyId, 2)
			expectEqual(s(state.enemyHp), "11", "next enemy at full HP")
			expectEqual(s(state.enemyMaxHp), "11")
		end,
	},
	{
		name = "a burst of hits defeats and rewards each enemy exactly once",
		run = function()
			local state = CombatRules.newState()
			local defeatedIds: { [number]: boolean } = {}
			local defeats = 0
			local totalGold = BigNum.zero
			for _ = 1, 200 do
				local enemyIdBefore = state.enemyId
				local stageBefore = state.stage
				local outcome = CombatRules.resolveHit(state, BigNum.one)
				if outcome.defeated then
					expectTrue(not defeatedIds[enemyIdBefore], `enemy {enemyIdBefore} defeated only once`)
					defeatedIds[enemyIdBefore] = true
					defeats += 1
					expectEqual(outcome.defeatedStage, stageBefore, "defeat belongs to the stage it happened on")
					expectTrue(BigNum.eq(outcome.goldAwarded, GameConfig.GetGoldReward(stageBefore)), "reward for that stage")
					expectEqual(state.stage, stageBefore + 1, "stage advances by exactly one")
					totalGold = BigNum.add(totalGold, outcome.goldAwarded)
				else
					expectEqual(state.enemyId, enemyIdBefore, "no respawn without a defeat")
				end
				expectTrue(not BigNum.isZero(state.enemyHp), "a zero-HP enemy never persists")
			end
			-- HP 10+11+13+16+19+22+26+31+37 = 185 hits for 9 defeats; 15 more hits on the 44 HP stage-10 enemy.
			expectEqual(defeats, 9)
			expectEqual(state.stage, 10)
			expectEqual(s(state.enemyHp), "29")
			expectEqual(s(totalGold), "70", "gold for stages 1-9")
		end,
	},
	{
		name = "ten one-hit kills follow the Milestone 1 stage table",
		run = function()
			local state = CombatRules.newState()
			local expectedGold = { "5", "5", "6", "7", "7", "8", "9", "11", "12", "13" }
			local totalGold = BigNum.zero
			for index, goldText in expectedGold do
				local outcome = CombatRules.resolveHit(state, BigNum.parse("1e100") :: BigNum.BigNum)
				expectTrue(outcome.defeated, `kill {index}`)
				expectEqual(s(outcome.goldAwarded), goldText, `gold for kill {index}`)
				totalGold = BigNum.add(totalGold, outcome.goldAwarded)
			end
			expectEqual(s(totalGold), "83")
			expectEqual(state.stage, 11)
			expectEqual(s(state.enemyHp), "52")
		end,
	},
}

return {
	name = "CombatRulesTests",
	tests = tests,
}
