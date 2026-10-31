# ART-001 — Standard Slime V1 (procedural model)

**Status:** Phase 2 implemented on branch `feature/art-slime-v1` (based on `main` at `730218a`). Waiting for Phase 3 Roblox Studio test results.

**Document history:** written in ART-001 Phase 2 at `art/ART-001_SLIME_V1.md`. Moved to `art/enemies/slime/` during the asset handoff; only file paths and the branch name were updated. No specification was changed.
Corrected on 2026-11-01 after the independent review of `44a267b` (four Low findings): gloss seating, installer parity tooling, height figures and the preview camera guard. See [`review/ART-001_CORRECTIONS_REPORT.md`](review/ART-001_CORRECTIONS_REPORT.md); the review itself is preserved in [`review/ART-001_INDEPENDENT_REVIEW.md`](review/ART-001_INDEPENDENT_REVIEW.md).
**Not integrated:** nothing in the game uses this model yet. `ArenaView` still builds the Milestone 1 slime. Milestone 2 (PR #1) is untouched.

## 1. Files

All files are new; no existing file was modified.

| File | Studio location | Purpose |
|---|---|---|
| `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau` | ReplicatedStorage > Shared > Visuals > VisualPalette (ModuleScript) | Official palette and colour helpers |
| `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau` | ReplicatedStorage > Shared > Visuals > SlimeModelFactory (ModuleScript) | Builds slime models |
| `src/ServerStorage/EmberDev/SlimePreview.luau` | ServerStorage > EmberDev > SlimePreview (ModuleScript) | Edit-mode preview and self-check |
| `art/enemies/slime/source/InstallSlimeV1.luau` | not installed; pasted into the Command Bar | Creates the three ModuleScripts above (generated) |
| `art/enemies/slime/source/build_installer.py` | not installed | Generates the installer and verifies repository parity (Python 3, standard library only) |
| `art/enemies/slime/source/SOURCE_SHA256.txt` | not installed | SHA-256 record of the three modules (`sha256sum` format) |
| `art/enemies/slime/ART-001_SLIME_V1.md` | not installed | This document |
| `art/enemies/slime/review/` | not installed | Preserved independent review and the corrections report |

SHA-256 of the three source files (also in `source/SOURCE_SHA256.txt`):

```text
c2944647d9252bdf64c6416384c93895974f863d731b9ebf9da85c85b87566b0  src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau
92aabd80ff0553124fc2f74cd50dc25a74e10eb8dec62fe8809e78e11427f110  src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau
832c3a3892f5eea6407a48eadc69ae84f644ba705d7ee9bf4a598555ea9a8951  src/ServerStorage/EmberDev/SlimePreview.luau
```

There are two separate checks:

- **Repository parity (outside Studio):** `python3 art/enemies/slime/source/build_installer.py` compares each embedded source with its repository file byte for byte, checks SHA-256 against `SOURCE_SHA256.txt` and checks that regenerating the installer reproduces it exactly. A same-length edit cannot pass. See "Regenerating and verifying the installer" below.
- **Embedded-source installation (in Studio):** after installing, the installer prints `(embedded text installed intact)` for each module. That only confirms the ModuleScript now holds the text embedded in the installer, at the recorded length; it does not compare against the repository.

These files are deliberately **not** listed in `SOURCE_HASHES.txt`, which belongs to the milestone reviews.

### Regenerating and verifying the installer

Run from the repository root (any operating system with Python 3; no packages needed):

1. After changing any of the three modules: `python3 art/enemies/slime/source/build_installer.py --write`. This rewrites `InstallSlimeV1.luau` (new `EXPECTED_LENGTHS`) and `SOURCE_SHA256.txt`, then verifies.
2. To verify without writing (for reviews): `python3 art/enemies/slime/source/build_installer.py`. It prints each file's byte count and SHA-256 next to its embedded copy and ends with `PARITY VERIFIED`, or lists every problem and exits with code 1.
3. Optional cross-check with standard tools: `sha256sum -c art/enemies/slime/source/SOURCE_SHA256.txt`.
4. `python3 art/enemies/slime/source/build_installer.py --self-test` makes same-length edits in memory (to each source, each embedded copy, the installer body and the manifest) and confirms every one is rejected.
5. Update the SHA-256 block above and in `art/ART-001_REVIEW_HANDOFF.md` when the hashes change.

Never edit `InstallSlimeV1.luau` by hand; the verifier rejects hand edits. Files must use LF line endings (on Windows, check out with `core.autocrlf=false`).

## 2. Model hierarchy (deliverable A)

```text
Slime_Standard (Model, PrimaryPart = Root)
├─ Root (invisible Part at the pivot)
│   ├─ Center (Attachment)  body centre, for hit bursts
│   ├─ Top    (Attachment)  top of the body, for crowns or labels
│   └─ Face   (Attachment)  just in front of the face, for damage numbers
├─ Ground (Folder)
│   └─ GroundShadow
├─ Body (Folder)
│   ├─ Skirt  ├─ Core  ├─ Gloss  └─ Sparkle
├─ Face (Folder)
│   ├─ EyeRight  ├─ EyeShineRight  ├─ EyeLeft  ├─ EyeShineLeft
│   ├─ MouthRight  ├─ MouthLeft
│   └─ CheekRight  └─ CheekLeft
└─ Crown (Folder)
    ├─ SproutStem  └─ SproutLeaf
```

- **Pivot:** the ground point under the slime's centre. Models are built at the origin; move them with `PivotTo`.
- **Front:** local −Z. "Right" and "Left" are the slime's own sides (Roblox rig convention), so `EyeRight` appears on the viewer's left.
- **Physics:** every part is Anchored with CanCollide, CanTouch and CanQuery off. Only `Core` casts a shadow; only `GroundShadow` is transparent.
- **Attributes:** model has `EmberAsset = "Slime"`, `EmberVariant`, `EmberAssetVersion = 1`, `EmberScale`. Every visible part has `ColorRole`.
- **Floor:** the skirt dips 0.35 studs (× scale) below the pivot so the slime meets the floor with a flat edge. It is meant to stand on a surface.

### Part list at scale 1 (studs)

| Part | Shape | Size | Colour role | Colour |
|---|---|---|---|---|
| GroundShadow | Cylinder disk | 7.8 wide, 0.06 thick | Shadow (55% transparent) | #26334A |
| Skirt | Ellipsoid | 6.7 × 1.3 × 6.1 | BodyShade | #60A156 |
| Core | Ellipsoid | 6.2 × 4.6 × 5.8 | Body | #78C96B |
| Gloss | Ellipsoid | 1.9 × 0.95 × 0.44 | BodyLight | #B5E1AE |
| Sparkle | Ball | 0.44 | Sparkle | #FFE9BC |
| EyeRight / EyeLeft | Ellipsoid | 0.95 × 1.35 × 0.5 | Ink | #26334A |
| EyeShineRight / Left | Ball | 0.34 | Shine | #FFFFFF |
| MouthRight / Left | Ellipsoid | 0.6 × 0.22 × 0.22 | Ink | #26334A |
| CheekRight / Left | Ellipsoid | 1.0 × 0.55 × 0.24 | Blush | #FF8733 |
| SproutStem | Cylinder | 0.75 long, 0.24 wide | Stem | #4E8346 |
| SproutLeaf | Ellipsoid | 1.3 × 0.14 × 0.62 | Leaf | #66AB5B |

15 visible parts plus the invisible Root, 10 built-in SpecialMeshes (MeshType Sphere, no asset IDs) and 3 Attachments: 33 descendants per slime.

Size at scale 1, measured from the factory output: the **visible** shape reaches 5.62 studs (top of the leaf) and dips to −0.35 (skirt); the body itself is 4.55 studs tall. The parts' **bounding boxes** reach 5.78 studs; `check()` uses the boxes as a conservative limit and reports both. Widths: skirt 6.7 × 6.1, ground shadow 7.8.

For comparison, the Milestone 1 slime in `ArenaView.luau` is about 6.16 studs tall to its leaf tip (5.2 to the top of its body), 6 studs wide at the body and 7.2 at its puddle. V1 is therefore about 0.5 studs shorter. The gameplay camera aims 3.4 studs above the ground point, so the framing still fits.

**Changes from the Phase 1 sketch:** the eye shines sit at the upper right of each eye so they match the gloss's light direction, and the body and skirt were tightened after an offline render so the base reads as a soft goopy edge rather than a plate.

## 3. Architecture (deliverable B)

- `VisualPalette` holds the six official colours plus `shade`, `tint` and `mix`. Every future asset takes its colours from it.
- `SlimeModelFactory` is a pure builder: no services, RemoteEvents, scripts, `RunService` loops or animation.
  - `create({ variant?, scale?, palette?, name? }) -> Model` builds a new, unparented model. Scale (0.1 to 10) is applied at build time to every size and offset.
  - `applyPalette(model, { Role = Color3 })` recolours by role.
  - `getVisualParts(model)` returns the visible parts in hierarchy order (useful for fades).
  - `getPalette(variant)` and `listVariants()` return a variant's colours and the available variants.
  - Bad input (unknown variant, bad scale, unknown colour role) raises a clear error.
- Variants live in one `VARIANTS` table. Only `Standard` exists. Ember, Frost, Shadow and Boss later add entries with their own palette and crown piece without touching Standard.
- Face and gloss details are placed by projecting onto the body's surface and turning them to follow it, with their centre sunk just inside the surface so only a cap shows. This adapts to other body shapes, but it is not perfectly flush on a curved body: `check()` measures every rim at scales 0.5, 1, 1.75 and 3 and requires that none lifts more than 0.01 studs × scale off the body and that every detail shows at least a 0.02-stud cap. Measured: the gloss, mouth and cheek rims are fully inside the body; the eye rims rise up to 0.006 studs above the surface along their lower edge (under the tolerance; eye geometry deliberately unchanged); the smallest cap is 0.040 studs (cheeks).
- Animation is left to a future client-only visual controller. The folders let it squash the body, blink the face and keep the shadow on the ground separately.

## 4. Install in Roblox Studio

### Before you start

1. Open your Emberbound test place in Roblox Studio (the place with the game installed).
2. Make a backup: **File → Save to File As…**, name it `Emberbound_before_ART001.rbxl`, then keep working in your normal place.
3. Make sure you are in **Edit mode**: no playtest is running and the **Play** button is available.
4. Open the **Explorer**, **Output** and **Command Bar** windows (in the classic layout these are on the **View** tab). Use the Command Bar the same way you did for the Milestone 1 installer.
5. Right-click inside the Output window and choose **Clear Output**.

### Method A: installer (recommended)

1. Open `art/enemies/slime/source/InstallSlimeV1.luau` in a plain text editor such as Notepad. Press **Ctrl+A**, then **Ctrl+C**.
2. Click inside the Studio Command Bar, press **Ctrl+V**, then **Enter**.
3. **PASS:** the Output shows three lines ending in `(embedded text installed intact)` and then `[ART-001 installer] Installed 3 ModuleScripts. Nothing else was changed.` (This confirms the installed text equals the text embedded in the installer. Parity with the repository is checked separately with `build_installer.py`; see section 1.)
   **FAIL:** any orange warning or red error. Copy the Output and report it.
4. In the Explorer, confirm **ReplicatedStorage → Shared → Visuals** contains `VisualPalette` and `SlimeModelFactory`, and **ServerStorage → EmberDev** contains `SlimePreview`. `GameConfig` and every other existing object are unchanged.

If the installer says the modules are already installed, nothing was changed. To replace them with a newer version, set `REPLACE_EXISTING_ART = true` at the top of the installer and run it again. After replacing, close and reopen the place before previewing, because the Command Bar may keep the old modules loaded.

### Method B: manual (only if the Command Bar rejects the long paste)

1. In the Explorer, right-click **ReplicatedStorage → Shared**, choose **Insert Object → Folder**, and rename it `Visuals`.
2. Right-click `Visuals`, choose **Insert Object → ModuleScript**, and rename it `VisualPalette`. Double-click it, press **Ctrl+A**, delete the default code, and paste the full contents of `VisualPalette.luau`.
3. Repeat step 2 inside `Visuals` for `SlimeModelFactory` with `SlimeModelFactory.luau`.
4. Right-click **ServerStorage**, insert a Folder named `EmberDev`, then a ModuleScript named `SlimePreview` inside it, and paste `SlimePreview.luau`.
5. Names are case-sensitive and must match exactly.

## 5. Studio tests (deliverable D, Phase 3)

Each Command Bar entry runs on its own, so every command below is one complete line. Paste it into the Command Bar and press Enter. Keep the Output window visible.

| ID | Do this | PASS when | FAIL when |
|---|---|---|---|
| T1 | `require(game.ServerStorage.EmberDev.SlimePreview).check()` | 18 lines begin `[SlimePreview] PASS` and the last line is `[SlimePreview] ALL 18 CHECKS PASSED` | Any `[SlimePreview] FAIL` line (orange) or red error |
| T2 | `require(game.ServerStorage.EmberDev.SlimePreview).show()` | The camera jumps to a grey platform with one slime, framed like the game. You see a rounded, slightly flattened green body; a darker green base; two dark navy oval eyes with white shines at their upper right; a small dark smile; orange cheeks; a pale gloss and warm sparkle at the upper right; a small sprout leaning left; a soft dark ring on the platform | A part is missing, floating, flickering, cut in half, the wrong colour, or the face is not readable |
| T3 | In the Explorer open **Workspace → _EmberSlimePreview → Slime_Standard**, expand the folders and click a few parts, for example `Core` and `EyeRight` | In Properties: **Anchored** ticked; **CanCollide**, **CanTouch**, **CanQuery** unticked; **CastShadow** ticked only on `Core` | Any part is unanchored or can collide |
| T4 | Select `Slime_Standard` in the Explorer and press **F** to focus. Hold the right mouse button and move the mouse to orbit; use the mouse wheel to zoom | From the sides, back and top, nothing floats, pokes out or has gaps; eyes and cheeks sit on the body; the sprout is attached | Any detail floats away from the body or sticks through it |
| T5 | `require(game.ServerStorage.EmberDev.SlimePreview).gameplayCamera()` | The camera returns to the gameplay framing | Camera does not move |
| T6 | `require(game.ServerStorage.EmberDev.SlimePreview).lineup()` | Four slimes, left to right: small, normal, large and a blue one. All have the same proportions and face layout. The blue one has a blue body, violet cheeks and the same navy eyes | Proportions differ between sizes, or recolouring missed a part |
| T7 | Run the T2 command again. Open the **Device Emulator** (classic layout: **Test** tab → **Device**), pick a phone and use landscape | On the phone-sized view, both eyes, the smile and the cheeks are still visible and the slime stands out from the backdrop | The face turns into an unreadable blob |
| T8 | **File → Studio Settings → Rendering**, set **Editor Quality Level** to **Level 1**, look at the slime, then set it back to **Automatic** | The slime still reads clearly with low graphics (shadows may disappear; the ground ring stays) | The slime becomes unreadable |
| T9 | `require(game.ServerStorage.EmberDev.SlimePreview).clear()` | `Preview removed.` in Output; `_EmberSlimePreview` is gone from Workspace; your camera is back where it was | Folder remains or an error appears |
| T10 | Press **Play**, play for a minute (tap the slime, defeat a few), then press **Stop** | The game behaves exactly as before: the **old** slime appears, tapping and Gold work, and no new red errors appear | Anything in gameplay changed or new errors appear |
| T11 (optional) | During Play, paste the T2 command, then the T5 command | Each refuses with a red error and changes nothing: on the server it says `Stop the playtest first`; if the Command Bar runs on the client, ServerStorage is hidden there, so the `require` itself fails instead | A preview appears or the camera moves during Play |

**Special case:** if T1's `Model:ScaleTo keeps built-in meshes in step` check fails, the preview is still valid. That check only matters for the future integration (the game's hit squash uses `ScaleTo`). Report it, and the fallback is a plain-sphere body.

