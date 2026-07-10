-- ✅ LUCK BOOST SHOP CLIENT (NO TOPBAR ICON!)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for remotes
local GetShopInfo = ReplicatedStorage:WaitForChild("GetLuckBoostShopInfo")
local PurchaseBoost = ReplicatedStorage:WaitForChild("PurchaseLuckBoost")
local ShowNotification = ReplicatedStorage:WaitForChild("ShowLuckNotification")

-- ============================================
-- DETECT MOBILE
-- ============================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

print(string.format("📱 Platform: %s", isMobile and "MOBILE" or "PC"))

-- ============================================
-- GET UI
-- ============================================

local gui = playerGui:WaitForChild("LuckBoostShopGui")
local mainFrame = gui:WaitForChild("MainFrame")
local header = mainFrame:WaitForChild("Header")
local content = mainFrame:WaitForChild("Content")

-- Get all elements
local closeBtn = header:WaitForChild("CloseButton")
local title = header:WaitForChild("Title")

local moneyCard = content:WaitForChild("MoneyCard")
local moneyLabel = moneyCard:WaitForChild("MoneyLabel")
local moneyValue = moneyCard:WaitForChild("MoneyValue")

local statusCard = content:WaitForChild("StatusCard")
local statusTitle = statusCard:WaitForChild("StatusTitle")
local luckLabel = statusCard:WaitForChild("LuckLabel")
local timeLabel = statusCard:WaitForChild("TimeLabel")

local multSection = content:WaitForChild("MultiplierSection")
local multLabel = multSection:WaitForChild("MultLabel")
local multSliderBg = multSection:WaitForChild("MultSlider")
local multSliderBtn = multSliderBg:WaitForChild("MultButton")

local durSection = content:WaitForChild("DurationSection")
local durLabel = durSection:WaitForChild("DurLabel")
local durSliderBg = durSection:WaitForChild("DurSlider")
local durSliderBtn = durSliderBg:WaitForChild("DurButton")

local priceCard = content:WaitForChild("PriceCard")
local priceLabel = priceCard:WaitForChild("PriceLabel")
local buyButton = content:WaitForChild("BuyButton")

-- ============================================
-- ADJUST UI FOR MOBILE
-- ============================================

if isMobile then
	print("🔧 Adjusting UI for Mobile...")

	mainFrame.Size = UDim2.fromOffset(280, 250)
	mainFrame:FindFirstChild("MainCorner").CornerRadius = UDim.new(0, 8)

	header.Size = UDim2.new(1, 0, 0, 30)
	header:FindFirstChild("HeaderCorner").CornerRadius = UDim.new(0, 8)

	title.Position = UDim2.new(0, 8, 0, 0)
	title.Text = "🍀 Luck Boost"
	title.TextSize = 11

	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(1, -26, 0.5, -11)
	closeBtn.TextSize = 11

	content.Size = UDim2.new(1, -16, 1, -38)
	content.Position = UDim2.new(0, 8, 0, 34)
	content:FindFirstChild("ContentLayout").Padding = UDim.new(0, 5)

	moneyCard.Size = UDim2.new(1, 0, 0, 32)
	moneyCard:FindFirstChild("MoneyCorner").CornerRadius = UDim.new(0, 6)

	moneyLabel.Size = UDim2.new(1, -12, 0, 10)
	moneyLabel.Position = UDim2.new(0, 6, 0, 3)
	moneyLabel.Text = "💰 Uang"
	moneyLabel.TextSize = 7

	moneyValue.Size = UDim2.new(1, -12, 0, 16)
	moneyValue.Position = UDim2.new(0, 6, 0, 13)
	moneyValue.TextSize = 10

	statusCard.Size = UDim2.new(1, 0, 0, 52)
	statusCard:FindFirstChild("StatusCorner").CornerRadius = UDim.new(0, 6)

	statusTitle.Size = UDim2.new(1, -12, 0, 10)
	statusTitle.Position = UDim2.new(0, 6, 0, 4)
	statusTitle.TextSize = 8

	luckLabel.Size = UDim2.new(1, -12, 0, 16)
	luckLabel.Position = UDim2.new(0, 6, 0, 16)
	luckLabel.Text = "x1"
	luckLabel.TextSize = 12

	timeLabel.Size = UDim2.new(1, -12, 0, 14)
	timeLabel.Position = UDim2.new(0, 6, 0, 34)
	timeLabel.Text = "Tidak aktif"
	timeLabel.TextSize = 9

	multSection.Size = UDim2.new(1, 0, 0, 38)

	multLabel.Size = UDim2.new(1, 0, 0, 12)
	multLabel.TextSize = 8

	multSliderBg.Size = UDim2.new(1, 0, 0, 22)
	multSliderBg.Position = UDim2.new(0, 0, 0, 14)
	multSliderBg:FindFirstChild("MultSliderCorner").CornerRadius = UDim.new(0, 5)

	multSliderBtn.Size = UDim2.new(0, 34, 1, -4)
	multSliderBtn.Position = UDim2.new(0, 2, 0, 2)
	multSliderBtn.TextSize = 9

	durSection.Size = UDim2.new(1, 0, 0, 38)

	durLabel.Size = UDim2.new(1, 0, 0, 12)
	durLabel.TextSize = 8

	durSliderBg.Size = UDim2.new(1, 0, 0, 22)
	durSliderBg.Position = UDim2.new(0, 0, 0, 14)
	durSliderBg:FindFirstChild("DurSliderCorner").CornerRadius = UDim.new(0, 5)

	durSliderBtn.Size = UDim2.new(0, 34, 1, -4)
	durSliderBtn.Position = UDim2.new(0, 2, 0, 2)
	durSliderBtn.TextSize = 9

	priceCard.Visible = false

	buyButton.Size = UDim2.new(1, 0, 0, 30)
	buyButton.Text = "✅ BELI - $2M"
	buyButton.TextSize = 9

