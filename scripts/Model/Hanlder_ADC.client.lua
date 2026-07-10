-- =====================================================================
-- ✅ SCRIPT 4: CONSOLE CONTROL - CLIENT (OPTIMIZED v2)
-- Perbaikan: Hapus polling loop, pure event-driven,
--            debounce closeConsole, cleanup connections
-- =====================================================================
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local isWhitelisted = false
local whitelistReceived = false

local consoleControlEvent = ReplicatedStorage:WaitForChild("ConsoleControl", 10)

-- ✅ FIX: Guard jika remote tidak ditemukan
if not consoleControlEvent then
	warn("[ConsoleControl] ConsoleControl remote not found")
	return
end

consoleControlEvent.OnClientEvent:Connect(function(whitelisted)
	isWhitelisted = whitelisted
	whitelistReceived = true
end)

-- ✅ FIX: Debounce untuk closeConsole (ga perlu spam panggil)
local lastCloseAttempt = 0
local CLOSE_COOLDOWN = 0.5

local function closeConsole()
	if isWhitelisted then return end

	local now = tick()
	if now - lastCloseAttempt < CLOSE_COOLDOWN then return end
	lastCloseAttempt = now

	pcall(function()
		StarterGui:SetCore("DevConsoleVisible", false)
	end)
end

-- ✅ FIX: Wait for whitelist dengan task.delay (bukan task.spawn + while loop)
task.delay(2, function()
	-- Setelah 2 detik, kalau belum dapat whitelist status, anggap tidak whitelisted
	if not whitelistReceived then
		whitelistReceived = true
		isWhitelisted = false
	end
	closeConsole()
end)

-- Close on respawn
player.CharacterAdded:Connect(function()
	task.delay(1, function()
		closeConsole()
	end)
end)

-- ✅ FIX: Hanya detect F9, tidak perlu check setiap input
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Hanya react ke F9 (console toggle key)
	if input.KeyCode == Enum.KeyCode.F9 then
		if not isWhitelisted then
			task.delay(0.1, function()
				closeConsole()
			end)

			-- Report ke server
			pcall(function()
				consoleControlEvent:FireServer("ExploitDetected")
			end)
		end
	end
end)