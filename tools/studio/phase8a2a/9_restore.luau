-- WORLD.EXE Phase 8A-2a: standalone manual rollback (Studio EDIT mode). Works without _G state,
-- e.g. after a Studio restart, using only ServerStorage.WORLD_EXE_Rollback8A2A:
--   * destroys Map.Architecture and Map.Megastructure;
--   * moves the removed 8A-1 reactor parts back to their recorded parents;
--   * restores the Lighting properties and children, and Lobby.Wall_N's visual properties;
--   * sets ArenaVersion back to 2 and removes the rollback store.
-- The external .rbxl backups (WorldEXE_pre-phase8a2a_2026-11-11.rbxl) remain authoritative.
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local store = ServerStorage:FindFirstChild("WORLD_EXE_Rollback8A2A")
assert(store, "no 8A-2a rollback store")
local root = workspace:WaitForChild("WORLD_EXE")
local map = root:WaitForChild("Map")
local log = {}

for _, name in { "Architecture", "Megastructure" } do
	local f = map:FindFirstChild(name)
	if f then
		f:Destroy()
	end
end
for _, inst in store.RemovedMapParts:GetChildren() do
	local path = inst:GetAttribute("Rollback8A2A_Parent")
	local parent: Instance? = game
	for _, seg in string.split(path, ".") do
		parent = parent and parent:FindFirstChild(seg)
	end
	if parent then
		inst:SetAttribute("Rollback8A2A_Parent", nil)
		inst.Parent = parent
	else
		table.insert(log, "could not restore " .. inst.Name)
	end
end
local snap = store.Lighting
for prop, value in snap:GetAttributes() do
	(Lighting :: any)[prop] = value
end
for _, child in Lighting:GetChildren() do
	child:Destroy()
end
for _, child in snap:GetChildren() do
	child:Clone().Parent = Lighting
end
local wallN = root.Lobby.Wall_N
local ws = store.LobbyWallN
wallN.Material = Enum.Material[ws:GetAttribute("Material")]
wallN.Transparency = ws:GetAttribute("Transparency")
wallN.Color = ws:GetAttribute("Color")
wallN.Reflectance = ws:GetAttribute("Reflectance")
root:SetAttribute("ArenaVersion", 2)
store:Destroy()
_G.W8A2A = nil
return "8A-2a rolled back" .. (if #log > 0 then " WITH ISSUES: " .. table.concat(log, "; ") else "")
