local debounce = script.Parent.Parent:WaitForChild("Debounce")
local sounds = game:GetService("ReplicatedStorage"):WaitForChild('Assets'):WaitForChild('Sounds')

local searchbar = script.Parent.Parent:WaitForChild("MainFrame"):WaitForChild("MainFrame"):WaitForChild("Frames"):WaitForChild("searchbar")
local opentabevent = script.Parent.Parent:WaitForChild("opentab")

local tab = {}
tab.__index = tab


function tab.new(TabData,SubCategoryObject,mainframe)
    local self = setmetatable({
        Tabs = TabData,
        CurrentTab = nil,
        
        SubCategoryObject = SubCategoryObject,
        
        MainFrame = mainframe
    },tab)
    
    self:_init_()
    
    return self
end

--// private methods
function tab:_init_()
    for i, v in pairs(self.Tabs) do
        v:SetAttribute("Tab",i)
        v.MouseEnter:Connect(function()
            if not v:GetAttribute("Clicked") and not v:GetAttribute("Selected") then
                v.UIGradient.Enabled = false
            end
        end)
        v.MouseLeave:Connect(function()
            if not v:GetAttribute("Clicked") and not v:GetAttribute("Selected") then
                v.UIGradient.Enabled = true
            end
        end)
        v.Button.MouseButton1Click:Connect(function()
            if v:GetAttribute("Clicked") or v:GetAttribute("Selected") or debounce.Value then
                return
            end
            v:SetAttribute("Clicked",true)
            sounds.ui_click:Play()
            self:_enabletab_(i,true)
            if self.CurrentTab and self.CurrentTab ~= i then
                self:_enabletab_(self.CurrentTab,false)
            end
            self:OpenTab(i)
            v:SetAttribute("Clicked",false)
        end)
    end
    
    self.SubCategoryObject.ChangeSubSignal:Connect(function(subdata,isempty)
        self.MainFrame.Frames.Title.Text = string.upper(subdata.Name)
        self.MainFrame.Frames.TitleIcon.Image = "rbxassetid://"..subdata.IconId
        self.MainFrame.Frames.WarnText.Text = "You currently don't own any '"..subdata.Name.."'."
        self.MainFrame.Frames.WarnText.Visible = isempty
    end)
    
    opentabevent.OnInvoke = function(...)
        self:OpenTab(...)
    end
end
function tab:_enabletab_(tabid,enable)
    local tabui = self:_gettabui_fromtabid_(tabid)
    
    if enable then
        searchbar.Visible = tabid == "Inventory"
        tabui.UIGradient.Enabled = true
        tabui.BackgroundColor3 = Color3.fromRGB(46,46,46)
        tabui.Label.ImageLabel.ImageColor3 = tabui:GetAttribute("SelectedColor")
        tabui.Label.TextLabel.TextColor3 = tabui:GetAttribute("SelectedColor")
        tabui:SetAttribute("Selected",true)
    else
        tabui.UIGradient.Enabled = true
        tabui.BackgroundColor3 = Color3.fromRGB(36,36,36)
        tabui.Label.ImageLabel.ImageColor3 = tabui:GetAttribute("UnselectedColor")
        tabui.Label.TextLabel.TextColor3 = tabui:GetAttribute("UnselectedColor")
        tabui:SetAttribute("Selected",false)
    end
end
function tab:_gettabui_fromtabid_(tabid)
    return self.Tabs[tabid]
end

--// public functions
function tab:OpenTab(TabId,subid)
    if not debounce.Value then
        debounce.Value = true
        if not self.CurrentTab then
            for i, v in pairs(self.Tabs) do
                self:_enabletab_(i,false)
            end
        else
            self:_enabletab_(self.CurrentTab,false)
        end
        self.CurrentTab = TabId
        self:_enabletab_(TabId,true)
        self.SubCategoryObject:DisplayTab(TabId,subid)
        task.wait(0.2)
        debounce.Value = false
    end
end


return tab