# Milestone 2 — Review guide

Everything a reviewer needs to audit Milestone 2 (Tap Upgrades, Economy & BigNum) from this repository alone. Line numbers refer to commit `024cd68838d6c34633a00e7eadcb320c251186f0`.

## 1. Explorer hierarchy

`src/` mirrors the Roblox Studio Explorer. Repository file names carry no `.server` / `.client` suffix; the class is given below.

```text
Players                                   CharacterAutoLoads = false (also enforced by ServerInit)
ReplicatedStorage
├── Shared (Folder)
│   ├── BigNum (ModuleScript)              NEW
│   ├── GameConfig (ModuleScript)          REVISED
│   └── ProgressionConfig (ModuleScript)   NEW
└── Remotes (Folder)
    ├── RequestAttack (RemoteEvent)        M1
    ├── ClientReady (RemoteEvent)          M1
    ├── CombatUpdate (RemoteEvent)         M1, payload changed
    ├── RequestUpgrade (RemoteEvent)       NEW
    ├── UpgradeUpdate (RemoteEvent)        NEW
    └── CurrencyUpdate (RemoteEvent)       NEW
ServerScriptService
├── ServerInit (Script)                    REVISED
├── CombatService (ModuleScript)           REVISED
├── CombatRules (ModuleScript)             NEW
├── CurrencyService (ModuleScript)         NEW
├── PlayerSessionService (ModuleScript)    NEW
├── RateLimiter (ModuleScript)             NEW
├── UpgradeService (ModuleScript)          NEW
├── Wallet (ModuleScript)                  NEW
└── Tests (Folder)                         NEW
    ├── TestRunner (Script)
    ├── TestKit (ModuleScript)
    ├── BigNumTests (ModuleScript)
    ├── CombatFormulaTests (ModuleScript)
    ├── CombatRulesTests (ModuleScript)
    ├── ProgressionTests (ModuleScript)
    ├── RateLimiterTests (ModuleScript)
    └── WalletTests (ModuleScript)
StarterPlayer
└── StarterPlayerScripts
    └── CombatClient (LocalScript)         REVISED
        ├── ArenaView (ModuleScript)       UNCHANGED
        ├── CombatHud (ModuleScript)       REVISED
        └── UpgradePanel (ModuleScript)    NEW
```

The six RemoteEvents are created by hand in Studio (the services `WaitForChild` them with a 10 s timeout and error if missing). No RemoteFunctions exist.

## 2. New and modified scripts

Package-to-repository name mapping (contents byte-identical): `ServerInit.server.luau` → `src/ServerScriptService/ServerInit.luau`; `Tests/TestRunner.server.luau` → `src/ServerScriptService/Tests/TestRunner.luau`; `CombatClient/CombatClient.client.luau` → `src/StarterPlayer/StarterPlayerScripts/CombatClient.luau`.

| File | Status | Lines | Purpose |
|---|---|---|---|
| `src/ReplicatedStorage/Shared/BigNum.luau` | new | 464 | Non-negative big numbers: math, compare, canonical text, display |
| `src/ReplicatedStorage/Shared/ProgressionConfig.luau` | new | 139 | Currency list (Gold), Tap Damage upgrade curve, start-up validation |
| `src/ReplicatedStorage/Shared/GameConfig.luau` | revised | 152 | Formulas return BigNum; new remote names, payload types, rate-limit values |
| `src/ServerScriptService/CombatRules.luau` | new | 90 | Pure per-player combat rules (spawn, hit, defeat, reward, advance) |
| `src/ServerScriptService/CombatService.luau` | revised | 235 | Combat state per player, `ApplyDamage`, `SetTapDamage`, tap cooldown, Gold grant on defeat |
| `src/ServerScriptService/CurrencyService.luau` | new | 140 | One Wallet per player; `Grant` / `TrySpend` with reasons; `CurrencyUpdate` |
| `src/ServerScriptService/Wallet.luau` | new | 80 | Pure balance bookkeeping; all-or-nothing, never negative |
| `src/ServerScriptService/RateLimiter.luau` | new | 66 | Token bucket per key, injectable clock |
| `src/ServerScriptService/UpgradeService.luau` | new | 222 | Purchase transaction, request-id replay guard, `UpgradeUpdate` |
| `src/ServerScriptService/PlayerSessionService.luau` | new | 147 | Join / ClientReady / leave across all services, in a fixed order |
| `src/ServerScriptService/ServerInit.luau` | revised | 27 | Starts CombatService, UpgradeService, PlayerSessionService |
| `src/ServerScriptService/Tests/*` | new | 8 files | TestKit, TestRunner (Studio only) and 48 deterministic tests |
| `src/StarterPlayer/StarterPlayerScripts/CombatClient.luau` | revised | 291 | Decodes BigNum strings, wires currency/upgrade updates and the panel |
| `src/StarterPlayer/StarterPlayerScripts/CombatClient/CombatHud.luau` | revised | 424 | Uses `BigNum.format`; Gold set separately via `SetGold` |
| `src/StarterPlayer/StarterPlayerScripts/CombatClient/UpgradePanel.luau` | new | 358 | Tap upgrade panel (placeholder UI) |
| `src/StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView.luau` | unchanged | 528 | — |

