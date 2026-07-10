local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents

script.Parent.MouseButton1Click:Connect(function()
	GlobalEvents.RemoteEvent:FireServer("uxpviewtoolsadd", script.Parent.Parent.Parent.Parent.NameValue.Value, script.Parent.Parent.Name)
end)