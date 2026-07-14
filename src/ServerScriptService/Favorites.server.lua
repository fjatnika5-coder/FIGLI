-- Lokasi: ServerScriptService/Favorites
-- Persist favorit animasi per player (anti throttle + ID standardize).
-- Aturan keamanan data: kalau load GAGAL, sesi ini TIDAK menyimpan apa pun
-- untuk player itu — mencegah data favorit lama tertimpa map kosong.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

-- === Config ===
local STORE_NAME           = "AnimationFavorites_v1"
local KEY_PREFIX           = "animFavs_v1_"
local AUTOSAVE_INTERVAL    = 30
local DEBOUNCE_SAVE_DELAY  = 2
local MAX_RETRIES          = 6
local MAX_FAVORITES        = 500
local DEBUG                = false

-- === Remotes ===
local Events = ReplicatedStorage:FindFirstChild("EventsACMS")
if not Events then
	Events        = Instance.new("Folder")
	Events.Name   = "EventsACMS"
	Events.Parent = ReplicatedStorage
end

local FavoritesGet = Events:FindFirstChild("FavoritesGet")
if not FavoritesGet or not FavoritesGet:IsA("RemoteFunction") then
	if FavoritesGet then FavoritesGet:Destroy() end
	FavoritesGet        = Instance.new("RemoteFunction")
	FavoritesGet.Name   = "FavoritesGet"
	FavoritesGet.Parent = Events
end

local FavoritesSet = Events:FindFirstChild("FavoritesSet")
if not FavoritesSet or not FavoritesSet:IsA("RemoteEvent") then
	if FavoritesSet then FavoritesSet:Destroy() end
	FavoritesSet        = Instance.new("RemoteEvent")
	FavoritesSet.Name   = "FavoritesSet"
	FavoritesSet.Parent = Events
end

-- === Whitelist animId ===
local Shared     = ReplicatedStorage:WaitForChild("Shared")
local Animations = require(Shared:WaitForChild("Animations"))
local Poses      = require(Shared:WaitForChild("Poses"))

local function stdId(id: any): string?
	if typeof(id) ~= "string" then return nil end
	local num = string.match(id, "%d+")
	if not num then return nil end
	return "rbxassetid://" .. num
end

local allowedIds: {[string]: true} = {}
local function addAllowed(list)
	for _, item in ipairs(list) do
		local s = stdId(item.animationId)
		if s then allowedIds[s] = true end
	end
end
addAllowed(Animations)
addAllowed(Poses)

-- === DataStore utils ===
local STORE = DataStoreService:GetDataStore(STORE_NAME)

local function waitBudget(rt: Enum.DataStoreRequestType, need: number)
	while DataStoreService:GetRequestBudgetForRequestType(rt) < need do
		task.wait(0.1)
	end
end

