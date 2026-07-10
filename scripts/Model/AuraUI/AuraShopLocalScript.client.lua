-- AuraShopClient (LocalScript)
-- ✅ FIXED v2:
-- 1. previewAura() sekarang FireServer ke PreviewAura remote
--    Preview dihandle di SERVER, bukan client langsung
--    Supaya cleanup bisa dijamin dari server side
-- 2. cancelPreview() sekarang FireServer ke CloseAuraTab remote
--    Server yang bersihin preview, bukan client nebak-nebak sendiri
-- 3. closeShop() otomatis FireServer CloseAuraTab
--    Jadi saat tab ditutup, preview PASTI hilang
-- 4. Hapus logika cleanup manual di client (loop cari IsPreview)
--    Karena sekarang server yang handle, tidak perlu double cleanup
-- 5. previewComponents tidak dipakai lagi (preview ada di server)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local Character    = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 10)
local Camera       = workspace.CurrentCamera

-- ===================================================================
-- UI REFERENCES
-- ===================================================================
local MainUI             = script.Parent
local MainFrame          = MainUI:WaitForChild("AuraMainFrame")
local ScrollingF         = MainFrame:WaitForChild("ScrollingFrame")
local CloseButton        = MainFrame:WaitForChild("Close")
local RotateFrame        = MainFrame:WaitForChild("RotateFrame")
local PurchaseFrame      = MainUI:WaitForChild("PurchaseFrame")
local BuyButton          = PurchaseFrame:WaitForChild("BuyButton")
local PriceLabel         = BuyButton:WaitForChild("PriceLabel")
local AuraNameLabel      = PurchaseFrame:WaitForChild("AuraName")
local PurchaseDescription = PurchaseFrame:WaitForChild("DescriptionLabel")
local AuraImageFrame     = PurchaseFrame:WaitForChild("AuraImage")
local EquipORView        = PurchaseFrame:WaitForChild("Equiporview")
local EquipORViewText    = EquipORView:WaitForChild("TextLabel")
local CancelPreviewButton = PurchaseFrame:WaitForChild("CancelPreviewButton")

local TemplateButton = script:WaitForChild("Template")

-- ===================================================================
-- REMOTES
-- ===================================================================
local RemoteFolder              = ReplicatedStorage:WaitForChild("AuraShopRemotes")
local PurchaseAuraEvent         = RemoteFolder:WaitForChild("PurchaseAura")
local EquipAuraEvent            = RemoteFolder:WaitForChild("EquipAura")
local UnequipAuraEvent          = RemoteFolder:WaitForChild("UnequipAura")
local GetOwnedAurasFunction     = RemoteFolder:WaitForChild("GetOwnedAuras")
local AuraOwnershipChangedEvent = RemoteFolder:WaitForChild("AuraOwnershipChanged")

-- ✅ NEW: Remote untuk preview dan close tab
local PreviewAuraEvent  = RemoteFolder:WaitForChild("PreviewAura")
local CloseAuraTabEvent = RemoteFolder:WaitForChild("CloseAuraTab")

local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

-- ===================================================================
-- STATE VARIABLES
-- ===================================================================
local ownedAuras          = {}
local currentPreviewAura  = nil   -- tracking preview lokal (untuk UI saja)
local currentEquippedAura = nil
local selectedAuraName    = nil
local isShopOpen          = false

local originalCameraCFrame    = Camera.CFrame
local originalCameraType      = Camera.CameraType
local originalCameraSubject   = Camera.CameraSubject
local originalFieldOfView     = Camera.FieldOfView
local originalHumanoidState   = nil

local rotationSensitivity   = 0.1
local isRotatingCharacter   = false
local currentRotationAngle  = 0

local CHARACTER_ROTATION_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local characterRotationTween = nil

local CAMERA_FIXED_OFFSET_FROM_HRP   = Vector3.new(0, 3, 12)
local CAMERA_LOOK_AT_OFFSET_FROM_HRP = Vector3.new(0, 1, 0)

local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local characterRotationConnection = nil

local rotateDotButton       = RotateFrame.bar.dot.Button
local rotateDotParent       = RotateFrame.bar.dot
local isHoldingRotateDot    = false
local characterRotationBarAngle = 0

-- ===================================================================
-- NOTIFICATION
-- ===================================================================
local function sendNotification(mode, text, sound, duration)
	if _G.SendNotificationV2 then
		_G.SendNotificationV2(mode, text, sound, duration)
	end
end

-- ===================================================================
-- SHOP FUNCTIONS
-- ===================================================================
local function clearAuraButtons()
	for _, child in ipairs(ScrollingF:GetChildren()) do
		if child:IsA("TextButton") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
