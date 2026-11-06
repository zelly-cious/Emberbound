local P = "[DEFECT-001 probe v2]"
-- v2: numbers are displayed with tostring (Luau's shortest round-trip text, which Studio keeps for subnormals);
-- v1 displayed them with string.format("%.17g"), which Studio prints as "0" for subnormals (DEFECT-001B).
local function f(x) return tostring(x) end
local function g17(x) local ok, text = pcall(string.format, "%.17g", x) return ok and text or ("error: " .. tostring(text)) end
local function say(...) local parts = {} for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end print(P .. " " .. table.concat(parts, " ")) end
local okVersion, robloxVersion = pcall(function() return version() end)
local okLp, localPlayer = pcall(function() return game:FindService("Players").LocalPlayer end)
local okRun, running = pcall(function() return game:FindService("RunService"):IsRunning() end)
say("engine", _VERSION, "roblox", okVersion and robloxVersion or "n/a", "context", (okLp and localPlayer ~= nil) and "client" or "server-or-edit", "running", okRun and tostring(running) or "n/a")
local box = { 5e-324, 2.2250738585072014e-308, 1e-300, 1e-10, 1, 2, 1e300, 10, -24, 4.9406564584124659, -324 }
local tiny, minNormal = box[1], box[2]
local t1 = tiny * box[5]
local half = minNormal / box[6]
local mixed = box[3] * box[4]
say("mode tiny>0", tostring(tiny > 0), "tiny*1", f(t1), "minNormal/2", f(half), "1e-300*1e-10", f(mixed))
say("mode verdict", (t1 == 0 and half == 0) and "FLUSH-TO-ZERO (subnormal results become 0)" or ((t1 > 0 and half > 0) and "GRADUAL UNDERFLOW" or "MIXED"), "| inputs", (tiny > 0) and "subnormal inputs kept (no DAZ)" or "subnormal inputs read as 0 (DAZ)")
say("formatter %.17g(tiny)=" .. g17(tiny), "tostring(tiny)=" .. tostring(tiny), "| verdict", (g17(tiny) == "0") and "FORMATTER PRINTS SUBNORMALS AS 0" or "formatter keeps subnormals")
local texts = { "4.9406564584124659e-324", "4.9406564584124654e-324", "5e-324", "3e-324", "2e-324", "1e-324", "1e-320", "1e-310", "2.2250738585072009e-308", "2.2250738585072014e-308", "1e-400" }
for _, text in ipairs(texts) do local v = tonumber(text) say("tonumber", text, "->", f(v), "==5e-324", tostring(v == tiny)) end
local rebuilt = tonumber(string.format("%.17ge%d", box[10], box[11]))
say("candidate rebuild tonumber(string.format('%.17ge%d', 4.9406564584124659, -324)) ->", f(rebuilt), "==5e-324", tostring(rebuilt == tiny))
local mant = tiny * box[7] / box[8] ^ box[9]
local step = mant * box[8] ^ box[9]
say("arithmetic mantissa", f(mant), "m*10^-24", f(step), "*1e-300", f(step * box[3]))
local okPack, packed = pcall(function() return string.unpack("<d", string.pack("<I8", 1)) end)
say("string.pack/unpack bit rebuild", okPack and f(packed) or ("unavailable: " .. tostring(packed)))
-- IEEE-754 bit patterns -> doubles without arithmetic (the BigNumTests fixtures use buffer the same way)
local okBuffer = pcall(function() return buffer.readf64(buffer.create(8), 0) end)
local function fromBits(high, low) local b = buffer.create(8) buffer.writeu32(b, 0, low) buffer.writeu32(b, 4, high) return buffer.readf64(b, 0) end
say("buffer bit rebuild", okBuffer and ("available, bits 0x1 -> " .. f(fromBits(0, 1)) .. " ==5e-324 " .. tostring(fromBits(0, 1) == tiny)) or "unavailable")
local okB, B = pcall(function() return require(game:FindService("ReplicatedStorage"):FindFirstChild("Shared"):FindFirstChild("BigNum")) end)
if not okB or type(B) ~= "table" then say("BigNum not loaded:", tostring(B)) return end
local function fields(label, v) say("fields", label, "m=" .. f(v and v.m), "e=" .. f(v and v.e), "valid=" .. tostring(v ~= nil and B.isValid(v)), "zero=" .. tostring(v ~= nil and v.m == 0)) end
local n = B.fromNumber(tiny)
local product = B.mul(n, B.parse("1e400"))
local q = B.div(product, B.parse("1e400"))
fields("tiny", n)
fields("product", product)
fields("quotient", q)
say("line 364 eq(div(product, 1e400), tiny)", tostring(B.eq(q, n)))
local function check(label, fn) local ok, result = pcall(fn) say("line", label, ok and tostring(result) or ("error: " .. tostring(result))) end
check("365 log10(1/tiny)", function() return f(B.log10(B.div(B.fromNumber(1), n))) end)
check("366-372 log10(minNormal*1e400)", function() return f(B.log10(B.mul(B.fromNumber(minNormal), B.parse("1e400")))) end)
check("373 add(tiny,1e400)", function() return B.toString(B.add(n, B.parse("1e400"))) end)
check("374 parse(toString(tiny)) == tiny", function() local text = B.toString(n) local back = B.parse(text) return string.format("%q", text) .. " -> " .. (back and f(back.m) or "nil") .. " eq=" .. tostring(back ~= nil and B.eq(back, n)) end)
check("375 lt(tiny, 1e-300)", function() return B.lt(n, B.fromNumber(1e-300)) end)
fields("fast add(tiny,tiny)", B.add(n, n))
fields("fast mul(1e-200,1e-120)", B.mul(B.fromNumber(1e-200), B.fromNumber(1e-120)))
fields("fast div(1e-300,1e10)", B.div(B.fromNumber(1e-300), B.fromNumber(1e10)))
fields("fast sub(minNormal,2.2250738585072009e-308)", B.sub(B.fromNumber(minNormal), B.fromNumber(2.2250738585072009e-308)))
fields("fast fromLog10(-320)", B.fromLog10(-320))
fields("sci div(5e-30,1e294)", B.div(B.parse("5e-30"), B.parse("1e294")))
fields("sci div(1e-30,1e294) true underflow", B.div(B.parse("1e-30"), B.parse("1e294")))
-- DEFECT-001B: canonical text. "module" is the installed BigNum.toString; "candidate" is the corrected
-- toString evaluated inline (positive subnormals use tostring), read back with the installed BigNum.parse.
local function candidateText(v) if v.e == 0 then local m = v.m if m > 0 and m < minNormal then return tostring(m) end return string.format("%.17g", m) end return string.format("%.17ge%.0f", v.m, v.e) end
local function serialization(label, x)
	local ok, result = pcall(function()
		local v = B.fromNumber(x)
		local moduleText = B.toString(v)
		local moduleBack = B.parse(moduleText)
		local text = candidateText(v)
		local back = B.parse(text)
		return string.format("%%.17g=%q tostring=%q tonumber(tostring)==x %s | module %q eq=%s | candidate %q eq=%s idempotent=%s",
			g17(x), tostring(x), tostring(tonumber(tostring(x)) == x), moduleText, tostring(moduleBack ~= nil and B.eq(moduleBack, v)),
			text, tostring(back ~= nil and B.eq(back, v)), tostring(back ~= nil and candidateText(back) == text))
	end)
	say("text", label, ok and result or ("error: " .. tostring(result)))
end
if okBuffer then
	serialization("bits 0x1 smallest", fromBits(0, 1))
	serialization("bits 0x2 next", fromBits(0, 2))
	serialization("bits 0x7E8 1e-320", fromBits(0, 0x7E8))
	serialization("bits 0x000012688B70E62B 1e-310", fromBits(0x1268, 0x8B70E62B))
	serialization("bits 0x000FFFFFFFFFFFFF largest subnormal", fromBits(0xFFFFF, 0xFFFFFFFF))
	serialization("bits 0x0010000000000000 smallest normal", fromBits(0x100000, 0))
else
	serialization("literal 5e-324 smallest", tiny)
	serialization("literal 2.2250738585072014e-308 smallest normal", minNormal)
end
serialization("1e-307 normal", 1e-307)
serialization("1e-300 normal", box[3])
serialization("0.1", 0.1)
serialization("0", 0)
say("done")
