-- WORLD.EXE Phase 8A-2a builder, step 3: Central Core transformation.
-- Containment vessel under the plaza (walls inset to ±92, Y -4..-90, fins, two outer galleries,
-- edge fascia); spoke girders and columns; supported mezzanine (clad corner pillars, knee braces,
-- deep edge girders) with collidable glass rails on its inner edge; gantry trusses with collidable
-- glass side rails, ramp stringers and hanger rods; a plaza-edge colonnade (12 collidable columns,
-- outside the flood volume) carrying a ring canopy at Y 60 with inward fins and four pool lights;
-- four plaza inlays. Nothing collidable enters flood volumes, bounce apex columns, supply columns,
-- spawn pads or the stabilizer radius (checked by 5_validate).
local W = assert(_G.W8A2A, "run 0_lib first")
local C, M, P, Strut = W.C, W.M, W.P, W.Strut
local A = "CentralCore"
local map = W.map
local coreSrc = map:WaitForChild("CentralCore")
local coreFolder = W.coreFolder or W.arch:FindFirstChild("CentralCore")
assert(coreFolder, "run 2_reactor first")

local vessel = W.Model(coreFolder, "ContainmentVessel", "Atomic")
local mezzM = W.Model(coreFolder, "MezzanineStructure", "Atomic")
local gantry = W.Model(coreFolder, "GantryTrusses", "Atomic")
local colon = W.Model(coreFolder, "ColonnadeCanopy", "Atomic")
local dress = W.Model(coreFolder, "Dressing", "Default")

local SIDES = W.SIDES
local sideCF = W.sideCF

-- 1. Containment vessel under the plaza.
for _, key in { "N", "E", "S", "W" } do
	local s = SIDES[key]
	P(A, vessel, "VesselUpper_" .. key, Vector3.new(184, 42, 6), sideCF(s, 0, -25, 92), C.Navy2, M.Concrete)
	P(A, vessel, "VesselLower_" .. key, Vector3.new(184, 44, 6), sideCF(s, 0, -68, 92), C.Navy1, M.Concrete)
	P(A, vessel, "Fascia_" .. key, Vector3.new(204, 6, 3), sideCF(s, 0, -7, 99), C.SteelLt, M.Metal)
	for _, u in { -66, 0, 66 } do
		P(A, vessel, "VesselFin_" .. key .. u, Vector3.new(3, 84, 10), sideCF(s, u, -48, 97), C.Steel, M.Metal)
	end
	for _, y in { -30, -60 } do
		P(A, vessel, "Gallery_" .. key .. y, Vector3.new(208, 1, 6), sideCF(s, 0, y, 101), C.Steel, M.DiamondPlate)
	end
	P(A, vessel, "VesselIndicator_" .. key, Vector3.new(120, 0.6, 0.3), sideCF(s, 0, -33, 95.2), C.Cyan, M.Neon)
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		P(A, vessel, "VesselChamfer", Vector3.new(14, 86, 6), CFrame.new(sx * 89, -47, sz * 89) * CFrame.Angles(0, math.rad(45), 0), C.Navy2, M.Concrete)
	end
end

-- 2. Spoke girders and end columns (spokes: ±100..±140, 24 wide, Y -4..0).
for _, key in { "N", "E", "S", "W" } do
	local s = SIDES[key]
	P(A, vessel, "SpokeGirder_" .. key, Vector3.new(20, 6, 40), sideCF(s, 0, -7, 120), C.Navy2, M.Metal)
	for _, u in { -8, 8 } do
		P(A, vessel, "SpokeColumn_" .. key .. u, Vector3.new(5, 80, 5), sideCF(s, u, -50, 136), C.Steel, M.Metal)
	end
end
-- Gantry bridge supports (beside the spokes, never on them).
for _, x in { -16, 16 } do
	P(A, gantry, "NBridgeColumn" .. x, Vector3.new(4, 108, 4), CFrame.new(x, -36, -120), C.Steel, M.Metal)
