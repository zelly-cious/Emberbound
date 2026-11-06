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

check("no remote handler raised an error", #Shim.handlerErrors == 0, table.concat(Shim.handlerErrors, "; "))

print(`[StatService probes] {passed} passed, {failed} failed`)
if failed > 0 then
	error("StatService probes failed", 0)
end
