-- ReplicatedStorage > QuestSystem > RateLimit
-- Fixed-window counter per-player + per-key. Panggil :Check() sebelum eksekusi handler.
--
-- CHANGES:
--   * FIX BUG: CheckConfig dulu baca cfg[1]/cfg[2] (array index), padahal
--     QuestConfig.RateLimit pakai named keys { window = , max = }. Akibatnya
--     semua limit fallback ke default 5 call/1 detik — config gak pernah
--     kepakai. Sekarang baca cfg.max/cfg.window, dengan array fallback
--     untuk backward compat.
--
-- Pakai di server:
--   if not RateLimit.Check(player, "RequestBoat", 2, 5) then return end
--   (max 2 call per 5 detik)

local Players = game:GetService("Players")

local RateLimit = {}

local _buckets = {}  -- [userId] = { [key] = { count, windowStart } }

local function bucketFor(userId, key)
	local userBuckets = _buckets[userId]
	if not userBuckets then
		userBuckets = {}
		_buckets[userId] = userBuckets
	end
	return userBuckets, userBuckets[key]
end

function RateLimit.Check(player, key, maxCalls, windowSec)
	if not (player and player.UserId) then return false end
	maxCalls = maxCalls or 5
	windowSec = windowSec or 1

	local now = os.clock()
	local userBuckets, b = bucketFor(player.UserId, key)
	if not b or (now - b.windowStart) > windowSec then
		userBuckets[key] = { count = 1, windowStart = now }
		return true
	end
	b.count = b.count + 1
	return b.count <= maxCalls
end

-- Quick helper kalau lo simpan limit-nya di config
function RateLimit.CheckConfig(player, key, configTable)
	local cfg = configTable and configTable[key]
	if not cfg then return true end
	return RateLimit.Check(player, key, cfg.max or cfg[1], cfg.window or cfg[2])
end

Players.PlayerRemoving:Connect(function(player)
	_buckets[player.UserId] = nil
end)

return RateLimit
