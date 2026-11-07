-- M3 source 23785544f846817c5d722f69d5e81b11348df46f; edit mode, read only.
local E = {
	{ "ReplicatedStorage/Shared/BigNum", "ModuleScript", 17007, 544, 2126309327 },
	{ "ReplicatedStorage/Shared/GameConfig", "ModuleScript", 5838, 153, 2137704413 },
	{ "ReplicatedStorage/Shared/ProgressionConfig", "ModuleScript", 6935, 167, 359691214 },
	{ "ServerScriptService/CombatRules", "ModuleScript", 2920, 91, 833873800 },
	{ "ServerScriptService/CombatService", "ModuleScript", 8719, 263, 1066130401 },
	{ "ServerScriptService/CurrencyService", "ModuleScript", 5702, 165, 2447495618 },
	{ "ServerScriptService/PlayerDataService", "ModuleScript", 12643, 373, 2998784157 },
	{ "ServerScriptService/PlayerSessionService", "ModuleScript", 7672, 223, 962820468 },
	{ "ServerScriptService/ProfileSchema", "ModuleScript", 12189, 346, 1031035281 },
	{ "ServerScriptService/ProfileStore", "ModuleScript", 6800, 194, 286192177 },
	{ "ServerScriptService/ProfileTransactions", "ModuleScript", 4689, 117, 3421469007 },
	{ "ServerScriptService/RateLimiter", "ModuleScript", 1886, 66, 2585428194 },
	{ "ServerScriptService/ServerInit", "Script", 1105, 27, 852134481 },
	{ "ServerScriptService/StatRules", "ModuleScript", 7759, 235, 3881779502 },
	{ "ServerScriptService/StatService", "ModuleScript", 7706, 187, 1444841730 },
	{ "ServerScriptService/Tests/BigNumTests", "ModuleScript", 26869, 671, 1174686409 },
	{ "ServerScriptService/Tests/CombatFormulaTests", "ModuleScript", 3327, 87, 1867459093 },
	{ "ServerScriptService/Tests/CombatRulesTests", "ModuleScript", 4399, 118, 839619764 },
	{ "ServerScriptService/Tests/ProfileSchemaTests", "ModuleScript", 9972, 280, 1411935786 },
	{ "ServerScriptService/Tests/ProfileStoreTests", "ModuleScript", 13769, 372, 2260419114 },
	{ "ServerScriptService/Tests/ProfileTransactionsTests", "ModuleScript", 7455, 168, 919576819 },
	{ "ServerScriptService/Tests/ProgressionTests", "ModuleScript", 4170, 128, 3226287864 },
	{ "ServerScriptService/Tests/RateLimiterTests", "ModuleScript", 2042, 65, 2206831031 },
	{ "ServerScriptService/Tests/StatRulesTests", "ModuleScript", 12309, 264, 3037874736 },
	{ "ServerScriptService/Tests/TestKit", "ModuleScript", 4287, 138, 3224874915 },
	{ "ServerScriptService/Tests/TestKitTests", "ModuleScript", 4545, 151, 991929235 },
	{ "ServerScriptService/Tests/TestRunner", "Script", 1574, 45, 1141053416 },
	{ "ServerScriptService/Tests/WalletTests", "ModuleScript", 8091, 194, 4028171145 },
	{ "ServerScriptService/UpgradeService", "ModuleScript", 10245, 261, 3653372142 },
	{ "ServerScriptService/Wallet", "ModuleScript", 2966, 85, 3038385218 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient", "LocalScript", 10496, 291, 1711349078 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView", "ModuleScript", 15520, 528, 2016899911 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient/CombatHud", "ModuleScript", 13480, 424, 4051264347 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient/UpgradePanel", "ModuleScript", 10325, 358, 3892797615 },
}
local problems = 0
local function bad(text) problems += 1 warn("[Parity] FAIL " .. text) end
local function find(path) local parts = string.split(path, "/") local node = game:GetService(parts[1]) for i = 2, #parts do if node == nil then return nil end node = node:FindFirstChild(parts[i]) end return node end
local function adler(s) local a, b = 1, 0 for i = 1, #s do a = (a + string.byte(s, i)) % 65521 b = (b + a) % 65521 end return b * 65536 + a end
local expected = {}
local matched = 0
for _, e in E do
	local node = find(e[1])
	if node == nil then
		bad(e[1] .. " is missing (check its name and parent)")
	elseif node.ClassName ~= e[2] then
		bad(e[1] .. " is a " .. node.ClassName .. ", it must be a " .. e[2])
	else
		expected[node] = true
		local same = 0
		for _, sibling in node.Parent:GetChildren() do if sibling.Name == node.Name then same += 1 end end
		local text = string.gsub(node.Source, "\r\n", "\n")
		text = string.gsub(text, "%s+$", "") .. "\n"
		local _, lines = string.gsub(text, "\n", "")
		local sum = adler(text)
		if same > 1 then
			bad(e[1] .. " exists " .. same .. " times; keep exactly one")
		elseif #text ~= e[3] or lines ~= e[4] or sum ~= e[5] then
			bad(string.format("%s content differs: %d bytes, %d lines, checksum %d (expected %d, %d, %d)", e[1], #text, lines, sum, e[3], e[4], e[5]))
		elseif node:IsA("BaseScript") and not node.Enabled then
			bad(e[1] .. " is disabled; tick Enabled in Properties")
		elseif node.ClassName == "Script" and node.RunContext == Enum.RunContext.Client then
			bad(e[1] .. " has RunContext = Client; set it to Legacy")
		else
			matched += 1
			print("[Parity] ok   " .. e[1])
		end
	end
end
for _, path in { "ReplicatedStorage/Shared", "ReplicatedStorage/Remotes", "ServerScriptService/Tests" } do local f = find(path) if f == nil or f.ClassName ~= "Folder" then bad(path .. " must be a Folder") end end
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local remoteCount = 0
for _, name in { "RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate" } do
	local r = (if remotes then remotes:FindFirstChild(name) else nil)
	if r == nil or r.ClassName ~= "RemoteEvent" then bad("ReplicatedStorage/Remotes/" .. name .. " must be a RemoteEvent") else remoteCount += 1 end
end
if remotes and #remotes:GetChildren() ~= 6 then bad("ReplicatedStorage/Remotes must hold exactly the 6 RemoteEvents (it has " .. #remotes:GetChildren() .. " children)") end
if game:GetService("Players").CharacterAutoLoads then bad("Players.CharacterAutoLoads must be unticked (false)") end
local extra = 0
for _, serviceName in { "Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" } do
	for _, d in game:GetService(serviceName):GetDescendants() do
		if d:IsA("LuaSourceContainer") and not expected[d] then extra += 1 bad("extra script " .. d:GetFullName() .. " (" .. d.ClassName .. "); delete it unless this guide told you to add it") end
	end
end
print(string.format("[Parity] scripts matching: %d / 34, remotes: %d / 6, extra scripts: %d", matched, remoteCount, extra))
if problems == 0 and matched == 34 then print("[Parity] RESULT: PASS") else warn("[Parity] RESULT: FAIL (" .. problems .. " problem(s) listed above)") end
