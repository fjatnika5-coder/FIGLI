-- FishData (GameProfileService)
-- Location: ServerScriptService/Data/PetCore/FishData (ModuleScript)
--
-- AUDIT FIX VERSION:
-- [FIX A] Duplicate ClaimReward handler removed (QuestBoardServer V1 is the
--         single authority for quest claims; this module only owns the remotes
--         and the quest data helpers).
-- [FIX B] AddFish preserves a caller-supplied uniqueId/timestamp/isFavorited
--         (required by fish transfer & rollback) and is idempotent for an
--         existing uniqueId.
-- [FIX C] cleanupOldFish never deletes favorited fish.
-- [FIX D] HasRod/GetOwnedRods respect the RodInventory blacklist so an
--         admin-removed rod cannot be restored or equipped from profile data.
-- [FIX E] AddRod also clears the RodInventory blacklist (repurchase/regrant
--         works after an admin removal).
-- [FIX F] New GameProfileService:RemoveRod (used by AdminRodManager).
-- [FIX G] ForceReload remote is rate limited and ignored while the profile
--         is already active (anti spam / DataStore churn).

local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(SSS.Data.DataModule:WaitForChild("ProfileService"))
local CurrencyAdapter = require(SSS:WaitForChild("Fishing"):WaitForChild("CurrencyAdapter"))

local MAX_LOAD_ATTEMPTS = 5
local RETRY_DELAY = 2
local KICK_ON_FAIL = true
local RECOVERY_ENABLED = true
local FORCE_RELOAD_COOLDOWN = 10

local MEMORY_SETTINGS = {
	MAX_FISH_PER_PLAYER = 3000,
	AUTO_CLEANUP_THRESHOLD = 2500,
	CLEANUP_TARGET = 2000,
	PROFILE_SIZE_WARNING_MB = 5,
	MEMORY_CHECK_INTERVAL = 300,
}

-- Connection tracking
local PlayerConnections = {}
local ModuleConnections = {}

-- ═══════════════════════════════════════════════════════════════
-- REMOTE EVENTS SETUP
-- ═══════════════════════════════════════════════════════════════
local ProfileRemotes = ReplicatedStorage:FindFirstChild("ProfileRemotes")
if not ProfileRemotes then
	ProfileRemotes = Instance.new("Folder")
	ProfileRemotes.Name = "ProfileRemotes"
	ProfileRemotes.Parent = ReplicatedStorage
end

local ProfileStatusEvent = ProfileRemotes:FindFirstChild("ProfileStatus")
if not ProfileStatusEvent then
	ProfileStatusEvent = Instance.new("RemoteEvent")
	ProfileStatusEvent.Name = "ProfileStatus"
	ProfileStatusEvent.Parent = ProfileRemotes
end

local ForceReloadEvent = ProfileRemotes:FindFirstChild("ForceReload")
if not ForceReloadEvent then
	ForceReloadEvent = Instance.new("RemoteEvent")
	ForceReloadEvent.Name = "ForceReload"
	ForceReloadEvent.Parent = ProfileRemotes
end

-- Quest remotes (owned here; QuestBoardServer connects the claim handler)
local QuestRemotes = ReplicatedStorage:FindFirstChild("QuestRemotes")
if not QuestRemotes then
	QuestRemotes = Instance.new("Folder")
	QuestRemotes.Name = "QuestRemotes"
	QuestRemotes.Parent = ReplicatedStorage
end

local UpdateQuestUI = QuestRemotes:FindFirstChild("UpdateQuestUI")
if not UpdateQuestUI then
	UpdateQuestUI = Instance.new("RemoteEvent")
	UpdateQuestUI.Name = "UpdateQuestUI"
	UpdateQuestUI.Parent = QuestRemotes
end

local ClaimReward = QuestRemotes:FindFirstChild("ClaimReward")
if not ClaimReward then
	ClaimReward = Instance.new("RemoteEvent")
	ClaimReward.Name = "ClaimReward"
	ClaimReward.Parent = QuestRemotes
end

