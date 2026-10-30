# Repository rules for Emberbound Milestone 1

- Task is **read-only audit**: no edits, no refactors, no generated code, no commits, and no pushes unless the user explicitly requests a later implementation task.
- Prioritize defects with concrete runtime, exploit, correctness, or reliability impact. No stylistic churn, speculative issues, or unrequested Milestone 2 features.
- Roblox server is authoritative over stage, gold, enemy HP, tap damage, rate limits, and enemy death rewards. Requests from clients must not choose damage or rewards.
- Every player must have independent combat state. Each defeated enemy rewards exactly once. The client generates local enemy models and UI; the fixed camera must not rely on a spawned player character.
- Multiple damage sources (future hero DPS) should be able to use the central damage pipeline; assess extensibility without insisting on premature redesign.
- Audit all six Luau files and the declared Explorer hierarchy together. Inspect event ordering, `ClientReady` sync, error paths, cleanup, out-of-order responses, performance, and cross-platform input behavior.
- Distinguish **confirmed code defects**, **risks requiring Roblox Studio tests**, and **optional improvements**. Do not fabricate runtime tests, engine outputs, or official Roblox API verification.
- Cite every finding by exact file path, function, and line(s); give a minimal reproduction/trigger, impact, and least disruptive fix.
- Severity: Critical (exploitable loss/security or fundamentally broken), High (user-facing correctness/security blocker), Medium (important edge case), Low (nonblocking improvement). Use evidence-based severity.
- `QA_REPORT.md` contains user-reported passes; do not downgrade proven code defects solely because basic functionality passed.
