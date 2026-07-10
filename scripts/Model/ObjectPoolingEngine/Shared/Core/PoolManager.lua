--!strict
--[[
    PoolManager.lua
    Advanced Object Pooling Engine - Pool Manager Singleton
    
    Central orchestrator for managing all object pools.
    Implements Singleton pattern with lazy initialization.
    
    Requirements: 1.1-1.8
]]

local Types = require(script.Parent.Parent.Types)
local Pool = require(script.Parent.Pool)
local PoolRegistry = require(script.Parent.PoolRegistry)
local PoolAnalytics = require(script.Parent.Parent.Analytics.PoolAnalytics)
local PoolConfigModule = require(script.Parent.Parent.Config.PoolConfig)
local DefaultConfigs = require(script.Parent.Parent.Config.DefaultConfigs)
local Constants = require(script.Parent.Parent.Utils.Constants)

type PoolConfig = Types.PoolConfig
type PoolStats = Types.PoolStats
type GlobalStats = Types.GlobalStats
type PoolImpl = Pool.PoolImpl
type PoolAnalyticsImpl = PoolAnalytics.PoolAnalyticsImpl

-- ============================================================================
-- Constants (from centralized Constants module)
-- ============================================================================

local DEBUG_MODE = false
local REQUEST_CACHE_SIZE = Constants.PoolManager.REQUEST_CACHE_SIZE

-- ============================================================================
-- Singleton Instance
-- ============================================================================

local instance: PoolManagerImpl? = nil

-- ============================================================================
-- PoolManager Class
-- ============================================================================

local PoolManager = {}
PoolManager.__index = PoolManager

export type PoolManagerImpl = {
	-- Internal state
	_pools: {[string]: PoolImpl},
	_defaultConfig: PoolConfig,
	_analytics: PoolAnalyticsImpl,
	_isInitialized: boolean,
	_requestCache: {[string]: PoolImpl},
	_requestCacheOrder: {string},

	-- Public API (Requirement 1.1-1.8)
	CreatePool: (self: PoolManagerImpl, categoryName: string, config: {[string]: any}?, template: (Instance | number)?) -> PoolImpl,
	GetPool: (self: PoolManagerImpl, categoryName: string) -> PoolImpl?,
	Get: (self: PoolManagerImpl, categoryName: string, template: (Instance | number)?) -> Instance?,
	Return: (self: PoolManagerImpl, object: Instance) -> boolean,
	Shutdown: (self: PoolManagerImpl) -> (),
	GetGlobalStats: (self: PoolManagerImpl) -> GlobalStats,

	-- Additional API
	SetDefaultConfig: (self: PoolManagerImpl, config: {[string]: any}) -> (),
	GetPoolNames: (self: PoolManagerImpl) -> {string},
	HasPool: (self: PoolManagerImpl, categoryName: string) -> boolean,
	DestroyPool: (self: PoolManagerImpl, categoryName: string) -> boolean,
	GetAnalytics: (self: PoolManagerImpl) -> PoolAnalyticsImpl,
}

--[[
    Debug logging helper
]]
local function debugLog(message: string, ...)
	if DEBUG_MODE then
		print(string.format("[PoolManager] " .. message, ...))
	end
end

--[[
    Create a new PoolManager instance (private constructor).
    Called only by GetInstance() for lazy initialization.
    
    Requirement 1.1: Singleton pattern with lazy initialization
]]
local function createInstance(): PoolManagerImpl
	local self = setmetatable({}, PoolManager) :: any

	-- Initialize internal state
	self._pools = {}
	self._defaultConfig = PoolConfigModule.MergeWithDefaults({})
	self._analytics = PoolAnalytics.new()
	self._isInitialized = true

	-- Request cache for fast routing (Requirement 1.8)
	self._requestCache = {}
	self._requestCacheOrder = {}

	debugLog("PoolManager initialized")

	return self
end

--[[
    Get the singleton instance of PoolManager.
    Creates the instance on first call (lazy initialization).
    
    @return PoolManagerImpl - The singleton instance
    
    Requirement 1.1: Singleton pattern with lazy initialization
]]
function PoolManager.GetInstance(): PoolManagerImpl
	if not instance then
		instance = createInstance()
	end
	return instance
end

--[[
    Reset the singleton instance (for testing purposes).
    This destroys the current instance and allows a fresh one to be created.
]]
function PoolManager._ResetInstance(): ()
	if instance then
		instance:Shutdown()
		instance = nil
	end
end

