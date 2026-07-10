local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents

script.Parent.MouseButton1Click:Connect(function()
	local TargetPlayer = Players:GetPlayerByUserId(script.Parent.Parent.Parent.TargetID.Value)
	if TargetPlayer then
		local args = {"CommandEvent",
			script.Parent.Parent.Parent.Command.Value,
			TargetPlayer.Name
		}
		for i,v in pairs(script.Parent.Parent.Parent.Parent.Parent.Parent.ScrollingFrame:GetChildren()) do
			if v:IsA("UIListLayout") or v.Name == "ButtonFrame" then continue end
			table.insert(args, v.TextFrame.ValueTextBox.Text)
		end
		GlobalEvents.RemoteEvent:FireServer(unpack(args))
	end
end)