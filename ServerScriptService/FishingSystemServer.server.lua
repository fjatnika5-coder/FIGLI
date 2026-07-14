-- FishingSystem Server (utama)
-- Location: ServerScriptService — ganti isi Script fishing server utama
-- (script yang berisi handler FishGiver / CastReplication / SellFish).
--
-- PERF AUDIT FIX:
-- [PERF-1] Radius broadcast: VFXSplashEvent, CastReplication, dan CleanupCast
--          tidak lagi FireClient ke SEMUA player — hanya ke player dalam
--          radius (FishingPerfConfig). Caster selalu menerima efeknya sendiri.
--          Ini memutus pola O(pemancing × semua player) pada network dan
--          kerja handler client.
-- Semua validasi anti-exploit, rate limit, session tracker, sell, restore,
-- autosell, dan lifecycle TIDAK berubah.

local FishingSystem = game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local MessagingService = game:GetService("MessagingService")
local PhysicsService = game:GetService("PhysicsService")

local DataManager = require(FishingSystem:WaitForChild("FishingModules"):WaitForChild("DataManager"))
local FishingConfig = require(FishingSystem:WaitForChild("FishingConfig"))
local PerfConfig = require(FishingSystem:WaitForChild("FishingPerfConfig"))
local GameProfileService = require(game:GetService("ServerScriptService").Data.PetCore:WaitForChild("FishData"))

-- ═══════════════════════════════════════════════════════════════
-- [PERF-1] RADIUS HELPER
-- ═══════════════════════════════════════════════════════════════
local function isWithinRadius(targetPlayer, origin, radius)
	local char = targetPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return (hrp.Position - origin).Magnitude <= radius
end

-- ═══════════════════════════════════════════════════════════════
-- VFX DEBOUNCE
-- ═══════════════════════════════════════════════════════════════
local VFX_DEBOUNCE_TIME = 0.15
local VFX_MAX_PER_SECOND = 8
local playerVFXCooldowns = {}
local playerVFXCounts = {}

local function canFireVFX(player, eventName)
	eventName = eventName or "default"
	local userId = player.UserId
	if not playerVFXCooldowns[userId] then playerVFXCooldowns[userId] = {} end
	if not playerVFXCounts[userId] then playerVFXCounts[userId] = 0 end
	if playerVFXCounts[userId] >= VFX_MAX_PER_SECOND then return false end
	local now = tick()
	if now - (playerVFXCooldowns[userId][eventName] or 0) < VFX_DEBOUNCE_TIME then return false end
	playerVFXCooldowns[userId][eventName] = now
	playerVFXCounts[userId] += 1
	return true
end

local function cleanupVFXTracking(userId)
	playerVFXCooldowns[userId] = nil
	playerVFXCounts[userId] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- UNIVERSAL REMOTE RATE-LIMITER
-- ═══════════════════════════════════════════════════════════════
local remoteRateLimits = {}

local function canFireRemote(userId, remoteName, cooldown)
	cooldown = cooldown or 0.2
	if not remoteRateLimits[userId] then remoteRateLimits[userId] = {} end
	local now = tick()
	if (now - (remoteRateLimits[userId][remoteName] or 0)) < cooldown then
		return false
	end
	remoteRateLimits[userId][remoteName] = now
	return true
end

local function cleanupRemoteRateLimits(userId)
	remoteRateLimits[userId] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI-EXPLOIT: FISHING SESSION TRACKER
-- ═══════════════════════════════════════════════════════════════
local activeFishingSessions  = {}
local SESSION_MIN_FISH_TIME  = 2.0
local SESSION_MAX_FISH_TIME  = 120
local SESSION_CLAIM_COOLDOWN = 1.5
local lastClaimTime          = {}

-- ═══════════════════════════════════════════════════════════════
-- SERVER TICK LOOP
-- ═══════════════════════════════════════════════════════════════
local serverTickAccum         = 0
local COOLDOWN_PRUNE_INTERVAL = 30
local cooldownPruneAccum      = 0
local SESSION_CLEANUP_INTERVAL = 15
local sessionCleanupAccum     = 0

