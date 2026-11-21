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
		-- Step 1B comparison switches (owner: sliding is the primary movement improvement; Super Dash optional)
		DashEnabled = 1, -- 0 = no dash at all
		SuperEnabled = 1, -- 0 = the second press does nothing (plain dash only)
		SpeedFovPerStud = 0.3, -- extra FOV per stud/s above RunSpeed (eased, capped by SpeedFovMax)
		SpeedFovMax = 9,
		LandingDipStuds = 0.45, -- camera dips this much on a hard landing (fall speed >= LandingDipFallSpeed), springs back
		LandingDipFallSpeed = 45,
	},
	-- Step 1B: momentum slide (Fortnite / Warframe / Titanfall 2 references: crouch while running starts it, a slide is
	-- mostly ground movement with reduced steering, downhill speeds it up, jumping out keeps the speed)
	Slide = {
		MinStartSpeed = 16, -- horizontal speed needed to start (from a run)
		EntryBoost = 8, -- added on entry (Titanfall 2 reference: a clear initial boost that dials back) ...
		BoostCooldown = 0.9, -- ... only if the last boosted slide started this long ago (rewards paced chaining, no spam)
		MaxEntrySpeed = 46, -- a boosted entry never exceeds this (chaining cannot run away)
		Friction = 13, -- studs/s per s on flat ground
		SlopeAccel = 75, -- downhill: + SlopeAccel * sin(slope angle); uphill: - (and friction)
		MaxSpeed = 58, -- hard cap while sliding
		MinSpeed = 15, -- slower than this: the slide ends into a run
		SteerRate = 1.7, -- rad/s toward the move input (limited steering)
		MaxSeconds = 3.5,
		ReentryDelay = 0.25, -- seconds between slides
		JumpBoost = 2, -- slide-jump keeps the slide speed plus this (carried by the air momentum)
		CoyoteSeconds = 0.12, -- leaving a ledge keeps the slide state this long (no instant cancel on bumps)
		HeadHeight = 0.5, -- hit volumes while sliding (server + client): head centre above the root (measured: posed head 0.51) ...
		BodyTop = 0.0, -- ... body capsule top / bottom relative to the root
		BodyBottom = -1.9,
		PoseBlendSeconds = 0.12,
	},
	-- Step 1B: horizontal wall-run v2 (Titanfall 2 reference, translated to third person). Mode 2 = v2 (default),
	-- 1 = the Step 1 wall-run (upward climb, kept for comparison), 0 = off.
	WallRun2 = {
		Mode = 2,
		MinEntrySpeed = 16, -- speed ALONG the wall needed to attach (automatic while airborne; no button)
		EntryBoost = 3, -- small reward for catching a wall
		MinSpeed = 26,
		TargetSpeed = 38, -- eases toward this when slower ...
		Accel = 10,
		MaxSpeed = 50, -- ... and never above this (approach momentum kept up to it)
		RiseKeep = 12, -- at most this much of YOUR jump's upward speed is kept on entry (no added climb)
		Gravity = 18, -- gentle pull down while on the wall (studs/s per s; tuned in Step 1B: 32 ended ground-level runs in 0.8 s) ...
		MaxSink = 12, -- ... capped
		Seconds = 1.8, -- then you drop off with your speed
		Reach = 3.3, -- side ray length from the root
		RequireTallWall = 0, -- 0 = a waist-height contact is enough (Titanfall 2 reference); 1 = also need a contact 1.6 higher
		Stick = 3, -- small pull toward the wall
		SameWallDelay = 0.6, -- the same wall cannot be re-caught for this long
		PeelDot = 0.6, -- pushing away from the wall this hard ...
		PeelSeconds = 0.1, -- ... this long detaches
		JumpOut = 28, -- wall jump: away from the wall
		JumpUp = 40, -- wall jump: upward
		JumpBoost = 4, -- wall jump: extra speed along the run (Titanfall: jumping off a wall boosts speed)
		JumpCarrySeconds = 0.35, -- the push-off keeps its direction this long (air control would cancel it), then normal air control
		TiltDegrees = 10, -- lean away from the wall (eased)
		AlignResponsiveness = 18, -- orientation easing (no snapping)
		CamPush = 1.2, -- third-person camera eases this far away from the wall
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
		-- Step 1B: hold-to-charge (Knockout City reference: tap = quick throw, hold = charged throw). Charge only
		-- changes flight speed / range / recovery: never damage, stun values or shield blocking.
		TapSeconds = 0.15, -- released sooner than this = an uncharged (tap) throw
		ChargeSeconds = 0.9, -- hold time from tap threshold to full charge
		ChargedOutSpeed = 200, -- out speed at full charge (tap = OutSpeed)
		ChargedRange = 115, -- range at full charge (tap = Range)
		ChargedReturnSpeed = 175, -- return speed at full charge (tap = ReturnSpeed)
		ChargedMaxFlightSeconds = 3.2, -- snap timeout at full charge (tap = MaxFlightSeconds)
		ChargedRethrowSeconds = 0.6, -- recovery after catching a full-charge throw (tap = RethrowSeconds)
		ChargeMoveScale = 1.0, -- movement speed while charging (1 = no slow)
		ChargeSlack = 0.08, -- server: claimed charge may exceed the server-timed charge by at most this
		MaxHoldSeconds = 10, -- server: a charge held longer is treated as stale (falls back to the server time cap)
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
		-- Step 1B server movement monitor (bounded speed): horizontal speed above the cap for the reported movement
		-- state, sustained for SpeedGraceSeconds, is logged as a violation (detection only in the prototype; see doc).
		SpeedCapRun = 52, -- run / air carry (soft cap 45 + margin)
		SpeedCapSlide = 64, -- slide (max 58 + margin)
		SpeedCapWall = 58, -- wall-run (max 50 + jump boost + margin)
		SpeedCapBurst = 125, -- dash / Super Dash windows (dash 104)
		SpeedGraceSeconds = 0.35,
		TeleportStuds = 30, -- a single-frame position jump larger than this (not explained by speed) is logged
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
