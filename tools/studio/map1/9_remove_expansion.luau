-- WORLD.EXE Map 1: remove the expansion built by 1_build_expansion.luau and restore every existing
-- object it moved. WORKING COPY ONLY. Removes only what it recognises; refuses (changing nothing) if
-- Map1Expansion contains anything else or if a moved original cannot be put back.
--   Recognised under Workspace.WORLD_EXE.Map.Map1Expansion: Folders/Models, BaseParts carrying the
--   Map1Expansion attribute (spec parts and HallOpenings cut pieces), PointLights parented to such parts.
--   Restored: every child of ServerStorage.Map1_Isolated.CutOriginals and .ExpansionMoved carrying
--   Map1OrigParent (moved back to that parent; Map1OrigParent / Map1CutBy attributes cleared).
-- Not touched: the ENV_SPRINT2 exterior isolation (0_isolate_sprint_exterior.luau, mode "restore") and
-- the Config bounds edit (2_set_bounds.luau, mode "restore").
local SS = game:GetService("ServerStorage")
local map = workspace.WORLD_EXE.Map
local function resolve(path)
	local cur = game
	for seg in string.gmatch(path, "[^%.]+") do
		if cur == game and seg == "Workspace" then
			cur = workspace
		else
			local found = nil
			for _, ch in (cur and cur:GetChildren() or {}) do
				if ch.Name == seg then
					if found then
						return nil, "ambiguous path segment " .. seg
					end
					found = ch
				end
			end
			cur = found
		end
		if not cur then
			return nil, "missing"
		end
	end
	return cur
end
local root = map:FindFirstChild("Map1Expansion")
local problems = {}
local n = 0
if root then
	for _, d in root:GetDescendants() do
		if d:IsA("Folder") or d:IsA("Model") then
			-- ok
		elseif d:IsA("BasePart") then
			if d:GetAttribute("Map1Expansion") == nil then
				table.insert(problems, "unrecognised part " .. d:GetFullName())
			end
			n += 1
		elseif d:IsA("PointLight") and d.Parent:IsA("BasePart") and d.Parent:GetAttribute("Map1Expansion") ~= nil then
			-- ok
		elseif d:IsA("SurfaceGui") and d.Name == "Sign" and d.Parent:IsA("BasePart") and d.Parent:GetAttribute("Map1Expansion") ~= nil then
			-- ok (v8 navigation sign)
		elseif d:IsA("TextLabel") and d.Name == "Text" and d.Parent:IsA("SurfaceGui") and d.Parent.Name == "Sign" then
			-- ok (v8 navigation sign text)
		else
			table.insert(problems, "unrecognised instance " .. d:GetFullName() .. " (" .. d.ClassName .. ")")
		end
	end
end
local iso = SS:FindFirstChild("Map1_Isolated")
local restore = {}
for _, sub in { "CutOriginals", "ExpansionMoved" } do
	local f = iso and iso:FindFirstChild(sub)
	for _, c in (f and f:GetChildren() or {}) do
		local path = c:GetAttribute("Map1OrigParent")
		local parent, why = nil, "no Map1OrigParent"
		if path then
			parent, why = resolve(path)
		end
		if not parent then
			table.insert(problems, "cannot resolve original parent for " .. c:GetFullName() .. " (" .. tostring(path) .. ": " .. tostring(why) .. ")")
		else
			table.insert(restore, { c, parent })
		end
	end
end
if #problems > 0 then
	error("refusing (nothing changed):\n" .. table.concat(problems, "\n"))
end
if root then
	root:Destroy()
end
for _, r in restore do
	r[1]:SetAttribute("Map1OrigParent", nil)
	r[1]:SetAttribute("Map1CutBy", nil)
	r[1].Parent = r[2]
end
for _, sub in { "CutOriginals", "ExpansionMoved" } do
	local f = iso and iso:FindFirstChild(sub)
	if f and #f:GetChildren() == 0 then
		f:Destroy()
	end
end
return ("removed Map1Expansion (%d parts) and restored %d moved originals"):format(n, #restore)
