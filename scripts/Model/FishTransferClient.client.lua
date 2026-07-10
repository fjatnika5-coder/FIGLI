-- System by @thehandofvoid
-- Modified by @jay_peaceee
-- StarterPlayer/StarterPlayerScripts/FishTransferClient

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- == CONFIGURATION ==
local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local FishingConfig = require(FishingSystem:WaitForChild("FishingConfig"))
local TransferSettings = FishingConfig.TransferSettings

local MAX_DISTANCE = TransferSettings.MaxDistance
local PROMPT_NAME = "TransferFishPrompt"
local PROMPT_TEXT = "Gift Fish"

-- == GUI REFERENCES ==
local TransferGui
local MainFrame
local Title
local Info
local Timer
local YesButton
local NoButton

-- Function to refresh GUI references
local function refreshGuiReferences()
	TransferGui = playerGui:WaitForChild("TransferGui")
	MainFrame = TransferGui:WaitForChild("MainFrame")
	Title = MainFrame:WaitForChild("Title")
	Info = MainFrame:WaitForChild("Info")
	Timer = MainFrame:WaitForChild("Timer")
	YesButton = MainFrame:WaitForChild("YesButton")
	NoButton = MainFrame:WaitForChild("NoButton")
end

-- Initial GUI setup
refreshGuiReferences()

-- == REMOTE EVENTS ==
local TransferRequest = FishingSystem:WaitForChild("TransferRequest")
local TransferResponse = FishingSystem:WaitForChild("TransferResponse")
local TransferPrompt = FishingSystem:WaitForChild("TransferPrompt")
local ShowNotification = FishingSystem:WaitForChild("ShowNotification")

-- == LOCAL STATE ==
local currentEquippedFish = nil
local activePrompts = {} -- {player = {prompt = prompt, connection = RBXScriptConnection}}
local isGuiBusy = false
local currentTransferId = nil
local closeGuiConnection = nil
local yesButtonConnection = nil
local noButtonConnection = nil

-- ===================================================================
-- CORE FUNCTIONS
-- ===================================================================

-- Function to hide GUI
local function closeGui()
	if closeGuiConnection then
		closeGuiConnection:Disconnect()
		closeGuiConnection = nil
	end

	if yesButtonConnection then
		yesButtonConnection:Disconnect()
		yesButtonConnection = nil
	end

	if noButtonConnection then
		noButtonConnection:Disconnect()
		noButtonConnection = nil
	end

	isGuiBusy = false
	currentTransferId = nil
	TransferGui.Enabled = false
	YesButton.Visible = true
	NoButton.Text = "No"
end

-- Function to show GUI (for both sender and receiver)
-- data = { title, info, yesText, noText, duration, transferId }
local function showGui(data)
	if isGuiBusy then 
		return 
	end

	isGuiBusy = true
	currentTransferId = data.transferId or nil

	Title.Text = data.title
	Info.Text = data.info
	YesButton.Text = data.yesText
	NoButton.Text = data.noText or "No"
	YesButton.Visible = (data.yesText ~= "")

	TransferGui.Enabled = true

	local startTime = tick()
	local duration = data.duration or 10

	if closeGuiConnection then
		closeGuiConnection:Disconnect()
	end

	-- Timer countdown
	closeGuiConnection = RunService.Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local remaining = math.floor(duration - elapsed)

		if remaining <= 0 then
			Timer.Text = "(0s)"
			if currentTransferId then
				TransferResponse:FireServer(currentTransferId, false)
			end
			closeGui()
		else
			Timer.Text = string.format("(%ds)", remaining)
		end
	end)
end

-- Function to check if a tool is a fish
local function getFishToolData(tool)
	if not tool or not tool:IsA("Tool") then return nil end

	local fishId = tool:FindFirstChild("FishId")
	local weight = tool:FindFirstChild("Weight")
	local rarity = tool:FindFirstChild("Rarity")

	if fishId and weight and rarity then
		return {
			Tool = tool,
			Name = tool.Name,
			Id = fishId.Value,
			Weight = weight.Value,
			Rarity = rarity.Value
		}
	end
	return nil
end

-- Forward declarations
local removePrompt
local updateAllPrompts

-- Function to create ProximityPrompt on other players
local function createPromptOnPlayer(targetPlayer)
	local character = targetPlayer.Character
	if not character then return end

	-- Remove old prompt if it exists
	if activePrompts[targetPlayer] then
		removePrompt(targetPlayer)
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ObjectText = targetPlayer.Name
	prompt.ActionText = PROMPT_TEXT
	prompt.MaxActivationDistance = MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = hrp

	-- Store connection
	local connection = prompt.Triggered:Connect(function()
		if not currentEquippedFish or isGuiBusy then 
			return 
		end

		-- Verify the tool still exists
		if not currentEquippedFish.Tool or not currentEquippedFish.Tool.Parent then
			currentEquippedFish = nil
			updateAllPrompts()
			return
		end

		-- Show confirmation GUI for SENDER
		showGui({
			title = "Transfer Confirmation",
			info = string.format("Give %s (%.1fkg) To %s?", currentEquippedFish.Name, currentEquippedFish.Weight, targetPlayer.Name),
			yesText = "Confirm",
			noText = "Cancel",
			duration = 10,
			transferId = nil
		})

		-- Disconnect old connections if they exist
		if yesButtonConnection then
			yesButtonConnection:Disconnect()
		end
		if noButtonConnection then
			noButtonConnection:Disconnect()
		end

		-- Store the connections
		yesButtonConnection = YesButton.MouseButton1Click:Connect(function()
			if currentEquippedFish and currentEquippedFish.Tool and currentEquippedFish.Tool.Parent then
				TransferRequest:FireServer(targetPlayer, currentEquippedFish.Id)
			end
			closeGui()
		end)

		noButtonConnection = NoButton.MouseButton1Click:Connect(function()
			closeGui()
		end)
	end)

	activePrompts[targetPlayer] = {
		prompt = prompt,
		connection = connection
	}