end

local function updatePurchaseFrame(auraName)
	selectedAuraName = auraName
	local auraInfo = AuraData.GetAura(auraName)
	if not auraInfo then
		PurchaseFrame.Visible = false
		return
	end

	AuraNameLabel.Text        = auraName
	PurchaseDescription.Text  = auraInfo.Description
	AuraImageFrame.Image      = auraInfo.ImageId

	local isOwned                = ownedAuras[auraName] or false
	local isEquipped             = (auraName == currentEquippedAura)
	local isAvailableForPurchase = AuraData.IsAuraAvailable(auraName)

	BuyButton.Visible  = false
	BuyButton.Active   = false
	PriceLabel.Text    = ""

	EquipORView.Visible         = false
	EquipORView.Active          = false
	EquipORViewText.Text        = ""
	EquipORViewText.TextColor3  = Color3.fromRGB(255, 255, 255)

	CancelPreviewButton.Visible = false

	if isOwned then
		EquipORView.Visible = true
		EquipORView.Active  = true

		if isEquipped then
			EquipORViewText.Text       = "UNEQUIP"
			EquipORViewText.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			EquipORViewText.Text = "EQUIP"
		end

		if (auraInfo.CostType == "Limited" or auraInfo.CostType == "Gamepass")
			and not isAvailableForPurchase and not isEquipped then
			EquipORViewText.Text  = "EQUIP"
			EquipORView.Active    = true
		end
	else
		if isAvailableForPurchase then
			BuyButton.Visible  = true
			BuyButton.Active   = true
			PriceLabel.Text    = AuraData.GetFormattedPrice(auraName)

			EquipORView.Visible = true
			EquipORView.Active  = true
			EquipORViewText.Text = "PREVIEW"
		else
			BuyButton.Visible = false
			BuyButton.Active  = false
			EquipORView.Visible = true
			EquipORView.Active  = true
			if (auraInfo.CostType == "Limited" or auraInfo.CostType == "Gamepass")
				and auraInfo.LimitedTimeEnd then
				local dateTime    = DateTime.fromUnixTimestamp(auraInfo.LimitedTimeEnd)
				local saleEndTime = dateTime:FormatUniversalTime("MMMM D, YYYY h:mm A", "en-us")
				EquipORViewText.Text = "PREVIEW (OFFSALE - " .. saleEndTime .. ")"
			else
				EquipORViewText.Text = "PREVIEW (UNAVAILABLE)"
			end
			EquipORViewText.TextColor3 = Color3.fromRGB(81, 80, 80)
		end
	end

	-- ✅ Kalau aura ini sedang di-preview, tampilkan tombol Cancel
	if auraName == currentPreviewAura then
		EquipORView.Visible         = false
		CancelPreviewButton.Visible = true
	end

	PurchaseFrame.Visible = true
end

-- ===================================================================
-- ✅ FIXED: PREVIEW FUNCTIONS
--
-- SEBELUMNYA:
--   previewAura() langsung clone di client → tidak terkontrol
--   cancelPreview() loop manual cari IsPreview → tidak reliable
--
-- SEKARANG:
--   previewAura() → FireServer PreviewAura → server yang clone
--   cancelPreview() → FireServer CloseAuraTab → server yang hapus
--   Client hanya track state lokal untuk keperluan UI
-- ===================================================================

-- ✅ Batalkan preview — server yang bersihin, client update UI saja
local function cancelPreview()
	if currentPreviewAura then
		-- ✅ Beritahu server untuk hapus preview
		-- Server akan panggil AuraData.CleanupPreviewOnly(character)
		CloseAuraTabEvent:FireServer()

		currentPreviewAura = nil
		sendNotification("Default", "Preview cancelled.", "Success", 2)
	end

	if selectedAuraName then
		updatePurchaseFrame(selectedAuraName)
	else
		PurchaseFrame.Visible = false
	end
end

-- ✅ Preview aura — kirim ke server, server yang spawn
local function previewAura(auraName)
	if currentEquippedAura == auraName then return end

	-- Kalau ada preview sebelumnya, server akan bersihin dulu
	-- (ini otomatis di server saat PreviewAura diterima)

	if auraName then
		-- ✅ Server yang handle clone dan cleanup preview lama
		PreviewAuraEvent:FireServer(auraName)
		currentPreviewAura = auraName
		sendNotification("Default", "Now previewing: " .. auraName, "Default", 2)
	end

	if selectedAuraName then
		updatePurchaseFrame(selectedAuraName)
	end
end

