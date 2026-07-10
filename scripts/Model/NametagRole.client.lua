-- NAMETAG MANAGER - TOPBAR ICON (TopbarPlus Integration)
-- Place this in StarterPlayerScripts
-- Requires TopbarPlus/Icon module in ReplicatedStorage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local ManagerFolder = ReplicatedStorage:WaitForChild("NameTagManager", 10)
if not ManagerFolder then return end

local CheckAccessFunction  = ManagerFolder:WaitForChild("CheckAccess")
local GetPlayersFunction   = ManagerFolder:WaitForChild("GetPlayers")
local GetRolesFunction     = ManagerFolder:WaitForChild("GetRoles")
local GetDurationsFunction = ManagerFolder:WaitForChild("GetDurations")
local GetIconsFunction     = ManagerFolder:WaitForChild("GetIcons")
local AssignRoleEvent      = ManagerFolder:WaitForChild("AssignRole")
local RemoveRoleEvent      = ManagerFolder:WaitForChild("RemoveRole")
local RefreshNameTagEvent  = ManagerFolder:WaitForChild("RefreshNameTag")

local hasAccess = CheckAccessFunction:InvokeServer()
if not hasAccess then return end

-- ============================================
-- SCREEN INFO
-- ============================================
local screenInfo = {}

local function updateScreenInfo()
	local vp = workspace.CurrentCamera.ViewportSize
	-- Mobile: touch enabled tapi bukan keyboard (tablet/phone)
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	-- Scale berbasis lebar layar, lebih agresif untuk mobile
	local scale
	if isMobile then
		-- Mobile: scale dari 1.0 (phone kecil 360px) hingga 1.3 (tablet 768px)
		scale = math.clamp(vp.X / 420, 1.0, 1.35)
	else
		scale = math.clamp(vp.X / 1920, 0.75, 1.1)
	end
	screenInfo.width    = vp.X
	screenInfo.height   = vp.Y
	screenInfo.isMobile = isMobile
	screenInfo.scale    = scale
end

updateScreenInfo()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScreenInfo)

-- ============================================
-- COLORS
-- ============================================
local COLORS = {
	background     = Color3.fromRGB(8, 8, 12),
	surface        = Color3.fromRGB(14, 14, 20),
	surfaceElevated= Color3.fromRGB(22, 22, 32),
	surfaceHover   = Color3.fromRGB(32, 32, 45),
	textPrimary    = Color3.fromRGB(245, 245, 250),
	textSecondary  = Color3.fromRGB(140, 140, 160),
	textMuted      = Color3.fromRGB(80, 80, 100),
	accent         = Color3.fromRGB(99, 102, 241),
	success        = Color3.fromRGB(34, 197, 94),
	danger         = Color3.fromRGB(239, 68, 68),
	warning        = Color3.fromRGB(245, 158, 11),
	closeButton    = Color3.fromRGB(255, 100, 100),
}

local PRESET_COLORS = {
	{Name="White",  Color=Color3.fromRGB(255,255,255)},
	{Name="Red",    Color=Color3.fromRGB(255,50,50)},
	{Name="Orange", Color=Color3.fromRGB(255,165,0)},
	{Name="Yellow", Color=Color3.fromRGB(255,255,0)},
	{Name="Green",  Color=Color3.fromRGB(50,255,50)},
	{Name="Cyan",   Color=Color3.fromRGB(0,255,255)},
	{Name="Blue",   Color=Color3.fromRGB(50,50,255)},
	{Name="Purple", Color=Color3.fromRGB(170,0,255)},
	{Name="Pink",   Color=Color3.fromRGB(255,85,255)},
	{Name="Black",  Color=Color3.fromRGB(0,0,0)},
}

local ICON_DISPLAY = {
	Founder   = "👑",
	CoFounder = "⭐",
	Member    = "👤",
	Player    = "🎮",
	Verified  = "✓",
}

-- ============================================
-- HELPER: SCALED VALUES
-- ============================================

-- Pixel value diskalakan ke screen
local function px(v)
	return math.floor(v * screenInfo.scale)
end

-- Text size: mobile dapat ukuran lebih gede supaya lebih mudah dibaca
local function ts(base)
	local m = screenInfo.isMobile
	local min = m and 12 or 8
	local max = m and 22 or 18
	return math.clamp(px(m and base * 1.15 or base), min, max)
end

-- Tinggi tombol (tap target): minimal 44 di mobile biar nyaman
local function btnH(preferred)
	return screenInfo.isMobile and math.max(44, px(preferred)) or px(preferred)
end

