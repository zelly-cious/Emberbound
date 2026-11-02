# Final Codex review handoff — M2 round 4 adoption corrections (ADOPT-01 to ADOPT-03)

Paste the block below into Codex. It is a **read-only** review: do not edit, commit, push, merge or approve PR #1.

---

Re-review branch `feature/m2-bignum-adoption-round4` of `zelly-cious/Emberbound` at its current head. You reviewed `a9326f157a079633f3915976f9262907cbfed8a6` as **PASS WITH RISKS**, with three Low findings. Read `review/M2_BIGNUM_ADOPTION_ROUND4.md` section 5, then `review/M2_BIGNUM_ADOPTION_ADOPT_FIXES_RESULTS.txt`. The diff to review is `git diff a9326f1 HEAD`.

Verify:
1. **ADOPT-01.** `M2_REVIEW_GUIDE.md:69` says 67 tests. The new package check finds no current document claiming 61 tests outside a historical note, and the end-to-end regression test reinstates the old row and expects a failure.
2. **ADOPT-02.** In `tools/m2/tests/check_release_package.py`:
   - `evaluate_parity` and `evaluate_unit` require Lua exit code 0. A positive run also needs exactly one PASS verdict with 24/6/0; a negative control needs the FAIL verdict with 22/6/0 and two `content differs` lines.
   - The unit-test run goes through `run_matrix.run`, which returns the Lua exit code.
   - Run `python3 tools/m2/tests/test_verification_tools.py`. Confirm that each injected Lua error (after PASS, after FAIL, after `ALL PASSED (67 tests)`) and the non-compiling checker are rejected, and that the controls are accepted.
3. **ADOPT-03.** `generate_installer.manifest_heading_errors` is used by `run_tests.py`, `check_release_package.py` and `read_manifest`.
   - It rejects a fake `Round 5 (current)`, duplicate or unexpected headings, a current round other than round 4, and miscounted sections.
   - The end-to-end test makes both checkers exit 1 on a planted Round 5, then restores the file.
4. **Nothing else moved:**
   - `git diff 9a988c9 HEAD -- src` is empty.
   - `python3 tools/m2/generate_installer.py --check` matches, and `InstallM2.lua` SHA-256 is still `b12fa7023f25a93d2e2a80aef0042c0cf962d81a7aef84dd4ca1fd06873623d4`.
   - `review/M2_STUDIO_QA_RESULTS.md` is still byte-identical to QA commit `ae861bd`.
5. **Full suite:** run `python3 tools/m2/tests/run_tests.py` (expect 19/19) and `python3 tools/m2/tests/check_release_package.py` (expect 34/34), and natively if you can.

Report:
- confirmed defects, Studio-dependent risks and optional improvements, each with severity, evidence and the smallest fix;
- what you executed versus what you only read.

End with **PASS**, **PASS WITH RISKS** or **FAIL** for the adoption revision. Roblox Studio verification of the installer v1.2.0 package path is still outstanding (adoption report §2.3); do not fabricate it. Do not approve merging, mark Milestone 2 complete, or start Milestone 2.1.
