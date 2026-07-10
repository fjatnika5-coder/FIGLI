-- ════════════════════════════════════════════════════════════════
-- ✅ ASSET MANAGER - FIXED (NO MEMORY LEAKS!)
-- Location: ServerScriptService/AssetManager (or similar)
-- ════════════════════════════════════════════════════════════════

local AssetManager = {}

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local UrlA = "https://catalog.roproxy.com/v1/search/items/details?Category=3&CreatorName="
local UrlB = "https://www.roproxy.com/users/inventory/list-json?assetTypeId=34&cursor=&itemsPerPage=100&pageNumber=%s&userId=%s"

AssetManager.Gamepasses = {}
AssetManager.Clothing = {}

-- 🆕 TRACK ACTIVE BOOTHS FOR CLEANUP
local activeBooths = {}

local function formatAmount(amount)
	local formatted = tostring(amount)
	while true do
		local k
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

local defaultSize = UDim2.new(0, 90, 0, 95)

-- 🆕 SAFE HTTP REQUEST WITH RETRY
local function safeHttpGet(url, maxRetries)
	maxRetries = maxRetries or 3
	local retryDelay = 1

	for attempt = 1, maxRetries do
		local success, result = pcall(function()
			return HttpService:GetAsync(url, true)
		end)

		if success then
			return success, result
		elseif result == "HTTP 429 (Too Many Requests)" and attempt < maxRetries then
			task.wait(retryDelay)
			retryDelay = retryDelay * 1.5 -- Exponential backoff
		else
			return false, result
		end
	end

	return false, "Max retries exceeded"
end

local function getUserGeneratedTShirtsRecursive(username, SignPrices, tshirts)
	tshirts = tshirts or {}

	local success, result = safeHttpGet(UrlA .. username)
	if not success then
		warn("Failed to get T-shirts:", result)
		return tshirts
	end

	local data = HttpService:JSONDecode(result).data
	if data then
		table.sort(data, function(a, b) return a.price < b.price end)
		for _, item in ipairs(data) do
			pcall(function()
				if not tshirts[item.id] then
					tshirts[item.id] = true

					-- 🆕 CREATE BUTTON SAFELY
					local newBtn = script.Template:Clone()
					newBtn.Size = defaultSize
					newBtn.Name = tostring(item.id)
					newBtn.PurchaseButton.Text = "" .. formatAmount(item.price)
					newBtn.LayoutOrder = item.price
					newBtn.ImportantValues.AssetId.Value = item.id
					newBtn.Parent = SignPrices
				end
			end)
		end
	end
	return tshirts
end

local function getUserCreatedGamepassesRecursive(userId, SignPrices, gamepasses)
	gamepasses = gamepasses or {}

	local success, result = safeHttpGet(UrlB:format(1, userId))
	if not success then
		warn("Failed to get gamepasses:", result)
		return gamepasses
	end

	local success2, decoded = pcall(function()
		return HttpService:JSONDecode(result)
	end)

	if success2 and decoded then
		for _, gamepass in ipairs(decoded.Data.Items) do
			if gamepass.Creator.Id == userId and not gamepasses[gamepass.Item.AssetId] then
				gamepasses[gamepass.Item.AssetId] = true
				pcall(function()
					local newBtn = script.Template:Clone()
					newBtn.Size = defaultSize
					newBtn.Name = tostring(gamepass.Item.AssetId)
					newBtn.PurchaseButton.Text = "" .. formatAmount(gamepass.Product.PriceInRobux)
					newBtn.LayoutOrder = gamepass.Product.PriceInRobux
					newBtn.ImportantValues.AssetId.Value = gamepass.Item.AssetId
					newBtn.ImportantValues.AssetType.Value = "Gamepass"
					newBtn.Parent = SignPrices
				end)
			end
		end
	end

	return gamepasses
end

local function GetClothings(userId)
	local baseLink = "https://catalog.RoProxy.com/v1/search/items/details?Category=3&CreatorType=%22User%22&IncludeNotForSale=false&Limit=30&CreatorTargetId="
	local link = baseLink .. userId

	local success, result = safeHttpGet(link)
	if not success then
		warn("Failed to get clothings:", result)
		return nil
	end

	local ForReturn = {}
	local AssetType = {}

	local su, decoded = pcall(function()
		return HttpService:JSONDecode(result)
	end)

	if su and decoded then
		for _, item in pairs(decoded["data"]) do
			ForReturn[item.id] = true
			table.insert(AssetType, item.assetType)
		end
	end

	if next(ForReturn) == nil then
		return nil
	else
		return ForReturn, AssetType
	end
