--!strict
-- Lokasi: ServerScriptService/GiftDonation/TipJarCoreServer
-- Donasi via gamepass: validasi whitelist + creator match, data Donated/Raised.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local DataStoreService    = game:GetService("DataStoreService")
local TweenService        = game:GetService("TweenService")
local MarketplaceService  = game:GetService("MarketplaceService")
local ServerScriptService = game:GetService("ServerScriptService")

local GamepassRegistry      = require(ServerScriptService:WaitForChild("GiftDonation"):WaitForChild("GamepassRegistry"))
local ENFORCE_CREATOR_MATCH = true

local RemotesFolder     = ReplicatedStorage:WaitForChild("Remotes")
local ChatMessageRemote = RemotesFolder:WaitForChild("ChatMessage") :: RemoteEvent

local RequestDonationRemote = RemotesFolder:FindFirstChild("RequestDonation") :: RemoteEvent?
if not RequestDonationRemote then
	RequestDonationRemote        = Instance.new("RemoteEvent")
	RequestDonationRemote.Name   = "RequestDonation"
	RequestDonationRemote.Parent = RemotesFolder
end

local DonateRobuxRemote = RemotesFolder:FindFirstChild("DonateRobux") :: RemoteEvent?
if not DonateRobuxRemote then
	DonateRobuxRemote        = Instance.new("RemoteEvent")
	DonateRobuxRemote.Name   = "DonateRobux"
	DonateRobuxRemote.Parent = RemotesFolder
end

local database           = DataStoreService:GetDataStore("DonatedRaised")
local GlobalRaisedStore  = DataStoreService:GetOrderedDataStore("TipJar_Global_Raised")
local GlobalDonatedStore = DataStoreService:GetOrderedDataStore("TipJar_Global_Donated")

type DonateData = { Donated: number, Raised: number }
local sessionData: {[number]: DonateData} = {}

-- Player yang datanya masih loading tapi sudah menerima/memberi donasi:
-- delta ditampung di sessionData lalu di-MERGE oleh loader (bukan ditimpa).
local dataLoaded: {[number]: boolean} = {}

type PendingDonation = { targetUserId: number, gamePassId: number, amount: number }
local pendingDonations: {[number]: PendingDonation} = {}
local requestCooldown:  {[number]: number}          = {}

local GLOBAL_SAVE_INTERVAL = 120
local GLOBAL_MIN_DELTA     = 50

local lastSavedRaised:  {[number]: {time: number, value: number}} = {}
local lastSavedDonated: {[number]: {time: number, value: number}} = {}

local savingOnShutdown: {[number]: boolean} = {}
local isShuttingDown                        = false

----------------------------------------------------------------
-- Global Save Queue
-- Key pakai prefix eksplisit ("raised"/"donated"), BUKAN tostring(store):
-- tostring pada DataStore object tidak dijamin unik per store → key bisa
-- tabrakan dan salah satu save hilang.
----------------------------------------------------------------
local globalSaveQueue: {[string]: {store: OrderedDataStore, userId: number, value: number}} = {}

local function queueGlobalSave(
	store:      OrderedDataStore,
	cacheTable: {[number]: {time: number, value: number}},
	userId:     number,
	newValue:   number,
	keyPrefix:  string
)
	local now  = os.clock()
	local last = cacheTable[userId]

	if last then
		local timeDiff  = now - last.time
		local valueDiff = math.abs(last.value - newValue)
		if timeDiff < GLOBAL_SAVE_INTERVAL and valueDiff < GLOBAL_MIN_DELTA then
			return
		end
	end

	cacheTable[userId] = { time = now, value = newValue }

	local storeKey = keyPrefix .. "_" .. tostring(userId)
	globalSaveQueue[storeKey] = { store = store, userId = userId, value = newValue }
end

local function flushGlobalQueue(): number
	local keys: {string} = {}
	for key in pairs(globalSaveQueue) do
		table.insert(keys, key)
	end

	local flushed = 0
	for _, key in ipairs(keys) do
		local entry = globalSaveQueue[key]
		if not entry then continue end
		globalSaveQueue[key] = nil

		local waitTime = 2
		for attempt = 1, 3 do
			local ok, err = pcall(function()
				entry.store:SetAsync(tostring(entry.userId), entry.value)
			end)
			if ok then
				flushed += 1
				break
			end
			warn("[TipJar] Global save attempt", attempt, "failed:", err)
			task.wait(waitTime)
			waitTime = waitTime * 2
		end
	end

	return flushed
end

task.spawn(function()
	while not isShuttingDown do
		task.wait(GLOBAL_SAVE_INTERVAL)
		if not isShuttingDown then
			flushGlobalQueue()
		end
	end
end)