end
P(A, gantry, "NBridgeCrossbeam", Vector3.new(36, 3, 4), CFrame.new(0, 19.5, -120), C.Navy2, M.Metal)
for _, z in { -16, 16 } do
	P(A, gantry, "EBridgeColumn" .. z, Vector3.new(4, 132, 4), CFrame.new(128, -24, z), C.Steel, M.Metal)
end
P(A, gantry, "EBridgeCrossbeam", Vector3.new(4, 3, 36), CFrame.new(128, 43.5, 0), C.Navy2, M.Metal)

-- 3. Mezzanine structure (deck Y 22..24, ring between 40 and 55; corner pillars 3x3 at ±47.5).
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local x, z = sx * 47.5, sz * 47.5
		P(A, mezzM, "PillarCladding", Vector3.new(5, 21, 5), CFrame.new(x, 10.5, z), C.Steel, M.Metal)
		P(A, mezzM, "PillarCapital", Vector3.new(7, 1.5, 7), CFrame.new(x, 21.25, z), C.SteelLt, M.Metal)
		Strut(A, mezzM, "KneeBraceX", Vector3.new(x, 14, z), Vector3.new(x - sx * 12, 21.5, z), 1.5, 2, C.Navy2, M.Metal)
		Strut(A, mezzM, "KneeBraceZ", Vector3.new(x, 14, z), Vector3.new(x, 21.5, z - sz * 12), 1.5, 2, C.Navy2, M.Metal)
	end
end
for _, key in { "N", "E", "S", "W" } do
	local s = SIDES[key]
	for _, d in { 41, 54 } do
		P(A, mezzM, "DeckGirder_" .. key .. d, Vector3.new(110, 3, 2), sideCF(s, 0, 20.5, d), C.Navy2, M.Metal)
	end
	-- Collidable glass rails on the inner edge (gap at the middle for drop-downs; corners hold
	-- the buttress plinths).
	for _, span in { { -36, -6 }, { 6, 36 } } do
		local u = (span[1] + span[2]) / 2
		local len = span[2] - span[1]
		P(A, mezzM, "InnerRail_" .. key .. u, Vector3.new(len, 3, 0.4), sideCF(s, u, 25.5, 40.5), C.Glass, M.Glass, { collide = true, transparency = 0.55, edgeRail = true })
		P(A, mezzM, "InnerRailCap_" .. key .. u, Vector3.new(len, 0.3, 0.5), sideCF(s, u, 27.15, 40.5), C.Cyan, M.Neon)
	end
end

-- 4. Gantry trusses and rails.
-- North bridge: deck x ±6, Y 22..24, z -55..-146.
for _, x in { -5.8, 5.8 } do
	P(A, gantry, "NRail" .. x, Vector3.new(0.4, 3, 85), CFrame.new(x, 25.5, -100.5), C.Glass, M.Glass, { collide = true, transparency = 0.55, edgeRail = true })
	P(A, gantry, "NRailCap" .. x, Vector3.new(0.5, 0.3, 85), CFrame.new(x, 27.15, -100.5), C.Cyan, M.Neon)
	P(A, gantry, "NChord" .. x, Vector3.new(1.5, 1.5, 91), CFrame.new(x, 16, -100.5), C.Steel, M.Metal)
end
for k = 0, 3 do
	P(A, gantry, "NWeb" .. k, Vector3.new(12, 6, 1), CFrame.new(0, 19, -66 - k * 23), C.Navy2, M.Metal)
end
-- East bridge: deck x 115..160, Y 46..48, z ±6.
for _, z in { -5.8, 5.8 } do
	P(A, gantry, "ERail" .. z, Vector3.new(41, 3, 0.4), CFrame.new(137.5, 49.5, z), C.Glass, M.Glass, { collide = true, transparency = 0.55, edgeRail = true })
	P(A, gantry, "ERailCap" .. z, Vector3.new(41, 0.3, 0.5), CFrame.new(137.5, 51.15, z), C.Cyan, M.Neon)
	P(A, gantry, "EChord" .. z, Vector3.new(45, 1.5, 1.5), CFrame.new(137.5, 40, z), C.Steel, M.Metal)
