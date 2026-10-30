--!strict
--[[
	ArenaView
	Location: StarterPlayer > StarterPlayerScripts > CombatClient > ArenaView (ModuleScript)

	Everything 3D that only this client sees:
	  - the fixed Scriptable camera
	  - the arena backdrop and lighting
	  - the local placeholder Forest Slime and its hit / defeat / spawn animations

	It holds no game state. CombatClient tells it which enemy (by enemyId)
	should be on screen and when a confirmed hit happened.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Layout (world space). The arena floats above the origin so it never
-- clashes with the template Baseplate if that was left in the place.
local ARENA_ORIGIN = Vector3.new(0, 50, 0)
local ENEMY_POSITION = ARENA_ORIGIN + Vector3.new(0, 0.6, 0) -- top of the stone platform
local CAMERA_POSITION = ARENA_ORIGIN + Vector3.new(0, 6, 18)
local CAMERA_FOCUS = ARENA_ORIGIN + Vector3.new(0, 4, 0)
local CAMERA_FIELD_OF_VIEW = 50

local STAGE_FOLDER_NAME = "CombatStage"

-- Placeholder palette
local SLIME_BODY_COLOR = Color3.fromRGB(112, 206, 92)
local SLIME_BASE_COLOR = Color3.fromRGB(82, 170, 70)
local SLIME_EYE_COLOR = Color3.fromRGB(25, 28, 36)
local SLIME_MOUTH_COLOR = Color3.fromRGB(38, 70, 34)
local WHITE = Color3.fromRGB(255, 255, 255)
local EMBER_COLOR = Color3.fromRGB(255, 150, 70)

-- Animation
local MIN_SCALE = 0.05
local HIT_SQUASH_SCALE = 0.86
local HIT_FLASH_TRANSPARENCY = 0.35
local IDLE_BOB_HEIGHT = 0.2
local DEFEAT_PARTICLE_COUNT = 24

local HIT_PULSE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HIT_FLASH_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPAWN_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.12)
local DEFEAT_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local IDLE_BOB_INFO = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

type PartSpec = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	transparency: number?,
	castShadow: boolean?,
}

type EnemyVisual = {
	id: number,
	model: Model,
	parts: { BasePart },
	highlight: Highlight,
	basePivot: CFrame,
	baseScale: NumberValue, -- spawn / defeat size
	pulseScale: NumberValue, -- short squash on hit
	bobOffset: NumberValue, -- idle up/down motion
	idleTween: Tween?,
	pulseTween: Tween?,
	flashTween: Tween?,
	spawnTween: Tween?,
}

local ArenaView = {}

local mounted = false
local stageFolder: Folder? = nil
local burstEmitter: ParticleEmitter? = nil
local currentEnemy: EnemyVisual? = nil
local cameraConnections: { RBXScriptConnection } = {}

