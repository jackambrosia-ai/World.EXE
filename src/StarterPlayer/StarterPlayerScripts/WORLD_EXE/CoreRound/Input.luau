--!strict
-- Input (Core Round Step 1 / 1B, client): one place for the combat bindings. Roblox's own movement and jump
-- controls are untouched (WASD / left stick / touch thumbstick, Space / A / touch jump).
--   action   keyboard + mouse             gamepad          touch
--   Slide    hold Left Shift or C (1D)    hold B (1B)      SLIDE button (tap toggles)
--   Jump     (Roblox jump) while sliding = Power Slide Jump (1D)
--   Dash     Q (twice = Super)            X (twice)        DASH button (double-tap)
--   Disc     left mouse: tap / hold       R2: tap / hold   DISC button: tap / hold (1B: hold charges, release throws)
--   Shield   hold right mouse             hold L2          SHIELD button (tap toggles; setting: hold)
--   Cursor   Left Alt frees / locks the desktop cursor; F2 diagnostics
-- Step 1B: dash moved from gamepad B to X so B (the usual crouch button) can slide. Touch buttons are compact and placed
-- left of and above the native jump button, clear of the joystick.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Input = {}

type Handlers = {
	dash: () -> (),
	throwDown: () -> (),
	throwUp: () -> (),
	shield: (boolean) -> (),
	shieldToggle: () -> (),
	touchToggle: () -> boolean,
	slide: (boolean) -> (),
	slideToggle: () -> (),
}

local PRIORITY = Enum.ContextActionPriority.High.Value + 10

function Input.Start(h: Handlers)
	ContextActionService:BindActionAtPriority("CR_Dash", function(_, state)
		if state == Enum.UserInputState.Begin then
			h.dash()
		end
		return Enum.ContextActionResult.Sink
	end, true, PRIORITY, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	ContextActionService:BindActionAtPriority("CR_Throw", function(_, state)
		if state == Enum.UserInputState.Begin then
			h.throwDown()
		elseif state == Enum.UserInputState.End then
			h.throwUp()
		elseif state == Enum.UserInputState.Cancel then
			h.throwUp()
		end
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

	ContextActionService:BindActionAtPriority("CR_Slide", function(_, state, obj)
		if obj.UserInputType == Enum.UserInputType.Touch then
			if state == Enum.UserInputState.Begin then
				h.slideToggle()
			end
		elseif state == Enum.UserInputState.Begin then
			h.slide(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			h.slide(false)
		end
		return Enum.ContextActionResult.Sink
	-- Step 1D: Left Shift replaces Left Ctrl (owner-reported bug: in Studio test windows Ctrl + A / Ctrl + D while
	-- sliding are Studio's Select All / Duplicate, which duplicated every character and the yard in that window; Left
	-- Shift is also the reference's slide key). Roblox's shift-lock toggle is disabled for Core Round (own aim lock).
	end, true, PRIORITY, Enum.KeyCode.LeftShift, Enum.KeyCode.C, Enum.KeyCode.ButtonB)

	-- touch layout (positions are inside Roblox's ContextActionGui; the jump button sits bottom-right)
	ContextActionService:SetTitle("CR_Dash", "DASH")
	ContextActionService:SetTitle("CR_Throw", "DISC")
	ContextActionService:SetTitle("CR_Shield", "SHIELD")
	ContextActionService:SetTitle("CR_Slide", "SLIDE")
	ContextActionService:SetPosition("CR_Throw", UDim2.new(1, -190, 1, -170))
	ContextActionService:SetPosition("CR_Dash", UDim2.new(1, -110, 1, -235))
	ContextActionService:SetPosition("CR_Shield", UDim2.new(1, -265, 1, -110))
	ContextActionService:SetPosition("CR_Slide", UDim2.new(1, -190, 1, -90))

	-- losing focus (alt-tab) releases held actions so nothing is stuck
	UserInputService.WindowFocusReleased:Connect(function()
		h.shield(false)
		h.slide(false)
	end)
end

return Input
