--!strict
--[[
    EasyPool.lua
    Advanced Object Pooling Engine - Simplified API
    
    ULTRA-SIMPLE API for quick integration.
    Just 3 functions: Get, Return, Preload
    
    Usage:
        local EasyPool = require(path.to.EasyPool)
        
        -- Get an object (auto-creates pool if needed)
        local bullet = EasyPool.Get("Bullets", bulletTemplate)
        
        -- Return when done
        EasyPool.Return(bullet)
        
        -- Optional: Preload for better performance
        EasyPool.Preload("Bullets", 100, bulletTemplate)
]]

local PoolManager = require(script.Parent.Core.PoolManager)
local DefaultConfigs = require(script.Parent.Config.DefaultConfigs)

-- ============================================================================
-- EasyPool Module
-- ============================================================================

local EasyPool = {}

-- Internal state
local _initialized = false
local _manager: typeof(PoolManager.GetInstance())? = nil
local _templates: {[string]: Instance | number} = {}

-- ============================================================================
-- Private Helpers
-- ============================================================================

local function ensureInitialized()
	if not _initialized then
		_manager = PoolManager.GetInstance()
		_initialized = true
	end
	return _manager :: typeof(PoolManager.GetInstance())
end

local function getOrCreatePool(categoryName: string, template: (Instance | number)?): any
	local manager = ensureInitialized()

	-- Check if pool exists
	local pool = manager:GetPool(categoryName)
	if pool then
		return pool
	end

	-- Store template for future use
	if template then
		_templates[categoryName] = template
	end

	-- Auto-detect best config based on category name
	local config = EasyPool._detectConfig(categoryName)

	-- Create pool with detected config
	return manager:CreatePool(categoryName, config, template or _templates[categoryName])
end

--[[
    Auto-detect best configuration based on pool name.
    Looks for keywords in the name to choose optimal settings.
]]
function EasyPool._detectConfig(categoryName: string): {[string]: any}
	local lowerName = string.lower(categoryName)

	-- Bullet/Projectile patterns
	if string.find(lowerName, "bullet") or string.find(lowerName, "projectile") 
		or string.find(lowerName, "shot") or string.find(lowerName, "ammo") then
		return DefaultConfigs.GetPreset("Bullets") or {}
	end

	-- Particle/Effect patterns
	if string.find(lowerName, "particle") or string.find(lowerName, "effect")
		or string.find(lowerName, "spark") or string.find(lowerName, "explosion")
		or string.find(lowerName, "smoke") or string.find(lowerName, "fire") then
		return DefaultConfigs.GetPreset("Particles") or {}
	end

	-- UI patterns
	if string.find(lowerName, "ui") or string.find(lowerName, "gui")
		or string.find(lowerName, "damage") or string.find(lowerName, "number")
		or string.find(lowerName, "notification") or string.find(lowerName, "popup") then
		return DefaultConfigs.GetPreset("UIElements") or {}
	end

	-- NPC/Enemy patterns
	if string.find(lowerName, "npc") or string.find(lowerName, "enemy")
		or string.find(lowerName, "mob") or string.find(lowerName, "monster")
		or string.find(lowerName, "zombie") then
		return DefaultConfigs.GetPreset("NPCs") or {}
	end

	-- Fish/Fishing patterns (visual pop effects, short-lived)
	if string.find(lowerName, "fish") then
		return {
			initialSize = 5,
			maxSize = 50,
			warmUpType = "lazy",
			cleanupType = "threshold",
			growthType = "exponential",
			evictionType = "lru",
			cleanupInterval = 60,
			enableValidation = false,
		}
	end

	-- Pickup/Collectible patterns
	if string.find(lowerName, "coin") or string.find(lowerName, "pickup")
		or string.find(lowerName, "loot") or string.find(lowerName, "collectible")
		or string.find(lowerName, "gem") or string.find(lowerName, "orb") then
		return DefaultConfigs.GetPreset("Pickups") or {}
	end

	-- Sound patterns
	if string.find(lowerName, "sound") or string.find(lowerName, "audio")
		or string.find(lowerName, "sfx") then
		return DefaultConfigs.GetPreset("Sounds") or {}
	end

	-- Default: balanced config
	return DefaultConfigs.GetPreset("Balanced") or {
		initialSize = 20,
		maxSize = 200,
		warmUpType = "progressive",
		growthType = "exponential",
		evictionType = "lru",
		cleanupType = "threshold",
		cleanupInterval = 60,
	}
end

-- ============================================================================
-- Public API (Just 3 main functions!)
-- ============================================================================

--[[
    Get an object from a pool.
    Auto-creates the pool if it doesn't exist.
    
    @param categoryName - Name of the pool (e.g., "Bullets", "Particles")
    @param template - Optional template Instance (only needed on first call)
    @return Instance? - The pooled object or nil if failed
    
    Example:
        local bullet = EasyPool.Get("Bullets", bulletTemplate)
        bullet.CFrame = gunBarrel.CFrame
        bullet.Parent = workspace
    
    Uses pcall protection for pool operations.
]]
function EasyPool.Get(categoryName: string, template: (Instance | number)?): Instance?
	local success, result = pcall(function()
		local pool = getOrCreatePool(categoryName, template)
		return pool:Get()
	end)

	if not success then
		warn(string.format("[EasyPool] Get failed for '%s': %s", categoryName, tostring(result)))
		return nil
	end

	return result
