--!strict
--[[
    PerformanceMonitor.lua
    Advanced Object Pooling Engine - Real-time Performance Monitoring
    
    Tracks FPS, memory usage, and lag spikes via Heartbeat connection.
    Requirements: 10.1-10.7
]]

local RunService = game:GetService("RunService")

local Types = require(script.Parent.Parent.Types)

-- ============================================================================
-- PerformanceMonitor Class
-- ============================================================================

local PerformanceMonitor = {}
PerformanceMonitor.__index = PerformanceMonitor

export type PerformanceMonitorImpl = {
	-- State
	_isRecording: boolean,
	_connection: RBXScriptConnection?,

	-- FPS tracking (Requirement 10.1)
	_frames: number,
	_lastTime: number,
	_currentFPS: number,
	_fpsUpdateInterval: number,
	_lastFPSUpdate: number,

	-- Frame time tracking
	_frameTimeSum: number,
	_frameTimeCount: number,
	_maxFrameTime: number,
	_minFrameTime: number,

	-- Recording data
	_recordingStartTime: number,
	_recordedFPS: {number},
	_lagSpikes: number,
	_lagSpikeThreshold: number,

	-- Memory tracking (Requirement 10.2)
	_memoryPeakMB: number,
	_lastMemoryMB: number,

	-- Pool size tracking for memory estimation
	_poolSizes: {[string]: number},
	_estimatedObjectMemoryKB: number,

	-- Methods
	StartRecording: (self: PerformanceMonitorImpl) -> (),
	StopRecording: (self: PerformanceMonitorImpl) -> Types.PerformanceReport,
	GetCurrentFPS: (self: PerformanceMonitorImpl) -> number,
	GetMemoryUsage: (self: PerformanceMonitorImpl) -> number,
	UpdatePoolSize: (self: PerformanceMonitorImpl, poolName: string, size: number) -> (),
	SetLagSpikeThreshold: (self: PerformanceMonitorImpl, thresholdMs: number) -> (),
	IsRecording: (self: PerformanceMonitorImpl) -> boolean,
	GetFrameTime: (self: PerformanceMonitorImpl) -> number,
	Destroy: (self: PerformanceMonitorImpl) -> (),
}

-- Default estimated memory per pooled object (in KB)
local DEFAULT_OBJECT_MEMORY_KB = 0.5

-- Default lag spike threshold (in seconds) - 50ms = 20 FPS frame
local DEFAULT_LAG_SPIKE_THRESHOLD = 0.05

--[[
    Create a new PerformanceMonitor instance.
    @param estimatedObjectMemoryKB - Estimated memory per pooled object in KB (default: 0.5)
]]
function PerformanceMonitor.new(estimatedObjectMemoryKB: number?): PerformanceMonitorImpl
	local self = setmetatable({}, PerformanceMonitor) :: any

	-- State
	self._isRecording = false
	self._connection = nil

	-- FPS tracking
	self._frames = 0
	self._lastTime = os.clock()
	self._currentFPS = 60 -- Default assumption
	self._fpsUpdateInterval = 0.5 -- Update FPS every 0.5 seconds
	self._lastFPSUpdate = os.clock()

	-- Frame time tracking
	self._frameTimeSum = 0
	self._frameTimeCount = 0
	self._maxFrameTime = 0
	self._minFrameTime = math.huge

	-- Recording data
	self._recordingStartTime = 0
	self._recordedFPS = {}
	self._lagSpikes = 0
	self._lagSpikeThreshold = DEFAULT_LAG_SPIKE_THRESHOLD

	-- Memory tracking
	self._memoryPeakMB = 0
	self._lastMemoryMB = 0

	-- Pool size tracking
	self._poolSizes = {}
	self._estimatedObjectMemoryKB = estimatedObjectMemoryKB or DEFAULT_OBJECT_MEMORY_KB

	-- Start passive FPS monitoring
	self:_startMonitoring()

	return self
end

--[[
    Internal: Start the Heartbeat connection for FPS monitoring.
]]
function PerformanceMonitor._startMonitoring(self: PerformanceMonitorImpl): ()
	if self._connection then
		return
	end

	self._lastTime = os.clock()
	self._lastFPSUpdate = os.clock()

	self._connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:_onHeartbeat(deltaTime)
	end)
end

--[[
    Internal: Handle each Heartbeat frame.
]]
function PerformanceMonitor._onHeartbeat(self: PerformanceMonitorImpl, deltaTime: number): ()
	local currentTime = os.clock()

	-- Track frame count
	self._frames = self._frames + 1

	-- Track frame time for lag spike detection (Requirement 10.3)
	self._frameTimeSum = self._frameTimeSum + deltaTime
	self._frameTimeCount = self._frameTimeCount + 1

	if deltaTime > self._maxFrameTime then
		self._maxFrameTime = deltaTime
	end
	if deltaTime < self._minFrameTime then
		self._minFrameTime = deltaTime
	end

	-- Detect lag spike
	if self._isRecording and deltaTime > self._lagSpikeThreshold then
		self._lagSpikes = self._lagSpikes + 1
	end

	-- Update FPS calculation periodically
	local timeSinceLastUpdate = currentTime - self._lastFPSUpdate
	if timeSinceLastUpdate >= self._fpsUpdateInterval then
		self._currentFPS = self._frames / timeSinceLastUpdate
		self._frames = 0
		self._lastFPSUpdate = currentTime

		-- Record FPS if recording
		if self._isRecording then
			table.insert(self._recordedFPS, self._currentFPS)

			-- Update memory peak
			local currentMemory = self:GetMemoryUsage()
			if currentMemory > self._memoryPeakMB then
				self._memoryPeakMB = currentMemory
			end
		end
	end

	self._lastTime = currentTime
