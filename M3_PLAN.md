# Emberbound Milestone 3 implementation

Implementation baseline is the released Milestone 2 Round 4 at `227962341facb26ddc6eb074ca7e49018dfc7acb` (PR #1), with its [Studio QA addendum](review/M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md). This branch contains M2.1 integration and the M3 foundations at `23785544f846817c5d722f69d5e81b11348df46f`. Review and the focused private Studio checkpoint remain pending. See [implementation results](review/m3/M3_IMPLEMENTATION_RESULTS.md) and the [M3 installer](tools/m3/README.md). The producer's milestone outline is captured in [ROADMAP.md](ROADMAP.md).

## Recorded requirements and dependencies

- The [M2 requirements](M2_REQUIREMENTS.md#known-gaps-against-the-roadmaps-m2-list-reported-not-fixed) assign M3 a versioned player profile with currencies, levels and a transaction log. They also assign currency kinds and rules, and the transaction sequence of validation, a single non-yielding mutation, marking the profile dirty and replying.
- [Decision 7](DECISIONS.md) assigns server-validated active gameplay tracking to M3. Include active seconds in the profile and update it from server-accepted gameplay activity. The later trading unlock consumes this record for its 30-minute active-play requirement. Accepted taps and successful purchases now extend a ten-second idle window; see the adopted parameters below.
- [Decision 9](DECISIONS.md) requires fixing and testing BigNum parsing before introducing an untrusted numerical input path, including persisted values if M3 reads them through this parser. Cover the out-of-range decimal in [M2 requirements](M2_REQUIREMENTS.md), malformed values, valid boundaries and supported round trips. Keep Decision 10's ratio constraint in force if any proposed M3 work broadens its use.
- Decision 1 assigns M2.1 StatService before M3's loaded stats and M4 heroes. The [roadmap revision](ROADMAP.md) adds basic prestige in M4.1 and requires its schema/reset contract during M3, before M4 economy tuning.
- Use the approved Master Spec to confirm the full M3 scope, the first persistence slice, the transaction log and currency rules, save and load behavior, session ownership and migration policy. The repository records the requirements above and references the Master Spec.

## Implementation sequence

1. Reproduce the BigNum parser boundary case against the accepted baseline and add a regression test with the parser fix.
2. Define a versioned profile and validation contract for the approved fields. Test new profiles, older versions, invalid or out-of-range stored values and round trips before connecting persistence.
3. Add the active-seconds counter at the approved server action entry points. Cover player isolation, idle and disconnect behavior, and rejected or replayed requests. Keep the existing server-authoritative combat and Gold invariants in the acceptance tests.
4. For the first persistence slice, test load failures, overlapping sessions, save retries and shutdown. Verify that a load failure cannot replace an existing profile with defaults. Use an isolated Studio test environment for persistence verification.

M3 owns saving, versioned profiles, session handling, currency wallets, interrupted-transaction recovery and migrations. Decision 7 adds the active-play counter. Define the prestige record, lifetime/run highest-cleared stage records and recoverable reset operation during M3. The [roadmap contract](ROADMAP.md#prestige-contract-before-m4-tuning) resets hero levels while retaining ownership, rarity and duplicate progress, and selects a permanent damage multiplier as the reward. Follow the focused persistence checkpoint before M4 in the [roadmap](ROADMAP.md).

## Current implementation status

| Item | Status |
|---|---|
| M2 release baseline | **Done:** `main` at `2279623`, the Round 4 package. |
| M2.1 StatService (decision 1) | **Draft PR #3** at `39a5357`, with source identical to reviewed `9a3ad1e`.<br>• Offline: 14/14 checks, 82 tests, 75 historical probes and 43 integration probes.<br>• Studio checks 1-4 are recorded as producer-attested passes in `review/m2.1/M2_1_STUDIO_QA_RESULTS.md`.<br>• Helper cleanup is scheduled for final release parity. Packaging and merge review remain. |
| BigNum parser fix (decision 9, R2-1) | **Done on this branch.** `BigNum.parse` checks the range against the decimal digits as written, before rounding. So `"1"` + 23 zeros + `"e9007199254740969"` (= 10^(2^53)) and every other decimal at or above 10^(2^53) read as nil. A value within one rounding step of the top can also read as nil; that is the safe direction. Offline only:<br>• 3 new BigNum tests, 70/70 in all four floating-point modes;<br>• both R2-1 tests fail against the `main` parser (negative control);<br>• 75/75 probes;<br>• 4,007 canonical and in-range strings parse identically before and after the fix.<br>Studio coverage joins the focused M3 persistence checkpoint and final launch regression as relevant. |
| M3 foundations | **Implemented; review and Studio checkpoint pending.** Source `2378554`.<br>• Schema v2 and v1 migration; session locks/release retry; typed wallets; journal/recovery; highest-cleared stage records; prestige data contract; active-time counter.<br>• Offline: 16/16 groups, 123/123 tests in 11 suites, 75 historical probes, 43 stat integration probes and 56 persistence probes. These also pass in native Luau 0.745.<br>• The pending-release/same-server-rejoin regression is fixed: the old 100-Gold final snapshot is preserved and restored on a later safe rejoin.<br>• Exact-source M3 installer, round 5 manifest and parity checker: `tools/m3/`.<br>• Manual Studio results remain pending; older attestations do not cover this revision. |
| Producer roadmap | **Milestone outline received.** [ROADMAP.md](ROADMAP.md) assigns M3 saving/recovery work, M2.1 stat calculation, M4.1 basic prestige, M6.1 Gem/reward claims and M13 the wider event framework. The proposed launch cutoff and expansion sequence are recorded there. |

### Integration order

1. **Build M3 on M2.1; merge M2.1 before merging M3.**
   - A loaded profile restores the upgrade levels, and StatService then derives tap damage from them.
   - Building persistence on M2.1 avoids writing the load path twice.
   - StatService state is derived, so it is not saved.
2. **The BigNum parser fix (decision 9) is the first M3 implementation task.**
   - It is a small, self-contained change, and it clears the gate for any untrusted stored value.
   - It changes `BigNum.luau` and `BigNumTests.luau`, the files adopted in Round 4. So it needs its own reviewed change and a new source manifest round with parity values and installer payload; this can be combined with the M2.1 package round.
   - It touches different files from M2.1, so the two can be reviewed in parallel.
3. **Review the implemented foundations** in `review/m3/M3_IMPLEMENTATION_RESULTS.md`. Keep the M3 draft based on M2.1 while PR #3 remains unmerged; neither draft implies merge approval.
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
- **Adopted implementation parameters:**
  - Gems/Crowns: whole values capped at 9,007,199,254,740,991, with gameplay activation in their owning milestones.
  - Journal: 50 completed operations plus one separately retained pending operation; permanent applied high-water ID. Persist a prepared external operation before acknowledging it. Load recovery uses saved payloads inside UpdateAsync.
  - Activity: accepted taps and successful purchases extend a ten-second window; joining, syncing, rejected actions and disconnected time earn no credit. Idle time after the window is excluded.
  - Schema v2 preserves lifetime/run highest cleared stages, claims and canonical BigNum prestige metadata. V1 defaults/migrates forward; malformed v2 and newer saves fail safely.
  - Final-save errors keep the snapshot and retry; a new session cannot steal a live same-job lock or pass the local pending-release guard.
- **Remaining acceptance work:** review; prepare/review the real-Studio fault-injection adapter; perform the focused private persistence checkpoint; record/version initial prestige threshold/gain decisions before M4 tuning. Automatic checks cover local/fake-engine paths, not actual Studio timing.

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
9. **Prestige contract:** implement the record/migration contract below before M4 tuning. M4.1 implements the mechanic before M5/M6 balancing.

### Prestige and stage schema contract

| Field or rule | Required behavior |
|---|---|
| Current `stage` | Existing current combat stage, starting at 1. |
| `lifetimeHighestStage` | Highest stage cleared under server authority. It is retained through prestige and gates stage-milestone Gem rewards and the trading stage requirement. |
| `runHighestStage` | Highest stage cleared in the current run. It drives prestige eligibility and gain and resets to 0 on prestige. |
| Prestige record | Count, persisted run identity and `prestige.multiplier` as a canonical BigNum string, starting at `"1"` and validated as at least 1 at load. |
| Reward rule | `nextMultiplier = currentMultiplier + gain(runHighestStage)`. Set the numeric threshold/gain curve before M4 tuning. Apply once to tap damage and automatic hero damage through StatService. |
| Hero levels | Reset to each hero's configured starting level. Retain ownership, identity, rarity and duplicate progress. |
| Durable reset | Snapshot `calculatedGain` as a canonical BigNum string, `gainCurveVersion`, completed run identity and its highest cleared stage in the operation before applying it. Recovery uses the recorded gain under the same operation ID. Retain pending operations until recovery finishes. |
| Milestone claims | Stable stage-milestone claim IDs survive prestige. Lifetime highest-stage eligibility is paired with those records, so a repeated run grants each milestone once per player. |
| Migration | Advance the schema version. Existing sequential v1 profiles seed cleared-stage maxima from `max(0, stage - 1)`, retain valid existing maxima/claims, and receive default prestige count 0 and stored multiplier `"1"`. |

Offline regressions must cover monotonic server-owned stage maxima, v1 migration, malformed field rejection, stable milestone claims across a reset, retained trading progress and interrupted/replayed reset operations. M4.1 adds regressions for hero-level resets and applying the multiplier once.


### Saved-gain recovery and balance acceptance

- Validate stored multiplier/gain encodings under the BigNum contract. Cover round trips beyond ordinary number range, such as a multiplier of `"1e400"`, and reject malformed or invalid values.
- Add a regression that prepares a gain under curve version A, changes the configured curve to B, then interrupts and recovers the operation. Use the saved amount once. An illustrative fixture starts at `"10"` with saved gain `"5"` and recovers to `"15"`, even when curve B would calculate `"500"`. Replaying recovery preserves that completed result and the single reset/count increment.
- Use the actual enemy HP function, currently `floor(10 * 1.18^(stage - 1))`, for gain calibration. At fixed other stats, record `relativeBoost = (M + G(s)) / M` and the approximate stage equivalent `log(relativeBoost) / log(1.18)`.
- Record early/mid/late balance samples and targets for run duration, return to the old peak and progress beyond it. The model includes the hero-level, tap-upgrade and Gold reset. M3 establishes/version-controls the initial curve and recovery payload, M4 tunes it with hero/economy progression, and M4.1 validates the loop before M5/M6 balancing.
