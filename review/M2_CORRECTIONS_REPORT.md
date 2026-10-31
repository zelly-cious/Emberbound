# Milestone 2 — Corrections for the Codex audit (round 2)

| | |
|---|---|
| Audit | *Emberbound — Milestone 2 Independent Audit*, 31 Oct 2026, verdict **FAIL** (2 Medium, 4 Low, no Critical). Copy: `review/audits/Emberbound_M2_Independent_Audit.pdf` |
| Audited | implementation `024cd68838d6c34633a00e7eadcb320c251186f0`, PR head `eb5a3511d932de5c1860852c0f47dfa8911912a5` |
| **Corrections commit (re-review this)** | `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf` on `feature/m2-tap-upgrades-bignum` (PR [#1](https://github.com/zelly-cious/Emberbound/pull/1)) |
| Later commits | Documentation and `review/` tooling only: `git diff e4b0108 HEAD -- src` is empty *(superseded 1 Nov 2026: one producer-authorized comment line in `CombatService.luau` has since changed; see section "Round 2 re-review outcome" below)* |
| Round 1 evidence | Unchanged: `review/M2_CHECK_RESULTS.md` (results for `024cd68` / `eb5a351`) |

**Roblox Studio was not used.** Everything below ran in the Luau CLI 0.745 with the offline harness's fake engine, plus Selene 0.32.0 and `luau-analyze` 0.745.

## Findings and fixes

| # | Severity | Status | Fix |
|---|---|---|---|
| F1 | Medium | **Fixed** | `BigNum.sub`: when the larger operand is below 10^23 (10^22 is the largest exact power of ten), both operands convert to doubles in one rounding (exactly below 10^16) and the result is one correctly rounded subtraction. Doubles ≥ 2^53 are whole numbers, so a result below 2^53 is exact. Larger operands keep the original scientific path. |
| F2 | Medium | **Fixed** | `normalize` split into a non-throwing `tryNormalize` (returns nil when the normalized exponent would exceed 2^53 − 1) and the throwing `normalize` used by arithmetic. `parse` uses `tryNormalize`, so it returns nil and never raises. Arithmetic overflow still raises, as before. |
| F3 | Low | **Fixed** | `TestRunner` records modules that fail to load, or that return something other than a suite (`TestKit.isSuite`), as load failures. `TestKit.runSuites(suites, loadFailures?, reporter?)` counts each as a failure and fails a run with no tests; `ALL PASSED` is printed only when at least one test ran and nothing failed. The offline harness now checks the output independently (every suite reported, no failure lines). |
| F4 | Low | **Fixed** | Powers of ten below −300 are applied in two steps (`multiplyByPowerOfTen` / `divideByPowerOfTen`), so subnormal values down to 5e-324 never divide by an underflowed 10^-324. Every other power uses the original single operation, so ordinary values round exactly as before. No change to the representation or its invariants. |
| F5 | Low | **Fixed (diagnostic)** — see tradeoff | `make` freezes the table in place and returns the typed reference, which removes the strict-mode error under both solvers. The exported type keeps plain `m`/`e` fields. |
| F6 | Low | **Fixed** | `expectNear` rejects NaN operands and NaN, negative or infinite tolerances; equal infinities still pass; opposite infinities (NaN difference) fail. |

> **Superseding notes (1 Nov 2026), added after Codex's round 2 re-review; the table above is kept as written.** F1–F6 are closed **for their audited cases**. Three statements were broader than the code guarantees:
> - F1: "a result below 2^53 is exact" holds when the operands are exact and the larger is below 10^23. It is not universal: cancellation after operations involving large approximate values can be approximate below 2^53 (`(1e23 + 12345) − 1e23` returns 0).
> - F2: `parse` never raises and rejects exponents beyond 2^53 − 1, but it does not reject every mathematically out-of-range decimal. That is limitation **R2-1**, separately and conditionally deferred.
> - F4: subnormal inputs are fixed for the operations the tests and probes cover (`add`, `sub`, `mul`, `div`, comparisons, text). `ratio` can still underflow or overflow prematurely; that is limitation **R2-2**, separately and conditionally deferred.
>
> The approved contract is the bounded precision contract in `M2_REQUIREMENTS.md` (`DECISIONS.md` 8–10).

### Tradeoffs to review

- **F5 — why not `read` fields.** Declaring `{ read m: number, read e: number }` is clean under the new solver but the old solver rejects the syntax (`read keyword is illegal here`) and then reports ~70 errors on every field access. Studio may run either solver, so the declared type stays writable and immutability is enforced at runtime by `table.freeze` (covered by the existing "values are immutable" test). Switch to `read` fields once the project standardizes on the new solver.
- **F1 — scope.** The native path applies to every subtraction with the larger operand below 10^23, not only results below 2^53. In the differential probe (section 11) 33 of 400 subtractions now differ from the audited BigNum, every one equal to the correctly rounded double subtraction; all other operations (3 967 of 4 000) are bit-identical. Before the fix about 35 % of subtractions with results in [2^53, 10^16) were one double (2) away from the correctly rounded value; now none are.
- **F2 — long mantissas.** Mantissas longer than ~16 digits are read to double precision, as `tonumber` does, so `"1" .. 23 zeros .. "e9007199254740968"` parses as 9.999…e9007199254740990 rather than being rejected as 10^(2^53). Canonical text never has this form.
  > **Correction (1 Nov 2026):** this example is wrong. 10^23 × 10^9007199254740968 = 10^9007199254740991 = 10^(2^53 − 1), which is **in range**, so accepting it is correct. The out-of-range case is exponent **9007199254740969**: `"1"` + 23 zeros + `"e9007199254740969"` = 10^(2^53), above the maximum, yet it parses as `9.9999999999999982e9007199254740991` and `isValid` returns true. Verified by running the repository's `BigNum.luau` in the Luau VM. This is limitation **R2-1**.

## Files changed in `e4b0108`

| File | Change |
|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | F1, F2, F4, F5 (+48 / −9 lines; 508 lines) |
| `src/ServerScriptService/Tests/TestKit.luau` | F3 (`isSuite`, `Reporter`, `runSuites` load failures and empty run), F6 (`expectNear`) |
| `src/ServerScriptService/Tests/TestRunner.luau` | F3 (load failures passed to `runSuites`) |
| `src/ServerScriptService/Tests/BigNumTests.luau` | +4 regression tests |
| `src/ServerScriptService/Tests/WalletTests.luau` | +2 regression tests |
| `src/ServerScriptService/Tests/TestKitTests.luau` | **new** suite, 7 tests (ModuleScript in `ServerScriptService > Tests`) |

No other file under `src/` changed: GameConfig, ProgressionConfig, every service, ServerInit and all client scripts are byte-identical to `024cd68`.

## Tests added

| Suite | Test | Covers |
|---|---|---|
| BigNumTests | subtraction that returns below 2^53 is exact | F1: 2^53 − (2^53 − k) for k = 1…64, crossing back from 2^53 + 2000, large − large → whole number |
| BigNumTests | subtraction with large results | F1: unchanged large results; 200 seeded pairs equal the correctly rounded double |
| BigNumTests | parse returns nil instead of overflowing during normalization | F2: four hostile strings return nil without raising; exponent 2^53 − 1 still parses three ways |
| BigNumTests | the smallest positive doubles work in arithmetic | F4: 5e-324 and 2.2e-308 through mul, div, add, compare, text round trip |
| WalletTests | spending across 2^53 leaves an exact whole balance | F1: the audit's level-510 case → exactly 4485383672432620 |
| WalletTests | Gold is conserved when a balance crosses 2^53 and is spent back below it | F1: 200 seeded grant/spend sequences end at the exact expected balance |
| TestKitTests | 7 tests | F6: NaN operands, NaN/negative/infinite tolerance, valid comparisons. F3: load failure counted, empty run fails, failing test counted, `isSuite` |

New review probes (`review/offline-harness/probes.luau`, sections 6–11; sections 1–5 are the original 54, unchanged): cross-regime subtraction fuzz and Gold conservation through the real services (F1), 23 168 hostile parse strings (F2), fault injection into the real `TestRunner` script (F3), subnormal arithmetic grid (F4), `expectNear` (F6), and a differential run against the audited BigNum.

**The new tests detect the original defects.** With the audited `BigNum`, `TestKit` and `TestRunner` from `024cd68` swapped back in, 12 of the 13 new unit tests fail (the one that passes checks that valid `expectNear` comparisons keep passing), and the new probes fail on F1 (3 checks), F2 (1 079 strings raised), F3 (3 checks) and F4 (15 operations raised).

## Results for `e4b0108`

| Check | Result |
|---|---|
| Unit tests via the real `TestRunner` (`run.sh unit`) | **61 / 61 pass** — 7 suites: BigNum 25, CombatFormula 4, CombatRules 5, Progression 7, RateLimiter 3, TestKit 7, Wallet 10. The harness independently verified that all 7 suites reported and no failure line appeared. |
| Original 48 tests (part of the 61) | **48 / 48 pass** |
| Review probes (`run.sh probes`) | **75 / 75 pass** — original sections 1–5: **54 / 54**; correction sections 6–11: **21 / 21** |
| Luau compilation (`luau-compile`) | **24 / 24** source files compile |
| Selene 0.32.0, Roblox std, all of `src/` | **0 errors, 0 warnings** |
| `luau-analyze --mode=strict`, 14 Roblox-free modules, new solver | BigNum F5 error **gone**. Remaining: `RateLimiterTests.luau:24, 30` DuplicateCondition (false positive, unchanged), `warn` unknown global (harness artifact) |
| Same, old solver | Same as above plus `TestKit.luau:114` "Function only returns 1 value" (old-solver false positive on `pcall`, present at `024cd68` line 66). No new diagnostics. |
| Roblox Studio / client execution | **Not performed** |

Probe output for the new sections:

```text
== 6. F1: subtraction near 2^53 and Gold conservation
  PASS sub(2^53, 2^53 - 1) = 1
  PASS 20000 subtractions from [2^53, 1e16) equal the correctly rounded double (exact below 2^53)
  PASS 4989 cancellations between large operands below 10^23 give whole numbers
  PASS 30 purchases from a 2^53 balance leave exactly 2^53 minus their summed costs
== 7. F2: parse never throws
  PASS 23168 random and boundary strings: parse never raised an error
  PASS every value parse returned is a valid BigNum
  PASS near exponent 2^53 - 1, parse accepts exactly the representable values
== 8. F3: TestRunner fault injection (the real TestRunner script)
  PASS a suite that errors while loading is reported and the run is not ALL PASSED
  PASS the harness check also rejects that run
  PASS a module that does not return a suite is a failure
  PASS a run with no test modules fails
  PASS control: a healthy folder still reports ALL PASSED
== 9. F4: the smallest positive doubles in arithmetic
  PASS 676 add/sub/mul/div operations on values from 5e-324 to 7.25e1000 raise no errors
  PASS every result is a valid BigNum and every value round-trips through text
  PASS 5e-324 * 1e400 divided by 1e400 is 5e-324 again
== 10. F6: approximate assertions reject NaN
  PASS expectNear(0/0, 123, 0) fails
  PASS expectNear(123, 0/0, 0) and NaN or negative tolerances fail
  PASS valid approximate comparisons still pass
== 11. Ordinary values: corrected BigNum vs the audited BigNum (024cd68)
  PASS parse and toString agree with the audited BigNum on every ordinary value
  PASS 4000 operations: every difference is the intended F1 subtraction change
  OBSERVE 3967 results identical to the audited BigNum, 33 subtractions now correctly rounded
  OBSERVE add with a result in [2^53, 1e16): 6970 of 20000 land one double (2) away from the correctly rounded sum (unchanged; not part of F1)
  PASS no remote handler raised an error (all sections)
[Probes] original sections 1-5: 54 passed, 0 failed
[Probes] correction sections 6-11: 21 passed, 0 failed
[Probes] total: 75 passed, 0 failed
```

## Regression check

| Must be preserved | Evidence |
|---|---|
| M1 enemy HP and Gold formulas | Probes section 3 (exact on stages 1–209 vs `730218a`); GameConfig unchanged |
| Starting tap damage 1 | Probe 3, ProgressionTests; ProgressionConfig unchanged |
| Upgrade pricing curve | Probes section 4 (levels 1–3000); ProgressionConfig unchanged |
| Server-authoritative Gold spending | Probes 5d–5f; Wallet, CurrencyService, UpgradeService unchanged |
| Remotes and payloads | GameConfig, services and client unchanged; probe 5b payload checks |
| Rate limiting and replay protection | Probes 5d–5f; RateLimiterTests |
| ClientReady synchronization | Probe 5b; PlayerSessionService and CombatClient unchanged |
| `CombatService.ApplyDamage` | Probes 5c, 5h; CombatService unchanged |
| Upgrade UI behaviour | UpgradePanel, CombatHud, CombatClient unchanged (not executed offline) |
| Per-player combat isolation | Probes 5c, 5g, 5i |

## Unresolved items and observations

- **None of F1–F6 is unresolved.** F5 is resolved as a diagnostic; the read-only type annotation is deliberately deferred (see tradeoff). *(1 Nov 2026: "resolved" means resolved for the audited cases; R2-1 and R2-2 are separate, conditionally deferred limitations.)*
- **Observation (not an audit finding): `add` above 2^53.** `add` still uses scientific form; about 35 % of sums landing in [2^53, 10^16) are one double (2) from the correctly rounded value. This is within BigNum's documented ~16-digit precision and was left unchanged to keep the correction minimal. The same native-path technique could be applied if the reviewer considers it necessary.
- **Observation: cancellation above 10^23.** For operands ≥ 10^23, `sub` keeps the scientific path, so a result that falls below 2^53 can be fractional. It needs a balance ≥ 10^23 and a cost within 9×10^15 of it (relative 10^-7).
- Offline-harness limits are unchanged: remotes run synchronously, client scripts are not executed, `Random` is a stand-in, and the Luau CLI's math library is not the Roblox server's.

## Ready for re-review?

**Yes, for an independent Codex re-review** of `e4b0108` (PR #1 head includes it). This is not a Milestone 2 approval: the re-review, Roblox Studio regression testing (`M2_REVIEW_GUIDE.md` §9, now expecting `ALL PASSED (61 tests)`), and Studio source-parity verification against `SOURCE_HASHES.txt` are still required. PR #1 remains unmerged.

## Round 2 re-review outcome and producer decisions (added 1 Nov 2026)

Everything above is the round 2 report as submitted for re-review, kept for the record apart from the clearly marked superseding notes.

### Final Codex assessment

Source: Codex's round 2 re-review of PR head `09be466c6c8844d025b25902a7f26338cad5e686`, as summarized in the producer's "Milestone 2 Final Review Decisions" message of 1 Nov 2026. The full Codex report text is not in this repository; the points below are exactly those relayed.

- Verdict: **CONDITIONAL PASS**.
- The original findings F1–F6 have been addressed for their audited cases.
- No additional gameplay-logic change is required under the proposed bounded precision contract and conditional deferrals.
- Codex independently reproduced that `BigNum.parse` can accept an originally out-of-range decimal after numerical rounding (**R2-1**), and identified that `BigNum.ratio` can overflow or underflow prematurely at extreme magnitudes (**R2-2**).
- PR #1 can proceed to Roblox Studio QA once the producer decisions are formally recorded and the QA expectations aligned. Do not merge.

### Producer decisions (recorded in `DECISIONS.md` 8–10 and `M2_REQUIREMENTS.md`)

| # | Decision | Conditions |
|---|---|---|
| 1 | Bounded finite-precision BigNum contract: **approved** | Exact tested early-game integer arithmetic, Milestone 1 formulas and progression, server authority, non-negative Gold, replay protection and exactly-once rewards are preserved. Rounding, absorption and approximate cancellation at large magnitudes are accepted. No promise of universal exactness below 2^53, unlimited range or universally correctly rounded results |
| 2 | R2-1 parser limitation: **conditionally deferred, M2 only** | Valid while production parsing is limited to client-side decoding of server-generated strings. Fix and test before any untrusted profile, import, client or other numerical input can reach `parse`, including M3 persistence if it introduces such a path |
| 3 | R2-2 ratio limitation: **conditionally deferred, M2 only** | Valid while the result is cosmetic, HP stays bounded by max HP, zero max HP is handled, and no authoritative calculation relies on it |

Both conditions hold in this code (confirmed by source): outside `Tests`, `BigNum.parse` is called only in `CombatClient.luau` on server-sent strings, and `BigNum.ratio` only in `CombatHud.luau:297`, inside a zero-max-HP check and clamped to 0…1.

### Verification of the R2-1 example and the precision contract (offline, Luau VM; not Studio)

```text
"1"+23 zeros+"e9007199254740968" (= 10^(2^53-1))  -> accepted  m=9.9999999999999982 e=9007199254740990  (in range: correct)
"1"+23 zeros+"e9007199254740969" (= 10^(2^53))    -> accepted  m=9.9999999999999982 e=9007199254740991  isValid=true  (R2-1)
"1e9007199254740992", "10e9007199254740991"       -> nil (rejected)
(1e23 + 12345) - 1e23                             -> 0      (true 12345: approximate cancellation below 2^53)
1e20 - 5, 1e20 + 5                                -> 1e20   (absorption)
ratio(1.1e609, 1e300)                             -> inf    (true 1.1e308: premature overflow, R2-2)
ratio(9e100, 1e424)                               -> 0      (true about 9e-324: premature underflow, R2-2)
```

### Comment-only source correction

The producer authorized correcting one misleading comment. No executable change:

```diff
--- a/src/ServerScriptService/CombatService.luau   (09be466)
+++ b/src/ServerScriptService/CombatService.luau
@@ -14 +14 @@
-	  - HP and damage are BigNums (exact below 2^53, unlimited above)
+	  - HP and damage are BigNums (finite precision: tested early-game values exact, large values approximate)
```

- **Runtime behaviour is unchanged.** Both versions compile to byte-identical Luau bytecode (4,683 bytes each, compiled with the Luau 0.663 compiler); the line count is unchanged (235).
- `SOURCE_HASHES.txt` has a new **round 3 (current)** manifest. Only `CombatService.luau` differs from round 2: new SHA-256 `60988bb1184f298c4567fa1840e6f11687b7ad3ddcb469ab108980c999a3b168`, 7,497 bytes. The round 2 and round 1 manifests are kept as historical records.
- The Studio QA guide's parity values for `CombatService` are updated to match (7,497 bytes, 235 lines, Adler-32 935340211).

### Offline re-run after the decisions (Luau VM with the repository's fake engine; not Studio)

- Unit tests via the real `TestRunner`: **61 / 61 pass**, 7 suites.
- Review probes: **75 / 75 pass** (54 original + 21 correction).

These match the round 2 results; no Roblox Studio test has been run.

### Status

Milestone 2 is **frozen** until Roblox Studio QA (`M2_STUDIO_REGRESSION_GUIDE.md`). PR #1 remains open and unmerged. Milestone 2.1 has not started.
