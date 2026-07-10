-- ModuleScript: FishingNotificationManager
-- Lokasi: ReplicatedStorage.FishingSystem.FishingModules.FishingNotificationManager
-- [PATCH v2] MAX_VISIBLE enforced, double-remove guard, raysTween safety

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local Manager = {}

-- ═══════════════════════════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════════════════════════
local CONFIG = {
	FISH_TEXT_DURATION  = 5,
	FISH_IMAGE_DURATION = 3,
	EVENT_DURATION      = 6,
	TWEEN_IN_TIME       = 0.5,
	TWEEN_OUT_TIME      = 0.4,
	MAX_VISIBLE         = 5,
}

local RARITY_COLORS = {
	["Common"]    = Color3.fromRGB(200, 200, 200),
	["Uncommon"]  = Color3.fromRGB(30,  255, 30),
	["Rare"]      = Color3.fromRGB(30,  100, 255),
	["Epic"]      = Color3.fromRGB(160, 30,  255),
	["Legendary"] = Color3.fromRGB(255, 128, 0),
	["Mitos"]     = Color3.fromRGB(170, 0,   0),
	["Secret"]    = Color3.fromRGB(85,  255, 255),
	["Unknown"]   = Color3.fromRGB(255, 0,   0),
}

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════
local screenGui         = nil
local notifFrame        = nil
local fishTextTemplate  = nil
local fishImageTemplate = nil
local eventTemplate     = nil
local activeNotifs      = {}
local initialized       = false
local localPlayer       = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════
-- INTERNAL: REMOVE NOTIF (with double-remove guard)
-- [PATCH v2] Pakai flag .removed biar nggak double-remove
-- ═══════════════════════════════════════════════════════════════
local function removeNotif(notif)
	if not notif then return end
	if notif.removed then return end  -- [PATCH v2] guard
	notif.removed = true

	for i, n in ipairs(activeNotifs) do
		if n == notif then table.remove(activeNotifs, i); break end
	end

	if notif.raysTween then
		pcall(function() notif.raysTween:Cancel() end)
		notif.raysTween = nil
	end
	if notif.tweenConnection then
		notif.tweenConnection:Disconnect()
		notif.tweenConnection = nil
	end
	if notif.frame and notif.frame.Parent then
		notif.frame:Destroy()
	end
	notif.frame = nil
end

-- ═══════════════════════════════════════════════════════════════
-- [PATCH v2] ENFORCE MAX_VISIBLE — hapus notif terlama kalau over cap
-- ═══════════════════════════════════════════════════════════════
local function enforceMaxVisible()
	while #activeNotifs >= CONFIG.MAX_VISIBLE do
		local oldest = activeNotifs[1]
		if oldest then
			removeNotif(oldest)
		else
			break
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- INTERNAL: TWEEN OUT HELPER
-- ═══════════════════════════════════════════════════════════════
local function tweenOut(notif, frame, extras)
	if notif.removed then return end  -- [PATCH v2] guard
	if not (frame and frame.Parent) then
		removeNotif(notif)
		return
	end
	local goals = { BackgroundTransparency = 1 }
	local t = TweenService:Create(frame, TweenInfo.new(CONFIG.TWEEN_OUT_TIME), goals)
	for _, extra in ipairs(extras or {}) do
		if extra.obj and extra.obj.Parent then
			TweenService:Create(extra.obj, TweenInfo.new(CONFIG.TWEEN_OUT_TIME), extra.goal):Play()
		end
	end
	t:Play()
	t.Completed:Wait()
	removeNotif(notif)
end

-- ═══════════════════════════════════════════════════════════════
-- INTERNAL: SHOW TEXT NOTIF (rarity + nama + berat)
-- ═══════════════════════════════════════════════════════════════
local function showFishText(rarity, fishName, weightStr, rarityColor)
	if not fishTextTemplate then return end
	enforceMaxVisible()  -- [PATCH v2]

	local frame = fishTextTemplate:Clone()
	frame.Visible = true
	frame.Parent = notifFrame

	local origBgTrans = frame.BackgroundTransparency
	local label       = frame:FindFirstChild("TextLabel")

	if label then
		label.RichText = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		local r = math.floor(rarityColor.R * 255)
		local g = math.floor(rarityColor.G * 255)
		local b = math.floor(rarityColor.B * 255)
		label.Text = string.format(
			'Kamu mendapatkan <font color="rgb(%d,%d,%d)"><b>%s</b></font> %s berat %s!',
			r, g, b, rarity, fishName, weightStr
		)
		local grad = label:FindFirstChild("UIGradient")
		if grad then grad:Destroy() end
	end

	frame.BackgroundTransparency = 1
	if label then label.TextTransparency = 1 end

	TweenService:Create(frame, TweenInfo.new(CONFIG.TWEEN_IN_TIME), { BackgroundTransparency = origBgTrans }):Play()
	if label then
		TweenService:Create(label, TweenInfo.new(CONFIG.TWEEN_IN_TIME), { TextTransparency = 0 }):Play()
	end

	local notif = { frame = frame, type = "fishText", createdAt = tick(), removed = false }
	table.insert(activeNotifs, notif)

	task.delay(CONFIG.FISH_TEXT_DURATION, function()
		tweenOut(notif, frame, label and {{ obj = label, goal = { TextTransparency = 1 } }} or {})
	end)
	return notif
