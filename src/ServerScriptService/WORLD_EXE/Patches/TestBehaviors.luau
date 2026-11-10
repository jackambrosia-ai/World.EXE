--!strict
-- Studio-only test patches for the Phase 3 patch engine. They are never in PatchCatalog, so player
-- input cannot reach them; PatchService registers them only when RunService:IsStudio() and only
-- accepts them through Request(..., { Test = true }).

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

return TestBehaviors
