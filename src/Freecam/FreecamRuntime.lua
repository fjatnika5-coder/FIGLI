--!nonstrict
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Packages = Shared.Packages
local Janitor = require(Packages.Janitor)

local FreecamInput = require(script.Parent.FreecamInput)
local FreecamMobileUI = require(script.Parent.FreecamMobileUI)
local FreecamState = require(script.Parent.FreecamState)
local FreecamPlatform = require(script.Parent.FreecamPlatform)
local Hotkeys = require(script.Parent.Parent.OpenFrame.LeftHolderHelpers.Hotkeys)

local LocalPlayer = Players.LocalPlayer

local TWO_PI = math.pi * 2
local NAV_GAIN = 64
local DESKTOP_PAN_GAIN_X = 2.1
local DESKTOP_PAN_GAIN_Y = 2.8
local MOBILE_PAN_GAIN_X = 6
local MOBILE_PAN_GAIN_Y = 8
local CONSOLE_PAN_GAIN_X = 2.4
local CONSOLE_PAN_GAIN_Y = 3.2
local FOV_GAIN = 220
local PITCH_LIMIT = math.rad(89)
local VEL_STIFFNESS = 1.5
local PAN_STIFFNESS = 1.0
local FOV_STIFFNESS = 4.0
local NAV_ADJ_SPEED = 0.75
local NAV_SHIFT_MUL = 0.25
local FOCUS_DISTANCE = 5 -- dekat biar grass tetap render di sekitar kamera

local CONSOLE_TOGGLE_ACTION = "SummitFreecamConsoleToggle"
local CONSOLE_EXIT_ACTION = "SummitFreecamConsoleExit"

local Spring = {}
Spring.__index = Spring

function Spring.new(freq, pos)
	local self = setmetatable({}, Spring)
	self.f = freq
	self.p = pos
	self.v = pos * 0
	return self
end

function Spring:Update(dt, goal)
	local f = self.f * 2 * math.pi
	local p0 = self.p
	local v0 = self.v

	local offset = goal - p0
	local decay = math.exp(-f * dt)

	local p1 = goal + (v0 * dt - offset * (f * dt + 1)) * decay
	local v1 = (f * dt * (offset * f - v0) + v0) * decay

	self.p = p1
	self.v = v1

	return p1
end

function Spring:Reset(pos)
	self.p = pos
	self.v = pos * 0
end

local FreecamRuntime = {}
FreecamRuntime.__index = FreecamRuntime

function FreecamRuntime.new(refs)
	local self = setmetatable({}, FreecamRuntime)
	self._refs = refs or {}
	self._janitor = Janitor.new()
	self._captureJanitor = Janitor.new()
	self._infoJanitor = nil
	self._active = false
	self._hidden = false
	self._bound = false
	self._mode = nil
	self._desktopPanSmoothing = 0.45
	self._navSpeed = 1
	self._cameraPos = Vector3.zero
	self._cameraRot = Vector2.zero
	self._cameraFov = 70
	self._velSpring = Spring.new(VEL_STIFFNESS, Vector3.zero)
	self._panSpring = Spring.new(PAN_STIFFNESS, Vector2.zero)
	self._fovSpring = Spring.new(FOV_STIFFNESS, 0)
	self._keyboard = {
		W = 0,
		A = 0,
		S = 0,
		D = 0,
		E = 0,
		Q = 0,
		Up = 0,
		Down = 0,
		LeftShift = 0,
		RightShift = 0,
	}
	self._mouseDelta = Vector2.zero
	self._mouseWheel = 0
	self._mobileZoomIn = false
	self._mobileZoomOut = false
	-- Gamepad state
	self._gamepadMove = Vector2.zero
	self._gamepadPan = Vector2.zero
	self._gamepadUp = 0
	self._gamepadDown = 0
	self._savedState = nil
	self._renderStepName = string.format("SummitFreecam_%d", LocalPlayer.UserId)
	self._touchPanId = nil
	self._touchPanLast = nil
	self._buttonVisuals = {}
	self._prevSelected = nil
	self._selectedObjectSet = false
	return self
