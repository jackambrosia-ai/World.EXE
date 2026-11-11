# Phase 8A — Major Arena Reconstruction: design proposal

Status: **planning only.** Nothing in Studio has changed. Implementation needs separate owner approval after this design is reviewed.

Baseline: `main` `f9e4707`; Studio matches it (42/42 scripts); rollback point `WorldEXE_post-phase7b_2026-11-10.rbxl`.

Layout diagram: [`phase8a_layout.svg`](phase8a_layout.svg) (top-down; north is up).

## 1. Why rebuild

The current arena (Phase 1, "THE SANDBOX") is a functional blockout:
- It covers about 360 × 165 studs, but most of it is two flat levels (Y 0 and Y 24) with roughly 170 parts.
- It has three zones and one landmark (the reactor).
- It is plain navy blocks with no architectural identity.

It proved the match loop, the 10 patches and the 5 combinations. The owner judges it substantially too small and far from the WORLD.EXE vision.

Phase 8A replaces the map geometry. **It does not change the game rules.** All existing systems keep working through the same tags and attributes. Only counts, bounds and a few map-size tuning values change, each listed below.

## 2. Goals

1. **Scale:** a substantially larger, interconnected sci-fi facility.
   - About 4–5× today's walkable area.
   - Edge-to-edge crossing about 30–35 s at walk speed.
   - Centre to any zone at most about 15 s.
2. **Structure:**
   - Five themed zones plus a connecting ring.
   - Four height tiers, each zone with at least 3 entrances.
   - No dead ends.
3. **Landmarks:** each zone readable from a distance (reactor spire, rack canyons, pump towers, floating islands, test grid).
4. **Every patch and combination has a home:** each of the 10 patches and 5 combinations has designed locations where it is readable, has counterplay, and is interesting.
5. **Fair multiplayer for 8–12 players:**
   - flank routes and wide corridors (12 studs minimum);
   - safe spawns;
   - objectives spread out.
6. **Cohesive identity:** a navy base, cyan system lines, violet for simulation and patch elements. Amber, green and red stay reserved for warnings, objectives and danger.
7. **Performance budget suitable for mobile clients,** with StreamingEnabled kept on.

## 3. Proposed layout

### Coordinates and tiers
- **Footprint:** X −260…+260, Z −260…+260 (520 × 520 studs), centred on the origin. −Z is north.
- **Tiers:**

  | Tier | Height |
  |---|---|
  | **T0** ground | Y 0 |
  | **T1** mezzanines, catwalks, outer ring | Y 24 |
  | **T2** gantries, SkyDeck | Y 48 |
  | **T3** floating islands | Y 72 |
  | Reservoir basin | Y −10 |

- **Arena bounds:** `Config.ArenaBounds` becomes about (−275, −40, −275) … (275, 160, 275). `OutOfBoundsY` stays −60.
- **Lobby:** moves from (0, 80, 150), which would sit inside the new footprint, to about (0, 160, 420). There it is outside the bounds and still overlooks the arena.

### Zones

| Zone | Where | Size | Character | Key features |
|---|---|---|---|---|
| **Central Core** | centre | radius ~105 | The heart of the simulation | Reactor spire, about 140 studs tall: violet core, cyan rings, impassable centre radius ~18. T0 plaza ring. T1 mezzanine ring reached by 4 ramps. T2 gantry spokes to Skybridge and Archive. **Stabilizer CORE** on the north plaza |
| **Research Yard** (expanded) | west | ~160 × 240 | Test laboratory | 10 × 10 DecayTile test grid (100 tiles). Two enclosed test chambers with open doorways for cover. T1 observation catwalks on the north and south walls. **Stabilizer YARD** |
| **Skybridge District** (expanded) | east | ~160 × 240 | Elevated control decks | SkyDeck (T2). Two floating islands (T3) linked by bridges and jump steps. Ramp up from the Core spoke; steps down to the outer ring. **Stabilizer SKY** on the SkyDeck |
| **Data Archive** (new) | north | ~270 × 140 | Server-rack canyons | 6 rows of racks (8 wide, 30 tall) with 14-stud aisles and cross-aisles. Open central atrium (60 × 60). T1 catwalks over the racks. Glowing rack strips stay readable during BLACKOUT |
| **Coolant Reservoir** (new) | south | ~270 × 140 | Cooling plant | Sunken basin (Y −10, ~150 × 90) with two pump towers (cover). Rim walkways (T0), T1 bridges across. Cargo lanes for magnetic crates along the east side |
| **Outer Ring Route** (new) | radius ~190 | 14 wide | Connector | T1 elevated loop linking all four outer zones, with ramps down into each. Gives flank routes that avoid the Core |

**Connections:**
- 4 T0 spoke corridors (20–24 wide) from the Core to each outer zone.
- 2 T2 gantries (Core to Skybridge, Core to Archive).
- The T1 outer ring.
- At least 16 ramps or stair sets.

Every elevated area has at least 2 ways down. Drop-downs are allowed; there is no fall damage.

