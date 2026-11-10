# WORLD.EXE — Project Status

This file is maintained by Claude after each phase. ChatGPT uses it to understand the current implementation state.

## Current state
- Overall status: PHASE 1 — review round 1 corrections applied (solo-tested); awaiting re-review; Phase 2 not started
- Current phase: Phase 1 — Foundation and Sandbox arena blockout
- Current branch: `phase-01-arena`
- Current PR: [jackambrosia-ai/World.EXE#1](https://github.com/jackambrosia-ai/World.EXE/pull/1) (do not merge without owner approval)
- PR head: docs-only commit after `1efe67b` (exact hash in the PR conversation)
- Last verified Studio place: `Place1.rbxl` (on disk: `OneDrive\Documents\Place1.rbxl`), unpublished (PlaceId 0)
- Source synchronization method: **owner decision — no Rojo / no mirroring toolchain.** Claude edits Studio directly via Studio MCP and keeps an identical copy of every WORLD_EXE script in `src/`, verified by byte-length + hash comparison after each change (see `src/README.md`).
- Baseline place backup: `OneDrive\Documents\RobloxBackups\WorldEXE_baseline_2026-11-09.rbxl` (byte-identical copy of the pre-Phase-1 place; rollback point)
- Studio save: Studio MCP cannot save the place — the owner must press Ctrl+S after each change set
- StreamingEnabled: unchanged (enabled), per Phase 0 review
- Multi-client testing: not available through Studio MCP; all Phase 1 tests are **solo**
- Latest technical review: Phase 1 review round 1 (ChatGPT, relayed by the owner 2026-11-09) — 6 findings, all addressed below
- Last updated: 2026-11-09

## Phase tracker
| Phase | Scope | Status | PR/Commit | Studio test evidence |
|---|---|---|---|---|
| 0 | Audit and setup | Complete (owner decisions recorded) | — | Read-only audit; ForgeGUI read-only audit |
| 1 | Foundation and arena | Review round 1 corrections applied — solo-tested, awaiting re-review | [PR #1](https://github.com/jackambrosia-ai/World.EXE/pull/1) | Solo playtests: see reports below |
| 2 | Match and Architect | Not started — needs separate owner approval | — | — |
| 3 | Patch engine | Not started | — | — |
| 4 | Four prototype patches | Not started | — | — |
| 5 | Stability/objectives/scoring | Not started | — | — |
| 6 | Initial abilities | Not started | — | — |
| 7 | Interactions and expansion | Not started | — | — |
| 8 | UI and visual polish | Not started | — | — |
| 9 | Progression and persistence | Not started | — | — |
| 10 | Hardening and release candidate | Not started | — | — |

## Review round 1 corrections — Phase 1 (2026-11-09)

### Findings and resolutions
| # | Finding | Resolution |
|---|---|---|
| 1 | Type/value-check every tagged attribute | `Config.AttributeSchema` declares each attribute's kind (`id`, `zone`, `positive`, `links`) and `Config.TagClasses` the required class per tag. `Validate()` enforces: non-empty unique string ids per tag; `Zone` ∈ `Config.Zones`; `InteractionRadius` finite and > 0 (rejects 0, negatives, NaN, ±inf, strings); `Links` is a string of comma-separated ids with no empty entries, whitespace, duplicates or self-links, every id known, every link symmetric; tagged instances have the right class; tag counts match. |
| 2 | Stronger spawn validation | Each `ArenaSpawn` must be a `SpawnLocation` that is Enabled, Neutral, Anchored and CanCollide. Floor support: raycasts from the pad centre and four inset corners must hit anchored, collidable, non-`DecayTile` floor within 0.05 studs of the pad bottom (reports "no floor" or "floats N studs"). The 4×6×4 overhead-clearance check is retained. |
| 3 | Replace additive fingerprint | Removed. `ArenaService` now captures a per-instance snapshot of `Workspace.WORLD_EXE.Map` at Init (keyed by instance identity) recording class, full path, all attributes (name + type + value), tags, and for BaseParts CFrame (position + rotation, 0.001 precision), size, Anchored, CanCollide, CanQuery, CanTouch; SpawnLocation Enabled/Neutral/Duration; Attachment CFrame; Model PrimaryPart. `CompareToBaseline()` reports added, removed, and changed instances (first 25 listed, total counted). Visual-only properties (color, material, transparency) are intentionally not compared. |
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

### Manual steps still needed
1. Press **Ctrl+S** in Studio to save these changes to `Place1.rbxl`.
2. Ask ChatGPT to re-review PR #1.

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
