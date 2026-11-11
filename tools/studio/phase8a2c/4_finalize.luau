-- WORLD.EXE Phase 8A-2c finalize (Studio Edit). Run after 0_build.luau and after 1_audit.luau
-- returned "result":"PASS" on the exact final state. Marks the map so the saved file can be verified
-- (Map.Phase8A2C) and confirms the place is clean for the owner's save. 2_rollback.luau removes the mark.
local ServerStorage = game:GetService("ServerStorage")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
assert(map:FindFirstChild("EnvFX8A2C"), "8A-2c not built")
assert(ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2C"), "rollback record missing")
for _, s in { game:GetService("ServerScriptService"), ServerStorage, workspace, game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer") } do
	for _, d in s:GetDescendants() do
		assert(d.Name:sub(1, 3) ~= "ZZ_", "test leftover: " .. d:GetFullName())
	end
end
assert(game:GetService("ServerScriptService").WORLD_EXE:GetAttribute("StudioTimeScale") == nil, "StudioTimeScale still set")
local L = game:GetService("Lighting")
assert(math.abs(L.Brightness - 1.8) < 1e-4 and math.abs(L.ExposureCompensation - 0.3) < 1e-4, "Lighting not at the A' baseline 1.80/0.30")
map:SetAttribute("Phase8A2C", "2026-11-11")
return "Phase8A2C set"
