--!strict
-- HackCatalog (WRIST-HACKING PROTOTYPE, owner-approved isolated milestone 2026-11-16).
-- The ONE bounded effect library used by BOTH the quick-hack chips and the typed wrist terminal.
-- Typed text is never executed: Parse() maps it to one of these ids plus a target hint, and the
-- server re-parses typed text and must reach the same id. Replicated so the client can show chips,
-- aliases and tuning. Every number here is PROVISIONAL prototype tuning, not final balance.
--
-- Separate from Architect patches by design: different ids, remotes, services and cooldowns.
-- Active only in places whose Workspace has attribute WORLD_EXE_HackPrototype = true.

export type HackDef = {
	Id: string,
	DisplayName: string,
	Short: string, -- chip label
	Icon: string, -- text glyph (no uploaded assets)
	Serial: string,
	Category: string, -- UITheme category (colour + glyph + code)
	Target: string, -- "self" | "other"
	Effect: string, -- one-line description shown on the chip / info line
	Order: number,
}

local HackCatalog = {}

HackCatalog.PrototypeAttribute = "WORLD_EXE_HackPrototype"
HackCatalog.RemoteFolder = "HackRemotes"
HackCatalog.RequestRemote = "HackRequest" -- client -> server (intent only)
HackCatalog.EventRemote = "HackEvent" -- server -> client
HackCatalog.TargetTag = "HackTarget" -- Models with a Humanoid that hacks may target (NPCs, boss)
HackCatalog.BossTag = "HackBoss"

-- Player / target attributes (server-set, replicated; clients only read them).
HackCatalog.Attr = table.freeze({
	ReadyPrefix = "WORLD_EXE_HackReady_", -- + hack id = server time the hack is ready again
	ShieldUntil = "WORLD_EXE_HackShieldUntil", -- on the Player
	ShieldStart = "WORLD_EXE_HackShieldStart", -- on the Player (perfect-deflect timing)
	Boots = "WORLD_EXE_Boots", -- on the Player: cyberware boots profile id
	NpcShieldUntil = "HackNpcShieldUntil", -- on NPC models (test-station reactions)
	NpcShieldStart = "HackNpcShieldStart",
	FrozenUntil = "HackFrozenUntil", -- on the target character / NPC model
	RagdollUntil = "HackRagdollUntil",
	FreezeImmuneUntil = "HackFreezeImmuneUntil",
	FlingImmuneUntil = "HackFlingImmuneUntil",
	TargetId = "HackTargetId", -- NPC / boss models
	BossChallenge = "BossChallenge", -- on the boss: "ResistanceBattle" | "InputChase" | "SignalLock"
	BossState = "BossState", -- IDLE | CHARGING | VULNERABLE | FROZEN | STAGGERED | OFFLINE
	BossIntegrity = "BossIntegrity",
})

local definitions: { HackDef } = {
	{ Id = "FLING_SELF", DisplayName = "Fling Self", Short = "FLING SELF", Icon = "▲", Serial = "HX-01", Category = "Physics", Target = "self",
		Effect = "Launch yourself up and forward. You keep control; no ragdoll.", Order = 1 },
	{ Id = "FLING_TARGET", DisplayName = "Fling Target", Short = "FLING", Icon = "»", Serial = "HX-02", Category = "Entity", Target = "other",
		Effect = "Grab a target. Click with the cursor above, beside or below screen centre: up, sideways or behind you.", Order = 2 },
	{ Id = "FREEZE", DisplayName = "Freeze", Short = "FREEZE", Icon = "❄", Serial = "HX-03", Category = "Environment", Target = "other",
		Effect = "Freeze a target for about 3 s. Bosses resist (shorter).", Order = 3 },
	{ Id = "SHIELD", DisplayName = "Shield", Short = "SHIELD", Icon = "◈", Serial = "HX-04", Category = "Beneficial", Target = "self",
		Effect = "Protect yourself from Conductor attacks for 6 s. Self only.", Order = 4 },
}

