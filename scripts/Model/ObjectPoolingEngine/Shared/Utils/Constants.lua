--!strict
--[[
    Constants.lua
    Advanced Object Pooling Engine - Centralized Constants
    
    All magic numbers and configuration defaults in one place.
]]

local Constants = {}

-- ============================================================================
-- Pool Configuration Defaults
-- ============================================================================

Constants.Pool = {
	-- Default buffer capacity when maxSize is not specified
	DEFAULT_BUFFER_CAPACITY = 1000,

	-- Default initial pool size
	DEFAULT_INITIAL_SIZE = 10,

	-- Default cleanup interval in seconds
	DEFAULT_CLEANUP_INTERVAL = 60,
}

-- ============================================================================
-- PoolManager Configuration
-- ============================================================================

Constants.PoolManager = {
	-- Size of the LRU request cache for fast pool routing
	REQUEST_CACHE_SIZE = 10,
}

-- ============================================================================
-- WarmUp Strategy Configuration
-- ============================================================================

Constants.WarmUp = {
	-- Number of objects to create per frame in progressive warm-up
	PROGRESSIVE_BATCH_SIZE = 10,

	-- Estimated time per object creation (seconds) for time estimation
	ESTIMATED_TIME_PER_OBJECT = 0.001,
}

-- ============================================================================
-- Growth Strategy Configuration
-- ============================================================================

Constants.Growth = {
	-- Number of objects to add per growth step in linear strategy
	LINEAR_INCREMENT = 10,

	-- Multiplier for exponential growth strategy
	EXPONENTIAL_MULTIPLIER = 2,
}

-- ============================================================================
-- Analytics Configuration
-- ============================================================================

Constants.Analytics = {
	-- Maximum number of performance samples to keep
	DEFAULT_SAMPLE_CAPACITY = 60,

	-- Minimum seconds between performance samples
	DEFAULT_SAMPLE_INTERVAL = 1,

	-- Number of pending updates before auto-flush
	DEFAULT_BATCH_THRESHOLD = 50,

	-- Number of lifetime samples to keep for averaging
	LIFETIME_SAMPLE_CAPACITY = 100,
}

-- ============================================================================
-- Metrics Configuration
-- ============================================================================

Constants.Metrics = {
	-- Default batch size for metrics collector
	DEFAULT_BATCH_SIZE = 10,

	-- Capacity for lifetime circular buffer
	LIFETIME_CAPACITY = 100,
}

-- ============================================================================
-- Timer Configuration
-- ============================================================================

Constants.Timer = {
	-- Assumed FPS for time calculations
	ASSUMED_FPS = 60,

	-- Frame time at assumed FPS
	FRAME_TIME = 1 / 60,
}

-- ============================================================================
-- Validation Configuration
-- ============================================================================

Constants.Validation = {
	-- Default validation rules
	CHECK_PARENT = true,
	CHECK_DESTROYED = true,
}

-- ============================================================================
-- Reset Configuration
-- ============================================================================

Constants.Reset = {
	-- Default reset options
	RESET_POSITION = true,
	RESET_VELOCITY = true,
	CLEAR_CONNECTIONS = true,
	CLEAR_TWEENS = true,
	CLEAR_ATTRIBUTES = true,
}

return Constants
