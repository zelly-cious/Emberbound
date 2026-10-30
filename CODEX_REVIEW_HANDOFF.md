# Codex review handoff — Emberbound Milestone 2

**Read-only audit of Milestone 2: Tap Upgrades, Economy & BigNum.** This repository is self-contained; no conversation history is needed.

| | |
|---|---|
| Repository | `zelly-cious/Emberbound` |
| Branch | [`feature/m2-tap-upgrades-bignum`](https://github.com/zelly-cious/Emberbound/tree/feature/m2-tap-upgrades-bignum) |
| Pull request | Targets `main`, not to be merged before the audit: [open / view](https://github.com/zelly-cious/Emberbound/compare/main...feature/m2-tap-upgrades-bignum) |
| **Implementation commit (review this)** | `024cd68838d6c34633a00e7eadcb320c251186f0` |
| Milestone 1 baseline | `730218a228463db5dc02e4c6b9726122d3a5e0c2` (sync-retry + `Camera.Focus` fixes) |
| Later commits on the branch | Review documents and `review/` tooling only. Check: `git diff 024cd68 HEAD -- src` is empty. |
| Source provenance | `Emberbound_M2_Scripts.zip` (packaged 31 Oct 2026 03:36). All 23 scripts byte-identical; manifest in `SOURCE_HASHES.txt`. |

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