local function updateAuraButton(auraButton, auraName)
	local auraInfo = AuraData.GetAura(auraName)
	if not auraInfo then return end

	local auraImage     = auraButton:FindFirstChild("AuraImage")
	local auraNameLabel = auraButton:FindFirstChild("AuraName")
	local AuraPricess   = auraButton:FindFirstChild("AuraPricess")
	local headerLabel   = auraButton:FindFirstChild("Header")

	if not auraImage or not auraNameLabel or not AuraPricess or not headerLabel then return end

	auraImage.Image     = auraInfo.ImageId
	auraNameLabel.Text  = auraName
	auraButton.Active   = true

	local isOwned                = ownedAuras[auraName] or false
	local isEquipped             = (auraName == currentEquippedAura)
	local isAvailableForPurchase = AuraData.IsAuraAvailable(auraName)
	local limitedTimeRemaining   = AuraData.GetLimitedTimeRemaining(auraName)

	if (auraInfo.CostType == "Limited" or auraInfo.CostType == "Gamepass") and auraInfo.LimitedTimeEnd then
		if isAvailableForPurchase and limitedTimeRemaining then
			headerLabel.Text       = limitedTimeRemaining
			headerLabel.TextColor3 = Color3.fromRGB(255, 136, 1)
		else
			local dateTime    = DateTime.fromUnixTimestamp(auraInfo.LimitedTimeEnd)
			local saleEndTime = dateTime:FormatUniversalTime("MMMM D, YYYY h:mm A", "en-us")
			headerLabel.Text       = "OFFSALE - " .. saleEndTime
			headerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		end
	else
		headerLabel.Text       = "Aura"
		headerLabel.TextColor3 = Color3.fromRGB(31, 87, 117)
	end

	if isOwned then
		if isEquipped then
			AuraPricess.Text       = "EQUIPPED"
			AuraPricess.TextColor3 = Color3.fromRGB(0, 255, 0)
		else
			AuraPricess.Text       = "OWNED"
			AuraPricess.TextColor3 = Color3.fromRGB(152, 152, 152)
		end
	else
		if isAvailableForPurchase then
			if auraInfo.CostType == "Currency" then
				AuraPricess.Text       = AuraData.GetFormattedPrice(auraName)
				AuraPricess.TextColor3 = Color3.fromRGB(203, 203, 203)
			elseif auraInfo.CostType == "Gamepass" then
				AuraPricess.Text       = AuraData.GetFormattedPrice(auraName)
				AuraPricess.TextColor3 = Color3.fromRGB(156, 255, 209)
			elseif auraInfo.CostType == "Limited" then
				AuraPricess.Text       = AuraData.GetFormattedPrice(auraName)
				AuraPricess.TextColor3 = Color3.fromRGB(255, 100, 0)
			end
		else
			AuraPricess.Text       = "No longer for sale."
			AuraPricess.TextColor3 = Color3.fromRGB(81, 80, 80)
		end
	end
end

local function populateShop()
	clearAuraButtons()

	for auraName, auraInfo in pairs(AuraData.Auras) do
		if auraInfo.Template then
			local newButton         = TemplateButton:Clone()
			newButton.Name          = auraName
			newButton.AuraName.Text = auraName
			newButton.Parent        = ScrollingF
			newButton.Visible       = true

			updateAuraButton(newButton, auraName)

			newButton.MouseButton1Click:Connect(function()
				updatePurchaseFrame(auraName)
				sendNotification("Default", "Selected: " .. auraName, "Default", 2)
			end)
		end
	end
end

-- ===================================================================
-- CAMERA FUNCTIONS
-- ===================================================================
local function resetCameraToCharacterView()
	if characterRotationConnection then
		characterRotationConnection:Disconnect()
		characterRotationConnection = nil
	end

	isHoldingRotateDot = false

	if characterRotationTween and characterRotationTween.PlaybackState == Enum.PlaybackState.Playing then
		characterRotationTween:Cancel()
	end

	if Character and Character:FindFirstChildOfClass("Humanoid") then
		local humanoid = Character:FindFirstChildOfClass("Humanoid")
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50

		if originalHumanoidState then
			humanoid:ChangeState(originalHumanoidState)
			originalHumanoidState = nil
		end

		if HumanoidRootPart and HumanoidRootPart.Anchored then
			HumanoidRootPart.Anchored = false
		end
	end

	Camera.CameraType  = Enum.CameraType.Custom
	Camera.FieldOfView = 70

	if Character and HumanoidRootPart then
		local targetCFrame = HumanoidRootPart.CFrame * CFrame.new(0, 2, 8)
		local cameraTween  = TweenService:Create(
			Camera,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = targetCFrame }
		)
		cameraTween:Play()
		cameraTween.Completed:Connect(function()
			if Character and Character:FindFirstChildOfClass("Humanoid") then
				Camera.CameraSubject = Character:FindFirstChildOfClass("Humanoid")
			end
		end)
	else
		if originalCameraSubject then
			Camera.CameraSubject = originalCameraSubject
		end
	end

	currentRotationAngle    = 0
	characterRotationBarAngle = 0
	rotateDotParent.Position  = UDim2.fromScale(0.5, 0.5)
