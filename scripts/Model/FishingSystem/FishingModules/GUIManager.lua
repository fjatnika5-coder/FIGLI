-- ReplicatedStorage/FishingModules/GUIManager
local GUIManager = {}
local TS = game:GetService("TweenService")
local SoundManager = nil -- Akan kita 'require' nanti

local gui = {}
local fishingFrameOriginalPosition
local imageTapOriginalSize
local notificationCoroutine

-- == FUNGSI BARU UNTUK MEMBUAT TOMBOL AUTO ==
local function createAutoButton(parentGui)
	local UIS = game:GetService("UserInputService")
	local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

	local autoButton = Instance.new("TextButton")
	autoButton.Name = "AutoButton"
	autoButton.Parent = parentGui
	autoButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Merah (OFF)
	autoButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
	autoButton.BorderSizePixel = 1
	autoButton.ZIndex = 2
	autoButton.Text = ""

	-- ✅ POSISI + SIZE (samain style AFK: center bawah, di atas hotbar)
	autoButton.AnchorPoint = Vector2.new(0.5, 1)

	if isMobile then
		-- MOBILE: kecil + lebih bawah
		autoButton.Size     = UDim2.new(0, 120, 0, 27)
		autoButton.Position = UDim2.new(0.5, 0, 1, -75)
	else
		-- PC/TABLET
		autoButton.Size     = UDim2.new(0, 180, 0, 40)
		autoButton.Position = UDim2.new(0.5, 0, 1, -120)
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = autoButton

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = autoButton

	local autoText = Instance.new("TextLabel")
	autoText.Name = "Text"
	autoText.Parent = autoButton
	autoText.BackgroundTransparency = 1
	autoText.Size = UDim2.new(1, 0, 1, 0)
	autoText.Font = Enum.Font.GothamSemibold
	autoText.Text = "Auto: OFF"
	autoText.TextColor3 = Color3.fromRGB(255, 255, 255)
	autoText.TextScaled = true
	autoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	autoText.TextStrokeTransparency = 0.5

	return autoButton, autoText
end

-- =============================================

-- ===================================================================
-- ===== [FITUR BARU] MEMBUAT GUI EFEK LANGKA =====
-- ===================================================================
local function createRareEffectGui(playerGui)
	local rareGui = Instance.new("ScreenGui")
	rareGui.Name = "RareFishEffectGui"
	rareGui.Enabled = false
	rareGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	rareGui.ResetOnSpawn = false

	-- Frame Hitam Transparan Penuh
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.BackgroundTransparency = 1 -- Mulai dari transparan
	background.Size = UDim2.new(1, 0, 1, 0)
	background.ZIndex = 9
	background.Parent = rareGui

	-- Teks Rarity (cth: "LEGENDARY!")
	local rarityText = Instance.new("TextLabel")
	rarityText.Name = "RarityText"
	rarityText.BackgroundTransparency = 1
	rarityText.Size = UDim2.new(0.8, 0, 0.3, 0)
	rarityText.AnchorPoint = Vector2.new(0.5, 0.5)
	rarityText.Position = UDim2.new(0.5, 0, 0.5, 0)
	rarityText.Font = Enum.Font.GothamBlack
	rarityText.Text = "LEGENDARY!"
	rarityText.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityText.TextScaled = true
	rarityText.TextTransparency = 1 -- Mulai dari transparan
	rarityText.ZIndex = 10
	rarityText.Parent = background

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 3
	stroke.Transparency = 1 -- Mulai dari transparan
	stroke.Parent = rarityText

	rareGui.Parent = playerGui

	return background, rarityText, stroke
end
-- ===================================================================

function GUIManager:Initialize(player)
	local playerGui = player:WaitForChild("PlayerGui")
	local fishingGui = playerGui:WaitForChild("FishingGui")

	-- == MEMBUAT TOMBOL AUTO SAAT INISIALISASI ==
	local autoButton, autoText = createAutoButton(fishingGui)

	-- == [FITUR BARU] MEMBUAT GUI EFEK LANGKA ==
	local rareBg, rareText, rareStroke = createRareEffectGui(playerGui)
	-- ===========================================

	gui = {
		notificationFrame = fishingGui:WaitForChild("Notification"),
		messageLabel = fishingGui.Notification:WaitForChild("Message"),
		tapMobileButton = fishingGui:WaitForChild("TapMobile"),
		tapMobileText = fishingGui.TapMobile:WaitForChild("TAP"),
		barFrame = fishingGui:WaitForChild("Bar"),
		fillFrame = fishingGui.Bar:WaitForChild("Fill"),
		luckMultiText = fishingGui.Bar:WaitForChild("LuckMulti"),
		fishingFrame = fishingGui:WaitForChild("Fishing"),
		fishingBarFrame = fishingGui.Fishing:WaitForChild("Bar"),
		fishingFillFrame = fishingGui.Fishing.Bar:WaitForChild("Fill"),
		whiteBox = fishingGui.Fishing:WaitForChild("WhiteBox"),
		imageTap = fishingGui.Fishing.WhiteBox:WaitForChild("ImageTap"),
		infoText = fishingGui.Fishing:WaitForChild("Info"),

		-- == MENAMBAHKAN REFERENSI TOMBOL AUTO ==
		autoButton = autoButton,
		autoButtonText = autoText,

		-- == [FITUR BARU] MENAMBAHKAN REFERENSI GUI LANGKA ==
		rareEffectBackground = rareBg,
		rareEffectText = rareText,
		rareEffectStroke = rareStroke
		-- ======================================
	}

	gui.barFrame.Visible = false
	gui.fishingFrame.Visible = false
	gui.tapMobileButton.Visible = false
	gui.autoButton.Visible = false 

	fishingFrameOriginalPosition = gui.fishingFrame.Position
	imageTapOriginalSize = gui.imageTap.Size

	-- [FITUR BARU] Membutuhkan SoundManager untuk efek suara
	SoundManager = require(script.Parent:WaitForChild("SoundManager"))
