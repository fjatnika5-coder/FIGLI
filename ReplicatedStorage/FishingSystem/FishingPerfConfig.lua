-- FishingPerfConfig
-- Location: ReplicatedStorage/FishingSystem/FishingPerfConfig (ModuleScript)
--
-- Satu tempat untuk semua angka performa sistem fishing.
-- Dipakai oleh: FishingSystem server (radius broadcast) dan
-- FishingSystem client (LOD VFX, budget efek, interval simulasi hook lain).
--
-- LOD splash (client, per jarak dari splash):
--   LOCAL : efek milik sendiri — selalu full quality.
--   NEAR  : full komponen (Sound/Light/Beam/Trail hidup), emit x NearEmitMultiplier.
--   MID   : tanpa Sound + Light, emit x MidEmitMultiplier.
--   FAR   : tanpa Sound + Light + Beam + Trail, emit x FarEmitMultiplier,
--           cleanup lebih pendek. Template tetap sama → efek tetap terlihat.
--   > FarRadius : di-skip client (server juga cull di VfxBroadcastRadius).

local RunService = game:GetService("RunService")

local PerfConfig = {}

-- ═══════════════════════════════════════════════════════════════
-- SERVER: RADIUS BROADCAST (studs)
-- ═══════════════════════════════════════════════════════════════
PerfConfig.VfxBroadcastRadius = 350     -- batas terluar splash dikirim (>= FarRadius tier tertinggi)
PerfConfig.CastBroadcastRadius = 80     -- replikasi cast (client memfilter > 60, margin 20)
PerfConfig.CleanupBroadcastRadius = 150 -- relay cleanup cast (client punya safety timeout sendiri)

-- ═══════════════════════════════════════════════════════════════
-- CLIENT: KUALITAS VFX
-- ForceQuality: "HIGH" / "MEDIUM" / "LOW" untuk memaksa tier,
-- nil = deteksi otomatis (graphics setting player + jenis perangkat).
-- ═══════════════════════════════════════════════════════════════
PerfConfig.ForceQuality = nil

PerfConfig.Quality = {
	HIGH = {
		NearRadius = 80,
		MidRadius = 180,
		FarRadius = 350,
		NearEmitMultiplier = 1.0,
		MidEmitMultiplier = 0.45,
		FarEmitMultiplier = 0.15,
		MaxTotalEffects = 10,           -- total splash aktif; saat penuh: efek lokal/terdekat menggusur yang terjauh
		VfxCooldown = 0.15,             -- jeda minimum antar splash per caster (dedup "satu cast satu splash")
		MaxOtherHooks = 4,
		OtherHookPhysicsInterval = 0.083,
		OtherHookLandCheckInterval = 0.08,
	},
	MEDIUM = {
		NearRadius = 60,
		MidRadius = 140,
		FarRadius = 250,
		NearEmitMultiplier = 0.6,
		MidEmitMultiplier = 0.3,
		FarEmitMultiplier = 0.1,
		MaxTotalEffects = 6,
		VfxCooldown = 0.25,
		MaxOtherHooks = 3,
		OtherHookPhysicsInterval = 0.1,
		OtherHookLandCheckInterval = 0.12,
	},
	LOW = {
		NearRadius = 50,
		MidRadius = 100,
		FarRadius = 160,
		NearEmitMultiplier = 0.35,
		MidEmitMultiplier = 0.2,
		FarEmitMultiplier = 0.08,
		MaxTotalEffects = 3,
		VfxCooldown = 0.4,
		MaxOtherHooks = 2,
		OtherHookPhysicsInterval = 0.125,
		OtherHookLandCheckInterval = 0.15,
	},
}

-- ═══════════════════════════════════════════════════════════════
-- DETEKSI TIER
-- Bukan hanya TouchEnabled: membaca SavedQualityLevel milik player
-- (read-only, tidak mengubah setting Roblox player).
-- ═══════════════════════════════════════════════════════════════
local cachedQualityName = nil

function PerfConfig.GetQualityName()
	if PerfConfig.ForceQuality and PerfConfig.Quality[PerfConfig.ForceQuality] then
		return PerfConfig.ForceQuality
	end

	if cachedQualityName then
		return cachedQualityName
	end

	local quality = "HIGH"

	if RunService:IsClient() then
		local ok, saved = pcall(function()
			return UserSettings():GetService("UserGameSettings").SavedQualityLevel
		end)
		if ok and saved and saved ~= Enum.SavedQualitySetting.Automatic then
			local level = saved.Value
			if level <= 3 then
				quality = "LOW"
			elseif level <= 6 then
				quality = "MEDIUM"
			end
		end

		local UserInputService = game:GetService("UserInputService")
		local isTouchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		if isTouchOnly and quality == "HIGH" then
			quality = "MEDIUM"
		end
	end

	cachedQualityName = quality
	return quality
end

function PerfConfig.Get()
	return PerfConfig.Quality[PerfConfig.GetQualityName()]
end

return PerfConfig
