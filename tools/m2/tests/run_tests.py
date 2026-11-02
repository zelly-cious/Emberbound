#!/usr/bin/env python3
"""Offline checks for the Milestone 2 Studio installer (task M2-TOOLS-001). Review tooling only.

    python3 tools/m2/tests/run_tests.py

1. Frozen commit, 24 files, SHA-256 against SOURCE_HASHES.txt round 3 (via the generator).
2. Deterministic generation: two in-memory builds and the committed files are byte-identical.
3. Independent decoding: every embedded string is decoded by a second decoder written here
   and compared with the frozen bytes read straight from git.
4. Static safety scan of the installer logic (no HTTP, DataStores, publishing, require, ...).
5. The real installer text runs against a fake Roblox engine with plain Lua 5.1
   (tests/installer_tests.lua): preflight, install, repeat run, collisions, unsafe modes,
   damaged and truncated text, joined lines, CRLF, and rollback after injected failures.
6. The installed result from step 5 is checked with an offline replica of the Appendix B
   parity logic, using the expected values parsed from M2_STUDIO_REGRESSION_GUIDE.md.
7. Git: src/ and SOURCE_HASHES.txt are unchanged; only tools/m2/ differs from the base.

None of this runs Roblox Studio. Studio behaviour must still be tested by the project owner.
"""

from __future__ import annotations

import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
TOOLS_DIR = TESTS_DIR.parent
sys.dont_write_bytecode = True  # keep tools/m2 free of __pycache__
sys.path.insert(0, str(TOOLS_DIR))

import generate_installer as gen  # noqa: E402

REPO = Path(subprocess.check_output(["git", "-C", str(TOOLS_DIR), "rev-parse", "--show-toplevel"]).decode().strip())
BASE_COMMIT = "2b832d267cc7461b5bebb138fe861d5b5e4ed0e9"  # PR #1 head this branch starts from
FORBIDDEN = [
    "HttpService", "DataStore", "MemoryStore", "MessagingService", "MarketplaceService", "TeleportService",
    "Publish", "SavePlace", "InsertService", "AssetService", "PluginManager", "plugin", "loadstring",
    "require", "getfenv", "setfenv", "task.wait", "wait(", "spawn(", "delay(", "RunService:Run", "Simulation",
    ":ClearAllChildren", "ChangeHistoryService", "Selection", "game:Shutdown", "GetService",
]

results: list[tuple[bool, str]] = []


def record(ok: bool, name: str, detail: str = "") -> None:
    results.append((ok, name))
    print(f"{'PASS' if ok else 'FAIL'} {name}{': ' + detail if detail else ''}")


def decode_lua_string(body: str) -> bytes:
    """Second, independent decoder (regex based) for double-quoted Lua string bodies."""
    def replace(match: re.Match) -> str:
        token = match.group(0)
        if token[1].isdigit():
            return chr(int(token[1:]))
        return {"\\n": "\n", "\\t": "\t", '\\"': '"', "\\\\": "\\"}[token]

    if re.search(r"\\[^nt\"\\0-9]", body):
        raise ValueError("unexpected escape")
    return re.sub(r"\\(\d{3}|[nt\"\\])", replace, body).encode("latin-1")


