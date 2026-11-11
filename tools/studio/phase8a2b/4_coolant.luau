-- WORLD.EXE Phase 8A-2b step 4: Coolant Reservoir "Pump Station" (Architecture.PumpStation).
-- Rims at T0 around a basin (floor Y -10, x -75..75, z 155..245; FLOOD_RES volume). Pump towers at
-- (+-30, z 225), bridges Y 24 (x -75..-7 / 7..75, z 194..206) with the 14-stud zero-G gap between.
-- * Two part-built cooling towers (x +-150, z 298, Y -90..70), outside the floors and bounds: a
--   tiered hyperboloid silhouette with a dark throat and a teal glow.
-- * Pump hall on the east rim: back wall on the rim's void edge (BoundaryWall), cantilevered roof
--   (no front columns), three turbine casings (collidable, against the edge), exhausts, crane rail,
--   service panels. Open front facing the basin.
-- * Pipe runs at Y 32 (above the bridge-link and ring-ramp headroom) from the pump towers to the
--   hall and to a west intake unit, with flanges, valves and decorative pipe posts on the basin-wall tops.
-- * Pump-tower flanges and gauges, basin intake grates, knee braces under both bridges.
-- Rim rails are generated with the Outer Ring rails in step 5 (same void test).
local W = assert(_G.W8A2B, "run 0_lib first")
local C, M = W.C, W.M
local A = "CoolantReservoir"
local d, S, D = W.District("PumpStation")
local V = Vector3.new

-- Cooling towers.
local throat
for _, sgn in { -1, 1 } do
	local t = W.Model(S, "CoolingTower_" .. (if sgn < 0 then "W" else "E"), "Atomic")
	local x, z = 150 * sgn, 298
	for _, tier in { { -90, -30, 44 }, { -30, 10, 38 }, { 10, 40, 32 }, { 40, 64, 34 }, { 64, 70, 38 } } do
		W.Cyl(A, t, "TowerShell", V(x, (tier[1] + tier[2]) / 2, z), tier[2] - tier[1], tier[3], if tier[3] == 38 and tier[1] == 64 then C.SteelLt else C.ConcreteDk, M.Concrete, { support = true })
	end
	throat = W.Cyl(A, t, "TowerThroat", V(x, 70.05, z), 0.1, 34, C.Slate, M.SmoothPlastic)
	W.Cyl(A, t, "TowerBand", V(x, 10, z), 1.2, 38.8, C.Steel, M.Metal)
	W.Cyl(A, t, "TowerBand", V(x, 40, z), 1.2, 32.8, C.Steel, M.Metal)
	W.Light(A, throat, "PointLight", { Color = C.Teal, Range = 24, Brightness = 1.2 })
end

-- Pump hall on the east rim (x 112..131, z 186..222).
local hall = W.Model(S, "PumpHall", "Atomic")
W.Box(A, hall, "HallBackWall", V(130.1, -4, 186), V(131.5, 20, 222), C.Navy1, M.Concrete, { role = "BoundaryWall", support = true })
local hallRoof = W.Box(A, hall, "HallRoof", V(112, 18.5, 185), V(131.5, 19.5, 222.5), C.Steel, M.Metal)
for _, z in { 189, 204, 219 } do
	W.Strut(A, hall, "RoofBracket", V(130, 10, z), V(113.5, 18.4, z), 0.8, 0.8, C.SteelLt, M.Metal, { support = true })
end
for _, z in { 192, 204, 216 } do
	W.P(A, hall, "TurbineCasing", V(8, 6, 6), CFrame.new(124, 3, z), C.TealDk, M.Metal, { shape = "Cylinder", role = "FloorStructure" })
	for _, x in { 120.2, 127.8 } do
		W.P(A, hall, "TurbineFlange", V(0.6, 7, 7), CFrame.new(x, 3, z), C.SteelLt, M.Metal, { shape = "Cylinder" })
	end
	W.Cyl(A, hall, "Exhaust", V(124, 13, z), 13, 1.4, C.Steel, M.Metal)
