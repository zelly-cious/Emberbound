--!strict
--[[
	UpgradeService
	Location: ServerScriptService > UpgradeService (ModuleScript)

	Server-authoritative upgrades. Milestone 2 has one upgrade: Tap Damage.

	A purchase is one non-yielding transaction:
	  rate limit -> validate request id and upgrade id -> check the level cap ->
	  spend Gold (all or nothing) -> raise the level -> report the new base tap
	  damage to StatService (which combines modifiers and sets CombatService's
	  tap damage) -> reply to that player only.
	Prices and values come only from ProgressionConfig; the client sends ids.

	No duplicate charges: each successful spend raises the level by exactly one,
	and a request id that is not newer than the last one accepted is ignored, so
	a replayed request can never charge twice.

	Milestone 3 hook: AddPlayer will accept saved levels from PlayerDataService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local StatService = require(ServerScriptService:WaitForChild("StatService"))

type UpgradeDefinition = ProgressionConfig.UpgradeDefinition
type UpgradeView = GameConfig.UpgradeView
type UpgradeUpdate = GameConfig.UpgradeUpdate
type PurchaseReason = GameConfig.PurchaseReason

type UpgradeState = {
	levels: { [string]: number },
	lastRequestId: number,
	synced: boolean, -- false until the client's first full sync
}

local REMOTE_WAIT_TIMEOUT = 10
local MAX_REQUEST_ID = 9007199254740991 -- request ids stay exact integers

local remotesFolder = ReplicatedStorage:WaitForChild(GameConfig.Network.RemotesFolderName)

local function getRemoteEvent(remoteName: string): RemoteEvent
	local instance = remotesFolder:WaitForChild(remoteName, REMOTE_WAIT_TIMEOUT)
	if instance and instance:IsA("RemoteEvent") then
		return instance
	end
	error(`[UpgradeService] Missing RemoteEvent ReplicatedStorage.{GameConfig.Network.RemotesFolderName}.{remoteName}`)
end

local requestUpgradeRemote = getRemoteEvent(GameConfig.Network.RequestUpgrade)
local upgradeUpdateRemote = getRemoteEvent(GameConfig.Network.UpgradeUpdate)

local requestLimiter = RateLimiter.new(GameConfig.Network.UpgradeRequestBurst, GameConfig.Network.UpgradeRequestsPerSecond)

local states: { [Player]: UpgradeState } = {}
local started = false

local UpgradeService = {}

local function buildView(definition: UpgradeDefinition, level: number): UpgradeView
	local atMax = level >= definition.maxLevel
	return {
		upgradeId = definition.id,
		level = level,
		maxLevel = definition.maxLevel,
		currencyId = definition.currencyId,
		currentValue = BigNum.toString(ProgressionConfig.GetUpgradeValue(definition, level)),
		nextValue = if atMax then nil else BigNum.toString(ProgressionConfig.GetUpgradeValue(definition, level + 1)),
		nextCost = if atMax then nil else BigNum.toString(ProgressionConfig.GetUpgradeCost(definition, level)),
	}
end

local function buildViews(state: UpgradeState): { [string]: UpgradeView }
	local views: { [string]: UpgradeView } = {}
	for _, definition in ProgressionConfig.Upgrades do
		views[definition.id] = buildView(definition, state.levels[definition.id])
	end
	return views
end

local function send(player: Player, state: UpgradeState, update: UpgradeUpdate)
	if not state.synced or player.Parent ~= Players then
		return
	end
	upgradeUpdateRemote:FireClient(player, update)
end

local function reply(player: Player, state: UpgradeState, requestId: number, upgradeId: string, reason: PurchaseReason)
	send(player, state, {
		kind = "PurchaseResult",
		upgrades = buildViews(state),
		result = {
			requestId = requestId,
			upgradeId = upgradeId,
			success = reason == "Ok",
			reason = reason,
		},
	})
end

-- Reports the stat an upgrade controls to StatService. Milestone 2 only has Tap Damage, whose value is the base tap damage.
local function applyUpgradeEffect(player: Player, definition: UpgradeDefinition, level: number): boolean
	if definition.id == ProgressionConfig.TapDamageUpgrade.id then
		return StatService.SetBase(player, StatService.Stats.TapDamage, ProgressionConfig.GetUpgradeValue(definition, level))
	end
	warn(`[UpgradeService] No effect is defined for upgrade {definition.id}`)
	return false
end

local function isValidRequestId(requestId: unknown, lastRequestId: number): boolean
	return typeof(requestId) == "number"
		and requestId % 1 == 0
		and requestId > lastRequestId
		and requestId <= MAX_REQUEST_ID
end

local function handlePurchaseRequest(player: Player, upgradeId: unknown, requestId: unknown)
	local state = states[player]
	if not state or not state.synced then
		return -- not ready yet; the client's panel stays disabled until the first sync
	end
	if not requestLimiter:allow(player) then
		return -- over the limit: dropped without a reply, like rapid taps
	end
	if not isValidRequestId(requestId, state.lastRequestId) or typeof(upgradeId) ~= "string" then
		return -- malformed or replayed request
	end
	local definition = ProgressionConfig.GetUpgrade(upgradeId :: string)
	if definition == nil then
		return -- unknown upgrade id
	end

	local acceptedRequestId = requestId :: number
	state.lastRequestId = acceptedRequestId

	local level = state.levels[definition.id]
	if level >= definition.maxLevel then
		reply(player, state, acceptedRequestId, definition.id, "MaxLevel")
		return
	end
	if not CombatService.HasPlayer(player) then
		return -- player is leaving; charge nothing
	end

	-- Everything from here to the reply runs without yielding: one atomic transaction.
	local cost = ProgressionConfig.GetUpgradeCost(definition, level)
	if not CurrencyService.TrySpend(player, definition.currencyId, cost, `Upgrade:{definition.id}`) then
		reply(player, state, acceptedRequestId, definition.id, "InsufficientFunds")
		return
	end

	local newLevel = level + 1
	state.levels[definition.id] = newLevel
	applyUpgradeEffect(player, definition, newLevel)
	reply(player, state, acceptedRequestId, definition.id, "Ok")
end

-- Requires CombatService.AddPlayer and StatService.AddPlayer first, so the starting tap damage can be applied.
function UpgradeService.AddPlayer(player: Player)
	if states[player] or player.Parent ~= Players then
		return
	end
	local levels: { [string]: number } = {}
	for _, definition in ProgressionConfig.Upgrades do
		levels[definition.id] = definition.startingLevel
	end
	states[player] = {
		levels = levels,
		lastRequestId = 0,
		synced = false,
	}
	for _, definition in ProgressionConfig.Upgrades do
		applyUpgradeEffect(player, definition, levels[definition.id])
	end
end

function UpgradeService.RemovePlayer(player: Player)
	states[player] = nil
	requestLimiter:remove(player)
end

function UpgradeService.GetLevel(player: Player, upgradeId: string): number?
	local state = states[player]
	if not state then
		return nil
	end
	return state.levels[upgradeId]
end

-- Sends every upgrade's current view and allows purchase replies from now on.
function UpgradeService.SyncPlayer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.synced = true
	send(player, state, {
		kind = "Sync",
		upgrades = buildViews(state),
	})
end

-- Connects the purchase remote. Safe to call once; repeated calls are ignored.
function UpgradeService.Start()
	if started then
		warn("[UpgradeService] Start() was called more than once; ignoring.")
		return
	end
	started = true

	requestUpgradeRemote.OnServerEvent:Connect(function(player: Player, upgradeId: unknown, requestId: unknown)
		handlePurchaseRequest(player, upgradeId, requestId)
	end)
end

return UpgradeService
