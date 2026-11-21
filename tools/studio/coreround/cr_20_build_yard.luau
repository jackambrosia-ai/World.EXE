--!nonstrict
-- Core Round Step 1: builds the isolated movement + Rebound Disc test yard in the open CORE ROUND place
-- (Edit mode). Native parts only: no meshes, no uploads, no Toolbox. Re-runnable (deletes and rebuilds
-- Workspace.CoreRoundYard). Refuses any place whose name does not contain "CoreRound".
-- Sets Workspace.WORLD_EXE_CoreRound = true (the prototype gate), creates the Cyan / Orange teams.
--
-- Layout (studs; ground top at y = 0):
--   Hub + spawns        Cyan pad (-14, 0, 110), Orange pad (14, 0, 190) inside the COMBAT ARENA (centre 0, 0, 150)
--   Combat arena        100 x 100, low perimeter walls with gaps, 6 cover blocks, 2 raised platforms (h 10) with
--                       ramps, centre pillar: the two-player area
--   Disc range (east)   firing line x = 30 (z -30..30); static dummies at 20 / 40 / 60 studs; a moving dummy on its
--                       own lane (x 80, z -55..-22, fire from (30, -38)); an angled rebound wall, a north rebound
--                       wall and a long back wall; cover blocks
--   Shield test         D-SHIELD with a permanent shield facing the firing line, D-BEHIND (same team) behind it
--   Movement lane (N)   straight runway z -20 .. -220 with a mark every 10 studs (numbers every 20)
--   Gap course (W)      x = -120: stairs to rooftop height 20, then platforms with gaps 16 / 26 / 40 / 55 / 70
--   Wall-run walls (NW) two parallel walls (24 tall, 80 long, 20 apart)
assert(string.find(game.Name, "CoreRound", 1, true), "core round test place only")
-- Step 1B: also builds the slide slopes and the wall-run v2 course (folder Step1B)
-- Step 1D: Power Slide Jump ledges 8 / 12 / 16 / 20 studs high at x 160..208, z -20 (folder Step1D)

local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")

