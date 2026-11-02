# tools/m2 — Milestone 2 one-time Studio installer (M2-TOOLS-001)

Tooling only. Nothing here is game code, and nothing here changes `src/`, `SOURCE_HASHES.txt` or any milestone document. The project owner's guide is [`INSTALL_INSTRUCTIONS.md`](INSTALL_INSTRUCTIONS.md).

Current installer: **v1.2.0** (round 4 BigNum adoption). It has the same installer logic as v1.1.0, which corrected the Codex review of v1.0.0 (commit `de4aa63`; see "Corrections" below). v1.2.0 embeds the round 4 sources; see "Round 4 (v1.2.0)".

## Files

| File | Role |
|---|---|
| `InstallM2.lua` | **Generated** installer, pasted into the Roblox Studio Command Bar. Embeds the 24 release sources (round 4). |
| `InstallM2.template.lua` | Installer logic (hand-written). The generator fills in the layout and the payload. |
| `generate_installer.py` | Deterministic generator and verifier (`--check` regenerates in memory and compares). |
| `INSTALLER_MANIFEST.txt` | **Generated.** SHA-256 of `InstallM2.lua` plus SHA-256, bytes, lines and Adler-32 of every embedded file. |
| `INSTALL_INSTRUCTIONS.md` | Beginner guide: download, check mode, install mode, Appendix B, unit tests, reporting. |
| `tests/run_tests.py` | Offline test runner (Python 3 + `lua5.1`). |
| `tests/installer_tests.lua` | 69 behaviour tests that run the real `InstallM2.lua` text. |
| `tests/mock_roblox.lua` | Minimal fake Roblox engine for those tests (not a Studio substitute). |

## Source of truth

- Sources: the 24 files under `src/` at the source commit `9a988c9254e07ac50dcf32fe4b55ba975613390d` (round 4; the reviewed BigNum candidate), read with `git cat-file` from that commit object (never from the working tree or a branch head).
- Hashes: the round 4 section of `SOURCE_HASHES.txt` **at HEAD**. Round 4 is recorded after the source commit, so it cannot live in that commit. The generator requires the source commit to be an ancestor of HEAD, and the round 4 heading to name it and be marked current. Every file's SHA-256 must match, or generation stops.
- Cross-checks: Appendix A (paths, classes, SHA-256) and Appendix B (bytes, lines, Adler-32) of `M2_STUDIO_REGRESSION_GUIDE.md` at HEAD (the round 4 guide).
- The generator never alters a source. It refuses any file that is not already in the Appendix B normalized form (all 24 are).

## How the installer works

**Payload.** Each source line is one double-quoted Lua string with escapes: `\n`, `\t`, `\"`, `\\`, and three-digit `\ddd` for any other byte (only the two `±` characters in `TestKit`). There are no long-bracket strings and no raw newlines inside strings, so source contents cannot end a delimiter early. The installer uses only `--[[ ]]` block comments and never starts a line with `(`. Because of this it compiles and behaves the same if a paste turns line breaks into spaces or LF into CRLF; both cases are tested. The file is ASCII-only. It is written in the subset of Luau that plain Lua 5.1 also accepts, so it can be executed offline.

**Services are only ever looked up, never created.** Every service access goes through one helper that calls `game:FindService`, which returns nil for a missing service. `GetService` would create the service, so it appears nowhere in the installer logic (enforced by a static test, and by the mock, which counts `GetService` calls). A missing *required* service (`RunService`, `Players`, `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer`) is refused. A missing scan-only service holds no scripts and is skipped.

**Steps, in order (no yields anywhere):**

