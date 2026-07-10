--[[
	RodShopGuiManager (Client) - New GUI
	
	Struktur GUI baru (RodShopGui):
	  MainFrame
	    Header (Title, CoinsDisplay, CloseButton)
	    TabsFrame (RodsTabButton) -- Skins dihapus
	    ContentFrame
	      RodsContent (Template card di dalamnya)
	
	Template card:
	  UIStroke
	  BG > Vector (rod image)
	  Padded > Top > RodName, PriceLabel
	  Padded > Bottom > Luck/Weight/Rarity (Counter labels)
	  BuyButton
	  OwnedLabel
	
	Tanpa: Skins, GiftButton, GiftRod
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local FishingConfig = require(FishingSystem:WaitForChild("FishingConfig"))
local RarityColors = FishingConfig.RarityColors or {}
local GlobalLuckVal = FishingSystem:WaitForChild("GlobalLuckMultiplier")

local ShopEvents = FishingSystem:WaitForChild("RodShopEvents")
local rfGetShopData = ShopEvents:WaitForChild("GetShopData")
local reRequestPurchase = ShopEvents:WaitForChild("RequestPurchase")
local rePurchaseSuccess = ShopEvents:WaitForChild("PurchaseSuccess")

-- ===================================================================
-- STATE
-- ===================================================================
local playerCoins = 0
local ownedRods = {}
local allRodData = {}
local shopDataLoaded = false
local isShopOpen = false
local currencyName = "Cash"

local gui = {}
local closeConn = nil
local npcConn = nil
local currencyConn = nil
local buttonConns = {}

-- ===================================================================
-- SOUND (asset IDs dari script lama, reuse 1 instance)
-- ===================================================================
local SOUNDS = {
	Click    = "rbxassetid://340910329",
	Hover    = "rbxassetid://5852311399",
	Purchase = "rbxassetid://4525871712",
	Error    = "rbxassetid://550209561",
	Open     = "rbxassetid://4943184703",
	Close    = "rbxassetid://4943184703",
}

local reusableSound = Instance.new("Sound")
reusableSound.Volume = 0.3
reusableSound.Parent = SoundService

local function playSound(name, volume)
	local id = SOUNDS[name]
	if not id then return end
	reusableSound.SoundId = id
	reusableSound.Volume = volume or 0.3
	reusableSound:Play()
end

-- ===================================================================
-- HELPERS
-- ===================================================================
local function formatNumber(n)
	local s = tostring(math.floor(n))
	return string.reverse(string.reverse(s):gsub("(%d%d%d)", "%1,")):gsub("^,", "")
end

local function cleanAssetId(raw)
	if not raw or raw == "" then return "" end
	local s = tostring(raw)
	if s == "0" then return "" end
	if s:match("^rbxassetid://") then return s end
	local id = s:match("%d+")
	return (id and tonumber(id) ~= 0) and ("rbxassetid://" .. id) or ""
end

-- ===================================================================
-- CURRENCY (Cash > Money > Coins)
-- ===================================================================
local function getCurrencyStat()
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return nil end
	for _, name in ipairs({"Cash", "Money", "Coins"}) do
		local c = ls:FindFirstChild(name)
		if c and (c:IsA("IntValue") or c:IsA("NumberValue")) then
			currencyName = name
			return c
		end
	end
	return nil
end

local function updateCoinsLabel()
	if gui.CoinsDisplay then
		gui.CoinsDisplay.Text = string.format("💰 %s: %s", currencyName, formatNumber(playerCoins))
	end
end

local function bindCurrencyChanged()
	if currencyConn then currencyConn:Disconnect(); currencyConn = nil end

	local c = getCurrencyStat()
	if not c then return end

	playerCoins = c.Value
	updateCoinsLabel()

	currencyConn = c.Changed:Connect(function(newVal)
		playerCoins = newVal
		if isShopOpen then updateCoinsLabel() end
	end)
end

-- ===================================================================
-- SORT RODS
-- ===================================================================
local function sortRods(rodDataTable)
	local list = {}
	for rodName, data in pairs(rodDataTable) do
		table.insert(list, {
			name = rodName,
			data = data,
			luck = data.Stats and data.Stats.baseLuck or 0,
			weight = data.Stats and data.Stats.maxWeight or 0,
		})
	end
	table.sort(list, function(a, b)
		if a.luck ~= b.luck then return a.luck > b.luck end
		return a.weight > b.weight
	end)
	return list
end

-- ===================================================================
-- BUILD GUI REFS
-- ===================================================================
local function buildGuiRefs()
	-- Disconnect old
	if closeConn then closeConn:Disconnect(); closeConn = nil end
	for _, c in ipairs(buttonConns) do if c and c.Connected then c:Disconnect() end end
	table.clear(buttonConns)

	local screenGui = playerGui:WaitForChild("RodShopGui", 10)
	if not screenGui then return false end

	local mainFrame = screenGui:FindFirstChild("MainFrame")
	if not mainFrame then return false end

	local header = mainFrame:FindFirstChild("Header")
	local tabsFrame = mainFrame:FindFirstChild("TabsFrame")
	local contentFrame = mainFrame:FindFirstChild("ContentFrame")

	if not header or not contentFrame then return false end

	local rodsContent = contentFrame:FindFirstChild("RodsContent")
	if not rodsContent then
		-- Fallback: mungkin masih pakai ScrollFrame
		rodsContent = mainFrame:FindFirstChild("ScrollFrame") or contentFrame
	end

	-- Cari template di dalam RodsContent
	local template = rodsContent:FindFirstChild("Template")

	gui = {
		ScreenGui = screenGui,
		MainFrame = mainFrame,
		Header = header,
		Title = header:FindFirstChild("Title"),
		CoinsDisplay = header:FindFirstChild("CoinsDisplay"),
		CloseButton = header:FindFirstChild("CloseButton"),
		TabsFrame = tabsFrame,
		RodsContent = rodsContent,
		Template = template,
	}

	-- Sembunyikan skins tab kalau ada
	if tabsFrame then
		local skinsTab = tabsFrame:FindFirstChild("SkinsTabButton")
		if skinsTab then skinsTab.Visible = false end

		-- Highlight rods tab
		local rodsTab = tabsFrame:FindFirstChild("RodsTabButton")
		if rodsTab then rodsTab.BackgroundColor3 = Color3.fromRGB(106, 106, 106) end
	end

	-- Sembunyikan SkinsContent kalau ada
	if contentFrame:FindFirstChild("SkinsContent") then
		contentFrame.SkinsContent.Visible = false
	end

	mainFrame.Visible = false

	-- Close button
	if gui.CloseButton then
		closeConn = gui.CloseButton.MouseButton1Click:Connect(function()
			setShopVisible(false)
		end)
		gui.CloseButton.MouseEnter:Connect(function() playSound("Hover", 0.2) end)
	end

	return true
end

-- ===================================================================
-- CREATE ROD CARD
-- ===================================================================
local function createRodCard(rodName, data, layoutOrder)
	if not gui.Template then return nil end

	local card = gui.Template:Clone()
	card.Name = rodName
	card.Visible = true
	card.LayoutOrder = layoutOrder

	local shopInfo = data.ShopInfo
	local stats = data.Stats or {}
	local multiplier = GlobalLuckVal.Value or 1
	local finalLuck = (stats.baseLuck or 1) * multiplier
	local rarity = stats.rarity or "Common"
	local rarityColor = RarityColors[rarity] or Color3.new(1, 1, 1)

	-- UIStroke (border glow berdasarkan rarity)
	local stroke = card:FindFirstChild("UIStroke")
	if stroke then
		stroke.Color = rarityColor
		stroke.Thickness = 3
		-- Animasi glow untuk rod langka
		if rarity == "Legendary" or rarity == "Mitos" or rarity == "Secret" or rarity == "Unknown" then
			stroke.Transparency = 0
			TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Transparency = 0.5
			}):Play()
		end
	end

	-- Rod Image (BG > Vector)
	local bg = card:FindFirstChild("BG")
	if bg then
		local vector = bg:FindFirstChild("Vector")
		if vector and data.TextureId then
			local tex = cleanAssetId(data.TextureId)
			if tex ~= "" then
				vector.Image = tex
				vector.ImageColor3 = Color3.fromRGB(255, 255, 255)
				vector.ImageTransparency = 0
				vector.Visible = true
			end
		end
	end

	-- Padded > Top (RodName, PriceLabel)
	local padded = card:FindFirstChild("Padded")
	if padded then
		local top = padded:FindFirstChild("Top")
		if top then
			local nameLabel = top:FindFirstChild("RodName")
			if nameLabel then
				nameLabel.Text = rodName
				nameLabel.TextColor3 = rarityColor
			end

			local priceLabel = top:FindFirstChild("PriceLabel")
			if priceLabel and shopInfo then
				if shopInfo.Type == "Currency" then
					priceLabel.Text = "💰 " .. formatNumber(shopInfo.Value)
					priceLabel.TextColor3 = Color3.fromRGB(255, 223, 85)
				elseif shopInfo.Type == "Gamepass" then
					priceLabel.Text = "💎 GAMEPASS"
					priceLabel.TextColor3 = Color3.fromRGB(85, 170, 255)
				end
			end
		end

		-- Padded > Bottom (Luck, Weight, Rarity counters)
		local bottom = padded:FindFirstChild("Bottom")
		if bottom then
			local luck = bottom:FindFirstChild("Luck")
			if luck then
				local ctr = luck:FindFirstChild("Counter")
				if ctr then
					ctr.RichText = true
					if multiplier > 1 then
						ctr.Text = string.format("<font color='#00FF00'><b>%.1fx</b></font>", finalLuck)
					else
						ctr.Text = string.format("%.1fx", finalLuck)
					end
				end
			end

			local weight = bottom:FindFirstChild("Weight")
			if weight then
				local ctr = weight:FindFirstChild("Counter")
				if ctr then ctr.Text = string.format("%dkg", stats.maxWeight or 0) end
			end

			local rarityFrame = bottom:FindFirstChild("Rarity")
			if rarityFrame then
				local ctr = rarityFrame:FindFirstChild("Counter")
				if ctr then
					ctr.Text = rarity
					ctr.TextColor3 = rarityColor
				end
			end
		end
	end

	-- Buy / Owned
	local buyButton = card:FindFirstChild("BuyButton")
	local ownedLabel = card:FindFirstChild("OwnedLabel")
	local giftButton = card:FindFirstChild("GiftButton")

	-- Sembunyikan gift button
	if giftButton then giftButton.Visible = false end

	if table.find(ownedRods, rodName) then
		if buyButton then buyButton.Visible = false end
		if ownedLabel then ownedLabel.Visible = true end
	else
		if ownedLabel then ownedLabel.Visible = false end
		if buyButton then
			buyButton.Visible = true
			-- Gamepass: ubah warna button
			if shopInfo and shopInfo.Type == "Gamepass" then
				buyButton.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
			end
			buyButton.MouseEnter:Connect(function() playSound("Hover", 0.2) end)
			buyButton.MouseButton1Click:Connect(function()
				playSound("Click")
				if shopInfo and shopInfo.Type == "Currency" and playerCoins < shopInfo.Value then
					playSound("Error", 0.4)
					return
				end
				reRequestPurchase:FireServer(rodName)
			end)
		end
	end

	return card
