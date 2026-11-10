--!strict
-- WORLD.EXE shared configuration (Phase 1).
-- Replicated to clients: never put secrets, keys, or server-only tuning here.

local Config = {}

Config.Version = "0.1.1-phase1"
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
