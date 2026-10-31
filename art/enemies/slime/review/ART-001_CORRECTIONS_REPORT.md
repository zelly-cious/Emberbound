# ART-001 Slime V1 — Review Corrections Report

**Game:** Tap a Monster (internal codename Emberbound)
**Branch / PR:** `feature/art-slime-v1`, PR #2 (not merged)
**Audited commit:** `44a267beae43938fbd960b1106c540668c3592fc` — review preserved in [`ART-001_INDEPENDENT_REVIEW.md`](ART-001_INDEPENDENT_REVIEW.md)
**Review verdict:** CONDITIONAL PASS — 0 Critical, 0 High, 0 Medium, 4 Low
**Date:** 2026-11-01

All four Low findings are resolved in new commits on top of the audited commit; history was not rewritten. **Every result below comes from offline tools (the Luau compiler and a fake Roblox engine). No Roblox Studio test has been run.** Studio tests T1–T11 are still required.

## 1. Findings and resolutions

### Low 1 — Gloss rim geometry: RESOLVED

**File:** `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau` (`STANDARD_DETAILS`)

| | Before | After |
|---|---|---|
| `glossDepth` | −0.1 | −0.14 |
| `glossSize` | 1.9 × 0.95 × 0.36 | 1.9 × 0.95 × 0.44 |

Evaluation, measured on the factory's own parts (scale 1; values scale exactly with the model):

| Option | Largest rim lift | Relief (cap) | Visible footprint |
|---|---|---|---|
| Original (−0.1, 0.36) | **+0.034** (rim off the body over 136° of its outline, at both ends) | 0.083 | 96% (includes the lifted ends) |
| Depth only (−0.14, 0.36) | −0.0055 (seated) | 0.041 | 82% |
| **Applied** (−0.14, 0.44) | −0.0055 (seated) | 0.083 | 89% |

The depth change alone seats the rim, because seating depends only on the depth of the gloss's rim plane. On its own it would halve the highlight's relief and shrink its visible footprint by about 14 points. Thickening the gloss restores the original 0.083-stud relief without affecting the rim, which better meets "preserve the intended visible highlight". The depth-only option also passes every check (mutation test M1b) if the producer prefers a single-value change. Position, outline (1.9 × 0.95), roll, colour and the face and body silhouette are unchanged. The gloss does not reach the sparkle (0 overlapping sample points). **Eye geometry was not changed**: the eye rims rise up to 0.006 studs above the body along their lower edge, which is under the new 0.01 tolerance.

**Regression check added:** `check()` item "Surface details sit on the body with a visible cap (scales 0.5, 1, 1.75 and 3)". For the gloss, eyes, mouth strokes and cheeks it samples 72 points on each rim and requires no lift above 0.01 studs × scale. It also requires every detail, including the sparkle and the eye shines, to show at least a 0.02-stud cap, and each ball detail's centre to sit inside its host. With the original gloss values it fails with `Gloss rim lifts 0.017 studs off Core at scale 0.5 (limit 0.005)`. The proportions check now covers scales 0.5, 1.75, 2 and 3 (was 0.5 and 2).

### Low 2 — Installer source parity: RESOLVED

**Files:** new `art/enemies/slime/source/build_installer.py`, new `art/enemies/slime/source/SOURCE_SHA256.txt`, regenerated `art/enemies/slime/source/InstallSlimeV1.luau`

- `build_installer.py` (Python 3, standard library only) is now the only way to produce the installer. `--write` regenerates it deterministically from the three repository files, updates `EXPECTED_LENGTHS` and writes `SOURCE_SHA256.txt` (`sha256sum -c` format).
- Verify mode, the default, fails with exit code 1 unless all of these hold:
  - each embedded source, extracted from the installer independently of the template, is byte-for-byte equal to its repository file;
  - SHA-256 values agree between the file, the embedded copy and the manifest;
  - `EXPECTED_LENGTHS` matches the file lengths;
  - regenerating reproduces the committed installer exactly, which also catches hand edits outside the embedded sources.
