--!strict
-- Lokasi: LocalScript di dalam ScreenGui AnimationsUI (StarterGui)
-- Struktur GUI yang dibutuhkan: MainFrame > UIScale, SearchContainer.SearchBox,
-- Content.ListFrame, Content.Sidebar (TabPose/TabDance/TabFav),
-- Footer.SpeedLabel, Footer.Frame (MinusBtn/PlusBtn), Header.CloseBtn

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local GUI = script.Parent
local Main = GUI:WaitForChild("MainFrame")
local UIScale = Main:WaitForChild("UIScale")

-- References UI
local SearchBox = Main:WaitForChild("SearchContainer"):WaitForChild("SearchBox")
local ListFrame = Main:WaitForChild("Content"):WaitForChild("ListFrame")
local Sidebar = Main:WaitForChild("Content"):WaitForChild("Sidebar")
local SpeedLabel = Main:WaitForChild("Footer"):WaitForChild("SpeedLabel")
local MinusBtn = Main:WaitForChild("Footer"):WaitForChild("Frame"):WaitForChild("MinusBtn")
local PlusBtn = Main:WaitForChild("Footer"):WaitForChild("Frame"):WaitForChild("PlusBtn")
local CloseBtn = Main:WaitForChild("Header"):WaitForChild("CloseBtn")

local Tabs = {
	Pose = Sidebar:WaitForChild("TabPose"),
	Dance = Sidebar:WaitForChild("TabDance"),
	Fav = Sidebar:WaitForChild("TabFav")
}

local FAV_ICON_ID = "rbxassetid://132423159479381"
local COLORS = {
	IDLE = Color3.fromRGB(18, 18, 18),
	ACTIVE = Color3.fromRGB(45, 45, 45),
	TEXT_IDLE = Color3.fromRGB(150, 150, 150),
	TEXT_ACTIVE = Color3.fromRGB(255, 255, 255)
}

-- Batas speed HARUS sama dengan clamp server (AnimationServer: 0.1 - 3.0)
local SPEED_MIN = 0.1
local SPEED_MAX = 3.0

-- Remotes
local Events = ReplicatedStorage:WaitForChild("EventsACMS")
local UpdateAnim = Events:WaitForChild("UpdateAnimation")
local UpdateSpeed = Events:FindFirstChild("UpdateAnimationSpeed")
local FavoritesGet = Events:WaitForChild("FavoritesGet")
local FavoritesSet = Events:WaitForChild("FavoritesSet")
local RequestSync = Events:WaitForChild("RequestSync")

----------------------------------------------------
-- SYNC OVERLAY
----------------------------------------------------
local SyncOverlay = Instance.new("Frame")
SyncOverlay.Name = "SyncOverlay"
SyncOverlay.Size = UDim2.fromScale(1, 1)
SyncOverlay.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SyncOverlay.BackgroundTransparency = 0.1
SyncOverlay.ZIndex = 100
SyncOverlay.Visible = false
SyncOverlay.Parent = Main

local ovCorner = Instance.new("UICorner")
ovCorner.CornerRadius = UDim.new(0, 8)
ovCorner.Parent = SyncOverlay

local SyncText = Instance.new("TextLabel")
SyncText.Size = UDim2.new(1, 0, 0, 40)
SyncText.Position = UDim2.new(0, 0, 0.4, 0)
SyncText.BackgroundTransparency = 1
SyncText.Text = "SYNC MODE ACTIVE"
SyncText.Font = Enum.Font.GothamBold
SyncText.TextColor3 = Color3.fromRGB(255, 255, 255)
SyncText.ZIndex = 101
SyncText.Parent = SyncOverlay

local SyncSubText = Instance.new("TextLabel")
SyncSubText.Size = UDim2.new(1, 0, 0, 20)
SyncSubText.Position = UDim2.new(0, 0, 0.4, 30)
SyncSubText.BackgroundTransparency = 1
SyncSubText.Text = " "
SyncSubText.Font = Enum.Font.Gotham
SyncSubText.TextColor3 = Color3.fromRGB(150, 150, 150)
SyncSubText.ZIndex = 101
SyncSubText.Parent = SyncOverlay

local StopSyncBtn = Instance.new("TextButton")
StopSyncBtn.Size = UDim2.new(0, 140, 0, 44)
StopSyncBtn.Position = UDim2.new(0.5, 0, 0.65, 0)
StopSyncBtn.AnchorPoint = Vector2.new(0.5, 0.5)
StopSyncBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
StopSyncBtn.Text = "STOP SYNC"
StopSyncBtn.Font = Enum.Font.GothamBold
StopSyncBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StopSyncBtn.AutoButtonColor = true
StopSyncBtn.ZIndex = 102
StopSyncBtn.Parent = SyncOverlay

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = StopSyncBtn