----------------------------------------------------------------
-- Load / Save Player Data
----------------------------------------------------------------
local loadQueue:         {Player} = {}
local isProcessingQueue           = false

local function processLoadQueue()
	if isProcessingQueue then return end
	isProcessingQueue = true

	task.spawn(function()
		while #loadQueue > 0 do
			local player = table.remove(loadQueue, 1)
			if player and player.Parent then
				local raisedValue  = Instance.new("NumberValue")
				raisedValue.Name   = "Raised"
				raisedValue.Value  = 0
				raisedValue.Parent = player

				local donatedValue  = Instance.new("NumberValue")
				donatedValue.Name   = "Donated"
				donatedValue.Value  = 0
				donatedValue.Parent = player

				local success    = false
				local playerData: DonateData? = nil
				local waitTime   = 2

				for attempt = 1, 5 do
					success, playerData = pcall(function()
						local stored = database:GetAsync(player.UserId)
						if typeof(stored) == "table" then
							local d = stored :: any
							return {
								Donated = tonumber(d.Donated) or 0,
								Raised  = tonumber(d.Raised)  or 0,
							}
						end
						return { Donated = 0, Raised = 0 }
					end)

					if success then break end
					warn("[TipJar] Load attempt", attempt, "failed for", player.Name)
					task.wait(waitTime)
					waitTime = waitTime * 2
				end

				if not player.Parent then continue end

				if not success or not playerData then
					player:Kick("Data load failed. Try again later.")
				else
					-- Merge delta donasi yang terjadi SEBELUM load selesai
					-- (applyDonation bisa jalan duluan saat pembelian cepat)
					local pendingDelta = sessionData[player.UserId]
					if pendingDelta then
						playerData.Donated += pendingDelta.Donated
						playerData.Raised  += pendingDelta.Raised
					end

					sessionData[player.UserId] = playerData
					dataLoaded[player.UserId]  = true
					donatedValue.Value         = playerData.Donated
					raisedValue.Value          = playerData.Raised

					if playerData.Raised > 0 then
						queueGlobalSave(GlobalRaisedStore, lastSavedRaised, player.UserId, playerData.Raised, "raised")
					end
					if playerData.Donated > 0 then
						queueGlobalSave(GlobalDonatedStore, lastSavedDonated, player.UserId, playerData.Donated, "donated")
					end

					donatedValue.Changed:Connect(function()
						local data = sessionData[player.UserId]
						if data then data.Donated = donatedValue.Value end
					end)

					raisedValue.Changed:Connect(function()
						local data = sessionData[player.UserId]
						if data then data.Raised = raisedValue.Value end
					end)
				end
			end

			if #loadQueue > 0 then
				task.wait(0.5)
			end
		end

		isProcessingQueue = false

		if #loadQueue > 0 then
			processLoadQueue()
		end
	end)
end

local function loadPlayerData(player: Player)
	table.insert(loadQueue, player)
	processLoadQueue()
end

local function savePlayerData(player: Player, isLeaving: boolean?)
	local data = sessionData[player.UserId]
	if not data then return end

	-- Data belum pernah sukses load → jangan tulis (bisa menimpa nilai asli
	-- dengan delta parsial). Delta gamepass tetap aman: purchase tercatat Roblox.
	if not dataLoaded[player.UserId] then
		warn("[TipJar] Skip save (data not loaded) for", player.Name)
	else
		local success  = false
		local waitTime = 2
		for attempt = 1, 5 do
			success = pcall(function()
				database:SetAsync(player.UserId, data)
			end)
			if success then break end
			warn("[TipJar] Save attempt", attempt, "failed for", player.Name)
			task.wait(waitTime)
			waitTime = waitTime * 2
		end

		if isLeaving == true then
			if data.Raised > 0 then
				pcall(function()
					GlobalRaisedStore:SetAsync(tostring(player.UserId), data.Raised)
				end)
			end
			if data.Donated > 0 then
				pcall(function()
					GlobalDonatedStore:SetAsync(tostring(player.UserId), data.Donated)
				end)
			end
		end
	end

	if isLeaving == true then
		sessionData[player.UserId]      = nil
		dataLoaded[player.UserId]       = nil
		pendingDonations[player.UserId] = nil
		requestCooldown[player.UserId]  = nil
		lastSavedRaised[player.UserId]  = nil
		lastSavedDonated[player.UserId] = nil
		savingOnShutdown[player.UserId] = nil
	end
end

Players.PlayerAdded:Connect(loadPlayerData)

Players.PlayerRemoving:Connect(function(player)
	if savingOnShutdown[player.UserId] then
		sessionData[player.UserId]      = nil
		dataLoaded[player.UserId]       = nil
		pendingDonations[player.UserId] = nil
		requestCooldown[player.UserId]  = nil
		lastSavedRaised[player.UserId]  = nil
		lastSavedDonated[player.UserId] = nil
		savingOnShutdown[player.UserId] = nil
		return
	end
	savePlayerData(player, true)
end)

