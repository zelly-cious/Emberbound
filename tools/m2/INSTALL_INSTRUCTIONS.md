# Installing Milestone 2 into Roblox Studio with the one-time installer

This guide is for the project owner. It replaces the manual copy-and-paste of 24 scripts (steps P-1 and P-2 of `M2_STUDIO_REGRESSION_GUIDE.md`) with one installer file that you paste into Studio's Command Bar. Everything after that, starting with the **Appendix B parity check (P-3)**, stays exactly as the regression guide describes.

| | |
|---|---|
| Installer file | `tools/m2/InstallM2.lua` on branch `feature/m2-tools-001-installer` |
| What it installs | Milestone 2 exactly as frozen at commit `e9d878d94155610558c9c6252d76f202dfd956b4`: 3 folders, 6 RemoteEvents, 24 scripts, and `Players.CharacterAutoLoads = false` |
| Where it may run | Only a **new Baseplate saved to a file** on your computer, in **Edit mode** |
| Default behaviour | **Check only.** It changes nothing until you switch on its one setting |
| Studio status | Tested offline only (plain Lua with a fake Roblox engine). **It has not been run in Roblox Studio yet.** Your run is the first real test |

**Never run the installer in a real game place.** It refuses places that already contain scripts, but a fresh Baseplate is the only place it is designed for.

## 1. Download the installer

1. Open <https://github.com/zelly-cious/Emberbound/blob/feature/m2-tools-001-installer/tools/m2/InstallM2.lua> (sign in to GitHub if asked).
2. Click the **Download raw file** button (the downward arrow at the top right of the file view). Save it somewhere easy to find, for example your Desktop. If your browser adds `.txt` to the name, that is fine.
   - Alternative: click **Raw**, then press **Ctrl+S** (Mac: **Cmd+S**) to save the page.
3. Optional, but recommended: check that the download is complete and unchanged. Compare its SHA-256 with the `installer_sha256` line in [`tools/m2/INSTALLER_MANIFEST.txt`](INSTALLER_MANIFEST.txt):
   - Windows PowerShell: `Get-FileHash -Algorithm SHA256 $HOME\Desktop\InstallM2.lua`
   - macOS Terminal: `shasum -a 256 ~/Desktop/InstallM2.lua`

   Do this **before** you edit the file in step 5. If the values differ, download it again.

Open the file in a **plain-text editor**: Notepad (Windows), TextEdit in plain-text mode (Mac: Format → Make Plain Text), or VS Code. Do not use Word or Google Docs. The file is about 227 KB and 5,600 lines long; that is normal.

## 2. Create a fresh Baseplate and save it locally

1. Open Roblox Studio and sign in.
2. Create a new place from the **Baseplate** template (File → New, or the Baseplate tile on the start page).
3. **File → Save to File As…** and save it as `Emberbound_M2_QA.rbxl`. Saving to a file does not publish anything. Do **not** publish this place before installing: the installer refuses published places.
4. Do not add anything to the place yourself. The installer creates everything, including the folders, the RemoteEvents and the `CharacterAutoLoads` setting.

## 3. Open Explorer, Properties, Output and the Command Bar

In the **View** tab, click **Explorer**, **Properties**, **Output** and **Command Bar** once each so they stay open. The Command Bar is the long single box at the bottom of Studio. Right-click inside Output and choose **Clear Output**.

Make sure you are in **Edit mode**: no playtest is running and the Play button is not active. If a playtest is running or paused, press **Stop** (Shift+F5).

## 4. Run the installer in check mode (changes nothing)

1. In your text editor, press **Ctrl+A** (select all), then **Ctrl+C** (copy). Mac: **Cmd+A**, **Cmd+C**.
2. Click inside Studio's **Command Bar**, press **Ctrl+V** (paste), then press **Enter**.
3. Wait a few seconds; the file is large. Then read Output.

A successful check prints these lines (all start with `[M2 Installer]`). The examples in this guide come from the offline tests; Studio should print the same text:

```text
[M2 Installer] Emberbound Milestone 2 installer v1.0.0
[M2 Installer] Frozen source commit: e9d878d94155610558c9c6252d76f202dfd956b4
[M2 Installer] Mode: CHECK ONLY (ENABLE_INSTALLATION = false). Nothing will be changed.
[M2 Installer] Embedded source: 24/24 files; sizes, line counts and checksums match the frozen commit.
[M2 Installer] Studio mode: Edit mode
[M2 Installer] Place: not published to Roblox (PlaceId 0).
[M2 Installer] Existing objects: no conflicts.
[M2 Installer] Players.CharacterAutoLoads is currently true; installation sets it to false.
[M2 Installer] Safe to modify this place: YES
[M2 Installer] Will create: 3 folders, 6 RemoteEvents, 24 scripts.
[M2 Installer] Ready to install: YES
[M2 Installer] CHECK COMPLETE. Nothing was changed. To install: ...
```

**Continue only if you see `Ready to install: YES`.** Otherwise the Output names each problem (orange lines). Common ones:

| Output says | What to do |
|---|---|
| `A playtest is running` or `not in Edit mode` | Press Stop (Shift+F5) and paste again |
| `This place is published to Roblox` | Start again from step 2 with a new Baseplate saved only to a file |
| `conflict(s)`, `already exists`, `Existing script` | The place is not fresh. Start again from step 2. The installer never overwrites or deletes anything |
| `checksum mismatch`, `payload`, or `damaged` | The file was changed or cut off. Download it again (step 1) |
| Nothing at all, or a red syntax error | The paste did not arrive complete. See section 9 |