end

--[[
    Start recording performance metrics.
    Requirement 10.4
]]
function PerformanceMonitor.StartRecording(self: PerformanceMonitorImpl): ()
	if self._isRecording then
		return
	end

	self._isRecording = true
	self._recordingStartTime = os.clock()

	-- Reset recording data
	table.clear(self._recordedFPS)
	self._lagSpikes = 0
	self._memoryPeakMB = self:GetMemoryUsage()
	self._maxFrameTime = 0
	self._minFrameTime = math.huge
	self._frameTimeSum = 0
	self._frameTimeCount = 0
end

--[[
    Stop recording and return performance report.
    Requirement 10.5
]]
function PerformanceMonitor.StopRecording(self: PerformanceMonitorImpl): Types.PerformanceReport
	local duration = os.clock() - self._recordingStartTime

	self._isRecording = false

	-- Calculate FPS statistics
	local avgFPS = 0
	local minFPS = math.huge
	local maxFPS = 0

	if #self._recordedFPS > 0 then
		local sum = 0
		for _, fps in ipairs(self._recordedFPS) do
			sum = sum + fps
			if fps < minFPS then minFPS = fps end
			if fps > maxFPS then maxFPS = fps end
		end
		avgFPS = sum / #self._recordedFPS
	else
		-- No samples recorded, use current FPS
		avgFPS = self._currentFPS
		minFPS = self._currentFPS
		maxFPS = self._currentFPS
	end

	-- Handle case where no frames were recorded
	if minFPS == math.huge then
		minFPS = 0
	end

	return {
		duration = duration,
		avgFPS = avgFPS,
		minFPS = minFPS,
		maxFPS = maxFPS,
		lagSpikes = self._lagSpikes,
		memoryPeakMB = self._memoryPeakMB,
	}
end

--[[
    Get current FPS value.
    Requirement 10.6
]]
function PerformanceMonitor.GetCurrentFPS(self: PerformanceMonitorImpl): number
	return self._currentFPS
end

--[[
    Get estimated memory usage in MB.
    Requirement 10.7
    
    Estimates memory based on pool sizes and estimated object memory.
    Also includes Lua heap memory if available.
]]
function PerformanceMonitor.GetMemoryUsage(self: PerformanceMonitorImpl): number
	-- Calculate pool-based memory estimate
	local totalObjects = 0
	for _, size in pairs(self._poolSizes) do
		totalObjects = totalObjects + size
	end

	local poolMemoryMB = (totalObjects * self._estimatedObjectMemoryKB) / 1024

	-- Try to get actual Lua memory usage
	local luaMemoryMB = 0
	local success, result = pcall(function()
		return collectgarbage("count") / 1024
	end)

	if success then
		luaMemoryMB = result
	end

	-- Return the larger of the two estimates
	self._lastMemoryMB = math.max(poolMemoryMB, luaMemoryMB)
	return self._lastMemoryMB
end

--[[
    Update the tracked size of a pool for memory estimation.
    @param poolName - Name of the pool
    @param size - Current total size (available + in-use)
]]
function PerformanceMonitor.UpdatePoolSize(self: PerformanceMonitorImpl, poolName: string, size: number): ()
	self._poolSizes[poolName] = size
end

--[[
    Set the threshold for lag spike detection.
    @param thresholdMs - Threshold in milliseconds (default: 50ms)
]]
function PerformanceMonitor.SetLagSpikeThreshold(self: PerformanceMonitorImpl, thresholdMs: number): ()
	self._lagSpikeThreshold = thresholdMs / 1000 -- Convert to seconds
end

--[[
    Check if currently recording.
]]
function PerformanceMonitor.IsRecording(self: PerformanceMonitorImpl): boolean
	return self._isRecording
end

--[[
    Get the average frame time in seconds.
]]
function PerformanceMonitor.GetFrameTime(self: PerformanceMonitorImpl): number
	if self._frameTimeCount > 0 then
		return self._frameTimeSum / self._frameTimeCount
	end
	return 1 / 60 -- Default to 60 FPS frame time
end

--[[
    Cleanup and disconnect the Heartbeat connection.
    Clears all internal references for proper GC.
]]
function PerformanceMonitor.Destroy(self: PerformanceMonitorImpl): ()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	self._isRecording = false
	table.clear(self._recordedFPS)
	table.clear(self._poolSizes)

	-- Clear array references
	self._recordedFPS = nil :: any
	self._poolSizes = nil :: any
end

return PerformanceMonitor
