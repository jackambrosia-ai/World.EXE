--!strict
-- WORLD.EXE approved patch catalog (finite and server-owned; replicated so the UI can show cards).
-- Player input only ever selects one of these ids; keywords are aliases for approved ids.
-- Timings are initial proposals from docs/03_PATCH_CATALOG.md. Phase 3 runs every approved patch
-- through the patch engine with a no-effect placeholder behaviour; real effects arrive in Phase 4.

export type PatchDefinition = {
	Id: string,
	DisplayName: string,
	Category: string,
	Warning: string,
	Effect: string,
	Aliases: { string },
	WarningSeconds: number, -- announcement before activation
	DurationSeconds: number, -- active period
}

local definitions: { PatchDefinition } = {
	{
		Id = "ZERO_G",
		DisplayName = "Zero-G",
		Category = "Physics",
		Warning = "GRAVITY UNSTABLE — Movement will feel weightless!",
		Effect = "Reduces gravity across the arena.",
		WarningSeconds = 4.5,
		DurationSeconds = 35,
		Aliases = { "ZEROG", "GRAVITY", "LOWGRAVITY", "WEIGHTLESS" },
	},
	{
		Id = "DECAY",
		DisplayName = "Decay",
		Category = "Environment",
		Warning = "STRUCTURAL DECAY — Marked platforms are about to collapse!",
		Effect = "Marked Research Yard tiles collapse for a short time.",
		WarningSeconds = 4.5,
		DurationSeconds = 40,
		Aliases = { "COLLAPSE", "CRUMBLE" },
	},
	{
		Id = "DRONE_SWARM",
		DisplayName = "Drone Swarm",
		Category = "Entity",
		Warning = "SECURITY DRONES DEPLOYED — Keep moving and break line of sight!",
		Effect = "A small group of hostile drones hunts players.",
		WarningSeconds = 4.5,
		DurationSeconds = 35,
		Aliases = { "DRONES", "DRONE", "SWARM" },
	},
	{
		Id = "SUPPLY_DROP",
		DisplayName = "Supply Drop",
		Category = "Beneficial",
		Warning = "SUPPLY DROP INBOUND — Reach the marked landing zone!",
		Effect = "A contested crate lands at a marked zone.",
		WarningSeconds = 4.5,
		DurationSeconds = 30,
		Aliases = { "SUPPLY", "SUPPLIES", "CRATE" },
	},
}

-- Normalized key: uppercase letters and digits only ("zero-g" -> "ZEROG").
local function normalize(text: string): string
	return (string.gsub(string.upper(text), "[^%w]", ""))
end

local byId: { [string]: PatchDefinition } = {}
local byKey: { [string]: string } = {}
local ids: { string } = {}
for _, def in definitions do
	table.freeze(def.Aliases)
	table.freeze(def)
	assert(byId[def.Id] == nil, "duplicate patch id " .. def.Id)
	byId[def.Id] = def
	table.insert(ids, def.Id)
	for _, key in { def.Id, table.unpack(def.Aliases) } do
		local k = normalize(key)
		assert(byKey[k] == nil or byKey[k] == def.Id, "alias collision " .. k)
		byKey[k] = def.Id
	end
end
table.freeze(ids)

local PatchCatalog = {}

function PatchCatalog.Get(id: string): PatchDefinition?
	return byId[id]
end

function PatchCatalog.IsApproved(id: string): boolean
	return byId[id] ~= nil
end

-- Resolves an id or alias (case/punctuation-insensitive) to an approved id, or nil.
function PatchCatalog.Resolve(text: string): string?
	return byKey[normalize(text)]
end

function PatchCatalog.Ids(): { string }
	return ids
end

return table.freeze(PatchCatalog)
