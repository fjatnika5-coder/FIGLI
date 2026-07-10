-- ============================================================
--   ClientOptimizer_Safe.lua
--   Letakkan di: StarterPlayerScripts
--   Versi aman untuk fishing game — tanpa CullingManager berbahaya
-- ============================================================

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- KONFIGURASI
-- ============================================================
local CONFIG = {
	-- Shadow: matiin shadow di part jauh
	SHADOW_DISABLE_DISTANCE = 100,  -- Part > X studs dari player: shadow off
	SHADOW_CHECK_INTERVAL   = 3,    -- Cek tiap X detik (jangan terlalu sering!)

	-- NPC LOD: distance threshold animasi NPC
	LOD_FULL_DIST   = 60,    -- < ini = animasi penuh
	LOD_HALF_DIST   = 120,   -- < ini = animasi 50%
	LOD_STOP_DIST   = 200,   -- > ini = animasi berhenti
	LOD_INTERVAL    = 1.5,   -- Update LOD tiap X detik

	-- FPS logger (debug saja, tidak auto-adjust quality)
	FPS_LOG_INTERVAL = 30,   -- Print FPS average tiap X detik
}

-- ============================================================
-- MODUL: Shadow LOD
-- Matiin CastShadow pada part jauh — AMAN karena skip anchored map parts
-- Hanya target loose/unanchored parts (VFX, projectile, dll)
-- ============================================================
local ShadowLOD = {}
-- weak keys: part yang di-Destroy otomatis lepas dari cache (tidak bocor memori)
ShadowLOD._disabled = setmetatable({}, {__mode = "k"})

function ShadowLOD:GetPlayerPos()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or Vector3.zero
end

function ShadowLOD:Update()
	local playerPos = self:GetPlayerPos()

	for _, obj in ipairs(workspace:GetDescendants()) do
		-- SKIP: anchored (map/dekorasi statis) — biar Streaming yang urus
		if not obj:IsA("BasePart") or obj.Anchored then continue end
		-- SKIP: karakter local player
		if LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character) then continue end
		-- SKIP: Terrain
		if obj:IsA("Terrain") then continue end

		local dist = (obj.Position - playerPos).Magnitude
		local id = obj -- referensi langsung lebih aman dari string key

		if dist > CONFIG.SHADOW_DISABLE_DISTANCE then
			if obj.CastShadow then
				self._disabled[id] = true
				obj.CastShadow = false
			end
		else
			if self._disabled[id] then
				obj.CastShadow = true
				self._disabled[id] = nil
			end
		end
	end
end

function ShadowLOD:Start()
	if self._started then return end
	self._started = true
	task.spawn(function()
		while true do
			task.wait(CONFIG.SHADOW_CHECK_INTERVAL)
			self:Update()
		end
	end)
	print("[ShadowLOD] Shadow LOD aktif.")
end

-- ============================================================
-- MODUL: NPC LOD
-- Kurangi update animasi NPC yang jauh dari player
-- ============================================================
local NPCLodManager = {}

function NPCLodManager:GetPlayerPos()
	return ShadowLOD:GetPlayerPos()
end

function NPCLodManager:Update()
	local playerPos = self:GetPlayerPos()

	for _, model in ipairs(workspace:GetChildren()) do
		if not model:IsA("Model") then continue end
		if model == LocalPlayer.Character then continue end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid then continue end

		local root = model:FindFirstChild("HumanoidRootPart")
		if not root then continue end

		local dist = (root.Position - playerPos).Magnitude
		local animator = humanoid:FindFirstChildOfClass("Animator")

		if dist > CONFIG.LOD_STOP_DIST then
			-- Sangat jauh: stop animasi
			humanoid.EvaluateStateMachine = false
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:AdjustSpeed(0)
				end
			end

		elseif dist > CONFIG.LOD_HALF_DIST then
			-- Jauh: lambatkan animasi
			humanoid.EvaluateStateMachine = true
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:AdjustSpeed(0.5)
				end
			end

		else
			-- Dekat: full quality
			humanoid.EvaluateStateMachine = true
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					track:AdjustSpeed(1)
				end
			end
		end
	end
end

function NPCLodManager:Start()
	if self._started then return end
	self._started = true
	task.spawn(function()
		while true do
			task.wait(CONFIG.LOD_INTERVAL)
			self:Update()
		end
	end)
	print("[NPCLodManager] NPC LOD aktif.")
end

-- ============================================================
-- MODUL: FPS Logger (debug only)
-- ============================================================
local FPSLogger = {}
FPSLogger._samples = {}

function FPSLogger:Start()
	local frameCount = 0
	local lastTime = os.clock()

	RunService.Heartbeat:Connect(function()
		frameCount += 1
		local now = os.clock()
		if now - lastTime >= 1 then
			local fps = frameCount / (now - lastTime)
			frameCount = 0
			lastTime = now
			table.insert(self._samples, fps)
			if #self._samples > CONFIG.FPS_LOG_INTERVAL then
				local sum = 0
				for _, v in ipairs(self._samples) do sum += v end
				local avg = sum / #self._samples
				print(string.format("[FPSLogger] Avg FPS (last %ds): %.1f", CONFIG.FPS_LOG_INTERVAL, avg))
				self._samples = {}
			end
		end
	end)
end

-- ============================================================
-- INISIALISASI CLIENT
-- ============================================================
print("=== [ClientOptimizer] Starting... ===")

local function Init()
	LocalPlayer.Character:WaitForChild("HumanoidRootPart")
	ShadowLOD:Start()
	NPCLodManager:Start()
end

-- Handle karakter sudah ada atau baru spawn
if LocalPlayer.Character then
	task.spawn(Init)
end
LocalPlayer.CharacterAdded:Connect(function()
	task.spawn(Init)
end)

FPSLogger:Start()

print("=== [ClientOptimizer] Ready ===")