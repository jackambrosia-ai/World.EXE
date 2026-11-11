-- WORLD.EXE Phase 8A-2a: READ-ONLY final-state audit (Studio Edit mode). Revision 2 (2026-11-11).
-- Mutates nothing and never calls a restore. Works on the actual saved build (no builder state
-- needed): 8A-2a parts are found through their "Arch8A2A" attribute. Every reading comes from ONE
-- run on ONE state; the report records that state (ArenaVersion, correction markers, part count).
--
-- Automated checks:
--   C1..C11  identical definitions to 5_validate (C6 includes the edge-rail test, the sloped-floor
--            envelope, the structure spoke-corridor test and the 2-stud marker clearance; C11 flags any
--            Neon part with two dimensions > 4 except EnergyCore/HubEmitter/CrownEmitter), plus
--            budgets and streaming modes.
--   AC2      STRICT approved benchmark, unchanged: 40 fixed samples (column axis, coil points at the
--            historical radii 24/20/16, crown), reactor-silhouette parts excluded as occluders. Pass:
--            >= 30% visible, >= 1 crown, >= 4 column. Walk-out is mitigation only.
--   SELF     Informational, separate from AC2: honest self-occlusion with the actual corrected reactor.
--            Samples on the energy core's surface facing the viewer (16 heights) and on the outer
--            face of the crown fins facing the viewer (8 points, Y 176/186); EVERY part is an occluder, including the reactor's own parts, except the
--            energy core itself and see-through parts (Transparency >= 0.4, e.g. the glass column).
--   LOBBY    strict-benchmark visibility from the lobby centre, third-person and at-the-glass eyes.
--   AC1      Two separate readings from each reference camera (9x5 ray fan over 90 x 50 degrees):
--            (a) GEOMETRY INTERSECTION: rays that hit no part (Transparency < 0.95) within 1,500
--                studs; (b) VISUAL SKY THROUGH TRANSLUCENT SURFACES: rays whose only hits are parts
--                with Transparency >= 0.3 (e.g. the 0.35 tinted-glass roof). (b) > 0 means the sky can
--                be seen dimmed through glass; judge the visible-sky criterion from screenshots.
--   AC3      height hierarchy inside the wall line (enclosure excluded) and the strongest light.
--   AC6      reserved hues on new parts; Central Core span support.
local CS = game:GetService("CollectionService")
local root = workspace:WaitForChild("WORLD_EXE")
local map, lobby = root.Map, root.Lobby
local report: { [string]: any } = {}
local errors = {}
local function err(s)
	table.insert(errors, s)
end

