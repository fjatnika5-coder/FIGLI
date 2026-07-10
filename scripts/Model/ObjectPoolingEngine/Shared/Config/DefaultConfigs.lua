--!strict
--[[
    DefaultConfigs.lua
    Advanced Object Pooling Engine - Preset Configurations
    
    This module provides sensible default configurations for common use cases.
    Requirements: 12.6
]]

local Types = require(script.Parent.Parent.Types)

type PoolConfig = Types.PoolConfig

local DefaultConfigs = {}

-- ============================================================================
-- Bullet Pool Configuration
-- Optimized for high-frequency, short-lived objects like projectiles
-- ============================================================================

DefaultConfigs.Bullets = {
	-- Size: Start with many, allow growth
	initialSize = 50,
	maxSize = 500,

	-- Strategies: Fast warmup, aggressive cleanup
	warmUpType = "progressive",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "fifo",

	-- Timing: Short TTL, auto-return for safety
	objectTTL = 30,
	autoReturnDelay = 5,
	cleanupInterval = 30,

	-- Flags: Validation for safety, no analytics overhead
	enableAnalytics = false,
	enableValidation = true,
	preloadAsync = true,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- Particle Pool Configuration
-- Optimized for visual effects with many short-lived particles
-- ============================================================================

DefaultConfigs.Particles = {
	-- Size: Large pool for particle systems
	initialSize = 100,
	maxSize = 1000,

	-- Strategies: Lazy warmup (create on demand), aggressive cleanup
	warmUpType = "lazy",
	cleanupType = "ttl",
	growthType = "exponential",
	evictionType = "lru",

	-- Timing: Very short TTL for particles
	objectTTL = 10,
	autoReturnDelay = 3,
	cleanupInterval = 15,

	-- Flags: Skip validation for performance
	enableAnalytics = false,
	enableValidation = false,
	preloadAsync = false,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- NPC Pool Configuration
-- Optimized for game entities with longer lifecycles
-- ============================================================================

DefaultConfigs.NPCs = {
	-- Size: Moderate pool, limited growth
	initialSize = 20,
	maxSize = 100,

	-- Strategies: Immediate warmup for responsiveness
	warmUpType = "immediate",
	cleanupType = "lru",
	growthType = "linear",
	evictionType = "lfu",

	-- Timing: Longer TTL, no auto-return (manual control)
	objectTTL = 300,
	autoReturnDelay = nil,
	cleanupInterval = 120,

	-- Flags: Full validation, analytics for debugging
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
-- UI Element Pool Configuration
-- Optimized for UI components that are frequently shown/hidden
-- ============================================================================

DefaultConfigs.UIElements = {
	-- Size: Small pool, fixed size
	initialSize = 10,
	maxSize = 50,

	-- Strategies: Lazy warmup, threshold cleanup
	warmUpType = "lazy",
	cleanupType = "threshold",
	growthType = "linear",
	evictionType = "lru",

	-- Timing: Long TTL, no auto-return
	objectTTL = nil,
	autoReturnDelay = nil,
	cleanupInterval = 300,

	-- Flags: Validation enabled
	enableAnalytics = false,
	enableValidation = true,
	preloadAsync = false,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- Sound Pool Configuration
-- Optimized for audio objects
-- ============================================================================

DefaultConfigs.Sounds = {
	-- Size: Moderate pool
	initialSize = 20,
	maxSize = 100,

	-- Strategies
	warmUpType = "progressive",
	cleanupType = "ttl",
	growthType = "linear",
	evictionType = "fifo",

	-- Timing: Auto-return after typical sound duration
	objectTTL = 60,
	autoReturnDelay = 10,
	cleanupInterval = 60,

	-- Flags
	enableAnalytics = false,
	enableValidation = true,
	preloadAsync = true,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- Minimal Pool Configuration
-- Bare minimum configuration for simple use cases
-- ============================================================================

DefaultConfigs.Minimal = {
	-- Size: Small, no limit
	initialSize = 5,
	maxSize = nil,

	-- Strategies: All defaults
	warmUpType = "lazy",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "lru",

	-- Timing: No TTL, no auto-return
	objectTTL = nil,
	autoReturnDelay = nil,
	cleanupInterval = 60,

	-- Flags: Minimal overhead
	enableAnalytics = false,
	enableValidation = false,
	preloadAsync = false,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- High Performance Pool Configuration
-- Maximum performance, minimal safety checks
-- ============================================================================

DefaultConfigs.HighPerformance = {
	-- Size: Large pre-allocated pool
	initialSize = 100,
	maxSize = 1000,

	-- Strategies: Immediate warmup, aggressive growth
	warmUpType = "immediate",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "fifo",

	-- Timing: Short cleanup interval
	objectTTL = nil,
	autoReturnDelay = nil,
	cleanupInterval = 30,

	-- Flags: Disable all overhead
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
-- Debug Pool Configuration
-- Full analytics and validation for development
-- ============================================================================

DefaultConfigs.Debug = {
	-- Size: Small for easier debugging
	initialSize = 5,
	maxSize = 20,

	-- Strategies
	warmUpType = "immediate",
	cleanupType = "threshold",
	growthType = "linear",
	evictionType = "lru",

	-- Timing
	objectTTL = 60,
	autoReturnDelay = 10,
	cleanupInterval = 30,

	-- Flags: Full debugging enabled
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
-- Pickups Pool Configuration
-- Optimized for collectibles (coins, gems, loot)
-- ============================================================================

DefaultConfigs.Pickups = {
	-- Size: Large pool for many collectibles
	initialSize = 50,
	maxSize = 500,

	-- Strategies: Progressive warmup, threshold cleanup
	warmUpType = "progressive",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "fifo",

	-- Timing: Medium TTL, auto-return for uncollected items
	objectTTL = 60,
	autoReturnDelay = 30,
	cleanupInterval = 45,

	-- Flags: Skip validation for performance
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
-- Balanced Pool Configuration
-- Good defaults for general use cases
-- ============================================================================

DefaultConfigs.Balanced = {
	-- Size: Moderate pool
	initialSize = 20,
	maxSize = 200,

	-- Strategies: Progressive warmup, balanced cleanup
	warmUpType = "progressive",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "lru",

	-- Timing: Reasonable defaults
	objectTTL = 120,
	autoReturnDelay = nil,
	cleanupInterval = 60,

	-- Flags: Validation enabled, no analytics overhead
	enableAnalytics = false,
	enableValidation = true,
	preloadAsync = true,

	-- Callbacks
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--[[
    Gets a preset configuration by name
    @param presetName - Name of the preset (e.g., "Bullets", "NPCs")
    @return PoolConfig or nil if not found
]]
function DefaultConfigs.GetPreset(presetName: string): PoolConfig?
	local preset = (DefaultConfigs :: any)[presetName]
	if preset and type(preset) == "table" and type(preset.initialSize) == "number" then
		-- Return a copy to prevent modification of the original
		return {
			initialSize = preset.initialSize,
			maxSize = preset.maxSize,
			warmUpType = preset.warmUpType,
			cleanupType = preset.cleanupType,
			growthType = preset.growthType,
			evictionType = preset.evictionType,
			objectTTL = preset.objectTTL,
			autoReturnDelay = preset.autoReturnDelay,
			cleanupInterval = preset.cleanupInterval,
			enableAnalytics = preset.enableAnalytics,
			enableValidation = preset.enableValidation,
			preloadAsync = preset.preloadAsync,
			onCreate = preset.onCreate,
			onAcquire = preset.onAcquire,
			onReturn = preset.onReturn,
			onDestroy = preset.onDestroy,
		}
	end
	return nil
end

--[[
    Gets a list of all available preset names
    @return Array of preset names
]]
function DefaultConfigs.GetPresetNames(): {string}
	return {
		"Bullets",
		"Particles",
		"NPCs",
		"UIElements",
		"Sounds",
		"Pickups",
		"Minimal",
		"Balanced",
		"HighPerformance",
		"Debug",
	}
end

return DefaultConfigs