----------------------------------------------------
-- DYNAMIC SCALE
----------------------------------------------------
local IS_MOBILE = UserInputService.TouchEnabled

local function getCamera()
	return Workspace.CurrentCamera
end

local function getDynamicScale()
	if not IS_MOBILE then
		return 1.0
	end

	local cam = getCamera()
	if not cam then return 1.0 end

	local vp = cam.ViewportSize
	local viewportY = vp.Y
	local shortestSide = math.min(vp.X, vp.Y)

	local MOBILE_BASE = 0.78

	local base
	if viewportY >= 1800 then
		base = 0.88 * MOBILE_BASE
	elseif viewportY >= 1200 then
		base = 0.95 * MOBILE_BASE
	elseif viewportY >= 900 then
		base = 1.05 * MOBILE_BASE
	else
		base = 1.15 * MOBILE_BASE
	end

	if shortestSide < 650 then
		return base * 1.45
	elseif shortestSide < 900 then
		return base * 1.28
	else
		return base * 1.15
	end
end

-- Simpan size asli SEKALI supaya width boost tidak menggandakan diri
-- kalau updateScale dipanggil lebih dari sekali.
local originalMainSize = Main.Size

local function updateScale()
	UIScale.Scale = getDynamicScale()

	if IS_MOBILE then
		local cam = getCamera()
		if cam then
			local vp = cam.ViewportSize
			local shortestSide = math.min(vp.X, vp.Y)

			local widthBoost = 1
			if shortestSide < 650 then
				widthBoost = 1.18
			elseif shortestSide < 900 then
				widthBoost = 1.12
			else
				widthBoost = 1.06
			end

			Main.Size = UDim2.new(
				originalMainSize.X.Scale * widthBoost,
				originalMainSize.X.Offset,
				originalMainSize.Y.Scale,
				originalMainSize.Y.Offset
			)
		end
	end
end

----------------------------------------------------
-- SYNC STATUS
----------------------------------------------------
local function checkSyncStatus()
	local syncedId = Player:GetAttribute("syncedPlayerId")

	if syncedId and syncedId > 0 then
		SyncOverlay.Visible = true
		SearchBox.Text = ""
	else
		SyncOverlay.Visible = false
	end
end

Player:GetAttributeChangedSignal("syncedPlayerId"):Connect(checkSyncStatus)

StopSyncBtn.MouseButton1Click:Connect(function()
	Player:SetAttribute("syncedPlayerId", nil)
	RequestSync:FireServer(nil)
end)

----------------------------------------------------
-- DATA
----------------------------------------------------
local AnimationsData = {}
local PosesData = {}

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if Shared then
	local AnimMod = Shared:WaitForChild("Animations", 5)
	if AnimMod then AnimationsData = require(AnimMod) end
	local PoseMod = Shared:WaitForChild("Poses", 5)
	if PoseMod then PosesData = require(PoseMod) end
end

local currentTab = "Pose"
local favorites = {}
local currentAnimId = nil
local speed = 1.0

----------------------------------------------------
-- HELPERS
----------------------------------------------------
local function getStdId(id)
	local n = string.match(id or "", "%d+")
	return n and ("rbxassetid://"..n) or id
end

local function loadFavorites()
	local success, data = pcall(function() return FavoritesGet:InvokeServer() end)
	if success and data then favorites = data else favorites = {} end
end

local function toggleFavorite(animId)
	local sid = getStdId(animId)
	local newState = not favorites[sid]
	if newState then favorites[sid] = true else favorites[sid] = nil end
	pcall(function() FavoritesSet:FireServer(sid, newState) end)
	return newState
end

local function getData()
	if currentTab == "Dance" then return AnimationsData end
	if currentTab == "Pose" then return PosesData end
	if currentTab == "Fav" then
		local res = {}
		for _, d in ipairs(AnimationsData) do if favorites[getStdId(d.animationId)] then table.insert(res, d) end end
		for _, d in ipairs(PosesData) do if favorites[getStdId(d.animationId)] then table.insert(res, d) end end
		return res
	end
	return {}
end