--[[
    Create a new Pool for a category of objects.
    
    @param categoryName - Unique name for this pool category
    @param config - Optional configuration (merged with defaults)
    @param template - Optional template Instance or asset ID
    @return PoolImpl - The created Pool instance
    
    Requirement 1.2: Create a new Pool instance and register it
]]
function PoolManager.CreatePool(self: PoolManagerImpl, categoryName: string, config: {[string]: any}?, template: (Instance | number)?): PoolImpl
	-- Check if pool already exists
	if self._pools[categoryName] then
		warn(string.format("[PoolManager] Pool '%s' already exists, returning existing pool", categoryName))
		return self._pools[categoryName]
	end

	-- Merge config with defaults
	local mergedConfig = config
	if not mergedConfig then
		mergedConfig = {}
	end

	-- Create the pool
	local pool = Pool.new(categoryName, mergedConfig, template)

	-- Register with analytics
	self._analytics:RegisterPool(categoryName)

	-- Store the pool
	self._pools[categoryName] = pool

	-- Add to request cache
	self:_addToRequestCache(categoryName, pool)

	debugLog("Created pool '%s'", categoryName)

	return pool
end

--[[
    Get an existing Pool by category name.
    
    @param categoryName - Name of the pool to retrieve
    @return PoolImpl? - The Pool or nil if not found
    
    Requirement 1.3: Return the Pool instance or nil if not found
]]
function PoolManager.GetPool(self: PoolManagerImpl, categoryName: string): PoolImpl?
	-- Check request cache first (Requirement 1.8)
	local cachedPool = self._requestCache[categoryName]
	if cachedPool then
		return cachedPool
	end

	-- Look up in pools map
	local pool = self._pools[categoryName]
	if pool then
		-- Add to cache for future lookups
		self:_addToRequestCache(categoryName, pool)
	end

	return pool
end

--[[
    Get an object from a pool by category name.
    Routes the request to the correct Pool.
    
    @param categoryName - Name of the pool to get from
    @param template - Optional template for creating new objects
    @return Instance? - The acquired Instance or nil if failed
    
    Requirement 1.4: Route the request to the correct Pool and return an Instance
    Hit detection uses pool's internal tracking.
]]
function PoolManager.Get(self: PoolManagerImpl, categoryName: string, template: (Instance | number)?): Instance?
	local pool = self:GetPool(categoryName)

	if not pool then
		warn(string.format("[PoolManager] Pool '%s' not found", categoryName))
		return nil
	end

	-- Set template if provided and pool doesn't have one
	if template and not pool._template and not pool._templateId then
		pool:SetTemplate(template)
	end

	-- Track available count before Get to determine if it was a hit
	local availableBefore = pool:GetAvailableCount()

	-- Get object from pool
	local obj = pool:Get()

	-- Record analytics with correct hit detection
	-- A hit means we got an object from _available (availableBefore > 0 and obj exists)
	if obj then
		local wasHit = availableBefore > 0
		self._analytics:RecordGet(categoryName, wasHit)
	end

	return obj
end

--[[
    Return an object to its pool.
    Uses PoolRegistry for fast lookup of the correct pool.
    
    @param object - The Instance to return
    @return boolean - True if returned successfully
    
    Requirement 1.5: Find the correct Pool via Registry and return the object
]]
function PoolManager.Return(self: PoolManagerImpl, object: Instance): boolean
	-- Use PoolRegistry for O(1) lookup
	local pool = PoolRegistry.GetPool(object) :: PoolImpl?

	if not pool then
		warn("[PoolManager] Unknown object returned - not registered in any pool")
		return false
	end

	-- Get wrapper for lifetime calculation
	local wrapper = PoolRegistry.GetWrapper(object)
	local lifetime = 0
	if wrapper then
		lifetime = os.clock() - (wrapper :: any).lastUsed
	end

	-- Return to pool
	local success = pool:Return(object)

	-- Record analytics
	if success then
		self._analytics:RecordReturn(pool.name, lifetime)
	end

	return success
end

--[[
    Shutdown the PoolManager and destroy all pools.
    Cleans up all resources.
    
    Requirement 1.6: Destroy all pools and cleanup resources
]]
function PoolManager.Shutdown(self: PoolManagerImpl): ()
	debugLog("Shutting down PoolManager")

	-- Destroy all pools
	for categoryName, pool in pairs(self._pools) do
		debugLog("Destroying pool '%s'", categoryName)
		self._analytics:UnregisterPool(categoryName)
		pool:Destroy()
	end

	-- Clear pools map
	table.clear(self._pools)

	-- Clear request cache
	table.clear(self._requestCache)
	table.clear(self._requestCacheOrder)

	-- Clear registry
	PoolRegistry.Clear()

	-- Destroy analytics
	self._analytics:Destroy()

	self._isInitialized = false

	debugLog("PoolManager shutdown complete")
