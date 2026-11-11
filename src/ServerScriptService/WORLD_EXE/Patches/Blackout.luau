--!strict
-- BLACKOUT (Phase 7A): darkens the arena through WorldModifierService tokens (never writes
-- Lighting directly). Lighting.Brightness is set low and ExposureCompensation lowered; both are
-- clamped to readable minimums in Config.WorldModifiers. Neon hazards, prompts, the HUD and
-- SCANNER highlights stay visible. The tokens are removed (exact baseline restored) when the patch
-- ends for any reason.

-- Server-only tuning (provisional).
local BRIGHTNESS = 0.5
local EXPOSURE_DELTA = -1.2

local Blackout = {}

function Blackout.Activate(ctx: any)
	ctx.AddModifier("Brightness", "set", BRIGHTNESS, 5)
	ctx.AddModifier("ExposureCompensation", "add", EXPOSURE_DELTA)
end

Blackout.Tuning = table.freeze({ Brightness = BRIGHTNESS, ExposureDelta = EXPOSURE_DELTA })

return table.freeze(Blackout)
