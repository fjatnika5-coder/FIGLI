--!nonstrict
-- PhotoStoryTrigger: deteksi dua player berdiri di pad, lalu minta server memulai.
-- Pakai Touched/TouchEnded (tanpa loop permanen). Validasi pasangan ada di server.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("PhotoStoryConfig"))
local PairRequest = ServerScriptService:WaitForChild("PhotoStoryPairRequest")

local COOLDOWN = 5

local pad = Workspace:WaitForChild(Config.PadPartName, 30)
if not pad then
	warn("[PhotoStory] Pad '" .. tostring(Config.PadPartName) .. "' tidak ditemukan di Workspace")
	return
end

-- Hitung berapa banyak part tiap player yang menyentuh pad.
local occupancy = {} -- [Player] = count
local lastTrigger = 0

local function playerFromPart(part)
	local character = part and part.Parent
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function tryTrigger()
	if os.clock() - lastTrigger < COOLDOWN then
		return
	end
	-- Ambil dua player berbeda yang sedang di pad.
	local present = {}
	for player, count in pairs(occupancy) do
		if count > 0 and player.Parent then
			present[#present + 1] = player
		end
	end
	if #present >= 2 then
		lastTrigger = os.clock()
		PairRequest:Fire(present[1], present[2])
	end
end

pad.Touched:Connect(function(part)
	local player = playerFromPart(part)
	if not player then
		return
	end
	occupancy[player] = (occupancy[player] or 0) + 1
	tryTrigger()
end)

pad.TouchEnded:Connect(function(part)
	local player = playerFromPart(part)
	if not player then
		return
	end
	local count = (occupancy[player] or 0) - 1
	if count <= 0 then
		occupancy[player] = nil
	else
		occupancy[player] = count
	end
end)

Players.PlayerRemoving:Connect(function(player)
	occupancy[player] = nil
end)
