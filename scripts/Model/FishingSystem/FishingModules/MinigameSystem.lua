-- System by @thehandofvoid
-- Modified by @jay_peaceee
-- ReplicatedStorage/FishingModules/MinigameSystem (FIXED)
-- ✅ Auto mode now requires MORE taps than manual (balanced)
-- ✅ Tap count based on rod quality from config
-- ✅ Better rod = fewer taps needed

local MinigameSystem = {}
local RepStorage = game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem")
local TS = game:GetService("TweenService")

local FishingConfig = require(RepStorage:WaitForChild("FishingConfig"))

local minigameState = {
	active = false,
	clickCount = 0,
	progress = 0,
	progressPerClick = 0,
	decayRate = 0,
	isAutoMode = false,
	requiredTaps = 15,  -- Will be set dynamically based on rod
	currentRodName = nil
}

local gui = nil
local callbacks = {}

function MinigameSystem:Initialize(guiElements)
	gui = guiElements
end

function MinigameSystem:SetCallbacks(onComplete, onFail)
	callbacks.onComplete = onComplete
	callbacks.onFail = onFail
end

function MinigameSystem:UpdateBar()
	minigameState.progress = math.clamp(minigameState.progress, 0, 1)

	gui.fishingFillFrame.Size = UDim2.new(minigameState.progress, 0, 1, 0)

	local color
	if minigameState.progress >= 1.0 then
		color = Color3.fromRGB(0, 255, 0)
	elseif minigameState.progress < 0.3 then
		color = Color3.fromRGB(255, 100, 100)
	elseif minigameState.progress < 0.7 then
		color = Color3.fromRGB(255, 200, 100)
	else
		color = Color3.fromRGB(100, 255, 100)
	end
	gui.fishingFillFrame.BackgroundColor3 = color
end

function MinigameSystem:HandleClick(SoundManager, GUIManager)
	if not minigameState.active then return end
	if minigameState.isAutoMode then return end  -- Don't allow manual clicks during auto mode

	minigameState.clickCount += 1
	minigameState.progress = math.min(minigameState.progress + minigameState.progressPerClick, 1.0)
	self:UpdateBar()

	if gui.infoText then
		gui.infoText.Text = string.format("Tap! (%d/%d)", minigameState.clickCount, minigameState.requiredTaps)
	end

	GUIManager:AnimateImageTap()
	SoundManager:Play("Tap", 0.4)

	if minigameState.progress >= 1.0 then
		minigameState.active = false
		if callbacks.onComplete then
			callbacks.onComplete()
		end
		return
	end

	-- Visual feedback
	task.spawn(function()
		local tween = TS:Create(
			gui.fishingFillFrame,
			TweenInfo.new(FishingConfig.MinigameSettings.clickFeedbackDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{BackgroundColor3 = Color3.fromRGB(255, 255, 255)}
		)
		tween:Play()

		task.wait(0.05)
		local tween2 = TS:Create(
			gui.fishingFillFrame,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{BackgroundColor3 = Color3.fromRGB(100, 255, 100)}
		)
		tween2:Play()

		tween2.Completed:Connect(function()
			if minigameState.active then
				self:UpdateBar()
			end
		end)
	end)
end

-- 🆕 MAIN START FUNCTION (Now calculates taps based on rod and mode)
function MinigameSystem:Start(isAuto, rodName)
	minigameState.active = true
	minigameState.clickCount = 0
	minigameState.isAutoMode = isAuto or false
	minigameState.currentRodName = rodName

	-- 🆕 Calculate required taps based on rod quality and mode
	minigameState.requiredTaps = FishingConfig.GetRequiredTaps(rodName, isAuto)

	-- 🆕 Calculate progress per click based on required taps
	-- We want the bar to fill completely after exactly requiredTaps clicks
	minigameState.progressPerClick = 1.0 / minigameState.requiredTaps

	if gui.infoText then
		if isAuto then
			gui.infoText.Text = string.format("Auto... (0/%d)", minigameState.requiredTaps)
		else
			gui.infoText.Text = string.format("Tap! (0/%d)", minigameState.requiredTaps)
		end
	end

	local settings = FishingConfig.MinigameSettings
	minigameState.progress = settings.startingProgress
	minigameState.decayRate = math.random(settings.decayMin, settings.decayMax) / 1000

	gui.fishingFillFrame.Size = UDim2.new(settings.startingProgress, 0, 1, 0)

	-- == AUTO MODE: Simulate realistic clicks ==
	if isAuto then
		task.spawn(function()
			-- Auto-click loop: Clicks at human-like intervals
			while minigameState.active and minigameState.progress < 1.0 do
				-- Random delay between clicks (0.10 - 0.18 seconds, realistic human speed)
				local clickDelay = math.random(100, 180) / 1000
				task.wait(clickDelay)

				if not minigameState.active then break end

				-- Simulate a click
				minigameState.clickCount += 1
				minigameState.progress = math.min(minigameState.progress + minigameState.progressPerClick, 1.0)
				self:UpdateBar()

				-- Update text
				if gui.infoText then
					gui.infoText.Text = string.format("Auto (%d/%d)", minigameState.clickCount, minigameState.requiredTaps)
				end

				-- Check if completed
				if minigameState.progress >= 1.0 then
					minigameState.active = false
					if callbacks.onComplete then
						callbacks.onComplete()
					end
					break
				end
			end
		end)

		-- Still run decay in background (makes auto more fair)
		local minigameStartTime = tick()
		local lastUpdateTime = tick()

		task.spawn(function()
			while minigameState.active and (tick() - minigameStartTime) < settings.fishingTime do
				local currentTime = tick()
				local deltaTime = currentTime - lastUpdateTime
				lastUpdateTime = currentTime

				-- Apply decay (auto mode still loses progress over time)
				minigameState.progress -= (minigameState.decayRate * deltaTime * settings.decayMultiplier)
				self:UpdateBar()

				-- Check for failure
				if minigameState.progress <= 0 then
					minigameState.active = false
					if callbacks.onFail then
						callbacks.onFail()
					end
					break
				end

				task.wait(0.02)
			end

			-- Timeout check
			if minigameState.active then
				minigameState.active = false
				if callbacks.onFail then
					callbacks.onFail()
				end
			end
		end)

		return
	end

	-- == MANUAL MODE: Normal player clicking ==
	local minigameStartTime = tick()
	local lastUpdateTime = tick()

	task.spawn(function()
		while minigameState.active and (tick() - minigameStartTime) < settings.fishingTime do
			local currentTime = tick()
			local deltaTime = currentTime - lastUpdateTime
			lastUpdateTime = currentTime

			minigameState.progress -= (minigameState.decayRate * deltaTime * settings.decayMultiplier)
			self:UpdateBar()

			if minigameState.progress >= 1.0 then
				minigameState.active = false
				if callbacks.onComplete then
					callbacks.onComplete()
				end
				break
			end

			if minigameState.progress <= 0 then
				minigameState.active = false
				if callbacks.onFail then
					callbacks.onFail()
				end
				break
			end

			task.wait(0.02)
		end

		if minigameState.active then
			minigameState.active = false
			if callbacks.onFail then
				callbacks.onFail()
			end
		end
	end)
end

function MinigameSystem:Stop()
	minigameState.active = false
	minigameState.isAutoMode = false
end

function MinigameSystem:ForceStop()
	minigameState.active = false
	minigameState.clickCount = 0
	minigameState.progress = 0
	minigameState.isAutoMode = false
end

function MinigameSystem:IsActive()
	return minigameState.active
end

return MinigameSystem