local function NewScriptSignal()
	local ScriptConnection = {}
	ScriptConnection.__index = ScriptConnection

	function ScriptConnection:Disconnect()
		if self._is_connected == false then return end
		self._is_connected = false
		self._script_signal._listener_count -= 1
		if self._script_signal._head == self then
			self._script_signal._head = self._next
		else
			local prev = self._script_signal._head
			while prev ~= nil and prev._next ~= self do prev = prev._next end
			if prev ~= nil then prev._next = self._next end
		end
	end

	local ScriptSignal = {}
	ScriptSignal.__index = ScriptSignal

	function ScriptSignal:Connect(listener)
		local script_connection = {
			_listener = listener,
			_script_signal = self,
			_next = self._head,
			_is_connected = true,
		}
		setmetatable(script_connection, ScriptConnection)
		self._head = script_connection
		self._listener_count += 1
		return script_connection
	end

	function ScriptSignal:Fire(...)
		local item = self._head
		while item ~= nil do
			if item._is_connected == true then
				task.spawn(item._listener, ...)
			end
			item = item._next
		end
	end

	return setmetatable({_head = nil, _listener_count = 0}, ScriptSignal)
end

local GAME_DATA_STORE_KEY = "PlayerGameData_V1"

local PlayerProfileTemplate = {
	Coins = 0,
	OwnedGamepasses = {},
	SavedFish = {},
	TotalFishCaught = 0,
	UnknownFishCaught = 0,
	OwnedRods = {},
	LastEquippedRod = nil,
	LastPosition = nil,
	FishInventoryLimit = MEMORY_SETTINGS.MAX_FISH_PER_PLAYER,
	QuestBoard = {
		CrystalKrakenCaught = 0,
		GlacierSerpentCaught = 0,
		RewardClaimed = false
	},
	RodUpgrades = {}, -- { ["RodName"] = level }
}

local PlayerProfileStore = ProfileService.GetProfileStore(GAME_DATA_STORE_KEY, PlayerProfileTemplate)
local PlayerProfiles = {}
local ProfileStatus = {}
local ForceReloadCooldowns = {}

local GameProfileService = {}
GameProfileService.ProfileLoadedSignal = NewScriptSignal()
GameProfileService.ProfileReadySignal = NewScriptSignal()

