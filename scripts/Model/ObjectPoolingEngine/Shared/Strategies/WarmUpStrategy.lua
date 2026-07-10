--!strict
--[[
    WarmUpStrategy.lua
    Advanced Object Pooling Engine - Warm-Up Strategy
    
    Provides configurable warm-up strategies for pre-creating pool objects.
    Strategies: immediate (sync), progressive (batched), lazy (on-demand).
    
    Requirements: 5.1-5.6
]]

local RunService = game:GetService("RunService")

-- Import Constants for centralized configuration
local Constants = require(script.Parent.Parent.Utils.Constants)

type WarmUpType = "immediate" | "progressive" | "lazy"

-- ============================================================================
-- Simple Promise Implementation (for async warm-up)
-- ============================================================================

export type PromiseStatus = "pending" | "resolved" | "rejected"

export type Promise = {
	_status: PromiseStatus,
	_value: any?,
	_error: string?,
	_thenCallbacks: {(any) -> ()},
	_catchCallbacks: {(string) -> ()},
	andThen: (self: Promise, callback: (any) -> ()) -> Promise,
	catch: (self: Promise, callback: (string) -> ()) -> Promise,
	await: (self: Promise) -> (boolean, any),
	getStatus: (self: Promise) -> PromiseStatus,
}

local Promise = {}
Promise.__index = Promise

function Promise.new(executor: ((resolve: (any) -> (), reject: (string) -> ()) -> ())?): Promise
	local self = setmetatable({}, Promise) :: any
	self._status = "pending"
	self._value = nil
	self._error = nil
	self._thenCallbacks = {}
	self._catchCallbacks = {}

	if executor then
		local function resolve(value: any)
			if self._status ~= "pending" then return end
			self._status = "resolved"
			self._value = value
			for _, callback in ipairs(self._thenCallbacks) do
				callback(value)
			end
		end

		local function reject(err: string)
			if self._status ~= "pending" then return end
			self._status = "rejected"
			self._error = err
			for _, callback in ipairs(self._catchCallbacks) do
				callback(err)
			end
		end

		executor(resolve, reject)
	end

	return self
end

function Promise.resolve(value: any): Promise
	local p = Promise.new()
	p._status = "resolved"
	p._value = value
	return p
end

function Promise.reject(err: string): Promise
	local p = Promise.new()
	p._status = "rejected"
	p._error = err
	return p
end

function Promise.andThen(self: Promise, callback: (any) -> ()): Promise
	if self._status == "resolved" then
		callback(self._value)
	elseif self._status == "pending" then
		table.insert(self._thenCallbacks, callback)
	end
	return self
end

function Promise.catch(self: Promise, callback: (string) -> ()): Promise
	if self._status == "rejected" then
		callback(self._error :: string)
	elseif self._status == "pending" then
		table.insert(self._catchCallbacks, callback)
	end
	return self
end

--[[
    Await the promise completion.
    
    Uses Heartbeat:Wait() with a timeout to prevent infinite spin-wait.
    Returns immediately if already resolved/rejected.
    
    @param timeout - Optional timeout in seconds (default: 30)
    @return (boolean, any) - (success, value/error)
]]
function Promise.await(self: Promise, timeout: number?): (boolean, any)
	-- Return immediately if already resolved
	if self._status == "resolved" then
		return true, self._value
	elseif self._status == "rejected" then
		return false, self._error
	end

	-- Wait with timeout protection
	local maxTimeout = timeout or 30
	local startTime = os.clock()

	while self._status == "pending" do
		-- Check timeout to prevent infinite wait
		if os.clock() - startTime > maxTimeout then
			return false, "Promise await timeout"
		end
		RunService.Heartbeat:Wait()
	end

	if self._status == "resolved" then
		return true, self._value
	else
		return false, self._error
	end
end

function Promise.getStatus(self: Promise): PromiseStatus
	return self._status
end

-- ============================================================================
-- WarmUpStrategy Class
-- ============================================================================

local WarmUpStrategy = {}
WarmUpStrategy.__index = WarmUpStrategy

-- Constants from centralized module
local PROGRESSIVE_BATCH_SIZE = Constants.WarmUp.PROGRESSIVE_BATCH_SIZE
local ESTIMATED_TIME_PER_OBJECT = Constants.WarmUp.ESTIMATED_TIME_PER_OBJECT

