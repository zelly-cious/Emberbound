--!strict
--[[
	ProgressionConfig
	Location: ReplicatedStorage > Shared > ProgressionConfig (ModuleScript)

	Currencies and upgrade curves. Every price and upgrade value comes from
	here; services never hardcode them. The numbers are temporary balancing
	values and can be changed without touching service code.

	Gacha compatibility: Gold is one currency id among others. Future summon
	currencies (earned tickets, premium currency) are added to the currency
	list as separate ids. Nothing in the economy converts one currency into
	another.
]]

local BigNum = require(script.Parent:WaitForChild("BigNum"))
local GameConfig = require(script.Parent:WaitForChild("GameConfig"))

type BigNum = BigNum.BigNum

export type CurrencyDefinition = {
	id: string,
	displayName: string,
	startingBalance: number,
	kind: "BigNum" | "Whole",
	maxBalance: number?,
}

export type UpgradeDefinition = {
	id: string,
	displayName: string,
	currencyId: string,
	startingLevel: number,
	maxLevel: number,
	baseValue: number, -- value at level 1 before milestone bonuses
	milestoneInterval: number, -- a milestone is reached every this many levels
	milestoneMultiplier: number, -- the value is multiplied by this at each milestone
	baseCost: number, -- price of the first purchase (startingLevel -> startingLevel + 1)
	costGrowth: number, -- each further level costs this much more (1.07 = +7%)
}

local ProgressionConfig = {}

ProgressionConfig.GoldCurrencyId = "Gold"
ProgressionConfig.GemCurrencyId = "Gems"
ProgressionConfig.CrownCurrencyId = "Crowns"

local gold: CurrencyDefinition = {
	id = ProgressionConfig.GoldCurrencyId,
	displayName = "Gold",
	startingBalance = GameConfig.Combat.StartingGold,
	kind = "BigNum",
}

ProgressionConfig.Currencies = table.freeze({ table.freeze(gold) }) :: { CurrencyDefinition }

-- Saved wallet definitions. The active currency list above controls gameplay and sync.
-- Gems and Crowns become active in M6 and M8 respectively.
ProgressionConfig.CurrencyDefinitions = table.freeze({
	gold,
	table.freeze({ id = "Gems", displayName = "Gems", startingBalance = 0, kind = "Whole", maxBalance = 9007199254740991 }),
	table.freeze({ id = "Crowns", displayName = "Crowns", startingBalance = 0, kind = "Whole", maxBalance = 9007199254740991 }),
}) :: { CurrencyDefinition }

local tapDamage: UpgradeDefinition = {
	id = "TapDamage",
	displayName = "Tap Damage",
	currencyId = ProgressionConfig.GoldCurrencyId,
	startingLevel = 1,
	maxLevel = 100000,
	baseValue = GameConfig.Combat.StartingTapDamage, -- level 1 deals Milestone 1's starting damage
	milestoneInterval = 25,
	milestoneMultiplier = 3,
	baseCost = 5,
	costGrowth = 1.07,
}

ProgressionConfig.TapDamageUpgrade = table.freeze(tapDamage) :: UpgradeDefinition
ProgressionConfig.Upgrades = table.freeze({ ProgressionConfig.TapDamageUpgrade }) :: { UpgradeDefinition }

local function checkLevel(definition: UpgradeDefinition, level: number)
	if typeof(level) ~= "number" or level % 1 ~= 0 or level < definition.startingLevel or level > definition.maxLevel then
		error(`ProgressionConfig: invalid level {level} for {definition.id}`, 3)
	end
end

function ProgressionConfig.GetCurrency(currencyId: string): CurrencyDefinition?
	for _, currency in ProgressionConfig.CurrencyDefinitions do
		if currency.id == currencyId then
			return currency
		end
	end
	return nil
end

