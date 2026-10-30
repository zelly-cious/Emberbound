--!strict
--[[
	TestKit
	Location: ServerScriptService > Tests > TestKit (ModuleScript)

	Minimal assertions and a runner for deterministic unit tests. No external
	framework. Each test module returns a Suite; TestRunner runs them in Studio.
]]

export type TestCase = {
	name: string,
	run: () -> (),
}

export type Suite = {
	name: string,
	tests: { TestCase },
}

local TestKit = {}

local function describe(value: unknown): string
	if typeof(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

function TestKit.expectEqual(actual: unknown, expected: unknown, label: string?)
	if actual ~= expected then
		error(`{label or "expectEqual"}: expected {describe(expected)}, got {describe(actual)}`, 2)
	end
end

function TestKit.expectTrue(condition: boolean, label: string?)
	if not condition then
		error(`{label or "expectTrue"}: condition was false`, 2)
	end
end

function TestKit.expectNil(value: unknown, label: string?)
	if value ~= nil then
		error(`{label or "expectNil"}: expected nil, got {describe(value)}`, 2)
	end
end

-- NaN never passes, and the tolerance must be a finite number >= 0. Equal infinities pass.
function TestKit.expectNear(actual: number, expected: number, tolerance: number, label: string?)
	local name = label or "expectNear"
	if typeof(tolerance) ~= "number" or tolerance ~= tolerance or tolerance < 0 or tolerance == math.huge then
		error(`{name}: invalid tolerance {tolerance}`, 2)
	end
	if typeof(actual) ~= "number" or typeof(expected) ~= "number" or actual ~= actual or expected ~= expected then
		error(`{name}: expected {expected} ± {tolerance}, got {actual} (NaN or not a number)`, 2)
	end
	-- Written so that NaN (from opposite infinities) fails the check instead of slipping through.
	if actual ~= expected and not (math.abs(actual - expected) <= tolerance) then
		error(`{name}: expected {expected} ± {tolerance}, got {actual}`, 2)
	end
end

function TestKit.expectError(callback: () -> (), label: string?)
	local ok = pcall(callback)
	if ok then
		error(`{label or "expectError"}: expected an error, but none was raised`, 2)
	end
end

-- True for a value shaped like a Suite. TestRunner uses it to reject test modules that return anything else.
function TestKit.isSuite(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local suite: any = value
	if typeof(suite.name) ~= "string" or typeof(suite.tests) ~= "table" then
		return false
	end
	for _, test in suite.tests do
		if typeof(test) ~= "table" or typeof(test.name) ~= "string" or typeof(test.run) ~= "function" then
			return false
		end
	end
	return true
end

-- Receives each output line; problem lines go to warn. Tests pass their own to run suites quietly.
export type Reporter = (isProblem: boolean, message: string) -> ()

local function defaultReporter(isProblem: boolean, message: string)
	if isProblem then
		warn(message)
	else
		print(message)
	end
end

--[[
	Runs every test in every suite, prints one line per suite and a final verdict.
	Each entry in loadFailures (a test module that could not be loaded) counts as a
	failure, and a run with no tests at all fails, so a broken or missing suite can
	never produce "ALL PASSED". Returns (passed, failed).
]]
function TestKit.runSuites(suites: { Suite }, loadFailures: { string }?, reporter: Reporter?): (number, number)
	local report = reporter or defaultReporter
	local failures: { string } = loadFailures or {}
	local passed, failed = 0, 0
	for _, problem in failures do
		failed += 1
		report(true, `[Tests] FAIL could not load {problem}`)
	end
	for _, suite in suites do
		local suitePassed, suiteFailed = 0, 0
		for _, test in suite.tests do
			local ok, problem = pcall(test.run)
			if ok then
				suitePassed += 1
			else
				suiteFailed += 1
				report(true, `[Tests] FAIL {suite.name} > {test.name}: {problem}`)
			end
		end
		report(false, `[Tests] {suite.name}: {suitePassed} passed, {suiteFailed} failed`)
		passed += suitePassed
		failed += suiteFailed
	end
	if passed + failed == 0 then
		failed = 1
		report(true, "[Tests] FAIL no tests ran")
	end
	if failed == 0 then
		report(false, `[Tests] ALL PASSED ({passed} tests)`)
	else
		report(true, `[Tests] {failed} FAILED, {passed} passed`)
	end
	return passed, failed
end

return table.freeze(TestKit)
