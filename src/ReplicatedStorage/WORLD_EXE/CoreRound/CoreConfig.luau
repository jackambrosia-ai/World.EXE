--!strict
-- CoreConfig (Core Round Step 1 prototype, shared). Every tunable value of the Step 1 movement and combat
-- prototype lives here. All values are PROVISIONAL (Core Round v1.1 spec + closeout addendum, 2026-11-20).
--
-- Isolation: nothing in WORLD_EXE/CoreRound runs unless Workspace.WORLD_EXE_CoreRound == true. Only the
-- script-built Step 1 test place sets it (tools/studio/coreround/cr_20_build_yard.luau). Production places never do.
--
-- Live tuning: a Workspace number attribute "CoreTune_<Group>_<Key>" overrides Tuning[Group][Key]
-- (e.g. CoreTune_Move_RunSpeed = 32). Bad values (non-number, NaN, negative, >= 10000) are ignored.

local CoreConfig = {}

CoreConfig.GateAttribute = "WORLD_EXE_CoreRound"

function CoreConfig.Enabled(): boolean
	return workspace:GetAttribute(CoreConfig.GateAttribute) == true
end

CoreConfig.Tuning = {
	Move = {
		RunSpeed = 30, -- baseline Humanoid.WalkSpeed (studs/s)
		Charges = 2, -- Super Dash charges
		ChargeRegenSeconds = 2.5, -- each charge, one after the other, ground or air
		DashDistance = 26, -- normal dash distance ...
		DashSeconds = 0.25, -- ... over this time (speed = 104 studs/s)
		SuperWindow = 0.40, -- a second press up to this long after the first press turns the dash into a Super Dash
		SuperSeconds = 1.0, -- steerable burst
		SuperSpeed = 70,
		SuperTurnRate = 5.5, -- rad/s the burst heading turns toward the held direction / camera
		SlipSpeed = 38, -- every dash ends at this speed ...
		SlipSeconds = 1.0, -- ... easing back to RunSpeed over this time while you keep moving
		SoftCap = 45, -- all speed sources share this soft cap (Super Dash exempt while it lasts) ...
		SoftCapDecay = 30, -- ... speed above it decays at this rate (studs/s per s)
		AirCarryDecay = 6, -- boosted speed kept through a jump decays this fast in the air (studs/s per s)
		WallJumpBoost = 4, -- jumping off a wall-run adds this to the carried speed
		FovBase = 70,
		FovDash = 6, -- extra FOV degrees during a dash
		FovSuper = 10, -- extra FOV degrees during a Super Dash
		MinPressGap = 0.06, -- server: dash presses closer than this are ignored (input spam)
	},
	Disc = {
		Range = 70, -- outbound distance before turning back (rebound distance counts toward it)
		OutSpeed = 130,
		ReturnSpeed = 150,
		Radius = 0.6, -- disc collision radius for hits / walls
		CatchRadius = 3.0, -- auto-catch distance to the owner's root
		RethrowSeconds = 0.25, -- after a catch
		MaxFlightSeconds = 2.5, -- not caught by then: snaps back ...
		SnapPenaltySeconds = 1.5, -- ... and cannot be thrown for this long
		Bounces = 1, -- reflects once off an eligible wall
		HitTolerance = 0.15, -- extra radius on hit volumes
		-- Hit volumes (rig-agnostic, from the root part and the Head part):
		HeadRadius = 0.85, -- sphere around the Head part centre
		BodyRadius = 1.35, -- capsule radius ...
		BodyTop = 1.6, -- ... from root + this (studs, up) ...
		BodyBottom = -2.9, -- ... down to root + this
		-- Lag compensation (provisional; measured in the Step 1 latency test):
		RewindMode = 1, -- 0 = test against current server positions; 1 = rewind targets by the thrower's latency
		RewindMax = 0.25, -- seconds, cap
		-- rewind = thrower one-way latency + an interpolation term per TARGET type (Step 1 measurement, solo shaping:
		-- a server-moved dummy is seen ~one-way late with no extra buffer, so 0 gave the best agreement; player
		-- characters replicate through the physics interpolation buffer: 0.05 is an UNVERIFIED estimate)
		InterpSeconds = 0, -- server-moved targets (dummies)
		InterpPlayerSeconds = 0.05, -- other players' characters (needs two-client calibration)
		CatchUpMax = 0.12, -- the server disc is advanced by the thrower's one-way latency up to this (matches the predicted visual)
		OriginTolerance = 8, -- client-reported throw origin must be within this of the server root (+ speed * latency)
		-- Duplicate-hit protection. Step 1 finding: the returning disc homes back along nearly the same line, so with
		-- the v1.1 rule (out + return both count, 0.4 s dedupe) ONE throw at a still target lands two hits (~0.7 s
		-- apart) and a single head throw stuns (50 + 50). Default 1 = a throw hits a given target at most once (out OR
		-- return); 2 = the v1.1 rule (both passes, ReturnDedupeSeconds apart). Owner decision.
		SameTargetPerThrow = 1,
		ReturnDedupeSeconds = 0.4, -- (mode 2) a return-pass hit this soon after an outbound hit on the same target is ignored
		TrailSeconds = 0.6, -- trail stays visible this long
		FireRateLimit = 8, -- server: max throw requests per second (spam guard)
	},
	Disrupt = {
		Body = 30,
		Head = 50,
		Threshold = 100,
		DecayDelay = 2.5, -- seconds without a hit before the meter drains ...
		DecayRate = 40, -- ... at this rate per second
		StunSeconds = 0.8,
		ImmuneSeconds = 3.0, -- after a stun: no meter gain
		NudgeStuds = 3, -- small flinch push on a non-stunning hit
	},
	Shield = {
		Width = 8,
		Height = 7,
		Forward = 3, -- panel centre this far in front of the root
		Lift = 0.5, -- panel centre this far above the root
		Energy = 100,
		DrainPerSecond = 20,
		BlockCost = 15,
		RegenDelay = 1.0,
		RegenPerSecond = 25,
		BrokenSeconds = 2.5,
		SpeedScale = 0.7, -- movement speed while raised
		AimRate = 12, -- client aim updates per second while raised
		RaiseSeconds = 0.12, -- deploy animation (visual only; blocking starts at once on the server)
	},
	Net = {
		RateLimitPerSecond = 30, -- generic remote budget per player
		RttBiasSeconds = 0.025, -- removed from the server-measured round trip (frame quantisation, measured in Step 1)
	},
	-- Optional wall-run (copied from PR #22 Rev 15s values; owner-reviewed there). Not needed for any objective.
	WallRun = {
		MinSpeed = 8,
		Speed = 36,
		Seconds = 4.0,
		ClimbSpeed = 30,
		AirClimbScale = 0.75,
		ClimbSeconds = 1.0,
		MaxSink = 6,
		TopClearance = 2.6,
		SideFacingMaxDot = 0.5,
		Gravity = 9,
		Reach = 3.2,
		Stick = 4,
		JumpOut = 40,
		JumpUp = 50,
		JumpCarrySeconds = 0.5,
		EdgeJumpGrace = 0.3,
		LeanDegrees = 8,
		ReattachDelay = 0.35,
		Flow = 2,
		EntryBlendSeconds = 0.14,
		MaxEntrySpeed = 52,
		SpeedSettle = 18,
		BackBrake = 40,
		MinCruise = 16,
		PeelDot = 0.6,
		PeelSeconds = 0.12,
		PeelOut = 16,
		ExitCarrySeconds = 0.25,
		ForwardLeanDegrees = 7,
		AnimRate = 1.5,
		RunAnimStuds = 14.8,
		StepsVolume = 0.45,
		CamPushOut = 2.5,
		CamLift = 0.6,
		PlantedLeanDegrees = 18,
	},
}

function CoreConfig.Tune(group: string, key: string): number
	local v = workspace:GetAttribute("CoreTune_" .. group .. "_" .. key)
	if typeof(v) == "number" and v == v and v >= 0 and v < 10000 then
		return v
	end
	local g = (CoreConfig.Tuning :: any)[group]
	local d = g and g[key]
	assert(typeof(d) == "number", "unknown tuning " .. group .. "." .. key)
	return d
end

-- Team colours (team = Roblox Team; dummies use the CR_Team attribute). Unknown -> neutral white.
CoreConfig.TeamColors = {
	Cyan = Color3.fromRGB(40, 220, 255),
	Orange = Color3.fromRGB(255, 140, 40),
}
CoreConfig.NeutralColor = Color3.fromRGB(235, 235, 235)

return CoreConfig
