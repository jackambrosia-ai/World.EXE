-- WORLD.EXE Phase 8A-2a builder, step 1: Terraced Containment Hall (Map.Megastructure).
-- Terrace plinth ±320 (Y -90..60) + terrace deck; upper wall ±400 (Y 60..180) with pilasters,
-- seams, a violet band, deep windows and a lobby notch (south, x ±40, Y 140..180); chamfered corner
-- towers; 8 box-truss ceiling ribs to a hub ring at Y 240; 12 terrace machinery towers (tops <= Y 150);
-- 8 far silhouettes behind the windows; a slate shaft floor at Y -90 with a faint grid.
-- Streaming: Silhouette = Persistent (enclosure + ribs + hub); Detail = Default.
local W = assert(_G.W8A2A, "run 0_lib first")
local C, M, P, Strut = W.C, W.M, W.P, W.Strut
local A = "Megastructure"

local sil = W.Model(W.mega, "Silhouette", "Persistent")
local det = W.Model(W.mega, "Detail", "Default")

local SIDES = {
	N = { n = Vector3.new(0, 0, -1), t = Vector3.new(1, 0, 0) },
	S = { n = Vector3.new(0, 0, 1), t = Vector3.new(1, 0, 0) },
	E = { n = Vector3.new(1, 0, 0), t = Vector3.new(0, 0, 1) },
	W = { n = Vector3.new(-1, 0, 0), t = Vector3.new(0, 0, 1) },
}
local ORDER = { "N", "E", "S", "W" }
-- CFrame on a side: local X = along the wall, Y = up, Z = perpendicular to the wall (right-handed).
local function sideCF(s, u: number, y: number, d: number): CFrame
	local pos = s.n * d + s.t * u + Vector3.new(0, y, 0)
	return CFrame.fromMatrix(pos, s.t, Vector3.yAxis)
end
W.sideCF = sideCF
W.SIDES = SIDES

-- 1. Terrace plinth (inner face 320, 12 thick, Y -90..60), 10 slabs per side with value variation.
local PL_IN, PL_T = 320, 12
for _, key in ORDER do
	local s = SIDES[key]
	local half = PL_IN + PL_T
	local n = 10
	local w = (2 * half) / n
	for i = 0, n - 1 do
		local u = -half + w * (i + 0.5)
		local recess = if i % 2 == 0 then 0 else 1.5
		P(A, sil, "Plinth_" .. key .. "_" .. (i + 1), Vector3.new(w - 0.4, 150, PL_T), sideCF(s, u, -15, PL_IN + PL_T / 2 + recess), if i % 2 == 0 then C.Concrete else C.ConcreteDk, M.Concrete)
	end
	P(A, sil, "PlinthCoping_" .. key, Vector3.new(2 * half + 16, 3, 16), sideCF(s, 0, 61.5, PL_IN + 6), C.SteelLt, M.Concrete)
	P(A, det, "PlinthBand_" .. key, Vector3.new(2 * half, 3, 1), sideCF(s, 0, 0, PL_IN - 0.4), C.Slate, M.Metal)
	-- Terrace deck between the plinth and the upper wall (Y 56..60).
	P(A, det, "TerraceDeck_" .. key, Vector3.new(800, 4, 68), sideCF(s, 0, 58, 366), C.Navy1, M.Concrete)
end

