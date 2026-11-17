--!nonstrict
-- Wrist-hacking prototype: adds the WALL RUN test lane (Rev 15g) to the PROTOTYPE place only (Edit mode).
-- Two parallel 70-stud walls, 20 studs apart, on open ground west of the launch area (checked clear): jump along one wall
-- to wall-run, Space to wall-jump across to the other; plus a 24-stud block at (330,140) to run around
-- corners. Idempotent (rebuilds HackProto.WallRunLane).
assert(string.find(game.Name, "HackPrototype", 1, true), "prototype place only")
local root = workspace:FindFirstChild("HackProto")
assert(root, "HackProto folder missing (run hp_20_build_place first)")
local old = root:FindFirstChild("WallRunLane")
if old then
	old:Destroy()
end
local lane = Instance.new("Folder")
lane.Name = "WallRunLane"
local WALL = Color3.fromRGB(24, 28, 44)
local TRIM = Color3.fromRGB(110, 225, 255)
local function part(name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = lane
	return p
end
for i, x in { 320, 340 } do
	part("WallRunWall" .. i, Vector3.new(2, 16, 70), CFrame.new(x, 8, 50), WALL, Enum.Material.Concrete)
	local trim = part("WallRunTrim" .. i, Vector3.new(2.2, 0.4, 70), CFrame.new(x, 16.2, 50), TRIM, Enum.Material.Neon)
	trim.CanCollide = false
	-- a faint guide stripe at running height on both faces
	for _, side in { -1, 1 } do
		local s = part("WallRunStripe" .. i, Vector3.new(0.1, 0.25, 70), CFrame.new(x + side * 1.06, 4.5, 50), TRIM, Enum.Material.Neon)
		s.CanCollide = false
		s.Transparency = 0.4
	end
end
-- a free-standing building block to run AROUND (MOV-03 wraps around building corners)
part("WallRunBlock", Vector3.new(24, 16, 24), CFrame.new(330, 8, 140), WALL, Enum.Material.Concrete)
-- thin neon edge outline on the top (a full neon lid glowed too brightly)
for _, e in { { Vector3.new(24.4, 0.3, 0.3), Vector3.new(0, 0, 12) }, { Vector3.new(24.4, 0.3, 0.3), Vector3.new(0, 0, -12) },
	{ Vector3.new(0.3, 0.3, 24.4), Vector3.new(12, 0, 0) }, { Vector3.new(0.3, 0.3, 24.4), Vector3.new(-12, 0, 0) } } do
	local edge = part("WallRunBlockEdge", e[1], CFrame.new(Vector3.new(330, 16.1, 140) + e[2]), TRIM, Enum.Material.Neon)
	edge.CanCollide = false
end
local sign = part("WallRunSign", Vector3.new(1, 1, 1), CFrame.new(330, 18.5, 14), WALL)
sign.Transparency = 1
sign.CanCollide = false
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(320, 40)
bb.AlwaysOnTop = false
bb.MaxDistance = 220
bb.Parent = sign
local t = Instance.new("TextLabel")
t.Size = UDim2.fromScale(1, 1)
t.BackgroundTransparency = 1
t.Font = Enum.Font.GothamBold
t.TextSize = 18
t.TextColor3 = TRIM
t.TextStrokeTransparency = 0.4
t.Text = "WALL RUN · jump along a wall · Space = wall jump"
t.Parent = bb
lane.Parent = root
return "WallRunLane built: 2 walls at x=320 and x=340, z 15..85, 16 tall; corner block 24x16x24 at (330, 140)"