for _, n in { "CoreRoundYard", "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

local ROOT = Instance.new("Folder")
ROOT.Name = "CoreRoundYard"
local count = 0

local C = {
	ground = Color3.fromRGB(38, 42, 50),
	line = Color3.fromRGB(70, 78, 90),
	wall = Color3.fromRGB(96, 104, 118),
	cover = Color3.fromRGB(120, 128, 140),
	roof = Color3.fromRGB(82, 90, 104),
	accent = Color3.fromRGB(40, 220, 255),
	orange = Color3.fromRGB(255, 140, 40),
	cyan = Color3.fromRGB(40, 220, 255),
	mark = Color3.fromRGB(210, 220, 230),
	dummy = Color3.fromRGB(180, 186, 196),
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	count += 1
	return p
end

local function sign(parent: Instance, at: Vector3, text: string, color: Color3?)
	local post = part(parent, "Sign", Vector3.new(0.4, 0.4, 0.4), CFrame.new(at), C.line, nil, { Transparency = 1, CanCollide = false, CanQuery = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 40)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 160
	bb.Parent = post
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 0.35
	t.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextColor3 = color or C.accent
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = t
end

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = ROOT
	return f
end

-- ---------- ground ----------
local G = folder("Ground")
part(G, "Floor", Vector3.new(460, 1, 520), CFrame.new(0, -0.5, -20), C.ground, Enum.Material.Concrete)
for x = -220, 220, 20 do
	part(G, "GridX", Vector3.new(0.25, 0.05, 520), CFrame.new(x, 0.02, -20), C.line, nil, { CanCollide = false, CanQuery = false })
end
for z = -280, 240, 20 do
	part(G, "GridZ", Vector3.new(460, 0.05, 0.25), CFrame.new(0, 0.02, z), C.line, nil, { CanCollide = false, CanQuery = false })
end

-- ---------- combat arena (two-player area) ----------
local A = folder("CombatArena")
local AC = Vector3.new(0, 0, 150)
part(A, "ArenaFloor", Vector3.new(100, 0.2, 100), CFrame.new(AC + Vector3.new(0, 0.1, 0)), Color3.fromRGB(46, 52, 62), Enum.Material.SmoothPlastic)
for _, w in {
	{ Vector3.new(40, 4, 1), Vector3.new(-30, 2, -50) }, { Vector3.new(40, 4, 1), Vector3.new(30, 2, -50) },
	{ Vector3.new(40, 4, 1), Vector3.new(-30, 2, 50) }, { Vector3.new(40, 4, 1), Vector3.new(30, 2, 50) },
	{ Vector3.new(1, 4, 40), Vector3.new(-50, 2, -30) }, { Vector3.new(1, 4, 40), Vector3.new(-50, 2, 30) },
	{ Vector3.new(1, 4, 40), Vector3.new(50, 2, -30) }, { Vector3.new(1, 4, 40), Vector3.new(50, 2, 30) },
} do
	part(A, "PerimeterWall", w[1], CFrame.new(AC + w[2]), C.wall)
end
for i, cov in {
	Vector3.new(-25, 3, -18), Vector3.new(25, 3, 18), Vector3.new(-10, 3, 22), Vector3.new(10, 3, -22), Vector3.new(-32, 3, 10), Vector3.new(32, 3, -10),
} do
	part(A, "Cover" .. i, Vector3.new(8, 6, 8), CFrame.new(AC + cov), C.cover)
end
part(A, "Pillar", Vector3.new(6, 16, 6), CFrame.new(AC + Vector3.new(0, 8, 0)), C.wall)
for _, s in { -1, 1 } do
	local px = s * 30
	part(A, "Platform", Vector3.new(16, 1, 16), CFrame.new(AC + Vector3.new(px, 9.5, s * 30)), C.roof)
	for _, leg in { Vector3.new(-7, 4.5, -7), Vector3.new(7, 4.5, -7), Vector3.new(-7, 4.5, 7), Vector3.new(7, 4.5, 7) } do
		part(A, "PlatformLeg", Vector3.new(1, 9, 1), CFrame.new(AC + Vector3.new(px, 0, s * 30) + leg), C.line)
	end
	-- ramp up to the platform (about 24 degrees)
	local rampLen = 24
	local ang = math.atan(10 / 22)
	part(A, "Ramp", Vector3.new(8, 1, rampLen), CFrame.new(AC + Vector3.new(px, 5, s * 30 - s * 19)) * CFrame.Angles(s * ang, 0, 0), C.roof)
end
local spC = Instance.new("SpawnLocation")
spC.Name = "SpawnCyan"
spC.Size = Vector3.new(10, 1, 10)
spC.CFrame = CFrame.new(-14, 0.5, 110)
spC.Anchored = true
spC.Neutral = false
spC.TeamColor = BrickColor.new("Cyan")
spC.Color = C.cyan
spC.Material = Enum.Material.Neon
spC.Transparency = 0.5
spC.Duration = 0
spC.Parent = A
local spO = spC:Clone()
spO.Name = "SpawnOrange"
spO.CFrame = CFrame.new(14, 0.5, 190)
spO.TeamColor = BrickColor.new("Neon orange")
spO.Color = C.orange
spO.Parent = A
count += 2
sign(A, AC + Vector3.new(0, 20, -52), "COMBAT ARENA (2 players)")

-- ---------- dummies ----------
local D = folder("Dummies")
local function dummy(name: string, pos: Vector3, team: string, yawDeg: number, extra: { [string]: any }?)
	local m = Instance.new("Model")
	m.Name = name
	local col = if team == "Cyan" then C.cyan elseif team == "Orange" then C.orange else C.dummy
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local hrp = part(m, "HumanoidRootPart", Vector3.new(2, 2, 1), cf * CFrame.new(0, 3, 0), C.dummy, nil, { Transparency = 1, CanCollide = false })
	part(m, "Torso", Vector3.new(2, 2, 1), cf * CFrame.new(0, 3, 0), C.dummy)
	part(m, "Head", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 4.6, 0), C.dummy)
	part(m, "Visor", Vector3.new(1.0, 0.3, 0.1), cf * CFrame.new(0, 4.75, -0.62), col, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	part(m, "Left Arm", Vector3.new(1, 2, 1), cf * CFrame.new(-1.5, 3, 0), C.dummy)
	part(m, "Right Arm", Vector3.new(1, 2, 1), cf * CFrame.new(1.5, 3, 0), C.dummy)
	part(m, "Left Leg", Vector3.new(1, 2, 1), cf * CFrame.new(-0.5, 1, 0), C.dummy)
	part(m, "Right Leg", Vector3.new(1, 2, 1), cf * CFrame.new(0.5, 1, 0), C.dummy)
	part(m, "TeamBand", Vector3.new(2.05, 0.3, 1.05), cf * CFrame.new(0, 3.6, 0), col, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	m.PrimaryPart = hrp
	m:SetAttribute("CR_Dummy", true)
	m:SetAttribute("CR_Team", team)
	for k, v in extra or {} do
		m:SetAttribute(k, v)
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Diag"
	bb.Size = UDim2.fromOffset(150, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 60
	bb.Parent = hrp
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 0.4
	t.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	t.Size = UDim2.fromScale(1, 1)
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Font = Enum.Font.Code
	t.TextScaled = true
	t.Text = name
	t.Parent = bb
	m.Parent = D
	return m
end

-- ---------- disc range (east) ----------
local R = folder("DiscRange")
part(R, "FiringLine", Vector3.new(0.3, 0.05, 60), CFrame.new(30, 0.04, 0), Color3.fromRGB(60, 150, 175), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
for i, d in { 20, 40, 60 } do
	dummy("D-STATIC-" .. d, Vector3.new(30 + d, 0, -12 + (i - 1) * 12), "Orange", 90)
end
-- moving target on its own clear lane north of the statics (fire from (30, -37) toward +X).
-- Rail points are root (pivot) positions: root height 3.
dummy("D-MOVING", Vector3.new(80, 0, -38), "Orange", 90, { CR_MoveA = Vector3.new(80, 3, -55), CR_MoveB = Vector3.new(80, 3, -22), CR_MoveSpeed = 14 })
part(R, "MovingLaneLine", Vector3.new(0.3, 0.05, 18), CFrame.new(30, 0.04, -38), Color3.fromRGB(150, 160, 170), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
-- a Cyan target for the Orange player (second client), west of the arena
dummy("D-CYAN-30", Vector3.new(-30, 0, 40), "Cyan", -90)
part(R, "BackWall", Vector3.new(2, 14, 110), CFrame.new(118, 7, 10), C.wall)
part(R, "ReboundWall", Vector3.new(2, 10, 26), CFrame.new(96, 5, 38) * CFrame.Angles(0, math.rad(45), 0), C.wall)
part(R, "ReboundWall2", Vector3.new(26, 10, 2), CFrame.new(60, 5, -62), C.wall)
part(R, "RangeCover1", Vector3.new(6, 5, 6), CFrame.new(48, 2.5, 22), C.cover)
part(R, "RangeCover2", Vector3.new(6, 5, 6), CFrame.new(90, 2.5, -30), C.cover)
sign(R, Vector3.new(30, 9, -34), "DISC RANGE  (firing line x=30)")

-- shield test: permanent shield facing the firing line (yaw -90 => facing -X), teammate behind it
local S = folder("ShieldTest")
dummy("D-SHIELD", Vector3.new(70, 0, 62), "Orange", 90, { CR_ShieldFixedYaw = -90 })
dummy("D-BEHIND", Vector3.new(76, 0, 62), "Orange", 90)
part(S, "ShieldLine", Vector3.new(0.3, 0.05, 20), CFrame.new(40, 0.04, 62), Color3.fromRGB(190, 120, 60), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false })
sign(S, Vector3.new(55, 10, 62), "SHIELD TEST (front: x=40, flank: z=40)")

-- ---------- movement lane (north) ----------
local M = folder("MovementLane")
part(M, "Runway", Vector3.new(24, 0.2, 200), CFrame.new(0, 0.1, -120), Color3.fromRGB(52, 58, 70))
for k = 0, 200, 10 do
	part(M, "Mark" .. k, Vector3.new(24, 0.06, if k % 50 == 0 then 0.6 else 0.25), CFrame.new(0, 0.23, -20 - k), C.mark, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	if k % 20 == 0 then
		sign(M, Vector3.new(15, 2, -20 - k), tostring(k) .. " studs", C.mark)
	end
end
sign(M, Vector3.new(0, 10, -18), "MOVEMENT LANE (dash 26 / super ~70)")

-- gap course (west): stairs to rooftop height 20, then platforms with gaps
local GC = folder("GapCourse")
local H = 20
local GX = -120
for s = 0, 9 do
	part(GC, "Stair" .. s, Vector3.new(16, 2, 4), CFrame.new(GX, 1 + s * 2, -30 - s * 4), C.roof)
	part(GC, "StairFill" .. s, Vector3.new(16, 1 + s * 2, 4), CFrame.new(GX, (1 + s * 2) / 2, -30 - s * 4), C.line)
end
local z = -70
part(GC, "Roof0", Vector3.new(20, 1, 30), CFrame.new(GX, H - 0.5, z - 15), C.roof)
z -= 30
for i, gap in { 16, 26, 40, 55, 70 } do
	z -= gap
	part(GC, "Roof" .. i, Vector3.new(20, 1, 30), CFrame.new(GX, H - 0.5, z - 15), C.roof)
	part(GC, "RoofBody" .. i, Vector3.new(20, H - 1, 30), CFrame.new(GX, (H - 1) / 2, z - 15), C.line, nil, { Transparency = 0.6 })
	sign(GC, Vector3.new(GX, H + 4, z + gap / 2), "gap " .. gap, C.mark)
	z -= 30
end
sign(GC, Vector3.new(GX, 8, -24), "ROOFTOP GAPS 16/26/40/55/70 (h 20)")

-- wall-run walls (north-west)
local W = folder("WallRun")
part(W, "WallA", Vector3.new(2, 24, 80), CFrame.new(-50, 12, -100), C.wall)
part(W, "WallB", Vector3.new(2, 24, 80), CFrame.new(-70, 12, -100), C.wall)
part(W, "LandingBlock", Vector3.new(16, 10, 16), CFrame.new(-60, 5, -160), C.roof)
sign(W, Vector3.new(-60, 28, -58), "WALL-RUN (optional)")

-- ---------- Step 1B: slide slopes + Titanfall-style wall-run course ----------
local B = folder("Step1B")
-- three downhill slide slopes (10 / 20 / 30 degrees), each 60 long, running down toward +Z, with stair access
for i, deg in { 10, 20, 30 } do
	local x = 130 + (i - 1) * 28
	local len = 60
	local rise = len * math.tan(math.rad(deg))
	local zTop, zBottom = -200, -200 + len
	local mid = Vector3.new(x, rise / 2, (zTop + zBottom) / 2)
	local slope = part(B, "Slope" .. deg, Vector3.new(16, 1, len / math.cos(math.rad(deg))), CFrame.new(mid) * CFrame.Angles(math.rad(deg), 0, 0), C.roof, Enum.Material.SmoothPlastic)
	local _ = slope
	part(B, "SlopeTop" .. deg, Vector3.new(16, 1, 14), CFrame.new(x, rise - 0.5, zTop - 7), C.roof)
	part(B, "SlopeTopBody" .. deg, Vector3.new(16, rise - 1, 14), CFrame.new(x, (rise - 1) / 2, zTop - 7), C.line, nil, { Transparency = 0.5 })
	local steps = math.ceil(rise / 2)
	for s = 1, steps do
		part(B, "SlopeStair" .. deg .. "_" .. s, Vector3.new(6, s * 2, 3), CFrame.new(x + 11, s, zTop - 14 + s * 0) + Vector3.new(0, 0, -(steps - s) * 3), C.line)
	end
	-- run-out marks every 10 studs past the bottom
	for k = 0, 60, 10 do
		part(B, "RunOut" .. deg .. "_" .. k, Vector3.new(16, 0.05, 0.25), CFrame.new(x, 0.03, zBottom + k), C.mark, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	end
	sign(B, Vector3.new(x, rise + 6, zTop - 7), "SLIDE SLOPE " .. deg .. "°")
end
-- wall-run v2 course (west): run-up lane + launch block, two staggered walls for wall-to-wall chaining,
-- a waist-high rail (Titanfall 2 reference: anything about waist high is a short wall-run surface)
local WX = -175
part(B, "WR2_Launch", Vector3.new(10, 3, 10), CFrame.new(WX, 1.5, -48), C.roof)
part(B, "WR2_WallA", Vector3.new(2, 16, 70), CFrame.new(WX + 8, 8, -95), C.wall)
part(B, "WR2_WallB", Vector3.new(2, 16, 70), CFrame.new(WX - 6, 8, -150), C.wall) -- 12-stud gap to wall A: wall-jump chaining
part(B, "WR2_Rail", Vector3.new(2, 4.5, 60), CFrame.new(WX + 30, 2.25, -100), C.cover)
part(B, "WR2_Landing", Vector3.new(14, 6, 14), CFrame.new(WX, 3, -205), C.roof)
for k = 0, 160, 20 do
	part(B, "WR2_Mark" .. k, Vector3.new(24, 0.05, 0.25), CFrame.new(WX, 0.03, -40 - k), C.mark, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
end
sign(B, Vector3.new(WX, 20, -40), "WALL-RUN v2 (jump along a wall)")
sign(B, Vector3.new(WX + 30, 9, -70), "waist-high rail")

-- ---------- Step 1D: Power Slide Jump ledges (east; area checked clear: x 156..220) ----------
-- four ledges 8 / 12 / 16 / 20 studs high, 12 wide, each with a 70-stud run-up lane marked every 10 studs
local PJ = folder("Step1D")
for i, h in { 8, 12, 16, 20 } do
	local x = 160 + (i - 1) * 16
	part(PJ, "Ledge" .. h, Vector3.new(12, h, 14), CFrame.new(x, h / 2, -20), C.roof)
	sign(PJ, Vector3.new(x, h + 4, -20), h .. " studs")
	for k = 10, 70, 10 do
		part(PJ, "Lane" .. h .. "_" .. k, Vector3.new(12, 0.05, 0.25), CFrame.new(x, 0.03, -13 + k), C.mark, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	end
end
sign(PJ, Vector3.new(184, 26, 30), "POWER SLIDE JUMP (slide, then jump)")

ROOT.Parent = workspace

-- ---------- teams, gate, lighting ----------
for _, t in Teams:GetChildren() do
	t:Destroy()
end
local tc = Instance.new("Team")
tc.Name = "Cyan"
tc.TeamColor = BrickColor.new("Cyan")
tc.AutoAssignable = false
tc.Parent = Teams
local to = Instance.new("Team")
to.Name = "Orange"
to.TeamColor = BrickColor.new("Neon orange")
to.AutoAssignable = false
to.Parent = Teams

workspace:SetAttribute("WORLD_EXE_CoreRound", true)
-- Step 1D: Left Shift slides, so Roblox's shift-lock option is off in the Core Round test place (own aim lock)
game:GetService("StarterPlayer").EnableMouseLockOption = false
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(110, 115, 125)
Lighting.Ambient = Color3.fromRGB(60, 64, 72)

return string.format("built CoreRoundYard: %d parts, %d dummies", count, #D:GetChildren())
