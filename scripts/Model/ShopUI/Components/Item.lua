local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local MS = game:GetService("MarketplaceService")
local GS = game:GetService("GroupService")

local player = game.Players.LocalPlayer
repeat task.wait(1) until player:FindFirstChild('DataLoaded')
local playerdata = player:WaitForChild('PlayerData')
local playerinventory = playerdata:WaitForChild('Inventory')
local playergamepasses = playerdata:WaitForChild('Gamepasses')

local templates = script.Parent.Parent:WaitForChild("Templates")
local debounce = script.Parent.Parent:WaitForChild("Debounce")

-- ✅ FIX: Tambah timeout dan error handling
local remotes = RS:WaitForChild("Remotes", 10)
if not remotes then
	warn("❌ [ShopUI Item] Remotes folder tidak ditemukan!")
	return
end

local shopremotes = remotes:WaitForChild("ShopInventoryRemotes", 10)
if not shopremotes then
	warn("❌ [ShopUI Item] ShopInventoryRemotes tidak ditemukan!")
	return
end

local notifyremote = script.Parent.Parent:WaitForChild("notify")
local searchbar = script.Parent.Parent:WaitForChild("MainFrame"):WaitForChild("MainFrame"):WaitForChild("Frames"):WaitForChild("searchbar")
local sounds = RS:WaitForChild('Assets'):WaitForChild('Sounds')
local signal = require(RS:WaitForChild("Module"):WaitForChild("Signal"))
local promise = require(RS:WaitForChild("Module"):WaitForChild("Promise"))
local shopmodule = require(RS:WaitForChild("Module"):WaitForChild("ShopModule"))

local item = {}
item.__index = item


function item.new(itemdata,iteminfoframe)
	local self = setmetatable({
		Data = itemdata,
		ItemInfoFrame = iteminfoframe,

		InventoryUI = nil,
		ShopUI = nil,
		InventoryContainer = nil,
		ShopContainer = nil
	},item)

	self:_init_()

	return self
end

--//private methods
function item:_init_()
	if self.Data.Currency == "cash" or self.Data.Currency == "gem" then
		self.Data.CanBuy = true
		self.Ready = true
	elseif self.Data.Currency == "robux" then
		local success, data = promise.retryWithDelay(function()
			-- ✅ Jangan pakai and/or karena bisa salah pilih tipe
			if self.Data.GamepassId and self.Data.GamepassId ~= 0 then
				return MS:GetProductInfo(self.Data.GamepassId, Enum.InfoType.GamePass)
			elseif self.Data.ProductId and self.Data.ProductId ~= 0 then
				return MS:GetProductInfo(self.Data.ProductId, Enum.InfoType.Product)
			else
				error("Tidak ada ID robux valid untuk item " .. tostring(self.Data.Id))
			end
		end, 3, 2):await()

		if success and data then
			self.Data.Name = self.Data.Name or data.Name
			self.Data.Description = self.Data.Description or data.Description or ""
			self.Data.IconId = self.Data.IconId or data.IconImageAssetId or 0
			self.Data.Price = data.PriceInRobux or 0
			self.Data.CanBuy = true
		else
			warn("⚠ Gagal mengambil ProductInfo untuk item:", self.Data.Id)
			self.Data.CanBuy = false
		end

		self.Ready = true
	end
	if self.Data.GroupNeededId then
		if not player:IsInGroup(self.Data.GroupNeededId) then
			self.Data.CanBuy = false
			local success, data = promise.retryWithDelay(function()
				return GS:GetGroupInfoAsync(self.Data.GroupNeededId)
			end,5,10):await()
			if success then
				self.Data.IconId = data.EmblemUrl and (tonumber(string.split(data.EmblemUrl,"=")[2]) or 0)
				self.Data.Requirements = "You need to be in the '"..data.Name.."' Group"
			end
		end
	end
	if playergamepasses:FindFirstChild(self.Data.Id) then
		playergamepasses:FindFirstChild(self.Data.Id):GetPropertyChangedSignal("Value"):Connect(function()
			self:Update()
		end)
	end
	if self.Data.Type == "item" then
		local _,isspecial = shopmodule.GetItemData(self.Data.Id)
		self.Data.IsSpecial = isspecial
	elseif self.Data.Type == "aura" then
		local _,isspecial = shopmodule.GetAuraData(self.Data.Id)
		self.Data.IsSpecial = isspecial
	end
end

