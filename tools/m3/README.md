# M3 private Studio test build

This candidate includes M2.1 and M3. The exact source is `23785544f846817c5d722f69d5e81b11348df46f`, with installer version `3.0.0-qa.1`. It is a test candidate awaiting review and the focused Studio checkpoint. The frozen M2 installer (`tools/m2/InstallM2.lua`, v1.2.0) still installs the historical M2 release.

## Install in a fresh place

1. In Roblox Studio create a **fresh Baseplate**, save it to a local file, and stop any playtest. Use a separate test copy of the game.
2. Open [InstallM3.lua](InstallM3.lua), copy its entire contents into the Studio Command Bar and run it. The default setting is `ENABLE_INSTALLATION = false`; it reports readiness and changes nothing.
3. After `Ready to install: YES`, paste the full installer again with its one setting changed to `ENABLE_INSTALLATION = true`. Expect `Scripts: 34/34` and `INSTALLATION COMPLETE`. It refuses published places, running playtests, collisions and existing scripts. It never replaces an existing script.
4. Save, close and reopen the local place. In edit mode run the full contents of [VerifyM3.lua](VerifyM3.lua). Expect `[Parity] scripts matching: 34 / 34, remotes: 6 / 6, extra scripts: 0` and `[Parity] RESULT: PASS`.
5. Press Play. The 11 unit suites should end with `[Tests] ALL PASSED (123 tests)`. The unpublished place uses **memory for that play session**; stopping Play discards those saves.

The file layout and checksums are in [STUDIO_GUIDE.md](STUDIO_GUIDE.md); SHA-256 values also appear in [the installer manifest](INSTALLER_MANIFEST.txt) and root `SOURCE_HASHES.txt`, round 5. The independent verifier counts disabled extra scripts. Keep `EmberboundStatQA` in your separate QA copy; remove it from any copy where you record release parity.

## Focused persistence checkpoint before M4

After review, publish this installed copy as a **separate private test experience**. All places within one experience share DataStores, so a new place within the release experience does not isolate its data. Enable Studio API access only for this separate test experience. Publication is a producer action; the installer does not publish anything.

In that private experience:

1. Start Play and confirm Output says `Studio is using the place's DataStore: saves persist.` A memory-mode message means the persistence checkpoint has not started.
2. Earn Gold, clear several stages and buy an upgrade. Record Gold, current stage, level and tap damage. On the **server** Command Bar, the following read-only snapshot also shows both highest-cleared records and active time:

   ```lua
   local player = game:GetService("Players"):GetPlayers()[1]
   local data = require(game.ServerScriptService.PlayerDataService)
   local schema = require(game.ServerScriptService.ProfileSchema)
   local profile = player and data.GetProfile(player)
   if profile then print(game:GetService("HttpService"):JSONEncode(schema.encode(profile))) end
   ```

3. Pause gameplay, allow at least 60 seconds for autosave, then read your own test record from the server Command Bar. Run this only in the isolated test experience:

   ```lua
   local player = game:GetService("Players"):GetPlayers()[1]
   if player then
       local store = game:GetService("DataStoreService"):GetDataStore("EmberboundProfiles")
       print(game:GetService("HttpService"):JSONEncode(store:GetAsync("player_" .. player.UserId)))
   end
   ```

4. Stop/restart Play or leave/rejoin. Gold, level, current stage, both highest-cleared records and derived tap damage should restore; the current enemy starts at full HP. Active seconds are retained, with no credit for time spent disconnected. After stopping, a successful release has saved the final state and removed the record's lock. Check the record before starting the next session when verifying release; a new session claims its own lock.
5. The checkpoint also requires delayed final save/rejoin and controlled load/save failure with reviewed test hooks. The offline regressions pass, but a real-Studio fault-injection adapter is **still to be prepared/reviewed**. Do not mark these scenarios passed from an ordinary successful rejoin or from the offline results.
6. Record the source pin, real DataStore mode and a concise result in `review/m3/M3_STUDIO_QA_RESULTS.md`. Keep any unperformed checks pending. Broader integrated manual QA remains at launch after M8.

## Rebuild and verify offline

Requires Python 3.10+, Git and Lua 5.1 (`lua5.1` on PATH):

```text
python3 tools/m3/generate_package.py --check
python3 tools/m3/check_package.py
python3 review/m3/run_checks.py
```

Generation reads immutable Git blobs named in `SOURCE_COMMIT.txt`. Any later gameplay change needs a new source pin and regenerated package. The M2 verifier scripts target round 4; run them on the frozen M2 release when reviewing that historical package.
