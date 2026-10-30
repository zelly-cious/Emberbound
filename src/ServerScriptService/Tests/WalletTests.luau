--!strict
--[[
	WalletTests
	Location: ServerScriptService > Tests > WalletTests (ModuleScript)

	Balance rules: exact grants, all-or-nothing spends, no negative balances,
	independent currencies, and a rapid purchase sequence that mirrors
	UpgradeService's transaction (spend, then raise the level by one).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local Wallet = require(ServerScriptService:WaitForChild("Wallet"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

type BigNum = BigNum.BigNum

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectError = TestKit.expectError

local GOLD = ProgressionConfig.GoldCurrencyId

local function n(value: number): BigNum
	return BigNum.fromNumber(value)
end

local function balanceText(wallet: Wallet.Wallet, currencyId: string): string
	return BigNum.toString(Wallet.get(wallet, currencyId))
end

local tests: { TestKit.TestCase } = {
	{
		name = "a new wallet holds its starting balances",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(0) })
			expectEqual(balanceText(wallet, GOLD), "0")
			expectTrue(Wallet.has(wallet, GOLD), "has Gold")
			expectTrue(not Wallet.has(wallet, "PremiumGems"), "has no other currency")
		end,
	},
	{
		name = "grants add exactly",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(0) })
			expectTrue(Wallet.grant(wallet, GOLD, n(5)), "grant 5")
			expectTrue(Wallet.grant(wallet, GOLD, n(7)), "grant 7")
			expectEqual(balanceText(wallet, GOLD), "12")
		end,
	},
	{
		name = "spends succeed only when the whole amount is available",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(10) })
			expectTrue(Wallet.trySpend(wallet, GOLD, n(3)), "spend 3 of 10")
			expectEqual(balanceText(wallet, GOLD), "7")
			expectTrue(not Wallet.trySpend(wallet, GOLD, n(8)), "spend 8 of 7 is refused")
			expectEqual(balanceText(wallet, GOLD), "7", "a refused spend changes nothing")
			expectTrue(Wallet.trySpend(wallet, GOLD, n(7)), "spend the exact balance")
			expectEqual(balanceText(wallet, GOLD), "0")
			expectTrue(not Wallet.trySpend(wallet, GOLD, n(1)), "nothing left to spend")
			expectEqual(balanceText(wallet, GOLD), "0", "never negative")
		end,
	},
	{
		name = "invalid amounts and unknown currencies change nothing",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(10) })
			local invalid: any = { m = -1, e = 0 }
			expectTrue(not Wallet.grant(wallet, GOLD, BigNum.zero), "zero grant")
			expectTrue(not Wallet.grant(wallet, GOLD, invalid), "malformed grant")
			expectTrue(not Wallet.trySpend(wallet, GOLD, invalid), "malformed spend")
			expectTrue(not Wallet.trySpend(wallet, GOLD, BigNum.zero), "zero spend")
			expectTrue(not Wallet.grant(wallet, "PremiumGems", n(5)), "unknown currency grant")
			expectTrue(not Wallet.trySpend(wallet, "PremiumGems", n(5)), "unknown currency spend")
			expectEqual(balanceText(wallet, GOLD), "10", "Gold unchanged")
			expectError(function()
				Wallet.get(wallet, "PremiumGems")
			end, "reading an unknown currency")
		end,
	},
	{
		name = "currencies are independent",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(10), TestTickets = n(3) })
			expectTrue(Wallet.trySpend(wallet, GOLD, n(10)), "spend all Gold")
			expectEqual(balanceText(wallet, "TestTickets"), "3", "tickets untouched")
			expectTrue(not Wallet.trySpend(wallet, GOLD, n(1)), "Gold cannot borrow from tickets")
		end,
	},
	{
		name = "huge balances",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(0) })
			expectTrue(Wallet.grant(wallet, GOLD, BigNum.parse("1.5e400") :: BigNum), "grant 1.5e400")
			expectTrue(Wallet.trySpend(wallet, GOLD, BigNum.parse("5e399") :: BigNum), "spend 5e399")
			expectEqual(balanceText(wallet, GOLD), "1e400")
		end,
	},
	{
		name = "rapid purchases never overdraw and each charge buys exactly one level",
		run = function()
			local tap = ProgressionConfig.TapDamageUpgrade
			local wallet = Wallet.new({ [GOLD] = n(1000) })
			local level = tap.startingLevel
			local totalSpent = BigNum.zero
			-- 100 back-to-back requests, more than the balance can pay for.
			for _ = 1, 100 do
				local cost = ProgressionConfig.GetUpgradeCost(tap, level)
				if Wallet.trySpend(wallet, GOLD, cost) then
					level += 1
					totalSpent = BigNum.add(totalSpent, cost)
				end
				expectTrue(BigNum.isValid(Wallet.get(wallet, GOLD)), "balance stays valid")
			end
			expectEqual(level, 41, "1000 Gold buys exactly 40 levels")
			expectEqual(balanceText(wallet, GOLD), "19", "19 Gold left over")
			expectEqual(BigNum.toString(BigNum.add(totalSpent, Wallet.get(wallet, GOLD))), "1000", "spent + left = starting Gold")
		end,
	},
	{
		name = "snapshot lists every balance as canonical text",
		run = function()
			local wallet = Wallet.new({ [GOLD] = n(42), TestTickets = BigNum.parse("1.5e400") :: BigNum })
			local snapshot = Wallet.snapshot(wallet)
			expectEqual(snapshot[GOLD], "42")
			expectEqual(snapshot.TestTickets, "1.5e400")
		end,
	},
}

return {
	name = "WalletTests",
	tests = tests,
}
