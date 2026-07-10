-- ═══════════════════════════════════════════════════════════════
-- 🔥 FLOATING ACTION BAR - v5 OPTIMIZED (No debug prints)
-- ═══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════
-- PLATFORM DETECTION
-- ═══════════════════════════════════════════════════════════════

local isMobile = UserInputService.TouchEnabled

-- ═══════════════════════════════════════════════════════════════
-- SIZE CONFIG
-- ═══════════════════════════════════════════════════════════════

local CONFIG = {
	MOBILE = {
		BAR_HEIGHT = 30,
		ICON_SIZE = 18,
		TOGGLE_SIZE = 20,
		PADDING = 3,
		SPACING = 3,
		CORNER_RADIUS = 17,
		CURRENCY_WIDTH = 28,
		CURRENCY_TEXT_SIZE = 9,
	},
	PC = {
		BAR_HEIGHT = 40,
		ICON_SIZE = 24,
		TOGGLE_SIZE = 26,
		PADDING = 7,
		SPACING = 7,
		CORNER_RADIUS = 20,
		CURRENCY_WIDTH = 70,
		CURRENCY_TEXT_SIZE = 12,
	}
}

local CFG = isMobile and CONFIG.MOBILE or CONFIG.PC

-- ═══════════════════════════════════════════════════════════════
-- GET GUI
-- ═══════════════════════════════════════════════════════════════

local gui = playerGui:WaitForChild("FloatingActionBar", 10)
if not gui then
	warn("❌ FloatingActionBar not found!")
	return
end

local mainContainer = gui:WaitForChild("MainContainer")
local bgFrame = mainContainer:WaitForChild("Background")
local buttonContainer = bgFrame:WaitForChild("ButtonContainer")

-- Buttons
local toggleBtn = buttonContainer:FindFirstChild("ToggleButton")
local hideUIBtn = buttonContainer:FindFirstChild("HideUIBtn")
local playerListBtn = buttonContainer:FindFirstChild("PlayerListBtn")
local auraShopBtn = buttonContainer:FindFirstChild("AuraShopBtn")
local luckShopBtn = buttonContainer:FindFirstChild("LuckShopBtn")
local freeCamBtn = buttonContainer:FindFirstChild("FreeCamBtn")
local currencyFrame = buttonContainer:FindFirstChild("CurrencyFrame")
local currencyLabel = currencyFrame and currencyFrame:FindFirstChild("CurrencyLabel")

-- State
local isExpanded = true
local isUIHidden = false
local freeCamEnabled = false
local hiddenGuis = {}

-- ═══════════════════════════════════════════════════════════════
-- CALCULATE SIZES
-- ═══════════════════════════════════════════════════════════════

local function calculateExpandedWidth()
	return CFG.PADDING * 2 + CFG.TOGGLE_SIZE + (CFG.ICON_SIZE * 5) + CFG.CURRENCY_WIDTH + (CFG.SPACING * 6)
end

local EXPANDED_WIDTH = calculateExpandedWidth()
local COLLAPSED_WIDTH = CFG.TOGGLE_SIZE + (CFG.PADDING * 2) + 6

local EXPANDED_SIZE = UDim2.fromOffset(EXPANDED_WIDTH, CFG.BAR_HEIGHT)
local COLLAPSED_SIZE = UDim2.fromOffset(COLLAPSED_WIDTH, CFG.BAR_HEIGHT)

-- ═══════════════════════════════════════════════════════════════
-- APPLY RESPONSIVE SIZES
-- ═══════════════════════════════════════════════════════════════

local function applyResponsiveSizes()
	local bgCorner = bgFrame:FindFirstChildOfClass("UICorner")
	if bgCorner then
		bgCorner.CornerRadius = UDim.new(0, CFG.CORNER_RADIUS)
	end

	buttonContainer.Size = UDim2.new(1, -CFG.PADDING*2, 1, -CFG.PADDING*2)
	buttonContainer.Position = UDim2.new(0, CFG.PADDING, 0, CFG.PADDING)

	local layout = buttonContainer:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, CFG.SPACING)
	end

	if toggleBtn then
		toggleBtn.Size = UDim2.fromOffset(CFG.TOGGLE_SIZE, CFG.TOGGLE_SIZE)
	end

	local buttons = {hideUIBtn, playerListBtn, auraShopBtn, luckShopBtn, freeCamBtn}
	for _, btn in ipairs(buttons) do
		if btn then
			btn.Size = UDim2.fromOffset(CFG.ICON_SIZE, CFG.ICON_SIZE)
		end
	end

	if currencyFrame then
		currencyFrame.Size = UDim2.fromOffset(CFG.CURRENCY_WIDTH, CFG.ICON_SIZE)
	end
	if currencyLabel then
		currencyLabel.TextSize = CFG.CURRENCY_TEXT_SIZE
	end
end

applyResponsiveSizes()
mainContainer.Size = EXPANDED_SIZE

-- ═══════════════════════════════════════════════════════════════
-- HELPER
-- ═══════════════════════════════════════════════════════════════

