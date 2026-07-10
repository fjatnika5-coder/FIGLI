--!strict
--[[
    Types.lua
    Advanced Object Pooling Engine - Type Definitions
    
    This module defines all strict Luau types for the Object Pooling Engine.
    Requirements: 15.1, 12.1-12.6
]]

local Types = {}

-- ============================================================================
-- Strategy Type Enums
-- ============================================================================

export type WarmUpType = "immediate" | "progressive" | "lazy"
export type CleanupType = "threshold" | "ttl" | "lru"
export type GrowthType = "fixed" | "linear" | "exponential"
export type EvictionType = "fifo" | "lifo" | "lru" | "lfu"

-- ============================================================================
-- Configuration Types (Requirements 12.1-12.6)
-- ============================================================================

export type PoolConfig = {
	-- Size (Requirement 12.1)
	initialSize: number,
	maxSize: number?,

	-- Strategies (Requirement 12.2)
	warmUpType: WarmUpType,
	cleanupType: CleanupType,
	growthType: GrowthType,
	evictionType: EvictionType,

	-- Timing (Requirement 12.3)
	objectTTL: number?,
	autoReturnDelay: number?,
	cleanupInterval: number,

	-- Flags (Requirement 12.4)
	enableAnalytics: boolean,
	enableValidation: boolean,
	preloadAsync: boolean,

	-- Callbacks (Requirement 12.5)
	onCreate: ((Instance) -> ())?,
	onAcquire: ((Instance) -> ())?,
	onReturn: ((Instance) -> ())?,
	onDestroy: ((Instance) -> ())?,
}


-- ============================================================================
-- Validation Types
-- ============================================================================

export type ValidationRules = {
	checkParent: boolean?,
	checkDestroyed: boolean?,
	customValidator: ((Instance) -> boolean)?,
}

export type ResetConfig = {
	resetPosition: boolean?,
	resetVelocity: boolean?,
	clearConnections: boolean?,
	clearTweens: boolean?,
	clearAttributes: boolean?,
}

-- ============================================================================
-- Statistics Types (Requirements 2.8, 2.9, 9.1-9.7)
-- ============================================================================

export type PoolStats = {
	name: string,
	availableCount: number,
	inUseCount: number,
	totalCreated: number,
	peakUsage: number,
	hitRate: number,
	avgLifetime: number,
}

export type GlobalStats = {
	totalPools: number,
	totalObjects: number,
	totalGets: number,
	totalReturns: number,
	overallHitRate: number,
	pools: {[string]: PoolStats},
}

export type PoolMetrics = {
	hitRate: number,
	peakUsage: number,
	avgLifetime: number,
	currentSize: number,
}

export type Snapshot = {
	timestamp: number,
	fps: number,
	memoryMB: number,
	poolStats: {[string]: PoolStats},
}

export type AnalyticsReport = {
	timestamp: number,
	global: GlobalStats,
	samples: {Snapshot},
}

export type PerformanceReport = {
	duration: number,
	avgFPS: number,
	minFPS: number,
	maxFPS: number,
	lagSpikes: number,
	memoryPeakMB: number,
}


