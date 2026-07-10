local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("PlaySoundLocal3D")

remote.OnClientEvent:Connect(function(soundId, part)
	if not part then return end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Name = "3DSound"
	sound.Volume = 1
	sound.EmitterSize = 10 -- ukuran area penyebaran suara
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMaxDistance = 50 -- maksimum jarak suara terdengar
	sound.Looped = false
	sound.Parent = part
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end)
