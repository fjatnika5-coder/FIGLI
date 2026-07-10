local ReplicatedStorage = game:GetService("ReplicatedStorage")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents

script.Parent.MouseButton1Click:Connect(function()
	if script.Parent.Parent.Parent.ButtonFrame.Visible then
		if script.Parent.Parent.Parent.ButtonFrame.ImageLabel.Image == "rbxassetid://134134889667415" then
			GlobalEvents.RemoteEvent:FireServer("uxpeditdata",
				script.Parent.Parent.Parent.Parent.Parent.NameValue.Value,
				script.Parent.Parent.Parent.TextLabel.Text,
				true)
		else
			GlobalEvents.RemoteEvent:FireServer("uxpeditdata",
				script.Parent.Parent.Parent.Parent.Parent.NameValue.Value,
				script.Parent.Parent.Parent.TextLabel.Text,
				false)
		end
	elseif script.Parent.Parent.Parent.ColorTextBox1.Visible then
		GlobalEvents.RemoteEvent:FireServer("uxpeditdata",
			script.Parent.Parent.Parent.Parent.Parent.NameValue.Value,
			script.Parent.Parent.Parent.TextLabel.Text,
			script.Parent.Parent.Parent.ColorTextBox1.Text,
			script.Parent.Parent.Parent.ColorTextBox2.Text,
			script.Parent.Parent.Parent.ColorTextBox3.Text)
	elseif script.Parent.Parent.Parent.IntTextBox.Visible then
		GlobalEvents.RemoteEvent:FireServer("uxpeditdata",
			script.Parent.Parent.Parent.Parent.Parent.NameValue.Value,
			script.Parent.Parent.Parent.TextLabel.Text,
			script.Parent.Parent.Parent.IntTextBox.Text)
	elseif script.Parent.Parent.Parent.StringTextBox.Visible then
		GlobalEvents.RemoteEvent:FireServer("uxpeditdata",
			script.Parent.Parent.Parent.Parent.Parent.NameValue.Value,
			script.Parent.Parent.Parent.TextLabel.Text,
			script.Parent.Parent.Parent.StringTextBox.Text)
	end
end)