RunService.Heartbeat:Connect(function(dt)
	serverTickAccum += dt
	if serverTickAccum >= 1 then
		serverTickAccum = 0
		table.clear(playerVFXCounts)
	end

	cooldownPruneAccum += dt
	if cooldownPruneAccum >= COOLDOWN_PRUNE_INTERVAL then
		cooldownPruneAccum = 0
		local now = tick()
		for userId, cooldowns in pairs(playerVFXCooldowns) do
			local p = Players:GetPlayerByUserId(userId)
			if not p then
				playerVFXCooldowns[userId] = nil
				playerVFXCounts[userId] = nil
			else
				for eventName, lastTime in pairs(cooldowns) do
					if (now - lastTime) > 10 then
						cooldowns[eventName] = nil
					end
				end
			end
		end

		for userId in pairs(remoteRateLimits) do
			if not Players:GetPlayerByUserId(userId) then
				remoteRateLimits[userId] = nil
			end
		end
	end

	sessionCleanupAccum += dt
	if sessionCleanupAccum >= SESSION_CLEANUP_INTERVAL then
		sessionCleanupAccum = 0
		local now = os.clock()
		for uId, sess in pairs(activeFishingSessions) do
			if (now - sess.castTime) > SESSION_MAX_FISH_TIME then
				activeFishingSessions[uId] = nil
			end
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════════
local function ensureRemote(parent, name)
	local remote = parent:FindFirstChild(name)

	if remote then
		assert(
			remote:IsA("RemoteEvent"),
			string.format("%s.%s harus berupa RemoteEvent, bukan %s", parent:GetFullName(), name, remote.ClassName)
		)
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local fishGiverEvent        = ensureRemote(FishingSystem, "FishGiver")
local castReplicationEvent  = ensureRemote(FishingSystem, "CastReplication")
local cleanupCastEvent      = ensureRemote(FishingSystem, "CleanupCast")
local showNotificationEvent = ensureRemote(FishingSystem, "ShowNotification")
local sellFishEvent         = ensureRemote(FishingSystem, "SellFish")
local SendChatMessage       = ensureRemote(FishingSystem, "SendChatMessage")
local fishPopEvent          = ensureRemote(FishingSystem, "FishPopEvent")
local fishCaughtResult      = ensureRemote(FishingSystem, "FishCaughtResult")
local vfxSplashEvent        = ensureRemote(FishingSystem, "VFXSplashEvent")
local publishFishCatchEvent = ensureRemote(FishingSystem, "PublishFishCatch")

local validatedFishCaughtEvent = FishingSystem:FindFirstChild("ValidatedFishCaught")
if not validatedFishCaughtEvent then
	validatedFishCaughtEvent = Instance.new("BindableEvent")
	validatedFishCaughtEvent.Name = "ValidatedFishCaught"
	validatedFishCaughtEvent.Parent = FishingSystem
end

-- VFX Splash validation
local VFX_SPLASH_MAX_DISTANCE = 200

local function isFiniteNumber(value)
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

vfxSplashEvent.OnServerEvent:Connect(function(player, rodName, splashPosition)
	if typeof(rodName) ~= "string" or not isFiniteVector3(splashPosition) then return end

	local character = player.Character
	local equippedRod = character and character:FindFirstChild(rodName)
	if not equippedRod or not equippedRod:IsA("Tool") then return end
	if not canFireVFX(player, "VFXSplash") then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - splashPosition).Magnitude > VFX_SPLASH_MAX_DISTANCE then return end

	-- [PERF-1] Hanya ke player dalam radius; caster selalu menerima
	-- (efek miliknya sendiri datang dari echo server).
	local radius = PerfConfig.VfxBroadcastRadius
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer == player or isWithinRadius(targetPlayer, splashPosition, radius) then
			vfxSplashEvent:FireClient(targetPlayer, player, rodName, splashPosition)
		end
	end
end)

local SERVER_ID = game.JobId ~= "" and game.JobId or ("Studio_" .. tostring(math.random(1000000, 9999999)))

-- ═══════════════════════════════════════════════════════════════
-- ASSETS
-- ═══════════════════════════════════════════════════════════════
local fishFolder    = FishingSystem:WaitForChild("Assets"):WaitForChild("Fish")
local rodToolFolder = ServerStorage:WaitForChild("AllRods")

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════
local DEFAULT_ROD_NAME            = "LoveRod"
local DEFAULT_ROD_IS_FREE_FOR_ALL = true

local ROD_ALIAS = {
	["Basic Rod"] = "LoveRod",
	["BasicRod"]  = "LoveRod",
	["Basic_Rod"] = "LoveRod",
}

local function normalizeRodName(name)
	if type(name) ~= "string" then return nil end
	return ROD_ALIAS[name] or name
end

local playerConnections = {}
local restoreInProgress = {}
local initializedPlayers = {}
local autoSellInProgress = {}

-- ═══════════════════════════════════════════════════════════════
-- ANTI-EXPLOIT: SERVER-SIDE PITY TRACKER
-- ═══════════════════════════════════════════════════════════════
local playerPityTrackers = {}

local function getPlayerPityTracker(userId)
	if not playerPityTrackers[userId] then
		if FishingConfig.CreatePityTracker then
			playerPityTrackers[userId] = FishingConfig.CreatePityTracker()
		end
	end
	return playerPityTrackers[userId]
end

-- ═══════════════════════════════════════════════════════════════
-- SERVER-SIDE FISH ROLLING
-- ═══════════════════════════════════════════════════════════════
local function serverSelectFish(player, rodName)
	if not rodName or rodName == "" then return nil, nil end
	local config = FishingConfig.GetRodConfig and FishingConfig.GetRodConfig(rodName)
	if not config then return nil, nil end

	local baseLuck  = config.baseLuck or 1
	local totalLuck = baseLuck

	if FishingConfig.CalculateTotalLuck then
		totalLuck = FishingConfig.CalculateTotalLuck(baseLuck, 1.0)
	end

	local selectedFish = nil
	if FishingConfig.RollFish then
		local pity = getPlayerPityTracker(player.UserId)
		local ok, result = pcall(FishingConfig.RollFish, pity, rodName, totalLuck, player)
		if ok and result then selectedFish = result end
	end
	if not selectedFish then return nil, nil end

	local maxWeight  = config.maxWeight or 100
	local fishWeight = nil
	if FishingConfig.GenerateFishWeight then
		local ok, w = pcall(FishingConfig.GenerateFishWeight, selectedFish, totalLuck, maxWeight)
		if ok and w then fishWeight = w end
	end
	if not fishWeight then
		fishWeight = math.floor(((selectedFish.minKg or 1) +
			math.random() * ((selectedFish.maxKg or 10) - (selectedFish.minKg or 1))) * 10) / 10
	end
	return selectedFish, fishWeight
