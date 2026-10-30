--!strict
--[[
	CombatHud
	Location: StarterPlayer > StarterPlayerScripts > CombatClient > CombatHud (ModuleScript)

	Builds and updates the placeholder combat interface:
	  Top:    Stage, Gold
	  Center: Enemy name, HP bar, "HP / Max HP", and the large tap area
	  Bottom: Tap Damage

	It only renders what it is given; it never decides combat outcomes.
	Sizes use Scale + constraints so the same layout works on phones and desktops.
	Milestone 2: numbers arrive as BigNums and are formatted with BigNum.format;
	Gold is set separately from combat updates (it comes from CurrencyUpdate).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))

type BigNum = BigNum.BigNum

-- Decoded combat state, built by CombatClient from a CombatSnapshot.
export type CombatView = {
	stage: number,
	tapDamage: BigNum,
	enemyId: number,
	enemyName: string,
	enemyHp: BigNum,
	enemyMaxHp: BigNum,
}

type HudElements = {
	screenGui: ScreenGui,
	tapArea: Frame,
	stageLabel: TextLabel,
	goldPill: Frame,
	goldLabel: TextLabel,
	goldScale: UIScale,
	enemyNameLabel: TextLabel,
	healthFill: Frame,
	healthText: TextLabel,
	tapDamageLabel: TextLabel,
}

local SCREEN_GUI_NAME = "CombatHud"
local FONT = Enum.Font.FredokaOne

local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR = Color3.fromRGB(20, 20, 28)
local PANEL_COLOR = Color3.fromRGB(24, 26, 36)
local GOLD_COLOR = Color3.fromRGB(255, 214, 90)
local DAMAGE_COLOR = Color3.fromRGB(255, 245, 235)
local HEALTH_BACK_COLOR = Color3.fromRGB(45, 18, 22)
local HEALTH_FILL_COLOR = Color3.fromRGB(226, 64, 64)

local HEALTH_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RIPPLE_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POPUP_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GOLD_POP_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local RIPPLE_SIZE = 0.14 -- fraction of the tap area (kept circular by an aspect constraint)

local CombatHud = {}

local elements: HudElements? = nil
local healthTween: Tween? = nil
local goldPopTween: Tween? = nil
local random = Random.new()

