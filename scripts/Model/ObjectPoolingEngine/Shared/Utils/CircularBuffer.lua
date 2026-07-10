--!strict
--[[
    CircularBuffer.lua
    Advanced Object Pooling Engine - Circular Buffer Data Structure
    
    Pre-allocated fixed-capacity buffer with O(1) push/pop operations.
    Used for _available storage in Pool for efficient object management.
    Requirements: 2.10
]]

-- ============================================================================
-- CircularBuffer Class
-- ============================================================================

local CircularBuffer = {}
CircularBuffer.__index = CircularBuffer

export type CircularBufferImpl<T> = {
	_buffer: {T?},
	_capacity: number,
	_head: number,  -- Points to next write position
	_tail: number,  -- Points to next read position
	_size: number,
	Push: (self: CircularBufferImpl<T>, value: T) -> boolean,
	Pop: (self: CircularBufferImpl<T>) -> T?,
	Peek: (self: CircularBufferImpl<T>) -> T?,
	Size: (self: CircularBufferImpl<T>) -> number,
	Capacity: (self: CircularBufferImpl<T>) -> number,
	IsFull: (self: CircularBufferImpl<T>) -> boolean,
	IsEmpty: (self: CircularBufferImpl<T>) -> boolean,
	Clear: (self: CircularBufferImpl<T>) -> (),
	ToArray: (self: CircularBufferImpl<T>) -> {T},
}

--[[
    Create a new CircularBuffer with the specified capacity.
    Pre-allocates the internal buffer for O(1) operations.
]]
function CircularBuffer.new<T>(capacity: number): CircularBufferImpl<T>
	assert(capacity > 0, "CircularBuffer capacity must be greater than 0")

	local self = setmetatable({}, CircularBuffer) :: any

	-- Pre-allocate buffer with nil values
	self._buffer = table.create(capacity)
	self._capacity = capacity
	self._head = 1  -- Next write position
	self._tail = 1  -- Next read position
	self._size = 0

	return self
end

--[[
    Push a value to the buffer.
    Returns true if successful, false if buffer is full.
    O(1) operation.
    
    If buffer is full, caller should handle cleanup.
]]
function CircularBuffer.Push<T>(self: CircularBufferImpl<T>, value: T): boolean
	if self._size >= self._capacity then
		return false  -- Buffer is full - caller must handle cleanup
	end

	self._buffer[self._head] = value
	self._head = (self._head % self._capacity) + 1
	self._size = self._size + 1

	return true
end

--[[
    Pop a value from the buffer (FIFO order).
    Returns nil if buffer is empty.
    O(1) operation.
]]
function CircularBuffer.Pop<T>(self: CircularBufferImpl<T>): T?
	if self._size == 0 then
		return nil  -- Buffer is empty
	end

	local value = self._buffer[self._tail]
	self._buffer[self._tail] = nil  -- Clear reference for GC
	self._tail = (self._tail % self._capacity) + 1
	self._size = self._size - 1

	return value
end

--[[
    Peek at the next value without removing it.
    Returns nil if buffer is empty.
    O(1) operation.
]]
function CircularBuffer.Peek<T>(self: CircularBufferImpl<T>): T?
	if self._size == 0 then
		return nil
	end

	return self._buffer[self._tail]
end

--[[
    Get the current number of elements in the buffer.
    O(1) operation.
]]
function CircularBuffer.Size<T>(self: CircularBufferImpl<T>): number
	return self._size
end

--[[
    Get the maximum capacity of the buffer.
    O(1) operation.
]]
function CircularBuffer.Capacity<T>(self: CircularBufferImpl<T>): number
	return self._capacity
end

--[[
    Check if the buffer is full.
    O(1) operation.
]]
function CircularBuffer.IsFull<T>(self: CircularBufferImpl<T>): boolean
	return self._size >= self._capacity
end

--[[
    Check if the buffer is empty.
    O(1) operation.
]]
function CircularBuffer.IsEmpty<T>(self: CircularBufferImpl<T>): boolean
	return self._size == 0
end

--[[
    Clear all elements from the buffer.
    O(n) operation to clear references for GC.
]]
function CircularBuffer.Clear<T>(self: CircularBufferImpl<T>): ()
	for i = 1, self._capacity do
		self._buffer[i] = nil
	end

	self._head = 1
	self._tail = 1
	self._size = 0
end

--[[
    Convert buffer contents to an array (in FIFO order).
    O(n) operation.
    Handles nil values safely.
]]
function CircularBuffer.ToArray<T>(self: CircularBufferImpl<T>): {T}
	local result = table.create(self._size)
	local index = self._tail
	local resultIndex = 0

	for i = 1, self._size do
		local value = self._buffer[index]
		if value ~= nil then
			resultIndex = resultIndex + 1
			result[resultIndex] = value :: T
		end
		index = (index % self._capacity) + 1
	end

	return result
end

--[[
    Destroy the buffer and cleanup resources.
    ARCHITECTURE: Added for consistent resource management.
]]
function CircularBuffer.Destroy<T>(self: CircularBufferImpl<T>): ()
	self:Clear()
	self._buffer = nil :: any
end

return CircularBuffer
