--!strict
-- SpeedFx (Core Round Step 1C, client, owner-approved Phase A item A2): restrained speed presentation.
--   * thin 2D streaks at the screen edges, pointing at the centre, moving inward and fading; count and opacity scale
--     with horizontal speed between SpeedFx.MinSpeed and SpeedFx.FullSpeed (hard cap SpeedFx.Streaks = 24)
--   * a faint team-colour glow on the screen edges during a dash / Super Dash (full) and at high speed (60%)
--   * intensity eases in and out (SpeedFx.FadeSeconds); nothing appears in one frame
--   * streaks never enter the central SpeedFx.ClearRadius of the screen (crosshair, charge ring, hit marker and
--     threat arrows live there) and skip the bottom-centre sector (status bar); the layer draws under the HUD
--   * 2D only (one ScreenGui, pooled frames); no world particles. Off in Reduced FX. Hidden when there is no live
--     character (death / respawn / reset clean up on their own)
-- References (principles only): EMPULSE and the owner's third-person parkour clip sell speed with edge streaks more
-- than with field of view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local CoreGeom = require(CoreRound:WaitForChild("CoreGeom"))

local SpeedFx = {}

local player = Players.LocalPlayer
local function tune(k: string): number
	return CoreConfig.Tune("SpeedFx", k)
end

local deps = {
	reduced = function(): boolean
		return false
	end,
	burst = function(): boolean
		return false
	end,
	teamColor = function(): Color3
		return Color3.new(1, 1, 1)
	end,
}

type Streak = { f: Frame, life: number, age: number, ang: number, r0: number, len: number, alive: boolean }
local streaks: { Streak } = {}
local glows: { Frame } = {}
local gui: ScreenGui? = nil
local intensity = 0 -- eased 0..1 from speed
local glow = 0 -- eased 0..1
local spawnAcc = 0

SpeedFx.Stats = { frames = 0, seconds = 0, maxVisible = 0 } -- test hook: script time and streak count

local function build()
	local g = Instance.new("ScreenGui")
	g.Name = "CoreRoundSpeedFx"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = -1 -- under the Core Round HUD (DisplayOrder 0)
	g.Enabled = false
	for i = 1, 24 do
		local f = Instance.new("Frame")
		f.Name = "Streak"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 1
		f.Visible = false
		f.Parent = g
		table.insert(streaks, { f = f, life = 0, age = 0, ang = 0, r0 = 0, len = 0, alive = false })
	end
	-- edge glow: four gradient strips (transparent toward the centre)
	local specs = {
		{ size = UDim2.new(1, 0, 0.16, 0), pos = UDim2.new(0, 0, 0, 0), rot = 90 },
		{ size = UDim2.new(1, 0, 0.16, 0), pos = UDim2.new(0, 0, 0.84, 0), rot = -90 },
		{ size = UDim2.new(0.1, 0, 1, 0), pos = UDim2.new(0, 0, 0, 0), rot = 0 },
		{ size = UDim2.new(0.1, 0, 1, 0), pos = UDim2.new(0.9, 0, 0, 0), rot = 180 },
	}
	for _, s in specs do
		local f = Instance.new("Frame")
		f.Name = "EdgeGlow"
		f.Size = s.size
		f.Position = s.pos
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 1
		local grad = Instance.new("UIGradient")
		grad.Rotation = s.rot
		grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		grad.Parent = f
		f.Parent = g
		table.insert(glows, f)
	end
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
end

local function respawnStreak(s: Streak, vp: Vector2)
	-- pick an angle outside the bottom-centre sector (status bar) ; screen angle 0 = right, +90 = down
	local ang
	for _ = 1, 6 do
		ang = math.random() * math.pi * 2
		local deg = math.deg(ang) % 360
		if not (deg > 62 and deg < 118) then
			break
		end
	end
	s.ang = ang :: number
	s.r0 = 1.08 + math.random() * 0.1 -- start just outside the edge (normalised to the half-screen ellipse)
	s.len = (0.08 + math.random() * 0.1) * math.min(vp.X, vp.Y)
	s.life = 0.22 + math.random() * 0.12
	s.age = 0
	s.alive = true
