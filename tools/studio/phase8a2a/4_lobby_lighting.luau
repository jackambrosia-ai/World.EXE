-- WORLD.EXE Phase 8A-2a builder, step 4: Lobby Observation Bay + night/navy Lighting preset, then
-- parents the built content into Workspace.WORLD_EXE.Map.
-- Lobby: only Wall_N changes (Material/Transparency/Color). Its size, CFrame and CanCollide, the
-- floor, the other walls and the LobbySpawns are untouched. The bay structures (notch cheeks,
-- underside, canopy, shrouds, mullions, signage, brackets, 2 soft lights) are decorative and live in
-- Map.Megastructure.LobbyBay.
local W = assert(_G.W8A2A, "run 0_lib first")
local C, M, P, Strut = W.C, W.M, W.P, W.Strut
local Lighting = game:GetService("Lighting")
local A = "LobbyBay"

-- Tunable lighting baseline (design section 8). WorldModifierService captures Brightness and
-- ExposureCompensation at server start, so BLACKOUT dims from and restores to these values.
-- Tuned in 8A-2a from screenshots: the design's night preset (ClockTime 0.5) rendered the arena
-- almost black, and a low dusk sun left the enclosed hall in shadow. The baseline is a high sun
-- (light enters through the open rib bays; the hall roof does not cast shadows) with a navy
-- atmosphere, contrast and bloom so emissive trims and the reactor core glow.
local PRESET = {
	ClockTime = 13,
	GeographicLatitude = 20,
	Brightness = 1.8,
	ExposureCompensation = 0,
	Ambient = Color3.fromRGB(46, 52, 84),
	OutdoorAmbient = Color3.fromRGB(76, 84, 124),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.6,
	Atmosphere = { Density = 0.3, Offset = 0.1, Color = Color3.fromRGB(32, 42, 82), Decay = Color3.fromRGB(12, 16, 38), Glare = 0, Haze = 1.6 },
	ColorCorrection = { Contrast = 0.2, Saturation = 0.05, TintColor = Color3.fromRGB(235, 240, 255), Brightness = 0 },
	Bloom = { Intensity = 0.9, Size = 28, Threshold = 1 },
}
W.PRESET = PRESET

-- 1. Lobby observation bay.
local wallN = W.wallN
wallN.Material = M.Glass
wallN.Transparency = 0.55
wallN.Color = C.Glass
wallN.Reflectance = 0

local bay = W.Model(W.mega, "LobbyBay", "Persistent")
P(A, bay, "PodUnderside", Vector3.new(50, 10, 50), CFrame.new(0, 151, 420), C.Navy1, M.Metal)
for _, sx in { -1, 1 } do
	P(A, bay, "NotchCheek", Vector3.new(16, 46, 16), CFrame.new(sx * 32, 163, 404), C.Navy2, M.Concrete)
	P(A, bay, "SideShroud", Vector3.new(2, 36, 56), CFrame.new(sx * 45, 168, 420), C.Navy1, M.Metal)
	P(A, bay, "Mullion", Vector3.new(0.6, 5, 0.6), CFrame.new(sx * 8, 162.5, 395.7), C.Steel, M.Metal)
	Strut(A, bay, "Bracket", Vector3.new(sx * 18, 146, 398), Vector3.new(sx * 22, 104, 399), 2, 3, C.Steel, M.Metal)
	local fx = P(A, bay, "Fixture", Vector3.new(2, 0.5, 2), CFrame.new(sx * 12, 185.6, 420), C.Navy0, M.Metal)
	W.Light(A, fx, "PointLight", { Color = Color3.fromRGB(220, 228, 255), Range = 28, Brightness = 0.8, Shadows = false })
end
P(A, bay, "Canopy", Vector3.new(88, 2, 58), CFrame.new(0, 187, 421), C.Navy2, M.Metal)
P(A, bay, "BackShroud", Vector3.new(88, 36, 2), CFrame.new(0, 168, 447), C.Navy1, M.Metal)
local sign = P(A, bay, "Signage", Vector3.new(30, 4, 0.4), CFrame.new(0, 182, 394.6), C.Navy0, M.Metal)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 20
gui.LightInfluence = 0
gui.Parent = sign
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "OBSERVATION 01"
label.TextColor3 = C.Cyan
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Parent = gui

-- 2. Lighting preset.
for _, k in { "ClockTime", "GeographicLatitude", "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" } do
	(Lighting :: any)[k] = PRESET[k]
end
local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
for k, v in PRESET.Atmosphere do
	(atm :: any)[k] = v
end
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
cc.Name = "ColorCorrection"
for k, v in PRESET.ColorCorrection do
	(cc :: any)[k] = v
end
cc.Enabled = true
cc.Parent = Lighting
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then
	for k, v in PRESET.Bloom do
		(bloom :: any)[k] = v
	end
end
local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
if rays then
	rays.Enabled = false
end
local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end
local sky = Lighting:FindFirstChildOfClass("Sky")
if sky then
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
end

-- 3. Parent the built content (two subtrees of a few hundred parts each).
W.arch.Parent = W.map
task.wait()
W.mega.Parent = W.map

local c = W.count(A)
return string.format("lobby bay parts=%d lights=%d; lighting preset applied; content parented (new parts total %d)", c.parts, c.lights, #W.newParts)
