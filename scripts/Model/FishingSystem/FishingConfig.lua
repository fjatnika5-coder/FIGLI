-- System by @thehandofvoid
-- Modified by @jay_peaceee
-- FishingConfig - CUSTOM (NO STAFF RODS / NO GAMEPASS LOGIC) + PER-ROD STATS (CUSTOM)

local FishingConfig = {}

local RunService = game:GetService("RunService")

-- ===================================================================
FishingConfig.DatabaseSettings = { enabled = true, warnOnDisabled = true }

-- ===================================================================
FishingConfig.CurrencySettings = {
	DisplayName = "Cash",
	PlayerDataFolderName = "PlayerData",
	PlayerDataCashName = "Cash",
	LeaderstatsFolderName = "leaderstats",
	LeaderstatsMoneyName = "Money",
	LegacyCoinsName = "Coins",
}

FishingConfig.LeaderboardSettings = {
	enabled = true,
	showCoins = true,
	CoinsName = "Cash",
	showCash = true,
	CashName = "Cash",
	showFishCaught = true,
	fishCaughtName = "FishCaught",
}

FishingConfig.InventoryLimitSettings = {
	enabled = true,
	maxFishInventory = 5000,
	fullInventoryMessage = "Your fish inventory is full! (5000/5000) Sell some fish first.",
	autoSellOldestFish = false
}

FishingConfig.AutoSellSettings = {
	enabled = true,
	triggerAt = 500,
	sellRarities = {
		Common = true,
		Uncommon = true,
		Rare = true,
		Epic = true,
		Legendary = false,
		Unknown = false
	},
	keepAmount = {
		Common = 0,
		Uncommon = 0,
		Rare = 0,
		Epic = 0,
		Legendary = 9999,
		Unknown = 9999
	},
	protectFavorites = true,
	notifyPlayer = true,
	notificationTitle = "Auto-Sell",
	notificationMessage = "Sold {count} fish for Rp{money}!\n{breakdown}",
	notificationDuration = 6,
	debugMode = false,
	logToConsole = false
}

FishingConfig.SellingSettings = {
	enabled = true,
	basePricePerKg = 46,
	rarityMultiplier = {
		Common = 1.0,
		Uncommon = 2.0,
		Rare = 3.0,
		Epic = 5.0,
		Legendary = 12.0,
		Unknown = 38.0
	},
	enableSizeBonus = true,
	sizeBonus = {
		small  = { min = 0,   max = 10,  multiplier = 0.7 },
		medium = { min = 10,  max = 50,  multiplier = 1.0 },
		large  = { min = 50,  max = 150, multiplier = 1.3 },
		huge   = { min = 150, max = 999, multiplier = 1.6 }
	}
}

FishingConfig.ProjectileSettings = {
	enabled = true,
	behindPlayerDistance = 5,
	landingHeightOffset = 1,
	flightTime = 0.8,
	rotationAngle = 45,
	landingSpeedThreshold = 5,
	landingVelocityY = 2,
	landingRayDistance = 5,
	landingGroundDistance = 3,
	detectionDelay = 0.5,
	fadeInDuration = 0.2,
	fadeOutDuration = 0.6,
	safetyTimeout = 3,
	randomLanding = false,
	randomBehindRange = { min = 4, max = 7 },
	randomSideRange = { min = -2, max = 2 },
	maxCastDistance = 35,
}

