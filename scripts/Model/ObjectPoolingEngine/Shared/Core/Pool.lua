--!strict
--[[
    Pool.lua
    Advanced Object Pooling Engine - Pool Class
    
    Manages a single category of pooled objects with configurable strategies.
    Uses CircularBuffer for O(1) get/return operations.
    
    Requirements: 2.1-2.10
]]

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)
local CircularBuffer = require(script.Parent.Parent.Utils.CircularBuffer)
local PooledObject = require(script.Parent.PooledObject)
local PoolRegistry = require(script.Parent.PoolRegistry)
local ObjectValidator = require(script.Parent.Parent.Utils.ObjectValidator)
local PoolConfigModule = require(script.Parent.Parent.Config.PoolConfig)
local Constants = require(script.Parent.Parent.Utils.Constants)

-- Strategy modules
local WarmUpStrategyModule = require(script.Parent.Parent.Strategies.WarmUpStrategy)
local CleanupStrategyModule = require(script.Parent.Parent.Strategies.CleanupStrategy)
local GrowthStrategyModule = require(script.Parent.Parent.Strategies.GrowthStrategy)
local EvictionStrategyModule = require(script.Parent.Parent.Strategies.EvictionStrategy)

type PoolConfig = Types.PoolConfig
type PoolStats = Types.PoolStats
type PooledObjectImpl = PooledObject.PooledObjectImpl
type CircularBufferImpl<T> = CircularBuffer.CircularBufferImpl<T>
type WarmUpStrategyImpl = WarmUpStrategyModule.WarmUpStrategyImpl
type CleanupStrategyImpl = CleanupStrategyModule.CleanupStrategyImpl
type GrowthStrategyImpl = GrowthStrategyModule.GrowthStrategyImpl
type EvictionStrategyImpl = EvictionStrategyModule.EvictionStrategyImpl
type Promise = WarmUpStrategyModule.Promise

local WarmUpStrategy = WarmUpStrategyModule.WarmUpStrategy
local CleanupStrategy = CleanupStrategyModule.CleanupStrategy
local GrowthStrategy = GrowthStrategyModule.GrowthStrategy
local EvictionStrategy = EvictionStrategyModule.EvictionStrategy
local Promise = WarmUpStrategyModule.Promise

-- ============================================================================
-- Constants (from centralized Constants module)
-- ============================================================================

local DEBUG_MODE = false
local DEFAULT_BUFFER_CAPACITY = Constants.Pool.DEFAULT_BUFFER_CAPACITY

-- ============================================================================
-- Pool Class
-- ============================================================================

local Pool = {}
Pool.__index = Pool

export type PoolImpl = {
	name: string,
	config: PoolConfig,

	-- Storage (Requirement 2.1)
	_available: CircularBufferImpl<PooledObjectImpl>,
	_inUse: {[PooledObjectImpl]: boolean},
	_inUseCount: number,  -- O(1) count tracking
	_template: Instance?,
	_templateId: number?,
	_storageFolder: Folder?,

	-- Strategies (DI)
	_warmUp: WarmUpStrategyImpl,
	_cleanup: CleanupStrategyImpl,
	_growth: GrowthStrategyImpl,
	_eviction: EvictionStrategyImpl,

	-- State (Requirement 2.9)
	_totalCreated: number,
	_peakUsage: number,
	_lastCleanup: number,
	_totalGets: number,
	_totalHits: number,
	_lifetimes: {number},

	-- Cleanup timer
	_cleanupConnection: RBXScriptConnection?,
	_lastCleanupCheck: number,

	-- Methods
	Get: (self: PoolImpl) -> Instance?,
	Return: (self: PoolImpl, object: Instance) -> boolean,
	WarmUp: (self: PoolImpl, count: number) -> Promise,
	Clear: (self: PoolImpl) -> (),
	Resize: (self: PoolImpl, newSize: number) -> (),
	GetStats: (self: PoolImpl) -> PoolStats,
	Destroy: (self: PoolImpl) -> (),
	SetTemplate: (self: PoolImpl, template: Instance | number) -> (),
	GetTotalCount: (self: PoolImpl) -> number,
	GetAvailableCount: (self: PoolImpl) -> number,
	GetInUseCount: (self: PoolImpl) -> number,
}

