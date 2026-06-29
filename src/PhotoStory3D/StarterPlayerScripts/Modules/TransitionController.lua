--!nonstrict
-- TransitionController: cover fade/flash + blur + vignette. Caption ditangani TextController.
-- Semua tween dilacak janitor -> cancel saat cleanup. Tanpa RenderStepped.

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local TransitionController = {}
TransitionController.__index = TransitionController

function TransitionController.new(screen, config, lowEnd, janitor)
	local self = setmetatable({}, TransitionController)
	self._janitor = janitor
	self._config = config
	self._lowEnd = lowEnd == true

	-- Cover fade/flash.
	local cover = Instance.new("Frame")
	cover.Name = "Cover"
	cover.Size = UDim2.fromScale(1, 1)
	cover.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cover.BorderSizePixel = 0
	cover.BackgroundTransparency = 1
	cover.Visible = false
	cover.ZIndex = 50
	cover.Parent = screen
	self._cover = cover

	-- Overlay blur-fallback (semi-transparan) untuk LowEnd / mobile.
	local soft = Instance.new("Frame")
	soft.Name = "SoftBlur"
	soft.Size = UDim2.fromScale(1, 1)
	soft.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	soft.BorderSizePixel = 0
	soft.BackgroundTransparency = 1
	soft.Visible = false
	soft.ZIndex = 40
	soft.Parent = screen
	self._soft = soft

	-- Vignette opsional.
	if typeof(config.VignetteImage) == "string" and string.match(config.VignetteImage, "^rbxassetid://%d+$") then
		local vig = Instance.new("ImageLabel")
		vig.Name = "Vignette"
		vig.Size = UDim2.fromScale(1, 1)
		vig.BackgroundTransparency = 1
		vig.Image = config.VignetteImage
		vig.ImageTransparency = 1
		vig.ScaleType = Enum.ScaleType.Stretch
		vig.ZIndex = 18
		vig.Parent = screen
		self._vignette = vig
	end

	return self
end

function TransitionController:_coverColor(kind)
	if kind == "FadeWhite" or kind == "FlashWhite" then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(0, 0, 0)
end

function TransitionController:_tween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	self._janitor:Add(tw, "Cancel")
	tw:Play()
	tw.Completed:Wait()
	return tw
end

function TransitionController:CoverInstant(kind)
	self._cover.BackgroundColor3 = self._coverColor(kind or "FadeBlack")
	self._cover.BackgroundTransparency = 0
	self._cover.Visible = true
end

function TransitionController:_blurReal(target, duration)
	local blur = Lighting:FindFirstChild("PhotoStoryBlur")
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "PhotoStoryBlur"
		blur.Size = 0
		blur.Parent = Lighting
		self._janitor:Add(blur, "Destroy")
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(blur, info, { Size = target })
	self._janitor:Add(tw, "Cancel")
	tw:Play()
end

function TransitionController:_blurSoft(target, duration)
	self._soft.Visible = true
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(self._soft, info, { BackgroundTransparency = target })
	self._janitor:Add(tw, "Cancel")
	tw:Play()
end

function TransitionController:ResetBlur()
	if self._lowEnd then
		if self._soft.Visible then
			self:_blurSoft(1, 0.2)
		end
	else
		local blur = Lighting:FindFirstChild("PhotoStoryBlur")
		if blur then
			self:_blurReal(0, 0.2)
		end
	end
end

function TransitionController:Play(kind, phase, duration)
	kind = kind or "FadeBlack"
	duration = math.max(duration or 0.45, 0.05)
	local cover = self._cover

	if kind == "Blur" then
		if self._lowEnd then
			-- Fallback ringan: overlay putih semi-transparan.
			if phase == "In" then
				self:_blurSoft(1, duration)
			else
				self:_blurSoft(0.5, duration)
				task.wait(duration)
			end
		else
			if phase == "In" then
				self:_blurReal(0, duration)
			else
				self:_blurReal(18, duration)
				task.wait(duration)
			end
		end
		return
	end

	cover.BackgroundColor3 = self._coverColor(kind)
	cover.Visible = true

	if phase == "In" then
		cover.BackgroundTransparency = 0
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		self:_tween(cover, info, { BackgroundTransparency = 1 })
		cover.Visible = false
	else
		cover.BackgroundTransparency = 1
		local dur = duration
		if kind == "FlashWhite" then
			dur = math.min(0.12, duration)
		end
		local info = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		self:_tween(cover, info, { BackgroundTransparency = 0 })
	end
end

function TransitionController:ShowVignette(on, duration)
	if not self._vignette then
		return
	end
	if self._lowEnd then
		self._vignette.ImageTransparency = 1
		return
	end
	local info = TweenInfo.new(duration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(self._vignette, info, { ImageTransparency = on and 0.15 or 1 })
	self._janitor:Add(tw, "Cancel")
	tw:Play()
end

return TransitionController
