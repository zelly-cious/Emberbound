# Slime (ART-001) — asset record

The Standard Slime V1 is a **procedural Roblox model**: Luau code builds it from Roblox parts at runtime or in Studio. There is no Blender file, no mesh export and no saved Roblox model file. This README records what exists, how to bring it into Studio, and its compatibility status.

- Specification and Studio test plan: [`ART-001_SLIME_V1.md`](ART-001_SLIME_V1.md)
- Art direction for all assets: [`../../ART_DIRECTION.md`](../../ART_DIRECTION.md)
- Review handoff for ChatGPT and Codex: [`../../ART-001_REVIEW_HANDOFF.md`](../../ART-001_REVIEW_HANDOFF.md)

## Verified files

| File | What it is |
|---|---|
| `src/ReplicatedStorage/Shared/Visuals/SlimeModelFactory.luau` | **Model source.** Builds the slime (`create`, `applyPalette`, `getVisualParts`, `getPalette`, `listVariants`) |
| `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau` | Official palette and colour helpers used by the factory |
| `src/ServerStorage/EmberDev/SlimePreview.luau` | Studio edit-mode preview and automatic checks |
| `art/enemies/slime/source/InstallSlimeV1.luau` | Command Bar installer that creates the three ModuleScripts above. Generated from them by `build_installer.py`; never edited by hand |
| `art/enemies/slime/source/build_installer.py` | Regenerates the installer and verifies repository parity: byte-for-byte and SHA-256 (Python 3 standard library) |
| `art/enemies/slime/source/SOURCE_SHA256.txt` | SHA-256 of the three modules, in `sha256sum -c` format |
| `art/enemies/slime/review/` | Claude's internal review of `44a267b` (preserved as delivered; not a fully independent review), Codex's independent review of `bbca679` (preserved as delivered) and the corrections report |
| `art/enemies/slime/ART-001_SLIME_V1.md` | ART-001 specification, Studio tests, performance checklist and integration plan |
| `art/enemies/slime/previews/slime-v1-offline-approximation.png` | Offline ray-traced approximation from the factory's exact part geometry. **Not a Roblox Studio screenshot**; Roblox lighting and materials will look different. Rendered before the review corrections (the gloss moved by under 0.04 studs) |

The three modules stay under `src/` because that folder mirrors their Roblox Studio locations, like the rest of the game's code.

**Not present** (none exist anywhere in the repository or the project workspace): `.blend` sources, `.fbx`/`.obj`/`.glb` exports, `.rbxm`/`.rbxmx` model files, textures, rigs, animations, and real Studio screenshots. No `exports/` or `textures/` folder was created because there is nothing to put in them.

## Roblox asset compatibility

| Item | Status |
|---|---|
| Asset | `Slime_Standard` Model, produced by `SlimeModelFactory.create()` |
| Source format | Luau ModuleScript (`--!strict`) |
| Export format | None. A `.rbxm` can be saved from Studio later if wanted (see below); not done |
| Mesh dependencies | Roblox built-in `SpecialMesh` with `MeshType = Sphere` on 10 parts; no mesh asset IDs |
| Material dependencies | Roblox built-in `SmoothPlastic` only |
| Texture dependencies | None |
| External or third-party content | None. All geometry, colours and code are original to this project, so there are no licences to track |
| Size at scale 1 | About 6.7 studs wide (skirt); visible height 5.62 studs to the leaf tip (part bounding boxes reach 5.78); ground shadow 7.8 studs across |
| Orientation | Pivot (`Root`) at the ground point under the body centre; front faces local −Z; built at the origin, placed with `PivotTo` |
| Scale | 0.1 to 10 via `create({ scale = n })`, same proportions at every scale |
| Imported into Roblox Studio | **Not yet verified.** It has been run offline in the Luau VM against a fake Roblox engine, but no Studio results have been received (ART-001 Phase 3 pending) |
| Rigging and animation | None. Parts are anchored and static; animation is planned for a separate client-only visual controller |
| Git LFS | Not needed: the largest file is the preview PNG (about 185 KB). No repository configuration was changed |

### Known limitations