-- 2. Upper wall (inner face 400, 14 thick, Y 60..180), deep windows, pilasters, seams, band.
local UW_IN, UW_T, UW_Y0, UW_Y1 = 400, 14, 60, 180
local UW_HALF = UW_IN + UW_T
local windows = { N = { 3, 10 }, E = { 4, 10 }, S = { 2, 11 }, W = { 3, 9 } } -- slab indices with deep windows
local windowAxes = {}
local function slabRun(key: string, from: number, to: number, n: number, startIndex: number, top: number?)
	local s = SIDES[key]
	local w = (to - from) / n
	for i = 0, n - 1 do
		local idx = startIndex + i
		local u = from + w * (i + 0.5)
		local y1 = top or UW_Y1
		local isWindow = table.find(windows[key], idx) ~= nil and top == nil
		local shade = if idx % 3 == 0 then C.Navy2 else C.Navy1
		if isWindow then
			-- Opening 70 tall x (w-8) wide with a 24-deep reveal.
			P(A, sil, "WinSill_" .. key .. idx, Vector3.new(w - 0.4, 25, UW_T), sideCF(s, u, UW_Y0 + 12.5, UW_IN + UW_T / 2), shade, M.Concrete)
			P(A, sil, "WinLintel_" .. key .. idx, Vector3.new(w - 0.4, 25, UW_T), sideCF(s, u, UW_Y1 - 12.5, UW_IN + UW_T / 2), shade, M.Concrete)
			for side = -1, 1, 2 do
				P(A, sil, "WinJamb_" .. key .. idx .. (if side < 0 then "L" else "R"), Vector3.new(4, 70, 24), sideCF(s, u + side * (w / 2 - 2), 120, UW_IN + 12), C.Navy0, M.Concrete)
			end
			table.insert(windowAxes, { s = s, u = u })
		else
			local h = y1 - UW_Y0
			P(A, sil, "Wall_" .. key .. idx, Vector3.new(w - 0.4, h, UW_T), sideCF(s, u, UW_Y0 + h / 2, UW_IN + UW_T / 2 + (if idx % 2 == 0 then 0 else 1)), shade, M.Concrete)
		end
	end
end
for _, key in ORDER do
	if key == "S" then
		slabRun("S", -UW_HALF, -40, 6, 1)
		slabRun("S", -40, 40, 1, 7, 140) -- notch slab below the lobby (Y 60..140)
		slabRun("S", 40, UW_HALF, 6, 8)
	else
		slabRun(key, -UW_HALF, UW_HALF, 13, 1)
	end
end
-- Pilasters every ~128 studs (8 wide, 6 deep, with a capital above the wall line); cyan seam on every 3rd.
local pil = 0
for _, key in ORDER do
	local s = SIDES[key]
	for k = -3, 3 do
		local u = k * 128
		if not (key == "S" and math.abs(u) < 60) then
			pil += 1
			P(A, det, "Pilaster_" .. key .. k, Vector3.new(8, 128, 6), sideCF(s, u, UW_Y0 + 64, UW_IN - 3), C.Steel, M.Metal)
			if pil % 3 == 1 then
				P(A, det, "Seam_" .. key .. k, Vector3.new(0.8, 108, 0.4), sideCF(s, u, UW_Y0 + 62, UW_IN - 6.2), C.Cyan, M.Neon)
			end
		end
	end
	-- Violet horizon band (Y 120), split around the south notch.
	if key == "S" then
		P(A, det, "Band_S_L", Vector3.new(UW_HALF - 40, 1, 0.6), sideCF(s, -(UW_HALF + 40) / 2, 120, UW_IN - 0.3), C.Violet, M.Neon)
		P(A, det, "Band_S_R", Vector3.new(UW_HALF - 40, 1, 0.6), sideCF(s, (UW_HALF + 40) / 2, 120, UW_IN - 0.3), C.Violet, M.Neon)
	else
		P(A, det, "Band_" .. key, Vector3.new(2 * UW_HALF, 1, 0.6), sideCF(s, 0, 120, UW_IN - 0.3), C.Violet, M.Neon)
	end
end
-- Chamfered corner towers (45 degrees), Y 55..190 with a cap.
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local pos = Vector3.new(sx * 410, 122.5, sz * 410)
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(45), 0)
		P(A, sil, "CornerTower", Vector3.new(52, 135, 52), cf, C.Navy2, M.Concrete)
		P(A, sil, "CornerTowerCap", Vector3.new(58, 4, 58), cf + Vector3.new(0, 69.5, 0), C.SteelLt, M.Metal)
	end
end

-- 3. Ceiling ribs: 8 box trusses from the wall tops (Y 180) to the hub ring (r 30, Y 240).
local HUB_Y, HUB_R = 240, 30
local ribDirs = {}
for i = 0, 7 do
	local a = i * math.pi / 4
	local d = Vector3.new(math.cos(a), 0, math.sin(a))
	local wallR = if i % 2 == 0 then UW_IN else UW_IN * math.sqrt(2)
	table.insert(ribDirs, { d = d, r = wallR })
