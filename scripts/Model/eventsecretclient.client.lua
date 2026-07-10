-- StarterPlayerScripts.LegendaryEventClient (Optimized)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local EventRemotes = FishingSystem:WaitForChild("EventRemotes")
local EventTimerEvent = EventRemotes:WaitForChild("EventTimer")
local EventCountdownEvent = EventRemotes:WaitForChild("EventCountdown")
local EventBroadcastEvent = EventRemotes:WaitForChild("EventBroadcast")

-- ═════════════════════════════════════
-- CHAT SYSTEM
-- ═════════════════════════════════════

local chatReady = false
local chatMethod = nil
local messageQueue = {}

task.spawn(function()
	-- Coba TextChatService dulu
	for i = 1, 30 do
		local ok, channel = pcall(function()
			local channels = TextChatService:WaitForChild("TextChannels", 1)
			if channels then
				return channels:WaitForChild("RBXSystem", 1)
			end
			return nil
		end)

		if ok and channel then
			chatMethod = "new"
			chatReady = true

			for _, msg in ipairs(messageQueue) do
				pcall(function() channel:DisplaySystemMessage(msg) end)
			end
			messageQueue = nil -- Bebas memory, ga perlu lagi
			return
		end
		task.wait(1)
	end

	-- Fallback ke legacy
	for i = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = " ",
				Color = Color3.fromRGB(255, 60, 60),
				Font = Enum.Font.GothamBold,
				TextSize = 22,
			})
		end)

		if ok then
			chatMethod = "legacy"
			chatReady = true

			for _, msg in ipairs(messageQueue) do
				pcall(function()
					StarterGui:SetCore("ChatMakeSystemMessage", {
						Text = msg,
						Color = Color3.fromRGB(255, 60, 60),
						Font = Enum.Font.GothamBold,
						TextSize = 22,
					})
				end)
				task.wait(0.3)
			end
			messageQueue = nil
			return
		end
		task.wait(1)
	end

	-- Kalau dua-duanya gagal, buang queue supaya ga nahan memory
	messageQueue = nil
end)

local function sendChat(message)
	if not chatReady then
		if messageQueue then
			table.insert(messageQueue, message)
		end
		return
	end

	if chatMethod == "new" then
		local richText = string.format(
			'<font size="22" color="#FF3C3C"><b>%s</b></font>',
			message
		)
		pcall(function()
			TextChatService.TextChannels.RBXSystem:DisplaySystemMessage(richText)
		end)
	elseif chatMethod == "legacy" then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = message,
				Color = Color3.fromRGB(255, 60, 60),
				Font = Enum.Font.GothamBold,
				TextSize = 22,
			})
		end)
	end
end

-- ═════════════════════════════════════
-- GUI REFERENCES
-- ═════════════════════════════════════

local gui            = playerGui:WaitForChild("LegendaryEventUI")
local countdownFrame = gui:WaitForChild("CountdownFrame")
local countdownLabel = countdownFrame:WaitForChild("CountdownLabel")
local countdownSub   = countdownFrame:WaitForChild("CountdownSub")
local bar            = gui:WaitForChild("TimerBar")
local stroke         = bar:WaitForChild("UIStroke")
local icon           = bar:WaitForChild("Icon")
local titleLabel     = bar:WaitForChild("TitleLabel")
local subtitleLabel  = bar:WaitForChild("SubtitleLabel")
local timeLabel      = bar:WaitForChild("TimeLabel")

-- ═════════════════════════════════════
-- WARNA
-- ═════════════════════════════════════

local COLOR_NORMAL  = Color3.fromRGB(255, 210, 120)
local COLOR_WARNING = Color3.fromRGB(255, 160, 60)
local COLOR_DANGER  = Color3.fromRGB(255, 70, 70)

local currentStrokeColor = COLOR_NORMAL

