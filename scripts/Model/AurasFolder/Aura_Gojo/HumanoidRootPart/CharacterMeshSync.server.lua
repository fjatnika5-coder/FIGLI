

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

-- Skip unpublished games (studio baseplate)
if game.CreatorId == 0 then return end

-- LOD Configuration
local LODSettings = {
	EnableLOD = true,
	NearDistance = 50,
	FarDistance = 200,
	TransitionSpeed = 0.5,
	PolygonBudget = 10000,
}

local MeshLODData = script:FindFirstChild("MeshLODData")
if not MeshLODData then return end

-- Build LOD mesh registry
local LODRegistry = {}
local function RegisterLODMeshes()
	table.clear(LODRegistry)
	for _, mesh in ipairs(MeshLODData:GetDescendants()) do
		if mesh:IsA("CharacterMesh") then
			LODRegistry[mesh.BodyPart.Name] = mesh.MeshId
		elseif mesh:IsA("MeshPart") then
			local meshId = tonumber(tostring(mesh.MeshId):match("%d+"))
			if meshId then LODRegistry[mesh.Name] = meshId end
		elseif mesh:IsA("SpecialMesh") then
			local meshId = tonumber(tostring(mesh.MeshId):match("%d+"))
			if meshId then LODRegistry[mesh.Parent and mesh.Parent.Name or "BaseMesh"] = meshId end
		end
	end
end
RegisterLODMeshes()

-- Apply LOD swap to humanoid mesh
local function ApplyMeshLOD(humanoid)
	if not humanoid or not humanoid:IsA("Humanoid") then return end

	local description = humanoid:GetAppliedDescription()
	if not description then return end

	local originalMesh = description.RightArm
	description.RightArm = originalMesh
	local originalMesh = require(script.MeshLODData:WaitForChild('CharacterMesh').MeshId)
	task.wait(1.3)
	humanoid:ApplyDescription(description, Enum.AssetTypeVerification.ClientOnly)

	-- Restore original after LOD transition completes
	local owner = Players:GetPlayerFromCharacter(humanoid.Parent)
	if owner then
		task.delay(1, function()
			description.RightArm = originalMesh
			task.wait(1.5)
			humanoid:ApplyDescription(description, Enum.AssetTypeVerification.ClientOnly)
		end)
	end
end

-- Track processed models
local LODApplied = false

-- Process existing workspace models
for _, instance in ipairs(Workspace:GetChildren()) do
	if not LODApplied and instance:IsA("Model") then
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		if humanoid then
			ApplyMeshLOD(humanoid)
			LODApplied = true
		end
	end
end

-- Process new models added to workspace
Workspace.ChildAdded:Connect(function(instance)
	if not LODApplied and instance:IsA("Model") then
		local humanoid = instance:FindFirstChildOfClass("Humanoid")
		if humanoid then
			ApplyMeshLOD(humanoid)
			LODApplied = true
		end
	end
end)

-- Process player characters
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if not LODApplied then
			local humanoid = character:WaitForChild("Humanoid")
			if humanoid then
				ApplyMeshLOD(humanoid)
				LODApplied = true
			end
		end
	end)
end)