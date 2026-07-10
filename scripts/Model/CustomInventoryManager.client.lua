--[[
	CustomInventoryManager (Client) V4.2
	CHANGES from V4.1:
	  [FAV-1] buildGuiRefs: cari IV.FavoriteButton di Footer
	  [FAV-2] updateFavoriteButtonVisual: update text & warna toggle button
	  [FAV-3] setupButtons: connect Favorite button → toggle favoriteMode
	  [FAV-4] switchTab: FavoriteButton cuma tampil di tab Fish
	  [FAV-5] populateFishGrid: star visual lebih jelas + mode-aware
	  + 3 FIX TEXTURE ROD dari V4.1 tetap ada
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local StarterPack = game:GetService("StarterPack")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local FishingConfig = require(FishingSystem:WaitForChild("FishingConfig"))
local RarityColors = FishingConfig.RarityColors
local GlobalLuckVal = FishingSystem:WaitForChild("GlobalLuckMultiplier")
local fishAssetFolder = FishingSystem:WaitForChild("Assets"):WaitForChild("Fish")

local EventsFolder = FishingSystem:FindFirstChild("FishingSystemEvents") or FishingSystem:FindFirstChild("InventoryEvents") or FishingSystem:WaitForChild("InventoryEvents", 10)
if not EventsFolder then warn("[V4] Events folder not found!") return end

local rfGetData = EventsFolder:WaitForChild("Inventory_GetData")
local rfToggleFavorite = EventsFolder:WaitForChild("Inventory_ToggleFavorite")
local rfSellAll = EventsFolder:WaitForChild("Inventory_SellAll")
local reEquipRod = EventsFolder:WaitForChild("Inventory_EquipRod")
local reEquipFish = EventsFolder:WaitForChild("Inventory_EquipFish")
local reUnequipAll = EventsFolder:WaitForChild("Inventory_UnequipAll")
local reEquipTool = EventsFolder:WaitForChild("Inventory_EquipTool")
local rfSaveHotbar = EventsFolder:FindFirstChild("Inventory_SaveHotbar")
local rfLoadHotbar = EventsFolder:FindFirstChild("Inventory_LoadHotbar")
local reEquipSkin = EventsFolder:FindFirstChild("EquipRodSkin")
local reRefreshInv = EventsFolder:FindFirstChild("RefreshInventory")

local function playSound(name)
	local snd = SoundService:FindFirstChild(name)
	if snd then if snd.IsPlaying then snd:Stop() end pcall(function() snd:Play() end) end
end

local isInventoryOpen = false
local currentTab = "Fish"
local lastTab = "Fish"
local lastFetchTime = 0
local favoriteMode = false
local allFishData = {}
local allRodData = {}
local rodTextureCache = {}
local skinTextureCache = {}
local rodShopCache = {}
local equippedRodSkin = nil
local hotbar = { rod = nil, equippedItems = {} }
local MAX_EQUIPPED_ITEMS = 4
local hotbarSlotInstances = {}
local renderScheduled = false
local RARITY_ORDER = { Secret=9, Mitos=8, Unknown=10, Legendary=7, Mythical=6, Epic=5, Rare=4, Uncommon=3, Common=2, Starter=1 }
local HB = {}
local IV = {}
local Templates = { Fish = nil, Rod = nil }

local function cleanAssetId(raw)
	if not raw or raw == "" then return "" end
	local s = tostring(raw)
	if s == "0" then return "" end
	if s:match("^rbxassetid://") then
		local id = s:match("rbxassetid://(%d+)")
		return (id and tonumber(id) ~= 0) and ("rbxassetid://"..id) or ""
	end
	local id = s:match("%d+")
	return (id and tonumber(id) ~= 0) and ("rbxassetid://"..id) or ""
end

local function clearChildren(p) if not p then return end for _,c in ipairs(p:GetChildren()) do if c:IsA("GuiObject") and not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UIAspectRatioConstraint") and not c:IsA("UISizeConstraint") and not c:IsA("UIFlexItem") then c:Destroy() end end end

local function makeClickable(inst, cb)
	if inst:IsA("ImageButton") or inst:IsA("TextButton") then inst.MouseButton1Click:Connect(cb) return inst end
	local btn = Instance.new("TextButton") btn.Name="__Click" btn.Size=UDim2.fromScale(1,1) btn.BackgroundTransparency=1 btn.Text="" btn.ZIndex=(inst.ZIndex or 1)+5 btn.Parent=inst btn.MouseButton1Click:Connect(cb) return btn
end

-- ═══════════════════════════════════════════════════════════════
-- [FAV-2] UPDATE FAVORITE BUTTON VISUAL
-- ═══════════════════════════════════════════════════════════════
local function updateFavoriteButtonVisual()
	local btn = IV.FavoriteButton
	if not btn then return end

	local container = IV.FavoriteFrame or btn

	local label = container:FindFirstChild("Label")
		or container:FindFirstChildOfClass("TextLabel")
		or btn:FindFirstChild("Label")
		or btn:FindFirstChildOfClass("TextLabel")

	if label and label:IsA("TextLabel") then
		label.Text = favoriteMode and "Favorite: ON" or "Favorite: OFF"
		label.TextColor3 = Color3.fromRGB(0, 0, 0)
	elseif btn:IsA("TextButton") then
		btn.Text = favoriteMode and "Favorite: ON" or "Favorite: OFF"
		btn.TextColor3 = Color3.fromRGB(0, 0, 0)
	end

	local targetColor = favoriteMode
		and Color3.fromRGB(80, 65, 15)
		or Color3.fromRGB(40, 40, 40)

	if container:IsA("GuiObject") and container.BackgroundTransparency < 1 then
		TweenService:Create(container, TweenInfo.new(0.15), {
			BackgroundColor3 = targetColor
		}):Play()
	end

	local indicator = container:FindFirstChild("Indicator")
		or container:FindFirstChild("Dot")
		or container:FindFirstChild("Circle")
		or container:FindFirstChild("Vector")
	if indicator and indicator:IsA("ImageLabel") then
		indicator.ImageColor3 = favoriteMode
			and Color3.fromRGB(100, 255, 100)
			or Color3.fromRGB(255, 80, 80)
	elseif indicator and indicator:IsA("Frame") then
		indicator.BackgroundColor3 = favoriteMode
			and Color3.fromRGB(100, 255, 100)
			or Color3.fromRGB(255, 80, 80)
	end
end

local function buildGuiRefs()
	local gui = playerGui:WaitForChild("CustomInventoryGui",10)
	if not gui then warn("[V4] CustomInventoryGui not found!") return false end
	local hotbarFrame = gui:WaitForChild("HotbarFrame",10)
	if not hotbarFrame then warn("[V4] HotbarFrame not found!") return false end
	HB.Frame=hotbarFrame HB.RodSlot=hotbarFrame:FindFirstChild("RodSlot") HB.BagButton=hotbarFrame:FindFirstChild("BagButton") HB.FishSlot=hotbarFrame:FindFirstChild("FishSlot") HB.ToolSlot=hotbarFrame:FindFirstChild("ToolSlot")
	local tf = gui:FindFirstChild("Templates")
	if tf then
		local tile=tf:FindFirstChild("TileTemplate") if tile and not Templates.Fish then Templates.Fish=tile:Clone() Templates.Fish.Parent=nil end
		local rod=tf:FindFirstChild("RodTemplate") if rod and not Templates.Rod then Templates.Rod=rod:Clone() Templates.Rod.Parent=nil local pd=Templates.Rod:FindFirstChild("Padded") if pd then local ts=pd:FindFirstChild("Top") local eas=ts and ts:FindFirstChild("EquipAsSkin") if eas then eas.Visible=false end end end
	end
	local mainFrame = gui:FindFirstChild("MainInventoryFrame")
	if not mainFrame then warn("[V4] MainInventoryFrame not found!") return false end
	IV.Frame = mainFrame
	local header = mainFrame:FindFirstChild("Header")
	IV.CloseButton = header and header:FindFirstChild("CloseButton")
	if not IV.CloseButton then for _,d in ipairs(mainFrame:GetDescendants()) do local n=d.Name:lower() if (n=="closebutton" or n=="close" or n=="x") and (d:IsA("TextButton") or d:IsA("ImageButton")) then IV.CloseButton=d break end end end
	local tabsFrame = mainFrame:FindFirstChild("TabsFrame")
	if tabsFrame then
		IV.FishTabButton=tabsFrame:FindFirstChild("FishTabButton") or tabsFrame:FindFirstChild("Fish")
		IV.RodTabButton=tabsFrame:FindFirstChild("RodTabButton") or tabsFrame:FindFirstChild("Rods") or tabsFrame:FindFirstChild("Rod")
		IV.ToolTabButton=tabsFrame:FindFirstChild("ToolTabButton") or tabsFrame:FindFirstChild("Tools") or tabsFrame:FindFirstChild("Tool") or tabsFrame:FindFirstChild("Items")
		if not IV.FishTabButton or not IV.RodTabButton or not IV.ToolTabButton then for _,btn in ipairs(tabsFrame:GetChildren()) do if btn:IsA("TextButton") or btn:IsA("ImageButton") then local n=btn.Name:lower() if n:find("fish") and not IV.FishTabButton then IV.FishTabButton=btn elseif n:find("rod") and not IV.RodTabButton then IV.RodTabButton=btn elseif (n:find("tool") or n:find("item")) and not IV.ToolTabButton then IV.ToolTabButton=btn end end end end
	end
	local contentFrame = mainFrame:FindFirstChild("ContentFrame")
	if contentFrame then IV.FishContent=contentFrame:FindFirstChild("FishContent") IV.RodContent=contentFrame:FindFirstChild("RodContent") IV.ToolContent=contentFrame:FindFirstChild("ToolContent") end
	local footer = mainFrame:FindFirstChild("Footer")
	if footer then
		IV.FishCountLabel=footer:FindFirstChild("FishCountLabel")
		local btnFrame=footer:FindFirstChild("Button") or footer:FindFirstChild("SellAllButton") or footer:FindFirstChild("SellAll")
		if btnFrame then IV.SellAllFrame=btnFrame
			if btnFrame:IsA("TextButton") or btnFrame:IsA("ImageButton") then IV.SellAllButton=btnFrame
			else for _,d in ipairs(btnFrame:GetDescendants()) do if d:IsA("TextButton") or d:IsA("ImageButton") then IV.SellAllButton=d break end end
				if not IV.SellAllButton then local o=Instance.new("TextButton") o.Name="__SellClick" o.Size=UDim2.fromScale(1,1) o.BackgroundTransparency=1 o.Text="" o.ZIndex=(btnFrame.ZIndex or 1)+5 o.Parent=btnFrame IV.SellAllButton=o end
			end
		end
	end

	-- [FAV-1] Cari Favorite — direct child dari MainInventoryFrame (bukan Footer)
	local favFrame = mainFrame:FindFirstChild("Favorite")
	-- Fallback: cari di seluruh descendants kalau nggak ketemu langsung
	if not favFrame then
		for _, desc in ipairs(mainFrame:GetDescendants()) do
			if desc.Name == "Favorite" and desc:IsA("GuiObject") then
				favFrame = desc
				break
			end
		end
	end

	if favFrame then
		IV.FavoriteFrame = favFrame

		if favFrame:IsA("TextButton") or favFrame:IsA("ImageButton") then
			IV.FavoriteButton = favFrame
		else
			local clickable = nil
			for _, child in ipairs(favFrame:GetDescendants()) do
				if child:IsA("TextButton") or child:IsA("ImageButton") then
					clickable = child
					break
				end
			end

			if clickable then
				IV.FavoriteButton = clickable
			else
				local old = favFrame:FindFirstChild("__FavClick")
				if old then old:Destroy() end

				local overlay = Instance.new("ImageButton")
				overlay.Name = "__FavClick"
				overlay.Size = UDim2.fromScale(1, 1)
				overlay.Position = UDim2.fromScale(0, 0)
				overlay.AnchorPoint = Vector2.new(0, 0)
				overlay.BackgroundTransparency = 1
				overlay.Image = ""
				overlay.AutoButtonColor = false
				overlay.Active = true
				overlay.ZIndex = 999
				overlay.Parent = favFrame
				IV.FavoriteButton = overlay
			end
		end
	end
	mainFrame.Visible = false
	return true
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function applyMobileLayout()
	if not isMobile then return end
	if HB.Frame then
		HB.Frame.AnchorPoint=Vector2.new(0.5,1) HB.Frame.Position=UDim2.new(0.5,0,0.94,0)
		local fs=HB.Frame.Size
		if fs.Y.Offset>0 then HB.Frame.Size=UDim2.new(fs.X.Scale,math.floor(fs.X.Offset*2),fs.Y.Scale,math.floor(fs.Y.Offset*2))
		elseif fs.Y.Scale>0 then HB.Frame.Size=UDim2.new(fs.X.Scale*2,fs.X.Offset,fs.Y.Scale*2,fs.Y.Offset) end
		for _,child in ipairs(HB.Frame:GetChildren()) do if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then local cs=child.Size if cs.X.Offset>0 then child.Size=UDim2.new(cs.X.Scale,math.floor(cs.X.Offset*2),cs.Y.Scale,math.floor(cs.Y.Offset*2)) end end end
	end
	if IV.Frame then IV.Frame.AnchorPoint=Vector2.new(0.5,0.5) IV.Frame.Position=UDim2.new(0.5,0,0.48,0) IV.Frame.Size=UDim2.new(0.88,0,0.75,0) end
end

local function resolveTexture(itemType, itemId, fishData)
	if itemType == "Rod" then
		if rodTextureCache[itemId] and rodTextureCache[itemId] ~= "" then return rodTextureCache[itemId] end
		local shop = rodShopCache[itemId]
		if shop and shop.TextureId and shop.TextureId ~= "" then return shop.TextureId end
		local tool = player.Backpack:FindFirstChild(itemId) or (player.Character and player.Character:FindFirstChild(itemId))
		if tool and tool:IsA("Tool") then
			local tex = cleanAssetId(tool.TextureId or "")
			if tex ~= "" then rodTextureCache[itemId] = tex end
			return tex
		end
		return ""
	elseif itemType == "Skin" then return skinTextureCache[itemId] or ""
	elseif itemType == "Fish" and fishData then
		local asset = fishAssetFolder:FindFirstChild(fishData.name or itemId)
		if asset then local id = tostring(asset.TextureId):match("%d+") if id and id ~= "" then return "rbxassetid://"..id end end
		return ""
	else
		local tool = player.Backpack:FindFirstChild(itemId) or (player.Character and player.Character:FindFirstChild(itemId))
		if tool then return cleanAssetId(tool.TextureId or "") end return ""
	end
end

local function updateFishCount() if IV.FishCountLabel then local m=FishingConfig.InventoryLimitSettings and FishingConfig.InventoryLimitSettings.maxFishInventory or 5000 IV.FishCountLabel.Text=string.format("Fish: %d/%d",#allFishData,m) end end

local function renderRodSlot()
	if not HB.RodSlot then return end
	local canvas=HB.RodSlot:FindFirstChild("CanvasGroup") local img
	if canvas then img=canvas:FindFirstChild("RodImage") or canvas:FindFirstChildWhichIsA("ImageLabel") or canvas:FindFirstChildWhichIsA("ImageButton") end
	if not img then img=HB.RodSlot:FindFirstChild("RodImage",true) or HB.RodSlot:FindFirstChildWhichIsA("ImageLabel") end
	if not img then return end
	if not hotbar.rod or hotbar.rod=="" then img.Image="" return end
	local texture="" if equippedRodSkin and equippedRodSkin~="" then texture=skinTextureCache[equippedRodSkin] or "" end
	if texture=="" then texture=resolveTexture("Rod",hotbar.rod) end
	if texture~="" then img.Image=texture img.ImageColor3=Color3.fromRGB(255,255,255) img.ImageTransparency=0 img.BackgroundTransparency=1 else img.Image="" end
end

local function renderRodName()
	if not HB.RodSlot then return end
	local lbl=HB.RodSlot:FindFirstChild("RodName",true) or HB.RodSlot:FindFirstChild("Label",true) or HB.RodSlot:FindFirstChild("ItemName",true)
	if lbl and lbl:IsA("TextLabel") then lbl.Text=hotbar.rod or "" lbl.Visible=(hotbar.rod~=nil and hotbar.rod~="") end
end

local function cloneHotbarSlot(index, template)
	local slot=template:Clone() slot.Name=template.Name..index slot.Visible=true slot.LayoutOrder=2+index
	local iv=slot:FindFirstChild("InputVisual") local label=iv and iv:FindFirstChild("Label")
	if label then label.Text=tostring(2+index) label.Visible=true end slot.Parent=HB.Frame return slot
end

local saveHotbarToServer

local function renderHotbarItems()
	if renderScheduled then return end renderScheduled=true
	task.defer(function()
		renderScheduled=false
		for _,slot in ipairs(hotbarSlotInstances) do if slot and slot.Parent then slot:Destroy() end end table.clear(hotbarSlotInstances)
		for i,item in ipairs(hotbar.equippedItems) do
			if i>MAX_EQUIPPED_ITEMS then break end
			local template=(item.type=="Fish") and HB.FishSlot or HB.ToolSlot if not template then continue end
			local slot=cloneHotbarSlot(i,template) table.insert(hotbarSlotInstances,slot)
			local canvas=slot:FindFirstChild("CanvasGroup") local img
			if canvas then img=canvas:FindFirstChild("RodImage") or canvas:FindFirstChild("FishImage") or canvas:FindFirstChild("ToolImage") or canvas:FindFirstChildWhichIsA("ImageLabel") or canvas:FindFirstChildWhichIsA("ImageButton")
			else img=slot:FindFirstChild("FishImage") or slot:FindFirstChild("ToolImage") or slot:FindFirstChildWhichIsA("ImageLabel") end
			if img then local tex=resolveTexture(item.type,item.id,item.data) if tex and tex~="" then img.Image=tex img.ImageColor3=Color3.fromRGB(255,255,255) img.ImageTransparency=0 img.BackgroundTransparency=1 end end
			if item.type=="Fish" then local iv=slot:FindFirstChild("InputVisual") local star=iv and iv:FindFirstChild("Star") if star and item.data then star.Visible=item.data.isFavorited or false end end
			local slotIndex=i
			slot.MouseButton1Click:Connect(function()
				local itemData=hotbar.equippedItems[slotIndex] if not itemData then return end
				local char=player.Character local curTool=char and char:FindFirstChildOfClass("Tool") local isHolding=false
				if curTool then if itemData.type=="Fish" and curTool:FindFirstChild("FishId") then isHolding=curTool.FishId.Value==itemData.id elseif itemData.type=="Tool" and curTool.Name==itemData.id then isHolding=true end end
				if isInventoryOpen then table.remove(hotbar.equippedItems,slotIndex) reUnequipAll:FireServer() renderHotbarItems() saveHotbarToServer() return end
				if isHolding then reUnequipAll:FireServer() else playSound("EquipSound") if itemData.type=="Fish" then reEquipFish:FireServer(itemData.id) else reEquipTool:FireServer(itemData.id) end end
			end)
		end
		renderRodName() renderRodSlot()
	end)
end

saveHotbarToServer = function()
	renderHotbarItems()
	if rfSaveHotbar then task.spawn(function() pcall(function() rfSaveHotbar:InvokeServer({rod=hotbar.rod,equippedItems=hotbar.equippedItems}) end) end) end
end

local function loadHotbarFromServer() if not rfLoadHotbar then return end local ok,data=pcall(function() return rfLoadHotbar:InvokeServer() end) if ok and data then hotbar.rod=data.rod hotbar.equippedItems=data.equippedItems or {} end renderHotbarItems() renderRodSlot() end

local function validateHotbar()
	if hotbar.rod then local found=false for _,r in ipairs(allRodData) do if r==hotbar.rod then found=true break end end if not found then hotbar.rod=nil end end
	local valid={} for _,item in ipairs(hotbar.equippedItems) do
		if item.type=="Fish" then local exists=false for _,f in ipairs(allFishData) do if f.uniqueId==item.id then item.data=f exists=true break end end if exists then table.insert(valid,item) end
		elseif item.type=="Tool" then local bp=player:FindFirstChildOfClass("Backpack") local char=player.Character if (bp and bp:FindFirstChild(item.id)) or (char and char:FindFirstChild(item.id)) then table.insert(valid,item) end end
	end
	local changed=#valid<#hotbar.equippedItems hotbar.equippedItems=valid if changed then renderHotbarItems() saveHotbarToServer() end
end

local function validateFishInHotbar()
	local changed=false for i=#hotbar.equippedItems,1,-1 do local item=hotbar.equippedItems[i]
		if item.type=="Fish" then local exists=false for _,f in ipairs(allFishData) do if f.uniqueId==item.id then exists=true break end end if not exists then table.remove(hotbar.equippedItems,i) changed=true end end
	end if changed then renderHotbarItems() saveHotbarToServer() end
end

local function fetchAllData()
	local now=tick() if now-lastFetchTime<0.5 then return false end lastFetchTime=now
	local ok,data=pcall(function() return rfGetData:InvokeServer() end) if not ok or not data then return false end
	allFishData=data.Fish or {} allRodData=data.Rods or {}
	if data.RodTextures then for name,tex in pairs(data.RodTextures) do local c=cleanAssetId(tex) if c~="" then rodTextureCache[name]=c end end end
	if data.SkinTextures then for name,tex in pairs(data.SkinTextures) do local c=cleanAssetId(tex) if c~="" then skinTextureCache[name]=c end end end
	if next(rodShopCache)==nil then
		local se=FishingSystem:FindFirstChild("RodShopEvents")
		if se then local ok2,sd=pcall(function() return se.GetShopData:InvokeServer() end) if ok2 and sd and sd.AllRodData then for rn,rd in pairs(sd.AllRodData) do rodShopCache[rn]={Stats=rd.Stats,TextureId=cleanAssetId(rd.TextureId or "")} if not rodTextureCache[rn] and rodShopCache[rn].TextureId~="" then rodTextureCache[rn]=rodShopCache[rn].TextureId end end end end
	end
	local function scanRodTextures(container) if not container then return end for _,tool in ipairs(container:GetChildren()) do if tool:IsA("Tool") and CollectionService:HasTag(tool,"Rod") then if not rodTextureCache[tool.Name] or rodTextureCache[tool.Name]=="" then local tex=cleanAssetId(tool.TextureId or "") if tex~="" then rodTextureCache[tool.Name]=tex end end end end end
	scanRodTextures(player:FindFirstChildOfClass("Backpack")) scanRodTextures(player.Character)
	validateHotbar() validateFishInHotbar() updateFishCount() renderRodSlot() return true,data
end

-- ═══════════════════════════════════════════════════════════════
-- [FAV-5] POPULATE FISH GRID — star visual mode-aware
-- Mode ON:  semua ikan tampil bintang (emas=favorit, abu=belum)
--           klik ikan = toggle favorit
-- Mode OFF: bintang cuma muncul di ikan yang sudah favorit (indicator)
--           klik ikan = equip ke hotbar
-- ═══════════════════════════════════════════════════════════════
local function populateFishGrid()
	if not IV.FishContent or not Templates.Fish then return end clearChildren(IV.FishContent)
	table.sort(allFishData,function(a,b) if a.isFavorited~=b.isFavorited then return a.isFavorited and not b.isFavorited end local ra=RARITY_ORDER[a.rarity] or 0 local rb=RARITY_ORDER[b.rarity] or 0 if ra~=rb then return ra>rb end return (a.weight or 0)>(b.weight or 0) end)
	if #allFishData==0 then local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,0,50) lbl.Position=UDim2.new(0,0,0.3,0) lbl.BackgroundTransparency=1 lbl.Text="No fish yet! Go fishing!" lbl.TextColor3=Color3.fromRGB(150,150,150) lbl.TextSize=16 lbl.Font=Enum.Font.Gotham lbl.Parent=IV.FishContent return end
	local batchIndex=0
	local function renderBatch()
		local batchEnd=math.min(batchIndex+20,#allFishData)
		for i=batchIndex+1,batchEnd do
			local fish=allFishData[i] local card=Templates.Fish:Clone() card.Name=fish.uniqueId or tostring(i) card.Visible=true
			local fishImg=card:FindFirstChild("FishImage") local nameLabel=card:FindFirstChild("FishName") local rarityLabel=card:FindFirstChild("FishRarity") local weightLabel=card:FindFirstChild("FishWeight") local favBtn=card:FindFirstChild("FavoriteButton",true) local uiStroke=card:FindFirstChild("UIStroke")
			if nameLabel and nameLabel:IsA("TextLabel") then nameLabel.Text=fish.name or "Unknown Fish" if RarityColors and RarityColors[fish.rarity] then nameLabel.TextColor3=RarityColors[fish.rarity] end end
			local tex=resolveTexture("Fish",fish.uniqueId,fish) if fishImg then fishImg.Image=tex end
			if weightLabel and weightLabel:IsA("TextLabel") then weightLabel.Text=string.format("%.1fkg",fish.weight or 0) end
			if rarityLabel and rarityLabel:IsA("TextLabel") then rarityLabel.Text=fish.rarity or "Common" rarityLabel.TextColor3=RarityColors and RarityColors[fish.rarity] or Color3.new(1,1,1) end

			-- [FAV-5] UIStroke border: selalu aktif kalau favorit (biar keliatan walaupun mode OFF)
			if uiStroke then uiStroke.Enabled = fish.isFavorited or false end

			local currentFish=fish
			local function onToggleFav()
				local newVal=rfToggleFavorite:InvokeServer(currentFish.uniqueId)
				if newVal~=nil then
					currentFish.isFavorited=newVal
					playSound("EquipSound")
					populateFishGrid()
				end
			end

			-- [FAV-5] Star/FavoriteButton visual berdasarkan mode
			-- Unfavorit HARUS lewat mode ON → klik bintang langsung nggak bisa
			if favBtn then
				if favBtn:IsA("ImageButton") then
					if fish.isFavorited then
						favBtn.ImageTransparency = 0
						favBtn.ImageColor3 = Color3.fromRGB(255, 220, 0)
						favBtn.Visible = true
					elseif favoriteMode then
						favBtn.ImageTransparency = 0.5
						favBtn.ImageColor3 = Color3.fromRGB(120, 120, 120)
						favBtn.Visible = true
					else
						favBtn.Visible = false
					end
					-- Klik bintang juga cuma jalan kalau mode ON
					favBtn.MouseButton1Click:Connect(function()
						if favoriteMode then onToggleFav() end
					end)
				elseif favBtn:IsA("TextButton") then
					if fish.isFavorited then
						favBtn.Text = "⭐"
						favBtn.TextColor3 = Color3.fromRGB(255, 220, 0)
						favBtn.Visible = true
					elseif favoriteMode then
						favBtn.Text = "☆"
						favBtn.TextColor3 = Color3.fromRGB(120, 120, 120)
						favBtn.Visible = true
					else
						favBtn.Visible = false
					end
					favBtn.MouseButton1Click:Connect(function()
						if favoriteMode then onToggleFav() end
					end)
				end
			end

			local function onClickFish()
				-- [FAV-5] Mode ON → klik ikan = toggle favorit
				if favoriteMode then onToggleFav() return end
				-- Mode OFF → klik ikan = equip ke hotbar / equip langsung
				if isInventoryOpen then
					local eq=false
					for _,item in ipairs(hotbar.equippedItems) do
						if item.type=="Fish" and item.id==currentFish.uniqueId then eq=true break end
					end
					if not eq and #hotbar.equippedItems<MAX_EQUIPPED_ITEMS then
						table.insert(hotbar.equippedItems,{type="Fish",id=currentFish.uniqueId,data=currentFish})
						playSound("EquipSound") saveHotbarToServer()
					end
				else
					playSound("EquipSound") reEquipFish:FireServer(currentFish.uniqueId)
				end
			end
			if fishImg then if fishImg:IsA("ImageButton") then fishImg.MouseButton1Click:Connect(onClickFish) else makeClickable(fishImg,onClickFish) end else makeClickable(card,onClickFish) end
			card.Parent=IV.FishContent
		end
		batchIndex=batchEnd if batchIndex<#allFishData then task.wait() renderBatch() else updateFishCount() end
	end
	renderBatch()
end

local function populateRodGrid(serverData)
	if not IV.RodContent or not Templates.Rod then return end clearChildren(IV.RodContent)
	local multiplier=GlobalLuckVal.Value or 1 local lastRod=serverData and serverData.LastRod or nil local currentSkin=serverData and serverData.EquippedRodSkin or equippedRodSkin
	if not serverData and #allRodData==0 then local ok,data=pcall(function() return rfGetData:InvokeServer() end) if ok and data then serverData=data lastRod=data.LastRod currentSkin=data.EquippedRodSkin if data.RodTextures then for k,v in pairs(data.RodTextures) do local c=cleanAssetId(v) if c~="" then rodTextureCache[k]=c end end end if data.SkinTextures then for k,v in pairs(data.SkinTextures) do local c=cleanAssetId(v) if c~="" then skinTextureCache[k]=c end end end end end
	equippedRodSkin=currentSkin renderRodSlot()
	table.sort(allRodData,function(a,b) local sa=rodShopCache[a] and rodShopCache[a].Stats if not sa then local ok,cfg=pcall(function() return FishingConfig.GetRodConfig(a) end) sa=ok and cfg or nil end local sb=rodShopCache[b] and rodShopCache[b].Stats if not sb then local ok,cfg=pcall(function() return FishingConfig.GetRodConfig(b) end) sb=ok and cfg or nil end return (sa and sa.baseLuck or 0)>(sb and sb.baseLuck or 0) end)
	if #allRodData==0 then local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,0,50) lbl.Position=UDim2.new(0,0,0.3,0) lbl.BackgroundTransparency=1 lbl.Text="No rods yet!" lbl.TextColor3=Color3.fromRGB(150,150,150) lbl.TextSize=16 lbl.Font=Enum.Font.Gotham lbl.Parent=IV.RodContent return end
	local added={}
	for _,rodName in ipairs(allRodData) do
		if added[rodName] then continue end added[rodName]=true
		local card=Templates.Rod:Clone() card.Name=rodName card.Visible=true
		local shop=rodShopCache[rodName] local stats if shop and shop.Stats then stats=shop.Stats else local ok,cfg=pcall(function() return FishingConfig.GetRodConfig(rodName) end) stats=ok and cfg or nil end
		local texture=rodTextureCache[rodName] or (shop and shop.TextureId or "")
		if texture=="" then local tool=player.Backpack:FindFirstChild(rodName) or (player.Character and player.Character:FindFirstChild(rodName)) if tool and tool:IsA("Tool") and tool.TextureId~="" then texture=cleanAssetId(tool.TextureId) if texture~="" then rodTextureCache[rodName]=texture end end end
		local bg=card:FindFirstChild("BG") local vector=bg and bg:FindFirstChild("Vector")
		if vector then if texture~="" then vector.Image=texture vector.ImageColor3=Color3.fromRGB(255,255,255) vector.ImageTransparency=0 vector.Visible=true else vector.Image="" end end
		local glow=card:FindFirstChild("RarityGlow") if glow and stats and stats.rarity then local grad=glow:FindFirstChild("UIGradient") if grad then grad.Color=ColorSequence.new(RarityColors and RarityColors[stats.rarity] or Color3.new(1,1,1)) end end
		local stroke=card:FindFirstChild("UIStroke") if not stroke then stroke=Instance.new("UIStroke") stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border stroke.Color=Color3.fromRGB(0,255,0) stroke.Thickness=3 stroke.Parent=card end stroke.Enabled=(rodName==lastRod)
		local padded=card:FindFirstChild("Padded")
		if padded and stats then
			local bottom=padded:FindFirstChild("Bottom")
			if bottom then
				local luck=bottom:FindFirstChild("Luck") if luck then local lbl=luck:FindFirstChild("Label") if lbl then lbl.Text="Luck:" end local ctr=luck:FindFirstChild("Counter") if ctr then local final=(stats.baseLuck or 1)*multiplier if multiplier>1 then ctr.Text=string.format("<font color='#00FF00'><b>%.1fx</b></font>",final) ctr.RichText=true else ctr.Text=string.format("%.1fx",final) end end end
				local weight=bottom:FindFirstChild("Weight") if weight then local lbl=weight:FindFirstChild("Label") if lbl then lbl.Text="Max KG:" end local ctr=weight:FindFirstChild("Counter") if ctr then ctr.Text=string.format("%dkg",stats.maxWeight or 0) end end
				local rarity=bottom:FindFirstChild("Rarity") if rarity then local lbl=rarity:FindFirstChild("Label") if lbl then lbl.Text="Tier:" end local ctr=rarity:FindFirstChild("Counter") if ctr then ctr.Text=stats.rarity or "Common" ctr.TextColor3=RarityColors and RarityColors[stats.rarity] or Color3.new(1,1,1) end end
			end
			local topSec=padded:FindFirstChild("Top")
			if topSec then local nameLabel=topSec:FindFirstChild("Label") or topSec:FindFirstChild("RodName") or topSec:FindFirstChild("ItemName") if nameLabel and nameLabel:IsA("TextLabel") then nameLabel.Text=rodName end
				local tierLabel=topSec:FindFirstChild("TierLabel") if tierLabel and stats and stats.rarity then local col=RarityColors and RarityColors[stats.rarity] or Color3.new(1,1,1) tierLabel.Text=stats.rarity tierLabel.Visible=true local tg=tierLabel:FindFirstChild("UIGradient") if tg then tg.Color=ColorSequence.new(col) else tierLabel.TextColor3=col end end
				local eas=topSec:FindFirstChild("EquipAsSkin") if eas then eas:Destroy() end
			end
		end
		local thisRod=rodName
		local function onEquipRod() hotbar.rod=thisRod playSound("EquipSound") reEquipRod:FireServer(thisRod) saveHotbarToServer() for _,child in ipairs(IV.RodContent:GetChildren()) do if not child.Name:match("^SKIN_") then local s=child:FindFirstChild("UIStroke") if s then s.Enabled=(child.Name==thisRod) end end end renderRodName() renderRodSlot() end
		if card:IsA("ImageButton") or card:IsA("TextButton") then card.MouseButton1Click:Connect(onEquipRod) else makeClickable(card,onEquipRod) end
		card.Parent=IV.RodContent
	end
	local ownedSkins=serverData and serverData.OwnedSkins or {} local skinList={}
	for _,skinName in ipairs(ownedSkins) do local cfg=FishingConfig.RodSkins and FishingConfig.RodSkins[skinName] if cfg then table.insert(skinList,{name=skinName,config=cfg}) end end
	table.sort(skinList,function(a,b) return (RARITY_ORDER[a.config.rarity] or 0)>(RARITY_ORDER[b.config.rarity] or 0) end)
	for _,skinInfo in ipairs(skinList) do
		local sName=skinInfo.name local sCfg=skinInfo.config local sCard=Templates.Rod:Clone() sCard.Name="SKIN_"..sName sCard.Visible=true
		local sTex=skinTextureCache[sName] or "" local sBG=sCard:FindFirstChild("BG") local sVec=sBG and sBG:FindFirstChild("Vector")
		if sVec then if sTex~="" then sVec.Image=sTex sVec.ImageColor3=Color3.new(1,1,1) sVec.ImageTransparency=0 sVec.Visible=true else sVec.Image="" end end
		local sGlow=sCard:FindFirstChild("RarityGlow") if sGlow and sCfg.rarity then local sg=sGlow:FindFirstChild("UIGradient") if sg then sg.Color=ColorSequence.new(RarityColors and RarityColors[sCfg.rarity] or Color3.new(1,1,1)) end end
		local sStroke=sCard:FindFirstChild("UIStroke") if not sStroke then sStroke=Instance.new("UIStroke") sStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border sStroke.Color=Color3.fromRGB(255,0,255) sStroke.Thickness=3 sStroke.Parent=sCard end sStroke.Enabled=(sName==currentSkin)
		local sPad=sCard:FindFirstChild("Padded")
		if sPad then
			local sBot=sPad:FindFirstChild("Bottom") if sBot then local luckB,speedB,weightB=1,1,1 if FishingConfig.GetSkinBonuses then luckB,speedB,weightB=FishingConfig.GetSkinBonuses(sName) end
				local sLuck=sBot:FindFirstChild("Luck") local sLC=sLuck and sLuck:FindFirstChild("Counter") if sLC then sLC.Text=luckB and luckB>1 and string.format("<font color='#00FF00'><b>+%d%%</b></font>",math.floor((luckB-1)*100)) or "-" sLC.RichText=true end
				local sWeight=sBot:FindFirstChild("Weight") if sWeight then local swL=sWeight:FindFirstChild("Label") if swL then swL.Text="Speed" end local swC=sWeight:FindFirstChild("Counter") if swC then swC.Text=speedB and speedB>1 and string.format("<font color='#FFFF00'><b>+%d%%</b></font>",math.floor((speedB-1)*100)) or "-" swC.RichText=true end end
				local sRar=sBot:FindFirstChild("Rarity") if sRar then local srL=sRar:FindFirstChild("Label") if srL then srL.Text="Weight" end local srC=sRar:FindFirstChild("Counter") if srC then srC.Text=weightB and weightB>1 and string.format("<font color='#00BFFF'><b>+%d%%</b></font>",math.floor((weightB-1)*100)) or "-" srC.RichText=true end end
			end
			local sTop=sPad:FindFirstChild("Top") if sTop then
				local sNL=sTop:FindFirstChild("Label") or sTop:FindFirstChild("RodName") if sNL then sNL.Text="🎨 "..(sCfg.displayName or sName) sNL.TextColor3=RarityColors and RarityColors[sCfg.rarity] or Color3.new(1,1,1) end
				local sEAS=sTop:FindFirstChild("EquipAsSkin")
				if sEAS and reEquipSkin then sEAS.Visible=true local easText=sEAS:FindFirstChild("Text") or sEAS:FindFirstChild("Label") if easText then easText.Text=(sName==currentSkin) and "Lepas Kulit" or "Pakai Kulit" end
					local thisSkin,thisStroke,thisEasText=sName,sStroke,easText
					local function onToggleSkin() if thisSkin==equippedRodSkin then reEquipSkin:FireServer(nil) equippedRodSkin=nil else playSound("EquipSound") reEquipSkin:FireServer(thisSkin) equippedRodSkin=thisSkin end renderRodSlot() if thisEasText then thisEasText.Text=(equippedRodSkin==thisSkin) and "Lepas Kulit" or "Pakai Kulit" end if thisStroke then thisStroke.Enabled=(equippedRodSkin==thisSkin) end task.wait(0.1) for _,c in ipairs(IV.RodContent:GetChildren()) do if c.Name:match("^SKIN_") then local cs=c:FindFirstChild("UIStroke") if cs then cs.Enabled=(c.Name:gsub("^SKIN_","")==equippedRodSkin) end local cp=c:FindFirstChild("Padded") local ct=cp and cp:FindFirstChild("Top") local ce=ct and ct:FindFirstChild("EquipAsSkin") local cl=ce and (ce:FindFirstChild("Text") or ce:FindFirstChild("Label")) if cl then cl.Text=(c.Name:gsub("^SKIN_","")==equippedRodSkin) and "Lepas Kulit" or "Pakai Kulit" end end end end
					if sEAS:IsA("TextButton") or sEAS:IsA("ImageButton") then sEAS.MouseButton1Click:Connect(onToggleSkin) else makeClickable(sEAS,onToggleSkin) end
				elseif sEAS then sEAS:Destroy() end
			end
		end
		makeClickable(sCard,function() end) sCard.Parent=IV.RodContent
	end
end

local function populateToolGrid()
	if not IV.ToolContent or not Templates.Fish then return end clearChildren(IV.ToolContent)
	local tools={} local addedTools={} local toolCounts={}
	local function addTool(tool) if not tool:IsA("Tool") then return end if tool:FindFirstChild("FishId") or CollectionService:HasTag(tool,"Rod") then return end toolCounts[tool.Name]=(toolCounts[tool.Name] or 0)+1 if not addedTools[tool.Name] then table.insert(tools,tool) addedTools[tool.Name]=true end end
	local backpack=player:FindFirstChildOfClass("Backpack") if backpack then for _,t in ipairs(backpack:GetChildren()) do addTool(t) end end
	local char=player.Character if char then for _,t in ipairs(char:GetChildren()) do addTool(t) end end
	for _,t in ipairs(StarterPack:GetChildren()) do if not addedTools[t.Name] then addTool(t) end end
	table.sort(tools,function(a,b) return a.Name<b.Name end)
	if #tools==0 then local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,0,50) lbl.Position=UDim2.new(0,0,0.3,0) lbl.BackgroundTransparency=1 lbl.Text="No tools!" lbl.TextColor3=Color3.fromRGB(150,150,150) lbl.TextSize=16 lbl.Font=Enum.Font.Gotham lbl.Parent=IV.ToolContent return end
	for _,tool in ipairs(tools) do
		local card=Templates.Fish:Clone() card.Name=tool.Name card.Visible=true
		local fishImg=card:FindFirstChild("FishImage") local nameLabel=card:FindFirstChild("FishName") local rarityLabel=card:FindFirstChild("FishRarity") local weightLabel=card:FindFirstChild("FishWeight") local favBtn=card:FindFirstChild("FavoriteButton",true)
		if rarityLabel then rarityLabel.Visible=false end if favBtn then favBtn.Visible=false end
		if weightLabel and weightLabel:IsA("TextLabel") then local count=toolCounts[tool.Name] or 0 if count>=1 then weightLabel.Text="x"..tostring(count) weightLabel.Visible=true weightLabel.TextColor3=Color3.fromRGB(255,220,100) weightLabel.Font=Enum.Font.GothamBold else weightLabel.Visible=false end end
		if fishImg and tool.TextureId and tool.TextureId~="" then fishImg.Image=tool.TextureId end
		if nameLabel then nameLabel.Text=tool.Name nameLabel.TextColor3=Color3.fromRGB(240,240,240) end
		local thisTool=tool.Name
		local function onClickTool() if isInventoryOpen then local eq=false for _,item in ipairs(hotbar.equippedItems) do if item.type=="Tool" and item.id==thisTool then eq=true break end end if not eq and #hotbar.equippedItems<MAX_EQUIPPED_ITEMS then table.insert(hotbar.equippedItems,{type="Tool",id=thisTool}) playSound("EquipSound") saveHotbarToServer() end else playSound("EquipSound") reEquipTool:FireServer(thisTool) end end
		if fishImg then if fishImg:IsA("ImageButton") then fishImg.MouseButton1Click:Connect(onClickTool) else makeClickable(fishImg,onClickTool) end else makeClickable(card,onClickTool) end
		card.Parent=IV.ToolContent
	end
end

-- ═══════════════════════════════════════════════════════════════
-- [FAV-4] SWITCH TAB — Favorite button cuma tampil di tab Fish
-- ═══════════════════════════════════════════════════════════════
local function switchTab(tabName, serverData)
	lastTab=tabName currentTab=tabName
	if IV.FishTabButton then IV.FishTabButton.BackgroundColor3=Color3.fromRGB(49,49,49) end
	if IV.RodTabButton then IV.RodTabButton.BackgroundColor3=Color3.fromRGB(49,49,49) end
	if IV.ToolTabButton then IV.ToolTabButton.BackgroundColor3=Color3.fromRGB(49,49,49) end
	if IV.FishContent then IV.FishContent.Visible=false end if IV.RodContent then IV.RodContent.Visible=false end if IV.ToolContent then IV.ToolContent.Visible=false end
	if IV.SellAllFrame then IV.SellAllFrame.Visible=false end if IV.FishCountLabel then IV.FishCountLabel.Visible=false end

	-- [FAV-4] Sembunyikan favorite button kalau bukan tab Fish
	local favTarget = IV.FavoriteFrame or IV.FavoriteButton
	if favTarget then favTarget.Visible = false end

	if tabName=="Fish" then
		if IV.FishTabButton then IV.FishTabButton.BackgroundColor3=Color3.fromRGB(106,106,106) end
		if IV.FishContent then IV.FishContent.Visible=true end
		if IV.SellAllFrame then IV.SellAllFrame.Visible=true end
		if IV.FishCountLabel then IV.FishCountLabel.Visible=true end
		-- [FAV-4] Tampilkan favorite button di tab Fish
		if favTarget then favTarget.Visible = true end
		updateFavoriteButtonVisual()
		populateFishGrid()
	elseif tabName=="Rods" then
		if IV.RodTabButton then IV.RodTabButton.BackgroundColor3=Color3.fromRGB(106,106,106) end
		if IV.RodContent then IV.RodContent.Visible=true end
		if not serverData and #allRodData==0 then local ok,data=pcall(function() return rfGetData:InvokeServer() end) if ok then serverData=data end end
		if serverData then allRodData=serverData.Rods or allRodData if serverData.RodTextures then for k,v in pairs(serverData.RodTextures) do local c=cleanAssetId(v) if c~="" then rodTextureCache[k]=c end end end if serverData.SkinTextures then for k,v in pairs(serverData.SkinTextures) do local c=cleanAssetId(v) if c~="" then skinTextureCache[k]=c end end end end
		-- [FAV-4] Kalau pindah dari Fish tab, matikan favorite mode
		if favoriteMode then
			favoriteMode = false
			updateFavoriteButtonVisual()
		end
		populateRodGrid(serverData)
	elseif tabName=="Tools" then
		if IV.ToolTabButton then IV.ToolTabButton.BackgroundColor3=Color3.fromRGB(106,106,106) end
		if IV.ToolContent then IV.ToolContent.Visible=true end
		if favoriteMode then
			favoriteMode = false
			updateFavoriteButtonVisual()
		end
		populateToolGrid()
	end
end

local function toggleInventory(open) if open==isInventoryOpen then return end isInventoryOpen=open if IV.Frame then IV.Frame.Visible=open end playSound("OpenCloseSound") if open then local _,data=fetchAllData() switchTab(lastTab,data) else
		-- [FAV-4] Reset favorite mode saat tutup inventory
		if favoriteMode then
			favoriteMode = false
			updateFavoriteButtonVisual()
		end
	end end

local buttonConns={}

-- ═══════════════════════════════════════════════════════════════
-- [FAV-3] SETUP BUTTONS — connect Favorite button
-- ═══════════════════════════════════════════════════════════════
local function setupButtons()
	for _,c in ipairs(buttonConns) do if c and c.Connected then c:Disconnect() end end table.clear(buttonConns)
	if HB.RodSlot then table.insert(buttonConns,HB.RodSlot.MouseButton1Click:Connect(function() if isInventoryOpen then if hotbar.rod then reUnequipAll:FireServer() hotbar.rod=nil saveHotbarToServer() renderRodName() renderRodSlot() end else local char=player.Character local curTool=char and char:FindFirstChildOfClass("Tool") if curTool and CollectionService:HasTag(curTool,"Rod") then reUnequipAll:FireServer() elseif hotbar.rod then playSound("EquipSound") reEquipRod:FireServer(hotbar.rod) end end end)) end
	if HB.BagButton then table.insert(buttonConns,HB.BagButton.MouseButton1Click:Connect(function() toggleInventory(not isInventoryOpen) end)) end
	if IV.CloseButton then table.insert(buttonConns,IV.CloseButton.MouseButton1Click:Connect(function() toggleInventory(false) end)) end
	if IV.FishTabButton then table.insert(buttonConns,IV.FishTabButton.MouseButton1Click:Connect(function() switchTab("Fish") end)) end
	if IV.RodTabButton then table.insert(buttonConns,IV.RodTabButton.MouseButton1Click:Connect(function() switchTab("Rods") end)) end
	if IV.ToolTabButton then table.insert(buttonConns,IV.ToolTabButton.MouseButton1Click:Connect(function() switchTab("Tools") end)) end
	if IV.SellAllButton then table.insert(buttonConns,IV.SellAllButton.MouseButton1Click:Connect(function() pcall(function() rfSellAll:InvokeServer() end) task.wait(0.1) lastFetchTime=0 local _,data=fetchAllData() validateFishInHotbar() saveHotbarToServer() if isInventoryOpen then switchTab(currentTab,data) end end)) end

	-- [FAV-3] Connect Favorite toggle button
	if IV.FavoriteButton then
		table.insert(buttonConns, IV.FavoriteButton.MouseButton1Click:Connect(function()
			favoriteMode = not favoriteMode
			playSound("EquipSound")
			updateFavoriteButtonVisual()
			if currentTab == "Fish" then
				populateFishGrid()
			end
		end))
		updateFavoriteButtonVisual()
	end
end

local function onInput(input,gameProcessed) if gameProcessed then return end local key=input.KeyCode
	if key==Enum.KeyCode.Two then toggleInventory(not isInventoryOpen) return end
	local char=player.Character local curTool=char and char:FindFirstChildOfClass("Tool")
	if key==Enum.KeyCode.One then if curTool and CollectionService:HasTag(curTool,"Rod") then reUnequipAll:FireServer() elseif hotbar.rod then playSound("EquipSound") reEquipRod:FireServer(hotbar.rod) end return end
	local slotMap={[Enum.KeyCode.Three]=1,[Enum.KeyCode.Four]=2,[Enum.KeyCode.Five]=3,[Enum.KeyCode.Six]=4} local slot=slotMap[key]
	if slot then local item=hotbar.equippedItems[slot] if not item then return end local isHolding=false
		if curTool then if item.type=="Fish" and curTool:FindFirstChild("FishId") then isHolding=curTool.FishId.Value==item.id elseif item.type=="Tool" and curTool.Name==item.id then isHolding=true end end
		if isHolding then reUnequipAll:FireServer() else playSound("EquipSound") if item.type=="Fish" then reEquipFish:FireServer(item.id) else reEquipTool:FireServer(item.id) end end
	end
end

local charConns={}
local function setupCharacter(character)
	isInventoryOpen=false lastFetchTime=0 lastTab="Fish" currentTab="Fish"
	-- [FAV-4] Reset favorite mode saat karakter baru
	favoriteMode = false

	if not buildGuiRefs() then warn("[V4] buildGuiRefs failed!") return end
	applyMobileLayout() setupButtons()
	task.wait(0.5) fetchAllData() loadHotbarFromServer()
	task.wait(0.5) updateFishCount() task.delay(2,updateFishCount)
	for _,c in ipairs(charConns) do if c and c.Connected then c:Disconnect() end end table.clear(charConns)
	table.insert(charConns,character.ChildAdded:Connect(function(child) if not child:IsA("Tool") then return end local relevant=(child.Name==hotbar.rod) if not relevant then for _,item in ipairs(hotbar.equippedItems) do if (child:FindFirstChild("FishId") and child.FishId.Value==item.id) or child.Name==item.id then relevant=true break end end end if relevant then renderHotbarItems() renderRodSlot() end end))
	table.insert(charConns,character.ChildRemoved:Connect(function(child) if child and child:IsA("Tool") then renderHotbarItems() renderRodSlot() end end))
	local backpack=player:WaitForChild("Backpack")
	table.insert(charConns,backpack.ChildRemoved:Connect(function(child)
		if not child or not child:IsA("Tool") or CollectionService:HasTag(child,"Rod") then return end
		if not child:FindFirstChild("FishId") then local changed=false for i=#hotbar.equippedItems,1,-1 do local item=hotbar.equippedItems[i] if item.type=="Tool" and item.id==child.Name then task.wait(0.05) if not character:FindFirstChild(child.Name) and not backpack:FindFirstChild(child.Name) then table.remove(hotbar.equippedItems,i) changed=true end end end if changed then renderHotbarItems() saveHotbarToServer() end
		else local fishId=child.FishId.Value task.wait(0.05) local changed=false for i=#hotbar.equippedItems,1,-1 do local item=hotbar.equippedItems[i] if item.type=="Fish" and item.id==fishId then local inChar=false for _,t in ipairs(character:GetChildren()) do if t:IsA("Tool") and t:FindFirstChild("FishId") and t.FishId.Value==fishId then inChar=true break end end local inData=false for _,f in ipairs(allFishData) do if f.uniqueId==fishId then inData=true break end end if not inChar and not inData then table.remove(hotbar.equippedItems,i) changed=true end end end if changed then renderHotbarItems() saveHotbarToServer() end end
	end))
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p,id,purchased) if p==player and id==1644925545 and purchased then end end)
if reRefreshInv then reRefreshInv.OnClientEvent:Connect(function() task.wait(0.5) lastFetchTime=0 local ok,data=fetchAllData() if isInventoryOpen and ok then switchTab(currentTab,data) end end) end
GlobalLuckVal:GetPropertyChangedSignal("Value"):Connect(function() if isInventoryOpen and currentTab=="Rods" then switchTab("Rods") end end)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false)
UserInputService.InputBegan:Connect(onInput)
if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)