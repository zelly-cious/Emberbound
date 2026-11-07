-- persistence_probes.luau (offline review harness, Milestone 3): save and load through the real server
-- scripts, against the fake engine's in-memory DataStore (review/offline-harness/roblox_shim.luau),
-- running as a live server (RunService:IsStudio() false). Reads the game code only. Every check prints PASS/FAIL.
-- Not Roblox Studio: DataStore timing, throttling, real yields and BindToClose limits are not modeled.
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

Shim.setStudio(false)
Shim.game.JobId = "server-A"
Shim.runScript("ServerScriptService/ServerInit")

local BigNum = Shim.require("ReplicatedStorage/Shared/BigNum")
local ProgressionConfig = Shim.require("ReplicatedStorage/Shared/ProgressionConfig")
local CombatService = Shim.require("ServerScriptService/CombatService")
local CurrencyService = Shim.require("ServerScriptService/CurrencyService")
local UpgradeService = Shim.require("ServerScriptService/UpgradeService")
local StatService = Shim.require("ServerScriptService/StatService")
local ProfileSchema = Shim.require("ServerScriptService/ProfileSchema")
local PlayerDataService = Shim.require("ServerScriptService/PlayerDataService")
local ProfileTransactions = Shim.require("ServerScriptService/ProfileTransactions")
local GOLD = ProgressionConfig.GoldCurrencyId
local UPGRADE = ProgressionConfig.TapDamageUpgrade

local function store()
	return Shim.dataStores.EmberboundProfiles
end
local function record(userId)
	local s = store()
	return s and s.records["player_" .. userId]
end
local function drain(player)
	local messages = table.clone(player.Inbox)
	table.clear(player.Inbox)
	return messages
end
local function gold(player)
	local balance = CurrencyService.GetBalance(player, GOLD)
	return if balance then BigNum.toString(balance) else "nil"
end
local function inGame(player)
	return CurrencyService.HasPlayer(player) or CombatService.HasPlayer(player) or StatService.HasPlayer(player)
		or UpgradeService.GetLevel(player, UPGRADE.id) ~= nil
end
local function ready(player)
	Shim.advanceClock(5) -- past the ClientReady cooldown
	Shim.fireServer("ClientReady", player)
	return drain(player)
end
local function tap(player, count)
	for _ = 1, count do
		Shim.advanceClock(0.2)
		Shim.fireServer("RequestAttack", player)
	end
	drain(player)
end
local requestIds = {}
local function buy(player)
	requestIds[player] = (requestIds[player] or 0) + 1
	Shim.advanceClock(1)
	Shim.fireServer("RequestUpgrade", player, UPGRADE.id, requestIds[player])
	local messages = drain(player)
	for _, message in messages do
		if message.remote == "UpgradeUpdate" and message.payload.result then
			return message.payload.result.reason
		end
	end
	return nil
end

print("== M3 persistence through the server scripts (fake engine, live-server path)")

-- 1. First join creates a locked record with the starting profile.
local alice = Shim.addPlayer("Alice", 1)
check("a first-time player joins with the starting state", inGame(alice) and gold(alice) == "0"
	and CombatService.GetStage(alice) == 1 and UpgradeService.GetLevel(alice, UPGRADE.id) == 1)
local first = record(1)
check("the first load writes the current profile version locked by this server",
	first ~= nil and first.profile.v == ProfileSchema.Version and first.profile.currencies[GOLD] == "0" and first.lock ~= nil
		and first.lock.job == "server-A", first and first.lock)
check("the record is tagged with the player's UserId (GDPR erasure)", store().userIds["player_1"] ~= nil
	and store().userIds["player_1"][1] == 1)
local sync = ready(alice)
check("the first sync is unchanged: CurrencyUpdate, UpgradeUpdate, CombatUpdate", #sync == 3
	and sync[1].remote == "CurrencyUpdate" and sync[2].remote == "UpgradeUpdate" and sync[3].remote == "CombatUpdate")

-- 2. Play, then autosave.
tap(alice, 40) -- four stage-1..4 enemies at tap damage 1 need 10+11+13+16 taps; at least three die
local goldBefore = gold(alice)
local reason = buy(alice)
check("a purchase after playing succeeds", reason == "Ok", reason)
local stageNow, levelNow, goldNow = CombatService.GetStage(alice), UpgradeService.GetLevel(alice, UPGRADE.id), gold(alice)
check("the purchase charged Gold and raised the level", goldNow ~= goldBefore and levelNow == 2, `{goldBefore} -> {goldNow}`)
local lockAt = record(1).lock.at
Shim.advanceClock(60)
local saved = record(1)
check("autosave writes the current Gold, stage and level after 60 s", saved.profile.currencies[GOLD] == goldNow
	and saved.profile.stage == stageNow and saved.profile.upgrades[UPGRADE.id] == levelNow,
	`{saved.profile.currencies[GOLD]}/{saved.profile.stage}/{saved.profile.upgrades[UPGRADE.id]}`)
