--!nonstrict
-- PhotoStoryClient: dengar StartStory/EndStory/PadStatus.
-- PadStatus: tampil UI "Waiting for partner..." / countdown 5-4-3-2-1.
-- StartStory: jalankan CutsceneRunner. EndStory: hentikan runner.

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")

local Modules        = script:WaitForChild("Modules")
local CutsceneRunner = require(Modules:WaitForChild("CutsceneRunner"))

local Remotes    = ReplicatedStorage:WaitForChild("PhotoStoryRemotes")
local StartStory = Remotes:WaitForChild("StartStory")
local EndStory   = Remotes:WaitForChild("EndStory")
local PadStatus  = Remotes:WaitForChild("PadStatus")

local LocalPlayer = Players.LocalPlayer
local activeRunner = nil

-- =====================================================================
-- Pad Status UI (Waiting / Countdown)
-- =====================================================================

local padGui = nil        -- ScreenGui yang berisi UI status pad
local countdownTween = nil

local function destroyPadGui()
	if countdownTween then
		countdownTween:Cancel()
		countdownTween = nil
	end
	if padGui then
		padGui:Destroy()
		padGui = nil
	end
end

local function ensurePadGui()
	if padGui and padGui.Parent then return padGui end
	destroyPadGui()

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PhotoStoryPadStatus"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	padGui = gui

	-- ---- Waiting pill (atas tengah) ----
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.07)
	pill.Size = UDim2.fromScale(0.34, 0.06)
	pill.BackgroundColor3 = Color3.fromRGB(28, 24, 32)
	pill.BackgroundTransparency = 1
	pill.BorderSizePixel = 0
	pill.ZIndex = 10
	pill.Parent = gui

	local pillGrad = Instance.new("UIGradient")
	pillGrad.Color = ColorSequence.new(Color3.fromRGB(48, 36, 52), Color3.fromRGB(26, 22, 30))
	pillGrad.Rotation = 90
	pillGrad.Parent = pill

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = pill

	local ps = Instance.new("UIStroke")
	ps.Thickness = 1.6
	ps.Color = Color3.fromRGB(255, 200, 225)
	ps.Transparency = 0.45
	ps.Parent = pill

	-- titik kecil indikator + label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = pill

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "StatusLabel"
	statusLbl.BackgroundTransparency = 1
	statusLbl.Size = UDim2.fromScale(1, 1)
	statusLbl.Font = Enum.Font.GothamMedium
	statusLbl.TextScaled = true
	statusLbl.TextColor3 = Color3.fromRGB(255, 232, 244)
	statusLbl.Text = "Waiting for partner"
	statusLbl.ZIndex = 11
	statusLbl.Parent = pill

	local sc = Instance.new("UITextSizeConstraint")
	sc.MaxTextSize = 18
	sc.MinTextSize = 8
	sc.Parent = statusLbl

	-- ---- Countdown ring (tengah layar) ----
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.42)
	ring.Size = UDim2.fromScale(0.16, 0.16)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ring.BackgroundColor3 = Color3.fromRGB(26, 22, 30)
	ring.BackgroundTransparency = 0.2
	ring.BorderSizePixel = 0
	ring.Visible = false
	ring.ZIndex = 12
	ring.Parent = gui

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = ring

	local rs = Instance.new("UIStroke")
	rs.Thickness = 3
	rs.Color = Color3.fromRGB(255, 190, 220)
	rs.Transparency = 0.1
	rs.Parent = ring

	local countLbl = Instance.new("TextLabel")
	countLbl.Name = "CountLabel"
	countLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	countLbl.Position = UDim2.fromScale(0.5, 0.5)
	countLbl.Size = UDim2.fromScale(0.9, 0.9)
	countLbl.BackgroundTransparency = 1
	countLbl.Font = Enum.Font.FredokaOne
	countLbl.TextScaled = true
	countLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLbl.Text = "5"
	countLbl.ZIndex = 13
	countLbl.Parent = ring

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = ring

	-- fade in pill
	local fadeIn = TweenService:Create(pill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.15 })
	fadeIn:Play()

	return gui
end

local function showWaiting()
	local gui = ensurePadGui()
	local pill = gui:FindFirstChild("Pill")
	local ring = gui:FindFirstChild("Ring")
	if pill then
		pill.Visible = true
		local lbl = pill:FindFirstChild("StatusLabel")
		if lbl then lbl.Text = "Waiting for partner" end
	end
	if ring then ring.Visible = false end
end

local function showCountdown(count)
	local gui = ensurePadGui()
	local pill = gui:FindFirstChild("Pill")
	local ring = gui:FindFirstChild("Ring")
	if pill then
		pill.Visible = true
		local lbl = pill:FindFirstChild("StatusLabel")
		if lbl then lbl.Text = "Get ready" end
	end
	if not ring then return end

	ring.Visible = true
	local countLbl = ring:FindFirstChild("CountLabel")
	if countLbl then countLbl.Text = tostring(count) end

	-- pop per angka
	local s = ring:FindFirstChildOfClass("UIScale")
	if s then
		s.Scale = 1.35
		if countdownTween then countdownTween:Cancel() end
		countdownTween = TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		countdownTween:Play()
	end
end

-- =====================================================================
-- Cutscene runner
-- =====================================================================

local function stopActive()
	if activeRunner then
		local r = activeRunner
		activeRunner = nil
		r:Stop()
	end
end

StartStory.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or not (payload.GirlUserId and payload.BoyUserId) then return end
	destroyPadGui()
	stopActive()

	local runner = CutsceneRunner.new()
	activeRunner = runner

	task.spawn(function()
		runner:Run(payload, function()
			if activeRunner == runner then activeRunner = nil end
			pcall(function() EndStory:FireServer(payload.SessionId) end)
		end)
	end)
end)

EndStory.OnClientEvent:Connect(function()
	stopActive()
end)

PadStatus.OnClientEvent:Connect(function(statusType, data)
	if statusType == "Waiting" then
		showWaiting()
	elseif statusType == "Countdown" then
		showCountdown(data)
	elseif statusType == "Cancel" then
		-- "Partner not found" sebentar lalu balik waiting
		local gui = ensurePadGui()
		local pill = gui and gui:FindFirstChild("Pill")
		local ring = gui and gui:FindFirstChild("Ring")
		if ring then ring.Visible = false end
		if pill then
			pill.Visible = true
			local lbl = pill:FindFirstChild("StatusLabel")
			if lbl then lbl.Text = "Partner not found" end
			task.delay(2, function()
				if padGui and padGui.Parent then showWaiting() end
			end)
		end
	elseif statusType == "Hide" then
		-- Player keluar pad
		if padGui then
			local pill = padGui:FindFirstChild("Pill")
			if pill then
				local tw = TweenService:Create(pill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
				tw:Play()
				tw.Completed:Connect(function() destroyPadGui() end)
			else
				destroyPadGui()
			end
		end
	end
end)
