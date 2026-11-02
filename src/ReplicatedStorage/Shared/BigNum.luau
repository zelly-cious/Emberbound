--!strict
--[[
	BigNum
	Location: ReplicatedStorage > Shared > BigNum (ModuleScript)

	Non-negative big numbers for values that grow exponentially: enemy HP, tap
	damage, Gold balances, upgrade costs and (later) hero DPS.

	Representation: value = m * 10^e, in one of two regimes chosen by size:
	  - small: e == 0 and 0 <= m < 2^53. m holds the exact double, so early-game
	    arithmetic is bit-for-bit the same as Milestone 1's plain numbers.
	  - large: 1 <= m < 10 and e >= 15, with value >= 2^53. e is an integer up
	    to 2^53 - 1, so values far beyond 10^308 are supported.
	Every value has exactly one representation, so comparisons and canonical
	strings are stable.

	Values are frozen; create new ones with the functions below.
	Canonical text (saves and network): "%.17g" of m, plus "e<exponent>" for
	large values, e.g. "13", "0.5", "1.5e400".
]]

-- Every BigNum is frozen at runtime (see make). The fields are not marked `read`, because the old
-- type solver rejects that syntax ("read keyword is illegal here") and Studio may use either solver.
export type BigNum = {
	m: number,
	e: number,
}

local SMALL_LIMIT = 9007199254740992 -- 2^53: below this, doubles represent every integer exactly
local MAX_EXPONENT = 9007199254740991 -- 2^53 - 1: largest exponent that is still an exact integer
local SMALL_LOG_LIMIT = 16 -- below 10^16 a value may be computed with plain doubles first
local MAX_EXACT_POWER_OF_TEN = 22 -- 10^22 is the largest power of ten a double holds exactly
local IGNORE_GAP = 17 -- a value 17+ orders of magnitude smaller cannot change a sum or difference
local MAX_TEXT_LENGTH = 64
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local BigNum = {}

local function make(m: number, e: number): BigNum
	local value: BigNum = { m = m, e = e }
	-- Freezes in place. The cast stops the new solver from narrowing value to read-only fields.
	table.freeze(value :: any)
	return value
end

local ZERO = make(0, 0)
local ONE = make(1, 0)

BigNum.zero = ZERO
BigNum.one = ONE

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--[[
	m * 10^power and m / 10^power. Powers below -300 are applied in two steps:
	subnormal doubles (down to 5e-324) need 10^-324, which underflows to zero on
	its own. Every other power uses the single operation, so ordinary values
	round exactly as before.

	DEFECT-001: a host that flushes subnormal results to zero (FTZ, as Roblox Studio
	did) makes the two-step product 0 even when m * 10^power is a representable
	subnormal. Only then (a zero product from a positive m) the value is rebuilt from
	decimal text, which tonumber rounds correctly; it still returns 0 for a genuine
	underflow (below half of 5e-324). Every other result is returned unchanged.
]]
local function multiplyByPowerOfTen(m: number, power: number): number
	if power < -300 then
		local value = m * 10 ^ (power + 300) * 1e-300
		if value == 0 and m > 0 then
			value = tonumber(string.format("%.17ge%.0f", m, power)) or 0
		end
		return value
	end
	return m * 10 ^ power
end

local function divideByPowerOfTen(m: number, power: number): number
	if power < -300 then
		return m * 1e300 / 10 ^ (power + 300)
	end
	return m / 10 ^ power
end

-- Brings any finite, non-negative m * 10^e (e an integer) into canonical form; nil if e would exceed 2^53 - 1.
local function tryNormalize(m: number, e: number): BigNum?
	if m <= 0 then
		return ZERO
	end
	if m < 1 or m >= 10 then
		local shift = math.floor(math.log10(m))
		m = divideByPowerOfTen(m, shift)
		e += shift
		if m >= 10 then
			m /= 10
			e += 1
		elseif m < 1 then
			m *= 10
			e -= 1
		end
	end
	if e > MAX_EXPONENT then
		return nil
	end
	if e < SMALL_LOG_LIMIT then
		local value = multiplyByPowerOfTen(m, e)
		if value < SMALL_LIMIT then
			return make(value, 0)
		end
	end
	return make(m, e)
end

