#!/usr/bin/env python3
"""Round 4 release-package consistency checks for Emberbound Milestone 2 (review tooling only).

    python3 tools/m2/tests/check_release_package.py

Checks that every artifact of the round 4 BigNum adoption agrees with the source commit
9a988c9 and with each other, and runs the guide's own Appendix B parity checker text offline:

  A. Source integrity: src/ in the working tree equals src/ at the source commit; SOURCE_HASHES.txt
     round 4 lists exactly those 24 SHA-256 values; rounds 1-3 keep their hash lines from the
     frozen release e9d878d; only round 4 is marked current.
  B. Guide: the source pin and links; Appendix A (bytes, lines, Adler-32, SHA-256 and links) and the
     Appendix B checker table equal the values computed from the source; the T-1 block equals the
     per-suite lines the shipped TestRunner prints offline; T-2 and the allowed-messages table say 67.
  C. Installer: INSTALLER_MANIFEST.txt matches InstallM2.lua and the source files; the pinned download
     commit holds the same installer bytes; versions, SHA-256, sizes, test counts and links in the
     docs agree; the pinned Appendix B link holds the round 4 checker values.
  D. Other documents: QA template, review guide, requirements and README say round 4 and 67 tests;
     the imported QA report is byte-identical to QA commit ae861bd; the historical DEFECT-001B
     report only gained its status row.
  E. The real Appendix B checker text (translated to Lua 5.1, run against a fake place built from
     the source files) prints 24/24 PASS; negative controls: the round 4 checker against the
     round 3 BigNum files, and the round 3 checker against the round 4 sources, both FAIL 22/24.

Every Lua child process must exit with code 0: a positive parity run needs exit 0 plus the PASS
verdict, a negative control needs exit 0 (it ran to completion) plus the FAIL verdict, and the
unit-test run needs exit 0 plus the exact TestRunner lines (ADOPT-02). SOURCE_HASHES.txt headings
are validated with generate_installer.manifest_heading_errors (ADOPT-03). Regression tests for both:
tools/m2/tests/test_verification_tools.py.

Nothing here runs Roblox Studio. Studio must still run the installer, the Appendix B checker and
the unit tests.
"""

from __future__ import annotations

import hashlib
import re
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

sys.dont_write_bytecode = True
TESTS_DIR = Path(__file__).resolve().parent
TOOLS_DIR = TESTS_DIR.parent
REPO = Path(subprocess.check_output(["git", "-C", str(TOOLS_DIR), "rev-parse", "--show-toplevel"]).decode().strip())
sys.path.insert(0, str(TOOLS_DIR))
sys.path.insert(0, str(REPO / "review" / "ftz-harness"))
import generate_installer as gen  # noqa: E402
import luau51  # noqa: E402
import run_matrix  # noqa: E402

SOURCE = "9a988c9254e07ac50dcf32fe4b55ba975613390d"
FROZEN = "e9d878d94155610558c9c6252d76f202dfd956b4"  # round 3 release, historical
ROUND3_GUIDE = "2b832d267cc7461b5bebb138fe861d5b5e4ed0e9"  # guide pinned to the round 3 release
QA_COMMIT = "ae861bd"
TEST_TOTAL = 67
CURRENT_DOCS = ("M2_STUDIO_REGRESSION_GUIDE.md", "M2_REVIEW_GUIDE.md", "M2_REQUIREMENTS.md", "README.md",
                "review/M2_STUDIO_QA_RESULTS_TEMPLATE.md", "tools/m2/INSTALL_INSTRUCTIONS.md", "tools/m2/README.md")
STALE_COUNT = re.compile(r"\b61 (?:deterministic |unit )?tests\b|ALL PASSED \(61 tests\)")

results: list[tuple[bool, str]] = []


def record(ok: bool, name: str, detail: str = "") -> None:
    results.append((ok, name))
    print(("PASS " if ok else "FAIL ") + name + (f": {detail}" if detail and not ok else ""))


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(REPO), *args])


def text(path: str) -> str:
    return (REPO / path).read_text(encoding="utf-8")


def values(data: bytes) -> tuple[int, int, int, str]:
    return len(data), data.count(b"\n"), zlib.adler32(data), hashlib.sha256(data).hexdigest()


def manifest_rounds(content: str) -> dict[str, tuple[str, list[str]]]:
    rounds: dict[str, tuple[str, list[str]]] = {}
    current = None
    for line in content.splitlines():
        heading = re.match(r"## Round (\d+)", line)
        if heading:
            current = heading.group(1)
            rounds[current] = (line, [])
        elif current and re.fullmatch(r"[0-9a-f]{64}  src/\S+", line):
            rounds[current][1].append(line)
    return rounds