Full change against Milestone 1: `git diff 730218a 024cd68 -- src`.

## 3. Client–server architecture

```text
Client (CombatClient + ArenaView, CombatHud, UpgradePanel)
   │  RequestAttack()                 RequestUpgrade(upgradeId, requestId)        ClientReady()
   ▼                                  ▼                                            ▼
CombatService ◄── SetTapDamage ── UpgradeService ── TrySpend ──► CurrencyService ◄── PlayerSessionService
   │ ApplyDamage → CombatRules.resolveHit                          ▲  (Wallet)          add / sync / remove
   └──────────── Grant("Gold", reward, "EnemyDefeated") ───────────┘
Server → one client: CombatUpdate, CurrencyUpdate, UpgradeUpdate (FireClient only)
```

- **Server authority.** The client sends no numbers the server trusts: `RequestAttack` has no arguments (extras are never read, `CombatService.luau:230`), `RequestUpgrade` carries only an upgrade id and a request id. Damage, HP, stage, Gold, prices and outcomes are computed on the server.
- **Single damage path.** `CombatService.ApplyDamage` (`CombatService.luau:118-153`) is the only place HP changes. It calls the pure `CombatRules.resolveHit` (`CombatRules.luau:64-88`), which on defeat computes the reward, advances the stage and spawns the next enemy in the same non-yielding step, so a defeat is rewarded exactly once.
- **Lifecycle.** `PlayerSessionService` (`PlayerSessionService.luau:71-99`) adds a player to CurrencyService, CombatService, UpgradeService in that order inside a `pcall`, and removes in reverse (`:61-69`). `ClientReady` (`:101-120`) triggers one full sync, economy first and combat last (`:55-59`): CurrencyUpdate → UpgradeUpdate(Sync) → CombatUpdate(Sync). A `ClientReady` that arrives before the player is added is remembered and answered when ready; repeats within 1 s are ignored.
- **No partial updates before sync.** Each service keeps a per-player `synced` flag and sends nothing until its `SyncPlayer` runs; requests from an unsynced player are ignored.
- **Per-player isolation.** All state lives in tables keyed by `Player`; every update uses `FireClient(player, …)`. Nothing calls `FireAllClients`.
- **Client.** `CombatClient` connects all three update handlers before firing `ClientReady`, retries `ClientReady` 3 times at 3 s intervals with a final 3 s wait (the M1 sync fix), decodes every BigNum string with `BigNum.parse`, and ignores malformed payloads with a warning.

## 4. BigNum representation and API

**Representation** (`BigNum.luau:9-19`). A frozen table `{ m: number, e: number }`, value = m × 10^e, in exactly one of two regimes:

| Regime | Invariant | Purpose |
|---|---|---|
| small | `e == 0` and `0 <= m < 2^53` | m is the exact double, so early-game arithmetic is bit-identical to Milestone 1 |
| large | `1 <= m < 10`, integer `15 <= e <= 2^53 − 1`, value ≥ 2^53 | Range far beyond 10^308 (up to about 10^(9×10^15)) |

Each value has one representation, so equality and canonical strings are stable. This intentionally differs from the roadmap's "1 ≤ m < 10 for every value" to keep sub-2^53 values exact.

**Canonical text** (saving and network): `string.format("%.17g", m)` plus `"e<exponent>"` for large values, e.g. `"13"`, `"0.5"`, `"1.5e400"`. `parse(toString(x)) == x` for every valid x.

