--!strict
-- HackDevice (wrist-hacking prototype, server): the PLACEHOLDER wrist device on every character's
-- left forearm. Owner direction 2026-11-16: "make the device look like an omnitrix as a place
-- holder" -> an original chunky sci-fi wrist gauntlet in that spirit (band, raised round face,
-- glowing green core, spinning dial ring, side buttons). No franchise emblem or exact design is
-- copied; native parts only, no assets. Massless, non-colliding, non-queryable.
--
-- The core colour shows the hack state for everyone nearby: idle green, hacking amber,
-- success cyan flash, failure red flash. The client spins the dial (local only) while the
-- terminal is open.

local HackDevice = {}

local C_IDLE = Color3.fromRGB(70, 230, 90)
local C_HACK = Color3.fromRGB(255, 193, 7)
local C_OK = Color3.fromRGB(0, 225, 255)
local C_FAIL = Color3.fromRGB(255, 80, 70)
local C_BODY = Color3.fromRGB(40, 44, 52)
local C_TRIM = Color3.fromRGB(150, 156, 168)
local C_FACE = Color3.fromRGB(16, 18, 22)

local function piece(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function HackDevice.Attach(character: Model)
	local arm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
	if not arm or not arm:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("WristDevice")
	if old then
		old:Destroy()
	end
	local r15 = arm.Name == "LeftLowerArm"
	local m = Instance.new("Model")
	m.Name = "WristDevice"
	-- wrist position: near the hand end of the forearm
	local yOff = if r15 then -arm.Size.Y * 0.25 else -arm.Size.Y * 0.25
	local base = arm.CFrame * CFrame.new(0, yOff, 0)
	local w, d = arm.Size.X, arm.Size.Z
	local band = piece(m, "Band", Vector3.new(w + 0.22, 0.62, d + 0.22), base, C_BODY, Enum.Material.Metal)
	piece(m, "TrimTop", Vector3.new(w + 0.28, 0.08, d + 0.28), base * CFrame.new(0, 0.31, 0), C_TRIM, Enum.Material.Metal)
	piece(m, "TrimBottom", Vector3.new(w + 0.28, 0.08, d + 0.28), base * CFrame.new(0, -0.31, 0), C_TRIM, Enum.Material.Metal)
	-- the face sits on the outside of the left forearm (-X in the arm's frame); cylinders run along X
	local out = -(w / 2 + 0.11)
	local faceSize = math.max(0.9, d * 0.95)
	local housing = piece(m, "Housing", Vector3.new(0.22, faceSize + 0.18, faceSize + 0.18), base * CFrame.new(out, 0, 0), C_BODY, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(m, "Bezel", Vector3.new(0.12, faceSize + 0.04, faceSize + 0.04), base * CFrame.new(out - 0.1, 0, 0), C_TRIM, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece(m, "Face", Vector3.new(0.1, faceSize - 0.12, faceSize - 0.12), base * CFrame.new(out - 0.14, 0, 0), C_FACE, Enum.Material.Glass, Enum.PartType.Cylinder)
	local core = piece(m, "Core", Vector3.new(0.08, faceSize * 0.45, faceSize * 0.45), base * CFrame.new(out - 0.2, 0, 0), C_IDLE, Enum.Material.Neon, Enum.PartType.Cylinder)
	-- dial ring with four ticks (spun locally by the client while the terminal is open)
	local dial = piece(m, "Dial", Vector3.new(0.06, faceSize - 0.2, faceSize - 0.2), base * CFrame.new(out - 0.17, 0, 0), C_IDLE, Enum.Material.Neon, Enum.PartType.Cylinder)
	dial.Transparency = 0.75
	for i = 0, 3 do
		local a = i * math.pi / 2
		local r = (faceSize - 0.3) / 2
		local tick = piece(m, "DialTick", Vector3.new(0.05, 0.1, 0.22), base * CFrame.new(out - 0.21, math.sin(a) * r, math.cos(a) * r) * CFrame.Angles(a, 0, 0), C_IDLE, Enum.Material.Neon)
		local tw = Instance.new("WeldConstraint")
		tw.Part0 = tick
		tw.Part1 = dial
		tw.Parent = tick
	end
	-- side buttons
	piece(m, "ButtonA", Vector3.new(0.2, 0.2, 0.18), base * CFrame.new(out + 0.02, 0, faceSize / 2 + 0.12), C_TRIM, Enum.Material.Metal)
	piece(m, "ButtonB", Vector3.new(0.2, 0.2, 0.18), base * CFrame.new(out + 0.02, 0, -faceSize / 2 - 0.12), C_TRIM, Enum.Material.Metal)
	-- welds: everything to the band, band to the arm; the dial uses a Weld (C0 is spun client-side)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p ~= band and p ~= dial and p.Name ~= "DialTick" then
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = p
			wc.Part1 = band
			wc.Parent = p
		end
	end
	local dw = Instance.new("Weld")
	dw.Name = "DialWeld"
	dw.Part0 = housing
	dw.Part1 = dial
	dw.C0 = housing.CFrame:ToObjectSpace(dial.CFrame)
	dw.Parent = dial
	local aw = Instance.new("WeldConstraint")
	aw.Part0 = band
	aw.Part1 = arm
	aw.Parent = band
	m:SetAttribute("State", "idle")
	m.Parent = character
	return m
end

local serial: { [Model]: number } = {}

function HackDevice.SetState(character: Model?, state: string)
	local m = character and character:FindFirstChild("WristDevice")
	if not m then
		return
	end
	local color = if state == "hacking" then C_HACK elseif state == "ok" then C_OK elseif state == "fail" then C_FAIL else C_IDLE
	local function paint(c: Color3)
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "Core" or p.Name == "Dial" or p.Name == "DialTick") then
				p.Color = c
			end
		end
	end
	paint(color)
	m:SetAttribute("State", state)
	if state == "ok" or state == "fail" then
		serial[character :: Model] = (serial[character :: Model] or 0) + 1
		local mine = serial[character :: Model]
		task.delay(0.7, function()
			if serial[character :: Model] == mine and m.Parent then
				paint(C_IDLE)
				m:SetAttribute("State", "idle")
			end
		end)
	end
end

return HackDevice
