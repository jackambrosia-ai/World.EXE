-- WORLD.EXE Phase 8A-2a: READ-ONLY final-state audit (Studio Edit mode).
-- Mutates nothing and never calls a restore. Works on the actual saved build (no builder state
-- needed): 8A-2a parts are found through their "Arch8A2A" attribute.
--
-- Automated checks:
--   C1..C11  gameplay clearances and rules (same definitions as 5_validate), budgets, streaming modes.
--   AC2      STRICT reactor recognizability from all 16 spawn eyes (+5) and the lobby. Pass per
--            viewpoint: >= 30% of 40 samples visible, >= 1 crown and >= 4 column samples. Reports the
--            top blocking parts. The walk-out distance is reported SEPARATELY as mitigation only; it
--            never changes the strict result.
--   LOBBY    window clearance from the lobby centre (head height), third-person and at-the-glass eyes.
--   AC1      sky exposure: a 9x5 ray fan (90 x 50 degrees) from each reference camera; a ray that hits
--            no part within 1,500 studs counts as open sky. Plus wall elevation angles.
--   AC3      height hierarchy inside the wall line (enclosure excluded) and the brightest light.
--   AC6      neon panel rule; reserved hues (amber/green/red) on new parts; Central Core span support.
-- Visual criteria (openness, district identity, repetition, readability) are judged from screenshots.
--
-- SIM_NON_OCCLUDING: optional list of full names treated as see-through in AC2/LOBBY only, to
-- evaluate a proposed repair without changing anything. Empty by default.
local SIM_NON_OCCLUDING: { string } = {}

local CS = game:GetService("CollectionService")
local root = workspace:WaitForChild("WORLD_EXE")
local map, lobby = root.Map, root.Lobby
local report: { [string]: any } = { simulated = SIM_NON_OCCLUDING }
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
-- Segment vs oriented box; returns the entry parameter t (0..1) or nil.
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

-- Marker counts (in Map only).
local counts = {}
for _, t in { "ArenaSpawn", "BounceSurface", "CorruptionNode", "DecayTile", "DroneWaypoint", "FloodZone", "FragmentSpawn", "MagneticPoint", "MagneticProp", "SlipSurface", "Stabilizer", "SupplyLandingPoint" } do
	counts[t] = #tagged(t)
end
report.markerCounts = counts

-- C1..C9, C11 (identical definitions to 5_validate).
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
local floors = {}
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and not newSet[p] and p.CFrame.UpVector.Y > 0.9 and p.Size.X >= 4 and p.Size.Z >= 4 then
		table.insert(floors, p)
	end
end
for _, p in newSolid do
	local isRail = p:GetAttribute("EdgeRail") == true
	local isStructure = string.find(p.Name, "^Column_") ~= nil or string.find(p.Name, "^ButtressPlinth_") ~= nil
	if not isRail and not isStructure then
		for _, f in floors do
			local top = f.Position.Y + f.Size.Y / 2
			if boxHit(p, Vector3.new(f.Position.X - f.Size.X / 2 + 1, top + 0.2, f.Position.Z - f.Size.Z / 2 + 1), Vector3.new(f.Position.X + f.Size.X / 2 - 1, top + 6, f.Position.Z + f.Size.Z / 2 - 1)) then
				err("C6 headroom: " .. p:GetFullName() .. " over " .. f.Name)
			end
		end
	end
end
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
for _, p in newSolid do
	local a, b = aabb(p)
	if b.X > 160.5 or a.X < -101 or a.Z < -147 or b.Z > 101 then
		err("C9 collidable outside core: " .. p:GetFullName())
	end
end
local reserved = {}
for _, p in newParts do
	if p.Material == Enum.Material.Neon then
		local s = { p.Size.X, p.Size.Y, p.Size.Z }
		table.sort(s)
		if s[1] < 1 and s[2] > 4 then
			err("C11 neon panel: " .. p:GetFullName())
		end
	end
	local h, sat, v = p.Color:ToHSV()
	if sat > 0.35 and v > 0.35 and ((h < 0.17) or (h > 0.22 and h < 0.45) or h > 0.95) then
		table.insert(reserved, p:GetFullName())
	end
end
report.checks = { lanes = lanes, links = links }
report.AC6_reservedHues = reserved