local byId: { [string]: HackDef } = {}
local ids: { string } = {}
table.sort(definitions, function(a, b)
	return a.Order < b.Order
end)
for _, def in definitions do
	table.freeze(def)
	byId[def.Id] = def
	table.insert(ids, def.Id)
end
table.freeze(ids)

function HackCatalog.Get(id: string): HackDef?
	return byId[id]
end

function HackCatalog.Ids(): { string }
	return ids
end

---------------------------------------------------------------------------------------------------
-- Provisional tuning (prototype configuration). Studs, studs/s, seconds.
HackCatalog.Tuning = table.freeze({
	-- Rev 15 movement (owner-authorized prototype; provisional values, tune by playtest):
	-- fast baseline run, first Q = grounded dash, second Q inside [SuperMin, SuperMax] after the dash
	-- = steerable super-speed. A second Q earlier than SuperMin VOIDS the window (spam-proof).
	Move = table.freeze({
		RunSpeed = 28, -- baseline Humanoid.WalkSpeed (Roblox default 16)
		DashSpeed = 115, -- studs/s, horizontal only (Rev 15b: owner "not substantial enough" — was 88)
		DashSeconds = 0.3, -- ≈25-30 studs (was 0.17 s ≈ 11 studs measured; 0.24 s measured 19-21)
		DashCooldownRatio = 0.25, -- owner 2026-11-16: halved again -> a quarter of the super-speed cooldown (11 s -> 2.75 s)
		SuperMin = 0.2, -- second Q earlier than this after the dash: too early (voids the window)
		SuperMax = 0.8, -- later than this: expired (counts as a fresh first Q)
		SuperSeconds = 1.0, -- MOV-02: ≈1 s bursts
		SuperSpeed = 74,
		SuperTurnRate = 10, -- rad/s cap on turning (Rev 15g smoother: was 14)
		SuperSteerSmoothing = 7, -- exponential steering response (higher = snappier)
		SuperAccelSeconds = 0.14, -- eased ramp up to SuperSpeed (Rev 15g: was instant)
		SuperEaseOutSeconds = 0.32, -- eased return to run speed at the end (was 0.15 s linear)
		SuperFollowUps = 2, -- owner 2026-11-16: usable 2 more times after the Q-Q activation (single Q each)
		SuperFollowWindow = 2.5, -- seconds after a burst ends to fire the next one; the cooldown starts when the chain ends
		SuperCooldown = 11, -- 10-12 s starting range
		FovRun = 3, -- extra degrees at full run speed
		FovSuper = 9, -- extra degrees during super-speed
	}),
	-- Rev 15g (owner 2026-11-16: "the wall run still needs to be implemented"; reference MOV-03). Client
	-- movement (Controllers/WallRun): airborne + moving fast + wall at your side -> run along it; Space jumps off.
	WallRun = table.freeze({
		MinSpeed = 8, -- horizontal studs/s needed (just "moving": the start is a deliberate Space press; hugging a wall slows you)
		Speed = 36, -- along-wall speed (or your current speed if faster)
		Seconds = 4.0, -- max wall-run time (MOV-03: ~4 s along building faces), then you drop off
		-- Rev 15i (owner: must move UPWARD, not glide): MOV-03 runs up the wall on latching, then comes down
		ClimbSpeed = 30, -- upward speed when latching from the ground (eases to 0 over ClimbSeconds: ~15 studs up)
		AirClimbScale = 0.75, -- latching mid-air climbs a little less
		ClimbSeconds = 1.0,
		MaxSink = 6, -- then a gentle descent, capped at this speed ...
		TopClearance = 2.6, -- stop climbing when the wall ends this far above the root (top edge)
		SideFacingMaxDot = 0.5, -- owner: the wall must be at the player's side: |look . wall normal| <= this
		Gravity = 9, -- ... building up at this rate (studs/s per s)
		Reach = 3.2, -- side ray length from the root to find a wall
		Stick = 4, -- pull toward the wall when drifting off it
		JumpOut = 40, -- wall jump: away from the wall
		JumpUp = 50, -- wall jump: upward
		JumpCarrySeconds = 0.5, -- the jump keeps its horizontal push this long (air control would cancel it)
		LeanDegrees = 8, -- slight tilt away from the wall (MOV-03 runner is nearly upright)
		ReattachDelay = 0.35, -- seconds before another wall run can start
	}),
	FlingSelf = table.freeze({
		Up = 90, -- initial vertical velocity (apex ~ Up^2 / (2 * 196.2) = 20.6 studs). Sweep 2026-11-16: A 78/48, B 90/42 (chosen), C 98/48
		Forward = 42, -- horizontal launch speed along the intended direction (~39 studs on flat ground)
		SteerSpeed = 24, -- extra horizontal speed from movement input mid-air (owner 2026-11-16: more fall control; was 16)
		TurnRate = 3.0, -- rad/s the launch carry turns toward the held direction
		BrakeRate = 45, -- studs/s per s the carry slows when holding the opposite direction
		MaxFallSpeed = 75, -- downward speed cap during the fling (free fall would reach ~90)
		GlideFallSpeed = 28, -- holding Jump while falling caps the descent here (slow, steerable fall)
		MinAirSeconds = 0.2, -- landing is not checked before this
		MaxFlightSeconds = 4.0, -- the carry and fall control always end by this time (longer for gliding)
		BlockedSpeedFraction = 0.3, -- carry ends early when the measured speed falls below this share (wall)
		Cooldown = 3,
		-- Owner rule (2026-11-16): FLING SELF never ragdolls you (only other players / bosses ragdoll).
	}),
	FlingTarget = table.freeze({
		-- Matched to the owner reference clip: apex ~32 studs, ~1.2 s airtime, ~35 studs travel.
		Up = 112,
		Forward = 32,
		TumbleSpeed = 7, -- rad/s spin across the flight direction (limp body tumbles in the air)
		RagdollSeconds = 1.2, -- minimum limp time
		MinAirSeconds = 0.5, -- landing is not checked before this
		LandRecoverDelay = 0.9, -- stays down this long after touching the ground, then gets up
		MaxRagdollSeconds = 5.0, -- hard cap: recovery always runs by this time
		ImmunitySeconds = 4, -- after recovery the same target cannot be flung again
		Range = 55,
		Cooldown = 8,
		BossUp = 80, -- the boss ragdolls too (owner rule), with a lower arc than players
		BossForward = 24,
		FlickWindow = 0.6, -- after a successful FLING cast: slide the mouse within this to aim; else thrown away
		-- Slide-thrown (aimed) FLING, owner 2026-11-16 "mostly sideways, low arc": the target travels
		-- along the slid direction with a small hop instead of the tall launch (kept for no-slide throws).
		AimedUp = 50,
		AimedForward = 80,
		BossAimedUp = 40,
		BossAimedForward = 55,
		-- Slide-throw style (owner 2026-11-16: the low-arc launch still "feels like an explosion"):
		-- 1 = GLIDE (banana-peel style: drops flat, glides along the ground in the slid direction,
		-- slowing smoothly; distance ≈ GlideSpeed × GlideSeconds / 2.6), 0 = the rev 8 low-arc launch.
		AimedStyle = 2, -- 2 = GRAB (gravity-gun hold, owner 2026-11-16, default), 1 = glide, 0 = launch
		-- GRAB: held HoldHeight up, pulled toward the attacker's cursor (within HoldLeash), thrown on
		-- left-click the way the mouse is dragged (ThrowSpeed + power × ThrowBonus), auto-thrown after HoldSeconds.
		HoldSeconds = 2, -- owner 2026-11-16: "cut it's duration to 2 seconds"
		HoldHeight = 0, -- owner 2026-11-16: no levitation; shocked where it stands
		HoldLeash = 32,
		HoldWiggle = 0, -- owner 2026-11-16: held target stays where it was shocked (was 4: sway toward the cursor)
		ShockJitter = 9, -- rad/s of random limb twitching while held (electrocuted look)
		HoldResponsiveness = 18,
		HoldMaxSpeed = 70,
		ThrowSpeed = 65,
		ThrowBonus = 35,
		ThrowUp = 22,
		BossThrowScale = 0.6,
		UpThrowSpeed = 90, -- cursor ABOVE screen centre at the click: launched up (+ power × UpThrowBonus) and forward (UpThrowForward)
		UpThrowBonus = 30,
		UpThrowForward = 32, -- owner 2026-11-16: the up-throw still launches the target forward (away from the attacker)
		UpThrowForwardBonus = 10, -- + power x this
		BackThrowUp = 45, -- cursor BELOW centre: thrown back over and past the attacker (higher arc to clear them)
		-- Rev 15 (owner-authorized): longer, more impactful post-throw ragdoll, measured FROM THE THROW.
		-- Recovery needs: PostThrowSeconds elapsed AND torso grounded AND settled (speed < SettleSpeed for
		-- 0.15 s), so a target never stands up mid-air; PostThrowCap is the hard safety cap (always recovers).
		PostThrowSeconds = 3.0, -- tested 2.5 / 3.0 / 3.5 (Workspace HackTune_FlingTarget_PostThrowSeconds)
		PostThrowCap = 5.5,
		SettleSpeed = 6,
		-- Rev 15d (owner): thrown targets look dragged by the torso (chest pulled + facing the throw, limbs trail)
		DragLeanDegrees = 50, -- upper body pitched forward into the pull (legs trail behind)
		DragTrailStart = 0.3, -- limbs start at this share of the launch speed (torso yanks them)
		DragTrailDamping = 7, -- per-second horizontal damping on non-torso parts while dragged
		DragSeconds = 1.1, -- the chest pull lasts this long from the throw, through the air AND the ground slide, easing to half speed
		GlideSpeed = 85,
		GlideSeconds = 1.8,
		GlideRestSeconds = 0.6, -- stays down this long after the glide stops, then gets up
		BossGlideSpeed = 55,
		BossGlideSeconds = 1.3,
	}),
	Freeze = table.freeze({
		Seconds = 3, -- owner setting
		ImmunitySeconds = 4, -- after a freeze ends the same target cannot be frozen again (anti stun-lock)
		Range = 55,
		Cooldown = 10,
		BossSeconds = 1.5, -- bosses resist: shorter freeze
		BossImmunitySeconds = 6,
	}),
	Shield = table.freeze({
		Seconds = 6, -- owner setting
		Cooldown = 12, -- starts at activation, so no refresh is possible while active
	}),
	-- Targeted-hack warning and counterplay (owner directive 2026-11-16, section 7). Defences are checked
	-- in this order when the window ends: SHIELD active (deflect; perfect if raised in the last
	-- PerfectWindow seconds) -> line of sight blocked by cover (evaded) -> target outside the impact
	-- ring (dodged) -> the hack lands.
	Incoming = table.freeze({
		ReactionWindow = 1.0, -- seconds between the warning and the resolution
		LatencyGrace = 0.12, -- extra server seconds for replicated movement / input
		DodgeRadius = 9, -- impact ring radius (studs) around the target at warning start
		PerfectWindow = 0.3, -- shield raised this close to resolution = perfect deflect (0 = off)
		PerfectShieldRefund = 0.5, -- perfect deflect refunds this share of the SHIELD cooldown (modest benefit)
		MinWarning = 0.5, -- FLING (armed at cast start): the throw never lands sooner than this after the warning
		MaxArmedSeconds = 25, -- safety: an armed warning is withdrawn after this
	}),
	Rate = table.freeze({ Burst = 14, PerSecond = 9 }), -- per player, all hack messages incl. arrow presses (fast players reach ~6/s; test 2026-11-16 hit 4/s)
	RetrySeconds = 1.5, -- after a failed/cancelled challenge, the same hack waits this long
	LineOfSight = true, -- targeted hacks need a clear line (collidable geometry blocks)
})

