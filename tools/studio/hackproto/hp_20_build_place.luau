--!nonstrict
-- Wrist-hacking prototype: builds the isolated test environment in the open PROTOTYPE place
-- (Edit mode). Native parts only, no assets. Re-runnable: it deletes and rebuilds Workspace.HackProto
-- and Workspace.WORLD_EXE. Never run in Place1 or any map place (guard below).
--
-- Layout (outside the game's arena box +-275 so the lobby containment never pulls players back):
--   Launch area        (450, 0, -105)  LobbySpawn = where everyone spawns
--   Height lanes       x 390.., z -60/-45/-30/-15: platforms H 8/14/20/26 at D 24/32/36/40
--   Gap course         z 70: segments at Y 12, gaps 16/24/32/40 over safe ground, ramp + stairs
--   Dummies            DUMMY-A stationary (wall 22 studs behind it), DUMMY-B patrol, DUMMY-C on a
--                      12-high ledge, landing test pieces (slope, beam, crate)
--   Boss arena         centre (450, 0, 180), radius 75, 3 cover pillars, CONDUCTOR placeholder,
--                      3 mode consoles at the entrance (z 98)
--   Game containers    WORLD_EXE.Lobby (LobbySpawn) and WORLD_EXE.Map (4 ArenaSpawn match pads at
--                      the origin) so the unchanged WORLD.EXE bootstrap runs (it reports Degraded:
--                      the prototype map has none of the match markers by design).
local CollectionService = game:GetService("CollectionService")
assert(string.find(game.Name, "HackPrototype", 1, true), "prototype place only")

for _, n in { "HackProto", "WORLD_EXE", "Baseplate" } do
	local old = workspace:FindFirstChild(n)
	if old then
		old:Destroy()
	end
end

local ROOT = Instance.new("Folder")
ROOT.Name = "HackProto"
ROOT.Parent = workspace
local count = 0

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

local function label(parent: Instance, adornee: BasePart, text: string, offset: number?, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(170, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offset or 3, 0)
	bb.Adornee = adornee
	bb.MaxDistance = 140
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextColor3 = color or Color3.fromRGB(245, 247, 255)
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
end

local C_GROUND = Color3.fromRGB(28, 32, 44)
local C_PAD = Color3.fromRGB(46, 52, 70)
local C_CYAN = Color3.fromRGB(0, 225, 255)
local C_AMBER = Color3.fromRGB(255, 193, 7)
local C_MAG = Color3.fromRGB(214, 38, 170)
local C_GREEN = Color3.fromRGB(60, 220, 140)

-- Ground (top Y = 0)
part(ROOT, "Ground", Vector3.new(420, 4, 460), CFrame.new(470, -2, 40), C_GROUND, Enum.Material.Concrete)

-- Launch area
local launch = Instance.new("Folder")
launch.Name = "LaunchArea"
launch.Parent = ROOT
local pad = part(launch, "LaunchPad", Vector3.new(32, 0.4, 24), CFrame.new(450, 0.2, -105), C_PAD, Enum.Material.Metal)
for _, x in { -16, 16 } do
	part(launch, "Edge", Vector3.new(0.4, 0.5, 24), CFrame.new(450 + x, 0.25, -105), C_CYAN, Enum.Material.Neon, { CanCollide = false })
end
label(launch, pad, "LAUNCH AREA · press H for the wrist terminal", 6, C_CYAN)

-- Height lanes (FLING SELF reach tests): start markers at x 390, platforms at x 390 + D
local lanes = Instance.new("Folder")
lanes.Name = "HeightLanes"
lanes.Parent = ROOT
local laneDefs = { { z = -60, h = 8, d = 24 }, { z = -45, h = 14, d = 32 }, { z = -30, h = 20, d = 36 }, { z = -15, h = 26, d = 40 } }
for i, L in laneDefs do
	local start = part(lanes, "LaneStart" .. i, Vector3.new(6, 0.3, 6), CFrame.new(390, 0.15, L.z), C_AMBER, Enum.Material.Neon, { CanCollide = false })
	label(lanes, start, string.format("LANE %d → H %d · D %d", i, L.h, L.d), 2.5, C_AMBER)
	local plat = part(lanes, "Platform" .. i, Vector3.new(12, L.h, 12), CFrame.new(390 + L.d + 6, L.h / 2, L.z), C_PAD, Enum.Material.Metal)
	part(lanes, "PlatformTop" .. i, Vector3.new(12, 0.2, 12), CFrame.new(390 + L.d + 6, L.h + 0.1, L.z), C_CYAN, Enum.Material.Neon, { CanCollide = false, Transparency = 0.6 })
	plat:SetAttribute("TopY", L.h)
	plat:SetAttribute("NearEdgeDistance", L.d)
end

-- Gap course at z 70: segments at Y 12 (top), gaps 16/24/32/40; falling is safe (ground at 0)
local gaps = Instance.new("Folder")
gaps.Name = "GapCourse"
gaps.Parent = ROOT
local x = 400
local segs = { 20, 20, 20, 20, 20 }
local gapSizes = { 16, 24, 32, 40 }
-- access stairs (also the way back after a fall): 6 steps up to Y 12 just before segment 1
for st = 1, 6 do
	part(gaps, "Stair" .. st, Vector3.new(4, 2 * st, 14), CFrame.new(376 + (st - 0.5) * 4, st, 70), C_PAD, Enum.Material.Metal)
end
for i, len in segs do
	local seg = part(gaps, "Segment" .. i, Vector3.new(len, 12, 14), CFrame.new(x + len / 2, 6, 70), C_PAD, Enum.Material.Metal)
	part(gaps, "SegmentEdge" .. i, Vector3.new(0.4, 0.3, 14), CFrame.new(x + len - 0.2, 12.15, 70), C_AMBER, Enum.Material.Neon, { CanCollide = false })
	if gapSizes[i] then
		label(gaps, seg, string.format("GAP %d →", gapSizes[i]), 9, C_AMBER)
		x += len + gapSizes[i]
	else
		label(gaps, seg, "COURSE END", 9, C_GREEN)
	end
end
-- Dummies (native R6 rigs)
local dummies = Instance.new("Folder")
dummies.Name = "Dummies"
dummies.Parent = ROOT
local function r6(name: string, cf: CFrame, color: Color3, scale: number?): Model
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = name
	local function p(n: string, size: Vector3, off: CFrame, col: Color3, collide: boolean)
		local q = Instance.new("Part")
		q.Name = n
		q.Size = size * s
		q.CFrame = cf * CFrame.new(off.Position * s) * (off - off.Position)
		q.Color = col
		q.Material = Enum.Material.SmoothPlastic
		q.CanCollide = collide
		q.TopSurface = Enum.SurfaceType.Smooth
		q.BottomSurface = Enum.SurfaceType.Smooth
		q.Parent = m
		count += 1
		return q
	end
	local hrp = p("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), color, false)
	hrp.Transparency = 1
	local torso = p("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), color, true)
	local head = p("Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), Color3.fromRGB(230, 230, 235), true)
	local la = p("Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), color, false)
	local ra = p("Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), color, false)
	local ll = p("Left Leg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), Color3.fromRGB(40, 44, 60), false)
	local rl = p("Right Leg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), Color3.fromRGB(40, 44, 60), false)
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local function motor(n: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local mo = Instance.new("Motor6D")
		mo.Name = n
		mo.Part0 = p0
		mo.Part1 = p1
		mo.C0 = CFrame.new(c0.Position * s) * (c0 - c0.Position)
		mo.C1 = CFrame.new(c1.Position * s) * (c1 - c1.Position)
		mo.Parent = p0
	end
	local R = CFrame.Angles(-math.pi / 2, 0, math.pi)
	motor("RootJoint", hrp, torso, R, R)
	motor("Neck", torso, head, CFrame.new(0, 1, 0) * R, CFrame.new(0, -0.5, 0) * R)
	motor("Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0))
	motor("Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	motor("Right Hip", torso, rl, CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0))
	motor("Left Hip", torso, ll, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayName = name
	hum.WalkSpeed = 10
	hum.Parent = m
	m.PrimaryPart = hrp
	return m
end

local function npc(name: string, cf: CFrame, color: Color3, patrolA: Vector3?, patrolB: Vector3?): Model
	local m = r6(name, cf, color)
	m:SetAttribute("HackTargetId", "npc:" .. string.lower(name))
	if patrolA and patrolB then
		m:SetAttribute("PatrolA", patrolA)
		m:SetAttribute("PatrolB", patrolB)
	end
	CollectionService:AddTag(m, "HackTarget")
	m.Parent = dummies
	return m
end
local ICE = Color3.fromRGB(90, 120, 170)
npc("Dummy-A", CFrame.new(450, 0, -50) * CFrame.Angles(0, math.pi, 0), ICE)
part(dummies, "WallBehindA", Vector3.new(24, 10, 1), CFrame.new(450, 5, -28), C_PAD, Enum.Material.Metal)
npc("Dummy-B", CFrame.new(420, 0, -75), Color3.fromRGB(150, 100, 170), Vector3.new(415, 0, -75), Vector3.new(485, 0, -75))
local ledge = part(dummies, "Ledge", Vector3.new(16, 12, 16), CFrame.new(505, 6, -55), C_PAD, Enum.Material.Metal)
label(dummies, ledge, "LEDGE · fling a dummy off a height", 8, C_MAG)
npc("Dummy-C", CFrame.new(505, 12, -55) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(170, 120, 80))
-- landing test pieces near the ledge
do
	local w = Instance.new("WedgePart")
	w.Name = "LandingSlope"
	w.Size = Vector3.new(12, 6, 16)
	w.CFrame = CFrame.new(505, 3, -30)
	w.Anchored = true
	w.Color = C_PAD
	w.Parent = dummies
	count += 1
end
part(dummies, "LandingBeam", Vector3.new(30, 1, 2), CFrame.new(530, 5, -40), C_PAD, Enum.Material.Metal)
part(dummies, "LandingCrate", Vector3.new(6, 6, 6), CFrame.new(525, 3, -20), Color3.fromRGB(120, 90, 50), Enum.Material.Wood)

-- Boss arena
local arena = Instance.new("Folder")
arena.Name = "BossArena"
arena.Parent = ROOT
local floor = part(arena, "ArenaFloor", Vector3.new(0.4, 150, 150), CFrame.new(450, 0.2, 180) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(36, 30, 40), Enum.Material.Slate, { Shape = Enum.PartType.Cylinder })
part(arena, "ArenaRing", Vector3.new(0.3, 151, 151), CFrame.new(450, 0.25, 180) * CFrame.Angles(0, 0, math.rad(90)), C_MAG, Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, CanCollide = false, Transparency = 0.85 })
for i, off in { Vector3.new(-30, 0, -10), Vector3.new(30, 0, -10), Vector3.new(0, 0, -35) } do
	part(arena, "CoverPillar" .. i, Vector3.new(6, 14, 6), CFrame.new(450 + off.X, 7, 180 + off.Z), C_PAD, Enum.Material.Concrete)
end
-- Conductor placeholder: scaled native humanoid, anchored, welded
local boss = r6("Conductor", CFrame.new(450, 0, 205) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 20, 30), 2.6)
for _, p in boss:GetDescendants() do
	if p:IsA("BasePart") then
		p.Anchored = true
	end
end
local torso = boss:FindFirstChild("Torso") :: BasePart
local core = Instance.new("Part")
core.Name = "CoreLight"
core.Shape = Enum.PartType.Ball
core.Size = Vector3.new(1.6, 1.6, 1.6)
core.Material = Enum.Material.Neon
core.Color = Color3.fromRGB(255, 111, 97)
core.Anchored = true
core.CanCollide = false
core.CFrame = torso.CFrame * CFrame.new(0, 0.6, -torso.Size.Z / 2 - 0.3)
core.Parent = boss
local clamp = Instance.new("Part")
clamp.Name = "ClampArm"
clamp.Size = Vector3.new(3.4, 2.6, 4)
clamp.Material = Enum.Material.Metal
clamp.Color = Color3.fromRGB(60, 62, 70)
clamp.Anchored = true
clamp.CanCollide = false
local ra = boss:FindFirstChild("Right Arm") :: BasePart
clamp.CFrame = ra.CFrame * CFrame.new(0, -ra.Size.Y / 2, -0.5)
clamp.Parent = boss
local hum = boss:FindFirstChildOfClass("Humanoid") :: Humanoid
hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
hum.WalkSpeed = 0
hum.MaxHealth = 1e6
hum.Health = 1e6
boss:SetAttribute("HackTargetId", "boss:conductor")
boss:SetAttribute("BossChallenge", "ResistanceBattle")
boss:SetAttribute("ArenaFloorY", 0.4)
CollectionService:AddTag(boss, "HackTarget")
CollectionService:AddTag(boss, "HackBoss")
boss.Parent = arena
-- Mode consoles at the arena entrance
for i, m in { { "ResistanceBattle", "RESISTANCE BATTLE" }, { "InputChase", "INPUT CHASE" }, { "SignalLock", "SIGNAL LOCK" } } do
	local c = part(arena, "ModeConsole_" .. m[1], Vector3.new(4, 3, 2), CFrame.new(435 + (i - 1) * 15, 1.5, 98), Color3.fromRGB(31, 37, 55), Enum.Material.Metal)
	c:SetAttribute("Mode", m[1])
	c:SetAttribute("Label", m[2])
	CollectionService:AddTag(c, "HackModeConsole")
	part(arena, "ConsoleScreen" .. i, Vector3.new(3.4, 1.6, 0.2), CFrame.new(435 + (i - 1) * 15, 2.2, 96.9), C_CYAN, Enum.Material.Neon, { CanCollide = false })
	label(arena, c, m[2], 3.5, C_CYAN)
end

-- WORLD_EXE containers for the unchanged game bootstrap
local we = Instance.new("Folder")
we.Name = "WORLD_EXE"
we.Parent = workspace
local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = we
local lobby = Instance.new("Folder")
lobby.Name = "Lobby"
lobby.Parent = we
local ls = Instance.new("SpawnLocation")
ls.Name = "LobbySpawn"
ls.Size = Vector3.new(10, 0.4, 10)
ls.CFrame = CFrame.new(450, 0.6, -108)
ls.Anchored = true
ls.Neutral = true
ls.Enabled = true
ls.Duration = 0
ls.Color = Color3.fromRGB(0, 190, 170)
ls.Material = Enum.Material.Neon
ls.Transparency = 0.5
ls.Parent = lobby
CollectionService:AddTag(ls, "LobbySpawn")
part(map, "MatchFloor", Vector3.new(60, 2, 60), CFrame.new(0, -1, 0), C_PAD, Enum.Material.Concrete)
for i, off in { Vector3.new(-12, 0, -12), Vector3.new(12, 0, -12), Vector3.new(-12, 0, 12), Vector3.new(12, 0, 12) } do
	local s = Instance.new("SpawnLocation")
	s.Name = "MatchPad" .. i
	s.Size = Vector3.new(6, 0.4, 6)
	s.CFrame = CFrame.new(off.X, 0.2, off.Z)
	s.Anchored = true
	s.Neutral = true
	s.Enabled = true
	s.Duration = 0
	s:SetAttribute("SpawnId", "MP" .. i)
	s:SetAttribute("Zone", "CentralCore")
	s.Parent = map
	CollectionService:AddTag(s, "ArenaSpawn")
end

-- Place settings
workspace:SetAttribute("WORLD_EXE_HackPrototype", true)
workspace.StreamingEnabled = false
local L = game:GetService("Lighting")
L.ClockTime = 15
L.Brightness = 2
L.Ambient = Color3.fromRGB(70, 74, 90)
L.OutdoorAmbient = Color3.fromRGB(110, 115, 135)
-- Studio-only: block automatic solo matches (set to 1 to test the Architect UI arbitration)
local sssRoot = game:GetService("ServerScriptService"):FindFirstChild("WORLD_EXE")
if sssRoot then
	sssRoot:SetAttribute("StudioMinPlayers", 99)
end
return "built " .. count .. " parts"