-- ============================================
-- PANEL DIMENSI (responsif per platform)
-- ============================================
local function getPanelSize()
	local m = screenInfo.isMobile
	local w, h = screenInfo.width, screenInfo.height
	if m then
		-- Mobile: hampir full-screen dengan margin kecil
		return
			math.min(w - 16, 460),   -- lebar max 460 atau layar - 16px margin
		math.min(h - 60, 720)    -- tinggi max 720 atau layar - 60px (buat topbar)
	else
		return px(420), px(640)
	end
end

-- ============================================
-- VARIABLES
-- ============================================
local selectedPlayer      = nil
local selectedRole        = nil
local selectedRoleName    = nil
local selectedDuration    = nil
local selectedGradientColor = nil
local selectedTextColor   = nil
local selectedIcons       = {}
local customTitleText     = ""
local isRGBEnabled        = false

-- ============================================
-- UTILITY
-- ============================================
local function createTween(inst, props, dur)
	return TweenService:Create(inst, TweenInfo.new(dur or 0.2, Enum.EasingStyle.Quart), props)
end

local function createAnimatedStroke(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = screenInfo.isMobile and 2.5 or 2
	stroke.Parent = parent
	local hue = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not stroke.Parent then
			conn:Disconnect()
			return
		end
		hue = (hue + dt * 0.3) % 1
		stroke.Color = Color3.fromHSV(hue, 0.7, 1)
	end)
	return stroke
end

local function makeDraggable(frame, dragHandle)
	-- Mobile: tidak perlu drag (panel sudah center), PC tetap bisa drag
	if screenInfo.isMobile then return end
	local dragging, dragStart, startPos = false, nil, nil
	local handle = dragHandle or frame

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = input.Position
			startPos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function enableHorizontalScroll(scrollFrame)
	local isHovering = false
	scrollFrame.MouseEnter:Connect(function() isHovering = true end)
	scrollFrame.MouseLeave:Connect(function() isHovering = false end)
	UserInputService.InputChanged:Connect(function(input, gp)
		if gp or not isHovering then return end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local cur = scrollFrame.CanvasPosition.X
			local amt = 60 * -input.Position.Z
			scrollFrame.CanvasPosition = Vector2.new(
				math.max(0, math.min(
					scrollFrame.AbsoluteCanvasSize.X - scrollFrame.AbsoluteWindowSize.X,
					cur + amt
					)), 0
			)
		end
	end)
	scrollFrame.ScrollingEnabled = true
end

-- ============================================
-- GUI CREATION
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NameTagManagerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true  -- supaya tidak terpotong safe area di mobile
screenGui.Parent = playerGui

local panelW, panelH = getPanelSize()

-- Padding adaptif: lebih gede di mobile supaya konten tidak terlalu rapat di tepi
local PAD = screenInfo.isMobile and 14 or px(12)

local mainPanel = Instance.new("Frame")
mainPanel.Size = UDim2.new(0, panelW, 0, panelH)
mainPanel.Position = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
mainPanel.BackgroundColor3 = COLORS.background
mainPanel.BorderSizePixel = 0
mainPanel.Visible = false
mainPanel.Parent = screenGui
Instance.new("UICorner", mainPanel).CornerRadius = UDim.new(0, px(16))
createAnimatedStroke(mainPanel)

-- ── HEADER ──────────────────────────────────────────────────────────────────
local headerH = screenInfo.isMobile and 54 or px(45)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -PAD*2, 0, headerH)
header.Position = UDim2.new(0, PAD, 0, PAD)
header.BackgroundTransparency = 1
header.Parent = mainPanel

makeDraggable(mainPanel, header)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -54, 0, headerH * 0.48)
title.BackgroundTransparency = 1
title.Text = "🏷️ NameTag Manager"
title.TextColor3 = COLORS.textPrimary
title.Font = Enum.Font.GothamBlack
title.TextSize = ts(14)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -54, 0, headerH * 0.35)
subtitle.Position = UDim2.new(0, 0, 0, headerH * 0.52)
subtitle.BackgroundTransparency = 1
subtitle.Text = screenInfo.isMobile and "Manage player nametags" or "Manage player nametags • Drag to move"
subtitle.TextColor3 = COLORS.textMuted
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = ts(9)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

-- Close button: lebih gede di mobile supaya gampang ditap
local closeBtnSz = screenInfo.isMobile and 40 or px(32)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, closeBtnSz, 0, closeBtnSz)
closeBtn.Position = UDim2.new(1, -closeBtnSz, 0, (headerH - closeBtnSz) / 2)
closeBtn.BackgroundColor3 = COLORS.closeButton
closeBtn.Text = "✖"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = ts(13)
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 10
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, px(8))

