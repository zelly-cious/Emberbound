# Emberbound Milestone 2 — Roblox Studio regression testing guide

A beginner-friendly, step-by-step checklist for testing Milestone 2 (Tap Upgrades, Economy & BigNum) in Roblox Studio before PR #1 can be considered for merge.

| | |
|---|---|
| Code under test | `src/` at commit `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf` (the round 2 corrections). PR #1 head `09be466` has identical `src/` (`git diff e4b0108 09be466 -- src` is empty). |
| Files | 24 Luau source files, 6 RemoteEvents, 3 Folders (Appendix A) |
| Unit tests | 61 tests in 7 suites, run automatically by `Tests/TestRunner` when you press Play in Studio |
| Where to record results | `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md` (copy it, then fill it in) |
| Not allowed during this testing | Editing any of the 24 scripts, merging PR #1, starting Milestone 2.1 |

**Important:** this guide was written from the source code and the offline review results. **Nobody has run it in Roblox Studio yet.** The expected results are predictions from the code. If Studio shows something different, that is exactly what we need to know: record it as a FAIL with evidence; do not change the expected result to match.

---

## Contents

0. [Read first: decision status, rules, how to mark results](#0-read-first)
1. [Studio basics for beginners](#1-studio-basics-for-beginners)
2. [Install the place and verify source parity (24 files)](#2-install-the-place-and-verify-source-parity)
3. [Run the 61 unit tests](#3-run-the-61-unit-tests)
4. [QA helpers you will paste into the Command Bar](#4-qa-helpers)
5. [Milestone 1 gameplay regression](#5-milestone-1-gameplay-regression)
6. [Milestone 2 purchases and damage (including level 24 → 25)](#6-milestone-2-purchases-and-damage)
7. [Request abuse: malformed, replayed, rapid and two-client requests](#7-request-abuse)
8. [Delayed requests and synchronization under lag](#8-delayed-requests-and-synchronization)
9. [Mobile UI, rotation and touch](#9-mobile-ui-rotation-and-touch)
10. [Scientific-number display](#10-scientific-number-display)
11. [Leave / rejoin and sustained-combat cleanup](#11-leave--rejoin-and-sustained-combat-cleanup)
12. [Collecting Output and reporting failures](#12-collecting-output-and-reporting-failures)
- [Appendix A — the 24 files, with checksums](#appendix-a--the-24-files)
- [Appendix B — source-parity checker](#appendix-b--source-parity-checker)
- [Appendix C — QA logger and other client snippets](#appendix-c--client-snippets)
- [Appendix D — server helper snippets and the fallback QA bridge](#appendix-d--server-snippets-and-the-fallback-qa-bridge)
- [Appendix E — expected-value tables](#appendix-e--expected-value-tables)

---

## 0. Read first

### 0.1 Status of the three documentation decisions

The producer approved three proposed documentation decisions **in principle**. They are **not yet written into the repository**: at PR #1 head `09be466`, `M2_REQUIREMENTS.md`, `DECISIONS.md` and `M2_REVIEW_GUIDE.md` do not mention them. The round 2 re-review report that defines R2-1 and R2-2 is not in the repository either. This guide treats the decisions as **pending**: every test below checks the requirements as they are written today. The table shows where a decision touches a test.

| Decision (approved in principle, documentation pending) | How this guide handles it | Tests affected |
|---|---|---|
| **1. Bounded finite-precision BigNum contract**, keeping the documented early-game exactness and all gameplay/security invariants | Exact results are required where the current requirements demand them: every value below 2^53 (Milestone 1 stage table, upgrade costs and values, Gold arithmetic). Above 2^53 the tests expect only the approximate behaviour that `M2_REVIEW_GUIDE.md` §4 and §10 already document (about 17 significant digits; a cost far smaller than the balance does not change it, so a purchase at a 1.5e400 balance leaves the balance at 1.5e400). Gold never negative, one charge per level, one reward per defeat, server authority and per-player isolation are pass/fail at every size. | U-4, U-5, U-6, A-5, N-2 to N-5 |
| **2. Defer R2-1** (affected parser), with a correction required before untrusted profile/import input can reach it | Not a Studio pass/fail item; do not try to reproduce it. The deferral's precondition holds in this code (confirmed by source): outside the Tests folder, `BigNum.parse` is only called by the client on strings the server generated (`CombatClient.luau:93-95, 117, 122-123, 162, 167, 178`); no server code parses text from a client, a profile or an import, and there is no persistence. N-1 checks only parse's existing contract (returns nil, never errors). | N-1 |
| **3. Defer R2-2** (health-bar display) for the current bounded use | Not a Studio pass/fail item. Precondition (confirmed by source): outside the Tests folder, `BigNum.ratio` is used only at `CombatHud.luau:297`, clamped to 0…1, and enemy HP never exceeds max HP. N-5 checks visually that the bar stays inside its frame at large values. | N-5 |

R2-1 and R2-2 are identified here only from the decision wording ("the affected parser" = `BigNum.parse`, "health-bar display use" = `BigNum.ratio`). The reviewer should confirm this mapping against the round 2 report. If a decision is changed or rejected, re-check the expected results of the listed tests before using them.

### 0.2 Rules while testing

1. **Do not edit any of the 24 scripts.** If something fails, record it; do not fix it.
2. The only things you may add to the place are the temporary QA objects this guide names (`EmptyTests` in T-2 and, only if needed, the `EmberboundQA` bridge in Appendix D). Delete them afterwards; P-5 checks that you did.
3. Do not merge PR #1, publish the place to a public experience, or start Milestone 2.1.
4. Start each **session** (listed in 0.4) with a fresh Play: Stop, clear Output, Play again, paste the QA logger.

### 0.3 How to mark each test

| Mark | Use it when |
|---|---|
| **PASS** | Every "PASS if" condition was observed. |
| **FAIL** | Anything in "FAIL if" happened, or any PASS condition was not met. Also FAIL: any **red** error line in Output during the test (none is expected anywhere in this guide), except lines that clearly come from a Studio plugin (see 12.3). |
| **BLOCKED** | You could not run the test because of a tool or setup problem (for example, a Studio feature is missing in your version). Write what blocked you. |
| **NOT RUN** | You chose to skip it (only allowed for tests marked *optional*). |

Orange/yellow warnings are allowed **only** if listed in 12.3. Any other warning that mentions one of the 24 scripts or a `[…]` tag from the game: mark the test FAIL and copy the warning.

### 0.4 Recommended order (about 4–5 hours in total; you can stop between sessions)

| Session | Mode | Tests | Time |
|---|---|---|---|
| 0 | Edit mode | Install, P-1 to P-4 | 60–90 min |
| 1 | Play (one player) | T-1, M1-1 to M1-8, T-2, U-1 to U-4, U-7 | 40 min |
| 2 | Play (one player) | H-check, U-6, U-5, N-1, N-3, N-4, N-5, N-2, L-3 | 35 min |
| 3 | Play (one player) | A-1 to A-7 | 20 min |
| 4 | 2 clients + server | B-1 to B-5, L-1, L-2, L-4 | 30 min |
| 5 | Play with simulated lag | D-4, D-1, D-2, D-3 | 20 min |
| 6 | Device emulator | MOB-1 to MOB-7, N-6 (MOB-8, MOB-9 optional) | 40 min |
| 7 | Play (one player) | C-1 to C-5 | 25 min |
| Final | Edit mode | P-5, fill in the results | 15 min |

---

## 1. Studio basics for beginners

Button and menu names below are from the standard Studio ribbon. If your Studio layout looks different, look for the same name in the **Home**, **Test** or **View** tab. Mac users: use **Cmd** wherever this guide says **Ctrl**.

### 1.1 Windows to open (View tab)

Click each of these once so they stay open: **Explorer**, **Properties**, **Output**, **Command Bar**.

- **Explorer** — the tree of everything in the place (ReplicatedStorage, ServerScriptService, …).
- **Properties** — settings of whatever is selected in Explorer.
- **Output** — messages. White/grey = info, **orange** = warning, **red** = error.
- **Command Bar** — a one-box code runner at the bottom of Studio. Paste a snippet, press **Enter**, read the result in Output.

In the Output window's options menu (if available), turn on **Show Context** (prints Client/Server) and **Show Timestamp**. Right-click inside Output and choose **Clear Output** before each session.

### 1.2 Play, Stop, and Client vs Server view

- **Play** (F5) starts a test with one player (you). **Stop** (Shift+F5) ends it.
- While playing, Studio has two views: the **Client** (what the player's device runs) and the **Server**. A toggle button on the Home or Test tab reads **"Current: Client"** or **"Current: Server"**; clicking it switches. The Explorer and the Command Bar always work in the current view.
- **Which view am I in?** Paste this into the Command Bar and press Enter:

  ```lua
  print("[QA] LocalPlayer =", game:GetService("Players").LocalPlayer)
  ```

  It prints your player name in the **Client** view and `nil` in the **Server** view. Every snippet in this guide says which view it needs. Running a snippet in the wrong view either errors or tests the wrong thing. A red error caused by pasting into the wrong view is not a game failure: note it and paste again in the right view.

### 1.3 Two players (Session 4)

**Test** tab → **Clients and Servers** area → set the player count to **2** → **Start**. Studio opens three windows: **Server**, **Player1**, **Player2**. Each window has its own Output and Command Bar: the Server window's Command Bar runs on the server, each Player window's runs on that client. To finish, click **Cleanup** (or Stop) in the Server window.

### 1.4 Device emulator (Session 6)

**Test** tab → **Device** (Emulation area). A bar appears above the 3D view with a device list and an **orientation** (rotate) button. Pick a phone, then press Play. With a phone selected, your mouse clicks act as **touches**.

### 1.5 Copying code into Studio

Every code block in this guide has a copy button on GitHub (top-right corner of the block). Copy, click into the Command Bar, paste (Ctrl+V), press Enter. The Command Bar snippets contain no comments and work whether Studio keeps or removes the line breaks.

---

## 2. Install the place and verify source parity

You will build a fresh place by hand and then prove, with a checksum, that all 24 scripts in Studio are byte-for-byte the reviewed code.

### 2.1 Get the source files

Use this exact commit so the code cannot change under you:

- Browse: <https://github.com/zelly-cious/Emberbound/tree/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src>
- Or download everything as a ZIP: <https://github.com/zelly-cious/Emberbound/archive/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf.zip>

To copy one file from GitHub: open the file, then click the **Copy raw file** button (two overlapping squares, top-right of the file view). This copies the exact contents. If you use the ZIP instead, open each `.luau` file in a plain-text editor (Notepad, TextEdit in plain-text mode, VS Code), press Ctrl+A, then Ctrl+C. **Never** copy through Word or Google Docs.

### 2.2 P-1 Create the place and its folders, remotes and settings

1. Open Roblox Studio and sign in.
2. Create a new place from the **Baseplate** template.
3. **File → Save to File As…** and save it as `Emberbound_M2_QA.rbxl` in a folder you will remember. (Saving to a file does not publish anything.) Save again (File → Save to File) after every few steps.
4. In **Explorer**, click **Players**. In **Properties**, find **CharacterAutoLoads** and **untick** it.
5. In Explorer, hover over **ReplicatedStorage**, click the **+** button, type `Folder`, press Enter. Right-click the new folder → **Rename** → type `Shared` → Enter.
6. Again on **ReplicatedStorage**: **+** → `Folder` → rename it `Remotes`.
7. Hover over **Remotes**, **+** → `RemoteEvent` → rename. Repeat until Remotes contains exactly these six RemoteEvents (names are case-sensitive, no spaces):
   `RequestAttack`, `ClientReady`, `CombatUpdate`, `RequestUpgrade`, `UpgradeUpdate`, `CurrencyUpdate`.
8. Hover over **ServerScriptService**, **+** → `Folder` → rename it `Tests`.

Do not add RemoteFunctions or anything else. P-1 is graded by the parity checker in P-3.

### 2.3 P-2 Create the 24 scripts

For **each row** of the table in [Appendix A](#appendix-a--the-24-files), in table order:

1. In Explorer, hover over the **Parent** shown in the row and click **+**.
2. Type the **Class** exactly (`ModuleScript`, `Script` or `LocalScript`) and press Enter. Only two rows are `Script` and one is a `LocalScript`; all others are `ModuleScript`.
3. Right-click the new object → **Rename** → type the **Name** exactly (case-sensitive) → Enter.
4. Double-click it to open the script editor. Press **Ctrl+A** (selects the placeholder text such as `print("Hello world!")`), then **Ctrl+V** to paste the file you copied from the **Repository file** column. Close the editor tab.

Tips:

- `ArenaView`, `CombatHud` and `UpgradePanel` go **inside** the `CombatClient` LocalScript: hover over CombatClient itself and click its +.
- Do not create anything in StarterGui or StarterCharacterScripts.
- If your Studio has an option that reformats code on paste or save, turn it off first: it would change the checksums.
- If you use Team Create with collaborative editing, commit every script draft before P-3, or the checker reads old text.
- If you installed with some other method (Rojo, an installer script), that is fine: P-3 is what proves the install.

### 2.4 P-3 Source-parity check (required)

1. Stay in **edit mode** (do not press Play).
2. Copy the whole snippet from [Appendix B](#appendix-b--source-parity-checker), paste it into the Command Bar, press Enter.
3. Read Output.

**PASS if** Output ends with these two lines, and no `[Parity] FAIL` line appears above them:

```text
[Parity] scripts matching: 24 / 24, remotes: 6 / 6, extra scripts: 0
[Parity] RESULT: PASS
```

**FAIL if** you see `[Parity] RESULT: FAIL`. Each `[Parity] FAIL …` line tells you what to fix:

| Message contains | What to do |
|---|---|
| `is missing` | Wrong name or wrong parent. Compare with Appendix A. |
| `is a … must be a …` | Wrong class. Delete it and re-create it with the right class, then paste again. |
| `content differs` | The text is not identical. Open the script, Ctrl+A, paste again from **Copy raw file**. If the byte count is off by a lot, you probably pasted the wrong file. |
| `exists 2 times` | Delete the duplicate. |
| `is disabled` | Select it, tick **Enabled** in Properties. |
| `RunContext = Client` | Select the Script, set **RunContext** to **Legacy** in Properties. |
| `extra script` | Delete it (for example a leftover Milestone 1 script), unless it is a QA object this guide told you to add. |
| `Folder` / `RemoteEvent` / `CharacterAutoLoads` | Fix as described in P-1. |

Fix and re-run until it passes. **Do not start Session 1 until P-3 passes.** Copy the final two `[Parity]` lines into your results file.

How the check works: for each script it normalizes line endings and trailing blank space at the end of the file, then compares the byte count, line count and an Adler-32 checksum with values computed from the exact bytes whose SHA-256 is listed in `SOURCE_HASHES.txt` (round 2 section). All 24 files at `e4b0108` match that manifest and are already in normalized form, so a pass means the Studio text equals the reviewed files.

### 2.5 P-4 (optional) Check the downloaded files' SHA-256

Only if you used the ZIP. Compare each file's SHA-256 with Appendix A (also in `SOURCE_HASHES.txt`, round 2 section).

- Windows PowerShell, in the extracted folder: `Get-FileHash -Algorithm SHA256 src\ReplicatedStorage\Shared\BigNum.luau`
- macOS Terminal: `shasum -a 256 src/ReplicatedStorage/Shared/BigNum.luau`

**PASS if** all 24 hashes match. **FAIL if** any differs (re-download the ZIP).

### 2.6 P-5 Final parity re-check (run last, after all testing)

Delete every temporary QA object (`EmptyTests`, the `EmberboundQA` Script if you added it), then run P-3 again in edit mode. **PASS if** `[Parity] RESULT: PASS` with `extra scripts: 0`. This shows the tested place is exactly the reviewed code.

---

## 3. Run the 61 unit tests

### T-1 All 61 tests in 7 suites pass in Studio

1. Clear Output. Press **Play**.
2. Wait 5 seconds. Read Output (the server's lines; in Play mode they appear in the same Output window).

**Expected** (these 8 lines, in this order; other lines may appear between them):

```text
[Tests] BigNumTests: 25 passed, 0 failed
[Tests] CombatFormulaTests: 4 passed, 0 failed
[Tests] CombatRulesTests: 5 passed, 0 failed
[Tests] ProgressionTests: 7 passed, 0 failed
[Tests] RateLimiterTests: 3 passed, 0 failed
[Tests] TestKitTests: 7 passed, 0 failed
[Tests] WalletTests: 10 passed, 0 failed
[Tests] ALL PASSED (61 tests)
```

**PASS if** all 8 lines appear exactly (25 + 4 + 5 + 7 + 3 + 7 + 10 = 61) and there is no red error.
**FAIL if** any line is missing, any count differs, or you see any `[Tests] FAIL …` line or a line like `[Tests] 1 FAILED, 60 passed`. Note: test failures are printed as **orange warnings**, not red errors, so read the text. Copy every `[Tests]` line into the failure report. One BigNum test uses Roblox's real `Random`, which the offline harness could not use; a failure there is a real Studio-only finding.

Keep this Play session running: M1-1 to M1-8 continue in it. Run T-2 after M1-8, because it needs a Stop.

### T-2 A broken test module can never report ALL PASSED (negative control)

Run this after M1-8. It checks the audit F3 fix in the real engine, and adds one temporary object that you remove again.

1. Stop. In Explorer, hover over **ServerScriptService → Tests**, **+** → `ModuleScript`, rename it `EmptyTests`. **Do not edit its text** (the default text returns an empty table, which is not a test suite).
2. Clear Output, press Play, wait 5 seconds.

**PASS if** Output contains both lines below, and does **not** contain `ALL PASSED`:

```text
[Tests] FAIL could not load EmptyTests: did not return a test suite
[Tests] 1 FAILED, 61 passed
```

**FAIL if** `ALL PASSED` appears, or the two lines are missing.

3. Stop. **Delete `EmptyTests`.** Press Play again and confirm T-1's 8 lines are back. Stop.

---

## 4. QA helpers

The helpers only **read** what the game sends, or call the game's own server functions from Studio. Paste them only when a test tells you to.

| Helper | View | What it does | Code |
|---|---|---|---|
| **H-1 QA logger** | Client | Prints every update the server sends you (`[QA] Combat …`, `[QA] Currency …`, `[QA] Upgrade …`) and counts them. Paste once per Play session, in every player window. `_G.QA.summary()` prints the counts; `_G.QA.reset()` zeroes them. | Appendix C.1 |
| **H-2 Resync check** | Client | Asks the server to resend your full state. If the screen does not change, the screen already matched the server. | Appendix C.2 |
| **H-3 Grant Gold** | Server | Gives your player Gold through the game's real `CurrencyService.Grant`. | Appendix D.1 |
| **H-4 Server state** | Server | Prints the server's Gold and upgrade level for your player. | Appendix D.2 |
| **H-5 Set tap damage** | Server | Sets tap damage through the game's real `CombatService.SetTapDamage`. | Appendix D.3 |

### H-check: do the server helpers reach the live game? (Session 2, once)

Studio may give Command Bar code its own copy of the game's modules. If so, H-3 to H-5 would change a copy instead of the real game. Check once:

1. Play. Switch to **Server** view. Paste **H-4**.
2. **Helpers OK** if it prints `gold=0 level=1 combat=true` (with your name).
3. **Helpers not connected** if it prints `gold=nil level=nil combat=false`. Then use the fallback bridge in Appendix D.4 for every H-3/H-4/H-5 step (one extra temporary Script; delete it before P-5). If the bridge also fails, mark the tests that need helpers (U-5, U-6, the exact numbers in A-5, N-2 to N-6, L-1's server check, C-3) BLOCKED.

Record which case you got in the results file. Both are acceptable; only the second needs the bridge.

---

## 5. Milestone 1 gameplay regression

**Session 1.** One Play session; keep it running from T-1 unless a test says otherwise. Switch to **Client** view and paste the **H-1 logger** before M1-3.

What the screen should look like (placeholder art):

| Area | Shows |
|---|---|
| Top | Two dark pills: `Stage 1` and `Gold: 0` (gold-coloured) |
| Upper middle | `Forest Slime`, a red health bar with `10 / 10` |
| Centre | A green slime on a stone platform, trees and braziers; faint text `Tap or click to attack` near the bottom of the combat area |
| Bottom | Pill `Tap Damage: 1` |
| Right | Dark panel `Tap Upgrade` with `Level 1`, `Tap Damage: 1`, `Next: 2 damage` and a grey button `Need 5 Gold` |

### M1-1 Clean startup

**Steps:** In the T-1 session, read all of Output.
**PASS if** you see `[CombatService] Created combat state for <your name> (tracked players: 1)`, no red lines, and no orange lines except those allowed in 12.3. In particular there is **no** `[ServerInit] Players.CharacterAutoLoads should be false` warning and **no** `[CombatClient] No combat sync yet` warning.
**FAIL if** any red line, any `Missing RemoteEvent`, any `Infinite yield possible`, or any unlisted warning.

### M1-2 No avatar, fixed camera

**Steps:**
1. Look at the game view. Try to move the camera: right-drag, mouse wheel, W/A/S/D, arrow keys.
2. Client view, paste Appendix C.3 (camera check).
3. Then paste Appendix C.4 (camera snap-back).

**PASS if** no avatar appears, the camera never moves, and the snippets print:

```text
[QA] CAMERA character=nil type=Enum.CameraType.Scriptable focus=0, 54, 0 position=0, 56, 18 fov=50
[QA] CAMERA after reset type=Enum.CameraType.Scriptable focus=0, 54, 0
```

**FAIL if** an avatar spawns, the camera moves, `type` is not `Scriptable`, or `focus` is not `0, 54, 0`.

### M1-3 Initial sync and HUD values

**Steps:** Paste the **H-1 logger** (Client view) if you have not yet. Paste **H-2** (resync).
**Expected logger lines** (one of each, in this order):

```text
[QA] Currency Gold=0
[QA] Upgrade Sync level=1 value=1 nextCost=5
[QA] Combat Sync stage=1 hp=10/10 tap=1 dmg=nil goldAwarded=nil
```

**PASS if** the HUD and panel show exactly the values in the table above (Stage 1, Gold: 0, Forest Slime, 10 / 10, Tap Damage: 1, Level 1, Tap Damage: 1, Next: 2 damage, Need 5 Gold) and the logger prints the three lines.
**FAIL if** anything still shows a placeholder (`Stage -`, `Gold: -`, `Connecting...`, `- / -`, `Tap Damage: -`, `Level -`, `Loading...`) more than 5 seconds after Play, or any value differs.

### M1-4 Ten taps defeat the stage 1 slime exactly once

**Steps:** In Client view, paste `_G.QA.reset()`. Click the slime **10 times**, slowly (about 2 clicks per second). Watch HP, then paste `_G.QA.summary()`.
**PASS if** all of:
- HP goes 10 → 9 → … → 1, one step per click, each click shows a white `-1` near the slime;
- on the 10th click the slime plays its defeat burst, `+5 Gold` floats under the Gold pill, `Gold: 5`, `Stage 2`, a new slime pops in at `11 / 11`;
- summary shows `hits=9 defeats=1` and Output has exactly one `[QA] Currency Gold=5`.

**FAIL if** two defeats, Gold other than 5, stage other than 2, max HP other than 11, or any click produced two hits.

### M1-5 Stage 2 and stage 3 values

**Do not buy any upgrade during this test** (keep Tap Damage at 1). The Upgrade button turns green; ignore it.

**Steps:** Click the stage 2 slime 11 times, then the stage 3 slime 13 times.
**PASS if** stage 2 shows `11 / 11` and pays `+5 Gold` (Gold: 10); stage 3 shows `13 / 13` and pays `+6 Gold` (Gold: 16); stage 4 shows `16 / 16`.
**FAIL if** any of these numbers differs.

### M1-6 Server tap cooldown (0.07 s) cannot be bypassed

**Steps (Client view):**
1. Wait 2 seconds without clicking. Paste Appendix C.5 (200 attack requests in one frame). Wait for the `[QA] SUMMARY` line.
2. Paste Appendix C.6 (one attack request every frame for 5 seconds). Wait about 8 seconds for its summary.

**PASS if** step 1's summary shows `hits + defeats = 1` (200 requests, exactly one accepted), and step 2's shows `hits + defeats` **≤ 72** (5 s ÷ 0.07 s, plus one). HP and Gold change only by those accepted hits.
**FAIL if** step 1 accepts 2 or more, or step 2 accepts more than 72.
Record the step 2 number (about 60 is typical at 60 frames per second).

### M1-7 Clicks outside the combat area never attack (desktop mouse)

**Steps:** `_G.QA.reset()`. Click 5 times each on: the `Stage` pill, the `Gold` pill, the `Tap Damage` pill at the bottom, the upgrade panel's title and labels, and the Upgrade button. Then `_G.QA.summary()`. Then click the slime 3 times and `_G.QA.summary()` again.
**PASS if** the first summary shows `hits=0 defeats=0`, and the second shows `hits + defeats = 3`. A click on the button buys an upgrade if you can afford one; it never also attacks.
**FAIL if** any of those UI clicks caused a hit.
Note: the enemy name and the health bar are **inside** the combat area by design, so clicking them does attack. That is expected.

### M1-8 Extra arguments on attack requests are ignored

**Steps:** Wait 1 second. Client view, paste:

```lua
game:GetService("ReplicatedStorage").Remotes.RequestAttack:FireServer(1e308, "Tap", { damage = 999999 })
```

**PASS if** the logger shows one `Combat Hit` (or `Defeated`) whose `dmg=` equals your current tap damage (or the remaining HP if that is smaller), not 1e308 or 999999, and no red error.
**FAIL if** damage is anything else, or the server errors.

(U-1 to U-4 and U-7 continue in this session; see section 6.)

---

## 6. Milestone 2 purchases and damage

### U-1 Panel at 0 Gold

**Setup:** a fresh Play (Stop, clear Output, Play, Client view, paste H-1). Do not click the slime.
**Steps:** Click the grey `Need 5 Gold` button 5 times.
**PASS if** the panel shows `Level 1`, `Tap Damage: 1`, `Next: 2 damage`, button `Need 5 Gold`; the clicks print **no** `[QA] Upgrade` line, no status text appears, and Gold stays `0`. (The client does not send a request it knows you cannot afford; the server re-checks anyway, see A-4.)
**FAIL if** a purchase happens, Gold changes, or a request reply appears.

### U-2 First purchase raises tap damage

**Steps:**
1. Click the slime 10 times → `Gold: 5`; the button turns green: `Upgrade for 5 Gold`.
2. Click the button once.
3. Click the stage 2 slime (11 HP) six times.

**PASS if**, after step 2: `Gold: 0`; panel `Level 2`, `Tap Damage: 2`, `Next: 3 damage`, button `Need 5 Gold`; green `Upgraded!` appears briefly and the panel pops; bottom HUD pill `Tap Damage: 2`; logger prints, in this order, `Currency Gold=0`, `Combat Stats … tap=2`, `Upgrade PurchaseResult level=2 … | result id=1 Ok`.
And in step 3: HP 11 → 9 → 7 → 5 → 3 → 1 with `-2` popups, then the 6th click shows `-1` (only 1 HP was left; damage never exceeds the remaining HP and overkill does not carry over), the slime is defeated once, `+5 Gold`, `Stage 3`.
**FAIL if** Gold is not exactly 0 after the purchase, level/damage differ, the HUD pill and the panel disagree, or hits do not deal 2.
If the three logger lines arrive in a different order, record it as an observation (the final values decide PASS/FAIL).

### U-3 HUD, panel and real hits always agree (check during U-4)

After **every** purchase in U-4, check three things: the bottom HUD `Tap Damage: N`, the panel `Tap Damage: N`, and the next damage popup on an enemy with more HP than N must all show the same N.
**PASS if** they always agree. **FAIL if** they ever disagree (write down the level).

### U-4 Play to level 24, then buy level 25 (no helpers needed)

Keep playing the U-2 session. Strategy: whenever the button is green, click it once; otherwise keep clicking the slime. You reach level 25 after roughly 105 accepted clicks (around stage 20). Appendix E.1 lists every cost.

**Steps:**
1. When the panel shows `Level 24`, stop buying. Check the panel and HUD.
2. Click an enemy whose HP is more than 24 once.
3. Write down the Gold amount. When the button shows `Upgrade for 23 Gold`, click it.
4. Click an enemy whose HP is more than 75 once (stage 14 or later; stage 14 has 85 HP).

**PASS if** all of:
- At level 24: panel `Level 24`, `Tap Damage: 24`, `Next: 75 damage`; button cost **23**; HUD `Tap Damage: 24`; the hit shows `-24` and HP drops by exactly 24.
- After buying: Gold dropped by **exactly 23**; panel `Level 25`, `Tap Damage: 75`, `Next: 78 damage`, next cost **25**; HUD `Tap Damage: 75`; `Upgraded!` shown.
- The hit shows `-75` and HP drops by exactly 75.
- Every purchase along the way charged exactly the Appendix E.1 cost (spot-check a few in the logger: each `Currency Gold=` after a purchase is the previous value minus that cost).

**FAIL if** level 25 deals anything but 75, level 24 anything but 24, any cost differs from Appendix E.1, or Gold ever goes below 0.

### U-7 Resync after purchases changes nothing

**Steps:** At the end of U-4, take a screenshot. Paste H-2 (resync).
**PASS if** the logger prints a Currency, an `Upgrade Sync` and a `Combat Sync` line, and **nothing on screen changes** (Stage, Gold, HP, Tap Damage, Level, Next, button text).
**FAIL if** any displayed value changes: that means the screen had drifted from the server.

Stop the session.

### U-6 Gold stays exact just below 2^53 (Session 2; helpers needed)

**Setup:** fresh Play; Client view: H-1. Server view: do the **H-check** (section 4) if you have not.
**Steps:**
1. Server view: run **H-3** with the amount `9007199254740991` (2^53 − 1). Expected print: `ok = true`.
2. Client view: logger shows `Currency Gold=9007199254740991`; HUD shows `Gold: 9.01Qa`.
3. Click `Upgrade for 5 Gold` once.

**PASS if** the logger then shows exactly `[QA] Currency Gold=9007199254740986` (5 less, every digit exact), the HUD still shows `Gold: 9.01Qa`, and the panel shows `Level 2`.
**FAIL if** the logged balance is anything else (for example ends in 85 or 88, or contains `e`).

Stop the session.

### U-5 Exact-Gold version of level 24 → 25 (Session 2; helpers needed)

**Setup:** fresh Play (Gold 0, Level 1); Client view: H-1. Do not click the slime yet.
**Steps:**
1. Server view: run **H-3** with `257` (the total cost of levels 1→24).
2. Client view: click the Upgrade button **23 times** (about 3 clicks per second; extra clicks while the button is grey do nothing).
3. Check the screen. Server view: run H-3 with `23`.
4. Client view: click the button once more.
5. Click the slime until you reach stage 14 (each click defeats one enemy), then click once more.

**PASS if** all of:
- After step 2: `Gold: 0`, `Level 24`, `Tap Damage: 24` (panel and HUD), `Next: 75 damage`, button `Need 23 Gold`; the logger shows 23 `Ok` replies and the Gold sequence from Appendix E.2 ending at `Gold=0`.
- After step 4: `Gold: 0`, `Level 25`, `Tap Damage: 75` (panel and HUD), `Next: 78 damage`, button `Need 25 Gold`.
- Step 5: the first click on stage 1 shows `-10` (capped at the slime's 10 HP), `+5 Gold`; on stage 14 (`85 / 85`) the click shows `-75` and leaves `10 / 85`.

**FAIL if** Gold is not exactly 0 after steps 2 and 4, any level/damage differs, or a 24th purchase succeeded before the 23 Gold grant.

Keep this session for N-1 and N-3 (section 10).

---

## 7. Request abuse

### Session 3 — one player

Fresh Play; Client view; paste H-1. **Do the tests in this order**: the upgrade request ids must keep increasing, and after A-4 the in-game Upgrade button will stop responding for the rest of the session. That is expected (the server ignores request ids it has already passed) and is **not** a failure.

#### A-1 Malformed upgrade requests are ignored

**Steps (Client view):** paste Appendix C.7. It sends 16 malformed requests, 0.25 s apart (slower than the rate limit, so none is dropped by rate limiting), then prints `[QA] malformed upgrade requests sent: 16`.
**PASS if** no `[QA] Upgrade` line and no `[QA] Currency` line appears, Gold and Level do not change, and there is no red error in Output (client or server).
**FAIL if** any reply, any change, or any server error.

#### A-2 ClientReady junk and spam

**Steps (Client view):** paste Appendix C.8. Wait about 10 seconds for its result line.
**PASS if** `burst syncs` is 0 or 1, `spam syncs` is at most the printed limit (the server allows one full sync per second, so about 5 or 6 for the 5-second spam), there are no red errors, and the screen values never change.
**FAIL if** either count exceeds its limit, an error appears, or a value changes.

#### A-3 Replayed purchase requests are ignored

**Steps:**
1. Click the slime 10 times (Gold 5). Click the green Upgrade button once (this is request id 1). Check `Level 2`, `Gold: 0`.
2. Click the slime until Gold is at least 5 again (6 clicks on stage 2).
3. Client view, paste (replays id 1, then an older id 0):

   ```lua
   local R = game:GetService("ReplicatedStorage").Remotes R.RequestUpgrade:FireServer("TapDamage", 1) R.RequestUpgrade:FireServer("TapDamage", 0)
   ```

4. Wait 2 seconds. Then click the Upgrade button once (the client sends id 2).

**PASS if** step 3 produces **no** `[QA] Upgrade` and no `[QA] Currency` line, Gold and Level stay the same, and step 4 succeeds normally (`Level 3`, `result id=2 Ok`).
**FAIL if** the replay charges Gold or raises the level.

#### A-4 The server refuses an unaffordable purchase

**Steps:** With Gold below the next cost (after A-3, Gold is 0 and the next cost is 5), Client view, paste:

```lua
game:GetService("ReplicatedStorage").Remotes.RequestUpgrade:FireServer("TapDamage", 100)
```

**PASS if** the logger shows `result id=100 InsufficientFunds`, the panel flashes red `Not enough Gold`, and Gold and Level do not change.
**FAIL if** the purchase succeeds or Gold goes negative.
From now on the Upgrade button does nothing in this session (expected).

#### A-5 A burst of 100 purchase requests

**Steps:**
1. Server view: H-3 with `1000` (or, if helpers are blocked, click the slime until you have at least 60 Gold and use the general rule below).
2. Client view: paste Appendix C.9 (waits 3 s for the rate limiter to refill, sends 100 requests with ids 1001–1100 in one frame, waits, prints a summary).

**PASS if** the summary shows exactly **10** replies (`ok + insufficient + maxLevel = 10`; burst capacity is 10), Gold never shows a negative value, the number of levels gained equals `ok`, and Gold dropped by exactly the sum of those levels' costs (Appendix E.1). With the 1000 Gold grant right after A-4 the exact expectation is: `ok=10`, Level 3 → **13**, Tap Damage **13**, Gold 1000 → **925**.
**FAIL if** more than 10 replies, Gold negative, a level without a charge, or a charge without a level.

#### A-6 Sustained purchase requests are rate-limited

**Steps:** Client view: paste Appendix C.10 (50 requests, 0.05 s apart, ids 2001–2050). It prints its own limit.
**PASS if** `replies` in the summary is **≤** the printed limit (about 10 + 8 per second ≈ 30), Gold never negative, levels gained = `ok`.
**FAIL if** replies exceed the limit, or the money rules break. Record the actual number (much lower than ~30 is worth noting as an observation).

#### A-7 A client that sends the largest id only blocks itself

**Steps:** Client view: paste Appendix C.11.
**PASS if** its summary shows exactly **1** upgrade reply (the first request is processed, the identical second one is ignored) and no errors.
**FAIL if** 0 or 2 replies, or an error. Stop the session.

### Session 4 — two players

Start **2 players** (section 1.3). In **both** Player windows, Client view, paste H-1. Use the server window's Command Bar for server snippets, replacing `GetPlayers()[1]` with `FindFirstChild("Player1")` or `FindFirstChild("Player2")` as needed.

#### B-1 Combat is independent per player

**Steps:** In Player1's window, click its slime 10 times.
**PASS if** Player1 shows Stage 2, Gold 5, 11/11, and Player2 still shows Stage 1, Gold 0, 10/10, with **no** new `[QA]` lines in Player2's Output.
**FAIL if** anything changes for Player2.

#### B-2 Purchases are independent per player

**Steps:** Player1 clicks Upgrade (id 1 for Player1).
**PASS if** Player1 shows Level 2, Gold 0, Tap Damage 2; Player2 still Level 1, Gold 0, Tap Damage 1, and no new `[QA]` lines in Player2's Output.
**FAIL if** Player2 receives anything or changes.

#### B-3 Request ids are per player (cross-player replay)

**Steps:** In **Player2's** Command Bar paste:

```lua
game:GetService("ReplicatedStorage").Remotes.RequestUpgrade:FireServer("TapDamage", 1)
```

**PASS if** Player2's logger shows `result id=1 InsufficientFunds` (it is Player2's own first request and Player2 has 0 Gold), Player2's panel flashes `Not enough Gold`, and Player1's Output shows nothing new and Player1's values do not change.
**FAIL if** Player1 is affected, or Player2 is charged.

#### B-4 A client cannot act for another player

**Steps:** Player2 clicks its slime until it has at least 5 Gold (10 clicks). Then in Player2's Command Bar:

```lua
game:GetService("ReplicatedStorage").Remotes.RequestUpgrade:FireServer("TapDamage", 2, game:GetService("Players"):FindFirstChild("Player1"))
```

**PASS if** the purchase happens for **Player2** (Player2: `result id=2 Ok`, Level 2, Gold 0) and Player1 is unchanged with nothing new in its Output.
**FAIL if** Player1 is charged or levelled.
Player2's own Upgrade button will now be ignored for this session (its counter is behind id 2); that is expected.

#### B-5 Each player's replay protection is still independent

**Steps:** In Player1's Command Bar, replay its id 1 (`…FireServer("TapDamage", 1)`). Then, after clicking until Player1 has 5 Gold, click Player1's Upgrade button.
**PASS if** the replay produces no reply and no charge, and the button purchase then succeeds (`result id=2 Ok` in Player1's logger).
**FAIL if** the replay charges, or Player1's button purchase is ignored.

Continue with L-1 (section 11) in this same two-player session.

---

## 8. Delayed requests and synchronization

**Session 5.** Studio can delay network traffic: **File → Studio Settings → Network → Incoming Replication Lag** (seconds). (It is the `NetworkSettings.IncomingReplicationLag` setting; you can also set it in the edit-mode Command Bar with `settings().Network.IncomingReplicationLag = 1`.) **Set it back to 0 when you finish this session.**

How to tell it works: with lag on, the white ripple appears the moment you click, but HP changes only after the delay. If HP changes instantly even with lag set, mark the D tests **BLOCKED** ("lag setting had no effect") and continue.

### D-4 Startup sync with heavy lag (run first)

**Steps:** Set lag to **4**. Clear Output, Play, and wait 20 seconds without clicking.
**PASS if** the HUD shows `Connecting...` for several seconds, then fills in with Stage 1, Gold 0, 10/10, Level 1; Output may show `[CombatClient] No combat sync yet; re-sending ClientReady (attempt 1/3)` (and attempt 2) — allowed here — but **not** `Combat state never arrived`, and no red errors.
**FAIL if** the HUD never fills in, `Combat state never arrived` appears while the HUD is still empty, or any red error.

### D-1 Taps under lag: exactly-once defeat

**Steps:** Stop, set lag to **1**, Play, Client view, H-1 and `_G.QA.reset()`. Click the slime 10 times at about 3 clicks per second, then wait 3 seconds. `_G.QA.summary()`.
**PASS if** the HP shown always equals 10 minus the number of accepted hits; if `hits + defeats` reached 10 there is exactly **one** defeat, exactly one `+5 Gold`, Gold 5 and Stage 2. (Lag can bunch requests so a few arrive closer than 0.07 s and are dropped by the server; then fewer than 10 hits is correct. Click until the slime is defeated and check the same rules.)
**FAIL if** two defeats or two Gold rewards for one enemy, or HP that disagrees with the accepted hits.

### D-2 Two purchase clicks before the first reply arrives

**Steps:** Continue (Gold 5, Level 1). Click the green Upgrade button twice, about 0.5 s apart, both within the 1-second lag. Wait 3 seconds.
**PASS if** exactly one purchase succeeds: final `Level 2`, `Gold: 0`, `Tap Damage: 2`; the logger shows `ok=1` and either one `InsufficientFunds` reply (the second click was sent before the client heard about the new balance) or none (the button had already turned grey). Gold never shows a negative number.
**FAIL if** Level 3, negative Gold, or Gold other than 0.

### D-3 Several purchases in flight; final state converges

**Steps:** Click the slime until Gold is at least 16. Then click the Upgrade button three times about 0.3 s apart. Wait 3 seconds. Take a screenshot. Paste H-2 (resync) and wait 3 seconds.
**PASS if** levels gained equal the `Ok` replies, Gold dropped by exactly their costs (Appendix E.1), Gold was never negative, and the resync changes **nothing** on screen.
**FAIL if** the resync changes any displayed value, or the money rules break. If the logger shows replies or currency updates in an unexpected order, copy those lines into the report as an observation.

Stop, set lag back to **0**.

---

## 9. Mobile UI, rotation and touch

**Session 6.** Use the device emulator (section 1.4). Test at least: one phone **with a notch** (any recent iPhone), one Android phone, one **small** phone, and one tablet. For every device, test **portrait and landscape**. In each Play session paste H-1 and the input diagnostic (Appendix C.12), Client view.

### MOB-1 Portrait layout

**PASS if**, on each phone in portrait: Stage and Gold pills, enemy name, health bar with HP text, Tap Damage pill and the whole upgrade panel (title, three labels, button, status line) are fully visible, not under the notch, rounded corners or Roblox's top-bar buttons; text is readable; the panel does not cover the Stage/Gold pills, the health bar or the Tap Damage pill.
**FAIL if** anything is cut off, unreadable, or overlapping as described. If the panel partly covers the slime model but you can still tap the slime easily, note it as an observation, not a FAIL.

### MOB-2 Landscape layout

Same as MOB-1 in landscape, on each phone. Pay attention to the notch side.

### MOB-3 One tap = one attack

**Steps:** `_G.QA.reset()`. Tap the slime 10 times, slowly. `_G.QA.summary()`.
**PASS if** `hits + defeats = 10`, and the input diagnostic printed one `[QA] input Touch processed=false` per tap (an extra `MouseButton1` line per tap is fine as long as hits stay 10).
**FAIL if** any single tap produced two hits, or a tap produced none.

### MOB-4 Panel and button taps never attack

**Steps:** `_G.QA.reset()`. Tap 10 times on different parts of the upgrade panel (title, labels, status line, the panel's four edges just inside the border) and 10 times on the Upgrade button. `_G.QA.summary()`. Repeat in the other orientation.
**PASS if** `hits=0 defeats=0` each time. With enough Gold, button taps buy upgrades only (never also an attack).
**FAIL if** any of these taps caused a hit.

### MOB-5 Edges of the combat area and safe-area insets

**Steps (portrait and landscape, on the notched phone):**
1. `_G.QA.reset()`. Tap 5 times each on the Stage pill, the Gold pill and the Tap Damage pill. `_G.QA.summary()` → must show no hits.
2. `_G.QA.reset()`. Tap once just **outside** the panel's left edge (about a finger-width to its left) and once just **outside** its top edge, both still in the combat area. `_G.QA.summary()` → must show 2 hits.

**PASS if** step 1 shows `hits=0 defeats=0` and step 2 shows `hits + defeats = 2`. The input diagnostic positions help you see where your taps landed.
**FAIL if** pills attack, or taps right next to the panel are swallowed (that would suggest the panel's tap-blocking rectangle is offset from what you see, which is the inset risk the audit asked to test). Note the device, orientation and the printed positions.

### MOB-6 Rotate during combat

**Steps:** Keep tapping the slime and rotate the emulator 4 times (portrait → landscape → portrait → landscape) while tapping. After each rotation, tap the panel 3 times and the slime 3 times.
**PASS if** after every rotation the layout re-arranges within about a second, slime taps still attack, panel taps still never attack, HP/Gold/Stage stay correct, and no errors appear. In Explorer (Client view), **Players → (you) → PlayerGui** contains exactly one `CombatHud` and one `UpgradePanel`.
**FAIL if** taps stop working, the panel blocks the wrong area, a second HUD appears, or errors appear.

### MOB-7 Small phone and tablet

Repeat MOB-1, MOB-2 and MOB-4 quickly on the smallest phone in the list and on a tablet.
**PASS / FAIL** as in those tests.

### MOB-8 (optional) Touchscreen laptop: no double attack

Only if you have a touchscreen Windows PC. Without the emulator, tap the slime with your finger 10 times. **PASS if** exactly 10 hits (touch plus the emulated mouse click must count once). **FAIL if** more.

### MOB-9 (optional) Physical phone

Emulation is not a real phone. If you choose to, publish a **private** copy of the place and play it on a real entry-level phone for 10 minutes of tapping and buying. Note: unit tests do not run in live servers, and `[CombatService]` join/leave lines print there too (`GameConfig.Debug.LogPlayerLifecycle = true`). **PASS if** play stays smooth and nothing in MOB-1 to MOB-6 fails. Record the phone model. Publishing is your decision; skip with NOT RUN if you prefer.

### N-6 Long numbers fit on the smallest phone (portrait)

**Steps:** On the smallest phone in portrait: Server view, H-3 with `1.5e400`; H-5 with `1e5000`. Look at the HUD and panel.
**PASS if** `Gold: 1.5e400` and `Tap Damage: 1e5000` are readable and stay inside their pills, nothing overlaps.
**FAIL if** text overflows its pill, is cut off, or shows `inf`, `nan` or a minus sign.

---

## 10. Scientific-number display

Continue in **Session 2** after U-5 (Level 25, around stage 14). Appendix E.3 lists expected display strings.

### N-1 BigNum display and parsing in the real Roblox engine

**Steps:** Paste Appendix C.13 (Client view is fine; it uses only the shared BigNum module).
**PASS if** it prints `[QA] BigNum spot checks: PASS` with no `[QA]` warnings above it. It checks 12 display strings, 13 malformed strings that must be rejected without an error (including the audit's `10e9007199254740991`), the canonical text round trip, and that 2^53 − (2^53 − 1) = 1 (audit F1).
**FAIL if** it prints `FAIL (n)`; copy the warning lines.

### N-3 Huge tap damage shows in scientific notation

**Steps:** Server view: H-5 with `1e5000`. Look at the HUD, then click the slime once.
**PASS if** the bottom HUD shows `Tap Damage: 1e5000`; the click defeats the enemy and the popup shows the enemy's remaining HP (not `1e5000`, because damage is capped at the remaining HP).
**Also expected (not a FAIL):** the panel still shows `Tap Damage: 75` (the upgrade's own value). In Milestone 2, tap damage is overwritten, not combined; buying an upgrade later sets it back to the upgrade's value. This is the known gap that the approved Milestone 2.1 StatService will fix (`M2_REQUIREMENTS.md`, Known gaps).
**FAIL if** the HUD shows `inf`, `nan`, a long row of digits, or anything other than `1e5000`.

### N-4 High-stage HP in scientific notation

**Steps:** Client view: paste Appendix C.14. It attacks every 0.08 s until stage 600 (about 50–80 seconds), with logging paused, then prints a summary.
**PASS if** the HUD ends around **Stage 600 or 601** and shows HP in scientific form matching Appendix E.3 (for example stage 600: `1.14e44 / 1.14e44`; stage 601: `1.35e44 / 1.35e44`); Gold is shown with a suffix such as `12.63No` (exact value depends on earlier play); no `inf`, `nan` or minus sign anywhere; no red errors.
**FAIL if** any of those appear, the stage stops advancing, or HP is not in the expected format.

### N-5 Health bar at large values

**Steps:** Server view: H-5 with `6e43`. Client view: click the slime **once**.
**PASS if** HP shows a smaller value than max in scientific form (stage 600: `5.41e43 / 1.14e44`; other stages: Appendix E.3), and the red fill shrinks to roughly that fraction (about 45–70 % of the bar), staying inside the bar's frame. Each further click removes another 6e43 until the enemy is defeated; the new enemy's bar is full.
**FAIL if** the bar overflows its frame, is empty while HP is above zero, or the text shows `inf`/`nan`.

### N-2 Purchases with a huge Gold balance

**Steps:** Server view: H-3 with `1.5e400`. Client view: check `Gold: 1.5e400`. Click the Upgrade button 3 times (about 1 per second).
**PASS if** each click gives `Upgraded!` and the level rises by exactly 1 each time; Gold still shows `1.5e400` and the logger shows `Currency Gold=1.5e400` after each purchase; the HUD `Tap Damage` changes to the upgrade's value again (for example 78, 81, 84; see N-3's note).
**Expected under the current documentation (not a FAIL):** the balance does not visibly drop, because a 25–29 Gold cost is about 10^-399 of 1.5e400 and BigNum keeps about 17 significant digits (`M2_REVIEW_GUIDE.md` §10, "Precision absorption"; also decision 1 in section 0.1).
**FAIL if** Gold shows a negative value, `inf` or `nan`, or a purchase fails or levels twice.

### L-3 Restart gives a fresh game (no persistence in M2)

**Steps:** Stop, then Play again.
**PASS if** Stage 1, Gold 0, 10/10, Level 1, Tap Damage 1 (Milestone 2 has no saving).
**FAIL if** any progress carried over.

---

## 11. Leave / rejoin and sustained-combat cleanup

### In the Session 4 two-player test (after B-5)

#### L-1 A player leaves mid-combat; the server cleans up

**Steps:**
1. Server window, Command Bar: paste Appendix D.5 (`capture`). Then paste Appendix D.6 (`check`). Expected: `[QA] Player2 currency=true combat=true level=<a number> session=true`.
2. In Player2's window, click its slime a few times, then **close Player2's window** (the player leaves).
3. Server window: read Output, then paste Appendix D.6 again.
4. In Player1's window, click the slime 5 times and, if affordable, buy an upgrade.

**PASS if**: the server Output shows `[CombatService] Removed combat state for Player2 (tracked players: 1)`; the second D.6 prints `currency=false combat=false level=nil session=false`; no red errors in any window; Player1 keeps playing normally.
**FAIL if** anything for Player2 is still `true`/non-nil after leaving, an error appears, or Player1 is affected.
(The rate-limiter entry is also removed on leave, `UpgradeService.luau:183-186`; Studio cannot show it, so it is checked by source only.)
If the helpers were "not connected" in the H-check, use the bridge's `capture` / `afterLeave` actions (Appendix D.4) instead.

#### L-2 A new player joins the running server and starts fresh

**Steps:** In the **Server** window's Test tab, Clients and Servers area, set the player count to 1 and click **Start** again. If your Studio adds a new player window (usually named Player2 or Player3), paste H-1 there.
**PASS if** the server prints `[CombatService] Created combat state for <name> (tracked players: 2)`, the new player sees Stage 1, Gold 0, 10/10, Level 1, Tap Damage 1, and Player1 is unchanged.
**FAIL if** the new player inherits anyone's progress, Player1 changes, or errors appear.
**BLOCKED** if your Studio cannot add a player to a running server; write down your Studio version. (L-3 already covers a full restart.)

#### L-4 Leaving while requests are still arriving

**Steps:** In the newest player's window, paste Appendix C.10 (sustained purchase loop). It starts sending after 3 seconds and keeps sending for about 2.5 seconds: close that player's window about 4 seconds after pasting, while requests are still being sent.
**PASS if** the server prints the `Removed combat state for …` line, there are no red errors in the server Output, and Player1 is unaffected.
**FAIL if** the server shows any error.

Click **Cleanup** to end Session 4.

### Session 7 — sustained-combat cleanup (one player)

Fresh Play; Client view: H-1. The counts snippet is Appendix C.15. "Wait 3 seconds idle" means: no clicks, no running loops, for 3 seconds.

#### C-1 Baseline object counts

**Steps:** Wait 3 seconds idle, paste C.15.
**PASS if** it prints `TapArea=1 GoldPill=5 CombatStage=2` (the tap hint label; the gold pill's five parts; the arena plus exactly one enemy). Write down the three numbers after the `|` (`hud=`, `panel=`, `stage=`); they are your baseline.
**FAIL if** the first three numbers differ.

#### C-2 Fast manual clicking leaves nothing behind

**Steps:** Click the slime as fast as you can for 60 seconds (buy upgrades when the button turns green, if you like). Wait 3 seconds idle. Paste C.15.
**PASS if** `TapArea=1 GoldPill=5 CombatStage=2` again. (During clicking, ripples, damage numbers and an old enemy's defeat animation exist briefly; they must all be gone after the pause.)
**FAIL if** any count is higher after the pause.

#### C-3 Ten minutes of enemy churn

**Steps:**
1. Server view: H-5 with `1e5000` (every hit defeats the enemy, so a new enemy spawns about 12 times per second).
2. Client view: paste Appendix C.16. It attacks every 0.08 s for 10 minutes with logging paused. To stop early, paste `_G.QA_RUN = false`.
3. Optional: press **F9** (Developer Console) → **Memory** and write down the client memory total at 1, 5 and 10 minutes.
4. When it prints `[QA] auto-attack ran …` and the summary, wait 3 seconds idle and paste C.15.

**PASS if** C.15 prints `TapArea=1 GoldPill=5 CombatStage=2` and `hud=`, `panel=`, `stage=` equal your C-1 baseline (every enemy model has the same parts); the HUD shows a stage in the thousands with HP and Gold in scientific notation (no `inf`, `nan`, minus sign); there are no red errors in Output; the game kept responding.
**FAIL if** any count stays higher after the pause, any error appears, or the game freezes.
**Observation (not pass/fail):** memory readings. If memory rose steadily at every reading and never levelled off, say so in the report.

#### C-4 Three minutes at tap damage 1 (mostly hits)

**Steps:** Stop, Play (fresh, Tap Damage 1, so most requests are hits and only about 20 enemies are defeated). Client view: H-1. Paste C.16 and stop it after 3 minutes with `_G.QA_RUN = false`. Wait 3 seconds idle, paste C.15.
**PASS if** `TapArea=1 GoldPill=5 CombatStage=2` and `hud=`, `panel=`, `stage=` equal the baseline from C-1. **FAIL if** not.

#### C-5 Long manual session (repeat of the Milestone 1 stress test)

**Steps:** Play normally for 10 minutes: tap, buy upgrades, rotate if using the emulator.
**PASS if** no errors, no slowdown you can notice, and C.15 at the end is back to the baseline after 3 seconds idle. **FAIL if** errors or stuck/slow UI.

---

## 12. Collecting Output and reporting failures

### 12.1 For every session

1. Before Play: right-click Output → **Clear Output**.
2. After the session: click inside Output, press **Ctrl+A** then **Ctrl+C** (or use the Output's right-click menu to select all and copy, or drag-select the lines), and paste into a plain-text file named `QA_<session>_<window>.txt`, for example `QA_S4_Server.txt`, `QA_S4_Player1.txt`.
3. In two-player sessions, copy **each** window's Output separately (Server, Player1, Player2).
4. The Developer Console (F9 while playing → **Log**) shows the same messages and can help if the Output window was cleared.

### 12.2 When a test fails

1. Do not stop the session yet. Take a screenshot of the whole Studio window (Windows: Win+Shift+S; Mac: Cmd+Shift+4) showing the game view and Output.
2. Copy the failing Output lines. For a red error, copy the red line **and** the lines right after it (Roblox prints `Stack Begin`, the script name and line number, `Stack End`).
3. Paste `_G.QA.summary()` (Client view) and copy its line.
4. If you can, try the test once more from a fresh Play and note "reproduced 2/2" or "1/2".
5. Fill in a failure report (template in `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`): test ID, device/orientation or session type, exact steps, expected, actual, Output lines, screenshot file names, reproduced count, and the P-3 parity line.
6. Do not edit scripts to work around the failure and do not retest with modified code. Leave severity to the reviewer.

### 12.3 Messages that are allowed or forbidden

| Output text | Meaning | Verdict |
|---|---|---|
| `[CombatService] Created/Removed combat state for … (tracked players: N)` | Normal join/leave log | Allowed (info) |
| `[Tests] …: N passed, 0 failed`, `[Tests] ALL PASSED (61 tests)` | Unit tests | Allowed (info) |
| `[QA] …`, `[Parity] ok …` | This guide's helpers | Allowed (info) |
| `[CombatClient] No combat sync yet; re-sending ClientReady (attempt n/3)` | Sync retry | Allowed **only in D-4** (FAIL in M1-1) |
| `[CombatClient] Could not disable the reset button …` | Cosmetic | Allowed; mention it in the notes |
| Lines from a Studio plugin or from Studio itself (they name a plugin, or none of the 24 scripts and no `[…]` tag) | Not Emberbound | Allowed; copy them into the notes. If a plugin prints red errors, disable that plugin and repeat the test |
| `[Tests] FAIL …`, `[Tests] n FAILED, m passed` | Unit test failure | FAIL (T-1), except the two expected lines in T-2 |
| `[Parity] FAIL …` | Install mismatch | Fix the install, re-run P-3 |
| `[QA] format …`, `[QA] parse should return nil …`, `[QA] … FAIL` | Spot-check failure | FAIL of that test |
| `[CombatClient] Ignored a malformed …`, `… with invalid numbers/values` | Server sent bad data | FAIL |
| `[CombatClient] Combat state never arrived …` | Sync failed | FAIL |
| `[CombatService] Rejected invalid damage amount …` | Invalid damage reached ApplyDamage | FAIL |
| `[CurrencyService] Rejected Gold grant …` | Only expected if **you** passed an invalid amount to H-3 | Otherwise FAIL |
| `[PlayerSessionService] Could not start a session …` | Join failed | FAIL |
| `… Start() was called more than once …` | Duplicate server script | FAIL (check P-3) |
| `[ServerInit] Players.CharacterAutoLoads should be false …` | Setting not unticked | FAIL of P-1 (fix it) |
| `[CombatHud] Used before Mount`, `[ArenaView] ShowEnemy called before Mount`, `[UpgradeService] No effect is defined …` | Internal order problem | FAIL |
| `Infinite yield possible …`, `Missing RemoteEvent …` | Missing or misnamed object | FAIL (check P-3) |
| Any other **red** line | Error | FAIL |

### 12.4 What to send back

The filled-in results file, all `QA_*.txt` Output files, screenshots of every FAIL, your Studio version and OS, and which helper case you had in the H-check. Send them to the reviewer the same way the Milestone 1 QA report was handled. PR #1 stays unmerged until the reviewer accepts the results.

---

## Appendix A — the 24 files

Create them in this order. "Parent" is the Explorer path. SHA-256 values are the round 2 manifest in `SOURCE_HASHES.txt`; bytes, lines and Adler-32 are what the parity checker compares.

| # | Parent (Explorer) | Name | Class | Repository file |
|---|---|---|---|---|
| 1 | ReplicatedStorage > Shared | `BigNum` | **ModuleScript** | [`src/ReplicatedStorage/Shared/BigNum.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ReplicatedStorage/Shared/BigNum.luau) |
| 2 | ReplicatedStorage > Shared | `GameConfig` | **ModuleScript** | [`src/ReplicatedStorage/Shared/GameConfig.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ReplicatedStorage/Shared/GameConfig.luau) |
| 3 | ReplicatedStorage > Shared | `ProgressionConfig` | **ModuleScript** | [`src/ReplicatedStorage/Shared/ProgressionConfig.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ReplicatedStorage/Shared/ProgressionConfig.luau) |
| 4 | ServerScriptService | `CombatRules` | **ModuleScript** | [`src/ServerScriptService/CombatRules.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/CombatRules.luau) |
| 5 | ServerScriptService | `CombatService` | **ModuleScript** | [`src/ServerScriptService/CombatService.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/CombatService.luau) |
| 6 | ServerScriptService | `CurrencyService` | **ModuleScript** | [`src/ServerScriptService/CurrencyService.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/CurrencyService.luau) |
| 7 | ServerScriptService | `PlayerSessionService` | **ModuleScript** | [`src/ServerScriptService/PlayerSessionService.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/PlayerSessionService.luau) |
| 8 | ServerScriptService | `RateLimiter` | **ModuleScript** | [`src/ServerScriptService/RateLimiter.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/RateLimiter.luau) |
| 9 | ServerScriptService | `ServerInit` | **Script** | [`src/ServerScriptService/ServerInit.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/ServerInit.luau) |
| 10 | ServerScriptService | `UpgradeService` | **ModuleScript** | [`src/ServerScriptService/UpgradeService.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/UpgradeService.luau) |
| 11 | ServerScriptService | `Wallet` | **ModuleScript** | [`src/ServerScriptService/Wallet.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Wallet.luau) |
| 12 | ServerScriptService > Tests | `BigNumTests` | **ModuleScript** | [`src/ServerScriptService/Tests/BigNumTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/BigNumTests.luau) |
| 13 | ServerScriptService > Tests | `CombatFormulaTests` | **ModuleScript** | [`src/ServerScriptService/Tests/CombatFormulaTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/CombatFormulaTests.luau) |
| 14 | ServerScriptService > Tests | `CombatRulesTests` | **ModuleScript** | [`src/ServerScriptService/Tests/CombatRulesTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/CombatRulesTests.luau) |
| 15 | ServerScriptService > Tests | `ProgressionTests` | **ModuleScript** | [`src/ServerScriptService/Tests/ProgressionTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/ProgressionTests.luau) |
| 16 | ServerScriptService > Tests | `RateLimiterTests` | **ModuleScript** | [`src/ServerScriptService/Tests/RateLimiterTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/RateLimiterTests.luau) |
| 17 | ServerScriptService > Tests | `TestKit` | **ModuleScript** | [`src/ServerScriptService/Tests/TestKit.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/TestKit.luau) |
| 18 | ServerScriptService > Tests | `TestKitTests` | **ModuleScript** | [`src/ServerScriptService/Tests/TestKitTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/TestKitTests.luau) |
| 19 | ServerScriptService > Tests | `TestRunner` | **Script** | [`src/ServerScriptService/Tests/TestRunner.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/TestRunner.luau) |
| 20 | ServerScriptService > Tests | `WalletTests` | **ModuleScript** | [`src/ServerScriptService/Tests/WalletTests.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/ServerScriptService/Tests/WalletTests.luau) |
| 21 | StarterPlayer > StarterPlayerScripts | `CombatClient` | **LocalScript** | [`src/StarterPlayer/StarterPlayerScripts/CombatClient.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/StarterPlayer/StarterPlayerScripts/CombatClient.luau) |
| 22 | StarterPlayer > StarterPlayerScripts > CombatClient | `ArenaView` | **ModuleScript** | [`src/StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView.luau) |
| 23 | StarterPlayer > StarterPlayerScripts > CombatClient | `CombatHud` | **ModuleScript** | [`src/StarterPlayer/StarterPlayerScripts/CombatClient/CombatHud.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/StarterPlayer/StarterPlayerScripts/CombatClient/CombatHud.luau) |
| 24 | StarterPlayer > StarterPlayerScripts > CombatClient | `UpgradePanel` | **ModuleScript** | [`src/StarterPlayer/StarterPlayerScripts/CombatClient/UpgradePanel.luau`](https://github.com/zelly-cious/Emberbound/blob/e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf/src/StarterPlayer/StarterPlayerScripts/CombatClient/UpgradePanel.luau) |

Checksums (for P-3 and P-4):

| # | Name | Bytes | Lines | Adler-32 | SHA-256 |
|---|---|---|---|---|---|
| 1 | `BigNum` | 15064 | 508 | 3533007835 | `c7474136d45bada326484a786fd60ff5ca02a18a12b4012fbcfca01a3950244a` |
| 2 | `GameConfig` | 5692 | 152 | 3501233795 | `2cefa5f694865e6682a8a9d8f04d0d1885499829ee1466a4dc227c9b4f070591` |
| 3 | `ProgressionConfig` | 5662 | 139 | 681296945 | `7d6483b06a155ca93bd2c408004cf2a3dd9bd797ca4d224cb69a4f1ba041ea80` |
| 4 | `CombatRules` | 2797 | 90 | 1984805962 | `1e18a1a78f25cbee8e325e6356a6875d3944db9f51604ec2d8f059d26a2a1d37` |
| 5 | `CombatService` | 7456 | 235 | 543955029 | `05998af20c81089f7fdc49f487877c0b38cd30af5a22169018aedf24af7c7bc3` |
| 6 | `CurrencyService` | 4563 | 140 | 1885359857 | `3a6bb75a0d93fb373fc2babfc481a39a680a48cf6f442c563f1f091e7d78c4d0` |
| 7 | `PlayerSessionService` | 4516 | 147 | 4289999976 | `81d56e8e9cab0264b0d74d01977845153f70ec6848afc51887882e461e66d646` |
| 8 | `RateLimiter` | 1886 | 66 | 2585428194 | `493d3758fd52adb6cca7a9bbb6e61831219fce75c4c9ee45e3ce1d3cf2a3e296` |
| 9 | `ServerInit` | 1105 | 27 | 852134481 | `cdc062557c5b3e3a796058c343b5622c8974dfb3727323809aafbf88156b7f98` |
| 10 | `UpgradeService` | 7868 | 222 | 700827497 | `489bfa3f97555790c69bdb5adf7d758be0230a54eda5cfdf50916c689e00bb8f` |
| 11 | `Wallet` | 2629 | 80 | 354195652 | `98fb07db5e0dbefb87e35e606e40aba98257bf9e0209b513b4ba372f2d16634c` |
| 12 | `BigNumTests` | 13960 | 383 | 755231800 | `0c13e4842d1420b285243e824c012bca32cbe13e09df278af53ae709d914d97a` |
| 13 | `CombatFormulaTests` | 3327 | 87 | 1867459093 | `91b557d4c31584050ef8589586439a04771279f34f25f842fd88b812311f56bb` |
| 14 | `CombatRulesTests` | 4399 | 118 | 839619764 | `5f2bd8ac8ce428334aefa5780760a86e96b3539f451dd4f34046c4be48900827` |
| 15 | `ProgressionTests` | 4170 | 128 | 3226287864 | `8d019e1c842334f5692c6debb59933268f50965678281beb33b6ccd814a9e953` |
| 16 | `RateLimiterTests` | 2042 | 65 | 2206831031 | `0a9b237905367c963dd3f83aefaf668295105de941f716c5d516e08c11ec1faa` |
| 17 | `TestKit` | 4287 | 138 | 3224874915 | `da6a4882d5177dc5537871a3aff302b2692e0fcd293e18f4993f6b763ccea969` |
| 18 | `TestKitTests` | 4545 | 151 | 991929235 | `74454d4a387afc7c9f7eecbf801506c9fb089528298c3ee4c64b1bc200198bd0` |
| 19 | `TestRunner` | 1574 | 45 | 1141053416 | `e3a24f14a5a5a14bd9838502eea7a5b8111480e596a2c894db0701af6b96c512` |
| 20 | `WalletTests` | 7186 | 174 | 2575493603 | `5c8713a664951176f02104f3461899c08d9677ddfa51201b3b8c06147c783fb6` |
| 21 | `CombatClient` | 10496 | 291 | 1711349078 | `fb56fece6ba29d4ea31ef308a4de775355c1079f7266d882d42a828e190c67ca` |
| 22 | `ArenaView` | 15520 | 528 | 2016899911 | `b3e05e45d0c907b4242b05b055d11dc1105cb0f2733fd3351e8130b63f7495e0` |
| 23 | `CombatHud` | 13480 | 424 | 4051264347 | `3da101a67005c8957e993f370eb8c15bf20dca37c2b5be220eace41341ce3314` |
| 24 | `UpgradePanel` | 10325 | 358 | 3892797615 | `45f9380a7cc4376bbc5ce8025c4d9692244dd32059a45a3e033af045478fb5f5` |

Folders: `ReplicatedStorage/Shared`, `ReplicatedStorage/Remotes`, `ServerScriptService/Tests`. RemoteEvents (in `ReplicatedStorage/Remotes`): `RequestAttack`, `ClientReady`, `CombatUpdate`, `RequestUpgrade`, `UpgradeUpdate`, `CurrencyUpdate`. Setting: `Players.CharacterAutoLoads` = false.

---

## Appendix B — source-parity checker

**Edit mode only** (not while playing). Paste the whole block into the Command Bar and press Enter. It only reads; it changes nothing.

```lua
local E = {
	{ "ReplicatedStorage/Shared/BigNum", "ModuleScript", 15064, 508, 3533007835 },
	{ "ReplicatedStorage/Shared/GameConfig", "ModuleScript", 5692, 152, 3501233795 },
	{ "ReplicatedStorage/Shared/ProgressionConfig", "ModuleScript", 5662, 139, 681296945 },
	{ "ServerScriptService/CombatRules", "ModuleScript", 2797, 90, 1984805962 },
	{ "ServerScriptService/CombatService", "ModuleScript", 7456, 235, 543955029 },
	{ "ServerScriptService/CurrencyService", "ModuleScript", 4563, 140, 1885359857 },
	{ "ServerScriptService/PlayerSessionService", "ModuleScript", 4516, 147, 4289999976 },
	{ "ServerScriptService/RateLimiter", "ModuleScript", 1886, 66, 2585428194 },
	{ "ServerScriptService/ServerInit", "Script", 1105, 27, 852134481 },
	{ "ServerScriptService/UpgradeService", "ModuleScript", 7868, 222, 700827497 },
	{ "ServerScriptService/Wallet", "ModuleScript", 2629, 80, 354195652 },
	{ "ServerScriptService/Tests/BigNumTests", "ModuleScript", 13960, 383, 755231800 },
	{ "ServerScriptService/Tests/CombatFormulaTests", "ModuleScript", 3327, 87, 1867459093 },
	{ "ServerScriptService/Tests/CombatRulesTests", "ModuleScript", 4399, 118, 839619764 },
	{ "ServerScriptService/Tests/ProgressionTests", "ModuleScript", 4170, 128, 3226287864 },
	{ "ServerScriptService/Tests/RateLimiterTests", "ModuleScript", 2042, 65, 2206831031 },
	{ "ServerScriptService/Tests/TestKit", "ModuleScript", 4287, 138, 3224874915 },
	{ "ServerScriptService/Tests/TestKitTests", "ModuleScript", 4545, 151, 991929235 },
	{ "ServerScriptService/Tests/TestRunner", "Script", 1574, 45, 1141053416 },
	{ "ServerScriptService/Tests/WalletTests", "ModuleScript", 7186, 174, 2575493603 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient", "LocalScript", 10496, 291, 1711349078 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView", "ModuleScript", 15520, 528, 2016899911 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient/CombatHud", "ModuleScript", 13480, 424, 4051264347 },
	{ "StarterPlayer/StarterPlayerScripts/CombatClient/UpgradePanel", "ModuleScript", 10325, 358, 3892797615 },
}
local problems = 0
local function bad(text) problems += 1 warn("[Parity] FAIL " .. text) end
local function find(path) local parts = string.split(path, "/") local node = game:GetService(parts[1]) for i = 2, #parts do if node == nil then return nil end node = node:FindFirstChild(parts[i]) end return node end
local function adler(s) local a, b = 1, 0 for i = 1, #s do a = (a + string.byte(s, i)) % 65521 b = (b + a) % 65521 end return b * 65536 + a end
local expected = {}
local matched = 0
for _, e in E do
	local node = find(e[1])
	if node == nil then
		bad(e[1] .. " is missing (check its name and parent)")
	elseif node.ClassName ~= e[2] then
		bad(e[1] .. " is a " .. node.ClassName .. ", it must be a " .. e[2])
	else
		expected[node] = true
		local same = 0
		for _, sibling in node.Parent:GetChildren() do if sibling.Name == node.Name then same += 1 end end
		local text = string.gsub(node.Source, "\r\n", "\n")
		text = string.gsub(text, "%s+$", "") .. "\n"
		local _, lines = string.gsub(text, "\n", "")
		local sum = adler(text)
		if same > 1 then
			bad(e[1] .. " exists " .. same .. " times; keep exactly one")
		elseif #text ~= e[3] or lines ~= e[4] or sum ~= e[5] then
			bad(string.format("%s content differs: %d bytes, %d lines, checksum %d (expected %d, %d, %d)", e[1], #text, lines, sum, e[3], e[4], e[5]))
		elseif node:IsA("BaseScript") and not node.Enabled then
			bad(e[1] .. " is disabled; tick Enabled in Properties")
		elseif node.ClassName == "Script" and node.RunContext == Enum.RunContext.Client then
			bad(e[1] .. " has RunContext = Client; set it to Legacy")
		else
			matched += 1
			print("[Parity] ok   " .. e[1])
		end
	end
end
for _, path in { "ReplicatedStorage/Shared", "ReplicatedStorage/Remotes", "ServerScriptService/Tests" } do local f = find(path) if f == nil or f.ClassName ~= "Folder" then bad(path .. " must be a Folder") end end
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local remoteCount = 0
for _, name in { "RequestAttack", "ClientReady", "CombatUpdate", "RequestUpgrade", "UpgradeUpdate", "CurrencyUpdate" } do
	local r = (if remotes then remotes:FindFirstChild(name) else nil)
	if r == nil or r.ClassName ~= "RemoteEvent" then bad("ReplicatedStorage/Remotes/" .. name .. " must be a RemoteEvent") else remoteCount += 1 end
end
if remotes and #remotes:GetChildren() ~= 6 then bad("ReplicatedStorage/Remotes must hold exactly the 6 RemoteEvents (it has " .. #remotes:GetChildren() .. " children)") end
if game:GetService("Players").CharacterAutoLoads then bad("Players.CharacterAutoLoads must be unticked (false)") end
local extra = 0
for _, serviceName in { "Workspace", "ReplicatedFirst", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService" } do
	for _, d in game:GetService(serviceName):GetDescendants() do
		if d:IsA("LuaSourceContainer") and not expected[d] then extra += 1 bad("extra script " .. d:GetFullName() .. " (" .. d.ClassName .. "); delete it unless this guide told you to add it") end
	end
end
print(string.format("[Parity] scripts matching: %d / 24, remotes: %d / 6, extra scripts: %d", matched, remoteCount, extra))
if problems == 0 and matched == 24 then print("[Parity] RESULT: PASS") else warn("[Parity] RESULT: FAIL (" .. problems .. " problem(s) listed above)") end
```

---

## Appendix C — client snippets

All of these run in the **Client** view (or a Player window in two-player tests).

### C.1 H-1 QA logger (paste once per Play session, per player window)

```lua
if _G.QA then print("[QA] logger is already running in this window") return end
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local QA = { hits = 0, defeats = 0, stats = 0, syncs = 0, ok = 0, insufficient = 0, maxLevel = 0, otherReason = 0, currency = 0, gold = "?", stage = 0, hp = "?", quiet = false }
_G.QA = QA
QA.reset = function() QA.hits = 0 QA.defeats = 0 QA.stats = 0 QA.syncs = 0 QA.ok = 0 QA.insufficient = 0 QA.maxLevel = 0 QA.otherReason = 0 QA.currency = 0 end
QA.summary = function() print(string.format("[QA] SUMMARY hits=%d defeats=%d stats=%d syncs=%d | replies=%d (ok=%d insufficient=%d maxLevel=%d other=%d) | currency updates=%d | gold=%s stage=%d hp=%s", QA.hits, QA.defeats, QA.stats, QA.syncs, QA.ok + QA.insufficient + QA.maxLevel + QA.otherReason, QA.ok, QA.insufficient, QA.maxLevel, QA.otherReason, QA.currency, QA.gold, QA.stage, QA.hp)) end
local function say(text) if not QA.quiet then print("[QA] " .. text) end end
R.CombatUpdate.OnClientEvent:Connect(function(u)
	local s = u.snapshot
	QA.stage = s.stage
	QA.hp = tostring(s.enemyHp) .. "/" .. tostring(s.enemyMaxHp)
	if u.kind == "Hit" then QA.hits += 1 elseif u.kind == "Defeated" then QA.defeats += 1 elseif u.kind == "Stats" then QA.stats += 1 elseif u.kind == "Sync" then QA.syncs += 1 end
	say("Combat " .. tostring(u.kind) .. " stage=" .. tostring(s.stage) .. " hp=" .. QA.hp .. " tap=" .. tostring(s.tapDamage) .. " dmg=" .. tostring(u.damage) .. " goldAwarded=" .. tostring(u.goldAwarded))
end)
R.CurrencyUpdate.OnClientEvent:Connect(function(u)
	QA.currency += 1
	QA.gold = tostring(u.balances.Gold)
	say("Currency Gold=" .. QA.gold)
end)
R.UpgradeUpdate.OnClientEvent:Connect(function(u)
	local v = u.upgrades.TapDamage
	local r = u.result
	local text = "Upgrade " .. tostring(u.kind) .. " level=" .. tostring(v.level) .. " value=" .. tostring(v.currentValue) .. " nextCost=" .. tostring(v.nextCost)
	if r then
		if r.reason == "Ok" then QA.ok += 1 elseif r.reason == "InsufficientFunds" then QA.insufficient += 1 elseif r.reason == "MaxLevel" then QA.maxLevel += 1 else QA.otherReason += 1 end
		text = text .. " | result id=" .. tostring(r.requestId) .. " " .. tostring(r.reason)
	end
	say(text)
end)
print("[QA] logger ready")
```

Logged numbers are the raw values the server sent (canonical BigNum text such as `9007199254740986` or `1.1410965080841207e44`); the HUD shows the same values rounded for display.

### C.2 H-2 resync (asks the server for your full state again)

```lua
game:GetService("ReplicatedStorage").Remotes.ClientReady:FireServer()
```

The server ignores it if the previous sync was less than 1 second ago; wait a moment and paste again if nothing is logged.

### C.3 Camera check (M1-2)

```lua
local cam = workspace.CurrentCamera
print("[QA] CAMERA character=" .. tostring(game:GetService("Players").LocalPlayer.Character) .. " type=" .. tostring(cam.CameraType) .. " focus=" .. tostring(cam.Focus.Position) .. " position=" .. tostring(cam.CFrame.Position) .. " fov=" .. tostring(cam.FieldOfView))
```

### C.4 Camera snap-back (M1-2)

```lua
task.spawn(function()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	task.wait(0.5)
	print("[QA] CAMERA after reset type=" .. tostring(cam.CameraType) .. " focus=" .. tostring(cam.Focus.Position))
end)
```

### C.5 200 attack requests in one frame (M1-6)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	_G.QA.reset()
	_G.QA.quiet = true
	for i = 1, 200 do R.RequestAttack:FireServer() end
	task.wait(2)
	_G.QA.quiet = false
	print("[QA] 200 attack requests in one frame; hits + defeats must be exactly 1")
	_G.QA.summary()
end)
```

### C.6 One attack request every frame for 5 seconds (M1-6)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	task.wait(1)
	_G.QA.reset()
	_G.QA.quiet = true
	local t0 = os.clock()
	while os.clock() - t0 < 5 do R.RequestAttack:FireServer() task.wait() end
	task.wait(2)
	_G.QA.quiet = false
	print("[QA] attack requests every frame for 5 s; hits + defeats must be <= 72")
	_G.QA.summary()
end)
```

### C.7 Malformed upgrade requests (A-1)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
local cases = { {}, { 123, 1 }, { {}, {} }, { "Nope", 5 }, { "tapdamage", 6 }, { "TapDamage ", 7 }, { "TapDamage", 1.5 }, { "TapDamage", "4" }, { "TapDamage", 0 / 0 }, { "TapDamage", math.huge }, { "TapDamage", -math.huge }, { "TapDamage", 2 ^ 60 }, { "TapDamage", 2 ^ 53 }, { "TapDamage", -5 }, { "TapDamage", 0 }, { "TapDamage", true } }
task.spawn(function()
	for _, c in cases do
		R.RequestUpgrade:FireServer(c[1], c[2])
		task.wait(0.25)
	end
	task.wait(1)
	print("[QA] malformed upgrade requests sent: " .. #cases)
end)
```

(The first case sends no arguments at all.)

### C.8 ClientReady junk and spam (A-2)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	task.wait(2)
	_G.QA.reset()
	_G.QA.quiet = true
	R.ClientReady:FireServer("junk", 123, { x = 1 })
	for i = 1, 20 do R.ClientReady:FireServer() end
	task.wait(1.5)
	local burstSyncs = _G.QA.syncs
	local t0 = os.clock()
	for i = 1, 50 do R.ClientReady:FireServer() task.wait(0.1) end
	local elapsed = os.clock() - t0
	task.wait(1.5)
	_G.QA.quiet = false
	print(string.format("[QA] ClientReady spam: burst syncs=%d (must be <= 1); spam syncs=%d over %.1f s (must be <= %d)", burstSyncs, _G.QA.syncs - burstSyncs, elapsed, math.floor(elapsed) + 2))
end)
```

### C.9 Burst of 100 purchase requests (A-5)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	task.wait(3)
	_G.QA.reset()
	for i = 1, 100 do R.RequestUpgrade:FireServer("TapDamage", 1000 + i) end
	task.wait(3)
	print("[QA] burst of 100 purchase requests sent; replies must be exactly 10")
	_G.QA.summary()
end)
```

### C.10 Sustained purchase requests (A-6, L-4)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	task.wait(3)
	_G.QA.reset()
	_G.QA.quiet = true
	local t0 = os.clock()
	for i = 1, 50 do R.RequestUpgrade:FireServer("TapDamage", 2000 + i) task.wait(0.05) end
	local elapsed = os.clock() - t0
	task.wait(3)
	_G.QA.quiet = false
	print(string.format("[QA] 50 purchase requests over %.2f s; replies must be <= %d", elapsed, math.floor(10 + 8 * elapsed) + 1))
	_G.QA.summary()
end)
```

In L-4 the summary never prints, because the window is closed while the loop is running.

### C.11 Largest request id (A-7)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	task.wait(2)
	_G.QA.reset()
	R.RequestUpgrade:FireServer("TapDamage", 9007199254740991)
	task.wait(2)
	R.RequestUpgrade:FireServer("TapDamage", 9007199254740991)
	task.wait(2)
	print("[QA] largest-id test: replies must be exactly 1")
	_G.QA.summary()
end)
```

### C.12 Input diagnostic (Session 6)

```lua
game:GetService("UserInputService").InputBegan:Connect(function(input, processed) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then print("[QA] input " .. input.UserInputType.Name .. " processed=" .. tostring(processed) .. " at " .. math.floor(input.Position.X) .. "," .. math.floor(input.Position.Y)) end end)
```

`processed=true` means the game engine treated the press as a UI press (it can never become an attack).

### C.13 BigNum spot checks (N-1)

```lua
local B = require(game:GetService("ReplicatedStorage").Shared.BigNum)
local bad = 0
local formats = { { "0", "0" }, { "999", "999" }, { "1000", "1K" }, { "1500", "1.5K" }, { "1234567", "1.23M" }, { "1e15", "1Qa" }, { "9007199254740986", "9.01Qa" }, { "1e33", "1Dc" }, { "1e35", "100Dc" }, { "1e36", "1e36" }, { "1.5e400", "1.5e400" }, { "1e5000", "1e5000" } }
for _, c in formats do local v = B.parse(c[1]) local got = (if v then B.format(v) else "nil") if got ~= c[2] then bad += 1 warn("[QA] format " .. c[1] .. " -> " .. got .. " (expected " .. c[2] .. ")") end end
local hostile = { "10e9007199254740991", "1e9007199254740992", "-5", "inf", "nan", "0x10", "", " 5", "5 ", "1e", "e5", "1.2.3", string.rep("9", 65) }
for _, h in hostile do local ok, v = pcall(B.parse, h) if not ok or v ~= nil then bad += 1 warn("[QA] parse should return nil without an error for '" .. h .. "'") end end
for _, t in { "13", "0.5", "9007199254740991", "1.5e400" } do local v = B.parse(t) if v == nil or B.toString(v) ~= t then bad += 1 warn("[QA] round trip failed for " .. t) end end
local one = B.sub(B.parse("9007199254740992"), B.parse("9007199254740991"))
if B.toString(one) ~= "1" then bad += 1 warn("[QA] 2^53 - (2^53 - 1) gave " .. B.toString(one) .. " (expected 1)") end
print("[QA] BigNum spot checks: " .. (if bad == 0 then "PASS" else "FAIL (" .. bad .. ")"))
```

### C.14 Attack until stage 600 (N-4)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
task.spawn(function()
	_G.QA.quiet = true
	local t0 = os.clock()
	while _G.QA.stage < 600 and os.clock() - t0 < 300 do R.RequestAttack:FireServer() task.wait(0.08) end
	task.wait(1)
	_G.QA.quiet = false
	print(string.format("[QA] reached stage %d after %.0f s", _G.QA.stage, os.clock() - t0))
	_G.QA.summary()
end)
```

### C.15 Cleanup counts (C-1 to C-5)

```lua
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local hud = pg:WaitForChild("CombatHud")
local panel = pg:WaitForChild("UpgradePanel")
local stage = workspace:WaitForChild("CombatStage")
print("[QA] CLEANUP TapArea=" .. #hud.TapArea:GetChildren() .. " GoldPill=" .. #hud.TopBar.GoldPill:GetChildren() .. " CombatStage=" .. #stage:GetChildren() .. " | hud=" .. #hud:GetDescendants() .. " panel=" .. #panel:GetDescendants() .. " stage=" .. #stage:GetDescendants())
```

### C.16 Auto-attack for up to 10 minutes (C-3, C-4)

```lua
local R = game:GetService("ReplicatedStorage").Remotes
_G.QA_RUN = true
task.spawn(function()
	_G.QA.reset()
	_G.QA.quiet = true
	local t0 = os.clock()
	while _G.QA_RUN and os.clock() - t0 < 600 do R.RequestAttack:FireServer() task.wait(0.08) end
	task.wait(1)
	_G.QA.quiet = false
	print(string.format("[QA] auto-attack ran %.0f s", os.clock() - t0))
	_G.QA.summary()
end)
```

Stop early with `_G.QA_RUN = false`.

---

## Appendix D — server snippets and the fallback QA bridge

Run these in the **Server** view (Play mode) or the **Server** window (two players). In two-player tests, replace `GetPlayers()[1]` with `FindFirstChild("Player1")` (or `"Player2"`). To use another amount, change only the text inside the quotes, for example `"257"`.

### D.1 H-3 grant Gold

```lua
local p = game:GetService("Players"):GetPlayers()[1]
local B = require(game:GetService("ReplicatedStorage").Shared.BigNum)
local ok = require(game:GetService("ServerScriptService").CurrencyService).Grant(p, "Gold", B.parse("257"), "StudioQA")
print("[QA] grant Gold to " .. p.Name .. ": ok = " .. tostring(ok))
```

`ok = true` and the client's Gold rises: it worked. `ok = false`: see the H-check in section 4.

### D.2 H-4 server state

```lua
local p = game:GetService("Players"):GetPlayers()[1]
local B = require(game:GetService("ReplicatedStorage").Shared.BigNum)
local S = game:GetService("ServerScriptService")
local g = require(S.CurrencyService).GetBalance(p, "Gold")
print("[QA] SERVER " .. p.Name .. " gold=" .. (if g then B.toString(g) else "nil") .. " level=" .. tostring(require(S.UpgradeService).GetLevel(p, "TapDamage")) .. " combat=" .. tostring(require(S.CombatService).HasPlayer(p)))
```

### D.3 H-5 set tap damage

```lua
local p = game:GetService("Players"):GetPlayers()[1]
local B = require(game:GetService("ReplicatedStorage").Shared.BigNum)
print("[QA] setTapDamage ok = " .. tostring(require(game:GetService("ServerScriptService").CombatService).SetTapDamage(p, B.parse("1e5000"))))
```

### D.4 Fallback: temporary EmberboundQA bridge (only if the H-check said "not connected")

A Script placed in the game runs with the game's own modules, so it always reaches the live state. **This is a temporary test object, not part of Emberbound. Delete it before P-5 and never commit it.**

1. Stop. Hover over **ServerScriptService**, **+** → `Script`, rename it `EmberboundQA`, paste the code below.
2. Play. Output prints `[QA] EmberboundQA bridge ready in ServerStorage`.
3. In the Server view, use these one-liners instead of D.1–D.3, D.5 and D.6 (the last argument, a player name, is optional in one-player tests):

```lua
print(game:GetService("ServerStorage").EmberboundQA:Invoke("grantGold", "257"))
print(game:GetService("ServerStorage").EmberboundQA:Invoke("setTapDamage", "1e5000"))
print(game:GetService("ServerStorage").EmberboundQA:Invoke("state"))
print(game:GetService("ServerStorage").EmberboundQA:Invoke("grantGold", "257", "Player1"))
print(game:GetService("ServerStorage").EmberboundQA:Invoke("capture", "Player2"))
print(game:GetService("ServerStorage").EmberboundQA:Invoke("afterLeave", "Player2"))
```

Bridge script:

```lua
-- TEMPORARY Studio QA helper for M2_STUDIO_REGRESSION_GUIDE.md. Not part of Emberbound.
-- Delete it after testing, before the final parity check (P-5). Never commit it.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local BigNum = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BigNum"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))
local CombatService = require(ServerScriptService:WaitForChild("CombatService"))
local UpgradeService = require(ServerScriptService:WaitForChild("UpgradeService"))
local PlayerSessionService = require(ServerScriptService:WaitForChild("PlayerSessionService"))

local captured = {}

local function findPlayer(name)
	if name == nil then
		return Players:GetPlayers()[1]
	end
	return Players:FindFirstChild(name)
end

local function describe(player)
	local gold = CurrencyService.GetBalance(player, "Gold")
	return "currency=" .. tostring(CurrencyService.HasPlayer(player))
		.. " combat=" .. tostring(CombatService.HasPlayer(player))
		.. " level=" .. tostring(UpgradeService.GetLevel(player, "TapDamage"))
		.. " session=" .. tostring(PlayerSessionService.IsReady(player))
		.. " gold=" .. (if gold then BigNum.toString(gold) else "nil")
end

local bridge = Instance.new("BindableFunction")
bridge.Name = "EmberboundQA"
bridge.OnInvoke = function(action, value, playerName)
	if action == "capture" then
		local player = findPlayer(value)
		captured[value] = player
		return "[QA] captured " .. tostring(player) .. ": " .. (if player then describe(player) else "not found")
	elseif action == "afterLeave" then
		local player = captured[value]
		if player == nil then
			return "[QA] capture this player first"
		end
		captured[value] = nil
		return "[QA] after leave: " .. describe(player)
	end

	local player = findPlayer(playerName)
	if player == nil then
		return "[QA] player not found"
	end
	if action == "grantGold" or action == "setTapDamage" then
		local amount = BigNum.parse(value)
		if amount == nil then
			return "[QA] not a valid amount: " .. tostring(value)
		end
		local ok = if action == "grantGold"
			then CurrencyService.Grant(player, "Gold", amount, "StudioQA")
			else CombatService.SetTapDamage(player, amount)
		return "[QA] " .. action .. " ok = " .. tostring(ok) .. " | " .. describe(player)
	elseif action == "state" then
		return "[QA] " .. describe(player)
	end
	return "[QA] unknown action " .. tostring(action)
end
bridge.Parent = ServerStorage
print("[QA] EmberboundQA bridge ready in ServerStorage")
```

With the bridge, L-1 PASS means `capture` shows `currency=true combat=true … session=true` and `afterLeave` shows `currency=false combat=false level=nil session=false gold=nil`.

### D.5 Capture Player2 before it leaves (L-1)

```lua
_G.QA_P2 = game:GetService("Players"):FindFirstChild("Player2") print("[QA] captured", _G.QA_P2)
```

### D.6 Check Player2's server state (L-1)

```lua
local p = _G.QA_P2
local S = game:GetService("ServerScriptService")
print("[QA] Player2 currency=" .. tostring(require(S.CurrencyService).HasPlayer(p)) .. " combat=" .. tostring(require(S.CombatService).HasPlayer(p)) .. " level=" .. tostring(require(S.UpgradeService).GetLevel(p, "TapDamage")) .. " session=" .. tostring(require(S.PlayerSessionService).IsReady(p)))
```

After L-1, release the reference with `_G.QA_P2 = nil`.

---

## Appendix E — expected-value tables

Values come from `ProgressionConfig` and `GameConfig` at `e4b0108`, computed with the same formulas (they match the offline harness table in `M2_REVIEW_GUIDE.md` §6). Before rounding down, every cost and value in E.1 and every stage up to 20 in E.3 is either an exact whole number or at least 0.006 away from one, far more than any floating-point difference between machines, so these numbers must match exactly. The large-stage strings (stage 50 and above) come from the same formulas through a port of `BigNum.format`; if Studio differs only in the last displayed digit, record it as an observation, not a FAIL.

### E.1 Tap Damage upgrade: cost and value by level

Cost(L) = floor(5 × 1.07^(L − 1)) is the price of going from level L to L + 1. Value(L) = floor(L × 3^floor(L / 25)) is the tap damage at level L.

| Level L | Tap damage at L | Cost L → L+1 | Total spent to reach L |
|---|---|---|---|
| 1 | 1 | 5 | 0 |
| 2 | 2 | 5 | 5 |
| 3 | 3 | 5 | 10 |
| 4 | 4 | 6 | 15 |
| 5 | 5 | 6 | 21 |
| 6 | 6 | 7 | 27 |
| 7 | 7 | 7 | 34 |
| 8 | 8 | 8 | 41 |
| 9 | 9 | 8 | 49 |
| 10 | 10 | 9 | 57 |
| 11 | 11 | 9 | 66 |
| 12 | 12 | 10 | 75 |
| 13 | 13 | 11 | 85 |
| 14 | 14 | 12 | 96 |
| 15 | 15 | 12 | 108 |
| 16 | 16 | 13 | 120 |
| 17 | 17 | 14 | 133 |
| 18 | 18 | 15 | 147 |
| 19 | 19 | 16 | 162 |
| 20 | 20 | 18 | 178 |
| 21 | 21 | 19 | 196 |
| 22 | 22 | 20 | 215 |
| 23 | 23 | 22 | 235 |
| 24 | 24 | 23 | 257 |
| 25 | 75 | 25 | 280 |
| 26 | 78 | 27 | 305 |
| 27 | 81 | 29 | 332 |
| 28 | 84 | 31 | 361 |
| 29 | 87 | 33 | 392 |
| 30 | 90 | 35 | 425 |

### E.2 U-5 Gold after each of the 23 purchases from 257 Gold

`252, 247, 242, 236, 230, 223, 216, 208, 200, 191, 182, 172, 161, 149, 137, 124, 110, 95, 79, 61, 42, 22, 0` (then `Gold=23` after the second grant, and `0` after the 24th purchase)

### E.3 Enemy HP and Gold reward by stage (as the HUD shows them)

Enemy max HP = max(1, floor(10 × 1.18^(stage − 1))); Gold reward = floor(5 × 1.12^(stage − 1)).

| Stage | Enemy HP | Gold reward |
|---|---|---|
| 1 | `10` | `5` |
| 2 | `11` | `5` |
| 3 | `13` | `6` |
| 4 | `16` | `7` |
| 5 | `19` | `7` |
| 10 | `44` | `13` |
| 13 | `72` | `19` |
| 14 | `85` | `21` |
| 20 | `232` | `43` |
| 50 | `33.28K` | `1.29K` |
| 100 | `130.71M` | `372.87K` |
| 200 | `2.02Qa` | `31.14B` |
| 210 | `10.55Qa` | `96.72B` |
| 300 | `31.1Sx` | `2.6Qa` |
| 487 | `860.31Dc` | `4.16Sp` |
| 488 | `1.02e36` | `4.66Sp` |
| 500 | `7.4e36` | `18.15Sp` |
| 598 | `8.2e43` | `1.21No` |
| 599 | `9.67e43` | `1.35No` |
| 600 | `1.14e44` | `1.52No` |
| 601 | `1.35e44` | `1.7No` |
| 602 | `1.59e44` | `1.9No` |
| 603 | `1.87e44` | `2.13No` |
| 1000 | `6.46e72` | `7.38e49` |
| 2000 | `4.92e144` | `1.22e99` |
| 4276 | `1.98e308` | `1.28e211` |
| 5000 | `2.18e360` | `5.49e246` |
| 7000 | `1.27e504` | `1.5e345` |

N-5 (after one 6e43 hit at full HP):

| Stage | HP text after the hit | Bar fill |
|---|---|---|
| 600 | `5.41e43 / 1.14e44` | about 47 % |
| 601 | `7.46e43 / 1.35e44` | about 55 % |
| 602 | `9.89e43 / 1.59e44` | about 62 % |
| 603 | `1.27e44 / 1.87e44` | about 68 % |
