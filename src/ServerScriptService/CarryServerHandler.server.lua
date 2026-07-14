--!strict
-- Lokasi: ServerScriptService/CarryServerHandler
-- Sistem carry (solo/multi) dengan lock, rate limit, dan cleanup per pasangan.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes
local REMOTE_NAME = "CarryRemote"
local CarryRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME) or Instance.new("RemoteEvent")
CarryRemote.Name = REMOTE_NAME
CarryRemote.Parent = ReplicatedStorage

type Blueprint = {
	Mode: string,
	CFrame: CFrame,
	CarrierAnimID_R15: number,
	CarrierAnimID_R6: number,
	TargetAnimID_R15: number,
	TargetAnimID_R6: number,
}
local CarryBlueprints = require(ReplicatedStorage:WaitForChild("CarryBlueprints"))

-- Config
local PENDING_TIMEOUT = 8
local MAX_DISTANCE = 20
local MAX_CARRY_MULTI = 8
local MAX_CARRY_SOLO = 1

local REMOTE_COOLDOWN = 0.3
local lastRemoteAction: {[number]: number} = {}

-- Formation (mode "Multi")
local BASE_Z = 1.6
local SPACING_Z = 1.1
local Y_OFFSET = 0.9
local SLOT1_ADJ_Z = -0.2
local SLOT2_ADJ_Z = 0.2
local STEP_Y_FIRST = 0.55
local STEP_Y_NEXT = 0.30
local MAX_EXTRA_Y = 6.0
local function slotOffset(i: number): CFrame
	local z = BASE_Z + (i - 1) * SPACING_Z
	if i == 1 then z += SLOT1_ADJ_Z elseif i == 2 then z += SLOT2_ADJ_Z end
	local elevIndex = math.max(0, i - 1)
	local extraY = (elevIndex > 0) and (STEP_Y_FIRST + (elevIndex - 1) * STEP_Y_NEXT) or 0
	extraY = math.min(extraY, MAX_EXTRA_Y)
	return CFrame.new(0, Y_OFFSET + extraY, z)
end

-- State
local pending: {[number]: {requester: Player, time: number, animType: string}} = {}
local carryingByCarrier: {[number]: {[number]: Player}} = {}
local carriedByTarget: {[number]: Player} = {}
local slotByCarrier: {[number]: {[number]: number}} = {}
local lockMap: {[number]: boolean} = {}
local detachGuard: {[number]: boolean} = {}
local carryModeByCarrier: {[number]: string} = {}
local animTypeByCarrier: {[number]: string} = {}

-- Cleanup connection per pasangan carrier-target
local pairCleanupConns: {[string]: {RBXScriptConnection}} = {}

local function getPairKey(carrierUid: number, targetUid: number): string
	return tostring(carrierUid) .. "_" .. tostring(targetUid)
end

local function disconnectPairCleanup(carrierUid: number, targetUid: number)
	local key = getPairKey(carrierUid, targetUid)
	local conns = pairCleanupConns[key]
	if conns then
		for _, conn in ipairs(conns) do
			if conn.Connected then conn:Disconnect() end
		end
		pairCleanupConns[key] = nil
	end
end

-- Save/Restore physical props
local savedProps: {[number]: {[BasePart]: {cc: boolean, ml: boolean, props: PhysicalProperties?}}} = {}
local savedHum: {[number]: {autoRotate: boolean}} = {}

local function getCharHRP(p: Player)
	local char = p.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not (hrp and hum) then return end
	return char, hrp, hum
end

-- Lock dengan timeout supaya tidak deadlock permanen
local LOCK_TIMEOUT = 5

local function acquireLock(uid: number)
	local start = os.clock()
	while lockMap[uid] do
		if (os.clock() - start) > LOCK_TIMEOUT then
			warn("[CarryServer] Lock timeout for", uid, "- force releasing")
			lockMap[uid] = false
			break
		end
		task.wait()
	end
	lockMap[uid] = true