end

local function validateFishExists(fishName)
	return fishName and fishFolder:FindFirstChild(fishName) ~= nil
end

-- ═══════════════════════════════════════════════════════════════
-- FISH TOOL CACHE
-- ═══════════════════════════════════════════════════════════════
local fishToolCache = {}

local function getFishCache(userId)
	if not fishToolCache[userId] then fishToolCache[userId] = {} end
	return fishToolCache[userId]
end

local function registerFishTool(userId, fishId, tool)
	if not userId or not fishId or not tool then return end
	local cache = getFishCache(userId)
	cache[tostring(fishId)] = tool
end

local function findFishToolById(player, fishId)
	if player and player.UserId then
		local cache = fishToolCache[player.UserId]
		if cache then
			local cached = cache[tostring(fishId)]
			if cached and cached.Parent then return cached end
			if cached then cache[tostring(fishId)] = nil end
		end
	end
	local function searchIn(container)
		if not container then return nil end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local id = tool:FindFirstChild("FishId")
				if id and id:IsA("StringValue") and id.Value == tostring(fishId) then
					if player and player.UserId then registerFishTool(player.UserId, fishId, tool) end
					return tool
				end
			end
		end
		return nil
	end
	return searchIn(player:FindFirstChild("Backpack")) or searchIn(player and player.Character)
end

local function findFishToolByIdInContainer(container, fishId)
	if not container or not fishId then return nil end
	for _, tool in ipairs(container:GetChildren()) do
		if tool:IsA("Tool") then
			local id = tool:FindFirstChild("FishId")
			if id and id:IsA("StringValue") and id.Value == tostring(fishId) then return tool end
		end
	end
	return nil
end

local function clearFishCache(userId)
	if fishToolCache[userId] then
		for k in pairs(fishToolCache[userId]) do
			fishToolCache[userId][k] = nil
		end
		fishToolCache[userId] = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function notify(player, msg, duration, color)
	if showNotificationEvent and player and player.Parent then
		pcall(function()
			showNotificationEvent:FireClient(player, msg, duration or 3, color or Color3.fromRGB(255,255,255))
		end)
	end
end

local function makeToolValue(class, name, value, parent)
	local v = Instance.new(class)
	v.Name = name; v.Value = value; v.Parent = parent
end

local function hasToolInBackpackOrCharacter(player, toolName)
	if not player or not toolName then return false end
	local bp = player:FindFirstChild("Backpack")
	if bp and bp:FindFirstChild(toolName) then return true end
	local ch = player.Character
	if ch and ch:FindFirstChild(toolName) then return true end
	return false
end

local function ensureRodTag(tool)
	if not tool or not tool:IsA("Tool") then return end
	local isRodByConfig = (FishingConfig and FishingConfig.RodConfig and FishingConfig.RodConfig[tool.Name]) ~= nil
	local isRodByParts  = tool:FindFirstChild("BobberTemplate") ~= nil or tool:FindFirstChild("MiniGame") ~= nil
	if (isRodByConfig or isRodByParts) and not CollectionService:HasTag(tool, "Rod") then
		CollectionService:AddTag(tool, "Rod")
	end
end

local function tagPlayerRods(player)
	if not player then return end
	local bp = player:FindFirstChild("Backpack")
	if bp then for _, t in ipairs(bp:GetChildren()) do ensureRodTag(t) end end
	if player.Character then for _, t in ipairs(player.Character:GetChildren()) do ensureRodTag(t) end end
end

local function wireAutoTag(player)
	local userId = player.UserId
	if not playerConnections[userId] then
		playerConnections[userId] = { core = {}, charChildConn = nil, bpChildConn = nil }
	end
	local pdata = playerConnections[userId]
	local bp = player:FindFirstChild("Backpack")
	if bp then
		for _, t in ipairs(bp:GetChildren()) do ensureRodTag(t) end
		if pdata.bpChildConn then pdata.bpChildConn:Disconnect(); pdata.bpChildConn = nil end
		pdata.bpChildConn = bp.ChildAdded:Connect(ensureRodTag)
	end
	local charAddedConn = player.CharacterAdded:Connect(function(char)
		if pdata.charChildConn then pdata.charChildConn:Disconnect(); pdata.charChildConn = nil end
		for _, t in ipairs(char:GetChildren()) do ensureRodTag(t) end
		pdata.charChildConn = char.ChildAdded:Connect(ensureRodTag)
		if pdata.bpChildConn then pdata.bpChildConn:Disconnect(); pdata.bpChildConn = nil end
		local newBp = player:FindFirstChild("Backpack")
		if newBp then
			for _, t in ipairs(newBp:GetChildren()) do ensureRodTag(t) end
			pdata.bpChildConn = newBp.ChildAdded:Connect(ensureRodTag)
		end
	end)
	table.insert(pdata.core, charAddedConn)
end

for _, rod in ipairs(rodToolFolder:GetChildren()) do
	if rod:IsA("Tool") and not CollectionService:HasTag(rod, "Rod") then
		CollectionService:AddTag(rod, "Rod")
	end
end

pcall(function()
	PhysicsService:RegisterCollisionGroup("FishEffect")
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("FishEffect", "Players", false)
end)

