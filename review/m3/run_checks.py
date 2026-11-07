#!/usr/bin/env python3
"""Milestone 3 persistence checks (review tooling only; nothing here runs Roblox Studio).

    python3 review/m3/run_checks.py

Runs, with review/ftz-harness (Luau translated to Lua 5.1) and the fake engine in
review/offline-harness/roblox_shim.luau:
  0. the M2.1 check set (review/m2.1/run_checks.py) at this branch's test totals
  1. the shipped TestRunner suites and the 75 historical probes (gradual and ftz-winfmt)
  2. the M2.1 StatService integration probes
  3. the persistence probes (review/m3/persistence_probes.luau, live-server path on a fake DataStore)
  4. the unpublished-Studio path (in-memory saves for one test session)
  5. client traffic for first-time players: main vs working tree, byte for byte
  6. static check: the gameplay services and pure modules never yield
  7. mutation controls: each deliberate persistence defect must make the checks fail
"""

from __future__ import annotations

import importlib.util
import re
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
_spec = importlib.util.spec_from_file_location("m21_checks", REPO / "review/m2.1/run_checks.py")
m21 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m21)
run_matrix = m21.run_matrix

MAIN = "227962341facb26ddc6eb074ca7e49018dfc7acb"
EXPECTED_TESTS = 106
EXPECTED_SUITES = 10
results: list[bool] = []

STUDIO_ENTRY = r"""
Shim.runScript("ServerScriptService/ServerInit")
local CurrencyService = Shim.require("ServerScriptService/CurrencyService")
local CombatService = Shim.require("ServerScriptService/CombatService")
local BigNum = Shim.require("ReplicatedStorage/Shared/BigNum")
local a = Shim.addPlayer("Alice", 1)
Shim.advanceClock(5)
Shim.fireServer("ClientReady", a)
for _ = 1, 25 do
	Shim.advanceClock(0.2)
	Shim.fireServer("RequestAttack", a)
end
local goldText = BigNum.toString(CurrencyService.GetBalance(a, "Gold"))
local stage = CombatService.GetStage(a)
Shim.removePlayer(a)
local b = Shim.addPlayer("Alice", 1)
local restored = BigNum.toString(CurrencyService.GetBalance(b, "Gold")) == goldText and CombatService.GetStage(b) == stage
print(`[studio] gold={goldText} stage={stage} restored={restored} datastores={next(Shim.dataStores) ~= nil} errors={#Shim.handlerErrors}`)
"""


def record(ok: bool, name: str, detail: str = "") -> None:
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + name + (f"\n      {detail}" if detail and not ok else ""))


def source_texts(overrides: dict[str, str] | None = None) -> dict[str, str]:
    texts = run_matrix.sources("worktree")
    texts.update(overrides or {})
    return texts


