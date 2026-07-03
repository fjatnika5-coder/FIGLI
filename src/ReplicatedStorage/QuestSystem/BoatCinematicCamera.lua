-- ReplicatedStorage > QuestSystem > BoatCinematicCamera
-- CLIENT-ONLY module. Multi-shot cinematic rig untuk boat ride.
--
-- DESIGN:
--   * Progress-driven, bukan timer. Client rebuild spline yang sama dengan
--     server (SplinePath + Workspace.Path + samplesPerSeg dari QuestConfig),
--     lalu proyeksikan pivot boat ke arc length tiap frame → u = 0..1.
--     Shot nempel ke LOKASI di path, bukan ke detik. Speed berubah? Shot
--     tetap di tempat yang sama.
--   * 11 shot: intro pullback, side follow (2 sisi), low front, back high,
--     orbit, front three-quarter, close (romantic utk duo), wide high,
--     low water, ending pullback. Semua tunable di tabel SHOTS.
--   * Anti-jitter: kamera TIDAK nempel raw ke pivot boat. Posisi & look
--     target di-filter exponential smoothing (frame-rate independent,
--     time constant >> network tick 20Hz) → step replikasi terserap penuh.
--     Ini juga yang bikin transisi antar shot jadi dolly move halus, bukan
--     snap — target lompat, rig meluncur.
--   * u monotonic (gak pernah mundur) → urutan shot stabil walau proyeksi
--     noisy di belokan.
--   * Cleanup: Stop() idempotent; auto-stop kalau boat kehilangan Parent;
--     restore CameraType/Subject/FOV dengan fallback humanoid baru kalau
--     subject lama sudah destroyed (respawn).
--
-- Sumbu local boat: LookVector = -Z. Offset Z negatif = DEPAN boat,
-- Z positif = BELAKANG, X positif = kanan.

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")

local QuestSystem = script.Parent
local SplinePath  = require(QuestSystem:WaitForChild("SplinePath"))
local PathModule  = require(QuestSystem:WaitForChild("PathModule"))
local QuestConfig = require(QuestSystem:WaitForChild("QuestConfig"))

local player = Players.LocalPlayer

local BoatCinematicCamera = {}

local BIND_NAME = "QuestBoatCinematicCamera"

-- Smoothing rates (per second). Kecil = floaty/cinematic, besar = responsif.
-- POS lebih lambat dari LOOK: framing "nyusul" subjek, feel film.
local POS_SMOOTH  = 1.8
local LOOK_SMOOTH = 3.2
local FOV_SMOOTH  = 1.4

-- Handheld sway tipis biar shot gak terasa mati. Jangan digedein — pusing.
local SWAY_AMP  = 0.3   -- studs
local SWAY_FREQ = 0.4   -- Hz

-- Duo: semua shot dilebarkan supaya dua karakter masuk frame
-- (kecuali close shot yang memang sengaja rapat).
local DUO_OFFSET_SCALE = 1.25

-- u0 = progress mulai shot (0..1 sepanjang path). u1 auto = u0 shot berikut.
-- offsetB/fovB (opsional) = dolly/zoom: lerp dari offset/fov sepanjang shot.
-- orbitSpeed (opsional) = rad/s, offset diputar di bidang XZ local boat.
local function buildShots(mode)
	local duo = mode == "duo"
	local s = duo and DUO_OFFSET_SCALE or 1

	local shots = {
		-- 1. Intro: depan, pullback pelan (establishing)
		{ u0 = 0.00, offset = Vector3.new(0, 5, -14) * s, offsetB = Vector3.new(0, 6.5, -20) * s,
			lookOffset = Vector3.new(0, 2.6, 4), fov = 60 },
		-- 2. Side follow kanan
		{ u0 = 0.06, offset = Vector3.new(13, 3.5, 1) * s,
			lookOffset = Vector3.new(0, 2.4, -4), fov = 55 },
		-- 3. Low front, water level
		{ u0 = 0.15, offset = Vector3.new(3, 1.6, -12) * s,
			lookOffset = Vector3.new(0, 2.6, 2), fov = 50 },
		-- 4. Back follow tinggi
		{ u0 = 0.24, offset = Vector3.new(0, 7, 15) * s,
			lookOffset = Vector3.new(0, 2.4, -8), fov = 58 },
		-- 5. Orbit pelan
		{ u0 = 0.33, offset = Vector3.new(12, 5, 4) * s, orbitSpeed = 0.12,
			lookOffset = Vector3.new(0, 2.6, 0), fov = 55 },
		-- 6. Side follow kiri, dekat
		{ u0 = 0.42, offset = Vector3.new(-10, 3, 0) * s,
			lookOffset = Vector3.new(0, 2.3, -2), fov = 48 },
		-- 7. Front three-quarter
		{ u0 = 0.51, offset = Vector3.new(-8, 4.5, -12) * s,
			lookOffset = Vector3.new(0, 2.6, 3), fov = 55 },
		-- 8. Close: duo = romantic front close; solo = over-shoulder
		duo and
		{ u0 = 0.60, offset = Vector3.new(0, 3, -7.5),
			lookOffset = Vector3.new(0, 2.8, 2), fov = 40 }
		or
		{ u0 = 0.60, offset = Vector3.new(2.5, 3.2, 6.5),
			lookOffset = Vector3.new(0, 2.6, -4), fov = 42 },
		-- 9. Wide high establishing
		{ u0 = 0.70, offset = Vector3.new(16, 12, 10) * s,
			lookOffset = Vector3.new(0, 2, 0), fov = 62 },
		-- 10. Low side kanan, water level
		{ u0 = 0.80, offset = Vector3.new(11, 1.4, -3) * s,
			lookOffset = Vector3.new(0, 2, 0), fov = 50 },
		-- 11. Ending pullback wide (hold sampai detach)
		{ u0 = 0.90, offset = Vector3.new(0, 6, 14) * s, offsetB = Vector3.new(0, 11, 26) * s,
			lookOffset = Vector3.new(0, 2.5, 0), fov = 58, fovB = 66 },
	}

	for i, shot in ipairs(shots) do
		shot.u1 = shots[i + 1] and shots[i + 1].u0 or 1
	end
	return shots
