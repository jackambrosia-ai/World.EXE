--!strict
-- HackIncoming (wrist-hacking prototype, server): the warning + counterplay stage for TARGETED hacks
-- on players and NPCs (owner directive 2026-11-16, section 7). Self hacks and boss hacks skip it.
--
-- When an attacker completes a targeted hack's input challenge:
--   1. the target is re-validated;
--   2. a reaction window starts (ReactionWindow + LatencyGrace, server clock);
--   3. every client is told to draw an overhead warning, the impact ring and a faint tether;
--      the defender's client also draws a directional indicator toward the attacker;
--   4. at resolveAt the SERVER decides, in this fixed order:
--        a) target gone / dead                         -> "lost"
--        b) SHIELD active on the target               -> "deflected"; "perfect" if it was raised
--           within PerfectWindow seconds of resolveAt (refunds part of the defender's SHIELD cooldown)
--        c) line of sight attacker -> target blocked   -> "evaded_cover"
--        d) target root outside the impact ring       -> "evaded_dodge"
--        e) otherwise the effect is applied            -> "hit"
-- Moving a little is not a miss: only leaving the ring (an explicit, visible radius) counts.
-- Clients never report outcomes; the server uses its own replicated positions and its own clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local HackTargets = require(script.Parent:WaitForChild("HackTargets"))
local HackEffects = require(script.Parent:WaitForChild("HackEffects"))

local HackIncoming = {}

