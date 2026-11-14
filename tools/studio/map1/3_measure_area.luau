-- WORLD.EXE Map 1: READ-ONLY playable-area and walk-time measurement (Edit mode).
-- Usage (execute_luau):  _G.MAP1_LABEL = "before"; task.spawn(loadstring(<this file>)); poll _G.MAP1_MEASURE
-- Needs lib_walkgraph.luau served at _G.MAP1_BASE (default http://127.0.0.1:8775/map1/).
-- Posts a JSON report to _G.MAP1_SINK (default http://127.0.0.1:8775/sink/) as area_<label>.json.
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local base = _G.MAP1_BASE or "http://127.0.0.1:8775/map1/"
local sink = _G.MAP1_SINK or "http://127.0.0.1:8775/sink/"
local label = _G.MAP1_LABEL or "run"
_G.MAP1_MEASURE = { state = "running" }
local ok, err = pcall(function()
	local W = loadstring(HS:GetAsync(base .. "lib_walkgraph.luau", true))()
	local map = workspace.WORLD_EXE.Map
	local t0 = os.clock()
	local G = W.build({ roots = { map }, limit = 1200 })
	local buildT = os.clock() - t0

	-- parse the Config source (require() caches stale values in Edit mode after a source edit)
	local csrc = game.ReplicatedStorage.WORLD_EXE.Shared.Config.Source
	local function vec(name)
		local a, b, c = csrc:match("Config%." .. name .. "%s*=%s*Vector3%.new%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
		return Vector3.new(tonumber(a), tonumber(b), tonumber(c))
	end
	local lo, hi = vec("ArenaBoundsMin"), vec("ArenaBoundsMax")
	local function inB(n)
		local x, y, z = G.nx[n], G.ny[n], G.nz[n]
		return x >= lo.X and x <= hi.X and y + 3 >= lo.Y and y + 3 <= hi.Y and z >= lo.Z and z <= hi.Z
	end

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

	local area = { all = {}, reachable = {}, reachableInBounds = {} }
	for n = 1, G.n do
		local t = W.tier(G.ny[n])
		area.all[t] = (area.all[t] or 0) + W.S * W.S
		if reach[n] then
			area.reachable[t] = (area.reachable[t] or 0) + W.S * W.S
			if inB(n) then
				area.reachableInBounds[t] = (area.reachableInBounds[t] or 0) + W.S * W.S
			end
		end
	end
	for _, k in { "all", "reachable", "reachableInBounds" } do
		local s = 0
		for _, v in area[k] do
			s += v
		end
		area[k].total = s
	end

	-- districts (hub) + any boss sectors present
	local points = _G.MAP1_POINTS or {
		CentralCore = Vector3.new(0, 0, 70),
		ResearchYard = Vector3.new(-200, 0, -90),
		Skybridge = Vector3.new(170, 0, 0),
		DataArchive = Vector3.new(0, 0, -200),
		CoolantReservoir = Vector3.new(0, -10, 200),
		OuterRing_N = Vector3.new(0, 24, -230),
	}
	local sectors = {}
	local exp = map:FindFirstChild("Map1Expansion")
	if exp then
		for _, d in exp:GetDescendants() do
			if d:IsA("BasePart") and d.Name:match("^BossSector_.+_Bounds$") then
				local nm = d.Name:match("^BossSector_(.+)_Bounds$")
				sectors[nm] = d
				points["Boss_" .. nm] = Vector3.new(d.Position.X, d:GetAttribute("FloorY") or 0, d.Position.Z)
			end
		end
	end
	local pnode, plist = {}, {}
	for name, p in points do
		local n, d = W.nearest(G, p, 45, 10)
		pnode[name] = n
		table.insert(plist, name)
	end
	table.sort(plist)
	local walk = {}
	for _, a in plist do
		walk[a] = {}
		if pnode[a] then
			local dist = W.dijkstra(G, { pnode[a] })
			for _, b in plist do
				if b ~= a and pnode[b] then
					local d = dist[pnode[b]]
					walk[a][b] = d and { studs = math.floor(d + 0.5), seconds = math.floor(d / 16 * 10 + 0.5) / 10 } or "unreachable"
				end
			end
		end
	end
	local straight = {}
	for _, a in plist do
		straight[a] = {}
		for _, b in plist do
			if a ~= b then
				local pa, pb = points[a], points[b]
				straight[a][b] = math.floor((Vector3.new(pa.X, 0, pa.Z) - Vector3.new(pb.X, 0, pb.Z)).Magnitude + 0.5)
			end
		end
	end

	-- boss floors: reachability out and back
	local boss = {}
	if exp then
		for _, d in exp:GetDescendants() do
			if d:IsA("BasePart") then
				local s = d:GetAttribute("BossSectorFloor")
				if s then
					boss[s] = boss[s] or { nodes = {}, area = 0 }
				end
			end
		end
		for n = 1, G.n do
			local p = G.parts[G.np[n]]
			local s = p and p:GetAttribute("BossSectorFloor")
			if s then
				table.insert(boss[s].nodes, n)
			end
		end
		local spawnSet = {}
		for _, s in spawns do
			spawnSet[s] = true
		end
		for s, b in boss do
			local reached = 0
			for _, n in b.nodes do
				if reach[n] then
					reached += 1
				end
			end
			local back = W.dijkstra(G, b.nodes)
			local backOk = 0
			for _, sp in spawns do
				if back[sp] then
					backOk += 1
				end
			end
			boss[s] = {
				floorNodes = #b.nodes,
				floorArea = #b.nodes * W.S * W.S,
				reachedFromSpawns = reached,
				spawnsReachableFromFloor = backOk,
				spawnsTotal = #spawns,
			}
		end
	end

	local report = {
		label = label,
		when = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		grid = W.S,
		nodes = G.n,
		skippedNonBlockCollidables = G.skipped,
		buildSeconds = math.floor(buildT * 10) / 10,
		bounds = { min = { lo.X, lo.Y, lo.Z }, max = { hi.X, hi.Y, hi.Z } },
		spawnNodes = #spawns,
		areaStuds2 = area,
		points = (function()
			local o = {}
			for k, v in points do
				o[k] = { v.X, v.Y, v.Z, node = pnode[k] ~= nil }
			end
			return o
		end)(),
		walk = walk,
		straightLine = straight,
		bossFloors = boss,
	}
	local json = HS:JSONEncode(report)
	pcall(function()
		HS:PostAsync(sink .. "area_" .. label .. ".json", json)
	end)
	_G.MAP1_MEASURE = { state = "done", report = report, json = json }
end)
if not ok then
	_G.MAP1_MEASURE = { state = "error", err = tostring(err) }
end
