# Emberbound Milestone 2 — Roblox Studio QA results

Copy this file (for example to `review/M2_STUDIO_QA_RESULTS.md`), then fill it in while following `M2_STUDIO_REGRESSION_GUIDE.md`. Marks: **PASS**, **FAIL**, **BLOCKED** (say why), **NOT RUN** (optional tests only).

## Test setup

| | |
|---|---|
| Tester | |
| Date(s) | |
| Roblox Studio version | |
| Computer and OS | |
| Place file name | |
| Code tested | `src/` at `e4b01088b953acb7f5d31b77cbf4e3f5b5e8adcf` (same as PR #1 head `09be466`) |
| How the scripts were installed | manual copy / ZIP / other: |
| P-3 result (copy the two `[Parity]` lines) | |
| P-5 result (copy the two `[Parity]` lines) | |
| H-check result | Helpers OK / Helpers not connected, used the EmberboundQA bridge / Blocked |
| Devices used in the emulator | |
| Physical phone (if any) | |

## Results

| ID | Test | Result | Notes (numbers you saw, Output file, screenshot) |
|---|---|---|---|
| P-1 | Place, folders, remotes, CharacterAutoLoads | | graded by P-3 |
| P-2 | 24 scripts created | | graded by P-3 |
| P-3 | Source-parity check | | |
| P-4 | Downloaded files' SHA-256 (optional) | | |
| P-5 | Final parity re-check | | |
| T-1 | 61 tests in 7 suites pass | | |
| T-2 | Broken test module is a failure | | |
| M1-1 | Clean startup | | |
| M1-2 | No avatar, fixed camera | | |
| M1-3 | Initial sync and HUD values | | |
| M1-4 | Ten taps defeat stage 1 once | | |
| M1-5 | Stage 2 and 3 values | | |
| M1-6 | Server tap cooldown | | burst accepted = ; 5 s spam accepted = |
| M1-7 | Clicks outside the combat area | | |
| M1-8 | Extra attack arguments ignored | | |
| U-1 | Panel at 0 Gold | | |
| U-2 | First purchase | | |
| U-3 | HUD, panel and hits agree | | |
| U-4 | Level 24 → 25 by playing | | Gold before / after the 23-Gold purchase: |
| U-5 | Level 24 → 25 with exact Gold | | |
| U-6 | Gold exact below 2^53 | | logged balance: |
| U-7 | Resync after purchases | | |
| A-1 | Malformed upgrade requests | | |
| A-2 | ClientReady junk and spam | | burst syncs = ; spam syncs = / limit |
| A-3 | Replayed purchase ignored | | |
| A-4 | Server refuses unaffordable purchase | | |
| A-5 | Burst of 100 purchase requests | | replies = ; level and Gold after: |
| A-6 | Sustained purchase requests | | replies = / limit |
| A-7 | Largest request id | | |
| B-1 | Combat independent per player | | |
| B-2 | Purchases independent per player | | |
| B-3 | Request ids per player | | |
| B-4 | Cannot act for another player | | |
| B-5 | Replay protection still independent | | |
| D-4 | Startup sync with heavy lag | | lag setting had an effect: yes / no |
| D-1 | Taps under lag | | |
| D-2 | Two purchase clicks before the reply | | |
| D-3 | Several purchases in flight, then resync | | |
| MOB-1 | Portrait layout | | devices: |
| MOB-2 | Landscape layout | | devices: |
| MOB-3 | One tap = one attack | | |
| MOB-4 | Panel and button taps never attack | | |
| MOB-5 | Combat-area edges and insets | | |
| MOB-6 | Rotate during combat | | |
| MOB-7 | Small phone and tablet | | |
| MOB-8 | Touchscreen PC (optional) | | |
| MOB-9 | Physical phone (optional) | | |
| N-1 | BigNum spot checks | | |
| N-2 | Purchases with a huge Gold balance | | |
| N-3 | Huge tap damage display | | |
| N-4 | High-stage HP display | | final stage and HP text: |
| N-5 | Health bar at large values | | |
| N-6 | Long numbers on the smallest phone | | |
| L-1 | Player leaves; server cleans up | | |
| L-2 | New player joins running server | | |
| L-3 | Restart gives a fresh game | | |
| L-4 | Leaving while requests arrive | | |
| C-1 | Baseline object counts | | hud= panel= stage= |
| C-2 | Fast manual clicking | | |
| C-3 | Ten minutes of enemy churn | | final stage; memory at 1 / 5 / 10 min: |
| C-4 | Three minutes at tap damage 1 | | |
| C-5 | Long manual session | | |

**Totals:** PASS ___ FAIL ___ BLOCKED ___ NOT RUN ___

## Failure reports

Copy this block once per FAIL.

```text
Test ID:
Session / mode (Play, 2 players, emulator device + orientation, lag setting):
Steps I did (exact):
Expected (from the guide):
What happened instead:
Output lines (red/orange lines plus the lines after them; which window):
_G.QA.summary() line, if relevant:
Screenshot file names:
Reproduced: __ of __ tries (fresh Play each time)
P-3 parity line at the time:
Notes:
```

## Observations (not failures)

Things that looked odd but did not break a PASS rule (for example update order in the logger, the panel partly covering the slime, memory readings, Studio or plugin messages).

-
