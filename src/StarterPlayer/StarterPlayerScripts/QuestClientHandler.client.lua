-- StarterPlayer > StarterPlayerScripts > QuestClientHandler
--
-- CHANGES dari versi sebelumnya:
--   * NEW: BoatCinematicCamera — scriptable follow camera saat naik perahu.
--     - Dipicu server via RemoteEvent StartBoatCamera / StopBoatCamera.
--     - Follow boat pivot (bukan HRP), exponential smoothing frame-rate
--       independent, subtle handheld sway, FOV cinematic per mode.
--     - Cleanup: stop remote, CharacterAdded, boat hilang, double-start.
--   * Music race fix: hard-stop current sound saat music baru main (no overlap).
--     Fading sounds di-track terpisah supaya tween Completed gak destroy sound
--     yang udah di-replace.
--   * Hapus dead branch di stopMusic (dulu dua if-branch identical).
--   * Hapus dead variable `pendingOutgoingInviteId`.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local RunService        = game:GetService("RunService")

local QuestSystem        = ReplicatedStorage:WaitForChild("QuestSystem")
local NPCModule          = require(QuestSystem:WaitForChild("NPCModule"))
local PlayerPickerModule = require(QuestSystem:WaitForChild("PlayerPickerModule"))
local DuoInviteModule    = require(QuestSystem:WaitForChild("DuoInviteModule"))
local QuestConfig        = require(QuestSystem:WaitForChild("QuestConfig"))

local Remotes              = ReplicatedStorage:WaitForChild("QuestRemotes")
local RequestBoat          = Remotes:WaitForChild("RequestBoat")
local RequestDuoInvite     = Remotes:WaitForChild("RequestDuoInvite")
local RespondDuoInvite     = Remotes:WaitForChild("RespondDuoInvite")
local CancelDuoInvite      = Remotes:WaitForChild("CancelDuoInvite")
local GetNearbyPlayers     = Remotes:WaitForChild("GetNearbyPlayers")
local ShowDuoInvitePrompt  = Remotes:WaitForChild("ShowDuoInvitePrompt")
local CloseDuoInvitePrompt = Remotes:WaitForChild("CloseDuoInvitePrompt")
local ShowWarning          = Remotes:WaitForChild("ShowWarning")
local NotifyDuoStatus      = Remotes:WaitForChild("NotifyDuoStatus")
local PlayBoatMusic        = Remotes:WaitForChild("PlayBoatMusic")
local StopBoatMusic        = Remotes:WaitForChild("StopBoatMusic")
local StartBoatCamera      = Remotes:WaitForChild("StartBoatCamera")
local StopBoatCamera       = Remotes:WaitForChild("StopBoatCamera")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NPC_NAME  = "Beedle"

----------------------------------------------------------------
-- ROOT GUI
----------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local npcLayer = Instance.new("Frame")
npcLayer.Size = UDim2.fromScale(1, 1)
npcLayer.BackgroundTransparency = 1
npcLayer.Visible = false
npcLayer.Parent = screenGui

local pickerLayer = Instance.new("Frame")
pickerLayer.Size = UDim2.fromScale(1, 1)
pickerLayer.BackgroundTransparency = 1
pickerLayer.Visible = false
pickerLayer.Parent = screenGui

local inviteLayer = Instance.new("Frame")
inviteLayer.Size = UDim2.fromScale(1, 1)
inviteLayer.BackgroundTransparency = 1
inviteLayer.Visible = false
inviteLayer.Parent = screenGui

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local activeNPC, activePicker, activeInvite

----------------------------------------------------------------
-- BOAT MUSIC
-- currentMusic: yang sedang main (fade in / playing)
-- _fadingOut: set of sounds yang sedang fade out, dijaga sampai destroy
-- Hard rule: kalau music baru fire, semua yang fading-out langsung dimatikan.
----------------------------------------------------------------
local MUSIC_VOLUME = QuestConfig.Music.volume or 0.5

local currentMusic = nil
local _fadingOut = {}  -- [sound] = true

local function killFadingOut()
	for s in pairs(_fadingOut) do
		if s and s.Parent then s:Destroy() end
	end
	_fadingOut = {}
end

local function stopMusic(immediate)
	if not currentMusic then return end
	local s = currentMusic
	currentMusic = nil

	if immediate then
		s:Destroy()
		return
	end

	_fadingOut[s] = true
	local fade = TweenService:Create(s, TweenInfo.new(QuestConfig.Boat.musicFadeOut), { Volume = 0 })
	fade:Play()
	fade.Completed:Connect(function()
		_fadingOut[s] = nil
		if s and s.Parent then s:Destroy() end
	end)
end

PlayBoatMusic.OnClientEvent:Connect(function(soundId)
	if not soundId or soundId == "" then return end
	-- Hard cut current + clear any fading-out remnants. No overlap.
	stopMusic(true)
	killFadingOut()

	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	currentMusic = s
	TweenService:Create(s, TweenInfo.new(QuestConfig.Boat.musicFadeIn), { Volume = MUSIC_VOLUME }):Play()
end)

StopBoatMusic.OnClientEvent:Connect(function()
	stopMusic(false)
end)

