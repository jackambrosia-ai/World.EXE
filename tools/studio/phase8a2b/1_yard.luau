-- WORLD.EXE Phase 8A-2b step 1: Research Yard "Test Hangar" (Architecture.TestHangar).
-- Yard: x -260..-140, z -130..130, T0. DecayTile grid x -250..-150, z -50..50. Ring_W passes over at
-- x -237..-223, Y 22-24. Lab pods (8A-1 walls) at (-200, +-90).
-- * Four trussed portal frames span the yard east-west over the grid (legs on the W/E edge strips,
--   x -258 / -142, at z +-20 and +-46; top Y 50). The frames carry the skylight, the gantry-crane
--   runways (Y 41) and the hanger rods that suspend Ring_W over the yard.
-- * Lab pods: roof, door headers, observation window, console desk, status display, warning module,
--   instrument mast. Catwalk support columns at the yard's outer edges. West silo cluster (outside
--   the bounds). Identity: steel truss, light lab panels, restrained violet.
local W = assert(_G.W8A2B, "run 0_lib first")
local C, M = W.C, W.M
local A = "ResearchYard"
local d, S, D = W.District("TestHangar")
local V = Vector3.new

-- Portal frames.
local FRAMES = { -46, -20, 20, 46 }
local XW, XE = -258, -142
for i, z in FRAMES do
	local f = W.Model(S, "PortalFrame_" .. i, "Atomic")
	for _, x in { XW, XE } do
		W.Box(A, f, "FrameLeg", V(x - 1.25, 0, z - 1.25), V(x + 1.25, 50, z + 1.25), C.Steel, M.Metal, { role = "FloorStructure", support = true })
	end
	W.Box(A, f, "TopChord", V(XW - 1.5, 47, z - 0.9), V(XE + 1.5, 50, z + 0.9), C.SteelLt, M.Metal, { support = true })
	W.Box(A, f, "BottomChord", V(XW + 1.25, 39.5, z - 0.6), V(XE - 1.25, 41, z + 0.6), C.Steel, M.Metal, { support = true })
	local xs = { XW, -229, -200, -171, XE }
	for k = 1, 4 do
		local up = k % 2 == 1
		local a = V(xs[k], if up then 41 else 47, z)
		local b = V(xs[k + 1], if up then 47 else 41, z)
		W.Strut(A, f, "Web", a, b, 0.8, 0.8, C.SteelLt, M.Metal)
	end
	-- Ring_W hangers: two rods beside the deck edges and a cross bearer under the deck.
	W.Box(A, f, "RingHanger", V(-237.7, 21, z - 0.3), V(-237.1, 39.5, z + 0.3), C.SteelLt, M.Metal, { support = true })
	W.Box(A, f, "RingHanger", V(-222.9, 21, z - 0.3), V(-222.3, 39.5, z + 0.3), C.SteelLt, M.Metal, { support = true })
	W.Box(A, f, "RingBearer", V(-237.7, 21, z - 0.6), V(-222.3, 22, z + 0.6), C.Steel, M.Metal, { support = true })
end

-- Skylight: three glazed bays and three purlins on the top chords.
for k = 1, 3 do
	local z0, z1 = FRAMES[k], FRAMES[k + 1]
	W.Box(A, S, "Skylight", V(XW, 50, z0 + 0.9), V(XE, 50.4, z1 - 0.9), C.GlassDk, M.Glass, { transparency = 0.55 })
end
for _, x in { XW, -200, XE } do
	W.Box(A, S, "Purlin", V(x - 0.6, 50, -46), V(x + 0.6, 51.2, 46), C.Steel, M.Metal)
end

-- Gantry crane (parked at z -33, clear of the bounce-apex and supply columns).
local crane = W.Model(S, "GantryCrane", "Atomic")
for _, x in { -255, -145 } do
	W.Box(A, crane, "Runway", V(x - 0.8, 41, -46), V(x + 0.8, 42.5, 46), C.Steel, M.Metal)
end
local bridge = W.Box(A, crane, "CraneBridge", V(-255, 39, -34.2), V(-145, 41, -31.8), C.LabPanel, M.Metal)
W.Box(A, crane, "Trolley", V(-208, 37, -36), V(-202, 39, -30), C.Steel, M.Metal)
W.Box(A, crane, "HoistCable", V(-205.15, 30, -33.15), V(-204.85, 37, -32.85), C.Charcoal, M.Metal)
W.Box(A, crane, "HookBlock", V(-206, 28, -34), V(-204, 30, -32), C.Charcoal, M.Metal)
local warn = W.Box(A, crane, "CraneWarning", V(-206, 39.2, -34.4), V(-198, 39.6, -34.2), C.Amber, M.Neon, { reservedUse = "Warning" })
W.Light(A, warn, "PointLight", { Color = C.Amber, Range = 8, Brightness = 0.8 })
W.Light(A, bridge, "SpotLight", { Color = C.White, Range = 40, Brightness = 1.2, Angle = 70, Face = Enum.NormalId.Bottom })

