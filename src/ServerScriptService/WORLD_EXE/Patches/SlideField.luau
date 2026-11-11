--!strict
-- SLIDE_FIELD combination (SLIPPERY + MAGNETIC, Phase 7B): MAGNETIC's crates slide twice as fast
-- toward their safe points and stay there (the field stops pushing them back), and each point is
-- marked with a glowing ring while the combination runs. Crates still never strike players: MAGNETIC holds a crate whenever a character is within
-- its clearance of the crate's next position. The ring markers (no collision, no queries) and the
-- speed token are removed when the combination ends (either source ending ends it).

local Magnetic = require(script.Parent:WaitForChild("Magnetic"))

local SPEED_FACTOR = 2
local RING_COLOR = Color3.fromRGB(90, 170, 255)

local SlideField = {}

function SlideField.Activate(ctx: any)
	Magnetic.AddSlide(ctx.RuntimeId, SPEED_FACTOR)
	ctx.Add(function()
		Magnetic.RemoveSlide(ctx.RuntimeId)
	end)
	for _, point in Magnetic.GetPoints() do
		local ring = Instance.new("Part")
		ring.Name = "SlideTarget_" .. tostring(point:GetAttribute("PointId"))
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 5, 5)
		ring.CFrame = CFrame.new(point.Position.X, point.Position.Y + 0.05, point.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = RING_COLOR
		ring.Transparency = 0.3
		ring.Parent = ctx.Folder
		ctx.Add(ring)
	end
end

SlideField.SpeedFactor = SPEED_FACTOR

return table.freeze(SlideField)
