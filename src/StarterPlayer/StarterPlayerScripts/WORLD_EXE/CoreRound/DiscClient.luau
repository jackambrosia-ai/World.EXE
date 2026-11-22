--!strict
-- DiscClient (Core Round Step 1, client): throwing input, disc visuals for every disc, hit feedback.
-- The SERVER decides every hit (CoreDisc). This client:
--   * predicts its own disc the moment you throw (no wait for the server), then follows server events
--     (bounce / turn / block / end) and corrects if they disagree;
--   * draws other discs from the server's launch event, advanced by the elapsed time;
--   * records, for its own throws, which target the disc VISIBLY crossed on this screen (head / body), so the
--     Step 1 latency test can compare "what the thrower saw" with "what the server confirmed".
-- Visuals: a team-coloured spinning disc, a 0.6 s trail, a ring mark at the bounce point, impact bursts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Aim = require(script.Parent:WaitForChild("Aim"))
local Poses = require(script.Parent:WaitForChild("Poses")) -- Step 1C: drawn slide weight for the visible-hit record

local DiscClient = {}

local player = Players.LocalPlayer
local function tune(k: string): number
	return CoreConfig.Tune("Disc", k)
end

type Vis = {
	id: number?,
	n: number?,
	owner: string,
	team: string,
	pos: Vector3,
	dir: Vector3,
	phase: string,
	travelled: number,
	bounces: number,
	part: BasePart,
	spin: number,
	mine: boolean,
	t0: number,
	seen: { [string]: { out: string?, ret: string?, outT: number? } }, -- own throws: visible crossings per target
	-- Step 1B: flight from the throw's charge (same lerp as the server)
	charge: number,
	outSpeed: number,
	range: number,
	retSpeed: number,
}

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- charging state (own)
local charging = false
local chargeT0 = 0
local maxCued = false
local lastTick = 0
local byId: { [number]: Vis } = {}
local pending: { [number]: Vis } = {} -- own predicted discs by client sequence n, before the server id arrives
local mine: Vis? = nil
local seq = 0
local readyAt = 0 -- os.clock()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local send: (string, { [string]: any }) -> () = function() end
local blockers: { shieldUp: () -> boolean, stunned: () -> boolean } = {
	shieldUp = function()
		return false
	end,
	stunned = function()
		return false
	end,
}
local hud: any = nil

-- Step 1E correction pass (Studio diagnostics, off unless Workspace attribute CR_HitTrace is true): per own throw n,
-- every disc step that passes within 10 studs of an enemy: server-clock time, disc segment, the target root / head
-- as drawn here, the drawn slide weight / slide head, and this screen's verdict.
DiscClient.Trace = {} :: { [number]: { { [string]: any } } }
-- diagnostics: per own throw n -> { visible = { target, part, pass }..., server = {...} }
DiscClient.Records = {} :: { [number]: { [string]: any } }

local function colorOf(team: string): Color3
	return (CoreConfig.TeamColors :: any)[team] or CoreConfig.NeutralColor
end

local function myTeam(): string
	return if player.Team then player.Team.Name else ""
end

-- every combat entity this client can see: other players' characters + yard dummies
local function entities(): { [string]: Model }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			out[p.Name] = p.Character
		end
	end
	local yard = workspace:FindFirstChild("CoreRoundYard")
	local d = yard and yard:FindFirstChild("Dummies")
	if d then
		for _, m in d:GetChildren() do
			if m:IsA("Model") then
				out[m.Name] = m
			end
		end
	end
	return out
end

local function teamOfModel(m: Model): string
	local p = Players:GetPlayerFromCharacter(m)
	if p then
		return if p.Team then p.Team.Name else ""
	end
	local t = m:GetAttribute("CR_Team")
	return if typeof(t) == "string" then t else ""
end

