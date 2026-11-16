--!strict
-- HackChallenges (wrist-hacking prototype, server): activation challenges, validated here only.
-- Clients display a snapshot and send single direction presses; progress, order, timing and the
-- success/failure decision are computed on the server. A client can never send "progress" or
-- "success".
--
-- Kinds (owner concepts, PR #14):
--   Sequence          self / player / NPC hacks: an ordered arrow sequence before a time limit;
--                     a wrong arrow is a miss (no reset), too many misses or the time limit fails.
--   ResistanceBattle  boss: correct arrows add progress while the boss drains it continuously;
--                     needs Length arrows AND progress >= Threshold (extra arrows are appended).
--   InputChase        boss: the boss appends an arrow every Interval; empty the queue to succeed,
--                     a queue longer than Cap or the time limit fails.
--   SignalLock        boss (assistant-proposed third type): signals arrive at a lock zone on a
--                     server schedule; press the shown arrow within +-Window of arrival.
-- Boss modifiers come from ctx.bossState(): "CHARGING" makes the boss stronger, "VULNERABLE"
-- weaker, so telegraphs and vulnerability windows matter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local CH = HackCatalog.Challenge

local DIRS = { "U", "D", "L", "R" }
local VALID: { [string]: boolean } = { U = true, D = true, L = true, R = true }

export type Ctx = { bossState: () -> string, rng: Random }

export type Session = {
	Kind: string,
	StartedAt: number,
	Deadline: number,
	Seq: { string }, -- Sequence / Resistance: the full ordered list; Chase: the live queue
	Index: number, -- next index to press (Sequence / Resistance)
	Misses: number,
	MaxMisses: number,
	Progress: number, -- Resistance
	LastT: number,
	Done: boolean,
	Result: string?, -- "success" | failure reason
	NextAppend: number, -- Chase
	Cleared: number, -- Chase / Lock: inputs accepted
	Signals: { { t: number, d: string, state: string } }, -- Lock: "pending" | "locked" | "missed"
	Locks: number,
	Assist: number, -- >= 1: accessibility / test time scale (HackTune_Challenge_TimeScale)
	ctx: Ctx,
}

local HackChallenges = {}

local function randDir(ctx: Ctx): string
	return DIRS[ctx.rng:NextInteger(1, 4)]
end

local function modifier(ctx: Ctx): string
	local ok, s = pcall(ctx.bossState)
	return if ok and typeof(s) == "string" then s else "IDLE"
end

function HackChallenges.New(kind: string, length: number?, t: number, ctx: Ctx): Session
	local s: Session = {
		Kind = kind, StartedAt = t, Deadline = t + 10, Seq = {}, Index = 1, Misses = 0, MaxMisses = 99,
		Progress = 0, LastT = t, Done = false, Result = nil, NextAppend = math.huge, Cleared = 0,
		Signals = {}, Locks = 0, Assist = 1, ctx = ctx,
	}
	-- Assist: longer limits/windows, slower boss drain and appends. Same rules, more time; no penalty.
	local a = workspace:GetAttribute("HackTune_Challenge_TimeScale")
	s.Assist = if typeof(a) == "number" and a == a then math.clamp(a, 1, 8) else 1
	local A = s.Assist
	if kind == "Sequence" then
		local n = length or CH.Target.Length
		for _ = 1, n do
			table.insert(s.Seq, randDir(ctx))
		end
		s.MaxMisses = CH.Target.MaxMisses
		s.Deadline = t + A * (if n <= 1 then CH.SelfTimeLimit else CH.Target.TimeLimit)
	elseif kind == "ResistanceBattle" then
		local cfg = CH.ResistanceBattle
		for _ = 1, cfg.Length do
			table.insert(s.Seq, randDir(ctx))
		end
		s.Progress = cfg.StartProgress
		s.Deadline = t + A * cfg.TimeLimit
	elseif kind == "InputChase" then
		local cfg = CH.InputChase
		for _ = 1, cfg.Start do
			table.insert(s.Seq, randDir(ctx))
		end
		s.Deadline = t + A * cfg.TimeLimit
		s.NextAppend = t + A * cfg.Interval
	elseif kind == "SignalLock" then
		local cfg = CH.SignalLock
		local at = t + A * cfg.LeadIn
		for _ = 1, cfg.Locks + cfg.MaxMisses + 1 do
			table.insert(s.Signals, { t = at, d = randDir(ctx), state = "pending" })
			at += A * ctx.rng:NextNumber(cfg.SpacingMin, cfg.SpacingMax)
		end
		s.MaxMisses = cfg.MaxMisses
		s.Deadline = at + A * cfg.Window + cfg.LatencyAllowance + 0.5
	else
		error("unknown challenge kind " .. kind)
	end
	return s
end

local function finish(s: Session, result: string)
	if not s.Done then
		s.Done = true
		s.Result = result
	end
end

local function drainRate(s: Session): number
	local cfg = CH.ResistanceBattle
	local m = modifier(s.ctx)
	local d = cfg.Drain
	if m == "VULNERABLE" or m == "FROZEN" or m == "STAGGERED" then
		d = cfg.DrainVulnerable
	elseif m == "CHARGING" then
		d = cfg.DrainCharging
	end
	return d / s.Assist
end

local function chaseInterval(s: Session): number
	local cfg = CH.InputChase
	local m = modifier(s.ctx)
	local i = cfg.Interval
	if m == "VULNERABLE" or m == "FROZEN" or m == "STAGGERED" then
		i = cfg.IntervalVulnerable
	elseif m == "CHARGING" then
		i = cfg.IntervalCharging
	end
	return i * s.Assist
end

local function lockWindow(s: Session): number
	local cfg = CH.SignalLock
	local m = modifier(s.ctx)
	local w = if m == "VULNERABLE" or m == "FROZEN" or m == "STAGGERED" then cfg.WindowVulnerable else cfg.Window
	return math.min(0.6, w * s.Assist)
end

-- Advance time-driven state (drain, appends, missed signals, deadlines). Returns true if the
-- client-visible state changed.
function HackChallenges.Tick(s: Session, t: number): boolean
	if s.Done then
		return false
	end
	local changed = false
	if s.Kind == "ResistanceBattle" then
		s.Progress = math.max(0, s.Progress - drainRate(s) * (t - s.LastT))
		s.LastT = t
		if s.Progress <= 0 then
			finish(s, "resisted")
		end
		changed = true
	elseif s.Kind == "InputChase" then
		while t >= s.NextAppend and not s.Done do
			table.insert(s.Seq, randDir(s.ctx))
			s.NextAppend += chaseInterval(s)
			changed = true
			if #s.Seq > CH.InputChase.Cap then
				finish(s, "overrun")
			end
		end
	elseif s.Kind == "SignalLock" then
		local cfg = CH.SignalLock
		local w = lockWindow(s)
		for _, sig in s.Signals do
			if sig.state == "pending" and t > sig.t + w + cfg.LatencyAllowance then
				sig.state = "missed"
				s.Misses += 1
				changed = true
			end
		end
		if s.Misses > s.MaxMisses then
			finish(s, "too_many_misses")
		else
			local pending = false
			for _, sig in s.Signals do
				if sig.state == "pending" then
					pending = true
				end
			end
			if not pending and s.Locks < cfg.Locks then
				finish(s, "too_many_misses")
			end
		end
	end
	if not s.Done and t > s.Deadline then
		finish(s, "timeout")
		changed = true
	end
	return changed
end

-- One direction press. clientT is the client's server-clock press time (bounded by recvT).
function HackChallenges.Input(s: Session, dir: any, clientT: any, recvT: number): (boolean, string?)
	if s.Done then
		return false, "done"
	end
	if typeof(dir) ~= "string" or not VALID[dir] then
		return false, "bad_input"
	end
	HackChallenges.Tick(s, recvT)
	if s.Done then
		return true, nil
	end
	if s.Kind == "Sequence" or s.Kind == "ResistanceBattle" then
		local expected = s.Seq[s.Index]
		if dir == expected then
			s.Index += 1
			if s.Kind == "ResistanceBattle" then
				s.Progress = math.min(1.2, s.Progress + CH.ResistanceBattle.Gain)
				local cfg = CH.ResistanceBattle
				if s.Index > #s.Seq then
					if s.Index > cfg.Length and s.Progress >= cfg.Threshold then
						finish(s, "success")
					else
						table.insert(s.Seq, randDir(s.ctx)) -- keep pushing until the bar is full
					end
				end
			elseif s.Index > #s.Seq then
				finish(s, "success")
			end
		else
			s.Misses += 1
			if s.Kind == "ResistanceBattle" then
				s.Progress = math.max(0, s.Progress - CH.ResistanceBattle.MissPenalty)
				if s.Progress <= 0 then
					finish(s, "resisted")
				end
			elseif s.Misses > s.MaxMisses then
				finish(s, "too_many_misses")
			end
		end
	elseif s.Kind == "InputChase" then
		if s.Seq[1] == dir then
			table.remove(s.Seq, 1)
			s.Cleared += 1
			if #s.Seq == 0 then
				if s.Cleared >= CH.InputChase.MinCleared then
					finish(s, "success")
				else
					-- cleared too early: the boss injects the next arrow immediately and keeps writing
					table.insert(s.Seq, randDir(s.ctx))
					s.NextAppend = recvT + chaseInterval(s)
				end
			end
		else
			s.Misses += 1 -- a wrong arrow costs time only (the boss keeps appending)
		end
	elseif s.Kind == "SignalLock" then
		local cfg = CH.SignalLock
		local w = lockWindow(s)
		local tc = recvT
		if typeof(clientT) == "number" and clientT == clientT then
			tc = math.clamp(clientT, recvT - cfg.LatencyAllowance, recvT)
		end
		-- The first pending signal is the one being judged.
		local sig = nil
		for _, cand in s.Signals do
			if cand.state == "pending" then
				sig = cand
				break
			end
		end
		if not sig then
			return true, nil
		end
		if math.abs(tc - sig.t) <= w and dir == sig.d then
			sig.state = "locked"
			s.Locks += 1
			s.Cleared += 1
			if s.Locks >= cfg.Locks then
				finish(s, "success")
			end
		elseif tc < sig.t - w - 0.6 then
			-- Far too early: ignored (no penalty), so a nervous early tap is not punished.
			return true, "early"
		else
			sig.state = "missed"
			s.Misses += 1
			if s.Misses > s.MaxMisses then
				finish(s, "too_many_misses")
			end
		end
	end
	return true, nil
end

-- Client display snapshot (no secrets: everything shown is what the player must press).
function HackChallenges.Snapshot(s: Session, t: number): { [string]: any }
	local snap: { [string]: any } = {
		kind = s.Kind,
		deadline = s.Deadline,
		started = s.StartedAt,
		misses = s.Misses,
		assist = s.Assist,
		maxMisses = s.MaxMisses,
		boss = modifier(s.ctx),
		now = t,
	}
	if s.Kind == "Sequence" or s.Kind == "ResistanceBattle" then
		snap.seq = table.clone(s.Seq)
		snap.index = s.Index
		if s.Kind == "ResistanceBattle" then
			snap.progress = s.Progress
			snap.drain = drainRate(s)
			snap.length = CH.ResistanceBattle.Length
			snap.threshold = CH.ResistanceBattle.Threshold
		end
	elseif s.Kind == "InputChase" then
		snap.seq = table.clone(s.Seq)
		snap.nextAppend = s.NextAppend
		snap.interval = chaseInterval(s)
		snap.cap = CH.InputChase.Cap
		snap.cleared = s.Cleared
		snap.need = CH.InputChase.MinCleared
	elseif s.Kind == "SignalLock" then
		local sigs = {}
		for _, sig in s.Signals do
			table.insert(sigs, { t = sig.t, d = sig.d, state = sig.state })
		end
		snap.signals = sigs
		snap.window = lockWindow(s)
		snap.travel = CH.SignalLock.TravelSeconds * s.Assist
		snap.locks = s.Locks
		snap.need = CH.SignalLock.Locks
	end
	return snap
end

return HackChallenges
