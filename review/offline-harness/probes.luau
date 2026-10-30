
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

local originalPassed, originalFailed = passed, failed

---------------------------------------------------------------------------
-- Sections 6-11 were added with the corrections for the Milestone 2 Codex audit
-- (findings F1-F6). Sections 1-5 above are the original 54 probes, unchanged.
---------------------------------------------------------------------------
local TWO_POW_53_NUMBER = 9007199254740992
local MAX_EXPONENT = 9007199254740991

---------------------------------------------------------------------------
section("6. F1: subtraction near 2^53 and Gold conservation")
---------------------------------------------------------------------------
check("sub(2^53, 2^53 - 1) = 1", s(BigNum.sub(n(TWO_POW_53_NUMBER), n(TWO_POW_53_NUMBER - 1))) == "1")
do
	local mismatches, total = 0, 0
	for _ = 1, 20000 do
		local a = TWO_POW_53_NUMBER + 2 * math.floor(math.random() * 4e14) -- even doubles in [2^53, ~9.8e15)
		local b = math.floor(math.random() * a)
		total += 1
		local result = BigNum.sub(n(a), n(b))
		if not BigNum.isValid(result) or BigNum.toNumber(result) ~= a - b then
			mismatches += 1
		end
	end
	check(`{total} subtractions from [2^53, 1e16) equal the correctly rounded double (exact below 2^53)`, mismatches == 0, mismatches)
end
do
	local wholeFailures, total = 0, 0
	for _ = 1, 5000 do
		local exponent = 16 + math.floor(math.random() * 7) -- operands up to 10^22
		local a = BigNum.fromLog10(exponent + math.random() * 0.99)
		local b = BigNum.fromLog10(BigNum.log10(a) - math.random() * 1e-12) -- very close to a
		if BigNum.gt(a, b) then
			total += 1
			local result = BigNum.sub(a, b)
			if result.e == 0 and result.m % 1 ~= 0 then
				wholeFailures += 1
			end
		end
	end
	check(`{total} cancellations between large operands below 10^23 give whole numbers`, wholeFailures == 0, wholeFailures)
end
do
	-- Through the real services: a 2^53 Gold balance pays 30 upgrades and must equal 2^53 minus their exact sum.
	local carol = Shim.addPlayer("Carol")
	Shim.advanceClock(5)
	Shim.fireServer("ClientReady", carol)
	CurrencyService.Grant(carol, GOLD, n(TWO_POW_53_NUMBER), "Probe")
	drain(carol)
	local expected = TWO_POW_53_NUMBER
	local level = UpgradeService.GetLevel(carol, TAP.id)
	local requestId = 0
	for _ = 1, 3 do
		refill()
		for _ = 1, 10 do
			requestId += 1
			expected -= BigNum.toNumber(ProgressionConfig.GetUpgradeCost(TAP, level))
			level += 1
			buy(carol, requestId)
		end
	end
	drain(carol)
	check("30 purchases from a 2^53 balance leave exactly 2^53 minus their summed costs",
		UpgradeService.GetLevel(carol, TAP.id) == level and gold(carol) == string.format("%.17g", expected),
		`{gold(carol)} vs {string.format("%.17g", expected)}`)
	Shim.removePlayer(carol)
end

