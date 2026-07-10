local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)
local bbvisible = true
local Shadows = game.Lighting

Shadows.DescendantAdded:Connect(function(obj)
	task.wait(1)
	if obj:IsA('DepthOfFieldEffect') then
		obj.Enabled = bbvisible
	end
end)

event.OnInvoke = function(condition)
	if condition ~= bbvisible then

		bbvisible = condition

		for i, part in pairs(Shadows:GetDescendants()) do
			if part:IsA("DepthOfFieldEffect") then
				part.Enabled = bbvisible
			end
		end

	end
end