end

-- ===================================================================
-- POPULATE SHOP
-- ===================================================================
local function populateShop()
	if not gui.RodsContent then return end

	-- Clear existing cards (jangan hapus Template)
	for _, child in ipairs(gui.RodsContent:GetChildren()) do
		if (child:IsA("Frame") or child:IsA("ImageButton")) and child.Name ~= "Template" then
			child:Destroy()
		end
	end

	-- Update coins
	local c = getCurrencyStat()
	if c then
		playerCoins = c.Value
		updateCoinsLabel()
	end

	-- Sort dan render
	local sorted = sortRods(allRodData)
	for i, rodInfo in ipairs(sorted) do
		local card = createRodCard(rodInfo.name, rodInfo.data, i)
		if card then
			card.Parent = gui.RodsContent
		end
	end
end

-- ===================================================================
-- DATA FETCHING
-- ===================================================================
local function preloadShopData()
	local ok, data = pcall(function() return rfGetShopData:InvokeServer() end)
	if ok and data then
		ownedRods = data.OwnedRods or {}
		allRodData = data.AllRodData or {}
		shopDataLoaded = true
	end
end

local function refreshShopData()
	if gui.CoinsDisplay then gui.CoinsDisplay.Text = "💰 Loading..." end
	local ok, data = pcall(function() return rfGetShopData:InvokeServer() end)
	if ok and data then
		ownedRods = data.OwnedRods or {}
		allRodData = data.AllRodData or {}
		populateShop()
	end
