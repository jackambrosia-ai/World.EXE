--!strict
-- Studio-only test patches for the Phase 3 patch engine. They are never in PatchCatalog, so player
-- input cannot reach them; PatchService registers them only when RunService:IsStudio() and only
-- accepts them through Request(..., { Test = true }).
-- The TEST_YIELD_* behaviours deliberately break the non-yielding hook contract and write directly
-- to workspace.Gravity after the yield, to prove that code never runs.

local function marker(ctx: any, name: string): Part
	local part = Instance.new("Part")
	part.Name = `{name}_{ctx.RuntimeId}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Position = Vector3.new(0, -250, 0)
	part.Parent = ctx.Folder
	return part
end

local TestBehaviors = {}

-- Creates one of each resource type: instance, connection, looping thread.
TestBehaviors.TEST_LIFECYCLE = {
	Definition = { DisplayName = "Test Lifecycle", WarningSeconds = 1, DurationSeconds = 2 },
	Activate = function(ctx: any)
		ctx.Add(marker(ctx, "TestMarker"))
		local value = ctx.Add(Instance.new("NumberValue"))
		ctx.Add(value.Changed:Connect(function() end))
		ctx.Add(task.spawn(function()
			while ctx.IsLive() do
				task.wait(0.2)
			end
		end))
	end,
}

TestBehaviors.TEST_GRAVITY_MULTIPLY = {
	Definition = { DisplayName = "Test Gravity x0.5", WarningSeconds = 0.5, DurationSeconds = 3 },
	Activate = function(ctx: any)
		ctx.AddModifier("Gravity", "multiply", 0.5)
	end,
}

TestBehaviors.TEST_GRAVITY_SET_HIGH = {
	Definition = { DisplayName = "Test Gravity =50 (priority 10)", WarningSeconds = 0.5, DurationSeconds = 3 },
	Activate = function(ctx: any)
		ctx.AddModifier("Gravity", "set", 50, 10)
	end,
}

TestBehaviors.TEST_GRAVITY_SET_LOW = {
	Definition = { DisplayName = "Test Gravity =100 (priority 5)", WarningSeconds = 0.5, DurationSeconds = 3 },
	Activate = function(ctx: any)
		ctx.AddModifier("Gravity", "set", 100, 5)
	end,
}

-- Creates resources, then fails: the engine must roll everything back and release the slot.
TestBehaviors.TEST_FAIL_ACTIVATE = {
	Definition = { DisplayName = "Test Failing Activation", WarningSeconds = 0.5, DurationSeconds = 3 },
	Activate = function(ctx: any)
		ctx.Add(marker(ctx, "TestFailMarker"))
		ctx.AddModifier("Gravity", "multiply", 0.25)
		error("injected activation failure")
	end,
}

-- Late writes from work that should have been stopped are recorded as attributes on the
-- Workspace.WORLD_EXE root (TestProbe*), so a test can prove they never happen.
local function probe(ctx: any, name: string, delta: number)
	local root = ctx.Folder and ctx.Folder.Parent
	if root then
		root:SetAttribute(name, (root:GetAttribute(name) or 0) + delta)
	end
end

-- Violates the non-yielding contract in Activate: creates resources, yields, then would mutate the
-- world. The engine must cancel it at the yield, roll back, and keep ticking.
TestBehaviors.TEST_YIELD_ACTIVATE = {
	Definition = { DisplayName = "Test Yielding Activate", WarningSeconds = 0.5, DurationSeconds = 3 },
	Activate = function(ctx: any)
		ctx.Add(marker(ctx, "TestYieldMarker"))
		ctx.AddModifier("Gravity", "multiply", 0.5)
		task.wait(2)
		probe(ctx, "TestProbeLate", 1)
		workspace.Gravity = 1
	end,
}

-- Violates the contract in Deactivate: the yield must not delay ending, and the rest never runs.
TestBehaviors.TEST_YIELD_DEACTIVATE = {
	Definition = { DisplayName = "Test Yielding Deactivate", WarningSeconds = 0.5, DurationSeconds = 1 },
	Activate = function(ctx: any)
		ctx.Add(marker(ctx, "TestYieldDeactivateMarker"))
	end,
	Deactivate = function(ctx: any)
		task.wait(2)
		probe(ctx, "TestProbeLate", 1)
		workspace.Gravity = 1
	end,
}

-- Correct long-running work through tracked tasks: a loop that never checks IsLive, slow work, and
-- a delayed call that fires after expiry. All must stop when the patch ends.
TestBehaviors.TEST_TRACKED_TASKS = {
	Definition = { DisplayName = "Test Tracked Tasks", WarningSeconds = 0.5, DurationSeconds = 1.5 },
	Activate = function(ctx: any)
		ctx.Add(marker(ctx, "TestTasksMarker"))
		ctx.Spawn(function()
			while true do
				probe(ctx, "TestProbeTicks", 1)
				task.wait(0.1)
			end
		end)
		ctx.Spawn(function()
			task.wait(4) -- slow work outlasting the patch
			probe(ctx, "TestProbeLate", 1)
			workspace.Gravity = 1
		end)
		ctx.Delay(3, function()
			probe(ctx, "TestProbeLate", 1)
			workspace.Gravity = 1
		end)
	end,
}

return TestBehaviors
