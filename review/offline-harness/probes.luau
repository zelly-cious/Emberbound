
-- probes.luau (offline review harness): extra checks requested for the Milestone 2 review.
-- Reads the game code only; it never edits it. Every check prints PASS/FAIL; OBSERVE lines
-- record behavior worth a reviewer's judgment without asserting it is right or wrong.
local passed, failed = 0, 0

local function check(name, condition, detail)
	if condition then
		passed += 1
		print("  PASS " .. name)
	else
		failed += 1
		print("  FAIL " .. name .. (if detail ~= nil then " -- " .. tostring(detail) else ""))
	end
end

local function observe(text)
	print("  OBSERVE " .. text)
end

local function section(title)
	print("\n== " .. title)
end

local BigNum = Shim.require("ReplicatedStorage/Shared/BigNum")
local GameConfig = Shim.require("ReplicatedStorage/Shared/GameConfig")
local ProgressionConfig = Shim.require("ReplicatedStorage/Shared/ProgressionConfig")

local TWO_POW_53 = 9007199254740992
local function n(value)
	return BigNum.fromNumber(value)
end
local function p(text)
	return assert(BigNum.parse(text), "could not parse " .. text)
end
local s = BigNum.toString

---------------------------------------------------------------------------
section("1. BigNum precision and serialization")
---------------------------------------------------------------------------
math.randomseed(20261031)
do
	local roundTripFailures, invalid, total = 0, 0, 0
	local function probe(value)
		total += 1
		if not BigNum.isValid(value) then
			invalid += 1
		end
		local again = BigNum.parse(s(value))
		if again == nil or not BigNum.eq(again, value) then
			roundTripFailures += 1
			if roundTripFailures <= 3 then
				print("    round-trip failure: " .. s(value))
			end
		end
	end
	for _ = 1, 5000 do
		probe(n(math.floor(math.random() * TWO_POW_53))) -- small integers
		probe(n(math.random() * 1e6)) -- small fractions
		probe(BigNum.fromLog10(16 + math.random() * 5000)) -- large
		probe(BigNum.fromLog10(1e12 + math.random() * 1e3)) -- huge exponents
	end
	probe(n(TWO_POW_53 - 1))
	probe(BigNum.add(n(TWO_POW_53 - 1), n(1)))
	probe(p("9.99e9007199254740991"))
	check(`{total} random values are valid BigNums`, invalid == 0, `{invalid} invalid`)
	check(`{total} random values round-trip through toString/parse`, roundTripFailures == 0, `{roundTripFailures} failures`)
end
do
	local ordered, total = 0, 0
	for _ = 1, 5000 do
		local a = BigNum.fromLog10(math.random() * 400)
		local b = BigNum.fromLog10(math.random() * 400)
		local gap = BigNum.log10(a) - BigNum.log10(b)
		if math.abs(gap) > 1e-9 then
			total += 1
			if BigNum.compare(a, b) == (if gap > 0 then 1 else -1) then
				ordered += 1
			end
		end
	end
	check("compare() agrees with log10 ordering on 5000 random pairs", ordered == total, `{total - ordered} disagreements`)
end
check("integers below 2^53 add exactly", s(BigNum.add(n(TWO_POW_53 - 2), n(1))) == "9007199254740991")
check("parse rejects exponent 2^53", BigNum.parse("1e9007199254740992") == nil)
check("parse accepts exponent 2^53 - 1", BigNum.parse("1e9007199254740991") ~= nil)

