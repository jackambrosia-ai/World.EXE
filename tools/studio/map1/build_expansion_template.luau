-- WORLD.EXE Map 1 "Stable Simulation" expansion builder. GENERATED: edit gen_expansion.js / this
-- template, then run `node gen_expansion.js`. WORKING COPY ONLY (WorldEXE_Map1_StableSim_WORKING_*.rbxl).
--
-- Usage (Studio Edit mode, execute_luau):
--   _G.MAP1_BUILD_MODE = "dryrun" | "build"   (default "build")
--   task.spawn(loadstring(<this file>)); poll _G.MAP1_BUILD.state ("done"/"error"/"refused")
--
-- What "build" does (all-or-nothing up to the final parenting):
--   1. Refuses if Workspace.WORLD_EXE.Map.Map1Expansion exists with another VERSION / part count
--      ("already built" no-op when it matches exactly), or if leftover cut originals exist.
--   2. Plans hall OPENINGS: every existing part in Map intersecting a CUTS box is either split into
--      axis-aligned remainder pieces (plain unrotated/90-degree Block Parts without tags/children) or,
--      for decorative parts that cannot be split, moved whole. Tagged parts, SpawnLocations and
--      collidable unsplittable parts make the build refuse. ISOLATE paths are moved whole.
--   3. Builds every spec row off-tree and checks each new collidable against existing collidables
--      (OBB separating-axis test, 0.05 stud tolerance; cut parts are replaced by their pieces).
--      Any hard conflict refuses the build with nothing changed.
--   4. Moves cut originals to ServerStorage.Map1_Isolated.CutOriginals and isolated parts to
--      ServerStorage.Map1_Isolated.ExpansionMoved (attribute Map1OrigParent = original parent path),
--      parents the pieces under Map1Expansion.HallOpenings, then parents everything in chunks and sets
--      Map1Expansion attribute Map1ExpansionVersion = VERSION.
-- Every new part carries Map1Expansion = <sector> and Map1Role = Floor|Ramp|Rail|Cover|Wall|Decor|
-- Bounds|CutPiece. Boss floors carry BossSectorFloor = <sector>. No tags, no scripts, no gameplay markers.
-- Undo: 9_remove_expansion.luau (removes only what it recognises and restores moved originals).
--@@SPEC@@

local mode = _G.MAP1_BUILD_MODE or "build"
_G.MAP1_BUILD = { state = "running", mode = mode }
local SS = game:GetService("ServerStorage")
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")

local function V(t)
	return Vector3.new(t[1], t[2], t[3])
end
local function resolve(path: string): Instance?
	local cur: Instance? = game
	for seg in string.gmatch(path, "[^%.]+") do
		if cur == game and seg == "Workspace" then
			cur = workspace
		else
			cur = cur and cur:FindFirstChild(seg)
		end
		if not cur then
			return nil
		end
	end
	return cur
end
local function aabb(p: BasePart)
	local cf, s = p.CFrame, p.Size
	local h = (cf.RightVector * s.X):Abs() / 2 + (cf.UpVector * s.Y):Abs() / 2 + (cf.LookVector * s.Z):Abs() / 2
	return cf.Position - h, cf.Position + h
end
local function boxHit(a0, a1, b0, b1, tol)
	tol = tol or 0
	return a0.X < b1.X - tol and a1.X > b0.X + tol and a0.Y < b1.Y - tol and a1.Y > b0.Y + tol and a0.Z < b1.Z - tol and a1.Z > b0.Z + tol
end
local function axisAligned(cf: CFrame): boolean
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.9999 then
			return false
		end
	end
	return true
end
-- OBB overlap (separating axis theorem); h = half sizes
local function obb(cfA: CFrame, hA: Vector3, cfB: CFrame, hB: Vector3): boolean
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
-- remainder boxes of box A minus box C (both {min,max})
local function subtract(a0, a1, c0, c1)
	c0 = Vector3.new(math.max(a0.X, c0.X), math.max(a0.Y, c0.Y), math.max(a0.Z, c0.Z))
	c1 = Vector3.new(math.min(a1.X, c1.X), math.min(a1.Y, c1.Y), math.min(a1.Z, c1.Z))
	local out = {}
	local function add(m0, m1)
		if m1.X - m0.X > 0.05 and m1.Y - m0.Y > 0.05 and m1.Z - m0.Z > 0.05 then
			table.insert(out, { m0, m1 })
		end
	end
	add(a0, Vector3.new(c0.X, a1.Y, a1.Z))
	add(Vector3.new(c1.X, a0.Y, a0.Z), a1)
	add(Vector3.new(c0.X, a0.Y, a0.Z), Vector3.new(c1.X, c0.Y, a1.Z))
	add(Vector3.new(c0.X, c1.Y, a0.Z), Vector3.new(c1.X, a1.Y, a1.Z))
	add(Vector3.new(c0.X, c0.Y, a0.Z), Vector3.new(c1.X, c1.Y, c0.Z))
	add(Vector3.new(c0.X, c0.Y, c1.Z), Vector3.new(c1.X, c1.Y, a1.Z))
	return out
