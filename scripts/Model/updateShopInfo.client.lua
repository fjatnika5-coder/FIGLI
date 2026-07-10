local isUpdatingShop = false
local SHOP_UPDATE_COOLDOWN = 1.0
local lastShopUpdate = 0

local function updateShopInfo()
	-- Guard: jangan spam InvokeServer
	if isUpdatingShop then return end
	local now = tick()
	if (now - lastShopUpdate) < SHOP_UPDATE_COOLDOWN then return end
	lastShopUpdate = now
	isUpdatingShop = true

	local success, data = pcall(function()
		return GetShopInfo:InvokeServer()
	end)

	isUpdatingShop = false

	if not success or not data then return end
	if typeof(data) ~= "table" then return end -- validasi tipe

	shopData = data

	-- Safe update UI dengan pcall supaya 1 element error nggak matiin semua
	pcall(function()
		moneyLabel.Text = "💰 Uang: " .. formatMoney(data.money)
	end)

	pcall(function()
		if data.isActive then
			currentLuckLabel.Text = string.format(
				"🍀 Server Luck: x%d (by %s)",
				data.currentLuck or 1,
				tostring(data.buyerName or "Someone")
			)
		else
			currentLuckLabel.Text = "🍀 Server Luck: x1 (Normal)"
		end
	end)

	pcall(function()
		if data.timeLeft and data.timeLeft > 0 then
			timeLeftLabel.Text = "⏰ Boost Berakhir: " .. formatTime(data.timeLeft)
			buyButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
			buyButton.Text = string.format("❌ SUDAH ADA BOOST (x%d)", data.currentLuck or 1)
		else
			timeLeftLabel.Text = "⏰ Tidak ada boost aktif"
			buyButton.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
			buyButton.Text = "✅ BELI LUCK BOOST (SERVER-WIDE)"
		end
	end)

	pcall(updatePrice)
end