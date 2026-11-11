-- WORLD.EXE Phase 8A-2b step 9: standalone rollback to the pre-8A-2b state (Studio EDIT mode).
-- Needs no builder state (_G.W8A2B). Removes the six 8A-2b district models from Map.Architecture,
-- restores the Transparency of every part hidden by 8A-2b (Orig8A2B_Transparency attribute), clears
-- Map.Phase8A2B and removes ServerStorage.WORLD_EXE_Rollback8A2B. 8A-2a content is untouched.
local ServerStorage = game:GetService("ServerStorage")
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
local arch = map:WaitForChild("Architecture")
local MODELS = { "TestHangar", "ControlFacility", "ServerCanyons", "PumpStation", "TransitRing", "SharedSupports" }
local removed, restored = 0, 0
for _, name in MODELS do
	local m = arch:FindFirstChild(name)
	if m then
		m:Destroy()
		removed += 1
	end
end
for _, d in map:GetDescendants() do
	local t = d:GetAttribute("Orig8A2B_Transparency")
	if t ~= nil and d:IsA("BasePart") then
		d.Transparency = t
		d:SetAttribute("Orig8A2B_Transparency", nil)
		restored += 1
	end
end
local leftovers = 0
for _, d in map:GetDescendants() do
	if d:GetAttribute("Arch8A2B") then
		leftovers += 1
	end
end
map:SetAttribute("Phase8A2B", nil)
local store = ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2B")
if store then
	store:Destroy()
end
_G.W8A2B = nil
return string.format("8A-2b restore: %d models removed, %d parts restored, %d 8A-2b parts left", removed, restored, leftovers)
