local tweenservice = game:GetService("TweenService")

local db = false
local RainActive = false

local endpos = UDim2.new(0.57, 0,0.051, 0)
local startpos = UDim2.new(0, 0,0.051, 0)

script.Parent.MouseButton1Click:Connect(function()
	script.Roblox_UI_Bright_Click:Play()
	if RainActive == false then
		if db == false then
			db = true
			RainActive = true
			script.Rain:Play()
			
			local RainFolderCreate = Instance.new("Folder",game.Players.LocalPlayer.Character)
			RainFolderCreate.Name = "Rain"
			
			for i = 34,1,-1 do
				local cloneTop = game.ReplicatedStorage.RainFolder.TopRain:Clone()
				cloneTop.Parent = RainFolderCreate
				cloneTop.CFrame = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,20,0)
				
				local weldCreate = Instance.new("WeldConstraint")
				weldCreate.Parent = cloneTop
				weldCreate.Part0 = cloneTop
				weldCreate.Part1 = game.Players.LocalPlayer.Character.HumanoidRootPart
			end
			
			for i = 6,1,-1 do
				local cloneTop = game.ReplicatedStorage.RainFolder.BottomRain:Clone()
				cloneTop.Parent = RainFolderCreate
				cloneTop.CFrame = game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,-2,0)

				local weldCreate = Instance.new("WeldConstraint")
				weldCreate.Parent = cloneTop
				weldCreate.Part0 = cloneTop
				weldCreate.Part1 = game.Players.LocalPlayer.Character.HumanoidRootPart
			end
			
			

			local tweenC = tweenservice:Create(script.Parent,TweenInfo.new(0.25),{BackgroundColor3 = Color3.fromRGB(0, 255, 17)})
			tweenC:Play()
			
			script.Parent.Indicator:TweenPosition(endpos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.25)

			task.wait(0.2)
			db = false
			
		end
	else
		if db == false then
			db = true
			RainActive = false
			local tweenP = tweenservice:Create(script.Parent,TweenInfo.new(0.25),{BackgroundColor3 = Color3.fromRGB(255, 0, 4)})
			tweenP:Play()
			script.Rain:Stop()
			
			
			
			game.Players.LocalPlayer.Character.Rain:Destroy()
			
			
			
			script.Parent.Indicator:TweenPosition(startpos,Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.25)

			task.wait(0.2)
			db = false
		end
	end
end)