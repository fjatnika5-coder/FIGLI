-- This is a copy of a public ModuleScript (Asset ID: 343254562)
-- A local copy is easier to debug while guarding the template from non-compatible asset updates.

local ClickerModule = {}

local remoteEvent = Instance.new('RemoteEvent', game.ReplicatedStorage)
remoteEvent.Name = game:GetService('HttpService'):GenerateGUID(false)

local localScript = script.ROBLOX_InteractiveClicker
localScript.RemoteValue.Value = remoteEvent

for _, player in pairs(game.Players:GetChildren()) do
	localScript:Clone().Parent = player:WaitForChild("PlayerGui")
end

localScript:Clone().Parent = game.StarterGui

ClickerModule.RemoteEvent = remoteEvent

function ClickerModule:CanClick(partA, partB, maxDistance, ignoreList, terrainCellsAreCubes, ignoreWater)
	if not ignoreList then
		ignoreList = {}
	end
	table.insert(ignoreList, partA)
	local ray = Ray.new(partA.Position, (partB.Position - partA.Position).unit * maxDistance)
	local part = game.Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList, terrainCellsAreCubes, ignoreWater)
	return part == partB
end

function ClickerModule:LoadLocalModule(module, ...)
	remoteEvent:FireAllClients(module, ...)
	local data = ...
	game.Players.PlayerAdded:connect(function(player)
		player:WaitForChild("PlayerGui")
		remoteEvent:FireClient(player, module, data)
	end)
end

return ClickerModule