-- ═══════════════════════════════════════════════════════════════
-- CURRENCY & DATA
-- ═══════════════════════════════════════════════════════════════
local function addCurrency(player, amount)
	if not player or not player.Parent then return false end

	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end

	if typeof(GameProfileService) == "table" then
		if type(GameProfileService.AddCash) == "function" then
			GameProfileService:AddCash(player, amount)
			return true
		end
		if type(GameProfileService.AddMoney) == "function" then
			GameProfileService:AddMoney(player, amount)
			return true
		end
		if type(GameProfileService.AddCoins) == "function" then
			GameProfileService:AddCoins(player, amount)
			return true
		end
	end

	-- Fallback sesuai sistem uang game: Player.PlayerData.Cash.
	local playerData = player:FindFirstChild("PlayerData")
	local cash = playerData and playerData:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
		cash.Value += amount
		return true
	end

	warn("[FishingSystem] Cash player tidak ditemukan:", player.Name)
	return false
end

local function getSavedFish(player)
	if DataManager and type(DataManager.GetSavedFish) == "function" then return DataManager:GetSavedFish(player) or {} end
	if GameProfileService and type(GameProfileService.GetSavedFish) == "function" then return GameProfileService:GetSavedFish(player) or {} end
	return {}
end

local function buildSavedFishMap(player)
	local map = {}
	for _, fishData in ipairs(getSavedFish(player)) do
		if fishData.uniqueId ~= nil then
			map[tostring(fishData.uniqueId)] = fishData
		end
	end
	return map
end

local function getOwnedRods(player)
	if DataManager and type(DataManager.GetOwnedRods) == "function" then return DataManager:GetOwnedRods(player) or {} end
	if GameProfileService and type(GameProfileService.GetOwnedRods) == "function" then return GameProfileService:GetOwnedRods(player) or {} end
	return {}
end

local function hasRod(player, rodName)
	rodName = normalizeRodName(rodName)
	if DEFAULT_ROD_IS_FREE_FOR_ALL and rodName == DEFAULT_ROD_NAME then return true end
	if DataManager and type(DataManager.HasRod) == "function" then return DataManager:HasRod(player, rodName) == true end
	if GameProfileService and type(GameProfileService.HasRod) == "function" then return GameProfileService:HasRod(player, rodName) == true end
	return false
end

local function addFishWithLimit(player, fishData)
	if DataManager and type(DataManager.AddFishWithLimit) == "function" then return DataManager:AddFishWithLimit(player, fishData) end
	local limit =
		(GameProfileService and type(GameProfileService.GetFishInventoryLimit) == "function" and GameProfileService:GetFishInventoryLimit(player))
		or (FishingConfig.InventoryLimitSettings and FishingConfig.InventoryLimitSettings.maxFishInventory)
		or 5000
	local saved = getSavedFish(player)
	if #saved >= limit then return nil end
	if GameProfileService and type(GameProfileService.AddFish) == "function" then
		local ok, uid = GameProfileService:AddFish(player, fishData)
		if ok then return uid end
	end
	return nil
end

local function removeFish(player, fishUniqueId)
	if DataManager and type(DataManager.RemoveFish) == "function" then return DataManager:RemoveFish(player, fishUniqueId) end
	if GameProfileService and type(GameProfileService.RemoveFish) == "function" then return GameProfileService:RemoveFish(player, fishUniqueId) end
	return false, nil
end

local function calcFishPrice(weight, rarity)
	if DataManager and type(DataManager.CalculateFishPrice) == "function" then return DataManager:CalculateFishPrice(weight, rarity) end
	if FishingConfig and type(FishingConfig.CalculateFishPrice) == "function" then return FishingConfig.CalculateFishPrice(weight, rarity) end
	return math.floor((tonumber(weight) or 0) * 2)
end

-- ═══════════════════════════════════════════════════════════════
-- RESTORE FUNCTIONS
-- ═══════════════════════════════════════════════════════════════
local RESTORE_BATCH_SIZE = 10
-- Saved inventory tetap boleh besar, tetapi Backpack tidak boleh diisi ribuan Tool fisik.
local MAX_PHYSICAL_FISH_TOOLS = 100

local function countPhysicalFishTools(player)
	local count = 0
	local function countIn(container)
		if not container then return end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") and tool:FindFirstChild("FishId") then
				count += 1
			end
		end
	end
	countIn(player:FindFirstChild("Backpack"))
	countIn(player.Character)
	return count
end

local function restoreSavedFish(player)
	if not player or not player.Parent then return end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end

	local availableSlots = math.max(0, MAX_PHYSICAL_FISH_TOOLS - countPhysicalFishTools(player))
	if availableSlots <= 0 then return end

	local savedFish = getSavedFish(player)
	local restored = 0
	for _, fishData in ipairs(savedFish) do
		if restored >= availableSlots then break end
		if not player.Parent then return end
		backpack = player:FindFirstChild("Backpack")
		if not backpack then return end

		if fishData.uniqueId and not findFishToolById(player, tostring(fishData.uniqueId)) then
			local fishTemplate = fishFolder:FindFirstChild(fishData.name)
			if fishTemplate then
				local toolClone = fishTemplate:Clone()
				toolClone.ToolTip = " "
				local uid = tostring(fishData.uniqueId)
				makeToolValue("StringValue", "FishId", uid, toolClone)
				makeToolValue("NumberValue", "Weight", tonumber(fishData.weight) or 0, toolClone)
				makeToolValue("StringValue", "Rarity", tostring(fishData.rarity or "Common"), toolClone)
				makeToolValue("BoolValue", "isFavorited", fishData.isFavorited == true, toolClone)
				if player.Parent and backpack.Parent then
					toolClone.Parent = backpack
					registerFishTool(player.UserId, uid, toolClone)
					restored += 1
				else
					toolClone:Destroy()
					return
				end
			end
		end
		if restored > 0 and restored % RESTORE_BATCH_SIZE == 0 then task.wait() end
	end
