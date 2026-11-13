-- WORLD.EXE Phase 8A-2b step 6: READ-ONLY final-state audit (never mutates, never restores).
-- Run in Studio EDIT mode. Long-running: wrap in task.spawn and poll _G.AUDIT8A2B (see README).
-- Covers every 8A-2a (Arch8A2A), 8A-2b (Arch8A2B) and ENV_SLICE1 (EnvSlice1) part. All checks are
-- analytic (part geometry, never physics queries: decorative parts have CanQuery off).
-- ENV_SLICE1 (tools/studio/envslice1, 2026-11-13) parts carry EnvSlice1 = "TraversalLinks" or
-- "ExteriorScenery" and are subject to every check below (C1-C5, C7, C8, C11, C12 apply through the
-- shared new-part lists). Slice-specific handling: C5h, C6s, C6b, C9, C10 and C13 as described.
--   C1 flood volumes          no new collidable in any FloodZone footprint, base-1 .. base+7.
--   C2 bounce apex            no new part of any kind above a bounce pad (footprint +2) below Y 40.
--   C3 supply columns         no new part of any kind in a landing column (footprint +1) to Y 160.
--   C4 spawns                 no new part of any kind in a spawn box (footprint +1, 8 high).
--   C5 stabilizers            no new collidable within the interaction radius (Y -1..+8).
--   C5h hazards (slice)       no ENV_SLICE1 collidable within 8 studs above any slip, decay, corruption,
--                             fragment or magnetic marker (footprint +1).
--   C6 walkable headroom      new collidables may not enter the 6-stud envelope above an existing
--                             walkable floor, except EdgeRails (on top, within 1.5 of an edge) and
--                             approved structures (8A-2a Column_/ButtressPlinth_; 8A-2b FloorStructure).
--                             Structures: outside the spoke corridors, >= 2 studs from every marker;
--                             8A-2b FloorStructures also within 4 studs of the edge of every floor they
--                             stand in, or within 1.5 studs of an existing collidable wall/rack.
--   C6s (slice)               nothing collidable (existing or new) may enter the 6-stud envelope above an
--                             ENV_SLICE1 WalkSurface, except an EdgeRail on its top within 1.5 of an edge.
--   C6b                       no 8A-2b or ENV_SLICE1 collidable intersects an existing collidable, and no
--                             two ENV_SLICE1 collidables intersect each other (0.3 tolerance).
--   C7 MAGNETIC lanes         no new collidable in any prop -> magnet lane (4 wide).
--   C8 drone LOS              no new collidable on any waypoint link (every waypoint instance).
--   C9 collidable roles       every 8A-2b collidable carries FloorStructure, EdgeRail or BoundaryWall;
--                             8A-2a collidables stay inside the core region. Every ENV_SLICE1 collidable
--                             is in TraversalLinks and carries exactly one of WalkSurface or EdgeRail.
--                             A WalkSurface is a level, unrotated slab (>= 4 x 4) inside Config.ArenaBounds
--                             that joins another walkable floor flush (top within 0.1, gap <= 0.3, shared
--                             edge >= 4); each traversal model must join at least two existing floors.
--                             An ENV_SLICE1 EdgeRail stands on a WalkSurface.
--   C10 budgets               per-area caps (design section 9.1), design total 2,252, ceilings
--                             4,000 parts / 900 collidable / 80 lights / 12 shadow lights. ENV_SLICE1 has
--                             its own categories (owner-approved 2026-11-13): TraversalLinks 24 parts /
--                             12 collidable / 0 lights, ExteriorScenery 40 / 0 / 0. They do not draw on
--                             the district caps. An unknown or doubly-attributed slice part is an error.
--   C11 neon                  no new Neon part with two dimensions > 4 (landmark emitters exempt).
--   C12 zero-G gaps           no new part in the Reservoir bridge gap or the Archive rack-top gaps.
--   C13 drop-downs            every 8A-2b and ENV_SLICE1 EdgeRail faces the void along its whole length
--                             (a floor within 40 studs below, or a floor at that level, fails). ENV_SLICE1
--                             WalkSurfaces count as floors here, for old and new rails alike.
-- Visual acceptance (reported, never a rollback trigger): AC2 strict benchmark (unchanged) with SELF
-- self-occlusion, lobby views, AC1 split, AC3 heights, AC6 reserved hues and slab span support
-- (ENV_SLICE1 WalkSurfaces are included in the span-support check).
-- report.ACCEPTANCE combines C1-C13, AC6 and strict AC2 for every non-waived viewpoint into one
-- overall PASS/FAIL; the five owner-approved AC2 exceptions are listed separately.
local CS = game:GetService("CollectionService")
local root = workspace:WaitForChild("WORLD_EXE")
local map, lobby = root.Map, root.Lobby
local report: { [string]: any } = {}
local errors = {}
local function err(s)
	table.insert(errors, s)
end
local V = Vector3.new

