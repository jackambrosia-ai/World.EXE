# Map interface proposal: one match system, several maps

Status: **proposal only** (Agent C, 2026-11-13). Nothing in `src/` is changed by this document. Every code reference is `main` at `f716fe4`; re-verified 2026-11-14 at `3790f0b` (PR #21 head, `src/` unchanged). The testable checklist is `COMPATIBILITY_CHECKLIST.md`.
Owner decisions are marked **[OWNER]**.

## 1. Why this is needed

The match systems are already mostly data-driven: patches, objectives and pickups find their targets through CollectionService tags under `Workspace.WORLD_EXE.Map`. The problem is that the *contract* for a map is spread over `Config`, hard-coded constants in eleven modules and implicit layout knowledge. A second map, or a twice-as-large first map, breaks that contract in four ways:

1. **Exact counts.** `Config.ExpectedTagCounts` (`Config.luau:29-42`) is compared with `==` in `ArenaService.Validate` (`ArenaService.luau:367-370`). Any map with different marker counts boots **Degraded** (`Bootstrap.server.luau:61-69`).
2. **Global constants that encode today's layout.** Arena bounds and the out-of-bounds plane (`Config.luau:215-219`), the zone list (`Config.luau:123`), the lobby location (implied by the bounds comment at `Config.luau:216-217`), and patch tuning written for a 520 × 520 arena: `MAX_UNSAFE = 12 -- of 100 tiles` (`Decay.luau:27`), `MAX_PROPS = 8` (`Magnetic.luau:32`), `MAX_ACTIVE = 12 -- larger arena` (`CollectibleService.luau:25`), `TEAM_REPAIR_TARGET = 3` (`ScoreService.luau:40`).
3. **Map-wide random targeting.** Every positional patch picks its target uniformly over the whole map. That works only because today's map is small: the farthest walk from the hub is 28 s (measured, `agentC/SCALE_REVIEW.md` §1). On a map twice the size, a random SUPPLY_DROP point or drone spawn is often farther away than the patch lasts (30 to 40 s, `PatchCatalog.luau:30-138`).
4. **Init-time caching.** Several services resolve the map once at server start. That is fine for one map per place. It is wrong for in-place map loading.

## 2. Audit: everything in `src/` that assumes the current map

The `tools/studio/*` build scripts are full of absolute coordinates by design. They are builders, not runtime, and are not listed.

### 2.1 Workspace paths (`Workspace.WORLD_EXE.Map` / `.Lobby`)
| Where | What | Caches? |
|---|---|---|
| `ArenaService.luau:504-512` | `Init` waits for `WORLD_EXE.Map`, stores `map`, takes the baseline snapshot | **yes** (`map`, `baseline`) |
| `ArenaService.luau:140-152` | `inMap` / `taggedInMap` filter every tag query to `map` | uses cached `map` |
| `PlayerStateService.luau:342-356` | `Init` reads `WORLD_EXE.Lobby` LobbySpawns and `ArenaService.GetSpawns()` | **yes** (`lobbySpawns`, `arenaSpawns`) |
| `ObjectiveService.luau:334-366` | `Init` discovers Stabilizer models under `Map` and stores `attachment.WorldPosition` | **yes** (`stabilizers`) |
| `CollectibleService.luau:228-234` | `Init` collects FragmentSpawn markers under `Map` | **yes** (`points`) |
| `Flood.luau:47-48`, `DroneSwarm.luau:79-80`, `SupplyDrop.luau:49-50`, `Corruption.luau:37-38`, `Decay.luau:54-55`, `Magnetic.luau:65-66`, `Bouncy.luau:36-37`, `Slippery.luau:26-27` | each patch resolves `workspace.WORLD_EXE.Map` itself, at activation | no (re-queried) |
| `EnvironmentResponseClient.luau:38, 379` | `EnvFX_*` hooks are found by global tag, **not** scoped to `Map` | no |

### 2.2 Bounds and out-of-bounds
| Where | What |
|---|---|
| `Config.luau:215` | `OutOfBoundsY = -60` (abyss floor is Y −91, deepest walkable surface is the basin at Y −10) |
| `Config.luau:216-219` | `ArenaBoundsMin/Max = (−275, −40, −275)..(275, 160, 275)`; comment fixes the lobby "outside it at about (0, 160, 420)" |
| `PlayerStateService.luau:95-99, 313-317` | `insideArena`: eliminate below `OutOfBoundsY`; non-participants inside the box are moved to a lobby pad |
| `AbilityService.luau:211-214, 238` | DASH landing must be inside the same box |

Measured: reachable walkable surfaces span X −260..237, Z −259..260 (`SCALE_REVIEW.md` §1), so today's box has a 15 to 38-stud margin. Any expansion past ±275 makes DASH silently fail at the new edges and lets spectators stand in the new areas. The vertical limits matter too: a walkable floor below Y −60 kills players and rooftops above Y 160 block DASH (Map 2 risk). A widened box must also keep the lobby pads outside it, or containment teleports lobby players every tick (checklist C-04, C-06).

### 2.3 Marker tags, counts and schema
| Where | What |
|---|---|
| `Config.luau:11-24` | 12 tags (shared vocabulary, fine to keep global) |
| `Config.luau:29-42` | exact expected counts (16 spawns, 3 stabilizers, 8 supply points, 30 waypoints, 24 fragments, 100 decay tiles, …) |
| `Config.luau:45-58, 68-121` | class and attribute schema per tag (map-independent, keep global) |
| `Config.luau:123` | `Zones` = the 7 district names of the current map; every marker's `Zone` must be one of them (`ArenaService.luau:32-35, 341-344`) |
| `Config.luau:128-132` | spawn safety margins (map-independent, keep global) |
| `ArenaService.luau:367-370` | `#items ~= expected` → validation error |

### 2.4 Validate and MatchesBaseline
`ArenaService` has **no stored fingerprint**. `MatchesBaseline` / `CompareToBaseline` (`ArenaService.luau:463-492`) compare the live map with a snapshot taken at `Init` (`:512`) using `describe()` (`:95-127`, which includes `GetFullName()`). It is checked at RESET (`MatchService.luau:395-398`) and again at LOBBY (`MatchService.luau:301-307`). So the baseline is already per-map *if the snapshot is taken after the correct map is in place*. The only map-specific parts of `Validate` are the exact counts and the zone list.

### 2.5 Patch reach and radii (all map-wide today)
| Patch | Selection | Reach constants | Scaling problem on a 2× map |
|---|---|---|---|
| FLOOD | **all** FloodZone markers at once (`Flood.luau:95-122`) | `MaxRise` clamped to 0..6 (`:114`); 10 s rise (`:22`) | Floods every low area everywhere. The header comment names today's escape routes (`:10-11`). |
| DRONE_SWARM | 3 drones at **random** waypoints map-wide (`DroneSwarm.luau:142-143`) | aggro 70 / disengage 90 (`:39-40`), speed 14 (`:38`), cap 6 (`:35`) | With 3 random spawns on ~4 sectors, most drones start more than 70 studs from everyone. The patch reads as "nothing happened". |
| SUPPLY_DROP | **random** free landing point (`SupplyDrop.luau:116-120`) | claim 12 (`:25`), beacon 60 high (`:30`) | 3 s + 30 s window. Today's farthest walk is already 28 s, and a 2× map doubles it. |
| MAGNETIC | first `MAX_PROPS = 8` props in name order (`Magnetic.luau:32, 75, 190-193`); nearest point in the same `Zone` (`:196-211`) | lane = straight line to point | More than 8 props: the alphabetically first 8 always win, so later sectors never move. |
| CORRUPTION | one **random Zone path** (`Corruption.luau:64-73`) | 6 active discs (`:24`), 7-stud reach height (`:27`) | Chooses a sector at random, not where players are. |
| DECAY | all DecayTiles (`Decay.luau:78`) | `MAX_UNSAFE = 12 -- of 100 tiles` (`:27`) | Cap is absolute. 200 tiles in two sectors means 6 % unsafe instead of 12 %. |
| BOUNCY / SLIPPERY | all pads map-wide (`Bouncy.luau:40`, `Slippery.luau:30`) | – | Fine, but effect density per sector halves. |
| ZERO_G / BLACKOUT | global (WorldModifierService) | – | map-independent |
| HUNTER_SCAN | drones × 1.2 aggro (`DroneSwarm.luau:50`) | – | as DRONE_SWARM |

### 2.6 Objectives, fragments, spawns, lobby, UI
| Where | What |
|---|---|
| `ObjectiveService.luau:336-366` | all Stabilizers; `InteractionRadius` comes from each model's attribute (10 today), not from code. Good. |
| `ScoreService.luau:40, 163` | `TEAM_REPAIR_TARGET = 3`: team success if 3 repairs, which assumes 3 stabilizers. |
| `CollectibleService.luau:25, 133-148` | 12 active of 24 markers, topped up at **random** free markers |
| `PlayerStateService.luau:108-122` | respawn: uniform random pad (any sector), not the last one |
| `PlayerStateService.luau:234-245` | match start: shuffled distinct pads |
| `PlayerStateService.luau:104-106, 342-355` | lobby: tagged `LobbySpawn` under `WORLD_EXE.Lobby` (geometry at (0, 158..165, 420)) |
| `HUDController.luau:52, 576` | `ZONE_SHORT = { CentralCore = "CORE", Skybridge = "SKY", ResearchYard = "YARD" }`: objective labels for the three current stabilizer zones |
| `PatchCatalog.luau:40` | DECAY text says "Research Yard" |
| `WorldModifierService.luau:124-127` | captures Lighting/Gravity baselines at Init. A per-map lighting preset must be applied **before** this. |
| Camera | no map-specific camera code in `src/` (only `CurrentCamera.ViewportSize` for UI) |
| Streaming | `StreamingEnabled = true`, target radius 1024, min 64 (place settings recorded in `EnvSprint2/geometry/markers_settings.json`; `src/` neither sets nor reads them and never sets `ModelStreamingMode`) |
| World guidance | no client world-space marker for stabilizers or crates; only the 60-stud supply beacon (`SupplyDrop.luau:30`) |

## 3. The contract: `MapDefinition`

One frozen data module per map, in `ReplicatedStorage/WORLD_EXE/Shared/Maps/<Id>.luau`, plus a tiny `MapRegistry` that returns the active definition. It must be replicated, because clients need the sector names and HUD labels. Never put server-only tuning there that players should not see; there is none today.

```lua
--!strict
-- Maps/StableSim.luau  (Map 1; values for the CURRENT map shown, so step 1 is behaviour-neutral)
return table.freeze({
	Id = "STABLE_SIM",                 -- must equal Map:GetAttribute("MapId")
	ArenaVersion = "3",                -- must equal Map:GetAttribute("ArenaVersion")
	DisplayName = "Stable Simulation",
	Container = "Map",                 -- child of Workspace.WORLD_EXE that holds this map
	Lobby = "Lobby",                   -- child of Workspace.WORLD_EXE holding LobbySpawns

	Bounds = { Min = Vector3.new(-275, -40, -275), Max = Vector3.new(275, 160, 275) },
	OutOfBoundsY = -60,

	-- Zone attribute values allowed on markers (replaces Config.Zones for validation)
	Zones = { "CentralCore", "ResearchYard", "Skybridge", "Routes", "DataArchive", "CoolantReservoir", "OuterRing" },

	-- Sectors: gameplay areas with an axis-aligned box. Markers join a sector through their Zone.
	-- Role: "hub" | "objective" | "boss" | "route". A sector may list several Zones.
	Sectors = {
		{ Id = "CORE",    Role = "hub",       Zones = { "CentralCore" },      Min = Vector3.new(-100, -5, -100), Max = Vector3.new(100, 80, 100),  Label = "CORE" },
		{ Id = "YARD",    Role = "objective", Zones = { "ResearchYard" },     Min = Vector3.new(-262, -5, -140), Max = Vector3.new(-140, 80, 140), Label = "YARD" },
		{ Id = "SKY",     Role = "objective", Zones = { "Skybridge" },        Min = Vector3.new(140, -5, -145),  Max = Vector3.new(262, 90, 145),  Label = "SKY" },
		{ Id = "ARCHIVE", Role = "objective", Zones = { "DataArchive" },      Min = Vector3.new(-140, -5, -262), Max = Vector3.new(140, 80, -140), Label = "ARCH" },
		{ Id = "RES",     Role = "objective", Zones = { "CoolantReservoir" }, Min = Vector3.new(-140, -15, 140), Max = Vector3.new(140, 80, 262),  Label = "RES" },
		{ Id = "RING",    Role = "route",     Zones = { "OuterRing", "Routes" }, Min = Vector3.new(-262, -5, -262), Max = Vector3.new(262, 40, 262) },
	},

	-- Marker requirements. Exact = today's strict mode; Min (+ PerSectorMin) for new maps.
	Markers = {
		ArenaSpawn         = { Exact = 16, PerSectorMin = 2, SectorRoles = { "hub", "objective" } },
		Stabilizer         = { Exact = 3 },
		SupplyLandingPoint = { Exact = 8 },
		DroneWaypoint      = { Exact = 30 },
		FragmentSpawn      = { Exact = 24 },
		DecayTile          = { Exact = 100 },
		BounceSurface      = { Exact = 8 }, SlipSurface = { Exact = 8 },
		MagneticProp       = { Exact = 8 }, MagneticPoint = { Exact = 4 },
		CorruptionNode     = { Exact = 18 }, FloodZone = { Exact = 3 },
	},

	Spawns = { Initial = "spread", Respawn = "any" },     -- see §6
	Patches = {                                            -- see §5; nil = code default
		Targeting = "map",                                 -- "map" (today) | "sector"
		DECAY = { MaxUnsafeFraction = 0.12 },
		MAGNETIC = { MaxProps = 8 },
		FLOOD = { MaxRise = 6 },
		DRONE_SWARM = { AggroRange = 70, DisengageRange = 90 },
	},
	Objectives = { TeamRepairTarget = 3, FragmentsMaxActive = 12 },
	BossSectors = {},                                       -- see §7 (data only)

	Lighting = "STABLE_NAVY_V1",                            -- preset id, see §8
	Streaming = { TargetRadius = 1024, MinRadius = 64 },    -- documented; place-level settings
	Fingerprint = nil,                                      -- optional, see §4
})
```

Design rules:
- **Tags and attribute schema stay global** (`Config.Tags`, `Config.TagClasses`, `Config.AttributeSchema`). Maps differ in *how many* and *where*, not in what a marker means.
- **Sector membership is derived from the existing `Zone` attribute.** No new attribute is needed on 375 markers. A Zone listed in two sectors is a validation error.
- **The box is authoritative for players.** `SectorAt(position)` returns the first sector containing the point (ordered list, hub first), so overlapping corridor boxes are allowed.
- `MapRegistry.Active()` returns the definition whose `Id` equals `Workspace.WORLD_EXE[Container]:GetAttribute("MapId")`. If the map has no `MapId`, it returns the legacy definition (`STABLE_SIM`), so production `Place1` keeps working unchanged.

A shared helper, `Shared/MapContext.luau` (about 120 lines, pure functions), owns all lookups:
`Active()`, `Container()`, `InBounds(pos)`, `SectorAt(pos)`, `SectorById(id)`, `ZoneSector(zone)`, `Tagged(tag, sectorId?)`, `PlayersBySector()` (server), `SectorsByRole(role)`.

## 4. Validate and MatchesBaseline per map

**Validate** (`ArenaService.luau:310-402`). Minimal diffs:
1. `:32-35` builds `validZones` from `def.Zones` instead of `Config.Zones`.
2. `:367-370` replaces the exact comparison with `checkCount(def.Markers[key], #items)`. `Exact` keeps today's behaviour. `Min`/`Max` give a range. A missing entry means 0 is allowed (a map without DECAY is legal).
3. New checks appended after `:378` (each about 10 lines, pure data):
   - every tagged marker is inside `def.Bounds`, and its `Zone` maps to a sector whose box contains it (catches markers placed in the wrong district);
   - `PerSectorMin` for each sector role listed;
   - each `objective` sector has at least one Stabilizer *or* is listed as fragment-only;
   - no `ArenaSpawn` and no `SupplyLandingPoint` lies inside a boss sector's `Encounter` box (§7);
   - `MapId` / `ArenaVersion` attributes on the container equal the definition (mismatch → error, not silent).

**MatchesBaseline** (`ArenaService.luau:463-492`). No logic change: the snapshot is already per-instance and taken from the live map. Two small changes:
- `Init` (`:504-512`) resolves `def.Container` instead of the literal `"Map"`.
- Optional release fingerprint: `ArenaService.Fingerprint()` hashes the sorted `describe()` strings with *container-relative* names (use `inst:GetFullName()` minus the container prefix, so the same map under `Maps/STABLE_SIM` fingerprints the same). When `def.Fingerprint` is set, a mismatch at Init is a validation error. That catches "right code, wrong place version" on a live server. Leave it `nil` during development.

For in-place loading (§9), `ArenaService.Init` becomes `ArenaService.Bind(def)`. It is called after the map is cloned in, re-resolves `map`, re-takes the snapshot and re-validates.

## 5. Scaling Architect patches, supply points, stabilizers, fragments and hazards

### 5.1 Sector-scoped targeting (the key change)
At activation, `PatchService` computes `scope` and passes it in `ctx.Scope = { sector = "YARD" }` or `nil` (map-wide). Patch modules filter their marker lists through `MapContext.Tagged(tag, ctx.Scope and ctx.Scope.sector)`. Scope choice, in `PatchService` (one function, about 40 lines):

1. `counts = MapContext.PlayersBySector()` (living Participants only).
2. Candidate sectors = sectors that hold the markers this patch needs (`def.Patches[id].Needs`, defaulting to the tags the module reads), excluding `boss` sectors whose reservation is `Active` (§7).
3. Weighted random pick, weight = `players + 0.5`. Busy sectors are likely, but empty sectors still occasionally get patched, so players are pulled outward. A sector holding more than half the players gets a weight bonus so crowds are punished, which is the design intent.
4. If no candidate exists, fall back to map-wide (today's behaviour), so a partially-marked map never errors.

`def.Patches.Targeting = "map"` turns the whole thing off. That is how the step-1 PR stays behaviour-neutral.

### 5.2 Per-patch rules on a 2× map
| Patch | Proposed rule | Code touch |
|---|---|---|
| SUPPLY_DROP | landing point in the chosen sector; prefer points 40 to 120 studs from the sector's player centroid (reachable in 3 to 8 s) | `SupplyDrop.luau:48-60, 116-120` |
| DRONE_SWARM | spawn waypoints in the chosen sector; patrol may follow `Links` out of it (keeps the graph) | `DroneSwarm.luau:78-92, 142-143` |
| CORRUPTION | path of a Zone in the chosen sector (today: random Zone) | `Corruption.luau:64-73` |
| FLOOD | only FloodZones in the chosen sector (or `FLOOD.Mode = "all"` to keep today's map-wide flood on Map 1) | `Flood.luau:81-95` |
| MAGNETIC | props in scope; `MaxProps` from the definition | `Magnetic.luau:32, 174, 190-193` |
| DECAY | tiles in scope; `MAX_UNSAFE = ceil(fraction × tiles in scope)` | `Decay.luau:27, 78` |
| BOUNCY / SLIPPERY | unchanged (map-wide pads are a benefit/nuisance everywhere) | none |
| ZERO_G / BLACKOUT | unchanged (global) | none |

The announcement should name the sector ("COOLANT FLOOD — RESERVOIR"). That is a one-field addition to the existing `PatchAnnouncement` payload. The HUD already shows patch text, so this is UI copy, not new UI.

### 5.3 Stabilizers, fragments and the success target
- **Stabilizers:** one per `objective` sector (3 to 4 per map). `TEAM_REPAIR_TARGET` (`ScoreService.luau:40`) reads `def.Objectives.TeamRepairTarget`, default `#stabilizers`. On a 2× map the walk between stabilizers grows from 14 to 30 s (current, measured) to an expected 25 to 50 s. Keep `COOLDOWN_SECONDS = 60` (`ObjectiveService.luau:37`) for now and re-tune only after a timed playtest.
- **Fragments:** `FragmentsMaxActive` from the definition. Keep **density per player-reachable area**, not the total: today there are 12 active per 211k sq studs, about 1 per 17.6k. A 420k map wants about 20 active of 40 markers. Top-up should be weighted to sectors with players (same helper as §5.1) so fragments do not pile up where nobody goes. `FRAGMENT_COST = 3` for a repair (`ObjectiveService.luau:38`) then stays achievable inside one sector.
- **Supply points and drone waypoints:** at least 2 supply points and 6 waypoints per non-route sector (validated by `PerSectorMin`).

## 6. Spawn logic across sectors
- **Match start** (`PlayerStateService.luau:234-245`): `Initial = "spread"` deals players round-robin over `hub` + `objective` sectors (shuffled pads inside each). That puts 2 to 3 players per sector for 8 to 12 players, instead of a uniform shuffle that can strand one player alone in a far sector. `Initial = "hub"` is the alternative for maps whose sectors are far apart.
- **Respawn** (`:108-122`): `Respawn = "near_team"` picks a pad in the sector with the most living teammates, excluding pads within 25 studs of an active hazard (Corruption disc, flood footprint) and any boss `Encounter` box. Fallback: today's "any pad but the last".
- Spawn safety rules (`ArenaService.luau:245-308`) are unchanged.

## 7. Boss-sector reservation (data only, no AI)
```lua
BossSectors = {
	{ Sector = "FOUNDRY", Encounter = { Min = ..., Max = ... },  -- the readable floor, 120-220 across
	  Telegraph = 60,          -- studs beyond Encounter edge a future telegraph may reach
	  Approaches = { "ROUTE_W", "ROUTE_N" },                     -- sector ids with a safe approach/retreat
	  ReservedTags = { "SupplyLandingPoint", "ArenaSpawn" },     -- must not be inside Encounter
	  Default = "dormant" },
}
```
Runtime state is one server table (`dormant` | `reserved` | `active`) owned by a future BossService. Until a BossService exists, nothing sets anything other than `dormant`. The only consumers now are: Validate (§4), patch scoping (skip `active`) and respawn (skip `Encounter`). Validation also checks the brief's spacing rule between boss sectors: Encounter-edge gap ≥ 250 studs and gap > `Telegraph` of both.

## 8. Lighting and streaming
- `Lighting = "<preset id>"` names a frozen table in `Shared/LightingPresets.luau` (ClockTime, Ambient, OutdoorAmbient, Brightness, ExposureCompensation, FogEnd, plus the Atmosphere/Bloom/ColorCorrection values). Map 1 = today's values from the export (ClockTime 13, Ambient 2e3454, Brightness 1.8, Exposure 0.3). Map 2 gets its own.
- The preset must be applied **before** `WorldModifierService.Init()` (`Bootstrap.server.luau:44`). Otherwise BLACKOUT restores the wrong baseline. With in-place loading, `WorldModifierService` needs a `Rebase()` called at RESET after the preset swap.
- Streaming properties (`StreamingEnabled`, `StreamingTargetRadius`, `StreamingMinRadius`) are Workspace properties that cannot be changed at runtime. With separate places they are per map for free. With in-place loading both maps share one setting (see §9 and `agentC/BUDGETS_AND_RISKS.md`).

## 9. Separate places vs in-place map loading **[OWNER]**

| | Separate places (one map per place, same code) | In-place loading (one place, maps cloned from ServerStorage) |
|---|---|---|
| Code change | smallest: the definition is chosen by the `MapId` attribute; every Init-time cache is correct as-is | `Bind/Unbind` for ArenaService, PlayerStateService, ObjectiveService, CollectibleService, WorldModifierService; ordering at RESET; destroy/clone of 2,000+ parts with replication spikes |
| Streaming, lighting, Workspace settings | per place (Map 2 can use a different target radius, gravity, Atmosphere) | shared; lighting swap is code, streaming is one compromise setting |
| Memory | one map in memory | both maps in server memory (ServerStorage); the client receives only the active one, but every switch re-streams the whole map |
| Matchmaking / rotation | universe with two places; a lobby/hub place or `TeleportService` with reserved servers; rotation = teleport between matches | rotation inside one server; parties stay together trivially |
| Failure modes | teleport failures (needs retry UI); two places to publish and keep in sync | a half-loaded or leftover map between matches; baseline snapshot and runtime caches out of date; StreamingEnabled clients standing in a streamed-out area when the map swaps |
| Place file truth | each place file is the environment truth for one map (matches the project rule "the saved place is environment truth") | one huge place file holding both maps; every map edit touches the one production place |
| Testing | existing Studio test workflow unchanged per map | new rotation tests (load, unload, reload, baseline after swap) |

**Recommendation:** separate places sharing one code base and one `MapDefinition` registry. It matches how the project already works (Studio-owned place files, Init-time services, per-place streaming), it is the smallest diff, and Map 2's different art and streaming needs argue for its own Workspace settings. Rotation can come later through a teleport step without touching match systems. In-place loading should be revisited only if the owner wants mixed-map rotation *inside one server session*. This is an owner decision: it also decides how the universe is published.

## 10. Migration plan (each step one small PR, behaviour-neutral until step 6)
1. **`MapDefinition` + `MapRegistry` + `MapContext`, legacy values only.** Add `Shared/Maps/StableSim.luau` with today's numbers. `Config.ArenaBoundsMin/Max`, `OutOfBoundsY` and `Zones` stay as aliases that read the active definition. No behaviour change. Unit test: the definition reproduces every current Config value.
2. **Bounds and OOB through MapContext.** `PlayerStateService.luau:95-99, 313`, `AbilityService.luau:211-214`. No behaviour change.
3. **Validate per map.** `ArenaService.luau:32-35, 367-370` plus the new checks in §4. Map 1 keeps `Exact`. Run the existing Validate test plus a negative test (marker outside its sector box).
4. **Container/lobby names from the definition.** `ArenaService.luau:505-506`, `PlayerStateService.luau:343`, `ObjectiveService.luau:335`, `CollectibleService.luau:229`, and the eight patch modules (`Flood.luau:47-48` etc.) switch to `MapContext.Container()`. No behaviour change.
5. **Tuning from the definition.** `Decay.luau:27` (fraction), `Magnetic.luau:32`, `CollectibleService.luau:25`, `ScoreService.luau:40`, `Flood.luau:114`, `DroneSwarm.luau:39-40`, `HUDController.luau:52` (labels from `Sectors[].Label`). Same values for Map 1.
6. **Sector-scoped targeting behind `Patches.Targeting`.** PatchService scope plus the patch filters in §5.2. Map 1 stays `"map"` until playtested. First behaviour change, gated.
7. **Spawn policy** (`Initial`, `Respawn`) behind the definition, default today's.
8. **Boss-sector data + validation** (no runtime consumer except §6/§5 exclusions).
9. **Map 1 expanded definition** (new bounds, sectors, counts from Agent A's LAYOUT; the v7 wings currently hold **no** gameplay markers, so counts must change) + `Fingerprint` once the place is approved.
10. **Map 2 definition** once Studio collision and markers exist; separate place (if approved).

Every step keeps `Place1.rbxl` booting `Ready` with zero validation errors, which is the existing acceptance gate.
