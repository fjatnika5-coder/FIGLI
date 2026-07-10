--!strict
--[[
    PriorityQueue.lua
    Advanced Object Pooling Engine - Min-Heap Priority Queue
    
    Implements a min-heap for priority-based allocation.
    Insert: O(log n), ExtractMin: O(log n), Peek: O(1)
    Requirements: 11.1, 11.2
]]

-- ============================================================================
-- PriorityQueue Class (Min-Heap)
-- ============================================================================

local PriorityQueue = {}
PriorityQueue.__index = PriorityQueue

export type PriorityQueueEntry<T> = {
	priority: number,
	value: T,
}

export type PriorityQueueImpl<T> = {
	_heap: {PriorityQueueEntry<T>},
	Insert: (self: PriorityQueueImpl<T>, value: T, priority: number) -> (),
	ExtractMin: (self: PriorityQueueImpl<T>) -> T?,
	Peek: (self: PriorityQueueImpl<T>) -> T?,
	PeekPriority: (self: PriorityQueueImpl<T>) -> number?,
	IsEmpty: (self: PriorityQueueImpl<T>) -> boolean,
	Size: (self: PriorityQueueImpl<T>) -> number,
	Clear: (self: PriorityQueueImpl<T>) -> (),
}

--[[
    Create a new PriorityQueue (min-heap).
]]
function PriorityQueue.new<T>(): PriorityQueueImpl<T>
	local self = setmetatable({}, PriorityQueue) :: any
	self._heap = {}
	return self
end

-- ============================================================================
-- Private Helper Functions
-- ============================================================================

--[[
    Get parent index for a given index.
]]
local function getParentIndex(index: number): number
	return math.floor(index / 2)
end

--[[
    Get left child index for a given index.
]]
local function getLeftChildIndex(index: number): number
	return index * 2
end

--[[
    Get right child index for a given index.
]]
local function getRightChildIndex(index: number): number
	return index * 2 + 1
end

--[[
    Swap two elements in the heap.
]]
local function swap<T>(heap: {PriorityQueueEntry<T>}, i: number, j: number): ()
	heap[i], heap[j] = heap[j], heap[i]
end

--[[
    Bubble up an element to maintain heap property.
    O(log n) operation.
]]
local function bubbleUp<T>(heap: {PriorityQueueEntry<T>}, index: number): ()
	while index > 1 do
		local parentIndex = getParentIndex(index)

		-- If parent has higher priority (larger value), swap
		if heap[parentIndex].priority > heap[index].priority then
			swap(heap, parentIndex, index)
			index = parentIndex
		else
			break
		end
	end
end

--[[
    Bubble down an element to maintain heap property.
    O(log n) operation.
]]
local function bubbleDown<T>(heap: {PriorityQueueEntry<T>}, index: number): ()
	local size = #heap

	while true do
		local smallest = index
		local leftIndex = getLeftChildIndex(index)
		local rightIndex = getRightChildIndex(index)

		-- Check if left child is smaller
		if leftIndex <= size and heap[leftIndex].priority < heap[smallest].priority then
			smallest = leftIndex
		end

		-- Check if right child is smaller
		if rightIndex <= size and heap[rightIndex].priority < heap[smallest].priority then
			smallest = rightIndex
		end

		-- If smallest is not current index, swap and continue
		if smallest ~= index then
			swap(heap, index, smallest)
			index = smallest
		else
			break
		end
	end
end

-- ============================================================================
-- Public Methods
-- ============================================================================

--[[
    Insert a value with the given priority.
    O(log n) operation.
]]
function PriorityQueue.Insert<T>(self: PriorityQueueImpl<T>, value: T, priority: number): ()
	local entry: PriorityQueueEntry<T> = {
		priority = priority,
		value = value,
	}

	-- Add to end of heap
	table.insert(self._heap, entry)

	-- Bubble up to maintain heap property
	bubbleUp(self._heap, #self._heap)
end

--[[
    Extract and return the minimum priority element.
    Returns nil if queue is empty.
    O(log n) operation.
]]
function PriorityQueue.ExtractMin<T>(self: PriorityQueueImpl<T>): T?
	local size = #self._heap

	if size == 0 then
		return nil
	end

	-- Get the minimum (root)
	local minEntry = self._heap[1]

	if size == 1 then
		-- Only one element, just remove it
		table.remove(self._heap, 1)
	else
		-- Move last element to root and bubble down
		self._heap[1] = self._heap[size]
		table.remove(self._heap, size)
		bubbleDown(self._heap, 1)
	end

	return minEntry.value
end

--[[
    Peek at the minimum priority element without removing it.
    Returns nil if queue is empty.
    O(1) operation.
]]
function PriorityQueue.Peek<T>(self: PriorityQueueImpl<T>): T?
	if #self._heap == 0 then
		return nil
	end

	return self._heap[1].value
end

--[[
    Peek at the minimum priority value without removing the element.
    Returns nil if queue is empty.
    O(1) operation.
]]
function PriorityQueue.PeekPriority<T>(self: PriorityQueueImpl<T>): number?
	if #self._heap == 0 then
		return nil
	end

	return self._heap[1].priority
end

--[[
    Check if the queue is empty.
    O(1) operation.
]]
function PriorityQueue.IsEmpty<T>(self: PriorityQueueImpl<T>): boolean
	return #self._heap == 0
end

--[[
    Get the number of elements in the queue.
    O(1) operation.
]]
function PriorityQueue.Size<T>(self: PriorityQueueImpl<T>): number
	return #self._heap
end

--[[
    Clear all elements from the queue.
    O(1) operation.
]]
function PriorityQueue.Clear<T>(self: PriorityQueueImpl<T>): ()
	table.clear(self._heap)
end

--[[
    Destroy the priority queue and cleanup resources.
    ARCHITECTURE: Added for consistent resource management.
]]
function PriorityQueue.Destroy<T>(self: PriorityQueueImpl<T>): ()
	table.clear(self._heap)
	self._heap = nil :: any
end

return PriorityQueue
