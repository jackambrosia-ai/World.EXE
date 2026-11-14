-- WORLD.EXE Map 1 (Stable Simulation) walk graph library. READ-ONLY: never mutates the place.
-- Loaded by 3_measure_area.luau and 5_check_map1.luau via HttpService:GetAsync + loadstring.
--
-- Model: a global XZ grid (spacing S studs). For every grid column, each collidable Part top face
-- (Block or vertical-axis Cylinder, slope <= 40 deg, face >= 2.5 studs in both directions) that covers
-- the column gives a node at the face height. A node is kept only if a 2 x 5 x 2 character envelope
-- above it (y+0.6 .. y+5.6) is free of collidable geometry (OBB point test). Links:
--   walk   8-neighbour columns, |dy| <= 2.1, ray at +2.5 clear (RespectCanCollide)
--   jump   from an edge node, columns within 6 studs, rise 2.1 < dy <= 6.5 (stock JumpHeight 7.2),
--          vertical ray then horizontal ray at the upper height + 3 clear
--   drop   from an edge node, columns within 6 studs, dy < -2.1 (down to -80), horizontal ray at
--          the upper height + 2.5 then a down ray clear (rails 4 high block both jumps and drops)
-- Costs are horizontal studs (octile), so Dijkstra distance / 16 = walk seconds (WalkSpeed 16).
local W = {}

W.S = 3
local S = W.S
local UPCOS = math.cos(math.rad(40))
local WALK_DY, JUMP_UP, DROP_MAX, JUMP_R = 2.1, 6.5, 80, 6

local function key(i, j)
	return (i + 50000) * 200000 + (j + 50000)
end
W.key = key

local function faceOf(p: BasePart)
	if not p:IsA("Part") then
		return nil -- WedgePart, MeshPart, Union: not modelled (counted as skipped)
	end
	local shape = p.Shape
	if shape ~= Enum.PartType.Block and shape ~= Enum.PartType.Cylinder then
		return nil
	end
	local cf, sz = p.CFrame, p.Size
	local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local halves = { sz.X / 2, sz.Y / 2, sz.Z / 2 }
	local best, bi, sgn = -1, 1, 1
	for i = 1, 3 do
		local d = axes[i].Y
		if math.abs(d) > best then
			best, bi, sgn = math.abs(d), i, (d >= 0 and 1 or -1)
		end
	end
	if best < UPCOS then
		return nil
	end
	local n = axes[bi] * sgn
	local c = cf.Position + n * halves[bi]
	if shape == Enum.PartType.Cylinder then
		if bi ~= 1 then
			return nil
		end
		local r = math.min(sz.Y, sz.Z) / 2
		if r < 1.25 then
			return nil
		end
		return { kind = "disc", n = n, c = c, r = r, ex = r, ez = r }
	end
	local o = {}
	for i = 1, 3 do
		if i ~= bi then
			table.insert(o, i)
		end
	end
	local a1, h1, a2, h2 = axes[o[1]], halves[o[1]], axes[o[2]], halves[o[2]]
	if h1 < 1.25 or h2 < 1.25 then
		return nil
	end
	return {
		kind = "plane", n = n, c = c, a1 = a1, h1 = h1, a2 = a2, h2 = h2,
		ex = math.abs(a1.X) * h1 + math.abs(a2.X) * h2,
		ez = math.abs(a1.Z) * h1 + math.abs(a2.Z) * h2,
	}
end
W.faceOf = faceOf

local function inside(q: BasePart, pt: Vector3): boolean
	local l = q.CFrame:PointToObjectSpace(pt)
	local h = q.Size / 2
	if q:IsA("Part") and q.Shape == Enum.PartType.Cylinder then
		return math.abs(l.X) <= h.X and (l.Y * l.Y + l.Z * l.Z) <= math.min(h.Y, h.Z) ^ 2
	elseif q:IsA("Part") and q.Shape == Enum.PartType.Ball then
		return l.Magnitude <= h.X
	end
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end