- Not a mesh: it exists only inside Roblox (or as code), so it can't be opened in Blender or another 3D tool.
- Whether `Model:ScaleTo` also changes `SpecialMesh.Scale` is unverified. Test T1 checks it in Studio. It only matters for the later ArenaView integration (the hit squash uses `ScaleTo`); the fallback is a plain-sphere body.
- The skirt dips 0.35 studs × scale below the pivot, so the slime must stand on a surface.
- Surface details are sunk just inside the curved body rather than perfectly flush. `check()` measures them: the eye rims rise up to 0.006 studs above the body surface along their lower edge (under the 0.01 tolerance; the eye geometry was deliberately left unchanged); all other rims are inside the body.
- Strict-mode type checking with Roblox's type definitions hasn't been run; open each ModuleScript in Studio and check the Script Analysis window.

### Review observations and producer decisions (2026-11-01)

Two optional observations from Claude's internal review, and what the producer decided:

1. **Duplicate name "Face": fixed.** `Root` had an Attachment named `Face` while the model also has a Folder named `Face`, so `slime:FindFirstChild("Face", true)` returned the attachment. The attachment is now **`FaceAnchor`**; the `Face` folder is unchanged. `check()` confirms `Root` has no child named `Face` and that a recursive search for `Face` finds the folder. Use `slime.Root.FaceAnchor` for damage numbers.
2. **Cheek contrast: deferred, pending visual-quality observation (not a blocking defect).** The Ember Orange cheeks and the Forest Green body have nearly the same luminance (contrast about 1.18:1), so they are told apart by hue alone and may be hard to see for players with red-green colour-vision deficiency. The palette stays unchanged; cheek visibility is evaluated during Studio T7 (phone) and T8 (low graphics), as noted in `ART-001_SLIME_V1.md` section 5.

## Bringing it into Roblox Studio

Full beginner steps, expected output and PASS/FAIL criteria are in section 4 and 5 of [`ART-001_SLIME_V1.md`](ART-001_SLIME_V1.md). In short:

1. Open the Emberbound place, make a backup (**File → Save to File As…**), and stay in Edit mode.
2. Paste all of `art/enemies/slime/source/InstallSlimeV1.luau` (about 62 KB) into the Command Bar and press Enter. Expect three lines ending in `(embedded text installed intact)` and `[ART-001 installer] Installed 3 ModuleScripts. Nothing else was changed.`
3. Run `require(game.ServerStorage.EmberDev.SlimePreview).check()` and expect 18 `[SlimePreview] PASS` lines and `[SlimePreview] ALL 18 CHECKS PASSED`.
4. Run `require(game.ServerStorage.EmberDev.SlimePreview).show()` to see it on a copy of the arena from the gameplay camera, and `...clear()` to remove it.

**Optional: a standalone model for an art review or a `.rbxm` file.** In the Command Bar run:

```lua
local m = require(game.ReplicatedStorage.Shared.Visuals.SlimeModelFactory).create() m:PivotTo(CFrame.new(0, 10, 0)) m.Parent = workspace
```

`Slime_Standard` appears in Workspace above the baseplate. To export it, right-click it in the Explorer and choose **Save to File…** (`.rbxm`). Delete it from Workspace afterwards: unlike the preview, this copy is saved with the place. A `.rbxm` made this way would be a snapshot; the factory remains the source of truth.

## Regenerating and verifying the installer

The installer is generated; the modules under `src/` are the source of truth. From the repository root:

- After editing a module: `python3 art/enemies/slime/source/build_installer.py --write` (rewrites the installer, its `EXPECTED_LENGTHS` and `SOURCE_SHA256.txt`, then verifies).
- To verify only: `python3 art/enemies/slime/source/build_installer.py`. It ends with `PARITY VERIFIED` or lists each problem and exits with code 1. Same-length edits are caught because it compares bytes and SHA-256, not just lengths.
- Cross-check with standard tools: `sha256sum -c art/enemies/slime/source/SOURCE_SHA256.txt`.
- Self-test of the tool: `python3 art/enemies/slime/source/build_installer.py --self-test`.

In Studio, the installer's `(embedded text installed intact)` line confirms only that each ModuleScript holds the text embedded in the installer. Parity with the repository is the job of `build_installer.py`. Full details are in section 1 of [`ART-001_SLIME_V1.md`](ART-001_SLIME_V1.md).

## Relationship to the game's current slime

The game still shows the Milestone 1 slime built inside `ArenaView.luau` (9 parts; about 6.16 studs tall to its leaf tip and 7.2 studs wide at its puddle). Nothing in the game uses this asset yet. Replacing it later means one reviewed change to `ArenaView.luau`, after Milestone 2 is merged and the Studio review passes. The plan is in section 7 of `ART-001_SLIME_V1.md`.
