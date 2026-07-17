-- GUIManager
-- Location: ReplicatedStorage/FishingSystem/FishingModules/GUIManager (ModuleScript)
-- Idempotent initialization, no duplicate GUI instances, bounded tweens/tasks.
--
-- [FIX-AUTO] getOrCreateAutoButton: kalau tombol AutoButton sudah ada di
-- FishingGui (di-clone dari StarterGui) tetapi TextLabel-nya TIDAK bernama
-- "Text", label designer itu DIADOPSI (di-rename) — bukan membuat TextLabel
-- kedua yang saling menimpa. Ini memastikan UpdateAutoButton selalu menulis
-- ke label yang benar-benar tampil, sehingga teks default "Label" tidak
-- pernah terlihat.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GUIManager = {}

local gui = {}
local initializedPlayerGui = nil
local fishingFrameOriginalPosition = nil
local imageTapOriginalSize = nil
local SoundManager = nil

local notificationGeneration = 0
local rareEffectGeneration = 0
local activeSlideTween = nil
local activeTapTweens = {}

local function cancelTween(tween)
	if tween then
		pcall(function() tween:Cancel() end)
	end
end

local function getOrCreateAutoButton(parentGui)
	local autoButton = parentGui:FindFirstChild("AutoButton")
	if autoButton and not autoButton:IsA("TextButton") then
		autoButton:Destroy()
		autoButton = nil
	end

	if not autoButton then
		autoButton = Instance.new("TextButton")
		autoButton.Name = "AutoButton"
		autoButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
		autoButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
		autoButton.BorderSizePixel = 1
		autoButton.ZIndex = 2
		autoButton.Text = ""
		autoButton.AnchorPoint = Vector2.new(0.5, 1)
		autoButton.Parent = parentGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = autoButton

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 1.5
		stroke.Parent = autoButton
	end

	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if isMobile then
		autoButton.Size = UDim2.new(0, 120, 0, 27)
		autoButton.Position = UDim2.new(0.5, 0, 1, -75)
	else
		autoButton.Size = UDim2.new(0, 180, 0, 40)
		autoButton.Position = UDim2.new(0.5, 0, 1, -120)
	end

	local autoText = autoButton:FindFirstChild("Text")
	if autoText and not autoText:IsA("TextLabel") then
		autoText:Destroy()
		autoText = nil
	end
	-- [FIX-AUTO] Adopsi TextLabel designer yang namanya bukan "Text" —
	-- mencegah dua label bertumpuk (label "Label" tampil di atas/bawah
	-- label yang di-update script).
	if not autoText then
		autoText = autoButton:FindFirstChildOfClass("TextLabel")
		if autoText then
			autoText.Name = "Text"
		end
	end
	if not autoText then
		autoText = Instance.new("TextLabel")
		autoText.Name = "Text"
		autoText.BackgroundTransparency = 1
		autoText.Size = UDim2.new(1, 0, 1, 0)
		autoText.Font = Enum.Font.GothamSemibold
		autoText.TextColor3 = Color3.fromRGB(255, 255, 255)
		autoText.TextScaled = true
		autoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		autoText.TextStrokeTransparency = 0.5
		autoText.Parent = autoButton
	end
	if autoText.Text == "" then
		autoText.Text = "Auto: OFF"
	end

	return autoButton, autoText
end

