--!nonstrict
-- AvatarClone: rig avatar lokal (client-only) dibangun dari userId player yang injek pad.
-- Diparent ke Workspace (tidak replikasi), ditaruh di titik scene, dianimasikan.
-- Maks 1 AnimationTrack hidup -> aman limit 64. Bersih total saat Destroy.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AvatarClone = {}
AvatarClone.__index = AvatarClone

local function sanitize(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("BackpackItem") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			-- Jangan anchor semua part: Motor6D harus bebas supaya animasi jalan.
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	-- Anchor hanya root: rig diam di tempat, limb tetap dianimasikan motor.
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
end

function AvatarClone.new(userId, janitor)
	local self = setmetatable({}, AvatarClone)
	self._userId = userId
	self._janitor = janitor
	self._track = nil
	self._currentAnimId = nil
	self._ready = false
	return self
end

-- Build async (yields). Panggil sebelum cutscene jalan.
function AvatarClone:Build()
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

	sanitize(model)

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

	model.Name = "PhotoStoryClone_" .. tostring(self._userId)
	-- Sembunyikan dulu sampai diposisikan.
	model.Parent = nil
	self._model = model
	self._janitor:Add(function()
		self:Destroy()
	end)
	self._ready = true
	return true
end

function AvatarClone:PlaceAt(cframe)
	if not self._model then
		return
	end
	self._model:PivotTo(cframe)
	if self._model.Parent == nil then
		self._model.Parent = Workspace
	end
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
	if not okTrack or not track then
		return
	end
	track.Looped = true
	track:Play(0.2)
	self._track = track
	self._currentAnimId = animId
end

function AvatarClone:StopAnimation()
	if self._track then
		pcall(function()
			self._track:Stop(0)
			self._track:Destroy()
		end)
		self._track = nil
		self._currentAnimId = nil
	end
end

function AvatarClone:Destroy()
	self:StopAnimation()
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
end

return AvatarClone
