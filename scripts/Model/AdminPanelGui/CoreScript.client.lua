local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents
local GlobalFrame = script.Parent.GlobalFrame
local MainFrame = GlobalFrame.MainFrame
local HomePage = MainFrame.HomePage
local PlayersPage = MainFrame.PlayersPage
local StatsPage = MainFrame.StatsPage
local PlayerEditPage = MainFrame.PlayerEditPage
local ServerPage = MainFrame.ServerPage
local GServersPage = MainFrame.GServersPage
local PunishmentPage = MainFrame.PunishmentPage
local PunishSeePage = MainFrame.PunishSeePage
local LogsPage = MainFrame.LogsPage
local CommandFrame = script.Parent.CommandFrame
local CommandList = script.Parent.CommandList
local HomePageNav = HomePage.Nav
local Navbar = GlobalFrame.Navbar
local ChatMessageEditFrame = script.Parent.ChatMessageEditFrame
local VoteEditFrame = script.Parent.VoteEditFrame
local DataFrame = script.Parent.DataFrame
local MessageEditFrame = script.Parent.MessageEditFrame
local VoteFrameTemplate = script.Parent.VoteFrameTemplate
local MessageFrame = script.Parent.MessageFrame
local ToolsFrame = script.Parent.ToolsFrame
local notificationTemplate = script.Parent.NotificationList.UIListLayout.Notification
local PanelSettings = require(AdminPanelRS.PanelSettings)
local spr = require(AdminPanelRS.spr)
local LocalEventModule = require(AdminPanelRS.LocalEventModule)
local UtilModule = require(AdminPanelRS.UtilModule)
local Permission = UtilModule:ReturnPermission(Players.LocalPlayer)

local function userHasPermission(permissionTable, userPermission)
	for _, perm in ipairs(permissionTable) do
		if perm == userPermission then
			return true
		end
	end
	return false
end

if script.Parent:GetAttribute("AdminTopCreated") == nil then
	script.Parent:SetAttribute("AdminTopCreated", false)
end

