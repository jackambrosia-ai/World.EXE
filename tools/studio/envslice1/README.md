# ENV_SLICE1 builder: first production map slice

Owner-approved on 2026-11-13. Review evidence: `WORLD-EXE-Dev-HQ` PR #11 (prototype) and PR #12 (production construction and review corrections). Current specification: **v2 2026-11-13**. Scripts run in Roblox Studio through Studio MCP `execute_luau` (no Rojo). The text of each file is executed as-is.

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
| 1 | `1_build.luau` | Yes: creates `Map.EnvSlice1`, sets `Map.EnvSlice1` attribute | Asserts the arena state and seven anchor parts. If the slice exists and matches the specification exactly (geometry; Color, Material, Anchored, CanCollide, CanQuery, CanTouch, CastShadow, Transparency, Reflectance, Massless, Locked, Shape, surfaces; exact attribute sets; no tags, children or extra instances; Map attribute = version) it changes nothing. Any other slice content, including an older version, stops it with the first difference named. Builds off-tree, self-checks, parents once. |
| 2 | `../phase8a2b/6_audit.luau` | **No** (read-only) | Full map audit, now ENV_SLICE1-aware. Long-running: run inside `task.spawn` and poll `_G`. |
| 3 | Focused Play tests | **No** (Play session only) | Solo Play; the stock Humanoid is driven from server-side `execute_luau` calls (`PivotTo`, `MoveTo`, `Jump`) under 20 s each. Nothing is inserted into the place. |
| 9 | `9_rollback.luau` | Yes | Removes `Map.EnvSlice1` and the attribute. Needs no builder state. Deletes only recognized slice content: it refuses, deleting nothing, if the folder holds anything other than the two slice models and their known, uniquely named Parts, if a part has children, tags, unexpected attributes or a missing/wrong `EnvSlice1` category, or if slice-marked content exists elsewhere. |

Upgrading from an older version: `9_rollback.luau` then `1_build.luau`.

## Changes against the reviewed prototype

### v1: two audit corrections (before construction)

The extended audit found two problems in the prototype geometry before anything was built in the production place. The owner approved both corrections on 2026-11-13.

1. **`EdgeRail_North` is 18 studs (X 122–140), not 28.** East of X 140 the rail stood one stud from `SkyBase` and blocked a drop-down (C13, 5 samples). The unrailed 10 studs drop onto `SkyBase`.
2. **`SupportPylon_A` and `SupportPylon_B` were added.** Three walk slabs had no support within 30 studs (AC6 span support: 32, 40 and 37). The pylons are non-collidable, like the existing `SharedSupports` pylons.

### v2: Spawn_RES_2 sightline (review correction, 2026-11-13)

The v1 slice reduced the reactor benchmark seen from `Spawn_RES_2` (an owner-waived AC2 viewpoint) from 9 to 5 of 40 samples (23% to 13%). The four lost samples are lines from the spawn eye (110, 6, 250) toward the reactor that cross the slab layer (Y 22–24) where `CutThrough_Walk_4` meets `ReservoirLanding`:

| Sample | Blocked by (v1) | Crossing at Y 22–24 | v2 |
|---|---|---|---|
| col5 (0, 69.5, 0) | `CutThrough_Walk_4`, 0.28 stud corner clip | X 78.8–82.3, Z 179–187 | **clear** (Walk_4 west edge 82 → 82.5) |
| coil95_1 (0, 95, 20) | `ReservoirLanding` north-east corner | X 87.8–90.2, Z 203.5–208.6 | **clear** (landing trimmed to Z ≤ 202, X ≤ 90.5) |
| col6 (0, 79, 0) | `ReservoirLanding` | X 82.9–85.9, Z 188.4–195.2 | still blocked |
| col7 (0, 88.5, 0) | `ReservoirLanding` | X 86.0–88.7, Z 195.5–201.5 | still blocked |