game:BindToClose(function()
	isShuttingDown = true

	pcall(flushGlobalQueue)

	local threads: {thread} = {}
	for _, player in ipairs(Players:GetPlayers()) do
		savingOnShutdown[player.UserId] = true
		local t = task.spawn(function()
			savePlayerData(player, true)
		end)
		table.insert(threads, t)
	end

	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local allDone = true
		for _, t in ipairs(threads) do
			if coroutine.status(t) ~= "dead" then
				allDone = false
				break
			end
		end
		if allDone then break end
		task.wait(0.1)
	end
end)

----------------------------------------------------------------
-- DONATION LOGIC
----------------------------------------------------------------

local function getSpecialAnnouncement(fromPlayer: Player, toPlayer: Player, amount: number): (string?, Color3?)
	local message = ""
	local color   = Color3.fromRGB(255, 255, 255)

	if amount >= 10000 then
		message = string.format("Nag-donate si %s ng 10K kay %s — Tangina Sana All!!!", fromPlayer.Name, toPlayer.Name)
		color = Color3.fromRGB(255, 165, 0)
	elseif amount >= 2500 then
		message = string.format("Nag-donate si %s ng %d kay %s — OHMYGOD IS THIS REAL???", fromPlayer.Name, amount, toPlayer.Name)
		color = Color3.fromRGB(255, 165, 0)
	elseif amount >= 1000 then
		message = string.format("Nag-donate si %s ng %d kay %s — Tangina Sana All!!!", fromPlayer.Name, amount, toPlayer.Name)
		color = Color3.fromRGB(255, 105, 180)
	elseif amount >= 500 then
		message = string.format("Nag-donate si %s ng %d kay %s — Grabe parehh!!!!", fromPlayer.Name, amount, toPlayer.Name)
		color = Color3.fromRGB(255, 165, 0)
	elseif amount >= 100 then
		message = string.format("Nag-donate si %s ng %d kay %s — Sheesh!!!", fromPlayer.Name, amount, toPlayer.Name)
		color = Color3.fromRGB(0, 255, 0)
	end

	if message == "" then return nil, nil end
	return message, color
end

local function playTipJarVfx(toPlayer: Player, fromPlayer: Player, amount: number)
	local char = toPlayer.Character
	if not char then
		-- Tunggu spawn max 5 detik, kalau tidak muncul → skip VFX saja
		local result: Model? = nil
		local waitThread = task.spawn(function()
			result = toPlayer.CharacterAdded:Wait()
		end)

		local waited = 0
		while waited < 5 and not result do
			task.wait(0.2)
			waited += 0.2
		end

		if not result then
			if coroutine.status(waitThread) ~= "dead" then
				pcall(function() task.cancel(waitThread) end)
			end
			return
		end
		char = result
	end

	if not char then return end

	local jar = char:FindFirstChild("Tip Jar") or char:FindFirstChild("TipJar")
	if not jar then return end

	local handle = (jar :: any):FindFirstChild("Handle")
	if not handle then return end

	local billboard = handle:FindFirstChild("BillboardGui")
	local label:  TextLabel? = nil
	local stroke: UIStroke?  = nil

	if billboard and billboard:IsA("BillboardGui") then
		label = billboard:FindFirstChildOfClass("TextLabel")
		if label then
			stroke = label:FindFirstChildOfClass("UIStroke")
		end
	end

	if label and billboard then
		label.TextTransparency = 0
		label.Text = string.format("%s donated %s%d", fromPlayer.DisplayName, utf8.char(0xE002), amount)
		if stroke then stroke.Transparency = 0.5 end
		billboard.Enabled = true
	end

	local donateSound = handle:FindFirstChild("Donate")
	if donateSound and donateSound:IsA("Sound") then
		donateSound:Play()
	end

	task.spawn(function()
		local attachment = handle:FindFirstChildOfClass("Attachment")
		local emitter: ParticleEmitter? = nil
		if attachment then
			emitter = attachment:FindFirstChildOfClass("ParticleEmitter")
		end

		for _ = 1, 50 do
			if emitter then emitter:Emit(1) end
			task.wait(0.02)
		end

		task.wait(1)

		if label and stroke then
			local fadeOut1 = TweenService:Create(label,  TweenInfo.new(0.25), { TextTransparency = 1 })
			local fadeOut2 = TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency     = 1 })
			fadeOut1:Play()
			fadeOut2:Play()
			fadeOut2.Completed:Wait()
		end

		if billboard then billboard.Enabled = false end
	end)
end