export type WarmUpStrategyImpl = {
	strategyType: WarmUpType,
	_isCancelled: boolean,
	_connection: RBXScriptConnection?,
	_currentPromise: Promise?,
	Execute: (self: WarmUpStrategyImpl, pool: any, targetCount: number) -> Promise,
	GetEstimatedTime: (self: WarmUpStrategyImpl, count: number) -> number,
	Cancel: (self: WarmUpStrategyImpl) -> (),
	IsCancelled: (self: WarmUpStrategyImpl) -> boolean,
}

--[[
    Create a new WarmUpStrategy.
    
    @param strategyType - The type of warm-up strategy: "immediate", "progressive", or "lazy"
    @return WarmUpStrategyImpl - The new strategy instance
]]
function WarmUpStrategy.new(strategyType: WarmUpType): WarmUpStrategyImpl
	local self = setmetatable({}, WarmUpStrategy) :: any
	self.strategyType = strategyType
	self._isCancelled = false
	self._connection = nil
	self._currentPromise = nil
	return self
end

--[[
    Execute the warm-up strategy.
    
    @param pool - The pool to warm up (must have _createObject method)
    @param targetCount - Number of objects to pre-create
    @return Promise - Resolves when warm-up is complete
    
    Requirements:
    - 5.1: immediate - create all objects synchronously
    - 5.2: progressive - create objects in batches (10 per frame)
    - 5.3: lazy - no-op (create on demand)
    - 5.4: Execute returns Promise for async completion
]]
function WarmUpStrategy.Execute(self: WarmUpStrategyImpl, pool: any, targetCount: number): Promise
	-- Reset cancellation state
	self._isCancelled = false

	-- Validate inputs
	if targetCount <= 0 then
		return Promise.resolve(0)
	end

	-- Check maxSize constraint
	local maxSize = pool.config and pool.config.maxSize
	if maxSize and targetCount > maxSize then
		targetCount = maxSize
	end

	-- Get current available count to determine how many to create
	local currentCount = 0
	if pool._available and pool._available.Size then
		currentCount = pool._available:Size()
	end

	local toCreate = math.max(0, targetCount - currentCount)

	if toCreate <= 0 then
		return Promise.resolve(currentCount)
	end

	-- Execute based on strategy type
	if self.strategyType == "lazy" then
		-- Requirement 5.3: Lazy - no-op, create on demand
		return Promise.resolve(currentCount)

	elseif self.strategyType == "immediate" then
		-- Requirement 5.1: Immediate - sync creation
		return self:_executeImmediate(pool, toCreate)

	elseif self.strategyType == "progressive" then
		-- Requirement 5.2: Progressive - batched creation
		return self:_executeProgressive(pool, toCreate)
	end

	-- Default fallback
	return Promise.resolve(currentCount)
end

--[[
    Execute immediate (synchronous) warm-up.
    Creates all objects in a single frame.
]]
function WarmUpStrategy._executeImmediate(self: WarmUpStrategyImpl, pool: any, count: number): Promise
	return Promise.new(function(resolve, reject)
		local created = 0

		for i = 1, count do
			if self._isCancelled then
				break
			end

			-- Check maxSize constraint
			local maxSize = pool.config and pool.config.maxSize
			local currentTotal = 0
			if pool._available and pool._available.Size then
				currentTotal = currentTotal + pool._available:Size()
			end
			if pool._inUse then
				for _ in pairs(pool._inUse) do
					currentTotal = currentTotal + 1
				end
			end

			if maxSize and currentTotal >= maxSize then
				break
			end

			-- Create object using pool's creation method
			local success = self:_createPoolObject(pool)
			if success then
				created = created + 1
			end
		end

		resolve(created)
	end)
end

