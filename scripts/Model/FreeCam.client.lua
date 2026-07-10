-- ============================================
-- FREECAM SCRIPT - PROFESSIONAL UI (NO TOPBAR ICON)
-- Controlled by FloatingActionBar
-- ============================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RS = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local cam = workspace.CurrentCamera

-- ============================================
-- KONFIGURASI
-- ============================================
local CONFIG = {
	Panel = {
		SizeMobile = UDim2.new(0.42, 0, 0.28, 0),
		SizePC = UDim2.new(0, 280, 0, 220),
		PositionMobile = UDim2.new(0.98, 0, 0.02, 0),
		PositionPC = UDim2.new(0.98, -15, 0, 60),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor = Color3.fromRGB(18, 18, 22),
		BackgroundTransparency = 0.05,
		CornerRadius = UDim.new(0, 16),
		Padding = 12
	},

	Colors = {
		Primary = Color3.fromRGB(88, 101, 242),
		Secondary = Color3.fromRGB(0, 200, 120),
		Danger = Color3.fromRGB(237, 66, 69),
		Background = Color3.fromRGB(18, 18, 22),
		Surface = Color3.fromRGB(32, 34, 37),
		Border = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(255, 255, 255),
		TextSecondary = Color3.fromRGB(180, 180, 185),
		TextMuted = Color3.fromRGB(120, 120, 125)
	},

	Typography = {
		TitleSize = 18,
		SubtitleSize = 13,
		BodySize = 12,
		CaptionSize = 10,
		Font = Enum.Font.GothamBold,
		FontRegular = Enum.Font.Gotham
	},

	Spacing = {
		Small = 6,
		Medium = 10,
		Large = 14,
		XLarge = 18
	},

	MobileControls = {
		MoveJoystick = {
			Size = UDim2.new(0.20, 0, 0.20, 0),
			Position = UDim2.new(0.04, 0, 0.96, 0),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor = Color3.fromRGB(18, 18, 22),
			BackgroundTransparency = 0.2
		},
		LookJoystick = {
			Size = UDim2.new(0.23, 0, 0.23, 0),
			Position = UDim2.new(0.96, 0, 0.96, 0),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor = Color3.fromRGB(18, 18, 22),
			BackgroundTransparency = 0.2
		},
		UpButton = {
			Size = UDim2.new(0.12, 0, 0.065, 0),
			Position = UDim2.new(0.96, 0, 0.70, 0),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor = Color3.fromRGB(0, 200, 120),
			Text = "⬆️ UP",
			TextSize = 15
		},
		DownButton = {
			Size = UDim2.new(0.12, 0, 0.065, 0),
			Position = UDim2.new(0.96, 0, 0.78, 0),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor = Color3.fromRGB(237, 66, 69),
			Text = "⬇️ DOWN",
			TextSize = 15
		}
	},

	Speed = {
		Default = 32,
		Min = 2,
		Max = 256
	},

	Camera = {
		MouseSensitivity = 0.18,
		SnapDuration = 0.3,
		SmoothFactor = 0.18
	},

	Animation = {
		OpenDuration = 0.45,
		CloseDuration = 0.35,
		EasingStyle = Enum.EasingStyle.Back,
		EasingDirection = Enum.EasingDirection.Out,
		StrokeAnimSpeed = 2.5
	}
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function clamp(v, a, b) 
	return math.max(a, math.min(b, v)) 
end

local function rad(d) 
	return d * math.pi / 180 
end

local function corner(inst, r) 
	local c = Instance.new("UICorner")
	c.CornerRadius = r
	c.Parent = inst
	return c
end

local function addPadding(inst, all)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, all)
	padding.PaddingBottom = UDim.new(0, all)
	padding.PaddingLeft = UDim.new(0, all)
	padding.PaddingRight = UDim.new(0, all)
	padding.Parent = inst
	return padding
end

local function makeDraggable(guiObject)
	local dragging = false
	local dragInput, dragStart, startPos

	local function update(input)
		local delta = input.Position - dragStart
		guiObject.Position = UDim2.new(
			startPos.X.Scale, 
			startPos.X.Offset + delta.X, 
			startPos.Y.Scale, 
			startPos.Y.Offset + delta.Y
		)
	end

	guiObject.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or 
			input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = guiObject.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	guiObject.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or 
			input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
end

local function createStrokeAnimation(stroke)
	local gradient = Instance.new("UIGradient")
	gradient.Parent = stroke

	local colorSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 101, 242)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(88, 101, 242))
	})
	gradient.Color = colorSeq

	spawn(function()
		while gradient and gradient.Parent do
			local tweenInfo = TweenInfo.new(
				CONFIG.Animation.StrokeAnimSpeed, 
				Enum.EasingStyle.Linear, 
				Enum.EasingDirection.InOut, 
				-1,
				false, 
				0
			)
			local tween = TweenService:Create(gradient, tweenInfo, {Rotation = 360})
			tween:Play()
			break
		end
	end)

	return gradient
