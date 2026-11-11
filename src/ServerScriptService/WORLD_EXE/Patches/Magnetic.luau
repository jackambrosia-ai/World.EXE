--!strict
-- MAGNETIC (Phase 7B): up to MAX_PROPS crates (tagged MagneticProp) are pulled toward safe
-- MagneticPoint markers.
-- * Only BaseParts tagged MagneticProp / MagneticPoint inside Workspace.WORLD_EXE.Map.
-- * Server-controlled and kinematic: the crates stay Anchored and the server moves them with CFrame
--   at UPDATE_SECONDS, so physics ownership never leaves the server and nothing can be flung.
-- * Each crate has one lane: the straight line from its resting place toward the nearest point in
--   its Zone, ending STOP_DISTANCE short of the point on the side the crate comes from (crates from
--   different sides never overlap). The lanes were checked against walls and markers when the arena
--   content was built (tools/studio/phase7b_markers.luau). Crates never leave their lane.
-- * The field flips polarity every PHASE_SECONDS: crates are pulled to the point end of the lane,
--   then pushed back to the resting end, so they keep moving predictably for the whole patch.
-- * Crates never strike players: a crate does not move while any character is within
--   PLAYER_CLEARANCE of its next position (it waits, then continues).
-- * Hooks for combinations (by token, removed at their cleanup):
--     AddSlide  (SLIDE_FIELD)      crates slide faster and are held at the point end (no push back)
--     AddFloat  (FLOATING_DEBRIS)  a function(pos) -> water surface Y or nil; crates float on it
-- * Restore: every crate's original CFrame and Color come back when the patch ends for any reason.
--   Safe restore (review round 1): if a character occupies a crate's resting spot at that moment,
--   the crate is first made non-colliding and see-through (a "ghost") and only then put back, so
--   it can never push or trap anyone. A settle loop (module-level, running only while ghosts
--   exist) makes each ghost solid again, with its original CanCollide and Transparency, as soon as
--   no character overlaps it. Position is exact at once; collision returns when the spot is clear.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

-- Server-only tuning (provisional).
local MAX_PROPS = 8
local UPDATE_SECONDS = 0.1
local SPEED = 6 -- studs/s
local LIFT_SPEED = 4 -- studs/s, vertical (floating)
local STOP_DISTANCE = 3.5
local PHASE_SECONDS = 8 -- pull for this long, then push back for this long
local PLAYER_CLEARANCE = 4 -- horizontal studs between a character and a crate's next position
local FLOAT_SINK = 1 -- a floating crate's bottom sits this far below the water surface
local GHOST_TRANSPARENCY = 0.6
local SETTLE_SECONDS = 0.1
local OCCUPANCY_MARGIN = 0.2 -- studs added around a crate when checking for characters
local PULL_COLOR = Color3.fromRGB(90, 170, 255)
local PUSH_COLOR = Color3.fromRGB(255, 150, 60)

type Entry = {
	prop: BasePart,
	origin: CFrame,
	color: Color3,
	rest: Vector3, -- resting end of the lane
	dest: Vector3, -- point end of the lane (same height)
	baseY: number,
}

local slideBoosts: { [string]: number } = {}
local floatProviders: { [string]: (Vector3) -> number? } = {}
local owners: { [BasePart]: string } = {} -- crate -> RuntimeId of the MAGNETIC patch moving it
type Ghost = { collide: boolean, transparency: number }

local ghosts: { [BasePart]: Ghost } = {} -- restored crates waiting for their spot to clear
local settler: thread? = nil
local stats = { Steps = 0, Paused = 0, Floating = 0, Flips = 0, Deferred = 0, Settled = 0 }

local function tagged(tag: string): { BasePart }
	local root = workspace:FindFirstChild(Config.RootName)
	local map = root and root:FindFirstChild("Map")
	local list = {}
	if map then
		for _, inst in CollectionService:GetTagged(tag) do
			if inst:IsA("BasePart") and inst:IsDescendantOf(map) then
				table.insert(list, inst)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function speedFactor(): number
	local factor = 1
	for _, f in slideBoosts do
		factor = math.max(factor, f)
	end
	return factor
