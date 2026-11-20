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
	-- history ring: { t, root CFrame, head position }
	hist: { { t: number, cf: CFrame, head: Vector3 } },
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
	}
	local fixed = m:GetAttribute("CR_ShieldFixedYaw")
	if typeof(fixed) == "number" then
		e.shieldFixed = true
		e.shieldUp = true
		e.shieldYaw = math.rad(fixed)
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
			e.hist[e.histN] = { t = t, cf = root.CFrame, head = head.Position }
		end
	end
end

-- pose at server time t (interpolated); falls back to the live pose
function CoreCombat.Sample(e: Entity, t: number): (CFrame?, Vector3?)
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
		return best.cf:Lerp(after.cf, a), best.head:Lerp(after.head, a)
	end
	local h = best or after
	if h then
		return h.cf, h.head
	end
	local root, head = rootOf(e.model), headOf(e.model)
	if root and head then
		return root.CFrame, head.Position
	end
	return nil, nil
end

-- swept disc (a -> b, disc radius r) vs an entity pose. Returns (fraction, "HEAD"/"BODY") or nil.
-- The head sphere is tested first (a pass through the head is a headshot); the body capsule ends at the neck.
function CoreCombat.TestHit(cf: CFrame, head: Vector3, a: Vector3, b: Vector3, r: number): (number?, string?)
	return CoreGeom.DiscHit(a, b, cf.Position, head, {
		headR = tune("Disc", "HeadRadius"),
		bodyR = tune("Disc", "BodyRadius"),
		bodyTop = tune("Disc", "BodyTop"),
		bodyBottom = tune("Disc", "BodyBottom"),
		r = r,
		tol = tune("Disc", "HitTolerance"),
	})
end

-- shield panel of an entity (or nil if not raised / broken)
function CoreCombat.Panel(e: Entity): (Vector3?, Vector3?, Vector3?, Vector3?, number?, number?)
	if not e.shieldUp then
		return nil, nil, nil, nil, nil, nil
	end
	local root = rootOf(e.model)
	if not root then
		return nil, nil, nil, nil, nil, nil
	end
	local n = Vector3.new(math.sin(e.shieldYaw), 0, math.cos(e.shieldYaw)) -- facing (front normal)
	local up = Vector3.yAxis
	local right = up:Cross(n).Unit
	local c = root.Position + n * tune("Shield", "Forward") + up * tune("Shield", "Lift")
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
	if yaw and yaw == yaw then
		e.shieldYaw = yaw
	end
	e.shieldLastUse = t
	publish(e)
	return true, nil
end

function CoreCombat.SetYaw(e: Entity, yaw: number)
	if e.shieldUp and yaw == yaw then
		e.shieldYaw = yaw
		e.model:SetAttribute("CR_ShieldYaw", yaw)
	end
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
