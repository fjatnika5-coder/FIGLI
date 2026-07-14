--!strict
-- Lokasi: ServerScriptService/ACM_Backend_Stats
-- Likes, playtime, dan follower stats untuk Avatar Context Menu.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LikesDataStore = DataStoreService:GetDataStore("ACM_Likes_Data_v1")
local HistoryDataStore = DataStoreService:GetDataStore("ACM_Likes_History_v1")
local PlaytimeStore = DataStoreService:GetDataStore("ACM_Playtime_Data_v1")
local OldLikeStore = DataStoreService:GetDataStore("PlayerLikes")

local eventsFolder = ReplicatedStorage:FindFirstChild("EventsACMS") or Instance.new("Folder")
eventsFolder.Name = "EventsACMS"
eventsFolder.Parent = ReplicatedStorage

local getStatsFunc = eventsFolder:FindFirstChild("GetPlayerStats") or Instance.new("RemoteFunction")
getStatsFunc.Name = "GetPlayerStats"
getStatsFunc.Parent = eventsFolder

local likeEvent = eventsFolder:FindFirstChild("ToggleLike") or Instance.new("RemoteEvent")
likeEvent.Name = "ToggleLike"
likeEvent.Parent = eventsFolder

local notifEvent = eventsFolder:FindFirstChild("SendLikeNotification") or Instance.new("RemoteEvent")
notifEvent.Name = "SendLikeNotification"
notifEvent.Parent = eventsFolder

-- =========================
-- RATE LIMIT
-- =========================
local rateLimits: {[number]: {[string]: number}} = {}

local function canDoAction(userId: number, actionName: string, cooldown: number): boolean
	local bucket = rateLimits[userId]
	if not bucket then
		bucket = {}
		rateLimits[userId] = bucket
	end
	local now = os.clock()
	if (now - (bucket[actionName] or 0)) < cooldown then
		return false
	end
	bucket[actionName] = now
	return true
end

-- Debounce like per player (cegah proses ganda paralel)
local likeLocks: {[number]: boolean} = {}

-- =========================
-- FOLLOWER CACHE (kurangi HTTP call per buka panel)
-- =========================
local FOLLOWER_TTL_OK = 300
local FOLLOWER_TTL_FAIL = 60
local followerCache: {[number]: {time: number, count: number?}} = {}

local function pruneFollowerCache()
	local now = os.clock()
	for id, entry in pairs(followerCache) do
		if now - entry.time > FOLLOWER_TTL_OK then
			followerCache[id] = nil
		end
	end
end

local function getFollowerCount(targetUserId: number): number?
	local now = os.clock()
	local cached = followerCache[targetUserId]
	if cached then
		local ttl = if cached.count ~= nil then FOLLOWER_TTL_OK else FOLLOWER_TTL_FAIL
		if now - cached.time < ttl then
			return cached.count
		end
	end

	local count: number? = nil
	local url = "https://friends.roproxy.com/v1/users/" .. tostring(targetUserId) .. "/followers/count"
	local ok, body = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if ok then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, body)
		if decodeOk and typeof(decoded) == "table" and typeof((decoded :: any).count) == "number" then
			count = (decoded :: any).count
		end
	end

	followerCache[targetUserId] = { time = now, count = count }
	pruneFollowerCache()
	return count
end

-- =========================
-- PLAYTIME
-- =========================
local PLAYTIME_AUTOSAVE_SECONDS = 120

local function SavePlaytime(player: Player)
	local ls = player:FindFirstChild("leaderstats")
	local pt = ls and ls:FindFirstChild("Playtime")
	if not (pt and pt:IsA("IntValue")) then return end
	local value = pt.Value
	pcall(function()
		PlaytimeStore:SetAsync(tostring(player.UserId), value)
	end)
end

-- =========================
-- LEADERSTATS
-- =========================
local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local likes = Instance.new("IntValue")
	likes.Name = "Likes"
	likes.Value = 0
	likes.Parent = leaderstats

	local playtime = Instance.new("IntValue")
	playtime.Name = "Playtime"
	playtime.Value = 0
	playtime.Parent = leaderstats

	task.spawn(function()
		local success, savedLikes = pcall(function()
			return LikesDataStore:GetAsync(tostring(player.UserId))
		end)

		if success and typeof(savedLikes) == "number" then
			likes.Value = savedLikes
		else
			-- Migrasi dari store lama (sekali jalan per player)
			local s2, oldData = pcall(function()
				return OldLikeStore:GetAsync(tostring(player.UserId))
			end)
			if s2 and type(oldData) == "table" and (oldData :: any).Liked then
				likes.Value = tonumber((oldData :: any).Liked) or 0
				pcall(function()
					LikesDataStore:SetAsync(tostring(player.UserId), likes.Value)
				end)
			end
		end

		local s3, savedTime = pcall(function()
			return PlaytimeStore:GetAsync(tostring(player.UserId))
		end)
		if s3 and typeof(savedTime) == "number" then
			playtime.Value = savedTime
		end

		-- Autosave berkala supaya crash server tidak menghapus progress
		local sinceSave = 0
		while player.Parent do
			task.wait(1)
			playtime.Value += 1
			sinceSave += 1
			if sinceSave >= PLAYTIME_AUTOSAVE_SECONDS then
				sinceSave = 0
				task.spawn(SavePlaytime, player)
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupLeaderstats)

