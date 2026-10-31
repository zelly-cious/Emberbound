# ART-001 Review Handoff — Stylized Fantasy Slime V1

**For:** ChatGPT (technical lead / QA coordinator) and Codex (read-only code reviewer).
**Branch:** `feature/art-slime-v1`, based on `main` at `730218a`. Pull request targets `main` and must **not** be merged until the conditions in section 8 are met.
**Prepared by:** Claude (implementation). Nothing here is a Roblox Studio result unless it says so.
**Updated 2026-11-01:** the independent review of `44a267b` (CONDITIONAL PASS, four Low findings) has been addressed on this branch. See section 11, `enemies/slime/review/ART-001_CORRECTIONS_REPORT.md`, and the preserved review in `enemies/slime/review/ART-001_INDEPENDENT_REVIEW.md`.

## 1. Summary

ART-001 adds Emberbound's first stylized enemy asset, the Standard Slime V1, plus the project's art direction document. The slime is a **procedural Roblox model**: a Luau factory builds it from built-in parts. There are no meshes or saved model files. The asset is isolated: nothing in the game requires it, and the live game still shows the Milestone 1 slime from `ArenaView.luau`.

Status: Phase 2 (implementation) complete and checked offline. **Phase 3 (Roblox Studio validation) has not been run yet.**

## 2. Isolation from Milestone 1 and Milestone 2

