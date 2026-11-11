# Phase 8A-2 — Creative direction and architectural design

Status: **planning only.** Nothing in Studio has been built or changed. Only camera positions were used, for screenshots. There has been no ForgeGUI generation or spending, no publishing and no uploads. Implementation needs separate approval after ChatGPT and owner review.

**Baseline**
- `main` `3ed5425` (Phase 8A-1 merged as `44e8f1d`).
- Rollback point: `WorldEXE_post-phase8a1_2026-11-10.rbxl` (SHA-256 `E0B955F4…14714745`).

**Sketches** (all are schematic mockups, not renders):
- [`phase8a2/establishing_after.svg`](phase8a2/establishing_after.svg): a perspective establishing shot of the proposed facility.
- [`phase8a2/ground_core_before_after.svg`](phase8a2/ground_core_before_after.svg): a ground-level view of Central Core, before and after.
- [`phase8a2/ground_districts_after.svg`](phase8a2/ground_districts_after.svg): ground-level views of Data Archive and Coolant Reservoir, after.
- [`phase8a2_elevation.svg`](phase8a2_elevation.svg): the skyline elevation (first draft).

**Contents**

| # | Deliverable | Section |
|---|---|---|
| 1 | Vision | §1 |
| 2 | Reference board | §2 |
| 3 | District specifications | §3 |
| 4 | Reactor redesign | §4 |
| 5 | Megastructure | §5 |
| 6 | Modular kit and reuse plan | §6 |
| 7 | ForgeGUI recommendation and budget | §7 |
| 8 | Lighting, atmosphere and materials | §8 |
| 9 | Performance plan | §9 |
| 10 | Staged implementation and validation | §10 |
| 11 | Before/after acceptance criteria | §11 |
| — | Patch-responsive environment | §12 |
| — | Gameplay safety rules | §13 |
| — | Decisions requested | §14 |

---

## 1. Vision

> **WORLD.EXE is fought inside the containment hall of a reality-simulation reactor.** It is a facility on the scale of a particle-physics cavern or a fusion-plant assembly hall. Every walkable floor is clearly *built*: held up by columns, trusses and machinery that run down into a deep substructure. The space is enclosed by a vast hall whose walls and ceiling ribs fade into navy haze. The reactor at the centre is the one thing you can always see. When the Architect patches the simulation, the building reacts.

**Three environmental layers**

| Layer | What it is | Collision | Where |
|---|---|---|---|
| **L1 Playable architecture** | The existing 8A-1 floors, ramps, bridges and markers. The only additions are dressing on these surfaces: balustrades, edge trims, door frames, roof slabs and inlays | As now; new rails only at edges, with gaps at drop-downs | Inside `ArenaBounds` (±275) |
| **L2 Structure and machinery** | Supports, trusses, substructure, district signature buildings, the reactor complex, pipes, server stacks and cranes | Decorative, except that columns are collidable where they stand on walkable floor outside routes | Inside and just below the arena, down to Y −90 |
| **L3 Megastructure** | Containment hall walls, ceiling ribs, distant machinery towers, the floor of the deep shaft, haze | None (all decorative) | Outside the bounds: ±300 to ±460, Y −90 to 240 |

**What the current map shows** (ground-level captures, 2026-11-11, Edit mode, camera only):

| Shot | Image | What it shows |
|---|---|---|
| G1 Core plaza | [g1_core_ground.jpg](phase8a2/g1_core_ground.jpg) | The reactor is a thin cylinder with three rings. A slab mezzanine sits on four legs. Blue daytime sky everywhere. |
| G2 Research Yard | [g2_yard_ground.jpg](phase8a2/g2_yard_ground.jpg) | A flat tile field, low blocks and empty horizon. No hangar or enclosure. |
| G3 Data Archive | [g3_archive_ground.jpg](phase8a2/g3_archive_ground.jpg) | Rack walls are flat cyan rectangles. Sky is visible straight through the "canyon". |
| G4 Coolant Reservoir | [g4_reservoir_ground.jpg](phase8a2/g4_reservoir_ground.jpg) | The basin and two plain pump cylinders. Bridges float with no visible support. |
| G5 Skybridge deck (T2) | [g5_skybridge_deck.jpg](phase8a2/g5_skybridge_deck.jpg) | A large empty deck. The horizon is a bare white haze line. |
| G6 Ring horizon (T1) | [g6_ring_horizon.jpg](phase8a2/g6_ring_horizon.jpg) | The clearest "floating platforms" problem: grey void under every slab, and floating stepping blocks. |

The overhead set from 8A-1 is in [`phase8a1/`](phase8a1).

