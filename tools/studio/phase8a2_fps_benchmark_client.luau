-- WORLD.EXE Phase 8A-2: foreground desktop FPS benchmark (CLIENT side). Hardened for Stage 0 (2026-11-11).
--
-- Run (docs/PHASE_8A2_ARCHITECTURE_DESIGN.md section 9.3), together with phase8a2_fps_benchmark_server.luau:
--   1. Start Play (solo) and inject the server Script.
--   2. Execute this file's text in the Play *Client* datamodel through Studio MCP. loadstring is
--      unavailable on the client, so the text is executed directly. It returns immediately; the run
--      continues in task.spawn and writes _G.WORLD_EXE_FPS.
--   3. ARMING: an on-screen banner asks the owner to click once inside the game view. Measurement
--      starts only after (a) that click (a real input event, which proves Studio has focus) and
--      (b) the match is ACTIVE. DRY_RUN = true skips the click; dry-run results are always INVALID.
--   4. Pass A (about 60 s): 5 s at each of 10 fixed views, then a 10 s orbit. Then the client fires
--      "A_done" to the server. Pass B records frames while the server reports
--      ZZ_FPSBench_Phase == "sampling" (three-patch load), orbiting continuously.
--   5. The scripted camera is re-asserted every frame. Studio MCP can reset CameraType after an
--      execute_luau call on the client, so the runner must NOT call the client during a run (poll
--      the server instead). Any detected reset is counted in CameraResets and makes the run INVALID.
--   6. INVALID if: DRY_RUN; focus lost after arming (WindowFocusReleased); camera reset; too few
--      frames; average FPS within +-1 of 15 (Studio background throttle). Invalid runs are reported,
--      never used as measurements.
-- Nothing is saved or persisted. The camera is restored to the follow camera afterwards.

local DRY_RUN = false

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local HOLD = 5
local SETTLE = 0.5
local ORBIT_SECONDS = 10
local ORBIT_RADIUS, ORBIT_Y = 330, 120
local FOV = 70
local ARM_TIMEOUT = 300

local VIEWS = {
	{ "G1", Vector3.new(0, 6, 110), Vector3.new(0, 40, 0) },
	{ "G2", Vector3.new(-235, 6, 60), Vector3.new(0, 30, 0) },
	{ "G3", Vector3.new(20, 6, -145), Vector3.new(0, 10, -250) },
	{ "G4", Vector3.new(40, 6, 150), Vector3.new(0, -5, 240) },
	{ "G5", Vector3.new(200, 54, 10), Vector3.new(0, 30, 0) },
	{ "G6", Vector3.new(225, 30, 225), Vector3.new(0, 15, 0) },
	{ "S_0_147", Vector3.new(0, 5, 147), Vector3.new(0, 60, 0) },
	{ "S_-245_70", Vector3.new(-245, 5, 70), Vector3.new(0, 60, 0) },
	{ "S_175_20", Vector3.new(175, 53, 20), Vector3.new(0, 60, 0) },
	{ "S_0_-250", Vector3.new(0, 5, -250), Vector3.new(0, 60, 0) },
}

local result = { Status = "arming", DryRun = DRY_RUN }
_G.WORLD_EXE_FPS = result

local function matchState()
	local folder = ReplicatedStorage:FindFirstChild("WORLD_EXE")
	folder = folder and folder:FindFirstChild("MatchState")
	local raw = folder and folder:GetAttribute("Snapshot")
	if type(raw) ~= "string" then
		return "?"
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(data) == "table" and type(data.State) == "string" then data.State else "?"
end

local function stats(frames)
	local n = #frames
	if n == 0 then
		return { Frames = 0, AvgFps = 0, OnePercentLowFps = 0, MedianFrameMs = 0, P99FrameMs = 0 }
	end
	local sum = 0
	for _, dt in frames do
		sum += dt
	end
	local asc = table.clone(frames)
	table.sort(asc)
	local worstCount = math.max(1, math.floor(n * 0.01))
	local worstSum = 0
	for i = n - worstCount + 1, n do
		worstSum += asc[i]
	end
	return {
		Frames = n,
		AvgFps = n / sum,
		OnePercentLowFps = worstCount / worstSum,
		MedianFrameMs = asc[math.max(1, math.floor(n * 0.5))] * 1000,
		P99FrameMs = asc[math.max(1, math.ceil(n * 0.99))] * 1000,
		MaxFrameMs = asc[n] * 1000,
	}
end

