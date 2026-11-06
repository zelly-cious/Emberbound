# Milestone 2 round 4 — BigNum DEFECT-001/001B adoption into the release package

| | |
|---|---|
| **Status** | **Adoption revision prepared for independent review. Not approved, not merged.** PR #1 is not merged, Milestone 2 is not marked complete, and Milestone 2.1 is not started. |
| Adopted source | `9a988c9254e07ac50dcf32fe4b55ba975613390d` (branch `candidate/m2-defect-001-ftz-subnormal`), unchanged |
| Branch | `feature/m2-bignum-adoption-round4`: the reviewed candidate `9a988c9`, merged with the reviewed installer branch (`feature/m2-tools-001-installer` at `bceecb6`), plus the round 4 adoption commits. Both inputs share base `2b832d2` (PR #1 head) and change disjoint files. |
| Authority | Producer direction to adopt the candidate. Codex's independent read-only reviews: candidate **PASS WITH RISKS**, and the historical QA evidence waiver **ACCEPT WITH RISKS**. The QA report is at QA branch commit `ae861bd` (R-9 there lists the work this revision does). |
| Results log | `review/M2_BIGNUM_ADOPTION_ROUND4_RESULTS.txt` (first review, tree `28861fc`); `review/M2_BIGNUM_ADOPTION_ADOPT_FIXES_RESULTS.txt` (after the ADOPT-01–03 corrections; section 5) |

## 1. What changed

**No gameplay code changed.** `src/` on this branch is byte-identical to `9a988c9` (checked). The only `src/` differences from the round 3 release `e9d878d` are the two reviewed candidate files:

| File | Round 3 (`e9d878d`) SHA-256 | Round 4 (`9a988c9`) SHA-256 | Round 4 bytes / lines / Adler-32 |
|---|---|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | `c7474136…0244a` | `e337573da95f481a022ed0e6f31dfefdacb0755921214cdb89cdb53d8e08f674` | 16287 / 532 / 3188390913 |
| `src/ServerScriptService/Tests/BigNumTests.luau` | `0c13e484…4d97a` | `8d28a9bf19fa29cf3ccf53dc5dd066f2777ef85548a35911b19f1feab4113b51` | 23275 / 578 / 1646015937 |

Release-package files changed:

| Area | File | Change |
|---|---|---|
| Source manifest | `SOURCE_HASHES.txt` | New **round 4 (current)** for `src/` at `9a988c9`. Round 3 relabelled *historical* with its 24 hash lines unchanged, the same precedent as round 2 → round 3. Rounds 1–2 untouched. |
| Source pin and parity | `M2_STUDIO_REGRESSION_GUIDE.md` | "Code under test" pins `9a988c9` (round 4), with a new "Guide revision" row. Browse, ZIP and all 24 Appendix A links point to `9a988c9`. Appendix A rows 1 and 12 and the Appendix B checker rows for `BigNum` and `BigNumTests` hold the round 4 values. The status note now points to the Studio QA run. |
| Unit-test count | same guide | T-1: 67 tests in 7 suites (BigNumTests 31). T-2 expects `1 FAILED, 67 passed`, and the FAIL example is `1 FAILED, 66 passed`. The allowed-messages table says `ALL PASSED (67 tests)`. |
| Results template | `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md` | "Code tested" pins `9a988c9` (round 4). T-1 row reads 67 tests. |
| Other current docs | `M2_REVIEW_GUIDE.md` §9, `M2_REQUIREMENTS.md`, `README.md`, `CODEX_REVIEW_HANDOFF.md` | Round 4 and 67 tests. The requirements header records the adoption. `CODEX_REVIEW_HANDOFF.md` gains a pointer to the round 4 handoff; its older sections are unchanged. |
| Installer payload | `tools/m2/InstallM2.lua`, `tools/m2/INSTALLER_MANIFEST.txt` | Regenerated as **v1.2.0**: 240,675 bytes, SHA-256 `b12fa7023f25a93d2e2a80aef0042c0cf962d81a7aef84dd4ca1fd06873623d4`. Only the header comment, `INSTALLER_VERSION`, `FROZEN_COMMIT` and the embedded FILES[1] (`BigNum`) and FILES[12] (`BigNumTests`) differ from v1.1.0. **The installer logic is byte-identical** (diffed). |
| Installer generator | `tools/m2/generate_installer.py`, `InstallM2.template.lua` | Source pin `9a988c9`, manifest round 4, version 1.2.0. Round 4 is recorded *after* the source commit, so the manifest is read from `HEAD`. The generator now requires the source commit to be an ancestor of `HEAD`, and the round 4 heading to name it and be marked current. The template header comment names round 4. |
| Installer tests | `tools/m2/tests/run_tests.py`, `installer_tests.lua` | Source identity against round 4. Repository-scope checks re-scoped for the adoption: `src/` unchanged from `9a988c9`, rounds 1–3 hash lines preserved, round 4 the only current round, only release-package files changed. One damage test hard-coded the frozen BigNum Adler-32; it now reads FILES[1]'s value, making the same mutation with any payload. |
| Installer docs | `tools/m2/INSTALL_INSTRUCTIONS.md`, `tools/m2/README.md` | v1.2.0, the new SHA-256 and size. The download link is pinned to `d2e638188efaa2f8fdcd59a9c4b2c35e1763a396`, which holds the v1.2.0 file. The Appendix B link is pinned to the round 4 guide at `5bcc94026dd21d6f261047f2baaa5f62ac73298f`. Tests expect 67. The current Studio evidence is in §2.3. |
| Consistency checker (new) | `tools/m2/tests/check_release_package.py` | Cross-checks every pin and value above. It also runs the guide's **own Appendix B checker text** offline (section 2). |
| Historical evidence | `review/M2_STUDIO_QA_RESULTS.md` | Imported **byte-identical** from QA commit `ae861bd` (blob `f7024af`) |
| Historical evidence | `review/DEFECT-001B_REPORT.md` | One dated status row added: Studio QA, Codex native results superseding its FTZ probe count and its "native checks not run", and the adoption. Its original text is unchanged. |

Kept unchanged as history: rounds 1–3 of the manifest; the frozen commit `e9d878d`; PR #1 head `2b832d2` and its round 3 guide; the candidate branch `9a988c9`; the installer branch `bceecb6`; the QA branch `ae861bd`; `review/DEFECT-001_REPORT.md`; the round 1/2 review records; `DECISIONS.md`; `AGENTS.md`; the Slime art.

## 2. Verification

### 2.1 Executed here (offline: Linux, Python 3, Lua 5.1; not Roblox Studio)

| # | Check | Result |
|---|---|---|
| V-1 | `git diff 9a988c9 -- src` on this branch (gameplay code unchanged) | **empty** |
| V-2 | `python3 tools/m2/generate_installer.py --check`: deterministic regeneration from the source commit blobs, verified against round 4 and Appendices A/B | **installer and manifest match** |
| V-3 | `python3 tools/m2/tests/run_tests.py`: source identity; determinism; an independent second decoder; static safety scan; `luac5.1 -p`; 69 Lua behaviour tests against the fake engine; offline replica of the Appendix B logic on the installed mock place; adoption scope | **19/19 checks; 69/69 behaviour tests; replica 24/24, 6/6, 0 extra** |
| V-4 | `python3 tools/m2/tests/check_release_package.py`: source integrity, manifest rounds, the guide's pins, links, Appendix A/B and T-1 against the shipped TestRunner's offline output, installer manifest and docs, other docs, imported QA report, DEFECT reports | **32/32** |
| V-5 | Inside V-4: **the guide's real Appendix B checker text**, translated to Lua 5.1 and run against a fake place built from the 24 round 4 sources | **`scripts matching: 24 / 24, remotes: 6 / 6, extra scripts: 0` / `RESULT: PASS`** |
| V-6 | Negative controls in V-4: the round 4 checker against the round 3 `BigNum`/`BigNumTests`; the round 3 checker (`2b832d2`) against the round 4 sources | **both 22 / 24, `RESULT: FAIL`**, each with exactly 2 `content differs`. The second reproduces the owner's initial P-3 22/24. |
| V-7 | Checker sensitivity: one changed value each in Appendix B, manifest round 4 and the T-1 block of `INSTALL_INSTRUCTIONS.md` (throwaway working-tree edits, restored from git) | **each detected** (FAIL lines in the results log) |
| V-8 | Unit tests through the shipped `TestRunner` (`review/ftz-harness/run_matrix.py`, translated harness) in gradual, FTZ, FTZ + modeled Studio formatter, and formatter-only modes | **67/67 in each mode**; per-suite lines identical to the guide's T-1 block |
| V-9 | Historical review probes (75), same harness, same four modes | **75/75 in each mode in this translated harness.** Codex's **native** Luau 0.745 run reported **75/75 gradual, 74/75 FTZ** (an outdated differential expectation in the historical probe). The native figure is authoritative; the harness figure is not a substitute. |

### 2.2 Earlier evidence for the same source, not re-executed here

| Evidence | Source |
|---|---|
| Roblox Studio: 67/67 unit tests; T-2 `1 FAILED, 67 passed`; final P-5 `24 / 24, 6 / 6, 0` `RESULT: PASS` with a checker adapted to exactly the round 4 values for the two files; gameplay, abuse, multiplayer, lag, mobile, large-number and cleanup tests; Script Analysis 0 Errors / 6 Warnings (none in `BigNum` or `BigNumTests`) | `review/M2_STUDIO_QA_RESULTS.md` (QA commit `ae861bd`; historical evidence accepted with risks under Codex's waiver) |
| Native Luau 0.745 compile of both changed files; strict analysis (old and new solvers); test-body analysis; offline 67/67 in four modes | Codex's independent read-only review, recorded in QA report §2.2 |

### 2.3 Round 4 release package in Roblox Studio

The project owner used installer **v1.2.0** in Studio and reported **24 / 24 scripts, 6 / 6 remotes, 0 extra scripts** after reopening the installed place, plus **67 / 67 unit tests**. The [release QA addendum](M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md) records those results and the initial HUD sync Output. It also records the accepted camera Focus exception and the owner's offline checklist attestation separately.

The exact parity checker text and separate observations for installer check mode, the `PlaceId` guard (M2-R01) and undo behavior were unrecorded for this run.

## 3. Remaining risks

| # | Risk | Severity / status |
|---|---|---|
| K-1 | BigNum is **PASS WITH RISKS** (Codex). Under FTZ, native small-value fast paths can still flush subnormal results to 0, and there is a ±1 subnormal step near the normal boundary. Correctness depends on Studio's `tostring`/`tonumber` for subnormals, and DAZ/ARM hosts are unsupported (tests fail loudly). Gameplay values are 0 or at least 1. | Accepted with risks; see `review/DEFECT-001B_REPORT.md` §10 |
| K-2 | The owner verified installation and post-reopen parity in Studio (§2.3). Check mode, the `PlaceId` guard and undo behavior have no separate Studio observations on record. | Residual Studio coverage gap |
| K-3 | Generator trust model: round 4 is read from `HEAD`, not from the source commit. This is mitigated by the ancestor and heading checks, the requirement that the 24 SHA-256 values match the source commit's blobs, and the package checks on rounds 1–3. | Design change; needs reviewer acceptance |
| K-4 | The historical FTZ probe has an outdated differential expectation. The native run gives 74/75; the translated harness gives 75/75. The probe file `review/offline-harness/probes.luau` was **not** changed (historical tooling). | Known; tooling follow-up if desired |
| K-5 | M1-2 camera Focus: strict FAIL, producer-accepted Low/nonblocking. `CombatClient` W-5/W-6 `Players.LocalPlayer` optionality warnings: Low/nonblocking (Codex). | Accepted; unchanged by this revision |
| K-6 | Historical QA evidence rests on the owner's attestation (Codex waiver, ACCEPT WITH RISKS). The imported QA report must stay byte-identical to `ae861bd`; V-4 checks this. | Accepted with risks |
| K-7 | Integration: this branch merges the installer branch into the candidate. Landing it means updating PR #1 to this branch (or merging it into PR #1's branch) after review. Nothing was merged. | Decision for the producer and reviewer |
| K-8 | `AGENTS.md` still describes the round 2 review task, and `DECISIONS.md` has no entry recording this adoption. Neither was changed, to avoid inventing decision text. | Producer may record the adoption decision |
| K-9 | The offline checks use translated Luau on Lua 5.1 and a fake engine. They prove package consistency and parity *logic*, not Studio behaviour. | Inherent |

## 4. Reviewer instructions

- First review: `review/M2_BIGNUM_ADOPTION_CODEX_HANDOFF.md`.
- Final review after the corrections: `review/M2_BIGNUM_ADOPTION_FINAL_CODEX_HANDOFF.md`.

## 5. Corrections after Codex's review of `a9326f1` (verdict PASS WITH RISKS)

Codex found three Low-severity issues. All are fixed. **No gameplay source, BigNum implementation, installer payload or historical QA record changed**: `src/` still equals `9a988c9`, and `InstallM2.lua` still has SHA-256 `b12fa7023f25a93d2e2a80aef0042c0cf962d81a7aef84dd4ca1fd06873623d4`.

| ID | Finding | Fix | Regression evidence |
|---|---|---|---|
| ADOPT-01 | `M2_REVIEW_GUIDE.md` inventory row (line 69) still said 61 tests | The row now says 67, with the history: 48 in round 1, 61 after `e4b0108`, 67 after the round 4 adoption | New package check: no current document (the guides, requirements, READMEs, template and install instructions) claims 61 tests outside an explicitly historical note. End-to-end test: restoring the old row makes `check_release_package.py` exit 1, naming `M2_REVIEW_GUIDE.md:69`. |
| ADOPT-02 | `check_release_package.py` ignored Lua child-process exit codes, so a Lua error after a verdict could pass | Added `run_lua` / `evaluate_parity` / `run_unit_tests` / `evaluate_unit`.<br>• A positive parity run needs exit 0 **and** exactly one PASS verdict with 24/6/0.<br>• A negative control needs exit 0 (it ran to completion) **and** the FAIL verdict with 22/6/0 and exactly 2 `content differs` lines.<br>• The unit-test run goes through `run_matrix.run` (which returns the Lua exit code) and needs exit 0 plus the exact 8 T-1 lines. | `tests/test_verification_tools.py`: real `lua5.1` runs with an error injected **after** the PASS verdict, after the FAIL verdict, and after `ALL PASSED (67 tests)`, plus a checker that does not compile. Each is rejected; the unmodified controls are accepted. The `a9326f1` checker, given the same injected errors, reports 32/32 (false success reproduced). |
| ADOPT-03 | Manifest headings were not fully validated, so a duplicate or extra current round could slip through | New `generate_installer.manifest_heading_errors`, used by `run_tests.py`, `check_release_package.py` and the generator. It requires exactly rounds 4, 3, 2, 1 (24/24/24/23 files) and round 4 as the only current round. It rejects duplicate or unexpected headings and hash-line counts that disagree with a heading. The generator's output is unchanged. | `tests/test_verification_tools.py`: a fake `Round 5 (current)`, a duplicate Round 3, an unexpected `## Notes`, Round 3 marked current, Round 4 marked historical and a missing hash line are each rejected. End to end, both `check_release_package.py` and `run_tests.py` exit 1 on a working tree with a fake `Round 5 (current)`, and the file is restored byte for byte. The `a9326f1` checkers report 32/32 and 19/19 on that tree (false success reproduced). |

Post-correction results (raw output in `review/M2_BIGNUM_ADOPTION_ADOPT_FIXES_RESULTS.txt`):

| Check | Result |
|---|---|
| Generator `--check` | installer and manifest match; SHA-256 `b12fa702…3623d4` unchanged |
| `run_tests.py` | 19/19 (69/69 Lua behaviour tests) |
| `check_release_package.py` | 34/34 (adds the heading and stale-count checks). Appendix B text: 24/24 PASS (Lua exit 0). Both negative controls: 22/24 FAIL (Lua exit 0). |
| `test_verification_tools.py` | 20/20 |
| Unit tests and harness probes, four floating-point modes | 67/67 and 75/75 per mode (translated harness; native FTZ probe figure remains Codex's 74/75) |
