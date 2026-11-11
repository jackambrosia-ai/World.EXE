--!strict
-- DECAY (Phase 4): marked Research Yard tiles warn, collapse briefly, then come back.
-- * Only BaseParts tagged DecayTile inside Workspace.WORLD_EXE.Map are ever touched.
-- * Readable cycle: every CYCLE_SECONDS a small group of tiles turns amber neon (warning) for
--   WARN_SECONDS, then becomes non-solid and see-through for COLLAPSE_SECONDS, then is restored.
--   Every tile is warned before it collapses.
-- * Bounded: at most MAX_UNSAFE tiles (of 64) are warned or collapsed at once, across every DECAY
--   patch, so there is always solid ground within a short walk (a tile is ~10 studs wide).
-- * Only Color, Material, Transparency and CanCollide change, and the originals are restored when
--   the group ends and again (idempotently) when the patch ends for any reason. Geometry is never
--   moved or deleted. A missing or destroyed tile is skipped, never an error.
-- * Overlapping DECAY patches share one claim table, so two patches never fight over one tile.
-- * Phase 7B (RAPID_DECAY): a speed-up token shortens the time between groups; warnings, collapse
--   time and MAX_UNSAFE are unchanged.
-- The server owns tile state; clients see the replicated tile properties.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

-- Server-only tuning (initial proposals; tune in playtests).
local CYCLE_SECONDS = 5
local GROUP_SIZE = 4
local WARN_SECONDS = 2.5
local COLLAPSE_SECONDS = 4
local MAX_UNSAFE = 8 -- GROUP_SIZE x ceil((WARN + COLLAPSE) / CYCLE): two overlapping groups at most
local WARN_COLOR = Config.Palette.AmberWarning
local COLLAPSED_COLOR = Color3.fromRGB(255, 70, 70)
local COLLAPSED_TRANSPARENCY = 0.8

type Original = {
	Color: Color3,
	Material: Enum.Material,
	Transparency: number,
	CanCollide: boolean,
}

-- Tile -> RuntimeId of the DECAY patch currently using it (warned or collapsed).
local claimed: { [BasePart]: string } = {}
local speedups: { [string]: number } = {} -- token -> factor (strongest wins)

local CHECK_SECONDS = 0.25

local function cycleSeconds(): number
	local factor = 1
	for _, f in speedups do
		factor = math.max(factor, f)
	end
	return CYCLE_SECONDS / factor
end

local function decayTiles(): { BasePart }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local list = {}
	if map then
		for _, inst in CollectionService:GetTagged(Config.Tags.DecayTile) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
				table.insert(list, inst)
			end
		end
	end
	return list
end

local function claimedCount(): number
	local n = 0
	for _ in claimed do
		n += 1
	end
	return n
end

local Decay = {}

function Decay.Activate(ctx: any)
	local tiles = decayTiles()
	if #tiles == 0 then
		error("no DecayTile parts in the arena")
	end
	local rng = Random.new()
	local originals: { [BasePart]: Original } = {}

	local function restore(tile: BasePart)
		local original = originals[tile]
		if original == nil then
			return
		end
		originals[tile] = nil
		if claimed[tile] == ctx.RuntimeId then
			claimed[tile] = nil
		end
		pcall(function()
			tile.Color = original.Color
			tile.Material = original.Material
			tile.Transparency = original.Transparency
			tile.CanCollide = original.CanCollide
		end)
	end

	-- Registered first, so it runs last at cleanup (after every timer is cancelled).
	ctx.Add(function()
		for tile in originals do
			restore(tile)
		end
	end)

	local function collapse(group: { BasePart })
		for _, tile in group do
			if originals[tile] and tile.Parent ~= nil then
				tile.CanCollide = false
				tile.Transparency = COLLAPSED_TRANSPARENCY
				tile.Color = COLLAPSED_COLOR
				tile.Material = Enum.Material.ForceField
			end
		end
	end

	local function startGroup()
		local free = {}
		for _, tile in tiles do
			if claimed[tile] == nil and tile.Parent ~= nil then
				table.insert(free, tile)
			end
		end
		local count = math.min(GROUP_SIZE, MAX_UNSAFE - claimedCount(), #free)
		local group = {}
		for _ = 1, count do
			local tile = table.remove(free, rng:NextInteger(1, #free)) :: BasePart
			claimed[tile] = ctx.RuntimeId
			originals[tile] = {
				Color = tile.Color,
				Material = tile.Material,
				Transparency = tile.Transparency,
				CanCollide = tile.CanCollide,
			}
			tile.Color = WARN_COLOR
			tile.Material = Enum.Material.Neon
			table.insert(group, tile)
		end
		if #group == 0 then
			return
		end
		ctx.Delay(WARN_SECONDS, function()
			if not ctx.IsLive() then
				return
			end
			collapse(group)
			ctx.Delay(COLLAPSE_SECONDS, function()
				for _, tile in group do
					restore(tile)
				end
			end)
		end)
	end

	startGroup() -- the first group is warned immediately (no yielding here)
	ctx.Spawn(function()
		local elapsed = 0
		while ctx.IsLive() do
			elapsed += task.wait(CHECK_SECONDS)
			if ctx.IsLive() and elapsed >= cycleSeconds() then
				elapsed = 0
				startGroup()
			end
		end
	end)
end

-- RAPID_DECAY hooks (token = the combination's RuntimeId).
function Decay.AddSpeedup(token: string, factor: number)
	speedups[token] = factor
end

function Decay.RemoveSpeedup(token: string)
	speedups[token] = nil
end

-- Seconds between new tile groups right now.
function Decay.GetCycleSeconds(): number
	return cycleSeconds()
end

-- Tiles currently warned or collapsed by any DECAY patch (for tests and diagnostics).
function Decay.GetClaimedCount(): number
	return claimedCount()
end

-- The tiles currently warned or collapsed (read-only list; Phase 6 SCANNER).
function Decay.GetClaimedTiles(): { BasePart }
	local list = {}
	for tile in claimed do
		table.insert(list, tile)
	end
	return list
end

Decay.Tuning = table.freeze({
	CycleSeconds = CYCLE_SECONDS,
	GroupSize = GROUP_SIZE,
	WarnSeconds = WARN_SECONDS,
	CollapseSeconds = COLLAPSE_SECONDS,
	MaxUnsafe = MAX_UNSAFE,
})

return table.freeze(Decay)
