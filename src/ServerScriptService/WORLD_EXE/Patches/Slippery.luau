--!strict
-- SLIPPERY (Phase 7A): the tagged SlipSurface pads become near-frictionless.
-- * Only BaseParts tagged SlipSurface inside Workspace.WORLD_EXE.Map (dedicated Phase 7A pads).
-- * Sets CustomPhysicalProperties (friction SLIP_FRICTION with a dominant friction weight) and an
--   icy look. The originals (CustomPhysicalProperties, Color, Material) are saved and restored when
--   the patch ends for any reason; missing parts are skipped.
-- * Counterplay: move slowly or stay off the pads. ANCHOR (approved P5) damps its user's sliding
--   while they stand on an active pad (see AbilityService). Note: the Roblox character controller
--   takes traction from the floor's friction, so a character's own friction does not help.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

-- Server-only tuning (provisional).
local SLIP_FRICTION = 0.02
local SLIP_FRICTION_WEIGHT = 100
local ICE_COLOR = Color3.fromRGB(175, 230, 255)

type Original = { Physical: PhysicalProperties?, Color: Color3, Material: Enum.Material }

local activePads: { [BasePart]: string } = {}

local function padsInMap(): { BasePart }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local list = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.SlipSurface) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
				table.insert(list, inst)
			end
		end
	end
	return list
end

local Slippery = {}

function Slippery.Activate(ctx: any)
	local pads = padsInMap()
	if #pads == 0 then
		error("no SlipSurface pads in the arena")
	end
	local originals: { [BasePart]: Original } = {}
	ctx.Add(function()
		for pad, original in originals do
			if activePads[pad] == ctx.RuntimeId then
				activePads[pad] = nil
			end
			pcall(function()
				pad.CustomPhysicalProperties = original.Physical
				pad.Color = original.Color
				pad.Material = original.Material
			end)
		end
	end)
	for _, pad in pads do
		originals[pad] = { Physical = pad.CustomPhysicalProperties, Color = pad.Color, Material = pad.Material }
		activePads[pad] = ctx.RuntimeId
		local base = PhysicalProperties.new(pad.Material)
		pad.CustomPhysicalProperties = PhysicalProperties.new(base.Density, SLIP_FRICTION, 0, SLIP_FRICTION_WEIGHT, 1)
		pad.Color = ICE_COLOR
		pad.Material = Enum.Material.Ice
	end
end

-- True while `part` is a pad made slippery by a running SLIPPERY patch (ANCHOR's grip check).
function Slippery.IsActive(part: Instance): boolean
	return activePads[part :: any] ~= nil
end

-- Pads currently slippery (SCANNER and tests).
function Slippery.GetActivePads(): { BasePart }
	local list = {}
	for pad in activePads do
		table.insert(list, pad)
	end
	return list
end

Slippery.Tuning = table.freeze({
	Friction = SLIP_FRICTION,
	FrictionWeight = SLIP_FRICTION_WEIGHT,
})

return table.freeze(Slippery)
