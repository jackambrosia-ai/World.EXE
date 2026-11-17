--!strict
-- MoveState (prototype, client): ONE owner of the local character's velocity at a time.
--   nil          = normal Humanoid running (fast baseline WalkSpeed); nothing overrides velocity
--   "dash"       = Q grounded dash (MovementController)
--   "super"      = super-speed spent from a diamond while the dash cools; chained bursts keep it (MovementController)
--   "flingSelf"  = FLING SELF carry + air control (HackController)
--   "wallrun"    = wall-running (WallRun, Rev 15g-15m); "walljump" = the short horizontal carry after a wall
--                  jump or (Rev 15m) a flowing wall-run exit
-- Hand-overs (forced claims): FLING SELF overrides dash / super; a wall run (Rev 15m) may take over a dash or
-- a FLING SELF flight. A system that loses ownership stops its own constraint (drive / carry / fling control);
-- FLING SELF's blue aura is a visual-flight state and is NOT tied to ownership (HackController).
-- Claim returns false when another state owns the velocity, so systems never fight each other.

local MoveState = {}

local owner: string? = nil
local since = 0

function MoveState.Owner(): string?
	return owner
end

function MoveState.Claim(name: string, force: boolean?): boolean
	if owner ~= nil and owner ~= name and not force then
		return false
	end
	owner = name
	since = os.clock()
	return true
end

function MoveState.Release(name: string)
	if owner == name then
		owner = nil
	end
end

function MoveState.Since(): number
	return since
end

return MoveState