-- ============================================================================
-- Utility Types
-- ============================================================================

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal = {
	_connections: {{callback: (...any) -> (), once: boolean}},
	Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
	Once: (self: Signal, callback: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

export type Timer = {
	duration: number,
	callback: () -> (),
	_startTime: number,
	_isCancelled: boolean,
	Start: (self: Timer) -> (),
	Cancel: (self: Timer) -> (),
	Reset: (self: Timer) -> (),
	GetRemaining: (self: Timer) -> number,
}

export type CircularBuffer<T> = {
	_buffer: {T},
	_capacity: number,
	_head: number,
	_tail: number,
	_size: number,
	Push: (self: CircularBuffer<T>, value: T) -> (),
	Pop: (self: CircularBuffer<T>) -> T?,
	Peek: (self: CircularBuffer<T>) -> T?,
	Size: (self: CircularBuffer<T>) -> number,
	IsFull: (self: CircularBuffer<T>) -> boolean,
	IsEmpty: (self: CircularBuffer<T>) -> boolean,
}

export type PriorityQueueEntry<T> = {
	priority: number,
	value: T,
}

export type PriorityQueue<T> = {
	_heap: {PriorityQueueEntry<T>},
	_compare: (a: number, b: number) -> boolean,
	Insert: (self: PriorityQueue<T>, value: T, priority: number) -> (),
	ExtractMin: (self: PriorityQueue<T>) -> T?,
	Peek: (self: PriorityQueue<T>) -> T?,
	IsEmpty: (self: PriorityQueue<T>) -> boolean,
	Size: (self: PriorityQueue<T>) -> number,
}


-- ============================================================================
-- Core Component Types (Forward Declarations)
-- ============================================================================

-- Note: These are simplified type hints for forward references.
-- Full implementations will define their own metatables.

export type PooledObjectMetadata = {
	id: string,
	createdAt: number,
	lastUsed: number,
	useCount: number,
}

export type PooledObject = {
	instance: Instance,
	pool: any, -- Forward reference to Pool

	-- Metadata
	id: string,
	createdAt: number,
	lastUsed: number,
	useCount: number,

	-- State
	isActive: boolean,
	isValid: boolean,

	-- Auto-return
	_autoReturnTimer: Timer?,
	_autoReturnDelay: number?,

	-- Lifecycle hooks
	onAcquire: Signal,
	onReturn: Signal,
	onDestroy: Signal,

	-- Methods
	Acquire: (self: PooledObject) -> Instance,
	Return: (self: PooledObject) -> (),
	Destroy: (self: PooledObject) -> (),
	Reset: (self: PooledObject) -> (),
	SetAutoReturn: (self: PooledObject, delay: number) -> (),
	Validate: (self: PooledObject) -> boolean,
}


-- ============================================================================
-- Strategy Types
-- ============================================================================

export type WarmUpStrategy = {
	strategyType: WarmUpType,
	Execute: (self: WarmUpStrategy, pool: any, targetCount: number) -> any, -- Returns Promise
	GetEstimatedTime: (self: WarmUpStrategy, count: number) -> number,
	Cancel: (self: WarmUpStrategy) -> (),
}

export type CleanupStrategy = {
	strategyType: CleanupType,
	ShouldCleanup: (self: CleanupStrategy, pool: any) -> boolean,
	Cleanup: (self: CleanupStrategy, pool: any, targetCount: number?) -> number,
}

export type GrowthStrategy = {
	strategyType: GrowthType,
	CalculateGrowth: (self: GrowthStrategy, currentSize: number, needed: number) -> number,
	CanGrow: (self: GrowthStrategy, pool: any) -> boolean,
}

export type EvictionStrategy = {
	strategyType: EvictionType,
	SelectVictims: (self: EvictionStrategy, pool: any, count: number) -> {PooledObject},
}


-- ============================================================================
-- Pool Type
-- ============================================================================

export type Pool = {
	name: string,
	config: PoolConfig,

	-- Storage
	_available: CircularBuffer<PooledObject>,
	_inUse: {[PooledObject]: boolean},
	_template: Instance | number,

	-- Strategies
	_warmUp: WarmUpStrategy,
	_cleanup: CleanupStrategy,
	_growth: GrowthStrategy,
	_eviction: EvictionStrategy,

	-- Analytics
	_analytics: any, -- MetricsCollector

	-- State
	_totalCreated: number,
	_peakUsage: number,
	_lastCleanup: number,

	-- Methods
	Get: (self: Pool) -> Instance?,
	Return: (self: Pool, object: Instance) -> boolean,
	WarmUp: (self: Pool, count: number) -> any, -- Returns Promise
	Clear: (self: Pool) -> (),
	Resize: (self: Pool, newSize: number) -> (),
	GetStats: (self: Pool) -> PoolStats,
}


-- ============================================================================
-- Analytics Types
-- ============================================================================

export type MetricsCollector = {
	poolName: string,
	_gets: number,
	_returns: number,
	_hits: number,
	_lifetimes: {number},
	RecordGet: (self: MetricsCollector, wasHit: boolean) -> (),
	RecordReturn: (self: MetricsCollector, lifetime: number) -> (),
	GetMetrics: (self: MetricsCollector) -> PoolMetrics,
	Reset: (self: MetricsCollector) -> (),
}

export type PoolAnalytics = {
	-- Global metrics
	totalGets: number,
	totalReturns: number,
	totalCreated: number,
	totalDestroyed: number,

	-- Per-pool metrics
	pools: {[string]: PoolMetrics},

	-- Sampling
	_samples: CircularBuffer<Snapshot>,
	_sampleInterval: number,
	_pendingUpdates: {any},

	-- Methods
	RecordGet: (self: PoolAnalytics, poolName: string, wasHit: boolean) -> (),
	RecordReturn: (self: PoolAnalytics, poolName: string, lifetime: number) -> (),
	GetReport: (self: PoolAnalytics) -> AnalyticsReport,
	Reset: (self: PoolAnalytics) -> (),
}

export type PerformanceMonitor = {
	_isRecording: boolean,
	_frames: number,
	_lastTime: number,
	_currentFPS: number,
	_maxFrameTime: number,
	_connection: RBXScriptConnection?,

	StartRecording: (self: PerformanceMonitor) -> (),
	StopRecording: (self: PerformanceMonitor) -> PerformanceReport,
	GetCurrentFPS: (self: PerformanceMonitor) -> number,
	GetMemoryUsage: (self: PerformanceMonitor) -> number,
}


-- ============================================================================
-- Pool Manager Type
-- ============================================================================

export type PoolManager = {
	-- Public API
	CreatePool: (self: PoolManager, categoryName: string, config: PoolConfig?) -> Pool,
	GetPool: (self: PoolManager, categoryName: string) -> Pool?,
	Get: (self: PoolManager, categoryName: string, template: Instance | number) -> Instance?,
	Return: (self: PoolManager, object: Instance) -> boolean,
	Shutdown: (self: PoolManager) -> (),
	GetGlobalStats: (self: PoolManager) -> GlobalStats,

	-- Internal
	_pools: {[string]: Pool},
	_defaultConfig: PoolConfig,
	_analytics: PoolAnalytics,
	_isInitialized: boolean,
	_requestCache: {[string]: Pool},
}

-- ============================================================================
-- Registry Type
-- ============================================================================

export type PoolRegistry = {
	_objectToPool: {[Instance]: Pool},
	_objectToWrapper: {[Instance]: PooledObject},
	Register: (instance: Instance, pool: Pool, wrapper: PooledObject) -> (),
	Unregister: (instance: Instance) -> (),
	GetPool: (instance: Instance) -> Pool?,
	GetWrapper: (instance: Instance) -> PooledObject?,
	Clear: () -> (),
}

return Types