- Same-length edits cannot pass. `--self-test` applies eight same-length or hand edits in memory and all eight are rejected. An on-disk test changed `leafRoll = 25` to `26` in a copy: `EXPECTED_LENGTHS` still matched, and the tool rejected it on byte comparison, manifest SHA-256 and regeneration.
- The installer stays self-contained for the Command Bar. Its Studio-side line now reads `(embedded text installed intact)`, and its header and comments say it does **not** compare against the repository. Apart from those wording changes (header, the check's comment, labels and the mismatch warning) and the new embedded sources, the generated installer is identical to the original. The generator was confirmed to reproduce the original installer from the original sources with only those differences.
- How to regenerate and verify: `art/enemies/slime/README.md` ("Regenerating and verifying the installer") and `ART-001_SLIME_V1.md` section 1.

### Low 3 — Documentation accuracy: RESOLVED

**Files:** `art/enemies/slime/ART-001_SLIME_V1.md`, `art/enemies/slime/README.md`, `art/ART_DIRECTION.md`, `art/ART-001_REVIEW_HANDOFF.md`

All figures come from the factory output (Luau harness) and agree with an independent Python model of the same geometry:

| Claim | Old text | Corrected |
|---|---|---|
| Slime V1 height | "about 5.8 studs tall" | visible 5.62 (leaf tip), part bounding boxes 5.78; body top 4.55; lowest point −0.35 |
| Milestone 1 slime | "about 6 studs wide and 5.9 studs tall" | 6 wide at the body, 7.2 at the puddle; 6.16 tall to the leaf tip (5.2 to the body top), from `ArenaView.luau` |
| T1 output | "16 lines start with `PASS`", "`ALL 16 CHECKS PASSED`" | 18 lines begin `[SlimePreview] PASS`; last line `[SlimePreview] ALL 18 CHECKS PASSED` |
| Installer output | "three lines ending in `(matches)`" | `(embedded text installed intact)`, with the parity distinction explained |
| Detail placement | details "sit flush" / "sit on the body surface" | sunk just inside so only a cap shows; measured, with the eye-rim exception stated |
| Preview in Play | "refuses to run during Play" (not true for `gameplayCamera`) | building and camera commands refuse; `clear`/`help` stay available |
| Hashes, sizes | old SHA-256, 51 KB | new SHA-256, about 59 KB |

`check()`'s height item now reports both the visible height and the bounding-box height. Its label changed from "keeps the Milestone 1 height" to "fits the gameplay framing", since V1 is about 0.5 studs shorter. The model's scale was not changed. Established art-direction statements and their labels are unchanged. The Phase 2 claims in the handoff are kept, with inline "corrected" notes, so the original evidence stays readable.

### Low 4 — Preview camera safety: RESOLVED

**File:** `src/ServerStorage/EmberDev/SlimePreview.luau`

- `gameplayCamera()` now calls the existing `guardEditMode()` before touching the camera.
- `guardEditMode()` reads a module-local `isPlaytestRunning` function (normally `RunService:IsRunning()`), which only `check()` swaps, briefly, to simulate a playtest.
- **Regression check added:** `check()` item "Preview commands refuse to run during Play (simulated) and change nothing". It runs `gameplayCamera`, `show` and `lineup` under a simulated playtest and requires each to fail with "Stop the playtest first". It also requires that the camera, the saved camera and the preview folder are unchanged. If a guard ever goes missing, it undoes whatever the command did before reporting the failure.
- Camera restoration and cleanup are unchanged: `show`/`lineup`/`gameplayCamera` followed by `clear` restores the original camera, and `clear` still works in Play. `ArenaView` and all gameplay scripts are untouched.

### Optional observations: DOCUMENTED, not changed

Both are recorded in `art/enemies/slime/README.md` ("Optional observations"): the duplicate `Face` name (Root attachment and model folder), and the low blush/body luminance contrast (about 1.18:1). Both need a producer decision; no redesign was done.

## 2. Files changed (relative to `44a267b`)

| File | Change |
|---|---|
| `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau` | gloss depth and thickness (2 lines) |
| `src/ServerStorage/EmberDev/SlimePreview.luau` | `gameplayCamera` guard; guard hook; two new checks; visible-height reporting; proportions at more scales; failure messages in real studs |
| `art/enemies/slime/source/InstallSlimeV1.luau` | regenerated by `build_installer.py` |
| `art/enemies/slime/source/build_installer.py` | new: generator and parity verifier |
| `art/enemies/slime/source/SOURCE_SHA256.txt` | new: SHA-256 manifest |
| `art/enemies/slime/ART-001_SLIME_V1.md` | Low 3 corrections; parity and regeneration docs; hashes; T1 and T11 |
| `art/enemies/slime/README.md` | Low 3 corrections; regeneration section; optional observations |
| `art/ART_DIRECTION.md` | heights, Milestone 1 figures, face-detail wording |
| `art/ART-001_REVIEW_HANDOFF.md` | inventory and hashes; corrected Phase 2 claims; section 11 |
| `art/enemies/slime/review/ART-001_INDEPENDENT_REVIEW.md` | new: review evidence as delivered |
| `art/enemies/slime/review/ART-001_CORRECTIONS_REPORT.md` | new: this report |

No file that existed before ART-001 is modified: nothing under `src/ServerScriptService` or `src/StarterPlayer` (ArenaView, CombatClient, CombatHud, CombatService, ServerInit), `GameConfig`, `SOURCE_HASHES.txt`, the root documents, or any Milestone 2 or PR #1 file.

## 3. Test results (offline; not Roblox Studio)

Environment:
- **Luau compiler and VM:** the official Luau sources via the `mlua` crate (Luau feature), run by a small runner.
- **Fake engine:** a minimal Roblox engine written for these checks. It covers Vector3, CFrame, Color3, Enum and Instance with class-checked properties, plus Model pivot and scale, ModuleScripts with `require` caching, Workspace and its camera, and a switchable `RunService:IsRunning()`.

The harness lives outside the repository so the project gains no new dependency; this report records its results.

| # | Required check | Result |
|---|---|---|
| 1 | Luau compilation | 4/4 files compile (VisualPalette, SlimeModelFactory, SlimePreview, installer); a deliberately broken file fails, as a control |
| 2 | SlimePreview offline checks | `check()` from the repository files: **18/18 PASS**, `[SlimePreview] ALL 18 CHECKS PASSED`, no warnings, place unchanged afterwards. Also 18/18 from the modules the regenerated installer created. Baseline: the audited commit reproduced the reported 16/16 in the same harness before any change |
| 2a | New checks catch their defects | M1: original gloss values → only the seating check fails (`Gloss rim lifts 0.017 studs off Core at scale 0.5 (limit 0.005)`). M2: guard removed from `gameplayCamera` → only the Play check fails, and it leaves no camera change or folder behind |
| 3 | Exact source parity | `build_installer.py`: PARITY VERIFIED, byte-identical, SHA-256 match, installer reproduces exactly; `--self-test` 8/8 edits rejected; `sha256sum -c` all OK; on-disk same-length edit rejected (exit 1) |
| 4 | Geometry and scaling | At scales 0.5, 1, 1.75, 3: visible height 5.619 × scale; lowest −0.35 × scale; gloss rim −0.0055, eyes +0.0062, mouths −0.0450, cheeks −0.0381 (studs per unit of scale); smallest cap 0.040 (cheeks); gloss cap 0.083; deviation between scales 8.9e-16; gloss/sparkle overlap 0. An independent Python model gives the same numbers |
| 5 | Installer safety | 14/14: fresh install adds only two folders and three modules; second run refuses and changes nothing; replace mode updates the same instances in place and keeps unrelated objects; refuses during Play, without `Shared`, when `EmberDev` is not a Folder, when a name is taken by another class, and when a partial install exists |
| 6 | ART-001 files consistent | Hashes identical in `SOURCE_SHA256.txt`, `ART-001_SLIME_V1.md` and the handoff; no stale "16 checks", "(matches)", "5.9", "51 KB" or old hashes left (the preserved review keeps its original text by design) |
| 7 | No Milestone 1/2 changes | `git diff --diff-filter=MDR 730218a`: empty; no paths shared with PR #1 |
| 8 | Slime still inactive | No file outside `Shared/Visuals` and `EmberDev` references the modules; ArenaView still builds the Milestone 1 slime |
| — | Preview behaviour (extra) | 12/12: `show` (Archivable=false folder, pivot on platform, faces camera), `lineup` (four slimes, blue recolour), `gameplayCamera`, `clear` (folder removed, original camera restored) |
| — | Real Play mode in the fake engine | `gameplayCamera`, `show`, `lineup`, `check` all refuse with "Stop the playtest first"; camera and place unchanged; `clear` still allowed |

Not run: strict-mode type checking with Roblox's definitions (no analyser with Roblox types was available). New code avoids patterns the checker rejects: an explicit `number` annotation, `IsA` refinement before reading `MeshType` and `Shape`, and typed result tables. Studio Script Analysis is still required.

## 4. Installer parity verification (final)

```text
src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau      1447 bytes  c2944647d9252bdf64c6416384c93895974f863d731b9ebf9da85c85b87566b0  embedded: identical
src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau 19999 bytes  92aabd80ff0553124fc2f74cd50dc25a74e10eb8dec62fe8809e78e11427f110  embedded: identical
src/ServerStorage/EmberDev/SlimePreview.luau               33304 bytes  832c3a3892f5eea6407a48eadc69ae84f644ba705d7ee9bf4a598555ea9a8951  embedded: identical
InstallSlimeV1.luau: 59,500 bytes, reproduces byte-for-byte from the three files
```

## 5. Roblox Studio tests still required

All of T1–T11 in `ART-001_SLIME_V1.md` section 5, with the user's results in the report template there. Particular attention:

- **T1:** expect 18 PASS lines. The `Model:ScaleTo keeps built-in meshes in step` item has only ever run in the fake engine, which leaves `SpecialMesh.Scale` alone by construction; only Studio can show what the real engine does.
- **T1 / T4:** the new seating check, and an orbit look at the gloss ends and the eye lower edges.
- **T11:** now also covers the T5 command (`gameplayCamera`) during Play.
- **Script Analysis:** each of the three ModuleScripts with no strict errors.
- **Installer:** the about 59 KB paste is accepted, and the three `(embedded text installed intact)` lines appear.

## 6. Outstanding risks

| Risk | Status |
|---|---|
| Real `ScaleTo` may change `SpecialMesh.Scale` | Unverified; T1 detects it. It matters only for the later ArenaView integration. Cheapest fallback: reset each `SpecialMesh.Scale` to `Vector3.one` after each `ScaleTo` |
| Strict type errors under Roblox's definitions | Unverified; Script Analysis in Studio |
| Command Bar rejects the about 59 KB paste | Method B (manual) remains |
| T9 camera restore depends on the Command Bar caching the module between entries | As before; if T9's camera clause fails, that is the likely cause |
| Replace mode while a module is open in the Script Editor or Team Create drafts | Close the module tabs before replacing |
| GroundShadow sits 0.02 studs above the floor; the two smile strokes overlap | Look for shimmer or seams in T7 and T8 |
| Offline preview image predates the gloss fix | Under 0.04 studs of change; Studio screenshots (T2, T6, T7) are the real review |
| Merging before PR #1 | Unchanged recommendation: merge after PR #1, then rebase |
