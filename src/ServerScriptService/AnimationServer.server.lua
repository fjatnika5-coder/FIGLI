--!strict
-- Lokasi: ServerScriptService/AnimationServer
-- Sinkronisasi dance/pose antar player (leader-follower) dengan cache track.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ===== Remotes =====
local Events = ReplicatedStorage:WaitForChild("EventsACMS")
local RequestSync = Events:WaitForChild("RequestSync") :: RemoteEvent
local UpdateAnimation = Events:WaitForChild("UpdateAnimation") :: RemoteEvent

local UpdateAnimationSpeed = Events:FindFirstChild("UpdateAnimationSpeed") :: RemoteEvent?
if not UpdateAnimationSpeed then
	UpdateAnimationSpeed = Instance.new("RemoteEvent")
	UpdateAnimationSpeed.Name = "UpdateAnimationSpeed"
	UpdateAnimationSpeed.Parent = Events
end

-- ===== Modules / Data =====
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Animations = require(Shared:WaitForChild("Animations"))
local okPoses, PosesModule = pcall(function() return require(Shared:WaitForChild("Poses")) end)
local Poses = okPoses and (PosesModule :: any) or {}

-- ===== Normalizer =====
local function stdId(id: string?): string?
	if type(id) ~= "string" then return nil end
	local digits = id:match("%d+")
	if not digits then return nil end
	return "rbxassetid://" .. digits
end

-- ===== State =====
type AnimRow = { name: string?, animationId: string }
local animationData: { [string]: AnimRow } = {}
local animationInstance: { [string]: Animation } = {}

-- Track cache: key = "userId_animId" -> AnimationTrack
local trackCache: { [string]: AnimationTrack } = {}

local activeTrack: { [number]: AnimationTrack? } = {}
local activeAnimId: { [number]: string? } = {}

-- Lock per player: cegah race saat replicate paralel
local playerLock: { [number]: boolean } = {}

-- Rate limit remote per player per aksi
local remoteCooldown: { [number]: { [string]: number } } = {}

local function allowRemote(plr: Player, action: string, cooldown: number): boolean
	local bucket = remoteCooldown[plr.UserId]
	if not bucket then
		bucket = {}
		remoteCooldown[plr.UserId] = bucket
	end
	local now = os.clock()
	if (now - (bucket[action] or 0)) < cooldown then
		return false
	end
	bucket[action] = now
	return true
end

-- Fade params
local FADE_IN = 0.18
local FADE_OUT = 0.16
local SAFE_EPS = 0.033

-- Sync heartbeat
local SYNC_INTERVAL = 2.0
local SYNC_TOLERANCE = 0.08

-- ===== Utils =====
local function getHumanoid(plr: Player): Humanoid?
	local ch = plr.Character
	if not ch then return nil end
	return ch:FindFirstChildOfClass("Humanoid")
end

local function getAnimator(hum: Humanoid?): Animator?
	if not hum then return nil end
	local a = hum:FindFirstChildOfClass("Animator")
	if not a then
		a = Instance.new("Animator")
		a.Parent = hum
	end
	return a
end

local function isTrackValid(track: AnimationTrack?): boolean
	if not track then return false end
	local ok, result = pcall(function()
		local _ = track.Length
		local _ = track.IsPlaying
		return true
	end)
	return ok and result == true
end

local function getOrLoadTrack(plr: Player, animator: Animator, animStdId: string): AnimationTrack?
	local cacheKey = tostring(plr.UserId) .. "_" .. animStdId
	local cached = trackCache[cacheKey]

	if cached and isTrackValid(cached) then
		return cached
	end

	if cached then
		pcall(function() cached:Stop(0) end)
		pcall(function() cached:Destroy() end)
		trackCache[cacheKey] = nil
	end

	local animObj = animationInstance[animStdId]
	if not animObj then return nil end

	local ok, newTrack = pcall(function()
		return animator:LoadAnimation(animObj)
	end)

	if not ok or not newTrack then
		warn("[AnimationServer] LoadAnimation failed for:", animStdId)
		return nil
	end

	trackCache[cacheKey] = newTrack
	return newTrack
end