end
local function releaseLock(uid: number) lockMap[uid] = false end
local function acquireLocks(a: number, b: number)
	if a == b then acquireLock(a) return end
	if a < b then acquireLock(a); acquireLock(b) else acquireLock(b); acquireLock(a) end
end
local function releaseLocks(a: number, b: number)
	releaseLock(a); if b ~= a then releaseLock(b) end
end

local function getCarryMap(carrier: Player)
	local m = carryingByCarrier[carrier.UserId]
	if not m then m = {}; carryingByCarrier[carrier.UserId] = m end
	return m
end
local function getSlotMap(carrier: Player)
	local m = slotByCarrier[carrier.UserId]
	if not m then m = {}; slotByCarrier[carrier.UserId] = m end
	return m
end
local function countCarried(carrier: Player)
	local m = carryingByCarrier[carrier.UserId]; if not m then return 0 end
	local n = 0; for _ in pairs(m) do n += 1 end
	return n
end
local function isBeingCarried(p: Player) return carriedByTarget[p.UserId] ~= nil end
local function targetAvailable(p: Player) return not isBeingCarried(p) end

local function saveHumState(uid: number, hum: Humanoid)
	savedHum[uid] = {
		autoRotate = hum.AutoRotate,
	}
end
local function restoreHumState(uid: number, hum: Humanoid)
	local st = savedHum[uid]
	if st then
		hum.AutoRotate = st.autoRotate
		savedHum[uid] = nil
	else
		hum.AutoRotate = true
	end
	hum.WalkSpeed = 16
end

local function makeCarriedLight(char: Model, userId: number)
	local map: {[BasePart]: {cc: boolean, ml: boolean, props: PhysicalProperties?}} = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			map[d] = {
				cc = d.CanCollide,
				ml = d.Massless,
				props = d.CustomPhysicalProperties,
			}
			d.CanCollide = false
			d.Massless = true
			d.CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0)
		end
	end
	savedProps[userId] = map
end

local function restoreCarriedLight(userId: number)
	local map = savedProps[userId]; if not map then return end
	for part, st in pairs(map) do
		if part and part.Parent then
			part.CanCollide = st.cc
			part.Massless = st.ml
			part.CustomPhysicalProperties = st.props
		end
	end
	savedProps[userId] = nil
end

-- Weld
local function clearCarryWeldsForChar(char: Model)
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		for _, w in ipairs(hrp:GetChildren()) do
			if w:IsA("WeldConstraint") and w.Name == "CarryWeld" then
				w:Destroy()
			end
		end
	end
end
local function findCarryWeldBetween(targetHRP: BasePart, carrierHRP: BasePart): WeldConstraint?
	for _, w in ipairs(targetHRP:GetChildren()) do
		if w:IsA("WeldConstraint") and w.Name == "CarryWeld" and w.Part0 == carrierHRP and w.Part1 == targetHRP then
			return w
		end
	end
	return nil
end
local function ensureCarryWeldBetween(carrierHRP: BasePart, targetHRP: BasePart): WeldConstraint
	local w = findCarryWeldBetween(targetHRP, carrierHRP)
	if not w then
		w = Instance.new("WeldConstraint")
		w.Name = "CarryWeld"
		w.Part0 = carrierHRP
		w.Part1 = targetHRP
		w.Parent = targetHRP
	end
	return w
end
local function removeCarryWeldBetween(carrierHRP: BasePart, targetHRP: BasePart)
	local w = findCarryWeldBetween(targetHRP, carrierHRP)
	if w then w:Destroy() end
end

-- UI Snapshot
local function buildCarriedList(carrier: Player)
	local list = {}
	local cmap = carryingByCarrier[carrier.UserId]
	if cmap then
		for tid, t in pairs(cmap) do table.insert(list, {id=tid, name=t.DisplayName}) end
		table.sort(list, function(a,b) return a.name < b.name end)
	end
	return list
