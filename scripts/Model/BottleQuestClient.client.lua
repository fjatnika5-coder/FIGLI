--[[
	BottleQuestClient V5 (LocalScript)
	Location: StarterPlayer.StarterPlayerScripts.BottleQuestClient

	CHANGELOG V5 (from V4):
	═══════════════════════════════════════════════════════════════

	[V5-1] Removed all expiry/grace period UI logic (isExpiring, timeLeft).
	       Codes never expire now — no countdown, no "CLAIM NOW" warning.
	       Code cards show rod name + "Use" button only.

	[V5-2] Kept all V4 bug fixes:
	       - CBFIX 1: copy code fallback (auto-fill Quest Board)
	       - CMLFIX 1: character ChildAdded tracking
	       - CMLFIX 2: toast connection cleanup

	═══════════════════════════════════════════════════════════════
]]

local Players                = game:GetService("Players")
local ReplicatedStorage      = game:GetService("ReplicatedStorage")
local TweenService           = game:GetService("TweenService")
local UserInputService       = game:GetService("UserInputService")
local CollectionService      = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FishingSystem     = ReplicatedStorage:WaitForChild("FishingSystem")
local BottleQuestConfig = require(FishingSystem:WaitForChild("BottleQuestConfig"))

local LANG = BottleQuestConfig.GetLang(player)
local function L(key) return BottleQuestConfig.SL(LANG, key) end

-- ═══════════════════════════════════════════════════════════════
-- SOUND SETUP
-- ═══════════════════════════════════════════════════════════════
local SOUNDS = {
	fake  = {
		{ id = "rbxassetid://83515977142116", volume = 0.4 },
		{ id = "rbxassetid://93661667012611", volume = 0.4 },
		{ id = "rbxassetid://83515977142116", volume = 0.4 },
	},
	real  = { { id = "rbxassetid://134711305341613", volume = 1.0 } },
	found = { { id = "rbxassetid://6494675393",      volume = 0.6 } },
}

local soundContainer = Instance.new("Folder")
soundContainer.Name   = "BottleQuestSounds"
soundContainer.Parent = playerGui

local function createSound(soundData)
	local s = Instance.new("Sound")
	s.SoundId            = soundData.id
	s.Volume             = soundData.volume or 0.8
	s.RollOffMaxDistance = 0
	s.Parent             = soundContainer
	return s
end

local loadedSounds = { fake = {}, real = {}, found = {} }
for soundType, list in pairs(SOUNDS) do
	for _, data in ipairs(list) do
		if data.id ~= "" and not data.id:find("GANTI") then
			table.insert(loadedSounds[soundType], createSound(data))
		end
	end
end

