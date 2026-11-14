-- WORLD.EXE Map 1 step 0: reversibly isolate the ENV_SPRINT2 v2 exterior (digital rift decor that does
-- not fit the Stable Simulation). WORKING COPY ONLY.
--   _G.MAP1_ISOLATE_MODE = "isolate" (default): move Workspace.WORLD_EXE.Map.EnvSprint2.
--        Exterior_WestRift, Exterior_BrokenSlabs, Exterior_UnrenderedVolume into ServerStorage.Map1_Isolated
--        (Folder, created if missing). Each moved model gets attribute Map1IsolatedFrom = original parent path.
--   _G.MAP1_ISOLATE_MODE = "restore": move them back into Map.EnvSprint2 (only models carrying
--        Map1IsolatedFrom = "Workspace.WORLD_EXE.Map.EnvSprint2"), clearing the attribute.
-- Idempotent: already-isolated / already-restored models are reported, never duplicated. Refuses when a
-- name exists in both places. Traversal_* models (high line, jump climb) are never touched.
-- Moving keeps instance identity and every property; nothing is destroyed or recreated.
local NAMES = { "Exterior_WestRift", "Exterior_BrokenSlabs", "Exterior_UnrenderedVolume" }
local FROM = "Workspace.WORLD_EXE.Map.EnvSprint2"
local mode = _G.MAP1_ISOLATE_MODE or "isolate"
local ss = game:GetService("ServerStorage")
local es2 = workspace.WORLD_EXE.Map:FindFirstChild("EnvSprint2")
assert(es2, "Map.EnvSprint2 not found")
local iso = ss:FindFirstChild("Map1_Isolated")
local log = {}

for _, name in NAMES do
	local inMap = es2:FindFirstChild(name)
	local inIso = iso and iso:FindFirstChild(name)
	if inMap and inIso then
		error(("refusing: %s exists both in EnvSprint2 and in Map1_Isolated"):format(name))
	end
end

if mode == "isolate" then
	if not iso then
		iso = Instance.new("Folder")
		iso.Name = "Map1_Isolated"
		iso:SetAttribute("Map1Note", "Reversibly isolated Map 1 content; restore with tools/studio/map1 scripts")
		iso.Parent = ss
	end
	for _, name in NAMES do
		local m = es2:FindFirstChild(name)
		if m then
			m:SetAttribute("Map1IsolatedFrom", FROM)
			m.Parent = iso
			table.insert(log, "isolated " .. name)
		elseif iso:FindFirstChild(name) then
			table.insert(log, "already isolated " .. name)
		else
			table.insert(log, "MISSING " .. name)
		end
	end
elseif mode == "restore" then
	for _, name in NAMES do
		local m = iso and iso:FindFirstChild(name)
		if m and m:GetAttribute("Map1IsolatedFrom") == FROM then
			m:SetAttribute("Map1IsolatedFrom", nil)
			m.Parent = es2
			table.insert(log, "restored " .. name)
		elseif es2:FindFirstChild(name) then
			table.insert(log, "already in place " .. name)
		else
			table.insert(log, "MISSING " .. name)
		end
	end
else
	error("unknown mode " .. tostring(mode))
end
return table.concat(log, "\n")
