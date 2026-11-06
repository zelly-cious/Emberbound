# CODEX TASK — EMBERBOUND MILESTONE 2 RE-REVIEW (ROUND 2)

> **Superseding note (1 Nov 2026) — historical prompt, kept unchanged below.** This round 2 re-review has been completed: Codex returned **CONDITIONAL PASS** (source: Codex's round 2 re-review of PR head `09be466`, as summarized in the producer's "Milestone 2 Final Review Decisions" message of 1 Nov 2026. The full Codex report text is not in this repository). Three verification items below were worded more broadly than the approved contract and must not be read as guarantees:
> - Item 1 ("results below 2^53 are exact"): exact only when the operands are exact and the larger is below 10^23. Cancellation after operations involving large approximate values can be approximate even below 2^53.
> - Item 2 ("returns nil … for every … overflowing input"): `parse` never raises, but limitation **R2-1** means a long-mantissa decimal that is mathematically out of range can round into range and be accepted (e.g. `"1"` + 23 zeros + `"e9007199254740969"`).
> - Item 4 ("subnormal inputs … in every BigNum operation"): covered for `add`, `sub`, `mul`, `div`, comparisons and the text round trip; `ratio` can underflow or overflow prematurely (limitation **R2-2**).
>
> The current contract is the bounded precision contract in `M2_REQUIREMENTS.md`; R2-1 and R2-2 are conditionally deferred for M2 only (`DECISIONS.md` decisions 8–10).


Act as the same independent senior Roblox/Luau engineer and game-security reviewer who audited Milestone 2. Claude produced the corrections. You are the reviewer, not the implementer.

Review PR [zelly-cious/Emberbound#1](https://github.com/zelly-cious/Emberbound/pull/1), corrections commit `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf`, against the audited commit `024cd68838d6c34633a00e7eadcb320c251186f0`.

Read `CODEX_REVIEW_HANDOFF.md` (round 2 section), `review/M2_CORRECTIONS_REPORT.md`, your round 1 audit in `review/audits/Emberbound_M2_Independent_Audit.pdf`, `AGENTS.md`, and the full diff `git diff 024cd68 e4b0108 -- src`. Read the changed files in full: `src/ReplicatedStorage/Shared/BigNum.luau`, `src/ServerScriptService/Tests/TestKit.luau`, `src/ServerScriptService/Tests/TestRunner.luau`, and the new or changed tests. Treat the offline-harness results as Luau-CLI results with a fake engine, not Roblox Studio results.

**Read-only. Do not edit code, create files, install dependencies, commit or push.** Do not add Milestone 2.1+ features.

Verify at least:
1. **F1** — `BigNum.sub`: results below 2^53 are exact; the 10^23 bound and the claim that `toNumber` is one correctly rounded conversion there; no overflow, NaN or negative result; canonical form preserved; Wallet conservation.
2. **F2** — `BigNum.parse` returns nil (never raises) for every malformed, unrepresentable or overflowing input, while canonical text still round-trips; arithmetic overflow still raises.
3. **F3** — a test module that fails to load or returns a non-suite, or a run with no tests, can never print `ALL PASSED`; the offline harness cannot be fooled either.
4. **F4** — subnormal inputs (down to 5e-324) in every BigNum operation; ordinary values unchanged.
5. **F5** — strict analysis is clean under both type solvers; judge the tradeoff of keeping the exported type writable instead of `read` fields.
6. **F6** — `expectNear` rejects NaN and invalid tolerances without breaking valid comparisons.
7. **No regressions or new defects** in BigNum, TestKit or TestRunner, and **no changes** anywhere else under `src/` (M1 formulas, starting tap damage, upgrade prices, Gold spending, remotes, payloads, rate limiting, replay protection, ClientReady sync, `ApplyDamage`, upgrade UI, per-player isolation).
8. Whether the two reported observations (`add` precision above 2^53; `sub` cancellation above 10^23) need action before approval.

For each finding: severity (Critical / High / Medium / Low), exact file and line(s), what is wrong and why, trigger, impact, minimal fix, and whether it is confirmed by source or needs a Studio test.

Report format:

## Executive verdict
PASS / CONDITIONAL PASS / FAIL with a 2–4 sentence rationale. A PASS is not a claim that the game was run.

## Status of F1–F6
One row per finding: resolved / partially resolved / unresolved, with evidence.

## New findings
Sorted by severity; none is an acceptable result if justified.

## Studio regression tests still required
## Readiness for merge and Milestone 2.1

Do not modify files. Finish after writing the report.
