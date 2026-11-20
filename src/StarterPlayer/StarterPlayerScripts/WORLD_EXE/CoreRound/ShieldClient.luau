--!strict
-- ShieldClient (Core Round Step 1, client): the holographic shield input + visuals.
-- Blocking is decided ONLY on the server (CoreCombat.Panel maths). The panel drawn here is a client-local,
-- anchored, non-colliding, non-queryable visual in Workspace.CoreRoundFx: it can never obstruct characters,
-- discs or pickups. It is drawn for every entity whose CR_ShieldUp attribute is true; your own shield shows the
-- moment you press (prediction) and follows the server if it refuses.
-- Look (original WORLD.EXE barrier): a faint ForceField-material hologram fill, a thin neon frame in the team
-- colour, a scan grid, an energy strip along the top edge, crack lines below 50% / 25% energy, a white impact
-- ring where a disc is blocked, and a shatter when it breaks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreRound = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
local CoreConfig = require(CoreRound:WaitForChild("CoreConfig"))
local Fx = require(script.Parent:WaitForChild("Fx"))
local Aim = require(script.Parent:WaitForChild("Aim"))

local ShieldClient = {}

local player = Players.LocalPlayer
local function tune(k: string): number
	return CoreConfig.Tune("Shield", k)
end

ShieldClient.TouchToggle = true -- touch: tap toggles (setting); desktop/gamepad: hold

local localUp = false -- predicted own state
local lastYawSent = 0
local lastSendT = 0
local send: (string, { [string]: any }) -> () = function() end
local stunned: () -> boolean = function()
	return false
end
local onChange: (boolean) -> () = function() end

type Panel = { model: Model, root: Model, fill: BasePart, frame: { BasePart }, energy: BasePart, cracks: { BasePart }, shown: number, up: boolean, wasUp: boolean, yaw: number }
local panels: { [Model]: Panel } = {}

local function colorOf(m: Model): Color3
	local p = Players:GetPlayerFromCharacter(m)
	local team = if p then (if p.Team then p.Team.Name else "") else (m:GetAttribute("CR_Team") :: string?) or ""
	return (CoreConfig.TeamColors :: any)[team] or CoreConfig.NeutralColor
end

local function part(name: string, parent: Instance, material: Enum.Material, color: Color3, transparency: number): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(1, 1, 0.1)
	p.Parent = parent
	return p
end

local function build(m: Model): Panel
	local col = colorOf(m)
	local root = Instance.new("Model")
	root.Name = "Shield_" .. m.Name
	root.Parent = Fx.Folder()
	local fill = part("Fill", root, Enum.Material.ForceField, col, 0.15)
	-- scan grid + label (original WORLD.EXE identity)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.PixelsPerStud = 24
	sg.AlwaysOnTop = false
	sg.Parent = fill
	for i = 1, 5 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = col
		line.BackgroundTransparency = 0.75
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Position = UDim2.fromScale(0, i / 6)
		line.Parent = sg
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.12, 0)
	label.Position = UDim2.fromScale(0, 0.86)
	label.Text = "WORLD.EXE // BARRIER"
	label.TextColor3 = col
	label.TextTransparency = 0.35
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Parent = sg
	local frame = {}
	for i = 1, 4 do
		table.insert(frame, part("Edge" .. i, root, Enum.Material.Neon, col, 0))
	end
	local energy = part("Energy", root, Enum.Material.Neon, Color3.new(1, 1, 1), 0.1)
	local cracks = {}
	for i = 1, 4 do
		local c = part("Crack" .. i, root, Enum.Material.Neon, Color3.new(1, 1, 1), 1)
		table.insert(cracks, c)
	end
	return { model = m, root = root, fill = fill, frame = frame, energy = energy, cracks = cracks, shown = 0, up = false, wasUp = false, yaw = 0 }
end

-- fixed crack layout in panel space: { x, y, length, angle }
local CRACKS = { { -1.6, 0.8, 2.6, 35 }, { 1.2, -0.6, 2.2, -50 }, { 2.0, 1.6, 1.6, 70 }, { -2.3, -1.4, 1.9, -20 } }

local function place(p: Panel, cf: CFrame, w: number, h: number, energyFrac: number)
	local hh = h * p.shown
	p.fill.Size = Vector3.new(w, math.max(0.05, hh), 0.08)
	p.fill.CFrame = cf
	local e = 0.14
	p.frame[1].Size = Vector3.new(w + e, e, e)
	p.frame[1].CFrame = cf * CFrame.new(0, hh / 2, 0)
	p.frame[2].Size = Vector3.new(w + e, e, e)
	p.frame[2].CFrame = cf * CFrame.new(0, -hh / 2, 0)
	p.frame[3].Size = Vector3.new(e, math.max(0.05, hh), e)
	p.frame[3].CFrame = cf * CFrame.new(-w / 2, 0, 0)
	p.frame[4].Size = Vector3.new(e, math.max(0.05, hh), e)
	p.frame[4].CFrame = cf * CFrame.new(w / 2, 0, 0)
	local ew = math.max(0.05, (w - 0.6) * energyFrac)
	p.energy.Size = Vector3.new(ew, 0.18, 0.16)
	p.energy.CFrame = cf * CFrame.new(-(w - 0.6) / 2 + ew / 2, hh / 2 - 0.3, -0.05)
	p.energy.Color = if energyFrac > 0.5 then Color3.new(1, 1, 1) elseif energyFrac > 0.25 then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(255, 80, 80)
	p.fill.Transparency = 0.15 + (1 - energyFrac) * 0.35
	for i, c in p.cracks do
		local def = CRACKS[i]
		local visible = (i <= 2 and energyFrac < 0.5) or (i > 2 and energyFrac < 0.25)
		c.Transparency = if visible and p.shown > 0.9 then 0.2 else 1
		c.Size = Vector3.new(def[3], 0.07, 0.1)
		c.CFrame = cf * CFrame.new(def[1] * w / 8, def[2] * h / 7, -0.06) * CFrame.Angles(0, 0, math.rad(def[4]))
	end
