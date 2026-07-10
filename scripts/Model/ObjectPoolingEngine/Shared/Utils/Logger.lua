--!strict
--[[
    Logger.lua
    Advanced Object Pooling Engine - Unified Logging System
    
    Provides consistent logging across all modules with configurable log levels.
]]

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR" | "NONE"

local Logger = {}

-- Log level priorities (higher = more important)
local LOG_PRIORITIES: {[LogLevel]: number} = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	NONE = 5,
}

-- Current log level (can be changed at runtime)
local currentLevel: LogLevel = "WARN"

-- Module-specific overrides
local moduleOverrides: {[string]: LogLevel} = {}

--[[
    Set the global log level.
    Messages below this level will not be printed.
    
    @param level - The minimum log level to display
]]
function Logger.SetLevel(level: LogLevel): ()
	currentLevel = level
end

--[[
    Get the current global log level.
    
    @return LogLevel - Current log level
]]
function Logger.GetLevel(): LogLevel
	return currentLevel
end

--[[
    Set log level for a specific module.
    
    @param moduleName - Name of the module
    @param level - Log level for this module
]]
function Logger.SetModuleLevel(moduleName: string, level: LogLevel): ()
	moduleOverrides[moduleName] = level
end

--[[
    Clear module-specific log level override.
    
    @param moduleName - Name of the module
]]
function Logger.ClearModuleLevel(moduleName: string): ()
	moduleOverrides[moduleName] = nil
end

--[[
    Check if a message at the given level should be logged.
    
    @param level - Log level to check
    @param moduleName - Optional module name for module-specific levels
    @return boolean - True if message should be logged
]]
local function shouldLog(level: LogLevel, moduleName: string?): boolean
	local effectiveLevel = currentLevel

	if moduleName and moduleOverrides[moduleName] then
		effectiveLevel = moduleOverrides[moduleName]
	end

	return LOG_PRIORITIES[level] >= LOG_PRIORITIES[effectiveLevel]
end

--[[
    Format a log message with timestamp and module name.
    
    @param level - Log level
    @param moduleName - Name of the module
    @param message - Message to format
    @return string - Formatted message
]]
local function formatMessage(level: LogLevel, moduleName: string, message: string): string
	local timestamp = string.format("%.3f", os.clock())
	return string.format("[%s][%s][%s] %s", timestamp, level, moduleName, message)
end

--[[
    Log a debug message.
    
    @param moduleName - Name of the module
    @param message - Message format string
    @param ... - Format arguments
]]
function Logger.Debug(moduleName: string, message: string, ...: any): ()
	if not shouldLog("DEBUG", moduleName) then return end
	print(formatMessage("DEBUG", moduleName, string.format(message, ...)))
end

--[[
    Log an info message.
    
    @param moduleName - Name of the module
    @param message - Message format string
    @param ... - Format arguments
]]
function Logger.Info(moduleName: string, message: string, ...: any): ()
	if not shouldLog("INFO", moduleName) then return end
	print(formatMessage("INFO", moduleName, string.format(message, ...)))
end

--[[
    Log a warning message.
    
    @param moduleName - Name of the module
    @param message - Message format string
    @param ... - Format arguments
]]
function Logger.Warn(moduleName: string, message: string, ...: any): ()
	if not shouldLog("WARN", moduleName) then return end
	warn(formatMessage("WARN", moduleName, string.format(message, ...)))
end

--[[
    Log an error message.
    
    @param moduleName - Name of the module
    @param message - Message format string
    @param ... - Format arguments
]]
function Logger.Error(moduleName: string, message: string, ...: any): ()
	if not shouldLog("ERROR", moduleName) then return end
	warn(formatMessage("ERROR", moduleName, string.format(message, ...)))
end

--[[
    Create a scoped logger for a specific module.
    Returns a table with debug/info/warn/error methods pre-bound to the module name.
    
    @param moduleName - Name of the module
    @return table - Scoped logger
]]
function Logger.ForModule(moduleName: string): {
	debug: (message: string, ...any) -> (),
	info: (message: string, ...any) -> (),
	warn: (message: string, ...any) -> (),
	error: (message: string, ...any) -> (),
	}
	return {
		debug = function(message: string, ...: any)
			Logger.Debug(moduleName, message, ...)
		end,
		info = function(message: string, ...: any)
			Logger.Info(moduleName, message, ...)
		end,
		warn = function(message: string, ...: any)
			Logger.Warn(moduleName, message, ...)
		end,
		error = function(message: string, ...: any)
			Logger.Error(moduleName, message, ...)
		end,
	}
end

return Logger
