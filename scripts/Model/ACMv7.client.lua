--!strict
--[[
  AvatarContextMenu (ACMv8.2) - FULL UNCUT VERSION
  - Custom Minimalist Edition
  - Layout: 330x425 (Fixed Height Buttons)
  - Features: Like System, Native Friends, Account Age/Followers, Clone Avatar
  - Pagination: Circular Solid Style
]]

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

----------------------------------------------------------------
-- Events & Remotes
----------------------------------------------------------------
local Events = ReplicatedStorage:WaitForChild("EventsACMS")
local OpenTipJarEvent = Events:WaitForChild("OpenTipJar")
local BackToACMEvent = Events:WaitForChild("BackToACM")
local RequestSync = Events:WaitForChild("RequestSync")
local CarryRemote = ReplicatedStorage:WaitForChild("CarryRemote")
-- ✅ Definisi Remote Clone (Pastikan RemoteEvent ini ada di ReplicatedStorage)
local CloneAvatarRemote = ReplicatedStorage:WaitForChild("CloneAvatarRemote")

-- Module Blueprint Carry
local CarryBlueprints = require(ReplicatedStorage:WaitForChild("CarryBlueprints"))

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local IS_MOBILE = UserInputService.TouchEnabled

-- Mobile Touch Filter
local TOUCH_MAX_MOVE = 18        -- px, toleransi geser
local TOUCH_MAX_TIME = 0.25      -- detik, tap cepat


local MAX_ACTIVATION_DISTANCE = 40
local MAX_CARRY_DISTANCE = 20
local REQUEST_TIMEOUT = 8
local ICON_LIST_ID = "rbxassetid://15016878198"

-- Helper Camera
local function getCamera(): Camera?
	return Workspace.CurrentCamera
end

-- ✅ SKALA RESPONSIF DINAMIS
local function getDynamicScale(): number
	if not IS_MOBILE then
		return 1.0 
	end

	local cam = getCamera()
	local viewportX = cam and cam.ViewportSize.X or 1280
	local viewportY = cam and cam.ViewportSize.Y or 900

	local MOBILE_REDUCTION_FACTOR = 0.75

	local baseMobileScale: number
	if viewportY > 1800 then 
		baseMobileScale = 0.75 * MOBILE_REDUCTION_FACTOR
	elseif viewportY > 1200 then 
		baseMobileScale = 0.80 * MOBILE_REDUCTION_FACTOR
	elseif viewportY > 900 then 
		baseMobileScale = 0.85 * MOBILE_REDUCTION_FACTOR
	else 
		baseMobileScale = 0.90 * MOBILE_REDUCTION_FACTOR
	end

	local shortestSide = math.min(viewportX, viewportY)

	if shortestSide > 700 then
		return baseMobileScale * 1.20
	else
		return baseMobileScale * 1.12
	end
end

local BASE_SCALE = getDynamicScale()

-- Colors
local COLOR_BG = Color3.fromHex("#0A0A0A")
local COLOR_GOLD = Color3.fromHex("#E9B44C")
local COLOR_TEXT = Color3.fromHex("#D6D6D6")
local COLOR_HIGHLIGHT = Color3.fromRGB(255, 230, 120)

-- Animation Settings
local TWEEN_INFO_SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local TWEEN_INFO_CAMERA = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local TWEEN_INFO_PANEL_LIST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Fonts Helper
local function getSafeFont(style: string): Enum.Font
	if style == "Bold" then
		return Enum.Font.GothamBold
	elseif style == "Italic" then
		return Enum.Font.GothamBold
	else
		return Enum.Font.Gotham
	end
end

local FONT_BOLD = getSafeFont("Bold")
local FONT_REGULAR = getSafeFont("Regular")
local FONT_ITALIC = getSafeFont("Italic")

----------------------------------------------------------------
-- Shared State
----------------------------------------------------------------
local State = {
	carriedIds = {} :: {[number]: boolean},
	carrierId = nil :: number?,
	isPassenger = false,
	currentTarget = nil :: Player?,
	panelOpen = false,
	defaultFOV = 70,
	currentCarryMode = nil :: string?, 
	isRemoteView = false,
}

-- Cache Data untuk Stats (Supaya tidak loading terus)
local DataCache = {}

_G.ACM_STATE = _G.ACM_STATE or {
	carriedList = {} :: {{id: number, name: string}},
	carrierId = nil :: number?,
}

local pendingPrompts: {[number]: {fromId: number, fromName: string, animType: string}} = {}


----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function getHumanoid(): Humanoid?
	local char = Player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function findCharacterModel(inst: Instance?): Model?
	local cur = inst
	while cur do
		local mdl = cur:FindFirstAncestorOfClass("Model")
		if not mdl then return nil end
		if mdl:FindFirstChildOfClass("Humanoid") then return mdl end
		cur = mdl.Parent
	end
	return nil
end

-- RAYCAST SUPER AKURAT – Mendeteksi seluruh badan + aksesori
local function raycastForPlayer(maxDist: number, screenPoint: Vector2?): Player?
	local cam = getCamera()
	if not cam then return nil end

	-- Posisi klik (mouse/touch)
	local pos = screenPoint or UserInputService:GetMouseLocation()
	local unit = cam:ViewportPointToRay(pos.X, pos.Y)

	-- Param raycast
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Player.Character }   -- ignored: karakter sendiri

	-- Jalankan raycast
	local result = Workspace:Raycast(unit.Origin, unit.Direction * maxDist, params)

	-- Jika kena sesuatu
	if result and result.Instance then
		-- Coba ambil karakter dari part “berapapun”
		local char = result.Instance:FindFirstAncestorWhichIsA("Model")
		if char and Players:GetPlayerFromCharacter(char) then
			return Players:GetPlayerFromCharacter(char)
		end
	end

	-- 🔥 CADANGAN: cek bounding box jika raycast tidak kena apa-apa
	local ignore = { Player.Character }
	local allPlayers = Players:GetPlayers()

	for _, p in ipairs(allPlayers) do
		if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = p.Character.HumanoidRootPart
			local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)

			-- Jika titik tengah badan kira-kira dekat lokasi klik → artinya dia pemain yang diklik
			if onScreen and (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(pos.X, pos.Y)).Magnitude < 60 then
				return p
			end
		end
	end

	return nil
end


local function pruneCarriedIds()
	local changed = false
	for uid in pairs(State.carriedIds) do
		if Players:GetPlayerByUserId(uid) == nil then
			State.carriedIds[uid] = nil
			changed = true
		end
	end
	if changed and _G.ACM_STATE then
		local n = {}
		for _, it in ipairs(_G.ACM_STATE.carriedList or {}) do
			if Players:GetPlayerByUserId(it.id) then
				table.insert(n, it)
			end
		end
		_G.ACM_STATE.carriedList = n
	end
end

local function resetPassengerState()
	State.carrierId = nil
	State.isPassenger = false
	if _G.ACM_STATE then
		_G.ACM_STATE.carrierId = nil
	end
end

local function safeIsFriendsWith(p: Player?, otherUserId: number): boolean
	if not p then return false end
	local ok, res = pcall(function()
		return p:IsFriendsWith(otherUserId)
	end)
	return ok and res or false
end

local function playClickSound()
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.3
		sound.Parent = SoundService
		sound:Play()
		task.delay(1, function()
			sound:Destroy()
		end)
	end)
end


----------------------------------------------------------------
-- Highlight Effect
----------------------------------------------------------------
local activeHighlight: Highlight? = nil

local function clearHighlight()
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function highlightTarget(target: Player)
	clearHighlight()

	local char = target.Character
	if not char then return end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.8 
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = char

	activeHighlight = highlight
end


----------------------------------------------------------------
-- Camera Zoom Effect
----------------------------------------------------------------
local isZoomed = false

local function zoomCameraIn()
	local cam = getCamera()
	if not cam or isZoomed then return end 
	isZoomed = true

	State.defaultFOV = cam.FieldOfView
	TweenService:Create(cam, TWEEN_INFO_CAMERA, {
		FieldOfView = math.clamp(State.defaultFOV - 10, 40, 70)
	}):Play()
end

local function zoomCameraOut()
	local cam = getCamera()
	if not cam then return end
	if not isZoomed then return end 
	isZoomed = false

	TweenService:Create(cam, TWEEN_INFO_CAMERA, {
		FieldOfView = State.defaultFOV
	}):Play()
end


----------------------------------------------------------------
-- UI Creation
----------------------------------------------------------------
local mainGui: ScreenGui? = nil
local mainPanel: Frame? = nil
local carriedBanner: Frame? = nil
local selectorPanel: Frame? = nil

local function destroyUI()
	if mainGui and mainGui.Parent then
		mainGui:Destroy()
	end
	mainGui = nil
	mainPanel = nil
	carriedBanner = nil
	selectorPanel = nil

	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

----------------------------------------------------------------
-- Anti-Spam Protection
----------------------------------------------------------------
local lastRequestTime = 0
local REQUEST_COOLDOWN = 1.0

local function canSendRequest(): boolean
	local now = os.clock()
	if now - lastRequestTime < REQUEST_COOLDOWN then
		return false
	end
	lastRequestTime = now
	return true
end

local function safeFireCarryRemote(action: string, data: any)
	if action == "Request" or action == "Response" then
		if not canSendRequest() then
			warn("[ACM] Request cooldown active, please wait...")
			return
		end
	end
	CarryRemote:FireServer(action, data)
end

