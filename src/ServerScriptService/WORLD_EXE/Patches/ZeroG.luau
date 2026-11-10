--!strict
-- ZERO_G (Phase 4): low gravity for the patch's active period.
-- One WorldModifierService "multiply" token owned by the patch. It composes deterministically
-- with any other gravity token, and is removed (gravity recomputed) when the patch ends for any
-- reason. This module never writes Workspace.Gravity.

-- Server-only tuning. 0.3 x 196.2 = 58.9: a standard jump rises ~21 studs (normal ~6.4), enough to
-- feel weightless while every landing stays inside the arena (arena ceiling is ~90 studs).
local GRAVITY_MULTIPLIER = 0.3

local ZeroG = {}

function ZeroG.Activate(ctx: any)
	ctx.AddModifier("Gravity", "multiply", GRAVITY_MULTIPLIER)
end

ZeroG.GravityMultiplier = GRAVITY_MULTIPLIER

return table.freeze(ZeroG)
