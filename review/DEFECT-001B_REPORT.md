# M2-STUDIO-001 / DEFECT-001B — the smallest subnormal's canonical text reads back as zero in Roblox Studio

| | |
|---|---|
| Studio evidence (owner, Edit mode, Luau `0.745.0.7451137`) | FTZ on, subnormal inputs kept (no DAZ). The frozen division rebuilds 5e-324 as zero. The `tonumber` fallback of the DEFECT-001 candidate works. `BigNum.parse(BigNum.toString(tiny)) == tiny` is **false**. Control: `tostring(tonumber("4.9406564584124654e-324"))` printed `"5e-324" true true` (non-zero, exact round trip). `string.format("%.17g", 5e-324)` printed `"0"`. |
| Frozen source | `e9d878d94155610558c9c6252d76f202dfd956b4`, **unchanged** (`SOURCE_HASHES.txt` round 3 is not modified) |
| Prior candidate | `8626bc70ff905975fbc8069b4f951762f15cdefd` (DEFECT-001: arithmetic rebuild in `multiplyByPowerOfTen`), kept unchanged |
| This candidate | branch `candidate/m2-defect-001-ftz-subnormal`, the commit that adds this report (parent `8626bc7`) |
| Status | **Candidate only.** Offline evidence is complete. The Server Play-mode diagnostic has **not** been supplied, and this candidate has **never run in Roblox Studio**. Not reviewed, not merged, Milestone 2 not complete. |

## 1. Evidence: what is from Studio, and what is offline

**From Studio** (reported by the owner; I did not run Studio):
- the floating-point mode: FTZ on, DAZ off;
- the frozen `BigNum.div` returns zero for the line 364 division;
- `tonumber` keeps 5e-324, so the DEFECT-001 fallback is viable;
- `string.format("%.17g", 5e-324)` returns `"0"`;
- `tostring(5e-324)` returns `"5e-324"`, which reads back as exactly the same double;
- so `parse(toString(tiny))` is zero and `BigNumTests.luau:374` (original line 374) fails once line 364 passes.

**Not from Studio:**
- Server Play-mode behaviour;
- `tostring`, `tonumber` and `string.format` for any subnormal other than 5e-324;
- `string.format` for small normal values near the boundary;
- every result of this candidate.

Probe v2 (section 9) covers these gaps, except the candidate's own test run, which needs a disposable copy of the QA place.

**Offline** (Lua 5.1 on Linux x86-64, review tooling only):
- every result in sections 5 to 7;
- the modeled Studio formatter (section 4).

Linux FTZ alone does **not** reproduce this defect, because glibc's `printf` converts with integer arithmetic. The formatter failure had to be modeled explicitly.

## 2. Root cause

`BigNum.toString` (frozen, unchanged in `8626bc7`) wrote the small regime as `string.format("%.17g", value.m)`. For a positive subnormal `m`, Studio's formatter printed `"0"`. `BigNum.parse("0")` returns `BigNum.zero`, so the canonical text, used for saves and the network, lost the value. Luau's `tostring` uses its own shortest round-trip conversion (`lnumprint.cpp`, integer arithmetic), and Studio printed the subnormal correctly with it.

This is a formatter defect, not an arithmetic one, so the DEFECT-001 arithmetic fix could not cover it. The frozen code never reached the round trip in Studio: the `expectTrue` at line 364 ended the test first.

## 3. Correction (`src/ReplicatedStorage/Shared/BigNum.luau`)

