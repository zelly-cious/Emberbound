--!strict
-- Pure journal operations. A caller persists prepare() before acknowledging a durable operation.
-- ProfileStore.load completes a saved pending operation while claiming the session lock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNum = require(Shared:WaitForChild("BigNum"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))
local ProfileSchema = require(ServerScriptService:WaitForChild("ProfileSchema"))
local Wallet = require(ServerScriptService:WaitForChild("Wallet"))

type Profile = ProfileSchema.Profile
type Transaction = ProfileSchema.Transaction

local ProfileTransactions = {}

local function apply(profile: Profile, transaction: Transaction): (boolean, string?)
	if transaction.kind == "Prestige" then
		if transaction.runId ~= profile.prestige.runId or transaction.runHighestStage ~= profile.runHighestStage then
			return false, "the prestige operation belongs to a different run"
		end
		if profile.prestige.count >= ProfileSchema.MaxInteger or profile.prestige.runId >= ProfileSchema.MaxInteger then
			return false, "the prestige counter is full"
		end
		-- The gain was calculated before preparation. Recovery never consults a gain curve.
		local gain = BigNum.parse(transaction.calculatedGain) :: BigNum.BigNum
		profile.prestige.multiplier = BigNum.add(profile.prestige.multiplier, gain)
		profile.prestige.count += 1
		profile.prestige.runId += 1
		profile.stage = 1
		profile.runHighestStage = 0
		profile.currencies[ProgressionConfig.GoldCurrencyId] = BigNum.zero
		for _, definition in ProgressionConfig.Upgrades do
			profile.upgrades[definition.id] = definition.startingLevel
		end
		return true, nil
	end

	local currencyId = transaction.currencyId :: string
	local amount = BigNum.parse(transaction.amount) :: BigNum.BigNum
	if transaction.claimId ~= nil and profile.claimedMilestones[transaction.claimId] then
		return false, "the milestone reward was already claimed"
	end
	if transaction.kind == "Upgrade" and profile.upgrades[transaction.upgradeId :: string] ~= transaction.fromLevel then
		return false, "the upgrade operation has an unexpected starting level"
	end
	local wallet = Wallet.new(profile.currencies)
	local changed = if transaction.kind == "Grant" then Wallet.grant(wallet, currencyId, amount) else Wallet.trySpend(wallet, currencyId, amount)
	if not changed then
		return false, "the currency operation cannot be applied"
	end
	profile.currencies = wallet.balances
	if transaction.kind == "Upgrade" then
		profile.upgrades[transaction.upgradeId :: string] = transaction.toLevel :: number
	end
	if transaction.claimId ~= nil then
		profile.claimedMilestones[transaction.claimId] = true
	end
	return true, nil
end

function ProfileTransactions.recover(profile: Profile): (Profile?, string?)
	local result = ProfileSchema.copy(profile)
	local pending = result.pendingTransaction
	if pending == nil then
		return result, nil
	end
	local transaction, reason = ProfileSchema.readTransaction(pending)
	if transaction == nil then
		return nil, reason
	end
	if transaction.id <= result.transactionId then
		result.pendingTransaction = nil
		return result, nil
	end
	if transaction.id ~= result.transactionId + 1 then
		return nil, "the operation id is out of sequence"
	end
	local ok, applied, problem = pcall(apply, result, transaction)
	if not ok then
		return nil, tostring(applied)
	end
	if not applied then
		return nil, problem
	end
	result.transactionId = transaction.id
	result.pendingTransaction = nil
	table.insert(result.transactions, transaction)
	if #result.transactions > ProfileSchema.HistoryLimit then
		table.remove(result.transactions, 1)
	end
	return result, nil
end

-- The returned profile contains the original balances and a validated pending operation.
-- Persist this profile before applying/recovering it. Operation ids increase within the saved profile.
function ProfileTransactions.prepare(profile: Profile, raw: unknown): (Profile?, string?)
	if profile.pendingTransaction ~= nil then
		return nil, "a transaction is already pending"
	end
	local transaction, reason = ProfileSchema.readTransaction(raw)
	if transaction == nil then
		return nil, reason
	end
	if transaction.id <= profile.transactionId then
		return nil, "the operation was already applied"
	end
	local prepared = ProfileSchema.copy(profile)
	prepared.pendingTransaction = transaction
	local checked, problem = ProfileTransactions.recover(prepared)
	if checked == nil then
		return nil, problem
	end
	return prepared, nil
end

return table.freeze(ProfileTransactions)
