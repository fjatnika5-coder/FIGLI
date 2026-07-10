-- ═══════════════════════════════════════════════════════════════
-- 🎯 QUEST BOARD CLIENT V1 — FIXED
--
-- [FIX 1] Listen to ClaimResult for server feedback
-- [FIX 2] Visual feedback saat claim (loading state)
-- [FIX 3] Retry UI update jika claim result datang
-- ═══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local QuestRemotes = ReplicatedStorage:WaitForChild("QuestRemotes", 10)
if not QuestRemotes then return end

local UpdateQuestUI = QuestRemotes:WaitForChild("UpdateQuestUI", 10)
local ClaimReward = QuestRemotes:WaitForChild("ClaimReward", 10)
local ClaimResult = QuestRemotes:WaitForChild("ClaimResult", 10) -- [FIX 1]

if not UpdateQuestUI or not ClaimReward then return end

-- Colors
local YELLOW = Color3.fromRGB(255, 220, 80)
local GREEN = Color3.fromRGB(80, 255, 120)
local GRAY = Color3.fromRGB(100, 100, 105)
local RED = Color3.fromRGB(255, 80, 80)

local canClaim = false
local lastQuestData = nil

-- ═══════════════════════════════════════════════════════════════
-- UPDATE UI
-- ═══════════════════════════════════════════════════════════════

local function updateQuestDisplay(data)
	if not data then return end
	lastQuestData = data

	local part = workspace:FindFirstChild("QuestBoard")
	if not part then return end

	local gui = part:FindFirstChild("QuestGui")
	if not gui then return end

	local bg = gui:FindFirstChild("Background")
	if not bg then return end

	-- Quest 1
	local quest1 = bg:FindFirstChild("Quest1")
	if quest1 then
		local progress = quest1:FindFirstChild("Progress")
		if progress then
			progress.Text = "Progress: " .. data.quest1.current .. " / " .. data.quest1.required
			progress.TextColor3 = data.quest1.complete and GREEN or YELLOW
		end

		for _, child in ipairs(quest1:GetDescendants()) do
			if child.Name == "ProgressFill" then
				local percent = math.min(1, data.quest1.current / data.quest1.required)
				child.Size = UDim2.new(percent, 0, 1, 0)
				child.BackgroundColor3 = data.quest1.complete and GREEN or YELLOW
				break
			end
		end

		local status = quest1:FindFirstChild("Status")
		if status then
			status.Text = data.quest1.complete and "✅ Complete!" or "🔄 In Progress"
			status.TextColor3 = data.quest1.complete and GREEN or YELLOW
		end

		for _, child in ipairs(quest1:GetChildren()) do
			if child:IsA("UIStroke") then
				child.Color = data.quest1.complete and GREEN or Color3.fromRGB(45, 45, 50)
				break
			end
		end
	end

	-- Quest 2
	local quest2 = bg:FindFirstChild("Quest2")
	if quest2 then
		local progress = quest2:FindFirstChild("Progress")
		if progress then
			progress.Text = "Progress: " .. data.quest2.current .. " / " .. data.quest2.required
			progress.TextColor3 = data.quest2.complete and GREEN or YELLOW
		end

		for _, child in ipairs(quest2:GetDescendants()) do
			if child.Name == "ProgressFill" then
				local percent = math.min(1, data.quest2.current / data.quest2.required)
				child.Size = UDim2.new(percent, 0, 1, 0)
				child.BackgroundColor3 = data.quest2.complete and GREEN or YELLOW
				break
			end
		end

		local status = quest2:FindFirstChild("Status")
		if status then
			status.Text = data.quest2.complete and "✅ Complete!" or "🔄 In Progress"
			status.TextColor3 = data.quest2.complete and GREEN or YELLOW
		end

		for _, child in ipairs(quest2:GetChildren()) do
			if child:IsA("UIStroke") then
				child.Color = data.quest2.complete and GREEN or Color3.fromRGB(45, 45, 50)
				break
			end
		end
	end

	-- Reward
	local rewardFrame = bg:FindFirstChild("RewardFrame")
	if rewardFrame then
		local rewardStatus = rewardFrame:FindFirstChild("RewardStatus")
		local claimBtn = rewardFrame:FindFirstChild("ClaimButton")

		if data.rewardClaimed then
			canClaim = false
			if rewardStatus then
				rewardStatus.Text = "✅ Reward claimed!"
				rewardStatus.TextColor3 = GREEN
			end
			if claimBtn then
				claimBtn.Text = "✅ Claimed"
				claimBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
				claimBtn.TextColor3 = GREEN
				claimBtn.AutoButtonColor = false
			end
			for _, child in ipairs(rewardFrame:GetChildren()) do
				if child:IsA("UIStroke") then child.Color = GREEN; break end
			end

		elseif data.allComplete then
			canClaim = true
			if rewardStatus then
				rewardStatus.Text = "🎉 All quests complete!"
				rewardStatus.TextColor3 = GREEN
			end
			if claimBtn then
				claimBtn.Text = "🎁 CLAIM!"
				claimBtn.BackgroundColor3 = GREEN
				claimBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
				claimBtn.AutoButtonColor = true
			end

		else
			canClaim = false
			if rewardStatus then
				rewardStatus.Text = "Complete all quests to claim!"
				rewardStatus.TextColor3 = GRAY
			end
			if claimBtn then
				claimBtn.Text = "🔒 Locked"
				claimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
				claimBtn.TextColor3 = GRAY
				claimBtn.AutoButtonColor = false
			end
		end
	end

	local prompt = part:FindFirstChild("ClaimPrompt")
	if prompt then
		prompt.Enabled = data.allComplete and not data.rewardClaimed
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CLAIM HANDLER
-- [FIX 2] Visual loading state saat claim
-- ═══════════════════════════════════════════════════════════════

