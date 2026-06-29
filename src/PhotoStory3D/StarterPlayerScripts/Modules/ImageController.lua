--!nonstrict
-- ImageController: logo/sticker/dekorasi gambar overlay.
--   GlobalImages  : muncul sepanjang cutscene.
--   Scene.Images  : muncul per scene (StartTime/Lifetime/EndTime opsional).
--   Target "Girl"/"Boy" : posisi dekat karakter via WorldToViewportPoint.
--   Target "Screen"     : pakai Position langsung.
-- Animasi: Pop, Wiggle, Float, Pulse, PopWiggle.
-- Asset kosong/placeholder di-skip tanpa warn. Cleanup penuh per scene.

local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local ImageController = {}
ImageController.__index = ImageController

local function isRealAsset(id)
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

-- World pos -> screen UDim2 (nil, false jika offscreen)
local function worldToScreen(worldPos)
	if not worldPos then return nil, false end
	local cam = Workspace.CurrentCamera
	local vp  = cam.ViewportSize
	local sv, _, onScreen = cam:WorldToViewportPoint(worldPos)
	if not onScreen or sv.Z < 0 then return nil, false end
	local sx = sv.X / vp.X
	local sy = sv.Y / vp.Y
	if sx < 0.02 or sx > 0.98 or sy < 0.02 or sy > 0.98 then return nil, false end
	return UDim2.fromScale(sx, sy), true
end

local function getHeadWorld(cloneObj)
	if not cloneObj or not cloneObj._model then return nil end
	local m    = cloneObj._model
	local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
	if head and head:IsA("BasePart") then return head.Position end
	return nil
end

function ImageController.new(screen, config, lowEnd, janitor)
	local self       = setmetatable({}, ImageController)
	self._config     = config
	self._lowEnd     = lowEnd == true
	self._janitor    = janitor
	self._clones     = {}   -- {Girl=AvatarClone, Boy=AvatarClone}
	self._sceneItems = {}   -- instances + tweens aktif scene

	local layer = Instance.new("Frame")
	layer.Name = "Overlay"
	layer.BackgroundTransparency = 1
	layer.Size  = UDim2.fromScale(1, 1)
	layer.ZIndex = 15
	layer.Parent = screen
	self._layer  = layer
	return self
end

function ImageController:SetClones(clones)
	self._clones = clones or {}
end

-- Hitung posisi sticker: Target Girl/Boy = dekat kepala; Screen/nil = pakai Position
function ImageController:_resolvePosition(cfg)
	local target = cfg.Target
	local offset = cfg.Offset or Vector2.new(0, -90)

	local cloneObj = nil
	if target == "Girl" then cloneObj = self._clones.Girl
	elseif target == "Boy" then cloneObj = self._clones.Boy
	end

	if cloneObj then
		local worldPos = getHeadWorld(cloneObj)
		local screenPos, onScreen = worldToScreen(worldPos)
		if onScreen then
			local cam  = Workspace.CurrentCamera
			local vpSz = cam.ViewportSize
			local nx   = math.clamp(screenPos.X.Scale + offset.X / vpSz.X, 0.04, 0.95)
			local ny   = math.clamp(screenPos.Y.Scale + offset.Y / vpSz.Y, 0.04, 0.95)
			return UDim2.fromScale(nx, ny)
		end
	end

	-- Fallback: pakai Position field dari cfg
	return cfg.Position or UDim2.fromScale(0.5, 0.5)
end