----------------------------------------------------------------
-- 🔔 NOTIFIKASI
----------------------------------------------------------------
local function showNotification(text: string)
	local notifGui = PlayerGui:FindFirstChild("ACM_NotificationGUI")
	if not notifGui then
		notifGui = Instance.new("ScreenGui")
		notifGui.Name = "ACM_NotificationGUI"
		notifGui.ResetOnSpawn = false
		notifGui.IgnoreGuiInset = true
		notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		notifGui.DisplayOrder = 999
		notifGui.Parent = PlayerGui
	end

	local notif = Instance.new("TextLabel")
	notif.Size = UDim2.new(0, 280 * BASE_SCALE, 0, 44 * BASE_SCALE)
	notif.AnchorPoint = Vector2.new(0.5, 0.5)
	notif.Position = UDim2.new(0.5, 0, 0.82, 0)
	notif.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notif.BackgroundTransparency = 0.15
	notif.TextColor3 = Color3.fromRGB(230, 230, 230)
	notif.Font = Enum.Font.GothamMedium
	notif.TextSize = 16 * BASE_SCALE
	notif.Text = text
	notif.TextTransparency = 1
	notif.ZIndex = 20
	notif.Parent = notifGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
	corner.Parent = notif

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 80, 80)
	stroke.Thickness = 1 * BASE_SCALE
	stroke.Transparency = 0.25
	stroke.Parent = notif

	TweenService:Create(notif, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
	task.delay(1.5, function()
		TweenService:Create(notif, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.5, function()
			if notif and notif.Parent then notif:Destroy() end
		end)
	end)
end

----------------------------------------------------------------
-- Build Selector Panel
----------------------------------------------------------------
local function buildSelectorPanel(target: Player): Frame
	local panel = Instance.new("Frame")
	panel.Name = "ACM_SelectorPanel"
	panel.Size = UDim2.new(0, 300 * BASE_SCALE, 0, 340 * BASE_SCALE)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0) 
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	panel.BackgroundTransparency = 0.4
	panel.BorderSizePixel = 0
	panel.ZIndex = 20 
	panel.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16 * BASE_SCALE)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 60)
	stroke.Transparency = 0.45
	stroke.Thickness = 1 * BASE_SCALE
	stroke.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28 * BASE_SCALE, 0, 28 * BASE_SCALE)
	closeBtn.Position = UDim2.new(1, -34 * BASE_SCALE, 0, 8 * BASE_SCALE)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 24 * BASE_SCALE
	closeBtn.ZIndex = 21
	closeBtn.Parent = panel

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -60 * BASE_SCALE, 0, 24 * BASE_SCALE)
	titleLabel.Position = UDim2.new(0, 30 * BASE_SCALE, 0, 12 * BASE_SCALE)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Select Carry Style"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = 18 * BASE_SCALE
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel

	local subTitleLabel = Instance.new("TextLabel")
	subTitleLabel.Size = UDim2.new(1, -60 * BASE_SCALE, 0, 18 * BASE_SCALE)
	subTitleLabel.Position = UDim2.new(0, 30 * BASE_SCALE, 0, 36 * BASE_SCALE)
	subTitleLabel.BackgroundTransparency = 1
	subTitleLabel.Text = "Target: " .. target.DisplayName
	subTitleLabel.Font = Enum.Font.Gotham
	subTitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	subTitleLabel.TextSize = 14 * BASE_SCALE
	subTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subTitleLabel.Parent = panel

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -40 * BASE_SCALE, 0, 1 * BASE_SCALE)
	divider.Position = UDim2.new(0, 20 * BASE_SCALE, 0, 64 * BASE_SCALE)
	divider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	divider.BorderSizePixel = 0
	divider.Parent = panel

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Size = UDim2.new(1, -20 * BASE_SCALE, 1, -80 * BASE_SCALE)
	scrollFrame.Position = UDim2.new(0, 10 * BASE_SCALE, 0, 70 * BASE_SCALE)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8 * BASE_SCALE)
	layout.Parent = scrollFrame

	local carriedList = _G.ACM_STATE.carriedList or {}
	local isCarrying = #carriedList > 0 or State.isPassenger

	local function makeListButton(animName: string, blueprint: table)
		local btn = Instance.new("TextButton")
		btn.Name = animName
		btn.Size = UDim2.new(1, 0, 0, 44 * BASE_SCALE)
		btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = scrollFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
		corner.Parent = btn

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -50 * BASE_SCALE, 1, 0)
		lbl.Position = UDim2.new(0, 15 * BASE_SCALE, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = animName
		lbl.Font = FONT_BOLD
		lbl.TextSize = 16 * BASE_SCALE
		lbl.TextColor3 = COLOR_TEXT
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = btn

		local modeLbl = Instance.new("TextLabel")
		modeLbl.Size = UDim2.new(0, 80 * BASE_SCALE, 1, 0)
		modeLbl.Position = UDim2.new(1, -95 * BASE_SCALE, 0, 0)
		modeLbl.BackgroundTransparency = 1
		modeLbl.Text = blueprint.Mode == "Multi" and "(Multi)" or "(Single)"
		modeLbl.Font = FONT_REGULAR
		modeLbl.TextSize = 13 * BASE_SCALE
		modeLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
		modeLbl.TextXAlignment = Enum.TextXAlignment.Right
		modeLbl.Parent = btn

		local isDisabled = false
		local carryCount = #carriedList

		if State.isPassenger then
			isDisabled = true
		elseif carryCount > 0 then
			local myCurrentMode = State.currentCarryMode 
			local btnMode = blueprint.Mode 

			if myCurrentMode == "Multi" and btnMode == "Multi" then
				isDisabled = false
			else
				isDisabled = true
			end
		end

		-- Logika Styling & Klik
		if isDisabled then
			-- Jika tombol mati (disabled), ubah warna jadi gelap
			btn.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
			lbl.TextColor3 = Color3.fromRGB(80, 80, 80)
			modeLbl.TextColor3 = Color3.fromRGB(60, 60, 60)
		else
			-- Jika tombol hidup (enabled), aktifkan fungsi klik
			btn.MouseButton1Click:Connect(function()
				playClickSound()

				-- Mengirim Remote ke Server
				safeFireCarryRemote("Request", {
					targetId = target.UserId,
					animType = animName
				})

				-- Notifikasi Native
				pcall(function()
					StarterGui:SetCore("SendNotification", {
						Title = "Carry Request",
						Text = "Request sent to " .. target.DisplayName,
						Duration = 3,
						Icon = "rbxassetid://122950291665538"
					})
				end)

				destroyUI()
				zoomCameraOut()
				State.panelOpen = false
			end)
		end

		return btn
	end

	local sortedNames = {}
	for name, _ in pairs(CarryBlueprints) do
		table.insert(sortedNames, name)
	end
	table.sort(sortedNames)

	for _, animName in ipairs(sortedNames) do
		makeListButton(animName, CarryBlueprints[animName])
	end

	return panel
end

local function showSelectorPanel(target: Player)
	if not mainPanel then return end 
	mainPanel.Visible = false

	local panel = buildSelectorPanel(target)
	panel.Parent = mainGui 
	selectorPanel = panel

	panel.BackgroundTransparency = 1
	TweenService:Create(panel, TWEEN_INFO_FADE, {BackgroundTransparency = 0.4}):Play()

	local closeBtn = panel:FindFirstChild("TextButton")
	if closeBtn then
		closeBtn.MouseButton1Click:Connect(function()
			playClickSound()
			if selectorPanel then
				selectorPanel:Destroy()
				selectorPanel = nil
			end
			if mainPanel then
				mainPanel.Visible = true
			end
		end)
	end
end

----------------------------------------------------------------
-- buildMainPanel (ACMv8.2 - Full Features)
----------------------------------------------------------------
local function buildMainPanel(target: Player, isPrompt: boolean, promptName: string?): Frame
	local panel = Instance.new("Frame")
	panel.Name = "ACM_Panel"
	panel.Size = UDim2.new(0, 330 * BASE_SCALE, 0, 425 * BASE_SCALE)
	panel.Position = UDim2.new(0.5, 0, 1.2, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	panel.BackgroundTransparency = 0.4
	panel.BorderSizePixel = 0
	panel.ZIndex = 10

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16 * BASE_SCALE)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255) 
	stroke.Transparency = 0.75 
	stroke.Thickness = 1.5 * BASE_SCALE
	stroke.Parent = panel

	-- Tombol Close
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28 * BASE_SCALE, 0, 28 * BASE_SCALE)
	closeBtn.Position = UDim2.new(1, -34 * BASE_SCALE, 0, 8 * BASE_SCALE)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 24 * BASE_SCALE
	closeBtn.ZIndex = 11
	closeBtn.Parent = panel
	closeBtn.MouseButton1Click:Connect(function()
		playClickSound()
		destroyUI()
		zoomCameraOut()
		State.panelOpen = false
	end)

	-- === BAGIAN ATAS (Avatar, Nama, Status) ===
	local avatar = Instance.new("ImageLabel")
	avatar.Size = UDim2.new(0, 82 * BASE_SCALE, 0, 82 * BASE_SCALE)
	avatar.Position = UDim2.new(0, 15 * BASE_SCALE, 0, 24 * BASE_SCALE)
	avatar.BackgroundTransparency = 1
	avatar.Image = ("rbxthumb://type=Avatar&id=%d&w=420&h=420"):format(target.UserId)
	avatar.Parent = panel

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 12 * BASE_SCALE)
	avatarCorner.Parent = avatar

	local textWidth = (330 - 110 - 55) * BASE_SCALE -- Dikurangi biar ga nabrak tombol Love

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, textWidth, 0, 24 * BASE_SCALE)
	nameLabel.Position = UDim2.new(0, 110 * BASE_SCALE, 0, 30 * BASE_SCALE)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = target.DisplayName
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 18 * BASE_SCALE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = panel

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.Size = UDim2.new(0, textWidth, 0, 18 * BASE_SCALE)
	usernameLabel.Position = UDim2.new(0, 110 * BASE_SCALE, 0, 54 * BASE_SCALE)
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.Text = "@" .. target.Name
	usernameLabel.Font = Enum.Font.Gotham
	usernameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	usernameLabel.TextSize = 14 * BASE_SCALE
	usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
	usernameLabel.Parent = panel

	local statusFrame = Instance.new("Frame")
	statusFrame.Size = UDim2.new(0, textWidth, 0, 20 * BASE_SCALE)
	statusFrame.Position = UDim2.new(0, 110 * BASE_SCALE, 0, 78 * BASE_SCALE)
	statusFrame.BackgroundTransparency = 1
	statusFrame.Parent = panel

	local statusDot = Instance.new("Frame")
	statusDot.Size = UDim2.new(0, 10 * BASE_SCALE, 0, 10 * BASE_SCALE)
	statusDot.Position = UDim2.new(0, 0, 0.5, 0)
	statusDot.AnchorPoint = Vector2.new(0, 0.5)
	statusDot.BackgroundColor3 = Color3.fromRGB(80, 255, 80)
	statusDot.Parent = statusFrame
	local statusDotCorner = Instance.new("UICorner")
	statusDotCorner.CornerRadius = UDim.new(1, 0)
	statusDotCorner.Parent = statusDot

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -15 * BASE_SCALE, 1, 0)
	statusLabel.Position = UDim2.new(0, 15 * BASE_SCALE, 0, -2 * BASE_SCALE)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Online"
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statusLabel.TextSize = 13 * BASE_SCALE
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = statusFrame

	-- ✅ TOMBOL LIKE (POSISI TENGAH KANAN)
	local ICON_UNLIKE = "rbxassetid://140425086081283"
	local ICON_LIKE = "rbxassetid://110760134428621"

	local likeBtn = Instance.new("ImageButton")
	likeBtn.Name = "LikeButton"
	likeBtn.Size = UDim2.new(0, 32 * BASE_SCALE, 0, 32 * BASE_SCALE)
	likeBtn.AnchorPoint = Vector2.new(1, 0.5)
	likeBtn.Position = UDim2.new(1, -25 * BASE_SCALE, 0, 65 * BASE_SCALE)
	likeBtn.BackgroundTransparency = 1
	likeBtn.Image = ICON_UNLIKE -- Default
	likeBtn.ImageColor3 = Color3.fromRGB(200, 200, 200) 
	likeBtn.ZIndex = 12
	likeBtn.Parent = panel

	-- === BAGIAN TENGAH (Statistik) ===
	local statsFrame = Instance.new("Frame")
	statsFrame.Size = UDim2.new(1, -30 * BASE_SCALE, 0, 60 * BASE_SCALE)
	statsFrame.Position = UDim2.new(0.5, 0, 0, 120 * BASE_SCALE)
	statsFrame.AnchorPoint = Vector2.new(0.5, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	statsFrame.Parent = panel

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
	statsCorner.Parent = statsFrame

	local statsStroke = Instance.new("UIStroke")
	statsStroke.Color = Color3.fromRGB(255, 255, 255) 
	statsStroke.Transparency = 0.8
	statsStroke.Thickness = 1.5 * BASE_SCALE
	statsStroke.Parent = statsFrame

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statsLayout.Padding = UDim.new(0, 5 * BASE_SCALE)
	statsLayout.Parent = statsFrame

	local function makeStat(value: string, label: string, parent: Frame)
		local container = Instance.new("Frame")
		container.Size = UDim2.new(0.33, 0, 1, -10 * BASE_SCALE)
		container.BackgroundTransparency = 1
		container.Parent = parent

		local valLabel = Instance.new("TextLabel")
		valLabel.Size = UDim2.new(1, 0, 0, 24 * BASE_SCALE)
		valLabel.Position = UDim2.new(0.5, 0, 0.5, -10 * BASE_SCALE)
		valLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		valLabel.BackgroundTransparency = 1
		valLabel.Text = value
		valLabel.Font = FONT_BOLD
		valLabel.TextColor3 = Color3.new(1, 1, 1)
		valLabel.TextSize = 18 * BASE_SCALE
		valLabel.Parent = container

		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, 0, 0, 18 * BASE_SCALE)
		subLabel.Position = UDim2.new(0.5, 0, 0.5, 12 * BASE_SCALE)
		subLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = label
		subLabel.Font = FONT_REGULAR
		subLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		subLabel.TextSize = 11 * BASE_SCALE
		subLabel.Parent = container

		return valLabel
	end

	-- 1. FRIENDS (Native)
	local friendStat = makeStat("...", "FRIENDS", statsFrame)
	-- 2. FOLLOWERS (HTTP)
	local followStat = makeStat("...", "FOLLOWERS", statsFrame)
	-- 3. LIKES (Remote)
	local likeStat = makeStat("...", "LIKES", statsFrame)

	-- ✅ LOGIKA DATA (CACHE & FETCH)

	-- 1. Cek Cache dulu (Instant Load)
	local cachedData = DataCache[target.UserId]
	if cachedData then
		friendStat.Text = cachedData.friends
		followStat.Text = cachedData.followers
		likeStat.Text = cachedData.likes

		if cachedData.hasLiked then
			likeBtn.Image = ICON_LIKE
			likeBtn.ImageColor3 = Color3.fromRGB(255, 80, 80)
			likeBtn:SetAttribute("IsLiked", true)
		else
			likeBtn.Image = ICON_UNLIKE
			likeBtn.ImageColor3 = Color3.fromRGB(200, 200, 200)
			likeBtn:SetAttribute("IsLiked", false)
		end
	end

	-- 2. Fetch Data Baru (Async)
	task.spawn(function()
		-- A. FRIENDS (Client Side)
		local fCount = 0
		local s1, pages = pcall(function() return Players:GetFriendsAsync(target.UserId) end)
		if s1 and pages then
			while true do
				fCount += #pages:GetCurrentPage()
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
			if friendStat.Parent then friendStat.Text = tostring(fCount) end
		else
			if not cachedData and friendStat.Parent then friendStat.Text = "-" end
		end

		-- B. FOLLOWERS & LIKES (Server Side)
		local remote = Events:FindFirstChild("GetPlayerStats")
		if remote then
			local data = remote:InvokeServer(target.UserId)
			if panel.Parent and data then
				-- Followers
				if data.followers then
					local val = tonumber(data.followers) or 0
					if val > 9999 then followStat.Text = string.format("%.1fK", val/1000) else followStat.Text = tostring(val) end
				else
					if not cachedData then followStat.Text = "N/A" end
				end

				-- Likes
				local lCount = tonumber(data.likes) or 0
				likeStat.Text = tostring(lCount)

				-- Like Status
				if data.hasLiked then
					likeBtn.Image = ICON_LIKE
					likeBtn.ImageColor3 = Color3.fromRGB(255, 80, 80)
					likeBtn:SetAttribute("IsLiked", true)
				else
					likeBtn.Image = ICON_UNLIKE
					likeBtn.ImageColor3 = Color3.fromRGB(200, 200, 200)
					likeBtn:SetAttribute("IsLiked", false)
				end

				-- Update Cache
				DataCache[target.UserId] = {
					friends = friendStat.Text,
					followers = followStat.Text,
					likes = likeStat.Text,
					hasLiked = (likeBtn:GetAttribute("IsLiked") == true)
				}
			end
		end
	end)

	-- EVENT KLIK LIKE
	likeBtn.MouseButton1Click:Connect(function()
		playClickSound()

		local isLiked = likeBtn:GetAttribute("IsLiked") == true
		local currentCount = tonumber(likeStat.Text) or 0
		local newCount, newStatus

		if isLiked then
			-- Unlike
			likeBtn.Image = ICON_UNLIKE
			likeBtn.ImageColor3 = Color3.fromRGB(200, 200, 200)
			likeBtn:SetAttribute("IsLiked", false)
			newCount = math.max(0, currentCount - 1)
			newStatus = false

			local scale = Instance.new("UIScale"); scale.Parent = likeBtn
			TweenService:Create(scale, TweenInfo.new(0.1), {Scale=0.8}):Play()
			task.wait(0.1)
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), {Scale=1}):Play()
		else
			-- Like
			likeBtn.Image = ICON_LIKE
			likeBtn.ImageColor3 = Color3.fromRGB(255, 80, 80)
			likeBtn:SetAttribute("IsLiked", true)
			newCount = currentCount + 1
			newStatus = true

			local scale = Instance.new("UIScale"); scale.Parent = likeBtn
			TweenService:Create(scale, TweenInfo.new(0.1), {Scale=1.3}):Play()
			task.wait(0.1)
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), {Scale=1}):Play()
		end

		likeStat.Text = tostring(newCount)

		-- Update Cache Manual
		if DataCache[target.UserId] then
			DataCache[target.UserId].likes = tostring(newCount)
			DataCache[target.UserId].hasLiked = newStatus
		else
			DataCache[target.UserId] = {
				friends = friendStat.Text,
				followers = followStat.Text,
				likes = tostring(newCount),
				hasLiked = newStatus
			}
		end

		local remote = Events:FindFirstChild("ToggleLike")
		if remote then
			remote:FireServer(target.UserId)
		end
	end)


	-- === PAGES CONTAINER (GRID UTAMA) ===
	local pagesContainer = Instance.new("Frame")
	pagesContainer.Name = "PagesContainer"
	pagesContainer.Size = UDim2.new(1, -24 * BASE_SCALE, 0, 170 * BASE_SCALE) 
	pagesContainer.Position = UDim2.new(0.5, 0, 0, 195 * BASE_SCALE)
	pagesContainer.AnchorPoint = Vector2.new(0.5, 0)
	pagesContainer.BackgroundTransparency = 1
	pagesContainer.ClipsDescendants = true
	pagesContainer.Parent = panel

	local pageLayout = Instance.new("UIPageLayout")
	pageLayout.Circular = true 
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Animated = true
	pageLayout.TweenTime = 0.4
	pageLayout.EasingStyle = Enum.EasingStyle.Quint
	pageLayout.EasingDirection = Enum.EasingDirection.Out
	pageLayout.ScrollWheelInputEnabled = false 
	pageLayout.Parent = pagesContainer

	local function addGridLayout(frame: Frame)
		local margin = Instance.new("UIPadding")
		margin.PaddingTop = UDim.new(0, 4 * BASE_SCALE)    
		margin.PaddingLeft = UDim.new(0, 4 * BASE_SCALE)   
		margin.PaddingRight = UDim.new(0, 4 * BASE_SCALE)  
		margin.PaddingBottom = UDim.new(0, 0)              
		margin.Parent = frame

		local grid = Instance.new("UIGridLayout")
		local gap = 12 * BASE_SCALE 
		grid.CellPadding = UDim2.new(0, gap, 0, gap)
		local buttonHeight = 65 * BASE_SCALE 
		local safetyBuffer = 1
		grid.CellSize = UDim2.new(0.5, -(gap / 2) - safetyBuffer, 0, buttonHeight)
		grid.FillDirectionMaxCells = 2 
		grid.StartCorner = Enum.StartCorner.TopLeft
		grid.Parent = frame
	end

	local function makeGridButton(iconId: string, title: string, subtitle: string, parent: Frame)
		local btn = Instance.new("TextButton")
		btn.Name = title
		btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
		corner.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = Color3.fromRGB(255, 255, 255) 
		btnStroke.Transparency = 0.6
		btnStroke.Thickness = 1.3 * BASE_SCALE
		btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		btnStroke.Parent = btn

		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 14 * BASE_SCALE, 0.5, 0)
		icon.Size = UDim2.new(0, 30 * BASE_SCALE, 0, 30 * BASE_SCALE)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = Color3.fromRGB(230, 230, 230)
		icon.Parent = btn

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "TitleLabel"
		titleLabel.AnchorPoint = Vector2.new(0, 0.5)
		titleLabel.Position = UDim2.new(0, 54 * BASE_SCALE, 0.5, -9 * BASE_SCALE) 
		titleLabel.Size = UDim2.new(1, -60 * BASE_SCALE, 0, 20 * BASE_SCALE)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = title
		titleLabel.Font = FONT_BOLD
		titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
		titleLabel.TextSize = 15 * BASE_SCALE
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = btn

		local subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "SubtitleLabel"
		subtitleLabel.AnchorPoint = Vector2.new(0, 0.5)
		subtitleLabel.Position = UDim2.new(0, 54 * BASE_SCALE, 0.5, 10 * BASE_SCALE) 
		subtitleLabel.Size = UDim2.new(1, -60 * BASE_SCALE, 0, 18 * BASE_SCALE)
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Text = subtitle
		subtitleLabel.Font = FONT_REGULAR
		subtitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		subtitleLabel.TextSize = 11 * BASE_SCALE
		subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		subtitleLabel.Parent = btn

		local scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = btn

		btn.MouseEnter:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.2}):Play() 
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.1), {Scale = 1}):Play()
			TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play() 
		end)
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.1), {Scale = 0.95}):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), {Scale = 1.03}):Play()
		end)

		local function doFlash()
			local flash = Instance.new("Frame")
			flash.Size = UDim2.fromScale(1,1)
			flash.BackgroundColor3 = Color3.new(1,1,1)
			flash.BackgroundTransparency = 0.8
			flash.ZIndex = 50
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10 * BASE_SCALE); c.Parent = flash
			flash.Parent = btn
			TweenService:Create(flash, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
			task.delay(0.25, function() flash:Destroy() end)
		end

		return btn, titleLabel, subtitleLabel, doFlash
	end

	local page1 = Instance.new("Frame")
	page1.Name = "Page1"
	page1.BackgroundTransparency = 1
	page1.Size = UDim2.fromScale(1, 1)
	page1.LayoutOrder = 1
	page1.Parent = pagesContainer
	addGridLayout(page1)

	-- BUTTONS PAGE 1
	local carryBtn, _, _, carryFlash = makeGridButton("rbxassetid://82418724795330", "CARRY", "Pick up player", page1)
	carryBtn.MouseButton1Click:Connect(function() playClickSound(); carryFlash(); showSelectorPanel(target); end)

	local friendBtn, _, friendSub, friendFlash = makeGridButton("rbxassetid://122950291665538", "FRIEND", "Add friend", page1)
	friendSub.Text = safeIsFriendsWith(Player, target.UserId) and "Remove friend" or "Add friend"
	friendBtn.MouseButton1Click:Connect(function()
		playClickSound(); friendFlash()
		if safeIsFriendsWith(Player, target.UserId) then pcall(function() StarterGui:SetCore("PromptUnfriend", target) end)
		else pcall(function() StarterGui:SetCore("PromptSendFriendRequest", target) end) end
		task.delay(1, function() if friendSub.Parent then friendSub.Text = safeIsFriendsWith(Player, target.UserId) and "Remove friend" or "Add friend" end end)
	end)

	local syncBtn, _, syncSub, syncFlash = makeGridButton("rbxassetid://107515648029667", "SYNC", "Coordinate", page1)
	local function toggleSync()
		local isSynced = (Player:GetAttribute("syncedPlayerId") == target.UserId)

		if isSynced then
			-- KONDISI: STOP SYNC
			Player:SetAttribute("syncedPlayerId", nil)
			RequestSync:FireServer(nil)

			-- [UBAH DI SINI] Notifikasi Sync Ended
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Synchronization",
					Text = "Sync ended.",
					Duration = 3
				})
			end)

			if syncSub then syncSub.Text = "Coordinate" end

		else
			-- KONDISI: START SYNC
			Player:SetAttribute("syncedPlayerId", target.UserId)
			RequestSync:FireServer(target)

			-- [UBAH DI SINI] Notifikasi You Coordinate...
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Synchronization",
					Text = "You coordinate " .. target.DisplayName,
					Duration = 3
				})
			end)

			if syncSub then syncSub.Text = "Stop coordinating" end
		end
	end
	syncBtn.MouseButton1Click:Connect(function() playClickSound(); syncFlash(); toggleSync(); end)
	task.defer(function() if syncSub.Parent then syncSub.Text = (Player:GetAttribute("syncedPlayerId") == target.UserId) and "Stop snc" or "Coordinate" end end)

	local viewBtn, _, _, viewFlash = makeGridButton("rbxassetid://109510722703012", "VIEW", "Inspect profile", page1)
	viewBtn.MouseButton1Click:Connect(function() playClickSound(); viewFlash(); pcall(function() GuiService:InspectPlayerFromUserId(target.UserId) end); end)

	-- PAGE 2
	local page2 = Instance.new("Frame")
	page2.Name = "Page2"
	page2.BackgroundTransparency = 1
	page2.Size = UDim2.fromScale(1, 1)
	page2.LayoutOrder = 2
	page2.Parent = pagesContainer
	addGridLayout(page2)

	local giftBtn, _, _, giftFlash = makeGridButton("rbxassetid://11560341132", "GIFT", "Send Robux", page2) -- Icon Gift
	giftBtn.MouseButton1Click:Connect(function()
		playClickSound()
		giftFlash()

		-- 1. Fire Event ke TipJar membawa target player
		OpenTipJarEvent:Fire(target)

		-- 2. Tutup ACM
		destroyUI()
		zoomCameraOut()
		State.panelOpen = false
	end)

	-- ✅ CLONE BUTTON (Logic Implemented)
	local cloneBtn, _, _, cloneFlash = makeGridButton("rbxassetid://120971085584613", "CLONE", "Copy avatar", page2)
	cloneBtn.MouseButton1Click:Connect(function()
		playClickSound()
		cloneFlash()

		-- [UBAH DI SINI] Notifikasi Cloning dimulai
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = "Avatar Cloning",
				Text = "Cloning " .. target.DisplayName .. "...",
				Duration = 3,
				Icon = "rbxassetid://120971085584613" -- (Opsional) Icon Clone
			})
		end)

		-- Fire Remote ke Server
		local success, err = pcall(function()
			CloneAvatarRemote:FireServer(target.UserId)
		end)

		if not success then
			warn("[ACM] Clone failed:", err)
			-- Notifikasi jika Gagal
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "System Error",
					Text = "Clone Request Failed.",
					Duration = 3
				})
			end)
		else
			-- Efek visual sukses & tutup panel
			task.wait(0.5)
			destroyUI()
			zoomCameraOut()
			State.panelOpen = false
		end
	end)


	-- === BAGIAN BAWAH: PAGINATION ===
	local navBar = Instance.new("Frame")
	navBar.Name = "NavBar"
	navBar.Size = UDim2.new(1, -60 * BASE_SCALE, 0, 40 * BASE_SCALE)
	navBar.Position = UDim2.new(0.5, 0, 1, -14 * BASE_SCALE)
	navBar.AnchorPoint = Vector2.new(0.5, 1)
	navBar.BackgroundTransparency = 1
	navBar.Parent = panel

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, 12 * BASE_SCALE)
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder 
	navLayout.Parent = navBar

	local function createSolidNavBtn(name, text, width, isClickable, order, layoutFn)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.LayoutOrder = order 
		btn.Size = UDim2.new(0, width * BASE_SCALE, 0, 32 * BASE_SCALE)
		btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
		btn.Text = text
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16 * BASE_SCALE
		btn.TextColor3 = Color3.fromRGB(220, 220, 220)
		btn.AutoButtonColor = false
		btn.Active = isClickable
		btn.Parent = navBar

		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
		cr.Parent = btn

		local str = Instance.new("UIStroke")
		str.Color = Color3.fromRGB(255, 255, 255)
		str.Transparency = 0.7
		str.Thickness = 1.5 * BASE_SCALE
		str.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		str.Parent = btn

		if isClickable then
			btn.MouseButton1Click:Connect(function()
				playClickSound()
				layoutFn()
			end)
			btn.MouseEnter:Connect(function()
				TweenService:Create(str, TweenInfo.new(0.2), {Transparency = 0.3}):Play()
				TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(str, TweenInfo.new(0.2), {Transparency = 0.7}):Play()
				TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 25)}):Play()
			end)
		end
		return btn
	end

	local prevBtn = createSolidNavBtn("Prev", "◁", 40, true, 1, function()
		pageLayout:Previous()
	end)

	local pageDisplay = createSolidNavBtn("Display", "1", 50, false, 2, nil)
	pageDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)

	local nextBtn = createSolidNavBtn("Next", "▷", 40, true, 3, function()
		pageLayout:Next()
	end)

	local function updateNav()
		local current = pageLayout.CurrentPage
		if current then
			local pageNum = current.LayoutOrder
			pageDisplay.Text = string.format("%d", pageNum)
			prevBtn.TextTransparency = 0
			nextBtn.TextTransparency = 0
		end
	end

	pageLayout:GetPropertyChangedSignal("CurrentPage"):Connect(updateNav)
	updateNav()

	return panel
