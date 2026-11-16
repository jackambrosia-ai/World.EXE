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

-- Incoming targeted hack (seen by everyone): the impact ring on the ground (the explicit dodge zone),
-- a faint pulsing tether from the attacker, and an overhead warning. Returns a cleanup function.
local HACK_COLOR: { [string]: Color3 } = { FREEZE = Color3.fromRGB(175, 230, 255), FLING_TARGET = Color3.fromRGB(255, 140, 30) }
local HACK_WORD: { [string]: string } = { FREEZE = "FREEZE", FLING_TARGET = "FLING" }
function HackVfx.Incoming(attacker: Model?, target: Model, center: Vector3, radius: number, startAt: number, resolveAt: number, hackId: string): () -> ()
	local made: { Instance } = {}
	local col = HACK_COLOR[hackId] or Color3.fromRGB(255, 111, 97)
	local floor = floorBelow(center, { target, root() })
	-- faint fill (no Neon: bloom turned the first version into an opaque dome) + a thin segmented edge
	local ring = vpart("ImpactRing", Vector3.new(0.1, radius * 2, radius * 2), CFrame.new(floor + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), col, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	ring.Transparency = 0.88
	table.insert(made, ring)
	local SEG = 28
	local segLen = 2 * math.pi * radius / SEG * 0.62 -- dashed edge
	for i = 1, SEG do
		local a = (i / SEG) * 2 * math.pi
		local p = floor + Vector3.new(math.cos(a) * radius, 0.12, math.sin(a) * radius)
		local seg = vpart("ImpactEdge", Vector3.new(segLen, 0.12, 0.35), CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), col, Enum.Material.Neon)
		seg.Transparency = 0.25
		table.insert(made, seg)
	end
	-- faint tether (presentation only; the rules are the ring, cover and shield)
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
		ring.Transparency = 0.82 + 0.1 * math.abs(math.sin(os.clock() * 8))
	end)
	return function()
		conn:Disconnect()
		for _, i in made do
			i:Destroy()
		end
	end
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
