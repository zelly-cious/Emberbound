# M2-STUDIO-001 / DEFECT-001 — BigNumTests.luau:364 fails in Roblox Studio

| | |
|---|---|
| Studio result (reported) | `[Tests] 1 FAILED, 60 passed`. `BigNumTests > the smallest positive doubles work in arithmetic`, `BigNumTests.luau:364: dividing back gives 5e-324, not zero` |
| Codex reproduction (reported) | The same 60/1 outcome with the unchanged frozen sources in Luau 0.745, with flush-to-zero (FTZ) on and denormals-are-zero (DAZ) off |
| Frozen source | `e9d878d94155610558c9c6252d76f202dfd956b4`, **unchanged** (`SOURCE_HASHES.txt` round 3 is not modified) |
| Candidate | branch `candidate/m2-defect-001-ftz-subnormal`, based on PR #1 head `2b832d2` (whose `src/` equals `e9d878d`) |
| Status | **Candidate only.** Offline evidence is complete; the Studio probe output has **not** been obtained yet (section 1). Not reviewed, not merged, Milestone 2 not complete. |

## 1. Evidence status: read this first

The task asked for the read-only Studio probe output **before** implementing. The author of this candidate cannot run Roblox Studio, and no probe output exists in the repository, PR #1, or the issue tracker. So:

- **Not obtained:** the Studio probe output. Until it exists, these are unconfirmed on the real Studio build:
  - that Studio's FP mode is FTZ without DAZ;
  - that the failing division returns the fields `m = 0, e = 0`;
  - that `tonumber` on that build keeps 5e-324;
  - what lines 365–375 do (they never ran in Studio, because `expectTrue` at line 364 raised and ended the test).
- **Prepared:** the read-only probe (`review/ftz-harness/studio_probe.lua`, section 8), plus its expected output under gradual underflow and FTZ, for the frozen and the candidate code.
- **Implemented anyway, as a gated candidate:** the correction below. Every offline signature matches the reported Studio failure exactly (60/1, line 364, quotient fields `0, 0`). Its acceptance still depends on the probe: if the Studio output differs from the FTZ signature in section 8, investigate that difference first and do not adopt this candidate.

## 2. Offline reproduction (no Studio)

**C, glibc, x86-64 SSE: the exact failing step.** Run `review/ftz-harness/signature.c` with `gcc -msse3 signature.c -lm && ./a.out`.

| Mode | toScientific mantissa | `m * 10^-24` | `* 1e-300` | `strtod("4.9406564584124659e-324")` |
|---|---|---|---|---|
| gradual (default) | 4.9406564584124659 | 4.9406564584124657e-24 | **4.9406564584124654e-324** (= 5e-324) | 5e-324 |
| FTZ on, DAZ off | 4.9406564584124659 | 4.9406564584124657e-24 | **0** | **5e-324** (decimal parsing is not flushed) |

**The real modules under FTZ.** These are the frozen sources translated to Lua 5.1, running with the CPU in FTZ (`review/ftz-harness/README.md`):

| Frozen `e9d878d` | gradual | FTZ on, DAZ off |
|---|---|---|
| 61 unit tests (shipped `TestRunner`) | 61/61 | **60 passed, 1 failed at `BigNumTests.luau:364`**, identical to Studio |
| 75 review probes | 75/75 | 74/75: `5e-324 * 1e400 divided by 1e400 is 5e-324 again` fails |
| Probe: quotient fields | `m = 4.9406564584124654e-324, e = 0` | **`m = 0, e = 0`** (a valid BigNum zero) |
| Probe: lines 365–375 run separately | all as expected | all as expected, including the decimal round trip at line 374 |

## 3. Root cause

`BigNum.div(product, 1e400)` reaches `tryNormalize(4.9406564584124659, -324)`, which calls `multiplyByPowerOfTen(m, -324)` (`BigNum.luau:64` at `e9d878d`): `m * 10^(power + 300) * 1e-300`. The last multiplication has an exactly representable subnormal result. With gradual underflow it returns 5e-324; with FTZ the hardware returns 0. `tryNormalize` then stores `make(0, 0)`, so `BigNum.eq(quotient, tiny)` is false. Nothing else in the F4 test depends on the FP mode.

## 4. Correction (candidate)

`src/ReplicatedStorage/Shared/BigNum.luau`, `multiplyByPowerOfTen` only:

