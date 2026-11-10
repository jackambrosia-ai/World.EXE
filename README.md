# WORLD.EXE

**Reality is yours to break.**

WORLD.EXE is an original medium-scope Roblox multiplayer reality-manipulation sandbox. Players take turns submitting curated, predefined patches that alter the simulation. Players adapt, survive, complete shared objectives, compete for individual score, and discover combinations between active patches.

## Project vision
- Creative player-driven reality changes.
- Hybrid gameplay: survival, cooperative objectives, and individual competition.
- Readable, fair counterplay: warn players before dangerous effects and provide a meaningful response.
- Data-driven patches with independent lifecycles and explicit cleanup.
- Expandable progression, collections, mastery, abilities, and cosmetics.
- Visual direction: polished Roblox sci-fi simulation; navy, cyan, violet, restrained amber warnings.

## Core experience
- **Launch mode:** Stability Run
- **Initial arena:** The Sandbox, with Central Core, Research Yard, and Skybridge
- **Target server size:** 8–12 players initially
- **Target round length:** approximately 7–9 minutes (tune through playtesting)
- **Initial active major patch cap:** 3 (tune after performance testing)

## First prototype patches
1. `ZERO_G` — global low-gravity modifier.
2. `DECAY` — telegraphed temporary platform/environment decay.
3. `DRONE_SWARM` — server-controlled hostile drone entities.
4. `SUPPLY_DROP` — contested beneficial collectible drop.

Build the playable core before shops, monetization, elaborate cosmetics, or large content expansions.

## Repository layout
- `docs/` — master instructions, game design, technical architecture, patch catalog, UI/art direction, roadmap, testing/release.
- `prompts/` — sequential phase-by-phase prompts for Claude.
- `CLAUDE_START_HERE.md` — exact Claude onboarding and first audit instructions.

## Give Claude access to this project

### Option A — Claude Projects / GitHub connector (easy context sync)
1. Open Claude and create/open your WORLD.EXE Project.
2. In Project Knowledge, click the `+` button and choose GitHub.
3. Authorize Claude's GitHub app for the private repository `jackambrosia-ai/World.EXE`. If the repository is missing, grant the Claude GitHub App access to this specific private repo in GitHub settings.
4. Select the repository files `README.md`, `CLAUDE_START_HERE.md`, all files in `docs/`, and all files in `prompts/`.
5. Sync when the repository changes.

This is a context-reading/sync path. Anthropic's GitHub integration documentation says it syncs selected file names and contents from a branch; it does not retrieve commit history or PR metadata. For direct local file editing and pushing, use Option B.

### Option B — Claude Code with local Roblox Studio MCP (recommended for building)
Run these commands in a terminal on the same computer where Roblox Studio is open:

```bash
git clone https://github.com/jackambrosia-ai/World.EXE.git
cd World.EXE
claude
```

Authenticate GitHub for that local terminal (for example, with GitHub CLI or your existing Git credential manager) if the private clone asks for credentials. Launch Claude Code from inside the cloned folder so it can read and edit the repository. Keep the Roblox Studio MCP connection configured in the same local Claude Code environment/session. Do not assume the GitHub web connector alone gives Claude local Studio access.

If the repository is already cloned, use `git pull` before starting and `git status` to check for local changes.

### Keep Studio and Git in sync
The repo is the shared source of truth for specs and version-controlled code; Studio is the live runtime. During Phase 0, Claude must recommend and confirm a safe source-sync workflow (for example, Rojo or an explicitly documented Studio-MCP-to-source mirroring approach) before significant code is created. Do not let two unsynchronized copies silently diverge.

## Collaboration protocol

**Claude (implementation agent)**
- Work in the local clone of this repository when using Claude Code.
- Connect to the user's open Roblox Studio session using the official Roblox Studio MCP integration.
- Read the project instructions before making changes.
- Implement, playtest, inspect Output, fix failures, and document evidence.
- Commit completed, tested increments and push them to this repository.
- Do not claim a feature is working unless it was actually tested.

**ChatGPT (architecture and review)**
- Review repository files, commits, and proposed changes through the connected GitHub integration.
- Provide architecture guidance, code review, test plans, and focused fixes.
- This repository is a shared handoff point; it does not expose Claude's private chat history or automatically notify Claude. Ask Claude to push progress/changes, then ask ChatGPT to review the repository.

**Project owner**
- Approves major scope changes, publishing, destructive changes, purchases, and release decisions.
- Keeps backups of the Roblox place before substantial Studio edits.

## First action
Read `CLAUDE_START_HERE.md`, then execute only `prompts/00_AUDIT_AND_SETUP.md`. This is a read-only audit. Wait for owner approval before Phase 1.

## Guardrails
- WORLD.EXE is an original project inspired by broad multiplayer sandbox/survival design patterns. Do not copy another game's maps, UI, text, proprietary assets, scripts, branding, or distinctive expression.
- Use only original or properly licensed assets. Prefer blockout geometry until mechanics work.
- Do not commit secrets, API keys, credentials, private player data, or unnecessary generated binaries.
- Do not publish or change monetization without explicit owner approval.
