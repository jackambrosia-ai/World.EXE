# Phase 8A-2 — Creative direction and architectural design

Status: **planning only.** No construction has been done in Studio. The only Studio actions were camera moves for screenshots and read-only queries. There has been no ForgeGUI generation or spending, no publishing and no uploads. Implementation needs separate approval after review by ChatGPT and the owner.

**Baseline**
- `main` `3ed5425` (Phase 8A-1 merged as `44e8f1d`).
- Rollback point: `WorldEXE_post-phase8a1_2026-11-10.rbxl` (SHA-256 `E0B955F4…14714745`).

**Revision 2 (design review corrections, 2026-11-11)**
- The part budget is reconciled with the kit (§6, §9.1).
- Lobby observation bay added (§5.2).
- The hall now has a terraced section so it doesn't feel cramped: hall wall top lowered to Y 180, so the reactor crown (Y 190) tops the skyline.
- Visibility acceptance now uses screenshots plus analytic occlusion (§11).
- Selective streaming plan and responder requirements added (§9.2, §12).
- Exact FPS benchmark added (§9.3, `tools/studio/phase8a2_fps_benchmark_*.luau`).
- Elevation redrawn to scale; lobby sketch added; decision summary added (§15).

**Sketches** (schematic mockups, not renders). Each was rendered locally with headless Edge and inspected; see §16.
- [`phase8a2_elevation.svg`](phase8a2_elevation.svg): north–south section through x = 0, to scale (vertical ×1.4). It shows the terraced hall, the lobby bay and the reactor.
- [`phase8a2/lobby_observation_after.svg`](phase8a2/lobby_observation_after.svg): the view from the lobby through the observation bay.
- [`phase8a2/establishing_after.svg`](phase8a2/establishing_after.svg): perspective establishing shot.
- [`phase8a2/ground_core_before_after.svg`](phase8a2/ground_core_before_after.svg): Central Core at ground level, before and after.
- [`phase8a2/ground_districts_after.svg`](phase8a2/ground_districts_after.svg): Data Archive and Coolant Reservoir at ground level, after.

| # | Deliverable | Section |
|---|---|---|
| 1 | Vision | §1 |
| 2 | Reference board | §2 |
| 3 | District specifications | §3 |
| 4 | Reactor redesign | §4 |
| 5 | Megastructure and lobby observation bay | §5 |
| 6 | Modular kit and reuse plan | §6 |
| 7 | ForgeGUI (and Figma) recommendation | §7 |
| 8 | Lighting, atmosphere and materials | §8 |
| 9 | Performance: budget, streaming, FPS benchmark | §9 |
| 10 | Staged implementation and validation | §10 |
| 11 | Before/after acceptance criteria | §11 |
| — | Patch-responsive environment | §12 |
| — | Gameplay safety rules | §13 |
| — | Decisions | §14 |
| — | Decision summary: ready for owner approval | §15 |
| — | Sketch verification and dimension reconciliation | §16 |

---

## 1. Vision

> **WORLD.EXE is fought inside the containment hall of a reality-simulation reactor.** It is a facility on the scale of a particle-physics cavern or a fusion-plant assembly hall. Every walkable floor is clearly built: held up by columns, girders and machinery that descend into a deep substructure. A vast terraced hall encloses the space, its walls and ceiling ribs fading into navy haze. The reactor at the centre is the tallest and brightest thing you can see. Players waiting in the lobby watch it all from an observation bay set into the hall wall. When the Architect patches the simulation, the building reacts.

Style: a professional, stylized Roblox sci-fi look, not photorealism. The palette is restrained: heavy mass, with light used sparingly.

**Three environmental layers**

| Layer | What | Collision | Where |
|---|---|---|---|
| **L1 Playable architecture** | The existing 8A-1 floors, ramps, bridges and markers, plus dressing on them: rails, kerbs, balustrades, door frames, roof slabs, inlays | As now. New rails and kerbs only at edges, with gaps at drop-downs | Inside `ArenaBounds` (±275) |
| **L2 Structure and machinery** | Supports, girders, district signature buildings, the reactor complex, pipes, stacks, cranes | Decorative (non-collidable), except where noted in §9.1 | Inside the arena and below it, down to Y −90 |
| **L3 Megastructure** | Terraced containment hall, ceiling ribs, terrace machinery, far silhouettes, shaft floor, lobby observation bay | None (all decorative) | ±280 to ±520, Y −90 to 240 |

**What the current map shows** (ground-level captures from 2026-11-11, Edit mode, camera only)

| Shot | Camera → look-at | Image | What it shows |
|---|---|---|---|
| G1 Core plaza | (0,6,110) → (0,40,0) | [g1](phase8a2/g1_core_ground.jpg) | The reactor is a thin tube; the mezzanine is a slab on legs; daytime sky |
| G2 Research Yard | (−235,6,60) → (0,30,0) | [g2](phase8a2/g2_yard_ground.jpg) | Flat tile field, empty horizon |
| G3 Data Archive | (20,6,−145) → (0,10,−250) | [g3](phase8a2/g3_archive_ground.jpg) | Racks are flat cyan rectangles; sky shows through the canyon |
| G4 Coolant Reservoir | (40,6,150) → (0,−5,240) | [g4](phase8a2/g4_reservoir_ground.jpg) | Basin and two plain cylinders; bridges float |
| G5 Skybridge deck | (200,54,10) → (0,30,0) | [g5](phase8a2/g5_skybridge_deck.jpg) | Empty deck, bare haze horizon |
| G6 Ring horizon | (225,30,225) → (0,15,0) | [g6](phase8a2/g6_ring_horizon.jpg) | Grey void under every slab; floating stepping blocks |

These six positions are the fixed before/after reference cameras (§11).