end

function SpeedFx.Start(d: typeof(deps))
	deps = d
	build()
	RunService:BindToRenderStep("CoreRoundSpeedFx", Enum.RenderPriority.Last.Value, function(dt)
		local t0 = os.clock()
		local g = gui :: ScreenGui
		local c = player.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local on = hrp ~= nil and hum ~= nil and hum.Health > 0 and tune("Enabled") >= 0.5 and not deps.reduced()
		local target, glowTarget = 0, 0
		if on then
			local v = (hrp :: BasePart).AssemblyLinearVelocity
			local hs = Vector3.new(v.X, 0, v.Z).Magnitude
			target = CoreGeom.Ease((hs - tune("MinSpeed")) / math.max(1, tune("FullSpeed") - tune("MinSpeed")))
			glowTarget = if deps.burst() then 1 else target * 0.6
		end
		local rate = dt / math.max(0.05, tune("FadeSeconds"))
		intensity += math.clamp(target - intensity, -rate, rate)
		glow += math.clamp(glowTarget - glow, -rate, rate)
		if intensity <= 0.001 and glow <= 0.001 then
			if g.Enabled then
				g.Enabled = false
				for _, s in streaks do
					s.alive = false
					s.f.Visible = false
				end
			end
			SpeedFx.Stats.frames += 1
			SpeedFx.Stats.seconds += os.clock() - t0
			return
		end
		g.Enabled = true
		local vp = workspace.CurrentCamera.ViewportSize
		local half = vp / 2
		local maxN = math.clamp(math.floor(tune("Streaks")), 0, 24)
		local wantAlive = math.floor(maxN * intensity + 0.5)
		local alive = 0
		for _, s in streaks do
			if s.alive then
				alive += 1
			end
		end
		-- spawn toward the wanted count (staggered, not all at once)
		spawnAcc += dt * 40 * intensity
		local i = 1
		while spawnAcc >= 1 and alive < wantAlive and i <= #streaks do
			local s = streaks[i]
			if not s.alive and i <= maxN then
				respawnStreak(s, vp)
				alive += 1
				spawnAcc -= 1
			end
			i += 1
		end
		spawnAcc = math.min(spawnAcc, 3)
		local clear = tune("ClearRadius")
		local alpha = tune("StreakAlpha")
		local visible = 0
		for _, s in streaks do
			if s.alive then
				s.age += dt
				local k = s.age / s.life
				if k >= 1 then
					s.alive = false
					s.f.Visible = false
				else
					-- move inward from the edge, never past the clear radius; fade in and out over its life
					local r = s.r0 - (s.r0 - clear - 0.1) * CoreGeom.Ease(k)
					local cx, cy = math.cos(s.ang), math.sin(s.ang)
					local px, py = half.X + cx * half.X * r, half.Y + cy * half.Y * r
					-- the streak's inner end must stay outside the clear ellipse
					local inner = math.sqrt(((px - cx * s.len / 2 - half.X) / half.X) ^ 2 + ((py - cy * s.len / 2 - half.Y) / half.Y) ^ 2)
					if inner < clear then
						s.alive = false
						s.f.Visible = false
					else
						local a = alpha * intensity * math.sin(k * math.pi)
						s.f.Position = UDim2.fromOffset(px, py)
						s.f.Size = UDim2.fromOffset(s.len, 2)
						s.f.Rotation = math.deg(s.ang)
						s.f.BackgroundTransparency = 1 - a
						s.f.Visible = true
						visible += 1
					end
				end
			end
		end
		SpeedFx.Stats.maxVisible = math.max(SpeedFx.Stats.maxVisible, visible)
		local col = deps.teamColor()
		for _, f in glows do
			f.BackgroundColor3 = col
			f.BackgroundTransparency = 1 - tune("GlowAlpha") * glow
		end
		SpeedFx.Stats.frames += 1
		SpeedFx.Stats.seconds += os.clock() - t0
	end)
end

function SpeedFx.Intensity(): (number, number)
	return intensity, glow
end

return SpeedFx
