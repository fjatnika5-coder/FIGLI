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

	-- Background pill
	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.AnchorPoint = Vector2.new(0.5, 0)
	bg.Position = UDim2.fromScale(0.5, 0.06)
	bg.Size = UDim2.fromScale(0.42, 0.068)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.35
	bg.BorderSizePixel = 0
	bg.ZIndex = 10
	bg.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 200, 230)
	stroke.Transparency = 0.5
	stroke.Parent = bg

	-- Status label ("Waiting for partner...")
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "StatusLabel"
	statusLbl.BackgroundTransparency = 1
	statusLbl.Size = UDim2.fromScale(1, 1)
	statusLbl.Font = Enum.Font.GothamBold
	statusLbl.TextScaled = true
	statusLbl.TextColor3 = Color3.fromRGB(255, 220, 240)
	statusLbl.Text = "Waiting for partner..."
	statusLbl.ZIndex = 11
	statusLbl.Visible = true
	statusLbl.Parent = bg

	local sc = Instance.new("UITextSizeConstraint")
	sc.MaxTextSize = 22
	sc.MinTextSize = 8
	sc.Parent = statusLbl

	-- Big countdown number (hidden by default)
	local countLbl = Instance.new("TextLabel")
	countLbl.Name = "CountLabel"
	countLbl.AnchorPoint = Vector2.new(0.5, 0.5)
	countLbl.Position = UDim2.fromScale(0.5, 0.5)
	countLbl.Size = UDim2.fromScale(1, 1)
	countLbl.BackgroundTransparency = 1
	countLbl.Font = Enum.Font.GothamBold
	countLbl.TextScaled = true
	countLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLbl.TextTransparency = 1
	countLbl.ZIndex = 12
	countLbl.Visible = false
	countLbl.Parent = bg

	local sc2 = Instance.new("UITextSizeConstraint")
	sc2.MaxTextSize = 36
	sc2.MinTextSize = 10
	sc2.Parent = countLbl

	-- UIScale for pop animation on countdown
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1
	uiScale.Parent = countLbl

	bg.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(bg, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.35 })
	fadeIn:Play()

	return gui
end

local function showWaiting()
	local gui = ensurePadGui()
	local bg = gui:FindFirstChild("BG")
	if not bg then return end
	local statusLbl = bg:FindFirstChild("StatusLabel")
	local countLbl  = bg:FindFirstChild("CountLabel")
	if statusLbl then
		statusLbl.Text = "Waiting for partner..."
		statusLbl.Visible = true
	end
	if countLbl then
		countLbl.Visible = false
		countLbl.TextTransparency = 1
	end
end

local function showCountdown(count)
	local gui = ensurePadGui()
	local bg = gui:FindFirstChild("BG")
	if not bg then return end
	local statusLbl = bg:FindFirstChild("StatusLabel")
	local countLbl  = bg:FindFirstChild("CountLabel")

	if statusLbl then statusLbl.Visible = false end
	if not countLbl then return end

	countLbl.Visible = true
	countLbl.Text = tostring(count)
	countLbl.TextTransparency = 0

	-- Pop animation per angka
	local sc = countLbl:FindFirstChildOfClass("UIScale")
	if sc then
		sc.Scale = 1.4
		if countdownTween then countdownTween:Cancel() end
		countdownTween = TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
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
		-- Show "Partner not found" briefly then hide
		local gui = ensurePadGui()
		local bg = gui and gui:FindFirstChild("BG")
		if bg then
			local statusLbl = bg:FindFirstChild("StatusLabel")
			local countLbl  = bg:FindFirstChild("CountLabel")
			if countLbl then countLbl.Visible = false end
			if statusLbl then
				statusLbl.Text = "Partner not found"
				statusLbl.Visible = true
			end
			task.delay(2, function()
				if padGui and padGui.Parent then
					showWaiting()
				end
			end)
		end
	elseif statusType == "Hide" then
		-- Player stepped off pad
		if padGui then
			local bg = padGui:FindFirstChild("BG")
			if bg then
				local tw = TweenService:Create(bg, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
				tw:Play()
				tw.Completed:Connect(function()
					destroyPadGui()
				end)
			else
				destroyPadGui()
			end
		end
	end
end)