end

-- ============================================
-- VARIABLES
-- ============================================

local currentMultiplier = 2
local currentHours = 1
local shopData = nil

-- ============================================
-- FUNCTIONS
-- ============================================

local function formatMoney(amount)
	if isMobile then
		if amount >= 1000000000 then
			return string.format("%.0fB", amount / 1000000000)
		elseif amount >= 1000000 then
			return string.format("%.0fM", amount / 1000000)
		elseif amount >= 1000 then
			return string.format("%.0fK", amount / 1000)
		else
			return tostring(amount)
		end
	else
		if amount >= 1000000000 then
			return string.format("$%.1fB", amount / 1000000000)
		elseif amount >= 1000000 then
			return string.format("$%.1fM", amount / 1000000)
		elseif amount >= 1000 then
			return string.format("$%.1fK", amount / 1000)
		else
			return "$" .. tostring(amount)
		end
	end
end

local function formatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)

	if isMobile then
		if hours > 0 then
			return string.format("%dj", hours)
		elseif mins > 0 then
			return string.format("%dm", mins)
		else
			return string.format("%ds", seconds)
		end
	else
		if hours > 0 then
			return string.format("%dj %dm", hours, mins)
		elseif mins > 0 then
			return string.format("%d menit", mins)
		else
			return string.format("%d detik", seconds)
		end
	end
end

local function calculatePrice(mult, hours)
	return math.floor(mult * mult * hours * (shopData and shopData.basePrice or 500000))
end

local function updateDisplay()
	local price = calculatePrice(currentMultiplier, currentHours)

	if isMobile then
		multLabel.Text = string.format("Multiplier: x%d", currentMultiplier)
		multSliderBtn.Text = string.format("x%d", currentMultiplier)

		durLabel.Text = string.format("Durasi: %d Jam", currentHours)
		durSliderBtn.Text = string.format("%dh", currentHours)

		buyButton.Text = string.format("✅ BELI - $%s", formatMoney(price))
	else
		multLabel.Text = string.format("Multiplier: x%d", currentMultiplier)
		multSliderBtn.Text = string.format("x%d", currentMultiplier)

		durLabel.Text = string.format("Durasi: %d Jam", currentHours)
		durSliderBtn.Text = string.format("%dh", currentHours)

		priceLabel.Text = "💵 " .. formatMoney(price)
	end

	local maxMult = (shopData and shopData.maxMultiplier or 10)
	local multPercent = (currentMultiplier - 2) / (maxMult - 2)
	local multBtnWidth = multSliderBtn.AbsoluteSize.X
	local multMaxWidth = multSliderBg.AbsoluteSize.X - multBtnWidth - 4
	multSliderBtn.Position = UDim2.new(0, 2 + (multPercent * multMaxWidth), 0, 2)

	local maxHours = (shopData and shopData.maxHours or 24)
	local durPercent = (currentHours - 1) / (maxHours - 1)
	local durBtnWidth = durSliderBtn.AbsoluteSize.X
	local durMaxWidth = durSliderBg.AbsoluteSize.X - durBtnWidth - 4
	durSliderBtn.Position = UDim2.new(0, 2 + (durPercent * durMaxWidth), 0, 2)
end

