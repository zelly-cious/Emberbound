--[[
	prelude.lua (review tooling, NOT game code): the Luau library pieces Emberbound's server code
	and the offline harness use, written for plain Lua 5.1. Loaded before the translated bundle.

	Deliberate limits:
	  - table.freeze only makes BigNum-shaped tables ({ m = number, e = number }) read-only,
	    through a proxy; other tables are returned unchanged. That is enough for every test that
	    checks immutability, and plain Lua 5.1 cannot freeze arrays without breaking # and ipairs.
	  - tostring follows Luau's number printing (VM/src/lnumprint.cpp): the shortest digits that
	    read back exactly, fixed notation while the decimal point is within [-5, 21] digits,
	    otherwise scientific ("5e-324", "1e+21"). Luau computes the digits with integer
	    arithmetic (Schubfach); here glibc printf does, which is also integer arithmetic, so
	    neither is changed by flush-to-zero. Exponent padding is approximated (two digits minimum);
	    subnormal exponents always have three.
	  - buffer has only create, writeu32, readu32 and readf64. readf64 builds the double from its
	    bit pattern as a hexadecimal float literal read by glibc strtod, which assembles the bits
	    with integer arithmetic, so a flush-to-zero host keeps subnormal fixtures exact.

	DEFECT-001B model (FTZ_HARNESS_WINDOWS_FORMAT=1): Roblox Studio's string.format printed "0" for
	the subnormal 5e-324 with "%.17g" while Luau's tostring printed "5e-324" (owner's Studio
	diagnostic). glibc printf does not do that, even with FTZ on. When the variable is set,
	string.format replaces every subnormal argument of a floating-point conversion (e, E, f, g, G)
	with 0 before formatting. That reproduces the observed "0" and assumes every subnormal behaves
	like 5e-324; normal values, tostring and tonumber are unchanged, as observed.
]]

local rawformat = string.format
__rawformat = rawformat -- harness display code only; never used by game code
local MIN_NORMAL = 2.2250738585072014e-308
MODEL_WINDOWS_FORMAT = os.getenv("FTZ_HARNESS_WINDOWS_FORMAT") == "1"

if MODEL_WINDOWS_FORMAT then
	function string.format(format, ...)
		local count = select("#", ...)
		local args = { ... }
		local index = 0
		for conversion in string.gmatch(format, "%%[-+ #0]*%d*%.?%d*([%a%%])") do
			if conversion ~= "%" then
				index = index + 1
				local value = args[index]
				if string.find("eEfgG", conversion, 1, true) and type(value) == "number" and value ~= 0 and math.abs(value) < MIN_NORMAL then
					args[index] = 0
				end
			end
		end
		return rawformat(format, unpack(args, 1, count))
	end
end

local function luauNumberText(value)
	if value ~= value then
		return "nan"
	elseif value == math.huge then
		return "inf"
	elseif value == -math.huge then
		return "-inf"
	elseif value == 0 then
		return (1 / value < 0) and "-0" or "0"
	end
	local sign = ""
	if value < 0 then
		sign, value = "-", -value
	end
	local digits, exponent
	for precision = 0, 16 do
		local text = rawformat("%." .. precision .. "e", value)
		if tonumber(text) == value then
			local lead, rest, power = string.match(text, "^(%d)%.?(%d*)e([-+]%d+)$")
			digits = string.gsub(lead .. rest, "0+$", "")
			exponent = tonumber(power)
			break
		end
	end
	local dot = exponent + 1 -- value = 0.<digits> * 10^dot
	if dot >= -5 and dot <= 21 then
		if dot <= 0 then
			return sign .. "0." .. string.rep("0", -dot) .. digits
		elseif dot >= #digits then
			return sign .. digits .. string.rep("0", dot - #digits)
		end
		return sign .. string.sub(digits, 1, dot) .. "." .. string.sub(digits, dot + 1)
	end
	local mantissa = string.sub(digits, 1, 1)
	if #digits > 1 then
		mantissa = mantissa .. "." .. string.sub(digits, 2)
	end
	return sign .. mantissa .. "e" .. (dot > 0 and "+" or "-") .. rawformat("%02d", dot > 0 and dot - 1 or 1 - dot)
end

local rawtostring = tostring
function tostring(value)
	if type(value) == "number" then
		return luauNumberText(value)
	end
	return rawtostring(value)
end
__tostr = tostring

buffer = {}
local function bufferBytes(b, offset, size)
	assert(type(b) == "table" and b.__buffer, "not a buffer")
	assert(offset % 1 == 0 and offset >= 0 and offset + size <= b.size, "buffer access out of bounds")
	return b.bytes
end
function buffer.create(size)
	return { __buffer = true, size = size, bytes = table.create(size, 0) }
end
function buffer.writeu32(b, offset, value)
	local bytes = bufferBytes(b, offset, 4)
	value = value % 4294967296
	for index = 1, 4 do
		bytes[offset + index] = value % 256
		value = (value - value % 256) / 256
	end
end
function buffer.readu32(b, offset)
	local bytes = bufferBytes(b, offset, 4)
	return bytes[offset + 1] + bytes[offset + 2] * 256 + bytes[offset + 3] * 65536 + bytes[offset + 4] * 16777216
end
function buffer.readf64(b, offset)
	local low, high = buffer.readu32(b, offset), buffer.readu32(b, offset + 4)
	local sign = high >= 2147483648 and "-" or ""
	local biased = math.floor(high / 1048576) % 2048
	local fraction = rawformat("%05x%08x", high % 1048576, low)
	if biased == 2047 then
		if fraction == "0000000000000" then
			return sign == "-" and -math.huge or math.huge
		end
		return 0 / 0
	elseif biased == 0 then
		return tonumber(sign .. "0x0." .. fraction .. "p-1022")
	end
	return tonumber(sign .. "0x1." .. fraction .. "p" .. (biased - 1023))
end

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
