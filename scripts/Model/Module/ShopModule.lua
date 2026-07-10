local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local module = {
	Items = {
		CashItems = require(script.CashItems),
		RobuxItems = require(script.RobuxItems),
		GroupItems = require(script.GroupItems),
		GemItems = require(script.GemItems)
	},

	Auras = {
		CashAuras = require(script.CashAuras),
		GemAuras = require(script.GemAuras),
		RobuxAuras = require(script.RobuxAuras)
	}
}

function module.GetItemData(id)
	for category, subcategory in pairs(module.Items) do
		for _, v in pairs(subcategory) do
			if v.ToolName == id then
				local isspecial = (v.Id and true) or (v.PriceType == "robux" or v.PriceType == "gem" or category == "GemItems")
				local currency = (category == "CashItems" or v.PriceType == "cash") and "cash"
					or (v.PriceType == "gem" or category == "GemItems") and "gem"
				return v, isspecial, currency
			end
		end
	end
end

function module.GetAuraData(id)
	for category, subcategory in pairs(module.Auras) do
		for _, v in pairs(subcategory) do
			if v.ModelName == id then
				local isspecial = (v.Id and true) or (v.PriceType == "robux" or v.PriceType == "gem" or category == "GemAuras")
				local currency = (category == "CashAuras" or v.PriceType == "cash") and "cash"
					or (v.PriceType == "gem" or category == "GemAuras") and "gem"
				return v, isspecial, currency
			end
		end
	end
end

function module.PlayerOwnsItem(player, itemid)
	if not player:FindFirstChild("DataLoaded") then return end
	if player.PlayerData.Inventory.Items:FindFirstChild(itemid)
		or (player.PlayerData.Gamepasses:FindFirstChild(itemid)
			and player.PlayerData.Gamepasses[itemid].Value)
	then return true end
end

function module.PlayerOwnsAura(player, auraid)
	if not player:FindFirstChild("DataLoaded") then return end
	if player.PlayerData.Inventory.Auras:FindFirstChild(auraid)
		or (player.PlayerData.Gamepasses:FindFirstChild(auraid)
			and player.PlayerData.Gamepasses[auraid].Value)
	then return true end
end

function module.PlayerCanPurchase(player,itemid)
	for i, v in pairs(module.Items.GroupItems) do
		if v.ToolName == itemid then
			return player:IsInGroup(v.GroupId)
		end
	end
	return true
end

function module.GetItemWithName(name)
	for _, category in pairs(module.Items) do
		for _, v in pairs(category) do
			if v.Name == name then return v end
		end
	end
end

function module.GetAuraWithName(name)
	for _, category in pairs(module.Auras) do
		for _, v in pairs(category) do
			if v.ModelName == name then return v end
		end
	end
end

function module.GetItemSub(name)
	for i, v in pairs(module.Items.GroupItems) do
		if i == name then return "GroupExclusive" end
	end
end

