--[[
Server can send with this : 

RemoteEvent:FireClient(<player>, Mode, Text, Duration)

Client From Another Script wit this : 

_G.SendNotification(Mode, Text, Duration)                                                                                                                                  ]] -- Its not like it will be a hidden backdoor code lmao

local RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("AuraShopRemotes"):WaitForChild("Notifcations") 
local gui = script.Parent
local Canvas = gui.list


_G.SendNotificationV2 = function(Mode, Text, Sound, Duration)
	if script:FindFirstChild(Mode) then
		local success, err = pcall(function()
			if script.Sound:FindFirstChild("success") then
				script.Sound:WaitForChild("success"):Play()
			end
				local Notification = script:WaitForChild(Mode):Clone()
				if Duration > 15 then
					local closeButton = script.ClosePrompt:Clone()
					closeButton.Visible = true
					closeButton.MouseEnter:Connect(function()
						closeButton.BackgroundTransparency = 0.1
						closeButton.ImageLabel.Visible = true
					end)
					closeButton.MouseLeave:Connect(function()
						closeButton.BackgroundTransparency = 1
						closeButton.ImageLabel.Visible = false
					end)
					closeButton.MouseButton1Click:Connect(function()
						Notification.Filler:TweenSize(UDim2.new(1, 0,1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2,true)
						task.wait(0.25)
						Notification:TweenSize(UDim2.new(0, 0,0.087, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
						task.wait(0.2)
						Notification:Destroy()
					end)
					closeButton.Parent = Notification
				end
				Notification.Header.Text = Text
				Notification.Size = UDim2.new(0, 0,0.087, 0)
				Notification.Filler.Size = UDim2.new(1, 0,1, 0)
				Notification.Parent = Canvas

				Notification:TweenSize(UDim2.new(1, 0,0.087, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
				task.wait(0.2)
				Notification.Filler:TweenSize(UDim2.new(0.011, 0,1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)

				Notification.bar:TweenSize(UDim2.new(1, 0,0.05, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, Duration, true)
				task.wait(Duration)
							
				Notification.Filler:TweenSize(UDim2.new(1, 0,1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2,true)
				task.wait(0.25)
				Notification:TweenSize(UDim2.new(0, 0,0.087, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
				task.wait(0.2)
				Notification:Destroy()
		end)
		if not success then
		end
	else
	end
end

RemoteEvent.OnClientEvent:Connect(_G.SendNotificationV2)



