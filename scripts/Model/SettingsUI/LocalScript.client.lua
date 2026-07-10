---------- SERVICES ----------
local RS = game:GetService('ReplicatedStorage')
local TS = game:GetService('TweenService')

---------- VARIABLES ----------
local remotes = RS:WaitForChild('Remotes')
local mainframe = script.Parent:WaitForChild('MainFrame')
local container = mainframe:WaitForChild('SettingsContainers')
local settingseventfolder = script.Parent:WaitForChild('SettingsEvents')

local CONFIGURATION = {
    
    ['HD'] = {container:FindFirstChild('HD'),true},
    
  --  ['JBL'] = {container:FindFirstChild('JBL'),true},
        
	['BILLBOARD'] = {container:FindFirstChild('BBUI'),true},
	
	['DOF'] = {container:FindFirstChild('DOF'),true},
	
	--['RAIN'] = {container:FindFirstChild('RAIN'),false},
	
	['AURA'] = {container:FindFirstChild('AURA'),true},
	
--	["CAR_SOUND"] = {container:FindFirstChild("CAR_SOUND"), true}

	['SWAY'] = {container:FindFirstChild('SWAY'),true},

}
local db = false


---------- FUNCTIONS ----------
local function toggle(toggler,condition)
    if condition then
        TS:Create(toggler,TweenInfo.new(0.2),{BackgroundColor3 = Color3.fromRGB(0, 170, 0)}):Play()
        TS:Create(toggler.circle,TweenInfo.new(0.2),{Position = UDim2.fromScale(0.07,0.5)}):Play()
        TS:Create(toggler.TextLabel,TweenInfo.new(0.1),{TextTransparency = 1}):Play()
        toggler.TextLabel.Text = 'ON'
        toggler.TextLabel.TextXAlignment = Enum.TextXAlignment.Right
        TS:Create(toggler.TextLabel,TweenInfo.new(0.1),{TextTransparency = 0}):Play()
    else
        TS:Create(toggler,TweenInfo.new(0.2),{BackgroundColor3 = Color3.fromRGB(255, 0, 0)}):Play()
        TS:Create(toggler.circle,TweenInfo.new(0.2),{Position = UDim2.fromScale(0.61,0.5)}):Play()
        TS:Create(toggler.TextLabel,TweenInfo.new(0.1),{TextTransparency = 1}):Play()
        toggler.TextLabel.Text = 'OFF'
        toggler.TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TS:Create(toggler.TextLabel,TweenInfo.new(0.1),{TextTransparency = 0}):Play()
    end
end

---------- RUN ----------
for i, v in pairs(CONFIGURATION) do
    v[1]:SetAttribute('Activated',v[2])
    toggle(v[1].Toggler,v[2])
    settingseventfolder[i]:Invoke(v[1]:GetAttribute('Activated'))
    v[1].Toggler.TextButton.MouseButton1Click:Connect(function()
        if not db then
            db = true
            v[1]:SetAttribute('Activated',not v[1]:GetAttribute('Activated'))
            settingseventfolder[i]:Invoke(v[1]:GetAttribute('Activated'))
            task.wait(0.2)
            db = false
        end
    end)
    v[1]:GetAttributeChangedSignal('Activated'):Connect(function()
        toggle(v[1].Toggler,v[1]:GetAttribute('Activated'))
    end)
end