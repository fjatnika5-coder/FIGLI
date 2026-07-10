--!strict
--[[
    PooledObject.lua
    Advanced Object Pooling Engine - Pooled Object Wrapper
    
    Wraps an Instance with metadata, lifecycle hooks, and auto-return functionality.
    Provides the core abstraction for pooled objects.
    
    Requirements: 3.1-3.7
]]

local HttpService = game:GetService("HttpService")

local Types = require(script.Parent.Parent.Types)
local Signal = require(script.Parent.Parent.Utils.Signal)
local TimerModule = require(script.Parent.Parent.Utils.Timer)
local ObjectValidator = require(script.Parent.Parent.Utils.ObjectValidator)
local PoolRegistry = require(script.Parent.PoolRegistry)

local Timer = TimerModule.Timer

type Pool = Types.Pool
type SignalImpl = Signal.SignalImpl
type TimerImpl = TimerModule.TimerImpl

-- ============================================================================
-- PooledObject Class
-- ============================================================================

local PooledObject = {}
PooledObject.__index = PooledObject

export type PooledObjectImpl = {
	-- Core references
	instance: Instance,
	pool: Pool?,

	-- Metadata (Requirement 3.1)
	id: string,
	createdAt: number,
	lastUsed: number,
	useCount: number,

	-- State
	isActive: boolean,
	isValid: boolean,

	-- Auto-return (Requirement 3.4)
	_autoReturnTimer: TimerImpl?,
	_autoReturnDelay: number?,

	-- Default state for reset
	_defaultCFrame: CFrame?,

	-- Lifecycle hooks (Requirement 3.2, 3.3, 3.7)
	onAcquire: SignalImpl,
	onReturn: SignalImpl,
	onDestroy: SignalImpl,

	-- Methods
	Acquire: (self: PooledObjectImpl) -> Instance,
	Return: (self: PooledObjectImpl) -> (),
	Destroy: (self: PooledObjectImpl) -> (),
	Reset: (self: PooledObjectImpl) -> (),
	SetAutoReturn: (self: PooledObjectImpl, delay: number) -> (),
	CancelAutoReturn: (self: PooledObjectImpl) -> (),
	Validate: (self: PooledObjectImpl) -> boolean,
	ValidateForReturn: (self: PooledObjectImpl) -> boolean,
	GetMetadata: (self: PooledObjectImpl) -> Types.PooledObjectMetadata,
}

--[[
    Create a new PooledObject wrapper around an Instance.
    
    @param instance - The Instance to wrap
    @param pool - The Pool that owns this object (optional, can be set later)
    @return PooledObjectImpl - The new PooledObject wrapper
    
    Requirement 3.1: Wrap Instance with id, createdAt, lastUsed, useCount metadata
]]
function PooledObject.new(instance: Instance, pool: Pool?): PooledObjectImpl
	local self = setmetatable({}, PooledObject) :: any

	-- Core references
	self.instance = instance
	self.pool = pool

	-- Metadata (Requirement 3.1)
	self.id = HttpService:GenerateGUID(false)
	self.createdAt = os.clock()
	self.lastUsed = self.createdAt
	self.useCount = 0

	-- State
	self.isActive = false
	self.isValid = true

	-- Auto-return
	self._autoReturnTimer = nil
	self._autoReturnDelay = nil

	-- Store default CFrame for reset
	self._defaultCFrame = nil
	if instance:IsA("BasePart") then
		self._defaultCFrame = (instance :: BasePart).CFrame
	elseif instance:IsA("Model") and (instance :: Model).PrimaryPart then
		self._defaultCFrame = (instance :: Model):GetPivot()
	end

	-- Lifecycle hooks (Signals)
	self.onAcquire = Signal.new()
	self.onReturn = Signal.new()
	self.onDestroy = Signal.new()

	-- Register with PoolRegistry if pool is provided
	if pool then
		PoolRegistry.Register(instance, pool, self)
	end

	return self
end

