--!strict
--[[
	UpgradePanel
	Location: StarterPlayer > StarterPlayerScripts > CombatClient > UpgradePanel (ModuleScript)

	Placeholder Tap Damage upgrade panel: level, current tap damage, damage
	after upgrading, next cost and a purchase button. It only shows server data
	and reports button presses; the server decides prices, damage and whether a
	purchase succeeds. Affordability shown here is a hint from the last balance
	the server sent; the server checks again.

	The panel and its button are Active GUI, so presses on them are marked as
	processed and never count as attacks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))

type BigNum = BigNum.BigNum

-- Decoded UpgradeView, built by CombatClient.
export type UpgradeViewModel = {
	upgradeId: string,
	level: number,
	maxLevel: number,
	currencyId: string,
	currentValue: BigNum,
	nextValue: BigNum?,
	nextCost: BigNum?,
}

type PanelElements = {
	screenGui: ScreenGui,
	panel: Frame,
	panelScale: UIScale,
	levelLabel: TextLabel,
	damageLabel: TextLabel,
	nextLabel: TextLabel,
	button: TextButton,
	statusLabel: TextLabel,
}

local SCREEN_GUI_NAME = "UpgradePanel"
local FONT = Enum.Font.FredokaOne
local CLICK_INTERVAL = 0.15 -- seconds between requests; keeps a held-down mash under the server's rate limit

local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local MUTED_TEXT_COLOR = Color3.fromRGB(200, 204, 214)
local STROKE_COLOR = Color3.fromRGB(20, 20, 28)
local PANEL_COLOR = Color3.fromRGB(24, 26, 36)
local BUTTON_READY_COLOR = Color3.fromRGB(70, 170, 90)
local BUTTON_LOCKED_COLOR = Color3.fromRGB(80, 84, 96)
local SUCCESS_COLOR = Color3.fromRGB(140, 235, 140)
local ERROR_COLOR = Color3.fromRGB(255, 120, 120)

local POP_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local STATUS_FADE_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 1.2)

local UpgradePanel = {}

local elements: PanelElements? = nil
local currentView: UpgradeViewModel? = nil
local goldBalance: BigNum? = nil
local purchaseCallback: (() -> ())? = nil
local lastClickAt = -math.huge
local popTween: Tween? = nil
local statusTween: Tween? = nil

local function newLabel(name: string, parent: Instance, height: number, order: number, maxTextSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, height)
	label.LayoutOrder = order
	label.Font = FONT
	label.Text = ""
	label.TextColor3 = TEXT_COLOR
	label.TextScaled = true

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = 9
	sizeConstraint.MaxTextSize = maxTextSize
	sizeConstraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 1.2
	stroke.Parent = label

	label.Parent = parent
	return label
end

local function canPurchase(): boolean
	local view = currentView
	local gold = goldBalance
	if not view or not gold then
		return false
	end
	local cost = view.nextCost
	if cost == nil then
		return false -- max level
	end
	return BigNum.gte(gold, cost)
end

local function refreshButton()
	local ui = elements
	if not ui then
		return
	end
	local view = currentView
	if not view or not goldBalance then
		ui.button.Text = "Loading..."
		ui.button.BackgroundColor3 = BUTTON_LOCKED_COLOR
		return
	end
	local cost = view.nextCost
	if cost == nil then
		ui.button.Text = "Max level"
		ui.button.BackgroundColor3 = BUTTON_LOCKED_COLOR
		return
	end
	local costText = BigNum.format(cost)
	if canPurchase() then
		ui.button.Text = `Upgrade for {costText} Gold`
		ui.button.BackgroundColor3 = BUTTON_READY_COLOR
	else
		ui.button.Text = `Need {costText} Gold`
		ui.button.BackgroundColor3 = BUTTON_LOCKED_COLOR
	end
end

local function showStatus(text: string, color: Color3)
	local ui = elements
	if not ui then
		return
	end
	local previous = statusTween
	if previous then
		previous:Cancel()
	end
	ui.statusLabel.Text = text
	ui.statusLabel.TextColor3 = color
	ui.statusLabel.TextTransparency = 0
	local tween = TweenService:Create(ui.statusLabel, STATUS_FADE_INFO, { TextTransparency = 1 })
	statusTween = tween
	tween:Play()
end

local function pop()
	local ui = elements
	if not ui then
		return
	end
	local previous = popTween
	if previous then
		previous:Cancel()
	end
	ui.panelScale.Scale = 1.06
	local tween = TweenService:Create(ui.panelScale, POP_INFO, { Scale = 1 })
	popTween = tween
	tween:Play()
end

local function onButtonActivated()
	if not canPurchase() then
		return
	end
	local now = os.clock()
	if now - lastClickAt < CLICK_INTERVAL then
		return
	end
	lastClickAt = now
	local callback = purchaseCallback
	if callback then
		callback()
	end
end