```diff
 	Canonical text (saves and network): "%.17g" of m, plus "e<exponent>" for
-	large values, e.g. "13", "0.5", "1.5e400".
+	large values, e.g. "13", "0.5", "1.5e400". Positive subnormal m (below
+	2.2250738585072014e-308) uses Luau's shortest round-trip tostring instead,
+	e.g. "5e-324" (DEFECT-001B).
@@
 local MAX_TEXT_LENGTH = 64
+local MIN_NORMAL = 2.2250738585072014e-308 -- smallest positive normal double; positive values below it are subnormal
@@
--- Canonical text used for saving and networking. parse(toString(x)) always equals x.
+--[[
+	Canonical text used for saving and networking. parse(toString(x)) always equals x.
+
+	DEFECT-001B: Roblox Studio's string.format printed "0" for the subnormal 5e-324 with
+	"%.17g", so its canonical text read back as zero. Positive subnormals therefore use Luau's
+	tostring, the shortest decimal text that reads back as exactly the same double ("5e-324"),
+	which Studio printed correctly. Zero, normal values and large values keep the "%.17g" text.
+]]
 function BigNum.toString(value: BigNum): string
 	if value.e == 0 then
-		return string.format("%.17g", value.m)
+		local m = value.m
+		if m > 0 and m < MIN_NORMAL then
+			return tostring(m)
+		end
+		return string.format("%.17g", m)
 	end
 	return string.format("%.17ge%.0f", value.m, value.e)
 end
```

What it keeps, and how that was checked:

| Behaviour | Kept? | Evidence |
|---|---|---|
| Zero, normal small values, large values | The text is byte-identical to the frozen `"%.17g"` and `"%.17ge%.0f"` output | Test "canonical text … keeps its existing form" compares every non-subnormal fixture with `string.format` directly. The differential found 0 text differences outside subnormals in 24,000 operations per mode. |
| `BigNum.parse`, `BigNum.eq`, representation and validity | Unchanged code | `parse` already accepts `"5e-324"` and `"2.225073858507201e-308"` through `^(%d+%.?%d*)[eE]([%+%-]?%d+)$` and reads them with one `tonumber(text)` |
| The DEFECT-001 arithmetic fix (`multiplyByPowerOfTen`) | Unchanged | Same lines as `8626bc7` |
| Network contract (canonical strings) | Unchanged for every non-subnormal value. Gameplay values are 0 or at least 1, so they are never subnormal. | Differential: no other difference; 75/75 review probes include the two-player server simulation |
| No reconstruction from logarithms or decimal mantissas | Satisfied: only `tostring` is used | — |

Subnormal text changes form on **every** host, from 17 digits (`"4.9406564584124654e-324"`) to the shortest text (`"5e-324"`). Both forms parse to the same double, and the old form still parses. No persisted data exists, since persistence is Milestone 3.

## 4. Offline model of the Studio formatter (`review/ftz-harness/prelude.lua`)