local closeBtnStroke = Instance.new("UIStroke")
closeBtnStroke.Color = Color3.fromRGB(255, 255, 255)
closeBtnStroke.Thickness = 1
closeBtnStroke.Transparency = 0.5
closeBtnStroke.Parent = closeBtn

-- ── CONTENT AREA ─────────────────────────────────────────────────────────────
local actionAreaH = screenInfo.isMobile and 56 or px(50)
local contentY    = PAD + headerH + PAD
local contentH    = panelH - contentY - actionAreaH - PAD

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -PAD*2, 0, contentH)
content.Position = UDim2.new(0, PAD, 0, contentY)
content.BackgroundTransparency = 1
content.ScrollBarThickness = screenInfo.isMobile and 6 or 3
content.ScrollBarImageColor3 = COLORS.textMuted
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = mainPanel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, screenInfo.isMobile and 10 or px(8))
contentLayout.Parent = content

-- ============================================
-- SECTION CREATOR
-- ============================================
local SECTION_CORNER = px(10)
local SECTION_LABEL_H = screenInfo.isMobile and 22 or px(20)
local SECTION_LABEL_PAD_TOP = screenInfo.isMobile and 6 or px(4)

local function createSection(labelText, innerHeight, order)
	local totalH = SECTION_LABEL_H + SECTION_LABEL_PAD_TOP + innerHeight + (screenInfo.isMobile and 12 or px(12))
	local section = Instance.new("Frame")
	section.Size = UDim2.new(1, 0, 0, totalH)
	section.BackgroundColor3 = COLORS.surfaceElevated
	section.LayoutOrder = order
	section.Parent = content
	Instance.new("UICorner", section).CornerRadius = UDim.new(0, SECTION_CORNER)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -(PAD), 0, SECTION_LABEL_H)
	label.Position = UDim2.new(0, PAD/2, 0, SECTION_LABEL_PAD_TOP)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = COLORS.textSecondary
	label.Font = Enum.Font.GothamBold
	label.TextSize = ts(9)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = section

	return section
end

local innerPad = screenInfo.isMobile and 10 or px(8)
local innerOffsetY = SECTION_LABEL_H + SECTION_LABEL_PAD_TOP + 2

-- ── SECTION: SELECT PLAYER ────────────────────────────────────────────────────
local searchH     = btnH(28)
local playerListH = screenInfo.isMobile and 120 or px(75)  -- lebih tinggi di mobile
local playerInnerH = searchH + 6 + playerListH

local playerSection = createSection("SELECT PLAYER", playerInnerH, 1)

local playerSearch = Instance.new("TextBox")
playerSearch.Size = UDim2.new(1, -innerPad*2, 0, searchH)
playerSearch.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
playerSearch.BackgroundColor3 = COLORS.surface
playerSearch.Text = ""
playerSearch.PlaceholderText = "🔍 Search player..."
playerSearch.TextColor3 = COLORS.textPrimary
playerSearch.PlaceholderColor3 = COLORS.textMuted
playerSearch.Font = Enum.Font.Gotham
playerSearch.TextSize = ts(10)
playerSearch.ClearTextOnFocus = false
playerSearch.Parent = playerSection
Instance.new("UICorner", playerSearch).CornerRadius = UDim.new(0, px(6))
local _ps = Instance.new("UIPadding", playerSearch)
_ps.PaddingLeft = UDim.new(0, innerPad)
_ps.PaddingRight = UDim.new(0, 6)

local playerScroll = Instance.new("ScrollingFrame")
playerScroll.Size = UDim2.new(1, -innerPad*2, 0, playerListH)
playerScroll.Position = UDim2.new(0, innerPad, 0, innerOffsetY + searchH + 6)
playerScroll.BackgroundColor3 = COLORS.surface
playerScroll.ScrollBarThickness = screenInfo.isMobile and 5 or 2
playerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerScroll.ScrollingDirection = Enum.ScrollingDirection.Y
playerScroll.Parent = playerSection
Instance.new("UICorner", playerScroll).CornerRadius = UDim.new(0, px(6))

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0, screenInfo.isMobile and 3 or 2)
playerListLayout.Parent = playerScroll

-- ── SECTION: SELECT ROLE ──────────────────────────────────────────────────────
local roleRowH = btnH(30)
local roleSection = createSection("SELECT ROLE", roleRowH, 2)

local roleScroll = Instance.new("ScrollingFrame")
roleScroll.Size = UDim2.new(1, -innerPad*2, 0, roleRowH)
roleScroll.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
roleScroll.BackgroundTransparency = 1
roleScroll.ScrollBarThickness = screenInfo.isMobile and 5 or 3
roleScroll.ScrollBarImageColor3 = COLORS.textMuted
roleScroll.ScrollingDirection = Enum.ScrollingDirection.X
roleScroll.ScrollingEnabled = true
roleScroll.Parent = roleSection
enableHorizontalScroll(roleScroll)

