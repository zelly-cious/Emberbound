# Launch QA: deferred manual checks

Per the producer's instruction (7 Nov 2026), manual Roblox Studio and live-server checks are no longer run milestone by milestone. They are collected here and run once, in a single final QA pass, when the launch build is playable. The final consolidated checklist will be built from this list. Offline checks still run on every change (`review/m3/run_checks.py`).

## Already confirmed (not repeated)

| Area | Evidence |
|---|---|
| Milestone 1 | `QA_REPORT.md` (owner-reported) |
| Milestone 2 Round 4 | `review/M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md`: installer v1.2.0, parity 24/24, T-1 67/67 |
| M2.1 StatService items 1–4 at `9a3ad1e` | `review/m2.1/M2_1_STUDIO_QA_RESULTS.md`: producer-attested PASS, detailed evidence unrecorded |

## Deferred to final QA

| ID | Check | Added by |
|---|---|---|
| D-1 | TestRunner in Studio reports ALL PASSED with the final suite count (106 tests in 10 suites at `feature/m3-planning`), including the R2-1 parser and the profile tests | R2-1 fix, persistence slice |
| D-2 | Script Analysis: no errors in the new or changed scripts (`ProfileSchema`, `ProfileStore`, `PlayerDataService`, `PlayerSessionService`, `CurrencyService`, `CombatService`, `CombatRules`, `UpgradeService`, `BigNum`, the new Tests). The two known `CombatClient` warnings may remain. | persistence slice |
| D-3 | Unpublished place: Output shows "Studio without DataStore access: saves are kept in memory"; the game plays exactly as before | persistence slice |
| D-4 | Private published test place with Studio API access: Output shows "Studio is using the place's DataStore". Earn Gold, buy an upgrade, reach stage 3 or higher, then Stop and Play again: Gold, level, stage and tap damage are restored, and the enemy is at full HP | persistence slice |
| D-5 | Same place: play for more than 60 s, with no PlayerDataService warnings in Output (autosave) | persistence slice |
| D-6 | Live, after publishing: join, play, leave and rejoin; progress is kept | persistence slice |
| D-7 | Live: join from a second device on the same account. The second session loads the latest progress within about 30 s, with no "still open on another server" message after the first session closes | persistence slice |
| D-8 | Live: "Shut down all servers", then rejoin; progress is kept | persistence slice |
| D-9 | M2.1 QA bridge `EmberboundStatQA` removed from the release place before parity and publishing (kept in the separate QA place) | M2.1 item 5, pending the producer's confirmation |
