# Phase 8A-2 — Architectural identity: design proposal

Status: **planning only.** Nothing in Studio has changed. Implementation needs separate approval after this design is reviewed.

Baseline: `main` `3ed5425` (Phase 8A-1 merged as `44e8f1d`); rollback point `WorldEXE_post-phase8a1_2026-11-10.rbxl`.

Diagram: [`phase8a2_elevation.svg`](phase8a2_elevation.svg), the proposed skyline from west to east. Current state: [`phase8a1/`](phase8a1) screenshots.

## 1. Why it still reads as "floating platforms"

The 8A-1 greybox fixed scale and connectivity but not presence. These are the specific causes, measured against the screenshots:

1. **Everything is a thin slab.** Floors are 2–4 studs thick and walls are rare. Almost nothing rises above T1 except the reactor shaft and the Sky deck, so the facility has no mass.
2. **No visible means of support.** Platforms end in empty space; there are no columns, foundations or substructure.
3. **The default blue daytime sky and gray void** surround everything. The arena reads as a model on a table, not a place.
4. **No enclosure.** No roofs, ceilings, halls or rooms. The only interiors are two 12-stud test chambers.
5. **Districts share one look.** The same navy slab and the same trim appear everywhere, so nothing tells you which district you're in except the layout.
6. **The reactor is a thin glowing cylinder.** It isn't yet the dominant landmark the fiction needs.
7. **Flat lighting.** Daylight, no atmosphere colour, no light pools, and neon used uniformly.

## 2. Goals for 8A-2

| # | Goal | Measurable target |
|---|---|---|
| G1 | Recognizable district silhouettes | Each district has a signature shape over 40 studs tall, identifiable in a top-down or skyline screenshot |
| G2 | Structure and grounding | Every platform edge visibly supported; substructure below T0 down to a visible floor; no unsupported slab longer than 60 studs |
| G3 | Enclosed and semi-enclosed spaces | At least one roofed or walled space per district (hangar, vault, plant hall, control room, atrium canopy) |
| G4 | A dramatic reactor | About 160 tall; buttresses, coil rings, a crown and an energy beam; readable from every spawn |
| G5 | Environmental framing | No default sky or void visible from play spaces: containment walls, a distant skyline, a luminous floor below, navy atmosphere |
| G6 | Distinct zone identity | Per-district material, trim and colour accents within the navy/cyan/violet palette (§5) |
| G7 | Performance | Within the budget in §7, measured on a **foreground** desktop client before review |
| G8 | Gameplay unchanged | No walkable route, marker, tier or timing changes, except where §6 lists one explicitly |

## 3. Environmental framing (removing the void)

**Concept: a "Simulation Containment Hall".** The arena sits inside a vast, mostly open containment structure.
- **Containment walls** stand outside the playable footprint at about ±300, roughly 120 tall.
  - Dark panels with vertical cyan seams and a violet horizon band.
  - Gaps frame views of the backdrop.
  - Decorative and non-collidable; well beyond `ArenaBounds` (±275).
- **Distant skyline:** 12–16 megastructure towers and server monoliths (150–250 tall) at a radius of about 380–450, beyond the bounds.
  - They give depth and scale.
  - Few parts each; low detail; CastShadow off.
- **Luminous data floor** at about Y −90: a wide dark plane with a faint cyan grid of strips.
  - It grounds everything visually.
  - It sits below the unchanged −60 kill plane, so falls still respawn.
  - Non-collidable, so it can never be stood on.
- **Sky and atmosphere** (Lighting):
  - Night-time `ClockTime` and a navy `Atmosphere` (density about 0.35, cool haze, violet glare).
  - `ColorCorrection` for contrast.
  - The sun/moon disc hidden or minimised; no uploaded skybox (no new assets).
  - **This changes the Lighting baseline** that WorldModifierService captures at start (see decision A2). BLACKOUT keeps its readable minimum (Brightness ≥ 0.5) and still restores the exact new baseline.
- **Fog and depth:** light atmospheric falloff, so the backdrop recedes and the play spaces stay crisp.

## 4. District architecture

All additions go in a new `Map.Architecture` folder. Each district has:
- a **signature** structure;
- **structure** (supports and substructure);
- **enclosure**;
- **details**.

