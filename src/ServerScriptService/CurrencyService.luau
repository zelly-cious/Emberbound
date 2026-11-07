--!strict
--[[
	CurrencyService
	Location: ServerScriptService > CurrencyService (ModuleScript)

	Owns every player's balances (one Wallet each) and sends the owning client
	its balances after each change. Gold is earned in CombatService and spent
	in UpgradeService; both go through Grant / TrySpend here.

	Gacha compatibility: currencies are ids from ProgressionConfig. Future
	summon currencies are added there and handled here unchanged. There is no
	function that converts one currency into another.

	Milestone 3: AddPlayer accepts the balances loaded by PlayerDataService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local Wallet = require(ServerScriptService:WaitForChild("Wallet"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))

type BigNum = BigNum.BigNum
type Wallet = Wallet.Wallet
type CurrencyUpdate = GameConfig.CurrencyUpdate

type CurrencyState = {
	wallet: Wallet,
	synced: boolean, -- false until the client's first full sync; no partial updates before that
}

local REMOTE_WAIT_TIMEOUT = 10

local remotesFolder = ReplicatedStorage:WaitForChild(GameConfig.Network.RemotesFolderName)

local function getRemoteEvent(remoteName: string): RemoteEvent
	local instance = remotesFolder:WaitForChild(remoteName, REMOTE_WAIT_TIMEOUT)
	if instance and instance:IsA("RemoteEvent") then
		return instance
	end
	error(`[CurrencyService] Missing RemoteEvent ReplicatedStorage.{GameConfig.Network.RemotesFolderName}.{remoteName}`)
end

local currencyUpdateRemote = getRemoteEvent(GameConfig.Network.CurrencyUpdate)

local states: { [Player]: CurrencyState } = {}

local CurrencyService = {}

local function startingBalances(): { [string]: BigNum }
	local balances: { [string]: BigNum } = {}
	for _, currency in ProgressionConfig.Currencies do
		balances[currency.id] = BigNum.fromNumber(currency.startingBalance)
	end
	return balances
end

local function sendBalances(player: Player, state: CurrencyState)
	if not state.synced or player.Parent ~= Players then
		return
	end
	local update: CurrencyUpdate = { balances = Wallet.snapshot(state.wallet) }
	currencyUpdateRemote:FireClient(player, update)
end

local function logEconomy(message: string)
	if GameConfig.Debug.LogEconomy then
		print(`[CurrencyService] {message}`)
	end
end

-- saved: balances from the player's profile, already validated by ProfileSchema (nil for a new player).
function CurrencyService.AddPlayer(player: Player, saved: { [string]: BigNum }?)
	if states[player] or player.Parent ~= Players then
		return
	end
	local balances = startingBalances()
	if saved then
		for currencyId in balances do
			local balance = saved[currencyId]
			if balance ~= nil and BigNum.isValid(balance) then
				balances[currencyId] = balance
			end
		end
	end
	states[player] = {
		wallet = Wallet.new(balances),
		synced = false,
	}
end

function CurrencyService.RemovePlayer(player: Player)
	states[player] = nil
end

function CurrencyService.HasPlayer(player: Player): boolean
	return states[player] ~= nil
end

function CurrencyService.GetBalance(player: Player, currencyId: string): BigNum?
	local state = states[player]
	if not state or not Wallet.has(state.wallet, currencyId) then
		return nil
	end
	return Wallet.get(state.wallet, currencyId)
end

-- Adds a positive amount. `reason` describes the source (for logs and future analytics).
function CurrencyService.Grant(player: Player, currencyId: string, amount: BigNum, reason: string, recordTransaction: boolean?): boolean
	local state = states[player]
	if not state or not PlayerDataService.CanMutate(player) then
		return false
	end
	if not Wallet.grant(state.wallet, currencyId, amount) then
		warn(`[CurrencyService] Rejected {currencyId} grant for {player.Name} ({reason})`)
		return false
	end
	if recordTransaction ~= false then
		PlayerDataService.RecordTransaction(player, {
			kind = "Grant", currencyId = currencyId, amount = BigNum.toString(amount),
			reason = if reason == "" then nil else string.sub(reason, 1, 128),
		})
	end
	PlayerDataService.MarkDirty(player)
	logEconomy(`+{BigNum.toString(amount)} {currencyId} for {player.Name} ({reason})`)
	sendBalances(player, state)
	return true
end

-- Spends the whole amount only if the player can afford it. Never yields, never goes negative.
function CurrencyService.TrySpend(player: Player, currencyId: string, amount: BigNum, reason: string, recordTransaction: boolean?): boolean
	local state = states[player]
	if not state or not PlayerDataService.CanMutate(player) then
		return false
	end
	if not Wallet.trySpend(state.wallet, currencyId, amount) then
		return false
	end
	if recordTransaction ~= false then
		PlayerDataService.RecordTransaction(player, {
			kind = "Spend", currencyId = currencyId, amount = BigNum.toString(amount),
			reason = if reason == "" then nil else string.sub(reason, 1, 128),
		})
	end
	PlayerDataService.MarkDirty(player)
	logEconomy(`-{BigNum.toString(amount)} {currencyId} for {player.Name} ({reason})`)
	sendBalances(player, state)
	return true
end

-- Sends the full balances and allows change updates from now on.
function CurrencyService.SyncPlayer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.synced = true
	sendBalances(player, state)
end

return CurrencyService
