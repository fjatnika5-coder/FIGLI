-- ServerScriptService > QuestServerHandler
-- All state goes through PlayerState. Async ops validate via sessionToken.
--
-- CHANGES dari versi sebelumnya:
--   * NEW: cinematic camera remotes. StartBoatCamera di-fire di onPlayerAttached
--     (bareng musik), StopBoatCamera di onPlayerDetached. Remote dibuat otomatis
--     kalau belum ada di QuestRemotes.
--   * Drop magic `task.wait(0.1)` sebelum Depart. Dulu itu nunggu AlignPosition
--     stabilize; sekarang gak ada constraint, gak butuh delay. Ganti dengan
--     `task.wait()` (1 Heartbeat) yang lebih semantically explicit.
--   * Build boat tidak panggil SetNetworkOwner lagi. Boat sekarang anchored,
--     ownership concept gak relevan untuk anchored assemblies.
--   * Validate session token TEPAT sebelum setiap step yang side-effect (attach,
--     depart), bukan cuma sebelum walk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local Workspace         = game:GetService("Workspace")
local Players           = game:GetService("Players")

local QuestSystem = ReplicatedStorage:WaitForChild("QuestSystem")
local PathModule  = require(QuestSystem:WaitForChild("PathModule"))
local BoatModule  = require(QuestSystem:WaitForChild("BoatModule"))
local PlayerState = require(QuestSystem:WaitForChild("PlayerState"))
local QuestConfig = require(QuestSystem:WaitForChild("QuestConfig"))
local RateLimit   = require(QuestSystem:WaitForChild("RateLimit"))
local Logger      = require(QuestSystem:WaitForChild("Logger"))

local States = PlayerState.States

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

-- Camera remotes: auto-create supaya gak perlu tambah manual di Studio.
local function getOrCreateRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end
local StartBoatCamera = getOrCreateRemote("StartBoatCamera")
local StopBoatCamera  = getOrCreateRemote("StopBoatCamera")

local nextInviteId = 0
local function newInviteId()
	nextInviteId = nextInviteId + 1
	return nextInviteId
end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function getPosition(instance)
	if instance:IsA("BasePart") then return instance.Position end
	if instance:IsA("Model") then return instance:GetPivot().Position end
	return nil
end

local function getPlayerPos(player)
	if not player or not player.Character then return nil end
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

local function checkRateLimit(player, key)
	return RateLimit.CheckConfig(player, key, QuestConfig.RateLimit)
end

