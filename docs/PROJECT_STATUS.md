# WORLD.EXE — Project Status

This file is maintained by Claude after each phase. ChatGPT uses it to understand the current implementation state.

## Current state
- Overall status: PHASE 2 IMPLEMENTED (solo-tested) — PR open for review, not merged; Phase 3 not started and requires separate owner approval
- Current phase: Phase 2 — Match lifecycle and Architect selection
- Current branch: `phase-02-match`
- Current PR: Phase 2 PR (see PR conversation; do not merge without owner approval)
- Phase 1 merge: squash-merged 2026-11-10 by owner approval as `9b9cbd0` (from PR head `ddc784c`; merged tree identical to that head). The `phase-01-arena` branch still exists on GitHub and can be deleted.
- Last verified Studio place: `Place1.rbxl` (on disk: `OneDrive\Documents\Place1.rbxl`), unpublished (PlaceId 0). Phase 2 changes are in the open Studio session and **not yet saved** — owner must press Ctrl+S.
- Source synchronization method: **owner decision — no Rojo / no mirroring toolchain.** Claude edits Studio directly via Studio MCP and keeps an identical copy of every WORLD_EXE script in `src/`, verified by byte-length + hash comparison after each change (see `src/README.md`).
- Place backups (outside the repo, `OneDrive\Documents\RobloxBackups\`):
  - `WorldEXE_baseline_2026-11-09.rbxl` — pre-Phase-1 place (byte-identical copy)
  - `WorldEXE_post-phase1_2026-11-10.rbxl` — post-Phase-1 place incl. both review rounds (byte-identical copy of the saved `Place1.rbxl`)
  - `WorldEXE_pre-phase2_2026-11-10.rbxl` — verified pre-Phase-2 copy (identical content to post-Phase-1); current rollback point for Phase 2
- Studio save: Studio MCP cannot save the place — the owner must press Ctrl+S after each change set
- StreamingEnabled: unchanged (enabled), per Phase 0 review
- Multi-client testing: not available through Studio MCP; all Phase 1 and Phase 2 tests are **solo**. Outstanding multi-client tests are listed in the Phase 2 report.
- Latest technical review: Phase 1 review round 2 (ChatGPT) — addressed and merged. Phase 2 awaiting review.
- Last updated: 2026-11-10

## Phase tracker
| Phase | Scope | Status | PR/Commit | Studio test evidence |
|---|---|---|---|---|
| 0 | Audit and setup | Complete (owner decisions recorded) | — | Read-only audit; ForgeGUI read-only audit |
| 1 | Foundation and arena | **Complete — merged** (solo-tested; multi-client tests outstanding) | [PR #1](https://github.com/jackambrosia-ai/World.EXE/pull/1) → `9b9cbd0` | Solo playtests: see reports below |
| 2 | Match and Architect | Implemented — solo-tested, PR open for review | Phase 2 PR (`phase-02-match`) | Solo playtests + unit tests: see Phase 2 report |
| 3 | Patch engine | Not started | — | — |
| 4 | Four prototype patches | Not started | — | — |
| 5 | Stability/objectives/scoring | Not started | — | — |
| 6 | Initial abilities | Not started | — | — |
| 7 | Interactions and expansion | Not started | — | — |
| 8 | UI and visual polish | Not started | — | — |
| 9 | Progression and persistence | Not started | — | — |
| 10 | Hardening and release candidate | Not started | — | — |

## Phase 2 report — Match lifecycle and Architect selection (2026-11-10)

Approved by the owner 2026-11-10. Pre-phase checks: `Place1.rbxl` saved and unchanged since the post-Phase-1 backup (hash-identical); fresh backup `WorldEXE_pre-phase2_2026-11-10.rbxl` verified hash-identical; live Studio scripts hash-identical to `main` before any edit.

### Completed features
- **Match state machine** (`MatchService`, the only writer of match state): LOBBY → COUNTDOWN → INITIALIZING → ACTIVE → FINAL_PHASE → RESULTS → RESET → LOBBY, plus COUNTDOWN → LOBBY (below minimum) and INITIALIZING/ACTIVE/FINAL_PHASE → RESULTS when no participants remain. Illegal transitions assert. One server loop (0.25 s) evaluates all deadlines — there are no per-state timer callbacks that could fire into a later match. `MatchId` increments at INITIALIZING; Architect turns and results carry it.
- **Timing** (`Config.Match`): countdown 10 s, initializing 5 s, ACTIVE 420 s, FINAL_PHASE 90 s (≈8.5 min, inside both the 7–9 and 8–12 min ranges currently stated in the docs), results 12 s, reset 3 s. Low-stability trigger for the final phase is left for Phase 5.
- **Participation** (`PlayerStateService`): server-set player attribute `WORLD_EXE_Role` (Lobby / Participant / Spectator) and `WORLD_EXE_Alive`. Everyone in the lobby at the end of the countdown becomes a participant (cap 12; overflow spectates). Players joining during LOBBY/COUNTDOWN join the lobby; joining later → Spectator until the next match. Leaving removes the player from the roster and the Architect queue; an Architect who leaves ends their turn as skipped.
- **Spawning & respawning**: new enclosed **Lobby** platform (`Workspace.WORLD_EXE.Lobby`, 4 `LobbySpawn` SpawnLocations, built by `tools/studio/phase2_build_lobby.luau`, outside the arena map so Phase 1 validation/baseline are unaffected). The server sets each player's `RespawnLocation`: participants respawn on an arena pad during INITIALIZING/ACTIVE/FINAL_PHASE (different pad from last time); everyone else in the lobby. INITIALIZING reloads each participant on a distinct arena pad; RESET reloads everyone in the lobby.
- **Spawn protection**: a visible ForceField on participants for the INITIALIZING window only, removed at ACTIVE.
- **Out-of-bounds / containment**: watchdog every 0.5 s — characters below Y = −60 are eliminated (then respawn per role); non-participants found inside the arena bounds are returned to the lobby.
- **Safe reset**: RESET empties runtime folders (marker-checked, Phase 1 safety rules), compares the map to its baseline snapshot (warns on drift), resets every role to Lobby, and returns everyone to the lobby.
- **Architect** (`ArchitectService`): roster shuffled at match start, then round-robin; the chosen player moves to the back, so nobody goes twice in a row when another eligible (alive participant) player exists. First turn 15 s into ACTIVE, 12 s submission window (never time-scaled), 45 s between turns, 4 cards offered. Timeout / Architect leaving / phase change → turn skipped, nothing activates. No new turns in FINAL_PHASE (an open turn is cancelled).
- **Submission validation** (server): rate limit (burst 4, 1/s refill) → payload must be a table with exactly one key `patchId` → string, 1–32 chars of `[A-Za-z0-9 _-]` → an open turn exists → sender is the current Architect → turn belongs to the current match → window not expired → id/alias resolves through `PatchCatalog` → id is one of the offered cards. Each rejection returns a reason code via `SubmissionResult`. Accepted submissions are recorded and announced; **no patch behaviour runs** (Phase 3).
- **Patch catalog** (`Shared/PatchCatalog`): finite list of the four prototype patches with display names, warnings, effect text and aliases (case/punctuation-insensitive).
- **Replication**: `ReplicatedStorage.WORLD_EXE.MatchState` attributes (State, MatchId, StateStartedAt, StateEndsAt, ParticipantCount, MinPlayers, Reason, ArchitectUserId/Name, TurnNumber, TurnEndsAt, OfferedPatches, NextTurnAt, LastResult JSON, LastReset*) plus `MatchStateChanged` / `PatchAnnouncement` / `SubmissionResult` RemoteEvents created by `NetService`.
- **Placeholder UI** (built-in Roblox UI only, palette from the reference board): HUD status panel (phase + timer, role, players needed / participants, Architect line or next-turn timer, results summary) and amber announcement banner; Architect panel on the right side, shown only to the current Architect, with 4 cards, keyword box (resolved locally to a card, never broadcast), confirm button, timer and feedback text.
- **Studio-only test controls**: `StudioTimeScale`, `StudioMinPlayers` attributes on `ServerScriptService.WORLD_EXE` (ignored on live servers; see `src/README.md`).

### Changed / added files
- Added: `src/ReplicatedStorage/WORLD_EXE/Shared/PatchCatalog.luau`, `src/ServerScriptService/WORLD_EXE/Services/{NetService,PlayerStateService,ArchitectService,MatchService}.luau`, `src/StarterPlayer/StarterPlayerScripts/WORLD_EXE/Controllers/{UIUtil,HUDController,ArchitectController}.luau`, `tools/studio/phase2_build_lobby.luau`.
- Changed: `Config.luau` (v0.2.0-phase2; Phase 2 sections appended, Phase 1 content unchanged), `Bootstrap.server.luau`, `ClientBootstrap.client.luau`, `src/README.md`, this file.
- Studio: all 12 scripts hash-verified identical to `src/`; new `Workspace.WORLD_EXE.Lobby`. Arena map unchanged (DecayTile 64, ArenaSpawn 12, baseline matched at every reset).

### Tests (all **solo** — one Studio client; no multi-client run)
| Group | Result |
|---|---|
| Unit (Edit mode): fair rotation — 400 simulated turns, 8 players, 25 % random ineligibility | PASS — 0 consecutive repeats when an alternative existed; 49–51 turns each |
| Unit: strict round-robin A B C A B C; sole eligible player may repeat; nobody eligible → nil | PASS |
| Unit: payload validation — 15 cases (non-table, string, nil, empty, extra key, array, wrong key, number/NaN id, empty, 33 chars, code-like text, newline, valid id, valid alias text) | 15/15 PASS |
| Unit: catalog resolution — 12 inputs incl. aliases, unknown, empty; exactly 4 approved ids | 13/13 PASS |
| Live: Bootstrap `Ready`, 4 remotes created, client ready | PASS |
| Live: INITIALIZING → participant on an arena pad with ForceField; ACTIVE → ForceField removed | PASS |
| Live: Architect selected (solo → self), 4 cards offered, panel shown only during the open turn | PASS |
| Live (client → real RemoteEvent): number payload, extra `duration` key, 40-char id, code-like text, unknown id | rejected: `bad_payload`, `bad_payload`, `bad_patch_id`, `bad_patch_id`, `unknown_patch` |
| Live: alias `gravity` → accepted as ZERO_G; announcement + HUD banner shown; second submission → `no_open_turn` | PASS |
| Live: burst of 8 rapid requests | 4 served, 4 `rate_limited` |
| Live: turn timeout → skipped, next turn after the interval; open turn cancelled at FINAL_PHASE | PASS (log) |
| Live: death in ACTIVE → respawn on an arena pad, still Participant; `Alive` false→true | PASS (3.8 s) |
| Live: below Y = −60 → eliminated by watchdog (0.37 s) → respawn in arena | PASS |
| Live: non-participant teleported into the arena → returned to the lobby (0.2 s); participant left in place | PASS |
| Live: RESULTS summary JSON (outcome, duration, participants, 1 accepted / 4 skipped turns) | PASS |
| Live: RESET removed 2 planted runtime objects, baseline matched, role → Lobby, player on a lobby pad, Architect cleared | PASS |
| Live: COUNTDOWN with `StudioMinPlayers=2` → LOBBY ("countdown cancelled: not enough players"), stays in LOBBY, restarts when the minimum is met | PASS |
| Live: repeated resets — 10 matches total in one session; recorder over 4 cycles: 0 illegal transitions, baseline matched at every reset, 0 runtime objects left | PASS |
| Edit DataModel after stopping play: no Remotes/MatchState/runtime folders/test attributes saved | PASS |
| Output | Only `[WORLD_EXE]` info lines (bootstrap, client ready, transitions, turns); **no errors or warnings** |

### Not tested (requires multi-client or cannot be done solo) — outstanding
- `not_architect` and `stale_turn` rejections (need a second player); fair rotation with real players (covered only by the unit simulation).
- Player leaving during an Architect turn / during a match; abort to RESULTS when all participants leave.
- Mid-match join → Spectator; lobby overflow beyond 12 participants.
- Concurrent spawning on distinct pads; multi-client replication of state, HUD and announcements; streaming at distance (carried over from Phase 1).
- Clicking the placeholder UI with real input (the client viewport was not visible to the test harness); the submission path was exercised through the same RemoteEvent the UI uses.

### Design decisions for review
- Respawn policy: participants respawn in the arena during ACTIVE **and** FINAL_PHASE (no elimination). Phase 5 can change this.
- Readiness: every lobby player is treated as ready (no ready toggle).
- Final phase: stops new Architect turns rather than restricting the patch subset.
- An extra remote, `SubmissionResult`, carries per-request feedback to the submitting client.
- Studio defaults to a minimum of 1 player (live: 2) so solo playtests run the loop.

## Review round 2 correction — Phase 1 (2026-11-09)

### Change
`ArenaService` baseline snapshots now also record, for every BasePart: `Part.Shape` (Part and subclasses such as SpawnLocation), `Material` (it sets default friction/density), `CustomPhysicalProperties` (all five components, or `material-default`), `CollisionGroup`, `Massless`, and `AssemblyLinearVelocity` / `AssemblyAngularVelocity` (an anchored part with velocity acts as a conveyor); plus `CollisionFidelity` for mesh/union parts and `MeshId` for MeshParts (none exist in the map yet).

**Intentionally excluded** (documented in `ArenaService.luau` above `describe()`): Color, Transparency, Reflectance, CastShadow, Locked, Archivable and surface types (visual-only or no physics effect); RootPriority (only matters for unanchored assemblies — Anchored is compared); network ownership (runtime state); internal union geometry (not readable from Luau; no unions in the map).

### Changed files
- `src/ServerScriptService/WORLD_EXE/Services/ArenaService.luau` — `describe()` extended, new helpers `vectorKey()` / `physicalPropertiesKey()`, inclusion/exclusion list documented. Studio copy hash-verified identical (15481 bytes).
- `docs/PROJECT_STATUS.md` — this section.
- No other scripts, no geometry, and no arena layout changes.

### Tests (all **solo** Studio playtests via Studio MCP)
| Test | Result |
|---|---|
| **New:** `CentralCore.ReactorBase` Shape Cylinder → Block is reported as drift (`shape=Cylinder … => … shape=Block`); restored to Cylinder, baseline matches again | **PASS** |
| **New:** CollisionGroup changed (registered test group); CustomPhysicalProperties set; Material → Ice; Massless toggled; conveyor velocity on an anchored part | 5/5 detected, each matches again after restore |
| **New:** visual-only change (Color + Transparency) is not reported, by design | PASS |
| Regression: the 21 round-1 snapshot cases (move, rotate, resize, Anchored, CanCollide, CanQuery, CanTouch, attribute value/added/type, tag removed/added, rename, reparent, SpawnLocation Enabled, Attachment moved, Model PrimaryPart, removed, added, identity swap, class swap) + float-noise ignored | 22/22 PASS |
| Init valid, baseline matches before and after all restores, arena still valid | PASS |
| Bootstrap on server start | PASS — `Ready`, 0 errors, DecayTile=64 |
| Regression: 12/12 forced spawns | PASS |
| Edit DataModel after stopping play (ReactorBase still Cylinder; CoverWall_W Default group, SmoothPlastic, no custom physics, zero velocity; no test objects) | PASS |
| Output | Only the two `[WORLD_EXE] … ready v0.1.1-phase1` lines |

Totals this round: 32/32 snapshot cases, 12/12 spawns. Validation and runtime-folder code are unchanged since round 1 (35/35 and 6/6 there).

### Commits
- Round 2 correction commit: `9e96936` (ArenaService + this report).
- Final PR head for this round: `ddc784c` (docs-only commit recording `9e96936`). Squash-merged to `main` as `9b9cbd0` on 2026-11-10.

### Outstanding (not claimed)
- Concurrent-spawn test and multi-client streaming test (Studio Test → Clients and Servers, 2+ clients) — not run.

## Review round 1 corrections — Phase 1 (2026-11-09)

### Findings and resolutions
| # | Finding | Resolution |
|---|---|---|
| 1 | Type/value-check every tagged attribute | `Config.AttributeSchema` declares each attribute's kind (`id`, `zone`, `positive`, `links`) and `Config.TagClasses` the required class per tag. `Validate()` enforces: non-empty unique string ids per tag; `Zone` ∈ `Config.Zones`; `InteractionRadius` finite and > 0 (rejects 0, negatives, NaN, ±inf, strings); `Links` is a string of comma-separated ids with no empty entries, whitespace, duplicates or self-links, every id known, every link symmetric; tagged instances have the right class; tag counts match. |
| 2 | Stronger spawn validation | Each `ArenaSpawn` must be a `SpawnLocation` that is Enabled, Neutral, Anchored and CanCollide. Floor support: raycasts from the pad centre and four inset corners must hit anchored, collidable, non-`DecayTile` floor within 0.05 studs of the pad bottom (reports "no floor" or "floats N studs"). The 4×6×4 overhead-clearance check is retained. |
| 3 | Replace additive fingerprint | Removed (extended in round 2 with Shape and physics properties). `ArenaService` now captures a per-instance snapshot of `Workspace.WORLD_EXE.Map` at Init (keyed by instance identity) recording class, full path, all attributes (name + type + value), tags, and for BaseParts CFrame (position + rotation, 0.001 precision), size, Anchored, CanCollide, CanQuery, CanTouch; SpawnLocation Enabled/Neutral/Duration; Attachment CFrame; Model PrimaryPart. `CompareToBaseline()` reports added, removed, and changed instances (first 25 listed, total counted). Visual-only properties (color, material, transparency) are intentionally not compared. |
| 4 | Should SkySteps be DecayTiles? | **Decision: no.** See "SkySteps decision" below. The 5 steps were untagged, `TileId` removed, recoloured as solid floor; `DecayTile` count is now 64. |
| 5 | Runtime-folder safety | The server marks folders it creates with attribute `WORLD_EXE_RuntimeFolder=true`. `ResetRuntime()` empties only a single marked `Folder` per name; a non-Folder, an unmarked Folder, or duplicate same-named children are left untouched and reported as problems (Bootstrap → `Degraded`). |
| 6 | Status update | This section. |

### SkySteps decision
The five SkySteps are **not** `DecayTile`s. They form the only jump route between the Core and the Skybridge and sit over a lethal void, so a collapse there would mean a fall death rather than a reroute. `docs/03_PATCH_CATALOG.md` lists "Leave highlighted tiles, use alternate routes" as DECAY counterplay, which fits the Research Yard field (64 tiles, solid frame, several exits) but not a single-file shortcut. DECAY therefore targets the Research Yard only. Reversible: if Phase 4 tuning wants the shortcut to decay, re-tag the steps and raise `Config.ExpectedTagCounts.DecayTile` — that should be an explicit design decision.

### Changed files
- `src/ReplicatedStorage/WORLD_EXE/Shared/Config.luau` — version `0.1.1-phase1`; `AttributeSchema`, `TagClasses`, `SpawnFloorTolerance`, `RuntimeFolderMarker`; `DecayTile` count 64; removed `RequiredAttributes`.
- `src/ServerScriptService/WORLD_EXE/Services/ArenaService.luau` — rewritten validation, spawn checks, snapshot baseline (`CompareToBaseline`, `MatchesBaseline`), marker-based runtime folders (`ResetRuntime` now returns `(removed, problems)`).
- `tools/studio/phase1_build_arena.luau` — SkySteps built as plain floor (no `DecayTile`).
- `docs/PROJECT_STATUS.md` — this report.
- Unchanged: `Bootstrap.server.luau`, `ClientBootstrap.client.luau`.
- Studio: same script sources (hash-verified identical to `src/`); 5 SkySteps untagged/recoloured. No other geometry changed.

### Tests (all **solo** Studio playtests via Studio MCP; each negative case mutates the play-mode copy, validates, restores, and re-validates)
| Group | Result |
|---|---|
| Bootstrap on server start | PASS — `Ready`, 0 errors, counts DecayTile=64 / ArenaSpawn=12 / Stabilizer=3 / SupplyLandingPoint=5 / DroneWaypoint=15 |
| Attribute validation (20 cases): id empty / wrong type / missing / duplicate; zone unknown / wrong type / missing; radius 0 / negative / NaN / inf / string; links unknown / duplicate / self / empty entry / empty string / whitespace / asymmetric / wrong type | **20/20 PASS** — each rejected with the expected message, valid again after restore |
| Tag checks: tag on wrong class; tag count drift | 2/2 PASS |
| Spawn validation: disabled; unanchored; non-collidable; floating 2 studs; over void; half off an edge; on a DecayTile; supporting floor unanchored; supporting floor non-collidable; overhead obstruction | **10/10 PASS** |
| Arena valid and baseline matching after all restores | PASS |
| Snapshot drift (21 cases): move 0.5 studs; rotate 5°; resize; Anchored; CanCollide; CanQuery; CanTouch; attribute value / added / type (`10` vs `"10"`); tag removed / added; rename; reparent; SpawnLocation Enabled; Attachment moved; Model PrimaryPart; instance removed; instance added; identity swap with an identical clone; class swap Part→WedgePart | **21/21 detected**, each matches again after restore |
| Snapshot ignores float noise (1e-5 stud move) | PASS |
| Runtime folders: reset empties 9 objects from marked folders, second reset removes 0 | PASS |
| Runtime folders: a `Model` named `Collectibles` (with an authored part) is not destroyed and is reported | PASS |
| Runtime folders: an unmarked authored `Folder` named `RuntimeEffects` is not emptied and is reported | PASS |
| Runtime folders: duplicate `ActivePatchInstances` (marked + authored twin) → nothing destroyed, reported | PASS |
| Runtime folders: recreated and marked once conflicts are removed; map baseline unchanged | PASS |
| Regression: 12/12 forced spawns on pad, no overlap, on floor; respawn after death | PASS (respawned on `Spawn_YARD_3` after 4.0s) |
| Edit DataModel after stopping play: no runtime folders/attributes, no test objects, all restored values intact | PASS |
| Output | Only `[WORLD_EXE] Bootstrap ready v0.1.1-phase1 …` and `[WORLD_EXE] Client ready v0.1.1-phase1 …`; no errors or warnings |

Totals: 35/35 validation cases, 28/28 snapshot + runtime-folder cases, 12/12 spawns.

Issue found while testing: the floor-support ray was initially 1 stud long, so a pad floating 2 studs was reported as "no floor" rather than "floats 2.00 studs". The ray is now 5 studs; both messages were then verified.

### Commits
- Corrections commit: `1efe67b` (code + Studio-mirrored sources + this report).
- PR head after this round: the docs-only commit directly after `1efe67b` that records this line (its hash is posted in the PR conversation; a commit cannot contain its own hash).

### Outstanding (not claimed)
- **Concurrent-spawn test** (several players spawning/respawning at once, pad contention) — requires Studio Test → Clients and Servers with 2+ clients; not run.
- **Multi-client streaming test** (clients far from each zone; tagged parts streaming in/out; client tolerance) — not run.
- No lobby, spawn protection, or out-of-bounds handling beyond FallenPartsDestroyHeight (−500) — Phase 2 scope.

### Manual steps (resolved 2026-11-10)
1. ~~Press Ctrl+S in Studio~~ — done; `Place1.rbxl` saved 2026-11-09 23:56 and backed up as `WorldEXE_post-phase1_2026-11-10.rbxl`.
2. ~~ChatGPT re-review of PR #1~~ — done; squash-merged as `9b9cbd0`.

## Original Phase 1 report (2026-11-09, commit `ea9e05c`)

### Studio changes
- **Moved (not deleted):** template `Workspace.Baseplate` and `Workspace.SpawnLocation` → `ServerStorage.WORLD_EXE_TemplateBackup` (folder did not exist beforehand; properties verified identical after the move).
- **Created `Workspace.WORLD_EXE.Map`** (182 parts; generated by `tools/studio/phase1_build_arena.luau`, Studio owns the geometry):
  - `CentralCore` — 80×80 deck, reactor (base, neon column, glass shell, cap), two cover walls.
  - `ResearchYard` — solid frame around an 8×8 field of `DecayTile`s (9.8-stud tiles), four barriers.
  - `Skybridge` — elevated deck (top Y=24), north span to the Lookout, five `SkySteps` jump platforms (not DecayTiles since review round 1).
  - `Routes` — Core↔Yard bridge, Core→Skybridge ramp, Lookout, Lookout→Yard ramp, Yard north annex. Every zone is reachable by at least two routes.
  - `Stabilizers` — 3 placeholder Models (`STAB_CORE`, `STAB_YARD`, `STAB_SKY`), Atomic streaming, `InteractionPoint` attachment, `InteractionRadius=10`.
  - `SpawnLocations` — 12 real `SpawnLocation`s (4 per zone; Enabled, Neutral, Duration 0), on solid non-decay floor.
  - `SupplyLandingPoints` — 5 invisible, non-collidable markers.
  - `DroneWaypoints` — 15 invisible markers forming a symmetric link graph (`Links` attribute).
- **Scripts** (identical copies in `src/`):
  - `ReplicatedStorage.WORLD_EXE.Shared.Config` (ModuleScript) — tags, counts, attribute schema, runtime folder names/marker, palette.
  - `ServerScriptService.WORLD_EXE.Services.ArenaService` (ModuleScript) — arena validation, runtime-folder reset, baseline snapshot.
  - `ServerScriptService.WORLD_EXE.Bootstrap` (Script) — initializes ArenaService, sets `BootstrapStatus` / `ArenaValidationErrors` attributes on `Workspace.WORLD_EXE`.
  - `StarterPlayer.StarterPlayerScripts.WORLD_EXE.ClientBootstrap` (LocalScript) — minimal client controller; streaming-tolerant.
- Runtime folders (`ActivePatchInstances`, `Collectibles`, `RuntimeEffects`) are created by the server at runtime only; they are not saved in the place.
- Not changed: Lighting, StreamingEnabled, any third-party plugin.

### Tag/attribute baseline (current)
| Tag | Count | Class | Attributes |
|---|---|---|---|
| DecayTile | 64 (Research Yard only) | BasePart | TileId (id), Zone (zone) |
| ArenaSpawn | 12 | SpawnLocation | SpawnId (id), Zone (zone) |
| Stabilizer | 3 | Model | StabilizerId (id), Zone (zone), InteractionRadius (positive) |
| SupplyLandingPoint | 5 | BasePart | PointId (id), Zone (zone) |
| DroneWaypoint | 15 | BasePart | WaypointId (id), Zone (zone), Links (links) |

### Original tests (all **solo**)
| Test | Result |
|---|---|
| Static: tag counts, anchoring, collidable floors, non-collidable decor/markers, spawns on solid non-decay floor, supply points over floor | PASS (0 issues) |
| Each of the 12 spawns, forced via `RespawnLocation` + `LoadCharacter` | PASS 12/12 |
| Natural respawn after death (Health=0) ×2; respawn after falling into the void | PASS |
| 30 automatic (random) spawns | PASS — 30/30 on a pad; 11/12 pads drawn at random (YARD_2 passed its forced test) |
| Walk Core → Skybridge, Skybridge → Yard annex, Yard annex → Core | PASS |
| Jump route Core ↔ Skybridge via 5 SkySteps (real jumps) | PASS 6/6 up, 6/6 down (after reducing gaps from 8 to 4 studs) |
| Client: Config/root found with streaming on, status replicated | PASS |
| Edit DataModel unchanged after stopping play | PASS |

Test-harness note: setting `Humanoid.Jump` from an injected client script is overwritten by the default control script; jump tests use `Humanoid:ChangeState(Jumping)`.

### Known limitations / risks
- Solo tests only (see Outstanding above).
- Arena geometry lives only in the place file; `tools/studio/phase1_build_arena.luau` reproduces it on an empty place.
- The ForgeGUIConnect Studio plugin error seen in Phase 0 has not reappeared; still treated as an external plugin issue.

## ForgeGUI
- Workflow: [docs/09_FORGEGUI_WORKFLOW.md](./09_FORGEGUI_WORKFLOW.md).
- Read-only audit done 2026-11-09: 41 tools; publishing connection `@amfam1` (Personal, Image/Model/Audio); no credit-balance or cost-estimate tool; Studio insertion only via Studio MCP.
- Owner decisions: publish destination `@amfam1`; no generation/publishing until a specific test batch and budget are approved; check credit balance on the website before the first generation; keep assets private (no Creator Store); do not upload the reference board without separate approval; create `docs/ASSET_MANIFEST.md` before the first published asset; placeholder shapes and built-in UI until artwork is approved.
