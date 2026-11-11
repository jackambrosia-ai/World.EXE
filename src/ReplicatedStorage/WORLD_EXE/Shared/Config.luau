--!strict
-- WORLD.EXE shared configuration (Phase 1).
-- Replicated to clients: never put secrets, keys, or server-only tuning here.

local Config = {}

Config.Version = "0.8.0-phase8a1"
Config.RootName = "WORLD_EXE"

-- CollectionService tags used by the Studio-owned arena.
Config.Tags = table.freeze({
	DecayTile = "DecayTile",
	ArenaSpawn = "ArenaSpawn",
	Stabilizer = "Stabilizer",
	SupplyLandingPoint = "SupplyLandingPoint",
	DroneWaypoint = "DroneWaypoint",
	FragmentSpawn = "FragmentSpawn", -- Phase 5: data-fragment spawn markers (Map.FragmentSpawns)
	BounceSurface = "BounceSurface", -- Phase 7A: BOUNCY pads (Map.PatchSurfaces)
	SlipSurface = "SlipSurface", -- Phase 7A: SLIPPERY pads (Map.PatchSurfaces)
	MagneticProp = "MagneticProp", -- Phase 7B: MAGNETIC crates (Map.PatchMarkers)
	MagneticPoint = "MagneticPoint", -- Phase 7B: safe points the crates move to
	CorruptionNode = "CorruptionNode", -- Phase 7B: CORRUPTION path nodes (one path per Zone)
	FloodZone = "FloodZone", -- Phase 7B: FLOOD low-ground footprints
})

-- Arena baseline (Phase 8A-1 arena, ArenaVersion 2; built by tools/studio/phase8a1_build_arena.luau).
-- Server validation reports any drift from these counts. DecayTile covers only the Research Yard
-- test grid (10 x 10).
Config.ExpectedTagCounts = table.freeze({
	DecayTile = 100,
	ArenaSpawn = 16,
	Stabilizer = 3,
	SupplyLandingPoint = 8,
	DroneWaypoint = 30,
	FragmentSpawn = 24,
	BounceSurface = 8,
	SlipSurface = 8,
	MagneticProp = 8,
	MagneticPoint = 4,
	CorruptionNode = 18,
	FloodZone = 3,
})

-- Instance class each tag must be applied to (checked with IsA).
Config.TagClasses = table.freeze({
	DecayTile = "BasePart",
	ArenaSpawn = "SpawnLocation",
	Stabilizer = "Model",
	SupplyLandingPoint = "BasePart",
	DroneWaypoint = "BasePart",
	FragmentSpawn = "BasePart",
	BounceSurface = "BasePart",
	SlipSurface = "BasePart",
	MagneticProp = "BasePart",
	MagneticPoint = "BasePart",
	CorruptionNode = "BasePart",
	FloodZone = "BasePart",
})

export type AttributeKind = "id" | "zone" | "positive" | "links"
export type AttributeField = { name: string, kind: AttributeKind }