1. **Payload check:** 24 entries, each matching the expected path and class in Appendix A order; no duplicates; 2 Scripts, 1 LocalScript and 21 ModuleScripts; every rebuilt text already normalized; bytes, lines and Adler-32 equal to the frozen values. This uses the same normalization and checksum as Appendix B.
2. **Studio mode:** `RunService:IsStudio()`, `IsEdit()` and `IsRunning()` must all be readable booleans, with Studio = true, Edit = true and Running = false. Requiring `IsEdit()` also rejects a paused playtest, the gap Codex found in ART-001's guard. If any call fails, the installer refuses.
3. **Place:** prints `Place identity: PlaceId …, GameId …`. `game.PlaceId` must be 0 (a local, unpublished file); a non-zero value is refused with a request to report it. This also excludes Team Create places. See M2-R01 below.
4. **Destinations:** `ReplicatedStorage`, `ServerScriptService` and `StarterPlayer.StarterPlayerScripts` must exist. None of the names the installer adds may exist under them, whatever their class (`Shared`, `Remotes`, `Tests`, the 8 server scripts, `CombatClient`). No script of any kind may exist in the 10 services that Appendix B scans for extra scripts.
5. **Check mode stops here** and prints the report. It creates no instance, sets no property, calls no `GetService` and creates no service (all tested).
6. **Install mode, phase 1:** builds every object **detached** (`Parent = nil`), sets `Enabled = true` on the 3 scripts, sets `Source`, reads it back and compares it after normalization, and rejects a Script whose `RunContext` reads `Client`. The place is not touched yet.
7. **Phase 2:** re-runs the destination check, then parents the 12 top-level objects (3 folders, 8 server scripts, `CombatClient`).
8. **Phase 3:** sets `Players.CharacterAutoLoads = false` only if it was not already false, then confirms it.
9. **Phase 4:** verifies the whole installed hierarchy (classes, uniqueness, normalized `Source`, `Enabled`, 6 RemoteEvents, 3 folders).
10. **On any error in phases 1–4,** rollback runs:
    - It destroys **first** the instances this run created (its own `built` list, newest first), so nothing that follows can stop the cleanup.
    - It then restores `CharacterAutoLoads` if it differs from the original. Every read, write and confirmation of that setting is protected.
    - It confirms each created object is gone and prints `ROLLBACK COMPLETE`, or `ROLLBACK INCOMPLETE` naming what could not be undone.
    - The rollback call is itself protected, so an unexpected error still produces an explicit `ROLLBACK INCOMPLETE` report.
    - Pre-existing objects are never destroyed, moved or edited.

The installer prints only `[M2 Installer]` status lines. It never prints `[Parity]` lines; only the unchanged Appendix B checker establishes parity.

## Round 4 (v1.2.0): BigNum DEFECT-001/001B adoption

- **What changed in the installer:** the embedded `BigNum` (FILES[1]) and `BigNumTests` (FILES[12]), the header comment, `INSTALLER_VERSION` (1.2.0) and `FROZEN_COMMIT` (`9a988c9`). The installer logic is byte-identical to v1.1.0; this was checked by diffing the generated file outside the two FILES blocks and the header.
- **Integrity values:** `InstallM2.lua` is 240,675 bytes, SHA-256 `b12fa7023f25a93d2e2a80aef0042c0cf962d81a7aef84dd4ca1fd06873623d4` (`INSTALLER_MANIFEST.txt`). The download link in `INSTALL_INSTRUCTIONS.md` is pinned to commit `d2e638188efaa2f8fdcd59a9c4b2c35e1763a396`, which contains this file.
- **Generator:** source pin and manifest round 4. The manifest is read from HEAD, with the ancestor and heading checks above.
- **Tests:** `run_tests.py` checks source identity against round 4. Its repository-scope checks now cover the adoption: `src/` unchanged from `9a988c9`, rounds 1-3 of `SOURCE_HASHES.txt` keep their hash lines, round 4 is the only current round, and only release-package files changed. One Lua damage test ("a recorded checksum changed") hard-coded the frozen BigNum Adler-32. It now reads FILES[1]'s value from the installer, so it makes the same mutation with any payload.

## Corrections after the Codex review of v1.0.0 (`de4aa63`, verdict FAIL)

