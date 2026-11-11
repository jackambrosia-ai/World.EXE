--!strict
-- WORLD.EXE ability catalog (Phase 6; finite and server-owned; replicated so the HUD can show it).
-- Player input only ever names one of these ids. Cooldowns and durations are provisional tuning
-- from docs/01_GAME_DESIGN.md §7; the server is the only judge of cooldowns and effects.

export type AbilityDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	CooldownSeconds: number,
	DurationSeconds: number, -- 0 = instant
	Key: Enum.KeyCode,
	GamepadKey: Enum.KeyCode,
	Order: number,
}

local definitions: { AbilityDefinition } = {
	{
		Id = "PHASE_DASH",
		DisplayName = "Phase Dash",
		Description = "Short dash in the direction you face. Cannot pass through walls.",
		CooldownSeconds = 18,
		DurationSeconds = 0,
		Key = Enum.KeyCode.Q,
		GamepadKey = Enum.KeyCode.ButtonX,
		Order = 1,
	},
	{
		Id = "ANCHOR",
		DisplayName = "Anchor",
		Description = "Briefly cancels low gravity on you. Not a shield.",
		CooldownSeconds = 25,
		DurationSeconds = 4,
		Key = Enum.KeyCode.F,
		GamepadKey = Enum.KeyCode.ButtonY,
		Order = 2,
	},
	{
		Id = "SCANNER",
		DisplayName = "Scanner",
		Description = "Highlights nearby fragments and hazards for a few seconds.",
		CooldownSeconds = 22,
		DurationSeconds = 6,
		Key = Enum.KeyCode.R,
		GamepadKey = Enum.KeyCode.DPadUp,
		Order = 3,
	},
}

local byId: { [string]: AbilityDefinition } = {}
local ids: { string } = {}
for _, def in definitions do
	table.freeze(def)
	assert(byId[def.Id] == nil, "duplicate ability id " .. def.Id)
	byId[def.Id] = def
	table.insert(ids, def.Id)
end
table.freeze(ids)

local AbilityCatalog = {}

function AbilityCatalog.Get(id: string): AbilityDefinition?
	return byId[id]
end

function AbilityCatalog.Ids(): { string }
	return ids
end

return table.freeze(AbilityCatalog)