end

-- ============================================================
-- Platform helpers
-- ============================================================

function FreecamRuntime:_getPlatformMode()
	if not self._mode then
		self._mode = FreecamPlatform.getMode()
	end
	return self._mode
end

function FreecamRuntime:_isMobile()
	return self:_getPlatformMode() == FreecamPlatform.Mode.Mobile
end

function FreecamRuntime:_isConsole()
	return self:_getPlatformMode() == FreecamPlatform.Mode.Console
end

function FreecamRuntime:_isDesktop()
	return self:_getPlatformMode() == FreecamPlatform.Mode.Desktop
end

function FreecamRuntime:_shouldUseCustomRuntime()
	return FreecamPlatform.shouldUseCustomRuntime()
end

function FreecamRuntime:_shouldUseNativeRobloxFreecam()
	return FreecamPlatform.shouldUseNativeRobloxFreecam()
end

-- ============================================================
-- Camera step
-- ============================================================

function FreecamRuntime:_getCamera()
	return Workspace.CurrentCamera
end

function FreecamRuntime:_panGains()
	if self:_isMobile() then
		return MOBILE_PAN_GAIN_X, MOBILE_PAN_GAIN_Y
	elseif self:_isConsole() then
		return CONSOLE_PAN_GAIN_X, CONSOLE_PAN_GAIN_Y
	end
	return DESKTOP_PAN_GAIN_X, DESKTOP_PAN_GAIN_Y
end

function FreecamRuntime:_step(dt)
	local camera = self:_getCamera()
	if not camera then
		return
	end

	local vel = self._velSpring:Update(dt, FreecamInput.getNavVelocity(self, dt, NAV_ADJ_SPEED, NAV_SHIFT_MUL))
	local panTarget = FreecamInput.getPanDelta(self)
	if self:_isDesktop() then
		panTarget *= self._desktopPanSmoothing
	end
	local pan = self._panSpring:Update(dt, panTarget)
	local fov = self._fovSpring:Update(dt, FreecamInput.getFovDelta(self, dt))
	local panGainX, panGainY = self:_panGains()

	local zoomFactor = math.sqrt(math.tan(math.rad(70 / 2)) / math.tan(math.rad(self._cameraFov / 2)))

	self._cameraFov = math.clamp(self._cameraFov + fov * FOV_GAIN, 20, 120)
	self._cameraRot = self._cameraRot + Vector2.new(pan.X * panGainX * dt / zoomFactor, pan.Y * panGainY * dt / zoomFactor)
	self._cameraRot = Vector2.new(
		math.clamp(self._cameraRot.X, -PITCH_LIMIT, PITCH_LIMIT),
		self._cameraRot.Y % TWO_PI
	)

	local cameraCFrame = CFrame.new(self._cameraPos)
		* CFrame.fromOrientation(self._cameraRot.X, self._cameraRot.Y, 0)
		* CFrame.new(vel * NAV_GAIN * dt)

	self._cameraPos = cameraCFrame.Position
	camera.CFrame = cameraCFrame
	camera.Focus = cameraCFrame * CFrame.new(0, 0, -FOCUS_DISTANCE)
	camera.FieldOfView = self._cameraFov
end

-- ============================================================
-- UI button binding helpers
-- ============================================================

function FreecamRuntime:_bindMovementButton(button, keyName)
	FreecamInput.bindHoldButton(self._janitor, button, function()
		self._keyboard[keyName] = 1
	end, function()
		self._keyboard[keyName] = 0
	end)
end

function FreecamRuntime:_bindZoomButton(button, field)
	FreecamInput.bindHoldButton(self._janitor, button, function()
		self[field] = true
	end, function()
		self[field] = false
	end)
end

function FreecamRuntime:_applyMobileUi()
	FreecamMobileUI.apply(self)
end

