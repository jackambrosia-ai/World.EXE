--!strict
-- CoreDisc (Core Round Step 1, server): the authoritative Rebound Disc.
--
-- Flight: OUT (straight, OutSpeed) until it has flown Range studs, hits the floor, hits a wall with no bounce
-- left, or is blocked by a shield -> RETURN (homes on the owner's root at ReturnSpeed, ignores walls) ->
-- caught within CatchRadius. Not caught after MaxFlightSeconds -> snaps back with a penalty.
-- One reflection off an eligible (roughly vertical) wall while OUT.
-- Hits: the disc passes THROUGH targets. Each pass (out / return) can hit a given target at most once, and a
-- return-pass hit within ReturnDedupeSeconds of that target's outbound hit is ignored (no instant double-tap).
-- Teammates are never hit and their shields never block their own team's discs.
-- Lag compensation: targets are tested at (now - rewind), rewind = thrower one-way latency + InterpSeconds (dummies)
-- or InterpPlayerSeconds (characters),
-- capped at RewindMax (RewindMode 1); RewindMode 0 tests the current server pose. PROVISIONAL (Step 1 test).
-- Shield: the server-side panel maths (CoreCombat.Panel), tested before bodies each step.

local CoreRound = game:GetService("ReplicatedStorage"):WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))
local CoreCombat = require(script.Parent:WaitForChild("CoreCombat"))

local CoreDisc = {}

type Disc = {
	id: number,
	n: number, -- the thrower's client sequence number (0 for dummies)
	owner: Model,
	ownerName: string,
	team: string,
	pos: Vector3,
	dir: Vector3,
	phase: string, -- "out" | "ret"
	travelled: number,
	bounces: number,
	t0: number,
	rewind: number,
	hitOut: { [Model]: number }, -- server time of the outbound hit
	hitRet: { [Model]: boolean },
	deflectUntil: number,
	blockedBy: { [Model]: boolean }, -- owner bug fix: a shield blocks a given disc at most once per throw
	log: { any },
	-- Step 1B: per-throw flight from the server-validated charge (0 = tap). Never changes damage / stun / blocking.
	charge: number,
	outSpeed: number,
	range: number,
	retSpeed: number,
	maxFlight: number,
	rethrow: number,
}

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local discs: { [number]: Disc } = {}
local nextId = 0
local fire: (kind: string, data: { [string]: any }) -> () = function() end
local logEvent: (entry: { [string]: any }) -> () = function() end
local readyAt: { [Model]: number } = {} -- owner can throw again at this server time
local out: { [Model]: number } = {} -- owner -> disc id in flight

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function tune(k: string): number
	return CoreConfig.Tune("Disc", k)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function CoreDisc.Init(deps: { fire: (string, { [string]: any }) -> (), log: ({ [string]: any }) -> () })
	fire = deps.fire
	logEvent = deps.log
end

function CoreDisc.Ready(owner: Model): (boolean, string?)
	if out[owner] then
		return false, "in_flight"
	end
	if now() < (readyAt[owner] or 0) then
		return false, "cooldown"
	end
	return true, nil
end

function CoreDisc.ReadyAt(owner: Model): number
	return readyAt[owner] or 0
end

local function rootPos(m: Model): Vector3?
	local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if r then r.Position else nil
end

local function finish(d: Disc, how: string)
	discs[d.id] = nil
	if out[d.owner] == d.id then
		out[d.owner] = nil
	end
	local penalty = if how == "snap" then tune("SnapPenaltySeconds") else d.rethrow
	readyAt[d.owner] = now() + penalty
	d.owner:SetAttribute("CR_DiscOut", false)
	d.owner:SetAttribute("CR_DiscReadyAt", readyAt[d.owner])
	fire("disc_end", { id = d.id, n = d.n, owner = d.ownerName, how = how, pos = d.pos })
	logEvent({ kind = "disc_end", id = d.id, how = how, flight = now() - d.t0 })
end

local function turn(d: Disc, why: string)
	if d.phase == "out" then
		d.phase = "ret"
		fire("disc_turn", { id = d.id, pos = d.pos, why = why })
	end
end

