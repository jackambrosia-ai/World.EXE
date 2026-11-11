-- WORLD.EXE Phase 8A-2c rollback (Studio Edit). Removes ONLY Phase 8A-2c work:
--   * destroys every instance marked Env8A2C = "new" (Map.EnvFX8A2C, the 3 PointLights, the scan
--     Beam and its 2 Attachments);
--   * on every instance marked Env8A2C = "hook": removes its EnvFX_* tags and its Base_*,
--     EnvFX_Role and Env8A2C attributes (no other property is touched; the builder never changed one);
--   * removes ServerStorage.WORLD_EXE_Rollback8A2C and Map.Phase8A2C.
-- Phase 8A-2a / 8A-2b content is never destroyed or restored over. Before the build there were no
-- Base_* attributes and no EnvFX_* tags (recorded in the rollback folder), so removing them is exact.
-- Test destructive rollback/rebuild only in a working session, never on the owner's saved place.
local CS = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")

local destroyed, cleaned = 0, 0
local toDestroy = {}
for _, d in root:GetDescendants() do
	if d:GetAttribute("Env8A2C") == "new" then
		-- only top-most marked instances (children go with them)
		local p = d.Parent
		local nested = false
		while p and p ~= root do
			if p:GetAttribute("Env8A2C") == "new" then
				nested = true
				break
			end
			p = p.Parent
		end
		if not nested then
			table.insert(toDestroy, d)
		end
	end
end
for _, d in toDestroy do
	d:Destroy()
	destroyed += 1
end
for _, d in root:GetDescendants() do
	if d:GetAttribute("Env8A2C") == "hook" then
		for _, t in CS:GetTags(d) do
			if t:sub(1, 6) == "EnvFX_" then
				CS:RemoveTag(d, t)
			end
		end
		for k in d:GetAttributes() do
			if k:sub(1, 5) == "Base_" or k == "EnvFX_Role" or k == "Env8A2C" then
				d:SetAttribute(k, nil)
			end
		end
		cleaned += 1
	end
end
local store = ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2C")
if store then
	store:Destroy()
end
map:SetAttribute("Phase8A2C", nil)

-- verify nothing remains
for _, d in root:GetDescendants() do
	assert(d:GetAttribute("Env8A2C") == nil, "left: " .. d:GetFullName())
	for _, t in CS:GetTags(d) do
		assert(t:sub(1, 6) ~= "EnvFX_", "tag left: " .. d:GetFullName())
	end
	for k in d:GetAttributes() do
		assert(k:sub(1, 5) ~= "Base_", "Base_ left: " .. d:GetFullName())
	end
end
return string.format("8A-2c rollback: destroyed %d top-level new instances, cleaned %d hooks", destroyed, cleaned)
