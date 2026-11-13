-- WORLD.EXE ENV_SLICE1 step 9: standalone rollback (Studio EDIT mode). Needs no builder state.
-- Removes Map.EnvSlice1 and the Map attribute "EnvSlice1". Touches nothing else: 1_build.luau never
-- modifies an existing instance, so removal restores the pre-slice map exactly.
-- Refuses to act if a slice-marked instance exists outside Map.EnvSlice1 (that would not be this
-- tool's construction) and reports it instead of deleting it.
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
local folder = map:FindFirstChild("EnvSlice1")
local function count(): (number, number)
	local parts, collide = 0, 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide then
				collide += 1
			end
		end
	end
	return parts, collide
end
local stray = {}
for _, d in workspace:GetDescendants() do
	if (d:GetAttribute("EnvSlice1") ~= nil or string.find(d.Name, "^EnvSlice1")) and d ~= map and not (folder and (d == folder or d:IsDescendantOf(folder))) then
		table.insert(stray, d:GetFullName())
	end
end
if #stray > 0 then
	error("ENV_SLICE1 rollback refused: slice-marked instances outside Map.EnvSlice1: " .. table.concat(stray, ", ", 1, math.min(#stray, 5)))
end
local p0, c0 = count()
local removed = 0
if folder then
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			removed += 1
		end
	end
	folder:Destroy()
end
map:SetAttribute("EnvSlice1", nil)
local p1, c1 = count()
return string.format("ENV_SLICE1 rollback: %d slice parts removed; Map parts %d -> %d, collidable %d -> %d", removed, p0, p1, c0, c1)