end

----------------------------------------------------------------
-- MINI PANEL (LEPAS / TURUN)
----------------------------------------------------------------
local miniGui: ScreenGui? = nil
local carrierRow: Frame? = nil
local passengerRow: Frame? = nil
local carriedIndex: number = 1

local function ensureMiniLayer(): ScreenGui
	if miniGui and miniGui.Parent then return miniGui end
	local g = Instance.new("ScreenGui")
	g.Name = "ACM_MiniUI"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.DisplayOrder = 100
	g.Parent = PlayerGui
	miniGui = g
	return g
end

local function destroyMiniRows()
	if carrierRow then carrierRow:Destroy() end
	if passengerRow then passengerRow:Destroy() end
	carrierRow, passengerRow = nil, nil

	if miniGui then
		local listPanel = miniGui:FindFirstChild("ACM_CarryListPanel")
		if listPanel then listPanel:Destroy() end
	end
end

local function makeRow(width: number, showListButton: boolean): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, width * BASE_SCALE, 0, 42 * BASE_SCALE)
	f.BackgroundColor3 = COLOR_BG
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	f.ZIndex = 60
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70,70,70)
	s.Thickness = 1 * BASE_SCALE
	s.Transparency = 0.4
	s.Parent = f

	local listButton = Instance.new("ImageButton")
	listButton.Name = "ListButton"
	listButton.AnchorPoint = Vector2.new(0, 0.5)
	listButton.Position = UDim2.new(0, 12 * BASE_SCALE, 0.5, 0)
	listButton.Size = UDim2.new(0, 28 * BASE_SCALE, 0, 28 * BASE_SCALE)
	listButton.BackgroundTransparency = 1
	listButton.Image = ICON_LIST_ID
	listButton.ImageColor3 = COLOR_TEXT
	listButton.ZIndex = 62
	listButton.Visible = showListButton 
	listButton.Parent = f

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.AnchorPoint = Vector2.new(0, 0.5)
	local nameLabelX = showListButton and (12 + 28 + 8) * BASE_SCALE or 14 * BASE_SCALE
	nameLabel.Position = UDim2.new(0, nameLabelX, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = COLOR_TEXT
	nameLabel.Font = FONT_BOLD
	nameLabel.TextSize = 18 * BASE_SCALE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 61
	nameLabel.Parent = f

	local button = Instance.new("TextButton")
	button.Name = "ActionButton"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -14 * BASE_SCALE, 0.5, 0)
	button.Size = UDim2.new(0, 85 * BASE_SCALE, 0, 28 * BASE_SCALE)
	button.BackgroundColor3 = Color3.fromRGB(45,45,45)
	button.TextColor3 = COLOR_TEXT
	button.Font = FONT_BOLD
	button.TextSize = 15 * BASE_SCALE
	button.AutoButtonColor = true 
	button.ZIndex = 61
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
	c2.Parent = button
	local s2 = Instance.new("UIStroke")
	s2.Color = Color3.fromRGB(90,90,90)
	s2.Thickness = 1 * BASE_SCALE
	s2.Transparency = 0.3
	s2.Parent = button
	button.Parent = f

	return f
