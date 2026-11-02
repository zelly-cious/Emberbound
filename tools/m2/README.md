# tools/m2 — Milestone 2 one-time Studio installer (M2-TOOLS-001)

Tooling only. Nothing here is game code, and nothing here changes `src/`, `SOURCE_HASHES.txt` or any milestone document. The project owner's guide is [`INSTALL_INSTRUCTIONS.md`](INSTALL_INSTRUCTIONS.md).

## Files

| File | Role |
|---|---|
| `InstallM2.lua` | **Generated** installer, pasted into the Roblox Studio Command Bar. Embeds the 24 frozen sources. |
| `InstallM2.template.lua` | Installer logic (hand-written). The generator fills in the layout and the payload. |
| `generate_installer.py` | Deterministic generator and verifier (`--check` regenerates in memory and compares). |
| `INSTALLER_MANIFEST.txt` | **Generated.** SHA-256 of `InstallM2.lua` plus SHA-256, bytes, lines and Adler-32 of every embedded file. |
| `INSTALL_INSTRUCTIONS.md` | Beginner guide: download, check mode, install mode, Appendix B, unit tests, reporting. |
| `tests/run_tests.py` | Offline test runner (Python 3 + `lua5.1`). |
| `tests/installer_tests.lua` | 54 behaviour tests that run the real `InstallM2.lua` text. |
| `tests/mock_roblox.lua` | Minimal fake Roblox engine for those tests (not a Studio substitute). |

## Source of truth

- Sources: the 24 files under `src/` at the frozen commit `e9d878d94155610558c9c6252d76f202dfd956b4`, read with `git cat-file` from that commit object (never from the working tree or a branch head).
- Hashes: the round 3 section of `SOURCE_HASHES.txt` **at the frozen commit**. Every file's SHA-256 must match, or generation stops.
- Cross-checks: Appendix A (paths, classes, SHA-256) and Appendix B (bytes, lines, Adler-32) of `M2_STUDIO_REGRESSION_GUIDE.md` at this branch's base (PR #1 head `2b832d2`, whose `src/` is identical to `e9d878d`).
- The generator never alters a source. It refuses any file that is not already in the Appendix B normalized form (all 24 are).

## How the installer works

**Payload.** Each source line is one double-quoted Lua string with escapes: `\n`, `\t`, `\"`, `\\`, and three-digit `\ddd` for any other byte (only the two `±` characters in `TestKit`). There are no long-bracket strings and no raw newlines inside strings, so source contents cannot end a delimiter early. The installer uses only `--[[ ]]` block comments and never starts a line with `(`. Because of this it compiles and behaves the same if a paste turns line breaks into spaces or LF into CRLF; both cases are tested. The file is ASCII-only. It is written in the subset of Luau that plain Lua 5.1 also accepts, so it can be executed offline.

**Steps, in order (no yields anywhere):**

1. **Payload check:** 24 entries, each matching the expected path and class in Appendix A order; no duplicates; 2 Scripts, 1 LocalScript and 21 ModuleScripts; every rebuilt text already normalized; bytes, lines and Adler-32 equal to the frozen values. This uses the same normalization and checksum as Appendix B.
2. **Studio mode:** `RunService:IsStudio()`, `IsEdit()` and `IsRunning()` must all be readable booleans, with Studio = true, Edit = true and Running = false. Requiring `IsEdit()` also rejects a paused playtest, the gap Codex found in ART-001's guard. If any call fails, the installer refuses.
3. **Place:** `game.PlaceId` must be 0 (a local, unpublished file). This also excludes Team Create places.
4. **Destinations:** `ReplicatedStorage`, `ServerScriptService` and `StarterPlayer.StarterPlayerScripts` must exist. None of the names the installer adds may exist under them, whatever their class (`Shared`, `Remotes`, `Tests`, the 8 server scripts, `CombatClient`). No script of any kind may exist in the 10 services that Appendix B scans for extra scripts.
5. **Check mode stops here** and prints the report. It creates no instance and sets no property (tested).
6. **Install mode, phase 1:** builds every object **detached** (`Parent = nil`), sets `Enabled = true` on the 3 scripts, sets `Source`, reads it back and compares it after normalization, and rejects a Script whose `RunContext` reads `Client`. The place is not touched yet.
7. **Phase 2:** re-runs the destination check, then parents the 12 top-level objects (3 folders, 8 server scripts, `CombatClient`).
8. **Phase 3:** sets `Players.CharacterAutoLoads = false` only if it was not already false, then confirms it.
9. **Phase 4:** verifies the whole installed hierarchy (classes, uniqueness, normalized `Source`, `Enabled`, 6 RemoteEvents, 3 folders).
10. **On any error in phases 1–4:** destroys only the instances this run created (its own `built` list, newest first), restores `CharacterAutoLoads` if it differs from the original, confirms each created object is gone, and prints `ROLLBACK COMPLETE` or `ROLLBACK INCOMPLETE` with the reason. Pre-existing objects are never destroyed, moved or edited.

The installer prints only `[M2 Installer]` status lines. It never prints `[Parity]` lines; only the unchanged Appendix B checker establishes parity.

## Regenerate and verify

```bash
python3 tools/m2/generate_installer.py           # writes InstallM2.lua and INSTALLER_MANIFEST.txt
python3 tools/m2/generate_installer.py --check   # exit 0 only if both files equal a fresh generation
python3 tools/m2/tests/run_tests.py              # all offline checks (needs lua5.1 / luac5.1 on PATH)
```