--[[
    Debug logging helper
]]
local function debugLog(message: string, ...)
	if DEBUG_MODE then
		print(string.format("[Pool] " .. message, ...))
	end
end

--[[
    Create a new Pool instance.
    
    @param name - Unique name for this pool category
    @param config - Pool configuration (merged with defaults)
    @param template - Optional template Instance or asset ID
    @return PoolImpl - The new Pool instance
    
    Requirement 2.1: Maintain separate storage for available and in-use objects
]]
function Pool.new(name: string, config: {[string]: any}?, template: (Instance | number)?): PoolImpl
	local self = setmetatable({}, Pool) :: any

	-- Validate and merge config with defaults
	local mergedConfig = PoolConfigModule.MergeWithDefaults(config)

	self.name = name
	self.config = mergedConfig

	-- Storage (Requirement 2.1, 2.10)
	local bufferCapacity = mergedConfig.maxSize or DEFAULT_BUFFER_CAPACITY
	self._available = CircularBuffer.new(bufferCapacity)
	self._inUse = {} :: {[PooledObjectImpl]: boolean}
	self._inUseCount = 0  -- O(1) count tracking

	-- Template
	self._template = nil
	self._templateId = nil
	self._storageFolder = nil
	if template then
		if typeof(template) == "Instance" then
			self._template = template
		elseif type(template) == "number" then
			self._templateId = template
		end
	end

	-- Create strategies based on config (DI)
	self._warmUp = self:_createWarmUpStrategy(mergedConfig.warmUpType)
	self._cleanup = self:_createCleanupStrategy(mergedConfig.cleanupType)
	self._growth = self:_createGrowthStrategy(mergedConfig.growthType)
	self._eviction = self:_createEvictionStrategy(mergedConfig.evictionType)

	-- State tracking (Requirement 2.9)
	self._totalCreated = 0
	self._peakUsage = 0
	self._lastCleanup = os.clock()
	self._totalGets = 0
	self._totalHits = 0
	self._lifetimes = {}

	-- Setup automatic cleanup
	self._lastCleanupCheck = os.clock()
	self:_setupCleanupTimer()

	debugLog("Created pool '%s' with config: initialSize=%d, maxSize=%s", 
		name, 
		mergedConfig.initialSize, 
		tostring(mergedConfig.maxSize))

	return self
end

--[[
    Create WarmUp strategy based on type
]]
function Pool._createWarmUpStrategy(self: PoolImpl, strategyType: string): WarmUpStrategyImpl
	if strategyType == "immediate" then
		return WarmUpStrategy.Immediate()
	elseif strategyType == "progressive" then
		return WarmUpStrategy.Progressive()
	else
		return WarmUpStrategy.Lazy()
	end
end

--[[
    Create Cleanup strategy based on type
]]
function Pool._createCleanupStrategy(self: PoolImpl, strategyType: string): CleanupStrategyImpl
	if strategyType == "ttl" then
		return CleanupStrategy.TTL()
	elseif strategyType == "lru" then
		return CleanupStrategy.LRU(self._eviction)
	else
		return CleanupStrategy.Threshold()
	end
end

--[[
    Create Growth strategy based on type
]]
function Pool._createGrowthStrategy(self: PoolImpl, strategyType: string): GrowthStrategyImpl
	if strategyType == "fixed" then
		return GrowthStrategy.Fixed()
	elseif strategyType == "linear" then
		return GrowthStrategy.Linear()
	else
		return GrowthStrategy.Exponential()
	end
end

--[[
    Create Eviction strategy based on type
]]
function Pool._createEvictionStrategy(self: PoolImpl, strategyType: string): EvictionStrategyImpl
	if strategyType == "fifo" then
		return EvictionStrategy.FIFO()
	elseif strategyType == "lifo" then
		return EvictionStrategy.LIFO()
	elseif strategyType == "lfu" then
		return EvictionStrategy.LFU()
	else
		return EvictionStrategy.LRU()
	end