---------------------------------------------------------------------------
section("7. F2: parse never throws")
---------------------------------------------------------------------------
do
	local alphabet = "0123456789.eE+-"
	local thrown, invalid, total = 0, 0, 0
	local function probeText(text)
		total += 1
		local ok, result = pcall(BigNum.parse, text)
		if not ok then
			thrown += 1
			if thrown <= 3 then
				print(`    parse raised for "{text}": {result}`)
			end
		elseif result ~= nil and not BigNum.isValid(result) then
			invalid += 1
		end
		return if ok then result else nil
	end
	for _ = 1, 20000 do
		local length = 1 + math.floor(math.random() * 64)
		local characters = table.create(length)
		for i = 1, length do
			local index = 1 + math.floor(math.random() * #alphabet)
			characters[i] = string.sub(alphabet, index, index)
		end
		probeText(table.concat(characters))
	end
	-- Structured hostile input: up to 48 mantissa digits with exponents around 2^53 - 1.
	-- The exact verdict is checked up to 23 digits, where the mantissa 10^(digits - 1) is an exact
	-- double; longer mantissas are read to double precision (like tonumber) or hit the 64-character limit.
	local wrongVerdicts = 0
	for digits = 1, 48 do
		for offset = -60, 5 do
			local exponent = MAX_EXPONENT + offset
			local text = "1" .. string.rep("0", digits - 1) .. "e" .. string.format("%.0f", exponent)
			local result = probeText(text)
			if digits <= 23 then
				-- Parenthesized: near 2^53, (exponent + digits) - 1 would round before subtracting.
				local normalizedExponent = exponent + (digits - 1)
				local shouldFit = exponent <= MAX_EXPONENT and normalizedExponent <= MAX_EXPONENT
				if shouldFit ~= (result ~= nil) or (result and result.e ~= normalizedExponent) then
					wrongVerdicts += 1
				end
			end
		end
	end
	check(`{total} random and boundary strings: parse never raised an error`, thrown == 0, thrown)
	check("every value parse returned is a valid BigNum", invalid == 0, invalid)
	check("near exponent 2^53 - 1, parse accepts exactly the representable values", wrongVerdicts == 0, wrongVerdicts)
end

---------------------------------------------------------------------------
section("8. F3: TestRunner fault injection (the real TestRunner script)")
---------------------------------------------------------------------------
do
	local runnerSource = SOURCES["ServerScriptService/Tests/TestRunner"]
	local kitSource = SOURCES["ServerScriptService/Tests/TestKit"]
	local goodSuite = 'return { name = "GoodTests", tests = { { name = "passes", run = function() end } } }'
	local function runFolder(folder, extraModules)
		Shim.addSource(`ServerScriptService/{folder}/TestKit`, "ModuleScript", kitSource)
		for name, source in extraModules do
			Shim.addSource(`ServerScriptService/{folder}/{name}`, "ModuleScript", source)
		end
		Shim.addSource(`ServerScriptService/{folder}/TestRunner`, "Script", runnerSource)
		return Shim.captureScript(`ServerScriptService/{folder}/TestRunner`)
	end
	local function says(lines, fragment)
		for _, line in lines do
			if string.find(line, fragment, 1, true) then
				return true
			end
		end
		return false
	end

	local broken = runFolder("FaultBroken", { GoodTests = goodSuite, BrokenTests = 'error("injected load failure")' })
	check("a suite that errors while loading is reported and the run is not ALL PASSED",
		says(broken, "could not load BrokenTests") and not says(broken, "ALL PASSED"))
	check("the harness check also rejects that run", not Shim.checkTestRun(broken, { "BrokenTests", "GoodTests" }))

	local notSuite = runFolder("FaultNotSuite", { GoodTests = goodSuite, NotASuiteTests = "return 42" })
	check("a module that does not return a suite is a failure",
		says(notSuite, "NotASuiteTests: did not return a test suite") and not says(notSuite, "ALL PASSED"))

	local empty = runFolder("FaultEmpty", {})
	check("a run with no test modules fails", says(empty, "no tests ran") and not says(empty, "ALL PASSED"))

	local clean = runFolder("FaultClean", { GoodTests = goodSuite })
	check("control: a healthy folder still reports ALL PASSED", Shim.checkTestRun(clean, { "GoodTests" }))
end

---------------------------------------------------------------------------
section("9. F4: the smallest positive doubles in arithmetic")
---------------------------------------------------------------------------
do
	local values = {
		n(5e-324), n(1e-320), n(2.2250738585072014e-308), n(1e-300), n(1e-200), n(0.5), n(13),
		n(TWO_POW_53_NUMBER - 1), n(TWO_POW_53_NUMBER), p("1e16"), n(1e308), p("1e400"), (p("7.25e1000")),
	} -- the parentheses keep p's second return value (assert's message) out of the list
	local errors, invalid, operations = 0, 0, 0
	for _, a in values do
		for _, b in values do
			for _, operation in { BigNum.add, BigNum.sub, BigNum.mul, BigNum.div } do
				operations += 1
				local ok, result = pcall(operation, a, b)
				if not ok then
					errors += 1
					if errors <= 3 then
						print(`    {s(a)} op {s(b)} raised: {result}`)
					end
				elseif not BigNum.isValid(result) then
					invalid += 1
				end
			end
			local okCompare = pcall(BigNum.compare, a, b) and pcall(BigNum.ratio, a, b) and pcall(BigNum.format, a)
			if not okCompare then
				errors += 1
			end
		end
		if not BigNum.eq(p(s(a)), a) then
			invalid += 1
		end
	end
	check(`{operations} add/sub/mul/div operations on values from 5e-324 to 7.25e1000 raise no errors`, errors == 0, errors)
	check("every result is a valid BigNum and every value round-trips through text", invalid == 0, invalid)
	check("5e-324 * 1e400 divided by 1e400 is 5e-324 again",
		BigNum.eq(BigNum.div(BigNum.mul(n(5e-324), p("1e400")), p("1e400")), n(5e-324)))
end