-- Cyberware prototype (non-persistent sidegrades, owner directive 2026-11-16 section 11). The starter kit must be
-- strong; alternatives trade one strength for another. Selected at the test station (player attribute Boots).
HackCatalog.Boots = table.freeze({
	Starter = table.freeze({ Label = "STARTER IMPULSE BOOTS", Up = 90, Forward = 42, SteerSpeed = 24, TurnRate = 3.0, Note = "balanced arc, full air control" }),
	Vault = table.freeze({ Label = "VAULT BOOTS", Up = 106, Forward = 30, SteerSpeed = 20, TurnRate = 3.0, Note = "higher, shorter" }),
	Vector = table.freeze({ Label = "VECTOR BOOTS", Up = 74, Forward = 64, SteerSpeed = 22, TurnRate = 2.2, Note = "longer, lower, wider turns" }),
})
HackCatalog.BootOrder = table.freeze({ "Starter", "Vault", "Vector" })

-- Live tuning overrides for prototype testing: a number attribute on Workspace named
-- "HackTune_<Group>_<Key>" (e.g. HackTune_FlingSelf_Up = 90) replaces the default above.
-- Lets the owner try values in Studio without code changes. Read at use time.
function HackCatalog.Tune(group: string, key: string): number
	local v = workspace:GetAttribute("HackTune_" .. group .. "_" .. key)
	if typeof(v) == "number" and v == v and v >= 0 and v < 1000 then
		return v
	end
	return (HackCatalog.Tuning :: any)[group][key]
