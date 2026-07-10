-- Place in StarterPlayer > StarterPlayerScripts
-- ChatDisplayClient - Displays fish catches in correct chat channels

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local FishingConfig = require(FishingSystem:WaitForChild("FishingConfig"))
local RarityColors = FishingConfig.RarityColors

-- Wait for SendChatMessage event
local SendChatMessage = FishingSystem:WaitForChild("SendChatMessage")

-- Wait for chat channels
local TextChannels = TextChatService:WaitForChild("TextChannels")
local generalChannel = TextChannels:WaitForChild("RBXGeneral")
local globalChannel = TextChannels:WaitForChild("Global")

-- Helper function to convert Color3 to rgb string
local function colorToRGB(color)
	return string.format(
		"rgb(%d,%d,%d)",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255)
	)
end

-- Receive and display messages
SendChatMessage.OnClientEvent:Connect(function(channelName, playerName, fishName, weight, rarity)
	-- Get fish color
	local fishColor = RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
	local fishColorString = colorToRGB(fishColor)

	-- Create message
	local message = string.format(
		"🎣 <b>%s</b> caught a <font color='%s'><b>%s</b></font> (%.1fkg)!",
		playerName,
		fishColorString,
		fishName,
		weight
	)

	-- Display in correct channel
	if channelName == "General" then
		generalChannel:DisplaySystemMessage(message)
	elseif channelName == "Global" then
		globalChannel:DisplaySystemMessage(message)
	end
end)