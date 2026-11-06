
-- unit.luau (offline review harness): runs the shipped TestRunner Script unchanged.
-- TestRunner discovers every *Tests ModuleScript in ServerScriptService.Tests and prints the verdict.
-- The harness does not trust that verdict alone (Codex audit F3): Shim.checkTestRun also requires
-- every expected suite to report, and no failure line anywhere.
local lines = Shim.captureScript("ServerScriptService/Tests/TestRunner")
for _, line in lines do
	print(line)
end

local expected = Shim.expectedSuites()
local ok, problems = Shim.checkTestRun(lines, expected)
if not ok then
	error("unit tests did not pass:\n  " .. table.concat(problems, "\n  "), 0)
end
print(`[Harness] verified: {#expected} suites reported, no failures`)
