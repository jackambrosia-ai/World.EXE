--!strict
-- BOUNCY (Phase 7A): the tagged BounceSurface pads launch living Participants upward.
-- * Only BaseParts tagged BounceSurface inside Workspace.WORLD_EXE.Map (dedicated Phase 7A pads).
-- * While active the pads glow; their original Color and Material come back when the patch ends.
-- * Launch: a short-lived LinearVelocity on the root part (simulated by the character's owner, so
--   it works on client-owned characters), held LAUNCH_HOLD seconds, then ballistic flight.
-- * Movement precedence (deterministic, highest first):
--     1. ANCHOR on the player (Phase 6, approved P5): no launch at all.
--     2. Combination boosts (SUPER_BOUNCE): the strongest active boost multiplies the speed.
--     3. Base launch speed.
--   The result is always clamped so the jump apex under the current gravity is at most MAX_APEX.
-- * Per-character cooldown LAUNCH_COOLDOWN; no infinite launch loops.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

-- Server-only tuning (provisional).
local LAUNCH_SPEED = 55 -- studs/s upward (apex ~7.7 studs at normal gravity)
local MAX_APEX = 35 -- studs; caps every launch under any gravity or boost
local LAUNCH_HOLD = 0.12
local LAUNCH_COOLDOWN = 1
local ACTIVE_COLOR = Config.Palette.ElectricPurple

type Original = { Color: Color3, Material: Enum.Material }

local boosts: { [string]: number } = {} -- token -> factor
local activePads: { [BasePart]: string } = {}
local lastLaunch: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local stats = { Launches = 0, Suppressed = 0, LastSpeed = 0 }

local function padsInMap(): { BasePart }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local list = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.BounceSurface) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
				table.insert(list, inst)
			end
		end
	end
	return list
end

local Bouncy = {}

-- Combination boost (e.g. SUPER_BOUNCE). The strongest active boost wins.
function Bouncy.AddBoost(token: string, factor: number)
	boosts[token] = factor
end

function Bouncy.RemoveBoost(token: string)
	boosts[token] = nil
end

-- Launch speed after boosts, clamped so the total rise stays within MAX_APEX under the current
-- gravity: the distance covered during the LAUNCH_HOLD (v * hold) plus the ballistic rise
-- (v^2 / 2g). Solving v^2/(2g) + hold*v = MAX_APEX gives the largest allowed v.
function Bouncy.LaunchSpeed(): number
	local factor = 1
	for _, f in boosts do
		factor = math.max(factor, f)
	end
	local g = math.max(workspace.Gravity, 1)
	local limit = -g * LAUNCH_HOLD + math.sqrt((g * LAUNCH_HOLD) ^ 2 + 2 * g * MAX_APEX)
	return math.min(LAUNCH_SPEED * factor, limit)
end

local function isAnchored(player: Player): boolean
	local untilTime = player:GetAttribute(Config.PlayerAttributes.AbilityActivePrefix .. "ANCHOR")
	return typeof(untilTime) == "number" and untilTime > workspace:GetServerTimeNow()
end

function Bouncy.Activate(ctx: any)
	local pads = padsInMap()
	if #pads == 0 then
		error("no BounceSurface pads in the arena")
	end
	local originals: { [BasePart]: Original } = {}
	-- Registered first, so it runs last at cleanup.
	ctx.Add(function()
		for pad, original in originals do
			if activePads[pad] == ctx.RuntimeId then
				activePads[pad] = nil
			end
			pcall(function()
				pad.Color = original.Color
				pad.Material = original.Material
			end)
		end
	end)
	for _, pad in pads do
		originals[pad] = { Color = pad.Color, Material = pad.Material }
		activePads[pad] = ctx.RuntimeId
		pad.Color = ACTIVE_COLOR
		pad.Material = Enum.Material.Neon
		ctx.Add(pad.Touched:Connect(function(hit: BasePart)
			if not ctx.IsLive() then
				return
			end
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if player == nil or character == nil then
				return
			end
			if PlayerStateService.GetRole(player) ~= Config.Roles.Participant or not PlayerStateService.IsAlive(player) then
				return
			end
			local t = os.clock()
			if t < (lastLaunch[character] or 0) + LAUNCH_COOLDOWN then
				return
			end
			lastLaunch[character] = t
			if isAnchored(player) then
				stats.Suppressed += 1
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") then
				return
			end
			local speed = Bouncy.LaunchSpeed()
			local attachment = Instance.new("Attachment")
			attachment.Name = "WORLD_EXE_BounceAttachment"
			local velocity = Instance.new("LinearVelocity")
			velocity.Name = "WORLD_EXE_Bounce"
			velocity.Attachment0 = attachment
			velocity.RelativeTo = Enum.ActuatorRelativeTo.World
			velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
			velocity.LineDirection = Vector3.yAxis
			velocity.LineVelocity = speed
			velocity.MaxForce = math.max(1, root.AssemblyMass) * 10000
			attachment.Parent = root
			velocity.Parent = root
			ctx.Add(attachment)
			ctx.Add(velocity)
			ctx.Delay(LAUNCH_HOLD, function()
				velocity:Destroy()
				attachment:Destroy()
			end)
			stats.Launches += 1
			stats.LastSpeed = speed
		end))
	end
end

-- Pads glowing for a running BOUNCY patch (SCANNER and tests).
function Bouncy.GetActivePads(): { BasePart }
	local list = {}
	for pad in activePads do
		table.insert(list, pad)
	end
	return list
end

function Bouncy.GetStats(): { Launches: number, Suppressed: number, LastSpeed: number }
	return table.clone(stats)
end

Bouncy.Tuning = table.freeze({
	LaunchSpeed = LAUNCH_SPEED,
	MaxApex = MAX_APEX,
	LaunchCooldown = LAUNCH_COOLDOWN,
})

return Bouncy
