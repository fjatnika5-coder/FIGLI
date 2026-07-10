local PlayerAssets = {}

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

-- URLs
local TShirtUrl = "https://catalog.rotunnel.com/v1/search/items/details?Category=3&CreatorName="
local ClothingUrlBase = "https://catalog.rotunnel.com/v1/search/items/details?Category=3&CreatorType=%22User%22&IncludeNotForSale=false&Limit=30&CreatorTargetId="
local GamepassesUrlBase = "https://apis.rotunnel.com/game-passes/v1/universes/"

-- Storage
PlayerAssets.Gamepasses = {}
PlayerAssets.Clothing = {}

--------------------------------------------------------------------------------------------------------
-- Fetch T-Shirts (updated)
local function getUserGeneratedTShirts(username, SignPrices)
	local tshirts = {}
	local success, result = pcall(function()
		return HttpService:GetAsync(TShirtUrl .. username)
	end)

	if success then
		local decoded = HttpService:JSONDecode(result)
		local data = decoded.data
		if data then
			table.sort(data, function(a,b) return a.price < b.price end)
			for _, item in ipairs(data) do
				table.insert(tshirts, item.id)
				local newBtn = script.Template:Clone()
				newBtn.PurchaseButton.Text = "💵"..item.price
				newBtn.LayoutOrder = item.price
				newBtn.Name = item.price
				newBtn.ImportantValues.AssetId.Value = item.id
				newBtn.Parent = SignPrices
			end
		end
	end
	return tshirts
end

--------------------------------------------------------------------------------------------------------
-- Fetch Clothing (updated)
local function GetClothings(userId)
	local link = ClothingUrlBase .. userId
	local success, result = pcall(function()
		return HttpService:GetAsync(link, true)
	end)

	if not success and result == "HTTP 429 (Too Many Requests)" then
		wait(1)
		success, result = pcall(function()
			return HttpService:GetAsync(link,true)
		end)
	end

	if success then
		local decoded = HttpService:JSONDecode(result)
		local forReturn = {}
		local assetType = {}
		for _, item in pairs(decoded.data or {}) do
			table.insert(forReturn, item.id)
			table.insert(assetType, item.assetType)
		end
		if #forReturn > 0 then
			return forReturn, assetType
		end
	end
	return nil
end

--------------------------------------------------------------------------------------------------------

local function GetUserUniverses(userId)
	local universes = {}
	local page = 1
	local pageSize = 50

	while true do
		local url = string.format("https://games.rotunnel.com/v2/users/%d/games?accessFilter=Public&sortOrder=Asc&limit=%d&page=%d", 
			userId, pageSize, page)
		local success, result = pcall(function()
			return HttpService:GetAsync(url)
		end)
		if not success then
			warn("Failed to fetch user games: "..tostring(result))
			break
		end

		local data = HttpService:JSONDecode(result)
		if not (data and data.data) then
			break
		end
		for _, gameInfo in ipairs(data.data) do
			table.insert(universes, gameInfo.id)
		end

		if #data.data < pageSize then
			break -- No more pages
		else
			page = page + 1
		end
	end

	return universes
end


-- Fetch Gamepasses (using new API)
local function GetGamepassesFromUser(userId)
	local gamepasses = {}
	local universes = GetUserUniverses(userId)
	for _, universeId in ipairs(universes) do
		local passes = {}
		local pageToken = ""
		repeat
			local url = string.format("https://apis.rotunnel.com/game-passes/v1/universes/%d/game-passes?passView=Full&pageSize=100&pageToken=%s", 
				universeId, pageToken)
			local success, result = pcall(function()
				return HttpService:GetAsync(url)
			end)
			if success then
				local decoded = HttpService:JSONDecode(result)
				for _, pass in ipairs(decoded.gamePasses or {}) do
					table.insert(gamepasses, pass.id)
				end
				pageToken = decoded.nextPageToken or ""
			else
				warn("Failed to fetch gamepasses for universe "..universeId..": "..tostring(result))
				break
			end
		until pageToken == ""
	end
	return gamepasses
end

--------------------------------------------------------------------------------------------------------
-- Fetch Player Content
local function GetContent(player, userId)
	local clothings, assetType = GetClothings(userId)
	local gamepasses = GetGamepassesFromUser(userId)
	return clothings, assetType, gamepasses
end

--------------------------------------------------------------------------------------------------------
-- Set Products in player TipJar/Donation Jar UI (This depends on what tipjar you use)
local function SetProducts(productTable, enumInfoType, SignPrices)
	if productTable then
		for _, assetID in pairs(productTable) do
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetID, enumInfoType)
			if ok and info and info.IsForSale then
				local newBtn = script.Template:Clone()
				local price = info.PriceInRobux
				newBtn.Name = price
				newBtn.PurchaseButton.Text = "💵"..price
				newBtn.GamepassImage.Image = "rbxassetid://"..info.IconImageAssetId
				newBtn.LayoutOrder = price
				newBtn.ImportantValues.AssetId.Value = assetID
				newBtn.ImportantValues.AssetType.Value = "Gamepass"
				PlayerAssets.Gamepasses[assetID] = info
				newBtn.Parent = SignPrices
			end
		end
	end
end

--------------------------------------------------------------------------------------------------------
-- Public API Function
function PlayerAssets:GetAssets(Player, BoothUI)
	-- Get content
	local clothings, assetType, gamepasses = GetContent(Player, Player.UserId)

	-- Set products in UI
	SetProducts(gamepasses, Enum.InfoType.GamePass, BoothUI)
	SetProducts(clothings, Enum.InfoType.Asset, BoothUI)
end

return PlayerAssets