end

-- Activation challenges. Symbols (Rev 15): "1".."4" (Signal Lock "1".."5"; see Challenge.Symbols).
HackCatalog.Challenge = table.freeze({
	-- Self hacks: FLING SELF none (traversal must feel instant), SHIELD one arrow (minimal).
	SelfLength = table.freeze({ FLING_SELF = 0, SHIELD = 1 }),
	SelfTimeLimit = 2.5,
	-- Targeted hacks on players / NPCs: a short ordered sequence by the HACKER (not the victim).
	Target = table.freeze({ Length = 3, TimeLimit = 4.5, MaxMisses = 2 }),
	-- Boss hacks: one selectable variant at a time (boss attribute BossChallenge).
	BossVariants = table.freeze({ "ResistanceBattle", "InputChase", "SignalLock" }),
	-- Rev 15: number keys per challenge kind. 5 is reserved for the timing-precision variant (Signal
	-- Lock); length, difficulty and symbol count are independent tuning variables.
	Symbols = table.freeze({ Sequence = 4, ResistanceBattle = 4, InputChase = 4, SignalLock = 5 }),
	ResistanceBattle = table.freeze({
		Length = 6, -- inputs required before success is possible
		StartProgress = 0.25,
		Gain = 0.2, -- per correct input
		Drain = 0.16, -- per second, boss resistance
		DrainCharging = 0.22, -- while the boss telegraphs an attack
		DrainVulnerable = 0.06, -- during the boss's vulnerability window
		Threshold = 1.0, -- progress needed (after Length inputs); extra arrows are appended until reached
		MissPenalty = 0.08,
		TimeLimit = 12,
	}),
	InputChase = table.freeze({
		Start = 3, -- initial queue length
		Interval = 0.9, -- the boss appends one arrow every Interval seconds (test 2026-11-16: 1.5 never appended before a fast player cleared 3)
		IntervalCharging = 0.7,
		IntervalVulnerable = 1.3,
		MinCleared = 7, -- success = queue empty AND at least this many arrows cleared; an early empty queue is refilled at once
		Cap = 6, -- queue longer than this = fail
		TimeLimit = 12,
	}),
	SignalLock = table.freeze({
		Locks = 4, -- successful locks needed
		MaxMisses = 2,
		LeadIn = 1.4, -- seconds before the first signal reaches the lock zone
		SpacingMin = 0.95,
		SpacingMax = 1.35,
		Window = 0.22, -- +- seconds around the signal's arrival
		WindowVulnerable = 0.32,
		LatencyAllowance = 0.25, -- client press time may be at most this much earlier than receipt
		TravelSeconds = 1.6, -- how long a signal is visible before reaching the zone (client display)
	}),
})

