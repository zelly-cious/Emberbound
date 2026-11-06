--!strict
--[[
	StatRules
	Location: ServerScriptService > StatRules (ModuleScript)

	Pure stat math for StatService (Milestone 2.1, DECISIONS.md decision 1). No Roblox
	services, no networking and no yields, so it is unit-tested directly (StatRulesTests).

	A sheet holds one player's base stats and the modifiers on top of them, grouped by
	source ("upgrade", "hero", "equipment", "perk") and keyed by an id within that source.
	Setting a modifier with the same source and id replaces it; it never stacks with itself.

	Combined value of a stat (decision 1's proposed stacking; the final rule is an M5
	balancing decision):

		floor((base + sum of flat bonuses) * (1 + sum of percentage bonuses) * product of multipliers)

	It is rounded down ONCE, at the end, and is never below the stat's minimum (tap damage 1,
	because CombatService only accepts a positive tap damage). Modifiers are combined in a
	fixed order (source order above, then modifier id), so the result never depends on the
	order in which they were added. With no modifiers the combined value is exactly the base,
	the same BigNum value Milestone 2 applied directly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))

type BigNum = BigNum.BigNum

export type Source = "upgrade" | "hero" | "equipment" | "perk"

-- Any field may be omitted; at least one must be present.
export type Modifier = {
	flat: BigNum?, -- added to the base
	percent: number?, -- 0.25 = +25%; percentages from all sources are summed, not compounded
	multiplier: number?, -- 2 = x2; multipliers from all sources are multiplied together
}

export type Sheet = {
	base: { [string]: BigNum },
	modifiers: { [string]: { [string]: { [string]: Modifier } } }, -- stat -> source -> modifier id -> modifier
}

local StatRules = {}

StatRules.Stats = table.freeze({
	TapDamage = "TapDamage",
})

-- Combination order of the sources.
StatRules.Sources = table.freeze({ "upgrade", "hero", "equipment", "perk" }) :: { Source }

local MINIMUM: { [string]: BigNum } = {
	TapDamage = BigNum.one,
}

local function isStat(statId: unknown): boolean
	return typeof(statId) == "string" and MINIMUM[statId :: string] ~= nil
end

local function isSource(source: unknown): boolean
	return typeof(source) == "string" and table.find(StatRules.Sources, source :: Source) ~= nil
end

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- A frozen copy of a valid modifier, or nil for anything invalid.
local function copyModifier(modifier: unknown): Modifier?
	if typeof(modifier) ~= "table" then
		return nil
	end
	local raw = modifier :: { [any]: any }
	for key in raw do
		if key ~= "flat" and key ~= "percent" and key ~= "multiplier" then
			return nil
		end
	end
	local flat, percent, multiplier = raw.flat, raw.percent, raw.multiplier
	if flat == nil and percent == nil and multiplier == nil then
		return nil
	end
	if flat ~= nil and not BigNum.isValid(flat) then
		return nil
	end
	if percent ~= nil and (typeof(percent) ~= "number" or not isFinite(percent) or percent < 0) then
		return nil
	end
	if multiplier ~= nil and (typeof(multiplier) ~= "number" or not isFinite(multiplier) or multiplier <= 0) then
		return nil
	end
	local copy: Modifier = { flat = flat, percent = percent, multiplier = multiplier }
	table.freeze(copy :: any)
	return copy
end

function StatRules.newSheet(): Sheet
	return { base = {}, modifiers = {} }
end

-- Sets a stat's base value (for tap damage: the Tap Damage upgrade's value). False if invalid.
function StatRules.setBase(sheet: Sheet, statId: string, value: BigNum): boolean
	if not isStat(statId) or not BigNum.isValid(value) then
		return false
	end
	sheet.base[statId] = value
	return true
end

-- Adds or replaces the modifier `modifierId` from `source`. False (and no change) if anything is invalid.
function StatRules.setModifier(sheet: Sheet, statId: string, source: Source, modifierId: string, modifier: Modifier): boolean
	if not isStat(statId) or not isSource(source) or typeof(modifierId) ~= "string" or modifierId == "" then
		return false
	end
	local copy = copyModifier(modifier)
	if copy == nil then
		return false
	end
	local bySource = sheet.modifiers[statId]
	if bySource == nil then
		bySource = {}
		sheet.modifiers[statId] = bySource
	end
	local entries = bySource[source]
	if entries == nil then
		entries = {}
		bySource[source] = entries
	end
	entries[modifierId] = copy
	return true
end

-- Removes a modifier. True if it existed.
function StatRules.removeModifier(sheet: Sheet, statId: string, source: Source, modifierId: string): boolean
	local bySource = sheet.modifiers[statId]
	if bySource == nil then
		return false
	end
	local entries = bySource[source]
	if entries == nil or entries[modifierId] == nil then
		return false
	end
	entries[modifierId] = nil
	if next(entries) == nil then
		bySource[source] = nil -- empty groups are dropped, so a stat without modifiers takes the exact path again
	end
	if next(bySource) == nil then
		sheet.modifiers[statId] = nil
	end
	return true
end

-- Number of modifiers on a stat (all sources).
function StatRules.countModifiers(sheet: Sheet, statId: string): number
	local count = 0
	for _, entries in sheet.modifiers[statId] or {} do
		for _ in entries do
			count += 1
		end
	end
	return count
end

--[[
	The combined value of a stat, or nil if its base was never set. Can raise BigNum's
	overflow error only if a result would exceed the largest exponent (2^53 - 1);
	StatService guards that call.
]]
function StatRules.combine(sheet: Sheet, statId: string): BigNum?
	local base = sheet.base[statId]
	if base == nil then
		return nil
	end
	local minimum = MINIMUM[statId]
	local bySource = sheet.modifiers[statId]
	if bySource == nil then
		return BigNum.max(BigNum.floor(base), minimum) -- no modifiers: exactly the base (Milestone 2)
	end

	local total = base
	local percentTotal = BigNum.zero
	local multipliers: { number } = {}
	for _, source in StatRules.Sources do
		local entries = bySource[source]
		if entries ~= nil then
			local ids: { string } = {}
			for id in entries do
				table.insert(ids, id)
			end
			table.sort(ids)
			for _, id in ids do
				local modifier = entries[id]
				if modifier.flat ~= nil then
					total = BigNum.add(total, modifier.flat)
				end
				if modifier.percent ~= nil and modifier.percent > 0 then
					percentTotal = BigNum.add(percentTotal, BigNum.fromNumber(modifier.percent))
				end
				if modifier.multiplier ~= nil and modifier.multiplier ~= 1 then
					table.insert(multipliers, modifier.multiplier)
				end
			end
		end
	end
	if not BigNum.isZero(percentTotal) then
		total = BigNum.mul(total, BigNum.add(BigNum.one, percentTotal))
	end
	for _, factor in multipliers do
		total = BigNum.mulNumber(total, factor)
	end
	return BigNum.max(BigNum.floor(total), minimum)
end

return table.freeze(StatRules)
