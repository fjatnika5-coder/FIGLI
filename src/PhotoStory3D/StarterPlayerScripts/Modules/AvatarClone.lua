--!nonstrict
-- AvatarClone: avatar cutscene, OTOMATIS dari player yang injek pad.
-- Clone karakter LIVE (andal & persis). Fallback HumanoidDescription.
-- Penempatan tanah didelegasikan ke CharacterPlacement (raycast turun).
-- Maks 1 AnimationTrack hidup -> aman limit 64.

local Players   = game:GetService("Players")

local CharacterPlacement = require(script.Parent.CharacterPlacement)

local AvatarClone = {}
AvatarClone.__index = AvatarClone

local CLONE_PREFIX = "PhotoStoryClone_"

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
	if hrp then hrp.Anchored = true end
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

	local player = Players:GetPlayerByUserId(self._userId)
	local src = player and player.Character
	if src and src.Parent and src:FindFirstChild("HumanoidRootPart") then
		local prev = src.Archivable
		src.Archivable = true
		local ok, clone = pcall(function() return src:Clone() end)
		src.Archivable = prev
		if ok and clone then model = clone end
	end

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

-- Tempatkan di titik scene (grounded). Return ok, grounded.
function AvatarClone:PlaceAt(point)
	if not self._model then return false, false end
	return CharacterPlacement.PlaceModel(self._model, point)
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

function AvatarClone:IsPosed()
	return self._track ~= nil and self._track.IsPlaying == true
end

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
