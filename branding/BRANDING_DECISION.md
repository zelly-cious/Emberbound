# BRAND-001 — Public title: Tap a Monster

| | |
|---|---|
| Decision | The game's public-facing title is **Tap a Monster**. |
| Decided by | Game owner, 31 Oct 2026 |
| Supersedes | **Emberbound** (former working title) and **Click/Tap A Monster** (proposed earlier the same day, replaced before adoption) |
| Internal codename | **Emberbound** stays as the development codename for the repository, branches, code, file paths and tooling |
| Status | Approved by the owner. Recorded on the documentation-only branch `feature/branding-click-tap-a-monster`, not merged. |
| Scope | Documentation and planning only. No gameplay code, source file, RemoteEvent, module, branch or existing document is changed by this decision record. |

The branch name keeps the wording of the first brief ("click-tap"); the title it records is **Tap a Monster**.

## 1. What changes and what does not

**Changes:** the name players see. That means the Roblox experience name and description, the launch screen, the icon and thumbnails, promotional material, and the game's name in new documentation.

**Does not change:**

- Gameplay: mobile-first incremental tapping RPG, fixed-camera monster battles, hero collection and gacha, upgrades, equipment and trading, as already planned.
- The rarity system, the currencies (Gold now; Gems and Crowns as already scheduled), the roadmap and every decision in `DECISIONS.md` (PR #1).
- The art direction: **Stylized Fantasy RPG**, the six-colour palette and all Ember-named palette identifiers (section 4).
- The repository name `zelly-cious/Emberbound`, every branch, module, RemoteEvent, folder and file name.
- PR #1 (Milestone 2) and PR #2 (ART-001 Stylized Fantasy Slime V1).

## 2. Branding strategy

1. **Say what you do.** "Tap a Monster" tells a new, younger player the whole first minute of play: there is a monster, and you tap it. Store copy, the launch screen and thumbnails all show that same action first.
2. **Fantasy look, simple promise.** The title is plain on purpose; the Stylized Fantasy RPG art carries the personality (rounded monsters, warm Ember accents, magical highlights). The title should never be dressed up with lore words.
3. **Two names, two jobs.** *Tap a Monster* is for players. *Emberbound* is the internal codename for code, tooling and history. A player should never see "Emberbound"; a developer should never need to rename code because the public title changed.
4. **Grow into the depth.** Lead with tapping and monsters. Introduce heroes, gacha, equipment and trading in descriptions and promotion only when each feature is live.
5. **One spelling everywhere.** Section 3 is the single source for how the title is written.

## 3. Naming convention

### 3.1 The title

| Use | Write it as | Notes |
|---|---|---|
| Standard form, everywhere in sentences and headings | **Tap a Monster** | Capital T and M, lowercase "a", single spaces. |
| Logo or launch-screen artwork set in an all-caps typeface | TAP A MONSTER | Only inside artwork; the text form stays "Tap a Monster". |
| First mention in technical documents | Tap a Monster (codename Emberbound) | Afterwards "Tap a Monster" for the game, "Emberbound" only for code and repository names. |
| File names of new marketing assets | `tap-a-monster_<asset>_v<N>.<ext>` | Example: `tap-a-monster_icon_v1.png`, `tap-a-monster_thumbnail-tap_v1.png`. |

Never write: "Tap A Monster", "TAP a Monster", "Tap-a-Monster", "TapAMonster" (in prose), "Tap a Monster!" (as the name), "Click/Tap A Monster", or "Emberbound" in anything a player sees.

### 3.2 Code and data identifiers

- **Keep the codename conventions already in use.** Existing and future code identifiers, Studio folder names and model attributes keep their current naming (`EmberDev`, `EmberAsset`, `EmberVariant`, `VisualPalette.EmberOrange`, and so on). Do not create identifiers from the public title (no `TapAMonster` modules or attributes), so a future title change never touches code.
- **Player-visible title text should live in one place** when it is first needed (for example a single title string used by the launch screen). Recommendation for the first UI task that shows the title; nothing is implemented now.
- **Persistence (Milestone 3):** DataStore names and keys must not contain the public title, so renaming the game can never require a data migration.

### 3.3 By surface

| Surface | Rule |
|---|---|
| Roblox experience name | Exactly `Tap a Monster`. If update tags are ever used, put them in front in brackets (for example `[UPDATE 1] Tap a Monster`) and never change the title itself. |
| Experience description | First line names the game and the core action, for example: "Tap a Monster: tap monsters, earn Gold and upgrade your power!" Then list only features that are live. Keep sentences short for younger readers. |
| Launch / loading UI | Title text "Tap a Monster". **[Recommendation]** the existing UI font (`FredokaOne`), Ember Gold `#FFC857` lettering with a Shadow Navy `#26334A` outline, against the arena's dark slate. Show the title only; no codename. |
| Icon | One readable monster face (the Standard Slime V1 once ART-001 is approved), a tap cue (finger or tap ripple), warm Ember accents. Title text on the icon is optional and should be avoided if it becomes unreadable at small size. |
| Thumbnails | Show the core action: a monster on the arena, a tap, damage numbers or Gold popping. Only show features that exist in the game at that time. |
| Documentation | "Tap a Monster" for the game; "Emberbound" for the repository, codename and code. Historical documents keep the name they were written with (section 5). |
| Promotional material, social posts, trailers | "Tap a Monster" only. Use the Stylized Fantasy RPG palette and the established art; no unreleased features shown as available. |

Use the upload sizes and content rules shown in Creator Dashboard when you upload icons and thumbnails, since Roblox can change them.

**[Recommendation]** Before the first public launch, search Roblox for existing experiences with the same or a very similar name, so players are not confused. This record does not include that search.

## 4. Art direction and Ember identifiers (unchanged)

The art direction in `art/ART_DIRECTION.md` (PR #2) stays in force: Stylized Fantasy RPG, rounded chunky silhouettes, vibrant controlled colour, soft glossy materials, expressive faces, warm magical highlights, mobile-first performance.

"Ember" remains the name of the warm visual motif and of these palette and asset identifiers. None of them is a title reference, and none is renamed:

| Identifier | Where |
|---|---|
| Ember Orange `#FF8733`, Ember Gold `#FFC857` (with Forest Green, Mystic Blue, Deep Violet, Shadow Navy) | `art/ART_DIRECTION.md` §2 (PR #2) |
| `VisualPalette.EmberOrange`, `VisualPalette.EmberGold` | `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau` (PR #2) |
| `EMBER_COLOR` (brazier fire and lights) | `src/StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView.luau:34` (`main`) |
| Model attributes `EmberAsset`, `EmberVariant`, `EmberAssetVersion`, `EmberScale` | `SlimeModelFactory.luau`, `SlimePreview.luau`, `InstallSlimeV1.luau` (PR #2) |
| `ServerStorage > EmberDev` folder; `_EmberSlimePreview`, `_EmberSlimeCheck`, `EmberLight` | `SlimePreview.luau`, `InstallSlimeV1.luau` (PR #2) |
| Planned "Ember Slime" variant | `art/ART_DIRECTION.md` §2, `ART-001_SLIME_V1.md` (PR #2) |

## 5. References to the old title

Searched on 31 Oct 2026 in `main` (`730218a`), PR #1 (`feature/m2-tap-upgrades-bignum` at `09be466`) and PR #2 (`feature/art-slime-v1` at `44a267b`).

**No player-visible text in any branch contains "Emberbound".** The game's UI shows no title yet. Every occurrence is in documentation, code comments, developer tooling or file names. The one public surface that may show the old name is the Roblox experience itself (section 7), which is outside the repository.

Actions: **Update** = change to "Tap a Monster" in the post-merge documentation sweep (BRAND-002). **Keep** = leave as is (codename, citation or historical record). **Next edit** = update only when that file is next changed for another reason.

### 5.1 On `main` (all four files are also changed by PR #1)

| File:line | Text | Action |
|---|---|---|
| `README.md:1` | "EMBERBOUND — MILESTONE 1 CODEX REVIEW HANDOFF" | Replaced by PR #1's README; update the merged README |
| `AGENTS.md:1` | "Repository rules for Emberbound Milestone 1" | Replaced by PR #1's version; see 5.2 |
| `M1_REQUIREMENTS.md:5` | "Original working title **Emberbound**" | Keep (frozen Milestone 1 contract; it correctly records the original working title) |
| `REVIEW_PROMPT.md:1` | "EMBERBOUND — MILESTONE 1 INDEPENDENT AUDIT" | Replaced by PR #1's version; see 5.2 |

### 5.2 Added or changed by PR #1 (after PR #1 merges)

| File:line | Text | Action |
|---|---|---|
| `README.md:1` | "EMBERBOUND — MILESTONE 2 CODEX REVIEW HANDOFF" | Update the heading; keep repository links |
| `README.md:5, 22` | repository link; audit PDF file name | Keep |
| `AGENTS.md:1` | "Repository rules for the Emberbound Milestone 2 review" | Update (living rules file), or Keep if it is retired with the review |
| `DECISIONS.md:1` | "Emberbound — Recorded decisions" | Update the heading; add a pointer to this record |
| `DECISIONS.md:15` | cites *Emberbound — Master Spec V1.0 Architecture Review* | Keep (title of an external document) |
| `M2_REQUIREMENTS.md:7` | cites *Emberbound — Technical Architecture & Roadmap* and the Master Spec | Keep (citations) |
| `CODEX_REVIEW_HANDOFF.md:1` | heading | Keep (review evidence for PR #1) |
| `CODEX_REVIEW_HANDOFF.md:7, 11, 29–31, 35` | audit PDF name, repository links, `Emberbound_M2_Scripts.zip` | Keep |
| `REREVIEW_PROMPT.md:1, 5, 7` | heading, repository link, PDF name | Keep (review evidence) |
| `REVIEW_PROMPT.md:1` | "EMBERBOUND — MILESTONE 2 INDEPENDENT AUDIT" | Keep (round 1 evidence, must not be rewritten) |
| `review/M2_CHECK_RESULTS.md:13`, `review/M2_CORRECTIONS_REPORT.md:5, 7` | package and audit names, links | Keep (historical evidence) |
| `review/audits/Emberbound_M2_Independent_Audit.pdf` | file name and 7 mentions inside | Keep (historical evidence) |
| `review/offline-harness/roblox_shim.luau:4`, `review/offline-harness/run.sh:2` | comments | Next edit (internal tooling) |
| `src/ReplicatedStorage/Shared/BigNum.luau:170` | comment "every scaling formula in Emberbound" | Next edit. Any byte change to a source file invalidates `SOURCE_HASHES.txt` and the Studio parity check, so never change it on its own. |

### 5.3 Added by PR #2 (after PR #2 merges)

| File:line | Text | Action |
|---|---|---|
| `art/ART_DIRECTION.md:1, 3` | "Emberbound Art Direction — Stylized Fantasy RPG"; "every Emberbound visual asset" | Update (living reference document) |
| `art/ART_DIRECTION.md:86` | "'Ember' is the brand motif" | Update wording to "the visual motif" (Ember stays the motif; it is no longer part of the title). Needs art-direction approval, since §6 is a labelled recommendation. |
| `art/ART-001_REVIEW_HANDOFF.md:9` | "Emberbound's first stylized enemy asset" | Keep (review evidence for PR #2) |
| `art/enemies/slime/ART-001_SLIME_V1.md:93–94` | "your Emberbound test place", backup `Emberbound_before_ART001.rbxl` | Next edit (developer instructions; the codename is acceptable) |
| `art/enemies/slime/README.md:53` | "Open the Emberbound place" | Next edit |
| `src/ReplicatedStorage/Shared/Visuals/VisualPalette.luau:6`, `SlimeModelFactory.luau:6` | header comments | Next edit. `InstallSlimeV1.luau` embeds copies of these files and ART-001 records their SHA-256, so a comment change means regenerating the installer and the hashes. |
| `art/enemies/slime/source/InstallSlimeV1.luau:2, 27, 71, 1417` | header, embedded comments, Studio warning "Open the Emberbound place first" | Next edit (developer-facing; regenerate with its sources) |

### 5.4 Unmerged local work

The Milestone 2 Studio regression guide (`M2_STUDIO_REGRESSION_GUIDE.md` and `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`, local commit `fbd40d3`, not yet pushed) uses "Emberbound" in its heading, in the QA place file name `Emberbound_M2_QA.rbxl` and in the temporary `EmberboundQA` bridge. Keep the QA names (internal tooling); update the heading when that guide is next edited.

### 5.5 Outside the repository (owner actions)

| Item | Action |
|---|---|
| Roblox experience name, description, icon, thumbnails | Rename using section 7 when you choose (section 6) |
| Start place name in Creator Dashboard | Optional: rename to "Tap a Monster" at the same time |
| GitHub repository `zelly-cious/Emberbound` | Keep for now; renaming is a separate later decision |
| External design documents (*Technical Architecture & Roadmap*, *Master Spec V1.0 Architecture Review*) | Their own next revisions; existing citations keep the old titles |
| Local `.rbxl` place files and backups | No change needed |

## 6. Recommended timing

| When | What |
|---|---|
| **Now** | This record only. PR #1 and PR #2 stay untouched. |
| **Any time the owner chooses (recommended before any public or wider test)** | Rename the Roblox experience and update its description (section 7). Renaming does not affect the code or the pull requests. |
| **After PR #1 and PR #2 are both merged** | One documentation-only pull request (BRAND-002) applies every **Update** row in section 5, adds a link to this record from `README.md` and `DECISIONS.md`, and leaves every **Keep** row alone. Doing it once, after both merges, avoids conflicts with the open pull requests and with the files their reviewers are reading. |
| **When a file is next edited for a functional reason** (for example Milestone 2.1 StatService, or the next art asset) | Apply that file's **Next edit** row in the same change, with the usual hash and review updates. Never make a source change only for the title. |
| **First UI task that shows the title** (launch screen) | Implement the launch-screen rules in section 3.3 with the title text in one place. |
| **Before public launch** | Icon and thumbnails to section 3.3; name search (section 3.3); decide whether to rename the GitHub repository. |
| **If the repository is renamed later** | Separate decision. Update clone URLs, links in living documents and any connected tools (Codex, Claude, CI). GitHub normally redirects the old repository URL after a rename, but check that before relying on it. |

## 7. Renaming the Roblox experience

Renaming changes only the displayed name. The experience and place IDs stay the same, so links, the place file and any future saved data are not affected. Button and menu names can shift as Roblox updates its tools; look for the same names nearby if a step looks different.

### 7.1 In Creator Dashboard (web)

1. Go to <https://create.roblox.com> and sign in with the account (or group) that owns the experience.
2. Open **Dashboard → Creations** and select the experience.
3. In the left menu, open **Configure → Basic Settings** (or the experience's details page).
4. Set **Name** to `Tap a Monster` exactly.
5. Update **Description** using section 3.3 (live features only).
6. Click **Save Changes**.
7. Optional: under **Places**, open the start place and rename it to `Tap a Monster` too.
8. If the experience has translated names or descriptions under **Localization**, update those as well.
9. Open the experience's public page on roblox.com and check the new name. It can take a few minutes to appear everywhere.

### 7.2 In Roblox Studio

1. Open the **published** place (File → Open from Roblox, or from the start page).
2. **Home** tab → **Game Settings** (also under **File → Game Settings**).
3. **Basic Info** → set **Name** to `Tap a Monster` exactly; update **Description**.
4. Click **Save**. This updates the published experience, not just the local file.
5. Check the experience page on roblox.com as in 7.1, step 9.

Icon and thumbnails are uploaded from the same places (Creator Dashboard: the experience's configuration pages; Studio: Game Settings → Basic Info). Follow section 3.3.

## 8. Decision history

| Date | Event |
|---|---|
| Before 31 Oct 2026 | Working title **Emberbound** (`M1_REQUIREMENTS.md`, all review and art documents). |
| 31 Oct 2026 | Owner proposed **Click/Tap A Monster** as the public title. |
| 31 Oct 2026 | Owner finalized **Tap a Monster**, replacing both. **Emberbound** kept as the internal codename. This record created on `feature/branding-click-tap-a-monster`. |
