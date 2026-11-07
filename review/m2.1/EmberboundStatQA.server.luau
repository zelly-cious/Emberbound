-- Studio QA helper for the M2.1 StatService checks (draft PR #3). NOT part of Emberbound and never in src/.
-- In Studio: ServerScriptService > + > Script, rename it EmberboundStatQA, paste this file, then Play.
-- A Script in the game shares the game's modules, so it reaches the live StatService (the Command Bar
-- may get its own module copies). It does nothing outside Studio, and only server code can invoke it.
--
-- Reuse: this file is the kept source. In a separate QA place it may stay installed with Enabled
-- unticked between sessions (tick Enabled before Play to use it). It must NOT be in the release place:
-- the Appendix B parity checker counts every extra script, enabled or disabled, so even a disabled copy
-- makes parity fail (extra scripts: 1). Remove it before any parity check that is recorded.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local StatService = require(ServerScriptService:WaitForChild("StatService"))

local TAP = "TapDamage"

local function findPlayer(name)
	if name ~= nil then
		return Players:FindFirstChild(name)
	end
	return Players:GetPlayers()[1]
end

local function describe(player)
	local value = StatService.GetValue(player, TAP)
	return `{player.Name}: sheet={tostring(StatService.HasPlayer(player))} tapDamage={if value then BigNum.toString(value) else "nil"}`
end

local bridge = Instance.new("BindableFunction")
bridge.Name = "EmberboundStatQA"
bridge.OnInvoke = function(action, playerName)
	local player = findPlayer(playerName)
	if player == nil then
		return "[QA] player not found"
	end
	if action == "x2" then
		local ok = StatService.SetModifier(player, TAP, "hero", "qa", { multiplier = 2 })
		return `[QA] set hero/qa x2 -> {tostring(ok)} | {describe(player)}`
	elseif action == "remove" then
		local ok = StatService.RemoveModifier(player, TAP, "hero", "qa")
		return `[QA] remove hero/qa -> {tostring(ok)} | {describe(player)}`
	elseif action == "overflow" then
		local flat = StatService.SetModifier(player, TAP, "equipment", "qa-huge", { flat = BigNum.parse("9e9007199254740991") })
		local double = StatService.SetModifier(player, TAP, "perk", "qa-double", { multiplier = 2 })
		return `[QA] flat 9e9007199254740991 -> {tostring(flat)}; x2 -> {tostring(double)} (expected false) | {describe(player)}`
	elseif action == "clearOverflow" then
		local double = StatService.RemoveModifier(player, TAP, "perk", "qa-double")
		local flat = StatService.RemoveModifier(player, TAP, "equipment", "qa-huge")
		return `[QA] remove x2 -> {tostring(double)} (expected false); remove flat -> {tostring(flat)} | {describe(player)}`
	elseif action == "state" then
		return "[QA] " .. describe(player)
	end
	return "[QA] unknown action " .. tostring(action)
end
bridge.Parent = ServerStorage
print("[QA] EmberboundStatQA bridge ready in ServerStorage")
