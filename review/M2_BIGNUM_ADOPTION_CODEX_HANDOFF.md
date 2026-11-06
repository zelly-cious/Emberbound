# Codex review handoff — M2 round 4 BigNum adoption (release package)

Paste the block below into Codex. It is a **read-only** review: do not edit, commit, push, merge or approve PR #1.

---

Review branch `feature/m2-bignum-adoption-round4` of `zelly-cious/Emberbound`. It adopts the reviewed BigNum DEFECT-001/001B candidate `9a988c9254e07ac50dcf32fe4b55ba975613390d` into the Milestone 2 release package (`SOURCE_HASHES.txt` round 4).

**Context:**
- You reviewed the candidate as **PASS WITH RISKS**, and the historical QA evidence waiver as **ACCEPT WITH RISKS**.
- The QA report is `review/M2_STUDIO_QA_RESULTS.md`, byte-identical to QA branch commit `ae861bd`. Its R-9 lists the work this revision does.

Read, in order:
1. `AGENTS.md`, for the review rules. Its "current task" text predates this revision.
2. `review/M2_BIGNUM_ADOPTION_ROUND4.md`: what changed, the verification, and the risks.
3. `review/M2_BIGNUM_ADOPTION_ROUND4_RESULTS.txt`: the raw output of the executed checks.

**Branch structure:**
- `9a988c9` (candidate)
- `808e167`: merge of the installer branch `bceecb6`
- `5bcc940`: manifest, guide and docs
- `d2e6381`: installer v1.2.0
- later commits: installer docs, the package checker, this report and the results log

Useful diffs:
- `git diff 9a988c9 HEAD -- src` must be empty.
- `git diff 9a988c9 HEAD -- SOURCE_HASHES.txt M2_STUDIO_REGRESSION_GUIDE.md review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`
- `git diff bceecb6 HEAD -- tools/m2`
- `git diff e9d878d HEAD -- src` shows the two adopted files only.

**Verify, citing file and line:**
1. **Source pin and integrity.** `src/` equals `9a988c9`, and only `BigNum.luau` and `BigNumTests.luau` differ from round 3 (`e9d878d`). Round 4 of `SOURCE_HASHES.txt` lists exactly the 24 SHA-256 values of `9a988c9`. Rounds 1–3 keep their hash lines byte for byte, and only the round 3 heading label changed (current → historical, the round 2 precedent).
2. **Parity expectations.** Appendix A (bytes, lines, Adler-32, SHA-256, links) and the Appendix B checker table equal the values computed from `9a988c9`. The Appendix B **checker logic** is unchanged apart from the two data rows (`git diff 2b832d2 HEAD -- M2_STUDIO_REGRESSION_GUIDE.md`).
3. **67-test expectation.** T-1 (31 + 4 + 5 + 7 + 3 + 7 + 10 = 67), T-2 (`1 FAILED, 67 passed`), the allowed-messages table, the template, `M2_REVIEW_GUIDE.md` S0, `INSTALL_INSTRUCTIONS.md` §8 and `README.md` agree. No *current* text still says 61.
4. **Installer v1.2.0.**
   - Run `python3 tools/m2/generate_installer.py --check` and `python3 tools/m2/tests/run_tests.py`.
   - Confirm the generated `InstallM2.lua` differs from v1.1.0 (`bceecb6`) only in the header comment, `INSTALLER_VERSION`, `FROZEN_COMMIT`, FILES[1] and FILES[12]. Confirm the installer logic is byte-identical.
   - Confirm `INSTALLER_MANIFEST.txt` records the right SHA-256 and size.
   - Confirm the download link in `INSTALL_INSTRUCTIONS.md` is pinned to a commit holding those exact bytes, and the Appendix B link to a guide holding the round 4 values.
   - Compile `InstallM2.lua` with `luau-compile` if you can.
5. **Generator trust-model change (risk K-3).** `read_manifest` now reads round 4 from `HEAD` because round 4 is recorded after the source commit. Assess the ancestor and heading checks. Could a later commit make the generator embed sources that do not match the reviewed candidate?
6. **Test changes.**
   - The re-scoped repository checks in `run_tests.py` still prevent gameplay changes and manifest-history rewrites.
   - The one `installer_tests.lua` change is the same mutation as before, read from the payload instead of hard-coded.
7. **Package checker.**
   - Run `python3 tools/m2/tests/check_release_package.py`.
   - Review its offline execution of the guide's real Appendix B checker text: the 24/24 PASS, and the two 22/24 FAIL negative controls. It rewrites only `name += 1` before translation.
   - Say whether any check is vacuous.
8. **Unit tests.** Run them natively if you can: the 67 tests via `review/offline-harness/run.sh unit <luau>`, plus the four floating-point modes. Report the historical probe count natively (expected 75/75 gradual and 74/75 FTZ, per your earlier review). Do not accept the translated harness's 75/75 FTZ as a native result.
9. **Historical records.**
   - Rounds 1–3, `review/DEFECT-001_REPORT.md`, the round 1/2 review files and the QA report (`ae861bd`) are preserved.
   - `review/DEFECT-001B_REPORT.md` only gained one status row.
10. **Risks K-1 to K-9** in the adoption report: confirm they are stated accurately, and identify any release blocker not listed.

**Report format:**
- Classify findings as confirmed defects, risks that need Roblox Studio, or optional improvements.
- For each, give severity (Critical/High/Medium/Low), evidence, a minimal trigger and the least disruptive fix.
- Distinguish what you executed from what you only read. Do not fabricate Studio or engine output.
- End with **PASS**, **PASS WITH RISKS** or **FAIL** for the adoption revision. Separately, say whether Studio verification of the installer v1.2.0 package path (adoption report §2.3) is required before PR #1 can be considered.

Do not approve merging, mark Milestone 2 complete, or start Milestone 2.1.
