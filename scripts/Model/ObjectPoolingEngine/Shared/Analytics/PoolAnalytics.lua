--!strict
--[[
    PoolAnalytics.lua
    Advanced Object Pooling Engine - Global Analytics System
    
    Tracks global metrics across all pools with per-pool aggregation.
    Uses CircularBuffer for samples to prevent memory leaks.
    Requirements: 9.1-9.7
]]

local Types = require(script.Parent.Parent.Types)
local CircularBuffer = require(script.Parent.Parent.Utils.CircularBuffer)
local MetricsCollector = require(script.Parent.MetricsCollector)
local Constants = require(script.Parent.Parent.Utils.Constants)

-- ============================================================================
-- PoolAnalytics Class
-- ============================================================================

local PoolAnalytics = {}
PoolAnalytics.__index = PoolAnalytics

export type PoolAnalyticsImpl = {
	-- Global metrics (Requirement 9.1)
	totalGets: number,
	totalReturns: number,
	totalCreated: number,
	totalDestroyed: number,

	-- Per-pool collectors
	_collectors: {[string]: MetricsCollector.MetricsCollectorImpl}?,

	-- Sampling (Requirement 9.6)
	_samples: CircularBuffer.CircularBufferImpl<Types.Snapshot>?,
	_sampleInterval: number,
	_lastSampleTime: number,

	-- Batch buffer (Requirement 9.7)
	_pendingUpdates: {PendingUpdate}?,
	_batchThreshold: number,

	-- Methods
	RegisterPool: (self: PoolAnalyticsImpl, poolName: string) -> MetricsCollector.MetricsCollectorImpl?,
	UnregisterPool: (self: PoolAnalyticsImpl, poolName: string) -> (),
	RecordGet: (self: PoolAnalyticsImpl, poolName: string, wasHit: boolean) -> (),
	RecordReturn: (self: PoolAnalyticsImpl, poolName: string, lifetime: number) -> (),
	RecordCreate: (self: PoolAnalyticsImpl, poolName: string) -> (),
	RecordDestroy: (self: PoolAnalyticsImpl, poolName: string) -> (),
	TakeSample: (self: PoolAnalyticsImpl, fps: number, memoryMB: number, poolStats: {[string]: Types.PoolStats}) -> (),
	GetReport: (self: PoolAnalyticsImpl) -> Types.AnalyticsReport,
	GetGlobalStats: (self: PoolAnalyticsImpl) -> Types.GlobalStats,
	GetPoolMetrics: (self: PoolAnalyticsImpl, poolName: string) -> Types.PoolMetrics?,
	FlushPending: (self: PoolAnalyticsImpl) -> (),
	Reset: (self: PoolAnalyticsImpl) -> (),
}

type PendingUpdate = {
	updateType: "get" | "return" | "create" | "destroy",
	poolName: string,
	wasHit: boolean?,
	lifetime: number?,
}

--[[
    Create a new PoolAnalytics instance.
    @param sampleCapacity - Maximum number of samples to keep (default from Constants)
    @param sampleInterval - Minimum seconds between samples (default from Constants)
    @param batchThreshold - Number of updates before auto-flush (default from Constants)
]]
function PoolAnalytics.new(sampleCapacity: number?, sampleInterval: number?, batchThreshold: number?): PoolAnalyticsImpl
	local self = setmetatable({}, PoolAnalytics) :: any

	-- Global metrics
	self.totalGets = 0
	self.totalReturns = 0
	self.totalCreated = 0
	self.totalDestroyed = 0

	-- Per-pool collectors
	self._collectors = {}

	-- Sampling (using Constants for defaults)
	self._samples = CircularBuffer.new(sampleCapacity or Constants.Analytics.DEFAULT_SAMPLE_CAPACITY)
	self._sampleInterval = sampleInterval or Constants.Analytics.DEFAULT_SAMPLE_INTERVAL
	self._lastSampleTime = 0

	-- Batch buffer (using Constants for defaults)
	self._pendingUpdates = {}
	self._batchThreshold = batchThreshold or Constants.Analytics.DEFAULT_BATCH_THRESHOLD

	return self
end

--[[
    Register a pool for metrics collection.
    Returns the MetricsCollector for the pool.
]]
function PoolAnalytics.RegisterPool(self: PoolAnalyticsImpl, poolName: string): MetricsCollector.MetricsCollectorImpl?
	if not self._collectors then
		return nil
	end
	if not self._collectors[poolName] then
		self._collectors[poolName] = MetricsCollector.new(poolName)
	end
	return self._collectors[poolName]
