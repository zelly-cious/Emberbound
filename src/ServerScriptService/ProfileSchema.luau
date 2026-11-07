--!strict
-- Versioned player data and validation. Currency/upgrade definitions remain the source of defaults.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BigNum = require(Shared:WaitForChild("BigNum"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ProgressionConfig = require(Shared:WaitForChild("ProgressionConfig"))

type BigNum = BigNum.BigNum

export type Transaction = {
	id: number,
	kind: "Grant" | "Spend" | "Upgrade" | "Prestige",
	currencyId: string?,
	amount: string?,
	upgradeId: string?,
	fromLevel: number?,
	toLevel: number?,
	claimId: string?,
	reason: string?,
	runId: number?,
	runHighestStage: number?,
	calculatedGain: string?,
	gainCurveVersion: string?,
}

export type Prestige = {
	count: number,
	multiplier: BigNum,
	runId: number,
}

export type Profile = {
	currencies: { [string]: BigNum },
	stage: number,
	upgrades: { [string]: number },
	activeSeconds: number,
	lifetimeHighestStage: number,
	runHighestStage: number,
	prestige: Prestige,
	claimedMilestones: { [string]: boolean },
	transactionId: number,
	pendingTransaction: Transaction?,
	transactions: { Transaction },
}

export type Stored = {
	v: number,
	currencies: { [string]: string },
	stage: number,
	upgrades: { [string]: number },
	activeSeconds: number,
	lifetimeHighestStage: number,
	runHighestStage: number,
	prestige: { count: number, multiplier: string, runId: number },
	claimedMilestones: { [string]: boolean },
	transactionId: number,
	pendingTransaction: Transaction?,
	transactions: { Transaction },
}

local MAX_INTEGER = 9007199254740991
local ProfileSchema = {}
ProfileSchema.Version = 2
ProfileSchema.MaxInteger = MAX_INTEGER
ProfileSchema.HistoryLimit = 50

local function isWholeNumber(value: unknown, minimum: number, maximum: number): boolean
	return typeof(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
end

local function isText(value: unknown, maximum: number): boolean
	return typeof(value) == "string" and #value > 0 and #value <= maximum
end

local function copyTransactions(transactions: { Transaction }): { Transaction }
	local result: { Transaction } = {}
	for _, transaction in transactions do
		table.insert(result, table.clone(transaction))
	end
	return result
end

function ProfileSchema.new(): Profile
	local currencies: { [string]: BigNum } = {}
	for _, currency in ProgressionConfig.CurrencyDefinitions do
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
		lifetimeHighestStage = 0,
		runHighestStage = 0,
		prestige = { count = 0, multiplier = BigNum.one, runId = 1 },
		claimedMilestones = {},
		transactionId = 0,
		pendingTransaction = nil,
		transactions = {},
	}
end

-- BigNums are immutable. Copy every mutable container so a failed operation cannot leak changes.
function ProfileSchema.copy(profile: Profile): Profile
	return {
		currencies = table.clone(profile.currencies),
		stage = profile.stage,
		upgrades = table.clone(profile.upgrades),
		activeSeconds = profile.activeSeconds,
		lifetimeHighestStage = profile.lifetimeHighestStage,
		runHighestStage = profile.runHighestStage,
		prestige = table.clone(profile.prestige),
		claimedMilestones = table.clone(profile.claimedMilestones),
		transactionId = profile.transactionId,
		pendingTransaction = if profile.pendingTransaction then table.clone(profile.pendingTransaction) else nil,
		transactions = copyTransactions(profile.transactions),
	}
end

-- Validate journal payloads independently of current prices or the current prestige gain curve.
function ProfileSchema.readTransaction(raw: unknown): (Transaction?, string?)
	if typeof(raw) ~= "table" then
		return nil, "the transaction is not a table"
	end
	local fields = raw :: { [string]: any }
	if not isWholeNumber(fields.id, 1, MAX_INTEGER) then
		return nil, "the transaction id is invalid"
	end
	local kind = fields.kind
	if kind ~= "Grant" and kind ~= "Spend" and kind ~= "Upgrade" and kind ~= "Prestige" then
		return nil, "the transaction kind is invalid"
	end
	local transaction: Transaction = { id = fields.id, kind = kind }
	if fields.reason ~= nil then
		if not isText(fields.reason, 128) then
			return nil, "the transaction reason is invalid"
		end
		transaction.reason = fields.reason
	end
	if kind == "Prestige" then
		local gain = BigNum.parse(fields.calculatedGain)
		if gain == nil or BigNum.isZero(gain) or not isText(fields.gainCurveVersion, 64)
			or not isWholeNumber(fields.runId, 1, MAX_INTEGER)
			or not isWholeNumber(fields.runHighestStage, 0, MAX_INTEGER) then
			return nil, "the saved prestige reward is invalid"
		end
		transaction.calculatedGain = BigNum.toString(gain)
		transaction.gainCurveVersion = fields.gainCurveVersion
		transaction.runId = fields.runId
		transaction.runHighestStage = fields.runHighestStage
		return transaction, nil
	end

	local currencyId = fields.currencyId
	local amount = BigNum.parse(fields.amount)
	if typeof(currencyId) ~= "string" or ProgressionConfig.GetCurrency(currencyId) == nil
		or amount == nil or BigNum.isZero(amount) or not ProgressionConfig.IsCurrencyValue(currencyId, amount) then
		return nil, "the saved currency operation is invalid"
	end
	transaction.currencyId = currencyId
	transaction.amount = BigNum.toString(amount)
	if kind == "Upgrade" then
		local definition = if typeof(fields.upgradeId) == "string" then ProgressionConfig.GetUpgrade(fields.upgradeId) else nil
		if definition == nil or definition.currencyId ~= currencyId
			or not isWholeNumber(fields.fromLevel, definition.startingLevel, definition.maxLevel - 1)
			or fields.toLevel ~= fields.fromLevel + 1 then
			return nil, "the saved upgrade operation is invalid"
		end
		transaction.upgradeId = fields.upgradeId
		transaction.fromLevel = fields.fromLevel
		transaction.toLevel = fields.toLevel
	end
	if fields.claimId ~= nil then
		if kind ~= "Grant" or not isText(fields.claimId, 128) then
			return nil, "the milestone claim id is invalid"
		end
		transaction.claimId = fields.claimId
	end
	return transaction, nil
end

function ProfileSchema.encode(profile: Profile): Stored
	local currencies: { [string]: string } = {}
	for currencyId, balance in profile.currencies do
		currencies[currencyId] = BigNum.toString(balance)
	end
	return {
		v = ProfileSchema.Version,
		currencies = currencies,
		stage = profile.stage,
		upgrades = table.clone(profile.upgrades),
		activeSeconds = profile.activeSeconds,
		lifetimeHighestStage = profile.lifetimeHighestStage,
		runHighestStage = profile.runHighestStage,
		prestige = {
			count = profile.prestige.count,
			multiplier = BigNum.toString(profile.prestige.multiplier),
			runId = profile.prestige.runId,
		},
		claimedMilestones = table.clone(profile.claimedMilestones),
		transactionId = profile.transactionId,
		pendingTransaction = if profile.pendingTransaction then table.clone(profile.pendingTransaction) else nil,
		transactions = copyTransactions(profile.transactions),
	}
end

function ProfileSchema.decode(raw: unknown): (Profile?, string?)
	if typeof(raw) ~= "table" then
		return nil, "the profile is not a table"
	end
	local record = raw :: { [string]: any }
	if not isWholeNumber(record.v, 1, MAX_INTEGER) then
		return nil, "the profile version is missing or invalid"
	end
	if record.v > ProfileSchema.Version then
		return nil, "the profile version is newer than this server"
	end

	local profile = ProfileSchema.new()
	if typeof(record.currencies) ~= "table" then
		return nil, "currencies is not a table"
	end
	for _, currency in ProgressionConfig.CurrencyDefinitions do
		local text = record.currencies[currency.id]
		if text == nil and record.v == ProfileSchema.Version then
			return nil, "the " .. currency.id .. " balance is missing"
		end
		if text ~= nil then
			local balance = BigNum.parse(text)
			if balance == nil or not ProgressionConfig.IsCurrencyValue(currency.id, balance) then
				return nil, "the " .. currency.id .. " balance is invalid"
			end
			profile.currencies[currency.id] = balance
		end
	end
	if not isWholeNumber(record.stage, GameConfig.Combat.StartingStage, MAX_INTEGER) then
		return nil, "the stage is invalid"
	end
	profile.stage = record.stage

	if typeof(record.upgrades) ~= "table" then
		return nil, "upgrades is not a table"
	end
	for _, definition in ProgressionConfig.Upgrades do
		local level = record.upgrades[definition.id]
		if level == nil and record.v == ProfileSchema.Version then
			return nil, "the " .. definition.id .. " level is missing"
		end
		if level ~= nil then
			if not isWholeNumber(level, definition.startingLevel, definition.maxLevel) then
				return nil, "the " .. definition.id .. " level is invalid"
			end
			profile.upgrades[definition.id] = level
		end
	end
	if record.activeSeconds == nil and record.v == ProfileSchema.Version then
		return nil, "activeSeconds is missing"
	end
	if record.activeSeconds ~= nil then
		local seconds = record.activeSeconds
		if typeof(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds > MAX_INTEGER then
			return nil, "activeSeconds is invalid"
		end
		profile.activeSeconds = seconds
	end

	-- V1 had sequential stages and no prestige. Upgrade its history conservatively.
	if record.v == 1 then
		profile.runHighestStage = math.max(0, profile.stage - 1)
		profile.lifetimeHighestStage = profile.runHighestStage
		return profile, nil
	end

	if not isWholeNumber(record.runHighestStage, profile.stage - 1, MAX_INTEGER)
		or not isWholeNumber(record.lifetimeHighestStage, record.runHighestStage, MAX_INTEGER) then
		return nil, "the highest-cleared stage records are invalid"
	end
	profile.runHighestStage = record.runHighestStage
	profile.lifetimeHighestStage = record.lifetimeHighestStage

	local prestige = record.prestige
	if typeof(prestige) ~= "table" or not isWholeNumber(prestige.count, 0, MAX_INTEGER)
		or not isWholeNumber(prestige.runId, 1, MAX_INTEGER) then
		return nil, "the prestige record is invalid"
	end
	local multiplier = BigNum.parse(prestige.multiplier)
	if multiplier == nil or BigNum.lt(multiplier, BigNum.one) then
		return nil, "the prestige multiplier is invalid"
	end
	profile.prestige = { count = prestige.count, multiplier = multiplier, runId = prestige.runId }

	if typeof(record.claimedMilestones) ~= "table" then
		return nil, "the milestone claim records are invalid"
	end
	for claimId, claimed in record.claimedMilestones do
		if not isText(claimId, 128) or claimed ~= true then
			return nil, "the milestone claim records are invalid"
		end
		profile.claimedMilestones[claimId] = true
	end
	if not isWholeNumber(record.transactionId, 0, MAX_INTEGER) or typeof(record.transactions) ~= "table" then
		return nil, "the transaction history is invalid"
	end
	profile.transactionId = record.transactionId
	local history = record.transactions
	local count = 0
	for index in history do
		if not isWholeNumber(index, 1, ProfileSchema.HistoryLimit) then
			return nil, "the transaction history is invalid"
		end
		count += 1
	end
	if count ~= #history then
		return nil, "the transaction history is not a sequence"
	end
	local lastId = 0
	for _, rawTransaction in history do
		local transaction, reason = ProfileSchema.readTransaction(rawTransaction)
		if transaction == nil then
			return nil, reason
		end
		if transaction.id <= lastId or transaction.id > profile.transactionId then
			return nil, "the transaction history is out of order"
		end
		lastId = transaction.id
		table.insert(profile.transactions, transaction)
	end
	if record.pendingTransaction ~= nil then
		local transaction, reason = ProfileSchema.readTransaction(record.pendingTransaction)
		if transaction == nil then
			return nil, reason
		end
		if transaction.id > profile.transactionId + 1 then
			return nil, "the pending transaction skips an operation id"
		end
		profile.pendingTransaction = transaction
	end
	return profile, nil
end

return ProfileSchema