function item:_createinventoryui_()
	local sample = templates:WaitForChild("inventoryitemsample"):Clone()
	sample.Name = self.Data.Id
	sample.Main.ItemIcon.ImageLabel.Image = 'rbxassetid://'..self.Data.IconId
	sample.LayoutOrder = -(math.clamp(self.Data.Price,0,99999))
	self:_animateBtn_(sample,{sample.Main.equip},function()
		if not debounce.Value then
			debounce.Value = true
			local req = self.Data.Type == "item" and shopremotes.equip_item:InvokeServer(self.Data.Id) or
				shopremotes.equip_aura:InvokeServer(self.Data.Id)
			if req then
				if not req[1] then
					notifyremote:Fire(req[2],true)
				end
			else
				notifyremote:Fire("There was an error. Please try again later!",true)
			end
			self:Update()
			task.wait(0.2)
			debounce.Value = false
		end
	end)
	if self.Data.Type == "item" then
		if self.Data.IsSpecial then
			playerinventory.EquippedSpecial:GetPropertyChangedSignal("Value"):Connect(function()
				self:_enableequip_(not (sample.Name == playerinventory.EquippedSpecial.Value))
			end)
		else
			playerinventory.EquippedItem:GetPropertyChangedSignal("Value"):Connect(function()
				self:_enableequip_(not (sample.Name == playerinventory.EquippedItem.Value))
			end)
		end
	elseif self.Data.Type == "aura" then
		playerinventory.EquippedAura:GetPropertyChangedSignal("Value"):Connect(function()
			self:_enableequip_(not (sample.Name == playerinventory.EquippedAura.Value))
		end)
	end
	searchbar.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
		if string.find(string.lower(sample.Name),string.lower(searchbar.TextBox.Text)) or searchbar.TextBox.Text == "" then
			sample.Visible = true
		else
			sample.Visible = false
		end
	end)
	sample.Visible = true
	return sample
end

function item:_createshopui_()
	local sample = templates:WaitForChild("shopitemsample"):Clone()
	local cangift = false
	sample.Name = self.Data.Id
	sample.Main.ItemIcon.ImageLabel.Image = 'rbxassetid://'..self.Data.IconId
	sample.LayoutOrder = math.clamp(self.Data.Price,0,99999)
	sample:SetAttribute("Order",math.clamp(self.Data.Price,0,99999))
	sample.Main.buy.TextLabel.Text = self.Data.Price

	if self.Data.Currency == "cash" then
		sample:SetAttribute("Color",Color3.fromRGB(85,255,0))
		sample:SetAttribute("Rotation",-45)
		sample:SetAttribute("IconId",14732298754)
	elseif self.Data.Currency == "robux" then
		sample:SetAttribute("Color",Color3.fromRGB(255, 170, 0))
		sample:SetAttribute("Rotation",0)
		sample:SetAttribute("IconId",13053159396)
		cangift = true
	elseif self.Data.Currency == "gem" then
		sample:SetAttribute("Color",Color3.fromRGB(49, 0, 148))
		sample:SetAttribute("Rotation",20)
		sample:SetAttribute("IconId",2654418499)
		cangift = false
	end
	sample.Main.buy.BackgroundColor3 = sample:GetAttribute("Color") or Color3.fromRGB(0,255,0)
	sample.Main.buy.ImageLabel.Rotation = sample:GetAttribute("Rotation") or 0
	sample.Main.buy.ImageLabel.Image = "rbxassetid://"..(sample:GetAttribute("IconId") or 0)


	self:_animateBtn_(sample,{sample.Main.buy,sample.Main.Button},function()
		if not debounce.Value then
			debounce.Value = true
			self.ItemInfoFrame:DisplayItem({
				IconId = self.Data.IconId,
				Id = self.Data.Id,
				Name = self.Data.Name,
				Description = self.Data.Description,
				Price = self.Data.Price,

				Color = sample:GetAttribute("Color"),
				IconRotation = sample:GetAttribute("Rotation"),
				ButtonIconId = sample:GetAttribute("IconId"),

				Owned = sample:GetAttribute("Owned"),
				CanGift = cangift,
				CanBuy = self.Data.CanBuy,
				Requirements = self.Data.Requirements,
			},function()
				if self.Data.Currency == "robux" then
					if self.Data.GamepassId then
						MS:PromptGamePassPurchase(game.Players.LocalPlayer,self.Data.GamepassId)
					else
						local selectplayerreq = shopremotes:WaitForChild("selectplayertogift"):InvokeServer(player.Name,self.Data.Id)
						if selectplayerreq then
							if selectplayerreq[1] then
								MS:PromptProductPurchase(game.Players.LocalPlayer,self.Data.ProductId)
							else
								notifyremote:Fire(selectplayerreq[2],true)
							end
						else
							notifyremote:Fire("There was an error. Please try again later",true)
						end
					end
				elseif self.Data.Currency == "cash" or self.Data.Currency == "gem" then
					local req = self.Data.Type == "item" and shopremotes.buy_Item:InvokeServer(self.Data.Id) or
						shopremotes.buy_aura:InvokeServer(self.Data.Id)
					if req then
						if not req[1] then
							notifyremote:Fire(req[2],true)
						else
							sounds.ui_success:Play()
						end
					else
						notifyremote:Fire("There was an error. Please try again later!",true)
					end
				end
			end,self.Data.Id,self.Data.ProductId)
			self:Update()
			task.wait(0.2)
			debounce.Value = false
		end
	end)
	sample.Visible = true
	return sample
