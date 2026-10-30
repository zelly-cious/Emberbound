--!strict
--[[
	TestKitTests
	Location: ServerScriptService > Tests > TestKitTests (ModuleScript)

	Tests for the test kit itself, from the Milestone 2 Codex audit: an
	approximate assertion must never pass on NaN (F6), and a suite that fails to
	load, or a run with no tests, must never be reported as ALL PASSED (F3).
	Suites run here use a quiet reporter, so they print nothing.
]]

local TestKit = require(script.Parent:WaitForChild("TestKit"))

local expectEqual = TestKit.expectEqual
local expectTrue = TestKit.expectTrue
local expectError = TestKit.expectError
local expectNear = TestKit.expectNear

local NAN = 0 / 0

-- Runs suites without printing and returns (passed, failed, every reported line).
local function runQuietly(suites: { TestKit.Suite }, loadFailures: { string }?): (number, number, { string })
	local lines: { string } = {}
	local passed, failed = TestKit.runSuites(suites, loadFailures, function(_isProblem: boolean, message: string)
		table.insert(lines, message)
	end)
	return passed, failed, lines
end

local function reportedAllPassed(lines: { string }): boolean
	for _, line in lines do
		if string.find(line, "ALL PASSED", 1, true) then
			return true
		end
	end
	return false
end

local passingSuite: TestKit.Suite = {
	name = "PassingTests",
	tests = {
		{ name = "passes", run = function() end },
	},
}

local tests: { TestKit.TestCase } = {
	{
		name = "expectNear accepts values within the tolerance",
		run = function()
			expectNear(1, 1.05, 0.1)
			expectNear(5, 5, 0)
			expectNear(-2, -2.5, 0.5)
			expectNear(math.huge, math.huge, 0, "equal infinities")
		end,
	},
	{
		name = "expectNear never passes on NaN",
		run = function()
			expectError(function()
				expectNear(NAN, 123, 0)
			end, "NaN actual")
			expectError(function()
				expectNear(123, NAN, 0)
			end, "NaN expected")
			expectError(function()
				expectNear(NAN, NAN, 1)
			end, "both NaN")
			expectError(function()
				expectNear(math.huge, -math.huge, 1)
			end, "opposite infinities (their difference is NaN)")
			expectError(function()
				expectNear(math.huge, 5, 1e300)
			end, "infinity is not near a finite value")
			expectError(function()
				expectNear(5, 7, 1)
			end, "plain mismatch")
		end,
	},
	{
		name = "expectNear rejects invalid tolerances",
		run = function()
			expectError(function()
				expectNear(1, 1, NAN)
			end, "NaN tolerance")
			expectError(function()
				expectNear(1, 1, -1)
			end, "negative tolerance")
			expectError(function()
				expectNear(1, 2, math.huge)
			end, "infinite tolerance")
		end,
	},
	{
		name = "a suite that failed to load is a failure, never ALL PASSED",
		run = function()
			local passed, failed, lines = runQuietly({ passingSuite }, { "BrokenTests: boom" })
			expectEqual(passed, 1, "the loaded suite still runs")
			expectEqual(failed, 1, "the load failure is counted")
			expectTrue(not reportedAllPassed(lines), "no ALL PASSED line")
		end,
	},
	{
		name = "a run with no tests is a failure",
		run = function()
			local passed, failed, lines = runQuietly({})
			expectEqual(passed, 0)
			expectEqual(failed, 1, "an empty run fails")
			expectTrue(not reportedAllPassed(lines), "no ALL PASSED line for an empty run")
			local _, emptySuiteFailed = runQuietly({ { name = "EmptyTests", tests = {} } })
			expectEqual(emptySuiteFailed, 1, "a suite with no tests also fails")
		end,
	},
	{
		name = "failing tests are counted and reported",
		run = function()
			local failing: TestKit.Suite = {
				name = "FailingTests",
				tests = {
					{
						name = "fails",
						run = function()
							error("expected failure")
						end,
					},
				},
			}
			local passed, failed, lines = runQuietly({ passingSuite, failing })
			expectEqual(passed, 1)
			expectEqual(failed, 1)
			expectTrue(not reportedAllPassed(lines), "no ALL PASSED line")
			local _, _, cleanLines = runQuietly({ passingSuite })
			expectTrue(reportedAllPassed(cleanLines), "a clean run still reports ALL PASSED")
		end,
	},
	{
		name = "isSuite rejects modules that do not return a suite",
		run = function()
			expectTrue(TestKit.isSuite(passingSuite), "a real suite")
			expectTrue(not TestKit.isSuite(42), "a number")
			expectTrue(not TestKit.isSuite(nil), "nil")
			expectTrue(not TestKit.isSuite({}), "an empty table")
			expectTrue(not TestKit.isSuite({ name = "X", tests = { { name = "no run function" } } }), "a test without run")
			expectTrue(not TestKit.isSuite({ name = "X", tests = "not a list" }), "tests is not a table")
		end,
	},
}

return {
	name = "TestKitTests",
	tests = tests,
}
