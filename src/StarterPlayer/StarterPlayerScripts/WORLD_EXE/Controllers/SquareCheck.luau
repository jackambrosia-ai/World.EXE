--!strict
-- SquareCheck (wrist-hacking prototype, client) — Rev 15n, owner reference UI-01 (2026-11-17):
-- "match it to the video, we'll tune from there". PRESENTATION ONLY of the Q-dash skill check; the server
-- still judges (MovementService), timing is unchanged (0.6 s sweep, 0.11 s zone at a random time,
-- 0.04 s late tolerance), one attempt per dash, diamonds unchanged.
--
-- UI-01 (owner video, SHA-256 40970525…, frames 0769-0782, private): a small square sits on the target; a
-- large thin square appears around it and SHRINKS onto it, both warming pale gold -> yellow -> orange ->
-- red as it closes; when they meet the inner square flips PINK, lingers, then fades.
-- WORLD.EXE mapping:
--   * a camera-facing frame (BillboardGui, sized in studs, always on top) centred on YOUR character
--     (first person: the same drawing at the screen centre);
--   * the inner square has a FIXED size (INNER, like the source) with a BAND-thick border;
--   * the outer square closes from OUTER_START onto the inner square's outer edge exactly when the zone
--     opens, crosses the border during the 0.11 s zone (reaching its inner edge exactly when the zone
--     closes), then keeps shrinking: "outer line on the inner square's border" == "inside the zone".
--     The zone time is random, so the closing SPEED varies per dash (as the source's closes at varying pace);
--   * hit: inner square flips pink (with a small pop), outer square vanishes, pink lingers then fades;
--     miss / no press: both grey out and fade (the video shows no miss; ours is deliberately neutral).
-- Drawn on the server clock: the caller passes the check start converted to os.clock() from the
-- server's check.startAt (Rev 15m alignment fix).
-- Not copied from the source: its game, names, fonts, slash effect or any asset (native Frames only).

local Players = game:GetService("Players")

local SquareCheck = {}
SquareCheck.__index = SquareCheck

local OUTER_START = 8 -- studs (the outer square's size when it appears)
local INNER = 3 -- studs, the inner square's outer edge (fixed, frames the torso)
local BAND = 0.35 -- studs, the inner square's border = the zone
local OUTER_END = 1.2 -- studs (the outer square's size when the sweep ends)
local LINE = 0.12 -- studs, outer line thickness
local GLOW = 0.1 -- studs, faint halo around the lines
local HOLD_HIT = 0.14 -- pink holds this long, then fades over FADE
local FADE = 0.25
local SCREEN_PX = 300 -- first-person fallback size

local PALE = Color3.fromRGB(255, 236, 182)
local YELLOW = Color3.fromRGB(255, 214, 92)
local ORANGE = Color3.fromRGB(255, 150, 46)
local RED = Color3.fromRGB(255, 72, 48)
local INNER_COLD = Color3.fromRGB(255, 246, 214)
local PINK = Color3.fromRGB(255, 72, 196)
local GREY = Color3.fromRGB(150, 152, 162)

local function ramp(stops: { Color3 }, p: number): Color3
	p = math.clamp(p, 0, 1) * (#stops - 1)
	local i = math.floor(p)
	if i >= #stops - 1 then
		return stops[#stops]
	end
	return stops[i + 1]:Lerp(stops[i + 2], p - i)
end

type Edges = { Frame }
export type Check = typeof(setmetatable({} :: {
	board: BillboardGui,
	screen: Frame,
	box: Frame,
	outer: Edges,
	outerGlow: Edges,
	inner: Edges,
	innerGlow: Edges,
	start: number,
	sweep: number,
	zoneA: number,
	zoneB: number,
	result: string, -- "" | "hit" | "miss" | "expired"
	resultAt: number,
	active: boolean,
}, SquareCheck))

local function edgeSet(parent: Frame, name: string, z: number): Edges
	local set = {}
	for i = 1, 4 do
		local f = Instance.new("Frame")
		f.Name = name .. i
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = parent
		table.insert(set, f)
	end
	return set
end

-- a square OUTLINE in the box's scale space: outer boundary `size` studs, line `thick` studs (inward)
local function drawSquare(set: Edges, size: number, thick: number, color: Color3, transparency: number)
	local s = math.max(size, 0) / OUTER_START
	local t = math.clamp(thick / OUTER_START, 0, s / 2)
	local x0 = 0.5 - s / 2
	local rects = {
		{ x0, x0, s, t },
		{ x0, 0.5 + s / 2 - t, s, t },
		{ x0, x0 + t, t, s - 2 * t },
		{ 0.5 + s / 2 - t, x0 + t, t, s - 2 * t },
	}
	for i, f in set do
		local r = rects[i]
		f.Position = UDim2.fromScale(r[1], r[2])
		f.Size = UDim2.fromScale(r[3], r[4])
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.Visible = transparency < 1 and s > 0
	end
end

function SquareCheck.new(screenRoot: Instance): Check
	local player = Players.LocalPlayer
	local board = Instance.new("BillboardGui")
	board.Name = "WORLD_EXE_SquareCheck"
	board.Size = UDim2.fromScale(OUTER_START, OUTER_START) -- studs
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.ResetOnSpawn = false
	board.Enabled = false
	board.Parent = player:WaitForChild("PlayerGui")
	local screen = Instance.new("Frame")
	screen.Name = "SquareCheckScreen"
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.fromOffset(SCREEN_PX, SCREEN_PX)
	screen.BackgroundTransparency = 1
	screen.Visible = false
	screen.Parent = screenRoot
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.Size = UDim2.fromScale(1, 1)
	box.BackgroundTransparency = 1
	box.Parent = board
	local self = setmetatable({
		board = board,
		screen = screen,
		box = box,
		outerGlow = edgeSet(box, "OuterGlow", 1),
		innerGlow = edgeSet(box, "InnerGlow", 1),
		inner = edgeSet(box, "Inner", 2),
		outer = edgeSet(box, "Outer", 3),
		start = -1,
		sweep = 0.6,
		zoneA = 0,
		zoneB = 0,
		result = "",
		resultAt = -1,
		active = false,
	}, SquareCheck)
	return self
end

-- outer square size at time rel (piecewise linear, pinned to the zone)
local function sizeAt(self: Check, rel: number): number
	local a, b = self.zoneA, self.zoneB
	local bandIn = INNER - 2 * BAND
	if rel <= a then
		return OUTER_START + (INNER - OUTER_START) * math.clamp(rel / math.max(0.01, a), 0, 1)
	elseif rel <= b then
		return INNER + (bandIn - INNER) * (rel - a) / math.max(0.01, b - a)
	end
	return bandIn + (OUTER_END - bandIn) * math.clamp((rel - b) / math.max(0.01, self.sweep - b), 0, 1)
end

-- start: os.clock() at which the sweep starts (already converted from the server's check.startAt)
function SquareCheck.Start(self: Check, start: number, sweep: number, zoneA: number, zoneB: number)
	self.start, self.sweep, self.zoneA, self.zoneB = start, sweep, zoneA, zoneB
	self.result, self.resultAt = "", -1
	self.active = true
end

function SquareCheck.Result(self: Check, kind: string)
	if self.active and self.result == "" then
		self.result, self.resultAt = kind, os.clock()
	end
end

function SquareCheck.Cancel(self: Check)
	self.active = false
	self.board.Enabled = false
	self.screen.Visible = false
end

function SquareCheck.Visible(self: Check): boolean
	return self.active
end

-- per frame. lateTolerance: the server's CheckLatency (the check is still open that long after the sweep)
function SquareCheck.Update(self: Check, now: number, reduced: boolean, lateTolerance: number)
	if not self.active then
		return
	end
	local rel = now - self.start
	if self.result == "" and rel > self.sweep + lateTolerance + 0.05 then
		self.result, self.resultAt = "expired", now -- no press: the check closed
	end
	local fadeK = 0 -- 0 = fully visible, 1 = gone
	if self.result == "hit" then
		fadeK = math.clamp((now - self.resultAt - HOLD_HIT) / FADE, 0, 1)
	elseif self.result ~= "" then
		fadeK = math.clamp((now - self.resultAt) / FADE, 0, 1)
	end
	if fadeK >= 1 then
		self:Cancel()
		return
	end
	-- where to draw: around my character, or the screen centre in first person
	local player = Players.LocalPlayer
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = c and c:FindFirstChild("Head") :: BasePart?
	local cam = workspace.CurrentCamera
	local firstPerson = cam ~= nil and head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.6
	if root and not firstPerson then
		self.board.Adornee = root
		if self.box.Parent ~= self.board then
			self.box.Parent = self.board
		end
		self.board.Enabled = rel >= 0 or self.result ~= ""
		self.screen.Visible = false
	else
		if self.box.Parent ~= self.screen then
			self.box.Parent = self.screen
		end
		self.board.Enabled = false
		self.screen.Visible = rel >= 0 or self.result ~= ""
	end
	if rel < 0 and self.result == "" then
		return -- CheckDelay: nothing yet
	end
	-- geometry: fixed inner square; the outer line is on its border exactly during the zone (sizeAt)
	local bandOut = INNER
	local bandThick = BAND
	local mid = (self.zoneA + self.zoneB) / 2
	local warm = math.clamp(rel / math.max(0.05, mid), 0, 1) -- 0 at appearance, 1 at the zone centre
	local alpha = fadeK -- extra transparency from fading
	local function tr(base: number): number
		return base + (1 - base) * alpha
	end
	local glowOn = not reduced
	if self.result == "hit" then
		local pop = if reduced then 1 else 1 + 0.12 * math.clamp(1 - (now - self.resultAt) / 0.12, 0, 1)
		drawSquare(self.inner, bandOut * pop, bandThick * pop, PINK, tr(0.05))
		drawSquare(self.innerGlow, (bandOut + GLOW) * pop, (bandThick + 2 * GLOW) * pop, PINK, if glowOn then tr(0.8) else 1)
		drawSquare(self.outer, 0, 0, PINK, 1)
		drawSquare(self.outerGlow, 0, 0, PINK, 1)
		return
	end
	if self.result == "miss" or self.result == "expired" then
		drawSquare(self.inner, bandOut, bandThick, GREY, tr(0.35))
		drawSquare(self.innerGlow, 0, 0, GREY, 1)
		local outSize = sizeAt(self, math.min(rel, self.sweep))
		drawSquare(self.outer, outSize, LINE, GREY, tr(0.4))
		drawSquare(self.outerGlow, 0, 0, GREY, 1)
		return
	end
	local outSize = sizeAt(self, rel)
	local outerColor = ramp({ PALE, YELLOW, ORANGE, RED }, warm)
	local innerColor = ramp({ INNER_COLD, YELLOW, ORANGE, RED }, warm)
	local appear = math.clamp(rel / 0.06, 0, 1) -- quick fade-in, like the source's first frame
	drawSquare(self.outer, outSize, LINE, outerColor, 1 - appear * 0.95)
	drawSquare(self.outerGlow, outSize + GLOW, LINE + 2 * GLOW, outerColor, if glowOn then 1 - appear * (0.1 + 0.15 * warm) else 1)
	drawSquare(self.inner, bandOut, bandThick, innerColor, 1 - appear * 0.9)
	drawSquare(self.innerGlow, bandOut + GLOW, bandThick + 2 * GLOW, innerColor, if glowOn then 1 - appear * (0.1 + 0.15 * warm) else 1)
end

return SquareCheck
