--!nonstrict
-- PhotoStoryClient: dengar StartStory/EndStory dari server, jalankan SceneRunner.
-- Satu story aktif per saat; story baru menghentikan yang lama dulu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script:WaitForChild("Modules")
local SceneRunner = require(Modules:WaitForChild("SceneRunner"))

local Remotes = ReplicatedStorage:WaitForChild("PhotoStoryRemotes")
local StartStory = Remotes:WaitForChild("StartStory")
local EndStory = Remotes:WaitForChild("EndStory")

local activeRunner = nil
local activeSession = nil

local function stopActive()
	if activeRunner then
		local runner = activeRunner
		activeRunner = nil
		activeSession = nil
		runner:Stop()
	end
end

StartStory.OnClientEvent:Connect(function(storyData)
	if typeof(storyData) ~= "table" then
		return
	end

	-- Hentikan story lama (kalau ada) sebelum mulai yang baru.
	stopActive()

	local runner = SceneRunner.new()
	activeRunner = runner
	activeSession = storyData.SessionId

	task.spawn(function()
		runner:Run(storyData, function()
			-- Selesai natural / dibatalkan: beri tahu server agar state pasangan dibersihkan.
			if activeRunner == runner then
				activeRunner = nil
			end
			activeSession = nil
			pcall(function()
				EndStory:FireServer(storyData.SessionId)
			end)
		end)
	end)
end)

EndStory.OnClientEvent:Connect(function()
	-- Server minta stop (mis. partner keluar).
	stopActive()
end)
