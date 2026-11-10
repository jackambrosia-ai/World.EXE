--!strict
-- SUPPLY_DROP (Phase 4): a contested crate at a server-approved landing point.
-- * The landing point is a random free BasePart tagged SupplyLandingPoint inside the arena Map
--   (never client input). Overlapping SUPPLY_DROP patches never share a point. With no free point,
--   activation fails (full rollback, slot freed).
-- * On activation a beacon column marks the zone; DROP_DELAY_SECONDS later the crate lands with a
--   ProximityPrompt. The crate holds ITEMS_PER_CRATE items; each player can claim at most one.
-- * Reward (server-defined, not client-controlled): a shield that blocks the next drone hit, for
--   up to SHIELD_SECONDS (PlayerStateService owns it and clears it on death and role change).
-- * Every claim is validated on the server in TryClaim: patch still live, crate still there,
--   claimer is a living Participant within CLAIM_RANGE, per-player attempt cooldown, not already
--   claimed from this crate, not already shielded, items left. A claim takes exactly one item.
-- * Unclaimed supplies despawn when the patch ends; the crate, beacon, prompt and connection are
--   all in the patch's cleanup bag. Placeholder parts are built in code until artwork is approved.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))
local PlayerStateService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PlayerStateService"))

-- Server-only tuning (initial proposals; tune in playtests).
local DROP_DELAY_SECONDS = 3
local ITEMS_PER_CRATE = 2
local CLAIM_RANGE = 12 -- server check; the prompt's own distance is shorter
local PROMPT_DISTANCE = 10
local CLAIM_COOLDOWN_SECONDS = 1
local SHIELD_SECONDS = 45
local CRATE_SIZE = Vector3.new(4, 4, 4)
local BEACON_HEIGHT = 60

type CrateState = {
	ctx: any,
	remaining: number,
	claimedBy: { [number]: boolean },
	prompt: ProximityPrompt,
	beacon: BasePart,
}

local claimedPoints: { [BasePart]: string } = {} -- landing point -> RuntimeId using it
local crates: { [Instance]: CrateState } = {}
local lastAttempt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function now(): number
	return workspace:GetServerTimeNow()
end

local function landingPoints(): { BasePart }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local list = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.SupplyLandingPoint) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) and claimedPoints[inst] == nil then
				table.insert(list, inst)
			end
		end
	end
	return list
end

local function promptText(remaining: number): string
	return `Supply Crate ({remaining} left)`
end

local SupplyDrop = {}

-- Validates and applies one claim. Returns (true, "claimed") or (false, reason).
function SupplyDrop.TryClaim(crate: Instance, player: Player): (boolean, string)
	local state = crates[crate]
	if state == nil or crate.Parent == nil or not state.ctx.IsLive() then
		return false, "unavailable"
	end
	if PlayerStateService.GetRole(player) ~= Config.Roles.Participant then
		return false, "not_participant"
	end
	if not PlayerStateService.IsAlive(player) then
		return false, "not_alive"
	end
	local t = now()
	if t < (lastAttempt[player] or 0) + CLAIM_COOLDOWN_SECONDS then
		return false, "cooldown"
	end
	lastAttempt[player] = t
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") or not crate:IsA("BasePart") then
		return false, "not_alive"
	end
	if (rootPart.Position - crate.Position).Magnitude > CLAIM_RANGE then
		return false, "too_far"
	end
	if state.claimedBy[player.UserId] then
		return false, "already_claimed"
	end
	if PlayerStateService.HasShield(player) then
		return false, "already_shielded"
	end
	if state.remaining <= 0 then
		return false, "empty"
	end
	state.remaining -= 1
	state.claimedBy[player.UserId] = true
	PlayerStateService.GrantShield(player, SHIELD_SECONDS)
	if state.remaining <= 0 then
		crates[crate] = nil
		crate:Destroy()
		state.beacon:Destroy()
	else
		state.prompt.ObjectText = promptText(state.remaining)
	end
	return true, "claimed"
end

function SupplyDrop.Activate(ctx: any)
	local points = landingPoints()
	if #points == 0 then
		error("no free SupplyLandingPoint in the arena")
	end
	local point = points[Random.new():NextInteger(1, #points)]
	claimedPoints[point] = ctx.RuntimeId
	ctx.Add(function()
		if claimedPoints[point] == ctx.RuntimeId then
			claimedPoints[point] = nil
		end
	end)
	local top = point.Position + Vector3.new(0, point.Size.Y / 2, 0)

	local beacon = Instance.new("Part")
	beacon.Name = `SupplyBeacon_{ctx.RuntimeId}`
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(BEACON_HEIGHT, 6, 6)
	beacon.CFrame = CFrame.new(top + Vector3.new(0, BEACON_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Material = Enum.Material.Neon
	beacon.Color = Config.Palette.NeonCyan
	beacon.Transparency = 0.65
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.CastShadow = false
	beacon:SetAttribute("PointId", point:GetAttribute("PointId"))
	beacon.Parent = ctx.Folder
	ctx.Add(beacon)

	ctx.Delay(DROP_DELAY_SECONDS, function()
		if not ctx.IsLive() then
			return
		end
		local crate = Instance.new("Part")
		crate.Name = `SupplyCrate_{ctx.RuntimeId}`
		crate.Size = CRATE_SIZE
		crate.CFrame = CFrame.new(top + Vector3.new(0, CRATE_SIZE.Y / 2, 0))
		crate.Material = Enum.Material.Metal
		crate.Color = Config.Palette.AmberWarning
		crate.Anchored = true
		crate.CanCollide = true
		crate.CanTouch = false
		crate:SetAttribute("PointId", point:GetAttribute("PointId"))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Claim shield"
		prompt.ObjectText = promptText(ITEMS_PER_CRATE)
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate
		crate.Parent = ctx.Folder
		ctx.Add(crate)
		crates[crate] = {
			ctx = ctx,
			remaining = ITEMS_PER_CRATE,
			claimedBy = {},
			prompt = prompt,
			beacon = beacon,
		}
		ctx.Add(function()
			crates[crate] = nil
		end)
		ctx.Add(prompt.Triggered:Connect(function(player: Player)
			SupplyDrop.TryClaim(crate, player)
		end))
	end)
end

-- Crates currently claimable (for tests and diagnostics).
function SupplyDrop.GetCrates(): { Instance }
	local list = {}
	for crate in crates do
		table.insert(list, crate)
	end
	return list
end

function SupplyDrop.GetClaimedPointCount(): number
	local n = 0
	for _ in claimedPoints do
		n += 1
	end
	return n
end

SupplyDrop.Tuning = table.freeze({
	DropDelaySeconds = DROP_DELAY_SECONDS,
	ItemsPerCrate = ITEMS_PER_CRATE,
	ClaimRange = CLAIM_RANGE,
	ClaimCooldownSeconds = CLAIM_COOLDOWN_SECONDS,
	ShieldSeconds = SHIELD_SECONDS,
})

return table.freeze(SupplyDrop)