-- Budgets and streaming.
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
local caps = { Megastructure = { 420, 0, 8 }, LobbyBay = { 30, 0, 2 }, CoreTotal = { 320, 28, 11 } }
for k, cap in caps do
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
	if m:IsA("Model") and m:GetAttribute("Arch8A2A") == nil and (m:IsDescendantOf(map:FindFirstChild("Architecture") or map) or m:IsDescendantOf(map:FindFirstChild("Megastructure") or map)) then
		streaming[m.Name] = m.ModelStreamingMode.Name
	end
end
report.streaming = streaming

-- Occluders for visibility checks.
local sim = {}
for _, n in SIM_NON_OCCLUDING do
	sim[n] = true
end
local reactorParts = {}
for _, d in map.Architecture.CentralCore.ReactorSilhouette:GetDescendants() do
	if d:IsA("BasePart") then
		reactorParts[d] = true
	end
end
local occluders = {}
for _, c in { map, lobby } do
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") and not reactorParts[d] and d.Transparency < 0.5 and d.Size.Magnitude > 0.5 and not sim[d:GetFullName()] then
			table.insert(occluders, d)
		end
	end
end
local samples = {}
for k = 0, 15 do
	table.insert(samples, { kind = "column", p = Vector3.new(0, 22 + k * 9.5, 0) })
end
for _, ring in { { 50, 24 }, { 95, 20 }, { 140, 16 } } do
	for j = 0, 3 do
		local a = j * math.pi / 2
		table.insert(samples, { kind = "coil", p = Vector3.new(math.cos(a) * ring[2], ring[1], math.sin(a) * ring[2]) })
	end
end
for j = 0, 11 do
	local a = j * math.pi / 6
	local r = if j % 2 == 0 then 13 else 6
	table.insert(samples, { kind = "crown", p = Vector3.new(math.cos(a) * r, 175 + (j % 3) * 6, math.sin(a) * r) })
end
local function score(eye: Vector3, ignore: Instance?)
	local vis, crown, column = 0, 0, 0
	local blockers = {}
	for _, smp in samples do
		local nearest, nearestT = nil, 2
		for _, o in occluders do
			if o ~= ignore then
				local t = segT(o, eye, smp.p)
				if t and t < nearestT then
					nearest, nearestT = o, t
				end
			end
		end
		if nearest then
			blockers[nearest.Name] = (blockers[nearest.Name] or 0) + 1
		else
			vis += 1
			if smp.kind == "crown" then
				crown += 1
			elseif smp.kind == "column" then
				column += 1
			end
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
local function pass(vis, crown, column)
	return vis / #samples >= 0.3 and crown >= 1 and column >= 4
end

