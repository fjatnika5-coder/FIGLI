local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuyFarmEvent = ReplicatedStorage:WaitForChild("BuyFarmEvent")

local toolName = "WateringCan" -- Ganti dengan nama tool yang ingin dibeli

script.Parent.MouseButton1Click:Connect(function()
	BuyFarmEvent:FireServer(toolName)
end)