--[[
    Execute progressive (batched) warm-up.
    Creates objects in batches of 10 per frame to avoid lag spikes.
    
    Uses 'resolved' flag to prevent race condition where resolve()
    could be called multiple times.
]]
function WarmUpStrategy._executeProgressive(self: WarmUpStrategyImpl, pool: any, count: number): Promise
	return Promise.new(function(resolve, reject)
		local created = 0
		local remaining = count
		local resolved = false  -- Prevent multiple resolve() calls

		-- Use Heartbeat for frame-by-frame batching
		self._connection = RunService.Heartbeat:Connect(function()
			-- Early exit if already resolved
			if resolved then
				return
			end

			if self._isCancelled or remaining <= 0 then
				resolved = true  -- Mark as resolved before cleanup
				if self._connection then
					self._connection:Disconnect()
					self._connection = nil
				end
				resolve(created)
				return
			end

			-- Create batch of objects this frame
			local batchSize = math.min(PROGRESSIVE_BATCH_SIZE, remaining)

			for i = 1, batchSize do
				if self._isCancelled then
					break
				end

				-- Check maxSize constraint
				local maxSize = pool.config and pool.config.maxSize
				local currentTotal = 0
				if pool._available and pool._available.Size then
					currentTotal = currentTotal + pool._available:Size()
				end
				if pool._inUse then
					for _ in pairs(pool._inUse) do
						currentTotal = currentTotal + 1
					end
				end

				if maxSize and currentTotal >= maxSize then
					remaining = 0
					break
				end

				-- Create object
				local success = self:_createPoolObject(pool)
				if success then
					created = created + 1
				end

				remaining = remaining - 1
			end

			-- Check if done
			if remaining <= 0 or self._isCancelled then
				if not resolved then  -- Double-check before resolving
					resolved = true
					if self._connection then
						self._connection:Disconnect()
						self._connection = nil
					end
					resolve(created)
				end
			end
		end)
	end)
end

--[[
    Create a single object in the pool.
    Handles different pool implementations.
    
    @param pool - The pool to create an object in
    @return boolean - True if object was created successfully
]]
function WarmUpStrategy._createPoolObject(self: WarmUpStrategyImpl, pool: any): boolean
	-- Try different creation methods that pools might have
	-- Prefer _createAndAddToAvailable as it adds to the available buffer
	if pool._createAndAddToAvailable then
		return pool:_createAndAddToAvailable()
	elseif pool._createObject then
		local obj = pool:_createObject()
		return obj ~= nil
	elseif pool.createObject then
		local obj = pool:createObject()
		return obj ~= nil
	end

	-- No creation method available
	return false
end

--[[
    Get estimated time to complete warm-up.
    
    @param count - Number of objects to create
    @return number - Estimated time in seconds
    
    Requirement 5.5: GetEstimatedTime returns estimated completion time
]]
function WarmUpStrategy.GetEstimatedTime(self: WarmUpStrategyImpl, count: number): number
	if count <= 0 then
		return 0
	end

	if self.strategyType == "lazy" then
		-- Lazy creates nothing upfront
		return 0

	elseif self.strategyType == "immediate" then
		-- Immediate creates all at once
		return count * ESTIMATED_TIME_PER_OBJECT

	elseif self.strategyType == "progressive" then
		-- Progressive creates in batches over multiple frames
		-- Assume ~60 FPS, so each frame is ~0.0167 seconds
		local frames = math.ceil(count / PROGRESSIVE_BATCH_SIZE)
		local frameTime = 1 / 60
		return frames * frameTime + (count * ESTIMATED_TIME_PER_OBJECT)
	end

	return 0
end

--[[
    Cancel ongoing warm-up process.
    Clears _currentPromise reference to help GC.
    
    Requirement 5.6: Cancel stops ongoing warm-up process
]]
function WarmUpStrategy.Cancel(self: WarmUpStrategyImpl): ()
	self._isCancelled = true

	-- Disconnect any active Heartbeat connection
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	-- Clear promise reference
	self._currentPromise = nil
end

--[[
    Check if the warm-up has been cancelled.
    
    @return boolean - True if cancelled
]]
function WarmUpStrategy.IsCancelled(self: WarmUpStrategyImpl): boolean
	return self._isCancelled
end

-- ============================================================================
-- Factory Functions
-- ============================================================================

--[[
    Create an immediate warm-up strategy.
    Creates all objects synchronously in a single frame.
]]
function WarmUpStrategy.Immediate(): WarmUpStrategyImpl
	return WarmUpStrategy.new("immediate")
end

--[[
    Create a progressive warm-up strategy.
    Creates objects in batches of 10 per frame.
]]
function WarmUpStrategy.Progressive(): WarmUpStrategyImpl
	return WarmUpStrategy.new("progressive")
end

--[[
    Create a lazy warm-up strategy.
    No-op - objects are created on demand.
]]
function WarmUpStrategy.Lazy(): WarmUpStrategyImpl
	return WarmUpStrategy.new("lazy")
end

-- ============================================================================
-- Module Export
-- ============================================================================

return {
	WarmUpStrategy = WarmUpStrategy,
	Promise = Promise,
	PROGRESSIVE_BATCH_SIZE = PROGRESSIVE_BATCH_SIZE,  -- Exported for backwards compatibility
}
