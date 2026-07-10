--!strict
--[[
    PoolServer.lua
    Advanced Object Pooling Engine - Server Entry Point
    
    Server-side initialization and management of object pools.
    Optimized for game logic objects (NPCs, projectiles, etc.)
    
    Requirements: 13.1, 13.5
]]

local PoolManager = require(script.Parent.Parent.Shared.Core.PoolManager)
local DefaultConfigs = require(script.Parent.Parent.Shared.Config.DefaultConfigs)
local PoolConfigModule = require(script.Parent.Parent.Shared.Config.PoolConfig)

-- ============================================================================
-- Types
-- ============================================================================

export type PoolServerImpl = {
	_manager: typeof(PoolManager.GetInstance()),
	_isInitialized: boolean,
	_defaultServerConfig: {[string]: any},

	-- Public API
	Initialize: (self: PoolServerImpl, config: {[string]: any}?) -> (),
	CreatePool: (self: PoolServerImpl, categoryName: string, config: {[string]: any}?, template: (Instance | number)?) -> any,
	GetPool: (self: PoolServerImpl, categoryName: string) -> any?,
	Get: (self: PoolServerImpl, categoryName: string, template: (Instance | number)?) -> Instance?,
	Return: (self: PoolServerImpl, object: Instance) -> boolean,
	Shutdown: (self: PoolServerImpl) -> (),
	GetManager: (self: PoolServerImpl) -> typeof(PoolManager.GetInstance()),
	IsInitialized: (self: PoolServerImpl) -> boolean,
}

-- ============================================================================
-- Constants
-- ============================================================================

local DEBUG_MODE = false

-- ============================================================================
-- Default Server Configuration
-- Optimized for game logic objects (Requirement 13.5)
-- ============================================================================

local DEFAULT_SERVER_CONFIG = {
	-- Size: Moderate defaults for server-side objects
	initialSize = 20,
	maxSize = 200,

	-- Strategies: Immediate warmup for responsiveness, LRU cleanup
	warmUpType = "immediate",
	cleanupType = "lru",
	growthType = "linear",
	evictionType = "lfu",

	-- Timing: Longer TTL for game logic objects
	objectTTL = 300,
	autoReturnDelay = nil, -- Manual control for game logic
	cleanupInterval = 120,

	-- Flags: Full validation for server-side safety
	enableAnalytics = true,
	enableValidation = true,
	preloadAsync = false,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- PoolServer Class
-- ============================================================================

local PoolServer = {}
PoolServer.__index = PoolServer

--[[
    Debug logging helper
]]
local function debugLog(message: string, ...)
	if DEBUG_MODE then
		print(string.format("[PoolServer] " .. message, ...))
	end
end

--[[
    Create a new PoolServer instance.
    
    @return PoolServerImpl - The PoolServer instance
]]
function PoolServer.new(): PoolServerImpl
	local self = setmetatable({}, PoolServer) :: any

	self._manager = PoolManager.GetInstance()
	self._isInitialized = false
	self._defaultServerConfig = DEFAULT_SERVER_CONFIG

	return self
end

--[[
    Initialize the server-side pooling system.
    
    @param config - Optional configuration overrides
    
    Requirement 13.1: Server-side initialization with appropriate defaults
]]
function PoolServer.Initialize(self: PoolServerImpl, config: {[string]: any}?): ()
	if self._isInitialized then
		warn("[PoolServer] Already initialized")
		return
	end

	debugLog("Initializing PoolServer")

	-- Merge provided config with server defaults
	if config then
		for key, value in pairs(config) do
			self._defaultServerConfig[key] = value
		end
	end

	-- Set default config on manager
	self._manager:SetDefaultConfig(self._defaultServerConfig)

	self._isInitialized = true

	debugLog("PoolServer initialized successfully")
end

--[[
    Create a new pool optimized for server-side game logic objects.
    
    @param categoryName - Unique name for this pool category
    @param config - Optional configuration (merged with server defaults)
    @param template - Optional template Instance or asset ID
    @return Pool - The created Pool instance
    
    Requirement 13.5: Optimize for game logic objects (NPCs, projectiles)
]]
function PoolServer.CreatePool(self: PoolServerImpl, categoryName: string, config: {[string]: any}?, template: (Instance | number)?): any
	if not self._isInitialized then
		self:Initialize()
	end

	-- Merge with server defaults
	local mergedConfig = {}
	for key, value in pairs(self._defaultServerConfig) do
		mergedConfig[key] = value
	end

	if config then
		for key, value in pairs(config) do
			mergedConfig[key] = value
		end
	end

	debugLog("Creating server pool '%s'", categoryName)

	return self._manager:CreatePool(categoryName, mergedConfig, template)
end

--[[
    Get an existing pool by name.
    
    @param categoryName - Name of the pool to retrieve
    @return Pool? - The Pool or nil if not found
]]
function PoolServer.GetPool(self: PoolServerImpl, categoryName: string): any?
	return self._manager:GetPool(categoryName)
end

--[[
    Get an object from a pool.
    
    @param categoryName - Name of the pool to get from
    @param template - Optional template for creating new objects
    @return Instance? - The acquired Instance or nil if failed
]]
function PoolServer.Get(self: PoolServerImpl, categoryName: string, template: (Instance | number)?): Instance?
	return self._manager:Get(categoryName, template)
end

--[[
    Return an object to its pool.
    
    @param object - The Instance to return
    @return boolean - True if returned successfully
]]
function PoolServer.Return(self: PoolServerImpl, object: Instance): boolean
	return self._manager:Return(object)
end

--[[
    Shutdown the server-side pooling system.
]]
function PoolServer.Shutdown(self: PoolServerImpl): ()
	if not self._isInitialized then
		return
	end

	debugLog("Shutting down PoolServer")

	self._manager:Shutdown()
	self._isInitialized = false

	debugLog("PoolServer shutdown complete")
end

--[[
    Get the underlying PoolManager instance.
    
    @return PoolManager - The PoolManager singleton
]]
function PoolServer.GetManager(self: PoolServerImpl): typeof(PoolManager.GetInstance())
	return self._manager
end

--[[
    Check if the server is initialized.
    
    @return boolean - True if initialized
]]
function PoolServer.IsInitialized(self: PoolServerImpl): boolean
	return self._isInitialized
end

-- ============================================================================
-- Preset Pool Creation Helpers
-- ============================================================================

--[[
    Create a pool optimized for NPCs.
    Uses DefaultConfigs.NPCs as base configuration.
    
    @param categoryName - Name for the NPC pool
    @param template - Template for NPC instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolServer.CreateNPCPool(self: PoolServerImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("NPCs") or {}

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

--[[
    Create a pool optimized for projectiles.
    Uses DefaultConfigs.Bullets as base configuration.
    
    @param categoryName - Name for the projectile pool
    @param template - Template for projectile instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolServer.CreateProjectilePool(self: PoolServerImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("Bullets") or {}

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

--[[
    Create a pool for generic game objects.
    
    @param categoryName - Name for the pool
    @param template - Template for instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolServer.CreateGameObjectPool(self: PoolServerImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	-- Use server defaults which are optimized for game logic
	return self:CreatePool(categoryName, overrides, template)
end

return PoolServer
