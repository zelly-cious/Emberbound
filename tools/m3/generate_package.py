#!/usr/bin/env python3
"""Deterministic M3 test package. Reads the pinned Git blobs, never working-tree source.

Run from any directory: python3 tools/m3/generate_package.py [--check]
The M2 installer/guide remain historical. This package supersedes them for M3 QA.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
VERSION = "3.0.0-qa.1"
HISTORICAL_RELEASE = "227962341facb26ddc6eb074ca7e49018dfc7acb"
spec = importlib.util.spec_from_file_location("m2_installer", HERE.parent / "m2/generate_installer.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def source_commit() -> str:
    pin = (HERE / "SOURCE_COMMIT.txt").read_text().strip()
    if not re.fullmatch(r"[0-9a-f]{40}", pin):
        raise ValueError("SOURCE_COMMIT.txt must hold one full commit SHA")
    if base.git(REPO, "rev-parse", f"{pin}^{{commit}}").decode().strip() != pin:
        raise ValueError("source pin did not resolve exactly")
    base.git(REPO, "merge-base", "--is-ancestor", pin, "HEAD")
    return pin


def load_sources() -> list[dict]:
    pin = source_commit()
    paths = base.git(REPO, "ls-tree", "-r", "--name-only", pin, "src").decode().splitlines()
    if len(paths) != 34 or any(not p.endswith(".luau") for p in paths):
        raise ValueError("M3 source must contain exactly 34 Luau files")
    files = []
    for path in sorted(paths):
        data = base.git(REPO, "show", f"{pin}:{path}")
        if data != base.normalize(data):
            raise ValueError(f"source is not LF-normalized: {path}")
        explorer = path.removeprefix("src/").removesuffix(".luau")
        kind = "ModuleScript"
        if explorer in ("ServerScriptService/ServerInit", "ServerScriptService/Tests/TestRunner"):
            kind = "Script"
        elif explorer == "StarterPlayer/StarterPlayerScripts/CombatClient":
            kind = "LocalScript"
        files.append(dict(path=explorer, className=kind, data=data,
                          sha256=hashlib.sha256(data).hexdigest(), bytes=len(data),
                          lines=data.count(b"\n"), adler32=base.adler32(data)))
    return files


def installer_template() -> str:
    template = (HERE.parent / "m2/InstallM2.template.lua").read_text(encoding="ascii")
    template = template.replace("Milestone 2", "Milestone 3").replace("[M2 Installer]", "[M3 Installer]")
    template = template.replace("M2-TOOLS-001", "M3 test package").replace("Emberbound_M2_QA", "Emberbound_M3_QA")
    template = template.replace("the 24 Milestone 3 scripts", "the {{FILE_COUNT}} Milestone 3 scripts")
    template = template.replace("classCounts.ModuleScript ~= 21", "classCounts.ModuleScript ~= 31")
    template = template.replace("and 21 ModuleScripts", "and 31 ModuleScripts")
    template = template.replace("round 4 (BigNum DEFECT-001/001B adoption)", "round 5 (M2.1 + M3)")
    template = template.replace("tools/m2/generate_installer.py", "tools/m3/generate_package.py")
    template = template.replace("tools/m2/INSTALL_INSTRUCTIONS.md", "tools/m3/README.md")
    template = template.replace("Appendix B checker in M2_STUDIO_REGRESSION_GUIDE.md", "checker in tools/m3/VerifyM3.lua")
    template = template.replace("Appendix B parity checker from M2_STUDIO_REGRESSION_GUIDE.md", "parity checker from tools/m3/VerifyM3.lua")
    template = template.replace("Appendix A of M2_STUDIO_REGRESSION_GUIDE.md", "tools/m3/STUDIO_GUIDE.md")
    return template


def parity_checker(files: list[dict]) -> str:
    # Keep the independently executed M2 verifier logic, with a new expected table/count.
    guide = base.git(REPO, "show", f"{HISTORICAL_RELEASE}:M2_STUDIO_REGRESSION_GUIDE.md").decode()
    section = guide[guide.index("## Appendix B"):]
    checker = re.search(r"```lua\n(.*?)\n```", section, re.S).group(1)
    rows = "\n".join(f'\t{{ "{f["path"]}", "{f["className"]}", {f["bytes"]}, {f["lines"]}, {f["adler32"]} }},' for f in files)
    checker, count = re.subn(r"local E = \{\n.*?\n\}", "local E = {\n" + rows + "\n}", checker, count=1, flags=re.S)
    if count != 1 or checker.count("matched == 24") != 1:
        raise ValueError("historical parity checker shape changed")
    checker = checker.replace("%d / 24", f"%d / {len(files)}").replace("matched == 24", f"matched == {len(files)}")
    return f"-- M3 source {source_commit()}; edit mode, read only.\n" + checker + "\n"


def build() -> dict[Path, bytes]:
    pin = source_commit()
    files = load_sources()
    lua = base.render(installer_template(), files, frozen_commit=pin, installer_version=VERSION)
    base.verify_output(lua, files)
    parity = parity_checker(files)
    manifest = ["# Emberbound M3 test installer manifest (generated; do not edit)",
                f"installer_version {VERSION}", f"frozen_commit {pin}",
                f"installer_bytes {len(lua.encode('ascii'))}",
                f"installer_sha256 {hashlib.sha256(lua.encode('ascii')).hexdigest()}",
                f"parity_sha256 {hashlib.sha256(parity.encode()).hexdigest()}", "",
                "# sha256, bytes, lines, adler32, class, Explorer path"]
    for f in files:
        manifest.append(f"{f['sha256']}  {f['bytes']}  {f['lines']}  {f['adler32']}  {f['className']}  {f['path']}")
    historical = base.git(REPO, "show", f"{HISTORICAL_RELEASE}:SOURCE_HASHES.txt").decode()
    historical = historical[historical.index("## Round 4"):].replace("(24 files; current)", "(24 files; historical)", 1)
    hashes = (base.MANIFEST_TITLE + f"\n\n## Round 5 — M2.1 and M3, source commit {pin[:7]} (34 files; current)\n\n"
              + f"Test candidate source: `{pin}`. Automated results and pending Studio checkpoint: review/m3/M3_IMPLEMENTATION_RESULTS.md.\n\n"
              + "\n".join(f"{f['sha256']}  src/{f['path']}.luau" for f in files) + "\n\n" + historical)
    layout = ["# M3 Studio source reference", "", f"Pinned source: `{pin}`. **34 files, 6 RemoteEvents, 3 folders.**",
              "", "Install and checkpoint instructions: [README](README.md).",
              "Expected TestRunner summary: `[Tests] ALL PASSED (123 tests)` in 11 suites.", "",
              "| Explorer path | Class | Bytes | Lines | Adler-32 | SHA-256 |",
              "|---|---|---:|---:|---:|---|"]
    layout += [f"| `{f['path']}` | {f['className']} | {f['bytes']} | {f['lines']} | {f['adler32']} | `{f['sha256']}` |" for f in files]
    return {HERE / "InstallM3.lua": lua.encode("ascii"),
            HERE / "VerifyM3.lua": parity.encode(),
            HERE / "INSTALLER_MANIFEST.txt": ("\n".join(manifest) + "\n").encode(),
            HERE / "STUDIO_GUIDE.md": ("\n".join(layout) + "\n").encode(),
            REPO / "SOURCE_HASHES.txt": hashes.encode()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    outputs = build()
    bad = False
    for path, data in outputs.items():
        if args.check:
            same = path.exists() and path.read_bytes() == data
            print(("PASS " if same else "FAIL ") + str(path.relative_to(REPO)))
            bad |= not same
        else:
            path.write_bytes(data)
            print("Wrote", path.relative_to(REPO))
    return int(bad)


if __name__ == "__main__":
    raise SystemExit(main())
