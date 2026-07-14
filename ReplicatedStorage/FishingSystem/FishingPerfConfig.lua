-- FishingPerfConfig
-- Location: ReplicatedStorage/FishingSystem/FishingPerfConfig (ModuleScript)
--
-- Satu tempat untuk semua angka performa sistem fishing.
-- Dipakai oleh: FishingSystem server (radius broadcast) dan
-- FishingSystem client (budget VFX, LOD, interval simulasi hook lain).
--
-- Tidak mengubah gameplay: hanya menentukan SIAPA yang menerima efek,
-- seberapa banyak efek boleh aktif, dan seberapa sering simulasi berjalan.

local RunService = game:GetService("RunService")

local PerfConfig = {}

-- ═══════════════════════════════════════════════════════════════
-- SERVER: RADIUS BROADCAST (studs)
-- Efek dunia hanya dikirim ke player dalam radius ini.
-- Caster/pemilik SELALU menerima efek miliknya sendiri.
-- ═══════════════════════════════════════════════════════════════
PerfConfig.VfxBroadcastRadius = 150     -- splash VFX rod khusus
PerfConfig.CastBroadcastRadius = 80     -- replikasi cast (client memfilter > 60, margin 20)
PerfConfig.CleanupBroadcastRadius = 150 -- relay cleanup cast (client punya safety timeout sendiri)

-- ═══════════════════════════════════════════════════════════════
-- CLIENT: KUALITAS VFX
-- ForceQuality: isi "HIGH" / "MEDIUM" / "LOW" untuk memaksa tier,
-- nil = deteksi otomatis (graphics setting player + jenis perangkat).
-- ═══════════════════════════════════════════════════════════════
PerfConfig.ForceQuality = nil

PerfConfig.Quality = {
	HIGH = {
		NearbyEffectRadius = 150,       -- efek caster lain di luar radius ini di-skip client
		MaxTotalEffects = 10,           -- total splash VFX aktif bersamaan
		MaxEffectsPerPlayer = 2,        -- splash aktif per caster
		VfxCooldown = 0.15,             -- jeda minimum antar splash per caster
		NearbyEmitMultiplier = 1.0,     -- skala partikel efek milik player LAIN (lokal selalu 1.0)
		MaxOtherHooks = 4,              -- hook player lain yang disimulasikan
		OtherHookPhysicsInterval = 0.083,
		OtherHookLandCheckInterval = 0.08,
	},
	MEDIUM = {
		NearbyEffectRadius = 110,
		MaxTotalEffects = 6,
		MaxEffectsPerPlayer = 1,
		VfxCooldown = 0.25,
		NearbyEmitMultiplier = 0.6,
		MaxOtherHooks = 3,
		OtherHookPhysicsInterval = 0.1,
		OtherHookLandCheckInterval = 0.12,
	},
	LOW = {
		NearbyEffectRadius = 70,
		MaxTotalEffects = 3,
		MaxEffectsPerPlayer = 1,
		VfxCooldown = 0.4,
		NearbyEmitMultiplier = 0.35,
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