end

local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- ============================================
-- VARIABEL STATE
-- ============================================
local enabled = false
local conns = {}
local playerModule, controls
local prevWalkSpeed, prevJumpPower, prevJumpHeight
local speed = CONFIG.Speed.Default
local moveDir, vel, velGoal = Vector3.zero, Vector3.zero, Vector3.zero
local upDown, holdLook = 0, false
local rotX, rotY = 0, 0
local lastCF
local moveTouchObj, lookTouchObj, moveCenter

local gui, mobileScreenGui, panel, statusIndicator, mobileGui
local moveBase, moveKnob, lookBase, upBtn, downBtn

local panelOriginalSize
local currentPanelTween
local isAnimating = false

local function forceResetCamera()
	enabled = false
	cam.CameraType = Enum.CameraType.Custom
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
			hum.WalkSpeed = 16
			hum.JumpPower = 50
			hum.JumpHeight = 7.2
		end
	end
	if isMobile and controls then
		pcall(function() controls:Enable() end)
	end
	for _, c in ipairs(conns) do 
		pcall(function() c:Disconnect() end) 
	end
	table.clear(conns)
end

_G.__Freecam_ForceReset = forceResetCamera

-- ============================================
-- PEMBUATAN GUI
-- ============================================

gui = Instance.new("ScreenGui")
gui.Name = "FreecamGUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = pg

mobileScreenGui = Instance.new("ScreenGui")
mobileScreenGui.Name = "FreecamMobileGUI"
mobileScreenGui.IgnoreGuiInset = true
mobileScreenGui.ResetOnSpawn = false
mobileScreenGui.DisplayOrder = 200
mobileScreenGui.Enabled = false
mobileScreenGui.Parent = pg

-- ============================================
-- MAIN PANEL
-- ============================================
panel = Instance.new("Frame")
panel.Name = "FCPanel"
panel.Size = isMobile and CONFIG.Panel.SizeMobile or CONFIG.Panel.SizePC
panel.BackgroundColor3 = CONFIG.Panel.BackgroundColor
panel.BackgroundTransparency = CONFIG.Panel.BackgroundTransparency
panel.Visible = false
panel.ZIndex = 20
panel.Position = isMobile and CONFIG.Panel.PositionMobile or CONFIG.Panel.PositionPC
panel.AnchorPoint = CONFIG.Panel.AnchorPoint
panel.ClipsDescendants = true
panel.BorderSizePixel = 0
corner(panel, CONFIG.Panel.CornerRadius)
addPadding(panel, CONFIG.Panel.Padding)
panel.Parent = gui

panelOriginalSize = isMobile and CONFIG.Panel.SizeMobile or CONFIG.Panel.SizePC

makeDraggable(panel)

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 2
panelStroke.Color = CONFIG.Colors.Border
panelStroke.Transparency = 0
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Parent = panel
createStrokeAnimation(panelStroke)

local contentContainer = Instance.new("Frame")
contentContainer.Name = "Content"
contentContainer.Size = UDim2.new(1, 0, 1, 0)
contentContainer.BackgroundTransparency = 1
contentContainer.ZIndex = 21
contentContainer.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
listLayout.Padding = UDim.new(0, CONFIG.Spacing.Medium)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = contentContainer

-- HEADER
local headerSection = Instance.new("Frame")
headerSection.Name = "Header"
headerSection.Size = UDim2.new(1, 0, 0, 32)
headerSection.BackgroundTransparency = 1
headerSection.LayoutOrder = 1
headerSection.ZIndex = 21
headerSection.Parent = contentContainer

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Font = CONFIG.Typography.Font
title.TextSize = isMobile and 16 or CONFIG.Typography.TitleSize
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextYAlignment = Enum.TextYAlignment.Center
title.TextColor3 = CONFIG.Colors.TextPrimary
title.Text = "📷 Free Camera"
title.ZIndex = 22
title.Parent = headerSection

statusIndicator = Instance.new("Frame")
statusIndicator.Name = "StatusIndicator"
statusIndicator.Size = UDim2.new(0, 10, 0, 10)
statusIndicator.Position = UDim2.new(1, -10, 0.5, -5)
statusIndicator.AnchorPoint = Vector2.new(1, 0.5)
statusIndicator.BackgroundColor3 = CONFIG.Colors.TextMuted
statusIndicator.BorderSizePixel = 0
statusIndicator.ZIndex = 22
corner(statusIndicator, UDim.new(1, 0))
statusIndicator.Parent = headerSection