local function ownerRoot(v: Vis): BasePart?
	local m = entities()[v.owner]
	return m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function makePart(team: string): BasePart
	local p = Instance.new("Part")
	p.Name = "Disc"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, 2.2, 2.2)
	p.Material = Enum.Material.Neon
	p.Color = colorOf(team)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	-- trail attachments on the spin axis (the cylinder's X axis, vertical in flight) so the ribbon does not twist
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.3, 0, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-0.3, 0, 0)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = tune("TrailSeconds")
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(colorOf(team))
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.WidthScale = NumberSequence.new(1, 0.2)
	tr.Parent = p
	-- inner core ring (dark centre reads as a disc, not a ball)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Cylinder
	core.Size = Vector3.new(0.34, 1.1, 1.1)
	core.Material = Enum.Material.SmoothPlastic
	core.Color = Color3.fromRGB(20, 24, 30)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Parent = p
	p.Parent = Fx.Folder()
	return p
end

local function newVis(owner: string, team: string, pos: Vector3, dir: Vector3, isMine: boolean, charge: number?): Vis
	local k = math.clamp(charge or 0, 0, 1)
	local part = makePart(team)
	if k > 0 then
		-- a charged disc reads hotter: brighter core, wider trail
		part.Size = Vector3.new(0.3, 2.2 + 0.6 * k, 2.2 + 0.6 * k)
		local tr = part:FindFirstChildOfClass("Trail")
		if tr then
			tr.WidthScale = NumberSequence.new(1 + k, 0.2)
			tr.Transparency = NumberSequence.new(0.2 - 0.15 * k, 1)
		end
		local core = part:FindFirstChild("Core") :: BasePart?
		if core then
			core.Color = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(20, 24, 30), 1 - k)
			core.Material = if k > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	return {
		id = nil,
		n = nil,
		owner = owner,
		team = team,
		pos = pos,
		dir = dir.Unit,
		phase = "out",
		travelled = 0,
		bounces = 0,
		part = part,
		spin = 0,
		mine = isMine,
		t0 = os.clock(),
		seen = {},
		charge = k,
		outSpeed = lerp(tune("OutSpeed"), tune("ChargedOutSpeed"), k),
		range = lerp(tune("Range"), tune("ChargedRange"), k),
		retSpeed = lerp(tune("ReturnSpeed"), tune("ChargedReturnSpeed"), k),
	}
end

local function removeVis(v: Vis, how: string)
	if v.id then
		byId[v.id] = nil
	end
	if v.n then
		pending[v.n] = nil
	end
	if mine == v then
		mine = nil
	end
	if how == "caught" then
		Fx.Burst(v.pos, colorOf(v.team), 2.2)
		if v.mine then
			Fx.Sound("catch")
		end
	end
	local p = v.part
	-- let the trail fade out
	p.Transparency = 1
	local core = p:FindFirstChild("Core") :: BasePart?
	if core then
		core.Transparency = 1
	end
	task.delay(tune("TrailSeconds"), function()
		p:Destroy()
	end)
end

-- client-side hit volumes (same maths as the server, against what THIS screen shows; no rewind)
local function visibleHit(m: Model, a: Vector3, b: Vector3): string?
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = m:FindFirstChild("Head") :: BasePart?
	if not root or not head then
		return nil
	end
	local _, part = CoreGeom.DiscHit(a, b, root.Position, head.Position, {
		headR = tune("HeadRadius"),
		bodyR = tune("BodyRadius"),
		bodyTop = tune("BodyTop"),
		bodyBottom = tune("BodyBottom"),
		r = tune("Radius"),
		tol = tune("HitTolerance"),
		-- Step 1C: a sliding target's volumes as drawn on THIS screen (same eased curve the server uses)
		slideHead = Poses.SlideHead(m),
		slideTop = CoreConfig.Tune("Slide", "BodyTop"),
		slideBottom = CoreConfig.Tune("Slide", "BodyBottom"),
		slideW = Poses.SlideWeight(m),
	})
	return part
end

