local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local MS = game:GetService("MarketplaceService")

local templates = script.Parent.Parent:WaitForChild("Templates")
local notifyremote = script.Parent.Parent:WaitForChild("notify")
local sounds = RS:WaitForChild('Assets'):WaitForChild('Sounds')
local shopremotes = RS:WaitForChild("Remotes"):WaitForChild("ShopInventoryRemotes")
local signal = require(RS:WaitForChild("Module"):WaitForChild("Signal"))

local iteminfo = {}
iteminfo.__index = iteminfo


function iteminfo.new(blackfade,frame,playerframe)
    local self = setmetatable({
        Fade = blackfade,
        Frame = frame,
        PlayerFrame = playerframe,
        
        db = false,
        EndProcessSignal = signal.new(),
        ProcessFunction = nil,
        SelectedPlayer = nil,
        ProductName = nil,
        ProductId = nil
    },iteminfo)
    
    self:_init_()
    
    return self
end

--//private methods
function iteminfo:_init_()
    self:_animateBtn_(self.Frame.close,function()
        if not self.db then
            self.db = true
            self:_close_()
            task.wait(0.2)
            self.db = false
        end
    end)
    self:_animateBtn_(self.Frame.Buttons.buy,function()
        if not self.db then
            self.db = true
            self.Frame.loading:SetAttribute("Load",true)
            if self.ProcessFunction then
                self.ProcessFunction()
            end
            task.wait(0.2)
            self.Frame.loading:SetAttribute("Load",false)
            self:_close_()
            task.wait(0.2)
            self.db = false
        end
    end)
    self:_animateBtn_(self.Frame.Buttons.gift,function()
        if not self.db then
            self.db = true
            self:_showplayers_()
            task.wait(0.2)
            self.db = false
        end
    end)
    self:_animateBtn_(self.PlayerFrame.close,function()
        if not self.db then
            self.db = true
            self:_close_(true)
            self:_open_()
            task.wait(0.2)
            self.db = false
        end
    end)
    self:_animateBtn_(self.PlayerFrame.SelectBtn.select,function()
        if not self.db then
            self.db = true
            if self.SelectedPlayer and self.ProductName and self.ProductId then
                local selectplayerreq = shopremotes:WaitForChild("selectplayertogift"):InvokeServer(self.SelectedPlayer.Name,self.ProductName)
                if selectplayerreq then
                    if selectplayerreq[1] then
                        MS:PromptProductPurchase(game.Players.LocalPlayer,self.ProductId)
                        task.wait(0.2)
                        self:_close_()
                    else
                        notifyremote:Fire(selectplayerreq[2],true)
                    end
                else
                    notifyremote:Fire("There was an error. Please try again later",true)
                end
            end
            task.wait(0.2)
            self.db = false
        end
    end)
    
    for i, v in pairs(game.Players:GetChildren()) do
        self:_updateplayer_(v)
    end
    game.Players.PlayerAdded:Connect(function(p)
        self:_updateplayer_(p)
    end)
    game.Players.PlayerRemoving:Connect(function(p)
        self:_updateplayer_(p,true)
    end)
    task.spawn(function()
        while true do
            if self.Frame.loading:GetAttribute("Load") then
                self.Frame.loading.Visible = true
                self.Frame.loading.ImageLabel.Rotation += 5
                task.wait()
            else
                self.Frame.loading.Visible = false
                self.Frame.loading.ImageLabel.Rotation = 0
                self.Frame.loading:GetAttributeChangedSignal("Load"):Wait()
            end
        end
    end)
