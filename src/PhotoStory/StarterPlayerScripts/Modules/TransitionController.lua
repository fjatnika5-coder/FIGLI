--!nonstrict
-- TransitionController: efek antar-scene berbasis UI + TweenService (tanpa Lighting,
-- tanpa RenderStepped). Semua tween dilacak janitor -> cancel saat cleanup.
--
-- Tipe: Fade, FadeWhite, WhiteFlash, DarkIntro, Zoom, Blur, Slide.
-- Phase "In"  = layar tertutup -> konten muncul.
-- Phase "Out" = konten terlihat -> layar tertutup (siap ganti scene).

local TweenService = game:GetService("TweenService")

local TransitionController = {}
TransitionController.__index = TransitionController

local EASE = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- layers = { Cover = Frame (fullscreen, di atas), Scale = UIScale (di konten), Root = Frame (konten) }
function TransitionController.new(layers, lowEnd, janitor)
	local self = setmetatable({}, TransitionController)
	self._cover = layers.Cover
	self._scale = layers.Scale
	self._root = layers.Root
	self._lowEnd = lowEnd == true
	self._janitor = janitor
	return self
end

function TransitionController:_coverColor(kind)
	if kind == "FadeWhite" or kind == "WhiteFlash" then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(0, 0, 0)
end

-- Jalankan satu tween dan tunggu selesai (cancellable via janitor:Cancel).
function TransitionController:_tween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	self._janitor:Add(tw, "Cancel")
	tw:Play()
	tw.Completed:Wait()
end

-- Tutup penuh tanpa animasi (dipakai sebelum scene pertama / sebelum ganti visual).
function TransitionController:CoverInstant(kind)
	self._cover.BackgroundColor3 = self._coverColor(kind or "Fade")
	self._cover.BackgroundTransparency = 0
	self._cover.Visible = true
	if self._scale then
		self._scale.Scale = 1
	end
end

function TransitionController:Play(kind, phase, duration)
	kind = kind or "Fade"
	duration = math.max(duration or 0.45, 0.05)
	if self._lowEnd then
		-- Low-end: efek berat diturunkan jadi fade biasa.
		if kind == "Blur" or kind == "Zoom" or kind == "Slide" then
			kind = "Fade"
		end
	end

	local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local cover = self._cover
	cover.BackgroundColor3 = self._coverColor(kind)

	-- Reset bantu.
	if self._scale then
		self._scale.Scale = 1
	end
	if self._root then
		self._root.Position = UDim2.fromScale(0.5, 0.5)
	end

	if kind == "Slide" then
		cover.Visible = false
		if phase == "In" then
			self._root.Position = UDim2.fromScale(1.5, 0.5)
			self:_tween(self._root, info, { Position = UDim2.fromScale(0.5, 0.5) })
		else
			self:_tween(self._root, info, { Position = UDim2.fromScale(-0.5, 0.5) })
		end
		return
	end

	if kind == "Zoom" then
		cover.Visible = true
		if phase == "In" then
			self._scale.Scale = 1.12
			cover.BackgroundTransparency = 0
			TweenService:Create(self._scale, info, { Scale = 1 }):Play()
			self:_tween(cover, info, { BackgroundTransparency = 1 })
			cover.Visible = false
		else
			cover.BackgroundTransparency = 1
			TweenService:Create(self._scale, info, { Scale = 1.12 }):Play()
			self:_tween(cover, info, { BackgroundTransparency = 0 })
		end
		return
	end

	if kind == "Blur" then
		-- Approksimasi blur via UI: pop scale kecil + fade overlay (tanpa Lighting).
		cover.Visible = true
		if phase == "In" then
			self._scale.Scale = 1.05
			cover.BackgroundTransparency = 0.35
			TweenService:Create(self._scale, info, { Scale = 1 }):Play()
			self:_tween(cover, info, { BackgroundTransparency = 1 })
			cover.Visible = false
		else
			cover.BackgroundTransparency = 1
			TweenService:Create(self._scale, info, { Scale = 1.05 }):Play()
			self:_tween(cover, info, { BackgroundTransparency = 0.35 })
		end
		return
	end

	-- Fade / FadeWhite / WhiteFlash / DarkIntro (cover transparency).
	cover.Visible = true
	if phase == "In" then
		cover.BackgroundTransparency = 0
		if kind == "DarkIntro" then
			task.wait(math.min(0.6, duration * 0.4)) -- tahan gelap sebentar
		end
		self:_tween(cover, info, { BackgroundTransparency = 1 })
		cover.Visible = false
	else
		cover.BackgroundTransparency = 1
		local outInfo = info
		if kind == "WhiteFlash" then
			outInfo = TweenInfo.new(math.min(0.12, duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
		self:_tween(cover, outInfo, { BackgroundTransparency = 0 })
	end
end

return TransitionController
