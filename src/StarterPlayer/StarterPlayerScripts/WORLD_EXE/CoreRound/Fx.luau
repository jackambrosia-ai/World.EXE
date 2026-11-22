--!strict
-- Fx (Core Round Step 1, client): pooled local effects (bursts, rings, shards, afterimages) and placeholder sounds.
-- Everything lives in Workspace.CoreRoundFx (client-only, never on the server). Parts are anchored, massless,
-- CanCollide / CanQuery / CanTouch = false, so effects never affect movement, hits or pickups.
-- Sounds are pitch-shifted built-in rbxasset placeholders (no uploads); final audio is a later art task.

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Fx = {}

Fx.Reduced = false -- Reduced Effects (accessibility / low-end): fewer particles, no afterimages

local folder: Folder
local pool: { BasePart } = {}
type Anim = { part: BasePart, t0: number, life: number, s0: Vector3, s1: Vector3, tr0: number, tr1: number, vel: Vector3?, cf: CFrame }
local anims: { Anim } = {}

local function mkPart(): BasePart
	local p = table.remove(pool)
	if p then
		return p
	end
	local n = Instance.new("Part")
	n.Anchored = true
	n.CanCollide = false
	n.CanQuery = false
	n.CanTouch = false
	n.CastShadow = false
	n.Massless = true
	n.TopSurface = Enum.SurfaceType.Smooth
	n.BottomSurface = Enum.SurfaceType.Smooth
	return n
end

local function release(p: BasePart)
	p.Parent = nil
	if #pool < 400 then
		table.insert(pool, p)
	else
		p:Destroy()
	end
end

function Fx.Folder(): Folder
	return folder
end

-- generic animated part: scales s0 -> s1 and fades tr0 -> tr1 over life seconds
local function play(shape: Enum.PartType, cf: CFrame, color: Color3, s0: Vector3, s1: Vector3, life: number, tr0: number, tr1: number, material: Enum.Material?, vel: Vector3?)
	local p = mkPart()
	p.Shape = shape
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = s0
	p.CFrame = cf
	p.Transparency = tr0
	p.Parent = folder
	table.insert(anims, { part = p, t0 = os.clock(), life = life, s0 = s0, s1 = s1, tr0 = tr0, tr1 = tr1, vel = vel, cf = cf })
end

-- impact burst: a quick expanding sphere plus a few sparks
function Fx.Burst(pos: Vector3, color: Color3, size: number)
	play(Enum.PartType.Ball, CFrame.new(pos), color, Vector3.one * size * 0.3, Vector3.one * size, 0.22, 0.1, 1)
	local sparks = if Fx.Reduced then 2 else 6
	for _ = 1, sparks do
		local d = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
		play(Enum.PartType.Block, CFrame.lookAt(pos, pos + d), color, Vector3.new(0.12, 0.12, 0.9), Vector3.new(0.05, 0.05, 0.3), 0.3, 0, 1, nil, d * 30)
	end
end

-- flat ring (e.g. a bounce mark on a wall, or a shield impact), facing normal
function Fx.Ring(pos: Vector3, normal: Vector3, color: Color3, size: number, life: number)
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.rad(90), 0)
	play(Enum.PartType.Cylinder, cf, color, Vector3.new(0.08, size * 0.4, size * 0.4), Vector3.new(0.04, size, size), life, 0.15, 1)
end

-- shards flying out (shield break)
function Fx.Shards(cf: CFrame, color: Color3, w: number, h: number)
	local n = if Fx.Reduced then 5 else 12
	for _ = 1, n do
		local off = cf * Vector3.new((math.random() - 0.5) * w, (math.random() - 0.5) * h, 0)
		local d = (cf.LookVector * 0.6 + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5)).Unit
		play(Enum.PartType.Block, CFrame.new(off) * CFrame.Angles(math.random() * 3, math.random() * 3, 0), color, Vector3.new(0.9, 0.6, 0.08), Vector3.new(0.3, 0.2, 0.05), 0.6, 0.2, 1, Enum.Material.Glass, d * 18)
	end