| Function | Notes |
|---|---|
| `zero`, `one` | Constants |
| `fromNumber(n)` | Errors on NaN, ±inf, negative |
| `fromLog10(x)` | 10^x without overflowing |
| `scaledPower(base, growth, steps)` | base × growth^steps; plain double while < 10^16 and < 2^53 (matches M1), else log space |
| `isValid(v)` | Full invariant check; use on any value from outside the module |
| `compare`, `eq`, `lt`, `lte`, `gt`, `gte`, `isZero`, `max`, `min` | Exponent first, then mantissa |
| `add(a, b)` | Exact while both small and the sum < 2^53; operands more than 17 orders of magnitude apart return the larger |
| `sub(a, b)` | **Saturating**: returns zero when b ≥ a |
| `trySub(a, b)` | nil when b > a (the "spend only if affordable" primitive) |
| `mul`, `mulNumber`, `div` | `div` errors on zero |
| `ratio(a, b)` | Plain number for display (health bar); may return `math.huge` |
| `floor`, `log10`, `toNumber` | `toNumber` returns `math.huge` above ~1.8e308; display only |
| `toString(v)` / `parse(text)` | Canonical text; `parse` never errors and returns nil for non-strings, empty or > 64 chars, signs, `inf`/`nan`, hex, or exponents beyond 2^53 − 1 |
| `format(v)` | `999`, `1.23K` … `999.99Dc`, then `1.23e456` |

Precision is about 17 significant digits; amounts smaller than about 10^-17 of the other operand are absorbed by `add`/`sub` (e.g. `1e20 − 5 = 1e20`).

## 5. Gold acquisition and spending

**Acquisition (one site).** Accepted tap → `CombatService.ApplyDamage` → `CombatRules.resolveHit`; on defeat `GameConfig.GetGoldReward(defeatedStage)` → `CurrencyService.Grant(player, "Gold", reward, "EnemyDefeated")` (`CombatService.luau:142`) → `Wallet.grant` (`Wallet.luau:48-55`, rejects unknown currency, invalid or zero amounts) → `CurrencyUpdate` to that player.

**Spending (one site).** `RequestUpgrade` → `UpgradeService.handlePurchaseRequest` (`UpgradeService.luau:123-162`):

1. Ignore if the player has no upgrade state or is not synced.
2. `RateLimiter:allow(player)` — burst 10, then 8 per second (`GameConfig.Network`). Over the limit: dropped, no reply.
3. `requestId` must be an integer, strictly greater than the last accepted id, ≤ 2^53 − 1; `upgradeId` must be a string naming a known upgrade. Otherwise dropped, no reply.
4. Record `lastRequestId`.
5. At max level → reply `MaxLevel`.
6. If the player has no combat state (leaving) → dropped, nothing charged.
7. `CurrencyService.TrySpend(player, "Gold", cost, "Upgrade:TapDamage")` (`UpgradeService.luau:153`) → `Wallet.trySpend` (`Wallet.luau:58-69`) → `BigNum.trySub`; all-or-nothing. Unaffordable → reply `InsufficientFunds`.
8. Level + 1 → `CombatService.SetTapDamage(player, value)` → reply `Ok`.

Steps 1–8 never yield, so concurrent requests are serialized by the Luau scheduler and each one sees the balance the previous one left. Each successful spend raises the level by exactly one; a replayed or older request id is ignored, so one request cannot charge twice. Nothing else writes balances.

## 6. Upgrade balancing formulas

All values come from `GameConfig.Combat` and `ProgressionConfig`; both validate at start.

| Quantity | Formula | Source |
|---|---|---|
| Enemy max HP | `max(1, floor(10 × 1.18^(stage − 1)))` | `GameConfig.luau:116-120` |
| Gold per defeat | `floor(5 × 1.12^(stage − 1))` | `GameConfig.luau:123-126` |
| Tap damage at level L | `floor(1 × L × 3^floor(L / 25))`, L = 1 … 100 000 | `ProgressionConfig.luau:93-97` |
| Cost of L → L + 1 | `floor(5 × 1.07^(L − 1))` | `ProgressionConfig.luau:100-103` |

Values computed by the shipped modules (offline harness):

| Level | Cost to next | Tap damage | | Stage | Enemy HP | Gold |
|---|---|---|---|---|---|---|
| 1 | 5 | 1 | | 1 | 10 | 5 |
| 2 | 5 | 2 | | 2 | 11 | 5 |
| 10 | 9 | 10 | | 3 | 13 | 6 |
| 24 | 23 | 24 | | 10 | 44 | 13 |
| 25 | 25 | 75 | | 50 | 33.28K | 1.29K |
| 50 | 137 | 450 | | 100 | 130.71M | 372.87K |
| 100 | 4.05K | 8.1K | | 210 | 10.55Qa (> 2^53) | 96.72B |
| 1 000 | 1.13No | 12.16Sx | | 4 276 | 1.98e308 (M1 overflowed here) | 1.28e211 |
| 100 000 | 1.12e2939 | 3.06e1913 | | 5 000 | 2.18e360 | 5.49e246 |

