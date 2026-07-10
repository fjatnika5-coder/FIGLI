--!strict
--[[
    CleanupStrategy.lua
    Advanced Object Pooling Engine - Cleanup Strategy
    
    Provides configurable cleanup strategies for automatic removal of unused objects.
    Strategies: Threshold (cleanup when available > maxSize), TTL (time-to-live), LRU (least recently used).
    
    Requirements: 6.1-6.5
]]

type CleanupType = "threshold" | "ttl" | "lru"

-- ============================================================================
-- CleanupStrategy Class
-- ============================================================================

local CleanupStrategy = {}
CleanupStrategy.__index = CleanupStrategy

export type PooledObjectLike = {
	createdAt: number,
	lastUsed: number,
	useCount: number,
	isActive: boolean,
	isValid: boolean,
	Destroy: ((self: any) -> ())?,
}

export type PoolLike = {
	name: string,
	config: {
		maxSize: number?,
		objectTTL: number?,
		evictionType: string?,
		[string]: any,
	},
	_available: any, -- CircularBuffer
	_inUse: {[any]: boolean},
	_totalCreated: number?,
}

export type CleanupStrategyImpl = {
	strategyType: CleanupType,
	_evictionStrategy: any?, -- EvictionStrategy for LRU mode
	ShouldCleanup: (self: CleanupStrategyImpl, pool: PoolLike) -> boolean,
	Cleanup: (self: CleanupStrategyImpl, pool: PoolLike, targetCount: number?) -> number,
}

--[[
    Create a new CleanupStrategy.
    
    @param strategyType - The type of cleanup strategy: "threshold", "ttl", or "lru"
    @param evictionStrategy - Optional EvictionStrategy for LRU mode
    @return CleanupStrategyImpl - The new strategy instance
]]
function CleanupStrategy.new(strategyType: CleanupType, evictionStrategy: any?): CleanupStrategyImpl
	local self = setmetatable({}, CleanupStrategy) :: any
	self.strategyType = strategyType
	self._evictionStrategy = evictionStrategy
	return self
end

--[[
    Get all available (non-active) PooledObjects from the pool.
    
    @param pool - The pool to get objects from
    @return {PooledObjectLike} - Array of available pooled objects
]]
local function getAvailableObjects(pool: PoolLike): {PooledObjectLike}
	local objects: {PooledObjectLike} = {}

	-- Get objects from _available CircularBuffer
	if pool._available and pool._available.ToArray then
		local arr = pool._available:ToArray()
		for _, obj in ipairs(arr) do
			if obj and not obj.isActive then
				table.insert(objects, obj)
			end
		end
	elseif pool._available and pool._available._buffer then
		-- Direct access to buffer if ToArray not available
		local buffer = pool._available
		local size = buffer._size or 0
		local capacity = buffer._capacity or 0
		local tail = buffer._tail or 1

		-- Read items in FIFO order (from tail)
		for i = 0, size - 1 do
			local index = ((tail - 1 + i) % capacity) + 1
			local obj = buffer._buffer[index]
			if obj and not obj.isActive then
				table.insert(objects, obj)
			end
		end
	end

	return objects
end

--[[
    Get the count of available objects in the pool.
    
    @param pool - The pool to check
    @return number - Count of available objects
]]
local function getAvailableCount(pool: PoolLike): number
	if pool._available and pool._available.Size then
		return pool._available:Size()
	elseif pool._available and pool._available._size then
		return pool._available._size
	end
	return 0
end

