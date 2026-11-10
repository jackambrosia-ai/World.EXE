# Claude: Start Here — WORLD.EXE

You are the implementation agent for WORLD.EXE. The user has connected you to Roblox Studio. ChatGPT is the project's game architect and technical reviewer. This GitHub repository is the shared source of truth for specifications and version-controlled code.

Repository: https://github.com/jackambrosia-ai/World.EXE

## Make sure you can read the repository

Choose the workflow that matches your Claude client:

- **Claude Projects / GitHub connector:** In Project Knowledge, click `+` → GitHub, authorize Claude's GitHub app to access the private repository `jackambrosia-ai/World.EXE`, and select `README.md`, this file, all of `docs/`, and all of `prompts/`. Sync the project after repository updates. This provides repository context; it does not by itself give a web chat local filesystem or Roblox Studio MCP access.
- **Claude Code (recommended for direct implementation):** Clone the repository on the same computer as Roblox Studio, open a terminal in the clone, and launch Claude Code there:
  ```bash
  git clone https://github.com/jackambrosia-ai/World.EXE.git
  cd World.EXE
  claude
  ```
  If already cloned, run `git pull` and `git status`. Authenticate GitHub in the local terminal if needed. Keep the Roblox Studio MCP connection configured in this same local Claude Code environment.

Do not assume that GitHub access and Roblox Studio access are the same connection. Verify both separately.

## Required first action: read-only audit

Read:
- `README.md`
- `docs/00_MASTER_INSTRUCTIONS.md`
- `docs/01_GAME_DESIGN.md`
- `docs/02_TECHNICAL_ARCHITECTURE.md`
- `docs/03_PATCH_CATALOG.md`
- `docs/04_UI_AND_ART_DIRECTION.md`
- `docs/05_DEVELOPMENT_ROADMAP.md`
- `docs/06_TESTING_AND_RELEASE.md`
- `prompts/00_AUDIT_AND_SETUP.md`

Then execute only the audit prompt. **Do not modify the Roblox place or repository yet.**

1. Confirm repository, current branch, local working tree, and that all required docs/prompts are accessible.
2. Confirm the Roblox Studio MCP connection and list connected Studio sessions.
3. Identify the intended place and inspect its DataModel/Explorer hierarchy, scripts, remotes, assets, and Output errors.
4. Determine whether this is a blank, partially built, or existing experience.
5. Identify reusable systems, conflicts, risks, and missing prerequisites.
6. Propose a backup approach.
7. Recommend and verify a source synchronization workflow between the local repository and Studio (Rojo or an explicit alternative) before major code work.

Report:
- Repository and branch detected.
- Studio place and connection status.
- Existing project structure and reusable systems.
- Which MCP capabilities are available and actually verified.
- Source-sync recommendation and any local setup required.
- Risks, conflicts, missing prerequisites, backup plan.
- Proposed Phase 1 implementation plan.

Do not create, delete, rename, or edit anything yet. Do not publish, purchase assets, upload assets, change monetization, or grant additional permissions.

Wait for the owner's explicit approval before Phase 1.

## Project objective

Build an original Roblox multiplayer reality-manipulation sandbox. Players take turns submitting approved patches that change the world. Patches can modify physics, environment, spawn entities, or create beneficial opportunities. Several patches may coexist within explicit limits and compatibility rules.

The experience combines creative player-driven patch submissions, survival and counterplay, shared stabilizer objectives, individual scoring/placement, a simulation stability meter and final instability phase, plus patch discovery/mastery/progression/cosmetics.

## Initial design targets

- One launch mode: Stability Run.
- One launch arena: The Sandbox (Central Core, Research Yard, Skybridge).
- 8–12 players initially.
- Approximately 7–9 minutes per match; tune with tests.
- No more than three active major patches initially.
- First four prototype patches: ZERO_G, DECAY, DRONE_SWARM, SUPPLY_DROP.
- First three abilities: PHASE_DASH, ANCHOR, SCANNER.
- Data-driven definitions and server-authoritative gameplay.

## Git workflow
1. Work from this local repository clone when using Claude Code.
2. Use focused branches for implementation phases.
3. Make small descriptive commits.
4. Push completed work so ChatGPT can review it.
5. Summarize files changed, tests run, results, known issues, and next steps.
6. Do not merge to main or publish a release without the owner's approval.

## Required behavior
Never claim a feature works without testing it. Distinguish a solo test from a multi-client test. If a tool or capability is unavailable, state exactly what is missing and provide the next safe step. Follow all engineering and safety rules in `docs/00_MASTER_INSTRUCTIONS.md`.

After audit approval, execute phase prompts in numerical order from `prompts/`, stopping at each acceptance gate.
## ForgeGUI is also connected

The user reports that ForgeGUI is connected to your Claude environment. During the read-only audit:
1. Verify that the ForgeGUI MCP/tools are actually available in this client session.
2. List the relevant available capabilities (e.g. asset/UI image generation, reference search, project editing/export, publishing) without invoking paid or mutating operations.
3. Distinguish ForgeGUI generation from Roblox Studio MCP. Studio MCP is still required to inspect/edit the live DataModel, wire working UI, and playtest.
4. Read `docs/09_FORGEGUI_WORKFLOW.md`.

Do not generate paid assets, consume credits, upload assets to Roblox, or publish through ForgeGUI until the owner explicitly approves the specific asset batch, estimated credit spend, and destination. A successful generation or export does not prove an asset was imported into the intended place; verify the actual Studio result.