| District | Signature (silhouette) | Enclosure | Structure and details | Identity |
|---|---|---|---|---|
| **Central Core** | **Reactor complex, about 160 tall.** Four angled buttresses rise from the drum. Stacked violet coil rings at 40/80/120. A cyan energy column. A crown cap with emitter fins. A vertical beam to the "ceiling" (decorative, client-side motion deferred to 8B) | Ring canopy over the mezzanine (open centre for the reactor); colonnade on the plaza edge | Columns under the mezzanine and gantries; balustrades (glass plus a cyan rail); floor inlays radiating from the core; enclosed gantry tubes (ribs, glass sides, open ends) | Cyan and violet; the brightest district |
| **Research Yard** | **Test hangar:** a vaulted truss roof (about 45) over the DecayTile grid, with skylight bays | Hangar walls with large openings on all four sides; test chambers become lab pods with door frames and roof slabs | Roof trusses; crane gantry over the grid; observation windows on the catwalks; instrument masts | Violet accents, cool white lab panels, grid inlays |
| **Skybridge District** | **Command spires:** two to three towers (about 80–110) with antennae; the SkyDeck becomes a control-tower top | Glass-walled control room on part of the deck (open sides toward play) | Lattice pylons down to the substructure; visible energy tethers (decorative beams) to the T3 relay pods; pod undersides with thrusters | Violet beacons; silver and glass |
| **Data Archive** | **Server cathedral:** a vaulted roof (about 70) over the rack canyons, with an **open oculus** over the atrium | The vault itself; side walls with tall slots | Racks keep the T1 walking tops, plus non-walkable upper cooling stacks between rows (above jump reach, clear of aisles); cable trays; data-stream strips | Cyan data light, dark metal; best BLACKOUT showcase |
| **Coolant Reservoir** | **Cooling plant:** two to three hyperboloid cooling towers (about 60–80) replace the slim pump towers' silhouette; pipe racks around the rim | Pump hall on one rim (open front) | Large pipes; tank walls with gauges; railings on rim walkways; the basin keeps its open sky for FLOOD | Teal-cyan water accents, concrete and steel |
| **Outer Ring** | **Transit ring:** support pylons into the substructure every about 60 studs; signal arches at each district entry | — | Guard rails with gaps at designated drop-down points; lights under the deck | Cyan running lights |

**Railings policy (decision A3).**
- Low (3-stud) collidable rails on the Outer Ring, gantries, bridges and catwalk edges.
- Gaps are left at every designated drop-down, ramp and zero-G gap.
- Rails reduce accidental falls. They stay jumpable, so they never become a trap.

## 5. Visual language (architecture level)

| Element | Rule |
|---|---|
| Base | Navy and charcoal structure (`#0A0F1F` – `#26345E`). Materials: Metal, DiamondPlate, Concrete (cooling plant), Glass (control rooms, balustrades) |
| Cyan `#00E1FF` | System and navigation: path inlays toward stabilizers, edge trims, data streams. Brightest along walkable edges |
| Violet `#8A2BE2` | Simulation and patch: reactor coils, patch-surface frames, district beacons |
| Reserved | Amber = warnings only. Green = objectives only (stabilizers get a green light pool). Red/coral = danger only (drones) |
| Hierarchy | Landmark > district signature > walkable edges > decoration. Neon is never used on large surfaces (readability and BLACKOUT contrast) |
| Lights | About 60–80 PointLight/SurfaceLight, concentrated on the reactor, stabilizers, district signatures and entry arches |

No uploaded textures, decals or meshes, and no ForgeGUI in 8A-2: built-in materials and parts only. Textures, VFX, motion (rotating rings, beams) and UI are Phase 8B.

## 6. Gameplay safety (what must not change)

Every 8A-2 addition is validated by the builder against the existing gameplay. The builder **aborts and restores** if any check fails.

| Constraint | Check |
|---|---|
| Walkable routes unchanged | New collidable parts may not overlap walkable surfaces, ramps or a 6-stud headroom envelope above them (rails excepted, at the edges only) |
| Supply drops | The sky column above all 8 landing points stays clear to Y 160 (the Archive oculus keeps SUP_ARCHIVE open; the Yard hangar roof covers only the grid) |
| Drone patrols | All 30 waypoint links keep line of sight |
| BOUNCY / SUPER_BOUNCE | Nothing collidable above any bounce pad below Y 40 (the 35-stud apex cap) |
| ZERO_G gaps | Both 14-stud gaps stay open with clear air above them |
| MAGNETIC lanes | All 8 crate lanes stay clear (box sweep) |
| FLOOD | No new collidable parts inside flood volumes up to their max level; escape routes unchanged |
| Spawns and stabilizers | Headroom and the spawn-safety rules unchanged; stabilizer interaction radius clear |
| Arena baseline | New parts live in `Map.Architecture` and become part of the baseline (ArenaVersion 3) |

