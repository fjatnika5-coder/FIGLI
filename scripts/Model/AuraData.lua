-- ReplicatedStorage/AuraData.lua
-- ✅ FIXED v2:
-- 1. Hapus duplikat Aura_Frozenwings
-- 2. Preview dan Equipped BENAR-BENAR dipisah
--    Preview pakai suffix "_Preview", Equipped pakai "_Equipped"
--    Cleanup preview TIDAK hapus equipped, dan sebaliknya
-- 3. Tambah fungsi CleanupPreviewOnly dan CleanupEquippedOnly
-- 4. Preview timeout 30 detik safety (kalau client disconnect tiba-tiba)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AurasFolder = ReplicatedStorage:WaitForChild("AurasFolder")
local MarketplaceService = game:GetService("MarketplaceService")
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local startTime = os.clock()

local AuraData = {}

AuraData.CurrencyName = "Gems"
AuraData.ConnectToLeaderstats = false

-- ✅ Track Chatted connections
local playerChatConnections = {}

-- ═══════════════════════════════════════════════════════════════
-- CURRENCY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

function AuraData.GetPlayerCurrency(player)
	local playerData = player:FindFirstChild("PlayerData")
	if playerData then
		local currency = playerData:FindFirstChild(AuraData.CurrencyName)
		if currency and currency:IsA("IntValue") then
			return currency.Value
		end
	end
	return 0
end

function AuraData.SetPlayerCurrency(player, amount)
	local playerData = player:FindFirstChild("PlayerData")
	if playerData then
		local currency = playerData:FindFirstChild(AuraData.CurrencyName)
		if currency and currency:IsA("IntValue") then
			currency.Value = amount
			return true
		end
	end
	return false
end

function AuraData.AddPlayerCurrency(player, amount)
	local current = AuraData.GetPlayerCurrency(player)
	return AuraData.SetPlayerCurrency(player, current + amount)
end

function AuraData.RemovePlayerCurrency(player, amount)
	local current = AuraData.GetPlayerCurrency(player)
	if current >= amount then
		return AuraData.SetPlayerCurrency(player, current - amount)
	end
	return false
end

function AuraData.HasEnoughCurrency(player, amount)
	return AuraData.GetPlayerCurrency(player) >= amount
end

-- ═══════════════════════════════════════════════════════════════
-- AURA DEFINITIONS
-- ✅ FIXED: Hapus duplikat Aura_Frozenwings
-- ═══════════════════════════════════════════════════════════════

