-- Script AURA - Toggle Auras, VFX Splash, dan Aura Badan
-- ✅ FIXED: Sekarang hide/show aura semua player, bukan cuma local player

local settingsUI = script:FindFirstAncestor("SettingsUI") or script.Parent.Parent
local settingsEvents = settingsUI:WaitForChild("SettingsEvents")
local event = settingsEvents:WaitForChild("AURA")

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local aurasVisible = true
local splashVisible = true

local playerConnections = {}

local function updateAuraEffect(obj, enabled)
	if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Light") then
		obj.Enabled = enabled
	end
end

-- ✅ FIX: Loop SEMUA player, bukan cuma localPlayer
local function updateCharacterAuras(character, enabled)
	if not character then return end
	for _, obj in pairs(character:GetDescendants()) do
		-- Aura equipped
		if obj.Name:match("^Aura_") and obj.Name:match("_Equipped") then
			updateAuraEffect(obj, enabled)
			for _, child in pairs(obj:GetDescendants()) do
				updateAuraEffect(child, enabled)
			end
		end
		-- Attribute-based aura
		if obj:GetAttribute("IsAura") == true then
			updateAuraEffect(obj, enabled)
			for _, child in pairs(obj:GetDescendants()) do
				updateAuraEffect(child, enabled)
			end
		end
	end
end

local function updateAurasVisibility()
	-- Aura di workspace (non-character)
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj.Name == "Auras" and obj:IsA("ParticleEmitter") then
			obj.Enabled = aurasVisible
		end
		if (obj.Name == "AuraEffect" or obj.Name == "Auras") and (obj:IsA("Folder") or obj:IsA("Model")) then
			for _, child in pairs(obj:GetDescendants()) do
				updateAuraEffect(child, aurasVisible)
			end
		end
	end

	-- ✅ FIX: Loop SEMUA player yang ada di server
	for _, player in pairs(Players:GetPlayers()) do
		updateCharacterAuras(player.Character, aurasVisible)
	end
end

local function updateSplashVisibility()
	if _G.SetSplashVFXEnabled then
		_G.SetSplashVFXEnabled(splashVisible)
	end

	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:GetAttribute("IsSplashVFX") == true then
			if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
				obj.Enabled = splashVisible
			elseif obj:IsA("Folder") or obj:IsA("Model") then
				for _, child in pairs(obj:GetDescendants()) do
					updateAuraEffect(child, splashVisible)
				end
			end
		end

		if typeof(obj.Name) == "string" and obj.Name:find("VFX_") and obj.Name:find("Rod") then
			if obj:IsA("Folder") or obj:IsA("Model") then
				for _, child in pairs(obj:GetDescendants()) do
					updateAuraEffect(child, splashVisible)
				end
			end
		end
	end
end

-- ✅ FIX: DescendantAdded tetap apply ke semua player
workspace.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if not obj or not obj.Parent then return end

		if obj.Name == "Auras" and obj:IsA("ParticleEmitter") then
			obj.Enabled = aurasVisible
		end

		if (obj.Name == "AuraEffect" or obj.Name == "Auras") and (obj:IsA("Folder") or obj:IsA("Model")) then
			obj.DescendantAdded:Connect(function(child)
				updateAuraEffect(child, aurasVisible)
			end)
			for _, child in pairs(obj:GetChildren()) do
				updateAuraEffect(child, aurasVisible)
			end
		end

		if obj:GetAttribute("IsSplashVFX") == true then
			if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
				obj.Enabled = splashVisible
			elseif obj:IsA("Folder") or obj:IsA("Model") then
				obj.DescendantAdded:Connect(function(child)
					updateAuraEffect(child, splashVisible)
				end)
				for _, child in pairs(obj:GetChildren()) do
					updateAuraEffect(child, splashVisible)
				end
			end
		end

		-- ✅ FIX: Kalau ada aura baru di character player manapun, langsung apply
		if obj:GetAttribute("IsAura") == true
			or (obj.Name:match("^Aura_") and obj.Name:match("_Equipped")) then
			updateAuraEffect(obj, aurasVisible)
			obj.DescendantAdded:Connect(function(child)
				updateAuraEffect(child, aurasVisible)
			end)
			for _, child in pairs(obj:GetDescendants()) do
				updateAuraEffect(child, aurasVisible)
			end
		end
	end)
end)

-- ✅ FIX: Setup untuk SEMUA player, bukan cuma localPlayer
local function setupPlayerConnections(player)
	local connections = {}

	-- Monitor CharacterAdded untuk setiap player
	connections.characterAdded = player.CharacterAdded:Connect(function(character)
		task.wait(1)
		updateCharacterAuras(character, aurasVisible)
	end)

	playerConnections[player.UserId] = connections
end

local function cleanupPlayerConnections(player)
	local connections = playerConnections[player.UserId]
	if connections then
		for _, connection in pairs(connections) do
			connection:Disconnect()
		end
		playerConnections[player.UserId] = nil
	end
end

-- ✅ Setup semua player yang sudah ada
for _, player in pairs(Players:GetPlayers()) do
	setupPlayerConnections(player)
end

-- ✅ Setup player yang join setelah script load
Players.PlayerAdded:Connect(function(player)
	setupPlayerConnections(player)
	-- Kalau character sudah spawn sebelum connection dibuat
	if player.Character then
		task.wait(1)
		updateCharacterAuras(player.Character, aurasVisible)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cleanupPlayerConnections(player)
end)

-- Apply untuk semua character yang sudah ada saat ini
task.defer(function()
	updateAurasVisibility()
	updateSplashVisibility()
end)

-- ✅ Handle toggle
event.OnInvoke = function(condition)
	if typeof(condition) == "table" then
		if condition.auras ~= nil then
			aurasVisible = condition.auras
			updateAurasVisibility()
		end
		if condition.splash ~= nil then
			splashVisible = condition.splash
			updateSplashVisibility()
		end
	else
		aurasVisible = condition
		splashVisible = condition
		updateAurasVisibility()
		updateSplashVisibility()
	end

	return {auras = aurasVisible, splash = splashVisible}
end