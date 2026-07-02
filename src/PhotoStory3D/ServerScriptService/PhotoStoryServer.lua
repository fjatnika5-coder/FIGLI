--!nonstrict
-- PhotoStoryServer: GirlPad/BoyPad detection, countdown 5-4-3-2-1, pair, freeze, StartStory.
-- PadStatus remote memberi tahu client: Waiting / Countdown / Cancel.
-- Player keluar pad = countdown cancel. Partner belum ada = tampil Waiting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("PhotoStoryConfig"))

-- ---------- Remote helpers ----------
local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end

local function ensureRemote(parent, name)
	local r = parent:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = parent
	end
	return r
end

local Remotes   = ensureFolder(ReplicatedStorage, "PhotoStoryRemotes")
local StartStory = ensureRemote(Remotes, "StartStory")
local EndStory   = ensureRemote(Remotes, "EndStory")
local PadStatus  = ensureRemote(Remotes, "PadStatus")  -- {Type, Data}

-- ---------- Pad references ----------
local padsFolder = Workspace:WaitForChild(Config.PadsFolder, 30)
local girlPad    = padsFolder and padsFolder:WaitForChild(Config.GirlPadName, 30)
local boyPad     = padsFolder and padsFolder:WaitForChild(Config.BoyPadName, 30)
if not (girlPad and boyPad) then
	warn("[PhotoStory] Pad tidak ditemukan di Workspace." .. tostring(Config.PadsFolder))
	return
end

-- ---------- State ----------
local COOLDOWN          = 4
local COUNTDOWN_SECS    = 5

local activeByPlayer = {}  -- [Player] = sessionId
local sessions       = {}  -- [sessionId] = {girl, boy, frozen}
local girlOcc        = {}  -- [Player] = count (body parts touching)
local boyOcc         = {}  -- [Player] = count
local lastStart      = 0   -- os.clock() of last startPair

-- Countdown state (single pair at a time)
local cdToken  = { cancelled = true }
local cdGirl   = nil
local cdBoy    = nil

-- ---------- Helpers ----------
local function isBusy(p)   return activeByPlayer[p] ~= nil end
local function isOnGirl(p) return girlOcc[p] and girlOcc[p] > 0 end
local function isOnBoy(p)  return boyOcc[p]  and boyOcc[p]  > 0 end

local function validChar(player)
	local char = player and player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return char, hrp, hum end
	return nil
end

local function freeze(player)
	local _, hrp, hum = validChar(player)
	if not hum then return nil end
	local st = {
		WalkSpeed = hum.WalkSpeed, JumpPower = hum.JumpPower,
		JumpHeight = hum.JumpHeight, AutoRotate = hum.AutoRotate,
		Anchored = hrp.Anchored, CFrame = hrp.CFrame,
	}
	hum.WalkSpeed = 0; hum.JumpPower = 0; hum.JumpHeight = 0
	hum.AutoRotate = false; hrp.Anchored = true
	return st
end

local function unfreeze(player, st)
	if not st then return end
	local _, hrp, hum = validChar(player)
	if hum and hrp then
		hum.WalkSpeed = st.WalkSpeed; hum.JumpPower = st.JumpPower
		hum.JumpHeight = st.JumpHeight; hum.AutoRotate = st.AutoRotate
		hrp.Anchored = st.Anchored
		pcall(function() hrp.CFrame = st.CFrame end)
	end
end

local function fireStatus(player, statusType, data)
	if player and player.Parent then
		PadStatus:FireClient(player, statusType, data)
	end
end

-- ---------- Session ----------
local function endSession(sessionId)
	local data = sessions[sessionId]
	if not data then return end
	sessions[sessionId] = nil
	for _, p in ipairs({ data.girl, data.boy }) do
		if p then
			if activeByPlayer[p] == sessionId then activeByPlayer[p] = nil end
			unfreeze(p, data.frozen and data.frozen[p])
			if p.Parent then EndStory:FireClient(p) end
		end
	end
end

local function startPair(girl, boy)
	if not (girl and boy and girl ~= boy) then return end
	if isBusy(girl) or isBusy(boy) then return end
	if not (validChar(girl) and validChar(boy)) then return end

	local sid = HttpService:GenerateGUID(false)
	local frozen = { [girl] = freeze(girl), [boy] = freeze(boy) }
	sessions[sid] = { girl = girl, boy = boy, frozen = frozen }
	activeByPlayer[girl] = sid
	activeByPlayer[boy]  = sid

	local payload = { SessionId = sid, GirlUserId = girl.UserId, BoyUserId = boy.UserId }
	StartStory:FireClient(girl, payload)
	StartStory:FireClient(boy,  payload)
end

-- ---------- Countdown ----------
local function cancelCountdown(notifyGirl, notifyBoy)
	if cdToken.cancelled then return end
	cdToken.cancelled = true
	local g, b = cdGirl, cdBoy
	cdGirl = nil; cdBoy = nil
	if notifyGirl ~= false and g and g.Parent then fireStatus(g, "Cancel") end
	if notifyBoy  ~= false and b and b.Parent then fireStatus(b, "Cancel") end
end