end

--[[
    Setup automatic cleanup timer based on cleanupInterval
]]
function Pool._setupCleanupTimer(self: PoolImpl): ()
	local cleanupInterval = self.config.cleanupInterval
	if cleanupInterval <= 0 then
		return
	end

	self._cleanupConnection = RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		if now - self._lastCleanupCheck >= cleanupInterval then
			self._lastCleanupCheck = now
			self:_performCleanup()
		end
	end)
end

--[[
    Perform automatic cleanup if needed
]]
function Pool._performCleanup(self: PoolImpl): ()
	if self._cleanup:ShouldCleanup(self) then
		local removed = self._cleanup:Cleanup(self)
		if removed > 0 then
			self._lastCleanup = os.clock()
			debugLog("Pool '%s' cleaned up %d objects", self.name, removed)
		end
	end
end

--[[
    Get an object from the pool.
    
    Flow: check available → growth → create
    
    @return Instance? - The acquired Instance or nil if failed
    
    Requirements:
    - 2.2: Return object from _available in O(1) time
    - 2.3: Use GrowthStrategy when no objects available
    
    Validates pooledObject.isValid to prevent returning corrupted objects.
]]
function Pool.Get(self: PoolImpl): Instance?
	self._totalGets = self._totalGets + 1

	-- Try to get from available (Requirement 2.2: O(1) operation)
	local pooledObject = self._available:Pop()

	-- Skip invalid objects that may have been destroyed externally
	while pooledObject and not pooledObject.isValid do
		debugLog("Pool '%s': Skipping invalid object %s", self.name, pooledObject.id)
		pooledObject = self._available:Pop()
	end

	if pooledObject then
		-- Hit - object was available
		self._totalHits = self._totalHits + 1
		return self:_acquireObject(pooledObject)
	end

	-- Miss - need to create or grow
	-- Check if we can grow (Requirement 2.3)
	if self._growth:CanGrow(self) then
		-- Create a new object
		pooledObject = self:_createObject()
		if pooledObject then
			return self:_acquireObject(pooledObject)
		end
	end

	-- Cannot grow or create failed
	debugLog("Pool '%s': Get failed - cannot grow and no available objects", self.name)
	return nil
end

--[[
    Acquire a pooled object and move it to in-use.
    Uses _inUseCount for O(1) count tracking.
    Validates object before acquiring.
]]
function Pool._acquireObject(self: PoolImpl, pooledObject: PooledObjectImpl): Instance?
	-- Validate object before acquiring
	if not pooledObject.isValid then
		warn(string.format("[Pool] '%s': Cannot acquire invalid pooled object", self.name))
		return nil
	end

	-- Check if instance still exists
	if not pooledObject.instance then
		warn(string.format("[Pool] '%s': Pooled object has nil instance", self.name))
		pooledObject.isValid = false
		return nil
	end

	-- Move to in-use set
	self._inUse[pooledObject] = true
	self._inUseCount = self._inUseCount + 1

	-- Update peak usage (now O(1) instead of O(n))
	if self._inUseCount > self._peakUsage then
		self._peakUsage = self._inUseCount
	end

	-- Acquire the object (updates metadata)
	local instance = pooledObject:Acquire()

	-- Call onAcquire callback if configured (with error protection)
	if self.config.onAcquire then
		local success, err = pcall(self.config.onAcquire, instance)
		if not success then
			warn(string.format("[Pool] '%s': onAcquire callback error: %s", self.name, tostring(err)))
		end
	end

	-- Set auto-return if configured
	if self.config.autoReturnDelay then
		pooledObject:SetAutoReturn(self.config.autoReturnDelay)
	end

	debugLog("Pool '%s': Acquired object %s", self.name, pooledObject.id)

	return instance
end

