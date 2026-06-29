--!nonstrict
-- TransitionController: UI overlay (fade/flash/vignette/caption) + blur Lighting.
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

	-- Cover fade/flash (paling atas).
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

	-- Vignette opsional (gambar bingkai gelap).
	if typeof(config.VignetteImage) == "string" and string.match(config.VignetteImage, "^rbxassetid://%d+$") then
		local vig = Instance.new("ImageLabel")
		vig.Name = "Vignette"
		vig.Size = UDim2.fromScale(1, 1)
		vig.BackgroundTransparency = 1
		vig.Image = config.VignetteImage
		vig.ImageTransparency = 1
		vig.ScaleType = Enum.ScaleType.Stretch
		vig.ZIndex = 20
		vig.Parent = screen
		self._vignette = vig
	end

	-- Caption + UIScale (bounce).
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.BackgroundTransparency = 1
	caption.TextScaled = true
	caption.RichText = false
	caption.Text = ""
	caption.Visible = false
	caption.ZIndex = 30
	caption.Parent = screen
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = caption
	local cscale = Instance.new("UIScale")
	cscale.Scale = 1
	cscale.Parent = caption
	self._caption = caption
	self._captionStroke = stroke
	self._captionScale = cscale

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

function TransitionController:_setBlur(target, duration)
	if self._lowEnd then
		return
	end
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

-- Play(kind, phase, duration). phase "In" = buka tirai, "Out" = tutup tirai.
function TransitionController:Play(kind, phase, duration)
	kind = kind or "FadeBlack"
	duration = math.max(duration or 0.45, 0.05)
	local cover = self._cover

	if kind == "Blur" then
		if phase == "In" then
			self:_setBlur(0, duration)
		else
			self:_setBlur(self._lowEnd and 0 or 18, duration)
			task.wait(duration)
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

-- Bersihkan blur (mis. sebelum scene yang TransitionIn-nya bukan Blur).
function TransitionController:ResetBlur()
	local blur = Lighting:FindFirstChild("PhotoStoryBlur")
	if blur then
		self:_setBlur(0, 0.2)
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

-- Susun caption untuk scene (belum animasi).
function TransitionController:SetCaption(textCfg)
	local caption = self._caption
	local d = self._config.TextDefaults
	if not textCfg or not textCfg.Text or textCfg.Text == "" then
		caption.Visible = false
		caption.Text = ""
		return
	end
	caption.Visible = true
	caption.Position = textCfg.Position or d.Position
	caption.Size = textCfg.Size or d.Size
	caption.Font = textCfg.Font or d.Font
	caption.TextColor3 = textCfg.TextColor3 or d.TextColor3
	self._captionStroke.Color = textCfg.StrokeColor3 or d.StrokeColor3
	caption.Text = textCfg.Text

	local fade = textCfg.Fade == true
	caption.TextTransparency = fade and 1 or 0
	self._captionStroke.Transparency = fade and 1 or (textCfg.StrokeTransparency or d.StrokeTransparency)
	caption.MaxVisibleGraphemes = textCfg.Typewriter and 0 or -1
	self._captionScale.Scale = textCfg.Bounce and 0.85 or 1
end

-- Animasikan caption (delay StartTime, fade, bounce, typewriter). Cancellable via token.
function TransitionController:PlayCaption(textCfg, token)
	if not textCfg or not textCfg.Text or textCfg.Text == "" then
		return
	end
	local caption = self._caption
	local d = self._config.TextDefaults

	if textCfg.StartTime and textCfg.StartTime > 0 then
		local elapsed = 0
		while elapsed < textCfg.StartTime do
			if token.cancelled then
				return
			end
			elapsed += task.wait()
		end
	end
	if token.cancelled then
		return
	end

	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if textCfg.Fade then
		local strokeTarget = textCfg.StrokeTransparency or d.StrokeTransparency
		local tw = TweenService:Create(caption, info, { TextTransparency = 0 })
		local tw2 = TweenService:Create(self._captionStroke, info, { Transparency = strokeTarget })
		self._janitor:Add(tw, "Cancel")
		self._janitor:Add(tw2, "Cancel")
		tw:Play()
		tw2:Play()
	end
	if textCfg.Bounce then
		local binfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tw = TweenService:Create(self._captionScale, binfo, { Scale = 1 })
		self._janitor:Add(tw, "Cancel")
		tw:Play()
	end

	if textCfg.Typewriter then
		local total = utf8.len(caption.ContentText) or #caption.ContentText
		local speed = textCfg.TypewriterSpeed or d.TypewriterSpeed
		local shown = 0
		while shown < total do
			if token.cancelled then
				return
			end
			shown += speed * task.wait()
			caption.MaxVisibleGraphemes = math.floor(shown)
		end
		caption.MaxVisibleGraphemes = -1
	end
end

return TransitionController
