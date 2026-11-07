# M3 implementation and offline results

Source under test: `23785544f846817c5d722f69d5e81b11348df46f`, on `feature/m3-planning`, based on M2.1 draft PR #3. This is implementation evidence, not Roblox Studio evidence. M3 acceptance and merging remain pending review and the focused persistence checkpoint before M4.

## Runtime changes

- **Pending release/rejoin:** different sessions cannot take a live lock even in the same server. A load refuses safely if the old local release is still pending after 25 seconds. A failed final save retains its snapshot and retries after five seconds; it does not silently discard the pending release. The regression verifies that the original session's final 100 Gold remains available on a later successful rejoin.
- **Schema v2:** v1 migrates forward, retaining Gold/levels/stage/active time and seeding both highest-cleared records from `max(0, stage - 1)`. Newer versions and malformed current-version data are rejected without overwriting the stored record. Current-version required balances/levels/active time cannot silently default.
- **Typed wallets:** Gold remains BigNum. Gems and Crowns are separately bounded whole values, from 0 through 9,007,199,254,740,991. Their balances are saved but gameplay income, UI and transfers remain assigned to M6/M8. There is no currency conversion.
- **Journal:** one profile contains the balances, upgrade levels, next operation sequence and last 50 completed operations. The applied high-water ID survives pruning. One separately retained pending operation is never pruned. Recovery runs inside the session-claim UpdateAsync and uses the saved amount/levels rather than current prices or curves. Current gameplay mutations remain non-yielding and checkpoint their completed journal entries with their balances. Acknowledging an external durable grant later requires persisting `ProfileTransactions.prepare` before applying/recovering it; receipt processing and cross-profile settlement remain later milestones.
- **Activity:** accepted remote taps and successful purchases extend a ten-second active window. Elapsed time is counted once, capped at the last accepted action plus ten seconds. Joining, syncing, rejected/replayed/rate-limited requests, automatic damage and disconnected time earn no credit. The counter is persisted for the later trading gate; it is not an anti-bot guarantee.
- **Prestige foundation:** saved run identity/count, canonical BigNum multiplier starting at `"1"`, lifetime/run highest cleared stages and stable milestone claim IDs. Pending resets store `calculatedGain`, `gainCurveVersion` and the run snapshot. Recovery retains lifetime/claims/active time/Gems/Crowns, resets Gold/tap levels/run progress, and adds the saved gain once. Hero fields do not exist yet; M4.1 must extend the reset for hero levels and apply the multiplier through StatService.
- **Dirty tracking:** successful economy/combat/activity changes mark revisions; an update arriving while a save yields stays dirty. Autosaves continue to refresh session ownership even when no economy data changed.

The numerical prestige threshold/gain curve and balance targets are not invented here. Set/version them before M4 economy tuning, using the retained contract and relative-boost diagnostics in `M3_PLAN.md`. No prestige remote, button or live reset is enabled in M3.

## Automated evidence

| Check | Result | Environment / limit |
|---|---|---|
| `review/m3/run_checks.py` | **16/16 groups PASS** | Lua 5.1 translated source with the fake engine; gradual and FTZ + modeled Windows formatting modes |
| Unit tests | **123/123, 11 suites PASS** | Same harness and native Luau CLI 0.745 |
| Historical gameplay probes | **75/75 PASS** | Same harness and native Luau |
| M2.1 stat integration probes | **43/43 PASS** | Same harness and native Luau |
| Persistence integration probes | **56/56 PASS** | Same harness and native Luau; simulated store/scheduler failures |
| Unpublished-memory path | **PASS** | Native/harness fake engine, no real Studio DataStore |
| First-time client traffic | **161 messages identical** | Compared with merged M2 `2279623` |
| Mutation controls | **6/6 detected** | Broken locks, failed-load defaulting, omitted stage, damaged-record defaulting and missing release |
| Native compilation | **34/34 source files PASS** | Luau CLI 0.745 |
| Adapted strict analysis | **0 TypeErrors** | Core services copied to a temporary tree with static require paths and Roblox engine globals stubbed as `any`; this does not replace Studio Script Analysis |

Harness corrections are limited to supporting dense journal arrays in the fake JSON round-trip, native-CLI global injection for the existing stat probe, and a timeout for each M2.1 verification child. They do not suppress assertions. No observed Studio result was changed or inferred from these checks.

Package verification (`tools/m3/check_package.py`) also passes: deterministic generation and independent payload decoding; **69/69 installer safety/behavior cases** against the fake engine; the actual parity checker text on the installed result reports **34/34 scripts, 6/6 remotes, 0 extras**. A changed-source control fails parity, and a disabled extra QA helper also fails parity. Rendering with the M2 defaults reproduces the frozen M2 installer byte for byte. This is offline package evidence; Studio installation/parity is still pending. See `tools/m3/README.md`.

## Outstanding before M4

1. Review the M3 implementation and the M2.1 dependency; merge only after producer approval.
2. Prepare/review the real-Studio controlled-failure/delayed-release test adapter, then run the focused private DataStore checkpoint. Save/rejoin, autosave/release and controlled failure results are all **pending**; producer attestations for older milestones do not cover this revision.
3. Record/version initial prestige eligibility/gain choices before M4 tuning. M4.1 owns the playable reset and hero-level behavior.