end

local function entityModels(): { Model }
	local out = {}
	for _, pl in Players:GetPlayers() do
		if pl.Character then
			table.insert(out, pl.Character)
		end
	end
	local yard = workspace:FindFirstChild("CoreRoundYard")
	local d = yard and yard:FindFirstChild("Dummies")
	if d then
		for _, m in d:GetChildren() do
			if m:IsA("Model") then
				table.insert(out, m)
			end
		end
	end
	return out
end

function ShieldClient.IsUp(): boolean
	return localUp
end

function ShieldClient.Set(up: boolean)
	local c = player.Character
	if not c then
		return
	end
	if up then
		local now = workspace:GetServerTimeNow()
		local broken = (c:GetAttribute("CR_ShieldBrokenUntil") :: number?) or 0
		local energy = (c:GetAttribute("CR_ShieldEnergy") :: number?) or tune("Energy")
		if stunned() or now < broken or energy <= 1 then
			Fx.Sound("deny")
			return
		end
		if localUp then
			return
		end
		localUp = true
		lastSendT = os.clock()
		lastYawSent = Aim.Yaw()
		send("shield", { up = true, yaw = lastYawSent })
		Fx.Sound("shield_up")
	else
		if not localUp then
			return
		end
		localUp = false
		lastSendT = os.clock()
		send("shield", { up = false })
	end
	onChange(localUp)
end

function ShieldClient.Toggle()
	ShieldClient.Set(not localUp)
end

-- called by Movement when a dash starts (the server lowers it too)
function ShieldClient.ForceDown()
	if localUp then
		localUp = false
		onChange(false)
	end
end

function ShieldClient.OnReject()
	if localUp then
		localUp = false
		onChange(false)
	end
end

function ShieldClient.Start(deps: { send: (string, { [string]: any }) -> (), stunned: () -> boolean, onChange: (boolean) -> () })
	send = deps.send
	stunned = deps.stunned
	onChange = deps.onChange
	player.CharacterAdded:Connect(function()
		ShieldClient.ForceDown()
	end)
	RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow()
		local myChar = player.Character
		-- own shield: follow the server when it drops it (break, stun, dash)
		if localUp and myChar then
			local srvUp = myChar:GetAttribute("CR_ShieldUp")
			local srvBroken = t < ((myChar:GetAttribute("CR_ShieldBrokenUntil") :: number?) or 0)
			if srvUp == false and (srvBroken or os.clock() - lastSendT > 0.5) then
				localUp = false
				onChange(false)
			end
			if stunned() then
				ShieldClient.Set(false)
			end
			-- aim updates while raised
			local yaw = Aim.Yaw()
			if os.clock() - lastSendT >= 1 / tune("AimRate") and math.abs(yaw - lastYawSent) > math.rad(2) then
				lastSendT = os.clock()
				lastYawSent = yaw
				send("aim", { yaw = yaw })
			end
		end
		local seen: { [Model]: boolean } = {}
		for _, m in entityModels() do
			seen[m] = true
			local rootPart = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			local up = m:GetAttribute("CR_ShieldUp") == true
			local yaw = (m:GetAttribute("CR_ShieldYaw") :: number?) or 0
			if m == myChar then
				up = localUp
				yaw = Aim.Yaw()
			end
			local p = panels[m]
			if (up or (p and p.shown > 0)) and rootPart then
				if not p then
					p = build(m)
					panels[m] = p
				end
				local pp = p :: Panel
				local target = if up then 1 else 0
				local rate = dt / math.max(0.02, tune("RaiseSeconds"))
				pp.shown = if target > pp.shown then math.min(1, pp.shown + rate) else math.max(0, pp.shown - rate)
				local n = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
				local c = rootPart.Position + n * tune("Forward") + Vector3.yAxis * tune("Lift")
				local cf = CFrame.lookAt(c, c + n)
				local energy = ((m:GetAttribute("CR_ShieldEnergy") :: number?) or tune("Energy")) / tune("Energy")
				place(pp, cf, tune("Width"), tune("Height"), math.clamp(energy, 0, 1))
				pp.root.Parent = if pp.shown > 0 then Fx.Folder() else nil
				-- break: was up, now down with a broken timer running
				local brokenUntil = (m:GetAttribute("CR_ShieldBrokenUntil") :: number?) or 0
				local srvUp = m:GetAttribute("CR_ShieldUp") == true
				if pp.wasUp and not srvUp and t < brokenUntil then
					Fx.Shards(cf, colorOf(m), tune("Width"), tune("Height"))
					Fx.Sound("shield_break", c)
					pp.shown = 0
				end
				pp.wasUp = srvUp
			elseif p then
				p.wasUp = m:GetAttribute("CR_ShieldUp") == true
			end
		end
		for m, p in panels do
			if not seen[m] or not m.Parent then
				p.root:Destroy()
				panels[m] = nil
			end
		end
	end)
end

return ShieldClient