local function stopAndDestroyTrack(track: AnimationTrack?, playerId: number, animStdId: string?)
	if not track then return end

	pcall(function() track:Stop(FADE_OUT) end)

	if animStdId then
		local cacheKey = tostring(playerId) .. "_" .. animStdId
		if trackCache[cacheKey] == track then
			trackCache[cacheKey] = nil
		end
	end

	task.delay(FADE_OUT + 0.1, function()
		pcall(function() track:Destroy() end)
	end)
end

local function destroyAllTracksForPlayer(plr: Player)
	local userId = plr.UserId

	activeTrack[userId] = nil
	activeAnimId[userId] = nil
	playerLock[userId] = nil

	local prefix = tostring(userId) .. "_"
	for key, cachedTrack in pairs(trackCache) do
		if key:sub(1, #prefix) == prefix then
			pcall(function() cachedTrack:Stop(0) end)
			pcall(function() cachedTrack:Destroy() end)
			trackCache[key] = nil
		end
	end

	local hum = getHumanoid(plr)
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		pcall(function() track:Stop(0) end)
		pcall(function() track:Destroy() end)
	end
end

-- ===== Sync group (BFS follower chain) =====
local function searchSynchronizedPlayers(start: Player): { [Player]: Humanoid? }
	local indexed: { [Player]: Humanoid? } = { [start] = getHumanoid(start) }
	local queue = { start }
	while #queue > 0 do
		local cur = table.remove(queue, 1) :: Player
		for _, other in ipairs(Players:GetPlayers()) do
			if indexed[other] then continue end
			local sid = other:GetAttribute("syncedPlayerId")
			if typeof(sid) == "number" and sid == cur.UserId then
				indexed[other] = getHumanoid(other)
				table.insert(queue, other)
			end
		end
	end
	return indexed
end

-- ===== Track search =====
local function searchCurrentAnimationTrack(plr: Player): AnimationTrack?
	local current = activeTrack[plr.UserId]
	if current and isTrackValid(current) then
		local ok, isPlaying = pcall(function() return current.IsPlaying end)
		if ok and isPlaying then
			return current
		end
	end

	local curStdId = activeAnimId[plr.UserId]
	if not curStdId then
		local curIdRaw = plr:GetAttribute("currentAnimationId")
		if typeof(curIdRaw) ~= "string" then return nil end
		curStdId = stdId(curIdRaw)
	end
	if not curStdId then return nil end

	local animObj = animationInstance[curStdId]
	if not animObj then return nil end

	local ch = plr.Character
	if not ch then return nil end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end

	local targetId = animObj.AnimationId
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation and track.Animation.AnimationId == targetId then
			activeTrack[plr.UserId] = track
			return track
		end
	end
	return nil
end

local function getLeaderSpeed(leader: Player, refTrack: AnimationTrack?): number
	local attr = leader:GetAttribute("currentAnimationSpeed")
	if typeof(attr) == "number" then
		return attr
	end
	if refTrack then
		local ok, spd = pcall(function() return refTrack.Speed end)
		if ok and typeof(spd) == "number" then
			return spd
		end
	end
	return 1.0
end

-- ===== CORE: replicateAnimation =====
local function replicateAnimation(sourceLeader: Player, animationId: string?, onlyUserId: number?, isNewDance: boolean?)
	local refSpeed = getLeaderSpeed(sourceLeader, searchCurrentAnimationTrack(sourceLeader))

	local wantStdId: string? = nil
	if animationId ~= nil then
		local std = stdId(animationId)
		if not std then
			warn("[AnimationServer] Bad animationId (std fail):", animationId)
			return
		end
		wantStdId = std
		if not animationInstance[wantStdId] then
			warn("[AnimationServer] Unknown animationId:", wantStdId)
			return
		end
	end

	for plr, hum in pairs(searchSynchronizedPlayers(sourceLeader)) do
		if onlyUserId and plr.UserId ~= onlyUserId then continue end
		if not hum then continue end

		task.spawn(function(targetPlr: Player, targetHum: Humanoid, targetStdId: string?, spd: number)
			local userId = targetPlr.UserId

			if playerLock[userId] then return end
			playerLock[userId] = true

			local ok, err = pcall(function()
				local animator = getAnimator(targetHum)
				if not animator then return end

				local oldTrack = activeTrack[userId]
				local oldStdId = activeAnimId[userId]

				-- ===== STOP =====
				if targetStdId == nil then
					stopAndDestroyTrack(oldTrack, userId, oldStdId)
					activeTrack[userId] = nil
					activeAnimId[userId] = nil
					targetPlr:SetAttribute("currentAnimationId", nil)
					targetHum.WalkSpeed = 16
					return
				end

				-- ===== ANIM SAMA MASIH JALAN: cukup sync posisi/speed =====
				if oldStdId == targetStdId and oldTrack and isTrackValid(oldTrack) then
					local isPlaying = false
					pcall(function() isPlaying = oldTrack.IsPlaying end)
					if isPlaying then
						if isNewDance == nil or isNewDance == false then
							local leaderTrack = searchCurrentAnimationTrack(sourceLeader)
							if leaderTrack then
								local livePos = leaderTrack.TimePosition
								local trackLen = oldTrack.Length
								if trackLen > 0 then
									local safe = math.max(0, math.min(trackLen - SAFE_EPS, livePos % trackLen))
									oldTrack.TimePosition = safe
								end
							end
						end
						pcall(function() oldTrack:AdjustSpeed(spd) end)
						return
					end
				end

				-- ===== PLAY / SWITCH =====
				local newTrack = getOrLoadTrack(targetPlr, animator, targetStdId :: string)
				if not newTrack then
					warn("[AnimationServer] Failed to load track for:", targetStdId)
					return
				end

				newTrack.Priority = Enum.AnimationPriority.Action4
				newTrack.Looped = true
				newTrack:Play(FADE_IN)
				pcall(function() newTrack:AdjustWeight(1, FADE_IN) end)

				if isNewDance == true then
					newTrack.TimePosition = 0
				else
					-- Join mid-dance: baca posisi live leader SETELAH LoadAnimation selesai
					local leaderTrack = searchCurrentAnimationTrack(sourceLeader)
					if leaderTrack then
						local livePos = leaderTrack.TimePosition
						local trackLen = newTrack.Length
						if trackLen > 0 then
							local safe = math.max(0, math.min(trackLen - SAFE_EPS, livePos % trackLen))
							newTrack.TimePosition = safe
						end
					end
				end

				pcall(function() newTrack:AdjustSpeed(spd) end)

				if oldTrack and oldTrack ~= newTrack then
					stopAndDestroyTrack(oldTrack, userId, oldStdId)
				end

				activeTrack[userId] = newTrack
				activeAnimId[userId] = targetStdId
				targetPlr:SetAttribute("currentAnimationId", targetStdId)
				targetHum.WalkSpeed = 6
			end)

			playerLock[userId] = nil

			if not ok then
				warn("[AnimationServer] replicateAnimation error:", err)
			end
		end, plr, hum, wantStdId, refSpeed)
	end
end

-- ===== Sync heartbeat: koreksi drift follower =====
local lastSyncCheck = 0

local function syncHeartbeat()
	local now = os.clock()
	if now - lastSyncCheck < SYNC_INTERVAL then return end
	lastSyncCheck = now

	for _, plr in ipairs(Players:GetPlayers()) do
		local sid = plr:GetAttribute("syncedPlayerId")
		if typeof(sid) ~= "number" then continue end

		local leader = Players:GetPlayerByUserId(sid)
		if not leader then continue end

		pcall(function()
			local leaderTrack = searchCurrentAnimationTrack(leader)
			if not leaderTrack then return end

			local followerTrack = searchCurrentAnimationTrack(plr)
			if not followerTrack then return end

			if activeAnimId[leader.UserId] ~= activeAnimId[plr.UserId] then return end

			local leaderPos = leaderTrack.TimePosition
			local followerPos = followerTrack.TimePosition
			local trackLen = leaderTrack.Length
			if trackLen <= 0 then return end

			local drift = math.abs(leaderPos - followerPos)
			local wrapDrift = trackLen - drift
			local actualDrift = math.min(drift, wrapDrift)

			if actualDrift > SYNC_TOLERANCE then
				local safe = math.max(0, math.min(trackLen - SAFE_EPS, leaderPos))
				followerTrack.TimePosition = safe
				followerTrack:AdjustSpeed(getLeaderSpeed(leader, leaderTrack))
			end
		end)
	end
end

RunService.Heartbeat:Connect(syncHeartbeat)

-- ===== Lifecycle =====
local function onCharacterAdded(plr: Player, _chr: Model)
	destroyAllTracksForPlayer(plr)

	if plr:GetAttribute("syncedPlayerId") ~= nil then
		plr:SetAttribute("syncedPlayerId", nil)
	end
	plr:SetAttribute("currentAnimationId", nil)
end

local function registerPlayer(plr: Player)
	if typeof(plr:GetAttribute("currentAnimationSpeed")) ~= "number" then
		plr:SetAttribute("currentAnimationSpeed", 1.0)
	end
	plr.CharacterAdded:Connect(function(chr) onCharacterAdded(plr, chr) end)
end

local function unregisterPlayer(plr: Player)
	destroyAllTracksForPlayer(plr)
	remoteCooldown[plr.UserId] = nil

	for _, other in ipairs(Players:GetPlayers()) do
		if other:GetAttribute("syncedPlayerId") == plr.UserId then
			other:SetAttribute("syncedPlayerId", nil)
			replicateAnimation(other, nil, other.UserId, true)
		end
	end
end

-- ===== Remote Handlers =====
local function updateAnimationHandler(plr: Player, animIdAny: any)
	if typeof(animIdAny) ~= "string" then return end
	if not allowRemote(plr, "UpdateAnimation", 0.25) then return end

	local incomingStd = stdId(animIdAny)
	if not incomingStd then return end
	if animationData[incomingStd] == nil then return end

	local cur = activeAnimId[plr.UserId] or stdId(plr:GetAttribute("currentAnimationId"))
	if cur and cur == incomingStd then
		if plr:GetAttribute("syncedPlayerId") ~= nil then
			plr:SetAttribute("syncedPlayerId", nil)
		end
		replicateAnimation(plr, nil, nil, true)
		return
	end

	if plr:GetAttribute("syncedPlayerId") ~= nil then
		plr:SetAttribute("syncedPlayerId", nil)
	end

	replicateAnimation(plr, incomingStd, nil, true)
end

local function syncRequestHandler(plr: Player, requestedPlayer: any)
	if not allowRemote(plr, "RequestSync", 0.5) then return end

	if requestedPlayer == nil then
		plr:SetAttribute("syncedPlayerId", nil)
		replicateAnimation(plr, nil, plr.UserId, false)
		return
	end
	if typeof(requestedPlayer) ~= "Instance" or not requestedPlayer:IsA("Player") then
		return
	end
	if requestedPlayer == plr then return end

	plr:SetAttribute("syncedPlayerId", requestedPlayer.UserId)

	local targetStd = stdId(requestedPlayer:GetAttribute("currentAnimationId"))
	if targetStd and animationInstance[targetStd] ~= nil then
		replicateAnimation(requestedPlayer, targetStd, plr.UserId, false)
	else
		replicateAnimation(plr, nil, plr.UserId, false)
	end
end

local function updateAnimationSpeedHandler(plr: Player, spdAny: any)
	if typeof(spdAny) ~= "number" then return end
	if spdAny ~= spdAny then return end -- NaN guard
	if not allowRemote(plr, "UpdateSpeed", 0.2) then return end

	local spd = math.clamp(spdAny, 0.1, 3.0)
	plr:SetAttribute("currentAnimationSpeed", spd)

	for member, _hum in pairs(searchSynchronizedPlayers(plr)) do
		local track = searchCurrentAnimationTrack(member)
		if track then
			pcall(function() track:AdjustSpeed(spd) end)
		end
	end
end

-- ===== Init =====
local function addList(list: {AnimRow})
	for _, row in ipairs(list) do
		local std = stdId(row.animationId)
		if std and not animationInstance[std] then
			animationData[std] = row
			local anim = Instance.new("Animation")
			anim.AnimationId = std
			animationInstance[std] = anim
		end
	end
end

addList(Animations :: {AnimRow})
if type(Poses) == "table" then addList(Poses :: {AnimRow}) end

Players.PlayerAdded:Connect(registerPlayer)
Players.PlayerRemoving:Connect(unregisterPlayer)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(registerPlayer, p)
end

RequestSync.OnServerEvent:Connect(syncRequestHandler)
UpdateAnimation.OnServerEvent:Connect(updateAnimationHandler)
assert(UpdateAnimationSpeed, "UpdateAnimationSpeed RemoteEvent must exist")
UpdateAnimationSpeed.OnServerEvent:Connect(updateAnimationSpeedHandler)
