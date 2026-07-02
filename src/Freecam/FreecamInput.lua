--!nonstrict
local UserInputService = game:GetService("UserInputService")

local FreecamInput = {}
local DESKTOP_MOUSE_DELTA_SCALE = 0.28
local TOUCH_DELTA_SCALE = 0.02
local GAMEPAD_PAN_DELTA = 14
local GAMEPAD_DEADZONE = 0.15

local function applyDeadzone(pos)
	local v = Vector2.new(pos.X, pos.Y)
	local mag = v.Magnitude
	if mag < GAMEPAD_DEADZONE then
		return Vector2.zero
	end
	local scaled = (mag - GAMEPAD_DEADZONE) / (1 - GAMEPAD_DEADZONE)
	return v.Unit * math.clamp(scaled, 0, 1)
end

function FreecamInput.zero(runtime)
	for key in pairs(runtime._keyboard) do
		runtime._keyboard[key] = 0
	end

	runtime._mouseDelta = Vector2.zero
	runtime._mouseWheel = 0
	runtime._mobileZoomIn = false
	runtime._mobileZoomOut = false
	runtime._touchPanId = nil
	runtime._touchPanLast = nil
	runtime._navSpeed = 1

	-- Gamepad state
	runtime._gamepadMove = Vector2.zero
	runtime._gamepadPan = Vector2.zero
	runtime._gamepadUp = 0
	runtime._gamepadDown = 0
end

function FreecamInput.getNavVelocity(runtime, dt, navAdjustSpeed, navShiftMultiplier)
	runtime._navSpeed = math.clamp(runtime._navSpeed + dt * (runtime._keyboard.Up - runtime._keyboard.Down) * navAdjustSpeed, 0.01, 4)

	local gp = runtime._gamepadMove
	local upDown = (runtime._keyboard.E - runtime._keyboard.Q) + (runtime._gamepadUp - runtime._gamepadDown)

	local base = Vector3.new(
		(runtime._keyboard.D - runtime._keyboard.A) + gp.X,
		upDown,
		(runtime._keyboard.S - runtime._keyboard.W) - gp.Y
	)

	local shiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local speedMul = shiftHeld and navShiftMultiplier or 1

	return base * (runtime._navSpeed * speedMul)
end

function FreecamInput.getPanDelta(runtime)
	local delta = runtime._mouseDelta
	runtime._mouseDelta = Vector2.zero

	-- Right thumbstick = pan kamera (continuous, dibaca tiap frame).
	local gp = runtime._gamepadPan
	if gp.X ~= 0 or gp.Y ~= 0 then
		delta += Vector2.new(gp.Y, -gp.X) * GAMEPAD_PAN_DELTA
	end

	return delta
end

function FreecamInput.getFovDelta(runtime, dt)
	local wheel = runtime._mouseWheel
	runtime._mouseWheel = 0

	local hold = 0
	if runtime._mobileZoomIn then
		hold -= 1.6 * dt
	end
	if runtime._mobileZoomOut then
		hold += 1.6 * dt
	end

	return wheel + hold
end

function FreecamInput.startCapture(runtime)
	runtime._captureJanitor:Cleanup()

	runtime._captureJanitor:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not runtime._active then
			return
		end

		-- Gamepad: shoulder buttons = zoom in/out.
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.ButtonR1 then
				runtime._mobileZoomIn = true
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
				runtime._mobileZoomOut = true
			end
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
			runtime._touchPanId = input
			runtime._touchPanLast = input.Position
			return
		end
		if gameProcessed then
			return
		end

		local key = input.KeyCode.Name
		if runtime._keyboard[key] ~= nil then
			runtime._keyboard[key] = 1
		end
	end), "Disconnect")

	runtime._captureJanitor:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			if input.KeyCode == Enum.KeyCode.ButtonR1 then
				runtime._mobileZoomIn = false
			elseif input.KeyCode == Enum.KeyCode.ButtonL1 then
				runtime._mobileZoomOut = false
			end
			return
		end

		if input.UserInputType == Enum.UserInputType.Touch and input == runtime._touchPanId then
			runtime._touchPanId = nil
			runtime._touchPanLast = nil
			return
		end

		local key = input.KeyCode.Name
		if runtime._keyboard[key] ~= nil then
			runtime._keyboard[key] = 0
		end
	end), "Disconnect")

	runtime._captureJanitor:Add(UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not runtime._active then
			return
		end

		-- Gamepad analog: thumbsticks + triggers.
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			local kc = input.KeyCode
			if kc == Enum.KeyCode.Thumbstick1 then
				runtime._gamepadMove = applyDeadzone(input.Position)
			elseif kc == Enum.KeyCode.Thumbstick2 then
				runtime._gamepadPan = applyDeadzone(input.Position)
			elseif kc == Enum.KeyCode.ButtonR2 then
				runtime._gamepadUp = input.Position.Z
			elseif kc == Enum.KeyCode.ButtonL2 then
				runtime._gamepadDown = input.Position.Z
			end
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			runtime._mouseDelta += Vector2.new(-input.Delta.Y, -input.Delta.X) * DESKTOP_MOUSE_DELTA_SCALE
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			runtime._mouseWheel -= input.Position.Z
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and input == runtime._touchPanId and runtime._touchPanLast and not gameProcessed then
			local delta = input.Position - runtime._touchPanLast
			runtime._touchPanLast = input.Position
			runtime._mouseDelta += Vector2.new(-delta.Y, -delta.X) * TOUCH_DELTA_SCALE
		end
	end), "Disconnect")
end

function FreecamInput.stopCapture(runtime)
	runtime._captureJanitor:Cleanup()
	FreecamInput.zero(runtime)
end

function FreecamInput.bindHoldButton(janitor, button, onPress, onRelease)
	if not button then
		return
	end

	janitor:Add(button.MouseButton1Down:Connect(onPress), "Disconnect")
	janitor:Add(button.MouseButton1Up:Connect(onRelease), "Disconnect")
	janitor:Add(button.MouseLeave:Connect(onRelease), "Disconnect")
end

return FreecamInput
