--!nonstrict
-- SceneImageController: sticker/gambar per scene dari Config.SceneImages[sceneName].
--   Target "Girl"/"Boy" : posisi dekat karakter via WorldToViewportPoint + Offset.
--   Target "Screen"     : pakai Position.
-- Image kosong/placeholder -> SKIP diam-diam (tidak ada kotak hijau, tidak ada warn).
-- Animasi: Pop, Float, Wiggle, Pulse, PopWiggle. Cleanup penuh tiap ganti scene.

local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local SceneImage = {}
SceneImage.__index = SceneImage

local function isReal(id)
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

local function headWorld(clone)
	if not clone or not clone._model then return nil end
	local m = clone._model
	local h = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
	if h and h:IsA("BasePart") then return h.Position end
	return nil
end

local function toScreen(world)
	if not world then return nil, false end
	local cam = Workspace.CurrentCamera
	local v, _, on = cam:WorldToViewportPoint(world)
	if not on or v.Z < 0 then return nil, false end
	local vp = cam.ViewportSize
	local sx, sy = v.X / vp.X, v.Y / vp.Y
	if sx < 0.02 or sx > 0.98 or sy < 0.02 or sy > 0.98 then return nil, false end
	return Vector2.new(sx, sy), true
end

function SceneImage.new(screen, config, lowEnd, janitor)
	local self = setmetatable({}, SceneImage)
	self._config  = config
	self._lowEnd  = lowEnd == true
	self._janitor = janitor
	self._clones  = {}
	self._items   = {}

	local layer = Instance.new("Frame")
	layer.Name = "Stickers"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 15
	layer.Parent = screen
	self._layer = layer
	return self
end

function SceneImage:SetClones(c) self._clones = c or {} end

function SceneImage:_pos(cfg)
	local t = cfg.Target
	local clone = (t == "Girl" and self._clones.Girl) or (t == "Boy" and self._clones.Boy) or nil
	if clone then
		local sp, on = toScreen(headWorld(clone))
		if on then
			local vp  = Workspace.CurrentCamera.ViewportSize
			local off = cfg.Offset or Vector2.new(0, -100)
			return UDim2.fromScale(
				math.clamp(sp.X + off.X / vp.X, 0.03, 0.97),
				math.clamp(sp.Y + off.Y / vp.Y, 0.03, 0.97)
			)
		end
	end
	return cfg.Position or UDim2.fromScale(0.5, 0.5)
end

function SceneImage:_create(cfg, owner)
	if not isReal(cfg.Image) then return nil end

	local pos = self:_pos(cfg)
	local img = Instance.new("ImageLabel")
	img.Name                  = cfg.Name or "Sticker"
	img.AnchorPoint           = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Image                 = cfg.Image
	img.Position              = pos
	img.Size                  = cfg.Size or UDim2.fromOffset(55, 55)
	img.Rotation              = cfg.Rotation or 0
	img.ImageTransparency     = 1
	img.ZIndex                = cfg.ZIndex or 30
	img.ScaleType             = Enum.ScaleType.Fit
	img.Parent                = self._layer
	owner[#owner + 1] = img

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = img

	local target = cfg.Transparency or 0
	local fadeIn = TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { ImageTransparency = target })
	owner[#owner + 1] = fadeIn
	fadeIn:Play()

	local a = cfg.Animation or "Pop"
	if a == "Pop" or a == "PopWiggle" then
		scale.Scale = 0.5
		local tw = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		owner[#owner + 1] = tw; tw:Play()
		if a == "PopWiggle" and not self._lowEnd then
			task.delay(0.35, function()
				if not img.Parent then return end
				local base = cfg.Rotation or 0
				local tw2 = TweenService:Create(img, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = base + 8 })
				owner[#owner + 1] = tw2; tw2:Play()
			end)
		end
	elseif a == "Wiggle" and not self._lowEnd then
		local base = cfg.Rotation or 0
		img.Rotation = base - 6
		local tw = TweenService:Create(img, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = base + 6 })
		owner[#owner + 1] = tw; tw:Play()
	elseif a == "Float" and not self._lowEnd then
		local up = pos - UDim2.fromScale(0, 0.03)
		local tw = TweenService:Create(img, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = up })
		owner[#owner + 1] = tw; tw:Play()
	elseif a == "Pulse" and not self._lowEnd then
		local tw = TweenService:Create(scale, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 })
		owner[#owner + 1] = tw; tw:Play()
	end

	return img
end

local function cleanup(list)
	for _, o in ipairs(list) do
		if typeof(o) == "Instance" then
			pcall(function() o:Destroy() end)
		elseif typeof(o) == "thread" then
			pcall(task.cancel, o)
		else
			pcall(function() o:Cancel() end)
		end
	end
end

-- Gambar global sepanjang cutscene (Config.GlobalImages).
function SceneImage:BeginGlobals()
	local globals = self._config.GlobalImages or {}
	local owner = {}
	for _, cfg in ipairs(globals) do
		self:_create(cfg, owner)
	end
	self._janitor:Add(function() cleanup(owner) end)
end

-- Gambar untuk scene (Config.SceneImages[sceneName]).
function SceneImage:SetScene(sceneName, token)
	self:Clear()
	local all  = self._config.SceneImages or {}
	local list = all[sceneName]
	if not list then return end

	local owner = {}
	self._items = owner

	for _, cfg in ipairs(list) do
		if isReal(cfg.Image) then
			local startT = cfg.StartTime or 0
			local life   = cfg.Lifetime

			local function go()
				if token.cancelled or self._items ~= owner then return end
				local img = self:_create(cfg, owner)
				if img and life and life > 0 then
					local th = task.delay(life, function()
						if not img.Parent then return end
						local tw = TweenService:Create(img, TweenInfo.new(0.28, Enum.EasingStyle.Quad), { ImageTransparency = 1 })
						tw:Play()
						task.delay(0.3, function() pcall(function() img:Destroy() end) end)
					end)
					owner[#owner + 1] = th
				end
			end

			if startT <= 0 then
				go()
			else
				owner[#owner + 1] = task.delay(startT, go)
			end
		end
	end
end

function SceneImage:Clear()
	if self._items then cleanup(self._items) end
	self._items = {}
end

return SceneImage
