# Emberbound roadmap

Planning draft prepared 7 Nov 2026 from the producer's milestone outline and [recorded decisions](DECISIONS.md). This assigns feature ownership and dependencies. The proposed first public launch follows M8. Expansion milestones M9-M14 follow that launch, with cross-server trading optional. The launch cutoff and expansion grouping are planning proposals for the producer to review. This revision brings basic prestige into M4.1 before launch, adds one focused persistence checkpoint after M3, and assigns cross-server leaderboards to M13.

## Current position

- M1 passed QA and review.
- M2 Round 4 merged through [PR #1](https://github.com/zelly-cious/Emberbound/pull/1) at `2279623`. The producer's outline describes an earlier status. Round 4 includes the reviewed BigNum adoption and Studio QA record.
- M2.1 is [draft PR #3](https://github.com/zelly-cious/Emberbound/pull/3), head `39a5357`. Gameplay source matches reviewed `9a3ad1e`, with 82 offline tests and producer-attested Studio passes. Release-place helper cleanup and release packaging remain to be completed.
- M3 is in progress on this branch. The parser fix and first persistence implementation are present at `a94f020`. Existing offline checks pass 16/16 with 106 tests. An independent delayed-save/rejoin regression exposed lost progress when a new same-server session takes a lock while the previous release is pending. Fix that path as part of M3.
- [M3_PLAN.md](M3_PLAN.md) tracks the implementation details. [Deferred launch QA](review/LAUNCH_QA_DEFERRED.md) tracks manual checks.

## Milestones through the proposed first launch

| Milestone | Deliverable and ownership | Completion condition |
|---|---|---|
| M1 - Core combat | Fixed camera, tapping, enemy HP, stages, Gold rewards and server-authoritative damage. | Existing QA and review accepted. |
| M2 - Tap upgrades, economy and BigNum | Gold-funded tap upgrades, upgrade UI, rising costs, server purchase validation and bounded BigNum arithmetic. | Released Round 4 baseline, already merged. |
| M2.1 - Shared stat calculation | StatService owns base stats and modifiers by source, including upgrades, heroes, equipment and perks. Recompute without overwriting other sources. M5 owns the final balancing rule for stacking. | Reviewed implementation and QA evidence, clean release parity, updated source manifest and installer, then merge review. |
| M3 - Saving and transaction foundations | Versioned profiles, migrations, session ownership, safe save/load, typed currency wallets, durable transaction journal, operation IDs and interrupted-transaction recovery. Implement active-play tracking and define prestige fields, reset/retention rules and operation recovery before M4 economy tuning. | Preserve progress across retries, rejoin, shutdown and overlapping sessions. Fix the pending-release race. Failed loads preserve the stored record. Recovery applies each operation once. Pass the focused M3 persistence checkpoint before M4. |
| M4 - Heroes and automatic DPS | Guaranteed starter hero, permanent hero identities, collection, leveling, party slots, derived hero stats and automatic server damage. Tune progression using M3's prestige contract and planned M4.1 rewards. Taps and heroes share combat and reward rules. | Starter grant and hero ownership survive reload. DPS, taps, party changes and purchases preserve player isolation and reward each enemy once. |
| M4.1 - Basic prestige | A server-validated reset, a permanent prestige reward, the reset UI and StatService integration for the reward. Use the M3 contract below, with eligibility and reward configuration established before M4 tuning. | The reset and reward recover as one operation, replay grants once, retained progress survives, and the starting run is playable after reset/rejoin. Balance later M5/M6 progression around this loop. |
| M5 - Equipment and inventory | Gameplay-earned equipment and initial rarity tiers, saved inventory, the three player-wide Weapon/Amulet/Sigil slots, passive bonuses and special effects. Finalize stacking and rounding with StatService. | Drops, equip/unequip and item effects save correctly and preserve other stat sources. |
| M6.1 - Gem income and reward claims | Gameplay-earned Gems/tickets, starting with stage milestones, then quests, achievements and daily goals. Build reusable quest definitions, daily rollover and reward claim IDs. | Players can earn Gems through gameplay, and each eligible reward is granted once across retries and rejoin. |
| M6.2 - Free hero summoning | Gem banners, gameplay-earned tickets, numerical rarity odds, pity, duplicate rules, summon UI and permanent hero ownership. | Spending, pity and the hero grant recover together. M6.1 supplies the earnable currency path. |
| M7 - Hero trading | Trading-unlock quest using M6.1's quest framework, progress eligibility and M3 active time. Hero-for-hero trades, trade history, ownership validation, paid-origin provenance, anti-alt eligibility and recoverable settlement across both profiles. Implement hero-for-Crown trade handling for activation in M8. | Cancellation, disconnect and retry recover to a defined outcome for both players. Begin with trades between players in the same server. |
| M8 - Premium economy | Robux Developer Products grant Crowns, Crown wallet activation, premium banners with disclosed hard pity, permanent Crown-funded perks and eligible Crown transfers. | Durable receipt handling, policy eligibility, banner odds, paid-origin trading restrictions and purchase/trade recovery are verified. The integrated launch QA checkpoint follows M8. |

### M3 implementation contract

- Currency rules distinguish BigNum Gold from bounded whole-number Gems and Crowns. Income ownership stays with M6 for Gems and M8 for paid Crowns.
- Transaction processing validates first, mutates gameplay state without yielding, marks the profile dirty and records the durable recovery state required for that operation.
- Use stable operation IDs for retryable grants and spends. Later summons, trades, crafting and prestige reuse the recovery foundation and add their own operation-specific state.
- Profile saves carry active seconds. Count only server-accepted activity under an explicit idle rule, and preserve it across rejoin.
- Keep the first-slice autosave and lock defaults in M3_PLAN.md as reviewable implementation defaults. Ownership and recovery must hold when writes take longer than those nominal intervals.
- Every later milestone extends the profile through versioned migrations.

### Prestige contract before M4 tuning

The following reset policy is a product proposal, carried forward from the earlier M10 draft. Record any producer adjustment before M4 tuning.

| On basic prestige | Proposed v1 rule |
|---|---|
| Reset | Stage returns to 1, run Gold to 0, tap-upgrade level to 1, and the current enemy/combat state is rebuilt. |
| Retain | Hero ownership and levels, inventory/equipment, party selection, Gems, Crowns, pity, permanent perks, quest/achievement claim records, paid-origin records, active seconds and trading eligibility. |
| Grant | A permanent prestige reward computed from server-validated progress under explicit eligibility and reward configuration. Apply its stat benefit through StatService. |
| Persist and recover | A versioned prestige record, reset/run identity and operation ID keep the reset and reward consistent. Retain purchase receipts, trade history and recovery records through reset. |

M3 owns the schema, migration and reset/recovery contract. Establish eligibility, reward parameters and the reset policy before M4 economy tuning. M4.1 owns the working reset mechanic and UI before M5/M6 balancing. M10 later extends this working system.

### M6 and M8 policy requirements

Roblox requires outcome odds disclosures and per-player eligibility handling for paid random items, including outcomes bought with currency purchasable with Robux. M8 must check the applicable PolicyService restrictions for paid banners and paid-item trading. The project's conservative paid-origin rule remains decision 4. [Roblox paid random item guidance](https://create.roblox.com/docs/production/monetization/paid-random-items)

Crown grants from Developer Products use ProcessReceipt and durable handling of each receipt's PurchaseId, with retries preserving a single grant. M8 owns the policy review for Crown transfers, and M13 owns it for event prizes. [Roblox Developer Products](https://create.roblox.com/docs/production/monetization/developer-products) [MarketplaceService receipt handling](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt)

## Scheduled expansion milestones

| Milestone | Previously unscheduled features | Dependencies and scope |
|---|---|---|
| M9 - Bosses and new worlds | Boss encounters, world unlocks, new enemy pools and world-specific rewards. | Builds on M4 combat, M5 drops and M3 migration/recovery. World transitions and boss rewards are server-owned. |
| M10 - Prestige expansion | Extend M4.1's working prestige loop with the new worlds and boss progression introduced in M9. | Review progression thresholds and rewards, migrate the existing prestige record, and preserve the published reset/retention contract through the update. |
| M11 - Crafting and higher rarities | Gameplay-earned materials, recipes, equipment upgrades and additional equipment/hero rarity tiers. | Builds on M5 inventory, M6/M8 banner catalogs and M9 material sources. Crafting atomically consumes inputs and grants a uniquely identified output. Equipment acquisition and crafting materials remain gameplay-earned. Update banner odds when hero tiers expand. |
| M12 - Hero skills and hero-specific gear | Hero skill progression and cooldown/effect rules, plus equipment attached to individual heroes. | Builds on M4 party/DPS, M5 effects, M11 inventory progression and M3 migrations. Hero gear uses separate slots from the existing three player-wide slots. Preserve equipment ownership during hero transfers. |
| M13 - Events and cross-server leaderboards | Cross-server leaderboards and Crown leaderboard-event settlement, seasonal rotations, limited-time quests, world events, global/cooperative goals and expanded event rewards. | Extends M6.1 reward claims and M9 boss/world content into an event framework with server-owned UTC schedules, scores, frozen standings and durable claims. Apply M8 paid-item rules to eligible rewards. This revises decision 3's former M8 timing. |
| M14 - Cross-server trading, optional | Trading between players in different servers. | Begin after M7/M8 trading is stable. First prove durable coordination, exclusive ownership, settlement and crash recovery across servers, then decide whether to enable it. Retain per-player policy and paid-origin restrictions. |

## Delivery and QA workflow

1. Finish M2.1 integration, then complete M3 recovery, wallets, active time and the prestige contract. Fix the save/rejoin race.
2. Run the focused M3 persistence checkpoint below before M4. Keep automatic checks and fix confirmed defects during development.
3. Implement M4, M4.1, M5, M6.1, M6.2, M7 and M8 in dependency order. Carry earlier QA attestations as evidence for their recorded source revisions and collect later manual checks for launch.
4. Run one integrated manual QA pass after M8 on the final launch build. Include prestige, hero DPS, equipment, summoning, trading, receipts, mobile layout and final source parity. Repeat the M3 persistence scenarios when later changes affect their behavior.
5. Retain the reusable EmberboundStatQA source and the disabled helper in the separate QA place. Remove the helper from the release place before recording release parity. Its cleanup is scheduled for final QA.
6. Package the exact reviewed launch source with matching manifest, parity expectations, test totals and installer. Prepare the private persistence test place through a documented install/publish path.
7. Public publication and merges follow producer approval of the reviewed result.

### Focused M3 persistence checkpoint

This is one targeted private Studio session after the M3 implementation and before M4. Use an isolated published test place with working DataStore access.

- Save Gold, stage and upgrade levels, stop/restart or leave/rejoin, and verify the restored values and derived tap damage.
- Verify an autosave and a release write using the real DataStore path.
- Exercise the pending-save/rejoin fix and a controlled load/save failure with reviewed test hooks. The player must safely wait or receive a retry outcome while stored progress remains protected.
- Record the exact source revision and a concise result in the QA record. This checkpoint is pending until performed. Keep the broader final-launch checks in [the QA list](review/LAUNCH_QA_DEFERRED.md).

## Product parameters to record during each milestone

Define the hero roster, party-slot progression, item tiers, prices, Gem rewards, pity counts and trading thresholds as explicit configuration during their owning milestone. Preserve the recorded 30-minute active-play trading requirement. Record any producer changes to this roadmap in DECISIONS.md.