local statusText = Instance.new("TextLabel")
statusText.Name = "Status"
statusText.Size = UDim2.new(0, 50, 1, 0)
statusText.Position = UDim2.new(1, -30, 0, 0)
statusText.AnchorPoint = Vector2.new(1, 0)
statusText.BackgroundTransparency = 1
statusText.Font = CONFIG.Typography.FontRegular
statusText.TextSize = isMobile and 10 or CONFIG.Typography.CaptionSize
statusText.TextXAlignment = Enum.TextXAlignment.Right
statusText.TextYAlignment = Enum.TextYAlignment.Center
statusText.TextColor3 = CONFIG.Colors.TextMuted
statusText.Text = "OFF"
statusText.ZIndex = 22
statusText.Parent = headerSection

-- CONTROLS INFO
local controlsSection = Instance.new("Frame")
controlsSection.Name = "Controls"
controlsSection.Size = UDim2.new(1, 0, 0, isMobile and 28 or 32)
controlsSection.BackgroundColor3 = CONFIG.Colors.Surface
controlsSection.BorderSizePixel = 0
controlsSection.LayoutOrder = 2
controlsSection.ZIndex = 21
corner(controlsSection, UDim.new(0, 8))
addPadding(controlsSection, CONFIG.Spacing.Small)
controlsSection.Parent = contentContainer

local controlsStroke = Instance.new("UIStroke")
controlsStroke.Thickness = 1
controlsStroke.Color = CONFIG.Colors.Border
controlsStroke.Transparency = 0.92
controlsStroke.Parent = controlsSection

local controlIcon = Instance.new("TextLabel")
controlIcon.Size = UDim2.new(0, 20, 1, 0)
controlIcon.BackgroundTransparency = 1
controlIcon.Font = CONFIG.Typography.Font
controlIcon.TextSize = isMobile and 14 or 16
controlIcon.Text = "🎮"
controlIcon.TextColor3 = CONFIG.Colors.Primary
controlIcon.ZIndex = 22
controlIcon.Parent = controlsSection

local controlHint = Instance.new("TextLabel")
controlHint.Size = UDim2.new(1, -25, 1, 0)
controlHint.Position = UDim2.new(0, 25, 0, 0)
controlHint.BackgroundTransparency = 1
controlHint.Font = CONFIG.Typography.FontRegular
controlHint.TextSize = isMobile and 9 or CONFIG.Typography.BodySize
controlHint.TextXAlignment = Enum.TextXAlignment.Left
controlHint.TextYAlignment = Enum.TextYAlignment.Center
controlHint.TextColor3 = CONFIG.Colors.TextSecondary
controlHint.Text = isMobile and "Touch joystick to move • UP/DOWN" or "RMB + Mouse to look • WASD/Q/E to move"
controlHint.TextTruncate = Enum.TextTruncate.AtEnd
controlHint.ZIndex = 22
controlHint.Parent = controlsSection

-- SPEED CONTROL
local speedSection = Instance.new("Frame")
speedSection.Name = "Speed"
speedSection.Size = UDim2.new(1, 0, 0, isMobile and 55 or 60)
speedSection.BackgroundTransparency = 1
speedSection.LayoutOrder = 3
speedSection.ZIndex = 21
speedSection.Parent = contentContainer

local speedHeader = Instance.new("Frame")
speedHeader.Size = UDim2.new(1, 0, 0, 20)
speedHeader.BackgroundTransparency = 1
speedHeader.ZIndex = 22
speedHeader.Parent = speedSection

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0.5, 0, 1, 0)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = CONFIG.Typography.FontRegular
speedLabel.TextSize = isMobile and 11 or CONFIG.Typography.SubtitleSize
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.TextColor3 = CONFIG.Colors.TextSecondary
speedLabel.Text = "⚡ Speed"
speedLabel.ZIndex = 22
speedLabel.Parent = speedHeader

local speedValue = Instance.new("TextLabel")
speedValue.Size = UDim2.new(0.5, 0, 1, 0)
speedValue.BackgroundTransparency = 1
speedValue.Font = CONFIG.Typography.Font
speedValue.TextSize = isMobile and 13 or CONFIG.Typography.TitleSize
speedValue.TextXAlignment = Enum.TextXAlignment.Right
speedValue.TextColor3 = CONFIG.Colors.Primary
speedValue.Text = tostring(CONFIG.Speed.Default)
speedValue.ZIndex = 22
speedValue.Parent = speedHeader

local sliderBg = Instance.new("Frame")
sliderBg.Name = "SliderBG"
sliderBg.Size = UDim2.new(1, 0, 0, isMobile and 6 or 8)
sliderBg.Position = UDim2.new(0, 0, 0, 28)
sliderBg.BackgroundColor3 = CONFIG.Colors.Surface
sliderBg.BorderSizePixel = 0
sliderBg.ZIndex = 22
corner(sliderBg, UDim.new(1, 0))
sliderBg.Parent = speedSection

