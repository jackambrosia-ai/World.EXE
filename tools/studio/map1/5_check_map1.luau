-- WORLD.EXE Map 1 check (READ-ONLY, Edit mode). Usage:
--   _G.MAP1_LABEL = "after"; task.spawn(loadstring(<this file>)); poll _G.MAP1_CHECK.state
-- Needs lib_walkgraph.luau, 4_script_hashes.luau (served at _G.MAP1_BASE) and the "before" script
-- inventory at _G.MAP1_NOTES .. "scripts_before.json" (written by 4_script_hashes.luau before any change).
-- Posts check_<label>.json to the sink. Checks:
--   K1 overlap      expansion collidables vs existing collidables outside Map1Expansion (OBB SAT, 0.05 tol;
--                   cut pieces count as existing). Soft overlaps with decor are counted, not failed.
--   K2 spawns       no expansion part (any) in an ArenaSpawn / lobby spawn box (footprint +1, 8 high).
--   K3 markers      no expansion collidable at hazard/gameplay markers (footprint +1 or +2, up to +8;
--                   FloodZone base-1..+7; Stabilizer InteractionRadius; SupplyLandingPoint column to Y160
--                   (any part); BounceSurface apex to Y40 (any part)); no expansion collidable on any
--                   DroneWaypoint link segment.
--   K4 reachability every BossSectorFloor reachable from the 16 arena spawns and back (walk graph: walk,
--                   jump rise <= 6.5 / gap <= 6, drops), and still reachable with each of its routes
--                   removed in turn (>= 2 independent routes).
--   K5 rails        every expansion walk-surface edge with a drop > 8 studs is guarded by a collidable within
--                   3 studs at +2 (rails are 4 high); Rail parts >= 4 high; ramps <= 35 deg.
--   K6 scripts      every LuaSourceContainer hash equals scripts_before.json except Config (documented).
--   K7 structure    attributes (Map1Expansion, Map1Role), one boss floor set + one invisible non-collidable
--                   bounds part per sector, no tags / scripts under Map1Expansion, expansion walk nodes
--                   inside Config.ArenaBounds, lobby spawns outside them; part / light counts.
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local base = _G.MAP1_BASE or "http://127.0.0.1:8775/map1/"
local notes = _G.MAP1_NOTES or "http://127.0.0.1:8775/notes/"
local sink = _G.MAP1_SINK or "http://127.0.0.1:8775/sink/"
local label = _G.MAP1_LABEL or "run"
_G.MAP1_CHECK = { state = "running" }

local SECTORS = { "ContainmentVault", "TestingPit", "Foundry" }
local ROUTES = {
	ContainmentVault = { Ground = { "RN_Ground", "RN_Gate" }, Elevated = { "RN_Bridge" } },
	TestingPit = { Ground = { "RW_Ground", "RW_Gate" }, Elevated = { "RW_Bridge", "RW_Gantry" } },
	Foundry = { Ground = { "RE_Ground", "RE_Gate" }, Elevated = { "RE_Bridge" } },
}

local function aabb(p: BasePart)
	local cf, s = p.CFrame, p.Size
	local h = (cf.RightVector * s.X):Abs() / 2 + (cf.UpVector * s.Y):Abs() / 2 + (cf.LookVector * s.Z):Abs() / 2
	return cf.Position - h, cf.Position + h
end
local function boxHit(a0, a1, b0, b1, tol)
	tol = tol or 0
	return a0.X < b1.X - tol and a1.X > b0.X + tol and a0.Y < b1.Y - tol and a1.Y > b0.Y + tol and a0.Z < b1.Z - tol and a1.Z > b0.Z + tol
end
local function obb(cfA, hA, cfB, hB)
	local A = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local B = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local T = cfB.Position - cfA.Position
	local axes = { A[1], A[2], A[3], B[1], B[2], B[3] }
	for i = 1, 3 do
		for j = 1, 3 do
			local c = A[i]:Cross(B[j])
			if c.Magnitude > 1e-5 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, L in axes do
		local ra = math.abs(A[1]:Dot(L)) * hA.X + math.abs(A[2]:Dot(L)) * hA.Y + math.abs(A[3]:Dot(L)) * hA.Z
		local rb = math.abs(B[1]:Dot(L)) * hB.X + math.abs(B[2]:Dot(L)) * hB.Y + math.abs(B[3]:Dot(L)) * hB.Z
		if math.abs(T:Dot(L)) > ra + rb then
			return false
		end
	end
	return true
end
local function inPart(p: BasePart, pt: Vector3)
	local l = p.CFrame:PointToObjectSpace(pt)
	local h = p.Size / 2
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end

