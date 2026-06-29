--!nonstrict
-- PhotoStoryServer: otoritas pairing. Membuat remotes, memvalidasi pasangan,
-- mengirim StartStory ke kedua client, dan membersihkan state saat selesai/keluar.
-- Trigger (pad) memanggil lewat BindableEvent internal "PhotoStoryPairRequest".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

-- ---------- Remotes (buat kalau belum ada) ----------
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
local RequestStart = ensureRemote(Remotes, "RequestStart")
local StartStory = ensureRemote(Remotes, "StartStory")
local EndStory = ensureRemote(Remotes, "EndStory")

-- BindableEvent internal: trigger pad -> server (server-to-server).
local PairRequest = ServerScriptService:FindFirstChild("PhotoStoryPairRequest")
if not PairRequest then
	PairRequest = Instance.new("BindableEvent")
	PairRequest.Name = "PhotoStoryPairRequest"
	PairRequest.Parent = ServerScriptService
end

-- ---------- State ----------
local activeByPlayer = {} -- [Player] = sessionId
local sessions = {} -- [sessionId] = { a = Player, b = Player }

local function isBusy(player)
	return activeByPlayer[player] ~= nil
end

local function endSession(sessionId)
	local data = sessions[sessionId]
	if not data then
		return
	end
	sessions[sessionId] = nil

	for _, p in ipairs({ data.a, data.b }) do
		if p and activeByPlayer[p] == sessionId then
			activeByPlayer[p] = nil
			if p.Parent then
				-- Pastikan client berhenti (mis. partner keluar).
				EndStory:FireClient(p)
			end
		end
	end
end

local function startPair(a, b)
	if not (a and b and a ~= b) then
		return
	end
	if not (a.Parent and b.Parent) then
		return
	end
	if isBusy(a) or isBusy(b) then
		return
	end

	local sessionId = HttpService:GenerateGUID(false)
	sessions[sessionId] = { a = a, b = b }
	activeByPlayer[a] = sessionId
	activeByPlayer[b] = sessionId

	local payload = {
		SessionId = sessionId,
		PlayerA = a.UserId,
		PlayerB = b.UserId,
	}
	StartStory:FireClient(a, payload)
	StartStory:FireClient(b, payload)
end

-- ---------- Hooks ----------
PairRequest.Event:Connect(function(a, b)
	startPair(a, b)
end)

-- Client memberitahu story selesai.
EndStory.OnServerEvent:Connect(function(player, sessionId)
	local current = activeByPlayer[player]
	if current and (sessionId == nil or sessionId == current) then
		endSession(current)
	end
end)

-- Opsional: player minta mulai (mis. dari UI). Server tetap butuh partner valid;
-- di sini diabaikan kecuali kamu kembangkan matchmaking sendiri.
RequestStart.OnServerEvent:Connect(function(_player)
	-- Sengaja no-op: pairing utama lewat pad/trigger. Hindari spam.
end)

Players.PlayerRemoving:Connect(function(player)
	local current = activeByPlayer[player]
	if current then
		endSession(current)
	end
end)