-- throw (validated by the caller). latency = thrower one-way latency estimate (s).
function CoreDisc.Throw(owner: Model, ownerName: string, n: number, origin: Vector3, dir: Vector3, latency: number, charge: number?): number
	nextId += 1
	local k = math.clamp(charge or 0, 0, 1)
	local mode = tune("RewindMode")
	-- base rewind = thrower one-way latency (mode 1); the per-target interpolation term is added in StepOne
	local rewind = if mode >= 0.5 then latency else -1
	local d: Disc = {
		id = nextId,
		n = n,
		owner = owner,
		ownerName = ownerName,
		team = CoreCombat.TeamOf(owner),
		pos = origin,
		dir = dir.Unit,
		phase = "out",
		travelled = 0,
		bounces = 0,
		t0 = now(),
		rewind = rewind,
		hitOut = {},
		hitRet = {},
		deflectUntil = 0,
		blockedBy = {},
		log = {},
		charge = k,
		outSpeed = lerp(tune("OutSpeed"), tune("ChargedOutSpeed"), k),
		range = lerp(tune("Range"), tune("ChargedRange"), k),
		retSpeed = lerp(tune("ReturnSpeed"), tune("ChargedReturnSpeed"), k),
		maxFlight = lerp(tune("MaxFlightSeconds"), tune("ChargedMaxFlightSeconds"), k),
		rethrow = lerp(tune("RethrowSeconds"), tune("ChargedRethrowSeconds"), k),
	}
	discs[d.id] = d
	out[owner] = d.id
	owner:SetAttribute("CR_DiscOut", true)
	local catchUp = math.min(tune("CatchUpMax"), latency)
	fire("disc_launch", {
		id = d.id,
		n = n,
		owner = ownerName,
		team = d.team,
		origin = origin,
		dir = d.dir,
		t0 = d.t0 - catchUp,
		charge = k,
	})
	logEvent({ kind = "throw", id = d.id, n = n, owner = ownerName, rewind = rewind, latency = latency, catchUp = catchUp, charge = k, speed = d.outSpeed, range = d.range })
	if catchUp > 0 then
		CoreDisc.StepOne(d, catchUp)
	end
	return d.id
end

-- an entity this disc may hit / be blocked by: not the owner, not on the owner's team (no team = everyone)
local function enemy(d: Disc, m: Model): boolean
	if m == d.owner then
		return false
	end
	return d.team == "" or CoreCombat.TeamOf(m) ~= d.team
end

local function hitEntity(d: Disc, e: CoreCombat.Entity, kind: string, at: Vector3, pass: string)
	local res = CoreCombat.ApplyHit(e, kind)
	local victim = e.model
	fire("hit", {
		id = d.id,
		n = d.n,
		attacker = d.ownerName,
		target = e.name,
		kind = kind,
		pass = pass,
		meter = res.meter,
		stunned = res.stunned,
		immune = res.immune,
		ignored = res.ignored,
		pos = at,
		dir = d.dir,
	})
	logEvent({
		kind = "hit",
		id = d.id,
		n = d.n,
		attacker = d.ownerName,
		target = e.name,
		part = kind,
		pass = pass,
		meter = res.meter,
		stunned = res.stunned,
		immune = res.immune,
		ignored = res.ignored,
		rewind = d.rewind,
	})
	-- small flinch push on the victim's own client (players), never on a stun (the stun holds them)
	if e.player and not res.stunned and not res.ignored then
		fire("nudge", { to = e.player.UserId, dir = d.dir })
	end
	local _ = victim
end

