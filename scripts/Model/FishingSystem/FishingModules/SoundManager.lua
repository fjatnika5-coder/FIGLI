local SoundManager = {}
local RepStorage = game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem")
local Debris = game:GetService("Debris")

-- Cache sounds
local soundsFolder = RepStorage:WaitForChild("Assets"):WaitForChild("Sound")
local sounds = {}

-- ✅ TAMBAHKAN INI
SoundManager.Enabled = true

function SoundManager:Initialize()
	for _, soundName in {"Cast", "Success", "Reeling", "HookHit", "Tap"} do
		local sound = soundsFolder:FindFirstChild(soundName)
		if sound then
			sounds[soundName] = sound
		end
	end
end

function SoundManager:Play(soundName, volume)
	-- ✅ TAMBAHKAN INI
	if not SoundManager.Enabled then 
		return 
	end

	local sound = sounds[soundName]
	if not sound then return end

	local clone = sound:Clone()
	clone.Volume = volume or 0.5
	clone.Parent = workspace
	clone:Play()

	clone.Ended:Connect(function()
		clone:Destroy()
	end)

	Debris:AddItem(clone, 10)
end

-- ✅ TAMBAHKAN FUNCTION INI
function SoundManager:SetEnabled(state)
	SoundManager.Enabled = state

	-- Stop semua fishing sound yang lagi playing
	if not state then
		for _, sound in pairs(workspace:GetDescendants()) do
			if sound:IsA("Sound") and (
				sound.Name == "Cast" or 
					sound.Name == "Success" or 
					sound.Name == "Reeling" or 
					sound.Name == "HookHit" or 
					sound.Name == "Tap"
				) then
				sound:Stop()
				sound:Destroy()
			end
		end
	end
end

return SoundManager