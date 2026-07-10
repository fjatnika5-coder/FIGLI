--!strict
--[[
    GrowthStrategy.lua
    Advanced Object Pooling Engine - Growth Strategy
    
    Provides configurable growth strategies for pool expansion.
    Strategies: fixed (no growth), linear (+10 per growth), exponential (*2 capped by maxSize).
    
    Requirements: 7.1-7.5
]]

-- Import Constants for centralized configuration
local Constants = require(script.Parent.Parent.Utils.Constants)

type GrowthType = "fixed" | "linear" | "exponential"

-- ============================================================================
-- Constants (from centralized Constants module)
-- ============================================================================

local LINEAR_INCREMENT = Constants.Growth.LINEAR_INCREMENT
local EXPONENTIAL_MULTIPLIER = Constants.Growth.EXPONENTIAL_MULTIPLIER

-- ============================================================================
-- GrowthStrategy Class
-- ============================================================================

local GrowthStrategy = {}
GrowthStrategy.__index = GrowthStrategy

export type GrowthStrategyImpl = {
	strategyType: GrowthType,
	CalculateGrowth: (self: GrowthStrategyImpl, currentSize: number, needed: number) -> number,
	CanGrow: (self: GrowthStrategyImpl, pool: any) -> boolean,
}

--[[
    Create a new GrowthStrategy.
    
    @param strategyType - The type of growth strategy: "fixed", "linear", or "exponential"
    @return GrowthStrategyImpl - The new strategy instance
]]
function GrowthStrategy.new(strategyType: GrowthType): GrowthStrategyImpl
	local self = setmetatable({}, GrowthStrategy) :: any
	self.strategyType = strategyType
	return self
end

--[[
    Calculate the new target size after growth.
    
    @param currentSize - Current total number of objects in pool (available + inUse)
    @param needed - Number of additional objects needed
    @return number - New target size for the pool
    
    Requirements:
    - 7.1: fixed - no growth beyond initialSize
    - 7.2: linear - add N objects at each growth
    - 7.3: exponential - double capacity at each growth (capped by maxSize)
    - 7.4: CalculateGrowth returns new target size
]]
function GrowthStrategy.CalculateGrowth(self: GrowthStrategyImpl, currentSize: number, needed: number): number
	if needed <= 0 then
		return currentSize
	end

	if self.strategyType == "fixed" then
		-- Requirement 7.1: Fixed - no growth beyond current size
		return currentSize

	elseif self.strategyType == "linear" then
		-- Requirement 7.2: Linear - add LINEAR_INCREMENT objects at each growth
		-- Calculate how many growth steps needed to satisfy demand
		local growthSteps = math.ceil(needed / LINEAR_INCREMENT)
		local growth = growthSteps * LINEAR_INCREMENT
		return currentSize + growth

	elseif self.strategyType == "exponential" then
		-- Requirement 7.3: Exponential - double capacity at each growth
		local targetSize = currentSize

		-- Keep doubling until we have enough capacity
		while targetSize < currentSize + needed do
			if targetSize == 0 then
				-- Start with at least 1 if pool is empty
				targetSize = 1
			else
				targetSize = targetSize * EXPONENTIAL_MULTIPLIER
			end
		end

		return targetSize
	end

	-- Default fallback - no growth
	return currentSize
end

--[[
    Check if the pool can grow based on maxSize constraint.
    
    @param pool - The pool to check (must have config with maxSize)
    @return boolean - True if pool can grow, false otherwise
    
    Requirement 7.5: CanGrow returns boolean based on maxSize constraint
]]
function GrowthStrategy.CanGrow(self: GrowthStrategyImpl, pool: any): boolean
	-- Fixed strategy never grows
	if self.strategyType == "fixed" then
		return false
	end

	-- Get current total size
	local currentTotal = 0
	if pool._available and pool._available.Size then
		currentTotal = currentTotal + pool._available:Size()
	end
	if pool._inUse then
		for _ in pairs(pool._inUse) do
			currentTotal = currentTotal + 1
		end
	end

	-- Check maxSize constraint
	local maxSize = pool.config and pool.config.maxSize
	if maxSize then
		return currentTotal < maxSize
	end

	-- No maxSize limit - can always grow
	return true
end

--[[
    Calculate growth with maxSize cap applied.
    
    @param currentSize - Current total number of objects in pool
    @param needed - Number of additional objects needed
    @param maxSize - Maximum pool size (nil for unlimited)
    @return number - New target size capped by maxSize
]]
function GrowthStrategy.CalculateGrowthCapped(self: GrowthStrategyImpl, currentSize: number, needed: number, maxSize: number?): number
	local targetSize = self:CalculateGrowth(currentSize, needed)

	-- Apply maxSize cap if specified
	if maxSize and targetSize > maxSize then
		return maxSize
	end

	return targetSize
end

-- ============================================================================
-- Factory Functions
-- ============================================================================

--[[
    Create a fixed growth strategy.
    No growth beyond initialSize.
]]
function GrowthStrategy.Fixed(): GrowthStrategyImpl
	return GrowthStrategy.new("fixed")
end

--[[
    Create a linear growth strategy.
    Adds LINEAR_INCREMENT (10) objects at each growth.
]]
function GrowthStrategy.Linear(): GrowthStrategyImpl
	return GrowthStrategy.new("linear")
end

--[[
    Create an exponential growth strategy.
    Doubles capacity at each growth (capped by maxSize).
]]
function GrowthStrategy.Exponential(): GrowthStrategyImpl
	return GrowthStrategy.new("exponential")
end

-- ============================================================================
-- Module Export
-- ============================================================================

return {
	GrowthStrategy = GrowthStrategy,
	LINEAR_INCREMENT = LINEAR_INCREMENT,
	EXPONENTIAL_MULTIPLIER = EXPONENTIAL_MULTIPLIER,
}
