# EMBERBOUND — MILESTONE 2 CODEX REVIEW HANDOFF

**Purpose:** independent, read-only audit of the Claude-generated Milestone 2 implementation (Tap Upgrades, Economy & BigNum) before Milestone 2.1 and Milestone 3.

- Branch: `feature/m2-tap-upgrades-bignum`
- Implementation commit: `024cd68838d6c34633a00e7eadcb320c251186f0`
- Milestone 1 baseline: `730218a` (sync-retry and `Camera.Focus` fixes)

This is source only, not a Roblox `.rbxl` place file. The client builds the camera, arena, slime, HUD and upgrade panel at runtime. `src/` mirrors the Roblox Studio Explorer placement; script classes and the six RemoteEvents are listed in `M2_REVIEW_GUIDE.md` section 1. No DataStore persistence exists yet.

## What to read, in order

1. `CODEX_REVIEW_HANDOFF.md` — one-page entry point: commit, scope, results, risks, review focus.
2. `AGENTS.md` — read-only reviewer rules.
3. `M2_REQUIREMENTS.md` — frozen scope, exit criteria and known gaps.
4. `M2_REVIEW_GUIDE.md` — hierarchy, scripts, architecture, BigNum, Gold flow, formulas, remote contracts, security and Studio checklists, limitations.
5. `review/M2_CHECK_RESULTS.md` — the static checks and automated tests that were actually executed (no Roblox Studio).
6. All 23 `.luau` files under `src/`.
7. `REVIEW_PROMPT.md` — one-shot prompt and report format.

Background: `M1_REQUIREMENTS.md` and `QA_REPORT.md` (Milestone 1 contract and user-reported M1 QA), `DECISIONS.md` (recorded future decisions, none affecting M2 code).

## Re-running the offline checks

```bash
review/offline-harness/run.sh unit   path/to/luau     # the shipped 48 tests, via the real TestRunner
review/offline-harness/run.sh probes path/to/luau     # 54 extra review probes
```

The Luau CLI comes from the [luau-lang/luau releases](https://github.com/luau-lang/luau/releases). The harness fakes a minimal Roblox engine; its results are not Studio results.

## After the audit

Send the report back, confirm the high-priority findings, apply only accepted fixes, and repeat the relevant Roblox Studio tests (`M2_REVIEW_GUIDE.md` section 9) before approving Milestone 2. Do not start Milestone 2.1 or Milestone 3 just because an AI says PASS.