local claimDebounce = false

local function setClaimButtonState(text, color, textColor)
	local part = workspace:FindFirstChild("QuestBoard")
	if not part then return end
	local gui = part:FindFirstChild("QuestGui")
	if not gui then return end
	local bg = gui:FindFirstChild("Background")
	if not bg then return end
	local rewardFrame = bg:FindFirstChild("RewardFrame")
	if not rewardFrame then return end
	local claimBtn = rewardFrame:FindFirstChild("ClaimButton")
	if claimBtn then
		claimBtn.Text = text
		if color then claimBtn.BackgroundColor3 = color end
		if textColor then claimBtn.TextColor3 = textColor end
	end
end

local function onClaimClicked()
	if claimDebounce then return end
	if not canClaim then return end

	claimDebounce = true
	canClaim = false -- Prevent double-click

	-- [FIX 2] Show loading state
	setClaimButtonState("⏳ Claiming...", Color3.fromRGB(80, 80, 40), YELLOW)

	ClaimReward:FireServer()

	-- Timeout: jika server tidak respond dalam 5 detik, reset
	task.delay(5, function()
		if claimDebounce then
			claimDebounce = false
			-- Re-check quest state
			if lastQuestData then
				updateQuestDisplay(lastQuestData)
			end
		end
	end)
end

-- [FIX 1] Handle ClaimResult dari server
if ClaimResult then
	ClaimResult.OnClientEvent:Connect(function(result)
		claimDebounce = false

		if result and result.success then
			setClaimButtonState("✅ Claimed!", Color3.fromRGB(40, 60, 45), GREEN)
			if result.note then
				-- Rod akan muncul setelah rejoin
				task.delay(2, function()
					setClaimButtonState("✅ Rejoin for rod", Color3.fromRGB(40, 60, 45), GREEN)
				end)
			end
		elseif result and result.error then
			-- Show error briefly, then restore
			setClaimButtonState("❌ " .. result.error, Color3.fromRGB(60, 30, 30), RED)
			task.delay(3, function()
				if lastQuestData then
					updateQuestDisplay(lastQuestData)
				end
			end)
		end
	end)
end

local function setupClaimButton()
	local part = workspace:FindFirstChild("QuestBoard")
	if not part then return end
	local gui = part:FindFirstChild("QuestGui")
	if not gui then return end
	local bg = gui:FindFirstChild("Background")
	if not bg then return end
	local rewardFrame = bg:FindFirstChild("RewardFrame")
	if not rewardFrame then return end
	local claimBtn = rewardFrame:FindFirstChild("ClaimButton")
	if claimBtn then
		claimBtn.MouseButton1Click:Connect(onClaimClicked)
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "ClaimPrompt" then
		onClaimClicked()
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

UpdateQuestUI.OnClientEvent:Connect(function(data)
	updateQuestDisplay(data)
end)

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

local function initialize()
	local maxWait = 30
	local startTime = tick()
	while not workspace:FindFirstChild("QuestBoard") do
		if tick() - startTime > maxWait then return end
		task.wait(1)
	end
	task.wait(1)
	setupClaimButton()
	if lastQuestData then updateQuestDisplay(lastQuestData) end
end

task.spawn(initialize)

player.CharacterAdded:Connect(function()
	task.delay(3, function()
		if lastQuestData then updateQuestDisplay(lastQuestData) end
	end)
end)