local newParts, newSolid, newSet = {}, {}, {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Arch8A2A") then
		table.insert(newParts, d)
		newSet[d] = true
		if d.CanCollide then
			table.insert(newSolid, d)
		end
	end
end
report.state = {
	ArenaVersion = root:GetAttribute("ArenaVersion"),
	Correction8A2A = map:GetAttribute("Correction8A2A"),
	Correction8A2A_R2 = map:GetAttribute("Correction8A2A_R2"),
	newParts = #newParts,
}

local function aabb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size / 2
	local r = cf - cf.Position
	local ex = Vector3.new(
		math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z,
		math.abs(r.XVector.Y) * s.X + math.abs(r.YVector.Y) * s.Y + math.abs(r.ZVector.Y) * s.Z,
		math.abs(r.XVector.Z) * s.X + math.abs(r.YVector.Z) * s.Y + math.abs(r.ZVector.Z) * s.Z
	)
	return cf.Position - ex, cf.Position + ex
end
local function boxHit(p: BasePart, lo: Vector3, hi: Vector3): boolean
	local a, b = aabb(p)
	return a.X < hi.X and b.X > lo.X and a.Y < hi.Y and b.Y > lo.Y and a.Z < hi.Z and b.Z > lo.Z
end
local function segT(p: BasePart, a: Vector3, b: Vector3, margin: number?): number?
	local m = margin or 0
	local la = p.CFrame:PointToObjectSpace(a)
	local lb = p.CFrame:PointToObjectSpace(b)
	local h = p.Size / 2 + Vector3.new(m, m, m)
	local d = lb - la
	local t0, t1 = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local o, dd, e = (la :: any)[axis], (d :: any)[axis], (h :: any)[axis]
		if math.abs(dd) < 1e-9 then
			if o < -e or o > e then
				return nil
			end
		else
			local u0, u1 = (-e - o) / dd, (e - o) / dd
			if u0 > u1 then
				u0, u1 = u1, u0
			end
			t0 = math.max(t0, u0)
			t1 = math.min(t1, u1)
			if t0 > t1 then
				return nil
			end
		end
	end
	return t0
end
local function tagged(tag: string)
	local list = {}
	for _, inst in CS:GetTagged(tag) do
		if inst:IsDescendantOf(map) then
			table.insert(list, inst)
		end
	end
	return list
end

local counts = {}
for _, t in { "ArenaSpawn", "BounceSurface", "CorruptionNode", "DecayTile", "DroneWaypoint", "FloodZone", "FragmentSpawn", "MagneticPoint", "MagneticProp", "SlipSurface", "Stabilizer", "SupplyLandingPoint" } do
	counts[t] = #tagged(t)
end
report.markerCounts = counts

-- C1..C5
for _, z in tagged("FloodZone") do
	local base = z.Position.Y - z.Size.Y / 2
	for _, p in newSolid do
		if boxHit(p, Vector3.new(z.Position.X - z.Size.X / 2, base - 1, z.Position.Z - z.Size.Z / 2), Vector3.new(z.Position.X + z.Size.X / 2, base + 7, z.Position.Z + z.Size.Z / 2)) then
			err("C1 flood: " .. p:GetFullName())
		end
	end
end
for _, pad in tagged("BounceSurface") do
	local top = pad.Position.Y + pad.Size.Y / 2
	for _, p in newParts do
		if boxHit(p, Vector3.new(pad.Position.X - pad.Size.X / 2 - 2, top, pad.Position.Z - pad.Size.Z / 2 - 2), Vector3.new(pad.Position.X + pad.Size.X / 2 + 2, 40, pad.Position.Z + pad.Size.Z / 2 + 2)) then
			err("C2 bounce: " .. p:GetFullName() .. " above " .. pad.Name)
		end
	end
end
for _, sp in tagged("SupplyLandingPoint") do
	for _, p in newParts do
		if boxHit(p, Vector3.new(sp.Position.X - sp.Size.X / 2 - 1, sp.Position.Y + 0.5, sp.Position.Z - sp.Size.Z / 2 - 1), Vector3.new(sp.Position.X + sp.Size.X / 2 + 1, 160, sp.Position.Z + sp.Size.Z / 2 + 1)) then
			err("C3 supply: " .. p:GetFullName() .. " in " .. sp.Name)
		end
	end
end
local spawns = tagged("ArenaSpawn")
for _, s in spawns do
	local top = s.Position.Y + s.Size.Y / 2
	for _, p in newParts do
		if boxHit(p, Vector3.new(s.Position.X - s.Size.X / 2 - 1, top, s.Position.Z - s.Size.Z / 2 - 1), Vector3.new(s.Position.X + s.Size.X / 2 + 1, top + 8, s.Position.Z + s.Size.Z / 2 + 1)) then
			err("C4 spawn: " .. p:GetFullName() .. " over " .. s.Name)
		end
	end
end
for _, st in tagged("Stabilizer") do
	local pos = if st:IsA("Model") then st:GetPivot().Position else st.Position
	local r = (st:GetAttribute("InteractionRadius") or 10) + 1
	for _, p in newSolid do
		if boxHit(p, pos - Vector3.new(r, 1, r), pos + Vector3.new(r, 8, r)) then
			err("C5 stabilizer: " .. p:GetFullName())
		end
	end
end
-- C6 (identical to 5_validate).
local floors = {}
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and not newSet[p] and p.CFrame.UpVector.Y > 0.9 and p.Size.X >= 4 and p.Size.Z >= 4 then
		table.insert(floors, p)
	end
end
local markers = {}
for _, tag in { "CorruptionNode", "SlipSurface", "BounceSurface", "MagneticProp", "MagneticPoint", "ArenaSpawn", "SupplyLandingPoint", "FragmentSpawn", "DecayTile" } do
	for _, m in tagged(tag) do
		if m:IsA("BasePart") then
			table.insert(markers, m)
		end
	end
end
local spokeCorridors = {}
for _, sp in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	local cx, cz = sp[1] * 114, sp[2] * 114
	local hx = if sp[1] ~= 0 then 28 else 15
	local hz = if sp[2] ~= 0 then 28 else 15
	table.insert(spokeCorridors, { Vector3.new(cx - hx, 0, cz - hz), Vector3.new(cx + hx, 8, cz + hz) })
end
local c6 = { rails = 0, structures = 0, other = 0 }
for _, p in newSolid do
	local isRail = p:GetAttribute("EdgeRail") == true
	local isStructure = string.find(p.Name, "^Column_") ~= nil or string.find(p.Name, "^ButtressPlinth_") ~= nil
	if isRail then
		c6.rails += 1
	elseif isStructure then
		c6.structures += 1
	else
		c6.other += 1
	end
	for _, f in floors do
		local top = f.Position.Y + f.Size.Y / 2
		local lo = Vector3.new(f.Position.X - f.Size.X / 2 + 1, top + 0.2, f.Position.Z - f.Size.Z / 2 + 1)
		local hi = Vector3.new(f.Position.X + f.Size.X / 2 - 1, top + 6, f.Position.Z + f.Size.Z / 2 - 1)
		if f.CFrame.RightVector.Y > 0.05 or f.CFrame.LookVector.Y > 0.05 or f.CFrame.LookVector.Y < -0.05 then
			local a, b = aabb(f)
			lo, hi = Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, b.Y + 6, b.Z)
		end
		if boxHit(p, lo, hi) then
			if isRail then
				local pa, pb = aabb(p)
				local nearEdge = math.min(math.abs(pa.X - (f.Position.X - f.Size.X / 2)), math.abs(pb.X - (f.Position.X + f.Size.X / 2)), math.abs(pa.Z - (f.Position.Z - f.Size.Z / 2)), math.abs(pb.Z - (f.Position.Z + f.Size.Z / 2)))
				local onTop = math.abs(pa.Y - top) < 0.6
				if not (onTop and nearEdge <= 1.5) then
					err("C6 rail not at an edge: " .. p:GetFullName() .. " vs " .. f.Name)
				end
			elseif not isStructure then
				err("C6 headroom: " .. p:GetFullName() .. " over " .. f.Name)
			end
		end
	end
	if isStructure then
		for _, c in spokeCorridors do
			if boxHit(p, c[1], c[2]) then
				err("C6 structure in spoke corridor: " .. p:GetFullName())
			end
		end
		for _, m in markers do
			local a, b = aabb(m)
			if boxHit(p, a - Vector3.new(2, 2, 2), b + Vector3.new(2, 8, 2)) then
				err("C6 structure within 2 of marker " .. m.Name .. ": " .. p:GetFullName())
			end
		end
	end
