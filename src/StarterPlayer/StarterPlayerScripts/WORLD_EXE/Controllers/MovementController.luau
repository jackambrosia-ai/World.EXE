--!strict
-- MovementController (wrist-hacking prototype, client) — Rev 15 (owner-authorized), updated through Rev 15m.
-- Executes what MovementService decides (the server owns timing, the skill check, charges and cooldowns;
-- this client owns its character's physics), and draws the speed feedback.
--
-- Controls (current, Rev 15j-15m owner design): Q = grounded dash + a skill check (a marker sweeps a bar;
-- Q inside the random zone fills one of two diamond containers); Q while the dash is cooling (6 s) spends a
-- diamond on ~1 s steerable super-speed; Q DURING a super-speed chains the next one (Rev 15l, diamond left,
-- >= 0.25 s apart). The sweep is drawn on the server's clock (Rev 15m). The old Q-Q timing window is gone.
-- Reference mapping (private, SHA-256-verified owner videos; original WORLD.EXE interpretations):
--   MOV-03 fast baseline run  -> Humanoid.WalkSpeed raised server-side; subtle foot streaks, sparse foot
--                                dust and a +3 degree FOV only when actually running fast (wall-run: WallRun).
--   MOV-04 grounded dash      -> Q: horizontal-only burst in the WASD (camera-relative) direction, dust puffs.
--   MOV-02 / MOV-05 super-speed -> steerable ~1 s burst, lightweight R6 silhouette afterimages (Rev 15m;
--                                cyan/green/violet),
--                                screen tint, wind loop, drain gauge.
--   MOV-01 abrupt activation, fading afterimages, quick return to normal -> instant start cue and an eased
--                                return to the run speed at the end.
-- Performance: afterimages and dust come from fixed pools (no per-frame Instance creation); trails
-- are created once per character and only toggled. Reduced Effects removes afterimages, dust,
-- trails and FOV changes; sounds and the gauge stay.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local sharedRoot = ReplicatedStorage:WaitForChild("WORLD_EXE")
local HackCatalog = require(sharedRoot:WaitForChild("Shared"):WaitForChild("HackCatalog"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIUtil = require(script.Parent:WaitForChild("UIUtil"))
local MoveState = require(script.Parent:WaitForChild("MoveState"))
local WallRun = require(script.Parent:WaitForChild("WallRun"))
local C = UITheme.Color

local Q_ACTION = "WORLD_EXE_MoveQ"
local CYAN = Color3.fromRGB(110, 225, 255)
local VIOLET = Color3.fromRGB(150, 110, 255)
local NEON_GREEN = Color3.fromRGB(110, 255, 150)
local SUPER_STOPS = { CYAN, NEON_GREEN, VIOLET } -- super-speed afterimage / screen tint cycle (owner: "mix of all")

local MovementController = {}

local function flat(v: Vector3): Vector3?
	local h = Vector3.new(v.X, 0, v.Z)
	return if h.Magnitude > 0.05 then h.Unit else nil
end

local function tune(key: string): number
	return HackCatalog.Tune("Move", key)
end

local function sfx(id: string, speed: number, volume: number, parent: Instance?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Parent = parent or SoundService
	s:Play()
	task.delay(3, function()
		s:Destroy()
	end)
end

-------------------------------------------------------------------------------------------------
-- Pools (afterimage ghost parts and dust puffs)
local fxFolder = Instance.new("Folder")
fxFolder.Name = "WORLD_EXE_MoveFx"

local function poolPart(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 1
	p.Parent = fxFolder
	return p
end

-- Rev 15m (owner decision): super-speed afterimages are LIGHTWEIGHT R6 SILHOUETTES, not copies of the
-- avatar. Each ghost is 6 plain anchored Neon parts (head, torso, two arms, two legs) sized from the
-- runner's own R6 limbs and posed from their CFrames at the moment it is dropped, so the chain reads as the
-- runner's recent positions while the real character (clothes, hair, wrist device) stays distinct.
-- No Humanoid, no clothing / accessories / decals / wrist device, no animation, no collision or queries.
-- Colours: the chain cycles cyan -> green -> violet (owner "mix of all"); Workspace attribute
-- WORLD_EXE_SuperTint (Color3) overrides. Pooled per character (built once, moved with BulkMoveTo).
-- History: Rev 15e-15l used full-detail clones of the avatar (16 x ~100 instances per character incl. a
-- Humanoid each, a one-time 25.9 ms build hitch; measured in Studio 2026-11-17).
local GHOST_POOL = 14
local GHOST_LIFE = 0.55
local GHOST_EVERY = 0.045
local GHOST_ALPHA = 0.42 -- starting transparency (slightly see-through), fading smoothly to 1
local R6_LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local R15_FALLBACK = { Head = "Head", Torso = "UpperTorso", ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm", ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg" }
type Ghost = { parts: { BasePart }, born: number }
type GhostSet = { ghosts: { Ghost }, nextI: number, sources: { BasePart? } }
local ghostSets: { [Model]: GhostSet } = {}
local activeGhosts: { Ghost } = {}
local stats = { ghosts = 0, dust = 0, fxMs = 0, fxFrames = 0, fxMax = 0 } -- fx*: afterimage CPU cost per frame (Studio perf evidence)
local DUST_POOL = 24
local dustParts: { Part } = {}
local dustNext = 1

local function limbSource(live: Model, name: string): BasePart?
	local p = live:FindFirstChild(name) or live:FindFirstChild(R15_FALLBACK[name] or "")
	return if p and p:IsA("BasePart") then p else nil
end

local function buildGhosts(live: Model): GhostSet
	local sources: { BasePart? } = {}
	for i, name in R6_LIMBS do
		sources[i] = limbSource(live, name)
	end
	local set: GhostSet = { ghosts = {}, nextI = 1, sources = sources }
	for _ = 1, GHOST_POOL do
		local parts = {}
		for i, name in R6_LIMBS do
			local src = sources[i]
			local gp = Instance.new("Part")
			gp.Name = "Ghost" .. name:gsub(" ", "")
			gp.Anchored = true
			gp.CanCollide = false
			gp.CanQuery = false
			gp.CanTouch = false
			gp.CastShadow = false
			gp.Massless = true
			gp.CollisionGroup = "WORLD_EXE_Afterimage"
			gp.Material = Enum.Material.Neon
			gp.Transparency = 1
			if name == "Head" then
				gp.Shape = Enum.PartType.Ball
				gp.Size = Vector3.new(1.25, 1.25, 1.25)
			else
				gp.Size = if src then src.Size else Vector3.new(1, 2, 1)
			end
			gp.Parent = fxFolder
			parts[i] = gp
		end
		table.insert(set.ghosts, { parts = parts, born = -1 })
	end
	ghostSets[live] = set
	live.AncestryChanged:Connect(function(_, parent)
		if not parent then
			for _, g in set.ghosts do
				for _, gp in g.parts do
					gp:Destroy()
				end
			end
			ghostSets[live] = nil
		end
	end)
	return set
end

local moveParts: { BasePart } = {}
local moveCFrames: { CFrame } = {}
local function spawnAfterimage(live: Model, tint: Color3)
	local set = ghostSets[live] or buildGhosts(live)
	local root = live:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local g = set.ghosts[set.nextI]
	set.nextI = set.nextI % #set.ghosts + 1
	table.clear(moveParts)
	table.clear(moveCFrames)
	for i, gp in g.parts do
		local src = set.sources[i]
		local cf = if src and src.Parent then src.CFrame else root.CFrame * CFrame.new(0, (i == 1 and 1.5 or 0), 0)
		table.insert(moveParts, gp)
		table.insert(moveCFrames, cf)
		gp.Color = tint
		gp.Transparency = GHOST_ALPHA
	end
	workspace:BulkMoveTo(moveParts, moveCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	g.born = os.clock()
	if not table.find(activeGhosts, g) then
		table.insert(activeGhosts, g)
	end
	stats.ghosts += 1
end

-- smooth fade from slightly see-through to gone
local function updateAfterimages(now: number)
	for i = #activeGhosts, 1, -1 do
		local g = activeGhosts[i]
		local f = (now - g.born) / GHOST_LIFE
		if f >= 1 or not g.parts[1].Parent then
			for _, gp in g.parts do
				gp.Transparency = 1
			end
			table.remove(activeGhosts, i)
		else
			local e = f * f * (3 - 2 * f)
			local a = GHOST_ALPHA + (1 - GHOST_ALPHA) * e
			for _, gp in g.parts do
				gp.Transparency = a
			end
		end
	end
end

local function superTint(progress: number): Color3
	local o = workspace:GetAttribute("WORLD_EXE_SuperTint")
	if typeof(o) == "Color3" then
		return o
	end
	-- owner 2026-11-16 ("mix of all"): the chain cycles cyan -> green -> violet -> cyan, 1.5 cycles per
	-- burst, so neighbouring copies differ and every colour shows; the screen grade follows it
	local stops = SUPER_STOPS
	local x = (math.clamp(progress, 0, 1) * 1.5 % 1) * #stops
	local i = math.floor(x)
	return stops[i + 1]:Lerp(stops[(i + 1) % #stops + 1], x - i)
end

local function spawnDust(at: Vector3, big: boolean)
	local p = dustParts[dustNext]
	dustNext = dustNext % DUST_POOL + 1
	local s = if big then 1.6 else 0.9
	p.Size = Vector3.new(s, s, s)
	p.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0))
	p.Color = Color3.fromRGB(205, 205, 220)
	p.Transparency = 0.55
	TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = Vector3.new(s * 2.2, s * 2.2, s * 2.2) }):Play()
	stats.dust += 1
end

-- Per-character foot streaks: created once, toggled (never re-created per frame)
type Fx = { trails: { Trail }, lastDust: number, lastGhost: number }
local fxByChar: { [Model]: Fx } = {}

local function fxFor(character: Model): Fx?
	local f = fxByChar[character]
	if f then
		return f
	end
	local trails = {}
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local a0 = Instance.new("Attachment")
			a0.Name = "SpeedStreakA"
			a0.Position = Vector3.new(0, -foot.Size.Y / 2 + 0.15, 0.25)
			a0.Parent = foot
			local a1 = Instance.new("Attachment")
			a1.Name = "SpeedStreakB"
			a1.Position = Vector3.new(0, -foot.Size.Y / 2 + 0.45, 0.25)
			a1.Parent = foot
			local tr = Instance.new("Trail")
			tr.Name = "SpeedStreak"
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = 0.12
			tr.LightEmission = 0.7
			tr.Transparency = NumberSequence.new(0.55, 1)
			tr.Color = ColorSequence.new(CYAN)
			tr.Enabled = false
			tr.Parent = foot
			table.insert(trails, tr)
		end
	end
	f = { trails = trails, lastDust = 0, lastGhost = 0 }
	fxByChar[character] = f
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			fxByChar[character] = nil
		end
	end)
	return f
end

-------------------------------------------------------------------------------------------------
function MovementController.Start()
	local player = Players.LocalPlayer
	local remotes = sharedRoot:WaitForChild(HackCatalog.RemoteFolder, 30)
	if not remotes then
		return
	end
	local request = remotes:WaitForChild(HackCatalog.RequestRemote) :: RemoteEvent
	local event = remotes:WaitForChild(HackCatalog.EventRemote) :: RemoteEvent
	fxFolder.Parent = workspace
	for _ = 1, DUST_POOL do
		local d = poolPart("SpeedDust")
		d.Shape = Enum.PartType.Ball
		table.insert(dustParts, d)
	end

	-- small gauge (bottom centre, above the HUD): dash window, super drain, super cooldown
	local gui, root = UIUtil.screen("WORLD_EXE_MoveGauge", 6)
	gui.ResetOnSpawn = false
	local gauge = UIUtil.create("Frame", { Name = "Gauge", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -118), Size = UDim2.fromOffset(150, 6), BackgroundColor3 = C.Charcoal, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false }, root) :: Frame
	UIUtil.corner(gauge, 3)
	local windowSeg = UIUtil.create("Frame", { Name = "Window", BackgroundColor3 = CYAN, BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, gauge) :: Frame
	local fill = UIUtil.create("Frame", { Name = "Fill", BackgroundColor3 = VIOLET, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, gauge) :: Frame
	UIUtil.corner(fill, 3)
	local marker = UIUtil.create("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(3, 12), BackgroundColor3 = C.Text, BorderSizePixel = 0, Visible = false }, gauge) :: Frame
	local label = UIUtil.text("Label", gauge, "", 11, C.Muted, UITheme.Font.Label, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2) })
	-- Rev 15b: dash cooldown (half the super-speed cooldown) as a thin cyan bar under the gauge
	local dashBar = UIUtil.create("Frame", { Name = "DashBar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(150, 3), BackgroundColor3 = C.Charcoal, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false }, root) :: Frame
	UIUtil.corner(dashBar, 2)
	local dashFill = UIUtil.create("Frame", { Name = "Fill", BackgroundColor3 = CYAN, BackgroundTransparency = 0.2, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, dashBar) :: Frame
	UIUtil.corner(dashFill, 2)
	local dashReadyAt = 0 -- server time
	-- Rev 15j (owner): two empty DIAMOND containers at the bottom middle; each skill-check hit fills one.
	-- Q while the dash is cooling spends a filled diamond on super-speed.
	local chargeRow = UIUtil.create("Frame", { Name = "SuperCharges", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -136), Size = UDim2.fromOffset(64, 26), BackgroundTransparency = 1 }, root) :: Frame
	local diamonds: { { box: Frame, fill: Frame, stroke: UIStroke, scale: UIScale } } = {}
	for i = 1, 2 do
		local box = UIUtil.create("Frame", { Name = "Diamond" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 1.5) * 30, 0.5, 0), Size = UDim2.fromOffset(17, 17), Rotation = 45, BackgroundColor3 = C.Charcoal, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, chargeRow) :: Frame
		local stroke = UIUtil.stroke(box, CYAN, 2)
		local fillD = UIUtil.create("Frame", { Name = "Fill", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundColor3 = VIOLET, BorderSizePixel = 0, Visible = false }, box) :: Frame
		local scale = Instance.new("UIScale")
		scale.Parent = box
		table.insert(diamonds, { box = box, fill = fillD, stroke = stroke, scale = scale })
	end
	local charges = 0
	local function renderCharges(pulse: number?)
		for i, d in diamonds do
			d.fill.Visible = i <= charges
			d.stroke.Color = if i <= charges then VIOLET else CYAN
		end
		if pulse and diamonds[pulse] and not UITheme.reducedEffects() then
			local d = diamonds[pulse]
			d.scale.Scale = 1.6
			TweenService:Create(d.scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		gui:SetAttribute("SuperCharges", charges)
	end
	renderCharges()

	local n = 0
	local dashAt = -1 -- os.clock() of the last executed dash (for the window display only)
	-- skill check of the last dash (client display; the server judges)
	local checkStart, checkSweep, zoneA, zoneB = -1, 0.75, 0, 0
	local checkResult, checkResultAt = "", -1
	local superEnd = -1 -- os.clock()
	-- Rev 15g: wall-running (its own module; feedback hooks here)
	WallRun.Start({
		ignore = { fxFolder },
		onStart = function()
			sfx("rbxasset://sounds/action_footsteps_plastic.mp3", 1.6, 0.4)
			gui:SetAttribute("LastMove", "wallrun")
		end,
		onStep = function(footPos: Vector3)
			if not UITheme.reducedEffects() then
				spawnDust(footPos, false)
			end
		end,
		onEnd = function(how: string)
			if how == "jump" then
				sfx("rbxasset://sounds/action_jump.mp3", 1.3, 0.4)
			end
			gui:SetAttribute("LastWallRunEnd", how)
		end,
	})
	local superLen = 1
	local wind: Sound? = nil
	local baseFov: number? = nil
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "WORLD_EXE_SuperGrade"
	grade.Enabled = false
	grade.Parent = game:GetService("Lighting")
	local gradeK = 0

	ContextActionService:BindActionAtPriority(Q_ACTION, function(_, st: Enum.UserInputState)
		if st == Enum.UserInputState.Begin then
			n += 1 -- one packet per DISTINCT press (key repeat / holding never sends more)
			request:FireServer({ op = "q", n = n })
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.ButtonX) -- above the main-game PHASE_DASH binding (prototype only), sunk

	local active: { kind: string, conn: RBXScriptConnection, parts: { Instance }, sp: number, dir: Vector3 }? = nil
	local function stop(kind: string?)
		local a = active
		if not a or (kind and a.kind ~= kind) then
			return
		end
		active = nil
		a.conn:Disconnect()
		for _, i in a.parts do
			i:Destroy()
		end
		MoveState.Release(a.kind)
		if a.kind == "super" and wind then
			wind:Stop()
		end
	end

	local function drive(kind: string, seconds: number, speed: number, turn: number?)
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not c or not hrp or not hum or hum.Health <= 0 then
			return
		end
		local owner = MoveState.Owner()
		if owner == "flingSelf" then
			return -- FLING SELF owns the velocity right now
		end
		-- Rev 15l: a chained super carries on from the previous burst's COMMANDED speed and heading (reading the
		-- velocity after the constraint is gone, or mid ease-out, made a visible dip at the hand-over)
		local prev = active
		local carrySp = if prev and turn and prev.kind == kind then prev.sp else 0
		local carryDir = if prev and turn and prev.kind == kind then prev.dir else nil
		stop() -- release our previous drive BEFORE claiming (a super -> super follow-up keeps ownership)
		if not MoveState.Claim(kind, owner == "dash" or owner == "wallrun" or owner == "walljump" or owner == kind) then
			return
		end
		-- Rev 15g smoother: start from the current motion (follow-up bursts and fast runs carry straight on)
		local v0 = hrp.AssemblyLinearVelocity
		local hs0 = Vector3.new(v0.X, 0, v0.Z).Magnitude
		hs0 = math.max(hs0, carrySp)
		local dir = carryDir or (if turn and hs0 > 20 then flat(v0) else nil) or flat(hum.MoveDirection) or flat(hrp.CFrame.LookVector) or Vector3.zAxis
		local att = Instance.new("Attachment")
		att.Name = "MoveDriveAttachment"
		att.Parent = hrp
		local lv = Instance.new("LinearVelocity")
		lv.Name = "MoveDrive"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane -- horizontal only: Y stays physical
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		lv.MaxForce = hrp.AssemblyMass * 3000
		lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * (if turn then math.max(hs0, tune("RunSpeed")) else speed)
		lv.Parent = hrp
		local t0 = os.clock()
		local run = tune("RunSpeed")
		local startSpeed = math.max(hs0, run)
		local accel = if turn and startSpeed < speed * 0.9 then tune("SuperAccelSeconds") else 0
		local easeOut = if turn then tune("SuperEaseOutSeconds") else 0.15
		local steerK = tune("SuperSteerSmoothing")
		local function smooth(x: number): number
			x = math.clamp(x, 0, 1)
			return x * x * (3 - 2 * x)
		end
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not hrp.Parent or hum.Health <= 0 then
				stop(kind)
				return
			end
			if MoveState.Owner() ~= kind then
				stop(kind) -- Rev 15m: another state took the velocity (a dash handed over to a wall run)
				return
			end
			local el = os.clock() - t0
			if turn then -- super-speed: full steering toward the held direction
				local want = flat(hum.MoveDirection)
				if want then
					local d = dir :: Vector3
					local ang = math.acos(math.clamp(d:Dot(want), -1, 1))
					if ang > 1e-3 then
						-- Rev 15g smoother: exponential approach, capped by the turn rate (no snapping)
						local step = math.min(ang * (1 - math.exp(-steerK * dt)), turn * dt)
						local cross = d:Cross(want).Y
						local a = if cross >= 0 then step else -step -- CFrame.Angles(0, +a) turns -Z toward -X; cross.Y = d.z*w.x - d.x*w.z
						dir = (CFrame.Angles(0, a, 0) * d).Unit
					end
				end
			end
			-- Rev 15g smoother: eased ramp-in from the current speed, eased return to run speed at the end
			local sp = speed
			if accel > 0 and el < accel then
				sp = startSpeed + (speed - startSpeed) * smooth(el / accel)
			end
			local remaining = seconds - el
			if remaining < easeOut then
				sp = run + (sp - run) * smooth(remaining / math.max(0.01, easeOut))
			end
			lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * sp
			local a = active
			if a and a.kind == kind then
				a.sp, a.dir = sp, dir
			end
			if el >= seconds then
				stop(kind)
			end
		end)
		active = { kind = kind, conn = conn, parts = { att, lv }, sp = startSpeed, dir = dir :: Vector3 }
	end

	event.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		local op = data.op
		if op == "dash" then
			dashAt = os.clock()
			dashReadyAt = tonumber(data.dashReady) or 0
			local ck = data.check
			if typeof(ck) == "table" then
				checkStart = dashAt + (tonumber(ck.delay) or 0.1)
				local startAt = tonumber(ck.startAt)
				if startAt then
					-- Rev 15m: draw the sweep on the SERVER's clock (the judge's). Starting it when this event
					-- arrived drew the marker ~83 ms behind the judgement (measured in Studio): presses that
					-- looked inside the zone were judged late. The server still judges; only the drawing moved.
					checkStart = dashAt + (startAt - workspace:GetServerTimeNow())
				end
				checkSweep = tonumber(ck.sweep) or 0.75
				zoneA = tonumber(ck.zoneA) or 0.3
				zoneB = tonumber(ck.zoneB) or 0.4
				checkResult = ""
			end
			charges = tonumber(data.charges) or charges
			renderCharges()
			drive("dash", tonumber(data.seconds) or 0.24, tonumber(data.speed) or 115, nil)
			sfx("rbxasset://sounds/action_jump.mp3", 1.75, 0.35)
			local c = player.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp and not UITheme.reducedEffects() then
				for i = 0, 2 do
					task.delay(i * 0.05, function()
						if hrp.Parent then
							spawnDust(hrp.Position - Vector3.new(0, 2.8, 0), true)
						end
					end)
				end
			end
			gui:SetAttribute("LastMove", "dash")
		elseif op == "super" then
			superLen = tonumber(data.seconds) or 1
			superEnd = os.clock() + superLen
			charges = tonumber(data.charges) or charges
			renderCharges()
			dashAt = -1
			checkStart = -1
			drive("super", superLen, tonumber(data.speed) or 74, tonumber(data.turn) or 10)
			if data.chained then
				sfx("rbxasset://sounds/volume_slider.ogg", 2.2, 0.45) -- chained burst: lighter cue, no thump
			else
				sfx("rbxasset://sounds/action_jump.mp3", 0.85, 0.45)
				sfx("rbxasset://sounds/volume_slider.ogg", 2.6, 0.5)
			end
			if not wind then
				local w = Instance.new("Sound")
				w.SoundId = "rbxasset://sounds/action_falling.ogg"
				w.Looped = true
				w.PlaybackSpeed = 1.35
				w.Volume = 0.5
				w.Parent = SoundService
				wind = w
			end
			(wind :: Sound):Play()
			local myEnd = superEnd
			task.delay(superLen, function()
				if superEnd ~= myEnd then
					return -- a newer burst started: keep the wind going
				end
				if wind then
					wind:Stop()
				end
				sfx("rbxasset://sounds/action_jump_land.mp3", 1.5, 0.3)
			end)
			gui:SetAttribute("LastMove", "super")
		elseif op == "move_fx" then
			if data.kind == "check_hit" then
				local before = charges
				charges = tonumber(data.charges) or charges
				checkResult, checkResultAt = "hit", os.clock()
				sfx("rbxasset://sounds/volume_slider.ogg", 2.4, 0.6)
				sfx("rbxasset://sounds/volume_slider.ogg", 3.1, 0.5)
				renderCharges(if charges > before then charges else nil)
			elseif data.kind == "check_miss" then
				checkResult, checkResultAt = "miss", os.clock()
				sfx("rbxasset://sounds/volume_slider.ogg", 0.55, 0.45)
			elseif data.kind == "no_charge" then
				sfx("rbxasset://sounds/volume_slider.ogg", 0.6, 0.25) -- soft tick: no diamond to spend
				dashReadyAt = tonumber(data.readyAt) or dashReadyAt
				if not UITheme.reducedEffects() then
					task.spawn(function()
						for _, dx in { -4, 4, -2, 2, 0 } do
							chargeRow.Position = UDim2.new(0.5, dx, 1, -136)
							task.wait(0.03)
						end
					end)
				end
			end
			gui:SetAttribute("LastMove", tostring(data.kind))
		elseif op == "ragdoll" or op == "frozen" then
			if data.on then
				stop()
			end
		elseif op == "fling_self" then
			stop() -- FLING SELF takes over the velocity
		end
	end)

	player.CharacterAdded:Connect(function()
		stop()
		MoveState.Release("dash")
		MoveState.Release("super")
		dashAt = -1
		superEnd = -1
	end)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local st = workspace:GetServerTimeNow()
		local reduced = UITheme.reducedEffects()
		-- gauge
		local superOn = superEnd > now
		-- skill check: shown from the dash until the sweep ends (plus a short result flash)
		local checkOn = checkStart > 0 and now <= checkStart + checkSweep + 0.35 and (checkResult == "" or now - checkResultAt < 0.35)
		gauge.Visible = superOn or checkOn
		if superOn then
			windowSeg.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = VIOLET
			fill.Size = UDim2.fromScale(math.clamp((superEnd - now) / superLen, 0, 1), 1)
			marker.Visible = false
			label.Text = "SUPER"
			label.TextColor3 = C.Muted
		elseif checkOn then
			windowSeg.Position = UDim2.fromScale(zoneA / checkSweep, 0)
			windowSeg.Size = UDim2.fromScale((zoneB - zoneA) / checkSweep, 1)
			windowSeg.BackgroundTransparency = 0.15
			windowSeg.BackgroundColor3 = if checkResult == "hit" then NEON_GREEN elseif checkResult == "miss" then C.Coral else CYAN
			fill.Size = UDim2.fromScale(0, 1)
			marker.Visible = true
			if checkResult == "" then
				marker.Position = UDim2.fromScale(math.clamp((now - checkStart) / checkSweep, 0, 1), 0.5)
			end
			label.Text = if checkResult == "hit" then "◆ +1" elseif checkResult == "miss" then "MISS" else "Q"
			label.TextColor3 = if checkResult == "hit" then NEON_GREEN elseif checkResult == "miss" then C.Coral else C.Text
		end
		local dashCd = tune("DashCooldown")
		dashBar.Visible = dashReadyAt > st
		if dashBar.Visible then
			dashFill.Size = UDim2.fromScale(1 - math.clamp((dashReadyAt - st) / math.max(0.1, dashCd), 0, 1), 1)
		end
		gui:SetAttribute("MoveOwner", MoveState.Owner())
		local fxT0 = os.clock()
		updateAfterimages(now)
		local fxMs = (os.clock() - fxT0) * 1000
		-- screen grade while I am in super-speed (local only; Reduced Effects: none)
		gradeK += ((if superOn and not reduced then 1 else 0) - gradeK) * math.clamp(dt * (if superOn then 14 else 5), 0, 1)
		grade.Enabled = gradeK > 0.01
		if grade.Enabled then
			local tint = superTint(if superOn then 1 - math.clamp((superEnd - now) / superLen, 0, 1) else 1)
			grade.TintColor = Color3.new(1, 1, 1):Lerp(tint, 0.38 * gradeK)
			grade.Saturation = -0.3 * gradeK
			grade.Contrast = 0.18 * gradeK
		end
		-- FOV (local camera only)
		local cam = workspace.CurrentCamera
		local myC = player.Character
		local myRoot = myC and myC:FindFirstChild("HumanoidRootPart") :: BasePart?
		if cam then
			baseFov = baseFov or cam.FieldOfView
			local target = baseFov :: number
			if myRoot and not reduced then
				local v = myRoot.AssemblyLinearVelocity
				local hs = Vector3.new(v.X, 0, v.Z).Magnitude
				target += tune("FovRun") * math.clamp((hs - 16) / math.max(1, tune("RunSpeed") - 16), 0, 1)
				if superOn then
					target += tune("FovSuper")
				end
			end
			cam.FieldOfView += (target - cam.FieldOfView) * math.clamp(dt * 6, 0, 1)
		end
		-- per-character speed feedback (everyone in range, so others' super-speed reads too)
		for _, pl in Players:GetPlayers() do
			local c = pl.Character
			local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if c and hrp and hum and (not myRoot or (hrp.Position - myRoot.Position).Magnitude < 160) then
				local f = fxFor(c)
				if f then
					local v = hrp.AssemblyLinearVelocity
					local hs = Vector3.new(v.X, 0, v.Z).Magnitude
					local su = c:GetAttribute("WORLD_EXE_SuperUntil")
					local du = c:GetAttribute("WORLD_EXE_DashUntil")
					local isSuper = typeof(su) == "number" and su > st
					local isDash = typeof(du) == "number" and du + 0.1 > st
					local grounded = hum.FloorMaterial ~= Enum.Material.Air
					for _, tr in f.trails do
						tr.Enabled = not reduced and (isSuper or isDash or (grounded and hs > 22) or c:GetAttribute("WORLD_EXE_WallRunning") == true)
						tr.Color = ColorSequence.new(if isSuper then VIOLET else CYAN)
						tr.Lifetime = if isSuper then 0.28 elseif isDash then 0.2 else 0.12
					end
					if not reduced then
						if isSuper and now - f.lastGhost >= GHOST_EVERY then
							f.lastGhost = now
							local remaining = math.clamp(((su :: number) - st) / math.max(0.1, tune("SuperSeconds")), 0, 1)
							local sT0 = os.clock()
							spawnAfterimage(c, superTint(1 - remaining))
							fxMs += (os.clock() - sT0) * 1000
						end
						local dustEvery = if isSuper then 0.08 elseif grounded and hs > 24 then 0.33 else math.huge
						if grounded and now - f.lastDust >= dustEvery then
							f.lastDust = now
							spawnDust(hrp.Position - Vector3.new(0, 2.8, 0), isSuper)
						end
					end
				end
			end
		end
		if #activeGhosts > 0 then
			stats.fxMs += fxMs
			stats.fxFrames += 1
			stats.fxMax = math.max(stats.fxMax, fxMs)
		end
		gui:SetAttribute("FxCounts", string.format("ghosts %d dust %d", stats.ghosts, stats.dust))
		gui:SetAttribute("FxCost", string.format("%.3f %d %.3f %d", stats.fxMs, stats.fxFrames, stats.fxMax, #activeGhosts))
	end)
end

return MovementController