local function keyFor(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

local function mapToList(map: {[string]: boolean}): {string}
	local list = {}
	for id, v in pairs(map) do
		if v then table.insert(list, id) end
	end
	return list
end

local function listToMap(payload: any): {[string]: boolean}
	local map: {[string]: boolean} = {}
	if type(payload) ~= "table" then return map end
	if #payload > 0 then
		-- array (format baru)
		for _, id in ipairs(payload) do
			if type(id) == "string" then map[id] = true end
		end
	else
		-- dictionary (format lama)
		for id, v in pairs(payload) do
			if type(id) == "string" and v == true then map[id] = true end
		end
	end
	return map
end

local function countMap(m: {[string]: boolean}): number
	local n = 0
	for _ in pairs(m) do n += 1 end
	return n
end

-- === Cache & State ===
local cache:   {[number]: {[string]: boolean}} = {}
local dirty:   {[number]: boolean}             = {}
local version: {[number]: number}              = {}

-- true = load DataStore sukses; false/nil = jangan pernah save sesi ini
local loadOk: {[number]: boolean} = {}

-- Loading lock: cegah load ganda concurrent per userId.
-- Nilai: thread yang sedang load, atau true kalau sudah selesai.
local loadLock: {[number]: thread | boolean} = {}

local isShuttingDown = false
local savingOnShutdown: {[number]: boolean} = {}

-- === Load & Save ===

local function ensureLoaded(userId: number): {[string]: boolean}
	if cache[userId] then return cache[userId] end

	local lock = loadLock[userId]
	if lock and type(lock) == "thread" then
		local waited = 0
		while loadLock[userId] and type(loadLock[userId]) == "thread" do
			task.wait(0.05)
			waited += 0.05
			if waited >= 10 then break end
		end
		if cache[userId] then return cache[userId] end
	end

	loadLock[userId] = coroutine.running()

	local ok, data = false, nil
	for attempt = 1, 3 do
		waitBudget(Enum.DataStoreRequestType.GetAsync, 1)
		ok, data = pcall(function()
			return STORE:GetAsync(keyFor(userId))
		end)
		if ok then break end
		task.wait(attempt)
	end

	local map = listToMap(ok and data or {})
	cache[userId]    = map
	loadOk[userId]   = ok == true
	loadLock[userId] = true

	if not ok then
		warn("[Favorites] Load failed for", userId, "- favorit read-only sesi ini")
	end

	-- Player keburu keluar saat load berjalan: buang entry supaya tidak leak
	if not Players:GetPlayerByUserId(userId) then
		cache[userId]    = nil
		dirty[userId]    = nil
		loadOk[userId]   = nil
		loadLock[userId] = nil
	end

	return map
end

local function save(userId: number, reason: string?)
	if not dirty[userId] then return end
	if not loadOk[userId] then
		warn("[Favorites] Skip save (load failed) for", userId)
		return
	end

	local map     = cache[userId] or {}
	local payload = mapToList(map)

	local tries, ok, err = 0, false, nil
	repeat
		tries += 1
		waitBudget(Enum.DataStoreRequestType.UpdateAsync, 1)
		ok, err = pcall(function()
			STORE:UpdateAsync(keyFor(userId), function(_old)
				return payload
			end)
		end)
		if not ok then
			local backoff = (2 ^ math.min(tries, 6)) * 0.1
			task.wait(backoff)
		end
	until ok or tries >= MAX_RETRIES

	if ok then
		dirty[userId] = nil
		if DEBUG then
			print(("[Favorites] Saved %d items for %d (%s)"):format(#payload, userId, tostring(reason)))
		end
	else
		warn(("[Favorites] Save FAILED for %d (%s): %s"):format(userId, tostring(reason), tostring(err)))
	end
end

-- === Player Lifecycle ===

Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		ensureLoaded(plr.UserId)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	local userId = plr.UserId

	if savingOnShutdown[userId] then
		cache[userId]            = nil
		dirty[userId]            = nil
		version[userId]          = nil
		loadOk[userId]           = nil
		loadLock[userId]         = nil
		savingOnShutdown[userId] = nil
		return
	end

	save(userId, "PlayerRemoving")
	cache[userId]    = nil
	dirty[userId]    = nil
	version[userId]  = nil
	loadOk[userId]   = nil
	loadLock[userId] = nil
end)

game:BindToClose(function()
	isShuttingDown = true

	local threads = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local userId = plr.UserId
		if dirty[userId] and loadOk[userId] then
			savingOnShutdown[userId] = true
			local t = task.spawn(function()
				save(userId, "Shutdown")
			end)
			table.insert(threads, t)
		end
	end

	local deadline = os.clock() + 25
	local allDone = false
	while not allDone and os.clock() < deadline do
		allDone = true
		for _, t in ipairs(threads) do
			if coroutine.status(t) ~= "dead" then
				allDone = false
				break
			end
		end
		if not allDone then task.wait(0.1) end
	end
end)

local function autoSaveLoop()
	if isShuttingDown then return end

	for userId in pairs(dirty) do
		if not savingOnShutdown[userId] then
			save(userId, "AutoSave")
		end
	end

	task.delay(AUTOSAVE_INTERVAL, autoSaveLoop)
end

task.delay(AUTOSAVE_INTERVAL, autoSaveLoop)

-- === RPC ===

FavoritesGet.OnServerInvoke = function(plr)
	return ensureLoaded(plr.UserId)
end

FavoritesSet.OnServerEvent:Connect(function(plr, animId: string, isFav: boolean)
	local sid = stdId(animId)
	if not sid then return end
	if not allowedIds[sid] then return end

	local map = ensureLoaded(plr.UserId)

	-- Load gagal → tolak perubahan; kalau diterima lalu disave, data lama hilang
	if not loadOk[plr.UserId] then return end

	if isFav then
		if not map[sid] and countMap(map) >= MAX_FAVORITES then return end
		map[sid] = true
	else
		map[sid] = nil
	end

	cache[plr.UserId] = map
	dirty[plr.UserId] = true

	-- Debounce save: save hanya kalau tidak ada perubahan baru dalam N detik
	version[plr.UserId] = (version[plr.UserId] or 0) + 1
	local my = version[plr.UserId]
	task.delay(DEBOUNCE_SAVE_DELAY, function()
		if isShuttingDown then return end
		if version[plr.UserId] == my and dirty[plr.UserId] then
			save(plr.UserId, "Debounced")
		end
	end)
end)
