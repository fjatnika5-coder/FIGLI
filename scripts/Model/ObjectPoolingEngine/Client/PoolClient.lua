--!strict
--[[
    PoolClient.lua
    Advanced Object Pooling Engine - Client Entry Point
    
    Client-side initialization and management of object pools.
    Optimized for visual objects (bullets, particles, effects, UI elements)
    
    Requirements: 13.2, 13.4
]]

local PoolManager = require(script.Parent.Parent.Shared.Core.PoolManager)
local DefaultConfigs = require(script.Parent.Parent.Shared.Config.DefaultConfigs)
local PoolConfigModule = require(script.Parent.Parent.Shared.Config.PoolConfig)

-- ============================================================================
-- Types
-- ============================================================================

export type PoolClientImpl = {
	_manager: typeof(PoolManager.GetInstance()),
	_isInitialized: boolean,
	_defaultClientConfig: {[string]: any},

	-- Public API
	Initialize: (self: PoolClientImpl, config: {[string]: any}?) -> (),
	CreatePool: (self: PoolClientImpl, categoryName: string, config: {[string]: any}?, template: (Instance | number)?) -> any,
	GetPool: (self: PoolClientImpl, categoryName: string) -> any?,
	Get: (self: PoolClientImpl, categoryName: string, template: (Instance | number)?) -> Instance?,
	Return: (self: PoolClientImpl, object: Instance) -> boolean,
	Shutdown: (self: PoolClientImpl) -> (),
	GetManager: (self: PoolClientImpl) -> typeof(PoolManager.GetInstance()),
	IsInitialized: (self: PoolClientImpl) -> boolean,
}

-- ============================================================================
-- Constants
-- ============================================================================

local DEBUG_MODE = false

-- ============================================================================
-- Default Client Configuration
-- Optimized for visual objects (Requirement 13.4)
-- ============================================================================

