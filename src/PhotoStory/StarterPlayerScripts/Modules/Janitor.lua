--!nonstrict
-- Janitor: pelacak resource ringan. Simpan connection/instance/tween/thread/fungsi,
-- bersihkan semua sekali panggil. Mencegah memory leak.

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new()
	return setmetatable({ _tasks = {}, _destroyed = false }, Janitor)
end

-- Add(object[, cleanupMethod])
-- cleanupMethod:
--   nil   -> auto: Connection:Disconnect, Instance:Destroy, function(), thread:cancel
--   string-> panggil object[method](object)
--   true  -> kalau thread: task.cancel; kalau function: panggil
function Janitor:Add(object, cleanupMethod)
	if self._destroyed then
		-- Sudah dibersihkan: jangan simpan, langsung beresin biar tidak bocor.
		Janitor._cleanupOne(object, cleanupMethod)
		return object
	end
	table.insert(self._tasks, { object = object, method = cleanupMethod })
	return object
end

function Janitor._cleanupOne(object, method)
	if object == nil then
		return
	end

	if type(method) == "string" then
		local fn = object[method]
		if fn then
			fn(object)
		end
		return
	end

	local kind = typeof(object)
	if kind == "RBXScriptConnection" then
		object:Disconnect()
	elseif kind == "Instance" then
		object:Destroy()
	elseif kind == "function" then
		object()
	elseif kind == "thread" then
		task.cancel(object)
	elseif kind == "table" and type(object.Destroy) == "function" then
		object:Destroy()
	end
end

function Janitor:Cleanup()
	local tasks = self._tasks
	self._tasks = {}
	-- Reverse order: resource terakhir dibuat dibersihkan duluan.
	for i = #tasks, 1, -1 do
		local entry = tasks[i]
		local ok, err = pcall(Janitor._cleanupOne, entry.object, entry.method)
		if not ok then
			warn("[PhotoStory] Janitor cleanup error: " .. tostring(err))
		end
	end
end

function Janitor:Destroy()
	self:Cleanup()
	self._destroyed = true
end

return Janitor
