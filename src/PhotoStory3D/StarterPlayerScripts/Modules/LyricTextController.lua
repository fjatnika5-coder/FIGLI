--!nonstrict
-- LyricTextController: lirik per-PHRASE, BERURUTAN (tidak acak), rapi seperti lyric edit.
-- Phrase = 2-3 kata (WordsPerPhrase). Muncul berurutan sesuai kalimat, stack rapi dekat karakter.
-- Phrase lama fade-out kalau melebihi MaxVisiblePhrases -> layar tidak penuh.
-- Target: Girl / Boy / Center / AlternatePhrase (phrase1 Girl, phrase2 Boy, dst).
-- Backward compatible: config lama {Typewriter/Fade/Bounce} -> auto pakai LyricPhrase.
-- Cleanup: semua holder/tween/thread dibersihkan di Clear().

local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local LyricText = {}
LyricText.__index = LyricText

local DEF = {
	Mode              = "LyricPhrase",
	Target            = "Center",
	WordsPerPhrase    = 2,
	PhraseDelay       = 0.42,
	PhraseLifetime    = 1.25,
	Layout            = "Stack",
	MaxVisiblePhrases = 2,
	Offset            = Vector2.new(0, -95),
	Spacing           = 28,
	TextSize          = 22,
	Animation         = "PopFloat",
	Wiggle            = true,
	Stroke            = true,
	Shadow            = true,
}

local DEFAULT_COLORS = {
	Color3.fromRGB(255, 210, 230),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(190, 220, 255),
	Color3.fromRGB(255, 230, 170),
}

local FONT         = Enum.Font.FredokaOne
local FALLBACK_POS = Vector2.new(0.5, 0.8) -- scale

local function splitPhrases(text, per)
	local words = {}
	for w in string.gmatch(text, "%S+") do words[#words + 1] = w end
	local phrases = {}
	local i = 1
	while i <= #words do
		local chunk = {}
		for j = 0, per - 1 do
			if words[i + j] then chunk[#chunk + 1] = words[i + j] end
		end
		phrases[#phrases + 1] = table.concat(chunk, " ")
		i += per
	end
	return phrases
end

local function headWorld(clone)
	if not clone or not clone._model then return nil end
	local m = clone._model
	local h = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then return h.Position + Vector3.new(0, 0.6, 0) end
	return nil
end

local function toViewportPx(world)
	if not world then return nil end
	local cam = Workspace.CurrentCamera
	local v, _, on = cam:WorldToViewportPoint(world)
	if not on or v.Z < 0 then return nil end
	local vp = cam.ViewportSize
	if v.X < vp.X * 0.04 or v.X > vp.X * 0.96 or v.Y < vp.Y * 0.04 or v.Y > vp.Y * 0.94 then
		return nil
	end
	return Vector2.new(v.X, v.Y)
end

function LyricText.new(screen, config, lowEnd, janitor)
	local self = setmetatable({}, LyricText)
	self._screen  = screen
	self._config  = config
	self._lowEnd  = lowEnd == true
	self._janitor = janitor
	self._clones  = {}
	self._all     = {}
	self._active  = { Girl = {}, Boy = {}, Center = {} }
	return self
end

function LyricText:SetClones(c) self._clones = c or {} end
function LyricText:Begin() self._janitor:Add(function() self:Clear() end) end
function LyricText:SetScene() self:Clear() end
function LyricText:ClearWords() self:Clear() end
function LyricText:FadeOut() end

function LyricText:Clear()
	for _, h in ipairs(self._all) do
		if typeof(h) == "Instance" and h.Parent then
			pcall(function() h:Destroy() end)
		end
	end
	self._all    = {}
	self._active = { Girl = {}, Boy = {}, Center = {} }
end

function LyricText:_zone(target, idx)
	if target == "Girl" then return "Girl", self._clones.Girl
	elseif target == "Boy" then return "Boy", self._clones.Boy
	elseif target == "AlternatePhrase" then
		if idx % 2 == 1 then return "Girl", self._clones.Girl else return "Boy", self._clones.Boy end
	else return "Center", nil end
end

function LyricText:_basePx(zone, clone, offset)
	local vp = Workspace.CurrentCamera.ViewportSize
	if zone == "Center" then
		return Vector2.new(vp.X * FALLBACK_POS.X, vp.Y * FALLBACK_POS.Y)
	end
	local sp = toViewportPx(headWorld(clone))
	if sp then
		return Vector2.new(sp.X + offset.X, sp.Y + offset.Y)
	end
	local x = (zone == "Girl") and vp.X * 0.30 or vp.X * 0.70
	return Vector2.new(x, vp.Y * 0.62)
end

local function makeLabel(parent, text, color, z, tt)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	t.TextTransparency = tt
	t.ZIndex = z
	t.Parent = parent
	return t
end

function LyricText:_make(text, color, cfg)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.46, 0.075) -- responsive box
	holder.ZIndex = 35
	holder.Parent = self._screen

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = holder

	local shadow
	if cfg.Shadow ~= false then
		shadow = makeLabel(holder, text, Color3.fromRGB(0, 0, 0), 35, 1)
		shadow.Position = UDim2.fromOffset(2, 2)
		local cs = Instance.new("UITextSizeConstraint")
		cs.MaxTextSize = cfg.TextSize; cs.MinTextSize = 8; cs.Parent = shadow
	end

	local main = makeLabel(holder, text, color, 36, 1)
	local cm = Instance.new("UITextSizeConstraint")
	cm.MaxTextSize = cfg.TextSize; cm.MinTextSize = 8; cm.Parent = main

	-- gradient halus
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, color),
	})
	grad.Rotation = 90
	grad.Parent = main

	local stroke
	if cfg.Stroke ~= false then
		stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(35, 22, 30)
		stroke.Transparency = 1
		stroke.Parent = main
	end

	return holder, scale, main, shadow, stroke
