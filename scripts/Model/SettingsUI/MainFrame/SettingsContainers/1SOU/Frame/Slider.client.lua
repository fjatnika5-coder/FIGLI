local mouse = game.Players.LocalPlayer:GetMouse()
local slider = script.Parent
local fill = script.Parent.Slide
local button = script.Parent.TextButton
local outputvalue = script.Parent.OutputValue

-- Ensure all sounds are correctly referenced
local sounds = {
	game.SoundService:WaitForChild("city ambience (NW D.C. Ambience.)"),
	game.Workspace:WaitForChild("Music"):WaitForChild("Dilaw"),
	game.Workspace:WaitForChild("RoadRust"):WaitForChild("Ambiance")
}

-- Initial slider fill size and button text
fill.Size = UDim2.fromScale(outputvalue.Value, 0.9)
button.Text = "0.1"

-- Function to update the slider's position and text
local function updateslider()
	-- Clamp the output value between 0 and 1
	local output = math.clamp((mouse.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)

	-- Update button text and slider fill size
	button.Text = string.format("%.1f", output * 2)
	outputvalue.Value = output
	fill.Size = UDim2.fromScale(output, 1)
end

-- Variable to track if the slider is active
local slideractive = false

-- Function to activate and handle the slider
local function activateslider()
	slideractive = true
	while slideractive do
		-- Get the volume value from the button text and update sounds
		local volume = tonumber(button.Text)
		if volume then
			for _, sound in ipairs(sounds) do
				-- Ensure the sound exists before trying to set the volume
				if sound and sound:IsA("Sound") then
					sound.Volume = volume
				end
			end
		end
		updateslider()
		task.wait()
	end
end

-- Event listener for clicking on the slider button
button.MouseButton1Down:Connect(activateslider)

-- Event listener for releasing the mouse or touch input
game:GetService("UserInputService").InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		slideractive = false
	end
end)
