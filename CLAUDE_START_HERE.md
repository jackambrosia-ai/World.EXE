# Claude: Start Here — WORLD.EXE

You are the implementation agent for WORLD.EXE. The user has already connected you to Roblox Studio. This GitHub repository is the shared source of truth with ChatGPT, which acts as game architect and technical reviewer.

Repository: https://github.com/jackambrosia-ai/World.EXE

## First: do a read-only audit

Do not modify the Roblox place or repository yet.

1. Confirm you can read this repository and identify the current branch and working-tree state.
2. Read the complete project specifications in `docs/` if present. If the user separately supplied the WORLD.EXE Claude Development Package, reconcile it with this repository and copy its Markdown specifications into `docs/` so this repository becomes the durable shared source of truth.
3. Confirm the Roblox Studio MCP connection. Use the Studio tool to list open Studio instances and identify the intended place.
4. Inspect the current Studio DataModel/Explorer hierarchy, scripts, remotes, assets, and Output errors.
5. Do not delete or overwrite existing content. Do not publish, purchase assets, or make other irreversible changes.
6. Report:
   - Repository and branch detected.
   - Studio place and connection status.
   - Existing project structure and reusable systems.
   - Conflicts or risks.
   - Missing project specifications.
   - A proposed Phase 0 implementation plan.
   - Any action that requires the owner's approval.

## Project objective

Build an original Roblox multiplayer reality-manipulation sandbox.

Players take turns submitting approved patches that change the world. Patches can modify physics, environment, spawn entities, or create beneficial opportunities. Several patches may coexist, within explicit limits and compatibility rules.

The game combines:
- Creative player-driven patch submissions.
- Survival and meaningful counterplay.
- Shared stabilizer objectives.
- Individual scoring and placement.
- A simulation stability meter and final instability phase.
- Patch discovery, mastery, progression, and cosmetics.

## Initial design targets

- One launch mode: Stability Run.
- One launch arena: The Sandbox (Central Core, Research Yard, Skybridge).
- 8–12 players initially.
- Approximately 8–12 minutes per match; tune through tests.
- No more than three active major patches initially.
- First four prototype patches: ZERO_G, DECAY, DRONE_SWARM, SUPPLY_DROP.
- First three abilities: PHASE_DASH, ANCHOR, SCANNER.
- Data-driven definitions and server-authoritative gameplay.

## Implementation constraints

- Server validates Architect turns, patch IDs, cooldowns, compatibility, damage, scoring, rewards, and progression.
- Clients may request actions and render effects, but may not decide authoritative outcomes.
- Every patch needs a unique active ID, owner/user attribution where applicable, start time, duration, lifecycle state, and cleanup handler.
- Global modifiers must be composed from active sources and restored safely; do not let one patch blindly overwrite another patch's settings.
- Patch combinations must be explicitly curated and tested at launch.
- Use bounded entity counts, deterministic cleanup, and rate limits.
- Use Roblox TextService filtering for any player-entered text that is displayed or persisted. Prefer approved patch IDs/aliases rather than executing arbitrary text.
- Handle player departure, round cancellation, errors, and server shutdown without leaking effects or leaving shared settings altered.
- Preserve existing place content. Back up before substantial Studio changes.

## Git workflow

1. Work from this repository's local clone when using Claude Code.
2. Create a focused branch for implementation phases (for example, `phase-0-audit`, `phase-1-foundation`).
3. Make small commits with descriptive messages.
4. Push completed work so ChatGPT can review it.
5. Summarize files changed, tests run, results, known issues, and next steps in each phase report.
6. Do not merge or publish release changes without the owner's approval.

## Required first response

Complete only the read-only audit and report the findings. Do not begin building until the owner approves the Phase 0 plan.