local function clearList()
	for _, child in ipairs(ListFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
end

local function rebuildList()
	clearList()
	local allData = getData()
	local query = string.lower(SearchBox.Text)

	local count = 0

	for _, item in ipairs(allData) do
		if query == "" or string.find(string.lower(item.name), query, 1, true) then
			count = count + 1
			local sid = getStdId(item.animationId)
			local isFav = favorites[sid] == true
			local isActive = (currentAnimId == sid)

			local btn = Instance.new("TextButton")
			btn.Name = "Item_" .. count
			btn.BackgroundColor3 = isActive and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(30, 30, 30)
			btn.Size = UDim2.new(1, 0, 0, 32)
			btn.AutoButtonColor = true
			btn.Text = ""
			btn.Parent = ListFrame

			local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = btn

			local lbl = Instance.new("TextLabel")
			lbl.Text = string.upper(item.name)
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 11
			lbl.TextColor3 = isActive and Color3.fromRGB(88, 130, 255) or Color3.fromRGB(255, 255, 255)
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(1, -30, 1, 0)
			lbl.Position = UDim2.new(0, 10, 0, 0)
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = btn

			local favIcon = Instance.new("ImageButton")
			favIcon.BackgroundTransparency = 1
			favIcon.Image = FAV_ICON_ID
			favIcon.ImageColor3 = isFav and Color3.fromRGB(255, 193, 71) or Color3.fromRGB(60, 60, 60)
			favIcon.Size = UDim2.fromOffset(16, 16)
			favIcon.AnchorPoint = Vector2.new(1, 0.5)
			favIcon.Position = UDim2.new(1, -8, 0.5, 0)
			favIcon.Parent = btn

			btn.MouseButton1Click:Connect(function()
				if currentAnimId == sid then
					if UpdateAnim then UpdateAnim:FireServer(sid) end
					currentAnimId = nil
				else
					if UpdateAnim then UpdateAnim:FireServer(sid) end
					currentAnimId = sid
				end
				rebuildList()
			end)

			favIcon.MouseButton1Click:Connect(function()
				local newVal = toggleFavorite(sid)
				favIcon.ImageColor3 = newVal and Color3.fromRGB(255, 193, 71) or Color3.fromRGB(60, 60, 60)
				if currentTab == "Fav" and not newVal then rebuildList() end
			end)
		end
	end
	ListFrame.CanvasSize = UDim2.new(0, 0, 0, count * 36)
end

local function updateTabs()
	for _, btn in pairs(Tabs) do
		btn.BackgroundColor3 = COLORS.IDLE
		btn.BackgroundTransparency = 1
		btn.ImageColor3 = COLORS.TEXT_IDLE
	end
	if Tabs[currentTab] then
		Tabs[currentTab].BackgroundColor3 = COLORS.ACTIVE
		Tabs[currentTab].BackgroundTransparency = 0
		Tabs[currentTab].ImageColor3 = COLORS.TEXT_ACTIVE
	end

	SearchBox.Text = ""
	rebuildList()
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(rebuildList)

Tabs.Pose.MouseButton1Click:Connect(function() currentTab = "Pose"; updateTabs() end)
Tabs.Dance.MouseButton1Click:Connect(function() currentTab = "Dance"; updateTabs() end)
Tabs.Fav.MouseButton1Click:Connect(function() currentTab = "Fav"; updateTabs() end)

local function changeSpeed(val)
	speed = math.clamp(val, SPEED_MIN, SPEED_MAX)
	SpeedLabel.Text = "SPEED " .. string.format("%.1f", speed) .. "x"
	if UpdateSpeed then UpdateSpeed:FireServer(speed) end
	local char = Player.Character
	if char then
		local hum = char:FindFirstChild("Humanoid")
		local animator = hum and hum:FindFirstChild("Animator")
		if animator then for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:AdjustSpeed(speed) end end
	end
end

MinusBtn.MouseButton1Click:Connect(function() changeSpeed(speed - 0.1) end)
PlusBtn.MouseButton1Click:Connect(function() changeSpeed(speed + 0.1) end)

CloseBtn.MouseButton1Click:Connect(function()
	local closeTween = TweenService:Create(UIScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
	closeTween:Play()
	closeTween.Completed:Connect(function() Main.Visible = false end)
end)

-- INIT
task.spawn(function()
	loadFavorites()
	updateTabs()
	updateScale()
	checkSyncStatus()
end)

----------------------------------------------------
-- PUBLIC API (dipanggil FastBar via _G)
----------------------------------------------------
local AnimationsUI = {}

function AnimationsUI.Open()
	if Main.Visible then return end
	Main.Visible = true

	local targetScale = getDynamicScale()
	UIScale.Scale = 0

	TweenService:Create(
		UIScale,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	):Play()
end

function AnimationsUI.Close()
	if not Main.Visible then return end

	local tw = TweenService:Create(
		UIScale,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0 }
	)

	tw:Play()
	tw.Completed:Once(function()
		Main.Visible = false
	end)
end

_G.AnimationsUI = AnimationsUI
