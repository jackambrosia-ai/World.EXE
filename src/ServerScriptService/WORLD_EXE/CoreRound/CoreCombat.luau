--!strict
-- CoreCombat (Core Round Step 1, server): combat entities (player characters + yard dummies), their
-- position history (for lag-compensated disc hits), the disruption meter / stun, and the holographic shield.
--
-- Everything here is server-authoritative. Replicated state is published as attributes on the entity model:
--   CR_Meter (0..100), CR_StunUntil, CR_ImmuneUntil (server time, workspace:GetServerTimeNow()),
--   CR_ShieldUp (bool), CR_ShieldYaw (radians), CR_ShieldEnergy (0..100), CR_ShieldBrokenUntil,
--   CR_Team (string), CR_Stuns (diagnostic count), CR_LastHit ("BODY"/"HEAD")
-- The shield is PURE MATHS on the server (a rectangle in front of the entity): no part exists here, so it can
-- never obstruct characters or pickups. Clients draw a non-colliding visual from the attributes.

local Players = game:GetService("Players")

local CoreRound = game:GetService("ReplicatedStorage"):WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))

local CoreCombat = {}

export type Entity = {
	model: Model,
	player: Player?,
	name: string,
	-- history ring: { t, root CFrame, head position, shield yaw / up, movement state }
	hist: { { t: number, cf: CFrame, head: Vector3, yaw: number, up: boolean, state: string, sw: number } },
	moveState: string, -- Step 1B: "run" | "slide" | "wallrun" (validated by the server)
	moveStateT: number,
	slideStartT: number?, -- Step 1C: server times the current / last slide started and ended (blended hit volumes)
	slideEndT: number?,
	slideHead: number?, -- Step 1C: this rig's drawn slide-head height above the root (CoreGeom.PosedHeadOffset)
	wallEndT: number?, -- Step 1D: server time the last wall-run ended (carried-speed window in the speed monitor)
	chargeStart: number?, -- Step 1B: server time the throw button was pressed (charge timing is server-side)
	histN: number,
	meter: number,
	lastHit: number,
	stunUntil: number,
	immuneUntil: number,
	stuns: number,
	shieldUp: boolean,
	shieldYaw: number,
	shieldEnergy: number,
	shieldBrokenUntil: number,
	shieldLastUse: number,
	shieldFixed: boolean, -- dummies with a permanent shield (test fixtures)
}

local HIST = 72 -- ~1.2 s at 60 Hz
local entities: { [Model]: Entity } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function tune(g: string, k: string): number
	return CoreConfig.Tune(g, k)
end

function CoreCombat.Now(): number
	return now()
end

local function rootOf(m: Model): BasePart?
	return m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function headOf(m: Model): BasePart?
	return m:FindFirstChild("Head") :: BasePart?
end

function CoreCombat.TeamOf(m: Model): string
	local e = entities[m]
	if e and e.player then
		return if e.player.Team then e.player.Team.Name else ""
	end
	local t = m:GetAttribute("CR_Team")
	return if typeof(t) == "string" then t else ""
end

local function publish(e: Entity)
	local m = e.model
	m:SetAttribute("CR_Meter", math.floor(e.meter + 0.5))
	m:SetAttribute("CR_StunUntil", e.stunUntil)
	m:SetAttribute("CR_ImmuneUntil", e.immuneUntil)
	m:SetAttribute("CR_ShieldUp", e.shieldUp)
	m:SetAttribute("CR_ShieldYaw", e.shieldYaw)
	m:SetAttribute("CR_ShieldEnergy", math.floor(e.shieldEnergy + 0.5))
	m:SetAttribute("CR_ShieldBrokenUntil", e.shieldBrokenUntil)
	m:SetAttribute("CR_Stuns", e.stuns)
	m:SetAttribute("CR_Team", CoreCombat.TeamOf(m))
end

