-- Modified by @jay_peaceee
-- DataManager (Wrapper for FishData)
-- This bridges the old fishing system API to the new FishData system
local DataManager = {}
local GameProfileService = require(game:GetService("ServerScriptService").Data.PetCore:WaitForChild("FishData"))
-- ===== FISH MANAGEMENT =====
function DataManager:AddFishWithLimit(player, fishData)
	local success, uniqueId = GameProfileService:AddFish(player, fishData)
	return success and uniqueId or false
end
function DataManager:AddExistingFish(player, fishEntry)
	-- Not needed anymore since we use AddFish directly
	local success, uniqueId = GameProfileService:AddFish(player, fishEntry)
	return success
end
function DataManager:RemoveFish(player, fishUniqueId)
	return GameProfileService:RemoveFish(player, fishUniqueId)
end
function DataManager:ToggleFavorite(player, fishUniqueId)
	return GameProfileService:ToggleFavoriteFish(player, fishUniqueId)
end
function DataManager:GetSavedFish(player)
	return GameProfileService:GetSavedFish(player)
end
function DataManager:GetFishCount(player)
	local fish = GameProfileService:GetSavedFish(player)
	return #fish
end
function DataManager:IsInventoryFull(player)
	-- Optional: Add inventory limit check here if needed
	-- For now, return false (unlimited)
	return false
end
-- ===== ROD MANAGEMENT =====
function DataManager:AddRod(player, rodName)
	return GameProfileService:AddRod(player, rodName)
end
function DataManager:HasRod(player, rodName)
	return GameProfileService:HasRod(player, rodName)
end
function DataManager:GetOwnedRods(player)
	return GameProfileService:GetOwnedRods(player)
end
function DataManager:SetLastEquippedRod(player, rodName)
	return GameProfileService:SetLastEquippedRod(player, rodName)
end
function DataManager:GetLastEquippedRod(player)
	return GameProfileService:GetLastEquippedRod(player)
end
-- ===== COINS (formerly "Cash") =====
function DataManager:AddCash(player, amount)
	return GameProfileService:AddCoins(player, amount)
end
function DataManager:RemoveCash(player, amount)
	local success, remaining = GameProfileService:TryPurchase(player, amount)
	return success
end
function DataManager:GetCash(player)
	return GameProfileService:GetCoins(player)
end
-- ===== LEVEL =====
function DataManager:GetLevel(player)
	return GameProfileService:GetLevel(player)
end
-- ===== PROFILE MANAGEMENT =====
function DataManager:LoadProfile(player)
	-- Profile is loaded automatically in FishData
	-- Just return a dummy profile object for compatibility
	local profile = GameProfileService:GetProfile(player)
	if profile then
		return {Data = profile.Data}
	end
	return nil
end
function DataManager:GetProfile(player)
	local profile = GameProfileService:GetProfile(player)
	if profile then
		return {Data = profile.Data}
	end
	return nil
end
function DataManager:EndProfile(player)
	-- Profile is managed by FishData, no need to end manually
	return true
end
-- ===== PRICE CALCULATION =====
function DataManager:CalculateFishPrice(weight, rarity)
	local FishingConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem"):WaitForChild("FishingConfig"))
	return FishingConfig.CalculateFishPrice(weight, rarity)
end
return DataManager