### Collecting Output and reporting

1. Click inside the Output window, press **Ctrl+A** then **Ctrl+C**, and paste into a text file.
2. Take screenshots of T2, T6 and T7 (**Win+Shift+S** on Windows, **Cmd+Shift+4** on Mac).
3. Report in this format:

```text
ART-001 Studio results
Installer: PASS/FAIL (paste Output)
T1 check(): PASS/FAIL (paste the PASS/FAIL lines)
T2 show: PASS/FAIL + screenshot + notes on looks
T3 properties: PASS/FAIL
T4 orbit: PASS/FAIL
T5 camera: PASS/FAIL
T6 lineup: PASS/FAIL + screenshot
T7 phone emulator: PASS/FAIL + screenshot (which device)
T8 low graphics: PASS/FAIL
T9 clear: PASS/FAIL
T10 gameplay unchanged: PASS/FAIL
T11 (optional): PASS/FAIL
Any red errors: (paste)
Look and feel notes: (anything to tune: colours, gloss size, cheek strength, sprout)
```

## 6. Mobile-performance checklist (deliverable E)

| Check | Target | V1 |
|---|---|---|
| Visible parts | 10–18 | 15 (+ invisible Root) |
| Instances per slime | as few as practical | 33 descendants (16 parts, 10 SpecialMeshes, 4 folders, 3 attachments) |
| Shadow-casting parts | minimal | 1 (`Core`) |
| Transparent parts | avoid overlap | 1 (`GroundShadow`), never stacked on another transparent part |
| Lights, particles, decals, textures, sounds | none | none |
| External assets | none | none (built-in Sphere meshes only) |
| Physics | none | all anchored; no collisions, touches or queries |
| Scripts in the model | none | none |
| Per-frame work | none on the server | none at all; the factory only builds when called |
| Readability (T1 estimate) | eyes ≥ 14 px, smile ≥ 3 px on a 360 px tall phone screen | about 33 px and 5.5 px |
| Detail seating (T1) | no rim more than 0.01 studs × scale off the body; every cap ≥ 0.02 | largest lift 0.006 (eye lower edge); smallest cap 0.040 |
| Readability (visual) | readable in the phone emulator and at Quality Level 1 | T7 and T8 |

