# ENV_SLICE1 builder: first production map slice

Owner-approved on 2026-11-13. Review evidence: `WORLD-EXE-Dev-HQ` PR #11 (prototype) and the follow-up production evidence PR. Scripts run in Roblox Studio through Studio MCP `execute_luau` (no Rojo). The text of each file is executed as-is.

## What the slice is

Everything lives in one new folder, `Workspace.WORLD_EXE.Map.EnvSlice1`, so it stays distinguishable from the original arena construction.

| Model | Category (`EnvSlice1` attribute) | Parts | Collidable | Contents |
|---|---|---|---|---|
| `TraversalLink_SkyLandingS_BridgeE` | `TraversalLinks` | 17 | 9 | 5 walk slabs joining `SkyLanding_S` to `Bridge_E` (top Y 24), 4 safety rails (4 studs high), 5 cyan guide trims, landing beacon, 2 support pylons |
| `ExteriorScenery_E10Spire` | `ExteriorScenery` | 24 | 0 | Fractured spire behind east hall window E10 (placement prototype, not final art) |

No scripts, tags, lights, MeshParts or unions. No existing instance is modified.

Collidable parts carry exactly one role, checked by the audit:

- `WalkSurface`: a level, unrotated slab inside `Config.ArenaBounds`, joined flush to another walkable floor.
- `EdgeRail`: stands on a `WalkSurface`, on an edge that drops to the void along the rail's whole length.

Decorative parts have CanCollide, CanQuery, CanTouch and CastShadow off.

## Budgets

The slice has its own categories. It does not draw on the district caps (Skybridge stays 95/100, Megastructure 394/420).

| Category | Cap (parts / collidable / lights) | Used |
|---|---|---|
| `TraversalLinks` | 24 / 12 / 0 | 17 / 9 / 0 |
| `ExteriorScenery` | 40 / 0 / 0 | 24 / 0 / 0 |

These are slice-level allocations, not permission to build up to them. The 2,252-part design total and the global ceilings are unchanged; the map goes from 1,861 to 1,902 parts and from 370 to 379 collidable.

## Order

| Step | Script | Mutates the place? | What it does |
|---|---|---|---|
| 1 | `1_build.luau` | Yes: creates `Map.EnvSlice1`, sets `Map.EnvSlice1` attribute | Asserts the arena state and seven anchor parts, refuses to run if slice content exists in any other form, builds off-tree and parents once. Running it again changes nothing. |
| 2 | `../phase8a2b/6_audit.luau` | **No** (read-only) | Full map audit, now ENV_SLICE1-aware. Long-running: run inside `task.spawn` and poll `_G`. |
| 3 | Focused Play tests | **No** (Play session only) | Solo Play; the stock Humanoid is driven from server-side `execute_luau` calls (`PivotTo`, `MoveTo`, `Jump`) under 20 s each. Nothing is inserted into the place. |
| 9 | `9_rollback.luau` | Yes | Removes `Map.EnvSlice1` and the attribute. Needs no builder state. |

## Two corrections to the reviewed prototype

The extended audit found two problems in the prototype geometry before anything was built in the production place. The owner approved both corrections on 2026-11-13.

1. **`EdgeRail_North` is 18 studs (X 122–140), not 28.** East of X 140 the rail stood one stud from `SkyBase` and blocked a drop-down (C13, 5 samples). The unrailed 10 studs drop onto `SkyBase`.
2. **`SupportPylon_A` and `SupportPylon_B` were added.** Three walk slabs had no support within 30 studs (AC6 span support: 32, 40 and 37). The pylons are non-collidable, like the existing `SharedSupports` pylons.

## Audit changes (`phase8a2b/6_audit.luau`)

The audit used to see only parts carrying `Arch8A2A` or `Arch8A2B`. It now also takes every part carrying `EnvSlice1`. With no slice parts in the map it behaves exactly as before.

| Check | Change |
|---|---|
| Discovery | `EnvSlice1` parts join the new-part lists, so C1–C5, C7, C8, C11 and C12 apply to them unchanged. A slice-marked instance outside `Map`, or one that is not a part, is an error. |
| C5h (new) | No slice collidable within 8 studs above a slip, decay, corruption, fragment or magnetic marker. |
| C6 | Slice collidables entering the headroom of an existing floor fail like any other new part. |
| C6s (new) | Nothing collidable, old or new, may enter the 6-stud envelope above a slice `WalkSurface`, except an `EdgeRail` at its edge. |
| C6b | Now also applied to slice collidables against existing collidables, and to slice collidables against each other. |
| C9 | Slice collidables must be in `TraversalLinks` with exactly one of `WalkSurface` / `EdgeRail`. Walk surfaces must be level slabs inside the arena bounds, joined flush; each traversal model must join at least two existing floors. Slice rails must stand on a slice walk surface. |
| C10 | `TraversalLinks` and `ExteriorScenery` caps added. Unknown categories and parts attributed to both a district and the slice are errors. District caps and totals unchanged. |
| C13 | Applied to slice rails. Slice walk surfaces count as floors, for old and new rails alike. |
| AC6 span support | Slice walk surfaces are included. |

No check exempts ENV_SLICE1.

## Recovery

- **Any session:** run `9_rollback.luau`. It was exercised on a disposable copy: 41 parts removed, map back to 1,861 parts / 370 collidable / 51 lights; a second run is a no-op; `1_build.luau` then rebuilds the same slice.
- **Slice content found outside `Map.EnvSlice1`:** both scripts stop and name it. Investigate by hand; nothing is deleted automatically.
- **Anything else:** close without saving and reopen the verified pre-construction backup.

Never run a destructive restore against the authoritative saved place to demonstrate recovery.

## Production record (2026-11-13)

| Item | Value |
|---|---|
| `Place1.rbxl` before | SHA-256 `E4BB6CEC295EF833243B3C53FD2E1B977CA2FDC973FA53323A8766CDDDBF8C29`, 231,250 bytes, 1,861 parts / 370 collidable / 51 lights |
| `Place1.rbxl` after (owner-saved) | SHA-256 `AE7C8D0E9A28D68367C88C748F2A11AC564E7BC44CF3BB70F35781276EEC55E3`, 232,836 bytes, 1,902 parts / 379 collidable / 51 lights |
| Pre-construction backup | `Place1_pre-production-envslice1_2026-11-13.rbxl`, byte-identical to the "before" file |
| Script sources | 44 of 44 identical before and after, and identical to `main` at `f716fe4` |
| Audit before construction | overall PASS, 0 errors, 35 slabs |
| Audit after construction | overall PASS, 0 errors, 40 slabs; TraversalLinks 17/9/0, ExteriorScenery 24/0/0; district counts unchanged |
| Unrelated content | A digest over every other instance (2,525) and the lighting settings was identical before and after |

One audit line changed outside the slice: `Spawn_RES_2`, one of the five owner-waived AC2 viewpoints, went from 23% to 13% of the reactor benchmark visible, because `ReservoirLanding` now crosses its sight line. It was already failing and waived; no non-waived viewpoint changed.