```diff
 local function multiplyByPowerOfTen(m: number, power: number): number
 	if power < -300 then
-		return m * 10 ^ (power + 300) * 1e-300
+		local value = m * 10 ^ (power + 300) * 1e-300
+		if value == 0 and m > 0 then
+			value = tonumber(string.format("%.17ge%.0f", m, power)) or 0
+		end
+		return value
 	end
 	return m * 10 ^ power
 end
```

plus a comment explaining DEFECT-001.

- **Narrow gate.** The fallback runs only when the product for a power below −300 came out exactly 0 from a positive mantissa. Every non-zero result, every power ≥ −300, the representation, `eq` and every other function are unchanged. With gradual underflow, the fallback can only run for a genuine underflow, where `tonumber` also returns 0.
- **Rebuild.** `"%.17ge%.0f"` is the same text form as `BigNum.toString`. 17 digits identify the double exactly, and `tonumber` rounds the decimal value correctly. It returns 0 only below half of 5e-324, so genuine mathematical underflow is preserved.

## 5. Regression tests added (`BigNumTests.luau`, after the existing tests; line 364 is unchanged)

1. **"subnormal results rebuilt from scientific form are not flushed to zero"** checks exact values through the scientific path:
   - the smallest positive double, and a value that rounds up to it;
   - 2× the smallest positive double, 1e-320, 1.5e-317, 1e-310, 1.5e-310 and 3e-310;
   - half the smallest normal.

   Every expected value is exact in **both** FP modes, checked offline.
2. **"the normal boundary and genuine underflow are unchanged"** covers three cases:
   - The smallest normal is exact.
   - The largest subnormal is one of the two neighbouring doubles and never zero; see limitation 7.2 for why this one is not an exact value.
   - Five genuine underflows (1e-324, 2e-324, 2.4e-324, 5e-330, 1e-430) are zero.

The suite now has 63 tests in 7 suites: the original 61 plus 2. No existing assertion was changed, skipped or relaxed.

## 6. Results (offline only)

| Run | gradual | FTZ on, DAZ off |
|---|---|---|
| Candidate: all unit tests via the shipped `TestRunner` | **63/63** | **63/63** |
| Candidate: 75 review probes (M1 formulas, cost curves, two-player server simulation, BigNum fuzz, F1–F6 checks) | **75/75** | **75/75** |
| Control: candidate tests against the **frozen** BigNum | 63/63 (the new tests encode no behaviour change) | 3 failures: line 364 and both new tests (they detect the defect) |
| Differential, frozen vs candidate, about 20,800 operations | **all identical** | identical except 3 results: frozen 0, candidate the correct subnormal; no other difference |

## 7. Limitations: what this candidate does NOT do

1. **Native small-value fast paths still flush under FTZ.** Operations whose operands are both in the small regime compute directly on doubles and never call `multiplyByPowerOfTen`; the same holds for `ratio` and for the small branches of `fromLog10` and `scaledPower`. On an FTZ host, a subnormal result from these becomes 0. The differential measured this on the candidate (gradual vs FTZ):

   | Operation | mul | ratio | div | add | fromLog10 | sub | trySub | scaledPower |
   |---|---|---|---|---|---|---|---|---|
   | Results that become 0 under FTZ | 127 | 71 | 68 | 44 | 37 | 20 | 20 | 10 |

   This candidate therefore does **not** provide universal subnormal support. Gameplay values (HP, Gold, damage, costs) are 0 or at least 1, and `ratio` only drives the clamped health bar (R2-2), so no gameplay result is affected. Making those paths FP-mode-independent would be a separate, larger change.
2. **Host-dependent last step near the normal boundary.** In the upper subnormal range, the gradual-underflow two-step product can double-round one subnormal step (4.9e-324) away from the decimal rebuild. Example: `2.2250738585072009e-14 / 1e294` gives the smallest normal under gradual underflow, but the largest subnormal under FTZ with this candidate. Similarly, `2.2250738585072e-14 / 1e294` gives `…072004e-308` vs `…071999e-308`, where the FTZ value is the closer one. Results stay within one step and never become zero, as allowed by the approved bounded precision contract. The tests assert exact values only where both modes agree.
3. **The fallback depends on `tonumber` keeping subnormals on the Studio build.** glibc does; Studio's C runtime is unverified (probe line `candidate rebuild …`). If it flushes, this candidate does **not** fix Studio. In that case, the probe also reports whether `string.pack`/`string.unpack` is available, as the basis for a bit-level alternative.
4. **DAZ or ARM flush-to-zero** (which also treats subnormal inputs as zero) is not handled. The probe reports this as "subnormal inputs read as 0 (DAZ)". Studio's reported failure point, after the earlier assertions passed, suggests DAZ is off, but that is unverified.
5. **Offline harness limits.** It translates Luau to Lua 5.1, so Luau's compiler and type checker did not run. It uses glibc and x86-64 SSE only. `luau-compile` and `luau-analyze` were not available. The change is one `tonumber(...) or 0` expression that should satisfy strict mode, but that is unverified until the Luau tools run.