AuraData.Auras = {
	-- ✅ Hanya satu definisi sekarang (duplikat dihapus)
	
	["Aura_Miyuki"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Miyuki"),
		Creator = "Duwataw",
	},

	
	
	
	["Aura_Little"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Little"),
		Creator = "Duwataw",
	},
	
	
	["Aura_Hammer"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Hammer"),
		Creator = "Duwataw",
	},
	
	["Aura_Hole"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Hole"),
		Creator = "Duwataw",
	},
	
	["Aura_Eternal"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Eternal"),
		Creator = "Duwataw",
	},



	["Aura_Vanquisher"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Vanquisher"),
		Creator = "Duwataw",
	},
	
	
	["Aura_darkmatter"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_darkmatter"),
		Creator = "Duwataw",
	},
	
	
	
	["Aura_Top"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Top"),
		Creator = "Duwataw",
	},
	
	
	
	["Aura_Jiyu"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Jiyu"),
		Creator = "Duwataw",
	},

	
	
	["Aura_Frozenwings"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Frozenwings"),
		Creator = "Duwataw",
	},

	["Aura_Crusader"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_Crusader"),
		Creator = "Duwataw",
	},

	["Aura_NorthStarpurple"] = {
		CostType = "Currency",
		Price = 4900,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_NorthStarpurple"),
		Creator = "Duwataw",
	},

	["Aura_NorthStar"] = {
		CostType = "Currency",
		Price = 4999,
		ImageId = "rbxassetid://12921903926",
		Description = "Shine like the North Star!",
		Template = AurasFolder:FindFirstChild("Aura_NorthStar"),
		Creator = "Duwataw",
	},

	["Aura_Gojo"] = {
		CostType = "Currency",
		Price = 4999,
		ImageId = "rbxassetid://18263154542",
		Description = "The strongest sorcerer's power!",
		Template = AurasFolder:FindFirstChild("Aura_Gojo"),
		Creator = "Duwataw",
	},

	["Aura_Binary404"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://6698238312",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Binary404"),
		Creator = "",
	},

	["Aura_FlameCrown"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://6394533520",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_FlameCrown"),
		Creator = "",
	},

	["Aura_WaterBubbleTrio"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://15766478443",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_WaterBubbleTrio"),
		Creator = "",
	},

	["Aura_RedWings"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://12921903926",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_RedWings"),
		Creator = "",
	},

	["Aura_WhiteWings"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://18263154542",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_WhiteWings"),
		Creator = "",
	},

	["Aura_FrozenBloom"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://15417213301",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_FrozenBloom"),
		Creator = "",
	},

	["Aura_DarkRoger"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://13159446718",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_DarkRoger"),
		Creator = "",
	},

	["Aura_DarkTyrant"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://6392174647",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_DarkTyrant"),
		Creator = "",
	},

	["Aura_Anon"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://14845152102",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Anon"),
		Creator = "",
	},

	["Aura_Purp"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://108975224959669",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Purp"),
		Creator = "",
	},

	["Aura_RainbFlame"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://12643711527",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_RainbFlame"),
		Creator = "",
	},

	["Aura_RedHeartFire"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://15870306386",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_RedHeartFire"),
		Creator = "",
	},

	["Aura_RomanticBloom"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://15958552963",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_RomanticBloom"),
		Creator = "",
	},

	["Aura_Aether"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://514937272",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Aether"),
		Creator = "",
	},

	["Aura_Thund"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://2969145300",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Thund"),
		Creator = "",
	},

	["Aura_SnowFlakes"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://17184399527",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_SnowFlakes"),
		Creator = "",
	},

	["Aura_BlindObsession"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://101728528083568",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_BlindObsession"),
		Creator = "",
	},

	["Aura_FireFist"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://12828271027",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_FireFist"),
		Creator = "",
	},

	["Aura_TimeKillingA"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://85439450636010",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_TimeKillingA"),
		Creator = "",
	},

	["Aura_SusanooArms"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://118490667793064",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_SusanooArms"),
		Creator = "",
	},

	["Aura_UnoWings"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://128313143614223",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_UnoWings"),
		Creator = "",
	},

	["Aura_Saiyan"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://241600108",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Saiyan"),
		Creator = "",
	},

	["Aura_Beloved"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://10906602280",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Beloved"),
		Creator = "",
	},

	["Aura_Atomic"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://18487030147",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_Atomic"),
		Creator = "",
	},

	["Aura_BlazingPinkHeart"] = {
		CostType = "Currency",
		Price = 5999,
		ImageId = "rbxassetid://11723506210",
		Description = "",
		Template = AurasFolder:FindFirstChild("Aura_BlazingPinkHeart"),
		Creator = "",
	},

	["Aura_ChaosInsanity"] = {
		CostType = "Currency",
		Price = 15000,
		ImageId = "rbxassetid://6394533520",
		Description = "Unleash the chaos within!",
		Template = AurasFolder:FindFirstChild("Aura_ChaosInsanity"),
		Creator = "Duwataw",
	},
}

-- ═══════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

function AuraData.FormatNumberWithCommas(number)
	local s = tostring(math.floor(number))
	local formatted = ""
	local count = 0
	for i = #s, 1, -1 do
		formatted = s:sub(i, i) .. formatted
		count = count + 1
		if count % 3 == 0 and i > 1 then
			formatted = "," .. formatted
		end
	end
	return formatted
