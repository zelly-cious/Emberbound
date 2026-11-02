--[[
	prelude.lua (review tooling, NOT game code): the Luau library pieces Emberbound's server code
	and the offline harness use, written for plain Lua 5.1. Loaded before the translated bundle.

	Deliberate limits:
	  - table.freeze only makes BigNum-shaped tables ({ m = number, e = number }) read-only,
	    through a proxy; other tables are returned unchanged. That is enough for every test that
	    checks immutability, and plain Lua 5.1 cannot freeze arrays without breaking # and ipairs.
	  - tostring prints numbers with the shortest of %.14g .. %.17g that reads back exactly, close
	    to Luau's shortest round-trip output; it is used for messages, not for any checked value.
]]

local rawtostring = tostring
function tostring(value)
	if type(value) == "number" then
		if value ~= value then
			return "nan"
		elseif value == math.huge then
			return "inf"
		elseif value == -math.huge then
			return "-inf"
		end
		for digits = 14, 17 do
			local text = string.format("%." .. digits .. "g", value)
			if tonumber(text) == value then
				return text
			end
		end
	end
	return rawtostring(value)
end
__tostr = tostring

function typeof(value)
	return type(value)
end

function warn(...)
	print("[warn]", ...)
end

local frozenStore = setmetatable({}, { __mode = "k" })
local frozenOther = setmetatable({}, { __mode = "k" })

local function readonly()
	error("attempt to modify a readonly table", 2)
end

function table.freeze(t)
	if frozenStore[t] or frozenOther[t] then
		return t
	end
	local keys = 0
	for _ in pairs(t) do
		keys = keys + 1
	end
	if getmetatable(t) == nil and keys == 2 and type(rawget(t, "m")) == "number" and type(rawget(t, "e")) == "number" then
		local store = { m = rawget(t, "m"), e = rawget(t, "e") }
		rawset(t, "m", nil)
		rawset(t, "e", nil)
		setmetatable(t, { __index = store, __newindex = readonly, __metatable = "frozen" })
		frozenStore[t] = store
	else
		frozenOther[t] = true
	end
	return t
end

function table.isfrozen(t)
	return frozenStore[t] ~= nil or frozenOther[t] ~= nil
end

function table.find(t, value, init)
	for index = init or 1, #t do
		if t[index] == value then
			return index
		end
	end
	return nil
end

function table.clone(t)
	local copy = {}
	local store = frozenStore[t]
	for k, v in pairs(store or t) do
		copy[k] = v
	end
	if store == nil then
		setmetatable(copy, getmetatable(t))
	end
	return copy
end

function table.create(count, value)
	local result = {}
	for index = 1, count do
		result[index] = value
	end
	return result
end

function table.clear(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

function table.move(source, first, last, offset, destination)
	destination = destination or source
	if last >= first then
		if offset > first and offset <= last and destination == source then
			for index = last - first, 0, -1 do
				destination[offset + index] = source[first + index]
			end
		else
			for index = 0, last - first do
				destination[offset + index] = source[first + index]
			end
		end
	end
	return destination
end

table.unpack = table.unpack or unpack

function string.split(text, separator)
	local parts, start = {}, 1
	separator = separator or ","
	while true do
		local first, last = string.find(text, separator, start, true)
		if first == nil then
			parts[#parts + 1] = string.sub(text, start)
			return parts
		end
		parts[#parts + 1] = string.sub(text, start, first - 1)
		start = last + 1
	end
end

function math.clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

--[[ Luau generalized iteration: functions iterate as usual, tables with next (frozen ones via their store). ]]
function __iter(value, ...)
	if type(value) == "function" then
		return value, ...
	end
	if type(value) == "table" then
		return next, frozenStore[value] or value
	end
	error("attempt to iterate over a " .. type(value) .. " value", 2)
end