local sliderBgStroke = Instance.new("UIStroke")
sliderBgStroke.Thickness = 1
sliderBgStroke.Color = CONFIG.Colors.Border
sliderBgStroke.Transparency = 0.9
sliderBgStroke.Parent = sliderBg

local sliderFill = Instance.new("Frame")
sliderFill.Name = "Fill"
sliderFill.Size = UDim2.new(0.5, 0, 1, 0)
sliderFill.BackgroundColor3 = CONFIG.Colors.Primary
sliderFill.BorderSizePixel = 0
sliderFill.ZIndex = 23
corner(sliderFill, UDim.new(1, 0))
sliderFill.Parent = sliderBg

local minLabel = Instance.new("TextLabel")
minLabel.Size = UDim2.new(0, 30, 0, 14)
minLabel.Position = UDim2.new(0, 0, 1, 2)
minLabel.BackgroundTransparency = 1
minLabel.Font = CONFIG.Typography.FontRegular
minLabel.TextSize = isMobile and 8 or CONFIG.Typography.CaptionSize
minLabel.TextColor3 = CONFIG.Colors.TextMuted
minLabel.Text = tostring(CONFIG.Speed.Min)
minLabel.ZIndex = 22
minLabel.Parent = speedSection

local maxLabel = Instance.new("TextLabel")
maxLabel.Size = UDim2.new(0, 40, 0, 14)
maxLabel.Position = UDim2.new(1, -40, 1, 2)
maxLabel.BackgroundTransparency = 1
maxLabel.Font = CONFIG.Typography.FontRegular
maxLabel.TextSize = isMobile and 8 or CONFIG.Typography.CaptionSize
maxLabel.TextColor3 = CONFIG.Colors.TextMuted
maxLabel.TextXAlignment = Enum.TextXAlignment.Right
maxLabel.Text = tostring(CONFIG.Speed.Max)
maxLabel.ZIndex = 22
maxLabel.Parent = speedSection

-- SNAP BUTTON
local actionSection = Instance.new("Frame")
actionSection.Name = "Actions"
actionSection.Size = UDim2.new(1, 0, 0, isMobile and 28 or 32)
actionSection.BackgroundTransparency = 1
actionSection.LayoutOrder = 4
actionSection.ZIndex = 21
actionSection.Parent = contentContainer

local snapBtn = Instance.new("TextButton")
snapBtn.Name = "SnapButton"
snapBtn.Size = UDim2.new(1, 0, 1, 0)
snapBtn.BackgroundColor3 = CONFIG.Colors.Secondary
snapBtn.BorderSizePixel = 0
snapBtn.Font = CONFIG.Typography.Font
snapBtn.TextSize = isMobile and 11 or CONFIG.Typography.SubtitleSize
snapBtn.TextColor3 = Color3.new(1, 1, 1)
snapBtn.Text = "🎯 Snap to Character"
snapBtn.Visible = false
snapBtn.ZIndex = 22
snapBtn.AutoButtonColor = false
corner(snapBtn, UDim.new(0, 8))
snapBtn.Parent = actionSection

local snapStroke = Instance.new("UIStroke")
snapStroke.Thickness = 1
snapStroke.Color = Color3.new(1, 1, 1)
snapStroke.Transparency = 0.7
snapStroke.Parent = snapBtn

snapBtn.MouseEnter:Connect(function()
	TweenService:Create(snapBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 220, 140)}):Play()
end)
snapBtn.MouseLeave:Connect(function()
	TweenService:Create(snapBtn, TweenInfo.new(0.2), {BackgroundColor3 = CONFIG.Colors.Secondary}):Play()
end)

-- FOOTER
local footerSection = Instance.new("Frame")
footerSection.Name = "Footer"
footerSection.Size = UDim2.new(1, 0, 0, 18)
footerSection.BackgroundTransparency = 1
footerSection.LayoutOrder = 5
footerSection.ZIndex = 21
footerSection.Parent = contentContainer

local footerText = Instance.new("TextLabel")
footerText.Size = UDim2.new(1, 0, 1, 0)
footerText.BackgroundTransparency = 1
footerText.Font = CONFIG.Typography.FontRegular
footerText.TextSize = isMobile and 8 or CONFIG.Typography.CaptionSize
footerText.TextXAlignment = Enum.TextXAlignment.Center
footerText.TextColor3 = CONFIG.Colors.TextMuted
footerText.Text = "Drag panel to reposition"
footerText.ZIndex = 22
footerText.Parent = footerSection

