-- AdminRodManager_Server
-- Location: ServerScriptService/AdminRodManager_Server (Script)
--
-- AUDIT FIX:
-- [FIX K] AddRod/RemoveRod now go through GameProfileService (FishData) as the
--         primary path. FishData:AddRod also un-blacklists via RodInventory and
--         FishData:RemoveRod also blacklists + destroys the tool, so admin
--         grants/removals are consistent across BOTH ownership stores. The old
--         version only touched RodInventory, so a rod stored in FishData
--         profile data kept coming back on respawn after an admin "remove".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ═════════════════════════════════════════════
-- CONFIG
-- ═════════════════════════════════════════════

local OWNER_NAMES = {
	"Duwataw",
}

local ALL_RODS = {
	"EvacoreRod", "PhantomRod", "LoveRod", "Rod Of The Eternal King",
	"RedShawdowRod", "ButterflyRod", "FlutterRod", "BloodmoonRod",
	"AuraluxRod", "UmbraluxRod", "Crescendo Scythe", "CryoStromRod",
	"DreadspireRod", "FrostwindRod", "Aqua Rod", "GundamAstraRod",
	"x1x1x1 Hammer", "GundamRod", "Fabulous Rod", "LightingRod",
	"DiamondRod", "Celestial Blossom Rod", "AdminRod", "OwnerRod",
	"FrozenkRod", "LavaRod", "FrozenRod", "Slash Katana",
	"Royal Spider", "Cherryna", "Esteh", "Jiyuu", "Jiyu",
	"Youkatta", "Nine", "Gulabatu", "Mei", "Vin",
	"AscensionRod", "OblivonRod", "Princess Parasol",
	"Wings of Everlove", "Aether Monarch", "Aurelian Rod",
	"Cupid Harp", "Kyouyariin", "Blackhole Sword",
	"Eternal Flower", "The Vanquisher", "Solitario", "Soya", "PASEP",
	"Ceisya", "Little", "Miyuki",
}

table.sort(ALL_RODS)

local VALID_ROD_SET = {}
for _, rodName in ipairs(ALL_RODS) do
	VALID_ROD_SET[rodName] = true
end

-- ═════════════════════════════════════════════
-- LOAD GAMEPROFILESERVICE
-- ═════════════════════════════════════════════

local GameProfileService = nil
pcall(function()
	GameProfileService = require(ServerScriptService.Data.PetCore:WaitForChild("FishData"))
end)

-- ═════════════════════════════════════════════
-- REMOTES
-- ═════════════════════════════════════════════

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")

local AdminRemotes = FishingSystem:FindFirstChild("AdminRemotes")
if not AdminRemotes then
	AdminRemotes = Instance.new("Folder")
	AdminRemotes.Name = "AdminRemotes"
	AdminRemotes.Parent = FishingSystem
end

local function getOrCreate(className, name, parent)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local ToggleUI      = getOrCreate("RemoteEvent",    "ToggleAdminRodUI", AdminRemotes)
local GetPlayerList = getOrCreate("RemoteFunction", "GetPlayerList",    AdminRemotes)
local GetPlayerRods = getOrCreate("RemoteFunction", "GetPlayerRods",    AdminRemotes)
local AddRod        = getOrCreate("RemoteFunction", "AddRod",           AdminRemotes)
local RemoveRod     = getOrCreate("RemoteFunction", "RemoveRod",        AdminRemotes)
local GetAllRods    = getOrCreate("RemoteFunction", "GetAllRods",       AdminRemotes)

-- ═════════════════════════════════════════════
-- HELPERS
-- ═════════════════════════════════════════════

local function isOwner(player)
	for _, n in ipairs(OWNER_NAMES) do
		if player.Name == n then return true end
	end
	return false
end