end

function item:_animateBtn_(btn,buttons,func)
	btn.MouseEnter:Connect(function()
		if not btn:GetAttribute("Clicked") and not debounce.Value then
			TS:Create(btn.Main.UIScale,TweenInfo.new(0.1),{Scale = 1.05}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if not btn:GetAttribute("Clicked") and not debounce.Value then
			TS:Create(btn.Main.UIScale,TweenInfo.new(0.1),{Scale = 1}):Play()
		end
	end)
	for i, button in pairs(buttons) do
		button.MouseButton1Click:Connect(function()
			if btn:GetAttribute("Clicked") or debounce.Value then
				return
			end
			if button:FindFirstChild("UIScale")then
				TS:Create(button.UIScale,TweenInfo.new(0.1),{Scale = 0.8}):Play()
				task.delay(0.1,function()
					TS:Create(button.UIScale,TweenInfo.new(0.1,Enum.EasingStyle.Back),{Scale = 1}):Play()
				end)
			end
			TS:Create(btn.Main.UIScale,TweenInfo.new(0.1),{Scale = 1}):Play()
			btn:SetAttribute("Clicked",true)
			func()
			btn:SetAttribute("Clicked",false)
		end)
	end
end

function item:_enableequip_(canequip)
	if canequip then
		self.InventoryUI.Main.equip.BackgroundColor3 = Color3.fromRGB(0, 85, 255)
		self.InventoryUI.Main.equip.TextLabel.Text = "EQUIP"
	else
		self.InventoryUI.Main.equip.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		self.InventoryUI.Main.equip.TextLabel.Text = "UNEQUIP"
	end
end

function item:_playerownsitem_()
	if self.Data.Type == "item" then
		return playerinventory.Items:FindFirstChild(self.Data.Id) or (playergamepasses:FindFirstChild(self.Data.Id) and playergamepasses:FindFirstChild(self.Data.Id).Value)
	elseif self.Data.Type == "aura" then
		return playerinventory.Auras:FindFirstChild(self.Data.Id) or (playergamepasses:FindFirstChild(self.Data.Id) and playergamepasses:FindFirstChild(self.Data.Id).Value)
	else
		return (playergamepasses:FindFirstChild(self.Data.Id) and playergamepasses:FindFirstChild(self.Data.Id).Value)
	end 
end

--// public methods
function item:Update()
	if self.Ready then
		--// updates the inventory ui
		if self:_playerownsitem_() and self.Data.Type ~= "gamepass" then
			self.InventoryUI = self.InventoryUI or self:_createinventoryui_()
			if self.Data.Type == "item" then
				if self.Data.IsSpecial then
					self:_enableequip_(not (self.InventoryUI.Name == playerinventory.EquippedSpecial.Value))
				else
					self:_enableequip_(not (self.InventoryUI.Name == playerinventory.EquippedItem.Value))
				end
			elseif self.Data.Type == "aura" then
				self:_enableequip_(not (self.InventoryUI.Name == playerinventory.EquippedAura.Value))
			end
			self.InventoryUI.Parent = self.InventoryContainer
		else
			if self.InventoryUI then
				self.InventoryUI.Parent = nil
			end
		end
		--// update the shop ui
		self.ShopUI = self.ShopUI or self:_createshopui_()
		if self:_playerownsitem_() then
			self.ShopUI.Main.buy.Visible = false
			self.ShopUI.Main.ownedtag.Text = "OWNED"
			self.ShopUI.Main.ownedtag.Visible = true
			self.ShopUI.Main.Button.Visible = true
			self.ShopUI.LayoutOrder = 999999
			self.ShopUI:SetAttribute("Owned",true)
		else
			if self.Data.CanBuy then
				self.ShopUI.Main.buy.Visible = true
				self.ShopUI.Main.ownedtag.Visible = false
				self.ShopUI.Main.Button.Visible = false
			else
				self.ShopUI.Main.Button.Visible = true
				self.ShopUI.Main.buy.Visible = false
				self.ShopUI.Main.ownedtag.Text = self.Data.Requirements
				self.ShopUI.Main.ownedtag.Visible = true
			end
			self.ShopUI:SetAttribute("Owned",false)
			self.ShopUI.LayoutOrder = self.ShopUI:GetAttribute("Order")
		end
		self.ShopUI.Parent = self.ShopContainer
	end
end


return item