local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents

script.Parent.MouseButton1Click:Connect(function()
	GlobalEvents.RemoteEvent:FireServer("uxpvoting", script.Parent.Parent.Parent.VoteID.Value, script.Parent.QValue.Value, script.Parent.Parent.Parent.Global.Value)
end)