-- Builds the panel. onPurchase is called once per accepted button press.
function UpgradePanel.Mount(playerGui: PlayerGui, onPurchase: () -> ())
	if elements then
		return
	end
	purchaseCallback = onPurchase

	local leftover = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if leftover then
		leftover:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screenGui.DisplayOrder = 2 -- above the combat HUD

	-- Right side, clear of the slime (center) and the HP panel (top center).
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.fromScale(0.985, 0.56)
	panel.Size = UDim2.fromScale(0.27, 0.4)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Active = true -- presses on the panel itself never become attacks
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = panel

	local border = Instance.new("UIStroke")
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Color = STROKE_COLOR
	border.Thickness = 2
	border.Transparency = 0.3
	border.Parent = panel

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(340, 260)
	sizeConstraint.Parent = panel

	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.05, 0)
	padding.PaddingBottom = UDim.new(0.05, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.025, 0)
	layout.Parent = panel

	local title = newLabel("Title", panel, 0.15, 1, 26)
	title.Text = "Tap Upgrade"

	local levelLabel = newLabel("Level", panel, 0.12, 2, 22)
	levelLabel.TextColor3 = MUTED_TEXT_COLOR

	local damageLabel = newLabel("Damage", panel, 0.12, 3, 22)
	local nextLabel = newLabel("Next", panel, 0.12, 4, 22)
	nextLabel.TextColor3 = MUTED_TEXT_COLOR

	local button = Instance.new("TextButton")
	button.Name = "UpgradeButton"
	button.Size = UDim2.fromScale(1, 0.26)
	button.LayoutOrder = 5
	button.AutoButtonColor = true
	button.BackgroundColor3 = BUTTON_LOCKED_COLOR
	button.BorderSizePixel = 0
	button.Font = FONT
	button.Text = "Loading..."
	button.TextColor3 = TEXT_COLOR
	button.TextScaled = true
	button.Parent = panel

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.25, 0)
	buttonCorner.Parent = button

	local buttonText = Instance.new("UITextSizeConstraint")
	buttonText.MinTextSize = 9
	buttonText.MaxTextSize = 24
	buttonText.Parent = button

	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingLeft = UDim.new(0.06, 0)
	buttonPadding.PaddingRight = UDim.new(0.06, 0)
	buttonPadding.PaddingTop = UDim.new(0.15, 0)
	buttonPadding.PaddingBottom = UDim.new(0.15, 0)
	buttonPadding.Parent = button

	local statusLabel = newLabel("Status", panel, 0.1, 6, 18)
	statusLabel.TextTransparency = 1

	-- Activated fires once per click or tap, for mouse and touch alike.
	button.Activated:Connect(onButtonActivated)

	screenGui.Parent = playerGui

	elements = {
		screenGui = screenGui,
		panel = panel,
		panelScale = panelScale,
		levelLabel = levelLabel,
		damageLabel = damageLabel,
		nextLabel = nextLabel,
		button = button,
		statusLabel = statusLabel,
	}

	levelLabel.Text = "Level -"
	damageLabel.Text = "Tap Damage: -"
	nextLabel.Text = "Next: -"
	refreshButton()
end

-- Shows the server's view of the upgrade.
function UpgradePanel.Render(view: UpgradeViewModel)
	local ui = elements
	if not ui then
		return
	end
	currentView = view
	ui.levelLabel.Text = `Level {view.level}`
	ui.damageLabel.Text = `Tap Damage: {BigNum.format(view.currentValue)}`
	local nextValue = view.nextValue
	ui.nextLabel.Text = if nextValue then `Next: {BigNum.format(nextValue)} damage` else "Next: max level reached"
	refreshButton()
end

-- Updates affordability from the latest server balance.
function UpgradePanel.SetBalance(gold: BigNum)
	goldBalance = gold
	refreshButton()
end

-- True if a screen position (InputObject.Position space) is over the panel. Taps there are never attacks.
function UpgradePanel.ContainsPoint(screenPosition: Vector2): boolean
	local ui = elements
	if not ui or not ui.screenGui.Enabled then
		return false
	end
	local topLeft = ui.panel.AbsolutePosition
	local bottomRight = topLeft + ui.panel.AbsoluteSize
	return screenPosition.X >= topLeft.X
		and screenPosition.X <= bottomRight.X
		and screenPosition.Y >= topLeft.Y
		and screenPosition.Y <= bottomRight.Y
end

-- Feedback for a purchase reply from the server.
function UpgradePanel.ShowResult(success: boolean, reason: string)
	if success then
		pop()
		showStatus("Upgraded!", SUCCESS_COLOR)
	elseif reason == "InsufficientFunds" then
		showStatus("Not enough Gold", ERROR_COLOR)
	elseif reason == "MaxLevel" then
		showStatus("Max level reached", ERROR_COLOR)
	else
		showStatus("Purchase failed", ERROR_COLOR)
	end
end

return UpgradePanel