check("autosave refreshes the lock", saved.lock ~= nil and saved.lock.at > lockAt)

-- 3. Leave saves the final state and releases the lock.
tap(alice, 15)
local finalGold, finalStage = gold(alice), CombatService.GetStage(alice)
Shim.removePlayer(alice)
local left = record(1)
check("leaving saves the final state and clears the lock", left.lock == nil and left.profile.currencies[GOLD] == finalGold
	and left.profile.stage == finalStage and left.profile.upgrades[UPGRADE.id] == 2,
	`{left.profile.currencies[GOLD]} vs {finalGold}`)
check("the player is gone from every service", not inGame(alice))

-- 4. Rejoin restores everything; tap damage is derived again through StatService.
local alice2 = Shim.addPlayer("Alice", 1)
check("rejoin restores Gold, stage and level", gold(alice2) == finalGold and CombatService.GetStage(alice2) == finalStage
	and UpgradeService.GetLevel(alice2, UPGRADE.id) == 2)
local expectedTap = BigNum.toString(ProgressionConfig.GetUpgradeValue(UPGRADE, 2))
check("tap damage is re-derived from the saved level", BigNum.toString(StatService.GetValue(alice2, StatService.Stats.TapDamage)) == expectedTap, expectedTap)
local resync = ready(alice2)
local combat = resync[3] and resync[3].payload.snapshot
check("the client's first sync shows the restored state", resync[1].payload.balances[GOLD] == finalGold
	and resync[2].payload.upgrades[UPGRADE.id].level == 2 and combat ~= nil and combat.stage == finalStage
	and combat.tapDamage == expectedTap and combat.enemyHp == combat.enemyMaxHp)
local price = BigNum.toString(ProgressionConfig.GetUpgradeCost(UPGRADE, 2))
check("the next price is the level 2 price", resync[2].payload.upgrades[UPGRADE.id].nextCost == price, price)
check("rejoining grants nothing: Gold equals the saved balance", gold(alice2) == record(1).profile.currencies[GOLD])

-- 5. Another server still holds the lock: the player is asked to rejoin; nothing is written.
local otherLock = { session = "other-session", job = "server-B", at = Shim.time() }
store().records["player_2"] = { profile = { v = 1, currencies = { [GOLD] = "500" }, stage = 9, upgrades = { [UPGRADE.id] = 4 }, activeSeconds = 0 }, lock = otherLock }
local bob = Shim.addPlayer("Bob", 2)
check("a profile locked by another live server is not loaded", not inGame(bob) and bob.KickMessage ~= nil
	and string.find(bob.KickMessage, "another server", 1, true) ~= nil, bob.KickMessage)