end

local function restoreOwnedRods(player)
	if not player or not player.Parent then return end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	local ownedRods = getOwnedRods(player)
	local seen = {}
	for _, rodName in ipairs(ownedRods) do
		if not player or not player.Parent then return end
		rodName = normalizeRodName(rodName)
		if rodName and rodName ~= "" and not seen[rodName] then
			seen[rodName] = true
			if not hasToolInBackpackOrCharacter(player, rodName) then
				local rodTool = rodToolFolder:FindFirstChild(rodName)
				if rodTool then
					local clonedRod = rodTool:Clone()
					if not CollectionService:HasTag(clonedRod, "Rod") then CollectionService:AddTag(clonedRod, "Rod") end
					if player and player.Parent and backpack and backpack.Parent then
						clonedRod.Parent = backpack
					else
						clonedRod:Destroy()
					end
				end
			end
		end
	end
end

local function giveDefaultRod(player)
	if not player or not player.Parent then return end
	if hasToolInBackpackOrCharacter(player, DEFAULT_ROD_NAME) then return end
	if not DEFAULT_ROD_IS_FREE_FOR_ALL and not hasRod(player, DEFAULT_ROD_NAME) then return end
	local tpl = rodToolFolder:FindFirstChild(DEFAULT_ROD_NAME)
	if not tpl then return end
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return end
	local cloned = tpl:Clone()
	CollectionService:AddTag(cloned, "Rod")
	if player and player.Parent and backpack and backpack.Parent then cloned.Parent = backpack else cloned:Destroy() end
end

-- ═══════════════════════════════════════════════════════════════
-- QUEST & AUTOSELL
-- ═══════════════════════════════════════════════════════════════
local function handleQuestIntegration(player, fishName, fishRarity)
	pcall(function()
		local RS = game:GetService("ReplicatedStorage")
		local QS = RS:FindFirstChild("QuestSystem")
		if QS then
			local b = QS:FindFirstChild("Remotes") and QS.Remotes:FindFirstChild("FishCaught_Bind")
			if b and b:IsA("BindableEvent") then b:Fire(player, fishName, fishRarity) end
		end
		local QS2 = RS:FindFirstChild("QuestSystemV2")
		if QS2 then
			local b2 = QS2:FindFirstChild("Remotes") and QS2.Remotes:FindFirstChild("FishCaught_BindV2")
			if b2 and b2:IsA("BindableEvent") then b2:Fire(player, fishName, fishRarity) end
		end
	end)
end

local function handleAutoSell(player)
	if not player or not player.Parent then return end

	local userId = player.UserId
	if autoSellInProgress[userId] then return end
	autoSellInProgress[userId] = true

	local ok, err = xpcall(function()
		local asc = FishingConfig.AutoSellSettings
		if not asc or not asc.enabled then return end

		local savedFish = getSavedFish(player)
		if #savedFish < (tonumber(asc.triggerAt) or math.huge) then return end

		local counts, protectedCount = {}, 0
		for _, fd in ipairs(savedFish) do
			local fi = FishingConfig.GetFishDataByName and FishingConfig.GetFishDataByName(fd.name)
			if fi then
				local rarity = tostring(fd.rarity or fi.rarity or "Common")
				local protected = (asc.protectFavorites and fd.isFavorited == true)
					or rarity == "Legendary"
					or rarity == "Unknown"

				if protected then
					protectedCount += 1
				else
					counts[rarity] = (counts[rarity] or 0) + 1
				end
			end
		end

		local totalSold, totalMoney, soldByRarity = 0, 0, {}

		for rarity, shouldSell in pairs(asc.sellRarities or {}) do
			if shouldSell and (counts[rarity] or 0) > 0 then
				local toSell, sold = counts[rarity], 0

				for i = #savedFish, 1, -1 do
					if sold >= toSell then break end
					if not player.Parent then return end

					local fd = savedFish[i]
					local fi = FishingConfig.GetFishDataByName and FishingConfig.GetFishDataByName(fd.name)
					local authoritativeRarity = tostring(fd.rarity or (fi and fi.rarity) or "Common")
					local protected = (asc.protectFavorites and fd.isFavorited == true)
						or authoritativeRarity == "Legendary"
						or authoritativeRarity == "Unknown"

					if authoritativeRarity == rarity and not protected then
						local removed = select(1, removeFish(player, fd.uniqueId))
						if removed then
							local backpack = player:FindFirstChild("Backpack")
							if backpack then
								local tool = findFishToolByIdInContainer(backpack, fd.uniqueId)
								if tool then tool:Destroy() end
							end

							if player.Character then
								local tool = findFishToolByIdInContainer(player.Character, fd.uniqueId)
								if tool then tool:Destroy() end
							end

							if fishToolCache[userId] then
								fishToolCache[userId][tostring(fd.uniqueId)] = nil
							end

							sold += 1
							totalSold += 1
							totalMoney += calcFishPrice(fd.weight, authoritativeRarity)
							soldByRarity[authoritativeRarity] = (soldByRarity[authoritativeRarity] or 0) + 1
						end
					end
				end
			end
		end

		if totalMoney > 0 and player.Parent and addCurrency(player, totalMoney) then
			local function formatNumber(number)
				return tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
			end

			local breakdown = {}
			for rarity, count in pairs(soldByRarity) do
				table.insert(breakdown, rarity .. ": " .. count)
			end

			local message = string.format("Sold %d fish for Rp%s!", totalSold, formatNumber(totalMoney))
			if #breakdown > 0 then
				message ..= "\n" .. table.concat(breakdown, ", ")
			end
			if protectedCount > 0 then
				message ..= string.format("\n✨ Protected: %d fish", protectedCount)
			end

			notify(player, message, 6, Color3.fromRGB(100, 255, 100))
		end
	end, debug.traceback)

	autoSellInProgress[userId] = nil

	if not ok then
		warn("[FishingSystem] AutoSell error untuk", player.Name, err)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- FISH CAUGHT EVENT