---------------------------------------------------------------------------
section("10. F6: approximate assertions reject NaN")
---------------------------------------------------------------------------
do
	local TestKit = Shim.require("ServerScriptService/Tests/TestKit")
	check("expectNear(0/0, 123, 0) fails", not pcall(TestKit.expectNear, 0 / 0, 123, 0))
	check("expectNear(123, 0/0, 0) and NaN or negative tolerances fail",
		not pcall(TestKit.expectNear, 123, 0 / 0, 0) and not pcall(TestKit.expectNear, 1, 1, 0 / 0) and not pcall(TestKit.expectNear, 1, 1, -1))
	check("valid approximate comparisons still pass", pcall(TestKit.expectNear, 1, 1.05, 0.1) and pcall(TestKit.expectNear, 5, 5, 0))
end

---------------------------------------------------------------------------
section("11. Ordinary values: corrected BigNum vs the audited BigNum (024cd68)")
---------------------------------------------------------------------------
local Audited = Shim.loadDetached("AUDITED/ReplicatedStorage/Shared/BigNum")
if Audited == nil then
	print("  SKIPPED: audited commit 024cd68 not available in git")
else
	local texts = {}
	for _ = 1, 400 do
		local kind = math.random(5)
		if kind == 1 then
			table.insert(texts, string.format("%.0f", math.floor(math.random() * TWO_POW_53_NUMBER)))
		elseif kind == 2 then
			table.insert(texts, string.format("%.17g", math.random() * 1e6))
		elseif kind == 3 then
			table.insert(texts, s(n(TWO_POW_53_NUMBER + 2 * math.floor(math.random() * 4e14))))
		elseif kind == 4 then
			table.insert(texts, s(BigNum.fromLog10(16 + math.random() * 14)))
		else
			table.insert(texts, s(BigNum.fromLog10(300 + math.random() * 5000)))
		end
	end
	local same, intended, unexpected, parseDifferences = 0, 0, 0, 0
	local function describe(ok, value)
		if not ok then
			return "error"
		end
		if type(value) == "table" then
			return s(value)
		end
		return tostring(value)
	end
	for i, aText in texts do
		local bText = texts[(i * 7) % #texts + 1]
		local newA, newB = p(aText), p(bText)
		local oldA, oldB = Audited.parse(aText), Audited.parse(bText)
		if s(newA) ~= Audited.toString(oldA) or s(newB) ~= Audited.toString(oldB) then
			parseDifferences += 1
		end
		for _, name in { "add", "sub", "mul", "div", "compare", "ratio", "floor", "log10", "format", "toString" } do
			local okNew, newResult = pcall(BigNum[name], newA, newB)
			local okOld, oldResult = pcall(Audited[name], oldA, oldB)
			if describe(okNew, newResult) == describe(okOld, oldResult) then
				same += 1
			elseif name == "sub" and newA.e ~= 0 and newA.e <= 22 then
				-- F1: the corrected sub returns the correctly rounded double subtraction below 10^23.
				local difference = BigNum.toNumber(newA) - BigNum.toNumber(newB)
				local expectedText = if difference > 0 then s(n(difference)) else "0"
				if describe(okNew, newResult) == expectedText then
					intended += 1
				else
					unexpected += 1
				end
			else
				unexpected += 1
				if unexpected <= 3 then
					print(`    {name}({aText}, {bText}): new {describe(okNew, newResult)}, audited {describe(okOld, oldResult)}`)
				end
			end
		end
	end
	check("parse and toString agree with the audited BigNum on every ordinary value", parseDifferences == 0, parseDifferences)
	check(`{same + intended + unexpected} operations: every difference is the intended F1 subtraction change`, unexpected == 0, unexpected)
	observe(`{same} results identical to the audited BigNum, {intended} subtractions now correctly rounded`)
end

do
	-- Not an audit finding: add still uses scientific form above 2^53 (documented ~16-digit precision).
	local off, total = 0, 0
	for _ = 1, 20000 do
		local a = TWO_POW_53_NUMBER + 2 * math.floor(math.random() * 4e14)
		local b = math.floor(math.random() * 1e6)
		total += 1
		if BigNum.toNumber(BigNum.add(n(a), n(b))) ~= a + b then
			off += 1
		end
	end
	observe(`add with a result in [2^53, 1e16): {off} of {total} land one double (2) away from the correctly rounded sum (unchanged; not part of F1)`)
end

check("no remote handler raised an error (all sections)", #Shim.handlerErrors == 0, table.concat(Shim.handlerErrors, " | "))

print(`\n[Probes] original sections 1-5: {originalPassed} passed, {originalFailed} failed`)
print(`[Probes] correction sections 6-11: {passed - originalPassed} passed, {failed - originalFailed} failed`)
print(`[Probes] total: {passed} passed, {failed} failed`)
if failed > 0 then
	error("probes failed", 0)
end