**Landmarks and sightlines:**
- The reactor spire is visible from everywhere and blocks the centre's long sightlines.
- Racks break up sightlines in the Archive. The Yard stays open (hazard area).
- The Skybridge looks over everything, but its exposed decks are counterbalanced by drone patrols.

## 4. Patch and combination integration

Every location is a new tagged marker or surface, validated by ArenaService. "Count" is the proposed `ExpectedTagCounts` value.

| Patch / combination | Where it plays | Markers (count now → proposed) | Notes |
|---|---|---|---|
| ZERO_G | Everywhere; designed **zero-G shortcuts**: 30-stud gaps between T2 and T3 islands and the reactor shaft, crossable only in low gravity | — | Shortcuts are optional, never the only route |
| DECAY | Yard test grid | DecayTile 64 → **100** | Cap of unsafe tiles scales 8 → 12 (see §8) |
| DRONE_SWARM | Patrol graph over every zone: Archive aisles, Core ring, Reservoir, Sky decks | DroneWaypoint 15 → **30** | Waypoints at Y 10 / 34 / 58; links checked as now (symmetric) |
| SUPPLY_DROP | At least one landing point per zone, plus the ring | SupplyLandingPoint 5 → **8** | Clear sky above each point |
| BOUNCY | Pads under 12-stud ledges (new Y 12 half-platforms) as alternative ways up. With ZERO_G they reach T1 and T2 | BounceSurface 4 → **8** | Normal bounce rise is about 15 studs, so the pads target 12-stud ledges |
| SLIPPERY | Reservoir rim walkways, Archive cross-aisles, Core ramps' landing flats | SlipSurface 4 → **8** | Never on the only route to an exit |
| BLACKOUT | Global. The Archive is the showcase: neon rack strips and lit stabilizers stay readable | — | Lighting minimums unchanged |
| MAGNETIC | Reservoir cargo lanes and Core plaza lanes | MagneticProp **8** (cap unchanged), MagneticPoint 4 → **6** | Lanes validated by the build tool as today |
| CORRUPTION | Three paths: Core plaza arc, Yard grid edge, Archive aisle | CorruptionNode 12 → **18** (3 paths × 6) | One path per activation; the cap of 6 is unchanged |
| FLOOD | Reservoir basin (MaxRise 6, water to Y −4), Core plaza, Yard grid | FloodZone 2 → **3** | Escapes: mezzanine, catwalks, ring, Sky. Every zone keeps a dry exit |
| SUPER_BOUNCE | Bounce pads under T1 and T2 ledges become real shortcuts | — | Apex cap of 35 studs unchanged |
| HUNTER_SCAN | Archive canyons: scan cones read clearly down the aisles | — | |
| FLOATING_DEBRIS | Reservoir basin: crates float into a stepping route across the water | — | The basin is the designed stage |
| RAPID_DECAY | Yard: the corruption path runs along the decay grid | — | Warnings unchanged |
| SLIDE_FIELD | Reservoir cargo lanes and slippery rim | — | Rings mark the safe points |

## 5. Objectives, spawns and pickups

- **Stabilizers:** keep **3**, as the design document requires (Core north plaza, Yard, SkyDeck).
  - They form a triangle about 200–260 studs apart, roughly 15 s between neighbours.
  - Each keeps its interaction radius and stays clear of every hazard marker. The build tool checks this.
- **Spawns:** ArenaSpawn 12 → **16**: Core 4, Yard 3, Sky 3, Archive 3, Reservoir 3.
  - **New spawn-safety rules,** checked by the build tool and added to ArenaService validation:
    - not on DecayTiles (as now);
    - not inside a FloodZone footprint;
    - at least 8 studs from corruption nodes, magnetic lanes, and bounce and slip pads;
    - clear headroom (as now).
  - Spawn protection (5 s ForceField) is unchanged.
- **Data fragments:** FragmentSpawn 12 → **24**, spread over all five zones and the ring.
  - The active fragment cap rises 8 → 12, because the map is larger.
- **Lobby:** moves outside the new bounds (§3); the lobby builder is rerun at the new location.

## 6. Visual identity (architecture level; UI, VFX and generated art are Phase 8B)

| Element | Treatment |
|---|---|
| Base structure | Deep navy and charcoal (`#0A0F1F` – `#26345E`); Metal, SmoothPlastic and DiamondPlate materials |
| System lines | Cyan (`#00E1FF`) neon trim strips (0.2–0.4 studs) on floor edges, ramp edges and rack faces; path lines guide players toward the stabilizers |
| Simulation / patch identity | Violet (`#8A2BE2`): reactor core, patch-surface frames, gantry undersides |
| Reserved colours | Amber = warnings only (DECAY, CORRUPTION). Green = objectives only (stabilizers). Red/coral = critical danger only (drones) |
| Lighting | Existing Lighting values kept, so BLACKOUT's baseline is unchanged. Add Atmosphere and colour correction for depth and a navy haze. At most about 80 light sources (PointLight/SurfaceLight), mostly on landmarks and stabilizers |
| Landmarks | Reactor spire, rack canyons, pump towers, floating islands, test-grid frame |