-- ═══════════════════════════════════════════════════════════════
if fishGiverEvent then
	fishGiverEvent.OnServerEvent:Connect(function(player, clientData)
		if not player or not player.Parent then return end
		local userId = player.UserId

		if not canFireRemote(userId, "FishGiver", 1.0) then return end

		local session = activeFishingSessions[userId]
		if not session or session.state ~= "casting" then
			warn("[AntiExploit] BLOCKED:", player.Name, "- no active fishing session")
			return
		end

		local now     = os.clock()
		local elapsed = now - session.castTime

		if elapsed < SESSION_MIN_FISH_TIME then
			warn("[AntiExploit] BLOCKED:", player.Name, "- too fast:", string.format("%.1f", elapsed), "seconds")
			activeFishingSessions[userId] = nil
			return
		end

		if elapsed > SESSION_MAX_FISH_TIME then
			activeFishingSessions[userId] = nil
			return
		end

		if (now - (lastClaimTime[userId] or 0)) < SESSION_CLAIM_COOLDOWN then return end
		lastClaimTime[userId] = now

		local rodName = session.rodName
		if not rodName or not hasRod(player, rodName) then
			activeFishingSessions[userId] = nil
			return
		end

		activeFishingSessions[userId] = nil

		local selectedFish, fishWeight = serverSelectFish(player, rodName)
		if not selectedFish or not selectedFish.name then return end
		if not validateFishExists(selectedFish.name) then return end

		local fish = {
			name   = selectedFish.name,
			weight = fishWeight,
			rarity = selectedFish.rarity or "Common",
		}

		local eventOverride = false

		if _G.IsLegendaryEventActive and _G.IsLegendaryEventActive() == true then
			local eventRarity = _G.GetEventFishRarity and _G.GetEventFishRarity(player)
			if eventRarity then
				eventOverride = true
				if eventRarity == "Unknown" and _G.RecordUnknownCatch then _G.RecordUnknownCatch(player) end
				fish.rarity = eventRarity
				local newFishData
				if FishingConfig.PickFishFromRarity then
					local ok, r = pcall(FishingConfig.PickFishFromRarity, eventRarity)
					if ok and r then newFishData = r end
				end
				if not newFishData and FishingConfig.FishTable then
					local candidates = {}
					for _, f in ipairs(FishingConfig.FishTable) do
						if f.rarity == eventRarity then table.insert(candidates, f) end
					end
					if #candidates > 0 then newFishData = candidates[math.random(1, #candidates)] end
				end
				if newFishData and newFishData.name then
					fish.name   = newFishData.name
					fish.weight = math.floor(((newFishData.minKg or 80) + math.random() * ((newFishData.maxKg or 1000) - (newFishData.minKg or 80))) * 10) / 10
				end
			end
		end

		if not player or not player.Parent then return end
		if not fishFolder:FindFirstChild(fish.name) then return end

		local uniqueFishId = addFishWithLimit(player, { name = fish.name, weight = fish.weight, rarity = fish.rarity })
		if not uniqueFishId then
			notify(player,
				(FishingConfig.InventoryLimitSettings and FishingConfig.InventoryLimitSettings.fullInventoryMessage) or "Inventory full!",
				4, Color3.fromRGB(255,200,100))
			return
		end

		if not player or not player.Parent then return end
		local uid = tostring(uniqueFishId)

		-- Hindari ribuan Tool fisik di Backpack. Data ikan tetap tersimpan penuh.
		if not findFishToolById(player, uid) and countPhysicalFishTools(player) < MAX_PHYSICAL_FISH_TOOLS then
			local backpack = player:FindFirstChild("Backpack")
			local template = fishFolder:FindFirstChild(fish.name)
			if backpack and template then
				local clonedFish = template:Clone()
				clonedFish.ToolTip = " "
				makeToolValue("StringValue", "FishId", uid, clonedFish)
				makeToolValue("NumberValue", "Weight", fish.weight, clonedFish)
				makeToolValue("StringValue", "Rarity", fish.rarity, clonedFish)
				makeToolValue("BoolValue", "isFavorited", false, clonedFish)
				if player.Parent and backpack.Parent then
					clonedFish.Parent = backpack
					registerFishTool(userId, uid, clonedFish)
				else
					clonedFish:Destroy()
				end
			end
		end

		pcall(function()
			if player and player.Parent then
				fishCaughtResult:FireClient(player, {
					name     = fish.name,
					weight   = fish.weight,
					rarity   = fish.rarity,
					uniqueId = uid,
				})
			end
		end)

		if validatedFishCaughtEvent:IsA("BindableEvent") then
			validatedFishCaughtEvent:Fire(player, fish.name, fish.rarity, fish.weight)
		end

		if eventOverride and showNotificationEvent then
			local col = fish.rarity == "Unknown" and Color3.fromRGB(190,0,3) or Color3.fromRGB(255,128,0)
			pcall(function()
				if player and player.Parent then
					showNotificationEvent:FireClient(player,
						string.format("🌟 EVENT: Caught %s %.1fkg %s!", fish.rarity, fish.weight, fish.name), 5, col)
				end
			end)
		end

		if fish.rarity == "Unknown" then
			if SendChatMessage then
				pcall(function() SendChatMessage:FireAllClients("General", player.Name, fish.name, fish.weight, fish.rarity) end)
			end
			pcall(function()
				MessagingService:PublishAsync("GlobalFishCatch", {
					ServerId = SERVER_ID, Sender = player.Name,
					FishName = fish.name, Weight = fish.weight, Rarity = fish.rarity,
				})
			end)
		end

		task.spawn(handleQuestIntegration, player, fish.name, fish.rarity)
		task.spawn(handleAutoSell, player)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- CAST REPLICATION
-- [PERF-1] Broadcast hanya ke player dalam CastBroadcastRadius —
-- client memang membuang cast dari caster berjarak > 60 stud, jadi
-- mengirimnya ke semua player hanya membuang network O(players).
-- ═══════════════════════════════════════════════════════════════
local CAST_REPLICATION_COOLDOWN = 0.4
local CAST_MAX_ROD_DISTANCE = 50
local CAST_MAX_VELOCITY = 250

if castReplicationEvent then
	castReplicationEvent.OnServerEvent:Connect(function(player, rodPos, vel, rodName, power)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
		if not player.Parent then return end
		if not isFiniteVector3(rodPos) or not isFiniteVector3(vel) then return end
		if vel.Magnitude > CAST_MAX_VELOCITY then return end
		if typeof(power) ~= "number" or not isFiniteNumber(power) then power = 0 end
		power = math.clamp(power, 0, 100)
		if typeof(rodName) ~= "string" then rodName = "" end

		local userId = player.UserId

		if not canFireRemote(userId, "CastReplication", CAST_REPLICATION_COOLDOWN) then return end

		rodName = normalizeRodName(rodName)
		if not rodName or not hasRod(player, rodName) then return end

		local char = player.Character
		if not char then return end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - rodPos).Magnitude > CAST_MAX_ROD_DISTANCE then return end

		local hasRodEquipped = false
		for _, tool in ipairs(char:GetChildren()) do
			if tool:IsA("Tool") and tool.Name == rodName then hasRodEquipped = true; break end
		end
		if not hasRodEquipped then return end

		local existingSession = activeFishingSessions[userId]
		if existingSession and not existingSession.markedForCleanup then return end

		activeFishingSessions[userId] = {
			state    = "casting",
			castTime = os.clock(),
			rodName  = rodName,
		}

		local serverTime = workspace:GetServerTimeNow()
		local radius = PerfConfig.CastBroadcastRadius
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player and isWithinRadius(otherPlayer, rodPos, radius) then
				castReplicationEvent:FireClient(otherPlayer, player, rodPos, vel, rodName, power, serverTime)
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP CAST
-- [PERF-1] Relay cleanup juga radius-culled. Client yang tidak
-- menerima relay tetap aman: simulasi hook lain punya safety
-- timeout 15 detik + distance recheck sendiri.
-- ═══════════════════════════════════════════════════════════════
if cleanupCastEvent then
	cleanupCastEvent.OnServerEvent:Connect(function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return end

		local userId = player.UserId

		if not canFireRemote(userId, "CleanupCast", 0.2) then return end

		local sessionAtCleanup = activeFishingSessions[userId]
		if sessionAtCleanup then
			sessionAtCleanup.markedForCleanup = true
			task.delay(1, function()
				if activeFishingSessions[userId] == sessionAtCleanup then
					activeFishingSessions[userId] = nil
				end
			end)
		end

		local originHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local radius = PerfConfig.CleanupBroadcastRadius
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player then
				if not originHrp or isWithinRadius(otherPlayer, originHrp.Position, radius) then
					cleanupCastEvent:FireClient(otherPlayer, player)
				end
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- SELL FISH
-- ═══════════════════════════════════════════════════════════════
local SELL_COOLDOWN = 0.5

local function destroyFishToolReferences(player, fishId)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local tool = findFishToolByIdInContainer(backpack, fishId)
		if tool then tool:Destroy() end
	end

	if player.Character then
		local tool = findFishToolByIdInContainer(player.Character, fishId)
		if tool then tool:Destroy() end
	end

	local cache = fishToolCache[player.UserId]
	if cache then
		cache[tostring(fishId)] = nil
	end
end

if sellFishEvent then
	sellFishEvent.OnServerEvent:Connect(function(player, sellType, fishData)
		if not player or not player.Parent then return end
		if not canFireRemote(player.UserId, "SellFish", SELL_COOLDOWN) then return end

		local savedFishMap = buildSavedFishMap(player)

		if sellType == "SellAllBatch" then
			if typeof(fishData) ~= "table" then return end

			local MAX_BATCH = 200
			if #fishData > MAX_BATCH then
				warn("[AntiExploit] SellAllBatch terlalu besar dari", player.Name, #fishData)
				return
			end

			local total = 0
			local seenIds = {}

			for _, requestedFish in ipairs(fishData) do
				if not player.Parent then return end

				local fishId = typeof(requestedFish) == "table" and requestedFish.fishId
				if fishId ~= nil then
					local key = tostring(fishId)
					local authoritativeFish = savedFishMap[key]

					if authoritativeFish
						and authoritativeFish.isFavorited ~= true
						and not seenIds[key] then
						seenIds[key] = true

						local removed = select(1, removeFish(player, fishId))
						if removed then
							total += calcFishPrice(
								authoritativeFish.weight,
								authoritativeFish.rarity
							)
							destroyFishToolReferences(player, fishId)
						end
					end
				end
			end

			if total > 0 and player.Parent then
				addCurrency(player, total)
			end

		elseif sellType == "SellSingle" then
			local fishId = typeof(fishData) == "table" and fishData.fishId
			if fishId == nil then return end

			local authoritativeFish = savedFishMap[tostring(fishId)]
			if not authoritativeFish or authoritativeFish.isFavorited == true then return end

			local removed = select(1, removeFish(player, fishId))
			if removed and player.Parent then
				addCurrency(
					player,
					calcFishPrice(authoritativeFish.weight, authoritativeFish.rarity)
				)
				destroyFishToolReferences(player, fishId)
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER LIFECYCLE
-- ═══════════════════════════════════════════════════════════════
local function restoreAll(player)
	if not player or not player.Parent then return end
	if not player:FindFirstChild("Backpack") then return end

	local userId = player.UserId
	if restoreInProgress[userId] then return end
	restoreInProgress[userId] = true

	local ok, err = xpcall(function()
		giveDefaultRod(player)
		restoreOwnedRods(player)
		restoreSavedFish(player)
		tagPlayerRods(player)
	end, debug.traceback)

	restoreInProgress[userId] = nil

	if not ok then
		warn("[FishingSystem] Restore gagal untuk", player.Name, err)
	end
end

local function onPlayerReady(player)
	if not player or not player.Parent then return end

	local userId = player.UserId
	if initializedPlayers[userId] then return end
	initializedPlayers[userId] = true

	local ok, err = xpcall(function()
		wireAutoTag(player)

		if not playerConnections[userId] then
			playerConnections[userId] = { core = {}, charChildConn = nil, bpChildConn = nil }
		end

		local pdata = playerConnections[userId]

		local restoreConn = player.CharacterAdded:Connect(function()
			task.delay(0.6, function()
				if player.Parent then restoreAll(player) end
			end)
		end)
		table.insert(pdata.core, restoreConn)

		if GameProfileService and GameProfileService.ProfileLoadedSignal
			and type(GameProfileService.ProfileLoadedSignal.Connect) == "function" then
			local profileConn = GameProfileService.ProfileLoadedSignal:Connect(function(loadedPlayer)
				if loadedPlayer == player and player.Parent then
					task.delay(0.6, function()
						if player.Parent then restoreAll(player) end
					end)
				end
			end)
			table.insert(pdata.core, profileConn)
		end

		-- Fallback ini tetap dijalankan agar player yang profilnya sudah loaded
		-- sebelum connection dibuat tidak kehilangan restore inventory.
		task.delay(2, function()
			if player.Parent then restoreAll(player) end
		end)
	end, debug.traceback)

	if not ok then
		initializedPlayers[userId] = nil
		warn("[FishingSystem] Inisialisasi player gagal:", player.Name, err)
	end
end

Players.PlayerAdded:Connect(onPlayerReady)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerReady, player) end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER REMOVING
-- ═══════════════════════════════════════════════════════════════
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId

	-- Player keluar = event jarang; kirim ke semua supaya tidak ada hook yatim.
	if cleanupCastEvent then
		pcall(function()
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= player then cleanupCastEvent:FireClient(otherPlayer, player) end
			end
		end)
	end

	local pdata = playerConnections[userId]
	if pdata then
		if pdata.core then
			for _, conn in ipairs(pdata.core) do
				if conn then pcall(function() if conn.Connected then conn:Disconnect() end end) end
			end
		end
		if pdata.charChildConn then pcall(function() if pdata.charChildConn.Connected then pdata.charChildConn:Disconnect() end end) end
		if pdata.bpChildConn   then pcall(function() if pdata.bpChildConn.Connected   then pdata.bpChildConn:Disconnect()   end end) end
		playerConnections[userId] = nil
	end

	restoreInProgress[userId]     = nil
	initializedPlayers[userId]    = nil
	autoSellInProgress[userId]    = nil
	cleanupVFXTracking(userId)
	cleanupRemoteRateLimits(userId)
	clearFishCache(userId)
	activeFishingSessions[userId] = nil
	lastClaimTime[userId]         = nil
	playerPityTrackers[userId]    = nil
end)