end
function iteminfo:_animateBtn_(btn,func,uiscale)
    uiscale = uiscale or btn:FindFirstChild("UIScale")
    btn.MouseEnter:Connect(function()
        if not btn:GetAttribute("Clicked") and not self.db then
            TS:Create(uiscale,TweenInfo.new(0.1),{Scale = 1.05}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not btn:GetAttribute("Clicked") and not self.db then
            TS:Create(uiscale,TweenInfo.new(0.1),{Scale = 1}):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if btn:GetAttribute("Clicked") or self.db then
            return
        end
        TS:Create(uiscale,TweenInfo.new(0.1),{Scale = 0.8}):Play()
        task.delay(0.1,function()
            TS:Create(uiscale,TweenInfo.new(0.1,Enum.EasingStyle.Back),{Scale = 1}):Play()
        end)
        btn:SetAttribute("Clicked",true)
        func()
        btn:SetAttribute("Clicked",false)
    end)
end
function iteminfo:_close_(ignoreEndProcess)
    if not ignoreEndProcess then
        TS:Create(self.Fade,TweenInfo.new(0.3),{BackgroundTransparency = 1}):Play()
    end
    self.Frame.Visible = false
    self.PlayerFrame.Visible = false
    if not ignoreEndProcess then
        task.wait(0.3)
        self.ProductId = nil
        self.ProductName = nil
        self.ProcessFunction = nil
        self.EndProcessSignal:Fire()
    end
end
function iteminfo:_open_()
    self.Frame.Position = UDim2.fromScale(0.5,0.4)
    TS:Create(self.Fade,TweenInfo.new(0.3),{BackgroundTransparency = 0.3}):Play()
    task.wait(0.1)
    self.Frame.Visible = true
    TS:Create(self.Frame,TweenInfo.new(0.2,Enum.EasingStyle.Back),{Position = UDim2.fromScale(0.5,0.5)}):Play()
end
function iteminfo:_showplayers_()
    self.PlayerFrame.Position = UDim2.fromScale(0.5,0.4)
    self.Frame.Visible = false
    self.PlayerFrame.SelectBtn.Visible = false
    if self.SelectedPlayer then
        self.SelectedPlayer.UIStroke.Enabled = false
        self.SelectedPlayer = nil
    end
    task.wait(0.1)
    self.PlayerFrame.Visible = true
    TS:Create(self.PlayerFrame,TweenInfo.new(0.2,Enum.EasingStyle.Back),{Position = UDim2.fromScale(0.5,0.5)}):Play()
end
function iteminfo:_updateplayer_(player,remove)
    if remove then
        if self.PlayerFrame.List:FindFirstChild(player.Name) then
            self.PlayerFrame.List:FindFirstChild(player.Name):Destroy()
        end
    else
        if self.PlayerFrame.List:FindFirstChild(player.Name) then
            return
        end
        local sample = templates:WaitForChild("playersample"):Clone()
        sample.Name = player.Name
        pcall(function()
            sample.ImageLabel.Image = game.Players:GetUserThumbnailAsync(player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420)
        end)
        sample.TextLabel.Text = player.Name
        self:_animateBtn_(sample,function()
            if not self.db then
                self.db = true
                if self.SelectedPlayer then
                    self.SelectedPlayer.UIStroke.Enabled = false
                end
                sample.UIStroke.Enabled = true
                self.SelectedPlayer = sample
                self.PlayerFrame.SelectBtn.select.TextLabel.Text = "GIFT "..player.Name
                self.PlayerFrame.SelectBtn.Visible = true
                task.wait(0.2)
                self.db = false
            end
        end,sample.ImageLabel.UIScale)
        sample.Parent = self.PlayerFrame.List
        sample.Visible = true
    end
end

--// public methods
function iteminfo:DisplayItem(itemdata,processfunction,productname,productid)
    self.Frame.ItemImage.Image = "rbxassetid://"..itemdata.IconId
    self.Frame.ItemDesc.Text = itemdata.Description
    self.Frame.ItemName.Text = itemdata.Name
    if itemdata.CanBuy then
        if itemdata.CanGift then
            self.Frame.Buttons.gift.Visible = true
        else
            self.Frame.Buttons.gift.Visible = false
        end
        if itemdata.Owned then
            self.Frame.Buttons.ownedframe.Visible = true
            self.Frame.Buttons.buy.Visible = false
        else
            self.Frame.Buttons.buy.BackgroundColor3 = itemdata.Color
            self.Frame.Buttons.buy.ImageLabel.Image = "rbxassetid://"..itemdata.ButtonIconId
            self.Frame.Buttons.buy.ImageLabel.Rotation = itemdata.IconRotation
            self.Frame.Buttons.buy.TextLabel.Text = itemdata.Price
            self.Frame.Buttons.ownedframe.Visible = false
            self.Frame.Buttons.buy.Visible = true
        end
        self.Frame.Buttons.Visible = true
        self.Frame.requirements.Visible = false
    else
        self.Frame.Buttons.Visible = false
        self.Frame.requirements.TextLabel.Text = itemdata.Requirements
        self.Frame.requirements.Visible = true
    end
    self.ProcessFunction = processfunction
    self.ProductName = productname
    self.ProductId = productid
    
    self:_open_()
    self.EndProcessSignal:Wait()
end


return iteminfo