--!strict
-- HackVfx (wrist-hacking prototype, client): cosmetic launch / landing effects for FLING, drawn
-- locally on every client from a server broadcast ({ op = "vfx", kind = "launch", model, pos, dir }).
-- Native parts + built-in particle texture only (no uploaded assets). Nothing here collides, is
-- queryable or affects gameplay; everything is cleaned up within a few seconds.
--
-- Reference: owner clip 2026-11-16 (fling in another Roblox experience): an orange starburst at the
-- feet with sparks, a ring of broken / tilted floor tiles (crater) that stays a few seconds, a
-- tall fast arc the camera chases, and an impact on landing.
--   launch  starburst spikes + core flash + spark burst + shockwave ring + crater tiles + scorch
--           + a flight trail on the launched character; local player: camera kick (FOV + shake)
--   land    (detected locally when the flown character reaches the ground) dust ring, small
--           crater, spark puff; local player: small shake

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local HackVfx = {}

local ORANGE = Color3.fromRGB(255, 140, 30)
local YELLOW = Color3.fromRGB(255, 220, 90)
local TILE = Color3.fromRGB(32, 34, 40)
local SCORCH = Color3.fromRGB(18, 16, 16)
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- built-in engine texture

local folder: Folder? = nil
local shakeUntil, shakeAmp = 0, 0
local fovKickUntil = 0

local function root(): Instance
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "WristHackVfx"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function vpart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = root()
	return p
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function fadeAndDestroy(p: BasePart, delay: number, seconds: number)
	task.delay(delay, function()
		if p.Parent then
			tween(p, seconds, { Transparency = 1 })
			task.delay(seconds + 0.05, function()
				p:Destroy()
			end)
		end
	end)
end

local function floorBelow(pos: Vector3, ignore: { Instance }): (Vector3, Vector3, boolean)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	if hit then
		return hit.Position, hit.Normal, true
	end
	return pos - Vector3.new(0, 3, 0), Vector3.yAxis, false
end

local function sparks(at: Vector3, count: number, speed: number, color: Color3)
	local a = vpart("SparkEmitterHost", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at), color)
	a.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK_TEXTURE
	e.Color = ColorSequence.new(YELLOW, color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0)
	e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(70, 70)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Drag = 2
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	task.delay(1, function()
		a:Destroy()
	end)
end

-- Ring of broken, tilted floor tiles around a point (cosmetic crater) plus a scorch disc.
local function crater(at: Vector3, normal: Vector3, radius: number, tiles: number, linger: number)
	local up = if normal.Y > 0.5 then normal else Vector3.yAxis
	local scorch = vpart("Scorch", Vector3.new(0.08, radius * 2.1, radius * 2.1), CFrame.new(at + up * 0.04) * CFrame.Angles(0, 0, math.rad(90)), SCORCH, Enum.Material.Slate, Enum.PartType.Cylinder)
	scorch.Transparency = 0.15
	fadeAndDestroy(scorch, linger, 1.2)
	local rng = Random.new()
	for i = 1, tiles do
		local a = (i / tiles) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local r = radius * rng:NextNumber(0.55, 1.05)
		local s = rng:NextNumber(1.6, 2.8)
		local pos = at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		-- tilt outward like slabs pushed up by the blast, partly sunk into the floor
		local cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0, math.sin(a))) * CFrame.Angles(math.rad(rng:NextNumber(18, 48)), math.rad(rng:NextNumber(-20, 20)), 0)
		local tile = vpart("CraterTile", Vector3.new(s, 0.45, s), cf + Vector3.new(0, 0.12, 0), TILE, Enum.Material.Slate)
		-- tiles pop up from below for a punchy read
		local target = tile.CFrame
		tile.CFrame = target - Vector3.new(0, 0.9, 0)
		tween(tile, 0.12, { CFrame = target }, Enum.EasingStyle.Back)
		fadeAndDestroy(tile, linger + rng:NextNumber(0, 0.6), 0.8)
	end
end

local function starburst(at: Vector3, scale: number)
	local rng = Random.new()
	-- radial spikes
	for i = 1, 11 do
		local a = (i / 11) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local len = rng:NextNumber(3.5, 7) * scale
		local tilt = rng:NextNumber(10, 55)
		local cf = CFrame.new(at) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(tilt), 0, 0) * CFrame.new(0, 0, -len / 2)
		local spike = vpart("Spike", Vector3.new(0.5 * scale, 0.5 * scale, 0.2), cf, if i % 2 == 0 then YELLOW else ORANGE, Enum.Material.Neon)
		tween(spike, 0.08, { Size = Vector3.new(0.6 * scale, 0.6 * scale, len) })
		task.delay(0.1, function()
			if spike.Parent then
				tween(spike, 0.35, { Size = Vector3.new(0.05, 0.05, len * 1.2), Transparency = 1 })
			end
		end)
		task.delay(0.5, function()
			spike:Destroy()
		end)
	end
	-- core flash
	local core = vpart("Flash", Vector3.new(1, 1, 1) * 2 * scale, CFrame.new(at), YELLOW, Enum.Material.Neon, Enum.PartType.Ball)
	tween(core, 0.12, { Size = Vector3.new(1, 1, 1) * 6 * scale })
	task.delay(0.12, function()
		if core.Parent then
			tween(core, 0.25, { Size = Vector3.new(1, 1, 1) * 7 * scale, Transparency = 1 })
		end
	end)
	task.delay(0.45, function()
		core:Destroy()
	end)
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Brightness = 6
	light.Range = 18 * scale
	light.Parent = core
