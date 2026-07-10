local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local AdminPanelGui = LocalPlayer.PlayerGui.AdminPanelGui
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local GlobalEvents = AdminPanelRS.GlobalEvents
local MainFrame = AdminPanelGui.GlobalFrame.MainFrame
local HomePage = MainFrame.HomePage
local ShutdownFrame = AdminPanelGui.ShutdownFrame
local CommandFrame =AdminPanelGui.CommandFrame
local CommandList = AdminPanelGui.CommandList
local HomePageNav = HomePage.Nav
local Navbar = AdminPanelGui.GlobalFrame.Navbar
local ChatMessageEditFrame = AdminPanelGui.ChatMessageEditFrame
local DataFrame = AdminPanelGui.DataFrame
local MessageEditFrame = AdminPanelGui.MessageEditFrame
local VoteEditFrame = AdminPanelGui.VoteEditFrame
local SkyBoxFrame = AdminPanelGui.SkyBoxFrame
local VoteFrameTemplate = AdminPanelGui.VoteFrameTemplate
local MessageFrame = AdminPanelGui.MessageFrame
local HatsFrame = AdminPanelGui.HatsFrame
local ToolsFrame = AdminPanelGui.ToolsFrame
local PanelSettings = require(script.Parent.PanelSettings)
local spr = require(script.Parent.spr)

local function GetPlayer(player, text)
	local TargetPlayer = nil
	if text == PanelSettings.Localization.Self then return player end 
	for i,v in pairs(game.Players:GetPlayers()) do
		if string.find(v.Name:lower(), text:lower()) then
			if TargetPlayer then
				return false
			end
			TargetPlayer = v
		end
	end
	if TargetPlayer then
		return TargetPlayer
	end
	if not TargetPlayer then
		return nil
	end
end

local function generateSystemMsg(MsgDict: array)

	return '<font color="#'..MsgDict["Color"]..'"><font size="'..MsgDict["FontSize"]..'"><font face="'..MsgDict["Font"]..'">'..MsgDict["Text"]..'</font></font></font>'

end

local serverpostList = {}
local globalpostList = {}
local noclipConnections = {}

