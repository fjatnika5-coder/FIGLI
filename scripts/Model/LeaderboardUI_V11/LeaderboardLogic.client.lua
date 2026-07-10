--!strict

-- =========================
-- SERVICE DECLARATION
-- =========================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- =========================
-- GUI REFERENCES
-- =========================
local ScreenGui = script.Parent
local MainFrame = ScreenGui:WaitForChild("MainFrame")
local Scroll = MainFrame:WaitForChild("List")
local SidePanel = MainFrame:WaitForChild("SidePanel")
local Template = ScreenGui:WaitForChild("Template")
local Header = MainFrame:WaitForChild("Header")
local SearchBox = Header:WaitForChild("SearchBox")
local StatTitle = Header:WaitForChild("StatTitle")
local SwitchBtn = Header:WaitForChild("SwitchButton")

local LocalPlayer = Players.LocalPlayer

-- =========================
-- DISABLE DEFAULT PLAYERLIST
-- =========================
task.spawn(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
end)

-- =========================
-- 🔥 POSITION (KANAN ATAS, DI BAWAH FAB)
-- =========================
MainFrame.AnchorPoint = Vector2.new(1, 0)

local FAB_OFFSET_Y
if UserInputService.TouchEnabled then
	FAB_OFFSET_Y = 70   -- 📱 mobile
else
	FAB_OFFSET_Y = 65   -- 🖥 PC (TIDAK TURUN)
end

local function updatePosition()
	MainFrame.Position = UDim2.new(
		1, -12,
		0, FAB_OFFSET_Y
	)
end

updatePosition()

if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")
		:Connect(updatePosition)
end

-- =========================
-- 🔥 UISCALE (ANTI NIL, FIX ERROR)
-- =========================
local UIScale = MainFrame:FindFirstChildWhichIsA("UIScale")
if not UIScale then
	UIScale = Instance.new("UIScale")
	UIScale.Name = "AutoScale"
	UIScale.Scale = 1
	UIScale.Parent = MainFrame
end

local function applyFABScale()
	if UserInputService.TouchEnabled then
		-- 📱 MOBILE
		UIScale.Scale = 0.70
	else
		-- 🖥 PC
		UIScale.Scale = 1.2
	end
end

applyFABScale()

if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")
		:Connect(applyFABScale)
end

-- =========================
-- STATE
-- =========================
local COLOR_HIGHLIGHT = Color3.fromHex("#326ACA")
local COLOR_ROW_BG = Color3.fromRGB(40, 40, 45)

local isAnimating = false
local isVisible = false
local currentSelection = nil

-- =========================
-- TOGGLE UI (SLIDE DARI KANAN)
-- =========================
local POS_SHOWN = MainFrame.Position
local POS_HIDDEN = POS_SHOWN + UDim2.new(0.4, 0, 0, 0)

MainFrame.Position = POS_HIDDEN
MainFrame.Visible = false

local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function ToggleUI(force)
	if isAnimating then return end

	local target = force ~= nil and force or not isVisible
	if target == isVisible then return end

	isAnimating = true

	if target then
		MainFrame.Visible = true
		MainFrame.Position = POS_HIDDEN

		TweenService:Create(MainFrame, TWEEN_INFO, {
			Position = POS_SHOWN
		}):Play()

		task.delay(0.3, function()
			isVisible = true
			isAnimating = false
		end)
	else
		TweenService:Create(MainFrame, TWEEN_INFO, {
			Position = POS_HIDDEN
		}):Play()

		task.delay(0.3, function()
			MainFrame.Visible = false
			isVisible = false
			isAnimating = false
			SidePanel.Visible = false
			currentSelection = nil
		end)
	end
end

-- =========================
-- STATS LOGIC
-- =========================
local StatsModes = {"Likes", "Playtime"}
local CurrentStatIndex = 1

local function FormatTime(seconds)
	seconds = tonumber(seconds) or 0
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm", m)
	end
	return seconds .. "s"
end

local function GetRealStat(player, stat)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(stat)
	return v and v.Value or 0
end

local function UpdateStats()
	local mode = StatsModes[CurrentStatIndex]
	StatTitle.Text = mode == "Playtime" and "Time Played" or mode

	for _, row in ipairs(Scroll:GetChildren()) do
		if row:IsA("TextButton") then
			local p = Players:FindFirstChild(row.Name)
			local label = row:FindFirstChild("StatValue")
			if p and label then
				local v = GetRealStat(p, mode)
				label.Text = mode == "Playtime"
					and FormatTime(v)
					or (v .. " ❤️")
			end
		end
	end
end

SwitchBtn.MouseButton1Click:Connect(function()
	CurrentStatIndex = (CurrentStatIndex % #StatsModes) + 1
	UpdateStats()
end)

task.spawn(function()
	while true do
		if MainFrame.Visible then
			UpdateStats()
		end
		task.wait(1)
	end
end)

-- =========================
-- PLAYER ROWS
-- =========================
local function ShowSidePanel(player, source)
	if currentSelection == player.Name then
		SidePanel.Visible = false
		currentSelection = nil
		return
	end

	currentSelection = player.Name
	SidePanel.Fullname.Text = player.DisplayName
	SidePanel.Username.Text = "@" .. player.Name
	SidePanel.BigAvatar.Image =
		"rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"

	local y = source.AbsolutePosition.Y - MainFrame.AbsolutePosition.Y
	SidePanel.Position = UDim2.new(0, -SidePanel.Size.X.Offset - 6, 0, y)
	SidePanel.Visible = true
end

local function CreateRow(player, isLocal)
	if Scroll:FindFirstChild(player.Name) then return end

	local row = Template:Clone()
	row.Name = player.Name
	row.Parent = Scroll
	row.Visible = true

	row.PlayerName.Text = player.DisplayName
	row.Avatar.Image =
		"rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=48&h=48"

	row.BackgroundColor3 = isLocal and COLOR_HIGHLIGHT or COLOR_ROW_BG
	row.LayoutOrder = isLocal and -10 or 0

	row.MouseButton1Click:Connect(function()
		ShowSidePanel(player, row)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	CreateRow(p, p == LocalPlayer)
end

Players.PlayerAdded:Connect(function(p)
	CreateRow(p, p == LocalPlayer)
end)

Players.PlayerRemoving:Connect(function(p)
	local row = Scroll:FindFirstChild(p.Name)
	if row then row:Destroy() end
	if currentSelection == p.Name then SidePanel.Visible = false end
end)

-- =========================
-- SEARCH
-- =========================
SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = SearchBox.Text:lower()
	for _, row in ipairs(Scroll:GetChildren()) do
		if row:IsA("TextButton") then
			row.Visible =
				q == ""
				or row.Name:lower():find(q, 1, true)
				or row.PlayerName.Text:lower():find(q, 1, true)
		end
	end
end)

SidePanel.InspectButton.MouseButton1Click:Connect(function()
	if not currentSelection then return end

	local targetPlayer = Players:FindFirstChild(currentSelection)
	if not targetPlayer then return end

	local myChar = LocalPlayer.Character
	local targetChar = targetPlayer.Character
	if not myChar or not targetChar then return end

	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not myRoot or not targetRoot then return end

	-- teleport sedikit di samping target (biar ga nabrak)
	myRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
end)

-- =========================
-- GLOBAL API
-- =========================
_G.ToggleLeaderboardUI = ToggleUI