Reaching level 25 costs 280 Gold in total. The curve is temporary (Master Spec review: "5 Gold first cost, +7% per level, ×3 damage every 25 levels"); retuning is an M2/M4 balancing decision.

## 7. RemoteEvent contracts (no RemoteFunctions)

All server → client events use `FireClient` to the owning player only, and only after that service has synced the player. BigNum values travel as canonical strings.

| Remote | Direction | Payload | Server validation / behaviour |
|---|---|---|---|
| `RequestAttack` | C → S | none (extras ignored) | Synced player; ≥ 0.07 s since last accepted tap (`os.clock`); damage = server tap damage |
| `ClientReady` | C → S | none | Adds the player if needed; 1 s cooldown; sends CurrencyUpdate, UpgradeUpdate(Sync), CombatUpdate(Sync) in that order |
| `RequestUpgrade` | C → S | `(upgradeId: string, requestId: integer)` | See section 5. Silent drop when unsynced, rate-limited, malformed, replayed, unknown id or leaving; replies `Ok` / `InsufficientFunds` / `MaxLevel` otherwise |
| `CombatUpdate` | S → C | `{ kind: "Sync" \| "Hit" \| "Defeated" \| "Stats", snapshot: { stage: number, tapDamage: string, enemyId: number, enemyName: string, enemyHp: string, enemyMaxHp: string }, damage: string?, source: "Tap"?, goldAwarded: string? }` | `Hit`/`Defeated` carry `damage` and `source`; `Defeated` carries `goldAwarded` and the next enemy's snapshot; `Stats` = tap damage changed |
| `CurrencyUpdate` | S → C | `{ balances: { [currencyId]: string } }` | After every successful grant or spend, and on sync |
| `UpgradeUpdate` | S → C | `{ kind: "Sync" \| "PurchaseResult", upgrades: { [upgradeId]: { upgradeId, level, maxLevel, currencyId, currentValue: string, nextValue: string?, nextCost: string? } }, result: { requestId, upgradeId, success, reason: "Ok" \| "InsufficientFunds" \| "MaxLevel" }? }` | `nextValue`/`nextCost` are nil at max level |

**Breaking changes from M1:** `CombatSnapshot.gold` was removed (Gold now arrives only via `CurrencyUpdate`); every HP/damage/reward field changed from number to BigNum string; `CombatUpdate.kind` gained `"Stats"`; the `ClientReady` handler moved from CombatService to PlayerSessionService. Client and server ship together, so no old client exists.

A successful purchase produces, in order: `CurrencyUpdate` → `CombatUpdate(Stats)` → `UpgradeUpdate(PurchaseResult)`.

## 8. Security review checklist

Mark each item confirmed-by-source, needs-Studio-test, or defect.

- [ ] Client never supplies damage, HP, stage, Gold, price, level or outcome (`RequestAttack` no args; `RequestUpgrade` ids only).
- [ ] Every `OnServerEvent` handler type-checks every argument (`unknown` parameters, `typeof` checks) and tolerates nil, tables, NaN, ±inf, non-integers and huge integers.
- [ ] `RequestUpgrade`: rate limit applied before any work; rate-limiter entries removed on leave (`UpgradeService.luau:183-186`).
- [ ] Replay protection: `requestId` strictly increasing per player; cannot be reset by the client; a client sending 2^53 − 1 only blocks itself.
- [ ] Spend is all-or-nothing and non-yielding from check to deduction (`UpgradeService.luau:151-161`, `Wallet.trySpend`, `BigNum.trySub`); balance can never become negative.
- [ ] Exactly one charge per level gained; no path raises a level without a successful spend except `AddPlayer`'s starting level.
- [ ] Grants reject zero, invalid and unknown-currency amounts; no currency conversion function exists.
- [ ] Defeat rewards exactly once under rapid taps (`resolveHit` spawns the next enemy in the same step).
- [ ] `RequestAttack` cooldown cannot be bypassed by extra arguments, many remotes in one frame, or before sync.
- [ ] `ClientReady` spam cannot cause repeated full syncs faster than 1 s or re-create state for a leaving player.
- [ ] All server → client traffic is `FireClient` to the owning player; no shared or broadcast state.
- [ ] Player leave cleans every per-player table (sessions, upgrade states, combat states, wallets, rate-limit buckets).
- [ ] BigNum values from outside the module are validated (`isValid` / `parse`) before use; `parse` cannot error or produce NaN/inf.
- [ ] No yields inside economy transactions; no DataStore, HTTP or `InvokeClient` calls.
- [ ] `TestRunner` runs only when `RunService:IsStudio()`; test modules expose no remotes.
- [ ] Client-side affordability, click interval (0.15 s) and tap-area checks are hints only; the server re-checks everything.