end
report.C6_checked = c6
-- C7, C8, C9
local lanes, links = 0, 0
for _, prop in tagged("MagneticProp") do
	for _, pt in tagged("MagneticPoint") do
		if pt:GetAttribute("Zone") == prop:GetAttribute("Zone") then
			lanes += 1
			for _, p in newSolid do
				if segT(p, prop.Position, pt.Position + Vector3.new(0, 1.5, 0), 2) then
					err("C7 lane: " .. p:GetFullName() .. " blocks " .. prop.Name)
				end
			end
		end
	end
end
local wps = {}
for _, wp in tagged("DroneWaypoint") do
	wps[wp:GetAttribute("WaypointId")] = wp
end
for id, wp in wps do
	for _, other in string.split(wp:GetAttribute("Links") or "", ",") do
		local o = wps[other]
		if o and id < other then
			links += 1
			for _, p in newSolid do
				if segT(p, wp.Position, o.Position, 0.5) then
					err("C8 drone LOS: " .. p:GetFullName() .. " blocks " .. id .. "-" .. other)
				end
			end
		end
	end
end
report.checks = { lanes = lanes, links = links }
for _, p in newSolid do
	local a, b = aabb(p)
	if b.X > 160.5 or a.X < -101 or a.Z < -147 or b.Z > 101 then
		err("C9 collidable outside core: " .. p:GetFullName())
	end
end
-- C11 (identical to 5_validate) and AC6 reserved hues.
local NEON_EXEMPT = { EnergyCore = true, HubEmitter = true, CrownEmitter = true }
local reserved = {}
local neonCount = 0
for _, p in newParts do
	if p.Material == Enum.Material.Neon then
		neonCount += 1
		if not NEON_EXEMPT[p.Name] then
			local s = { p.Size.X, p.Size.Y, p.Size.Z }
			table.sort(s)
			if s[2] > 4 then
				err("C11 neon surface: " .. p:GetFullName())
			end
		end
	end
	local h, sat, v = p.Color:ToHSV()
	if sat > 0.35 and v > 0.35 and ((h < 0.17) or (h > 0.22 and h < 0.45) or h > 0.95) then
		table.insert(reserved, p:GetFullName())
	end
