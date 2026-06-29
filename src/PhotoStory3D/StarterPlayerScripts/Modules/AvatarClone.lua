--!nonstrict
-- AvatarClone: avatar cutscene, OTOMATIS dari player yang injek pad.
-- Strategi utama: clone karakter LIVE (andal & persis). Fallback HumanoidDescription.
-- PlaceAt: RAYCAST turun dari titik -> kaki nempel permukaan (tidak nembus / tidak melayang),
--          walau titik di atas part. HRP anchored -> diam di tempat (tidak benar2 jatuh fisika).
-- Maks 1 AnimationTrack hidup -> aman limit 64.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AvatarClone = {}
AvatarClone.__index = AvatarClone

local CLONE_PREFIX = "PhotoStoryClone_"

-- Buang yang berat/ganggu; sisakan visual + Motor6D + Humanoid + Animator + accessory.
local function strip(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer")
			or d:IsA("Tool") or d:IsA("BackpackItem")
			or d:IsA("Sound") or d:IsA("ParticleEmitter")
			or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Beam")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored   = false
			d.CanCollide = false
			d.CanQuery   = false
			d.CanTouch   = false
			d.Massless   = true
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true -- root diam; limb tetap dianimasikan Motor6D
	end
end

local function prepHumanoid(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.EvaluateStateMachine = false
	humanoid.RequiresNeck = false
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

function AvatarClone.new(userId, janitor)
	local self = setmetatable({}, AvatarClone)
	self._userId        = userId
	self._janitor       = janitor
	self._track         = nil
	self._currentAnimId = nil
	self._ready         = false
	return self
end

function AvatarClone:Build()
	if self._ready then return true end

	local model

	-- 1) Clone karakter live.
	local player = Players:GetPlayerByUserId(self._userId)
	local src = player and player.Character
	if src and src.Parent and src:FindFirstChild("HumanoidRootPart") then
		local prev = src.Archivable
		src.Archivable = true
		local ok, clone = pcall(function() return src:Clone() end)
		src.Archivable = prev
		if ok and clone then model = clone end
	end

	-- 2) Fallback HumanoidDescription.
	if not model then
		local okDesc, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(self._userId)
		end)
		if okDesc and desc then
			local okModel, built = pcall(function()
				return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
			end)
			if okModel and built then model = built end
		end
	end

	if not model then return false end

	strip(model)
	self._animator = prepHumanoid(model)

	model.Name   = CLONE_PREFIX .. tostring(self._userId)
	model.Parent = nil
	self._model  = model
	self._janitor:Add(function() self:Destroy() end)
	self._ready  = true
	return true
end

local function pointCFrame(point)
	if not point then return nil end
	if point:IsA("BasePart") then return point.CFrame
	elseif point:IsA("Attachment") then return point.WorldCFrame
	elseif point:IsA("Model") then return point:GetPivot() end
	return nil
end

-- Daftar yang di-ignore raycast: clone ini + semua karakter player + semua clone PhotoStory.
local function buildIgnore(selfModel)
	local ignore = { selfModel }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then ignore[#ignore + 1] = p.Character end
	end
	for _, c in ipairs(Workspace:GetChildren()) do
		if c:IsA("Model") and string.sub(c.Name, 1, #CLONE_PREFIX) == CLONE_PREFIX and c ~= selfModel then
			ignore[#ignore + 1] = c
		end
	end
	return ignore
end

-- Tempatkan di titik scene. footAlign = kaki nempel permukaan (raycast turun).
function AvatarClone:PlaceAt(point, footAlign)
	if not self._model then return false end
	local cf = pointCFrame(point)
	if not cf then return false end

	if self._model.Parent == nil then
		self._model.Parent = Workspace
	end

	-- Orientasi & XZ dari titik dulu.
	self._model:PivotTo(cf)

	if footAlign ~= false then
		-- Cari permukaan di bawah titik (terrain / part anchored) lewat raycast.
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = buildIgnore(self._model)
		rp.IgnoreWater = false

		local origin = cf.Position + Vector3.new(0, 2, 0)
		local result = Workspace:Raycast(origin, Vector3.new(0, -500, 0), rp)

		-- Y target kaki: permukaan kalau ketemu, kalau tidak pakai Y titik.
		local groundY = cf.Position.Y
		if result then
			-- Hanya pakai kalau part anchored / terrain (biar tidak nempel objek gerak).
			local inst = result.Instance
			if inst == nil or (inst:IsA("BasePart") and inst.Anchored) or inst:IsA("Terrain") then
				groundY = result.Position.Y
			end
		end

		-- Angkat/turunkan supaya bagian bawah rig = groundY.
		local bbCF, bbSize = self._model:GetBoundingBox()
		local bottomY = bbCF.Position.Y - bbSize.Y * 0.5
		local lift = groundY - bottomY
		self._model:PivotTo(CFrame.new(0, lift, 0) * self._model:GetPivot())
	end

	-- Pastikan HRP tetap anchored setelah pivot (diam, tidak melayang/jatuh).
	local hrp = self._model:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = true end
	return true
end

function AvatarClone:PlayAnimation(animId)
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
	if not okTrack or not track then return end
	track.Looped   = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.15)
	self._track         = track
	self._currentAnimId = animId
end

-- True kalau track sudah benar2 jalan (pose sudah masuk).
function AvatarClone:IsPosed()
	return self._track ~= nil and self._track.IsPlaying == true
end

-- True kalau punya animasi yang seharusnya jalan (untuk tahu perlu ditunggu atau tidak).
function AvatarClone:HasAnim()
	return self._track ~= nil
end

function AvatarClone:StopAnimation()
	if self._track then
		pcall(function()
			self._track:Stop(0)
			self._track:Destroy()
		end)
		self._track         = nil
		self._currentAnimId = nil
	end
end

function AvatarClone:GetModel()
	return self._model
end

function AvatarClone:Destroy()
	self:StopAnimation()
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
end

return AvatarClone
