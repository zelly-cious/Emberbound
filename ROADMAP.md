# Emberbound roadmap

Planning draft prepared 7 Nov 2026 from the producer's milestone outline and [recorded decisions](DECISIONS.md). This assigns feature ownership and dependencies. The proposed first public launch follows M8. Expansion milestones M9-M14 follow that launch, with cross-server trading optional. The launch cutoff and expansion grouping are planning proposals for the producer to review.

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
| M3 - Saving and transaction foundations | Versioned profiles, migrations, session ownership, safe save/load, typed currency wallets, durable transaction journal, operation IDs and interrupted-transaction recovery. Implement server-validated active-play tracking for the later 30-minute trading requirement. | Preserve progress across retries, rejoin, shutdown and overlapping sessions. Fix the pending-release race. Failed loads preserve the stored record. Recovery applies each operation once. |
| M4 - Heroes and automatic DPS | Guaranteed starter hero, permanent hero identities, collection, leveling, party slots, derived hero stats and automatic server damage. Taps and heroes share combat and reward rules. | Starter grant and hero ownership survive reload. DPS, taps, party changes and purchases preserve player isolation and reward each enemy once. |
| M5 - Equipment and inventory | Gameplay-earned equipment and initial rarity tiers, saved inventory, the three player-wide Weapon/Amulet/Sigil slots, passive bonuses and special effects. Finalize stacking and rounding with StatService. | Drops, equip/unequip and item effects save correctly and preserve other stat sources. |
| M6 - Earned summoning, Gem income and event framework | Gem banners, gameplay-earned tickets, disclosed rarity odds and pity, duplicate rules and permanent summon ownership. Gem income starts with stage milestones, then quests, achievements and daily goals. Build reusable quests, schedules, event IDs and reward claims here. | Players can earn and spend Gems through gameplay. Spending, pity, hero grants and reward claims recover together without duplicate rewards. |
| M7 - Hero trading | Trading-unlock quest using M6's quest framework, progress eligibility and M3 active time. Hero-for-hero trades, trade history, ownership validation, paid-origin provenance, anti-alt eligibility and recoverable settlement across both profiles. Implement hero-for-Crown trade handling for activation in M8. | Cancellation, disconnect and retry recover to a defined outcome for both players. Begin with trades between players in the same server. |
| M8 - Premium economy and launch | Robux Developer Products grant Crowns, Crown wallet activation, premium banners with disclosed hard pity, permanent Crown-funded perks and eligible Crown transfers. Add cross-server leaderboards and reward settlement to M6's event framework, following decision 3. | Durable receipt handling, policy eligibility, banner odds, paid-origin trading restrictions and purchase/trade recovery are verified. Complete the consolidated launch QA on the final packaged build. |

### M3 implementation contract

- Currency rules distinguish BigNum Gold from bounded whole-number Gems and Crowns. Income ownership stays with M6 for Gems and M8 for paid Crowns.
- Transaction processing validates first, mutates gameplay state without yielding, marks the profile dirty and records the durable recovery state required for that operation.
- Use stable operation IDs for retryable grants and spends. Later summons, trades, crafting and prestige reuse the recovery foundation and add their own operation-specific state.
- Profile saves carry active seconds. Count only server-accepted activity under an explicit idle rule, and preserve it across rejoin.
- Keep the first-slice autosave and lock defaults in M3_PLAN.md as reviewable implementation defaults. Ownership and recovery must hold when writes take longer than those nominal intervals.
- Every later milestone extends the profile through versioned migrations.

### M6 and M8 policy requirements

Roblox requires outcome odds disclosures and per-player eligibility handling for paid random items, including outcomes bought with currency purchasable with Robux. M8 must check the applicable PolicyService restrictions for paid banners and paid-item trading. The project's conservative paid-origin rule remains decision 4. [Roblox paid random item guidance](https://create.roblox.com/docs/production/monetization/paid-random-items)

Crown grants from Developer Products use ProcessReceipt and durable handling of each receipt's PurchaseId, with retries preserving a single grant. M8 also owns the current policy review for event rewards and Crown transfers. [Roblox Developer Products](https://create.roblox.com/docs/production/monetization/developer-products) [MarketplaceService receipt handling](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt)

## Scheduled expansion milestones

| Milestone | Previously unscheduled features | Dependencies and scope |
|---|---|---|
| M9 - Bosses and new worlds | Boss encounters, world unlocks, new enemy pools and world-specific rewards. | Builds on M4 combat, M5 drops and M3 migration/recovery. World transitions and boss rewards are server-owned. |
| M10 - Prestige | A repeatable progression reset with permanent progression rewards. | Builds on M9 progression and M3 recoverable transactions. Proposed reset policy resets stage, run Gold and tap-upgrade levels while retaining hero ownership/levels, equipment, Gems, Crowns, permanent perks and trading eligibility. Review this retention table before implementation. |
| M11 - Crafting and higher rarities | Gameplay-earned materials, recipes, equipment upgrades and additional equipment/hero rarity tiers. | Builds on M5 inventory, M6/M8 banner catalogs and M9 material sources. Crafting atomically consumes inputs and grants a uniquely identified output. Equipment acquisition and crafting materials remain gameplay-earned. Update banner odds when hero tiers expand. |
| M12 - Hero skills and hero-specific gear | Hero skill progression and cooldown/effect rules, plus equipment attached to individual heroes. | Builds on M4 party/DPS, M5 effects, M11 inventory progression and M3 migrations. Hero gear uses separate slots from the existing three player-wide slots. Preserve equipment ownership during hero transfers. |
| M13 - Seasonal and global events | Seasonal rotations, limited-time quests, world events, global/cooperative goals and expanded event rewards. | Reuses M6 schedules/claims and M8 cross-server leaderboards. M9 supplies boss/world event content. Ended events retain enough claim history for recovery. |
| M14 - Cross-server trading, optional | Trading between players in different servers. | Begin after M7/M8 trading is stable. First prove durable coordination, exclusive ownership, settlement and crash recovery across servers, then decide whether to enable it. Retain per-player policy and paid-origin restrictions. |

## Delivery and QA workflow

1. Finish M2.1 integration, then complete the remaining M3 recovery, wallet and active-time work before expanding the gameplay systems.
2. Implement M4-M8 in dependency order. Keep automatic checks and fix confirmed defects during development.
3. Carry earlier QA attestations as evidence for their recorded source revisions. Add the checks for new or changed behavior to the consolidated launch checklist.
4. Run one integrated manual QA pass on the final launch build. Include persistent saves, migrations/recovery, hero DPS, equipment, summoning, trading, receipts, mobile layout and the final source parity check.
5. Retain the reusable EmberboundStatQA source and the disabled helper in the separate QA place. Remove the helper from the release place before recording release parity. Its cleanup is scheduled for final QA.
6. Package the exact reviewed launch source with matching manifest, parity expectations, test totals and installer. Prepare the private persistence test place through a documented install/publish path.
7. Public publication and merges follow producer approval of the reviewed result.

## Product parameters to record during each milestone

Define the hero roster, party-slot progression, item tiers, prices, Gem rewards, pity counts and trading thresholds as explicit configuration during their owning milestone. Preserve the recorded 30-minute active-play trading requirement. Record any producer changes to this roadmap in DECISIONS.md.
