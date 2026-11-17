--!strict
-- MovementController (wrist-hacking prototype, client) — Rev 15, owner-authorized 2026-11-16.
-- Executes what MovementService decides (the server owns timing and cooldowns; this client owns its
-- character's physics), and draws the speed feedback.
--
-- Reference mapping (private, SHA-256-verified owner videos; original WORLD.EXE interpretations):
--   MOV-03 fast baseline run  -> Humanoid.WalkSpeed raised server-side; subtle foot streaks, sparse
--                                foot dust and a +3° FOV only when actually running fast.
--   MOV-04 grounded dash      -> first Q: ~0.17 s horizontal-only burst in the WASD (camera-relative)
--                                direction, short dust puffs at the feet; vertical position untouched.
--   MOV-02 steerable ~1 s burst, translucent blue-violet afterimage chain, dust, speed lines, drain
--                                gauge -> second Q: super-speed with full steering (turn rate 14 rad/s),
--                                pooled violet afterimages, violet streaks, wind loop, small gauge.
--   MOV-01 abrupt activation, streak look, fading afterimages, quick return to normal -> instant start
--                                cue and a short ease back to the run speed at the end.
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
local C = UITheme.Color

local Q_ACTION = "WORLD_EXE_MoveQ"
local CYAN = Color3.fromRGB(110, 225, 255)
local VIOLET = Color3.fromRGB(150, 110, 255)

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

local GHOST_POOL = 96 -- parts (≈ 12 afterimages × 8 limbs) — fixed, reused
local ghostParts: { Part } = {}
local ghostNext = 1
local DUST_POOL = 24
local dustParts: { Part } = {}
local dustNext = 1
local stats = { ghosts = 0, dust = 0 }

local function ghostPart(): Part
	local p = ghostParts[ghostNext]
	ghostNext = ghostNext % GHOST_POOL + 1
	return p
end

local function spawnAfterimage(character: Model, color: Color3)
	for _, limb in character:GetChildren() do
		if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and limb.Transparency < 1 then
			local g = ghostPart()
			g.Size = limb.Size
			g.CFrame = limb.CFrame
			g.Color = color
			g.Transparency = 0.55
			TweenService:Create(g, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		end
	end
	stats.ghosts += 1
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
	for _ = 1, GHOST_POOL do
		table.insert(ghostParts, poolPart("Afterimage"))
	end
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

	local n = 0
	local dashAt = -1 -- os.clock() of the last executed dash (for the window display only)
	local windowMin, windowMax = 0.2, 0.8
	local superReadyAt = 0 -- server time
	local superEnd = -1 -- os.clock()
	local superLen = 1
	local wind: Sound? = nil
	local baseFov: number? = nil

	ContextActionService:BindActionAtPriority(Q_ACTION, function(_, st: Enum.UserInputState)
		if st == Enum.UserInputState.Begin then
			n += 1 -- one packet per DISTINCT press (key repeat / holding never sends more)
			request:FireServer({ op = "q", n = n })
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.ButtonX) -- above the main-game PHASE_DASH binding (prototype only), sunk

	local active: { kind: string, conn: RBXScriptConnection, parts: { Instance } }? = nil
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
		if not MoveState.Claim(kind, MoveState.Owner() == "dash" and kind == "super") then
			return -- FLING SELF (or another state) owns the velocity right now
		end
		stop()
		local dir = flat(hum.MoveDirection) or flat(hrp.CFrame.LookVector) or Vector3.zAxis
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
		lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * speed
		lv.Parent = hrp
		local t0 = os.clock()
		local run = tune("RunSpeed")
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			if not hrp.Parent or hum.Health <= 0 then
				stop(kind)
				return
			end
			local el = os.clock() - t0
			if turn then -- super-speed: full steering toward the held direction
				local want = flat(hum.MoveDirection)
				if want then
					local d = dir :: Vector3
					local ang = math.acos(math.clamp(d:Dot(want), -1, 1))
					if ang > 1e-3 then
						local step = math.min(ang, turn * dt)
						local cross = d:Cross(want).Y
						local a = if cross >= 0 then step else -step -- CFrame.Angles(0, +a) turns -Z toward -X; cross.Y = d.z*w.x - d.x*w.z
						dir = (CFrame.Angles(0, a, 0) * d).Unit
					end
				end
			end
			-- ease back toward run speed over the last 0.15 s (no hard stop, MOV-01 quick return)
			local k = math.clamp((seconds - el) / 0.15, 0, 1)
			local sp = run + (speed - run) * k
			lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * sp
			if el >= seconds then
				stop(kind)
			end
		end)
		active = { kind = kind, conn = conn, parts = { att, lv } }
	end

	event.OnClientEvent:Connect(function(data: any)
		if typeof(data) ~= "table" then
			return
		end
		local op = data.op
		if op == "dash" then
			dashAt = os.clock()
			windowMin = tonumber(data.windowMin) or 0.2
			windowMax = tonumber(data.windowMax) or 0.8
			superReadyAt = tonumber(data.superReady) or 0
			drive("dash", tonumber(data.seconds) or 0.17, tonumber(data.speed) or 88, nil)
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
			dashAt = -1
			drive("super", superLen, tonumber(data.speed) or 74, tonumber(data.turn) or 14)
			sfx("rbxasset://sounds/action_jump.mp3", 0.85, 0.45)
			sfx("rbxasset://sounds/volume_slider.ogg", 2.6, 0.5)
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
			task.delay(superLen, function()
				if wind then
					wind:Stop()
				end
				sfx("rbxasset://sounds/action_jump_land.mp3", 1.5, 0.3)
			end)
			gui:SetAttribute("LastMove", "super")
		elseif op == "move_fx" then
			if data.kind == "early" then
				sfx("rbxasset://sounds/volume_slider.ogg", 0.7, 0.25) -- soft "too early" tick
				dashAt = -1 -- the window is gone: hide it
			elseif data.kind == "super_cooldown" then
				sfx("rbxasset://sounds/volume_slider.ogg", 0.5, 0.35)
				superReadyAt = tonumber(data.readyAt) or superReadyAt
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
		local inWindowDisplay = dashAt > 0 and now - dashAt <= windowMax + 0.05
		local superOn = superEnd > now
		local cooling = superReadyAt > st
		gauge.Visible = inWindowDisplay or superOn or cooling
		if superOn then
			windowSeg.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = VIOLET
			fill.Size = UDim2.fromScale(math.clamp((superEnd - now) / superLen, 0, 1), 1)
			marker.Visible = false
			label.Text = "SUPER"
		elseif inWindowDisplay then
			local span = windowMax + 0.05
			windowSeg.Position = UDim2.fromScale(windowMin / span, 0)
			windowSeg.Size = UDim2.fromScale((windowMax - windowMin) / span, 1)
			windowSeg.BackgroundColor3 = if cooling then C.Muted else CYAN
			fill.Size = UDim2.fromScale(0, 1)
			marker.Visible = true
			marker.Position = UDim2.fromScale(math.clamp((now - dashAt) / span, 0, 1), 0.5)
			label.Text = if cooling then "SUPER COOLING" else "Q AGAIN"
		elseif cooling then
			windowSeg.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = C.Muted
			fill.Size = UDim2.fromScale(1 - math.clamp((superReadyAt - st) / tune("SuperCooldown"), 0, 1), 1)
			marker.Visible = false
			label.Text = ""
		end
		gui:SetAttribute("MoveOwner", MoveState.Owner())
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
						tr.Enabled = not reduced and (isSuper or isDash or (grounded and hs > 22))
						tr.Color = ColorSequence.new(if isSuper then VIOLET else CYAN)
						tr.Lifetime = if isSuper then 0.28 elseif isDash then 0.2 else 0.12
					end
					if not reduced then
						if isSuper and now - f.lastGhost >= 0.05 then
							f.lastGhost = now
							spawnAfterimage(c, VIOLET)
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
		gui:SetAttribute("FxCounts", string.format("ghosts %d dust %d", stats.ghosts, stats.dust))
	end)
end

return MovementController
