#!/usr/bin/env python3
"""Run Emberbound's unit tests and review probes under gradual underflow and flush-to-zero.

Review tooling only (DEFECT-001 / M2-STUDIO-001). Builds the same bundle as
review/offline-harness/run.sh, but translated to Lua 5.1 by luau51.py, and runs it with plain
lua5.1, either normally (gradual underflow) or with ftz_preload.so (FTZ on, DAZ off), which sets
the x86-64 MXCSR flush-to-zero bit before the interpreter starts.

    python3 review/ftz-harness/run_matrix.py --source e9d878d94155610558c9c6252d76f202dfd956b4
    python3 review/ftz-harness/run_matrix.py --source worktree

None of this is Roblox Studio. It reproduces the floating-point mode, not the engine.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import luau51  # noqa: E402

REPO = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"]).decode().strip())
M1_BASELINE = "730218a"
AUDITED = "024cd68"
HARNESS = "review/offline-harness"


def git_show(ref: str, path: str) -> str:
    return subprocess.check_output(["git", "-C", str(REPO), "show", f"{ref}:{path}"]).decode()


def sources(source: str) -> dict[str, str]:
    if source == "worktree":
        files = sorted(p for d in ("ReplicatedStorage", "ServerScriptService") for p in (REPO / "src" / d).rglob("*.luau"))
        return {str(p.relative_to(REPO / "src"))[: -len(".luau")]: p.read_text() for p in files}
    names = subprocess.check_output(["git", "-C", str(REPO), "ls-tree", "-r", "--name-only", source, "src/ReplicatedStorage", "src/ServerScriptService"]).decode().split()
    return {n[len("src/"): -len(".luau")]: git_show(source, n) for n in sorted(names) if n.endswith(".luau")}


def ftz_library(workdir: Path) -> Path:
    library = workdir / "ftz_preload.so"
    subprocess.run(["gcc", "-shared", "-fPIC", "-O2", "-o", str(library), str(HERE / "ftz_preload.c")], check=True)
    return library


def bundle(source: str, entry: str, harness_ref: str) -> str:
    parts = [(HERE / "prelude.lua").read_text(), "local SOURCES = {}"]

    def add(key: str, text: str) -> None:
        translated = luau51.translate(text)
        assert "]==========]" not in translated
        parts.append(f'SOURCES["{key}"] = [==========[\n{translated}]==========]')

    for key, text in sources(source).items():
        add(key, text)
    add("M1/ReplicatedStorage/Shared/GameConfig", git_show(M1_BASELINE, "src/ReplicatedStorage/Shared/GameConfig.luau"))
    add("AUDITED/ReplicatedStorage/Shared/BigNum", git_show(AUDITED, "src/ReplicatedStorage/Shared/BigNum.luau"))
    parts.append(luau51.translate(git_show(harness_ref, f"{HARNESS}/roblox_shim.luau")))
    parts.append(luau51.translate(git_show(harness_ref, f"{HARNESS}/{entry}.luau")))
    return "\n".join(parts) + "\n"


def run(source: str, entry: str, mode: str, library: Path, workdir: Path, harness_ref: str) -> tuple[int, str]:
    path = workdir / f"bundle_{entry}.lua"
    path.write_text(bundle(source, entry, harness_ref))
    env = {"PATH": "/usr/bin:/bin"}
    if mode == "ftz":
        env["LD_PRELOAD"] = str(library)
    result = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True, env=env)
    return result.returncode, result.stdout + result.stderr


def summarize(entry: str, output: str) -> str:
    if entry == "unit":
        verdict = re.findall(r"\[Tests\] (ALL PASSED \(\d+ tests\)|\d+ FAILED, \d+ passed)", output)
        fails = re.findall(r"\[Tests\] FAIL (.*)", output)
        return (verdict[-1] if verdict else "no verdict") + "".join(f"\n      FAIL {f}" for f in fails)
    totals = re.findall(r"\[Probes\] total: (\d+) passed, (\d+) failed", output)
    fails = re.findall(r"^\s*FAIL (.*)$", output, re.M)
    head = f"{totals[-1][0]} passed, {totals[-1][1]} failed" if totals else "no total"
    return head + "".join(f"\n      FAIL {f}" for f in fails)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True, help="a git commit for src/, or 'worktree'")
    parser.add_argument("--harness-ref", default="HEAD", help="commit holding review/offline-harness (default HEAD)")
    parser.add_argument("--entries", default="unit,probes")
    parser.add_argument("--modes", default="gradual,ftz")
    parser.add_argument("--show", action="store_true", help="print the full output of every run")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        library = ftz_library(workdir)
        for mode in args.modes.split(","):
            for entry in args.entries.split(","):
                code, output = run(args.source, entry, mode, library, workdir, args.harness_ref)
                if args.show:
                    print(output)
                print(f"[{mode:7}] {entry:6} exit={code} {summarize(entry, output)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