-- Lab pods. sgn = -1 north pod (back wall Wall_N z -104), +1 south pod (back wall Wall_S z 104).
for _, sgn in { -1, 1 } do
	local tag = if sgn < 0 then "N" else "S"
	local pod = W.Model(D, "LabPod_" .. tag, "Default")
	local back, front = 104 * sgn, 76 * sgn
	W.Box(A, pod, "PodRoof", V(-216, 12, back + sgn * 1), V(-184, 13, front - sgn * 1), C.LabPanel, M.SmoothPlastic)
	for _, x in { -214, -186 } do
		W.Box(A, pod, "DoorHeader", V(x - 1.2, 9.5, 86.5 * sgn), V(x + 1.2, 12, 93.5 * sgn), C.Steel, M.Metal)
	end
	-- Observation window on the grid-facing wall (decorative frame + glass, proud of the face).
	local wz = front - sgn * 1.15
	W.Box(A, pod, "WindowFrame", V(-207, 4.5, wz - 0.15), V(-193, 10.5, wz + 0.15), C.Charcoal, M.Metal)
	W.Box(A, pod, "WindowGlass", V(-206.4, 5.1, wz - 0.25), V(-193.6, 9.9, wz + 0.25), C.Glass, M.Glass, { transparency = 0.35 })
	-- Console desk against the back wall (collidable, adjacent to the wall).
	local dz = back - sgn * 1
	W.Box(A, pod, "ConsoleDesk", V(-205, 0, dz - sgn * 2.5), V(-195, 3, dz), C.Steel, M.Metal, { role = "FloorStructure" })
	local display = W.Box(A, pod, "StatusDisplay", V(-204, 4.5, dz - 0.1 * sgn), V(-196, 9, dz - 0.3 * sgn), C.Slate, M.Glass)
	for k, col in { C.Violet, C.Magenta, C.Cyan } do
		local x = -203 + k * 1.5
		W.Box(A, pod, "StatusBar", V(x, 5.2, dz - 0.35 * sgn), V(x + 0.5, 5.2 + k * 0.9, dz - 0.45 * sgn), col, M.Neon)
	end
	W.Light(A, display, "PointLight", { Color = C.Violet, Range = 14, Brightness = 1.1 })
	W.Box(A, pod, "WarningModule", V(-213.2, 8, 95 * sgn - 0.4), V(-212.6, 8.8, 95 * sgn + 0.4), C.Amber, M.Neon, { reservedUse = "Warning" })
	W.Box(A, pod, "InstrumentMast", V(-188.3, 13, back - sgn * 3.3), V(-187.7, 23, back - sgn * 2.7), C.SteelLt, M.Metal)
	W.P(A, pod, "MastBeacon", V(1, 1, 1), CFrame.new(-188, 23.5, back - sgn * 3), C.Violet, M.Neon, { shape = "Ball" })
end

-- Catwalk support columns at the yard's outer edges (under Catwalk_N / Catwalk_S).
for _, sgn in { -1, 1 } do
	for _, x in { -250, -200, -150 } do
		W.Box(A, S, "CatwalkColumn", V(x - 1, 0, 127 * sgn - 1), V(x + 1, 22, 127 * sgn + 1), C.Steel, M.Metal, { role = "FloorStructure", support = true })
	end
end

-- West silo cluster (outside the playable bounds, rising from the shaft).
local silos = W.Model(S, "SiloCluster", "Atomic")
local siloTop
for i, p in { V(-286, 0, -14), V(-286, 0, 14), V(-302, 0, 0) } do
	W.Cyl(A, silos, "Silo_" .. i, V(p.X, -27, p.Z), 126, 12, C.ConcreteDk, M.Concrete)
	siloTop = W.Cyl(A, silos, "SiloCap_" .. i, V(p.X, 37, p.Z), 2, 10, C.Steel, M.Metal)
	W.Cyl(A, silos, "SiloBand_" .. i, V(p.X, 18, p.Z), 1.5, 12.6, C.SteelLt, M.Metal)
end
W.Strut(A, silos, "SiloPipe", V(-280, -3, -14), V(-260.5, -3, -14), 1.6, 1.6, C.Steel, M.Metal)
W.Strut(A, silos, "SiloPipe", V(-280, -3, 14), V(-260.5, -3, 14), 1.6, 1.6, C.Steel, M.Metal)
W.Light(A, siloTop, "PointLight", { Color = C.Violet, Range = 16, Brightness = 1 })

local c = W.counts[A]
return string.format("TestHangar: %d parts, %d collidable, %d lights", c.parts, c.collide, c.lights)