-- Attribute schema per tag. Kinds:
--   id       non-empty string, unique within the tag (each tag has exactly one, listed first)
--   zone     string listed in Config.Zones
--   positive finite number greater than zero
--   links    comma-separated DroneWaypoint ids (no spaces): each known, no duplicates, no self-link, symmetric
Config.AttributeSchema = table.freeze({
	DecayTile = table.freeze({
		table.freeze({ name = "TileId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	ArenaSpawn = table.freeze({
		table.freeze({ name = "SpawnId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	Stabilizer = table.freeze({
		table.freeze({ name = "StabilizerId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
		table.freeze({ name = "InteractionRadius", kind = "positive" }),
	}),
	SupplyLandingPoint = table.freeze({
		table.freeze({ name = "PointId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	DroneWaypoint = table.freeze({
		table.freeze({ name = "WaypointId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
		table.freeze({ name = "Links", kind = "links" }),
	}),
	FragmentSpawn = table.freeze({
		table.freeze({ name = "FragmentSpawnId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	BounceSurface = table.freeze({
		table.freeze({ name = "SurfaceId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	SlipSurface = table.freeze({
		table.freeze({ name = "SurfaceId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	MagneticProp = table.freeze({
		table.freeze({ name = "PropId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	MagneticPoint = table.freeze({
		table.freeze({ name = "PointId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
	}),
	CorruptionNode = table.freeze({
		table.freeze({ name = "NodeId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
		table.freeze({ name = "Order", kind = "positive" }),
	}),
	FloodZone = table.freeze({
		table.freeze({ name = "FloodZoneId", kind = "id" }),
		table.freeze({ name = "Zone", kind = "zone" }),
		table.freeze({ name = "MaxRise", kind = "positive" }),
	}),
}) :: { [string]: { AttributeField } }

Config.Zones = table.freeze({ "CentralCore", "ResearchYard", "Skybridge", "Routes", "DataArchive", "CoolantReservoir", "OuterRing" })

-- Phase 8A spawn safety (checked by ArenaService.Validate): arena spawns stay this far outside every
-- FloodZone footprint and at least SpawnHazardClearance studs (edge to centre) from corruption
-- nodes, bounce/slip pads and MAGNETIC crate lanes.
Config.SpawnFloodMargin = 3
Config.SpawnHazardClearance = 8

-- Spawn pads must rest on anchored, collidable, non-DecayTile floor within this gap (studs).
Config.SpawnFloorTolerance = 0.05

-- Runtime containers under Workspace.WORLD_EXE. The server creates them at runtime and marks
-- them with RuntimeFolderMarker; only marked Folders are ever emptied.
Config.RuntimeFolders = table.freeze({ "ActivePatchInstances", "Collectibles", "RuntimeEffects" })
Config.RuntimeFolderMarker = "WORLD_EXE_RuntimeFolder"

---------------------------------------------------------------------------------------------------
-- Phase 2: match lifecycle, players, Architect

Config.MatchStates = table.freeze({
	Lobby = "LOBBY",
	Countdown = "COUNTDOWN",
	Initializing = "INITIALIZING",
	Active = "ACTIVE",
	FinalPhase = "FINAL_PHASE",
	Results = "RESULTS",
	Reset = "RESET",
})

-- Match timing (seconds). Target match length 8–12 min; initial gameplay duration 8:30
-- (ACTIVE 7:00 + FINAL_PHASE 1:30), approved 2026-11-10. Tune in playtests.
Config.Match = table.freeze({
	MinPlayers = 2,
	StudioMinPlayers = 1, -- used only in Studio so solo playtests can run the loop
	MaxParticipants = 12,
	CountdownSeconds = 10,
	InitializingSeconds = 5, -- spawn protection lasts exactly this long
	ActiveSeconds = 420,
	FinalPhaseSeconds = 90,
	ResultsSeconds = 12,
	ResetSeconds = 3,
	TickSeconds = 0.25,
})

Config.Architect = table.freeze({
	FirstTurnDelaySeconds = 15, -- after ACTIVE starts
	-- Gap between the end of one turn and the start of the next. Phase 7A review round 1: 45 -> 25 so
	-- consecutive Architect patches (35 s) overlap and combinations can occur in normal play.
	TurnIntervalSeconds = 25,
	SubmissionWindowSeconds = 12,
	CardsOffered = 4,
	NoEligibleRetrySeconds = 3,
	MaxSevereCards = 2, -- Phase 7A rotation: at most this many "severe" cards per offer
	NoRepeatTurns = 2, -- Phase 7A rotation: patches accepted in this many latest turns are not offered
	MaxInputLength = 32,
	RateLimitBurst = 4,
	RateLimitPerSecond = 1,
})

Config.Roles = table.freeze({
	Lobby = "Lobby",
	Participant = "Participant",
	Spectator = "Spectator",
})

-- Server-set player attributes (replicated; clients only read them).
Config.PlayerAttributes = table.freeze({
	Role = "WORLD_EXE_Role",
	Alive = "WORLD_EXE_Alive",
	Shield = "WORLD_EXE_ShieldUntil", -- server time the SUPPLY_DROP shield expires (absent = none)
	Score = "WORLD_EXE_Score", -- Phase 5: this match's score so far (absent outside a match)
	Fragments = "WORLD_EXE_Fragments", -- Phase 5: data fragments carried and not yet spent
	AbilityReadyPrefix = "WORLD_EXE_AbilityReady_", -- Phase 6: + ability id = server time it is ready
	AbilityActivePrefix = "WORLD_EXE_AbilityActive_", -- Phase 6: + ability id = server time it ends
})

-- RemoteEvents created by the server under ReplicatedStorage.WORLD_EXE.Remotes.
Config.Remotes = table.freeze({
	RequestPatchSubmission = "RequestPatchSubmission", -- client -> server: { patchId = string }
	SubmissionResult = "SubmissionResult", -- server -> one client: { ok, reason, patchId? }
	PatchAnnouncement = "PatchAnnouncement", -- server -> all: accepted / skipped turn
	MatchStateChanged = "MatchStateChanged", -- reserved (still created; not fired since Phase 8A-1: clients read the Snapshot attribute)
	RequestAbility = "RequestAbility", -- client -> server: { abilityId = string } only (Phase 6)
	AbilityFeedback = "AbilityFeedback", -- server -> one client: result, cooldown, scanner targets
})

-- Replicated match state: ReplicatedStorage.WORLD_EXE.MatchState carries ONE attribute holding a
-- JSON snapshot with a monotonically increasing Version (no partially updated multi-attribute state).
Config.MatchStateFolder = "MatchState"
Config.MatchSnapshotAttribute = "Snapshot"

Config.LobbySpawnTag = "LobbySpawn"
Config.OutOfBoundsY = -60 -- characters below this are eliminated and respawn
-- Non-participants found inside this box are returned to the lobby (Phase 8A-1: 520 x 520 arena;
-- the lobby sits outside it at about (0, 160, 420)).
Config.ArenaBoundsMin = Vector3.new(-275, -40, -275)
Config.ArenaBoundsMax = Vector3.new(275, 160, 275)
Config.SpawnProtectionName = "WORLD_EXE_SpawnProtection"

-- Studio-only test controls: attributes on ServerScriptService.WORLD_EXE, ignored on live servers.
Config.StudioControls = table.freeze({
	TimeScale = "StudioTimeScale", -- multiplies match-phase and turn-interval durations
	MinPlayers = "StudioMinPlayers",
	FailOnEnter = "StudioFailOnEnter", -- state name: makes that state's entry fail (recovery test)
})

---------------------------------------------------------------------------------------------------
-- Phase 3: patch engine

Config.PatchStates = table.freeze({
	Warning = "WARNING",
	Active = "ACTIVE",
	Ending = "ENDING",
	Ended = "ENDED",
})

Config.Patches = table.freeze({
	MaxActiveMajor = 3, -- slots: patches in WARNING, ACTIVE or ENDING each hold one
	DefaultWarningSeconds = 4.5, -- used when a definition has no WarningSeconds
	HistoryLimit = 50, -- ended records kept for results/tests
})

-- Shared world properties owned by WorldModifierService (effective value is clamped to this range).
Config.WorldModifiers = table.freeze({
	Gravity = table.freeze({ Min = 0, Max = 1000 }),
	-- Phase 7A (BLACKOUT): readable minimums so hazards and prompts stay visible.
	Brightness = table.freeze({ Min = 0.5, Max = 10 }),
	ExposureCompensation = table.freeze({ Min = -1.5, Max = 3 }),
})

---------------------------------------------------------------------------------------------------
-- Phase 5: stability, objectives, collectibles, scoring (display values; server tuning lives in
-- the services)

Config.Stability = table.freeze({
	Initial = 100,
	Min = 0,
	Max = 100,
	SuccessTarget = 50, -- team success if stability ends at or above this (or enough repairs)
})

Config.ObjectiveStates = table.freeze({
	Idle = "IDLE",
	Repairing = "REPAIRING",
	Paused = "PAUSED",
	Cooldown = "COOLDOWN",
})

-- Reference-board palette (docs/04_UI_AND_ART_DIRECTION.md).
Config.Palette = table.freeze({
	DeepNavy = Color3.fromRGB(10, 15, 31),
	NeonCyan = Color3.fromRGB(0, 225, 255),
	ElectricPurple = Color3.fromRGB(138, 43, 226),
	AmberWarning = Color3.fromRGB(255, 193, 7),
	CleanWhite = Color3.fromRGB(245, 247, 255),
	ObjectiveGreen = Color3.fromRGB(60, 220, 140),
})

return table.freeze(Config)