local function stepVis(v: Vis, dt: number)
	local speed
	if v.phase == "ret" then
		local root = ownerRoot(v)
		if not root then
			return
		end
		local to = root.Position - v.pos
		if to.Magnitude <= tune("CatchRadius") then
			v.pos = root.Position
			return -- wait for the server's end event (the owner sees the catch at once anyway)
		end
		v.dir = to.Unit
		speed = v.retSpeed
	else
		speed = v.outSpeed
	end
	local a = v.pos
	local step = v.dir * speed * dt
	local b = a + step
	if v.phase == "out" then
		local ignore: { Instance } = { Fx.Folder() }
		for _, m in entities() do
			table.insert(ignore, m)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Spherecast(a, tune("Radius"), step, params)
		if hit then
			local n = hit.Normal
			if math.abs(n.Y) < 0.7 and v.bounces < tune("Bounces") then
				v.bounces += 1
				v.pos = hit.Position + n * (tune("Radius") * 0.5)
				v.dir = (v.dir - 2 * v.dir:Dot(n) * n).Unit
				Fx.Ring(hit.Position + n * 0.05, n, colorOf(v.team), 3, tune("TrailSeconds"))
				Fx.Sound("bounce", hit.Position)
			else
				v.pos = hit.Position + n * (tune("Radius") * 0.5)
				v.phase = "ret"
			end
			b = v.pos
		else
			v.pos = b
			v.travelled += step.Magnitude
			if v.travelled >= v.range then
				v.phase = "ret"
			end
		end
	else
		v.pos = b
	end
	-- own throws: record what this screen shows the disc crossing
	if v.mine and v.n then
		for name, m in entities() do
			if name ~= player.Name and (myTeam() == "" or teamOfModel(m) ~= myTeam()) then
				local part = visibleHit(m, a, b)
				if workspace:GetAttribute("CR_HitTrace") == true then
					local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
					local head = m:FindFirstChild("Head") :: BasePart?
					if root and head and (root.Position - b).Magnitude < 10 then
						local tr = DiscClient.Trace[v.n] or {}
						DiscClient.Trace[v.n] = tr
						if #tr < 300 then
							table.insert(tr, { st = workspace:GetServerTimeNow(), pass = v.phase, a = a, b = b, root = root.Position,
								head = head.Position, vel = root.AssemblyLinearVelocity, sw = Poses.SlideWeight(m), sh = Poses.SlideHead(m),
								state = m:GetAttribute("CR_MoveState"), part = part })
						end
					end
				end
				if part then
					local s = v.seen[name] or {}
					v.seen[name] = s
					if v.phase == "out" then
						if not s.out then
							s.out = part
							s.outT = os.clock()
						end
					elseif not s.ret and (s.out == nil or tune("SameTargetPerThrow") >= 1.5) then
						s.ret = part -- same rule as the server: by default a target already crossed on the way out does not count again
					end
					local rec = DiscClient.Records[v.n]
					if rec then
						rec.visible[name] = { out = s.out, ret = s.ret }
					end
				end
			end
		end
	end
	-- orient + spin
	v.spin += dt * 40
	-- cylinder axis = X: lay it flat (axis up), then spin around the vertical
	v.part.CFrame = CFrame.new(v.pos) * CFrame.Angles(0, v.spin, 0) * CFrame.Angles(0, 0, math.rad(90))
	local core = v.part:FindFirstChild("Core") :: BasePart?
	if core then
		core.CFrame = v.part.CFrame
	end
end

-- ---------- throwing ----------
function DiscClient.CanThrow(): (boolean, string?)
	if blockers.stunned() then
		return false, "stunned"
	end
	if blockers.shieldUp() then
		return false, "shield"
	end
	if mine then
		return false, "in_flight"
	end
	if os.clock() < readyAt then
		return false, "cooldown"
	end
	return true, nil
end

