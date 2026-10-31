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
	      |- Root (invisible Part) with Attachments Center, Top and FaceAnchor
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
	glossSize = Vector3.new(1.9, 0.95, 0.44),
	glossX = -1.5, -- viewer's upper right
	glossY = 4.05,
	glossDepth = -0.14, -- deep enough that the whole rim stays inside the body
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
		{ name = "FaceAnchor", position = faceFrame.Position }, -- not "Face": that is the face Folder
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
