--!strict
--[[
    PoolConfig.lua
    Advanced Object Pooling Engine - Configuration Validation and Merging
    
    This module provides validation and merging utilities for PoolConfig.
    Requirements: 12.1-12.6
]]

local Types = require(script.Parent.Parent.Types)

type PoolConfig = Types.PoolConfig

local PoolConfig = {}

-- ============================================================================
-- Valid Strategy Values
-- ============================================================================

local VALID_WARMUP_TYPES: {[string]: boolean} = {
	immediate = true,
	progressive = true,
	lazy = true,
}

local VALID_CLEANUP_TYPES: {[string]: boolean} = {
	threshold = true,
	ttl = true,
	lru = true,
}

local VALID_GROWTH_TYPES: {[string]: boolean} = {
	fixed = true,
	linear = true,
	exponential = true,
}

local VALID_EVICTION_TYPES: {[string]: boolean} = {
	fifo = true,
	lifo = true,
	lru = true,
	lfu = true,
}

-- ============================================================================
-- Default Configuration (Requirement 12.6)
-- ============================================================================

local DEFAULT_CONFIG: PoolConfig = {
	-- Size (Requirement 12.1)
	initialSize = 10,
	maxSize = nil, -- unlimited by default

	-- Strategies (Requirement 12.2)
	warmUpType = "lazy",
	cleanupType = "threshold",
	growthType = "exponential",
	evictionType = "lru",

	-- Timing (Requirement 12.3)
	objectTTL = nil, -- no TTL by default
	autoReturnDelay = nil, -- no auto-return by default
	cleanupInterval = 60,

	-- Flags (Requirement 12.4)
	enableAnalytics = false,
	enableValidation = true,
	preloadAsync = false,

	-- Callbacks (Requirement 12.5)
	onCreate = nil,
	onAcquire = nil,
	onReturn = nil,
	onDestroy = nil,
}

-- ============================================================================
-- Validation Result Type
-- ============================================================================

export type ValidationResult = {
	isValid: boolean,
	errors: {string},
}

-- ============================================================================
-- Validation Functions
-- ============================================================================

--[[
    Validates a single config field
    @param fieldName - Name of the field being validated
    @param value - Value to validate
    @param validValues - Table of valid values (for enum types)
    @param isNumeric - Whether the field should be a non-negative number
    @param isOptional - Whether the field can be nil
    @return error message or nil if valid
]]
local function validateField(
	fieldName: string,
	value: any,
	validValues: {[string]: boolean}?,
	isNumeric: boolean?,
	isOptional: boolean?
): string?
	-- Check if nil is allowed
	if value == nil then
		if isOptional then
			return nil
		else
			return string.format("Field '%s' is required but was nil", fieldName)
		end
	end

	-- Validate enum types
	if validValues then
		if type(value) ~= "string" then
			return string.format("Field '%s' must be a string, got %s", fieldName, type(value))
		end
		if not validValues[value] then
			local validList = {}
			for k in pairs(validValues) do
				table.insert(validList, k)
			end
			return string.format(
				"Field '%s' has invalid value '%s'. Valid values: %s",
				fieldName,
				tostring(value),
				table.concat(validList, ", ")
			)
		end
	end

	-- Validate numeric types
	if isNumeric then
		if type(value) ~= "number" then
			return string.format("Field '%s' must be a number, got %s", fieldName, type(value))
		end
		if value < 0 then
			return string.format("Field '%s' must be non-negative, got %s", fieldName, tostring(value))
		end
	end

	return nil
end

--[[
    Validates a callback field
    @param fieldName - Name of the callback field
    @param value - Value to validate
    @return error message or nil if valid
]]
local function validateCallback(fieldName: string, value: any): string?
	if value == nil then
		return nil -- Callbacks are optional
	end
	if type(value) ~= "function" then
		return string.format("Field '%s' must be a function, got %s", fieldName, type(value))
	end
	return nil
end

