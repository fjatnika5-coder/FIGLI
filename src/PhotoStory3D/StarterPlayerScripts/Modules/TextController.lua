--!nonstrict
-- TextController: per-kata dekat karakter (WorldToViewportPoint dari Head/HRP).
-- Tiap kata = TextLabel sendiri, pop/float/wiggle, warna bergantian.
-- Backward compatible: config lama {Text,StartTime,Typewriter,Fade,Bounce} tetap jalan
-- (mode default = PerWordNearCharacter dengan target Alternate).
-- Cleanup: semua label per-scene dihancurkan di ClearWords().

local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local Workspace     = game:GetService("Workspace")

local TextController = {}
TextController.__index = TextController

-- Default warna per kata (cycled)
local DEFAULT_COLORS = {
	Color3.fromRGB(255, 190, 220),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 220, 255),
	Color3.fromRGB(255, 230, 160),
}

local DEFAULT_FONT        = Enum.Font.GothamBold
local DEFAULT_WORD_DELAY  = 0.22
local DEFAULT_LIFETIME    = 1.15
local DEFAULT_MODE        = "PerWordNearCharacter"
local DEFAULT_TARGET      = "Alternate"

-- Offset Y kamera (pixel) dekat kepala karakter
local HEAD_Y_OFFSET = -90

