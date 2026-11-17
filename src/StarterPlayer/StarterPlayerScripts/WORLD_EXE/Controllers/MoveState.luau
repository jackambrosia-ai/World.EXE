--!strict
-- MoveState (prototype, client): ONE owner of the local character's velocity at a time.
-- Rev 15 architecture for future movement states (owner: wall-running later, MOV-03):
--   nil          = normal Humanoid running (fast baseline WalkSpeed); nothing overrides velocity
--   "dash"       = first-Q grounded dash (MovementController)
--   "super"      = second-Q steerable super-speed (MovementController)
--   "flingSelf"  = FLING SELF carry + air control (HackController)
--   "wallrun"    = wall-running (WallRun, Rev 15g); "walljump" = the short carry after a wall jump
--   (future)     "wallrun" — would claim ownership here, read the wall normal, and release on exit;
--                nothing in this prototype assumes the character is always grounded or that velocity
--                is only horizontal (dash/super drive the horizontal plane only and leave Y to physics).
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