end

local function sliding(): boolean
	return next(slideBoosts) ~= nil
end

local function floatLevel(position: Vector3): number?
	local best: number? = nil
	for _, provider in floatProviders do
		local ok, level = pcall(provider, position)
		if ok and typeof(level) == "number" and (best == nil or level > best) then
			best = level
		end
	end
	return best
end

local function characterPositions(): { Vector3 }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(list, root.Position)
		end
	end
	return list
end

-- True if any character part overlaps a crate-sized box at `cframe`.
local function occupied(cframe: CFrame, size: Vector3): boolean
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	if #characters == 0 then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = false
	return #workspace:GetPartBoundsInBox(cframe, size + Vector3.one * OCCUPANCY_MARGIN, params) > 0
end

-- Makes ghosts solid again once nothing overlaps them; stops by itself when none are left.
local function ensureSettler()
	if settler ~= nil or next(ghosts) == nil then
		return
	end
	settler = task.spawn(function()
		while next(ghosts) ~= nil do
			task.wait(SETTLE_SECONDS)
			for part, ghost in table.clone(ghosts) do
				if part.Parent == nil then
					ghosts[part] = nil
				elseif not occupied(part.CFrame, part.Size) then
					ghosts[part] = nil
					part.CanCollide = ghost.collide
					part.Transparency = ghost.transparency
					stats.Settled += 1
				end
			end
		end
		settler = nil
	end)
end

-- Puts a crate back exactly; ghosts it first if a character is on the spot.
local function restoreCrate(prop: BasePart, origin: CFrame, color: Color3)
	if occupied(origin, prop.Size) then
		if ghosts[prop] == nil then
			ghosts[prop] = { collide = prop.CanCollide, transparency = prop.Transparency }
		end
		prop.CanCollide = false
		prop.Transparency = GHOST_TRANSPARENCY
		stats.Deferred += 1
	end
	prop.CFrame = origin
	prop.Color = color
end

local Magnetic = {}