end

-- afterimage: neon copies of the visible body parts, fading
function Fx.Afterimage(character: Model, color: Color3)
	if Fx.Reduced then
		return
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9 and d.Size.Magnitude > 0.6 then
			play(Enum.PartType.Block, d.CFrame, color, d.Size, d.Size * 0.96, 0.28, 0.72, 1)
		end
	end
end

-- placeholder sounds (built-in files, pitch-shifted)
local SOUNDS = {
	throw = { "rbxasset://sounds/action_jump.mp3", 1.7, 0.5 },
	dash = { "rbxasset://sounds/action_jump.mp3", 1.25, 0.35 },
	super = { "rbxasset://sounds/action_jump.mp3", 0.8, 0.5 },
	hit_body = { "rbxasset://sounds/volume_slider.ogg", 1.3, 0.9 },
	hit_head = { "rbxasset://sounds/volume_slider.ogg", 2.1, 1.0 },
	stun = { "rbxasset://sounds/impact_explosion_03.mp3", 1.6, 0.35 },
	catch = { "rbxasset://sounds/volume_slider.ogg", 0.8, 0.6 },
	block = { "rbxasset://sounds/action_jump_land.mp3", 1.9, 0.8 },
	shield_break = { "rbxasset://sounds/impact_explosion_03.mp3", 2.3, 0.5 },
	shield_up = { "rbxasset://sounds/volume_slider.ogg", 0.6, 0.5 },
	deny = { "rbxasset://sounds/volume_slider.ogg", 0.45, 0.6 },
	bounce = { "rbxasset://sounds/action_jump_land.mp3", 2.6, 0.5 },
	-- Step 1B
	charge_tick = { "rbxasset://sounds/volume_slider.ogg", 1.0, 0.35 },
	-- full charge: a clean "ready" chime, one step above the last charge tick (ticks rise to x1.8); the earlier
	-- pitched-up explosion still read as an explosion (owner feedback 2026-11-21)
	charge_max = { "rbxasset://sounds/volume_slider.ogg", 2.4, 0.6 },
	throw_max = { "rbxasset://sounds/action_jump.mp3", 2.2, 0.7 },
	slide_start = { "rbxasset://sounds/action_jump_land.mp3", 0.7, 0.5 },
	wall_catch = { "rbxasset://sounds/action_jump_land.mp3", 1.4, 0.45 },
	wall_jump = { "rbxasset://sounds/action_jump.mp3", 1.1, 0.45 },
	land_hard = { "rbxasset://sounds/action_jump_land.mp3", 0.9, 0.55 },
	-- Step 1D: Power Slide Jump launch (deeper, louder jump)
	power_jump = { "rbxasset://sounds/action_jump.mp3", 0.72, 0.75 },
}

-- pitch: optional multiplier on the sound's base playback speed (charge ticks rise in pitch)
function Fx.Sound(name: string, at: Vector3?, pitch: number?)
	local def = SOUNDS[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = def[1] :: string
	s.PlaybackSpeed = (def[2] :: number) * (pitch or 1)
	s.Volume = def[3] :: number
	if at then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = workspace.Terrain
		s.RollOffMaxDistance = 220
		s.Parent = a
		s:Play()
		Debris:AddItem(a, 2)
	else
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 2)
	end
end

function Fx.Start()
	folder = workspace:FindFirstChild("CoreRoundFx") :: Folder?
		or (function()
			local f = Instance.new("Folder")
			f.Name = "CoreRoundFx"
			f.Parent = workspace
			return f
		end)()
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i = #anims, 1, -1 do
			local a = anims[i]
			local k = (t - a.t0) / a.life
			if k >= 1 then
				release(a.part)
				table.remove(anims, i)
			else
				a.part.Size = a.s0:Lerp(a.s1, k)
				a.part.Transparency = a.tr0 + (a.tr1 - a.tr0) * k
				if a.vel then
					a.cf += a.vel * dt
					a.vel *= 0.9
					a.part.CFrame = a.cf
				end
			end
		end
	end)
end

return Fx