end
for i, rd in ribDirs do
	local d, r = rd.d, rd.r
	-- Rib 3 would land on the south wall right at the lobby bay: it starts at r 330 instead, tucked
	-- under the roof (with a hanger into the roof) and above the lobby sightline, no corbel.
	local lobbyRib = i == 3
	local top0 = if lobbyRib then d * 330 + Vector3.new(0, 196, 0) else d * (r - 2) + Vector3.new(0, 186, 0)
	local top1 = d * HUB_R + Vector3.new(0, HUB_Y + 6, 0)
	local bot0 = if lobbyRib then d * 322 + Vector3.new(0, 184, 0) else d * (r - 10) + Vector3.new(0, 172, 0)
	local bot1 = d * (HUB_R + 6) + Vector3.new(0, HUB_Y - 6, 0)
	Strut(A, sil, "RibTop_" .. i, top0, top1, 10, 6, C.Steel, M.Metal, { shadow = true })
	Strut(A, sil, "RibBottom_" .. i, bot0, bot1, 8, 4, C.Navy2, M.Metal)
	for k = 1, 3 do
		local t = k / 4
		local a = bot0:Lerp(bot1, t)
		local b = top0:Lerp(top1, t)
		Strut(A, det, "RibWeb_" .. i .. "_" .. k, a, b, 3, 3, C.Navy1, M.Metal)
	end
	if lobbyRib then
		Strut(A, det, "RibHanger_" .. i, bot0, top0 + Vector3.new(0, 4, 0), 3, 3, C.Navy1, M.Metal)
	else
		P(A, sil, "RibCorbel_" .. i, Vector3.new(16, 20, 16), CFrame.lookAt(d * (r + 2) + Vector3.new(0, 176, 0), Vector3.new(0, 176, 0)), C.Navy2, M.Concrete)
	end
