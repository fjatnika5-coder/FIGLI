local cache = {} -- array of cache
local shadows = {} -- array of shadows
local Graphicvisible = true
local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)

event.OnInvoke = function(condition)
    if condition ~= Graphicvisible then
        
        Graphicvisible = condition

        if Graphicvisible then


            for _, part in pairs(workspace:GetDescendants()) do
                if part:IsA("BasePart") and cache[part] ~= nil and shadows[part] ~= nil then
                    part.Material = cache[part]
                    part.CastShadow = shadows[part]
                    game.Lighting.GlobalShadows = true
                end
            end

        else

            for i, part in pairs(workspace:GetDescendants()) do
                if part:IsA("BasePart") and cache[part] ~= nil and shadows[part] ~= nil then
                    part.Material = Enum.Material.Plastic
                    part.CastShadow = false
                    game.Lighting.GlobalShadows = false
                elseif part:IsA("BasePart") then
                    cache[part] = part.Material
                    shadows[part] = part.CastShadow
                    
                    part.Material = Enum.Material.Plastic
                    part.CastShadow = false
                    game.Lighting.GlobalShadows = false
                end
            end
        end
    end
end

-- Cache the initial material and shadow settings
for i, part in pairs(workspace:GetDescendants()) do
    if part:IsA("BasePart") then
        cache[part] = part.Material
        shadows[part] = part.CastShadow
    end
end