def main() -> int:
    installer_text = gen.OUTPUT_PATH.read_text(encoding="ascii")

    # 1. Frozen source identity.
    try:
        files = gen.load_sources(REPO)
        record(True, f"frozen commit {gen.FROZEN_COMMIT} resolves; src/ holds exactly 24 files; all SHA-256 match SOURCE_HASHES.txt round 3")
    except gen.GenerationError as error:
        record(False, "frozen source identity", str(error))
        return finish()
    classes = [f["className"] for f in files]
    record(classes.count("Script") == 2 and classes.count("LocalScript") == 1 and classes.count("ModuleScript") == 21,
           "classes: 2 Scripts (ServerInit, TestRunner), 1 LocalScript (CombatClient), 21 ModuleScripts")
    try:
        gen.check_guide(REPO, files)
        record(True, "Appendix A (paths, classes, SHA-256) and Appendix B (bytes, lines, Adler-32) of the guide match the frozen files")
    except gen.GenerationError as error:
        record(False, "guide cross-check", str(error))

    # 2. Determinism.
    first, manifest_a, _ = gen.build(REPO)
    second, manifest_b, _ = gen.build(REPO)
    record(first == second and manifest_a == manifest_b, "two generations are byte-identical")
    record(first == installer_text and gen.MANIFEST_PATH.read_text(encoding="ascii") == manifest_a,
           "committed InstallM2.lua and INSTALLER_MANIFEST.txt equal a fresh generation")
    sha = hashlib.sha256(installer_text.encode("ascii")).hexdigest()
    record(f"installer_sha256 {sha}" in manifest_a, f"manifest records the installer SHA-256 {sha}")

    # 3. Independent decoding of every embedded file.
    ok_decode = True
    for index, f in enumerate(files, 1):
        start = installer_text.index(f"\nFILES[{index}] = {{\n")
        end = installer_text.index("\n}\n", start)
        literals = re.findall(r'^\t\t"((?:[^"\\]|\\.)*)",$', installer_text[start:end], re.M)
        rebuilt = b"".join(decode_lua_string(s) for s in literals)
        if rebuilt != f["data"] or len(literals) != f["lines"]:
            ok_decode = False
            record(False, f"decode {f['path']}")
    record(ok_decode, "second decoder rebuilds all 24 embedded files byte for byte (one literal per source line)")
    record(installer_text.isascii() and "\r" not in installer_text, "installer is ASCII-only with LF line endings")
    record(installer_text.count("local ENABLE_INSTALLATION = false") == 1 and "ENABLE_INSTALLATION = true\n" not in installer_text,
           "installation is disabled by default (single setting)")

    # 4. Static scan of the installer logic (the template; the payload is the frozen game source).
    template = gen.TEMPLATE_PATH.read_text(encoding="ascii")
    code = re.sub(r"--\[\[.*?\]\]", "", template, flags=re.S)
    hits = [token for token in FORBIDDEN if token in code]
    record(not hits, "installer logic uses no GetService (it creates missing services), HTTP, DataStore, publish, require, loadstring, yields or other unrelated APIs", ", ".join(hits))
    calls = sorted(set(re.findall(r"findService\(\"(\w+)\"\)", code)))
    record(code.count("game:FindService(") == 1 and calls == ["Players", "RunService"],
           f"every service lookup goes through one non-creating game:FindService helper (named directly: {calls})")
    record("Destroy()" in code and code.count(":Destroy()") == 1 and "built[index]" in code,
           "the only Destroy() call removes objects from this run's own 'built' list")
    try:
        subprocess.run(["luac5.1", "-p", str(gen.OUTPUT_PATH)], check=True, capture_output=True)
        record(True, "luac5.1 -p accepts the installer (Lua 5.1 subset of Luau)")
    except FileNotFoundError:
        record(False, "luac5.1 not installed; syntax check skipped")
    except subprocess.CalledProcessError as error:
        record(False, "luac5.1 -p", error.stderr.decode())

    # 5 and 6. Run the installer against the fake engine, then replicate Appendix B on the result.
    lua = shutil.which("lua5.1")
    if lua is None:
        record(False, "lua5.1 not installed; behaviour tests skipped")
    else:
        with tempfile.TemporaryDirectory() as tmp:
            fixtures = Path(tmp)
            (fixtures / "layout.txt").write_text("".join(f"{f['path']}\t{f['className']}\n" for f in files))
            for index, f in enumerate(files, 1):
                (fixtures / f"{index:02d}.luau").write_bytes(f["data"])
            dump = fixtures / "installed.dump"
            run = subprocess.run([lua, str(TESTS_DIR / "installer_tests.lua"), str(gen.OUTPUT_PATH), str(fixtures), str(dump)],
                                 capture_output=True, text=True)
            print(run.stdout.rstrip())
            if run.stderr:
                print(run.stderr.rstrip())
            summary = re.search(r"\[installer tests\] (\d+) passed, (\d+) failed, (\d+) declared", run.stdout)
            counts_ok = (summary is not None and int(summary.group(1)) > 0 and summary.group(2) == "0"
                         and summary.group(1) == summary.group(3))
            record(run.returncode == 0 and counts_ok,
                   f"Lua behaviour tests against the fake engine: {summary.group(0) if summary else 'no summary'} "
                   "(every declared test must run and pass)")
            if dump.exists():
                replicate_appendix_b(dump.read_text())
            else:
                record(False, "no installed dump to check")

    # 7. Repository hygiene.
    src_same = subprocess.run(["git", "-C", str(REPO), "diff", "--quiet", gen.FROZEN_COMMIT, "--", "src"]).returncode == 0
    record(src_same, "working tree src/ is identical to the frozen commit")
    hashes_same = subprocess.run(["git", "-C", str(REPO), "diff", "--quiet", BASE_COMMIT, "--", "SOURCE_HASHES.txt"]).returncode == 0
    record(hashes_same, "SOURCE_HASHES.txt is unchanged from the base commit")
    changed = subprocess.check_output(["git", "-C", str(REPO), "diff", "--name-only", BASE_COMMIT]).decode().split()
    untracked = subprocess.check_output(["git", "-C", str(REPO), "ls-files", "--others", "--exclude-standard"]).decode().split()
    outside = [p for p in changed + untracked if not p.startswith("tools/m2/")]
    record(not outside, "every change since the base commit is under tools/m2/", ", ".join(outside))
    return finish()