end

local function shockwave(at: Vector3, radius: number, seconds: number, color: Color3)
	local ring = vpart("Shockwave", Vector3.new(0.15, 1, 1), CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.3
	tween(ring, seconds, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
	task.delay(seconds + 0.05, function()
		ring:Destroy()
	end)
end

local function trail(model: Model, seconds: number)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.5, 0)
	a1.Parent = hrp
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Color = ColorSequence.new(YELLOW, ORANGE)
	tr.LightEmission = 1
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	tr.Lifetime = 0.35
	tr.MinLength = 0.1
	tr.FaceCamera = true
	tr.Parent = hrp
	task.delay(seconds, function()
		tr.Enabled = false
		task.delay(0.4, function()
			tr:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end)
end

local function cameraKick(amp: number, seconds: number, fov: boolean)
	shakeAmp = math.max(shakeAmp, amp)
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	if fov then
		fovKickUntil = os.clock() + 0.6
	end
end

-- Watch a flown character until it reaches the ground, then play the landing impact.
local function watchLanding(model: Model, isLocal: boolean)
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - t0
		if not hrp.Parent or elapsed > 4 then
			if conn then
				conn:Disconnect()
			end
			return
		end
		if elapsed < 0.3 then
			return
		end
		local vy = hrp.AssemblyLinearVelocity.Y
		local pos, normal, found = floorBelow(hrp.Position, { model, root() })
		if found and vy <= 2 and (hrp.Position.Y - pos.Y) < 4.2 then
			if conn then
				conn:Disconnect()
			end
			shockwave(pos, 9, 0.35, Color3.fromRGB(220, 210, 190))
			crater(pos, normal, 3.2, 7, 2.5)
			sparks(pos + Vector3.new(0, 0.5, 0), 14, 18, ORANGE)
			if isLocal then
				cameraKick(0.35, 0.25, false)
			end
		end
	end)
end

function HackVfx.Launch(model: Model?, pos: Vector3, scale: number?)
	if UITheme.reducedEffects() then
		return -- Reduced Effects: no flashes / shake (gameplay unchanged)
	end
	local s = scale or 1
	local isLocal = model ~= nil and model == Players.LocalPlayer.Character
	local ignore: { Instance } = { root() }
	if model then
		table.insert(ignore, model)
	end
	local floor, normal = floorBelow(pos, ignore)
	starburst(floor + Vector3.new(0, 0.6, 0), s)
	sparks(floor + Vector3.new(0, 0.5, 0), 34, 45, ORANGE)
	shockwave(floor, 12 * s, 0.4, ORANGE)
	crater(floor, normal, 4.5 * s, 11, 4)
	if model then
		trail(model, 1.6)
		watchLanding(model, isLocal)
	end
	local cam = workspace.CurrentCamera
	if isLocal then
		cameraKick(0.9, 0.35, true)
	elseif cam and (cam.CFrame.Position - floor).Magnitude < 40 then
		cameraKick(0.25, 0.2, false)
	end
end

-- Incoming targeted hack (seen by everyone): a faint pulsing tether from the attacker and an overhead
-- warning (the defender also gets a screen banner). Returns a cleanup function.
local HACK_COLOR: { [string]: Color3 } = { FREEZE = Color3.fromRGB(175, 230, 255), FLING_TARGET = Color3.fromRGB(255, 140, 30) }
local HACK_WORD: { [string]: string } = { FREEZE = "FREEZE", FLING_TARGET = "FLING" }
function HackVfx.Incoming(attacker: Model?, target: Model, center: Vector3, radius: number, startAt: number, resolveAt: number, hackId: string): () -> ()
	local made: { Instance } = {}
	local col = HACK_COLOR[hackId] or Color3.fromRGB(255, 111, 97)
	local _ = center
	local _ = radius
	-- (the ground dodge ring was removed 2026-11-16, owner: leaving a circle no longer counters a hack)
	-- faint tether (presentation only; the rules are cover and shield)
	local aRoot = attacker and attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if aRoot and tRoot then
		local a0 = Instance.new("Attachment")
		a0.Parent = aRoot
		local a1 = Instance.new("Attachment")
		a1.Parent = tRoot
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(col)
		beam.LightEmission = 1
		beam.Width0, beam.Width1 = 0.15, 0.3
		beam.Transparency = NumberSequence.new(0.55)
		beam.FaceCamera = true
		beam.Segments = 12
		beam.CurveSize0, beam.CurveSize1 = 2, -2
		beam.Parent = aRoot
		table.insert(made, a0)
		table.insert(made, a1)
		table.insert(made, beam)
	end
	-- overhead warning with a draining timer bar
	local head = (target:FindFirstChild("Head") or tRoot) :: BasePart?
	local bar: Frame? = nil
	local isLocal = Players.LocalPlayer and target == Players.LocalPlayer.Character -- the defender already has the screen banner
	if head and not isLocal then
		local bb = Instance.new("BillboardGui")
		bb.Name = "IncomingWarning"
		bb.Size = UDim2.fromOffset(170, 46)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = head
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(10, 15, 31)
		bg.BackgroundTransparency = 0.2
		bg.BorderSizePixel = 0
		bg.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = bg
		local stroke = Instance.new("UIStroke")
		stroke.Color = col
		stroke.Thickness = 2
		stroke.Parent = bg
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 30)
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 16
		t.TextColor3 = col
		t.Text = "⚠ " .. (HACK_WORD[hackId] or hackId) .. " INCOMING"
		t.Parent = bg
		local track = Instance.new("Frame")
		track.Position = UDim2.new(0, 8, 1, -12)
		track.Size = UDim2.new(1, -16, 0, 5)
		track.BackgroundColor3 = Color3.fromRGB(58, 66, 88)
		track.BorderSizePixel = 0
		track.Parent = bg
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = col
		fill.BorderSizePixel = 0
		fill.Parent = track
		bar = fill
		bb.Parent = root()
		table.insert(made, bb)
	end
	local conn = RunService.RenderStepped:Connect(function()
		local left = resolveAt - workspace:GetServerTimeNow()
		local f = math.clamp(left / math.max(0.05, resolveAt - startAt), 0, 1)
		if bar then
			bar.Size = UDim2.fromScale(f, 1)
		end
	end)
	return function()
		conn:Disconnect()
		for _, i in made do
			i:Destroy()
		end
	end
