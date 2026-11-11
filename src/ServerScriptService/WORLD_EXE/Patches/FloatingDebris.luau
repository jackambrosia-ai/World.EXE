--!strict
-- FLOATING_DEBRIS combination (FLOOD + MAGNETIC, Phase 7B): MAGNETIC's crates float on FLOOD's water
-- and become temporary stepping routes above it (a crate's top sits 2 studs above the surface, so
-- standing on one keeps a player out of the water). Crates never move while a player is next to
-- them, so a crate someone stands on stays put. When the combination ends (either source ending
-- ends it) the float hook is removed and the crates settle back to their resting height (or are
-- restored by MAGNETIC's own cleanup).

local Flood = require(script.Parent:WaitForChild("Flood"))
local Magnetic = require(script.Parent:WaitForChild("Magnetic"))

local FloatingDebris = {}

function FloatingDebris.Activate(ctx: any)
	Magnetic.AddFloat(ctx.RuntimeId, Flood.GetWaterLevel)
	ctx.Add(function()
		Magnetic.RemoveFloat(ctx.RuntimeId)
	end)
end

return table.freeze(FloatingDebris)
