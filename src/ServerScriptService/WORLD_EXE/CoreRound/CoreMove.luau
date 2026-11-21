--!strict
-- CoreMove (Core Round Step 1, server): authoritative Super Dash charges.
-- The owning client moves the character (physics owner) and predicts charges; the server is the judge:
--   * 2 charges; each regenerates in ChargeRegenSeconds, one after the other (ground or air).
--   * "dash" spends 1; "super" spends 1 more and is only accepted within SuperWindow (+ latency slack) of the
--     dash it extends. No other way to get a burst: no unlimited bursts, no cooldown bypass.
--   * presses closer than MinPressGap are ignored (spam); stunned players cannot dash.
-- Published on the Player: CR_Charges (int), CR_RegenAt (server time the next charge arrives, 0 = full).

local CoreRound = game:GetService("ReplicatedStorage"):WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))

local CoreMove = {}

type State = { charges: number, regenAt: number, lastDash: number, lastPress: number, superUsed: boolean, dashes: number, supers: number, rejects: number }
local states: { [Player]: State } = {}

local function tune(k: string): number
	return CoreConfig.Tune("Move", k)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function publish(p: Player, s: State)
	p:SetAttribute("CR_Charges", s.charges)
	p:SetAttribute("CR_RegenAt", s.regenAt)
end

function CoreMove.Get(p: Player): State
	local s = states[p]
	if not s then
		s = { charges = math.floor(tune("Charges")), regenAt = 0, lastDash = -100, lastPress = -100, superUsed = true, dashes = 0, supers = 0, rejects = 0 }
		states[p] = s
		publish(p, s)
	end
	return s
end

local function regen(p: Player, s: State)
	local max = math.floor(tune("Charges"))
	local t = now()
	local changed = false
	while s.charges < max and s.regenAt > 0 and t >= s.regenAt do
		s.charges += 1
		s.regenAt = if s.charges < max then s.regenAt + tune("ChargeRegenSeconds") else 0
		changed = true
	end
	if s.charges >= max and s.regenAt ~= 0 then
		s.regenAt = 0
		changed = true
	end
	if changed then
		publish(p, s)
	end
end

local function spend(p: Player, s: State)
	local max = math.floor(tune("Charges"))
	if s.charges >= max then
		s.regenAt = now() + tune("ChargeRegenSeconds")
	end
	s.charges -= 1
	publish(p, s)
end

-- returns ok, reason. latency = the player's one-way latency estimate (s), used only as slack for the window.
function CoreMove.Request(p: Player, op: string, stunned: boolean, latency: number): (boolean, string?)
	local s = CoreMove.Get(p)
	regen(p, s)
	local t = now()
	if stunned then
		s.rejects += 1
		return false, "stunned"
	end
	if t - s.lastPress < tune("MinPressGap") then
		s.rejects += 1
		return false, "spam"
	end
	s.lastPress = t
	if op == "dash" then
		if s.charges < 1 then
			s.rejects += 1
			return false, "no_charge"
		end
		spend(p, s)
		s.lastDash = t
		s.superUsed = false
		s.dashes += 1
		return true, nil
	elseif op == "super" then
		local slack = math.min(0.25, latency * 2) + 0.05
		if s.superUsed or t - s.lastDash > tune("SuperWindow") + slack then
			s.rejects += 1
			return false, "window"
		end
		if s.charges < 1 then
			s.rejects += 1
			return false, "no_charge"
		end
		spend(p, s)
		s.superUsed = true
		s.supers += 1
		return true, nil
	end
	return false, "op"
end

function CoreMove.Update()
	for p, s in states do
		if p.Parent then
			regen(p, s)
		else
			states[p] = nil
		end
	end
end

function CoreMove.Reset(p: Player?)
	if p then
		states[p] = nil
		CoreMove.Get(p)
	else
		for q in states do
			states[q] = nil
			CoreMove.Get(q)
		end
	end
end

function CoreMove.Stats(p: Player): { [string]: number }
	local s = CoreMove.Get(p)
	return { charges = s.charges, dashes = s.dashes, supers = s.supers, rejects = s.rejects }
end

return CoreMove
