# Emberbound Art Direction — Stylized Fantasy RPG

This is the reference for every Emberbound visual asset: enemies, heroes, environments, effects and UI art. The Standard Slime (ART-001) is the first asset built to it.

Every statement below is labelled with where it comes from:

- **[Established]** — set by the ART-001 art-direction brief. Change only with explicit approval.
- **[Approved in ART-001]** — decided during ART-001 Phase 1 design review.
- **[Implemented, review pending]** — built in ART-001 Phase 2 (`art/enemies/slime/ART-001_SLIME_V1.md`), not yet visually reviewed in Roblox Studio.
- **[Existing game]** — already in the Milestone 1 code on `main`.
- **[Recommendation]** — proposed here for future assets. Not yet approved; confirm before relying on it.

## 1. Style and principles

**[Established]** Official style: **Stylized Fantasy RPG**. All future assets follow this visual language unless explicitly approved otherwise.

**[Established]** Visual principles:

- Rounded, chunky silhouettes
- Exaggerated but appealing proportions
- Vibrant, controlled colors
- Clean, readable shapes
- Soft glossy materials
- Expressive creature faces
- Warm magical highlights
- Mobile-first performance

**[Established]** Creatures should feel like fantasy RPG monsters, not realistic organisms.

## 2. Colour palette

**[Established]** Official palette:

| Name | Hex | Typical use |
|---|---|---|
| Ember Orange | `#FF8733` | brand warmth, fire, accents |
| Ember Gold | `#FFC857` | rewards, magical highlights |
| Forest Green | `#78C96B` | nature, early-game creatures |
| Mystic Blue | `#5D9CEC` | magic, frost, calm |
| Deep Violet | `#6C55A1` | arcane, shadow, rare |
| Shadow Navy | `#26334A` | ink lines, eyes, shadows |

The "typical use" column is a **[Recommendation]**; the six colours themselves are established. In code the palette lives in `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau`, which also provides `shade` (darker), `tint` (toward white) and `mix` helpers.

**[Implemented, review pending]** Slime colour roles, all derived from the palette:

| Role | Rule | Slime V1 |
|---|---|---|
| Body | base colour | Forest Green `#78C96B` |
| BodyShade | base × 0.8 | `#60A156` |
| BodyLight | base tinted 45% toward white | `#B5E1AE` |
| Ink | Shadow Navy | `#26334A` |
| Shine | white | `#FFFFFF` |
| Sparkle | Ember Gold tinted 60% toward white | `#FFE9BC` |
| Blush | accent | Ember Orange `#FF8733` |
| Shadow | Shadow Navy, 55% transparent | `#26334A` |
| Stem / Leaf | base × 0.65 / × 0.85 | `#4E8346` / `#66AB5B` |

**[Recommendation]** Use the same role names for every creature so one recolour function works across assets. Future slime variants: Ember Slime with an Ember Orange body and Ember Gold accents; Frost Slime with Mystic Blue; Shadow Slime with Deep Violet; Boss Slime as any of these with a crown piece and a larger scale.

## 3. Silhouette and shape language

- **[Established]** Rounded, slightly flattened body; strong silhouette at the gameplay camera distance; simple, clean geometry; no unnecessary decoration.
- **[Approved in ART-001]** Slime silhouette: a dome-shaped body on a softer, darker skirt, plus a small leaf sprout on top. The sprout keeps the Milestone 1 "Forest Slime" read and is the slot that variants swap (flame wisp, ice shard, horns, crown).
- **[Implemented, review pending]** Body ellipsoid 6.2 × 4.6 × 5.8 studs (height about 0.74 of width) on a 6.7 × 1.3 × 6.1 skirt; total height about 5.8 studs.
- **[Recommendation]** For every creature, design the silhouette first: it should be identifiable as a solid dark shape against the arena backdrop. Prefer one dominant mass, one secondary mass and at most one small accent (for the slime: body, skirt, sprout). Avoid thin protrusions that disappear on a phone screen.
- **[Recommendation]** Keep enemy designs original. Avoid the recognisable traits of well-known slimes from other franchises (teardrop tip, wide tongue grin, cube body).

## 4. Materials

- **[Established]** Soft glossy look. Do not assume transparency gives physically accurate translucency; avoid overlapping transparent surfaces.
- **[Implemented, review pending]** All parts use opaque `SmoothPlastic`. The gloss comes from shapes, not material effects: a pale gloss patch and a small warm sparkle on the upper body. Only the ground shadow is transparent.
- **[Recommendation]** Use `SmoothPlastic` for creatures and characters. Save `Neon` for intentional glow effects (magic, rewards), and avoid `Glass` on gameplay-critical shapes. Textured materials (`Grass`, `Slate`, `Wood`) belong to environments, as the Milestone 1 arena already does.

## 5. Eyes and facial expression