----------------------------------------------------------------
-- BUILD BOAT
-- Unanchor all parts, weld non-primary to primary. BoatModule:Spawn()
-- akan anchor primary lagi setelah pivot.
----------------------------------------------------------------
local function buildBoat(boatType)
	local templateName = QuestConfig.BoatTemplates[boatType]
	if not templateName then return nil, "type invalid" end

	local spawnPart  = Workspace:FindFirstChild("BoatSpawn")
	local pathFolder = Workspace:FindFirstChild("Path")
	local template   = ServerStorage:FindFirstChild(templateName)

	if not spawnPart  then return nil, "BoatSpawn missing" end
	if not pathFolder then return nil, "Path missing" end
	if not template   then return nil, templateName .. " missing in ServerStorage" end

	local waypoints = PathModule.GetWaypoints(pathFolder)
	if #waypoints < 2 then return nil, "need >= 2 waypoints" end

	local boat = template:Clone()
	if not boat.PrimaryPart then boat:Destroy() return nil, "no PrimaryPart" end

	local primary = boat.PrimaryPart
	-- Unanchor everything; weld non-primary to primary
	for _, d in ipairs(boat:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
	for _, d in ipairs(boat:GetDescendants()) do
		if d:IsA("BasePart") and d ~= primary then
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = d
			w.Parent = primary
		end
	end

	local spawnPos = getPosition(spawnPart)
	if not spawnPos then boat:Destroy() return nil, "BoatSpawn invalid" end

	local pathDir = (waypoints[2].Position - waypoints[1].Position).Unit
	local spawnCF = CFrame.lookAt(spawnPos, spawnPos + pathDir)
	boat:PivotTo(spawnCF)
	boat.Parent = Workspace

	return boat, spawnCF, waypoints
end

----------------------------------------------------------------
-- WALK
----------------------------------------------------------------
local function walkPlayerToTarget(player, targetPos)
	if not player.Character then return false end
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return false end

	if (hrp.Position - targetPos).Magnitude <= QuestConfig.Walk.arrivalDistance then return true end

	local arrived = false
	local conn = hum.MoveToFinished:Connect(function(reached) arrived = reached end)
	hum:MoveTo(targetPos)

	local startT = os.clock()
	while os.clock() - startT < QuestConfig.Walk.timeoutSec do
		if not player.Parent or not player.Character then break end
		hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then break end
		if (hrp.Position - targetPos).Magnitude <= QuestConfig.Walk.arrivalDistance then
			arrived = true
			break
		end
		if arrived then break end
		task.wait(QuestConfig.Walk.pollInterval)
	end

	if conn then conn:Disconnect() end
	return arrived
end

----------------------------------------------------------------
-- SOLO
----------------------------------------------------------------
local function startSoloBoat(player)
	local boat, spawnCF, waypoints = buildBoat("solo")
	if not boat then
		Logger.warn("solo_boat_build_fail", { reason = tostring(spawnCF) })
		ShowWarning:FireClient(player, "Gagal spawn perahu")
		return false
	end

	local controller = BoatModule.new(boat, waypoints, {
		speed = QuestConfig.Boat.defaultSpeed,
		boatType = "solo",
		animationConfig = { animId = QuestConfig.Animation.solo },
		onPlayerAttached = function(p)
			StartBoatCamera:FireClient(p, boat, "solo")
			if QuestConfig.Music.solo and QuestConfig.Music.solo ~= "" then
				PlayBoatMusic:FireClient(p, QuestConfig.Music.solo)
			end
		end,
		onPlayerDetached = function(p)
			if p.Parent then
				StopBoatCamera:FireClient(p)
				StopBoatMusic:FireClient(p)
			end
			PlayerState.EnterCooldown(p, QuestConfig.Cooldown.postRideSec)
		end,
	})

	PlayerState.Set(player, States.OnBoat, { boat = controller })
	local token = PlayerState.GetSessionToken(player)
	controller:Spawn(spawnCF)

	local soloPart = controller:GetPositionPart("SoloPosition")
	if not soloPart then
		controller:Destroy()
		PlayerState.Set(player, States.Idle, {})
		ShowWarning:FireClient(player, "SoloPosition tidak ditemukan")
		return false
	end

	task.spawn(function()
		walkPlayerToTarget(player, soloPart.Position)
		if not PlayerState.IsSessionValid(player, token) then
			controller:Destroy()
			return
		end
		local ok = controller:AttachPlayer(player, "solo")
		if not ok then
			controller:Destroy()
			ShowWarning:FireClient(player, "Gagal naik perahu")
			return
		end
		-- One frame for attachment + animation to settle visually
		task.wait()
		if not PlayerState.IsSessionValid(player, token) then return end
		controller:Depart()
	end)

	Logger.info("solo_boat_started", { user = player.UserId })
	return true
end

----------------------------------------------------------------
-- DUO
----------------------------------------------------------------
local function startDuoBoat(inviter, target)
	local boat, spawnCF, waypoints = buildBoat("couple")
	if not boat then
		Logger.warn("duo_boat_build_fail", { reason = tostring(spawnCF) })
		ShowWarning:FireClient(inviter, "Gagal spawn perahu")
		if target.Parent then ShowWarning:FireClient(target, "Gagal spawn perahu") end
		return false
	end

	local controller = BoatModule.new(boat, waypoints, {
		speed = QuestConfig.Boat.defaultSpeed,
		boatType = "couple",
		animationConfig = QuestConfig.Animation.duo,
		onPlayerAttached = function(p)
			StartBoatCamera:FireClient(p, boat, "duo")
			if QuestConfig.Music.duo and QuestConfig.Music.duo ~= "" then
				PlayBoatMusic:FireClient(p, QuestConfig.Music.duo)
			end
		end,
		onPlayerDetached = function(p)
			if p.Parent then
				StopBoatCamera:FireClient(p)
				StopBoatMusic:FireClient(p)
			end
			PlayerState.EnterCooldown(p, QuestConfig.Cooldown.postRideSec)
		end,
	})

	PlayerState.Set(inviter, States.OnBoat, { boat = controller, partnerUid = target.UserId })
	PlayerState.Set(target,  States.OnBoat, { boat = controller, partnerUid = inviter.UserId })
	local inviterToken = PlayerState.GetSessionToken(inviter)
	local targetToken  = PlayerState.GetSessionToken(target)

	controller:Spawn(spawnCF)

	local malePart = controller:GetPositionPart("MalePosition")
	local femalePart = controller:GetPositionPart("FemalePosition")
	if not (malePart and femalePart) then
		controller:Destroy()
		PlayerState.Set(inviter, States.Idle, {})
		PlayerState.Set(target,  States.Idle, {})
		ShowWarning:FireClient(inviter, "Position parts tidak ditemukan")
		return false
	end

	task.spawn(function()
		local arrivals = { [inviter] = false, [target] = false }
		local signal = Instance.new("BindableEvent")
		local count = 0

		local function tryWalk(p, role, part, expectedToken)
			task.spawn(function()
				walkPlayerToTarget(p, part.Position)
				if not PlayerState.IsSessionValid(p, expectedToken) or not p.Parent then
					arrivals[p] = false
					count = count + 1
					signal:Fire()
					return
				end
				local ok = controller:AttachPlayer(p, role)
				arrivals[p] = ok
				count = count + 1
				signal:Fire()
			end)
		end

		tryWalk(inviter, "male",   malePart,   inviterToken)
		tryWalk(target,  "female", femalePart, targetToken)

		local startT = os.clock()
		while count < 2 and os.clock() - startT < (QuestConfig.Walk.timeoutSec + 2) do
			signal.Event:Wait()
		end
		signal:Destroy()

		if not (PlayerState.IsSessionValid(inviter, inviterToken)
			and PlayerState.IsSessionValid(target, targetToken)) then
			controller:Destroy()
			return
		end

		if not (arrivals[inviter] and arrivals[target]) then
			ShowWarning:FireClient(inviter, "Salah satu player gagal naik")
			if target.Parent then ShowWarning:FireClient(target, "Gagal naik perahu") end
			controller:Destroy()
			return
		end

		-- One frame for both attachments + sync animation to settle
		task.wait()
		if not (PlayerState.IsSessionValid(inviter, inviterToken)
			and PlayerState.IsSessionValid(target, targetToken)) then return end
		controller:Depart()
	end)

	Logger.info("duo_boat_started", { inviter = inviter.UserId, target = target.UserId })
	return true
end

----------------------------------------------------------------
-- INVITE FLOW
----------------------------------------------------------------
local function expireInvite(inviter, target, reason, applyTargetCooldown)
	if inviter and PlayerState.Is(inviter, States.InvitedOut) then
		local data = select(2, PlayerState.Get(inviter))
		if data.cancelToken then pcall(task.cancel, data.cancelToken) end
		PlayerState.Set(inviter, States.Idle, {})
	end
	if target and PlayerState.Is(target, States.InvitedIn) then
		PlayerState.Set(target, States.Idle, {})
	end

	if applyTargetCooldown and inviter and target then
		PlayerState.MarkTargetCooldown(inviter, target, QuestConfig.Invite.targetSpamCD)
	end

	if target and target.Parent then
		local _, tData = PlayerState.Get(target)
		CloseDuoInvitePrompt:FireClient(target, tData.inviteId or 0)
	end
	if inviter and inviter.Parent then
		NotifyDuoStatus:FireClient(inviter, reason, nil)
	end

	Logger.info("invite_expired", {
		inviter = inviter and inviter.UserId,
		target  = target and target.UserId,
		reason  = reason,
	})
end

local function createInvite(inviter, target)
	local id = newInviteId()

	local cancelToken = task.delay(QuestConfig.Invite.timeoutSec, function()
		expireInvite(inviter, target, "timeout", true)
	end)

	PlayerState.Set(inviter, States.InvitedOut, {
		inviteId    = id,
		targetUid   = target.UserId,
		cancelToken = cancelToken,
	})
	PlayerState.Set(target, States.InvitedIn, {
		inviteId   = id,
		inviterUid = inviter.UserId,
	})

	ShowDuoInvitePrompt:FireClient(target, inviter, id, QuestConfig.Invite.timeoutSec)
	NotifyDuoStatus:FireClient(inviter, "sent",
		"Invite dikirim ke " .. (target.DisplayName or target.Name))

	Logger.info("invite_created", {
		id      = id,
		inviter = inviter.UserId,
		target  = target.UserId,
	})
end

----------------------------------------------------------------
-- REMOTES
----------------------------------------------------------------
RequestBoat.OnServerEvent:Connect(function(player, boatType)
	if not checkRateLimit(player, "RequestBoat") then return end
	if type(boatType) ~= "string" or boatType ~= "solo" then return end

	local state = PlayerState.Get(player)
	if state == States.Cooldown then
		local _, rem = PlayerState.IsOnCooldown(player)
		ShowWarning:FireClient(player, "Tunggu " .. math.ceil(rem) .. " detik lagi")
		return
	end
	if state ~= States.Idle then
		ShowWarning:FireClient(player, "Lo lagi sibuk!")
		return
	end

	if not startSoloBoat(player) then
		PlayerState.Set(player, States.Idle, {})
	end
end)

GetNearbyPlayers.OnServerInvoke = function(player)
	if not checkRateLimit(player, "GetNearbyPlayers") then
		return {}
	end

	local pos = getPlayerPos(player)
	if not pos then return {} end

	local radius = QuestConfig.Invite.nearbyRadius
	local result = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherPos = getPlayerPos(other)
			if otherPos and (otherPos - pos).Magnitude <= radius then
				if PlayerState.IsIdle(other) then
					table.insert(result, {
						UserId = other.UserId,
						Name = other.Name,
						DisplayName = other.DisplayName,
					})
				end
			end
		end
	end
	return result
end

RequestDuoInvite.OnServerEvent:Connect(function(player, targetUserId)
	if not checkRateLimit(player, "RequestDuoInvite") then return end
	if type(targetUserId) ~= "number" then return end
	if targetUserId == player.UserId then return end

	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		ShowWarning:FireClient(player, "Player gak ditemukan")
		return
	end

	local state = PlayerState.Get(player)
	if state == States.Cooldown then
		local _, rem = PlayerState.IsOnCooldown(player)
		ShowWarning:FireClient(player, "Tunggu " .. math.ceil(rem) .. " detik lagi")
		return
	end
	if state ~= States.Idle then
		ShowWarning:FireClient(player, "Lo lagi sibuk!")
		return
	end

	if not PlayerState.IsIdle(target) then
		ShowWarning:FireClient(player, (target.DisplayName or target.Name) .. " lagi sibuk")
		return
	end

	local canInvite, rem = PlayerState.CanInviteTarget(player, target)
	if not canInvite then
		ShowWarning:FireClient(player,
			"Tunggu " .. math.ceil(rem) .. " detik sebelum invite "
				.. (target.DisplayName or target.Name) .. " lagi")
		return
	end

	local pPos = getPlayerPos(player)
	local tPos = getPlayerPos(target)
	if not (pPos and tPos) or (pPos - tPos).Magnitude > QuestConfig.Invite.nearbyRadius then
		ShowWarning:FireClient(player, "Player terlalu jauh")
		return
	end

	createInvite(player, target)
end)

RespondDuoInvite.OnServerEvent:Connect(function(player, inviteId, accept)
	if not checkRateLimit(player, "RespondDuoInvite") then return end
	if type(inviteId) ~= "number" then return end

	local state, data = PlayerState.Get(player)
	if state ~= States.InvitedIn or data.inviteId ~= inviteId then return end

	local inviter = Players:GetPlayerByUserId(data.inviterUid)
	if not inviter or not PlayerState.Is(inviter, States.InvitedOut) then
		PlayerState.Set(player, States.Idle, {})
		return
	end

	local _, invData = PlayerState.Get(inviter)
	if invData.inviteId ~= inviteId then
		PlayerState.Set(player, States.Idle, {})
		return
	end

	if accept then
		if invData.cancelToken then pcall(task.cancel, invData.cancelToken) end
		CloseDuoInvitePrompt:FireClient(player, inviteId)
		NotifyDuoStatus:FireClient(inviter, "accepted",
			(player.DisplayName or player.Name) .. " terima!")

		if not startDuoBoat(inviter, player) then
			PlayerState.Set(inviter, States.Idle, {})
			PlayerState.Set(player,  States.Idle, {})
			NotifyDuoStatus:FireClient(inviter, "failed", "Gagal spawn perahu")
		end
	else
		expireInvite(inviter, player, "declined", true)
	end
end)

CancelDuoInvite.OnServerEvent:Connect(function(player, inviteId)
	if not checkRateLimit(player, "CancelDuoInvite") then return end
	if type(inviteId) ~= "number" then return end

	local state, data = PlayerState.Get(player)
	if state ~= States.InvitedOut or data.inviteId ~= inviteId then return end

	local target = Players:GetPlayerByUserId(data.targetUid)
	expireInvite(player, target, "cancelled", false)
end)

----------------------------------------------------------------
-- CLEANUP ON LEAVE
-- PlayerState tombstone bikin state masih readable di sini.
----------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	local state, data = PlayerState.Get(player)

	if state == States.OnBoat and data.boat then
		pcall(function() data.boat:Destroy() end)
	elseif state == States.InvitedOut then
		local target = Players:GetPlayerByUserId(data.targetUid or 0)
		expireInvite(player, target, "inviter_left", false)
	elseif state == States.InvitedIn then
		local inviter = Players:GetPlayerByUserId(data.inviterUid or 0)
		expireInvite(inviter, player, "target_left", true)
	end
end)

Logger.info("quest_server_handler_ready", {})