-- ✅ MEMORY LEAK FIXED VERSION - equipaura
function module.equipaura(char, auraname, condition)
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")

	-- ✅ FIX 1: Proper cleanup with ParticleEmitter stop
	local function clearTaggedAura()
		-- Stop all particle emitters FIRST before destroying
		for _, inst in ipairs(char:GetDescendants()) do
			if CollectionService:HasTag(inst, "AuraFX") then
				-- Stop particles before destroy
				if inst:IsA("ParticleEmitter") then
					inst.Enabled = false
					inst:Clear()
				elseif inst:IsA("Trail") then
					inst.Enabled = false
					inst:Clear()
				elseif inst:IsA("Beam") then
					inst.Enabled = false
				end
			end
		end

		-- Small delay to ensure particles cleared
		task.wait(0.1)

		-- Now destroy AURA model
		if char:FindFirstChild("AURA") then
			char.AURA:Destroy()
		end

		-- Destroy all tagged instances
		for _, inst in ipairs(char:GetDescendants()) do
			if CollectionService:HasTag(inst, "AuraFX") then
				pcall(function()
					CollectionService:RemoveTag(inst, "AuraFX")
					inst:Destroy()
				end)
			end
		end
	end

	-- UNEQUIP
	if not condition then
		clearTaggedAura()
		return
	end

	-- ✅ FIX 2: Safety check for character validity
	if not char or not char.Parent then
		return
	end

	local info = module.GetAuraWithName(auraname)
	if not info then return end

	-- Always cleanup old aura first
	clearTaggedAura()

	local aura = SS.ShopAssets.Auras:FindFirstChild(info.ModelName)
	if not aura then return end
	aura = aura:Clone()
	aura:SetAttribute("AuraId", auraname)

	local main = aura:FindFirstChild("Main")
	if main then
		-- ======================
		-- MODE 1: AURA dengan Main (sistem lama)
		-- ======================
		aura.Name = "AURA"
		aura.Parent = char
		aura:PivotTo(char.UpperTorso.CFrame)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = char.UpperTorso
		weld.Part1 = main
		weld.Parent = main

		-- Tag all descendants for cleanup
		for _, d in ipairs(aura:GetDescendants()) do
			CollectionService:AddTag(d, "AuraFX")
		end
		CollectionService:AddTag(aura, "AuraFX")

		-- ✅ FIX 3: Auto-cleanup on character death
		local humanoid = char:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				clearTaggedAura()
			end)
		end

		return
	end

	-- ======================
	-- MODE 2: AURA dummy tubuh (tanpa Main)
	-- ======================
	local bodyParts = {
		"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot"
	}

	for _, dummyPart in ipairs(aura:GetChildren()) do
		if table.find(bodyParts, dummyPart.Name) then
			local targetPart = char:FindFirstChild(dummyPart.Name)
			if targetPart then
				for _, obj in ipairs(dummyPart:GetChildren()) do
					-- ========== PART EFFECT (Mesh/Wings/BasePart) ==========
					if obj:IsA("BasePart") then
						local newPart = obj:Clone()
						newPart.Anchored = false
						newPart.CanCollide = false
						newPart.Massless = true
						newPart.Parent = char

						local weld = Instance.new("WeldConstraint")
						weld.Part0 = targetPart
						weld.Part1 = newPart
						weld.Parent = newPart
						newPart.CFrame = targetPart.CFrame

						-- ✅ Tag the part for cleanup
						CollectionService:AddTag(newPart, "AuraFX")
						CollectionService:AddTag(weld, "AuraFX")
					end

					-- Attachment
					if obj:IsA("Attachment") then
						local att = obj:Clone()
						att.Parent = targetPart
						CollectionService:AddTag(att, "AuraFX")

						-- Clone effects inside attachment
						for _, eff in ipairs(obj:GetChildren()) do
							if eff:IsA("ParticleEmitter") or eff:IsA("Beam") or eff:IsA("PointLight") 
								or eff:IsA("SpotLight") or eff:IsA("SurfaceLight") or eff:IsA("Trail") then
								local e = eff:Clone()
								if e:IsA("Trail") or e:IsA("Beam") or e:IsA("ParticleEmitter") then
									e.Enabled = true
								end
								e.Parent = att
								CollectionService:AddTag(e, "AuraFX")
							end
						end
					end

					-- Particle/Beam/Light directly on part
					if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("PointLight") 
						or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") or obj:IsA("Trail") then
						local e = obj:Clone()
						if e:IsA("Trail") or e:IsA("Beam") or e:IsA("ParticleEmitter") then
							e.Enabled = true
						end
						e.Parent = targetPart
						CollectionService:AddTag(e, "AuraFX")
					end

					-- GUI effects
					if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
						local g = obj:Clone()
						g.Parent = targetPart
						CollectionService:AddTag(g, "AuraFX")
					end
				end
			end
		end
	end

	-- ✅ FIX 4: Destroy template immediately
	aura:Destroy()

	-- ✅ FIX 5: Auto-cleanup on death
	local humanoid = char:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			clearTaggedAura()
		end)
	end
end

return module