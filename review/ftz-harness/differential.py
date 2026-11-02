#!/usr/bin/env python3
"""Differential check for DEFECT-001 (review tooling only).

Runs the same deterministic sequence of BigNum operations through the frozen BigNum
(e9d878d) and the candidate BigNum (work tree) in one Lua 5.1 process, once with gradual
underflow and once with FTZ (FTZ on, DAZ off), and reports:

  1. frozen vs candidate in each mode: every difference must be a frozen zero that the
     candidate rebuilds as a non-zero subnormal (FTZ only); gradual mode must be identical;
  2. candidate gradual vs candidate FTZ: what still depends on the floating-point mode after
     the fix, grouped by operation (the native small-value fast paths).

    python3 review/ftz-harness/differential.py
"""

from __future__ import annotations

import collections
import random
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import luau51  # noqa: E402
import run_matrix  # noqa: E402

FROZEN = "e9d878d94155610558c9c6252d76f202dfd956b4"

DRIVER = r"""
local state = 20261102
local function rand()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
local function operand()
	local index = math.floor(rand() * #OPERANDS) + 1
	return OPERANDS[index]
end
local function show(B, v)
	if type(v) == "table" then
		return string.format("%.17g|%.0f", v.m, v.e)
	end
	if type(v) == "number" then
		return string.format("%.17g", v)
	end
	return tostring(v)
end
local OPS = {
	{ "add", function(B, a, b) return B.add(a, b) end },
	{ "sub", function(B, a, b) return B.sub(a, b) end },
	{ "mul", function(B, a, b) return B.mul(a, b) end },
	{ "div", function(B, a, b) return B.div(a, b) end },
	{ "trySub", function(B, a, b) return B.trySub(a, b) end },
	{ "compare", function(B, a, b) return B.compare(a, b) end },
	{ "floor", function(B, a, b) return B.floor(a) end },
	{ "roundtrip", function(B, a, b) return B.parse(B.toString(a)) end },
	{ "format", function(B, a, b) return B.format(a) end },
	{ "log10", function(B, a, b) return B.log10(a) end },
	{ "ratio", function(B, a, b) if B.isZero(b) then return "skip" end return B.ratio(a, b) end },
	{ "fromLog10", function(B, a, b) return B.fromLog10(-340 + rand() * 760) end },
	{ "scaledPower", function(B, a, b) return B.scaledPower(1 + rand() * 9, 0.001 + rand() * 2, math.floor(rand() * 400)) end },
}
local count = 0
for round = 1, 1600 do
	local ta, tb = operand(), operand()
	for _, op in ipairs(OPS) do
		local saved = state
		local results = {}
		for index, B in ipairs({ FROZEN, CANDIDATE }) do
			state = saved
			local ok, value = pcall(function()
				local a, b = B.parse(ta), B.parse(tb)
				if a == nil or b == nil then return "unparsed" end
				return op[2](B, a, b)
			end)
			results[index] = ok and show(B, value) or ("error")
		end
		count = count + 1
		print(op[1] .. "\t" .. ta .. "\t" .. tb .. "\t" .. results[1] .. "\t" .. results[2])
	end
end
"""


def operands() -> list[str]:
    """Operand texts made in Python (gradual underflow), so both modes see identical inputs."""
    rng = random.Random(20261102)
    texts = []
    for _ in range(4000):
        kind = rng.randrange(6)
        if kind == 0:
            texts.append("%.17g" % (10 ** rng.uniform(-323.3, -307.65)))  # subnormal
        elif kind == 1:
            texts.append("%.17g" % (10 ** rng.uniform(-308, -8)))  # tiny normal
        elif kind == 2:
            texts.append(str(rng.randrange(1_000_000)))  # ordinary integers
        elif kind == 3:
            texts.append("%.17g" % rng.uniform(0, 1000))  # ordinary fractions
        elif kind == 4:
            texts.append(str(9007199254740992 - rng.randrange(4096)))  # around 2^53
        else:
            texts.append("%.6fe%d" % (rng.uniform(1, 9.999), rng.randrange(16, 616)))  # large
    texts += ["5e-324", "4.9406564584124654e-324", "2.2250738585072009e-308", "2.2250738585072014e-308", "1e-300", "1e400", "0"]
    return texts


def main() -> int:
    frozen = run_matrix.git_show(FROZEN, "src/ReplicatedStorage/Shared/BigNum.luau")
    candidate = (run_matrix.REPO / "src/ReplicatedStorage/Shared/BigNum.luau").read_text()
    chunk = "\n".join([
        (HERE / "prelude.lua").read_text(),
        "FROZEN = (function()\n" + luau51.translate(frozen) + "\nend)()",
        "CANDIDATE = (function()\n" + luau51.translate(candidate) + "\nend)()",
        "OPERANDS = {" + ",".join('"' + text + '"' for text in operands()) + "}",
        DRIVER,
    ])
    rows = {}
    with tempfile.TemporaryDirectory() as tmp:
        library = run_matrix.ftz_library(Path(tmp))
        path = Path(tmp) / "differential.lua"
        path.write_text(chunk)
        for mode in ("gradual", "ftz"):
            env = {"PATH": "/usr/bin:/bin"}
            if mode == "ftz":
                env["LD_PRELOAD"] = str(library)
            out = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True, env=env, check=True).stdout
            rows[mode] = [line.split("\t") for line in out.splitlines()]
    ok = True
    for mode in ("gradual", "ftz"):
        total = len(rows[mode])
        diffs = [r for r in rows[mode] if r[3] != r[4]]
        rebuilt = [r for r in diffs if r[3].startswith("0|0") and not r[4].startswith("0|")]
        other = [r for r in diffs if r not in rebuilt]
        print(f"[{mode}] frozen vs candidate: {total} operations, {total - len(diffs)} identical, "
              f"{len(rebuilt)} frozen zero -> candidate subnormal, {len(other)} other differences")
        for r in other[:10]:
            print("    OTHER", r)
        if mode == "gradual" and diffs:
            ok = False
        if other:
            ok = False
    by_op = collections.Counter()
    zero_only = collections.Counter()
    for g, f in zip(rows["gradual"], rows["ftz"]):
        if g[4] != f[4]:
            by_op[g[0]] += 1
            if f[4].startswith("0|0") or f[4] == "0":
                zero_only[g[0]] += 1
    print("[candidate] results that still depend on the floating-point mode (gradual vs FTZ):")
    for op, count in sorted(by_op.items()):
        print(f"    {op:12} {count:5} ({zero_only[op]} of them become zero under FTZ)")
    if not by_op:
        print("    none")
    print("DIFFERENTIAL", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
