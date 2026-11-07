--!strict
--[[
	BigNumTests
	Location: ServerScriptService > Tests > BigNumTests (ModuleScript)

	Deterministic BigNum unit tests. Exact-string expectations use values whose
	mantissas are exact in binary (1.5, 3, 7.25 ...) so results cannot vary by
	platform; everything else is checked by comparison or round trip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

type BigNum = BigNum.BigNum

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectNil = TestKit.expectNil
local expectError = TestKit.expectError
local expectNear = TestKit.expectNear

local TWO_POW_53 = 9007199254740992

local function n(value: number): BigNum
	return BigNum.fromNumber(value)
end

local function p(text: string): BigNum
	local value = BigNum.parse(text)
	if value == nil then
		error(`test setup: could not parse "{text}"`, 2)
	end
	return value
end

local function s(value: BigNum): string
	return BigNum.toString(value)
end

local tests: { TestKit.TestCase } = {
	{
		name = "small values keep their exact double",
		run = function()
			expectEqual(s(n(0)), "0")
			expectEqual(s(n(13)), "13")
			expectEqual(s(n(TWO_POW_53 - 1)), "9007199254740991")
			expectEqual(n(13).e, 0, "13 stays in the small regime")
			expectEqual(n(13).m, 13, "13 is stored exactly")
		end,
	},
	{
		name = "fromNumber rejects NaN, infinity and negatives",
		run = function()
			expectError(function()
				n(0 / 0)
			end, "NaN")
			expectError(function()
				n(math.huge)
			end, "+infinity")
			expectError(function()
				n(-math.huge)
			end, "-infinity")
			expectError(function()
				n(-1)
			end, "negative")
			expectEqual(s(n(-0)), "0", "negative zero becomes zero")
		end,
	},
	{
		name = "addition is exact below 2^53 and switches regime above",
		run = function()
			expectEqual(s(BigNum.add(n(9), n(1))), "10")
			expectEqual(s(BigNum.add(n(TWO_POW_53 - 2), n(1))), "9007199254740991")
			local crossed = BigNum.add(n(TWO_POW_53 - 1), n(1))
			expectEqual(crossed.e, 15, "2^53 is stored in the large regime")
			expectTrue(BigNum.gt(crossed, n(TWO_POW_53 - 1)), "2^53 > 2^53 - 1")
			expectEqual(s(BigNum.add(p("1.5e400"), p("1.5e400"))), "3e400")
		end,
	},
	{
		name = "subtraction saturates at zero and stays exact below 2^53",
		run = function()
			expectTrue(BigNum.isZero(BigNum.sub(n(5), n(7))), "5 - 7 saturates to 0")
			local hp = n(11)
			for remaining = 10, 0, -1 do
				hp = BigNum.sub(hp, n(1))
				expectEqual(s(hp), tostring(remaining), "HP countdown")
			end
			expectTrue(BigNum.isZero(hp), "HP reaches exactly zero")
			expectEqual(s(BigNum.sub(p("1.5e400"), p("5e399"))), "1e400")
		end,
	},
	{
		name = "trySub refuses to go below zero",
		run = function()
			expectNil(BigNum.trySub(n(3), n(5)), "3 - 5")
			local equal = BigNum.trySub(n(5), n(5))
			expectTrue(equal ~= nil and BigNum.isZero(equal), "5 - 5 is zero")
			local smaller = BigNum.trySub(n(5), n(3))
			expectTrue(smaller ~= nil and s(smaller) == "2", "5 - 3 is 2")
		end,
	},
	{
		name = "multiplication and division",
		run = function()
			expectEqual(s(BigNum.mul(n(6), n(7))), "42")
			expectEqual(s(BigNum.mul(n(1e10), n(1e10))), "1e20")
			expectEqual(s(BigNum.mul(p("3e200"), p("5e200"))), "1.5e401")
			expectEqual(s(BigNum.mulNumber(p("1.5e400"), 2)), "3e400")
			expectTrue(BigNum.isZero(BigNum.mul(n(0), p("1.5e400"))), "anything times zero is zero")
			expectEqual(s(BigNum.div(n(42), n(6))), "7")
			expectEqual(s(BigNum.div(p("3e400"), p("1.5e200"))), "2e200")
			expectError(function()
				BigNum.div(n(1), BigNum.zero)
			end, "division by zero")
		end,
	},
	{
		name = "values beyond 10^308 stay finite and ordered",
		run = function()
			local big = p("1.5e400")
			expectTrue(BigNum.isValid(big), "valid")
			expectEqual(s(big), "1.5e400")
			expectTrue(BigNum.gt(big, p("1e308")), "1.5e400 > 1e308")
			expectEqual(BigNum.toNumber(big), math.huge, "toNumber saturates at infinity")
			expectNear(BigNum.log10(big), 400 + math.log10(1.5), 1e-9, "log10")
		end,
	},
	{
		name = "a much smaller operand does not change a large value",
		run = function()
			expectEqual(s(BigNum.add(p("1.5e400"), n(1))), "1.5e400")
			expectEqual(s(BigNum.sub(p("1.5e400"), n(1))), "1.5e400")
			expectEqual(s(BigNum.add(n(1), p("1.5e400"))), "1.5e400")
		end,
	},
	{
		name = "comparison works across both regimes",
		run = function()
			local justBelow = n(TWO_POW_53 - 1)
			local justAbove = BigNum.add(justBelow, n(1))
			expectEqual(BigNum.compare(justBelow, justAbove), -1)
			expectEqual(BigNum.compare(justAbove, justBelow), 1)
			expectEqual(BigNum.compare(n(13), p("13")), 0)
			expectEqual(BigNum.compare(p("2e400"), p("3e399")), 1)
			expectEqual(BigNum.compare(BigNum.zero, n(0)), 0)
			expectTrue(BigNum.lte(n(5), n(5)) and BigNum.gte(n(5), n(5)), "lte and gte on equal values")
			expectTrue(BigNum.lt(n(4), n(5)) and not BigNum.lt(n(5), n(4)), "lt")
			expectEqual(s(BigNum.max(n(3), p("1e20"))), "1e20")
			expectEqual(s(BigNum.min(n(3), p("1e20"))), "3")
		end,
	},
	{
		name = "canonical strings round-trip exactly",
		run = function()
			local texts = { "0", "1", "13", "999", "1000000000000000", "9007199254740991", "0.5", "0.25", "2e16", "1.5e400", "7.25e1000" }
			for _, text in texts do
				expectEqual(s(p(text)), text, "round trip")
			end
			-- Seeded, so the same 200 values are checked on every run.
			local rng = Random.new(20261031)
			for _ = 1, 200 do
				local mantissa = 1 + rng:NextInteger(0, 899999) / 100000
				local exponent = rng:NextInteger(16, 100000)
				local value = p(string.format("%.5fe%d", mantissa, exponent))
				local again = p(s(value))
				expectTrue(BigNum.eq(value, again), `round trip of {s(value)}`)
			end
		end,
	},
	{
		name = "decimal text with an exponent is read exactly",
		run = function()
			expectEqual(s(p("1.1e1")), "11")
			expectEqual(s(p("25e-1")), "2.5")
			expectEqual(s(p("007")), "7")
		end,
	},
	{
		name = "parse rejects malformed and non-finite input",
		run = function()
			local bad = { "", " 1", "1 ", "-1", "+1", "abc", "1e", "e5", ".5", "1..2", "inf", "nan", "0x10", "1e9007199254740993", "1e99999999999999999999", string.rep("1", 65) }
			for _, text in bad do
				expectNil(BigNum.parse(text), `parse("{text}")`)
			end
			expectNil(BigNum.parse(12), "number input")
			expectNil(BigNum.parse(nil), "nil input")
			expectNil(BigNum.parse({}), "table input")
			expectNil(BigNum.parse(true), "boolean input")
		end,
	},
	{
		name = "isValid rejects malformed tables",
		run = function()
			expectTrue(BigNum.isValid(n(13)), "13")
			expectTrue(BigNum.isValid(p("1.5e16")), "1.5e16")
			expectTrue(not BigNum.isValid({ m = 0 / 0, e = 0 }), "NaN mantissa")
			expectTrue(not BigNum.isValid({ m = math.huge, e = 0 }), "infinite mantissa")
			expectTrue(not BigNum.isValid({ m = -1, e = 0 }), "negative")
			expectTrue(not BigNum.isValid({ m = 11, e = 20 }), "mantissa >= 10")
			expectTrue(not BigNum.isValid({ m = 5, e = 15 }), "large form for a small value")
			expectTrue(not BigNum.isValid({ m = 1.5, e = 20.5 }), "fractional exponent")
			expectTrue(not BigNum.isValid({ m = TWO_POW_53, e = 0 }), "small form at 2^53")
			expectTrue(not BigNum.isValid({ m = "1", e = 0 }), "string mantissa")
			expectTrue(not BigNum.isValid("13"), "string")
			expectTrue(not BigNum.isValid(nil), "nil")
		end,
	},
	{
		name = "floor",
		run = function()
			expectEqual(s(BigNum.floor(n(12.7))), "12")
			expectEqual(s(BigNum.floor(n(0.5))), "0")
			expectEqual(s(BigNum.floor(p("1.5e400"))), "1.5e400")
		end,
	},
	{
		name = "ratio for health bars",
		run = function()
			expectEqual(BigNum.ratio(n(5), n(10)), 0.5)
			expectEqual(BigNum.ratio(p("1.5e400"), p("3e400")), 0.5)
			expectEqual(BigNum.ratio(BigNum.zero, n(7)), 0)
			expectEqual(BigNum.ratio(n(1), p("1e500")), 0)
			expectError(function()
				BigNum.ratio(n(1), BigNum.zero)
			end, "ratio by zero")
		end,
	},
	{
		name = "format matches Milestone 1 style and continues past Dc",
		run = function()
			expectEqual(BigNum.format(n(999)), "999")
			expectEqual(BigNum.format(n(12.9)), "12")
			expectEqual(BigNum.format(n(1234)), "1.23K")
			expectEqual(BigNum.format(n(5600000)), "5.6M")
			expectEqual(BigNum.format(n(999999)), "1M")
			expectEqual(BigNum.format(p("1e33")), "1Dc")
			expectEqual(BigNum.format(p("1.5e400")), "1.5e400")
		end,
	},
	{
		name = "scaledPower equals the plain-double formula in the small range",
		run = function()
			for steps = 0, 200 do
				local expected = 5 * 1.07 ^ steps
				expectTrue(BigNum.eq(BigNum.scaledPower(5, 1.07, steps), n(expected)), `5 * 1.07^{steps}`)
			end
		end,
	},
	{
		name = "scaledPower uses log space instead of overflowing",
		run = function()
			local previous = BigNum.scaledPower(10, 1.18, 4990)
			for steps = 4991, 5010 do
				local value = BigNum.scaledPower(10, 1.18, steps)
				expectTrue(BigNum.isValid(value), `valid at {steps}`)
				expectTrue(BigNum.gt(value, previous), `increasing at {steps}`)
				previous = value
			end
			local value = BigNum.scaledPower(10, 1.18, 5000)
			expectTrue(value.e > 308, "beyond a double's range")
			expectNear(BigNum.log10(value), 1 + 5000 * math.log10(1.18), 1e-6, "log10 of 10 * 1.18^5000")
		end,
	},
	{
		name = "fromLog10",
		run = function()
			expectEqual(s(BigNum.fromLog10(2)), "100")
			local value = BigNum.fromLog10(400.5)
			expectEqual(value.e, 400)
			expectNear(value.m, math.sqrt(10), 1e-9, "mantissa of 10^400.5")
		end,
	},
	{
		name = "overflow raises an error instead of producing infinity",
		run = function()
			local huge = p("1e9000000000000000")
			expectError(function()
				BigNum.mul(huge, huge)
			end, "exponent overflow")
		end,
	},
	{
		name = "values are immutable",
		run = function()
			local value: any = n(5)
			expectError(function()
				value.m = 6
			end, "writing to a frozen BigNum")
		end,
	},
	-- Regression tests for the Milestone 2 Codex audit findings (F1, F2, F4).
	{
		name = "subtraction that returns below 2^53 is exact",
		run = function()
			-- F1: scientific form made 2^53 - (2^53 - 1) come out as 1.7763568394002502.
			local twoPow53 = n(TWO_POW_53)
			expectEqual(twoPow53.e, 15, "2^53 is stored in the large regime")
			expectEqual(s(BigNum.sub(twoPow53, n(TWO_POW_53 - 1))), "1", "2^53 - (2^53 - 1)")
			for distance = 1, 64 do
				local difference = BigNum.sub(twoPow53, n(TWO_POW_53 - distance))
				expectEqual(s(difference), tostring(distance), `2^53 - (2^53 - {distance})`)
				expectEqual(difference.e, 0, "the result is back in the exact small regime")
			end
			expectEqual(s(BigNum.sub(twoPow53, n(1))), "9007199254740991", "2^53 - 1")
			-- 2^53 + 2000 is a whole double above 2^53, so coming back below it must be exact.
			local above = BigNum.add(n(TWO_POW_53 - 1000), n(3000))
			expectEqual(s(BigNum.sub(above, n(2500))), "9007199254740492")
			expectEqual(s(BigNum.sub(above, n(TWO_POW_53 - 1000))), "3000")
			-- Two large operands whose difference is small give a whole number, not 3000000000000000.5.
			expectEqual(s(BigNum.sub(p("1.5e16"), p("1.2e16"))), "3000000000000000")
			expectEqual(s(BigNum.sub(p("1.0000000000000002e22"), p("1e22"))), "2097152")
		end,
	},
	{
		name = "subtraction with large results",
		run = function()
			expectEqual(s(BigNum.sub(p("3e16"), p("1e16"))), "2e16")
			expectEqual(s(BigNum.sub(p("1e20"), n(5))), "1e20")
			expectEqual(s(BigNum.sub(p("2e400"), p("5e399"))), "1.5e400")
			expectTrue(BigNum.isZero(BigNum.sub(n(TWO_POW_53), n(TWO_POW_53))), "equal values give zero")
			-- Below 10^16 the result is the correctly rounded double, for every pair (seeded).
			local rng = Random.new(53)
			for _ = 1, 200 do
				local a = TWO_POW_53 + 2 * rng:NextInteger(0, 400000000) * 1000000
				local b = rng:NextInteger(0, 1000000)
				expectEqual(BigNum.toNumber(BigNum.sub(n(a), n(b))), a - b, `{a} - {b}`)
			end
		end,
	},
	{
		name = "parse returns nil instead of overflowing during normalization",
		run = function()
			-- F2: these raised "BigNum overflow" from inside parse.
			local overflowing = {
				"10e9007199254740991",
				"100e9007199254740990",
				"99.5e9007199254740991",
				string.rep("9", 40) .. "e9007199254740980",
			}
			for _, text in overflowing do
				local ok, result = pcall(BigNum.parse, text)
				expectTrue(ok, `parse("{text}") must not raise an error`)
				expectNil(result, `parse("{text}")`)
			end
			-- The largest representable exponent still parses, however the text writes it.
			local top = p("1000e9007199254740988")
			expectEqual(top.e, 9007199254740991, "1000e(2^53 - 4) normalizes to exponent 2^53 - 1")
			expectEqual(s(top), "1e9007199254740991")
			expectEqual(p("99e9007199254740990").e, 9007199254740991)
			expectEqual(p("9.99e9007199254740991").e, 9007199254740991)
		end,
	},
	{
		name = "the smallest positive doubles work in arithmetic",
		run = function()
			-- F4: subnormal values made toScientific divide by an underflowed 10^-324.
			local tiny = n(5e-324) -- the smallest positive double
			local product = BigNum.mul(tiny, p("1e400"))
			expectTrue(BigNum.isValid(product), "5e-324 * 1e400 is valid")
			expectNear(BigNum.log10(product), math.log10(5e-324) + 400, 1e-9, "5e-324 * 1e400")
			expectTrue(BigNum.eq(BigNum.div(product, p("1e400")), tiny), "dividing back gives 5e-324, not zero")
			expectNear(BigNum.log10(BigNum.div(n(1), tiny)), -math.log10(5e-324), 1e-9, "1 / 5e-324")
			local smallestNormal = n(2.2250738585072014e-308)
			expectNear(
				BigNum.log10(BigNum.mul(smallestNormal, p("1e400"))),
				math.log10(2.2250738585072014e-308) + 400,
				1e-9,
				"2.2250738585072014e-308 * 1e400"
			)
			expectEqual(s(BigNum.add(tiny, p("1e400"))), "1e400")
			expectTrue(BigNum.eq(p(s(tiny)), tiny), "5e-324 round-trips through text")
			expectTrue(BigNum.lt(tiny, n(1e-300)), "ordered")
		end,
	},
}

--[[
	Candidate regression tests for DEFECT-001 (arithmetic) and DEFECT-001B (canonical text).
	They are appended after the original list so the original assertions keep their line numbers
	(BigNumTests.luau:364 and :374 above), and each is its own test, so an arithmetic failure
	cannot hide a serialization failure.

	Roblox Studio runs with flush-to-zero: subnormal arithmetic results become 0 (subnormal
	inputs are kept), and its string.format printed "0" for 5e-324 with "%.17g". The subnormal
	fixtures are therefore built from IEEE-754 bit patterns, not computed. Expected values hold in
	both floating-point modes (checked offline with FTZ on and off, and with the Studio formatter
	behaviour modeled).
]]

type DivisionCase = {
	dividend: string,
	divisor: string,
	expected: number,
}

type UnderflowCase = {
	dividend: string,
	divisor: string,
}

type SerializationFixture = {
	label: string,
	value: BigNum,
	subnormal: boolean,
}

local MIN_NORMAL = 2.2250738585072014e-308 -- smallest positive normal double

-- The binary64 value with this IEEE-754 bit pattern (high and low 32-bit words). Only bytes are
-- copied, with no floating-point arithmetic, so a flush-to-zero host cannot alter the value.
local function fromBits(high: number, low: number): number
	local bytes = buffer.create(8)
	buffer.writeu32(bytes, 0, low)
	buffer.writeu32(bytes, 4, high)
	return buffer.readf64(bytes, 0)
end

local SMALLEST_SUBNORMAL = fromBits(0x00000000, 0x00000001) -- 4.9406564584124654e-324
local NEXT_SUBNORMAL = fromBits(0x00000000, 0x00000002) -- 9.8813129168249309e-324
local SUBNORMAL_1E_320 = fromBits(0x00000000, 0x000007E8) -- nearest double to 1e-320
local SUBNORMAL_1E_310 = fromBits(0x00001268, 0x8B70E62B) -- nearest double to 1e-310
local LARGEST_SUBNORMAL = fromBits(0x000FFFFF, 0xFFFFFFFF) -- 2.2250738585072009e-308
local SMALLEST_NORMAL = fromBits(0x00100000, 0x00000000) -- 2.2250738585072014e-308

local function serializationFixtures(): { SerializationFixture }
	return {
		{ label = "smallest positive double (bits 0x1)", value = n(SMALLEST_SUBNORMAL), subnormal = true },
		{ label = "next subnormal (bits 0x2)", value = n(NEXT_SUBNORMAL), subnormal = true },
		{ label = "1e-320 (bits 0x7E8)", value = n(SUBNORMAL_1E_320), subnormal = true },
		{ label = "1e-310 (bits 0x000012688B70E62B)", value = n(SUBNORMAL_1E_310), subnormal = true },
		{ label = "largest subnormal (bits 0x000FFFFFFFFFFFFF)", value = n(LARGEST_SUBNORMAL), subnormal = true },
		{ label = "smallest normal (bits 0x0010000000000000)", value = n(SMALLEST_NORMAL), subnormal = false },
		{ label = "zero", value = BigNum.zero, subnormal = false },
		{ label = "zero from bits", value = n(fromBits(0, 0)), subnormal = false },
		{ label = "1e-300", value = n(1e-300), subnormal = false },
		{ label = "0.1", value = n(0.1), subnormal = false },
		{ label = "0.5", value = n(0.5), subnormal = false },
		{ label = "1", value = n(1), subnormal = false },
		{ label = "13", value = n(13), subnormal = false },
		{ label = "123456.789", value = n(123456.789), subnormal = false },
		{ label = "1e15", value = n(1e15), subnormal = false },
		{ label = "2^53 - 1", value = n(TWO_POW_53 - 1), subnormal = false },
		{ label = "2^53 (first large value)", value = n(TWO_POW_53), subnormal = false },
		{ label = "1e16", value = p("1e16"), subnormal = false },
		{ label = "largest double", value = n(fromBits(0x7FEFFFFF, 0xFFFFFFFF)), subnormal = false },
		{ label = "1.5e400", value = p("1.5e400"), subnormal = false },
		{ label = "7.25e1000", value = p("7.25e1000"), subnormal = false },
		{ label = "1e9007199254740991 (largest exponent)", value = p("1e9007199254740991"), subnormal = false },
	}
end

table.insert(tests, {
	name = "subnormal results rebuilt from scientific form are not flushed to zero",
	run = function()
		local cases: { DivisionCase } = {
			{ dividend = "5e-30", divisor = "1e294", expected = 5e-324 }, -- the smallest positive double
			{ dividend = "3e-30", divisor = "1e294", expected = 5e-324 }, -- rounds up to it
			{ dividend = "1e-29", divisor = "1e294", expected = 1e-323 }, -- twice the smallest positive double
			{ dividend = "1e-26", divisor = "1e294", expected = 1e-320 },
			{ dividend = "1.5e-23", divisor = "1e294", expected = 1.5e-317 },
			{ dividend = "1e-16", divisor = "1e294", expected = 1e-310 },
			{ dividend = "1.1125369292536007e-14", divisor = "1e294", expected = 1.1125369292536007e-308 }, -- half the smallest normal
			{ dividend = "1.5", divisor = "1e310", expected = 1.5e-310 },
			{ dividend = "3", divisor = "1e310", expected = 3e-310 },
		}
		for _, case in cases do
			local value = BigNum.div(p(case.dividend), p(case.divisor))
			expectTrue(BigNum.isValid(value) and not BigNum.isZero(value), `{case.dividend} / {case.divisor} is a positive BigNum`)
			expectTrue(BigNum.eq(value, n(case.expected)), `{case.dividend} / {case.divisor} equals {case.expected}`)
		end
	end,
})

table.insert(tests, {
	name = "the normal boundary and genuine underflow are unchanged",
	run = function()
		local smallestNormal = n(2.2250738585072014e-308)
		expectTrue(BigNum.eq(BigNum.div(p("2.2250738585072014e-14"), p("1e294")), smallestNormal), "smallest normal")
		-- Just below it, the floating-point mode decides the last step (bounded precision contract):
		-- the result is the largest subnormal or the smallest normal, and never zero.
		local largestSubnormal = BigNum.div(p("2.2250738585072009e-14"), p("1e294"))
		expectTrue(
			BigNum.eq(largestSubnormal, n(2.2250738585072009e-308)) or BigNum.eq(largestSubnormal, smallestNormal),
			"largest subnormal stays within one step"
		)
		-- Below half of 5e-324 the exact result rounds to zero in every mode.
		local underflows: { UnderflowCase } = {
			{ dividend = "1e-30", divisor = "1e294" },
			{ dividend = "2e-30", divisor = "1e294" },
			{ dividend = "2.4e-30", divisor = "1e294" },
			{ dividend = "5", divisor = "1e330" },
			{ dividend = "1e-30", divisor = "1e400" },
		}
		for _, case in underflows do
			local value = BigNum.div(p(case.dividend), p(case.divisor))
			expectTrue(BigNum.isZero(value) and BigNum.eq(value, BigNum.zero), `{case.dividend} / {case.divisor} underflows to zero`)
		end
	end,
})

table.insert(tests, {
	name = "subnormal fixtures built from IEEE-754 bits are the intended doubles",
	run = function()
		-- A host that reads subnormal inputs as zero (DAZ) fails here, before any serialization check.
		local ordered = { SMALLEST_SUBNORMAL, NEXT_SUBNORMAL, SUBNORMAL_1E_320, SUBNORMAL_1E_310, LARGEST_SUBNORMAL }
		for index, value in ordered do
			expectTrue(value > 0 and value < MIN_NORMAL, `subnormal fixture {index} is positive and below the smallest normal`)
			if index > 1 then
				expectTrue(value > ordered[index - 1], `subnormal fixture {index} is larger than fixture {index - 1}`)
			end
		end
		expectTrue(SMALLEST_NORMAL == MIN_NORMAL, "bits 0x0010000000000000 are the smallest normal")
		expectTrue(fromBits(0x3FF00000, 0) == 1, "bits 0x3FF0000000000000 are 1")
		expectTrue(fromBits(0, 0) == 0, "bits 0 are zero")
	end,
})

table.insert(tests, {
	name = "canonical text round-trips exactly for subnormal, boundary, ordinary and large values",
	run = function()
		-- DEFECT-001B: Studio printed the smallest positive double as "0", so it read back as zero.
		for _, fixture in serializationFixtures() do
			if fixture.subnormal then
				expectTrue(not BigNum.isZero(fixture.value), `{fixture.label}: the fixture BigNum is not zero`)
			end
			local text = s(fixture.value)
			local back = BigNum.parse(text)
			expectTrue(back ~= nil, `{fixture.label}: parse("{text}") returns a BigNum`)
			local parsed = back :: BigNum
			expectTrue(BigNum.isValid(parsed), `{fixture.label}: parse("{text}") is valid`)
			expectTrue(BigNum.eq(parsed, fixture.value), `{fixture.label}: parse(toString(x)) equals x (text "{text}")`)
			expectEqual(s(parsed), text, `{fixture.label}: toString(parse(toString(x))) is unchanged`)
		end
	end,
})

table.insert(tests, {
	name = "canonical text of zero, normal and large values keeps its existing form",
	run = function()
		expectEqual(s(BigNum.zero), "0")
		expectEqual(s(n(0.5)), "0.5")
		expectEqual(s(n(13)), "13")
		expectEqual(s(n(TWO_POW_53 - 1)), "9007199254740991")
		expectEqual(s(p("1.5e400")), "1.5e400")
		expectEqual(s(p("7.25e1000")), "7.25e1000")
		expectEqual(s(p("1e9007199254740991")), "1e9007199254740991")
		-- Every non-subnormal value still uses the "%.17g" text, the smallest normal included.
		for _, fixture in serializationFixtures() do
			if not fixture.subnormal then
				local value = fixture.value
				local expected = if value.e == 0
					then string.format("%.17g", value.m)
					else string.format("%.17ge%.0f", value.m, value.e)
				expectEqual(s(value), expected, `{fixture.label}: canonical text`)
			end
		end
	end,
})

table.insert(tests, {
	name = "text below half the smallest positive double still reads as zero",
	run = function()
		for _, text in { "2e-324", "2.4e-324", "1e-330", "1e-400" } do
			local value = p(text)
			expectTrue(BigNum.isZero(value) and BigNum.eq(value, BigNum.zero), `"{text}" reads as zero`)
			expectEqual(s(value), "0", `"{text}" prints as zero`)
		end
		expectTrue(BigNum.eq(p("3e-324"), n(SMALLEST_SUBNORMAL)), `"3e-324" rounds up to the smallest positive double`)
	end,
})

table.insert(tests, {
	name = "parse rejects out-of-range decimals that would round into range (R2-1)",
	run = function()
		-- Each of these is at least 10^(2^53), above the largest BigNum; the first one used to
		-- parse as 9.9999999999999982e9007199254740991 and pass isValid.
		local outOfRange = {
			"1" .. string.rep("0", 23) .. "e9007199254740969",
			"0001" .. string.rep("0", 23) .. "e9007199254740969",
			"1" .. string.rep("0", 23) .. ".000e9007199254740969",
			"1" .. string.rep("0", 23) .. "E+9007199254740969",
			"1" .. string.rep("0", 40) .. "e9007199254740952",
			"10.0000000000000000001e9007199254740991",
		}
		for _, text in outOfRange do
			local ok, result = pcall(BigNum.parse, text)
			expectTrue(ok, `parse("{text}") must not raise an error`)
			expectNil(result, `parse("{text}")`)
		end
		-- One decade lower is in range and still accepted, at the top exponent.
		local inRange = {
			"1" .. string.rep("0", 22) .. "e9007199254740969",
			string.rep("9", 23) .. "e9007199254740969",
			string.rep("0", 24) .. "1e9007199254740991",
			"0.1e9007199254740991",
			"10e9007199254740990",
		}
		local expectedExponents = { 9007199254740991, 9007199254740991, 9007199254740991, 9007199254740990, 9007199254740991 }
		for index, text in inRange do
			local value = BigNum.parse(text)
			expectTrue(value ~= nil and BigNum.isValid(value), `parse("{text}") is a valid BigNum`)
			expectEqual((value :: BigNum).e, expectedExponents[index], `exponent of "{text}"`)
		end
	end,
})

table.insert(tests, {
	name = "parse accepts only decimals below 10^(2^53), at every mantissa length (seeded)",
	run = function()
		-- The digits as written decide the range: a value whose first digit sits at decimal
		-- exponent 2^53 - 1 or below may round past the top and read as nil, but a value at or
		-- above 10^(2^53) never parses, and anything a full decade below the top always does.
		local rng = Random.new(2021)
		for _ = 1, 300 do
			local digits = rng:NextInteger(1, 40)
			local text = tostring(rng:NextInteger(1, 9))
			if rng:NextInteger(1, 3) == 1 then
				-- Exact powers of ten: 10^23 and others round down as doubles, which is the R2-1 case.
				text = "1" .. string.rep("0", digits - 1)
			else
				for _ = 2, digits do
					text ..= tostring(rng:NextInteger(0, 9))
				end
			end
			-- The exponent is 2^53 - 1 - leading + top, written as text so that no large number is
			-- formatted: 2^53 - 1 = 9007199254740991 and every exponent here is 90071992547409xx.
			local leading = digits - 1
			local top = rng:NextInteger(-2, 2)
			local written = `{text}e90071992547409{91 - leading + top}`
			local value = BigNum.parse(written)
			if top > 0 then
				expectNil(value, `parse("{written}") is above the range`)
			elseif top < 0 then
				expectTrue(value ~= nil and BigNum.isValid(value), `parse("{written}") is in range`)
			else
				expectTrue(value == nil or BigNum.isValid(value), `parse("{written}") is nil or valid`)
			end
		end
	end,
})

table.insert(tests, {
	name = "canonical text round-trips at every scale up to the top exponent",
	run = function()
		local values = {
			BigNum.zero,
			BigNum.one,
			n(TWO_POW_53 - 1),
			n(TWO_POW_53),
			p("1.5e16"),
			p("7.25e300"),
			p("3e9007199254740990"),
			p("9.99e9007199254740991"),
			p("1e9007199254740991"),
		}
		for _, value in values do
			local text = s(value)
			local again = BigNum.parse(text)
			expectTrue(again ~= nil and BigNum.eq(again, value), `"{text}" reads back as the same value`)
			expectEqual(s(again :: BigNum), text, `"{text}" prints the same after a round trip`)
		end
	end,
})

return {
	name = "BigNumTests",
	tests = tests,
}
