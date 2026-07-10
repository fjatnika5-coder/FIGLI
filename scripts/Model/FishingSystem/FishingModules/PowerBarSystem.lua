-- System by @thehandofvoid
-- Modified by @jay_peaceee
-- ReplicatedStorage/FishingModules/PowerBarSystem
-- ✅ FIXED: Luck now displays correctly (no more negative values!)

local PowerBarSystem = {}
local RepStorage = game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem")
local RS = game:GetService("RunService")
local FishingConfig = require(RepStorage:WaitForChild("FishingConfig"))

local powerState = {
	isCharging = false,
	currentPower = 0,
	maxPower = 100,
	chargeSpeed = 120,
	chargingDirection = 1
}

local chargingConnection = nil
local gui = nil

function PowerBarSystem:Initialize(guiElements)
	gui = guiElements
end

function PowerBarSystem:UpdateBar(rodName)
	local powerPercent = powerState.currentPower / powerState.maxPower
	local config = FishingConfig.GetRodConfig(rodName)

	-- 🆕 FIXED: Use the corrected CalculateTotalLuck function
	local totalLuck, baseLuck, powerBonus = FishingConfig.CalculateTotalLuck(config.baseLuck, powerPercent)

	gui.fillFrame.Size = UDim2.new(1, 0, powerPercent, 0)

	local color
	if powerPercent < 0.25 then
		color = Color3.fromRGB(255, 100, 100)
	elseif powerPercent < 0.5 then
		color = Color3.fromRGB(255, 200, 100)
	elseif powerPercent < 0.75 then
		color = Color3.fromRGB(255, 255, 100)
	else
		color = Color3.fromRGB(100, 255, 100)
	end
	gui.fillFrame.BackgroundColor3 = color

	-- 🆕 FIXED: Display total luck correctly
	-- Shows the actual multiplier (e.g., "50.2x Luck" for Owner Rod)
	gui.luckMultiText.Text = string.format("%.1fx Luck", totalLuck)
end

function PowerBarSystem:StartCharging(rodName)
	powerState.isCharging = true
	powerState.currentPower = 0
	powerState.chargingDirection = 1

	gui.barFrame.Visible = true
	gui.fillFrame.Size = UDim2.new(1, 0, 0, 0)

	self:UpdateBar(rodName)

	if chargingConnection then
		chargingConnection:Disconnect()
	end

	chargingConnection = RS.Heartbeat:Connect(function(deltaTime)
		if not powerState.isCharging then return end

		powerState.currentPower += powerState.chargeSpeed * deltaTime * powerState.chargingDirection

		if powerState.currentPower >= powerState.maxPower then
			powerState.currentPower = powerState.maxPower
			powerState.chargingDirection = -1
		elseif powerState.currentPower <= 0 then
			powerState.currentPower = 0
			powerState.chargingDirection = 1
		end

		self:UpdateBar(rodName)
	end)
end

function PowerBarSystem:StopCharging()
	powerState.isCharging = false
	gui.barFrame.Visible = false

	if chargingConnection then
		chargingConnection:Disconnect()
		chargingConnection = nil
	end

	local power = powerState.currentPower
	powerState.currentPower = 0
	powerState.chargingDirection = 1

	return power
end

function PowerBarSystem:IsCharging()
	return powerState.isCharging
end

function PowerBarSystem:GetCurrentPower()
	return powerState.currentPower
end

function PowerBarSystem:Reset()
	if chargingConnection then
		chargingConnection:Disconnect()
		chargingConnection = nil
	end

	powerState.isCharging = false
	powerState.currentPower = 0
	powerState.chargingDirection = 1
end

return PowerBarSystem