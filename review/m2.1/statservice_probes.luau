-- statservice_probes.luau (offline review harness, Milestone 2.1): StatService integration checks.
-- Runs the real server scripts against the fake engine (review/offline-harness/roblox_shim.luau)
-- with two players. Reads the game code only; it never edits it. Every check prints PASS/FAIL.
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

local BigNum = Shim.require("ReplicatedStorage/Shared/BigNum")
local ProgressionConfig = Shim.require("ReplicatedStorage/Shared/ProgressionConfig")

Shim.runScript("ServerScriptService/ServerInit")
local CombatService = Shim.require("ServerScriptService/CombatService")
local CurrencyService = Shim.require("ServerScriptService/CurrencyService")
local UpgradeService = Shim.require("ServerScriptService/UpgradeService")
local StatService = Shim.require("ServerScriptService/StatService")
local GOLD = ProgressionConfig.GoldCurrencyId
local UPGRADE = ProgressionConfig.TapDamageUpgrade
local TAP = StatService.Stats.TapDamage

local function n(value)
	return BigNum.fromNumber(value)
end
local function drain(player)
	local messages = table.clone(player.Inbox)
	table.clear(player.Inbox)
	return messages
end
local function value(player)
	local combined = StatService.GetValue(player, TAP)
	return if combined then BigNum.toString(combined) else "nil"
end
-- Tap damage as the client sees it: the last CombatUpdate snapshot in these messages.
local function clientTap(messages)
	local last = nil
	for _, message in messages do
		if message.remote == "CombatUpdate" then
			last = message.payload.snapshot.tapDamage
		end
	end
	return last
end
local requestIds = {}
local function buy(player)
	requestIds[player] = (requestIds[player] or 0) + 1
	Shim.advanceClock(1) -- keeps the upgrade rate limiter refilled
	Shim.fireServer("RequestUpgrade", player, UPGRADE.id, requestIds[player])
