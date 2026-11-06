# Emberbound Milestone 3 kickoff

Planning baseline is the released Milestone 2: Round 4 with its [Studio QA addendum](review/M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md), merged into `main` at `227962341facb26ddc6eb074ca7e49018dfc7acb` (PR #1). This branch is merged with that `main`, so its diff contains only M3 planning. Keep it aligned before opening an implementation PR.

## Recorded requirements and dependencies

- The [M2 requirements](M2_REQUIREMENTS.md#known-gaps-against-the-roadmaps-m2-list-reported-not-fixed) assign M3 a versioned player profile with currencies, levels and a transaction log. They also assign currency kinds and rules, and the transaction sequence of validation, a single non-yielding mutation, marking the profile dirty and replying.
- [Decision 7](DECISIONS.md) assigns server-validated active gameplay tracking to M3. Include active seconds in the profile and update it from server-accepted gameplay activity. The later trading unlock consumes this record for its 30-minute active-play requirement. Confirm how accepted actions earn time and how idle gaps are capped before implementing the counter.
- [Decision 9](DECISIONS.md) requires fixing and testing BigNum parsing before introducing an untrusted numerical input path, including persisted values if M3 reads them through this parser. Cover the out-of-range decimal in [M2 requirements](M2_REQUIREMENTS.md), malformed values, valid boundaries and supported round trips. Keep Decision 10's ratio constraint in force if any proposed M3 work broadens its use.
- Decision 1 approves M2.1 StatService after acceptance of the M2 audit. Confirm its sequencing separately from M3.
- Use the approved Master Spec to confirm the full M3 scope, the first persistence slice, the transaction log and currency rules, save and load behavior, session ownership and migration policy. The repository records the requirements above and references the Master Spec.

## Proposed first implementation slice

1. Reproduce the BigNum parser boundary case against the accepted baseline and add a regression test with the parser fix.
2. Define a versioned profile and validation contract for the approved fields. Test new profiles, older versions, invalid or out-of-range stored values and round trips before connecting persistence.
3. Add the active-seconds counter at the approved server action entry points. Cover player isolation, idle and disconnect behavior, and rejected or replayed requests. Keep the existing server-authoritative combat and Gold invariants in the acceptance tests.
4. For the first persistence slice, test load failures, overlapping sessions, save retries and shutdown. Verify that a load failure cannot replace an existing profile with defaults. Use an isolated Studio test environment for persistence verification.

Implementation starts after the M2 release baseline, M2.1 sequencing and M3 scope are confirmed.

## Kickoff status (7 Nov 2026)

| Item | Status |
|---|---|
| M2 release baseline | **Done:** `main` at `2279623`, the Round 4 package. |
| M2.1 StatService (decision 1) | **In progress:** draft PR #3, `feature/m2.1-statservice` at `2771db1`.<br>• UpgradeService reports the base tap damage, and StatService combines modifiers by source and applies the result through `CombatService.SetTapDamage`.<br>• Offline: 79/79 tests and 75/75 probes; client traffic is byte-identical to `main`.<br>• Still needed: Studio checks and review. |
| Approved Master Spec, M3 section | **Not in the repository.** The repository cites it but does not contain it; `M2_REQUIREMENTS.md` references only its "M3 items 2, 4, 7". **Needed from the producer** before the scope below is fixed. |

### Proposed sequencing

1. **Merge M2.1 before the profile and persistence work.**
   - A loaded profile restores the upgrade levels, and StatService then derives tap damage from them.
   - Building persistence on M2.1 avoids writing the load path twice.
   - StatService state is derived, so it is not saved.
2. **The BigNum parser fix (decision 9) is the first M3 implementation task.**
   - It is a small, self-contained change, and it clears the gate for any untrusted stored value.
   - It changes `BigNum.luau` and `BigNumTests.luau`, the files adopted in Round 4. So it needs its own reviewed change and a new source manifest round with parity values and installer payload; this can be combined with the M2.1 package round.
   - It touches different files from M2.1, so the two can be reviewed in parallel.
3. **Then the profile contract (slice step 2), the active-seconds counter (step 3) and the first persistence slice (step 4),** within the scope the producer confirms.

### Scope decisions to settle before implementation

1. **Full M3 scope:** the Master Spec's M3 item list, and which items are in the first slice.
2. **Persistence in the first slice:**
   - whether DataStore saving is included;
   - the session-ownership rule for overlapping servers;
   - load-failure behaviour (never overwrite a profile with defaults);
   - autosave interval and shutdown save.
3. **Profile fields and BigNum storage format:** canonical text read back through `BigNum.parse` (then decision 9 applies directly) or structured fields checked with `BigNum.isValid`.
4. **Transaction log:**
   - which events it records;
   - its purpose (audit, or idempotent replay protection);
   - size cap and retention;
   - whether it lives inside the profile or in a separate store.
5. **Currency kinds and rules:** BigNum versus whole-number kinds, and limits per kind. Whether M3 only defines the kinds; Gem income is M6 and Crowns are M8.
6. **Active seconds (decision 7):**
   - which server-accepted actions earn time;
   - the idle cap after the last accepted action;
   - disconnect and rejoin behaviour;
   - how replayed or rate-limited requests are treated.
7. **Migration policy:**
   - `schemaVersion` steps;
   - forward-only migrations;
   - what happens to a profile with a newer version than the server.
8. **Studio test environment for persistence:** DataStores need a published (private) place with Studio API access. The M2 installer refuses published places, so M3 testing needs its own install path.