---

## 2. Reference board

**Rules**
- Links only. Nothing was downloaded, committed or uploaded, including to ForgeGUI or Figma.
- Sources are Wikimedia Commons. *(verify)* means the licence was seen only in a search snippet; check the file page before any reuse beyond reference.
- These are mood and structure references. Nothing is to be traced or reproduced.

| Theme | Reference (source, credit, licence) | What we take from it |
|---|---|---|
| **Facility establishing** | [ITER central building construction (41767823552).jpg](https://commons.wikimedia.org/wiki/File:ITER_central_building_construction_(41767823552).jpg). ORNL via Flickr, CC BY 2.0 *(verify)* | A circular pit inside a massive enclosure; human scale; ring galleries |
| | [CERN ATLAS Detector.jpg](https://commons.wikimedia.org/wiki/File:CERN_ATLAS_Detector.jpg). Simon Waldherr, 2019, CC BY-SA 4.0 | A cavern that wraps the machine |
| **Reactor** | [CERN Atlas Caverne.jpg](https://commons.wikimedia.org/wiki/File:CERN_Atlas_Caverne.jpg). Nikolai Schwerg, 2004, GFDL *(verify)* | Radial coils around a core; heavy cradle; scaffold galleries |
| | [CERN-20060225-12.jpg](https://commons.wikimedia.org/wiki/File:CERN-20060225-12.jpg). Fanny Schertzer, 2006 *(verify)* | Ring silhouettes; access platforms at several heights |
| | [ITER Tokamak and Plant Systems (2016)](https://commons.wikimedia.org/wiki/File:ITER_Tokamak_and_Plant_Systems_(2016)_(41783636452).jpg). ITER *(verify)* | Layered "reactor complex" massing |
| **Industrial** | [Völklingen Ironworks (20849731019).jpg](https://commons.wikimedia.org/wiki/File:V%C3%B6lklingen_Ironworks_(20849731019).jpg). Via Flickr, CC BY 2.0 | Dense steel frames, ducts, depth |
| | [Gantry Crane 1.jpg](https://commons.wikimedia.org/wiki/File:Gantry_Crane_1.jpg). Homestead Steel Works *(verify)* | Crane gantry over a work floor |
| **Archive interiors** | [Cern datacenter.jpg](https://commons.wikimedia.org/wiki/File:Cern_datacenter.jpg) *(verify)* | Long rack aisles; overhead trays |
| | [Datacenter Server Racks (22370909788).jpg](https://commons.wikimedia.org/wiki/File:Datacenter_Server_Racks_(22370909788).jpg). Carl Lender *(verify)* | Rack rhythm with small indicator lights |
| | [Category:Data centers](https://commons.wikimedia.org/wiki/Category:Data_centers) | Canyon proportions, ceiling services |
| **Elevated platforms and supports** | [Observing Platform VLT.jpg](https://commons.wikimedia.org/wiki/File:Observing_Platform_VLT.jpg). ESO *(verify)* | Instrument buildings on a raised platform |
| | [Category:Gantries](https://commons.wikimedia.org/wiki/Category:Gantries), [Category:Launching gantry](https://commons.wikimedia.org/wiki/Category:Launching_gantry) | Lattice towers carrying decks |
| **Coolant and atmosphere** | [Pumpspeicherwerk Glems Turbinenhalle 2012.JPG](https://commons.wikimedia.org/wiki/File:Pumpspeicherwerk_Glems_Turbinenhalle_2012.JPG). Felix König *(verify)* | Pump and turbine hall under a crane rail |
| | [Turbine hall at Parker Dam 1973.jpg](https://commons.wikimedia.org/wiki/File:Turbine_hall_at_Parker_Dam_1973.jpg). CC BY-SA 3.0 | Rhythmic heavy casings |
| | [Towers over cooling pipes, Sizewell A](https://commons.wikimedia.org/wiki/File:Towers_over_cooling_pipes,_Sizewell_A_Power_Station_-_geograph.org.uk_-_2576289.jpg). John Goldsmith, CC BY-SA 2.0 | Giant ground-level pipe runs |
| | [Inside cooling tower.jpg](https://commons.wikimedia.org/wiki/File:Inside_cooling_tower.jpg). Jan Beránek, CC BY-SA 4.0 | Hyperboloid shell, mist, scale |
| | [Doel Nuclear power plant and cooling tower.jpg](https://commons.wikimedia.org/wiki/File:Doel_Nuclear_power_plant_and_cooling_tower.jpg). Sally V, CC BY-SA 4.0 | Cooling tower beside a containment dome |

Our own map is shown in the §1 ground set and in the [`phase8a1/`](phase8a1) overhead set.

---

## 3. District specifications

Each district gets its own `Map.Architecture.<District>` folder with sub-assembly Models (§9.2).
- Heights are absolute Y; T0 is Y 0.
- Tiers are unchanged: T1 24, T2 48, T3 72, basin −10.
- Part estimates for each district are in §9.1.

### 3.1 Central Core — "Containment Pit"
- **Signature:** the reactor complex (§4).
- **L1:**
  - radial plaza inlays (8) and an edge kerb;
  - glass mezzanine balustrades with a cyan cap rail;
  - the four gantries become truss tubes (ribs every 12, glass sides, open ends);
  - a colonnade along the plaza edge carrying a ring canopy at Y 60. The canopy is open over the reactor and over every bounce pad's apex column below Y 40.
- **L2:**
  - the plaza becomes the lid of a radius-110 **containment pit**: walls down to Y −90, with two ring galleries at −30 and −60 and light pools;
  - eight radial girders under the mezzanine.

### 3.2 Research Yard — "Test Hangar"
- **Signature:**
  - an open-sided **test hangar** of four trussed portal frames (64 wide, top Y 50) with a skylight roof over the DecayTile grid only;
  - a **gantry crane** on rails at Y 40, parked clear of the apex columns.
- **L1:** the two test chambers become lab pods (door frames, roof slabs, observation windows, instrument masts).
- **L2:**
  - substructure girders under the yard plate;
  - a silo cluster at the west rim, outside the bounds.
- **Identity:** violet experiment lights, cool white lab panels, steel truss.

### 3.3 Skybridge — "Elevated Control Facility"
- **Signature:**
  - two lattice **command spires** standing on the deck, tops at **Y 110 and Y 92**;
  - a glass **control room** on part of the SkyDeck, with open sides facing play.
- **Suspension:**
  - Beams (not parts) act as cables from the spires to the T3 relay pods, so the pods read as hung;
  - the floating stepping blocks get hanger rods to an overhead truss at Y 120, so nothing floats unsupported.
- **L2:** lattice pylons from the deck down to −90, a counterweight under the deck, and thruster nacelles under the pods.
- **Identity:** silver-grey metal, glass, violet beacons.

### 3.4 Data Archive — "Server Canyons"
- **Signature:** a vaulted hall (walls to Y 70, ribbed roof) over the rack canyons, with an **open oculus** that keeps the SUP_ARCHIVE drop column clear to Y 160.
- **L1:**
  - the solid cyan rack faces are replaced by recessed **rack-face panels**: one panel per 24-stud run, with 3 small indicator lights;
  - cable trays at Y 34 or higher.
- **L2:** non-walkable cooling stacks rising from the racks to the roof.
- **Identity:** cyan data light on dark metal; the darkest and most enclosed district.

### 3.5 Coolant Reservoir — "Pump Station"
- **Signature:**
  - two **hyperboloid cooling towers** rising from the deep shaft, at (±150, ·, 298), radius 20, base Y −90, top Y 70. They stand outside the flood volumes and outside `ArenaBounds`. They are seen from the Reservoir, and from the lobby when looking down to either side (§5.2);
  - a **pump hall** on the east rim: open front, three turbine casings, crane rail.
- **L1:** pump columns get flanges, valves and gauges; rim walkways get rails; the basin keeps an open sky for FLOOD.
- **L2:** pipe runs from the basin to the pump hall and down into the substructure; decorative intake grates.

### 3.6 Outer Ring — "Transit Ring"
- A box-girder underside (8 long girder parts).
- Pylons about every 60 studs down to −90.
- Signal arches at the five district entries.
- Long single-part rails with gaps at drop-down points.

---

## 4. Reactor redesign — "Simulation Core"

Goal: the dominant landmark. It is the **tallest element inside the hall wall line** and the brightest element under BLACKOUT.

| Part | Spec |
|---|---|
| Height | Pit floor at Y −90; crown top at Y **190** (now about 146). The hall wall top is Y 180 and the spire tops are Y 110 or lower, so only the ceiling ribs and hub (Y 180–240) are higher, and they are enclosure, not skyline |
| Cradle | 8 heavy ribs around the existing drum, from Y −90 to 20. The drum's collision and the plaza's walkable area are unchanged |
| Coil rings | Three tapering rings at Y 50, 95 and 140 (Ø 48, 40, 32). 16 segment parts each (or F1 meshes). Violet only on the inner face |
| Containment column | A Glass cylinder Ø 18 from Y 20 to 170, with a cyan Neon core Ø 6. Brightest element |
| Buttresses | 4 lattice buttresses from the pit rim (radius 60) to Y 95 |
| Galleries | 2 decorative ring catwalks at Y 60 and 120 |
| Crown | 8 fins plus a ring, Y 170–190, and a cyan Beam to the ceiling hub (Y 240) |
| Lights | 7. The core PointLight is the only one casting shadows |
| Collision | Everything above the plaza is non-collidable. Nothing enters a bounce apex column or the stabilizer radius |
| Parts | About 110 for the reactor itself, plus about 73 for the pit (§9.1) |

---

## 5. Megastructure — "Terraced Containment Hall"

### 5.1 Hall

The revision replaces the flat ±300 wall, which would have felt cramped from the ring: about 63° wall elevation at G6.

| Element | Spec |
|---|---|
| **Terrace plinth** (inner) | A ring at ±320, Y −90 → **60**: a massive wall with a coping. The terrace deck between ±320 and ±400 is at Y 60 |
| **Terrace machinery** | 12 machinery towers on the terrace (3 variants, tops Y 110–150), with pipe bridges between them. They give depth between the arena and the upper wall |
| **Upper hall wall** | A ring at ±400, Y 60 → **180**. 64-wide slabs with a pilaster at every other joint and a cyan seam on every 4th pilaster. A violet band at Y 120. 8 **deep windows** looking out to far silhouettes. Chamfered corner towers |
| **Ceiling ribs** | 8 radial box ribs from the wall tops (Y 180, r 400) to a hub ring at Y **240** (r 30) over the reactor. At any supply landing point (r ≤ 260) a rib is at Y 200 or higher, well above the Y 160 drop clearance |
| **Far silhouettes** | 8 low-detail towers seen through the deep windows, at 440–520 |
| **Shaft floor** | Y −90, dark Slate with a faint cyan grid, non-collidable. The −60 kill plane is unchanged |
| **Wall elevation from the reference cameras** | Computed to the nearest wall; plinth top / upper wall top. **Interior cameras:** G1 14°/31°; G3 17°/34°; G4 18°/35°; G5 3°/32°. **Edge cameras:** G6 18°/41°; G2 32°/47°. For comparison, a flat ±300 wall to Y 200 would put G6 at 63°. The terrace splits the height into two readable steps, and the open haze between the ribs keeps the upper frame open |

### 5.2 Lobby observation bay

The lobby stays exactly as it is:
- position (0,160,410), a 48×48 floor at Y 156–160, 4 walls and trims, `LobbySpawn_1–4`;
- outside `ArenaBounds`;
- lobby behaviour unchanged.

Design:
- **Placement:** the south upper wall at z = 400 passes through the lobby footprint (z 396–444). The wall gets an **observation notch** at x −40 … 40, from Y 140 up to its top (180). The lobby sits in the notch as a glazed observation station; its north wall at z 396 is flush with the hall interior.
- **Window:** `Lobby.Wall_N` changes from opaque to **Glass**: Transparency 0.55, a light cyan tint, and the same size, CFrame and `CanCollide`. This is the only change to an existing lobby part. It is a property change, not a behaviour change. No code references lobby walls; only the `LobbySpawn` tag is used.
- **Framing (decorative):**
  - bay cheeks either side;
  - a canopy at Y 186;
  - two mullions;
  - a cyan sill line;
  - an "OBSERVATION 01" signage strip on the hall-facing side;
  - two cantilever brackets under the pod down to the terrace deck (Y 60), so the station is visibly supported.
- **Sightlines** (eye at the lobby centre, (0,164,420); floor top Y 160 plus 4.5):
  - to the reactor crown (Y 190) the line crosses the wall plane (z 400) at about Y 165, inside the notch (Y 140–180);
  - to the mid-coil (Y 95) the line is at about Y 111 above the Core canopy edge (r ≈ 100, Y 60), about 50 studs clear;
  - to the reactor base (Y 0) the line is at about Y 125 over the terrace (z 320, Y 60);
  - the coolant structures (Y 70 or lower) are below every line.
- **Composition:**
  - The lobby's own floor edge (z 396, Y 160) hides views steeper than about 9.5° from the lobby centre.
  - From anywhere in the lobby, players see the crown, the upper column, the Y 140 coil, the Y 95 coil just above the floor line, the ribs and hub, the far hall walls, the terraces and the Skybridge spire tops.
  - At the glass, the plaza, Reservoir, Yard and Archive floors come into view.
  - The cooling towers (x ±150, top Y 70) are outside the straight-ahead frame. They are seen when looking left or right and down.
  - The lobby floor is not changed.
- **Lights:** 2 soft interior lights (no shadows). Lobby colours stay neutral so the facility is the focus.
- **Streaming:** the lobby is the replication focus during LOBBY. The whole arena is within 740 studs, inside the current target radius of 1024, so the reactor and hall are streamed in for lobby players on desktop. This is checked in AC2.

Sketches: [`phase8a2/lobby_observation_after.svg`](phase8a2/lobby_observation_after.svg) and the section [`phase8a2_elevation.svg`](phase8a2_elevation.svg).

---

## 6. Modular kit and reuse plan

The templates live in `ServerStorage.WORLD_EXE_ArchitectureKit`, and the builder clones them. The revised kit **uses larger single pieces**: one long part per rail run, girder or pipe run, instead of 12- or 24-stud modules, to keep part counts honest.

| ID | Module | Size | Parts / instance | Instances | Parts |
|---|---|---|---|---|---|
| K1 | Heavy column plus footing (3 sizes: 6, 8, 12 square) | full height, one part | 2 | 60 | 120 |
| K2 | Box girder or brace (one part, cut to span) | 4×6 × span | 1 | 100 | 100 |
| K3 | Hall wall slab (64 wide) | 64 × 120 (upper) / 64 × 150 (plinth) | 1 | 90 | 90 |
| K3p | Pilaster (+ seam on every 4th) | 8 wide | 1–2 | 52 | 65 |
| K4 | Rail run (one part per straight run) | run length × 3 | 1 | 50 | 50 |
| K5 | Pipe run (one cylinder per run) plus elbow (3 parts, or F3) | Ø 4–8 | 1 / 3 | 20 + 8 | 44 |
| K6 | Rack-face panel plus 3 indicator lights | 24 × 20 | 4 | 16 | 64 |
| K7 | Portal frame (hangar) | 64 × 50 | 7 | 4 | 28 |
| K8 | Light fixture (where no host part exists) | 2×2×1 | 1 | 30 | 30 |
| K9 | Machinery tower (3 variants) | 40×40 × 50–90 | 8 | 12 | 96 |
| K10 | Coil-ring segment (or F1) | arc 10×6×8 | 1 | 48 | 48 |
| K11 | Signal arch | 24 × 20 | 5 | 5 | 25 |
| K12 | Pipe-rack bent | 16 × 20 | 3 | 6 | 18 |
| | **Kit total** | | | | **778** |

The remaining new parts are unique compositions (the reactor, pit, signature buildings, lobby bay and shaft grid). They are counted per district in §9.1.

**Avoiding repetition and "identical pillars"**
- Columns come in 3 sizes, are paired with girders or bracing, and never sit on a uniform grid.
- No more than 6 identical columns are visible in a row from any G-camera.
- Every 4th pilaster has a seam.
- Rack panels have 4 indicator patterns.
- Towers have 3 variants, rotated.
- Landmarks are unique.

**No empty interiors:** every roofed or enclosed space gets at least one of equipment, overhead services, or a light pool.

---

## 7. ForgeGUI recommendation (and Figma)

**Discovery (read-only, 2026-11-11)**
- Capabilities:
  - GLB model prepare (at most 1M triangles);
  - tiled PBR textures (at most 2048);
  - equirectangular skybox (512/1024);
  - Roblox publishing only through the `@amfam1` api_key connection.
- OAuth publishing and mesh-UV texturing are unavailable.
- No projects; one unrelated style.
- **Credit balance and pricing are not available through any tool.** The owner checks them on the website.
- GLB import into Studio has not been verified.

**Recommendation: parts-first.** The entire design, and the budget in §9.1, are built from parts. Generated assets are optional, separately gated upgrades.

| ID | Candidate | Purpose and size | Why not parts | Format | Cost | Privacy and publishing |
|---|---|---|---|---|---|---|
| F1 | Coil-ring segment mesh | Reactor rings; a 1/8 arc about 20×8×12, ×24 | A smooth torus would need about 64 faceted parts per ring | GLB → `prepare.model.glb`, ≤ 5k tris, `delivery: direct` | Unknown via tools | Text prompt only. Reviewed locally. No upload or publish without approval |
| F2 | Hyperboloid tower shell | 2 cooling towers plus 4 terrace or far variants; Ø 40 × 160 | A doubly curved shell is impossible with parts | GLB, ≤ 4k tris | Unknown | Same |
| F3 | Pipe fittings | Elbow, T-junction, valve wheel | Part elbows show seams | GLB, ≤ 1.5k tris | Unknown | Same |
| F4 | Panel-metal PBR set | Hall slabs, at 1024 | Repetition across 400-stud walls | `prepare.texture.tiled` | Unknown | Same |
| F5 (optional) | Night skybox | Far depth above the wall line | Lighting alone may be enough | Equirectangular, 1024 | Unknown | Same |

**F1/F2 experiment (stage 8A-2d, separately gated):**
- one generation each, direct delivery;
- a local import test and a side-by-side comparison with the parts version;
- **only** after the 8A-2a review, with explicit approval and a budget the owner sets after checking the balance on the website;
- no publish without a further approval, and `docs/ASSET_MANIFEST.md` comes first.

**Figma:**
- Connected by the owner for future design-system work: UI, branding, thumbnails and a reference-board layout.
- It is **not** used for architecture, which is built in Studio.
- No 8A-2 work depends on it, and nothing has been uploaded to it.

---

## 8. Lighting, atmosphere and materials

| Setting | Proposal (decision A2) |
|---|---|
| Time | `ClockTime` about 0.5; sun and moon minimised |
| Ambient | `Ambient` #1A2240, `OutdoorAmbient` #2A3460, `Brightness` 2, `EnvironmentDiffuseScale` 0.4, `EnvironmentSpecularScale` 0.6 |
| Atmosphere | Density 0.35, Offset 0.1, Color #26345E, Decay #0A0F1F, Glare 0.2, Haze 1.5 (tuned in 8A-2a against the openness criterion) |
| ColorCorrection | Contrast 0.15, Saturation −0.05, Tint #E6ECFF |
| Bloom | Intensity 0.6, Size 24, Threshold 1.6 |
| SunRays / DepthOfField | Off |
| Light pools | Stabilizers green (objective); district signatures in their accent colours; lobby neutral |
| BLACKOUT | The baseline is captured at start and restored exactly. Minimum Brightness ≥ 0.5 is kept |

**Palette**
- **Structure:** navy and charcoal (#0A0F1F, #141C3C, #1F2C5C, #26345E), with **value variation per material**, so no surface is featureless dark: concrete is lighter, metal is mid, slate is darkest.
- **Cyan:** system.
- **Violet:** simulation energy.
- **Reserved:** amber for warnings, green for objectives, red/coral for danger.

**Neon**
- Strips no wider than 1 stud on **walkable edges and landmarks only**; there are no outlines on decorative structure.
- Allowed elsewhere only on the reactor core and on indicator lights.
- No neon panel larger than 4×4.

**Materials:** Metal, DiamondPlate, Concrete, Slate, Glass, SmoothPlastic, and Neon (trims only).

---

## 9. Performance

### 9.1 Reconciled part budget

These are estimates from the kit (§6) plus the unique compositions. The provisional limits are **ceilings, not targets**.

| Area (layer) | Main contents | Est. new parts | Cap | New collidable | Lights (shadow) |
|---|---|---|---|---|---|
| Existing 8A-1 map (L1, gameplay-critical) | Floors, ramps, markers, props | 522 (existing) | 522 | 262 (existing) | 0 |
| Megastructure (L3) | Upper wall 50 slabs + 26 pilasters + 7 seams + band 4 + corners 12 + deep windows 16 (115); plinth 40 + coping 4 (44); ribs 48 + hub 12 (60); terrace towers 96 + pipe bridges 8 (104); far silhouettes 16; shaft floor and grid 27 | 366 | 420 | 0 | 8 wall-wash (0) |
| Lobby observation bay (L3) | Cheeks 4, canopy 2, mullions 2, sill 1, sign 2, brackets 4. `Wall_N` changes to Glass (0 new) | 15 | 30 | 0 | 2 (0) |
| Shared supports (L2) | 60 columns × 2 (120); 60 girders; 40 braces | 220 | 250 | 0 | 0 |
| Central Core (L1+L2) | Reactor about 110; pit 24 walls + 2 × 24 gallery + floor (73); canopy 20 + colonnade 16; gantry tubes 4 × 10; balustrades 16; inlays 8; radial girders 8 | 291 | 320 | 28 | 11 (1) |
| Research Yard | Portal frames 28; roof 14; crane 7; lab pods 20; masts 8; silos 12; side panels 8 | 97 | 120 | 24 | 6 (1) |
| Skybridge | Spires 24; control room 15; cable anchors 8 (cables are Beams); hanger rods and truss 12; antennae 8; thrusters 6; counterweight 2 | 75 | 100 | 20 | 5 (1) |
| Data Archive | Vault walls 24; slot recesses 16; roof ribs and panels 19; oculus ring 8; rack-face panels 64; trays 8; stacks 8; grilles 6 | 153 | 170 | 24 | 8 (1) |
| Coolant Reservoir | Cooling towers 12 (or 2 F2 meshes); pump hall 21; pump dressing 12; pipe runs and elbows 44; bents 18; rails 12; grates 4 | 123 | 140 | 18 | 6 (1) |
| Outer Ring | Girders 8; pylons 32; arches 25; rails 32; fixtures 8 | 105 | 120 | 42 | 5 (0) |
| EnvFX hook extras (§12) | Debris clusters, scan-beam emitters, patch lights (normally off) | 40 | 60 | 0 | 4 (0) |
| **Total** | | **522 + 1,485 = 2,007** | **2,252** | **262 + 156 = 418** | **55 (5)** |
| **Ceiling** | | | **4,000** | **900** | **80 (12)** |

**Gameplay-critical vs decorative**
- **Gameplay-critical (collidable):**
  - the existing 522 parts, of which 262 are collidable and all markers;
  - 156 new collidable parts: rails, kerbs, colonnade, portal legs and lab-pod walls on walkable floors, spire legs and control-room glass on the deck, archive vault walls, and pump-hall legs.
- **Decorative:** everything else, about 1,329 parts, with `CanCollide`, `CanQuery`, `CanTouch` false and `CastShadow` false (except ribs, walls and the reactor).
- Supports below T0 are decorative so falling players never snag on them.
- Beams (not parts): about 8 (reactor beam, Skybridge cables, scan beam).
- Emitters: at most 2 per district.

The ~1,750 parts of headroom below the ceiling are **not** to be spent. Any stage exceeding its row cap stops for review.

### 9.2 Streaming plan

The existing configuration stays: StreamingEnabled on, target radius 1024 (measured 2026-11-11). Changes happen only if the measurements justify them.

| Group | `ModelStreamingMode` | Why |
|---|---|---|
| `Megastructure.Silhouette`: upper wall slabs, plinth, ribs, hub, corner towers, the reactor column and crown (about 150 large parts) | **Persistent** | Must never pop: it defines the enclosure and the landmark from every viewpoint, including the lobby |
| `Megastructure.Detail`: pilasters, seams, terrace towers, pipe bridges, far silhouettes, shaft grid | Default | Normal streaming; at desktop radius it is all within range |
| `Architecture.<District>.<Assembly>` (hangar, crane, vault, pump hall, spires, gantry tubes, pit galleries, coil rings …) | **Atomic** per assembly | Streams as a whole: no half-built machines |
| Small dressing (rails, inlays, rack panels) | Default, grouped by district | — |

Notes:
- A Persistent model is sent to all clients and never streamed out. Keeping it to about 150 large parts bounds the cost.
- `Model.LevelOfDetail` (StreamingMesh imposters) is **not relied on**. It only applies in published experiences and cannot be verified in Studio.

### 9.3 Foreground FPS benchmark (exact, repeatable)

Scripts:
- `tools/studio/phase8a2_fps_benchmark_client.luau`: injected into the Play **Client** datamodel.
- `tools/studio/phase8a2_fps_benchmark_server.luau`: injected into the Play **Server** datamodel; needed for pass B only.

**Owner action (the only manual part):**
1. In Studio, open `Place1.rbxl`. Close other heavy applications.
2. Maximise Studio on the primary monitor.
3. When Claude says "benchmark starting", **click inside the 3D viewport once, then do not touch the mouse or keyboard or switch windows for about 70 seconds** (pass A), and again for pass B.
4. Note the Studio frame-rate cap setting if you know it. It is not changed.

**Procedure**
1. Claude starts Play (solo).
2. Pass A (visual load) runs on the client:
   - 3 s warm-up;
   - then a fixed **camera script** (Scriptable camera, FOV 70) holds 5 s at each of G1–G6 and 4 spawn views (0,5,147), (−245,5,70), (175,53,20) and (0,5,−250);
   - then a 10 s orbit at radius 330, Y 120 around the reactor;
   - frames during the first 0.5 s after each cut are excluded (streaming and settle).
3. Pass B (server load):
   - the server script requests 3 patches (ZERO_G, CORRUPTION, FLOOD) through the existing `PatchService.Request` path, used as in the 8A-1 tests;
   - it samples Heartbeat for 30 s;
   - the client repeats the orbit.
4. **Metrics:**
   - client: average FPS, 1% low FPS (the average of the worst 1% of frame times, inverted), median and p99 frame time (ms), `Stats:GetTotalMemoryUsageMb()` at the start and end, and viewport size;
   - server: average and p99 Heartbeat step (ms).
5. **Validity guard:** the client records `UserInputService.WindowFocused` and `WindowFocusReleased` events. A run is **invalid** if focus was lost at any time, or if the average FPS is within ±1 of 15 (the background throttle). Invalid runs are reported as invalid and never used.
6. The results are written to attributes and read back through MCP. Nothing is persisted.

The same script runs at baseline (before 8A-2a), after 8A-2a and after 8A-2b.

**Targets:**
- After 8A-2: average FPS ≥ 85% of the baseline, and 1% low ≥ 45 on the same desktop.
- If the cap pins the average at 60, the 1% low and p99 frame time are the deciding figures.
- Server Heartbeat p99 within 10% of the baseline.

Mobile and device testing remain release-milestone items.

---

## 10. Staged implementation and validation (after approval)

All construction goes through `tools/studio/phase8a2_architecture.luau`.
- It is reproducible from the post-8A-1 place.
- It has per-stage entry points.
- It enforces the §13 checks, aborting and restoring on any failure.
- It audits the budget against §9.1 caps and stops if a cap is exceeded.
- It sets ArenaVersion 3.

| Stage | Contents | Validation (each stage stops for review) |
|---|---|---|
| **0 Baseline** | §9.3 benchmark on the 8A-1 map; owner focus needed | Valid pass A and pass B figures in the PR |
| **8A-2a** | Containment hall (Silhouette and Detail), lobby observation bay, Lighting preset, reactor complex, Central Core transformation (pit, canopy, gantry tubes, supports) | §13 checks; budget audit; AC1–AC3, AC6, AC10 for the Core and hall; G1–G6 and lobby screenshots; benchmark rerun |
| **8A-2b** | Yard, Skybridge, Archive, Coolant, Ring and their supports | §13; budget; AC1–AC8; targeted regression (validators, traversal spot-checks, one patch of each kind, 5 combinations, two-match cleanup); benchmark |
| **8A-2c** | `EnvironmentResponseClient` plus hooks (§12) | AC9; streaming-in test; 0 warnings; parity |
| **8A-2d** (optional) | ForgeGUI F1/F2 experiment, only with separate approval and a budget | Import test, triangle and FPS check; no publish |

Each stage follows the existing protocol:
- commits on the branch;
- parity between `src/` and Studio;
- the owner saves with Ctrl+S, and the save is verified from the file;
- a backup;
- a PR comment.

Multiplayer validation stays deferred to the pre-release milestone.

---

## 11. Before/after acceptance criteria

Raycasts are not used for landmark visibility, because decorative geometry has `CanQuery` off and physics queries ignore it.

| # | Criterion | Method |
|---|---|---|
| AC1 | **No default sky or grey void, and not cramped.** No default sky, sun or void is visible from G1–G6, the lobby, or the overhead set. Upper-wall elevation to the nearest wall is ≤ 35° from the interior cameras (G1, G3, G4, G5) and ≤ 47° from the edge cameras (G2, G6), with values as computed in §5.1. Navy haze between the ribs is visible in the top of every G-frame. Openness is confirmed by owner/ChatGPT review of the G-set; if a view reads as cramped, the fix is a deep window or a lower plinth in that sector, not moving gameplay | Fixed-camera screenshots before and after (the same camera CFrames as §1), plus the builder's elevation-angle audit |
| AC2 | **The reactor is recognizable from all 16 spawns and the lobby.** At least 30% of 40 sample points on the reactor (core column 16, coils 12, crown 12) are unoccluded, including at least 1 crown point and at least 4 column points | **Analytic occlusion test:** a Luau segment-versus-box test (slab method) against *every* BasePart in Map, Architecture, Megastructure and Lobby, whatever `CanQuery` says, with cylinders and wedges treated as their bounding boxes (conservative). Eye at spawn + (0,5,0); run in chunks in Edit. **Plus** screenshots: the actual player camera (Play, character at the spawn, default follow camera turned toward the reactor) for a sample of 6 spawns, and Edit-camera captures for all 16 |
| AC3 | **The Central Core dominates the skyline.** The crown (Y 190) is the highest element inside the wall line; no spire, tower or cooling tower is above Y 150; in G1–G6 and the lobby view the reactor is the brightest emissive element | Builder height audit plus screenshot review |
| AC4 | Each district identifiable from one ground screenshot | Owner/ChatGPT blind review of the G-set |
| AC5 | At least one enclosed or roofed, furnished space per district | Checklist and screenshots |
| AC6 | Visual rules: no neon outlines on decorative structure; no neon panel over 4×4; reserved colours only for their uses; no more than 6 identical columns in a row from any G-camera; every slab supported within 30 of each edge midpoint (span ≤ 60) | Builder audit over `Map.Architecture` and `Megastructure` |
| AC7 | Gameplay unchanged: 8A-1 validators pass; marker counts unchanged; drop columns clear to 160; bounce apex columns clear to 40; zero-G gaps open; crate lanes clear; flood volumes clear; lobby spawns and teleport unchanged | §13 checks plus the 8A-2b regression |
| AC8 | Performance: §9.1 caps; §9.3 targets from **valid** foreground runs | Budget audit plus benchmark |
| AC9 | Patch responses: all 10 patches and 5 combinations show their response and fully revert at end or RESET, **including for hook parts that stream in after activation** | 8A-2c test, which includes re-parenting a hook assembly mid-patch to simulate stream-in |
| AC10 | BLACKOUT readability: walkable edges and stabilizers stay readable; the reactor remains the anchor | Screenshots at G1, G3, G6 and the lobby under BLACKOUT |

---

## 12. Patch-responsive environment (no gameplay change)

**`EnvironmentResponseClient` requirements (stage 8A-2c)**
- **Input:** only the existing replicated `MatchState.Snapshot` attribute (`Patches`, `Interactions`) via `GetAttributeChangedSignal`. **No new remotes, no server code changes**, nothing server-authoritative touched.
- **Event-driven:** it recomputes the desired visual state only when the Snapshot version changes. There are **no per-frame updates** (no RenderStepped or Heartbeat loops). Any flicker states use a few pre-built alternate states toggled on the Snapshot change; animated motion is Phase 8B.
- **Streaming-safe:**
  - hooks are found through `CollectionService` tags (`EnvFX_<ID>`);
  - `GetInstanceAddedSignal` applies the *current* desired state to hook parts that stream in after a patch started;
  - `GetInstanceRemovedSignal` drops references.
- **Exact restore:**
  - each hook stores its original visual properties in attributes written by the builder (`Base_Color`, `Base_Transparency`, `Base_LightEnabled` …);
  - restore reads those attributes, never cached client values, so restoring is correct even after streaming out and back in;
  - at RESET, or when no patches are active, everything returns to its base state.
- **Scope:** decorative properties only (Color, Transparency, Material swap between two allowed materials, Light/Beam `Enabled`, emitter `Rate`). It never changes CanCollide, CanQuery, CanTouch, size or position.

| Patch / combination | Response | Where |
|---|---|---|
| ZERO_G | Coil rings switch to bright violet; pilaster "field" strips light violet; static dust motes | Reactor, hall |
| DECAY | Hangar skylight panels switch to the dark glitch pattern; grid inlays turn violet | Research Yard |
| DRONE_SWARM | Drone-bay beacons on the spires turn coral (danger) | Skybridge |
| SUPPLY_DROP | The hub ring and archive oculus light cyan | Ceiling, Archive |
| BOUNCY | Pad-surround rings brighten | Pads |
| SLIPPERY | Pipe and rail trims switch to icy pale-cyan Glass | Reservoir, Ring |
| BLACKOUT | Hall seams switch off by sector; the reactor core stays on | Hall |
| MAGNETIC | Overhead archive coils glow violet | Archive |
| CORRUPTION | Wall slabs nearest the active nodes show violet glitch bands | Hall |
| FLOOD | Pump casings and intake grates turn teal; mist rate rises | Reservoir |
| SUPER_BOUNCE | Coils and pad rings at maximum violet | Reactor, pads |
| HUNTER_SCAN | Static scan beam from the spires turns on (a sweep comes in 8B) | Skybridge |
| FLOATING_DEBRIS | Decorative debris above the basin becomes visible | Reservoir |
| RAPID_DECAY | Hangar roof dark; crane warning beacon amber | Research Yard |
| SLIDE_FIELD | Icy trims plus a violet floor-band shimmer (a static alternate state) | Reservoir, Ring |

---

## 13. Gameplay safety rules (builder-enforced)

| Constraint | Check |
|---|---|
| Walkable routes | New collidable parts may not overlap walkable surfaces, ramps, or a 6-stud headroom envelope (rails at edges only, with gaps at drop-downs and zero-G gaps) |
| Supply drops | All 8 drop columns clear to Y 160; ribs ≥ Y 200 above any landing point |
| Drones | All 30 waypoint links keep line of sight |
| Bounce | Nothing collidable above any pad below Y 40 |
| ZERO_G | Both 14-stud gaps open |
| MAGNETIC | 8 crate lanes clear (box sweep) |
| FLOOD | No new collidable parts in flood volumes |
| Spawns and stabilizers | Unchanged safety and headroom; interaction radius clear |
| Lobby | Only `Wall_N` changes, and only in visual properties (Material, Transparency, Color). Size, CFrame, `CanCollide` and the spawns are unchanged |
| Raycasts | Decor has `CanQuery` off: DASH, SCANNER and drone line of sight are unaffected |

---

## 14. Decisions

| # | Decision | Recommendation |
|---|---|---|
| A1 | Megastructure | Terraced hall: plinth ±320 to Y 60, upper wall ±400 to Y 180, ribs to a hub at Y 240, shaft floor at Y −90 |
| A2 | Lighting baseline | Night/navy preset (§8) |
| A3 | Railings | Low, jumpable, long single-part runs with gaps at drop-downs |
| A4 | Concepts | Districts as in §3; reactor as in §4 |
| A5 | Budget | §9.1 row caps (2,252 total), inside the 4,000 / 900 / 80 / 12 ceilings |
| A6 | Staging | One branch: 0 → 8A-2a → 8A-2b → 8A-2c, a review stop at each; 8A-2d optional |
| A7 | FPS procedure | §9.3; the owner focuses Studio for about 70 s per pass |
| A8 | ForgeGUI | Parts-first; the F1/F2 experiment is separately gated |
| A9 | Patch responder | Client-only and event-driven (§12) |
| A10 | Lobby | Observation notch plus glazed `Wall_N` (§5.2) |
| A11 | Streaming | Persistent silhouette only; Atomic assemblies; radius unchanged (§9.2) |

## 15. Decision summary: ready for owner approval

**Ready now (design approval):** A1–A11 as a package. Nothing is implemented until the owner approves.

**Next milestone, with explicit approval (not started):** stage 0 (FPS baseline), then **8A-2a**: Containment Hall, Central Reactor and the Central Core architectural transformation, including the lobby observation bay and lighting preset.

**Needs owner action:**
- about 2 × 70 s of focused Studio for the baseline benchmark (§9.3), which can run any time before 8A-2a;
- later, a credit check on the ForgeGUI website only if the 8A-2d experiment is wanted.

**Not requested:** publishing, ForgeGUI spending, uploads, persistence, paid automation, Figma work.

## 16. Sketch verification and dimension reconciliation

**Verification**
- All SVGs were XML-validated.
- Each was rendered locally to PNG with headless Microsoft Edge and inspected visually.
- The PNGs were not committed.

**Dimension reconciliation**
- **The elevation is redrawn to scale** (north–south section, 1 px = 1 stud horizontally, vertical ×1.4). It shows the walls at 180, plinth 60, crown 190, coils at 50/95/140, ribs and hub at 180–240, Archive vault 70, cooling towers at Y −90 → 70, the lobby at Y 156–165 in the notch, and the lobby sightline.
- **The perspective mockups are schematic.** They show relative massing, not exact dimensions. The establishing and core sketches show the terraced hall: a plinth band below a set-back upper wall.
- **Values changed from revision 1:**

| Item | Revision 1 | Now |
|---|---|---|
| Wall height | 200 | 180 |
| Wall position | ±300 | ±320 plinth / ±400 upper |
| Spire tops | "about 110 and 85" | Y 110 and 92 |
| Outer towers | 150–260 tall | Tops ≤ Y 150 |
| Cooling towers | 55–80 | Y −90 → 70 |
| Part budget | 3,500–4,000 | Reconciled to 2,007 estimated / 2,252 capped |