end
report.C11_neonPartsChecked = neonCount
report.AC6_reservedHues = reserved
-- C10 budgets and streaming.
local totals = { parts = 0, collide = 0, lights = 0, shadows = 0 }
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		totals.parts += 1
		if d.CanCollide then
			totals.collide += 1
		end
	elseif d:IsA("Light") then
		totals.lights += 1
		if (d :: any).Shadows then
			totals.shadows += 1
		end
	end
end
local areas = {}
for _, p in newParts do
	local a = p:GetAttribute("Arch8A2A")
	if a == "Reactor" or a == "CentralCore" then
		a = "CoreTotal"
	end
	areas[a] = areas[a] or { parts = 0, collide = 0, lights = 0 }
	areas[a].parts += 1
	if p.CanCollide then
		areas[a].collide += 1
	end
	for _, c in p:GetChildren() do
		if c:IsA("Light") then
			areas[a].lights += 1
		end
	end
end
report.totals, report.areas = totals, areas
for k, cap in { Megastructure = { 420, 0, 8 }, LobbyBay = { 30, 0, 2 }, CoreTotal = { 320, 28, 11 } } do
	local a = areas[k] or { parts = 0, collide = 0, lights = 0 }
	if a.parts > cap[1] or a.collide > cap[2] or a.lights > cap[3] then
		err("C10 budget " .. k)
	end
end
if totals.parts > 4000 or totals.collide > 900 or totals.lights > 80 or totals.shadows > 12 then
	err("C10 global ceiling")
end
local streaming = {}
for _, m in map:GetDescendants() do
	if m:IsA("Model") and (m:IsDescendantOf(map:FindFirstChild("Architecture") or map) or m:IsDescendantOf(map:FindFirstChild("Megastructure") or map)) then
		local key = if string.find(m.Name, "^TerraceTower_") then "TerraceTower_*" else m.Name
		streaming[key] = m.ModelStreamingMode.Name
	end
end
report.streaming = streaming

-- Visibility helpers.
local silParts = {}
for _, d in map.Architecture.CentralCore.ReactorSilhouette:GetDescendants() do
	if d:IsA("BasePart") then
		silParts[d] = true
	end
end
local benchOcc, honestOcc = {}, {}
for _, c in { map, lobby } do
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") and d.Size.Magnitude > 0.5 then
			if not silParts[d] and d.Transparency < 0.5 then
				table.insert(benchOcc, d)
			end
			if d.Name ~= "EnergyCore" and d.Transparency < 0.4 then
				table.insert(honestOcc, d)
			end
		end
	end
end
local bench = {}
for k = 0, 15 do
	table.insert(bench, { kind = "column", p = Vector3.new(0, 22 + k * 9.5, 0) })
end
for _, ring in { { 50, 24 }, { 95, 20 }, { 140, 16 } } do
	for j = 0, 3 do
		local a = j * math.pi / 2
		table.insert(bench, { kind = "coil", p = Vector3.new(math.cos(a) * ring[2], ring[1], math.sin(a) * ring[2]) })
	end
end
for j = 0, 11 do
	local a = j * math.pi / 6
	local r = if j % 2 == 0 then 13 else 6
	table.insert(bench, { kind = "crown", p = Vector3.new(math.cos(a) * r, 175 + (j % 3) * 6, math.sin(a) * r) })
end
local function visible(occ, eye: Vector3, target: Vector3, ignore: Instance?): (boolean, BasePart?)
	local nearest, nt = nil, 2
	for _, o in occ do
		if o ~= ignore then
			local t = segT(o, eye, target)
			if t and t < nt then
				nearest, nt = o, t
			end
		end
	end
	return nearest == nil, nearest
