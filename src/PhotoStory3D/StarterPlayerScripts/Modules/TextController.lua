--!nonstrict
-- TextController: kata per-kata dekat karakter (WorldToViewportPoint dari Head/HRP).
-- ANTI-NUMPUK: tiap zona (Girl/Boy/Center) punya slot stack vertikal -> kata tidak tumpuk.
-- Cute style: font bulat, gradient halus, shadow + stroke, pop + float + wiggle.
-- Backward compatible: config lama {Typewriter/Fade/Bounce} jalan via _playLegacy.
-- Cleanup: semua label per scene dihancurkan di ClearWords(); slot di-reset.

local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local TextController = {}
TextController.__index = TextController

local DEFAULT_COLORS = {
	Color3.fromRGB(255, 190, 220),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 220, 255),
	Color3.fromRGB(255, 230, 160),
}

local CUTE_FONT       = Enum.Font.FredokaOne
local DEFAULT_DELAY   = 0.22
local DEFAULT_LIFE    = 1.15
local DEFAULT_MODE    = "PerWordNearCharacter"
local DEFAULT_TARGET  = "Alternate"
local DEFAULT_OFFSET  = Vector2.new(0, -82)   -- pixel dari kepala
local DEFAULT_WSIZE   = UDim2.fromScale(0.105, 0.05)
local SLOT_STEP       = 0.052                  -- jarak antar kata dalam stack (scale Y)
local FALLBACK_POS    = UDim2.fromScale(0.5, 0.78)

local function splitWords(text)
	local t = {}
	for w in string.gmatch(text, "%S+") do t[#t + 1] = w end
	return t
end

local function getHeadWorld(cloneObj)
	if not cloneObj or not cloneObj._model then return nil end
	local m    = cloneObj._model
	local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
	if head and head:IsA("BasePart") then
		return head.Position + Vector3.new(0, 0.4, 0)
	end
	return nil
end

-- world -> screen scale; (nil,false) kalau di belakang kamera / mepet pinggir
local function worldToScreen(worldPos)
	if not worldPos then return nil, false end
	local cam = Workspace.CurrentCamera
	local vp  = cam.ViewportSize
	local sv, _, onScreen = cam:WorldToViewportPoint(worldPos)
	if not onScreen or sv.Z < 0 then return nil, false end
	local sx, sy = sv.X / vp.X, sv.Y / vp.Y
	if sx < 0.04 or sx > 0.96 or sy < 0.04 or sy > 0.94 then return nil, false end
	return sx, sy, true
end

function TextController.new(screen, config, lowEnd, janitor)
	local self      = setmetatable({}, TextController)
	self._screen    = screen
	self._config    = config
	self._lowEnd    = lowEnd == true
	self._janitor   = janitor
	self._clones    = {}
	self._words     = {}
	self._slots     = { Girl = 0, Boy = 0, Center = 0 }
	return self
end

function TextController:SetClones(clones)
	self._clones = clones or {}
end

function TextController:Begin()
	self._janitor:Add(function() self:ClearWords() end)
end

function TextController:SetScene(_textCfg)
	self:ClearWords()
end

function TextController:ClearWords()
	for _, lbl in ipairs(self._words) do
		if typeof(lbl) == "Instance" and lbl.Parent then
			pcall(function() lbl:Destroy() end)
		end
	end
	self._words = {}
	self._slots = { Girl = 0, Boy = 0, Center = 0 }
end

-- zona + base screen pos untuk target
function TextController:_zoneBase(target, wordIdx)
	local zone, cloneObj
	if target == "Center" then
		zone = "Center"
	elseif target == "Girl" then
		zone, cloneObj = "Girl", self._clones.Girl
	elseif target == "Boy" then
		zone, cloneObj = "Boy", self._clones.Boy
	else -- Alternate
		if wordIdx % 2 == 1 then zone, cloneObj = "Girl", self._clones.Girl
		else zone, cloneObj = "Boy", self._clones.Boy end
	end

	if zone == "Center" then
		return zone, FALLBACK_POS.X.Scale, FALLBACK_POS.Y.Scale, true
	end

	local sx, sy, on = worldToScreen(getHeadWorld(cloneObj))
	if on then
		return zone, sx, sy, true
	end
	-- fallback kiri (Girl) / kanan (Boy)
	local x = (zone == "Girl") and 0.27 or 0.73
	return zone, x, 0.62, false
end

local function makeWord(screen, word, color, wsize)
	-- holder buat sway+scale tanpa ganggu posisi
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = wsize
	holder.ZIndex = 35
	holder.Parent = screen

	local scale = Instance.new("UIScale")
	scale.Scale = 0.35
	scale.Parent = holder

	-- shadow
	local shadow = Instance.new("TextLabel")
	shadow.BackgroundTransparency = 1
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(2, 3)
	shadow.TextScaled = true
	shadow.Font = CUTE_FONT
	shadow.Text = word
	shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	shadow.TextTransparency = 1
	shadow.ZIndex = 35
	shadow.Parent = holder

	-- main
	local main = Instance.new("TextLabel")
	main.BackgroundTransparency = 1
	main.Size = UDim2.fromScale(1, 1)
	main.TextScaled = true
	main.Font = CUTE_FONT
	main.Text = word
	main.TextColor3 = color
	main.TextTransparency = 1
	main.ZIndex = 36
	main.Parent = holder

	-- gradient halus (atas terang -> bawah warna)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, color),
	})
	grad.Rotation = 90
	grad.Parent = main

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(40, 25, 35)
	stroke.Transparency = 0.15
	stroke.Parent = main

	local sc = Instance.new("UITextSizeConstraint")
	sc.MaxTextSize = 30
	sc.MinTextSize = 8
	sc.Parent = main
	local sc2 = sc:Clone()
	sc2.Parent = shadow

	return holder, scale, main, shadow, stroke