end

function LyricText:_restack(zone, basePx, cfg)
	local vp = Workspace.CurrentCamera.ViewportSize
	local list = self._active[zone]
	local n = #list
	for i, e in ipairs(list) do
		local fromBottom = n - i -- newest (i=n) di bawah/base; lama naik
		local px = basePx.X
		local py = basePx.Y - fromBottom * cfg.Spacing
		local pos = UDim2.fromScale(px / vp.X, py / vp.Y)
		TweenService:Create(e.holder, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = pos }):Play()
	end
end

function LyricText:_fadeOut(entry, dur)
	if not entry or not entry.holder or not entry.holder.Parent then return end
	if entry.main then TweenService:Create(entry.main, TweenInfo.new(dur), { TextTransparency = 1 }):Play() end
	if entry.shadow then TweenService:Create(entry.shadow, TweenInfo.new(dur), { TextTransparency = 1 }):Play() end
	if entry.stroke then TweenService:Create(entry.stroke, TweenInfo.new(dur), { Transparency = 1 }):Play() end
	local p = entry.holder.Position
	TweenService:Create(entry.holder, TweenInfo.new(dur, Enum.EasingStyle.Quad),
		{ Position = UDim2.new(p.X.Scale, 0, p.Y.Scale - 0.025, 0) }):Play()
	task.delay(dur + 0.05, function()
		if entry.holder then pcall(function() entry.holder:Destroy() end) end
	end)
end

function LyricText:_spawn(zone, clone, phrase, color, cfg)
	local basePx = self:_basePx(zone, clone, cfg.Offset)

	local holder, scale, main, shadow, stroke = self:_make(phrase, color, cfg)
	local entry = { holder = holder, scale = scale, main = main, shadow = shadow, stroke = stroke }
	table.insert(self._active[zone], entry)
	self._all[#self._all + 1] = holder

	-- batasi jumlah tampil; fade yang paling lama
	while #self._active[zone] > cfg.MaxVisiblePhrases do
		local old = table.remove(self._active[zone], 1)
		self:_fadeOut(old, 0.3)
	end

	self:_restack(zone, basePx, cfg)

	-- masuk: pop + fade + (wiggle halus)
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(main, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	if shadow then TweenService:Create(shadow, TweenInfo.new(0.2), { TextTransparency = 0.4 }):Play() end
	if stroke then TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.1 }):Play() end
	if cfg.Wiggle and not self._lowEnd then
		holder.Rotation = -2
		TweenService:Create(holder, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 2 }):Play()
	end

	-- auto fade setelah lifetime
	task.delay(cfg.PhraseLifetime, function()
		if not holder.Parent then return end
		local list = self._active[zone]
		for i, e in ipairs(list) do
			if e == entry then table.remove(list, i) break end
		end
		self:_fadeOut(entry, 0.3)
	end)
end

function LyricText:Play(textCfg, token)
	if not textCfg or not textCfg.Text or textCfg.Text == "" then return end

	local cfg = {}
	for k, v in pairs(DEF) do cfg[k] = v end
	for k, v in pairs(textCfg) do if v ~= nil then cfg[k] = v end end
	cfg.Colors = textCfg.Colors or self._config.DefaultWordColors or DEFAULT_COLORS

	if cfg.StartTime and cfg.StartTime > 0 then
		local el = 0
		while el < cfg.StartTime do
			if token.cancelled then return end
			el += task.wait()
		end
	end
	if token.cancelled then return end

	local phrases = splitPhrases(textCfg.Text, math.max(1, cfg.WordsPerPhrase))
	for i, phrase in ipairs(phrases) do
		if token.cancelled then return end
		local zone, clone = self:_zone(cfg.Target, i)
		local color = cfg.Colors[((i - 1) % #cfg.Colors) + 1] or Color3.new(1, 1, 1)
		self:_spawn(zone, clone, phrase, color, cfg)
		if i < #phrases then task.wait(cfg.PhraseDelay) end
	end
end

return LyricText