function CoreCombat.Register(m: Model, player: Player?): Entity
	local existing = entities[m]
	if existing then
		return existing
	end
	local e: Entity = {
		model = m,
		player = player,
		name = if player then player.Name else m.Name,
		hist = table.create(HIST),
		histN = 0,
		meter = 0,
		lastHit = -100,
		stunUntil = 0,
		immuneUntil = 0,
		stuns = 0,
		shieldUp = false,
		shieldYaw = 0,
		shieldEnergy = tune("Shield", "Energy"),
		shieldBrokenUntil = 0,
		shieldLastUse = -100,
		shieldFixed = false,
		moveState = "run",
		moveStateT = 0,
		chargeStart = nil,
	}
	local fixed = m:GetAttribute("CR_ShieldFixedYaw")
	if typeof(fixed) == "number" and fixed == fixed and math.abs(fixed) <= 360 then
		e.shieldFixed = true
		e.shieldUp = true
		e.shieldYaw = CoreCombat.SafeYaw(math.rad(fixed)) or 0
	end
	entities[m] = e
	publish(e)
	m.Destroying:Connect(function()
		entities[m] = nil
	end)
	return e
end

function CoreCombat.Unregister(m: Model)
	entities[m] = nil
end

function CoreCombat.Get(m: Model): Entity?
	return entities[m]
end

function CoreCombat.All(): { [Model]: Entity }
	return entities
end

function CoreCombat.ByName(name: string): Entity?
	for _, e in entities do
		if e.name == name then
			return e
		end
	end
	return nil
end

function CoreCombat.IsStunned(m: Model): boolean
	local e = entities[m]
	return e ~= nil and now() < e.stunUntil
end

-- record the current pose of every entity (call every Heartbeat)
function CoreCombat.Record()
	local t = now()
	for m, e in entities do
		local root, head = rootOf(m), headOf(m)
		if root and head and m.Parent then
			e.histN = e.histN % HIST + 1
			local sw = CoreGeom.SlideWeight(e.slideStartT, e.slideEndT, t, tune("Slide", "PoseBlendSeconds"))
			e.hist[e.histN] = { t = t, cf = root.CFrame, head = head.Position, yaw = e.shieldYaw, up = e.shieldUp, state = e.moveState, sw = sw }
			-- Step 1E correction pass: a longer (10 s) diagnostics ring, Studio test attribute only (gameplay never reads it)
			if workspace:GetAttribute("CR_HitTrace") == true then
				local dg = (e :: any).diag or {}
				(e :: any).diag = dg
				table.insert(dg, { t = t, pos = root.Position, head = head.Position, state = e.moveState, sw = sw, vel = root.AssemblyLinearVelocity })
				if #dg > 700 then
					table.remove(dg, 1)
				end
			end
		end
	end
end

-- pose at server time t (interpolated); falls back to the live pose. Also returns the shield yaw / up flag and the
-- movement state recorded at that time (Step 1B: panels and slide hit volumes use the same rewound time as bodies).
-- Step 1C: the 6th value is the slide blend weight at that time (interpolated like the pose).
function CoreCombat.Sample(e: Entity, t: number): (CFrame?, Vector3?, number?, boolean?, string?, number?)
	local best, after = nil, nil
	for _, h in e.hist do
		if h.t <= t then
			if not best or h.t > best.t then
				best = h
			end
		else
			if not after or h.t < after.t then
				after = h
			end
		end
	end
	if best and after then
		local a = (t - best.t) / math.max(1e-4, after.t - best.t)
		return best.cf:Lerp(after.cf, a), best.head:Lerp(after.head, a), best.yaw, best.up, best.state, best.sw + (after.sw - best.sw) * a
	end
	local h = best or after
	if h then
		return h.cf, h.head, h.yaw, h.up, h.state, h.sw
	end
	local root, head = rootOf(e.model), headOf(e.model)
	if root and head then
		return root.CFrame, head.Position, e.shieldYaw, e.shieldUp, e.moveState, CoreGeom.SlideWeight(e.slideStartT, e.slideEndT, now(), tune("Slide", "PoseBlendSeconds"))
	end
	return nil, nil, nil, nil, nil, nil
end

local function hitShape(r: number, state: string?, slideW: number?, slideHead: number?): CoreGeom.HitShape
	return {
		headR = tune("Disc", "HeadRadius"),
		bodyR = tune("Disc", "BodyRadius"),
		bodyTop = tune("Disc", "BodyTop"),
		bodyBottom = tune("Disc", "BodyBottom"),
		r = r,
		tol = tune("Disc", "HitTolerance"),
		state = state,
		slideHead = slideHead or tune("Slide", "HeadHeight"),
		slideTop = tune("Slide", "BodyTop"),
		slideBottom = tune("Slide", "BodyBottom"),
		slideW = slideW,
	}