end

local function sendCarrierList(carrier: Player)
	if not carrier or not carrier.Parent then return end
	CarryRemote:FireClient(carrier, "CarrierList", {
		list = buildCarriedList(carrier),
		carryMode = carryModeByCarrier[carrier.UserId],
		animType = animTypeByCarrier[carrier.UserId]
	})
end

-- Reindex slot (mode "Multi")
local function reindexSlots(carrier: Player)
	if carryModeByCarrier[carrier.UserId] ~= "Multi" then return end

	acquireLock(carrier.UserId)
	pcall(function()
		local _, cHRP = getCharHRP(carrier); if not cHRP then return end
		local smap = slotByCarrier[carrier.UserId]; if not smap then return end
		local temp = {}
		for tid, s in pairs(smap) do
			local t = Players:GetPlayerByUserId(tid)
			if t then table.insert(temp, {p=t, s=s}) end
		end
		table.sort(temp, function(a,b) return a.s < b.s end)
		for i, e in ipairs(temp) do
			local _tChar, tHRP = getCharHRP(e.p)
			if tHRP then
				if e.s ~= i then
					removeCarryWeldBetween(cHRP, tHRP)
					tHRP.CFrame = cHRP.CFrame * slotOffset(i)
					ensureCarryWeldBetween(cHRP, tHRP)
					slotByCarrier[carrier.UserId][e.p.UserId] = i
				else
					ensureCarryWeldBetween(cHRP, tHRP)
				end
			end
		end
	end)
	releaseLock(carrier.UserId)
end

-- Notify
local function sendStart(carrier: Player, target: Player, animType: string, carryMode: string)
	if not carrier.Parent or not target.Parent then return end
	local total = countCarried(carrier)
	CarryRemote:FireClient(carrier, "Start", {
		carrierId=carrier.UserId, carrierName=carrier.DisplayName,
		targetId=target.UserId,    targetName=target.DisplayName,
		youAreCarrier=true, carrierActiveCount=total,
		animType = animType,
		carryMode = carryMode
	})
	CarryRemote:FireClient(target, "Start", {
		carrierId=carrier.UserId, carrierName=carrier.DisplayName,
		targetId=target.UserId,    targetName=target.DisplayName,
		youAreCarrier=false,
		animType = animType,
		carryMode = carryMode
	})
end

local function sendEndForCarrierOnly(carrier: Player, removedTarget: Player, reason: string?)
	if not carrier.Parent then return end
	local total = countCarried(carrier)
	CarryRemote:FireClient(carrier, "End", {
		reason = reason or "end",
		youAreCarrier = true,
		carrierActiveCount = total,
		removedId = removedTarget.UserId,
		removedName = removedTarget.DisplayName,
	})
end
local function sendEndPair(carrier: Player, target: Player, reason: string?)
	if carrier.Parent then
		local total = countCarried(carrier)
		CarryRemote:FireClient(carrier, "End", {
			reason = reason or "end",
			youAreCarrier = true,
			carrierActiveCount = total,
			removedId = target.UserId,
			removedName = target.DisplayName,
		})
	end
	if target.Parent then
		local still = countCarried(target)
		CarryRemote:FireClient(target, "End", {reason = reason or "end", youAreCarrier = false, yourCarryCount = still})
	end
end

