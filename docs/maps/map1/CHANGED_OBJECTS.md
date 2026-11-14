# Map 1 working copy: existing objects changed (2026-11-13, Agent A)

Studio file: `WorldEXE_Map1_StableSim_WORKING_2026-11-13.rbxl` (working copy only; `Place1.rbxl` untouched).
Expansion version: `map1-expansion v7 2026-11-13` (`Workspace.WORLD_EXE.Map.Map1Expansion`, attribute `Map1ExpansionVersion`).
Nothing existing was deleted. Every changed object was **moved** (identity and properties kept) to `ServerStorage.Map1_Isolated`, with attribute `Map1OrigParent` (or `Map1IsolatedFrom`) naming its original parent. Undo scripts restore them.

## 1. ENV_SPRINT2 exterior isolated (`tools/studio/map1/0_isolate_sprint_exterior.luau`, restore mode `restore`)
| Model | Parts | From |
|---|---|---|
| Exterior_WestRift | 35 | Workspace.WORLD_EXE.Map.EnvSprint2 |
| Exterior_BrokenSlabs | 20 | same |
| Exterior_UnrenderedVolume | 21 | same |

The Traversal_* models (Y24 high line and the jump climb) are kept in place.

## 2. Hall openings (`1_build_expansion.luau` CUTS; undo: `9_remove_expansion.luau`)
The original part moves to `ServerStorage.Map1_Isolated.CutOriginals`. Axis-aligned remainder pieces (clones; `Map1Role = CutPiece`, `Map1CutFrom = <original path>`) are placed under `Map1Expansion.HallOpenings`.

| Original (under Workspace.WORLD_EXE.Map) | Kind | Original position / size | Cut box | Pieces |
|---|---|---|---|---|
| Megastructure.Silhouette.Plinth_N_6 | decor | (33.2,-15,-327.5) / 66x150x12 | RN_Ground_Plinth X53..77 Y-6..30 Z-337..-316 | 3 |
| Megastructure.Silhouette.Plinth_N_7 | decor | (99.6,-15,-326) / 66x150x12 | RN_Ground_Plinth | 3 |
| Megastructure.Detail.PlinthBand_N | decor | (0,0,-319.6) / 664x3x1 | RN_Ground_Plinth | 2 |
| DataArchive.ArchiveFloor_Trim2 | decor (neon edge) | (0,-0.35,-260.15) / 260x0.5x0.3 | RN_Ground_VaultWallDoor X55..75 Y-4..28 Z-261.6..-260 | 2 |
| Architecture.ServerCanyons.Structure.VaultWalls.VaultWall_N | **collidable** | (0,33,-260.75) / 263x74x1.5 | RN_Ground_VaultWallDoor + RN_Bridge_VaultWall X-75..-55 Y22..52 | 6 |
| Megastructure.Silhouette.Plinth_N_4 | decor | (-99.6,-15,-327.5) / 66x150x12 | RN_Bridge_Plinth X-77..-53 Y20..52 Z-337..-316 | 3 |
| Megastructure.Silhouette.Plinth_N_5 | decor | (-33.2,-15,-326) / 66x150x12 | RN_Bridge_Plinth | 3 |
| Megastructure.Silhouette.Plinth_W_6 | decor | (-327.5,-15,33.2) / 66x150x12 (rot Y-90) | RW_Plinth X-337..-315 Y-6..52 Z21..43 | 4 |
| Megastructure.Detail.PlinthBand_W | decor | (-319.6,0,0) / 664x3x1 (rot Y-90) | RW_Plinth | 2 |
| Megastructure.Silhouette.Plinth_E_5 | decor | (326,-15,-33.2) / 66x150x12 (rot Y-90) | RE_Ground_Plinth X315..337 Y-6..30 Z-32..-8 | 4 |
| Megastructure.Detail.PlinthBand_E | decor | (319.6,0,0) / 664x3x1 (rot Y-90) | RE_Ground_Plinth | 2 |
| Megastructure.Silhouette.Plinth_E_7 | decor | (326,-15,99.6) / 66x150x12 (rot Y-90) | RE_Bridge_Plinth X315..337 Y20..52 Z81..99 | 4 |
| Architecture.TransitRing.Structure.Rails.EdgeRail (the X 236.8 outer rail, 445 long) | **collidable** (1.2-high rail) | (236.8,24.6,0) / 0.4x1.2x445 | RE_Bridge_RingEdgeRail X236.5..237.2 Y24.02..25.5 Z83..97 | 2 |

Rotated originals (Y -90) are replaced by pieces with identity rotation and world-aligned sizes, so the material grain direction differs. This has no visible effect on Concrete or Metal at this scale.

## 3. Decor moved out of a sector footprint (`ISOLATE` list; moved to `ServerStorage.Map1_Isolated.ExpansionMoved`)
| Original | Position / size | Why |
|---|---|---|
| Megastructure.Detail.FarTower_8 | (-488,30,113.4) / 44x240x44 | stood inside the Testing Pit rim |
| Megastructure.Detail.FarTowerTop_8 | (-488,165,113.4) / 28x30x28 | same |

## 4. Config bounds (Studio working copy only, `2_set_bounds.luau`, restore mode `restore`)
`ReplicatedStorage.WORLD_EXE.Shared.Config` source, two lines (the only script-source change: K6 hash check shows 44/44 scripts, 1 changed):
```
before: Config.ArenaBoundsMin = Vector3.new(-275, -40, -275)
        Config.ArenaBoundsMax = Vector3.new(275, 160, 275)
after:  Config.ArenaBoundsMin = Vector3.new(-845, -40, -715) -- MAP1 WORKING COPY (was -275, -40, -275)
        Config.ArenaBoundsMax = Vector3.new(705, 160, 275) -- MAP1 WORKING COPY (was 275, 160, 275)
```
`OutOfBoundsY = -60` is unchanged. Max Z stays 275 and max Y stays 160, so the lobby (Z 396..444, Y about 160..165) stays outside the bounds. The check verified that the lobby spawns are outside.

**Proposed `src/` change (NOT made in git):** in `src/ReplicatedStorage/WORLD_EXE/Shared/Config.luau:218-219`, set the same two values, but only if Map 1 is adopted. For a multi-map future, Agent C's map contract should move the bounds into per-map data rather than a global constant (they are read in AbilityService:212 for Dash landing and PlayerStateService:96 for the out-of-arena containment of non-participants).

## Undo order
`9_remove_expansion.luau` (removes Map1Expansion and restores sections 2 and 3), then `2_set_bounds.luau` with `_G.MAP1_BOUNDS_MODE="restore"`, then `0_isolate_sprint_exterior.luau` with `_G.MAP1_ISOLATE_MODE="restore"`. This full undo was exercised in this session: the old phase8a2b audit returned PASS on the restored state.
