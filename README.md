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

**Launch mode:** Stability Run  
**Initial arena:** The Sandbox, with Central Core, Research Yard, and Skybridge  
**Target server size:** 8–12 players initially  
**Target round length:** approximately 8–12 minutes (tune through playtesting)  
**Initial active major patch cap:** 3 (tune after performance testing)

## First prototype patches

1. `ZERO_G` — global low-gravity modifier.
2. `DECAY` — telegraphed temporary platform/environment decay.
3. `DRONE_SWARM` — server-controlled hostile drone entities.
4. `SUPPLY_DROP` — contested beneficial collectible drop.

Build the playable core before shops, monetization, elaborate cosmetics, or large content expansions.

## Source of truth

- This repository is the shared source of truth for written specifications and version-controlled code.
- Roblox Studio is the live runtime/project environment.
- Keep source changes reviewable and commit them in small, descriptive increments.
- Keep the documentation current when architecture or design decisions change.
- Do not commit secrets, API keys, credentials, private player data, or unnecessary generated binaries.
- Prefer source files and reproducible project configuration over opaque place-file-only changes.

## Collaboration protocol

**Claude (implementation agent)**
- Work in the local clone of this repository.
- Connect to the user's open Roblox Studio session using the official Roblox Studio MCP integration.
- Read the project instructions before making changes.
- Implement, playtest, inspect Output, fix failures, and document evidence.
- Commit completed, tested increments and push them to this repository.
- Do not claim a feature is working unless it was actually tested.

**ChatGPT (architecture and review)**
- Review repository files, commits, and proposed changes.
- Provide architecture guidance, code review, test plans, and focused fixes.
- Treat this repository as the shared handoff point; it does not expose Claude's private chat history or automatically notify Claude.

**Project owner**
- Approves major scope changes, publishing, destructive changes, purchases, and release decisions.
- Keeps backups of the Roblox place before substantial Studio edits.

## Start here

Read [CLAUDE_START_HERE.md](./CLAUDE_START_HERE.md) and follow its read-only audit before implementing. Add the complete Claude handoff package (master instructions, game design, technical architecture, patch catalog, UI/art direction, roadmap, and test/release requirements) under `docs/` if those files have not yet been committed.
