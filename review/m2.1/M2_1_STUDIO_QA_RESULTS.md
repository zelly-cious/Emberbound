# Emberbound Milestone 2.1 — Roblox Studio QA results (StatService, draft PR #3)

| | |
|---|---|
| **Code tested** | `feature/m2.1-statservice` at `9a3ad1e1e856a12dc240cf9c3d3ac4e5428c85ea`. Its `src/` is identical to `c4fa386`. That is the merged M2 Round 4 `main` (`2279623`), plus StatRules, StatService, StatRulesTests and the UpgradeService, PlayerSessionService and GameConfig changes. |
| **Status** | **Items 1–4: PASS — producer-attested; detailed evidence unrecorded.** Item 5 (bridge cleanup): **PENDING**, awaiting the producer's confirmation of the required action (section 3). Not merged. Release packaging (section 4) is still to do. |
| **Tester** | Project owner, in Roblox Studio |
| **Date, Studio version, OS, install method, QA place name** | Unrecorded |
| **Provenance** | The owner reports that they completed checks 1–4 successfully in Roblox Studio, earlier and outside this session. **No Output logs, screenshots, individual results or measurements were supplied; they are unrecorded.** For this QA cycle the producer accepted their own attestation and waived further requests for logs, screenshots, individual results and repeated testing. This record states that attestation; it does not claim that the missing evidence exists. Any independent reviewer can weigh it as producer attestation. |

## 1. Results

These are the Studio checks listed in PR #3. The numbering follows the owner's checklist; PR #3's "Session lifecycle" item is part of item 4 here.

| # | Check (PR #3) | Result | Notes |
|---|---|---|---|
| 1 | **Required:** a ×2 modifier survives a purchase. Uses the `EmberboundStatQA` bridge: buy to level 2 (2), `x2` gives 4, buy level 3 gives **6, not 3**, `remove` gives 3. | **PASS — producer-attested** | The bridge outputs, HUD values and hit popups are unrecorded. |
| 2 | T-1: `[Tests] ALL PASSED (82 tests)`, with `StatRulesTests: 15 passed, 0 failed` | **PASS — producer-attested** | The eight `[Tests]` lines are unrecorded. |
| 3 | Script Analysis: no new diagnostics in the six M2.1 scripts (StatRules, StatService, StatRulesTests, UpgradeService, PlayerSessionService, GameConfig) | **PASS — producer-attested** | Error and warning counts are unrecorded. |
| 4 | Gameplay as in M2: M1-3/M1-4, U-2, U-5 (level 24 → 25: 75 damage), U-6, N-2, N-3. Session lifecycle: L-1 (StatService cleanup on leave), L-2, B-1/B-2 (isolation). | **PASS — producer-attested** | Individual results per test are unrecorded. |
| 5 | Cleanup of the temporary `EmberboundStatQA` bridge | **PENDING** | The owner prefers to keep the bridge for future testing; section 3 sets out what is allowed where. |
| — | Optional: the overflow path through the bridge | Not recorded | Optional. Covered offline only (section 2). |

## 2. Offline evidence for the same code (not Roblox Studio)

`python3 review/m2.1/run_checks.py` at `9a3ad1e`: **14 / 14**. This runs Lua 5.1 with the translated harness and a fake engine.
- **Unit tests:** 82/82 in 8 suites, in both floating-point modes.
- **Historical probes:** 75/75.
- **StatService integration probes:** 43/43. They include the flat `9e9007199254740991` then ×2 regression, the refused purchase, the fault-injected refund, and the bridge's required check run against the live StatService.
- **Control on the previous head:** the same probes fail 10 checks on `2771db1`.
- **Client traffic:** byte-identical to `main` (161 messages).
- **Code checks:** no yielding calls; all StatRules mutation controls detected.

The producer independently reviewed `9a3ad1e` and confirmed the failure-path fix. These offline results support the Studio attestation but do not replace it.

## 3. The `EmberboundStatQA` bridge: where it may stay

The reusable source is kept at `review/m2.1/EmberboundStatQA.server.luau`. It is review tooling and never part of `src/`.

| Place | Can the bridge stay? | Why |
|---|---|---|
| **Separate QA place** | **Yes, disabled** (untick `Enabled`; tick it again before Play to use it) | A disabled Script does not run. Even when enabled, it does nothing outside Studio (`RunService:IsStudio()` guard), and its BindableFunction can only be called by server code; clients cannot reach it. |
| **Any place where a parity result is recorded** | **No — remove it first** | The round 4 Appendix B checker counts every extra script in the ten scanned services, and does not check `Enabled`. Checked offline: the M2 release sources pass 24/24 with 0 extra scripts, but adding a **disabled** `EmberboundStatQA` gives `extra scripts: 1` and `RESULT: FAIL`. |
| **Release place** | **No** | Release parity has to show exactly the reviewed scripts. The installer also refuses a place that already contains any script in those services, so release installs start from a fresh Baseplate anyway. |

**Pending producer decision (item 5):** keep the bridge disabled in the separate QA place, and confirm that it will be removed from the release place before release parity. Until then, cleanup stays **PENDING**.

## 4. Still to do (not covered by this record)

- **Producer confirmation of item 5** (section 3).
- **The M2.1 release package after approval:**
  - `SOURCE_HASHES.txt` round 5;
  - regression-guide Appendix A/B values and test count (82 tests, 8 suites);
  - installer payload.

  Release parity is then recorded against the round 5 values, in a place without the bridge.
- **The producer's merge approval for PR #3.** This record does not approve a merge or mark Milestone 2.1 complete.
