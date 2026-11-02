# review/ftz-harness — flush-to-zero reproduction for DEFECT-001

Review tooling only; nothing here is game code or installed in Studio. It exists to reproduce and check M2-STUDIO-001 / DEFECT-001 (`BigNumTests.luau:364` fails in Roblox Studio) without Roblox Studio and without a Luau binary.

| File | Purpose |
|---|---|
| `signature.c` | The failing BigNum step in plain C doubles, run with gradual underflow, FTZ, and FTZ+DAZ (`gcc -msse3 signature.c -lm`). |
| `ftz_preload.c` | `LD_PRELOAD` helper: sets the x86-64 MXCSR flush-to-zero bit (FTZ on, DAZ off) before the interpreter starts. |
| `luau51.py` | Translates the Luau used by Emberbound into plain Lua 5.1: removes types and casts, rewrites if-expressions, interpolation, compound assignment and generalized iteration. Line numbers are preserved. It refuses Luau constructs it does not handle. |
| `prelude.lua` | The Luau library pieces the code needs (`table.freeze` for BigNum values, `table.find/clone/create/clear/move`, `string.split`, `math.clamp`, `typeof`, Luau-style `tostring`, generalized iteration). |
| `run_matrix.py` | Builds the same bundle as `review/offline-harness/run.sh` (translated) and runs the shipped `TestRunner` (`unit`) and the review probes (`probes`) with gradual underflow and with FTZ. |
| `differential.py` | Runs about 20,800 deterministic BigNum operations through the frozen and the candidate BigNum in both modes and classifies every difference. |
| `studio_probe.lua` | **Read-only Studio probe** for the Command Bar (see `review/DEFECT-001_REPORT.md`, section 8). |
| `run_probe_offline.py` | Runs `studio_probe.lua` offline in both modes, to show the output Studio is expected to print. |

```bash
python3 review/ftz-harness/run_matrix.py --source e9d878d94155610558c9c6252d76f202dfd956b4   # frozen sources
python3 review/ftz-harness/run_matrix.py --source worktree                                    # candidate
python3 review/ftz-harness/differential.py
python3 review/ftz-harness/run_probe_offline.py worktree
```

Requirements: `lua5.1`, `gcc`, Python 3, and an x86-64 CPU (the FTZ bit is an SSE control bit).

## Why the translation can be trusted for this question, and its limits

Luau and Lua 5.1 both compute with C doubles, so with the same CPU mode the arithmetic is the same machine arithmetic; only the syntax differs. The translation is validated by reproducing known results before it is used for anything new:

| Frozen `e9d878d` | Known result | Harness result |
|---|---|---|
| unit tests, gradual underflow | 61/61 (offline Luau CLI runs) | **61/61** |
| review probes, gradual underflow | 75/75 (offline Luau CLI runs) | **75/75** |
| unit tests, FTZ on and DAZ off | 60 passed, 1 failed at `BigNumTests.luau:364` (Roblox Studio as reported; Codex with Luau 0.745) | **60 passed, 1 failed at `BigNumTests.luau:364`** |

Limits:
- **Decimal parsing.** `tonumber` here is glibc `strtod`; Studio uses its own C runtime.
- **No engine.** It is not Luau, so there is no Luau compiler constant folding and no Luau type checking.
- **Freezing.** `table.freeze` is emulated only for BigNum values.
- **Platform.** It cannot model Roblox Studio itself or ARM hosts. ARM's flush-to-zero also flushes subnormal inputs.

The Studio probe exists to close these gaps on the real build.