local function tween(obj, time, props, style, dir)
	if not obj then return end
	TweenService:Create(obj, TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end

local function setButtonsVisible(visible)
	local buttons = {hideUIBtn, playerListBtn, auraShopBtn, luckShopBtn, freeCamBtn, currencyFrame}
	for _, btn in ipairs(buttons) do
		if btn then btn.Visible = visible end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- TOGGLE EXPAND/COLLAPSE
-- ═══════════════════════════════════════════════════════════════

local function toggleExpand()
	isExpanded = not isExpanded

	local targetSize = isExpanded and EXPANDED_SIZE or COLLAPSED_SIZE
	local targetRotation = isExpanded and 0 or 180

	tween(mainContainer, 0.25, {Size = targetSize}, Enum.EasingStyle.Back)

	if toggleBtn then
		tween(toggleBtn, 0.25, {Rotation = targetRotation}, Enum.EasingStyle.Back)
	end

	if isExpanded then
		task.delay(0.1, function()
			setButtonsVisible(true)
		end)
	else
		setButtonsVisible(false)
	end
end

if toggleBtn then
	toggleBtn.Activated:Connect(toggleExpand)
end

-- ═══════════════════════════════════════════════════════════════
-- HIDE UI
-- ═══════════════════════════════════════════════════════════════

local function toggleHideUI()
	isUIHidden = not isUIHidden

	if isUIHidden then
		hiddenGuis = {}
		for _, guiObj in ipairs(playerGui:GetChildren()) do
			if guiObj:IsA("ScreenGui") and guiObj.Name ~= "FloatingActionBar" and guiObj.Enabled then
				table.insert(hiddenGuis, guiObj)
				guiObj.Enabled = false
			end
		end
		if hideUIBtn then hideUIBtn.ImageTransparency = 0.5 end
	else
		for _, guiObj in ipairs(hiddenGuis) do
			if guiObj and guiObj.Parent then guiObj.Enabled = true end
		end
		hiddenGuis = {}
		if hideUIBtn then hideUIBtn.ImageTransparency = 0 end
	end
end

if hideUIBtn then
	hideUIBtn.Activated:Connect(toggleHideUI)
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER LIST
-- ═══════════════════════════════════════════════════════════════

if playerListBtn then
	playerListBtn.Activated:Connect(function()
		local lbGui = playerGui:FindFirstChild("LeaderboardUI_V11")
		if not lbGui then return end

		if _G.ToggleLeaderboardUI then
			-- toggle berdasarkan visibility internal
			_G.ToggleLeaderboardUI()
		else
			-- fallback kasar (kalau script belum load)
			lbGui.Enabled = not lbGui.Enabled
		end
	end)
end


-- ═══════════════════════════════════════════════════════════════
-- AURA SHOP
-- ═══════════════════════════════════════════════════════════════

if auraShopBtn then
	auraShopBtn.Activated:Connect(function()
		local auraGui = playerGui:FindFirstChild("AuraUI")
		if auraGui then
			local target = auraGui:FindFirstChild("AuraMainFrame") or auraGui:FindFirstChild("MainFrame")
			if target then
				target.Visible = not target.Visible
				auraShopBtn.ImageTransparency = target.Visible and 0 or 0.5
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- LUCK SHOP
-- ═══════════════════════════════════════════════════════════════

if luckShopBtn then
	luckShopBtn.Activated:Connect(function()
		local luckGui = playerGui:FindFirstChild("LuckBoostShopGui")
		if luckGui then
			local target = luckGui:FindFirstChild("MainFrame")
			if target then
				target.Visible = not target.Visible
				luckShopBtn.ImageTransparency = target.Visible and 0 or 0.5
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- FREE CAM
-- ═══════════════════════════════════════════════════════════════

if freeCamBtn then
	freeCamBtn.Activated:Connect(function()
		freeCamEnabled = not freeCamEnabled

		if freeCamEnabled then
			if _G.__Freecam_Enable then _G.__Freecam_Enable() end
			freeCamBtn.ImageTransparency = 0.5
		else
			if _G.__Freecam_Disable then _G.__Freecam_Disable() end
			freeCamBtn.ImageTransparency = 0
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- CURRENCY
-- ═══════════════════════════════════════════════════════════════

local function formatCurrency(amount)
	amount = amount or 0
	if amount >= 1000000000 then
		return string.format("%.1fB", amount / 1000000000)
	elseif amount >= 1000000 then
		return string.format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	else
		return tostring(math.floor(amount))
	end
end

local function updateCurrency()
	if not currencyLabel then return end

	local playerData = player:FindFirstChild("PlayerData")
	if playerData then
		local cash = playerData:FindFirstChild("Cash")
		if cash then
			currencyLabel.Text = formatCurrency(cash.Value)
			return
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local money = leaderstats:FindFirstChild("Money") or leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Coins")
		if money then 
			currencyLabel.Text = formatCurrency(money.Value)
			return
		end
	end

	currencyLabel.Text = "0"
end

task.spawn(function()
	task.wait(2)

	local playerData = player:WaitForChild("PlayerData", 10)
	if playerData then
		local cash = playerData:FindFirstChild("Cash")
		if cash then
			cash:GetPropertyChangedSignal("Value"):Connect(updateCurrency)
		end
	end

	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		for _, child in ipairs(leaderstats:GetChildren()) do
			if child:IsA("IntValue") or child:IsA("NumberValue") then
				child:GetPropertyChangedSignal("Value"):Connect(updateCurrency)
			end
		end
	end

	updateCurrency()
end)