-- ═════════════════════════════════════
-- PULSE BORDER (fixed: pakai flag, tidak rekursi)
-- ═════════════════════════════════════

local pulseRunning = false

local function startPulse()
	if pulseRunning then return end -- Cegah numpuk
	pulseRunning = true

	task.spawn(function()
		while pulseRunning and bar.Visible do
			TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.7
			}):Play()
			task.wait(0.8)

			if not pulseRunning or not bar.Visible then break end

			TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.15
			}):Play()
			task.wait(0.8)
		end
		pulseRunning = false
	end)
end

local function stopPulse()
	pulseRunning = false
end

-- ═════════════════════════════════════
-- HELPERS
-- ═════════════════════════════════════

local function formatTime(sec)
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%d:%02d", m, s)
end

local function setColor(color)
	if currentStrokeColor == color then return end
	currentStrokeColor = color
	TweenService:Create(stroke, TweenInfo.new(0.4), {Color = color}):Play()
	TweenService:Create(titleLabel, TweenInfo.new(0.4), {TextColor3 = color}):Play()
	TweenService:Create(timeLabel, TweenInfo.new(0.4), {TextColor3 = color}):Play()
end

local function showBar()
	bar.Visible = true
	bar.Position = UDim2.new(0.5, 0, 0, -70)
	startPulse()
	TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 14)
	}):Play()
end

local function hideBar()
	stopPulse() -- Matikan pulse sebelum hide
	TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
		Position = UDim2.new(0.5, 0, 0, -70)
	}):Play()
	task.delay(0.35, function()
		bar.Visible = false
	end)
end

-- ═════════════════════════════════════
-- COUNTDOWN
-- ═════════════════════════════════════

local function animateCountdownNumber(text, color)
	countdownLabel.Text = text
	countdownLabel.TextColor3 = color
	countdownLabel.TextTransparency = 0
	countdownLabel.Size = UDim2.new(0, 180, 0, 180)

	TweenService:Create(countdownLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {
		Size = UDim2.new(0, 300, 0, 200),
		TextTransparency = 0.1
	}):Play()
end

local function showCountdown(number, isGo)
	countdownFrame.Visible = true
	countdownFrame.BackgroundTransparency = 0.4

	if isGo then
		animateCountdownNumber("GO!", Color3.fromRGB(100, 255, 150))
		countdownSub.Text = "Selamat memancing!"

		task.delay(0.6, function()
			TweenService:Create(countdownFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {
				BackgroundTransparency = 1
			}):Play()
			TweenService:Create(countdownLabel, TweenInfo.new(0.5), {
				TextTransparency = 1
			}):Play()
			TweenService:Create(countdownSub, TweenInfo.new(0.5), {
				TextTransparency = 1
			}):Play()
			task.delay(0.5, function()
				countdownFrame.Visible = false
				countdownLabel.TextTransparency = 0
				countdownSub.TextTransparency = 0
			end)
		end)
	else
		local color = number == 1 and COLOR_DANGER or COLOR_WARNING
		animateCountdownNumber(tostring(number), color)
		countdownSub.Text = "Legendary Event dimulai!"
	end
end

-- ═════════════════════════════════════
-- REMOTE HANDLERS
-- ═════════════════════════════════════

EventCountdownEvent.OnClientEvent:Connect(function(number, isGo)
	showCountdown(number, isGo)
end)

EventTimerEvent.OnClientEvent:Connect(function(timeRemaining, active)
	if active and timeRemaining > 0 then
		if not bar.Visible then showBar() end

		timeLabel.Text = formatTime(timeRemaining)

		if timeRemaining <= 10 then
			setColor(COLOR_DANGER)
		elseif timeRemaining <= 30 then
			setColor(COLOR_WARNING)
		else
			setColor(COLOR_NORMAL)
		end
	else
		if bar.Visible then hideBar() end
	end
end)

EventBroadcastEvent.OnClientEvent:Connect(function(message)
	sendChat(message)
end)