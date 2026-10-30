# CODEX TASK — EMBERBOUND MILESTONE 1 INDEPENDENT AUDIT

Act as an independent senior Roblox/Luau engineer and game-security reviewer. Claude produced the implementation. You are the reviewer, not the implementer.

Read `README.md`, `AGENTS.md`, `M1_REQUIREMENTS.md`, `QA_REPORT.md`, and **all six Luau files under `src/`**, including the cross-script call/event flow. `src/` mirrors their Roblox Explorer placement. Treat the QA report as **user-reported tests**, not as tests you executed.

**Read-only audit. Do not edit any code, create files, install dependencies, commit, or push.** Do not add Milestone 2 features. Do not recommend unnecessary architecture rewrites. Focus on realistic M1 correctness/security/performance defects, not style.

Review at least:
1. Roblox API validity and file placement (`ModuleScript`, `Script`, `LocalScript`), including no-avatar/fixed-camera configuration.
2. Server authority over damage, stage, gold, and HP; client request abuse and rate limiting.
3. Exactly-once enemy death and rewards under rapid taps, concurrent requests, and desynchronization.
4. Initial client sync, `ClientReady` retry, player joining/leaving, and event ordering.
5. Per-player state isolation in a two-client server.
6. Touch/mouse input duplication; click filtering over chat, HUD, safe-area insets, and future buttons.
7. Tween/event/particle cleanup and performance under sustained rapid combat on mobile.
8. Errors or corner cases in stage scaling, number formatting, and rendering.
9. Contract between `CombatClient`, `CombatService`, `GameConfig`, `ArenaView`, and `CombatHud`.
10. Future compatibility with a shared `ApplyDamage` pipeline for hero DPS; flag only concrete concerns.

For each finding, provide:
- Severity: Critical / High / Medium / Low
- Exact file path and line number(s)
- Finding: precisely what is wrong and why
- Trigger / reproduction steps
- Expected user or security impact
- Minimal recommended fix
- Status: confirmed by source vs requires a Roblox Studio test

Report in this format:

## Executive verdict
PASS / CONDITIONAL PASS / FAIL, with 2–4 sentence rationale. A PASS is not a claim that the game was run.

## Findings table
Sort by severity, and do not invent findings simply to fill sections. No findings is an acceptable result if justified.

## Suggested Roblox Studio regression tests
Concrete steps for any risks that cannot be verified statically.

## Non-blocking improvements
Only if justified; distinguish from bugs.

## Milestone 2 readiness
Explicitly state which issues, if any, must be fixed before implementing upgrades; give smallest fix sequence and which tests to rerun.

Do not modify files. Finish after writing the audit report.