-- Detach
local function detachPair(carrier: Player, target: Player, reason: string?)
	local cUID = carrier.UserId
	local tUID = target.UserId

	disconnectPairCleanup(cUID, tUID)

	acquireLock(cUID)
	-- Seluruh bagian kritis dibungkus pcall supaya lock selalu dilepas
	local ok, err = pcall(function()
		local _cChar, cHRP = getCharHRP(carrier)
		local _tChar, tHRP, tHum = getCharHRP(target)

		if cHRP and tHRP then
			removeCarryWeldBetween(cHRP, tHRP)
		end

		if tHum then
			tHum.PlatformStand = false
			restoreHumState(tUID, tHum)
			tHum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		restoreCarriedLight(tUID)

		local cmap = carryingByCarrier[cUID]
		if cmap then
			cmap[tUID] = nil
			if not next(cmap) then
				carryingByCarrier[cUID] = nil
				carryModeByCarrier[cUID] = nil
				animTypeByCarrier[cUID] = nil
				slotByCarrier[cUID] = nil
			end
		end

		if slotByCarrier[cUID] then slotByCarrier[cUID][tUID] = nil end
		carriedByTarget[tUID] = nil
	end)
	releaseLock(cUID)

	if not ok then
		warn("[CarryServer] detachPair error:", err)
		-- Pastikan state map konsisten walau body error
		local cmap = carryingByCarrier[cUID]
		if cmap then cmap[tUID] = nil end
		carriedByTarget[tUID] = nil
	end

	sendEndPair(carrier, target, reason)

	task.defer(function()
		if carryingByCarrier[cUID] then
			reindexSlots(carrier)
		end
		sendCarrierList(carrier)
	end)
end

local function detachAllForCarrier(carrier: Player, reason: string?)
	local cmap = carryingByCarrier[carrier.UserId]; if not cmap then return end
	local list = {}
	for _, t in pairs(cmap) do table.insert(list, t) end
	for _, t in ipairs(list) do detachPair(carrier, t, reason) end
end
local function detachIfAny(p: Player, reason: string?)
	if carriedByTarget[p.UserId] then
		detachPair(carriedByTarget[p.UserId], p, reason)
	elseif carryingByCarrier[p.UserId] then
		detachAllForCarrier(p, reason)
	end
end
local function safeDetachIfAny(p: Player, reason: string?)
	if detachGuard[p.UserId] then return end
	detachGuard[p.UserId] = true
	task.defer(function()
		detachIfAny(p, reason)
		detachGuard[p.UserId] = nil
	end)
end

-- Transfer
local function transferPassengersToAtomic(newCarrier: Player, oldCarrier: Player)
	if carryModeByCarrier[newCarrier.UserId] ~= "Multi" then
		detachAllForCarrier(oldCarrier, "transfer_solo")
		return
	end

	local oldMap = carryingByCarrier[oldCarrier.UserId]; if not oldMap then return end
	local smapOld = slotByCarrier[oldCarrier.UserId] or {}
	local arr = {}
	for tid, t in pairs(oldMap) do table.insert(arr, {t=t, s=smapOld[tid] or 999}) end
	table.sort(arr, function(a,b) return a.s < b.s end)

	local _, newHRP = getCharHRP(newCarrier)
	local _, oldHRP = getCharHRP(oldCarrier)
	if not newHRP or not oldHRP then return end

	acquireLocks(newCarrier.UserId, oldCarrier.UserId)

	local ok, err = pcall(function()
		for _, entry in ipairs(arr) do
			local t: Player = entry.t
			local tChar, tHRP, tHum = getCharHRP(t)
			if tChar and tHRP and tHum then
				local used, smNew = {}, getSlotMap(newCarrier)
				for _, idx in pairs(smNew) do used[idx] = true end
				local slotIdx
				for i = 1, MAX_CARRY_MULTI do if not used[i] then slotIdx = i break end end
				if not slotIdx then continue end

				disconnectPairCleanup(oldCarrier.UserId, t.UserId)

				removeCarryWeldBetween(oldHRP, tHRP)
				tHRP.CFrame = newHRP.CFrame * slotOffset(slotIdx)
				ensureCarryWeldBetween(newHRP, tHRP)

				tHum.PlatformStand = true
				tHum.AutoRotate = false

				local oldMap2 = carryingByCarrier[oldCarrier.UserId]
				if oldMap2 then
					oldMap2[t.UserId] = nil
					if not next(oldMap2) then
						carryingByCarrier[oldCarrier.UserId] = nil
						carryModeByCarrier[oldCarrier.UserId] = nil
						animTypeByCarrier[oldCarrier.UserId] = nil
						slotByCarrier[oldCarrier.UserId] = nil
					end
				end
				if slotByCarrier[oldCarrier.UserId] then slotByCarrier[oldCarrier.UserId][t.UserId] = nil end

				getCarryMap(newCarrier)[t.UserId] = t
				getSlotMap(newCarrier)[t.UserId] = slotIdx
				carriedByTarget[t.UserId] = newCarrier

				sendEndForCarrierOnly(oldCarrier, t, "transfer")
				local animType = animTypeByCarrier[newCarrier.UserId] or "Piggyback"
				local carryMode = carryModeByCarrier[newCarrier.UserId] or "Multi"
				sendStart(newCarrier, t, animType, carryMode)
			end
		end
	end)

	releaseLocks(newCarrier.UserId, oldCarrier.UserId)

	if not ok then
		warn("[CarryServer] transfer error:", err)
	end

	if carryingByCarrier[oldCarrier.UserId] then reindexSlots(oldCarrier) end
	sendCarrierList(newCarrier)
	sendCarrierList(oldCarrier)
