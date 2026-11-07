# Launch QA: deferred manual checks

The producer's roadmap review (7 Nov 2026) adds one focused private Studio persistence checkpoint after M3 and before M4. Broader manual gameplay/live checks are collected for a single integrated launch QA pass after M8. Record the focused checkpoint against its source revision and repeat its scenarios at launch when later changes affect persistence. Offline checks continue during development (`review/m3/run_checks.py`).

## Already confirmed (not repeated)

| Area | Evidence |
|---|---|
| Milestone 1 | `QA_REPORT.md` (owner-reported) |
| Milestone 2 Round 4 | `review/M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md`: installer v1.2.0, parity 24/24, T-1 67/67 |
| M2.1 StatService items 1–4 at `9a3ad1e` | `review/m2.1/M2_1_STUDIO_QA_RESULTS.md`: producer-attested PASS, detailed evidence unrecorded |

## Focused checkpoint after M3, before M4

| ID | Check | Status |
|---|---|---|
| M3-P1 | One private Studio persistence session on the real DataStore path. Verify saved Gold/stage/upgrade levels and derived damage after restart/rejoin, one autosave/release, and the delayed-save/rejoin and controlled failure paths through reviewed test hooks. Stored progress must remain protected. Record the exact source revision and a concise result. | Pending implementation fixes and execution |

## Final launch checks

| ID | Check | Added by |
|---|---|---|
| D-1 | TestRunner in Studio reports ALL PASSED with the final suite count (106 tests in 10 suites at `feature/m3-planning`), including the R2-1 parser and the profile tests | R2-1 fix, persistence slice |
| D-2 | Script Analysis: no errors in the new or changed scripts (`ProfileSchema`, `ProfileStore`, `PlayerDataService`, `PlayerSessionService`, `CurrencyService`, `CombatService`, `CombatRules`, `UpgradeService`, `BigNum`, the new Tests). The two known `CombatClient` warnings may remain. | persistence slice |
| D-3 | Unpublished place: Output shows "Studio without DataStore access: saves are kept in memory"; the game plays exactly as before | persistence slice |
| D-4 | M3-P1 first covers private Studio save/reload on the real DataStore path. On the final build, repeat if persistence changed: restored Gold, level, stage and derived damage match, with a fresh enemy at full HP. | M3-P1, then integration regression as needed |
| D-5 | M3-P1 first covers autosave/release. Repeat on the final build if those paths changed, checking the persisted state after the write. | M3-P1, then integration regression as needed |
| D-6 | Private published live-server test: join, play, leave and rejoin. Progress is kept. | persistence slice |
| D-7 | Controlled overlapping-session/rejoin test in the private experience. A new session loads only after safe ownership transfer or receives a retry outcome. Pending final writes retain their progress, and an old session cannot overwrite a new owner. | persistence slice |
| D-8 | Private published test servers: shut down the test servers, then rejoin. Progress is kept. | persistence slice |
| D-9 | M2.1 QA bridge `EmberboundStatQA` removed from the release place before parity and publishing. Keep its reusable source and the disabled helper in the separate QA place. | Scheduled for final release parity |