end
local function benchScore(eye: Vector3, ignore: Instance?)
	local vis, crown, column = 0, 0, 0
	local blockers = {}
	for _, smp in bench do
		local ok, b = visible(benchOcc, eye, smp.p, ignore)
		if ok then
			vis += 1
			if smp.kind == "crown" then
				crown += 1
			elseif smp.kind == "column" then
				column += 1
			end
		elseif b then
			blockers[b.Name] = (blockers[b.Name] or 0) + 1
		end
	end
	local list = {}
	for n, c in blockers do
		table.insert(list, { n, c })
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	local top = {}
	for i = 1, math.min(3, #list) do
		table.insert(top, list[i][1] .. "=" .. list[i][2])
	end
	return vis, crown, column, table.concat(top, ", ")
end
local function benchPass(v, c, co)
	return v / #bench >= 0.3 and c >= 1 and co >= 4
end
-- Honest self-occlusion samples: core surface facing the viewer + crown top.
local function selfScore(eye: Vector3, ignore: Instance?)
	local flat = Vector3.new(eye.X, 0, eye.Z)
	local toward = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
	local core, crown = 0, 0
	for k = 0, 15 do
		local y = 20 + k * 9.5
		local p = toward * 4.4 + Vector3.new(0, y, 0)
		if visible(honestOcc, eye, p, ignore) then
			core += 1
		end
	end
	-- Crown: points on the outer face of the crown fins/collar facing the viewer (Y 172..190,
	-- within ±45 degrees of the viewer direction).
	local side = Vector3.new(-toward.Z, 0, toward.X)
	for j = 0, 7 do
		local ang = math.rad(-45 + (j % 4) * 30)
		local dir = toward * math.cos(ang) + side * math.sin(ang)
		local p = dir * 20.5 + Vector3.new(0, if j < 4 then 176 else 186, 0)
		if visible(honestOcc, eye, p, ignore) then
			crown += 1
		end
	end
	return core, crown
end

-- AC2 strict (benchmark, unchanged) + SELF (informational).
local ac2, ac2Fail, selfLines = {}, {}, {}
for _, s in spawns do
	local eye = s.Position + Vector3.new(0, s.Size.Y / 2 + 5, 0)
	local v, c, co, blk = benchScore(eye, s)
	local ok = benchPass(v, c, co)
	local walk = nil
	if not ok then
		table.insert(ac2Fail, s.Name)
		local flat = Vector3.new(-eye.X, 0, -eye.Z).Unit
		for step = 4, 60, 4 do
			local v2, c2, co2 = benchScore(eye + flat * step, s)
			if benchPass(v2, c2, co2) then
				walk = step
				break
			end
			task.wait()
		end
	end
	table.insert(ac2, string.format("%s %s %d%% crown %d column %d | blockers: %s%s", s.Name, if ok then "PASS" else "FAIL", math.floor(v / #bench * 100 + 0.5), c, co, if blk == "" then "-" else blk, if walk then " | walk-out mitigation: " .. walk .. " studs" elseif not ok then " | walk-out: none within 60" else ""))
	local sc, scr = selfScore(eye, s)
	table.insert(selfLines, string.format("%s energy-core surface %d/16, crown top %d/8", s.Name, sc, scr))
	task.wait()
end
local lobbyLines = {}
for _, v in { { "LobbyCentre_head", Vector3.new(0, 164.5, 420) }, { "Lobby_thirdPerson", Vector3.new(0, 172, 434) }, { "Lobby_atGlass", Vector3.new(0, 164.5, 399) } } do
	local vv, c, co, blk = benchScore(v[2])
	local ok = benchPass(vv, c, co)
	local sc, scr = selfScore(v[2])
	table.insert(lobbyLines, string.format("%s %s %d%% crown %d column %d | blockers: %s | SELF core %d/16 crown %d/8", v[1], if ok then "PASS" else "FAIL", math.floor(vv / #bench * 100 + 0.5), c, co, if blk == "" then "-" else blk, sc, scr))
	if v[1] == "LobbyCentre_head" and not ok then
		table.insert(ac2Fail, "Lobby")
	end
end
report.AC2_strict = { result = if #ac2Fail == 0 then "PASS" else "FAIL (" .. #ac2Fail .. " viewpoints)", failing = ac2Fail, lines = ac2 }
report.SELF_occlusion_informational = selfLines
report.LOBBY = lobbyLines

-- AC1 (two readings).
local cams = {
	G1 = { Vector3.new(0, 6, 110), Vector3.new(0, 40, 0) },
	G2 = { Vector3.new(-235, 6, 60), Vector3.new(0, 30, 0) },
	G3 = { Vector3.new(20, 6, -145), Vector3.new(0, 10, -250) },
	G4 = { Vector3.new(40, 6, 150), Vector3.new(0, -5, 240) },
	G5 = { Vector3.new(200, 54, 10), Vector3.new(0, 30, 0) },
	G6 = { Vector3.new(225, 30, 225), Vector3.new(0, 15, 0) },
}
local anyParts, opaqueParts = {}, {}
for _, c in { map, lobby } do
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Transparency < 0.95 then
				table.insert(anyParts, d)
			end
			if d.Transparency < 0.3 then
				table.insert(opaqueParts, d)
			end
		end
	end
end
local function hitsAny(list, a, b)
	for _, p in list do
		if segT(p, a, b) then
			return true
		end
	end
	return false
end
local geo, vis = {}, {}
for name, cam in cams do
	local cf = CFrame.lookAt(cam[1], cam[2])
	local openGeo, throughGlass, total = 0, 0, 0
	for yi = -2, 2 do
		for xi = -4, 4 do
			total += 1
			local dir = (cf * CFrame.Angles(math.rad(yi * 12.5), math.rad(-xi * 11.25), 0)).LookVector
			local b = cam[1] + dir * 1500
			local anyHit = hitsAny(anyParts, cam[1], b)
			if not anyHit then
				openGeo += 1
			elseif not hitsAny(opaqueParts, cam[1], b) then
				throughGlass += 1
			end
		end
		task.wait()
	end
	geo[name] = string.format("%d/%d rays hit no geometry", openGeo, total)
	vis[name] = string.format("%d/%d rays see sky only through translucent surfaces (roof glass etc.)", throughGlass, total)
end
report.AC1_geometryIntersection = geo
report.AC1_skyThroughTranslucent = vis

-- AC3
local enclosure = { "^Roof", "^Rib", "^Hub", "^Wall_", "^Win", "^Pilaster", "^Seam", "^Band", "^Corner", "^Plinth", "^Terrace", "^Far", "^Fascia" }
local tall = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		local skip = false
		for _, pat in enclosure do
			if string.find(d.Name, pat) then
				skip = true
			end
		end
		local _, b = aabb(d)
		if not skip and math.abs(d.Position.X) < 400 and math.abs(d.Position.Z) < 400 and not d:IsDescendantOf(map.Megastructure.LobbyBay) then
			table.insert(tall, { b.Y, d.Name })
		end
	end
end
table.sort(tall, function(a, b)
	return a[1] > b[1]
end)
local nonReactor = ""
for _, t in tall do
	if not (string.find(t[2], "^Crown") or string.find(t[2], "^Energy") or string.find(t[2], "^Containment")) then
		nonReactor = string.format("%s %.0f", t[2], t[1])
		break
	end
end
local brightest, bVal = "", 0
for _, l in map:GetDescendants() do
	if l:IsA("Light") and l.Brightness * l.Range > bVal then
		bVal = l.Brightness * l.Range
		brightest = l.Parent.Name .. "/" .. l.ClassName
	end
end
report.AC3 = { tallest = string.format("%s %.0f", tall[1][2], tall[1][1]), tallestNonReactor = nonReactor, strongestLight = brightest }

-- AC6 Central Core span support.
local supports = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and (string.find(d.Name, "Column") or string.find(d.Name, "Pillar") or string.find(d.Name, "Vessel") or string.find(d.Name, "Girder") or string.find(d.Name, "Hanger") or string.find(d.Name, "Stringer") or string.find(d.Name, "Chord") or string.find(d.Name, "Fascia") or string.find(d.Name, "Crossbeam")) then
		table.insert(supports, d)
	end
end
local spans = {}
for _, n in { "CorePlaza", "Mezz_N", "Mezz_S", "Mezz_E", "Mezz_W", "Gantry_N_Bridge", "Gantry_E_Bridge" } do
	local f = map:FindFirstChild(n, true)
	if f then
		local a, b = aabb(f)
		local worst = 0
		for _, mid in { Vector3.new((a.X + b.X) / 2, a.Y, a.Z), Vector3.new((a.X + b.X) / 2, a.Y, b.Z), Vector3.new(a.X, a.Y, (a.Z + b.Z) / 2), Vector3.new(b.X, a.Y, (a.Z + b.Z) / 2) } do
			local best = math.huge
			for _, s in supports do
				local sa, sb = aabb(s)
				if sb.Y <= a.Y + 1 and sa.Y < a.Y then
					best = math.min(best, (Vector3.new(math.clamp(mid.X, sa.X, sb.X), 0, math.clamp(mid.Z, sa.Z, sb.Z)) - Vector3.new(mid.X, 0, mid.Z)).Magnitude)
				end
			end
			worst = math.max(worst, best)
		end
		table.insert(spans, string.format("%s %s", n, if worst == math.huge then "none" else string.format("%.0f", worst)))
	end
end
report.AC6_coreSpanSupport = spans

report.errors = errors
report.result = if #errors == 0 then "GAMEPLAY CHECKS C1-C11 PASS (read-only)" else "GAMEPLAY CHECK FAILURES: " .. #errors
return game:GetService("HttpService"):JSONEncode(report)
