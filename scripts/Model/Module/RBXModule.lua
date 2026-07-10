-- RBXModule - Data konfigurasi Gamepass & DevProduct
local shopmodule = require(script.Parent:WaitForChild('ShopModule'))
local globalmodule = require(script.Parent:WaitForChild('GlobalFunction'))
local module = {}

module.Gamepasses = {
	UnlockAllCustomization = 1551747606,
	VIPPinoyPSHangout = 1551748001,
	Notes5 = 1551748002,
	EarnableGems = 1551748003,
	VIP_RUS = 1530393117
}

module.DevPGamepasses = {
	UnlockAllCustomization = 3477685970,
	VIPPinoyPSHangout = 3477685971,
	Notes5 = 3477685972,
	EarnableGems = 3477685973,
}

module.DevProducts = {
	Cash = {
		{
			Reward = 10000,
			ProductId = 3424566110,
			IconId = 14732298754,
		},
		{
			Reward = 20000,
			ProductId = 3424566110,
			IconId = 14732298754,
		},
		{
			Reward = 30000,
			ProductId = 3424566110,
			IconId = 14732298754,
		},
		{
			Reward = 40000,
			ProductId = 3424566110,
			IconId = 14732298754,
		},
		{
			Reward = 100000,
			ProductId = 3424566110,
			IconId = 14732298754,
		},
	},
	Donation = {
		{
			DonationValue = 5,
			ProductId = 3290844771,
		},
		{
			DonationValue = 10,
			ProductId = 3290844770
		},
		{
			DonationValue = 50,
			ProductId = 3290844769
		},
		{
			DonationValue = 100,
			ProductId = 3290844768
		},
		{
			DonationValue = 500,
			ProductId = 3290844767
		},
		{
			DonationValue = 1000,
			ProductId = 3290845151
		},
		{
			DonationValue = 5000,
			ProductId = 3290845150
		},
		{
			DonationValue = 10000,
			ProductId = 3290845149
		}
	},
	Gem = {
		{
			Reward = 100,
			ProductId = 3426790141,
			IconId = 2654418499
		},
		{
			Reward = 200,
			ProductId = 3426790140,
			IconId = 2654418499
		},
		{
			Reward = 300,
			ProductId = 3426790139,
			IconId = 2654418499
		},
		{
			Reward = 400,
			ProductId = 3426790137,
			IconId = 2654418499
		},
		{
			Reward = 500,
			ProductId = 3426790136,
			IconId = 2654418499
		},
		{
			Reward = 1000,
			ProductId = 3426790135,
			IconId = 2654418499
		},
	},
}

function module.GetGamepassName(id)
	for i, v in pairs(module.Gamepasses) do
		if v == id then
			return i
		end
	end
end

function module.GetPurchasedProductInfo(id)
	local typo = typeof(id) == 'string' and 'Key' or typeof(id) == 'number' and 'Value'
	if typo then
		for i, v in pairs(module.DevPGamepasses) do
			if (typo == 'Key' and i == id) or (typo == 'Value' and v == id) then
				return {'DevPGamepasses',i,v}
			end
		end
		for i, v in pairs(module.DevProducts) do
			for _, p in pairs(v) do
				if (typo == 'Key' and i == id) or (typo == 'Value' and p.ProductId == id) then
					return {i,p}
				end
			end
		end
	end
end

local devlistitem = {
	shopmodule.Items.RobuxItems,
	shopmodule.Items.GroupItems,
	shopmodule.Auras.RobuxAuras
}

for _, category in pairs(devlistitem) do
	for i, v in pairs(category) do
		local index = v.ToolName or v.ModelName
		if not v.PriceType then
			module.DevPGamepasses[index] = v.Id
		elseif v.PriceType == "robux" then
			module.DevPGamepasses[index] = v.ProductId
		end
	end
end

return module