----------------------------------------------------------------
-- BOAT CINEMATIC CAMERA
-- Follow shot belakang-samping boat. Follow boat pivot (bukan HRP) supaya
-- stabil. Exponential smoothing frame-rate independent + subtle sway.
-- Single state (boatCam); start baru selalu stop yang lama dulu, jadi
-- render bind tidak pernah dobel.
----------------------------------------------------------------
local CAMERA_BIND_NAME = "QuestBoatCinematicCamera"

local CAMERA_PRESETS = {
	solo = {
		offset     = Vector3.new(-7, 5, -14),  -- belakang-samping, boat local space
		lookOffset = Vector3.new(0, 2.8, 5),
		fov        = 58,
	},
	duo = {
		offset     = Vector3.new(-9, 6, -17),  -- lebih lebar, dua karakter kelihatan
		lookOffset = Vector3.new(0, 3.2, 6),
		fov        = 55,
	},
}

local CAM_POS_SMOOTH  = 2.2   -- makin kecil makin floaty
local CAM_LOOK_SMOOTH = 4.0   -- look point lebih responsif dari posisi
local CAM_FOV_SMOOTH  = 1.6
local CAM_SWAY_AMP    = 0.35  -- studs; handheld feel tipis, bukan goyang liar
local CAM_SWAY_FREQ   = 0.45  -- Hz

local boatCam = nil  -- { boat, preset, saved = { camType, subject, fov } }

local function stopBoatCamera()
	if not boatCam then return end
	local saved = boatCam.saved
	boatCam = nil

	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)

	local cam = Workspace.CurrentCamera
	if not cam then return end
	cam.CameraType = saved.camType
	cam.FieldOfView = saved.fov
	-- Subject lama bisa udah destroyed (respawn) — fallback ke humanoid sekarang.
	if saved.subject and saved.subject.Parent then
		cam.CameraSubject = saved.subject
	else
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	end
end

local function startBoatCamera(boat, mode)
	stopBoatCamera()  -- idempotent; bind lama pasti lepas sebelum bind baru

	if typeof(boat) ~= "Instance" or not boat.Parent then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end

	local preset = CAMERA_PRESETS[mode] or CAMERA_PRESETS.solo

	boatCam = {
		boat = boat,
		preset = preset,
		saved = {
			camType = cam.CameraType,
			subject = cam.CameraSubject,
			fov     = cam.FieldOfView,
		},
	}

	cam.CameraType = Enum.CameraType.Scriptable

	-- Mulai dari pose kamera sekarang: shot "glide in", bukan snap.
	local camPos  = cam.CFrame.Position
	local lookPos = camPos + cam.CFrame.LookVector * 10
	local clock   = 0

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local state = boatCam
		if not state then return end

		local b = state.boat
		if not b.Parent then
			stopBoatCamera()  -- boat destroyed/despawn: langsung restore
			return
		end

		local pivot = b:GetPivot()
		clock += dt

		-- Sway halus di boat local space; shot hidup tapi tidak liar.
		local sway = Vector3.new(
			math.sin(clock * CAM_SWAY_FREQ * 2 * math.pi) * CAM_SWAY_AMP,
			math.sin(clock * CAM_SWAY_FREQ * 1.7 * 2 * math.pi) * CAM_SWAY_AMP * 0.5,
			0
		)

		local targetPos  = pivot:PointToWorldSpace(state.preset.offset + sway)
		local targetLook = pivot:PointToWorldSpace(state.preset.lookOffset)

		-- Exponential smoothing frame-rate independent: alpha = 1 - e^(-k*dt)
		local aPos  = 1 - math.exp(-CAM_POS_SMOOTH * dt)
		local aLook = 1 - math.exp(-CAM_LOOK_SMOOTH * dt)
		local aFov  = 1 - math.exp(-CAM_FOV_SMOOTH * dt)

		camPos  = camPos:Lerp(targetPos, aPos)
		lookPos = lookPos:Lerp(targetLook, aLook)

		local c = Workspace.CurrentCamera
		if not c then return end
		if (lookPos - camPos).Magnitude > 0.01 then
			c.CFrame = CFrame.lookAt(camPos, lookPos)
		end
		c.FieldOfView += (state.preset.fov - c.FieldOfView) * aFov
	end)
end

StartBoatCamera.OnClientEvent:Connect(function(boat, mode)
	startBoatCamera(boat, mode)
end)

StopBoatCamera.OnClientEvent:Connect(function()
	stopBoatCamera()
end)

----------------------------------------------------------------
-- WARNINGS
----------------------------------------------------------------
ShowWarning.OnClientEvent:Connect(function(message)
	NPCModule.ShowToast(screenGui, tostring(message), 2.5)
end)

----------------------------------------------------------------
-- DUO STATUS
----------------------------------------------------------------
NotifyDuoStatus.OnClientEvent:Connect(function(status, message)
	local fallback = {
		sent = "Invite dikirim", accepted = "Diterima", declined = "Ditolak",
		timeout = "Timeout", cancelled = "Dibatalkan", failed = "Gagal",
		ended = nil,
	}
	local msg = message or fallback[status]
	if msg then NPCModule.ShowToast(screenGui, tostring(msg), 2.5) end
end)