-- dirOverride: test kit only (a scripted aim direction). charge: 0 (tap) .. 1 (full), from ChargeRelease.
function DiscClient.Throw(dirOverride: Vector3?, charge: number?): (boolean, string?)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not c or not hrp then
		return false, "nochar"
	end
	local ok, why = DiscClient.CanThrow()
	if not ok then
		Fx.Sound("deny")
		if hud then
			hud.Deny(why)
		end
		return false, why
	end
	local k = math.clamp(charge or 0, 0, 1)
	local origin = hrp.Position + Vector3.new(0, 1.2, 0)
	local dir = dirOverride or (Aim.Point() - origin)
	if dir.Magnitude < 1e-3 then
		dir = hrp.CFrame.LookVector
	end
	dir = dir.Unit
	seq += 1
	local v = newVis(player.Name, myTeam(), origin, dir, true, k)
	v.n = seq
	pending[seq] = v
	mine = v
	DiscClient.Records[seq] = { t = os.clock(), visible = {}, server = {}, origin = origin, dir = dir, charge = k }
	-- Step 1E: the throw carries WHERE this screen drew each nearby enemy at release. Step 1E closeout: the server
	-- logs it as an agreement diagnostic only; the authoritative rewind is server-measured latency + a fixed offset
	-- (Disc.RewindPlayerOffset) and hits are judged on the server only.
	local view = {}
	for name, m in entities() do
		if name ~= player.Name and (myTeam() == "" or teamOfModel(m) ~= myTeam()) and #view < 8 then
			local r = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and (r.Position - origin).Magnitude < 90 then
				table.insert(view, { name, r.Position })
			end
		end
	end
	send("throw", { n = seq, origin = origin, dir = dir, charge = k, view = view })
	Fx.Sound(if k > 0.95 then "throw_max" else "throw")
	return true, nil
end

-- ---------- Step 1B: hold to charge (Knockout City reference: tap = quick throw, hold = faster / farther) ----------
function DiscClient.Charging(): (boolean, number)
	if not charging then
		return false, 0
	end
	return true, math.clamp((os.clock() - chargeT0 - tune("TapSeconds")) / math.max(0.05, tune("ChargeSeconds")), 0, 1)
end

function DiscClient.ChargeBegin(): (boolean, string?)
	if charging then
		return true, nil
	end
	local ok, why = DiscClient.CanThrow()
	if not ok then
		Fx.Sound("deny")
		if hud then
			hud.Deny(why)
		end
		return false, why
	end
	charging = true
	chargeT0 = os.clock()
	maxCued = false
	lastTick = 0
	send("charge", { n = seq + 1 })
	return true, nil
end

function DiscClient.ChargeCancel(reason: string)
	if not charging then
		return
	end
	charging = false
	send("charge_cancel", { why = reason })
end

function DiscClient.ChargeRelease(dirOverride: Vector3?): (boolean, string?)
	if not charging then
		return false, "not_charging"
	end
	local _, k = DiscClient.Charging()
	charging = false
	return DiscClient.Throw(dirOverride, k)
end

-- ---------- Step 1B: incoming-disc threats (Knockout City "border warning" reference) ----------
-- enemy discs heading toward the local player and close enough to matter
function DiscClient.Threats(): { { pos: Vector3, eta: number, charge: number } }
	local out = {}
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return out
	end
	local me = myTeam()
	for _, v in byId do
		if not v.mine and (me == "" or v.team ~= me) then
			local to = hrp.Position - v.pos
			local dist = to.Magnitude
			local speed = if v.phase == "ret" then v.retSpeed else v.outSpeed
			if dist < 60 and dist > 2 and v.dir:Dot(to.Unit) > 0.75 then
				table.insert(out, { pos = v.pos, eta = dist / speed, charge = v.charge })
			end
		end
	end
	return out
end

function DiscClient.Busy(): boolean
	return mine ~= nil
end

function DiscClient.ReadyIn(): number
	return math.max(0, readyAt - os.clock())
end

