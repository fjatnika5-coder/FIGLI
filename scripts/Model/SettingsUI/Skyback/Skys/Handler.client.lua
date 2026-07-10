local ServerStorage = game:GetService("ReplicatedStorage")
local skyFolder = ServerStorage:FindFirstChild("Sky")
local skyUI = ServerStorage:FindFirstChild("SkyUI")
local skysScroll = script.Parent:FindFirstChild("SkysScroll")

if skyFolder and skyUI and skysScroll then
	local skyChildren = skyFolder:GetChildren()
	print("Numbers of Sky: ", #skyChildren)

	for _, child in pairs(skyChildren) do
		local clonedUI = skyUI:Clone()
		clonedUI.Parent = skysScroll
		for _,insidetheSky in pairs(child:GetChildren())do
			if insidetheSky:IsA("Sky") then
				clonedUI.Image = insidetheSky.SkyboxLf
			end
		end
		clonedUI.Skyname.Text = child.Name
		clonedUI.Name = child.Name
	end
end