- Branched from `main` (`730218a`, the Milestone 1 baseline). `feature/m2-tap-upgrades-bignum` (PR #1) is **not** an ancestor and was not merged in.
- Only new files are added. No existing file is modified, renamed or deleted: no gameplay script, RemoteEvent, `GameConfig`, `SOURCE_HASHES.txt`, `README.md`, `AGENTS.md`, requirement or review document.
- No path overlaps with PR #1's changes, so the two branches cannot conflict.
- The new modules never run on their own: `ReplicatedStorage/Shared/Visuals/*` are ModuleScripts nothing requires yet, and `ServerStorage/EmberDev/SlimePreview` never replicates. Its commands that build anything or move the camera (`show`, `lineup`, `gameplayCamera`, `check`) refuse to run during Play; `clear` and `help` stay available. (`gameplayCamera` gained this guard in the review corrections.)
- The Milestone 2 test runner only loads ModuleScripts named `*Tests` in `ServerScriptService/Tests`; none were added, so its 61 tests and seven suites are unaffected.

## 3. How this branch was prepared

Claude prepared the content as two commits on top of `main`:

1. `ART-001: procedural Standard Slime V1 factory and Studio preview` — the Phase 2 implementation exactly as delivered (originally on a local `art/slime-v1` branch that was never pushed).
2. `ART-001: art directory, art direction and review handoff` — moves the ART-001 document and installer into `art/enemies/slime/` (path and branch references updated only), and adds `ART_DIRECTION.md`, the slime README, the offline preview image and this handoff.

Both commits were pushed to GitHub as prepared, followed by a third commit that corrects this section. File contents can be checked against the SHA-256 values in section 4.

## 4. Verified file inventory

| File | Role | SHA-256 |
|---|---|---|
| `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau` | Official palette and colour helpers | `c2944647d9252bdf64c6416384c93895974f863d731b9ebf9da85c85b87566b0` |
| `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau` | Model source (factory) | `92aabd80ff0553124fc2f74cd50dc25a74e10eb8dec62fe8809e78e11427f110` |
| `src/ServerStorage/EmberDev/SlimePreview.luau` | Edit-mode preview and 18 automatic checks | `832c3a3892f5eea6407a48eadc69ae84f644ba705d7ee9bf4a598555ea9a8951` |
| `art/enemies/slime/source/InstallSlimeV1.luau` | Command Bar installer embedding the three modules verbatim (generated) | — |
| `art/enemies/slime/source/build_installer.py` | Generates the installer; verifies repository parity (byte-for-byte, SHA-256) | — |
| `art/enemies/slime/source/SOURCE_SHA256.txt` | SHA-256 record of the three modules | — |
| `art/enemies/slime/review/ART-001_INDEPENDENT_REVIEW.md` | The independent review of `44a267b`, preserved as delivered | — |
| `art/enemies/slime/review/ART-001_CORRECTIONS_REPORT.md` | Finding-by-finding resolution and test results | — |
| `art/enemies/slime/ART-001_SLIME_V1.md` | Specification, hierarchy, Studio tests T1–T11, performance checklist, integration plan | — |
| `art/enemies/slime/README.md` | Asset record and Roblox compatibility table | — |
| `art/enemies/slime/previews/slime-v1-offline-approximation.png` | Offline ray-traced approximation of the exact part geometry (**not** a Studio screenshot) | — |
| `art/ART_DIRECTION.md` | Art direction; labels established specs vs recommendations | — |
| `art/ART-001_REVIEW_HANDOFF.md` | This file | — |

**Not present anywhere** (repository, project workspace): Blender sources, FBX/OBJ/GLB exports, `.rbxm`/`.rbxmx` files, textures, rigs, animations, Studio screenshots. These were never created; ART-001 deliberately used Roblox-native geometry.

## 5. What was verified, and how

Done offline by Claude (evidence, not Studio results):

- All three modules and the installer were compiled and executed in the real Luau compiler and VM (embedded via the `mlua` crate) against a minimal fake Roblox engine that errors on unknown properties.
- `SlimePreview.check()` passed all 16 checks at the time (18 after the review corrections; see section 11): variants, pivot and PrimaryPart, exact hierarchy, part budget (15 visible + Root), no collisions/touch/query, one shadow caster and one transparent part, only allowed instance classes and no asset IDs, attributes and colour roles, anchor attachments, forward-facing symmetric smiling face, floor contact and height (about 5.8 studs by part bounding boxes; the visible height is 5.62), identical proportions at scale 0.5 and 2, recolouring, clear errors on bad input, `ScaleTo` mesh behaviour (fake engine only), and a phone readability estimate (eyes about 33 px, smile about 5.5 px on a 360 px tall screen).
- Extra checks: face and gloss details sit just under the body surface with a visible cap (**corrected:** this did not measure the gloss rim, whose two ends lifted up to 0.034 studs; fixed and now measured by `check()`); eye shines sit on the eyes; smile strokes cross the centre line; ball parts are uniform; nothing extends past the shadow footprint; `show`/`lineup`/`clear` touch only their own folder and the camera and restore it; the preview refuses to run during Play.
- Installer: fresh install, refusal when already installed (nothing changed), and replace mode, each with the installer's own check (**corrected:** that check only proves the installed text equals the embedded text; repository parity is now verified by `build_installer.py`).
- An approximate offline render from the gameplay camera was used to tune the skirt proportions.

**Not verified** (needs Roblox Studio or tools not available here):

- Roblox's actual rendering, lighting and materials.
- Whether `Model:ScaleTo` changes `SpecialMesh.Scale` in the real engine (Studio test T1).
- Strict-mode type checking with Roblox's type definitions (Studio Script Analysis).
- Command Bar acceptance of the 59 KB installer paste (51 KB before the review corrections; manual Method B exists as a fallback).

## 6. Studio validation (pending)

The beginner test plan is section 5 of `art/enemies/slime/ART-001_SLIME_V1.md`: installer parity, T1 automatic checks, T2 gameplay-camera look, T3 part properties, T4 orbit inspection, T5 camera reset, T6 scale and recolour lineup, T7 phone emulator, T8 low graphics, T9 cleanup, T10 gameplay unchanged, T11 Play-mode refusal. Each has PASS/FAIL criteria and the document includes a report template. **No results have been received yet.**

## 7. Instructions for Codex (read-only review)

The root `AGENTS.md` was written for the Milestone 1 audit. Keep its rules on read-only review, evidence and severity, but use the scope below for this pull request.

```text
Review pull request "ART-001: Stylized Fantasy Slime V1 — Assets and Art Direction"
(branch feature/art-slime-v1, base main 730218a). Read-only: no edits, commits or pushes.

Read first: art/ART-001_REVIEW_HANDOFF.md, art/enemies/slime/ART-001_SLIME_V1.md,
art/enemies/slime/README.md, art/ART_DIRECTION.md.

Review these files:
- src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau
- src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau
- src/ServerStorage/EmberDev/SlimePreview.luau
- art/enemies/slime/source/InstallSlimeV1.luau (confirm its three embedded sources are
  byte-identical to the files above: python3 art/enemies/slime/source/build_installer.py)

Check:
1. Isolation: no changes to existing files; no gameplay, combat, currency, RemoteEvent,
   DataStore or networking code; nothing requires the new modules; the preview cannot run
   during Play; the installer only creates or replaces the three art ModuleScripts and
   their two folders, and changes nothing when they already exist.
2. Roblox API correctness: properties, enums and methods used exist and are used correctly
   (Part, SpecialMesh, Attachment, Model.PrimaryPart, PivotTo, ScaleTo, CFrame.lookAt,
   Color3.fromHex, Camera, RunService:IsRunning).
3. Luau --!strict typing problems the type checker would report.
4. Geometry: pivot and orientation contract, face details placed on the body surface,
   build-time scaling keeps proportions, no parts float or poke through.
5. Mobile and performance: part and instance budget, one shadow caster, one transparent part,
   no per-frame work, no external assets.
6. Preview safety: Archivable=false preview folder, camera restored by clear(), check()
   leaves nothing behind.
7. Documentation accuracy: every claim in the four documents matches the code; nothing is
   presented as a Studio result that is not one; established specs vs recommendations are
   labelled correctly in ART_DIRECTION.md.

Out of scope: Milestone 1 and Milestone 2 gameplay code (unchanged here), PR #1, and
gameplay integration into ArenaView (deliberately not done).

Report format: for each finding give severity (Critical/High/Medium/Low), exact file,
function and lines, a minimal trigger, impact, and the least disruptive fix. Separate
confirmed code defects, risks that need Roblox Studio to confirm, and optional improvements.
Do not invent Studio results or engine output.
```

## 8. Notes for ChatGPT (coordination)

Decisions and gates:

1. **Studio validation:** collect the user's T1–T11 results (template in `ART-001_SLIME_V1.md` section 5) before approving the asset.
2. **Codex review:** run the prompt in section 7; send accepted fixes back to Claude.
3. **Merge order (recommendation):** keep this PR open until PR #1 (Milestone 2) is approved and merged, then rebase this branch onto the new `main`. Merging it first would add new `src/` files to `main` while the Milestone 2 regression guide counts a fixed set of source files.
4. **Gameplay integration:** a separate, later change to `ArenaView.luau` only, after items 1–3 (plan in `ART-001_SLIME_V1.md` section 7). Not part of this PR.
5. **Open art-direction items:** the **[Recommendation]** entries in `ART_DIRECTION.md` (variant colour mapping, part budgets for bosses and heroes, repository layout for future assets) need the producer's approval before they become standards.

## 9. Asset handoff report answers

1. **Pull request:** the GitHub pull request from `feature/art-slime-v1` into `main` titled "ART-001: Stylized Fantasy Slime V1 — Assets and Art Direction". Not merged.
2. **Latest commit:** the head of `feature/art-slime-v1` (shown on the pull request; a file cannot contain its own commit SHA).
3. **Committed assets:** the files in section 4 (nine at the handoff; four more added by the review corrections).
4. **3D model formats present:** none. The model exists only as Luau generator code that builds a Roblox Model; no `.blend`, `.fbx`, `.obj`, `.glb`, `.rbxm` or `.rbxmx`.
5. **Art direction specification:** `art/ART_DIRECTION.md` (project-wide) and `art/enemies/slime/ART-001_SLIME_V1.md` (slime).
6. **Importing into Studio:** `art/enemies/slime/README.md` ("Bringing it into Roblox Studio") and `ART-001_SLIME_V1.md` section 4.
7. **Missing files or dependencies:** no missing dependencies. Missing evidence: Studio test results and Studio screenshots. Optional future files: a `.rbxm` snapshot (can be saved from Studio), and Blender sources only if the art pipeline later moves to meshes.
8. **Ready for in-Studio visual review:** yes. Install with the installer and run tests T1–T11.
9. **ArenaView's slime:** it will need modification later, not replacement of the whole module: `buildSlimeModel` in `ArenaView.luau` would call the factory, and the defeat burst would use the model's `Center` attachment and palette colour. That waits for Studio approval and the Milestone 2 merge.

## 10. Known risks

| Risk | Effect | Mitigation |
|---|---|---|
| `ScaleTo` scales `SpecialMesh.Scale` in the real engine | Ellipsoids would grow twice as much during ArenaView's hit squash after integration | T1 detects it; fallback is a plain-sphere body |
| Command Bar rejects the long installer paste | Installer can't run | Manual install (Method B) |
| Command Bar caches modules after a replace-install | Old code keeps running | Reopen the place after replacing (documented) |
| Offline render differs from Roblox | Look may differ in Studio | T2, T6, T7 screenshots are the real review |
| Merging before Milestone 2 | Changes `main`'s source file set during the M2 review | Merge after PR #1 (section 8) |

## 11. Review corrections (2026-11-01)

The independent review of `44a267b` returned CONDITIONAL PASS with no Critical, High or Medium findings. All four Low findings were corrected on this branch, in new commits on top of the audited one (history not rewritten):

| Finding | Resolution |
|---|---|
| Low 1 — gloss rim lifted up to 0.034 studs at both ends | `glossDepth` −0.1 → −0.14 seats the whole rim (now 0.0055 studs inside). Gloss thickness 0.36 → 0.44 keeps the original 0.083-stud relief, so the visible highlight covers 89% of its outline (82% with the depth change alone). Eye geometry unchanged. New `check()` item measures every surface detail at scales 0.5, 1, 1.75 and 3 |
| Low 2 — installer "(matches)" compared the text with itself | New `build_installer.py` (standard library) regenerates the installer and verifies byte-for-byte and SHA-256 parity; rejects same-length edits. Installer regenerated; its Studio line now reads `(embedded text installed intact)` |
| Low 3 — heights were bounding-box values; Milestone 1 comparison wrong | Docs now give visible height 5.62 (boxes 5.78) and the Milestone 1 slime's 6.16 / 7.2; T1 output prefix corrected; "flush" claims reworded; `check()` reports both heights |
| Low 4 — `gameplayCamera()` had no Edit-mode guard | Now calls `guardEditMode()`. New `check()` item simulates a running playtest and confirms `gameplayCamera`, `show` and `lineup` refuse and change nothing |

Optional observations (duplicate `Face` name, blush contrast) are recorded in `enemies/slime/README.md`, not changed. All results above are offline (fake engine); **no Roblox Studio test has been run**. T1–T11 in `enemies/slime/ART-001_SLIME_V1.md` section 5 are still required.
