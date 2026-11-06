--!strict
--[[
	StatRulesTests
	Location: ServerScriptService > Tests > StatRulesTests (ModuleScript)

	Milestone 2.1 (DECISIONS.md decision 1): stat combination by source.
	- No modifiers: the combined value is exactly the base, so Milestone 2 tap damage is unchanged.
	- Stacking: flat bonuses, then summed percentages, then multipliers, rounded down once.
	- Modifiers are grouped by source and id; the result does not depend on insertion order.
	- Invalid input is rejected without changing the sheet.
	Exact-string expectations use values that are exact in binary (0.25, 0.5, 1.5, 2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local StatRules = require(ServerScriptService:WaitForChild("StatRules"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

type BigNum = BigNum.BigNum

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectNil = TestKit.expectNil

local TAP = StatRules.Stats.TapDamage

local function n(value: number): BigNum
	return BigNum.fromNumber(value)
end

local function p(text: string): BigNum
	local value = BigNum.parse(text)
	if value == nil then
		error(`test setup: could not parse "{text}"`, 2)
	end
	return value
end

local function combined(sheet: StatRules.Sheet): string
	local value = StatRules.combine(sheet, TAP)
	if value == nil then
		return "nil"
	end
	return BigNum.toString(value)
end

local function sheetWithBase(value: BigNum): StatRules.Sheet
	local sheet = StatRules.newSheet()
	expectTrue(StatRules.setBase(sheet, TAP, value), "setBase accepts a valid value")
	return sheet
end

local tests: { TestKit.TestCase } = {
	{
		name = "with no modifiers the combined value is exactly the base",
		run = function()
			local tap = ProgressionConfig.TapDamageUpgrade
			for _, level in { 1, 2, 24, 25, 26, 100, 510, 1000, 100000 } do
				local base = ProgressionConfig.GetUpgradeValue(tap, level)
				local value = StatRules.combine(sheetWithBase(base), TAP)
				expectTrue(value ~= nil and BigNum.eq(value, base), `level {level}: combined equals the upgrade value`)
				expectEqual(combined(sheetWithBase(base)), BigNum.toString(base), `level {level}: same canonical text`)
			end
			expectEqual(combined(sheetWithBase(p("1.5e400"))), "1.5e400")
		end,
	},
	{
		name = "a stat without a base has no combined value",
		run = function()
			local sheet = StatRules.newSheet()
			expectNil(StatRules.combine(sheet, TAP))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", { flat = n(5) }), "a modifier can wait for the base")
			expectNil(StatRules.combine(sheet, TAP))
			expectTrue(StatRules.setBase(sheet, TAP, n(10)))
			expectEqual(combined(sheet), "15")
		end,
	},
	{
		name = "flat bonuses, then summed percentages, then multipliers",
		run = function()
			local sheet = sheetWithBase(n(10))
			expectTrue(StatRules.setModifier(sheet, TAP, "equipment", "sword", { flat = n(6) }))
			expectEqual(combined(sheet), "16")
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", { percent = 0.25 }))
			expectTrue(StatRules.setModifier(sheet, TAP, "perk", "p1", { percent = 0.25 }))
			expectEqual(combined(sheet), "24", "(10 + 6) * (1 + 0.25 + 0.25): percentages are summed, not compounded")
			expectTrue(StatRules.setModifier(sheet, TAP, "upgrade", "u1", { multiplier = 2 }))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h2", { multiplier = 1.5 }))
			expectEqual(combined(sheet), "72", "24 * 2 * 1.5: multipliers multiply")
		end,
	},
	{
		name = "the result is rounded down once, at the end",
		run = function()
			local sheet = sheetWithBase(n(1))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", { percent = 0.5 }))
			expectTrue(StatRules.setModifier(sheet, TAP, "perk", "p1", { multiplier = 1.5 }))
			-- 1 * 1.5 * 1.5 = 2.25 -> 2. Rounding after each step would give floor(floor(1.5) * 1.5) = 1.
			expectEqual(combined(sheet), "2")
		end,
	},
	{
		name = "tap damage never drops below 1",
		run = function()
			local sheet = sheetWithBase(n(1))
			expectTrue(StatRules.setModifier(sheet, TAP, "perk", "p1", { multiplier = 0.5 }))
			expectEqual(combined(sheet), "1", "0.5 rounds down to 0 but tap damage stays positive")
		end,
	},
	{
		name = "modifiers are grouped by source and id; the same id replaces, never stacks",
		run = function()
			local sheet = sheetWithBase(n(10))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "bonus", { flat = n(5) }))
			expectTrue(StatRules.setModifier(sheet, TAP, "equipment", "bonus", { flat = n(5) }))
			expectEqual(combined(sheet), "20", "the same id in two sources counts twice")
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "bonus", { flat = n(7) }))
			expectEqual(combined(sheet), "22", "setting hero/bonus again replaces it")
			expectEqual(StatRules.countModifiers(sheet, TAP), 2)
		end,
	},
	{
		name = "removing every modifier restores the exact base",
		run = function()
			local base = ProgressionConfig.GetUpgradeValue(ProgressionConfig.TapDamageUpgrade, 25)
			local sheet = sheetWithBase(base)
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", { percent = 0.5, flat = n(3) }))
			expectEqual(combined(sheet), "117", "(75 + 3) * 1.5")
			expectTrue(StatRules.removeModifier(sheet, TAP, "hero", "h1"), "removal reports an existing modifier")
			expectTrue(not StatRules.removeModifier(sheet, TAP, "hero", "h1"), "removing twice reports false")
			expectEqual(StatRules.countModifiers(sheet, TAP), 0)
			local value = StatRules.combine(sheet, TAP)
			expectTrue(value ~= nil and BigNum.eq(value, base), "back to exactly the upgrade value (75)")
		end,
	},
	{
		name = "the result does not depend on the order modifiers were added",
		run = function()
			local modifiers: { { source: StatRules.Source, id: string, modifier: StatRules.Modifier } } = {
				{ source = "perk", id = "p", modifier = { multiplier = 1.5 } },
				{ source = "upgrade", id = "u", modifier = { flat = n(3), percent = 0.25 } },
				{ source = "hero", id = "h", modifier = { percent = 0.5, multiplier = 2 } },
				{ source = "equipment", id = "e", modifier = { flat = n(1) } },
			}
			local forward = sheetWithBase(n(12))
			for index = 1, #modifiers do
				local entry = modifiers[index]
				expectTrue(StatRules.setModifier(forward, TAP, entry.source, entry.id, entry.modifier))
			end
			local backward = sheetWithBase(n(12))
			for index = #modifiers, 1, -1 do
				local entry = modifiers[index]
				expectTrue(StatRules.setModifier(backward, TAP, entry.source, entry.id, entry.modifier))
			end
			expectEqual(combined(forward), combined(backward))
			expectEqual(combined(forward), "84", "(12 + 3 + 1) * (1 + 0.25 + 0.5) * 2 * 1.5")
		end,
	},
	{
		name = "large values combine without overflow",
		run = function()
			local sheet = sheetWithBase(p("1e400"))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", { percent = 0.5 }))
			expectEqual(combined(sheet), "1.5e400")
			expectTrue(StatRules.setModifier(sheet, TAP, "perk", "p1", { multiplier = 1e300 }))
			expectEqual(combined(sheet), "1.5e700")
			expectTrue(StatRules.setModifier(sheet, TAP, "equipment", "e1", { flat = n(5) }))
			expectEqual(combined(sheet), "1.5e700", "a flat 5 is absorbed at 1e400 (bounded precision contract)")
		end,
	},
	{
		name = "invalid stats, sources, ids and modifiers are rejected without changing the sheet",
		run = function()
			local sheet = sheetWithBase(n(10))
			local bad: { { label: string, ok: boolean } } = {
				{ label = "unknown stat", ok = StatRules.setModifier(sheet, "Speed", "hero", "h", { flat = n(1) }) },
				{ label = "unknown source", ok = StatRules.setModifier(sheet, TAP, "pet" :: any, "h", { flat = n(1) }) },
				{ label = "empty id", ok = StatRules.setModifier(sheet, TAP, "hero", "", { flat = n(1) }) },
				{ label = "non-string id", ok = StatRules.setModifier(sheet, TAP, "hero", 7 :: any, { flat = n(1) }) },
				{ label = "empty modifier", ok = StatRules.setModifier(sheet, TAP, "hero", "h", {}) },
				{ label = "unknown field", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { bonus = 1 } :: any) },
				{ label = "flat is not a BigNum", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { flat = 5 :: any }) },
				{ label = "negative percent", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { percent = -0.25 }) },
				{ label = "NaN percent", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { percent = 0 / 0 }) },
				{ label = "zero multiplier", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { multiplier = 0 }) },
				{ label = "negative multiplier", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { multiplier = -2 }) },
				{ label = "infinite multiplier", ok = StatRules.setModifier(sheet, TAP, "hero", "h", { multiplier = math.huge }) },
				{ label = "modifier is not a table", ok = StatRules.setModifier(sheet, TAP, "hero", "h", 3 :: any) },
				{ label = "invalid base", ok = StatRules.setBase(sheet, TAP, { m = -1, e = 0 } :: any) },
				{ label = "base for an unknown stat", ok = StatRules.setBase(sheet, "Speed", n(1)) },
			}
			for _, case in bad do
				expectTrue(not case.ok, `{case.label} is rejected`)
			end
			expectEqual(StatRules.countModifiers(sheet, TAP), 0, "no modifier was stored")
			expectEqual(combined(sheet), "10", "the base is unchanged")
		end,
	},
	{
		name = "stored modifiers are copies the caller cannot change",
		run = function()
			local sheet = sheetWithBase(n(10))
			local modifier: StatRules.Modifier = { flat = n(5) }
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", modifier))
			modifier.flat = n(500)
			expectEqual(combined(sheet), "15", "editing the caller's table after setModifier changes nothing")
		end,
	},
	{
		name = "a multiplier and its inverse cancel even at the largest exponent",
		run = function()
			-- The factors are combined before the sum is multiplied, so x2 then x0.5 never overflows on the way.
			local sheet = sheetWithBase(n(1))
			expectTrue(StatRules.setModifier(sheet, TAP, "equipment", "huge", { flat = p("9e9007199254740991") }))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "double", { multiplier = 2 }) and true)
			expectTrue(StatRules.setModifier(sheet, TAP, "perk", "half", { multiplier = 0.5 }))
			expectEqual(combined(sheet), "9e9007199254740991", "hero x2 (applied first by source order) and perk x0.5 cancel")
		end,
	},
	{
		name = "copySheet makes an independent copy",
		run = function()
			local sheet = sheetWithBase(n(10))
			expectTrue(StatRules.setModifier(sheet, TAP, "hero", "h1", { flat = n(5) }))
			local copy = StatRules.copySheet(sheet)
			expectTrue(StatRules.setModifier(copy, TAP, "hero", "h2", { multiplier = 2 }))
			expectTrue(StatRules.removeModifier(copy, TAP, "hero", "h1"))
			expectTrue(StatRules.setBase(copy, TAP, n(40)))
			expectEqual(combined(copy), "80")
			expectEqual(combined(sheet), "15", "the original keeps its base and its modifiers")
			expectEqual(StatRules.countModifiers(sheet, TAP), 1)
		end,
	},
	{
		name = "combining past the largest exponent raises BigNum's overflow error",
		run = function()
			-- StatService catches this and keeps the previous sheet and tap damage (DEFECT regression for M2.1).
			local sheet = sheetWithBase(n(1))
			expectTrue(StatRules.setModifier(sheet, TAP, "equipment", "huge", { flat = p("9e9007199254740991") }))
			expectEqual(combined(sheet), "9e9007199254740991", "the flat bonus alone is still representable")
			expectTrue(StatRules.setModifier(sheet, TAP, "perk", "double", { multiplier = 2 }))
			local ok, problem = pcall(StatRules.combine, sheet, TAP)
			expectTrue(not ok and string.find(tostring(problem), "overflow", 1, true) ~= nil, "x2 overflows the exponent")
		end,
	},
	{
		name = "separate sheets are independent",
		run = function()
			local first = sheetWithBase(n(10))
			local second = sheetWithBase(n(10))
			expectTrue(StatRules.setModifier(first, TAP, "hero", "h1", { multiplier = 2 }))
			expectEqual(combined(first), "20")
			expectEqual(combined(second), "10")
		end,
	},
}

return {
	name = "StatRulesTests",
	tests = tests,
}
