--!strict
--[[
	ProfileSchema
	Location: ServerScriptService > ProfileSchema (ModuleScript)

	Milestone 3 player profile, version 1: what is saved and how it is checked.
	Pure: no Roblox services, no yields.

	Saved: currency balances (canonical BigNum text, read back with BigNum.parse,
	decision 9), the current stage, upgrade levels and active seconds
	(decision 7; the field is kept and preserved, and the counter waits for its rules).
	Not saved, because it is derived: tap damage (from the upgrade levels through
	StatService) and the current enemy (a fresh one spawns for the saved stage).

	decode() rejects anything malformed or out of range instead of repairing it,
	so a damaged record is never replaced by defaults. Fields that are missing
	(for example an upgrade added after the profile was saved) take their
	starting values. A profile with a newer version than this server is rejected.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNum = require(Shared:WaitForChild("BigNum"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

type BigNum = BigNum.BigNum

export type Profile = {
	currencies: { [string]: BigNum },
	stage: number,
	upgrades: { [string]: number },
	activeSeconds: number,
}

-- The table written to the data store (JSON-compatible).
export type Stored = {
	v: number,
	currencies: { [string]: string },
	stage: number,
	upgrades: { [string]: number },
	activeSeconds: number,
}

local MAX_INTEGER = 9007199254740991 -- 2^53 - 1

local ProfileSchema = {}

ProfileSchema.Version = 1

local function isWholeNumber(value: unknown, minimum: number, maximum: number): boolean
	if typeof(value) ~= "number" then
		return false
	end
	local number = value :: number
	return number % 1 == 0 and number >= minimum and number <= maximum -- NaN and infinities fail
end

-- A first-time player's profile.
function ProfileSchema.new(): Profile
	local currencies: { [string]: BigNum } = {}
	for _, currency in ProgressionConfig.Currencies do
		currencies[currency.id] = BigNum.fromNumber(currency.startingBalance)
	end
	local upgrades: { [string]: number } = {}
	for _, definition in ProgressionConfig.Upgrades do
		upgrades[definition.id] = definition.startingLevel
	end
	return {
		currencies = currencies,
		stage = GameConfig.Combat.StartingStage,
		upgrades = upgrades,
		activeSeconds = 0,
	}
end

function ProfileSchema.encode(profile: Profile): Stored
	local currencies: { [string]: string } = {}
	for currencyId, balance in profile.currencies do
		currencies[currencyId] = BigNum.toString(balance)
	end
	local upgrades: { [string]: number } = {}
	for upgradeId, level in profile.upgrades do
		upgrades[upgradeId] = level
	end
	return {
		v = ProfileSchema.Version,
		currencies = currencies,
		stage = profile.stage,
		upgrades = upgrades,
		activeSeconds = profile.activeSeconds,
	}
end

-- Reads a stored table. Returns the profile, or nil and the reason it was rejected.
function ProfileSchema.decode(raw: unknown): (Profile?, string?)
	if typeof(raw) ~= "table" then
		return nil, "the profile is not a table"
	end
	local record = raw :: { [string]: unknown }
	if not isWholeNumber(record.v, 1, MAX_INTEGER) then
		return nil, "the profile version is missing or invalid"
	end
	local version = record.v :: number
	if version > ProfileSchema.Version then
		return nil, `the profile version {version} is newer than this server's version {ProfileSchema.Version}`
	end
	-- Version 1 is the first version, so there are no migrations yet. Later versions upgrade
	-- the record one step at a time here, before it is checked.

	local profile = ProfileSchema.new()

	local currencies = record.currencies
	if typeof(currencies) ~= "table" then
		return nil, "currencies is not a table"
	end
	local storedCurrencies = currencies :: { [string]: unknown }
	for _, currency in ProgressionConfig.Currencies do
		local text = storedCurrencies[currency.id]
		if text ~= nil then
			local balance = BigNum.parse(text) -- nil for anything malformed, negative or out of range
			if balance == nil then
				return nil, `the {currency.id} balance is invalid`
			end
			profile.currencies[currency.id] = balance
		end
	end

	if not isWholeNumber(record.stage, GameConfig.Combat.StartingStage, MAX_INTEGER) then
		return nil, "the stage is invalid"
	end
	profile.stage = record.stage :: number

	local upgrades = record.upgrades
	if typeof(upgrades) ~= "table" then
		return nil, "upgrades is not a table"
	end
	local storedUpgrades = upgrades :: { [string]: unknown }
	for _, definition in ProgressionConfig.Upgrades do
		local level = storedUpgrades[definition.id]
		if level ~= nil then
			if not isWholeNumber(level, definition.startingLevel, definition.maxLevel) then
				return nil, `the {definition.id} level is invalid`
			end
			profile.upgrades[definition.id] = level :: number
		end
	end

	local activeSeconds = record.activeSeconds
	if activeSeconds ~= nil then
		if typeof(activeSeconds) ~= "number" then
			return nil, "activeSeconds is invalid"
		end
		local seconds = activeSeconds :: number
		if seconds ~= seconds or seconds < 0 or seconds > MAX_INTEGER then
			return nil, "activeSeconds is invalid"
		end
		profile.activeSeconds = seconds
	end

	return profile, nil
end

return ProfileSchema
