local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OpenFarmGUI = ReplicatedStorage:WaitForChild("OpenFarmGUI")
local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local OpenFarmGui = PlayerGui:WaitForChild("Farm")
local MainFrame = OpenFarmGui:WaitForChild("Frame")

OpenFarmGUI.OnClientEvent:Connect(function()
	MainFrame.Visible = true
end)