local function refreshShop()
	local success, data = pcall(function()
		return GetShopInfo:InvokeServer()
	end)

	if success and data then
		shopData = data

		moneyValue.Text = (isMobile and "$" or "") .. formatMoney(data.money)

		if data.active and data.multiplier > 1 then
			if isMobile then
				luckLabel.Text = string.format("x%d (Aktif!)", data.multiplier)
				timeLabel.Text = formatTime(data.timeLeft) .. " lagi"
			else
				luckLabel.Text = string.format("LUCK: x%d (Aktif!)", data.multiplier)
				timeLabel.Text = "WAKTU: " .. formatTime(data.timeLeft)
			end
			luckLabel.TextColor3 = Color3.fromRGB(70, 200, 100)
			timeLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		else
			if isMobile then
				luckLabel.Text = "x1"
				timeLabel.Text = "Tidak aktif"
			else
				luckLabel.Text = "LUCK: x1"
				timeLabel.Text = "WAKTU: Tidak aktif"
			end
			luckLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			timeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		end

		updateDisplay()
	end
end

-- ============================================
-- SLIDER LOGIC
-- ============================================

local draggingMult = false
local draggingDur = false

multSliderBtn.MouseButton1Down:Connect(function()
	draggingMult = true
end)

durSliderBtn.MouseButton1Down:Connect(function()
	draggingDur = true
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or 
		input.UserInputType == Enum.UserInputType.Touch then
		draggingMult = false
		draggingDur = false
	end
end)

RunService.RenderStepped:Connect(function()
	if draggingMult then
		local mouse = player:GetMouse()
		local sliderPos = multSliderBg.AbsolutePosition.X
		local btnWidth = multSliderBtn.AbsoluteSize.X
		local sliderSize = multSliderBg.AbsoluteSize.X - btnWidth - 4
		local mouseX = mouse.X - sliderPos - 2

		local percent = math.clamp(mouseX / sliderSize, 0, 1)
		local maxMult = (shopData and shopData.maxMultiplier or 10)
		currentMultiplier = math.floor(2 + percent * (maxMult - 2))

		updateDisplay()
	end

	if draggingDur then
		local mouse = player:GetMouse()
		local sliderPos = durSliderBg.AbsolutePosition.X
		local btnWidth = durSliderBtn.AbsoluteSize.X
		local sliderSize = durSliderBg.AbsoluteSize.X - btnWidth - 4
		local mouseX = mouse.X - sliderPos - 2

		local percent = math.clamp(mouseX / sliderSize, 0, 1)
		local maxHours = (shopData and shopData.maxHours or 24)
		currentHours = math.floor(1 + percent * (maxHours - 1))

		updateDisplay()
	end
end)

-- ============================================
-- BUTTONS
-- ============================================

buyButton.MouseButton1Click:Connect(function()
	PurchaseBoost:FireServer(currentMultiplier, currentHours)
	task.wait(0.5)
	refreshShop()
end)

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
end)

-- ============================================
-- NOTIFICATIONS
-- ============================================

ShowNotification.OnClientEvent:Connect(function(title, message, color)
	local notif = Instance.new("Frame")
	notif.Size = isMobile and UDim2.fromOffset(280, 50) or UDim2.fromOffset(300, 60)
	notif.Position = isMobile and UDim2.new(0.5, -140, 0, -60) or UDim2.new(1, -310, 0, -70)
	notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	notif.BorderSizePixel = 0
	notif.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notif

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(70, 200, 100)
	stroke.Thickness = 2
	stroke.Parent = notif

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = isMobile and UDim2.new(1, -12, 0, 16) or UDim2.new(1, -16, 0, 20)
	titleLbl.Position = isMobile and UDim2.new(0, 6, 0, 4) or UDim2.new(0, 8, 0, 6)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLbl.TextSize = isMobile and 10 or 12
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = notif

	local msgLbl = Instance.new("TextLabel")
	msgLbl.Size = isMobile and UDim2.new(1, -12, 0, 26) or UDim2.new(1, -16, 0, 30)
	msgLbl.Position = isMobile and UDim2.new(0, 6, 0, 20) or UDim2.new(0, 8, 0, 26)
	msgLbl.BackgroundTransparency = 1
	msgLbl.Text = message
	msgLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	msgLbl.TextSize = isMobile and 9 or 10
	msgLbl.Font = Enum.Font.Gotham
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextWrapped = true
	msgLbl.Parent = notif

	TweenService:Create(notif, TweenInfo.new(0.3), {
		Position = isMobile and UDim2.new(0.5, -140, 0, 10) or UDim2.new(1, -310, 0, 10)
	}):Play()

	task.wait(2.5)
	TweenService:Create(notif, TweenInfo.new(0.3), {
		Position = isMobile and UDim2.new(0.5, -140, 0, -60) or UDim2.new(1, -310, 0, -70)
	}):Play()
	task.wait(0.3)
	notif:Destroy()
end)

-- ============================================
-- INIT
-- ============================================

mainFrame.Visible = false
task.wait(1)
refreshShop()

-- Auto refresh every 2 seconds when open
task.spawn(function()
	while task.wait(2) do
		if mainFrame.Visible then
			refreshShop()
		end
	end
end)