## 9. Roblox Studio testing checklist

**Not performed during this handoff.** Run in Studio with the place built from `src/` and the six RemoteEvents created. Use *Test → Clients and Servers* (2 players) for S6.

| # | Test | Expected |
|---|---|---|
| S0 | Press Play; read Output | `[Tests] ALL PASSED (48 tests)`; no red errors; no `Missing RemoteEvent` errors |
| S1 | M1 regression: 10 taps at stage 1 | 10/10 → 0, one defeat, `+5 Gold`, stage 2 shows 11 HP; stage 3 shows 13 HP and pays 6 |
| S2 | Upgrade panel at 0 Gold | Button reads `Need 5 Gold`, does nothing; panel shows Level 1, Tap Damage 1, Next 2 damage |
| S3 | Earn 5 Gold, press Upgrade | Gold 5 → 0, Level 2, Tap Damage 2 in HUD and panel, `Upgraded!`; slime now takes 2 per tap |
| S4 | Rapid purchase: auto-clicker or command-bar loop firing `RequestUpgrade` 100× with new ids | Gold never negative; levels gained = successful replies; no errors |
| S5 | Replay: fire `RequestUpgrade("TapDamage", 1)` again after it succeeded | No reply, no charge |
| S6 | Two clients | Each player's Gold, level, damage, stage and HP are independent; one player's purchase sends nothing to the other |
| S7 | Malformed remotes from the client command bar (`nil`, `123`, `{}`, `"Nope"`, `1.5`, `"4"`, `0/0`, `math.huge`, `2^60`, `-5`) | Ignored, no server errors |
| S8 | Taps on the upgrade panel and its button (mouse and touch emulation, portrait and landscape, devices with safe-area insets) | Never count as attacks |
| S9 | Level 25 boundary (grant Gold via a Studio-only command bar call to `CurrencyService.Grant`) | Level 24 → 24 damage, level 25 → 75 damage |
| S10 | Large numbers (Studio-only grant of `BigNum.parse("1e400")`, `SetTapDamage(1e400)`) | HUD shows scientific notation; health bar and purchases still work; no `inf`/`nan` text |
| S11 | Leave and rejoin during combat | No errors; rejoin starts fresh at stage 1, 0 Gold (no persistence in M2) |
| S12 | Long session on a low-end phone | Stable frame rate and memory (M1 stress tests repeated) |

## 10. Known limitations and deliberately deferred features

- **No persistence.** All progress resets on leave (Milestone 3).
- **Tap damage is overwritten, not derived.** `SetTapDamage` replaces tap damage; a second stat source would conflict. Fix approved as **M2.1 StatService** after this audit; not implemented.
- **No profile-shaped state, schemaVersion, transaction log or dirty flag** (assigned to M3 by the Master Spec review).
- **No buy-max**, no general `BigNum.pow`.
- **Precision absorption:** with ~17 significant digits, a cost or reward smaller than ~10^-17 of the balance does not change it (a purchase at a 1e400 balance is effectively free). Acknowledged by the roadmap's "about 15 significant digits".
- **No overkill carry-over;** at most one defeat per hit (M4 balancing decision).
- **Silent drops:** rate-limited, malformed and unsynced purchase requests get no reply; the client keeps no pending-request state, so the UI cannot hang but shows no feedback.
- **Upgrade request ids are per server session** and must only increase; the client counter starts at 1 when the LocalScript starts (it does not restart without a character).
- **Placeholder UI;** the upgrade panel is functional, not final art.
- **Debug logging:** `GameConfig.Debug.LogPlayerLifecycle = true` prints on join/leave in live servers too.
- **Test modules ship in ServerScriptService** but only run in Studio.
- **Stale comments:** `ProgressionConfig` and `CurrencyService` headers mention "earned tickets, premium currency" (now Gems and Crowns).
- **Strict-mode type note:** under Luau's new type solver, `BigNum.luau:37` reports a type mismatch (`table.freeze` returns read-only fields; `BigNum` type declares read-write). Type-level only; see `review/M2_CHECK_RESULTS.md`.
- **Out of scope:** heroes, DPS, gacha, Gems, Crowns, equipment, trading, premium purchases, PolicyService, bosses, prestige. See `DECISIONS.md`.
