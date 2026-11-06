--!strict
--[[
	StatService
	Location: ServerScriptService > StatService (ModuleScript)

	Milestone 2.1 (DECISIONS.md decision 1): the one place a player's combat stats are
	combined. It keeps each player's base stats and modifiers grouped by source (upgrade,
	hero, equipment, perk), combines them with StatRules (flat bonuses, then summed
	percentage bonuses, then multipliers, rounded down once) and applies the result through
	CombatService.SetTapDamage.

	UpgradeService reports the Tap Damage upgrade's value here as the base tap damage
	instead of setting tap damage itself. So upgrades and later hero, equipment or perk
	modifiers no longer overwrite each other: a purchase changes only the base, and every
	modifier still applies on top of it.

	Lifecycle (PlayerSessionService): added after CombatService and before UpgradeService,
	removed in reverse order. It has no client sync of its own; the combined tap damage
	reaches the client in CombatService's snapshot, exactly as in Milestone 2. Milestone 2
	has no modifier sources yet, so the combined tap damage always equals the upgrade value.

	Every call is non-yielding, so it keeps UpgradeService's purchase one atomic step.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local StatRules = require(ServerScriptService:WaitForChild("StatRules"))

type BigNum = BigNum.BigNum
export type Source = StatRules.Source
export type Modifier = StatRules.Modifier

local sheets: { [Player]: StatRules.Sheet } = {}

local StatService = {}

StatService.Stats = StatRules.Stats
StatService.Sources = StatRules.Sources

-- Combines a stat and pushes it to the service that uses it. False if nothing was applied.
local function apply(player: Player, sheet: StatRules.Sheet, statId: string): boolean
	local ok, combined = pcall(StatRules.combine, sheet, statId)
	if not ok then
		warn(`[StatService] Could not combine {statId} for {player.Name}: {combined}`)
		return false
	end
	if combined == nil then
		return false -- no base yet; modifiers wait for it
	end
	if statId == StatRules.Stats.TapDamage then
		return CombatService.SetTapDamage(player, combined)
	end
	return false
end

-- Requires CombatService.AddPlayer first; UpgradeService.AddPlayer then reports the starting base.
function StatService.AddPlayer(player: Player)
	if sheets[player] or player.Parent ~= Players then
		return
	end
	sheets[player] = StatRules.newSheet()
end

function StatService.RemovePlayer(player: Player)
	sheets[player] = nil
end

function StatService.HasPlayer(player: Player): boolean
	return sheets[player] ~= nil
end

--[[
	Sets a stat's base value and applies the combined result. Called by UpgradeService
	with the Tap Damage upgrade's value. Returns true if CombatService accepted the result.
]]
function StatService.SetBase(player: Player, statId: string, value: BigNum): boolean
	local sheet = sheets[player]
	if sheet == nil then
		return false
	end
	if not StatRules.setBase(sheet, statId, value) then
		warn(`[StatService] Rejected base value for {statId} ({player.Name})`)
		return false
	end
	return apply(player, sheet, statId)
end

--[[
	Adds or replaces one modifier (for later hero, equipment and perk sources) and applies
	the combined result once the stat has a base. Returns false if the modifier is invalid,
	the player is unknown, or the combined result could not be applied.
]]
function StatService.SetModifier(player: Player, statId: string, source: Source, modifierId: string, modifier: Modifier): boolean
	local sheet = sheets[player]
	if sheet == nil then
		return false
	end
	if not StatRules.setModifier(sheet, statId, source, modifierId, modifier) then
		warn(`[StatService] Rejected modifier {tostring(source)}/{tostring(modifierId)} for {tostring(statId)} ({player.Name})`)
		return false
	end
	if sheet.base[statId] == nil then
		return true
	end
	return apply(player, sheet, statId)
end

-- Removes one modifier and applies the combined result. False if it did not exist.
function StatService.RemoveModifier(player: Player, statId: string, source: Source, modifierId: string): boolean
	local sheet = sheets[player]
	if sheet == nil or not StatRules.removeModifier(sheet, statId, source, modifierId) then
		return false
	end
	if sheet.base[statId] == nil then
		return true
	end
	return apply(player, sheet, statId)
end

-- The current combined value of a stat, or nil (unknown player, or no base yet).
function StatService.GetValue(player: Player, statId: string): BigNum?
	local sheet = sheets[player]
	if sheet == nil then
		return nil
	end
	local ok, combined = pcall(StatRules.combine, sheet, statId)
	return if ok then combined else nil
end

return StatService