local ok, err = pcall(function()
	local W = loadstring(HS:GetAsync(base .. "lib_walkgraph.luau", true))()
	local map = workspace.WORLD_EXE.Map
	local exp = map:FindFirstChild("Map1Expansion")
	assert(exp, "Map1Expansion missing")
	local R = { label = label, when = os.date("!%Y-%m-%dT%H:%M:%SZ"), version = exp:GetAttribute("Map1ExpansionVersion") }
	local expParts, expColl, existing = {}, {}, {}
	for _, d in exp:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(expParts, d)
			if d.CanCollide and d:GetAttribute("Map1Role") ~= "CutPiece" then
				table.insert(expColl, d)
			end
		end
	end
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(exp) then
			table.insert(existing, d)
		end
	end
	for _, d in exp:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Map1Role") == "CutPiece" then
			table.insert(existing, d)
		end
	end

	-- K1 -----------------------------------------------------------------------------------------
	local hard, soft = {}, 0
	local exAABB = {}
	for i, e in existing do
		local a, b = aabb(e)
		exAABB[i] = { a, b }
	end
	for i, p in expColl do
		local a, b = aabb(p)
		for j, e in existing do
			local ea = exAABB[j]
			if boxHit(a, b, ea[1], ea[2], 0.05) and obb(p.CFrame, p.Size / 2 - Vector3.one * 0.05, e.CFrame, e.Size / 2 - Vector3.one * 0.05) then
				if e.CanCollide then
					table.insert(hard, p.Name .. " x " .. e:GetFullName())
				else
					soft += 1
				end
			end
		end
		if i % 40 == 0 then
			task.wait()
		end
	end
	R.K1 = { pass = #hard == 0, hardOverlaps = hard, softOverlapsWithDecor = soft, expansionCollidables = #expColl }

	-- K2 / K3 ---------------------------------------------------------------------------------------
	local function anyExpIn(c0, c1, collOnly)
		local hits = {}
		for _, p in expParts do
			if (not collOnly or p.CanCollide) and p:GetAttribute("Map1Role") ~= "Bounds" then
				local a, b = aabb(p)
				if boxHit(a, b, c0, c1, 0) and obb(p.CFrame, p.Size / 2, CFrame.new((c0 + c1) / 2), (c1 - c0) / 2) then
					table.insert(hits, p.Name)
				end
			end
		end
		return hits
	end
	local spawnFails, nsp = {}, 0
	local lobbySpawns = {}
	for _, s in CS:GetTagged("ArenaSpawn") do
		if s:IsA("BasePart") and s:IsDescendantOf(map) then
			nsp += 1
			local a, b = aabb(s)
			local h = anyExpIn(Vector3.new(a.X - 1, b.Y, a.Z - 1), Vector3.new(b.X + 1, b.Y + 8, b.Z + 1), false)
			if #h > 0 then
				table.insert(spawnFails, s.Name .. ": " .. table.concat(h, ","))
			end
		end
	end
	for _, s in workspace.WORLD_EXE.Lobby:GetDescendants() do
		if s:IsA("SpawnLocation") then
			table.insert(lobbySpawns, s)
			local a, b = aabb(s)
			local h = anyExpIn(Vector3.new(a.X - 1, b.Y, a.Z - 1), Vector3.new(b.X + 1, b.Y + 8, b.Z + 1), false)
			if #h > 0 then
				table.insert(spawnFails, s.Name .. ": " .. table.concat(h, ","))
			end
		end
	end
	R.K2 = { pass = #spawnFails == 0, arenaSpawns = nsp, lobbySpawns = #lobbySpawns, fails = spawnFails }

	local markerFails, nmark = {}, 0
	local tags = { "CorruptionNode", "DecayTile", "FragmentSpawn", "MagneticPoint", "MagneticProp", "SlipSurface", "FloodZone", "Stabilizer", "SupplyLandingPoint", "BounceSurface" }
	for _, tag in tags do
		for _, m in CS:GetTagged(tag) do
			if not m:IsDescendantOf(map) then
				continue
			end
			local parts = {}
			if m:IsA("BasePart") then
				parts = { m }
			else
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						table.insert(parts, d)
					end
				end
			end
			for _, mp in parts do
				nmark += 1
				local a, b = aabb(mp)
				local h
				if tag == "FloodZone" then
					h = anyExpIn(Vector3.new(a.X, a.Y - 1, a.Z), Vector3.new(b.X, a.Y + 7, b.Z), true)
				elseif tag == "SupplyLandingPoint" then
					h = anyExpIn(Vector3.new(a.X - 1, a.Y, a.Z - 1), Vector3.new(b.X + 1, 160, b.Z + 1), false)
				elseif tag == "BounceSurface" then
					h = anyExpIn(Vector3.new(a.X - 2, b.Y, a.Z - 2), Vector3.new(b.X + 2, 40, b.Z + 2), false)
				elseif tag == "Stabilizer" then
					local r = (m:GetAttribute("InteractionRadius") or 10)
					local c = (a + b) / 2
					h = anyExpIn(Vector3.new(c.X - r, a.Y - 1, c.Z - r), Vector3.new(c.X + r, b.Y + 8, c.Z + r), true)
				else
					h = anyExpIn(Vector3.new(a.X - 1, a.Y - 1, a.Z - 1), Vector3.new(b.X + 1, b.Y + 8, b.Z + 1), true)
				end
				if #h > 0 then
					table.insert(markerFails, tag .. " " .. mp:GetFullName() .. ": " .. table.concat(h, ","))
				end
			end
		end
		task.wait()
	end
	-- drone links
	local wps = {}
	for _, w in CS:GetTagged("DroneWaypoint") do
		if w:IsDescendantOf(map) and w:IsA("BasePart") then
			wps[w:GetAttribute("WaypointId")] = w
		end
	end
	local linkFails, nlinks = {}, 0
	for id, w in wps do
		for other in string.gmatch(tostring(w:GetAttribute("Links") or ""), "[^,%s]+") do
			local o = wps[other]
			if o and id < other then
				nlinks += 1
				local p0, p1 = w.Position, o.Position
				local c0, c1 = p0:Min(p1) - Vector3.one, p0:Max(p1) + Vector3.one
				for _, p in expColl do
					local a, b = aabb(p)
					if boxHit(a, b, c0, c1, 0) then
						local L = (p1 - p0).Magnitude
						for t = 0, L, 1 do
							if inPart(p, p0 + (p1 - p0).Unit * t) then
								table.insert(linkFails, id .. "-" .. other .. " x " .. p.Name)
								break
							end
						end
					end
				end
			end
		end
	end
	R.K3 = { pass = #markerFails == 0 and #linkFails == 0, markerParts = nmark, droneLinks = nlinks, markerFails = markerFails, droneLinkFails = linkFails }

	-- K4 -----------------------------------------------------------------------------------------
	local G = W.build({ roots = { map }, limit = 1200 })
	local spawns = {}
	for _, s in CS:GetTagged("ArenaSpawn") do
		if s:IsDescendantOf(map) and s:IsA("BasePart") then
			local n = W.nearest(G, s.Position + Vector3.new(0, s.Size.Y / 2, 0), 9, 3)
			if n then
				table.insert(spawns, n)
			end
		end
	end
	local reach = W.dijkstra(G, spawns)
	local bossNodes, routeNodes = {}, {}
	for n = 1, G.n do
		local p = G.parts[G.np[n]]
		local s = p:GetAttribute("BossSectorFloor")
		if s then
			bossNodes[s] = bossNodes[s] or {}
			table.insert(bossNodes[s], n)
		end
		for sec, rt in ROUTES do
			for rname, prefixes in rt do
				for _, pre in prefixes do
					if string.sub(p.Name, 1, #pre) == pre then
						routeNodes[sec .. "." .. rname] = routeNodes[sec .. "." .. rname] or {}
						routeNodes[sec .. "." .. rname][n] = true
					end
				end
			end
		end
	end
	local K4 = { pass = true, sectors = {} }
	for _, s in SECTORS do
		local nodes = bossNodes[s] or {}
		local reached = 0
		for _, n in nodes do
			if reach[n] then
				reached += 1
			end
		end
		local back = W.dijkstra(G, nodes)
		local backN = 0
		for _, sp in spawns do
			if back[sp] then
				backN += 1
			end
		end
		local entry = { floorNodes = #nodes, reachedFromSpawns = reached, spawnsReachableFromFloor = backN, spawns = #spawns, withoutRoute = {} }
		for rname in ROUTES[s] do
			local skip = routeNodes[s .. "." .. rname] or {}
			local d = W.dijkstra(G, spawns, nil, skip)
			local r2 = 0
			for _, n in nodes do
				if d[n] then
					r2 += 1
				end
			end
			local back2 = W.dijkstra(G, nodes, nil, skip)
			local b2 = 0
			for _, sp in spawns do
				if back2[sp] then
					b2 += 1
				end
			end
			local cnt = 0
			for _ in skip do
				cnt += 1
			end
			entry.withoutRoute[rname] = { removedNodes = cnt, reached = r2, spawnsBack = b2 }
			if r2 == 0 or b2 == 0 then
				K4.pass = false
			end
		end
		if #nodes == 0 or reached < #nodes * 0.95 or backN < #spawns then
			K4.pass = false
		end
		K4.sectors[s] = entry
	end
	R.K4 = K4

	-- K5 -----------------------------------------------------------------------------------------
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { map }
	rp.RespectCanCollide = true
	local unguarded, checked = {}, 0
	local ugBySector, ugSamples = {}, {}
	local DIRS = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	for n = 1, G.n do
		local p = G.parts[G.np[n]]
		local sec = p:GetAttribute("Map1Expansion")
		if not sec or sec == "HallOpenings" or not reach[n] then
			continue
		end
		W.neighbours(G, n)
		if (G.cardinal[n] or 0) >= 4 then
			continue
		end
		local pos = Vector3.new(G.nx[n], G.ny[n], G.nz[n])
		local i, j = math.round(pos.X / W.S), math.round(pos.Z / W.S)
		for _, d in DIRS do
			-- skip directions that have a walkable column neighbour within 2.1
			-- a column node within 2.1 (walkable) or higher than y - 8.5 (step-up wall / small drop) means
			-- this direction is not an unguarded drop
			local col = G.cols[W.key(i + d.X, j + d.Z)]
			local walkable = false
			for _, m in col or {} do
				if G.ny[m] >= pos.Y - 8.5 then
					walkable = true
				end
			end
			if walkable then
				continue
			end
			checked += 1
			if workspace:Raycast(pos + Vector3.new(0, 2, 0), d * 3, rp) then
				continue
			end
			-- 2 x 0.4 x 2 block swept down 9.5 studs from 1 stud above the node level, 3 studs out
			-- (a character-sized probe; sub-stud seams between ring segments are not drops)
			local probe = pos + d * 3 + Vector3.new(0, 1, 0)
			local hit = workspace:Blockcast(CFrame.new(probe), Vector3.new(2, 0.4, 2), Vector3.new(0, -9.5, 0), rp)
			if not hit then
				ugBySector[sec] = (ugBySector[sec] or 0) + 1
				table.insert(unguarded, n)
				if #ugSamples < 40 then
					local key = p.Name .. " " .. string.format("(%d,%d,%d) dir %d,%d", pos.X, pos.Y, pos.Z, d.X, d.Z)
					table.insert(ugSamples, key)
				end
			end
		end
		if n % 2000 == 0 then
			task.wait()
		end
	end
	local railShort, steep = {}, {}
	for _, p in expParts do
		local role = p:GetAttribute("Map1Role")
		if role == "Rail" and p.Size.Y < 3.99 then
			table.insert(railShort, p.Name)
		elseif role == "Ramp" then
			local ang = math.deg(math.asin(math.abs(p.CFrame.LookVector.Y)))
			if ang > 35 then
				table.insert(steep, p.Name .. string.format(" %.1f", ang))
			end
		end
	end
	local nUg = #unguarded
	R.K5 = { pass = nUg == 0 and #railShort == 0 and #steep == 0, edgeDirectionsChecked = checked, unguardedDropsOver8 = nUg, bySector = ugBySector, samples = ugSamples, railsUnder4 = railShort, rampsOver35deg = steep }

	-- K6 -----------------------------------------------------------------------------------------
	local before = HS:JSONDecode(HS:GetAsync(notes .. "scripts_before.json", true))
	_G.MAP1_LABEL = label
	loadstring(HS:GetAsync(base .. "4_script_hashes.luau", true))()
	local now = _G.MAP1_SCRIPTS
	local changed, added, removed = {}, {}, {}
	for k, v in before.scripts do
		if now.scripts[k] == nil then
			table.insert(removed, k)
		elseif now.scripts[k] ~= v then
			table.insert(changed, k)
		end
	end
	for k in now.scripts do
		if before.scripts[k] == nil then
			table.insert(added, k)
		end
	end
	local onlyConfig = #added == 0 and #removed == 0 and (#changed == 0 or (#changed == 1 and changed[1] == "ReplicatedStorage.WORLD_EXE.Shared.Config|ModuleScript"))
	R.K6 = { pass = onlyConfig, before = before.count, after = now.count, changed = changed, added = added, removed = removed }

	-- K7 -----------------------------------------------------------------------------------------
	local probs = {}
	local counts, lightsN = {}, 0
	local boundsParts, bossFloors = {}, {}
	for _, d in exp:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			table.insert(probs, "script under Map1Expansion: " .. d:GetFullName())
		elseif d:IsA("BasePart") then
			local s, role = d:GetAttribute("Map1Expansion"), d:GetAttribute("Map1Role")
			if not s or not role then
				table.insert(probs, "missing attributes: " .. d:GetFullName())
			end
			if #d:GetTags() > 0 then
				table.insert(probs, "tagged: " .. d:GetFullName())
			end
			counts[s or "?"] = counts[s or "?"] or { parts = 0, collidable = 0, lights = 0 }
			counts[s or "?"].parts += 1
			if d.CanCollide then
				counts[s or "?"].collidable += 1
			end
			if role == "Bounds" then
				local nm = d.Name:match("^BossSector_(.+)_Bounds$")
				boundsParts[nm or "?"] = (d.Transparency == 1 and not d.CanCollide and not d.CanQuery) and "ok" or "NOT invisible/non-collidable"
			end
			local bf = d:GetAttribute("BossSectorFloor")
			if bf then
				bossFloors[bf] = (bossFloors[bf] or 0) + 1
			end
		elseif d:IsA("Light") then
			lightsN += 1
			local s = d.Parent:GetAttribute("Map1Expansion") or "?"
			counts[s] = counts[s] or { parts = 0, collidable = 0, lights = 0 }
			counts[s].lights += 1
		elseif (d:IsA("SurfaceGui") and d.Name == "Sign" and d.Parent:IsA("BasePart")) or (d:IsA("TextLabel") and d.Name == "Text" and d.Parent:IsA("SurfaceGui")) then
			-- v8 navigation signs: SurfaceGui + TextLabel only (no scripts, not interactive)
		elseif not (d:IsA("Folder") or d:IsA("Model")) then
			table.insert(probs, "unexpected instance: " .. d:GetFullName() .. " " .. d.ClassName)
		end
	end
	for _, s in SECTORS do
		if boundsParts[s] ~= "ok" then
			table.insert(probs, "bounds part missing/invalid for " .. s)
		end
		if not bossFloors[s] then
			table.insert(probs, "no BossSectorFloor for " .. s)
		end
	end
	local csrc = game.ReplicatedStorage.WORLD_EXE.Shared.Config.Source
	local function vec(name)
		local a, b, c = csrc:match("Config%." .. name .. "%s*=%s*Vector3%.new%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
		return Vector3.new(tonumber(a), tonumber(b), tonumber(c))
	end
	local lo, hi = vec("ArenaBoundsMin"), vec("ArenaBoundsMax")
	local outN = 0
	for n = 1, G.n do
		local p = G.parts[G.np[n]]
		if p:GetAttribute("Map1Expansion") and reach[n] then
			local x, y, z = G.nx[n], G.ny[n] + 3, G.nz[n]
			if x < lo.X or x > hi.X or y < lo.Y or y > hi.Y or z < lo.Z or z > hi.Z then
				outN += 1
			end
		end
	end
	if outN > 0 then
		table.insert(probs, outN .. " reachable expansion walk nodes outside Config.ArenaBounds")
	end
	for _, s in lobbySpawns do
		local pp = s.Position + Vector3.new(0, s.Size.Y / 2 + 3, 0)
		if pp.X >= lo.X and pp.X <= hi.X and pp.Y >= lo.Y and pp.Y <= hi.Y and pp.Z >= lo.Z and pp.Z <= hi.Z then
			table.insert(probs, "lobby spawn inside ArenaBounds: " .. s.Name)
		end
	end
	local mapParts, mapColl, mapLights = 0, 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			mapParts += 1
			if d.CanCollide then
				mapColl += 1
			end
		elseif d:IsA("Light") then
			mapLights += 1
		end
	end
	R.K7 = { pass = #probs == 0, problems = probs, counts = counts, lights = lightsN, bossFloorParts = bossFloors,
		bounds = { min = { lo.X, lo.Y, lo.Z }, max = { hi.X, hi.Y, hi.Z } }, map = { parts = mapParts, collidable = mapColl, lights = mapLights } }

	R.overall = R.K1.pass and R.K2.pass and R.K3.pass and R.K4.pass and R.K5.pass and R.K6.pass and R.K7.pass
	local json = HS:JSONEncode(R)
	pcall(function()
		HS:PostAsync(sink .. "check_" .. label .. ".json", json)
	end)
	_G.MAP1_CHECK = { state = "done", report = R }
end)
if not ok then
	_G.MAP1_CHECK = { state = "error", err = tostring(err) }
end