end
W.Box(A, hall, "CraneRail", V(126, 17, 186), V(127, 18, 222), C.Steel, M.Metal)
W.Box(A, hall, "HallCrane", V(122, 15.5, 200), V(129, 17, 202), C.SteelLt, M.Metal)
for k, z in { 196, 210 } do
	W.Box(A, hall, "ServicePanel", V(129.2, 3, z - 2), V(129.55, 7, z + 2), C.Slate, M.Glass)
	W.Box(A, hall, "PanelBar", V(129.0, 3.5, z - 1.5), V(129.2, 3.5 + k * 1.2, z - 1.1), C.Teal, M.Neon)
end
W.Light(A, hallRoof, "PointLight", { Color = C.Teal, Range = 20, Brightness = 1 })

-- Pipe runs (Y 32) from the pump towers: east to the hall roof, west to an intake unit.
local pipes = W.Model(D, "PipeRuns", "Default")
for _, sgn in { -1, 1 } do
	-- East run drops onto the hall roof (Y 19.5); west run drops into the intake unit (Y 8).
	local x0, x1 = 37 * sgn, if sgn > 0 then 116 else -127
	local dropTo = if sgn > 0 then 19.3 else 8
	W.Strut(A, pipes, "PipeRun", V(x0, 32, 216), V(x1, 32, 216), 2, 2, C.SteelLt, M.Metal)
	W.Box(A, pipes, "PipeElbow", V(x1 - 1.3, 30.7, 214.7), V(x1 + 1.3, 33.3, 217.3), C.Steel, M.Metal)
	W.Cyl(A, pipes, "PipeDrop", V(x1, (dropTo + 30.7) / 2, 216), 30.7 - dropTo, 2, C.SteelLt, M.Metal)
	for _, xf in { 50, 90, 104 } do
		W.P(A, pipes, "PipeFlange", V(0.5, 2.8, 2.8), CFrame.new(xf * sgn, 32, 216), C.Steel, M.Metal, { shape = "Cylinder" })
	end
	W.P(A, pipes, "ValveWheel", V(0.3, 2.2, 2.2), CFrame.new(70 * sgn, 33.6, 216) * CFrame.Angles(0, 0, math.rad(90)), C.TealDk, M.Metal, { shape = "Cylinder" })
	-- Decorative post on the basin-wall top (a collidable post would cross the MAGNETIC crate lane).
	W.Box(A, pipes, "PipePost", V(76 * sgn - 0.6, 0, 215.4), V(76 * sgn + 0.6, 31, 216.6), C.Steel, M.Metal, { support = true })
end
W.Box(A, pipes, "IntakeUnit", V(-129.4, 0, 210), V(-125, 8, 222), C.TealDk, M.Metal, { role = "FloorStructure" })
W.Box(A, pipes, "IntakeGrille", V(-125, 2, 212), V(-124.7, 6, 220), C.Charcoal, M.DiamondPlate)

-- Pump-tower flanges and gauges.
for _, sgn in { -1, 1 } do
	for _, y in { -4, 16 } do
		W.Cyl(A, D, "PumpFlange", V(30 * sgn, y, 225), 0.8, 16, C.SteelLt, M.Metal)
	end
	W.Box(A, D, "PumpGauge", V(30 * sgn - 1, 8, 217.6), V(30 * sgn + 1, 10, 217.9), C.Static, M.Glass)
	W.Box(A, D, "PumpValve", V(30 * sgn - 0.4, 2, 216.8), V(30 * sgn + 0.4, 4, 217.9), C.TealDk, M.Metal)
end

-- Basin intake grates (decorative, on the basin walls) with low teal light.
for _, z in { 155.1, 244.9 } do
	for _, x in { -40, 40 } do
		local g = W.Box(A, D, "IntakeGrate", V(x - 4, -9, z - 0.15), V(x + 4, -6, z + 0.15), C.Charcoal, M.DiamondPlate)
		if z > 200 and x < 0 then
			W.Light(A, g, "PointLight", { Color = C.Teal, Range = 18, Brightness = 0.8 })
		end
	end
end

-- Knee braces under both bridges (from the basin wall tops).
for _, sgn in { -1, 1 } do
	for _, z in { 197, 203 } do
		W.Strut(A, S, "BridgeBrace", V(76 * sgn, 0, z), V(35 * sgn, 21.5, z), 1, 1, C.Steel, M.Metal, { support = true })
	end
end

local c = W.counts[A]
return string.format("PumpStation: %d parts, %d collidable, %d lights", c.parts, c.collide, c.lights)
