--!strict
--[[
    EvictionStrategy.lua
    Advanced Object Pooling Engine - Eviction Strategy
    
    Provides configurable eviction strategies for selecting objects to remove.
    Strategies: FIFO (oldest first), LIFO (newest first), LRU (least recently used), LFU (least frequently used).
    
    Requirements: 8.1-8.5
]]

type EvictionType = "fifo" | "lifo" | "lru" | "lfu"

-- ============================================================================
-- EvictionStrategy Class
-- ============================================================================

local EvictionStrategy = {}
EvictionStrategy.__index = EvictionStrategy

export type PooledObjectLike = {
	createdAt: number,
	lastUsed: number,
	useCount: number,
	isActive: boolean,
	isValid: boolean,
}

export type EvictionStrategyImpl = {
	strategyType: EvictionType,
	SelectVictims: (self: EvictionStrategyImpl, pool: any, count: number) -> {PooledObjectLike},
}

--[[
    Create a new EvictionStrategy.
    
    @param strategyType - The type of eviction strategy: "fifo", "lifo", "lru", or "lfu"
    @return EvictionStrategyImpl - The new strategy instance
]]
function EvictionStrategy.new(strategyType: EvictionType): EvictionStrategyImpl
	local self = setmetatable({}, EvictionStrategy) :: any
	self.strategyType = strategyType
	return self
end

--[[
    Get all available (non-active) PooledObjects from the pool.
    
    @param pool - The pool to get objects from
    @return {PooledObjectLike} - Array of available pooled objects
]]
local function getAvailableObjects(pool: any): {PooledObjectLike}
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
		local head = buffer._head or 1

		for i = 0, size - 1 do
			local index = ((head - 1 + i) % capacity) + 1
			local obj = buffer._buffer[index]
			if obj and not obj.isActive then
				table.insert(objects, obj)
			end
		end
	end

	return objects
end

--[[
    Select victims for eviction based on the strategy type.
    
    @param pool - The pool to select victims from
    @param count - Number of victims to select
    @return {PooledObjectLike} - Array of PooledObjects to remove
    
    Requirements:
    - 8.1: FIFO - select oldest objects first (by createdAt)
    - 8.2: LIFO - select newest objects first (by createdAt descending)
    - 8.3: LRU - select least recently used objects (by lastUsed ascending)
    - 8.4: LFU - select least frequently used objects (by useCount ascending)
    - 8.5: SelectVictims returns array of PooledObjects
]]
function EvictionStrategy.SelectVictims(self: EvictionStrategyImpl, pool: any, count: number): {PooledObjectLike}
	if count <= 0 then
		return {}
	end

	-- Get all available objects
	local available = getAvailableObjects(pool)

	if #available == 0 then
		return {}
	end

	-- Sort based on strategy type
	if self.strategyType == "fifo" then
		-- Requirement 8.1: FIFO - oldest first (by createdAt ascending)
		table.sort(available, function(a, b)
			return a.createdAt < b.createdAt
		end)

	elseif self.strategyType == "lifo" then
		-- Requirement 8.2: LIFO - newest first (by createdAt descending)
		table.sort(available, function(a, b)
			return a.createdAt > b.createdAt
		end)

	elseif self.strategyType == "lru" then
		-- Requirement 8.3: LRU - least recently used (by lastUsed ascending)
		table.sort(available, function(a, b)
			return a.lastUsed < b.lastUsed
		end)

	elseif self.strategyType == "lfu" then
		-- Requirement 8.4: LFU - least frequently used (by useCount ascending)
		table.sort(available, function(a, b)
			return a.useCount < b.useCount
		end)
	end

	-- Select up to 'count' victims
	local victims: {PooledObjectLike} = {}
	local selectCount = math.min(count, #available)

	for i = 1, selectCount do
		table.insert(victims, available[i])
	end

	return victims
end

-- ============================================================================
-- Factory Functions
-- ============================================================================

--[[
    Create a FIFO eviction strategy.
    Selects oldest objects first (by createdAt).
    
    Requirement 8.1
]]
function EvictionStrategy.FIFO(): EvictionStrategyImpl
	return EvictionStrategy.new("fifo")
end

--[[
    Create a LIFO eviction strategy.
    Selects newest objects first (by createdAt descending).
    
    Requirement 8.2
]]
function EvictionStrategy.LIFO(): EvictionStrategyImpl
	return EvictionStrategy.new("lifo")
end

--[[
    Create an LRU eviction strategy.
    Selects least recently used objects (by lastUsed ascending).
    
    Requirement 8.3
]]
function EvictionStrategy.LRU(): EvictionStrategyImpl
	return EvictionStrategy.new("lru")
end

--[[
    Create an LFU eviction strategy.
    Selects least frequently used objects (by useCount ascending).
    
    Requirement 8.4
]]
function EvictionStrategy.LFU(): EvictionStrategyImpl
	return EvictionStrategy.new("lfu")
end

-- ============================================================================
-- Module Export
-- ============================================================================

return {
	EvictionStrategy = EvictionStrategy,
}