v2 geometry: `CutThrough_Walk_4` X 82.5–90.5 (was 82–90); `CutThrough_Walk_3` X 82.5–122 (was 82–122); `ReservoirLanding` X 75–90.5, Z 188–202 (was 75–93, 188–206); `EdgeTrim_Landing_N`, `LandingBeacon` and the Walk_3/4 guide trims follow. Result: **7 of 40 (18%)**. No other viewpoint changes.

Why not 23%: col6 and col7 cross exactly where any 8-stud walkway from `Walk_4` must reach `Bridge_E`'s east end (X 75, Z 194–206). Measured alternatives on a disposable copy (no other spawn affected in any of them):

| Variant | Spawn_RES_2 | Trade-off |
|---|---|---|
| v1 as built | 5/40 (13%) | — |
| Trim landing only | 6/40 (15%) | — |
| Shift Walk_4 only | 6/40 (15%) | — |
| **v2: shift Walk_4 + trim landing** | **7/40 (18%)** | Landing 15.5 × 14 instead of 18 × 18 |
| Full reroute crossing the sight lines further north (Walk_3 at Z 137–145, join `Bridge_E`'s north face) | 7/40 (18%) | Loses two other samples (coil50); route ~9 studs longer; full redesign |
| No landing / Walk_4 | 9/40 (23%) | Route no longer connects |

Thinner slabs (1 stud) were considered and do not clear col6 or col7. Nothing was made transparent; no threshold or waiver was changed.

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

- **Any session:** run `9_rollback.luau`. It was exercised on disposable copies: 41 parts removed, map back to 1,861 parts / 370 collidable / 51 lights; a second run is a no-op; `1_build.luau` then rebuilds the same slice.
- **Safeguard tests (disposable copy, 2026-11-13):** the builder refused, changing nothing, for each of 19 deliberate alterations (Anchored, CanQuery, CanTouch, CastShadow, Transparency 0.5 and 1, CanCollide, Color, Material, Massless, Reflectance, Shape, a 0.1-stud move, an extra attribute, a removed role attribute, a wrong model category, an extra Folder, an Attachment under a part, a stale Map attribute) and for the older v1 slice. The rollback refused, deleting nothing, for a Script inside a slice model, an unknown Part in the folder, a Weld under a slice part, a part missing its category, a duplicate part name and a gameplay tag on a slice part.
- **Slice content found outside `Map.EnvSlice1`:** both scripts stop and name it. Investigate by hand; nothing is deleted automatically.
- **Anything else:** close without saving and reopen the verified pre-construction backup.

Never run a destructive restore against the authoritative saved place to demonstrate recovery.

## Production record (2026-11-13)

### v1 construction

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

### v2 review correction

| Item | Value |
|---|---|
| `Place1.rbxl` before | SHA-256 `AE7C8D0E9A28D68367C88C748F2A11AC564E7BC44CF3BB70F35781276EEC55E3` (v1), 232,836 bytes |
| Pre-correction backup | `Place1_pre-slice1-corrections_2026-11-13.rbxl`, byte-identical to the "before" file |
| Upgrade | `1_build.luau` refused the v1 slice (no change); `9_rollback.luau` removed 41 parts; `1_build.luau` built v2; a second run changed nothing |
| `Place1.rbxl` after (owner-saved) | SHA-256 `8B443F13FA25C58BA751079B847ED782E61F6161F650B7C1F8898A01B5F177F2`, 232,841 bytes, 1,902 parts / 379 collidable / 51 lights |
| Script sources | 44 of 44 identical to before and to `main` at `f716fe4` |
| Audit | overall PASS, 0 errors, 40 slabs; TraversalLinks 17/9/0, ExteriorScenery 24/0/0; `Spawn_RES_2` 18%; all other AC2, lobby and district lines identical to v1 |
| Unrelated content | Digest over the 2,525 other instances and lighting settings identical before the rollback, after it, and after the rebuild |
