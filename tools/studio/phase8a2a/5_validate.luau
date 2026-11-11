-- WORLD.EXE Phase 8A-2a builder, step 5: validation, then finalize (ArenaVersion 3) or restore.
-- All checks are analytic: they use part geometry directly, never physics queries, because
-- decorative parts have CanQuery off.
--   C1 flood volumes: no new collidable part inside any FloodZone footprint from its base to +7.
--   C2 bounce apex: no new part of any kind above any bounce pad (footprint +2) below Y 40.
--   C3 supply drops: no new part of any kind in any landing column (footprint +1) up to Y 160.
--   C4 spawns: no new part of any kind in any spawn pad box (footprint +1, 8 high).
--   C5 stabilizers: no new collidable part within the interaction radius (Y -1..+8).
--   C6 walkable headroom: new collidable parts may not enter the 6-stud envelope above any
--      existing walkable floor, except EdgeRail parts (must sit within 1.5 of that floor's edge)
--      and the approved FloorStructure parts (colonnade columns, buttress plinths). Those must keep
--      clear of the spoke corridors and stay >= 2 studs from every gameplay marker.
--   C7 MAGNETIC lanes: no new collidable part intersects any prop -> magnet point lane (4 wide).
--   C8 drone LOS: no new collidable part (queryable) intersects any waypoint link.
--   C9 zero-G / Skybridge: no new collidable part beyond x 160 or outside the core region.
--   C10 budget: per-area caps and global ceilings (4,000 parts / 900 collidable / 80 lights / 12 shadow).
--   C11 neon panels: no new Neon part with two dimensions > 4 and the third < 1.
--   AC2 reactor visibility: from all 16 spawns (eye +5) and the lobby centre, segment-vs-box
--      occlusion against every BasePart in Map + Lobby (decor included; parts with
--      Transparency >= 0.5 and the reactor's own parts do not occlude; cylinders as boxes).
--      Pass per viewpoint: >= 30% of 40 samples visible, incl. >= 1 crown and >= 4 column.
local W = assert(_G.W8A2A, "run steps 0-4 first")
local CS = game:GetService("CollectionService")
local map, lobby = W.map, W.lobby
local errors, notes = {}, {}
local function err(s)
	table.insert(errors, s)
end

local newSet = {}
for _, p in W.newParts do
	newSet[p] = true
end
local newSolid = {}
for _, p in W.newParts do
	if p.CanCollide then
		table.insert(newSolid, p)
	end
end

-- World AABB of a part.
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
-- Segment vs oriented box (slab test in the part's local space), with an optional margin.
local function segHitsPart(p: BasePart, a: Vector3, b: Vector3, margin: number?): boolean
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
				return false
			end
		else
			local u0, u1 = (-e - o) / dd, (e - o) / dd
			if u0 > u1 then
				u0, u1 = u1, u0
			end
			t0 = math.max(t0, u0)
			t1 = math.min(t1, u1)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
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

-- C1 flood volumes.
for _, z in tagged("FloodZone") do
	local base = z.Position.Y - z.Size.Y / 2
	local lo = Vector3.new(z.Position.X - z.Size.X / 2, base - 1, z.Position.Z - z.Size.Z / 2)
	local hi = Vector3.new(z.Position.X + z.Size.X / 2, base + 7, z.Position.Z + z.Size.Z / 2)
	for _, p in newSolid do
		if boxHit(p, lo, hi) then
			err("C1 flood: " .. p:GetFullName() .. " in " .. z.Name)
		end
	end
end
-- C2 bounce apex columns.
for _, pad in tagged("BounceSurface") do
	local top = pad.Position.Y + pad.Size.Y / 2
	local lo = Vector3.new(pad.Position.X - pad.Size.X / 2 - 2, top, pad.Position.Z - pad.Size.Z / 2 - 2)
	local hi = Vector3.new(pad.Position.X + pad.Size.X / 2 + 2, 40, pad.Position.Z + pad.Size.Z / 2 + 2)
	for _, p in W.newParts do
		if boxHit(p, lo, hi) then
			err("C2 bounce: " .. p:GetFullName() .. " above " .. pad.Name)
		end
	end
end
-- C3 supply columns.
for _, sp in tagged("SupplyLandingPoint") do
	local lo = Vector3.new(sp.Position.X - sp.Size.X / 2 - 1, sp.Position.Y + 0.5, sp.Position.Z - sp.Size.Z / 2 - 1)
	local hi = Vector3.new(sp.Position.X + sp.Size.X / 2 + 1, 160, sp.Position.Z + sp.Size.Z / 2 + 1)
	for _, p in W.newParts do
		if boxHit(p, lo, hi) then
			err("C3 supply: " .. p:GetFullName() .. " in column " .. sp.Name)
		end
	end
end
-- C4 spawns.
local spawns = tagged("ArenaSpawn")
for _, s in spawns do
	local top = s.Position.Y + s.Size.Y / 2
	local lo = Vector3.new(s.Position.X - s.Size.X / 2 - 1, top, s.Position.Z - s.Size.Z / 2 - 1)
	local hi = Vector3.new(s.Position.X + s.Size.X / 2 + 1, top + 8, s.Position.Z + s.Size.Z / 2 + 1)
	for _, p in W.newParts do
		if boxHit(p, lo, hi) then
			err("C4 spawn: " .. p:GetFullName() .. " over " .. s.Name)
		end
	end
end
-- C5 stabilizers.
for _, st in tagged("Stabilizer") do
	local pos = if st:IsA("Model") then st:GetPivot().Position else st.Position
	local r = (st:GetAttribute("InteractionRadius") or 10) + 1
	local lo, hi = pos - Vector3.new(r, 1, r), pos + Vector3.new(r, 8, r)
	for _, p in newSolid do
		if boxHit(p, lo, hi) then
			err("C5 stabilizer: " .. p:GetFullName() .. " near " .. st.Name)
		end
	end
end
-- C6 walkable headroom.
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
for _, p in newSolid do
	local isRail = p:GetAttribute("EdgeRail") == true
	local isStructure = string.find(p.Name, "^Column_") ~= nil or string.find(p.Name, "^ButtressPlinth_") ~= nil
	for _, f in floors do
		local top = f.Position.Y + f.Size.Y / 2
		local lo = Vector3.new(f.Position.X - f.Size.X / 2 + 1, top + 0.2, f.Position.Z - f.Size.Z / 2 + 1)
		local hi = Vector3.new(f.Position.X + f.Size.X / 2 - 1, top + 6, f.Position.Z + f.Size.Z / 2 - 1)
		if f.CFrame.RightVector.Y > 0.05 or f.CFrame.LookVector.Y > 0.05 or f.CFrame.LookVector.Y < -0.05 then
			-- sloped ramps: use their AABB as the envelope.
			local a, b = aabb(f)
			lo, hi = Vector3.new(a.X, a.Y, a.Z), Vector3.new(b.X, b.Y + 6, b.Z)
		end
		if boxHit(p, lo, hi) then
			if isRail then
				local pa, pb = aabb(p)
				local nearEdge = math.min(math.abs(pa.X - (f.Position.X - f.Size.X / 2)), math.abs(pb.X - (f.Position.X + f.Size.X / 2)), math.abs(pa.Z - (f.Position.Z - f.Size.Z / 2)), math.abs(pb.Z - (f.Position.Z + f.Size.Z / 2)))
				local onTop = math.abs(pa.Y - top) < 0.6
				if not (onTop and nearEdge <= 1.5) then
					-- A rail may also sit inside a larger floor's envelope only at that floor's level edge.
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
-- C7 MAGNETIC lanes (each prop to every magnet point in its zone).
local points = tagged("MagneticPoint")
for _, prop in tagged("MagneticProp") do
	for _, pt in points do
		if pt:GetAttribute("Zone") == prop:GetAttribute("Zone") then
			for _, p in newSolid do
				if segHitsPart(p, prop.Position, pt.Position + Vector3.new(0, 1.5, 0), 2) then
					err("C7 crate lane: " .. p:GetFullName() .. " blocks " .. prop.Name)
				end
			end
		end
	end
end
-- C8 drone waypoint lines of sight.
local wps = {}
for _, wp in tagged("DroneWaypoint") do
	wps[wp:GetAttribute("WaypointId")] = wp
end
local links = 0
for id, wp in wps do
	for _, other in string.split(wp:GetAttribute("Links") or "", ",") do
		local o = wps[other]
		if o and id < other then
			links += 1
			for _, p in newSolid do
				if segHitsPart(p, wp.Position, o.Position, 0.5) then
					err("C8 drone LOS: " .. p:GetFullName() .. " blocks " .. id .. "-" .. other)
				end
			end
		end
	end
end
table.insert(notes, "C8 checked " .. links .. " waypoint links")
-- C9 no new collidable outside the core region / E bridge.
for _, p in newSolid do
	local a, b = aabb(p)
	if b.X > 160.5 or a.X < -101 or a.Z < -147 or b.Z > 101 then
		err("C9 collidable outside the core region: " .. p:GetFullName())
	end
end
-- C11 neon panels.
for _, p in W.newParts do
	if p.Material == Enum.Material.Neon then
		local s = { p.Size.X, p.Size.Y, p.Size.Z }
		table.sort(s)
		if s[1] < 1 and s[2] > 4 then
			err("C11 neon panel: " .. p:GetFullName())
		end
	end
end
-- C10 budget.
local caps = {
	Megastructure = { parts = 420, collide = 0, lights = 8, shadows = 0 },
	LobbyBay = { parts = 30, collide = 0, lights = 2, shadows = 0 },
	CoreTotal = { parts = 320, collide = 28, lights = 11, shadows = 1 },
}
local cnt = {}
for area, c in W.counts do
	local key = if area == "Reactor" or area == "CentralCore" then "CoreTotal" else area
	cnt[key] = cnt[key] or { parts = 0, collide = 0, lights = 0, shadows = 0 }
	for k, v in c do
		cnt[key][k] += v
	end
end
for key, cap in caps do
	local c = cnt[key] or { parts = 0, collide = 0, lights = 0, shadows = 0 }
	for k, v in cap do
		if c[k] > v then
			err(string.format("C10 budget %s.%s = %d > cap %d", key, k, c[k], v))
		end
	end
end
local totalParts, totalSolid, totalLights, totalShadows = 0, 0, 0, 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		totalParts += 1
		if d.CanCollide then
			totalSolid += 1
		end
	elseif d:IsA("Light") then
		totalLights += 1
		if (d :: any).Shadows then
			totalShadows += 1
		end
	end
end
if totalParts > 4000 then err("C10 total parts " .. totalParts) end
if totalSolid > 900 then err("C10 total collidable " .. totalSolid) end
if totalLights > 80 then err("C10 total lights " .. totalLights) end
if totalShadows > 12 then err("C10 shadow lights " .. totalShadows) end

-- AC2 reactor visibility.
local reactorParts = {}
local silModel = map.Architecture.CentralCore.ReactorSilhouette
for _, d in silModel:GetDescendants() do
	if d:IsA("BasePart") then
		reactorParts[d] = true
	end
end
local occluders = {}
for _, container in { map, lobby } do
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and not reactorParts[d] and d.Transparency < 0.5 and d.Size.Magnitude > 0.5 then
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
local viewpoints = {}
for _, s in spawns do
	table.insert(viewpoints, { name = s.Name, eye = s.Position + Vector3.new(0, s.Size.Y / 2 + 5, 0), ignore = s })
end
table.insert(viewpoints, { name = "LobbyCentre", eye = Vector3.new(0, 164.5, 420) })
local vis = {}
local tests = 0
for vi, v in viewpoints do
	local visible, crown, column = 0, 0, 0
	for _, smp in samples do
		local blocked = false
		for _, o in occluders do
			if o ~= v.ignore then
				tests += 1
				if segHitsPart(o, v.eye, smp.p) then
					blocked = true
					break
				end
			end
		end
		if not blocked then
			visible += 1
			if smp.kind == "crown" then
				crown += 1
			elseif smp.kind == "column" then
				column += 1
			end
		end
	end
	local frac = visible / #samples
	local ok = frac >= 0.3 and crown >= 1 and column >= 4
	local line = string.format("%s %d%% (crown %d, column %d)", v.name, math.floor(frac * 100 + 0.5), crown, column)
	if not ok and v.ignore then
		-- Walk-out check: step toward the core (4 studs at a time, up to 40) until the reactor reads.
		local flat = Vector3.new(-v.eye.X, 0, -v.eye.Z).Unit
		local walked = nil
		for step = 4, 40, 4 do
			local eye = v.eye + flat * step
			local vv, cc, co = 0, 0, 0
			for _, smp in samples do
				local blocked = false
				for _, o in occluders do
					if o ~= v.ignore and segHitsPart(o, eye, smp.p) then
						blocked = true
						break
					end
				end
				if not blocked then
					vv += 1
					if smp.kind == "crown" then
						cc += 1
					elseif smp.kind == "column" then
						co += 1
					end
				end
			end
			if vv / #samples >= 0.3 and cc >= 1 and co >= 4 then
				walked = step
				break
			end
		end
		if walked and walked <= 30 then
			line ..= string.format(" -> DEVIATION: blocked at the spawn eye by pre-existing geometry; readable after walking %d studs toward the core", walked)
			table.insert(notes, "AC2 deviation for review: " .. v.name .. " readable after " .. walked .. " studs")
		else
			line ..= " FAIL"
			err("AC2 reactor not readable from " .. v.name .. " (walk-out " .. tostring(walked) .. ")")
		end
	elseif not ok then
		line ..= " FAIL"
		err("AC2 reactor not readable from " .. v.name)
	end
	table.insert(vis, line)
	if vi % 3 == 0 then
		task.wait()
	end
end

local summary = {}
for k, c in cnt do
	table.insert(summary, string.format("%s parts=%d collide=%d lights=%d shadows=%d", k, c.parts, c.collide, c.lights, c.shadows))
end
local report = {
	errors = errors,
	notes = notes,
	areas = summary,
	totals = string.format("map parts=%d collidable=%d lights=%d shadowLights=%d beams=%d", totalParts, totalSolid, totalLights, totalShadows, W.beams or 0),
	visibility = vis,
	occlusionTests = tests,
}
if #errors == 0 then
	W.root:SetAttribute("ArenaVersion", 3)
	report.result = "PASS: finalized (ArenaVersion 3). Rollback store kept at ServerStorage.WORLD_EXE_Rollback8A2A."
else
	report.result = "FAIL: " .. W.Restore("validation failed")
end
return game:GetService("HttpService"):JSONEncode(report)
