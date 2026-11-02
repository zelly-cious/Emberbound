# Codex review handoff — Emberbound Milestone 2

**Read-only audit of Milestone 2: Tap Upgrades, Economy & BigNum.** This repository is self-contained; no conversation history is needed.

> **Current review (round 4 BigNum adoption):** see `review/M2_BIGNUM_ADOPTION_CODEX_HANDOFF.md`. Everything below is historical.

> **Status (1 Nov 2026) — superseding note; the round 1 and round 2 sections below are historical.** Codex's round 2 re-review returned **CONDITIONAL PASS** (source: Codex's round 2 re-review of PR head `09be466`, as summarized in the producer's "Milestone 2 Final Review Decisions" message of 1 Nov 2026. The full Codex report text is not in this repository). The producer then recorded a bounded BigNum precision contract and conditionally deferred limitations R2-1 (`BigNum.parse`) and R2-2 (`BigNum.ratio`) for M2 only (`M2_REQUIREMENTS.md`, `DECISIONS.md` decisions 8–10). Two statements below are superseded: "exact below 2^53" (round 1 summary) is replaced by that bounded contract, and "`git diff e4b0108 HEAD -- src` is empty" is no longer true. The only later source change is one comment line in `CombatService.luau`, with byte-identical bytecode (`SOURCE_HASHES.txt` round 3). Next step: Roblox Studio QA with `M2_STUDIO_REGRESSION_GUIDE.md`. Milestone 2 is frozen until then; PR #1 is not to be merged.

## Round 2 — re-review of the audit corrections (current)

The round 1 audit (`review/audits/Emberbound_M2_Independent_Audit.pdf`) returned **FAIL** with findings F1–F6 (2 Medium, 4 Low). All six were corrected in one source commit.