end

local function setCameraToCharacterSideView()
	if not Character or not HumanoidRootPart or not HumanoidRootPart.Parent then return end

	originalCameraCFrame  = Camera.CFrame
	originalCameraType    = Camera.CameraType
	originalCameraSubject = Camera.CameraSubject
	originalFieldOfView   = Camera.FieldOfView

	local humanoid = Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		originalHumanoidState = humanoid:GetState()
		humanoid.WalkSpeed    = 0
		humanoid.JumpPower    = 0
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	if HumanoidRootPart then
		HumanoidRootPart.Anchored = true
	end

	Camera.CameraType  = Enum.CameraType.Scriptable
	Camera.FieldOfView = 90

	local hrpPos         = HumanoidRootPart.Position
	local targetPosition = hrpPos + CAMERA_FIXED_OFFSET_FROM_HRP
	local lookAtPosition = hrpPos + CAMERA_LOOK_AT_OFFSET_FROM_HRP
	local targetCFrame   = CFrame.lookAt(targetPosition, lookAtPosition)

	local tween = TweenService:Create(Camera, TWEEN_INFO, { CFrame = targetCFrame })
	tween:Play()
end

-- ===================================================================
-- ROTATION BAR SETUP
-- ===================================================================
local function setupRotationBar()
	rotateDotButton.MouseButton1Down:Connect(function()
		isHoldingRotateDot = true
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and isHoldingRotateDot then
			isHoldingRotateDot = false
		end
	end)

	RunService.RenderStepped:Connect(function()
		if isHoldingRotateDot and HumanoidRootPart then
			local mousepos  = UserInputService:GetMouseLocation().X
			local barSizeX  = RotateFrame.bar.AbsoluteSize.X
			local barPosX   = RotateFrame.bar.AbsolutePosition.X
			local pos       = math.clamp((mousepos - barPosX) / barSizeX, 0, 1)

			rotateDotParent.Position      = UDim2.fromScale(pos, 0.5)
			characterRotationBarAngle     = math.rad(pos * 360 - 180)

			if characterRotationTween and characterRotationTween.PlaybackState == Enum.PlaybackState.Playing then
				characterRotationTween:Cancel()
			end

			characterRotationTween = TweenService:Create(
				HumanoidRootPart,
				CHARACTER_ROTATION_TWEEN_INFO,
				{ CFrame = CFrame.new(HumanoidRootPart.Position) * CFrame.Angles(0, characterRotationBarAngle, 0) }
			)
			characterRotationTween:Play()
		end
	end)
end

-- ===================================================================
-- ✅ FIXED: SHOP OPEN / CLOSE
--
-- openShop: tidak ada perubahan
-- closeShop: sekarang FireServer CloseAuraTab sebelum reset
--   Ini yang KUNCI — server akan bersihkan preview saat tab ditutup
-- ===================================================================

local function openShop()
	isShopOpen        = true
	MainFrame.Visible = true
	setCameraToCharacterSideView()
	populateShop()
	sendNotification("Default", "Aura Shop opened.", "Default", 2)
end

local function closeShop()
	isShopOpen = false
	MainFrame.Visible  = false
	PurchaseFrame.Visible = false
	selectedAuraName   = nil

	-- ✅ Beritahu server tutup tab — server bersihin preview
	-- Ini dipanggil sebelum cancelPreview() supaya server tau dulu
	if currentPreviewAura then
		CloseAuraTabEvent:FireServer()
		currentPreviewAura = nil
	end

	resetCameraToCharacterView()
	sendNotification("Default", "Aura Shop closed.", "Default", 2)
end

CloseButton.MouseButton1Click:Connect(function()
	closeShop()
end)

