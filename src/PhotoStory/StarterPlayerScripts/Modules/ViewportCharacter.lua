--!nonstrict
-- ViewportCharacter: satu avatar player di dalam ViewportFrame + WorldModel + Camera
-- sendiri (bukan CurrentCamera). Ringan, tidak menyentuh world asli.
-- Hanya 1 AnimationTrack hidup per karakter (stop+destroy track lama sebelum load baru)
-- -> aman dari limit 64 track.

local Players = game:GetService("Players")

local ViewportCharacter = {}
ViewportCharacter.__index = ViewportCharacter

local BASE_SIZE = UDim2.fromScale(0.5, 0.7) -- ukuran dasar ViewportFrame (dikali Scale config)
local CAMERA_FOV = 28

-- Bersihkan model dari hal yang tidak perlu (script/tool), anchor root biar diam.
local function sanitizeRig(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("BackpackItem") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
end

function ViewportCharacter.new(parent, userId, janitor)
	local self = setmetatable({}, ViewportCharacter)
	self._janitor = janitor
	self._userId = userId
	self._track = nil
	self._currentAnimId = nil
	self._baseCFrame = CFrame.new()
	self._ready = false

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Char_" .. tostring(userId)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Size = BASE_SIZE
	viewport.BackgroundTransparency = 1
	viewport.Visible = false
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.ZIndex = 3
	viewport.Parent = parent
	self._viewport = viewport
	janitor:Add(viewport, "Destroy")

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport
	self._worldModel = worldModel

	local camera = Instance.new("Camera")
	camera.FieldOfView = CAMERA_FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	self._camera = camera

	return self
end

-- Build rig async (yields). Panggil sekali sebelum story mulai.
function ViewportCharacter:Build()
	if self._ready then
		return true
	end

	local okDesc, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(self._userId)
	end)
	if not okDesc or not desc then
		return false
	end

	local okModel, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not okModel or not model then
		return false
	end

	sanitizeRig(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.EvaluateStateMachine = false
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		self._animator = animator
	end

	model.Parent = self._worldModel
	model:PivotTo(CFrame.new(0, 0, 0))
	self._model = model
	self._baseCFrame = CFrame.new(0, 0, 0)

	self:_frameCamera()
	self._ready = true
	return true
end

function ViewportCharacter:_frameCamera()
	local cf, size = self._model:GetBoundingBox()
	local center = cf.Position
	local height = math.max(size.Y, 1)
	local dist = (height * 0.5) / math.tan(math.rad(CAMERA_FOV * 0.5)) * 1.15
	-- Avatar menghadap -Z; kamera di sisi -Z melihat ke +Z supaya wajah terlihat.
	local camPos = center + Vector3.new(0, size.Y * 0.05, -dist)
	self._camera.CFrame = CFrame.lookAt(camPos, center)
end

function ViewportCharacter:SetTransform(position, scale, rotationDeg)
	scale = scale or 1
	self._viewport.Position = position or self._viewport.Position
	self._viewport.Size = UDim2.fromScale(BASE_SIZE.X.Scale * scale, BASE_SIZE.Y.Scale * scale)
	if self._model then
		self._model:PivotTo(self._baseCFrame * CFrame.Angles(0, math.rad(rotationDeg or 0), 0))
	end
end

-- Stop + destroy track lama, load + play track baru. Reuse kalau anim sama.
function ViewportCharacter:PlayAnimation(animId)
	if not (self._animator and typeof(animId) == "string" and string.match(animId, "^rbxassetid://%d+$")) then
		self:StopAnimation()
		return
	end
	if self._track and self._currentAnimId == animId and self._track.IsPlaying then
		return
	end

	self:StopAnimation()

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local okTrack, track = pcall(function()
		return self._animator:LoadAnimation(anim)
	end)
	anim:Destroy()
	if not okTrack or not track then
		return
	end

	track.Looped = true
	track:Play(0.15)
	self._track = track
	self._currentAnimId = animId
end

function ViewportCharacter:StopAnimation()
	if self._track then
		pcall(function()
			self._track:Stop(0)
			self._track:Destroy()
		end)
		self._track = nil
		self._currentAnimId = nil
	end
end

function ViewportCharacter:Show()
	self._viewport.Visible = true
end

function ViewportCharacter:Hide()
	self._viewport.Visible = false
end

function ViewportCharacter:Destroy()
	self:StopAnimation()
	-- ViewportFrame & isinya sudah didaftarkan ke janitor pemanggil.
end

return ViewportCharacter