end

-- Glide scuff (banana-peel style slide-fling, owner 2026-11-16): no blast — small dust puffs kicked
-- up under the sliding body while it moves, thinning out as it slows. Bounded (≤ 30 puffs).
function HackVfx.Glide(model: Model, seconds: number)
	if UITheme.reducedEffects() then
		return
	end
	local body = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not body then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		local n = 0
		local last: Vector3? = nil
		while os.clock() - t0 < seconds and n < 30 and body.Parent do
			local pos = body.Position
			local moved = if last then (pos - last).Magnitude else 99
			if moved > 1.2 then -- only while actually sliding
				last = pos
				n += 1
				local floor = floorBelow(pos, { model, root() })
				local size = 1.4 + math.random() * 0.8
				local puff = vpart("GlideDust", Vector3.new(size, size, size), CFrame.new(floor + Vector3.new(0, 0.5, 0)), Color3.fromRGB(215, 208, 192), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				puff.Transparency = 0.6
				tween(puff, 0.7, { Size = Vector3.new(size * 2.4, size * 1.4, size * 2.4), Transparency = 1 })
				task.delay(0.75, function()
					puff:Destroy()
				end)
			end
			task.wait(0.06)
		end
	end)
end

-- Shock link (owner 2026-11-16: "replicate the feel of hacking someone remotely ... as if they're
-- actively being electrocuted"): seen by everyone while a target is held. A jittery electric arc
-- (two thin cyan/white beams whose curve re-randomises every few frames) from the attacker's wrist
-- to the target, small sparks crawling over the target's body, a flickering cyan glow, and a 3D
-- electric crackle at the target (built-in click sound, rapid random high pitches; no uploads).
-- Returns a cleanup function.
-------------------------------------------------------------------------------------------------
-- VFX-01 lightning (owner reference 2026-11-17, TikTok stream, no SHA): "make the lightning effect look like
-- this", applied to ALL electric effects (owner choice). Observed look: curling, hooked electric strands
-- with a thin WHITE-HOT centre inside a deep saturated BLUE glow, wrapped around a blinding white-blue core,
-- re-drawn every few frames (crackle), the cluster swelling / shrinking, a few stray sparks thrown out.
-- Original build from native Neon parts (no textures / flipbooks / uploads): each bolt is a chain of
-- segments, each segment = white core part inside a wider translucent blue sheath part.
local BOLT_CORE = Color3.fromRGB(236, 248, 255)
local BOLT_GLOW = Color3.fromRGB(30, 105, 255)
local BOLT_HALO = Color3.fromRGB(50, 120, 255)
-- the place has no Bloom, so each segment fakes it: white core, saturated blue sheath, wide faint halo
type Bolt = { cores: { Part }, sheaths: { Part }, halos: { Part }, coreW: number, glowW: number }

local function newBolt(segs: number, coreW: number, glowW: number): Bolt
	local b: Bolt = { cores = {}, sheaths = {}, halos = {}, coreW = coreW, glowW = glowW }
	for _ = 1, segs do
		local core = vpart("BoltCore", Vector3.new(coreW, coreW, 1), CFrame.new(0, -1e4, 0), BOLT_CORE, Enum.Material.Neon)
		local sheath = vpart("BoltGlow", Vector3.new(1, glowW, glowW), CFrame.new(0, -1e4, 0), BOLT_GLOW, Enum.Material.Neon, Enum.PartType.Cylinder)
		sheath.Transparency = 0.4
		local halo = vpart("BoltHalo", Vector3.new(1, glowW * 2.6, glowW * 2.6), CFrame.new(0, -1e4, 0), BOLT_HALO, Enum.Material.Neon, Enum.PartType.Cylinder)
		halo.Transparency = 0.84
		table.insert(b.cores, core)
		table.insert(b.sheaths, sheath)
		table.insert(b.halos, halo)
	end
	return b
end

-- lay the bolt along pts (#pts - 1 segments used; the rest hidden); fade 0 = full, 1 = gone
local function drawBolt(b: Bolt, pts: { Vector3 }, fade: number)
	for i, core in b.cores do
		local sheath = b.sheaths[i]
		local p0, p1 = pts[i], pts[i + 1]
		if p0 and p1 and fade < 1 then
			local len = math.max(0.05, (p1 - p0).Magnitude)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			core.Size = Vector3.new(b.coreW, b.coreW, len)
			core.CFrame = cf
			core.Transparency = fade
			local tube = cf * CFrame.Angles(0, math.rad(90), 0) -- cylinder axis (X) along the segment
			sheath.Size = Vector3.new(len + b.glowW * 0.6, b.glowW, b.glowW)
			sheath.CFrame = tube
			sheath.Transparency = 0.4 + 0.6 * fade
			local halo = b.halos[i]
			halo.Size = Vector3.new(len + b.glowW * 1.5, b.glowW * 2.6, b.glowW * 2.6)
			halo.CFrame = tube
			halo.Transparency = 0.84 + 0.16 * fade
		else
			core.Transparency = 1
			sheath.Transparency = 1
			b.halos[i].Transparency = 1
		end
	end
end

local function destroyBolt(b: Bolt)
	for i, core in b.cores do
		core:Destroy()
		b.sheaths[i]:Destroy()
		b.halos[i]:Destroy()
	end
end

local function randUnit(): Vector3
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	return if v.Magnitude > 0.01 then v.Unit else Vector3.yAxis
end

-- a curling, hooked strand swept around `center` (part of a jittered great circle)
local function curlPath(center: Vector3, radius: number, segs: number): { Vector3 }
	local axis = randUnit()
	local start = axis:Cross(randUnit())
	start = if start.Magnitude > 0.01 then start.Unit else Vector3.xAxis
	local sweep = math.rad(70 + math.random() * 100) * (if math.random() < 0.5 then -1 else 1)
	local r0 = radius * (0.6 + math.random() * 0.4)
	local pts = {}
	for i = 0, segs do
		local dir = CFrame.fromAxisAngle(axis, sweep * i / segs) * start
		local rr = r0 * (1 + (math.random() - 0.5) * 0.35)
		table.insert(pts, center + dir * rr + randUnit() * radius * 0.12)
	end
	return pts
end

-- a jagged bolt from a to b (ends fixed, middle points kicked sideways)
local function jagPath(a: Vector3, b: Vector3, segs: number, amp: number): { Vector3 }
	local d = b - a
	local side1 = d:Cross(Vector3.yAxis)
	side1 = if side1.Magnitude > 0.01 then side1.Unit else Vector3.xAxis
	local side2 = d.Unit:Cross(side1).Unit
	local pts = { a }
	for i = 1, segs - 1 do
		local k = math.sin(math.pi * i / segs) -- bigger kicks mid-bolt
		table.insert(pts, a + d * (i / segs) + (side1 * (math.random() - 0.5) + side2 * (math.random() - 0.5)) * 2 * amp * k)
	end
	table.insert(pts, b)
	return pts
end

-- A crackling lightning cluster around `part` until the returned stop() (or `seconds`). opts:
-- arcs, segs, radius, every (frames between re-draws), light (PointLight brightness), core (core ball size)
local function lightningCluster(part: BasePart, opts: { arcs: number, segs: number, radius: number, every: number, light: number, core: number, seconds: number? }): () -> ()
	local bolts: { Bolt } = {}
	for _ = 1, opts.arcs do
		table.insert(bolts, newBolt(opts.segs, 0.07, 0.3))
	end
	local spark = newBolt(2, 0.05, 0.2)
	local coreBall: Part? = nil
	local coreHalo: Part? = nil
	if opts.core > 0 then
		local cb = vpart("BoltCoreFlash", Vector3.new(opts.core, opts.core, opts.core), part.CFrame, Color3.fromRGB(225, 240, 255), Enum.Material.Neon, Enum.PartType.Ball)
		cb.Transparency = 0.25
		coreBall = cb
		local ch = vpart("BoltCoreHalo", Vector3.new(opts.core * 2.4, opts.core * 2.4, opts.core * 2.4), part.CFrame, BOLT_HALO, Enum.Material.Neon, Enum.PartType.Ball)
		ch.Transparency = 0.8
		coreHalo = ch
	end
	local light: PointLight? = nil
	if opts.light > 0 then
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(90, 160, 255)
		pl.Range = 11
		pl.Brightness = opts.light
		pl.Parent = part
		light = pl
	end
	local t0 = os.clock()
	local frame = 0
	local stopped = false
	local conn: RBXScriptConnection? = nil
	local boltOffsets: { [number]: { Vector3 }? } = {}
	local sparkOffsets: { Vector3 }? = nil
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if conn then
			conn:Disconnect()
		end
		for _, b in bolts do
			destroyBolt(b)
		end
		destroyBolt(spark)
		if coreBall then
			coreBall:Destroy()
		end
		if coreHalo then
			coreHalo:Destroy()
		end
		if light then
			light:Destroy()
		end
	end
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if not part.Parent or (opts.seconds and el > opts.seconds) then
			stop()
			return
		end
		frame += 1
		local center = part.Position
		if coreBall then
			coreBall.CFrame = CFrame.new(center)
		end
		if coreHalo then
			coreHalo.CFrame = CFrame.new(center)
		end
		local fadeOut = if opts.seconds then math.clamp((el - opts.seconds * 0.7) / (opts.seconds * 0.3), 0, 1) else 0
		local function place(offs: { Vector3 }?): { Vector3 }
			local pts = {}
			if offs then
				for i, o in offs do
					pts[i] = center + o
				end
			end
			return pts
		end
		if frame % opts.every ~= 0 then
			-- between crackles the arcs ride with the body (shapes kept as offsets: no lagging at speed)
			for i, b in bolts do
				drawBolt(b, place(boltOffsets[i]), if boltOffsets[i] then fadeOut else 1)
			end
			drawBolt(spark, place(sparkOffsets), if sparkOffsets then fadeOut else 1)
			return
		end
		-- the cluster swells and shrinks; every re-draw is a new crackle
		local pulse = 0.8 + 0.25 * math.sin(el * 7) + math.random() * 0.15
		for i, b in bolts do
			if math.random() < 0.85 then
				local offs = {}
				for k, pt in curlPath(Vector3.zero, opts.radius * pulse, opts.segs) do
					offs[k] = pt
				end
				boltOffsets[i] = offs
			else
				boltOffsets[i] = nil -- a gap now and then: lightning is never steady
			end
			drawBolt(b, place(boltOffsets[i]), if boltOffsets[i] then fadeOut else 1)
		end
		if math.random() < 0.35 then -- a stray spark thrown out
			local dir = randUnit()
			local a = dir * opts.radius * (0.9 + math.random() * 0.3)
			sparkOffsets = jagPath(a, a + (dir + randUnit() * 0.6).Unit * (0.8 + math.random() * 0.9), 2, 0.15)
		else
			sparkOffsets = nil
		end
		drawBolt(spark, place(sparkOffsets), if sparkOffsets then fadeOut else 1)
		if coreBall then
			local s = opts.core * (0.7 + math.random() * 0.6) * pulse
			coreBall.Size = Vector3.new(s, s, s)
			coreBall.Transparency = 0.2 + math.random() * 0.3 + 0.5 * fadeOut
			if coreHalo then
				local hs = s * 2.4
				coreHalo.Size = Vector3.new(hs, hs, hs)
				coreHalo.Transparency = 0.78 + 0.1 * math.random() + 0.12 * fadeOut
			end
		end
		if light then
			light.Brightness = opts.light * (0.6 + math.random() * 0.6) * (1 - fadeOut)
		end
	end)
	return stop
end

function HackVfx.GrabBeam(attacker: Model?, target: Model): () -> ()
	-- Rev 15t (VFX-01): the remote-shock link is a jagged white-core / blue-glow bolt from the wrist to the
	-- target (plus a flickering branch), re-drawn every 2 frames, and a crackling lightning cluster around the
	-- held body. Glow highlight and crackle sound as before. Reduced Effects: the main bolt only.
	local made: { Instance } = {}
	local tBody = (target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso") or target:FindFirstChild("HumanoidRootPart")) :: BasePart?
	local wd = attacker and attacker:FindFirstChild("WristDevice")
	local aPart = attacker and ((wd and wd:FindFirstChildWhichIsA("BasePart", true)) or attacker:FindFirstChild("LeftHand") or attacker:FindFirstChild("Left Arm") or attacker:FindFirstChild("HumanoidRootPart")) :: BasePart?
	local reduced = UITheme.reducedEffects()
	local mainBolt: Bolt? = if tBody and aPart then newBolt(8, 0.09, 0.38) else nil
	local branch: Bolt? = if tBody and aPart and not reduced then newBolt(4, 0.05, 0.22) else nil
	local stopCluster: (() -> ())? = nil
	if tBody and not reduced then
		stopCluster = lightningCluster(tBody, { arcs = 4, segs = 6, radius = 2.7, every = 2, light = 1.6, core = 1.1 })
	end
	local glow: Highlight? = nil
	if tBody and not reduced then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromRGB(70, 150, 255)
		h.FillTransparency = 0.7
		h.OutlineColor = Color3.fromRGB(235, 250, 255)
		h.OutlineTransparency = 0.15
		h.Adornee = target
		h.Parent = root()
		table.insert(made, h)
		glow = h
	end
	-- crackle: a short click at a random high pitch every 50-110 ms, positioned at the target
	local crackleOn = true
	if tBody then
		task.spawn(function()
			while crackleOn and tBody.Parent do
				local s = Instance.new("Sound")
				s.SoundId = "rbxasset://sounds/volume_slider.ogg"
				s.PlaybackSpeed = 2.4 + math.random() * 2.2
				s.Volume = 0.35 + math.random() * 0.25
				s.RollOffMaxDistance = 120
				s.Parent = tBody
				s:Play()
				task.delay(0.4, function()
					s:Destroy()
				end)
				task.wait(0.05 + math.random() * 0.06)
			end
		end)
	end
	local frame = 0
	local conn = RunService.RenderStepped:Connect(function()
		frame += 1
		if glow then
			glow.FillTransparency = 0.55 + math.random() * 0.35
		end
		if frame % 2 ~= 0 or not mainBolt or not tBody or not aPart or not tBody.Parent or not aPart.Parent then
			return
		end
		local a, b = aPart.Position, tBody.Position
		local amp = math.clamp((b - a).Magnitude * 0.06, 0.3, 1.1)
		local pts = jagPath(a, b, 8, amp)
		drawBolt(mainBolt, pts, 0)
		if branch then
			if math.random() < 0.7 then
				local from = pts[math.random(2, #pts - 1)]
				drawBolt(branch, jagPath(from, from + randUnit() * (1.2 + math.random() * 1.6), 4, 0.25), 0)
			else
				drawBolt(branch, {}, 1)
			end
		end
	end)
	return function()
		crackleOn = false
		conn:Disconnect()
		if mainBolt then
			destroyBolt(mainBolt)
		end
		if branch then
			destroyBolt(branch)
		end
		if stopCluster then
			stopCluster()
		end
		for _, inst in made do
			inst:Destroy()
		end
	end
end

-- Throw streak: a short trail on the thrown body (no blast).
function HackVfx.ThrowTrail(model: Model)
	local body = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not body then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.8, 0)
	a1.Parent = body
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.35
	tr.Color = ColorSequence.new(Color3.fromRGB(120, 230, 255))
	tr.Transparency = NumberSequence.new(0.3, 1)
	tr.LightEmission = 0.8
	tr.Parent = body
	task.delay(1.0, function()
		tr:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end



-- Rev 15m (owner: "the blue effect MUST last until landing"): FLING SELF wears a blue/cyan energy aura for
-- the WHOLE airborne journey: a cyan trail on the torso, crackling sparks and a soft light (+ a faint
-- flickering body glow). Its lifetime is the VISUAL flight, not the movement controller: it ends only on
-- HackVfx.SelfFlingEnd (the server relays the owner's real landing / cancel to everyone), when the
-- character dies or is removed, or after AURA_MAX_SECONDS as a safety net. A new FLING SELF replaces it.
-- Reduced Effects keeps only the trail. (Rev 15b-15l used the 1.0 s throw trail, which vanished
-- mid-air on longer flights: measured 1.25 s before landing on a 2.2 s high launch.)
local AURA_MAX_SECONDS = 10
local HUM_VOLUME = 0.32 -- Rev 15s flight hum: clearly audible locally, below hack / warning cues
local CYAN_ENERGY = Color3.fromRGB(70, 150, 255) -- Rev 15t (VFX-01): deeper electric blue (was 90,215,255 cyan)
local auras: { [Model]: (landed: boolean) -> () } = {}

function HackVfx.SelfFlingEnd(model: Model)
	local stop = auras[model]
	if stop then
		stop(true)
	end
end

function HackVfx.SelfFlingActive(model: Model): boolean
	return auras[model] ~= nil
end

local function selfFlingAura(model: Model)
	local prev = auras[model]
	if prev then
		prev(false)
	end
	local body = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not body then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local reduced = UITheme.reducedEffects()
	local a0 = Instance.new("Attachment")
	a0.Name = "SelfFlingAuraA"
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Name = "SelfFlingAuraB"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = body
	local tr = Instance.new("Trail")
	tr.Name = "SelfFlingAuraTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.42
	tr.Color = ColorSequence.new(Color3.fromRGB(225, 242, 255), CYAN_ENERGY) -- white-hot head fading to blue
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.LightEmission = 0.9
	tr.Parent = body
	local fx: { Instance } = { a0, a1, tr }
	local emitter: ParticleEmitter? = nil
	local light: PointLight? = nil
	local glow: Highlight? = nil
	if not reduced then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "SelfFlingAuraSparks"
		pe.Texture = SPARK_TEXTURE
		pe.Color = ColorSequence.new(Color3.fromRGB(200, 245, 255), CYAN_ENERGY)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.45, 0)
		pe.Transparency = NumberSequence.new(0.1, 1)
		pe.Lifetime = NumberRange.new(0.15, 0.32)
		pe.Rate = 26
		pe.Speed = NumberRange.new(2, 6)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = body
		emitter = pe
		local pl = Instance.new("PointLight")
		pl.Name = "SelfFlingAuraLight"
		pl.Color = CYAN_ENERGY
		pl.Range = 9
		pl.Brightness = 1.4
		pl.Parent = body
		light = pl
		local h = Instance.new("Highlight")
		h.Name = "SelfFlingAuraGlow"
		h.FillColor = CYAN_ENERGY
		h.FillTransparency = 0.82
		h.OutlineColor = Color3.fromRGB(200, 245, 255)
		h.OutlineTransparency = 0.45
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = model
		h.Parent = root()
		glow = h
		table.insert(fx, pe)
		table.insert(fx, pl)
		table.insert(fx, h)
	end
	-- Rev 15t (VFX-01): a lighter crackling lightning cluster rides with the body for the whole flight
	local stopLightning: (() -> ())? = if reduced then nil else lightningCluster(body, { arcs = 2, segs = 5, radius = 2.1, every = 3, light = 0, core = 0 })
	-- Rev 15s (owner: "The sound effect should last as long as the blue effect is present"): continuous
	-- flight audio owned by THIS aura (same start, same stop, same cleanup). No uploads: the built-in wind
	-- loop pitched up, chopped by a fast tremolo and EQ'd thin = a soft electric hum, plus an occasional very
	-- quiet crackle from ONE reused Sound at random intervals (never per frame). Spatial (heard by everyone
	-- near, attenuated with distance). Reduced Effects keeps the hum, drops the crackle.
	for _, old in body:GetChildren() do
		if old:IsA("Sound") and (old.Name == "SelfFlingHum" or old.Name == "SelfFlingCrackle") then
			old:Destroy() -- a relaunch replaces the previous flight's audio at once (never two loops)
		end
	end
	local humSound = Instance.new("Sound")
	humSound.Name = "SelfFlingHum"
	humSound.SoundId = "rbxasset://sounds/action_falling.ogg"
	humSound.Looped = true
	humSound.PlaybackSpeed = 2.2
	humSound.Volume = 0
	humSound.RollOffMode = Enum.RollOffMode.InverseTapered
	humSound.RollOffMinDistance = 10
	humSound.RollOffMaxDistance = 90
	local tremolo = Instance.new("TremoloSoundEffect")
	tremolo.Depth = 0.55
	tremolo.Frequency = 24
	tremolo.Duty = 0.5
	tremolo.Parent = humSound
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -12
	eq.MidGain = -2
	eq.HighGain = 3
	eq.Parent = humSound
	humSound.Parent = body
	humSound:Play()
	TweenService:Create(humSound, TweenInfo.new(0.15), { Volume = HUM_VOLUME }):Play()
	table.insert(fx, humSound)
	local crackle: Sound? = nil
	if not reduced then
		local cs = Instance.new("Sound")
		cs.Name = "SelfFlingCrackle"
		cs.SoundId = "rbxasset://sounds/volume_slider.ogg"
		cs.Volume = 0.12
		cs.RollOffMode = Enum.RollOffMode.InverseTapered
		cs.RollOffMinDistance = 8
		cs.RollOffMaxDistance = 60
		cs.Parent = body
		crackle = cs
		table.insert(fx, cs)
	end
	local nextCrackle = os.clock() + 0.2
	model:SetAttribute("SelfFlingAura", true)
	local t0 = os.clock()
	local frame = 0
	local conn: RBXScriptConnection? = nil
	local stopped = false
	local function stop(_landed: boolean)
		if stopped then
			return
		end
		stopped = true
		if auras[model] == stop then
			auras[model] = nil
		end
		if conn then
			conn:Disconnect()
		end
		if model.Parent then
			model:SetAttribute("SelfFlingAura", nil)
		end
		if stopLightning then
			stopLightning()
		end
		-- the hum fades out quickly (before the landing thud lands on top of it), then stops
		if humSound.Parent then
			TweenService:Create(humSound, TweenInfo.new(0.15), { Volume = 0 }):Play()
			task.delay(0.16, function()
				if humSound.Parent then
					humSound:Stop()
				end
			end)
		end
		tr.Enabled = false
		if emitter then
			emitter.Enabled = false
		end
		if light then
			TweenService:Create(light, TweenInfo.new(0.25), { Brightness = 0 }):Play()
		end
		if glow then
			TweenService:Create(glow, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		end
		task.delay(0.5, function()
			for _, i in fx do
				i:Destroy()
			end
		end)
	end
	auras[model] = stop
	conn = RunService.Heartbeat:Connect(function()
		if not model.Parent or not body.Parent or (hum and hum.Health <= 0) or os.clock() - t0 > AURA_MAX_SECONDS then
			stop(false) -- death / reset / removal / safety net: never a stuck aura
			return
		end
		frame += 1
		if glow and frame % 3 == 0 then
			glow.FillTransparency = 0.76 + math.random() * 0.14 -- faint electric flicker
		end
		-- the hum rises a little with speed (sense of motion); a sparse, quiet crackle
		local sp = body.AssemblyLinearVelocity.Magnitude
		humSound.PlaybackSpeed = 2.0 + math.clamp(sp / 220, 0, 0.45)
		local nowC = os.clock()
		if crackle and nowC >= nextCrackle then
			nextCrackle = nowC + 0.14 + math.random() * 0.24
			crackle.PlaybackSpeed = 2.6 + math.random() * 1.6
			crackle:Play()
		end
	end)
end

-- Rev 15b: FLING SELF launch, matched to the regular fling (owner: "resemble the regular fling more").
-- A short electric shock on the body (cyan glow flicker, crackle, sparks crawling over the limbs, ~0.35 s)
-- then (Rev 15m) the airborne energy aura until landing; no crater, no orange starburst, no camera shake.
-- Landing uses the regular fling's LandImpact (sent by the server when the owner reports a real landing).
function HackVfx.SelfFling(model: Model)
	selfFlingAura(model)
	local body = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	if not body then
		return
	end
	for i = 0, 4 do
		task.delay(i * 0.06, function()
			if not body.Parent then
				return
			end
			local s = Instance.new("Sound")
			s.SoundId = "rbxasset://sounds/volume_slider.ogg"
			s.PlaybackSpeed = 2.6 + math.random() * 1.8
			s.Volume = 0.4
			s.RollOffMaxDistance = 120
			s.Parent = body
			s:Play()
			task.delay(0.4, function()
				s:Destroy()
			end)
		end)
	end
	if UITheme.reducedEffects() then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(80, 220, 255)
	h.FillTransparency = 0.6
	h.OutlineColor = Color3.fromRGB(235, 250, 255)
	h.OutlineTransparency = 0.2
	h.Adornee = model
	h.Parent = root()
	-- Rev 15t (VFX-01): the launch shock is a dense, bright lightning burst around the body (was small
	-- spark sticks), fading over 0.45 s while the flight aura's lighter lightning takes over
	lightningCluster(body, { arcs = 5, segs = 6, radius = 2.6, every = 2, light = 2.4, core = 1.6, seconds = 0.45 })
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if os.clock() - t0 > 0.35 or not model.Parent then
			if conn then
				conn:Disconnect()
			end
			h:Destroy()
			return
		end
		h.FillTransparency = 0.5 + math.random() * 0.4
	end)
end
-- Rev 15: FLING TARGET landing impact (after the throw, seen by everyone). Grounded and physical, not
-- an explosion: a low dust ring, a few cyan residual-shock sparks and a 3D body thud at the landing
-- point. No camera shake, no explosion audio. Reduced Effects keeps only the thud.
function HackVfx.LandImpact(model: Model?, pos: Vector3, strength: number)
	local host = vpart("LandThudHost", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(), nil)
	host.Transparency = 1
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/action_jump_land.mp3"
	s.PlaybackSpeed = 0.62
	s.Volume = 0.6 + 0.6 * strength
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 140
	s.Parent = host
	s:Play()
	task.delay(2, function()
		host:Destroy()
	end)
	if UITheme.reducedEffects() then
		return
	end
	shockwave(pos, 5 + 5 * strength, 0.4, Color3.fromRGB(200, 196, 188))
	sparks(pos + Vector3.new(0, 0.6, 0), math.floor(5 + 7 * strength), 12, Color3.fromRGB(120, 230, 255))
	if model then
		model:SetAttribute("HackLandFx", (model:GetAttribute("HackLandFx") or 0) + 1)
	end
end
-- Rev 15q (owner: "slamming into a wall should stun"): a thrown body hit a wall. The wall impact (thud, dust
-- ring on the wall, cyan sparks) and dizzy stars circling over the target's head until it gets up
-- (`seconds`, from the server). Reduced Effects: the thud only.
function HackVfx.Slam(model: Model?, pos: Vector3, normal: Vector3, seconds: number, strength: number)
	local host = vpart("SlamThudHost", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(), nil)
	host.Transparency = 1
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/action_jump_land.mp3"
	s.PlaybackSpeed = 0.5
	s.Volume = 0.9 + 0.5 * strength
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 160
	s.Parent = host
	s:Play()
	task.delay(2, function()
		host:Destroy()
	end)
	if UITheme.reducedEffects() then
		return
	end
	-- a flat ring on the wall surface, facing out of it
	local ring = vpart("SlamRing", Vector3.new(0.2, 1, 1), CFrame.lookAt(pos + normal * 0.15, pos + normal * 2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(220, 214, 200), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	ring.Transparency = 0.35
	tween(ring, 0.35, { Size = Vector3.new(0.2, 7 + 4 * strength, 7 + 4 * strength), Transparency = 1 })
	task.delay(0.4, function()
		ring:Destroy()
	end)
	sparks(pos + normal * 0.5, math.floor(8 + 8 * strength), 16, Color3.fromRGB(120, 230, 255))
	if not model then
		return
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local stars: { Part } = {}
	for i = 1, 3 do
		local st = vpart("DizzyStar", Vector3.new(0.45, 0.45, 0.45), head.CFrame, Color3.fromRGB(255, 220, 70), Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(stars, st)
	end
	model:SetAttribute("HackDizzy", true)
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if el > seconds or not head.Parent or not model.Parent then
			if conn then
				conn:Disconnect()
			end
			for _, st in stars do
				st:Destroy()
			end
			if model.Parent then
				model:SetAttribute("HackDizzy", nil)
			end
			return
		end
		for i, st in stars do
			local a = el * 5 + i * (2 * math.pi / 3)
			st.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.3, 1.3 + 0.15 * math.sin(el * 7 + i), math.sin(a) * 1.3))
		end
	end)
end

-- Deflection burst on the defender (seen by everyone); perfect = bigger, whiter, longer.
function HackVfx.Deflect(target: Model, perfect: boolean)
	local tRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tRoot or UITheme.reducedEffects() then
		return
	end
	local col = if perfect then Color3.fromRGB(245, 247, 255) else Color3.fromRGB(60, 220, 140)
	local s = if perfect then 1.6 else 1
	local orb = vpart("DeflectOrb", Vector3.new(6, 6, 6) * s, tRoot.CFrame, col, Enum.Material.ForceField, Enum.PartType.Ball)
	orb.Transparency = 0.1
	tween(orb, 0.3, { Size = Vector3.new(14, 14, 14) * s, Transparency = 1 })
	task.delay(0.35, function()
		orb:Destroy()
	end)
	shockwave(tRoot.Position - Vector3.new(0, 2.8, 0), 10 * s, 0.35, col)
	sparks(tRoot.Position, if perfect then 40 else 20, 35, col)
	if perfect then
		starburst(tRoot.Position, 0.8)
	end
end

local started = false
function HackVfx.Start()
	if started then
		return
	end
	started = true
	-- Camera shake + FOV kick (applied after the default camera each frame).
	local baseFov: number? = nil
	RunService:BindToRenderStep("WristHackCameraKick", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local t = os.clock()
		if t < shakeUntil then
			local k = shakeAmp * math.clamp((shakeUntil - t) / 0.35, 0, 1)
			cam.CFrame = cam.CFrame * CFrame.new(math.random(-100, 100) / 100 * k, math.random(-100, 100) / 100 * k, 0)
		else
			shakeAmp = 0
		end
		if t < fovKickUntil then
			baseFov = baseFov or cam.FieldOfView
			local f = (fovKickUntil - t) / 0.6
			cam.FieldOfView = (baseFov :: number) + 14 * math.sin(f * math.pi * 0.5)
		elseif baseFov then
			cam.FieldOfView = baseFov
			baseFov = nil
		end
	end)
end

return HackVfx
