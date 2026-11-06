#!/usr/bin/env python3
"""Milestone 2.1 StatService offline checks (review tooling only; not Roblox Studio).

    python3 review/m2.1/run_checks.py

1. The shipped TestRunner (all suites, including StatRulesTests) and the 75 historical review
   probes on the working tree, in gradual and FTZ + modeled-formatter modes.
2. StatService integration probes (statservice_probes.luau) against the fake engine.
3. Client-traffic differential: client_traffic_scenario.luau on `main` (merged M2 Round 4,
   2279623) and on the working tree. Every message every client receives must be identical.
4. StatRules mutation controls: StatRulesTests must FAIL against deliberately wrong combination
   rules (compounded percentages, rounding at every step, no minimum, same-id stacking).

Uses review/ftz-harness (Luau translated to Lua 5.1) and review/offline-harness/roblox_shim.luau.
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "review" / "ftz-harness"))
import luau51  # noqa: E402
import run_matrix  # noqa: E402

MAIN = "227962341facb26ddc6eb074ca7e49018dfc7acb"
PREVIOUS = "2771db13aaec1bd6884daa32656c37f70f0157c4"  # PR #3 head before the failure-path fix
STAT_RULES = "ServerScriptService/StatRules"
results: list[tuple[bool, str]] = []


def record(ok: bool, name: str, detail: str = "") -> None:
    results.append((ok, name))
    print(("PASS " if ok else "FAIL ") + name + (f"\n      {detail}" if detail and not ok else ""))


def bundle(source: str, entry_text: str, replace: dict[str, str] | None = None) -> str:
    """prelude + sources (git ref or 'worktree', optionally with replaced texts) + shim + entry, all translated."""
    parts = [(REPO / "review/ftz-harness/prelude.lua").read_text(), run_matrix.MODE_CHECK, "local SOURCES = {}"]
    texts = run_matrix.sources(source)
    texts.update(replace or {})
    # The same detached baselines run_matrix.bundle adds (the historical probes compare against them).
    texts["M1/ReplicatedStorage/Shared/GameConfig"] = run_matrix.git_show(run_matrix.M1_BASELINE, "src/ReplicatedStorage/Shared/GameConfig.luau")
    texts["AUDITED/ReplicatedStorage/Shared/BigNum"] = run_matrix.git_show(run_matrix.AUDITED, "src/ReplicatedStorage/Shared/BigNum.luau")
    # The temporary Studio QA bridge, kept out of the tree (key outside any service); the probes add it as a Script.
    texts["QA/EmberboundStatQA"] = (HERE / "EmberboundStatQA.server.luau").read_text()
    for key, text in texts.items():
        translated = luau51.translate(text)
        assert "]==========]" not in translated
        parts.append(f'SOURCES["{key}"] = [==========[\n{translated}]==========]')
    parts.append(luau51.translate((REPO / "review/offline-harness/roblox_shim.luau").read_text()))
    parts.append(luau51.translate(entry_text))
    return "\n".join(parts) + "\n"


def run(chunk: str, mode: str, workdir: Path, library: Path) -> tuple[int, str]:
    path = workdir / "chunk.lua"
    path.write_text(chunk)
    proc = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True, env=run_matrix.mode_env(mode, library))
    return proc.returncode, proc.stdout + proc.stderr


def unit_entry() -> str:
    return (REPO / "review/offline-harness/unit.luau").read_text()


MUTATIONS = {
    "percentages compounded instead of summed": (
        "percentTotal = BigNum.add(percentTotal, BigNum.fromNumber(modifier.percent))",
        "total = BigNum.mul(total, BigNum.fromNumber(1 + modifier.percent))",
    ),
    "rounded after every step": (
        "factor = BigNum.mulNumber(factor, modifier.multiplier)",
        "factor = BigNum.mulNumber(factor, modifier.multiplier)\n\t\t\t\t\ttotal = BigNum.floor(BigNum.mul(BigNum.floor(total), BigNum.fromNumber(1 + (modifier.percent or 0))))",
    ),
    "no minimum tap damage": (
        "return BigNum.max(BigNum.floor(total), minimum)",
        "return BigNum.floor(total)",
    ),
    "same id stacks instead of replacing": (
        "entries[modifierId] = copy",
        "entries[modifierId .. tostring(os.clock()) .. tostring(math.random())] = copy",
    ),
    "modifier stored by reference": (
        "table.freeze(copy :: any)\n\treturn copy",
        "return modifier :: any",
    ),
}


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        library = run_matrix.ftz_library(workdir)
        probes_entry = run_matrix.git_show("HEAD", "review/offline-harness/probes.luau")

        # 1. Shipped unit tests and historical probes.
        for mode in ("gradual", "ftz-winfmt"):
            code, out = run(bundle("worktree", unit_entry()), mode, workdir, library)
            verdict = re.findall(r"\[Tests\] (ALL PASSED \(\d+ tests\)|\d+ FAILED, \d+ passed)", out)
            suites = re.findall(r"^\[Tests\] (\w+Tests): (\d+) passed, 0 failed$", out, re.M)
            record(code == 0 and verdict[-1:] == ["ALL PASSED (82 tests)"] and len(suites) == 8,
                   f"[{mode}] TestRunner: {verdict[-1] if verdict else 'no verdict'} in {len(suites)} suites "
                   f"({', '.join(f'{s} {c}' for s, c in suites)})", out[-800:])
            code, out = run(bundle("worktree", probes_entry), mode, workdir, library)
            totals = re.findall(r"\[Probes\] total: (\d+) passed, (\d+) failed", out)
            record(code == 0 and totals[-1:] == [("75", "0")], f"[{mode}] historical review probes: "
                   + (f"{totals[-1][0]} passed, {totals[-1][1]} failed" if totals else "no total"), out[-800:])

        # 2. StatService integration probes.
        code, out = run(bundle("worktree", (HERE / "statservice_probes.luau").read_text()), "gradual", workdir, library)
        print("\n".join(line for line in out.splitlines() if line.startswith(("  PASS", "  FAIL"))))
        summary = re.findall(r"\[StatService probes\] (\d+) passed, (\d+) failed", out)
        record(code == 0 and summary[-1:] != [] and summary[-1][1] == "0",
               f"StatService integration probes: {summary[-1][0] + ' passed, ' + summary[-1][1] + ' failed' if summary else 'no summary'}",
               out[-800:])

        # 2b. Negative control: the same probes against the previous PR head (2771db1), which left a failed
        #     modifier installed and charged for an upgrade whose tap damage was not applied.
        code, out = run(bundle(PREVIOUS, (HERE / "statservice_probes.luau").read_text()), "gradual", workdir, library)
        old_fails = [line.strip()[5:] for line in out.splitlines() if line.startswith("  FAIL")]
        record(code != 0 and len(old_fails) >= 2,
               f"control: the probes fail on the previous PR head {PREVIOUS[:7]} ({len(old_fails)} failures, the reported defect)",
               out[-600:])
        for line in old_fails:
            print(f"      {PREVIOUS[:7]}: FAIL {line[:150]}")

        # 2c. Static check: the purchase path stays non-yielding.
        yielding = re.compile(r"task\.wait|task\.delay|task\.defer|\bwait\(|\bdelay\(|coroutine\.yield|:Wait\(|Async\(")
        hits = []
        for rel in ("src/ServerScriptService/StatService.luau", "src/ServerScriptService/StatRules.luau", "src/ServerScriptService/UpgradeService.luau"):
            for number, line in enumerate((REPO / rel).read_text().splitlines(), 1):
                if yielding.search(line):
                    hits.append(f"{rel}:{number}")
        record(not hits, "StatService, StatRules and UpgradeService contain no yielding call (purchase stays one non-yielding step)", ", ".join(hits))

        # 3. Client-traffic differential: main vs working tree.
        scenario = (HERE / "client_traffic_scenario.luau").read_text()
        outputs = {}
        for label, source in (("main", MAIN), ("M2.1", "worktree")):
            code, out = run(bundle(source, scenario), "gradual", workdir, library)
            lines = [line for line in out.splitlines() if not line.startswith("[Mode]")]
            outputs[label] = (code, lines)
        (code_a, main_lines), (code_b, branch_lines) = outputs["main"], outputs["M2.1"]
        messages = sum(1 for line in main_lines if re.match(r"^\d+ ", line))
        first_diff = next((i for i, (a, b) in enumerate(zip(main_lines, branch_lines)) if a != b), None)
        record(code_a == 0 and code_b == 0 and main_lines == branch_lines and messages > 100,
               f"client traffic identical on main ({MAIN[:7]}) and M2.1: {messages} messages to 3 clients, "
               f"{len(main_lines) - messages} summary lines",
               f"exit {code_a}/{code_b}; first difference at line {first_diff}: "
               + (f"{main_lines[first_diff]!r} vs {branch_lines[first_diff]!r}" if first_diff is not None else "length differs"))
        # Control: a deliberate +1 in the no-modifier path must change the traffic, so the comparison is not vacuous.
        stat_rules_text = (REPO / "src" / (STAT_RULES + ".luau")).read_text()
        plus_one = stat_rules_text.replace("return BigNum.max(BigNum.floor(base), minimum) -- no modifiers",
                                           "return BigNum.add(BigNum.max(BigNum.floor(base), minimum), BigNum.one) -- no modifiers", 1)
        code_c, out_c = run(bundle("worktree", scenario, {STAT_RULES: plus_one}), "gradual", workdir, library)
        control_lines = [line for line in out_c.splitlines() if not line.startswith("[Mode]")]
        differing = sum(1 for a, b in zip(main_lines, control_lines) if a != b)
        record(plus_one != stat_rules_text and code_c == 0 and differing > 0,
               f"control: a +1 tap damage change in StatRules makes the traffic differ ({differing} lines differ)")
        (workdir / "traffic_main.txt").write_text("\n".join(main_lines))
        print("  traffic summary:", next((l for l in main_lines if l.startswith("[traffic] handler")), "none"))

        # 4. Mutation controls for StatRules.
        stat_rules = (REPO / "src" / (STAT_RULES + ".luau")).read_text()
        for label, (old, new) in MUTATIONS.items():
            if stat_rules.count(old) != 1:
                record(False, f"mutation '{label}' could not be applied", old)
                continue
            mutated = stat_rules.replace(old, new)
            code, out = run(bundle("worktree", unit_entry(), {STAT_RULES: mutated}), "gradual", workdir, library)
            stat_line = re.findall(r"^\[Tests\] StatRulesTests: (\d+) passed, (\d+) failed$", out, re.M)
            record(code != 0 and stat_line != [] and int(stat_line[-1][1]) > 0,
                   f"mutation control '{label}': StatRulesTests "
                   + (f"{stat_line[-1][0]} passed, {stat_line[-1][1]} failed" if stat_line else "did not report"), out[-500:])

    failed = sum(1 for ok, _ in results if not ok)
    print(f"[M2.1 checks] {len(results) - failed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