Players.PlayerRemoving:Connect(function(player)
	SavePlaytime(player)
	rateLimits[player.UserId] = nil
	likeLocks[player.UserId] = nil
end)

game:BindToClose(function()
	local threads = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(threads, task.spawn(function()
			SavePlaytime(p)
		end))
	end
	local deadline = os.clock() + 25
	for _, t in ipairs(threads) do
		while coroutine.status(t) ~= "dead" and os.clock() < deadline do
			task.wait(0.1)
		end
	end
end)

-- =========================
-- VALIDASI
-- =========================
local function isValidUserId(id: any): boolean
	return typeof(id) == "number"
		and id > 0
		and id == math.floor(id)
		and id < 1e15
end

-- =========================
-- GET STATS
-- Return nil kalau invalid/rate-limited; client pertahankan cache lama.
-- =========================
getStatsFunc.OnServerInvoke = function(player: Player, targetUserId: any)
	if not isValidUserId(targetUserId) then return nil end
	if not canDoAction(player.UserId, "GetStats", 2.0) then return nil end

	local stats = {
		followers = "N/A" :: any,
		likes = 0,
		hasLiked = false,
	}

	local followers = getFollowerCount(targetUserId :: number)
	if followers ~= nil then
		stats.followers = followers
	end

	local target = Players:GetPlayerByUserId(targetUserId)
	local leaderstats = target and target:FindFirstChild("leaderstats")
	local likesVal = leaderstats and leaderstats:FindFirstChild("Likes")
	if likesVal and likesVal:IsA("IntValue") then
		stats.likes = likesVal.Value
	else
		local s2, v = pcall(function()
			return LikesDataStore:GetAsync(tostring(targetUserId))
		end)
		if s2 and typeof(v) == "number" then
			stats.likes = v
		end
	end

	local key = player.UserId .. "_" .. targetUserId
	local s3, liked = pcall(function()
		return HistoryDataStore:GetAsync(key)
	end)
	if s3 then
		stats.hasLiked = liked == true
	end

	return stats
end

-- =========================
-- LIKE TOGGLE
-- Konsistensi: history adalah sumber kebenaran status like.
-- Kalau increment gagal setelah history berubah, history di-rollback.
-- =========================
likeEvent.OnServerEvent:Connect(function(player: Player, targetUserId: any)
	if not isValidUserId(targetUserId) then return end
	if player.UserId == targetUserId then return end
	if not canDoAction(player.UserId, "ToggleLike", 3.0) then return end
	if likeLocks[player.UserId] then return end
	likeLocks[player.UserId] = true

	local ok, err = pcall(function()
		local historyKey = player.UserId .. "_" .. targetUserId
		local target = Players:GetPlayerByUserId(targetUserId)

		local s, hasLiked = pcall(function()
			return HistoryDataStore:GetAsync(historyKey)
		end)
		if not s then
			warn("[LikeSystem] GetAsync failed for", historyKey)
			return
		end

		local function bumpLeaderstats(delta: number)
			if not (target and target.Parent) then return end
			local ls = target:FindFirstChild("leaderstats")
			local likesVal = ls and ls:FindFirstChild("Likes")
			if likesVal and likesVal:IsA("IntValue") then
				likesVal.Value = math.max(0, likesVal.Value + delta)
			end
		end

		if hasLiked then
			local removeOk = pcall(function()
				HistoryDataStore:RemoveAsync(historyKey)
			end)
			if not removeOk then return end

			local decOk = pcall(function()
				LikesDataStore:IncrementAsync(tostring(targetUserId), -1)
			end)
			if not decOk then
				pcall(function()
					HistoryDataStore:SetAsync(historyKey, true)
				end)
				return
			end
			bumpLeaderstats(-1)
		else
			local setOk = pcall(function()
				HistoryDataStore:SetAsync(historyKey, true)
			end)
			if not setOk then return end

			local incOk = pcall(function()
				LikesDataStore:IncrementAsync(tostring(targetUserId), 1)
			end)
			if not incOk then
				pcall(function()
					HistoryDataStore:RemoveAsync(historyKey)
				end)
				return
			end
			bumpLeaderstats(1)

			if target and target.Parent then
				pcall(function()
					notifEvent:FireClient(target, player.DisplayName)
				end)
			end
		end
	end)

	likeLocks[player.UserId] = nil
	if not ok then
		warn("[LikeSystem] ToggleLike error for", player.Name, err)
	end
end)