local function updatePanelPos()
	if not panel.Visible then return end
	local inset = GuiService:GetGuiInset()
	if isMobile then
		panel.Position = UDim2.new(CONFIG.Panel.PositionMobile.X.Scale, 0, 0, inset.Y + 15)
	else
		panel.Position = UDim2.new(CONFIG.Panel.PositionPC.X.Scale, CONFIG.Panel.PositionPC.X.Offset, 0, inset.Y + 60)
	end
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updatePanelPos)

-- ============================================
-- MOBILE CONTROLS
-- ============================================
mobileGui = Instance.new("Frame")
mobileGui.Name = "MobileControls"
mobileGui.BackgroundTransparency = 1
mobileGui.Size = UDim2.fromScale(1, 1)
mobileGui.Visible = false
mobileGui.ZIndex = 1
mobileGui.Parent = mobileScreenGui

moveBase = Instance.new("Frame")
moveBase.Size = CONFIG.MobileControls.MoveJoystick.Size
moveBase.AnchorPoint = CONFIG.MobileControls.MoveJoystick.AnchorPoint
moveBase.Position = CONFIG.MobileControls.MoveJoystick.Position
moveBase.BackgroundColor3 = CONFIG.MobileControls.MoveJoystick.BackgroundColor
moveBase.BackgroundTransparency = CONFIG.MobileControls.MoveJoystick.BackgroundTransparency
moveBase.BorderSizePixel = 0
moveBase.ZIndex = 2
corner(moveBase, UDim.new(1, 0))
moveBase.Parent = mobileGui

local moveStroke = Instance.new("UIStroke")
moveStroke.Thickness = 2
moveStroke.Color = CONFIG.Colors.Primary
moveStroke.Transparency = 0.4
moveStroke.Parent = moveBase
createStrokeAnimation(moveStroke)

moveKnob = Instance.new("Frame")
moveKnob.Size = UDim2.fromScale(0.45, 0.45)
moveKnob.AnchorPoint = Vector2.new(0.5, 0.5)
moveKnob.Position = UDim2.fromScale(0.5, 0.5)
moveKnob.BackgroundColor3 = CONFIG.Colors.Primary
moveKnob.BackgroundTransparency = 0.2
moveKnob.BorderSizePixel = 0
moveKnob.ZIndex = 3
corner(moveKnob, UDim.new(1, 0))
moveKnob.Parent = moveBase

lookBase = Instance.new("Frame")
lookBase.Size = CONFIG.MobileControls.LookJoystick.Size
lookBase.AnchorPoint = CONFIG.MobileControls.LookJoystick.AnchorPoint
lookBase.Position = CONFIG.MobileControls.LookJoystick.Position
lookBase.BackgroundColor3 = CONFIG.MobileControls.LookJoystick.BackgroundColor
lookBase.BackgroundTransparency = CONFIG.MobileControls.LookJoystick.BackgroundTransparency
lookBase.BorderSizePixel = 0
lookBase.ZIndex = 2
corner(lookBase, UDim.new(1, 0))
lookBase.Parent = mobileGui

local lookStroke = Instance.new("UIStroke")
lookStroke.Thickness = 2
lookStroke.Color = CONFIG.Colors.Primary
lookStroke.Transparency = 0.4
lookStroke.Parent = lookBase
createStrokeAnimation(lookStroke)

upBtn = Instance.new("TextButton")
upBtn.Size = CONFIG.MobileControls.UpButton.Size
upBtn.AnchorPoint = CONFIG.MobileControls.UpButton.AnchorPoint
upBtn.Position = CONFIG.MobileControls.UpButton.Position
upBtn.BackgroundColor3 = CONFIG.MobileControls.UpButton.BackgroundColor
upBtn.Text = CONFIG.MobileControls.UpButton.Text
upBtn.TextColor3 = Color3.new(1, 1, 1)
upBtn.Font = CONFIG.Typography.Font
upBtn.TextSize = CONFIG.MobileControls.UpButton.TextSize
upBtn.BorderSizePixel = 0
upBtn.ZIndex = 2
corner(upBtn, UDim.new(0, 10))
upBtn.Parent = mobileGui

local upStroke = Instance.new("UIStroke")
upStroke.Thickness = 2
upStroke.Color = Color3.new(1, 1, 1)
upStroke.Transparency = 0.6
upStroke.Parent = upBtn
createStrokeAnimation(upStroke)