end

local function updateCarryListPanel(panel: Frame)
	local list = _G.ACM_STATE and (_G.ACM_STATE.carriedList or {}) or {}
	local title = panel:FindFirstChild("Title") :: TextLabel?

	if not title then return end 

	title.Text = string.format("LIST CARRY (%d/8)", #list)

	for _, v in ipairs(panel:GetChildren()) do
		if v.Name == "Row" then
			v:Destroy()
		end
	end

	if #list == 0 then
		panel:Destroy()
		return
	end

	local totalHeight = 24 + 8 + 8 + (#list * 30) + ((#list - 1) * 4) 

	for i, item in ipairs(list) do
		local p = Players:GetPlayerByUserId(item.id)
		local name = p and p.DisplayName or item.name or "Player"

		local row = Instance.new("Frame")
		row.Name = "Row"
		row.Size = UDim2.new(1, 0, 0, 30 * BASE_SCALE)
		row.BackgroundTransparency = 1
		row.LayoutOrder = i
		row.Parent = panel

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0, 0.5)
		nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
		nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLabel.Font = FONT_REGULAR
		nameLabel.TextSize = 15 * BASE_SCALE
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, 0, 0.5, 0)
		btn.Size = UDim2.new(0, 60 * BASE_SCALE, 0, 24 * BASE_SCALE)
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		btn.Text = "LEPAS"
		btn.TextColor3 = COLOR_TEXT
		btn.Font = FONT_BOLD
		btn.TextSize = 13 * BASE_SCALE

		local cBtn = Instance.new("UICorner")
		cBtn.CornerRadius = UDim.new(0, 6 * BASE_SCALE)
		cBtn.Parent = btn
		btn.Parent = row

		btn.MouseButton1Click:Connect(function()
			playClickSound()
			safeFireCarryRemote("Stop", {targetId = item.id})
		end)
	end

	local targetSize = UDim2.new(0, 220 * BASE_SCALE, 0, totalHeight * BASE_SCALE)
	if panel.Size ~= targetSize then
		TweenService:Create(panel, TWEEN_INFO_PANEL_LIST, {
			Size = targetSize
		}):Play()
	end