local newParts, newSolid, newSet = {}, {}, {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and (d:GetAttribute("Arch8A2A") or d:GetAttribute("Arch8A2B") or d:GetAttribute("EnvSlice1") ~= nil) then
		table.insert(newParts, d)
		newSet[d] = true
		if d.CanCollide then
			table.insert(newSolid, d)
		end
	end
end
local nB, nS = 0, 0
local sliceSolid, sliceFloors = {}, {}
for _, p in newParts do
	if p:GetAttribute("Arch8A2B") then
		nB += 1
	end
	if p:GetAttribute("EnvSlice1") ~= nil then
		nS += 1
		if p.CanCollide then
			table.insert(sliceSolid, p)
			if p:GetAttribute("WalkSurface") == true then
				table.insert(sliceFloors, p)
			end
		end
	end
end
-- Slice-marked instances the lists above cannot see (outside Map, or not parts) are errors.
for _, d in workspace:GetDescendants() do
	if d:GetAttribute("EnvSlice1") ~= nil and d ~= map and not (d:IsA("BasePart") and d:IsDescendantOf(map)) then
		err("EnvSlice1 attribute on an instance the audit cannot check: " .. d:GetFullName())
	end
end
report.state = { ArenaVersion = root:GetAttribute("ArenaVersion"), Correction8A2A_R2 = map:GetAttribute("Correction8A2A_R2"), Phase8A2B = map:GetAttribute("Phase8A2B"), EnvSlice1 = map:GetAttribute("EnvSlice1"), parts8A2A = #newParts - nB - nS, parts8A2B = nB, partsEnvSlice1 = nS, auditedAt = os.date("!%Y-%m-%dT%H:%M:%SZ") }

local function aabb(p: BasePart): (Vector3, Vector3)
	local cf, s = p.CFrame, p.Size / 2
	local r = cf - cf.Position
	local ex = V(math.abs(r.XVector.X) * s.X + math.abs(r.YVector.X) * s.Y + math.abs(r.ZVector.X) * s.Z, math.abs(r.XVector.Y) * s.X + math.abs(r.YVector.Y) * s.Y + math.abs(r.ZVector.Y) * s.Z, math.abs(r.XVector.Z) * s.X + math.abs(r.YVector.Z) * s.Y + math.abs(r.ZVector.Z) * s.Z)
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
	local h = p.Size / 2 + V(m, m, m)
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

-- C1..C5.
for _, z in tagged("FloodZone") do
	local base = z.Position.Y - z.Size.Y / 2
	for _, p in newSolid do
		if boxHit(p, V(z.Position.X - z.Size.X / 2, base - 1, z.Position.Z - z.Size.Z / 2), V(z.Position.X + z.Size.X / 2, base + 7, z.Position.Z + z.Size.Z / 2)) then
			err("C1 flood: " .. p:GetFullName())
		end
	end
end
for _, pad in tagged("BounceSurface") do
	local top = pad.Position.Y + pad.Size.Y / 2
	for _, p in newParts do
		if boxHit(p, V(pad.Position.X - pad.Size.X / 2 - 2, top, pad.Position.Z - pad.Size.Z / 2 - 2), V(pad.Position.X + pad.Size.X / 2 + 2, 40, pad.Position.Z + pad.Size.Z / 2 + 2)) then
			err("C2 bounce: " .. p:GetFullName())
		end
	end
end
for _, sp in tagged("SupplyLandingPoint") do
	for _, p in newParts do
		if boxHit(p, V(sp.Position.X - sp.Size.X / 2 - 1, sp.Position.Y + 0.5, sp.Position.Z - sp.Size.Z / 2 - 1), V(sp.Position.X + sp.Size.X / 2 + 1, 160, sp.Position.Z + sp.Size.Z / 2 + 1)) then
			err("C3 supply: " .. p:GetFullName() .. " in " .. sp.Name)
		end
	end
end
local spawns = tagged("ArenaSpawn")
for _, s in spawns do
	local top = s.Position.Y + s.Size.Y / 2
	for _, p in newParts do
		if boxHit(p, V(s.Position.X - s.Size.X / 2 - 1, top, s.Position.Z - s.Size.Z / 2 - 1), V(s.Position.X + s.Size.X / 2 + 1, top + 8, s.Position.Z + s.Size.Z / 2 + 1)) then
			err("C4 spawn: " .. p:GetFullName() .. " over " .. s.Name)
		end
	end
end
for _, st in tagged("Stabilizer") do
	local pos = if st:IsA("Model") then st:GetPivot().Position else st.Position
	local r = (st:GetAttribute("InteractionRadius") or 10) + 1
	for _, p in newSolid do
		if boxHit(p, pos - V(r, 1, r), pos + V(r, 8, r)) then
			err("C5 stabilizer: " .. p:GetFullName())
		end
	end
end

-- C5h hazards (ENV_SLICE1): nothing collidable from the slice directly above a hazard or pickup marker.
local hazardMarkers = 0
for _, tag in { "SlipSurface", "DecayTile", "CorruptionNode", "FragmentSpawn", "MagneticPoint", "MagneticProp" } do
	for _, m in tagged(tag) do
		if m:IsA("BasePart") then
			hazardMarkers += 1
			local a, b = aabb(m)
			for _, p in sliceSolid do
				if boxHit(p, V(a.X - 1, b.Y, a.Z - 1), V(b.X + 1, b.Y + 8, b.Z + 1)) then
					err("C5h hazard clearance: " .. p:GetFullName() .. " over " .. m.Name)
				end
			end
		end
	end
end
report.C5h_markersChecked = hazardMarkers

-- C6 / C6b.
local existingSolid, floors, walls = {}, {}, {}
for _, p in map:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide and not newSet[p] then
		table.insert(existingSolid, p)
		-- Rack tops are walkable (zero-G route), so tall upright parts can be both floor and wall.
		if p.CFrame.UpVector.Y > 0.9 and p.Size.X >= 4 and p.Size.Z >= 4 then
			table.insert(floors, p)
		end
		local a, b = aabb(p)
		if b.Y - a.Y >= 6 then
			table.insert(walls, p)
		end
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
	table.insert(spokeCorridors, { V(cx - hx, 0, cz - hz), V(cx + hx, 8, cz + hz) })
end
local function hGap(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3): number
	local dx = math.max(0, b0.X - a1.X, a0.X - b1.X)
	local dz = math.max(0, b0.Z - a1.Z, a0.Z - b1.Z)
	return math.sqrt(dx * dx + dz * dz)
end
local c6 = { rails = 0, structures = 0, boundaryWalls = 0, other = 0 }
for _, p in newSolid do
	local isB = p:GetAttribute("Arch8A2B") ~= nil
	local isS = p:GetAttribute("EnvSlice1") ~= nil
	local isRail = p:GetAttribute("EdgeRail") == true
	local isStructure = string.find(p.Name, "^Column_") ~= nil or string.find(p.Name, "^ButtressPlinth_") ~= nil or p:GetAttribute("FloorStructure") == true
	if isRail then
		c6.rails += 1
	elseif isStructure then
		c6.structures += 1
	elseif p:GetAttribute("BoundaryWall") then
		c6.boundaryWalls += 1
	else
		c6.other += 1
	end
	local pa, pb = aabb(p)
	for _, f in floors do
		local top = f.Position.Y + f.Size.Y / 2
		local lo = V(f.Position.X - f.Size.X / 2 + 1, top + 0.2, f.Position.Z - f.Size.Z / 2 + 1)
		local hi = V(f.Position.X + f.Size.X / 2 - 1, top + 6, f.Position.Z + f.Size.Z / 2 - 1)
		local sloped = f.CFrame.RightVector.Y > 0.05 or f.CFrame.LookVector.Y > 0.05 or f.CFrame.LookVector.Y < -0.05
		if sloped then
			local a, b = aabb(f)
			lo, hi = V(a.X, a.Y, a.Z), V(b.X, b.Y + 6, b.Z)
		end
		if boxHit(p, lo, hi) then
			local fa, fb = aabb(f)
			if isRail then
				local nearEdge = math.min(math.abs(pa.X - fa.X), math.abs(pb.X - fb.X), math.abs(pa.Z - fa.Z), math.abs(pb.Z - fb.Z))
				if not (math.abs(pa.Y - top) < 0.6 and nearEdge <= 1.5) then
					err("C6 rail not at an edge: " .. p:GetFullName() .. " vs " .. f.Name)
				end
			elseif isStructure then
				if isB and not sloped then
					local edgeDist = math.min(math.abs(pa.X - fa.X), math.abs(fb.X - pb.X), math.abs(pa.Z - fa.Z), math.abs(fb.Z - pb.Z))
					local nearWall = false
					for _, w in walls do
						local wa, wb = aabb(w)
						if wa.Y < pb.Y and wb.Y > pa.Y and hGap(pa, pb, wa, wb) <= 1.5 then
							nearWall = true
							break
						end
					end
					if edgeDist > 4 and not nearWall then
						err(string.format("C6 FloorStructure mid-floor (%.1f from %s edge, no adjacent wall): %s", edgeDist, f.Name, p:GetFullName()))
					end
				elseif isB and sloped then
					err("C6 FloorStructure over a ramp: " .. p:GetFullName() .. " vs " .. f.Name)
				end
			else
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
			if boxHit(p, a - V(2, 2, 2), b + V(2, 8, 2)) then
				err("C6 structure within 2 of marker " .. m.Name .. ": " .. p:GetFullName())
			end
		end
	end
	if isB or isS then
		for _, e in existingSolid do
			local ea, eb = aabb(e)
			if pa.X < eb.X - 0.3 and pb.X > ea.X + 0.3 and pa.Y < eb.Y - 0.3 and pb.Y > ea.Y + 0.3 and pa.Z < eb.Z - 0.3 and pb.Z > ea.Z + 0.3 then
				err("C6b intersects existing " .. e:GetFullName() .. ": " .. p:GetFullName())
			end
		end
	end
end
-- C6b (ENV_SLICE1): slice collidables may touch (rails stand on floors) but not intersect each other.
for i, p in sliceSolid do
	local pa, pb = aabb(p)
	for j = i + 1, #sliceSolid do
		local ea, eb = aabb(sliceSolid[j])
		if pa.X < eb.X - 0.3 and pb.X > ea.X + 0.3 and pa.Y < eb.Y - 0.3 and pb.Y > ea.Y + 0.3 and pa.Z < eb.Z - 0.3 and pb.Z > ea.Z + 0.3 then
			err("C6b slice parts intersect: " .. p:GetFullName() .. " x " .. sliceSolid[j]:GetFullName())
		end
	end
end
-- C6s (ENV_SLICE1): headroom above the new walk surfaces, against every collidable in the map.
local allSolid = table.clone(existingSolid)
for _, p in newSolid do
	table.insert(allSolid, p)
end
local c6sRails = 0
for _, f in sliceFloors do
	local fa, fb = aabb(f)
	local lo, hi = V(fa.X + 1, fb.Y + 0.2, fa.Z + 1), V(fb.X - 1, fb.Y + 6, fb.Z - 1)
	for _, p in allSolid do
		if p ~= f and boxHit(p, lo, hi) then
			local pa, pb = aabb(p)
			local nearEdge = math.min(math.abs(pa.X - fa.X), math.abs(pb.X - fb.X), math.abs(pa.Z - fa.Z), math.abs(pb.Z - fb.Z))
			if p:GetAttribute("EdgeRail") == true and math.abs(pa.Y - fb.Y) < 0.6 and nearEdge <= 1.5 then
				c6sRails += 1
			else
				err("C6s headroom over slice walk surface " .. f.Name .. ": " .. p:GetFullName())
			end
		end
	end
end
report.C6_checked = c6
report.C6s_checked = { walkSurfaces = #sliceFloors, edgeRailsAccepted = c6sRails }

-- C7, C8.
local lanes, links = 0, 0
for _, prop in tagged("MagneticProp") do
	for _, pt in tagged("MagneticPoint") do
		if pt:GetAttribute("Zone") == prop:GetAttribute("Zone") then
			lanes += 1
			for _, p in newSolid do
				if segT(p, prop.Position, pt.Position + V(0, 1.5, 0), 2) then
					err("C7 lane: " .. p:GetFullName() .. " blocks " .. prop.Name)
				end
			end
		end
	end
end
local byId = {}
local wpList = tagged("DroneWaypoint")
for _, wp in wpList do
	local id = wp:GetAttribute("WaypointId")
	byId[id] = byId[id] or {}
	table.insert(byId[id], wp)
end
local seen = {}
for _, wp in wpList do
	for _, other in string.split(wp:GetAttribute("Links") or "", ",") do
		for _, o in byId[other] or {} do
			local key = if wp:GetFullName() < o:GetFullName() then wp:GetFullName() .. "|" .. o:GetFullName() else o:GetFullName() .. "|" .. wp:GetFullName()
			if not seen[key] then
				seen[key] = true
				links += 1
				for _, p in newSolid do
					if segT(p, wp.Position, o.Position, 0.5) then
						err("C8 drone LOS: " .. p:GetFullName() .. " " .. wp:GetAttribute("WaypointId") .. "-" .. other)
					end
				end
			end
		end
	end
end
report.checks = { lanes = lanes, links = links }

-- C9.
for _, p in newSolid do
	if p:GetAttribute("Arch8A2B") then
		if not (p:GetAttribute("FloorStructure") or p:GetAttribute("EdgeRail") or p:GetAttribute("BoundaryWall")) then
			err("C9 8A-2b collidable without an approved role: " .. p:GetFullName())
		end
	elseif p:GetAttribute("EnvSlice1") ~= nil then
		local walk, rail = p:GetAttribute("WalkSurface") == true, p:GetAttribute("EdgeRail") == true
		if walk == rail then
			err("C9 ENV_SLICE1 collidable needs exactly one of WalkSurface / EdgeRail: " .. p:GetFullName())
		end
		if p:GetAttribute("EnvSlice1") ~= "TraversalLinks" then
			err("C9 ENV_SLICE1 collidable outside TraversalLinks: " .. p:GetFullName())
		end
		if p:GetAttribute("FloorStructure") or p:GetAttribute("BoundaryWall") then
			err("C9 ENV_SLICE1 collidable carries an 8A-2b role: " .. p:GetFullName())
		end
	else
		local a, b = aabb(p)
		if b.X > 160.5 or a.X < -101 or a.Z < -147 or b.Z > 101 then
			err("C9 8A-2a collidable outside the core: " .. p:GetFullName())
		end
	end
end

-- C9 (ENV_SLICE1) walk surfaces: level slabs inside the arena bounds, joined flush to other floors.
local BOUNDS_MIN, BOUNDS_MAX = V(-275, -40, -275), V(275, 160, 275) -- Config.ArenaBoundsMin / Max
local function flushJoin(f: BasePart, g: BasePart): boolean
	local fa, fb = aabb(f)
	local ga, gb = aabb(g)
	if math.abs(fb.Y - gb.Y) > 0.1 then
		return false
	end
	local gapX = math.max(ga.X - fb.X, fa.X - gb.X)
	local gapZ = math.max(ga.Z - fb.Z, fa.Z - gb.Z)
	local overlapX = math.min(fb.X, gb.X) - math.max(fa.X, ga.X)
	local overlapZ = math.min(fb.Z, gb.Z) - math.max(fa.Z, ga.Z)
	return (math.abs(gapX) <= 0.3 and overlapZ >= 4) or (math.abs(gapZ) <= 0.3 and overlapX >= 4)
end
local sliceJoins = {}
for _, f in sliceFloors do
	local fa, fb = aabb(f)
	if f.CFrame.UpVector.Y < 0.9999 or math.abs(f.CFrame.LookVector.X * f.CFrame.LookVector.Z) > 1e-4 or f.Size.X < 4 or f.Size.Z < 4 then
		err("C9 walk surface must be a level, unrotated slab of at least 4 x 4: " .. f:GetFullName())
	end
	if fa.X < BOUNDS_MIN.X or fa.Y < BOUNDS_MIN.Y or fa.Z < BOUNDS_MIN.Z or fb.X > BOUNDS_MAX.X or fb.Y + 6 > BOUNDS_MAX.Y or fb.Z > BOUNDS_MAX.Z then
		err("C9 walk surface outside the arena bounds: " .. f:GetFullName())
	end
	local joined = false
	local key = f.Parent:GetFullName()
	sliceJoins[key] = sliceJoins[key] or {}
	for _, g in sliceFloors do
		if g ~= f and flushJoin(f, g) then
			joined = true
		end
	end
	for _, g in floors do
		if flushJoin(f, g) then
			joined = true
			sliceJoins[key][g.Name] = true
		end
	end
	if not joined then
		err("C9 walk surface not joined flush to another floor: " .. f:GetFullName())
	end
end
local joinReport = {}
for key, set in sliceJoins do
	local names = {}
	for n in set do
		table.insert(names, n)
	end
	table.sort(names)
	joinReport[key] = names
	if #names < 2 then
		err(string.format("C9 traversal model joins %d existing floor(s), needs 2: %s", #names, key))
	end
end
report.C9_sliceJoins = joinReport

-- C10 budgets.
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
	local a = p:GetAttribute("Arch8A2B") or p:GetAttribute("Arch8A2A")
	local sliceArea = p:GetAttribute("EnvSlice1")
	if sliceArea ~= nil then
		if a ~= nil then
			err("C10 part attributed to both a district and ENV_SLICE1: " .. p:GetFullName())
		end
		if sliceArea ~= "TraversalLinks" and sliceArea ~= "ExteriorScenery" then
			err("C10 unknown ENV_SLICE1 category '" .. tostring(sliceArea) .. "': " .. p:GetFullName())
		end
		a = tostring(sliceArea)
	end
	if a == "Reactor" or a == "CentralCore" then
		a = "CoreTotal"
	end
	areas[a] = areas[a] or { parts = 0, collide = 0, lights = 0, shadows = 0 }
	areas[a].parts += 1
	if p.CanCollide then
		areas[a].collide += 1
	end
	for _, c in p:GetChildren() do
		if c:IsA("Light") then
			areas[a].lights += 1
			if (c :: any).Shadows then
				areas[a].shadows += 1
			end
		end
	end
end
report.totals, report.areas = totals, areas
local CAPS = {
	Megastructure = { 420, 0, 8 },
	LobbyBay = { 30, 0, 2 },
	CoreTotal = { 320, 28, 11 },
	ResearchYard = { 120, 24, 6 },
	Skybridge = { 100, 20, 5 },
	DataArchive = { 170, 24, 8 },
	CoolantReservoir = { 140, 18, 6 },
	OuterRing = { 120, 42, 5 },
	SharedSupports = { 250, 0, 0 },
	-- ENV_SLICE1 slice-level allocations (owner-approved 2026-11-13). Not a licence to build up to them.
	TraversalLinks = { 24, 12, 0 },
	ExteriorScenery = { 40, 0, 0 },
}
for k, cap in CAPS do
	local a = areas[k] or { parts = 0, collide = 0, lights = 0 }
	if a.parts > cap[1] or a.collide > cap[2] or a.lights > cap[3] then
		err(string.format("C10 budget %s %d/%d/%d > %d/%d/%d", k, a.parts, a.collide, a.lights, cap[1], cap[2], cap[3]))
	end
end
if totals.parts > 2252 then
	err("C10 design total cap 2,252 exceeded: " .. totals.parts)
end
if totals.parts > 4000 or totals.collide > 900 or totals.lights > 80 or totals.shadows > 12 then
	err("C10 global ceiling")
end

-- C11, AC6 reserved hues.
local NEON_EXEMPT = { EnergyCore = true, HubEmitter = true, CrownEmitter = true }
local reserved, reservedUse, neonCount = {}, {}, 0
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
		if p:GetAttribute("ReservedUse") then
			table.insert(reservedUse, p.Name .. "=" .. p:GetAttribute("ReservedUse"))
		else
			table.insert(reserved, p:GetFullName())
		end
	end
end
report.C11_neonPartsChecked = neonCount
report.AC6_reservedHues_unapproved = reserved
report.AC6_reservedHues_declaredUse = reservedUse

-- C12 zero-G gaps.
local gaps = { { "ReservoirBridgeGap", V(-7, 23, 194), V(7, 40, 206) } }
local racks = {}
for _, d in map.DataArchive:GetDescendants() do
	if d:IsA("BasePart") and string.match(d.Name, "^Rack_%-?%d+[AB]$") then
		table.insert(racks, d)
	end
end
for _, r1 in racks do
	for _, r2 in racks do
		local a1, b1 = aabb(r1)
		local a2, b2 = aabb(r2)
		if r1 ~= r2 and math.abs(r1.Position.Z - r2.Position.Z) < 1 and a2.X > b1.X and a2.X - b1.X <= 16 then
			table.insert(gaps, { "RackGap_" .. r1.Name .. "_" .. r2.Name, V(b1.X, b1.Y, a1.Z), V(a2.X, 40, b1.Z) })
		end
	end
end
for _, g in gaps do
	for _, p in newParts do
		if boxHit(p, g[2], g[3]) then
			err("C12 zero-G gap " .. g[1] .. ": " .. p:GetFullName())
		end
	end
end
report.C12_gapsChecked = #gaps

-- C13 drop-downs: every 8A-2b EdgeRail must face the void.
local coverSolids = table.clone(existingSolid)
local railFloors = table.clone(floors)
for _, f in sliceFloors do
	table.insert(coverSolids, f)
	table.insert(railFloors, f)
end
local function coveredOut(pt: Vector3, top: number, floor: BasePart?): boolean
	for _, e in coverSolids do
		if e ~= floor then
			local a, b = aabb(e)
			if pt.X >= a.X and pt.X <= b.X and pt.Z >= a.Z and pt.Z <= b.Z and b.Y >= top - 40 and a.Y <= top + 6 then
				return true
			end
		end
	end
	return false
end
local railsChecked, sliceRails = 0, 0
for _, p in newSolid do
	if (p:GetAttribute("Arch8A2B") or p:GetAttribute("EnvSlice1") ~= nil) and p:GetAttribute("EdgeRail") then
		railsChecked += 1
		if p:GetAttribute("EnvSlice1") ~= nil then
			sliceRails += 1
		end
		local a, b = aabb(p)
		local floor
		for _, f in railFloors do
			local fa, fb = aabb(f)
			local c = (a + b) / 2
			if c.X >= fa.X and c.X <= fb.X and c.Z >= fa.Z and c.Z <= fb.Z and math.abs(fb.Y - a.Y) < 0.6 then
				floor = f
				break
			end
		end
		if not floor then
			err("C13 rail without a floor: " .. p:GetFullName())
		elseif p:GetAttribute("EnvSlice1") ~= nil and not floor:GetAttribute("WalkSurface") then
			err("C9 ENV_SLICE1 rail not on a slice walk surface: " .. p:GetFullName())
		else
			local fa, fb = aabb(floor)
			local alongX = (b.X - a.X) > (b.Z - a.Z)
			local n
			if alongX then
				n = if math.abs(a.Z - fa.Z) < math.abs(fb.Z - b.Z) then V(0, 0, -1) else V(0, 0, 1)
			else
				n = if math.abs(a.X - fa.X) < math.abs(fb.X - b.X) then V(-1, 0, 0) else V(1, 0, 0)
			end
			local edge = if n.X < 0 then fa.X elseif n.X > 0 then fb.X elseif n.Z < 0 then fa.Z else fb.Z
			local len = if alongX then b.X - a.X else b.Z - a.Z
			local bad = 0
			for t = 0.5, len - 0.5, 2 do
				local pt = if alongX then V(a.X + t, fb.Y, edge + n.Z * 1.0) else V(edge + n.X * 1.0, fb.Y, a.Z + t)
				if coveredOut(pt, fb.Y, floor) then
					bad += 1
				end
			end
			if bad > 0 then
				err(string.format("C13 rail blocks %d drop-down sample(s): %s", bad, p:GetFullName()))
			end
		end
	end
end
report.C13_railsChecked = railsChecked
report.C13_sliceRailsChecked = sliceRails

-- Streaming modes of the new assemblies.
local streaming = {}
for _, top in { map.Architecture, map.Megastructure } do
	for _, m in top:GetDescendants() do
		if m:IsA("Model") then
			local key = if string.find(m.Name, "^TerraceTower_") then "TerraceTower_*" else m.Name
			streaming[key] = m.ModelStreamingMode.Name
		end
	end
end
report.streaming = streaming

-- AC2 strict benchmark (unchanged) + SELF + lobby.
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
	table.insert(bench, { kind = "column", p = V(0, 22 + k * 9.5, 0) })
end
for _, ring in { { 50, 24 }, { 95, 20 }, { 140, 16 } } do
	for j = 0, 3 do
		local a = j * math.pi / 2
		table.insert(bench, { kind = "coil", p = V(math.cos(a) * ring[2], ring[1], math.sin(a) * ring[2]) })
	end
end
for j = 0, 11 do
	local a = j * math.pi / 6
	local r = if j % 2 == 0 then 13 else 6
	table.insert(bench, { kind = "crown", p = V(math.cos(a) * r, 175 + (j % 3) * 6, math.sin(a) * r) })
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
local function selfScore(eye: Vector3, ignore: Instance?)
	local flat = V(eye.X, 0, eye.Z)
	local toward = if flat.Magnitude > 0.1 then flat.Unit else V(0, 0, 1)
	local core, crown = 0, 0
	for k = 0, 15 do
		if visible(honestOcc, eye, toward * 4.4 + V(0, 20 + k * 9.5, 0), ignore) then
			core += 1
		end
	end
	local side = V(-toward.Z, 0, toward.X)
	for j = 0, 7 do
		local ang = math.rad(-45 + (j % 4) * 30)
		local dir = toward * math.cos(ang) + side * math.sin(ang)
		if visible(honestOcc, eye, dir * 20.5 + V(0, if j < 4 then 176 else 186, 0), ignore) then
			crown += 1
		end
	end
	return core, crown
end
local WAIVED = { Spawn_RES_1 = true, Spawn_RES_2 = true, Spawn_ARCH_1 = true, Spawn_ARCH_2 = true, Spawn_ARCH_3 = true }
local ac2, ac2Fail, newFail, selfLines, waivedLines = {}, {}, {}, {}, {}
for _, s in spawns do
	local eye = s.Position + V(0, s.Size.Y / 2 + 5, 0)
	local v, c, co, blk = benchScore(eye, s)
	local ok = benchPass(v, c, co)
	if not ok then
		table.insert(ac2Fail, s.Name)
		if not WAIVED[s.Name] then
			table.insert(newFail, s.Name)
		end
	end
	local line = string.format("%s %s%s %d%% crown %d column %d | blockers: %s", s.Name, if ok then "PASS" else "FAIL", if WAIVED[s.Name] then " (waived)" else "", math.floor(v / #bench * 100 + 0.5), c, co, if blk == "" then "-" else blk)
	table.insert(ac2, line)
	if WAIVED[s.Name] then
		table.insert(waivedLines, line)
	end
	local sc, scr = selfScore(eye, s)
	table.insert(selfLines, string.format("%s core %d/16 crown %d/8", s.Name, sc, scr))
	task.wait()
end
local lobbyLines = {}
for _, v in { { "LobbyCentre_head", V(0, 164.5, 420) }, { "Lobby_thirdPerson", V(0, 172, 434) }, { "Lobby_atGlass", V(0, 164.5, 399) } } do
	local vv, c, co, blk = benchScore(v[2])
	local ok = benchPass(vv, c, co)
	local sc, scr = selfScore(v[2])
	table.insert(lobbyLines, string.format("%s %s %d%% crown %d column %d | blockers: %s | SELF core %d/16 crown %d/8", v[1], if ok then "PASS" else "FAIL", math.floor(vv / #bench * 100 + 0.5), c, co, if blk == "" then "-" else blk, sc, scr))
	if v[1] == "LobbyCentre_head" and not ok then
		table.insert(newFail, "Lobby")
	end
end
report.AC2_strict = { result = if #newFail == 0 then "PASS except the five waived spawns" else "NEW FAILURES: " .. table.concat(newFail, ", "), failing = ac2Fail, lines = ac2 }
report.SELF_occlusion_informational = selfLines
report.LOBBY = lobbyLines

-- AC1 split.
local cams = {
	G1 = { V(0, 6, 110), V(0, 40, 0) },
	G2 = { V(-235, 6, 60), V(0, 30, 0) },
	G3 = { V(20, 6, -145), V(0, 10, -250) },
	G4 = { V(40, 6, 150), V(0, -5, 240) },
	G5 = { V(200, 54, 10), V(0, 30, 0) },
	G6 = { V(225, 30, 225), V(0, 15, 0) },
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
			if not hitsAny(anyParts, cam[1], b) then
				openGeo += 1
			elseif not hitsAny(opaqueParts, cam[1], b) then
				throughGlass += 1
			end
		end
		task.wait()
	end
	geo[name] = string.format("%d/%d rays hit no geometry", openGeo, total)
	vis[name] = string.format("%d/%d rays see sky only through translucent surfaces", throughGlass, total)
end
report.AC1_geometryIntersection = geo
report.AC1_skyThroughTranslucent = vis

-- AC3.
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
local nonReactor, nonReactorY = "", 0
for _, t in tall do
	if not (string.find(t[2], "^Crown") or string.find(t[2], "^Energy") or string.find(t[2], "^Containment")) then
		nonReactor, nonReactorY = string.format("%s %.0f", t[2], t[1]), t[1]
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
report.AC3 = { tallest = string.format("%s %.0f", tall[1][2], tall[1][1]), tallestNonReactor = nonReactor, nonReactorAtOrBelow150 = nonReactorY <= 150.5, strongestLight = brightest }

-- AC6 span support: every elevated 8A-1 slab and the 8A-2a core decks.
local SUPPORT_NAMES = { "Column", "Pillar", "Pylon", "Hanger", "Leg", "Tower", "Rack_", "Vessel", "Stringer", "Wall", "Post", "Rod" }
local supports = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and not string.find(d.Name, "Girder") then
		local isSup = d:GetAttribute("Support8A2B") == true
		if not isSup and d:GetAttribute("Arch8A2B") == nil then
			for _, n in SUPPORT_NAMES do
				if string.find(d.Name, n) then
					isSup = true
					break
				end
			end
		end
		if isSup then
			local a, b = aabb(d)
			if b.Y - a.Y >= 6 or d:GetAttribute("Support8A2B") then
				table.insert(supports, d)
			end
		end
	end
end
local SLABS = { "Catwalk_N", "Catwalk_S", "RackDeck_NW", "RackDeck_NE", "ArchiveWalk_S", "SkyDeck", "SkyLanding_N", "SkyLanding_S", "Island_N", "Island_S", "Bridge_W", "Bridge_E", "BridgeLink_W", "BridgeLink_E", "Ring_N", "Ring_S", "Ring_W", "Ring_E", "CorePlaza", "Mezz_N", "Mezz_S", "Mezz_E", "Mezz_W", "Gantry_N_Bridge", "Gantry_E_Bridge" }
local slabParts = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and (table.find(SLABS, d.Name) or string.match(d.Name, "^Step_%d$")) then
		table.insert(slabParts, d)
	end
end
for _, f in sliceFloors do
	table.insert(slabParts, f)
end
local CORE_SLABS = { CorePlaza = true, Mezz_N = true, Mezz_S = true, Mezz_E = true, Mezz_W = true, Gantry_N_Bridge = true, Gantry_E_Bridge = true }
local coreSupports = {}
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		for _, n in { "Column", "Pillar", "Vessel", "Girder", "Hanger", "Stringer", "Chord", "Fascia", "Crossbeam" } do
			if string.find(d.Name, n) then
				table.insert(coreSupports, d)
				break
			end
		end
	end
end
local spans, spanFail = {}, {}
for _, f in slabParts do
	local a, b = aabb(f)
	local worst = 0
	for _, mid in { V((a.X + b.X) / 2, a.Y, a.Z), V((a.X + b.X) / 2, a.Y, b.Z), V(a.X, a.Y, (a.Z + b.Z) / 2), V(b.X, a.Y, (a.Z + b.Z) / 2) } do
		local best = math.huge
		if CORE_SLABS[f.Name] then
			-- 8A-2a core decks: the 8A-2a audit method (supports below the deck, girders included).
			for _, s in coreSupports do
				local sa, sb = aabb(s)
				if sb.Y <= a.Y + 1 and sa.Y < a.Y then
					best = math.min(best, (V(math.clamp(mid.X, sa.X, sb.X), 0, math.clamp(mid.Z, sa.Z, sb.Z)) - V(mid.X, 0, mid.Z)).Magnitude)
				end
			end
		else
			for _, s in supports do
				if s ~= f then
					local sa, sb = aabb(s)
					if sb.Y >= a.Y - 4.5 and sa.Y <= b.Y + 0.5 then
						best = math.min(best, (V(math.clamp(mid.X, sa.X, sb.X), 0, math.clamp(mid.Z, sa.Z, sb.Z)) - V(mid.X, 0, mid.Z)).Magnitude)
					end
				end
			end
		end
		worst = math.max(worst, best)
	end
	local label = string.format("%s@%.0f,%.0f %s", f.Name, f.Position.X, f.Position.Z, if worst == math.huge then "none" else string.format("%.0f", worst))
	table.insert(spans, label)
	if worst > 30 then
		table.insert(spanFail, label)
	end
end
report.AC6_spanSupport = spans
report.AC6_spanOver30 = spanFail

report.errors = errors
report.result = if #errors == 0 then "GAMEPLAY CHECKS C1-C13 PASS (read-only)" else "GAMEPLAY CHECK FAILURES: " .. #errors

-- Combined acceptance summary (correction 2026-11-11). The detailed arrays above stay unchanged;
-- this block decides acceptance from ALL of them, so a regression in AC6 or in any non-waived AC2
-- viewpoint can never read as a pass. The five owner-approved AC2 exceptions are reported
-- separately with their measured (failing) strict results; they are not counted as passes.
local function verdict(ok: boolean): string
	return if ok then "PASS" else "FAIL"
end
local waivedNames = {}
for n in WAIVED do
	table.insert(waivedNames, n)
end
table.sort(waivedNames)
local acc = {
	gameplay_C1_C13 = verdict(#errors == 0) .. string.format(" (%d errors)", #errors),
	AC6_structuralSupport = verdict(#spanFail == 0) .. string.format(" (%d slabs, %d over 30)", #slabParts, #spanFail),
	AC6_colorRestrictions = verdict(#reserved == 0) .. string.format(" (%d unapproved reserved hues; %d declared warning uses)", #reserved, #reservedUse),
	AC2_strict_nonWaived = verdict(#newFail == 0) .. string.format(" (%d of %d spawns + lobby centre checked; failing: %s)", #spawns - #waivedLines, #spawns, if #newFail == 0 then "none" else table.concat(newFail, ", ")),
	AC2_ownerApprovedExceptions = { spawns = waivedNames, approved = "owner, 2026-11-11 (limited five-spawn waiver)", measuredStrict = waivedLines },
}
acc.overall = verdict(#errors == 0 and #spanFail == 0 and #reserved == 0 and #newFail == 0)
report.ACCEPTANCE = acc
_G.AUDIT8A2B_PASS = acc.overall == "PASS"
return game:GetService("HttpService"):JSONEncode(report)
