local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)
local bbvisible = false

game.Workspace.DescendantAdded:Connect(function(obj)
    task.wait(1)
if obj.Name == "Ulan" then
	obj.Enabled = bbvisible
end
end)

event.OnInvoke = function(condition)
    if condition ~= bbvisible then
        
        bbvisible = condition
        
        for i, part in pairs(workspace:GetDescendants()) do
            if part.Name("Ulan") then
				part.Enabled = bbvisible
				
					end
				end
	end
end

			
			
local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)
local bbvisible = false

game.Workspace.DescendantAdded:Connect(function(obj)
	task.wait(1)
	if obj.Name == "Ulan" and obj:IsA("ParticleEmitter") then
		obj.Enabled = bbvisible
	end
end)

event.OnInvoke = function(condition)
	if condition ~= bbvisible then
		bbvisible = condition
		for _, part in pairs(workspace:GetDescendants()) do
			if part.Name == "Ulan" and part:IsA("ParticleEmitter") then
				part.Enabled = bbvisible
			end
		end
	end
end