end

local function buildCarryListPanel(gui: ScreenGui)
	local panel = Instance.new("Frame")
	panel.Name = "ACM_CarryListPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 15 * BASE_SCALE, 0.5, 0) 
	panel.Size = UDim2.new(0, 220 * BASE_SCALE, 0, 40 * BASE_SCALE) 
	panel.BackgroundColor3 = COLOR_BG
	panel.BackgroundTransparency = 0.1
	panel.ZIndex = 50
	panel.ClipsDescendants = true
	panel.Parent = gui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
	c.Parent = panel
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(70,70,70)
	s.Thickness = 1 * BASE_SCALE
	s.Transparency = 0.4
	s.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4 * BASE_SCALE)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8 * BASE_SCALE)
	padding.PaddingBottom = UDim.new(0, 8 * BASE_SCALE)
	padding.PaddingLeft = UDim.new(0, 8 * BASE_SCALE)
	padding.PaddingRight = UDim.new(0, 8 * BASE_SCALE)
	padding.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24 * BASE_SCALE)
	title.BackgroundTransparency = 1
	title.Text = "LIST CARRY"
	title.TextColor3 = COLOR_TEXT
	title.Font = FONT_BOLD
	title.TextSize = 16 * BASE_SCALE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 0
	title.Parent = panel

	updateCarryListPanel(panel)
end

local function toggleCarryListPanel()
	playClickSound()
	local gui = ensureMiniLayer()
	local existing = gui:FindFirstChild("ACM_CarryListPanel")

	if existing then
		existing:Destroy()
	else
		buildCarryListPanel(gui)
	end
end