**Diagnosis, carried over and confirmed by the ground shots**
1. Every surface is a thin slab with no mass.
2. Nothing visibly holds anything up.
3. The default daytime sky and the grey void surround the map.
4. There are no enclosed spaces.
5. All the districts look alike.
6. The reactor is a thin tube.
7. Lighting is flat, and neon is used uniformly.

---

## 2. Reference board

**Rules**
- Links only. No images were downloaded, copied into the repo, or uploaded anywhere, including ForgeGUI.
- All sources are Wikimedia Commons file or category pages.
- Licences are as stated on the page, or in search snippets where marked *(verify)*. Check each file page before any reuse beyond reference.
- These are mood and structure references for building in parts. Nothing is to be traced or reproduced.

| Theme | Reference (source, author/credit, licence) | What we take from it |
|---|---|---|
| **Facility establishing shot** | [ITER central building construction (41767823552).jpg](https://commons.wikimedia.org/wiki/File:ITER_central_building_construction_(41767823552).jpg). Oak Ridge National Laboratory via Flickr, CC BY 2.0 *(verify)* | A circular pit inside a massive concrete enclosure; tiny people for scale; ring galleries |
| | [CERN ATLAS Detector.jpg](https://commons.wikimedia.org/wiki/File:CERN_ATLAS_Detector.jpg). Simon Waldherr, 2019, 360° panorama, CC BY-SA 4.0 | A cavern that wraps the machine: walls and ceiling read as part of the facility |
| **Reactor / central machine** | [CERN Atlas Caverne.jpg](https://commons.wikimedia.org/wiki/File:CERN_Atlas_Caverne.jpg). Nikolai Schwerg, 2004, GFDL *(verify)* | Radial toroid coils around a core; heavy support cradle; scaffold galleries hugging the machine |
| | [CERN-20060225-12.jpg](https://commons.wikimedia.org/wiki/File:CERN-20060225-12.jpg). Fanny Schertzer, 2006 *(verify licence)* | Coil octagon and ring silhouettes; access platforms at several heights |
| | [ITER Tokamak and Plant Systems (2016)](https://commons.wikimedia.org/wiki/File:ITER_Tokamak_and_Plant_Systems_(2016)_(41783636452).jpg). ITER drawing *(verify)* | Toroidal vessel, cryostat ring and plant layered around it: the "reactor complex" massing |
| **Industrial structure (Research Yard)** | [Völklingen Ironworks (20849731019).jpg](https://commons.wikimedia.org/wiki/File:V%C3%B6lklingen_Ironworks_(20849731019).jpg). Via Flickr, CC BY 2.0 | Dense steel frames, stair towers, ducts, layered depth |
| | [Gantry Crane 1.jpg](https://commons.wikimedia.org/wiki/File:Gantry_Crane_1.jpg). Homestead Steel Works, uploader's own work *(verify licence)* | A crane gantry spanning a work floor: the hangar crane over the DecayTile grid |
| **Archive interiors** | [Cern datacenter.jpg](https://commons.wikimedia.org/wiki/File:Cern_datacenter.jpg). Wikimedia Commons *(verify)* | Long rack aisles; overhead cable trays; contained cold aisles |
| | [Datacenter Server Racks (22370909788).jpg](https://commons.wikimedia.org/wiki/File:Datacenter_Server_Racks_(22370909788).jpg). Carl Lender via Flickr *(verify licence)* | Rack-face rhythm and small indicator lights instead of solid neon panels |
| | [Category:Data centers](https://commons.wikimedia.org/wiki/Category:Data_centers). Various | Canyon proportions, raised floors, ceiling services |
| **Elevated platforms and supports (Skybridge)** | [Observing Platform VLT.jpg](https://commons.wikimedia.org/wiki/File:Observing_Platform_VLT.jpg). ESO *(verify; ESO images are generally CC BY 4.0)* | Instrument buildings on a raised platform; control-facility massing |
| | [Category:Gantries](https://commons.wikimedia.org/wiki/Category:Gantries) and [Category:Launching gantry](https://commons.wikimedia.org/wiki/Category:Launching_gantry). Various | Lattice towers and bridge-like structures carrying decks and equipment |
| **Coolant machinery and atmosphere** | [Pumpspeicherwerk Glems Turbinenhalle 2012.JPG](https://commons.wikimedia.org/wiki/File:Pumpspeicherwerk_Glems_Turbinenhalle_2012.JPG). Felix König, own work *(verify licence)* | A pump and turbine hall: big machines in a row under a crane rail |
| | [Turbine hall at Parker Dam 1973.jpg](https://commons.wikimedia.org/wiki/File:Turbine_hall_at_Parker_Dam_1973.jpg). Own work, CC BY-SA 3.0 | Turbine casings as rhythmic, heavy forms |
| | [Towers over cooling pipes, Sizewell A](https://commons.wikimedia.org/wiki/File:Towers_over_cooling_pipes,_Sizewell_A_Power_Station_-_geograph.org.uk_-_2576289.jpg). John Goldsmith / Geograph, CC BY-SA 2.0 | Giant pipe runs at ground level, framing views |
| | [Inside cooling tower.jpg](https://commons.wikimedia.org/wiki/File:Inside_cooling_tower.jpg). Jan Beránek (Tušimice), CC BY-SA 4.0 | Hyperboloid shell interior, mist and scale |
| | [Doel Nuclear power plant and cooling tower.jpg](https://commons.wikimedia.org/wiki/File:Doel_Nuclear_power_plant_and_cooling_tower.jpg). Sally V, CC BY-SA 4.0 | Cooling-tower silhouette next to a containment dome |

**Our own map** is shown by the screenshots in §1 (ground level) and in [`phase8a1/`](phase8a1) (overhead).

---

## 3. District specifications

Each district sits in its own `Map.Architecture.<District>` Model. Heights are in studs above T0 (Y 0). Tiers stay as they are: T1 24, T2 48, T3 72, basin −10.

### 3.1 Central Core — "Containment Pit"
- **Role:** the landmark district and the facility's heart. Brightest.
- **Signature:** the reactor complex (§4).
- **L1 dressing:**
  - the plaza becomes a reactor-deck floor with radial inlays and a raised edge kerb;
  - the mezzanine gets glass balustrades with a cyan cap rail;
  - the four gantries become enclosed truss tubes (ribs every 8, glass sides, open ends);
  - the colonnade along the plaza edge carries a ring canopy at about Y 60. The canopy is open over the reactor and over every bounce pad's 40-stud apex column.
- **L2 structure:**
  - the plaza becomes the lid of a circular **containment pit**: radius 110, walls dropping to Y −90, with ring galleries at −30 and −60 lit by light pools;
  - eight radial support girders run under the mezzanine.
- **Avoid:** anything collidable above the bounce pads; blocking stabilizer reach.

### 3.2 Research Yard — "Test Hangar"
- **Role:** industrial testing labs; Decay's home.
- **Signature:**
  - an **open-sided test hangar**: four trussed portal frames 64 wide and about 50 tall, with a skylight roof over the DecayTile grid only;
  - a **gantry crane** (bridge plus trolley) riding rails along the hangar at Y 40, parked off the grid's apex columns.
- **L1 dressing:**
  - the test chambers become lab pods (door frames, roof slabs, observation windows, instrument masts);
  - grid inlays and hazard-free lab lighting.
- **L2:**
  - substructure trusses under the yard plate down to −40, then columns to the shaft floor;
  - a fuel/sample silo cluster at the west rim, outside the bounds.
- **Identity:** violet experiment lights; cool white lab panels (SmoothPlastic, light grey); steel truss (DiamondPlate/Metal).

### 3.3 Skybridge — "Elevated Control Facility"
- **Role:** suspended command and control.
- **Signature:**
  - **two lattice command spires** (about 110 and about 85) carrying a **glass control room** on part of the SkyDeck (open sides facing play);
  - **suspension cables**: thin decorative beams from the spires to the T3 relay pods, so the pods read as *hung*, not floating;
  - the floating stepping blocks get visible hanger rods to an overhead truss at about Y 120.
- **L1 dressing:** deck edge rails with gaps at drop-downs; dish antenna and instrument racks at the deck corners (off routes).
- **L2:**
  - lattice pylons from the deck down to −90;
  - a counterweight block under the deck;
  - thruster nacelles under the pods.
- **Identity:** silver-grey metal plus glass, and violet beacons.

### 3.4 Data Archive — "Server Canyons"
- **Role:** imposing enclosed spaces; BLACKOUT showcase.
- **Signature:**
  - a **vaulted archive hall**: walls about 70 tall with tall slot windows; a ribbed roof at about Y 70 covering the rack canyons;
  - an **open oculus** over the atrium, which keeps the SUP_ARCHIVE drop column clear to Y 160.
- **L1 dressing:**
  - the rack walls get real faces: modular rack units (K6) with recessed fronts and small cyan/white indicator lights instead of solid cyan panels;
  - cable trays overhead at Y 34 or higher (above jump reach, clear of aisles).
- **L2:** non-walkable cooling stacks rising from the rack tops to the roof between rows; the raised-floor plenum visible through floor grilles.
- **Identity:** cyan data light on dark metal; the most enclosed and darkest district.

### 3.5 Coolant Reservoir — "Pump Station"
- **Role:** heavy machinery and atmosphere; FLOOD's home.
- **Signature:**
  - **two hyperboloid cooling towers** (about 70 and about 55) standing just outside the south rim, beyond the flood volumes;
  - a **pump hall** on the east rim: an open front, three pump/turbine casings and a crane rail.
- **L1 dressing:** the existing pump towers become pump columns (flanges, valves, gauges); rim walkways get railings; the basin keeps its open sky (FLOOD readability).
- **L2:**
  - heavy pipe racks (4–8 stud pipes) running from the basin to the pump hall and on into the substructure;
  - intake grates in the basin walls (decorative, non-collidable insets).
- **Identity:** teal-cyan water light, Concrete plus steel, and mist (static ParticleEmitter, two at most).

### 3.6 Outer Ring — "Transit Ring"
- **Role:** circulation.
- **Additions:**
  - box-girder underside;
  - **support pylons every about 60 studs** down to −90;
  - **signal arches** at each district entry, in district colour with the district name;
  - low rails with gaps at the designated drop-down points;
  - lights under the deck.

---

## 4. Reactor redesign — "Simulation Core"

Goal: the dominant landmark, readable from every spawn. It is the tallest thing inside the hall and the brightest element under BLACKOUT.

| Part | Spec |
|---|---|
| Height | Base of the pit at Y −90; crown at Y **190** (now about 146). Total visible height about 280 |
| Containment drum | The existing drum (a gameplay prop) stays. It is wrapped in a 60-diameter **cradle** of 8 heavy ribs (4 wide, 8 deep) from Y −90 to Y 20 |
| Toroidal coil array | **Three coil rings** at Y 50, 95 and 140, diameter 48 → 40 → 32 (tapering). Each ring is 16 segments: either Parts (K10, about 16 parts per ring) or one generated mesh (F1, §7). Violet Neon only on the inner face; the outer face is navy metal |
| Containment column | A Glass cylinder 18 in diameter from Y 20 to 170, Transparency 0.4, with a cyan Neon **energy core** 6 in diameter inside. Brightest element |
| Buttresses | Four angled lattice buttresses from the pit rim (radius 60) up to the middle coil (Y 95). Each is a box truss (K2) |
| Service galleries | Two ring catwalks around the column at Y 60 and 120. Decorative and non-collidable: they are well above every reachable height |
| Crown | An emitter crown at Y 170–190: 8 fins (K-fin) and a cyan beam (Beam) up to the hall ceiling rib hub at Y 240 |
| Lights | 4 SurfaceLights on the coils (violet), 1 PointLight in the core (cyan, Range 60), 2 spotlights from the pit galleries up the cradle. **7 lights total** |
| Safety | Every addition above the plaza is non-collidable, except the cradle ribs below the plaza deck (in the pit). The existing drum collision and the plaza walkable area are unchanged. Nothing enters the bounce-pad apex columns or the stabilizer radius |
| Part estimate | About 160 parts (parts-only path) or about 70 (with F1 meshes) |

Patch responses: §12.

---

## 5. Megastructure — "Containment Hall"

The aim is to remove the void in every view direction while keeping it all decorative, outside `ArenaBounds`.

| Element | Spec |
|---|---|
| **Hall walls** | A square ring at ±300, Y −90 → 200. Built from wall bays (K3, 24×24 panels plus pilasters every 48). Cyan seams on the pilasters; a violet horizon band at Y 40–44. Every 3rd bay is a **deep window** (recessed 24) showing the outer machinery. Corners have massive chamfer towers 40 wide |
| **Ceiling ribs** | Eight radial box-truss ribs from the wall tops to a central hub ring at Y **240** (radius 30, directly over the reactor). Ribs are 12×16 in section. No ceiling panels: navy haze fills between them. Lowest point Y 200 at the walls. **Every supply-drop column stays clear to Y 160; no rib comes lower than Y 200** |
| **Outer machinery** | Between ±300 and ±460: 12 machinery towers (150–260 tall, 3 variants of K9), 4 cooling towers (reuse of the F1/F2 shell or a parts version), and pipe bridges linking the towers to the hall wall. Seen through the deep windows and above the wall line from the T3 decks |
| **Deep shaft** | The substructure falls to a **shaft floor at Y −90**: dark Slate with a faint cyan grid (strip parts every 40). Non-collidable. The −60 kill plane is unchanged, so falls still respawn before reaching it |
| **Supports** | Columns (K1 scaled) from the shaft floor up under every platform edge: no unsupported slab span over 60. Substructure trusses between the columns at Y −20 and −50 |
| **Haze** | Atmosphere density about 0.35 with navy colour, so the walls read as monumental but soft, and the machinery reads as silhouettes (§8) |
| Streaming | One `Megastructure` Model, `ModelStreamingMode = Persistent`, about 500 large parts, all CanCollide/CanQuery/CanTouch false, CastShadow false except the ribs |

See [`phase8a2/establishing_after.svg`](phase8a2/establishing_after.svg).

---

## 6. Modular kit and reuse plan

The kit lives in `ServerStorage.WORLD_EXE_ArchitectureKit` as template Models. The builder clones and places them; nothing is hand-placed. Each module has a variant colour slot (district accent) and a collidable or decorative flag set by the builder.

| ID | Module | Size (studs) | Parts | Reuse (approx.) |
|---|---|---|---|---|
| K1 | Column with base and capital | 4×4×24 (scales by stacking) | 3 | 180 |
| K2 | Box-truss segment | 4×4×24 (chords plus 2 diagonals) | 6 | 220 |
| K3 | Hall wall bay | 24×24 panel plus pilaster | 3 | 200 |
| K4 | Rail module | 12 long × 3 tall | 3 | 120 |
| K5 | Pipe straight / elbow / flange | Ø4–8 × 24 | 1–3 | 90 |
| K6 | Server rack unit | 4×8×24, recessed face plus 4 indicator lights | 6 | 70 |
| K7 | Portal frame (hangar) | 64 wide × 50 tall | 9 | 6 |
| K8 | Light fixture (pool lamp) | 2×2×1 plus SurfaceLight | 2 | 70 (lights capped) |
| K9 | Machinery tower (3 variants) | 40×40×150–260 | 12–20 | 12 |
| K10 | Coil-ring segment | 10×6×8 arc block | 1 | 48 (or F1 mesh) |
| K11 | Signal arch | 24 wide × 20 tall | 5 | 8 |
| K12 | Pipe-rack bent | 16 wide × 20 tall | 6 | 30 |

**Repetition control**
- Three height variants per tower.
- Rotation and mirroring.
- District accent colours.
- Racks get one of 4 indicator patterns.
- Every 7th wall bay is a deep window.
- Landmarks (the reactor, hangar, control spires, archive vault and cooling towers) are unique compositions, not kit repeats.

**Interiors are never empty:** every enclosed or roofed space gets at least one of: equipment (racks, casings, consoles), overhead services (trays, pipes, crane) or a light pool.

---

## 7. ForgeGUI recommendation and budget

### 7.1 Discovery (read-only, 2026-11-11)

| Item | Finding |
|---|---|
| Tools | 41 tools, including generation (model_3d, image, texture via asset_prepare, music, SFX), prepare, publish, style and library. Studio MCP also offers `generate_mesh`, `generate_material` and `generate_texture` |
| Capabilities (`asset_capabilities`) | `prepare.model.glb` enabled (model prepare max **1M triangles**); `prepare.texture.tiled` enabled (PBR roles colour/normal/roughness/metalness; **max 2048**); `prepare.skybox.equirectangular` enabled (512/1024 faces); `publish.roblox.api_key_connection` enabled (Model/Image/Audio); OAuth / shared-group publishing unavailable; `texture.mesh_uv` unavailable |
| Projects / styles | No projects. One unrelated style ("Castaway Expanse - Island Textures"). Earlier unrelated generations exist (axe/sword models, character sheets) |
| Publication connection | `@amfam1` (Personal, api_key, asset read/write). It is the approved destination, but not used now |
| **Credit balance / pricing** | **Not available through any tool.** There is no balance or estimate endpoint. The owner checks on the website (plans page: `forgegui.com/plans`) before any approval |
| Privacy | Prompts can be text-only. **No reference images will be uploaded** (owner rule). Generations appear in the account's generation list. Publishing goes to the owner's personal Roblox account through the api_key connection only, kept private (no Creator Store) |
| Studio import | GLB → Studio import has **not** been verified yet. The first approved step would be importing one asset and checking scale, collision and triangle count |

### 7.2 Recommendation

Use **parts for everything first** (the whole design is buildable with parts; §6). Generated assets are **optional upgrades** for the few shapes parts do badly: double curvature and smooth rings, which would otherwise cost hundreds of wedges. Only a small, approved preview batch, after the 8A-2a checkpoint.

| ID | Candidate | Purpose and size | Why parts are not enough | Format / path | Cost | Privacy / publishing |
|---|---|---|---|---|---|---|
| F1 | Coil-ring segment (toroidal arc) | Reactor coils. A 1/8 arc segment about 20×8×12 with a flange; tiled 8× per ring, reused for 3 rings (24 instances) | A smooth torus needs about 64 wedge/cylinder parts per ring and still looks faceted. One mesh is smooth and cheaper | GLB via `generation_model_3d` → `prepare.model.glb` (≤ 5k tris), `delivery: direct` (files only) for review | Unknown via tools; owner checks the site | Text prompt only. Files reviewed locally. No upload or publish until approved; then `@amfam1`, private |
| F2 | Hyperboloid cooling-tower shell | Reservoir cooling towers (2) and outer machinery (4). About 50 in diameter × 70, open top, uniform scaling | Parts can't make a doubly curved shell. Stacked cylinders look like a stepped pyramid | Same as F1 (≤ 4k tris) | Unknown | Same |
| F3 | Pipe fitting set (elbow 90°, T-junction, valve wheel) | Pipe racks and pump hall. Ø4–8, 4 pieces, reused about 60× | Elbows from parts need 6–10 wedges each and show seams at every joint | Same (≤ 1.5k tris each) | Unknown | Same |
| F4 | Tiled panel-metal PBR set | Megastructure wall bays and the shaft floor. 1024² tiled (colour/normal/roughness/metalness) as a SurfaceAppearance | Built-in materials repeat obviously at 300-stud scale. A navy panel texture gives scale without extra parts | `asset_prepare` `prepare.texture.tiled`, max 2048 (use 1024) | Unknown | Same. An Image asset when published |
| F5 *(optional)* | Night skybox: distant facility silhouettes and haze | Fills the view above the wall line | Lighting alone can give a dark sky; a skybox adds far depth for 0 parts | `prepare.skybox.equirectangular` (1024 faces) | Unknown | Same. 6 Image assets when published |

**Proposed preview batch, after the 8A-2a review and only with explicit approval:** F1 and F2 only, one generation each, `delivery: direct`. Then a local Studio import test (no publish), and a side-by-side comparison against the parts version. F3–F5 only if the preview proves worthwhile.

**Budget request:** none now. The owner sets a ceiling after checking the balance and price on the website.

Studio `generate_mesh`/`generate_material` are an alternative path with unknown cost and their own privacy terms. They are **not proposed** and will not be called without separate approval.

**Before the first published asset:** create `docs/ASSET_MANIFEST.md` (id, prompt, source, licence and owner approval for each asset), per the ForgeGUI workflow.

---

## 8. Lighting, atmosphere and materials

| Setting | Proposal (decision A2) |
|---|---|
| Time | `ClockTime` about 0.5 (night), `GeographicLatitude` default, sun/moon minimised (`CelestialBodiesShown` false or a dim moon) |
| Ambient | `Ambient` #1A2240, `OutdoorAmbient` #2A3460; `Brightness` 2; `EnvironmentDiffuseScale` 0.4, `EnvironmentSpecularScale` 0.6 |
| Atmosphere | Density 0.35, Offset 0.1, Color #26345E, Decay #0A0F1F, Glare 0.2, Haze 1.5 (tuned in 8A-2a) |
| ColorCorrection | Contrast 0.15, Saturation −0.05, TintColor #E6ECFF |
| Bloom | Intensity 0.6, Size 24, Threshold 1.6 (only true emitters bloom) |
| SunRays | Disabled, or Intensity 0.02 |
| DepthOfField | Off in gameplay (readability) |
| Light pools | Stabilizers: a green pool (objective colour). Spawns: white. District signatures: accent colour. Everything else relies on ambient and emissive trims |
| **BLACKOUT** | WorldModifierService captures the new baseline at start and restores it exactly. BLACKOUT keeps its readable minimum (Brightness ≥ 0.5). Verified in 8A-2a |

**Palette**
- **Navy and charcoal structure:** #0A0F1F, #141C3C, #1F2C5C, #26345E.
- **Cyan #00E1FF:** system and navigation (walkable edges, path inlays, data, the reactor core).
- **Violet #8A2BE2:** simulation energy (coils, patch surfaces, district beacons, patch-response effects).
- **Reserved:**
  - amber = warnings only;
  - green = objectives only;
  - red/coral = danger only (drones).

**Neon rules**
- Neon only on strips no wider than 1 stud, on the reactor core and on indicator lights.
- No neon panels larger than 4×4. The current solid cyan rack faces are removed.

**Materials** (at most 6 per district):
- Metal and DiamondPlate: structure and trusses.
- Concrete: the pit, the reservoir and the hall plinth.
- Slate: the shaft floor.
- Glass: control rooms, balustrades and the containment column.
- SmoothPlastic: lab panels.
- Neon: trims only.

---

## 9. Performance plan

| Budget | 8A-1 now | 8A-2 cap |
|---|---|---|
| Map parts | 522 | **≤ 4,000**: L1 dressing ≤ 900; L2 districts and the reactor ≤ 2,400; L3 megastructure ≤ 600 |
| Collidable parts | about 520 | ≤ 900 (all new decor non-collidable) |
| Lights | few | ≤ 80 total; ≤ 12 with `Shadows` on |
| Beams / ParticleEmitters | 0 | ≤ 2 per district, static rate (motion is 8B) |
| Unions / CSG | 0 | 0 |
| Meshes (if F1–F3 approved) | 0 | ≤ 4 unique meshes, ≤ 5k tris each, `CollisionFidelity = Box`, decorative |
| Textures (if F4/F5) | 0 | ≤ 1 SurfaceAppearance set at 1024, ≤ 1 skybox at 1024 |

**Collision**
- All decor has `CanCollide = false`, `CanQuery = false`, `CanTouch = false` and `CastShadow = false` (except large ribs and walls).
- Collidable additions are limited to rails, kerbs and columns on walkable floor.
- Meshes, if approved, use Box fidelity.

**Streaming**
- StreamingEnabled stays on.
- Megastructure: one Persistent Model.
- Each district: an Atomic Model per sub-assembly.
- Default StreamingTargetRadius is unchanged unless the measurement says otherwise.

**FPS baseline (required before 8A-2 implementation)**
- Scripted 10-second camera flight through all districts plus the six ground-level positions in §1, on a **foreground** Studio client. **The owner must keep the Studio window focused**, because unfocused Studio throttles rendering to 15 FPS.
- Record: average and 1% low FPS, frame time, client memory, and part count. Also server heartbeat under a three-patch load.
- Repeat the same script after 8A-2a and 8A-2b.
- **Target:** post-8A-2 average FPS ≥ 85% of the baseline, and ≥ 55 on the same desktop.
- Mobile and device testing remain release-milestone items.

---

## 10. Staged implementation and validation (after approval)

All work happens through the reproducible builder `tools/studio/phase8a2_architecture.luau`. It is run from the post-8A-1 place and builds `Map.Architecture` plus the `Megastructure`. On any failed §13 check it **aborts and restores**. On success it sets ArenaVersion 3. Each stage ends with a review checkpoint and a stop.

| Stage | Contents | Validation |
|---|---|---|
| **0 Baseline** | Foreground FPS baseline (owner focuses Studio). No changes | FPS, memory and part numbers recorded in the PR |
| **8A-2a** | Megastructure (walls, ribs, shaft floor, outer machinery), Lighting/Atmosphere preset, reactor complex, Central Core supports | §13 checks; the six ground plus six overhead fixed-camera screenshots; BLACKOUT readability check; FPS rerun. **Stop for review** (taste checkpoint) |
| **8A-2b** | All five districts and the Outer Ring: signatures, supports, dressing, interiors | §13 checks; screenshots per district; budget audit; FPS rerun; targeted regression (validation, traversal spot-checks, one patch of each kind, all 5 combinations, a two-match cleanup). **Stop for review** |
| **8A-2c** | Patch-responsive environment (§12): tagged decorative hooks plus one client script that reads the replicated Snapshot. No server or gameplay change | Each of the 10 patches and 5 combinations shows its response and fully reverts at RESET; 0 warnings; parity. **Stop for review** |
| **8A-2d** *(optional)* | ForgeGUI preview (F1/F2) only if approved with a budget: generate (direct delivery) → local import test → compare | No publish without separate approval; manifest; triangle and FPS check |

Each stage follows the existing protocol:
- branch commits;
- Studio ↔ GitHub `src/` parity;
- the owner saves with Ctrl+S, and the save is verified from the file;
- a new rollback backup;
- a PR comment with the report.

Multiplayer validation stays deferred to the pre-release milestone.

---

## 11. Before/after acceptance criteria

| # | Criterion | How measured |
|---|---|---|
| AC1 | No default sky or empty void visible from any of the six ground-level camera positions (G1–G6) or the overhead set | Fixed-camera screenshots before and after, compared side by side |
| AC2 | The reactor is visible from all 16 spawns and is the tallest element inside the hall | Raycast from each spawn (head height) to 3 points on the reactor column: at least 1 unobstructed; height audit |
| AC3 | Every platform edge visibly supported; no unsupported slab span over 60 | Builder audit: every walkable slab has a support within 30 of each edge midpoint |
| AC4 | Each district identifiable from one ground screenshot without its name | Owner/ChatGPT blind check on the G-set |
| AC5 | At least one enclosed or roofed space per district, none empty | Checklist plus screenshots |
| AC6 | Palette compliance: no new amber/green/red except reserved uses; no neon panel over 4×4 | Builder audit over `Map.Architecture` |
| AC7 | Gameplay unchanged: all 8A-1 validators pass; marker counts unchanged; drop columns clear to 160; bounce apex clear to 40; zero-G gaps open; crate lanes clear; flood volumes clear | Builder §13 checks plus the 8A-2b targeted regression |
| AC8 | Performance within §9 | Part, light and collidable counts; foreground FPS ≥ 85% of baseline and ≥ 55 |
| AC9 | All 10 patches and 5 combinations show an environment response that reverts cleanly | 8A-2c test |
| AC10 | BLACKOUT stays readable; the reactor stays the brightest anchor | BLACKOUT screenshot at G1, G3 and G6 |

---

## 12. Patch-responsive environment (no gameplay change)

**Mechanism**
- The builder tags decorative "hook" parts (for example `EnvFX_ZERO_G`).
- A single new **client** script, `EnvironmentResponseClient`, reads the existing replicated `MatchState.Snapshot` (`Patches`, `Interactions`). It changes **only** decorative properties: Color, Transparency, Light.Enabled, Beam.Enabled and emitter rate.
- No server code, remotes, timings or collision change.
- Everything reverts when the patch ends or at RESET.
- Motion (rotation, sweeps) and new VFX are Phase 8B; 8A-2c uses state changes only.

| Patch / combination | Environment response | Where |
|---|---|---|
| ZERO_G | Coil rings switch to bright violet; "gravity field" strips on the hall pilasters light violet; static dust motes | Reactor, hall walls |
| DECAY | Hangar skylight panels flicker to dark (glitch pattern); grid inlays shift to violet | Research Yard |
| DRONE_SWARM | Drone-bay beacons on the control spires turn coral (danger colour) | Skybridge |
| SUPPLY_DROP | The ceiling hub ring and the archive oculus light cyan, marking where drops come from | Ceiling, archive |
| BOUNCY | Pad-surround rings pulse brighter (on/off states) | Bounce pads |
| SLIPPERY | Pipe and rail trims switch to an icy pale-cyan Glass look | Reservoir, ring rails |
| BLACKOUT | The hall wall seams switch off in sectors; the reactor core stays on as the anchor | Hall, all districts |
| MAGNETIC | Overhead archive coils glow violet | Archive |
| CORRUPTION | Hall wall panels nearest the active nodes show violet "glitch" bands | Hall walls |
| FLOOD | Pump-hall casings and intake grates light teal; mist emitters raise their rate | Reservoir |
| SUPER_BOUNCE | Coil rings plus pad rings at maximum violet | Reactor, pads |
| HUNTER_SCAN | A static scan beam from the control spires lights (a sweep comes in 8B) | Skybridge |
| FLOATING_DEBRIS | Decorative debris clusters appear above the basin (non-collidable) | Reservoir |
| RAPID_DECAY | Hangar roof panels go fully dark; the crane hazard beacon goes amber (a warning) | Research Yard |
| SLIDE_FIELD | Icy trims plus a violet shimmer on the hall floor band | Reservoir / ring |

---

## 13. Gameplay safety rules (builder-enforced)

| Constraint | Check |
|---|---|
| Walkable routes unchanged | New collidable parts may not overlap walkable surfaces, ramps, or a 6-stud headroom envelope above them (rails at edges only, with gaps at drop-downs and zero-G gaps) |
| Supply drops | The sky column above all 8 landing points is clear to Y 160; no ceiling rib below Y 200 |
| Drone patrols | All 30 waypoint links keep line of sight |
| BOUNCY / SUPER_BOUNCE | Nothing collidable above any bounce pad below Y 40 |
| ZERO_G | Both 14-stud gaps stay open with clear air |
| MAGNETIC | All 8 crate lanes stay clear (box sweep) |
| FLOOD | No new collidable parts in flood volumes; escape routes unchanged |
| Spawns and stabilizers | Spawn safety and headroom unchanged; stabilizer interaction radius clear |
| Raycasts | Decor has `CanQuery = false`, so DASH, SCANNER and drone line-of-sight are unaffected |

---

## 14. Decisions requested

| # | Decision | Recommendation |
|---|---|---|
| A1 | Megastructure | Containment hall: walls ±300 to Y 200, ceiling ribs to a hub at Y 240, outer machinery, shaft floor at Y −90 |
| A2 | Lighting baseline | The night/navy preset in §8 (it changes the baseline BLACKOUT dims from and restores to) |
| A3 | Railings | Low, jumpable rails with gaps at all drop-downs and gaps |
| A4 | District concepts and reactor | As in §3 and §4 |
| A5 | Budget | ≤ 4,000 parts, ≤ 900 collidable, ≤ 80 lights, no unions |
| A6 | Staging | One branch: 0 → 8A-2a → 8A-2b → 8A-2c, a review stop at each; 8A-2d optional |
| A7 | Foreground FPS | The owner focuses Studio for scripted runs: baseline before 8A-2a, then after each stage |
| A8 | ForgeGUI | Parts-first. A preview of F1/F2 only after 8A-2a, with explicit approval and a budget the owner sets after checking the balance on the website; direct delivery, no publish |
| A9 | Patch responses | The client-only, decorative-only responder (8A-2c) |