| Finding | Severity | Status in v1.1.0 |
|---|---|---|
| **M2-I01** Rollback could stop before removing created objects when reading `CharacterAutoLoads` raised an error | Medium | **Fixed.** Objects are destroyed before the setting is touched, every setting read and write is protected, and the rollback call is protected. New regression tests make the setting read fail after the restore write, every setting read fail, and the restore write fail; each requires all 33 created objects removed and `ROLLBACK INCOMPLETE` reported, with no unexpected-error path. |
| **M2-I02** Check mode was not read-only: `GetService` creates a missing service | Medium | **Fixed.** Non-creating `FindService` everywhere; missing required services are refused. The mock now creates services lazily in `GetService`, like Roblox, and counts calls. Every test asserts zero `GetService` calls and zero created services. New tests cover 6 missing scan-only services (check and install) and 5 missing required services. |
| **M2-I03** Instructions said "press Enter" only; in the multi-line Command Bar, Enter adds a line | Low | **Fixed** in `INSTALL_INSTRUCTIONS.md`: both Command Bar versions are described (Enter, or Ctrl+Enter / Cmd+Enter / Run), and every execution step says "run it". |
| **M2-R01** A fresh Baseplate might report its template's non-zero `PlaceId` and be refused | Medium (risk, unverified) | **Not changed, by design.** As recommended, the published-place refusal is kept until Studio observations exist. The installer now prints `PlaceId` and `GameId` on every run, and the refusal asks the owner to report rather than work around it. `INSTALL_INSTRUCTIONS.md` section 9 gives the observation procedure (before saving, after Save to File, after reopening). |
| Optional: positive test count | — | **Done.** The Lua suite prints `passed, failed, declared`; the runner requires passed = declared > 0 and failed = 0. |
| Optional: pin download links | — | **Done.** The download link in `INSTALL_INSTRUCTIONS.md` is pinned to the commit that contains the reviewed v1.1.0 installer. |

**The new tests detect the original defects.** Running the v1.1.0 test suite against the v1.0.0 installer from `de4aa63`:

- 67 of 69 tests fail, because every run called `GetService`.
- Two of the new rollback tests fail through the unexpected-error path that skipped cleanup (M2-I01).
- A direct probe shows v1.0.0's check mode creating `SoundService` while printing "Nothing was changed" (M2-I02). v1.1.0 creates nothing.

## Regenerate and verify

```bash
python3 tools/m2/generate_installer.py           # writes InstallM2.lua and INSTALLER_MANIFEST.txt
python3 tools/m2/generate_installer.py --check   # exit 0 only if both files equal a fresh generation
python3 tools/m2/tests/run_tests.py              # all offline checks (needs lua5.1 / luac5.1 on PATH)
```

`run_tests.py` covers:

1. The source commit resolves, `src/` has exactly the 24 expected files, and every SHA-256 matches round 4.
2. Classes, plus the Appendix A and B cross-checks.
3. Two in-memory generations and the committed files are byte-identical.
4. A second, independent decoder rebuilds every embedded file byte for byte.
5. A static scan of the installer logic finds no `GetService`, HTTP, DataStore, publish, `require`, `loadstring`, yields or similar calls, and confirms every service lookup uses the one `FindService` helper.
6. `luac5.1 -p` accepts the file.
7. The 69 Lua behaviour tests run; every declared test must run and pass.
8. An offline replica of the Appendix B logic checks the installed mock place.
9. `src/` is unchanged from the source commit; `SOURCE_HASHES.txt` keeps rounds 1-3 (hash lines unchanged) and round 4 is the only current round; every change since the source commit is a release-package file.

## What was and was not tested

**Tested offline** (Python 3, Lua 5.1.5, fake engine): everything in the list above. The 69 behaviour tests cover:

- check mode on a fresh place (no instance, property, `GetService` call or service created);
- a full install (exact Sources, classes, parents, `Enabled`, `RunContext`, 33 objects, nothing in StarterGui or StarterCharacterScripts, unrelated objects untouched);
- `CharacterAutoLoads` already false;
- a second run refused;
- 14 collision cases;
- 12 unsafe states (running, paused, not Studio, each `RunService` call failing, non-boolean, `RunService` lookup failing, non-zero `PlaceId` with the identity line, unreadable `PlaceId`, missing `StarterPlayerScripts`);
- 6 missing scan-only services (check and install; never created) and 5 missing required services (refused; never created);
- 6 kinds of damaged payload;
- 22 truncation points;
- joined lines and CRLF;
- 13 failures injected during installation, each followed by a complete rollback;
- 3 failures of the `CharacterAutoLoads` read or write during rollback, where all objects must still be removed;
- one rollback where `Destroy` fails, which reports `ROLLBACK INCOMPLETE`.

**Not tested — needs the project owner in Roblox Studio:**