end

--[[
    Return an object to its pool.
    
    @param object - The Instance to return
    @return boolean - True if returned successfully
    
    Example:
        EasyPool.Return(bullet)
    
    Includes nil check and pcall protection.
]]
function EasyPool.Return(object: Instance): boolean
	if object == nil then
		warn("[EasyPool] Cannot return nil object")
		return false
	end

	local success, result = pcall(function()
		local manager = ensureInitialized()
		return manager:Return(object)
	end)

	if not success then
		warn(string.format("[EasyPool] Return failed: %s", tostring(result)))
		return false
	end

	return result or false
end

--[[
    Preload objects into a pool for better performance.
    Call this during loading screens or game start.
    
    @param categoryName - Name of the pool
    @param count - Number of objects to preload
    @param template - Template Instance (required if pool doesn't exist)
    
    Example:
        EasyPool.Preload("Bullets", 100, bulletTemplate)
        EasyPool.Preload("Particles", 50, particleTemplate)
]]
function EasyPool.Preload(categoryName: string, count: number, template: (Instance | number)?): ()
	local pool = getOrCreatePool(categoryName, template)
	pool:WarmUp(count)
end

-- ============================================================================
-- Additional Convenience Functions
-- ============================================================================

--[[
    Get multiple objects at once.
    
    @param categoryName - Name of the pool
    @param count - Number of objects to get
    @param template - Optional template
    @return {Instance} - Array of pooled objects
    
    Example:
        local bullets = EasyPool.GetMany("Bullets", 10)
]]
function EasyPool.GetMany(categoryName: string, count: number, template: (Instance | number)?): {Instance}
	local objects = {}
	for i = 1, count do
		local obj = EasyPool.Get(categoryName, template)
		if obj then
			table.insert(objects, obj)
		end
	end
	return objects
end

--[[
    Return multiple objects at once.
    
    @param objects - Array of Instances to return
    
    Example:
        EasyPool.ReturnMany(bullets)
]]
function EasyPool.ReturnMany(objects: {Instance}): ()
	for _, obj in ipairs(objects) do
		EasyPool.Return(obj)
	end
end

--[[
    Get an object with auto-return after delay.
    Perfect for temporary effects.
    
    @param categoryName - Name of the pool
    @param autoReturnDelay - Seconds until auto-return
    @param template - Optional template
    @return Instance? - The pooled object
    
    Example:
        local explosion = EasyPool.GetTemporary("Explosions", 2)
        -- Automatically returns after 2 seconds
]]
function EasyPool.GetTemporary(categoryName: string, autoReturnDelay: number, template: (Instance | number)?): Instance?
	local pool = getOrCreatePool(categoryName, template)

	-- Temporarily set auto-return delay
	local originalDelay = pool.config.autoReturnDelay
	pool.config.autoReturnDelay = autoReturnDelay

	local obj = pool:Get()

	-- Restore original delay
	pool.config.autoReturnDelay = originalDelay

	return obj
end

--[[
    Get pool statistics.
    
    @param categoryName - Name of the pool (optional, nil for global stats)
    @return table - Statistics
    
    Example:
        local stats = EasyPool.GetStats("Bullets")
        print("Hit rate:", stats.hitRate)
]]
function EasyPool.GetStats(categoryName: string?): {[string]: any}
	local manager = ensureInitialized()

	if categoryName then
		local pool = manager:GetPool(categoryName)
		if pool then
			return pool:GetStats()
		end
		return {}
	end

	return manager:GetGlobalStats()
end

--[[
    Clear all objects from a pool.
    
    @param categoryName - Name of the pool to clear
    
    Example:
        EasyPool.Clear("Bullets")
]]
function EasyPool.Clear(categoryName: string): ()
	local manager = ensureInitialized()
	local pool = manager:GetPool(categoryName)
	if pool then
		pool:Clear()
	end
end

--[[
    Shutdown and cleanup all pools.
    Call this when the game ends or player leaves.
    
    Example:
        game:BindToClose(function()
            EasyPool.Shutdown()
        end)
]]
function EasyPool.Shutdown(): ()
	if _initialized and _manager then
		_manager:Shutdown()
		_initialized = false
		_manager = nil
		table.clear(_templates)
	end
end

--[[
    Check if a pool exists.
    
    @param categoryName - Name of the pool
    @return boolean - True if pool exists
]]
function EasyPool.HasPool(categoryName: string): boolean
	local manager = ensureInitialized()
	return manager:HasPool(categoryName)
end

--[[
    Get the underlying PoolManager for advanced usage.
    
    @return PoolManager - The PoolManager singleton
]]
function EasyPool.GetManager(): typeof(PoolManager.GetInstance())
	return ensureInitialized()
end

return EasyPool