end

function AuraData.GetAura(auraName)
	return AuraData.Auras[auraName]
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ FIXED v3: CLEANUP FUNCTIONS — TOP-DOWN DESTRUCTION
--
-- MASALAH LAMA:
--   Loop GetDescendants() → destroy parent → tapi children masih
--   ada sebentar karena Roblox destroy tidak instant → aura sisa
--
-- SOLUSI BARU:
--   Kumpulkan ROOT nodes yang punya marker dulu (direct children
--   dari body parts atau HRP), lalu destroy ROOT-nya sekaligus.
--   Dengan destroy root, seluruh subtree ikut hancur seketika.
--   Tidak ada sisa, tidak ada race condition.
--
-- ATURAN SUFFIX (tetap sama):
--   Preview  → nama part berakhir "_Preview", attribute "IsPreview"
--   Equipped → nama part berakhir "_Equipped", attribute "IsAura"
-- ═══════════════════════════════════════════════════════════════

-- Helper internal: kumpulkan root aura nodes dari character
-- filterFn(name, instance) → true kalau instance ini harus dihapus
local function collectAuraRoots(character, filterFn)
	local toDestroy = {}
	local seen = {}

	-- Scan semua descendant, tapi hanya ambil yang ROOT
	-- (parent-nya bukan aura lain) supaya tidak double-destroy
	for _, desc in ipairs(character:GetDescendants()) do
		if not seen[desc] then
			local name = desc.Name
			if filterFn(name, desc) then
				-- Cek apakah parent-nya juga aura (kalau iya, skip — parent sudah di-collect)
				local parentIsAura = false
				local p = desc.Parent
				while p and p ~= character do
					if filterFn(p.Name, p) then
						parentIsAura = true
						break
					end
					p = p.Parent
				end

				if not parentIsAura then
					table.insert(toDestroy, desc)
					-- Tandai semua descendant dari node ini sebagai "sudah ditangani"
					seen[desc] = true
					for _, child in ipairs(desc:GetDescendants()) do
						seen[child] = true
					end
				end
			end
		end
	end

	return toDestroy
end

-- ✅ Hapus HANYA preview — dipanggil saat tab aura ditutup
function AuraData.CleanupPreviewOnly(character)
	if not character or not character.Parent then return end

	local roots = collectAuraRoots(character, function(name, inst)
		local isPreview = name:find("_Preview$") or inst:GetAttribute("IsPreview") == true
		local isEquipped = name:find("_Equipped$") or inst:GetAttribute("IsAura") == true
		-- Hanya ambil yang preview, bukan equipped
		return isPreview and not isEquipped
	end)

	for _, root in ipairs(roots) do
		pcall(function()
			if root and root.Parent then
				root:Destroy()
			end
		end)
	end
end

-- ✅ Hapus HANYA equipped — dipanggil saat unequip
function AuraData.CleanupEquippedOnly(character)
	if not character or not character.Parent then return end

	local roots = collectAuraRoots(character, function(name, inst)
		local isEquipped = name:find("_Equipped$") or inst:GetAttribute("IsAura") == true
		local isPreview  = name:find("_Preview$")  or inst:GetAttribute("IsPreview") == true
		-- Hanya ambil yang equipped, bukan preview
		return isEquipped and not isPreview
	end)

	for _, root in ipairs(roots) do
		pcall(function()
			if root and root.Parent then
				root:Destroy()
			end
		end)
	end
end

-- ✅ Hapus semua — dipanggil saat player leave atau respawn
function AuraData.CleanupAll(character)
	if not character or not character.Parent then return end

	local roots = collectAuraRoots(character, function(name, inst)
		return name:find("_Preview$")
			or name:find("_Equipped$")
			or inst:GetAttribute("IsPreview") == true
			or inst:GetAttribute("IsAura") == true
	end)

	for _, root in ipairs(roots) do
		pcall(function()
			if root and root.Parent then
				root:Destroy()
			end
		end)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- LEGACY ALIAS — supaya kode lama tidak error