-- tryNormalize for arithmetic results, where an exponent beyond 2^53 - 1 is an overflow error.
local function normalize(m: number, e: number): BigNum
	local value = tryNormalize(m, e)
	if value == nil then
		error("BigNum overflow: exponent exceeds 2^53 - 1", 3)
	end
	return value
end

-- Mantissa in [1, 10) and integer exponent for any non-zero value (small values included).
local function toScientific(value: BigNum): (number, number)
	if value.e ~= 0 or value.m == 0 then
		return value.m, value.e
	end
	local mantissa = value.m
	local exponent = math.floor(math.log10(mantissa))
	mantissa = divideByPowerOfTen(mantissa, exponent)
	if mantissa >= 10 then
		mantissa /= 10
		exponent += 1
	elseif mantissa < 1 then
		mantissa *= 10
		exponent -= 1
	end
	return mantissa, exponent
end

local function trimZeros(text: string): string
	return (string.gsub(text, "%.?0+$", ""))
end

---------------------------------------------------------------------------
-- Construction and validation
---------------------------------------------------------------------------

-- Converts a plain number. Errors on NaN, infinity or negative input (programmer error).
function BigNum.fromNumber(value: number): BigNum
	if not isFiniteNumber(value) or value < 0 then
		error(`BigNum.fromNumber expects a finite, non-negative number (got {value})`, 2)
	end
	if value == 0 then
		return ZERO
	end
	if value < SMALL_LIMIT then
		return make(value, 0)
	end
	return normalize(value, 0)
end

-- 10^exponent for any finite exponent, without ever computing an overflowing double.
function BigNum.fromLog10(exponent: number): BigNum
	if not isFiniteNumber(exponent) then
		error("BigNum.fromLog10 expects a finite number", 2)
	end
	if exponent < SMALL_LOG_LIMIT then
		local value = 10 ^ exponent
		if value < SMALL_LIMIT then
			return if value == 0 then ZERO else make(value, 0)
		end
	end
	local whole = math.floor(exponent)
	return normalize(10 ^ (exponent - whole), whole)
end

--[[
	base * growth^steps, the shape of every scaling formula in Emberbound.
	While the result stays below 10^16 it is computed with the same double
	expression Milestone 1 used, so early values match exactly. Beyond that it
	is computed in log space and never overflows.
]]
function BigNum.scaledPower(base: number, growth: number, steps: number): BigNum
	if not isFiniteNumber(base) or base < 0 then
		error("BigNum.scaledPower expects a finite, non-negative base", 2)
	end
	if not isFiniteNumber(growth) or growth <= 0 then
		error("BigNum.scaledPower expects a finite, positive growth", 2)
	end
	if not isFiniteNumber(steps) or steps < 0 then
		error("BigNum.scaledPower expects finite, non-negative steps", 2)
	end
	if base == 0 then
		return ZERO
	end
	local magnitude = math.log10(base) + steps * math.log10(growth)
	if magnitude < SMALL_LOG_LIMIT then
		local value = base * growth ^ steps
		if value < SMALL_LIMIT then
			return if value == 0 then ZERO else make(value, 0)
		end
	end
	return BigNum.fromLog10(magnitude)
end

