-- ANNOUNCEMENT - TOPBAR ICON (TopbarPlus Integration)
-- Place this in StarterPlayerScripts
-- Requires TopbarPlus/Icon module in ReplicatedStorage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Wait for TopbarPlus Icon module
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

local AnnouncementEvent = ReplicatedStorage:WaitForChild("GlobalAnnouncementEvent")
local AnnouncementRequest = ReplicatedStorage:WaitForChild("AnnouncementRequest")
local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AnnouncementGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, 0)
container.BackgroundTransparency = 1
container.Parent = screenGui

local PFP_SIZE = 24
local messageDuration = 6
local spacing = 0.07
local startingY = 0.1
local activeMessages = {}
local DEFAULT_PFP = ""

local function createAnnouncement(displayName, prefix, message)
	local messageIndex = #activeMessages + 1
	local yPos = startingY + (messageIndex - 1) * spacing

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0.6, 0, 0.05, 0)
	holder.Position = UDim2.new(0.5, 0, yPos, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = container

	local pfp = Instance.new("ImageLabel")
	pfp.Size = UDim2.new(0,PFP_SIZE,0,PFP_SIZE)
	pfp.AnchorPoint = Vector2.new(0,0.5)
	pfp.Position = UDim2.new(0,0,0.5,0)
	pfp.BackgroundTransparency = 1
	pfp.Image = DEFAULT_PFP
	pfp.Visible = true
	pfp.Parent = holder

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 1
	bg.Parent = holder

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(0, 0, 0))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.9, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = bg

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.new(0, 20, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 18
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTransparency = 1
	label.RichText = true
	label.Parent = holder

	label.Text = string.format("%s%s: %s", displayName, prefix or "", message)
	holder.Size = UDim2.new(0, label.TextBounds.X + 60, 0.07, 0)

	table.insert(activeMessages, holder)

	TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
	TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 0}):Play()

	task.delay(messageDuration, function()
		local fadeBg = TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1})
		local fadeText = TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1})
		fadeBg:Play()
		fadeText:Play()
		fadeText.Completed:Wait()

		local indexToRemove = table.find(activeMessages, holder)
		if indexToRemove then
			table.remove(activeMessages, indexToRemove)
			holder:Destroy()
			for i = indexToRemove, #activeMessages do
				local targetY = startingY + (i - 1) * spacing
				TweenService:Create(activeMessages[i], TweenInfo.new(0.3), {
					Position = UDim2.new(0.5, 0, targetY, 0)
				}):Play()
			end
		end
	end)
end

AnnouncementEvent.OnClientEvent:Connect(function(data)
	if typeof(data) == "table" and data.displayName and data.message then
		createAnnouncement(data.displayName, data.prefix, data.message)
	end
end)

---------------------------------------------------------------------
-- 🔥 ADMIN PANEL – TOPBAR ICON (TopbarPlus Integration)
---------------------------------------------------------------------
local function createAdminPanel()

	local Admins = {
		["Duwataw"] = true
	}

	local isStudio = RunService:IsStudio()
	local isWhitelisted = Admins[player.Name] == true

	if not (isStudio or isWhitelisted) then
		return
	end

	local adminGui = Instance.new("ScreenGui")
	adminGui.Name = "AnnouncementAdmin"
	adminGui.ResetOnSpawn = false
	adminGui.IgnoreGuiInset = true
	adminGui.Parent = player:WaitForChild("PlayerGui")

	-- ===== PANEL =====
	local panel = Instance.new("Frame")
	panel.Visible = false
	panel.Size = UDim2.fromOffset(440, 220)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = Color3.fromRGB(15,15,15)
	panel.BorderSizePixel = 0
	panel.Parent = adminGui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0,10)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Thickness = 1
	panelStroke.Color = Color3.fromRGB(255,255,255)
	panelStroke.Transparency = 0.7
	panelStroke.Parent = panel

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = "📢 Send Announcement"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.TextSize = 20
	title.Size = UDim2.new(1, -10, 0, 24)
	title.Parent = panel

	local box = Instance.new("TextBox")
	box.PlaceholderText = "Type announcement text..."
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Font = Enum.Font.FredokaOne
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.PlaceholderColor3 = Color3.fromRGB(210, 210, 210)
	box.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	box.BorderSizePixel = 0
	box.TextSize = 18
	box.TextWrapped = true
	box.MultiLine = true
	box.Size = UDim2.new(1, -10, 0, 90)
	box.Position = UDim2.fromOffset(0, 28)
	box.Parent = panel

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 8)
	boxCorner.Parent = box

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.fromOffset(0, 128)
	row.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local function styleButton(btn)
		btn.Font = Enum.Font.FredokaOne
		btn.TextSize = 18
		btn.TextColor3 = Color3.fromRGB(255,255,255)
		btn.BackgroundColor3 = Color3.fromRGB(30,30,30)
		btn.BorderSizePixel = 0

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0,8)
		c.Parent = btn

		local s = Instance.new("UIStroke")
		s.Color = Color3.fromRGB(255,255,255)
		s.Transparency = 0.6
		s.Thickness = 1
		s.Parent = btn
	end

	-- ===== TOPBAR ICON (TopbarPlus) =====
	local announceIcon = Icon.new()
		:setLabel("📢")

	local function send(mode)
		local text = string.gsub(box.Text, "^%s*(.-)%s*$", "%1")
		if #text == 0 then return end
		AnnouncementRequest:FireServer(mode, text)
		box.Text = ""
		announceIcon:deselect()
	end

	local serverBtn = Instance.new("TextButton")
	serverBtn.Text = "Server"
	serverBtn.Size = UDim2.fromOffset(120, 40)
	serverBtn.Parent = row
	styleButton(serverBtn)
	serverBtn.MouseButton1Click:Connect(function() send("server") end)

	local globalBtn = Instance.new("TextButton")
	globalBtn.Text = "Global"
	globalBtn.Size = UDim2.fromOffset(120, 40)
	globalBtn.Parent = row
	styleButton(globalBtn)
	globalBtn.MouseButton1Click:Connect(function() send("global") end)

	-- Toggle panel when icon is selected/deselected
	announceIcon.selected:Connect(function()
		panel.Visible = true
	end)

	announceIcon.deselected:Connect(function()
		panel.Visible = false
	end)

	
end

createAdminPanel()