-- FishingSystem Client
-- Location: StarterPlayer/StarterPlayerScripts/FishingSystem (LocalScript)
--
-- PERF AUDIT FIX (semua angka di ReplicatedStorage.FishingSystem.FishingPerfConfig):
-- [PERF-2] Tier kualitas VFX (HIGH/MEDIUM/LOW) dari graphics setting player +
--          jenis perangkat. Budget efek (total aktif, per caster, cooldown)
--          mengikuti tier.
-- [PERF-3] VFX LOD bertingkat: LOCAL (full) / NEAR / MID / FAR. Efek pemain
--          jauh tetap terlihat dengan template yang sama, emit lebih rendah;
--          MID membuang Sound + Light, FAR juga membuang Beam + Trail.
-- [PERF-4] Budget efek dengan prioritas: saat penuh, efek LocalPlayer dan
--          efek terdekat menggusur efek non-lokal terjauh.
-- [PERF-5] Metadata template (waktu cleanup) di-cache per rod; setiap clone
--          maksimal SATU traversal GetDescendants.
-- [PERF-7] Counter runtime (_G.GetFishingVFXStats) + label MicroProfiler
--          "FishingSplashVFX" untuk pembuktian.
-- [PERF-8] VFX Timeline Runner: Attribute timeline asset (EmitDelay/
--          EmitDuration/AutoEmit/EmitCount/SFX/CleanupTime) dieksekusi benar;
--          satu task per grup delay; FAR memakai prototype ringan per rod;
--          budget berbobot jumlah emitter dengan prioritas LocalPlayer.
-- [PERF-6] Interval simulasi hook player lain + jumlah maksimum hook
--          mengikuti tier perangkat.

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local RepStorage   = game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem")
local CS           = game:GetService("CollectionService")
local Debris       = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- Forward declaration agar callback VFX memakai state lokal, bukan global _G.
local gameState

local modulesFolder       = RepStorage:WaitForChild("FishingModules")
local FishingConfig       = require(RepStorage:WaitForChild("FishingConfig"))
local PerfConfig          = require(RepStorage:WaitForChild("FishingPerfConfig"))
local SoundManager        = require(modulesFolder:WaitForChild("SoundManager"))
local GUIManager          = require(modulesFolder:WaitForChild("GUIManager"))
local AnimationController = require(modulesFolder:WaitForChild("AnimationController"))
local PowerBarSystem      = require(modulesFolder:WaitForChild("PowerBarSystem"))
local MinigameSystem      = require(modulesFolder:WaitForChild("MinigameSystem"))
local CastingSystem       = require(modulesFolder:WaitForChild("CastingSystem"))

-- [PERF-2] Tier kualitas perangkat ini.
local PERF = PerfConfig.Get()

local fishGiverEvent        = RepStorage:WaitForChild("FishGiver", 30)
local castReplicationEvent  = RepStorage:WaitForChild("CastReplication", 30)
local cleanupCastEvent      = RepStorage:WaitForChild("CleanupCast", 30)
local showNotificationEvent = RepStorage:WaitForChild("ShowNotification", 30)
local splashTemplate        = RepStorage:FindFirstChild("Splash")
local fishCaughtResult      = RepStorage:WaitForChild("FishCaughtResult", 30)
local fishAssetFolder       = RepStorage:WaitForChild("Assets"):WaitForChild("Fish")

-- ═══════════════════════════════════════════════════════════════
-- NOTIFICATION MANAGER
-- ═══════════════════════════════════════════════════════════════
local NotificationManager = nil
task.spawn(function()
	local ok, err = pcall(function()
		local mgr = require(modulesFolder:WaitForChild("FishingNotificationManager", 10))
		local gui = player:WaitForChild("PlayerGui")
		if mgr:Initialize(gui) then
			NotificationManager = mgr
			_G.FishingNotificationManager = mgr
			_G.ShowFishingNotification = function(text, duration, color)
				pcall(function() mgr:ShowEvent(text, duration, color) end)
			end
		else
			warn("[FishingSystem] NotificationManager Initialize gagal — cek struktur FishingNotifications ScreenGui")
		end
	end)
	if not ok then
		warn("[FishingSystem] NotificationManager error:", err)
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- FISH TOOL CACHE
-- ═══════════════════════════════════════════════════════════════
local fishToolCache = {}
local fishToolWatched = setmetatable({}, {__mode = "k"})
local function registerFishTool(fishId, tool)
	if not fishId or not tool then return end
	fishToolCache[tostring(fishId)] = tool
	if fishToolWatched[tool] then return end
	fishToolWatched[tool] = true
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then fishToolCache[tostring(fishId)] = nil end
	end)
end
local function findFishToolById(fishId)
	local cached = fishToolCache[tostring(fishId)]
	if cached and cached.Parent then return cached end
	if cached then fishToolCache[tostring(fishId)] = nil end
	local function searchIn(container)
		if not container then return nil end
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				local id = tool:FindFirstChild("FishId")
				if id and id:IsA("StringValue") and id.Value == tostring(fishId) then
					registerFishTool(fishId, tool)
					return tool
				end
			end
		end
		return nil
	end
	return searchIn(player:FindFirstChild("Backpack")) or searchIn(player.Character)
end

local function destroySplash(splash)
	if not splash then return end
	pcall(function() if splash and splash.Parent then splash:Destroy() end end)
end