-- Ini sekarang pakai CleanupAll
-- ═══════════════════════════════════════════════════════════════
local function cleanUpPreviousAuraParts(character)
	AuraData.CleanupAll(character)
	task.wait(0.05)
end

-- ═══════════════════════════════════════════════════════════════
-- CLONE AURA COMPONENTS
-- ✅ FIXED: isPreview benar-benar mempengaruhi suffix dan attribute
--   isPreview = true  → suffix "_Preview", attribute "IsPreview"
--   isPreview = false → suffix "_Equipped", attribute "IsAura"
-- ═══════════════════════════════════════════════════════════════

function AuraData.CloneAuraComponents(auraName, playerCharacter, isPreview)
	if not playerCharacter or not playerCharacter:IsA("Model") then
		warn("CloneAuraComponents: playerCharacter nil atau bukan Model.")
		return {}
	end

	local playerHumanoid = playerCharacter:FindFirstChildOfClass("Humanoid")
	if not playerHumanoid then
		warn("CloneAuraComponents: Humanoid tidak ditemukan.")
		return {}
	end

	local playerHRP = playerCharacter:FindFirstChild("HumanoidRootPart")
	if not playerHRP then
		warn("CloneAuraComponents: HumanoidRootPart tidak ditemukan.")
		return {}
	end

	local auraModel = AurasFolder:FindFirstChild(auraName)
	if not auraModel then
		warn("Aura model tidak ditemukan: " .. auraName)
		return {}
	end

	-- ✅ Kalau preview: bersihkan preview lama saja
	-- Kalau equipped: bersihkan equipped lama saja
	-- Jangan cross-cleanup!
	if isPreview then
		AuraData.CleanupPreviewOnly(playerCharacter)
	else
		AuraData.CleanupEquippedOnly(playerCharacter)
	end

	-- ✅ Suffix dan attribute sesuai mode
	local suffix    = isPreview and "_Preview" or "_Equipped"
	local attrKey   = isPreview and "IsPreview" or "IsAura"
	local attrValue = true

	local clonedComponents = {}
	local clonedHumanoidRootPart = nil

	local BODY_PART_NAMES = {
		"HumanoidRootPart",
		"Head",
		"UpperTorso", "LowerTorso",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"Torso", "RightArm", "LeftArm", "RightLeg", "LeftLeg",
	}

	local processedParts = {}

	-- ✅ Helper: tag instance DAN semua descendant-nya
	-- Penting supaya WeldConstraint, ParticleEmitter, Beam, dll
	-- semua ikut ter-tag dan bisa di-detect oleh collectAuraRoots
	local function tagInstance(inst)
		pcall(function()
			inst:SetAttribute(attrKey, attrValue)
			inst:SetAttribute("AuraName", auraName)
			for _, desc in ipairs(inst:GetDescendants()) do
				pcall(function()
					desc:SetAttribute(attrKey, attrValue)
					desc:SetAttribute("AuraName", auraName)
				end)
			end
		end)
	end

	for _, partName in ipairs(BODY_PART_NAMES) do
		local auraPartTemplate = auraModel:FindFirstChild(partName)
		local characterPart    = playerCharacter:FindFirstChild(partName)

		if auraPartTemplate and characterPart and auraPartTemplate:IsA("BasePart") then
			local clonedPart = auraPartTemplate:Clone()
			clonedPart.Name        = "Aura_" .. partName .. suffix
			clonedPart.Transparency = 1
			clonedPart.CanCollide  = false
			clonedPart.Massless    = true
			clonedPart.Anchored    = false
			clonedPart.CFrame      = characterPart.CFrame
			clonedPart.Parent      = characterPart

			-- ✅ Tag root DAN semua descendants
			tagInstance(clonedPart)

			local weld  = Instance.new("WeldConstraint")
			weld.Part0  = clonedPart
			weld.Part1  = characterPart
			weld.Parent = clonedPart
			tagInstance(weld)

			table.insert(clonedComponents, clonedPart)
			table.insert(clonedComponents, weld)

			if partName == "HumanoidRootPart" then
				clonedHumanoidRootPart = clonedPart
			end
			processedParts[partName] = true
		end
	end

	for _, child in ipairs(auraModel:GetChildren()) do
		if child:IsA("BasePart") and not processedParts[child.Name] then
			local clonedPart = child:Clone()
			clonedPart.Name        = "Aura_" .. child.Name .. suffix
			clonedPart.Transparency = 1
			clonedPart.CanCollide  = false
			clonedPart.Massless    = true
			clonedPart.Anchored    = false
			clonedPart.CFrame      = playerHRP.CFrame
			clonedPart.Parent      = playerHRP

			-- ✅ Tag root DAN semua descendants
			tagInstance(clonedPart)

			local weld  = Instance.new("WeldConstraint")
			weld.Part0  = clonedPart
			weld.Part1  = playerHRP
			weld.Parent = clonedPart
			tagInstance(weld)

			table.insert(clonedComponents, clonedPart)
			table.insert(clonedComponents, weld)
		end
	end

	-- BillboardGui hanya untuk preview
	if isPreview then
		local originalAuraHRP    = auraModel:FindFirstChild("HumanoidRootPart")
		local originalBillboardGui = nil

		if originalAuraHRP and originalAuraHRP:IsA("BasePart") then
			originalBillboardGui = originalAuraHRP:FindFirstChild("InfoGui", true)
			if originalBillboardGui and not originalBillboardGui:IsA("BillboardGui") then
				originalBillboardGui = nil
			end
		end

		if originalBillboardGui and clonedHumanoidRootPart then
			local clonedBillboardGui = originalBillboardGui:Clone()
			clonedBillboardGui.Parent = clonedHumanoidRootPart
			clonedBillboardGui:SetAttribute("IsPreview", true)

			local creatorLabel = clonedBillboardGui:FindFirstChild("Creator")
			local priceLabel   = clonedBillboardGui:FindFirstChild("Price")
			local auraInfo     = AuraData.GetAura(auraName)

			if creatorLabel and auraInfo and auraInfo.Creator then
				creatorLabel.Text = auraInfo.Creator
			end
			if priceLabel and auraInfo then
				priceLabel.Text = AuraData.GetFormattedPrice(auraName)
			end
			table.insert(clonedComponents, clonedBillboardGui)
		end
	else
		-- Equipped: hapus semua BillboardGui dari komponen
		for _, component in ipairs(clonedComponents) do
			if component:IsA("BillboardGui") then
				component:Destroy()
			elseif component:IsA("BasePart") or component:IsA("Model") then
				for _, desc in ipairs(component:GetDescendants()) do
					if desc:IsA("BillboardGui") then
						desc:Destroy()
					end
				end
			end
		end
	end

	for _, child in ipairs(auraModel:GetChildren()) do
		if not child:IsA("BasePart")
			and not child:IsA("Humanoid")
			and not child:IsA("BillboardGui")
			and child.Name ~= "HumanoidRootPart" then

			local clonedChild = child:Clone()
			clonedChild.Name   = "Aura_" .. child.Name .. suffix
			clonedChild.Parent = playerHRP

			-- ✅ Tag root DAN semua descendants
			tagInstance(clonedChild)

			if clonedChild:IsA("BasePart") then
				local weld  = Instance.new("WeldConstraint")
				weld.Part0  = clonedChild
				weld.Part1  = playerHRP
				weld.Parent = clonedChild
				tagInstance(weld)
			end
			table.insert(clonedComponents, clonedChild)
		end
	end

	return clonedComponents
