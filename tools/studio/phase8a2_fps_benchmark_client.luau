--!strict
-- WORLD.EXE Phase 8A-2: foreground desktop FPS benchmark (CLIENT side).
--
-- How to run (see docs/PHASE_8A2_ARCHITECTURE_DESIGN.md section 9.3):
--   1. Studio Play (solo). The owner keeps the Studio window focused and does not touch the
--      mouse or keyboard for the duration of the run (about 70 s for pass A, about 40 s for pass B).
--   2. Execute this file in the Play *Client* datamodel (Studio MCP execute_luau). Set PASS first.
--   3. It returns immediately; the run continues in task.spawn. Poll _G.WORLD_EXE_FPS until
--      Status == "done", then read the results.
--
-- Nothing is saved or persisted: the run happens in a Play session and all state lives in _G.
-- The camera is restored to the default follow camera afterwards.

local PASS = "A" -- "A" = fixed views plus orbit (visual load); "B" = orbit only (run during the server load pass)

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local WARMUP = 3 -- seconds before recording starts
local HOLD = 5 -- seconds per fixed view
local SETTLE = 0.5 -- seconds excluded after every camera cut
local ORBIT_SECONDS = 10
local ORBIT_RADIUS, ORBIT_Y = 330, 120
local FOV = 70

-- Fixed views: the six reference cameras (section 1) and four spawn views toward the reactor.
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

type Result = { [string]: any }
local result: Result = { Status = "running", Pass = PASS, StartedAt = os.clock() }
_G.WORLD_EXE_FPS = result

task.spawn(function()
	local camera = workspace.CurrentCamera
	local frames: { number } = {}
	local recording = false
	local focusLostEvents = 0
	local focusGainedEvents = 0

	local c1 = UserInputService.WindowFocusReleased:Connect(function()
		focusLostEvents += 1
	end)
	local c2 = UserInputService.WindowFocused:Connect(function()
		focusGainedEvents += 1
	end)
	local c3 = RunService.RenderStepped:Connect(function(dt)
		if recording then
			table.insert(frames, dt)
		end
	end)

	local ok, err = pcall(function()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FOV
		result.MemoryStartMb = Stats:GetTotalMemoryUsageMb()
		result.Viewport = tostring(camera.ViewportSize)
		pcall(function()
			result.QualityLevel = tostring(UserSettings():GetService("UserGameSettings").SavedQualityLevel)
		end)

		-- Warm-up at the first view (lets streaming and shaders settle).
		camera.CFrame = CFrame.lookAt(VIEWS[1][2], VIEWS[1][3])
		task.wait(WARMUP)

		local function hold(position: Vector3, target: Vector3, seconds: number)
			recording = false
			camera.CFrame = CFrame.lookAt(position, target)
			task.wait(SETTLE)
			recording = true
			task.wait(seconds - SETTLE)
			recording = false
		end

		if PASS == "A" then
			for _, view in VIEWS do
				hold(view[2], view[3], HOLD)
			end
		end

		-- Orbit around the reactor (both passes).
		recording = false
		camera.CFrame = CFrame.lookAt(Vector3.new(ORBIT_RADIUS, ORBIT_Y, 0), Vector3.new(0, 60, 0))
		task.wait(SETTLE)
		recording = true
		local t0 = os.clock()
		while os.clock() - t0 < ORBIT_SECONDS do
			local a = (os.clock() - t0) / ORBIT_SECONDS * math.pi * 2
			camera.CFrame = CFrame.lookAt(
				Vector3.new(math.cos(a) * ORBIT_RADIUS, ORBIT_Y, math.sin(a) * ORBIT_RADIUS),
				Vector3.new(0, 60, 0)
			)
			RunService.RenderStepped:Wait()
		end
		recording = false
	end)

	c1:Disconnect()
	c2:Disconnect()
	c3:Disconnect()

	-- Restore the default follow camera.
	local character = Players.LocalPlayer.Character
	camera.CameraType = Enum.CameraType.Custom
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	if not ok then
		result.Status = "error"
		result.Error = tostring(err)
		return
	end

	-- Metrics.
	local n = #frames
	local sum = 0
	for _, dt in frames do
		sum += dt
	end
	local sorted = table.clone(frames)
	table.sort(sorted, function(a, b)
		return a > b
	end) -- worst (longest) first
	local worstCount = math.max(1, math.floor(n * 0.01))
	local worstSum = 0
	for i = 1, worstCount do
		worstSum += sorted[i]
	end
	local ascending = table.clone(frames)
	table.sort(ascending)

	result.Frames = n
	result.AvgFps = if sum > 0 then n / sum else 0
	result.OnePercentLowFps = if worstSum > 0 then worstCount / worstSum else 0
	result.MedianFrameMs = if n > 0 then ascending[math.max(1, math.floor(n * 0.5))] * 1000 else 0
	result.P99FrameMs = if n > 0 then ascending[math.max(1, math.ceil(n * 0.99))] * 1000 else 0
	result.MemoryEndMb = Stats:GetTotalMemoryUsageMb()
	local map = workspace:FindFirstChild("WORLD_EXE") and workspace.WORLD_EXE:FindFirstChild("Map")
	local streamedParts = 0
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				streamedParts += 1
			end
		end
	end
	result.StreamedMapParts = streamedParts
	result.FocusLostEvents = focusLostEvents
	result.FocusGainedEvents = focusGainedEvents

	-- Validity guard: never report a background-throttled run as a measurement.
	local throttled = math.abs(result.AvgFps - 15) <= 1
	result.Valid = focusLostEvents == 0 and not throttled and n > 0
	result.InvalidReason = if focusLostEvents > 0
		then "window focus was lost during the run"
		elseif throttled then "average FPS is about 15 (Studio background throttle)"
		elseif n == 0 then "no frames recorded"
		else nil
	result.Status = "done"
end)

return "benchmark started: pass " .. PASS