local roleListLayout = Instance.new("UIListLayout")
roleListLayout.FillDirection = Enum.FillDirection.Horizontal
roleListLayout.Padding = UDim.new(0, px(6))
roleListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
roleListLayout.Parent = roleScroll

-- ── SECTION: SELECT DURATION ──────────────────────────────────────────────────
local durRowH = btnH(28)
local durationSection = createSection("SELECT DURATION", durRowH, 3)

local durationScroll = Instance.new("ScrollingFrame")
durationScroll.Size = UDim2.new(1, -innerPad*2, 0, durRowH)
durationScroll.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
durationScroll.BackgroundTransparency = 1
durationScroll.ScrollBarThickness = screenInfo.isMobile and 5 or 3
durationScroll.ScrollBarImageColor3 = COLORS.textMuted
durationScroll.ScrollingDirection = Enum.ScrollingDirection.X
durationScroll.ScrollingEnabled = true
durationScroll.Parent = durationSection
enableHorizontalScroll(durationScroll)

local durationListLayout = Instance.new("UIListLayout")
durationListLayout.FillDirection = Enum.FillDirection.Horizontal
durationListLayout.Padding = UDim.new(0, px(6))
durationListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
durationListLayout.Parent = durationScroll

-- ── SECTION: CUSTOM TITLE ─────────────────────────────────────────────────────
local customInputH = btnH(30)
local customSection = createSection("CUSTOM TITLE (Optional)", customInputH, 4)

local customInput = Instance.new("TextBox")
customInput.Size = UDim2.new(1, -innerPad*2, 0, customInputH)
customInput.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
customInput.BackgroundColor3 = COLORS.surface
customInput.Text = ""
customInput.PlaceholderText = "Enter custom title..."
customInput.TextColor3 = COLORS.textPrimary
customInput.PlaceholderColor3 = COLORS.textMuted
customInput.Font = Enum.Font.Gotham
customInput.TextSize = ts(10)
customInput.Parent = customSection
Instance.new("UICorner", customInput).CornerRadius = UDim.new(0, px(6))
local _ci = Instance.new("UIPadding", customInput)
_ci.PaddingLeft = UDim.new(0, innerPad)

-- ── SECTION: GRADIENT COLOR ───────────────────────────────────────────────────
-- Mobile: swatch lebih gede supaya mudah ditap
local swatchSz = screenInfo.isMobile and 36 or px(26)
local colorSection = createSection("GRADIENT COLOR", swatchSz, 5)

local colorScroll = Instance.new("ScrollingFrame")
colorScroll.Size = UDim2.new(1, -innerPad*2, 0, swatchSz)
colorScroll.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
colorScroll.BackgroundTransparency = 1
colorScroll.ScrollBarThickness = screenInfo.isMobile and 5 or 3
colorScroll.ScrollBarImageColor3 = COLORS.textMuted
colorScroll.ScrollingDirection = Enum.ScrollingDirection.X
colorScroll.ScrollingEnabled = true
colorScroll.Parent = colorSection
enableHorizontalScroll(colorScroll)

local colorListLayout = Instance.new("UIListLayout")
colorListLayout.FillDirection = Enum.FillDirection.Horizontal
colorListLayout.Padding = UDim.new(0, screenInfo.isMobile and 6 or px(4))
colorListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
colorListLayout.Parent = colorScroll

-- ── SECTION: TEXT COLOR ───────────────────────────────────────────────────────
local textColorSection = createSection("TEXT COLOR", swatchSz, 6)

local textColorScroll = Instance.new("ScrollingFrame")
textColorScroll.Size = UDim2.new(1, -innerPad*2, 0, swatchSz)
textColorScroll.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
textColorScroll.BackgroundTransparency = 1
textColorScroll.ScrollBarThickness = screenInfo.isMobile and 5 or 3
textColorScroll.ScrollBarImageColor3 = COLORS.textMuted
textColorScroll.ScrollingDirection = Enum.ScrollingDirection.X
textColorScroll.ScrollingEnabled = true
textColorScroll.Parent = textColorSection
enableHorizontalScroll(textColorScroll)

local textColorListLayout = Instance.new("UIListLayout")
textColorListLayout.FillDirection = Enum.FillDirection.Horizontal
textColorListLayout.Padding = UDim.new(0, screenInfo.isMobile and 6 or px(4))
textColorListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
textColorListLayout.Parent = textColorScroll