end

-- spawn 1 kata; freeSlot dipanggil saat kata mati untuk lepas slot
function TextController:_spawnWord(word, target, wordIdx, color, life, wsize, offset)
	local zone, bx, by = self:_zoneBase(target, wordIdx)

	-- slot stack: kata baru di bawah, naik pelan -> tidak numpuk
	local slot = self._slots[zone] or 0
	self._slots[zone] = slot + 1
	local vp = Workspace.CurrentCamera.ViewportSize
	local jitterX = (math.random() - 0.5) * 0.018
	local startY  = math.clamp(by + (offset.Y / vp.Y) - slot * SLOT_STEP, 0.05, 0.9)
	local posX    = math.clamp(bx + (offset.X / vp.X) + jitterX, 0.06, 0.94)
	local startPos = UDim2.fromScale(posX, startY)

	local holder, scale, main, shadow, stroke = makeWord(self._screen, word, color, wsize)
	holder.Position = startPos
	holder.Rotation = (math.random() - 0.5) * 6
	self._words[#self._words + 1] = holder

	-- pop in
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(main,   TweenInfo.new(0.16), { TextTransparency = 0 }):Play()
	TweenService:Create(shadow, TweenInfo.new(0.16), { TextTransparency = 0.4 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.16), { Transparency = 0.15 }):Play()

	-- float naik pelan
	local upPos = UDim2.new(startPos.X.Scale, 0, startPos.Y.Scale - 0.045, 0)
	TweenService:Create(holder, TweenInfo.new(life + 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = upPos }):Play()

	-- wiggle halus
	if not self._lowEnd then
		local r = (wordIdx % 2 == 0) and 4 or -4
		TweenService:Create(holder, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = r }):Play()
	end

	-- fade out + free slot
	task.delay(life, function()
		if not holder.Parent then return end
		TweenService:Create(main,   TweenInfo.new(0.26), { TextTransparency = 1 }):Play()
		TweenService:Create(shadow, TweenInfo.new(0.26), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.26), { Transparency = 1 }):Play()
		task.delay(0.3, function()
			if self._slots[zone] and self._slots[zone] > 0 then
				self._slots[zone] = self._slots[zone] - 1
			end
			pcall(function() holder:Destroy() end)
		end)
	end)
end

function TextController:Play(textCfg, token)
	if not textCfg or not textCfg.Text or textCfg.Text == "" then return end

	local startTime = textCfg.StartTime    or 0
	local mode      = textCfg.Mode         or DEFAULT_MODE
	local target    = textCfg.Target       or DEFAULT_TARGET
	local delay     = textCfg.WordDelay    or DEFAULT_DELAY
	local life      = textCfg.WordLifetime or DEFAULT_LIFE
	local colors    = textCfg.Colors       or self._config.DefaultWordColors or DEFAULT_COLORS
	local wsize     = textCfg.WordSize     or DEFAULT_WSIZE
	local offset    = textCfg.Offset       or DEFAULT_OFFSET

	if startTime > 0 then
		local el = 0
		while el < startTime do
			if token.cancelled then return end
			el += task.wait()
		end
	end
	if token.cancelled then return end

	if mode ~= "PerWordNearCharacter" then
		self:_playLegacy(textCfg, token)
		return
	end

	local words = splitWords(textCfg.Text)
	for i, word in ipairs(words) do
		if token.cancelled then return end
		local color = colors[((i - 1) % #colors) + 1] or Color3.new(1, 1, 1)
		self:_spawnWord(word, target, i, color, life, wsize, offset)
		if i < #words then task.wait(delay) end
	end
end

-- mode lama: caption bawah layar
function TextController:_playLegacy(textCfg, token)
	local d = self._config.TextDefaults
	local holder = Instance.new("Frame")
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

	self._words[#self._words + 1] = holder

	local popStyle = (textCfg.Bounce ~= false) and Enum.EasingStyle.Back or Enum.EasingStyle.Quart
	TweenService:Create(scale, TweenInfo.new(0.32, popStyle, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(lbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = textCfg.StrokeTransparency or d.StrokeTransparency }):Play()

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
	-- per-kata fade sendiri; legacy holder dibersihkan di ClearWords scene berikut
end

return TextController