With `FTZ_HARNESS_WINDOWS_FORMAT=1`, `string.format` replaces every subnormal argument of an `e/E/f/g/G` conversion with 0 before formatting.
- **What it reproduces exactly:** the observed `"0"` for 5e-324.
- **What it assumes:** that every subnormal behaves the same way. That assumption is conservative, because the candidate sends every subnormal through `tostring`.
- **What is unaffected:** `tostring` (Luau-like shortest digits from glibc's integer-arithmetic printf), `tonumber` (glibc `strtod`) and normal values. That matches the observation.

Every run prints a self-check line: `[ftz-winfmt] tiny*1=0 format(%.17g,tiny)=0 tostring(tiny)=5e-324 tonumber(5e-324)>0=true`.

The model is consistent with both Studio observations:

| Source | Model `ftz-winfmt` | Studio (reported) |
|---|---|---|
| frozen `e9d878d` | 60 passed, 1 failed at `BigNumTests.luau:364` | same |
| prior candidate `8626bc7` | 62 passed, 1 failed at `BigNumTests.luau:374` | 364 passes, 374 is the next failure |
| probe, frozen module | `quotient m=0 e=0`, `line 374 … "0" -> 0 eq=false`, `tostring(tiny)=5e-324` | same signature |

## 5. Regression tests (`src/ServerScriptService/Tests/BigNumTests.luau`)

**Original assertions:**
- They are textually unchanged **at their original line numbers**: 364 (`dividing back gives 5e-324, not zero`) and 374 (`5e-324 round-trips through text`).
- Compared with frozen `e9d878d`, the file diff only adds lines; it removes none.
- The candidate tests now follow the original list and are added with `table.insert`. The two DEFECT-001 tests moved out of the original table literal for this reason.

**Typing (Codex's test-table findings):**
- `8626bc7` used mixed arrays such as `{ "5e-30", 5e-324 }`, whose elements infer as `string | number`.
- Every case now uses a typed record: `DivisionCase { dividend, divisor, expected }`, `UnderflowCase { dividend, divisor }` and `SerializationFixture { label, value, subnormal }`.
- `parse` results are narrowed with an `expectTrue(back ~= nil)` check followed by `back :: BigNum`.

**Fixtures are built from IEEE-754 bit patterns, with no arithmetic.** `fromBits(high, low)` does `buffer.writeu32` twice, then `buffer.readf64`. Only bytes move, so FTZ cannot touch them.

| Fixture | Bits | Value (`%.17g`, glibc) | Shortest text |
|---|---|---|---|
| smallest positive double | `0x0000000000000001` | 4.9406564584124654e-324 | `5e-324` |
| its next neighbour | `0x0000000000000002` | 9.8813129168249309e-324 | `1e-323` |
| nearest to 1e-320 | `0x00000000000007E8` | 9.9998886718268301e-321 | `1e-320` |
| nearest to 1e-310 | `0x000012688B70E62B` | 9.9999999999999694e-311 | `1e-310` |
| largest subnormal | `0x000FFFFFFFFFFFFF` | 2.2250738585072009e-308 | `2.225073858507201e-308` |
| smallest normal | `0x0010000000000000` | 2.2250738585072014e-308 | `2.2250738585072014e-308` |

**Tests:** 67 in total. That is 61 original, 2 from DEFECT-001 (retyped) and 4 new; each runs separately, so an arithmetic failure cannot hide a serialization failure.

| Line | Test | Why |
|---|---|---|
| 455 | subnormal results rebuilt from scientific form are not flushed to zero | DEFECT-001, retyped. It is the same cases. The 1.5/1e310 and 3/1e310 checks are now in the loop, which also asserts that they are valid and non-zero. |
| 477 | the normal boundary and genuine underflow are unchanged | DEFECT-001, retyped; same assertions |
| 504 | **subnormal fixtures built from IEEE-754 bits are the intended doubles** | Each subnormal fixture is > 0 and below the smallest normal, in increasing order. The bits match the smallest normal, 1 and 0. A host that reads subnormal inputs as zero (DAZ) fails here instead of passing the round trip silently. |
| 521 | **canonical text round-trips exactly for subnormal, boundary, ordinary and large values** | 22 fixtures: the 5 subnormals; the smallest normal; zero twice; 1e-300, 0.1, 0.5, 1, 13, 123456.789, 1e15, 2^53 − 1; 2^53, 1e16, the largest double, 1.5e400, 7.25e1000, 1e9007199254740991. Each must give a valid BigNum with `eq(parse(toString(x)), x)` and `toString(parse(toString(x))) == toString(x)`. Subnormal fixtures must also be non-zero BigNums. |
| 540 | **canonical text of zero, normal and large values keeps its existing form** | Exact strings: `"0"`, `"0.5"`, `"13"`, `"9007199254740991"`, `"1.5e400"`, `"7.25e1000"`, `"1e9007199254740991"`. Every non-subnormal fixture equals the frozen `"%.17g"` or `"%.17ge%.0f"` text. |
| 563 | **text below half the smallest positive double still reads as zero** | `"2e-324"`, `"2.4e-324"`, `"1e-330"` and `"1e-400"` read as zero and print `"0"`; `"3e-324"` rounds up to the smallest double (genuine underflow is preserved) |

## 6. Results by floating-point mode (offline only; raw output in `review/DEFECT-001B_OFFLINE_RESULTS.txt`)

| Candidate (work tree) | gradual | FTZ, DAZ off | FTZ + modeled Studio formatter | formatter model only |
|---|---|---|---|---|
| Unit tests (shipped `TestRunner`) | **67/67** | **67/67** | **67/67** | **67/67** |
| Review probes: M1 formulas, cost curves, two-player server simulation, BigNum fuzz, F1–F6 | **75/75** | **75/75** | **75/75** | **75/75** |
| Differential: candidate `parse(toString(x)) == x` and idempotent text | 0 failures | 0 | 0 | 0 |

**Differential:** 24,000 operations per mode, comparing the frozen BigNum, the prior candidate and this candidate. Every difference falls in one of the intended classes; "other differences" is 0 in every mode.

| Class | gradual | FTZ | FTZ + formatter | formatter |
|---|---|---|---|---|
| frozen → prior: arithmetic 0 → subnormal (DEFECT-001) | 0 | 4 | 4 | 0 |
| prior → candidate: subnormal text now from `tostring` | 254 | 254 | 255 | 255 |
| prior → candidate: `parse(toString(x))` 0 → x | 0 | 0 | 255 | 255 |

In gradual and FTZ modes, one subnormal operand's shortest text has 17 digits and is identical to its `%.17g` text. That is why those modes show 254 text differences rather than 255.

## 7. Negative controls (offline)

The new tests were run against older BigNum versions, to show that they detect the defects.

| Tests | BigNum | gradual | FTZ | FTZ + formatter | formatter |
|---|---|---|---|---|---|
| frozen, 61 | frozen | 61/61 | 1 fail: 364 | 1 fail: 364 | 1 fail: 374 |
| prior, 63 | prior `8626bc7` | 63/63 | 63/63 | 1 fail: **374** | 1 fail: 374 |
| **candidate, 67** | **prior `8626bc7`** | 67/67 | 67/67 | **2 fail: 374, 534** (`smallest positive double (bits 0x1): parse(toString(x)) equals x (text "0")`) | 2 fail: 374, 534 |
| candidate, 67 | frozen `e9d878d` | 67/67 | 3 fail: 364, 471, 485 | 4 fail: 364, 471, 485, 534 | 2 fail: 374, 534 |

- **All five subnormal fixtures are detected.** A test stops at its first failure, so a per-fixture view comes from probe v2 against the frozen module: `module "0" eq=false` appears for each of the 5 subnormal fixtures, and the inline candidate text gives `eq=true idempotent=true`.
- **Supplementary DAZ check** (FTZ + DAZ + formatter; Studio reported no DAZ): 4 failures, at lines 365, 471, 510 and 527. The fixture test fails loudly, so the round trip cannot pass on flushed zeros.

## 8. Luau compilation and analysis: NOT run

- **Why not:** `luau-compile` and `luau-analyze` are not installed in this environment. Downloading the official Luau 0.745 release binaries was **blocked by the environment's permission policy** ("Code from External"). No compiler or analyzer result exists for this candidate.
- **How the offline harness ran the code:** it translates Luau to Lua 5.1, which checks neither syntax nor types the way Luau does.
- **Manual strict-mode review (not a substitute):**
  - the casts are `back :: BigNum` (from `BigNum?`);
  - the typed records and the typed `{ DivisionCase }`, `{ UnderflowCase }` and `{ SerializationFixture }` arrays;
  - the `buffer.create`, `writeu32` and `readf64` signatures;
  - `table.insert(tests, { name, run })` against `{ TestKit.TestCase }`;
  - one multi-line if-expression.
- **The reviewer should run**, against these two files:
  1. `luau-compile` on both files;
  2. `luau-analyze src/ReplicatedStorage/Shared/BigNum.luau`, which is standalone;
  3. Studio's Script Analysis, or `luau-lsp analyze` with Roblox definitions, on `BigNumTests.luau`, which needs `game`, `script` and `require` of Instances.

  Report any analyzer failure rather than suppressing it.

## 9. Studio validation still required (do not change the original QA place)

1. **Probe v2, Server Play mode, original QA place (read-only).**
   - Run `review/ftz-harness/studio_probe.lua` as in `DEFECT-001_REPORT.md` section 8; the lines are prefixed `[DEFECT-001 probe v2]`.
   - v2 prints numbers with `tostring`, because v1's `%.17g` display showed subnormals as 0 in Studio. It adds a `formatter` verdict, a `buffer` check, and one `text …` line per fixture: `%.17g` text, `tostring` text, module round trip, and the inline candidate text with its round trip and idempotence.
   - Expected, from `run_probe_offline.py … ftz-winfmt` with the frozen module:
     - `FLUSH-TO-ZERO`, `subnormal inputs kept (no DAZ)`;
     - `FORMATTER PRINTS SUBNORMALS AS 0`;
     - `buffer bit rebuild available`;
     - `line 374 … "0" -> 0 eq=false`;
     - for every subnormal fixture: `module "0" eq=false | candidate "<shortest>" eq=true idempotent=true`;
     - for the smallest normal, 1e-307, 1e-300, 0.1 and 0: `module … eq=true`.
   - Anything else is a different signature: investigate before using this candidate. That includes a normal value whose `%.17g` text does not read back, or a subnormal whose `tostring` does not read back.
2. **Candidate tests in a disposable copy of the QA place.**
   1. Replace `BigNum` and `BigNumTests` with the candidate files.
   2. Press Play and expect `[Tests] ALL PASSED (67 tests)`.
   3. Run the M1/M2 gameplay sections of `M2_STUDIO_REGRESSION_GUIDE.md` on the copy.
   4. Expect Appendix B to report the two scripts as changed in that copy; nowhere else.

## 10. Remaining host-specific limitations

1. **Native small-value fast paths still flush under FTZ.** This is unchanged from DEFECT-001. Candidate results that still differ between gradual and FTZ + formatter, all becoming 0:

   | Operation | mul | ratio | div | add | fromLog10 | sub | trySub | scaledPower |
   |---|---|---|---|---|---|---|---|---|
   | Results that become 0 | 133 | 70 | 65 | 55 | 37 | 29 | 29 | 10 |

   There is no universal subnormal support. Gameplay values are 0 or at least 1.
2. **A ±1 subnormal step near the normal boundary in arithmetic** (the bounded precision contract). Unchanged from DEFECT-001.
3. **Dependence on Studio's `tostring` and `tonumber`.** Studio has verified only 5e-324 (the owner's control). The other fixtures await probe v2.
4. **The formatter model is an inference from one value.** If Studio's `%.17g` also misprints some *normal* values, those still use `%.17g` and would remain wrong. Probe v2 checks the smallest normal, 1e-307 and 1e-300.
5. **Text form:** subnormal canonical text is now the shortest form on every host (section 3). Server and client produce the same text, because both use Luau's deterministic `tostring`.
6. **DAZ and ARM flush-to-zero** (subnormal inputs read as zero) are not supported. The tests now fail loudly there (section 7).
7. **Harness limits:** Lua 5.1 with glibc, not Luau. The `tostring` layout is approximated: exponent padding, while subnormal exponents always have three digits. No Luau compiler, constant folding or type checker ran.

## 11. Candidate source hashes (NOT applied to any manifest)

Bytes, lines and Adler-32 are the Appendix B normalized values (each file is already normalized).

| File | Frozen `e9d878d` (round 3) | Prior candidate `8626bc7` | **This candidate** | This candidate: bytes / lines / Adler-32 |
|---|---|---|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | `c7474136d45bada326484a786fd60ff5ca02a18a12b4012fbcfca01a3950244a` | `31b0b589f53936adbf8f22979c290801f51290e749dba97c5e281019616cc5a0` | `e337573da95f481a022ed0e6f31dfefdacb0755921214cdb89cdb53d8e08f674` | 16287 / 532 / 3188390913 |
| `src/ServerScriptService/Tests/BigNumTests.luau` | `0c13e4842d1420b285243e824c012bca32cbe13e09df278af53ae709d914d97a` | `331827340044ed2e4b001c6c4bc764e0049b32b8500932d7cb406df2e28f50b2` | `8d28a9bf19fa29cf3ccf53dc5dd066f2777ef85548a35911b19f1feab4113b51` | 23275 / 578 / 1646015937 |
| Other 22 files | unchanged (equal to round 3) | — | — | — |

**Not changed on this branch:**
- frozen commit `e9d878d`;
- `SOURCE_HASHES.txt`;
- `M2_STUDIO_REGRESSION_GUIDE.md` (Appendix A/B parity tables, expected 61 tests);
- the installer payload on `feature/m2-tools-001-installer`;
- `main`, PR #1 and PR #2;
- the Slime art files and every milestone document.

Adopting this candidate needs a separate, reviewed revision covering:
- the source pin;
- manifest round 4, keeping round 3 as history;
- the parity tables and the installer payload;
- the expected test count (67).
