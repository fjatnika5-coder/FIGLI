-- SoundManager
-- Location: ReplicatedStorage/FishingSystem/FishingModules/SoundManager (ModuleScript)
--
-- Reuses a fixed pool instead of cloning one Sound per play.
-- [PERF-8] Dynamic resolution: nama Sound APA PUN yang ada di
-- FishingSystem/Assets/Sound bisa diputar (dipakai Attribute SFX root
-- template VfxSplash), tetap satu instance ter-manage per nama.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local templates = FishingSystem:WaitForChild("Assets"):WaitForChild("Sound")

local SoundManager = { Enabled = true }
local managed = {}
local NAMES = {"Cast", "Success", "Reeling", "HookHit", "Tap"}

local folder = SoundService:FindFirstChild("FishingSounds")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "FishingSounds"
	folder.Parent = SoundService
end

local function resolve(name)
	local sound = managed[name]
	if sound and sound.Parent then return sound end

	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		managed[name] = existing
		return existing
	end

	local template = templates:FindFirstChild(name)
	if template and template:IsA("Sound") then
		sound = template:Clone()
		sound.Name = name
		sound.Looped = false
		sound.Parent = folder
		managed[name] = sound
		return sound
	end

	return nil
end

function SoundManager:Initialize()
	for _, name in ipairs(NAMES) do
		resolve(name)
	end
end

function SoundManager:Play(soundName, volume)
	if not self.Enabled then return end
	if type(soundName) ~= "string" or soundName == "" then return end

	local sound = resolve(soundName)
	if not sound then return end

	sound:Stop()
	sound.TimePosition = 0
	sound.Volume = math.clamp(tonumber(volume) or 0.5, 0, 10)
	sound:Play()
end

function SoundManager:SetEnabled(state)
	self.Enabled = state == true
	if not self.Enabled then
		for _, sound in pairs(managed) do
			if sound and sound.Parent then sound:Stop() end
		end
	end
end

function SoundManager:Cleanup()
	for _, sound in pairs(managed) do
		if sound and sound.Parent then sound:Destroy() end
	end
	table.clear(managed)
end

return SoundManager
