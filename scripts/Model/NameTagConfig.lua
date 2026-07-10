--[[
	NameTag Configuration Module (Updated - With Custom Hardcoded Players)
	
	This module allows you to easily customize:
	- Roles and their requirements
	- Colors (gradient, text, background)
	- Status icons
	- Custom player overrides
	- Hardcoded special players
	- Display settings
	
	Place this ModuleScript in ReplicatedStorage
]]

local NameTagConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- GROUP SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.GroupId = 111109796

-- ═══════════════════════════════════════════════════════════════════════════
-- HARDCODED SPECIAL PLAYERS (From your old system)
-- These have highest priority and override everything else
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.SpecialPlayers = {
	[8856448564] = {Label = "OWNER", Background = Color3.fromRGB(255, 0, 0), TextColor = Color3.fromRGB(0, 0, 0), Verified = true, IsRGB = true, Icons = {"Founder", "Verified", "Member"}},

}

-- ═══════════════════════════════════════════════════════════════════════════
-- ROLE DEFINITIONS
-- Define roles in order of priority (highest first)
-- The system will use the first matching role for each player
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.Roles = {
	-- Group rank-based roles (checked by minimum rank)
	{
		Name = "Developer",
		Type = "GroupRank",
		MinRank = 255,
		GradientColor = Color3.fromRGB(0, 0, 0),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"Founder", "Verified"},
	},
	{
		Name = "Founder",
		Type = "GroupRank",
		MinRank = 254,
		GradientColor = Color3.fromRGB(255, 255, 0),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"Founder", "Verified"},
	},
	{
		Name = "Builder",
		Type = "GroupRank",
		MinRank = 253,
		GradientColor = Color3.fromRGB(85, 255, 255),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"Founder", "Verified"},
	},
	{
		Name = "Admin",
		Type = "GroupRank",
		MinRank = 252,
		GradientColor = Color3.fromRGB(170, 0, 127),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"CoFounder", "Verified"},
	},
	{
		Name = "Staff",
		Type = "GroupRank",
		MinRank = 251,
		GradientColor = Color3.fromRGB(255, 85, 255),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"CoFounder", "Verified"},
	},
	{
		Name = "Moderator",
		Type = "GroupRank",
		MinRank = 250,
		GradientColor = Color3.fromRGB(7, 255, 139),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"CoFounder", "Verified"},
	},
	{
		Name = "Warga Babeh",
		Type = "GroupRank",
		MinRank = 1,
		GradientColor = Color3.fromRGB(85, 170, 0),
		TextColor = Color3.fromRGB(0, 0, 0),
		Icons = {"Player", "Verified"},
	},
}

-- Default role for players who don't match any criteria
NameTagConfig.DefaultRole = {
	Name = "Pengunjung",
	GradientColor = Color3.fromRGB(132, 132, 132),
	TextColor = Color3.fromRGB(0, 0, 0),
	Icons = {"Player"},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CUSTOM PLAYER OVERRIDES (Dynamic - set by NameTagManager)
-- These are runtime overrides that can be changed in-game
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.CustomPlayers = {
	-- These will be populated by the NameTagManager addon
}

-- ═══════════════════════════════════════════════════════════════════════════
-- USERNAME DISPLAY SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.UsernameSettings = {
	-- Default colors (can be overridden per-role or per-player)
	DefaultColor = Color3.fromRGB(255, 255, 255),
	DefaultOutlineColor = Color3.fromRGB(0, 0, 0),

	-- Use DisplayName instead of Username
	UseDisplayName = true,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DEVICE ICONS
-- Map device types to icon names in your StatusFrame
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.DeviceIcons = {
	PC = "PC",
	Mobile = "Mobile",
	Console = "Console",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ALL AVAILABLE STATUS ICONS
-- List all icon names that exist in your StatusFrame
-- Used to hide all icons before showing relevant ones
-- ═══════════════════════════════════════════════════════════════════════════

NameTagConfig.AllStatusIcons = {
	"Founder",
	"CoFounder",
	"Member",
	"Player",
	"Verified",
	"Mobile",
	"PC",
	"Console",
	-- Add any custom icons here
}

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Add a new role dynamically
function NameTagConfig:AddRole(roleData, priority)
	priority = priority or #self.Roles + 1
	table.insert(self.Roles, priority, roleData)
end

-- Add a custom player override
function NameTagConfig:SetCustomPlayer(userId, data)
	self.CustomPlayers[userId] = data
end

-- Remove a custom player override
function NameTagConfig:RemoveCustomPlayer(userId)
	self.CustomPlayers[userId] = nil
end

-- Find role for a player
function NameTagConfig:GetRoleForPlayer(player)
	local userId = player.UserId

	-- Check special hardcoded players FIRST (highest priority)
	if self.SpecialPlayers[userId] then
		local special = self.SpecialPlayers[userId]
		return {
			Name = special.Label,
			GradientColor = special.Background,
			TextColor = special.TextColor,
			Icons = special.Icons,
			IsRGB = special.IsRGB or false,
			UsernameColor = special.UsernameColor,
			UsernameOutlineColor = special.UsernameOutlineColor,
		}
	end

	-- Then check dynamic custom player overrides (from NameTagManager)
	if self.CustomPlayers[userId] then
		local custom = self.CustomPlayers[userId]
		return {
			Name = custom.RoleName or "Custom",
			GradientColor = custom.GradientColor or self.DefaultRole.GradientColor,
			TextColor = custom.TextColor or self.DefaultRole.TextColor,
			Icons = custom.Icons or self.DefaultRole.Icons,
			IsRGB = custom.IsRGB or false,
			UsernameColor = custom.UsernameColor,
			UsernameOutlineColor = custom.UsernameOutlineColor,
		}
	end

	-- Get group rank
	local groupRank = 0
	local success, result = pcall(function()
		return player:GetRankInGroup(self.GroupId)
	end)
	if success then
		groupRank = result
	end

	-- Check roles in order
	for _, role in ipairs(self.Roles) do
		local matches = false

		if role.Type == "UserId" and role.Value == userId then
			matches = true
		elseif role.Type == "GroupRank" and groupRank >= role.MinRank then
			matches = true
		elseif role.Type == "Gamepass" then
			-- Add gamepass check if needed
			local MarketplaceService = game:GetService("MarketplaceService")
			local hasPass = false
			pcall(function()
				hasPass = MarketplaceService:UserOwnsGamePassAsync(userId, role.GamepassId)
			end)
			if hasPass then
				matches = true
			end
		elseif role.Type == "Badge" then
			-- Add badge check if needed
			local BadgeService = game:GetService("BadgeService")
			local hasBadge = false
			pcall(function()
				hasBadge = BadgeService:UserHasBadgeAsync(userId, role.BadgeId)
			end)
			if hasBadge then
				matches = true
			end
		elseif role.Type == "Team" then
			-- Team-based role
			if player.Team and player.Team.Name == role.TeamName then
				matches = true
			end
		elseif role.Type == "Attribute" then
			-- Attribute-based role
			local attrValue = player:GetAttribute(role.AttributeName)
			if attrValue == role.AttributeValue then
				matches = true
			end
		end

		if matches then
			return {
				Name = role.Name,
				GradientColor = role.GradientColor,
				TextColor = role.TextColor,
				Icons = role.Icons or {},
				UsernameColor = role.UsernameColor,
				UsernameOutlineColor = role.UsernameOutlineColor,
			}
		end
	end

	-- Return default role
	return self.DefaultRole
end

return NameTagConfig