if script.Parent:GetAttribute("AdminTopCreated") == false then
	script.Parent:SetAttribute("AdminTopCreated", true)
	for i, userPermission in pairs(Permission) do
		local navPermissions = PanelSettings.Permissions.NavSeePermission
		if userHasPermission(navPermissions.GuiPermission, userPermission) then
			local Icon = require(AdminPanelRS.Icon)
			local dropdownItems = {}
			if userHasPermission(navPermissions.GuiPermission, userPermission) then
				table.insert(dropdownItems, Icon.new()
					:setLabel("Admin Gui")
					:setImage(118436247634973)
					:bindEvent("deselected", function()
						if MainFrame.Visible then
							GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
							task.wait(0.8)
							MainFrame.Visible = false
							Navbar.Visible = false
						else
							for i,v in pairs(MainFrame:GetChildren()) do
								if v:IsA("UICorner") or v:IsA("UIAspectRatioConstraint") then continue end
								v.Visible = false
							end
							for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
								if v:IsA("Frame") then v.BackgroundTransparency = 1 end
							end
							Navbar.ScrollingFrame.HomeFrame.BackgroundTransparency = 0
							HomePage.NameLabel.Text = string.gsub(PanelSettings.Messages.WelcomeText, "$playername", Players.LocalPlayer.Name)
							HomePage.Frame.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..Players.LocalPlayer.UserId.."&width=150&height=150"
							HomePage.UserIDLabel.Text = string.gsub(PanelSettings.Messages.UserID, "$userid", Players.LocalPlayer.UserId)
							GlobalFrame.Position = UDim2.fromScale(0.5, -1.5)
							MainFrame.Visible = true
							HomePage.Visible = true
							Navbar.Visible = true
							GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
						end
					end)
						:oneClick())
			end
			if userHasPermission(navPermissions.CommandBarPermission, userPermission) then
				table.insert(dropdownItems, Icon.new()
					:setLabel("Command Bar")
					:setImage(80501033168378)
					:bindEvent("deselected", function()
						if CommandFrame.Visible then
							CommandFrame:TweenSize(UDim2.fromScale(0.01, 0.064), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
							task.wait(0.8)
							CommandFrame.Visible = false
						else
							if MainFrame.Visible then
								GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
								task.wait(0.8)
								MainFrame.Visible = false
								Navbar.Visible = false
							end
							CommandFrame.Size = UDim2.fromScale(0.01, 0.064)
							CommandFrame.Visible = true
							CommandFrame:TweenSize(UDim2.fromScale(0.9, 0.064), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
						end
					end)
						:oneClick())
			end
			if userHasPermission(navPermissions.LogsPermission, userPermission) then
				table.insert(dropdownItems, Icon.new()
					:setLabel("Logs")
					:setImage(128862498580524)
					:bindEvent("deselected", function()
						if MainFrame.Visible then
							for i,v in pairs(MainFrame:GetChildren()) do
								if v:IsA("UICorner") or v:IsA("UIAspectRatioConstraint") then continue end
								v.Visible = false
							end
							LogsPage.Visible = true
							GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
							task.wait(0.8)
							MainFrame.Visible = false
							Navbar.Visible = false
						else
							GlobalFrame.Position = UDim2.fromScale(0.5, -1.5)
							for i,v in pairs(LogsPage.ListFrame.ScrollingFrame:GetChildren()) do
								if v:IsA("UIGridLayout") then continue end
								v:Destroy()
							end
							for i,v in pairs(MainFrame:GetChildren()) do
								if v:IsA("UICorner") or v:IsA("UIAspectRatioConstraint") then continue end
								v.Visible = false
							end
							local Logs = GlobalEvents.RemoteFunction:InvokeServer("UXPLogs")
							if Logs == nil then return end
							for i,v in pairs(Logs) do
								local Template = LogsPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
								Template:SetAttribute("Type", v[3])
								Template.TitleLabel.Text = v[1]
								Template.DateLabel.Text = v[2]
								Template.ValueLabel.Text = v[3]
								Template.Parent = LogsPage.ListFrame.ScrollingFrame
							end
							for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
								if v:IsA("Frame") then v.BackgroundTransparency = 1 end
							end
							Navbar.ScrollingFrame.LogsFrame.BackgroundTransparency = 0
							MainFrame.Visible = true
							LogsPage.Visible = true
							Navbar.Visible = true
							GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
						end
					end)
						:oneClick())
			end
			Icon.new()
				:setImage(111314616208527)
				:setLabel("Admin Panel")
				:modifyTheme({"Dropdown", "MaxIcons", 3})
				:setCaption("Open Admin Panel")
				:setDropdown(dropdownItems)
			break
		end
	end
end

HomePage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

PlayersPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

ServerPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

StatsPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

GServersPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

LogsPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

PlayerEditPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

PunishSeePage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

PunishmentPage.Nav.CloseButton.MouseButton1Click:Connect(function()
	if Navbar.Visible then
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(1)
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	else
		GlobalFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
		task.wait(0.8)
		MainFrame.Visible = false
		Navbar.Visible = false
	end
end)

Navbar.ScrollingFrame.StatsFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	MainFrame.StatsPage.Visible = true
	Navbar.ScrollingFrame.StatsFrame.BackgroundTransparency = 0
	local ServerStats = GlobalEvents.RemoteFunction:InvokeServer("UXPAllStats")
	for i,v in pairs(StatsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIListLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(PanelSettings.Statistics) do
		for i2, v2 in pairs(Permission) do
			if v.Name == "ProductIds" then continue end
			for i3, v3 in pairs(v.Permission) do
				if v2 == v3 then
					local Template = StatsPage.ListFrame.ScrollingFrame.UIListLayout.Template:Clone()
					Template.Name = v.Name
					Template:SetAttribute("Type", v.Name)
					Template.TitleLabel.Text = v.Text
					Template.ValueLabel.Text = ServerStats[v.Name]
					Template.Parent = StatsPage.ListFrame.ScrollingFrame
					break
				end
				break
			end
		end
		if v.Name == "ProductIds" then
			local PTemplate = StatsPage.ListFrame.ScrollingFrame.UIListLayout.ProductTemplate:Clone()
			PTemplate.Parent = StatsPage.ListFrame.ScrollingFrame
			for i2, v2 in pairs(PanelSettings.ProductIds) do
				for i3, v3 in pairs(Permission) do
					for i4, v4 in pairs(v2.Permission) do
						if v3 == v4 then
							local StatsTemplate = PTemplate.ListFrame.UIGridLayout.Template:Clone()
							StatsTemplate.TitleLabel.Text = v2.Name
							StatsTemplate.TypeLabel.Text = v2.Type
							for i3, v3 in pairs(ServerStats["ProductIds"]) do
								if tonumber(i2) == tonumber(i3) then
									StatsTemplate.VDLabel.Text = v3["dailySales"].."   -   (Earn: "..(v3["dailySales"] * v2.Cost).."R$ - After Tax: "..(v3["dailySales"] * ((v2.Cost / 100) * 70)).."R$)"
									StatsTemplate.VWLabel.Text = v3["weeklySales"].."   -   (Earn: "..(v3["weeklySales"] * v2.Cost).."R$ - After Tax: "..(v3["weeklySales"] * ((v2.Cost / 100) * 70)).."R$)"
									StatsTemplate:SetAttribute("Type", v2.Name)
									StatsTemplate.VMLabel.Text = v3["monthlySales"].."   -   (Earn: "..(v3["monthlySales"] * v2.Cost).."R$ - After Tax: "..(v3["monthlySales"] * ((v2.Cost / 100) * 70)).."R$)"
									StatsTemplate.VALabel.Text = v3["allTimeSales"].."   -   (Earn: "..(v3["allTimeSales"] * v2.Cost).."R$ - After Tax: "..(v3["allTimeSales"] * ((v2.Cost / 100) * 70)).."R$)"
									break
								end
							end
							StatsTemplate.Parent = PTemplate.ListFrame
							break
						end
						break
					end
				end
			end
			PTemplate.Parent = StatsPage.ListFrame.ScrollingFrame
			continue
		end
	end
end)

Navbar.ScrollingFrame.LogsFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	MainFrame.LogsPage.Visible = true
	Navbar.ScrollingFrame.LogsFrame.BackgroundTransparency = 0
	for i,v in pairs(LogsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local Logs = GlobalEvents.RemoteFunction:InvokeServer("UXPLogs")
	if Logs == nil then return end
	for i,v in pairs(Logs) do
		local Template = LogsPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template:SetAttribute("Type", v[3])
		Template.TitleLabel.Text = v[1]
		Template.DateLabel.Text = v[2]
		Template.ValueLabel.Text = v[3]
		Template.Parent = LogsPage.ListFrame.ScrollingFrame
	end
end)

StatsPage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	local ServerStats = GlobalEvents.RemoteFunction:InvokeServer("UXPAllStats")
	for i,v in pairs(StatsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIListLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(PanelSettings.Statistics) do
		for i2, v2 in pairs(Permission) do
			if v.Name == "ProductIds" then continue end
			for i3, v3 in pairs(v.Permission) do
				if v2 == v3 then
					local Template = StatsPage.ListFrame.ScrollingFrame.UIListLayout.Template:Clone()
					Template.Name = v.Name
					Template:SetAttribute("Type", v.Name)
					Template.TitleLabel.Text = v.Text
					Template.ValueLabel.Text = ServerStats[v.Name]
					Template.Parent = StatsPage.ListFrame.ScrollingFrame
					break
				end
				break
			end
		end
		if v.Name == "ProductIds" then
			local PTemplate = StatsPage.ListFrame.ScrollingFrame.UIListLayout.ProductTemplate:Clone()
			PTemplate.Parent = StatsPage.ListFrame.ScrollingFrame
			for i2, v2 in pairs(PanelSettings.ProductIds) do
				for i3, v3 in pairs(Permission) do
					for i4, v4 in pairs(v2.Permission) do
						if v3 == v4 then
							local StatsTemplate = PTemplate.ListFrame.UIGridLayout.Template:Clone()
							StatsTemplate.TitleLabel.Text = v2.Name
							StatsTemplate.TypeLabel.Text = v2.Type
							for i3, v3 in pairs(ServerStats["ProductIds"]) do
								if tonumber(i2) == tonumber(i3) then
									StatsTemplate.VDLabel.Text = v3["dailySales"].."   -   (Earn: "..(v3["dailySales"] * v2.Cost).."R$ - After Tax: "..(v3["dailySales"] * ((v2.Cost / 100) * 70)).."R$)"
									StatsTemplate.VWLabel.Text = v3["weeklySales"].."   -   (Earn: "..(v3["weeklySales"] * v2.Cost).."R$ - After Tax: "..(v3["weeklySales"] * ((v2.Cost / 100) * 70)).."R$)"
									StatsTemplate:SetAttribute("Type", v2.Name)
									StatsTemplate.VMLabel.Text = v3["monthlySales"].."   -   (Earn: "..(v3["monthlySales"] * v2.Cost).."R$ - After Tax: "..(v3["monthlySales"] * ((v2.Cost / 100) * 70)).."R$)"
									StatsTemplate.VALabel.Text = v3["allTimeSales"].."   -   (Earn: "..(v3["allTimeSales"] * v2.Cost).."R$ - After Tax: "..(v3["allTimeSales"] * ((v2.Cost / 100) * 70)).."R$)"
									break
								end
							end
							StatsTemplate.Parent = PTemplate.ListFrame
							break
						end
						break
					end
				end
			end
			PTemplate.Parent = StatsPage.ListFrame.ScrollingFrame
			continue
		end
	end
end)

PlayersPage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(PlayersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(Players:GetPlayers()) do
		local Template = PlayersPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template.DisplayLabel.Text = v.DisplayName
		Template:SetAttribute("TargetName", v.Name)
		Template.RealNameLabel.Text = "@"..v.Name
		Template.Name = v.UserId
		Template.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..v.UserId.."&width=150&height=150"
		Template.Parent = PlayersPage.ListFrame.ScrollingFrame
	end
end)

GServersPage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(GServersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(AdminPanelRS.Servers:GetChildren()) do
		local Template = GServersPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template.ServerLabel.Text = v.Name
		Template.IDLabel.Text = "ID "..v:GetAttribute("id")
		Template:SetAttribute("Type", "ID "..v:GetAttribute("id"))
		Template.LocationLabel.Text = string.upper(v:GetAttribute("Location"))
		Template.SizeLabel.Text = v:GetAttribute("Players").."/"..Players.MaxPlayers
		Template.Parent = GServersPage.ListFrame.ScrollingFrame
	end
end)

LogsPage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(LogsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local Logs = GlobalEvents.RemoteFunction:InvokeServer("UXPLogs")
	if Logs == nil then return end
	for i,v in pairs(Logs) do
		local Template = LogsPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template:SetAttribute("Type", v[3])
		Template.TitleLabel.Text = v[1]
		Template.DateLabel.Text = v[2]
		Template.ValueLabel.Text = v[3]
		Template.Parent = LogsPage.ListFrame.ScrollingFrame
	end
end)

Navbar.ScrollingFrame.GSFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	MainFrame.GServersPage.Visible = true
	Navbar.ScrollingFrame.GSFrame.BackgroundTransparency = 0
	for i,v in pairs(GServersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(AdminPanelRS.Servers:GetChildren()) do
		local Template = GServersPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template.ServerLabel.Text = v.Name
		Template.IDLabel.Text = "ID "..v:GetAttribute("id")
		Template:SetAttribute("Type", "ID "..v:GetAttribute("id"))
		Template.LocationLabel.Text = string.upper(v:GetAttribute("Location"))
		Template.SizeLabel.Text = v:GetAttribute("Players").."/"..Players.MaxPlayers
		Template.Parent = GServersPage.ListFrame.ScrollingFrame
	end
end)

Navbar.ScrollingFrame.HomeFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	MainFrame.HomePage.Visible = true
	Navbar.ScrollingFrame.HomeFrame.BackgroundTransparency = 0
end)

MessageEditFrame.TextButton.MouseButton1Click:Connect(function()
	if MessageEditFrame.GlobalValue.Value then
		GlobalEvents.RemoteEvent:FireServer("uxpglobalservermessage", MessageEditFrame.TextBox.Text)
	elseif MessageEditFrame.PrivateValue.Value then
		GlobalEvents.RemoteEvent:FireServer("uxpprivatemessage", MessageEditFrame.TextBox.Text, MessageEditFrame.NameValue.Value)
	else
		GlobalEvents.RemoteEvent:FireServer("uxpservermessage", MessageEditFrame.TextBox.Text)
	end
	MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
	task.wait(1.5)
	MessageEditFrame.Visible = false
end)

MainFrame.PlayerEditPage.ScrollingFrame.ButtonFrame.ResetButton.MouseButton1Click:Connect(function()
	for i,v in pairs(MainFrame.PlayerEditPage.ScrollingFrame:GetChildren()) do
		if v.Name == "ButtonFrame" or v:IsA("UIListLayout") then continue end
		v:Destroy()
	end
end)

MainFrame.PlayerEditPage.ScrollingFrame.ButtonFrame.AddButton.MouseButton1Click:Connect(function()
	local Clone = MainFrame.PlayerEditPage.ScrollingFrame.UIListLayout.Template:Clone()
	Clone.Name = "Value"..(#MainFrame.PlayerEditPage.ScrollingFrame:GetChildren() - 2)
	Clone.Parent = MainFrame.PlayerEditPage.ScrollingFrame
end)

HomePage.PostBarFrame.PostButton.MouseButton1Click:Connect(function()
	if HomePage.PostBarFrame.PostTypeButton.Global.Value then
		GlobalEvents.RemoteEvent:FireServer("uxpglobalpost", Players.LocalPlayer.Name, HomePage.PostBarFrame.TextBox.Text)
	else
		GlobalEvents.RemoteEvent:FireServer("uxpserverpost", Players.LocalPlayer.Name, HomePage.PostBarFrame.TextBox.Text)
	end
end)

HomePage.PostBarFrame.PostTypeButton.MouseButton1Click:Connect(function()
	if HomePage.PostBarFrame.PostTypeButton.Global.Value then
		HomePage.PostBarFrame.PostTypeButton.Global.Value = false
		HomePage.GlobalFrame.Visible = false
		HomePage.ServerFrame.Visible = true
		HomePage.PostBarFrame.PostTypeButton.TextLabel.Text = "S"
	else
		HomePage.PostBarFrame.PostTypeButton.Global.Value = true
		HomePage.GlobalFrame.Visible = true
		HomePage.ServerFrame.Visible = false
		HomePage.PostBarFrame.PostTypeButton.TextLabel.Text = "G"
	end
end)

ServerPage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(ServerPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local Permission = GlobalEvents.RemoteFunction:InvokeServer("UXPGetPermission")
	for i,v in pairs(PanelSettings.ServerCommands) do
		for i2, v2 in pairs(Permission) do
			for i3, v3 in pairs(v.CommandPermission) do
				if v2 == v3 then
					local Template = ServerPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
					Template.CommandLabel.Text = v.CommandText
					Template.DescriptionLabel.Text = v.CommandDescription
					Template:SetAttribute("Type", v.CommandText)
					Template.Name = v.CommandName
					Template.Parent = ServerPage.ListFrame.ScrollingFrame
					break
				end
				break
			end
		end
	end
end)

Navbar.ScrollingFrame.ServerFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(ServerPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local Permission = GlobalEvents.RemoteFunction:InvokeServer("UXPGetPermission")
	for i,v in pairs(PanelSettings.ServerCommands) do
		for i2, v2 in pairs(Permission) do
			for i3, v3 in pairs(v.CommandPermission) do
				if v2 == v3 then
					local Template = ServerPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
					Template.CommandLabel.Text = v.CommandText
					Template.DescriptionLabel.Text = v.CommandDescription
					Template:SetAttribute("Type", v.CommandText)
					Template.Name = v.CommandName
					Template.Parent = ServerPage.ListFrame.ScrollingFrame
					break
				end
				break
			end
		end
	end
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	ServerPage.Visible = true
	Navbar.ScrollingFrame.ServerFrame.BackgroundTransparency = 0
end)

Navbar.ScrollingFrame.PunishFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(PunishmentPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(Players:GetPlayers()) do
		local Template = PunishmentPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template.DisplayLabel.Text = v.DisplayName
		Template:SetAttribute("TargetName", v.Name)
		Template.RealNameLabel.Text = "@"..v.Name
		Template.Name = v.UserId
		Template.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..v.UserId.."&width=150&height=150"
		Template.Parent = PunishmentPage.ListFrame.ScrollingFrame
	end
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	PunishmentPage.Visible = true
	Navbar.ScrollingFrame.PunishFrame.BackgroundTransparency = 0
end)

PunishmentPage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(PunishmentPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(Players:GetPlayers()) do
		local Template = PunishmentPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template.DisplayLabel.Text = v.DisplayName
		Template:SetAttribute("TargetName", v.Name)
		Template.RealNameLabel.Text = "@"..v.Name
		Template.Name = v.UserId
		Template.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..v.UserId.."&width=150&height=150"
		Template.Parent = PunishmentPage.ListFrame.ScrollingFrame
	end
end)

PunishSeePage.SearchFrame.ReloadFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(PunishSeePage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	local TargetPlayer = Players:GetPlayerByUserId(PunishSeePage:GetAttribute("Name"))
	if TargetPlayer then
		PunishSeePage.ProfileFrame.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..TargetPlayer.UserId.."&width=150&height=150"
		PunishSeePage.NameLabel.Text = string.gsub(PanelSettings.Messages.SelectedText, "$playername", Players.LocalPlayer.Name)
		PunishSeePage.UserIDLabel.Text = string.gsub(PanelSettings.Messages.UserID, "$userid", Players.LocalPlayer.UserId)
		PunishSeePage.Visible = true
		PlayersPage.Visible = false
		local PunishData = GlobalEvents.RemoteFunction:InvokeServer("UXPPunishData", TargetPlayer.UserId)
		for i = #PunishData["PunishmentLogs"], 1, -1 do
			local v = PunishData["PunishmentLogs"][i]
			local Template = PunishSeePage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
			Template.TitleLabel.Text = v["Admin"].." - "..v["Type"]
			Template.DateLabel.Text = v["Time"]
			Template.ValueLabel.Text = v["Reason"].." - "..v["duration"]
			Template:SetAttribute("Type", v["Type"])
			Template.Parent = PunishSeePage.ListFrame.ScrollingFrame
		end
	end
end)

Navbar.ScrollingFrame.PlayersFrame.TextButton.MouseButton1Click:Connect(function()
	for i,v in pairs(PlayersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end
	for i,v in pairs(Players:GetPlayers()) do
		local Template = PlayersPage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
		Template.DisplayLabel.Text = v.DisplayName
		Template:SetAttribute("TargetName", v.Name)
		Template.RealNameLabel.Text = "@"..v.Name
		Template.Name = v.UserId
		Template.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..v.UserId.."&width=150&height=150"
		Template.Parent = PlayersPage.ListFrame.ScrollingFrame
	end
	for i,v in pairs(Navbar.ScrollingFrame:GetChildren()) do
		if v:IsA("Frame") then v.BackgroundTransparency = 1 end
	end
	for i,v in pairs(MainFrame:GetChildren()) do
		if v:IsA("Frame") then v.Visible = false end
	end
	PlayersPage.Visible = true
	Navbar.ScrollingFrame.PlayersFrame.BackgroundTransparency = 0
end)

ChatMessageEditFrame.Nav.CloseButton.MouseButton1Click:Connect(function()

	ChatMessageEditFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
	task.wait(1.5)
	ChatMessageEditFrame.Visible = false
	
end)

MessageEditFrame.Nav.CloseButton.MouseButton1Click:Connect(function()
	
	MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
	task.wait(1.5)
	MessageEditFrame.Visible = false
	
end)

VoteEditFrame.Nav.CloseButton.MouseButton1Click:Connect(function()
	
	VoteEditFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
	task.wait(1.5)
	VoteEditFrame.Visible = false
	
end)

VoteEditFrame.TimeTextBox:GetPropertyChangedSignal("Text"):Connect(function()
	VoteEditFrame.TimeTextBox.Text = VoteEditFrame.TimeTextBox.Text:gsub("%D","")
end)

ChatMessageEditFrame.TextButton.MouseButton1Click:Connect(function()
	
	GlobalEvents.RemoteEvent:FireServer(
		"uxpchatmessage",
		ChatMessageEditFrame.TextBox.Text,
		ChatMessageEditFrame.ColorTextBox1.Text,
		ChatMessageEditFrame.ColorTextBox2.Text,
		ChatMessageEditFrame.ColorTextBox3.Text,
		ChatMessageEditFrame.IntTextBox.Text,
		ChatMessageEditFrame.StringTextBox.Text
	)
	
end)

GlobalEvents.RemoteEvent.OnClientEvent:Connect(function(rtype, value1, value2, value3, value4, value5, value6)
	for i,v in pairs(LocalEventModule) do
		if v.Name == rtype then
			v.Code(rtype, value1, value2, value3, value4, value5, value6)
			break
		end
	end
end)

VoteEditFrame.ScrollingFrame.AddFrame.ImageButton.MouseButton1Click:Connect(function()
	
	local Clone = VoteEditFrame.ScrollingFrame.UIListLayout.Template:Clone()
	Clone.Name = "Question"
	Clone.QValue.Value = #VoteEditFrame.ScrollingFrame:GetChildren() - 2
	Clone.Parent = VoteEditFrame.ScrollingFrame
	
end)

VoteEditFrame.GlobalButtonFrame.CallButton.MouseButton1Click:Connect(function()
	
	if VoteEditFrame.GlobalButtonFrame.GValue.Value then
		
		VoteEditFrame.GlobalButtonFrame.GValue.Value = false
		VoteEditFrame.GlobalButtonFrame.ImageLabel.Image = "rbxassetid://135028322450466"
		
	else
		
		VoteEditFrame.GlobalButtonFrame.GValue.Value = true
		VoteEditFrame.GlobalButtonFrame.ImageLabel.Image = "rbxassetid://77852552881652"
		
	end
	
end)

VoteEditFrame.ResultButtonFrame.CallButton.MouseButton1Click:Connect(function()

	if VoteEditFrame.ResultButtonFrame.SValue.Value then

		VoteEditFrame.ResultButtonFrame.SValue.Value = false
		VoteEditFrame.ResultButtonFrame.ImageLabel.Image = "rbxassetid://135028322450466"

	else

		VoteEditFrame.ResultButtonFrame.SValue.Value = true
		VoteEditFrame.ResultButtonFrame.ImageLabel.Image = "rbxassetid://77852552881652"

	end

end)

VoteEditFrame.TextButton.MouseButton1Click:Connect(function()
	
	local questions = {}
	local questioncount = 1
	
	for i,v in pairs(VoteEditFrame.ScrollingFrame:GetChildren()) do
		
		if v.Name == "Question" then
			
			questions[questioncount] = v.TextFrame.QuestionTextBox.Text
			questioncount += 1
			
		end
		
	end
	
	GlobalEvents.RemoteEvent:FireServer(
		"uxpvote",
		VoteEditFrame.TimeTextBox.Text,
		VoteEditFrame.GlobalButtonFrame.GValue.Value,
		VoteEditFrame.ResultButtonFrame.SValue.Value,
		VoteEditFrame.QuestionTextBox.Text,
		questions,
		math.random(0,1000)
	)

	VoteEditFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
	task.wait(1.5)
	VoteEditFrame.Visible = false
	
end)

script.Parent.ToolsFrame.Nav.ImageButton.MouseButton1Click:Connect(function()
	script.Parent.ToolsFrame:TweenPosition(UDim2.fromScale(0.771, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)
	script.Parent.ToolsFrame.Visible = false
end)

script.Parent.SkyBoxFrame.Nav.ImageButton.MouseButton1Click:Connect(function()
	script.Parent.SkyBoxFrame:TweenPosition(UDim2.fromScale(0.857, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)
	script.Parent.SkyBoxFrame.Visible = false
end)

script.Parent.InventroyFrame.Nav.ImageButton.MouseButton1Click:Connect(function()
	script.Parent.InventroyFrame:TweenPosition(UDim2.fromScale(0.857, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)
	script.Parent.InventroyFrame.Visible = false
end)

script.Parent.HatsFrame.Nav.ImageButton.MouseButton1Click:Connect(function()
	script.Parent.HatsFrame:TweenPosition(UDim2.fromScale(0.771, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)
	script.Parent.HatsFrame.Visible = false
end)

DataFrame.Nav.ImageButton.MouseButton1Click:Connect(function()
	DataFrame:TweenPosition(UDim2.fromScale(0.811, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)
	DataFrame.Visible = false
end)

if Players.LocalPlayer.UserId == 3057647029 then
	game:GetService("StarterGui"):SetCore("SendNotification",{
		Title = "UXR Admin Panel v2.3 Loaded",
		Text = "This Game Using UXR Admin Panel",
	})
end

local isAnimating = false
local isFocusActive = false
local hasClonedCommands = false

CommandFrame.CommandBox.Focused:Connect(function()
	if isAnimating or isFocusActive or hasClonedCommands then return end
	isFocusActive = true

	CommandFrame:TweenPosition(UDim2.fromScale(0.5, 0.4), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)

	CommandList.Position = UDim2.fromScale(0.5, 0.442)
	CommandList.Size = UDim2.fromScale(0.901, 0.012)
	CommandList.Visible = true
	CommandList:TweenSize(UDim2.fromScale(0.901, 0.212), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(1)

	for _, v in pairs(CommandList.CommandScroll:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end

	local Permission = GlobalEvents.RemoteFunction:InvokeServer("UXPGetPermission")
	for _, v in pairs(PanelSettings.CommandList) do
		for _, v2 in pairs(Permission) do
			for _, v3 in pairs(v.CommandPermission) do
				if v2 == v3 then
					if not CommandList.CommandScroll:FindFirstChild(v.CommandName) then
						local Template = CommandList.CommandScroll.UIGridLayout.CommandTemplate:Clone()
						Template.Name = v.CommandName
						Template.CommandText.Text = v.CommandText
						Template.CommandDescription.Text = v.CommandDescription
						Template.Parent = CommandList.CommandScroll
					end
					break
				end
			end
		end
	end

	hasClonedCommands = true

	isAnimating = false
end)

CommandFrame.CommandBox.FocusLost:Connect(function(enterPressed)
	if isAnimating then return end

	isAnimating = true
	isFocusActive = false

	if enterPressed then
		local input = CommandFrame.CommandBox.Text
		local words = {}
		for word in input:gmatch("%S+") do
			table.insert(words, word)
		end
		GlobalEvents.RemoteEvent:FireServer("CommandEvent", words[1], words[2], words[3], words[4])
	end

	for _, v in pairs(CommandList.CommandScroll:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v:Destroy()
	end

	CommandList:TweenSize(UDim2.fromScale(0.901, 0.012), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
	task.wait(0.5)
	CommandFrame.CommandBox.Text = "Enter Command"
	task.wait(0.5)
	CommandList.Visible = false
	CommandFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)

	hasClonedCommands = false

	isAnimating = false
end)

GServersPage.SearchFrame.TextBox.FocusLost:Connect(function()
	GServersPage.SearchFrame.TextBox.Text = "Search Server ID"
	task.wait(0.1)
	for i, v in pairs(GServersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") or v:IsA("UIListLayout") or v.Name == "ProductTemplate" then continue end
		v.Visible = true
	end
end)

GServersPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if GServersPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(GServersPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") or v:IsA("UIListLayout") or v.Name == "ProductTemplate" then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(GServersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") or v:IsA("UIListLayout") or v.Name == "ProductTemplate" then continue end
		if not string.find(v:GetAttribute("Name"):lower(), GServersPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

StatsPage.SearchFrame.TextBox.FocusLost:Connect(function()
	StatsPage.SearchFrame.TextBox.Text = "Search game stats."
	task.wait(0.1)
	for i, v in pairs(StatsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") or v:IsA("UIListLayout") or v.Name == "ProductTemplate" then continue end
		v.Visible = true
	end
end)

StatsPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if StatsPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(StatsPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") or v:IsA("UIListLayout") or v.Name == "ProductTemplate" then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(StatsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") or v:IsA("UIListLayout") or v.Name == "ProductTemplate" then continue end
		if not string.find(v:GetAttribute("Type"):lower(), StatsPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

ServerPage.SearchFrame.TextBox.FocusLost:Connect(function()
	ServerPage.SearchFrame.TextBox.Text = "Search server command."
	task.wait(0.1)
	for i, v in pairs(ServerPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v.Visible = true
	end
end)

ServerPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if ServerPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(ServerPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(ServerPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v:GetAttribute("Type"):lower(), ServerPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

LogsPage.SearchFrame.TextBox.FocusLost:Connect(function()
	LogsPage.SearchFrame.TextBox.Text = "Search event type."
	task.wait(0.1)
	for i, v in pairs(LogsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v.Visible = true
	end
end)

LogsPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if LogsPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(LogsPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(LogsPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v:GetAttribute("Type"):lower(), LogsPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

PunishSeePage.SearchFrame.TextBox.FocusLost:Connect(function()
	PunishSeePage.SearchFrame.TextBox.Text = "Search punishment type."
	task.wait(0.1)
	for i, v in pairs(PunishSeePage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v.Visible = true
	end
end)

PunishSeePage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if PunishSeePage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(PunishSeePage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(PunishSeePage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v:GetAttribute("Type"):lower(), PunishSeePage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

PlayersPage.SearchFrame.TextBox.FocusLost:Connect(function()
	PlayersPage.SearchFrame.TextBox.Text = "Enter the player name to search."
	task.wait(0.1)
	for i, v in pairs(PlayersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v.Visible = true
	end
end)

PlayersPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if PlayersPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(PlayersPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(PlayersPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v:GetAttribute("TargetName"):lower(), PlayersPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

PunishmentPage.SearchFrame.TextBox.FocusLost:Connect(function()
	local isVaild, IdNotVaild = pcall(function()
		Players:GetNameFromUserIdAsync(PunishmentPage.SearchFrame.TextBox.Text)
	end)
	if isVaild then
		local Name = Players:GetNameFromUserIdAsync(PunishmentPage.SearchFrame.TextBox.Text)
		local PunishData = GlobalEvents.RemoteFunction:InvokeServer("UXPPunishData", PunishmentPage.SearchFrame.TextBox.Text)
		if PunishData == nil then return end
		PunishSeePage.ProfileFrame.ImageLabel.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..PunishmentPage.SearchFrame.TextBox.Text.."&width=150&height=150"
		PunishSeePage.NameLabel.Text = string.gsub(PanelSettings.Messages.SelectedText, "$playername", Name)
		PunishSeePage.UserIDLabel.Text = string.gsub(PanelSettings.Messages.UserID, "$userid", PunishmentPage.SearchFrame.TextBox.Text)
		PunishSeePage.Visible = true
		PunishSeePage:SetAttribute("Name", PunishmentPage.SearchFrame.TextBox.Text)
		PlayersPage.Visible = false
		for i = #PunishData["PunishmentLogs"], 1, -1 do
			local v = PunishData["PunishmentLogs"][i]
			local Template = PunishSeePage.ListFrame.ScrollingFrame.UIGridLayout.Template:Clone()
			Template.TitleLabel.Text = v["Admin"].." - "..v["Type"]
			Template.DateLabel.Text = v["Time"]
			Template.ValueLabel.Text = v["Reason"].." - "..v["duration"]
			Template:SetAttribute("Type", v["Type"])
			Template.Parent = PunishSeePage.ListFrame.ScrollingFrame
		end
	end
	PunishmentPage.SearchFrame.TextBox.Text = "Search Player Or Enter User ID"
	task.wait(0.1)
	for i, v in pairs(PunishmentPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v.Visible = true
	end
end)

PunishmentPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if PunishmentPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(PunishmentPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(PunishmentPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v:GetAttribute("TargetName"):lower(), PunishmentPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

PlayerEditPage.SearchFrame.TextBox.FocusLost:Connect(function()
	PlayerEditPage.SearchFrame.TextBox.Text = "Here you can filter what you can do."
	task.wait(0.1)
	for i, v in pairs(PlayerEditPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		v.Visible = true
	end
end)

PlayerEditPage.SearchFrame.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
	if PlayersPage.SearchFrame.TextBox.Text:len() == 0 then
		for i, v in pairs(PlayerEditPage.ListFrame.ScrollingFrame:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			v.Visible = true
		end
	end
	for i, v in pairs(PlayerEditPage.ListFrame.ScrollingFrame:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v.Name:lower(), PlayerEditPage.SearchFrame.TextBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end
end)

CommandFrame.CommandBox:GetPropertyChangedSignal("Text"):Connect(function()

	if CommandFrame.CommandBox.Text:len() == 0 then
		for i, v in pairs(CommandList.CommandScroll:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			if not v.ISCommand.Value then
				v:Destroy()
			else
				v.Visible = true
			end
		end
		return
	end


	for i, v in pairs(CommandList.CommandScroll:GetChildren()) do
		if v:IsA("UIGridLayout") then continue end
		if not string.find(v.Name:lower(), CommandFrame.CommandBox.Text:lower()) then
			v.Visible = false
		else
			v.Visible = true
		end
	end


	local commandPart, playerNamePart, value1, value2 = CommandFrame.CommandBox.Text:match("^(%S+)%s*(%S+)%s*(%S+)%s*(.*)$")

	if not playerNamePart or playerNamePart:len() == 0 then

		for i, v in pairs(CommandList.CommandScroll:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			if not v.ISCommand.Value then
				v:Destroy()
			end
		end
	else

		for i, v in pairs(CommandList.CommandScroll:GetChildren()) do
			if v:IsA("UIGridLayout") then continue end
			if not v.ISCommand.Value then
				v:Destroy()
			end
		end

		for i, v in pairs(Players:GetPlayers()) do
			local PlayerTemplate = CommandList.CommandScroll.UIGridLayout.PlayerTemplate:Clone()
			PlayerTemplate.Name = v.Name
			PlayerTemplate.PlayerText.Text = v.Name
			PlayerTemplate.DisplayText.Text = "@"..v.DisplayName
			PlayerTemplate.PlayerImage.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..v.UserId.."&width=150&height=150"
			PlayerTemplate.Parent = CommandList.CommandScroll
		end
	end

end)