--!strict
-- HUNTER_SCAN combination (BLACKOUT + DRONE_SWARM, Phase 7A): drones show visible scan cones,
-- acquire targets from 20% farther away, and must hold a visible amber pre-lock warning for
-- DroneSwarm's PRELOCK_SECONDS before a new lock. Damage rules are unchanged. All of it lives in
-- DroneSwarm behind a hunter token, removed when the combination ends.

local DroneSwarm = require(script.Parent:WaitForChild("DroneSwarm"))

local HunterScan = {}

function HunterScan.Activate(ctx: any)
	DroneSwarm.AddHunter(ctx.RuntimeId)
	ctx.Add(function()
		DroneSwarm.RemoveHunter(ctx.RuntimeId)
	end)
end

return table.freeze(HunterScan)