end

-- Pending cleanup loop
task.spawn(function()
	while true do
		task.wait(10)
		local now = os.clock()
		for targetId, info in pairs(pending) do
			if now - info.time > PENDING_TIMEOUT then
				local target = Players:GetPlayerByUserId(targetId)
				if info.requester and info.requester.Parent == Players then
					CarryRemote:FireClient(info.requester, "RequestExpired", {targetId = targetId})
					if target and target.Parent then CarryRemote:FireClient(target, "PromptExpire", {}) end
				end
				pending[targetId] = nil
			end
		end
	end
end)

local function hasPendingIncoming(p: Player)
	return pending[p.UserId] ~= nil
end
local function hasPendingOutgoing(p: Player)
	for _, info in pairs(pending) do
		if info.requester == p then
			return true
		end
	end
	return false
end

local function cleanupPendingForRequester(p: Player)
	local toRemove = {}
	for targetId, info in pairs(pending) do
		if info.requester == p then
			table.insert(toRemove, targetId)
		end
	end
	for _, targetId in ipairs(toRemove) do
		local target = Players:GetPlayerByUserId(targetId)
		if target and target.Parent then
			CarryRemote:FireClient(target, "PromptExpire", {})
		end
		pending[targetId] = nil
	end
end

-- Start Carry
-- Catatan: semua error() memakai level 0 supaya kode error TIDAK diberi
-- prefix "script:line" oleh Lua — perbandingan string di caller jadi valid.
local function startCarry(carrier: Player, target: Player, animType: string, blueprint: Blueprint)
	local cChar, cHRP, cHum = getCharHRP(carrier)
	local tChar, tHRP, tHum = getCharHRP(target)

	if not (cChar and cHRP and cHum and tChar and tHRP and tHum) then return false, "character_missing" end

	acquireLock(carrier.UserId)

	local carryMode = blueprint.Mode

	local ok, err = pcall(function()
		if (cHRP.Position - tHRP.Position).Magnitude > MAX_DISTANCE then error("too_far", 0) end

		local currentCarryCount = countCarried(carrier)
		local currentMode = carryModeByCarrier[carrier.UserId]

		if currentMode and currentMode ~= carryMode then
			error("busy_wrong_mode", 0)
		end

		if carryMode == "Solo" and currentCarryCount >= MAX_CARRY_SOLO then
			error("busy_solo_full", 0)
		end

		if carryMode == "Multi" and currentCarryCount >= MAX_CARRY_MULTI then
			error("limit", 0)
		end

		if not targetAvailable(target) then error("busy_target", 0) end

		local extra = countCarried(target)
		if carryMode == "Multi" and (currentCarryCount + 1 + extra) > MAX_CARRY_MULTI then
			error("limit_transfer", 0)
		end

		local slotIdx
		if carryMode == "Multi" then
			local used, sm = {}, getSlotMap(carrier)
			for _, idx in pairs(sm) do used[idx] = true end
			for i = 1, MAX_CARRY_MULTI do if not used[i] then slotIdx = i break end end
			if not slotIdx then error("limit", 0) end
			tHRP.CFrame = cHRP.CFrame * slotOffset(slotIdx)
		else
			slotIdx = 1
			tHRP.CFrame = cHRP.CFrame * blueprint.CFrame
		end

		ensureCarryWeldBetween(cHRP, tHRP)

		saveHumState(target.UserId, tHum)
		tHum.AutoRotate = false
		tHum.PlatformStand = true

		if tHum.Sit then
			tHum.Sit = false
		end

		makeCarriedLight(tChar, target.UserId)

		getCarryMap(carrier)[target.UserId] = target
		getSlotMap(carrier)[target.UserId] = slotIdx
		carriedByTarget[target.UserId] = carrier
		carryModeByCarrier[carrier.UserId] = carryMode
		animTypeByCarrier[carrier.UserId] = animType

		-- Cleanup per pasangan: diputus saat detach
		local pairKey = getPairKey(carrier.UserId, target.UserId)
		disconnectPairCleanup(carrier.UserId, target.UserId)
		local conns: {RBXScriptConnection} = {}

		local function bindCleanupForPair(char: Instance, p: Player)
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				table.insert(conns, hum.Died:Connect(function()
					safeDetachIfAny(p, "death")
				end))
			end
			table.insert(conns, char.AncestryChanged:Connect(function(_, parent)
				if not parent then safeDetachIfAny(p, "character removed") end
			end))
		end
		bindCleanupForPair(cChar, carrier)
		bindCleanupForPair(tChar, target)
		pairCleanupConns[pairKey] = conns

		sendStart(carrier, target, animType, carryMode)
	end)

	releaseLock(carrier.UserId)

	if not ok then return false, tostring(err) end

	if countCarried(target) > 0 then
		transferPassengersToAtomic(carrier, target)
	end

	sendCarrierList(carrier)
	return true
