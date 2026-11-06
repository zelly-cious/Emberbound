# review/ftz-harness — flush-to-zero reproduction for DEFECT-001

Review tooling only; nothing here is game code or installed in Studio. It reproduces and checks M2-STUDIO-001 without Roblox Studio and without a Luau binary:
- DEFECT-001: `BigNumTests.luau:364` fails in Roblox Studio;
- DEFECT-001B: the canonical text of a subnormal reads back as zero, `BigNumTests.luau:374`.

| File | Purpose |
|---|---|
| `signature.c` | The failing BigNum step in plain C doubles, run with gradual underflow, FTZ, and FTZ+DAZ (`gcc -msse3 signature.c -lm`). |
| `ftz_preload.c` | `LD_PRELOAD` helper: sets the x86-64 MXCSR flush-to-zero bit (FTZ on, DAZ off) before the interpreter starts. |
| `luau51.py` | Translates the Luau used by Emberbound into plain Lua 5.1: removes types and casts, rewrites if-expressions, interpolation, compound assignment and generalized iteration. Line numbers are preserved. It refuses Luau constructs it does not handle. |
| `prelude.lua` | The Luau library pieces the code needs:<br>• `table.freeze` for BigNum values, and `table.find/clone/create/clear/move`;<br>• `string.split`, `math.clamp`, `typeof`, generalized iteration;<br>• Luau-style shortest `tostring`;<br>• `buffer` (`create`, `writeu32`, `readu32`, `readf64`).<br>It also holds the **modeled Studio formatter** (`FTZ_HARNESS_WINDOWS_FORMAT=1`): subnormal arguments of `e/f/g` conversions print as 0, as Studio printed `%.17g` of 5e-324. |
| `run_matrix.py` | Builds the same bundle as `review/offline-harness/run.sh` (translated). It runs the shipped `TestRunner` (`unit`) and the review probes (`probes`) in the modes `gradual`, `ftz`, `ftz-winfmt` (FTZ plus the formatter model, the closest model of Studio) and `winfmt`. It prints a self-check line per mode. `--override PATH=REF` takes one source file from a git ref, for negative controls. |
| `differential.py` | Runs 24,000 deterministic BigNum operations per mode through the frozen (`e9d878d`), prior candidate (`8626bc7`) and work-tree BigNum, and classifies every difference. It also checks `parse(toString(x)) == x` and that the text is idempotent. |
| `studio_probe.lua` | **Read-only Studio probe v2** for the Command Bar (see `review/DEFECT-001B_REPORT.md`, section 9). |
| `run_probe_offline.py` | Runs `studio_probe.lua` offline in every mode (or the ones given), to show the output Studio is expected to print. |

```bash
python3 review/ftz-harness/run_matrix.py --source e9d878d94155610558c9c6252d76f202dfd956b4 --modes gradual,ftz,ftz-winfmt,winfmt   # frozen
python3 review/ftz-harness/run_matrix.py --source worktree --modes gradual,ftz,ftz-winfmt,winfmt                                    # candidate
python3 review/ftz-harness/run_matrix.py --source worktree --override src/ReplicatedStorage/Shared/BigNum.luau=8626bc7 --entries unit  # control
python3 review/ftz-harness/differential.py
python3 review/ftz-harness/run_probe_offline.py e9d878d94155610558c9c6252d76f202dfd956b4 ftz-winfmt
```

Requirements: `lua5.1`, `gcc`, Python 3, and an x86-64 CPU (the FTZ bit is an SSE control bit).

## Why the translation can be trusted for this question, and its limits

Luau and Lua 5.1 both compute with C doubles, so with the same CPU mode the arithmetic is the same machine arithmetic; only the syntax differs. The translation is validated by reproducing known results before it is used for anything new:

| Frozen `e9d878d` | Known result | Harness result |
|---|---|---|
| unit tests, gradual underflow | 61/61 (offline Luau CLI runs) | **61/61** |
| review probes, gradual underflow | 75/75 (offline Luau CLI runs) | **75/75** |
| unit tests, FTZ on and DAZ off | 60 passed, 1 failed at `BigNumTests.luau:364` (Roblox Studio as reported; Codex with Luau 0.745) | **60 passed, 1 failed at `BigNumTests.luau:364`** |
| prior candidate `8626bc7`, FTZ plus formatter model | line 364 passes and line 374 is the next failure (Studio diagnostic, reported) | **62 passed, 1 failed at `BigNumTests.luau:374`** |

Limits:
- **Decimal parsing.** `tonumber` here is glibc `strtod`; Studio uses its own C runtime.
- **Formatting.** glibc `printf` keeps subnormals even with FTZ, so plain `ftz` mode does not show DEFECT-001B. The `winfmt` modes model the Studio output. The model is inferred from one observed value (5e-324) and assumes every subnormal behaves the same way.
- **Translator.** Multi-line if-expressions are supported. The change was checked to translate all 54 earlier files (the `e9d878d` and `8626bc7` sources, plus the harness) byte-identically.
- **No engine.** It is not Luau, so there is no Luau compiler constant folding and no Luau type checking.
- **Freezing.** `table.freeze` is emulated only for BigNum values.
- **Platform.** It cannot model Roblox Studio itself or ARM hosts. ARM's flush-to-zero also flushes subnormal inputs.

The Studio probe exists to close these gaps on the real build.