end

-- ═══════════════════════════════════════════════════════════════
-- INTERNAL: SHOW IMAGE NOTIF (gambar ikan + rays)
-- ═══════════════════════════════════════════════════════════════
local function showFishImage(rarityColor, imageId)
	if not fishImageTemplate then return end
	enforceMaxVisible()  -- [PATCH v2]

	local frame    = fishImageTemplate:Clone()
	frame.Visible  = true
	frame.Parent   = notifFrame

	local origBgTrans   = frame.BackgroundTransparency
	local innerFrame    = frame:FindFirstChild("Frame")
	if not innerFrame then frame:Destroy(); return end

	local origInnerTrans = innerFrame.BackgroundTransparency
	local rays           = innerFrame:FindFirstChild("Rays")
	local vector         = innerFrame:FindFirstChild("Vector")

	if vector and imageId then
		vector.Image    = imageId
		vector.Rotation = 0
	end
	if rays then
		rays.ImageColor3 = rarityColor
		rays.Rotation    = 0
	end

	frame.BackgroundTransparency        = 1
	innerFrame.BackgroundTransparency   = 1
	if rays   then rays.ImageTransparency   = 1 end
	if vector then vector.ImageTransparency = 1 end

	TweenService:Create(frame,      TweenInfo.new(CONFIG.TWEEN_IN_TIME), { BackgroundTransparency = origBgTrans }):Play()
	TweenService:Create(innerFrame, TweenInfo.new(CONFIG.TWEEN_IN_TIME), { BackgroundTransparency = origInnerTrans }):Play()
	if vector then TweenService:Create(vector, TweenInfo.new(CONFIG.TWEEN_IN_TIME), { ImageTransparency = 0 }):Play() end
	if rays   then TweenService:Create(rays,   TweenInfo.new(CONFIG.TWEEN_IN_TIME), { ImageTransparency = 0.5 }):Play() end

	-- [PATCH v2] raysTween — tetap infinite tapi di-track buat cleanup
	local raysTween = nil
	if rays then
		raysTween = TweenService:Create(rays,
			TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 })
		raysTween:Play()
	end

	if vector then
		task.spawn(function()
			task.wait(0.3)
			-- [PATCH v2] Guard: cek frame masih ada sebelum animate
			if not (frame and frame.Parent) then return end
			local t1 = TweenService:Create(vector, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = 15 })
			t1:Play(); t1.Completed:Wait()
			if not (frame and frame.Parent) then return end
			local t2 = TweenService:Create(vector, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = -15 })
			t2:Play(); t2.Completed:Wait()
			if not (frame and frame.Parent) then return end
			TweenService:Create(vector, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Rotation = 0 }):Play()
		end)
	end

	local notif = { frame = frame, type = "fishImage", createdAt = tick(), raysTween = raysTween, removed = false }
	table.insert(activeNotifs, notif)

	task.delay(CONFIG.FISH_IMAGE_DURATION, function()
		if notif.removed then return end  -- [PATCH v2] guard
		if not (notif.frame and notif.frame.Parent) then
			removeNotif(notif)
			return
		end
		if raysTween then pcall(function() raysTween:Cancel() end) end
		local t = TweenService:Create(frame, TweenInfo.new(CONFIG.TWEEN_OUT_TIME), { BackgroundTransparency = 1 })
		TweenService:Create(innerFrame, TweenInfo.new(CONFIG.TWEEN_OUT_TIME), { BackgroundTransparency = 1 }):Play()
		if vector then TweenService:Create(vector, TweenInfo.new(CONFIG.TWEEN_OUT_TIME), { ImageTransparency = 1 }):Play() end
		if rays   then TweenService:Create(rays,   TweenInfo.new(CONFIG.TWEEN_OUT_TIME), { ImageTransparency = 1 }):Play() end
		t:Play(); t.Completed:Wait()
		removeNotif(notif)
	end)
	return notif
end

