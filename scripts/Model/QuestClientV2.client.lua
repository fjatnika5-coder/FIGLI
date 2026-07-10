-- ═══════════════════════════════════════════════════════════════
-- 🎯 QUEST BOARD V2 CLIENT — FIXED
--
-- Same fixes as V1 client:
-- [FIX 1] Listen to ClaimResultV2 for server feedback
-- [FIX 2] Visual loading state saat claim
-- [FIX 3] Timeout protection
-- ═══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local QuestRemotesV2 = ReplicatedStorage:WaitForChild("QuestRemotesV2", 10)
if not QuestRemotesV2 then return end

local UpdateQuestUIV2 = QuestRemotesV2:WaitForChild("UpdateQuestUIV2", 10)
local ClaimRewardV2 = QuestRemotesV2:WaitForChild("ClaimRewardV2", 10)
local ClaimResultV2 = QuestRemotesV2:WaitForChild("ClaimResultV2", 10) -- [FIX 1]

if not UpdateQuestUIV2 or not ClaimRewardV2 then return end

-- Colors
local YELLOW = Color3.fromRGB(255, 220, 80)
local GREEN = Color3.fromRGB(80, 255, 120)
local GRAY = Color3.fromRGB(100, 100, 105)
local RED = Color3.fromRGB(255, 80, 80)

local canClaimV2 = false
local lastQuestDataV2 = nil

-- ═══════════════════════════════════════════════════════════════
-- UPDATE UI
-- ═══════════════════════════════════════════════════════════════

local function updateQuestDisplayV2(data)
	if not data then return end
	lastQuestDataV2 = data

	local part = workspace:FindFirstChild("QuestBoardV2")
	if not part then return end

	local gui = part:FindFirstChild("QuestGuiV2")
	if not gui then return end

	local bg = gui:FindFirstChild("Background")
	if not bg then return end

	-- Quest 1 (Celestfin)
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

	-- Quest 2 (Rosefin)
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
			canClaimV2 = false
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
			canClaimV2 = true
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
			canClaimV2 = false
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

	local prompt = part:FindFirstChild("ClaimPromptV2")
	if prompt then
		prompt.Enabled = data.allComplete and not data.rewardClaimed
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CLAIM HANDLER
-- ═══════════════════════════════════════════════════════════════

local claimDebounceV2 = false

local function setClaimButtonState(text, color, textColor)
	local part = workspace:FindFirstChild("QuestBoardV2")
	if not part then return end
	local gui = part:FindFirstChild("QuestGuiV2")
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

local function onClaimClickedV2()
	if claimDebounceV2 then return end
	if not canClaimV2 then return end

	claimDebounceV2 = true
	canClaimV2 = false

	-- [FIX 2] Loading state
	setClaimButtonState("⏳ Claiming...", Color3.fromRGB(80, 80, 40), YELLOW)

	ClaimRewardV2:FireServer()

	-- Timeout
	task.delay(5, function()
		if claimDebounceV2 then
			claimDebounceV2 = false
			if lastQuestDataV2 then updateQuestDisplayV2(lastQuestDataV2) end
		end
	end)
end

-- [FIX 1] Handle server response
if ClaimResultV2 then
	ClaimResultV2.OnClientEvent:Connect(function(result)
		claimDebounceV2 = false

		if result and result.success then
			setClaimButtonState("✅ Claimed!", Color3.fromRGB(40, 60, 45), GREEN)
			if result.note then
				task.delay(2, function()
					setClaimButtonState("✅ Rejoin for rod", Color3.fromRGB(40, 60, 45), GREEN)
				end)
			end
		elseif result and result.error then
			setClaimButtonState("❌ " .. result.error, Color3.fromRGB(60, 30, 30), RED)
			task.delay(3, function()
				if lastQuestDataV2 then updateQuestDisplayV2(lastQuestDataV2) end
			end)
		end
	end)
end

local function setupClaimButtonV2()
	local part = workspace:FindFirstChild("QuestBoardV2")
	if not part then return end
	local gui = part:FindFirstChild("QuestGuiV2")
	if not gui then return end
	local bg = gui:FindFirstChild("Background")
	if not bg then return end
	local rewardFrame = bg:FindFirstChild("RewardFrame")
	if not rewardFrame then return end
	local claimBtn = rewardFrame:FindFirstChild("ClaimButton")
	if claimBtn then
		claimBtn.MouseButton1Click:Connect(onClaimClickedV2)
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "ClaimPromptV2" then
		onClaimClickedV2()
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

UpdateQuestUIV2.OnClientEvent:Connect(function(data)
	updateQuestDisplayV2(data)
end)

-- ═══════════════════════════════════════════════════════════════
-- INIT
-- ═══════════════════════════════════════════════════════════════

local function initializeV2()
	local maxWait = 30
	local startTime = tick()
	while not workspace:FindFirstChild("QuestBoardV2") do
		if tick() - startTime > maxWait then return end
		task.wait(1)
	end
	task.wait(1)
	setupClaimButtonV2()
	if lastQuestDataV2 then updateQuestDisplayV2(lastQuestDataV2) end
end

task.spawn(initializeV2)

player.CharacterAdded:Connect(function()
	task.delay(3, function()
		if lastQuestDataV2 then updateQuestDisplayV2(lastQuestDataV2) end
	end)
end)