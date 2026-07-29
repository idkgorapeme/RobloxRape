-- State.lua — Shared settings table with optional persistence via writefile/readfile
print("[State] Loaded")

local HttpService = game:GetService("HttpService")

local State = {}
State.__index = State

local SETTINGS_FILE = "ScriptHub/settings.json"

function State.new()
	local self = setmetatable({
		_data = {},         -- in-memory settings key-value store
		_hasFileIO = false, -- whether writefile/readfile are available
		_listeners = {},    -- change listeners: key -> {fn, fn, ...}
	}, State)

	-- Feature-detect file I/O
	local ok
	ok = pcall(function() return readfile end)
	if ok then
		self._hasFileIO = true
	end

	-- Try to load from disk
	self:LoadFromDisk()

	return self
end

--- Get a setting, with optional default.
function State:Get(key, default)
	if self._data[key] ~= nil then
		return self._data[key]
	end
	return default
end

--- Set a setting and fire listeners.
function State:Set(key, value)
	self._data[key] = value
	self:FireListeners(key, value)
	self:SaveToDisk()
end

--- Register a listener for changes to a key.
-- Returns a function to unregister.
function State:OnChange(key, fn)
	if not self._listeners[key] then
		self._listeners[key] = {}
	end
	table.insert(self._listeners[key], fn)
	return function()
		for i, f in ipairs(self._listeners[key] or {}) do
			if f == fn then
				table.remove(self._listeners[key], i)
				return
			end
		end
	end
end

--- Fire all listeners for a key.
function State:FireListeners(key, value)
	if self._listeners[key] then
		for _, fn in ipairs(self._listeners[key]) do
			pcall(fn, value)
		end
	end
end

--- Save settings to disk as JSON.
function State:SaveToDisk()
	if not self._hasFileIO then return end
	local ok, err = pcall(function()
		local json = HttpService:JSONEncode(self._data)
		writefile(SETTINGS_FILE, json)
	end)
	if not ok then
		warn("[State] Failed to save settings: " .. tostring(err))
	end
end

--- Load settings from disk.
function State:LoadFromDisk()
	if not self._hasFileIO then return end
	local ok, data = pcall(function()
		if isfile and isfile(SETTINGS_FILE) then
			return readfile(SETTINGS_FILE)
		end
		return nil
	end)
	if ok and data then
		local decoded
		local ok2 = pcall(function()
			decoded = HttpService:JSONDecode(data)
		end)
		if ok2 and type(decoded) == "table" then
			self._data = decoded
		end
	end
end

--- Dump all data (for debugging).
function State:GetAll()
	return self._data
end

--- Clear all data.
function State:Clear()
	self._data = {}
	self:SaveToDisk()
end

return State
