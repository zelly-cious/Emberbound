# Milestone 2 — Static checks and automated tests actually executed

> **Historical — round 1.** These are the results for the audited commit `024cd68` / PR head `eb5a351`, kept unchanged as evidence. The Codex audit later found F1–F6, which these checks missed. Results for the corrections commit `e4b0108` are in `review/M2_CORRECTIONS_REPORT.md`.

Run on 31 Oct 2026 against commit `024cd68838d6c34633a00e7eadcb320c251186f0`, on Windows 11 (Git Bash). **Roblox Studio was not used.** Nothing below is a Studio, live-server, device or multi-client result.

| Check | Tool | Scope | Result |
|---|---|---|---|
| Shipped unit tests | Luau CLI 0.745 + `review/offline-harness` | 6 suites, 48 tests, run by the shipped `TestRunner` | **48 / 48 passed** |
| Review probes | Luau CLI 0.745 + `review/offline-harness/probes.luau` | BigNum, > 10^308, M1 compatibility, cost curves, server services with two fake players | **54 / 54 passed**, 4 observations |
| Lint | Selene 0.32.0, `std = "roblox"` | All 23 files under `src/` | **0 errors, 0 warnings** |
| Strict type check | `luau-analyze` 0.745, `--mode=strict`, new and old solver | 13 modules that use no Roblox API (copies with requires rewritten) | 1 finding in game code (new solver only); everything else is a rewrite artifact or false positive |
| Package integrity | `sha256sum` | 23 `.luau` files vs `Emberbound_M2_Scripts.zip` | All byte-identical; the package's `CHANGES_FROM_M1.diff` matches `git diff 730218a 024cd68 -- src` line for line (568 changed lines) |

