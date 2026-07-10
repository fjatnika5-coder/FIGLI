local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)
local bbvisible = true

game.Workspace.DescendantAdded:Connect(function(obj)
    task.wait(1)
    if obj:IsA('BillboardGui') then
        obj.Enabled = bbvisible
    end
end)

event.OnInvoke = function(condition)
    if condition ~= bbvisible then
        
        bbvisible = condition
        
        for i, part in pairs(workspace:GetDescendants()) do
            if part:IsA("BillboardGui") then
                part.Enabled = bbvisible
            end
        end
        
    end
end