end

local state = nil  -- { boat, shots, path, u, projIdx, saved }

local function restoreCamera(saved)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	cam.CameraType = saved.camType
	cam.FieldOfView = saved.fov
	-- Subject lama bisa sudah destroyed (respawn) — fallback humanoid sekarang.
	if saved.subject and saved.subject.Parent then
		cam.CameraSubject = saved.subject
	else
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then cam.CameraSubject = hum end
	end
end

function BoatCinematicCamera.Stop()
	if not state then return end
	local saved = state.saved
	state = nil
	RunService:UnbindFromRenderStep(BIND_NAME)
	restoreCamera(saved)
end

function BoatCinematicCamera.Start(boat, mode)
	BoatCinematicCamera.Stop()  -- idempotent; bind lama pasti lepas dulu

	if typeof(boat) ~= "Instance" or not boat.Parent then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end

	-- Rebuild spline yang sama dengan server. Kalau Path hilang/invalid,
	-- fallback: u dikunci 0.24 → satu back-follow shot statis, tetap jalan.
	local path
	local pathFolder = Workspace:FindFirstChild("Path")
	if pathFolder then
		local wps = PathModule.GetWaypoints(pathFolder)
		if #wps >= 2 then
			local pts = table.create(#wps)
			for i, wp in ipairs(wps) do pts[i] = wp.Position end
			path = SplinePath.Build(pts, QuestConfig.Boat.samplesPerSeg)
		end
	end

	state = {
		boat = boat,
		shots = buildShots(mode),
		path = path,
		u = 0,
		projIdx = 1,
		saved = {
			camType = cam.CameraType,
			subject = cam.CameraSubject,
			fov     = cam.FieldOfView,
		},
	}

	cam.CameraType = Enum.CameraType.Scriptable

	-- Mulai dari pose kamera sekarang: glide masuk shot pertama, bukan snap.
	local camPos  = cam.CFrame.Position
	local lookPos = camPos + cam.CFrame.LookVector * 10
	local clock   = 0

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local st = state
		if not st then return end

		local b = st.boat
		if not b.Parent then
			BoatCinematicCamera.Stop()
			return
		end

		local pivot = b:GetPivot()
		clock += dt

		-- Progress via proyeksi arc-length; monotonic.
		if st.path then
			local arc, idx = SplinePath.ProjectNear(st.path, pivot.Position, st.projIdx)
			st.projIdx = idx
			local u = arc / st.path.totalLen
			if u > st.u then st.u = u end
		else
			st.u = 0.24
		end

		-- Pilih shot aktif
		local shot
		for _, sh in ipairs(st.shots) do
			if st.u >= sh.u0 then shot = sh else break end
		end
		shot = shot or st.shots[1]

		-- k = progress internal shot (0..1) untuk dolly/zoom
		local span = shot.u1 - shot.u0
		local k = span > 0 and math.clamp((st.u - shot.u0) / span, 0, 1) or 0

		local offset = shot.offset
		if shot.offsetB then offset = offset:Lerp(shot.offsetB, k) end
		if shot.orbitSpeed then
			local ang = clock * shot.orbitSpeed
			local c, sn = math.cos(ang), math.sin(ang)
			offset = Vector3.new(offset.X * c - offset.Z * sn, offset.Y, offset.X * sn + offset.Z * c)
		end
		local fovT = shot.fov
		if shot.fovB then fovT += (shot.fovB - shot.fov) * k end

		local sway = Vector3.new(
			math.sin(clock * SWAY_FREQ * 2 * math.pi) * SWAY_AMP,
			math.sin(clock * SWAY_FREQ * 1.7 * 2 * math.pi) * SWAY_AMP * 0.5,
			0
		)

		local targetPos  = pivot:PointToWorldSpace(offset + sway)
		local targetLook = pivot:PointToWorldSpace(shot.lookOffset)

		-- Frame-rate independent exponential smoothing: alpha = 1 - e^(-k*dt).
		-- Time constant jauh di atas interval network tick → replication step
		-- terserap, transisi antar shot jadi dolly halus.
		local aPos  = 1 - math.exp(-POS_SMOOTH * dt)
		local aLook = 1 - math.exp(-LOOK_SMOOTH * dt)
		local aFov  = 1 - math.exp(-FOV_SMOOTH * dt)

		camPos  = camPos:Lerp(targetPos, aPos)
		lookPos = lookPos:Lerp(targetLook, aLook)

		local c = Workspace.CurrentCamera
		if not c then return end
		if (lookPos - camPos).Magnitude > 0.01 then
			c.CFrame = CFrame.lookAt(camPos, lookPos)
		end
		c.FieldOfView += (fovT - c.FieldOfView) * aFov
	end)
end

return BoatCinematicCamera