local function getOrCreateRareEffectGui(playerGui)
	local rareGui = playerGui:FindFirstChild("RareFishEffectGui")
	if rareGui and not rareGui:IsA("ScreenGui") then
		rareGui:Destroy()
		rareGui = nil
	end

	if not rareGui then
		rareGui = Instance.new("ScreenGui")
		rareGui.Name = "RareFishEffectGui"
		rareGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		rareGui.ResetOnSpawn = false
		rareGui.Parent = playerGui
	end
	rareGui.Enabled = false

	local background = rareGui:FindFirstChild("Background")
	if background and not background:IsA("Frame") then
		background:Destroy()
		background = nil
	end
	if not background then
		background = Instance.new("Frame")
		background.Name = "Background"
		background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		background.BackgroundTransparency = 1
		background.Size = UDim2.new(1, 0, 1, 0)
		background.ZIndex = 9
		background.Parent = rareGui
	end

	local rarityText = background:FindFirstChild("RarityText")
	if rarityText and not rarityText:IsA("TextLabel") then
		rarityText:Destroy()
		rarityText = nil
	end
	if not rarityText then
		rarityText = Instance.new("TextLabel")
		rarityText.Name = "RarityText"
		rarityText.BackgroundTransparency = 1
		rarityText.Size = UDim2.new(0.8, 0, 0.3, 0)
		rarityText.AnchorPoint = Vector2.new(0.5, 0.5)
		rarityText.Position = UDim2.new(0.5, 0, 0.5, 0)
		rarityText.Font = Enum.Font.GothamBlack
		rarityText.Text = "LEGENDARY!"
		rarityText.TextColor3 = Color3.fromRGB(255, 255, 255)
		rarityText.TextScaled = true
		rarityText.TextTransparency = 1
		rarityText.ZIndex = 10
		rarityText.Parent = background
	end

	local stroke = rarityText:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent = rarityText
	end
	stroke.Transparency = 1

	return background, rarityText, stroke
end

function GUIManager:Initialize(player)
	if not player then return false end

	local playerGui = player:WaitForChild("PlayerGui")
	local fishingGui = playerGui:WaitForChild("FishingGui")

	local autoButton, autoText = getOrCreateAutoButton(fishingGui)
	local rareBg, rareText, rareStroke = getOrCreateRareEffectGui(playerGui)

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
		autoButton = autoButton,
		autoButtonText = autoText,
		rareEffectBackground = rareBg,
		rareEffectText = rareText,
		rareEffectStroke = rareStroke,
	}

	gui.barFrame.Visible = false
	gui.fishingFrame.Visible = false
	gui.tapMobileButton.Visible = false
	gui.autoButton.Visible = false

	fishingFrameOriginalPosition = gui.fishingFrame.Position
	imageTapOriginalSize = gui.imageTap.Size
	initializedPlayerGui = playerGui

	if not SoundManager then
		SoundManager = require(script.Parent:WaitForChild("SoundManager"))
	end

	return true
end

function GUIManager:GetElement(elementName)
	return gui[elementName]
end

function GUIManager:UpdateAutoButton(isOn)
	if not gui.autoButton or not gui.autoButton.Parent then return end
	gui.autoButton.BackgroundColor3 = isOn
		and Color3.fromRGB(50, 200, 50)
		or Color3.fromRGB(220, 50, 50)
	if gui.autoButtonText then
		gui.autoButtonText.Text = isOn and "Auto: ON" or "Auto: OFF"
	end
end

function GUIManager:ShowAutoButton(visible)
	if gui.autoButton then
		gui.autoButton.Visible = visible == true
	end
end

function GUIManager:PlayRareEffect(rarityName, rarityColor, onCompleteCallback)
	local bg = gui.rareEffectBackground
	local text = gui.rareEffectText
	local stroke = gui.rareEffectStroke
	if not (bg and bg.Parent and text and stroke) then
		if onCompleteCallback then onCompleteCallback() end
		return
	end

	rareEffectGeneration += 1
	local generation = rareEffectGeneration

	bg.Parent.Enabled = true
	text.Text = tostring(rarityName or "RARE"):upper() .. "!"
	text.TextColor3 = rarityColor or Color3.new(1, 1, 1)
	bg.BackgroundTransparency = 1
	text.TextTransparency = 1
	stroke.Transparency = 1
	text.Size = UDim2.new(0.8, 0, 0.3, 0)

	if SoundManager then
		SoundManager:Play("Success", 1)
	end

	TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0.6 }):Play()
	text.TextTransparency = 0
	stroke.Transparency = 0
	TweenService:Create(
		text,
		TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0.9, 0, 0.35, 0) }
	):Play()

	task.delay(3, function()
		if generation ~= rareEffectGeneration or not bg.Parent then return end

		TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()

		task.delay(0.5, function()
			if generation ~= rareEffectGeneration or not bg.Parent then return end
			bg.Parent.Enabled = false
			if onCompleteCallback then onCompleteCallback() end
		end)
	end)