local function splitWords(text)
	local t = {}
	for w in string.gmatch(text, "%S+") do t[#t+1] = w end
	return t
end

-- Ambil posisi 3D kepala/HRP dari clone model
local function getHeadWorld(cloneObj)
	if not cloneObj or not cloneObj._model then return nil end
	local m = cloneObj._model
	local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
	if head and head:IsA("BasePart") then
		return head.Position + Vector3.new(0, 0.5, 0)
	end
	return nil
end

-- Convert world pos -> screen UDim2 (scale). Mengembalikan pos, isOnScreen.
local function worldToScreen(worldPos)
	if not worldPos then return nil, false end
	local cam = Workspace.CurrentCamera
	local vp  = cam.ViewportSize
	local screenVec, _, onScreen = cam:WorldToViewportPoint(worldPos)
	if not onScreen or screenVec.Z < 0 then return nil, false end
	local sx = screenVec.X / vp.X
	local sy = screenVec.Y / vp.Y
	if sx < 0.03 or sx > 0.97 or sy < 0.03 or sy > 0.97 then return nil, false end
	return UDim2.fromScale(sx, sy), true
end

function TextController.new(screen, config, lowEnd, janitor)
	local self    = setmetatable({}, TextController)
	self._screen  = screen
	self._config  = config
	self._lowEnd  = lowEnd == true
	self._janitor = janitor
	self._clones  = {}       -- {Girl=AvatarClone, Boy=AvatarClone}
	self._words   = {}       -- semua TextLabel aktif scene ini
	self._playThreads = {}   -- task threads (untuk cancel)
	return self
end

function TextController:SetClones(clones)
	self._clones = clones or {}
end

-- Tidak perlu RenderStepped persistent; cleanup dipanggil via janitor.
function TextController:Begin()
	self._janitor:Add(function()
		self:ClearWords()
	end)
end

function TextController:SetScene(textCfg)
	self:ClearWords()
	-- tidak perlu setup awal (label dibuat saat Play)
end

-- Hancurkan semua label kata yang aktif
function TextController:ClearWords()
	for _, th in ipairs(self._playThreads) do
		pcall(task.cancel, th)
	end
	self._playThreads = {}
	for _, lbl in ipairs(self._words) do
		if typeof(lbl) == "Instance" and lbl.Parent then
			pcall(function() lbl:Destroy() end)
		end
	end
	self._words = {}
end

-- Buat 1 TextLabel kata di posisi screen
local function makeWordLabel(screen, word, pos, color, wordIdx, lowEnd)
	local lbl = Instance.new("TextLabel")
	lbl.Name            = "W_" .. word
	lbl.BackgroundTransparency = 1
	lbl.AnchorPoint     = Vector2.new(0.5, 0.5)
	lbl.Size            = UDim2.fromScale(0.13, 0.048)
	lbl.Position        = pos
	lbl.TextScaled      = true
	lbl.Font            = DEFAULT_FONT
	lbl.Text            = word
	lbl.TextColor3      = color
	lbl.TextTransparency = 1
	lbl.ZIndex          = 35
	lbl.Parent          = screen

	local stroke = Instance.new("UIStroke")
	stroke.Thickness    = 2.5
	stroke.Color        = Color3.fromRGB(0, 0, 0)
	stroke.Transparency = 0.25
	stroke.Parent       = lbl

	local sc = Instance.new("UITextSizeConstraint")
	sc.MaxTextSize = 32
	sc.MinTextSize = 8
	sc.Parent = lbl

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.4
	uiScale.Parent = lbl

	return lbl, uiScale
end

-- Animasi masuk + float + wiggle untuk 1 kata, lalu fade keluar setelah lifetime
local function animateWord(lbl, uiScale, wordIdx, lifetime, lowEnd, wordItems)
	-- Pop in
	TweenService:Create(uiScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()

	-- Float naik pelan
	local startPos = lbl.Position
	local floatPos = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale - 0.05, startPos.Y.Offset)
	TweenService:Create(lbl, TweenInfo.new(lifetime + 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = floatPos }):Play()

	-- Sway halus (hanya non-lowend)
	if not lowEnd then
		local targetRot = (wordIdx % 2 == 0) and 4 or -4
		TweenService:Create(lbl, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = targetRot }):Play()
	end

	-- Fade out setelah lifetime
	task.delay(lifetime, function()
		if not lbl.Parent then return end
		TweenService:Create(lbl, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
		task.delay(0.3, function()
			pcall(function() lbl:Destroy() end)
		end)
	end)
end

-- Tentukan posisi screen untuk target role
function TextController:_posForTarget(role, wordIdx)
	local cloneObj = nil
	if role == "Girl" then
		cloneObj = self._clones.Girl
	elseif role == "Boy" then
		cloneObj = self._clones.Boy
	else -- Alternate
		cloneObj = (wordIdx % 2 == 1) and self._clones.Girl or self._clones.Boy
	end

	local worldPos = getHeadWorld(cloneObj)
	local screenPos, onScreen = worldToScreen(worldPos)

	if onScreen then
		-- Offset ke atas dari posisi kepala + random kecil
		local cam = Workspace.CurrentCamera
		local vpH = cam.ViewportSize.Y
		local offsetY = HEAD_Y_OFFSET / vpH
		local rx = (math.random() - 0.5) * 0.07
		local ry = (math.random() - 0.5) * 0.035
		return UDim2.fromScale(
			math.clamp(screenPos.X.Scale + rx, 0.07, 0.90),
			math.clamp(screenPos.Y.Scale + offsetY + ry, 0.05, 0.88)
		)
	else
		-- Fallback: kiri untuk Girl, kanan untuk Boy
		local isGirl = (role == "Girl") or (role == "Alternate" and wordIdx % 2 == 1)
		local baseX  = isGirl and 0.28 or 0.70
		return UDim2.fromScale(baseX + (math.random() - 0.5) * 0.06, 0.60 + (math.random() - 0.5) * 0.05)
	end
end

-- Play: spawn kata satu per satu dekat karakter. Cancellable via token.
function TextController:Play(textCfg, token)
	if not textCfg or not textCfg.Text or textCfg.Text == "" then return end
	local d = self._config.TextDefaults

	local startTime  = textCfg.StartTime or 0
	local mode       = textCfg.Mode      or DEFAULT_MODE
	local target     = textCfg.Target    or DEFAULT_TARGET
	local wordDelay  = textCfg.WordDelay or DEFAULT_WORD_DELAY
	local lifetime   = textCfg.WordLifetime or DEFAULT_LIFETIME
	local colors     = textCfg.Colors    or DEFAULT_COLORS

	-- Tunggu StartTime
	if startTime > 0 then
		local el = 0
		while el < startTime do
			if token.cancelled then return end
			el += task.wait()
		end
	end
	if token.cancelled then return end

	-- Kalau bukan mode per-kata, fallback ke mode lama (satu label di bawah)
	if mode ~= "PerWordNearCharacter" then
		self:_playLegacy(textCfg, token)
		return
	end

	local words = splitWords(textCfg.Text)
	if #words == 0 then return end

	local wordItems = self._words

	for i, word in ipairs(words) do
		if token.cancelled then return end

		local pos   = self:_posForTarget(target, i)
		local color = colors[((i - 1) % #colors) + 1] or Color3.new(1, 1, 1)

		local lbl, uiScale = makeWordLabel(self._screen, word, pos, color, i, self._lowEnd)
		wordItems[#wordItems + 1] = lbl

		animateWord(lbl, uiScale, i, lifetime, self._lowEnd, wordItems)

		if i < #words then
			task.wait(wordDelay)
		end
	end
end

-- Mode lama: satu caption di bawah layar (Typewriter/Fade/Bounce)
function TextController:_playLegacy(textCfg, token)
	local d = self._config.TextDefaults

	local holder = Instance.new("Frame")
	holder.Name = "CaptionLegacy"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Size     = textCfg.Size     or d.Size
	holder.Position = textCfg.Position or d.Position
	holder.ZIndex   = 30
	holder.Parent   = self._screen

	local scale = Instance.new("UIScale")
	scale.Scale = 0.7
	scale.Parent = holder

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.TextScaled = true
	lbl.Font = textCfg.Font or d.Font
	lbl.Text = textCfg.Text
	lbl.TextColor3 = textCfg.TextColor3 or d.TextColor3
	lbl.TextTransparency = 1
	lbl.ZIndex = 31
	lbl.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = textCfg.StrokeColor3 or d.StrokeColor3
	stroke.Transparency = 1
	stroke.Parent = lbl

	local sc = Instance.new("UITextSizeConstraint")
	sc.MaxTextSize = 52; sc.MinTextSize = 10
	sc.Parent = lbl

	self._words[#self._words + 1] = holder

	-- Pop + fade in
	local popStyle = (textCfg.Bounce ~= false) and Enum.EasingStyle.Back or Enum.EasingStyle.Quart
	TweenService:Create(scale, TweenInfo.new(0.32, popStyle, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Transparency = textCfg.StrokeTransparency or d.StrokeTransparency }):Play()

	if textCfg.Typewriter then
		local total = utf8.len(lbl.ContentText) or #lbl.ContentText
		local speed = textCfg.TypewriterSpeed or d.TypewriterSpeed
		local shown = 0
		lbl.MaxVisibleGraphemes = 0
		while shown < total do
			if token.cancelled then break end
			shown += speed * task.wait()
			lbl.MaxVisibleGraphemes = math.floor(shown)
		end
		lbl.MaxVisibleGraphemes = -1
	end
end

function TextController:FadeOut(duration)
	-- Kata per-kata sudah punya lifetime sendiri; legacy holder di-fade out
	for _, item in ipairs(self._words) do
		if typeof(item) == "Instance" and item.Parent then
			if item:IsA("Frame") then
				-- Legacy holder
				TweenService:Create(item, TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad), {}):Play()
				task.delay((duration or 0.25) + 0.05, function()
					pcall(function() item:Destroy() end)
				end)
			end
		end
	end
end

return TextController
