local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIEffectsModule = {}

local defaultTweenInfo = {
	ShopOpen = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	ShopClose = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
	BlurOpen = TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	BlurClose = TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.In),
	Camera = TweenInfo.new(0.35)
}

function UIEffectsModule.Initialize(UI, options)
	options = options or {}

	local config = {
		useBlur = options.useBlur ~= nil and options.useBlur or true,
		useCamera = options.useCamera ~= nil and options.useCamera or true,
		blurSize = options.blurSize or 24,
		cameraZoomFactor = options.cameraZoomFactor or 1.15,
		openSize = options.openSize or UDim2.new(0.8, 0, 0.8, 0),
		openPosition = options.openPosition or UDim2.new(0.5, 0, 0.5, 0),
		closeSize = options.closeSize or UDim2.new(0, 0, 0, 0),
		closePosition = options.closePosition or UDim2.new(0.5, 0, 0.5, 0),
		tweenInfo = options.tweenInfo or defaultTweenInfo
	}

	local Camera = workspace.CurrentCamera
	local Blur = nil

	if config.useBlur then
		Blur = Lighting:FindFirstChild("UI Blur") or Instance.new("BlurEffect")
		Blur.Name = "UI Blur"
		Blur.Parent = Lighting
		Blur.Size = 0
	end

	local Tweens = {}

	Tweens.UIOpen = TweenService:Create(UI, config.tweenInfo.ShopOpen, {
		Size = config.openSize,
		Position = config.openPosition
	})

	Tweens.UIClose = TweenService:Create(UI, config.tweenInfo.ShopClose, {
		Size = config.closeSize,
		Position = config.closePosition
	})

	if config.useBlur and Blur then
		Tweens.BlurOpen = TweenService:Create(Blur, config.tweenInfo.BlurOpen, {
			Size = config.blurSize
		})

		Tweens.BlurClose = TweenService:Create(Blur, config.tweenInfo.BlurClose, {
			Size = 0
		})
	end

	if config.useCamera then
		local originalFOV = Camera.FieldOfView
		Tweens.CameraOpen = TweenService:Create(Camera, config.tweenInfo.Camera, {
			FieldOfView = originalFOV * config.cameraZoomFactor
		})

		Tweens.CameraClose = TweenService:Create(Camera, config.tweenInfo.Camera, {
			FieldOfView = originalFOV
		})
	end

	Tweens.UIClose.Completed:Connect(function()
		if not UI:GetAttribute("Toggled") then
			UI.Visible = false
		end
	end)

	local function Toggle(isOpen)
		if isOpen then
			UI.Visible = true
		end

		if isOpen then
			Tweens.UIOpen:Play()
		else
			Tweens.UIClose:Play()
		end

		if config.useBlur and Blur then
			if isOpen then
				Tweens.BlurOpen:Play()
			else
				Tweens.BlurClose:Play()
			end
		end

		if config.useCamera then
			if isOpen then
				Tweens.CameraOpen:Play()
			else
				Tweens.CameraClose:Play()
			end
		end

		UI:SetAttribute("Toggled", isOpen)

		return isOpen
	end

	UI:GetAttributeChangedSignal("Toggled"):Connect(function()
		local isOpen = UI:GetAttribute("Toggled")
		Toggle(isOpen)
	end)

	UI:SetAttribute("Toggled", false)
	UI.Visible = false

	return {
		UI = UI,
		Blur = Blur,
		Camera = Camera,
		Toggle = function(isOpen)
			return Toggle(isOpen)
		end,
		IsOpen = function()
			return UI:GetAttribute("Toggled")
		end,
		Open = function()
			return Toggle(true)
		end,
		Close = function()
			return Toggle(false)
		end,
		ToggleState = function()
			return Toggle(not UI:GetAttribute("Toggled"))
		end
	}
end

return UIEffectsModule