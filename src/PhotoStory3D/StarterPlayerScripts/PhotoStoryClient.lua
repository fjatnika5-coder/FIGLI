--!nonstrict
-- PhotoStoryClient: dengar StartStory / EndStory / PadStatus.
-- PadStatus -> TOAST kecil (notif), bukan background besar. Responsive (scale + AutomaticSize).
-- StartStory -> jalankan CutsceneRunner. EndStory -> stop runner.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Modules        = script:WaitForChild("Modules")
local CutsceneRunner = require(Modules:WaitForChild("CutsceneRunner"))

local Remotes    = ReplicatedStorage:WaitForChild("PhotoStoryRemotes")
local StartStory = Remotes:WaitForChild("StartStory")
local EndStory   = Remotes:WaitForChild("EndStory")
local PadStatus  = Remotes:WaitForChild("PadStatus")

local LocalPlayer  = Players.LocalPlayer
local activeRunner = nil

-- =====================================================================
-- Toast UI (notif kecil)
-- =====================================================================
local toastGui   = nil
local toastFrame = nil
local toastLabel = nil
local toastScale = nil
local popTween   = nil
local hideThread = nil

local function destroyToast()
	if popTween then popTween:Cancel(); popTween = nil end
	if hideThread then pcall(task.cancel, hideThread); hideThread = nil end
	if toastGui then toastGui:Destroy(); toastGui = nil end
	toastFrame, toastLabel, toastScale = nil, nil, nil
end

local function ensureToast()
	if toastGui and toastGui.Parent then return end
	destroyToast()

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhotoStoryToast"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 4999
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	toastGui = gui

	-- Frame kecil di atas-tengah, auto lebar mengikuti teks (responsive).
	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.05)
	frame.Size = UDim2.fromScale(0, 0.05)              -- tinggi relatif layar
	frame.AutomaticSize = Enum.AutomaticSize.X          -- lebar ikut teks
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.ZIndex = 10
	frame.Parent = gui
	toastFrame = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.8
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft  = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = frame

	local sizeC = Instance.new("UISizeConstraint")
	sizeC.MinSize = Vector2.new(40, 0)
	sizeC.MaxSize = Vector2.new(520, math.huge)
	sizeC.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame
	toastScale = scale

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.BackgroundTransparency = 1
	lbl.AutomaticSize = Enum.AutomaticSize.X
	lbl.Size = UDim2.fromScale(0, 1)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 240, 248)
	lbl.Text = ""
	lbl.ZIndex = 11
	lbl.Parent = frame
	toastLabel = lbl

	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 20
	tsc.MinTextSize = 10
	tsc.Parent = lbl
end

local function showToast(text, autoHide)
	ensureToast()
	if not toastLabel then return end
	toastLabel.Text = text

	-- pop kecil tiap update
	if toastScale then
		toastScale.Scale = 1.12
		if popTween then popTween:Cancel() end
		popTween = TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		popTween:Play()
	end

	if hideThread then pcall(task.cancel, hideThread); hideThread = nil end
	if autoHide then
		hideThread = task.delay(autoHide, function()
			if toastFrame then
				local tw = TweenService:Create(toastFrame, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
				tw:Play()
				tw.Completed:Connect(destroyToast)
			end
		end)
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
	destroyToast()
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
		showToast("Waiting for partner...")
	elseif statusType == "Countdown" then
		showToast("Starting in " .. tostring(data))
	elseif statusType == "Start" then
		showToast("Start!")
	elseif statusType == "Cancel" then
		showToast("Canceled", 1.4)
	elseif statusType == "Hide" then
		destroyToast()
	end
end)
