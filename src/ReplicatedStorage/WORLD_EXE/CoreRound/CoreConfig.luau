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
		RunSpeed = 36, -- baseline Humanoid.WalkSpeed (studs/s). Step 1D: PROVISIONAL 36 (owner: running felt slow;
		-- 34 / 36 / 38 compared via CoreTune_Move_RunSpeed; was 30). Not an approved default.
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
		GroundCarryDecay = 8, -- Step 1D: ... and this fast on the ground while you keep moving (same as Step 1C at run 30)
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
		-- added on entry ... Step 1D (owner: the slide must be a real burst, Sojourn reference): PROVISIONAL 16 (compared
		-- 12 / 16 / 20 via CoreTune_Slide_EntryBoost; was 8 in Step 1C). Not an approved default.
		EntryBoost = 16,
		BoostCooldown = 0.9, -- ... only if the last boosted slide started this long ago (rewards paced chaining, no spam)
		MaxEntrySpeed = 58, -- a boosted entry never exceeds this (chaining cannot run away). Step 1D: 46 -> 58 so a
		-- +20 boost on a 38 run is not silently discarded (= Slide.MaxSpeed)
		Friction = 13, -- studs/s per s on flat ground
		SlopeAccel = 75, -- downhill: + SlopeAccel * sin(slope angle); uphill: - (and friction)
		MaxSpeed = 58, -- hard cap while sliding
		MinSpeed = 15, -- slower than this: the slide ends into a run
		SteerRate = 1.7, -- rad/s toward the move input (limited steering)
		MaxSeconds = 3.5,
		ReentryDelay = 0.25, -- seconds between slides
		JumpBoost = 2, -- Step 1C slide-jump (PowerJump = 0): keeps the slide speed plus this
		-- Step 1D: Power Slide Jump (jump while sliding cancels into a high jump; speed is traded for height)
		PowerJump = 1, -- 1 = Power Slide Jump, 0 = the Step 1C slide-jump (comparison)
		PowerJumpUp = 76, -- launch upward speed at PowerJumpFrom slide speed (normal jump: 50.5 -> 6.4 studs). Tuned in
		-- Step 1D from measured ledge tests: 68 could not reach a 16-stud ledge from a normal slide, 76 can ...
		PowerJumpFrom = 36, -- ... slide speed where the conversion starts (the run speed) ...
		PowerJumpConvert = 0.6, -- ... + this much upward speed per stud/s of slide speed above it ...
		PowerJumpMaxUp = 90, -- ... capped (rise ~20.6 studs: a 20-stud ledge needs a fast slide, e.g. downhill)
		PowerJumpKeep = 0.68, -- forward speed after the launch = slide speed * this (the rest became height) ...
		PowerJumpMinForward = 22, -- ... but never less than this
		PowerJumpHoldSeconds = 0.1, -- re-assert the launch this long (the Humanoid's own jump may land after it)
		CoyoteSeconds = 0.12, -- leaving a ledge keeps the slide state this long (no instant cancel on bumps)
		HeadHeight = 0.5, -- FALLBACK slide head centre above the root, for rigs that are not a standard R15 chain. Step 1C:
		-- the server and clients compute it per character from the rig (CoreGeom.PosedHeadOffset; default test avatar 0.19) ...
		BodyTop = 0.0, -- ... body capsule top / bottom relative to the root
		BodyBottom = -1.9,
		-- Step 1C (A1): pose AND hit-volume blend time. The server lowers / raises the slide hit volumes on the same eased
		-- curve over this time (CoreGeom.SlideWeight) that every client uses to draw the slide pose (was 0.12, pose only)
		PoseBlendSeconds = 0.22,
	},
	-- Step 1C (A1): third-person camera offset changes (slide drop, wall push, shoulder) reach ~95% in this time
	Cam = {
		BlendSeconds = 0.25,
	},
	-- Step 1C (owner feedback): the Disc charge ring starts wide and closes to a point on the crosshair at full charge
	Hud = {
		ChargeRingStart = 48, -- ring radius (pixels) when charging starts ...
		ChargeRingEnd = 0, -- ... and at full charge (the dots meet in one point)
	},
	-- Step 1C (A2): client-only speed presentation (screen-edge streaks + team-colour edge glow); off in Reduced FX
	SpeedFx = {
		Enabled = 1,
		MinSpeed = 40, -- streaks start above this horizontal speed (studs/s) ...
		FullSpeed = 75, -- ... and reach full intensity here
		Streaks = 24, -- hard cap on 2D streaks
		StreakAlpha = 0.55, -- max streak opacity
		GlowAlpha = 0.35, -- max edge-glow opacity (dash / Super Dash, and high speed at 60% of this)
		FadeSeconds = 0.25, -- intensity eases in / out over about this long
		ClearRadius = 0.55, -- streaks stay outside this fraction of the half-screen (crosshair, charge ring, arrows)
	},
	-- Step 1B: horizontal wall-run v2 (Titanfall 2 reference, translated to third person). Mode 2 = v2 (default),
	-- 1 = the Step 1 wall-run (upward climb, kept for comparison), 0 = off.
	WallRun2 = {
		Mode = 2,
		MinEntrySpeed = 16, -- speed ALONG the wall needed to attach (automatic while airborne; no button)
		EntryBoost = 5, -- reward for catching a wall. Step 1D: PROVISIONAL 5 (compared 3 / 5 / 8; was 3)
		MinSpeed = 26,
		TargetSpeed = 38, -- eases toward this when slower ...
		Accel = 10,
		MaxSpeed = 60, -- ... and never above this (approach momentum kept up to it). Step 1D: 50 -> 60 so a fast slide or
		-- Power Slide Jump arrival is not cut to a low cruise; still a hard cap, so wall chaining cannot accelerate forever
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
		JumpOut = 48, -- wall jump: away from the wall. Step 1D (owner: jump off further): PROVISIONAL 48 (was 28; measured
		-- 12.3 -> 29.4 studs away from the wall, total 26.3 -> 39.5 studs; 40 + up 48 gave 23.5 / 35.4)
		-- Step 1D (owner: the outward push must be controllable): the camera aims the wall jump. JumpOut = looking AWAY;
		JumpOutMin = 20, -- ... looking toward the wall -> this small push (you still leave the wall) ...
		JumpOutNeutral = 40, -- ... looking along the wall -> this (measured: 34 -> 13.1 studs from the wall, 40 -> 15.7)
		JumpAim = 0.35, -- the launch turns this fraction of the way toward the look direction (never back into the wall)
		JumpSteerRate = 1.2, -- rad/s: during the push-off carry the movement keys steer the flight (speed kept; 2.5 was too strong)
		JumpUp = 48, -- wall jump: upward (Step 1D: 40 -> 48, a little more airtime for the longer push)
		JumpBoost = 4, -- wall jump: extra speed along the run (Titanfall: jumping off a wall boosts speed)
		JumpCarrySeconds = 0.6, -- the push-off keeps its direction this long (air control would cancel it), then normal air control (Step 1D: 0.35 -> 0.6)
		TiltDegrees = 10, -- body lean away from the wall (Step 1C: a blended joint pose; the physical root stays upright)
		CamTiltDegrees = 8, -- Step 1C (A3): optional camera roll away from the wall (0 = off; forced 0 in Reduced FX) ...
		CamTiltInSeconds = 0.25, -- ... eased in ...
		CamTiltOutSeconds = 0.3, -- ... and out
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
		-- Step 1E closeout (security): the AUTHORITATIVE rewind against player characters is a fixed server policy:
		-- rewind = server-measured one-way latency (capped by the engine's own ping, see Net.EnginePingMargin)
		-- + RewindPlayerOffset, capped at RewindMax. The thrower's reported view is DIAGNOSTICS ONLY (logged agreement
		-- measurement); it never selects or trains the rewind (the 615ac22 per-thrower estimate was trained by those
		-- claims and could be drifted to its cap: 3/3 forged hits). RewindPlayerOffset is the server's interpolation
		-- policy. Two-client sessions measured the honest drawn age (beyond the server-measured latency) at 0.08-0.16 s
		-- (2026-11-21) and 0.015-0.094 s (2026-11-22, latency ~0). Honest lead throws at a 49 st/s slider, 2026-11-22:
		-- offset 0.08 -> 0/9 confirmed, 0.05 -> 4/4, 0.03 -> 6/6. Separate from InterpPlayerSeconds (remote pose timing).
		RewindPlayerOffset = 0.05,
		ViewDiagMaxBack = 0.4, -- diagnostics: how far back a reported drawn position is searched for in server history
		ViewMatchTolerance = 1.0, -- studs: (diagnostics) a drawn position must lie on the target's recorded path
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
		-- Step 1E closeout: the script ping depends on the client answering promptly (a client could delay its pongs to
		-- inflate its rewind), so the latency used for rewind is capped at the engine's Player:GetNetworkPing() (not
		-- scriptable by the client) + this margin.
		EnginePingMargin = 0.02,
		-- Step 1B server movement monitor (bounded speed): horizontal speed above the cap for the reported movement
		-- state, sustained for SpeedGraceSeconds, is logged as a violation (detection only in the prototype; see doc).
		SpeedCapRun = 52, -- run / air carry (soft cap 45 + margin)
		SpeedCapSlide = 64, -- slide (max 58 + margin)
		SpeedCapWall = 86, -- wall-run (Step 1D: max 60; a wall-jump exit is up to (60 + 4) along + 48 out = 80 horizontal)
		CarrySeconds = 1.0, -- Step 1D: after a slide / wall-run ends, its cap still applies this long (carried speed)
		VerticalCapNormal = 58, -- Step 1D: upward speed above this is logged ... (normal jump 50.5, wall jump 48)
		VerticalCapPower = 96, -- ... except within PowerJumpWindow after a server-validated slide ended (max launch 90)
		PowerJumpWindow = 0.5,
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