Tool sources: [luau-lang/luau 0.745](https://github.com/luau-lang/luau/releases/tag/0.745) (`luau-windows.zip`), [Kampfkarren/selene 0.32.0](https://github.com/Kampfkarren/selene/releases/tag/0.32.0) (`selene-0.32.0-windows.zip`). Selene downloaded its Roblox standard library on first use.

## 1. Unit tests (48)

```bash
review/offline-harness/run.sh unit path/to/luau
```

```text
[Tests] BigNumTests: 21 passed, 0 failed
[Tests] CombatFormulaTests: 4 passed, 0 failed
[Tests] CombatRulesTests: 5 passed, 0 failed
[Tests] ProgressionTests: 7 passed, 0 failed
[Tests] RateLimiterTests: 3 passed, 0 failed
[Tests] WalletTests: 8 passed, 0 failed
[Tests] ALL PASSED (48 tests)
```

The harness (`review/offline-harness/roblox_shim.luau`) fakes only what these modules touch: the Instance tree from `src/` paths, `game:GetService`, `WaitForChild`, `require(ModuleScript)`, `RunService:IsStudio()` (true), `warn`, a controllable `os.clock`, and `Random`. **Differences from Studio:**

- The first run failed 1 test because the shim had no `Random`. A seeded stand-in was added; it has Roblox's API but **not the engine's sequence**, so `BigNumTests > canonical strings round-trip exactly` checks 200 different random values than it would in Studio.
- Math functions (`math.log10`, `^`, `string.format("%.17g")`) are the Luau CLI's on Windows, not the Roblox server's. Results in the last binary digit could differ by platform.

## 2. Review probes (54 checks)

```bash
review/offline-harness/run.sh probes path/to/luau
```

Section 5 loads the real `ServerInit`, `PlayerSessionService`, `CombatService`, `CurrencyService` and `UpgradeService` against fake `Players` and RemoteEvents. **Fake remotes run handlers synchronously and immediately**; Roblox may defer them. Handler errors are caught and counted (zero occurred).

One probe expectation was wrong on the first run (it assumed `1.5e36` formats as `1.5Dc`; `Dc` is 10^33, so `1.5e36` is correctly scientific). The probe was corrected; the game code was not touched.

```text
== 1. BigNum precision and serialization
  PASS 20003 random values are valid BigNums
  PASS 20003 random values round-trip through toString/parse
  PASS compare() agrees with log10 ordering on 5000 random pairs
  PASS integers below 2^53 add exactly
  PASS parse rejects exponent 2^53
  PASS parse accepts exponent 2^53 - 1
== 2. Values beyond 10^308
  PASS 1e309 > largest double
  PASS 1e200 * 1e200 = 1e400
  PASS 1e400 + 1e400 = 2e400
  PASS 1.5e400 - 5e399 = 1e400
  PASS trySub refuses 1e400 - 1e401
  PASS sub saturates at zero
  PASS toNumber(1e400) is math.huge (display only)
  PASS format(1e400) = 1e400
  PASS format(1.5e35) = 150Dc and format(1.5e36) = 1.5e36
  PASS ratio(1e400, 2e400) = 0.5
  PASS mul overflow past exponent 2^53 - 1 errors
  OBSERVE small amounts vanish next to huge ones (17-digit precision): 1e20 - 5 = 1e20, 1e20 + 5 = 1e20
== 3. Milestone 1 formula compatibility
  PASS enemy HP matches M1 exactly on 209 stages where M1 < 2^53 (1..209)
  PASS gold reward matches M1 exactly on the same stages
  OBSERVE stage 5000: M1 HP = inf, M2 HP = 2.17848474609035e360
  PASS tap damage at level 1 equals M1 starting damage (1)
== 4. Upgrade cost and value formulas
  PASS cost(level) = floor(5 * 1.07^(level-1)) for levels 1..3000 (where < 2^53)
  PASS value(level) = floor(level * 3^floor(level/25)) for levels 1..3000 (where < 2^53)
  PASS cost and value never decrease from one level to the next
  PASS first purchase costs 5 Gold
  PASS level 24 -> 24 damage, level 25 -> 75 damage (first milestone x3)
  PASS max level 100000 cost and value are valid BigNums
  OBSERVE level 100000: cost 1.12e2939, damage 3.06e1913
  PASS level 0, maxLevel + 1 and 1.5 are rejected
== 5. Server services with two players (fake engine, synchronous remotes)
  PASS requests before ClientReady are ignored (no messages, no charge, level 1)
  PASS sync order is CurrencyUpdate, UpgradeUpdate, CombatUpdate
  PASS sync payloads: Gold 0, level 1, next cost 5, damage 1, stage 1, HP 10/10
  PASS a second ClientReady within the 1 s cooldown is ignored
  PASS defeat pays 5 Gold and the snapshot is the stage 2 enemy
  PASS 10 spaced taps of 1 damage defeat the 10 HP slime exactly once
  PASS Alice has 5 Gold; Bob is untouched (0 Gold, no messages)
  PASS 20 taps in the same instant: at most 1 accepted (0.07 s cooldown)
  PASS purchase #1 succeeds: Gold 5 -> 0, level 2, tap damage 2
  PASS purchase messages: CurrencyUpdate, CombatUpdate(Stats), UpgradeUpdate(PurchaseResult)
  PASS replayed or older request ids are ignored with no reply and no charge
  PASS purchase with 0 Gold -> InsufficientFunds, balance stays 0 (never negative)
  PASS 10 malformed requests change nothing and get no reply
  PASS 50 requests in one instant: exactly 10 processed (burst capacity)
  PASS levels gained == successful replies == 10
  PASS Gold spent equals the exact sum of the 10 level costs (no duplicate charge)
  PASS after 0.5 s only 4 more requests are processed (8 per second)
  PASS out-of-order request id 99 after 100 is ignored
  PASS Bob's request id 1 is accepted independently of Alice's ids (InsufficientFunds at 0 Gold)
  PASS Alice received nothing from Bob's request
  PASS purchase with a 1e400 balance succeeds
  OBSERVE balance after that purchase: 1e400 (cost is below the 17-digit precision, so it is absorbed)
  PASS a 1e400 tap defeats the enemy and every network number parses
  PASS ApplyDamage rejects NaN, 0, negative and invalid tables
  PASS Grant rejects zero, invalid and unknown currencies
  PASS after leaving, Alice's state is gone everywhere and her requests are ignored
  PASS Bob is unaffected by Alice leaving
  PASS no remote handler raised an error
[Probes] 54 passed, 0 failed
```

How the requested review areas map to evidence:

| Area | Evidence | Not covered |
|---|---|---|
| BigNum precision and serialization | Probes 1, BigNumTests | Engine-specific float behaviour |
| Values exceeding 10^308 | Probes 2, 5h | HUD rendering of huge values (client not run) |
| Upgrade cost calculations | Probes 4, ProgressionTests | — |
| Currency balance validation | WalletTests, probes 5d, 5h | — |
| Rapid purchase requests | Probes 5f | Real network timing, deferred signal ordering |
| Duplicate charges | Probes 5d, 5f | Same |
| Negative balance prevention | WalletTests, probes 5d | — |
| Multiplayer isolation | Probes 5c, 5g, 5i (two fake players, one server) | Real two-client Studio test |
| Compatibility with Milestone 1 | Probes 3 (formulas vs `730218a`), 5c (10 taps → one defeat, 5 Gold, stage 2) | Client visuals, input, camera |

## 3. Selene lint

```bash
selene --config selene.toml --display-style quiet src    # selene.toml: std = "roblox"
```

```text
Results:
0 errors
0 warnings
0 parse errors
```

Sanity check: the same configuration reports `undefined_variable` and `unused_variable` on a planted test file and accepts `game`, `workspace`, `Enum`, `Vector3` and `task`, so the Roblox standard library was loaded.

## 4. Strict type check (partial)

`luau-analyze` has no Roblox type definitions, so only the 13 modules that use no Roblox API were checked: BigNum, GameConfig, ProgressionConfig, Wallet, RateLimiter, CombatRules, TestKit and the six test suites. In temporary copies (line numbers preserved), `require(<Instance path>:WaitForChild("X"))` became `require("./X")`, `game:GetService(...)` became `(nil :: any)` and `Random.new` became `(nil :: any).new`.

```bash
luau-analyze --mode=strict --formatter=plain *.luau                 # new solver (default)
luau-analyze --mode=strict --solver=old --formatter=plain *.luau
```

| Report | Solver | Classification |
|---|---|---|
| `BigNum.luau:37` — expected `BigNum`, got `{ read e: number, read m: number }` | new only | **Real, type-level only.** `table.freeze` returns read-only fields; the exported `BigNum` type declares read-write `m`/`e`. No runtime effect. Would appear in Studio's Script Analysis when the new solver is enabled. Not fixed (frozen code). |
| `TestKit.luau:66` — "Function only returns 1 value, but 2 are required" | old only | False positive: `pcall(test.run)` returns two values. |
| `RateLimiterTests.luau:24, 30` — DuplicateCondition | both | False positive: `limiter:allow("a")` has side effects, so repeating it is intended. |
| `TestKit.luau:71, 81` — unknown global `warn` | both | Artifact: `warn` is a Roblox global. |
| LocalUnused `ReplicatedStorage` / `ServerScriptService` (8 files) | both | Artifact of the require rewrite. |

**Not type-checked:** CombatService, CurrencyService, UpgradeService, PlayerSessionService, ServerInit, TestRunner and all four client scripts (they need Roblox type definitions — use Studio's Script Analysis or `luau-lsp analyze` with Roblox definitions).

## 5. Not executed

- Anything in Roblox Studio: Play, Team Test, the Studio-only `TestRunner`, client UI, input, camera, rendering, device emulation, performance.
- Client scripts (`CombatClient`, `CombatHud`, `UpgradePanel`, `ArenaView`) at runtime.
- Real RemoteEvent semantics (deferred signal behaviour, network latency, packet ordering, exploiter clients).
- There is **no user-reported Milestone 2 QA**; the package README's "ALL PASSED (48 tests)" lines are expected checkpoints, not results. `QA_REPORT.md` covers Milestone 1 only.