local lastFakeIdx = 0
local function playSound(soundType)
	local list = loadedSounds[soundType]
	if not list or #list == 0 then return end
	local idx
	if soundType == "fake" and #list > 1 then
		repeat idx = math.random(1, #list) until idx ~= lastFakeIdx
		lastFakeIdx = idx
	else
		idx = math.random(1, #list)
	end
	local s = list[idx]
	if s then s:Stop(); s:Play() end
end

local function stopAllSounds()
	for _, list in pairs(loadedSounds) do
		for _, s in ipairs(list) do s:Stop() end
	end
end

-- ═══════════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════════
local remoteFolder = FishingSystem:WaitForChild("BottleQuestRemotes", 30)
if not remoteFolder then warn("[BottleQuestClient] BottleQuestRemotes not found!"); return end

local OpenBottleRemote   = remoteFolder:WaitForChild("OpenBottle")
local ClaimCodeRemote    = remoteFolder:WaitForChild("ClaimCode")
local GetQuestInfoRemote = remoteFolder:WaitForChild("GetQuestInfo")
local BottleEventRemote  = remoteFolder:WaitForChild("BottleEventUpdate", 10)

-- ═══════════════════════════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════════════════════════
local gui = playerGui:WaitForChild("BottleQuestGUI", 30)
if not gui then warn("[BottleQuestClient] BottleQuestGUI not found!"); return end

local UI      = BottleQuestConfig.UI
local Overlay = gui:WaitForChild("Overlay")

local BLFrame           = gui:WaitForChild("BottleLetterFrame")
local BL_TitleLabel     = BLFrame:WaitForChild("TitleBar"):WaitForChild("TitleLabel")
local BL_CloseBtn       = BLFrame:WaitForChild("TitleBar"):WaitForChild("CloseButton")
local BL_Content        = BLFrame:WaitForChild("ContentArea")
local BL_TypeLabel      = BL_Content:WaitForChild("BottleTypeLabel")
local BL_LetterTitle    = BL_Content:WaitForChild("LetterTitle")
local BL_LetterBody     = BL_Content:WaitForChild("LetterScroll"):WaitForChild("LetterBody")
local BL_CashGivenLabel = BL_Content:WaitForChild("CashGivenLabel")
local BL_CodeSection    = BL_Content:WaitForChild("CodeSection")
local BL_RodRewardLabel = BL_CodeSection:WaitForChild("RodRewardLabel")
local BL_CodeText       = BL_CodeSection:WaitForChild("CodeDisplay"):WaitForChild("CodeText")
local BL_CopyBtn        = BL_CodeSection:WaitForChild("CopyCodeButton")
local BL_CloseBottomBtn = BL_Content:WaitForChild("CloseBottomButton")

local QBFrame        = gui:WaitForChild("QuestBoardFrame")
local QB_CloseBtn    = QBFrame:WaitForChild("TitleBar"):WaitForChild("CloseButton")
local QB_Content     = QBFrame:WaitForChild("ContentArea")
local QB_TabBar      = QB_Content:WaitForChild("TabBar")
local QB_TabQuest    = QB_TabBar:WaitForChild("TabQuest")
local QB_TabClaim    = QB_TabBar:WaitForChild("TabClaim")
local QB_TabHistory  = QB_TabBar:WaitForChild("TabHistory")
local QB_Pages       = QB_Content:WaitForChild("ContentPages")
local QB_QuestPage   = QB_Pages:WaitForChild("QuestPage")
local QB_ClaimPage   = QB_Pages:WaitForChild("ClaimPage")
local QB_HistoryPage = QB_Pages:WaitForChild("HistoryPage")

local QB_StatsFrame       = QB_QuestPage:WaitForChild("StatsFrame")
local QB_CodeInput        = QB_ClaimPage:WaitForChild("CodeInputFrame"):WaitForChild("CodeInput")
local QB_ClaimBtn         = QB_ClaimPage:WaitForChild("ClaimButton")
local QB_ClaimResult      = QB_ClaimPage:WaitForChild("ClaimResult")
local QB_ActiveCodesTitle = QB_ClaimPage:WaitForChild("ActiveCodesTitle")
local QB_ActiveCodesList  = QB_ClaimPage:WaitForChild("ActiveCodesScroll")
local QB_HistoryScroll    = QB_HistoryPage:WaitForChild("HistoryScroll")

local NotifFrame = gui:WaitForChild("NotificationFrame")
local NotifIcon  = NotifFrame:WaitForChild("NotifIcon")
local NotifText  = NotifFrame:WaitForChild("NotifText")

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════
local isLetterOpen  = false
local isBoardOpen   = false
local currentTab    = "quest"
local isAnimating   = false
local openingBottle = false
local charChildAddedConn = nil

-- ═══════════════════════════════════════════════════════════════
-- TWEEN HELPERS
-- ═══════════════════════════════════════════════════════════════
local function tween(obj, props, dur, style, dir)
	if not obj then return end
	local t = TweenService:Create(obj, TweenInfo.new(dur or 0.3, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props)
	t:Play(); return t
end

local function showFrame(frame)
	if not frame then return end
	isAnimating = true
	Overlay.Visible = true; Overlay.BackgroundTransparency = 1
	tween(Overlay, { BackgroundTransparency = 0.4 }, 0.25)
	frame.Visible = true; frame.GroupTransparency = 1
	local origSize = frame.Size
	frame.Size = UDim2.new(origSize.X.Scale * 0.85, origSize.X.Offset, origSize.Y.Scale * 0.85, origSize.Y.Offset)
	tween(frame, { Size = origSize, GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(0.3, function() isAnimating = false end)
end

local function hideFrame(frame, callback)
	if not frame then return end
	isAnimating = true
	tween(Overlay, { BackgroundTransparency = 1 }, 0.2)
	tween(frame, { GroupTransparency = 1 }, 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	task.delay(0.2, function()
		frame.Visible = false; Overlay.Visible = false; isAnimating = false
		if callback then callback() end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- NOTIFICATION
-- ═══════════════════════════════════════════════════════════════
local notifQueue   = {}
local showingNotif = false

local function showNotification(text, icon, duration)
	table.insert(notifQueue, { text = text, icon = icon or "", duration = duration or 4 })
	if showingNotif then return end
	showingNotif = true
	task.spawn(function()
		while #notifQueue > 0 do
			local n = table.remove(notifQueue, 1)
			NotifIcon.Text = n.icon; NotifText.Text = n.text
			NotifFrame.Visible = true
			NotifFrame.Position = UDim2.new(0.5, 0, 0, -70); NotifFrame.GroupTransparency = 1
			tween(NotifFrame, { Position = UDim2.new(0.5, 0, 0, 20), GroupTransparency = 0 }, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			task.wait(n.duration)
			tween(NotifFrame, { Position = UDim2.new(0.5, 0, 0, -70), GroupTransparency = 1 }, 0.3)
			task.wait(0.35); NotifFrame.Visible = false
		end
		showingNotif = false
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- EVENT UI
-- ═══════════════════════════════════════════════════════════════
local C = {
	black = Color3.fromRGB(10,10,10), white = Color3.fromRGB(245,245,245),
	gray100 = Color3.fromRGB(232,232,232), gray300 = Color3.fromRGB(170,170,170),
	gray500 = Color3.fromRGB(85,85,85), gray700 = Color3.fromRGB(34,34,34),
	borderFaint = Color3.fromRGB(40,40,40), borderBright = Color3.fromRGB(80,80,80),
	urgent = Color3.fromRGB(220,90,90),
}

local eventGui = Instance.new("ScreenGui")
eventGui.Name = "BottleEventUI"; eventGui.DisplayOrder = 20; eventGui.ResetOnSpawn = false
eventGui.IgnoreGuiInset = true; eventGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
eventGui.Parent = playerGui

local bannerFrame = Instance.new("Frame")
bannerFrame.Name = "EventBanner"; bannerFrame.Size = UDim2.new(0, 380, 0, 56)
bannerFrame.Position = UDim2.new(0.5, -190, 0, -70); bannerFrame.BackgroundColor3 = C.black
bannerFrame.BorderSizePixel = 0; bannerFrame.Visible = false; bannerFrame.ZIndex = 10
bannerFrame.Parent = eventGui

local bannerCorner = Instance.new("UICorner"); bannerCorner.CornerRadius = UDim.new(0, 4); bannerCorner.Parent = bannerFrame
local bannerStroke = Instance.new("UIStroke"); bannerStroke.Color = C.borderBright; bannerStroke.Thickness = 1; bannerStroke.Parent = bannerFrame

local bannerTopLine = Instance.new("Frame")
bannerTopLine.Size = UDim2.new(0.6, 0, 0, 1); bannerTopLine.Position = UDim2.new(0.2, 0, 0, 0)
bannerTopLine.BackgroundColor3 = C.white; bannerTopLine.BorderSizePixel = 0; bannerTopLine.ZIndex = 11; bannerTopLine.Parent = bannerFrame

local bannerIcon = Instance.new("TextLabel")
bannerIcon.Size = UDim2.new(0, 36, 1, 0); bannerIcon.Position = UDim2.new(0, 10, 0, 0)
bannerIcon.BackgroundTransparency = 1; bannerIcon.Text = "🍾"; bannerIcon.TextSize = 20
bannerIcon.Font = Enum.Font.GothamBold; bannerIcon.ZIndex = 11; bannerIcon.Parent = bannerFrame

local bannerTitle = Instance.new("TextLabel")
bannerTitle.Size = UDim2.new(0, 180, 0, 22); bannerTitle.Position = UDim2.new(0, 46, 0, 6)
bannerTitle.BackgroundTransparency = 1; bannerTitle.Text = L("event.title")
bannerTitle.TextColor3 = C.white; bannerTitle.TextSize = 14; bannerTitle.Font = Enum.Font.GothamBold
bannerTitle.TextXAlignment = Enum.TextXAlignment.Left; bannerTitle.ZIndex = 11; bannerTitle.Parent = bannerFrame

local bannerSub = Instance.new("TextLabel")
bannerSub.Size = UDim2.new(0, 200, 0, 16); bannerSub.Position = UDim2.new(0, 46, 0, 30)
bannerSub.BackgroundTransparency = 1; bannerSub.Text = L("event.subtitle")
bannerSub.TextColor3 = C.gray300; bannerSub.TextSize = 10; bannerSub.Font = Enum.Font.GothamMedium
bannerSub.TextXAlignment = Enum.TextXAlignment.Left; bannerSub.ZIndex = 11; bannerSub.Parent = bannerFrame

local bannerCountdown = Instance.new("TextLabel")
bannerCountdown.Size = UDim2.new(0, 60, 0, 28); bannerCountdown.Position = UDim2.new(1, -70, 0, 6)
bannerCountdown.BackgroundTransparency = 1; bannerCountdown.Text = "5:00"; bannerCountdown.TextColor3 = C.white
bannerCountdown.TextSize = 20; bannerCountdown.Font = Enum.Font.Code
bannerCountdown.TextXAlignment = Enum.TextXAlignment.Right; bannerCountdown.ZIndex = 11; bannerCountdown.Parent = bannerFrame

local bannerRemLabel = Instance.new("TextLabel")
bannerRemLabel.Size = UDim2.new(0, 60, 0, 14); bannerRemLabel.Position = UDim2.new(1, -70, 0, 36)
bannerRemLabel.BackgroundTransparency = 1; bannerRemLabel.Text = L("event.remaining")
bannerRemLabel.TextColor3 = C.gray500; bannerRemLabel.TextSize = 9; bannerRemLabel.Font = Enum.Font.GothamMedium
bannerRemLabel.TextXAlignment = Enum.TextXAlignment.Right; bannerRemLabel.ZIndex = 11; bannerRemLabel.Parent = bannerFrame

local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(1, 0, 0, 2); progressTrack.Position = UDim2.new(0, 0, 1, -2)
progressTrack.BackgroundColor3 = C.gray700; progressTrack.BorderSizePixel = 0; progressTrack.ZIndex = 11; progressTrack.Parent = bannerFrame

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(1, 0, 1, 0); progressFill.BackgroundColor3 = C.white
progressFill.BorderSizePixel = 0; progressFill.ZIndex = 12; progressFill.Parent = progressTrack

-- ── ROD TOAST ──
local toastContainer = Instance.new("Frame")
toastContainer.Name = "ToastContainer"; toastContainer.Size = UDim2.new(0, 340, 1, 0)
toastContainer.Position = UDim2.new(1, -356, 0, 0); toastContainer.BackgroundTransparency = 1
toastContainer.BorderSizePixel = 0; toastContainer.ZIndex = 20; toastContainer.Parent = eventGui

local toastLayout = Instance.new("UIListLayout"); toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom; toastLayout.Padding = UDim.new(0, 6); toastLayout.Parent = toastContainer

local toastPadding = Instance.new("UIPadding"); toastPadding.PaddingBottom = UDim.new(0, 20); toastPadding.Parent = toastContainer

local toastCount = 0

local function createRodToast(playerName, rodName)
	toastCount += 1
	local toast = Instance.new("Frame")
	toast.Name = "Toast_" .. toastCount; toast.Size = UDim2.new(1, 0, 0, 64)
	toast.BackgroundColor3 = C.black; toast.BorderSizePixel = 0; toast.LayoutOrder = -toastCount
	toast.ZIndex = 21; toast.Parent = toastContainer

	Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 4)
	local ts = Instance.new("UIStroke"); ts.Color = C.borderBright; ts.Thickness = 1; ts.Parent = toast

	local leftLine = Instance.new("Frame"); leftLine.Size = UDim2.new(0, 2, 0.7, 0)
	leftLine.Position = UDim2.new(0, 0, 0.15, 0); leftLine.BackgroundColor3 = C.white
	leftLine.BorderSizePixel = 0; leftLine.ZIndex = 22; leftLine.Parent = toast

	local iconBox = Instance.new("Frame"); iconBox.Size = UDim2.new(0, 36, 0, 36)
	iconBox.Position = UDim2.new(0, 14, 0.5, -18); iconBox.BackgroundColor3 = C.gray700
	iconBox.BorderSizePixel = 0; iconBox.ZIndex = 22; iconBox.Parent = toast
	Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 3)
	local ibs = Instance.new("UIStroke"); ibs.Color = C.borderBright; ibs.Thickness = 1; ibs.Parent = iconBox

	local iconLabel = Instance.new("TextLabel"); iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1; iconLabel.Text = "🍾"; iconLabel.TextSize = 18
	iconLabel.Font = Enum.Font.GothamBold; iconLabel.ZIndex = 23; iconLabel.Parent = iconBox

	local toastCategory = Instance.new("TextLabel")
	toastCategory.Size = UDim2.new(1, -120, 0, 14); toastCategory.Position = UDim2.new(0, 58, 0, 10)
	toastCategory.BackgroundTransparency = 1; toastCategory.Text = L("toast.category")
	toastCategory.TextColor3 = C.gray500; toastCategory.TextSize = 9; toastCategory.Font = Enum.Font.GothamMedium
	toastCategory.TextXAlignment = Enum.TextXAlignment.Left; toastCategory.ZIndex = 22; toastCategory.Parent = toast

	local toastMain = Instance.new("TextLabel")
	toastMain.Size = UDim2.new(1, -120, 0, 18); toastMain.Position = UDim2.new(0, 58, 0, 24)
	toastMain.BackgroundTransparency = 1; toastMain.Text = string.format(L("toast.obtained"), playerName, rodName)
	toastMain.TextColor3 = C.white; toastMain.TextSize = 12; toastMain.Font = Enum.Font.GothamBold
	toastMain.TextXAlignment = Enum.TextXAlignment.Left; toastMain.TextTruncate = Enum.TextTruncate.AtEnd
	toastMain.ZIndex = 22; toastMain.Parent = toast

	local toastSub = Instance.new("TextLabel")
	toastSub.Size = UDim2.new(1, -120, 0, 14); toastSub.Position = UDim2.new(0, 58, 0, 42)
	toastSub.BackgroundTransparency = 1; toastSub.Text = L("toast.source")
	toastSub.TextColor3 = C.gray500; toastSub.TextSize = 9; toastSub.Font = Enum.Font.GothamMedium
	toastSub.TextXAlignment = Enum.TextXAlignment.Left; toastSub.ZIndex = 22; toastSub.Parent = toast

	local dismissBtn = Instance.new("TextButton")
	dismissBtn.Size = UDim2.new(0, 20, 0, 20); dismissBtn.Position = UDim2.new(1, -28, 0, 8)
	dismissBtn.BackgroundColor3 = C.gray700; dismissBtn.BorderSizePixel = 0; dismissBtn.Text = "x"
	dismissBtn.TextColor3 = C.gray500; dismissBtn.TextSize = 10; dismissBtn.Font = Enum.Font.GothamMedium
	dismissBtn.ZIndex = 23; dismissBtn.Parent = toast
	Instance.new("UICorner", dismissBtn).CornerRadius = UDim.new(0, 3)

	toast.Position = UDim2.new(1, 20, 0, 0); toast.BackgroundTransparency = 1
	task.wait(0.05)
	toast.Position = UDim2.new(0, 0, 0, 0)
	tween(toast, { BackgroundTransparency = 0 }, 0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

	local toastConns = {}
	table.insert(toastConns, dismissBtn.MouseEnter:Connect(function()
		tween(dismissBtn, { BackgroundColor3 = C.borderBright, TextColor3 = C.white }, 0.15)
	end))
	table.insert(toastConns, dismissBtn.MouseLeave:Connect(function()
		tween(dismissBtn, { BackgroundColor3 = C.gray700, TextColor3 = C.gray500 }, 0.15)
	end))

	local function dismissToast()
		for _, conn in ipairs(toastConns) do
			if conn and conn.Connected then conn:Disconnect() end
		end
		table.clear(toastConns)
		tween(toast, { BackgroundTransparency = 1 }, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		task.delay(0.3, function() if toast and toast.Parent then toast:Destroy() end end)
	end
	table.insert(toastConns, dismissBtn.MouseButton1Click:Connect(dismissToast))
	task.delay(8, function() if toast and toast.Parent then dismissToast() end end)
end

-- ── EVENT STATE ──
local eventActive     = false
local eventEndTime    = 0
local countdownThread = nil

local function formatTime(s)
	return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

local function showEventBanner(duration)
	eventActive  = true
	eventEndTime = tick() + duration
	bannerFrame.Visible  = true
	bannerFrame.Position = UDim2.new(0.5, -190, 0, -70)
	bannerStroke.Color = C.borderBright; bannerTitle.TextColor3 = C.white
	bannerSub.TextColor3 = C.gray300; bannerSub.Text = L("event.subtitle")
	bannerCountdown.TextColor3 = C.white; progressFill.BackgroundColor3 = C.white
	bannerRemLabel.Text = L("event.remaining")
	tween(bannerFrame, { Position = UDim2.new(0.5, -190, 0, 16) }, 0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	if countdownThread then task.cancel(countdownThread) end
	countdownThread = task.spawn(function()
		local totalDur = duration
		while eventActive do
			local remaining = math.max(0, eventEndTime - tick())
			local pct = remaining / totalDur
			bannerCountdown.Text = formatTime(remaining)
			progressFill.Size = UDim2.new(math.max(pct, 0), 0, 1, 0)
			if remaining <= 30 and remaining > 0 then
				bannerStroke.Color = C.urgent; bannerCountdown.TextColor3 = C.urgent
				bannerTitle.TextColor3 = C.gray100
				bannerSub.Text = L("event.ending_soon"); bannerSub.TextColor3 = C.urgent
				progressFill.BackgroundColor3 = C.urgent
			end
			if remaining <= 0 then break end
			task.wait(0.5)
		end
	end)
end

local function hideEventBanner()
	eventActive = false
	if countdownThread then task.cancel(countdownThread); countdownThread = nil end
	tween(bannerFrame, { Position = UDim2.new(0.5, -190, 0, -70) }, 0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	task.delay(0.4, function()
		bannerFrame.Visible = false
		bannerStroke.Color = C.borderBright; bannerTitle.TextColor3 = C.white
		bannerSub.TextColor3 = C.gray300; bannerSub.Text = L("event.subtitle")
		bannerCountdown.TextColor3 = C.white; progressFill.BackgroundColor3 = C.white
	end)
end

if BottleEventRemote then
	BottleEventRemote.OnClientEvent:Connect(function(action, duration)
		if action == "start" then
			showEventBanner(duration or 300)
			showNotification(L("event.started"), "", 5)
		elseif action == "stop" then
			hideEventBanner()
			showNotification(L("event.ended"), "", 3)
		elseif action == "rod_claim" then
			if typeof(duration) == "table" then
				createRodToast(duration.playerName or "Someone", duration.rodName or "a Rod")
			end
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- UI HELPERS
-- ═══════════════════════════════════════════════════════════════
local function clearList(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end
end

local function ensureListLayout(parent, padding)
	if not parent:FindFirstChildOfClass("UIListLayout") then
		local l = Instance.new("UIListLayout"); l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, padding or 4); l.Parent = parent
	end
	if not parent:FindFirstChildOfClass("UIPadding") then
		local p = Instance.new("UIPadding")
		p.PaddingTop = UDim.new(0, 4); p.PaddingBottom = UDim.new(0, 4)
		p.PaddingLeft = UDim.new(0, 4); p.PaddingRight = UDim.new(0, 4); p.Parent = parent
	end
end

local function formatNum(num)
	return tostring(num):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function createStatRow(parent, label, value, order)
	local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 32)
	f.BackgroundColor3 = UI.colors.panelHighlight; f.BorderSizePixel = 0; f.LayoutOrder = order; f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0.6, -8, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = UI.colors.textSecondary
	lbl.TextSize = 12; lbl.Font = Enum.Font.GothamMedium; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f
	local val = Instance.new("TextLabel"); val.Size = UDim2.new(0.4, -10, 1, 0); val.Position = UDim2.new(0.6, 0, 0, 0)
	val.BackgroundTransparency = 1; val.Text = tostring(value); val.TextColor3 = UI.colors.textPrimary
	val.TextSize = 13; val.Font = Enum.Font.GothamBold; val.TextXAlignment = Enum.TextXAlignment.Right; val.Parent = f
end

-- [V5-1] Simplified code card — no expiry, no countdown
local function createCodeCard(parent, info, order)
	local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 56)
	f.BackgroundColor3 = UI.colors.codeBackground; f.BorderSizePixel = 0; f.LayoutOrder = order; f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	local s = Instance.new("UIStroke"); s.Color = UI.colors.codeBorder; s.Thickness = 1; s.Parent = f

	local code = Instance.new("TextLabel"); code.Size = UDim2.new(0.6, -8, 0, 22); code.Position = UDim2.new(0, 10, 0, 6)
	code.BackgroundTransparency = 1; code.Text = info.code; code.TextColor3 = UI.colors.codeText
	code.TextSize = 15; code.Font = Enum.Font.Code; code.TextXAlignment = Enum.TextXAlignment.Left; code.Parent = f

	local rod = Instance.new("TextLabel"); rod.Size = UDim2.new(1, -20, 0, 16); rod.Position = UDim2.new(0, 10, 0, 30)
	rod.BackgroundTransparency = 1; rod.Text = "ROD: " .. (info.rodName or "Unknown Rod")
	rod.TextColor3 = UI.colors.accent; rod.TextSize = 11; rod.Font = Enum.Font.GothamMedium
	rod.TextXAlignment = Enum.TextXAlignment.Left; rod.Parent = f

	-- "Use" button — auto-fill kode ke input
	local useBtn = Instance.new("TextButton"); useBtn.Size = UDim2.new(0.25, 0, 0, 20); useBtn.Position = UDim2.new(0.73, 0, 0, 6)
	useBtn.BackgroundColor3 = UI.colors.buttonPrimary or Color3.fromRGB(60, 60, 60); useBtn.BorderSizePixel = 0
	useBtn.Text = "Use"; useBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	useBtn.TextSize = 10; useBtn.Font = Enum.Font.GothamBold; useBtn.ZIndex = 2; useBtn.Parent = f
	Instance.new("UICorner", useBtn).CornerRadius = UDim.new(0, 4)
	useBtn.MouseButton1Click:Connect(function()
		QB_CodeInput.Text = info.code
		QB_ClaimResult.Text = ""; QB_ClaimResult.Visible = false
	end)
end

local function createHistoryRow(parent, entry, order)
	local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 40)
	f.BackgroundColor3 = UI.colors.panelHighlight; f.BorderSizePixel = 0; f.LayoutOrder = order; f.Parent = parent
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	local icon = Instance.new("TextLabel"); icon.Size = UDim2.new(0, 28, 1, 0); icon.Position = UDim2.new(0, 6, 0, 0)
	icon.BackgroundTransparency = 1; icon.Text = entry.type == "real" and "[R]" or "[F]"
	icon.TextColor3 = entry.type == "real" and UI.colors.accent or UI.colors.textMuted
	icon.TextSize = 12; icon.Font = Enum.Font.GothamBold; icon.Parent = f
	local title = Instance.new("TextLabel"); title.Size = UDim2.new(0.5, -36, 0, 18); title.Position = UDim2.new(0, 36, 0, 3)
	title.BackgroundTransparency = 1; title.Text = entry.title or "Unknown"
	title.TextColor3 = UI.colors.textPrimary; title.TextSize = 12; title.Font = Enum.Font.GothamMedium
	title.TextXAlignment = Enum.TextXAlignment.Left; title.TextTruncate = Enum.TextTruncate.AtEnd; title.Parent = f
	local sub = Instance.new("TextLabel"); sub.Size = UDim2.new(0.5, -36, 0, 14); sub.Position = UDim2.new(0, 36, 0, 22)
	sub.BackgroundTransparency = 1; sub.TextSize = 10; sub.Font = Enum.Font.Gotham
	sub.TextXAlignment = Enum.TextXAlignment.Left; sub.TextColor3 = UI.colors.textMuted
	sub.Text = entry.type == "real" and (entry.rodName or "Rod") or "Rp200,000"; sub.Parent = f
	local status = Instance.new("TextLabel"); status.Size = UDim2.new(0.3, -8, 1, 0); status.Position = UDim2.new(0.7, 0, 0, 0)
	status.BackgroundTransparency = 1; status.TextSize = 10; status.Font = Enum.Font.GothamMedium
	status.TextXAlignment = Enum.TextXAlignment.Right; status.Parent = f
	if entry.type == "real" then
		status.Text       = entry.claimed and L("quest.status_claimed") or L("quest.status_unclaimed")
		status.TextColor3 = entry.claimed and UI.colors.success or UI.colors.warning
	else
		status.Text = L("quest.status_opened"); status.TextColor3 = UI.colors.textMuted
	end
end

-- ═══════════════════════════════════════════════════════════════
-- BOTTLE LETTER
-- ═══════════════════════════════════════════════════════════════
local function openLetter(data)
	if isLetterOpen or isAnimating then return end
	isLetterOpen = true
	local isReal = data.bottleType == "real"
	if isReal then playSound("real") else task.delay(0.15, function() playSound("fake") end) end

	BL_TitleLabel.Text      = isReal and L("letter.title_real") or L("letter.title_fake")
	BL_TypeLabel.Text       = isReal and L("letter.type_real") or L("letter.type_fake")
	BL_TypeLabel.TextColor3 = isReal and UI.colors.accent or UI.colors.textMuted
	BL_LetterTitle.Text     = data.message.title
	BL_LetterBody.Text      = data.message.body
	BL_CashGivenLabel.Visible = not isReal
	if not isReal then
		BL_CashGivenLabel.Text = string.format(L("letter.cash_given"), formatNum(data.cashGiven or 200000))
	end
	BL_CodeSection.Visible = isReal
	if isReal and data.code then
		if BL_CodeText:IsA("TextBox") then
			BL_CodeText.Text = data.code
			BL_CodeText.TextEditable = false
			BL_CodeText.ClearTextOnFocus = false
		else
			BL_CodeText.Text = data.code
		end
		local rodName          = data.rodReward and data.rodReward.displayName or "Unknown Rod"
		BL_RodRewardLabel.Text = string.format(L("letter.reward_prefix"), rodName)
	end
	BL_CopyBtn.Text = L("letter.copy_code")
	showFrame(BLFrame)
end

local function closeLetter()
	if not isLetterOpen or isAnimating then return end
	stopAllSounds()
	hideFrame(BLFrame, function() isLetterOpen = false end)
end

BL_CloseBtn.MouseButton1Click:Connect(closeLetter)
BL_CloseBottomBtn.MouseButton1Click:Connect(closeLetter)

BL_CopyBtn.MouseButton1Click:Connect(function()
	local code = BL_CodeText.Text
	if code and code ~= "" then
		local copyOk = pcall(function() setclipboard(code) end)
		if copyOk then
			BL_CopyBtn.Text = L("letter.copied")
		else
			QB_CodeInput.Text = code
			BL_CopyBtn.Text = "✓ Code saved! Use Quest Board to claim"
			showNotification("💡 Code auto-filled in Quest Board! Open Quest Board → Claim tab to redeem.", "📋", 6)
		end
		task.delay(3, function() BL_CopyBtn.Text = L("letter.copy_code") end)
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- DETECT BOTTLE EQUIP -> AUTO OPEN
-- ═══════════════════════════════════════════════════════════════
local function onToolEquipped(tool)
	if not tool or not tool:IsA("Tool") then return end
	if not tool:GetAttribute("IsBottle") then return end
	if tool:GetAttribute("BottleOpened") then return end
	if openingBottle then return end
	openingBottle = true
	tool:SetAttribute("BottleOpened", true)
	playSound("found")
	local bottleId = tool:GetAttribute("BottleId")
	if not bottleId then openingBottle = false; return end
	task.wait(0.3)
	local result = nil
	pcall(function() result = OpenBottleRemote:InvokeServer(bottleId) end)
	if result and result.success then
		openLetter(result)
	else
		local bottleType = tool:GetAttribute("BottleType") or "fake"
		local fallbackData = {
			bottleType = bottleType,
			message    = { title = tool:GetAttribute("BottleMsgTitle") or "Unknown", body = tool:GetAttribute("BottleMsgBody") or "" },
		}
		if bottleType == "real" then
			fallbackData.code      = tool:GetAttribute("BottleCode") or "???"
			fallbackData.rodReward = { displayName = tool:GetAttribute("BottleRodDisplay") or "Unknown Rod" }
		else
			fallbackData.cashGiven = 200000
		end
		openLetter(fallbackData)
		pcall(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid:UnequipTools() end
			task.wait(0.1); if tool and tool.Parent then tool:Destroy() end
		end)
	end
	openingBottle = false
end

local function setupCharacter(char)
	if not char then return end
	if charChildAddedConn then
		charChildAddedConn:Disconnect()
		charChildAddedConn = nil
	end
	charChildAddedConn = char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("IsBottle") then task.spawn(onToolEquipped, child) end
	end)
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("IsBottle") and not child:GetAttribute("BottleOpened") then
			task.spawn(onToolEquipped, child)
		end
	end
end

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

-- ═══════════════════════════════════════════════════════════════
-- QUEST BOARD
-- ═══════════════════════════════════════════════════════════════
local function refreshQuest(info)
	clearList(QB_StatsFrame); ensureListLayout(QB_StatsFrame, 4)
	if info and info.stats then
		local s = info.stats
		createStatRow(QB_StatsFrame, L("quest.bottles_caught"), s.caught or 0, 1)
		createStatRow(QB_StatsFrame, L("quest.real_bottles"),   s.real or 0, 2)
		createStatRow(QB_StatsFrame, L("quest.fake_bottles"),   s.fake or 0, 3)
		createStatRow(QB_StatsFrame, L("quest.codes_claimed"),  s.claimed or 0, 4)
		createStatRow(QB_StatsFrame, L("quest.rods_earned"),    s.rods or 0, 5)
		createStatRow(QB_StatsFrame, L("quest.cash_earned"),    "Rp" .. formatNum(s.cash or 0), 6)
	end
end

local function refreshClaim(info)
	QB_CodeInput.Text = ""; QB_ClaimResult.Text = ""; QB_ClaimResult.Visible = false
	clearList(QB_ActiveCodesList); ensureListLayout(QB_ActiveCodesList, 6)
	if info and info.unclaimedCodes and #info.unclaimedCodes > 0 then
		QB_ActiveCodesTitle.Text = string.format(L("quest.active_codes"), #info.unclaimedCodes)
		for i, c in ipairs(info.unclaimedCodes) do createCodeCard(QB_ActiveCodesList, c, i) end
	else
		QB_ActiveCodesTitle.Text = string.format(L("quest.active_codes"), 0)
		local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, 0, 0, 36)
		lbl.BackgroundTransparency = 1; lbl.Text = L("quest.no_codes")
		lbl.TextColor3 = UI.colors.textMuted; lbl.TextSize = 12; lbl.Font = Enum.Font.Gotham
		lbl.Parent = QB_ActiveCodesList
	end
end

local function refreshHistory(info)
	clearList(QB_HistoryScroll); ensureListLayout(QB_HistoryScroll, 4)
	if info and info.history and #info.history > 0 then
		for i, e in ipairs(info.history) do createHistoryRow(QB_HistoryScroll, e, i) end
	else
		local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, 0, 0, 50)
		lbl.BackgroundTransparency = 1; lbl.Text = L("quest.no_history")
		lbl.TextColor3 = UI.colors.textMuted; lbl.TextSize = 12; lbl.Font = Enum.Font.Gotham
		lbl.Parent = QB_HistoryScroll
	end
end

local function switchTab(name)
	currentTab = name
	local tabs  = { QB_TabQuest, QB_TabClaim, QB_TabHistory }
	local names = { "quest", "claim", "history" }
	local pages = { QB_QuestPage, QB_ClaimPage, QB_HistoryPage }
	for i, tab in ipairs(tabs) do
		local active         = names[i] == name
		tab.BackgroundColor3 = active and UI.colors.buttonPrimary or UI.colors.buttonSecondary
		tab.TextColor3       = active and UI.colors.buttonPrimaryText or UI.colors.buttonSecondaryText
		pages[i].Visible     = active
	end
end

local function openBoard()
	if isBoardOpen or isAnimating then return end
	isBoardOpen = true
	local info = nil
	pcall(function() info = GetQuestInfoRemote:InvokeServer() end)
	refreshQuest(info); refreshClaim(info); refreshHistory(info)
	switchTab("quest"); showFrame(QBFrame)
end

local function closeBoard()
	if not isBoardOpen or isAnimating then return end
	hideFrame(QBFrame, function() isBoardOpen = false end)
end

QB_TabQuest.MouseButton1Click:Connect(function() switchTab("quest") end)
QB_TabClaim.MouseButton1Click:Connect(function() switchTab("claim") end)
QB_TabHistory.MouseButton1Click:Connect(function() switchTab("history") end)
QB_CloseBtn.MouseButton1Click:Connect(closeBoard)

QB_ClaimBtn.MouseButton1Click:Connect(function()
	local code = QB_CodeInput.Text
	if not code or code == "" then
		QB_ClaimResult.Text = L("notif.code_enter"); QB_ClaimResult.TextColor3 = UI.colors.error
		QB_ClaimResult.Visible = true; return
	end
	QB_ClaimBtn.Text = L("quest.claiming"); QB_ClaimBtn.Active = false
	local result = nil
	pcall(function() result = ClaimCodeRemote:InvokeServer(code) end)
	QB_ClaimBtn.Text = L("quest.claim_btn"); QB_ClaimBtn.Active = true
	if result and result.success then
		local msg = string.format(L("quest.claim_ok"), result.rodName)
		if result.alreadyOwned then msg = msg .. L("quest.claim_restored") end
		QB_ClaimResult.Text = msg; QB_ClaimResult.TextColor3 = UI.colors.success
		QB_ClaimResult.Visible = true; QB_CodeInput.Text = ""
		showNotification(string.format(L("quest.claimed_notif"), result.rodName), "", 5)
		task.spawn(function()
			local info = nil
			pcall(function() info = GetQuestInfoRemote:InvokeServer() end)
			if info then refreshClaim(info); refreshQuest(info); refreshHistory(info) end
		end)
	elseif result then
		QB_ClaimResult.Text = result.error or "Failed."; QB_ClaimResult.TextColor3 = UI.colors.error
		QB_ClaimResult.Visible = true
	else
		QB_ClaimResult.Text = L("quest.connection_error"); QB_ClaimResult.TextColor3 = UI.colors.error
		QB_ClaimResult.Visible = true
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- OVERLAY CLOSE & ESC
-- ═══════════════════════════════════════════════════════════════
Overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if isLetterOpen then closeLetter() elseif isBoardOpen then closeBoard() end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
	if triggerPlayer ~= player then return end
	local parent = prompt.Parent
	if not parent then return end
	local isBoard = parent.Name == "BottleQuestBoard" or CollectionService:HasTag(parent, "BottleQuestBoard")
	if not isBoard and parent.Parent then
		isBoard = parent.Parent.Name == "BottleQuestBoard" or CollectionService:HasTag(parent.Parent, "BottleQuestBoard")
	end
	if isBoard then openBoard() end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if isLetterOpen then closeLetter() elseif isBoardOpen then closeBoard() end
	end
end)

-- Init
Overlay.Visible = false; BLFrame.Visible = false; QBFrame.Visible = false
NotifFrame.Visible = false; bannerFrame.Visible = false