local function getAllOwnedRods(player)
	local blacklistSet = {}
	if _G.RodInventory_GetBlacklist then
		local ok, bl = pcall(_G.RodInventory_GetBlacklist, player)
		if ok and type(bl) == "table" then
			for _, r in ipairs(bl) do
				blacklistSet[r] = true
			end
		end
	end

	local rodSet = {}

	-- Source 1: GameProfileService (already blacklist-filtered, tapi tetap
	-- di-set-kan untuk dedup dengan source 2)
	if GameProfileService and type(GameProfileService.GetOwnedRods) == "function" then
		local ok, rods = pcall(function()
			return GameProfileService:GetOwnedRods(player)
		end)
		if ok and type(rods) == "table" then
			for _, r in ipairs(rods) do
				if not blacklistSet[r] then
					rodSet[r] = true
				end
			end
		end
	end

	-- Source 2: RodInventory
	if _G.RodInventory_GetOwned then
		local ok, rods = pcall(function()
			return _G.RodInventory_GetOwned(player)
		end)
		if ok and type(rods) == "table" then
			for _, r in ipairs(rods) do
				if not blacklistSet[r] then
					rodSet[r] = true
				end
			end
		end
	end

	local result = {}
	for rodName in pairs(rodSet) do
		table.insert(result, rodName)
	end
	table.sort(result)
	return result
end

-- ═════════════════════════════════════════════
-- REMOTE HANDLERS
-- ═════════════════════════════════════════════

GetPlayerList.OnServerInvoke = function(requester)
	if not isOwner(requester) then return {} end

	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			name = p.Name,
			displayName = p.DisplayName,
			userId = p.UserId,
		})
	end
	return list
end

GetAllRods.OnServerInvoke = function(requester)
	if not isOwner(requester) then return {} end
	return ALL_RODS
end

GetPlayerRods.OnServerInvoke = function(requester, targetName)
	if not isOwner(requester) then return {} end
	if typeof(targetName) ~= "string" then return {} end

	local target = Players:FindFirstChild(targetName)
	if not target then return {} end

	return getAllOwnedRods(target)
end

AddRod.OnServerInvoke = function(requester, targetName, rodName)
	if not isOwner(requester) then return false, "No permission" end
	if typeof(targetName) ~= "string" or typeof(rodName) ~= "string" then
		return false, "Invalid arguments"
	end

	local target = Players:FindFirstChild(targetName)
	if not target then return false, "Player not found" end
	if not VALID_ROD_SET[rodName] then return false, "Invalid rod" end

	-- [FIX K] Primary: FishData (syncs RodInventory + clears blacklist inside).
	if GameProfileService and type(GameProfileService.AddRod) == "function" then
		local ok, result = pcall(function()
			return GameProfileService:AddRod(target, rodName)
		end)
		if ok and result then
			return true, "Added"
		end
	end

	-- Fallback: RodInventory only.
	if _G.RodInventory_AddOwned then
		local ok = pcall(_G.RodInventory_AddOwned, target, rodName)
		if ok then
			return true, "Added"
		end
	end

	return false, "Failed"
end

RemoveRod.OnServerInvoke = function(requester, targetName, rodName)
	if not isOwner(requester) then return false, "No permission" end
	if typeof(targetName) ~= "string" or typeof(rodName) ~= "string" then
		return false, "Invalid arguments"
	end

	local target = Players:FindFirstChild(targetName)
	if not target then return false, "Player not found" end

	-- [FIX K] Primary: FishData (removes profile entry + blacklists via
	-- RodInventory + destroys the tool).
	if GameProfileService and type(GameProfileService.RemoveRod) == "function" then
		local ok, result = pcall(function()
			return GameProfileService:RemoveRod(target, rodName)
		end)
		if ok and result then
			return true, "Removed"
		end
	end

	-- Fallback: RodInventory only.
	if _G.RodInventory_RemoveOwned then
		local ok, result = pcall(function()
			return _G.RodInventory_RemoveOwned(target, rodName)
		end)
		if ok and result then
			return true, "Removed"
		end
	end

	return false, "Failed"
end

-- ═════════════════════════════════════════════
-- CHAT COMMAND
-- ═════════════════════════════════════════════

local function onChat(player, msg)
	if not isOwner(player) then return end

	local lower = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if lower == "!inv" or lower == "!rod" or lower == "!rods" then
		ToggleUI:FireClient(player)
	end
end

Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg) onChat(p, msg) end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	p.Chatted:Connect(function(msg) onChat(p, msg) end)
end