-- opts: roots {Instance}, limit (abs XZ), yieldEvery
function W.build(opts)
	local roots = opts.roots
	local limit = opts.limit or 1200
	local ov = OverlapParams.new()
	ov.FilterType = Enum.RaycastFilterType.Include
	ov.FilterDescendantsInstances = roots
	ov.RespectCanCollide = true
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = roots
	rp.RespectCanCollide = true

	local G = { nx = {}, ny = {}, nz = {}, np = {}, cols = {}, parts = {}, skipped = 0, rp = rp, adj = {}, cardinal = {} }
	local partList = {}
	for _, r in roots do
		for _, d in r:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then
				table.insert(partList, d)
			end
		end
	end
	local count = 0
	for pi, p in partList do
		local f = faceOf(p)
		if not f then
			G.skipped += 1
			continue
		end
		G.parts[pi] = p
		local c = f.c
		local i0, i1 = math.ceil((c.X - f.ex) / S), math.floor((c.X + f.ex) / S)
		local j0, j1 = math.ceil((c.Z - f.ez) / S), math.floor((c.Z + f.ez) / S)
		for i = i0, i1 do
			local x = i * S
			if math.abs(x) > limit then
				continue
			end
			for j = j0, j1 do
				local z = j * S
				if math.abs(z) > limit then
					continue
				end
				local y = c.Y - (f.n.X * (x - c.X) + f.n.Z * (z - c.Z)) / f.n.Y
				local v = Vector3.new(x, y, z)
				local d = v - c
				local ok
				if f.kind == "disc" then
					ok = (d - f.n * d:Dot(f.n)).Magnitude <= f.r + 0.01
				else
					ok = math.abs(d:Dot(f.a1)) <= f.h1 + 0.01 and math.abs(d:Dot(f.a2)) <= f.h2 + 0.01
				end
				if not ok then
					continue
				end
				-- headroom envelope
				local blocked = false
				local hits = workspace:GetPartBoundsInBox(CFrame.new(x, y + 3.1, z), Vector3.new(2, 5, 2), ov)
				for _, q in hits do
					if q ~= p and q.CanCollide then
						for _, dy in { 0.8, 2.6, 4.6 } do
							for _, o in { Vector3.zero, Vector3.new(0.9, 0, 0.9), Vector3.new(-0.9, 0, 0.9), Vector3.new(0.9, 0, -0.9), Vector3.new(-0.9, 0, -0.9) } do
								if inside(q, Vector3.new(x, y + dy, z) + o) then
									blocked = true
									break
								end
							end
							if blocked then
								break
							end
						end
					end
					if blocked then
						break
					end
				end
				if blocked then
					continue
				end
				local k = key(i, j)
				local col = G.cols[k]
				if col then
					local dup = false
					for _, m in col do
						if math.abs(G.ny[m] - y) < 0.35 then
							dup = true
							break
						end
					end
					if dup then
						continue
					end
				else
					col = {}
					G.cols[k] = col
				end
				local n = #G.nx + 1
				G.nx[n], G.ny[n], G.nz[n], G.np[n] = x, y, z, pi
				table.insert(col, n)
				count += 1
				if count % 3000 == 0 then
					task.wait()
				end
			end
		end
		if pi % 200 == 0 then
			task.wait()
		end
	end
	G.n = #G.nx
	return G
end

local function clear(G, a: Vector3, b: Vector3): boolean
	local d = b - a
	if d.Magnitude < 1e-3 then
		return true
	end
	return workspace:Raycast(a, d, G.rp) == nil
end