- **[Established]** Two expressive, dark eyes facing the player; a small, friendly mouth; a recognisable face at gameplay distance.
- **[Approved in ART-001]** Ember Orange blush cheeks.
- **[Implemented, review pending]** Tall Shadow Navy oval eyes (0.95 × 1.35 studs) with one white shine each. The shines sit on the same side as the body gloss so the light direction is consistent. A two-stroke smile and oval cheeks complete the face. All face details sit on the body surface and follow its curve.
- **[Recommendation]** Eyes are the most important readability feature: on a 360 px tall phone screen at the gameplay camera they should be at least about 14 px tall (Slime V1: about 33 px). Express mood mainly through eye shape and shine placement, and keep mouths small. Use Shadow Navy for "ink", never pure black.

## 6. Fantasy visual identity

- **[Established]** Warm magical highlights; vibrant but controlled colour.
- **[Existing game]** The Milestone 1 arena uses ember braziers (warm point lights and fire), a dark slate backdrop, a stone platform and forest trees.
- **[Recommendation]** "Ember" is the brand motif. Give every asset at least one small warm accent (Ember Orange or Ember Gold) against cooler or natural base colours, as the slime's cheeks and sparkle do. Rewards, upgrades and rare items lean gold; magic leans blue or violet.

## 7. Roblox proportions and orientation

- **[Existing game]** Gameplay camera (ArenaView): 18 studs in front of and 5.4 studs above the enemy's ground point, aimed 3.4 studs above it, field of view 50. The Milestone 1 slime was about 6 studs wide and 5.9 studs tall.
- **[Implemented, review pending]** Slime V1 contract: pivot at the ground point under the body centre; front faces local −Z; "Right"/"Left" part names are the creature's own sides; built at scale 1 and scalable from 0.1 to 10 with identical proportions; parts may dip 0.35 studs × scale below the pivot for a flat contact edge.
- **[Recommendation]** Use the same contract for every enemy: ground-point pivot, front on −Z, standard enemy footprint about 6–8 studs wide at scale 1, bosses by scale rather than separate models, and attachments named `Center`, `Top` and `Face` for effects.

## 8. Mobile performance

- **[Established]** Mobile-first; Roblox-native geometry; no external asset dependencies; about 10–18 visible parts per creature; visual parts non-collidable; no per-frame server-side visual animation; animation in a separate visual controller.
- **[Implemented, review pending]** Slime V1: 15 visible parts plus an invisible root, 10 built-in sphere meshes, 1 shadow-casting part, 1 transparent part; no lights, particles, textures, decals, sounds or scripts; all parts anchored with collisions, touches and queries off.
- **[Recommendation]** Budgets for future assets: standard enemy 10–18 visible parts, boss up to about 30, hero up to about 25. At most one transparent surface per asset, and shadows only from the main body mass. Animate on the client with TweenService, never every frame on the server. Check every asset in Studio's phone Device Emulator and at Editor Quality Level 1.

## 9. Lighting and presentation

- **[Existing game]** Arena lighting: a warm-white key SpotLight above the camera aimed at the enemy, two ember-coloured PointLights from the braziers, and a dark slate backdrop. Hit feedback uses a white `Highlight` flash and a quick squash; defeats use a particle burst.
- **[Implemented, review pending]** The ART-001 preview copies this stage and camera so assets are judged under gameplay conditions.
- **[Recommendation]** Judge every asset in the gameplay framing first, then up close. Keep creature colours lighter and more saturated than the backdrop so they pop. Don't rely on real-time shadows for readability, because low graphics settings turn them off; a fake ground shadow keeps assets grounded.

## 10. Reusable conventions

- **[Implemented, review pending]** Pipeline: assets are procedural Luau model factories (`src/ReplicatedStorage/Shared/Visuals/`), with an edit-mode preview and automatic checks (`src/ServerStorage/EmberDev/`) and a Command Bar installer. Asset generation is kept separate from gameplay code.
- **[Implemented, review pending]** Model structure: `Root` (invisible PrimaryPart with attachments), then folders by purpose (`Ground`, `Body`, `Face`, `Crown`). Every visible part has a `ColorRole` attribute; models carry `EmberAsset`, `EmberVariant`, `EmberAssetVersion` and `EmberScale` attributes.
- **[Recommendation]** Repository layout for art: `art/ART_DIRECTION.md` (this file), then `art/<category>/<asset>/` holding the asset's ART document, a README describing the asset record, `source/` for editable sources and tools, `exports/` only for real exported files, `textures/` only for real textures, and `previews/` for labelled renders or Studio screenshots. Create those folders only when they hold real files.
- **[Recommendation]** If meshes made in Blender or another tool are introduced later, commit the editable source next to the Roblox export, record the licence for any third-party content, and use Git LFS for large binaries. That needs a separate decision, because the repository has no LFS setup for art.
