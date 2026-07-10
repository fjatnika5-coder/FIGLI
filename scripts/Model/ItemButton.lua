--[[SERVICES]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--[[MODULES]]--

--[[CONSTANTS]]--

--[[GLOBALS]]--

local ItemButton = {}

--[[LOCAL FUNCTIONS]]--

local mouse = Players.LocalPlayer:GetMouse()

--[[MODULAR FUNCTIONS]]--

function ItemButton.ConnectItemButtonAnimations(ItemButton: Frame)

	local gradientTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential)
	local showGradientTween = TweenService:Create(
		ItemButton.Gradient,
		gradientTweenInfo,
		{BackgroundTransparency = 0.5}
	)
	local hideGradientTween = TweenService:Create(
		ItemButton.Gradient,
		gradientTweenInfo,
		{BackgroundTransparency = 1}
	)

	local function showGradient()

		showGradientTween:Play()

	end

	local function hideGradient()

		hideGradientTween:Play()

	end

	local updateRotationConnection = nil

	local function updateRotation()

		local mousePosition = Vector2.new(mouse.X, mouse.Y)
		local buttonPosition = ItemButton.AbsolutePosition + ItemButton.AbsoluteSize / 2
		local angle = math.deg(math.atan((mousePosition - buttonPosition).Y / (mousePosition - buttonPosition).X))
		
		ItemButton.Gradient.UIGradient.Rotation = angle + 180

	end

	local function startUpdatingRotation()

		--updateRotationConnection = RunService.Heartbeat:Connect(updateRotation)

	end

	local function stopUpdatingRotation()

		if updateRotationConnection then

			updateRotationConnection:Disconnect()

		end

	end

	ItemButton.Gradient.Position = UDim2.fromScale(0, 0)
	hideGradient()

	local button = ItemButton.Button
	button.MouseEnter:Connect(function()

		startUpdatingRotation()
		showGradient()

	end)
	button.MouseLeave:Connect(function()

		stopUpdatingRotation()
		hideGradient()

	end)

end

return ItemButton