task.spawn(function()
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "ZZ_FPSBenchBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 36)
	label.BackgroundColor3 = Color3.fromRGB(10, 15, 31)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(245, 247, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = "WORLD.EXE BENCHMARK: click once inside this view, then do not touch anything"
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local clicked = DRY_RUN
	local armConn = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			clicked = true
		end
	end)
	local armStart = os.clock()
	while (not clicked or matchState() ~= "ACTIVE") and os.clock() - armStart < ARM_TIMEOUT do
		if clicked then
			label.Text = "WORLD.EXE BENCHMARK: armed, waiting for the match to start (do not touch)"
		end
		task.wait(0.2)
	end
	armConn:Disconnect()
	if not clicked or matchState() ~= "ACTIVE" then
		result.Status = "done"
		result.Valid = false
		result.InvalidReason = if not clicked then "owner click not received within 300 s" else "match not ACTIVE within 300 s"
		gui:Destroy()
		return
	end

	local focusLost = 0
	local cameraResets = 0
	local recording = nil
	local framesA = {}
	local framesB = {}
	local target = CFrame.lookAt(VIEWS[1][2], VIEWS[1][3])
	local c1 = UserInputService.WindowFocusReleased:Connect(function()
		focusLost += 1
	end)
	local c2 = RunService.RenderStepped:Connect(function(dt)
		if recording == "A" then
			table.insert(framesA, dt)
		elseif recording == "B" then
			table.insert(framesB, dt)
		end
	end)
	-- Re-assert the scripted camera every frame and count external resets.
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("ZZ_FPSBenchCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			cameraResets += 1
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.FieldOfView = FOV
		camera.CFrame = target
	end)

	label.Text = "WORLD.EXE BENCHMARK RUNNING: pass A (about 60 s). Do not touch the mouse or keyboard."
	result.Status = "passA"
	result.MemoryStartMb = Stats:GetTotalMemoryUsageMb()
	result.Viewport = tostring(camera.ViewportSize)
	pcall(function()
		result.QualityLevel = tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)
	end)

	local ok, err = pcall(function()
		camera.CameraType = Enum.CameraType.Scriptable
		task.wait(3)
		for _, view in VIEWS do
			recording = nil
			target = CFrame.lookAt(view[2], view[3])
			task.wait(SETTLE)
			recording = "A"
			task.wait(HOLD - SETTLE)
		end
		recording = nil
		target = CFrame.lookAt(Vector3.new(ORBIT_RADIUS, ORBIT_Y, 0), Vector3.new(0, 60, 0))
		task.wait(SETTLE)
		recording = "A"
		local t0 = os.clock()
		while os.clock() - t0 < ORBIT_SECONDS do
			local a = (os.clock() - t0) / ORBIT_SECONDS * math.pi * 2
			target = CFrame.lookAt(Vector3.new(math.cos(a) * ORBIT_RADIUS, ORBIT_Y, math.sin(a) * ORBIT_RADIUS), Vector3.new(0, 60, 0))
			RunService.RenderStepped:Wait()
		end
		recording = nil
		result.MemoryAfterAMb = Stats:GetTotalMemoryUsageMb()

		local signal = ReplicatedStorage:WaitForChild("ZZ_FPSBenchSignal", 10)
		if signal == nil then
			error("server benchmark signal not found")
		end
		signal:FireServer("A_done")
		label.Text = "WORLD.EXE BENCHMARK RUNNING: pass B (about 40 s). Do not touch the mouse or keyboard."
		result.Status = "passB"
		local tb = os.clock()
		local sawSampling = false
		while os.clock() - tb < 90 do
			local p = workspace:GetAttribute("ZZ_FPSBench_Phase")
			if p == "sampling" then
				sawSampling = true
				recording = "B"
			elseif sawSampling then
				break
			elseif p == "error" then
				break
			end
			local a = (os.clock() - tb) / ORBIT_SECONDS * math.pi * 2
			target = CFrame.lookAt(Vector3.new(math.cos(a) * ORBIT_RADIUS, ORBIT_Y, math.sin(a) * ORBIT_RADIUS), Vector3.new(0, 60, 0))
			RunService.RenderStepped:Wait()
		end
		recording = nil
		result.SawServerSampling = sawSampling
	end)

	c1:Disconnect()
	c2:Disconnect()
	RunService:UnbindFromRenderStep("ZZ_FPSBenchCamera")
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	gui:Destroy()

	result.MemoryEndMb = Stats:GetTotalMemoryUsageMb()
	result.FocusLostEvents = focusLost
	result.CameraResets = cameraResets
	result.PassA = stats(framesA)
	result.PassB = stats(framesB)
	local map = workspace:FindFirstChild("WORLD_EXE") and workspace.WORLD_EXE:FindFirstChild("Map")
	local parts = 0
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	result.StreamedMapParts = parts

	local function verdict(s, minFrames)
		if not ok then
			return "error: " .. tostring(err)
		elseif DRY_RUN then
			return "dry run (no owner focus confirmation)"
		elseif focusLost > 0 then
			return "Studio window focus was lost during the run"
		elseif cameraResets > 0 then
			return "camera was reset externally " .. cameraResets .. " time(s)"
		elseif s.Frames < minFrames then
			return "too few frames (" .. s.Frames .. ")"
		elseif math.abs(s.AvgFps - 15) <= 1 then
			return "average FPS is about 15 (Studio background throttle)"
		end
		return nil
	end
	local ra = verdict(result.PassA, 600)
	local rb = if result.SawServerSampling then verdict(result.PassB, 300) else "server sampling phase not observed"
	result.PassAValid = ra == nil
	result.PassAInvalidReason = ra or ""
	result.PassBValid = rb == nil
	result.PassBInvalidReason = rb or ""
	result.Status = "done"
end)

return "benchmark armed (DRY_RUN=" .. tostring(DRY_RUN) .. ")"