----------------------------------------------------------------
-- RESPAWN: stop music + camera
----------------------------------------------------------------
player.CharacterAdded:Connect(function(char)
	stopBoatCamera()
	stopMusic(true)
	killFadingOut()
	-- Pastikan kamera nempel ke humanoid baru setelah respawn.
	task.defer(function()
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
		local cam = Workspace.CurrentCamera
		if hum and cam and not boatCam then
			cam.CameraSubject = hum
		end
	end)
end)

----------------------------------------------------------------
-- DUO INVITE
----------------------------------------------------------------
ShowDuoInvitePrompt.OnClientEvent:Connect(function(inviterPlayer, inviteId, timeout)
	if activeInvite then return end
	if not inviterPlayer or not inviteId then return end

	inviteLayer.Visible = true
	activeInvite = DuoInviteModule.new(inviteLayer)
	activeInvite:Build(inviterPlayer, timeout)

	local function cleanup()
		if activeInvite then
			local inv = activeInvite
			activeInvite = nil
			task.spawn(function()
				inv:Close()
				if not activeInvite then inviteLayer.Visible = false end
			end)
		end
	end

	activeInvite:Show(
		function() RespondDuoInvite:FireServer(inviteId, true);  cleanup() end,
		function() RespondDuoInvite:FireServer(inviteId, false); cleanup() end,
		function() cleanup() end
	)
end)

CloseDuoInvitePrompt.OnClientEvent:Connect(function(_inviteId)
	if activeInvite then
		local inv = activeInvite
		activeInvite = nil
		task.spawn(function()
			inv:Close()
			if not activeInvite then inviteLayer.Visible = false end
		end)
	end
end)

----------------------------------------------------------------
-- DIALOGUE FLOW
----------------------------------------------------------------
local startDialogue, chooseSolo, chooseDuo, openPicker, closeDialogue
local isProcessing = false

closeDialogue = function()
	if activeNPC then activeNPC:Close() activeNPC = nil end
	npcLayer.Visible = false
	isProcessing = false
end

local function closePicker()
	if activePicker then
		local p = activePicker
		activePicker = nil
		task.spawn(function()
			p:Close()
			if not activePicker then pickerLayer.Visible = false end
		end)
	end
end

chooseSolo = function()
	if isProcessing then return end
	isProcessing = true
	if not activeNPC then isProcessing = false return end
	activeNPC:ClearChoices()
	activeNPC:Type(NPC_NAME, "Siap! Perahu sendiri lagi disiapkan...", function()
		RequestBoat:FireServer("solo")
		task.wait(0.4)
		if activeNPC then
			activeNPC:SetText("Selamat berlayar.")
			task.wait(1.2)
			closeDialogue()
		end
		isProcessing = false
	end)
end

openPicker = function()
	if activePicker then return end
	if isProcessing then return end

	if activeNPC then
		activeNPC:Close()
		activeNPC = nil
		npcLayer.Visible = false
	end

	pickerLayer.Visible = true
	activePicker = PlayerPickerModule.new(pickerLayer)
	activePicker:Build()

	local ok, players = pcall(function()
		return GetNearbyPlayers:InvokeServer()
	end)
	if not ok then players = {} end

	local resolved = {}
	if type(players) == "table" then
		for _, info in ipairs(players) do
			local p = Players:GetPlayerByUserId(info.UserId)
			if p then table.insert(resolved, p) end
		end
	end

	activePicker:Show(
		resolved,
		function(picked)
			if picked and picked:IsA("Player") then
				RequestDuoInvite:FireServer(picked.UserId)
			end
			closePicker()
		end,
		function() closePicker() end
	)
end

chooseDuo = function()
	if isProcessing then return end
	if not activeNPC then return end
	activeNPC:ClearChoices()
	activeNPC:Type(NPC_NAME, "Pilih partner mu...", function()
		task.wait(0.3)
		openPicker()
	end)
end

startDialogue = function()
	if activeNPC or isProcessing or activePicker or activeInvite then return end
	npcLayer.Visible = true
	activeNPC = NPCModule.new(npcLayer)
	activeNPC:Build()
	activeNPC:Type(NPC_NAME, "Halo traveler. Mau naik perahu sendiri atau berdua?", function()
		if not activeNPC then return end
		activeNPC:ShowChoices({
			{ Text = "Sendiri", Callback = chooseSolo },
			{ Text = "Berdua",  Callback = chooseDuo  },
			{ Text = "Pulang",  Callback = closeDialogue },
		})
	end)
end

----------------------------------------------------------------
-- BIND NPC PROMPT
----------------------------------------------------------------
local function bindNPC()
	local npcModel
	repeat
		npcModel = Workspace:FindFirstChild("NPC")
		if not npcModel then task.wait(1) end
	until npcModel
	if not npcModel then warn("[Quest] Workspace.NPC not found") return end
	local prompt = npcModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then warn("[Quest] NPC has no ProximityPrompt") return end
	prompt.Triggered:Connect(function(t)
		if t == player then startDialogue() end
	end)
end

bindNPC()