end

-- ===================================================================
-- SHOW / HIDE
-- ===================================================================
function setShopVisible(visible)
	if not gui.MainFrame then return end
	if visible == isShopOpen then return end
	isShopOpen = visible

	if visible then
		playSound("Open")
		if shopDataLoaded then
			populateShop()
		else
			refreshShopData()
		end
		gui.MainFrame.Visible = true
	else
		playSound("Close")
		gui.MainFrame.Visible = false
	end
end

-- ===================================================================
-- NPC PROMPT
-- ===================================================================
local function connectNpcPrompt()
	if npcConn then npcConn:Disconnect(); npcConn = nil end

	local npc = workspace:WaitForChild("RodShop", 30)
	if not npc then return end

	-- Cari ProximityPrompt
	local prompt = npc:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso")
		if root then prompt = root:FindFirstChildOfClass("ProximityPrompt") end
	end
	if not prompt then
		for _, desc in ipairs(npc:GetDescendants()) do
			if desc:IsA("ProximityPrompt") then prompt = desc; break end
		end
	end
	if not prompt then return end

	npcConn = prompt.Triggered:Connect(function(p)
		if p == player then setShopVisible(true) end
	end)
end

-- ===================================================================
-- CHARACTER SETUP
-- ===================================================================
local function onCharacterAdded(character)
	setShopVisible(false)
	task.wait(0.5)
	buildGuiRefs()
	connectNpcPrompt()
	bindCurrencyChanged()

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function() setShopVisible(false) end)
	end
end

-- ===================================================================
-- EVENTS
-- ===================================================================
rePurchaseSuccess.OnClientEvent:Connect(function()
	playSound("Purchase", 0.5)
	if isShopOpen then
		task.wait(0.2)
		refreshShopData()
	end
end)

GlobalLuckVal:GetPropertyChangedSignal("Value"):Connect(function()
	if isShopOpen then populateShop() end
end)

-- ===================================================================
-- INIT
-- ===================================================================
buildGuiRefs()
task.spawn(preloadShopData)
bindCurrencyChanged()

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)