-- ── SECTION: ICONS ───────────────────────────────────────────────────────────
local iconBtnH = btnH(34)
local iconLabelH = screenInfo.isMobile and 18 or 16
local iconsSection = createSection("SELECT ICONS (Multiple)", iconBtnH + iconLabelH + 4, 7)

local iconScroll = Instance.new("ScrollingFrame")
iconScroll.Size = UDim2.new(1, -innerPad*2, 0, iconBtnH)
iconScroll.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
iconScroll.BackgroundTransparency = 1
iconScroll.ScrollBarThickness = screenInfo.isMobile and 5 or 3
iconScroll.ScrollBarImageColor3 = COLORS.textMuted
iconScroll.ScrollingDirection = Enum.ScrollingDirection.X
iconScroll.ScrollingEnabled = true
iconScroll.Parent = iconsSection
enableHorizontalScroll(iconScroll)

local iconListLayout = Instance.new("UIListLayout")
iconListLayout.FillDirection = Enum.FillDirection.Horizontal
iconListLayout.Padding = UDim.new(0, px(6))
iconListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
iconListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
iconListLayout.Parent = iconScroll

local selectedIconsLabel = Instance.new("TextLabel")
selectedIconsLabel.Size = UDim2.new(1, -innerPad*2, 0, iconLabelH)
selectedIconsLabel.Position = UDim2.new(0, innerPad, 0, innerOffsetY + iconBtnH + 4)
selectedIconsLabel.BackgroundTransparency = 1
selectedIconsLabel.Text = "Selected: None"
selectedIconsLabel.TextColor3 = COLORS.textMuted
selectedIconsLabel.Font = Enum.Font.Gotham
selectedIconsLabel.TextSize = ts(8)
selectedIconsLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedIconsLabel.Parent = iconsSection

-- ── SECTION: RGB TOGGLE ───────────────────────────────────────────────────────
local rgbBtnH  = btnH(30)
local rgbBtnW  = screenInfo.isMobile and 72 or px(60)
local rgbSection = createSection("RGB EFFECT", rgbBtnH, 8)

local rgbToggle = Instance.new("TextButton")
rgbToggle.Size = UDim2.new(0, rgbBtnW, 0, rgbBtnH)
rgbToggle.Position = UDim2.new(0, innerPad, 0, innerOffsetY)
rgbToggle.BackgroundColor3 = COLORS.surface
rgbToggle.Text = "OFF"
rgbToggle.TextColor3 = COLORS.textSecondary
rgbToggle.Font = Enum.Font.GothamBold
rgbToggle.TextSize = ts(10)
rgbToggle.AutoButtonColor = false
rgbToggle.Parent = rgbSection
Instance.new("UICorner", rgbToggle).CornerRadius = UDim.new(0, px(6))

-- ============================================
-- ACTION BUTTONS (bawah panel, sticky)
-- ============================================
local actionFrame = Instance.new("Frame")
actionFrame.Size = UDim2.new(1, -PAD*2, 0, actionAreaH - 8)
actionFrame.Position = UDim2.new(0, PAD, 1, -(actionAreaH))
actionFrame.BackgroundTransparency = 1
actionFrame.Parent = mainPanel

local assignBtn = Instance.new("TextButton")
assignBtn.Size = UDim2.new(0.48, 0, 1, 0)
assignBtn.BackgroundColor3 = COLORS.success
assignBtn.Text = "✓ ASSIGN"
assignBtn.TextColor3 = COLORS.textPrimary
assignBtn.Font = Enum.Font.GothamBold
assignBtn.TextSize = ts(11)
assignBtn.AutoButtonColor = false
assignBtn.Parent = actionFrame
Instance.new("UICorner", assignBtn).CornerRadius = UDim.new(0, px(10))

local removeBtn = Instance.new("TextButton")
removeBtn.Size = UDim2.new(0.48, 0, 1, 0)
removeBtn.Position = UDim2.new(0.52, 0, 0, 0)
removeBtn.BackgroundColor3 = COLORS.surfaceElevated
removeBtn.Text = "✕ REMOVE"
removeBtn.TextColor3 = COLORS.danger
removeBtn.Font = Enum.Font.GothamBold
removeBtn.TextSize = ts(11)
removeBtn.AutoButtonColor = false
removeBtn.Parent = actionFrame
Instance.new("UICorner", removeBtn).CornerRadius = UDim.new(0, px(10))

local removeStroke = Instance.new("UIStroke")
removeStroke.Color = COLORS.danger
removeStroke.Thickness = 1
removeStroke.Parent = removeBtn

-- ============================================
-- POPULATE FUNCTIONS
-- ============================================
local function clearChildren(frame, className)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA(className or "TextButton") then
			child:Destroy()
		end
	end
end