---------------------------------------------------------------------------------------------------
-- Typed command parsing (pure; same result on client and server).
-- Returns hackId (or nil) and a target hint: "self" | "boss" | "target" (use the selected target) |
-- a lowercase name fragment. Never evaluates the text.

local VERB: { [string]: string } = {
	fling = "FLING", launch = "FLING", throw = "FLING", yeet = "FLING", toss = "FLING", boost = "FLING", jump = "FLING", leap = "FLING",
	freeze = "FREEZE", stop = "FREEZE", halt = "FREEZE", ice = "FREEZE", stun = "FREEZE", lock = "FREEZE", pause = "FREEZE",
	shield = "SHIELD", protect = "SHIELD", guard = "SHIELD", barrier = "SHIELD", block = "SHIELD", defend = "SHIELD",
}
local SELF_WORDS: { [string]: boolean } = { self = true, me = true, myself = true, up = true }
local TARGET_WORDS: { [string]: boolean } = { target = true, them = true, it = true, enemy = true, that = true, him = true, her = true }
local FILLER: { [string]: boolean } = { the = true, a = true, at = true, on = true, to = true, please = true, hack = true }

HackCatalog.MaxCommandLength = 48

function HackCatalog.Parse(text: string, hasTarget: boolean?): (string?, string?)
	if typeof(text) ~= "string" or #text == 0 or #text > HackCatalog.MaxCommandLength then
		return nil, nil
	end
	local words = {}
	for w in string.gmatch(string.lower(text), "[%a%d%-]+") do
		if not FILLER[w] then
			table.insert(words, w)
		end
	end
	local verb: string? = nil
	local rest = {}
	for _, w in words do
		if verb == nil and VERB[w] then
			verb = VERB[w]
		else
			table.insert(rest, w)
		end
	end
	if verb == nil then
		return nil, nil
	end
	local hint: string? = nil
	for _, w in rest do
		if SELF_WORDS[w] then
			hint = "self"
		elseif w == "boss" or w == "conductor" then
			hint = "boss"
		elseif TARGET_WORDS[w] then
			hint = hint or "target"
		elseif hint == nil then
			hint = w -- a name fragment
		end
	end
	if verb == "FLING" and (words[1] == "jump" or words[1] == "leap" or words[1] == "boost") and (hint == nil or hint == "self") then
		return "FLING_SELF", "self" -- movement verbs only ever mean yourself
	end
	if verb == "SHIELD" then
		return "SHIELD", "self" -- self only in this prototype; "shield ally" still shields yourself
	elseif verb == "FREEZE" then
		if hint == "self" then
			return nil, "self" -- FREEZE never targets yourself
		end
		return "FREEZE", hint or "target"
	else -- FLING
		if hint == "self" then
			return "FLING_SELF", "self"
		elseif hint ~= nil then
			return "FLING_TARGET", hint
		end
		-- Contextual: bare "fling" = fling the selected target if there is one, else yourself.
		if hasTarget then
			return "FLING_TARGET", "target"
		end
		return "FLING_SELF", "self"
	end
end

HackCatalog.Examples = table.freeze({ "fling self", "fling", "fling dummy", "freeze", "freeze boss", "shield" })

return table.freeze(HackCatalog)
