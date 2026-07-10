--!strict
--[[
    Signal.lua
    Advanced Object Pooling Engine - Custom Event System
    
    GC-friendly alternative to BindableEvents for lifecycle hooks.
    Requirements: 11.7, 11.8
]]

local Types = require(script.Parent.Parent.Types)

-- ============================================================================
-- Connection Class
-- ============================================================================

local Connection = {}
Connection.__index = Connection

export type ConnectionImpl = {
	_signal: SignalImpl?,
	_callback: ((...any) -> ())?,
	_once: boolean,
	Connected: boolean,
	Disconnect: (self: ConnectionImpl) -> (),
}

function Connection.new(signal: SignalImpl, callback: (...any) -> (), once: boolean): ConnectionImpl
	local self = setmetatable({}, Connection) :: any
	self._signal = signal
	self._callback = callback
	self._once = once
	self.Connected = true
	return self
end

function Connection.Disconnect(self: ConnectionImpl): ()
	if not self.Connected then
		return
	end

	self.Connected = false

	if self._signal then
		-- Remove from signal's connection list
		local connections = self._signal._connections
		for i = #connections, 1, -1 do
			if connections[i] == self then
				table.remove(connections, i)
				break
			end
		end
	end

	self._signal = nil
	self._callback = nil
end

-- ============================================================================
-- Signal Class
-- ============================================================================

local Signal = {}
Signal.__index = Signal

export type SignalImpl = {
	_connections: {ConnectionImpl},
	Connect: (self: SignalImpl, callback: (...any) -> ()) -> ConnectionImpl,
	Once: (self: SignalImpl, callback: (...any) -> ()) -> ConnectionImpl,
	Fire: (self: SignalImpl, ...any) -> (),
	DisconnectAll: (self: SignalImpl) -> (),
	GetConnectionCount: (self: SignalImpl) -> number,
}

function Signal.new(): SignalImpl
	local self = setmetatable({}, Signal) :: any
	self._connections = {}
	return self
end

--[[
    Connect a callback to the signal.
    The callback will be invoked every time Fire() is called.
    Returns a Connection object that can be used to disconnect.
]]
function Signal.Connect(self: SignalImpl, callback: (...any) -> ()): ConnectionImpl
	local connection = Connection.new(self, callback, false)
	table.insert(self._connections, connection)
	return connection
end

--[[
    Connect a callback that will only fire once.
    After the first Fire(), the connection is automatically disconnected.
]]
function Signal.Once(self: SignalImpl, callback: (...any) -> ()): ConnectionImpl
	local connection = Connection.new(self, callback, true)
	table.insert(self._connections, connection)
	return connection
end

--[[
    Fire the signal, invoking all connected callbacks with the provided arguments.
    Once connections are automatically disconnected after firing.
    
    Iterates in reverse order instead of cloning the array for better performance.
    This avoids allocation on every Fire() call while still being safe
    if callbacks disconnect during iteration.
    
    Safe to call after Destroy() - will no-op.
    Uses pcall to prevent one bad callback from breaking others.
]]
function Signal.Fire(self: SignalImpl, ...: any): ()
	-- Check if destroyed
	if self._connections == nil then
		return
	end

	-- Iterate in reverse to safely handle disconnections during iteration
	for i = #self._connections, 1, -1 do
		local connection = self._connections[i]
		if connection and connection.Connected and connection._callback then
			local success, err = pcall(connection._callback, ...)
			if not success then
				warn("[Signal] Callback error: " .. tostring(err))
			end

			-- Auto-disconnect if it was a Once connection
			if connection._once then
				connection:Disconnect()
			end
		end
	end
end

--[[
    Disconnect all callbacks from the signal.
    After this call, Fire() will invoke zero callbacks.
]]
function Signal.DisconnectAll(self: SignalImpl): ()
	-- Disconnect each connection properly
	for _, connection in ipairs(self._connections) do
		connection.Connected = false
		connection._signal = nil
		connection._callback = nil
	end

	-- Clear the connections array
	table.clear(self._connections)
end

--[[
    Get the current number of connected callbacks.
    Useful for testing and debugging.
]]
function Signal.GetConnectionCount(self: SignalImpl): number
	return #self._connections
end

--[[
    Destroy the signal and cleanup all resources.
    Safe to call multiple times (idempotent).
]]
function Signal.Destroy(self: SignalImpl): ()
	-- Check if already destroyed
	if self._connections == nil then
		return
	end

	self:DisconnectAll()
	self._connections = nil :: any
end

return Signal
