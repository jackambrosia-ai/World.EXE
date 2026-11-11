--!strict
-- RAPID_DECAY combination (DECAY + CORRUPTION, Phase 7B): DECAY starts new tile groups 1.5x as often.
-- Safety is unchanged: every tile still shows its full amber warning (Decay WARN_SECONDS) before it
-- collapses, and Decay's MAX_UNSAFE cap still bounds how many tiles are unsafe at once. The speed-up
-- token is removed when the combination ends (either source ending ends it).

local Decay = require(script.Parent:WaitForChild("Decay"))

local SPEEDUP = 1.5

local RapidDecay = {}

function RapidDecay.Activate(ctx: any)
	Decay.AddSpeedup(ctx.RuntimeId, SPEEDUP)
	ctx.Add(function()
		Decay.RemoveSpeedup(ctx.RuntimeId)
	end)
end

RapidDecay.Speedup = SPEEDUP

return table.freeze(RapidDecay)
