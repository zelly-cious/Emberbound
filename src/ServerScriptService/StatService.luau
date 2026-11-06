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

	Every change is transactional and non-yielding. It is made on a copy of the player's
	sheet; the copy is combined; and it replaces the sheet only once CombatService has
	accepted the combined value. If combining fails (a BigNum exponent overflow) or the
	value cannot be applied, the previous sheet and the previous tap damage stay exactly as
	they were. PrepareBase splits this in two, so UpgradeService can find a failure before
	any Gold moves and commit only after the spend.

	Lifecycle (PlayerSessionService): added after CombatService and before UpgradeService,
	removed in reverse order. It has no client sync of its own; the combined tap damage
	reaches the client in CombatService's snapshot, exactly as in Milestone 2. Milestone 2
	has no modifier sources yet, so the combined tap damage always equals the upgrade value.
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

type Prepared = {
	player: Player,
	from: StatRules.Sheet, -- the sheet the change was prepared from; a commit requires it to still be current
	sheet: StatRules.Sheet, -- the changed copy
	statId: string,
	value: BigNum?, -- combined value to apply; nil when the stat has no base yet
}

local sheets: { [Player]: StatRules.Sheet } = {}

local StatService = {}

StatService.Stats = StatRules.Stats
StatService.Sources = StatRules.Sources

-- The conditions CombatService.SetTapDamage checks, so a prepared change can always be committed.
local function canApply(player: Player, statId: string, value: BigNum): boolean
	return statId == StatRules.Stats.TapDamage and CombatService.HasPlayer(player) and BigNum.isValid(value) and not BigNum.isZero(value)
end

-- Makes `change` on a copy of the player's sheet and combines it. Nothing is changed; nil if the change is invalid or cannot be applied.
local function prepare(player: Player, statId: string, change: (StatRules.Sheet) -> boolean): Prepared?
	local sheet = sheets[player]
	if sheet == nil then
		return nil
	end
	local candidate = StatRules.copySheet(sheet)
	if not change(candidate) then
		return nil
	end
	if candidate.base[statId] == nil then
		return { player = player, from = sheet, sheet = candidate, statId = statId, value = nil }
	end
	local ok, combined = pcall(StatRules.combine, candidate, statId)
	if not ok then
		warn(`[StatService] Could not combine {statId} for {player.Name}; the change was not made: {combined}`)
		return nil
	end
	if combined == nil or not canApply(player, statId, combined) then
		return nil
	end
	return { player = player, from = sheet, sheet = candidate, statId = statId, value = combined }
end

-- Applies a prepared change: CombatService first, then the sheet. On any failure nothing changes.
local function commit(prepared: Prepared): boolean
	if sheets[prepared.player] ~= prepared.from then
		return false -- the player left, or the sheet changed since this was prepared
	end
	local value = prepared.value
	if value ~= nil and not CombatService.SetTapDamage(prepared.player, value) then
		return false
	end
	sheets[prepared.player] = prepared.sheet
	return true
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
	Prepares a new base value without changing anything. Returns the function that applies
	it (true on success), or nil if the value is invalid or the combined result cannot be
	applied (for example a BigNum overflow). Call the returned function in the same
	non-yielding step: it refuses to apply if the sheet changed in between.
]]
function StatService.PrepareBase(player: Player, statId: string, value: BigNum): (() -> boolean)?
	local prepared = prepare(player, statId, function(candidate: StatRules.Sheet): boolean
		return StatRules.setBase(candidate, statId, value)
	end)
	if prepared == nil then
		return nil
	end
	local ready = prepared
	return function(): boolean
		return commit(ready)
	end
end

-- Sets a stat's base value and applies the combined result. False, with nothing changed, if it cannot be applied.
function StatService.SetBase(player: Player, statId: string, value: BigNum): boolean
	local apply = StatService.PrepareBase(player, statId, value)
	if apply == nil then
		if sheets[player] ~= nil then
			warn(`[StatService] Base value for {statId} was not applied ({player.Name})`)
		end
		return false
	end
	return apply()
end

--[[
	Adds or replaces one modifier (for later hero, equipment and perk sources) and applies
	the combined result once the stat has a base. Returns false, with the previous sheet and
	tap damage unchanged, if the modifier is invalid, the player is unknown, or the combined
	result cannot be applied. Before a base exists the modifier is only stored; a base that
	later cannot be combined with it is refused the same way.
]]
function StatService.SetModifier(player: Player, statId: string, source: Source, modifierId: string, modifier: Modifier): boolean
	if sheets[player] == nil then
		return false
	end
	local valid = true
	local prepared = prepare(player, statId, function(candidate: StatRules.Sheet): boolean
		valid = StatRules.setModifier(candidate, statId, source, modifierId, modifier)
		return valid
	end)
	if not valid then
		warn(`[StatService] Rejected modifier {tostring(source)}/{tostring(modifierId)} for {tostring(statId)} ({player.Name})`)
		return false
	end
	return prepared ~= nil and commit(prepared)
end

-- Removes one modifier and applies the combined result. False, with nothing changed, if it did not exist or the result cannot be applied.
function StatService.RemoveModifier(player: Player, statId: string, source: Source, modifierId: string): boolean
	local prepared = prepare(player, statId, function(candidate: StatRules.Sheet): boolean
		return StatRules.removeModifier(candidate, statId, source, modifierId)
	end)
	return prepared ~= nil and commit(prepared)
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