local function updateSelectedIconsDisplay()
	if #selectedIcons > 0 then
		selectedIconsLabel.Text = "Selected: " .. table.concat(selectedIcons, ", ")
		selectedIconsLabel.TextColor3 = COLORS.accent
	else
		selectedIconsLabel.Text = "Selected: None"
		selectedIconsLabel.TextColor3 = COLORS.textMuted
	end
end

local function populatePlayers(filter)
	clearChildren(playerScroll)
	local players = GetPlayersFunction:InvokeServer()
	filter = filter and string.lower(filter) or ""

	local rowH = btnH(screenInfo.isMobile and 38 or 26)

	for _, pData in ipairs(players) do
		local searchStr = string.lower(pData.Name .. pData.DisplayName)
		if filter == "" or string.find(searchStr, filter, 1, true) then
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -4, 0, rowH)
			btn.BackgroundColor3 = COLORS.surface
			btn.Text = "  " .. pData.DisplayName .. " @" .. pData.Name
			btn.TextColor3 = pData.HasOverride and COLORS.accent or COLORS.textPrimary
			btn.Font = Enum.Font.Gotham
			btn.TextSize = ts(10)
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.TextTruncate = Enum.TextTruncate.AtEnd
			btn.AutoButtonColor = false
			btn.Parent = playerScroll
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, px(4))

			local stroke = Instance.new("UIStroke")
			stroke.Color = COLORS.accent
			stroke.Thickness = 0
			stroke.Parent = btn

			btn.MouseButton1Click:Connect(function()
				-- Reset style tombol lain tanpa rebuild list (rebuild menghancurkan tombol ini sendiri)
				for _, c in ipairs(playerScroll:GetChildren()) do
					if c:IsA("TextButton") then
						c.BackgroundColor3 = COLORS.surface
						local s = c:FindFirstChildOfClass("UIStroke")
						if s then s.Thickness = 0 end
					end
				end
				btn.BackgroundColor3 = COLORS.accent
				stroke.Thickness = 2
				selectedPlayer = pData
			end)
		end
	end
end

local function populateRoles()
	clearChildren(roleScroll)
	local roles = GetRolesFunction:InvokeServer()
	if not roles or not next(roles) then
		warn("[NameTagManager] No roles received!")
		return
	end

	local sorted = {}
	for name, data in pairs(roles) do
		table.insert(sorted, {name = name, data = data})
	end
	table.sort(sorted, function(a, b)
		return (a.data.Priority or 99) < (b.data.Priority or 99)
	end)

	local totalWidth = 0
	local rH = btnH(screenInfo.isMobile and 38 or 28)

	for i, roleInfo in ipairs(sorted) do
		local gc = roleInfo.data.GradientColor or {R=128,G=128,B=128}
		local roleColor = Color3.fromRGB(gc.R or 128, gc.G or 128, gc.B or 128)
		local displayName = roleInfo.data.Name or roleInfo.name
		-- Mobile: tombol lebih lebar supaya teks tidak terpotong
		local charW = screenInfo.isMobile and 9 or px(7)
		local btnWidth = math.max(screenInfo.isMobile and 80 or px(65), #displayName * charW + (screenInfo.isMobile and 24 or px(16)))

		local btn = Instance.new("TextButton")
		btn.Name = roleInfo.name
		btn.Size = UDim2.new(0, btnWidth, 0, rH)
		btn.BackgroundColor3 = COLORS.surface
		btn.BorderSizePixel = 0
		btn.Text = displayName
		btn.TextColor3 = roleColor
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = ts(9)
		btn.LayoutOrder = i
		btn.AutoButtonColor = false
		btn.Parent = roleScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, px(6))

		local stroke = Instance.new("UIStroke")
		stroke.Color = roleColor
		stroke.Thickness = 0
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			for _, c in ipairs(roleScroll:GetChildren()) do
				if c:IsA("TextButton") then
					c.BackgroundColor3 = COLORS.surface
					local s = c:FindFirstChild("UIStroke")
					if s then s.Thickness = 0 end
				end
			end
			btn.BackgroundColor3 = COLORS.surfaceHover
			stroke.Thickness = 2
			selectedRole = roleInfo.data
			selectedRoleName = roleInfo.name
		end)

		totalWidth = totalWidth + btnWidth + px(6)
	end
	roleScroll.CanvasSize = UDim2.new(0, totalWidth + px(10), 0, 0)
end