`run_tests.py` covers:

1. The frozen commit resolves, `src/` has exactly the 24 expected files, and every SHA-256 matches round 3.
2. Classes, plus the Appendix A and B cross-checks.
3. Two in-memory generations and the committed files are byte-identical.
4. A second, independent decoder rebuilds every embedded file byte for byte.
5. A static scan of the installer logic finds no HTTP, DataStore, publish, `require`, `loadstring`, yields or similar calls.
6. `luac5.1 -p` accepts the file.
7. The 54 Lua behaviour tests run.
8. An offline replica of the Appendix B logic checks the installed mock place.
9. `src/` and `SOURCE_HASHES.txt` are unchanged, and every change is under `tools/m2/`.

## What was and was not tested

**Tested offline** (Python 3, Lua 5.1.5, fake engine): everything in the list above. The 54 behaviour tests cover:

- check mode on a fresh place (no instance created, no property set);
- a full install (exact Sources, classes, parents, `Enabled`, `RunContext`, 33 objects, nothing in StarterGui or StarterCharacterScripts, unrelated objects untouched);
- `CharacterAutoLoads` already false;
- a second run refused;
- 14 collision cases;
- 11 unsafe states (running, paused, not Studio, each `RunService` call failing, non-boolean, `RunService` unavailable, published place, unreadable `PlaceId`, missing `StarterPlayerScripts`);
- 6 kinds of damaged payload;
- 22 truncation points;
- joined lines and CRLF;
- 13 failures injected during installation, each followed by a complete rollback;
- one rollback where `Destroy` fails, which correctly reports `ROLLBACK INCOMPLETE`.

**Not tested — needs the project owner in Roblox Studio:**

- Whether the Command Bar accepts a ~227 KB paste. Every failure mode found offline was safe: a truncated paste either does not compile or never reaches the final call.
- The real values of `IsStudio`, `IsEdit` and `IsRunning` in Edit, Play, Run and paused states, and of `game.PlaceId` for a local file.
- Setting `Source` from the Command Bar, the default `RunContext` and `Enabled` of `Instance.new("Script")`, `Destroy` and parenting behaviour, and how Studio records these changes in undo history.
- The Appendix B checker and the 61 unit tests on the installed place.
- Luau-specific parsing. The file was checked with `luac5.1`, not with `luau-compile` or `luau-analyze`, which were not available here.

## Limitations

- **Command Bar size.** The single-paste design is unverified in Studio. If Studio cannot take it, the fallback (for example a multi-part paste) needs its own design and review; the instructions tell the owner to report rather than improvise.
- **Rollback depends on `Destroy`.** If Studio refuses to destroy an object this run created, the installer reports `ROLLBACK INCOMPLETE`, names the object, and tells the owner to close without saving. It never falls back to broader cleanup.
- **Studio undo history.** The installer does not create undo waypoints. The instructions tell the owner not to use Ctrl+Z to remove an installation.
- **The fake engine** models only the API surface listed in `tests/mock_roblox.lua`. It does not model security levels, replication, plugins or Studio itself.

## Codex review prompt

> Independently review branch `feature/m2-tools-001-installer` of `zelly-cious/Emberbound` (task M2-TOOLS-001: a one-time Roblox Studio Command Bar installer for the frozen Milestone 2 source). Read-only: do not edit, commit or push. Read `tools/m2/README.md`, `tools/m2/INSTALL_INSTRUCTIONS.md`, `tools/m2/InstallM2.template.lua`, `tools/m2/generate_installer.py` and the tests in `tools/m2/tests/`.
>
> Verify:
> 1. Every embedded source in `tools/m2/InstallM2.lua` is byte-identical to `src/` at commit `e9d878d94155610558c9c6252d76f202dfd956b4`. Every SHA-256 matches the round 3 section of `SOURCE_HASHES.txt` at that commit. Run `python3 tools/m2/generate_installer.py --check` and `python3 tools/m2/tests/run_tests.py` (needs `lua5.1`), and decode the payload yourself.
> 2. The hierarchy matches Appendix A of `M2_STUDIO_REGRESSION_GUIDE.md`, and the result passes its unchanged Appendix B checker. If you can, compile the installer with `luau-compile` and analyze it with `luau-analyze`.
> 3. Safety:
>    - Check mode creates nothing and sets nothing.
>    - The installer refuses a running or paused playtest, non-Studio, unreadable mode, a published place, damaged payload, any pre-existing Milestone 2 name, and any pre-existing script.
>    - A second run cannot overwrite anything.
>    - Rollback destroys only objects created by the same run and restores `CharacterAutoLoads`.
>    - There is no HTTP, DataStore, publishing, plugin, `require`/`loadstring` or yield, and nothing outside the reviewed hierarchy.
> 4. No file outside `tools/m2/` changed relative to base `2b832d267cc7461b5bebb138fe861d5b5e4ed0e9`, and nothing under `src/` or `SOURCE_HASHES.txt` changed.
> 5. The instructions are correct and beginner-safe, and every claim about untested Studio behaviour is disclosed.
>
> For each finding give severity (Critical/High/Medium/Low), file and line, trigger, impact and the smallest fix. Distinguish confirmed defects from risks that need a Studio test. Do not claim Studio results you did not observe.