end

local function finish(state, data)
	data = data or {}
	data.state = state
	data.mode = mode
	data.version = VERSION
	_G.MAP1_BUILD = data
end

local ok, err = pcall(function()
	-- ------------------------------------------------------------ 1. state
	local existing = map:FindFirstChild("Map1Expansion")
	if existing then
		local n = 0
		for _, d in existing:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Map1Expansion") ~= nil and d:GetAttribute("Map1Role") ~= "CutPiece" then
				n += 1
			end
		end
		if existing:GetAttribute("Map1ExpansionVersion") == VERSION and n == EXPECT.parts then
			finish("done", { message = "already built (" .. VERSION .. ", " .. n .. " spec parts); nothing changed" })
		else
			finish("refused", { message = ("Map1Expansion exists (version %s, %d spec parts, expected %d): run 9_remove_expansion.luau first"):format(tostring(existing:GetAttribute("Map1ExpansionVersion")), n, EXPECT.parts) })
		end
		return
	end
	local iso = SS:FindFirstChild("Map1_Isolated")
	for _, sub in { "CutOriginals", "ExpansionMoved" } do
		local f = iso and iso:FindFirstChild(sub)
		if f and #f:GetChildren() > 0 then
			finish("refused", { message = "ServerStorage.Map1_Isolated." .. sub .. " is not empty but Map1Expansion is missing: inconsistent state, run 9_remove_expansion.luau (restore) first" })
			return
		end
	end

	-- ------------------------------------------------------------ 2. plan cuts / isolations
	local existingParts = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local a, b = aabb(d)
			table.insert(existingParts, { p = d, a = a, b = b })
		end
	end
	local targets, order = {}, {}
	local problems = {}
	for _, c in CUTS do
		local c0, c1 = V(c.min), V(c.max)
		for _, e in existingParts do
			if boxHit(e.a, e.b, c0, c1, 0.01) then
				local t = targets[e.p]
				if not t then
					t = { part = e.p, boxes = {}, cuts = {} }
					targets[e.p] = t
					table.insert(order, t)
				end
				table.insert(t.boxes, { c0, c1 })
				table.insert(t.cuts, c.name)
			end
		end
	end
	for _, t in order do
		local p = t.part
		local splittable = p.ClassName == "Part" and p.Shape == Enum.PartType.Block and axisAligned(p.CFrame) and #p:GetChildren() == 0
		if #p:GetTags() > 0 or p:IsA("SpawnLocation") then
			table.insert(problems, "tagged/spawn part in a cut: " .. p:GetFullName())
		elseif splittable then
			t.policy = "split"
			local a, b = aabb(p)
			local pieces = { { a, b } }
			for _, bx in t.boxes do
				local nxt = {}
				for _, pc in pieces do
					if boxHit(pc[1], pc[2], bx[1], bx[2], 0) then
						for _, r in subtract(pc[1], pc[2], bx[1], bx[2]) do
							table.insert(nxt, r)
						end
					else
						table.insert(nxt, pc)
					end
				end
				pieces = nxt
			end
			t.pieces = pieces
		elseif not p.CanCollide then
			t.policy = "moveWhole"
			t.pieces = {}
		else
			table.insert(problems, "collidable part cannot be split: " .. p:GetFullName())
		end
	end
	local isoTargets = {}
	for _, path in ISOLATE do
		local inst = resolve(path)
		if not inst then
			table.insert(problems, "isolate path not found: " .. path)
		elseif #inst:GetTags() > 0 or not inst:IsA("BasePart") or inst.CanCollide then
			table.insert(problems, "isolate target is tagged / not a part / collidable: " .. path)
		else
			table.insert(isoTargets, inst)
		end
	end

	-- ------------------------------------------------------------ 3. build off-tree + conflict scan
	local root = Instance.new("Folder")
	root.Name = "Map1Expansion"
	local sectorFolders, groupInst = {}, {}
	local function sectorFolder(s)
		local f = sectorFolders[s]
		if not f then
			f = Instance.new("Folder")
			f.Name = s
			sectorFolders[s] = f
		end
		return f
	end
	for gname, c in CONTAINERS do
		if gname == c.sector then
			groupInst[gname] = sectorFolder(c.sector)
		else
			local inst = Instance.new(c.cls)
			inst.Name = c.name or gname
			if c.cls == "Model" and c.streaming then
				inst.ModelStreamingMode = Enum.ModelStreamingMode[c.streaming]
			end
			inst.Parent = sectorFolder(c.sector)
			groupInst[gname] = inst
		end
	end
	local newParts = {}
	for _, r in ROWS do
		local name, gname, role, size, pos, rot, mat, color, tr, coll, shape, shadow, ex =
			r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13]
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape == "C" and Enum.PartType.Cylinder or Enum.PartType.Block
		p.Size = V(size)
		p.CFrame = CFrame.new(pos[1], pos[2], pos[3], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
		p.Anchored = true
		p.Material = Enum.Material[mat]
		p.Color = Color3.fromRGB(color[1], color[2], color[3])
		p.Transparency = tr
		p.CanCollide = coll
		p.CanQuery = coll
		p.CanTouch = coll
		p.CastShadow = shadow
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Map1Expansion", CONTAINERS[gname].sector)
		p:SetAttribute("Map1Role", role)
		if ex.boss then
			p:SetAttribute("BossSectorFloor", ex.boss)
		end
		if ex.attrs then
			for k, v in ex.attrs do
				p:SetAttribute(k, v)
			end
		end
		if ex.light then
			local l = Instance.new("PointLight")
			l.Range = ex.light.range
			l.Brightness = ex.light.brightness
			l.Color = Color3.fromRGB(ex.light.color[1], ex.light.color[2], ex.light.color[3])
			l.Shadows = false
			l.Parent = p
		end
		if ex.sign then
			-- in-world navigation sign (v8): SurfaceGui + one TextLabel, no scripts, not interactive
			local sg = Instance.new("SurfaceGui")
			sg.Name = "Sign"
			sg.Face = Enum.NormalId[ex.sign.face]
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = ex.sign.ppS
			sg.LightInfluence = 0
			sg.Brightness = ex.sign.bright or 1.6
			local t = Instance.new("TextLabel")
			t.Name = "Text"
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			if ex.sign.bg then
				-- v10 high-contrast navigation sign: solid light panel, dark heavy text
				t.BackgroundTransparency = 0
				t.BackgroundColor3 = Color3.fromRGB(ex.sign.bg[1], ex.sign.bg[2], ex.sign.bg[3])
				t.BorderSizePixel = 0
			end
			t.Text = ex.sign.text
			t.TextScaled = true
			t.Font = ex.sign.font and Enum.Font[ex.sign.font] or Enum.Font.GothamBold
			t.TextColor3 = Color3.fromRGB(ex.sign.color[1], ex.sign.color[2], ex.sign.color[3])
			t.Parent = sg
			sg.Parent = p
		end
		table.insert(newParts, { p = p, g = gname })
	end
	-- conflicts: brute force over existing parts with a coarse XZ hash
	local CELL = 64
	local hash = {}
	local function cells(a, b, fn)
		for i = math.floor(a.X / CELL), math.floor(b.X / CELL) do
			for j = math.floor(a.Z / CELL), math.floor(b.Z / CELL) do
				fn(i * 100000 + j)
			end
		end
	end
	local entries = {}
	for _, e in existingParts do
		local t = targets[e.p]
		if t and t.policy == "moveWhole" then
			continue
		end
		local isIso = table.find(isoTargets, e.p) ~= nil
		if isIso then
			continue
		end
		if t and t.policy == "split" then
			for _, pc in t.pieces do
				table.insert(entries, { name = e.p:GetFullName() .. " (piece)", a = pc[1], b = pc[2], cf = CFrame.new((pc[1] + pc[2]) / 2), h = (pc[2] - pc[1]) / 2, coll = e.p.CanCollide })
			end
		else
			table.insert(entries, { name = e.p:GetFullName(), a = e.a, b = e.b, cf = e.p.CFrame, h = e.p.Size / 2, coll = e.p.CanCollide })
		end
	end
	for idx, e in entries do
		cells(e.a, e.b, function(k)
			local l = hash[k]
			if not l then
				l = {}
				hash[k] = l
			end
			table.insert(l, idx)
		end)
	end
	local hard, soft = {}, {}
	local nsoft = 0
	for ni, np in newParts do
		local p = np.p
		local a, b = aabb(p)
		local seen = {}
		cells(a, b, function(k)
			for _, idx in hash[k] or {} do
				if seen[idx] then
					continue
				end
				seen[idx] = true
				local e = entries[idx]
				if (p.CanCollide or e.coll) and boxHit(a, b, e.a, e.b, 0.05) then
					if obb(p.CFrame, p.Size / 2 - Vector3.new(0.05, 0.05, 0.05), e.cf, e.h - Vector3.new(0.05, 0.05, 0.05)) then
						if p.CanCollide and e.coll then
							table.insert(hard, p.Name .. " x " .. e.name)
						else
							nsoft += 1
							if #soft < 80 then
								table.insert(soft, p.Name .. (p.CanCollide and "(C)" or "(d)") .. " x " .. e.name .. (e.coll and "(C)" or "(d)"))
							end
						end
					end
				end
			end
		end)
		if ni % 200 == 0 then
			task.wait()
		end
	end

	local plan = {}
	local npieces = 0
	for _, t in order do
		table.insert(plan, ("%s [%s] %s -> %d pieces (cuts: %s)"):format(t.part:GetFullName(), t.part.CanCollide and "collidable" or "decor", tostring(t.policy), t.pieces and #t.pieces or 0, table.concat(t.cuts, ",")))
		npieces += t.pieces and #t.pieces or 0
	end
	local report = {
		cutPlan = plan, isolate = ISOLATE, problems = problems, hardConflicts = hard, softOverlaps = soft, softOverlapCount = nsoft,
		specParts = #newParts, expect = EXPECT, pieces = npieces,
	}
	if mode == "dryrun" then
		finish("done", report)
		return
	end
	if #problems > 0 or #hard > 0 then
		report.message = "refused: problems or hard conflicts (nothing changed)"
		finish("refused", report)
		return
	end

	-- ------------------------------------------------------------ 4. apply
	if not iso then
		iso = Instance.new("Folder")
		iso.Name = "Map1_Isolated"
		iso.Parent = SS
	end
	local function subFolder(nm)
		local f = iso:FindFirstChild(nm)
		if not f then
			f = Instance.new("Folder")
			f.Name = nm
			f.Parent = iso
		end
		return f
	end
	local cutOrig, moved = subFolder("CutOriginals"), subFolder("ExpansionMoved")
	local hallOpenings = sectorFolder("HallOpenings")
	local pieceParts = {}
	local k = 0
	for _, t in order do
		local p = t.part
		local origPath = p:GetFullName()
		if t.policy == "split" then
			for _, pc in t.pieces do
				k += 1
				local c = p:Clone()
				for _, ch in c:GetChildren() do
					ch:Destroy()
				end
				c.Name = p.Name .. "_Cut" .. k
				c.Size = pc[2] - pc[1]
				c.CFrame = CFrame.new((pc[1] + pc[2]) / 2)
				c:SetAttribute("Map1Expansion", "HallOpenings")
				c:SetAttribute("Map1Role", "CutPiece")
				c:SetAttribute("Map1CutFrom", origPath)
				table.insert(pieceParts, c)
			end
		end
		p:SetAttribute("Map1OrigParent", p.Parent:GetFullName())
		p:SetAttribute("Map1CutBy", table.concat(t.cuts, ","))
		p.Parent = cutOrig
	end
	for _, p in isoTargets do
		p:SetAttribute("Map1OrigParent", p.Parent:GetFullName())
		p.Parent = moved
	end
	root.Parent = map
	for _, f in sectorFolders do
		f.Parent = root
	end
	for i, c in pieceParts do
		c.Parent = hallOpenings
	end
	task.wait()
	for i, np in newParts do
		np.p.Parent = groupInst[np.g]
		if i % 250 == 0 then
			task.wait()
		end
	end
	local n, coll, lights = 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Map1Role") ~= "CutPiece" then
			n += 1
			if d.CanCollide then
				coll += 1
			end
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	if n ~= EXPECT.parts or coll ~= EXPECT.collidable or lights ~= EXPECT.lights then
		report.message = ("post-build count mismatch %d/%d/%d vs %d/%d/%d (version attribute NOT set)"):format(n, coll, lights, EXPECT.parts, EXPECT.collidable, EXPECT.lights)
		finish("error", report)
		return
	end
	root:SetAttribute("Map1ExpansionVersion", VERSION)
	root:SetAttribute("Map1ExpansionParts", n)
	report.message = ("built %s: %d spec parts (%d collidable, %d lights) + %d cut pieces; %d originals moved to ServerStorage.Map1_Isolated.CutOriginals, %d to ExpansionMoved"):format(VERSION, n, coll, lights, #pieceParts, #order, #isoTargets)
	finish("done", report)
end)
if not ok then
	finish("error", { message = tostring(err) })
end
