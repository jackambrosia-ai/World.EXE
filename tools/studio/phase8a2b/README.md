# Phase 8A-2b builder: districts, order, checks and recovery

All scripts run in Roblox Studio through Studio MCP `execute_luau` (no Rojo). The text of each file is executed as-is.

## Order

| Step | Script | Mutates the place? | What it does |
|---|---|---|---|
| 0 | `0_lib.luau` | Yes: creates `ServerStorage.WORLD_EXE_Rollback8A2B` | Asserts the final 8A-2a build (ArenaVersion 3, `Correction8A2A_R2`) and that no 8A-2b content exists. Defines `_G.W8A2B`: palette, part helpers, `W.Hide`, `W.Restore`. |
| 1 | `1_yard.luau` | Yes | `Architecture.TestHangar`: 4 trussed portal frames, skylight, gantry crane, lab-pod fit-out, catwalk columns, Ring_W hangers, west silos. |
| 2 | `2_skybridge.luau` | Yes | `Architecture.ControlFacility`: 2 lattice spires (Y 110 / 92), raised glass control room, overhead trusses with stepping-block hangers, Beam cables to the relay islands, nacelles, counterweight, knee braces, deck pylons. |
| 3 | `3_archive.luau` | Yes (also hides the 12 rack-face strips: Transparency 1, original kept as `Orig8A2B_Transparency`) | `Architecture.ServerCanyons`: vault walls, ribbed roof, open oculus, hung lamps, rack-face plates and light bars, trays, cooling stacks, Ring_N / walk hangers, rack-tucked columns. |
| 4 | `4_coolant.luau` | Yes | `Architecture.PumpStation`: 2 cooling towers, pump hall (turbines, crane rail), pipe runs, pump dressing, basin grates, bridge braces. |
| 5 | `5_ring_supports.luau` | Yes | `Architecture.TransitRing`: box girders over the void, pylons, rim columns, 5 signal arches, void-edge rails (ring + reservoir rims). `Architecture.SharedSupports`: girders and pylons under the T0 slabs and sky landings. |
| 6 | `6_audit.luau` | **No** (read-only) | Final-state audit: C1–C13, budgets, streaming, AC1/AC2/AC3/AC6. Long-running: run it inside `task.spawn` and poll `_G.AUDIT8A2B` (each MCP call times out after about 60 s). |
| 7 | `7_finalize.luau` | Yes: sets `Map.Phase8A2B` | Only after `6_audit` passed in the same session (`_G.AUDIT8A2B_PASS`). ArenaVersion stays 3. |
| 8 | `8_regression_server.luau` | **No** (Play session only) | Injected as `ServerScriptService.ZZ_Regress8A2B` right after starting solo Play. It validates the arena, runs each patch kind and the five combinations, then checks the RESET/baseline and that a second match starts. |
| 9 | `9_restore.luau` | Yes | Standalone rollback to the pre-8A-2b state. |

Every new part carries `Arch8A2B = <area>` (ResearchYard, Skybridge, DataArchive, CoolantReservoir, OuterRing, SharedSupports). Decorative parts have CanCollide, CanQuery, CanTouch and CastShadow off. Collidable parts carry exactly one role, which `6_audit` checks:

- `FloorStructure`: stands within 4 studs of its floor's edge, or within 1.5 studs of an existing wall/rack; at least 2 studs from every gameplay marker; outside the spoke corridors.
- `EdgeRail`: 1.2 high, on a floor's top within 1.5 studs of an edge that drops to the void (C13 re-checks that no rail blocks a drop-down).
- `BoundaryWall`: outside every walkable footprint, against an edge that drops to the void.

The rule from 8A-2a that kept new collidables inside the core region now applies only to 8A-2a parts. 8A-2b collidables must have one of the roles above (C9).

## Recovery

- **Same Studio session:** `return _G.W8A2B.Restore("reason")`. It destroys the six district models, restores the rack strips' Transparency, clears `Map.Phase8A2B` and removes the rollback store. It was exercised several times on the working session during construction, and returned exactly to 1,233 parts / 285 collidable / 21 lights each time.
- **Any session:** run `9_restore.luau`. It needs no builder state.
- **Rollback store damaged:** close without saving and reopen the verified pre-8A-2b backup (`WorldEXE_pre-phase8a2b_2026-11-11.rbxl`).

Never run a destructive restore against the authoritative saved place to demonstrate recovery.
