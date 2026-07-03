-- ReplicatedStorage > QuestSystem > SplinePath
-- Catmull-Rom arc-length spline, standalone.
--
-- Dipakai client (BoatCinematicCamera) untuk rebuild path yang sama dengan
-- boat server, TANPA menyentuh BoatModule. Math identik dengan buildPath di
-- BoatModule — sengaja diduplikasi supaya movement system yang sudah stabil
-- tidak perlu diubah sama sekali. Kalau nanti mau, BoatModule bisa direfactor
-- untuk require module ini (mechanical swap).

local SplinePath = {}

local function crPos(p0, p1, p2, p3, t)
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * (
		(2 * p1) +
			(-p0 + p2) * t +
			(2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
			(-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)
end

local function crTan(p0, p1, p2, p3, t)
	local t2 = t * t
	return 0.5 * (
		(-p0 + p2) +
			(2 * p0 - 5 * p1 + 4 * p2 - p3) * (2 * t) +
			(-p0 + 3 * p1 - 3 * p2 + p3) * (3 * t2)
	)
end

-- points: array of Vector3 (>= 2). Returns { samples, totalLen } atau nil.
function SplinePath.Build(points, samplesPerSeg)
	local n = #points
	if n < 2 then return nil end
	samplesPerSeg = math.max(samplesPerSeg or 32, 4)

	local cp = {}
	cp[0] = points[1] * 2 - points[2]
	for i = 1, n do cp[i] = points[i] end
	cp[n + 1] = points[n] * 2 - points[n - 1]

	local samples = {}
	local cumLen = 0

	do
		local p0, p1, p2, p3 = cp[0], cp[1], cp[2], cp[3]
		local pos = crPos(p0, p1, p2, p3, 0)
		local tan = crTan(p0, p1, p2, p3, 0)
		if tan.Magnitude < 1e-6 then tan = (p2 - p1) end
		samples[1] = { pos = pos, tan = tan.Unit, len = 0 }
	end

	for segIdx = 1, n - 1 do
		local p0, p1, p2, p3 = cp[segIdx - 1], cp[segIdx], cp[segIdx + 1], cp[segIdx + 2]
		local prev = samples[#samples]
		for s = 1, samplesPerSeg do
			local t = s / samplesPerSeg
			local pos = crPos(p0, p1, p2, p3, t)
			local tan = crTan(p0, p1, p2, p3, t)
			if tan.Magnitude < 1e-6 then tan = (p2 - p1) end
			cumLen = cumLen + (pos - prev.pos).Magnitude
			local sample = { pos = pos, tan = tan.Unit, len = cumLen }
			samples[#samples + 1] = sample
			prev = sample
		end
	end

	return { samples = samples, totalLen = cumLen }
end

-- Sample posisi + tangent pada arc distance tertentu.
function SplinePath.Sample(path, distance)
	local samples = path.samples
	local nSamp = #samples
	if distance <= 0 then
		local s = samples[1]
		return s.pos, s.tan
	end
	if distance >= path.totalLen then
		local s = samples[nSamp]
		return s.pos, s.tan
	end
	local lo, hi = 1, nSamp
	while lo < hi do
		local mid = (lo + hi) // 2
		if samples[mid].len < distance then
			lo = mid + 1
		else
			hi = mid
		end
	end
	local i = math.max(lo, 2)
	local a = samples[i - 1]
	local b = samples[i]
	local seg = b.len - a.len
	local t = seg > 0 and (distance - a.len) / seg or 0
	local pos = a.pos:Lerp(b.pos, t)
	local tan = a.tan:Lerp(b.tan, t)
	if tan.Magnitude > 1e-6 then tan = tan.Unit else tan = b.tan end
	return pos, tan
end

-- Proyeksi posisi world ke arc length, windowed di sekitar lastIdx.
-- Boat cuma maju, jadi window kecil (belakang 4, depan 60 sample) cukup dan
-- murah per frame. Return: arcLen, sampleIdx (feed balik sebagai lastIdx).
function SplinePath.ProjectNear(path, worldPos, lastIdx)
	local samples = path.samples
	local n = #samples
	lastIdx = math.clamp(lastIdx or 1, 1, n)
	local i0 = math.max(1, lastIdx - 4)
	local i1 = math.min(n, lastIdx + 60)
	local bestI, bestD = lastIdx, math.huge
	for i = i0, i1 do
		local d = (samples[i].pos - worldPos).Magnitude
		if d < bestD then
			bestD = d
			bestI = i
		end
	end
	return samples[bestI].len, bestI
end

return SplinePath
