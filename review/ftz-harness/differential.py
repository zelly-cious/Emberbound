#!/usr/bin/env python3
"""Differential check for DEFECT-001 and DEFECT-001B (review tooling only).

Runs the same deterministic sequence of BigNum operations through three BigNum versions in one
Lua 5.1 process per floating-point mode (see run_matrix.py for the modes):

    frozen     e9d878d, the approved Milestone 2 source
    prior      8626bc7, the DEFECT-001 candidate (arithmetic fix only)
    candidate  the work tree (arithmetic fix plus the DEFECT-001B canonical-text fix)

and checks that every difference is one of the intended corrections:

    frozen -> prior      an arithmetic result the frozen code flushed to 0 is now the subnormal
                         (multiplyByPowerOfTen, DEFECT-001; FTZ modes only)
    prior -> candidate   toString of a positive subnormal prints Luau's shortest text instead of
                         "%.17g"; parse(toString(x)) of a positive subnormal is x instead of 0 where
                         the formatter printed "0" (DEFECT-001B; formatter-model modes only)

It also checks two invariants of the candidate in every mode: parse(toString(x)) == x and
toString(parse(toString(x))) == toString(x) for every operand, and it lists what still depends on
the floating-point mode (the native small-value fast paths, a documented limitation).

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
PRIOR = "8626bc70ff905975fbc8069b4f951762f15cdefd"
MIN_NORMAL = 2.2250738585072014e-308

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
local F = __rawformat -- display with the real formatter, never the modeled one
local function show(v)
	if type(v) == "table" then
		return F("%.17g|%.0f", v.m, v.e)
	end
	if type(v) == "number" then
		return F("%.17g", v)
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
	{ "toString", function(B, a, b) return B.toString(a) end },
	{ "roundtrip", function(B, a, b) return B.parse(B.toString(a)) end },
	{ "idempotent", function(B, a, b) return B.toString(B.parse(B.toString(a))) == B.toString(a) end },
	{ "format", function(B, a, b) return B.format(a) end },
	{ "log10", function(B, a, b) return B.log10(a) end },
	{ "ratio", function(B, a, b) if B.isZero(b) then return "skip" end return B.ratio(a, b) end },
	{ "fromLog10", function(B, a, b) return B.fromLog10(-340 + rand() * 760) end },
	{ "scaledPower", function(B, a, b) return B.scaledPower(1 + rand() * 9, 0.001 + rand() * 2, math.floor(rand() * 400)) end },
}
for round = 1, 1600 do
	local ta, tb = operand(), operand()
	for _, op in ipairs(OPS) do
		local saved = state
		local results = {}
		for index, B in ipairs({ FROZEN, PRIOR, CANDIDATE }) do
			state = saved
			local ok, value = pcall(function()
				local a, b = B.parse(ta), B.parse(tb)
				if a == nil or b == nil then return "unparsed" end
				return op[2](B, a, b)
			end)
			results[index] = ok and show(value) or ("error")
		end
		print(op[1] .. "\t" .. ta .. "\t" .. tb .. "\t" .. show(CANDIDATE.parse(ta)) .. "\t" .. table.concat(results, "\t"))
	end
end
"""


def operands() -> list[str]:
    """Operand texts made in Python (gradual underflow), so every mode sees identical inputs."""
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
    texts += ["5e-324", "4.9406564584124654e-324", "1e-323", "1e-320", "1e-310", "2.2250738585072009e-308",
              "2.2250738585072014e-308", "1e-300", "1e400", "0"]
    return texts


def is_subnormal(shown: str) -> bool:
    m, _, e = shown.partition("|")
    return e == "0" and 0 < float(m) < MIN_NORMAL


def main() -> int:
    candidate = (run_matrix.REPO / "src/ReplicatedStorage/Shared/BigNum.luau").read_text()
    chunk = "\n".join([
        (HERE / "prelude.lua").read_text(),
        "FROZEN = (function()\n" + luau51.translate(run_matrix.git_show(FROZEN, "src/ReplicatedStorage/Shared/BigNum.luau")) + "\nend)()",
        "PRIOR = (function()\n" + luau51.translate(run_matrix.git_show(PRIOR, "src/ReplicatedStorage/Shared/BigNum.luau")) + "\nend)()",
        "CANDIDATE = (function()\n" + luau51.translate(candidate) + "\nend)()",
        "OPERANDS = {" + ",".join('"' + text + '"' for text in operands()) + "}",
        DRIVER,
    ])
    rows: dict[str, list[list[str]]] = {}
    with tempfile.TemporaryDirectory() as tmp:
        library = run_matrix.ftz_library(Path(tmp))
        path = Path(tmp) / "differential.lua"
        path.write_text(chunk)
        for mode in run_matrix.MODES:
            out = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True, env=run_matrix.mode_env(mode, library), check=True).stdout
            rows[mode] = [line.split("\t") for line in out.splitlines()]
    ok = True
    for mode in run_matrix.MODES:
        total = len(rows[mode])
        classes = collections.Counter()
        other = []
        invariant_failures = []
        for op, ta, tb, a, frozen, prior, cand in rows[mode]:
            # frozen -> prior: DEFECT-001 arithmetic rebuild only
            if frozen != prior:
                if frozen.startswith("0|0") and not prior.startswith("0|") and op not in ("toString", "roundtrip", "idempotent"):
                    classes["frozen->prior: arithmetic 0 -> subnormal (DEFECT-001)"] += 1
                else:
                    other.append(("frozen->prior", op, ta, tb, frozen, prior))
            # prior -> candidate: DEFECT-001B canonical text only
            if prior != cand:
                if op == "toString" and is_subnormal(a):
                    classes["prior->candidate: subnormal text now Luau tostring (DEFECT-001B)"] += 1
                elif op == "roundtrip" and prior.startswith("0|0") and cand == a and is_subnormal(a):
                    classes["prior->candidate: parse(toString(x)) 0 -> x (DEFECT-001B)"] += 1
                else:
                    other.append(("prior->candidate", op, ta, tb, prior, cand))
            # candidate invariants in every mode
            if op == "roundtrip" and cand != a:
                invariant_failures.append((op, ta, a, cand))
            if op == "idempotent" and cand != "true":
                invariant_failures.append((op, ta, a, cand))
        print(f"[{mode:10}] {total} operations; differences by class:")
        for name, count in sorted(classes.items()):
            print(f"      {count:5}  {name}")
        print(f"      {len(other):5}  other differences (must be 0)")
        for r in other[:10]:
            print("         OTHER", r)
        print(f"      candidate parse(toString(x)) == x and idempotent text: {len(invariant_failures)} failures (must be 0)")
        for r in invariant_failures[:10]:
            print("         INVARIANT", r)
        if mode == "gradual" and any(not k.startswith("prior->candidate: subnormal text") for k in classes):
            ok = False
        if other or invariant_failures:
            ok = False
    by_op = collections.Counter()
    zero_only = collections.Counter()
    for g, f in zip(rows["gradual"], rows["ftz-winfmt"]):
        if g[6] != f[6]:
            by_op[g[0]] += 1
            if f[6].startswith("0|0") or f[6] == "0":
                zero_only[g[0]] += 1
    print("[candidate] results that still differ between gradual and ftz-winfmt (native fast paths):")
    for op, count in sorted(by_op.items()):
        print(f"      {op:12} {count:5} ({zero_only[op]} of them become zero under FTZ)")
    if not by_op:
        print("      none")
    print("DIFFERENTIAL", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
