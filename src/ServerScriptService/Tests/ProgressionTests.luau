--!strict
--[[
	ProgressionTests
	Location: ServerScriptService > Tests > ProgressionTests (ModuleScript)

	Tap Damage upgrade curve, cost curve and config lookups.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectError = TestKit.expectError

local tap = ProgressionConfig.TapDamageUpgrade

local function damageText(level: number): string
	return BigNum.toString(ProgressionConfig.GetUpgradeValue(tap, level))
end

local function costText(level: number): string
	return BigNum.toString(ProgressionConfig.GetUpgradeCost(tap, level))
end

local tests: { TestKit.TestCase } = {
	{
		name = "level 1 tap damage equals Milestone 1's starting damage",
		run = function()
			expectTrue(
				BigNum.eq(ProgressionConfig.GetUpgradeValue(tap, 1), BigNum.fromNumber(GameConfig.Combat.StartingTapDamage)),
				"level 1 damage"
			)
		end,
	},
	{
		name = "tap damage curve: level x 3 every 25 levels",
		run = function()
			local expected = {
				[1] = "1",
				[2] = "2",
				[24] = "24",
				[25] = "75",
				[26] = "78",
				[49] = "147",
				[50] = "450",
				[74] = "666",
				[75] = "2025",
				[100] = "8100",
			}
			for level, text in expected do
				expectEqual(damageText(level), text, `damage at level {level}`)
			end
		end,
	},
	{
		name = "tap damage strictly increases with level",
		run = function()
			local previous = ProgressionConfig.GetUpgradeValue(tap, 1)
			for level = 2, 500 do
				local value = ProgressionConfig.GetUpgradeValue(tap, level)
				expectTrue(BigNum.gt(value, previous), `damage increases at level {level}`)
				previous = value
			end
		end,
	},
	{
		name = "cost curve: floor(5 x 1.07^(level - 1))",
		run = function()
			local expected = { "5", "5", "5", "6", "6", "7", "7", "8", "8", "9" }
			for level, text in expected do
				expectEqual(costText(level), text, `cost at level {level}`)
			end
		end,
	},
	{
		name = "costs never decrease and stay finite up to the max level",
		run = function()
			local previous = ProgressionConfig.GetUpgradeCost(tap, 1)
			for level = 2, 2000 do
				local cost = ProgressionConfig.GetUpgradeCost(tap, level)
				expectTrue(BigNum.gte(cost, previous), `cost does not decrease at level {level}`)
				previous = cost
			end
			local topCost = ProgressionConfig.GetUpgradeCost(tap, tap.maxLevel)
			expectTrue(BigNum.isValid(topCost) and topCost.e > 308, "cost at max level is a valid number beyond 1e308")
			local topDamage = ProgressionConfig.GetUpgradeValue(tap, tap.maxLevel)
			expectTrue(BigNum.isValid(topDamage) and topDamage.e > 308, "damage at max level is a valid number beyond 1e308")
		end,
	},
	{
		name = "invalid levels are rejected",
		run = function()
			expectError(function()
				ProgressionConfig.GetUpgradeValue(tap, 0)
			end, "level 0")
			expectError(function()
				ProgressionConfig.GetUpgradeValue(tap, 1.5)
			end, "fractional level")
			expectError(function()
				ProgressionConfig.GetUpgradeValue(tap, tap.maxLevel + 1)
			end, "above max level")
			expectError(function()
				ProgressionConfig.GetUpgradeCost(tap, -3)
			end, "negative level")
		end,
	},
	{
		name = "config lookups",
		run = function()
			expectTrue(ProgressionConfig.GetUpgrade("TapDamage") ~= nil, "TapDamage exists")
			expectTrue(ProgressionConfig.GetUpgrade("NotAnUpgrade") == nil, "unknown upgrade")
			local gold = ProgressionConfig.GetCurrency(ProgressionConfig.GoldCurrencyId)
			expectTrue(gold ~= nil and gold.startingBalance == 0, "Gold exists and starts at 0")
			expectTrue(ProgressionConfig.GetCurrency("PremiumGems") == nil, "no other currencies yet")
			expectEqual(tap.currencyId, ProgressionConfig.GoldCurrencyId, "Tap Damage is bought with Gold")
		end,
	},
}

return {
	name = "ProgressionTests",
	tests = tests,
}