-- Buat 1 ImageLabel dari cfg. ownerList = list untuk cleanup.
function ImageController:_create(cfg, ownerList)
	if not isRealAsset(cfg.Image) then return nil end

	local pos = self:_resolvePosition(cfg)

	local img = Instance.new("ImageLabel")
	img.Name               = cfg.Name or "Img"
	img.AnchorPoint        = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Image              = cfg.Image
	img.Position           = pos
	img.Size               = cfg.Size or UDim2.fromScale(0.1, 0.1)
	img.Rotation           = cfg.Rotation or 0
	img.ImageTransparency  = 1          -- fade in dari transparan
	img.ZIndex             = cfg.ZIndex or 20
	img.ScaleType          = Enum.ScaleType.Fit
	img.Parent             = self._layer
	ownerList[#ownerList + 1] = img

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = img

	local anim   = cfg.Animation or "Pop"
	local target = cfg.Transparency or 0

	-- Fade in selalu ada
	local fadeIn = TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { ImageTransparency = target })
	ownerList[#ownerList + 1] = fadeIn
	fadeIn:Play()

	local function doAnim(animName)
		if animName == "Pop" or animName == "PopWiggle" then
			scale.Scale = 0.5
			local tw = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			ownerList[#ownerList + 1] = tw
			tw:Play()
			if animName == "PopWiggle" and not self._lowEnd then
				-- Wiggle setelah pop
				task.delay(0.35, function()
					if not img.Parent then return end
					local base = cfg.Rotation or 0
					local tw2 = TweenService:Create(img, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = base + 8 })
					ownerList[#ownerList + 1] = tw2
					tw2:Play()
				end)
			end
		elseif animName == "Wiggle" and not self._lowEnd then
			local base = cfg.Rotation or 0
			img.Rotation = base - 6
			local tw = TweenService:Create(img, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = base + 6 })
			ownerList[#ownerList + 1] = tw
			tw:Play()
		elseif animName == "Float" and not self._lowEnd then
			local up = pos - UDim2.fromScale(0, 0.03)
			local tw = TweenService:Create(img, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = up })
			ownerList[#ownerList + 1] = tw
			tw:Play()
		elseif animName == "Pulse" and not self._lowEnd then
			local tw = TweenService:Create(scale, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 })
			ownerList[#ownerList + 1] = tw
			tw:Play()
		end
	end

	doAnim(anim)
	return img
end

local function cancelTween(obj)
	if typeof(obj) == "Instance" then
		pcall(function() obj:Destroy() end)
	else
		pcall(function() obj:Cancel() end)
	end
end

local function cleanupList(list)
	for _, obj in ipairs(list) do
		if typeof(obj) == "Instance" then
			pcall(function() obj:Destroy() end)
		elseif typeof(obj) == "thread" then
			pcall(task.cancel, obj)
		else
			pcall(function() obj:Cancel() end)
		end
	end
end

-- Global images (sepanjang cutscene)
function ImageController:BeginGlobals()
	local globals = self._config.GlobalImages or {}
	local owner   = {}
	for _, cfg in ipairs(globals) do
		self:_create(cfg, owner)
	end
	self._janitor:Add(function()
		cleanupList(owner)
	end)
end

-- Scene images (per scene, dengan StartTime dan Lifetime/EndTime)
function ImageController:SetScene(scene, token)
	self:ClearScene()
	local images = scene.Images or {}
	local owner  = {}
	self._sceneItems = owner

	for _, cfg in ipairs(images) do
		if isRealAsset(cfg.Image) then
			local startT    = cfg.StartTime or 0
			local lifetime  = cfg.Lifetime  -- nil = bertahan sampai scene selesai

			local function spawnIt()
				if token.cancelled or self._sceneItems ~= owner then return end
				local img = self:_create(cfg, owner)
				if img and lifetime and lifetime > 0 then
					local th = task.delay(lifetime, function()
						if not img.Parent then return end
						local tw = TweenService:Create(img, TweenInfo.new(0.28, Enum.EasingStyle.Quad), { ImageTransparency = 1 })
						tw:Play()
						task.delay(0.3, function() pcall(function() img:Destroy() end) end)
					end)
					owner[#owner + 1] = th
				end
				-- Backward compat: EndTime field
				if img and cfg.EndTime and cfg.EndTime > 0 and not lifetime then
					local th = task.delay(cfg.EndTime, function()
						if not img.Parent then return end
						local tw = TweenService:Create(img, TweenInfo.new(0.28, Enum.EasingStyle.Quad), { ImageTransparency = 1 })
						tw:Play()
						task.delay(0.3, function() pcall(function() img:Destroy() end) end)
					end)
					owner[#owner + 1] = th
				end
			end

			if startT <= 0 then
				spawnIt()
			else
				local th = task.delay(startT, spawnIt)
				owner[#owner + 1] = th
			end
		end
	end
end

function ImageController:ClearScene()
	if self._sceneItems then
		cleanupList(self._sceneItems)
	end
	self._sceneItems = {}
end

return ImageController
