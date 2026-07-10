local Tool = script.Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local effectEvent = ReplicatedStorage:WaitForChild("GlowStick")
local humanoid = nil
local drinker = nil
local con = nil
local enabled = false

function onEquipped(mouse)

	humanoid = Tool.Parent:FindFirstChild("Humanoid")
	if humanoid ~= nil then
		drinker = humanoid:LoadAnimation(Tool.Anim)
	
	end
	con = mouse.Button1Down:connect(function() onButton1Down(mouse) end)

end

function onUnequipped(mouse)
	
	humanoid = nil
	if drinker ~= nil then
		drinker:remove()
		drinker = nil
	end
	if con ~= nil then
		con:disconnect()
	end

end

function onButton1Down(mouse)

	if enabled then
		return
	end
	
	enabled = true 

	
	drinker:Play()
	effectEvent:FireServer()
	wait(1)

	enabled = false


end

Tool.Equipped:Connect(onEquipped)
Tool.Unequipped:Connect(onUnequipped)
