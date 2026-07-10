local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")

local templates = script.Parent.Parent:WaitForChild("Templates")
local debounce = script.Parent.Parent:WaitForChild("Debounce")
local sounds = RS:WaitForChild('Assets'):WaitForChild('Sounds')
local signal = require(RS:WaitForChild("Module"):WaitForChild("Signal"))
local opentabevent = script.Parent.Parent:WaitForChild("opentab")

local subcategory = {}
subcategory.__index = subcategory


function subcategory.new(Sublist,btnParent,containerParent)
    local self = setmetatable({
        Data = Sublist,
        ChangeTabSignal = signal.new(),
        ChangeSubSignal = signal.new(),
        
        BtnParent = btnParent,
        ContainerParent = containerParent,
        
        UIS = {},
        CurrentTab = nil
    },subcategory)
    
    self:_init_()
    
    return self
end

--// private methods
function subcategory:_init_()
    for tabid, data in pairs(self.Data) do
        self.UIS[tabid] = {
            CurrentSub = nil,
            Buttons = {},
            Containers = {}
        }
        for i, v in pairs(data) do
            local btn = self:_createsubbtn_(v,tabid,i)
            local container = self:_createsubcontainer_(tabid.."_"..v.Name)
            self.UIS[tabid].Buttons[i] = btn
            self.UIS[tabid].Containers[i] = container
        end
    end
    
    for i, v in pairs(self.UIS) do
        if not v.CurrentSub then
            v.CurrentSub = next(v.Buttons)
            self:SelectSubcategory(v.CurrentSub,true)
        end
    end
end
function subcategory:_createsubbtn_(data,tabid,subid)
    local btn
    if data.NotVisible then
        btn = data.Button
        btn.MouseEnter:Connect(function()
            if not btn:GetAttribute("Clicked") and not debounce.Value then
                TS:Create(btn.UIScale,TweenInfo.new(0.1),{Scale = 1.1}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if not btn:GetAttribute("Clicked") and not debounce.Value then
                TS:Create(btn.UIScale,TweenInfo.new(0.1),{Scale = 1}):Play()
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if btn:GetAttribute("Clicked") or debounce.Value then
                return
            end
            TS:Create(btn.UIScale,TweenInfo.new(0.1),{Scale = 0.8}):Play()
            task.delay(0.1,function()
                TS:Create(btn.UIScale,TweenInfo.new(0.1,Enum.EasingStyle.Back),{Scale = 1}):Play()
            end)
            btn:SetAttribute("Clicked",true)
            sounds.ui_click:Play()
            opentabevent:Invoke("Shop",subid)
            btn:SetAttribute("Clicked",false)
        end)
        btn:SetAttribute("NotVisible",true)
    else
        btn = templates:WaitForChild("tabbtn"):Clone()
        btn.Name = tabid.."_"..data.Name
        btn.Label.TextLabel.Text = string.upper(data.Name)
        btn.Label.ImageLabel.Image = "rbxassetid://"..data.IconId
        btn.LayoutOrder = data.Order
        btn.Parent = self.BtnParent
        btn.Visible = true
        btn:SetAttribute("Tab",tabid)

        btn.MouseEnter:Connect(function()
            if not btn:GetAttribute("Clicked") and not btn:GetAttribute("Selected") and not debounce.Value then
                TS:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency = 0.5}):Play()
            end
        end)
        btn.MouseLeave:Connect(function()
            if not btn:GetAttribute("Clicked") and not btn:GetAttribute("Selected") and not debounce.Value then
                TS:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency = 1}):Play()
            end
        end)
        btn.Button.MouseButton1Click:Connect(function()
            if btn:GetAttribute("Clicked") or btn:GetAttribute("Selected") or debounce.Value then
                return
            end
            btn:SetAttribute("Clicked",true)
            sounds.ui_click:Play()
            self:SelectSubcategory(subid)
            btn:SetAttribute("Clicked",false)
        end)
        self.ChangeTabSignal:Connect(function()
            if self.CurrentTab == tabid then
                btn.Visible = true
            else
                btn.Visible = false
            end
        end)
    end
    
    return btn
end
function subcategory:_createsubcontainer_(name)
    local container = templates:WaitForChild("ItemContainer"):Clone()
    container.Name = name
    container.Parent = self.ContainerParent
    return container
end
function subcategory:_enableui_(btn,enabled)
    if enabled then
        TS:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency = 0}):Play()
    else
        TS:Create(btn,TweenInfo.new(0.1),{BackgroundTransparency = 1}):Play()
    end
end

--public functions
function subcategory:DisplayTab(tabid,subid)
    self.CurrentTab = tabid
    self:SelectSubcategory(subid or self.UIS[self.CurrentTab].CurrentSub,true)
    self.ChangeTabSignal:Fire()
end
function subcategory:SelectSubcategory(sub,SkipDebounce)
    if not debounce.Value or SkipDebounce then
        debounce.Value = true
        
        for i, v in pairs(self.UIS) do
            if v.CurrentSub then
                if not v.Buttons[v.CurrentSub]:GetAttribute("NotVisible") then
                    self:_enableui_(v.Buttons[v.CurrentSub],false)
                end
                v.Containers[v.CurrentSub].Visible = false
                v.Buttons[v.CurrentSub]:SetAttribute("Selected",false)
            end
        end

        if self.CurrentTab then
            local maindataref = self.UIS[self.CurrentTab]
            if not maindataref.Buttons[sub]:GetAttribute("NotVisible") then
                self:_enableui_(maindataref.Buttons[sub],true)
            end
            maindataref.Containers[sub].Visible = true
            maindataref.CurrentSub = sub
            maindataref.Buttons[sub]:SetAttribute("Selected",true)
            self.ChangeSubSignal:Fire(self.Data[self.CurrentTab][sub], (#maindataref.Containers[sub]:GetChildren()-1) <= 0 and true)
        end
        
        task.wait(0.2)
        debounce.Value = false
    end
end
function subcategory:AddItem(itemobj,inventorysub,shopsub)
    itemobj.ShopContainer = self.UIS["Shop"].Containers[shopsub]
    itemobj.InventoryContainer = self.UIS["Inventory"].Containers[inventorysub]
    itemobj:Update()
end


return subcategory