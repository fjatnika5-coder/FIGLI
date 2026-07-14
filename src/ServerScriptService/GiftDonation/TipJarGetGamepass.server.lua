--!strict
-- Lokasi: ServerScriptService/GiftDonation/TipJarGetGamepass
-- Fetch daftar gamepass milik target (via roproxy) + isi whitelist registry.

local Players             = game:GetService("Players")
local HttpService         = game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local GetGamePasses = RemotesFolder:WaitForChild("GetGamePasses") :: RemoteEvent

local GamepassRegistry = require(ServerScriptService:WaitForChild("GiftDonation"):WaitForChild("GamepassRegistry"))

----------------------------------------------------------------
-- Types & Cache
----------------------------------------------------------------
export type GamePassSummary = {
	id: number,
	name: string,
	price: number,
}

local lastRequest: {[number]: number} = {}

type CacheEntry = {
	time: number,
	passes: {GamePassSummary},
}

local gamepassCache: {[number]: CacheEntry} = {}
local CACHE_TTL = 60

----------------------------------------------------------------
-- Helper: semua game publik milik user
----------------------------------------------------------------
local function getAllUserGames(userId: number): {number}
	local allGames: {number} = {}
	local cursor = ""
	local maxPages = 10
	local pages = 0

	repeat
		pages += 1
		if pages > maxPages then break end

		local url = ("https://games.roproxy.com/v2/users/%s/games?accessFilter=Public&sortOrder=Asc&limit=50&cursor=%s")
			:format(userId, cursor)

		local success, result = pcall(function()
			return HttpService:GetAsync(url)
		end)

		if not success or not result then
			warn("[GetGames] Failed for user:", userId)
			break
		end

		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(result)
		end)

		if not ok or typeof(decoded) ~= "table" then
			warn("[GetGames] JSON decode failed for user:", userId)
			break
		end

		local data = (decoded :: any).data
		if typeof(data) == "table" then
			for _, gameData in ipairs(data) do
				local id = (gameData :: any).id
				if typeof(id) == "number" then
					table.insert(allGames, id)
				end
			end
		end

		local nextCursor = (decoded :: any).nextPageCursor
		if nextCursor == nil or nextCursor == "" then
			cursor = ""
		else
			cursor = tostring(nextCursor)
		end
	until cursor == ""

	return allGames
end

----------------------------------------------------------------
-- Gamepass per universe (roproxy)
----------------------------------------------------------------
local function getGamepassesForGame(universeId: number): {GamePassSummary}
	local gamepasses: {GamePassSummary} = {}

	local url = ("https://apis.roproxy.com/game-passes/v1/universes/%s/game-passes"):format(universeId)

	local success, result = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if not success or not result then
		warn("[Gamepasses] Failed for universe:", universeId)
		return gamepasses
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(result)
	end)

	if not ok or typeof(data) ~= "table" then
		return gamepasses
	end

	local passes = (data :: any).gamePasses
	if typeof(passes) ~= "table" then
		return gamepasses
	end

	for _, pass in ipairs(passes) do
		local p = pass :: any
		local id = p.id or p.gamePassId
		local name = p.name or "Unnamed Pass"
		local price = p.price or 0

		if typeof(id) == "number" then
			table.insert(gamepasses, {
				id = id,
				name = tostring(name),
				price = tonumber(price) or 0,
			})
		end
	end

	return gamepasses
end

----------------------------------------------------------------
-- Handler: terima userId (number); Player instance masih didukung
-- untuk kompatibilitas client lama, tapi divalidasi server-side.
----------------------------------------------------------------
GetGamePasses.OnServerEvent:Connect(function(sender: Player, targetUserId: any)
	if not sender or not sender.Parent then return end

	local now = os.clock()
	local last = lastRequest[sender.UserId] or 0
	if now - last < 3 then return end
	lastRequest[sender.UserId] = now

	local userId: number

	if typeof(targetUserId) == "number" then
		userId = targetUserId
	elseif typeof(targetUserId) == "Instance" and targetUserId:IsA("Player") then
		local targetPlayer = Players:GetPlayerByUserId(targetUserId.UserId)
		if not targetPlayer then return end
		userId = targetPlayer.UserId
	else
		userId = sender.UserId
	end

	local targetPlayer = Players:GetPlayerByUserId(userId)
	if not targetPlayer then
		warn("[GetGamePasses] Target userId", userId, "not in game")
		return
	end

	-- 1) Cache dulu
	local cache = gamepassCache[userId]
	if cache and (now - cache.time) < CACHE_TTL then
		GamepassRegistry.SetForUser(userId, cache.passes)
		GetGamePasses:FireClient(sender, targetPlayer, cache.passes)
		return
	end

	-- 2) HTTP fetch
	local allGamepasses: {GamePassSummary} = {}

	local games = getAllUserGames(userId)
	for _, universeId in ipairs(games) do
		local passes = getGamepassesForGame(universeId)
		for _, pass in ipairs(passes) do
			table.insert(allGamepasses, pass)
		end
	end

	-- Sender/target bisa keluar selama HTTP jalan
	if not sender.Parent then return end
	if not targetPlayer.Parent then return end

	-- 3) Cache & whitelist
	gamepassCache[userId] = {
		time = now,
		passes = allGamepasses,
	}

	GamepassRegistry.SetForUser(userId, allGamepasses)
	GetGamePasses:FireClient(sender, targetPlayer, allGamepasses)
end)

----------------------------------------------------------------
-- Cleanup saat player keluar
----------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	gamepassCache[player.UserId] = nil
	lastRequest[player.UserId] = nil
	GamepassRegistry.ClearUser(player.UserId)
end)
