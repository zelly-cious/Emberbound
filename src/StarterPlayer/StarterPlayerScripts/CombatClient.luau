--!strict
--[[
	CombatClient
	Location: StarterPlayer > StarterPlayerScripts > CombatClient (LocalScript)
	Children: ArenaView (ModuleScript), CombatHud (ModuleScript)

	Client controller. It:
	  1. builds the local arena/camera (ArenaView) and interface (CombatHud)
	  2. listens for authoritative CombatUpdate events, THEN tells the server it
	     is ready, so the first full sync can never be missed
	  3. turns mouse clicks and touches into attack requests

	It sends no numbers to the server and never changes HP, gold or stage itself.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ArenaView = require(script:WaitForChild("ArenaView"))
local CombatHud = require(script:WaitForChild("CombatHud"))

type CombatSnapshot = GameConfig.CombatSnapshot
type CombatUpdate = GameConfig.CombatUpdate

local REMOTE_WAIT_TIMEOUT = 30
-- Some touch-screen PCs report a touch AND an emulated mouse click; ignore the click if a touch just happened.
local TOUCH_THEN_MOUSE_IGNORE_SECONDS = 0.5
local SYNC_RETRY_INTERVAL = 3
local SYNC_RETRY_ATTEMPTS = 3
local CORE_GUI_RETRY_ATTEMPTS = 10
local CORE_GUI_RETRY_INTERVAL = 0.5

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local currentSnapshot: CombatSnapshot? = nil
local lastAttackRequestAt = -math.huge
local lastTouchAt = -math.huge

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

local function onCombatUpdate(update: CombatUpdate)
	if typeof(update) ~= "table" or typeof(update.snapshot) ~= "table" then
		warn("[CombatClient] Ignored a malformed combat update")
		return
	end

	local snapshot = update.snapshot
	local isFirstSnapshot = currentSnapshot == nil
	currentSnapshot = snapshot

	-- ShowEnemy is a no-op when this enemy is already displayed.
	-- On "Defeated" the snapshot already describes the NEXT enemy, so the old one plays its defeat animation.
	ArenaView.ShowEnemy(snapshot.enemyId, isFirstSnapshot or update.kind == "Defeated")

	if update.kind == "Hit" then
		ArenaView.PlayHit()
	end

	CombatHud.Render(snapshot, update.kind ~= "Hit")

	local damage = update.damage
	if damage then
		CombatHud.ShowDamage(damage)
	end

	local goldAwarded = update.goldAwarded
	if goldAwarded and goldAwarded > 0 then
		CombatHud.ShowGoldGain(goldAwarded)
	end
end

local function tryRequestAttack(screenPosition: Vector2, requestAttackRemote: RemoteEvent)
	if currentSnapshot == nil then
		return -- not synced yet
	end
	if not CombatHud.IsInTapArea(screenPosition) then
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
	-- landed on an interactive GUI element (buttons, chat, Roblox menus), so
	-- those presses never become attacks.
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

	ArenaView.Mount()
	CombatHud.Mount(playerGui)

	local requestAttackRemote = getRemoteEvent(GameConfig.Network.RequestAttack)
	local clientReadyRemote = getRemoteEvent(GameConfig.Network.ClientReady)
	local combatUpdateRemote = getRemoteEvent(GameConfig.Network.CombatUpdate)

	-- Listen first, then announce readiness: the server's Sync reply can't arrive before we're listening.
	combatUpdateRemote.OnClientEvent:Connect(onCombatUpdate)
	connectInput(requestAttackRemote)
	clientReadyRemote:FireServer()

	-- Safety net: if no sync arrived (e.g. the server was still starting), ask again a few times.
	task.spawn(function()
		for attempt = 1, SYNC_RETRY_ATTEMPTS do
			task.wait(SYNC_RETRY_INTERVAL)
			if currentSnapshot ~= nil then
				return
			end
			warn(`[CombatClient] No combat sync yet; re-sending ClientReady (attempt {attempt}/{SYNC_RETRY_ATTEMPTS})`)
			clientReadyRemote:FireServer()
		end
		if currentSnapshot == nil then
			warn("[CombatClient] Combat state never arrived. Check the server Output for CombatService errors.")
		end
	end)
end

start()