function Magnetic.Activate(ctx: any)
	local props = tagged(Config.Tags.MagneticProp)
	local points = tagged(Config.Tags.MagneticPoint)
	if #props == 0 or #points == 0 then
		error("no MagneticProp or MagneticPoint markers in the arena")
	end
	local entries: { Entry } = {}
	-- Registered first, so it runs last at cleanup (after the update loop is cancelled).
	ctx.Add(function()
		for _, entry in entries do
			if owners[entry.prop] == ctx.RuntimeId then
				owners[entry.prop] = nil
			end
			pcall(restoreCrate, entry.prop, entry.origin, entry.color)
		end
		ensureSettler()
	end)
	for _, prop in props do
		if #entries >= MAX_PROPS then
			break
		end
		if owners[prop] == nil and prop.Anchored then
			-- Nearest point in the crate's Zone (any point if its Zone has none).
			local zone = prop:GetAttribute("Zone")
			local candidates = {}
			for _, point in points do
				if point:GetAttribute("Zone") == zone then
					table.insert(candidates, point)
				end
			end
			if #candidates == 0 then
				candidates = points
			end
			local point = candidates[1]
			for _, other in candidates do
				if (other.Position - prop.Position).Magnitude < (point.Position - prop.Position).Magnitude then
					point = other
				end
			end
			local flat = Vector3.new(prop.Position.X - point.Position.X, 0, prop.Position.Z - point.Position.Z)
			local away = if flat.Magnitude > 0.01 then flat.Unit else Vector3.xAxis
			local destXZ = Vector3.new(point.Position.X, 0, point.Position.Z) + away * STOP_DISTANCE
			owners[prop] = ctx.RuntimeId
			table.insert(entries, {
				prop = prop,
				origin = prop.CFrame,
				color = prop.Color,
				rest = prop.Position,
				dest = Vector3.new(destXZ.X, prop.Position.Y, destXZ.Z),
				baseY = prop.Position.Y,
			})
			prop.Color = PULL_COLOR
		end
	end
	if #entries == 0 then
		error("every MagneticProp is already in use")
	end

	local started = os.clock()
	local lastPull: boolean? = nil
	ctx.Spawn(function()
		while ctx.IsLive() do
			local dt = task.wait(UPDATE_SECONDS)
			if not ctx.IsLive() then
				break
			end
			local speed = SPEED * speedFactor()
			local pull = sliding() or math.floor((os.clock() - started) / PHASE_SECONDS) % 2 == 0
			if pull ~= lastPull then
				lastPull = pull
				stats.Flips += 1
				for _, entry in entries do
					if entry.prop.Parent ~= nil then
						entry.prop.Color = if pull then PULL_COLOR else PUSH_COLOR
					end
				end
			end
			local characters = characterPositions()
			for _, entry in entries do
				local prop = entry.prop
				if prop.Parent == nil then
					continue
				end
				local pos = prop.Position
				-- Horizontal move along the lane, toward the point end (pull) or the resting end (push).
				local goal = if pull then entry.dest else entry.rest
				local delta = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
				local horizontal = if delta.Magnitude > 0.001 then delta.Unit * math.min(delta.Magnitude, speed * dt) else Vector3.zero
				-- Vertical: rest height, or float on water while FLOATING_DEBRIS supplies a level.
				local targetY = entry.baseY
				local level = floatLevel(pos)
				if level then
					targetY = math.max(entry.baseY, level - FLOAT_SINK + prop.Size.Y / 2)
				end
				local dy = math.clamp(targetY - pos.Y, -LIFT_SPEED * dt, LIFT_SPEED * dt)
				local nextPos = pos + horizontal + Vector3.new(0, dy, 0)
				if (nextPos - pos).Magnitude < 0.001 then
					continue
				end
				local blocked = false
				for _, c in characters do
					local flat = Vector2.new(c.X - nextPos.X, c.Z - nextPos.Z)
					if flat.Magnitude < PLAYER_CLEARANCE + prop.Size.X / 2 and math.abs(c.Y - nextPos.Y) < 8 then
						blocked = true
						break
					end
				end
				if blocked then
					stats.Paused += 1
					continue
				end
				prop.CFrame = entry.origin.Rotation + nextPos
				stats.Steps += 1
				if level then
					stats.Floating += 1
				end
			end
		end
	end)
end

-- Combination hooks (token = the combination's RuntimeId).
function Magnetic.AddSlide(token: string, factor: number)
	slideBoosts[token] = factor
end

function Magnetic.RemoveSlide(token: string)
	slideBoosts[token] = nil
end

function Magnetic.AddFloat(token: string, provider: (Vector3) -> number?)
	floatProviders[token] = provider
end

function Magnetic.RemoveFloat(token: string)
	floatProviders[token] = nil
end

-- Crates currently moved by a MAGNETIC patch (SCANNER and tests).
function Magnetic.GetActiveProps(): { BasePart }
	local list = {}
	for prop in owners do
		table.insert(list, prop)
	end
	return list
end

-- The MagneticPoint markers (SLIDE_FIELD marks them).
function Magnetic.GetPoints(): { BasePart }
	return tagged(Config.Tags.MagneticPoint)
end

-- Restored crates still waiting for their spot to clear (tests).
function Magnetic.GetGhostCount(): number
	local n = 0
	for _ in ghosts do
		n += 1
	end
	return n
end

function Magnetic.GetStats(): { Steps: number, Paused: number, Floating: number, Flips: number, Deferred: number, Settled: number }
	return table.clone(stats)
end

Magnetic.Tuning = table.freeze({
	MaxProps = MAX_PROPS,
	UpdateSeconds = UPDATE_SECONDS,
	Speed = SPEED,
	StopDistance = STOP_DISTANCE,
	PhaseSeconds = PHASE_SECONDS,
	PlayerClearance = PLAYER_CLEARANCE,
	FloatSink = FLOAT_SINK,
})

return Magnetic