-- Balances and amounts share the same kind/range checks; callers decide whether zero is allowed.
function ProgressionConfig.IsCurrencyValue(currencyId: string, value: BigNum): boolean
	if not BigNum.isValid(value) then
		return false
	end
	local definition = ProgressionConfig.GetCurrency(currencyId)
	if definition == nil then
		return true -- Wallet also supports caller-defined currencies, as it did in M2.
	end
	if definition.kind == "Whole" and not BigNum.eq(BigNum.floor(value), value) then
		return false
	end
	return definition.maxBalance == nil or BigNum.lte(value, BigNum.fromNumber(definition.maxBalance))
end

function ProgressionConfig.GetUpgrade(upgradeId: string): UpgradeDefinition?
	for _, upgrade in ProgressionConfig.Upgrades do
		if upgrade.id == upgradeId then
			return upgrade
		end
	end
	return nil
end

-- Value(level) = floor(baseValue * level * milestoneMultiplier^floor(level / milestoneInterval))
function ProgressionConfig.GetUpgradeValue(definition: UpgradeDefinition, level: number): BigNum
	checkLevel(definition, level)
	local milestones = math.floor(level / definition.milestoneInterval)
	return BigNum.floor(BigNum.scaledPower(definition.baseValue * level, definition.milestoneMultiplier, milestones))
end

-- Cost(level) = floor(baseCost * costGrowth^(level - startingLevel)): the price of going from level to level + 1.
function ProgressionConfig.GetUpgradeCost(definition: UpgradeDefinition, level: number): BigNum
	checkLevel(definition, level)
	return BigNum.floor(BigNum.scaledPower(definition.baseCost, definition.costGrowth, level - definition.startingLevel))
end

-- Fail fast on broken balancing edits.
local function validate()
	local seenCurrencies: { [string]: boolean } = {}
	for _, currency in ProgressionConfig.Currencies do
		assert(not seenCurrencies[currency.id], `ProgressionConfig: duplicate currency id {currency.id}`)
		assert(currency.startingBalance >= 0, `ProgressionConfig: {currency.id} starting balance must be >= 0`)
		seenCurrencies[currency.id] = true
	end

	local seenUpgrades: { [string]: boolean } = {}
	for _, upgrade in ProgressionConfig.Upgrades do
		local id = upgrade.id
		assert(not seenUpgrades[id], `ProgressionConfig: duplicate upgrade id {id}`)
		seenUpgrades[id] = true
		assert(seenCurrencies[upgrade.currencyId], `ProgressionConfig: {id} uses unknown currency {upgrade.currencyId}`)
		assert(upgrade.startingLevel >= 1 and upgrade.startingLevel % 1 == 0, `ProgressionConfig: {id} startingLevel must be a whole number >= 1`)
		assert(upgrade.maxLevel >= upgrade.startingLevel and upgrade.maxLevel % 1 == 0, `ProgressionConfig: {id} maxLevel must be a whole number >= startingLevel`)
		assert(upgrade.baseValue > 0, `ProgressionConfig: {id} baseValue must be > 0`)
		assert(upgrade.milestoneInterval >= 1 and upgrade.milestoneInterval % 1 == 0, `ProgressionConfig: {id} milestoneInterval must be a whole number >= 1`)
		assert(upgrade.milestoneMultiplier >= 1, `ProgressionConfig: {id} milestoneMultiplier must be >= 1`)
		assert(upgrade.baseCost >= 1, `ProgressionConfig: {id} baseCost must be >= 1`)
		assert(upgrade.costGrowth >= 1, `ProgressionConfig: {id} costGrowth must be >= 1`)
	end

	-- Level 1 tap damage must equal Milestone 1's starting tap damage.
	local tap = ProgressionConfig.TapDamageUpgrade
	assert(
		BigNum.eq(ProgressionConfig.GetUpgradeValue(tap, tap.startingLevel), BigNum.fromNumber(GameConfig.Combat.StartingTapDamage)),
		"ProgressionConfig: TapDamage at its starting level must equal GameConfig.Combat.StartingTapDamage"
	)
end

validate()

return table.freeze(ProgressionConfig)
