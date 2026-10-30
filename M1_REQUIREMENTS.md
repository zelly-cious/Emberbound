# Milestone 1 — Frozen scope and acceptance contract

## Game

Original working title **Emberbound**, fixed-camera, one-enemy-at-a-time, idle/clicker RPG inspired by the gameplay loop of Tap Titans and Clicker Heroes; not a reproduction of their assets or branding.

## Intended gameplay

- Stage 1 begins at 0 Gold with Tap Damage 1.
- Forest Slime spawns at 10/10 HP.
- Player mouse clicks or phone taps in combat area request attacks; server validates and applies damage.
- After 10 accepted 1-damage taps, stage 1 slime is defeated once; 5 gold is awarded once; stage advances to 2 and new enemy spawns.
- Initial formulas: `floor(10 * 1.18^(stage - 1))` enemy HP; `floor(5 * 1.12^(stage - 1))` gold per defeat. Starting tap cooldown is 0.07s server-side.
- At stage 2: 11 HP, 5 gold reward; stage 3: 13 HP, 6 gold reward.
- Each player has completely independent gold, enemy HP, and stage progression.
- No avatar needed; fixed `Scriptable` camera and local enemy/arena presentation.
- Current client and server communicate via `RequestAttack`, `ClientReady`, `CombatUpdate`. Combat state snapshots return from server; client doesn't supply damage numbers.

## Explicit exclusions from Milestone 1

No gold upgrade purchases, automatic heroes/DPS, boss fight logic, prestige, persistence, equipment, or real-money monetization. Review the foundation's ability to grow into them without demanding their implementation now.

## Specific quality concerns to audit

- Remote attack cooldown and potential spam abuse.
- Exactly-once enemy defeat and gold reward under fast requests.
- `PlayerAdded`/`PlayerRemoving` lifecycle and startup handshake; missed sync retries.
- One player's events/states cannot change another player's.
- Mouse/touch duplicate events and UI tap-region filtering across insets and orientations.
- Client-side animation/tween/event cleanup, old enemy retirement and memory/performance on a long session.
- Roblox API correctness, strict Luau types, `CharacterAutoLoads` behavior.
- Overflow or numeric limits only insofar as they affect Milestone 1 or clearly block later stages; otherwise defer.
