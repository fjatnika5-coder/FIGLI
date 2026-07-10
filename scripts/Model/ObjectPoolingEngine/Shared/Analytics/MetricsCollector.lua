--!strict
--[[
    MetricsCollector.lua
    Advanced Object Pooling Engine - Per-Pool Metrics Collection
    
    Collects metrics for individual pools with batch update buffering.
    Requirements: 9.2
]]

local Types = require(script.Parent.Parent.Types)
local Constants = require(script.Parent.Parent.Utils.Constants)

-- ============================================================================
-- MetricsCollector Class
-- ============================================================================

local MetricsCollector = {}
MetricsCollector.__index = MetricsCollector

export type MetricsCollectorImpl = {
	poolName: string,

	-- Counters
	_gets: number,
	_returns: number,
	_hits: number,
	_created: number,
	_destroyed: number,

	-- Lifetime tracking (circular buffer of recent lifetimes)
	_lifetimes: {number},
	_lifetimeIndex: number,
	_lifetimeCapacity: number,

	-- Peak tracking
	_peakUsage: number,
	_currentInUse: number,

	-- Batch buffer for pending updates
	_pendingGets: number,
	_pendingReturns: number,
	_pendingHits: number,
	_batchSize: number,

	-- Methods
	RecordGet: (self: MetricsCollectorImpl, wasHit: boolean) -> (),
	RecordReturn: (self: MetricsCollectorImpl, lifetime: number) -> (),
	RecordCreate: (self: MetricsCollectorImpl) -> (),
	RecordDestroy: (self: MetricsCollectorImpl) -> (),
	UpdateInUse: (self: MetricsCollectorImpl, count: number) -> (),
	FlushBatch: (self: MetricsCollectorImpl) -> (),
	GetMetrics: (self: MetricsCollectorImpl) -> Types.PoolMetrics,
	GetDetailedMetrics: (self: MetricsCollectorImpl) -> DetailedMetrics,
	Reset: (self: MetricsCollectorImpl) -> (),
}

export type DetailedMetrics = {
	gets: number,
	returns: number,
	hits: number,
	created: number,
	destroyed: number,
	hitRate: number,
	peakUsage: number,
	avgLifetime: number,
	currentInUse: number,
}

--[[
    Create a new MetricsCollector for a specific pool.
    @param poolName - Name of the pool being tracked
    @param batchSize - Number of operations before auto-flush (default from Constants)
]]
function MetricsCollector.new(poolName: string, batchSize: number?): MetricsCollectorImpl
	local self = setmetatable({}, MetricsCollector) :: any

	self.poolName = poolName

	-- Initialize counters
	self._gets = 0
	self._returns = 0
	self._hits = 0
	self._created = 0
	self._destroyed = 0

	-- Lifetime tracking (keep last N lifetimes for averaging)
	self._lifetimeCapacity = Constants.Metrics.LIFETIME_CAPACITY
	self._lifetimes = table.create(self._lifetimeCapacity, 0)
	self._lifetimeIndex = 1

	-- Peak tracking
	self._peakUsage = 0
	self._currentInUse = 0

	-- Batch buffer
	self._pendingGets = 0
	self._pendingReturns = 0
	self._pendingHits = 0
	self._batchSize = batchSize or Constants.Metrics.DEFAULT_BATCH_SIZE

	return self
end

--[[
    Record a Get operation.
    @param wasHit - true if object was available in pool (hit), false if created (miss)
]]
function MetricsCollector.RecordGet(self: MetricsCollectorImpl, wasHit: boolean): ()
	self._pendingGets = self._pendingGets + 1
	if wasHit then
		self._pendingHits = self._pendingHits + 1
	end

	-- Update in-use count
	self._currentInUse = self._currentInUse + 1
	if self._currentInUse > self._peakUsage then
		self._peakUsage = self._currentInUse
	end

	-- Auto-flush if batch is full
	if self._pendingGets + self._pendingReturns >= self._batchSize then
		self:FlushBatch()
	end
end