end
for k = 0, 3 do
	P(A, gantry, "EWeb" .. k, Vector3.new(1, 6, 12), CFrame.new(120 + k * 12, 43, 0), C.Navy2, M.Metal)
end
-- Ramp stringers (under the three ramps) and two hanger rods from the canopy to the east ramp.
for _, rn in { "Gantry_E_Ramp", "Ramp_MezzW", "Ramp_MezzS" } do
	local r = coreSrc:FindFirstChild(rn) :: BasePart
	assert(r, "missing " .. rn)
	P(A, gantry, "Stringer_" .. rn, Vector3.new(r.Size.X - 1, 2, r.Size.Z), r.CFrame * CFrame.new(0, -2.5, 0), C.Navy2, M.Metal)
end
do
	local ramp = coreSrc:FindFirstChild("Gantry_E_Ramp") :: BasePart
	-- Find the ramp's local Z where its centreline is at world x = 97.
	local p0 = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, 0))
	local p1 = ramp.CFrame:PointToWorldSpace(Vector3.new(0, 0, 1))
	local lz = (97 - p0.X) / (p1.X - p0.X)
	for _, lx in { -5.5, 5.5 } do
		local q = ramp.CFrame:PointToWorldSpace(Vector3.new(lx, -1, lz))
		Strut(A, gantry, "Hanger" .. lx, q, Vector3.new(q.X, 60, q.Z), 0.6, 0.6, C.SteelLt, M.Metal)
	end
end

-- 5. Colonnade (8 collidable columns at the plaza edge, outside the flood volume) + ring canopy.
--    Columns at ±40 on the N/S edges were removed: they blocked drone links WP_C1..C4 -> WP_SN/SS.
local colSlots = { N = { -80, 80 }, S = { -80, 80 }, E = { -80, 80 }, W = { -80, 80 } }
for _, key in { "N", "E", "S", "W" } do
	local s = SIDES[key]
	for _, u in colSlots[key] do
		P(A, colon, "Column_" .. key .. u, Vector3.new(4, 60, 4), sideCF(s, u, 30, 97), C.Steel, M.Metal, { collide = true, shadow = true })
	end
	local girder = P(A, colon, "CanopyGirder_" .. key, Vector3.new(200, 4, 6), sideCF(s, 0, 62, 97), C.Navy2, M.Metal, { shadow = true })
	W.Light(A, girder, "SpotLight", { Face = Enum.NormalId.Bottom, Angle = 70, Range = 50, Brightness = 1.6, Color = C.Warm, Shadows = false })
	local finSlots = if key == "S" then { -90, -60, -30, 30, 90 } else { -90, -60, -30, 30, 60, 90 }
	for _, u in finSlots do
		P(A, colon, "CanopyFin_" .. key .. u, Vector3.new(2, 3, 14), sideCF(s, u, 61.5, 87), C.Steel, M.Metal)
	end
end

-- 6. Plaza inlays on the diagonals (flush, decorative metal, outside the mezzanine).
for i, sgn in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
	local d = Vector3.new(sgn[1], 0, sgn[2]).Unit
	-- Stops at r 108, short of the corner spawn pads (r ~120).
	Strut(A, dress, "Inlay_" .. i, d * 74 + Vector3.new(0, 0.05, 0), d * 108 + Vector3.new(0, 0.05, 0), 1.5, 0.1, C.SteelLt, M.Metal)
end

local c = W.count(A)
return string.format("core built: parts=%d collide=%d lights=%d shadows=%d", c.parts, c.collide, c.lights, c.shadows)
