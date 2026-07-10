--!strict
--[[
    PoolRegistry.lua
    Advanced Object Pooling Engine - Pool Registry
    
    Static module for fast Instance → Pool/PooledObject lookup.
    Provides O(1) access for returning objects to their correct pools.
    
    Requirements: 4.1-4.5
]]

local Types = require(script.Parent.Parent.Types)

type Pool = Types.Pool
type PooledObject = Types.PooledObject

-- ============================================================================
-- PoolRegistry Module (Static)
-- ============================================================================

local PoolRegistry = {}

-- Internal maps for O(1) lookup (Requirement 4.1)
local _objectToPool: {[Instance]: Pool} = {}
local _objectToWrapper: {[Instance]: PooledObject} = {}

--[[
    Register an Instance with its Pool and PooledObject wrapper.
    
    @param instance - The Instance to register
    @param pool - The Pool that owns this instance
    @param wrapper - The PooledObject wrapper for this instance
    
    Requirement 4.2: Store the mappings for fast lookup
]]
function PoolRegistry.Register(instance: Instance, pool: Pool, wrapper: PooledObject): ()
	if instance == nil then
		warn("[PoolRegistry] Cannot register nil instance")
		return
	end

	_objectToPool[instance] = pool
	_objectToWrapper[instance] = wrapper
end

--[[
    Unregister an Instance, removing all mappings.
    
    @param instance - The Instance to unregister
    
    Requirement 4.3: Remove the mappings when object is destroyed
]]
function PoolRegistry.Unregister(instance: Instance): ()
	if instance == nil then
		return
	end

	_objectToPool[instance] = nil
	_objectToWrapper[instance] = nil
end

--[[
    Get the Pool that owns an Instance.
    
    @param instance - The Instance to look up
    @return Pool? - The Pool or nil if not found
    
    Requirement 4.4: Return the Pool in O(1) time
]]
function PoolRegistry.GetPool(instance: Instance): Pool?
	if instance == nil then
		return nil
	end

	return _objectToPool[instance]
end

--[[
    Get the PooledObject wrapper for an Instance.
    
    @param instance - The Instance to look up
    @return PooledObject? - The wrapper or nil if not found
    
    Requirement 4.5: Return the PooledObject in O(1) time
]]
function PoolRegistry.GetWrapper(instance: Instance): PooledObject?
	if instance == nil then
		return nil
	end

	return _objectToWrapper[instance]
end

--[[
    Clear all registry mappings.
    Used during shutdown or testing.
]]
function PoolRegistry.Clear(): ()
	table.clear(_objectToPool)
	table.clear(_objectToWrapper)
end

--[[
    Get the count of registered objects.
    Useful for debugging and testing.
    
    @return number - The count of registered instances
]]
function PoolRegistry.GetCount(): number
	local count = 0
	for _ in pairs(_objectToPool) do
		count = count + 1
	end
	return count
end

--[[
    Check if an Instance is registered.
    
    @param instance - The Instance to check
    @return boolean - True if registered
]]
function PoolRegistry.IsRegistered(instance: Instance): boolean
	if instance == nil then
		return false
	end

	return _objectToPool[instance] ~= nil
end

return PoolRegistry
