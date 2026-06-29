--!nonstrict
-- CutsceneRunner: orkestrasi cutscene 3D di client.
-- Kamera Scriptable -> CameraPart, clone avatar di GirlPoint/BoyPoint, anim, text,
-- musik, transisi, shake/zoom. Cleanup total saat selesai/batal.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("PhotoStoryConfig"))

local Janitor = require(script.Parent.Janitor)
local AvatarClone = require(script.Parent.AvatarClone)
local CameraDirector = require(script.Parent.CameraDirector)
local TransitionController = require(script.Parent.TransitionController)

local CutsceneRunner = {}
CutsceneRunner.__index = CutsceneRunner

local LocalPlayer = Players.LocalPlayer

local function detectLowEnd()
	if not Config.AutoLowEnd then
		return Config.LowEndMode
	end
	if Config.LowEndMode then
		return true
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return true
	end
	return false
end

function CutsceneRunner.new()
	local self = setmetatable({}, CutsceneRunner)
	self._janitor = Janitor.new()
	self._token = { cancelled = false }
	self._finished = false
	self._lowEnd = detectLowEnd()
	self._clones = {}
	self._onFinish = nil
	return self
end

function CutsceneRunner:_wait(duration)
	local elapsed = 0
	while elapsed < duration do
		if self._token.cancelled then
			return false
		end
		elapsed += task.wait()
	end
	return not self._token.cancelled
end

function CutsceneRunner:_buildUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "PhotoStoryGui"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	screen.DisplayOrder = 5000
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = playerGui
	self._janitor:Add(screen, "Destroy")
	self._screen = screen
	self._transition = TransitionController.new(screen, Config, self._lowEnd, self._janitor)
end

function CutsceneRunner:_startMusic()
	if not (typeof(Config.MusicSoundId) == "string" and string.match(Config.MusicSoundId, "^rbxassetid://%d+$")) then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = Config.MusicSoundId
	sound.Volume = Config.Volume or 0.5
	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	self._janitor:Add(function()
		pcall(function()
			sound:Stop()
		end)
		sound:Destroy()
	end)
end

-- Nonaktifkan kontrol player lokal selama cutscene; aktifkan lagi saat cleanup.
function CutsceneRunner:_disableControls()
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not scripts then
		return
	end
	local moduleScript = scripts:FindFirstChild("PlayerModule")
	if not moduleScript then
		return
	end
	local ok, playerModule = pcall(require, moduleScript)
	if not ok or not playerModule then
		return
	end
	local okC, controls = pcall(function()
		return playerModule:GetControls()
	end)
	if not okC or not controls then
		return
	end
	pcall(function()
		controls:Disable()
	end)
	self._janitor:Add(function()
		pcall(function()
			controls:Enable()
		end)
	end)
end

-- Sembunyikan karakter asli kedua peserta secara lokal (hindari avatar duplikat di frame).
function CutsceneRunner:_hideRealCharacters(userIds)
	for _, userId in ipairs(userIds) do
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") then
					local prev = part.LocalTransparencyModifier
					part.LocalTransparencyModifier = 1
					self._janitor:Add(function()
						if part and part.Parent then
							part.LocalTransparencyModifier = prev
						end
					end)
				end
			end
		end
	end
end

function CutsceneRunner:_buildClones(payload)
	local girl = AvatarClone.new(payload.GirlUserId, self._janitor)
	if girl:Build() then
		self._clones.Girl = girl
	end
	if self._token.cancelled then
		return
	end
	local boy = AvatarClone.new(payload.BoyUserId, self._janitor)
	if boy:Build() then
		self._clones.Boy = boy
	end
end

function CutsceneRunner:_resolveScene(scenesFolder, scene)
	local folder = scenesFolder:FindFirstChild(scene.Name)
	if not folder then
		return nil
	end
	return {
		camera = folder:FindFirstChild(scene.CameraPart or "CameraPart"),
		girl = folder:FindFirstChild(scene.GirlPoint or "GirlPoint"),
		boy = folder:FindFirstChild(scene.BoyPoint or "BoyPoint"),
	}
end

function CutsceneRunner:_runScenes(scenesFolder)
	local scenes = Config.Scenes or {}
	local transition = self._transition
	local camera = self._camera

	transition:CoverInstant(scenes[1] and scenes[1].TransitionIn or "FadeBlack")

	for _, scene in ipairs(scenes) do
		if self._token.cancelled then
			break
		end

		local parts = self:_resolveScene(scenesFolder, scene)
		if parts then
			-- Posisikan clone + animasi (sembunyikan yang tidak ada titiknya).
			if self._clones.Girl and parts.girl and parts.girl:IsA("BasePart") then
				self._clones.Girl:PlaceAt(parts.girl.CFrame)
				self._clones.Girl:PlayAnimation(scene.Animations and scene.Animations.Girl)
			end
			if self._clones.Boy and parts.boy and parts.boy:IsA("BasePart") then
				self._clones.Boy:PlaceAt(parts.boy.CFrame)
				self._clones.Boy:PlayAnimation(scene.Animations and scene.Animations.Boy)
			end

			local camCfg = scene.Camera or {}
			camera:SetScene(
				parts.camera,
				camCfg.FOV,
				camCfg.Shake and (camCfg.ShakeAmount or 0) or 0,
				camCfg.SlowZoom and (camCfg.ZoomAmount or 0) or 0,
				scene.Duration
			)

			transition:SetCaption(scene.Text)
			transition:ShowVignette(scene.Vignette == true, 0.4)
			if (scene.TransitionIn or "FadeBlack") ~= "Blur" then
				transition:ResetBlur()
			end

			transition:Play(scene.TransitionIn or "FadeBlack", "In", 0.45)
			if self._token.cancelled then
				break
			end

			task.spawn(function()
				transition:PlayCaption(scene.Text, self._token)
			end)

			if not self:_wait(scene.Duration or 3) then
				break
			end

			transition:Play(scene.TransitionOut or "FadeBlack", "Out", 0.4)
		end
	end
end

function CutsceneRunner:Run(payload, onFinish)
	self._onFinish = onFinish

	local userIds = { payload.GirlUserId, payload.BoyUserId }

	self:_buildUI()
	self:_disableControls()

	self._camera = CameraDirector.new(self._janitor, self._lowEnd)
	self._camera:Begin()

	self:_startMusic()
	self:_hideRealCharacters(userIds)
	self:_buildClones(payload)

	local scenesFolder = Workspace:FindFirstChild(Config.ScenesFolder)
	if scenesFolder and not self._token.cancelled then
		self:_runScenes(scenesFolder)
	end

	self:_finish()
end

function CutsceneRunner:Stop()
	self._token.cancelled = true
end

function CutsceneRunner:_finish()
	if self._finished then
		return
	end
	self._finished = true
	self._token.cancelled = true

	for _, clone in pairs(self._clones) do
		pcall(function()
			clone:Destroy()
		end)
	end
	self._clones = {}

	self._janitor:Destroy()

	if self._onFinish then
		local cb = self._onFinish
		self._onFinish = nil
		task.spawn(cb)
	end
end

return CutsceneRunner
