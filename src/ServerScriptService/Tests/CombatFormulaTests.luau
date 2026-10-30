--!strict
--[[
	CombatFormulaTests
	Location: ServerScriptService > Tests > CombatFormulaTests (ModuleScript)

	Milestone 1 regression: the BigNum versions of the enemy HP and gold reward
	formulas must equal Milestone 1's plain-double formulas wherever those were
	exact (below 2^53), and keep working far beyond a double's range.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue

local TWO_POW_53 = 9007199254740992
local combat = GameConfig.Combat

-- Exactly the expressions Milestone 1's GameConfig used.
local function milestone1EnemyMaxHp(stage: number): number
	return math.max(1, math.floor(combat.StartingEnemyHp * combat.EnemyHpMultiplier ^ math.max(stage - 1, 0)))
end

local function milestone1GoldReward(stage: number): number
	return math.max(0, math.floor(combat.StartingGoldReward * combat.GoldRewardMultiplier ^ math.max(stage - 1, 0)))
end

local tests: { TestKit.TestCase } = {
	{
		name = "enemy HP equals Milestone 1 for every stage below 2^53 (stages 1-209)",
		run = function()
			for stage = 1, 209 do
				local expected = milestone1EnemyMaxHp(stage)
				expectTrue(expected < TWO_POW_53, `stage {stage} is in the exact range`)
				expectTrue(BigNum.eq(GameConfig.GetEnemyMaxHp(stage), BigNum.fromNumber(expected)), `HP at stage {stage}`)
			end
			expectTrue(GameConfig.GetEnemyMaxHp(210).e >= 15, "stage 210 HP is above 2^53 and stored in the large regime")
		end,
	},
	{
		name = "gold reward equals Milestone 1 for every stage below 2^53 (stages 1-310)",
		run = function()
			for stage = 1, 310 do
				local expected = milestone1GoldReward(stage)
				expectTrue(expected < TWO_POW_53, `stage {stage} is in the exact range`)
				expectTrue(BigNum.eq(GameConfig.GetGoldReward(stage), BigNum.fromNumber(expected)), `gold at stage {stage}`)
			end
		end,
	},
	{
		name = "Milestone 1 stage table",
		run = function()
			local hp = { "10", "11", "13", "16", "19", "22", "26", "31", "37", "44", "52" }
			local gold = { "5", "5", "6", "7", "7", "8", "9", "11", "12", "13" }
			for stage, text in hp do
				expectEqual(BigNum.toString(GameConfig.GetEnemyMaxHp(stage)), text, `HP at stage {stage}`)
			end
			for stage, text in gold do
				expectEqual(BigNum.toString(GameConfig.GetGoldReward(stage)), text, `gold at stage {stage}`)
			end
		end,
	},
	{
		name = "late stages stay valid, increasing and beyond 10^308",
		run = function()
			local stages = { 1000, 4275, 4276, 5000, 100000 }
			local previous = GameConfig.GetEnemyMaxHp(999)
			for _, stage in stages do
				local hp = GameConfig.GetEnemyMaxHp(stage)
				expectTrue(BigNum.isValid(hp), `valid HP at stage {stage}`)
				expectTrue(BigNum.gt(hp, previous), `HP increases by stage {stage}`)
				previous = hp
			end
			expectTrue(BigNum.log10(GameConfig.GetEnemyMaxHp(4276)) > 308.25, "stage 4276 HP is past a double's maximum")
			expectTrue(BigNum.isValid(GameConfig.GetGoldReward(100000)), "gold at stage 100000 is valid")
		end,
	},
}

return {
	name = "CombatFormulaTests",
	tests = tests,
}