end
W.Ring(A, sil, "HubRing", Vector3.new(0, HUB_Y, 0), HUB_R, 12, Vector3.new(17, 8, 8), C.Steel, M.Metal)
P(A, sil, "HubEmitterHousing", Vector3.new(6, 26, 26), CFrame.new(0, HUB_Y - 4, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Navy2, M.Metal, { shape = "Cylinder" })
local hubCore = P(A, sil, "HubEmitter", Vector3.new(2, 10, 10), CFrame.new(0, HUB_Y - 8, 0) * CFrame.Angles(0, 0, math.rad(90)), C.Cyan, M.Neon, { shape = "Cylinder" })
W.hubCore = hubCore
W.Light(A, hubCore, "PointLight", { Color = C.Cyan, Range = 40, Brightness = 1.2, Shadows = false })

-- 3b. Hall roof (added after the lighting review): four hip-roof faces just above the rib trusses,
--     Y 189 at the walls to Y 248 at a square oculus (±40) over the reactor, plus a fascia closing
--     the gap above the wall tops. CastShadow is off, so sunlight still reaches the arena while the
--     default sky disappears; this lets the atmosphere stay light enough for long sightlines.
--     Built from 1 sloped plate + 2 WedgeParts per face.
do
	local Y0, Y1, R0, R1 = 189, 248, 400, 40
	local run, rise = R0 - R1, Y1 - Y0
	local slopeLen = math.sqrt(run * run + rise * rise)
	for k = 0, 3 do
		local rot = CFrame.Angles(0, k * math.pi / 2, 0)
		local function pt(x: number, z: number): Vector3
			local y = Y0 + (R0 - math.abs(z)) / run * rise
			return rot:PointToWorldSpace(Vector3.new(x, y, z))
		end
		local xAxis = rot:VectorToWorldSpace(Vector3.new(1, 0, 0))
		local normal = rot:VectorToWorldSpace(Vector3.new(0, run, -rise).Unit)
		-- Centre plate (x ±R1) from the wall edge to the oculus.
		local mid = (pt(0, -R0) + pt(0, -R1)) / 2
		P(A, sil, "RoofPlate_" .. k, Vector3.new(2 * R1, 2, slopeLen), CFrame.fromMatrix(mid, xAxis, normal), C.Navy0, M.Metal)
		-- Two right-triangle wedges (right angle at B = (±R1, -R0)).
		for _, sx in { -1, 1 } do
			local B = pt(sx * R1, -R0)
			local Apt = pt(sx * R0, -R0)
			local Cpt = pt(sx * R1, -R1)
			local yAxis = (Apt - B).Unit
			local zAxis = (B - Cpt).Unit
			local xw = yAxis:Cross(zAxis)
			local centre = B + (Apt - B) / 2 + (Cpt - B) / 2
			P(A, sil, "RoofWedge_" .. k .. (if sx < 0 then "L" else "R"), Vector3.new(2, (Apt - B).Magnitude, (Cpt - B).Magnitude), CFrame.fromMatrix(centre, xw, yAxis, zAxis), C.Navy0, M.Metal, { wedge = true })
		end
	end
	for _, key in ORDER do
		P(A, sil, "RoofFascia_" .. key, Vector3.new(2 * UW_HALF, 10, 4), sideCF(SIDES[key], 0, 185, UW_IN + 2), C.Navy2, M.Concrete)
	end
end

-- 4. Terrace machinery towers (3 per side, 3 height variants, tops <= Y 150). Never on the
--    lobby sightline (south side keeps |x| >= 120).
local towerSlots = { N = { -260, -40, 200 }, E = { -200, 40, 260 }, S = { -250, -130, 200 }, W = { -260, 0, 180 } }
local heights = { 110, 130, 150 }
local tCount = 0
for _, key in ORDER do
	local s = SIDES[key]
	for j, u in towerSlots[key] do
		tCount += 1
		local top = heights[(tCount % 3) + 1]
		local m = W.Model(det, "TerraceTower_" .. key .. j, "Atomic")
		local function at(y: number, depth: number?): CFrame
			return sideCF(s, u, y, 366 + (depth or 0))
		end
		P(A, m, "Base", Vector3.new(40, 8, 40), at(64), C.ConcreteDk, M.Concrete)
		local bodyTop = top - 22
		P(A, m, "Body", Vector3.new(32, bodyTop - 68, 30), at((68 + bodyTop) / 2), if j % 2 == 0 then C.Navy2 else C.Navy1, M.Metal)
		P(A, m, "Upper", Vector3.new(24, 20, 22), at(bodyTop + 10, 2), C.Steel, M.Metal)
		local cap = P(A, m, "Cap", Vector3.new(27, 2, 25), at(top - 1, 2), C.SteelLt, M.Metal)
		P(A, m, "Band", Vector3.new(34, 2, 32), at((68 + bodyTop) / 2 + 6), C.Steel, M.Metal)
		for side = -1, 1, 2 do
			P(A, m, "Pipe", Vector3.new(bodyTop - 66, 4, 4), sideCF(s, u + side * 9, (68 + bodyTop) / 2, 366 - 17) * CFrame.Angles(0, 0, math.rad(90)), C.SteelLt, M.Metal, { shape = "Cylinder" })
		end
		P(A, m, "Indicator", Vector3.new(0.6, 12, 0.3), sideCF(s, u, bodyTop - 10, 366 - 15.2), C.Cyan, M.Neon)
		if tCount <= 7 then -- 7 wall-wash lights + the hub light = 8 megastructure lights
			W.Light(A, cap, "PointLight", { Color = Color3.fromRGB(150, 170, 255), Range = 45, Brightness = 1.4, Shadows = false })
		end
	end
end

-- 5. Far silhouettes behind the deep windows (Y -90..150 at ~480).
for k, wa in windowAxes do
	local s, u = wa.s, wa.u
	local h = 200 + (k % 3) * 20
	P(A, det, "FarTower_" .. k, Vector3.new(44, h, 44), sideCF(s, u + ((k % 2) * 2 - 1) * 14, -90 + h / 2, 488), C.Slate, M.Metal)
	P(A, det, "FarTowerTop_" .. k, Vector3.new(28, 30, 28), sideCF(s, u + ((k % 2) * 2 - 1) * 14, -90 + h + 15, 488), C.Navy0, M.Metal)
end

-- 6. Shaft floor (Y -92..-90) with a faint cyan grid every 80 studs.
P(A, det, "ShaftFloor", Vector3.new(1100, 2, 1100), CFrame.new(0, -91, 0), C.Slate, M.Slate)
for k = -6, 6 do
	P(A, det, "GridX_" .. k, Vector3.new(960, 0.2, 0.8), CFrame.new(0, -89.9, k * 80), C.Cyan, M.Neon, { transparency = 0.7 })
	P(A, det, "GridZ_" .. k, Vector3.new(0.8, 0.2, 960), CFrame.new(k * 80, -89.9, 0), C.Cyan, M.Neon, { transparency = 0.7 })
end

local c = W.count(A)
return string.format("hall built (not yet parented): parts=%d collide=%d lights=%d shadows=%d windows=%d", c.parts, c.collide, c.lights, c.shadows, #windowAxes)
