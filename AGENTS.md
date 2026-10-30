# Repository rules for the Emberbound Milestone 2 review

- Task is a **read-only audit** of Milestone 2 (Tap Upgrades, Economy & BigNum) at commit `024cd68838d6c34633a00e7eadcb320c251186f0`: no edits, no refactors, no generated code, no commits and no pushes unless the user explicitly requests a later implementation task.
- Start with `CODEX_REVIEW_HANDOFF.md`. Scope and exit criteria are in `M2_REQUIREMENTS.md`; architecture, contracts and checklists in `M2_REVIEW_GUIDE.md`; what was actually executed in `review/M2_CHECK_RESULTS.md`.
- Audit all 23 Luau files under `src/` and the declared Explorer hierarchy together. Diff against the Milestone 1 baseline with `git diff 730218a 024cd68 -- src`.
- Prioritize defects with concrete runtime, exploit, economy, correctness or reliability impact. No stylistic churn and no speculative issues.
- The server is authoritative over stage, Gold, enemy HP, tap damage, upgrade levels, prices, rate limits and rewards. Client requests must never choose damage, prices, amounts or outcomes.
- Gold must never go negative, never be charged twice for one level, and never be granted more than once per defeated enemy. Every player's state must stay independent.
- Do **not** implement or demand Milestone 3+ features (persistence, heroes, gacha, Gems, Crowns, equipment, trading) or the approved Milestone 2.1 StatService (`DECISIONS.md`). Assess whether the code can grow into them; flag only concrete blockers.
- Distinguish **confirmed code defects**, **risks requiring Roblox Studio tests**, and **optional improvements**. Do not fabricate runtime tests, engine output or official Roblox API verification.
- Cite every finding by exact file path, function and line(s); give a minimal trigger, impact and least disruptive fix.
- Severity: Critical (exploitable loss/duplication or fundamentally broken), High (user-facing correctness or security blocker), Medium (important edge case), Low (non-blocking). Use evidence-based severity.
- The offline harness in `review/` is review tooling, not game code. Its results come from the Luau CLI with a fake engine, not from Roblox Studio. `QA_REPORT.md` contains user-reported **Milestone 1** results only; there is no Milestone 2 Studio QA.