local function startCountdown(girl, boy)
	-- Cancel any running countdown first
	cancelCountdown()

	cdToken = { cancelled = false }
	cdGirl  = girl
	cdBoy   = boy
	local token = cdToken

	task.spawn(function()
		for i = COUNTDOWN_SECS, 1, -1 do
			if token.cancelled then return end
			fireStatus(girl, "Countdown", i)
			fireStatus(boy,  "Countdown", i)
			task.wait(1)
			if token.cancelled then return end
			-- Re-validate both still on pads and not busy
			if not (isOnGirl(girl) and isOnBoy(boy)
				and girl.Parent and boy.Parent
				and not isBusy(girl) and not isBusy(boy)) then
				-- Someone left — cancel and re-evaluate
				token.cancelled = true
				cdGirl = nil; cdBoy = nil
				-- Notify remaining waiting players
				if isOnGirl(girl) and girl.Parent and not isBusy(girl) then
					fireStatus(girl, "Cancel")
					fireStatus(girl, "Waiting")
				elseif girl.Parent then
					fireStatus(girl, "Cancel")
				end
				if isOnBoy(boy) and boy.Parent and not isBusy(boy) then
					fireStatus(boy, "Cancel")
					fireStatus(boy, "Waiting")
				elseif boy.Parent then
					fireStatus(boy, "Cancel")
				end
				return
			end
		end
		if token.cancelled then return end
		-- Countdown finished
		token.cancelled = true
		cdGirl = nil; cdBoy = nil
		-- "Start!" toast sebentar lalu mulai (validasi terakhir).
		fireStatus(girl, "Start")
		fireStatus(boy,  "Start")
		task.wait(0.4)
		if not (isOnGirl(girl) and isOnBoy(boy) and girl.Parent and boy.Parent
			and not isBusy(girl) and not isBusy(boy)) then
			if girl.Parent then fireStatus(girl, "Cancel") end
			if boy.Parent  then fireStatus(boy,  "Cancel") end
			return
		end
		if os.clock() - lastStart >= COOLDOWN then
			lastStart = os.clock()
			startPair(girl, boy)
		end
	end)
end

-- ---------- Pad status update (called on every occupancy change) ----------
local function getPadPlayers()
	local girl, boy = nil, nil
	for p, c in pairs(girlOcc) do
		if c > 0 and p.Parent and not isBusy(p) then girl = p; break end
	end
	for p, c in pairs(boyOcc) do
		if c > 0 and p.Parent and not isBusy(p) and p ~= girl then boy = p; break end
	end
	return girl, boy
end

local function updatePadStatus()
	local girl, boy = getPadPlayers()
	if girl and boy then
		-- Both present: start countdown if not already running for this pair
		if cdToken.cancelled or cdGirl ~= girl or cdBoy ~= boy then
			startCountdown(girl, boy)
		end
	else
		-- At least one missing: cancel any countdown
		if not cdToken.cancelled then
			cancelCountdown()
		end
		-- Notify waiting player
		if girl then fireStatus(girl, "Waiting") end
		if boy  then fireStatus(boy,  "Waiting") end
	end
end

-- ---------- Pad occupancy ----------
local function playerFromPart(part)
	local char = part and part.Parent
	if not char then return nil end
	if not char:FindFirstChildOfClass("Humanoid") then return nil end
	return Players:GetPlayerFromCharacter(char)
end

local function bindPad(pad, occ, role)
	pad.Touched:Connect(function(part)
		local p = playerFromPart(part)
		if not p then return end
		local prev = occ[p] or 0
		occ[p] = prev + 1
		if prev == 0 then
			-- Just stepped on pad
			updatePadStatus()
		end
	end)
	pad.TouchEnded:Connect(function(part)
		local p = playerFromPart(part)
		if not p then return end
		local c = (occ[p] or 0) - 1
		if c <= 0 then
			occ[p] = nil
			-- Player left pad
			if not cdToken.cancelled then
				-- If this player was in countdown, cancel it
				if (role == "Girl" and cdGirl == p) or (role == "Boy" and cdBoy == p) then
					cancelCountdown()
					-- Notify the other player who might still be on their pad
					local g, b = getPadPlayers()
					if g then fireStatus(g, "Waiting") end
					if b then fireStatus(b, "Waiting") end
				end
			end
			-- Send hide to the player who left
			fireStatus(p, "Hide")
		else
			occ[p] = c
		end
	end)
end

bindPad(girlPad, girlOcc, "Girl")
bindPad(boyPad,  boyOcc,  "Boy")

-- ---------- Cleanup hooks ----------
EndStory.OnServerEvent:Connect(function(player, sessionId)
	local current = activeByPlayer[player]
	if current and (sessionId == nil or sessionId == current) then
		endSession(current)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	girlOcc[player] = nil
	boyOcc[player]  = nil
	if not cdToken.cancelled and (cdGirl == player or cdBoy == player) then
		cancelCountdown()
	end
	local current = activeByPlayer[player]
	if current then endSession(current) end
end)

local function onPlayer(player)
	player.CharacterRemoving:Connect(function()
		local current = activeByPlayer[player]
		if current then
			local data = sessions[current]
			if data then data.frozen[player] = nil end
			endSession(current)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