-- advance one disc by dt (sub-stepped)
function CoreDisc.StepOne(d: Disc, dt: number)
	local remaining = dt
	while remaining > 1e-4 and discs[d.id] do
		local h = math.min(remaining, 1 / 90)
		remaining -= h
		local t = now()
		if t - d.t0 > d.maxFlight then
			finish(d, "snap")
			return
		end
		local ownerPos = rootPos(d.owner)
		if not ownerPos or not d.owner.Parent then
			finish(d, "owner_gone")
			return
		end
		local speed
		if d.phase == "ret" then
			local to = ownerPos - d.pos
			if to.Magnitude <= tune("CatchRadius") then
				finish(d, "caught")
				return
			end
			d.dir = to.Unit
			speed = d.retSpeed
		else
			speed = d.outSpeed
		end
		local a = d.pos
		local step = d.dir * speed * h
		local b = a + step
		local r = tune("Radius")

		-- earliest contact along a -> b: shield panels, then walls (out only), bodies (pass-through)
		local bestT, bestKind, bestE = 2, "", nil :: CoreCombat.Entity?
		local function rewindFor(e: CoreCombat.Entity): number
			return if d.rewind < 0 then 0 else math.min(tune("RewindMax"), d.rewind + (if e.player then tune("InterpPlayerSeconds") else tune("InterpSeconds")))
		end
		for m, e in CoreCombat.All() do
			-- owner bug fix (Step 1E): a panel that already blocked this disc is ignored for the rest of its flight. A disc
			-- thrown from behind passes the panel's back face (panels block one side), and on its way home it met the
			-- FRONT face; a return-pass block does not change the homing path, so it re-blocked every 1/90 s step (~235
			-- blocks, each costing shield energy) until the 2.5 s flight cap snapped it home.
			if enemy(d, m) and not d.blockedBy[m] then
				-- Step 1B: panels at the same rewound time as bodies (review item "shield latency")
				local c, nrm, right, up, hw, hh = CoreCombat.Panel(e, t - rewindFor(e))
				if c and nrm and right and up and hw and hh then
					local tp = CoreGeom.SegPanel(a, b, c, nrm, right, up, hw + r, hh + r)
					if tp and tp < bestT then
						bestT, bestKind, bestE = tp, "shield", e
					end
				end
			end
		end
		local wall: RaycastResult? = nil
		if d.phase == "out" then
			local filter = {}
			for m in CoreCombat.All() do
				table.insert(filter, m)
			end
			local fx = workspace:FindFirstChild("CoreRoundFx")
			if fx then
				table.insert(filter, fx)
			end
			params.FilterDescendantsInstances = filter
			wall = workspace:Spherecast(a, r, step, params)
			if wall then
				local tw = (wall.Position - a).Magnitude / math.max(step.Magnitude, 1e-6)
				if tw < bestT then
					bestT, bestKind, bestE = tw, "wall", nil
				end
			end
		end
		-- bodies: collect every target crossed before the first blocking contact
		local crossed: { { t: number, e: CoreCombat.Entity, part: string } } = {}
		if t >= d.deflectUntil then
			for m, e in CoreCombat.All() do
				if enemy(d, m) then
					local cf, head, _, _, state, sw = CoreCombat.Sample(e, t - rewindFor(e))
					if cf and head then
						local th, part = CoreCombat.TestHit(cf, head, a, b, r, state, sw, e.slideHead)
						if th and part and th <= bestT then
							table.insert(crossed, { t = th, e = e, part = part })
						end
					end
				end
			end
		end
		table.sort(crossed, function(x, y)
			return x.t < y.t
		end)
		for _, c in crossed do
			local m = c.e.model
			if d.phase == "out" then
				if not d.hitOut[m] then
					d.hitOut[m] = t
					hitEntity(d, c.e, c.part, a + step * c.t, "out")
				end
			else
				local tOut = d.hitOut[m]
				if not d.hitRet[m] then
					d.hitRet[m] = true
					if tOut and tune("SameTargetPerThrow") < 1.5 then
						logEvent({ kind = "dedupe", id = d.id, target = c.e.name, gap = t - tOut, rule = "once_per_throw" })
					elseif tOut and t - tOut < tune("ReturnDedupeSeconds") then
						logEvent({ kind = "dedupe", id = d.id, target = c.e.name, gap = t - tOut })
					else
						hitEntity(d, c.e, c.part, a + step * c.t, "ret")
					end
				end
			end
		end
		if bestKind == "shield" and bestE then
			d.blockedBy[bestE.model] = true
			d.pos = a + step * bestT
			local broke = CoreCombat.BlockCost(bestE)
			fire("disc_block", { id = d.id, pos = d.pos, holder = bestE.name, broke = broke, energy = bestE.shieldEnergy })
			logEvent({ kind = "block", id = d.id, holder = bestE.name, broke = broke, energy = bestE.shieldEnergy, pass = d.phase })
			if d.phase == "out" then
				turn(d, "shield")
			else
				d.deflectUntil = t + 0.3
			end
			-- nudge off the panel so the next step does not re-block
			d.pos += -d.dir * 0.2
		elseif bestKind == "wall" and wall then
			d.pos = a + step * bestT + wall.Normal * (r * 0.5)
			d.travelled += step.Magnitude * bestT
			local nrm = wall.Normal
			local eligible = math.abs(nrm.Y) < 0.7
			if eligible and d.bounces < tune("Bounces") then
				d.bounces += 1
				d.dir = (d.dir - 2 * d.dir:Dot(nrm) * nrm).Unit
				fire("disc_bounce", { id = d.id, pos = d.pos, dir = d.dir })
				logEvent({ kind = "bounce", id = d.id, pos = d.pos })
			else
				turn(d, if eligible then "wall" else "floor")
			end
		else
			d.pos = b
			if d.phase == "out" then
				d.travelled += step.Magnitude
				if d.travelled >= d.range then
					turn(d, "range")
				end
			end
		end
	end
end

function CoreDisc.Step(dt: number)
	for _, d in discs do
		CoreDisc.StepOne(d, dt)
	end
end

-- end every disc of an owner (death, leave, reset)
function CoreDisc.Clear(owner: Model?)
	for _, d in discs do
		if owner == nil or d.owner == owner then
			finish(d, "cleared")
		end
	end
	if owner == nil then
		table.clear(readyAt)
	else
		readyAt[owner] = nil
	end
end

function CoreDisc.Count(): number
	local c = 0
	for _ in discs do
		c += 1
	end
	return c
end

return CoreDisc