downBtn = Instance.new("TextButton")
downBtn.Size = CONFIG.MobileControls.DownButton.Size
downBtn.AnchorPoint = CONFIG.MobileControls.DownButton.AnchorPoint
downBtn.Position = CONFIG.MobileControls.DownButton.Position
downBtn.BackgroundColor3 = CONFIG.MobileControls.DownButton.BackgroundColor
downBtn.Text = CONFIG.MobileControls.DownButton.Text
downBtn.TextColor3 = Color3.new(1, 1, 1)
downBtn.Font = CONFIG.Typography.Font
downBtn.TextSize = CONFIG.MobileControls.DownButton.TextSize
downBtn.BorderSizePixel = 0
downBtn.ZIndex = 2
corner(downBtn, UDim.new(0, 10))
downBtn.Parent = mobileGui

local downStroke = Instance.new("UIStroke")
downStroke.Thickness = 2
downStroke.Color = Color3.new(1, 1, 1)
downStroke.Transparency = 0.6
downStroke.Parent = downBtn
createStrokeAnimation(downStroke)

-- ============================================
-- SLIDER LOGIC
-- ============================================
local dragging = false

local function updateSpeed(percent)
	percent = clamp(percent, 0, 1)
	speed = math.floor(CONFIG.Speed.Min + (CONFIG.Speed.Max - CONFIG.Speed.Min) * percent)
	sliderFill.Size = UDim2.fromScale(percent, 1)
	speedValue.Text = tostring(speed)

	local color = Color3.fromRGB(
		math.floor(88 + (237 - 88) * percent),
		math.floor(101 - (101 - 66) * percent),
		math.floor(242 - (242 - 69) * percent)
	)
	speedValue.TextColor3 = color
	sliderFill.BackgroundColor3 = color
end

local function getSliderPercent(x)
	local left = sliderBg.AbsolutePosition.X
	local width = sliderBg.AbsoluteSize.X
	return clamp((x - left) / width, 0, 1)
end

sliderBg.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		updateSpeed(getSliderPercent(input.Position.X))
	end
end)

UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
		input.UserInputType == Enum.UserInputType.Touch) then
		updateSpeed(getSliderPercent(input.Position.X))
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ============================================
-- SNAP BACK LOGIC
-- ============================================

local function getCharacterHeadCF()
	local char = player.Character
	if not char then return nil end
	local head = char:FindFirstChild("Head")
	if not head then return nil end
	return head.CFrame * CFrame.new(0, 0.6, 3.5) * CFrame.Angles(0, math.rad(180), 0)
end

local function smoothSnapTo(targetCF, duration)
	if not enabled then return end
	duration = duration or CONFIG.Camera.SnapDuration
	local startCF = cam.CFrame
	local startTime = tick()
	local conn
	conn = RS.RenderStepped:Connect(function()
		if not enabled then
			conn:Disconnect()
			return
		end
		local elapsed = tick() - startTime
		local alpha = clamp(elapsed / duration, 0, 1)
		local smooth = 0.5 - 0.5 * math.cos(alpha * math.pi)
		cam.CFrame = startCF:Lerp(targetCF, smooth)
		if alpha >= 1 then
			conn:Disconnect()
		end
	end)
end

snapBtn.MouseButton1Click:Connect(function()
	if not enabled then return end
	local targetCF = getCharacterHeadCF()
	if targetCF then
		smoothSnapTo(targetCF, CONFIG.Camera.SnapDuration)
	end
end)

-- ============================================
-- INPUT HANDLERS
-- ============================================

local function getMoveCenter()
	local ap, as = moveBase.AbsolutePosition, moveBase.AbsoluteSize
	return Vector2.new(ap.X + as.X / 2, ap.Y + as.Y / 2)
end

local function moveAction(_, state, input)
	if not enabled then return Enum.ContextActionResult.Pass end

	if state == Enum.UserInputState.Begin then
		if input.KeyCode == Enum.KeyCode.W then moveDir += Vector3.new(0, 0, -1)
		elseif input.KeyCode == Enum.KeyCode.S then moveDir += Vector3.new(0, 0, 1)
		elseif input.KeyCode == Enum.KeyCode.A then moveDir += Vector3.new(-1, 0, 0)
		elseif input.KeyCode == Enum.KeyCode.D then moveDir += Vector3.new(1, 0, 0)
		elseif input.KeyCode == Enum.KeyCode.Q then upDown -= 1
		elseif input.KeyCode == Enum.KeyCode.E then upDown += 1 end

	elseif state == Enum.UserInputState.End then
		if input.KeyCode == Enum.KeyCode.W then moveDir -= Vector3.new(0, 0, -1)
		elseif input.KeyCode == Enum.KeyCode.S then moveDir -= Vector3.new(0, 0, 1)
		elseif input.KeyCode == Enum.KeyCode.A then moveDir -= Vector3.new(-1, 0, 0)
		elseif input.KeyCode == Enum.KeyCode.D then moveDir -= Vector3.new(1, 0, 0)
		elseif input.KeyCode == Enum.KeyCode.Q then upDown += 1
		elseif input.KeyCode == Enum.KeyCode.E then upDown -= 1 end
	end

	return Enum.ContextActionResult.Sink
