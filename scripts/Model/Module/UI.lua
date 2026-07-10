local UI = {}

local BigFrameInfo = {}

local TS = game:GetService("TweenService")
local MPS = game:GetService("MarketplaceService")
local CS = game:GetService("CollectionService")

function UI.Tween(instance,Time, easingStyle, easingDirection, Value,WaitBool)
	local tween = TS:Create(instance,TweenInfo.new(Time,easingStyle,easingDirection),Value)
	tween:Play()
	if WaitBool then
		tween.Completed:Wait()
	end
end

function UI.TweenSize(UIElement,Time, easingStyle, easingDirection, Value,WaitBool)
	local tween = TS:Create(UIElement,TweenInfo.new(Time,easingStyle or nil,easingDirection or nil),{Size = Value})
	tween:Play()
	if WaitBool then
		tween.Completed:Wait()
	end
end

function UI.TweenPosition(UIElement,Time, easingStyle, easingDirection, Value,WaitBool)
	local tween = TS:Create(UIElement,TweenInfo.new(Time,easingStyle or 0,easingDirection or 0),{Position = Value})
	tween:Play()
	if WaitBool then
		tween.Completed:Wait()
	end
end

function UI.PromptGamePassPurchase(player,ID)
	MPS:PromptGamePassPurchase(player,ID)
end

function UI.PromptProductPurchase(player,ID)
	MPS:PromptProductPurchase(player,ID)
end

function UI.Visible(Button)
	local Frame = Button.Frame.Value
	local Action = Button:HasTag("OpenButton") and true or false
	Frame.Visible = Action
end

function UI.HideUIs(Action,DontHide)


	print(Action)

	if Action == "Hide" then
		for i, ui in ipairs(CS:GetTagged("HideUI")) do
			task.spawn(function()
				if ui.Name == "Top" and DontHide ~= ui.Name then

					UI.TweenPosition(ui,.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out,ui.Position+UDim2.fromOffset(0,40),true)
					UI.TweenPosition(ui,.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out,UDim2.fromScale(ui.Position.X.Scale,-.5),true)
				elseif ui.Name == "Bottom" and DontHide ~= ui.Name then

					UI.TweenPosition(ui,.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out,ui.Position+UDim2.fromOffset(0,-40),true)
					UI.TweenPosition(ui,.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out,UDim2.fromScale(ui.Position.X.Scale,1.5),true)

				elseif ui.Name == "Left" and DontHide ~= ui.Name then

					UI.TweenPosition(ui,.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out,ui.Position+UDim2.fromOffset(40,0),true)
					UI.TweenPosition(ui,.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out,UDim2.fromScale(-.5,ui.Position.Y.Scale),true)

				elseif ui.Name == "Right" and DontHide ~= ui.Name then

					UI.TweenPosition(ui,.2,Enum.EasingStyle.Back,Enum.EasingDirection.Out,ui.Position+UDim2.fromOffset(-40,0),true)
					UI.TweenPosition(ui,.5,Enum.EasingStyle.Back,Enum.EasingDirection.Out,UDim2.fromScale(1.5,ui.Position.Y.Scale),true)
				end
			end)
			if i == #CS:GetTagged("HideUI") then
				task.wait(.2)
				script.Swing:Play()
			end
		end

	elseif Action == "Show" then

		print("showing")
		for _, ui in ipairs(CS:GetTagged("HideUI")) do
			print(ui)
			if DontHide then
				if DontHide.Name ~= ui.Name then
					UI.TweenPosition(ui,1,Enum.EasingStyle.Bounce,Enum.EasingDirection.Out,UI.HideUIPrePos[ui])
				end
			else
				UI.TweenPosition(ui,1,Enum.EasingStyle.Bounce,Enum.EasingDirection.Out,UI.HideUIPrePos[ui])
			end
		end
	end
end


function UI.CloseOtherFrames(Button)
	
	local OpeningFrame = Button.Frame.Value
	for _, Frame in ipairs(CS:GetTagged("BigFrames")) do
		
		if Frame:FindFirstChild("CloseButton",true) then
			if Frame:FindFirstChild("CloseButton",true):FindFirstChild("OpenButton") then
				Frame:FindFirstChild("CloseButton",true).OpenButton.Value.ImageColor3 = Color3.fromRGB(255,255,255)
			end
		end

		if OpeningFrame ~= Frame then

			if Frame:HasTag("TweenPosition") then
				UI.TweenPosition(Frame,.2,0,0,BigFrameInfo[Frame])
			elseif Frame:HasTag("TweenSize") then
				---
			elseif Frame:HasTag("TweenVisible") then
				Frame.Visible = false
			end
		end
	end
end

for _, Frame in ipairs(CS:GetTagged("BigFrames")) do
	BigFrameInfo[Frame] = Frame:HasTag("TweenPosition") and Frame.Position or Frame.Size
end

return UI
