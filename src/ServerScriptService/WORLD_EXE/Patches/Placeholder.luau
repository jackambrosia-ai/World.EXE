--!strict
-- Placeholder patch behaviour (Phase 3). Holds a slot for the patch's lifetime with no gameplay
-- effect, so the engine (lifecycle, capacity, cleanup, announcements) can be exercised end to
-- end. Phase 4 replaces it per PatchId with ZERO_G, DECAY, DRONE_SWARM and SUPPLY_DROP.

return table.freeze({
	Activate = function(_ctx: any) end,
})