end

function GUIManager:GetElement(elementName)
	return gui[elementName]
end

-- == FUNGSI BARU UNTUK UPDATE TOMBOL AUTO ==
function GUIManager:UpdateAutoButton(isOn)
	if not gui.autoButton then return end

	if isOn then
		gui.autoButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50) -- Hijau (ON)
		gui.autoButtonText.Text = "Auto: ON"
	else
		gui.autoButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50) -- Merah (OFF)
		gui.autoButtonText.Text = "Auto: OFF"
	end
end

function GUIManager:ShowAutoButton(visible)
	if gui.autoButton then
		gui.autoButton.Visible = visible
	end
end
-- ========================================

-- ===================================================================
-- ===== [FITUR BARU] FUNGSI UNTUK MEMUTAR "CUTSCENE" =====
-- ===================================================================
function GUIManager:PlayRareEffect(rarityName, rarityColor, onCompleteCallback)
	if not gui.rareEffectBackground then
		-- Jika GUI gagal dibuat, langsung panggil callback
		onCompleteCallback()
		return
	end

	-- Persiapan
	local bg = gui.rareEffectBackground
	local text = gui.rareEffectText
	local stroke = gui.rareEffectStroke

	bg.Parent.Enabled = true
	text.Text = rarityName:upper() .. "!"
	text.TextColor3 = rarityColor

	-- Reset Awal
	bg.BackgroundTransparency = 1
	text.TextTransparency = 1
	stroke.Transparency = 1
	text.Size = UDim2.new(0.8, 0, 0.3, 0)

	-- Animasi
	task.spawn(function()
		-- Suara Dramatis
		if SoundManager then
			SoundManager:Play("Success", 1.0) -- Mainkan suara sukses dengan volume penuh
		end

		-- 1. Fade in background hitam
		TS:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 0.6}):Play()

		-- 2. Teks muncul dan membesar (Zoom-in)
		text.TextTransparency = 0
		stroke.Transparency = 0
		TS:Create(text, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.9, 0, 0.35, 0)
		}):Play()

		-- 3. Tahan selama 3 detik
		task.wait(3)

		-- 4. Fade out semuanya
		TS:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		TS:Create(text, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TS:Create(stroke, TweenInfo.new(0.5), {Transparency = 1}):Play()

		-- 5. Tunggu fade out selesai, lalu panggil callback
		task.wait(0.5)
		bg.Parent.Enabled = false

		if onCompleteCallback then
			onCompleteCallback()
		end
	end)
end
-- ===================================================================

function GUIManager:ShowNotification(message, duration, textColor)
	duration = duration or 3
	textColor = textColor or Color3.fromRGB(255, 255, 255)

	if notificationCoroutine then
		coroutine.close(notificationCoroutine)
	end

	gui.notificationFrame.Visible = true
	gui.messageLabel.TextTransparency = 0
	gui.messageLabel.Text = message
	gui.messageLabel.TextColor3 = textColor

	notificationCoroutine = coroutine.create(function()
		task.wait(duration)

		for i = 0, 1, 0.1 do
			if gui.messageLabel then
				gui.messageLabel.TextTransparency = i
			end
			task.wait(0.02)
		end

		if gui.notificationFrame then
			gui.notificationFrame.Visible = false
		end
	end)

	coroutine.resume(notificationCoroutine)
end

function GUIManager:UpdateMobileButtonText(text)
	gui.tapMobileText.Text = text
end

function GUIManager:ShowMobileButton(visible)
	gui.tapMobileButton.Visible = visible
end

function GUIManager:SlideFishingFrameIn()
	if not gui.fishingFrame then return end

	gui.fishingFrame.Position = UDim2.new(
		fishingFrameOriginalPosition.X.Scale,
		fishingFrameOriginalPosition.X.Offset,
		1.2, 0
	)

	gui.fishingFrame.Visible = true

	local slideInTween = TS:Create(
		gui.fishingFrame,
		TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{Position = fishingFrameOriginalPosition}
	)

	slideInTween:Play()
end


function GUIManager:SlideFishingFrameOut(callback)
	if not gui.fishingFrame or not fishingFrameOriginalPosition then 
		if callback then callback() end
		return 
	end

	local slideOutTween = TS:Create(
		gui.fishingFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{Position = UDim2.new(
			fishingFrameOriginalPosition.X.Scale,
			fishingFrameOriginalPosition.X.Offset,
			1.2, 0
			)}
	)

	slideOutTween:Play()

	slideOutTween.Completed:Connect(function()
		gui.fishingFrame.Visible = false
		gui.fishingFrame.Position = fishingFrameOriginalPosition

		if callback then callback() end
	end)
end

function GUIManager:AnimateImageTap()
	if not gui.imageTap or not imageTapOriginalSize then return end

	local compressTween = TS:Create(
		gui.imageTap,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(
			imageTapOriginalSize.X.Scale * 0.8, 
			imageTapOriginalSize.X.Offset * 0.8, 
			imageTapOriginalSize.Y.Scale * 0.8, 
			imageTapOriginalSize.Y.Offset * 0.8
			)}
	)

	local bounceTween = TS:Create(
		gui.imageTap,
		TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{Size = imageTapOriginalSize}
	)

	compressTween:Play()
	compressTween.Completed:Connect(function()
		bounceTween:Play()
	end)
end

return GUIManager