local function addCorner(guiObject: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = guiObject
end

local function addBorderStroke(guiObject: GuiObject, thickness: number, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = STROKE_COLOR
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = guiObject
	return stroke
end

local function newFrame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false -- never sink input, so taps pass through to the combat area
	frame.Parent = parent
	return frame
end

local function newLabel(name: string, parent: Instance, maxTextSize: number): (TextLabel, UIStroke)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.Text = ""
	label.TextColor3 = TEXT_COLOR
	label.TextScaled = true
	label.Active = false

	local sizeConstraint = Instance.new("UITextSizeConstraint")
	sizeConstraint.MinTextSize = 10
	sizeConstraint.MaxTextSize = maxTextSize
	sizeConstraint.Parent = label

	local stroke = Instance.new("UIStroke") -- Contextual mode outlines the text
	stroke.Color = STROKE_COLOR
	stroke.Thickness = 1.5
	stroke.Parent = label

	label.Parent = parent
	return label, stroke
end

-- Rounded dark "pill" with a label inside. Returns the pill, its label and a UIScale for pop effects.
local function newPill(name: string, parent: Instance, size: UDim2, maxSize: Vector2): (Frame, TextLabel, UIScale)
	local pill = newFrame(name, parent)
	pill.Size = size
	pill.BackgroundColor3 = PANEL_COLOR
	pill.BackgroundTransparency = 0.25
	addCorner(pill, UDim.new(0.3, 0))
	addBorderStroke(pill, 2, 0.3)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = maxSize
	sizeConstraint.Parent = pill

	local scale = Instance.new("UIScale")
	scale.Parent = pill

	local label = newLabel("Label", pill, 32)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.86, 0.72)

	return pill, label, scale
end

local function getElements(): HudElements?
	local ui = elements
	if not ui then
		warn("[CombatHud] Used before Mount")
	end
	return ui
end

-- Floats a label from its current Position by `offset`, fading it out, then destroys it.
local function floatAndFade(label: TextLabel, stroke: UIStroke, offset: UDim2)
	TweenService:Create(label, POPUP_INFO, {
		Position = label.Position + offset,
		TextTransparency = 1,
	}):Play()
	local strokeTween = TweenService:Create(stroke, POPUP_INFO, { Transparency = 1 })
	strokeTween.Completed:Once(function()
		label:Destroy()
	end)
	strokeTween:Play()
end

function CombatHud.Mount(playerGui: PlayerGui)
	if elements then
		return
	end

	local leftover = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if leftover then
		leftover:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = SCREEN_GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- stays clear of Roblox buttons and notches
	screenGui.DisplayOrder = 1

	-- Large combat tap area. It is a plain, non-Active Frame: it marks WHERE taps
	-- count. Real buttons placed above it (Active = true) mark input as processed,
	-- which CombatClient ignores, so UI controls never trigger attacks.
	local tapArea = newFrame("TapArea", screenGui)
	tapArea.Position = UDim2.fromScale(0, 0.12)
	tapArea.Size = UDim2.fromScale(1, 0.74)
	tapArea.ZIndex = 1

	local tapHint = newLabel("TapHint", tapArea, 22)
	tapHint.AnchorPoint = Vector2.new(0.5, 1)
	tapHint.Position = UDim2.fromScale(0.5, 0.99)
	tapHint.Size = UDim2.fromScale(0.5, 0.06)
	tapHint.Text = "Tap or click to attack"
	tapHint.TextTransparency = 0.4

	-- Top: Stage and Gold
	local topBar = newFrame("TopBar", screenGui)
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.fromScale(0.5, 0.015)
	topBar.Size = UDim2.fromScale(0.92, 0.085)
	topBar.ZIndex = 2

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Padding = UDim.new(0.03, 0)
	topLayout.Parent = topBar

	local stagePill, stageLabel = newPill("StagePill", topBar, UDim2.fromScale(0.36, 1), Vector2.new(280, 64))
	stagePill.LayoutOrder = 1

	local goldPill, goldLabel, goldScale = newPill("GoldPill", topBar, UDim2.fromScale(0.36, 1), Vector2.new(280, 64))
	goldPill.LayoutOrder = 2
	goldLabel.TextColor3 = GOLD_COLOR

	-- Above the enemy: name, HP bar, HP text
	local enemyPanel = newFrame("EnemyPanel", screenGui)
	enemyPanel.AnchorPoint = Vector2.new(0.5, 0)
	enemyPanel.Position = UDim2.fromScale(0.5, 0.13)
	enemyPanel.Size = UDim2.fromScale(0.55, 0.12)
	enemyPanel.ZIndex = 2

	local panelConstraint = Instance.new("UISizeConstraint")
	panelConstraint.MaxSize = Vector2.new(520, 110)
	panelConstraint.Parent = enemyPanel

	local enemyNameLabel = newLabel("EnemyName", enemyPanel, 34)
	enemyNameLabel.Size = UDim2.fromScale(1, 0.45)

	local healthBar = newFrame("HealthBar", enemyPanel)
	healthBar.Position = UDim2.fromScale(0, 0.52)
	healthBar.Size = UDim2.fromScale(1, 0.48)
	healthBar.BackgroundColor3 = HEALTH_BACK_COLOR
	healthBar.BackgroundTransparency = 0
	addCorner(healthBar, UDim.new(0.3, 0))
	addBorderStroke(healthBar, 2, 0)

	local healthFill = newFrame("Fill", healthBar)
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = HEALTH_FILL_COLOR
	healthFill.BackgroundTransparency = 0
	healthFill.ZIndex = 1
	addCorner(healthFill, UDim.new(0.3, 0))

	local healthText = newLabel("HealthText", healthBar, 26)
	healthText.ZIndex = 2

	-- Bottom: Tap Damage
	local tapDamagePill, tapDamageLabel = newPill("TapDamagePill", screenGui, UDim2.fromScale(0.42, 0.085), Vector2.new(320, 64))
	tapDamagePill.AnchorPoint = Vector2.new(0.5, 1)
	tapDamagePill.Position = UDim2.fromScale(0.5, 0.985)
	tapDamagePill.ZIndex = 2

	-- Placeholder text until the first server sync arrives
	stageLabel.Text = "Stage -"
	goldLabel.Text = "Gold: -"
	enemyNameLabel.Text = "Connecting..."
	healthText.Text = "- / -"
	tapDamageLabel.Text = "Tap Damage: -"

	screenGui.Parent = playerGui

	elements = {
		screenGui = screenGui,
		tapArea = tapArea,
		stageLabel = stageLabel,
		goldPill = goldPill,
		goldLabel = goldLabel,
		goldScale = goldScale,
		enemyNameLabel = enemyNameLabel,
		healthFill = healthFill,
		healthText = healthText,
		tapDamageLabel = tapDamageLabel,
	}
end

-- Shows the authoritative combat state. instantHealthBar skips the bar tween (used when a new enemy appears).
function CombatHud.Render(view: CombatView, instantHealthBar: boolean)
	local ui = getElements()
	if not ui then
		return
	end

	ui.stageLabel.Text = `Stage {view.stage}`
	ui.enemyNameLabel.Text = view.enemyName
	ui.healthText.Text = `{BigNum.format(view.enemyHp)} / {BigNum.format(view.enemyMaxHp)}`
	ui.tapDamageLabel.Text = `Tap Damage: {BigNum.format(view.tapDamage)}`

	local ratio = 0
	if not BigNum.isZero(view.enemyMaxHp) then
		ratio = math.clamp(BigNum.ratio(view.enemyHp, view.enemyMaxHp), 0, 1)
	end
	local targetSize = UDim2.fromScale(ratio, 1)

	local previousTween = healthTween
	if previousTween then
		previousTween:Cancel()
		healthTween = nil
	end

	if instantHealthBar then
		ui.healthFill.Size = targetSize
	else
		local tween = TweenService:Create(ui.healthFill, HEALTH_TWEEN_INFO, { Size = targetSize })
		healthTween = tween
		tween:Play()
	end
end

-- Shows the authoritative Gold balance (from CurrencyUpdate).
function CombatHud.SetGold(gold: BigNum)
	local ui = getElements()
	if not ui then
		return
	end
	ui.goldLabel.Text = `Gold: {BigNum.format(gold)}`
end

-- True if a screen position (InputObject.Position space) is inside the combat tap area.
function CombatHud.IsInTapArea(screenPosition: Vector2): boolean
	local ui = elements
	if not ui or not ui.screenGui.Enabled then
		return false
	end
	local topLeft = ui.tapArea.AbsolutePosition
	local bottomRight = topLeft + ui.tapArea.AbsoluteSize
	return screenPosition.X >= topLeft.X
		and screenPosition.X <= bottomRight.X
		and screenPosition.Y >= topLeft.Y
		and screenPosition.Y <= bottomRight.Y
end

-- Instant local feedback where the player tapped (shown before the server replies).
function CombatHud.PlayTapRipple(screenPosition: Vector2)
	local ui = getElements()
	if not ui then
		return
	end

	local localPosition = screenPosition - ui.tapArea.AbsolutePosition

	local ripple = newFrame("TapRipple", ui.tapArea)
	ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	ripple.Position = UDim2.fromOffset(localPosition.X, localPosition.Y)
	ripple.Size = UDim2.fromScale(0, 0)
	ripple.BackgroundColor3 = TEXT_COLOR
	ripple.BackgroundTransparency = 0.6
	ripple.ZIndex = 2
	addCorner(ripple, UDim.new(0.5, 0))

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = ripple

	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = TEXT_COLOR
	ring.Thickness = 2
	ring.Transparency = 0.2
	ring.Parent = ripple

	TweenService:Create(ripple, RIPPLE_INFO, {
		Size = UDim2.fromScale(RIPPLE_SIZE, RIPPLE_SIZE),
		BackgroundTransparency = 1,
	}):Play()
	local ringTween = TweenService:Create(ring, RIPPLE_INFO, { Transparency = 1 })
	ringTween.Completed:Once(function()
		ripple:Destroy()
	end)
	ringTween:Play()
end

-- Floating damage number near the enemy for a server-confirmed hit.
function CombatHud.ShowDamage(amount: BigNum)
	local ui = getElements()
	if not ui then
		return
	end

	local label, stroke = newLabel("DamagePopup", ui.tapArea, 44)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5 + random:NextNumber(-0.07, 0.07), 0.42 + random:NextNumber(-0.05, 0.05))
	label.Size = UDim2.fromScale(0.16, 0.09)
	label.Text = `-{BigNum.format(amount)}`
	label.TextColor3 = DAMAGE_COLOR
	label.ZIndex = 3

	floatAndFade(label, stroke, UDim2.fromScale(0, -0.1))
end

-- "+X Gold" popup under the gold counter plus a small pop of the counter.
function CombatHud.ShowGoldGain(amount: BigNum)
	local ui = getElements()
	if not ui then
		return
	end

	local previousPop = goldPopTween
	if previousPop then
		previousPop:Cancel()
	end
	ui.goldScale.Scale = 1.15
	local popTween = TweenService:Create(ui.goldScale, GOLD_POP_INFO, { Scale = 1 })
	goldPopTween = popTween
	popTween:Play()

	local label, stroke = newLabel("GoldPopup", ui.goldPill, 30)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 1.1)
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Text = `+{BigNum.format(amount)} Gold`
	label.TextColor3 = GOLD_COLOR
	label.ZIndex = 3

	floatAndFade(label, stroke, UDim2.fromScale(0, 0.5))
end

return CombatHud
