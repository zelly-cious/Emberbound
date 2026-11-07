# Emberbound

M2 is merged; M2.1 is draft PR #3. M3 saving/recovery foundations are implemented on `feature/m3-planning`, with review and the private Studio persistence checkpoint pending. Current planning: [ROADMAP.md](ROADMAP.md), [M3_PLAN.md](M3_PLAN.md). Current test build: [M3 Studio installer and instructions](tools/m3/README.md), pinned to `23785544f846817c5d722f69d5e81b11348df46f`. Offline evidence: [M3 results](review/m3/M3_IMPLEMENTATION_RESULTS.md).

The following Milestone 2 review handoff is historical. Its installer, manifest round and QA results describe the frozen M2 release. Earlier QA does not cover the M3 candidate.

## Historical Milestone 2 review handoff

**Purpose:** independent, read-only review of the Claude-generated Milestone 2 implementation (Tap Upgrades, Economy & BigNum) before Milestone 2.1 and Milestone 3. Round 1 (audit of `024cd68`) returned FAIL with findings F1–F6; round 2 is the re-review of their corrections.

- Pull request: [zelly-cious/Emberbound#1](https://github.com/zelly-cious/Emberbound/pull/1), branch `feature/m2-tap-upgrades-bignum`
- **Corrections commit (round 2):** `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf`
- Audited implementation (round 1): `024cd68838d6c34633a00e7eadcb320c251186f0`
- Milestone 1 baseline: `730218a` (sync-retry and `Camera.Focus` fixes)
- **Status (1 Nov 2026):** round 2 re-review complete (Codex: CONDITIONAL PASS). Producer decisions are recorded (bounded BigNum precision contract; R2-1 and R2-2 deferred for M2 only; see `DECISIONS.md` 8–10). Milestone 2 is **frozen** until Roblox Studio QA (`M2_STUDIO_REGRESSION_GUIDE.md`, results in `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`). PR #1 stays unmerged.

This is source only, not a Roblox `.rbxl` place file. The client builds the camera, arena, slime, HUD and upgrade panel at runtime. `src/` mirrors the Roblox Studio Explorer placement; script classes and the six RemoteEvents are listed in `M2_REVIEW_GUIDE.md` section 1. No DataStore persistence exists yet.

## What to read, in order

1. `CODEX_REVIEW_HANDOFF.md` — entry point; the round 2 section comes first.
2. `review/M2_CORRECTIONS_REPORT.md` — fixes for F1–F6, tradeoffs, tests and round 2 results.
3. `AGENTS.md` — read-only reviewer rules.
4. `M2_REQUIREMENTS.md` — frozen scope, exit criteria and known gaps.
5. `M2_REVIEW_GUIDE.md` — hierarchy, scripts, architecture, BigNum, Gold flow, formulas, remote contracts, security and Studio checklists, limitations.
6. All 24 `.luau` files under `src/`.
7. `REREVIEW_PROMPT.md` — round 2 prompt and report format (historical; see its superseding note).
8. `M2_STUDIO_REGRESSION_GUIDE.md` — the Roblox Studio QA procedure (next step), with `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`.

Historical round 1 evidence, unchanged: `review/audits/Emberbound_M2_Independent_Audit.pdf` (the Codex audit), `review/M2_CHECK_RESULTS.md` (round 1 checks), `REVIEW_PROMPT.md` (round 1 prompt).

Background: `M1_REQUIREMENTS.md` and `QA_REPORT.md` (Milestone 1 contract and user-reported M1 QA), `DECISIONS.md` (recorded producer decisions; none changes executable M2 code).

## Re-running the offline checks

```bash
review/offline-harness/run.sh unit   path/to/luau     # the shipped 67 tests, via the real TestRunner
review/offline-harness/run.sh probes path/to/luau     # 75 review probes (54 original + 21 for the corrections)
```

The Luau CLI comes from the [luau-lang/luau releases](https://github.com/luau-lang/luau/releases). The harness fakes a minimal Roblox engine; its results are not Studio results.

## After the audit

Send the report back, confirm the high-priority findings, apply only accepted fixes, and repeat the relevant Roblox Studio tests (`M2_REVIEW_GUIDE.md` section 9) before approving Milestone 2. Do not start Milestone 2.1 or Milestone 3 just because an AI says PASS.
