# ART-001 — Standard Slime V1 (procedural model)

**Status:** Phase 2 implemented on branch `feature/art-slime-v1` (based on `main` at `730218a`). Waiting for Phase 3 Roblox Studio test results.

**Document history:** written in ART-001 Phase 2 at `art/ART-001_SLIME_V1.md`. Moved to `art/enemies/slime/` during the asset handoff; only file paths and the branch name were updated. No specification was changed.
**Not integrated:** nothing in the game uses this model yet. `ArenaView` still builds the Milestone 1 slime. Milestone 2 (PR #1) is untouched.

## 1. Files

All files are new; no existing file was modified.

| File | Studio location | Purpose |
|---|---|---|
| `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau` | ReplicatedStorage > Shared > Visuals > VisualPalette (ModuleScript) | Official palette and colour helpers |
| `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau` | ReplicatedStorage > Shared > Visuals > SlimeModelFactory (ModuleScript) | Builds slime models |
| `src/ServerStorage/EmberDev/SlimePreview.luau` | ServerStorage > EmberDev > SlimePreview (ModuleScript) | Edit-mode preview and self-check |
| `art/enemies/slime/source/InstallSlimeV1.luau` | not installed; pasted into the Command Bar | Creates the three ModuleScripts above |
| `art/enemies/slime/ART-001_SLIME_V1.md` | not installed | This document |

SHA-256 of the three source files (source parity):

```text
c2944647d9252bdf64c6416384c93895974f863d731b9ebf9da85c85b87566b0  src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau
43048824a4e4c0414f70a836a2d3e29246d009618b9976de65d0ca3d0e60ea37  src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau
c76d1eb51ec1077391cf92d58d59237ce04da501f756a4e3c06fcc5f6ebd7a14  src/ServerStorage/EmberDev/SlimePreview.luau
```

The installer embeds these exact texts and prints `(matches)` for each module after installing. These files are deliberately **not** listed in `SOURCE_HASHES.txt`, which belongs to the milestone reviews.

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
| Gloss | Ellipsoid | 1.9 × 0.95 × 0.36 | BodyLight | #B5E1AE |
| Sparkle | Ball | 0.44 | Sparkle | #FFE9BC |
| EyeRight / EyeLeft | Ellipsoid | 0.95 × 1.35 × 0.5 | Ink | #26334A |
| EyeShineRight / Left | Ball | 0.34 | Shine | #FFFFFF |
| MouthRight / Left | Ellipsoid | 0.6 × 0.22 × 0.22 | Ink | #26334A |
| CheekRight / Left | Ellipsoid | 1.0 × 0.55 × 0.24 | Blush | #FF8733 |
| SproutStem | Cylinder | 0.75 long, 0.24 wide | Stem | #4E8346 |
| SproutLeaf | Ellipsoid | 1.3 × 0.14 × 0.62 | Leaf | #66AB5B |

15 visible parts plus the invisible Root, 10 built-in SpecialMeshes (MeshType Sphere, no asset IDs) and 3 Attachments: 33 descendants per slime. About 5.8 studs tall, close to the Milestone 1 slime, so the camera framing still fits.

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
- Face and gloss details are placed by projecting onto the body's surface and turning them to follow it, so they sit flush and adapt to other body shapes.
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
3. **PASS:** the Output shows three lines ending in `(matches)` and then `Installed 3 ModuleScripts. Nothing else was changed.`
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
| T1 | `require(game.ServerStorage.EmberDev.SlimePreview).check()` | 16 lines start with `PASS` and the last line is `ALL 16 CHECKS PASSED` | Any `FAIL` line (orange) or red error |
| T2 | `require(game.ServerStorage.EmberDev.SlimePreview).show()` | The camera jumps to a grey platform with one slime, framed like the game. You see a rounded, slightly flattened green body; a darker green base; two dark navy oval eyes with white shines at their upper right; a small dark smile; orange cheeks; a pale gloss and warm sparkle at the upper right; a small sprout leaning left; a soft dark ring on the platform | A part is missing, floating, flickering, cut in half, the wrong colour, or the face is not readable |
| T3 | In the Explorer open **Workspace → _EmberSlimePreview → Slime_Standard**, expand the folders and click a few parts, for example `Core` and `EyeRight` | In Properties: **Anchored** ticked; **CanCollide**, **CanTouch**, **CanQuery** unticked; **CastShadow** ticked only on `Core` | Any part is unanchored or can collide |
| T4 | Select `Slime_Standard` in the Explorer and press **F** to focus. Hold the right mouse button and move the mouse to orbit; use the mouse wheel to zoom | From the sides, back and top, nothing floats, pokes out or has gaps; eyes and cheeks sit on the body; the sprout is attached | Any detail floats away from the body or sticks through it |
| T5 | `require(game.ServerStorage.EmberDev.SlimePreview).gameplayCamera()` | The camera returns to the gameplay framing | Camera does not move |
| T6 | `require(game.ServerStorage.EmberDev.SlimePreview).lineup()` | Four slimes, left to right: small, normal, large and a blue one. All have the same proportions and face layout. The blue one has a blue body, violet cheeks and the same navy eyes | Proportions differ between sizes, or recolouring missed a part |
| T7 | Run the T2 command again. Open the **Device Emulator** (classic layout: **Test** tab → **Device**), pick a phone and use landscape | On the phone-sized view, both eyes, the smile and the cheeks are still visible and the slime stands out from the backdrop | The face turns into an unreadable blob |
| T8 | **File → Studio Settings → Rendering**, set **Editor Quality Level** to **Level 1**, look at the slime, then set it back to **Automatic** | The slime still reads clearly with low graphics (shadows may disappear; the ground ring stays) | The slime becomes unreadable |
| T9 | `require(game.ServerStorage.EmberDev.SlimePreview).clear()` | `Preview removed.` in Output; `_EmberSlimePreview` is gone from Workspace; your camera is back where it was | Folder remains or an error appears |
| T10 | Press **Play**, play for a minute (tap the slime, defeat a few), then press **Stop** | The game behaves exactly as before: the **old** slime appears, tapping and Gold work, and no new red errors appear | Anything in gameplay changed or new errors appear |
| T11 (optional) | During Play, paste the T2 command | It refuses with a red error (for example `Stop the playtest first`) and builds nothing | A preview appears during Play |

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
- **Not verifiable offline:** Roblox's own rendering and lighting, `Model:ScaleTo`'s effect on SpecialMeshes (T1 checks it in Studio), and strict-mode type checking with Roblox's type definitions (open each ModuleScript in Studio's Script Editor; the Script Analysis window should show no errors).

## 10. Files created or modified (deliverable G)

Created:

- `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau`
- `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau`
- `src/ServerStorage/EmberDev/SlimePreview.luau`
- `art/enemies/slime/source/InstallSlimeV1.luau`
- `art/enemies/slime/ART-001_SLIME_V1.md`

Modified: none. Not touched: every existing file under `src/`, `SOURCE_HASHES.txt`, `README.md`, all requirement and review documents, the Milestone 2 branch and PR #1.