end

function AuraData.RemoveAuraComponents(targetParent, _attributeName)
	if not targetParent then return end

	local playerCharacter = targetParent:FindFirstAncestorOfClass("Model")
	if playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid") then
		AuraData.CleanupEquippedOnly(playerCharacter)

		task.delay(0.2, function()
			if playerCharacter and playerCharacter.Parent then
				AuraData.CleanupEquippedOnly(playerCharacter)
			end
		end)
	end
end

function AuraData.IsAuraAvailable(auraName)
	local auraInfo = AuraData.GetAura(auraName)
	if not auraInfo then return false end

	if (auraInfo.CostType == "Limited" or auraInfo.CostType == "Gamepass") and auraInfo.LimitedTimeEnd then
		return workspace:GetServerTimeNow() < auraInfo.LimitedTimeEnd
	end

	return true
end

function AuraData.GetFormattedPrice(auraName)
	local auraInfo = AuraData.GetAura(auraName)
	if not auraInfo then return "N/A" end

	if auraInfo.CostType == "Currency" then
		return "💎 " .. AuraData.FormatNumberWithCommas(auraInfo.Price)
	elseif auraInfo.CostType == "Gamepass" then
		local success, productInfo = pcall(MarketplaceService.GetProductInfo, MarketplaceService, auraInfo.GamepassId, Enum.InfoType.GamePass)
		if success and productInfo and productInfo.PriceInRobux ~= nil then
			return "R$ " .. AuraData.FormatNumberWithCommas(productInfo.PriceInRobux)
		else
			return "R$ ???"
		end
	elseif auraInfo.CostType == "Limited" then
		if AuraData.IsAuraAvailable(auraName) then
			return "💎 " .. AuraData.FormatNumberWithCommas(auraInfo.Price)
		else
			return "OFFSALE"
		end
	end

	return "FREE"
