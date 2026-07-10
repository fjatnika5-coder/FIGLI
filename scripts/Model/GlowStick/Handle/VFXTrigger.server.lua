local WindRingDark = script.Parent.Parent.Handle.LevelParticle
local WindRingAzure = script.Parent.Parent.Handle2.LevelParticle


local RS = game:GetService("ReplicatedStorage")
local effectEvent = RS.GlowStick

local tool = script.Parent.Parent
local localPlayer = tool.Parent.Parent

effectEvent.OnServerEvent:Connect(function(player)
	if player ~= localPlayer then return end
	WindRingAzure.Enabled = true
	WindRingDark.Enabled = true
	wait(1)
	WindRingAzure.Enabled = false
	WindRingDark.Enabled = false
end)