local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents
local PanelSettings = require(AdminPanelRS.PanelSettings)
local MainFrame = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent

script.Parent.MouseButton1Click:Connect(function()
	for i,v in pairs(MainFrame.PlayerEditPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local TargetPlayer = Players:GetPlayerByUserId(script.Parent.Parent.Parent.Name)
	if TargetPlayer then
		MainFrame.PlayerEditPage.ProfileFrame.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..TargetPlayer.UserId.."&width=150&height=150"
		MainFrame.PlayerEditPage.NameLabel.Text = string.gsub(PanelSettings.Messages.SelectedText, "$playername", Players.LocalPlayer.Name)
		MainFrame.PlayerEditPage.UserIDLabel.Text = string.gsub(PanelSettings.Messages.UserID, "$userid", Players.LocalPlayer.UserId)
		MainFrame.PlayerEditPage.Visible = true
		MainFrame.PlayersPage.Visible = false
		local Permission = GlobalEvents.RemoteFunction:InvokeServer("UXPGetPermission")
		for i,v in pairs(PanelSettings.CommandList) do
			for i2, v2 in pairs(Permission) do
				for i3, v3 in pairs(v.CommandPermission) do
					if v2 == v3 then
						local Template = MainFrame.PlayerEditPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
						Template.Name = v.CommandName
						Template.CommandText.Text = v.CommandText
						Template.CommandDescription.Text = v.CommandDescription
						Template.TargetID.Value = TargetPlayer.UserId
						Template.Command.Value = v.CommandName
						Template.Parent = MainFrame.PlayerEditPage.ListFrame.ScrollingFrame
						break
					end
					break
				end
			end
		end
	end
end)