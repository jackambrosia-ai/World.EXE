# Phase 8A-2a builder: order, failure handling and recovery

All scripts run in Roblox Studio **Edit** mode through Studio MCP `execute_luau`. Each script's text is executed as-is.

## Order

| Step | Script | Mutates the place? | Notes |
|---|---|---|---|
| 0 | `0_lib.luau` | Yes: creates `ServerStorage.WORLD_EXE_Rollback8A2A` (Lighting snapshot, `Lobby.Wall_N` snapshot) | Asserts ArenaVersion 2 and that no 8A-2a content exists. Defines `_G.W8A2A` (helpers, `W.Restore`). |
| 1 | `1_hall.luau` | No: builds into an **unparented** `Megastructure` folder | |
| 2 | `2_reactor.luau` | **Yes**: moves the six 8A-1 reactor parts into the rollback store. Otherwise builds unparented | |
| 3 | `3_core.luau` | No: builds unparented | |
| 4 | `4_lobby_lighting.luau` | **Yes**: changes `Wall_N` visuals and the Lighting preset, then parents `Architecture` and `Megastructure` into the Map | |
| 5 | `5_validate.luau` | On a **gameplay/budget** failure (C1..C11) it calls `W.Restore()`. On success it sets ArenaVersion 3 | Strict AC2 is reported only, never restored. |
| 7 | `7_correction.luau` | Yes: review corrections (reactor massing, materials, roof glass, fill, bloom). Originals are kept as `Orig8A2A_*` attributes; removed parts go to `…Rollback8A2A.CorrectionRemoved` | Runs on the saved build. Needs no builder state. |
| 8 | `8_hollow_rings.luau` | Yes: replaces the solid coil/gallery discs from step 7 with hollow segmented rings (parts only, decorative, non-collidable). Removed discs go to `…Rollback8A2A.CorrectionRemoved`; sets `Map.Correction8A2A_R2` | Runs after step 7. Asserts it has not run before. |
| 6 | `6_audit.luau` | **No** (read-only) | Final-state audit of the actual place. Never restores. C1–C11 match `5_validate` exactly (including C6 rail-edge, spoke-corridor and 2-stud marker-clearance checks). Reports the strict AC2 benchmark unchanged, plus an informational SELF self-occlusion score (all reactor parts count as occluders except the EnergyCore and parts with Transparency ≥ 0.4), and splits AC1 into geometry intersection vs sky seen only through translucent surfaces. |

C11 (both scripts): any Neon part whose second-largest dimension exceeds 4 studs fails, except `EnergyCore`, `HubEmitter` and `CrownEmitter`.
| 9 | `9_restore.luau` | Yes | Standalone rollback to pre-8A-2a. See below. |

## Two different recovery situations

1. **Automatic rollback (validation failure).** Only `5_validate` restores automatically, and only when a gameplay-safety or budget check fails. It uses `W.Restore()`: it destroys the new content, moves the original reactor parts back, and restores Lighting and `Wall_N`. This was exercised once during the original build. The first attempt failed C8/C11, and the place returned exactly to ArenaVersion 2 with 522 parts.

2. **Manual recovery (a step errors part-way, or the session is lost).** Steps 1–4 do **not** restore on their own if they throw. The place may then be partially changed: reactor parts moved by step 2, Lighting and `Wall_N` changed by step 4, content parented by step 4. Recovery:
   - If `_G.W8A2A` still exists in the same Studio session, run `return _G.W8A2A.Restore("manual")`.
   - Otherwise, run `9_restore.luau`. It works only from `ServerStorage.WORLD_EXE_Rollback8A2A` and needs no builder state.
   - If the rollback store itself is missing or damaged, **close the place without saving** and reopen the last verified `.rbxl` backup.

   `9_restore` does **not** undo `7_correction`'s colour and material tweaks on parts that it then destroys anyway. It does restore Lighting from the pre-8A-2a snapshot, which covers the correction's fill, exposure and bloom changes too.

## Authoritative rollback

The external `.rbxl` backups in `OneDrive\Documents\RobloxBackups\` are authoritative. Never run a destructive restore against the saved place just to demonstrate recovery. Demonstrations use a throwaway copy, or the automatic path during a fresh build.