def appendix_b_rows(guide: str) -> list[tuple[str, str, int, int, int]]:
    return [(p, c, int(b), int(l), int(a)) for p, c, b, l, a in re.findall(r'\{ "([^"]+)", "(\w+)", (\d+), (\d+), (\d+) \}', guide)]


def appendix_b_snippet(guide: str) -> str:
    start = guide.index("## Appendix B")
    block = re.search(r"```lua\n(.*?)\n```", guide[start:], re.S)
    assert block is not None
    return block.group(1)


def main() -> int:
    files = gen.load_sources(REPO)  # source commit blobs, verified against round 4 at HEAD
    computed = {f["path"]: values(f["data"]) for f in files}

    # A. Source integrity.
    same_src = subprocess.run(["git", "-C", str(REPO), "diff", "--quiet", SOURCE, "--", "src"]).returncode == 0
    record(same_src, f"working-tree src/ is identical to the source commit {SOURCE[:7]}")
    worktree = {f["path"]: values((REPO / gen.repo_file(f["path"])).read_bytes()) for f in files}
    record(worktree == computed, "all 24 working-tree source files have the source commit's bytes, lines, Adler-32 and SHA-256")
    heading_errors = gen.manifest_heading_errors(text("SOURCE_HASHES.txt"))
    record(not heading_errors, "SOURCE_HASHES.txt headings: exactly rounds 4, 3, 2, 1, no duplicate or unexpected heading, "
           "round 4 the only current round, hash-line counts match", "; ".join(heading_errors))
    rounds = manifest_rounds(text("SOURCE_HASHES.txt"))
    r4 = sorted(rounds.get("4", ("", []))[1])
    expected_r4 = sorted(f"{f['sha256']}  {gen.repo_file(f['path'])}" for f in files)
    record(r4 == expected_r4 and len(r4) == 24, "SOURCE_HASHES.txt round 4 lists exactly the 24 source SHA-256 values")
    record(SOURCE[:7] in rounds["4"][0] and "current" in rounds["4"][0], "round 4 heading names the source commit and is marked current")
    frozen_rounds = manifest_rounds(git("show", f"{FROZEN}:SOURCE_HASHES.txt").decode())
    record(all(rounds[n][1] == frozen_rounds[n][1] for n in ("1", "2", "3")), "rounds 1-3 keep their hash lines exactly as in the round 3 release")
    record(all("historical" in rounds[n][0] for n in ("1", "2", "3")), "rounds 1-3 are marked historical")
    r3 = dict((line.split("  ")[1], line.split("  ")[0]) for line in frozen_rounds["3"][1])
    changed = sorted(p for p in r3 if r3[p] != dict((l.split("  ")[1], l.split("  ")[0]) for l in rounds["4"][1])[p])
    record(changed == ["src/ReplicatedStorage/Shared/BigNum.luau", "src/ServerScriptService/Tests/BigNumTests.luau"],
           "round 4 differs from round 3 only in BigNum.luau and BigNumTests.luau", ", ".join(changed))

    # B. Regression guide.
    guide = text("M2_STUDIO_REGRESSION_GUIDE.md")
    code_row = re.search(r"^\| Code under test \| (.*)$", guide, re.M).group(1)
    record(SOURCE in code_row and "round 4" in code_row and FROZEN not in code_row, "guide 'Code under test' pins the source commit and round 4")
    record(f"/tree/{SOURCE}/src>" in guide and f"/archive/{SOURCE}.zip>" in guide, "guide browse and ZIP links point to the source commit")
    links = re.findall(r"https://github.com/zelly-cious/Emberbound/blob/([0-9a-f]{40})/src/", guide)
    record(len(links) == 24 and set(links) == {SOURCE}, f"all 24 Appendix A file links point to the source commit ({len(links)} found)")
    table = re.findall(r"^\| (\d+) \| `(\w+)` \| (\d+) \| (\d+) \| (\d+) \| `([0-9a-f]{64})` \|", guide, re.M)
    expected_table = [(str(i), f["path"].rsplit("/", 1)[1], *map(str, computed[f["path"]])) for i, f in enumerate(files, 1)]
    record(table == expected_table, "Appendix A checksum table (bytes, lines, Adler-32, SHA-256) equals the source values")
    expected_b = [(f["path"], f["className"], *computed[f["path"]][:3]) for f in files]
    record(appendix_b_rows(guide) == expected_b, "Appendix B checker table equals the source values (24 rows)")
    t1 = guide[guide.index("### T-1"):guide.index("### T-2")]
    t1_lines = re.findall(r"^\[Tests\] .*$", t1, re.M)
    unit_code, unit_output = run_unit_tests()
    unit_ok, unit_detail = evaluate_unit(unit_code, unit_output, t1_lines)
    record(unit_ok, f"guide T-1 block equals the 8 lines the shipped TestRunner prints offline (exit 0, ALL PASSED ({TEST_TOTAL} tests))",
           unit_detail)
    record(f"(31 + 4 + 5 + 7 + 3 + 7 + 10 = {TEST_TOTAL})" in t1 and f"1 FAILED, {TEST_TOTAL} passed" in guide
           and f"`[Tests] ALL PASSED ({TEST_TOTAL} tests)` | Unit tests |" in guide and "ALL PASSED (61 tests)" not in guide,
           "guide T-1 sum, T-2 expectation and the allowed-messages table say 67; no current '61 tests' remains")

    # C. Installer.
    installer = (TOOLS_DIR / "InstallM2.lua").read_bytes()
    manifest = text("tools/m2/INSTALLER_MANIFEST.txt")
    m = dict(re.findall(r"^(installer_version|frozen_commit|installer_bytes|installer_sha256) (\S+)$", manifest, re.M))
    sha = hashlib.sha256(installer).hexdigest()
    record(m.get("installer_sha256") == sha and m.get("installer_bytes") == str(len(installer)),
           f"INSTALLER_MANIFEST.txt records the installer's SHA-256 and size ({len(installer)} bytes)")
    record(m.get("frozen_commit") == SOURCE and m.get("installer_version") == gen.INSTALLER_VERSION == "1.2.0",
           "installer manifest names the source commit and version 1.2.0")
    rows = re.findall(r"^([0-9a-f]{64})  (\d+)  (\d+)  (\d+)  (\w+)  (\S+)$", manifest, re.M)
    record([(s, int(b), int(l), int(a), c, p) for s, b, l, a, c, p in rows]
           == [(computed[f["path"]][3], *computed[f["path"]][:3], f["className"], f["path"]) for f in files],
           "installer manifest file rows equal the source values (24 rows)")
    lua = installer.decode("ascii")
    record(f'local FROZEN_COMMIT = "{SOURCE}"' in lua and f'local INSTALLER_VERSION = "{gen.INSTALLER_VERSION}"' in lua,
           "InstallM2.lua embeds the source commit and version")
    instructions = text("tools/m2/INSTALL_INSTRUCTIONS.md")
    pinned = re.search(r"blob/([0-9a-f]{40})/tools/m2/InstallM2\.lua", instructions)
    pinned_ok = False
    if pinned:
        pinned_ok = hashlib.sha256(git("show", f"{pinned.group(1)}:tools/m2/InstallM2.lua")).hexdigest() == sha
    record(pinned_ok, "the pinned download commit in INSTALL_INSTRUCTIONS.md holds byte-identical installer bytes")
    stale_version = re.search(r"InstallM2\.lua`? v1\.1\.0|installer v1\.1\.0", instructions)
    record(instructions.count(sha) == 2 and "v1.2.0" in instructions and stale_version is None and SOURCE in instructions,
           "INSTALL_INSTRUCTIONS.md quotes the installer SHA-256 (twice), v1.2.0 and the source commit")
    guide_link = re.search(r"blob/([0-9a-f]{40})/M2_STUDIO_REGRESSION_GUIDE\.md#appendix-b", instructions)
    link_ok = guide_link is not None and appendix_b_rows(git("show", f"{guide_link.group(1)}:M2_STUDIO_REGRESSION_GUIDE.md").decode()) == expected_b
    record(link_ok, "the Appendix B link in INSTALL_INSTRUCTIONS.md points to a guide holding the round 4 checker values")
    record(f"BigNumTests: 31 passed" in instructions and f"ALL PASSED ({TEST_TOTAL} tests)" in instructions and "61 " not in instructions,
           "INSTALL_INSTRUCTIONS.md expects 67 tests (BigNumTests 31)")
    readme = text("tools/m2/README.md")
    record("**v1.2.0**" in readme and sha in readme and SOURCE in readme, "tools/m2/README.md names v1.2.0, the installer SHA-256 and the source commit")

    # D. Other documents.
    template = text("review/M2_STUDIO_QA_RESULTS_TEMPLATE.md")
    record(SOURCE in template and "round 4" in template and f"| T-1 | {TEST_TOTAL} tests in 7 suites pass |" in template,
           "QA template pins the source commit, round 4 and 67 tests")
    record("round 4, current" in text("M2_REVIEW_GUIDE.md") and f"ALL PASSED ({TEST_TOTAL} tests)" in text("M2_REVIEW_GUIDE.md"),
           "M2_REVIEW_GUIDE.md section 9 says round 4 and 67 tests")
    record(f"{TEST_TOTAL} tests since the round 4 BigNum adoption" in text("M2_REQUIREMENTS.md") and SOURCE in text("M2_REQUIREMENTS.md"),
           "M2_REQUIREMENTS.md records the adoption and 67 tests")
    record(f"the shipped {TEST_TOTAL} tests" in text("README.md"), "README.md says 67 tests")
    stale = [f"{doc}:{number}" for doc in CURRENT_DOCS for number, line in enumerate(text(doc).splitlines(), 1)
             if STALE_COUNT.search(line) and "historical" not in line]
    record(not stale, "no current document claims 61 tests outside an explicitly historical note (ADOPT-01)", ", ".join(stale))
    qa_same = git("hash-object", "review/M2_STUDIO_QA_RESULTS.md").strip() == git("rev-parse", f"{QA_COMMIT}:review/M2_STUDIO_QA_RESULTS.md").strip()
    record(qa_same, f"review/M2_STUDIO_QA_RESULTS.md is byte-identical to QA commit {QA_COMMIT} (historical evidence)")
    diff = git("diff", SOURCE, "--", "review/DEFECT-001B_REPORT.md", "review/DEFECT-001_REPORT.md").decode()
    removed = [l for l in diff.splitlines() if l.startswith("-") and not l.startswith("---")]
    added = [l for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
    record(not removed and len(added) == 1 and added[0].startswith("+| Update: round 4 adoption |"),
           "historical DEFECT reports are unchanged except one added DEFECT-001B status row")

    # E. The real Appendix B checker text, offline.
    sources = {f["path"]: f["data"].decode() for f in files}
    round3_sources = dict(sources)
    for path in ("ReplicatedStorage/Shared/BigNum", "ServerScriptService/Tests/BigNumTests"):
        round3_sources[path] = git("show", f"{FROZEN}:{gen.repo_file(path)}").decode()
    round3_guide = git("show", f"{ROUND3_GUIDE}:M2_STUDIO_REGRESSION_GUIDE.md").decode()
    for label, snippet_guide, place, expect_pass in (
        ("round 4 checker, round 4 sources", guide, sources, True),
        ("round 4 checker, round 3 BigNum and BigNumTests (negative control)", guide, round3_sources, False),
        ("round 3 checker, round 4 sources (negative control: the expected initial 22/24)", round3_guide, sources, False),
    ):
        code, output = run_checker(appendix_b_snippet(snippet_guide), place, files)
        ok, description = evaluate_parity(code, output, expect_pass)
        record(ok, f"Appendix B checker text offline, {label}: {description}", output[-600:])

    failed = sum(1 for ok, _ in results if not ok)
    print(f"[package checks] {len(results) - failed} passed, {failed} failed")
    return 0 if failed == 0 else 1


FAKE_PLACE = r"""
local function newNode(name, className, parent, extra)
	local node = { Name = name, ClassName = className, Parent = parent, _children = {} }
	for k, v in pairs(extra or {}) do node[k] = v end
	if parent then table.insert(parent._children, node) end
	function node:FindFirstChild(childName) for _, c in ipairs(self._children) do if c.Name == childName then return c end end return nil end
	function node:GetChildren() local out = {} for i, c in ipairs(self._children) do out[i] = c end return out end
	function node:GetDescendants() local out = {} local function walk(n) for _, c in ipairs(n._children) do out[#out + 1] = c walk(c) end end walk(self) return out end
	function node:IsA(class)
		if class == "LuaSourceContainer" then return self.ClassName == "Script" or self.ClassName == "LocalScript" or self.ClassName == "ModuleScript" end
		if class == "BaseScript" then return self.ClassName == "Script" or self.ClassName == "LocalScript" end
		return self.ClassName == class
	end
	function node:GetFullName() local parts = {} local n = self while n do table.insert(parts, 1, n.Name) n = n.Parent end return table.concat(parts, ".") end
	return node
end
Enum = { RunContext = { Legacy = "Legacy", Client = "Client" } }
local services = {}
game = {}
function game:GetService(name)
	if not services[name] then services[name] = newNode(name, name, nil, name == "Players" and { CharacterAutoLoads = false } or nil) end
	return services[name]
end
local function container(path)
	local parts = string.split(path, "/")
	local node = game:GetService(parts[1])
	for i = 2, #parts do
		node = node:FindFirstChild(parts[i]) or newNode(parts[i], "Folder", node)
	end
	return node
end
local shared = container("ReplicatedStorage/Shared")
local remotes = container("ReplicatedStorage/Remotes")
container("ServerScriptService/Tests")
container("StarterPlayer/StarterPlayerScripts")
for _, name in ipairs({ "RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate" }) do newNode(name, "RemoteEvent", remotes) end
for _, item in ipairs(PLACE) do
	local parts = string.split(item.path, "/")
	local parent = game:GetService(parts[1])
	for i = 2, #parts - 1 do parent = parent:FindFirstChild(parts[i]) end
	local extra = { Source = item.source }
	if item.className ~= "ModuleScript" then extra.Enabled = true end
	if item.className == "Script" then extra.RunContext = Enum.RunContext.Legacy end
	newNode(parts[#parts], item.className, parent, extra)
end
"""


def lua_long_string(value: str) -> str:
    level = 1  # Lua 5.1 rejects "[[" inside a level-0 long string, and the sources contain "--[["
    while f"]{'=' * level}]" in value:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{value}]{eq}]"