local function newPart(spec: PartSpec, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	part.Shape = spec.shape or Enum.PartType.Block
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Color = spec.color
	part.Material = spec.material
	part.Transparency = spec.transparency or 0
	part.CastShadow = spec.castShadow == true
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Cylinders point along X by default; this stands them upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function buildTree(parent: Instance, groundPosition: Vector3, height: number)
	newPart({
		name = "TreeTrunk",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, 2.2, 2.2),
		cframe = CFrame.new(groundPosition + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		color = Color3.fromRGB(58, 42, 32),
		material = Enum.Material.Wood,
	}, parent)
	newPart({
		name = "TreeCanopy",
		shape = Enum.PartType.Ball,
		size = Vector3.new(10, 10, 10),
		cframe = CFrame.new(groundPosition + Vector3.new(0, height + 3, 0)),
		color = Color3.fromRGB(34, 66, 40),
		material = Enum.Material.Grass,
	}, parent)
end

local function buildBrazier(parent: Instance, groundPosition: Vector3)
	local pillarHeight = 10
	newPart({
		name = "Pillar",
		size = Vector3.new(2.5, pillarHeight, 2.5),
		cframe = CFrame.new(groundPosition + Vector3.new(0, pillarHeight / 2, 0)),
		color = Color3.fromRGB(88, 84, 78),
		material = Enum.Material.Cobblestone,
		castShadow = true,
	}, parent)

	local bowl = newPart({
		name = "Brazier",
		size = Vector3.new(2.8, 0.8, 2.8),
		cframe = CFrame.new(groundPosition + Vector3.new(0, pillarHeight + 0.4, 0)),
		color = Color3.fromRGB(60, 50, 45),
		material = Enum.Material.Metal,
	}, parent)

	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Color = EMBER_COLOR
	fire.SecondaryColor = Color3.fromRGB(255, 80, 30)
	fire.Parent = bowl

	local light = Instance.new("PointLight")
	light.Color = EMBER_COLOR
	light.Brightness = 2
	light.Range = 24
	light.Parent = bowl
end

local function buildArena(parent: Instance)
	local arena = Instance.new("Folder")
	arena.Name = "Arena"

	newPart({
		name = "Floor",
		size = Vector3.new(100, 1, 70),
		cframe = CFrame.new(ARENA_ORIGIN + Vector3.new(0, -0.5, -6)),
		color = Color3.fromRGB(62, 84, 56),
		material = Enum.Material.Grass,
	}, arena)

	newPart({
		name = "Backdrop",
		size = Vector3.new(180, 80, 2),
		cframe = CFrame.new(ARENA_ORIGIN + Vector3.new(0, 38, -24)),
		color = Color3.fromRGB(34, 46, 52),
		material = Enum.Material.Slate,
	}, arena)

	newPart({
		name = "Platform",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.6, 12, 12),
		cframe = CFrame.new(ARENA_ORIGIN + Vector3.new(0, 0.3, 0)) * UPRIGHT,
		color = Color3.fromRGB(96, 92, 84),
		material = Enum.Material.Slate,
	}, arena)

	for _, x in { -30, -15, 16, 31 } do
		buildTree(arena, ARENA_ORIGIN + Vector3.new(x, 0, -19), 14)
	end

	buildBrazier(arena, ARENA_ORIGIN + Vector3.new(-13, 0, -6))
	buildBrazier(arena, ARENA_ORIGIN + Vector3.new(13, 0, -6))

	-- Key light aimed at the enemy from above the camera.
	local keyLightPosition = ARENA_ORIGIN + Vector3.new(0, 14, 12)
	local keyLightAnchor = newPart({
		name = "KeyLight",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.lookAt(keyLightPosition, ENEMY_POSITION + Vector3.new(0, 2.5, 0)),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
	}, arena)
	local keyLight = Instance.new("SpotLight")
	keyLight.Face = Enum.NormalId.Front
	keyLight.Angle = 55
	keyLight.Range = 45
	keyLight.Brightness = 2.5
	keyLight.Color = Color3.fromRGB(255, 240, 220)
	keyLight.Parent = keyLightAnchor

	-- Invisible emitter used for the defeat burst.
	local burstAnchor = newPart({
		name = "BurstAnchor",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(ENEMY_POSITION + Vector3.new(0, 2.4, 0)),
		color = WHITE,
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
	}, arena)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(SLIME_BODY_COLOR, Color3.fromRGB(210, 255, 170))
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.Drag = 2
	emitter.Parent = burstAnchor
	burstEmitter = emitter

	arena.Parent = parent
end

