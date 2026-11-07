--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local ProfileTransactions = require(ServerScriptService:WaitForChild("ProfileTransactions"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectNil = TestKit.expectNil

local function number(text: string): BigNum.BigNum
	return BigNum.parse(text) :: BigNum.BigNum
end

local function prepared(profile: ProfileSchema.Profile, operation: { [string]: any }): ProfileSchema.Profile
	local result, problem = ProfileTransactions.prepare(profile, operation)
	assert(result, problem)
	return result :: ProfileSchema.Profile
end

local function recovered(profile: ProfileSchema.Profile): ProfileSchema.Profile
	-- Exercise the stored representation between preparation and recovery.
	local decoded, decodeProblem = ProfileSchema.decode(ProfileSchema.encode(profile))
	assert(decoded, decodeProblem)
	local result, problem = ProfileTransactions.recover(decoded :: ProfileSchema.Profile)
	assert(result, problem)
	return result :: ProfileSchema.Profile
end

local tests: { TestKit.TestCase } = {
	{
		name = "a saved grant recovers once and retains its milestone claim",
		run = function()
			local original = ProfileSchema.new()
			local operation = { id = 1, kind = "Grant", currencyId = "Gems", amount = "10", claimId = "stage:10" }
			local pending = prepared(original, operation)
			expectEqual(BigNum.toString(pending.currencies.Gems), "0")
			expectNil(original.pendingTransaction)
			operation.amount = "999"
			local result = recovered(pending)
			expectEqual(BigNum.toString(result.currencies.Gems), "10")
			expectTrue(result.claimedMilestones["stage:10"], "claim retained")
			expectEqual(result.transactionId, 1)
			expectEqual(BigNum.toString(recovered(result).currencies.Gems), "10")
			expectNil(ProfileTransactions.prepare(result, { id = 2, kind = "Grant", currencyId = "Gems", amount = "10", claimId = "stage:10" }))
		end,
	},
	{
		name = "upgrade recovery uses the saved price and changes balance and level together",
		run = function()
			local profile = ProfileSchema.new()
			profile.currencies.Gold = number("100")
			local pending = prepared(profile, {
				id = 1, kind = "Upgrade", currencyId = "Gold", amount = "7",
				upgradeId = "TapDamage", fromLevel = 1, toLevel = 2,
			})
			local result = recovered(pending)
			expectEqual(BigNum.toString(result.currencies.Gold), "93", "the saved cost replaces the current price for recovery")
			expectEqual(result.upgrades.TapDamage, 2)
			expectEqual(profile.upgrades.TapDamage, 1)
			expectEqual(BigNum.toString(profile.currencies.Gold), "100")
		end,
	},
	{
		name = "an unaffordable or stale operation changes nothing",
		run = function()
			local profile = ProfileSchema.new()
			expectNil(ProfileTransactions.prepare(profile, { id = 1, kind = "Spend", currencyId = "Gold", amount = "5" }))
			expectNil(ProfileTransactions.prepare(profile, { id = 2, kind = "Grant", currencyId = "Gold", amount = "5" }))
			expectEqual(profile.transactionId, 0)
			expectEqual(BigNum.toString(profile.currencies.Gold), "0")
		end,
	},
	{
		name = "prestige recovery uses the snapshotted gain across curve changes",
		run = function()
			local profile = ProfileSchema.new()
			profile.stage = 101
			profile.runHighestStage = 100
			profile.lifetimeHighestStage = 150
			profile.currencies.Gold = number("100")
			profile.currencies.Crowns = number("20")
			profile.upgrades.TapDamage = 25
			profile.prestige.multiplier = number("10")
			profile.claimedMilestones["stage:50"] = true
			profile.activeSeconds = 1800
			local pending = prepared(profile, {
				id = 1, kind = "Prestige", runId = 1, runHighestStage = 100,
				calculatedGain = "5", gainCurveVersion = "curve-A",
			})
			-- New code can use a different curve; the persisted payload is authoritative.
			local result = recovered(pending)
			expectEqual(BigNum.toString(result.prestige.multiplier), "15")
			expectEqual(result.prestige.count, 1)
			expectEqual(result.prestige.runId, 2)
			expectEqual(result.stage, 1)
			expectEqual(result.runHighestStage, 0)
			expectEqual(result.lifetimeHighestStage, 150)
			expectEqual(result.upgrades.TapDamage, 1)
			expectEqual(BigNum.toString(result.currencies.Gold), "0")
			expectEqual(BigNum.toString(result.currencies.Crowns), "20")
			expectTrue(result.claimedMilestones["stage:50"], "claims survive")
			expectEqual(result.activeSeconds, 1800)
			expectEqual(recovered(result).prestige.count, 1)
			expectEqual(result.transactions[1].calculatedGain, "5")
		end,
	},
	{
		name = "huge prestige multipliers and saved gains round trip",
		run = function()
			local profile = ProfileSchema.new()
			profile.prestige.multiplier = number("1e400")
			local result = recovered(prepared(profile, {
				id = 1, kind = "Prestige", runId = 1, runHighestStage = 0,
				calculatedGain = "2e399", gainCurveVersion = "test",
			}))
			expectEqual(ProfileSchema.encode(result).prestige.multiplier, "1.2e400")
		end,
	},
	{
		name = "overflow or the wrong run rejects a prestige without resetting progress",
		run = function()
			local profile = ProfileSchema.new()
			profile.prestige.multiplier = number("9e9007199254740991")
			expectNil(ProfileTransactions.prepare(profile, {
				id = 1, kind = "Prestige", runId = 1, runHighestStage = 0,
				calculatedGain = "9e9007199254740991", gainCurveVersion = "test",
			}))
			expectNil(ProfileTransactions.prepare(profile, {
				id = 1, kind = "Prestige", runId = 2, runHighestStage = 0,
				calculatedGain = "1", gainCurveVersion = "test",
			}))
			expectEqual(profile.prestige.count, 0)
			expectEqual(BigNum.toString(profile.prestige.multiplier), "9e9007199254740991")
		end,
	},
	{
		name = "history pruning retains the high-water id and all pending work",
		run = function()
			local profile = ProfileSchema.new()
			for id = 1, ProfileSchema.HistoryLimit + 5 do
				profile = recovered(prepared(profile, { id = id, kind = "Grant", currencyId = "Gold", amount = "1" }))
			end
			expectEqual(#profile.transactions, ProfileSchema.HistoryLimit)
			expectEqual(profile.transactionId, ProfileSchema.HistoryLimit + 5)
			expectNil(ProfileTransactions.prepare(profile, { id = 1, kind = "Grant", currencyId = "Gold", amount = "1" }))
			local pending = prepared(profile, { id = profile.transactionId + 1, kind = "Grant", currencyId = "Gold", amount = "7" })
			expectTrue(pending.pendingTransaction ~= nil, "pending work retained")
			expectNil(ProfileTransactions.prepare(pending, { id = profile.transactionId + 2, kind = "Grant", currencyId = "Gold", amount = "7" }))
		end,
	},
	{
		name = "a leftover applied marker is cleared without a second grant",
		run = function()
			local operation = { id = 1, kind = "Grant", currencyId = "Gold", amount = "10" }
			local profile = recovered(prepared(ProfileSchema.new(), operation))
			profile.pendingTransaction = ProfileSchema.readTransaction(operation)
			local result = recovered(profile)
			expectEqual(BigNum.toString(result.currencies.Gold), "10")
			expectNil(result.pendingTransaction)
			expectEqual(#result.transactions, 1)
		end,
	},
}

return { name = "ProfileTransactionsTests", tests = tests }