--[[
    Record a Return operation.
    @param lifetime - How long the object was in use (seconds)
]]
function MetricsCollector.RecordReturn(self: MetricsCollectorImpl, lifetime: number): ()
	self._pendingReturns = self._pendingReturns + 1

	-- Update in-use count
	self._currentInUse = math.max(0, self._currentInUse - 1)

	-- Record lifetime in circular buffer
	self._lifetimes[self._lifetimeIndex] = lifetime
	self._lifetimeIndex = (self._lifetimeIndex % self._lifetimeCapacity) + 1

	-- Auto-flush if batch is full
	if self._pendingGets + self._pendingReturns >= self._batchSize then
		self:FlushBatch()
	end
end

--[[
    Record object creation.
]]
function MetricsCollector.RecordCreate(self: MetricsCollectorImpl): ()
	self._created = self._created + 1
end

--[[
    Record object destruction.
]]
function MetricsCollector.RecordDestroy(self: MetricsCollectorImpl): ()
	self._destroyed = self._destroyed + 1
end

--[[
    Update the current in-use count directly.
    Used for synchronization with actual pool state.
]]
function MetricsCollector.UpdateInUse(self: MetricsCollectorImpl, count: number): ()
	self._currentInUse = count
	if count > self._peakUsage then
		self._peakUsage = count
	end
end

--[[
    Flush pending batch updates to main counters.
]]
function MetricsCollector.FlushBatch(self: MetricsCollectorImpl): ()
	self._gets = self._gets + self._pendingGets
	self._returns = self._returns + self._pendingReturns
	self._hits = self._hits + self._pendingHits

	self._pendingGets = 0
	self._pendingReturns = 0
	self._pendingHits = 0
end

--[[
    Get current metrics for this pool.
    Returns PoolMetrics type as defined in Types.lua
]]
function MetricsCollector.GetMetrics(self: MetricsCollectorImpl): Types.PoolMetrics
	-- Flush any pending updates first
	self:FlushBatch()

	-- Calculate hit rate
	local hitRate = 0
	if self._gets > 0 then
		hitRate = self._hits / self._gets
	end

	-- Calculate average lifetime
	local avgLifetime = 0
	local lifetimeSum = 0
	local lifetimeCount = 0
	for _, lifetime in ipairs(self._lifetimes) do
		if lifetime > 0 then
			lifetimeSum = lifetimeSum + lifetime
			lifetimeCount = lifetimeCount + 1
		end
	end
	if lifetimeCount > 0 then
		avgLifetime = lifetimeSum / lifetimeCount
	end

	return {
		hitRate = hitRate,
		peakUsage = self._peakUsage,
		avgLifetime = avgLifetime,
		currentSize = self._currentInUse,
	}
end

--[[
    Get detailed metrics including all counters.
]]
function MetricsCollector.GetDetailedMetrics(self: MetricsCollectorImpl): DetailedMetrics
	-- Flush any pending updates first
	self:FlushBatch()

	local metrics = self:GetMetrics()

	return {
		gets = self._gets,
		returns = self._returns,
		hits = self._hits,
		created = self._created,
		destroyed = self._destroyed,
		hitRate = metrics.hitRate,
		peakUsage = metrics.peakUsage,
		avgLifetime = metrics.avgLifetime,
		currentInUse = self._currentInUse,
	}
end

--[[
    Reset all metrics to initial state.
]]
function MetricsCollector.Reset(self: MetricsCollectorImpl): ()
	self._gets = 0
	self._returns = 0
	self._hits = 0
	self._created = 0
	self._destroyed = 0

	-- Clear lifetimes
	for i = 1, self._lifetimeCapacity do
		self._lifetimes[i] = 0
	end
	self._lifetimeIndex = 1

	self._peakUsage = 0
	self._currentInUse = 0

	-- Clear batch buffer
	self._pendingGets = 0
	self._pendingReturns = 0
	self._pendingHits = 0
end

--[[
    Destroy the metrics collector and cleanup resources.
    
    ARCHITECTURE: Added proper cleanup method for resource management.
]]
function MetricsCollector.Destroy(self: MetricsCollectorImpl): ()
	self:Reset()
	table.clear(self._lifetimes)
end

return MetricsCollector