--[[
    Return an object to the pool.
    
    Flow: validate → reset → move to available
    
    @param object - The Instance to return
    @return boolean - True if returned successfully
    
    Requirement 2.4: Move object from _inUse to _available
    
    THREAD-SAFETY: This method is NOT thread-safe. If called from multiple
    coroutines simultaneously for the same object, it may cause issues.
    In Roblox, this is generally safe since Lua is single-threaded per VM.
]]
function Pool.Return(self: PoolImpl, object: Instance): boolean
	-- SAFETY: Early nil check to prevent crash on destroyed instances
	if object == nil then
		warn(string.format("[Pool] '%s': Cannot return nil object", self.name))
		return false
	end

	-- Get the wrapper from registry
	local pooledObject = PoolRegistry.GetWrapper(object) :: PooledObjectImpl?

	if not pooledObject then
		warn(string.format("[Pool] '%s': Unknown object returned", self.name))
		return false
	end

	-- Check if object belongs to this pool
	local registeredPool = PoolRegistry.GetPool(object)
	if registeredPool ~= self then
		warn(string.format("[Pool] '%s': Object belongs to different pool", self.name))
		return false
	end

	-- Check if object is in use
	if not self._inUse[pooledObject] then
		-- Already returned or never acquired
		debugLog("Pool '%s': Object %s not in use", self.name, pooledObject.id)
		return false
	end

	-- Validate if enabled (Requirement 15.2)
	-- Uses ValidateForReturn() which skips checkParent - objects may legitimately
	-- have Parent=nil when being returned (e.g. fish effects, cleaned up VFX).
	-- The pool will reparent/unparent the object itself after this check.
	if self.config.enableValidation then
		if not pooledObject:ValidateForReturn() then
			warn(string.format("[Pool] '%s': Invalid object returned, destroying", self.name))
			self:_destroyObject(pooledObject)
			return false
		end
	end

	-- Record lifetime for analytics
	local lifetime = os.clock() - pooledObject.lastUsed
	table.insert(self._lifetimes, lifetime)
	-- Keep only last 100 lifetimes
	if #self._lifetimes > 100 then
		table.remove(self._lifetimes, 1)
	end

	-- Call onReturn callback if configured (with error protection)
	if self.config.onReturn then
		local success, err = pcall(self.config.onReturn, object)
		if not success then
			warn(string.format("[Pool] '%s': onReturn callback error: %s", self.name, tostring(err)))
		end
	end

	-- Return the pooled object (updates state)
	pooledObject:Return()

	-- Reset the object
	pooledObject:Reset()

	-- Unparent the object (move out of workspace while pooled)
	pcall(function()
		if pooledObject.instance then
			pooledObject.instance.Parent = nil
		end
	end)

	-- Move from in-use to available (Requirement 2.4)
	self._inUse[pooledObject] = nil
	self._inUseCount = self._inUseCount - 1

	-- Try to add back to available buffer
	if not self._available:Push(pooledObject) then
		-- Buffer is full, destroy the object
		debugLog("Pool '%s': Available buffer full, destroying object", self.name)
		self:_destroyObject(pooledObject)
	end

	debugLog("Pool '%s': Returned object %s", self.name, pooledObject.id)

	return true
end