--[[
    Acquire the object for use.
    
    - Marks isActive = true
    - Updates lastUsed to current time
    - Increments useCount
    - Fires onAcquire signal
    
    @return Instance - The wrapped Instance
    
    Requirement 3.2: Mark isActive=true, update lastUsed, increment useCount, fire onAcquire
]]
function PooledObject.Acquire(self: PooledObjectImpl): Instance
	if not self.isValid then
		warn("[PooledObject] Cannot acquire invalid object: " .. self.id)
		return self.instance
	end

	if self.isActive then
		warn("[PooledObject] Object already active: " .. self.id)
		return self.instance
	end

	-- Update state (Requirement 3.2)
	self.isActive = true
	self.lastUsed = os.clock()
	self.useCount = self.useCount + 1

	-- Fire lifecycle hook
	self.onAcquire:Fire(self.instance)

	return self.instance
end

--[[
    Return the object to the pool.
    
    - Marks isActive = false
    - Cancels any auto-return timer
    - Fires onReturn signal
    
    Requirement 3.3: Mark isActive=false and fire onReturn signal
]]
function PooledObject.Return(self: PooledObjectImpl): ()
	if not self.isValid then
		warn("[PooledObject] Cannot return invalid object: " .. self.id)
		return
	end

	if not self.isActive then
		-- Already returned, no-op
		return
	end

	-- Cancel auto-return timer if active
	self:CancelAutoReturn()

	-- Update state (Requirement 3.3)
	self.isActive = false

	-- Fire lifecycle hook
	self.onReturn:Fire(self.instance)
end

--[[
    Destroy the pooled object.
    
    - Marks isValid = false
    - Cancels any auto-return timer
    - Fires onDestroy signal
    - Unregisters from PoolRegistry
    - Destroys the Instance
    
    Requirement 3.7: Cleanup and fire onDestroy signal
    Clears all references to help GC.
]]
function PooledObject.Destroy(self: PooledObjectImpl): ()
	if not self.isValid then
		-- Already destroyed
		return
	end

	-- Mark as invalid
	self.isValid = false
	self.isActive = false

	-- Cancel auto-return timer
	self:CancelAutoReturn()

	-- Fire lifecycle hook before cleanup
	self.onDestroy:Fire(self.instance)

	-- Disconnect all signal connections
	self.onAcquire:DisconnectAll()
	self.onReturn:DisconnectAll()
	self.onDestroy:DisconnectAll()

	-- Unregister from PoolRegistry
	PoolRegistry.Unregister(self.instance)

	-- Destroy the Instance
	if self.instance then
		self.instance:Destroy()
	end

	-- Clear all references to help GC
	self.instance = nil :: any
	self.pool = nil
	self._defaultCFrame = nil
	self.onAcquire = nil :: any
	self.onReturn = nil :: any
	self.onDestroy = nil :: any
end

--[[
    Reset the object to its default state.
    
    Uses ObjectValidator to reset position, velocity, attributes, etc.
    
    Requirement 3.6: Restore the Instance to default state
]]
function PooledObject.Reset(self: PooledObjectImpl): ()
	if not self.isValid then
		warn("[PooledObject] Cannot reset invalid object: " .. self.id)
		return
	end

	-- Use ObjectValidator to reset the instance
	ObjectValidator.Reset(self.instance, nil, self._defaultCFrame)
end

--[[
    Set up automatic return after a delay.
    
    @param delay - Seconds until auto-return
    
    Requirement 3.4: Schedule automatic return after delay seconds
    Only calls pool:Return() which handles everything internally.
]]
function PooledObject.SetAutoReturn(self: PooledObjectImpl, delay: number): ()
	if not self.isValid then
		warn("[PooledObject] Cannot set auto-return on invalid object: " .. self.id)
		return
	end

	if delay <= 0 then
		warn("[PooledObject] Auto-return delay must be positive: " .. tostring(delay))
		return
	end

	-- Cancel existing timer if any
	self:CancelAutoReturn()

	-- Store the delay
	self._autoReturnDelay = delay

	-- Create and start new timer
	self._autoReturnTimer = Timer.new(delay, function()
		-- Only auto-return if still active and valid
		if self.isValid and self.isActive and self.pool then
			-- Only call pool:Return() - it will handle calling self:Return() internally
			-- This prevents double-return bug where object was added to _available twice
			self.pool:Return(self.instance)
		end
	end)

	self._autoReturnTimer:Start()