-- ═══════════════════════════════════════════════════════════════
-- INTERNAL: SHOW EVENT FRAME
-- ═══════════════════════════════════════════════════════════════
local function showEventFrame(text, duration, color)
	if not eventTemplate then return end
	enforceMaxVisible()  -- [PATCH v2]

	local frame = eventTemplate:Clone()
	frame.Visible = true
	if color then frame.BackgroundColor3 = color end
	frame.Parent = notifFrame

	local origBgTrans = frame.BackgroundTransparency
	local label       = frame:FindFirstChild("TextLabel")
	if label then
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text       = text
	end

	frame.BackgroundTransparency = 1
	if label then label.TextTransparency = 1 end

	TweenService:Create(frame, TweenInfo.new(CONFIG.TWEEN_IN_TIME), { BackgroundTransparency = origBgTrans }):Play()
	if label then
		TweenService:Create(label, TweenInfo.new(CONFIG.TWEEN_IN_TIME), { TextTransparency = 0 }):Play()
	end

	local notif = { frame = frame, type = "event", createdAt = tick(), removed = false }
	table.insert(activeNotifs, notif)

	task.delay(duration or CONFIG.EVENT_DURATION, function()
		tweenOut(notif, frame, label and {{ obj = label, goal = { TextTransparency = 1 } }} or {})
	end)
	return notif
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC: INITIALIZE
-- ═══════════════════════════════════════════════════════════════
function Manager.Initialize(_, playerGui)
	if initialized then return true end

	local gui = (playerGui or localPlayer:WaitForChild("PlayerGui")):WaitForChild("FishingNotifications", 10)
	if not gui then
		warn("[FishingNotificationManager] FishingNotifications ScreenGui tidak ditemukan!")
		return false
	end

	local screen = gui:WaitForChild("Screen", 5)
	if not screen then warn("[FishingNotificationManager] Screen frame tidak ditemukan!"); return false end

	notifFrame = screen:WaitForChild("NotificationsFrame", 5)
	if not notifFrame then warn("[FishingNotificationManager] NotificationsFrame tidak ditemukan!"); return false end

	fishTextTemplate  = notifFrame:WaitForChild("FishFrame",      5)
	fishImageTemplate = notifFrame:WaitForChild("FishImageFrame", 5)
	eventTemplate     = notifFrame:WaitForChild("EventFrame",     5)

	if not fishTextTemplate  then warn("[FishingNotificationManager] FishFrame template tidak ditemukan!");      return false end
	if not fishImageTemplate then warn("[FishingNotificationManager] FishImageFrame template tidak ditemukan!"); return false end
	if not eventTemplate     then warn("[FishingNotificationManager] EventFrame template tidak ditemukan!");     return false end

	fishTextTemplate.Visible  = false
	fishImageTemplate.Visible = false
	eventTemplate.Visible     = false

	initialized = true
	print("[FishingNotificationManager] ✅ Initialized!")
	return true
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC: SHOW FISH CATCH POPUP
-- ═══════════════════════════════════════════════════════════════
function Manager.ShowFishCatch(_, fishData)
	if not initialized then return end
	if not fishData then return end

	local fishName  = fishData.name   or "Unknown Fish"
	local rarity    = fishData.rarity or "Common"
	local imageId   = fishData.icon   or "rbxassetid://0"
	local weight    = fishData.weight

	if not weight or weight == 0 then
		local defaults = {
			Common = 1.0, Uncommon = 2.0, Rare = 4.0,
			Epic = 7.0, Legendary = 12.0, Mitos = 20.0,
			Secret = 15.0, Unknown = 25.0,
		}
		weight = defaults[rarity] or 1.0
	end

	local weightStr   = string.format("%.1f kg", math.floor(weight * 10 + 0.5) / 10)
	local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)

	showFishText(rarity, fishName, weightStr, rarityColor)
	task.delay(0.15, function()
		showFishImage(rarityColor, imageId)
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC: SHOW EVENT NOTIF
-- ═══════════════════════════════════════════════════════════════
function Manager.ShowEvent(_, text, duration, color)
	if not initialized then return end
	showEventFrame(text, duration, color)
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC: SHOW GIFT NOTIF
-- ═══════════════════════════════════════════════════════════════
function Manager.ShowGift(_, senderName, giftName)
	if not initialized then return end
	local text = string.format(
		'🎁 You received \'%s\' from <font color="rgb(85,255,127)"><b>%s</b></font>!',
		giftName, senderName
	)
	showEventFrame(text, 8, nil)
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC: CLEANUP
-- ═══════════════════════════════════════════════════════════════
function Manager.Cleanup(_)
	-- [PATCH v2] Iterate copy supaya nggak corrupt
	local copy = table.clone(activeNotifs)
	for _, notif in ipairs(copy) do
		removeNotif(notif)
	end
	activeNotifs = {}
end

return Manager