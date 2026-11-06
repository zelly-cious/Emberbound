# Emberbound Milestone 2 Round 4 Studio release QA

This addendum records the installer-path run separately from the [historical candidate QA results](M2_STUDIO_QA_RESULTS.md). Use the [Round 4 regression guide](../M2_STUDIO_REGRESSION_GUIDE.md) and [QA results template](M2_STUDIO_QA_RESULTS_TEMPLATE.md) for the test IDs. The historical record and its evidence waiver remain applicable to the candidate run.

| Setup | Record |
|---|---|
| Round 4 packaging baseline | `bffef4f85f4b3b3a8187fce98a797acf4bd55573` |
| Source pin | `9a988c9254e07ac50dcf32fe4b55ba975613390d`, as recorded in the [installer manifest](../tools/m2/INSTALLER_MANIFEST.txt) |
| Installer | `tools/m2/InstallM2.lua` v1.2.0 |
| Tester | Project owner, using Roblox Studio |
| Date, Studio version, OS and place filename | Unrecorded for this run |

| Check | Result and evidence |
|---|---|
| Installer path (P-1/P-2 replacement) | The owner used installer v1.2.0 in Studio. The installed place passed parity after reopening. Separate installer check-mode, PlaceId guard and undo observations are unrecorded in this addendum. |
| Source parity after reopening | **PASS** — 24/24 scripts, 6/6 remotes, 0 extra scripts. This records the post-reopen check. The historical P-3 result remains as recorded for the candidate run. |
| T-1 unit tests | **PASS** — 67/67 in Studio. This addendum records the total. |
| M1-3 initial sync | **PASS** — the owner ran `ClientReady:FireServer()` and shared the three client Output lines below. |
| M1-2 fixed camera | The fixed camera behaved as expected in position, aim and FOV. The exact `Focus` discrepancy retains its **strict FAIL** and the producer's **Low-severity, nonblocking exception**. See F-1 in the historical report. |
| Remaining checklist | The owner said they went through the remaining checks offline. This is producer attestation. Individual results, measurements and logs for this run were unrecorded. Existing historical results, optional-test dispositions and the evidence waiver retain their original scope. |

```text
[QA] Currency Gold=0
[QA] Upgrade Sync level=1 value=1 nextCost=5
[QA] Combat Sync stage=1 hp=10/10 tap=1 dmg=nil goldAwarded=nil
```

## Release decision

This updates the Studio status in the [Round 4 adoption report](M2_BIGNUM_ADOPTION_ROUND4.md), the [final review handoff](M2_BIGNUM_ADOPTION_FINAL_CODEX_HANDOFF.md) and the [installer instructions](../tools/m2/INSTALL_INSTRUCTIONS.md) for the observed installer, parity and test run. The project owner executed the Studio checks. The review of this record reconciled the supplied evidence with the Round 4 manifest and guide.

PR #1 still targets `main` from `feature/m2-tap-upgrades-bignum` at `2b832d2`, which precedes Round 4. The final independent adoption verdict for the ADOPT-01 through ADOPT-03 corrections and producer merge approval remain outstanding in the repository record. Review the Round 4 package and decide which release head PR #1 should carry before merging. Milestone 2 remains open pending those decisions.
