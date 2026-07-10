local event = script.Parent.Parent:WaitForChild("SettingsEvents"):WaitForChild(script.Name)
local RepStorage = game:GetService("ReplicatedStorage")
local FishingSystem = RepStorage:WaitForChild("FishingSystem")
local FishingModules = FishingSystem:WaitForChild("FishingModules")
local SoundManager = require(FishingModules:WaitForChild("SoundManager"))

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ✅ UBAH INI: Default sound ON (true)
local ATTRIBUTE_KEY = "FishingSoundEnabled"

local fishingSoundEnabled = player:GetAttribute(ATTRIBUTE_KEY)
if fishingSoundEnabled == nil then
	fishingSoundEnabled = true  -- ✅ Default: Sound ON
	player:SetAttribute(ATTRIBUTE_KEY, true)
end

-- ✅ Set state pas load pertama kali
SoundManager:SetEnabled(fishingSoundEnabled)

event.OnInvoke = function(condition)
	fishingSoundEnabled = condition
	player:SetAttribute(ATTRIBUTE_KEY, fishingSoundEnabled)
	SoundManager:SetEnabled(fishingSoundEnabled)
	return fishingSoundEnabled
end