local CARD = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local DIAG = { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
local FAR = {}
for di = -2, 2 do
	for dj = -2, 2 do
		if (di ~= 0 or dj ~= 0) and (di * di + dj * dj) * S * S <= JUMP_R * JUMP_R + 0.01 then
			table.insert(FAR, { di, dj })
		end
	end
end

-- Adjacency for node n (cached): flat list {m, cost, kind(1 walk, 2 jump, 3 drop), ...}
function W.neighbours(G, n)
	local a = G.adj[n]
	if a then
		return a
	end
	a = {}
	local x, y, z = G.nx[n], G.ny[n], G.nz[n]
	local i, j = math.round(x / S), math.round(z / S)
	local card = 0
	local function walk(list, cost, isCard)
		for _, d in list do
			local col = G.cols[key(i + d[1], j + d[2])]
			if col then
				for _, m in col do
					local dy = G.ny[m] - y
					if math.abs(dy) <= WALK_DY then
						if clear(G, Vector3.new(x, y + 2.5, z), Vector3.new(G.nx[m], G.ny[m] + 2.5, G.nz[m])) then
							table.insert(a, m)
							table.insert(a, cost)
							table.insert(a, 1)
							if isCard then
								card += 1
							end
						end
					end
				end
			end
		end
	end
	walk(CARD, S, true)
	walk(DIAG, S * math.sqrt(2), false)
	if card < 4 then
		for _, d in FAR do
			local col = G.cols[key(i + d[1], j + d[2])]
			if col then
				local hz = S * math.sqrt(d[1] * d[1] + d[2] * d[2])
				for _, m in col do
					local mx, my, mz = G.nx[m], G.ny[m], G.nz[m]
					local dy = my - y
					if dy > WALK_DY and dy <= JUMP_UP then
						local top = my + 3
						if clear(G, Vector3.new(x, y + 2.5, z), Vector3.new(x, top, z)) and clear(G, Vector3.new(x, top, z), Vector3.new(mx, top, mz)) then
							table.insert(a, m)
							table.insert(a, hz + 1)
							table.insert(a, 2)
						end
					elseif dy < -WALK_DY and dy >= -DROP_MAX then
						local top = y + 2.5
						if clear(G, Vector3.new(x, top, z), Vector3.new(mx, top, mz)) and clear(G, Vector3.new(mx, top, mz), Vector3.new(mx, my + 0.5, mz)) then
							table.insert(a, m)
							table.insert(a, hz + 1)
							table.insert(a, 3)
						end
					end
				end
			end
		end
	end
	G.adj[n] = a
	G.cardinal[n] = card
	return a
end

-- Dijkstra from a list of source nodes. Returns dist table (node -> studs).
function W.dijkstra(G, sources, maxDist, skip)
	maxDist = maxDist or math.huge
	skip = skip or {}
	local dist = {}
	local heap, hd = {}, {}
	local function push(n, d)
		table.insert(heap, n)
		table.insert(hd, d)
		local k = #heap
		while k > 1 do
			local p = k // 2
			if hd[p] <= hd[k] then
				break
			end
			heap[p], heap[k] = heap[k], heap[p]
			hd[p], hd[k] = hd[k], hd[p]
			k = p
		end
	end
	local function pop()
		local n, d = heap[1], hd[1]
		local last = #heap
		heap[1], hd[1] = heap[last], hd[last]
		heap[last], hd[last] = nil, nil
		last -= 1
		local k = 1
		while true do
			local l, r, s = 2 * k, 2 * k + 1, k
			if l <= last and hd[l] < hd[s] then
				s = l
			end
			if r <= last and hd[r] < hd[s] then
				s = r
			end
			if s == k then
				break
			end
			heap[s], heap[k] = heap[k], heap[s]
			hd[s], hd[k] = hd[k], hd[s]
			k = s
		end
		return n, d
	end
	for _, s in sources do
		dist[s] = 0
		push(s, 0)
	end
	local steps = 0
	while #heap > 0 do
		local n, d = pop()
		if d > (dist[n] or math.huge) or d > maxDist then
			continue
		end
		local a = W.neighbours(G, n)
		for q = 1, #a, 3 do
			local m, c = a[q], a[q + 1]
			if skip[m] then
				continue
			end
			local nd = d + c
			if nd < (dist[m] or math.huge) then
				dist[m] = nd
				push(m, nd)
			end
		end
		steps += 1
		if steps % 1500 == 0 then
			task.wait()
		end
	end
	return dist
end

function W.nearest(G, pos: Vector3, maxH: number?, maxDY: number?)
	maxH = maxH or 30
	maxDY = maxDY or 8
	local best, bd = nil, math.huge
	local i0, j0 = math.round(pos.X / S), math.round(pos.Z / S)
	local r = math.ceil(maxH / S)
	for di = -r, r do
		for dj = -r, r do
			local col = G.cols[key(i0 + di, j0 + dj)]
			if col then
				for _, m in col do
					local dy = math.abs(G.ny[m] - pos.Y)
					if dy <= maxDY then
						local d = (Vector3.new(G.nx[m], G.ny[m], G.nz[m]) - pos).Magnitude
						if d < bd then
							best, bd = m, d
						end
					end
				end
			end
		end
	end
	return best, bd
end

function W.tier(y: number): string
	if y < 12 then
		return "T0"
	elseif y < 36 then
		return "T24"
	elseif y < 60 then
		return "T48"
	elseif y < 100 then
		return "T72"
	end
	return "High"
end

return W
