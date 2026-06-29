--!nonstrict
-- PhotoStoryServer: deteksi GirlPad/BoyPad, pasangkan dua player, validasi,
-- freeze keduanya, kirim StartStory ke kedua client, dan cleanup saat selesai/keluar/mati.
-- Avatar diambil otomatis dari player yang injek pad (tidak ada UserId manual).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("PhotoStoryConfig"))

-- ---------- Remotes ----------
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

local Remotes = ensureFolder(ReplicatedStorage, "PhotoStoryRemotes")
local StartStory = ensureRemote(Remotes, "StartStory")
local EndStory = ensureRemote(Remotes, "EndStory")

-- ---------- Pads ----------
local padsFolder = Workspace:WaitForChild(Config.PadsFolder, 30)
local girlPad = padsFolder and padsFolder:WaitForChild(Config.GirlPadName, 30)
local boyPad = padsFolder and padsFolder:WaitForChild(Config.BoyPadName, 30)
if not (girlPad and boyPad) then
	warn("[PhotoStory] Pad tidak ditemukan (cek Workspace." .. tostring(Config.PadsFolder) .. ")")
	return
end

-- ---------- State ----------
local COOLDOWN = 4
local activeByPlayer = {} -- [Player] = sessionId
local sessions = {} -- [sessionId] = { girl=Player, boy=Player, frozen={[Player]=stateTable} }
local girlOcc = {} -- [Player] = count di GirlPad
local boyOcc = {} -- [Player] = count di BoyPad
local lastTrigger = 0

local function isBusy(player)
	return activeByPlayer[player] ~= nil
end

local function validCharacter(player)
	local char = player and player.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return char, hrp, hum
	end
	return nil
end

local function freeze(player)
	local _, hrp, hum = validCharacter(player)
	if not hum then
		return nil
	end
	local state = {
		WalkSpeed = hum.WalkSpeed,
		JumpPower = hum.JumpPower,
		JumpHeight = hum.JumpHeight,
		AutoRotate = hum.AutoRotate,
		Anchored = hrp.Anchored,
		CFrame = hrp.CFrame,
	}
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.AutoRotate = false
	hrp.Anchored = true
	return state
end

local function unfreeze(player, state)
	if not state then
		return
	end
	local _, hrp, hum = validCharacter(player)
	if hum and hrp then
		hum.WalkSpeed = state.WalkSpeed
		hum.JumpPower = state.JumpPower
		hum.JumpHeight = state.JumpHeight
		hum.AutoRotate = state.AutoRotate
		hrp.Anchored = state.Anchored
		-- Kembalikan posisi (jaga kalau sempat tergeser).
		pcall(function()
			hrp.CFrame = state.CFrame
		end)
	end
end

local function endSession(sessionId)
	local data = sessions[sessionId]
	if not data then
		return
	end
	sessions[sessionId] = nil
	for _, p in ipairs({ data.girl, data.boy }) do
		if p then
			if activeByPlayer[p] == sessionId then
				activeByPlayer[p] = nil
			end
			unfreeze(p, data.frozen[p])
			if p.Parent then
				EndStory:FireClient(p)
			end
		end
	end
end

local function startPair(girl, boy)
	if not (girl and boy and girl ~= boy) then
		return
	end
	if isBusy(girl) or isBusy(boy) then
		return
	end
	if not (validCharacter(girl) and validCharacter(boy)) then
		return
	end

	local sessionId = HttpService:GenerateGUID(false)
	local frozen = {
		[girl] = freeze(girl),
		[boy] = freeze(boy),
	}
	sessions[sessionId] = { girl = girl, boy = boy, frozen = frozen }
	activeByPlayer[girl] = sessionId
	activeByPlayer[boy] = sessionId

	local payload = {
		SessionId = sessionId,
		GirlUserId = girl.UserId,
		BoyUserId = boy.UserId,
	}
	StartStory:FireClient(girl, payload)
	StartStory:FireClient(boy, payload)
end

local function tryStart()
	if os.clock() - lastTrigger < COOLDOWN then
		return
	end
	local girl, boy
	for p, c in pairs(girlOcc) do
		if c > 0 and p.Parent and not isBusy(p) then
			girl = p
			break
		end
	end
	for p, c in pairs(boyOcc) do
		if c > 0 and p.Parent and not isBusy(p) and p ~= girl then
			boy = p
			break
		end
	end
	if girl and boy then
		lastTrigger = os.clock()
		startPair(girl, boy)
	end
end

-- ---------- Pad occupancy ----------
local function playerFromPart(part)
	local character = part and part.Parent
	if not character then
		return nil
	end
	if not character:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function bindPad(pad, occ)
	pad.Touched:Connect(function(part)
		local p = playerFromPart(part)
		if not p then
			return
		end
		occ[p] = (occ[p] or 0) + 1
		tryStart()
	end)
	pad.TouchEnded:Connect(function(part)
		local p = playerFromPart(part)
		if not p then
			return
		end
		local c = (occ[p] or 0) - 1
		if c <= 0 then
			occ[p] = nil
		else
			occ[p] = c
		end
	end)
end

bindPad(girlPad, girlOcc)
bindPad(boyPad, boyOcc)

-- ---------- Cleanup hooks ----------
EndStory.OnServerEvent:Connect(function(player, sessionId)
	local current = activeByPlayer[player]
	if current and (sessionId == nil or sessionId == current) then
		endSession(current)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	girlOcc[player] = nil
	boyOcc[player] = nil
	local current = activeByPlayer[player]
	if current then
		endSession(current)
	end
end)

local function onPlayer(player)
	player.CharacterRemoving:Connect(function()
		-- Mati/reset saat cutscene -> akhiri sesi (state lama tidak bisa di-restore).
		local current = activeByPlayer[player]
		if current then
			local data = sessions[current]
			if data then
				data.frozen[player] = nil -- jangan coba restore char yang sudah hilang
			end
			endSession(current)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