local function refreshMiniRows()
	local list = _G.ACM_STATE and (_G.ACM_STATE.carriedList or {}) or {}
	local cname: string? = nil
	if State.carrierId then
		local p = Players:GetPlayerByUserId(State.carrierId)
		if p then cname = p.DisplayName end
	end

	local gui = ensureMiniLayer()

	-- === Carrier Row ===
	if #list > 0 then
		if not carrierRow or not carrierRow.Parent then
			local showList = (State.currentCarryMode == "Multi")
			carrierRow = makeRow(340, showList)
			carrierRow.Name = "ACM_CarrierRow"
			carrierRow.AnchorPoint = Vector2.new(0.5, 1)
			carrierRow.Position = UDim2.new(0.5, 0, 1, -110 * BASE_SCALE)
			carrierRow.Parent = gui

			local listButton = carrierRow:FindFirstChild("ListButton")
			if listButton then
				listButton.MouseButton1Click:Connect(toggleCarryListPanel)
			end

			local actionButton = carrierRow:FindFirstChild("ActionButton")
			if actionButton and actionButton:IsA("TextButton") then
				actionButton.MouseButton1Click:Connect(function()
					playClickSound()
					local currentList = _G.ACM_STATE and (_G.ACM_STATE.carriedList or {}) or {}
					if #currentList > 0 then
						local firstItem = currentList[1]
						safeFireCarryRemote("Stop", {targetId = firstItem.id})
					end
				end)
			end
		end

		local item = list[1]
		if State.currentCarryMode == "Multi" then
			carrierRow.NameLabel.Text = string.format("%s (%d/%d)", item.name or "Player", #list, 8)
		else
			carrierRow.NameLabel.Text = string.format("%s", item.name or "Player") 
		end
		carrierRow.ActionButton.Text = "LEPAS"

	else
		if carrierRow then carrierRow:Destroy(); carrierRow = nil end
		local listPanel = gui:FindFirstChild("ACM_CarryListPanel")
		if listPanel then listPanel:Destroy() end
	end

	-- === Passenger Row ===
	if cname then
		if not passengerRow or not passengerRow.Parent then
			passengerRow = makeRow(340, false)
			passengerRow.Name = "ACM_PassengerRow"
			passengerRow.AnchorPoint = Vector2.new(0.5, 1)
			passengerRow.Position = UDim2.new(0.5, 0, 1, (carrierRow and -158 or -110) * BASE_SCALE)
			passengerRow.Parent = gui

			local actionButton = passengerRow:FindFirstChild("ActionButton")
			if actionButton and actionButton:IsA("TextButton") then
				actionButton.MouseButton1Click:Connect(function()
					playClickSound()
					safeFireCarryRemote("Stop", {})
					resetPassengerState()
				end)
			end
		end

		passengerRow.NameLabel.Text = cname
		passengerRow.ActionButton.Text = "TURUN"

	else
		if passengerRow then passengerRow:Destroy(); passengerRow = nil end
	end
end

----------------------------------------------------------------
-- COMPACT PROMPT
----------------------------------------------------------------
local function showPrompt(fromPlayer: Player)
	local old = PlayerGui:FindFirstChild("ACM_CarryPrompt")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ACM_CarryPrompt"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 90
	gui.Parent = PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300 * BASE_SCALE, 0, 145 * BASE_SCALE)
	frame.Position = UDim2.new(0.5, 0, 0.5, 20 * BASE_SCALE) 
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
	frame.BorderSizePixel = 0
	frame.Visible = false 
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
	c.Parent = frame
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(60, 60, 60)
	s.Thickness = 1 * BASE_SCALE
	s.Transparency = 0.4
	s.Parent = frame

	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundTransparency = 1
	avatar.Size = UDim2.new(0, 44 * BASE_SCALE, 0, 44 * BASE_SCALE)
	avatar.Position = UDim2.new(0, 18 * BASE_SCALE, 0, 18 * BASE_SCALE)
	avatar.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=180&h=180"):format(fromPlayer.UserId)
	avatar.Parent = frame
	local avCorner = Instance.new("UICorner")
	avCorner.CornerRadius = UDim.new(1,0)
	avCorner.Parent = avatar

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Text = fromPlayer.DisplayName
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18 * BASE_SCALE
	name.Position = UDim2.new(0, 70 * BASE_SCALE, 0, 18 * BASE_SCALE)
	name.Size = UDim2.new(1, -80 * BASE_SCALE, 0, 22 * BASE_SCALE)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = frame

	local uname = Instance.new("TextLabel")
	uname.BackgroundTransparency = 1
	local data = pendingPrompts[fromPlayer.UserId]
	local animType = data and data.animType or "Carry"
	if animType == "Carry" or animType == "Piggyback" then
		uname.Text = "@ " .. fromPlayer.Name .. " • wants to carry you"
	else
		uname.Text = string.format("@ %s • wants to %s you", fromPlayer.Name, animType)
	end
	uname.TextColor3 = Color3.fromRGB(190, 190, 190)
	uname.Font = Enum.Font.GothamMedium
	uname.TextSize = 14 * BASE_SCALE
	uname.Position = UDim2.new(0, 70 * BASE_SCALE, 0, 38 * BASE_SCALE)
	uname.Size = UDim2.new(1, -110 * BASE_SCALE, 0, 18 * BASE_SCALE)
	name.TextXAlignment = Enum.TextXAlignment.Left
	uname.Parent = frame

	local countdown = Instance.new("TextLabel")
	countdown.BackgroundTransparency = 1
	countdown.Text = "Respond in 8s..."
	countdown.TextColor3 = Color3.fromRGB(150, 150, 150)
	countdown.Font = Enum.Font.GothamMedium
	countdown.TextSize = 13 * BASE_SCALE
	countdown.Position = UDim2.new(0, 70 * BASE_SCALE, 0, 56 * BASE_SCALE)
	countdown.Size = UDim2.new(1, -110 * BASE_SCALE, 0, 18 * BASE_SCALE)
	countdown.TextXAlignment = Enum.TextXAlignment.Left
	countdown.Parent = frame

	local btnContainer = Instance.new("Frame")
	btnContainer.BackgroundTransparency = 1
	btnContainer.Size = UDim2.new(1, -16 * BASE_SCALE, 0, 36 * BASE_SCALE)
	btnContainer.Position = UDim2.new(0, 8 * BASE_SCALE, 1, -46 * BASE_SCALE)
	btnContainer.Parent = frame

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	btnLayout.Padding = UDim.new(0, 10 * BASE_SCALE)
	btnLayout.Parent = btnContainer

	local accept = Instance.new("TextButton")
	accept.Size = UDim2.new(0.5, -24 * BASE_SCALE, 0, 36 * BASE_SCALE)
	accept.Position = UDim2.new(0, 12 * BASE_SCALE, 1, -52 * BASE_SCALE)
	accept.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	accept.BackgroundTransparency = 0.3
	accept.Text = "ACCEPT"
	accept.TextColor3 = Color3.new(1, 1, 1)
	accept.Font = FONT_BOLD
	accept.TextSize = 16 * BASE_SCALE
	accept.AutoButtonColor = false
	local aCorner = Instance.new("UICorner")
	aCorner.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
	aCorner.Parent = accept
	local aStroke = Instance.new("UIStroke")
	aStroke.Color = Color3.fromRGB(255, 255, 255)
	aStroke.Thickness = 1.3 * BASE_SCALE
	aStroke.Transparency = 0.25
	aStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	aStroke.Parent = accept
	accept.Parent = frame

	local deny = accept:Clone()
	deny.Size = UDim2.new(0.5, -24 * BASE_SCALE, 0, 36 * BASE_SCALE)
	deny.Position = UDim2.new(0.5, 12 * BASE_SCALE, 1, -52 * BASE_SCALE)
	deny.Text = "DENY"
	deny.Parent = frame

	local accepted = false
	local timer = 8

	accept.MouseButton1Click:Connect(function()
		accepted = true
		safeFireCarryRemote("Response", {requesterId = fromPlayer.UserId, accept = true})
		gui:Destroy()
	end)

	deny.MouseButton1Click:Connect(function()
		safeFireCarryRemote("Response", {requesterId = fromPlayer.UserId, accept = false})
		gui:Destroy()
	end)

	frame.BackgroundTransparency = 1
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05
	}):Play()
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}):Play()

	task.spawn(function()
		while timer > 0 and gui.Parent do
			countdown.Text = string.format("Respond in %ds...", timer)
			timer -= 1
			task.wait(1)
		end
		if gui.Parent and not accepted then
			safeFireCarryRemote("Response", {requesterId = fromPlayer.UserId, accept = false})
			gui:Destroy()
			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Carry Request Expired",
					Text = "No response received.",
					Duration = 3
				})
			end)
		end
	end)
end


local function showPanel(target: Player, isPrompt: boolean, promptName: string?)
	if State.panelOpen then
		destroyUI()
	end

	State.currentTarget = target
	State.panelOpen = true
	State.isRemoteView = isRemote or false

	highlightTarget(target)
	zoomCameraIn()

	local gui = Instance.new("ScreenGui")
	gui.Name = "ACM_GUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = PlayerGui

	local blur = Instance.new("Frame")
	blur.Size = UDim2.new(1, 0, 1, 0)
	blur.BackgroundColor3 = Color3.new(0, 0, 0)
	blur.BackgroundTransparency = 0.7
	blur.BorderSizePixel = 0
	blur.ZIndex = 5
	blur.Parent = gui

	local panel = buildMainPanel(target, isPrompt, promptName)
	panel.Parent = gui

	mainGui = gui
	mainPanel = panel

	TweenService:Create(panel, TWEEN_INFO_SLIDE, {
		Position = UDim2.new(0.5, 0, 0.5, 0) 
	}):Play()

	playClickSound()
end

----------------------------------------------------------------
-- Carry Animations (Local Play/Stop)
----------------------------------------------------------------
local _sitTrack: AnimationTrack? = nil
local _carryTrack: AnimationTrack? = nil

local function isR15(hum: Humanoid?): boolean
	return hum and hum.RigType == Enum.HumanoidRigType.R15 or false
end

local function getAnimator(hum: Humanoid?): Animator?
	if not hum then return nil end
	return hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
end

local function getBlueprint(animType: string?): table?
	if not animType then return nil end
	return CarryBlueprints[animType]
end

