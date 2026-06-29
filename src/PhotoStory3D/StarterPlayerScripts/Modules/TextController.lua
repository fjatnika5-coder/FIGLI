--!nonstrict
-- TextController: caption cinematic (fade + pop/bounce + typewriter + sway halus + shadow).
-- Responsive (TextScaled + UITextSizeConstraint). Sway pakai 1 RenderStepped, unbind via janitor.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TextController = {}
TextController.__index = TextController

local SWAY_NAME = "PhotoStoryTextSway"

local function makeLabel(parent, zindex)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.TextScaled = true
	lbl.RichText = false
	lbl.Text = ""
	lbl.ZIndex = zindex
	lbl.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 54
	constraint.MinTextSize = 10
	constraint.Parent = lbl
	return lbl
end

function TextController.new(screen, config, lowEnd, janitor)
	local self = setmetatable({}, TextController)
	self._config = config
	self._lowEnd = lowEnd == true
	self._janitor = janitor

	-- Holder dipakai untuk posisi + sway (rotation/offset) tanpa ganggu layout teks.
	local holder = Instance.new("Frame")
	holder.Name = "Caption"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Size = config.TextDefaults.Size
	holder.Position = config.TextDefaults.Position
	holder.ZIndex = 30
	holder.Visible = false
	holder.Parent = screen
	self._holder = holder

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = holder
	self._scale = scale

	-- Shadow (di belakang) + main label.
	local shadow = makeLabel(holder, 30)
	shadow.Position = UDim2.fromOffset(2, 3)
	shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	shadow.TextTransparency = 1
	self._shadow = shadow

	local main = makeLabel(holder, 31)
	main.TextTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = main
	self._main = main
	self._stroke = stroke

	self._swayPhase = math.random() * 100
	return self
end

-- Bind sway lembut sekali untuk seluruh cutscene.
function TextController:Begin()
	if self._lowEnd then
		return
	end
	RunService:BindToRenderStep(SWAY_NAME, Enum.RenderPriority.Last.Value, function()
		if not self._holder.Visible then
			return
		end
		local t = os.clock() * 0.8 + self._swayPhase
		self._holder.Rotation = math.noise(t, 0.0) * 1.6 -- derajat, sangat halus
	end)
	self._janitor:Add(function()
		RunService:UnbindFromRenderStep(SWAY_NAME)
	end)
end

function TextController:SetScene(textCfg)
	local d = self._config.TextDefaults
	if not textCfg or not textCfg.Text or textCfg.Text == "" then
		self._holder.Visible = false
		return
	end
	self._holder.Visible = true
	self._holder.Position = textCfg.Position or d.Position
	self._holder.Size = textCfg.Size or d.Size
	self._holder.Rotation = 0

	local font = textCfg.Font or d.Font
	local color = textCfg.TextColor3 or d.TextColor3
	for _, lbl in ipairs({ self._main, self._shadow }) do
		lbl.Font = font
		lbl.Text = textCfg.Text
	end
	self._main.TextColor3 = color
	self._stroke.Color = textCfg.StrokeColor3 or d.StrokeColor3

	-- Mulai tersembunyi (akan di-fade in di Play).
	self._main.TextTransparency = 1
	self._shadow.TextTransparency = 1
	self._stroke.Transparency = 1
	self._scale.Scale = 0.7

	local typ00 = textCfg.Typewriter and 0 or -1
	self._main.MaxVisibleGraphemes = typ00
	self._shadow.MaxVisibleGraphemes = typ00
end

function TextController:_tween(obj, info, props)
	local tw = TweenService:Create(obj, info, props)
	self._janitor:Add(tw, "Cancel")
	tw:Play()
	return tw
end

-- Animasi masuk: delay StartTime -> pop + fade + (typewriter). Cancellable via token.
function TextController:Play(textCfg, token)
	if not textCfg or not textCfg.Text or textCfg.Text == "" then
		return
	end
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

	local strokeTarget = textCfg.StrokeTransparency or d.StrokeTransparency
	local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	-- Fade selalu ada (biar tidak kaku) walau Fade=false tetap halus.
	self:_tween(self._main, fadeInfo, { TextTransparency = 0 })
	self:_tween(self._shadow, fadeInfo, { TextTransparency = 0.35 })
	self:_tween(self._stroke, fadeInfo, { Transparency = strokeTarget })

	-- Pop/bounce (Back overshoot). Selalu ada walau Bounce=false, tapi lebih kuat kalau true.
	local popStyle = (textCfg.Bounce ~= false) and Enum.EasingStyle.Back or Enum.EasingStyle.Quart
	local popInfo = TweenInfo.new(0.34, popStyle, Enum.EasingDirection.Out)
	self:_tween(self._scale, popInfo, { Scale = 1 })

	if textCfg.Typewriter then
		local total = utf8.len(self._main.ContentText) or #self._main.ContentText
		local speed = textCfg.TypewriterSpeed or d.TypewriterSpeed
		local shown = 0
		while shown < total do
			if token.cancelled then
				return
			end
			shown += speed * task.wait()
			local n = math.floor(shown)
			self._main.MaxVisibleGraphemes = n
			self._shadow.MaxVisibleGraphemes = n
		end
		self._main.MaxVisibleGraphemes = -1
		self._shadow.MaxVisibleGraphemes = -1
	end
end

-- Fade keluar lembut di akhir scene.
function TextController:FadeOut(duration)
	if not self._holder.Visible then
		return
	end
	local info = TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	self:_tween(self._main, info, { TextTransparency = 1 })
	self:_tween(self._shadow, info, { TextTransparency = 1 })
	self:_tween(self._stroke, info, { Transparency = 1 })
end

return TextController