--[[
    Validates a complete PoolConfig
    @param config - The configuration to validate
    @return ValidationResult with isValid and errors array
]]
function PoolConfig.Validate(config: any): ValidationResult
	local errors: {string} = {}

	if type(config) ~= "table" then
		return {
			isValid = false,
			errors = {"Config must be a table, got " .. type(config)},
		}
	end

	-- Validate size fields (Requirement 12.1)
	local err = validateField("initialSize", config.initialSize, nil, true, false)
	if err then table.insert(errors, err) end

	err = validateField("maxSize", config.maxSize, nil, true, true)
	if err then table.insert(errors, err) end

	-- Validate maxSize >= initialSize if both are set
	if config.initialSize and config.maxSize then
		if type(config.initialSize) == "number" and type(config.maxSize) == "number" then
			if config.maxSize < config.initialSize then
				table.insert(errors, string.format(
					"maxSize (%d) must be >= initialSize (%d)",
					config.maxSize,
					config.initialSize
					))
			end
		end
	end

	-- Validate strategy fields (Requirement 12.2)
	err = validateField("warmUpType", config.warmUpType, VALID_WARMUP_TYPES, false, false)
	if err then table.insert(errors, err) end

	err = validateField("cleanupType", config.cleanupType, VALID_CLEANUP_TYPES, false, false)
	if err then table.insert(errors, err) end

	err = validateField("growthType", config.growthType, VALID_GROWTH_TYPES, false, false)
	if err then table.insert(errors, err) end

	err = validateField("evictionType", config.evictionType, VALID_EVICTION_TYPES, false, false)
	if err then table.insert(errors, err) end

	-- Validate timing fields (Requirement 12.3)
	err = validateField("objectTTL", config.objectTTL, nil, true, true)
	if err then table.insert(errors, err) end

	err = validateField("autoReturnDelay", config.autoReturnDelay, nil, true, true)
	if err then table.insert(errors, err) end

	err = validateField("cleanupInterval", config.cleanupInterval, nil, true, false)
	if err then table.insert(errors, err) end

	-- Validate flag fields (Requirement 12.4)
	if config.enableAnalytics ~= nil and type(config.enableAnalytics) ~= "boolean" then
		table.insert(errors, string.format(
			"Field 'enableAnalytics' must be a boolean, got %s",
			type(config.enableAnalytics)
			))
	end

	if config.enableValidation ~= nil and type(config.enableValidation) ~= "boolean" then
		table.insert(errors, string.format(
			"Field 'enableValidation' must be a boolean, got %s",
			type(config.enableValidation)
			))
	end

	if config.preloadAsync ~= nil and type(config.preloadAsync) ~= "boolean" then
		table.insert(errors, string.format(
			"Field 'preloadAsync' must be a boolean, got %s",
			type(config.preloadAsync)
			))
	end

	-- Validate callback fields (Requirement 12.5)
	err = validateCallback("onCreate", config.onCreate)
	if err then table.insert(errors, err) end

	err = validateCallback("onAcquire", config.onAcquire)
	if err then table.insert(errors, err) end

	err = validateCallback("onReturn", config.onReturn)
	if err then table.insert(errors, err) end

	err = validateCallback("onDestroy", config.onDestroy)
	if err then table.insert(errors, err) end

	return {
		isValid = #errors == 0,
		errors = errors,
	}
end

