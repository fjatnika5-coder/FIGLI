--[[
	VFXPopupHandler (LocalScript)
	Taruh di: StarterGui > VFXPopupGui > VFXPopupHandler

	Fungsi:
	- Munculin popup VFX settings pas player pertama masuk
	- Simpan pilihan VFX on/off
	- Konek ke _G.SetSplashVFXEnabled() yang udah ada di FishingSystem client
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- REFERENCES UI
local vfxGui = script.Parent
local overlay = vfxGui:WaitForChild("Overlay")
local card = vfxGui:WaitForChild("Card")
local buttonRow = card:WaitForChild("ButtonRow")
local btnOff = buttonRow:WaitForChild("BtnOff")
local btnOn = buttonRow:WaitForChild("BtnOn")

-- STATE
local VFX_ENABLED_KEY = "FishingVFXEnabled"
local hasChosen = false

-- ================================================================
-- APPLY VFX PREFERENCE
-- Konek ke SEMUA sistem yang kontrol VFX di fishing client:
--   1. _G.SetSplashVFXEnabled(bool) - fungsi dari fishing script
--   2. _G.GraphicsVFXEnabled - global flag yang dicek canSpawnVFX
--   3. Player attribute - backup persistent selama session
-- ================================================================
local function applyVFXPreference(enabled)
	player:SetAttribute(VFX_ENABLED_KEY, enabled)

	if type(_G.SetSplashVFXEnabled) == "function" then
		_G.SetSplashVFXEnabled(enabled)
	end

	_G.GraphicsVFXEnabled = enabled

	print("[VFXPopup]", player.Name, "VFX =", enabled and "ON" or "OFF")
end

-- ================================================================
-- TWEEN ANIMATIONS
-- ================================================================
local TWEEN_INFO_IN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local originalCardSize = card.Size

local function showPopup()
	vfxGui.Enabled = true
	overlay.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.Size = UDim2.new(0, 0, 0, 0)
	card.Visible = true

	TweenService:Create(overlay, TWEEN_FADE, {
		BackgroundTransparency = 0.4
	}):Play()

	TweenService:Create(card, TWEEN_INFO_IN, {
		Size = originalCardSize
	}):Play()
end

local function hidePopup()
	local tweenCard = TweenService:Create(card, TWEEN_INFO_OUT, {
		Size = UDim2.new(0, 0, 0, 0)
	})
	local tweenOverlay = TweenService:Create(overlay, TWEEN_FADE, {
		BackgroundTransparency = 1
	})
	tweenCard:Play()
	tweenOverlay:Play()
	tweenCard.Completed:Wait()
	vfxGui.Enabled = false
end

-- ================================================================
-- BUTTON HANDLERS
-- ================================================================
btnOff.MouseButton1Click:Connect(function()
	if hasChosen then return end
	hasChosen = true
	applyVFXPreference(false)
	hidePopup()
end)

btnOn.MouseButton1Click:Connect(function()
	if hasChosen then return end
	hasChosen = true
	applyVFXPreference(true)
	hidePopup()
end)

-- ================================================================
-- INIT
-- ================================================================
local function init()
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(2.5)

	local existingPref = player:GetAttribute(VFX_ENABLED_KEY)
	if existingPref ~= nil then
		applyVFXPreference(existingPref)
		vfxGui.Enabled = false
		return
	end

	showPopup()
end

init()