def mutate(path: str, old: str, new: str) -> dict[str, str]:
    key = path.removeprefix("src/").removesuffix(".luau")
    text = (REPO / path).read_text()
    assert text.count(old) == 1, f"mutation anchor not found once in {path}: {old!r}"
    return {key: text.replace(old, new)}


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        library = run_matrix.ftz_library(workdir)

        def run(entry: str, source: str = "worktree", replace: dict[str, str] | None = None, mode: str = "gradual"):
            return m21.run(m21.bundle(source, entry, replace), mode, workdir, library)

        unit = m21.unit_entry()
        probes = run_matrix.git_show("HEAD", "review/offline-harness/probes.luau")
        persistence = (HERE / "persistence_probes.luau").read_text()

        # 0. The full M2.1 check set (StatService probes, its controls and mutation controls) at this branch's totals.
        m21.EXPECTED_TESTS, m21.EXPECTED_SUITES = EXPECTED_TESTS, EXPECTED_SUITES
        record(m21.main() == 0, "the M2.1 check set passes on this branch (review/m2.1/run_checks.py, 14 checks)")

        # 1. Shipped tests and historical probes.
        for mode in ("gradual", "ftz-winfmt"):
            code, out = run(unit, mode=mode)
            verdict = re.findall(r"\[Tests\] (ALL PASSED \(\d+ tests\)|\d+ FAILED, \d+ passed)", out)
            suites = re.findall(r"^\[Tests\] (\w+Tests): (\d+) passed, 0 failed$", out, re.M)
            record(code == 0 and verdict[-1:] == [f"ALL PASSED ({EXPECTED_TESTS} tests)"] and len(suites) == EXPECTED_SUITES,
                   f"[{mode}] TestRunner: {verdict[-1] if verdict else 'no verdict'} in {len(suites)} suites "
                   f"({', '.join(f'{s} {c}' for s, c in suites)})", out[-600:])
            code, out = run(probes, mode=mode)
            totals = re.findall(r"\[Probes\] total: (\d+) passed, (\d+) failed", out)
            record(code == 0 and totals[-1:] == [("75", "0")],
                   f"[{mode}] historical review probes: {totals[-1][0] + ' passed' if totals else 'no total'}", out[-600:])

        # 2. M2.1 StatService integration probes.
        code, out = run((REPO / "review/m2.1/statservice_probes.luau").read_text())
        summary = re.findall(r"\[StatService probes\] (\d+) passed, (\d+) failed", out)
        record(code == 0 and summary[-1:] != [] and summary[-1][1] == "0",
               f"M2.1 StatService integration probes: {summary[-1][0] + ' passed' if summary else 'no summary'}", out[-600:])

        # 3. Persistence probes.
        code, out = run(persistence)
        print("\n".join(line for line in out.splitlines() if line.startswith(("  PASS", "  FAIL"))))
        summary = re.findall(r"\[Persistence probes\] (\d+) passed, (\d+) failed", out)
        record(code == 0 and summary[-1:] != [] and summary[-1][1] == "0",
               f"persistence probes: {summary[-1][0] + ' passed, ' + summary[-1][1] + ' failed' if summary else 'no summary'}", out[-800:])

        # 4. Unpublished Studio place: in-memory saves, no DataStore touched.
        code, out = run(STUDIO_ENTRY)
        line = next((l for l in out.splitlines() if l.startswith("[studio]")), "")
        record(code == 0 and "restored=true" in line and "datastores=false" in line and "errors=0" in line
               and "Studio without DataStore access" in out and "gold=0 " not in line,
               f"unpublished Studio place: progress survives a rejoin in the same session, DataStore untouched ({line})", out[-600:])

        # 5. Client traffic for first-time players is unchanged from main.
        scenario = (REPO / "review/m2.1/client_traffic_scenario.luau").read_text()
        outputs = {}
        for label, source in (("main", MAIN), ("M3", "worktree")):
            code, out = run(scenario, source=source)
            outputs[label] = (code, [l for l in out.splitlines() if not l.startswith(("[Mode]", "[PlayerDataService]"))])
        (code_a, main_lines), (code_b, branch_lines) = outputs["main"], outputs["M3"]
        messages = sum(1 for l in main_lines if re.match(r"^\d+ ", l))
        record(code_a == 0 and code_b == 0 and main_lines == branch_lines and messages > 100,
               f"client traffic for first-time players identical on main ({MAIN[:7]}) and M3: {messages} messages",
               f"exit {code_a}/{code_b}")

        # 6. Static check: no yields in gameplay services or the pure profile modules.
        yielding = re.compile(r"task\.wait|task\.delay|task\.defer|\bwait\(|\bdelay\(|coroutine\.yield|:Wait\(|Async\(")
        hits = []
        for name in ("CombatService", "CombatRules", "CurrencyService", "Wallet", "StatService", "StatRules", "UpgradeService", "ProfileSchema"):
            for number, text in enumerate((REPO / f"src/ServerScriptService/{name}.luau").read_text().splitlines(), 1):
                if yielding.search(text):
                    hits.append(f"{name}:{number}")
        record(not hits, "gameplay services and ProfileSchema contain no yielding call (combat, Gold and purchases stay non-yielding)", ", ".join(hits))

        # 7. Mutation controls.
        mutations = {
            "locks ignored on load": mutate("src/ServerScriptService/ProfileStore.luau",
                "\tif typeof(lock) ~= \"table\" then\n\t\treturn true -- no lock", "\tif true then\n\t\treturn true -- no lock"),
            "save does not check the lock": mutate("src/ServerScriptService/ProfileStore.luau",
                "if typeof(lock) ~= \"table\" or (lock :: { [string]: unknown }).session ~= session then",
                "if false then"),
            "a failed load starts the player on defaults": mutate("src/ServerScriptService/PlayerSessionService.luau",
                "\tif profile == nil then\n\t\tsession.failed = true\n\t\tplayer:Kick(message)\n\t\treturn\n\tend",
                "\tif profile == nil then\n\t\tprofile = ProfileSchema.new()\n\tend"),
            "the stage is not saved": mutate("src/ServerScriptService/PlayerSessionService.luau",
                "\tprofile.stage = stage\n", "\tlocal _ = stage\n"),
            "damaged records repaired with defaults": mutate("src/ServerScriptService/ProfileSchema.luau",
                "\t\t\tif balance == nil then\n\t\t\t\treturn nil, `the {currency.id} balance is invalid`\n\t\t\tend\n\t\t\tprofile.currencies[currency.id] = balance",
                "\t\t\tif balance ~= nil then\n\t\t\t\tprofile.currencies[currency.id] = balance\n\t\t\tend"),
            "leave does not release the lock": mutate("src/ServerScriptService/PlayerSessionService.luau",
                "\tPlayerDataService.Release(player, buildProfile(player))\n\tsessions[player] = nil",
                "\tsessions[player] = nil"),
        }
        for label, replace in mutations.items():
            code_u, out_u = run(unit, replace=replace)
            code_p, out_p = run(persistence, replace=replace)
            unit_fails = re.findall(r"\[Tests\] (\d+) FAILED", out_u)
            probe_fails = re.findall(r"\[Persistence probes\] \d+ passed, (\d+) failed", out_p)
            caught_by = []
            if code_u != 0:
                caught_by.append(f"unit {unit_fails[-1] if unit_fails else '?'} failed")
            if code_p != 0:
                caught_by.append(f"probes {probe_fails[-1] if probe_fails else 'error'} failed")
            record(bool(caught_by), f"mutation control '{label}': " + ("; ".join(caught_by) or "NOT caught"))

    failed = results.count(False)
    print(f"[M3 checks] {len(results) - failed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