-- ===================================================================
-- BUY BUTTON
-- ===================================================================
BuyButton.MouseButton1Click:Connect(function()
	if not selectedAuraName or not BuyButton.Active then
		sendNotification("Error", "Cannot purchase this aura at the moment.", "Error", 3)
		return
	end

	local auraInfo = AuraData.GetAura(selectedAuraName)
	if not auraInfo or ownedAuras[selectedAuraName] then
		sendNotification("Error", "You already own this aura or it's invalid.", "Error", 3)
		return
	end

	if not AuraData.IsAuraAvailable(selectedAuraName) then
		sendNotification("Error", "This aura is no longer available for purchase.", "Error", 3)
		return
	end

	if auraInfo.CostType == "Currency" or auraInfo.CostType == "Limited" then
		PurchaseAuraEvent:FireServer(selectedAuraName)
		sendNotification("Default", "Attempting to purchase: " .. selectedAuraName .. "...", "Default", 3)
	elseif auraInfo.CostType == "Gamepass" and auraInfo.GamepassId then
		MarketplaceService:PromptGamePassPurchase(LocalPlayer, auraInfo.GamepassId)
		sendNotification("Default", "Prompting Game Pass purchase for: " .. selectedAuraName .. "...", "Default", 3)
	end
end)

-- ===================================================================
-- ✅ FIXED: EQUIP/VIEW BUTTON
--
-- SEBELUMNYA: equip langsung tanpa bersihin preview dulu
-- SEKARANG:
--   - Kalau owned → equip (server otomatis bersihin preview sebelum equip)
--   - Kalau belum owned → previewAura() → FireServer PreviewAura
-- ===================================================================
EquipORView.MouseButton1Click:Connect(function()
	if not selectedAuraName or not EquipORView.Active then
		sendNotification("Error", "Cannot perform action on this aura.", "Error", 3)
		return
	end

	local isOwned    = ownedAuras[selectedAuraName] or false
	local isEquipped = (selectedAuraName == currentEquippedAura)

	if isOwned then
		if isEquipped then
			UnequipAuraEvent:FireServer()
			currentEquippedAura = nil
			sendNotification("Default", "Unequipping aura...", "Default", 2)
		else
			-- ✅ Server akan bersihin preview dulu sebelum equip
			EquipAuraEvent:FireServer(selectedAuraName)
			currentEquippedAura = selectedAuraName
			sendNotification("Default", "Equipping: " .. selectedAuraName .. "...", "Default", 2)
		end

		-- ✅ Reset state preview setelah equip/unequip
		currentPreviewAura = nil
		populateShop()
		updatePurchaseFrame(selectedAuraName)
	else
		-- ✅ Preview — server yang handle clone
		previewAura(selectedAuraName)
	end
end)

-- ✅ Cancel preview — server yang bersihin
CancelPreviewButton.MouseButton1Click:Connect(cancelPreview)

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
local function initializeShop()
	local success, result = pcall(function()
		return GetOwnedAurasFunction:InvokeServer()
	end)

	if success and result then
		ownedAuras        = result.ownedAuras or {}
		currentEquippedAura = result.equippedAuraName
		sendNotification("Default", "Shop data initialized.", "Default", 2)
	else
		ownedAuras        = {}
		currentEquippedAura = nil
		sendNotification("Error", "Failed to load shop data.", "Error", 3)
	end

	populateShop()
	MainFrame.Visible     = false
	PurchaseFrame.Visible = false
end

-- ===================================================================
-- OWNERSHIP CHANGED EVENT
-- ===================================================================
AuraOwnershipChangedEvent.OnClientEvent:Connect(function(newOwnedAuras, newEquippedAuraName)
	ownedAuras          = newOwnedAuras or {}
	currentEquippedAura = newEquippedAuraName

	if newEquippedAuraName then
		sendNotification("Success", "Aura equipped: " .. newEquippedAuraName, "Success", 2)
	else
		sendNotification("Success", "Aura unequipped.", "Success", 2)
	end

	populateShop()

	if isShopOpen and selectedAuraName then
		updatePurchaseFrame(selectedAuraName)
	else
		PurchaseFrame.Visible = false
	end

	-- ✅ Kalau aura yang di-preview ternyata baru diequip, reset state preview
	if currentPreviewAura then
		if currentEquippedAura == currentPreviewAura then
			currentPreviewAura = nil
			-- Tidak perlu FireServer karena server sudah handle di EquipAuraEvent
		end
	end
end)

-- ===================================================================
-- ✅ CHARACTER RESPAWN
-- Saat respawn, pastikan state preview di-reset
-- ===================================================================
LocalPlayer.CharacterAdded:Connect(function(char)
	Character         = char
	HumanoidRootPart  = char:WaitForChild("HumanoidRootPart", 10)

	-- Reset state preview di client (server sudah bersihin di CharacterAdded handler)
	currentPreviewAura = nil

	if isShopOpen then
		closeShop()
	end
	resetCameraToCharacterView()
end)

-- ===================================================================
-- START
-- ===================================================================
setupRotationBar()
initializeShop()