---------------------------------------------------------------------------
section("2. Values beyond 10^308")
---------------------------------------------------------------------------
do
	local maxDouble = n(1.7976931348623157e308)
	local e309 = p("1e309")
	check("1e309 > largest double", BigNum.gt(e309, maxDouble))
	check("1e200 * 1e200 = 1e400", s(BigNum.mul(p("1e200"), p("1e200"))) == "1e400", s(BigNum.mul(p("1e200"), p("1e200"))))
	check("1e400 + 1e400 = 2e400", s(BigNum.add(p("1e400"), p("1e400"))) == "2e400")
	check("1.5e400 - 5e399 = 1e400", s(BigNum.sub(p("1.5e400"), p("5e399"))) == "1e400", s(BigNum.sub(p("1.5e400"), p("5e399"))))
	check("trySub refuses 1e400 - 1e401", BigNum.trySub(p("1e400"), p("1e401")) == nil)
	check("sub saturates at zero", BigNum.isZero(BigNum.sub(p("1e400"), p("1e401"))))
	check("toNumber(1e400) is math.huge (display only)", BigNum.toNumber(p("1e400")) == math.huge)
	check("format(1e400) = 1e400", BigNum.format(p("1e400")) == "1e400", BigNum.format(p("1e400")))
	-- Dc (10^33) is the last suffix, so 1.5e35 is "150Dc" and 1.5e36 switches to scientific notation.
	check("format(1.5e35) = 150Dc and format(1.5e36) = 1.5e36",
		BigNum.format(p("1.5e35")) == "150Dc" and BigNum.format(p("1.5e36")) == "1.5e36",
		`{BigNum.format(p("1.5e35"))}, {BigNum.format(p("1.5e36"))}`)
	check("ratio(1e400, 2e400) = 0.5", BigNum.ratio(p("1e400"), p("2e400")) == 0.5)
	check("mul overflow past exponent 2^53 - 1 errors", not pcall(BigNum.mul, p("1e9007199254740991"), p("1e10")))
	observe(`small amounts vanish next to huge ones (17-digit precision): 1e20 - 5 = {s(BigNum.sub(p("1e20"), n(5)))}, 1e20 + 5 = {s(BigNum.add(p("1e20"), n(5)))}`)
end

---------------------------------------------------------------------------
section("3. Milestone 1 formula compatibility")
---------------------------------------------------------------------------
local M1 = Shim.loadDetached("M1/ReplicatedStorage/Shared/GameConfig")
if M1 == nil then
	print("  SKIPPED: Milestone 1 baseline (730218a) not available in git")
else
	local compared, hpMismatch, goldMismatch, lastExactStage = 0, 0, 0, 0
	for stage = 1, 5000 do
		local m1Hp, m1Gold = M1.GetEnemyMaxHp(stage), M1.GetGoldReward(stage)
		local m2Hp, m2Gold = GameConfig.GetEnemyMaxHp(stage), GameConfig.GetGoldReward(stage)
		if not BigNum.isValid(m2Hp) or not BigNum.isValid(m2Gold) then
			hpMismatch += 1
		elseif m1Hp < TWO_POW_53 and m1Gold < TWO_POW_53 then
			compared += 1
			lastExactStage = stage
			if BigNum.toNumber(m2Hp) ~= m1Hp then
				hpMismatch += 1
			end
			if BigNum.toNumber(m2Gold) ~= m1Gold then
				goldMismatch += 1
			end
		end
	end
	check(`enemy HP matches M1 exactly on {compared} stages where M1 < 2^53 (1..{lastExactStage})`, hpMismatch == 0, `{hpMismatch} mismatches`)
	check(`gold reward matches M1 exactly on the same stages`, goldMismatch == 0, `{goldMismatch} mismatches`)
	observe(`stage 5000: M1 HP = {M1.GetEnemyMaxHp(5000)}, M2 HP = {s(GameConfig.GetEnemyMaxHp(5000))}`)
	local tap = ProgressionConfig.TapDamageUpgrade
	check("tap damage at level 1 equals M1 starting damage (1)", s(ProgressionConfig.GetUpgradeValue(tap, 1)) == tostring(M1.Combat.StartingTapDamage))
end

