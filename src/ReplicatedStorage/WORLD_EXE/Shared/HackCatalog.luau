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
		Effect = "Launch a target away from you. It ragdolls briefly, then recovers.", Order = 2 },
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
	FlingSelf = table.freeze({
		Up = 90, -- initial vertical velocity (apex ~ Up^2 / (2 * 196.2) = 20.6 studs). Sweep 2026-11-16: A 78/48, B 90/42 (chosen), C 98/48
		Forward = 42, -- horizontal launch speed along the intended direction (~39 studs on flat ground)
		SteerSpeed = 16, -- extra horizontal speed the player can add/subtract with movement input mid-air
		MinAirSeconds = 0.2, -- landing is not checked before this
		MaxFlightSeconds = 2.5, -- the horizontal carry always ends by this time
		BlockedSpeedFraction = 0.3, -- carry ends early when the measured speed falls below this share (wall)
		Cooldown = 3,
		-- Owner reference mode (clip 2026-11-16): 1 = FLING SELF uses the tumbling ragdoll launch below.
		-- Default 0 keeps the 2026-11-16 directive (no ragdoll on FLING SELF) until the owner decides.
		Ragdoll = 0,
		RagdollUp = 112,
		RagdollForward = 32,
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
		BossStaggerSeconds = 1.0,
		BossPushStuds = 6,
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
	Rate = table.freeze({ Burst = 14, PerSecond = 9 }), -- per player, all hack messages incl. arrow presses (fast players reach ~6/s; test 2026-11-16 hit 4/s)
	RetrySeconds = 1.5, -- after a failed/cancelled challenge, the same hack waits this long
	LineOfSight = true, -- targeted hacks need a clear line (collidable geometry blocks)
})

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

-- Activation challenges. Directions: "U" "D" "L" "R".
HackCatalog.Challenge = table.freeze({
	-- Self hacks: FLING SELF none (traversal must feel instant), SHIELD one arrow (minimal).
	SelfLength = table.freeze({ FLING_SELF = 0, SHIELD = 1 }),
	SelfTimeLimit = 2.5,
	-- Targeted hacks on players / NPCs: a short ordered sequence by the HACKER (not the victim).
	Target = table.freeze({ Length = 3, TimeLimit = 4.5, MaxMisses = 2 }),
	-- Boss hacks: one selectable variant at a time (boss attribute BossChallenge).
	BossVariants = table.freeze({ "ResistanceBattle", "InputChase", "SignalLock" }),
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