end

--[[
    Unregister a pool from metrics collection.
]]
function PoolAnalytics.UnregisterPool(self: PoolAnalyticsImpl, poolName: string): ()
	if self._collectors then
		self._collectors[poolName] = nil
	end
end

--[[
    Record a Get operation for a pool.
    @param poolName - Name of the pool
    @param wasHit - true if object was available (hit), false if created (miss)
]]
function PoolAnalytics.RecordGet(self: PoolAnalyticsImpl, poolName: string, wasHit: boolean): ()
	if not self._pendingUpdates then
		return
	end

	-- Add to pending updates for batching
	table.insert(self._pendingUpdates, {
		updateType = "get",
		poolName = poolName,
		wasHit = wasHit,
	})

	-- Auto-flush if threshold reached
	if #self._pendingUpdates >= self._batchThreshold then
		self:FlushPending()
	end
end

--[[
    Record a Return operation for a pool.
    @param poolName - Name of the pool
    @param lifetime - How long the object was in use (seconds)
]]
function PoolAnalytics.RecordReturn(self: PoolAnalyticsImpl, poolName: string, lifetime: number): ()
	if not self._pendingUpdates then
		return
	end

	-- Add to pending updates for batching
	table.insert(self._pendingUpdates, {
		updateType = "return",
		poolName = poolName,
		lifetime = lifetime,
	})

	-- Auto-flush if threshold reached
	if #self._pendingUpdates >= self._batchThreshold then
		self:FlushPending()
	end
end

--[[
    Record object creation for a pool.
]]
function PoolAnalytics.RecordCreate(self: PoolAnalyticsImpl, poolName: string): ()
	if not self._pendingUpdates then
		return
	end

	table.insert(self._pendingUpdates, {
		updateType = "create",
		poolName = poolName,
	})

	if #self._pendingUpdates >= self._batchThreshold then
		self:FlushPending()
	end
end

--[[
    Record object destruction for a pool.
]]
function PoolAnalytics.RecordDestroy(self: PoolAnalyticsImpl, poolName: string): ()
	if not self._pendingUpdates then
		return
	end

	table.insert(self._pendingUpdates, {
		updateType = "destroy",
		poolName = poolName,
	})

	if #self._pendingUpdates >= self._batchThreshold then
		self:FlushPending()
	end
end

--[[
    Take a performance sample snapshot.
    Samples are rate-limited by sampleInterval.
]]
function PoolAnalytics.TakeSample(self: PoolAnalyticsImpl, fps: number, memoryMB: number, poolStats: {[string]: Types.PoolStats}): ()
	if not self._samples then
		return
	end

	local currentTime = os.clock()

	-- Rate limit samples
	if currentTime - self._lastSampleTime < self._sampleInterval then
		return
	end

	self._lastSampleTime = currentTime

	local snapshot: Types.Snapshot = {
		timestamp = currentTime,
		fps = fps,
		memoryMB = memoryMB,
		poolStats = poolStats,
	}

	self._samples:Push(snapshot)
end

--[[
    Flush all pending updates to collectors and global counters.
    Includes overflow protection - counters reset at 2^52 to prevent precision loss.
]]
function PoolAnalytics.FlushPending(self: PoolAnalyticsImpl): ()
	-- Safety check for post-Destroy state
	if not self._pendingUpdates then
		return
	end

	-- Overflow protection (Lua numbers lose precision above 2^53)
	local MAX_COUNTER = 4503599627370496 -- 2^52

	for _, update in ipairs(self._pendingUpdates) do
		local collector = self._collectors and self._collectors[update.poolName]

		if update.updateType == "get" then
			self.totalGets = self.totalGets + 1
			if self.totalGets > MAX_COUNTER then
				self.totalGets = 0  -- Reset to prevent precision loss
			end
			if collector then
				collector:RecordGet(update.wasHit or false)
			end
		elseif update.updateType == "return" then
			self.totalReturns = self.totalReturns + 1
			if self.totalReturns > MAX_COUNTER then
				self.totalReturns = 0
			end
			if collector then
				collector:RecordReturn(update.lifetime or 0)
			end
		elseif update.updateType == "create" then
			self.totalCreated = self.totalCreated + 1
			if self.totalCreated > MAX_COUNTER then
				self.totalCreated = 0
			end
			if collector then
				collector:RecordCreate()
			end
		elseif update.updateType == "destroy" then
			self.totalDestroyed = self.totalDestroyed + 1
			if self.totalDestroyed > MAX_COUNTER then
				self.totalDestroyed = 0
			end
			if collector then
				collector:RecordDestroy()
			end
		end
	end

	-- Clear pending updates
	table.clear(self._pendingUpdates)