local LocalEventModule = {

	{
		Name = "uxpshutdown",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			spr.target(ShutdownFrame, 0.6, 0.5, {
				BackgroundTransparency = 0
			})
			task.wait(0.4)
			spr.target(ShutdownFrame.Pattern, 0.6, 0.5, {
				ImageTransparency = 0.8
			})
			task.wait(0.5)
			ShutdownFrame.RobloxLogo.Visible = true
			ShutdownFrame.ClosingText.Visible = true
			ShutdownFrame.ClosingExtraText.Visible = true
			task.wait(0.1)
			while true do
				spr.target(ShutdownFrame.RobloxLogo, 0.6, 0.5, {
					Rotation = 360
				})
				task.wait(2)
				ShutdownFrame.RobloxLogo.Rotation = 0
			end
		end,
	},

	{
		Name = "uxpglobalpost",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			if #HomePage.GlobalFrame.ScrollingFrame:GetChildren() > 20 then
				globalpostList[1]:Destroy()
				table.remove(globalpostList, 1)
			end
			local Template = HomePage.GlobalFrame.ScrollingFrame.UIGridLayout.Template:Clone()
			Template.NameLabel.Text = value1..":"
			Template.ContentLabel.Text = value2
			Template.Parent = HomePage.GlobalFrame.ScrollingFrame
			table.insert(globalpostList, Template)
		end,
	},
	
	{
		Name = "uxpserverpost",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			if #HomePage.ServerFrame.ScrollingFrame:GetChildren() > 20 then
				serverpostList[1]:Destroy()
				table.remove(serverpostList, 1)
			end
			local Template = HomePage.ServerFrame.ScrollingFrame.UIGridLayout.Template:Clone()
			Template.NameLabel.Text = value1..":"
			Template.ContentLabel.Text = value2
			Template.Parent = HomePage.ServerFrame.ScrollingFrame
			table.insert(serverpostList, Template)
		end,
	},

	{
		Name = "uxpadminunmute",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		end,
	},

	{
		Name = "uxpadminmute",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
		end,
	},
	
	{
		Name = "uxpblur",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local Blur = Lighting:FindFirstChild("UXPBlur")
			if Blur then
				Blur.Size = value3
			else
				local NewBlur = Instance.new("BlurEffect")
				NewBlur.Name = "UXPBlur"
				NewBlur.Size = value1
				NewBlur.Parent = Lighting
			end
		end,
	},

	{
		Name = "uxpview",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				local TargetCharacter = TargetPlayer.Character
				if TargetCharacter then
					workspace.Camera.CameraSubject = TargetCharacter.Humanoid
				end
			end
		end,
	},

	{
		Name = "uxpunview",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = Players.LocalPlayer
			if TargetPlayer then
				local TargetCharacter = TargetPlayer.Character
				if TargetCharacter then
					workspace.Camera.CameraSubject = TargetCharacter.Humanoid
				end
			end
		end,
	},

	{
		Name = "uxpchatmessagealert",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TextChatService = game:GetService("TextChatService")
			local Channel
			if TextChatService:FindFirstChild("TextChannels") then
				local textChannels = TextChatService:FindFirstChild("TextChannels")
				Channel = textChannels:FindFirstChild("RBXSystem")
				if Channel then
					Channel:DisplaySystemMessage(
						generateSystemMsg({
							Text = value1,
							Font = value6,
							Color = Color3.fromRGB(value2, value3, value4):ToHex(),
							FontSize = tonumber(value5),
						})
					)
				end
			end
		end,
	},

	{
		Name = "uxpchatmessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			ChatMessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			ChatMessageEditFrame.Visible = true
			ChatMessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpprivateservermessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageEditFrame.Nav.HeadLabel.Text = "Private Message"
			MessageEditFrame.PrivateValue.Value = true
			MessageEditFrame.NameValue.Value = value1
			MessageEditFrame.Visible = true
			MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},
	
	{
		Name = "uxpunview",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = Players.LocalPlayer
			if TargetPlayer and TargetPlayer.Character then
				workspace.Camera.CameraSubject = TargetPlayer.Character.Humanoid
			end
		end,
	},

	{
		Name = "uxpchatmessagealert",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TextChatService = game:GetService("TextChatService")
			local Channel
			if TextChatService:FindFirstChild("TextChannels") then
				local textChannels = TextChatService:FindFirstChild("TextChannels")
				Channel = textChannels:FindFirstChild("RBXSystem")
				if Channel then
					Channel:DisplaySystemMessage(
						generateSystemMsg({
							Text = value1,
							Font = value6,
							Color = Color3.fromRGB(value2, value3, value4):ToHex(),
							FontSize = tonumber(value5),
						})
					)
				end
			end
		end,
	},

	{
		Name = "uxpchatmessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			ChatMessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			ChatMessageEditFrame.Visible = true
			ChatMessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpprivateservermessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageEditFrame.Nav.HeadLabel.Text = "Private Message"
			MessageEditFrame.PrivateValue.Value = true
			MessageEditFrame.NameValue.Value = value1
			MessageEditFrame.Visible = true
			MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpvotestatus",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local VoteFrame = AdminPanelGui:FindFirstChild(tostring(value2))
			if not VoteFrame then return end
			for questionIndex, voteCount in pairs(value1[3]) do
				for _, voteFrameChild in pairs(VoteFrame.ScrollingFrame:GetChildren()) do
					if voteFrameChild:IsA("UIListLayout") then continue end
					if tostring(voteFrameChild.QValue.Value) == tostring(questionIndex) then
						voteFrameChild.TextLabel.Text = questionIndex..") "..value1[1][questionIndex] .. " (" .. tostring(voteCount) .. ")"
					end
				end
			end
		end,
	},

	{
		Name = "uxpendvote",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local VoteFrame = AdminPanelGui:FindFirstChild(tostring(value1))
			if not VoteFrame then return end
			local number = 0
			local id = 0
			if not value2[3] or not value2[3][1] then VoteFrame.Nav.HeadLabel.Text = "VOTING - DRAW" return end
			for i,v in pairs(value2[3]) do
				if v > id then
					number = v
					id = i
				end
			end
			for i,v in pairs(VoteFrame.ScrollingFrame:GetChildren()) do
				if v:IsA("UIListLayout") then continue end
				if id == v.QValue.Value then
					v.BackgroundColor3 = Color3.new(0.333333, 1, 0)
				end
			end
		end,
	},

	{
		Name = "uxpvote",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local VoteFrame = VoteFrameTemplate:Clone()
			VoteFrame.Parent = AdminPanelGui
			VoteFrame.Global.Value = value2
			VoteFrame.Name = tostring(value6)
			for i,v in pairs(VoteFrame.ScrollingFrame:GetChildren()) do
				if not v:IsA("UIListLayout") then v:Destroy() end
			end
			VoteFrame.QuestionLabel.Text = tostring(value4)
			VoteFrame.VoteID.Value = value6
			for i,v in pairs(value5) do
				local Template = VoteFrame.ScrollingFrame.UIListLayout.Template:Clone()
				Template.TextLabel.Text = i..") "..v.." (0)"
				Template.QValue.Value = i
				Template.Parent = VoteFrame.ScrollingFrame
			end
			VoteFrame.Position = UDim2.fromScale(0.5, -1.5)
			VoteFrame.Visible = true
			VoteFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			for i = value1, 0, -1 do
				task.wait(1)
				VoteFrame.Nav.HeadLabel.Text = "VOTING ("..i..")"
			end
			task.wait(10)
			VoteFrame:Destroy()
		end,
	},

	{
		Name = "uxpvoteedit",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			VoteEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			VoteEditFrame.TimeTextBox.Text = 0
			VoteEditFrame.QuestionTextBox.Text = "Enter Question"
			for i,v in pairs(VoteEditFrame.ScrollingFrame:GetChildren()) do
				if v:IsA("UIListLayout") or v.Name == "ManualFrame" or v.Name == "AddFrame" then continue end
				v:Destroy()
			end
			local Template1 = VoteEditFrame.ScrollingFrame.UIListLayout.Template:Clone()
			local Template2 = VoteEditFrame.ScrollingFrame.UIListLayout.Template:Clone()
			Template1.Name = "Question"
			Template1.QValue.Value = 1
			Template2.Name = "Question"
			Template2.QValue.Value = 2
			Template1.Parent = VoteEditFrame.ScrollingFrame
			Template2.Parent = VoteEditFrame.ScrollingFrame
			VoteEditFrame.Visible = true
			VoteEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpskybox",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			if SkyBoxFrame.Visible then
				SkyBoxFrame:TweenPosition(UDim2.fromScale(0.857, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
				task.wait(1)
				SkyBoxFrame.Visible = false
			else
				SkyBoxFrame.Position = UDim2.fromScale(0.857, 1.5)
				SkyBoxFrame.Visible = true
				SkyBoxFrame:TweenPosition(UDim2.fromScale(0.857, 0.774), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
				for i,v in pairs(SkyBoxFrame.ScrollingFrame:GetChildren()) do
					if v:IsA("UIGridLayout") then continue end
					v:Destroy()
				end
				for i,v in pairs(PanelSettings.SkyboxList) do
					local Template = SkyBoxFrame.ScrollingFrame.UIGridLayout.Template:Clone()
					Template.Name = i
					Template.TextLabel.Text = v.SkyboxName
					Template.Parent = SkyBoxFrame.ScrollingFrame
				end
			end
		end,
	},
	
	{
		Name = "uxpunview",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = Players.LocalPlayer
			if TargetPlayer and TargetPlayer.Character then
				workspace.Camera.CameraSubject = TargetPlayer.Character.Humanoid
			end
		end,
	},

	{
		Name = "uxpchatmessagealert",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TextChatService = game:GetService("TextChatService")
			local Channel
			if TextChatService:FindFirstChild("TextChannels") then
				local textChannels = TextChatService:FindFirstChild("TextChannels")
				Channel = textChannels:FindFirstChild("RBXSystem")
				if Channel then
					Channel:DisplaySystemMessage(
						generateSystemMsg({
							Text = value1,
							Font = value6,
							Color = Color3.fromRGB(value2, value3, value4):ToHex(),
							FontSize = tonumber(value5),
						})
					)
				end
			end
		end,
	},

	{
		Name = "uxpchatmessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			ChatMessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			ChatMessageEditFrame.Visible = true
			ChatMessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpprivateservermessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageEditFrame.Nav.HeadLabel.Text = "Private Message"
			MessageEditFrame.PrivateValue.Value = true
			MessageEditFrame.NameValue.Value = value1
			MessageEditFrame.Visible = true
			MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpglobalservermessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageEditFrame.Nav.HeadLabel.Text = "Global Server Message"
			MessageEditFrame.GlobalValue.Value = true
			MessageEditFrame.PrivateValue.Value = false
			MessageEditFrame.NameValue.Value = ""
			MessageEditFrame.Visible = true
			MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpservermessage",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageEditFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageEditFrame.Nav.HeadLabel.Text = "Server Message"
			MessageEditFrame.GlobalValue.Value = false
			MessageEditFrame.PrivateValue.Value = false
			MessageEditFrame.NameValue.Value = ""
			MessageEditFrame.Visible = true
			MessageEditFrame:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
		end,
	},

	{
		Name = "uxpprivatemessagealert",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageFrame.Visible = true
			MessageFrame:TweenPosition(UDim2.fromScale(0.5, 0.18), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			MessageFrame.TextLabel.Text = value1
			MessageFrame.Nav.HeadLabel.Text = "Private Message"
			MessageFrame.FromLabel.Text = "From "..value2
			task.wait(5)
			MessageFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			task.wait(1.5)
			MessageFrame.Visible = false
		end,
	},

	{
		Name = "uxpglobalservermessagealert",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageFrame.Visible = true
			MessageFrame:TweenPosition(UDim2.fromScale(0.5, 0.18), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			MessageFrame.TextLabel.Text = value2
			MessageFrame.Nav.HeadLabel.Text = "Global Server Message"
			MessageFrame.FromLabel.Text = "From "..value1
			task.wait(5)
			MessageFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			task.wait(1.5)
			MessageFrame.Visible = false
		end,
	},

	{
		Name = "uxpservermessagealert",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			MessageFrame.Position = UDim2.fromScale(0.5, -1.5)
			MessageFrame.Visible = true
			MessageFrame:TweenPosition(UDim2.fromScale(0.5, 0.18), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			MessageFrame.TextLabel.Text = value1
			MessageFrame.Nav.HeadLabel.Text = "Server Message"
			MessageFrame.FromLabel.Text = "From "..value2
			task.wait(5)
			MessageFrame:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
			task.wait(1.5)
			MessageFrame.Visible = false
		end,
	},
	
	{
		Name = "uxpeditdata",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				if DataFrame.Visible then
					DataFrame:TweenPosition(UDim2.fromScale(0.811, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					task.wait(1)
					DataFrame.Visible = false
				else
					DataFrame.Position = UDim2.fromScale(0.811, 1.5)
					DataFrame.Visible = true
					DataFrame:TweenPosition(UDim2.fromScale(0.811, 0.774), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					DataFrame.NameValue.Value = TargetPlayer.Name
					DataFrame.Nav.TextLabel.Text = TargetPlayer.Name.." Data"
					local function ProcessFolder(folder, indentLevel)
						local HeadTemplate = DataFrame.ScrollingFrame.UIGridLayout.HeadTemplate:Clone()
						HeadTemplate.TextLabel.Text = string.rep("     ", indentLevel) .. folder.Name
						HeadTemplate.Parent = DataFrame.ScrollingFrame
						for _, v in pairs(folder:GetChildren()) do
							if v:IsA("ValueBase") then
								local Template = DataFrame.ScrollingFrame.UIGridLayout.Template:Clone()
								Template.TextLabel.Text = v.Name
								Template.Parent = DataFrame.ScrollingFrame
								if v:IsA("IntValue") or v:IsA("NumberValue") then
									Template.IntTextBox.Visible = true
									Template.IntTextBox.Text = v.Value
								end
								if v:IsA("Color3Value") then
									Template.ColorTextBox1.Visible = true
									Template.ColorTextBox2.Visible = true
									Template.ColorTextBox3.Visible = true
									Template.ColorTextBox1.Text = math.floor(v.Value.R * 255)
									Template.ColorTextBox2.Text = math.floor(v.Value.G * 255)
									Template.ColorTextBox3.Text = math.floor(v.Value.B * 255)
								end
								if v:IsA("BoolValue") then
									Template.ButtonFrame.Visible = true
									if v.Value then
										Template.ButtonFrame.ImageLabel.Image = "rbxassetid://134134889667415"
									else
										Template.ButtonFrame.ImageLabel.Image = "rbxassetid://135028322450466"
									end
								end
								if v:IsA("StringValue") then
									Template.StringTextBox.Visible = true
									Template.StringTextBox.Text = v.Value
								end
							end
						end
						for _, v in pairs(folder:GetChildren()) do
							if v:IsA("Folder") then
								ProcessFolder(v, indentLevel + 1)
							end
						end
					end
					for _, v in pairs(TargetPlayer:GetChildren()) do
						if v:IsA("Folder") then
							ProcessFolder(v, 0)
						end
					end
				end
			end
		end,
	},

	{
		Name = "uxpviewhats",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				if HatsFrame.Visible then
					HatsFrame:TweenPosition(UDim2.fromScale(0.771, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					task.wait(1)
					HatsFrame.Visible = false
				else
					HatsFrame.Position = UDim2.fromScale(0.771, 1.5)
					HatsFrame.Visible = true
					HatsFrame.Nav.TextLabel.Text = TargetPlayer.Name.." Hats"
					HatsFrame:TweenPosition(UDim2.fromScale(0.771, 0.774), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					HatsFrame.NameValue.Value = TargetPlayer.Name
					for i,v in pairs(HatsFrame.ServerScrollingFrame:GetChildren()) do
						if v:IsA("UIGridLayout") then continue end
						v:Destroy()
					end
					for i,v in pairs(HatsFrame.ScrollingFrame:GetChildren()) do
						if v:IsA("UIGridLayout") then continue end
						v:Destroy()
					end
					local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
					for i,v in pairs(PanelSettings.HatList) do
						if TargetCharacter:FindFirstChild(i) then continue end

						local Template = HatsFrame.ServerScrollingFrame.UIGridLayout.Template:Clone()
						Template.Name = i
						Template.TextLabel.Text = v.HatName
						Template.Parent = HatsFrame.ServerScrollingFrame
					end
					if TargetCharacter then
						for i,v in pairs(TargetCharacter:GetChildren()) do
							if v:IsA("Accessory") and v.AccessoryType == Enum.AccessoryType.Hat then
								local Template = HatsFrame.ScrollingFrame.UIGridLayout.Template:Clone()
								Template.Name = v.Name
								Template.TextLabel.Text = v.Name
								Template.Parent = HatsFrame.ScrollingFrame
							end
						end
					end
				end
			end
		end,
	},
	
	{
		Name = "uxpviewtools",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				if ToolsFrame.Visible then
					ToolsFrame:TweenPosition(UDim2.fromScale(0.771, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					task.wait(1)
					ToolsFrame.Visible = false
				else
					ToolsFrame.Position = UDim2.fromScale(0.771, 1.5)
					ToolsFrame.Visible = true
					ToolsFrame.Nav.TextLabel.Text = TargetPlayer.Name.." Tools"
					ToolsFrame:TweenPosition(UDim2.fromScale(0.771, 0.774), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					ToolsFrame.NameValue.Value = TargetPlayer.Name
					for _, v in pairs(ToolsFrame.ServerScrollingFrame:GetChildren()) do
						if not v:IsA("UIGridLayout") then
							v:Destroy()
						end
					end
					for _, v in pairs(ToolsFrame.ScrollingFrame:GetChildren()) do
						if not v:IsA("UIGridLayout") then
							v:Destroy()
						end
					end
					local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
					for i, v in pairs(PanelSettings.ToolList) do
						if not TargetCharacter:FindFirstChild(i) then
							local Template = ToolsFrame.ServerScrollingFrame.UIGridLayout.Template:Clone()
							Template.Name = i
							Template.TextLabel.Text = v.ToolName
							Template.Parent = ToolsFrame.ServerScrollingFrame
						end
					end
					if TargetCharacter then
						for _, v in pairs(TargetPlayer.Backpack:GetChildren()) do
							if v:IsA("Tool") then
								local Template = ToolsFrame.ScrollingFrame.UIGridLayout.Template:Clone()
								Template.Name = v.Name
								Template.TextLabel.Text = v.Name
								Template.Parent = ToolsFrame.ScrollingFrame
							end
						end
						for _, v in pairs(TargetCharacter:GetChildren()) do
							if v:IsA("Tool") then
								local Template = ToolsFrame.ScrollingFrame.UIGridLayout.Template:Clone()
								Template.Name = v.Name
								Template.TextLabel.Text = v.Name
								Template.Parent = ToolsFrame.ScrollingFrame
							end
						end
					end
				end
			end
		end,
	},
	
	{
		Name = "uxpviewhatsdone",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				HatsFrame.Nav.TextLabel.Text = TargetPlayer.Name.." Hats"
				HatsFrame.NameValue.Value = TargetPlayer.Name
				for _, v in pairs(HatsFrame.ServerScrollingFrame:GetChildren()) do
					if not v:IsA("UIGridLayout") then
						v:Destroy()
					end
				end
				for _, v in pairs(HatsFrame.ScrollingFrame:GetChildren()) do
					if not v:IsA("UIGridLayout") then
						v:Destroy()
					end
				end
				local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
				for i, v in pairs(PanelSettings.HatList) do
					if not TargetCharacter:FindFirstChild(i) then
						local Template = HatsFrame.ServerScrollingFrame.UIGridLayout.Template:Clone()
						Template.Name = i
						Template.TextLabel.Text = v.HatName
						Template.Parent = HatsFrame.ServerScrollingFrame
					end
				end
				if TargetCharacter then
					for _, v in pairs(TargetCharacter:GetChildren()) do
						if v:IsA("Accessory") and v.AccessoryType == Enum.AccessoryType.Hat then
							local Template = HatsFrame.ScrollingFrame.UIGridLayout.Template:Clone()
							Template.Name = v.Name
							Template.TextLabel.Text = v.Name
							Template.Parent = HatsFrame.ScrollingFrame
						end
					end
				end
			end
		end,
	},

	{
		Name = "uxpviewtoolsdone",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				ToolsFrame.Nav.TextLabel.Text = TargetPlayer.Name.." Tools"
				ToolsFrame.NameValue.Value = TargetPlayer.Name
				for _, v in pairs(ToolsFrame.ServerScrollingFrame:GetChildren()) do
					if not v:IsA("UIGridLayout") then
						v:Destroy()
					end
				end
				for _, v in pairs(ToolsFrame.ScrollingFrame:GetChildren()) do
					if not v:IsA("UIGridLayout") then
						v:Destroy()
					end
				end
				local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
				for i, v in pairs(PanelSettings.ToolList) do
					if not TargetCharacter:FindFirstChild(i) and not TargetPlayer.Backpack:FindFirstChild(i) then
						local Template = ToolsFrame.ServerScrollingFrame.UIGridLayout.Template:Clone()
						Template.Name = i
						Template.TextLabel.Text = v.ToolName
						Template.Parent = ToolsFrame.ServerScrollingFrame
					end
				end
				if TargetCharacter then
					for _, v in pairs(TargetPlayer.Backpack:GetChildren()) do
						if v:IsA("Tool") then
							local Template = ToolsFrame.ScrollingFrame.UIGridLayout.Template:Clone()
							Template.Name = v.Name
							Template.TextLabel.Text = v.Name
							Template.Parent = ToolsFrame.ScrollingFrame
						end
					end
					for _, v in pairs(TargetCharacter:GetChildren()) do
						if v:IsA("Tool") then
							local Template = ToolsFrame.ScrollingFrame.UIGridLayout.Template:Clone()
							Template.Name = v.Name
							Template.TextLabel.Text = v.Name
							Template.Parent = ToolsFrame.ScrollingFrame
						end
					end
				end
			end
		end,
	},
	
	{
		Name = "uxpsearchinventorydone",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				local InventoryFrame = AdminPanelGui.InventroyFrame
				for _, v in pairs(InventoryFrame.ScrollingFrame:GetChildren()) do
					if not v:IsA("UIGridLayout") then
						v:Destroy()
					end
				end
				local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
				if TargetCharacter then
					for _, v in pairs(TargetCharacter:GetChildren()) do
						if v:IsA("Tool") then
							local Template = InventoryFrame.ScrollingFrame.UIGridLayout.Template:Clone()
							Template.Name = v.Name
							Template.TextLabel.Text = v.Name
							Template.Parent = InventoryFrame.ScrollingFrame
						end
					end
				end
				for _, v in pairs(TargetPlayer.Backpack:GetChildren()) do
					if v:IsA("Tool") then
						local Template = InventoryFrame.ScrollingFrame.UIGridLayout.Template:Clone()
						Template.Name = v.Name
						Template.TextLabel.Text = v.Name
						Template.Parent = InventoryFrame.ScrollingFrame
					end
				end
			end
		end,
	},

	{
		Name = "uxpsearchinventory",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local TargetPlayer = GetPlayer(LocalPlayer, value1)
			if TargetPlayer then
				local InventoryFrame = AdminPanelGui.InventroyFrame
				if InventoryFrame.Visible then
					InventoryFrame:TweenPosition(UDim2.fromScale(0.857, 1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					task.wait(1)
					InventoryFrame.Visible = false
				else
					InventoryFrame.Position = UDim2.fromScale(0.857, 1.5)
					InventoryFrame.Visible = true
					InventoryFrame.Nav.TextLabel.Text = TargetPlayer.Name.." Inventory"
					InventoryFrame:TweenPosition(UDim2.fromScale(0.857, 0.774), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1, true)
					InventoryFrame.NameValue.Value = TargetPlayer.Name
					for _, v in pairs(InventoryFrame.ScrollingFrame:GetChildren()) do
						if not v:IsA("UIGridLayout") then
							v:Destroy()
						end
					end
					local TargetCharacter = TargetPlayer.Character or TargetPlayer.CharacterAdded:Wait()
					if TargetCharacter then
						for _, v in pairs(TargetCharacter:GetChildren()) do
							if v:IsA("Tool") then
								local Template = InventoryFrame.ScrollingFrame.UIGridLayout.Template:Clone()
								Template.Name = v.Name
								Template.TextLabel.Text = v.Name
								Template.Parent = InventoryFrame.ScrollingFrame
							end
						end
					end
					for _, v in pairs(TargetPlayer.Backpack:GetChildren()) do
						if v:IsA("Tool") then
							local Template = InventoryFrame.ScrollingFrame.UIGridLayout.Template:Clone()
							Template.Name = v.Name
							Template.TextLabel.Text = v.Name
							Template.Parent = InventoryFrame.ScrollingFrame
						end
					end
				end
			end
		end,
	},
	
	{
		Name = "uxpfly",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local Players = game:GetService("Players")
			local RunService = game:GetService("RunService")
			local UserInputService = game:GetService("UserInputService")
			local LocalPlayer = Players.LocalPlayer
			local Camera = workspace.CurrentCamera

			local Character = LocalPlayer.Character
			if not Character then return end

			local Humanoid = Character:FindFirstChild("Humanoid")
			local Torso = Character:FindFirstChild("HumanoidRootPart")
			if not Humanoid or not Torso then return end

			local bPos = Torso:FindFirstChild("FLIGHT_POSITION")
			local bGyro = Torso:FindFirstChild("FLIGHT_GYRO")
			if bPos or bGyro then
				return
			end

			local flightPosition = Instance.new("BodyPosition")
			flightPosition.Name = "FLIGHT_POSITION"
			flightPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			flightPosition.Position = Torso.Position
			flightPosition.Parent = Torso

			local flightGyro = Instance.new("BodyGyro")
			flightGyro.Name = "FLIGHT_GYRO"
			flightGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
			flightGyro.CFrame = Torso.CFrame
			flightGyro.Parent = Torso

			local flying = true
			local curSpeed = 0
			local topSpeed = (value1 and tonumber(value1)) or 1
			local speedInc = 0.2

			local dir = {
				Forward = false,
				Backward = false,
				Left = false,
				Right = false,
				Up = false,
				Down = false
			}

			local function HandleInput(input, isGame, bool)
				if isGame then return end

				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.W then
						dir.Forward = bool
					elseif input.KeyCode == Enum.KeyCode.S then
						dir.Backward = bool
					elseif input.KeyCode == Enum.KeyCode.A then
						dir.Left = bool
					elseif input.KeyCode == Enum.KeyCode.D then
						dir.Right = bool
					elseif input.KeyCode == Enum.KeyCode.Space then
						dir.Up = bool
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Q then
						dir.Down = bool
					end
				end
			end

			local inputBeganConnection = UserInputService.InputBegan:Connect(function(input, isGame)
				HandleInput(input, isGame, true)
			end)

			local inputEndedConnection = UserInputService.InputEnded:Connect(function(input, isGame)
				HandleInput(input, isGame, false)
			end)

			Humanoid.PlatformStand = true
			Humanoid.WalkSpeed = 0
			Humanoid.AutoRotate = false
			Humanoid.JumpHeight = 0

			for _, track in pairs(Humanoid:GetPlayingAnimationTracks()) do
				track:Stop()
			end

			Torso.Anchored = true
			task.wait(0.2)
			Torso.Anchored = false
			Torso.Velocity = Vector3.new(0, 0, 0)
			Torso.RotVelocity = Vector3.new(0, 0, 0)

			local flightLoop
			flightLoop = RunService.RenderStepped:Connect(function()
				if not flying or not flightPosition or not flightPosition.Parent or not flightGyro or not flightGyro.Parent then

					flying = false

					if inputBeganConnection then inputBeganConnection:Disconnect() end
					if inputEndedConnection then inputEndedConnection:Disconnect() end
					if flightLoop then flightLoop:Disconnect() end

					if Humanoid and Humanoid.Parent then
						Humanoid.PlatformStand = false
						Humanoid.WalkSpeed = 16
						Humanoid.AutoRotate = true
						Humanoid.JumpHeight = 7.2
						Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
					end

					if flightPosition and flightPosition.Parent then
						flightPosition:Destroy()
					end
					if flightGyro and flightGyro.Parent then
						flightGyro:Destroy()
					end
					return
				end

				local new = flightGyro.CFrame - flightGyro.CFrame.Position + flightPosition.Position

				local NewPush = Vector3.new(0, 0, 0)
				local ForwardVector = Camera.CoordinateFrame:vectorToWorldSpace(Vector3.new(0, 0, -1))
				local SideVector = Camera.CoordinateFrame:vectorToWorldSpace(Vector3.new(-1, 0, 0))
				local UpVector = Vector3.new(0, 1, 0)

				local moveSpeed = topSpeed

				if dir.Forward then
					NewPush = NewPush + (ForwardVector * moveSpeed)
				end

				if dir.Backward then
					NewPush = NewPush - (ForwardVector * moveSpeed)
				end

				if dir.Left then
					NewPush = NewPush + (SideVector * moveSpeed)
				end

				if dir.Right then
					NewPush = NewPush - (SideVector * moveSpeed)
				end

				if dir.Up then
					NewPush = NewPush + (UpVector * moveSpeed)
				end

				if dir.Down then
					NewPush = NewPush - (UpVector * moveSpeed)
				end

				if NewPush.magnitude < 0.1 then
					new = flightGyro.CFrame - flightGyro.CFrame.Position + flightPosition.Position
				else
					new = new + NewPush
				end

				flightPosition.Position = new.Position

				flightGyro.CFrame = CFrame.new(Vector3.new(0, 0, 0), ForwardVector)
			end)
		end,
	},

	{
		Name = "uxpunfly",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local Players = game:GetService("Players")
			local LocalPlayer = Players.LocalPlayer

			local Character = LocalPlayer.Character
			if not Character then return end

			local Humanoid = Character:FindFirstChild("Humanoid")
			local Torso = Character:FindFirstChild("HumanoidRootPart")
			if not Humanoid or not Torso then return end

			local flightPosition = Torso:FindFirstChild("FLIGHT_POSITION")
			local flightGyro = Torso:FindFirstChild("FLIGHT_GYRO")

			if flightPosition then
				flightPosition:Destroy()
			end

			if flightGyro then
				flightGyro:Destroy()
			end

			Torso.Velocity = Vector3.new(0, 0, 0)
			Torso.RotVelocity = Vector3.new(0, 0, 0)

			if Humanoid and Humanoid.Parent then
				Humanoid.PlatformStand = false
				Humanoid.WalkSpeed = 16
				Humanoid.AutoRotate = true
				Humanoid.JumpHeight = 7.2
				Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end
		end,
	},
	
	{
		Name = "uxpnoclip",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local Players = game:GetService("Players")
			local RunService = game:GetService("RunService")
			local UserInputService = game:GetService("UserInputService")
			local LocalPlayer = Players.LocalPlayer
			local Camera = workspace.CurrentCamera

			local Character = LocalPlayer.Character
			if not Character then return end

			local Humanoid = Character:FindFirstChild("Humanoid")
			local Torso = Character:FindFirstChild("HumanoidRootPart")
			if not Humanoid or not Torso then return end

			local existingNoclip = Character:GetAttribute("NOCLIP_ACTIVE")
			if existingNoclip then
				return
			end

			local noclipSpeed = (value1 and tonumber(value1)) or 16

			Humanoid.PlatformStand = true

			local dir = {
				Forward = false,
				Backward = false,
				Left = false,
				Right = false,
				Up = false,
				Down = false
			}

			local function HandleInput(input, isGame, bool)
				if isGame then return end

				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.W then
						dir.Forward = bool
					elseif input.KeyCode == Enum.KeyCode.S then
						dir.Backward = bool
					elseif input.KeyCode == Enum.KeyCode.A then
						dir.Left = bool
					elseif input.KeyCode == Enum.KeyCode.D then
						dir.Right = bool
					elseif input.KeyCode == Enum.KeyCode.Space then
						dir.Up = bool
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.Q then
						dir.Down = bool
					end
				end
			end

			local inputBeganConnection = UserInputService.InputBegan:Connect(function(input, isGame)
				HandleInput(input, isGame, true)
			end)

			local inputEndedConnection = UserInputService.InputEnded:Connect(function(input, isGame)
				HandleInput(input, isGame, false)
			end)

			local noclipConnection = RunService.Heartbeat:Connect(function(Step)
				if not Character or not Humanoid or not Torso then
					return
				end

				Torso.Anchored = true
				Torso.Velocity = Vector3.new()

				local MoveAmount = Vector3.new()

				if dir.Forward then
					MoveAmount = MoveAmount + Vector3.new(0, 0, -1)
				end
				if dir.Backward then
					MoveAmount = MoveAmount + Vector3.new(0, 0, 1)
				end

				if dir.Left then
					MoveAmount = MoveAmount + Vector3.new(-1, 0, 0)
				end
				if dir.Right then
					MoveAmount = MoveAmount + Vector3.new(1, 0, 0)
				end

				if dir.Up then
					MoveAmount = MoveAmount + Vector3.new(0, 1, 0)
				end
				if dir.Down then
					MoveAmount = MoveAmount + Vector3.new(0, -1, 0)
				end

				if MoveAmount.Magnitude > 1 then
					MoveAmount = MoveAmount.Unit
				end
				MoveAmount = MoveAmount * Step * noclipSpeed

				if MoveAmount.Magnitude > 0 then
					Torso.CFrame = CFrame.new(Torso.Position, Torso.Position + Camera.CFrame.LookVector) * CFrame.new(MoveAmount)
				end
			end)

			local noclipData = {
				inputBegan = inputBeganConnection,
				inputEnded = inputEndedConnection,
				heartbeat = noclipConnection
			}

			Character:SetAttribute("NOCLIP_ACTIVE", true)
			noclipConnections[LocalPlayer.Name] = noclipData
		end,
	},

	{
		Name = "uxpunnoclip",
		Code = function(rtype, value1, value2, value3, value4, value5, value6)
			local Players = game:GetService("Players")
			local LocalPlayer = Players.LocalPlayer

			local Character = LocalPlayer.Character
			if not Character then return end

			local Humanoid = Character:FindFirstChild("Humanoid")
			local Torso = Character:FindFirstChild("HumanoidRootPart")
			if not Humanoid or not Torso then return end

			local isNoclipping = Character:GetAttribute("NOCLIP_ACTIVE")
			if not isNoclipping then
				return
			end

			local noclipData = noclipConnections[LocalPlayer.Name]
			if noclipData then
				if noclipData.inputBegan then noclipData.inputBegan:Disconnect() end
				if noclipData.inputEnded then noclipData.inputEnded:Disconnect() end
				if noclipData.heartbeat then noclipData.heartbeat:Disconnect() end

				noclipConnections[LocalPlayer.Name] = nil
			end
			
			Character:SetAttribute("NOCLIP_ACTIVE", nil)

			Humanoid.PlatformStand = false
			Humanoid.WalkSpeed = 16
			Humanoid.AutoRotate = true
			Humanoid.JumpHeight = 7.2

			Torso.Anchored = false

			Torso.Velocity = Vector3.new(0, 0, 0)
			Torso.RotVelocity = Vector3.new(0, 0, 0)

			Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end,
	},
	
}

return LocalEventModule
