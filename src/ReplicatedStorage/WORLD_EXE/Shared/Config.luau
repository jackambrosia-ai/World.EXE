--!strict
-- WORLD.EXE shared configuration (Phase 1).
-- Replicated to clients: never put secrets, keys, or server-only tuning here.

local Config = {}

Config.Version = "0.1.0-phase1"
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
Config.ExpectedTagCounts = table.freeze({
	DecayTile = 69,
	ArenaSpawn = 12,
	Stabilizer = 3,
	SupplyLandingPoint = 5,
	DroneWaypoint = 15,
})

-- Attributes every tagged instance must carry. The first entry is the unique id attribute.
Config.RequiredAttributes = table.freeze({
	DecayTile = table.freeze({ "TileId", "Zone" }),
	ArenaSpawn = table.freeze({ "SpawnId", "Zone" }),
	Stabilizer = table.freeze({ "StabilizerId", "Zone", "InteractionRadius" }),
	SupplyLandingPoint = table.freeze({ "PointId", "Zone" }),
	DroneWaypoint = table.freeze({ "WaypointId", "Zone", "Links" }),
})

Config.Zones = table.freeze({ "CentralCore", "ResearchYard", "Skybridge", "Routes" })

-- Runtime containers under Workspace.WORLD_EXE, created and emptied by the server.
Config.RuntimeFolders = table.freeze({ "ActivePatchInstances", "Collectibles", "RuntimeEffects" })

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
