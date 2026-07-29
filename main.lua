-- main.lua -- ScriptHub Entry Point
-- All stubs written to _G so loadstring'd modules can see them.

-- ============================================================
-- GLOBAL COMPATIBILITY SHIMS (must be in _G for loadstring)
-- ============================================================
print("[SH] Compatibility check...")

-- typeof
if not _G.typeof then
    _G.typeof = function(x)
        local t = type(x)
        if t == "userdata" then
            local ok, cls = pcall(function() return x.ClassName end)
            return (ok and cls) and cls or "userdata"
        end
        return t
    end
    print("[SH]   typeof() -> global")
end

-- task library
if not _G.task then _G.task = {} end
if not _G.task.spawn  then _G.task.spawn  = function(f,...) local a={...}; return coroutine.wrap(function() f(table.unpack(a)) end)() end end
if not _G.task.wait   then _G.task.wait   = function(t) wait(t or 0) end end
if not _G.task.delay  then _G.task.delay  = function(t,f,...) local a={...}; spawn(function() wait(t or 0); f(table.unpack(a)) end) end end
if not _G.task.defer  then _G.task.defer  = _G.task.spawn end
if not _G.task.cancel then _G.task.cancel = function() end end
print("[SH]   task.* -> global")

-- setfenv/getfenv
if not setfenv then _G.setfenv = function() end end
if not getfenv then _G.getfenv = function() return getgenv and getgenv() or _G end end

-- Drawing
if not _G.Drawing then
    local has = pcall(function() return Drawing end)
    if not has then
        _G.Drawing = nil
        print("[SH]   Drawing NOT available")
    end
end

-- Clipboard
if not setclipboard then _G.setclipboard = function() end end
if not getclipboard then _G.getclipboard = function() return "" end end

-- File I/O
if not writefile  then _G.writefile  = function() end end
if not readfile   then _G.readfile   = function() return "" end end
if not isfile     then _G.isfile     = function() return false end end
if not isfolder   then _G.isfolder   = function() return false end end
if not makefolder then _G.makefolder = function() end end
if not listfiles  then _G.listfiles  = function() return {} end end
if not delfile    then _G.delfile    = function() end end

-- HttpService.GenerateGUID (old executors may not have it)
local HttpService = game:GetService("HttpService")
if not pcall(function() return HttpService:GenerateGUID(false) end) then
    local orig = HttpService.GenerateGUID
    if not orig then
        -- stub it
        local function fakeGuid()
            local t = {}
            for i=1,32 do t[i] = ("%x"):format(math.random(0,15)) end
            return table.concat(t)
        end
        HttpService.GenerateGUID = function(self, wrap)
            local g = fakeGuid()
            return wrap ~= false and "{"..g.."}" or g
        end
        print("[SH]   GenerateGUID stubbed")
    end
end

print("[SH] Compatibility OK")

-- ============================================================
-- CONFIG
-- ============================================================
local OWNER  = "idkgorapeme"
local REPO   = "RobloxRape"
local BRANCH = "arena/019fafdf-robloxrape"
local BASE   = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)
local CACHE  = tostring(os.time())
print("[SH] " .. OWNER .. "/" .. REPO .. " @" .. BRANCH)