local function playCarryAnimLocal(animType: string?)
	local char = Player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not hum then return end

	local blueprint = getBlueprint(animType)
	if not blueprint then
		warn("[ACMv6] Error: Tidak bisa playCarryAnim, blueprint tidak ditemukan:", animType)
		return
	end

	local animId = isR15(hum) and blueprint.CarrierAnimID_R15 or blueprint.CarrierAnimID_R6
	if not animId then return end

	if _carryTrack then _carryTrack:Stop(0.15) end
	local animator = getAnimator(hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. animId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	anim:Destroy()

	if ok and track then
		_carryTrack = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
	end
end

local function stopCarryAnimLocal()
	if _carryTrack then
		_carryTrack:Stop(0.15)
		_carryTrack = nil
	end
end

local function playSitAnimLocal(animType: string?)
	local char = Player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not hum then return end

	local blueprint = getBlueprint(animType)
	if not blueprint then
		warn("[ACMv6] Error: Tidak bisa playSitAnim, blueprint tidak ditemukan:", animType)
		return
	end

	local animId = isR15(hum) and blueprint.TargetAnimID_R15 or blueprint.TargetAnimID_R6
	if not animId then return end

	if _sitTrack then _sitTrack:Stop(0.15) end
	local animator = getAnimator(hum)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. animId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	anim:Destroy()

	if ok and track then
		_sitTrack = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play(0.2)
	end
end

local function stopSitAnimLocal()
	if _sitTrack then
		_sitTrack:Stop(0.15)
		_sitTrack = nil
	end
end


----------------------------------------------------------------
-- Carry Remote Handlers
----------------------------------------------------------------
local function setupCarryHandlers()
	CarryRemote.OnClientEvent:Connect(function(action: string, data: any)

		if action == "Prompt" then
			local fromId = data and data.fromId
			local fromPlayer = (typeof(fromId) == "number") and Players:GetPlayerByUserId(fromId) or nil
			if not fromPlayer then return end

			local animType = data.animType or "Carry"
			pendingPrompts[fromId] = {fromId = fromId, fromName = data.fromName, animType = animType}
			showPrompt(fromPlayer)

		elseif action == "Start" then
			local animType = data.animType
			local carryMode = data.carryMode

			if data.youAreCarrier then
				local list = _G.ACM_STATE.carriedList or {}
				table.insert(list, { id = data.targetId, name = data.targetName })
				_G.ACM_STATE.carriedList = list
				State.carriedIds[data.targetId] = true
				State.currentCarryMode = carryMode
				playCarryAnimLocal(animType)

				if State.panelOpen then
					destroyUI()
					zoomCameraOut()
					State.panelOpen = false
				end
			else
				State.carrierId = data.carrierId
				State.isPassenger = true
				_G.ACM_STATE.carrierId = data.carrierId
				playSitAnimLocal(animType)

				if State.panelOpen then
					destroyUI()
					zoomCameraOut()
					State.panelOpen = false
				end
			end

			if State.panelOpen then
				destroyUI()
				zoomCameraOut()
				State.panelOpen = false
			end

			if typeof(refreshMiniRows) == "function" then refreshMiniRows() end
			local p = PlayerGui:FindFirstChild("ACM_CarryPrompt"); if p then p:Destroy() end

		elseif action == "End" then
			if data.youAreCarrier then
				State.carriedIds[data.removedId] = nil
				local list = _G.ACM_STATE.carriedList or {}
				local newList = {}
				for _, it in ipairs(list) do
					if it.id ~= data.removedId then table.insert(newList, it) end
				end
				_G.ACM_STATE.carriedList = newList

				if #newList == 0 then
					stopCarryAnimLocal()
					State.currentCarryMode = nil 
				end
			else
				resetPassengerState()
				stopSitAnimLocal()
			end

			if typeof(refreshMiniRows) == "function" then refreshMiniRows() end

		elseif action == "CarrierList" then
			local list = data.list or {}
			local arr = {}
			local newIds = {}
			for _, it in ipairs(list) do
				table.insert(arr, { id = it.id, name = it.name })
				newIds[it.id] = true
			end
			_G.ACM_STATE.carriedList = arr
			State.carriedIds = newIds 

			local animType = data.animType or "Piggyback" 
			local carryMode = data.carryMode or "Multi"
			State.currentCarryMode = carryMode

			if #arr > 0 then playCarryAnimLocal(animType) else stopCarryAnimLocal() end

			if typeof(refreshMiniRows) == "function" then refreshMiniRows() end



		elseif action == "RequestExpired" or action == "PromptExpire" then
			if State.panelOpen then
				destroyUI()
				zoomCameraOut()
				State.panelOpen = false
			end

			local p = PlayerGui:FindFirstChild("ACM_CarryPrompt"); if p then p:Destroy() end

			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Carry Request Expired",
					Text = "No response received.",
					Duration = 3
				})
			end)

			if typeof(refreshMiniRows) == "function" then refreshMiniRows() end
		elseif action == "Busy" or action == "Failed" or action == "TooFar" or action == "Limit" or action == "Declined" then
			if State.panelOpen then
				destroyUI()
				zoomCameraOut()
				State.panelOpen = false
			end

			local reason = data and data.reason or "Unknown error"
			local text = "Request Failed"

			if action == "TooFar" then text = "Target is too far away!"
			elseif action == "Declined" then text = "Request declined."
			elseif reason == "pending" then text = "Target has a pending request."
			elseif reason == "target_busy" then text = "Target is busy/being carried."
			elseif reason == "wrong_mode" then text = "Wrong Carry Mode active."
			elseif reason == "limit" or reason == "solo_full" then text = "Carry limit reached."
			elseif reason == "limit_transfer" then text = "Cannot transfer (Group full)."
			end

			pcall(function()
				StarterGui:SetCore("SendNotification", {
					Title = "Carry Failed",
					Text = text,
					Duration = 4,
					Icon = "rbxassetid://122950291665538"
				})
			end)
		end

		if action == "Start" or action == "End" or action == "CarrierList" then
			if miniGui then
				local listPanel = miniGui:FindFirstChild("ACM_CarryListPanel")
				if listPanel and listPanel.Parent then
					updateCarryListPanel(listPanel)
				end
			end
		end

	end)
end


----------------------------------------------------------------
-- Input Handler (Click to Open Panel)
----------------------------------------------------------------
local function setupInputHandler()
	local lastClickTime = 0

	-- MOBILE TOUCH TRACKING
	local touchStartPos: Vector2? = nil
	local touchStartTime = 0

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if UserInputService:GetFocusedTextBox() then return end

		-- ❌ Desktop tetap normal
		if not IS_MOBILE then
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

			local now = os.clock()
			if now - lastClickTime < 0.15 then return end
			lastClickTime = now

			local target = raycastForPlayer(MAX_ACTIVATION_DISTANCE, nil)
			if target and target ~= Player and not State.carriedIds[target.UserId] then
				showPanel(target, false, nil)
			end
			return
		end

		-- 📱 MOBILE: simpan posisi & waktu awal
		if input.UserInputType == Enum.UserInputType.Touch then
			touchStartPos = input.Position
			touchStartTime = os.clock()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not IS_MOBILE then return end
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not touchStartPos then return end

		local duration = os.clock() - touchStartTime
		local moveDist = (input.Position - touchStartPos).Magnitude

		-- ❌ JIKA GESER / HOLD → ABORT
		if moveDist > TOUCH_MAX_MOVE then
			touchStartPos = nil
			return
		end

		if duration > TOUCH_MAX_TIME then
			touchStartPos = nil
			return
		end

		-- ⏱ Anti spam
		local now = os.clock()
		if now - lastClickTime < 0.4 then
			touchStartPos = nil
			return
		end
		lastClickTime = now

		-- ✅ BARU DIANGGAP "NIAT TAP"
		local target = raycastForPlayer(MAX_ACTIVATION_DISTANCE, input.Position)
		if target and target ~= Player and not State.carriedIds[target.UserId] then
			showPanel(target, false, nil)
		end

		touchStartPos = nil
	end)
end