## 8. Studio probe: required before review

The probe is read-only: it only reads values and requires the already installed `ReplicatedStorage.Shared.BigNum`. It creates, changes and deletes nothing, and uses `FindService`/`FindFirstChild`, so it never creates or waits for objects. Use the QA place where the frozen M2 is installed.

1. Copy `review/ftz-harness/studio_probe.lua` (all of it).
2. **Edit mode:** paste it into the Command Bar and run it (Enter, or Ctrl+Enter / Cmd+Enter in the multi-line Command Bar). Copy every `[DEFECT-001 probe]` line.
3. **Play mode, Server view:** press Play, switch to the Server view, paste and run it again. Copy the lines. This is the closest Command Bar context to where `TestRunner` ran.
4. If step 3 reports `GRADUAL UNDERFLOW` even though the unit tests failed, the Command Bar runs with a different FP mode than scripts do. In that case:
   1. Stop.
   2. Add a temporary Script `DefectProbe` in ServerScriptService with the same text.
   3. Press Play and copy the Output.
   4. Stop, and **delete `DefectProbe`**. P-5 parity will flag it otherwise.

**Expected signatures**, from `run_probe_offline.py`:

| Line | Frozen, FTZ (the reported failure) | Candidate, FTZ |
|---|---|---|
| `mode verdict` | `FLUSH-TO-ZERO … \| … subnormal inputs kept (no DAZ)` | same |
| `tonumber 4.9406564584124659e-324` | `-> 4.9406564584124654e-324 ==5e-324 true` | same |
| `candidate rebuild …` | `==5e-324 true` | same |
| `fields quotient` | **`m=0 e=0 valid=true zero=true`** | `m=4.9406564584124654e-324 e=0 valid=true zero=false` |
| `line 364 …` | `false` | `true` |
| `line 374 parse(toString(tiny)) == tiny` | `… eq=true` | `… eq=true` |
| `fields fast add(tiny,tiny)` | `m=0 e=0` | `m=0 e=0` (limitation 7.1) |

**Decision rules:**

- **Signature confirmed:** `FLUSH-TO-ZERO`, no DAZ, quotient `m=0 e=0`, `candidate rebuild … true`. Validate the candidate in Studio:
  1. In a **disposable copy** of the QA place, replace the text of `BigNum` and `BigNumTests` with the candidate files.
  2. Press Play and expect `[Tests] ALL PASSED (63 tests)`.
  3. Appendix B will then report those two scripts as changed. That is expected for the copy, and is why updated pins and parity tables need a separate reviewed revision.
- **Quotient fields other than `m=0 e=0`, or DAZ reported:** the signature differs. Investigate before using this candidate.
- **`candidate rebuild … false`:** Studio's decimal parser also flushes, so this candidate does not fix Studio. Report it, together with the `string.pack/unpack` line.

## 9. Candidate source hashes (NOT applied to any manifest)

| File | Frozen SHA-256 (round 3) | Candidate SHA-256 | Candidate bytes / lines / Adler-32 |
|---|---|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | `c7474136d45bada326484a786fd60ff5ca02a18a12b4012fbcfca01a3950244a` | `31b0b589f53936adbf8f22979c290801f51290e749dba97c5e281019616cc5a0` | 15588 / 518 / 464395072 |
| `src/ServerScriptService/Tests/BigNumTests.luau` | `0c13e4842d1420b285243e824c012bca32cbe13e09df278af53ae709d914d97a` | `331827340044ed2e4b001c6c4bc764e0049b32b8500932d7cb406df2e28f50b2` | 16239 / 426 / 644517531 |
| Other 22 files | unchanged (equal to round 3) | — | — |

Deliberately **not** changed on this branch:
- `SOURCE_HASHES.txt` (the approved frozen manifest);
- `M2_STUDIO_REGRESSION_GUIDE.md` (Appendix A/B parity tables, the expected 61-test count);
- the M2 installer payload on `feature/m2-tools-001-installer`;
- every milestone document.

Adopting the candidate requires a separate reviewed revision that updates the source pin, the manifest (a new round, keeping round 3 as history), the parity tables, the installer payload and the expected test count (63).
