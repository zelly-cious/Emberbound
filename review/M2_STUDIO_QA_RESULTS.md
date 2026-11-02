# Emberbound Milestone 2 — Roblox Studio QA results

Filled in from `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`, following `M2_STUDIO_REGRESSION_GUIDE.md` (the version pinned to `e9d878d`, as on PR #1 head `2b832d2`).

| | |
|---|---|
| **Overall status** | **CONDITIONAL — NOT A PASS.** 1 FAIL (M1-2), 1 BLOCKED (L-1), 5 PARTIAL, and 14 tests with no result reported. 32 passes rest on a category-level statement that still needs confirming (PASS†). Section 6 lists the open release-blocking questions. |
| **Provenance** | The project owner ran the tests and reported the results as a written summary. Output files (`QA_*.txt`), screenshots and verbatim Output lines were **not** supplied to the repository. Claude Code wrote this report from that summary and from repository evidence. No result, number, screenshot or measurement was added that the owner did not report; where something was derived or inferred, it says so. |
| **Where the referenced files are** | The tested code, `review/DEFECT-001_REPORT.md`, `review/DEFECT-001B_REPORT.md` and `review/DEFECT-001B_CODEX_HANDOFF.md` are on branch `candidate/m2-defect-001-ftz-subnormal` at `9a988c9`. The pinned guide and template are on PR #1 head `2b832d2`, and also on `9a988c9`. This report is committed on `claude/emberbound-m2-regression-testing-56vtjh`, which holds an older, unpinned copy of the guide; review against the pinned version. |
| **Not done** | PR #1 is not merged. Milestone 2 is not marked complete. Milestone 2.1 is not started. No gameplay source was changed. |

## 1. Marks used

The template allows PASS, FAIL, BLOCKED and NOT RUN. Three extra marks are added so that the report does not overstate the results. Only PASS counts as a pass.

| Mark | Meaning in this report |
|---|---|
| **PASS** | The owner reported the test as passed, and the reported facts cover its PASS conditions. |
| **PASS†** | The owner reported a whole category as passing its "primary numerical checks" (section 3.2), and this report maps the test to that category. The test's other PASS conditions were **not itemized**: for example no red or orange Output lines (guide 0.3), visual feedback, or exact logger lines. **Needs confirmation (R-2).** |
| **FAIL** | A PASS condition was observed not to hold. |
| **PARTIAL** | Part of the test was done, and at least one required part was not completed or not confirmed. Not a pass. |
| **BLOCKED** | The test could not be completed conclusively; the reason is given. |
| **NOT RUN** | An optional test that was skipped, as reported. |
| **NOT VERIFIED** | No result was reported. For a required test this is an open item, not a pass. The template reserves NOT RUN for optional tests. |

## 2. Test setup

| | |
|---|---|
| Tester | Project owner (name not supplied) |
| Date(s) | Not supplied. This report was prepared on 2026-11-02. |
| Roblox Studio version | Not supplied. The owner's earlier DEFECT-001B Edit-mode diagnostic reported Luau `0.745.0.7451137`. |
| Computer and OS | Not supplied |
| Place file name | `Emberbound_M2_DEFECT001_QA.rbxl`, saved after testing. This is the separate candidate copy that `review/DEFECT-001B_REPORT.md` §9 asked for; the guide's default name is `Emberbound_M2_QA.rbxl`. |
| Code tested | `src/` at `9a988c9254e07ac50dcf32fe4b55ba975613390d` (branch `candidate/m2-defect-001-ftz-subnormal`). This equals the frozen `e9d878d94155610558c9c6252d76f202dfd956b4` except for `BigNum.luau` and `BigNumTests.luau`; confirmed with `git diff --name-only e9d878d 9a988c9 -- src`. See section 3.1. |
| How the scripts were installed | Not supplied |
| P-3 result | Not supplied |
| P-5 result | Reported as: 24 / 24 scripts matching, 6 / 6 RemoteEvents, 0 extra scripts, `RESULT: PASS`. The verbatim `[Parity]` lines were not supplied. Which expected values the checker used is open (R-1). |
| H-check result | Not reported directly. The owner reports that a **temporary QA bridge was deleted before final parity**. The guide uses the bridge only when the helpers are "not connected" (Appendix D.4), so the inferred case is "Helpers not connected, used the EmberboundQA bridge". **To be confirmed (R-11).** |
| Devices used in the emulator | Not supplied |
| Physical phone | None (MOB-9 not run) |

### 2.1 Candidate source files (not in any approved manifest)

| File | Frozen `e9d878d` SHA-256 (round 3) | Tested candidate `9a988c9` SHA-256 | Candidate bytes / lines / Adler-32 (parity checker values) |
|---|---|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | `c7474136d45bada326484a786fd60ff5ca02a18a12b4012fbcfca01a3950244a` | `e337573da95f481a022ed0e6f31dfefdacb0755921214cdb89cdb53d8e08f674` | 16287 / 532 / 3188390913 |
| `src/ServerScriptService/Tests/BigNumTests.luau` | `0c13e4842d1420b285243e824c012bca32cbe13e09df278af53ae709d914d97a` | `8d28a9bf19fa29cf3ccf53dc5dd066f2777ef85548a35911b19f1feab4113b51` | 23275 / 578 / 1646015937 |
| The other 22 files | equal to round 3 | equal to round 3 | as in guide Appendix A |

## 3. Reconciliation with the guide and the repository

### 3.1 Deviations from the guide, caused by testing the candidate

1. **Code under test.** The guide (and the template's "Code tested" row) pins `e9d878d`. This run tested the DEFECT-001B candidate, so every result applies to `9a988c9`'s `src/`, not to the frozen release. The candidate is **not adopted**. Adopting it needs a separately reviewed revision: the source pin, manifest round 4, the Appendix A/B tables, the installer payload and the test count.
2. **T-1 expectation: 67 tests, not 61.** The candidate's `BigNumTests` has 31 tests: the original 25, plus 2 from DEFECT-001 and 4 from DEFECT-001B. The adapted expectation below is **derived from the source**, not copied from Studio Output:
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
3. **T-2 expectation.** With the candidate, the negative control would print `[Tests] 1 FAILED, 67 passed`, not `1 FAILED, 61 passed`.
4. **P-3 and P-5 expected values.** Rows 1 and 12 of Appendix B hold the frozen values: `BigNum` 15064 / 508 / 3533007835 and `BigNumTests` 13960 / 383 / 755231800. With the candidate files installed, an **unmodified** Appendix B checker would report `content differs` for those two rows, `scripts matching: 22 / 24` and `RESULT: FAIL`. The reported 24 / 24 therefore implies that those two rows were replaced with the candidate values in section 2.1. That is a deduction, not a reported fact (**R-1**).

### 3.2 How the owner's category statement was mapped to tests

The owner reported: "Combat, upgrades, currency, request validation, replay protection, multiplayer isolation, network-lag behavior, and large-number displays passed their primary numerical checks." This report maps the categories to tests as follows. The mapping is the report author's reading and **must be confirmed by the owner (R-2)**.

| Category | Tests mapped to it | Not mapped (reported separately or not covered) |
|---|---|---|
| Combat | M1-3, M1-4, M1-5, M1-6, M1-7, M1-8 | M1-1 (startup Output, not numerical); M1-2 (reported FAIL) |
| Upgrades | U-1, U-2, U-5 (also reported separately), N-2 | U-3 and U-4 (reported incomplete); U-7 (follows the incomplete U-4) |
| Currency | U-6 | — |
| Request validation | M1-6, M1-8, A-1, A-2, A-4, A-5, A-6, A-7 | — |
| Replay protection | A-3, B-3, B-5 | — |
| Multiplayer isolation | B-1, B-2, B-4 | L-1 to L-4 (session lifecycle, reported separately or not at all) |
| Network-lag behaviour | D-1, D-2, D-3, D-4 | — |
| Large-number displays | N-1, N-2, N-3, N-4, N-5 | N-6 (part of the mobile session; not itemized) |

### 3.3 Consistency checks on the reported numbers (analysis, not new observations)

- **C-4.**
  - The reported figures (181 s, 2,139 hits, 22 defeats) mean 2,161 accepted taps at tap damage 1.
  - With `EnemyMaxHP(stage) = floor(10 × 1.18^(stage − 1))` (`GameConfig.luau:115-119`), stages 1–22 total 2,050 HP and stages 1–23 total 2,431 HP. So 2,161 damage gives exactly 22 defeats, with 111 damage on the stage 23 enemy.
  - The auto-attack sends at most about 2,262 requests in 181 s (one every 0.08 s). **Consistent.**
- **C-3.**
  - 601 s at one request every 0.08 s is about 7,512 requests, so 7,183 defeats means about 95.6 % were accepted, below the 0.07 s server cooldown. **Plausible.**
  - Final Stage 7199 = 7,183 + 16. That is consistent with C-3 starting at stage 16, carried over from C-1/C-2 in the same Session 7 Play. The starting stage was not recorded.
- **Cleanup counts.** The baseline and every final C-1 to C-5 count reported are `TapArea=1 GoldPill=5 CombatStage=2 | hud=43 panel=26 stage=38`. The first three numbers match guide C-1's fixed expectation.

## 4. Results

| ID | Test | Result | Notes (only what was reported; derived or inferred items are labelled) |
|---|---|---|---|
| P-1 | Place, folders, remotes, CharacterAutoLoads | **PASS** | Graded by the final P-5 run (the same checker covers the folders, the exactly-6 RemoteEvents and CharacterAutoLoads). The initial P-3 grading was not reported. |
| P-2 | 24 scripts created | **PASS** | Graded by P-5: 24/24 matching, 0 extra. Subject to R-1 (which reference values were used). |
| P-3 | Source-parity check | **NOT VERIFIED** | Initial parity lines not supplied. P-5 shows only the end state. |
| P-4 | Downloaded files' SHA-256 (optional) | **NOT VERIFIED** (optional) | No result reported |
| P-5 | Final parity re-check | **PASS** | Reported: 24/24 scripts, 6/6 RemoteEvents, 0 extra scripts, `RESULT: PASS`, run after the temporary QA bridge was deleted. Verbatim lines and the checker's expected values were not supplied (R-1). |
| T-1 | Unit tests pass (adapted: 67 tests in 7 suites) | **PASS** | Reported 67/67 in Roblox Studio. Per-suite lines not supplied; the adapted expectation is in 3.1. |
| T-2 | Broken test module is a failure | **NOT VERIFIED** | No result reported. Expected with the candidate: `could not load EmptyTests …` and `1 FAILED, 67 passed`. |
| X-1 | *(added)* DEFECT-001/001B BigNum FTZ/subnormal Studio checks | **PASS** | Reported passed in **Edit, Server and Client** contexts. The specific probe lines were not supplied. This covers the Studio validation items in `review/DEFECT-001B_REPORT.md` §9 (arithmetic and serialization round trip); the unit-test item is T-1. |
| M1-1 | Clean startup | **NOT VERIFIED** | Not reported: the `Created combat state …` line, and the absence of red, unlisted orange, `Infinite yield`, `CharacterAutoLoads` and `No combat sync yet` lines |
| M1-2 | No avatar, fixed camera | **FAIL** | `Camera.Focus.Position` was `(0, 53.7913703918457, -1.8776741027832031)`; the guide's strict expectation is `0, 54, 0`. The owner reports that other camera behaviour appeared functional. See failure report F-1. |
| M1-3 | Initial sync and HUD values | **PASS†** | Combat/currency category |
| M1-4 | Ten taps defeat stage 1 once | **PASS†** | Combat category |
| M1-5 | Stage 2 and 3 values | **PASS†** | Combat category |
| M1-6 | Server tap cooldown | **PASS†** | Combat / request-validation category. burst accepted = *not supplied*; 5 s spam accepted = *not supplied* |
| M1-7 | Clicks outside the combat area | **PASS†** | Combat category (the input part of this mapping is assumed; confirm) |
| M1-8 | Extra attack arguments ignored | **PASS†** | Request-validation category |
| U-1 | Panel at 0 Gold | **PASS†** | Upgrades category |
| U-2 | First purchase | **PASS†** | Upgrades category |
| U-3 | HUD, panel and hits agree | **PARTIAL** | Checked after every U-4 purchase, so it can only be as complete as U-4 |
| U-4 | Level 24 → 25 by playing | **PARTIAL** | Reported: the natural-progression boundary hit was **incomplete**. Which U-4 steps were completed was not itemized. Gold before / after the 23-Gold purchase: *not supplied*. U-5 separately covers the exact transition. |
| U-5 | Level 24 → 25 with exact Gold | **PASS†** | Reported: exact Level 24 → 25 transition verified. The step 5 hit checks were not itemized: `-10` on stage 1, then `-75` leaving `10 / 85` on stage 14. |
| U-6 | Gold exact just below 2^53 (tested case) | **PASS†** | Currency category. Logged balance (`9007199254740986` expected): *not supplied* |
| U-7 | Resync after purchases | **NOT VERIFIED** | Runs at the end of U-4, which was incomplete. Not itemized. |
| A-1 | Malformed upgrade requests | **PASS†** | Request-validation category |
| A-2 | ClientReady junk and spam | **PASS†** | Request-validation category. burst syncs = *not supplied*; spam syncs = *not supplied* / limit |
| A-3 | Replayed purchase ignored | **PASS†** | Replay-protection category |
| A-4 | Server refuses unaffordable purchase | **PASS†** | Request-validation category |
| A-5 | Burst of 100 purchase requests | **PASS†** | Request-validation category. Replies, level and Gold after: *not supplied*. With the 1000-Gold grant the expected values are ok=10, Level 13, Gold 925. |
| A-6 | Sustained purchase requests | **PASS†** | Request-validation category. replies = *not supplied* / limit |
| A-7 | Largest request id | **PASS†** | Request-validation category |
| B-1 | Combat independent per player | **PASS†** | Multiplayer-isolation category |
| B-2 | Purchases independent per player | **PASS†** | Multiplayer-isolation category |
| B-3 | Request ids per player | **PASS†** | Replay-protection category |
| B-4 | Cannot act for another player | **PASS†** | Multiplayer-isolation category |
| B-5 | Replay protection still independent | **PASS†** | Replay-protection category |
| D-4 | Startup sync with heavy lag | **PASS†** | Network-lag category. Whether the lag setting had an effect: *not supplied* |
| D-1 | Taps under lag | **PASS†** | Network-lag category |
| D-2 | Two purchase clicks before the reply | **PASS†** | Network-lag category |
| D-3 | Several purchases in flight, then resync | **PASS†** | Network-lag category |
| MOB-1 | Portrait layout | **NOT VERIFIED** | No result reported. Devices: *not supplied* |
| MOB-2 | Landscape layout | **NOT VERIFIED** | No result reported. Devices: *not supplied* |
| MOB-3 | One tap = one attack | **NOT VERIFIED** | No result reported |
| MOB-4 | Panel and button taps never attack | **NOT VERIFIED** | No result reported |
| MOB-5 | Combat-area edges and insets | **NOT VERIFIED** | No result reported. This is the inset risk the round 1 audit asked to test. |
| MOB-6 | Rotate during combat | **PARTIAL** | Reported: some orientation/device checks incomplete |
| MOB-7 | Small phone and tablet | **PARTIAL** | Reported: some orientation/device checks incomplete |
| MOB-8 | Touchscreen PC (optional) | **NOT RUN** | Reported not run (optional) |
| MOB-9 | Physical phone (optional) | **NOT RUN** | Reported not run (optional) |
| N-1 | BigNum spot checks | **PASS†** | Large-number category. Not supplied: the `[QA] BigNum spot checks: PASS` line. |
| N-2 | Purchases with a huge Gold balance | **PASS†** | Large-number / upgrades category |
| N-3 | Huge tap damage display | **PASS†** | Large-number category |
| N-4 | High-stage HP display | **PASS†** | Large-number category. Final stage and HP text: *not supplied* |
| N-5 | Health bar at large values | **PASS†** | Large-number category. The bar staying inside its frame is a visual condition that was not itemized. |
| N-6 | Long numbers on the smallest phone | **NOT VERIFIED** | Mobile-session test; not itemized. The small-phone checks (MOB-7) were incomplete. |
| L-1 | Player leaves; server cleans up | **BLOCKED (partial)** | Reported: full cleanup of the disconnected player was **not conclusively verified**, because the player identities were mixed up. Not confirmed for the leaving player: `Removed combat state for Player2 (tracked players: 1)`, and `currency=false combat=false level=nil session=false` (or the bridge's `afterLeave` equivalent). |
| L-2 | New player joins running server | **NOT VERIFIED** | No result reported |
| L-3 | Restart gives a fresh game | **NOT VERIFIED** | No result reported |
| L-4 | Leaving while requests arrive | **NOT VERIFIED** | No result reported |
| C-1 | Baseline object counts | **PASS** | `TapArea=1 GoldPill=5 CombatStage=2`; hud=43 panel=26 stage=38 |
| C-2 | Fast manual clicking | **PASS** | Reported: the cleanup counts returned to baseline |
| C-3 | Ten minutes of enemy churn | **PASS†** | Reported: 601 s, 7,183 enemy defeats, final Stage 7199; the cleanup counts matched baseline (section 3.3). Not itemized: no red errors, scientific HP/Gold display, and that the game kept responding. Memory at 1 / 5 / 10 min: *not supplied* (optional observation). |
| C-4 | Three minutes at tap damage 1 | **PASS** | Reported: 181 s, 2,139 hits, 22 defeats; the cleanup counts matched baseline. Consistent with the HP formula (section 3.3). |
| C-5 | Long manual session | **PARTIAL** | Reported: the extended manual session's final cleanup counts matched baseline and the duration check passed. **Not independently confirmed:** no noticeable slowdown, and no red errors. Both are PASS conditions. |

### 4.1 Totals

Guide tests (62):

| PASS | PASS† (needs R-2 confirmation) | FAIL | PARTIAL | BLOCKED | NOT RUN (optional) | NOT VERIFIED |
|---|---|---|---|---|---|---|
| 7 | 32 | 1 | 5 | 1 | 2 | 14 (13 required, 1 optional) |

On the template's four-mark line: **PASS 7 (+32 conditional), FAIL 1, BLOCKED 1, NOT RUN 2.** Another 5 PARTIAL and 14 NOT VERIFIED results do not fit those four marks; none of them is a pass.

- **PASS:** P-1, P-2, P-5, T-1, C-1, C-2, C-4.
- **Added check X-1:** PASS.
- **FAIL:** M1-2.
- **BLOCKED:** L-1.
- **PARTIAL:** U-3, U-4, MOB-6, MOB-7, C-5.
- **NOT RUN:** MOB-8, MOB-9.
- **NOT VERIFIED:** P-3, P-4 (optional), T-2, M1-1, U-7, MOB-1 to MOB-5, N-6, L-2, L-3, L-4.

## 5. Failure reports

```text
Test ID: M1-2 (failure F-1)
Session / mode: Session 1, Play, one player. Emulator device and orientation: not supplied (desktop expected for Session 1).
Steps I did (exact): not supplied in detail; guide M1-2 steps (camera input, then Appendix C.3, then C.4) assumed.
Expected (from the guide):
  [QA] CAMERA character=nil type=Enum.CameraType.Scriptable focus=0, 54, 0 position=0, 56, 18 fov=50
  [QA] CAMERA after reset type=Enum.CameraType.Scriptable focus=0, 54, 0
What happened instead: Camera.Focus.Position = (0, 53.7913703918457, -1.8776741027832031).
  The owner reports that other camera behaviour appeared functional.
  Not supplied: the full C.3 and C.4 lines (character, type, position, fov) and which of the two printed this focus.
Output lines: not supplied.
_G.QA.summary() line: not relevant.
Screenshot file names: not supplied.
Reproduced: not supplied.
P-3 parity line at the time: not supplied (P-5 at the end: 24/24 PASS, see R-1).
Notes: recorded as a strict FAIL, as instructed. No script was edited.
```

**Reviewer analysis of F-1.** This is analysis, not a new observation, and no fix was made.
- **What the code sets.** `ArenaView.luau:418-423` sets `CameraType = Scriptable`, `CFrame = CFrame.lookAt((0, 56, 18), (0, 54, 0))` and then `Focus = CFrame.new(0, 54, 0)`. The comment at lines 421-422 states that Scriptable cameras never update `Focus` on their own.
- **Where the observed point lies.** It is the point **exactly 20 studs** from the camera position along that look direction. The computed point is `(0, 53.79136948, -1.87767469)`; the observed value matches to float32 precision.
- **What this suggests:** the camera's position and aim are as designed, and `Focus` was later overwritten by something other than `ArenaView.luau:423`. For example, the engine or a default camera script may have placed it 20 studs ahead of the camera.
- **What it does not establish:** whether the guide's strict expectation, or the code comment's assumption about Scriptable cameras, is wrong for this Studio build.
- **Impact.** `Camera.Focus` steers engine detail and streaming priorities, not what the player sees; the displacement is about 2.2 studs. Severity and disposition are for the reviewer.
- **Evidence needed:** the C.3 and C.4 lines verbatim, and whether the value appears before and after C.4.

## 6. Open release-blocking questions

The overall result cannot be accepted until each of these is answered.

| # | Question | Why it blocks |
|---|---|---|
| R-1 | Which expected values did the P-5 checker use for `BigNum` and `BigNumTests`? Supply the checker text or the full `[Parity]` Output. | An unmodified Appendix B would report 22/24 and FAIL with the candidate installed. The 24/24 is meaningful only if it was checked against the candidate values in section 2.1. |
| R-2 | Confirm the category-to-test mapping in 3.2 for the 32 PASS† tests. Confirm that their non-numerical conditions also held: no red errors, no unlisted warnings, and the visual checks. Supply the `QA_*.txt` Output files (guide 12.4). | Under the guide (0.3), PASS needs every condition observed, and any red line is a FAIL. |
| R-3 | Disposition of M1-2 (F-1): a game defect (Focus overwritten after it is set), or a guide expectation that does not hold on this build? Repeat C.3 and C.4 and supply the lines. | It is a recorded FAIL against the guide; the reviewer decides severity. |
| R-4 | Repeat L-1 with unambiguous player identities: Appendix D.5/D.6, or the bridge's `capture`/`afterLeave`. | Per-player server cleanup on leave is a reliability and isolation requirement, and it is currently unverified. |
| R-5 | Run or account for the required tests with no result: P-3, T-2, M1-1, U-7, MOB-1 to MOB-5, N-6, L-2, L-3, L-4. | Required tests; NOT RUN is allowed only for optional ones |
| R-6 | Is the incomplete U-4 (natural progression to level 25), with U-3, acceptable given that U-5 verified the exact transition with granted Gold? | Decision for the reviewer and producer (bounded precision contract, decision 1) |
| R-7 | Complete MOB-6 and MOB-7. MOB-1 to MOB-5 have no reported result. | Mobile is a primary platform. MOB-5 is the safe-area inset risk from the audit. |
| R-8 | C-5: confirm no slowdown and no red errors over the long session (Output file). | These are C-5 PASS conditions |
| R-9 | The tested code is the **DEFECT-001B candidate**, not the approved release. Still needed before adoption: the independent Codex review of the candidate (`review/DEFECT-001B_CODEX_HANDOFF.md`); Luau compile/analysis or Studio Script Analysis results (not run; `DEFECT-001B_REPORT.md` §8); and a reviewed revision of the pin, manifest round 4, the parity tables, the installer payload and the test count (67). | These QA results apply only to `9a988c9`'s `src/` |
| R-10 | Supply the missing setup facts: tester, dates, Studio version, OS, install method, emulator devices. Also the screenshots for every FAIL. | Traceability required by guide 12.4 |
| R-11 | Confirm the H-check outcome. Was the EmberboundQA bridge used because the helpers were "not connected"? | Shows how the helper-based results (U-5, U-6, A-5, N-2 to N-6, C-3) reached the live game |

## 7. Observations (not failures)

- The QA place is `Emberbound_M2_DEFECT001_QA.rbxl`. Keeping a separate candidate copy agrees with `DEFECT-001B_REPORT.md` §9: the original QA place was not to be changed.
- The temporary QA bridge was deleted before P-5, as guide 0.2 and P-5 require. `EmptyTests` (T-2) is not mentioned; P-5's `extra scripts: 0` shows that no extra script remained at the end.
- C-3 appears to have started at stage 16, carried over from C-1/C-2 in the same Play session (section 3.3). This is allowed by the guide.
- No memory readings were supplied for C-3; they are optional.
- The Milestone 1 report (`QA_REPORT.md`) is a user-reported summary with no logs. This Milestone 2 report has the same provenance limit.

## 8. For the independent (Codex) review

Review this report read-only against `M2_STUDIO_REGRESSION_GUIDE.md` (as on PR #1 head `2b832d2`), this template, `review/DEFECT-001B_REPORT.md` and the code at `9a988c9`. In particular:
1. Check every mark against the guide's PASS/FAIL rules (0.3). Nothing should be credited beyond what section 2 and the notes state.
2. Check the deductions in 3.1 (P-5 values, the T-1 and T-2 adaptations) and 3.3 (the C-3/C-4 arithmetic) against the source.
3. Assess F-1 (M1-2) from `ArenaView.luau:415-440`, and say whether it is a code defect, a guide error or a Studio-dependent risk.
4. Decide which items in section 6 are release-blocking for PR #1 and for adopting the DEFECT-001B candidate.

Do not fabricate Studio output, do not merge, and do not mark Milestone 2 complete.