No uploaded assets or ForgeGUI generation in 8A: only built-in materials and parts. Textures, decals, icons and VFX come in 8B, under the ForgeGUI rules.

## 7. Performance and streaming

- **Budget:**
  - at most about 4,000 parts in the map, all anchored;
  - no unions in the first pass;
  - decorative parts set to `CanQuery = false`, `CanTouch = false`, `CastShadow = false`, Box collision.
- **StreamingEnabled stays on**, per the Phase 0 decision.
  - The map's half-extent (~260) is well inside the default streaming target radius.
  - Zones are separate Models; stabilizers may use the Atomic streaming mode if tests show they need it.
  - The server reads every tagged marker server-side, as now.
- **Measured in Studio before review:** part count, server heartbeat during a full match with all patch types, and client FPS and memory on the desktop and mobile emulators.

## 8. Systems that change with the map (all small, all listed)

| Item | Now | Proposed | Why |
|---|---|---|---|
| `Config.ExpectedTagCounts` | see §4–5 | new counts | New markers |
| `Config.ArenaBoundsMin/Max` | (−185, −60, −95)…(175, 90, 70) | (−275, −40, −275)…(275, 160, 275) | Bigger footprint (dash bounds and spectator containment use it) |
| Lobby position | (0, 80, 150) | (0, 160, 420) | Outside the new bounds |
| Decay `MAX_UNSAFE` | 8 of 64 | 12 of 100 | Same proportion |
| Collectible `MAX_ACTIVE` | 8 | 12 | Larger map |
| New ArenaService spawn rules | — | flood, corruption, lane and pad clearances | Spawn safety |
| Drone counts and speed, SCANNER range, patch timings, stability values | — | **unchanged** | Gameplay rules unchanged in 8A |
| Match timeline, cadence, cap | — | **unchanged** | — |

## 9. Implementation plan (after approval)

The map is generated by tool scripts in `tools/studio/`, as in every earlier phase, so the geometry is reproducible and reviewable. **Two PRs:**

1. **8A-1 — Layout and gameplay migration.**
   - Back up the place first.
   - Build the new Map with `tools/studio/phase8a_build_arena.luau` as a greybox with navy materials.
   - Move the old Map to `ServerStorage` as a rollback copy until 8A is approved.
   - Rebuild the lobby at its new location and set `ArenaVersion = 2`.
   - Place every tagged marker with the validating marker tools: spawns, stabilizers, waypoints, fragments, supply points, pads, crates, points, nodes, flood zones.
   - Update Config counts and bounds, the two caps and the spawn rules.
   - **Review evidence:** Studio screenshots per zone and from the top, the part count, and the validation report.
   - **Tests:**
     - ArenaService validation and baseline;
     - spawn safety;
     - a run of every patch and combination on the new map;
     - two full live matches with consecutive-match cleanup;
     - performance numbers;
     - parity.
2. **8A-2 — Architectural identity.**
   - Neon trim lines, landmark detailing, atmosphere and lighting, all within the budget.
   - Before/after screenshots and the performance check.

**Rules for both PRs:**
- Every stage keeps the game playable.
- The old map is deleted only after owner approval.
- PR #4 is untouched.
- No publishing, ForgeGUI, persistence or paid automation.

## 10. Risks

- **Pacing:** a bigger map means longer travel. It is mitigated by ring and spoke routes and by spreading stabilizers and fragments. If matches feel empty, tune the fragment cap and drone counts in playtests.
- **Combination overlaps** are still about 6–10 s (unchanged; balancing is carried forward). The new stages (Reservoir basin, Yard grid) make them more visible but not longer.
- **Stability pressure** stays as reported in Phase 7B; balancing is carried forward.
- **Performance on mobile** with 4× the geometry. This is why there is a budget, decorative-part settings and streaming; it will be measured before review.
- **Multiplayer** behaviour on the larger map (spawn spread, chokepoints, drone targeting) cannot be fully verified solo. It is assigned to the pre-release integration milestone as before.
- **Build size:** this is the largest Studio change so far. Staging in 2 PRs, with a backup before each, limits the risk.

## 11. Decisions requested

- **M1 Scale:** a 520 × 520 footprint with 4 tiers plus the basin.
- **M2 Zones:** Core, Yard and Skybridge (expanded), plus the new Data Archive (north) and Coolant Reservoir (south), plus the T1 Outer Ring.
- **M3 Stabilizers:** keep 3 (recommended), or 4 (one more in the Archive or Reservoir).
- **M4 Marker counts:** the §4–5 table, including 100 DecayTiles and 16 spawns.
- **M5 Map-size tuning:** Decay unsafe cap 12, fragment cap 12; everything else unchanged.
- **M6 Lobby relocation** to about (0, 160, 420).
- **M7 Build approach:** tool-generated geometry; old map kept as a rollback copy until approval; 2 PRs (8A-1 layout and migration, 8A-2 architectural identity).
- **M8 Visual scope split:** architecture palette, materials and lighting in 8A; UI, VFX, textures and ForgeGUI art in 8B.
