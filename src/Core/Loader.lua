-- Loader.lua — Fetches Lua modules from GitHub raw URLs and executes them via loadstring.
-- Supports cache-busting and handles errors gracefully.

local HttpService = game:GetService("HttpService")

local Loader = {}
Loader.__index = Loader

-- Cache for already-loaded modules to avoid double-fetching.
local ModuleCache = {}

function Loader.new(repoOwner, repoName, branch)
	local self = setmetatable({
		_repoOwner = repoOwner or "idkgorapeme",
		_repoName = repoName or "RobloxRape",
		_branch = branch or "main",
		_baseUrl = nil,
		_cacheVersion = nil, -- cache-bust query param
	}, Loader)

	self._baseUrl = "https://raw.githubusercontent.com/" .. self._repoOwner .. "/" .. self._repoName .. "/" .. self._branch .. "/"
	-- Use current timestamp as cache buster for fresh loads each session
	self._cacheVersion = tostring(os.time())

	return self
end

--- Fetch and execute a single Lua module from a path relative to repo root.
-- Returns whatever the module returns.
function Loader:LoadModule(path)
	local url = self._baseUrl .. path .. "?v=" .. self._cacheVersion

	-- Check cache
	if ModuleCache[url] then
		return ModuleCache[url]
	end

	local ok, result = pcall(function()
		local raw = game:HttpGet(url)
		local fn, err = loadstring(raw)
		if not fn then
			error("Failed to compile module: " .. tostring(err))
		end
		return fn()
	end)

	if not ok then
		return nil, result -- result is the error
	end

	ModuleCache[url] = result
	return result
end

--- Get the full raw URL for a path (for external use like loadstring injection).
function Loader:GetUrl(path)
	return self._baseUrl .. path .. "?v=" .. self._cacheVersion
end

return Loader