## 7. Future integration plan (deliverable F)

Only after the Phase 3 results are accepted **and** PR #1 (Milestone 2) is approved and merged:

1. Rebase `feature/art-slime-v1` onto the new `main`. Only new files are involved, so no conflicts are expected.
2. Make the integration a separate, reviewable change on its own branch, touching only `ArenaView.luau`:
   - `buildSlimeModel` returns `SlimeModelFactory.create({ name = "Enemy" })` and `SlimeModelFactory.getVisualParts(model)`, pivoted with the same `basePivot`. `ShowEnemy`, `PlayHit`, timings, the `Highlight` flash and the `ScaleTo` squash stay as they are.
   - Move the defeat burst to the model's `Center` attachment and take the burst colour from the palette instead of the hard-coded Milestone 1 green.
   - The idle bob moves the whole model, so the ground ring bobs 0.2 studs. That is acceptable for V1; the future visual controller will keep it on the ground.
3. That change updates `SOURCE_HASHES.txt` and the source-file count, goes through Codex review, and is followed by the Milestone 1/2 regression tests plus a mobile Studio check. Server code and the 61 tests are unaffected because the slime is client-only.
4. Rollback is reverting that one `ArenaView` change. The factory files can stay unused or be deleted.
5. Later: a client-only `SlimeVisualController` (TweenService; no server per-frame animation) and the Ember, Frost, Shadow and Boss variants as new `VARIANTS` entries.

