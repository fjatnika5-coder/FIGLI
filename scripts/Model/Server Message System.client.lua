local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Event = ReplicatedStorage:WaitForChild("GlobalChatEvent")

Event.OnClientEvent:Connect(function(message)
	if not message then return end

	local channel = TextChatService.TextChannels:WaitForChild("RBXGeneral")
	channel:DisplaySystemMessage(message)
end)
