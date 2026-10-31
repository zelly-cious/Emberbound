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
| `art/enemies/slime/source/InstallSlimeV1.luau` | Command Bar installer that creates the three ModuleScripts above (generated from them; same text) |
| `art/enemies/slime/ART-001_SLIME_V1.md` | ART-001 specification, Studio tests, performance checklist and integration plan |
| `art/enemies/slime/previews/slime-v1-offline-approximation.png` | Offline ray-traced approximation from the factory's exact part geometry. **Not a Roblox Studio screenshot**; Roblox lighting and materials will look different |

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
| Size at scale 1 | About 6.7 studs wide (skirt), 5.8 studs tall; ground shadow 7.8 studs across |
| Orientation | Pivot (`Root`) at the ground point under the body centre; front faces local −Z; built at the origin, placed with `PivotTo` |
| Scale | 0.1 to 10 via `create({ scale = n })`, same proportions at every scale |
| Imported into Roblox Studio | **Not yet verified.** It has been run offline in the Luau VM against a fake Roblox engine, but no Studio results have been received (ART-001 Phase 3 pending) |
| Rigging and animation | None. Parts are anchored and static; animation is planned for a separate client-only visual controller |
| Git LFS | Not needed: the largest file is the preview PNG (about 185 KB). No repository configuration was changed |

### Known limitations

- Not a mesh: it exists only inside Roblox (or as code), so it can't be opened in Blender or another 3D tool.
- Whether `Model:ScaleTo` also changes `SpecialMesh.Scale` is unverified. Test T1 checks it in Studio. It only matters for the later ArenaView integration (the hit squash uses `ScaleTo`); the fallback is a plain-sphere body.
- The skirt dips 0.35 studs × scale below the pivot, so the slime must stand on a surface.
- Strict-mode type checking with Roblox's type definitions hasn't been run; open each ModuleScript in Studio and check the Script Analysis window.

## Bringing it into Roblox Studio

Full beginner steps, expected output and PASS/FAIL criteria are in section 4 and 5 of [`ART-001_SLIME_V1.md`](ART-001_SLIME_V1.md). In short:

1. Open the Emberbound place, make a backup (**File → Save to File As…**), and stay in Edit mode.
2. Paste all of `art/enemies/slime/source/InstallSlimeV1.luau` into the Command Bar and press Enter. Expect three lines ending in `(matches)` and `Installed 3 ModuleScripts. Nothing else was changed.`
3. Run `require(game.ServerStorage.EmberDev.SlimePreview).check()` and expect `ALL 16 CHECKS PASSED`.
4. Run `require(game.ServerStorage.EmberDev.SlimePreview).show()` to see it on a copy of the arena from the gameplay camera, and `...clear()` to remove it.

**Optional: a standalone model for an art review or a `.rbxm` file.** In the Command Bar run:

```lua
local m = require(game.ReplicatedStorage.Shared.Visuals.SlimeModelFactory).create() m:PivotTo(CFrame.new(0, 10, 0)) m.Parent = workspace
```

`Slime_Standard` appears in Workspace above the baseplate. To export it, right-click it in the Explorer and choose **Save to File…** (`.rbxm`). Delete it from Workspace afterwards: unlike the preview, this copy is saved with the place. A `.rbxm` made this way would be a snapshot; the factory remains the source of truth.

## Relationship to the game's current slime

The game still shows the Milestone 1 slime built inside `ArenaView.luau` (9 parts). Nothing in the game uses this asset yet. Replacing it later means one reviewed change to `ArenaView.luau`, after Milestone 2 is merged and the Studio review passes. The plan is in section 7 of `ART-001_SLIME_V1.md`.