-- True only for a table that satisfies every BigNum invariant. Use on any value from outside the module.
function BigNum.isValid(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local candidate: any = value
	local m, e = candidate.m, candidate.e
	if not isFiniteNumber(m) or not isFiniteNumber(e) then
		return false
	end
	if e == 0 then
		return m >= 0 and m < SMALL_LIMIT
	end
	if e % 1 ~= 0 or e < 15 or e > MAX_EXPONENT or m < 1 or m >= 10 then
		return false
	end
	return e > 15 or m * 1e15 >= SMALL_LIMIT
end

---------------------------------------------------------------------------
-- Comparison
---------------------------------------------------------------------------

-- Returns -1, 0 or 1.
function BigNum.compare(a: BigNum, b: BigNum): number
	if a.e ~= b.e then
		return if a.e < b.e then -1 else 1
	end
	if a.m < b.m then
		return -1
	elseif a.m > b.m then
		return 1
	end
	return 0
end

function BigNum.eq(a: BigNum, b: BigNum): boolean
	return a.e == b.e and a.m == b.m
end

function BigNum.lt(a: BigNum, b: BigNum): boolean
	return BigNum.compare(a, b) < 0
end

function BigNum.lte(a: BigNum, b: BigNum): boolean
	return BigNum.compare(a, b) <= 0
end

function BigNum.gt(a: BigNum, b: BigNum): boolean
	return BigNum.compare(a, b) > 0
end

function BigNum.gte(a: BigNum, b: BigNum): boolean
	return BigNum.compare(a, b) >= 0
end

function BigNum.isZero(value: BigNum): boolean
	return value.m == 0
end

function BigNum.max(a: BigNum, b: BigNum): BigNum
	return if BigNum.compare(a, b) >= 0 then a else b
end

function BigNum.min(a: BigNum, b: BigNum): BigNum
	return if BigNum.compare(a, b) <= 0 then a else b
end

---------------------------------------------------------------------------
-- Arithmetic
---------------------------------------------------------------------------

function BigNum.add(a: BigNum, b: BigNum): BigNum
	if a.e == 0 and b.e == 0 then
		local sum = a.m + b.m -- exact while both operands and the result stay below 2^53
		if sum < SMALL_LIMIT then
			return make(sum, 0)
		end
		return normalize(sum, 0)
	end
	if a.m == 0 then
		return b
	end
	if b.m == 0 then
		return a
	end
	local larger, smaller = a, b
	if BigNum.compare(a, b) < 0 then
		larger, smaller = b, a
	end
	local largeM, largeE = toScientific(larger)
	local smallM, smallE = toScientific(smaller)
	local gap = largeE - smallE
	if gap > IGNORE_GAP then
		return larger
	end
	return normalize(largeM + smallM / 10 ^ gap, largeE)
end

-- Saturating subtraction: returns zero when b >= a. Use trySub when going below zero must be refused.
function BigNum.sub(a: BigNum, b: BigNum): BigNum
	if BigNum.compare(a, b) <= 0 then
		return ZERO
	end
	if a.e == 0 then
		return make(a.m - b.m, 0) -- both small: exact
	end
	if b.m == 0 then
		return a
	end
	-- Scientific form loses the low digits here (2^53 - (2^53 - 1) came out as 1.776). Below 10^23
	-- (10^22 is the largest exact power of ten) both operands convert to doubles in one rounding,
	-- exactly below 10^16, so one correctly rounded subtraction is used instead. Doubles at or
	-- above 2^53 are whole numbers, so a result below 2^53 is exact.
	if a.e <= MAX_EXACT_POWER_OF_TEN then
		local difference = BigNum.toNumber(a) - BigNum.toNumber(b)
		return if difference > 0 then BigNum.fromNumber(difference) else ZERO
	end
	local smallM, smallE = toScientific(b)
	local gap = a.e - smallE
	if gap > IGNORE_GAP then
		return a
	end
	return normalize(a.m - smallM / 10 ^ gap, a.e)
end

-- a - b, or nil when b > a. The building block for "spend only if affordable".
function BigNum.trySub(a: BigNum, b: BigNum): BigNum?
	if BigNum.compare(a, b) < 0 then
		return nil
	end
	return BigNum.sub(a, b)
end

function BigNum.mul(a: BigNum, b: BigNum): BigNum
	if a.m == 0 or b.m == 0 then
		return ZERO
	end
	if a.e == 0 and b.e == 0 then
		local product = a.m * b.m
		if product < SMALL_LIMIT then
			return make(product, 0)
		end
	end
	local aM, aE = toScientific(a)
	local bM, bE = toScientific(b)
	return normalize(aM * bM, aE + bE)
end

-- Multiplies by a plain finite, non-negative number (for example an interval in seconds).
function BigNum.mulNumber(a: BigNum, factor: number): BigNum
	return BigNum.mul(a, BigNum.fromNumber(factor))
end

function BigNum.div(a: BigNum, b: BigNum): BigNum
	if b.m == 0 then
		error("BigNum.div: division by zero", 2)
	end
	if a.m == 0 then
		return ZERO
	end
	if a.e == 0 and b.e == 0 then
		local quotient = a.m / b.m
		if quotient < SMALL_LIMIT then
			return make(quotient, 0)
		end
	end
	local aM, aE = toScientific(a)
	local bM, bE = toScientific(b)
	return normalize(aM / bM, aE - bE)
end

-- a / b as a plain number (for example a health bar fill). Can return math.huge for enormous ratios.
function BigNum.ratio(a: BigNum, b: BigNum): number
	if b.m == 0 then
		error("BigNum.ratio: division by zero", 2)
	end
	if a.m == 0 then
		return 0
	end
	if a.e == 0 and b.e == 0 then
		return a.m / b.m
	end
	local aM, aE = toScientific(a)
	local bM, bE = toScientific(b)
	local gap = aE - bE
	if gap > 308 then
		return math.huge
	end
	if gap < -330 then
		return 0
	end
	return (aM / bM) * 10 ^ gap
end

-- Rounds down. Large values (>= 2^53) are already whole numbers at this precision.
function BigNum.floor(value: BigNum): BigNum
	if value.e ~= 0 then
		return value
	end
	local floored = math.floor(value.m)
	if floored == value.m then
		return value
	end
	return make(floored, 0)
end

-- log10 of the value; -math.huge for zero.
function BigNum.log10(value: BigNum): number
	if value.m == 0 then
		return -math.huge
	end
	if value.e == 0 then
		return math.log10(value.m)
	end
	return math.log10(value.m) + value.e
end

-- The value as a plain number. Returns math.huge beyond about 1.8e308; meant for display math only.
function BigNum.toNumber(value: BigNum): number
	if value.e == 0 then
		return value.m
	end
	if value.e > 308 then
		return math.huge
	end
	return value.m * 10 ^ value.e
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------

-- Canonical text used for saving and networking. parse(toString(x)) always equals x.
function BigNum.toString(value: BigNum): string
	if value.e == 0 then
		return string.format("%.17g", value.m)
	end
	return string.format("%.17ge%.0f", value.m, value.e)
end

--[[
	Reads canonical text (and other plain decimal or "<digits>e<exponent>"
	forms). Returns nil for anything malformed, negative, non-finite, longer
	than 64 characters, or with an exponent beyond 2^53 - 1. Never errors.
]]
function BigNum.parse(text: unknown): BigNum?
	if typeof(text) ~= "string" then
		return nil
	end
	if #text == 0 or #text > MAX_TEXT_LENGTH then
		return nil
	end
	local mantissaText, exponentText = string.match(text, "^(%d+%.?%d*)[eE]([%+%-]?%d+)$")
	if mantissaText == nil then
		mantissaText = string.match(text, "^(%d+%.?%d*)$")
		if mantissaText == nil then
			return nil
		end
	end
	local mantissa = tonumber(mantissaText)
	if mantissa == nil or not isFiniteNumber(mantissa) then
		return nil
	end
	local exponent = 0
	if exponentText ~= nil then
		local parsedExponent = tonumber(exponentText)
		if parsedExponent == nil or parsedExponent % 1 ~= 0 or math.abs(parsedExponent) > MAX_EXPONENT then
			return nil
		end
		exponent = parsedExponent
	end
	if mantissa == 0 then
		return ZERO
	end
	-- Anything that fits a double below 2^53 is read in one step, so "1.1e1" is exactly 11.
	local whole = tonumber(text)
	if whole ~= nil and isFiniteNumber(whole) and whole < SMALL_LIMIT then
		return if whole == 0 then ZERO else make(whole, 0)
	end
	-- The normalized exponent can still exceed 2^53 - 1 ("10e9007199254740991"): nil, not an error.
	return tryNormalize(mantissa, exponent)
end

-- Player-facing text: "999", "1.23K", "5.6M" ... "1.2Dc", then "1.23e456".
function BigNum.format(value: BigNum): string
	if value.e == 0 and value.m < 1000 then
		return tostring(math.floor(value.m))
	end
	local mantissa, exponent = toScientific(value)
	local tier = math.floor(exponent / 3)
	if tier < #SUFFIXES then
		local scaled = mantissa * 10 ^ (exponent - tier * 3)
		local text = string.format("%.2f", scaled)
		if (tonumber(text) :: number) >= 1000 then -- rounding reached the next tier (999.995 -> 1000.00)
			tier += 1
			text = string.format("%.2f", scaled / 1000)
		end
		if tier < #SUFFIXES then
			return trimZeros(text) .. SUFFIXES[tier + 1]
		end
	end
	local text = string.format("%.2f", mantissa)
	if text == "10.00" then
		text = "1.00"
		exponent += 1
	end
	return trimZeros(text) .. "e" .. string.format("%.0f", exponent)
end

return table.freeze(BigNum)