---------------------------------------------------------------------------
section("4. Upgrade cost and value formulas")
---------------------------------------------------------------------------
do
	local tap = ProgressionConfig.TapDamageUpgrade
	local costMismatch, valueMismatch, nonMonotonic = 0, 0, 0
	local previousCost, previousValue = nil, nil
	for level = 1, 3000 do
		local cost = ProgressionConfig.GetUpgradeCost(tap, level)
		local value = ProgressionConfig.GetUpgradeValue(tap, level)
		local expectedCost = math.floor(5 * 1.07 ^ (level - 1))
		local expectedValue = math.floor(1 * level * 3 ^ math.floor(level / 25))
		if expectedCost < TWO_POW_53 and BigNum.toNumber(cost) ~= expectedCost then
			costMismatch += 1
		end
		if expectedValue < TWO_POW_53 and BigNum.toNumber(value) ~= expectedValue then
			valueMismatch += 1
		end
		if previousCost and (BigNum.lt(cost, previousCost) or BigNum.lt(value, previousValue)) then
			nonMonotonic += 1
		end
		previousCost, previousValue = cost, value
	end
	check("cost(level) = floor(5 * 1.07^(level-1)) for levels 1..3000 (where < 2^53)", costMismatch == 0, costMismatch)
	check("value(level) = floor(level * 3^floor(level/25)) for levels 1..3000 (where < 2^53)", valueMismatch == 0, valueMismatch)
	check("cost and value never decrease from one level to the next", nonMonotonic == 0, nonMonotonic)
	check("first purchase costs 5 Gold", s(ProgressionConfig.GetUpgradeCost(tap, 1)) == "5")
	check("level 24 -> 24 damage, level 25 -> 75 damage (first milestone x3)", s(ProgressionConfig.GetUpgradeValue(tap, 24)) == "24" and s(ProgressionConfig.GetUpgradeValue(tap, 25)) == "75")
	local maxCost = ProgressionConfig.GetUpgradeCost(tap, tap.maxLevel)
	local maxValue = ProgressionConfig.GetUpgradeValue(tap, tap.maxLevel)
	check(`max level {tap.maxLevel} cost and value are valid BigNums`, BigNum.isValid(maxCost) and BigNum.isValid(maxValue))
	observe(`level {tap.maxLevel}: cost {BigNum.format(maxCost)}, damage {BigNum.format(maxValue)}`)
	check("level 0, maxLevel + 1 and 1.5 are rejected", not pcall(ProgressionConfig.GetUpgradeCost, tap, 0)
		and not pcall(ProgressionConfig.GetUpgradeCost, tap, tap.maxLevel + 1)
		and not pcall(ProgressionConfig.GetUpgradeCost, tap, 1.5))
end

---------------------------------------------------------------------------
section("5. Server services with two players (fake engine, synchronous remotes)")
---------------------------------------------------------------------------
Shim.runScript("ServerScriptService/ServerInit")
local CombatService = Shim.require("ServerScriptService/CombatService")
local CurrencyService = Shim.require("ServerScriptService/CurrencyService")
local UpgradeService = Shim.require("ServerScriptService/UpgradeService")
local GOLD = ProgressionConfig.GoldCurrencyId
local TAP = ProgressionConfig.TapDamageUpgrade

local function drain(player)
	local messages = table.clone(player.Inbox)
	table.clear(player.Inbox)
	return messages
end
local function gold(player)
	local balance = CurrencyService.GetBalance(player, GOLD)
	return if balance then s(balance) else "nil"
end
local function buy(player, requestId, upgradeId)
	Shim.fireServer("RequestUpgrade", player, upgradeId or TAP.id, requestId)
end
local function results(messages)
	local list = {}
	for _, message in messages do
		if message.remote == "UpgradeUpdate" and message.payload.kind == "PurchaseResult" then
			table.insert(list, message.payload.result)
		end
	end
	return list
end
local function refill()
	Shim.advanceClock(5) -- refills the upgrade rate limiter and clears the tap cooldown
end

local alice = Shim.addPlayer("Alice")
local bob = Shim.addPlayer("Bob")

