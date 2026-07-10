---------- SERVICES ----------
local RS = game:GetService('ReplicatedStorage')
local MS = game:GetService('MarketplaceService')
local TS = game:GetService('TweenService')
local SG = game:GetService('StarterGui')

---------- VARIABLES ----------
local player = game.Players.LocalPlayer
repeat task.wait(1) until player:FindFirstChild('DataLoaded')
local playerdata = player:WaitForChild('PlayerData')
local playerinventory = playerdata:WaitForChild('Inventory')
local playergamepasses = playerdata:WaitForChild('Gamepasses')

local modules = RS:WaitForChild('Module')
local uitemplates = script.Parent:WaitForChild("Templates")
local componentfolder = script.Parent:WaitForChild("Components")
local remotes = RS:WaitForChild('Remotes')
local sounds = RS:WaitForChild('Assets'):WaitForChild('Sounds')
local notifyevent = script.Parent:WaitForChild("notify")
local debounce = script.Parent:WaitForChild("Debounce")

local globalmodule = require(modules:WaitForChild("GlobalFunction"))
local shopmodule = require(modules:WaitForChild("ShopModule"))
local rbxmodule = require(modules:WaitForChild("RBXModule"))

local MainF = script.Parent:WaitForChild('MainFrame')
local mainframe = MainF:WaitForChild('MainFrame')
local sidebtnsframe = mainframe:WaitForChild('SubCategories')
local frames = mainframe:WaitForChild('Frames')
local topbarframe = MainF:WaitForChild('TopBar')
local errortext = script.Parent:WaitForChild("ErrorText")
local inventorybtn = script.Parent:WaitForChild("InventoryBtn")

local db = false
local notifythread = nil

local components = {}
local Tab = nil
local Subcategory = nil
local ItemInfo = nil

--// require components
for i, v in pairs(componentfolder:GetChildren()) do
	components[v.Name] = require(v)
end
--// create subcategories
Subcategory = components.SubCategory.new(require(script.Parent:WaitForChild("TabUIData")), sidebtnsframe.List, frames)
--// create tab component
Tab = components.Tab.new({
	Inventory = topbarframe:WaitForChild("InventoryBtn"),
	Shop = topbarframe:WaitForChild("ShopBtn")
}, Subcategory, mainframe)
--// create the item info component
ItemInfo = components.ItemInfo.new(MainF:WaitForChild("BlackFade"), MainF:WaitForChild("ItemInfo"), MainF:WaitForChild("PlayerList"))

---------- FUNCTIONS ----------
function notify(message, iserror)
	if notifythread then
		task.cancel(notifythread)
	end

	notifythread = task.spawn(function()
		errortext.Visible = false
		if iserror then
			errortext.TextColor3 = Color3.fromRGB(255,0,0)
			sounds.error:Play()
		else
			errortext.TextColor3 = Color3.fromRGB(255,255,255)
			sounds.notify:Play()
		end
		errortext.Text = string.upper(message)
		errortext.Visible = true
		task.wait(3)
		errortext.Visible = false
	end)
end

local function updateplayercurrency()
	topbarframe.PlayerCash.Amount.Text = globalmodule.abreviatenumber(playerdata.Cash.Value)
	topbarframe.PlayerGems.Amount.Text = globalmodule.abreviatenumber(playerdata.Gems.Value)
end

---------- EVENTS ----------
inventorybtn.MouseEnter:Connect(function()
	if not inventorybtn:GetAttribute("Clicked") and not debounce.Value then
		TS:Create(inventorybtn.UIScale, TweenInfo.new(0.1), {Scale = 1.05}):Play()
	end
end)
inventorybtn.MouseLeave:Connect(function()
	if not inventorybtn:GetAttribute("Clicked") and not debounce.Value then
		TS:Create(inventorybtn.UIScale, TweenInfo.new(0.1), {Scale = 1}):Play()
	end
end)
inventorybtn.MouseButton1Click:Connect(function()
	if inventorybtn:GetAttribute("Clicked") or debounce.Value then
		return
	end
	TS:Create(inventorybtn.UIScale, TweenInfo.new(0.1), {Scale = 0.8}):Play()
	task.delay(0.1,function()
		TS:Create(inventorybtn.UIScale, TweenInfo.new(0.1, Enum.EasingStyle.Back), {Scale = 1}):Play()
	end)
	inventorybtn:SetAttribute("Clicked", true)
	if not debounce.Value then
		debounce.Value = true
		if MainF:GetAttribute("Open") then
			MainF.Visible = false
			MainF:SetAttribute("Open", false)
		else
			MainF.Position = UDim2.fromScale(0.5, 0.4)
			MainF.Visible = true
			TS:Create(MainF, TweenInfo.new(0.2, Enum.EasingStyle.Back), {Position = UDim2.fromScale(0.5, 0.5)}):Play()
			MainF:SetAttribute("Open", true)
		end
		task.wait(0.2)
		debounce.Value = false
	end
	inventorybtn:SetAttribute("Clicked", false)
end)

notifyevent.Event:Connect(notify)
remotes:WaitForChild("messagegift").OnClientEvent:Connect(function(message)
	game:GetService("TextChatService").TextChannels.RBXGeneral:DisplaySystemMessage("[SYSTEM]: "..message)
end)

playerdata.Cash:GetPropertyChangedSignal("Value"):Connect(updateplayercurrency)
playerdata.Gems:GetPropertyChangedSignal("Value"):Connect(updateplayercurrency)