type Deps = {
	send: (Player, { [string]: any }) -> (),
	broadcast: ({ [string]: any }) -> (),
	log: (string) -> (),
	onResolved: (attacker: Player, hackId: string, outcome: string, defender: Player?) -> (),
}
local deps: Deps
local active: { [Model]: { id: number } } = {}
local seq = 0
local stats: { [string]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tune(key: string): number
	return HackCatalog.Tune("Incoming", key)
end

function HackIncoming.Init(d: Deps)
	deps = d
end

function HackIncoming.IsTargeted(model: Model?): boolean
	return model ~= nil and active[model] ~= nil
end

function HackIncoming.Stats(): { [string]: number }
	return stats
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Test-station NPC reactions (workspace attribute HackProto_DummyReaction): none | shield | perfect | dodge.
local function npcReact(target: HackTargets.Target, center: Vector3, attackerPos: Vector3, resolveAt: number)
	local mode = workspace:GetAttribute("HackProto_DummyReaction")
	if target.Player or typeof(mode) ~= "string" or mode == "none" then
		return
	end
	local model = target.Model
	task.spawn(function()
		if mode == "shield" then
			task.wait(0.4) -- a human-like reaction delay
			HackEffects.ShieldModel(model, HackCatalog.Tune("Shield", "Seconds"))
		elseif mode == "perfect" then
			local wait = resolveAt - now() - 0.15
			if wait > 0 then
				task.wait(wait)
			end
			HackEffects.ShieldModel(model, HackCatalog.Tune("Shield", "Seconds"))
		elseif mode == "dodge" then
			task.wait(0.3)
			local away = flat(center - attackerPos)
			local side = Vector3.new(-away.Z, 0, away.X)
			side = if side.Magnitude > 0.1 then side.Unit else Vector3.xAxis
			local hum = target.Humanoid
			local old = hum.WalkSpeed
			hum.WalkSpeed = 20
			hum:MoveTo(center + side * (tune("DodgeRadius") + 5))
			task.delay(1.5, function()
				if hum.Parent then
					hum.WalkSpeed = old
				end
			end)
		end
	end)
end

-- Handle for a MANUAL incoming stage (FLING, owner 2026-11-16 "slide my mouse and they should
-- immediately go in that direction"): the warning goes up when the attacker BEGINS casting and has
-- no timer; Resolve(aim) is called the moment the attacker slides the mouse after the cast (held
-- back only until MinWarning has passed since the warning went up); Cancel() withdraws it.
export type Handle = { id: number, target: Model, Resolve: (aim: Vector3?) -> (), Cancel: (reason: string) -> () }

-- Starts the incoming stage. Timed (default): resolves after ReactionWindow + LatencyGrace.
-- opts.manual: armed until Resolve/Cancel (safety cancel after MaxArmedSeconds).
-- Returns ok, reason ("incoming" on success), handle.
function HackIncoming.Start(attacker: Player, hackId: string, target: HackTargets.Target, apply: (HackTargets.Target, Vector3, Vector3?) -> (boolean, string?), opts: { manual: boolean? }?): (boolean, string, Handle?)
	local model = target.Model
	if active[model] then
		return false, "target_busy", nil
	end
	local aChar = attacker.Character
	local aRoot = aChar and aChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not aChar or not aRoot then
		return false, "not_alive", nil
	end
	local manual = opts ~= nil and opts.manual == true
	seq += 1
	local id = seq
	local window = tune("ReactionWindow")
	local startT = now()
	local timedResolveAt = startT + window + tune("LatencyGrace")
	local center = target.Root.Position
	local radius = tune("DodgeRadius")
	active[model] = { id = id }
	deps.broadcast({
		op = "incoming", id = id, hackId = hackId,
		attacker = aChar, target = model, center = center, radius = radius,
		startAt = startT, resolveAt = if manual then nil else startT + window, -- clients show the window without the grace
		armed = manual, -- manual: no countdown, "being cast"
		attackerName = attacker.DisplayName,
	})
	deps.log(string.format("incoming #%d %s %s -> %s (%s)", id, attacker.Name, hackId, model.Name, if manual then "armed at cast start" else string.format("window %.2f", window)))
	npcReact(target, center, aRoot.Position, if manual then startT + tune("MinWarning") + 0.6 else timedResolveAt)
	local done = false

	local function resolve(aim: Vector3?)
		if done then
			return
		end
		done = true
		debug.profilebegin("HackIncoming.Resolve")
		local t0 = os.clock()
		local resolveTime = if manual then now() else timedResolveAt
		active[model] = nil
		local outcome = "hit"
		local live = HackTargets.Resolve(target.Id)
		local defender = Players:GetPlayerFromCharacter(model)
		if not live or live.Model ~= model then
			outcome = "lost"
		else
			local shielded, raisedAt = HackEffects.ModelShieldInfo(model)
			local aChar2 = attacker.Character
			local aRoot2 = aChar2 and aChar2:FindFirstChild("HumanoidRootPart") :: BasePart?
			if shielded then
				local pw = tune("PerfectWindow")
				outcome = if pw > 0 and typeof(raisedAt) == "number" and raisedAt >= resolveTime - tune("LatencyGrace") - pw then "perfect" else "deflected"
				HackEffects.ShieldFlash(model)
			elseif not aChar2 or not aRoot2 then
				outcome = "lost" -- attacker gone: the hack fizzles
			elseif not HackTargets.LineOfSight(aChar2, live) then
				outcome = "evaded_cover"
			elseif flat(live.Root.Position - center).Magnitude > radius then
				outcome = "evaded_dodge"
			else
				local ok, why = apply(live, aRoot2.Position, aim)
				outcome = if ok then "hit" else ("failed:" .. tostring(why))
			end
		end
		stats[outcome] = (stats[outcome] or 0) + 1
		deps.broadcast({ op = "incoming_result", id = id, hackId = hackId, outcome = outcome, attacker = attacker.Character, target = model })
		deps.onResolved(attacker, hackId, outcome, defender)
		deps.log(string.format("incoming #%d -> %s after %.2f s warning (%.2f ms)", id, outcome, now() - startT, (os.clock() - t0) * 1000))
		debug.profileend()
	end

	local handle: Handle = {
		id = id,
		target = model,
		Resolve = function(aim: Vector3?)
			local wait = startT + tune("MinWarning") - now()
			if wait > 0 then
				task.delay(wait, resolve, aim)
			else
				resolve(aim)
			end
		end,
		Cancel = function(reason: string)
			if done then
				return
			end
			done = true
			active[model] = nil
			stats.cancelled = (stats.cancelled or 0) + 1
			deps.broadcast({ op = "incoming_result", id = id, hackId = hackId, outcome = "cancelled", attacker = attacker.Character, target = model })
			deps.log(string.format("incoming #%d cancelled (%s)", id, reason))
		end,
	}
	if manual then
		task.delay(tune("MaxArmedSeconds"), function()
			handle.Cancel("armed too long")
		end)
	else
		task.delay(timedResolveAt - now(), resolve, nil)
	end
	return true, "incoming", handle
end

return HackIncoming