local function releaseHook(hook)
	if not hook then return end
	if CastingSystem and type(CastingSystem.ReturnHook) == "function" then
		local ok = pcall(function() CastingSystem:ReturnHook(hook) end)
		if ok then return end
	end
	pcall(function()
		if hook.Parent then hook:Destroy() end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- VFX SPLASH SYSTEM
-- ═══════════════════════════════════════════════════════════════
local VfxSplashFolder = RepStorage:WaitForChild("Assets"):WaitForChild("VfxSplash")
local vfxSplashEvent = RepStorage:WaitForChild("VFXSplashEvent", 30)

if not vfxSplashEvent or not vfxSplashEvent:IsA("RemoteEvent") then
	error("[FishingSystem] VFXSplashEvent RemoteEvent tidak tersedia")
end

local RODS_WITH_SPLASH_SET = {}
for _, name in ipairs({
	"BloodmoonRod","LavaRod","PhantomRod","Rod Of The Eternal King",
	"Royal Spider","Fabulous Rod","Youkatta","Jiyuu","LightingRod",
	"Aqua Rod","AdminRod","Celestial Blossom Rod","Slash Katana",
	"AuraluxRod","Kyouyariin","UmbraluxRod","Cherryna","Nine",
	"OwnerRod","Vin","Esteh","Mei","Gulabatu","FrozenkRod","x1x1x1 Hammer",
	"Princess Parasol","AscensionRod","OblivonRod","Jiyu","Solitario","Soya","PASEP","Ceisya",
	"DiamonRod","DreadspireRod","EvacoreRod","FrostwindRod","OwnerRod1","OwnerRodsss",
	"Crescendo Scythe","Wings of Everlove","Aether Monarch","Aurelian Rod","Cupid Harp",
	"Dark Matter Scythe","Blackhole Sword","The Vanquisher","Eternal Flower","Little","Miyuki"
	}) do
	RODS_WITH_SPLASH_SET[name] = true
end

-- [PERF-2] Budget berbobot & LOD dari tier perangkat.
local VFX_MAX_CLEANUP_TIME = 12.0
local VFX_TIME_GROUP_STEP  = 0.05 -- pembulatan waktu timeline → satu task per grup waktu

-- [userId] = { inst, position, cost, token }
local activeEffects      = {}
local totalActiveCost    = 0
local playerVFXLastSpawn = {}
local otherPlayersHooks  = {}
local VFX_SPLASH_ENABLED = true

-- [PERF-5] Metadata template per rod (sekali per sesi): bobot emitter +
-- Attribute SFX root. Prototype FAR dibangun sekali per rod.
local templateMetaCache = {}
local farProtoCache = {}

-- [PERF-7] Counter runtime untuk pembuktian.
local vfxStats = {
	spawnedTotal = 0,
	spawnedLocal = 0,
	spawnedNear = 0,
	spawnedMid = 0,
	spawnedFar = 0,
	skippedRange = 0,
	skippedBudget = 0,
	duplicateBlocked = 0,
	evictedForPriority = 0,
	farProtoBuilds = 0,
}

_G.GetFishingVFXStats = function()
	local snapshot = table.clone(vfxStats)
	snapshot.activeCost = totalActiveCost
	local activeCount = 0
	for _ in pairs(activeEffects) do activeCount += 1 end
	snapshot.activeNow = activeCount
	snapshot.quality = PerfConfig.GetQualityName()
	return snapshot
end

_G.SetSplashVFXEnabled = function(enabled)
	VFX_SPLASH_ENABLED = enabled
	if not enabled then
		for _, rec in pairs(activeEffects) do
			rec.token.cancelled = true
			if rec.inst and rec.inst.Parent then rec.inst:Destroy() end
		end
		table.clear(activeEffects)
		totalActiveCost = 0
	end
end
_G.GetSplashVFXEnabled = function() return VFX_SPLASH_ENABLED end

task.spawn(function()
	task.wait(1)
	if _G.GraphicsVFXEnabled == false then
		VFX_SPLASH_ENABLED = false
	end
end)

local function isVFXAllowed()
	if not VFX_SPLASH_ENABLED then return false end
	if _G.GraphicsVFXEnabled == false then return false end
	return true
end

local function getLocalHrpPosition()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

-- [PERF-3] Pilih LOD berdasarkan jarak. nil = di luar jangkauan tier.
local function selectVFXLOD(casterPlayer, splashPosition)
	if casterPlayer == player then return "LOCAL", 0 end
	local myPos = getLocalHrpPosition()
	if not myPos then return nil, math.huge end
	local dist = (myPos - splashPosition).Magnitude
	if dist <= PERF.NearRadius then return "NEAR", dist end
	if dist <= PERF.MidRadius then return "MID", dist end
	if dist <= PERF.FarRadius then return "FAR", dist end
	return nil, dist
end

local function destroyEffectRecord(userId)
	local rec = activeEffects[userId]
	if not rec then return end
	activeEffects[userId] = nil
	totalActiveCost = math.max(0, totalActiveCost - rec.cost)
	rec.token.cancelled = true
	if rec.inst and rec.inst.Parent then
		rec.inst:Destroy()
	end
end

local function cleanupPlayerVFX(playerId)
	destroyEffectRecord(playerId)
end

-- [PERF-4] Budget BERBOBOT (bobot = jumlah emitter varian yang di-spawn):
-- - Cooldown per caster = dedup event → satu cast satu splash.
-- - Per caster maksimal satu efek aktif (yang baru menggantikan miliknya).
-- - Saat budget penuh: efek non-lokal TERJAUH digusur selama pendatang lebih
--   prioritas (LocalPlayer, atau lebih dekat). Efek LocalPlayer SELALU tampil
--   walau budget habis oleh efeknya sendiri.
local function tryReserveVFXBudget(ownerUserId, isLocalOwner, distance, cost)
	if not isVFXAllowed() then return false end

	local now = tick()
	if (now - (playerVFXLastSpawn[ownerUserId] or 0)) < PERF.VfxCooldown then
		vfxStats.duplicateBlocked += 1
		return false
	end

	if activeEffects[ownerUserId] then
		destroyEffectRecord(ownerUserId)
	end

	local maxCost = PERF.MaxVfxCost
	if totalActiveCost + cost > maxCost then
		local myPos = getLocalHrpPosition()
		while totalActiveCost + cost > maxCost do
			local farthestId, farthestDist = nil, -1
			for uid, rec in pairs(activeEffects) do
				if uid ~= player.UserId then
					local d = myPos and (myPos - rec.position).Magnitude or math.huge
					if d > farthestDist then
						farthestDist = d
						farthestId = uid
					end
				end
			end
			if not farthestId then
				-- Tersisa hanya efek lokal; efek lokal baru tetap boleh tampil.
				if isLocalOwner then break end
				vfxStats.skippedBudget += 1
				return false
			end
			if isLocalOwner or distance < farthestDist then
				destroyEffectRecord(farthestId)
				vfxStats.evictedForPriority += 1
			else
				vfxStats.skippedBudget += 1
				return false
			end
		end
	end

	playerVFXLastSpawn[ownerUserId] = now
	return true
end

local function ensureAttachment(parent, name)
	if not parent or not parent.Parent then return nil end
	local att = parent:FindFirstChild(name)
	if att and not att:IsA("Attachment") then att:Destroy(); att = nil end
	if not att then
		att        = Instance.new("Attachment")
		att.Name   = name
		att.Parent = parent
	end
	return att
end

local function getMaxLifetime(emitter)
	local lt = emitter.Lifetime
	if typeof(lt) == "NumberRange" then return lt.Max end
	return 1.0
end

-- [PERF-5] Metadata sekali per rod: bobot (jumlah emitter) + Attribute SFX root.
local function getTemplateMeta(rodName, template)
	local meta = templateMetaCache[rodName]
	if meta then return meta end
	local count = 0
	for _, desc in ipairs(template:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then count += 1 end
	end
	local sfx = template:GetAttribute("SFX")
	meta = {
		cost = math.max(1, count),
		sfx = (typeof(sfx) == "string" and sfx ~= "") and sfx or nil,
	}
	templateMetaCache[rodName] = meta
	return meta
end

-- AutoEmit tanpa EmitDuration TIDAK ditebak per emitter: fallback per template
-- dari config (AutoEmitDurationOverrides), default AutoEmitFallbackDuration.
local function getAutoEmitFallbackDuration(rodName)
	local overrides = PerfConfig.AutoEmitDurationOverrides
	local v = overrides and overrides[rodName]
	return tonumber(v) or PerfConfig.AutoEmitFallbackDuration or 2.0
end

-- Skor heuristik emitter untuk prototype FAR: ukuran maksimum × intensitas.
local function getEmitterScore(emitter)
	local sizeMax = 0
	local ok, size = pcall(function() return emitter.Size end)
	if ok and typeof(size) == "NumberSequence" then
		for _, kp in ipairs(size.Keypoints) do
			if kp.Value > sizeMax then sizeMax = kp.Value end
		end
	end
	local intensity = emitter:GetAttribute("EmitCount") or emitter.Rate or 1
	return (sizeMax + 0.1) * (intensity + 1)
end

-- [PERF-8] Prototype FAR: dibangun SEKALI per rod dari subset emitter visual
-- utama (FarPrototypeEmitterCount), lalu di-clone murah (belasan instance)
-- untuk setiap splash jauh — bukan clone template full 149–201 emitter.
local function getFarPrototype(rodName, template)
	local cached = farProtoCache[rodName]
	if cached then return cached end

	local temp = template:Clone()
	local emitters = {}
	for _, desc in ipairs(temp:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			emitters[#emitters + 1] = desc
		end
	end
	table.sort(emitters, function(a, b)
		return getEmitterScore(a) > getEmitterScore(b)
	end)

	local proto = Instance.new("Part")
	proto.Name = "FarProto_" .. rodName
	proto.Anchored = true
	proto.CanCollide = false
	proto.CanQuery = false
	proto.CanTouch = false
	proto.Transparency = 1
	proto.Size = Vector3.new(1, 1, 1)

	-- [FIX-ATT] Emitter yang menempel pada Attachment kehilangan posisi/
	-- orientasi bila di-parent langsung ke Part. Buat Attachment padanan
	-- (dedup per Attachment asli) dengan CFrame relatif pivot template.
	local okPivot, tempPivot = pcall(temp.GetPivot, temp)
	local attachmentMap = {}
	local function getProtoAttachment(origAtt)
		local existing = attachmentMap[origAtt]
		if existing then return existing end
		local att = Instance.new("Attachment")
		att.Name = origAtt.Name
		if okPivot and tempPivot then
			local okCf, worldCf = pcall(function() return origAtt.WorldCFrame end)
			att.CFrame = (okCf and worldCf) and tempPivot:ToObjectSpace(worldCf) or origAtt.CFrame
		else
			att.CFrame = origAtt.CFrame
		end
		att.Parent = proto
		attachmentMap[origAtt] = att
		return att
	end

	local n = math.min(PerfConfig.FarPrototypeEmitterCount or 6, #emitters)
	for i = 1, n do
		local orig = emitters[i]
		local c = orig:Clone() -- Attribute timeline ikut ter-copy
		c.Enabled = false
		if orig.Parent and orig.Parent:IsA("Attachment") then
			c.Parent = getProtoAttachment(orig.Parent)
		else
			c.Parent = proto
		end
	end
	temp:Destroy()

	farProtoCache[rodName] = proto
	vfxStats.farProtoBuilds += 1
	return proto
end

local VFX_LIGHT_CLASSES = { PointLight = true, SpotLight = true, SurfaceLight = true }

local function getLODEmitScale(lodName)
	if lodName == "LOCAL" then return 1 end
	if lodName == "NEAR" then return PERF.NearEmitMultiplier end
	if lodName == "MID" then return PERF.MidEmitMultiplier end
	return PERF.FarEmitMultiplier
end

-- ═══════════════════════════════════════════════════════════════
-- [PERF-8] VFX TIMELINE RUNNER
-- Pemrosesan Attribute (SATU traversal per clone; semua komponen
-- dimatikan sebelum container di-Parent):
--   EmitDelay (emitter/Beam/Trail) : waktu mulai relatif spawn.
--   EmitDuration                   : lama aktif; Enabled=false setelahnya.
--   AutoEmit=true                  : window Enabled [delay, delay+duration];
--                                    tanpa EmitDuration → fallback config.
--   EmitCount>0                    : burst Emit(count×skala LOD) pada t=delay.
--   Emitter tanpa AutoEmit/EmitCount : window biasa (delay + duration/fallback).
--   Beam/Trail tanpa attribute     : state Enabled asli dipulihkan pada t=0.
--   Sound PlayDelay/AutoPlay       : Play terjadwal (LOCAL/NEAR saja).
--   CleanupTime (root)             : override umur efek.
--   SFX (root)                     : nama sound → SoundManager (LOCAL/NEAR).
-- Grup waktu 0.05 s → SATU task.delay per grup waktu, bukan per emitter.
-- Timing identik di semua LOD; LOD hanya mengubah skala & komponen.
-- ═══════════════════════════════════════════════════════════════
local function buildTimeline(container, rodName, lodName, emitScale, folderPivot, splashPosition)
	local schedule = {}
	local attachBeams = {}
	local maxEnd = 0
	local fallbackDuration = getAutoEmitFallbackDuration(rodName)
	local keepSoundLight = lodName == "LOCAL" or lodName == "NEAR"
	local toDestroy = {}

	local function at(t, fn)
		if t < 0 then t = 0 end
		local key = math.floor(t / VFX_TIME_GROUP_STEP + 0.5)
		local bucket = schedule[key]
		if not bucket then
			bucket = {}
			schedule[key] = bucket
		end
		bucket[#bucket + 1] = fn
	end

	local function scheduleWindow(inst, delay, duration, lifetime)
		at(delay, function() inst.Enabled = true end)
		at(delay + duration, function() inst.Enabled = false end)
		local endT = delay + duration + (lifetime or 0)
		if endT > maxEnd then maxEnd = endT end
	end

	for _, desc in ipairs(container:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			local delay     = desc:GetAttribute("EmitDelay") or 0
			local duration  = desc:GetAttribute("EmitDuration")
			local autoEmit  = desc:GetAttribute("AutoEmit") == true
			local emitCount = desc:GetAttribute("EmitCount")
			local lifetime  = getMaxLifetime(desc)
			-- [FIX-TS] TimeScale_Duration ikut umur efek (cleanup saja;
			-- tidak menyentuh Rate/EmitCount/timing delay-duration).
			local timeScaleDur = desc:GetAttribute("TimeScale_Duration") or 0
			if emitScale < 1 then
				desc.Rate = desc.Rate * emitScale
			end
			desc.Enabled = false
			if autoEmit then
				scheduleWindow(desc, delay, duration or fallbackDuration, lifetime + timeScaleDur)
			elseif emitCount and emitCount > 0 then
				local scaled = math.max(1, math.floor(emitCount * emitScale + 0.5))
				at(delay, function() desc:Emit(scaled) end)
				local endT = delay + lifetime + timeScaleDur
				if endT > maxEnd then maxEnd = endT end
			else
				scheduleWindow(desc, delay, duration or fallbackDuration, lifetime + timeScaleDur)
			end
		elseif desc:IsA("Beam") or desc:IsA("Trail") then
			local delay      = desc:GetAttribute("EmitDelay")
			local duration   = desc:GetAttribute("EmitDuration")
			local wasEnabled = desc.Enabled
			desc.Enabled = false
			if desc:IsA("Beam") then
				attachBeams[#attachBeams + 1] = desc
			end
			if delay ~= nil or duration ~= nil then
				scheduleWindow(desc, delay or 0, duration or fallbackDuration, 0)
			elseif wasEnabled then
				at(0, function() desc.Enabled = true end)
			end
		elseif VFX_LIGHT_CLASSES[desc.ClassName] then
			if not keepSoundLight then
				toDestroy[#toDestroy + 1] = desc
			end
		elseif desc:IsA("Sound") then
			if not keepSoundLight then
				toDestroy[#toDestroy + 1] = desc
			else
				local playDelay = desc:GetAttribute("PlayDelay") or 0
				local autoPlay  = desc:GetAttribute("AutoPlay")
				if autoPlay == true or autoPlay == nil then
					at(playDelay, function() desc:Play() end)
					local endT = playDelay + (desc.TimeLength or 0)
					if endT > maxEnd then maxEnd = endT end
				end
			end
		elseif folderPivot and desc:IsA("BasePart") then
			desc.Position = splashPosition + (desc.Position - folderPivot.Position)
		end
	end

	for _, inst in ipairs(toDestroy) do
		inst:Destroy()
	end

	return schedule, attachBeams, maxEnd
end

local function runTimeline(schedule, container, token)
	for key, bucket in pairs(schedule) do
		local t = key * VFX_TIME_GROUP_STEP
		if t <= 0.001 then
			for _, fn in ipairs(bucket) do
				pcall(fn)
			end
		else
			task.delay(t, function()
				if token.cancelled then return end
				if not container.Parent then return end
				for _, fn in ipairs(bucket) do
					pcall(fn)
				end
			end)
		end
	end
end

local function spawnSplashVFXAtPosition(rodName, splashPosition, targetSinker, ownerPlayer, lodName, distance)
	if not ownerPlayer then return nil end
	if not RODS_WITH_SPLASH_SET[rodName] then return nil end
	local vfxTemplate = VfxSplashFolder:FindFirstChild(rodName)
	if not vfxTemplate then return nil end

	local isLocalOwner = ownerPlayer == player
	lodName = lodName or (isLocalOwner and "LOCAL" or "NEAR")
	local isFar = lodName == "FAR"

	local meta = getTemplateMeta(rodName, vfxTemplate)
	local cost = isFar
		and math.min(PerfConfig.FarPrototypeEmitterCount or 6, meta.cost)
		or meta.cost
	if not tryReserveVFXBudget(ownerPlayer.UserId, isLocalOwner, distance or 0, cost) then return nil end

	debug.profilebegin("FishingSplashVFX")

	-- Clone dengan Parent=nil; seluruh konfigurasi selesai sebelum tampil.
	local container
	local folderPivot = nil
	if isFar then
		-- [PERF-8] FAR tidak meng-clone template full 149–201 emitter.
		container = getFarPrototype(rodName, vfxTemplate):Clone()
		container.Position = splashPosition
	else
		container = vfxTemplate:Clone()
		if container:IsA("Model") then
			if container.PrimaryPart then
				container:SetPrimaryPartCFrame(CFrame.new(splashPosition))
			else
				container:MoveTo(splashPosition)
			end
		elseif container:IsA("BasePart") then
			container.CFrame = CFrame.new(splashPosition)
		else
			local ok, pivot = pcall(container.GetPivot, container)
			folderPivot = ok and pivot or nil
		end
	end
	container.Name = "VFX_" .. rodName .. "_" .. ownerPlayer.Name
	container:SetAttribute("IsSplashVFX", true)

	local emitScale = getLODEmitScale(lodName)
	local token = { cancelled = false }
	local schedule, attachBeams, maxEnd =
		buildTimeline(container, rodName, lodName, emitScale, folderPivot, splashPosition)

	if targetSinker and targetSinker.Parent then
		for _, beam in ipairs(attachBeams) do
			if not beam.Attachment0 then
				local p = beam.Parent
				if p and (p:IsA("BasePart") or p:IsA("MeshPart")) then
					beam.Attachment0 = p:FindFirstChildOfClass("Attachment")
						or ensureAttachment(p, "BeamSource")
				end
			end
			if not beam.Attachment1 then
				beam.Attachment1 = targetSinker:FindFirstChild("BeamTarget")
					or targetSinker:FindFirstChildOfClass("Attachment")
					or ensureAttachment(targetSinker, "BeamTarget")
			end
		end
	end

	-- Cleanup = max(delay + duration + lifetime); root CleanupTime = override.
	local cleanupTime = container:GetAttribute("CleanupTime") or vfxTemplate:GetAttribute("CleanupTime")
	if cleanupTime and cleanupTime > 0 then
		cleanupTime = math.clamp(cleanupTime, 0.5, VFX_MAX_CLEANUP_TIME)
	else
		cleanupTime = math.clamp(maxEnd + 0.5, 0.5, VFX_MAX_CLEANUP_TIME)
	end

	container.Parent = workspace
	runTimeline(schedule, container, token)

	-- SFX root via SoundManager (hanya LOCAL/NEAR; MID/FAR tanpa SFX).
	if meta.sfx and (lodName == "LOCAL" or lodName == "NEAR") then
		SoundManager:Play(meta.sfx, 0.5)
	end

	activeEffects[ownerPlayer.UserId] = {
		inst = container,
		position = splashPosition,
		cost = cost,
		token = token,
	}
	totalActiveCost += cost

	vfxStats.spawnedTotal += 1
	if lodName == "LOCAL" then vfxStats.spawnedLocal += 1
	elseif lodName == "NEAR" then vfxStats.spawnedNear += 1
	elseif lodName == "MID" then vfxStats.spawnedMid += 1
	else vfxStats.spawnedFar += 1 end

	local ownerId = ownerPlayer.UserId
	task.delay(cleanupTime, function()
		local rec = activeEffects[ownerId]
		if rec and rec.inst == container then
			activeEffects[ownerId] = nil
			totalActiveCost = math.max(0, totalActiveCost - rec.cost)
			rec.token.cancelled = true
		end
	end)
	Debris:AddItem(container, cleanupTime)

	debug.profileend()
	return container
end

vfxSplashEvent.OnClientEvent:Connect(function(casterPlayer, rodName, splashPosition)
	if typeof(casterPlayer) ~= "Instance" or not casterPlayer:IsA("Player") then return end
	if typeof(rodName) ~= "string" or typeof(splashPosition) ~= "Vector3" then return end

	-- [PERF-3] Pilih LOD dari jarak; di luar FarRadius tier → skip.
	local lodName, distance = selectVFXLOD(casterPlayer, splashPosition)
	if not lodName then
		vfxStats.skippedRange += 1
		return
	end

	local targetSinker = nil
	if casterPlayer == player then
		targetSinker = gameState and gameState.sinker
	elseif otherPlayersHooks[casterPlayer.UserId] then
		targetSinker = otherPlayersHooks[casterPlayer.UserId].hook
	end
	task.spawn(spawnSplashVFXAtPosition, rodName, splashPosition, targetSinker, casterPlayer, lodName, distance)
end)

local function HasTagSafe(inst, tag)
	if typeof(inst) ~= "Instance" then return false end
	local ok, res = pcall(CS.HasTag, CS, inst, tag)
	return ok and res == true
end

-- ═══════════════════════════════════════════════════════════════
-- GAME STATE
-- ═══════════════════════════════════════════════════════════════
gameState = {
	casted            = false,
	sinker            = nil,
	splash            = nil,
	savedHookPosition = nil,
	waitTime          = math.random(3, 6),
	fishingCaught     = false,
	hasLanded         = false,
	fishingInProgress = false,
	canCast           = true,
	castingCooldown   = false,
	cooldownTime      = 0.3,
	activeFishingTask = nil,
	isAutoFishing     = false,
	waterConn         = nil,
	castStartTime     = 0,
}

local pendingCastGeneration = 0
local cooldownGeneration = 0
local fishingTaskCounter = 0

local speedState = {
	originalWalkSpeed = 16,
	fishingWalkSpeed  = 8,
	speedModified     = false,
}

local connections = {}
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

local sharedWaterRayParams = RaycastParams.new()
sharedWaterRayParams.FilterType  = Enum.RaycastFilterType.Exclude
sharedWaterRayParams.IgnoreWater = false

local sharedOtherHookRayParams = RaycastParams.new()
sharedOtherHookRayParams.FilterType  = Enum.RaycastFilterType.Exclude
sharedOtherHookRayParams.IgnoreWater = false

local _ignoreListSelf  = {}
local _ignoreListOther = {}

local function getRodPart(rod)
	if not rod then return nil end
	return rod:FindFirstChild("Handle") or rod:FindFirstChild("Part") or rod:FindFirstChild("Main")
end

local function safeDetachRodBeams(rod)
	if not rod then return end
	local rodPart = getRodPart(rod)
	if rodPart then CastingSystem:DetachBeamsFromRod(rodPart) end
end

local function stopLandingWatchers()
	if gameState.waterConn then
		gameState.waterConn:Disconnect()
		gameState.waterConn = nil
	end
end

local RodManager
local updateMobileButtonText, onRodEquipped, onRodUnequipped, performCast, schedulePerformCast

local function buildIgnoreList()
	table.clear(_ignoreListSelf)
	local n = 0
	if character then n += 1; _ignoreListSelf[n] = character end
	if RodManager and RodManager.currentRod then n += 1; _ignoreListSelf[n] = RodManager.currentRod end
	if gameState.sinker then n += 1; _ignoreListSelf[n] = gameState.sinker end
	return _ignoreListSelf
end

local function buildIgnoreForOther(casterChar, hook)
	table.clear(_ignoreListOther)
	local n = 0
	if character  then n += 1; _ignoreListOther[n] = character end
	if casterChar then n += 1; _ignoreListOther[n] = casterChar end
	if hook       then n += 1; _ignoreListOther[n] = hook end
	return _ignoreListOther
end

-- ═══════════════════════════════════════════════════════════════
-- ROD MANAGER
-- ═══════════════════════════════════════════════════════════════
RodManager = { currentRod = nil, isEquipped = false }
local charMonitorConns = {}

function RodManager:IsValidRod()
	local rod = self.currentRod
	return rod and rod.Parent and self.isEquipped
		and player.Character and rod:IsDescendantOf(player.Character)
		and getRodPart(rod)
end

function RodManager:CleanupFishing()
	if not (gameState.casted or gameState.fishingInProgress) then return end
	gameState.casted, gameState.fishingInProgress = false, false
	gameState.canCast, gameState.castingCooldown  = true, false
	gameState.activeFishingTask = nil
	stopLandingWatchers()
	destroySplash(gameState.splash); gameState.splash = nil
	if gameState.sinker then releaseHook(gameState.sinker); gameState.sinker = nil end
	if MinigameSystem and MinigameSystem:IsActive() then MinigameSystem:ForceStop() end
	if PowerBarSystem and PowerBarSystem:IsCharging() then PowerBarSystem:StopCharging() end
	safeDetachRodBeams(self.currentRod)
	cleanupCastEvent:FireServer()
	if GUIManager and GUIManager.SlideFishingFrameOut then GUIManager:SlideFishingFrameOut(nil) end
	updateMobileButtonText()
end

function RodManager:OnRodEquipped(rod)
	if not rod or not rod.Parent then return end
	if self.currentRod and self.currentRod ~= rod then self:OnRodUnequipped() end
	self.currentRod, self.isEquipped = rod, true
	onRodEquipped(rod)
end

function RodManager:OnRodUnequipped()
	if not self.currentRod then return end
	self:CleanupFishing()
	self.currentRod, self.isEquipped = nil, false
	onRodUnequipped()
end

function RodManager:CheckEquippedRod(char)
	if not char then return end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and HasTagSafe(tool, "Rod") then
			if self.currentRod ~= tool then self:OnRodEquipped(tool) end
			return
		end
	end
	if self.isEquipped then self:OnRodUnequipped() end
end

function RodManager:SetupCharacterMonitoring(char)
	if not char then return end
	for _, conn in ipairs(charMonitorConns) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	table.clear(charMonitorConns)
	self:CheckEquippedRod(char)
	table.insert(charMonitorConns, char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and HasTagSafe(child, "Rod") then self:OnRodEquipped(child) end
	end))
	table.insert(charMonitorConns, char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and HasTagSafe(child, "Rod") and self.currentRod == child then
			self:OnRodUnequipped()
		end
	end))
end

-- ═══════════════════════════════════════════════════════════════
-- MASTER HEARTBEAT LOOP
-- ═══════════════════════════════════════════════════════════════
local masterLoopActive          = false
local MASTER_ROD_CHECK_INTERVAL = 0.25
local masterRodCheckAccum       = 0

local function startMasterLoop(char)
	if masterLoopActive then return end
	masterLoopActive    = true
	masterRodCheckAccum = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not char or not char.Parent then
			conn:Disconnect()
			masterLoopActive = false
			return
		end
		local isFishing = gameState.casted or gameState.fishingInProgress
			or MinigameSystem:IsActive() or PowerBarSystem:IsCharging()
		local shouldSlowDown = isFishing and RodManager.isEquipped
		if shouldSlowDown and not speedState.speedModified then
			humanoid.WalkSpeed       = speedState.fishingWalkSpeed
			speedState.speedModified = true
		elseif not shouldSlowDown and speedState.speedModified then
			humanoid.WalkSpeed       = speedState.originalWalkSpeed
			speedState.speedModified = false
		end
		masterRodCheckAccum += dt
		if masterRodCheckAccum >= MASTER_ROD_CHECK_INTERVAL then
			masterRodCheckAccum = 0
			if RodManager.isEquipped and not RodManager:IsValidRod() then RodManager:OnRodUnequipped() end
			RodManager:CheckEquippedRod(char)
		end
		if gameState.isAutoFishing and RodManager.isEquipped
			and gameState.canCast and not gameState.casted
			and not gameState.fishingInProgress and not gameState.castingCooldown then
			gameState.canCast = false
			local power = math.random(90, 100)
			AnimationController:PlayCastSequence()
			SoundManager:Play("Cast", 0.5)
			schedulePerformCast(power, true)
		end
	end)
	connections.masterLoop = conn
end

local function stopMasterLoop()
	masterLoopActive = false
	if connections.masterLoop then connections.masterLoop:Disconnect(); connections.masterLoop = nil end
	if speedState.speedModified then
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = speedState.originalWalkSpeed
		end
		speedState.speedModified = false
	end
end

local function getCurrentRodName()
	return RodManager.currentRod and RodManager.currentRod.Name
end

local function startCastingCooldown()
	cooldownGeneration += 1
	local generation = cooldownGeneration

	gameState.castingCooldown, gameState.canCast = true, false
	updateMobileButtonText()

	task.delay(gameState.cooldownTime, function()
		if generation ~= cooldownGeneration then return end
		if gameState.casted or gameState.fishingInProgress then return end

		gameState.castingCooldown, gameState.canCast = false, true
		updateMobileButtonText()
	end)
end

function schedulePerformCast(power, requireAutoFishing)
	pendingCastGeneration += 1
	local generation = pendingCastGeneration

	gameState.canCast = false
	updateMobileButtonText()

	task.delay(0.4, function()
		if generation ~= pendingCastGeneration then return end

		if requireAutoFishing and not gameState.isAutoFishing then
			gameState.canCast = true
			updateMobileButtonText()
			return
		end

		if not RodManager:IsValidRod() or gameState.casted or gameState.fishingInProgress then
			gameState.canCast = true
			updateMobileButtonText()
			return
		end

		performCast(power)
	end)
end

function updateMobileButtonText()
	if not GUIManager then return end
	local text = "CAST"
	if MinigameSystem:IsActive()                              then text = "TAP!"
	elseif PowerBarSystem:IsCharging()                        then text = "CAST!"
	elseif gameState.casted or gameState.fishingInProgress    then text = "FISHING..."
	elseif gameState.castingCooldown                          then text = "WAIT..." end
	if gameState.isAutoFishing then
		text = (MinigameSystem:IsActive() or gameState.casted or gameState.fishingInProgress)
			and "AUTO..." or "AUTO"
	end
	GUIManager:UpdateMobileButtonText(text)
end

local autoButtonConn = nil

local function initializeSystems()
	SoundManager:Initialize()
	GUIManager:Initialize(player)
	-- [FIX-AUTO] Set teks tombol Auto sesuai state SEKARANG, tepat setelah
	-- referensi GUI valid — jangan menunggu klik pertama.
	GUIManager:UpdateAutoButton(gameState.isAutoFishing)
	if autoButtonConn then autoButtonConn:Disconnect(); autoButtonConn = nil end
	local autoButton = GUIManager:GetElement("autoButton")
	if autoButton then
		autoButtonConn = autoButton.MouseButton1Click:Connect(function()
			gameState.isAutoFishing = not gameState.isAutoFishing
			GUIManager:UpdateAutoButton(gameState.isAutoFishing)
			GUIManager:ShowNotification(
				"Auto-Fishing: " .. (gameState.isAutoFishing and "ON" or "OFF"),
				3, gameState.isAutoFishing and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100))
		end)
	end
	AnimationController:Initialize(humanoid)
	PowerBarSystem:Initialize({
		barFrame      = GUIManager:GetElement("barFrame"),
		fillFrame     = GUIManager:GetElement("fillFrame"),
		luckMultiText = GUIManager:GetElement("luckMultiText"),
	})
	MinigameSystem:Initialize({
		fishingFillFrame = GUIManager:GetElement("fishingFillFrame"),
		infoText         = GUIManager:GetElement("infoText"),
	}, nil)
	speedState.originalWalkSpeed = humanoid.WalkSpeed
end

initializeSystems()

-- ═══════════════════════════════════════════════════════════════
-- AUTO-DETECT FISH TEXTURE
-- ═══════════════════════════════════════════════════════════════
local fishTextureCache = {}
local CACHE_MISS = "__MISS__"

local function getFishImageId(fishName)
	local cached = fishTextureCache[fishName]
	if cached == CACHE_MISS then return nil end
	if cached then return cached end

	local fishTool = fishAssetFolder:FindFirstChild(fishName)
	if not fishTool then
		fishTextureCache[fishName] = CACHE_MISS
		return nil
	end

	local function check(id)
		return id and id ~= "" and id ~= "rbxassetid://0"
	end

	for _, desc in ipairs(fishTool:GetDescendants()) do
		if desc:IsA("SurfaceAppearance") and check(desc.ColorMap) then
			fishTextureCache[fishName] = desc.ColorMap; return desc.ColorMap
		end
		if desc:IsA("MeshPart") and check(desc.TextureID) then
			fishTextureCache[fishName] = desc.TextureID; return desc.TextureID
		end
		if desc:IsA("SpecialMesh") and check(desc.TextureId) then
			fishTextureCache[fishName] = desc.TextureId; return desc.TextureId
		end
		if desc:IsA("Decal") and check(desc.Texture) then
			fishTextureCache[fishName] = desc.Texture; return desc.Texture
		end
		if desc:IsA("Texture") and check(desc.Texture) then
			fishTextureCache[fishName] = desc.Texture; return desc.Texture
		end
		if desc:IsA("ImageLabel") and check(desc.Image) then
			fishTextureCache[fishName] = desc.Image; return desc.Image
		end
	end

	if fishTool:IsA("Tool") and check(fishTool.TextureId) then
		fishTextureCache[fishName] = fishTool.TextureId
		return fishTool.TextureId
	end

	fishTextureCache[fishName] = CACHE_MISS
	return nil
end

-- ═══════════════════════════════════════════════════════════════
-- SMALL NOTIFICATION POPUP (GUI "Small Notification")
-- ═══════════════════════════════════════════════════════════════
local TWEEN_DURATION = 0.8
local VISIBLE_DURATION = 2.5
local notificationGeneration = 0

local function showFishCatchNotification(fishData)
	notificationGeneration += 1
	local generation = notificationGeneration
	local fishName   = fishData.name
	local fishWeight = fishData.weight
	local fishRarity = fishData.rarity
	local playerGui       = player:FindFirstChild("PlayerGui")
	local notificationGui = playerGui and playerGui:FindFirstChild("Small Notification")
	if not notificationGui or not notificationGui:IsA("ScreenGui") then
		GUIManager:ShowNotification(
			string.format("Dapat %s %.1fkg (%s)", fishName, fishWeight, fishRarity),
			4, FishingConfig.GetRarityColor(fishRarity))
		return
	end
	local display = notificationGui:FindFirstChild("Display")
	if not display then
		GUIManager:ShowNotification(
			string.format("Dapat %s %.1fkg (%s)", fishName, fishWeight, fishRarity),
			4, FishingConfig.GetRarityColor(fishRarity))
		return
	end
	local container     = display:FindFirstChild("Container")
	local itemName      = container and container:FindFirstChild("ItemName")
	local rarityText    = container and container:FindFirstChild("Rarity")
	local vectorFrame   = display:FindFirstChild("VectorFrame")
	local raysEffect    = vectorFrame and vectorFrame:FindFirstChild("Rays")
	local vectorElement = vectorFrame and vectorFrame:FindFirstChild("Vector")
	local fishImageLabel = display:FindFirstChild("FishImage") or display:FindFirstChild("Icon")
	if not fishImageLabel then
		local KnownNames = { "Container", "NewFrame", "VectorFrame", "UIScale" }
		for _, child in ipairs(display:GetChildren()) do
			if child:IsA("ImageLabel") then
				local isKnown = false
				for _, n in ipairs(KnownNames) do if child.Name == n then isKnown = true; break end end
				if not isKnown and child.Name ~= "Rays" and child.Name ~= "Vector" then
					fishImageLabel = child; break
				end
			end
		end
	end
	if not fishImageLabel then
		local NewFrame = display:FindFirstChild("NewFrame")
		if NewFrame then fishImageLabel = NewFrame:FindFirstChildOfClass("ImageLabel") end
	end
	local rarityColor    = FishingConfig.GetRarityColor(fishRarity)
	local imageId        = getFishImageId(fishName)
	local targetPosition = UDim2.new(0.5, 0, 0.05, 0)
	local hiddenPosition = UDim2.new(0.5, 0, -0.5, 0)
	local tweenIn        = TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenOut       = TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if fishImageLabel and fishImageLabel:IsA("ImageLabel") then fishImageLabel.Image = imageId end
	if vectorElement  and vectorElement:IsA("ImageLabel")  then vectorElement.Image  = imageId end
	if itemName then
		itemName.Text       = fishName .. string.format(" (%.1fkg)", fishWeight)
		itemName.TextColor3 = rarityColor
	end
	if rarityText then
		rarityText.Text       = fishRarity
		rarityText.TextColor3 = rarityColor
	end
	if raysEffect and raysEffect:IsA("ImageLabel") then
		raysEffect.ImageColor3 = rarityColor
	end
	display.Position        = hiddenPosition
	notificationGui.Enabled = true
	task.spawn(function()
		local slideIn = TweenService:Create(display, tweenIn, { Position = targetPosition })
		slideIn:Play()
		slideIn.Completed:Wait()
		if generation ~= notificationGeneration then return end

		local shakeOffset = 3
		local shakeDuration = 0.05
		local originalXOffset = display.Position.X.Offset
		local shakeInfo = TweenInfo.new(
			shakeDuration,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out
		)

		for _ = 1, 2 do
			local rightTween = TweenService:Create(display, shakeInfo, {
				Position = UDim2.new(
					display.Position.X.Scale,
					originalXOffset + shakeOffset,
					display.Position.Y.Scale,
					display.Position.Y.Offset
				)
			})
			rightTween:Play()
			rightTween.Completed:Wait()
			if generation ~= notificationGeneration then return end

			local leftTween = TweenService:Create(display, shakeInfo, {
				Position = UDim2.new(
					display.Position.X.Scale,
					originalXOffset - shakeOffset,
					display.Position.Y.Scale,
					display.Position.Y.Offset
				)
			})
			leftTween:Play()
			leftTween.Completed:Wait()
			if generation ~= notificationGeneration then return end
		end

		local returnTween = TweenService:Create(display, shakeInfo, {
			Position = UDim2.new(
				display.Position.X.Scale,
				originalXOffset,
				display.Position.Y.Scale,
				display.Position.Y.Offset
			)
		})
		returnTween:Play()
		returnTween.Completed:Wait()
		if generation ~= notificationGeneration then return end

		task.wait(VISIBLE_DURATION)
		if generation ~= notificationGeneration then return end

		local slideOut = TweenService:Create(display, tweenOut, {
			Position = hiddenPosition,
		})
		slideOut:Play()
		slideOut.Completed:Wait()

		if generation == notificationGeneration then
			notificationGui.Enabled = false
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- MINIGAME CALLBACKS
-- ═══════════════════════════════════════════════════════════════
MinigameSystem:SetCallbacks(
	function() -- ON SUCCESS
		gameState.fishingCaught = true
		updateMobileButtonText()
		SoundManager:Play("Success", 0.6)
		fishGiverEvent:FireServer({
			hookPosition = gameState.savedHookPosition,
		})
		gameState.savedHookPosition = nil
		task.delay(0.3, function()
			if RodManager.isEquipped and RodManager.currentRod then
				AnimationController:PlayIdleSequence()
			end
			startCastingCooldown()
		end)
	end,
	function() -- ON FAIL
		gameState.savedHookPosition = nil
		if RodManager.isEquipped and RodManager.currentRod then AnimationController:PlayIdleSequence() end
		GUIManager:ShowNotification("Ikan kabur!", 2, Color3.fromRGB(255, 100, 100))
		MinigameSystem:Stop()
		startCastingCooldown()
	end
)

-- ═══════════════════════════════════════════════════════════════
-- FISH CAUGHT RESULT
-- ═══════════════════════════════════════════════════════════════
fishCaughtResult.OnClientEvent:Connect(function(result)
	if typeof(result) ~= "table" then return end
	if not (result.name and result.weight and result.rarity) then return end

	task.spawn(function()
		if NotificationManager then
			pcall(function()
				NotificationManager:ShowFishCatch({
					name   = result.name,
					weight = result.weight,
					rarity = result.rarity,
					icon   = getFishImageId(result.name),
				})
			end)
		else
			showFishCatchNotification({
				name   = result.name,
				weight = result.weight,
				rarity = result.rarity,
			})
		end
	end)

	if result.uniqueId then
		local tool = findFishToolById(result.uniqueId)
		if tool then
			local rarityVal = tool:FindFirstChild("Rarity")
			if rarityVal and rarityVal:IsA("StringValue") then rarityVal.Value = result.rarity end
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- FISHING SEQUENCE
-- ═══════════════════════════════════════════════════════════════
local function runFishingSequence(taskId, splash)
	local waitDuration = math.random(3, 6)

	local function ownsCurrentTask()
		return gameState.activeFishingTask == taskId
	end

	local function validate()
		return ownsCurrentTask()
			and RodManager.isEquipped
			and RodManager.currentRod
			and RodManager:IsValidRod()
			and gameState.casted
			and gameState.sinker
	end

	local function cleanupSplash()
		destroySplash(splash)
		if gameState.splash == splash then
			gameState.splash = nil
		end
	end

	local function abortOwnedTask()
		cleanupSplash()

		if not ownsCurrentTask() then
			return false
		end

		gameState.activeFishingTask = nil
		gameState.fishingInProgress = false
		gameState.casted = false
		gameState.canCast = true

		stopLandingWatchers()

		if gameState.sinker then
			releaseHook(gameState.sinker)
			gameState.sinker = nil
		end

		safeDetachRodBeams(RodManager.currentRod)
		cleanupCastEvent:FireServer()
		updateMobileButtonText()
		return false
	end

	if not validate() then
		return abortOwnedTask()
	end

	task.wait(waitDuration)
	if not validate() then
		return abortOwnedTask()
	end

	for _ = 1, 3 do
		if not validate() then
			return abortOwnedTask()
		end

		if splashTemplate and isVFXAllowed() then
			local bubble = splashTemplate:Clone()
			if bubble then
				bubble.Parent = workspace
				if bubble:FindFirstChild("Caster") then
					bubble.Caster.Value = player.Name
				end
				bubble.Position = gameState.sinker.Position
				Debris:AddItem(bubble, 1)
			end
		end

		task.wait(0.1)
	end

	if not validate() then
		return abortOwnedTask()
	end

	AnimationController:PlayPullingSequence()
	SoundManager:Play("Reeling", 0.4)
	GUIManager:SlideFishingFrameIn()

	if gameState.sinker and gameState.sinker.Parent then
		gameState.savedHookPosition = gameState.sinker.Position
	end

	MinigameSystem:Start(gameState.isAutoFishing, getCurrentRodName())

	while MinigameSystem:IsActive() do
		if not validate() then
			MinigameSystem:Stop()
			return abortOwnedTask()
		end
		task.wait(0.1)
	end

	if not ownsCurrentTask() then
		cleanupSplash()
		return false
	end

	gameState.fishingInProgress = false
	gameState.casted = false
	gameState.activeFishingTask = nil

	stopLandingWatchers()

	if gameState.sinker then
		releaseHook(gameState.sinker)
		gameState.sinker = nil
	end

	cleanupSplash()
	safeDetachRodBeams(RodManager.currentRod)
	cleanupCastEvent:FireServer()
	GUIManager:SlideFishingFrameOut(function()
		updateMobileButtonText()
	end)

	return true
end

-- ═══════════════════════════════════════════════════════════════
-- LANDING HANDLERS
-- ═══════════════════════════════════════════════════════════════
local function onLandedNotWater()
	if gameState.hasLanded or not gameState.casted or gameState.fishingInProgress then return end

	local sinkerAtLanding = gameState.sinker
	local castStartedAt = gameState.castStartTime

	gameState.hasLanded = true
	stopLandingWatchers()

	if sinkerAtLanding then
		sinkerAtLanding.AssemblyLinearVelocity = Vector3.zero
		sinkerAtLanding.Anchored = true
	end

	GUIManager:ShowNotification("Cast ke air dulu!", 3, Color3.fromRGB(255, 200, 100))
	task.wait(1.5)

	if gameState.castStartTime ~= castStartedAt then return end
	if gameState.sinker ~= sinkerAtLanding then return end
	if not gameState.casted or gameState.fishingInProgress then return end
	if not RodManager.isEquipped or not RodManager.currentRod then return end

	gameState.casted = false

	if gameState.sinker then
		releaseHook(gameState.sinker)
		gameState.sinker = nil
	end

	safeDetachRodBeams(RodManager.currentRod)
	cleanupCastEvent:FireServer()
	startCastingCooldown()

	task.delay(0.4, function()
		if gameState.castStartTime ~= castStartedAt then return end
		if RodManager.isEquipped and RodManager.currentRod then
			AnimationController:PlayIdleSequence()
		end
	end)
end

local function onLandedInWater()
	if gameState.hasLanded or not gameState.casted or gameState.fishingInProgress or not gameState.sinker then return end
	gameState.hasLanded = true
	stopLandingWatchers()
	gameState.sinker.AssemblyLinearVelocity = Vector3.zero
	gameState.sinker.Anchored               = true
	SoundManager:Play("HookHit", 0.4)
	local pos    = gameState.sinker.Position
	local waterY = CastingSystem:GetWaterSurfaceY(pos.X, pos.Z, buildIgnoreList())
	if not waterY then
		for i = 1, 10 do
			local test = pos - Vector3.new(0, i * 0.18, 0)
			local wy   = CastingSystem:GetWaterSurfaceY(test.X, test.Z, buildIgnoreList())
			if wy then waterY = wy; break end
		end
	end
	gameState.sinker.Position = waterY
		and Vector3.new(pos.X, waterY, pos.Z)
		or  Vector3.new(pos.X, pos.Y - 0.15, pos.Z)
	local currentRod = getCurrentRodName()
	if currentRod and RODS_WITH_SPLASH_SET[currentRod] and isVFXAllowed() then
		task.wait()
		if gameState.sinker and gameState.sinker.Parent then
			pcall(function() vfxSplashEvent:FireServer(currentRod, gameState.sinker.Position) end)
		end
	end
	fishingTaskCounter += 1
	gameState.activeFishingTask = fishingTaskCounter
	gameState.fishingInProgress, gameState.canCast = true, false
	updateMobileButtonText()
	local splash = nil
	if splashTemplate and isVFXAllowed() then
		splash = splashTemplate:Clone()
	end
	if splash then
		splash.Parent = workspace
		if splash:FindFirstChild("Caster") then splash.Caster.Value = player.Name end
		splash.Position  = gameState.sinker.Position
		gameState.splash = splash
	end
	task.spawn(runFishingSequence, gameState.activeFishingTask, splash)
end

-- ═══════════════════════════════════════════════════════════════
-- WATER DETECTION + CAST
-- ═══════════════════════════════════════════════════════════════
local WATER_CHECK_INTERVAL = 0.10

function performCast(power)
	if not RodManager:IsValidRod() or gameState.casted or not character then
		gameState.canCast = true
		updateMobileButtonText()
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		gameState.canCast = true
		updateMobileButtonText()
		return
	end
	gameState.hasLanded, gameState.fishingInProgress = false, false
	gameState.canCast       = false
	gameState.castStartTime = tick()
	updateMobileButtonText()
	local rodPart = getRodPart(RodManager.currentRod)
	if not rodPart then
		gameState.canCast = true
		updateMobileButtonText()
		return
	end
	safeDetachRodBeams(RodManager.currentRod)
	local rodPos   = rodPart.Position + rodPart.CFrame.LookVector * 1.5
	local velocity = CastingSystem:CalculateVelocity(rodPos, hrp.CFrame.LookVector, power, 30)
	castReplicationEvent:FireServer(rodPos, velocity, getCurrentRodName(), power)
	gameState.sinker = CastingSystem:CreateHook(rodPos)
	if not gameState.sinker then
		gameState.canCast = true
		updateMobileButtonText()
		return
	end
	gameState.sinker.Anchored                = false
	gameState.sinker.AssemblyLinearVelocity  = velocity
	gameState.sinker.AssemblyAngularVelocity = Vector3.zero
	local hookAtt = ensureAttachment(gameState.sinker, "BeamTarget")
	CastingSystem:CreateBeam(rodPart, nil, hookAtt, getCurrentRodName())
	gameState.casted = true
	stopLandingWatchers()
	local waterCheckAccum = 0
	gameState.waterConn = RunService.Heartbeat:Connect(function(dt)
		if not gameState.sinker or not gameState.sinker.Parent then return end
		if gameState.hasLanded or not gameState.casted or gameState.fishingInProgress then return end
		if not RodManager:IsValidRod() then return end
		local elapsed = tick() - (gameState.castStartTime or 0)
		if elapsed < 0.45 then return end
		local vel = gameState.sinker.AssemblyLinearVelocity
		if not vel or vel.Y > -2.0 then return end
		waterCheckAccum += dt
		if waterCheckAccum < WATER_CHECK_INTERVAL then return end
		waterCheckAccum = 0
		local hookPos = gameState.sinker.Position
		local ignore  = buildIgnoreList()
		local waterY  = CastingSystem:GetWaterSurfaceY(hookPos.X, hookPos.Z, ignore)
		if waterY then
			if hookPos.Y <= (waterY + 0.03) then onLandedInWater(); return end
		else
			if CastingSystem:IsPositionInWater(hookPos, ignore, 2.2) then onLandedInWater(); return end
		end
		sharedWaterRayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(hookPos + Vector3.new(0, 0.6, 0), Vector3.new(0, -14, 0), sharedWaterRayParams)
		if hit and hit.Instance then
			local inst = hit.Instance
			local isWaterHit =
				(inst:IsA("Terrain") and hit.Material == Enum.Material.Water)
				or (inst:IsA("BasePart") and (inst.Material == Enum.Material.Water or HasTagSafe(inst, "Water")))
			if isWaterHit then onLandedInWater(); return end
			if (hookPos.Y - hit.Position.Y) <= 0.25 then onLandedNotWater(); return end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- ROD EQUIPPED / UNEQUIPPED
-- ═══════════════════════════════════════════════════════════════
function onRodEquipped(rod)
	AnimationController:SetRod(rod.Name)
	AnimationController:Reload(humanoid)
	AnimationController:PlayIdleSequence()
	GUIManager:ShowAutoButton(true)
	-- [FIX-AUTO] Teks benar saat tombol pertama kali tampil.
	GUIManager:UpdateAutoButton(gameState.isAutoFishing)
	if isMobile then
		GUIManager:ShowMobileButton(true)
		updateMobileButtonText()
		if connections.mobileButton then connections.mobileButton:Disconnect() end
		local btn = GUIManager:GetElement("tapMobileButton")
		if btn then
			connections.mobileButton = btn.MouseButton1Click:Connect(function()
				if not RodManager.isEquipped or gameState.isAutoFishing then return end
				if MinigameSystem:IsActive() then
					task.spawn(function() MinigameSystem:HandleClick(SoundManager, GUIManager) end)
				elseif PowerBarSystem:IsCharging() then
					local power = PowerBarSystem:StopCharging()
					if power > 10 and not gameState.castingCooldown then
						AnimationController:PlayCastSequence()
						SoundManager:Play("Cast", 0.5)
						schedulePerformCast(power, false)
					else
						if not gameState.castingCooldown then
							GUIManager:ShowNotification("Tenaga kurang!", 2, Color3.fromRGB(255, 200, 100))
						end
						gameState.canCast = true
						AnimationController:PlayIdleSequence()
					end
					updateMobileButtonText()
				elseif gameState.canCast and not gameState.casted
					and not gameState.fishingInProgress and not gameState.castingCooldown then
					PowerBarSystem:StartCharging(getCurrentRodName())
					updateMobileButtonText()
				end
			end)
		end
	else
		if connections.inputBegan then connections.inputBegan:Disconnect() end
		connections.inputBegan = UIS.InputBegan:Connect(function(input, processed)
			if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if gameState.isAutoFishing then return end
			if gameState.canCast and not gameState.casted
				and not gameState.fishingInProgress and not gameState.castingCooldown then
				PowerBarSystem:StartCharging(getCurrentRodName())
				updateMobileButtonText()
			end
		end)
		if connections.inputEnded then connections.inputEnded:Disconnect() end
		connections.inputEnded = UIS.InputEnded:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch)
				and MinigameSystem:IsActive() then
				task.spawn(function() MinigameSystem:HandleClick(SoundManager, GUIManager) end)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				and PowerBarSystem:IsCharging() then
				if gameState.isAutoFishing then return end
				local power = PowerBarSystem:StopCharging()
				if power > 10 and not gameState.castingCooldown then
					AnimationController:PlayCastSequence()
					SoundManager:Play("Cast", 0.5)
					schedulePerformCast(power, false)
				else
					if not gameState.castingCooldown then
						GUIManager:ShowNotification("Tenaga kurang!", 2, Color3.fromRGB(255, 200, 100))
					end
					gameState.canCast = true
					AnimationController:PlayIdleSequence()
				end
				updateMobileButtonText()
			end
		end)
	end
end

function onRodUnequipped()
	pendingCastGeneration += 1
	cooldownGeneration += 1

	AnimationController:ClearRod()
	AnimationController:Stop()
	if PowerBarSystem and PowerBarSystem:IsCharging() then PowerBarSystem:StopCharging() end
	if MinigameSystem and MinigameSystem:IsActive() then
		MinigameSystem:Stop()
		GUIManager:SlideFishingFrameOut(nil)
	end
	if gameState.isAutoFishing then
		gameState.isAutoFishing = false
		GUIManager:UpdateAutoButton(false)
	end
	GUIManager:ShowAutoButton(false)
	PowerBarSystem:Reset()
	GUIManager:ShowMobileButton(false)
	for k, conn in pairs(connections) do
		if k ~= "masterLoop" and conn then conn:Disconnect(); connections[k] = nil end
	end
	stopLandingWatchers()
	if gameState.sinker then releaseHook(gameState.sinker); gameState.sinker = nil end
	safeDetachRodBeams(RodManager.currentRod)
	if gameState.casted or gameState.fishingInProgress then cleanupCastEvent:FireServer() end
	gameState.casted, gameState.fishingInProgress      = false, false
	gameState.canCast, gameState.hasLanded             = true, false
	gameState.fishingCaught, gameState.castingCooldown = false, false
end

-- ═══════════════════════════════════════════════════════════════
-- OTHER PLAYER HOOK SIMULATION
-- [PERF-6] Batas hook + interval simulasi dari tier perangkat.
-- ═══════════════════════════════════════════════════════════════
local MAX_OTHER_HOOKS           = PERF.MaxOtherHooks
local CAST_DISTANCE_LIMIT       = 60
local DISTANCE_TOLERANCE        = 15
local OTHER_PHYSICS_INTERVAL    = PERF.OtherHookPhysicsInterval
local OTHER_LAND_CHECK_INTERVAL = PERF.OtherHookLandCheckInterval
local DISTANCE_RECHECK_INTERVAL = 1.5
local activeOtherHookCount      = 0

local function getDistanceToCaster(caster)
	local myHrp     = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local casterHrp = caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
	if not myHrp or not casterHrp then return math.huge end
	return (myHrp.Position - casterHrp.Position).Magnitude
end

local function cleanupOtherCast(caster)
	if not caster then return end
	local userId = typeof(caster) == "Instance" and caster.UserId or caster
	local data = otherPlayersHooks[userId]
	if not data then return end
	if data.simConn then data.simConn:Disconnect(); data.simConn = nil end
	if data.hook then releaseHook(data.hook) end
	if data.rodPart and data.rodPart.Parent then
		pcall(function() CastingSystem:DetachBeamsFromRod(data.rodPart) end)
	end
	if data.countedActive then activeOtherHookCount = math.max(0, activeOtherHookCount - 1) end
	otherPlayersHooks[userId] = nil
	cleanupPlayerVFX(userId)
end

local function findCasterRodTool(caster, rodName)
	if not caster or not caster.Character then return nil end
	local char = caster.Character
	if rodName and rodName ~= "" then
		local t = char:FindFirstChild(rodName)
		if t and t:IsA("Tool") then return t end
	end
	for _, inst in ipairs(char:GetChildren()) do
		if inst:IsA("Tool") and HasTagSafe(inst, "Rod") then return inst end
	end
	return nil
end

castReplicationEvent.OnClientEvent:Connect(function(caster, rodPos, vel, rodName, power, t0)
	if caster == player then return end
	if typeof(caster) ~= "Instance" or not caster:IsA("Player") then return end
	if typeof(rodPos) ~= "Vector3" or typeof(vel) ~= "Vector3" then return end
	if typeof(t0) ~= "number" then t0 = workspace:GetServerTimeNow() end
	if getDistanceToCaster(caster) > CAST_DISTANCE_LIMIT then return end
	if activeOtherHookCount >= MAX_OTHER_HOOKS then return end
	local rodTool = findCasterRodTool(caster, rodName)
	if not rodTool then return end
	local rodPart = getRodPart(rodTool)
	if not rodPart then return end
	cleanupOtherCast(caster)
	local hook = CastingSystem:CreateHook(rodPos)
	if not hook then return end
	hook.CanCollide              = false
	hook.Anchored                = true
	hook.AssemblyLinearVelocity  = Vector3.zero
	hook.AssemblyAngularVelocity = Vector3.zero
	local hookAtt = ensureAttachment(hook, "BeamTarget")
	pcall(function() CastingSystem:CreateBeam(rodPart, nil, hookAtt, rodTool.Name) end)
	activeOtherHookCount += 1
	local casterId = caster.UserId
	otherPlayersHooks[casterId] = {
		hook = hook, rodPart = rodPart, simConn = nil, landed = false, countedActive = true,
	}
	local g          = Vector3.new(0, -workspace.Gravity, 0)
	local landedPos  = nil
	local casterChar = caster.Character
	local function detectLanding(pos)
		local ignore = buildIgnoreForOther(casterChar, hook)
		local waterY = CastingSystem:GetWaterSurfaceY(pos.X, pos.Z, ignore)
		if waterY then
			if pos.Y <= (waterY + 0.03) then return true, Vector3.new(pos.X, waterY, pos.Z) end
		else
			if CastingSystem:IsPositionInWater(pos, ignore, 2.2) then
				return true, Vector3.new(pos.X, pos.Y - 0.15, pos.Z)
			end
		end
		sharedOtherHookRayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(pos + Vector3.new(0, 0.6, 0), Vector3.new(0, -14, 0), sharedOtherHookRayParams)
		if hit and hit.Instance then
			local inst = hit.Instance
			local isWaterHit = (inst:IsA("Terrain") and hit.Material == Enum.Material.Water)
				or (inst:IsA("BasePart") and (inst.Material == Enum.Material.Water or HasTagSafe(inst, "Water")))
			if isWaterHit then return true, Vector3.new(pos.X, waterY or hit.Position.Y, pos.Z) end
			if (pos.Y - hit.Position.Y) <= 0.25 then return true, pos end
		end
		return false, nil
	end
	local physicsAccum, landCheckAccum, distRecheckAccum = 0, 0, 0
	local simConn
	simConn = RunService.Heartbeat:Connect(function(dt)
		local d = otherPlayersHooks[casterId]
		if not d or d.hook ~= hook then simConn:Disconnect(); return end
		if not (caster and caster.Parent) then cleanupOtherCast(caster); return end
		if not hook or not hook.Parent then cleanupOtherCast(caster); return end
		if d.landed then if landedPos then hook.Position = landedPos end; return end
		distRecheckAccum += dt
		if distRecheckAccum >= DISTANCE_RECHECK_INTERVAL then
			distRecheckAccum = 0
			if getDistanceToCaster(caster) > CAST_DISTANCE_LIMIT + DISTANCE_TOLERANCE then
				cleanupOtherCast(caster); return
			end
		end
		physicsAccum += dt
		if physicsAccum < OTHER_PHYSICS_INTERVAL then return end
		physicsAccum = 0
		local elapsed = math.max(0, workspace:GetServerTimeNow() - t0)
		local simPos  = rodPos + (vel * elapsed) + (0.5 * g * (elapsed * elapsed))
		hook.Position = simPos
		local velNow = vel + (g * elapsed)
		if elapsed < 0.45 or velNow.Y > -2.0 then return end
		landCheckAccum += dt
		if landCheckAccum < OTHER_LAND_CHECK_INTERVAL then return end
		landCheckAccum = 0
		local okLanded, newPos = detectLanding(simPos)
		if okLanded then
			d.landed  = true
			landedPos = newPos or simPos
			hook.Position = landedPos
		end
	end)
	otherPlayersHooks[casterId].simConn = simConn

	-- Safety cleanup 15 detik
	local hookRef = hook
	task.delay(15, function()
		local d = otherPlayersHooks[casterId]
		if d and d.hook == hookRef then cleanupOtherCast(caster) end
	end)
end)

cleanupCastEvent.OnClientEvent:Connect(function(caster)
	if caster == player then return end
	if typeof(caster) == "Instance" and caster:IsA("Player") then cleanupOtherCast(caster) end
end)

Players.PlayerRemoving:Connect(function(p)
	cleanupOtherCast(p)
	playerVFXLastSpawn[p.UserId] = nil
	cleanupPlayerVFX(p.UserId)
end)

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER EVENTS
-- ═══════════════════════════════════════════════════════════════
local function resetGameState()
	pendingCastGeneration += 1
	cooldownGeneration += 1
	fishingTaskCounter += 1

	gameState.activeFishingTask = nil
	if MinigameSystem:IsActive() then MinigameSystem:ForceStop() end
	stopLandingWatchers()
	if gameState.sinker then releaseHook(gameState.sinker); gameState.sinker = nil end
	destroySplash(gameState.splash); gameState.splash = nil
	cleanupCastEvent:FireServer()
	gameState.casted, gameState.fishingInProgress      = false, false
	gameState.canCast, gameState.hasLanded             = true, false
	gameState.fishingCaught, gameState.castingCooldown = false, false
	gameState.isAutoFishing = false
end

player.CharacterAdded:Connect(function(char)
	resetGameState()
	character, humanoid = char, char:WaitForChild("Humanoid")
	speedState.originalWalkSpeed = humanoid.WalkSpeed
	speedState.speedModified     = false
	initializeSystems()
	GUIManager:UpdateAutoButton(false)
	stopMasterLoop()
	task.wait(1.5)
	startMasterLoop(char)
	RodManager:SetupCharacterMonitoring(char)
end)

player.CharacterRemoving:Connect(function()
	resetGameState()
	stopMasterLoop()
	for _, conn in ipairs(charMonitorConns) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	table.clear(charMonitorConns)
	for k, conn in pairs(connections) do
		if conn then conn:Disconnect(); connections[k] = nil end
	end
end)

if showNotificationEvent then
	showNotificationEvent.OnClientEvent:Connect(function(message, duration, textColor)
		GUIManager:ShowNotification(message, duration or 3, textColor or Color3.fromRGB(255, 255, 255))
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- START
-- ═══════════════════════════════════════════════════════════════
task.wait(2)
startMasterLoop(character)
RodManager:SetupCharacterMonitoring(character)
