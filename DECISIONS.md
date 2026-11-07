# Emberbound — Recorded decisions

Decisions made by the producer that affect Milestone 2's documented contract or later milestones. **None of them changes executable Milestone 2 code.** Decisions 1–7 were recorded on 31 Oct 2026, during the M2 Codex handoff; decisions 8–10 on 1 Nov 2026, after Codex's round 2 re-review of PR head `09be466` (CONDITIONAL PASS). Decision 8 led to a one-line comment correction in `CombatService.luau` only (byte-identical bytecode; `SOURCE_HASHES.txt` round 3).

| # | Decision | Milestone | Effect on the code |
|---|---|---|---|
| 1 | **Centralized StatService** (approved as Milestone 2.1, to be built only after the Codex audit of M2 is accepted). It holds each player's base stats and modifiers grouped by source (upgrade, hero, equipment, perk), combines them, rounds down once and calls `CombatService.SetTapDamage`. UpgradeService reports the tap upgrade's base value to it instead of setting tap damage directly, so tap upgrades and future hero/equipment modifiers no longer overwrite each other. Proposed stacking: flat bonuses, then summed percentage bonuses, then multipliers (final rule is an M5 balancing decision). Expected scope: new StatService, one function in UpgradeService, PlayerSessionService add/remove order, new tests; CombatService and the client unchanged. | M2.1 | None in M2. Do not implement during this review. |
| 2 | **Gem income begins in Milestone 6** (stage-milestone rewards at minimum; quests, achievements and daily goals where they fit). | M6 | None in M2. Gold stays the only currency. |
| 3 | **Historical timing, superseded by revision 13 below. Cross-server Crown leaderboard events were planned for Milestone 8** (ordered DataStore or MemoryStore sorted map; server-owned UTC schedule, server-computed scores, rewards from frozen standings, one claim record per event and player). | M8 | None in M2. |
| 4 | **Paid-origin trading provenance is tracked conservatively**, pending final verification of Roblox policy: a hero is permanently marked paid once it comes from a Crown banner or changes hands for Crowns. | M7–M8 | None in M2. |
| 5 | **Premium banners initially use disclosed hard pity** (a guarantee at a set count, shown numerically before Crowns are spent). | M8 (M6 for Gem banners if adopted there) | None in M2. |
| 6 | **Crown trading launches without fees.** | M7 | None in M2. |
| 7 | **Server-validated active-gameplay tracking begins in Milestone 3** (only accepted server actions count; feeds the trading unlock's 30-minute active-play requirement). | M3 | None in M2. M3's profile schema must include the active-seconds field and its server-side counter. |
| 8 | **Bounded BigNum precision contract (approved).** BigNum is explicitly finite-precision. Kept: exact tested early-game integer arithmetic, Milestone 1 formulas and progression, server-authoritative combat and purchases, non-negative Gold, replay protection and exactly-once rewards. Accepted: rounding and absorption at very large magnitudes, and approximate cancellation after operations involving large approximate values. Not promised: universal exactness merely because a final value is below 2^53, unlimited range, or universally correctly rounded results. Transaction guarantees are distinct from numerical precision guarantees. Full text: `M2_REQUIREMENTS.md`. | M2 (contract) and later | None executable. Documentation corrected; one comment line in `CombatService.luau`. |
| 9 | **R2-1 parser limitation: conditionally deferred for M2 only.** `BigNum.parse` can accept an originally out-of-range decimal after rounding (e.g. `"1"` + 23 zeros + `"e9007199254740969"`). Allowed only while production parsing is limited to client-side decoding of server-generated strings. Do not treat `parse` followed by `isValid` as proof that the original decimal was in range. | Gate: before M3 (or any earlier untrusted input path) | Fix and test the parser before untrusted profile data, imports, client-supplied strings or any other untrusted numerical input can reach it, including M3 persistence if it introduces such a path. |
| 10 | **R2-2 ratio limitation: conditionally deferred for M2 only.** `BigNum.ratio` can overflow or underflow prematurely at extreme magnitudes. Valid only while the result is cosmetic, HP stays bounded by max HP, zero max HP is handled, and no authoritative calculation (combat, damage, purchases, rewards) relies on it. | Gate: before broadening its use | Correct and test `ratio` before its numerical or gameplay use is broadened. |

Background: *Emberbound — Master Spec V1.0 Architecture Review* (31 Oct 2026) lists the open producer decisions these resolve. That document also confirms Milestone 2 "stays exactly as submitted for Codex review".

## Roadmap review revisions (7 Nov 2026)

Planning updates following the producer's roadmap review. Original decisions 1-10 retain their review history. The prestige reset/retention contract is refined in revisions 15-17 below, following the producer's review.

| # | Planning revision | Owner | Implementation consequence |
|---|---|---|---|
| 11 | Basic prestige belongs before launch, with its contract before hero economy tuning. | M3 contract, M4.1 mechanic, M10 expansion | Define the versioned record, reset/retention policy and recovery operation in M3. Set eligibility and reward configuration before M4 tuning. Implement the reset, reward and UI in M4.1 before M5/M6 balancing. |
| 12 | One focused Studio persistence checkpoint precedes M4. | After M3 | Verify the real DataStore save/reload, autosave/release and controlled rejoin/failure paths in a private test place. The broader gameplay checks remain in final launch QA. |
| 13 | Cross-server leaderboards and Crown leaderboard-event settlement move to M13. | M13, superseding decision 3's M8 schedule | M8 concentrates on premium purchases, eligibility, Crown trades and receipt recovery. M13 owns the UTC schedule, computed scores, frozen standings and durable reward claims. |
| 14 | Split M6 into earning/rewards and summoning. | M6.1 and M6.2 | M6.1 supplies Gems, quests, dailies and claim IDs. M6.2 supplies free summoning, pity, duplicate rules and permanent ownership. M13 builds the wider event framework. |

### Prestige contract refinement (7 Nov 2026)

| # | Revision | Owner | Implementation consequence |
|---|---|---|---|
| 15 | Reset Gold-funded hero levels on prestige while retaining hero ownership, identity, rarity and duplicate progress. Retain the other permanent systems listed in ROADMAP.md. | M3 contract, M4.1 implementation | Restore each owned hero's configured starting level during the recoverable reset. Tune Gold costs and DPS with this policy before M4. |
| 16 | Persist lifetime and current-run highest-cleared stage records alongside current stage. | M3, consumed by M4.1/M6.1/M7 | Lifetime progress and durable milestone claim IDs gate one-time Gem rewards. Lifetime progress gates trading. This-run progress drives prestige rewards and resets with the run. Migrate existing profiles using the versioned contract in M3_PLAN.md. |
| 17 | Select a permanent damage multiplier as the v1 prestige reward form. | M3 record, M4.1 reward | Start at 1x and add the configured gain from each eligible completed run. Store it in the prestige record as validated canonical BigNum text and apply it once to tap and hero damage. The reward has no currency-wallet exchange or spend operation. Numeric gain/eligibility parameters are settled before M4 tuning. |

### Prestige serialization, recovery and calibration (7 Nov 2026)

| # | Refinement | Owner | Implementation consequence |
|---|---|---|---|
| 18 | Persist the multiplier and each transaction's calculated gain as canonical BigNum strings. Snapshot the curve version and input run with the operation. | M3 | Default the multiplier to `"1"`. Recovery applies the saved gain under its operation ID, including after a config update. Test large-value round trips and recovery across a curve change. |
| 19 | Size the additive gain curve against enemy HP growth and the reset economy. | M3 initial contract, M4 tuning, M4.1 validation | Use the actual HP function, currently based on 1.18 growth per stage. Record relative boost, approximate stage advantage, run duration and time to regain/exceed the previous peak across early/mid/late progression. Set explicit targets and initial values before M4 tuning, then refine them with the implemented hero loop. |