-- ---------- server events ----------
function DiscClient.OnEvent(kind: string, d: { [string]: any })
	if kind == "disc_launch" then
		if d.owner == player.Name then
			local v = pending[d.n]
			if v then
				v.id = d.id
				byId[d.id] = v
			end
			return
		end
		local v = newVis(d.owner, d.team, d.origin, d.dir, false, d.charge)
		v.id = d.id
		byId[d.id] = v
		-- advance by the elapsed server time so it lines up with the server disc
		local elapsed = math.clamp(workspace:GetServerTimeNow() - d.t0, 0, 0.5)
		local steps = math.ceil(elapsed / (1 / 60))
		for _ = 1, steps do
			stepVis(v, elapsed / steps)
		end
	elseif kind == "disc_bounce" then
		local v = byId[d.id]
		if v and v.bounces == 0 then
			v.bounces = 1
			v.pos = d.pos
			v.dir = d.dir
			Fx.Ring(d.pos, d.dir, colorOf(v.team), 3, tune("TrailSeconds"))
		elseif v and (v.pos - d.pos).Magnitude > 6 and v.phase == "out" then
			v.pos = d.pos
			v.dir = d.dir
		end
	elseif kind == "disc_turn" then
		local v = byId[d.id]
		if v and v.phase == "out" then
			v.phase = "ret"
			if (v.pos - d.pos).Magnitude > 4 then
				v.pos = d.pos
			end
		end
	elseif kind == "disc_block" then
		local v = byId[d.id]
		local col = if v then colorOf(v.team) else CoreConfig.NeutralColor
		Fx.Ring(d.pos, if v then -v.dir else Vector3.yAxis, Color3.new(1, 1, 1), 4, 0.25)
		Fx.Burst(d.pos, col, 2.5)
		Fx.Sound("block", d.pos)
		if v and v.phase == "out" then
			v.phase = "ret"
			v.pos = d.pos
		end
		if d.broke then
			Fx.Sound("shield_break", d.pos)
		end
		if hud then
			hud.Blocked(d)
		end
	elseif kind == "disc_end" then
		local v = byId[d.id]
		if not v and d.owner == player.Name then
			v = pending[d.n]
		end
		if v then
			removeVis(v, d.how)
		end
		if d.owner == player.Name then
			local k = if v then v.charge else 0
			local penalty = if d.how == "snap" then tune("SnapPenaltySeconds") else lerp(tune("RethrowSeconds"), tune("ChargedRethrowSeconds"), k)
			readyAt = os.clock() + penalty
		end
	elseif kind == "hit" then
		local col = if d.kind == "HEAD" then Color3.fromRGB(255, 214, 64) else Color3.new(1, 1, 1)
		Fx.Burst(d.pos, col, if d.stunned then 5 else 2.2)
		if d.stunned then
			Fx.Sound("stun", d.pos)
		end
		if d.attacker == player.Name then
			Fx.Sound(if d.kind == "HEAD" then "hit_head" else "hit_body")
			local rec = DiscClient.Records[d.n]
			if rec then
				rec.server[d.target .. ":" .. d.pass] = { part = d.kind, stunned = d.stunned, meter = d.meter, immune = d.immune, ignored = d.ignored }
			end
		end
		if hud then
			hud.Hit(d)
		end
	elseif kind == "reject" and d.op == "throw" then
		local v = pending[d.n]
		if v then
			removeVis(v, "rejected")
		end
		if hud then
			hud.Deny(d.why)
		end
	elseif kind == "reject" and d.op == "charge" then
		charging = false
		if hud then
			hud.Deny(d.why)
		end
	end
end

-- ---------- Step 1B: charge presentation (own + other players via CR_ChargeStart) ----------
-- A disc appears in the throwing hand and heats up (size, brightness, spin), a team-coloured ring tightens around the
-- character, and rising ticks play; at full charge a white flash + chime. Readable to the opponent (anticipation).
type Held = { disc: BasePart, ring: BasePart }
local held: { [Model]: Held } = {}

