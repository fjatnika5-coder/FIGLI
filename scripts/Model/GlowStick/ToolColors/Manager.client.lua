local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

local Gui = script.Parent

local Tool = script.Parent.Parent

local uis = game:GetService("UserInputService")

local AddedGui = false

local function AddNewTemplate(Tag)
	local Template = Gui.Template:Clone()
	Template.Parent = Gui.ListOfColorWheels
	Template.TextLabel.Text = Tag
	local Number = string.split(Tag, "Color")[2]
	if Number and tostring(Number) then
		Template.LayoutOrder = Number
	end
	Template.Visible = true
	local ColorWheel = Template:WaitForChild("ColorWheel")
	local wheelPicker = ColorWheel:WaitForChild("Picker")

	local darknessPicker = Template:WaitForChild("DarknessPicker")
	local darknessSlider = darknessPicker:WaitForChild("Slider")

	local ColorDisplay = Template:WaitForChild("ColorDisplay")

	local buttonDown = false
	local movingSlider = false

	local function updateColor(centreOfWheel)
		local ColorPickerCentre = Vector2.new(
			ColorWheel.Picker.AbsolutePosition.X + (ColorWheel.Picker.AbsoluteSize.X/2),
			ColorWheel.Picker.AbsolutePosition.Y + (ColorWheel.Picker.AbsoluteSize.Y/2)
		)
		local h = (math.pi - math.atan2(ColorPickerCentre.Y - centreOfWheel.Y, ColorPickerCentre.X - centreOfWheel.X)) / (math.pi * 2)

		local s = (centreOfWheel - ColorPickerCentre).Magnitude / (ColorWheel.AbsoluteSize.X/2)

		local v = math.abs((darknessSlider.AbsolutePosition.Y - darknessPicker.AbsolutePosition.Y) / darknessPicker.AbsoluteSize.Y - 1)
		local hsv = Color3.fromHSV(math.clamp(h, 0, 1), math.clamp(s, 0, 1), math.clamp(v, 0, 1))
		ColorDisplay.ImageColor3 = hsv
		darknessPicker.UIGradient.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, hsv), 
			ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
		}
	end

	ColorWheel.MouseButton1Down:Connect(function()
		buttonDown = true
	end)

	darknessPicker.MouseButton1Down:Connect(function()
		movingSlider = true
	end)

	Template.Confirm.MouseButton1Click:Connect(function()
		local ColorList = {}
		for _, Part in Tool:GetDescendants() do
			if Part:HasTag(Tag) then
				table.insert(ColorList, {Part, ColorDisplay.ImageColor3})
			end
		end
		script.Parent.ApplyColors:FireServer(ColorList)
	end)

	uis.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		buttonDown = false
		movingSlider = false
	end)

	uis.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local mousePos = uis:GetMouseLocation() - Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)

		local centreOfWheel = Vector2.new(ColorWheel.AbsolutePosition.X + (ColorWheel.AbsoluteSize.X/2), ColorWheel.AbsolutePosition.Y + (ColorWheel.AbsoluteSize.Y/2))

		local distanceFromWheel = (mousePos - centreOfWheel).Magnitude

		if distanceFromWheel <= ColorWheel.AbsoluteSize.X/2 and buttonDown then
			wheelPicker.Position = UDim2.new(0, mousePos.X - ColorWheel.AbsolutePosition.X, 0, mousePos.Y - ColorWheel.AbsolutePosition.Y)
		elseif movingSlider then

			darknessSlider.Position = UDim2.new(darknessSlider.Position.X.Scale, 0, 0, 
				math.clamp(
					mousePos.Y - darknessPicker.AbsolutePosition.Y, 
					0, 
					darknessPicker.AbsoluteSize.Y)
			)	
		end
		updateColor(centreOfWheel)
	end)
end

Gui.Close.MouseButton1Click:Connect(function()
	Gui.ListOfColorWheels.Visible = false
	Gui.Close.Visible = false
	Gui.Open.Visible = true
end)

Gui.Open.MouseButton1Click:Connect(function()
	Gui.ListOfColorWheels.Visible = true
	Gui.Close.Visible = true
	Gui.Open.Visible = false
end)

Tool.Equipped:Connect(function()
	script.Parent.Enabled = true
	script.Parent.Parent = Player.PlayerGui
	for _, Frame in Gui.ListOfColorWheels:GetDescendants() do
		if Frame:IsA("Frame") then
			Frame.Visible = true
		end
	end
	if not AddedGui then
		AddedGui = true
		local ColorParts = {}
		local DifferentTags = {}
		for _, Child in Tool:GetDescendants() do
			for _, Tag in Child:GetTags() do
				if string.find(Tag, "Color") then
					ColorParts[Child] = Tag
					if not table.find(DifferentTags, Tag) then
						table.insert(DifferentTags, Tag)
						AddNewTemplate(Tag)
					end
				end
			end
		end
	end
end)

Tool.Unequipped:Connect(function()
	script.Parent.Parent = Tool
	script.Parent.Enabled = false
end)