end

-- Rate limit remote
local function canProcessRemote(player: Player): boolean
	local uid = player.UserId
	local now = os.clock()
	if (now - (lastRemoteAction[uid] or 0)) < REMOTE_COOLDOWN then
		return false
	end
	lastRemoteAction[uid] = now
	return true
end

CarryRemote.OnServerEvent:Connect(function(player: Player, action: string, data)
	if typeof(action) ~= "string" then return end
	if not canProcessRemote(player) then return end

	if action == "Request" then
		local targetId = data and data.targetId
		local animType = data and data.animType
		if type(targetId) ~= "number" or type(animType) ~= "string" then return end
		if #animType > 100 then return end

		local blueprint = CarryBlueprints[animType]
		if not blueprint then return end
		local carryMode = blueprint.Mode

		local target = Players:GetPlayerByUserId(targetId); if not target or target == player then return end
		local _, cHRP, cHum = getCharHRP(player)
		local _, tHRP, tHum = getCharHRP(target)

		if not (cHRP and cHum and tHRP and tHum) then return end

		if (cHRP.Position - tHRP.Position).Magnitude > MAX_DISTANCE then
			CarryRemote:FireClient(player, "TooFar", {targetId=targetId}); return
		end

		local currentCarryCount = countCarried(player)
		local currentMode = carryModeByCarrier[player.UserId]

		if currentMode and currentMode ~= carryMode then
			CarryRemote:FireClient(player, "Busy", {reason="wrong_mode"}); return
		end

		if carryMode == "Solo" and currentCarryCount >= MAX_CARRY_SOLO then
			CarryRemote:FireClient(player, "Busy", {reason="solo_full"}); return
		end

		local extra = countCarried(target)
		local maxCarry = (carryMode == "Multi") and MAX_CARRY_MULTI or MAX_CARRY_SOLO

		if (currentCarryCount + 1 + extra) > maxCarry then
			if carryMode == "Multi" and extra > 0 then
				CarryRemote:FireClient(player, "Limit", {max = maxCarry, reason = "transfer"}); return
			else
				CarryRemote:FireClient(player, "Limit", {max = maxCarry, reason = "limit"}); return
			end
		end

		if not targetAvailable(target) then
			CarryRemote:FireClient(player, "Busy", {reason="target_busy"}); return
		end

		if hasPendingIncoming(player) or hasPendingOutgoing(player) or pending[target.UserId] then
			CarryRemote:FireClient(player, "Busy", {reason="pending"}); return
		end

		pending[target.UserId] = {requester = player, time = os.clock(), animType = animType}
		CarryRemote:FireClient(target, "Prompt", {fromId = player.UserId, fromName = player.DisplayName, animType = animType})

	elseif action == "Response" then
		local accept = data and data.accept == true
		local requesterId = data and data.requesterId
		if type(requesterId) ~= "number" then return end

		local requester = Players:GetPlayerByUserId(requesterId); if not requester then return end

		local pend = pending[player.UserId]; if not pend or pend.requester ~= requester then return end
		local animType = pend.animType
		pending[player.UserId] = nil

		local blueprint = CarryBlueprints[animType]
		if not blueprint then return end

		if not accept then
			CarryRemote:FireClient(requester, "Declined", {targetId = player.UserId})
			CarryRemote:FireClient(player, "PromptClose", {})
			return
		end

		local ok2, err2 = startCarry(requester, player, animType, blueprint)

		if not ok2 then
			if tostring(err2) == "limit_transfer" then
				CarryRemote:FireClient(requester, "Limit", {max = MAX_CARRY_MULTI, reason = "transfer"})
				CarryRemote:FireClient(player, "Failed", {reason="limit_transfer"})
			else
				CarryRemote:FireClient(requester, "Failed", {reason=err2})
				CarryRemote:FireClient(player, "Failed", {reason=err2})
			end
		end

	elseif action == "Stop" then
		local targetId = data and data.targetId
		if type(targetId) == "number" then
			local t = Players:GetPlayerByUserId(targetId)
			if t and carryingByCarrier[player.UserId] and carryingByCarrier[player.UserId][targetId] then
				detachPair(player, t, "stop"); return
			end
		end
		detachIfAny(player, "stop")
	end
end)

