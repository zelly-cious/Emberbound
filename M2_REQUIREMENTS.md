# Milestone 2 — Frozen scope and acceptance contract

**Milestone:** Tap Upgrades, Economy & BigNum
**Implementation under review:** commit `024cd68838d6c34633a00e7eadcb320c251186f0` on `feature/m2-tap-upgrades-bignum`, corrected for audit findings F1–F6 in `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf` (`review/M2_CORRECTIONS_REPORT.md`)
**Baseline:** Milestone 1 at `730218a` (includes the ClientReady sync-retry fix and the `Camera.Focus` fix)

Sources: *Emberbound — Technical Architecture & Roadmap* (31 Oct 2026, M2 section and "Large numbers") and *Emberbound — Master Spec V1.0 Architecture Review* (31 Oct 2026), which supersedes the roadmap where they conflict. Neither PDF is in this repository; the requirements they impose on M2 are restated here so the reviewer needs nothing else.

## In scope

1. **BigNum.** One shared, unit-tested big-number module for every value that grows exponentially: enemy HP, tap damage, Gold, upgrade costs (and later hero DPS). Non-negative only. Saved/network form is one canonical string; parsing rejects malformed or non-finite input. Display uses suffixes K … Dc, then scientific notation. Below 2^53 results must stay exact so Milestone 1's values are unchanged.
2. **Switch in one change.** CombatService HP, damage and Gold, and the HUD number formatter, move to BigNum together. Remote names, the `ClientReady` handshake and `ApplyDamage`'s role are kept.
3. **Tap upgrade.** `ProgressionConfig` cost and value curves, `UpgradeService`, and an upgrade screen. UpgradeService spends Gold, raises the tap level, computes tap damage from `ProgressionConfig`, then calls the new `CombatService.SetTapDamage(player, value)`. Taps keep calling `ApplyDamage(player, state.tapDamage, "Tap")`.
4. **One way to spend Gold.** CombatService still awards Gold on kills. Every spend goes through one function that checks and deducts in a single non-yielding step, so Gold can never go negative or be spent twice.
5. **Gacha-ready economy shape.** A currency API keyed by currency id with a reason on every grant and spend; Gold is the only currency now and nothing converts one currency into another. A reusable per-remote rate limiter. Purchase-style requests carry ids only (never prices or outcomes) and get results through `FireClient` to one player. `ProgressionConfig` is validated at start.

## Exit criteria (from the roadmap)

| Criterion | Where to verify |
|---|---|
| Upgrades raise tap damage | `UpgradeService.handlePurchaseRequest` → `CombatService.SetTapDamage`; Studio test S3 |
| Spamming the upgrade remote never drives Gold negative | `Wallet.trySpend`, `BigNum.trySub`, `RateLimiter`; probes 5d–5f; Studio test S4 |
| BigNum tests pass | `ServerScriptService/Tests` (61 tests since the corrections; 48 in round 1); offline runs in `review/M2_CORRECTIONS_REPORT.md` and, for round 1, `review/M2_CHECK_RESULTS.md` |
| Milestone 1's stage table is unchanged | `GameConfig.GetEnemyMaxHp` / `GetGoldReward`; probe section 3; Studio test S1 |

Milestone 1 behaviour that must still hold: stage 1 starts at 0 Gold and tap damage 1; Forest Slime 10/10 HP; 10 accepted taps defeat it once and award 5 Gold once; stage 2 = 11 HP / 5 Gold, stage 3 = 13 HP / 6 Gold; 0.07 s server tap cooldown; per-player isolation; no avatar, fixed camera.

## Known gaps against the roadmap's M2 list (reported, not fixed)

The roadmap's "prepares for gacha" list asked for more than the delivered code contains. The Master Spec V1.0 review re-assigned most of it; one item is an approved follow-up.

| Roadmap item | State in this code | Owner |
|---|---|---|
| Stat pipeline combining additive and multiplicative bonuses into tap damage | Not present. `SetTapDamage` overwrites tap damage with the upgrade value. | **M2.1 StatService** (approved, after this audit) |
| Per-player state shaped like the saved profile (schemaVersion, currencies, levels, transaction log) | Not present. State is split across CurrencyService, UpgradeService and CombatService; no schemaVersion or transaction log. | M3 (Master Spec review, M3 items 2, 4, 7) |
| Transaction shape "validate, mutate in one non-yielding step, **mark dirty**, reply" | Validate / mutate / reply present; no dirty flag (nothing is saved yet). | M3 |
| Buy-max via a geometric series in log space | Not present; one level per request. | Unscheduled |
| BigNum "power" operation | No general `BigNum.pow`; `BigNum.scaledPower(base, growth, steps)` covers every current curve. | As needed |
| Currency kinds (BigNum vs whole number) and rules | Every currency is a BigNum; no kind/rules fields. | M3 |
| Gold multiplier input and tap/defeat effect hooks | Not present. | M5 |

Comment-only staleness, deferred to the next correction: the headers of `ProgressionConfig` and `CurrencyService` still mention "earned tickets, premium currency"; under Master Spec V1.0 these are **Gems** and **Crowns**.

## Explicitly out of scope for M2

Persistence / DataStores, heroes and hero DPS, summoning / gacha, equipment, trading, Gems, Crowns, premium purchases, PolicyService, bosses, prestige, the StatService (M2.1) and anything in Milestone 3 or later. See `DECISIONS.md` for the recorded future decisions.
