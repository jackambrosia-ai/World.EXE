--!strict
-- SUPER_BOUNCE combination (ZERO_G + BOUNCY, Phase 7A): boosts BOUNCY launches x1.5 while both
-- sources run. The launch stays clamped by Bouncy's apex limit under the current gravity. The
-- boost token is removed when the combination ends (either source ending ends it).

local Bouncy = require(script.Parent:WaitForChild("Bouncy"))

local BOOST = 1.5

local SuperBounce = {}

function SuperBounce.Activate(ctx: any)
	Bouncy.AddBoost(ctx.RuntimeId, BOOST)
	ctx.Add(function()
		Bouncy.RemoveBoost(ctx.RuntimeId)
	end)
end

SuperBounce.Boost = BOOST

return table.freeze(SuperBounce)
