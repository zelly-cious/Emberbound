# CODEX TASK — EMBERBOUND MILESTONE 2 INDEPENDENT AUDIT

Act as an independent senior Roblox/Luau engineer and game-security reviewer. Claude produced the implementation. You are the reviewer, not the implementer.

Review branch `feature/m2-tap-upgrades-bignum`, implementation commit `024cd68838d6c34633a00e7eadcb320c251186f0`. Read `CODEX_REVIEW_HANDOFF.md`, `AGENTS.md`, `M2_REQUIREMENTS.md`, `M2_REVIEW_GUIDE.md`, `review/M2_CHECK_RESULTS.md`, `DECISIONS.md`, and **all 23 Luau files under `src/`**, including the cross-script call and event flow. `src/` mirrors the Roblox Explorer placement; script classes are listed in `M2_REVIEW_GUIDE.md` section 1.

**Read-only audit. Do not edit code, create files, install dependencies, commit or push.** Do not add Milestone 3+ features or the Milestone 2.1 StatService. Do not recommend unnecessary rewrites. Focus on realistic correctness, security, economy and performance defects, not style. The offline harness results are Luau-CLI results with a fake engine, not Roblox Studio results.

Review at least:
1. Roblox API validity and file placement (`ModuleScript`, `Script`, `LocalScript`), remote creation, startup order and `require` cycles.
2. BigNum: representation invariants, regime boundary at 2^53, `add`/`sub`/`mul`/`div` precision, `parse`/`toString` round trip and rejection of hostile text, `format`, values beyond 10^308 and near exponent 2^53 − 1.
3. Upgrade economy: cost and value curves, level bounds, the purchase transaction in `UpgradeService.handlePurchaseRequest`, all-or-nothing spending, negative balances, duplicate charges, replayed / out-of-order / malformed request ids, rate limiting under rapid requests.
4. Gold acquisition: exactly-once defeat rewards under rapid taps; the single grant site; reason codes.
5. Server authority and argument validation on `RequestAttack`, `RequestUpgrade` and `ClientReady`.
6. Player lifecycle across PlayerSessionService, CurrencyService, CombatService and UpgradeService: join, early `ClientReady`, failed add, sync order, leave and cleanup.
7. Per-player isolation in a two-client server.
8. Client decoding of BigNum strings, malformed payload handling, upgrade panel input filtering (mouse/touch, insets), and the HUD.
9. Milestone 1 compatibility: stage table, starting values, tap cooldown, handshake and sync-retry behaviour, camera fix.
10. Future compatibility with persistence (M3), hero DPS through `ApplyDamage` (M4) and the approved StatService (M2.1); flag only concrete concerns.

For each finding, provide:
- Severity: Critical / High / Medium / Low
- Exact file path and line number(s)
- Finding: precisely what is wrong and why
- Trigger / reproduction steps
- Expected user, economy or security impact
- Minimal recommended fix
- Status: confirmed by source vs requires a Roblox Studio test

Report in this format:

## Executive verdict
PASS / CONDITIONAL PASS / FAIL, with a 2–4 sentence rationale. A PASS is not a claim that the game was run.

## Findings table
Sort by severity. Do not invent findings to fill sections; no findings is an acceptable result if justified.

## Suggested Roblox Studio regression tests
Concrete steps for risks that cannot be verified statically (start from `M2_REVIEW_GUIDE.md` section 9).

## Non-blocking improvements
Only if justified; keep them separate from bugs.

## Milestone 2.1 / 3 readiness
State which issues, if any, must be fixed before the StatService correction and before persistence; give the smallest fix sequence and which tests to rerun.

Do not modify files. Finish after writing the audit report.