local function notifyClient(player, status, message)
	if player and player:IsDescendantOf(Players) then
		pcall(function()
			ProfileStatusEvent:FireClient(player, status, message)
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ROD BLACKLIST BRIDGE (RodInventoryServer)
-- ═══════════════════════════════════════════════════════════════
local function isRodBlacklisted(player, rodName)
	local fn = _G.RodInventory_IsBlacklisted
	if type(fn) ~= "function" then return false end
	local ok, result = pcall(fn, player, rodName)
	return ok and result == true
end

-- ═══════════════════════════════════════════════════════════════
-- MEMORY OPTIMIZATION
-- ═══════════════════════════════════════════════════════════════

-- [FIX C] Favorited fish are never pruned; only the oldest
-- non-favorited fish are removed until CLEANUP_TARGET is reached.
local function cleanupOldFish(profile)
	if not profile or not profile.Data or not profile.Data.SavedFish then return 0 end

	local saved_fish = profile.Data.SavedFish
	local count = #saved_fish

	if count <= MEMORY_SETTINGS.AUTO_CLEANUP_THRESHOLD then
		return 0
	end

	local kept, removable = {}, {}
	for _, fish in ipairs(saved_fish) do
		if fish.isFavorited == true then
			table.insert(kept, fish)
		else
			table.insert(removable, fish)
		end
	end

	-- newest first
	table.sort(removable, function(a, b)
		return (a.timestamp or 0) > (b.timestamp or 0)
	end)

	local slots = math.max(0, MEMORY_SETTINGS.CLEANUP_TARGET - #kept)
	for i = 1, math.min(slots, #removable) do
		table.insert(kept, removable[i])
	end

	local removed = count - #kept
	if removed <= 0 then
		return 0
	end

	profile.Data.SavedFish = kept
	return removed
end

local function getProfileSize(profile)
	if not profile or not profile.Data then return 0 end

	local success, encoded = pcall(function()
		return HttpService:JSONEncode(profile.Data)
	end)

	if success then
		return #encoded / 1024 / 1024
	end

	return 0
end

local function trimProfileBeforeSave(profile)
	if not profile or not profile.Data then return false end

	local size_mb = getProfileSize(profile)

	if size_mb > MEMORY_SETTINGS.PROFILE_SIZE_WARNING_MB then
		local removed = cleanupOldFish(profile)
		if removed > 0 then
			warn(string.format(
				"[FishData]: Auto-trimmed %d fish from profile (%.2f MB -> %.2f MB)",
				removed,
				size_mb,
				getProfileSize(profile)
				))
			return true
		end
	end

	return false
end

local function ensureCoinsAlias(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local money = leaderstats:FindFirstChild("Money")
	local coins = leaderstats:FindFirstChild("Coins")

	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = (money and money.Value) or (CurrencyAdapter:Get(player) or 0)
		coins.Parent = leaderstats
	end

	if not PlayerConnections[player] then
		PlayerConnections[player] = {}
	end

	if money then
		coins.Value = money.Value

		local lockA, lockB = false, false

		local conn1 = money:GetPropertyChangedSignal("Value"):Connect(function()
			if lockB then return end
			lockA = true
			coins.Value = money.Value
			player:SetAttribute("Coins", coins.Value)
			player:SetAttribute("Cash", coins.Value)
			lockA = false
		end)

		local conn2 = coins:GetPropertyChangedSignal("Value"):Connect(function()
			if lockA then return end
			lockB = true
			money.Value = coins.Value
			player:SetAttribute("Coins", coins.Value)
			player:SetAttribute("Cash", coins.Value)
			lockB = false
		end)

		table.insert(PlayerConnections[player], conn1)
		table.insert(PlayerConnections[player], conn2)
	end

	player:SetAttribute("Coins", coins.Value)
	player:SetAttribute("Cash", coins.Value)

	return leaderstats, coins
end

local function loadProfileWithRetry(player)
	local profile = nil
	local lastError = nil

	for attempt = 1, MAX_LOAD_ATTEMPTS do
		if not player:IsDescendantOf(Players) then
			return nil, "player_left"
		end

		notifyClient(player, "loading", string.format("Loading data... (%d/%d)", attempt, MAX_LOAD_ATTEMPTS))
		player:SetAttribute("ProfileStatus", "loading")
		player:SetAttribute("ProfileLoadAttempt", attempt)

		local ok, err = pcall(function()
			profile = PlayerProfileStore:LoadProfileAsync("Player_" .. player.UserId)
		end)

		if ok and profile then
			return profile, nil
		end

		lastError = err or "Unknown error"

		if attempt < MAX_LOAD_ATTEMPTS then
			local waitTime = RETRY_DELAY * attempt
			notifyClient(player, "retrying", string.format("Retrying in %d seconds...", waitTime))
			task.wait(waitTime)
		end
	end

	return nil, lastError
end

-- ═══════════════════════════════════════════════════════════════
-- QUEST BOARD (data + UI push only; claim handler lives in
-- QuestBoardServer V1 — [FIX A])
-- ═══════════════════════════════════════════════════════════════

local function sendQuestUpdate(player)
	if not player or not player:IsDescendantOf(Players) then return end

	local profile = PlayerProfiles[player]
	if not profile or not profile.Data then return end

	if not profile.Data.QuestBoard then
		profile.Data.QuestBoard = {
			CrystalKrakenCaught = 0,
			GlacierSerpentCaught = 0,
			RewardClaimed = false
		}
	end

	local questData = profile.Data.QuestBoard
	local allComplete = questData.CrystalKrakenCaught >= 2 and questData.GlacierSerpentCaught >= 1

	local data = {
		quest1 = {
			current = questData.CrystalKrakenCaught,
			required = 2,
			complete = questData.CrystalKrakenCaught >= 2
		},
		quest2 = {
			current = questData.GlacierSerpentCaught,
			required = 1,
			complete = questData.GlacierSerpentCaught >= 1
		},
		allComplete = allComplete,
		rewardClaimed = questData.RewardClaimed
	}

	pcall(function()
		UpdateQuestUI:FireClient(player, data)
	end)
end

function GameProfileService:ForceReloadProfile(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false, "invalid_player"
	end

	if not player:IsDescendantOf(Players) then
		return false, "player_left"
	end

	local oldProfile = PlayerProfiles[player]
	if oldProfile then
		pcall(function()
			oldProfile:Release()
		end)
		PlayerProfiles[player] = nil
	end

	ProfileStatus[player] = "reloading"
	notifyClient(player, "reloading", "Reloading your data...")

	local profile, err = loadProfileWithRetry(player)

	if not profile then
		ProfileStatus[player] = "failed"
		notifyClient(player, "failed", "Failed to load data: " .. tostring(err))
		player:SetAttribute("ProfileStatus", "failed")
		return false, err
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if type(profile.Data.SavedFish) ~= "table" then profile.Data.SavedFish = {} end
	if type(profile.Data.OwnedRods) ~= "table" then profile.Data.OwnedRods = {} end
	if type(profile.Data.TotalFishCaught) ~= "number" then profile.Data.TotalFishCaught = 0 end
	if type(profile.Data.UnknownFishCaught) ~= "number" then profile.Data.UnknownFishCaught = 0 end
	if type(profile.Data.QuestBoard) ~= "table" then
		profile.Data.QuestBoard = {
			CrystalKrakenCaught = 0,
			GlacierSerpentCaught = 0,
			RewardClaimed = false
		}
	end
	if type(profile.Data.RodUpgrades) ~= "table" then profile.Data.RodUpgrades = {} end

	PlayerProfiles[player] = profile
	ProfileStatus[player] = "ready"

	profile:ListenToRelease(function()
		PlayerProfiles[player] = nil
		ProfileStatus[player] = "released"
		player:SetAttribute("ProfileActive", false)
		player:SetAttribute("ProfileStatus", "released")
		notifyClient(player, "released", "Profile session ended")

		if RECOVERY_ENABLED and player:IsDescendantOf(Players) then
			task.delay(3, function()
				if player:IsDescendantOf(Players) and not PlayerProfiles[player] then
					GameProfileService:ForceReloadProfile(player)
				end
			end)
		end
	end)

	player:SetAttribute("ProfileActive", true)
	player:SetAttribute("ProfileStatus", "ready")
	notifyClient(player, "ready", "Data loaded successfully!")

	GameProfileService.ProfileReadySignal:Fire(player)

	task.delay(1, function()
		if player and player:IsDescendantOf(Players) and PlayerProfiles[player] then
			sendQuestUpdate(player)
		end
	end)

	return true, nil
end

-- [FIX G] Rate limited; ignored while profile already active.
local ForceReloadConnection = ForceReloadEvent.OnServerEvent:Connect(function(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end

	local now = os.clock()
	if now - (ForceReloadCooldowns[player.UserId] or 0) < FORCE_RELOAD_COOLDOWN then return end
	ForceReloadCooldowns[player.UserId] = now

	local profile = PlayerProfiles[player]
	if profile and profile:IsActive() then return end

	GameProfileService:ForceReloadProfile(player)
end)

table.insert(ModuleConnections, ForceReloadConnection)

function GameProfileService:GetProfile(player, timeout)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end

	timeout = timeout or 15

	local profile = PlayerProfiles[player]
	if profile and profile:IsActive() then
		return profile
	end

	local startTime = os.clock()
	while os.clock() - startTime < timeout do
		profile = PlayerProfiles[player]
		if profile and profile:IsActive() then
			return profile
		end

		if not player:IsDescendantOf(Players) then
			return nil
		end

		task.wait(0.2)
	end

	return nil
end

function GameProfileService:IsProfileReady(player)
	local profile = PlayerProfiles[player]
	return profile ~= nil and profile:IsActive()
end

function GameProfileService:GetProfileStatus(player)
	return ProfileStatus[player] or "unknown"
end

function GameProfileService:AddCoins(player, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	return CurrencyAdapter:Add(player, amount)
end

function GameProfileService:SetCoins(player, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	return CurrencyAdapter:Set(player, amount)
end

function GameProfileService:TryPurchase(player, cost)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false, 0
	end
	return CurrencyAdapter:TryPurchase(player, cost)
end

function GameProfileService:GetCoins(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return 0
	end
	return CurrencyAdapter:Get(player) or 0
end

function GameProfileService:SavePlayerData(player)
	local profile = PlayerProfiles[player]
	if not profile or not profile:IsActive() then return false end

	trimProfileBeforeSave(profile)

	profile.Data.Coins = CurrencyAdapter:Get(player) or 0
	return true
end

function GameProfileService:GetFishInventoryLimit(player)
	return MEMORY_SETTINGS.MAX_FISH_PER_PLAYER
end

-- ═══════════════════════════════════════════════════════════════
-- FISH
-- ═══════════════════════════════════════════════════════════════

-- [FIX B] If fishData.uniqueId is provided (transfer / rollback), it is
-- preserved along with timestamp and isFavorited, and the call is
-- idempotent: re-adding an id that already exists is a no-op success.
function GameProfileService:AddFish(player, fishData)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile:IsActive() then
		return false, nil, "profile_not_ready"
	end

	if not profile.Data.SavedFish then profile.Data.SavedFish = {} end

	local providedId = fishData.uniqueId and tostring(fishData.uniqueId) or nil
	if providedId then
		for _, fish in ipairs(profile.Data.SavedFish) do
			if fish.uniqueId == providedId then
				return true, providedId, nil
			end
		end
	end

	local limit = self:GetFishInventoryLimit(player)
	local current_count = #profile.Data.SavedFish

	if current_count >= MEMORY_SETTINGS.AUTO_CLEANUP_THRESHOLD then
		local removed = cleanupOldFish(profile)
		if removed > 0 then
			warn(string.format(
				"[FishData]: Auto-cleaned %d old fish for %s (%d -> %d)",
				removed,
				player.Name,
				current_count,
				#profile.Data.SavedFish
				))
		end
		current_count = #profile.Data.SavedFish
	end

	if current_count >= limit then
		return false, nil, "inventory_full"
	end

	local uniqueId = providedId or HttpService:GenerateGUID(false)
	local fishEntry = {
		name = fishData.name,
		weight = fishData.weight,
		rarity = fishData.rarity or "Common",
		uniqueId = uniqueId,
		timestamp = fishData.timestamp or tick(),
		isFavorited = fishData.isFavorited == true
	}

	table.insert(profile.Data.SavedFish, fishEntry)

	-- Transferred fish (provided id) must not inflate catch statistics.
	if not providedId then
		profile.Data.TotalFishCaught = (profile.Data.TotalFishCaught or 0) + 1

		if fishData.rarity == "Unknown" then
			profile.Data.UnknownFishCaught = (profile.Data.UnknownFishCaught or 0) + 1
		end
	end

	return true, uniqueId, nil
end

function GameProfileService:RemoveFish(player, fishUniqueId)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile.Data.SavedFish then return false, nil end

	fishUniqueId = tostring(fishUniqueId)
	for i, fish in ipairs(profile.Data.SavedFish) do
		if fish.uniqueId == fishUniqueId then
			local removed = table.remove(profile.Data.SavedFish, i)
			return true, removed
		end
	end

	return false, nil
end

function GameProfileService:GetSavedFish(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return {} end
	return profile.Data.SavedFish or {}
end

function GameProfileService:GetTotalFishCaught(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return 0 end
	return profile.Data.TotalFishCaught or 0
end

function GameProfileService:GetUnknownFishCaught(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return 0 end
	return profile.Data.UnknownFishCaught or 0
end

function GameProfileService:ToggleFavoriteFish(player, fishUniqueId)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile.Data.SavedFish then return nil end

	for _, fish in ipairs(profile.Data.SavedFish) do
		if fish.uniqueId == fishUniqueId then
			fish.isFavorited = not fish.isFavorited
			return fish.isFavorited
		end
	end
	return nil
end

-- ═══════════════════════════════════════════════════════════════
-- RODS
-- ═══════════════════════════════════════════════════════════════

-- [FIX E] Also clears the RodInventory blacklist so a regranted /
-- repurchased rod becomes visible and equippable again.
function GameProfileService:AddRod(player, rodName)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile:IsActive() then return false end
	if type(rodName) ~= "string" or rodName == "" then return false end

	if not profile.Data.OwnedRods then profile.Data.OwnedRods = {} end

	local already = false
	for _, r in ipairs(profile.Data.OwnedRods) do
		if r == rodName then
			already = true
			break
		end
	end

	if not already then
		table.insert(profile.Data.OwnedRods, rodName)
	end

	if type(_G.RodInventory_AddOwned) == "function" then
		pcall(_G.RodInventory_AddOwned, player, rodName)
	end

	return true
end

-- [FIX F] Removes the rod from profile data and (via RodInventory)
-- blacklists it + destroys the physical tool.
function GameProfileService:RemoveRod(player, rodName)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile:IsActive() then return false end
	if type(rodName) ~= "string" or rodName == "" then return false end

	local removed = false
	if profile.Data.OwnedRods then
		for i, r in ipairs(profile.Data.OwnedRods) do
			if r == rodName then
				table.remove(profile.Data.OwnedRods, i)
				removed = true
				break
			end
		end
	end

	if profile.Data.LastEquippedRod == rodName then
		profile.Data.LastEquippedRod = nil
	end

	if type(_G.RodInventory_RemoveOwned) == "function" then
		local ok = pcall(_G.RodInventory_RemoveOwned, player, rodName)
		removed = removed or ok
	end

	return removed
end

-- [FIX D] Blacklisted rods count as not owned.
function GameProfileService:HasRod(player, rodName)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile.Data.OwnedRods then return false end
	for _, r in ipairs(profile.Data.OwnedRods) do
		if r == rodName then
			return not isRodBlacklisted(player, rodName)
		end
	end
	return false
end

-- [FIX D] Returns a filtered copy (callers only read the result).
function GameProfileService:GetOwnedRods(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return {} end

	local owned = profile.Data.OwnedRods or {}
	local result = {}
	for _, rodName in ipairs(owned) do
		if not isRodBlacklisted(player, rodName) then
			table.insert(result, rodName)
		end
	end
	return result
end

function GameProfileService:SetLastEquippedRod(player, rodName)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile:IsActive() then return false end
	profile.Data.LastEquippedRod = rodName
	return true
end

function GameProfileService:GetLastEquippedRod(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return nil end
	return profile.Data.LastEquippedRod
end

-- ═══════════════════════════════════════════════════════════════
-- ROD UPGRADES
-- ═══════════════════════════════════════════════════════════════

function GameProfileService:GetRodLevel(player, rodName)
	local profile = self:GetProfile(player, 5)
	if not profile then return 1 end
	if not profile.Data.RodUpgrades then profile.Data.RodUpgrades = {} end
	return profile.Data.RodUpgrades[rodName] or 1
end

function GameProfileService:SetRodLevel(player, rodName, level)
	local profile = self:GetProfile(player, 5)
	if not profile or not profile:IsActive() then return false end
	if not profile.Data.RodUpgrades then profile.Data.RodUpgrades = {} end
	profile.Data.RodUpgrades[rodName] = level
	return true
end

function GameProfileService:GetAllRodLevels(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return {} end
	return profile.Data.RodUpgrades or {}
end

-- ═══════════════════════════════════════════════════════════════
-- QUEST BOARD HELPERS
-- ═══════════════════════════════════════════════════════════════

function GameProfileService:GetQuestData(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return nil end

	if not profile.Data.QuestBoard then
		profile.Data.QuestBoard = {
			CrystalKrakenCaught = 0,
			GlacierSerpentCaught = 0,
			RewardClaimed = false
		}
	end

	return profile.Data.QuestBoard
end

function GameProfileService:ForceCompleteQuest(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return false end

	if not profile.Data.QuestBoard then
		profile.Data.QuestBoard = {
			CrystalKrakenCaught = 0,
			GlacierSerpentCaught = 0,
			RewardClaimed = false
		}
	end

	profile.Data.QuestBoard.CrystalKrakenCaught = 2
	profile.Data.QuestBoard.GlacierSerpentCaught = 1

	sendQuestUpdate(player)
	return true
end

function GameProfileService:ResetQuest(player)
	local profile = self:GetProfile(player, 5)
	if not profile then return false end

	profile.Data.QuestBoard = {
		CrystalKrakenCaught = 0,
		GlacierSerpentCaught = 0,
		RewardClaimed = false
	}

	sendQuestUpdate(player)
	return true
end

function GameProfileService:SendQuestUpdate(player)
	sendQuestUpdate(player)
end

-- ═══════════════════════════════════════════════════════════════
-- DEBUG & MONITORING
-- ═══════════════════════════════════════════════════════════════

function GameProfileService:GetMemoryStats()
	local stats = {
		total_profiles = 0,
		total_fish = 0,
		total_data_mb = 0,
		players = {}
	}

	for player, profile in pairs(PlayerProfiles) do
		if profile and profile:IsActive() then
			local fish_count = #(profile.Data.SavedFish or {})
			local size_mb = getProfileSize(profile)

			stats.total_profiles += 1
			stats.total_fish += fish_count
			stats.total_data_mb += size_mb

			table.insert(stats.players, {
				name = player.Name,
				fish_count = fish_count,
				size_mb = size_mb
			})
		end
	end

	return stats
end

function GameProfileService:PrintMemoryReport()
	local stats = self:GetMemoryStats()

	print("═══════════════════════════════════════════")
	print("FISHDATA MEMORY REPORT")
	print(string.format("Active Profiles: %d", stats.total_profiles))
	print(string.format("Total Fish: %d", stats.total_fish))
	print(string.format("Total Data Size: %.2f MB", stats.total_data_mb))

	table.sort(stats.players, function(a, b)
		return a.size_mb > b.size_mb
	end)

	print("Top 5 Largest Profiles:")
	for i = 1, math.min(5, #stats.players) do
		local p = stats.players[i]
		print(string.format("  %d. %s: %.2f MB (%d fish)",
			i, p.name, p.size_mb, p.fish_count))

		if p.size_mb > MEMORY_SETTINGS.PROFILE_SIZE_WARNING_MB then
			warn(string.format("    Profile exceeds %.0f MB warning threshold!",
				MEMORY_SETTINGS.PROFILE_SIZE_WARNING_MB))
		end
	end
	print("═══════════════════════════════════════════")
end

function GameProfileService:CleanupAllProfiles()
	local total_removed = 0

	for player, profile in pairs(PlayerProfiles) do
		if profile and profile:IsActive() then
			local removed = cleanupOldFish(profile)
			if removed > 0 then
				total_removed += removed
				print(string.format("[FishData]: Cleaned %d fish from %s",
					removed, player.Name))
			end
		end
	end

	return total_removed
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP
-- ═══════════════════════════════════════════════════════════════
local function cleanupPlayerConnections(player)
	if PlayerConnections[player] then
		for _, conn in ipairs(PlayerConnections[player]) do
			pcall(function()
				if conn and conn.Connected then
					conn:Disconnect()
				end
			end)
		end
		PlayerConnections[player] = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER EVENTS
-- ═══════════════════════════════════════════════════════════════

Players.PlayerAdded:Connect(function(player)
	ProfileStatus[player] = "loading"
	player:SetAttribute("ProfileStatus", "loading")

	notifyClient(player, "loading", "Loading your data...")

	local profile, err = loadProfileWithRetry(player)

	if not profile then
		ProfileStatus[player] = "failed"
		player:SetAttribute("ProfileStatus", "failed")
		notifyClient(player, "failed", "Failed to load your data after multiple attempts.")

		if KICK_ON_FAIL then
			task.delay(5, function()
				if player:IsDescendantOf(Players) and not PlayerProfiles[player] then
					player:Kick("Failed to load your data. Please rejoin. If this keeps happening, try again later.")
				end
			end)
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if type(profile.Data.SavedFish) ~= "table" then profile.Data.SavedFish = {} end
	if type(profile.Data.OwnedRods) ~= "table" then profile.Data.OwnedRods = {} end
	if type(profile.Data.TotalFishCaught) ~= "number" then profile.Data.TotalFishCaught = 0 end
	if type(profile.Data.UnknownFishCaught) ~= "number" then profile.Data.UnknownFishCaught = 0 end
	if type(profile.Data.QuestBoard) ~= "table" then
		profile.Data.QuestBoard = {
			CrystalKrakenCaught = 0,
			GlacierSerpentCaught = 0,
			RewardClaimed = false
		}
	end
	if type(profile.Data.RodUpgrades) ~= "table" then profile.Data.RodUpgrades = {} end

	if not profile.Data.FishInventoryLimit or profile.Data.FishInventoryLimit > MEMORY_SETTINGS.MAX_FISH_PER_PLAYER then
		profile.Data.FishInventoryLimit = MEMORY_SETTINGS.MAX_FISH_PER_PLAYER
	end

	PlayerProfiles[player] = profile
	ProfileStatus[player] = "ready"

	profile:ListenToRelease(function()
		PlayerProfiles[player] = nil
		ProfileStatus[player] = "released"
		player:SetAttribute("ProfileActive", false)
		player:SetAttribute("ProfileStatus", "released")
		notifyClient(player, "released", "Your session ended unexpectedly.")

		if RECOVERY_ENABLED and player:IsDescendantOf(Players) then
			task.delay(3, function()
				if player:IsDescendantOf(Players) and not PlayerProfiles[player] then
					GameProfileService:ForceReloadProfile(player)
				end
			end)
		end
	end)

	if not player:IsDescendantOf(Players) then
		profile:Release()
		PlayerProfiles[player] = nil
		ProfileStatus[player] = nil
		cleanupPlayerConnections(player)
		return
	end

	task.spawn(function()
		local maxWait = 10
		local startTime = os.clock()
		while (os.clock() - startTime) < maxWait do
			if player:FindFirstChild("DataLoaded") or player:FindFirstChild("leaderstats") then
				break
			end
			task.wait(0.3)
		end
		ensureCoinsAlias(player)
		profile.Data.Coins = CurrencyAdapter:Get(player) or 0
	end)

	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("ProfileActive", true)
	player:SetAttribute("ProfileStatus", "ready")

	notifyClient(player, "ready", "Data loaded!")

	GameProfileService.ProfileLoadedSignal:Fire(player)
	GameProfileService.ProfileReadySignal:Fire(player)

	task.delay(3, function()
		if player and player:IsDescendantOf(Players) and PlayerProfiles[player] then
			sendQuestUpdate(player)
		end
	end)

	task.delay(5, function()
		if player and player:IsDescendantOf(Players) and PlayerProfiles[player] then
			local size_mb = getProfileSize(PlayerProfiles[player])
			if size_mb > MEMORY_SETTINGS.PROFILE_SIZE_WARNING_MB then
				warn(string.format(
					"[FishData]: Large profile detected for %s: %.2f MB (%d fish)",
					player.Name,
					size_mb,
					#(PlayerProfiles[player].Data.SavedFish or {})
					))
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local profile = PlayerProfiles[player]

	cleanupPlayerConnections(player)

	ProfileStatus[player] = nil
	ForceReloadCooldowns[player.UserId] = nil

	if not profile then return end

	trimProfileBeforeSave(profile)

	profile.Data.Coins = CurrencyAdapter:Get(player) or 0

	pcall(function()
		profile:Release()
	end)

	PlayerProfiles[player] = nil
end)

-- Auto-save mirror + memory monitor (ProfileService has its own autosave;
-- this only refreshes the Coins mirror and trims oversized profiles).
task.spawn(function()
	while task.wait(300) do
		for _, player in ipairs(Players:GetPlayers()) do
			if player and player:IsDescendantOf(Players) then
				GameProfileService:SavePlayerData(player)
			end
		end

		local stats = GameProfileService:GetMemoryStats()

		if stats.total_data_mb > 100 then
			warn(string.format(
				"[FishData]: High profile data usage: %.2f MB across %d profiles",
				stats.total_data_mb,
				stats.total_profiles
				))

			GameProfileService:PrintMemoryReport()
		end

		if stats.total_data_mb > 200 then
			warn("[FishData]: Emergency cleanup triggered!")
			local removed = GameProfileService:CleanupAllProfiles()
			warn(string.format("[FishData]: Emergency cleanup removed %d fish total", removed))
		end
	end
end)

game:BindToClose(function()
	for _, conn in ipairs(ModuleConnections) do
		pcall(function()
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end)
	end

	for player, profile in pairs(PlayerProfiles) do
		if profile and profile:IsActive() then
			pcall(function()
				trimProfileBeforeSave(profile)
				profile.Data.Coins = CurrencyAdapter:Get(player) or 0
				profile:Release()
			end)
		end
		cleanupPlayerConnections(player)
	end

	task.wait(2)
end)

print("[FishData] Loaded (audit-fixed) — max fish:", MEMORY_SETTINGS.MAX_FISH_PER_PLAYER)

return GameProfileService
