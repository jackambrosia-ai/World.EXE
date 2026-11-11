--!strict
-- WORLD.EXE approved patch catalog (finite and server-owned; replicated so the UI can show cards).
-- Player input only ever selects one of these ids; keywords are aliases for approved ids.
-- Timings are initial proposals from docs/03_PATCH_CATALOG.md. Each id's server behaviour lives in
-- ServerScriptService.WORLD_EXE.Patches (ZeroG, Decay, DroneSwarm, SupplyDrop, Bouncy, Slippery,
-- Blackout). Severity drives the stability cost and the "at most 2 severe cards" rotation rule;
-- Weight is the relative chance of being offered (Phase 7A provisional tuning).

export type PatchDefinition = {
	Id: string,
	DisplayName: string,
	Category: string,
	Warning: string,
	Effect: string,
	Aliases: { string },
	WarningSeconds: number, -- announcement before activation
	DurationSeconds: number, -- active period
	Severity: string, -- "mild" | "standard" | "severe"
	Weight: number, -- relative offer weight
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
		Severity = "standard",
		Weight = 3,
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
		Severity = "severe",
		Weight = 2,
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
		Severity = "severe",
		Weight = 2,
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
		Severity = "mild",
		Weight = 3,
		Aliases = { "SUPPLY", "SUPPLIES", "CRATE" },
	},
	{
		Id = "BOUNCY",
		DisplayName = "Bouncy",
		Category = "Physics",
		Warning = "BOUNCE FIELD ONLINE — Glowing pads launch you upward!",
		Effect = "Marked pads launch players into the air.",
		WarningSeconds = 4.5,
		DurationSeconds = 35,
		Severity = "mild",
		Weight = 3,
		Aliases = { "BOUNCE", "JUMPPAD", "SPRING" },
	},
	{
		Id = "SLIPPERY",
		DisplayName = "Slippery",
		Category = "Environment",
		Warning = "SURFACE FAULT — Icy pads have almost no grip!",
		Effect = "Marked pads become slippery.",
		WarningSeconds = 4.5,
		DurationSeconds = 35,
		Severity = "mild",
		Weight = 3,
		Aliases = { "SLIP", "ICE", "ICY" },
	},
	{
		Id = "BLACKOUT",
		DisplayName = "Blackout",
		Category = "Environment",
		Warning = "POWER FAILURE — Lights are dropping. Watch the glowing hazards!",
		Effect = "The arena goes dark; hazards stay lit.",
		WarningSeconds = 4.5,
		DurationSeconds = 30,
		Severity = "mild",
		Weight = 3,
		Aliases = { "DARK", "LIGHTSOUT", "POWER" },
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
