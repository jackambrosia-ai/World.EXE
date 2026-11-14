# ENV_SPRINT2 builder

Owner-approved sprint (2026-11-13): a map expansion in `Workspace.WORLD_EXE.Map.EnvSprint2`. Scripts run in Studio through Studio MCP `execute_luau` (no Rojo). Built by three parallel agents (A: traversal design, B: exterior art, C: tooling and audit) and integrated by the coordinator. **Depends on draft PR #19** (`tools/env-slice1-construction` at `491f0bf`): this branch starts from that head, because `6_audit.luau` extends the ENV_SLICE1 audit.

| Model prefix | Category (`EnvSprint2` attribute) | Cap (parts / collidable / lights) | Owner of the spec |
|---|---|---|---|
| `Traversal_*` | `SprintTraversal` | 95 / 42 / 0 | Agent A: `traversal_spec.luau` |
| `Exterior_*` | `SprintExterior` | 105 / 0 / 2 | Agent B: `exterior_spec.luau` |
| Sprint total | | 200 / 42 / 2 | |
| Map after | | 2,102 / 421 / 53 | |

## Files and order
| Step | File | Mutates? | What it does |
|---|---|---|---|
| 0 | `node assemble.js` | No (writes `1_build.luau`) | Inlines both specs into `build_template.luau`, offline preflight (builder rules, budgets, map-after from the geometry export), structural Luau check. Deterministic. |
| 1 | `1_build.luau` | Yes: `Map.EnvSprint2`, Map attribute `EnvSprint2` | Validates the specs and budgets, refuses stray or differing sprint content, builds off-tree, self-checks, parents model by model, checks again, sets the attribute. Exact re-run = no-op. Run in `task.spawn`, poll `_G.ENVSPRINT2_BUILD`. |
| 2 | `../phase8a2b/6_audit.luau` | No | Full audit, ENV_SPRINT2-aware (header lists every sprint rule). |
| 3 | Focused Play tests | No | Solo Play. Walks are driven from server `execute_luau` (`MoveTo`; keep legs under 8 s because `MoveTo` times out at 8 s). Jumps must be driven from the **client**, which owns the character's physics (a server-set `Jump` arrives late): bind `Humanoid:Move(dir)` to a RenderStep after the control script and set `Jump` at a chosen distance before the edge. Live services (Validate, MatchesBaseline, patches) are reached through a Script injected into the Play session only. |
| 9 | `9_rollback.luau` | Yes | Removes only structurally recognised sprint content and the attribute; refuses otherwise. |

## Roles (collidable parts, SprintTraversal only; exactly one per part)
- `WalkSurface`: level, unrotated Block ≥ 4×4 in bounds, joined flush to another floor (ENV_SLICE1 rule).
- `EdgeRail`: unrotated Block ≥ 4 high on a sprint WalkSurface edge that faces the void (C13).
- `JumpStep` (new, Agent C): level, unrotated Block ≥ 4×4 in bounds; jump links rise ≤ 6.5 and gap ≤ min(6, 9 − rise) across a shared edge ≥ 4; each step group links two existing floors; no void (floor ≤ 40 below every corner and the centre); take-off headroom 12 studs over the 2-stud band plus gap (C6j); C6s above each step.

Decorative parts: CanCollide/CanQuery/CanTouch/CastShadow false. Lights: PointLight/SpotLight, SprintExterior only, Shadows false. Streaming: Traversal Default, Exterior Atomic.

## Spec row format
`{ name, size, position, {r,g,b}, material, role|nil, orientation(deg)|nil, extra|nil }`; `extra` keys: `shape` (Block/Wedge/Cylinder/Ball), `class` (Part/WedgePart/CornerWedgePart), `transparency` [0,1), `reservedUse` (string → `ReservedUse` attribute), `light` `{ class, range ≤ 60, brightness ≤ 10, color, angle?, face? }`. Group keys: `model`, `category`, `parts`, optional `anchors = { { name, position, size } }`. Reserved names (audit/gameplay meanings) are refused.

Upgrading: bump `VERSION` in the template, `9_rollback.luau`, then the new `1_build.luau`.

## Built (v1 2026-11-13)

| Model | Parts | Collidable | What it is |
|---|---|---|---|
| `Traversal_YardArchiveLink` | 12 | 7 | Y24 railed walkway from `Catwalk_N` (east face X −145) round `VaultWall_W2` to `ArchiveWalk_S` (south face Z −146); marked drop-downs to `YardFloor_N` / `ArchiveFloor` |
| `Traversal_ArchiveSkyLink` | 12 | 6 | Y24 railed walkway from `ArchiveWalk_S` round `VaultWall_E2` to `SkyLanding_N` (west face X 150); open drop to `SkyBase` |
| `Traversal_IslandClimb` | 21 | 9 | Nine 7×7 JumpSteps (+5 each, tops 29–69) spiralling a signal mast from `SkyLanding_N` (Y24) to `Island_N` (Y72, `SUP_ISLAND`, `FRAG_10`); misses land on `SkyLanding_N` or `SkyBase` |
| `Exterior_FracturedMonolith` | 41 | 0 | SW void band (−295, ·, 295), Y −90…148: basalt root, violet fracture, sheared and tilted blocks, wireframe "deleted" top, fragments; 1 PointLight |
| `Exterior_SeveredCauseway` | 30 | 0 | NE corner: plated causeway snapped into a V over the abyss, rebar, falling span, violet corruption, dying cyan line |
| `Exterior_RenderLattice` | 31 | 0 | NW corner: open grid tower being re-rendered, cyan live lines and scan ring; 1 PointLight |
| **Total** | **147** | **22** | 2 lights (Shadows off) |

Integration change to Agent A's spec: the climb failed C6j (the first take-off was under step 2's underside, 8 studs up). Steps 1 / 2–9 and their strips moved −1 / −2 in Z (Agent C's verified fix).

## Production record (2026-11-13)

| Item | Value |
|---|---|
| `Place1.rbxl` before | SHA-256 `8B443F13FA25C58BA751079B847ED782E61F6161F650B7C1F8898A01B5F177F2`, 1,902 parts / 379 collidable / 51 lights |
| Pre-sprint backup | `Place1_pre-env-sprint2_2026-11-13.rbxl`, byte-identical to "before" |
| `Place1.rbxl` after (owner-saved 18:16:23) | SHA-256 `6B4129D292A934BD6C96A6D49431BFFC0022B802422E1CAC83688DA1E136AEC3`, 237,048 bytes, 2,049 / 401 / 53 |
| Script sources | 44/44 identical before and after, and to `main` `f716fe4` |
| Audit with sprint absent (new audit) | identical keys and results to the previous ENV_SLICE1 audit (PASS, 40 slabs) |
| Audit after build | overall PASS, 0 errors, 53 slabs; SprintTraversal 45/22/0, SprintExterior 102/0/2; district caps unchanged; AC1, AC2 (all 16 spawns), lobby views identical to before; `AC2_sprintImpact` empty |
| Unrelated content | digest over the 2,569 non-sprint instances + lighting identical before and after build and after Play |
| Builder | second run "already built"; also tested: rollback refusals (Script inside, gameplay tag), clean rollback to 1,902/379/51, rebuild, on a disposable copy |
| Audit negative test (disposable copy) | 5 planted faults (broken jump link, displaced slab, shadow light, roleless rail, part on Spawn_RES_2's sight line) all reported; overall FAIL |
