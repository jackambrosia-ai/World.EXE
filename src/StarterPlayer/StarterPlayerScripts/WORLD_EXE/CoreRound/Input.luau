--!strict
-- Input (Core Round Step 1, client): one place for the combat bindings. Roblox's own movement and jump
-- controls are untouched (WASD / left stick / touch thumbstick, Space / A / touch jump).
--   action   keyboard + mouse        gamepad        touch
--   Dash     Q (twice = Super)       B (twice)      DASH button (double-tap)
--   Disc     left mouse              R2             DISC button
--   Shield   hold right mouse        hold L2        SHIELD button (tap toggles; setting: hold)
--   Cursor   Left Alt frees / locks the desktop cursor; F2 diagnostics
-- Touch buttons are compact and placed left of and above the native jump button, clear of the joystick.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Input = {}

type Handlers = { dash: () -> (), throw: () -> (), shield: (boolean) -> (), shieldToggle: () -> (), touchToggle: () -> boolean }

local PRIORITY = Enum.ContextActionPriority.High.Value + 10

function Input.Start(h: Handlers)
	ContextActionService:BindActionAtPriority("CR_Dash", function(_, state)
		if state == Enum.UserInputState.Begin then
			h.dash()
		end
		return Enum.ContextActionResult.Sink
	end, true, PRIORITY, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

	ContextActionService:BindActionAtPriority("CR_Throw", function(_, state, obj)
		if state == Enum.UserInputState.Begin then
			h.throw()
		end
		local _ = obj
		return Enum.ContextActionResult.Sink
	end, true, PRIORITY, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindActionAtPriority("CR_Shield", function(_, state, obj)
		if obj.UserInputType == Enum.UserInputType.Touch and h.touchToggle() then
			if state == Enum.UserInputState.Begin then
				h.shieldToggle()
			end
		else
			if state == Enum.UserInputState.Begin then
				h.shield(true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				h.shield(false)
			end
		end
		return Enum.ContextActionResult.Sink
	end, true, PRIORITY, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	-- touch layout (positions are inside Roblox's ContextActionGui; the jump button sits bottom-right)
	ContextActionService:SetTitle("CR_Dash", "DASH")
	ContextActionService:SetTitle("CR_Throw", "DISC")
	ContextActionService:SetTitle("CR_Shield", "SHIELD")
	ContextActionService:SetPosition("CR_Throw", UDim2.new(1, -190, 1, -170))
	ContextActionService:SetPosition("CR_Dash", UDim2.new(1, -110, 1, -235))
	ContextActionService:SetPosition("CR_Shield", UDim2.new(1, -265, 1, -110))

	-- releasing the shield when focus is lost (alt-tab) so it is never stuck up
	UserInputService.WindowFocusReleased:Connect(function()
		h.shield(false)
	end)
end

return Input