local function handOf(c: Model): BasePart?
	return (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm") or c:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local function heldFor(c: Model, team: string): Held
	local h = held[c]
	if h then
		return h
	end
	local disc = makePart(team)
	disc.Name = "HeldDisc"
	local tr = disc:FindFirstChildOfClass("Trail")
	if tr then
		tr.Enabled = false
	end
	local ring = Instance.new("Part")
	ring.Name = "ChargeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = colorOf(team)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 0.6
	ring.Parent = Fx.Folder()
	h = { disc = disc, ring = ring }
	held[c] = h
	return h
end

local function dropHeld(c: Model)
	local h = held[c]
	if h then
		h.disc:Destroy()
		h.ring:Destroy()
		held[c] = nil
	end
end

local function chargeOf(c: Model): number?
	if c == player.Character then
		local on, k = DiscClient.Charging()
		return if on then k else nil
	end
	local cs = c:GetAttribute("CR_ChargeStart")
	if typeof(cs) ~= "number" then
		return nil
	end
	return math.clamp((workspace:GetServerTimeNow() - cs - tune("TapSeconds")) / math.max(0.05, tune("ChargeSeconds")), 0, 1)
end

local discWall: ((Model) -> (Vector3?, Vector3?))? = nil -- Poses.DiscWall (security gate pass)

local function updateCharge(dt: number)
	local seen: { [Model]: boolean } = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local k = c and chargeOf(c)
		if c and k then
			seen[c] = true
			local team = if p.Team then p.Team.Name else ""
			local h = heldFor(c, team)
			local hand = handOf(c)
			local hrp = c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hand and hrp then
				local spin = os.clock() * (10 + 30 * k)
				local wp, wn = nil, nil
				if discWall then
					wp, wn = discWall(c)
				end
				if wp and wn then
					-- security gate pass (owner wall-run direction): charging on a right-hand wall-run, the raised arm's
					-- disc spins EDGE-ON to the wall (its plane parallel to the wall), kept 0.3 off it - a flat disc on
					-- the palm would cut into the wall. Charge, glow, spin and the throw itself are unchanged.
					local pos = (hand.CFrame * CFrame.new(0, -0.9, 0)).Position
					pos += wn * math.max(0, 0.3 + h.disc.Size.X * 0.5 - (pos - wp):Dot(wn))
					h.disc.CFrame = CFrame.fromMatrix(pos, wn, Vector3.yAxis) * CFrame.Angles(spin, 0, 0)
				else
					h.disc.CFrame = hand.CFrame * CFrame.new(0, -0.9, -0.4) * CFrame.Angles(0, spin, 0) * CFrame.Angles(0, 0, math.rad(90))
				end
				local core = h.disc:FindFirstChild("Core") :: BasePart?
				if core then
					core.CFrame = h.disc.CFrame
					core.Color = Color3.fromRGB(20, 24, 30):Lerp(Color3.new(1, 1, 1), k)
					core.Material = if k > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
				end
				local radius = 7 - 3.5 * k
				h.ring.Size = Vector3.new(0.12, radius * 2, radius * 2)
				h.ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
				h.ring.Transparency = if Fx.Reduced then 0.85 else 0.7 - 0.4 * k
				h.ring.Color = if k >= 1 then Color3.new(1, 1, 1) else colorOf(team)
			end
		end
	end
	for c in held do
		if not seen[c] or not c.Parent then
			dropHeld(c)
		end
	end
	-- own audio cues + cancel rules
	if charging then
		if blockers.stunned() then
			DiscClient.ChargeCancel("stunned")
		elseif blockers.shieldUp() then
			DiscClient.ChargeCancel("shield")
		else
			local _, k = DiscClient.Charging()
			local t = os.clock()
			if k < 1 and t - lastTick > 0.13 and t - chargeT0 > tune("TapSeconds") then
				lastTick = t
				Fx.Sound("charge_tick", nil, 0.9 + k * 0.9)
			elseif k >= 1 and not maxCued then
				maxCued = true
				Fx.Sound("charge_max")
				local c = player.Character
				local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					Fx.Burst(hrp.Position + Vector3.new(0, 1, 0), Color3.new(1, 1, 1), 3)
				end
			end
		end
	end
	local _ = dt
end

function DiscClient.Start(deps: { send: (string, { [string]: any }) -> (), shieldUp: () -> boolean, stunned: () -> boolean, hud: any, discWall: ((Model) -> (Vector3?, Vector3?))? })
	send = deps.send
	discWall = deps.discWall
	blockers = { shieldUp = deps.shieldUp, stunned = deps.stunned }
	hud = deps.hud
	RunService.RenderStepped:Connect(function(dt)
		for _, v in byId do
			stepVis(v, dt)
		end
		for _, v in pending do
			if not v.id then
				stepVis(v, dt)
			end
		end
		-- a lost prediction (no server answer) is cleared after the max flight time
		local m = mine
		if m and os.clock() - m.t0 > tune("ChargedMaxFlightSeconds") + 1.5 then
			removeVis(m, "timeout")
		end
		updateCharge(dt)
	end)
	player.CharacterAdded:Connect(function()
		local m = mine
		if m then
			removeVis(m, "respawn")
		end
		readyAt = 0
		charging = false
	end)
end

return DiscClient