--[[
    Create a new pooled object.
    
    @return PooledObjectImpl? - The new pooled object or nil if failed
]]
function Pool._createObject(self: PoolImpl): PooledObjectImpl?
	-- Check maxSize constraint
	local maxSize = self.config.maxSize
	if maxSize and self:GetTotalCount() >= maxSize then
		debugLog("Pool '%s': Cannot create - maxSize reached", self.name)
		return nil
	end

	-- Create the Instance
	local instance: Instance?

	if self._template then
		-- Clone from template
		local success, result = pcall(function()
			return self._template:Clone()
		end)
		if success then
			instance = result
		else
			warn(string.format("[Pool] '%s': Failed to clone template: %s", self.name, tostring(result)))
			return nil
		end
	elseif self._templateId then
		-- Asset ID provided - create default Part (InsertService not used for performance)
		local part = Instance.new("Part")
		part.Name = self.name .. "_Object"
		part.Anchored = true
		part.CanCollide = false
		instance = part
	else
		-- No template - create a basic Part
		local part = Instance.new("Part")
		part.Name = self.name .. "_Object"
		part.Anchored = true
		part.CanCollide = false
		instance = part
	end

	if not instance then
		warn(string.format("[Pool] '%s': Failed to create instance", self.name))
		return nil
	end

	-- Parent to a storage location (workspace by default) so validation passes
	-- Objects need a parent for validation to succeed
	if not self._storageFolder then
		self._storageFolder = Instance.new("Folder")
		self._storageFolder.Name = "_PoolStorage_" .. self.name
		self._storageFolder.Parent = workspace
	end
	instance.Parent = self._storageFolder

	-- Call onCreate callback if configured
	if self.config.onCreate then
		local success, err = pcall(self.config.onCreate, instance)
		if not success then
			warn(string.format("[Pool] '%s': onCreate callback error: %s", self.name, tostring(err)))
		end
	end

	-- Create the wrapper
	local pooledObject = PooledObject.new(instance, self :: any)

	-- Update stats
	self._totalCreated = self._totalCreated + 1

	debugLog("Pool '%s': Created object %s (total: %d)", self.name, pooledObject.id, self._totalCreated)

	return pooledObject
end

--[[
    Create an object and add it directly to available buffer.
    Used by WarmUpStrategy.
    
    @return boolean - True if created successfully
]]
function Pool._createAndAddToAvailable(self: PoolImpl): boolean
	local pooledObject = self:_createObject()
	if not pooledObject then
		return false
	end

	-- Add to available buffer
	if not self._available:Push(pooledObject) then
		-- Buffer is full
		self:_destroyObject(pooledObject)
		return false
	end

	return true
end

--[[
    Destroy a pooled object.
    Decrements _inUseCount if object was in use.
]]
function Pool._destroyObject(self: PoolImpl, pooledObject: PooledObjectImpl): ()
	-- Remove from in-use if present and decrement count
	if self._inUse[pooledObject] then
		self._inUse[pooledObject] = nil
		self._inUseCount = self._inUseCount - 1
	end

	-- Call onDestroy callback if configured (with error protection)
	if self.config.onDestroy and pooledObject.instance then
		local success, err = pcall(self.config.onDestroy, pooledObject.instance)
		if not success then
			warn(string.format("[Pool] '%s': onDestroy callback error: %s", self.name, tostring(err)))
		end
	end

	-- Destroy the pooled object
	pooledObject:Destroy()

	debugLog("Pool '%s': Destroyed object %s", self.name, pooledObject.id)
end

--[[
    Pre-create objects using the configured WarmUpStrategy.
    
    @param count - Number of objects to pre-create
    @return Promise - Resolves when warm-up is complete
    
    Requirement 2.5: Pre-create objects using WarmUpStrategy
]]
function Pool.WarmUp(self: PoolImpl, count: number): Promise
	debugLog("Pool '%s': Starting warm-up for %d objects", self.name, count)
	return self._warmUp:Execute(self, count)
end

--[[
    Clear all objects from the pool.
    
    Requirement 2.6: Destroy all objects and reset the pool
]]
function Pool.Clear(self: PoolImpl): ()
	debugLog("Pool '%s': Clearing all objects", self.name)

	-- Destroy all available objects
	while not self._available:IsEmpty() do
		local pooledObject = self._available:Pop()
		if pooledObject then
			self:_destroyObject(pooledObject)
		end
	end

	-- Destroy all in-use objects
	for pooledObject in pairs(self._inUse) do
		self:_destroyObject(pooledObject)
	end

	-- Clear the in-use set
	table.clear(self._inUse)
	self._inUseCount = 0

	-- Reset stats
	self._peakUsage = 0
	self._totalGets = 0
	self._totalHits = 0
	table.clear(self._lifetimes)

	debugLog("Pool '%s': Cleared", self.name)
end

