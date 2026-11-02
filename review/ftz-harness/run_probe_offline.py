#!/usr/bin/env python3
"""Run studio_probe.lua offline (Lua 5.1, gradual and FTZ) against a BigNum from git or the work tree.

Review tooling only. Produces the probe output Studio is expected to print under each
floating-point mode, so the real Studio output can be compared line by line.

    python3 review/ftz-harness/run_probe_offline.py e9d878d94155610558c9c6252d76f202dfd956b4
    python3 review/ftz-harness/run_probe_offline.py worktree
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import luau51  # noqa: E402
import run_matrix  # noqa: E402

FAKE_GAME = """
local bigNumModule = {}
local function node(children) return { FindFirstChild = function(self, name) return children[name] end } end
local services = {
	Players = { LocalPlayer = nil },
	RunService = { IsRunning = function() return false end },
	ReplicatedStorage = node({ Shared = node({ BigNum = bigNumModule }) }),
}
game = { FindService = function(self, name) return services[name] end }
function require(module) assert(module == bigNumModule) return BIGNUM end
"""


def main() -> int:
    source = sys.argv[1] if len(sys.argv) > 1 else "worktree"
    if source == "worktree":
        bignum = (run_matrix.REPO / "src/ReplicatedStorage/Shared/BigNum.luau").read_text()
    else:
        bignum = run_matrix.git_show(source, "src/ReplicatedStorage/Shared/BigNum.luau")
    chunk = "\n".join([
        (HERE / "prelude.lua").read_text(),
        "BIGNUM = (function()\n" + luau51.translate(bignum) + "\nend)()",
        FAKE_GAME,
        (HERE / "studio_probe.lua").read_text(),
    ])
    with tempfile.TemporaryDirectory() as tmp:
        library = run_matrix.ftz_library(Path(tmp))
        path = Path(tmp) / "probe.lua"
        path.write_text(chunk)
        for mode in ("gradual", "ftz"):
            env = {"PATH": "/usr/bin:/bin"}
            if mode == "ftz":
                env["LD_PRELOAD"] = str(library)
            result = subprocess.run(["lua5.1", str(path)], capture_output=True, text=True, env=env)
            print(f"===== {mode} ({source}) =====")
            print((result.stdout + result.stderr).rstrip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