| | |
|---|---|
| Pull request | [zelly-cious/Emberbound#1](https://github.com/zelly-cious/Emberbound/pull/1), branch `feature/m2-tap-upgrades-bignum` → `main`; **not to be merged before re-review and Studio testing** |
| **Corrections commit (re-review this)** | `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf` |
| What changed | `git diff 024cd68 e4b0108 -- src`: BigNum (F1, F2, F4, F5), TestKit and TestRunner (F3, F6), 13 new tests incl. the new `Tests/TestKitTests` suite. No gameplay, service, remote or client changes. |
| Later commits | Documents and `review/` tooling only: `git diff e4b0108 HEAD -- src` is empty |
| Report | `review/M2_CORRECTIONS_REPORT.md` — fixes, tradeoffs, files, tests, results, unresolved items |
| Results (no Roblox Studio) | 61 / 61 unit tests (48 original + 13 new); 75 / 75 probes (54 original + 21 new); 24 / 24 files compile; Selene clean; F5 strict diagnostic gone under both solvers |
| Prompt | `REREVIEW_PROMPT.md` |

Re-review focus: correctness of the new `BigNum.sub` native path and its 10^23 bound; `tryNormalize` vs `normalize` error behaviour; subnormal scaling in `multiplyByPowerOfTen` / `divideByPowerOfTen`; the F5 tradeoff (writable type, runtime freeze); `TestKit.runSuites` / `TestRunner` failure accounting; and that nothing outside those files changed.

---

## Round 1 — original submission (historical)

Everything below describes the submission audited in round 1 and is kept unchanged except for this heading and the labels in the table.

| | |
|---|---|
| Repository | `zelly-cious/Emberbound` |
| Branch | [`feature/m2-tap-upgrades-bignum`](https://github.com/zelly-cious/Emberbound/tree/feature/m2-tap-upgrades-bignum) |
| Pull request | [zelly-cious/Emberbound#1](https://github.com/zelly-cious/Emberbound/pull/1) |
| Implementation commit (audited in round 1) | `024cd68838d6c34633a00e7eadcb320c251186f0` |
| Milestone 1 baseline | `730218a228463db5dc02e4c6b9726122d3a5e0c2` (sync-retry + `Camera.Focus` fixes) |
| Round 1 PR head | `eb5a3511d932de5c1860852c0f47dfa8911912a5` (documents only on top of `024cd68`) |
| Source provenance | `Emberbound_M2_Scripts.zip` (packaged 31 Oct 2026 03:36). All 23 scripts byte-identical; round 1 manifest in `SOURCE_HASHES.txt`. |

## Milestone 2 requirements (full contract: `M2_REQUIREMENTS.md`)

1. A shared, unit-tested **BigNum** for HP, damage, Gold and costs: non-negative, canonical string for network/saves, exact below 2^53, far beyond 10^308.
2. CombatService HP/damage/Gold and the HUD formatter switch to BigNum in one change; remote names, handshake and `ApplyDamage` kept.
3. **Tap Damage upgrade:** `ProgressionConfig` curves, `UpgradeService`, upgrade panel, `CombatService.SetTapDamage`.
4. **One way to spend Gold:** check and deduct in one non-yielding step — never negative, never charged twice.
5. Currency API keyed by id with a reason on every grant/spend; reusable rate limiter; ids-only requests; config validated at start.

**Exit criteria:** upgrades raise tap damage · spamming the upgrade remote never drives Gold negative · BigNum tests pass · M1 stage table unchanged.

## New and modified scripts (details: `M2_REVIEW_GUIDE.md` §1–2)

- **New (17):** `Shared/BigNum`, `Shared/ProgressionConfig`; `CombatRules`, `CurrencyService`, `PlayerSessionService`, `RateLimiter`, `UpgradeService`, `Wallet`; `Tests/` (TestRunner, TestKit, 6 suites); `CombatClient/UpgradePanel`.
- **Modified M1 scripts (5):** `Shared/GameConfig`, `CombatService`, `ServerInit`, `CombatClient`, `CombatClient/CombatHud`. **Unchanged:** `ArenaView`.
- **New RemoteEvents (3):** `RequestUpgrade`, `UpgradeUpdate`, `CurrencyUpdate`. No RemoteFunctions.

## Automated results (details and commands: `review/M2_CHECK_RESULTS.md`)

**Roblox Studio was not used.** These ran on Windows with the Luau CLI 0.745 and a minimal fake Roblox engine:

| Check | Result |
|---|---|
| Shipped unit tests via the real `TestRunner` | **48 / 48 pass** (one test used a stand-in `Random`, so its 200 random values differ from Studio's) |
| Review probes: BigNum fuzz (20 003 values), > 10^308, M1 formula parity (stages 1–209 exact), cost curves (levels 1–3000), two-player server simulation | **54 / 54 pass** |
| Selene 0.32.0 lint, Roblox std, all of `src/` | **0 errors, 0 warnings** |
| `luau-analyze --mode=strict` on the 13 Roblox-free modules | 1 type-level finding (below); services and client scripts **not** type-checked |
| Milestone 2 Studio QA | **None exists** |

## Known risks and limitations

- **Type mismatch under the new Luau solver:** `BigNum.luau:37` — `table.freeze` returns read-only `m`/`e`; the exported `BigNum` type is read-write. No runtime effect; not fixed.
- **Tap damage is overwritten, not derived** (`CombatService.SetTapDamage`). Any second stat source would conflict → approved **M2.1 StatService**, after this audit only.
- **Roadmap items not in the code:** profile-shaped state with schemaVersion and transaction log, a "mark dirty" step, buy-max, a general `BigNum.pow` (see `M2_REQUIREMENTS.md`, "Known gaps"; mostly re-assigned to M3 by the Master Spec V1.0 review).
- **Precision absorption:** a cost or reward below ~10^-17 of the balance does not change it (a purchase at a 1e400 balance is free).
- **Silent drops:** rate-limited, malformed or unsynced purchase requests get no reply.
- **Simulation gaps:** remote handlers ran synchronously (Roblox may defer them); client scripts never ran; engine math may differ in the last bit.
- **No persistence;** Milestone 1 itself is "implemented and reviewed but not formally closed".
- Stale header comments in `ProgressionConfig` / `CurrencyService` ("earned tickets, premium currency" → Gems, Crowns).

## Areas requiring independent review

1. `UpgradeService.handlePurchaseRequest` (`UpgradeService.luau:123-162`): ordering of the rate limit, request-id check and spend; whether any path charges without leveling, or levels without charging; request-id edge cases.
2. `BigNum` (`BigNum.luau`): the two-regime invariant, `normalize`/`toScientific` rounding at regime and decade boundaries, `parse` on hostile input, `add`/`sub` with large exponent gaps, overflow near exponent 2^53 − 1.
3. `PlayerSessionService` lifecycle: early `ClientReady`, partial-add failure and cleanup, rejoin, sync ordering across three services.
4. Exactly-once defeat and Gold grant (`CombatRules.resolveHit`, `CombatService.ApplyDamage`) under rapid taps and with future DPS callers.
5. Client: BigNum decoding and malformed payloads in `CombatClient.luau`; `UpgradePanel.ContainsPoint` with `ScreenInsets.CoreUISafeInsets` vs `InputObject.Position`; touch/mouse duplicate filtering.
6. M1 regressions: stage table, starting values, 0.07 s cooldown, `ClientReady` retry, `Camera.Focus`, and the changed `CombatUpdate` payload (`gold` removed, numbers → strings).
7. Readiness for M2.1 StatService, M3 persistence (Gold as a BigNum string, levels, stage restore) and M4 hero DPS through `ApplyDamage`.

Rules: `AGENTS.md`. Prompt and report format: `REVIEW_PROMPT.md`. Recorded future decisions (none change M2): `DECISIONS.md`.
