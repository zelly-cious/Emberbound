--!strict
--[[
	SlimePreview
	Location: ServerStorage > EmberDev > SlimePreview (ModuleScript)

	Studio-only preview and self-check for the ART-001 Standard Slime. Run it from
	the Command Bar in Edit mode (never during Play). Each Command Bar entry runs
	on its own, so every command includes the require:

		require(game.ServerStorage.EmberDev.SlimePreview).check()   -- automatic PASS/FAIL checks
		require(game.ServerStorage.EmberDev.SlimePreview).show()    -- one slime, gameplay camera
		require(game.ServerStorage.EmberDev.SlimePreview).lineup()  -- scales 0.5/1/1.75 + recolour test
		require(game.ServerStorage.EmberDev.SlimePreview).gameplayCamera()
		require(game.ServerStorage.EmberDev.SlimePreview).clear()   -- remove preview, restore camera
		require(game.ServerStorage.EmberDev.SlimePreview).help()

	Safety: ServerStorage never replicates to players and a ModuleScript never runs
	on its own, so this module does nothing in a live game. Nothing in the game
	requires it. The preview folder is not Archivable, so it is never saved into
	the place file. The stage numbers below copy ArenaView (Milestone 1, 730218a)
	so the preview matches the gameplay view; the gameplay scripts are not touched.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function findVisualsModule(name: string): ModuleScript
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local visuals = if shared then shared:FindFirstChild("Visuals") else nil
	local module = if visuals then visuals:FindFirstChild(name) else nil
	if module == nil or not module:IsA("ModuleScript") then
		error(`[SlimePreview] ReplicatedStorage.Shared.Visuals.{name} not found. Run the ART-001 installer first.`, 0)
	end
	return module :: ModuleScript
end

local SlimeModelFactory = require(findVisualsModule("SlimeModelFactory"))
local VisualPalette = require(findVisualsModule("VisualPalette"))

local PREFIX = "[SlimePreview]"
local COMMAND = "require(game.ServerStorage.EmberDev.SlimePreview)"
local FOLDER_NAME = "_EmberSlimePreview"

-- Far above the baseplate and above the play-mode arena (which sits at y = 50).
local PREVIEW_ORIGIN = Vector3.new(0, 300, 0)

-- Copied from ArenaView (Milestone 1) so the framing matches gameplay.
local ENEMY_OFFSET = Vector3.new(0, 0.6, 0) -- top of the stone platform
local CAMERA_OFFSET = Vector3.new(0, 6, 18)
local CAMERA_FOCUS_OFFSET = Vector3.new(0, 4, 0)
local CAMERA_FIELD_OF_VIEW = 50
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local LINEUP_CAMERA_OFFSET = Vector3.new(0, 8, 36)
local LINEUP_FOCUS_OFFSET = Vector3.new(0, 3, 0)

-- Reference phone for the readability estimate: a landscape screen 360 px tall.
local PHONE_VIEWPORT_HEIGHT = 360
local MIN_EYE_PIXELS = 14
local MIN_SMILE_PIXELS = 3

local EXPECTED_PARTS: { [string]: { string } } = {
	Ground = { "GroundShadow" },
	Body = { "Skirt", "Core", "Gloss", "Sparkle" },
	Face = {
		"EyeRight",
		"EyeShineRight",
		"EyeLeft",
		"EyeShineLeft",
		"MouthRight",
		"MouthLeft",
		"CheekRight",
		"CheekLeft",
	},
	Crown = { "SproutStem", "SproutLeaf" },
}
local GROUP_ORDER = { "Ground", "Body", "Face", "Crown" }
local ALLOWED_CLASSES: { [string]: boolean } = { Part = true, SpecialMesh = true, Folder = true, Attachment = true }

type SavedCamera = { cframe: CFrame, focus: CFrame, fieldOfView: number }
type LineupEntry = { label: string, scale: number, x: number, palette: { [string]: Color3 }? }
local savedCamera: SavedCamera? = nil

local SlimePreview = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function guardEditMode()
	if RunService:IsRunning() then
		error(`{PREFIX} Stop the playtest first: the preview runs in Edit mode only.`, 0)
	end
end

local function removePreviewFolder()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

local function newPreviewFolder(): Folder
	removePreviewFolder()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Archivable = false -- never saved into the place file
	folder.Parent = Workspace
	return folder
end

local function stagePart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Locked = true -- clicks select the slime, not the stage
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A copy of ArenaView's floor, backdrop, platform and lights (no fire effects).
local function buildStage(parent: Instance, origin: Vector3, includePlatform: boolean)
	local stage = Instance.new("Folder")
	stage.Name = "Stage"

	stagePart(
		stage,
		"Floor",
		Enum.PartType.Block,
		Vector3.new(100, 1, 70),
		CFrame.new(origin + Vector3.new(0, -0.5, -6)),
		Color3.fromRGB(62, 84, 56),
		Enum.Material.Grass
	)
	stagePart(
		stage,
		"Backdrop",
		Enum.PartType.Block,
		Vector3.new(180, 80, 2),
		CFrame.new(origin + Vector3.new(0, 38, -24)),
		Color3.fromRGB(34, 46, 52),
		Enum.Material.Slate
	)
	if includePlatform then
		stagePart(
			stage,
			"Platform",
			Enum.PartType.Cylinder,
			Vector3.new(0.6, 12, 12),
			CFrame.new(origin + Vector3.new(0, 0.3, 0)) * UPRIGHT,
			Color3.fromRGB(96, 92, 84),
			Enum.Material.Slate
		)
	end

	local keyLightPosition = origin + Vector3.new(0, 14, 12)
	local keyAnchor = stagePart(
		stage,
		"KeyLight",
		Enum.PartType.Block,
		Vector3.one,
		CFrame.lookAt(keyLightPosition, origin + ENEMY_OFFSET + Vector3.new(0, 2.5, 0)),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		1
	)
	local keyLight = Instance.new("SpotLight")
	keyLight.Face = Enum.NormalId.Front
	keyLight.Angle = 55
	keyLight.Range = 45
	keyLight.Brightness = 2.5
	keyLight.Color = Color3.fromRGB(255, 240, 220)
	keyLight.Parent = keyAnchor

	for _, x in { -13, 13 } do
		local emberAnchor = stagePart(
			stage,
			"EmberLight",
			Enum.PartType.Block,
			Vector3.one,
			CFrame.new(origin + Vector3.new(x, 10.8, -6)),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			1
		)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 70)
		light.Brightness = 2
		light.Range = 24
		light.Parent = emberAnchor
	end

	stage.Parent = parent
end

local function pointCamera(position: Vector3, focus: Vector3)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		warn(`{PREFIX} No camera found; move the view to the preview manually.`)
		return
	end
	if savedCamera == nil then
		savedCamera = { cframe = camera.CFrame, focus = camera.Focus, fieldOfView = camera.FieldOfView }
	end
	camera.FieldOfView = CAMERA_FIELD_OF_VIEW
	camera.CFrame = CFrame.lookAt(position, focus)
	camera.Focus = CFrame.new(focus)
end

local function facing(position: Vector3, cameraPosition: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(cameraPosition.X, position.Y, cameraPosition.Z))
end

local function close(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

local function vectorsClose(a: Vector3, b: Vector3, tolerance: number): boolean
	return (a - b).Magnitude <= tolerance
end

-- Part colours are stored with 8 bits per channel, so compare within one step.
local function colorsClose(a: Color3, b: Color3): boolean
	local step = 1.5 / 255
	return close(a.R, b.R, step) and close(a.G, b.G, step) and close(a.B, b.B, step)
end

-- Conservative vertical extent of a part, treating it as its bounding box.
local function verticalExtent(part: BasePart): (number, number)
	local frame = part.CFrame
	local half = part.Size / 2
	local reach = math.abs(frame.RightVector.Y) * half.X
		+ math.abs(frame.UpVector.Y) * half.Y
		+ math.abs(frame.LookVector.Y) * half.Z
	return frame.Position.Y - reach, frame.Position.Y + reach
end

local function partByPath(model: Model, group: string, name: string): BasePart?
	local folder = model:FindFirstChild(group)
	local part = if folder then folder:FindFirstChild(name) else nil
	if part ~= nil and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function requirePart(model: Model, group: string, name: string): BasePart
	local part = partByPath(model, group, name)
	if part == nil then
		error(`missing {group}.{name}`, 0)
	end
	return part
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

function SlimePreview.help()
	print(`{PREFIX} Commands (Edit mode, paste one line into the Command Bar):`)
	print(`  {COMMAND}.check()           automatic PASS/FAIL checks`)
	print(`  {COMMAND}.show()            one slime on the arena platform, gameplay camera`)
	print(`  {COMMAND}.lineup()          scales 0.5, 1, 1.75 and a recolour test`)
	print(`  {COMMAND}.gameplayCamera()  camera back to the gameplay view`)
	print(`  {COMMAND}.clear()           remove the preview and restore your camera`)
end

-- Moves the Studio camera to the gameplay framing of the preview platform.
function SlimePreview.gameplayCamera()
	pointCamera(PREVIEW_ORIGIN + CAMERA_OFFSET, PREVIEW_ORIGIN + CAMERA_FOCUS_OFFSET)
end

-- One slime on the platform, framed exactly like the game. options go to SlimeModelFactory.create.
function SlimePreview.show(options: { [string]: any }?): Model
	guardEditMode()
	local folder = newPreviewFolder()
	buildStage(folder, PREVIEW_ORIGIN, true)

	local slime = SlimeModelFactory.create(options)
	slime:PivotTo(facing(PREVIEW_ORIGIN + ENEMY_OFFSET, PREVIEW_ORIGIN + CAMERA_OFFSET))
	slime.Parent = folder

	SlimePreview.gameplayCamera()
	print(
		`{PREFIX} Showing {slime.Name} ({#SlimeModelFactory.getVisualParts(slime)} visible parts) from the gameplay camera. When done: {COMMAND}.clear()`
	)
	return slime
end

-- Four slimes side by side: scale 0.5, 1, 1.75 and a recolour test at scale 1.
function SlimePreview.lineup()
	guardEditMode()
	local folder = newPreviewFolder()
	buildStage(folder, PREVIEW_ORIGIN, false)
	local cameraPosition = PREVIEW_ORIGIN + LINEUP_CAMERA_OFFSET

	local recolour: { [string]: Color3 } = {
		Body = VisualPalette.MysticBlue,
		BodyShade = VisualPalette.shade(VisualPalette.MysticBlue, 0.8),
		BodyLight = VisualPalette.tint(VisualPalette.MysticBlue, 0.45),
		Stem = VisualPalette.shade(VisualPalette.MysticBlue, 0.65),
		Leaf = VisualPalette.shade(VisualPalette.MysticBlue, 0.85),
		Blush = VisualPalette.DeepViolet,
	}
	local entries: { LineupEntry } = {
		{ label = "scale 0.5", scale = 0.5, x = -15 },
		{ label = "scale 1", scale = 1, x = -8 },
		{ label = "scale 1.75", scale = 1.75, x = 3 },
		{ label = "scale 1, recoloured (Mystic Blue body, Deep Violet blush)", scale = 1, x = 15, palette = recolour },
	}
	for index, entry in entries do
		local slime = SlimeModelFactory.create({ scale = entry.scale, name = `Lineup{index}` })
		local palette = entry.palette
		if palette then
			SlimeModelFactory.applyPalette(slime, palette)
		end
		slime:PivotTo(facing(PREVIEW_ORIGIN + Vector3.new(entry.x, 0, 0), cameraPosition))
		slime.Parent = folder
	end

	pointCamera(cameraPosition, PREVIEW_ORIGIN + LINEUP_FOCUS_OFFSET)
	print(`{PREFIX} Lineup, left to right on screen:`)
	for index, entry in entries do
		print(`  {index}. {entry.label}`)
	end
	print(`{PREFIX} The recolour test only proves recolouring works; it is not a Frost variant.`)
	print(`{PREFIX} When done: {COMMAND}.clear()`)
end

-- Removes the preview and restores the camera you had before the preview moved it.
function SlimePreview.clear()
	removePreviewFolder()
	local camera = Workspace.CurrentCamera
	local saved = savedCamera
	if camera and saved then
		camera.FieldOfView = saved.fieldOfView
		camera.CFrame = saved.cframe
		camera.Focus = saved.focus
	end
	savedCamera = nil
	print(`{PREFIX} Preview removed.`)
end

--[[
	Builds test slimes in memory and checks the ART-001 acceptance rules. Prints
	one PASS or FAIL line per check and a summary. Returns true when all pass.
	Changes nothing in the place.
]]
function SlimePreview.check(): boolean
	guardEditMode()
	local passed, failed = 0, 0

	local function run(label: string, test: () -> string?)
		local ok, detail = pcall(test)
		if ok then
			passed += 1
			print(`{PREFIX} PASS  {label}` .. (if detail then ` ({detail})` else ""))
		else
			failed += 1
			warn(`{PREFIX} FAIL  {label}: {tostring(detail)}`)
		end
	end

	local function expect(condition: boolean, message: string)
		if not condition then
			error(message, 0)
		end
	end

	local slime = SlimeModelFactory.create()

	run("Factory offers exactly the Standard variant", function()
		local variants = SlimeModelFactory.listVariants()
		expect(#variants == 1 and variants[1] == "Standard", `variants are {table.concat(variants, ", ")}`)
		return nil
	end)

	run("Model name, Root pivot and PrimaryPart", function()
		expect(slime.Name == "Slime_Standard", `name is {slime.Name}`)
		local primary = slime.PrimaryPart
		expect(primary ~= nil and primary.Name == "Root", "PrimaryPart is not Root")
		expect(vectorsClose(slime:GetPivot().Position, Vector3.zero, 1e-6), "pivot is not at the origin")
		return nil
	end)

	run("Hierarchy matches the ART-001 contract", function()
		for _, group in GROUP_ORDER do
			local folder = slime:FindFirstChild(group)
			expect(folder ~= nil and folder:IsA("Folder"), `missing folder {group}`)
			local names: { string } = {}
			for _, child in (folder :: Instance):GetChildren() do
				table.insert(names, child.Name)
			end
			local expected = EXPECTED_PARTS[group]
			expect(
				table.concat(names, ",") == table.concat(expected, ","),
				`{group} holds {table.concat(names, ", ")}`
			)
		end
		return nil
	end)

	run("Part budget (10 to 18 visible parts)", function()
		local visible = #SlimeModelFactory.getVisualParts(slime)
		local total = 0
		for _, descendant in slime:GetDescendants() do
			if descendant:IsA("BasePart") then
				total += 1
			end
		end
		expect(visible >= 10 and visible <= 18, `{visible} visible parts`)
		expect(total == visible + 1, `{total} parts in total`)
		return `{visible} visible + invisible Root`
	end)

	run("No collisions, touches, queries or physics", function()
		for _, descendant in slime:GetDescendants() do
			if descendant:IsA("BasePart") then
				expect(descendant.Anchored, `{descendant.Name} is not anchored`)
				expect(not descendant.CanCollide, `{descendant.Name} can collide`)
				expect(not descendant.CanTouch, `{descendant.Name} can touch`)
				expect(not descendant.CanQuery, `{descendant.Name} can be queried`)
			end
		end
		return nil
	end)

	run("One shadow caster and one transparent part", function()
		local casters: { string }, transparent: { string } = {}, {}
		for _, part in SlimeModelFactory.getVisualParts(slime) do
			if part.CastShadow then
				table.insert(casters, part.Name)
			end
			if part.Transparency > 0 then
				table.insert(transparent, part.Name)
			end
		end
		expect(table.concat(casters, ",") == "Core", `shadow casters: {table.concat(casters, ", ")}`)
		expect(table.concat(transparent, ",") == "GroundShadow", `transparent: {table.concat(transparent, ", ")}`)
		local root = slime:FindFirstChild("Root")
		expect(root ~= nil and root:IsA("BasePart") and root.Transparency == 1, "Root is not invisible")
		return nil
	end)

	run("Only parts, built-in meshes, folders and attachments (no scripts or assets)", function()
		local count = 0
		for _, descendant in slime:GetDescendants() do
			count += 1
			expect(ALLOWED_CLASSES[descendant.ClassName] == true, `unexpected {descendant.ClassName} {descendant.Name}`)
			if descendant:IsA("SpecialMesh") then
				expect(descendant.MeshType == Enum.MeshType.Sphere, `{descendant.Parent} uses mesh type {descendant.MeshType}`)
				expect(descendant.MeshId == "", `{descendant.Parent} references a mesh asset`)
			end
		end
		expect(count <= 40, `{count} instances`)
		return `{count} instances`
	end)

	run("Attributes and colour roles", function()
		expect(slime:GetAttribute("EmberAsset") == "Slime", "EmberAsset missing")
		expect(slime:GetAttribute("EmberVariant") == "Standard", "EmberVariant missing")
		expect(slime:GetAttribute("EmberAssetVersion") == SlimeModelFactory.VERSION, "EmberAssetVersion missing")
		expect(slime:GetAttribute("EmberScale") == 1, "EmberScale missing")
		local roles: { [string]: boolean } = {}
		for _, role in SlimeModelFactory.ROLES do
			roles[role] = true
		end
		for _, part in SlimeModelFactory.getVisualParts(slime) do
			local role = part:GetAttribute("ColorRole")
			expect(typeof(role) == "string" and roles[role] == true, `{part.Name} has no valid ColorRole`)
		end
		return nil
	end)

	run("Anchor attachments on Root", function()
		local root = slime:FindFirstChild("Root") :: Instance
		for _, name in { "Center", "Top", "Face" } do
			local attachment = root:FindFirstChild(name)
			expect(attachment ~= nil and attachment:IsA("Attachment"), `missing attachment {name}`)
		end
		return nil
	end)

	run("Face looks forward, is symmetric and smiles", function()
		local eyeRight = requirePart(slime, "Face", "EyeRight")
		local eyeLeft = requirePart(slime, "Face", "EyeLeft")
		expect(eyeRight.Position.X > 0 and eyeLeft.Position.X < 0, "eyes are on the wrong sides")
		expect(close(eyeRight.Position.X, -eyeLeft.Position.X, 1e-4), "eyes are not mirrored")
		expect(close(eyeRight.Position.Y, eyeLeft.Position.Y, 1e-4), "eyes are at different heights")
		for _, eye in { eyeRight, eyeLeft } do
			expect(eye.Position.Z < 0 and eye.CFrame.LookVector.Z < -0.7, `{eye.Name} does not face the front`)
		end
		for _, name in { "MouthRight", "MouthLeft" } do
			local mouth = requirePart(slime, "Face", name)
			local endA = mouth.CFrame:PointToWorldSpace(Vector3.new(mouth.Size.X / 2, 0, 0))
			local endB = mouth.CFrame:PointToWorldSpace(Vector3.new(-mouth.Size.X / 2, 0, 0))
			local outer, inner = endA, endB
			if math.abs(endB.X) > math.abs(endA.X) then
				outer, inner = endB, endA
			end
			expect(outer.Y > inner.Y, `{name} does not curve up into a smile`)
		end
		local gloss = requirePart(slime, "Body", "Gloss")
		local shine = requirePart(slime, "Face", "EyeShineRight")
		expect(gloss.Position.X < 0, "gloss is not on the viewer's right")
		expect(shine.Position.X < eyeRight.Position.X, "eye shine is not on the viewer's right")
		return nil
	end)

	run("Stands on the floor and keeps the Milestone 1 height", function()
		local lowest, highest = math.huge, -math.huge
		local lowestName = ""
		for _, part in SlimeModelFactory.getVisualParts(slime) do
			local bottom, top = verticalExtent(part)
			if bottom < lowest then
				lowest, lowestName = bottom, part.Name
			end
			highest = math.max(highest, top)
		end
		expect(lowest >= -0.36, `{lowestName} reaches {string.format("%.2f", lowest)} below the floor`)
		expect(highest <= 6.5, `about {string.format("%.1f", highest)} studs tall`)
		return `lowest point {string.format("%.2f", lowest)} ({lowestName}), about {string.format(
			"%.1f",
			highest
		)} studs tall`
	end)

	run("Proportions stay identical at scale 0.5 and 2", function()
		local base: { [string]: BasePart } = {}
		for _, part in slime:GetDescendants() do
			if part:IsA("BasePart") then
				base[part:GetFullName()] = part
			end
		end
		for _, scale in { 0.5, 2 } do
			local scaled = SlimeModelFactory.create({ scale = scale })
			expect(scaled:GetAttribute("EmberScale") == scale, `EmberScale is not {scale}`)
			local count = 0
			for _, part in scaled:GetDescendants() do
				if part:IsA("BasePart") then
					count += 1
					local original = base[part:GetFullName()]
					expect(original ~= nil, `unexpected part {part.Name} at scale {scale}`)
					expect(vectorsClose(part.Size, original.Size * scale, 1e-4 * scale), `{part.Name} size at scale {scale}`)
					expect(
						vectorsClose(part.Position, original.Position * scale, 1e-4 * scale),
						`{part.Name} position at scale {scale}`
					)
					expect(
						vectorsClose(part.CFrame.LookVector, original.CFrame.LookVector, 1e-5)
							and vectorsClose(part.CFrame.UpVector, original.CFrame.UpVector, 1e-5),
						`{part.Name} rotation at scale {scale}`
					)
				elseif part:IsA("Attachment") then
					local parent = part.Parent :: Instance
					local original = (slime:FindFirstChild("Root") :: Instance):FindFirstChild(part.Name)
					expect(original ~= nil and original:IsA("Attachment") and parent.Name == "Root", `attachment {part.Name}`)
					expect(
						vectorsClose(part.Position, (original :: Attachment).Position * scale, 1e-4 * scale),
						`attachment {part.Name} at scale {scale}`
					)
				end
			end
			expect(count == #SlimeModelFactory.getVisualParts(slime) + 1, `part count changed at scale {scale}`)
			scaled:Destroy()
		end
		return nil
	end)

	run("Recolouring by role", function()
		local defaults = SlimeModelFactory.getPalette("Standard")
		local blue = SlimeModelFactory.create({ palette = { Body = VisualPalette.MysticBlue } })
		expect(colorsClose(requirePart(blue, "Body", "Core").Color, VisualPalette.MysticBlue), "Body override ignored")
		expect(colorsClose(requirePart(blue, "Body", "Skirt").Color, defaults.BodyShade), "other roles changed")
		SlimeModelFactory.applyPalette(blue, { Ink = VisualPalette.DeepViolet })
		for _, name in { "EyeRight", "EyeLeft", "MouthRight", "MouthLeft" } do
			expect(colorsClose(requirePart(blue, "Face", name).Color, VisualPalette.DeepViolet), `{name} not recoloured`)
		end
		expect(colorsClose(requirePart(blue, "Face", "CheekRight").Color, defaults.Blush), "cheeks changed")
		blue:Destroy()
		return nil
	end)

	run("Bad input is refused with a clear error", function()
		local cases: { { label: string, call: () -> (), text: string } } = {
			{
				label = "unknown variant",
				call = function()
					SlimeModelFactory.create({ variant = "Ember" })
				end,
				text = "unknown variant",
			},
			{
				label = "scale 0",
				call = function()
					SlimeModelFactory.create({ scale = 0 })
				end,
				text = "scale",
			},
			{
				label = "unknown colour role",
				call = function()
					SlimeModelFactory.create({ palette = { Glow = VisualPalette.EmberGold } })
				end,
				text = "unknown colour role",
			},
			{
				label = "recolouring a non-slime",
				call = function()
					SlimeModelFactory.applyPalette(Instance.new("Model"), {})
				end,
				text = "expected a slime Model",
			},
		}
		for _, case in cases do
			local ok, message = pcall(case.call)
			expect(not ok, `{case.label} was accepted`)
			expect(string.find(tostring(message), case.text, 1, true) ~= nil, `{case.label}: unclear error "{message}"`)
		end
		return nil
	end)

	run("Model:ScaleTo keeps built-in meshes in step (needed later for ArenaView's hit squash)", function()
		local holder = Instance.new("Folder")
		holder.Name = "_EmberSlimeCheck"
		holder.Archivable = false
		holder.Parent = Workspace
		local probe = SlimeModelFactory.create()
		probe:PivotTo(CFrame.new(PREVIEW_ORIGIN + Vector3.new(0, 0, -200)))
		probe.Parent = holder
		local core = requirePart(probe, "Body", "Core")
		local originalSize = core.Size
		local ok, problem = pcall(function()
			probe:ScaleTo(2)
			expect(vectorsClose(core.Size, originalSize * 2, 1e-3), "Core did not double in size")
			for _, descendant in probe:GetDescendants() do
				if descendant:IsA("SpecialMesh") then
					expect(
						vectorsClose(descendant.Scale, Vector3.one, 1e-4),
						`SpecialMesh.Scale became {descendant.Scale}, so ellipsoids would grow twice as much. Report this; the fallback is a plain-sphere body`
					)
				end
			end
			probe:ScaleTo(1)
			expect(vectorsClose(core.Size, originalSize, 1e-3), "ScaleTo(1) did not restore the size")
		end)
		holder:Destroy()
		expect(ok, tostring(problem))
		return nil
	end)

	run("Readable on a phone (estimate from part sizes; confirm in the device emulator)", function()
		-- The slime faces the camera, which sits 18 studs in front and 5.4 studs above the pivot.
		local cameraLocal = Vector3.new(0, CAMERA_OFFSET.Y - ENEMY_OFFSET.Y, -CAMERA_OFFSET.Z)
		local eye = requirePart(slime, "Face", "EyeRight")
		local mouth = requirePart(slime, "Face", "MouthRight")
		local function pixels(part: BasePart, studs: number): number
			local distance = (part.Position - cameraLocal).Magnitude
			local viewHeight = 2 * distance * math.tan(math.rad(CAMERA_FIELD_OF_VIEW / 2))
			return studs / viewHeight * PHONE_VIEWPORT_HEIGHT
		end
		local eyePixels = pixels(eye, eye.Size.Y)
		local smilePixels = pixels(mouth, mouth.Size.Y)
		expect(eyePixels >= MIN_EYE_PIXELS, `eyes only about {math.floor(eyePixels)} px tall`)
		expect(smilePixels >= MIN_SMILE_PIXELS, `smile only about {string.format("%.1f", smilePixels)} px thick`)
		return `eyes about {math.floor(eyePixels)} px, smile about {string.format("%.1f", smilePixels)} px on a {PHONE_VIEWPORT_HEIGHT} px tall screen`
	end)

	slime:Destroy()

	local total = passed + failed
	if failed == 0 then
		print(`{PREFIX} ALL {total} CHECKS PASSED`)
	else
		warn(`{PREFIX} {failed} OF {total} CHECKS FAILED (see the FAIL lines above)`)
	end
	return failed == 0
end

return table.freeze(SlimePreview)