end

local function mouseInput(input, processed)
	if not enabled or processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		if input.UserInputState == Enum.UserInputState.Begin then
			holdLook = true
			UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputState == Enum.UserInputState.End then
			holdLook = false
			UIS.MouseBehavior = Enum.MouseBehavior.Default
		end

	elseif input.UserInputType == Enum.UserInputType.MouseMovement and holdLook then
		local d = input.Delta
		rotX = rotX - d.X * CONFIG.Camera.MouseSensitivity * 0.5
		rotY = clamp(rotY - d.Y * CONFIG.Camera.MouseSensitivity * 0.5, -89, 89)
	end
end

UIS.TouchStarted:Connect(function(touch)
	if not enabled or not isMobile then return end
	local pos = Vector2.new(touch.Position.X, touch.Position.Y)
	local vp = cam.ViewportSize

	if not moveTouchObj and pos.X <= vp.X * 0.4 then
		moveTouchObj = touch
		moveCenter = getMoveCenter()

	elseif not lookTouchObj and pos.X >= vp.X * 0.6 then
		lookTouchObj = touch
	end
end)

UIS.TouchMoved:Connect(function(touch)
	if not enabled or not isMobile then return end

	if moveTouchObj and touch == moveTouchObj then
		local pos2 = Vector2.new(touch.Position.X, touch.Position.Y)
		if not moveCenter then moveCenter = getMoveCenter() end
		local d = pos2 - moveCenter
		local r = moveBase.AbsoluteSize.X * 0.45

		if d.Magnitude > r then d = d.Unit * r end

		moveKnob.Position = UDim2.fromOffset(
			d.X + moveBase.AbsoluteSize.X / 2, 
			d.Y + moveBase.AbsoluteSize.Y / 2
		)

		local v = Vector2.new(d.X / r, d.Y / r)
		moveDir = Vector3.new(v.X, 0, v.Y)
	end

	if lookTouchObj and touch == lookTouchObj then
		local d = touch.Delta
		rotX = rotX - d.X * CONFIG.Camera.MouseSensitivity
		rotY = clamp(rotY - d.Y * CONFIG.Camera.MouseSensitivity, -89, 89)
	end
end)

UIS.TouchEnded:Connect(function(touch)
	if not enabled or not isMobile then return end

	if moveTouchObj and touch == moveTouchObj then
		moveTouchObj = nil
		moveKnob.Position = UDim2.fromScale(0.5, 0.5)
		moveDir = Vector3.zero
		moveCenter = nil
	end

	if lookTouchObj and touch == lookTouchObj then
		lookTouchObj = nil
	end
end)

local upHold, downHold = false, false

upBtn.MouseButton1Down:Connect(function() upHold = true end)
upBtn.MouseButton1Up:Connect(function() upHold = false end)
downBtn.MouseButton1Down:Connect(function() downHold = true end)
downBtn.MouseButton1Up:Connect(function() downHold = false end)

local function step(dt)
	if not enabled then return end

	if isMobile then 
		upDown = (upHold and 1 or 0) + (downHold and -1 or 0) 
	end

	local cf = cam.CFrame
	local right = cf.RightVector
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
	local worldUp = Vector3.new(0, 1, 0)

	local moveWorld = (right * moveDir.X) + (flatLook * -moveDir.Z) + (worldUp * upDown)
	velGoal = (moveDir.Magnitude > 0 or upDown ~= 0) and (moveWorld * speed) or Vector3.zero

	vel = vel:Lerp(velGoal, clamp(CONFIG.Camera.SmoothFactor * 60 * dt, 0, 1))

	local rotCF = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), rad(rotX)) * 
		CFrame.fromAxisAngle(Vector3.new(1, 0, 0), rad(rotY))

	if cam.CameraType == Enum.CameraType.Scriptable then
		cam.CFrame = CFrame.new(cf.Position) * rotCF + (vel * dt)
	end
end

-- ============================================
-- ANIMASI PANEL
-- ============================================

local function animateOpenPanel()
	if currentPanelTween then
		currentPanelTween:Cancel()
	end

	isAnimating = true

	panel.Size = UDim2.new(panelOriginalSize.X.Scale, 0, panelOriginalSize.Y.Scale, 0)
	panel.Visible = true

	local tweenInfo = TweenInfo.new(
		CONFIG.Animation.OpenDuration,
		CONFIG.Animation.EasingStyle,
		CONFIG.Animation.EasingDirection
	)

	currentPanelTween = TweenService:Create(panel, tweenInfo, {Size = panelOriginalSize})
	currentPanelTween:Play()

	currentPanelTween.Completed:Connect(function()
		isAnimating = false
		currentPanelTween = nil
	end)