Decorative parts:
- `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` off, so they never affect raycasts, DASH checks or SCANNER.
- Only true structure (columns, rails, walls outside paths) is collidable.

## 7. Performance plan

- **Budget** (initial targets):
  - about 3,500 parts in the map (8A-1: 522);
  - at most about 80 lights;
  - at most 2 Beams/ParticleEmitters per district (static only in 8A-2);
  - no unions or CSG;
  - decorative parts non-collidable and non-queryable, CastShadow off below 4 studs.
- **Streaming:**
  - StreamingEnabled stays on.
  - District architecture is grouped into Models. The far backdrop goes into one Model with `ModelStreamingMode = Persistent` (low part count), so the horizon always renders.
  - Revisit if memory grows.
- **Measurement (closes the carried-forward item):**
  - **Before 8A-2 approval:** a baseline foreground desktop client FPS on the current 8A-1 map.
  - **Before 8A-2 review:** a post-8A-2 measurement with the same method.
  - Method: a scripted 10-second camera path through every district, recording FPS, frame time and client memory.
  - It needs **the owner to keep the Studio window focused** during the run (an unfocused Studio throttles rendering to 15 FPS).
  - Server heartbeat under a three-patch load is measured as in 8A-1.
  - Mobile and device testing remain release-milestone items.

## 8. Implementation approach (after approval)

- **Builder:** `tools/studio/phase8a2_architecture.luau`, committed and reproducible from the post-8A-1 backup.
  - Builds `Map.Architecture` (per-district Models) and the framing (backdrop, walls, data floor) outside the gameplay bounds.
  - Applies the Lighting/Atmosphere preset.
  - Runs every §6 check; restores on failure; sets `ArenaVersion = 3`.
- **Code:** no gameplay code changes expected. The only expected change is Config text (version) and, if A2 is approved, nothing more: WorldModifierService captures the new Lighting baseline automatically.
- **Two review checkpoints:**
  1. **8A-2a: framing, lighting and reactor.** The biggest visual change. Screenshots, the foreground FPS figure, and the §6 checks.
  2. **8A-2b: district architecture.** All five districts. Screenshots per district plus top-down and skyline; budget and FPS; a targeted regression (validation, traversal spot-checks, one patch of each kind, combinations, two-match cleanup).
- **Evidence:** screenshots from fixed camera positions matching the 8A-1 set, so before and after can be compared directly.

## 9. Risks

- **Readability.** Darker lighting could hide hazards. This is mitigated by the reserved-colour rules, neon edges on walkable surfaces, and light pools at stabilizers. Checked with BLACKOUT active.
- **Performance.** About 7× the parts. Mitigated by the budget, non-collidable decor, streaming groups and foreground measurement; mobile still unverified until the release milestone.
- **Gameplay drift.** New geometry near routes. Mitigated by the §6 checks and the targeted regression.
- **Taste.** This is subjective. The 8A-2a checkpoint lets the owner and reviewer redirect early, before all districts are built.

## 10. Decisions requested

- **A1 Framing:** a containment hall with walls about 120 at ±300, a distant skyline and a data floor at about Y −90 (recommended), versus a fully roofed hall.
- **A2 Lighting baseline:** a night/navy preset (`ClockTime`, `Atmosphere`, `ColorCorrection`). This changes the baseline BLACKOUT dims from and restores to.
- **A3 Railings:** low, jumpable rails on the ring, gantries, bridges and catwalks, with gaps at drop-downs and gaps.
- **A4 District concepts:** as in §4 (hangar, server cathedral, cooling plant, command spires, reactor complex, transit ring).
- **A5 Budget:** about 3,500 parts and about 80 lights, no unions, static effects only.
- **A6 Staging:** one branch with two review checkpoints (8A-2a, then 8A-2b), or two PRs.
- **A7 Foreground FPS procedure:** the owner keeps Studio focused for two short scripted runs (8A-1 baseline now; post-8A-2 later).
