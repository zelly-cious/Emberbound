# ART-001 Slime V1 — Independent Review (preserved evidence)

**Game:** Tap a Monster (internal codename Emberbound)
**Reviewed:** PR #2, branch `feature/art-slime-v1`, commit `44a267beae43938fbd960b1106c540668c3592fc` (base `main` at `730218a`)
**Review type:** read-only code and geometry audit, 2026-11-01. No code was changed during the review, and no Roblox Studio tests were run.
**Status:** this is the review as delivered. Line numbers refer to the audited commit, not to later commits. The resolution of each finding is in [`ART-001_CORRECTIONS_REPORT.md`](ART-001_CORRECTIONS_REPORT.md).

## 1. Verdict: CONDITIONAL PASS

No Critical, High or Medium defects. The asset is correctly isolated, the Roblox API usage looks right, and the installer's embedded sources are byte-identical to the repository. The conditions are four Low fixes (one geometry, three docs/tooling) and the Studio tests.

## 2–4. Findings, locations and minimal fixes

**Low 1 — Gloss rim lifts off the body at both ends** (confirmed by offline geometry)
- `SlimeModelFactory.luau` line 222 (`glossDepth = -0.1`), placed at line 326.
- At scale 1, about 136° of the gloss outline sits outside the Core. The worst gap is 0.034 studs, and it grows with scale (0.1 at scale 3). Up close (T4) a thin lip may show; at gameplay distance it is under a pixel. The eyes lift by 0.006 studs, which is negligible.
- Fix: set `glossDepth = -0.14`. That seats the rim and keeps a 0.04 cap. Optionally set `eyeDepth = -0.13`. Then regenerate the installer, `EXPECTED_LENGTHS` and the SHA-256 values in the docs.
- Doc impact: handoff line 52 and ART-001 line 86 say the details "sit flush". That is not true at the gloss ends.

**Low 2 — The installer's "(matches)" check doesn't prove repo parity**
- `InstallSlimeV1.luau` lines 1463 and 1469–1473. The check compares `module.Source` with the same string it just assigned. Only `EXPECTED_LENGTHS` (lines 1400–1404) ties it to the repo.
- Trigger: a same-length edit to a `src/` file that isn't copied into the installer would still print `(matches)`. The header (line 15) says "Generated from the repository files", but no generator is committed.
- Fix: commit the generator or a parity script, or embed a checksum computed in Luau. Reword ART-001 line 28 and handoff line 53.

**Low 3 — Height figures in the docs are bounding-box values**
- The true visual height is 5.62 studs. "About 5.8" (ART-001 line 72, README line 35, ART_DIRECTION line 65) is the part-box height, which is what `check()` measures (SlimePreview lines 251–258).
- The Milestone 1 slime is actually about 6.16 tall to the leaf tip (ArenaView lines 302–307) and its puddle is 7.2 wide (line 254). ART_DIRECTION line 90 says "6 wide, 5.9 tall".
- Nit: T1 lines start with `[SlimePreview] PASS`, not `PASS`.
- Fix: wording only. The framing is still fine.

**Low 4 — `gameplayCamera()` isn't Edit-mode guarded**
- `SlimePreview.luau` lines 291–293. During Play in the client context, it moves the live camera to about y=306, looking at nothing. It builds nothing, but it contradicts handoff line 18 ("refuses to run during Play").
- Fix: call `guardEditMode()` first.

**Optional**
- Root has an attachment named `Face` (line 408) and the model has a folder named `Face`. `FindFirstChild("Face", true)` returns the attachment. Decide this before the naming becomes standard.
- Blush versus body luminance contrast is only 1.18:1, so the cheeks are told apart by hue alone. They may vanish for red-green colour-blind players. They are decorative, so this is not blocking.

## 5. Checks run independently
- Cloned the branch at `44a267b`. The diff against `730218a` shows 9 files, all added; nothing was modified or deleted.
- No other `src/` file references the new modules.
- PR #1 is not an ancestor and shares no paths with this PR. The M2 `TestRunner` loads only `*Tests` modules.
- Installer parity: extracted the three embedded strings. Each is byte-identical to its source file, matches the documented SHA-256 and matches `EXPECTED_LENGTHS`. No CRs, no non-ASCII bytes and no delimiter collisions. The installer was 51,153 bytes.
- Rebuilt the factory geometry in Python: 15 visible parts plus Root, 10 meshes, lowest point −0.35; eye shines stay inside the eye outline; eyes and cheeks don't overlap; the leaf tip sits inside the stem; the mouth strokes overlap at the centre, as intended; the phone estimate reproduces at 33.1 px (eyes) and 5.5 px (smile).
- All derived palette hex values reproduce exactly.
- No `loadstring`, `HttpService`, remotes, DataStores, connections or asset IDs.
- ArenaView compatibility: taps use screen-wide `UserInputService` (CombatClient lines 129–137), so `CanQuery=false` is safe; the pivot, the −Z front and the camera numbers match ArenaView lines 20–24 and 350–351. At integration, use `PivotTo(basePivot)`; `WorldPivot` (ArenaView line 311) is ignored once `PrimaryPart` is set.
- Not run during the review: Luau compile, strict type check and selene (the tools could not be executed in the review environment).

## 6. Studio tests still required
- T1–T11 as written, especially the T1 `ScaleTo` vs `SpecialMesh.Scale` check (Roblox's documentation says Sphere meshes scale with the part's Size, but the `ScaleTo` documentation does not mention meshes) and Script Analysis showing no strict errors.
- T9: the camera restore depends on the Command Bar caching the module between entries.
- Replace mode: close the module tabs first, because Team Create or open drafts may not accept a `.Source` write.
- Watch for GroundShadow shimmer (it sits 0.02 above the floor) and a seam where the two smile strokes overlap, in T7 and T8.
- Integration note: during ArenaView's defeat fade (lines 406–408), hidden inner parts will show through briefly. If T1 fails, a cheaper fallback than a plain-sphere body is to reset every `SpecialMesh.Scale` to `Vector3.one` after each `ScaleTo`.

## 7. Readiness
Ready for Studio validation: yes. Ready to merge: not yet — after T1–T11 and Script Analysis pass and Lows 1–4 are fixed, then (per the handoff) after PR #1 merges and this branch is rebased.
