# EMBERBOUND — MILESTONE 1 CODEX REVIEW HANDOFF

**Purpose:** Independent, read-only audit of Claude-generated Roblox Luau code before Milestone 2.

This is the six-script Milestone 1 implementation extracted from the previously provided Claude response. The six script bodies are unchanged. It is **not** a Roblox `.rbxl` place file and does not include world assets; the client constructs the camera, arena, slime, and HUD at runtime. The `src/` file layout mirrors the intended Roblox Studio Explorer placement.

## What to read, in order

1. `QA_REPORT.md` — user-reported manual test outcomes and limitations.
2. `M1_REQUIREMENTS.md` — agreed scope, network contract, architecture, and acceptance criteria.
3. `AGENTS.md` — read-only reviewer rules.
4. All six `.luau` files under `src/`.
5. `REVIEW_PROMPT.md` — one-shot prompt and required report format.

## Roblox Studio object hierarchy

```text
ReplicatedStorage
├── Shared (Folder)
│   └── GameConfig (ModuleScript)
└── Remotes (Folder)
    ├── RequestAttack (RemoteEvent)
    ├── ClientReady (RemoteEvent)
    └── CombatUpdate (RemoteEvent)
ServerScriptService
├── CombatService (ModuleScript)
└── ServerInit (Script)
StarterPlayer
└── StarterPlayerScripts
    └── CombatClient (LocalScript)
        ├── ArenaView (ModuleScript)
        └── CombatHud (ModuleScript)
```

The installer sets `Players.CharacterAutoLoads = false`; `ServerInit` also checks this at runtime. Each client constructs its own local 3D scene. No DataStore persistence is implemented in M1.

## How to use with Codex

**Codex app or local CLI:** Unzip this package into a project folder, open the extracted folder in Codex, then paste the text from `REVIEW_PROMPT.md` as the task. Ask for read-only review. Do not run the Studio installer in a normal shell; it's a Roblox Studio Luau Command Bar script.

**Codex Cloud/PR review:** Add these extracted files to a GitHub repository (or a branch). Connect the repository to your Codex environment and request a read-only review with `REVIEW_PROMPT.md`. Codex Cloud availability/setup depends on your account and workspace. A plain ZIP is not a GitHub repository.

**Important:** Code inspection cannot reproduce Roblox Studio runtime testing. Treat QA as user-reported evidence, not proof that Codex ran tests.

## After the audit

Send the report back to ChatGPT. Confirm the high-priority findings, send only the accepted fixes to Claude, and repeat the relevant Roblox Studio regression tests before milestone approval. Do not start Milestone 2 just because an AI says PASS.
