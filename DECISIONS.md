# Emberbound — Recorded decisions

Decisions made by the producer that affect later milestones. **None of them changes the Milestone 2 code under review.** Recorded 31 Oct 2026, during the M2 Codex handoff.

| # | Decision | Milestone | Effect on the code |
|---|---|---|---|
| 1 | **Centralized StatService** (approved as Milestone 2.1, to be built only after the Codex audit of M2 is accepted). It holds each player's base stats and modifiers grouped by source (upgrade, hero, equipment, perk), combines them, rounds down once and calls `CombatService.SetTapDamage`. UpgradeService reports the tap upgrade's base value to it instead of setting tap damage directly, so tap upgrades and future hero/equipment modifiers no longer overwrite each other. Proposed stacking: flat bonuses, then summed percentage bonuses, then multipliers (final rule is an M5 balancing decision). Expected scope: new StatService, one function in UpgradeService, PlayerSessionService add/remove order, new tests; CombatService and the client unchanged. | M2.1 | None in M2. Do not implement during this review. |
| 2 | **Gem income begins in Milestone 6** (stage-milestone rewards at minimum; quests, achievements and daily goals where they fit). | M6 | None in M2. Gold stays the only currency. |
| 3 | **Cross-server Crown leaderboard events are planned for Milestone 8** (ordered DataStore or MemoryStore sorted map; server-owned UTC schedule, server-computed scores, rewards from frozen standings, one claim record per event and player). | M8 | None in M2. |
| 4 | **Paid-origin trading provenance is tracked conservatively**, pending final verification of Roblox policy: a hero is permanently marked paid once it comes from a Crown banner or changes hands for Crowns. | M7–M8 | None in M2. |
| 5 | **Premium banners initially use disclosed hard pity** (a guarantee at a set count, shown numerically before Crowns are spent). | M8 (M6 for Gem banners if adopted there) | None in M2. |
| 6 | **Crown trading launches without fees.** | M7 | None in M2. |
| 7 | **Server-validated active-gameplay tracking begins in Milestone 3** (only accepted server actions count; feeds the trading unlock's 30-minute active-play requirement). | M3 | None in M2. M3's profile schema must include the active-seconds field and its server-side counter. |

Background: *Emberbound — Master Spec V1.0 Architecture Review* (31 Oct 2026) lists the open producer decisions these resolve. That document also confirms Milestone 2 "stays exactly as submitted for Codex review".
