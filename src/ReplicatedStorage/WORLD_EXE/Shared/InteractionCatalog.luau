--!strict
-- WORLD.EXE combination allowlist (Phase 7A; docs/03_PATCH_CATALOG.md "Approved combinations").
-- A combination exists only if listed here. Each one names exactly two source patches and the
-- server behaviour module (ServerScriptService.WORLD_EXE.Patches.<Behavior>). Phase 7B adds
-- FLOATING_DEBRIS, RAPID_DECAY and SLIDE_FIELD.

export type InteractionDefinition = {
	Id: string,
	DisplayName: string,
	Sources: { string },
	Warning: string,
	Behavior: string,
}

local definitions: { InteractionDefinition } = {
	{
		Id = "SUPER_BOUNCE",
		DisplayName = "Super Bounce",
		Sources = { "ZERO_G", "BOUNCY" },
		Warning = "SUPER BOUNCE — Low gravity supercharges the bounce pads!",
		Behavior = "SuperBounce",
	},
	{
		Id = "HUNTER_SCAN",
		DisplayName = "Hunter Scan",
		Sources = { "BLACKOUT", "DRONE_SWARM" },
		Warning = "HUNTER SCAN — Drones sweep the dark. An amber cone means a lock is coming!",
		Behavior = "HunterScan",
	},
}

local byId: { [string]: InteractionDefinition } = {}
local byPatch: { [string]: { InteractionDefinition } } = {}
local ids: { string } = {}
for _, def in definitions do
	assert(#def.Sources == 2 and def.Sources[1] ~= def.Sources[2], "combination " .. def.Id .. " needs two different sources")
	table.freeze(def.Sources)
	table.freeze(def)
	assert(byId[def.Id] == nil, "duplicate combination id " .. def.Id)
	byId[def.Id] = def
	table.insert(ids, def.Id)
	for _, source in def.Sources do
		byPatch[source] = byPatch[source] or {}
		table.insert(byPatch[source], def)
	end
end
table.freeze(ids)

local InteractionCatalog = {}

function InteractionCatalog.Get(id: string): InteractionDefinition?
	return byId[id]
end

function InteractionCatalog.Ids(): { string }
	return ids
end

-- Combinations that list `patchId` as a source (empty when none).
function InteractionCatalog.ForPatch(patchId: string): { InteractionDefinition }
	return byPatch[patchId] or {}
end

return table.freeze(InteractionCatalog)
