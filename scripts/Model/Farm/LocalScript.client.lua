local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local NotifyEvent = ReplicatedStorage:WaitForChild("BuyToolNotify")

local successSound = SoundService:FindFirstChild("BuySuccess")
local failSound = SoundService:FindFirstChild("BuyFail")

NotifyEvent.OnClientEvent:Connect(function(status, toolName, price)
	if status == "Success" then
		StarterGui:SetCore("SendNotification", {
			Title = "Purchase Successful",
			Text = toolName .. " has been added to your backpack!",
			Duration = 3
		})
		if successSound then successSound:Play() end
	elseif status == "NotEnoughMoney" then
		StarterGui:SetCore("SendNotification", {
			Title = "Not Enough Money",
			Text = "You need more money to buy " .. toolName .. ".",
			Duration = 3
		})
		if failSound then failSound:Play() end
	end
end)
