--!strict
--[[
	RateLimiterTests
	Location: ServerScriptService > Tests > RateLimiterTests (ModuleScript)

	Token bucket behavior with an injected clock, so results never depend on timing.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectTrue = TestKit.expectTrue

local tests: { TestKit.TestCase } = {
	{
		name = "allows a burst, then refills at the configured rate",
		run = function()
			local now = 0
			local limiter = RateLimiter.new(3, 2, function()
				return now
			end)
			expectTrue(limiter:allow("a") and limiter:allow("a") and limiter:allow("a"), "burst of 3")
			expectTrue(not limiter:allow("a"), "4th request in the same instant is refused")
			now = 0.5 -- 0.5 s x 2 per second = 1 token
			expectTrue(limiter:allow("a"), "one token after 0.5 s")
			expectTrue(not limiter:allow("a"), "and only one")
			now = 100 -- refill caps at capacity
			expectTrue(limiter:allow("a") and limiter:allow("a") and limiter:allow("a"), "back to a full burst")
			expectTrue(not limiter:allow("a"), "never more than capacity")
		end,
	},
	{
		name = "keys are independent and can be forgotten",
		run = function()
			local now = 0
			local limiter = RateLimiter.new(1, 1, function()
				return now
			end)
			expectTrue(limiter:allow("a"), "a's first request")
			expectTrue(not limiter:allow("a"), "a is limited")
			expectTrue(limiter:allow("b"), "b is not affected by a")
			limiter:remove("a")
			expectTrue(limiter:allow("a"), "a starts fresh after remove")
		end,
	},
	{
		name = "a clock that goes backwards never grants extra tokens",
		run = function()
			local now = 10
			local limiter = RateLimiter.new(1, 1, function()
				return now
			end)
			expectTrue(limiter:allow("a"), "first request")
			now = 5
			expectTrue(not limiter:allow("a"), "no refill from negative elapsed time")
		end,
	},
}

return {
	name = "RateLimiterTests",
	tests = tests,
}