-- ============================================================
-- MODULE LOADER
-- ============================================================
local loaded = {}
local function mod(path)
    local url = BASE .. path .. "?v=" .. CACHE
    print("[SH] Load: " .. path)
    if loaded[path] then print("[SH]   cached"); return loaded[path] end

    local ok, result = pcall(function()
        local raw = game:HttpGet(url)
        if not raw or #raw < 10 then error("HTTP returned empty/short ("..tostring(#raw or 0).." bytes)") end
        print("[SH]   HTTP " .. #raw .. " bytes")
        local fn, err = loadstring(raw)
        if not fn then error("loadstring: " .. tostring(err)) end
        print("[SH]   compile OK, running...")
        return fn()
    end)

    if not ok then
        print("[SH]   FAIL: " .. tostring(result))
        return nil, tostring(result)
    end

    print("[SH]   -> loaded")
    loaded[path] = result
    return result
end

-- ============================================================
-- LOAD CORE MODULES
-- ============================================================
print("[SH] --- Core ---")

local Cleanup   = mod("src/Core/Cleanup.lua")
local State     = mod("src/Core/State.lua")
local UILibrary = mod("src/Core/UILibrary.lua")

if not Cleanup or not State or not UILibrary then
    print("[SH] === CORE LOAD FAILED ===")
    print("[SH] Missing: " ..
        (Cleanup and "" or "Cleanup ") ..
        (State and "" or "State ") ..
        (UILibrary and "" or "UILibrary "))

    -- Show error that stays visible (NO auto-unload)
    pcall(function()
        local errParent = game:GetService("CoreGui")
        local probe = Instance.new("Frame"); probe.Parent = errParent; probe:Destroy()

        local g = Instance.new("ScreenGui"); g.Name = "ScriptHub_Err"
        g.ResetOnSpawn = false; g.Parent = errParent

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0, 440, 0, 80)
        l.Position = UDim2.new(0.5, -220, 0.5, -40)
        l.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
        l.TextColor3 = Color3.new(1, 0.3, 0.3)
        l.Text = "ScriptHub: core module load failed.\n\nCheck the executor console for details.\n\nRe-run the loadstring to try again."
        l.Font = Enum.Font.SourceSans or Enum.Font.Legacy or 0
        l.TextSize = 14
        l.TextWrapped = true
        l.Parent = g
        pcall(function() Instance.new("UICorner", l).CornerRadius = UDim2.new(0, 6) end)
    end)
    return
end

-- ============================================================
-- BUILD UI
-- ============================================================
print("[SH] Building UI...")
local ui; local uiOk, uiErr = pcall(function() ui = UILibrary.new("Script Hub") end)

if not uiOk or not ui then
    print("[SH] === UI BUILD FAILED: " .. tostring(uiErr) .. " ===")
    return
end
print("[SH] UI OK")

local mc = Cleanup.new()
local ss = State.new()

ui.OnClose = function()
    print("[SH] Close requested")
    mc:Clean()
end

-- ============================================================
-- CREATE TABS
-- ============================================================
print("[SH] Creating tabs...")
local function mkT(name)
    local ok, t = pcall(function() return ui:CreateTab(name) end)
    if ok and t then print("[SH]   "..name.." OK")
    else print("[SH]   "..name.." FAIL: "..tostring(t)) end
    return t
end
local t1 = mkT("Universal")
local t2 = mkT("Executor")
local t3 = mkT("Exec.Viewport")
local t4 = mkT("Prompt Gen")
local t5 = mkT("Save/Load")

-- ============================================================
-- LOAD TAB MODULES
-- ============================================================
print("[SH] --- Tab modules ---")
local vpApi, exApi

-- Tab 3 first (viewport needed by executor)
do local m = mod("src/Tabs/ExecutorViewport.lua")
if m and t3 then
    local ok, r = pcall(function() return m.Build(t3, ui, ss, mc) end)
    if ok then vpApi = r; print("[SH]   Viewport OK")
    else print("[SH]   Viewport ERR: "..tostring(r)) end
else print("[SH]   Viewport: not loaded") end end

do local m = mod("src/Tabs/Executor.lua")
if m and t2 then
    local ok, r = pcall(function() return m.Build(t2, ui, ss, mc, vpApi) end)
    if ok then exApi = r; print("[SH]   Executor OK")
    else print("[SH]   Executor ERR: "..tostring(r)) end
else print("[SH]   Executor: not loaded") end end

do local m = mod("src/Tabs/Universal.lua")
if m and t1 then
    local ok, r = pcall(function() return m.Build(t1, ui, ss, mc) end)
    if ok then print("[SH]   Universal OK")
    else print("[SH]   Universal ERR: "..tostring(r)) end
else print("[SH]   Universal: not loaded") end end

do local m = mod("src/Tabs/PromptGenerator.lua")
if m and t4 then
    local ok, r = pcall(function() return m.Build(t4, ui, ss, mc) end)
    if ok then print("[SH]   PromptGen OK")
    else print("[SH]   PromptGen ERR: "..tostring(r)) end
else print("[SH]   PromptGen: not loaded") end end

do local m = mod("src/Tabs/SaveLoad.lua")
if m and t5 then
    local ok, r = pcall(function() return m.Build(t5, ui, ss, mc, exApi) end)
    if ok then print("[SH]   SaveLoad OK")
    else print("[SH]   SaveLoad ERR: "..tostring(r)) end
else print("[SH]   SaveLoad: not loaded") end end

print("[SH] === Init complete ===")
pcall(function() ui:Notify("Ready", "All modules loaded.", 4, "success") end)
