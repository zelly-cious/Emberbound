# Emberbound Milestone 3 kickoff

Planning baseline is Round 4 with its [Studio QA addendum](review/M2_STUDIO_QA_ROUND4_RELEASE_RESULTS.md) at `27f1ed524bc57ded9875acd1624fb93d557e91c8`. Before opening an implementation PR, align this branch with the approved, merged M2 baseline so the PR diff contains only M3 work.

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
