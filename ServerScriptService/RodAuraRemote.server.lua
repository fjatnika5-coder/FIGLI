-- RodAuraRemote
-- Location: ServerScriptService/RodAuraRemote (Script)
--
-- AUDIT FIX:
-- [FIX I] Ownership validation. The old version let any client equip ANY aura
--         name (the ownership check was a commented-out TODO). Now the aura
--         must exist in AuraData.Auras AND be owned by the player
--         (PlayerData.Inventory.Auras child, created by PlayerHandler).
-- [FIX J] Idempotent remote creation (reuses existing RodAuraRemote).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local AuraData = require(ReplicatedStorage:WaitForChild("AuraData"))

local Remote = ReplicatedStorage:FindFirstChild("RodAuraRemote")
if not Remote or not Remote:IsA("RemoteEvent") then
	if Remote then Remote:Destroy() end
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "RodAuraRemote"
	Remote.Parent = ReplicatedStorage
end

local AURA_COOLDOWN = 0.5
local lastAuraAction = {}

local function ownsAura(player, auraName)
	local playerData = player:FindFirstChild("PlayerData")
	local inventory = playerData and playerData:FindFirstChild("Inventory")
	if not inventory then return false end

	local auras = inventory:FindFirstChild("Auras")
	if auras and auras:FindFirstChild(auraName) then
		return true
	end

	local equipped = inventory:FindFirstChild("EquippedAura")
	if equipped and equipped.Value == auraName then
		return true
	end

	return false
end

local function removeRodAura(character)
	for _, obj in ipairs(character:GetDescendants()) do
		if obj.Name:match("^Aura_") and obj.Name:match("_Equipped") then
			obj:Destroy()
		end
	end
end

Remote.OnServerEvent:Connect(function(player, action, auraName)
	if typeof(action) ~= "string" then return end
	if action ~= "Equip" and action ~= "Unequip" then return end

	local character = player.Character
	if not character then return end

	local userId = player.UserId
	local now = tick()
	if (now - (lastAuraAction[userId] or 0)) < AURA_COOLDOWN then return end
	lastAuraAction[userId] = now

	if action == "Equip" then
		if typeof(auraName) ~= "string" then return end
		if auraName == "" or #auraName > 100 then return end

		-- [FIX I] Aura must be defined and owned.
		if not AuraData.GetAura(auraName) then return end
		if not ownsAura(player, auraName) then return end

		removeRodAura(character)
		pcall(function()
			AuraData.CloneAuraComponents(auraName, character, false)
		end)
	elseif action == "Unequip" then
		removeRodAura(character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAuraAction[player.UserId] = nil
end)
