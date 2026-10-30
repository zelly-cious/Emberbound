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

function TestKit.expectNear(actual: number, expected: number, tolerance: number, label: string?)
	if math.abs(actual - expected) > tolerance then
		error(`{label or "expectNear"}: expected {expected} ± {tolerance}, got {actual}`, 2)
	end
end

function TestKit.expectError(callback: () -> (), label: string?)
	local ok = pcall(callback)
	if ok then
		error(`{label or "expectError"}: expected an error, but none was raised`, 2)
	end
end

-- Runs every test in every suite, prints one line per suite and a final verdict.
function TestKit.runSuites(suites: { Suite }): (number, number)
	local passed, failed = 0, 0
	for _, suite in suites do
		local suitePassed, suiteFailed = 0, 0
		for _, test in suite.tests do
			local ok, problem = pcall(test.run)
			if ok then
				suitePassed += 1
			else
				suiteFailed += 1
				warn(`[Tests] FAIL {suite.name} > {test.name}: {problem}`)
			end
		end
		print(`[Tests] {suite.name}: {suitePassed} passed, {suiteFailed} failed`)
		passed += suitePassed
		failed += suiteFailed
	end
	if failed == 0 then
		print(`[Tests] ALL PASSED ({passed} tests)`)
	else
		warn(`[Tests] {failed} of {passed + failed} tests FAILED`)
	end
	return passed, failed
end

return table.freeze(TestKit)
