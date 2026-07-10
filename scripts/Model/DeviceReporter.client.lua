--[[
	NameTag System - Client Script
	
	Reports the player's device type to the server.
	
	Place this LocalScript in StarterPlayerScripts
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Detect device type
local function getDeviceType()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Mobile"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Console"
	else
		return "PC"
	end
end

-- Wait for remote and fire
local DeviceTypeRemote = ReplicatedStorage:WaitForChild("DeviceTypeReport")
DeviceTypeRemote:FireServer(getDeviceType())