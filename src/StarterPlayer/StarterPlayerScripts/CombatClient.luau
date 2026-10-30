--!strict
--[[
	CombatClient
	Location: StarterPlayer > StarterPlayerScripts > CombatClient (LocalScript)
	Children: ArenaView, CombatHud, UpgradePanel (ModuleScripts)

	Client controller. It:
	  1. builds the local arena/camera (ArenaView), interface (CombatHud) and
	     upgrade panel (UpgradePanel)
	  2. listens for every server update FIRST, then tells the server it is
	     ready, so no initial sync can be missed
	  3. turns mouse clicks and touches into attack requests, and panel presses
	     into upgrade requests

	It sends no numbers the server trusts: attacks carry nothing, upgrade
	requests carry only an upgrade id and an increasing request id. It never
	changes HP, Gold, stage, damage or prices itself.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ProgressionConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProgressionConfig"))
local ArenaView = require(script:WaitForChild("ArenaView"))
local CombatHud = require(script:WaitForChild("CombatHud"))
local UpgradePanel = require(script:WaitForChild("UpgradePanel"))

type BigNum = BigNum.BigNum
type CombatView = CombatHud.CombatView
type UpgradeViewModel = UpgradePanel.UpgradeViewModel
type CombatSnapshot = GameConfig.CombatSnapshot
type CombatUpdate = GameConfig.CombatUpdate
type CurrencyUpdate = GameConfig.CurrencyUpdate
type UpgradeUpdate = GameConfig.UpgradeUpdate

local REMOTE_WAIT_TIMEOUT = 30
-- Some touch-screen PCs report a touch AND an emulated mouse click; ignore the click if a touch just happened.
local TOUCH_THEN_MOUSE_IGNORE_SECONDS = 0.5
local SYNC_RETRY_INTERVAL = 3
local SYNC_RETRY_ATTEMPTS = 3
local CORE_GUI_RETRY_ATTEMPTS = 10
local CORE_GUI_RETRY_INTERVAL = 0.5

local TAP_UPGRADE_ID = ProgressionConfig.TapDamageUpgrade.id
local GOLD_ID = ProgressionConfig.GoldCurrencyId

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local currentView: CombatView? = nil
local lastAttackRequestAt = -math.huge
local lastTouchAt = -math.huge
local lastUpgradeRequestId = 0

local function getRemoteEvent(remoteName: string): RemoteEvent
	local folderName = GameConfig.Network.RemotesFolderName
	local folder = ReplicatedStorage:WaitForChild(folderName, REMOTE_WAIT_TIMEOUT)
	if folder then
		local remote = folder:WaitForChild(remoteName, REMOTE_WAIT_TIMEOUT)
		if remote and remote:IsA("RemoteEvent") then
			return remote
		end
	end
	error(`[CombatClient] RemoteEvent ReplicatedStorage.{folderName}.{remoteName} was not found`)
end

-- No avatar exists, so hide character-only core UI and on-screen movement controls.
local function configureCoreGui()
	GuiService.TouchControlsEnabled = false
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	-- SetCore can fail until the core scripts have registered it, so retry a bounded number of times.
	for _ = 1, CORE_GUI_RETRY_ATTEMPTS do
		local success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if success then
			return
		end
		task.wait(CORE_GUI_RETRY_INTERVAL)
	end
	warn("[CombatClient] Could not disable the reset button (it does nothing without a character).")
end

-- Turns the network snapshot (BigNum strings) into a view; nil if any number is malformed.
local function decodeSnapshot(snapshot: CombatSnapshot): CombatView?
	local tapDamage = BigNum.parse(snapshot.tapDamage)
	local enemyHp = BigNum.parse(snapshot.enemyHp)
	local enemyMaxHp = BigNum.parse(snapshot.enemyMaxHp)
	if tapDamage == nil or enemyHp == nil or enemyMaxHp == nil then
		return nil
	end
	if typeof(snapshot.stage) ~= "number" or typeof(snapshot.enemyId) ~= "number" or typeof(snapshot.enemyName) ~= "string" then
		return nil
	end
	return {
		stage = snapshot.stage,
		tapDamage = tapDamage,
		enemyId = snapshot.enemyId,
		enemyName = snapshot.enemyName,
		enemyHp = enemyHp,
		enemyMaxHp = enemyMaxHp,
	}
end

local function decodeUpgradeView(raw: unknown): UpgradeViewModel?
	if typeof(raw) ~= "table" then
		return nil
	end
	local view: any = raw
	local currentValue = BigNum.parse(view.currentValue)
	if currentValue == nil or typeof(view.level) ~= "number" or typeof(view.maxLevel) ~= "number" then
		return nil
	end
	-- nextValue and nextCost are absent at max level; if present they must be valid.
	local nextValue = BigNum.parse(view.nextValue)
	local nextCost = BigNum.parse(view.nextCost)
	if (view.nextValue ~= nil and nextValue == nil) or (view.nextCost ~= nil and nextCost == nil) then
		return nil
	end
	return {
		upgradeId = tostring(view.upgradeId),
		level = view.level,
		maxLevel = view.maxLevel,
		currencyId = tostring(view.currencyId),
		currentValue = currentValue,
		nextValue = nextValue,
		nextCost = nextCost,
	}
end

local function onCombatUpdate(update: CombatUpdate)
	if typeof(update) ~= "table" or typeof(update.snapshot) ~= "table" then
		warn("[CombatClient] Ignored a malformed combat update")
		return
	end
	local view = decodeSnapshot(update.snapshot)
	if view == nil then
		warn("[CombatClient] Ignored a combat update with invalid numbers")
		return
	end

	local isFirstSnapshot = currentView == nil
	currentView = view

	-- ShowEnemy is a no-op when this enemy is already displayed.
	-- On "Defeated" the snapshot already describes the NEXT enemy, so the old one plays its defeat animation.
	ArenaView.ShowEnemy(view.enemyId, isFirstSnapshot or update.kind == "Defeated")

	if update.kind == "Hit" then
		ArenaView.PlayHit()
	end

	CombatHud.Render(view, update.kind ~= "Hit")

	local damage = BigNum.parse(update.damage)
	if damage and not BigNum.isZero(damage) then
		CombatHud.ShowDamage(damage)
	end

	local goldAwarded = BigNum.parse(update.goldAwarded)
	if goldAwarded and not BigNum.isZero(goldAwarded) then
		CombatHud.ShowGoldGain(goldAwarded)
	end
end

local function onCurrencyUpdate(update: CurrencyUpdate)
	if typeof(update) ~= "table" or typeof(update.balances) ~= "table" then
		warn("[CombatClient] Ignored a malformed currency update")
		return
	end
	local gold = BigNum.parse(update.balances[GOLD_ID])
	if gold == nil then
		warn("[CombatClient] Ignored a currency update without a valid Gold balance")
		return
	end
	CombatHud.SetGold(gold)
	UpgradePanel.SetBalance(gold)
end

local function onUpgradeUpdate(update: UpgradeUpdate)
	if typeof(update) ~= "table" or typeof(update.upgrades) ~= "table" then
		warn("[CombatClient] Ignored a malformed upgrade update")
		return
	end
	local view = decodeUpgradeView(update.upgrades[TAP_UPGRADE_ID])
	if view == nil then
		warn("[CombatClient] Ignored an upgrade update with invalid values")
		return
	end
	UpgradePanel.Render(view)

	local result = update.result
	if update.kind == "PurchaseResult" and typeof(result) == "table" then
		UpgradePanel.ShowResult(result.success == true, tostring(result.reason))
	end
end

local function tryRequestAttack(screenPosition: Vector2, requestAttackRemote: RemoteEvent)
	if currentView == nil then
		return -- not synced yet
	end
	if not CombatHud.IsInTapArea(screenPosition) or UpgradePanel.ContainsPoint(screenPosition) then
		return
	end

	-- Matches the server cooldown so we don't send requests the server would drop anyway.
	local now = os.clock()
	if now - lastAttackRequestAt < GameConfig.Combat.TapCooldown then
		return
	end
	lastAttackRequestAt = now

	requestAttackRemote:FireServer() -- no arguments: the server decides everything
	CombatHud.PlayTapRipple(screenPosition)
end

local function connectInput(requestAttackRemote: RemoteEvent)
	-- One handler for mouse and touch. gameProcessedEvent is true when the press
	-- landed on an interactive GUI element (the upgrade panel and its button,
	-- chat, Roblox menus), so those presses never become attacks.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.Touch then
			lastTouchAt = os.clock()
		elseif inputType == Enum.UserInputType.MouseButton1 then
			if os.clock() - lastTouchAt < TOUCH_THEN_MOUSE_IGNORE_SECONDS then
				return
			end
		else
			return
		end

		tryRequestAttack(Vector2.new(input.Position.X, input.Position.Y), requestAttackRemote)
	end)
end

local function start()
	task.spawn(configureCoreGui)

	local requestAttackRemote = getRemoteEvent(GameConfig.Network.RequestAttack)
	local clientReadyRemote = getRemoteEvent(GameConfig.Network.ClientReady)
	local combatUpdateRemote = getRemoteEvent(GameConfig.Network.CombatUpdate)
	local currencyUpdateRemote = getRemoteEvent(GameConfig.Network.CurrencyUpdate)
	local upgradeUpdateRemote = getRemoteEvent(GameConfig.Network.UpgradeUpdate)
	local requestUpgradeRemote = getRemoteEvent(GameConfig.Network.RequestUpgrade)

	ArenaView.Mount()
	CombatHud.Mount(playerGui)
	UpgradePanel.Mount(playerGui, function()
		-- Each press gets a new, increasing id; the server ignores any id it has already seen.
		lastUpgradeRequestId += 1
		requestUpgradeRemote:FireServer(TAP_UPGRADE_ID, lastUpgradeRequestId)
	end)

	-- Listen first, then announce readiness: no sync reply can arrive before we're listening.
	combatUpdateRemote.OnClientEvent:Connect(onCombatUpdate)
	currencyUpdateRemote.OnClientEvent:Connect(onCurrencyUpdate)
	upgradeUpdateRemote.OnClientEvent:Connect(onUpgradeUpdate)
	connectInput(requestAttackRemote)
	clientReadyRemote:FireServer()

	-- Safety net: if no sync arrived (e.g. the server was still starting), ask again a few times.
	task.spawn(function()
		for attempt = 1, SYNC_RETRY_ATTEMPTS do
			task.wait(SYNC_RETRY_INTERVAL)
			if currentView ~= nil then
				return
			end
			warn(`[CombatClient] No combat sync yet; re-sending ClientReady (attempt {attempt}/{SYNC_RETRY_ATTEMPTS})`)
			clientReadyRemote:FireServer()
		end
		-- Give the final retry the same response window before concluding that sync failed.
		task.wait(SYNC_RETRY_INTERVAL)
		if currentView == nil then
			warn("[CombatClient] Combat state never arrived. Check the server Output for CombatService errors.")
		end
	end)
end

start()
