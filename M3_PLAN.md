# Emberbound Milestone 3 kickoff

Implementation baseline is the released Milestone 2 Round 4 at `227962341facb26ddc6eb074ca7e49018dfc7acb` (PR #1), with its [Studio QA addendum](review/M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md). This branch now contains M2.1 integration and the first M3 implementation. The producer's supplied milestone outline is captured in the proposed [roadmap](ROADMAP.md), including feature ownership and launch sequencing.

## Recorded requirements and dependencies

- The [M2 requirements](M2_REQUIREMENTS.md#known-gaps-against-the-roadmaps-m2-list-reported-not-fixed) assign M3 a versioned player profile with currencies, levels and a transaction log. They also assign currency kinds and rules, and the transaction sequence of validation, a single non-yielding mutation, marking the profile dirty and replying.
- [Decision 7](DECISIONS.md) assigns server-validated active gameplay tracking to M3. Include active seconds in the profile and update it from server-accepted gameplay activity. The later trading unlock consumes this record for its 30-minute active-play requirement. Confirm how accepted actions earn time and how idle gaps are capped before implementing the counter.
- [Decision 9](DECISIONS.md) requires fixing and testing BigNum parsing before introducing an untrusted numerical input path, including persisted values if M3 reads them through this parser. Cover the out-of-range decimal in [M2 requirements](M2_REQUIREMENTS.md), malformed values, valid boundaries and supported round trips. Keep Decision 10's ratio constraint in force if any proposed M3 work broadens its use.
- Decision 1 assigns M2.1 StatService before M3's loaded stats and M4 heroes. The [roadmap revision](ROADMAP.md) adds basic prestige in M4.1 and requires its schema/reset contract during M3, before M4 economy tuning.
- Use the approved Master Spec to confirm the full M3 scope, the first persistence slice, the transaction log and currency rules, save and load behavior, session ownership and migration policy. The repository records the requirements above and references the Master Spec.

## Proposed first implementation slice

1. Reproduce the BigNum parser boundary case against the accepted baseline and add a regression test with the parser fix.
2. Define a versioned profile and validation contract for the approved fields. Test new profiles, older versions, invalid or out-of-range stored values and round trips before connecting persistence.
3. Add the active-seconds counter at the approved server action entry points. Cover player isolation, idle and disconnect behavior, and rejected or replayed requests. Keep the existing server-authoritative combat and Gold invariants in the acceptance tests.
4. For the first persistence slice, test load failures, overlapping sessions, save retries and shutdown. Verify that a load failure cannot replace an existing profile with defaults. Use an isolated Studio test environment for persistence verification.

M3 owns saving, versioned profiles, session handling, currency wallets, interrupted-transaction recovery and migrations. Decision 7 adds the active-play counter. Define the prestige record, reset/retention policy and recoverable reset operation during M3. Follow the focused persistence checkpoint before M4 in the [roadmap](ROADMAP.md).

## Kickoff status (7 Nov 2026)

| Item | Status |
|---|---|
| M2 release baseline | **Done:** `main` at `2279623`, the Round 4 package. |
| M2.1 StatService (decision 1) | **Draft PR #3** at `39a5357`, with source identical to reviewed `9a3ad1e`.<br>• Offline: 14/14 checks, 82 tests, 75 historical probes and 43 integration probes.<br>• Studio checks 1-4 are recorded as producer-attested passes in `review/m2.1/M2_1_STUDIO_QA_RESULTS.md`.<br>• Helper cleanup is scheduled for final release parity. Packaging and merge review remain. |
| BigNum parser fix (decision 9, R2-1) | **Done on this branch.** `BigNum.parse` checks the range against the decimal digits as written, before rounding. So `"1"` + 23 zeros + `"e9007199254740969"` (= 10^(2^53)) and every other decimal at or above 10^(2^53) read as nil. A value within one rounding step of the top can also read as nil; that is the safe direction. Offline only:<br>• 3 new BigNum tests, 70/70 in all four floating-point modes;<br>• both R2-1 tests fail against the `main` parser (negative control);<br>• 75/75 probes;<br>• 4,007 canonical and in-range strings parse identically before and after the fix.<br>Studio coverage joins the focused M3 persistence checkpoint and final launch regression as relevant. |
| First persistence slice (plan steps 2 and 4) | **Implemented on this branch and under review, built on M2.1.**<br>• New modules: `ProfileSchema` (version 1 profile), `ProfileStore` (session lock, retries) and `PlayerDataService` (DataStore, autosave, shutdown). Hooks added in the Currency, Combat, Upgrade and PlayerSession services.<br>• Saved: Gold as canonical BigNum text, stage, upgrade levels and `activeSeconds`. Tap damage is re-derived through StatService, and a fresh enemy spawns on load.<br>• Offline: `review/m3/run_checks.py` 16/16: 106/106 tests in 10 suites, 75/75 historical probes, the M2.1 check set, 36/36 persistence probes, the Studio memory path, unchanged first-time client traffic and 6 mutation controls.<br>• One focused private Studio persistence checkpoint is required after M3 and before M4. Broader live and integrated gameplay checks are collected in `review/LAUNCH_QA_DEFERRED.md`. |
| Producer roadmap | **Milestone outline received.** [ROADMAP.md](ROADMAP.md) assigns M3 saving/recovery work, M2.1 stat calculation, M4.1 basic prestige, M6.1 Gem/reward claims and M13 the wider event framework. The proposed launch cutoff and expansion sequence are recorded there. |

### Proposed sequencing

1. **Merge M2.1 before the profile and persistence work.**
   - A loaded profile restores the upgrade levels, and StatService then derives tap damage from them.
   - Building persistence on M2.1 avoids writing the load path twice.
   - StatService state is derived, so it is not saved.
2. **The BigNum parser fix (decision 9) is the first M3 implementation task.**
   - It is a small, self-contained change, and it clears the gate for any untrusted stored value.
   - It changes `BigNum.luau` and `BigNumTests.luau`, the files adopted in Round 4. So it needs its own reviewed change and a new source manifest round with parity values and installer payload; this can be combined with the M2.1 package round.
   - It touches different files from M2.1, so the two can be reviewed in parallel.
3. **Complete the profile contract, active-seconds counter, interrupted-transaction recovery and pending-release fix.** Include the prestige schema, reset/retention policy and reset operation contract before M4 tuning.
4. **Run one focused persistence checkpoint before M4.** Use the real DataStore path in an isolated private Studio place. Verify save/reload, autosave/release and the controlled rejoin/failure paths. Record the source revision and result once.

### Defaults adopted for the first slice (7 Nov 2026; the producer may override)

These keep launch work moving. Each is a small, contained change if overridden.
- **Decision 2, persistence:** included.
  - One DataStore, `EmberboundProfiles`, with key `player_<UserId>`.
  - Session lock: the lock expires 300 s after the last write. A load waits up to 30 s for another server's lock. A server that loses its lock stops writing and asks the player to rejoin.
  - Autosave every 60 s. Leaving and shutdown save and release the lock.
  - A failed load never starts on defaults: the player is asked to rejoin and the record is untouched.
  - An unpublished Studio place uses in-memory saves for that test session.
- **Decision 3, profile fields and BigNum format:** canonical BigNum text, read back through the fixed `BigNum.parse` (decision 9).
- **Decision 7, migration:** a `v` field and forward-only steps. A profile with a newer version than the server is rejected with a rejoin message.
- **Remaining M3 work:**
  - the durable transaction log and interrupted-operation recovery (4);
  - currency kinds and rules for the future Gem/Crown wallets (5);
  - the server-validated active-seconds counter (6). `activeSeconds` is currently stored but has no counter;
  - fix the delayed-release/same-server-rejoin race identified in independent review of `a94f020`. A load must safely wait or refuse while the previous final save is still pending;
  - define the prestige record, run/reset identity, proposed reset/retention policy and transaction recovery contract in ROADMAP.md before M4 tuning;
  - complete the focused M3 persistence checkpoint before starting M4.

### Implementation parameters to record

1. **M3 scope:** implement the producer's saving/profile/session/wallet/recovery/migration outline and decision 7's active-play counter, as recorded in ROADMAP.md.
2. **Persistence defaults and recovery:**
   - DataStore saving is included in M3;
   - the session-ownership rule for overlapping servers;
   - load-failure behaviour (never overwrite a profile with defaults);
   - autosave interval and shutdown save.
3. **Profile fields and BigNum storage format:** canonical text read back through `BigNum.parse` (then decision 9 applies directly) or structured fields checked with `BigNum.isValid`.
4. **Transaction log:**
   - which events it records;
   - its purpose (audit, or idempotent replay protection);
   - size cap and retention;
   - whether it lives inside the profile or in a separate store.
5. **Currency kinds and rules:** BigNum Gold and bounded whole-number Gems/Crowns. Define validation and limits in M3; Gem income begins in M6 and paid Crown income in M8.
6. **Active seconds (decision 7):**
   - which server-accepted actions earn time;
   - the idle cap after the last accepted action;
   - disconnect and rejoin behaviour;
   - how replayed or rate-limited requests are treated.
7. **Migration policy:**
   - `schemaVersion` steps;
   - forward-only migrations;
   - what happens to a profile with a newer version than the server.
8. **Studio persistence checkpoint:** use a private published test place with Studio API access and a documented installation path. Test save/reload, autosave/release, delayed-save/rejoin and controlled failure recovery once before M4. See ROADMAP.md and `review/LAUNCH_QA_DEFERRED.md`.
9. **Prestige contract:** record the proposed reset/retain rules, schema defaults, operation identity and eligibility/reward configuration before M4 tuning. M4.1 implements the mechanic before M5/M6 balancing.

