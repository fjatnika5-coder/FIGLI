local player = game.Players.LocalPlayer

repeat wait(1) until player.Character

local character = player.Character
local humanoid = character:WaitForChild("Humanoid")

local animationIds = {
	"http://www.roblox.com/asset/?id=120611859881869",  -- Idle Animation 1
	-- Add more animation IDs as needed
}

local randomAnimationId = animationIds[math.random(1, #animationIds)]

local animation = Instance.new("Animation")
animation.Name = "Idle"
animation.Parent = script.Parent

animation.AnimationId = randomAnimationId
local animtrack = humanoid:LoadAnimation(animation)

script.Parent.Equipped:connect(function()
	animtrack:Play()
end)

script.Parent.Unequipped:connect(function()
	animtrack:Stop()
end)