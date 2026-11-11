--!strict
-- Phase 7A (Studio Edit mode, run once via Studio MCP): adds the dedicated BOUNCY and SLIPPERY
-- surfaces (approved decision P3: new tagged parts only, no existing geometry changed).
-- * 4 BounceSurface pads (6 x 0.4 x 6) and 4 SlipSurface pads (0.2 thick) under
--   Map.PatchSurfaces, anchored and collidable, each resting on an existing floor top.
-- * Each pad is verified before anything is created: floor under all four corners and no other
--   Map part in the pad's volume plus 6 studs of headroom. Any failure aborts with no changes.
-- * Positions keep clear of spawn pads, stabilizers, supply points and fragment markers.
-- Idempotent: an existing PatchSurfaces folder is left untouched.

local CollectionService = game:GetService("CollectionService")

local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")
if map:FindFirstChild("PatchSurfaces") then
	return "PatchSurfaces already exists; nothing changed"
end

-- { id, tag, zone, x, z, sizeX, sizeZ }
local PADS = {
	{ "BOUNCE_CORE_NW", "BounceSurface", "CentralCore", -18, 18, 6, 6 },
	{ "BOUNCE_CORE_SE", "BounceSurface", "CentralCore", 18, -18, 6, 6 },
	{ "BOUNCE_YARD_S", "BounceSurface", "ResearchYard", -105, 46, 6, 6 },
	{ "BOUNCE_YARD_N", "BounceSurface", "ResearchYard", -135, -46, 6, 6 },
	{ "SLIP_CORE_W", "SlipSurface", "CentralCore", -30, 0, 8, 10 },
	{ "SLIP_ANNEX", "SlipSurface", "Routes", -124, -64, 10, 10 },
	{ "SLIP_YARD_E", "SlipSurface", "ResearchYard", -74, -22, 10, 12 },
	{ "SLIP_YARD_W", "SlipSurface", "ResearchYard", -166, 22, 10, 12 },
}
local THICKNESS = { BounceSurface = 0.4, SlipSurface = 0.2 }
local COLOR = { BounceSurface = Color3.fromRGB(88, 52, 140), SlipSurface = Color3.fromRGB(120, 150, 175) }

local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Include
rays.FilterDescendantsInstances = { map }
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { map }

local plans = {}
for _, pad in PADS do
	local id, tag, zone, x, z, sx, sz = pad[1], pad[2], pad[3], pad[4], pad[5], pad[6], pad[7]
	local centre = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -250, 0), rays)
	assert(centre, `{id}: no floor`)
	local top = centre.Position.Y
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local hit = workspace:Raycast(Vector3.new(x + c[1] * sx / 2 * 0.95, top + 5, z + c[2] * sz / 2 * 0.95), Vector3.new(0, -10, 0), rays)
		assert(hit and math.abs(hit.Position.Y - top) < 0.01, `{id}: floor does not cover the pad`)
	end
	local blocking = workspace:GetPartBoundsInBox(CFrame.new(x, top + 3.3, z), Vector3.new(sx, 6, sz), overlap)
	assert(#blocking == 0, `{id}: blocked by {blocking[1] and blocking[1]:GetFullName()}`)
	table.insert(plans, { id = id, tag = tag, zone = zone, cf = CFrame.new(x, top + THICKNESS[tag] / 2, z), size = Vector3.new(sx, THICKNESS[tag], sz) })
end

local folder = Instance.new("Folder")
folder.Name = "PatchSurfaces"
for _, plan in plans do
	local part = Instance.new("Part")
	part.Name = plan.id
	part.Size = plan.size
	part.CFrame = plan.cf
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = COLOR[plan.tag]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("SurfaceId", plan.id)
	part:SetAttribute("Zone", plan.zone)
	CollectionService:AddTag(part, plan.tag)
	part.Parent = folder
end
folder.Parent = map
return `created {#plans} patch surfaces`