FishingConfig.MinigameSettings = {
	progressMin = 8, progressMax = 12,
	decayMin = 3, decayMax = 7,
	startingProgress = 0.4,
	fishingTime = 25,
	decayMultiplier = 25,
	clickFeedbackDuration = 0.15,

	rodTapCount = {
		["EvacoreRod"]    = 13,
		["PhantomRod"]    = 8,
		["LoveRod"]       = 15,
		["Rod Of The Eternal King"]  = 9,
		["RedShawdowRod"] = 11,
		["ButterflyRod"]  = 12,
		["FlutterRod"]    = 12,
		["BloodmoonRod"]    = 8,
		["AuraluxRod"]    = 6,
		["UmbraluxRod"]    = 6,
		["Crescendo Scythe"]   = 6,
		["CryoStromRod"]   = 11,
		["DreadspireRod"]  = 11,
		["FrostwindRod"]   = 11,
		["Aqua Rod"] = 9,
		["GundamAstraRod"] = 13,
		["x1x1x1 Hammer"] = 7,
		["GundamRod"]      = 13,
		["Fabulous Rod"]     = 8,
		["LightingRod"]      = 8,
		["DiamondRod"]     = 13,
		["Celestial Blossom Rod"]      = 7,
		["AdminRod"]      = 11,
		["OwnerRod"]      = 13,
		["FrozenkRod"]      = 13,
		["LavaRod"]      = 8,
		["FrozenRod"] = 8,
		["Slash Katana"]    = 6,
		["Royal Spider"]   = 8,
		["Cherryna"] = 6,
		["Esteh"]    = 6,
		["Jiyuu"]    = 6,
		["Jiyu"]    = 6,
		["Youkatta"]   = 6,
		["Nine"]   = 6,
		["Gulabatu"]   = 6,
		["Mei"]   = 6,
		["Soya"]   = 6,
		["Ceisya"]   = 6,
		["Solitario"]   = 6,
		["PASEP"]   = 6,
		["Princess Parasol"]   = 5,
		["Wings of Everlove"]   = 5,
		["Aether Monarch"]   = 5,
		["Blackhole Sword"]   = 5,
		["Eternal Flower"]   = 5,
		["The Vanquisher"]   = 5,
		["Little"]   = 5,
		["Aurelian Rod"]   = 5,
		["Miyuki"]   = 5,
		["Cupid Harp"]   = 5,
		["Dark Matter Scythe"]   = 5,
		["The Vanquisher"]   = 5,
		["Eternal Flower"]   = 5,
		["Blackhole Sword"]   = 5,

		default = 15
	},
	autoModeExtraTaps = 2
}

FishingConfig.TransferSettings = { Enabled = true, RequiredLevel = 1, MaxDistance = 15 }

-- ===================================================================
-- ROD STATS
-- ===================================================================
FishingConfig.GlobalMaxWeight = 1600

local SAME_BEAM_COLOR  = Color3.fromRGB(106, 106, 106)
local SAME_BEAM_WIDTH  = 0.05
local SAME_HOOK        = "BasicHook"
local SAME_ROD_RARITY  = "Epic"

local function RodCfg(baseLuck, maxWeight, maxRarity)
	return {
		hookName  = SAME_HOOK,
		beamColor = SAME_BEAM_COLOR,
		beamWidth = SAME_BEAM_WIDTH,
		baseLuck  = baseLuck or 1.0,
		maxWeight = maxWeight or 400.0,
		maxRarity = maxRarity or "Unknown",
		rodRarity = SAME_ROD_RARITY,
	}
end

