--!strict
-- CoreDummies (Core Round Step 1, server): the yard's target dummies (built by cr_20_build_yard.luau).
-- Each dummy is a Model under Workspace.CoreRoundYard.Dummies with a HumanoidRootPart + Head (anchored parts)
-- and attributes:
--   CR_Dummy = true, CR_Team = "Orange" | "Cyan" | "" (dummies are targets for the other team)
--   CR_MoveA / CR_MoveB (Vector3) + CR_MoveSpeed (studs/s): patrols between A and B (moving target)
--   CR_ShieldFixedYaw (degrees): holds a permanent shield facing that yaw (shield test fixture)
-- A diagnostic BillboardGui "Diag" shows meter / stuns / last hit (server-updated text).

local CoreCombat = require(script.Parent:WaitForChild("CoreCombat"))

local CoreDummies = {}

type D = { model: Model, root: BasePart, a: Vector3?, b: Vector3?, speed: number, phase: number, label: TextLabel? }
local list: { D } = {}

function CoreDummies.Init()
	local yard = workspace:FindFirstChild("CoreRoundYard")
	local folder = yard and yard:FindFirstChild("Dummies")
	if not folder then
		warn("[CoreRound] no Workspace.CoreRoundYard.Dummies (build the yard first)")
		return
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("CR_Dummy") == true then
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				CoreCombat.Register(m, nil)
				local a, b = m:GetAttribute("CR_MoveA"), m:GetAttribute("CR_MoveB")
				local diag = root:FindFirstChild("Diag")
				local label = diag and diag:FindFirstChildWhichIsA("TextLabel") :: TextLabel?
				table.insert(list, {
					model = m,
					root = root,
					a = if typeof(a) == "Vector3" then a else nil,
					b = if typeof(b) == "Vector3" then b else nil,
					speed = (m:GetAttribute("CR_MoveSpeed") :: number?) or 12,
					phase = 0,
					label = label,
				})
			end
		end
	end
end

function CoreDummies.Update(dt: number)
	for _, d in list do
		if d.a and d.b and d.model.Parent then
			local live = d.model:GetAttribute("CR_MoveSpeed")
			if typeof(live) == "number" and live >= 0 and live < 200 then
				d.speed = live -- live-tunable (latency test: running-speed target)
			end
			local span = (d.b - d.a).Magnitude
			if span > 0.1 then
				d.phase = (d.phase + d.speed * dt / span) % 2
				local f = if d.phase <= 1 then d.phase else 2 - d.phase
				local pos = d.a:Lerp(d.b, f)
				local dir = if d.phase <= 1 then (d.b - d.a).Unit else (d.a - d.b).Unit
				local look = Vector3.new(dir.Z, 0, -dir.X) -- face sideways to the path (a crossing target)
				d.model:PivotTo(CFrame.lookAt(pos, pos + look))
			end
		end
		if d.label then
			local m = d.model
			local meter = (m:GetAttribute("CR_Meter") :: number?) or 0
			local stuns = (m:GetAttribute("CR_Stuns") :: number?) or 0
			local last = (m:GetAttribute("CR_LastHit") :: string?) or "-"
			local stunned = workspace:GetServerTimeNow() < ((m:GetAttribute("CR_StunUntil") :: number?) or 0)
			local text = string.format("%s\nmeter %d  stuns %d  last %s%s", m.Name, meter, stuns, last, if stunned then "  STUNNED" else "")
			if d.label.Text ~= text then
				d.label.Text = text
			end
		end
	end
end

function CoreDummies.Find(name: string): Model?
	for _, d in list do
		if d.model.Name == name then
			return d.model
		end
	end
	return nil
end

function CoreDummies.List(): { Model }
	local out = {}
	for _, d in list do
		table.insert(out, d.model)
	end
	return out
end

return CoreDummies