end

local function animateClosePanel()
	if currentPanelTween then
		currentPanelTween:Cancel()
	end

	isAnimating = true

	local targetSize = UDim2.new(panelOriginalSize.X.Scale, 0, panelOriginalSize.Y.Scale, 0)

	local tweenInfo = TweenInfo.new(
		CONFIG.Animation.CloseDuration,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)

	currentPanelTween = TweenService:Create(panel, tweenInfo, {Size = targetSize})
	currentPanelTween:Play()

	currentPanelTween.Completed:Connect(function()
		panel.Visible = false
		isAnimating = false
		currentPanelTween = nil
	end)
end

-- ============================================
-- ENABLE/DISABLE FREECAM
-- ============================================

local function enableFreecam()
	if enabled then return end
	if isAnimating then return end

	enabled = true

	lastCF = cam.CFrame

	local look = cam.CFrame.LookVector
	rotX = math.deg(math.atan2(-look.X, -look.Z))
	rotY = math.deg(math.asin(look.Y))

	cam.CameraType = Enum.CameraType.Scriptable

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			prevWalkSpeed = hum.WalkSpeed
			prevJumpPower = hum.JumpPower
			prevJumpHeight = hum.JumpHeight

			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.JumpHeight = 0
		end
	end

	if isMobile then
		pcall(function()
			if not playerModule then
				playerModule = require(player.PlayerScripts:WaitForChild("PlayerModule"))
			end
			if not controls then
				controls = playerModule:GetControls()
			end
			controls:Disable()
		end)

		pcall(function()
			local touchGui = pg:FindFirstChild("TouchGui")
			if touchGui then touchGui.Enabled = false end
		end)
	end

	CAS:BindAction("FC_Move", moveAction, false,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
		Enum.KeyCode.Q, Enum.KeyCode.E
	)

	table.insert(conns, UIS.InputBegan:Connect(mouseInput))
	table.insert(conns, UIS.InputChanged:Connect(mouseInput))
	table.insert(conns, UIS.InputEnded:Connect(mouseInput))
	table.insert(conns, RS.RenderStepped:Connect(step))

	statusText.Text = "ON"
	statusText.TextColor3 = CONFIG.Colors.Secondary
	statusIndicator.BackgroundColor3 = CONFIG.Colors.Secondary

	spawn(function()
		while enabled do
			TweenService:Create(statusIndicator, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), 
				{BackgroundTransparency = 0.5}):Play()
			wait(0.8)
		end
	end)

	animateOpenPanel()
	snapBtn.Visible = true
	updatePanelPos()
	mobileScreenGui.Enabled = isMobile
	mobileGui.Visible = isMobile
end

local function disableFreecam()
	if not enabled then return end
	if isAnimating then return end

	enabled = false

	moveDir = Vector3.zero
	upDown = 0
	vel = Vector3.zero
	velGoal = Vector3.zero
	moveTouchObj = nil
	lookTouchObj = nil
	moveCenter = nil
	moveKnob.Position = UDim2.fromScale(0.5, 0.5)

	for _, c in ipairs(conns) do 
		pcall(function() c:Disconnect() end) 
	end
	table.clear(conns)

	CAS:UnbindAction("FC_Move")
	UIS.MouseBehavior = Enum.MouseBehavior.Default

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = prevWalkSpeed or 16
			hum.JumpPower = prevJumpPower or 50
			hum.JumpHeight = prevJumpHeight or 7.2
			cam.CameraSubject = hum
		end
	end

	if isMobile then
		pcall(function()
			if controls then
				controls:Enable()
			end
		end)
		pcall(function()
			local touchGui = pg:FindFirstChild("TouchGui")
			if touchGui then
				touchGui.Enabled = true
			end
		end)
	end

	cam.CameraType = Enum.CameraType.Custom

	statusText.Text = "OFF"
	statusText.TextColor3 = CONFIG.Colors.TextMuted
	statusIndicator.BackgroundColor3 = CONFIG.Colors.TextMuted
	statusIndicator.BackgroundTransparency = 0

	animateClosePanel()
	snapBtn.Visible = false
	mobileScreenGui.Enabled = false
	mobileGui.Visible = false

	task.delay(0.5, function()
		if not enabled and char then
			local hum2 = char:FindFirstChildOfClass("Humanoid")
			if hum2 then
				cam.CameraSubject = hum2
			end
		end
	end)
end

_G.__Freecam_Enable = enableFreecam
_G.__Freecam_Disable = disableFreecam

player.CharacterAdded:Connect(function()
	if enabled then 
		disableFreecam() 
	end
end)


