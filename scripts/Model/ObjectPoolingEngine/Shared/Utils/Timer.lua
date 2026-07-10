--!strict
--[[
    Timer.lua
    Advanced Object Pooling Engine - Timer System
    
    Provides Timer class and TimerManager for efficient timer management.
    Uses single Heartbeat connection for all timers (batch processing).
    Requirements: 11.5, 11.6
]]

local RunService = game:GetService("RunService")

-- ============================================================================
-- Forward declaration (TimerManager is defined below, but Timer.Start needs it)
-- ============================================================================
local TimerManager

-- ============================================================================
-- Timer Class
-- ============================================================================

local Timer = {}
Timer.__index = Timer

export type TimerImpl = {
	duration: number,
	callback: () -> (),
	_startTime: number,
	_isCancelled: boolean,
	_isRunning: boolean,
	_manager: TimerManagerImpl?,
	Start: (self: TimerImpl) -> (),
	Cancel: (self: TimerImpl) -> (),
	Reset: (self: TimerImpl) -> (),
	GetRemaining: (self: TimerImpl) -> number,
	IsRunning: (self: TimerImpl) -> boolean,
}

function Timer.new(duration: number, callback: () -> ()): TimerImpl
	local self = setmetatable({}, Timer) :: any
	self.duration = duration
	self.callback = callback
	self._startTime = 0
	self._isCancelled = false
	self._isRunning = false
	self._manager = nil
	return self
end

--[[
    Start the timer. Registers with TimerManager for batch processing.
]]
function Timer.Start(self: TimerImpl): ()
	if self._isRunning then
		return
	end

	self._startTime = os.clock()
	self._isCancelled = false
	self._isRunning = true

	-- Register with the global TimerManager
	TimerManager._registerTimer(self)
end

--[[
    Cancel the timer. Removes from TimerManager.
]]
function Timer.Cancel(self: TimerImpl): ()
	if not self._isRunning then
		return
	end

	self._isCancelled = true
	self._isRunning = false

	-- Unregister from TimerManager
	TimerManager._unregisterTimer(self)

	-- Clear callback reference to prevent memory leak
	self.callback = nil :: any
end

--[[
    Reset the timer. Restarts the countdown from the beginning.
    Preserves callback reference during reset.
]]
function Timer.Reset(self: TimerImpl): ()
	local wasRunning = self._isRunning
	local savedCallback = self.callback  -- Save callback before Cancel clears it

	if wasRunning then
		-- Manually stop without clearing callback
		self._isCancelled = true
		self._isRunning = false
		TimerManager._unregisterTimer(self)
	end

	-- Restore callback if it was cleared
	if savedCallback then
		self.callback = savedCallback
	end

	self._isCancelled = false

	if wasRunning then
		self:Start()
	end
end

--[[
    Get remaining time in seconds.
    Returns 0 if timer is not running or has expired.
]]
function Timer.GetRemaining(self: TimerImpl): number
	if not self._isRunning or self._isCancelled then
		return 0
	end

	local elapsed = os.clock() - self._startTime
	local remaining = self.duration - elapsed

	return math.max(0, remaining)
end

--[[
    Check if the timer is currently running.
]]
function Timer.IsRunning(self: TimerImpl): boolean
	return self._isRunning and not self._isCancelled
end

-- ============================================================================
-- TimerManager (Singleton) - Single Heartbeat connection for all timers
-- ============================================================================

export type TimerManagerImpl = {
	_timers: {TimerImpl},
	_connection: RBXScriptConnection?,
	_isRunning: boolean,
	_registerTimer: (timer: TimerImpl) -> (),
	_unregisterTimer: (timer: TimerImpl) -> (),
	_start: () -> (),
	_stop: () -> (),
	GetActiveTimerCount: () -> number,
}

TimerManager = {
	_timers = {},
	_connection = nil,
	_isRunning = false,
} :: any

--[[
    Register a timer with the manager.
    Starts the Heartbeat connection if not already running.
]]
function TimerManager._registerTimer(timer: TimerImpl): ()
	-- Check if already registered
	for _, t in ipairs(TimerManager._timers) do
		if t == timer then
			return
		end
	end

	table.insert(TimerManager._timers, timer)
	timer._manager = TimerManager

	-- Start the manager if not running
	if not TimerManager._isRunning then
		TimerManager._start()
	end
end

--[[
    Unregister a timer from the manager.
    Stops the Heartbeat connection if no timers remain.
]]
function TimerManager._unregisterTimer(timer: TimerImpl): ()
	for i = #TimerManager._timers, 1, -1 do
		if TimerManager._timers[i] == timer then
			table.remove(TimerManager._timers, i)
			timer._manager = nil
			break
		end
	end

	-- Stop the manager if no timers remain
	if #TimerManager._timers == 0 and TimerManager._isRunning then
		TimerManager._stop()
	end
end

--[[
    Start the Heartbeat connection for batch timer processing.
]]
function TimerManager._start(): ()
	if TimerManager._isRunning then
		return
	end

	TimerManager._isRunning = true

	TimerManager._connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local currentTime = os.clock()
		local timersToFire: {TimerImpl} = {}

		-- Check all timers and collect expired ones
		for i = #TimerManager._timers, 1, -1 do
			local timer = TimerManager._timers[i]

			if timer._isCancelled then
				-- Remove cancelled timers
				table.remove(TimerManager._timers, i)
				timer._manager = nil
			elseif currentTime - timer._startTime >= timer.duration then
				-- Timer expired - collect for firing
				table.insert(timersToFire, timer)
				table.remove(TimerManager._timers, i)
				timer._isRunning = false
				timer._manager = nil
			end
		end

		-- Fire callbacks after iteration (safe from modification during iteration)
		-- Uses pcall to prevent one bad callback from breaking others
		for _, timer in ipairs(timersToFire) do
			if not timer._isCancelled and timer.callback then
				local success, err = pcall(timer.callback)
				if not success then
					warn("[Timer] Callback error: " .. tostring(err))
				end
			end
		end

		-- Stop if no timers remain
		if #TimerManager._timers == 0 then
			TimerManager._stop()
		end
	end)
end

--[[
    Stop the Heartbeat connection.
]]
function TimerManager._stop(): ()
	if not TimerManager._isRunning then
		return
	end

	TimerManager._isRunning = false

	if TimerManager._connection then
		TimerManager._connection:Disconnect()
		TimerManager._connection = nil
	end
end

--[[
    Get the number of active timers.
    Useful for testing and debugging.
]]
function TimerManager.GetActiveTimerCount(): number
	return #TimerManager._timers
end

--[[
    Clear all timers and stop the manager.
    ARCHITECTURE: Added for proper cleanup during shutdown.
]]
function TimerManager.ClearAll(): ()
	-- Cancel all timers
	for _, timer in ipairs(TimerManager._timers) do
		timer._isCancelled = true
		timer._isRunning = false
		timer._manager = nil
		timer.callback = nil :: any  -- Clear callback reference
	end

	-- Clear the timers array
	table.clear(TimerManager._timers)

	-- Stop the manager
	TimerManager._stop()
end

-- ============================================================================
-- Module Export
-- ============================================================================

return {
	Timer = Timer,
	TimerManager = TimerManager,
}