end

local function GetContent(player, userId)
	local Clothings, AssetType = GetClothings(userId)
	local gamepasses = {}

	local GetGamesUrl1 = "https://games.RoProxy.com/v2/users/"
	local GetGamesUrl2 = "/games?accessFilter=Public&sortOrder=Asc&limit=50"
	local getGamesUrl = GetGamesUrl1 .. userId .. GetGamesUrl2

	local success, result = safeHttpGet(getGamesUrl)
	if success then
		pcall(function()
			result = HttpService:JSONDecode(result)
			for _, GameInfo in pairs(result["data"]) do
				local gameId = GameInfo.id
				local url = "https://games.roproxy.com/v1/games/" .. gameId .. "/game-passes?limit=100&sortOrder=Asc"

				local success2, result2 = safeHttpGet(url)
				if success2 then
					result2 = HttpService:JSONDecode(result2)
					for _, GamepassDetail in pairs(result2["data"]) do
						gamepasses[GamepassDetail.id] = true
					end
				end
			end
		end)
	end

	if next(gamepasses) == nil then
		return Clothings, AssetType, nil
	else
		return Clothings, AssetType, gamepasses
	end
end

-- 🆕 CLEANUP OLD BUTTONS (PREVENT LEAK!)
local function cleanupBoothUI(SignPrices)
	if not SignPrices then return end

	for _, child in ipairs(SignPrices:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
			pcall(function()
				child:Destroy()
			end)
		end
	end
end

local function SetProducts(productTable, enumInfoType, SignPrices)
	if not productTable then return end

	local function createProductButton(assetID, info)
		-- 🆕 CHECK IF BUTTON ALREADY EXISTS (MORE ROBUST)
		local existingBtn = SignPrices:FindFirstChild(tostring(assetID))
		if existingBtn then
			-- Update existing button instead of creating new one
			pcall(function()
				existingBtn.PurchaseButton.Text = "\u{E002}" .. formatAmount(info.PriceInRobux)
				existingBtn.LayoutOrder = info.PriceInRobux
			end)
			return
		end

		-- Create new button
		local success, newBtn = pcall(function()
			local btn = script.Template:Clone()
			btn.Size = defaultSize
			btn.Name = tostring(assetID)
			btn.PurchaseButton.Text = "\u{E002}" .. formatAmount(info.PriceInRobux)
			btn.LayoutOrder = info.PriceInRobux
			btn.ImportantValues.AssetId.Value = assetID
			btn.ImportantValues.AssetType.Value = enumInfoType == Enum.InfoType.GamePass and "Gamepass" or "Asset"
			return btn
		end)

		if success and newBtn then
			newBtn.Parent = SignPrices
		end
	end

	for assetID in pairs(productTable) do
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(assetID, enumInfoType)
		end)

		if success and info and info.IsForSale then
			createProductButton(assetID, info)
		end
	end
end

-- ✅ IMPROVED GetAssets (WITH CLEANUP!)
function AssetManager:GetAssets(Player, BoothUI)
	if not Player or not BoothUI then return end

	-- 🆕 CLEANUP OLD BUTTONS FIRST!
	cleanupBoothUI(BoothUI)

	-- Track this booth for cleanup
	activeBooths[Player.UserId] = BoothUI

	-- Get and set new products
	local Clothings, AssetType, Gamepasses = GetContent(Player, Player.UserId)

	SetProducts(Gamepasses, Enum.InfoType.GamePass, BoothUI)
	SetProducts(Clothings, Enum.InfoType.Asset, BoothUI)
end

-- 🆕 CLEANUP FUNCTION (CALL WHEN BOOTH CLOSES)
function AssetManager:CleanupBooth(Player)
	if not Player then return end

	local boothUI = activeBooths[Player.UserId]
	if boothUI then
		cleanupBoothUI(boothUI)
		activeBooths[Player.UserId] = nil
	end
end

-- 🆕 CLEANUP ALL BOOTHS (CALL ON SHUTDOWN)
function AssetManager:CleanupAll()
	for userId, boothUI in pairs(activeBooths) do
		cleanupBoothUI(boothUI)
	end
	activeBooths = {}
end

return AssetManager
