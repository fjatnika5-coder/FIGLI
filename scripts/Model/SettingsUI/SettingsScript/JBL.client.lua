local CS = game:GetService('CollectionService')

local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)
local jblsactive = true
local alljbls = CS:GetTagged('Boombox')

local function updatejbls()
    for _,a in pairs(alljbls) do
        if a:FindFirstChild('Handle') and a.Handle:FindFirstChild('Sound') then
            a.Handle.Sound.RollOffMaxDistance = (jblsactive and 45 or 0)
        end
    end
end

CS:GetInstanceAddedSignal('Boombox'):Connect(function()
    alljbls = CS:GetTagged('Boombox')
    task.wait(1)
    if jblsactive == false then
        updatejbls()
    end
end)


event.OnInvoke = function(condition)
    if condition ~= jblsactive then
        
        jblsactive = condition

        updatejbls()
        
    end
end