local DEFAULT_CLIENT_CONFIG = {
	-- Size: Larger pools for visual objects (many bullets, particles)
	initialSize = 50,
	maxSize = 500,

	-- Strategies: Progressive warmup to avoid frame drops, aggressive cleanup
	warmUpType = "progressive",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "fifo",

	-- Timing: Short TTL for visual objects, auto-return for safety
	objectTTL = 30,
	autoReturnDelay = 5,
	cleanupInterval = 30,

	-- Flags: Skip validation for performance, no analytics overhead
	enableAnalytics = false,
	enableValidation = false,
	preloadAsync = true,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- PoolClient Class
-- ============================================================================

local PoolClient = {}
PoolClient.__index = PoolClient

--[[
    Debug logging helper
]]
local function debugLog(message: string, ...)
	if DEBUG_MODE then
		print(string.format("[PoolClient] " .. message, ...))
	end
end

--[[
    Create a new PoolClient instance.
    
    @return PoolClientImpl - The PoolClient instance
]]
function PoolClient.new(): PoolClientImpl
	local self = setmetatable({}, PoolClient) :: any

	self._manager = PoolManager.GetInstance()
	self._isInitialized = false
	self._defaultClientConfig = DEFAULT_CLIENT_CONFIG

	return self
end

--[[
    Initialize the client-side pooling system.
    
    @param config - Optional configuration overrides
    
    Requirement 13.2: Client-side initialization optimized for visual objects
]]
function PoolClient.Initialize(self: PoolClientImpl, config: {[string]: any}?): ()
	if self._isInitialized then
		warn("[PoolClient] Already initialized")
		return
	end

	debugLog("Initializing PoolClient")

	-- Merge provided config with client defaults
	if config then
		for key, value in pairs(config) do
			self._defaultClientConfig[key] = value
		end
	end

	-- Set default config on manager
	self._manager:SetDefaultConfig(self._defaultClientConfig)

	self._isInitialized = true

	debugLog("PoolClient initialized successfully")
end

--[[
    Create a new pool optimized for client-side visual objects.
    
    @param categoryName - Unique name for this pool category
    @param config - Optional configuration (merged with client defaults)
    @param template - Optional template Instance or asset ID
    @return Pool - The created Pool instance
    
    Requirement 13.4: Optimize for visual objects (bullets, particles, effects)
]]
function PoolClient.CreatePool(self: PoolClientImpl, categoryName: string, config: {[string]: any}?, template: (Instance | number)?): any
	if not self._isInitialized then
		self:Initialize()
	end

	-- Merge with client defaults
	local mergedConfig = {}
	for key, value in pairs(self._defaultClientConfig) do
		mergedConfig[key] = value
	end

	if config then
		for key, value in pairs(config) do
			mergedConfig[key] = value
		end
	end

	debugLog("Creating client pool '%s'", categoryName)

	return self._manager:CreatePool(categoryName, mergedConfig, template)
end

--[[
    Get an existing pool by name.
    
    @param categoryName - Name of the pool to retrieve
    @return Pool? - The Pool or nil if not found
]]
function PoolClient.GetPool(self: PoolClientImpl, categoryName: string): any?
	return self._manager:GetPool(categoryName)
end

--[[
    Get an object from a pool.
    
    @param categoryName - Name of the pool to get from
    @param template - Optional template for creating new objects
    @return Instance? - The acquired Instance or nil if failed
]]
function PoolClient.Get(self: PoolClientImpl, categoryName: string, template: (Instance | number)?): Instance?
	return self._manager:Get(categoryName, template)
end

--[[
    Return an object to its pool.
    
    @param object - The Instance to return
    @return boolean - True if returned successfully
]]
function PoolClient.Return(self: PoolClientImpl, object: Instance): boolean
	return self._manager:Return(object)
end

--[[
    Shutdown the client-side pooling system.
]]
function PoolClient.Shutdown(self: PoolClientImpl): ()
	if not self._isInitialized then
		return
	end

	debugLog("Shutting down PoolClient")

	self._manager:Shutdown()
	self._isInitialized = false

	debugLog("PoolClient shutdown complete")
end

--[[
    Get the underlying PoolManager instance.
    
    @return PoolManager - The PoolManager singleton
]]
function PoolClient.GetManager(self: PoolClientImpl): typeof(PoolManager.GetInstance())
	return self._manager
end

--[[
    Check if the client is initialized.
    
    @return boolean - True if initialized
]]
function PoolClient.IsInitialized(self: PoolClientImpl): boolean
	return self._isInitialized
end

-- ============================================================================
-- Preset Pool Creation Helpers
-- ============================================================================

--[[
    Create a pool optimized for bullets/projectiles.
    Uses DefaultConfigs.Bullets as base configuration.
    
    @param categoryName - Name for the bullet pool
    @param template - Template for bullet instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolClient.CreateBulletPool(self: PoolClientImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("Bullets") or {}

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

--[[
    Create a pool optimized for particles.
    Uses DefaultConfigs.Particles as base configuration.
    
    @param categoryName - Name for the particle pool
    @param template - Template for particle instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolClient.CreateParticlePool(self: PoolClientImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("Particles") or {}

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

--[[
    Create a pool optimized for UI elements.
    Uses DefaultConfigs.UIElements as base configuration.
    
    @param categoryName - Name for the UI pool
    @param template - Template for UI instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolClient.CreateUIPool(self: PoolClientImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("UIElements") or {}

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

--[[
    Create a pool optimized for sound effects.
    Uses DefaultConfigs.Sounds as base configuration.
    
    @param categoryName - Name for the sound pool
    @param template - Template for sound instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolClient.CreateSoundPool(self: PoolClientImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("Sounds") or {}

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

--[[
    Create a pool optimized for visual effects.
    Uses high-performance settings for effects.
    
    @param categoryName - Name for the effects pool
    @param template - Template for effect instances
    @param overrides - Optional config overrides
    @return Pool - The created Pool
]]
function PoolClient.CreateEffectPool(self: PoolClientImpl, categoryName: string, template: (Instance | number)?, overrides: {[string]: any}?): any
	local config = DefaultConfigs.GetPreset("HighPerformance") or {}

	-- Override with effect-specific settings
	config.objectTTL = 10
	config.autoReturnDelay = 3

	if overrides then
		for key, value in pairs(overrides) do
			config[key] = value
		end
	end

	return self:CreatePool(categoryName, config, template)
end

return PoolClient
