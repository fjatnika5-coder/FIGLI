local UtilModule = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local uxpRS = ReplicatedStorage.uxpRS
local AdminPanelRS = uxpRS.AdminPanel
local PanelSettings = require(AdminPanelRS.PanelSettings)

function UtilModule:ReturnPermission(player)
	local TotalPermission = {}
	for i,v in pairs(PanelSettings.Permissions.GroupPermission) do
		if player:IsInGroup(i) then
			for i2, v2 in pairs(v) do
				if i2 == player:GetRankInGroup(i) then
					for i3, v3 in pairs(v2) do
						if not table.find(TotalPermission, v3) then
							table.insert(TotalPermission, v3)
						end
					end
					break
				end
			end
			break
		end
	end
	if player.Team then
		for i,v in pairs(PanelSettings.Permissions.TeamPermission) do
			if player.Team.Name == i then
				for i2, v2 in pairs(v) do
					if not table.find(TotalPermission, v2) then
						table.insert(TotalPermission, v2)
					end
				end
				break
			end
		end
	end
	for i,v in pairs(PanelSettings.Permissions.GamepassPermission) do
		local success, hasGamepass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, i)
		end)
		if success then
			if hasGamepass then
				for i2, v2 in pairs(v) do
					if not table.find(TotalPermission, v2) then
						table.insert(TotalPermission, v2)
					end
				end
			end
		end
	end
	for i,v in pairs(PanelSettings.Permissions.IDPermission) do
		if i == player.UserId then
			for i2, v2 in pairs(v) do
				if not table.find(TotalPermission, v2) then
					table.insert(TotalPermission, v2)
				end
			end
			break
		end
	end
	return TotalPermission
end

return UtilModule