FishingConfig.RodConfig = {
	default = RodCfg(1.0, 400.0, "Unknown"),

	["LoveRod"]      = RodCfg(1.0, 100.0, "Legendary"),
	["ButterflyRod"] = RodCfg(1.5, 140.0, "Legendary"),
	["FlutterRod"]   = RodCfg(1.5, 140.0, "Legendary"),
	["PhantomRod"]   = RodCfg(2.4, 400.0, "Unknown"),

	["CryoStromRod"]  = RodCfg(1.7, 350.0, "Unknown"),
	["BloodmoonRod"]  = RodCfg(14.9, 950.0, "Unknown"),
	["DreadspireRod"] = RodCfg(1.7, 350.0, "Unknown"),
	["DreadSpearRod"] = RodCfg(1.7, 350.0, "Unknown"),
	["FrostwindRod"]  = RodCfg(1.7, 350.0, "Unknown"),
	["LightingRod"] = RodCfg(6.7, 750.0, "Unknown"),
	["Fabulous Rod"]  = RodCfg(5.7, 570.0, "Unknown"),
	["Kyouyariin"]  = RodCfg(95.0, 1200.0, "Unknown"),

	["EvacoreRod"] = RodCfg(2.0, 300.0, "Unknown"),

	["DiamondRod"]     = RodCfg(1.8, 250.0, "Unknown"),
	["Aqua Rod"]     = RodCfg(40.0, 1100.0, "Unknown"),
	["RedShadowRod"]   = RodCfg(1.8, 250.0, "Unknown"),
	["RedShawdowRod"]  = RodCfg(1.8, 250.0, "Unknown"),
	["GundamAstraRod"] = RodCfg(1.8, 250.0, "Unknown"),
	["GundamRod"]      = RodCfg(1.8, 250.0, "Unknown"),
	["AdminRod"]       = RodCfg(7.9, 750.0, "Unknown"),
	["Celestial Blossom Rod"]       = RodCfg(45.9, 1100.0, "Unknown"),
	["LavaRod"]      = RodCfg(2.9, 500.0, "Unknown"),
	["FrozenRod"] = RodCfg(2.8, 500.0, "Unknown"),
	["Rod Of The Eternal King"]    = RodCfg(5.7, 570.0, "Unknown"),
	["Esteh"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Royal Spider"]   = RodCfg(2.8, 500.0, "Unknown"),
	["OwnerRod"]       = RodCfg(55.0, 1600.0, "Unknown"),
	["Slash Katana"]       = RodCfg(35.0, 1000.0, "Unknown"),
	["AuraluxRod"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Cherryna"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Jiyuu"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Youkatta"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Nine"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Gulabatu"]       = RodCfg(100.0, 1200.0, "Unknown"),
	["Mei"]       = RodCfg(100.0, 1200.0, "Unknown"),
	["Vin"]       = RodCfg(100.0, 1200.0, "Unknown"),
	["Jiyu"]       = RodCfg(100.0, 1200.0, "Unknown"),
	["Miyuki"]       = RodCfg(100.0, 1200.0, "Unknown"),
	["Little"]       = RodCfg(100.0, 1200.0, "Unknown"),
	["AscensionRod"]       = RodCfg(80.0, 1000.0, "Unknown"),
	["OblivonRod"]       = RodCfg(80.0, 1000.0, "Unknown"),
	["FrozenkRod"]       = RodCfg(80.0, 1000.0, "Unknown"),
	["x1x1x1 Hammer"]       = RodCfg(250.0, 1500.0, "Unknown"),
	["Princess Parasol"]       = RodCfg(80.0, 1000.0, "Unknown"),
	["UmbraluxRod"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Wings of Everlove"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Aether Monarch"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Aurelian Rod"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Cupid Harp"]       = RodCfg(210.0, 1450.0, "Unknown"),
	["Soya"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Solitario"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["PASEP"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Ceisya"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Dark Matter Scythe"]       = RodCfg(95.0, 1200.0, "Unknown"),
	["Eternal Flower"]       = RodCfg(195.0, 1400.0, "Unknown"),
	["The Vanquisher"]       = RodCfg(195.0, 1400.0, "Unknown"),
	["Blackhole Sword"]       = RodCfg(195.0, 1400.0, "Unknown"),
	["Crescendo Scythe"]       = RodCfg(155.0, 1200.0, "Unknown")
}

FishingConfig.Pity = {
	Rare      = { maxPity = 400,   baseBoost = 0.06,  maxMultiplier = 1.15 },
	Epic      = { maxPity = 1200,  baseBoost = 0.04,  maxMultiplier = 1.12 },
	Legendary = { maxPity = 25000, baseBoost = 0.015, maxMultiplier = 1.05 },
	Unknown   = { maxPity = 75000, baseBoost = 0.008, maxMultiplier = 1.03 }
}

FishingConfig.RarityWeights = {
	Common    = 45.0,
	Uncommon  = 33.0,
	Rare      = 18.0,
	Epic      = 3.8,
	Legendary = 0.18,
	Unknown   = 0.02
}

-- ===================================================================
-- FISH TABLE
-- ===================================================================
FishingConfig.FishTable = {
	-- COMMON (1-15)
	{ name = "Fangtooth",      probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "Goliath Tiger",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "Hermit Crab",    probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "Lion Fish",      probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "Luminous Fish",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },

	{ name = "TropicalFish1",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish2",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish3",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish4",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish5",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish6",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish8",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish9",  probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish10", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish11", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish12", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish13", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish14", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish15", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },
	{ name = "TropicalFish16", probability = 1, minKg = 1,  maxKg = 15,  rarity = "Common" },

	-- UNCOMMON (1-20)
	{ name = "UncommonFish1", probability = 1, minKg = 1, maxKg = 20, rarity = "Uncommon" },
	{ name = "UncommonFish3", probability = 1, minKg = 1, maxKg = 20, rarity = "Uncommon" },
	{ name = "UncommonFish4", probability = 1, minKg = 1, maxKg = 20, rarity = "Uncommon" },
	{ name = "UncommonFish5", probability = 1, minKg = 1, maxKg = 20, rarity = "Uncommon" },
	{ name = "UncommonFish6", probability = 1, minKg = 1, maxKg = 20, rarity = "Uncommon" },

	-- RARE (25-40)
	{ name = "RareFish1", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish2", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish3", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish4", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish5", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish6", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish7", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },
	{ name = "RareFish8", probability = 1, minKg = 25, maxKg = 40, rarity = "Rare" },

	-- EPIC (25-45)
	{ name = "Blackcap Basslet", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "Boar Fish",        probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "Loving Shark",     probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },

	{ name = "ChristmasFish1", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish2", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish3", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish4", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish5", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish6", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish7", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "ChristmasFish8", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },

	{ name = "Cumi",      probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },
	{ name = "Jellyfish", probability = 1, minKg = 25, maxKg = 45, rarity = "Epic" },

	-- LEGENDARY (80-1000)
	{ name = "CrashFish",      probability = 1, minKg = 80, maxKg = 1000, rarity = "Legendary" },
	{ name = "CrocodileFish",  probability = 1, minKg = 80, maxKg = 1000, rarity = "Legendary" },
	{ name = "JellyKingFish",  probability = 1, minKg = 80, maxKg = 1000, rarity = "Legendary" },
	{ name = "MythcyFish",     probability = 1, minKg = 80, maxKg = 1000, rarity = "Legendary" },
	{ name = "PlasmaFish",     probability = 1, minKg = 80, maxKg = 1000, rarity = "Legendary" },
	{ name = "Zombie Shark",  probability = 1, minKg = 80, maxKg = 1000, rarity = "Legendary" },
	{ name = "Walrus Bride",    probability = 1, minKg = 300, maxKg = 1200, rarity = "Legendary" },

	-- UNKNOWN (200-1600)
	{ name = "BigLocnessAlbino",    probability = 1, minKg = 200, maxKg = 1200, rarity = "Unknown" },
	{ name = "LocnessFish",    probability = 1, minKg = 200, maxKg = 1200, rarity = "Unknown" },
	{ name = "MegaLodonFish",  probability = 1, minKg = 200, maxKg = 1200, rarity = "Unknown" },
	{ name = "Bloodmoon Whale",  probability = 1, minKg = 500, maxKg = 1200, rarity = "Unknown" },
	{ name = "Ancient Whale",  probability = 1, minKg = 200, maxKg = 1200, rarity = "Unknown" },
	{ name = "Bone Whale Pink",  probability = 1, minKg = 400, maxKg = 1200, rarity = "Unknown" },
	{ name = "Gran Maja",  probability = 1, minKg = 200, maxKg = 1200, rarity = "Unknown" },
	{ name = "Glaciers Serpent",  probability = 0.2, minKg = 500, maxKg = 1200, rarity = "Unknown" },
	{ name = "Crystal Kraken",  probability = 0.2, minKg = 500, maxKg = 1200, rarity = "Unknown" },
	{ name = "Beruang Laut",    probability = 1, minKg = 200, maxKg = 1200, rarity = "Unknown" },
	{ name = "Celestfin",  probability = 0.2, minKg = 650, maxKg = 1200, rarity = "Unknown" },
	{ name = "Rosefin",    probability = 0.2, minKg = 650, maxKg = 1200, rarity = "Unknown" },
	{ name = "Ancient Magma Whale",  probability = 0.02, minKg = 1000, maxKg = 1400, rarity = "Unknown" },
	{ name = "Leviathan",    probability = 0.02, minKg = 1000, maxKg = 1600, rarity = "Unknown" },
	{ name = "Love Nessie",  probability = 0.02, minKg = 1000, maxKg = 1500, rarity = "Unknown" },
	{ name = "Bajak Laut Megalodon",    probability = 0.02, minKg = 1000, maxKg = 1200, rarity = "Unknown" },
}

FishingConfig.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(30, 255, 30),
	Rare = Color3.fromRGB(30, 100, 255),
	Epic = Color3.fromRGB(160, 30, 255),
	Legendary = Color3.fromRGB(255, 128, 0),
	Unknown = Color3.fromRGB(190, 0, 3)
}

FishingConfig.rarityOrder = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Unknown = 6
}

FishingConfig.RoleSettings = {
	Enabled = false,
	GroupID = 0,
	RoleRodMapping = {}
}

FishingConfig.GamepassEffects = { enabled = false }

-- ===================================================================
-- OWNERROD GUARANTEED FISH SYSTEM
-- Tiap 5 cast pasti dapet 1 dari 4 ikan spesial
-- ===================================================================

local OWNER_ROD_GUARANTEED_FISH = {
	"Leviathan",
	"Love Nessie",
	"Ancient Magma Whale",
	"Bajak Laut Megalodon",
}

local OWNER_ROD_GUARANTEE_EVERY = 5

-- Track per player: { [userId] = castCount }
local ownerRodCastCount = {}

-- Cleanup kalau player leave
if RunService:IsServer() then
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		ownerRodCastCount[p.UserId] = nil
	end)
end

local function getGuaranteedOwnerFish()
	local fishName = OWNER_ROD_GUARANTEED_FISH[math.random(1, #OWNER_ROD_GUARANTEED_FISH)]

	for _, fish in ipairs(FishingConfig.FishTable) do
		if fish.name == fishName then
			return fish
		end
	end

	return nil
end

-- ===================================================================
-- CURRENCY HELPERS
-- ===================================================================
local function getValueObj(player, folderName, valueName)
	if not player then return nil end
	local folder = player:FindFirstChild(folderName)
	if not folder then return nil end
	local v = folder:FindFirstChild(valueName)
	if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
		return v
	end
	return nil
end

function FishingConfig.GetCashValue(player)
	local cs = FishingConfig.CurrencySettings
	local v = getValueObj(player, cs.PlayerDataFolderName, cs.PlayerDataCashName)
	if v then return v.Value end
	local m = getValueObj(player, cs.LeaderstatsFolderName, cs.LeaderstatsMoneyName)
	if m then return m.Value end
	return 0
end

function FishingConfig.AddCash(player, amount)
	if not RunService:IsServer() then return false end
	local n = math.floor(tonumber(amount) or 0)
	if n == 0 then return true end

	local cs = FishingConfig.CurrencySettings
	local v = getValueObj(player, cs.PlayerDataFolderName, cs.PlayerDataCashName)
	if v then v.Value = v.Value + n; return true end

	local m = getValueObj(player, cs.LeaderstatsFolderName, cs.LeaderstatsMoneyName)
	if m then m.Value = m.Value + n; return true end

	return false
end

function FishingConfig.SpendCash(player, amount)
	if not RunService:IsServer() then return false end
	local n = math.floor(tonumber(amount) or 0)
	if n <= 0 then return true end

	local cur = FishingConfig.GetCashValue(player)
	if cur < n then return false end

	local cs = FishingConfig.CurrencySettings
	local v = getValueObj(player, cs.PlayerDataFolderName, cs.PlayerDataCashName)
	if v then v.Value = v.Value - n; return true end

	local m = getValueObj(player, cs.LeaderstatsFolderName, cs.LeaderstatsMoneyName)
	if m then m.Value = m.Value - n; return true end

	return false
end

function FishingConfig.GetCoinsValue(player) return FishingConfig.GetCashValue(player) end
function FishingConfig.AddCoins(player, amount) return FishingConfig.AddCash(player, amount) end
function FishingConfig.SpendCoins(player, amount) return FishingConfig.SpendCash(player, amount) end

function FishingConfig.GetCurrencyDisplayName()
	return FishingConfig.CurrencySettings.DisplayName or "Cash"
end

function FishingConfig.GetMaxCastDistance()
	return tonumber(FishingConfig.ProjectileSettings.maxCastDistance) or 35
end

-- ===================================================================
-- FUNCTIONS
-- ===================================================================
function FishingConfig.CreatePityTracker()
	return { Rare = 0, Epic = 0, Legendary = 0, Unknown = 0 }
end

function FishingConfig.GetRarityWithPity(pityData, rodName, luckBonus)
	local base = FishingConfig.RarityWeights
	local rodConfig = FishingConfig.GetRodConfig(rodName)
	local maxRarity = rodConfig.maxRarity or "Unknown"
	local maxRarityLevel = FishingConfig.rarityOrder[maxRarity] or 6

	luckBonus = luckBonus or rodConfig.baseLuck or 1.0
	local final = {}

	for rarity, weight in pairs(base) do
		local rarityLevel = FishingConfig.rarityOrder[rarity] or 1
		local rarityMultiplier = (rarityLevel - 1) / 5

		local luckEffect
		if luckBonus <= 5 then
			luckEffect = 1 + ((luckBonus - 1) * rarityMultiplier * 5)
		else
			local scaledLuck = math.sqrt(luckBonus)
			luckEffect = 1 + ((scaledLuck - 1) * rarityMultiplier * 15)
		end

		final[rarity] = weight * luckEffect
	end

	for rarity, level in pairs(FishingConfig.rarityOrder) do
		if level > maxRarityLevel then
			final[rarity] = 0
		end
	end

	if rodName == "OwnerRod" then
		for rarity, _ in pairs(final) do
			if rarity ~= "Legendary" and rarity ~= "Unknown" then
				final[rarity] = 0
			end
		end
	end

	for rarity, cfg in pairs(FishingConfig.Pity) do
		local rarityLevel = FishingConfig.rarityOrder[rarity] or 1
		if rarityLevel <= maxRarityLevel and final[rarity] and final[rarity] > 0 then
			local count = pityData[rarity] or 0
			local progress = math.clamp(count / cfg.maxPity, 0, 1)
			local boost = cfg.baseBoost * progress
			local boostedWeight = final[rarity] * (1 + boost)
			final[rarity] = math.min(boostedWeight, final[rarity] * cfg.maxMultiplier)
		end
	end

	local total = 0
	for _, w in pairs(final) do total = total + w end
	if total == 0 then return "Common" end

	local roll = math.random() * total
	for rarity, w in pairs(final) do
		if roll < w then return rarity end
		roll = roll - w
	end
	return "Common"
end

function FishingConfig.PickFishFromRarity(rarity)
	local list = {}
	for _, fish in ipairs(FishingConfig.FishTable) do
		if fish.rarity == rarity then table.insert(list, fish) end
	end
	if #list == 0 then
		for _, fish in ipairs(FishingConfig.FishTable) do
			if fish.rarity == "Common" then table.insert(list, fish) end
		end
	end
	if #list == 0 then return nil end

	local totalProb = 0
	for _, f in ipairs(list) do totalProb = totalProb + f.probability end
	local roll = math.random() * totalProb
	for _, f in ipairs(list) do
		if roll < f.probability then return f end
		roll = roll - f.probability
	end
	return list[1]
end

function FishingConfig.RollFish(pityData, rodName, luckBonus, player)
	pityData = pityData or FishingConfig.CreatePityTracker()

	-- OwnerRod guaranteed system: tiap 5 cast pasti dapet ikan spesial
	if rodName == "OwnerRod" and player then
		local uid = player.UserId
		ownerRodCastCount[uid] = (ownerRodCastCount[uid] or 0) + 1

		if ownerRodCastCount[uid] >= OWNER_ROD_GUARANTEE_EVERY then
			ownerRodCastCount[uid] = 0

			local guaranteedFish = getGuaranteedOwnerFish()
			if guaranteedFish then
				-- Reset pity untuk Unknown karena dapet Unknown
				if pityData.Unknown then pityData.Unknown = 0 end
				if pityData.Legendary then pityData.Legendary = 0 end
				return guaranteedFish
			end
		end
	end

	-- Normal roll
	for rarity in pairs(pityData) do pityData[rarity] = pityData[rarity] + 1 end

	local rarity = FishingConfig.GetRarityWithPity(pityData, rodName, luckBonus)

	local rarityLevel = FishingConfig.rarityOrder[rarity] or 1
	for r, level in pairs(FishingConfig.rarityOrder) do
		if level >= rarityLevel and pityData[r] then pityData[r] = 0 end
	end

	return FishingConfig.PickFishFromRarity(rarity)
end

function FishingConfig.GetRodConfig(rodName)
	return FishingConfig.RodConfig[rodName] or FishingConfig.RodConfig.default
end

function FishingConfig.GetRarityColor(rarity)
	return FishingConfig.RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
end

function FishingConfig.CalculateTotalLuck(baseLuck, powerPercent)
	local repStorage = game:GetService("ReplicatedStorage")
	local luckValObj = repStorage:WaitForChild("FishingSystem"):FindFirstChild("GlobalLuckMultiplier")
	local serverMultiplier = luckValObj and luckValObj.Value or 1.0

	local powerBonus = baseLuck * (powerPercent * 0.2)
	local rodLuck = baseLuck + powerBonus
	local total = rodLuck * serverMultiplier

	return total, baseLuck, powerBonus
end

function FishingConfig.CanCatchRarity(rodName, fishRarity)
	local rodConfig = FishingConfig.GetRodConfig(rodName)
	local maxRarity = rodConfig.maxRarity or "Unknown"
	local rodMaxLevel = FishingConfig.rarityOrder[maxRarity] or 6
	local fishLevel = FishingConfig.rarityOrder[fishRarity] or 1
	return fishLevel <= rodMaxLevel
end

function FishingConfig.GenerateFishWeight(fish, totalLuck, maxRodWeight)
	local minKg = math.max(1.0, fish.minKg or 1.0)

	local globalCap = tonumber(FishingConfig.GlobalMaxWeight) or 1600.0
	local rodCap = tonumber(maxRodWeight) or globalCap
	local maxKg = math.min(fish.maxKg or globalCap, rodCap, globalCap)
	if maxKg < minKg then maxKg = minKg end

	local luckFactor = math.clamp((totalLuck or 1.0) / 10.0, 0, 1)
	local randomFactor = math.random()
	local biasedRandom = randomFactor * (1 - luckFactor * 0.3) + (luckFactor * 0.3)

	local w = minKg + (biasedRandom * (maxKg - minKg))
	w = math.clamp(w, 1.0, globalCap)
	return math.floor(w * 10 + 0.5) / 10
end

function FishingConfig.CalculateFishPrice(weight, rarity)
	local basePricePerKg = FishingConfig.SellingSettings.basePricePerKg
	local rarityMult = FishingConfig.SellingSettings.rarityMultiplier[rarity] or 1.0
	local basePrice = weight * basePricePerKg * rarityMult
	local finalPrice = basePrice

	if FishingConfig.SellingSettings.enableSizeBonus then
		for _, bonusData in pairs(FishingConfig.SellingSettings.sizeBonus) do
			if weight >= bonusData.min and weight < bonusData.max then
				finalPrice = basePrice * bonusData.multiplier
				break
			end
		end
	end
	return math.floor(finalPrice + 0.5)
end

function FishingConfig.HasGamepassEffects(_rodName) return false end
function FishingConfig.GetGamepassEffects(_rodName) return nil end

function FishingConfig.GetRequiredTaps(rodName, isAutoMode)
	local settings = FishingConfig.MinigameSettings
	local baseTaps = settings.rodTapCount[rodName] or settings.rodTapCount.default
	if isAutoMode then return baseTaps + settings.autoModeExtraTaps end
	return baseTaps
end

function FishingConfig.GetFishDataByName(fishName)
	for _, fish in ipairs(FishingConfig.FishTable) do
		if fish.name == fishName then
			return fish
		end
	end
	return nil
end

-- ===================================================================
-- UPGRADE SYSTEM PATCH
-- ===================================================================

function FishingConfig.GetUpgradedRodConfig(rodName, player)
	local baseConfig = FishingConfig.RodConfig[rodName] or FishingConfig.RodConfig.default

	if not player or not _G.GetUpgradedRodStats then
		return baseConfig
	end

	local upgradedStats, level = _G.GetUpgradedRodStats(player, rodName)

	if not upgradedStats or level <= 1 then
		return baseConfig
	end

	return {
		hookName = baseConfig.hookName,
		beamColor = baseConfig.beamColor,
		beamWidth = baseConfig.beamWidth,
		baseLuck = upgradedStats.Luck,
		maxWeight = upgradedStats.MaxWeight,
		maxRarity = upgradedStats.MaxRarity or baseConfig.maxRarity,
		rodRarity = baseConfig.rodRarity,
		_baseConfig = baseConfig,
		_upgradeLevel = level,
	}
end

function FishingConfig.GetUpgradedTapCount(rodName, player, isAutoMode)
	local settings = FishingConfig.MinigameSettings
	local baseTaps = settings.rodTapCount[rodName] or settings.rodTapCount.default

	local level = 1
	if player and _G.GetRodUpgradeLevel then
		level = _G.GetRodUpgradeLevel(player, rodName) or 1
	end

	local upgradedTaps = math.max(3, baseTaps - (level - 1))

	if isAutoMode then
		return upgradedTaps + settings.autoModeExtraTaps
	end

	return upgradedTaps
end

function FishingConfig.CalculateTotalLuckWithUpgrade(baseLuck, powerPercent, player, rodName)
	local repStorage = game:GetService("ReplicatedStorage")
	local luckValObj = repStorage:WaitForChild("FishingSystem"):FindFirstChild("GlobalLuckMultiplier")
	local serverMultiplier = luckValObj and luckValObj.Value or 1.0

	local finalBaseLuck = baseLuck
	if player and _G.GetUpgradedRodStats and rodName then
		local upgradedStats = _G.GetUpgradedRodStats(player, rodName)
		if upgradedStats and upgradedStats.Luck then
			finalBaseLuck = upgradedStats.Luck
		end
	end

	local powerBonus = finalBaseLuck * (powerPercent * 0.2)
	local rodLuck = finalBaseLuck + powerBonus
	local total = rodLuck * serverMultiplier

	return total, finalBaseLuck, powerBonus
end

return FishingConfig