--[[
    Resize the pool capacity.
    
    @param newSize - New maximum size for the pool
    
    Requirement 2.7: Adjust pool capacity
]]
function Pool.Resize(self: PoolImpl, newSize: number): ()
	if newSize <= 0 then
		warn(string.format("[Pool] '%s': Invalid resize value: %d", self.name, newSize))
		return
	end

	debugLog("Pool '%s': Resizing to %d", self.name, newSize)

	-- Update config
	self.config.maxSize = newSize

	-- If current total exceeds new size, cleanup excess
	local currentTotal = self:GetTotalCount()
	if currentTotal > newSize then
		local toRemove = currentTotal - newSize

		-- Remove from available first
		while toRemove > 0 and not self._available:IsEmpty() do
			local pooledObject = self._available:Pop()
			if pooledObject then
				self:_destroyObject(pooledObject)
				toRemove = toRemove - 1
			end
		end
	end

	-- Recreate buffer with new capacity if needed
	if newSize > self._available:Capacity() then
		local oldBuffer = self._available
		self._available = CircularBuffer.new(newSize)

		-- Transfer objects from old buffer
		local objects = oldBuffer:ToArray()
		for _, obj in ipairs(objects) do
			self._available:Push(obj)
		end
	end
end

--[[
    Get current pool statistics.
    
    @return PoolStats - Current statistics
    
    Requirement 2.8: Return current pool statistics
]]
function Pool.GetStats(self: PoolImpl): PoolStats
	local availableCount = self._available:Size()
	local inUseCount = self:GetInUseCount()

	-- Calculate hit rate
	local hitRate = 0
	if self._totalGets > 0 then
		hitRate = self._totalHits / self._totalGets
	end

	-- Calculate average lifetime
	local avgLifetime = 0
	if #self._lifetimes > 0 then
		local sum = 0
		for _, lifetime in ipairs(self._lifetimes) do
			sum = sum + lifetime
		end
		avgLifetime = sum / #self._lifetimes
	end

	return {
		name = self.name,
		availableCount = availableCount,
		inUseCount = inUseCount,
		totalCreated = self._totalCreated,
		peakUsage = self._peakUsage,
		hitRate = hitRate,
		avgLifetime = avgLifetime,
	}
end

--[[
    Set the template for creating new objects.
    
    @param template - Instance to clone or asset ID to load
]]
function Pool.SetTemplate(self: PoolImpl, template: Instance | number): ()
	if typeof(template) == "Instance" then
		self._template = template
		self._templateId = nil
	elseif type(template) == "number" then
		self._templateId = template
		self._template = nil
	end
end

--[[
    Get total count of objects (available + in-use).
    
    @return number - Total object count
]]
function Pool.GetTotalCount(self: PoolImpl): number
	return self._available:Size() + self:GetInUseCount()
end

--[[
    Get count of available objects.
    
    @return number - Available object count
]]
function Pool.GetAvailableCount(self: PoolImpl): number
	return self._available:Size()
end

--[[
    Get count of in-use objects.
    O(1) operation using cached _inUseCount.
    
    @return number - In-use object count
]]
function Pool.GetInUseCount(self: PoolImpl): number
	return self._inUseCount
end

--[[
    Destroy the pool and cleanup all resources.
    Clears all internal references for proper GC.
]]
function Pool.Destroy(self: PoolImpl): ()
	debugLog("Pool '%s': Destroying", self.name)

	-- Stop cleanup timer
	if self._cleanupConnection then
		self._cleanupConnection:Disconnect()
		self._cleanupConnection = nil
	end

	-- Cancel any ongoing warm-up
	self._warmUp:Cancel()

	-- Clear all objects
	self:Clear()

	-- Destroy storage folder
	if self._storageFolder then
		self._storageFolder:Destroy()
		self._storageFolder = nil
	end

	-- Clear all internal references for GC
	self._template = nil
	self._warmUp = nil :: any
	self._cleanup = nil :: any
	self._growth = nil :: any
	self._eviction = nil :: any
	table.clear(self._lifetimes)

	debugLog("Pool '%s': Destroyed", self.name)
end

return Pool
