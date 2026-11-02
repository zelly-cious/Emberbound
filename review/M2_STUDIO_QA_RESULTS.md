# Emberbound Milestone 2 — Roblox Studio QA results

Filled in from `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`, following `M2_STUDIO_REGRESSION_GUIDE.md` (the version pinned to `e9d878d`, as on PR #1 head `2b832d2`).

**Revision 2.** Adds the evidence the owner recorded during the Roblox Studio testing conversation:
- the adapted P-5 Output;
- per-test observations for M1-1, M1-6, U-5 to U-7, A-1 to A-7, L-1, L-2, L-4, MOB-1 to MOB-7, N-2, N-4 to N-6 and C-3 to C-5;
- the Studio Script Analysis result.

Every classification was rechecked against the pinned guide's PASS criteria.

**Revision 3.** Adds the owner's newly completed Roblox Studio tests on `9a988c9`:
- T-2 (negative control) and L-3 (restart);
- L-1, repeated with Player2 unambiguously captured through the temporary QA bridge;
- an M1-2 reproduction, with the owner's proposed disposition;
- a second final P-5 after the bridge was deleted again.

The place file `Emberbound_M2_DEFECT001_QA.rbxl` was saved afterwards. The open questions that remain are preserved in section 6.

**Revision 4.** Records Codex's completed independent **read-only** review of candidate `9a988c9`, including native Luau checks (section 2.2), and corrects R-9 and the related wording. No test result changed.

**Revision 5.** Adds the Roblox Studio Script Analysis evidence from the saved `Emberbound_M2_DEFECT001_QA.rbxl`, which contains candidate `9a988c9` (section 2.3). It updates R-9 accordingly. No test result changed.

**Revision 6 (2026-11-03).** Incorporates the producer's subsequent explicit Roblox Studio confirmations for U-3/U-4/U-7, A-4, MOB-6/MOB-7 and C-5. The producer formally accepted M1-2 as a **known Low-severity, nonblocking M2 deviation** without changing its strict FAIL. This is reported evidence, not new independently collected Studio logs. P-3 and the other outstanding evidence/adoption requirements remain open.

| | |
|---|---|
| **Overall status** | **CONDITIONAL — NOT A FULL QA PASS / NOT RELEASE-READY.** 37 PASS (including revision-6 user confirmations), 20 PASS† pending detail, 1 strict FAIL (M1-2; **formally producer-accepted Low/nonblocking M2 deviation**), 1 PARTIAL (P-3), 0 BLOCKED, 2 optional NOT RUN and 1 optional NOT VERIFIED. This does not approve the candidate, Milestone 2 completion or PR #1 merge. General no-red-Output confirmation, mobile specifics, independent warning classification, risk acceptance for BigNum and revised source pin/manifest/parity/installer remain outstanding (section 6). |
| **Provenance** | The project owner ran the tests in Roblox Studio and reported the results through the Roblox Studio testing conversation: written observations, plus quoted Output lines for P-5 (both runs), T-2, L-1, C-3, C-4 and the cleanup counts. **No Output files (`QA_*.txt`) or screenshots are in the repository.** A screenshot was captured for N-6; it is not in the repository. Claude Code wrote this report from the owner's reports and repository evidence. No observation, log, screenshot, measurement or test action was added beyond what the owner reported; where something is derived or inferred, it says so. |
| **Where the referenced files are** | The tested code, `review/DEFECT-001_REPORT.md`, `review/DEFECT-001B_REPORT.md` and `review/DEFECT-001B_CODEX_HANDOFF.md` are on branch `candidate/m2-defect-001-ftz-subnormal` at `9a988c9`. The pinned guide and template are on PR #1 head `2b832d2`, and also on `9a988c9`. This report is committed on `claude/emberbound-m2-regression-testing-56vtjh`, which holds an older, unpinned copy of the guide; review against the pinned version. |
| **Not done** | PR #1 is not merged. Milestone 2 is not marked complete. Milestone 2.1 is not started. No gameplay source was changed. |

## 1. Marks used

The template allows PASS, FAIL, BLOCKED and NOT RUN. Three extra marks keep the report from overstating results. Only PASS counts as a confirmed pass.

| Mark | Meaning in this report |
|---|---|
| **PASS** | The reported observations cover the test's primary "PASS if" conditions. Secondary conditions that were not itemized are named in the Notes. One condition applies to every test and was not itemized per test: the guide's rule (0.3) that any red Output line is a FAIL. It is a single open confirmation (R-2). |
| **PASS†** | Reported as passed, but the only evidence is the category-level statement (section 3.2) or a summary-level remark, or the reported procedure does not match the guide's. **Needs confirmation.** |
| **FAIL** | A PASS condition was observed not to hold. |
| **PARTIAL** | Part of the test was done, and a required step or condition was not performed or not confirmed. Not a pass, and **not a defect**. |
| **BLOCKED** | The test could not be completed conclusively; the reason is given. |
| **NOT RUN** | An optional test that was skipped, as reported. |
| **NOT VERIFIED** | No result was reported. For a required test this is an open item, not a pass. |

## 2. Test setup

| | |
|---|---|
| Tester | Project owner (name not supplied) |
| Date(s) | November 3, 2026 for C-5's cleanup checks (Studio Output timestamps 02:06:51, 02:08:58, 02:18:43) and the first final P-5 (02:21:09). The second final P-5 is timestamped 03:32:33.698; its date was not restated. Other dates were not supplied. This report was first prepared on 2026-11-02 (UTC). |
| Roblox Studio version | Not supplied. The owner's DEFECT-001B Edit-mode diagnostic reported Luau `0.745.0.7451137`. |
| Computer and OS | Not supplied |
| Place file name | `Emberbound_M2_DEFECT001_QA.rbxl`, saved after testing, including after the revision 3 tests and the second final P-5. This is the separate candidate copy that `review/DEFECT-001B_REPORT.md` §9 asked for; the guide's default name is `Emberbound_M2_QA.rbxl`. |
| Code tested | `src/` at `9a988c9254e07ac50dcf32fe4b55ba975613390d` (branch `candidate/m2-defect-001-ftz-subnormal`). This equals the frozen `e9d878d94155610558c9c6252d76f202dfd956b4` except for `BigNum.luau` and `BigNumTests.luau`; confirmed with `git diff --name-only e9d878d 9a988c9 -- src`. See 2.1 and 3.1. |
| How the scripts were installed | Not supplied |
| P-3 result | Reported: **22 / 24 scripts matching, 6 / 6 remotes** with the unmodified Appendix B checker. The two non-matching files are the intended candidate files, so this is an expected deviation, not a defect (3.1). Verbatim lines and the extra-script count were not supplied. |
| P-5 result | Checker adapted for `9a988c9`: the `BigNum` and `BigNumTests` rows use the candidate values in 2.1.<br>**Final run**, after the temporary QA bridge used for the L-1 repeat was deleted:<br>`03:32:33.698 [Parity] scripts matching: 24 / 24, remotes: 6 / 6, extra scripts: 0`<br>`03:32:33.698 [Parity] RESULT: PASS`<br>Earlier final run (November 3, 2026, before the revision 3 tests):<br>`02:21:09.684 [Parity] scripts matching: 24 / 24, remotes: 6 / 6, extra scripts: 0 - Edit`<br>`02:21:09.684 [Parity] RESULT: PASS - Edit` |
| H-check result | Not reported directly. The temporary QA bridge **was used**: the L-1 repeat captured Player2 through it, and it was deleted before each final P-5. The guide uses the bridge only when the helpers are "not connected" (Appendix D.4), so the inferred H-check case is "Helpers not connected, used the EmberboundQA bridge". The H-4 result itself was not reported (R-11). |
| Devices used in the emulator | A recent iPhone (model not stated); iPhone 7; a large iPad (model not stated); Samsung Galaxy S22 Ultra |
| Physical phone | None (MOB-9 not run) |
| Studio Script Analysis | Run on the saved `Emberbound_M2_DEFECT001_QA.rbxl` (candidate `9a988c9`). **0 of 0 Errors, 6 of 6 Warnings, 0 Information, 0 Hints.** Two of the six warnings are named `TypeError`. **No diagnostics in `BigNum` or `BigNumTests`.** Details and provisional classification in 2.3. This is a Studio check, separate from Codex's native compile and strict-analysis checks (2.2). |

### 2.1 Candidate source files (not in any approved manifest)

| File | Frozen `e9d878d` SHA-256 (round 3) | Tested candidate `9a988c9` SHA-256 | Candidate bytes / lines / Adler-32 (the adapted P-5 rows) |
|---|---|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | `c7474136d45bada326484a786fd60ff5ca02a18a12b4012fbcfca01a3950244a` | `e337573da95f481a022ed0e6f31dfefdacb0755921214cdb89cdb53d8e08f674` | 16287 / 532 / 3188390913 |
| `src/ServerScriptService/Tests/BigNumTests.luau` | `0c13e4842d1420b285243e824c012bca32cbe13e09df278af53ae709d914d97a` | `8d28a9bf19fa29cf3ccf53dc5dd066f2777ef85548a35911b19f1feab4113b51` | 23275 / 578 / 1646015937 |
| The other 22 files | equal to round 3 | equal to round 3 | as in guide Appendix A (unchanged rows) |

### 2.2 Independent review of the candidate (Codex; native and offline, not Roblox Studio)

Codex completed an independent **read-only** review of `9a988c9254e07ac50dcf32fe4b55ba975613390d`.
- **How it was delivered:** directly in the owner's conversation. It was not posted as GitHub review comments, and no review file is in the repository.
- **What it does and does not cover:** these are native/offline results, not Roblox Studio results. The Studio results are in section 4. Codex's findings, as relayed by the owner:

| Check (native / offline) | Codex result |
|---|---|
| BigNum technical verdict | **PASS WITH RISKS**. No additional blocking numerical or serialization defect was identified. |
| Native Luau 0.745 compilation of both changed files (`BigNum.luau`, `BigNumTests.luau`) | **PASS** |
| BigNum strict analysis, old and new type solvers | **PASS** |
| Test-body analysis with typed context adapters (`BigNumTests.luau`) | **PASS** |
| Unit tests, offline: gradual underflow, FTZ, FTZ plus the modeled formatter failure, and the formatter model alone | **67/67** in each mode |
| Historical review probes (`review/offline-harness`), offline | **75/75** gradual; **74/75** FTZ. Codex attributes the remaining FTZ failure to an outdated differential expectation in the historical probe. It is reported here as **74/75**, not 75/75. |
| Full Roblox-aware Studio Script Analysis, and classification of the six warnings | Not part of Codex's native checks. The Studio evidence was supplied afterwards and is recorded in **2.3**; the classification there is provisional. |
| Candidate adoption, full QA acceptance, PR #1 merge readiness | **NOT APPROVED** |

The candidate branch's `review/DEFECT-001B_REPORT.md` was written before this review, from the translated Lua 5.1 harness. It lists 75/75 probes under FTZ and says the native Luau checks were not run. For the FTZ probe count and the native checks, Codex's native results supersede that report. The specific risks behind "PASS WITH RISKS" are not itemized in this report.

### 2.3 Roblox Studio Script Analysis (candidate place)

Source: the saved `Emberbound_M2_DEFECT001_QA.rbxl`, containing candidate `9a988c9`. Studio summary, as reported by the owner: **0 of 0 Errors, 6 of 6 Warnings, 0 Information, 0 Hints.** No diagnostics were reported in `BigNum` or `BigNumTests`, the two files the candidate changes.

| # | Script | Position | Studio diagnostic (reported as a warning) | Source at that line (`9a988c9`) | Provisional classification |
|---|---|---|---|---|---|
| W-1 | `ServerScriptService.Tests.RateLimiterTests` | (24,38) | `DuplicateCondition` | `expectTrue(limiter:allow("a") and limiter:allow("a") and limiter:allow("a"), "burst of 3")` | Analyzer false positive (lint) |
| W-2 | `ServerScriptService.Tests.RateLimiterTests` | (24,61) | `DuplicateCondition` | same line | Analyzer false positive (lint) |
| W-3 | `ServerScriptService.Tests.RateLimiterTests` | (30,38) | `DuplicateCondition` | `expectTrue(limiter:allow("a") and limiter:allow("a") and limiter:allow("a"), "back to a full burst")` | Analyzer false positive (lint) |
| W-4 | `ServerScriptService.Tests.RateLimiterTests` | (30,61) | `DuplicateCondition` | same line | Analyzer false positive (lint) |
| W-5 | `StarterPlayer.StarterPlayerScripts.CombatClient` | (53,19) | `TypeError`: Expected `this` to be `Instance`, but got `Player?` | `local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui` (where line 52 is `local localPlayer = Players.LocalPlayer`) | Typing concern, documented; no runtime failure observed |
| W-6 | `StarterPlayer.StarterPlayerScripts.CombatClient` | (53,19) | `TypeError`: Value of type `Player?` could be nil | same line | Typing concern, documented; no runtime failure observed |

- **W-1 to W-4.** `DuplicateCondition` flags identical sub-expressions in an `and` chain, which is redundant only if the expression has no side effects. Here each `limiter:allow("a")` call consumes a token, and the test deliberately calls it three times to drain a burst. The repetition is intended, so these are **provisionally analyzer false positives, not confirmed defects**.
- **W-5 and W-6.** Studio files these under Warnings, but they are named **`TypeError`**. `Players.LocalPlayer` is typed `Player?`. In a LocalScript it is set at runtime, and the gameplay tests showed no runtime failure. **The static typing concern remains documented and unresolved:** this strict-mode client script calls a method on a value typed as possibly nil. Fixing it would mean narrowing `Players.LocalPlayer` to `Player`, which is a gameplay-code change; none was made in this QA pass.
- **Error count versus TypeError warnings.** "0 Errors" means Studio reported no diagnostic in its **Errors** category. It does **not** mean the scripts are free of type errors: two `TypeError` diagnostics exist and are listed as warnings.
- **Not introduced by the candidate.** `RateLimiterTests.luau` and `CombatClient.luau` are byte-identical in frozen `e9d878d` and candidate `9a988c9` (`git diff e9d878d 9a988c9`), so all six warnings already exist in the approved frozen source.
- **The classification is provisional** and needs reviewer confirmation (R-9).

## 3. Reconciliation with the guide and the repository

### 3.1 Deviations from the guide, caused by testing the candidate (intended, not defects)

1. **Code under test.** The guide (and the template's "Code tested" row) pins `e9d878d`. This run tested the DEFECT-001B candidate, so every result applies to `9a988c9`'s `src/`. The candidate is **not adopted**. Adopting it needs a separately reviewed revision: the source pin, manifest round 4, the Appendix A/B tables, the installer payload and the test count.
2. **Parity.**
   - The unmodified Appendix B checker reports `BigNum` and `BigNumTests` as `content differs`, because it holds the frozen values (15064 / 508 / 3533007835 and 13960 / 383 / 755231800). That explains the initial **22 / 24**.
   - The final P-5 used a checker adapted with the candidate values, and passed **24 / 24**.
   - The candidate content of the two files was therefore confirmed only at the end of testing, not before it (P-3 is PARTIAL).
3. **T-1 expectation: 67 tests, not 61.** The candidate's `BigNumTests` has 31 tests: the original 25, plus 2 from DEFECT-001 and 4 from DEFECT-001B. The adapted expectation below is **derived from the source**, not copied from Studio Output:
   ```text
   [Tests] BigNumTests: 31 passed, 0 failed
   [Tests] CombatFormulaTests: 4 passed, 0 failed
   [Tests] CombatRulesTests: 5 passed, 0 failed
   [Tests] ProgressionTests: 7 passed, 0 failed
   [Tests] RateLimiterTests: 3 passed, 0 failed
   [Tests] TestKitTests: 7 passed, 0 failed
   [Tests] WalletTests: 10 passed, 0 failed
   [Tests] ALL PASSED (67 tests)
   ```
   The owner reported 67/67. The per-suite lines were not supplied.
4. **T-2 expectation.** With the candidate, the negative control prints `[Tests] 1 FAILED, 67 passed`, not `1 FAILED, 61 passed`. Confirmed in Studio (T-2).

### 3.2 Category-level evidence (the PASS† rows)

For these tests the only evidence is the owner's statement that "Combat, upgrades, currency, request validation, replay protection, multiplayer isolation, network-lag behavior, and large-number displays passed their primary numerical checks". The mapping below is the report author's reading and **must be confirmed (R-2)**.

| Category | Tests credited only by this statement |
|---|---|
| Combat | M1-3, M1-4, M1-5, M1-7 (the input part of this mapping is assumed) |
| Request validation | M1-8 |
| Upgrades | U-1, U-2 |
| Replay protection / multiplayer isolation | B-1, B-2, B-3, B-4, B-5 |
| Network-lag behaviour | D-1, D-2, D-3, D-4 |
| Large-number displays | N-1, N-3 |

Two more PASS† rows rest on a summary-level remark (MOB-1, MOB-2). A-4 was subsequently repeated with the guide's exact one-request procedure and is now PASS.

### 3.3 Consistency checks on the reported numbers (analysis, not new observations)

Every check uses the formulas in `ProgressionConfig` and `GameConfig` and the guide's Appendix E. All are **consistent**.

| Test | Reported | Check |
|---|---|---|
| A-5 | Level 3 → 13, Gold 1000 → 925 | Costs of levels 3–12 add up to 75, so 1000 − 75 = 925. This matches the guide's stated expectation. |
| A-6 | 50 requests in 2.92 s; 32 replies (28 Ok, 4 InsufficientFunds); Gold 29; Level 41 | The C.10 limit is `floor(10 + 8 × 2.92) + 1 = 34`. Costs of levels 13–40 add up to 896, and 925 − 896 = 29. The next cost (level 41) is 74 > 29, which explains the InsufficientFunds replies. |
| A-7 | One InsufficientFunds reply | At Level 41 with Gold 29, cost 74 > 29 |
| C-3 | `defeats=7183`, `stage=7199`, `hp=2.5508715463324365e518/…`, `gold=7.7824428161429955e355` | EnemyMaxHP(7199) = 10 × 1.18^7198 ≈ 2.550872e518. The sum of rewards through stage 7198 is ≈ 7.7824e355. 7199 = 7183 + 16, so C-3 started at stage 16, carried over from C-1/C-2 in the same Play session (allowed). |
| C-4 | `hits=2139 defeats=22 gold=453 stage=23 hp=270/381` | 2,161 damage at tap damage 1. Stages 1–22 total 2,050 HP, so 22 defeats, with 111 damage on the stage 23 enemy (381 HP), leaving 270. Rewards for stages 1–22 add up to 453. |
| N-5 | `5.4109650808412066e43 / 1.1410965080841207e44`, bar ≈ 47 % | 1.1410965080841207e44 − 6e43 = 5.410965080841206e43, which is 47.4 % (inside the guide's 45–70 %) |
| C-5 | Cleanup checks at 02:06:51, 02:08:58 and 02:18:43 | The window from the first to the final check is 11 min 52 s, consistent with a session longer than 10 minutes |

### 3.4 Reported procedures that differ from the guide

| Test | Guide | Reported | Treatment |
|---|---|---|---|
| A-4 | **One** request with ID `100` | Initial run sent **100 separate requests** (owner clarified). A later fresh session sent **one** request with ID `100`. Output: `04:00:35.259 [QA] A-4 id=100 reason=InsufficientFunds level=1 - Client`. The owner confirmed Gold remained `0` and the red `Not enough Gold` appeared. | The exact-guide repeat is **PASS**; do not treat the original 100 requests as 100 accepted/replied requests. R-12 resolved. |
| L-2, L-4 | The remaining player is Player1 | The remaining player was **Player2**; the new player was **Player3** | Equivalent check of an unaffected remaining player. These sessions followed the first L-1 attempt, whose capture targeted the wrong player; L-1 was later repeated cleanly. |
| C-4 | C.16 prints `[QA] auto-attack ran …` | Output reads `[QA] normal-damage auto-attack ran 181 s` | A relabelled variant of C.16 was used; its text was not supplied. The counts are consistent (3.3). |
| MOB-6 | Rotation interactions and 1 `CombatHud` / 1 `UpgradePanel` in PlayerGui | Three orientation changes with successful slime touches and zero panel attacks were initially reported. The owner subsequently confirmed the remaining rotation and that the duplicate-HUD check worked, without quoting new counts. | **PASS by owner confirmation**; detailed fourth transition / 1-and-1 Output not supplied (R-7). |

## 4. Results

| ID | Test | Result | Notes (only what was reported; derived or inferred items are labelled) |
|---|---|---|---|
| P-1 | Place, folders, remotes, CharacterAutoLoads | **PASS** | Graded by the adapted P-5 run, whose checker also covers the folders, the exactly-6 RemoteEvents and CharacterAutoLoads |
| P-2 | 24 scripts created | **PASS** | Graded by P-5: 24/24 matching against the candidate-adapted rows, 0 extra scripts |
| P-3 | Source-parity check | **PARTIAL** | Before testing: 22/24 matching against the frozen table, 6/6 remotes. The two mismatches are the intended candidate files, **not a defect**. Their candidate content was not checked until P-5. Extra-script count not supplied. |
| P-4 | Downloaded files' SHA-256 (optional) | **NOT VERIFIED** (optional) | No result reported |
| P-5 | Final parity re-check | **PASS** | Adapted checker. The final run at 03:32:33.698 came after the bridge was deleted again following the L-1 repeat, and `EmptyTests` (T-2) had also been deleted. The earlier 02:21:09.684 run also passed. Output quoted in section 2. |
| T-1 | Unit tests pass (adapted: 67 tests in 7 suites) | **PASS** | Reported 67/67 in Roblox Studio. Per-suite lines not supplied (adapted expectation in 3.1). |
| T-2 | Broken test module is a failure | **PASS** | With the temporary `EmptyTests`: `[Tests] FAIL could not load EmptyTests: did not return a test suite` and `[Tests] 1 FAILED, 67 passed`; no `ALL PASSED` appeared. After `EmptyTests` was deleted: `[Tests] ALL PASSED (67 tests)`. This matches the candidate-adapted expectation (3.1). |
| X-1 | *(added)* DEFECT-001/001B BigNum FTZ/subnormal Studio checks | **PASS** | Reported passed in **Edit, Server and Client** contexts. Probe lines not supplied. This covers the arithmetic and serialization round-trip items of `review/DEFECT-001B_REPORT.md` §9; the unit-test item is T-1. |
| M1-1 | Clean startup | **PASS** | Owner observed clean startup passing. The `Created combat state …` line and the startup Output were not quoted. |
| M1-2 | No avatar, fixed camera | **FAIL** | Reproduced: Focus `(0, 53.7913703918457, -1.8776741027832031)` instead of `(0, 54, 0)` and explicit assignment reverted on RenderStepped. Camera aim, position, Scriptable type, FOV and restrictions were correct. **Producer formally accepted as a Low-severity, nonblocking M2 deviation on 2026-11-03.** Strict FAIL is retained; not a code fix, QA PASS or general release approval (R-3, F-1). |
| M1-3 | Initial sync and HUD values | **PASS†** | Category statement only (3.2) |
| M1-4 | Ten taps defeat stage 1 once | **PASS†** | Category statement only |
| M1-5 | Stage 2 and 3 values | **PASS†** | Category statement only |
| M1-6 | Server tap cooldown | **PASS** | Burst accepted = **1** (of 200). 5 s spam accepted = **61** (limit 72). The sub-condition "HP and Gold change only by those accepted hits" was not itemized. |
| M1-7 | Clicks outside the combat area | **PASS†** | Category statement only |
| M1-8 | Extra attack arguments ignored | **PASS†** | Category statement only |
| U-1 | Panel at 0 Gold | **PASS†** | Category statement only |
| U-2 | First purchase | **PASS†** | Category statement only |
| U-3 | HUD, panel and hits agree | **PASS** | Owner explicitly confirmed consistent HUD Tap Damage, panel Tap Damage and real damage during normal upgrades through Level 25. U-5 (75) and N-2 (78/81/84) corroborate some levels. Per-purchase numerical logs were not supplied; the confirmation is owner testimony. |
| U-4 | Level 24 → 25 by playing | **PASS** | Owner explicitly confirmed **normal play** from Level 1 to 25, no Gold helper grants, and a 23-Gold Level 24→25 cost, 24→75 Tap Damage, 23 Gold deducted, next value 78 and next cost 25. U-3 owner confirmation covers consistent displays and real damage; U-5 independently verified the boundary hit via helper setup. Natural-run per-purchase logs and exact popup line were not supplied. |
| U-5 | Level 24 → 25 with exact Gold | **PASS** | Starting at Level 24, a 23-Gold grant bought Level 25 with **exactly 0 Gold** left; Tap Damage became **75**; one attack on an 85-HP enemy left **10 HP**. Not itemized: the E.2 Gold sequence and the count of 23 `Ok` replies in step 2, the panel `Next: 78 damage` / `Need 25 Gold` text, and the `-10` first hit on stage 1. |
| U-6 | Gold exact just below 2^53 (tested case) | **PASS** | An exact difference of 5 was confirmed. The logged balance (`9007199254740986` expected) and the HUD text were not quoted. |
| U-7 | Resync after purchases | **PASS** | Previously checked correct numerical resync; owner subsequently confirmed there was no visual change, flicker, reset or incorrect HUD/panel display. No screenshot supplied. |
| A-1 | Malformed upgrade requests | **PASS** | 16 malformed requests were rejected silently: no Upgrade or Currency reply |
| A-2 | ClientReady junk and spam | **PASS** | Burst syncs = **1** (limit 1). Spam syncs = **6** / printed limit **7**. The sub-condition "screen values never change" was not itemized. |
| A-3 | Replayed purchase ignored | **PASS** | Replayed ids 1 and 0 got no response; the new id 2 succeeded |
| A-4 | Server refuses unaffordable purchase | **PASS** | Initial test was 100 separate requests, **not** the guide's procedure. Fresh repeat sent one `FireServer("TapDamage", 100)`; owner supplied `04:00:35.259 [QA] A-4 id=100 reason=InsufficientFunds level=1 - Client` and confirmed Gold 0 and red `Not enough Gold` message. R-12 resolved. |
| A-5 | Burst of 100 purchase requests | **PASS** | Exactly **10** successful purchases; Level 3 → **13**; Gold 1000 → **925**. This matches the guide's exact expectation and the cost table (3.3). |
| A-6 | Sustained purchase requests | **PASS** | 50 requests over 2.92 s; replies = **32** / limit **34** (28 Ok, 4 InsufficientFunds); final Gold 29, Level 41. Consistent with the cost table (3.3). |
| A-7 | Largest request id | **PASS** | id `9007199254740991` produced exactly **one** reply (InsufficientFunds); the duplicate was ignored |
| B-1 | Combat independent per player | **PASS†** | Category statement only |
| B-2 | Purchases independent per player | **PASS†** | Category statement only |
| B-3 | Request ids per player | **PASS†** | Category statement only |
| B-4 | Cannot act for another player | **PASS†** | Category statement only |
| B-5 | Replay protection still independent | **PASS†** | Category statement only |
| D-4 | Startup sync with heavy lag | **PASS†** | Category statement only. Whether the lag setting had an effect: *not supplied* |
| D-1 | Taps under lag | **PASS†** | Category statement only |
| D-2 | Two purchase clicks before the reply | **PASS†** | Category statement only |
| D-3 | Several purchases in flight, then resync | **PASS†** | Category statement only |
| MOB-1 | Portrait layout | **PASS†** | On a recent iPhone in portrait, the layout was checked and the HUD and upgrade controls remained accessible. **Observations:** the upgrade panel partly covers the slime (the guide says to record that as an observation, not a FAIL), and text appeared small. Not itemized: "text is readable", not under the notch or top-bar buttons, and the panel not covering the pills or health bar. The Android phone (S22 Ultra) and the small phone are under MOB-7. |
| MOB-2 | Landscape layout | **PASS†** | On a recent iPhone in landscape, the layout was checked and the HUD and upgrade controls remained accessible. The same sub-conditions were not itemized, including the notch side. |
| MOB-3 | One tap = one attack | **PASS** | 10 emulated touches, each `processed=false`, in landscape: exactly 10 attacks (9 hits + 1 defeat). Device not stated. |
| MOB-4 | Panel and button taps never attack | **PASS** | 10 panel touches + 10 button touches: **0 attacks**, in both portrait and landscape |
| MOB-5 | Combat-area edges and insets | **PASS** | 15 touches on the HUD pills: 0 attacks. 2 touches just outside the panel: 2 attacks. Both orientations checked. Device not stated; the guide requires the notched phone (R-7). |
| MOB-6 | Rotate during combat | **PASS** | Three prior rotations: 3 successful slime interactions, 0 panel attacks. Owner subsequently confirmed the remaining rotation was tested and worked and that the PlayerGui duplicate HUD/panel check worked. Exact fourth-rotation logger and `1/1` line were not provided; this PASS is based on explicit user confirmation. |
| MOB-7 | Small phone and tablet | **PASS** | Owner confirmed iPhone 7 landscape as well as portrait, with no attacks from upgrade panel/button touches, and separately confirmed iPad panel/button filtering in both orientations. iPad and Galaxy S22 Ultra portrait/landscape were tested earlier. No verbatim device touch logs supplied. |
| MOB-8 | Touchscreen PC (optional) | **NOT RUN** | Optional |
| MOB-9 | Physical phone (optional) | **NOT RUN** | Optional |
| N-1 | BigNum spot checks | **PASS†** | Category statement only. The `[QA] BigNum spot checks: PASS` line was not quoted. |
| N-2 | Purchases with a huge Gold balance | **PASS** | With Gold `1.5e400`, three upgrades took Level 25 → 28 and Tap Damage 75 → 78, 81, 84. Not itemized: Gold still showing `1.5e400` after each purchase, and the `Upgraded!` messages. |
| N-3 | Huge tap damage display | **PASS†** | Category statement only |
| N-4 | High-stage HP display | **PASS** | Stage 600 displayed HP of about `1.14e44` in scientific notation (Appendix E.3 value). The Gold suffix display was not itemized. |
| N-5 | Health bar at large values | **PASS** | At stage 600, tap damage `6e43` left `5.4109650808412066e43 / 1.1410965080841207e44`, and the bar showed about 47 % (3.3). The next defeat advanced to stage 601 with full HP. |
| N-6 | Long numbers on the smallest phone | **PASS** | iPhone 7 portrait: `Gold: 1.5e400` and `Tap Damage: 1e5000` stayed inside their pills, with the text wrapped onto two lines (observation). Checked visually; screenshot captured (not in the repository). |
| L-1 | Player leaves; server cleans up | **PASS** | **Repeated** in a two-player server, with Player2 identified unambiguously and captured through the temporary QA bridge (the first attempt captured the wrong player).<br>• Before leaving: `[QA] captured Player2: currency=true combat=true level=1 session=true gold=0`<br>• On disconnect: `[CombatService] Removed combat state for Player2 (tracked players: 1)`<br>• After leaving: `[QA] after leave: currency=false combat=false level=nil session=false gold=nil`<br>Player1 then made five normal attacks successfully, and the owner confirmed no unexpected errors. This matches the guide's bridge criterion (Appendix D.4) exactly. |
| L-2 | New player joins running server | **PASS** | A new Player3 joined the running server with fresh state; Player2 kept its separate state (Stage 3, HP 10/13, Gold 0, Level 3, Tap Damage 3). Not itemized: the `Created combat state … (tracked players: 2)` line and Player3's individual starting values. |
| L-3 | Restart gives a fresh game | **PASS** | The player progressed to Stage 2, Gold 5, HP 11/11, Level 1, Tap Damage 1. After Stop and a new Play: Stage 1, Gold 0, HP 10/10, Level 1, Tap Damage 1. |
| L-4 | Leaving while requests arrive | **PASS** | Player3 disconnected while the 50 fast requests were being sent. The server removed its combat state and reported one tracked player remaining; Player2 kept attacking, with no errors reported. |
| C-1 | Baseline object counts | **PASS** | `TapArea=1 GoldPill=5 CombatStage=2 \| hud=43 panel=26 stage=38` |
| C-2 | Fast manual clicking | **PASS** | Counts returned to the baseline |
| C-3 | Ten minutes of enemy churn | **PASS** | `[QA] auto-attack ran 601 s`; `SUMMARY hits=0 defeats=7183 … currency updates=7183 \| gold=7.7824428161429955e355 stage=7199 hp=2.5508715463324365e518/2.5508715463324365e518`. Counts matched the baseline. The loop ran its full duration, so the game kept responding. Logged values are finite, non-negative and in scientific form (3.3). Not itemized: the HUD's rendering of those values. Memory at 1 / 5 / 10 min: *not supplied* (optional observation). |
| C-4 | Three minutes at tap damage 1 | **PASS** | `[QA] normal-damage auto-attack ran 181 s`; `SUMMARY hits=2139 defeats=22 … currency updates=22 \| gold=453 stage=23 hp=270/381`. Counts matched the baseline. Exactly consistent with the HP and reward formulas (3.3). |
| C-5 | Long manual session | **PASS** | More than 10 minutes, with cleanup counts `TapArea=1 GoldPill=5 CombatStage=2 \| hud=43 panel=26 stage=38` matching baseline at 02:18:43 after checks at 02:06:51 and 02:08:58. Owner explicitly confirmed no noticeable slowdown, freezing or unexpected red errors during the session. The Output file itself was not provided. |

### 4.1 Totals

Guide tests (62):

| PASS | PASS† (needs confirmation) | FAIL | PARTIAL | BLOCKED | NOT RUN (optional) | NOT VERIFIED |
|---|---|---|---|---|---|---|
| **37** | **20** | **1** | **1** | **0** | **2** | **1** (optional P-4) |

On the template's four-mark line: **PASS 37 (+20 conditional), FAIL 1 (producer-accepted nonblocking exception), BLOCKED 0, NOT RUN 2 (optional).** Another 1 PARTIAL (P-3) and 1 optional NOT VERIFIED result do not fit those four marks; neither is a pass.

- **PASS:** P-1, P-2, P-5, T-1, T-2, M1-1, M1-6, U-3, U-4, U-5, U-6, U-7, A-1, A-2, A-3, A-4, A-5, A-6, A-7, MOB-3, MOB-4, MOB-5, MOB-6, MOB-7, N-2, N-4, N-5, N-6, L-1, L-2, L-3, L-4, C-1, C-2, C-3, C-4, C-5.
- **PASS†:** M1-3, M1-4, M1-5, M1-7, M1-8, U-1, U-2, B-1 to B-5, D-1 to D-4, MOB-1, MOB-2, N-1, N-3.
- **FAIL:** M1-2 (producer formally accepted Low/nonblocking deviation; strict FAIL retained).
- **PARTIAL:** P-3 (initial frozen checker mismatches two intentional candidate files; final P-5 candidate-adapted parity passed).
- **BLOCKED:** none.
- **NOT RUN:** MOB-8, MOB-9.
- **NOT VERIFIED:** P-4 (optional).
- **Added check X-1:** PASS (not counted in the 62).

Changes from revision 5 (owner confirmations on 2026-11-03):
- **PARTIAL → PASS:** U-3, U-4, U-7, MOB-6, MOB-7, C-5.
- **PASS† → PASS:** A-4 (fresh one-request repeat, response and visual confirmation).
- **M1-2:** strict FAIL retained, with formal producer acceptance of Low/nonblocking risk.
- Other evidence and release-readiness questions remain open.

Changes from revision 2:
- **T-2:** NOT VERIFIED → PASS.
- **L-3:** NOT VERIFIED → PASS.
- **L-1:** BLOCKED → PASS, after the repeat with an unambiguous capture.
- **M1-2:** stayed FAIL when reproduced; disposition later approved in revision 6.
- **P-5:** stays PASS, with the newer final run.

Changes from revision 1:
- **To PASS:** M1-1, M1-6, U-5, U-6, A-1, A-2, A-3, A-5, A-6, A-7, MOB-3, MOB-4, MOB-5, N-2, N-4, N-5, N-6, L-2, L-4 and C-3.
- **To PARTIAL:** P-3 (expected candidate deviation) and U-7 (visual condition not confirmed).
- **MOB-1 and MOB-2:** from NOT VERIFIED to PASS† (summary-level layout evidence).
- **A-4:** stays PASS†, now because its procedure differs from the guide.

## 5. Failure reports

```text
Test ID: M1-2 (failure F-1)
Session / mode: Session 1, Play, one player; repeated later. Emulator device and orientation: not supplied (Session 1 is desktop).
Steps I did (exact): not supplied in detail; guide M1-2 steps (camera input, then Appendix C.3, then C.4) assumed.
  Repeat: Focus checked again; then the expected Focus was assigned explicitly and read back.
Expected (from the guide):
  [QA] CAMERA character=nil type=Enum.CameraType.Scriptable focus=0, 54, 0 position=0, 56, 18 fov=50
  [QA] CAMERA after reset type=Enum.CameraType.Scriptable focus=0, 54, 0
What happened instead: Camera.Focus.Position = (0, 53.7913703918457, -1.8776741027832031).
  Repeat: the same Focus value. Camera position, rotation, field of view, Scriptable type and
  movement restrictions were correct. An explicit assignment of the expected Focus took effect
  immediately, then reverted on the next RenderStepped frame.
  Not supplied: the verbatim C.3 and C.4 lines.
Output lines: not supplied beyond the focus value.
_G.QA.summary() line: not relevant.
Screenshot file names: not supplied.
Reproduced: yes (original run and the repeat); exact count of fresh-Play tries not supplied.
P-3 parity line at the time: 22 / 24 against the frozen table (expected for the candidate; see 3.1). P-5 at the end: 24 / 24 PASS (adapted).
Notes: recorded as a strict FAIL, as instructed. No script was edited.
  Disposition: producer explicitly approved Low-severity, nonblocking M2 deviation on 2026-11-03;
  the strict QA result remains FAIL and no fix was made. No visible gameplay impact observed.
```

**Reviewer analysis of F-1.** This is analysis, not a new observation, and no fix was made.
- **What the code sets.** `ArenaView.luau:417-424` (`applyCamera`) sets `CameraType = Scriptable`, `CFrame = CFrame.lookAt((0, 56, 18), (0, 54, 0))` and then `Focus = CFrame.new(0, 54, 0)`. The comment at lines 421-422 states that Scriptable cameras never update `Focus` on their own.
- **Where the observed point lies.** It is the point **exactly 20 studs** from the camera position along that look direction. The computed point is `(0, 53.79136948, -1.87767469)`; the observed value matches to float32 precision.
- **What the repeat adds:** the camera's position and aim are as designed. Something writes `Focus` **every frame**: an explicit assignment reverted on the next RenderStepped. That contradicts the comment at `ArenaView.luau:421-422` that Scriptable cameras never update `Focus` on their own.
- **What it does not establish:** which component writes it. A default camera script bound to the render step, or the engine itself, are possibilities.
- **Impact.** `Camera.Focus` steers engine detail and streaming priorities, not what the player sees; the displacement is about 2.2 studs, and the owner observed no visible gameplay problem.
- **Disposition.** The producer formally approved **Low-severity, nonblocking for M2** on 2026-11-03. M1-2 remains **strict FAIL**, and the technical cause remains for independent review. This does not approve code changes, the candidate or PR merge; no gameplay code was changed and Milestone 2.1 is not started.
- **Evidence still missing:** the verbatim C.3 and C.4 lines.

## 6. Open release-blocking questions

| # | Question | Why it blocks | Status |
|---|---|---|---|
| R-1 | Which expected values did the P-5 checker use for `BigNum` and `BigNumTests`? | An unmodified Appendix B cannot pass with the candidate | **RESOLVED.** The checker was adapted with the candidate values (2.1), and the Output is quoted in section 2. The initial 22/24 was the intended difference. |
| R-2 | Confirm no unexpected red Output lines **across all PASS/PASS† tests**, preferably with `QA_*.txt` files, and check 20 remaining PASS† rows individually. The owner did explicitly confirm no red errors for L-1 and C-5. A-4 is now fully confirmed. | Guide 0.3 requires all conditions and no red errors | **OPEN, narrowed** |
| R-3 | M1-2: reproduced Focus overwrite. **Producer formally accepted Low-severity/nonblocking deviation** on 2026-11-03, retaining strict FAIL. Reviewer may characterize source as code, guide or Studio issue. C.3/C.4 verbatim lines are still absent. | Producer exception addresses release-blocking disposition, but not underlying technical root cause / missing verbatim logs | **Producer disposition RESOLVED; technical/log follow-up open, producer-deemed nonblocking** |
| R-4 | Repeat L-1 with unambiguous player identities | Per-player service cleanup on leave is a reliability and isolation requirement | **RESOLVED.** Repeated with Player2 captured through the bridge; `afterLeave` printed `currency=false combat=false level=nil session=false gold=nil`. L-1 PASS. |
| R-5 | Run T-2 (negative control) and L-3 (restart is fresh). P-4 is optional. | Required tests with no result | **RESOLVED.** T-2 PASS (`1 FAILED, 67 passed`, then `ALL PASSED (67 tests)`); L-3 PASS. P-4 (optional) still has no result. |
| R-6 | U-3/U-4/U-7: owner confirmed natural Level 1–25 play, the 23 Gold / 24→75 boundary, HUD/panel/real-hit agreement and unchanged resync UI. U-5 also verified boundary arithmetic. Detailed natural-run purchase log and popup not supplied. | Owner-reported PASS criteria now covered; evidence remains less granular than full Output | **RESOLVED by owner confirmations; detailed logs desirable** |
| R-7 | MOB-6/MOB-7: owner confirmed final rotation, no duplicate HUD/panel, iPhone 7 landscape and tablet touch filtering; marked PASS on owner report. **Still open:** MOB-1/MOB-2 text readability, notch/overlap details; device identity in MOB-3/MOB-5; verbatim fourth rotation / `1/1` counts. | Mobile primary platform; independent acceptance needs clear evidence and notch verification | **PARTIALLY RESOLVED; remaining details open** |
| R-8 | C-5: owner confirmed no slowdown, freezing or unexpected red errors through >10-min session; object counts previously matched. Output file not provided. | Owner-confirmed C-5 conditions | **RESOLVED by owner confirmation; logs desirable** |
| R-9 | The tested code is the **DEFECT-001B candidate**, not the approved release.<br>**Done (native/offline, 2.2):** Codex's independent read-only review — BigNum technical verdict PASS WITH RISKS, no additional blocking numerical or serialization defect; native Luau 0.745 compilation of both changed files PASS; BigNum strict analysis (old and new solvers) PASS; test-body analysis with typed context adapters PASS; 67/67 offline in all four floating-point modes; historical probes 75/75 gradual and **74/75 FTZ** (outdated differential expectation).<br>**Done (Roblox Studio, 2.3):** Script Analysis on the saved candidate place: 0 Errors, 6 Warnings, 0 Information, 0 Hints; no diagnostics in `BigNum` or `BigNumTests`. The six warnings are identified and **provisionally** classified: four `DuplicateCondition` warnings in `RateLimiterTests` (lines 24 and 30) as analyzer false positives, and two `TypeError` warnings in `CombatClient` (53,19) for the possibly nil `Players.LocalPlayer` as a documented typing concern with no runtime failure observed. All six are pre-existing in frozen `e9d878d`.<br>**Still needed:**<br>• reviewer confirmation of the provisional warning classification, and a decision to fix or formally accept the `CombatClient` `Player?` typing concern (W-5, W-6);<br>• the producer's decision on the risks behind "PASS WITH RISKS";<br>• a reviewed revision of the pin, manifest round 4, the parity tables, the installer payload and the test count (67). | These QA results apply only to `9a988c9`'s `src/`. Codex did **not approve** candidate adoption, full QA acceptance or PR #1 merge readiness. | Open (independent review, native analysis and Studio Script Analysis evidence done; warning classification provisional; adoption NOT APPROVED) |
| R-10 | Supply the missing setup facts: tester, Studio version, OS, install method, the test dates other than November 3, and the date of the 03:32 P-5. Also the screenshots: the N-6 capture and F-1. | Traceability required by guide 12.4 | Open |
| R-11 | Confirm the H-check outcome (the H-4 line). The bridge was demonstrably used (L-1 repeat). Was that because the helpers were "not connected"? | Shows how the helper-based results (U-5, U-6, A-5, N-2 to N-6, C-3) reached the live game | Open (bridge use confirmed; H-4 result not reported) |
| R-12 | A-4: initial test was 100 **separate** requests, later replaced by the exact one-request ID-100 test. Output at 04:00:35.259 shows `InsufficientFunds level=1`; Gold stayed 0 and red message appeared per owner. This is not evidence that 100 requests all got responses. | Guide procedure completed | **RESOLVED: A-4 PASS** |

## 7. Observations (not failures)

- **Portrait layout (recent iPhone):** the upgrade panel partly covers the slime model; the guide (MOB-1) says to record that as an observation. Text appeared small (readability is part of R-7).
- **N-6 (iPhone 7 portrait):** the long values wrap onto two lines inside their pills.
- **C-4** used a relabelled variant of the C.16 snippet (`normal-damage auto-attack`); its text was not supplied.
- **C-3** started at stage 16, carried over from C-1/C-2 in the same Play session (3.3). The guide allows this.
- **Memory:** no readings were supplied for C-3; they are optional.
- **L-2 and L-4:** Player2 was the remaining original player and Player3 the joining one, rather than the guide's Player1.
- **Separate place file:** the QA place `Emberbound_M2_DEFECT001_QA.rbxl` is a candidate copy, as `DEFECT-001B_REPORT.md` §9 required; the original QA place was not to be changed.
- **Temporary objects:** the temporary QA bridge was added for the L-1 repeat and deleted again; `EmptyTests` was deleted after T-2. The final P-5 (03:32:33.698) reports `extra scripts: 0`, so neither remained.
- **M1-2:** an explicit Focus assignment reverts on the next RenderStepped frame, contrary to the assumption in the code comment at `ArenaView.luau:421-422`. Producer accepted Low/nonblocking deviation, while strict FAIL remains (F-1).
- **Provenance limit:** the Milestone 1 report (`QA_REPORT.md`) is a user-reported summary with no logs. This report shares that limit, except for the quoted Output lines.

## 8. For the independent (Codex) review

Codex's read-only review of the candidate code is recorded in 2.2. For any further review of **this QA report**, review it read-only against `M2_STUDIO_REGRESSION_GUIDE.md` (as on PR #1 head `2b832d2`), the template, `review/DEFECT-001B_REPORT.md` and the code at `9a988c9`. In particular:
1. Check every mark against the guide's PASS/FAIL rules (0.3). Nothing should be credited beyond the evidence stated in each row.
2. Check the arithmetic in 3.3 against `ProgressionConfig`, `GameConfig` and Appendix E, and the deviations in 3.1 and 3.4.
3. Assess F-1 (M1-2) from `ArenaView.luau:415-440` and the repeat evidence (Focus reverts every RenderStepped frame). Say whether it is a code defect, a guide error or a Studio-dependent risk. The producer **already approved Low/nonblocking acceptance**; retain the strict FAIL, and evaluate any residual risk.
4. Decide which items in section 6 are release-blocking for PR #1 and for adopting the DEFECT-001B candidate.

Do not fabricate Studio output, do not merge, and do not mark Milestone 2 complete.