check("... and its record is untouched", record(2).lock.session == "other-session" and record(2).profile.currencies[GOLD] == "500")
Shim.fireServer("ClientReady", bob)
check("a ClientReady from the rejected player starts nothing", not inGame(bob) and #drain(bob) == 0)
Shim.removePlayer(bob)
check("the rejected player leaving writes nothing", record(2).lock.session == "other-session")

-- 6. A damaged record: rejected, untouched, never replaced by defaults.
store().records["player_3"] = { profile = { v = 1, currencies = { [GOLD] = "-5" }, stage = 2, upgrades = {} } }
local carol = Shim.addPlayer("Carol", 3)
check("a damaged record is rejected and the player asked to rejoin", not inGame(carol) and carol.KickMessage ~= nil, carol.KickMessage)
check("... and the record is not overwritten or claimed", record(3).profile.currencies[GOLD] == "-5" and record(3).lock == nil)
Shim.removePlayer(carol)

-- 7. A newer profile version: rejected with the out-of-date message.
store().records["player_4"] = { profile = { v = ProfileSchema.Version + 1, currencies = { [GOLD] = "1" }, stage = 1, upgrades = {} } }
local dan = Shim.addPlayer("Dan", 4)
check("a newer profile version is rejected with the out-of-date message", not inGame(dan)
	and string.find(dan.KickMessage or "", "out of date", 1, true) ~= nil, dan.KickMessage)
check("... and is not overwritten", record(4).profile.v == ProfileSchema.Version + 1)
Shim.removePlayer(dan)

-- 8. DataStore outage: no defaults, nothing written.
Shim.storeFaults.failNext = 100
local erin = Shim.addPlayer("Erin", 5)
check("a DataStore outage keeps the player out instead of starting on defaults", not inGame(erin) and erin.KickMessage ~= nil, erin.KickMessage)
check("... and creates no record", record(5) == nil)
Shim.removePlayer(erin)
Shim.storeFaults.failNext = 0

-- 9. Transient errors are retried.
Shim.storeFaults.failNext = 2
local fay = Shim.addPlayer("Fay", 6)
check("two transient DataStore errors are retried and the load succeeds", inGame(fay) and record(6) ~= nil and record(6).lock ~= nil)
ready(fay)
tap(fay, 10)

-- 10. Lock taken over by another server mid-session: this server stops writing.
local stolen = record(6)
stolen.lock = { session = "thief", job = "server-C", at = Shim.time() }
stolen.profile.currencies[GOLD] = "777"
Shim.advanceClock(60)
check("after losing the lock, autosave writes nothing", record(6).profile.currencies[GOLD] == "777" and record(6).lock.session == "thief")
check("... and the player is asked to rejoin", fay.KickMessage ~= nil and string.find(fay.KickMessage, "another server", 1, true) ~= nil, fay.KickMessage)
Shim.removePlayer(fay)
check("... and leaving writes nothing either", record(6).profile.currencies[GOLD] == "777" and record(6).lock.session == "thief")

-- 11. The player leaves while the profile is loading.
Shim.storeFaults.beforeUpdate = function()
	local gina = Shim.game:GetService("Players"):FindFirstChild("Gina")
	Shim.removePlayer(gina)
end
local gina = Shim.addPlayer("Gina", 7)
check("a player who leaves during the load never enters the services", not inGame(gina))
check("... and the lock claimed by that load is released", record(7) ~= nil and record(7).lock == nil)

-- A same-server rejoin must not steal a lock while the final save is pending.
local leaving = Shim.addPlayer("PendingRelease", 42)
CurrencyService.Grant(leaving, GOLD, BigNum.fromNumber(100), "Review")
local overlapping = nil
Shim.storeFaults.beforeUpdate = function()
	overlapping = Shim.addPlayer("OverlappingJoin", 42)
end
Shim.removePlayer(leaving)
check("a same-server rejoin waits safely when the final save exceeds the wait limit",
	overlapping ~= nil and not inGame(overlapping) and overlapping.KickMessage ~= nil)
check("the pending final save completes without losing its Gold",
	record(42).profile.currencies[GOLD] == "100" and record(42).lock == nil)
Shim.removePlayer(overlapping)
local afterRelease = Shim.addPlayer("AfterRelease", 42)
check("a retry after the previous release loads the latest Gold", gold(afterRelease) == "100")
Shim.removePlayer(afterRelease)

-- 12. Isolation and shutdown.
local hal = Shim.addPlayer("Hal", 8)
local ivy = Shim.addPlayer("Ivy", 9)
ready(hal)
ready(ivy)
tap(hal, 30)
local halGold, ivyGold = gold(hal), gold(ivy)
check("players' saved state is independent", halGold ~= ivyGold and record(8).profile.currencies[GOLD] == "0"
	and record(9).profile.currencies[GOLD] == "0" and record(1).profile.currencies[GOLD] == finalGold)
Shim.closeServer()
check("shutdown saves and releases every remaining player", record(8).lock == nil and record(9).lock == nil
	and record(8).profile.currencies[GOLD] == halGold and record(9).profile.currencies[GOLD] == ivyGold
	and record(1).lock == nil and record(1).profile.currencies[GOLD] == gold(alice2))
local calls = Shim.storeFaults.calls
Shim.removePlayer(hal)
Shim.removePlayer(ivy)
Shim.removePlayer(alice2)
check("PlayerRemoving after the shutdown save writes nothing more", Shim.storeFaults.calls == calls, Shim.storeFaults.calls - calls)

-- 13. Gold and stage stay consistent across a reload: a saved record never holds Gold without its stage.
local alice3 = Shim.addPlayer("Alice", 1)
check("a third join restores the shutdown-saved state", gold(alice3) == record(1).profile.currencies[GOLD]
	and CombatService.GetStage(alice3) == record(1).profile.stage)

-- Accepted server actions drive active time. Syncs, rejected requests and idle time do not.
local active = Shim.addPlayer("ActivePlayer", 43)
ready(active)
Shim.advanceClock(30)
check("joining, syncing and idling grant no active time", PlayerDataService.GetProfile(active).activeSeconds == 0)
tap(active, 1)
for _ = 1, 100 do
	Shim.fireServer("RequestAttack", active)
end
Shim.advanceClock(5)
check("an accepted tap starts a bounded active window", math.abs(PlayerDataService.GetProfile(active).activeSeconds - 5) < 0.001)
Shim.advanceClock(30)
check("idle credit is capped at ten seconds", math.abs(PlayerDataService.GetProfile(active).activeSeconds - 10) < 0.001)
check("an unaffordable purchase is refused", buy(active) == "InsufficientFunds")
Shim.advanceClock(30)
check("rejected purchases extend no active time", math.abs(PlayerDataService.GetProfile(active).activeSeconds - 10) < 0.001)
tap(active, 9)
local progress = PlayerDataService.GetProfile(active)
check("only an enemy defeat advances both highest-cleared records",
	progress.stage == 2 and progress.runHighestStage == 1 and progress.lifetimeHighestStage == 1)
check("a successful purchase is journaled as one complete operation", buy(active) == "Ok"
	and PlayerDataService.GetProfile(active).transactions[2].kind == "Upgrade")
check("gameplay changes mark the profile dirty", PlayerDataService.IsDirty(active))
Shim.advanceClock(60)
check("a successful checkpoint clears the saved revision", not PlayerDataService.IsDirty(active)
	and record(43).profile.runHighestStage == 1 and record(43).profile.upgrades[UPGRADE.id] == 2)

-- Mutating the live profile while an older snapshot is being written leaves a dirty revision.
local function duringSave(key)
	if key == "player_43" then
		CurrencyService.Grant(active, GOLD, BigNum.fromNumber(5), "DuringSave")
	else
		Shim.storeFaults.beforeUpdate = duringSave
	end
end
Shim.storeFaults.beforeUpdate = duringSave
Shim.advanceClock(60)
check("changes during a save stay dirty while the stored snapshot remains consistent",
	PlayerDataService.IsDirty(active) and gold(active) == "5" and record(43).profile.currencies[GOLD] == "0")
Shim.advanceClock(60)
check("the next checkpoint persists the newer revision", not PlayerDataService.IsDirty(active)
	and record(43).profile.currencies[GOLD] == "5")

-- Loaded metadata survives ordinary gameplay snapshots, including inactive future wallets.
local retained = ProfileSchema.new()
retained.stage = 4
retained.runHighestStage = 3
retained.lifetimeHighestStage = 40
retained.prestige.multiplier = BigNum.parse("1e400")
retained.claimedMilestones["stage:10"] = true
retained.currencies.Gems = BigNum.fromNumber(50)
retained.currencies.Crowns = BigNum.fromNumber(60)
store().records.player_44 = { profile = ProfileSchema.encode(retained) }
local keeper = Shim.addPlayer("MetadataKeeper", 44)
Shim.removePlayer(keeper)
local kept = record(44).profile
check("saves retain lifetime history, claims, huge multipliers and inactive wallets",
	kept.lifetimeHighestStage == 40 and kept.runHighestStage == 3 and kept.claimedMilestones["stage:10"]
	and kept.prestige.multiplier == "1e400" and kept.currencies.Gems == "50" and kept.currencies.Crowns == "60")

-- A prepared operation is recovered inside the normal load path, before gameplay starts.
local pending = ProfileTransactions.prepare(ProfileSchema.new(), { id = 1, kind = "Grant", currencyId = GOLD, amount = "25" })
store().records.player_45 = { profile = ProfileSchema.encode(pending) }
local recoverer = Shim.addPlayer("RecoveryPlayer", 45)
check("the normal join path recovers a durable pending grant", gold(recoverer) == "25"
	and record(45).profile.pendingTransaction == nil and record(45).profile.transactionId == 1)
Shim.removePlayer(recoverer)
recoverer = Shim.addPlayer("RecoveryPlayer", 45)
check("a later rejoin preserves the grant without replaying it", gold(recoverer) == "25"
	and record(45).profile.transactionId == 1)

-- Keep a failed release's final snapshot for a background retry.
local retrying = Shim.addPlayer("ReleaseRetry", 46)
CurrencyService.Grant(retrying, GOLD, BigNum.fromNumber(20), "Review")
Shim.storeFaults.failNext = 4
Shim.removePlayer(retrying)
local tooEarly = Shim.addPlayer("ReleaseRetryEarly", 46)
check("a failed final write keeps the next local join out until its retry", not inGame(tooEarly))
Shim.advanceClock(0)
check("the retained final snapshot is saved when the retry succeeds",
	record(46).profile.currencies[GOLD] == "20" and record(46).lock == nil)
Shim.removePlayer(tooEarly)
local retryJoined = Shim.addPlayer("ReleaseRetryJoined", 46)
check("a join after the retry restores the final balance", gold(retryJoined) == "20")

check("no handler errors", #Shim.handlerErrors == 0, table.concat(Shim.handlerErrors, " | "))
print(`[Persistence probes] {passed} passed, {failed} failed`)
if failed > 0 then
	error("persistence probes failed")
end