- Whether the Command Bar (one-line or multi-line) accepts a ~241 KB paste. Every failure mode found offline was safe: a truncated paste either does not compile or never reaches the final call.
- The `PlaceId` and `GameId` of a fresh Baseplate before and after saving and reopening (M2-R01).
- The real values of `IsStudio`, `IsEdit` and `IsRunning` in Edit, Play, Run and paused states.
- `FindService` results for the services in a real Baseplate.
- Setting `Source` from the Command Bar, the default `RunContext` and `Enabled` of `Instance.new("Script")`, `Destroy` and parenting behaviour, and how Studio records these changes in undo history.
- Save and reopen of the installed place.
- The Appendix B checker (round 4 values) and the 67 unit tests on the installed place.
- `luau-compile` and `luau-analyze` were not available here. In the Codex review, `luau-compile` accepted v1.0.0, and v1.2.0's installer logic is unchanged from v1.1.0. Codex's native compile of the two round 4 source files is recorded in `review/M2_STUDIO_QA_RESULTS.md` section 2.2. `luau-analyze` reported missing Roblox globals, which is expected without Roblox type definitions.

## Limitations

- **Command Bar size.** The single-paste design is unverified in Studio. If Studio cannot take it, the fallback (for example a multi-part paste) needs its own design and review; the instructions tell the owner to report rather than improvise.
- **Published-place detection (M2-R01).** If Studio reports a template `PlaceId` for a fresh Baseplate, the installer refuses it until the detection is changed and reviewed.
- **Rollback depends on `Destroy`.** If Studio refuses to destroy an object this run created, the installer reports `ROLLBACK INCOMPLETE`, names the object, and tells the owner to close without saving. It never falls back to broader cleanup.
- **Studio undo history.** The installer does not create undo waypoints. The instructions tell the owner not to use Ctrl+Z to remove an installation.
- **The fake engine** models only the API surface listed in `tests/mock_roblox.lua`. It does not model security levels, replication, plugins or Studio itself.
- **The Appendix B checker itself** (unchanged, outside this tool) uses `game:GetService` in its scan, so it may create a missing scan-only service while it reads. That does not affect its parity result, and the checker must stay unchanged.

## Codex re-review prompt (v1.1.0; historical)

The current review prompt is `review/M2_BIGNUM_ADOPTION_CODEX_HANDOFF.md`.

> Re-review branch `feature/m2-tools-001-installer` of `zelly-cious/Emberbound`: the M2-TOOLS-001 installer v1.1.0, which corrects your review of v1.0.0 at `de4aa6399973089d33501731ddd5a0f0d928e435` (FAIL: M2-I01, M2-I02, M2-I03; risk M2-R01). Read-only: do not edit, commit or push. Read `tools/m2/README.md` (section "Corrections"), `tools/m2/INSTALL_INSTRUCTIONS.md`, `tools/m2/InstallM2.template.lua`, `tools/m2/generate_installer.py` and `tools/m2/tests/`, and diff against `de4aa63`.
>
> Verify:
> 1. **M2-I01:** no failure of `CharacterAutoLoads` reads or writes, or any other rollback step, can stop the destruction of objects this run created, and the outcome is always reported.
> 2. **M2-I02:** the installer logic never calls `GetService`; check mode cannot create services or instances or set properties; missing required services are refused.
> 3. **M2-I03:** the instructions are correct for both Command Bar versions.
> 4. **M2-R01:** the guard is kept and the diagnostic procedure is sound.
> 5. **Unchanged guarantees:**
>    - The 24 embedded sources are byte-identical to `src/` at `e9d878d94155610558c9c6252d76f202dfd956b4` and match `SOURCE_HASHES.txt` round 3.
>    - Generation is deterministic.
>    - Run `python3 tools/m2/generate_installer.py --check` and `python3 tools/m2/tests/run_tests.py`.
>    - Rerun your own probes, including the lazy-`GetService` mock and the failing rollback read.
>    - Compile with `luau-compile`.
>    - Confirm only `tools/m2/` changed relative to `2b832d267cc7461b5bebb138fe861d5b5e4ed0e9`.
>
> For each finding give severity, file and line, trigger, impact and the smallest fix; separate confirmed defects from Studio-dependent risks. Do not claim Studio results you did not observe.
