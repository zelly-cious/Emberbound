--[[
	Emberbound ART-001: Standard Slime V1 installer (Roblox Studio Command Bar)

	Creates ONLY these three ModuleScripts and the folders that hold them:
	  ReplicatedStorage > Shared > Visuals > VisualPalette
	  ReplicatedStorage > Shared > Visuals > SlimeModelFactory
	  ServerStorage > EmberDev > SlimePreview
	It changes nothing else: no gameplay scripts, RemoteEvents, settings or parts.
	If any of the three already exists it stops without changing anything, unless
	you set REPLACE_EXISTING_ART to true below (that replaces only these three).

	Run it in Edit mode (not during Play): open the Command Bar, paste this whole
	file, press Enter, then read the Output window.

	Generated from the repository files; do not edit the sources here.
]]

local REPLACE_EXISTING_ART = false

local ART_SOURCES = {}
ART_SOURCES["VisualPalette"] = [============[
--!strict
--[[
	VisualPalette
	Location: ReplicatedStorage > Shared > Visuals > VisualPalette (ModuleScript)

	Emberbound's official Stylized Fantasy RPG palette (ART-001) plus a few
	colour helpers. Every procedural asset takes its colours from here so the
	visual language stays consistent.

	Pure data and math: no services, no instances, no state. Safe to require
	from client scripts, server scripts and the Studio Command Bar.
]]

local WHITE = Color3.new(1, 1, 1)

local VisualPalette = {
	EmberOrange = Color3.fromHex("#FF8733"),
	EmberGold = Color3.fromHex("#FFC857"),
	ForestGreen = Color3.fromHex("#78C96B"),
	MysticBlue = Color3.fromHex("#5D9CEC"),
	DeepViolet = Color3.fromHex("#6C55A1"),
	ShadowNavy = Color3.fromHex("#26334A"),
	White = WHITE,
}

-- A darker version of color: every channel multiplied by factor (0 = black, 1 = unchanged).
function VisualPalette.shade(color: Color3, factor: number): Color3
	local f = math.clamp(factor, 0, 1)
	return Color3.new(color.R * f, color.G * f, color.B * f)
end

-- A lighter version of color: blended toward white by amount (0 = unchanged, 1 = white).
function VisualPalette.tint(color: Color3, amount: number): Color3
	return color:Lerp(WHITE, math.clamp(amount, 0, 1))
end

-- Blend of two colours: amount 0 gives a, 1 gives b.
function VisualPalette.mix(a: Color3, b: Color3, amount: number): Color3
	return a:Lerp(b, math.clamp(amount, 0, 1))
end

return table.freeze(VisualPalette)
]============]
ART_SOURCES["SlimeModelFactory"] = [============[
--!strict
--[[
	SlimeModelFactory
	Location: ReplicatedStorage > Shared > Visuals > SlimeModelFactory (ModuleScript)

	Builds Emberbound's procedural Slime enemy models (ART-001, Standard Slime V1)
	from Roblox-native parts. Visual asset generation only: no gameplay, combat,
	currency, networking, animation, services or scripts. Nothing in the game
	requires this module yet; ArenaView still builds its own Milestone 1 slime.

	Usage:
		local SlimeModelFactory = require(path.to.SlimeModelFactory)
		local slime = SlimeModelFactory.create()               -- Standard, scale 1
		local big = SlimeModelFactory.create({ scale = 2 })
		slime:PivotTo(CFrame.lookAt(groundPoint, pointToFace)) -- face looks along LookVector
		slime.Parent = workspace

	Model contract (version 1):
	  - Pivot: Root.CFrame, the ground point under the slime's centre. Models
	    are built at the origin; move them with PivotTo. Model:ScaleTo scales
	    around this point.
	  - Front: local -Z, so the face looks along the pivot's LookVector.
	    "Right" and "Left" in part names are the slime's own sides (Roblox rig
	    convention): EyeRight sits at +X and appears on the viewer's left.
	  - Hierarchy:
	      Slime_<Variant> (Model, PrimaryPart = Root)
	      |- Root (invisible Part) with Attachments Center, Top and Face
	      |- Ground (Folder): GroundShadow
	      |- Body (Folder):   Skirt, Core, Gloss, Sparkle
	      |- Face (Folder):   EyeRight, EyeShineRight, EyeLeft, EyeShineLeft,
	      |                   MouthRight, MouthLeft, CheekRight, CheekLeft
	      '- Crown (Folder):  SproutStem, SproutLeaf (the slot future variants swap)
	  - Every part is Anchored with CanCollide, CanTouch and CanQuery off.
	    Only Core casts a shadow. Only GroundShadow is transparent.
	  - Every visible part has a "ColorRole" attribute; applyPalette recolours by role.
	  - Model attributes: EmberAsset = "Slime", EmberVariant, EmberAssetVersion, EmberScale.
	  - The skirt dips up to 0.35 studs (times scale) below the pivot so the
	    slime meets the floor with a flat edge: it is meant to stand on a surface.
	  - Ellipsoids are Block parts with a built-in SpecialMesh (MeshType Sphere).
	    No asset IDs or external content are used.
]]

local visualsFolder = script.Parent :: Instance
local paletteModule = visualsFolder:WaitForChild("VisualPalette", 10)
if paletteModule == nil or not paletteModule:IsA("ModuleScript") then
	error("SlimeModelFactory: the VisualPalette ModuleScript must sit next to this module")
end
local VisualPalette = require(paletteModule :: ModuleScript)

local FACTORY_VERSION = 1
local MIN_SCALE = 0.1
local MAX_SCALE = 10
local ROOT_SIZE = 0.4

-- Cylinders point along their X axis; this turns that axis upright (Y).
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

type Shape = "Ellipsoid" | "Ball" | "Cylinder"
local ELLIPSOID: Shape = "Ellipsoid"
local BALL: Shape = "Ball"
local CYLINDER: Shape = "Cylinder"

export type SlimePalette = { [string]: Color3 }

export type SlimeOptions = {
	variant: string?, -- default "Standard"
	scale: number?, -- default 1, between 0.1 and 10
	palette: SlimePalette?, -- colour overrides by role, for example { Body = Color3.fromHex("#5D9CEC") }
	name: string?, -- default "Slime_<Variant>"
}

type PartSpec = {
	name: string,
	group: string,
	shape: Shape,
	size: Vector3, -- studs at scale 1
	cframe: CFrame, -- relative to the pivot, at scale 1
	role: string,
	transparency: number?,
	castShadow: boolean?,
}

type AnchorSpec = {
	name: string,
	position: Vector3, -- relative to the pivot, at scale 1
}

-- Body and ground shapes, in studs at scale 1.
type BodyShape = {
	size: Vector3, -- ellipsoid diameters
	centerY: number, -- height of the ellipsoid centre above the pivot
	skirtSize: Vector3,
	skirtCenterY: number,
	shadowDiameter: number,
	shadowThickness: number,
	shadowHeight: number,
	shadowTransparency: number,
}

--[[
	Face and surface details, in studs at scale 1. Each is placed on the body's
	front surface at (x, y) and turned to follow the surface. depth moves the
	detail's centre along the surface normal: negative values sink it in, so
	only a cap shows. roll (degrees) turns it clockwise as the viewer sees it.
	Shine u/v are measured on the eye's own surface; negative u is the viewer's right.
]]
type DetailLayout = {
	eyeSize: Vector3,
	eyeX: number,
	eyeY: number,
	eyeDepth: number,
	shineDiameter: number,
	shineU: number,
	shineV: number,
	shineInset: number,
	mouthSize: Vector3,
	mouthX: number,
	mouthY: number,
	mouthDepth: number,
	mouthRoll: number,
	cheekSize: Vector3,
	cheekX: number,
	cheekY: number,
	cheekDepth: number,
	glossSize: Vector3,
	glossX: number,
	glossY: number,
	glossDepth: number,
	glossRoll: number,
	sparkleDiameter: number,
	sparkleX: number,
	sparkleY: number,
	sparkleDepth: number,
}

type SproutLayout = {
	stemLength: number,
	stemDiameter: number,
	stemSink: number, -- how far the stem starts below the top of the body
	stemTilt: number, -- degrees; negative leans toward +X (the viewer's left)
	leafSize: Vector3,
	leafRoll: number, -- degrees the leaf's outer end rises
	leafFaceTilt: number, -- degrees the leaf's face turns toward the front
	leafOverlap: number, -- how far the leaf reaches back over the stem tip
}

type VariantSpec = {
	body: BodyShape,
	details: DetailLayout,
	sprout: SproutLayout,
	palette: SlimePalette,
}

-- Colour roles. Every visible part uses exactly one.
local ROLES = {
	"Body", -- main body
	"BodyShade", -- skirt
	"BodyLight", -- soft gloss
	"Ink", -- eyes and mouth
	"Shine", -- eye highlights
	"Sparkle", -- small warm highlight
	"Blush", -- cheeks
	"Shadow", -- ground shadow
	"Stem", -- sprout stem
	"Leaf", -- sprout leaf
}
local ROLE_SET: { [string]: boolean } = {}
for _, role in ROLES do
	ROLE_SET[role] = true
end

local GROUP_ORDER = { "Ground", "Body", "Face", "Crown" }

-- Every role's colour, derived from a body colour and a blush colour.
local function derivePalette(bodyColor: Color3, blushColor: Color3): SlimePalette
	return {
		Body = bodyColor,
		BodyShade = VisualPalette.shade(bodyColor, 0.8),
		BodyLight = VisualPalette.tint(bodyColor, 0.45),
		Ink = VisualPalette.ShadowNavy,
		Shine = VisualPalette.White,
		Sparkle = VisualPalette.tint(VisualPalette.EmberGold, 0.6),
		Blush = blushColor,
		Shadow = VisualPalette.ShadowNavy,
		Stem = VisualPalette.shade(bodyColor, 0.65),
		Leaf = VisualPalette.shade(bodyColor, 0.85),
	}
end

local STANDARD_BODY: BodyShape = {
	size = Vector3.new(6.2, 4.6, 5.8),
	centerY = 2.25,
	skirtSize = Vector3.new(6.7, 1.3, 6.1),
	skirtCenterY = 0.3,
	shadowDiameter = 7.8,
	shadowThickness = 0.06,
	shadowHeight = 0.05,
	shadowTransparency = 0.55,
}

local STANDARD_DETAILS: DetailLayout = {
	eyeSize = Vector3.new(0.95, 1.35, 0.5),
	eyeX = 1.05,
	eyeY = 2.85,
	eyeDepth = -0.12,
	shineDiameter = 0.34,
	shineU = -0.17, -- viewer's upper right of each eye, the same side as the gloss
	shineV = 0.27,
	shineInset = 0.06,
	mouthSize = Vector3.new(0.6, 0.22, 0.22),
	mouthX = 0.21,
	mouthY = 2.12,
	mouthDepth = -0.06,
	mouthRoll = 18, -- outer ends rise into a smile
	cheekSize = Vector3.new(1.0, 0.55, 0.24),
	cheekX = 1.95,
	cheekY = 2.3,
	cheekDepth = -0.08,
	glossSize = Vector3.new(1.9, 0.95, 0.36),
	glossX = -1.5, -- viewer's upper right
	glossY = 4.05,
	glossDepth = -0.1,
	glossRoll = 20,
	sparkleDiameter = 0.44,
	sparkleX = -2.15,
	sparkleY = 3.55,
	sparkleDepth = -0.05,
}

local STANDARD_SPROUT: SproutLayout = {
	stemLength = 0.75,
	stemDiameter = 0.24,
	stemSink = 0.25,
	stemTilt = -8,
	leafSize = Vector3.new(1.3, 0.14, 0.62),
	leafRoll = 25,
	leafFaceTilt = -35,
	leafOverlap = 0.05,
}

-- Future variants (Ember, Frost, Shadow, Boss) add entries here with their own
-- palette and, later, their own crown piece. Only Standard exists in V1.
local VARIANTS: { [string]: VariantSpec } = {
	Standard = {
		body = STANDARD_BODY,
		details = STANDARD_DETAILS,
		sprout = STANDARD_SPROUT,
		palette = derivePalette(VisualPalette.ForestGreen, VisualPalette.EmberOrange),
	},
}

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

-- A frame on the body's front surface at (x, y): local -Z points out along the
-- surface normal, local +Y stays as close to world up as the surface allows.
local function surfaceFrame(body: BodyShape, x: number, y: number, depth: number, roll: number): CFrame
	local a, b, c = body.size.X / 2, body.size.Y / 2, body.size.Z / 2
	local dy = y - body.centerY
	local inside = 1 - (x / a) ^ 2 - (dy / b) ^ 2
	if inside <= 0.02 then
		error(`SlimeModelFactory: detail at ({x}, {y}) is off the body surface`, 2)
	end
	local point = Vector3.new(x, y, -c * math.sqrt(inside))
	local normal = Vector3.new(point.X / (a * a), dy / (b * b), point.Z / (c * c)).Unit
	local position = point + normal * depth
	return CFrame.lookAt(position, position + normal, Vector3.yAxis) * CFrame.Angles(0, 0, math.rad(roll))
end

-- A frame on the front of an ellipsoid (given its frame and size) at (u, v) on
-- its face, pushed inset studs back toward the ellipsoid's centre.
local function ellipsoidFrontFrame(frame: CFrame, size: Vector3, u: number, v: number, inset: number): CFrame
	local a, b, c = size.X / 2, size.Y / 2, size.Z / 2
	local inside = 1 - (u / a) ^ 2 - (v / b) ^ 2
	if inside <= 0.02 then
		error(`SlimeModelFactory: detail at ({u}, {v}) is off the ellipsoid`, 2)
	end
	return frame * CFrame.new(u, v, -c * math.sqrt(inside) + inset)
end

local function buildLayout(variant: VariantSpec): ({ PartSpec }, { AnchorSpec })
	local body = variant.body
	local d = variant.details
	local sprout = variant.sprout
	local specs: { PartSpec } = {}

	local function add(spec: PartSpec)
		table.insert(specs, spec)
	end

	-- Ground
	add({
		name = "GroundShadow",
		group = "Ground",
		shape = CYLINDER,
		size = Vector3.new(body.shadowThickness, body.shadowDiameter, body.shadowDiameter),
		cframe = CFrame.new(0, body.shadowHeight, 0) * UPRIGHT,
		role = "Shadow",
		transparency = body.shadowTransparency,
	})

	-- Body
	add({
		name = "Skirt",
		group = "Body",
		shape = ELLIPSOID,
		size = body.skirtSize,
		cframe = CFrame.new(0, body.skirtCenterY, 0),
		role = "BodyShade",
	})
	add({
		name = "Core",
		group = "Body",
		shape = ELLIPSOID,
		size = body.size,
		cframe = CFrame.new(0, body.centerY, 0),
		role = "Body",
		castShadow = true,
	})
	add({
		name = "Gloss",
		group = "Body",
		shape = ELLIPSOID,
		size = d.glossSize,
		cframe = surfaceFrame(body, d.glossX, d.glossY, d.glossDepth, d.glossRoll),
		role = "BodyLight",
	})
	add({
		name = "Sparkle",
		group = "Body",
		shape = BALL,
		size = Vector3.one * d.sparkleDiameter,
		cframe = surfaceFrame(body, d.sparkleX, d.sparkleY, d.sparkleDepth, 0),
		role = "Sparkle",
	})

	-- Face. side = 1 is +X: the slime's own right, the viewer's left.
	for _, side in { 1, -1 } do
		local suffix = if side == 1 then "Right" else "Left"
		local eyeFrame = surfaceFrame(body, side * d.eyeX, d.eyeY, d.eyeDepth, 0)
		add({
			name = "Eye" .. suffix,
			group = "Face",
			shape = ELLIPSOID,
			size = d.eyeSize,
			cframe = eyeFrame,
			role = "Ink",
		})
		add({
			name = "EyeShine" .. suffix,
			group = "Face",
			shape = BALL,
			size = Vector3.one * d.shineDiameter,
			cframe = ellipsoidFrontFrame(eyeFrame, d.eyeSize, d.shineU, d.shineV, d.shineInset),
			role = "Shine",
		})
	end
	for _, side in { 1, -1 } do
		add({
			name = "Mouth" .. (if side == 1 then "Right" else "Left"),
			group = "Face",
			shape = ELLIPSOID,
			size = d.mouthSize,
			cframe = surfaceFrame(body, side * d.mouthX, d.mouthY, d.mouthDepth, side * d.mouthRoll),
			role = "Ink",
		})
	end
	for _, side in { 1, -1 } do
		add({
			name = "Cheek" .. (if side == 1 then "Right" else "Left"),
			group = "Face",
			shape = ELLIPSOID,
			size = d.cheekSize,
			cframe = surfaceFrame(body, side * d.cheekX, d.cheekY, d.cheekDepth, 0),
			role = "Blush",
		})
	end

	-- Crown: a small sprout leaning toward the viewer's left.
	local tilt = CFrame.Angles(0, 0, math.rad(sprout.stemTilt))
	local stemBase = Vector3.new(0, body.centerY + body.size.Y / 2 - sprout.stemSink, 0)
	add({
		name = "SproutStem",
		group = "Crown",
		shape = CYLINDER,
		size = Vector3.new(sprout.stemLength, sprout.stemDiameter, sprout.stemDiameter),
		cframe = CFrame.new(stemBase) * tilt * CFrame.new(0, sprout.stemLength / 2, 0) * UPRIGHT,
		role = "Stem",
	})
	local stemTip = stemBase + tilt:VectorToWorldSpace(Vector3.new(0, sprout.stemLength, 0))
	local leafRoll = CFrame.Angles(0, 0, math.rad(sprout.leafRoll))
	local leafCenter = stemTip + leafRoll.RightVector * (sprout.leafSize.X / 2 - sprout.leafOverlap)
	add({
		name = "SproutLeaf",
		group = "Crown",
		shape = ELLIPSOID,
		size = sprout.leafSize,
		cframe = CFrame.new(leafCenter) * leafRoll * CFrame.Angles(math.rad(sprout.leafFaceTilt), 0, 0),
		role = "Leaf",
	})

	-- Anchors for future effects (hit bursts, damage numbers, crowns).
	local faceFrame = surfaceFrame(body, 0, body.centerY + 0.25, 0.05, 0)
	local anchors: { AnchorSpec } = {
		{ name = "Center", position = Vector3.new(0, body.centerY, 0) },
		{ name = "Top", position = Vector3.new(0, body.centerY + body.size.Y / 2, 0) },
		{ name = "Face", position = faceFrame.Position },
	}

	return specs, anchors
end

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------

local function scaledFrame(frame: CFrame, scale: number): CFrame
	return frame.Rotation + frame.Position * scale
end

local function applyCommonProperties(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function newPart(spec: PartSpec, scale: number, palette: SlimePalette, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = spec.name
	if spec.shape == BALL then
		part.Shape = Enum.PartType.Ball
	elseif spec.shape == CYLINDER then
		part.Shape = Enum.PartType.Cylinder
	else
		part.Shape = Enum.PartType.Block
	end
	part.Size = spec.size * scale
	part.CFrame = scaledFrame(spec.cframe, scale)
	part.Color = palette[spec.role]
	part.Transparency = spec.transparency or 0
	part.CastShadow = spec.castShadow == true
	applyCommonProperties(part)
	part:SetAttribute("ColorRole", spec.role)

	if spec.shape == ELLIPSOID then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- fills the part's Size, so it scales with the part
		mesh.Parent = part
	end

	part.Parent = parent
	return part
end

local function validatePalette(palette: unknown, caller: string)
	if typeof(palette) ~= "table" then
		error(`{caller}: palette must be a table of role = Color3`, 3)
	end
	for role, color in palette :: { [unknown]: unknown } do
		if typeof(role) ~= "string" or ROLE_SET[role] == nil then
			error(`{caller}: unknown colour role "{tostring(role)}" (roles: {table.concat(ROLES, ", ")})`, 3)
		end
		if typeof(color) ~= "Color3" then
			error(`{caller}: colour role "{role}" must be a Color3`, 3)
		end
	end
end

local function sortedVariantNames(): { string }
	local names: { string } = {}
	for name in VARIANTS do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

local SlimeModelFactory = {}

SlimeModelFactory.VERSION = FACTORY_VERSION
SlimeModelFactory.MIN_SCALE = MIN_SCALE
SlimeModelFactory.MAX_SCALE = MAX_SCALE
SlimeModelFactory.ROLES = table.freeze(table.clone(ROLES))

-- Names of the variants this version can build, sorted.
function SlimeModelFactory.listVariants(): { string }
	return sortedVariantNames()
end

-- A copy of a variant's default colours by role (safe to modify).
function SlimeModelFactory.getPalette(variantName: string?): SlimePalette
	local name = variantName or "Standard"
	local variant = VARIANTS[name]
	if variant == nil then
		error(`SlimeModelFactory.getPalette: unknown variant "{name}"`, 2)
	end
	return table.clone(variant.palette)
end

--[[
	Builds a new, unparented slime Model at the origin (pivot = CFrame.identity).
	Errors on an unknown variant, a scale outside 0.1 to 10, or a bad palette.
]]
function SlimeModelFactory.create(options: SlimeOptions?): Model
	if options ~= nil and typeof(options) ~= "table" then
		error("SlimeModelFactory.create: options must be a table or nil", 2)
	end
	local opts: SlimeOptions = options or {}

	local variantName = opts.variant or "Standard"
	local variant = VARIANTS[variantName]
	if variant == nil then
		error(
			`SlimeModelFactory.create: unknown variant "{tostring(variantName)}" (available: {table.concat(
				sortedVariantNames(),
				", "
			)})`,
			2
		)
	end

	local scale = opts.scale or 1
	if typeof(scale) ~= "number" or scale ~= scale or scale < MIN_SCALE or scale > MAX_SCALE then
		error(`SlimeModelFactory.create: scale must be a number from {MIN_SCALE} to {MAX_SCALE}`, 2)
	end

	local palette = table.clone(variant.palette)
	local overrides = opts.palette
	if overrides ~= nil then
		validatePalette(overrides, "SlimeModelFactory.create")
		for role, color in overrides do
			palette[role] = color
		end
	end

	local name = opts.name or `Slime_{variantName}`
	if typeof(name) ~= "string" or name == "" then
		error("SlimeModelFactory.create: name must be a non-empty string", 2)
	end

	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Block
	root.Size = Vector3.one * (ROOT_SIZE * scale)
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.CastShadow = false
	applyCommonProperties(root)
	root.Parent = model

	local specs, anchors = buildLayout(variant)

	for _, anchor in anchors do
		local attachment = Instance.new("Attachment")
		attachment.Name = anchor.name
		attachment.Position = anchor.position * scale
		attachment.Parent = root
	end

	local folders: { [string]: Folder } = {}
	for _, groupName in GROUP_ORDER do
		local folder = Instance.new("Folder")
		folder.Name = groupName
		folders[groupName] = folder
	end
	for _, spec in specs do
		newPart(spec, scale, palette, folders[spec.group])
	end
	for _, groupName in GROUP_ORDER do
		folders[groupName].Parent = model
	end

	model.PrimaryPart = root
	model:SetAttribute("EmberAsset", "Slime")
	model:SetAttribute("EmberVariant", variantName)
	model:SetAttribute("EmberAssetVersion", FACTORY_VERSION)
	model:SetAttribute("EmberScale", scale)
	return model
end

-- Recolours a factory-made slime by role. Roles not in palette keep their colour.
function SlimeModelFactory.applyPalette(model: Model, palette: SlimePalette)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or model:GetAttribute("EmberAsset") ~= "Slime" then
		error("SlimeModelFactory.applyPalette: expected a slime Model made by this factory", 2)
	end
	validatePalette(palette, "SlimeModelFactory.applyPalette")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local role = descendant:GetAttribute("ColorRole")
			if typeof(role) == "string" then
				local color = palette[role]
				if color ~= nil then
					descendant.Color = color
				end
			end
		end
	end
end

-- The visible parts (everything except Root), in hierarchy order. Useful for fades.
function SlimeModelFactory.getVisualParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, groupName in GROUP_ORDER do
		local folder = model:FindFirstChild(groupName)
		if folder ~= nil then
			for _, child in folder:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(parts, child)
				end
			end
		end
	end
	return parts
end

return table.freeze(SlimeModelFactory)
]============]
ART_SOURCES["SlimePreview"] = [============[
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
]============]

local EXPECTED_LENGTHS = {
	VisualPalette = 1447,
	SlimeModelFactory = 19942,
	SlimePreview = 25532,
}

(function()
	local PREFIX = "[ART-001 installer]"
	if game:GetService("RunService"):IsRunning() then
		warn(PREFIX, "Stop the playtest first; run the installer in Edit mode. Nothing was changed.")
		return
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if shared == nil or not shared:IsA("Folder") then
		warn(PREFIX, "ReplicatedStorage.Shared was not found. Open the Emberbound place first. Nothing was changed.")
		return
	end

	local targets = {
		{ name = "VisualPalette", parent = shared, folder = "Visuals", path = "ReplicatedStorage.Shared.Visuals" },
		{ name = "SlimeModelFactory", parent = shared, folder = "Visuals", path = "ReplicatedStorage.Shared.Visuals" },
		{ name = "SlimePreview", parent = ServerStorage, folder = "EmberDev", path = "ServerStorage.EmberDev" },
	}

	-- Check everything before changing anything.
	local existing = {}
	for _, target in targets do
		local holder = target.parent:FindFirstChild(target.folder)
		if holder ~= nil and not holder:IsA("Folder") then
			warn(PREFIX, `{target.path} exists but is a {holder.ClassName}, not a Folder. Nothing was changed.`)
			return
		end
		local current = if holder then holder:FindFirstChild(target.name) else nil
		if current ~= nil then
			if not current:IsA("ModuleScript") then
				warn(PREFIX, `{target.path}.{target.name} exists but is a {current.ClassName}. Nothing was changed.`)
				return
			end
			table.insert(existing, `{target.path}.{target.name}`)
		end
	end
	if #existing > 0 and not REPLACE_EXISTING_ART then
		warn(PREFIX, "Already installed: " .. table.concat(existing, ", "))
		warn(PREFIX, "Nothing was changed. To replace just these modules, set REPLACE_EXISTING_ART = true at the top and run again.")
		return
	end

	for _, target in targets do
		local holder = target.parent:FindFirstChild(target.folder)
		if holder == nil then
			holder = Instance.new("Folder")
			holder.Name = target.folder
			holder.Parent = target.parent
		end
		local module = holder:FindFirstChild(target.name)
		if module == nil then
			module = Instance.new("ModuleScript")
			module.Name = target.name
			module.Parent = holder
		end
		module.Source = ART_SOURCES[target.name]
	end

	-- Source parity: every module must hold exactly the text from the repository.
	local allMatch = true
	for _, target in targets do
		local module = target.parent:FindFirstChild(target.folder):FindFirstChild(target.name)
		local length = #module.Source
		local matches = module.Source == ART_SOURCES[target.name] and length == EXPECTED_LENGTHS[target.name]
		allMatch = allMatch and matches
		print(PREFIX, `{target.path}.{target.name}: {length} characters`, if matches then "(matches)" else "(MISMATCH)")
	end
	if allMatch then
		print(PREFIX, "Installed 3 ModuleScripts. Nothing else was changed.")
		print(PREFIX, "Next, paste this into the Command Bar:  require(game.ServerStorage.EmberDev.SlimePreview).check()")
	else
		warn(PREFIX, "A module does not match the repository text. Report this before testing.")
	end
end)()
