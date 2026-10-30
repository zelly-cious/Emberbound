
-- unit.luau (offline review harness): runs the shipped TestRunner Script unchanged.
-- TestRunner discovers every *Tests ModuleScript in ServerScriptService.Tests and prints the verdict.
local capturedLines = {}
local realPrint = print
print = function(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	table.insert(capturedLines, table.concat(parts, " "))
	realPrint(...)
end

Shim.runScript("ServerScriptService/Tests/TestRunner")

local allPassed = false
for _, line in capturedLines do
	if string.find(line, "[Tests] ALL PASSED", 1, true) then
		allPassed = true
	end
end
if not allPassed then
	error("unit tests did not report ALL PASSED", 0)
end