-- 5a. Nothing happens before the ClientReady handshake.
buy(alice, 1)
Shim.fireServer("RequestAttack", alice)
check("requests before ClientReady are ignored (no messages, no charge, level 1)",
	#drain(alice) == 0 and gold(alice) == "0" and UpgradeService.GetLevel(alice, TAP.id) == 1)

-- 5b. Handshake: economy first, combat last.
Shim.fireServer("ClientReady", alice)
Shim.fireServer("ClientReady", bob)
local sync = drain(alice)
drain(bob)
check("sync order is CurrencyUpdate, UpgradeUpdate, CombatUpdate",
	#sync == 3 and sync[1].remote == "CurrencyUpdate" and sync[2].remote == "UpgradeUpdate" and sync[3].remote == "CombatUpdate")
check("sync payloads: Gold 0, level 1, next cost 5, damage 1, stage 1, HP 10/10",
	sync[1].payload.balances.Gold == "0"
		and sync[2].payload.upgrades.TapDamage.level == 1
		and sync[2].payload.upgrades.TapDamage.nextCost == "5"
		and sync[3].payload.snapshot.tapDamage == "1"
		and sync[3].payload.snapshot.stage == 1
		and sync[3].payload.snapshot.enemyHp == "10"
		and sync[3].payload.snapshot.enemyMaxHp == "10")
Shim.fireServer("ClientReady", alice)
check("a second ClientReady within the 1 s cooldown is ignored", #drain(alice) == 0)

-- 5c. Gold acquisition, and isolation from Bob.
for _ = 1, 10 do
	Shim.advanceClock(0.1)
	Shim.fireServer("RequestAttack", alice, "extra", 1e9) -- extra arguments must be ignored
end
local afterKill = drain(alice)
local defeated = 0
for _, message in afterKill do
	if message.remote == "CombatUpdate" and message.payload.kind == "Defeated" then
		defeated += 1
		check("defeat pays 5 Gold and the snapshot is the stage 2 enemy",
			message.payload.goldAwarded == "5" and message.payload.snapshot.stage == 2 and message.payload.snapshot.enemyHp == message.payload.snapshot.enemyMaxHp)
	end
end
check("10 spaced taps of 1 damage defeat the 10 HP slime exactly once", defeated == 1, defeated)
check("Alice has 5 Gold; Bob is untouched (0 Gold, no messages)", gold(alice) == "5" and gold(bob) == "0" and #drain(bob) == 0)

local hitsBefore = 0
for _ = 1, 20 do
	Shim.fireServer("RequestAttack", alice)
end
for _, message in drain(alice) do
	if message.remote == "CombatUpdate" then
		hitsBefore += 1
	end
end
check("20 taps in the same instant: at most 1 accepted (0.07 s cooldown)", hitsBefore <= 1, hitsBefore)

-- 5d. Spending, replays and insufficient funds.
refill()
buy(alice, 1)
local purchase = drain(alice)
local purchaseResults = results(purchase)
check("purchase #1 succeeds: Gold 5 -> 0, level 2, tap damage 2",
	#purchaseResults == 1 and purchaseResults[1].success and gold(alice) == "0" and UpgradeService.GetLevel(alice, TAP.id) == 2)
check("purchase messages: CurrencyUpdate, CombatUpdate(Stats), UpgradeUpdate(PurchaseResult)",
	#purchase == 3 and purchase[1].remote == "CurrencyUpdate" and purchase[2].payload.kind == "Stats"
		and purchase[2].payload.snapshot.tapDamage == "2" and purchase[3].remote == "UpgradeUpdate")
buy(alice, 1)
buy(alice, 0)
check("replayed or older request ids are ignored with no reply and no charge", #drain(alice) == 0 and UpgradeService.GetLevel(alice, TAP.id) == 2)
buy(alice, 2)
local poor = results(drain(alice))
check("purchase with 0 Gold -> InsufficientFunds, balance stays 0 (never negative)",
	#poor == 1 and poor[1].reason == "InsufficientFunds" and gold(alice) == "0" and UpgradeService.GetLevel(alice, TAP.id) == 2)

-- 5e. Malformed requests.
refill()
local levelBefore, goldBefore = UpgradeService.GetLevel(alice, TAP.id), gold(alice)
CurrencyService.Grant(alice, GOLD, n(1000), "Probe")
drain(alice)
local malformed = {
	{ nil, 3 }, { 123, 3 }, { {}, 3 }, { "Nope", 3 },
	{ TAP.id, 3.5 }, { TAP.id, "4" }, { TAP.id, 0 / 0 }, { TAP.id, math.huge }, { TAP.id, 2 ^ 60 }, { TAP.id, -5 },
}
for _, args in malformed do
	refill()
	Shim.fireServer("RequestUpgrade", alice, args[1], args[2])
end
check(`{#malformed} malformed requests change nothing and get no reply`,
	#drain(alice) == 0 and UpgradeService.GetLevel(alice, TAP.id) == levelBefore and gold(alice) == "1000")
local _ = goldBefore

-- 5f. Rapid purchases: rate limit and exact charging.
CurrencyService.Grant(alice, GOLD, n(1e9), "Probe")
refill()
drain(alice)
local startLevel = UpgradeService.GetLevel(alice, TAP.id)
local startGold = CurrencyService.GetBalance(alice, GOLD)
for requestId = 10, 59 do
	buy(alice, requestId)
end
local burst = results(drain(alice))
local endLevel = UpgradeService.GetLevel(alice, TAP.id)
local expectedSpent = BigNum.zero
for level = startLevel, endLevel - 1 do
	expectedSpent = BigNum.add(expectedSpent, ProgressionConfig.GetUpgradeCost(TAP, level))
end
local okCount = 0
for _, result in burst do
	if result.success then
		okCount += 1
	end
end
check("50 requests in one instant: exactly 10 processed (burst capacity)", #burst == 10, #burst)
check("levels gained == successful replies == 10", endLevel - startLevel == okCount and okCount == 10, `{endLevel - startLevel} levels, {okCount} ok`)
check("Gold spent equals the exact sum of the 10 level costs (no duplicate charge)",
	BigNum.eq(BigNum.sub(startGold, CurrencyService.GetBalance(alice, GOLD)), expectedSpent),
	`spent {s(BigNum.sub(startGold, CurrencyService.GetBalance(alice, GOLD)))}, expected {s(expectedSpent)}`)
Shim.advanceClock(0.5)
for requestId = 60, 69 do
	buy(alice, requestId)
end
check("after 0.5 s only 4 more requests are processed (8 per second)", #results(drain(alice)) == 4)
refill()
buy(alice, 100)
buy(alice, 99)
local order = results(drain(alice))
check("out-of-order request id 99 after 100 is ignored", #order == 1 and order[1].requestId == 100)

-- 5g. Isolation: Bob's own request ids, balance and level.
refill()
buy(bob, 1)
local bobResults = results(drain(bob))
check("Bob's request id 1 is accepted independently of Alice's ids (InsufficientFunds at 0 Gold)",
	#bobResults == 1 and bobResults[1].reason == "InsufficientFunds" and gold(bob) == "0" and UpgradeService.GetLevel(bob, TAP.id) == 1)
check("Alice received nothing from Bob's request", #drain(alice) == 0)

-- 5h. Huge numbers through the services.
refill()
CurrencyService.Grant(alice, GOLD, p("1e400"), "Probe")
local hugeLevel = UpgradeService.GetLevel(alice, TAP.id)
buy(alice, 200)
local huge = drain(alice)
check("purchase with a 1e400 balance succeeds", UpgradeService.GetLevel(alice, TAP.id) == hugeLevel + 1)
observe(`balance after that purchase: {gold(alice)} (cost is below the 17-digit precision, so it is absorbed)`)
CombatService.SetTapDamage(alice, p("1e400"))
Shim.advanceClock(1)
Shim.fireServer("RequestAttack", alice)
local hugeHit = drain(alice)
local allParse = true
for _, message in table.move(hugeHit, 1, #hugeHit, #huge + 1, huge) do
	local payload = message.payload
	for _, text in { payload.damage, payload.goldAwarded, payload.snapshot and payload.snapshot.enemyHp, payload.snapshot and payload.snapshot.tapDamage } do
		if text ~= nil and BigNum.parse(text) == nil then
			allParse = false
		end
	end
	if payload.balances then
		for _, text in payload.balances do
			allParse = allParse and BigNum.parse(text) ~= nil
		end
	end
end
check("a 1e400 tap defeats the enemy and every network number parses", #hugeHit >= 1 and allParse)
check("ApplyDamage rejects NaN, 0, negative and invalid tables",
	not CombatService.ApplyDamage(alice, 0 / 0, "Tap") and not CombatService.ApplyDamage(alice, 0, "Tap")
		and not CombatService.ApplyDamage(alice, -1, "Tap") and not CombatService.ApplyDamage(alice, { m = -1, e = 0 }, "Tap"))
check("Grant rejects zero, invalid and unknown currencies",
	not CurrencyService.Grant(bob, GOLD, BigNum.zero, "Probe") and not CurrencyService.Grant(bob, GOLD, { m = -1, e = 0 }, "Probe")
		and not CurrencyService.Grant(bob, "Gems", n(5), "Probe") and gold(bob) == "0")
drain(alice)
drain(bob)

-- 5i. Leaving.
Shim.removePlayer(alice)
refill()
buy(alice, 300)
Shim.fireServer("RequestAttack", alice)
Shim.fireServer("ClientReady", alice)
check("after leaving, Alice's state is gone everywhere and her requests are ignored",
	CurrencyService.GetBalance(alice, GOLD) == nil and UpgradeService.GetLevel(alice, TAP.id) == nil
		and not CombatService.HasPlayer(alice) and #drain(alice) == 0)
check("Bob is unaffected by Alice leaving", gold(bob) == "0" and UpgradeService.GetLevel(bob, TAP.id) == 1 and CombatService.HasPlayer(bob))

check("no remote handler raised an error", #Shim.handlerErrors == 0, table.concat(Shim.handlerErrors, " | "))

print(`\n[Probes] {passed} passed, {failed} failed`)
if failed > 0 then
	error("probes failed", 0)
end
