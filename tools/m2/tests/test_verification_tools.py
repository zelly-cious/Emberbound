#!/usr/bin/env python3
"""Regression tests for the round 4 verification tooling (review tooling only).

    python3 tools/m2/tests/test_verification_tools.py

ADOPT-02: an unexpected Lua execution error must make verification fail, even when the output
already contains the expected verdict. Each case runs a real lua5.1 process:
  - the guide's Appendix B checker text with an error injected after its verdict (positive run
    and negative control), and with a syntax error;
  - the shipped TestRunner bundle with an error injected after ALL PASSED (67 tests).
ADOPT-03: SOURCE_HASHES.txt heading validation rejects a fake "Round 5 (current)", duplicate,
unexpected, mislabelled and miscounted rounds; end to end, both check_release_package.py and
run_tests.py fail on a working tree whose manifest has a fake Round 5 (current) heading (the file
is restored byte for byte afterwards).
ADOPT-01: end to end, check_release_package.py fails when the M2_REVIEW_GUIDE.md inventory row says
61 tests again (restored afterwards).

Nothing here runs Roblox Studio.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
TESTS_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS_DIR))
import check_release_package as crp  # noqa: E402

gen = crp.gen
run_matrix = crp.run_matrix
REPO = crp.REPO
INJECTED = '\nerror("injected Lua error after the verdict")\n'

results: list[tuple[bool, str]] = []


def record(ok: bool, name: str, detail: str = "") -> None:
    results.append((ok, name))
    print(("PASS " if ok else "FAIL ") + name + (f": {detail}" if detail and not ok else ""))


def test_parity_exit_codes(files: list[dict]) -> None:
    guide = crp.text("M2_STUDIO_REGRESSION_GUIDE.md")
    snippet = crp.appendix_b_snippet(guide)
    round3_snippet = crp.appendix_b_snippet(crp.git("show", f"{crp.ROUND3_GUIDE}:M2_STUDIO_REGRESSION_GUIDE.md").decode())
    sources = {f["path"]: f["data"].decode() for f in files}

    code, output = crp.run_checker(snippet, sources, files)
    ok, description = crp.evaluate_parity(code, output, True)
    record(ok and code == 0, f"control: positive Appendix B run is accepted ({description})")

    code, output = crp.run_checker(snippet + INJECTED, sources, files)
    ok, description = crp.evaluate_parity(code, output, True)
    record(code != 0 and "[Parity] RESULT: PASS" in output and not ok,
           f"positive run with a Lua error after the PASS verdict is rejected ({description})")

    code, output = crp.run_checker(round3_snippet, sources, files)
    ok, description = crp.evaluate_parity(code, output, False)
    record(ok and code == 0, f"control: negative control (round 3 checker, round 4 sources) is accepted ({description})")

    code, output = crp.run_checker(round3_snippet + INJECTED, sources, files)
    ok, description = crp.evaluate_parity(code, output, False)
    record(code != 0 and "[Parity] RESULT: FAIL" in output and not ok,
           f"negative control with a Lua error after the FAIL verdict is rejected ({description})")

    code, output = crp.run_checker("local = 1\n" + snippet, sources, files)
    rejected = not crp.evaluate_parity(code, output, True)[0] and not crp.evaluate_parity(code, output, False)[0]
    record(code != 0 and rejected, f"a checker that does not compile is rejected as both a positive run and a negative control (lua exit {code})")


def test_unit_exit_codes() -> None:
    guide = crp.text("M2_STUDIO_REGRESSION_GUIDE.md")
    t1 = guide[guide.index("### T-1"):guide.index("### T-2")]
    expected = re.findall(r"^\[Tests\] .*$", t1, re.M)

    code, output = crp.run_unit_tests()
    ok, detail = crp.evaluate_unit(code, output, expected)
    record(ok and code == 0, "control: the shipped TestRunner run is accepted (exit 0, the 8 T-1 lines)", detail)

    bundle = run_matrix.bundle("worktree", "unit", "HEAD") + INJECTED
    code, output = crp.run_lua(bundle)
    ok, detail = crp.evaluate_unit(code, output, expected)
    record(code != 0 and "[Tests] ALL PASSED (67 tests)" in output and not ok,
           f"TestRunner run with a Lua error after ALL PASSED (67 tests) is rejected (lua exit {code})", detail)


def test_manifest_headings() -> None:
    real = (REPO / "SOURCE_HASHES.txt").read_text()
    record(gen.manifest_heading_errors(real) == [], "control: the committed SOURCE_HASHES.txt has no heading errors")
    lines = real.split("\n")
    title = lines[0]
    round4 = real[real.index("## Round 4"):real.index("## Round 3")]
    round3 = real[real.index("## Round 3"):real.index("## Round 2")]
    round4_hashes = "\n".join(l for l in round4.split("\n") if re.fullmatch(r"[0-9a-f]{64}  src/\S+", l))
    fake5 = f"## Round 5 — fake adoption (24 files; current)\n\n{round4_hashes}\n\n"
    cases = {
        "a fake 'Round 5 (current)' heading": real.replace(title + "\n\n", title + "\n\n" + fake5, 1),
        "a duplicate Round 3 section": real.replace("## Round 2", round3 + "## Round 2", 1),
        "an unexpected '## Notes' heading": real.replace("## Round 3", "## Notes\n\n## Round 3", 1),
        "round 3 relabelled current": real.replace("(24 files; historical)", "(24 files; current)", 1),
        "round 4 relabelled historical (no current round)": real.replace("(24 files; current)", "(24 files; historical)", 1),
        "a round 4 hash line removed": real.replace(round4_hashes.split("\n")[0] + "\n", "", 1),
    }
    for label, content in cases.items():
        errors = gen.manifest_heading_errors(content)
        record(content != real and bool(errors), f"heading validation rejects {label}", "no error reported")
        if label.startswith("a fake"):
            record(any("only current round" in e for e in errors) and any("rounds 4, 3, 2, 1" in e for e in errors),
                   "the fake Round 5 is reported as a second current round and an unexpected round", "; ".join(errors))


def test_manifest_end_to_end() -> None:
    path = REPO / "SOURCE_HASHES.txt"
    original = path.read_bytes()
    text = original.decode()
    title = text.split("\n")[0]
    round4 = text[text.index("## Round 4"):text.index("## Round 3")]
    hashes = "\n".join(l for l in round4.split("\n") if re.fullmatch(r"[0-9a-f]{64}  src/\S+", l))
    planted = text.replace(title + "\n\n", f"{title}\n\n## Round 5 — fake adoption (24 files; current)\n\n{hashes}\n\n", 1)
    try:
        path.write_text(planted)
        for script in ("check_release_package.py", "run_tests.py"):
            run = subprocess.run([sys.executable, str(TESTS_DIR / script)], capture_output=True, text=True)
            flagged = re.search(r"^FAIL SOURCE_HASHES\.txt headings:.*only current round", run.stdout, re.M)
            record(run.returncode != 0 and flagged is not None,
                   f"end to end: {script} fails on a working tree with a fake 'Round 5 (current)' heading (exit {run.returncode})",
                   run.stdout[-400:])
    finally:
        path.write_bytes(original)
    record(path.read_bytes() == original, "SOURCE_HASHES.txt restored byte for byte after the end-to-end test")


def test_stale_count_end_to_end() -> None:
    path = REPO / "M2_REVIEW_GUIDE.md"
    original = path.read_bytes()
    current = "and 67 deterministic tests in 7 suites (48 in round 1; 61 after TestKitTests and 6 more tests were added in e4b0108; 67 after the round 4 adoption of `9a988c9` added 6 BigNum regression tests) |"
    reverted = "and 61 deterministic tests in 7 suites (48 in round 1; TestKitTests and 6 more tests added in e4b0108) |"
    text = original.decode()
    try:
        path.write_text(text.replace(current, reverted, 1))
        run = subprocess.run([sys.executable, str(TESTS_DIR / "check_release_package.py")], capture_output=True, text=True)
        flagged = re.search(r"^FAIL no current document claims 61 tests.*M2_REVIEW_GUIDE\.md:69", run.stdout, re.M)
        record(current in text and run.returncode != 0 and flagged is not None,
               f"end to end: check_release_package.py fails when the ADOPT-01 inventory row says 61 tests again (exit {run.returncode})",
               run.stdout[-400:])
    finally:
        path.write_bytes(original)
    record(path.read_bytes() == original, "M2_REVIEW_GUIDE.md restored byte for byte after the end-to-end test")


def main() -> int:
    files = gen.load_sources(REPO)
    test_parity_exit_codes(files)
    test_unit_exit_codes()
    test_manifest_headings()
    test_manifest_end_to_end()
    test_stale_count_end_to_end()
    failed = sum(1 for ok, _ in results if not ok)
    print(f"[verification self-tests] {len(results) - failed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