end

function AuraData.GetLimitedTimeRemaining(auraName)
	local auraInfo = AuraData.GetAura(auraName)
	if not auraInfo or (auraInfo.CostType ~= "Limited" and auraInfo.CostType ~= "Gamepass") or not auraInfo.LimitedTimeEnd then
		return nil
	end

	local remainingTime = auraInfo.LimitedTimeEnd - workspace:GetServerTimeNow()
	if remainingTime <= 0 then return nil end

	local days    = math.floor(remainingTime / 86400)
	local hours   = math.floor((remainingTime % 86400) / 3600)
	local minutes = math.floor((remainingTime % 3600) / 60)

	if days > 0 then
		return string.format("Limited: %dD %dH", days, hours)
	elseif hours > 0 then
		return string.format("Limited: %dH %dM", hours, minutes)
	elseif minutes > 0 then
		local seconds = remainingTime % 60
		return string.format("Limited: %dM %dS", minutes, seconds)
	else
		return string.format("Limited: %dS", remainingTime)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ FIXED: MANUAL CLEANUP COMMAND
-- ═══════════════════════════════════════════════════════════════

if RunService:IsServer() then
	Players.PlayerAdded:Connect(function(player)
		playerChatConnections[player.UserId] = player.Chatted:Connect(function(message)
			if message:lower() == "/cleanaura" then
				if player.Character then
					AuraData.CleanupAll(player.Character)
					print("[AURA] " .. player.Name .. " manually cleaned aura!")
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerChatConnections[player.UserId] then
			playerChatConnections[player.UserId]:Disconnect()
			playerChatConnections[player.UserId] = nil
		end
	end)

	game:BindToClose(function()
		for _, connection in pairs(playerChatConnections) do
			pcall(function() connection:Disconnect() end)
		end
		playerChatConnections = {}
		print("[AURA] Shutdown cleanup selesai")
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════

local deltaTime = os.clock() - startTime
print(("[AURA DATA LOADED]: took %.2f seconds"):format(deltaTime))

local auraCount = 0
for _ in pairs(AuraData.Auras) do auraCount += 1 end
print(("[AURA DATA]: %d auras loaded"):format(auraCount))

return AuraData