end
CoreCombat.HitShape = hitShape

-- swept disc (a -> b, disc radius r) vs an entity pose. Returns (fraction, "HEAD"/"BODY") or nil.
-- Step 1B: a sliding target uses the lowered slide volumes (same rule on server and client).
-- Step 1C: the volumes are blended by slideW (the rewound slide weight), matching the eased pose clients draw.
function CoreCombat.TestHit(cf: CFrame, head: Vector3, a: Vector3, b: Vector3, r: number, state: string?, slideW: number?, slideHead: number?): (number?, string?)
	return CoreGeom.DiscHit(a, b, cf.Position, head, hitShape(r, state, slideW, slideHead))
end

-- shield panel of an entity at server time t (or nil if not raised). Step 1B (review item "shield latency"): the panel
-- position and facing come from the SAME rewound time as body hits; it counts if it is up now OR was up at that time
-- (a defender who raised it before the disc arrived is not punished by latency, and a panel that was up in the
-- thrower's view still blocks).
function CoreCombat.Panel(e: Entity, t: number?): (Vector3?, Vector3?, Vector3?, Vector3?, number?, number?)
	local cf, yaw, wasUp
	if t then
		local scf, _, syaw, sup = CoreCombat.Sample(e, t)
		cf, yaw, wasUp = scf, syaw, sup
	end
	if not (e.shieldUp or wasUp) then
		return nil, nil, nil, nil, nil, nil
	end
	local root = rootOf(e.model)
	if not root then
		return nil, nil, nil, nil, nil, nil
	end
	local pos = if cf then cf.Position else root.Position
	local useYaw = if wasUp and yaw then yaw else e.shieldYaw
	local n = Vector3.new(math.sin(useYaw), 0, math.cos(useYaw)) -- facing (front normal)
	local up = Vector3.yAxis
	local right = up:Cross(n).Unit
	local c = pos + n * tune("Shield", "Forward") + up * tune("Shield", "Lift")
	return c, n, right, up, tune("Shield", "Width") / 2, tune("Shield", "Height") / 2
end

export type HitResult = { kind: string, meter: number, stunned: boolean, immune: boolean, ignored: boolean }

-- apply a confirmed disc hit (server). Returns what happened, for logging and events.
function CoreCombat.ApplyHit(e: Entity, kind: string): HitResult
	local t = now()
	if t < e.stunUntil then
		return { kind = kind, meter = e.meter, stunned = false, immune = false, ignored = true } -- no chain-stun
	end
	if t < e.immuneUntil then
		e.model:SetAttribute("CR_LastHit", kind)
		return { kind = kind, meter = e.meter, stunned = false, immune = true, ignored = false }
	end
	e.meter += if kind == "HEAD" then tune("Disrupt", "Head") else tune("Disrupt", "Body")
	e.lastHit = t
	local stunned = false
	if e.meter >= tune("Disrupt", "Threshold") then
		stunned = true
		e.meter = 0
		e.stuns += 1
		e.stunUntil = t + tune("Disrupt", "StunSeconds")
		e.immuneUntil = e.stunUntil + tune("Disrupt", "ImmuneSeconds")
		if not e.shieldFixed then
			e.shieldUp = false -- a stunned player cannot hold the shield
		end
		e.chargeStart = nil -- ... or keep charging a throw
		e.model:SetAttribute("CR_ChargeStart", nil)
	end
	e.model:SetAttribute("CR_LastHit", kind)
	publish(e)
	return { kind = kind, meter = e.meter, stunned = stunned, immune = false, ignored = false }
end

-- a blocked disc costs the shield energy; returns true if this broke the shield
function CoreCombat.BlockCost(e: Entity): boolean
	e.shieldLastUse = now()
	if e.shieldFixed then
		publish(e)
		return false
	end
	e.shieldEnergy -= tune("Shield", "BlockCost")
	if e.shieldEnergy <= 0 then
		e.shieldEnergy = 0
		e.shieldUp = false
		e.shieldBrokenUntil = now() + tune("Shield", "BrokenSeconds")
		publish(e)
		return true
	end
	publish(e)
	return false
end

-- client request to raise / lower; returns false (and a reason) when refused
function CoreCombat.SetShield(e: Entity, up: boolean, yaw: number?): (boolean, string?)
	local t = now()
	if up then
		if t < e.stunUntil then
			return false, "stunned"
		end
		if t < e.shieldBrokenUntil then
			return false, "broken"
		end
		if e.shieldEnergy <= 1 then
			return false, "empty"
		end
	end
	e.shieldUp = up
	if up and e.chargeStart then
		e.chargeStart = nil -- raising the shield cancels a charging throw
		e.model:SetAttribute("CR_ChargeStart", nil)
	end
	local y = CoreCombat.SafeYaw(yaw)
	if y then
		e.shieldYaw = y
	end
	e.shieldLastUse = t
	publish(e)
	return true, nil
end

-- Step 1B (review item "input safety"): reject NaN / infinite / absurd yaw values, wrap the rest to [-pi, pi]
function CoreCombat.SafeYaw(yaw: any): number?
	if typeof(yaw) ~= "number" or yaw ~= yaw or yaw == math.huge or yaw == -math.huge or math.abs(yaw) > 1e4 then
		return nil
	end
	return (yaw + math.pi) % (2 * math.pi) - math.pi
end

function CoreCombat.SetYaw(e: Entity, yaw: any)
	local y = CoreCombat.SafeYaw(yaw)
	if e.shieldUp and y then
		e.shieldYaw = y
		e.model:SetAttribute("CR_ShieldYaw", y)
	end
end

-- Step 1B: validated movement state ("run" / "slide" / "wallrun"), replicated as CR_MoveState
function CoreCombat.SetMoveState(e: Entity, state: string)
	local t = now()
	if state == "slide" and e.moveState ~= "slide" then
		if e.slideHead == nil then
			e.slideHead = CoreGeom.PosedHeadOffset(e.model) -- once per character (rig proportions do not change)
		end
		-- Step 1C: a new slide blends in from where the last one left off (a quick re-slide does not snap)
		local cur = CoreGeom.SlideWeight(e.slideStartT, e.slideEndT, t, tune("Slide", "PoseBlendSeconds"))
		e.slideStartT = t - cur * math.max(0.02, tune("Slide", "PoseBlendSeconds"))
		e.slideEndT = nil
	elseif state ~= "slide" and e.moveState == "slide" then
		e.slideEndT = t
	end
	if e.moveState == "wallrun" and state ~= "wallrun" then
		e.wallEndT = t
	end
	e.moveState = state
	e.moveStateT = now()
	e.model:SetAttribute("CR_MoveState", state)
end

-- per-frame: meter decay, shield drain / regen / break; publishes on change
function CoreCombat.Update(dt: number)
	local t = now()
	for _, e in entities do
		local changed = false
		if e.meter > 0 and t - e.lastHit > tune("Disrupt", "DecayDelay") then
			e.meter = math.max(0, e.meter - tune("Disrupt", "DecayRate") * dt)
			changed = true
		end
		if not e.shieldFixed then
			if e.shieldUp then
				e.shieldEnergy -= tune("Shield", "DrainPerSecond") * dt
				e.shieldLastUse = t
				if e.shieldEnergy <= 0 then
					e.shieldEnergy = 0
					e.shieldUp = false
					e.shieldBrokenUntil = t + tune("Shield", "BrokenSeconds")
				end
				changed = true
			elseif e.shieldEnergy < tune("Shield", "Energy") and t >= e.shieldBrokenUntil and t - e.shieldLastUse > tune("Shield", "RegenDelay") then
				e.shieldEnergy = math.min(tune("Shield", "Energy"), e.shieldEnergy + tune("Shield", "RegenPerSecond") * dt)
				changed = true
			end
		end
		if changed then
			publish(e)
		end
	end
end

function CoreCombat.Reset(e: Entity)
	e.meter = 0
	e.lastHit = -100
	e.stunUntil = 0
	e.immuneUntil = 0
	e.stuns = 0
	if not e.shieldFixed then
		e.shieldUp = false
	end
	e.shieldEnergy = tune("Shield", "Energy")
	e.shieldBrokenUntil = 0
	publish(e)
end

function CoreCombat.ResetAll()
	for _, e in entities do
		CoreCombat.Reset(e)
	end
end

function CoreCombat.PlayerEntity(p: Player): Entity?
	local c = p.Character
	return if c then entities[c] else nil
end

-- silence unused warning for Players in strict mode (used by callers via PlayerEntity)
local _ = Players

return CoreCombat