end

--[[
    Get comprehensive analytics report.
    Returns AnalyticsReport with global stats and samples.
]]
function PoolAnalytics.GetReport(self: PoolAnalyticsImpl): Types.AnalyticsReport
	-- Flush pending updates first
	self:FlushPending()

	return {
		timestamp = os.clock(),
		global = self:GetGlobalStats(),
		samples = self._samples and self._samples:ToArray() or {},
	}
end

--[[
    Get global statistics across all pools.
]]
function PoolAnalytics.GetGlobalStats(self: PoolAnalyticsImpl): Types.GlobalStats
	-- Flush pending updates first
	self:FlushPending()

	-- Calculate overall hit rate
	local overallHitRate = 0
	local totalHits = 0
	local totalObjects = 0

	local poolStats: {[string]: Types.PoolStats} = {}

	-- Safety check for post-Destroy state
	if self._collectors then
		for poolName, collector in pairs(self._collectors) do
			local metrics = collector:GetMetrics()
			local detailed = collector:GetDetailedMetrics()

			totalHits = totalHits + detailed.hits
			totalObjects = totalObjects + detailed.currentInUse

			poolStats[poolName] = {
				name = poolName,
				availableCount = 0, -- Would need pool reference for this
				inUseCount = detailed.currentInUse,
				totalCreated = detailed.created,
				peakUsage = metrics.peakUsage,
				hitRate = metrics.hitRate,
				avgLifetime = metrics.avgLifetime,
			}
		end
	end

	if self.totalGets > 0 then
		overallHitRate = totalHits / self.totalGets
	end

	local poolCount = 0
	if self._collectors then
		for _ in pairs(self._collectors) do
			poolCount = poolCount + 1
		end
	end

	return {
		totalPools = poolCount,
		totalObjects = totalObjects,
		totalGets = self.totalGets,
		totalReturns = self.totalReturns,
		overallHitRate = overallHitRate,
		pools = poolStats,
	}
end

--[[
    Get metrics for a specific pool.
]]
function PoolAnalytics.GetPoolMetrics(self: PoolAnalyticsImpl, poolName: string): Types.PoolMetrics?
	if not self._collectors then
		return nil
	end
	local collector = self._collectors[poolName]
	if collector then
		return collector:GetMetrics()
	end
	return nil
end

--[[
    Reset all analytics to initial state.
]]
function PoolAnalytics.Reset(self: PoolAnalyticsImpl): ()
	self.totalGets = 0
	self.totalReturns = 0
	self.totalCreated = 0
	self.totalDestroyed = 0

	-- Reset all collectors (with nil check for post-Destroy safety)
	if self._collectors then
		for _, collector in pairs(self._collectors) do
			collector:Reset()
		end
	end

	-- Clear samples (with nil check)
	if self._samples then
		self._samples:Clear()
	end
	self._lastSampleTime = 0

	-- Clear pending updates (with nil check)
	if self._pendingUpdates then
		table.clear(self._pendingUpdates)
	end
end

--[[
    Destroy the analytics instance and cleanup all resources.
    Safe to call multiple times.
]]
function PoolAnalytics.Destroy(self: PoolAnalyticsImpl): ()
	-- Safety check - already destroyed
	if not self._collectors then
		return
	end

	-- Destroy all collectors first (before Reset clears them)
	for poolName, collector in pairs(self._collectors) do
		collector:Destroy()
	end

	-- Clear collectors
	table.clear(self._collectors)

	-- Clear samples
	if self._samples then
		self._samples:Clear()
	end

	-- Clear pending updates
	if self._pendingUpdates then
		table.clear(self._pendingUpdates)
	end

	-- Reset counters
	self.totalGets = 0
	self.totalReturns = 0
	self.totalCreated = 0
	self.totalDestroyed = 0
	self._lastSampleTime = 0

	-- Clear references (mark as destroyed)
	self._collectors = nil :: any
	self._samples = nil :: any
	self._pendingUpdates = nil :: any
end

return PoolAnalytics
