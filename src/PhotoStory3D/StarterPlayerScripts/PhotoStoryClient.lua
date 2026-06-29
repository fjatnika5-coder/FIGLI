--!nonstrict
-- PhotoStoryClient: dengar StartStory/EndStory, jalankan CutsceneRunner 3D.
-- Satu cutscene aktif; yang baru menghentikan yang lama dulu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script:WaitForChild("Modules")
local CutsceneRunner = require(Modules:WaitForChild("CutsceneRunner"))

local Remotes = ReplicatedStorage:WaitForChild("PhotoStoryRemotes")
local StartStory = Remotes:WaitForChild("StartStory")
local EndStory = Remotes:WaitForChild("EndStory")

local activeRunner = nil

local function stopActive()
	if activeRunner then
		local runner = activeRunner
		activeRunner = nil
		runner:Stop()
	end
end

StartStory.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or not (payload.GirlUserId and payload.BoyUserId) then
		return
	end
	stopActive()

	local runner = CutsceneRunner.new()
	activeRunner = runner

	task.spawn(function()
		runner:Run(payload, function()
			if activeRunner == runner then
				activeRunner = nil
			end
			pcall(function()
				EndStory:FireServer(payload.SessionId)
			end)
		end)
	end)
end)

EndStory.OnClientEvent:Connect(function()
	stopActive()
end)
