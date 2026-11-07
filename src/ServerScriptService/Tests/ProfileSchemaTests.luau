--!strict
--[[
	ProfileSchemaTests
	Location: ServerScriptService > Tests > ProfileSchemaTests (ModuleScript)

	V1 migration and V2 profiles: defaults, round trips, and rejection of malformed
	or out-of-range stored value (a rejected profile is never replaced by defaults).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectNil = TestKit.expectNil

local GOLD = ProgressionConfig.GoldCurrencyId
local TAP = ProgressionConfig.TapDamageUpgrade

-- A valid stored profile with every field present.
local function stored(): { [string]: any }
	return {
		v = 1,
		currencies = { [GOLD] = "1234" },
		stage = 7,
		upgrades = { [TAP.id] = 5 },
		activeSeconds = 90,
	}
end

local function decodeOk(raw: unknown): ProfileSchema.Profile
	local profile, reason = ProfileSchema.decode(raw)
	if profile == nil then
		error(`expected a valid profile, got: {reason}`, 2)
	end
	return profile
end

local function expectRejected(raw: unknown, label: string)
	local profile, reason = ProfileSchema.decode(raw)
	expectNil(profile, label)
	expectTrue(typeof(reason) == "string" and #(reason :: string) > 0, `{label}: a reason is given`)
end

local tests: { TestKit.TestCase } = {
	{
		name = "a new profile has the starting balances, stage, levels and zero active seconds",
		run = function()
			local profile = ProfileSchema.new()
			expectEqual(BigNum.toString(profile.currencies[GOLD]), "0")
			expectEqual(profile.stage, GameConfig.Combat.StartingStage)
			expectEqual(profile.upgrades[TAP.id], TAP.startingLevel)
			expectEqual(profile.activeSeconds, 0)
		end,
	},
	{
		name = "encode then decode returns the same profile, at small and huge values",
		run = function()
			for _, goldText in { "0", "1234", "9007199254740991", "1.5e16", "9.99e9007199254740991" } do
				local profile = ProfileSchema.new()
				profile.currencies[GOLD] = BigNum.parse(goldText) :: BigNum.BigNum
				profile.stage = 4321
				profile.runHighestStage = 4320
				profile.lifetimeHighestStage = 4320
				profile.upgrades[TAP.id] = TAP.maxLevel
				profile.activeSeconds = 1800
				local encoded = ProfileSchema.encode(profile)
				expectEqual(encoded.v, ProfileSchema.Version)
				expectEqual(typeof(encoded.currencies[GOLD]), "string", "balances are stored as text")
				local decoded = decodeOk(encoded)
				expectTrue(BigNum.eq(decoded.currencies[GOLD], profile.currencies[GOLD]), `Gold {goldText} round-trips`)
				expectEqual(decoded.stage, 4321)
				expectEqual(decoded.upgrades[TAP.id], TAP.maxLevel)
				expectEqual(decoded.activeSeconds, 1800)
			end
		end,
	},
	{
		name = "decode reads every field of a valid stored profile",
		run = function()
			local profile = decodeOk(stored())
			expectEqual(BigNum.toString(profile.currencies[GOLD]), "1234")
			expectEqual(profile.stage, 7)
			expectEqual(profile.upgrades[TAP.id], 5)
			expectEqual(profile.activeSeconds, 90)
		end,
	},
	{
		name = "missing optional entries take starting values; unknown entries are ignored",
		run = function()
			local raw = stored()
			raw.currencies = { FutureCurrency = "50" }
			raw.upgrades = { FutureUpgrade = 3 }
			raw.activeSeconds = nil
			raw.unknownField = "kept out"
			local profile = decodeOk(raw)
			expectEqual(BigNum.toString(profile.currencies[GOLD]), "0")
			expectNil(profile.currencies.FutureCurrency, "an unknown currency is not loaded")
			expectEqual(profile.upgrades[TAP.id], TAP.startingLevel)
			expectNil(profile.upgrades.FutureUpgrade, "an unknown upgrade is not loaded")
			expectEqual(profile.activeSeconds, 0)
		end,
	},
	{
		name = "decode rejects a missing, malformed or newer version",
		run = function()
			expectRejected(nil, "nil")
			expectRejected("profile", "a string")
			for _, version in { 0, -1, 1.5, 0 / 0, math.huge, "1" } do
				local raw = stored()
				raw.v = version
				expectRejected(raw, `version {version}`)
			end
			local raw = stored()
			raw.v = nil
			expectRejected(raw, "no version")
			raw = stored()
			raw.v = ProfileSchema.Version + 1
			local profile, reason = ProfileSchema.decode(raw)
			expectNil(profile, "a newer version")
			expectTrue(string.find(reason or "", "newer", 1, true) ~= nil, "the reason says the profile is newer")
		end,
	},
	{
		name = "decode rejects invalid balances, including out-of-range decimals (decision 9)",
		run = function()
			local bad: { unknown } = {
				"-5",
				"abc",
				"",
				"inf",
				"nan",
				"0x10",
				"1e9007199254740992",
				"10e9007199254740991",
				"1" .. string.rep("0", 23) .. "e9007199254740969", -- R2-1: 10^(2^53)
				string.rep("9", 65),
				12,
				true,
				{},
			}
			for _, value in bad do
				local raw = stored()
				raw.currencies = { [GOLD] = value }
				expectRejected(raw, `Gold {tostring(value)}`)
			end
			local raw = stored()
			raw.currencies = "1234"
			expectRejected(raw, "currencies is not a table")
		end,
	},
	{
		name = "decode rejects invalid stages, levels and active seconds",
		run = function()
			for _, stage in { 0, -3, 2.5, 0 / 0, math.huge, "7", 9007199254740992 } do
				local raw = stored()
				raw.stage = stage
				expectRejected(raw, `stage {stage}`)
			end
			for _, level in { TAP.startingLevel - 1, TAP.maxLevel + 1, 2.5, 0 / 0, "5" } do
				local raw = stored()
				raw.upgrades = { [TAP.id] = level }
				expectRejected(raw, `level {level}`)
			end
			local raw = stored()
			raw.upgrades = 5
			expectRejected(raw, "upgrades is not a table")
			for _, seconds in { -1, 0 / 0, math.huge, "90" } do
				raw = stored()
				raw.activeSeconds = seconds
				expectRejected(raw, `activeSeconds {seconds}`)
			end
		end,
	},
	{
		name = "decode never changes the stored table, and decoded profiles are independent",
		run = function()
			local raw = stored()
			local first = decodeOk(raw)
			local second = decodeOk(raw)
			first.upgrades[TAP.id] = 99
			first.currencies[GOLD] = BigNum.fromNumber(1)
			expectEqual(second.upgrades[TAP.id], 5)
			expectEqual(BigNum.toString(second.currencies[GOLD]), "1234")
			expectEqual(raw.currencies[GOLD], "1234")
			expectEqual(raw.upgrades[TAP.id], 5)
		end,
	},
	{
		name = "v1 migration seeds cleared-stage records and canonical prestige defaults",
		run = function()
			local profile = decodeOk(stored())
			expectEqual(profile.runHighestStage, 6)
			expectEqual(profile.lifetimeHighestStage, 6)
			expectEqual(profile.prestige.count, 0)
			expectEqual(profile.prestige.runId, 1)
			expectEqual(ProfileSchema.encode(profile).prestige.multiplier, "1")
			expectEqual(ProfileSchema.encode(profile).v, 2)
		end,
	},
	{
		name = "v2 preserves lifetime progress, claims and huge prestige multipliers",
		run = function()
			local profile = ProfileSchema.new()
			profile.lifetimeHighestStage = 500
			profile.prestige.multiplier = BigNum.parse("1e400") :: BigNum.BigNum
			profile.claimedMilestones["stage:100"] = true
			local copy = decodeOk(ProfileSchema.encode(profile))
			expectEqual(copy.lifetimeHighestStage, 500)
			expectEqual(copy.runHighestStage, 0)
			expectEqual(ProfileSchema.encode(copy).prestige.multiplier, "1e400")
			expectTrue(copy.claimedMilestones["stage:100"], "claim survives")
		end,
	},
	{
		name = "whole-number currencies reject fractions and over-cap balances",
		run = function()
			for _, currencyId in { "Gems", "Crowns" } do
				for _, amount in { "0.5", "9007199254740992", "-1" } do
					local raw = stored()
					raw.currencies[currencyId] = amount
					expectRejected(raw, currencyId .. " " .. amount)
				end
				local raw = stored()
				raw.currencies[currencyId] = "9007199254740991"
				expectEqual(BigNum.toString(decodeOk(raw).currencies[currencyId]), "9007199254740991")
			end
		end,
	},
	{
		name = "current-version missing or inconsistent stage and prestige fields are rejected",
		run = function()
			local valid = ProfileSchema.encode(ProfileSchema.new()) :: any
			for _, key in { "prestige", "runHighestStage", "lifetimeHighestStage", "transactions", "claimedMilestones", "activeSeconds" } do
				local raw = table.clone(valid)
				raw[key] = nil
				expectRejected(raw, "missing " .. key)
			end
			local missingGold = ProfileSchema.encode(ProfileSchema.new()) :: any
			missingGold.currencies[GOLD] = nil
			expectRejected(missingGold, "missing Gold")
			local missingLevel = ProfileSchema.encode(ProfileSchema.new()) :: any
			missingLevel.upgrades[TAP.id] = nil
			expectRejected(missingLevel, "missing upgrade level")
			valid.runHighestStage = 5
			expectRejected(valid, "run best exceeds lifetime best")
			valid.runHighestStage = 0
			valid.prestige.multiplier = "0.5"
			expectRejected(valid, "multiplier below one")
		end,
	},
	{
		name = "malformed pending operations and disordered history are rejected",
		run = function()
			local raw = ProfileSchema.encode(ProfileSchema.new()) :: any
			raw.pendingTransaction = { id = 2, kind = "Grant", currencyId = "Gold", amount = "1" }
			expectRejected(raw, "skipped id")
			raw.pendingTransaction = { id = 1, kind = "Prestige", runId = 1, runHighestStage = 0, calculatedGain = "nan", gainCurveVersion = "A" }
			expectRejected(raw, "invalid saved gain")
			raw.pendingTransaction = nil
			raw.transactionId = 2
			raw.transactions = {
				{ id = 2, kind = "Grant", currencyId = "Gold", amount = "1" },
				{ id = 1, kind = "Grant", currencyId = "Gold", amount = "1" },
			}
			expectRejected(raw, "disordered receipts")
		end,
	},
}

return {
	name = "ProfileSchemaTests",
	tests = tests,
}