--[[
    Remove an object from the pool's available buffer.
    
    @param pool - The pool to remove from
    @param obj - The object to remove
    @return boolean - True if removed successfully
]]
local function removeFromAvailable(pool: PoolLike, obj: PooledObjectLike): boolean
	if not pool._available then
		return false
	end

	-- If the buffer has a Remove method, use it
	if pool._available.Remove then
		return pool._available:Remove(obj)
	end

	-- Otherwise, we need to rebuild the buffer without this object
	-- This is less efficient but works for testing
	if pool._available._buffer and pool._available._size ~= nil then
		local buffer = pool._available
		local newItems = {}
		local found = false

		local size = buffer._size or 0
		local capacity = buffer._capacity or 0
		local tail = buffer._tail or 1

		-- Read items in FIFO order (from tail)
		for i = 0, size - 1 do
			local index = ((tail - 1 + i) % capacity) + 1
			local item = buffer._buffer[index]
			if item == obj and not found then
				found = true
				-- Skip this item (don't add to newItems)
			else
				table.insert(newItems, item)
			end
		end

		if found then
			-- Clear the buffer
			for i = 1, capacity do
				buffer._buffer[i] = nil
			end
			buffer._head = 1
			buffer._tail = 1
			buffer._size = 0

			-- Re-add remaining items
			for _, item in ipairs(newItems) do
				if buffer.Push then
					buffer:Push(item)
				end
			end

			return true
		end
	end

	return false
end

--[[
    Determine if cleanup should be performed based on the strategy type.
    
    @param pool - The pool to check
    @return boolean - True if cleanup is needed
    
    Requirements:
    - 6.1: Threshold - cleanup when available > maxSize
    - 6.2: TTL - cleanup when objects exceed objectTTL
    - 6.3: LRU - use eviction strategy for selection
    - 6.4: ShouldCleanup returns boolean
]]
function CleanupStrategy.ShouldCleanup(self: CleanupStrategyImpl, pool: PoolLike): boolean
	local availableCount = getAvailableCount(pool)

	if self.strategyType == "threshold" then
		-- Requirement 6.1: Cleanup when available > maxSize
		local maxSize = pool.config.maxSize
		if maxSize and availableCount > maxSize then
			return true
		end
		return false

	elseif self.strategyType == "ttl" then
		-- Requirement 6.2: Cleanup when objects exceed objectTTL
		local objectTTL = pool.config.objectTTL
		if not objectTTL then
			return false
		end

		local currentTime = os.clock()
		local available = getAvailableObjects(pool)

		for _, obj in ipairs(available) do
			local age = currentTime - obj.lastUsed
			if age > objectTTL then
				return true
			end
		end
		return false

	elseif self.strategyType == "lru" then
		-- Requirement 6.3: LRU uses eviction strategy
		-- For LRU, we check if there are objects that could be cleaned up
		-- based on maxSize threshold (similar to threshold but uses LRU selection)
		local maxSize = pool.config.maxSize
		if maxSize and availableCount > maxSize then
			return true
		end
		return false
	end

	return false
end

--[[
    Perform cleanup on the pool.
    
    @param pool - The pool to cleanup
    @param targetCount - Optional target count to cleanup to (for threshold/lru)
    @return number - Count of objects removed
    
    Requirements:
    - 6.1: Threshold - cleanup when available > maxSize
    - 6.2: TTL - destroy objects not used for objectTTL seconds
    - 6.3: LRU - use Least Recently Used eviction
    - 6.5: Cleanup returns count removed
]]
function CleanupStrategy.Cleanup(self: CleanupStrategyImpl, pool: PoolLike, targetCount: number?): number
	local removedCount = 0
	local availableCount = getAvailableCount(pool)

	if self.strategyType == "threshold" then
		-- Requirement 6.1: Cleanup when available > maxSize
		local maxSize = pool.config.maxSize
		if not maxSize or availableCount <= maxSize then
			return 0
		end

		-- Calculate how many to remove
		local toRemove = availableCount - maxSize
		if targetCount and targetCount < maxSize then
			toRemove = availableCount - targetCount
		end

		-- Get available objects sorted by createdAt (FIFO - oldest first)
		local available = getAvailableObjects(pool)
		table.sort(available, function(a, b)
			return a.createdAt < b.createdAt
		end)

		-- Remove oldest objects
		for i = 1, math.min(toRemove, #available) do
			local obj = available[i]
			if removeFromAvailable(pool, obj) then
				-- Destroy the object if it has a Destroy method
				if obj.Destroy then
					(obj :: any):Destroy()
				end
				removedCount = removedCount + 1
			end
		end

	elseif self.strategyType == "ttl" then
		-- Requirement 6.2: Destroy objects not used for objectTTL seconds
		local objectTTL = pool.config.objectTTL
		if not objectTTL then
			return 0
		end

		local currentTime = os.clock()
		local available = getAvailableObjects(pool)
		local toRemove: {PooledObjectLike} = {}

		-- Find all expired objects
		for _, obj in ipairs(available) do
			local age = currentTime - obj.lastUsed
			if age > objectTTL then
				table.insert(toRemove, obj)
			end
		end

		-- Remove expired objects
		for _, obj in ipairs(toRemove) do
			if removeFromAvailable(pool, obj) then
				if obj.Destroy then
					(obj :: any):Destroy()
				end
				removedCount = removedCount + 1
			end
		end

	elseif self.strategyType == "lru" then
		-- Requirement 6.3: Use LRU eviction strategy
		local maxSize = pool.config.maxSize
		if not maxSize or availableCount <= maxSize then
			return 0
		end

		-- Calculate how many to remove
		local toRemove = availableCount - maxSize
		if targetCount and targetCount < maxSize then
			toRemove = availableCount - targetCount
		end

		-- Use eviction strategy if available, otherwise sort by lastUsed
		local victims: {PooledObjectLike}

		if self._evictionStrategy and self._evictionStrategy.SelectVictims then
			victims = self._evictionStrategy:SelectVictims(pool, toRemove)
		else
			-- Fallback: sort by lastUsed ascending (LRU)
			local available = getAvailableObjects(pool)
			table.sort(available, function(a, b)
				return a.lastUsed < b.lastUsed
			end)

			victims = {}
			for i = 1, math.min(toRemove, #available) do
				table.insert(victims, available[i])
			end
		end

		-- Remove victims
		for _, obj in ipairs(victims) do
			if removeFromAvailable(pool, obj) then
				if obj.Destroy then
					(obj :: any):Destroy()
				end
				removedCount = removedCount + 1
			end
		end
	end

	return removedCount
end

-- ============================================================================
-- Factory Functions
-- ============================================================================

--[[
    Create a Threshold cleanup strategy.
    Cleans up when available > maxSize.
    
    Requirement 6.1
]]
function CleanupStrategy.Threshold(): CleanupStrategyImpl
	return CleanupStrategy.new("threshold")
end

--[[
    Create a TTL cleanup strategy.
    Destroys objects not used for objectTTL seconds.
    
    Requirement 6.2
]]
function CleanupStrategy.TTL(): CleanupStrategyImpl
	return CleanupStrategy.new("ttl")
end

--[[
    Create an LRU cleanup strategy.
    Uses Least Recently Used eviction for selection.
    
    @param evictionStrategy - Optional EvictionStrategy to use for selection
    
    Requirement 6.3
]]
function CleanupStrategy.LRU(evictionStrategy: any?): CleanupStrategyImpl
	return CleanupStrategy.new("lru", evictionStrategy)
end

-- ============================================================================
-- Module Export
-- ============================================================================

return {
	CleanupStrategy = CleanupStrategy,
}
