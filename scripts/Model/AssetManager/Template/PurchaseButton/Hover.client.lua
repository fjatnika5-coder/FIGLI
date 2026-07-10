local TweenService = game:GetService("TweenService")
local textButton = script.Parent -- The TextButton itself
local parentUI = textButton.Parent -- The parent of the TextButton
local uiScale = parentUI:FindFirstChildOfClass("UIScale") -- Find the UIScale in the parent

-- Original color of the button
local originalColor = textButton.BackgroundColor3

if uiScale then
	-- Tween info for hover (increase scale)
	local tweenInfoHover = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	-- Tween info for reset (restore scale)
	local tweenInfoReset = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Create tweens for scale and background color change
	local tweenHover = TweenService:Create(uiScale, tweenInfoHover, {Scale = 1.2}) -- Tween to increase scale
	local tweenReset = TweenService:Create(uiScale, tweenInfoReset, {Scale = 1}) -- Tween to reset scale

	local colorHoverTween = TweenService:Create(textButton, tweenInfoHover, {BackgroundColor3 = Color3.fromRGB(174, 254, 255)})
	local colorResetTween = TweenService:Create(textButton, tweenInfoReset, {BackgroundColor3 = originalColor})

	-- Play hover effects when the mouse enters the button
	textButton.MouseEnter:Connect(function()
		tweenHover:Play() -- Play the hover tween when mouse enters the button
		colorHoverTween:Play() -- Change background color on hover
	end)

	-- Reset effects when the mouse leaves the button
	textButton.MouseLeave:Connect(function()
		tweenReset:Play() -- Play the reset tween when mouse leaves the button
		colorResetTween:Play() -- Reset background color on leave
	end)
else
	warn("No UIScale found in the parent of the TextButton!")
end
