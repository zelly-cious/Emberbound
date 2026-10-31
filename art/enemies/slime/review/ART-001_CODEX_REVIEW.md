# ART-001 Slime V1 — Independent Review by Codex (preserved evidence)

**Game:** Tap a Monster (internal codename Emberbound)
**Reviewed:** PR #2, branch `feature/art-slime-v1`, commit `bbca679999c829d986f61a422c14d9d606fa015c` (base `main` at `730218a`)
**Reviewer:** OpenAI Codex, read-only. This is the independent review the producer left open after Claude's internal review.
**Status:** the review text below is reproduced exactly as delivered (plain text, unedited). Line numbers refer to `bbca679`. The resolution of each finding is in [`ART-001_CORRECTIONS_REPORT.md`](ART-001_CORRECTIONS_REPORT.md), section 8.

---

```text
Verdict: CONDITIONAL PASS. PR #2 at bbca679999c829d986f61a422c14d9d606fa015c is ready for controlled Studio validation in Edit mode. It is not ready to merge.

I reviewed all 13 changed files against 730218a, including the corrections since 44a267b. No Critical or High findings. No repository code was modified; no commits, pushes, PR actions, or Roblox Studio tests were performed.

The confirmed findings are:

1. Medium — The Edit-only guards permit paused Play sessions.

   Affected locations:

   - SlimePreview.luau, isPlaytestRunning / guardEditMode, lines 115–122
   - build_installer.py, installer template, lines 76–79
   - InstallSlimeV1.luau, lines 1604–1607

   Trigger: Pause a Studio playtest, then invoke the preview or installer from the server Command Bar.

   Impact: Both guards accept this state because IsRunning() returns false while paused. Preview creation and installation can proceed despite the promised refusal. Roblox documents this distinction between paused simulation and Edit mode. API documentation

   Minimal fix: Require RunService:IsEdit() explicitly in these Command Bar utilities, then regenerate the installer. Extend the simulated-state coverage to include paused Play.

   Confirmed through source inspection, documented API semantics, and offline simulation—not Studio execution.

2. Low — The new regression check cannot preserve an existing preview when a building guard regresses.

   Location: SlimePreview.luau, check(), lines 823–867.

   Trigger: With a preview already showing, run check() against an in-memory mutation removing only show()’s guard.

   Impact: show() destroys the original preview. Cleanup deletes its replacement but cannot restore the destroyed original. I reproduced this; the check correctly reports failure but leaves the existing preview lost.

   Minimal fix: Preserve the existing preview outside the negative test’s working area and restore it through guaranteed cleanup.

   Normal cleanup with the current guards intact passed offline.

3. Low — The simulated-Play check misses changes to camera Focus.

   Location: SlimePreview.luau, check(), lines 818–821 and 859–863.

   Trigger: An in-memory mutation changes Camera.Focus immediately before gameplayCamera() calls its guard.

   Impact: The guard still raises the expected error, and check() reports ALL 18 CHECKS PASSED. It compares CFrame and field of view, but omits Focus.

   Minimal fix: Include camera.Focus ~= focusBefore in cameraMoved.

   This is a confirmed regression-test coverage defect; current normal camera restoration passed.

4. Low — T11 is simultaneously optional and mandatory in the current documentation.

   Locations: ART-001_SLIME_V1.md, section 5, lines 158 and 184, versus the handoff’s mandatory gate, line 172.

   Trigger/impact: A tester follows the test table or report template and skips T11 despite the producer’s mandatory T1–T11 requirement.

   Minimal fix: Remove “optional” from the T11 instructions and template.

My assessment of the previous corrections is:

Item	Independent assessment

Gloss seating	Resolved. Approved dimensions and depth are present. Dense sampling reproduced rim seating of −0.005527 studs and cap relief of 0.082802 studs, per unit of scale. Original geometry correctly fails the new check.
Installer parity tooling	Resolved. Byte comparison, hashes, regeneration comparison, and same-length-edit rejection work.
Original documentation inaccuracies	Resolved for the reported heights, output labels, hashes, and placement wording. The separate T11 inconsistency remains.
Missing gameplayCamera() guard	Original omission resolved. Running-Play refusal works offline; paused-Play coverage remains incomplete as finding 1 describes.
FaceAnchor rename	Resolved and scoped correctly. Root contains Center, Top, and FaceAnchor; the eight-part Face folder remains. Historical references are appropriately identified.


The hook remains module-local, and normal execution restores it after the simulated commands. The new seating check passes current geometry and rejects the original gloss values. The simulated-Play check has the limitations above.

I independently executed these checks using Python 3.12.14:

Command	Exit	Actual result

python3 art/enemies/slime/source/build_installer.py	0	PARITY VERIFIED: all three embedded sources are byte-identical to the repository files
python3 art/enemies/slime/source/build_installer.py --self-test	0	All eight edits rejected; SELF-TEST PASSED
sha256sum -c art/enemies/slime/source/SOURCE_SHA256.txt	0	All three module paths returned OK


Additional independent results:

- All 13 snapshot files, including the PNG, matched their Git blob hashes.
- An on-disk, same-length leafRoll = 25 → 26 edit returned exit 1, despite matching lengths.
- Regeneration was deterministic. Paths containing spaces and Unicode worked from another working directory. CRLF input was rejected as documented. Native Windows execution was not performed.
- Built the official Luau 0.700 compiler/VM with an audit driver outside the repository. All three modules and the installer compiled. Invalid syntax correctly failed with exit 1.
- A newly written mock-engine harness reproduced 18/18 passing checks, normal preview cleanup/camera restoration, and installer fresh/refuse/replace/running-Play behavior.
- Verified palette values, 15 visible parts plus Root, 10 meshes, 33 descendants, and unchanged geometry proportions. Gloss sampling covered scales 0.1, 0.5, 1, 1.75, 3, and 10.

The mock’s ScaleTo pass establishes only behavior under that mock. Roblox-aware strict analysis was not run; luau-analyze and selene were unavailable. Compilation does not establish Studio type safety.

Isolation is intact: all 13 PR files are additions, existing gameplay files are unchanged, and existing scripts do not require the art modules. The pivot/front contract and visual-part interface fit the documented future ArenaView integration. I found no additional confirmed security, external-asset, networking, or per-frame performance defect. The review documents correctly classify Claude’s review as internal.

Studio validation still needs T1–T11 and Script Analysis, particularly:

- Real ScaleTo/SpecialMesh.Scale behavior.
- Gloss and eye seating, smile seams, shadow shimmer, lighting, and materials.
- Phone and low-quality readability; cheek contrast remains the approved deferred observation.
- Installer paste acceptance, replacement/cache behavior, and camera restoration across Command Bar entries.
- Running and paused Play refusal, plus unchanged existing gameplay.

Proceed with Studio validation in confirmed Edit mode, keeping the asset frozen. Merge should wait for Studio evidence, disposition of these findings, and the existing branch-update/merge gates. Gameplay integration remains a separate change.
```