-- Respawn
local function onCharacterAdded(p: Player, char: Model)
	task.defer(function()
		clearCarryWeldsForChar(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
			hum.AutoRotate = true
			hum.WalkSpeed = 16
			if hum.UseJumpPower then hum.JumpPower = 50 else hum.JumpHeight = 7.2 end
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum.Jump = false
		end
		savedProps[p.UserId] = nil
		savedHum[p.UserId] = nil
		safeDetachIfAny(p, "respawn")
	end)
end

local function setupPlayer(p: Player)
	p.CharacterAdded:Connect(function(char) onCharacterAdded(p, char) end)
	if p.Character then
		task.spawn(onCharacterAdded, p, p.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, p)
end

Players.PlayerRemoving:Connect(function(p: Player)
	pending[p.UserId] = nil
	cleanupPendingForRequester(p)
	detachIfAny(p, "left")

	local uid = p.UserId
	lastRemoteAction[uid] = nil
	lockMap[uid] = nil
	detachGuard[uid] = nil
	slotByCarrier[uid] = nil
	savedProps[uid] = nil
	savedHum[uid] = nil

	for key, conns in pairs(pairCleanupConns) do
		if key:match("^" .. tostring(uid) .. "_") or key:match("_" .. tostring(uid) .. "$") then
			for _, conn in ipairs(conns) do
				if conn.Connected then conn:Disconnect() end
			end
			pairCleanupConns[key] = nil
		end
	end
end)