-- Paksa mouse ke state normal (dipanggil dari Stop & Destroy). Hanya relevan
-- bila ada mouse; di mobile/console no-op aman.
function FreecamRuntime:_forceUnlockMouse()
	if not UserInputService.MouseEnabled then
		return
	end
	pcall(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)
end

-- ============================================================
-- Desktop (PC) route: Roblox native freecam only.
-- ============================================================

function FreecamRuntime:_showDesktopInfo()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	if self._infoJanitor then
		self._infoJanitor:Cleanup()
	else
		self._infoJanitor = Janitor.new()
		self._janitor:Add(self._infoJanitor, "Destroy")
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SummitFreecamInfo"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 24)
	label.Size = UDim2.new(0, 340, 0, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.Text = "PC pakai Roblox Freecam — tekan Shift+P"
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	self._infoJanitor:Add(gui, "Destroy")
	task.delay(2.5, function()
		if gui then
			gui:Destroy()
		end
	end)
end

function FreecamRuntime:_bindDesktop()
	-- Tidak ada custom runtime, tidak bind hotkey V, tidak set Scriptable.
	-- Movement UI mobile tidak ditampilkan.
	if self._refs.Root then
		self._refs.Root.Visible = false
	end

	if self._refs.ToggleBtn then
		if self._refs.ToggleBtn:IsA("GuiObject") then
			Hotkeys.setupVisibility(self._refs.ToggleBtn)
		end
		-- Label hotkey diganti jadi Shift+P (Roblox native freecam).
		Hotkeys.setText(self._refs.ToggleHotkey or Hotkeys.getContainer(self._refs.ToggleBtn), "Shift+P")

		-- Klik tombol di PC hanya kasih info kecil, TIDAK mengaktifkan custom freecam.
		self._janitor:Add(self._refs.ToggleBtn.Activated:Connect(function()
			self:_showDesktopInfo()
		end), "Disconnect")
	end
end

-- ============================================================
-- Custom route (mobile + console).
-- ============================================================

function FreecamRuntime:_bindConsoleActions()
	ContextActionService:BindAction(CONSOLE_TOGGLE_ACTION, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		self:Toggle()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonY)

	ContextActionService:BindAction(CONSOLE_EXIT_ACTION, function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if not self._active then
			return Enum.ContextActionResult.Pass
		end
		self:Stop()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)

	self._janitor:Add(function()
		ContextActionService:UnbindAction(CONSOLE_TOGGLE_ACTION)
		ContextActionService:UnbindAction(CONSOLE_EXIT_ACTION)
	end, true, "FreecamConsoleActionCleanup")
end

function FreecamRuntime:_bindCustom()
	if self._refs.ToggleBtn then
		if self._refs.ToggleBtn:IsA("GuiObject") then
			Hotkeys.setupVisibility(self._refs.ToggleBtn)
		end
		if self:_isConsole() then
			Hotkeys.setText(self._refs.ToggleHotkey or Hotkeys.getContainer(self._refs.ToggleBtn), "Y")
		else
			-- Mobile tidak punya keyboard; jangan tampilkan hotkey "V".
			Hotkeys.setText(self._refs.ToggleHotkey or Hotkeys.getContainer(self._refs.ToggleBtn), "")
		end

		self._janitor:Add(self._refs.ToggleBtn.Activated:Connect(function()
			self:Toggle()
		end), "Disconnect")
	end

	self:_bindMovementButton(self._refs.ForwardBtn, "W")
	self:_bindMovementButton(self._refs.BackBtn, "S")
	self:_bindMovementButton(self._refs.LeftBtn, "A")
	self:_bindMovementButton(self._refs.RightBtn, "D")
	self:_bindZoomButton(self._refs.ZoomInBtn, "_mobileZoomIn")
	self:_bindZoomButton(self._refs.ZoomOutBtn, "_mobileZoomOut")

	if self._refs.HideBtn then
		self._janitor:Add(self._refs.HideBtn.Activated:Connect(function()
			self._hidden = not self._hidden
			self:_applyMobileUi()
		end), "Disconnect")
	end

	if self._refs.CloseBtn then
		self._janitor:Add(self._refs.CloseBtn.Activated:Connect(function()
			self:Stop()
		end), "Disconnect")
	end

	if self:_isConsole() then
		self:_bindConsoleActions()
	end

	if self:_isMobile() then
		FreecamMobileUI.applySafeArea(self)
	end
end

-- ============================================================
-- Public API
-- ============================================================

function FreecamRuntime:Toggle()
	if self._active then
		self:Stop()
	else
		self:Start()
	end
end

function FreecamRuntime:Start()
	if self._active then
		return
	end

	-- GUARD: PC tidak pernah jalankan custom runtime (pakai Roblox native freecam).
	if not self:_shouldUseCustomRuntime() then
		return
	end

	local camera = self:_getCamera()
	if not camera then
		return
	end

	self._savedState = FreecamState.save(self, camera)

	-- Kalau saved state mouse jelek (kelock), overwrite ke Default biar restore aman.
	if self._savedState then
		if self._savedState.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
			self._savedState.MouseBehavior = Enum.MouseBehavior.Default
		end
		if self._savedState.MouseIconEnabled == false then
			self._savedState.MouseIconEnabled = true
		end
	end

	self._cameraPos = camera.CFrame.Position
	self._cameraRot = Vector2.new(camera.CFrame:ToEulerAnglesYXZ())
	self._cameraFov = camera.FieldOfView

	self._velSpring:Reset(Vector3.zero)
	self._panSpring:Reset(Vector2.zero)
	self._fovSpring:Reset(0)
	FreecamInput.zero(self)

	local controls = FreecamState.getControls()
	self._controls = controls
	if controls and controls.Disable then
		controls:Disable()
	end

	camera.CameraType = Enum.CameraType.Scriptable

	-- Console: arahkan gamepad selection ke tombol Close supaya tombol A bisa exit.
	if self:_isConsole() and self._refs.CloseBtn then
		self._prevSelected = GuiService.SelectedObject
		self._selectedObjectSet = true
		GuiService.SelectedObject = self._refs.CloseBtn
	end

	self._active = true
	self._hidden = false
	FreecamMobileUI.hide(self)
	FreecamMobileUI.setButtonVisual(self, true)
	self:_applyMobileUi()
	FreecamInput.startCapture(self)
	RunService:BindToRenderStep(self._renderStepName, Enum.RenderPriority.Camera.Value, function(dt)
		self:_step(dt)
	end)
end

function FreecamRuntime:Stop()
	if not self._active then
		return
	end

	self._active = false
	RunService:UnbindFromRenderStep(self._renderStepName)
	FreecamInput.stopCapture(self)
	FreecamState.restore(self, self:_getCamera(), self._savedState, FreecamMobileUI.restore)

	if self._controls and self._controls.Enable then
		self._controls:Enable()
	end
	self._controls = nil
	self._savedState = nil

	-- Restore gamepad selection.
	if self._selectedObjectSet then
		GuiService.SelectedObject = self._prevSelected
		self._prevSelected = nil
		self._selectedObjectSet = false
	end

	-- Safety net mouse.
	self:_forceUnlockMouse()

	FreecamMobileUI.setButtonVisual(self, false)
	self:_applyMobileUi()
end

function FreecamRuntime:Bind()
	if self._bound then
		return
	end
	self._bound = true
	self._mode = self:_getPlatformMode()

	FreecamMobileUI.setButtonVisual(self, false)

	if self._refs.Root then
		self._refs.Root.Visible = false
	end

	if self:_shouldUseNativeRobloxFreecam() then
		self:_bindDesktop()
	else
		self:_bindCustom()
	end
end

function FreecamRuntime:Destroy()
	self:Stop()
	-- Safety net tambahan kalau Destroy dipanggil tanpa lewat Stop.
	self:_forceUnlockMouse()
	if self._selectedObjectSet then
		GuiService.SelectedObject = self._prevSelected
		self._selectedObjectSet = false
	end
	self._captureJanitor:Destroy()
	self._janitor:Destroy()
end

return FreecamRuntime
