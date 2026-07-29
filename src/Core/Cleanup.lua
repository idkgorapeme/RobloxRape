-- Cleanup.lua — Janitor-style session cleanup system
print("[Cleanup] Loaded")
-- Tracks Instances, RBXScriptConnections, threads, and custom callbacks
-- so they can all be destroyed/disconnected/cancelled in one call.

local Cleanup = {}
Cleanup.__index = Cleanup

function Cleanup.new()
	local self = setmetatable({
		_instances = {},          -- Instances to :Destroy()
		_connections = {},        -- RBXScriptConnections to :Disconnect()
		_threads = {},            -- threads/coroutines to task.cancel
		_bindables = {},          -- BindableEvents/Functions to :Destroy()
		_callbacks = {},          -- custom functions to call on cleanup
		_active = true
	}, Cleanup)
	return self
end

--- Add an Instance to be destroyed on cleanup.
function Cleanup:Add(thing)
	if not self._active then return end

	if typeof(thing) == "Instance" then
		table.insert(self._instances, thing)
	elseif typeof(thing) == "RBXScriptConnection" then
		table.insert(self._connections, thing)
	elseif type(thing) == "thread" then
		table.insert(self._threads, thing)
	elseif type(thing) == "function" then
		-- Custom callback
		table.insert(self._callbacks, thing)
	else
		-- Try to store anyway; Consumer should know what it's doing
		table.insert(self._callbacks, function()
			pcall(function()
				if typeof(thing) == "Instance" then
					thing:Destroy()
				elseif typeof(thing) == "RBXScriptConnection" then
					thing:Disconnect()
				end
			end)
		end)
	end
end

--- Convenience: Add an Instance → destroy
function Cleanup:AddInstance(inst)
	if typeof(inst) == "Instance" then
		table.insert(self._instances, inst)
	end
end

--- Convenience: Add a connection → disconnect
function Cleanup:AddConnection(conn)
	if typeof(conn) == "RBXScriptConnection" then
		table.insert(self._connections, conn)
	end
end

--- Convenience: Add a thread → cancel
function Cleanup:AddThread(th)
	if type(th) == "thread" or typeof(th) == "thread" then
		table.insert(self._threads, th)
	end
end

--- Convenience: Register a custom callback
function Cleanup:AddCallback(fn)
	if type(fn) == "function" then
		table.insert(self._callbacks, fn)
	end
end

--- Destroy everything tracked by this janitor.
-- @param keepActive (bool) — if true, the janitor remains usable after cleanup
function Cleanup:Clean(keepActive)
	keepActive = keepActive or false

	-- Disconnect connections first (prevents callbacks firing on destroyed instances)
	for _, conn in ipairs(self._connections) do
		pcall(function() conn:Disconnect() end)
	end
	self._connections = {}

	-- Cancel threads
	for _, th in ipairs(self._threads) do
		pcall(function() task.cancel(th) end)
	end
	self._threads = {}

	-- Destroy Bindables
	for _, b in ipairs(self._bindables) do
		pcall(function() b:Destroy() end)
	end
	self._bindables = {}

	-- Destroy Instances
	for _, inst in ipairs(self._instances) do
		pcall(function() inst:Destroy() end)
	end
	self._instances = {}

	-- Fire custom callbacks
	for _, cb in ipairs(self._callbacks) do
		pcall(cb)
	end
	self._callbacks = {}

	if not keepActive then
		self._active = false
	end
end

--- Remove a specific thing from tracking without destroying it.
function Cleanup:Remove(thing)
	for i, v in ipairs(self._instances) do
		if v == thing then table.remove(self._instances, i); return end
	end
	for i, v in ipairs(self._connections) do
		if v == thing then table.remove(self._connections, i); return end
	end
	for i, v in ipairs(self._threads) do
		if v == thing then table.remove(self._threads, i); return end
	end
end

return Cleanup
