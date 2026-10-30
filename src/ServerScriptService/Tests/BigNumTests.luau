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
}

return {
	name = "BigNumTests",
	tests = tests,
}
