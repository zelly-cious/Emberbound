#!/usr/bin/env python3
"""Run Emberbound's unit tests and review probes under each modeled floating-point mode.

Review tooling only (DEFECT-001 / DEFECT-001B / M2-STUDIO-001). Builds the same bundle as
review/offline-harness/run.sh, but translated to Lua 5.1 by luau51.py, and runs it with plain
lua5.1 in these modes:

    gradual     IEEE-754 gradual underflow (the default on Linux and macOS hosts)
    ftz         ftz_preload.so sets the x86-64 MXCSR flush-to-zero bit (FTZ on, DAZ off)
    ftz-winfmt  FTZ plus the modeled Studio string.format failure: subnormal arguments of
                e/f/g conversions print as 0 (prelude.lua, FTZ_HARNESS_WINDOWS_FORMAT=1).
                This is the closest model of the observed Studio Edit-mode behaviour.
    winfmt      the formatter model alone (supplementary, isolates DEFECT-001B)

    python3 review/ftz-harness/run_matrix.py --source e9d878d94155610558c9c6252d76f202dfd956b4
    python3 review/ftz-harness/run_matrix.py --source worktree
    python3 review/ftz-harness/run_matrix.py --source worktree \
        --override src/ReplicatedStorage/Shared/BigNum.luau=8626bc7   # negative control

None of this is Roblox Studio. It reproduces the floating-point mode and the observed formatter
output, not the engine.
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


MODES = ("gradual", "ftz", "ftz-winfmt", "winfmt")

MODE_CHECK = r"""
local box = { 5e-324, 1 }
print("[Mode] tiny*1=" .. __rawformat("%.17g", box[1] * box[2])
	.. " format(%.17g,tiny)=" .. string.format("%.17g", box[1])
	.. " tostring(tiny)=" .. tostring(box[1])
	.. " tonumber(5e-324)>0=" .. tostring(tonumber("5e-324") > 0))
"""


def sources(source: str, overrides: dict[str, str] | None = None) -> dict[str, str]:
    if source == "worktree":
        files = sorted(p for d in ("ReplicatedStorage", "ServerScriptService") for p in (REPO / "src" / d).rglob("*.luau"))
        result = {str(p.relative_to(REPO / "src"))[: -len(".luau")]: p.read_text() for p in files}
    else:
        names = subprocess.check_output(["git", "-C", str(REPO), "ls-tree", "-r", "--name-only", source, "src/ReplicatedStorage", "src/ServerScriptService"]).decode().split()
        result = {n[len("src/"): -len(".luau")]: git_show(source, n) for n in sorted(names) if n.endswith(".luau")}
    for path, ref in (overrides or {}).items():
        key = path[len("src/"): -len(".luau")]
        assert key in result, f"override {path} is not a source file"
        result[key] = git_show(ref, path)
    return result


def mode_env(mode: str, library: Path) -> dict[str, str]:
    assert mode in MODES, f"unknown mode {mode}"
    env = {"PATH": "/usr/bin:/bin"}
    if mode in ("ftz", "ftz-winfmt"):
        env["LD_PRELOAD"] = str(library)
    if mode in ("ftz-winfmt", "winfmt"):
        env["FTZ_HARNESS_WINDOWS_FORMAT"] = "1"
    return env


def ftz_library(workdir: Path) -> Path:
    library = workdir / "ftz_preload.so"
    subprocess.run(["gcc", "-shared", "-fPIC", "-O2", "-o", str(library), str(HERE / "ftz_preload.c")], check=True)
    return library


def bundle(source: str, entry: str, harness_ref: str, overrides: dict[str, str] | None = None) -> str:
    parts = [(HERE / "prelude.lua").read_text(), MODE_CHECK, "local SOURCES = {}"]

    def add(key: str, text: str) -> None:
        translated = luau51.translate(text)
        assert "]==========]" not in translated
        parts.append(f'SOURCES["{key}"] = [==========[\n{translated}]==========]')

    for key, text in sources(source, overrides).items():
        add(key, text)
    add("M1/ReplicatedStorage/Shared/GameConfig", git_show(M1_BASELINE, "src/ReplicatedStorage/Shared/GameConfig.luau"))
    add("AUDITED/ReplicatedStorage/Shared/BigNum", git_show(AUDITED, "src/ReplicatedStorage/Shared/BigNum.luau"))
    parts.append(luau51.translate(git_show(harness_ref, f"{HARNESS}/roblox_shim.luau")))
    parts.append(luau51.translate(git_show(harness_ref, f"{HARNESS}/{entry}.luau")))
    return "\n".join(parts) + "\n"


def run(source: str, entry: str, mode: str, library: Path, workdir: Path, harness_ref: str, overrides: dict[str, str] | None = None) -> tuple[int, str]:
    path = workdir / f"bundle_{entry}.lua"
    path.write_text(bundle(source, entry, harness_ref, overrides))
    result = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True, env=mode_env(mode, library))
    return result.returncode, result.stdout + result.stderr


def summarize(entry: str, output: str) -> str:
    if entry == "unit":
        verdict = re.findall(r"\[Tests\] (ALL PASSED \(\d+ tests\)|\d+ FAILED, \d+ passed)", output)
        fails = list(dict.fromkeys(re.findall(r"\[Tests\] FAIL (.*)", output)))  # the runner prints each failure twice
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
    parser.add_argument("--modes", default="gradual,ftz,ftz-winfmt")
    parser.add_argument("--override", action="append", default=[], metavar="PATH=REF",
                        help="take one source file from a git ref, e.g. src/ReplicatedStorage/Shared/BigNum.luau=8626bc7")
    parser.add_argument("--show", action="store_true", help="print the full output of every run")
    args = parser.parse_args()
    overrides = dict(item.split("=", 1) for item in args.override)
    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        library = ftz_library(workdir)
        for mode in args.modes.split(","):
            for entry in args.entries.split(","):
                code, output = run(args.source, entry, mode, library, workdir, args.harness_ref, overrides)
                if args.show:
                    print(output)
                if entry == args.entries.split(",")[0]:
                    print(f"[{mode:10}] " + "".join(re.findall(r"\[Mode\] (.*)", output)[:1]))
                print(f"[{mode:10}] {entry:6} exit={code} {summarize(entry, output)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