def run_lua(chunk: str) -> tuple[int, str]:
    """Run a Lua 5.1 chunk; returns (exit code, stdout + stderr)."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "chunk.lua"
        path.write_text(chunk)
        run = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True)
    return run.returncode, run.stdout + run.stderr


PARITY_SUMMARY = re.compile(r"\[Parity\] scripts matching: (\d+) / 24, remotes: (\d+) / 6, extra scripts: (\d+)")


def evaluate_parity(code: int, output: str, expect_pass: bool) -> tuple[bool, str]:
    """Positive run: exit 0, exactly one PASS verdict, no FAIL verdict or FAIL line, 24 / 6 / 0.
    Negative control: exit 0 (the checker ran to completion), the FAIL verdict and no PASS verdict,
    22 / 6 / 0 and exactly two 'content differs' lines. Anything else, including a Lua error after
    a verdict was printed, is a failure."""
    summary = PARITY_SUMMARY.search(output)
    passes = output.count("[Parity] RESULT: PASS")
    fails = output.count("[Parity] RESULT: FAIL")
    description = (summary.group(0) if summary else "no summary") + (" RESULT: PASS" if passes else " RESULT: FAIL" if fails else " no verdict")
    description += f" (lua exit {code})"
    if code != 0:
        return False, description
    if expect_pass:
        ok = passes == 1 and fails == 0 and "[Parity] FAIL" not in output and summary is not None and summary.groups() == ("24", "6", "0")
    else:
        ok = (passes == 0 and fails == 1 and summary is not None and summary.groups() == ("22", "6", "0")
              and output.count("content differs") == 2)
    return ok, description


def run_unit_tests() -> tuple[int, str]:
    """The shipped TestRunner on the working-tree sources (gradual mode); returns (lua exit code, output)."""
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        return run_matrix.run("worktree", "unit", "gradual", run_matrix.ftz_library(workdir), workdir, "HEAD")


def evaluate_unit(code: int, output: str, expected_lines: list[str]) -> tuple[bool, str]:
    """Exit 0, and the [Tests] lines are exactly the expected 8, ending in ALL PASSED (67 tests)."""
    lines = re.findall(r"^\[Tests\] .*$", output, re.M)
    if code != 0:
        return False, f"unit-test process exited with code {code}; [Tests] lines: {lines}"
    ok = (len(expected_lines) == 8 and lines == expected_lines and lines[-1] == f"[Tests] ALL PASSED ({TEST_TOTAL} tests)")
    return ok, f"runner={lines} expected={expected_lines}"


def run_checker(snippet: str, place: dict[str, str], files: list[dict]) -> tuple[int, str]:
    items = ",\n".join(
        f'{{ path = "{f["path"]}", className = "{f["className"]}", source = {lua_long_string(place[f["path"]])} }}' for f in files
    )
    chunk = "\n".join([
        (REPO / "review/ftz-harness/prelude.lua").read_text(),
        "PLACE = {\n" + items + "\n}",
        FAKE_PLACE,
        # The snippet is written for the Command Bar, with several statements per line. The translator's
        # compound-assignment rule assumes one statement per line, so the snippet's only compound form,
        # "name += 1", is rewritten first; the rest of the text is translated unchanged.
        luau51.translate(re.sub(r"\b([A-Za-z_]\w*) \+= 1\b", r"\1 = \1 + 1", snippet)),
    ])
    return run_lua(chunk)


if __name__ == "__main__":
    sys.exit(main())