end
local function hit(player)
	Shim.advanceClock(1)
	Shim.fireServer("RequestAttack", player)
	local messages = drain(player)
	local last = messages[#messages]
	return if last and last.remote == "CombatUpdate" then last.payload.damage else nil
end

print("== M2.1 StatService integration (fake engine)")

-- Join: CurrencyService, CombatService, StatService, UpgradeService.
local alice = Shim.addPlayer("Alice")
local bob = Shim.addPlayer("Bob")
check("join adds both players to StatService", StatService.HasPlayer(alice) and StatService.HasPlayer(bob))
check("starting combined tap damage is the level 1 upgrade value (1)", value(alice) == "1" and value(bob) == "1")
check("nothing is sent before ClientReady (StatService has no sync of its own)", #drain(alice) == 0 and #drain(bob) == 0)

Shim.fireServer("ClientReady", alice)
Shim.fireServer("ClientReady", bob)
local sync = drain(alice)
drain(bob)
check("sync is unchanged: CurrencyUpdate, UpgradeUpdate, CombatUpdate with tap damage 1",
	#sync == 3 and sync[1].remote == "CurrencyUpdate" and sync[2].remote == "UpgradeUpdate"
		and sync[3].remote == "CombatUpdate" and sync[3].payload.snapshot.tapDamage == "1")

-- A purchase reports the new base; with no modifiers tap damage equals the upgrade value.
CurrencyService.Grant(alice, GOLD, n(1000), "Probe")
drain(alice)
buy(alice)
local first = drain(alice)
check("purchase order is unchanged: CurrencyUpdate, CombatUpdate Stats, UpgradeUpdate Ok",
	#first == 3 and first[1].remote == "CurrencyUpdate" and first[2].remote == "CombatUpdate"
		and first[2].payload.kind == "Stats" and first[3].payload.result and first[3].payload.result.reason == "Ok")
check("level 2 tap damage is 2 on the server and the client", value(alice) == "2" and clientTap(first) == "2")

-- Decision 1: a modifier survives purchases instead of being overwritten.
check("a hero x2 modifier applies at once (2 -> 4)",
	StatService.SetModifier(alice, TAP, "hero", "probe-hero", { multiplier = 2 }) and value(alice) == "4" and clientTap(drain(alice)) == "4")
buy(alice)
local afterBuy = drain(alice)
check("the next purchase raises only the base: (3) x2 = 6, not overwritten to 3",
	UpgradeService.GetLevel(alice, UPGRADE.id) == 3 and value(alice) == "6" and clientTap(afterBuy) == "6")
check("taps deal the combined damage (6)", hit(alice) == "6")
check("an equipment +4 flat bonus adds before the multiplier: (3 + 4) x2 = 14",
	StatService.SetModifier(alice, TAP, "equipment", "probe-sword", { flat = n(4) }) and value(alice) == "14" and clientTap(drain(alice)) == "14")
check("removing the hero modifier leaves 3 + 4 = 7",
	StatService.RemoveModifier(alice, TAP, "hero", "probe-hero") and value(alice) == "7" and clientTap(drain(alice)) == "7")
check("removing the last modifier restores the exact upgrade value (3)",
	StatService.RemoveModifier(alice, TAP, "equipment", "probe-sword") and value(alice) == "3" and clientTap(drain(alice)) == "3")

-- Invalid input changes nothing.
local warningsBefore = #Shim.warnings
check("an invalid modifier is rejected with a warning and no update",
	not StatService.SetModifier(alice, TAP, "hero", "bad", { multiplier = 0 }) and value(alice) == "3"
		and #drain(alice) == 0 and #Shim.warnings == warningsBefore + 1)

-- Player isolation.
check("Bob was unaffected by Alice's purchases and modifiers (tap 1, level 1, no messages)",
	value(bob) == "1" and UpgradeService.GetLevel(bob, UPGRADE.id) == 1 and #drain(bob) == 0)
StatService.SetModifier(bob, TAP, "perk", "probe-perk", { percent = 0.5 })
check("a modifier on Bob changes only Bob (1 x 1.5 -> 1; Alice still 3)", value(bob) == "1" and value(alice) == "3")
drain(bob)

-- The QA helper path (direct CombatService.SetTapDamage, guide H-5) still works,
-- and the next purchase resets tap damage to the combined value (guide N-3 / N-2).
CombatService.SetTapDamage(alice, BigNum.parse("1e5000"))
check("a direct SetTapDamage still sets tap damage (1e5000)", clientTap(drain(alice)) == "1e5000")
buy(alice)
check("the next purchase restores the combined value (level 4 -> 4)", value(alice) == "4" and clientTap(drain(alice)) == "4")

-- Leave: removed in reverse order; the other player keeps playing.
Shim.removePlayer(alice)
check("leave removes Alice from StatService, UpgradeService and CombatService",
	not StatService.HasPlayer(alice) and UpgradeService.GetLevel(alice, UPGRADE.id) == nil and not CombatService.HasPlayer(alice))
check("StatService calls for a departed player return false or nil",
	not StatService.SetModifier(alice, TAP, "hero", "late", { flat = n(1) })
		and not StatService.SetBase(alice, TAP, n(5)) and StatService.GetValue(alice, TAP) == nil)
CurrencyService.Grant(bob, GOLD, n(100), "Probe")
drain(bob)
buy(bob)
check("Bob still buys normally after Alice left (level 2: 2 x 1.5 = 3)", value(bob) == "3" and clientTap(drain(bob)) == "3")

-- Join while running: a fresh sheet.
local carol = Shim.addPlayer("Carol")
Shim.fireServer("ClientReady", carol)
check("a player who joins later starts fresh (tap 1, no modifiers)", value(carol) == "1" and clientTap(drain(carol)) == "1")

print("== M2.1 failure paths: a stat change that cannot be applied changes nothing")

local HUGE = BigNum.parse("9e9007199254740991") -- the largest exponent; x2 overflows it
local function gold(player)
	local balance = CurrencyService.GetBalance(player, GOLD)
	return if balance then BigNum.toString(balance) else "nil"
end
local function resultReason(messages)
	local reason = nil
	for _, message in messages do
		if message.remote == "UpgradeUpdate" and message.payload.result then
			reason = message.payload.result.reason
		end
	end
	return reason
end
-- The server's combat tap damage, read back through a full resync.
local function resyncTap(player)
	Shim.advanceClock(2)
	Shim.fireServer("ClientReady", player)
	return clientTap(drain(player))
end

local dana = Shim.addPlayer("Dana")
Shim.fireServer("ClientReady", dana)
drain(dana)
check("a flat 9e9007199254740991 bonus applies (still representable)",
	StatService.SetModifier(dana, TAP, "equipment", "huge", { flat = HUGE })
		and value(dana) == "9e9007199254740991" and clientTap(drain(dana)) == "9e9007199254740991")
local warningsBeforeDouble = #Shim.warnings
check("a x2 modifier on top would overflow: SetModifier returns false, one warning, no update",
	not StatService.SetModifier(dana, TAP, "perk", "double", { multiplier = 2 })
		and #drain(dana) == 0 and #Shim.warnings == warningsBeforeDouble + 1)
check("the failed x2 was not installed (RemoveModifier finds nothing); the previous sheet is intact",
	not StatService.RemoveModifier(dana, TAP, "perk", "double") and value(dana) == "9e9007199254740991")
check("combat tap damage is unchanged after the failed update (resync: 9e9007199254740991)", resyncTap(dana) == "9e9007199254740991")
CurrencyService.Grant(dana, GOLD, n(100), "Probe")
drain(dana)
buy(dana)
local danaBuy = drain(dana)
check("success path unchanged: a purchase with the flat bonus charges 5, levels to 2, replies Ok, tap 9e9007199254740991",
	resultReason(danaBuy) == "Ok" and gold(dana) == "95" and UpgradeService.GetLevel(dana, UPGRADE.id) == 2
		and #danaBuy == 3 and danaBuy[1].remote == "CurrencyUpdate" and danaBuy[2].remote == "CombatUpdate"
		and clientTap(danaBuy) == "9e9007199254740991")
check("a x0.5 then a x2 fit (4.5e... then 9e9007199254740991)",
	StatService.SetModifier(dana, TAP, "perk", "half", { multiplier = 0.5 })
		and StatService.SetModifier(dana, TAP, "hero", "double", { multiplier = 2 }) and value(dana) == "9e9007199254740991")
drain(dana)
check("removing the x0.5 would overflow: RemoveModifier returns false, keeps it, sends nothing",
	not StatService.RemoveModifier(dana, TAP, "perk", "half") and #drain(dana) == 0 and value(dana) == "9e9007199254740991")
check("combat tap damage is still 9e9007199254740991", resyncTap(dana) == "9e9007199254740991")

-- A failed upgrade application: a sheet whose modifiers were stored before a base existed
-- (as when modifiers are restored before the upgrades report), so the base cannot be combined.
local eve = Shim.addPlayer("Eve")
Shim.fireServer("ClientReady", eve)
CurrencyService.Grant(eve, GOLD, n(100), "Probe")
drain(eve)
StatService.RemovePlayer(eve)
StatService.AddPlayer(eve)
check("without a base, the flat 9e9007199254740991 and the x2 are only stored",
	StatService.SetModifier(eve, TAP, "equipment", "huge", { flat = HUGE })
		and StatService.SetModifier(eve, TAP, "perk", "double", { multiplier = 2 }) and StatService.GetValue(eve, TAP) == nil)
buy(eve)
local eveFailed = drain(eve)
check("a purchase whose new tap damage cannot be applied is refused before any Gold moves: EffectFailed, Gold 100, level 1, no Gold or combat update",
	resultReason(eveFailed) == "EffectFailed" and #eveFailed == 1 and gold(eve) == "100" and UpgradeService.GetLevel(eve, UPGRADE.id) == 1)
check("combat tap damage is unchanged after the refused purchase (resync: 1)", resyncTap(eve) == "1")
check("once the x2 is removed the purchase succeeds: Gold 95, level 2, Ok, tap 9e9007199254740991",
	(function()
		if not StatService.RemoveModifier(eve, TAP, "perk", "double") then
			return false
		end
		buy(eve)
		local messages = drain(eve)
		return resultReason(messages) == "Ok" and gold(eve) == "95" and UpgradeService.GetLevel(eve, UPGRADE.id) == 2
			and clientTap(messages) == "9e9007199254740991"
	end)())

-- Fault injection: CombatService rejects the prepared damage after the spend (not reachable today).
local realSetTapDamage = CombatService.SetTapDamage
CombatService.SetTapDamage = function()
	return false
end
buy(eve)
local refunded = drain(eve)
CombatService.SetTapDamage = realSetTapDamage
check("if the prepared damage is still rejected after the spend, the purchase is undone: EffectFailed, Gold refunded to 95, level 2",
	resultReason(refunded) == "EffectFailed" and gold(eve) == "95" and UpgradeService.GetLevel(eve, UPGRADE.id) == 2)
check("... and combat tap damage and the sheet are unchanged (resync 9e9007199254740991; next purchase Ok, level 3, Gold 90)",
	resyncTap(eve) == "9e9007199254740991"
		and (function()
			buy(eve)
			local messages = drain(eve)
			return resultReason(messages) == "Ok" and UpgradeService.GetLevel(eve, UPGRADE.id) == 3 and gold(eve) == "90"
		end)())

print("== Studio QA bridge (review/m2.1/EmberboundStatQA.server.luau), offline")

-- The fake engine has no Instance.new or ServerStorage: give the bridge minimal stand-ins.
local bridgeInstance = nil
local fakeServerStorage = { Name = "ServerStorage" }
local realGetService = Shim.game.GetService
Shim.game.GetService = function(self, name)
	if name == "ServerStorage" then
		return fakeServerStorage
	end
	return realGetService(self, name)
end
-- _G explicitly: the fake engine has its own local named Instance in the same chunk.
_G.Instance = {
	new = function(className)
		assert(className == "BindableFunction", "the bridge creates only a BindableFunction")
		bridgeInstance = { ClassName = className }
		return bridgeInstance
	end,
}
Shim.addSource("ServerScriptService/EmberboundStatQA", "Script", SOURCES["QA/EmberboundStatQA"])
Shim.runScript("ServerScriptService/EmberboundStatQA")
Shim.game.GetService = realGetService
check("the bridge installs EmberboundStatQA in ServerStorage",
	bridgeInstance ~= nil and bridgeInstance.Name == "EmberboundStatQA" and bridgeInstance.Parent == fakeServerStorage)
local function invoke(...)
	if bridgeInstance == nil then
		return ""
	end
	return bridgeInstance.OnInvoke(...)
end
local function says(text, expected)
	return string.find(text, expected, 1, true) ~= nil
end

local finn = Shim.addPlayer("Finn")
Shim.fireServer("ClientReady", finn)
CurrencyService.Grant(finn, GOLD, n(100), "Probe")
buy(finn)
drain(finn)
local x2 = invoke("x2", "Finn")
check("bridge x2: true, tap 2 -> 4, and the client sees 4", says(x2, "-> true") and says(x2, "tapDamage=4") and clientTap(drain(finn)) == "4", x2)
buy(finn)
local afterPurchase = invoke("state", "Finn")
check("REQUIRED STUDIO CHECK, offline: after a purchase the x2 survives (level 3: 6, not 3)",
	says(afterPurchase, "tapDamage=6") and UpgradeService.GetLevel(finn, UPGRADE.id) == 3 and clientTap(drain(finn)) == "6", afterPurchase)
local removed = invoke("remove", "Finn")
check("bridge remove: true, back to 3", says(removed, "-> true") and says(removed, "tapDamage=3") and clientTap(drain(finn)) == "3", removed)
local overflow = invoke("overflow", "Finn")
check("bridge overflow: flat true, x2 false, tap stays 9e9007199254740991",
	says(overflow, "flat 9e9007199254740991 -> true") and says(overflow, "x2 -> false") and says(overflow, "tapDamage=9e9007199254740991"), overflow)
local cleared = invoke("clearOverflow", "Finn")
check("bridge clearOverflow: x2 was never installed (false), flat removed (true), back to 3",
	says(cleared, "remove x2 -> false") and says(cleared, "remove flat -> true") and says(cleared, "tapDamage=3"), cleared)
check("bridge reports an unknown player", invoke("state", "Nobody") == "[QA] player not found")
drain(finn)

check("no remote handler raised an error", #Shim.handlerErrors == 0, table.concat(Shim.handlerErrors, "; "))

print(`[StatService probes] {passed} passed, {failed} failed`)
if failed > 0 then
	error("StatService probes failed", 0)
end