end

-- Function to remove ProximityPrompt
removePrompt = function(player)
	if activePrompts[player] then
		if activePrompts[player].connection then
			activePrompts[player].connection:Disconnect()
		end
		if activePrompts[player].prompt then
			activePrompts[player].prompt:Destroy()
		end
		activePrompts[player] = nil
	end
end

-- Function to update all prompts
updateAllPrompts = function()
	if currentEquippedFish then
		-- Holding a fish, create prompts
		for _, player in pairs(Players:GetPlayers()) do
			if player ~= localPlayer and player.Character then
				createPromptOnPlayer(player)
			end
		end
	else
		-- Not holding a fish, destroy all prompts
		for player, data in pairs(activePrompts) do
			removePrompt(player)
		end
		activePrompts = {}
	end
end

-- ===================================================================
-- EVENT CONNECTIONS
-- ===================================================================

-- 1. Monitor Equipped Tools
local function onCharacterAdded(character)
	-- Refresh GUI references after respawn
	task.wait(0.1)
	refreshGuiReferences()

	-- Force close GUI and reset all states on respawn
	closeGui()

	-- Clear current fish data on respawn
	currentEquippedFish = nil

	-- Remove ALL old prompts and connections
	for player, data in pairs(activePrompts) do
		removePrompt(player)
	end
	activePrompts = {}

	character.ChildAdded:Connect(function(child)
		local fishData = getFishToolData(child)
		if fishData then
			currentEquippedFish = fishData
			updateAllPrompts()
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if currentEquippedFish and child == currentEquippedFish.Tool then
			currentEquippedFish = nil
			updateAllPrompts()
		end
	end)

	-- Check if already holding a fish on spawn
	task.wait(0.5)
	local currentTool = character:FindFirstChildOfClass("Tool")
	if currentTool then
		local fishData = getFishToolData(currentTool)
		if fishData then
			currentEquippedFish = fishData
			updateAllPrompts()
		end
	end
end

-- 2. Monitor Other Players Joining/Leaving
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		if currentEquippedFish then
			createPromptOnPlayer(player)
		end
	end)

	if player.Character and currentEquippedFish then
		task.wait(1)
		createPromptOnPlayer(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removePrompt(player)
end)

-- Monitor when other players respawn
for _, player in pairs(Players:GetPlayers()) do
	if player ~= localPlayer then
		player.CharacterAdded:Connect(function()
			removePrompt(player)
			if currentEquippedFish then
				task.wait(1)
				createPromptOnPlayer(player)
			end
		end)
	end
end

-- 3. Global No button handler (for receiver's decline)
NoButton.MouseButton1Click:Connect(function()
	if currentTransferId then
		TransferResponse:FireServer(currentTransferId, false)
	end
	closeGui()
end)

-- 4. Monitor Events from Server (For RECEIVER)
TransferPrompt.OnClientEvent:Connect(function(senderPlayer, fishName, fishWeight, transferId)
	if isGuiBusy then
		TransferResponse:FireServer(transferId, false)
		return
	end

	showGui({
		title = "Transfer Request",
		info = string.format("%s want to give %s (%.1fkg)", senderPlayer.Name, fishName, fishWeight),
		yesText = "Accept",
		noText = "Decline",
		duration = 10,
		transferId = transferId
	})

	-- Disconnect old connection
	if yesButtonConnection then
		yesButtonConnection:Disconnect()
	end

	-- Store the connection
	yesButtonConnection = YesButton.MouseButton1Click:Connect(function()
		TransferResponse:FireServer(currentTransferId, true)
		closeGui()
	end)
end)

-- 5. Monitor Notifications from Server
ShowNotification.OnClientEvent:Connect(function(message, duration, color)
	if isGuiBusy then
		closeGui()
	end
end)

-- ===================================================================
-- INITIALIZATION
-- ===================================================================

-- Run for existing character
if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end

-- Run for character spawns
localPlayer.CharacterAdded:Connect(onCharacterAdded)

-- Setup for all existing players
for _, player in pairs(Players:GetPlayers()) do
	if player ~= localPlayer and player.Character then
		player.CharacterAdded:Connect(function()
			removePrompt(player)
			if currentEquippedFish then
				task.wait(1)
				createPromptOnPlayer(player)
			end
		end)
	end
end