end

--[[
    Get aggregated statistics from all pools.
    
    @return GlobalStats - Aggregated statistics
    
    Requirement 1.7: Aggregate and return statistics from all pools
]]
function PoolManager.GetGlobalStats(self: PoolManagerImpl): GlobalStats
	-- Flush pending analytics updates
	self._analytics:FlushPending()

	local totalObjects = 0
	local totalGets = 0
	local totalReturns = 0
	local totalHits = 0
	local poolStats: {[string]: PoolStats} = {}

	-- Aggregate from all pools
	for categoryName, pool in pairs(self._pools) do
		local stats = pool:GetStats()
		poolStats[categoryName] = stats

		totalObjects = totalObjects + stats.availableCount + stats.inUseCount

		-- Accumulate hits for overall hit rate calculation
		if stats.hitRate > 0 then
			totalHits = totalHits + (stats.hitRate * pool._totalGets)
		end
	end

	-- Get global metrics from analytics
	local analyticsStats = self._analytics:GetGlobalStats()
	totalGets = analyticsStats.totalGets
	totalReturns = analyticsStats.totalReturns

	-- Calculate overall hit rate
	local overallHitRate = 0
	if totalGets > 0 then
		overallHitRate = totalHits / totalGets
	end

	local poolCount = 0
	for _ in pairs(self._pools) do
		poolCount = poolCount + 1
	end

	return {
		totalPools = poolCount,
		totalObjects = totalObjects,
		totalGets = totalGets,
		totalReturns = totalReturns,
		overallHitRate = overallHitRate,
		pools = poolStats,
	}
end

--[[
    Set the default configuration for new pools.
    
    @param config - Configuration to use as default
]]
function PoolManager.SetDefaultConfig(self: PoolManagerImpl, config: {[string]: any}): ()
	self._defaultConfig = PoolConfigModule.MergeWithDefaults(config)
end

--[[
    Get list of all pool names.
    
    @return {string} - Array of pool names
]]
function PoolManager.GetPoolNames(self: PoolManagerImpl): {string}
	local names = {}
	for name in pairs(self._pools) do
		table.insert(names, name)
	end
	return names
end

--[[
    Check if a pool exists.
    
    @param categoryName - Name of the pool to check
    @return boolean - True if pool exists
]]
function PoolManager.HasPool(self: PoolManagerImpl, categoryName: string): boolean
	return self._pools[categoryName] ~= nil
end

--[[
    Destroy a specific pool.
    
    @param categoryName - Name of the pool to destroy
    @return boolean - True if pool was destroyed
]]
function PoolManager.DestroyPool(self: PoolManagerImpl, categoryName: string): boolean
	local pool = self._pools[categoryName]
	if not pool then
		return false
	end

	-- Unregister from analytics
	self._analytics:UnregisterPool(categoryName)

	-- Destroy the pool
	pool:Destroy()

	-- Remove from pools map
	self._pools[categoryName] = nil

	-- Remove from request cache
	self._requestCache[categoryName] = nil
	for i, name in ipairs(self._requestCacheOrder) do
		if name == categoryName then
			table.remove(self._requestCacheOrder, i)
			break
		end
	end

	debugLog("Destroyed pool '%s'", categoryName)

	return true
end

--[[
    Get the analytics instance.
    
    @return PoolAnalyticsImpl - The analytics instance
]]
function PoolManager.GetAnalytics(self: PoolManagerImpl): PoolAnalyticsImpl
	return self._analytics
end

--[[
    Add a pool to the request cache (LRU).
    Maintains a fixed-size cache for fast routing.
    
    Requirement 1.8: Cache last N requests for fast routing optimization
]]
function PoolManager._addToRequestCache(self: PoolManagerImpl, categoryName: string, pool: PoolImpl): ()
	-- Check if already in cache
	if self._requestCache[categoryName] then
		-- Move to end of order (most recently used)
		for i, name in ipairs(self._requestCacheOrder) do
			if name == categoryName then
				table.remove(self._requestCacheOrder, i)
				break
			end
		end
		table.insert(self._requestCacheOrder, categoryName)
		return
	end

	-- Add to cache
	self._requestCache[categoryName] = pool
	table.insert(self._requestCacheOrder, categoryName)

	-- Evict oldest if cache is full
	if #self._requestCacheOrder > REQUEST_CACHE_SIZE then
		local oldestName = table.remove(self._requestCacheOrder, 1)
		if oldestName then
			self._requestCache[oldestName] = nil
		end
	end
end

return PoolManager