end

--[[
    Cancel any pending auto-return timer.
]]
function PooledObject.CancelAutoReturn(self: PooledObjectImpl): ()
	if self._autoReturnTimer then
		self._autoReturnTimer:Cancel()
		self._autoReturnTimer = nil
	end
	self._autoReturnDelay = nil
end

--[[
    Validate the object.
    
    Checks:
    - Instance.Parent exists
    - Instance is not destroyed
    - Object is not in another pool
    
    @return boolean - True if valid
    
    Requirement 3.5: Check Instance.Parent exists, not destroyed, not in another pool
    Checks for nil instance before validation.
]]
function PooledObject.Validate(self: PooledObjectImpl): boolean
	if not self.isValid then
		return false
	end

	-- Check if instance reference is still valid
	if not self.instance then
		self.isValid = false
		return false
	end

	-- Use ObjectValidator for basic validation
	local isValid, errorMsg = ObjectValidator.Validate(self.instance, {
		checkParent = true,
		checkDestroyed = true,
	})

	if not isValid then
		self.isValid = false
		return false
	end

	-- Check if registered to correct pool
	local registeredPool = PoolRegistry.GetPool(self.instance)
	if registeredPool ~= nil and registeredPool ~= self.pool then
		-- Object is registered to a different pool
		self.isValid = false
		return false
	end

	return true
end

--[[
    Validate the object for returning to pool.
    
    Same as Validate() but skips the Parent check.
    When returning objects to the pool, Parent may legitimately be nil
    because the pool will unparent/reparent the object itself.
    
    Checks:
    - Instance is not destroyed
    - Object is not in another pool
    
    @return boolean - True if valid for return
]]
function PooledObject.ValidateForReturn(self: PooledObjectImpl): boolean
	if not self.isValid then
		return false
	end

	-- Check if instance reference is still valid
	if not self.instance then
		self.isValid = false
		return false
	end

	-- Use ObjectValidator WITHOUT checkParent (parent may be nil when returning)
	local isValid, errorMsg = ObjectValidator.Validate(self.instance, {
		checkParent = false,
		checkDestroyed = true,
	})

	if not isValid then
		self.isValid = false
		return false
	end

	-- Check if registered to correct pool
	local registeredPool = PoolRegistry.GetPool(self.instance)
	if registeredPool ~= nil and registeredPool ~= self.pool then
		-- Object is registered to a different pool
		self.isValid = false
		return false
	end

	return true
end

--[[
    Get the metadata for this pooled object.
    
    @return PooledObjectMetadata - The metadata
]]
function PooledObject.GetMetadata(self: PooledObjectImpl): Types.PooledObjectMetadata
	return {
		id = self.id,
		createdAt = self.createdAt,
		lastUsed = self.lastUsed,
		useCount = self.useCount,
	}
end

--[[
    Set the pool reference.
    Used when the pool is not known at construction time.
    
    @param pool - The Pool that owns this object
]]
function PooledObject.SetPool(self: PooledObjectImpl, pool: Pool): ()
	self.pool = pool

	-- Register with PoolRegistry
	PoolRegistry.Register(self.instance, pool, self)
end

--[[
    Check if the object is currently active (in use).
    
    @return boolean - True if active
]]
function PooledObject.IsActive(self: PooledObjectImpl): boolean
	return self.isActive
end

--[[
    Check if the object is valid (not destroyed).
    
    @return boolean - True if valid
]]
function PooledObject.IsValid(self: PooledObjectImpl): boolean
	return self.isValid
end

--[[
    Get the time since last use in seconds.
    
    @return number - Seconds since last use
]]
function PooledObject.GetIdleTime(self: PooledObjectImpl): number
	return os.clock() - self.lastUsed
end

--[[
    Get remaining auto-return time in seconds.
    
    @return number - Seconds remaining, or 0 if no auto-return set
]]
function PooledObject.GetAutoReturnRemaining(self: PooledObjectImpl): number
	if self._autoReturnTimer then
		return self._autoReturnTimer:GetRemaining()
	end
	return 0
end

return PooledObject
