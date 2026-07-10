local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local PanelSettings = require(AdminPanelRS.PanelSettings)
local GlobalEvents = AdminPanelRS.GlobalEvents
local MainFrame = script.Parent.Parent.Parent.Parent.Parent.Parent.Parent

script.Parent.MouseButton1Click:Connect(function()
	for i,v in pairs(MainFrame.PunishSeePage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local TargetPlayer = Players:GetPlayerByUserId(script.Parent.Parent.Parent.Name)
	if TargetPlayer then
		local PunishData = GlobalEvents.RemoteFunction:InvokeServer("UXPPunishData", TargetPlayer.UserId)
		if PunishData == nil then return end
		MainFrame.PunishSeePage.ProfileFrame.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..TargetPlayer.UserId.."&width=150&height=150"
		MainFrame.PunishSeePage.NameLabel.Text = string.gsub(PanelSettings.Messages.SelectedText, "$playername", Players.LocalPlayer.Name)
		MainFrame.PunishSeePage.UserIDLabel.Text = string.gsub(PanelSettings.Messages.UserID, "$userid", Players.LocalPlayer.UserId)
		MainFrame.PunishSeePage.Visible = true
		MainFrame.PunishSeePage:SetAttribute("Name", script.Parent.Parent.Parent.Name)
		MainFrame.PlayersPage.Visible = false
		for i = #PunishData["PunishmentLogs"], 1, -1 do
			local v = PunishData["PunishmentLogs"][i]
			local Template = MainFrame.PunishSeePage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
			Template.TitleLabel.Text = v["Admin"].." - "..v["Type"]
			Template.DateLabel.Text = v["Time"]
			Template.ValueLabel.Text = v["Reason"].." - "..v["duration"]
			Template:SetAttribute("Type", v["Type"])
			Template.Parent = MainFrame.PunishSeePage.ListFrame.ScrollingFrame
		end
	end
end)