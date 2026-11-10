--!strict
-- WORLD.EXE shared configuration (Phase 1).
-- Replicated to clients: never put secrets, keys, or server-only tuning here.

local Config = {}

Config.Version = "0.3.0-phase3"
Config.RootName = "WORLD_EXE"

-- CollectionService tags used by the Studio-owned arena.
Config.Tags = table.freeze({
	DecayTile = "DecayTile",
	ArenaSpawn = "ArenaSpawn",
	Stabilizer = "Stabilizer",
	SupplyLandingPoint = "SupplyLandingPoint",
	DroneWaypoint = "DroneWaypoint",
})

-- Phase 1 arena baseline. Server validation reports any drift from these counts.
-- DecayTile covers only the 64 Research Yard tiles; the Skybridge jump steps are deliberately
-- NOT DecayTiles (see docs/PROJECT_STATUS.md, "SkySteps decision").
Config.ExpectedTagCounts = table.freeze({
	DecayTile = 64,
	ArenaSpawn = 12,
	Stabilizer = 3,
	SupplyLandingPoint = 5,
	DroneWaypoint = 15,
})

-- Instance class each tag must be applied to (checked with IsA).
Config.TagClasses = table.freeze({
	DecayTile = "BasePart",
	ArenaSpawn = "SpawnLocation",
	Stabilizer = "Model",
	SupplyLandingPoint = "BasePart",
	DroneWaypoint = "BasePart",
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
}) :: { [string]: { AttributeField } }

Config.Zones = table.freeze({ "CentralCore", "ResearchYard", "Skybridge", "Routes" })

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
	TurnIntervalSeconds = 45, -- gap between the end of one turn and the start of the next
	SubmissionWindowSeconds = 12,
	CardsOffered = 4,
	NoEligibleRetrySeconds = 3,
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
})

-- RemoteEvents created by the server under ReplicatedStorage.WORLD_EXE.Remotes.
Config.Remotes = table.freeze({
	RequestPatchSubmission = "RequestPatchSubmission", -- client -> server: { patchId = string }
	SubmissionResult = "SubmissionResult", -- server -> one client: { ok, reason, patchId? }
	PatchAnnouncement = "PatchAnnouncement", -- server -> all: accepted / skipped turn
	MatchStateChanged = "MatchStateChanged", -- server -> all: state snapshot on each transition
})

-- Replicated match state: ReplicatedStorage.WORLD_EXE.MatchState carries ONE attribute holding a
-- JSON snapshot with a monotonically increasing Version (no partially updated multi-attribute state).
Config.MatchStateFolder = "MatchState"
Config.MatchSnapshotAttribute = "Snapshot"

Config.LobbySpawnTag = "LobbySpawn"
Config.OutOfBoundsY = -60 -- characters below this are eliminated and respawn
-- Non-participants found inside this box are returned to the lobby.
Config.ArenaBoundsMin = Vector3.new(-185, -60, -95)
Config.ArenaBoundsMax = Vector3.new(175, 90, 70)
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