-- AC2 strict.
local ac2, ac2Fail = {}, {}
local yieldN = 0
for _, s in spawns do
	local eye = s.Position + Vector3.new(0, s.Size.Y / 2 + 5, 0)
	local vis, crown, column, blk = score(eye, s)
	local ok = pass(vis, crown, column)
	local walk = nil
	if not ok then
		local flat = Vector3.new(-eye.X, 0, -eye.Z).Unit
		for step = 4, 60, 4 do
			local v2, c2, co2 = score(eye + flat * step, s)
			if pass(v2, c2, co2) then
				walk = step
				break
			end
		end
		table.insert(ac2Fail, s.Name)
	end
	table.insert(ac2, string.format("%s %s %d%% crown %d column %d | blockers: %s%s", s.Name, if ok then "PASS" else "FAIL", math.floor(vis / #samples * 100 + 0.5), crown, column, if blk == "" then "-" else blk, if walk then " | walk-out mitigation: " .. walk .. " studs" elseif not ok then " | walk-out: none within 60" else ""))
	yieldN += 1
	if yieldN % 3 == 0 then
		task.wait()
	end
end
local lobbyLines = {}
for _, v in { { "LobbyCentre_head", Vector3.new(0, 164.5, 420) }, { "Lobby_thirdPerson", Vector3.new(0, 172, 434) }, { "Lobby_atGlass", Vector3.new(0, 164.5, 399) } } do
	local vis, crown, column, blk = score(v[2])
	local ok = pass(vis, crown, column)
	table.insert(lobbyLines, string.format("%s %s %d%% crown %d column %d | blockers: %s", v[1], if ok then "PASS" else "FAIL", math.floor(vis / #samples * 100 + 0.5), crown, column, if blk == "" then "-" else blk))
	if v[1] == "LobbyCentre_head" and not ok then
		table.insert(ac2Fail, "Lobby")
	end
end
report.AC2_strict = { result = if #ac2Fail == 0 then "PASS" else "FAIL (" .. #ac2Fail .. " viewpoints)", failing = ac2Fail, lines = ac2 }
report.LOBBY = lobbyLines

-- AC1 sky exposure from the six reference cameras (all parts are blockers here).
local allParts = {}
for _, c in { map, lobby } do
	for _, d in c:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			table.insert(allParts, d)
		end
	end
end
local cams = {
	G1 = { Vector3.new(0, 6, 110), Vector3.new(0, 40, 0) },
	G2 = { Vector3.new(-235, 6, 60), Vector3.new(0, 30, 0) },
	G3 = { Vector3.new(20, 6, -145), Vector3.new(0, 10, -250) },
	G4 = { Vector3.new(40, 6, 150), Vector3.new(0, -5, 240) },
	G5 = { Vector3.new(200, 54, 10), Vector3.new(0, 30, 0) },
	G6 = { Vector3.new(225, 30, 225), Vector3.new(0, 15, 0) },
}
local sky = {}
for name, cam in cams do
	local cf = CFrame.lookAt(cam[1], cam[2])
	local open, total = 0, 0
	for yi = -2, 2 do
		for xi = -4, 4 do
			total += 1
			local dir = (cf * CFrame.Angles(math.rad(yi * 12.5), math.rad(-xi * 11.25), 0)).LookVector
			local b = cam[1] + dir * 1500
			local hit = false
			for _, p in allParts do
				if segT(p, cam[1], b) then
					hit = true
					break
				end
			end
			if not hit then
				open += 1
			end
		end
		task.wait()
	end
	sky[name] = string.format("%d/%d rays open to sky (%d%%)", open, total, math.floor(open / total * 100 + 0.5))
end
report.AC1_skyExposure = sky
local elev = {}
for name, cam in cams do
	local x, y, z = cam[1].X, cam[1].Y, cam[1].Z
	local dU = math.min(400 - math.abs(x), 400 - math.abs(z))
	local dP = math.min(320 - math.abs(x), 320 - math.abs(z))
	elev[name] = string.format("plinth %.0f deg, upper wall %.0f deg", math.deg(math.atan2(60 - y, dP)), math.deg(math.atan2(180 - y, dU)))
end
report.AC1_wallElevation = elev

-- AC3 hierarchy: tallest non-enclosure parts inside the wall line.
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
		local a, b = aabb(d)
		if not skip and math.abs(d.Position.X) < 400 and math.abs(d.Position.Z) < 400 and not d:IsDescendantOf(map.Megastructure.LobbyBay) then
			table.insert(tall, { b.Y, d.Name })
		end
	end
end
table.sort(tall, function(a, b)
	return a[1] > b[1]
end)
local top = {}
for i = 1, 6 do
	table.insert(top, string.format("%s %.0f", tall[i][2], tall[i][1]))
end
local brightest, bVal = "", 0
for _, l in map:GetDescendants() do
	if l:IsA("Light") and l.Brightness * l.Range > bVal then
		bVal = l.Brightness * l.Range
		brightest = l.Parent.Name .. "/" .. l.ClassName
	end
end
report.AC3 = { tallestInsideWallLine = top, strongestLight = brightest }

-- AC6 Central Core span support (other districts are 8A-2b scope).
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
					local cx = math.clamp(mid.X, sa.X, sb.X)
					local cz = math.clamp(mid.Z, sa.Z, sb.Z)
					best = math.min(best, (Vector3.new(cx, 0, cz) - Vector3.new(mid.X, 0, mid.Z)).Magnitude)
				end
			end
			worst = math.max(worst, best)
		end
		table.insert(spans, string.format("%s worst edge-midpoint distance to a support below: %s", n, if worst == math.huge then "none" else string.format("%.0f", worst)))
	end
end
report.AC6_coreSpanSupport = spans

report.errors = errors
report.result = if #errors == 0 then "GAMEPLAY CHECKS PASS (read-only)" else "GAMEPLAY CHECK FAILURES: " .. #errors
return game:GetService("HttpService"):JSONEncode(report)