local function applyDonation(fromPlayer: Player, toPlayer: Player, amount: number)
	if amount <= 0 then return end

	local fromData = sessionData[fromPlayer.UserId]
	if fromData then
		fromData.Donated += amount
	else
		-- Data belum load: tampung delta, loader akan merge (bukan menimpa)
		fromData = { Donated = amount, Raised = 0 }
		sessionData[fromPlayer.UserId] = fromData
	end

	local donatedValue = fromPlayer:FindFirstChild("Donated")
	if donatedValue then donatedValue.Value += amount end

	local toData = sessionData[toPlayer.UserId]
	if toData then
		toData.Raised += amount
	else
		toData = { Donated = 0, Raised = amount }
		sessionData[toPlayer.UserId] = toData
	end

	local raisedValue = toPlayer:FindFirstChild("Raised")
	if raisedValue then raisedValue.Value += amount end

	queueGlobalSave(GlobalDonatedStore, lastSavedDonated, fromPlayer.UserId, fromData.Donated, "donated")
	queueGlobalSave(GlobalRaisedStore,  lastSavedRaised,  toPlayer.UserId,   toData.Raised,   "raised")

	playTipJarVfx(toPlayer, fromPlayer, amount)

	local announceMsg, announceColor = getSpecialAnnouncement(fromPlayer, toPlayer, amount)
	if announceMsg and announceColor then
		ChatMessageRemote:FireAllClients({
			Type    = "Announcement",
			Message = announceMsg,
			Color   = announceColor,
		})
	end

	task.spawn(function()
		local sound   = Instance.new("Sound")
		sound.Name    = "GlobalDonationSound"
		sound.SoundId = "rbxassetid://84795270640054"
		sound.Volume  = 2
		sound.Parent  = game:GetService("SoundService")
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 3)
	end)

	ChatMessageRemote:FireAllClients({
		Type      = "Donation",
		Donor     = fromPlayer.DisplayName,
		Recipient = toPlayer.DisplayName,
		Amount    = amount,
	})
end

----------------------------------------------------------------
-- Remote: RequestDonation
----------------------------------------------------------------
RequestDonationRemote.OnServerEvent:Connect(function(fromPlayer: Player, targetUserId: number, gamePassId: number)
	if typeof(targetUserId) ~= "number" or typeof(gamePassId) ~= "number" then return end

	local now  = os.clock()
	local last = requestCooldown[fromPlayer.UserId] or 0
	if now - last < 2 then return end
	requestCooldown[fromPlayer.UserId] = now

	local toPlayer = Players:GetPlayerByUserId(targetUserId)
	if not toPlayer then return end

	if not GamepassRegistry.IsAllowed(targetUserId, gamePassId) then
		warn("[Donation] gamePassId", gamePassId, "tidak ada di whitelist untuk userId", targetUserId)
		return
	end

	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
	end)

	if not success or typeof(productInfo) ~= "table" then
		warn("[Donation] GetProductInfo failed for", gamePassId)
		return
	end

	local info = productInfo :: any

	if ENFORCE_CREATOR_MATCH then
		local creator    = info.Creator
		local creatorId: number? = nil
		if typeof(creator) == "table" then
			creatorId = creator.CreatorTargetId or creator.Id or creator.CreatorId
		end
		if typeof(creatorId) ~= "number" then
			warn("[Donation] Missing or invalid CreatorId for gamepass", gamePassId)
			return
		end
		if creatorId ~= targetUserId then
			warn(string.format("[Donation] Creator mismatch for gamepass %d (creatorId=%d, targetUserId=%d)",
				gamePassId, creatorId, targetUserId))
			return
		end
	end

	local price = info.PriceInRobux
	if typeof(price) ~= "number" or price <= 0 then
		warn("[Donation] Invalid price for gamepass", gamePassId)
		return
	end

	pendingDonations[fromPlayer.UserId] = {
		targetUserId = targetUserId,
		gamePassId   = gamePassId,
		amount       = price,
	}

	pcall(function()
		MarketplaceService:PromptGamePassPurchase(fromPlayer, gamePassId)
	end)
end)

----------------------------------------------------------------
-- Roblox purchase event
----------------------------------------------------------------
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, purchasedPassId: number, wasPurchased: boolean)
	if not wasPurchased then
		pendingDonations[player.UserId] = nil
		return
	end

	local pendingDonation = pendingDonations[player.UserId]
	if not pendingDonation then return end
	if pendingDonation.gamePassId ~= purchasedPassId then return end

	pendingDonations[player.UserId] = nil

	local toPlayer = Players:GetPlayerByUserId(pendingDonation.targetUserId)
	if not toPlayer then return end

	applyDonation(player, toPlayer, pendingDonation.amount)
end)