---------- RUN ----------
updateplayercurrency()

--// load all items
for i, v in pairs(shopmodule.Items.CashItems) do --// load cash items
	local obj = components.Item.new({
		Id = v.ToolName,
		Name = v.Name,
		Type = "item",

		Description = v.Description,
		IconId = v.IconImageAssetId,
		Price = v.Price,

		Currency = "cash",

		-- Viewport preview
		ViewportFrame = v.ViewportFrame,
		ToolName      = v.ToolName,
	}, ItemInfo)
	Subcategory:AddItem(obj, "Items", "Items")
end

for i, v in pairs(shopmodule.Items.RobuxItems) do --// load robux items
	task.spawn(function()
		local obj = components.Item.new({
			Id = v.ToolName,
			Name = v.Name,
			Type = "item",

			Currency = "robux",
			ProductId = v.Id,

			-- Viewport preview
			ViewportFrame = v.ViewportFrame,
			ToolName      = v.ToolName,
		}, ItemInfo)
		Subcategory:AddItem(obj, "Special", "Special")
	end)
end

for i, v in pairs(shopmodule.Items.GroupItems) do --// load group items
	task.spawn(function()
		local obj = components.Item.new({
			Id = v.ToolName,
			Name = v.Name,
			Type = "item",

			Description = v.Description,
			IconId = v.IconImageAssetId,
			Price = v.Price,

			Currency = v.PriceType,
			ProductId = v.ProductId,
			GroupNeededId = v.GroupId,

			-- Viewport preview
			ViewportFrame = v.ViewportFrame,
			ToolName      = v.ToolName,
		}, ItemInfo)
		Subcategory:AddItem(obj, "ExItems", "ExItems")
	end)
end

for i, v in pairs(shopmodule.Items.GemItems) do --// load gem items
	local obj = components.Item.new({
		Id = v.ToolName,
		Name = v.Name,
		Type = "item",

		Description = v.Description,
		IconId = v.IconImageAssetId,
		Price = v.Price,

		Currency = "gem",

		-- Viewport preview
		ViewportFrame = v.ViewportFrame,
		ToolName      = v.ToolName,
	}, ItemInfo)
	Subcategory:AddItem(obj, "Special", "GemItems")
end

for i, v in pairs(shopmodule.Auras.CashAuras) do --// load cash auras
	local obj = components.Item.new({
		Id = v.ModelName,
		Name = v.Name,
		Type = "aura",

		Description = v.Description,
		IconId = v.IconImageAssetId,
		Price = v.Price,

		Currency = "cash",

		-- Viewport preview (pakai ModelName untuk aura)
		ViewportFrame = v.ViewportFrame,
		ToolName      = v.ModelName,
	}, ItemInfo)
	Subcategory:AddItem(obj, "Auras", "Auras")
end

for i, v in pairs(shopmodule.Auras.GemAuras) do --// load gem auras
	local obj = components.Item.new({
		Id = v.ModelName,
		Name = v.Name,
		Type = "aura",

		Description = v.Description,
		IconId = v.IconImageAssetId,
		Price = v.Price,

		Currency = "gem",

		-- Viewport preview
		ViewportFrame = v.ViewportFrame,
		ToolName      = v.ModelName,
	}, ItemInfo)
	Subcategory:AddItem(obj, "SpecialAuras", "GemAuras")
end

for i, v in pairs(shopmodule.Auras.RobuxAuras) do --// load robux auras
	task.spawn(function()
		local obj = components.Item.new({
			Id = v.ModelName,
			Name = v.Name,
			Type = "aura",

			Currency = "robux",
			ProductId = v.Id,

			-- Viewport preview
			ViewportFrame = v.ViewportFrame,
			ToolName      = v.ModelName,
		}, ItemInfo)
		Subcategory:AddItem(obj, "SpecialAuras", "SpecialAuras")
	end)
end

for i, v in pairs(rbxmodule.Gamepasses) do --// load all gamepasses
	task.spawn(function()
		local obj = components.Item.new({
			Id = i,
			Type = "gamepass",

			Currency = "robux",
			ProductId = rbxmodule.DevPGamepasses[i],
			GamepassId = v,
			-- (gamepass tidak punya tool, jadi tanpa viewport)
		}, ItemInfo)
		Subcategory:AddItem(obj, nil, "Gamepasses")
	end)
end

for i, v in pairs(rbxmodule.DevProducts.Gem) do --// load all gem devproducts
	task.spawn(function()
		local obj = components.Item.new({
			Id = "currency",
			Type = "gamepass",

			IconId = v.IconId,

			Currency = "robux",
			ProductId = v.ProductId,
			-- (dev product mata uang: tidak ada tool)
		}, ItemInfo)
		Subcategory:AddItem(obj, nil, "GemsFrame")
	end)
end

for i, v in pairs(rbxmodule.DevProducts.Cash) do --// load all cash devproducts
	task.spawn(function()
		local obj = components.Item.new({
			Id = "currency",
			Type = "gamepass",

			IconId = v.IconId,

			Currency = "robux",
			ProductId = v.ProductId,
			-- (dev product mata uang: tidak ada tool)
		}, ItemInfo)
		Subcategory:AddItem(obj, nil, "CashFrame")
	end)
end

Tab:OpenTab("Inventory")