--[[
    Merges a partial config with defaults
    @param partialConfig - Partial configuration (can be nil)
    @return Complete PoolConfig with defaults applied
]]
function PoolConfig.MergeWithDefaults(partialConfig: {[string]: any}?): PoolConfig
	if partialConfig == nil then
		return PoolConfig.GetDefaults()
	end

	local merged: PoolConfig = {
		-- Size
		initialSize = if partialConfig.initialSize ~= nil 
			then partialConfig.initialSize 
			else DEFAULT_CONFIG.initialSize,
		maxSize = if partialConfig.maxSize ~= nil 
			then partialConfig.maxSize 
			else DEFAULT_CONFIG.maxSize,

		-- Strategies
		warmUpType = if partialConfig.warmUpType ~= nil 
			then partialConfig.warmUpType 
			else DEFAULT_CONFIG.warmUpType,
		cleanupType = if partialConfig.cleanupType ~= nil 
			then partialConfig.cleanupType 
			else DEFAULT_CONFIG.cleanupType,
		growthType = if partialConfig.growthType ~= nil 
			then partialConfig.growthType 
			else DEFAULT_CONFIG.growthType,
		evictionType = if partialConfig.evictionType ~= nil 
			then partialConfig.evictionType 
			else DEFAULT_CONFIG.evictionType,

		-- Timing
		objectTTL = if partialConfig.objectTTL ~= nil 
			then partialConfig.objectTTL 
			else DEFAULT_CONFIG.objectTTL,
		autoReturnDelay = if partialConfig.autoReturnDelay ~= nil 
			then partialConfig.autoReturnDelay 
			else DEFAULT_CONFIG.autoReturnDelay,
		cleanupInterval = if partialConfig.cleanupInterval ~= nil 
			then partialConfig.cleanupInterval 
			else DEFAULT_CONFIG.cleanupInterval,

		-- Flags
		enableAnalytics = if partialConfig.enableAnalytics ~= nil 
			then partialConfig.enableAnalytics 
			else DEFAULT_CONFIG.enableAnalytics,
		enableValidation = if partialConfig.enableValidation ~= nil 
			then partialConfig.enableValidation 
			else DEFAULT_CONFIG.enableValidation,
		preloadAsync = if partialConfig.preloadAsync ~= nil 
			then partialConfig.preloadAsync 
			else DEFAULT_CONFIG.preloadAsync,

		-- Callbacks
		onCreate = if partialConfig.onCreate ~= nil 
			then partialConfig.onCreate 
			else DEFAULT_CONFIG.onCreate,
		onAcquire = if partialConfig.onAcquire ~= nil 
			then partialConfig.onAcquire 
			else DEFAULT_CONFIG.onAcquire,
		onReturn = if partialConfig.onReturn ~= nil 
			then partialConfig.onReturn 
			else DEFAULT_CONFIG.onReturn,
		onDestroy = if partialConfig.onDestroy ~= nil 
			then partialConfig.onDestroy 
			else DEFAULT_CONFIG.onDestroy,
	}

	return merged
end

--[[
    Returns a copy of the default configuration
    @return Default PoolConfig
]]
function PoolConfig.GetDefaults(): PoolConfig
	return {
		initialSize = DEFAULT_CONFIG.initialSize,
		maxSize = DEFAULT_CONFIG.maxSize,
		warmUpType = DEFAULT_CONFIG.warmUpType,
		cleanupType = DEFAULT_CONFIG.cleanupType,
		growthType = DEFAULT_CONFIG.growthType,
		evictionType = DEFAULT_CONFIG.evictionType,
		objectTTL = DEFAULT_CONFIG.objectTTL,
		autoReturnDelay = DEFAULT_CONFIG.autoReturnDelay,
		cleanupInterval = DEFAULT_CONFIG.cleanupInterval,
		enableAnalytics = DEFAULT_CONFIG.enableAnalytics,
		enableValidation = DEFAULT_CONFIG.enableValidation,
		preloadAsync = DEFAULT_CONFIG.preloadAsync,
		onCreate = DEFAULT_CONFIG.onCreate,
		onAcquire = DEFAULT_CONFIG.onAcquire,
		onReturn = DEFAULT_CONFIG.onReturn,
		onDestroy = DEFAULT_CONFIG.onDestroy,
	}
end

--[[
    Checks if a warmUpType value is valid
    @param value - Value to check
    @return boolean
]]
function PoolConfig.IsValidWarmUpType(value: any): boolean
	return type(value) == "string" and VALID_WARMUP_TYPES[value] == true
end

--[[
    Checks if a cleanupType value is valid
    @param value - Value to check
    @return boolean
]]
function PoolConfig.IsValidCleanupType(value: any): boolean
	return type(value) == "string" and VALID_CLEANUP_TYPES[value] == true
end

--[[
    Checks if a growthType value is valid
    @param value - Value to check
    @return boolean
]]
function PoolConfig.IsValidGrowthType(value: any): boolean
	return type(value) == "string" and VALID_GROWTH_TYPES[value] == true
end

--[[
    Checks if a evictionType value is valid
    @param value - Value to check
    @return boolean
]]
function PoolConfig.IsValidEvictionType(value: any): boolean
	return type(value) == "string" and VALID_EVICTION_TYPES[value] == true
end

return PoolConfig
