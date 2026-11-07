--!strict
--[[
	Wallet
	Location: ServerScriptService > Wallet (ModuleScript)

	Pure balance bookkeeping for one player: no Roblox services, no networking,
	no yields. CurrencyService owns one Wallet per player; tests use it directly.
	Every operation either fully succeeds or changes nothing, and no operation
	can make a balance negative.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))

type BigNum = BigNum.BigNum

export type Wallet = {
	balances: { [string]: BigNum },
}

local Wallet = {}

-- Creates a wallet holding exactly the given currencies.
function Wallet.new(startingBalances: { [string]: BigNum }): Wallet
	local balances: { [string]: BigNum } = {}
	for currencyId, amount in startingBalances do
		assert(ProgressionConfig.IsCurrencyValue(currencyId, amount), `Wallet.new: invalid starting balance for {currencyId}`)
		balances[currencyId] = amount
	end
	return { balances = balances }
end

function Wallet.has(wallet: Wallet, currencyId: string): boolean
	return wallet.balances[currencyId] ~= nil
end

-- Errors for an unknown currency: callers check has() or use ids from ProgressionConfig.
function Wallet.get(wallet: Wallet, currencyId: string): BigNum
	local balance = wallet.balances[currencyId]
	if balance == nil then
		error(`Wallet: unknown currency "{currencyId}"`, 2)
	end
	return balance
end

-- Adds a positive amount. Returns false, changing nothing, for an unknown currency or an invalid or zero amount.
function Wallet.grant(wallet: Wallet, currencyId: string, amount: BigNum): boolean
	local balance = wallet.balances[currencyId]
	if balance == nil or not ProgressionConfig.IsCurrencyValue(currencyId, amount) or BigNum.isZero(amount) then
		return false
	end
	local ok, updated = pcall(BigNum.add, balance, amount)
	if not ok or not ProgressionConfig.IsCurrencyValue(currencyId, updated) then
		return false
	end
	wallet.balances[currencyId] = updated
	return true
end

-- Removes the whole amount only if it is available. Returns false, changing nothing, otherwise.
function Wallet.trySpend(wallet: Wallet, currencyId: string, amount: BigNum): boolean
	local balance = wallet.balances[currencyId]
	if balance == nil or not ProgressionConfig.IsCurrencyValue(currencyId, amount) or BigNum.isZero(amount) then
		return false
	end
	local remaining = BigNum.trySub(balance, amount)
	if remaining == nil then
		return false
	end
	wallet.balances[currencyId] = remaining
	return true
end

-- Every balance as a canonical BigNum string, ready to send to the client.
function Wallet.snapshot(wallet: Wallet): { [string]: string }
	local result: { [string]: string } = {}
	for currencyId, balance in wallet.balances do
		result[currencyId] = BigNum.toString(balance)
	end
	return result
end

return table.freeze(Wallet)