----------------------------------------------------------------
-- Keyboard Shortcut: X untuk Drop
----------------------------------------------------------------
local function setupDropShortcut()
	ContextActionService:BindAction("ACM_Drop", function(_: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end

		local list = _G.ACM_STATE.carriedList or {}
		if #list > 0 then
			local first = list[1]
			safeFireCarryRemote("Stop", {targetId = first.id})
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
end

----------------------------------------------------------------
-- Character Respawn Handler
----------------------------------------------------------------
local function setupCharacterHandlers()
	local function onCharacterAdded(char: Model)
		State.carriedIds = {}
		resetPassengerState()
		_G.ACM_STATE.carriedList = {}
		State.currentCarryMode = nil

		stopCarryAnimLocal()
		stopSitAnimLocal()

		destroyUI()
		zoomCameraOut()
		State.panelOpen = false

		destroyMiniRows()

		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.Died:Connect(function()
				State.carriedIds = {}
				resetPassengerState()
				_G.ACM_STATE.carriedList = {}
				State.currentCarryMode = nil

				stopCarryAnimLocal()
				stopSitAnimLocal()

				destroyUI()
				zoomCameraOut()
				State.panelOpen = false
				destroyMiniRows()
			end)
		end
	end

	if Player.Character then
		onCharacterAdded(Player.Character)
	end

	Player.CharacterAdded:Connect(onCharacterAdded)
end

----------------------------------------------------------------
-- Player Removing Handler (Prune)
----------------------------------------------------------------
local function setupPlayerRemovingHandler()
	Players.PlayerRemoving:Connect(function(p: Player)
		local wasCarried = State.carriedIds[p.UserId]

		if State.carriedIds[p.UserId] then
			State.carriedIds[p.UserId] = nil
		end

		local list = _G.ACM_STATE.carriedList or {}
		local newList = {}
		local changed = false
		for _, it in ipairs(list) do
			if it.id ~= p.UserId then
				table.insert(newList, it)
			else
				changed = true
			end
		end
		_G.ACM_STATE.carriedList = newList

		if changed and #newList == 0 then
			stopCarryAnimLocal()
			State.currentCarryMode = nil
		end

		if State.carrierId and p.UserId == State.carrierId then
			resetPassengerState()
			stopSitAnimLocal()
			destroyMiniRows()
		end

		if State.currentTarget == p then
			destroyUI()
			zoomCameraOut()
			State.panelOpen = false
		end

		if typeof(refreshMiniRows) == "function" then refreshMiniRows() end

		if wasCarried and miniGui then
			local listPanel = miniGui:FindFirstChild("ACM_CarryListPanel")
			if listPanel and listPanel.Parent then
				updateCarryListPanel(listPanel)
			end
		end
	end)
end

----------------------------------------------------------------
-- Distance Monitor (Auto-close jika terlalu jauh)
----------------------------------------------------------------
local function setupDistanceMonitor()
	RunService.Heartbeat:Connect(function()
		if not State.panelOpen or not State.currentTarget then return end

		if State.isRemoteView then return end 

		local myChar = Player.Character
		local targetChar = State.currentTarget.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local tHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

		if not (myHRP and tHRP) then
			destroyUI()
			zoomCameraOut()
			State.panelOpen = false
			return
		end

		local dist = (myHRP.Position - tHRP.Position).Magnitude

		--if dist > 60 then
		--	destroyUI()
		--	zoomCameraOut()
		--	State.panelOpen = false
		--end
	end)
end

----------------------------------------------------------------
-- Passenger Watchdog (Auto-lepas jika carrier hilang)
----------------------------------------------------------------
local function setupPassengerWatchdog()
	local lastCarrierSeen = 0

	RunService.Heartbeat:Connect(function()
		if not State.isPassenger or not State.carrierId then return end

		local carrierPlayer = Players:GetPlayerByUserId(State.carrierId)
		if not carrierPlayer or not carrierPlayer.Character then
			if os.clock() - lastCarrierSeen > 2.5 then
				resetPassengerState()
				stopSitAnimLocal()
				destroyMiniRows()
			end
			return
		end

		local myChar = Player.Character
		local carrierChar = carrierPlayer.Character
		local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
		local cHRP = carrierChar and carrierChar:FindFirstChild("HumanoidRootPart")

		if myHRP and cHRP then
			local dist = (myHRP.Position - cHRP.Position).Magnitude
			if dist < 60 then
				lastCarrierSeen = os.clock()
			elseif os.clock() - lastCarrierSeen > 2.5 then
				resetPassengerState()
				stopSitAnimLocal()
				destroyMiniRows()
			end
		else
			lastCarrierSeen = 0
		end
	end)
end

----------------------------------------------------------------
-- Cleanup on Teleport/Place Change
----------------------------------------------------------------
local function setupCleanup()
	PlayerGui.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			destroyUI()
			zoomCameraOut()
			State.panelOpen = false
			destroyMiniRows()

			stopCarryAnimLocal()
			stopSitAnimLocal()
		end
	end)
end

----------------------------------------------------------------
-- Status Change Handler (Update UI jika panel terbuka)
----------------------------------------------------------------
local function setupStatusMonitor()
	-- Pencarian rekursif tiap frame bikin lag; cukup cek 4x per detik dan update kalau berubah
	local elapsed = 0
	local lastStatus = nil
	RunService.Heartbeat:Connect(function(dt)
		if not State.panelOpen or not State.currentTarget or not mainPanel then
			lastStatus = nil
			return
		end

		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0

		local newStatus = State.currentTarget:GetAttribute("Status") or "nothing to say.."
		if newStatus == lastStatus then return end

		local statusLabel = mainPanel:FindFirstChild("Status", true)
		if statusLabel and statusLabel:IsA("TextLabel") then
			statusLabel.Text = string.format('"%s"', newStatus)
			lastStatus = newStatus
		end
	end)
end

----------------------------------------------------------------
-- Sound Effects (Optional Enhancement)
----------------------------------------------------------------
local function createSoundEffect(soundId: string, volume: number?): Sound?
	local success, sound = pcall(function()
		local s = Instance.new("Sound")
		s.SoundId = soundId
		s.Volume = volume or 0.3
		s.Parent = SoundService
		return s
	end)
	return success and sound or nil
end

local function playOpenSound()
	local sound = createSoundEffect("rbxassetid://6895079853", 0.4)
	if sound then
		sound:Play()
		task.delay(2, function()
			sound:Destroy()
		end)
	end
end

local function playCloseSound()
	local sound = createSoundEffect("rbxassetid://6895079853", 0.25)
	if sound then
		sound:Play()
		task.delay(2, function()
			sound:Destroy()
		end)
	end
end

-- Override panel show/hide dengan sound
local originalShowPanel = showPanel
showPanel = function(target: Player, isPrompt: boolean, promptName: string?)
	playOpenSound()
	originalShowPanel(target, isPrompt, promptName)
end

local originalDestroyUI = destroyUI
destroyUI = function()
	playCloseSound()
	originalDestroyUI()
end

----------------------------------------------------------------
-- Visual Polish: Particle Effects on Highlight (Optional)
----------------------------------------------------------------
local function addParticleEffect(target: Player)
	pcall(function()
		local char = target.Character
		if not char then return end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 255, 255)
		sparkles.Parent = hrp

		task.delay(2, function()
			sparkles:Destroy()
		end)
	end)
end

local originalHighlightTarget = highlightTarget
highlightTarget = function(target: Player)
	originalHighlightTarget(target)
	addParticleEffect(target)
end

----------------------------------------------------------------
-- Mobile Optimization
----------------------------------------------------------------
local function setupMobileOptimization()
	if not IS_MOBILE then return end
end


----------------------------------------------------------------
-- Debug Mode (Toggle dengan Ctrl+Shift+D)
----------------------------------------------------------------
local DEBUG_MODE = false

local function toggleDebugMode()
	DEBUG_MODE = not DEBUG_MODE
	print("[ACM] Debug Mode:", DEBUG_MODE and "ON" or "OFF")

	if DEBUG_MODE then
		-- Show debug info
		local debugLabel = Instance.new("TextLabel")
		debugLabel.Name = "ACM_Debug"

		debugLabel.Size = UDim2.new(0, 300 * BASE_SCALE, 0, 150 * BASE_SCALE)
		debugLabel.Position = UDim2.new(0, 10 * BASE_SCALE, 0, 10 * BASE_SCALE)
		debugLabel.BackgroundColor3 = Color3.new(0, 0, 0)
		debugLabel.BackgroundTransparency = 0.5
		debugLabel.TextColor3 = Color3.new(1, 1, 1)
		debugLabel.Font = Enum.Font.Code

		debugLabel.TextSize = 14 * BASE_SCALE
		debugLabel.TextXAlignment = Enum.TextXAlignment.Left
		debugLabel.TextYAlignment = Enum.TextYAlignment.Top
		debugLabel.Parent = PlayerGui

		RunService.Heartbeat:Connect(function()
			if not DEBUG_MODE or not debugLabel.Parent then return end

			local carriedCount = 0
			for _ in pairs(State.carriedIds) do
				carriedCount = carriedCount + 1
			end

			local scaleInfo = string.format("Scale: %.2f (ResY: %d)",
				BASE_SCALE,
				getCamera() and getCamera().ViewportSize.Y or 0
			)

			debugLabel.Text = string.format(
				"[ACM Debug] - %s\nPanel Open: %s\nCarrier ID: %s\nPassenger: %s\nCarried Count: %d\nTarget: %s\nCarry Mode: %s",
				scaleInfo,
				tostring(State.panelOpen),
				tostring(State.carrierId or "nil"),
				tostring(State.isPassenger),
				carriedCount,
				State.currentTarget and State.currentTarget.Name or "nil",
				tostring(State.currentCarryMode or "nil")
			)
		end)
	else
		local debugLabel = PlayerGui:FindFirstChild("ACM_Debug")
		if debugLabel then
			debugLabel:Destroy()
		end
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.D then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			toggleDebugMode()
		end
	end
end)

----------------------------------------------------------------
-- Notification Handler (Listener)
----------------------------------------------------------------
local function setupNotificationListener()
	local remote = Events:WaitForChild("SendLikeNotification", 5)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(likerName)
			StarterGui:SetCore("SendNotification", {
				Title = "New Like!",
				Text = likerName .. " liked your profile ❤️",
				Icon = "rbxassetid://110760134428621", -- Icon Love
				Duration = 5
			})

			playClickSound() 
		end)
	end
end

----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------
local function initialize()

	-- Setup all handlers
	setupCarryHandlers()
	setupInputHandler()
	setupDropShortcut()
	setupCharacterHandlers()
	setupPlayerRemovingHandler()
	setupDistanceMonitor()
	setupPassengerWatchdog()
	setupCleanup()
	setupStatusMonitor()
	setupMobileOptimization()

	-- Panggil Listener
	setupNotificationListener()

	-- Store default camera FOV
	local cam = getCamera()
	if cam then
		State.defaultFOV = cam.FieldOfView
	end
end

-- Listener untuk membuka kembali ACM dari TipJar
BackToACMEvent.Event:Connect(function(previousTarget)
	if previousTarget and previousTarget:IsA("Player") then
		-- Beri jeda sedikit agar transisi halus
		task.wait(0.1)
		showPanel(previousTarget, false, nil)
	end
end)

-- Start
task.defer(initialize)

----------------------------------------------------------------
-- Global API (untuk external scripts)
----------------------------------------------------------------
_G.ACM_API = {
	showPanel = function(target, isPrompt, promptName, isRemote)
		showPanel(target, isPrompt, promptName, isRemote)
	end,
	closePanel = function()
		destroyUI()
		zoomCameraOut()
		State.panelOpen = false
	end,
	getState = function()
		return {
			isPassenger = State.isPassenger,
			carrierId = State.carrierId,
			carriedIds = State.carriedIds,
			panelOpen = State.panelOpen,
			carryMode = State.currentCarryMode,
		}
	end,
	toggleDebug = toggleDebugMode,
}