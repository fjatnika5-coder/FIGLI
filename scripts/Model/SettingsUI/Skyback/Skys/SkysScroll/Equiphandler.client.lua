local db = false

wait(1)
for i,v in pairs(script.Parent:GetChildren()) do
	if v:IsA("ImageButton") then
		v.MouseButton1Click:Connect(function()
			if db == false then
				db = true
				print("Clicked: "..v.Name)
				script.Roblox_UI_Bright_Click:Play()
				for _,SkyAlrexisted in pairs(game.Lighting:GetChildren()) do
					SkyAlrexisted:Destroy()
				end
				task.wait(0.1)
				local findSkyinRepli = game.ReplicatedStorage.Sky:FindFirstChild(v.Name):Clone()
				if findSkyinRepli then
					findSkyinRepli.Parent = game.Lighting
					
					--Set the Lightning Settings
					game.Lighting.Ambient = findSkyinRepli.Ambient.Value
					game.Lighting.Brightness = findSkyinRepli.Brightness.Value
					game.Lighting.ClockTime = findSkyinRepli.ClockTime.Value
					game.Lighting.ColorShift_Top = findSkyinRepli.ColorShift_Top.Value
					game.Lighting.ColorShift_Bottom = findSkyinRepli.ColorShift_Bottom.Value
					game.Lighting.EnvironmentDiffuseScale = findSkyinRepli.EnviromentalDiffuseScale.Value
					game.Lighting.EnvironmentSpecularScale = findSkyinRepli.EnviromentalSpecularScale.Value
					game.Lighting.GeographicLatitude = findSkyinRepli.GeographicLatitude.Value
					game.Lighting.OutdoorAmbient = findSkyinRepli.OutDoorAmbient.Value
					game.Lighting.ShadowSoftness = findSkyinRepli.ShadowSoftness.Value
					-----------------
					
					for __,Skys in pairs(findSkyinRepli:GetChildren()) do
						Skys.Parent = game.Lighting
					end
					
					findSkyinRepli:Destroy()
				end
				
				task.wait(0.1)
				db = false
			end
		end)
	end
end