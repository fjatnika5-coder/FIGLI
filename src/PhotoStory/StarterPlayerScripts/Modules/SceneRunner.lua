--!nonstrict
-- SceneRunner: orkestrasi cutscene Photo Story (UI + ViewportFrame).
-- Membangun UI, karakter, transisi, text, musik; menjalankan tiap scene;
-- membersihkan total saat selesai/dibatalkan.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("PhotoStoryConfig"))

local Janitor = require(script.Parent.Janitor)
local AssetPreloader = require(script.Parent.AssetPreloader)
local ViewportCharacter = require(script.Parent.ViewportCharacter)
local TransitionController = require(script.Parent.TransitionController)

local SceneRunner = {}
SceneRunner.__index = SceneRunner

local LocalPlayer = Players.LocalPlayer

-- Deteksi low-end sederhana: device sentuh non-tablet kecil / memori rendah.
local function detectLowEnd()
	if not Config.AutoLowEnd then
		return Config.LowEndMode
	end
	if Config.LowEndMode then
		return true
	end
	-- Touch tanpa keyboard/mouse = mobile; anggap perlu hemat.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	return false
end

function SceneRunner.new()
	local self = setmetatable({}, SceneRunner)
	self._janitor = Janitor.new()
	self._token = { cancelled = false }
	self._finished = false
	self._chars = {} -- ["PlayerA"|"PlayerB"] = ViewportCharacter
	self._images = {} -- [Name] = ImageLabel
	self._lowEnd = detectLowEnd()
	self._onFinish = nil
	return self
end

function SceneRunner:_cancelled()
	return self._token.cancelled
end

-- Wait yang bisa dibatalkan (tanpa loop permanen; hanya saat scene aktif).
function SceneRunner:_wait(duration)
	local elapsed = 0
	while elapsed < duration do
		if self._token.cancelled then
			return false
		end
		elapsed += task.wait()
	end
	return not self._token.cancelled
end

function SceneRunner:_buildUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "PhotoStoryGui"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.DisplayOrder = 5000
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	self._janitor:Add(screen, "Destroy")
	self._screen = screen

	-- Backdrop hitam menutup area letterbox.
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.ZIndex = 1
	backdrop.Parent = screen

	-- Frame portrait 9:16 yang di-fit ke layar.
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.ZIndex = 2
	stage.Parent = screen
	self._stage = stage

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = Config.AspectRatio or (9 / 16)
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.DominantAxis = Enum.DominantAxis.Height
	ratio.Parent = stage

	-- UIScale untuk transisi zoom/blur (di stage).
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = stage
	self._scale = scale

	-- Background image.
	local bg = Instance.new("ImageLabel")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.ScaleType = Enum.ScaleType.Crop
	bg.Image = ""
	bg.ZIndex = 2
	bg.Parent = stage
	self._bg = bg

	-- Layer karakter (ViewportFrame ditaruh di sini).
	local charLayer = Instance.new("Frame")
	charLayer.Name = "Characters"
	charLayer.Size = UDim2.fromScale(1, 1)
	charLayer.BackgroundTransparency = 1
	charLayer.ZIndex = 3
	charLayer.Parent = stage
	self._charLayer = charLayer

	-- Layer image/sticker/logo.
	local imageLayer = Instance.new("Frame")
	imageLayer.Name = "Images"
	imageLayer.Size = UDim2.fromScale(1, 1)
	imageLayer.BackgroundTransparency = 1
	imageLayer.ZIndex = 4
	imageLayer.Parent = stage
	self._imageLayer = imageLayer

	-- Caption text.
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.BackgroundTransparency = 1
	caption.TextScaled = true
	caption.RichText = false
	caption.Text = ""
	caption.ZIndex = 5
	caption.Parent = stage
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = caption
	self._caption = caption
	self._captionStroke = stroke

	-- Cover transisi (paling atas, di dalam screen agar menutup penuh).
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

	self._transition = TransitionController.new(
		{ Cover = cover, Scale = scale, Root = stage },
		self._lowEnd,
		self._janitor
	)
end

function SceneRunner:_startMusic()
	if not (typeof(Config.MusicSoundId) == "string" and string.match(Config.MusicSoundId, "^rbxassetid://%d+$")) then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = Config.MusicSoundId
	sound.Volume = Config.Volume or 0.5
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	self._janitor:Add(function()
		pcall(function()
			sound:Stop()
		end)
		sound:Destroy()
	end)
end

-- Bangun kedua avatar dari userId (async). Hanya yang valid yang dipakai.
function SceneRunner:_buildCharacters(storyData)
	local map = {
		PlayerA = storyData.PlayerA,
		PlayerB = storyData.PlayerB,
	}
	for slotKey, userId in pairs(map) do
		if userId then
			local vc = ViewportCharacter.new(self._charLayer, userId, self._janitor)
			local ok = vc:Build()
			if ok then
				self._chars[slotKey] = vc
			end
			if self._token.cancelled then
				return
			end
		end
	end
end

