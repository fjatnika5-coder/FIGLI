--!strict
--[[
  TipJar GUI Client - Final (Auto Refresh + Loading)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
local RequestDonation: RemoteEvent? = nil
local GetGamePasses: RemoteEvent? = nil
local OpenDonate: RemoteEvent? = nil

local Events = ReplicatedStorage:WaitForChild("EventsACMS")
local OpenTipJarEvent = Events:WaitForChild("OpenTipJar")
local BackToACMEvent = Events:WaitForChild("BackToACM")

if remotesFolder then
	RequestDonation = remotesFolder:FindFirstChild("RequestDonation") :: RemoteEvent
	GetGamePasses = remotesFolder:FindFirstChild("GetGamePasses") :: RemoteEvent
	OpenDonate = remotesFolder:FindFirstChild("OpenDonate") :: RemoteEvent
end

local currentTargetPlayer: Player? = nil

----------------------------------------------------------------
-- Dynamic Scale
----------------------------------------------------------------
local IS_MOBILE = UserInputService.TouchEnabled

local function getCamera(): Camera?
	return Workspace.CurrentCamera
end

local function getDynamicScale(): number
	if not IS_MOBILE then return 1.0 end
	local cam = getCamera()
	local viewportY = cam and cam.ViewportSize.Y or 900
	local MOBILE_REDUCTION = 0.75
	local base: number
	if viewportY > 1800 then base = 0.75 * MOBILE_REDUCTION
	elseif viewportY > 1200 then base = 0.80 * MOBILE_REDUCTION
	elseif viewportY > 900 then base = 0.85 * MOBILE_REDUCTION
	else base = 0.90 * MOBILE_REDUCTION end
	local cam2 = getCamera()
	local shortestSide = math.min(cam2 and cam2.ViewportSize.X or 1280, viewportY)
	return shortestSide > 700 and base * 1.20 or base * 1.12
end

local BASE_SCALE = getDynamicScale()

----------------------------------------------------------------
-- Colors
----------------------------------------------------------------
local COLOR_BG = Color3.fromRGB(15, 15, 15)
local COLOR_BG_SECONDARY = Color3.fromRGB(25, 25, 25)
local COLOR_STROKE = Color3.fromRGB(255, 255, 255)
local COLOR_TEXT = Color3.fromRGB(230, 230, 230)
local COLOR_TEXT_DIM = Color3.fromRGB(180, 180, 180)

local STROKE_THICKNESS = 1.3
local STROKE_TRANSPARENCY = 0.6

local TWEEN_INFO_SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

----------------------------------------------------------------
-- Sound
----------------------------------------------------------------
local function playClickSound()
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.3
		sound.Parent = SoundService
		sound:Play()
		task.delay(1, function() sound:Destroy() end)
	end)
end

----------------------------------------------------------------
-- UI Helper
----------------------------------------------------------------
local function addWhiteStroke(parent: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_STROKE
	stroke.Thickness = STROKE_THICKNESS * BASE_SCALE
	stroke.Transparency = STROKE_TRANSPARENCY
	stroke.Parent = parent
	return stroke
end

----------------------------------------------------------------
-- CREATE TIPJAR GUI
----------------------------------------------------------------
local function CreateTipJarGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TipJarGui_ACM"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 95
	screenGui.Parent = playerGui

	local bgDimmer = Instance.new("Frame")
	bgDimmer.Name = "BG_Dimmer"
	bgDimmer.Size = UDim2.fromScale(1, 1)
	bgDimmer.BackgroundColor3 = Color3.new(0, 0, 0)
	bgDimmer.BackgroundTransparency = 1
	bgDimmer.BorderSizePixel = 0
	bgDimmer.ZIndex = 5
	bgDimmer.Visible = false
	bgDimmer.Parent = screenGui

	local mainPanel = Instance.new("Frame")
	mainPanel.Name = "MainPanel"
	mainPanel.Size = UDim2.new(0, 480 * BASE_SCALE, 0, 180 * BASE_SCALE)
	mainPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	mainPanel.BackgroundColor3 = COLOR_BG
	mainPanel.BackgroundTransparency = 0.15
	mainPanel.BorderSizePixel = 0
	mainPanel.Visible = false
	mainPanel.ZIndex = 10
	mainPanel.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12 * BASE_SCALE)
	mainCorner.Parent = mainPanel

	addWhiteStroke(mainPanel)

	-- Header
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(0, 100 * BASE_SCALE, 0, 24 * BASE_SCALE)
	headerLabel.Position = UDim2.new(0, 12 * BASE_SCALE, 0, 6 * BASE_SCALE)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = utf8.char(0xE002) .. " Gift Donation"
	headerLabel.TextColor3 = COLOR_TEXT
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 13 * BASE_SCALE
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.ZIndex = 11
	headerLabel.Parent = mainPanel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28 * BASE_SCALE, 0, 28 * BASE_SCALE)
	closeBtn.Position = UDim2.new(1, -34 * BASE_SCALE, 0, 6 * BASE_SCALE)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text = "×"
	closeBtn.TextColor3 = COLOR_TEXT_DIM
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 22 * BASE_SCALE
	closeBtn.ZIndex = 11
	closeBtn.Parent = mainPanel

	-- Left Section
	local leftSection = Instance.new("Frame")
	leftSection.Name = "LeftSection"
	leftSection.Size = UDim2.new(0, 90 * BASE_SCALE, 0, 120 * BASE_SCALE)
	leftSection.Position = UDim2.new(0, 12 * BASE_SCALE, 0, 32 * BASE_SCALE)
	leftSection.BackgroundTransparency = 1
	leftSection.ZIndex = 10
	leftSection.Parent = mainPanel

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "AvatarHeadshot"
	avatarImage.Size = UDim2.new(0, 70 * BASE_SCALE, 0, 70 * BASE_SCALE)
	avatarImage.Position = UDim2.new(0.5, 0, 0, 0)
	avatarImage.AnchorPoint = Vector2.new(0.5, 0)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Image = ""
	avatarImage.ZIndex = 11
	avatarImage.Parent = leftSection

	local avCorner = Instance.new("UICorner")
	avCorner.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
	avCorner.Parent = avatarImage

	local displayName = Instance.new("TextLabel")
	displayName.Name = "DisplayName"
	displayName.Size = UDim2.new(1, 0, 0, 18 * BASE_SCALE)
	displayName.Position = UDim2.new(0, 0, 0, 74 * BASE_SCALE)
	displayName.BackgroundTransparency = 1
	displayName.Text = "Player"
	displayName.TextColor3 = COLOR_TEXT
	displayName.Font = Enum.Font.GothamBold
	displayName.TextSize = 13 * BASE_SCALE
	displayName.TextXAlignment = Enum.TextXAlignment.Center
	displayName.TextTruncate = Enum.TextTruncate.AtEnd
	displayName.ZIndex = 12
	displayName.Parent = leftSection

	local username = Instance.new("TextLabel")
	username.Name = "Username"
	username.Size = UDim2.new(1, 0, 0, 14 * BASE_SCALE)
	username.Position = UDim2.new(0, 0, 0, 92 * BASE_SCALE)
	username.BackgroundTransparency = 1
	username.Text = "@username"
	username.TextColor3 = COLOR_TEXT_DIM
	username.Font = Enum.Font.Gotham
	username.TextSize = 10 * BASE_SCALE
	username.TextXAlignment = Enum.TextXAlignment.Center
	username.ZIndex = 12
	username.Parent = leftSection

	-- Right Section
	local rightSection = Instance.new("Frame")
	rightSection.Name = "RightSection"
	rightSection.Size = UDim2.new(0, 355 * BASE_SCALE, 0, 130 * BASE_SCALE)
	rightSection.Position = UDim2.new(0, 110 * BASE_SCALE, 0, 32 * BASE_SCALE)
	rightSection.BackgroundTransparency = 1
	rightSection.ZIndex = 10
	rightSection.Parent = mainPanel

	-- -------------------------------------------------------------
	-- [BARU] LOADING TEXT LABEL
	-- -------------------------------------------------------------
	local loadingLabel = Instance.new("TextLabel")
	loadingLabel.Name = "LoadingLabel"
	loadingLabel.Size = UDim2.new(1, 0, 0, 40 * BASE_SCALE)
	loadingLabel.Position = UDim2.new(0, 0, 0, 10 * BASE_SCALE) -- Center di area tombol
	loadingLabel.BackgroundTransparency = 1
	loadingLabel.Text = "Loading..."
	loadingLabel.TextColor3 = COLOR_TEXT_DIM
	loadingLabel.Font = Enum.Font.Gotham
	loadingLabel.TextSize = 14 * BASE_SCALE
	loadingLabel.TextTransparency = 0.4
	loadingLabel.Visible = false
	loadingLabel.ZIndex = 15
	loadingLabel.Parent = rightSection

	-- Animasi kedip Loading (stop saat label di-destroy, tween dibuat sekali)
	task.spawn(function()
		local tweenIn = TweenService:Create(loadingLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0.2})
		local tweenOut = TweenService:Create(loadingLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0.8})
		while loadingLabel.Parent do
			if loadingLabel.Visible then
				tweenIn:Play()
				task.wait(0.8)
				tweenOut:Play()
				task.wait(0.8)
			else
				task.wait(0.5)
			end
		end
	end)

	local buttonsScroll = Instance.new("ScrollingFrame")
	buttonsScroll.Name = "ButtonsScroll"
	buttonsScroll.Size = UDim2.new(1, 0, 0, 62 * BASE_SCALE)
	buttonsScroll.Position = UDim2.new(0, 0, 0, 0)
	buttonsScroll.BackgroundTransparency = 1
	buttonsScroll.ScrollBarThickness = 4 * BASE_SCALE
	buttonsScroll.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
	buttonsScroll.ScrollBarImageTransparency = 0.3
	buttonsScroll.VerticalScrollBarInset = Enum.ScrollBarInset.None
	buttonsScroll.HorizontalScrollBarInset = Enum.ScrollBarInset.Always
	buttonsScroll.ScrollingDirection = Enum.ScrollingDirection.X
	buttonsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	buttonsScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	buttonsScroll.ElasticBehavior = Enum.ElasticBehavior.Always
	buttonsScroll.ZIndex = 11
	buttonsScroll.Parent = rightSection

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	btnLayout.Padding = UDim.new(0, 10 * BASE_SCALE)
	btnLayout.Parent = buttonsScroll

	local btnPadding = Instance.new("UIPadding")
	btnPadding.PaddingLeft = UDim.new(0, 4 * BASE_SCALE)
	btnPadding.PaddingTop = UDim.new(0, 2 * BASE_SCALE)
	btnPadding.PaddingBottom = UDim.new(0, 2 * BASE_SCALE)
	btnPadding.Parent = buttonsScroll

	-- Stats Section
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsFrame"
	statsFrame.Size = UDim2.new(1, -8 * BASE_SCALE, 0, 50 * BASE_SCALE)
	statsFrame.Position = UDim2.new(0, 4 * BASE_SCALE, 0, 72 * BASE_SCALE)
	statsFrame.BackgroundTransparency = 1
	statsFrame.ZIndex = 10
	statsFrame.Parent = rightSection

	local statsLayout = Instance.new("UIListLayout")
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statsLayout.Padding = UDim.new(0, 10 * BASE_SCALE)
	statsLayout.Parent = statsFrame

	-- Donated Box
	local donatedBox = Instance.new("Frame")
	donatedBox.Name = "DonatedBox"
	donatedBox.Size = UDim2.new(0.5, -8 * BASE_SCALE, 0, 42 * BASE_SCALE)
	donatedBox.BackgroundColor3 = COLOR_BG_SECONDARY
	donatedBox.ZIndex = 11
	donatedBox.Parent = statsFrame
	local donatedCorner = Instance.new("UICorner")
	donatedCorner.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
	donatedCorner.Parent = donatedBox
	addWhiteStroke(donatedBox)
	local donatedLabel = Instance.new("TextLabel")
	donatedLabel.Size = UDim2.new(1, 0, 0, 14 * BASE_SCALE)
	donatedLabel.Position = UDim2.new(0, 0, 0, 6 * BASE_SCALE)
	donatedLabel.BackgroundTransparency = 1
	donatedLabel.Text = "DONATED"
	donatedLabel.TextColor3 = COLOR_TEXT_DIM
	donatedLabel.Font = Enum.Font.GothamBold
	donatedLabel.TextSize = 9 * BASE_SCALE
	donatedLabel.ZIndex = 12
	donatedLabel.Parent = donatedBox
	local donatedValue = Instance.new("TextLabel")
	donatedValue.Name = "DonatedValue"
	donatedValue.Size = UDim2.new(1, 0, 0, 18 * BASE_SCALE)
	donatedValue.Position = UDim2.new(0, 0, 0, 20 * BASE_SCALE)
	donatedValue.BackgroundTransparency = 1
	donatedValue.Text = utf8.char(0xE002) .. " 0"
	donatedValue.TextColor3 = Color3.fromRGB(99, 102, 241)
	donatedValue.Font = Enum.Font.GothamBold
	donatedValue.TextSize = 14 * BASE_SCALE
	donatedValue.ZIndex = 12
	donatedValue.Parent = donatedBox

	-- Raised Box
	local raisedBox = Instance.new("Frame")
	raisedBox.Name = "RaisedBox"
	raisedBox.Size = UDim2.new(0.5, -8 * BASE_SCALE, 0, 42 * BASE_SCALE)
	raisedBox.BackgroundColor3 = COLOR_BG_SECONDARY
	raisedBox.ZIndex = 11
	raisedBox.Parent = statsFrame
	local raisedCorner = Instance.new("UICorner")
	raisedCorner.CornerRadius = UDim.new(0, 8 * BASE_SCALE)
	raisedCorner.Parent = raisedBox
	addWhiteStroke(raisedBox)
	local raisedLabel = Instance.new("TextLabel")
	raisedLabel.Size = UDim2.new(1, 0, 0, 14 * BASE_SCALE)
	raisedLabel.Position = UDim2.new(0, 0, 0, 6 * BASE_SCALE)
	raisedLabel.BackgroundTransparency = 1
	raisedLabel.Text = "RAISED"
	raisedLabel.TextColor3 = COLOR_TEXT_DIM
	raisedLabel.Font = Enum.Font.GothamBold
	raisedLabel.TextSize = 9 * BASE_SCALE
	raisedLabel.ZIndex = 12
	raisedLabel.Parent = raisedBox
	local raisedValue = Instance.new("TextLabel")
	raisedValue.Name = "RaisedValue"
	raisedValue.Size = UDim2.new(1, 0, 0, 18 * BASE_SCALE)
	raisedValue.Position = UDim2.new(0, 0, 0, 20 * BASE_SCALE)
	raisedValue.BackgroundTransparency = 1
	raisedValue.Text = utf8.char(0xE002) .. " 0"
	raisedValue.TextColor3 = Color3.fromRGB(80, 255, 80)
	raisedValue.Font = Enum.Font.GothamBold
	raisedValue.TextSize = 14 * BASE_SCALE
	raisedValue.ZIndex = 12
	raisedValue.Parent = raisedBox

	----------------------------------------------------------------
	-- Buttons
	----------------------------------------------------------------
	local function CreateDonateButton(price: number, gamepassId: number, layoutOrder: number, isOwned: boolean)
		local btn = Instance.new("TextButton")
		btn.Name = "Donate_" .. price
		btn.Size = UDim2.new(0, 62 * BASE_SCALE, 0, 48 * BASE_SCALE)
		btn.BackgroundColor3 = isOwned and Color3.fromRGB(40, 40, 40) or COLOR_BG_SECONDARY
		btn.Text = ""
		btn.AutoButtonColor = not isOwned 
		btn.LayoutOrder = layoutOrder
		btn.ZIndex = 12
		btn.Parent = buttonsScroll

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 10 * BASE_SCALE)
		btnCorner.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = isOwned and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(255, 255, 255)
		btnStroke.Thickness = 1.3 * BASE_SCALE
		btnStroke.Transparency = isOwned and 0.8 or 0.6
		btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		btnStroke.Parent = btn

		local priceLabel = Instance.new("TextLabel")
		priceLabel.Size = UDim2.new(1, 0, 1, 0)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Text = isOwned and "OWNED" or utf8.char(0xE002) .. tostring(price)
		priceLabel.TextColor3 = isOwned and COLOR_TEXT_DIM or COLOR_TEXT
		priceLabel.Font = Enum.Font.GothamBold
		priceLabel.TextSize = (isOwned and 10 or 16) * BASE_SCALE
		priceLabel.ZIndex = 13
		priceLabel.Parent = btn

		if not isOwned then
			local scale = Instance.new("UIScale")
			scale.Scale = 1
			scale.Parent = btn

			btn.MouseEnter:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.1), {Scale = 1.05}):Play()
				TweenService:Create(btnStroke, TweenInfo.new(0.1), {Transparency = 0.2}):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.1), {Scale = 1}):Play()
				TweenService:Create(btnStroke, TweenInfo.new(0.1), {Transparency = STROKE_TRANSPARENCY}):Play()
			end)
			btn.MouseButton1Click:Connect(function()
				playClickSound()
				if not RequestDonation or not currentTargetPlayer then return end
				RequestDonation:FireServer(currentTargetPlayer.UserId, gamepassId)
			end)
		else
			btn.Active = false
		end

		return btn
	end

	----------------------------------------------------------------
	-- Animation
	----------------------------------------------------------------
	local function OpenGUI()
		mainPanel.Visible = true
		mainPanel.Position = UDim2.new(0.5, 0, 0.5, 50 * BASE_SCALE)
		mainPanel.BackgroundTransparency = 1
		bgDimmer.Visible = true
		bgDimmer.BackgroundTransparency = 1

		TweenService:Create(mainPanel, TWEEN_INFO_SLIDE, {
			Position = UDim2.new(0.5, 0, 0.5, 0),
			BackgroundTransparency = 0.15
		}):Play()

		TweenService:Create(bgDimmer, TweenInfo.new(0.3), {
			BackgroundTransparency = 0.7
		}):Play()

		playClickSound()
	end

	local function CloseGUI()
		playClickSound()
		local tweenPanel = TweenService:Create(mainPanel, TWEEN_INFO_FADE, {
			Position = UDim2.new(0.5, 0, 0.5, 50 * BASE_SCALE),
			BackgroundTransparency = 1
		})
		tweenPanel:Play()

		local tweenDimmer = TweenService:Create(bgDimmer, TweenInfo.new(0.3), {
			BackgroundTransparency = 1
		})
		tweenDimmer:Play()

		tweenPanel.Completed:Connect(function()
			mainPanel.Visible = false
			bgDimmer.Visible = false
		end)
	end

	closeBtn.MouseButton1Click:Connect(function()
		CloseGUI()
		if currentTargetPlayer then
			BackToACMEvent:Fire(currentTargetPlayer)
		end
	end)

	----------------------------------------------------------------
	-- Public API
	----------------------------------------------------------------
	local API = {}

	function API:Open()
		OpenGUI()
	end

	function API:Close()
		CloseGUI()
	end

	function API:ShowLoading()
		loadingLabel.Visible = true
		buttonsScroll.Visible = false
	end

	function API:HideLoading()
		loadingLabel.Visible = false
		buttonsScroll.Visible = true
	end

	function API:SetProfile(targetPlayer: Player)
		currentTargetPlayer = targetPlayer
		displayName.Text = targetPlayer.DisplayName
		username.Text = "@" .. targetPlayer.Name
		avatarImage.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(targetPlayer.UserId)

		local raised = targetPlayer:FindFirstChild("Raised")
		local donated = targetPlayer:FindFirstChild("Donated")

		if raised and raised:IsA("NumberValue") then
			raisedValue.Text = utf8.char(0xE002) .. " " .. tostring(raised.Value)
		else
			raisedValue.Text = utf8.char(0xE002) .. " 0"
		end

		if donated and donated:IsA("NumberValue") then
			donatedValue.Text = utf8.char(0xE002) .. " " .. tostring(donated.Value)
		else
			donatedValue.Text = utf8.char(0xE002) .. " 0"
		end
	end

	function API:ClearButtons()
		for _, child in ipairs(buttonsScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

	function API:AddDonateOption(price: number, gamepassId: number, layoutOrder: number, isOwned: boolean)
		CreateDonateButton(price, gamepassId, layoutOrder, isOwned)
	end

	function API:Refresh()
		if currentTargetPlayer then
			self:ClearButtons()
			self:ShowLoading()
			if GetGamePasses then
				GetGamePasses:FireServer(currentTargetPlayer)
			end
		end
	end

	function API:GetMainFrame()
		return mainPanel
	end

	return API
end

----------------------------------------------------------------
-- Initialize
----------------------------------------------------------------
local TipJar = CreateTipJarGUI()

----------------------------------------------------------------
-- Connect to Remotes
----------------------------------------------------------------
if OpenDonate then
	OpenDonate.OnClientEvent:Connect(function(targetPlayer: Player)
		if not TipJar then return end
		if not targetPlayer or not targetPlayer:IsA("Player") then return end

		TipJar:SetProfile(targetPlayer)
		TipJar:ClearButtons()
		TipJar:ShowLoading() -- Tampilkan Loading sebelum data masuk
		TipJar:Open()

		if GetGamePasses then
			GetGamePasses:FireServer(targetPlayer)
		end
	end)
end

if GetGamePasses then
	GetGamePasses.OnClientEvent:Connect(function(targetPlayer: Player, gamePasses)
		if not TipJar then return end
		if not targetPlayer or typeof(gamePasses) ~= "table" then return end

		TipJar:ClearButtons()
		TipJar:SetProfile(targetPlayer)

		local processedPasses = {}

		for _, gp in ipairs(gamePasses) do
			if gp.id then
				local realPrice = 0
				local isOwned = false
				local success, info = pcall(function()
					return MarketplaceService:GetProductInfo(gp.id, Enum.InfoType.GamePass)
				end)
				if success and info then
					realPrice = info.PriceInRobux or 0
				end

				local ownSuccess, alreadyOwned = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.id)
				end)
				if ownSuccess then
					isOwned = alreadyOwned
				end

				table.insert(processedPasses, {
					id = gp.id,
					price = realPrice,
					owned = isOwned
				})
			end
		end

		table.sort(processedPasses, function(a, b)
			return a.price < b.price
		end)

		-- Sembunyikan Loading setelah data siap
		TipJar:HideLoading()

		for i, gp in ipairs(processedPasses) do
			TipJar:AddDonateOption(gp.price, gp.id, i, gp.owned)
		end
	end)
end

if OpenTipJarEvent then
	OpenTipJarEvent.Event:Connect(function(targetPlayer)
		if not TipJar then return end
		if not targetPlayer or not targetPlayer:IsA("Player") then return end

		TipJar:SetProfile(targetPlayer)
		TipJar:ClearButtons()
		TipJar:ShowLoading() -- Tampilkan Loading
		TipJar:Open()

		if GetGamePasses then
			GetGamePasses:FireServer(targetPlayer)
		end
	end)
end

----------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, purchasedPassId, purchaseSuccess)
	if purchaseSuccess then
		task.wait(1)
		if TipJar and TipJar:GetMainFrame().Visible then
			TipJar:Refresh()
		end
	end
end)

return TipJar