local function buildSlimeModel(basePivot: CFrame): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "Enemy"
	local parts: { BasePart } = {}

	-- Offsets are relative to the pivot (ground point under the slime).
	-- The pivot faces the camera, so the slime's front is local -Z.
	local function addPart(spec: PartSpec)
		table.insert(parts, newPart(spec, model))
	end

	addPart({
		name = "Puddle",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.35, 7.2, 7.2),
		cframe = basePivot * CFrame.new(0, 0.175, 0) * UPRIGHT,
		color = SLIME_BASE_COLOR,
		material = Enum.Material.SmoothPlastic,
		transparency = 0.15,
	})
	addPart({
		name = "Body",
		shape = Enum.PartType.Ball,
		size = Vector3.new(6, 6, 6),
		cframe = basePivot * CFrame.new(0, 2.2, 0),
		color = SLIME_BODY_COLOR,
		material = Enum.Material.SmoothPlastic,
		transparency = 0.08,
		castShadow = true,
	})
	for _, side in { -1, 1 } do
		addPart({
			name = "Eye",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1, 1, 1),
			cframe = basePivot * CFrame.new(side * 1.0, 3.0, -2.55),
			color = SLIME_EYE_COLOR,
			material = Enum.Material.SmoothPlastic,
		})
		addPart({
			name = "EyeShine",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.32, 0.32, 0.32),
			cframe = basePivot * CFrame.new(side * 1.0 + 0.15, 3.18, -2.98),
			color = WHITE,
			material = Enum.Material.SmoothPlastic,
		})
	end
	addPart({
		name = "Mouth",
		size = Vector3.new(0.8, 0.16, 0.2),
		cframe = basePivot * CFrame.new(0, 2.1, -2.95),
		color = SLIME_MOUTH_COLOR,
		material = Enum.Material.SmoothPlastic,
	})
	addPart({
		name = "Stem",
		size = Vector3.new(0.25, 0.7, 0.25),
		cframe = basePivot * CFrame.new(0, 5.45, 0),
		color = Color3.fromRGB(110, 78, 45),
		material = Enum.Material.Wood,
	})
	addPart({
		name = "Leaf",
		size = Vector3.new(1.5, 0.12, 0.7),
		cframe = basePivot * CFrame.new(0.6, 5.85, 0) * CFrame.Angles(0, 0, math.rad(20)),
		color = Color3.fromRGB(60, 150, 60),
		material = Enum.Material.SmoothPlastic,
	})

	-- Scaling and moving the model both happen around this ground point.
	model.WorldPivot = basePivot
	return model, parts
end

local function cancelTween(tween: Tween?)
	if tween then
		tween:Cancel()
	end
end

local function cancelAllTweens(visual: EnemyVisual)
	cancelTween(visual.idleTween)
	cancelTween(visual.pulseTween)
	cancelTween(visual.flashTween)
	cancelTween(visual.spawnTween)
	visual.idleTween = nil
	visual.pulseTween = nil
	visual.flashTween = nil
	visual.spawnTween = nil
end

local function applyScale(visual: EnemyVisual)
	local scale = math.max(visual.baseScale.Value * visual.pulseScale.Value, MIN_SCALE)
	visual.model:ScaleTo(scale)
end

local function applyBob(visual: EnemyVisual)
	visual.model:PivotTo(visual.basePivot + Vector3.new(0, visual.bobOffset.Value, 0))
end

local function newNumberValue(name: string, value: number, parent: Instance): NumberValue
	local numberValue = Instance.new("NumberValue")
	numberValue.Name = name
	numberValue.Value = value
	numberValue.Parent = parent
	return numberValue
end

local function createEnemyVisual(parent: Instance, enemyId: number): EnemyVisual
	local lookTarget = Vector3.new(CAMERA_POSITION.X, ENEMY_POSITION.Y, CAMERA_POSITION.Z)
	local basePivot = CFrame.lookAt(ENEMY_POSITION, lookTarget)
	local model, parts = buildSlimeModel(basePivot)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = WHITE
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local visual: EnemyVisual = {
		id = enemyId,
		model = model,
		parts = parts,
		highlight = highlight,
		basePivot = basePivot,
		baseScale = newNumberValue("BaseScale", 1, model),
		pulseScale = newNumberValue("PulseScale", 1, model),
		bobOffset = newNumberValue("BobOffset", 0, model),
		idleTween = nil,
		pulseTween = nil,
		flashTween = nil,
		spawnTween = nil,
	}

	-- These connections are cleaned up automatically when the model is destroyed.
	visual.baseScale.Changed:Connect(function()
		applyScale(visual)
	end)
	visual.pulseScale.Changed:Connect(function()
		applyScale(visual)
	end)
	visual.bobOffset.Changed:Connect(function()
		applyBob(visual)
	end)

	model.Parent = parent
	return visual
end

