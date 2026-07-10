--[[SERVICES]]--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--[[MODULES]]--

--[[CONSTANTS]]--

--[[GLOBALS]]--

local mouse = Players.LocalPlayer:GetMouse()

local musicPlayerMaster = script.Parent.MusicPlayerMaster

--[[FUNCTIONS]]--

local function startDrag()
	
	local startMousePosition = Vector2.new(mouse.X, mouse.Y)
	local startPlayerAbsolutePosition = musicPlayerMaster.AbsolutePosition
	
	local function update()
		
		local currentMousePosition = Vector2.new(mouse.X, mouse.Y)
		local mouseDelta = currentMousePosition - startMousePosition
		local newPlayerAbsolutePosition = startPlayerAbsolutePosition + mouseDelta
		musicPlayerMaster.Position = UDim2.fromOffset(newPlayerAbsolutePosition.X, newPlayerAbsolutePosition.Y)
		
	end
	
	local updateConnection = RunService.Heartbeat:Connect(update)
	local checkConnection
	
	checkConnection = musicPlayerMaster.MusicPlayer.DragButton.MouseButton1Up:Connect(function()
		
		updateConnection:Disconnect()
		checkConnection:Disconnect()
		
	end)
	
end

musicPlayerMaster.MusicPlayer.DragButton.MouseButton1Down:Connect(startDrag)

--[[SIGNALS]]--
