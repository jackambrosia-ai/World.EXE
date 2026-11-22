--!strict
-- CoreTest (Core Round Step 1, server, STUDIO ONLY): test hooks behind ServerStorage.CoreRoundTest.
-- Invoked from Studio MCP execute_luau (separate VM; this BindableFunction is the bridge, L-0022).
--   ("Log", fromIndex)            -> { base, entries } (event log since fromIndex, absolute index)
--   ("State")                     -> entity states, discs in flight, per-player RTT / charges
--   ("Reset")                     -> clears meters, stuns, shields, discs, charges
--   ("DummyThrow", dummy, target, part?, lead?, charge?) -> stand-in attacker: the named dummy throws at the named
--                                    entity's "HEAD" / "BODY" (current pose; lead = seconds of target motion)
--   ("ThrowFrom", origin, dir, team, ownerDummy, charge?) -> raw scripted throw owned by a dummy
--   ("SetShield", entityName, up, yawDegrees)
--   ("Pose", entityName)          -> root / head positions
--   ("Hit", entityName, "HEAD"/"BODY") -> apply a hit directly (meter maths only)
-- Results are labelled stand-in / scripted; they are not two-client evidence.

local CoreCombat = require(script.Parent:WaitForChild("CoreCombat"))
local CoreDisc = require(script.Parent:WaitForChild("CoreDisc"))
local CoreMove = require(script.Parent:WaitForChild("CoreMove"))
local CoreDummies = require(script.Parent:WaitForChild("CoreDummies"))

local CoreTest = {}

local function pose(e: CoreCombat.Entity): (Vector3?, Vector3?)
	local r = e.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local h = e.model:FindFirstChild("Head") :: BasePart?
	return if r then r.Position else nil, if h then h.Position else nil
end

function CoreTest.Handle(op: string, ctx: any, ...): any
	local args = { ... }
	if op == "Log" then
		local from = (args[1] :: number?) or 0
		local base = ctx.logBase()
		local out = {}
		for i, entry in ctx.log do
			if base + i > from then
				table.insert(out, entry)
			end
		end
		return { base = base + #ctx.log, entries = out }
	elseif op == "State" then
		local ents = {}
		for _, e in CoreCombat.All() do
			local r, h = pose(e)
			ents[e.name] = {
				meter = math.floor(e.meter + 0.5),
				stunned = workspace:GetServerTimeNow() < e.stunUntil,
				immune = workspace:GetServerTimeNow() < e.immuneUntil,
				stuns = e.stuns,
				shieldUp = e.shieldUp,
				energy = math.floor(e.shieldEnergy + 0.5),
				broken = workspace:GetServerTimeNow() < e.shieldBrokenUntil,
				team = CoreCombat.TeamOf(e.model),
				root = r,
				head = h,
			}
		end
		local players = {}
		for p, n in ctx.net do
			players[p.Name] = { rtt = n.rtt, samples = n.samples, move = CoreMove.Stats(p) }
		end
		return { entities = ents, discs = CoreDisc.Count(), players = players }
	elseif op == "Reset" then
		CoreDisc.Clear(nil)
		CoreCombat.ResetAll()
		CoreMove.Reset(nil)
		ctx.logEvent({ kind = "test_reset" })
		return true
	elseif op == "DummyThrow" then
		local dm = CoreDummies.Find(args[1])
		local target = CoreCombat.ByName(args[2])
		if not dm or not target then
			return "missing"
		end
		local part = (args[3] :: string?) or "BODY"
		local lead = (args[4] :: number?) or 0
		local droot = dm:FindFirstChild("HumanoidRootPart") :: BasePart
		local r, h = pose(target)
		if not r or not h then
			return "nopose"
		end
		local aim = if part == "HEAD" then h else r
		local vel = (target.model:FindFirstChild("HumanoidRootPart") :: BasePart).AssemblyLinearVelocity
		aim += vel * lead
		local origin = droot.Position + Vector3.new(0, 1, 0)
		local id = CoreDisc.Throw(dm, dm.Name, 0, origin, (aim - origin).Unit, 0, args[5])
		return id
	elseif op == "ThrowFrom" then
		local dm = CoreDummies.Find(args[4])
		if not dm then
			return "missing"
		end
		return CoreDisc.Throw(dm, dm.Name, 0, args[1], (args[2] :: Vector3).Unit, 0, args[5])
	elseif op == "SetShield" then
		local e = CoreCombat.ByName(args[1])
		if not e then
			return "missing"
		end
		return CoreCombat.SetShield(e, args[2] == true, math.rad((args[3] :: number?) or 0))
	elseif op == "Pose" then
		local e = CoreCombat.ByName(args[1])
		if not e then
			return "missing"
		end
		local r, h = pose(e)
		return { root = r, head = h }
	elseif op == "Trace" then -- Step 1E correction pass: server hit trace for (ownerName, n)
		return CoreDisc.TraceLog[tostring(args[1]) .. ":" .. tostring(args[2])]
	elseif op == "HistAt" then -- (entityName, { serverTimes }) -> sampled root / head / state / slide weight
		local e = CoreCombat.ByName(args[1])
		if not e then
			return "missing"
		end
		-- from the 10 s diagnostics ring (linear interpolation)
		local dg = (e :: any).diag or {}
		local out = {}
		for _, t in args[2] do
			local r
			for i = 2, #dg do
				if dg[i - 1].t <= t and dg[i].t >= t then
					local k = (t - dg[i - 1].t) / math.max(1e-4, dg[i].t - dg[i - 1].t)
					r = { t = t, root = dg[i - 1].pos:Lerp(dg[i].pos, k), head = dg[i - 1].head:Lerp(dg[i].head, k), state = dg[i].state,
						sw = dg[i - 1].sw + (dg[i].sw - dg[i - 1].sw) * k, vel = dg[i].vel }
					break
				end
			end
			table.insert(out, r or { t = t })
		end
		return out
	elseif op == "Diag" then -- Step 1E final head-hitbox correction: (entityName, fromServerTime) -> raw diagnostics ring
		-- entries { t, cf (root), head (physical Head), hc (head-hit centre), hw (wall-head weight), state }
		local e = CoreCombat.ByName(args[1])
		if not e then
			return "missing"
		end
		local out = {}
		for _, d in (e :: any).diag or {} do
			if d.t >= (args[2] or 0) then
				table.insert(out, { t = d.t, cf = d.cf, head = d.head, hc = d.hc, hw = d.hw, state = d.state })
			end
		end
		return out
	elseif op == "Hit" then
		local e = CoreCombat.ByName(args[1])
		if not e then
			return "missing"
		end
		return CoreCombat.ApplyHit(e, args[2])
	end
	return "unknown op"
end

return CoreTest
