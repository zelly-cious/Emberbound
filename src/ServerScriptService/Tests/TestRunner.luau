--!strict
--[[
	TestRunner
	Location: ServerScriptService > Tests > TestRunner (Script)

	Runs every ModuleScript in this folder whose name ends in "Tests" when you
	press Play in Studio. Never runs in live game servers. Results appear in the
	Output window: one line per suite, then "ALL PASSED" or the failures.
	Set RUN_TESTS_IN_STUDIO to false to skip them.
]]

local RunService = game:GetService("RunService")

local TestKit = require(script.Parent:WaitForChild("TestKit"))

local RUN_TESTS_IN_STUDIO = true

if RUN_TESTS_IN_STUDIO and RunService:IsStudio() then
	local testModules: { ModuleScript } = {}
	for _, child in script.Parent:GetChildren() do
		if child:IsA("ModuleScript") and string.match(child.Name, "Tests$") then
			table.insert(testModules, child)
		end
	end
	table.sort(testModules, function(a: ModuleScript, b: ModuleScript)
		return a.Name < b.Name
	end)

	local suites: { TestKit.Suite } = {}
	for _, moduleScript in testModules do
		local ok, suiteOrError = pcall(require, moduleScript)
		if ok then
			table.insert(suites, suiteOrError :: TestKit.Suite)
		else
			warn(`[Tests] Could not load {moduleScript.Name}: {suiteOrError}`)
		end
	end

	TestKit.runSuites(suites)
end
