-- AdminLuckSystem
-- Location: ServerScriptService/AdminLuckSystem (Script)
--
-- AUDIT FIX:
-- [FIX H] Removed the TextChatService ShouldDeliverCallback hook. Player.Chatted
--         already fires for TextChatService messages, so the old hook processed
--         every admin command TWICE (double boost + double MessagingService
--         publish) and monopolized RBXGeneral.ShouldDeliverCallback (only one
--         callback can exist game-wide).

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ==============================================================================
-- KONFIGURASI ADMIN
-- ==============================================================================
local ADMIN_IDS = {
	8918465521,
}

local GLOBAL_TOPIC = "GlobalLuckEvent"

local playerConnections = {}
local currentBoostTask = nil
local messagingConnection = nil

-- ==============================================================================
-- AUTO-SETUP
-- ==============================================================================
local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem", 10)
local LuckValue = FishingSystem and FishingSystem:FindFirstChild("GlobalLuckMultiplier")

if not LuckValue and FishingSystem then
	LuckValue = Instance.new("NumberValue")
	LuckValue.Name = "GlobalLuckMultiplier"
	LuckValue.Value = 1
	LuckValue.Parent = FishingSystem
end

local ShowNotification = FishingSystem:WaitForChild("ShowNotification")
local SendChatMessage = FishingSystem:WaitForChild("SendChatMessage")

local function cleanupPlayer(player)
	local data = playerConnections[player.UserId]
	if data then
		if data.chatted then
			data.chatted:Disconnect()
		end
		playerConnections[player.UserId] = nil
	end
end

local function cleanup()
	if currentBoostTask and typeof(currentBoostTask) == "thread" then
		pcall(function()
			task.cancel(currentBoostTask)
		end)
		currentBoostTask = nil
	end

	if messagingConnection and typeof(messagingConnection) == "RBXScriptConnection" then
		pcall(function()
			messagingConnection:Disconnect()
		end)
		messagingConnection = nil
	end

	for _, data in pairs(playerConnections) do
		if data.chatted and typeof(data.chatted) == "RBXScriptConnection" then
			pcall(function()
				data.chatted:Disconnect()
			end)
		end
	end
	table.clear(playerConnections)

	if LuckValue then
		LuckValue.Value = 1
	end
end

-- ==============================================================================
-- LOGIKA KEAMANAN
-- ==============================================================================

local function isAdmin(userId)
	for _, id in ipairs(ADMIN_IDS) do
		if userId == id then
			return true
		end
	end
	return false
end

local function formatTime(seconds)
	if seconds >= 60 then
		return string.format("%d menit", math.floor(seconds / 60))
	else
		return string.format("%d detik", seconds)
	end
end

local function executeLuckBoost(multiplier, duration, isGlobal, adminName)
	if currentBoostTask and typeof(currentBoostTask) == "thread" then
		pcall(function()
			task.cancel(currentBoostTask)
		end)
		currentBoostTask = nil
	end

	currentBoostTask = task.spawn(function()
		if LuckValue then LuckValue.Value = multiplier end

		local scopeText = isGlobal and "GLOBAL" or "SERVER"
		local msg = string.format("🔥 %s EVENT! Luck x%d oleh %s (%s)!", scopeText, multiplier, adminName, formatTime(duration))

		pcall(function()
			ShowNotification:FireAllClients(msg, 8, Color3.fromRGB(0, 255, 0))
			SendChatMessage:FireAllClients("General", "[SYSTEM]", msg, 0, "Legendary")
		end)

		local timeLeft = duration
		while timeLeft > 0 do
			task.wait(1)
			timeLeft = timeLeft - 1

			if not currentBoostTask then break end
		end

		if LuckValue then LuckValue.Value = 1 end

		pcall(function()
			ShowNotification:FireAllClients("Event Luck Berakhir.", 5, Color3.fromRGB(200, 200, 200))
		end)

		currentBoostTask = nil
	end)
end

-- ==============================================================================
-- PROCESSOR COMMAND
-- ==============================================================================
local function processCommand(player, text)
	if not player or not player.Parent then return end

	text = string.gsub(text, "^%s*(.-)%s*$", "%1")

	local prefix = string.sub(text, 1, 1)
	local commandBody = string.sub(text, 2)
	local args = string.split(commandBody, " ")
	local cmd = string.lower(args[1] or "")

	if prefix ~= "/" and prefix ~= ":" and prefix ~= "!" then return end

	if cmd == "luck" then
		if not isAdmin(player.UserId) then
			warn("⛔ SECURITY ALERT: " .. player.Name .. " mencoba pakai command admin!")
			pcall(function()
				ShowNotification:FireClient(player, "⛔ Anda bukan Admin!", 3, Color3.fromRGB(255, 50, 50))
			end)
			return
		end

		local scope = string.lower(args[2] or "")
		local mult = tonumber(args[3])
		local minutes = tonumber(args[4])

		if (scope ~= "server" and scope ~= "global") or not mult or not minutes then
			pcall(function()
				ShowNotification:FireClient(player, "Format: !luck [server/global] [angka] [menit]", 5, Color3.fromRGB(255, 255, 0))
			end)
			return
		end

		local duration = minutes * 60

		if scope == "server" then
			executeLuckBoost(mult, duration, false, player.Name)
		elseif scope == "global" then
			pcall(function()
				MessagingService:PublishAsync(GLOBAL_TOPIC, {m = mult, d = duration, a = player.Name})
			end)
			executeLuckBoost(mult, duration, true, player.Name)
		end

	elseif cmd == "unluck" then
		if isAdmin(player.UserId) then
			if currentBoostTask and typeof(currentBoostTask) == "thread" then
				pcall(function()
					task.cancel(currentBoostTask)
				end)
				currentBoostTask = nil
			end
			if LuckValue then LuckValue.Value = 1 end
			pcall(function()
				ShowNotification:FireAllClients("🚫 Boost dibatalkan Admin.", 4, Color3.fromRGB(255, 100, 100))
			end)
		end
	end
end

-- ==============================================================================
-- LISTENER
-- ==============================================================================

local function hookPlayer(player)
	cleanupPlayer(player)
	playerConnections[player.UserId] = {
		chatted = player.Chatted:Connect(function(msg)
			processCommand(player, msg)
		end),
	}
end

Players.PlayerAdded:Connect(hookPlayer)

Players.PlayerRemoving:Connect(cleanupPlayer)

local subscribeSuccess, subscribeResult = pcall(function()
	return MessagingService:SubscribeAsync(GLOBAL_TOPIC, function(msg)
		local d = msg.Data
		if d then
			executeLuckBoost(d.m, d.d, true, d.a)
		end
	end)
end)

if subscribeSuccess and subscribeResult and typeof(subscribeResult) == "RBXScriptConnection" then
	messagingConnection = subscribeResult
end

game:BindToClose(function()
	cleanup()
end)

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end
