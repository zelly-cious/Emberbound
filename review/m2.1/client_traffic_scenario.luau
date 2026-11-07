-- client_traffic_scenario.luau (offline review harness, Milestone 2.1): a scripted two-player
-- session that prints every message each client receives, in a canonical form, so the output
-- of two source versions can be compared byte for byte (review/m2.1/run_checks.py runs it on
-- main and on the M2.1 branch). It uses only Milestone 2 entry points: no StatService call.

local BigNum = Shim.require("ReplicatedStorage/Shared/BigNum")
local ProgressionConfig = Shim.require("ReplicatedStorage/Shared/ProgressionConfig")

Shim.runScript("ServerScriptService/ServerInit")
local CombatService = Shim.require("ServerScriptService/CombatService")
local CurrencyService = Shim.require("ServerScriptService/CurrencyService")
local GOLD = ProgressionConfig.GoldCurrencyId
local UPGRADE = ProgressionConfig.TapDamageUpgrade

local function encode(value)
	if type(value) == "table" then
		local keys = {}
		for key in value do
			table.insert(keys, tostring(key))
		end
		table.sort(keys)
		local parts = {}
		for _, key in keys do
			local item = value[key]
			if item == nil then
				item = value[tonumber(key)]
			end
			table.insert(parts, key .. "=" .. encode(item))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return type(value) .. ":" .. tostring(value)
end

local step = 0
local function flush(label, players)
	step += 1
	for _, player in players do
		for index, message in player.Inbox do
			print(`{step} {label} {player.Name} #{index} {message.remote} {encode(message.payload)}`)
		end
		table.clear(player.Inbox)
	end
end

local alice = Shim.addPlayer("Alice")
local bob = Shim.addPlayer("Bob")
local everyone = { alice, bob }
flush("join", everyone)

Shim.fireServer("ClientReady", alice)
Shim.fireServer("ClientReady", bob)
flush("sync", everyone)

-- Ten taps on stage 1, then the stage 2 enemy.
for _ = 1, 16 do
	Shim.advanceClock(0.1)
	Shim.fireServer("RequestAttack", alice)
end
flush("taps", everyone)

-- Purchases from level 1 to 25 with exact Gold (257 + 23), as in guide U-5.
CurrencyService.Grant(alice, GOLD, BigNum.fromNumber(257), "Scenario")
local id = 0
for _ = 1, 24 do
	id += 1
	Shim.advanceClock(1)
	Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, id)
end
flush("buy to 24", everyone)
CurrencyService.Grant(alice, GOLD, BigNum.fromNumber(23), "Scenario")
id += 1
Shim.advanceClock(1)
Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, id)
flush("buy 25", everyone)

-- Replay, stale id, unaffordable, malformed and a burst.
Shim.advanceClock(5)
Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, id)
Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, 0)
Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, 1000)
Shim.fireServer("RequestUpgrade", alice, "Nope", 1001)
Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, "1002")
CurrencyService.Grant(alice, GOLD, BigNum.fromNumber(1000), "Scenario")
Shim.advanceClock(5)
for burst = 2001, 2100 do
	Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, burst)
end
flush("abuse", everyone)

-- Taps at the new damage, a huge balance, a direct SetTapDamage (QA helper H-5) and a purchase after it.
for _ = 1, 5 do
	Shim.advanceClock(0.1)
	Shim.fireServer("RequestAttack", alice)
end
CurrencyService.Grant(alice, GOLD, BigNum.parse("1.5e400"), "Scenario")
CombatService.SetTapDamage(alice, BigNum.parse("1e5000"))
Shim.advanceClock(1)
Shim.fireServer("RequestAttack", alice)
Shim.advanceClock(5)
id = 3000
for _ = 1, 3 do
	id += 1
	Shim.advanceClock(1)
	Shim.fireServer("RequestUpgrade", alice, UPGRADE.id, id)
end
flush("large values", everyone)

-- Bob plays a little; then Alice leaves and Carol joins.
CurrencyService.Grant(bob, GOLD, BigNum.fromNumber(5), "Scenario")
Shim.advanceClock(1)
Shim.fireServer("RequestUpgrade", bob, UPGRADE.id, 1)
Shim.fireServer("RequestUpgrade", bob, UPGRADE.id, 1)
flush("bob", everyone)
Shim.removePlayer(alice)
local carol = Shim.addPlayer("Carol")
Shim.fireServer("ClientReady", carol)
Shim.advanceClock(1)
Shim.fireServer("RequestAttack", carol)
Shim.fireServer("ClientReady", alice)
flush("leave and join", { bob, carol, alice })

print(`[traffic] handler errors: {#Shim.handlerErrors}; warnings: {#Shim.warnings}`)
for _, text in Shim.warnings do
	print(`[traffic] warning: {text}`)
end