local function populateDurations()
	clearChildren(durationScroll)
	local durations = GetDurationsFunction:InvokeServer()
	if not durations then return end

	local sorted = {}
	for name, data in pairs(durations) do
		table.insert(sorted, {name = name, data = data})
	end
	table.sort(sorted, function(a, b) return a.data.order < b.data.order end)

	local totalWidth = 0
	local dH = btnH(screenInfo.isMobile and 36 or 26)
	local dW = screenInfo.isMobile and 54 or px(40)

	for i, durInfo in ipairs(sorted) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, dW, 0, dH)
		btn.BackgroundColor3 = COLORS.surface
		btn.Text = durInfo.data.display or durInfo.name
		btn.TextColor3 = COLORS.textSecondary
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = ts(10)
		btn.LayoutOrder = i
		btn.AutoButtonColor = false
		btn.Parent = durationScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, px(6))

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.accent
		stroke.Thickness = 0
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			for _, c in ipairs(durationScroll:GetChildren()) do
				if c:IsA("TextButton") then
					c.BackgroundColor3 = COLORS.surface
					c.TextColor3 = COLORS.textSecondary
					local s = c:FindFirstChild("UIStroke")
					if s then s.Thickness = 0 end
				end
			end
			btn.BackgroundColor3 = COLORS.accent
			btn.TextColor3 = COLORS.textPrimary
			stroke.Thickness = 2
			selectedDuration = durInfo.name
		end)

		totalWidth = totalWidth + dW + px(6)
	end
	durationScroll.CanvasSize = UDim2.new(0, totalWidth + px(10), 0, 0)
end

local function populateColors()
	clearChildren(colorScroll)
	local totalWidth = 0

	for i, colorData in ipairs(PRESET_COLORS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, swatchSz, 0, swatchSz)
		btn.BackgroundColor3 = colorData.Color
		btn.Text = ""
		btn.LayoutOrder = i
		btn.AutoButtonColor = false
		btn.Parent = colorScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, px(6))

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.textPrimary
		stroke.Thickness = 0
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			for _, c in ipairs(colorScroll:GetChildren()) do
				if c:IsA("TextButton") then
					local s = c:FindFirstChild("UIStroke")
					if s then s.Thickness = 0 end
				end
			end
			stroke.Thickness = 3
			selectedGradientColor = colorData.Color
		end)

		totalWidth = totalWidth + swatchSz + (screenInfo.isMobile and 6 or px(4))
	end
	colorScroll.CanvasSize = UDim2.new(0, totalWidth + px(10), 0, 0)
end

local function populateTextColors()
	clearChildren(textColorScroll)
	local totalWidth = 0

	for i, colorData in ipairs(PRESET_COLORS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, swatchSz, 0, swatchSz)
		btn.BackgroundColor3 = colorData.Color
		btn.Text = ""
		btn.LayoutOrder = i
		btn.AutoButtonColor = false
		btn.Parent = textColorScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, px(6))

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.textPrimary
		stroke.Thickness = 0
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			for _, c in ipairs(textColorScroll:GetChildren()) do
				if c:IsA("TextButton") then
					local s = c:FindFirstChild("UIStroke")
					if s then s.Thickness = 0 end
				end
			end
			stroke.Thickness = 3
			selectedTextColor = colorData.Color
		end)

		totalWidth = totalWidth + swatchSz + (screenInfo.isMobile and 6 or px(4))
	end
	textColorScroll.CanvasSize = UDim2.new(0, totalWidth + px(10), 0, 0)
end

local function populateIcons()
	clearChildren(iconScroll)
	local icons = GetIconsFunction:InvokeServer()
	if not icons then
		icons = {"Founder", "CoFounder", "Member", "Player", "Verified"}
	end

	local filteredIcons = {}
	for _, icon in ipairs(icons) do
		if icon ~= "Mobile" and icon ~= "PC" and icon ~= "Console" then
			table.insert(filteredIcons, icon)
		end
	end

	local totalWidth = 0
	local iH = btnH(screenInfo.isMobile and 38 or 32)
	local charW = screenInfo.isMobile and 9 or px(6)

	for i, iconName in ipairs(filteredIcons) do
		local displayText = (ICON_DISPLAY[iconName] or "◉") .. " " .. iconName
		local btnWidth = math.max(screenInfo.isMobile and 86 or px(70), #displayText * charW + (screenInfo.isMobile and 24 or px(16)))

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, btnWidth, 0, iH)
		btn.BackgroundColor3 = COLORS.surface
		btn.Text = displayText
		btn.TextColor3 = COLORS.textSecondary
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = ts(9)
		btn.LayoutOrder = i
		btn.AutoButtonColor = false
		btn.Parent = iconScroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, px(6))

		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.warning
		stroke.Thickness = 0
		stroke.Parent = btn

		if table.find(selectedIcons, iconName) then
			btn.BackgroundColor3 = COLORS.warning
			btn.TextColor3 = COLORS.textPrimary
			stroke.Thickness = 2
		end

		btn.MouseButton1Click:Connect(function()
			local index = table.find(selectedIcons, iconName)
			if index then
				table.remove(selectedIcons, index)
				btn.BackgroundColor3 = COLORS.surface
				btn.TextColor3 = COLORS.textSecondary
				stroke.Thickness = 0
			else
				table.insert(selectedIcons, iconName)
				btn.BackgroundColor3 = COLORS.warning
				btn.TextColor3 = COLORS.textPrimary
				stroke.Thickness = 2
			end
			updateSelectedIconsDisplay()
		end)

		totalWidth = totalWidth + btnWidth + px(6)
	end
	iconScroll.CanvasSize = UDim2.new(0, totalWidth + px(10), 0, 0)
