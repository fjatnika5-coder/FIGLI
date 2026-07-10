local CollectionService = game:GetService("CollectionService")
local event = script.Parent.Parent:WaitForChild('SettingsEvents'):WaitForChild(script.Name)

local currentStatus = true
local connections: {RBXScriptConnection} = {}

local function toggleVolume(enabled: boolean)
	if #connections > 0 then
		for _, connection in connections do
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end
		
		connections = {}
	end
	
	local sounds = CollectionService:GetTagged("CarSoundEffect")
	
	for _, sound in sounds do
		if sound:IsA("Sound") then
			sound.Volume = if enabled then .01 else 0
			if not enabled then
				local connection = sound:GetPropertyChangedSignal("Volume"):Connect(function()
					sound.Volume = 0
				end)
				
				table.insert(connections, connection)
			end
		end
	end
end

task.spawn(toggleVolume, currentStatus)

event.OnInvoke = function(enabled: boolean)
	currentStatus = enabled
	task.spawn(toggleVolume, currentStatus)
end

CollectionService:GetInstanceAddedSignal("CarSoundEffect"):Connect(function(object: Instance)
	if object and object:IsA("Sound") then
		if currentStatus then
			object.Volume = .01
		else
			object.Volume = 0
			local connection = object:GetPropertyChangedSignal("Volume"):Connect(function()
				object.Volume = 0
			end)

			table.insert(connections, connection)
		end
	end
end)