local function retireEnemy(visual: EnemyVisual, animate: boolean)
	cancelAllTweens(visual)

	if not animate then
		visual.model:Destroy()
		return
	end

	local emitter = burstEmitter
	if emitter then
		emitter:Emit(DEFEAT_PARTICLE_COUNT)
	end

	visual.highlight.FillTransparency = HIT_FLASH_TRANSPARENCY
	TweenService:Create(visual.highlight, DEFEAT_INFO, { FillTransparency = 1 }):Play()
	for _, part in visual.parts do
		TweenService:Create(part, DEFEAT_INFO, { Transparency = 1 }):Play()
	end

	local shrinkTween = TweenService:Create(visual.baseScale, DEFEAT_INFO, { Value = MIN_SCALE })
	shrinkTween.Completed:Once(function()
		visual.model:Destroy()
	end)
	shrinkTween:Play()
end

local function applyCamera(camera: Camera)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = CAMERA_FIELD_OF_VIEW
	camera.CFrame = CFrame.lookAt(CAMERA_POSITION, CAMERA_FOCUS)
	-- Scriptable cameras never update Focus on their own. The camera is stationary,
	-- so setting it here (on lock, camera swap or CameraType reset) is enough.
	camera.Focus = CFrame.new(CAMERA_FOCUS)
end

local function lockCamera(camera: Camera)
	applyCamera(camera)

	-- Safety net: if anything switches the camera away from Scriptable, put it back.
	table.insert(
		cameraConnections,
		camera:GetPropertyChangedSignal("CameraType"):Connect(function()
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				applyCamera(camera)
			end
		end)
	)
end

local function bindCamera()
	for _, connection in cameraConnections do
		connection:Disconnect()
	end
	table.clear(cameraConnections)

	local camera = Workspace.CurrentCamera
	if camera then
		lockCamera(camera)
	end
	-- If there is no camera yet, the CurrentCamera changed signal calls this again.
end

-- Builds the arena and locks the camera. Safe to call more than once.
function ArenaView.Mount()
	if mounted then
		return
	end
	mounted = true

	local leftover = Workspace:FindFirstChild(STAGE_FOLDER_NAME)
	if leftover then
		leftover:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = STAGE_FOLDER_NAME
	buildArena(folder)
	folder.Parent = Workspace
	stageFolder = folder

	bindCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
end

-- Makes sure the enemy with this id is on screen. Does nothing if it already is.
-- animate = true plays the defeat burst on the old enemy and a pop-in on the new one.
function ArenaView.ShowEnemy(enemyId: number, animate: boolean)
	local folder = stageFolder
	if not folder then
		warn("[ArenaView] ShowEnemy called before Mount")
		return
	end

	local previous = currentEnemy
	if previous and previous.id == enemyId then
		return
	end
	if previous then
		currentEnemy = nil
		retireEnemy(previous, animate)
	end

	local visual = createEnemyVisual(folder, enemyId)
	currentEnemy = visual

	if animate then
		visual.baseScale.Value = MIN_SCALE
		local spawnTween = TweenService:Create(visual.baseScale, SPAWN_INFO, { Value = 1 })
		visual.spawnTween = spawnTween
		spawnTween:Play()
	end

	local idleTween = TweenService:Create(visual.bobOffset, IDLE_BOB_INFO, { Value = IDLE_BOB_HEIGHT })
	visual.idleTween = idleTween
	idleTween:Play()
end

-- Squash + white flash on a server-confirmed hit.
function ArenaView.PlayHit()
	local visual = currentEnemy
	if not visual then
		return
	end

	cancelTween(visual.pulseTween)
	visual.pulseScale.Value = HIT_SQUASH_SCALE
	local pulseTween = TweenService:Create(visual.pulseScale, HIT_PULSE_INFO, { Value = 1 })
	visual.pulseTween = pulseTween
	pulseTween:Play()

	cancelTween(visual.flashTween)
	visual.highlight.FillTransparency = HIT_FLASH_TRANSPARENCY
	local flashTween = TweenService:Create(visual.highlight, HIT_FLASH_INFO, { FillTransparency = 1 })
	visual.flashTween = flashTween
	flashTween:Play()
end

return ArenaView