end

-- ============================================
-- TOPBAR ICON
-- ============================================
local nametagIcon = Icon.new()
	:setLabel("🏷️")

local function refreshPanel()
	panelW, panelH = getPanelSize()
	mainPanel.Size = UDim2.new(0, panelW, 0, panelH)
	mainPanel.Position = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
end

nametagIcon.selected:Connect(function()
	panelW, panelH = getPanelSize()

	mainPanel.Size = UDim2.new(0, panelW, 0, 0)
	mainPanel.Position = UDim2.new(0.5, -panelW/2, 0.5, 0)
	mainPanel.Visible = true

	createTween(mainPanel, {
		Size = UDim2.new(0, panelW, 0, panelH),
		Position = UDim2.new(0.5, -panelW/2, 0.5, -panelH/2)
	}, 0.3):Play()

	populatePlayers()
	populateRoles()
	populateDurations()
	populateColors()
	populateTextColors()
	populateIcons()
end)

nametagIcon.deselected:Connect(function()
	createTween(mainPanel, {
		Size = UDim2.new(0, panelW, 0, 0),
		Position = UDim2.new(0.5, -panelW/2, 0.5, 0)
	}, 0.2):Play()
	task.delay(0.2, function() mainPanel.Visible = false end)

	selectedIcons = {}
	updateSelectedIconsDisplay()
end)

-- ============================================
-- EVENTS
-- ============================================
closeBtn.MouseButton1Click:Connect(function()
	nametagIcon:deselect()
end)

local searchDebounce = 0
playerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	searchDebounce += 1
	local myToken = searchDebounce
	task.delay(0.25, function()
		if myToken == searchDebounce then
			populatePlayers(playerSearch.Text)
		end
	end)
end)

customInput:GetPropertyChangedSignal("Text"):Connect(function()
	customTitleText = customInput.Text
end)

rgbToggle.MouseButton1Click:Connect(function()
	isRGBEnabled = not isRGBEnabled
	rgbToggle.Text = isRGBEnabled and "ON" or "OFF"
	rgbToggle.BackgroundColor3 = isRGBEnabled and COLORS.success or COLORS.surface
	rgbToggle.TextColor3 = isRGBEnabled and COLORS.textPrimary or COLORS.textSecondary
end)

assignBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	if not selectedRoleName then return end
	if not selectedDuration then return end

	local options = {
		customTitle    = customTitleText ~= "" and customTitleText or nil,
		gradientColor  = selectedGradientColor,
		textColor      = selectedTextColor,
		icons          = #selectedIcons > 0 and selectedIcons or nil,
		isRGB          = isRGBEnabled,
	}

	AssignRoleEvent:FireServer(selectedPlayer.UserId, selectedRoleName, selectedDuration, options)

	assignBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
	task.wait(0.3)
	assignBtn.BackgroundColor3 = COLORS.success

	customInput.Text = ""
	populatePlayers()
end)

removeBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end

	RemoveRoleEvent:FireServer(selectedPlayer.UserId)

	removeBtn.BackgroundColor3 = COLORS.danger
	task.wait(0.3)
	removeBtn.BackgroundColor3 = COLORS.surfaceElevated

	populatePlayers()
end)

-- Hover effects (hanya PC)
if not screenInfo.isMobile then
	closeBtn.MouseEnter:Connect(function()
		createTween(closeBtn, {
			BackgroundColor3 = Color3.fromRGB(255, 60, 60),
			Size = UDim2.new(0, px(34), 0, px(34))
		}, 0.15):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		createTween(closeBtn, {
			BackgroundColor3 = COLORS.closeButton,
			Size = UDim2.new(0, px(32), 0, px(32))
		}, 0.15):Play()
	end)
end

-- Re-layout saat ukuran layar berubah (rotate, dll)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	updateScreenInfo()
	if mainPanel.Visible then
		refreshPanel()
	end
end)