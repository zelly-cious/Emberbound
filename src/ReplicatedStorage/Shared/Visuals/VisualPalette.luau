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
