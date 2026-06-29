--!nonstrict
-- CutsceneRunner: orkestrasi cutscene 3D di client.
-- Fix: avatar + animasi ready SEBELUM kamera fade in (wait 0.15s setelah PlayAnimation).
-- TextController: per-kata dekat karakter (WorldToViewportPoint).
-- ImageController: sticker dengan Target Girl/Boy/Screen.
-- Cleanup total via Janitor.

local Players          = game:GetService("Players")
local SoundService     = game:GetService("SoundService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("PhotoStoryConfig"))

local Janitor              = require(script.Parent.Janitor)
local AvatarClone          = require(script.Parent.AvatarClone)
local CameraDirector       = require(script.Parent.CameraDirector)
local TransitionController = require(script.Parent.TransitionController)
local TextController       = require(script.Parent.TextController)
local ImageController      = require(script.Parent.ImageController)

local CutsceneRunner = {}
CutsceneRunner.__index = CutsceneRunner

local LocalPlayer = Players.LocalPlayer

local function detectLowEnd()
	if not Config.AutoLowEnd then return Config.LowEndMode end
	if Config.LowEndMode then return true end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return true end
	return false
end

function CutsceneRunner.new()
	local self = setmetatable({}, CutsceneRunner)
	self._janitor  = Janitor.new()
	self._token    = { cancelled = false }
	self._finished = false
	self._lowEnd   = detectLowEnd()
	self._clones   = {}
	self._onFinish = nil
	self._warned   = {}
	return self
end

function CutsceneRunner:_warnOnce(key, msg)
	if self._warned[key] then return end
	self._warned[key] = true
	warn("[PhotoStory] " .. msg)
end

function CutsceneRunner:_wait(duration)
	local elapsed = 0
	while elapsed < duration do
		if self._token.cancelled then return false end
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
	self._text       = TextController.new(screen, Config, self._lowEnd, self._janitor)
	self._images     = ImageController.new(screen, Config, self._lowEnd, self._janitor)
end

function CutsceneRunner:_startMusic()
	if not (typeof(Config.MusicSoundId) == "string" and string.match(Config.MusicSoundId, "^rbxassetid://%d+$")) then return end
	local sound = Instance.new("Sound")
	sound.SoundId = Config.MusicSoundId
	sound.Volume  = Config.Volume or 0.5
	sound.Looped  = true
	sound.Parent  = SoundService
	sound:Play()
	self._janitor:Add(function()
		pcall(function() sound:Stop() end)
		sound:Destroy()
	end)
end

function CutsceneRunner:_disableControls()
	local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not scripts then return end
	local mod = scripts:FindFirstChild("PlayerModule")
	if not mod then return end
	local ok, pm = pcall(require, mod)
	if not ok or not pm then return end
	local okC, controls = pcall(function() return pm:GetControls() end)
	if not okC or not controls then return end
	pcall(function() controls:Disable() end)
	self._janitor:Add(function() pcall(function() controls:Enable() end) end)
end

function CutsceneRunner:_hideRealCharacter(userId)
	local player    = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	if not character then return end
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
	local girl = AvatarClone.new(payload.GirlUserId, self._janitor)
	if girl:Build() then
		self._clones.Girl = girl
		self:_hideRealCharacter(payload.GirlUserId)
	else
		self:_warnOnce("cloneGirl", "Gagal clone avatar Girl (userId " .. tostring(payload.GirlUserId) .. ")")
	end
	if self._token.cancelled then return end
	local boy = AvatarClone.new(payload.BoyUserId, self._janitor)
	if boy:Build() then
		self._clones.Boy = boy
		self:_hideRealCharacter(payload.BoyUserId)
	else
		self:_warnOnce("cloneBoy", "Gagal clone avatar Boy (userId " .. tostring(payload.BoyUserId) .. ")")
	end
end

function CutsceneRunner:_resolveScene(scenesFolder, scene)
	local folder = scenesFolder:FindFirstChild(scene.Name)
	if not folder then
		self:_warnOnce("scene_" .. scene.Name, "Folder scene '" .. scene.Name .. "' tidak ada")
		return nil
	end
	local camera = folder:FindFirstChild(scene.CameraPart or "CameraPart")
	local girl   = folder:FindFirstChild(scene.GirlPoint  or "GirlPoint")
	local boy    = folder:FindFirstChild(scene.BoyPoint   or "BoyPoint")
	if not camera then self:_warnOnce("cam_"  .. scene.Name, "CameraPart hilang di '" .. scene.Name .. "'") end
	if not girl   then self:_warnOnce("girl_" .. scene.Name, "GirlPoint hilang di '"  .. scene.Name .. "'") end
	if not boy    then self:_warnOnce("boy_"  .. scene.Name, "BoyPoint hilang di '"   .. scene.Name .. "'") end
	return { camera = camera, girl = girl, boy = boy }
end

function CutsceneRunner:_runScenes(scenesFolder)
	local scenes     = Config.Scenes or {}
	local transition = self._transition
	local camera     = self._camera

	-- Tutup layar dulu sebelum scene pertama
	transition:CoverInstant(scenes[1] and scenes[1].TransitionIn or "FadeBlack")

	for _, scene in ipairs(scenes) do
		if self._token.cancelled then break end

		local parts = self:_resolveScene(scenesFolder, scene)
		if not parts then continue end  -- scene tidak valid, skip

		-- 1. Tempatkan avatar di titik scene
		if self._clones.Girl and parts.girl then
			self._clones.Girl:PlaceAt(parts.girl, true)
		end
		if self._clones.Boy and parts.boy then
			self._clones.Boy:PlaceAt(parts.boy, true)
		end

		-- 2. Mulai animasi SEBELUM kamera reveal
		if self._clones.Girl then
			self._clones.Girl:PlayAnimation(scene.Animations and scene.Animations.Girl)
		end
		if self._clones.Boy then
			self._clones.Boy:PlayAnimation(scene.Animations and scene.Animations.Boy)
		end

		-- 3. Tunggu sampai animasi BENAR2 jalan (pose masuk) sebelum kamera reveal.
		--    Poll IsPosed() maks ~0.35s. Kalau anim gagal load, lanjut (avatar idle, tidak stuck).
		do
			local deadline = os.clock() + 0.35
			local function bothReady()
				local g = self._clones.Girl
				local b = self._clones.Boy
				local gOk = (not g) or (not g:HasAnim()) or g:IsPosed()
				local bOk = (not b) or (not b:HasAnim()) or b:IsPosed()
				return gOk and bOk
			end
			-- minimal settle supaya pose terlihat, lalu tunggu pose
			if not self:_wait(0.12) then break end
			while not bothReady() and os.clock() < deadline do
				if self._token.cancelled then break end
				task.wait()
			end
			if self._token.cancelled then break end
		end

		-- 4. Set kamera ke CameraPart scene ini
		local camCfg = scene.Camera or {}
		camera:SetScene(
			parts.camera,
			camCfg.FOV,
			camCfg.Shake    and (camCfg.ShakeAmount or 0) or 0,
			camCfg.SlowZoom and (camCfg.ZoomAmount  or 0) or 0,
			scene.Duration
		)

		-- 5. Siapkan overlay + caption
		self._images:SetScene(scene, self._token)
		self._text:SetScene(scene.Text)
		transition:ShowVignette(scene.Vignette == true, 0.4)
		if (scene.TransitionIn or "FadeBlack") ~= "Blur" then
			transition:ResetBlur()
		end

		-- 6. Fade IN (reveal scene — avatar + animasi sudah ready)
		transition:Play(scene.TransitionIn or "FadeBlack", "In", 0.45)
		if self._token.cancelled then break end

		-- 7. Spawn text per-kata (non-blocking)
		task.spawn(function()
			self._text:Play(scene.Text, self._token)
		end)

		-- 8. Tunggu durasi scene
		if not self:_wait(scene.Duration or 3) then break end

		-- 9. Akhir scene: bersihkan, fade out
		self._text:FadeOut(0.25)
		self._text:ClearWords()
		transition:Play(scene.TransitionOut or "FadeBlack", "Out", 0.4)
		self._images:ClearScene()
	end
end

function CutsceneRunner:_preload()
	local ContentProvider = game:GetService("ContentProvider")
	local assets = {}
	-- model clone
	for _, c in pairs(self._clones) do
		local m = c.GetModel and c:GetModel()
		if m then assets[#assets + 1] = m end
	end
	-- animasi tiap scene
	for _, scene in ipairs(Config.Scenes or {}) do
		local a = scene.Animations or {}
		for _, id in pairs({ a.Girl, a.Boy }) do
			if typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") then
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				assets[#assets + 1] = anim
			end
		end
	end
	if #assets > 0 then
		pcall(function() ContentProvider:PreloadAsync(assets) end)
	end
	-- buang Animation sementara
	for _, a in ipairs(assets) do
		if typeof(a) == "Instance" and a:IsA("Animation") then a:Destroy() end
	end
end

function CutsceneRunner:Run(payload, onFinish)
	self._onFinish = onFinish

	self:_buildUI()
	self:_disableControls()

	-- Tutup layar SEBELUM ambil alih kamera + preload (sembunyikan snap/loading).
	self._transition:CoverInstant((Config.Scenes and Config.Scenes[1] and Config.Scenes[1].TransitionIn) or "FadeBlack")

	self._camera = CameraDirector.new(self._janitor, self._lowEnd)
	self._camera:Begin()
	self._text:Begin()

	-- Berikan referensi clones ke text & image controller (untuk WorldToViewportPoint)
	-- Clones belum dibangun di sini; kita set setelah buildClones.
	self:_startMusic()
	self:_buildClones(payload)

	-- Setelah build, berikan clone refs ke controllers
	self._text:SetClones(self._clones)
	self._images:SetClones(self._clones)

	-- Preload model clone + semua animasi scene supaya tidak nge-lag/late saat shoot.
	self:_preload()

	self._images:BeginGlobals()

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
	if self._finished then return end
	self._finished = true
	self._token.cancelled = true

	-- Bersihkan kata-kata text yang masih ada
	if self._text then
		pcall(function() self._text:ClearWords() end)
	end
	if self._images then
		pcall(function() self._images:ClearScene() end)
	end

	for _, clone in pairs(self._clones) do
		pcall(function() clone:Destroy() end)
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