## 8. Removing ART-001

Nothing references these modules, so removal cannot affect the game:

1. Run `require(game.ServerStorage.EmberDev.SlimePreview).clear()` if a preview is showing.
2. In the Explorer, delete **ServerStorage → EmberDev** and **ReplicatedStorage → Shared → Visuals**.
3. Press Play to confirm the game still works (same as T10).

The preview folder is never saved into the place (`Archivable = false`), so it cannot be left behind by a save.

## 9. Verification already done offline

- All three modules and the installer were compiled and run in the real Luau VM against a small fake Roblox engine: all 16 `check()` items passed, plus extra checks that face details sit on the body surface, the shines sit on the eyes, the smile strokes meet, balls are uniform, the preview manages only its own folder and camera, and the preview refuses to run during Play. The installer was tested for fresh install, refusal when already installed, and replace mode.
- An approximate offline render from the gameplay camera was used to tune the skirt.
- **Correction (2026-11-01):** the Phase 2 extra check above did not measure the gloss rim. The independent review found its two ends lifted up to 0.034 studs off the body; that is fixed, and `check()` now measures seating itself. The offline preview image predates this fix (the change is under 0.04 studs at scale 1).
- Review corrections, offline (fake engine, not Studio): all 18 `check()` items pass from the repository files and from the regenerated installer; mutation tests confirm the two new checks fail on the original gloss values and on an unguarded `gameplayCamera()`; installer fresh, refuse and replace runs behave as before; `build_installer.py` verifies parity and rejects same-length edits. Details in `review/ART-001_CORRECTIONS_REPORT.md`.
- **Not verifiable offline:** Roblox's own rendering and lighting, `Model:ScaleTo`'s effect on SpecialMeshes (T1 checks it in Studio), and strict-mode type checking with Roblox's type definitions (open each ModuleScript in Studio's Script Editor; the Script Analysis window should show no errors).

## 10. Files created or modified (deliverable G)

Created:

- `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau`
- `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau`
- `src/ServerStorage/EmberDev/SlimePreview.luau`
- `art/enemies/slime/source/InstallSlimeV1.luau`
- `art/enemies/slime/ART-001_SLIME_V1.md`
- Review corrections: `art/enemies/slime/source/build_installer.py`, `art/enemies/slime/source/SOURCE_SHA256.txt`, `art/enemies/slime/review/ART-001_INDEPENDENT_REVIEW.md`, `art/enemies/slime/review/ART-001_CORRECTIONS_REPORT.md`

Modified: none of the files that existed before ART-001. Not touched: every existing file under `src/`, `SOURCE_HASHES.txt`, `README.md`, all requirement and review documents, the Milestone 2 branch and PR #1.
