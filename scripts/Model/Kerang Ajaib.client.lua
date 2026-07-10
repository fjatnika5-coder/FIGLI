local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for RemoteEvents
local openConchGUI = ReplicatedStorage:WaitForChild("OpenConchGUI")
local askConchEvent = ReplicatedStorage:WaitForChild("AskConchEvent")
local sendNotification = ReplicatedStorage:WaitForChild("SendNotification")

local currentConchShell = nil

-- Buat GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ConchGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Frame utama
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 250)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

-- UICorner untuk frame
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = mainFrame

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 0, 50)
title.Position = UDim2.new(0, 20, 0, 15)
title.BackgroundTransparency = 1
title.Text = "🐚 Magic Conch Shell"
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- Cost label
local costLabel = Instance.new("TextLabel")
costLabel.Name = "CostLabel"
costLabel.Size = UDim2.new(1, -40, 0, 20)
costLabel.Position = UDim2.new(0, 20, 0, 50)
costLabel.BackgroundTransparency = 1
costLabel.Text = "Biaya: 1000 Cash"
costLabel.Font = Enum.Font.Gotham
costLabel.TextSize = 14
costLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
costLabel.TextXAlignment = Enum.TextXAlignment.Left
costLabel.Parent = mainFrame

-- WM
local watermarkLabel = Instance.new("TextLabel")
watermarkLabel.Name = "WatermarkLabel"
watermarkLabel.Size = UDim2.new(1, -40, 0, 2)
watermarkLabel.Position = UDim2.new(0, 340, 0, 10)
watermarkLabel.BackgroundTransparency = 1
watermarkLabel.Text = "By Centrlz"
watermarkLabel.Font = Enum.Font.Sarpanch
watermarkLabel.TextSize = 14
watermarkLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
watermarkLabel.Parent = mainFrame

-- Question TextBox
local questionBox = Instance.new("TextBox")
questionBox.Name = "QuestionBox"
questionBox.Size = UDim2.new(1, -40, 0, 80)
questionBox.Position = UDim2.new(0, 20, 0, 85)
questionBox.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
questionBox.BorderSizePixel = 0
questionBox.Text = ""
questionBox.PlaceholderText = "Ketik pertanyaanmu disini..."
questionBox.Font = Enum.Font.Gotham
questionBox.TextSize = 16
questionBox.TextColor3 = Color3.fromRGB(255, 255, 255)
questionBox.TextXAlignment = Enum.TextXAlignment.Left
questionBox.TextYAlignment = Enum.TextYAlignment.Top
questionBox.ClearTextOnFocus = false
questionBox.MultiLine = true
questionBox.TextWrapped = true
questionBox.Parent = mainFrame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 8)
boxCorner.Parent = questionBox

local boxPadding = Instance.new("UIPadding")
boxPadding.PaddingTop = UDim.new(0, 8)
boxPadding.PaddingBottom = UDim.new(0, 8)
boxPadding.PaddingLeft = UDim.new(0, 12)
boxPadding.PaddingRight = UDim.new(0, 12)
boxPadding.Parent = questionBox

-- Ask Button
local askButton = Instance.new("TextButton")
askButton.Name = "AskButton"
askButton.Size = UDim2.new(0, 160, 0, 40)
askButton.Position = UDim2.new(0, 20, 1, -55)
askButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
askButton.BorderSizePixel = 0
askButton.Text = "TANYA"
askButton.Font = Enum.Font.GothamBold
askButton.TextSize = 18
askButton.TextColor3 = Color3.fromRGB(255, 255, 255)
askButton.Parent = mainFrame

local askCorner = Instance.new("UICorner")
askCorner.CornerRadius = UDim.new(0, 8)
askCorner.Parent = askButton

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 160, 0, 40)
closeButton.Position = UDim2.new(1, -180, 1, -55)
closeButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
closeButton.BorderSizePixel = 0
closeButton.Text = "TUTUP"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Notification Frame
local notifFrame = Instance.new("Frame")
notifFrame.Name = "NotificationFrame"
notifFrame.Size = UDim2.new(0, 350, 0, 80)
notifFrame.Position = UDim2.new(0.5, -175, 0, -100)
notifFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false
notifFrame.Parent = screenGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 10)
notifCorner.Parent = notifFrame

local notifText = Instance.new("TextLabel")
notifText.Name = "NotifText"
notifText.Size = UDim2.new(1, -30, 1, -20)
notifText.Position = UDim2.new(0, 15, 0, 10)
notifText.BackgroundTransparency = 1
notifText.Text = ""
notifText.Font = Enum.Font.Gotham
notifText.TextSize = 16
notifText.TextColor3 = Color3.fromRGB(255, 255, 255)
notifText.TextWrapped = true
notifText.TextXAlignment = Enum.TextXAlignment.Center
notifText.TextYAlignment = Enum.TextYAlignment.Center
notifText.Parent = notifFrame

-- Fungsi untuk show notification
local function showNotification(message)
	notifText.Text = message
	notifFrame.Visible = true
	notifFrame:TweenPosition(UDim2.new(0.5, -175, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.5, true)

	wait(3)

	notifFrame:TweenPosition(UDim2.new(0.5, -175, 0, -100), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.5, true)
	wait(0.5)
	notifFrame.Visible = false
end

-- Event handlers
openConchGUI.OnClientEvent:Connect(function(conchShell)
	currentConchShell = conchShell
	questionBox.Text = ""
	mainFrame.Visible = true
end)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	questionBox.Text = ""
end)

sendNotification.OnClientEvent:Connect(function(message)
	showNotification(message)
end)

askButton.MouseButton1Click:Connect(function()
	local question = questionBox.Text
	if question ~= "" and currentConchShell then
		askConchEvent:FireServer(currentConchShell, question)
		mainFrame.Visible = false
	else
		showNotification("Ketik pertanyaan terlebih dahulu!")
	end
end)