end

function GUIManager:ShowNotification(message, duration, textColor)
	if not gui.notificationFrame or not gui.messageLabel then return end

	notificationGeneration += 1
	local generation = notificationGeneration
	duration = math.clamp(tonumber(duration) or 3, 0.2, 20)

	gui.notificationFrame.Visible = true
	gui.messageLabel.TextTransparency = 0
	gui.messageLabel.Text = tostring(message or "")
	gui.messageLabel.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)

	task.delay(duration, function()
		if generation ~= notificationGeneration or not gui.messageLabel.Parent then return end

		local fade = TweenService:Create(
			gui.messageLabel,
			TweenInfo.new(0.2, Enum.EasingStyle.Linear),
			{ TextTransparency = 1 }
		)
		fade:Play()
		fade.Completed:Once(function()
			if generation == notificationGeneration and gui.notificationFrame then
				gui.notificationFrame.Visible = false
			end
		end)
	end)
end

function GUIManager:UpdateMobileButtonText(text)
	if gui.tapMobileText then
		gui.tapMobileText.Text = tostring(text or "")
	end
end

function GUIManager:ShowMobileButton(visible)
	if gui.tapMobileButton then
		gui.tapMobileButton.Visible = visible == true
	end
end

function GUIManager:SlideFishingFrameIn()
	if not gui.fishingFrame or not fishingFrameOriginalPosition then return end

	cancelTween(activeSlideTween)
	gui.fishingFrame.Position = UDim2.new(
		fishingFrameOriginalPosition.X.Scale,
		fishingFrameOriginalPosition.X.Offset,
		1.2,
		0
	)
	gui.fishingFrame.Visible = true

	activeSlideTween = TweenService:Create(
		gui.fishingFrame,
		TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = fishingFrameOriginalPosition }
	)
	activeSlideTween:Play()
end

function GUIManager:SlideFishingFrameOut(callback)
	if not gui.fishingFrame or not fishingFrameOriginalPosition then
		if callback then callback() end
		return
	end

	cancelTween(activeSlideTween)
	activeSlideTween = TweenService:Create(
		gui.fishingFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
		{
			Position = UDim2.new(
				fishingFrameOriginalPosition.X.Scale,
				fishingFrameOriginalPosition.X.Offset,
				1.2,
				0
			),
		}
	)
	local tweenRef = activeSlideTween
	tweenRef:Play()
	tweenRef.Completed:Once(function()
		if activeSlideTween ~= tweenRef then return end
		gui.fishingFrame.Visible = false
		gui.fishingFrame.Position = fishingFrameOriginalPosition
		activeSlideTween = nil
		if callback then callback() end
	end)
end

function GUIManager:AnimateImageTap()
	if not gui.imageTap or not imageTapOriginalSize then return end

	for _, tween in ipairs(activeTapTweens) do
		cancelTween(tween)
	end
	table.clear(activeTapTweens)

	local compressTween = TweenService:Create(
		gui.imageTap,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(
				imageTapOriginalSize.X.Scale * 0.8,
				imageTapOriginalSize.X.Offset * 0.8,
				imageTapOriginalSize.Y.Scale * 0.8,
				imageTapOriginalSize.Y.Offset * 0.8
			),
		}
	)
	local bounceTween = TweenService:Create(
		gui.imageTap,
		TweenInfo.new(0.15, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ Size = imageTapOriginalSize }
	)
	activeTapTweens[1] = compressTween
	activeTapTweens[2] = bounceTween

	compressTween:Play()
	compressTween.Completed:Once(function()
		if gui.imageTap and gui.imageTap.Parent then
			bounceTween:Play()
		end
	end)
end

function GUIManager:Cleanup()
	notificationGeneration += 1
	rareEffectGeneration += 1
	cancelTween(activeSlideTween)
	activeSlideTween = nil

	for _, tween in ipairs(activeTapTweens) do
		cancelTween(tween)
	end
	table.clear(activeTapTweens)
	table.clear(gui)
	initializedPlayerGui = nil
	fishingFrameOriginalPosition = nil
	imageTapOriginalSize = nil
end

return GUIManager