function SceneRunner:_applyCharacters(scene)
	-- Sembunyikan semua dulu, stop animasi scene sebelumnya.
	for _, vc in pairs(self._chars) do
		vc:Hide()
	end

	local entries = scene.Characters or {}
	for _, slotName in ipairs({ "Left", "Right" }) do
		local cfg = entries[slotName]
		if cfg then
			local vc = self._chars[cfg.User]
			if vc then
				vc:SetTransform(
					cfg.Position,
					cfg.Scale or Config.CharacterDefaults.Scale,
					cfg.Rotation or Config.CharacterDefaults.Rotation
				)
				vc:PlayAnimation(cfg.AnimationId)
				vc:Show()
			end
		end
	end
end

function SceneRunner:_getImage(name)
	local img = self._images[name]
	if img then
		return img
	end
	img = Instance.new("ImageLabel")
	img.Name = name
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = 4
	img.Visible = false
	img.Parent = self._imageLayer
	self._images[name] = img
	return img
end

function SceneRunner:_applyImages(scene)
	-- Sembunyikan semua image pool dulu.
	for _, img in pairs(self._images) do
		img.Visible = false
	end
	for _, cfg in ipairs(scene.Images or {}) do
		local img = self:_getImage(cfg.Name)
		img.Image = cfg.Image
		img.Position = cfg.Position
		img.Size = cfg.Size
		img.ImageTransparency = cfg.Transparency or 0
		img.Visible = true
	end
end

function SceneRunner:_applyCaption(scene)
	local t = scene.Text
	local caption = self._caption
	if not t or not t.Text or t.Text == "" then
		caption.Text = ""
		caption.Visible = false
		return
	end

	caption.Visible = true
	caption.Position = t.Position or UDim2.fromScale(0.5, 0.6)
	caption.Size = t.Size or UDim2.fromScale(0.78, 0.1)
	caption.Font = t.Font or Config.TextDefaults.Font
	caption.TextColor3 = t.TextColor3 or Config.TextDefaults.TextColor3
	self._captionStroke.Color = t.StrokeColor3 or Config.TextDefaults.StrokeColor3
	self._captionStroke.Transparency = t.StrokeTransparency or Config.TextDefaults.StrokeTransparency
	caption.Text = t.Text

	local fade = t.Fade == true
	caption.TextTransparency = fade and 1 or 0
	self._captionStroke.Transparency = fade and 1 or (t.StrokeTransparency or Config.TextDefaults.StrokeTransparency)

	if t.Typewriter then
		caption.MaxVisibleGraphemes = 0
	else
		caption.MaxVisibleGraphemes = -1
	end
end

-- Animasikan teks (fade + typewriter). Cancellable.
function SceneRunner:_playCaption(scene)
	local t = scene.Text
	if not t or not t.Text or t.Text == "" then
		return
	end
	local caption = self._caption

	if t.Fade then
		local target = 0
		local strokeTarget = t.StrokeTransparency or Config.TextDefaults.StrokeTransparency
		local TweenService = game:GetService("TweenService")
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tw = TweenService:Create(caption, info, { TextTransparency = target })
		local tw2 = TweenService:Create(self._captionStroke, info, { Transparency = strokeTarget })
		self._janitor:Add(tw, "Cancel")
		self._janitor:Add(tw2, "Cancel")
		tw:Play()
		tw2:Play()
	end

	if t.Typewriter then
		local total = utf8.len(caption.ContentText) or #caption.ContentText
		local speed = t.TypewriterSpeed or Config.TextDefaults.TypewriterSpeed
		local shown = 0
		while shown < total do
			if self._token.cancelled then
				return
			end
			shown += speed * task.wait()
			caption.MaxVisibleGraphemes = math.floor(shown)
		end
		caption.MaxVisibleGraphemes = -1
	end
end

function SceneRunner:_runScenes()
	local scenes = Config.Scenes or {}

	-- Mulai tertutup supaya penyusunan scene pertama tidak terlihat.
	self._transition:CoverInstant(scenes[1] and scenes[1].TransitionIn or "Fade")

	for i, scene in ipairs(scenes) do
		if self._token.cancelled then
			break
		end

		AssetPreloader.preloadWindow(scenes, i)

		self._bg.Image = scene.Background or ""
		self:_applyCharacters(scene)
		self:_applyImages(scene)
		self:_applyCaption(scene)

		self._transition:Play(scene.TransitionIn or "Fade", "In", 0.45)
		if self._token.cancelled then
			break
		end

		self:_playCaption(scene)
		if not self:_wait(scene.Duration or 3) then
			break
		end

		self._transition:Play(scene.TransitionOut or "Fade", "Out", 0.4)
	end
end

-- API publik -------------------------------------------------

function SceneRunner:Run(storyData, onFinish)
	self._onFinish = onFinish
	self._buildOk = true

	self:_buildUI()
	self:_startMusic()
	self:_buildCharacters(storyData)

	if not self._token.cancelled then
		self:_runScenes()
	end

	self:_finish()
end

function SceneRunner:Stop()
	self._token.cancelled = true
end

function SceneRunner:_finish()
	if self._finished then
		return
	end
	self._finished = true
	self._token.cancelled = true

	-- Stop animasi semua karakter sebelum destroy (jaga track bersih).
	for _, vc in pairs(self._chars) do
		pcall(function()
			vc:Destroy()
		end)
	end
	self._chars = {}
	self._images = {}

	self._janitor:Destroy()

	if self._onFinish then
		local cb = self._onFinish
		self._onFinish = nil
		task.spawn(cb)
	end
end

return SceneRunner
