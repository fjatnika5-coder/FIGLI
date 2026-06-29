--!nonstrict
-- ImageController: logo/sticker/dekorasi gambar overlay.
--   GlobalImages : muncul sepanjang cutscene.
--   Scene.Images : muncul per scene (dengan StartTime/EndTime opsional).
-- Animasi: Fade, Pop, Float, Wiggle, Pulse (pakai TweenService berulang -> mulus, cancellable).
-- Asset kosong/placeholder di-skip tanpa warn. Cleanup penuh per scene & saat selesai.

local TweenService = game:GetService("TweenService")

local ImageController = {}
ImageController.__index = ImageController

local function isRealAsset(id)
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

function ImageController.new(screen, config, lowEnd, janitor)
	local self = setmetatable({}, ImageController)
	self._config = config
	self._lowEnd = lowEnd == true
	self._janitor = janitor -- janitor cutscene (untuk global + container)

	local layer = Instance.new("Frame")
	layer.Name = "Overlay"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 15
	layer.Parent = screen
	self._layer = layer

	self._sceneItems = {} -- {instance|tween|thread} milik scene berjalan
	return self
end

-- Buat 1 ImageLabel dari cfg. Mengembalikan label + daftar objek untuk cleanup.
function ImageController:_create(cfg, ownerList)
	if not isRealAsset(cfg.Image) then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = cfg.Name or "Image"
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Image = cfg.Image
	img.Position = cfg.Position or UDim2.fromScale(0.5, 0.5)
	img.Size = cfg.Size or UDim2.fromScale(0.15, 0.15)
	img.Rotation = cfg.Rotation or 0
	img.ImageTransparency = cfg.Transparency or 0
	img.ZIndex = cfg.ZIndex or 16
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = self._layer
	ownerList[#ownerList + 1] = img

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = img

	local anim = cfg.Animation
	local target = cfg.Transparency or 0

	-- Fade-in masuk (selalu, biar halus).
	img.ImageTransparency = 1
	local fadeTw = TweenService:Create(img, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { ImageTransparency = target })
	ownerList[#ownerList + 1] = fadeTw
	fadeTw:Play()

	if anim == "Pop" then
		scale.Scale = 0.6
		local tw = TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		ownerList[#ownerList + 1] = tw
		tw:Play()
	elseif not self._lowEnd and anim == "Float" then
		local up = img.Position - UDim2.fromScale(0, 0.03)
		local tw = TweenService:Create(img, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = up })
		ownerList[#ownerList + 1] = tw
		tw:Play()
	elseif not self._lowEnd and anim == "Wiggle" then
		local baseR = cfg.Rotation or 0
		img.Rotation = baseR - 5
		local tw = TweenService:Create(img, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = baseR + 5 })
		ownerList[#ownerList + 1] = tw
		tw:Play()
	elseif not self._lowEnd and anim == "Pulse" then
		local tw = TweenService:Create(scale, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.08 })
		ownerList[#ownerList + 1] = tw
		tw:Play()
	end

	return img
end

local function cleanupList(list)
	for _, obj in ipairs(list) do
		local kind = typeof(obj)
		if kind == "Instance" then
			obj:Destroy()
		elseif kind == "RBXScriptConnection" then
			obj:Disconnect()
		elseif kind == "thread" then
			pcall(task.cancel, obj)
		elseif kind == "table" and typeof(obj.Cancel) == "function" then
			obj:Cancel()
		else
			-- Tween
			pcall(function()
				obj:Cancel()
			end)
		end
	end
end

-- Gambar global (sepanjang cutscene). Masuk janitor cutscene.
function ImageController:BeginGlobals()
	local globals = self._config.GlobalImages or {}
	local owner = {}
	for _, cfg in ipairs(globals) do
		self:_create(cfg, owner)
	end
	self._janitor:Add(function()
		cleanupList(owner)
	end)
end

-- Set gambar untuk scene berjalan (membersihkan scene sebelumnya).
function ImageController:SetScene(scene, token)
	self:ClearScene()
	local images = scene.Images or {}
	local owner = {}
	self._sceneItems = owner

	for _, cfg in ipairs(images) do
		if isRealAsset(cfg.Image) then
			local startT = cfg.StartTime or 0
			if startT <= 0 then
				local img = self:_create(cfg, owner)
				if img and cfg.EndTime and cfg.EndTime > 0 then
					self:_scheduleHide(img, cfg, owner, token)
				end
			else
				-- Tampilkan sesuai StartTime.
				local th = task.delay(startT, function()
					if token.cancelled or self._sceneItems ~= owner then
						return
					end
					local img = self:_create(cfg, owner)
					if img and cfg.EndTime and cfg.EndTime > 0 then
						self:_scheduleHide(img, cfg, owner, token)
					end
				end)
				owner[#owner + 1] = th
			end
		end
	end
end

function ImageController:_scheduleHide(img, cfg, owner, token)
	local th = task.delay(cfg.EndTime, function()
		if token.cancelled or self._sceneItems ~= owner or not img.Parent then
			return
		end
		local tw = TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { ImageTransparency = 1 })
		owner[#owner + 1] = tw
		tw:Play()
	end)
	owner[#owner + 1] = th
end

function ImageController:ClearScene()
	if self._sceneItems then
		cleanupList(self._sceneItems)
	end
	self._sceneItems = {}
end

return ImageController