def replicate_appendix_b(dump: str) -> None:
    """Offline replica of the Appendix B checker's logic, using the guide's own expected table."""
    guide = (REPO / gen.GUIDE_PATH).read_text()
    expected = re.findall(r'\{ "([^"]+)", "(\w+)", (\d+), (\d+), (\d+) \}', guide)
    scripts, objects, setting = {}, {}, None
    for line in dump.splitlines():
        parts = line.split("\t")
        if parts[0] == "SCRIPT":
            if parts[1] in scripts:
                scripts[parts[1]] = None  # duplicate
            else:
                scripts[parts[1]] = (parts[2], parts[3], parts[4], bytes.fromhex(parts[5]))
        elif parts[0] == "OBJECT":
            objects.setdefault(parts[1], []).append(parts[2])
        elif parts[0] == "SETTING":
            setting = parts[2]
    matched = 0
    for path, class_name, size, lines, checksum in expected:
        entry = scripts.get(path)
        if entry is None:
            continue
        cls, enabled, context, source = entry
        text = gen.normalize(source)
        if (cls == class_name and len(text) == int(size) and text.count(b"\n") == int(lines)
                and gen.adler32(text) == int(checksum) and enabled != "false" and context != "Enum.RunContext.Client"):
            matched += 1
    folders = all(objects.get(p) == ["Folder"] for p in ("ReplicatedStorage/Shared", "ReplicatedStorage/Remotes", "ServerScriptService/Tests"))
    remote_names = [p.split("/")[-1] for p, c in objects.items() if p.startswith("ReplicatedStorage/Remotes/")]
    remotes = sum(1 for name in ("RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate")
                  if objects.get(f"ReplicatedStorage/Remotes/{name}") == ["RemoteEvent"])
    extra = [p for p in scripts if p not in {e[0] for e in expected}]
    record(len(expected) == 24 and matched == 24 and remotes == 6 and len(remote_names) == 6 and folders and not extra and setting == "false",
           f"replicated Appendix B logic on the installed mock place: scripts matching {matched} / 24, remotes {remotes} / 6, "
           f"extra scripts {len(extra)}, folders {'3 / 3' if folders else 'missing'}, CharacterAutoLoads {setting} "
           "(offline replica only; the real checker must still run in Studio)")


def finish() -> int:
    failed = sum(1 for ok, _ in results if not ok)
    print(f"[offline checks] {len(results) - failed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
