-- JualIkanServer
-- Location: ServerScriptService/JualIkanServer (Script)
--
-- AUDIT FIX:
-- [FIX L] Payment now goes through FishData:AddCoins (CurrencyAdapter →
--         PlayerData.Cash). The old version wrote leaderstats.Money directly,
--         which was a third parallel money path relying on the bidirectional
--         sync bridges. One authoritative path now.
-- [FIX M] Sell-All yields every 25 fish so selling thousands of fish cannot
--         freeze one server frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SellRemote = ReplicatedStorage:WaitForChild("JualIkanRemote")

-- Optional: refresh UI fish inventory (kalau ada)
local FishInventoryFolder = ReplicatedStorage:FindFirstChild("FishInventory")
local FishRefreshEvent = FishInventoryFolder and FishInventoryFolder:FindFirstChild("Core")

local FishingConfig = require(ReplicatedStorage:WaitForChild("FishingSystem"):WaitForChild("FishingConfig"))
local FishData = require(ServerScriptService.Data.PetCore:WaitForChild("FishData"))

local processing = {}

-- =========================================================
-- Helpers
-- =========================================================
local function refreshFishUI(player)
	if FishRefreshEvent and FishRefreshEvent:IsA("RemoteEvent") then
		FishRefreshEvent:FireClient(player)
	end
end

local function getFishIdFromTool(tool)
	if not tool or not tool:IsA("Tool") then return nil end

	local v = tool:FindFirstChild("FishId")
	if v and v:IsA("StringValue") and v.Value ~= "" then
		return v.Value
	end

	local a = tool:GetAttribute("FishId")
	if typeof(a) == "string" and a ~= "" then
		return a
	end

	return nil
end

local function destroyFishToolById(container, fishId)
	if not container or not fishId then return end
	for _, t in ipairs(container:GetChildren()) do
		if t:IsA("Tool") then
			local id = getFishIdFromTool(t)
			if id == fishId then
				t:Destroy()
			end
		end
	end
end

local function destroyFishEverywhere(player, fishId)
	if not player or not fishId then return end
	destroyFishToolById(player:FindFirstChild("Backpack"), fishId)
	destroyFishToolById(player.Character, fishId)
	destroyFishToolById(player:FindFirstChild("StarterGear"), fishId)
end

local function findFishInSavedList(savedFish, fishId)
	for _, f in ipairs(savedFish) do
		if tostring(f.uniqueId) == tostring(fishId) then
			return f
		end
	end
	return nil
end

-- =========================================================
-- MAIN
-- =========================================================
SellRemote.OnServerEvent:Connect(function(player, option)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	if processing[player.UserId] then return end
	processing[player.UserId] = true

	local ok, err = pcall(function()
		local savedFish = FishData:GetSavedFish(player) or {}

		-- =========================
		-- SELL HAND
		-- =========================
		if option == "Hand" then
			local char = player.Character
			local tool = char and char:FindFirstChildOfClass("Tool")
			if not tool then
				SellRemote:FireClient(player, "Info", "Kamu tidak memegang ikan.")
				return
			end

			local fishId = getFishIdFromTool(tool)
			if not fishId then
				SellRemote:FireClient(player, "Info", "Tool ini bukan ikan yang bisa dijual.")
				return
			end

			local f = findFishInSavedList(savedFish, fishId)
			if not f then
				SellRemote:FireClient(player, "Info", "Data ikan tidak ditemukan (mungkin sudah kejual / desync).")
				return
			end

			if f.isFavorited == true then
				SellRemote:FireClient(player, "Info", "Ikan favorit tidak bisa dijual. Unfavorite dulu.")
				return
			end

			local removedOk = select(1, FishData:RemoveFish(player, fishId))
			if not removedOk then
				SellRemote:FireClient(player, "Info", "Gagal jual (server). Coba lagi.")
				return
			end

			local price = FishingConfig.CalculateFishPrice(tonumber(f.weight) or 0, tostring(f.rarity or "Common"))
			if price > 0 then
				FishData:AddCoins(player, price)
			end

			destroyFishEverywhere(player, fishId)

			SellRemote:FireClient(player, "TerimaKasih", price)
			refreshFishUI(player)
			return
		end

		-- =========================
		-- SELL ALL (EXCEPT FAVORITES)
		-- =========================
		if option == "All" then
			if #savedFish == 0 then
				SellRemote:FireClient(player, "Info", "Ikan kamu kosong.")
				return
			end

			local total = 0
			local soldAny = false

			for index, f in ipairs(savedFish) do
				if not player.Parent then return end

				if f and f.uniqueId and f.isFavorited ~= true then
					local fishId = tostring(f.uniqueId)

					local removedOk = select(1, FishData:RemoveFish(player, fishId))
					if removedOk then
						soldAny = true
						total += FishingConfig.CalculateFishPrice(tonumber(f.weight) or 0, tostring(f.rarity or "Common"))
						destroyFishEverywhere(player, fishId)
					end
				end

				if index % 25 == 0 then task.wait() end
			end

			if not soldAny then
				SellRemote:FireClient(player, "Info", "Semua ikan kamu favorit. Tidak ada yang dijual.")
				return
			end

			if total > 0 and player.Parent then
				FishData:AddCoins(player, total)
			end

			SellRemote:FireClient(player, "TerimaKasih", total)
			refreshFishUI(player)
			return
		end
	end)

	processing[player.UserId] = nil

	if not ok then
		warn("[JualIkanServer] Sell error:", err)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	processing[player.UserId] = nil
end)
