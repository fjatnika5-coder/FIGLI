--!nonstrict
-- CutsceneRunner: orkestrasi cutscene 3D di client.
-- Kamera Scriptable -> CameraPart, clone avatar (auto dari pad) di GirlPoint/BoyPoint,
-- anim, caption cinematic, gambar overlay, musik, transisi, shake/zoom. Cleanup total.

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
local TextController = require(script.Parent.TextController)
local ImageController = require(script.Parent.ImageController)

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
	self._warned = {} -- validasi: warn sekali per kunci
	return self
end

function CutsceneRunner:_warnOnce(key, msg)
	if self._warned[key] then
		return
	end
	self._warned[key] = true
	warn("[PhotoStory] " .. msg)
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
	self._text = TextController.new(screen, Config, self._lowEnd, self._janitor)
	self._images = ImageController.new(screen, Config, self._lowEnd, self._janitor)
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

function CutsceneRunner:_hideRealCharacter(userId)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if not character then
		return
	end
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

function CutsceneRunner:_buildClones(payload)
	-- Hanya sembunyikan char asli untuk role yang clone-nya berhasil.
	local girl = AvatarClone.new(payload.GirlUserId, self._janitor)
	if girl:Build() then
		self._clones.Girl = girl
		self:_hideRealCharacter(payload.GirlUserId)
	else
		self:_warnOnce("cloneGirl", "Gagal membuat avatar Girl (userId " .. tostring(payload.GirlUserId) .. ")")
	end
	if self._token.cancelled then
		return
	end
	local boy = AvatarClone.new(payload.BoyUserId, self._janitor)
	if boy:Build() then
		self._clones.Boy = boy
		self:_hideRealCharacter(payload.BoyUserId)
	else
		self:_warnOnce("cloneBoy", "Gagal membuat avatar Boy (userId " .. tostring(payload.BoyUserId) .. ")")
	end
end

function CutsceneRunner:_resolveScene(scenesFolder, scene)
	local folder = scenesFolder:FindFirstChild(scene.Name)
	if not folder then
		self:_warnOnce("scene_" .. scene.Name, "Folder scene '" .. scene.Name .. "' tidak ada di " .. Config.ScenesFolder)
		return nil
	end
	local camera = folder:FindFirstChild(scene.CameraPart or "CameraPart")
	local girl = folder:FindFirstChild(scene.GirlPoint or "GirlPoint")
	local boy = folder:FindFirstChild(scene.BoyPoint or "BoyPoint")
	if not camera then
		self:_warnOnce("cam_" .. scene.Name, "CameraPart hilang di scene '" .. scene.Name .. "'")
	end
	if not girl then
		self:_warnOnce("girl_" .. scene.Name, "GirlPoint hilang di scene '" .. scene.Name .. "'")
	end
	if not boy then
		self:_warnOnce("boy_" .. scene.Name, "BoyPoint hilang di scene '" .. scene.Name .. "'")
	end
	return { camera = camera, girl = girl, boy = boy }
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
			-- Avatar ke titik scene (footAlign supaya kaki nempel titik).
			if self._clones.Girl and parts.girl then
				self._clones.Girl:PlaceAt(parts.girl, true)
				self._clones.Girl:PlayAnimation(scene.Animations and scene.Animations.Girl)
			end
			if self._clones.Boy and parts.boy then
				self._clones.Boy:PlaceAt(parts.boy, true)
				self._clones.Boy:PlayAnimation(scene.Animations and scene.Animations.Boy)
			end

			-- Kamera.
			local camCfg = scene.Camera or {}
			camera:SetScene(
				parts.camera,
				camCfg.FOV,
				camCfg.Shake and (camCfg.ShakeAmount or 0) or 0,
				camCfg.SlowZoom and (camCfg.ZoomAmount or 0) or 0,
				scene.Duration
			)

			-- Overlay gambar + caption.
			self._images:SetScene(scene, self._token)
			self._text:SetScene(scene.Text)
			transition:ShowVignette(scene.Vignette == true, 0.4)
			if (scene.TransitionIn or "FadeBlack") ~= "Blur" then
				transition:ResetBlur()
			end

			transition:Play(scene.TransitionIn or "FadeBlack", "In", 0.45)
			if self._token.cancelled then
				break
			end

			task.spawn(function()
				self._text:Play(scene.Text, self._token)
			end)

			if not self:_wait(scene.Duration or 3) then
				break
			end

			-- Akhir scene: fade text keluar, bersihkan gambar, transisi keluar.
			self._text:FadeOut(0.25)
			transition:Play(scene.TransitionOut or "FadeBlack", "Out", 0.4)
			self._images:ClearScene()
		end
	end
end

function CutsceneRunner:Run(payload, onFinish)
	self._onFinish = onFinish

	self:_buildUI()
	self:_disableControls()

	self._camera = CameraDirector.new(self._janitor, self._lowEnd)
	self._camera:Begin()
	self._text:Begin()
	self._images:BeginGlobals()

	self:_startMusic()
	self:_buildClones(payload)

	local scenesFolder = Workspace:FindFirstChild(Config.ScenesFolder)
	if not scenesFolder then
		self:_warnOnce("noScenes", "Folder '" .. Config.ScenesFolder .. "' tidak ada di Workspace")
	elseif not self._token.cancelled then
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