## 5. Turn on installation

1. In your text editor, find this line near the top of the file (line 35; use Ctrl+F and search for `ENABLE_INSTALLATION`):

   ```lua
   local ENABLE_INSTALLATION = false
   ```

2. Change `false` to `true`, so the line reads `local ENABLE_INSTALLATION = true`. Change nothing else. You do not need to save the file.

## 6. Run the installer in install mode

1. Clear Output. Make sure you are still in Edit mode in the same fresh place.
2. In the text editor press **Ctrl+A**, **Ctrl+C**. Click the Command Bar, **Ctrl+V**, **Enter**.
3. Wait a few seconds and read Output.

## 7. Recognize a successful installation

Output repeats the checks, then ends with:

```text
[M2 Installer] Ready to install: YES
[M2 Installer] INSTALLATION COMPLETE
[M2 Installer] Scripts: 24/24
[M2 Installer] RemoteEvents: 6/6
[M2 Installer] Required folders: 3/3
[M2 Installer] Players.CharacterAutoLoads: false (changed from true by this run)
[M2 Installer] These are installer status messages, not a parity result.
[M2 Installer] Next: save the place (File > Save to File), then run the Appendix B parity checker from M2_STUDIO_REGRESSION_GUIDE.md.
```

In Explorer you should now see `ReplicatedStorage → Shared` (3 modules) and `Remotes` (6 RemoteEvents), the scripts and the `Tests` folder in `ServerScriptService`, and `StarterPlayer → StarterPlayerScripts → CombatClient` with `ArenaView`, `CombatHud` and `UpgradePanel` inside it.

Then **File → Save to File** to save `Emberbound_M2_QA.rbxl`.

If Output says `INSTALLATION FAILED` instead, read the next lines:

- `ROLLBACK COMPLETE` means the installer removed everything it had created in this run and put `CharacterAutoLoads` back. Close the place **without saving**, then go to section 10 to report the failure.
- `ROLLBACK INCOMPLETE` names what could not be undone. Close the place **without saving**, start from a new Baseplate, and report it (section 10).

**Do not run the installer a second time in the same place.** A second run sees the first installation and refuses ("already exists"). That refusal is expected. Do not use Undo (Ctrl+Z) to remove an installation either; start from a new Baseplate instead.

## 8. Run the independent Appendix B parity checker, then the 61 unit tests

The installer's messages are not proof of source parity. The **unchanged Appendix B checker** in `M2_STUDIO_REGRESSION_GUIDE.md` is.

1. Stay in **Edit mode**. Clear Output.
2. Open Appendix B of the guide: <https://github.com/zelly-cious/Emberbound/blob/2b832d267cc7461b5bebb138fe861d5b5e4ed0e9/M2_STUDIO_REGRESSION_GUIDE.md#appendix-b--source-parity-checker>. Use the copy button at the top right of the code block to copy the whole checker.
3. Click the Command Bar, paste, press **Enter**.
4. **PASS** only if Output ends with exactly these two lines and no `[Parity] FAIL` line appears above them:

   ```text
   [Parity] scripts matching: 24 / 24, remotes: 6 / 6, extra scripts: 0
   [Parity] RESULT: PASS
   ```

   This is test **P-3** in the regression guide; copy the two lines into your results file.
5. If the checker prints `[Parity] RESULT: FAIL`: **do not change any script to make it pass.** Copy all of Output into a text file and report it (section 10).

When P-3 passes, run the 61 unit tests (test **T-1** in the regression guide):

1. Clear Output and press **Play** (F5).
2. Wait 5 seconds and read Output. A pass shows these 8 lines (other lines may appear between them):

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

3. Continue with the rest of `M2_STUDIO_REGRESSION_GUIDE.md` (M1-1 onwards), recording results in `review/M2_STUDIO_QA_RESULTS_TEMPLATE.md`. In the results file, write "installed with tools/m2/InstallM2.lua v1.0.0" in the "How the scripts were installed" row.

## 9. If the Command Bar cannot take the whole file

The installer is one large paste (about 227 KB). This has not been tried in Studio yet. If nothing happens, Studio freezes for a long time, or Output shows a red syntax error such as `unfinished string` or `'end' expected`, the paste probably did not arrive complete.

That is safe: Studio checks the whole text before running any of it, so a cut-off installer cannot change anything. The installer also checks the size and checksum of every embedded script before it does anything. Do **not** split the file into pieces yourself. Report what happened (section 10). A different installation method would need its own review.

## 10. What to send if something fails

Send these to the reviewer, the same way the other QA results are handled:

1. The **whole Output** from the failing run (click inside Output, Ctrl+A, Ctrl+C, paste into a text file), including every orange and red line.
2. Which step failed (check mode, install mode, Appendix B, or the unit tests) and whether `ENABLE_INSTALLATION` was `false` or `true`.
3. The installer version and frozen commit from the first two Output lines, and the SHA-256 of your downloaded file if you checked it (step 1.3).
4. A screenshot of Explorer with ReplicatedStorage, ServerScriptService and StarterPlayer expanded.
5. Your Roblox Studio version and your operating system.

Do not edit the installer or any installed script to work around a failure, and do not merge PR #1.
