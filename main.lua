-- main.lua -- ScriptHub Entry Point
-- All Logging via print() -- always works.

-- ═══ COMPATIBILITY SHIM ═══
print("[SH] Compatibility check...")

if not typeof then
    typeof = function(x)
        local t = type(x)
        if t == "userdata" then
            local ok, cls = pcall(function() return x.ClassName end)
            if ok and cls then return cls end
            return "userdata"
        end
        return t
    end
    print("[SH]   typeof() stubbed")
end

if not task then task = {} end
if not task.spawn  then task.spawn  = function(f,...) return coroutine.wrap(f)(...) end end
if not task.wait   then task.wait   = function(t) wait(t or 0) end end
if not task.delay  then task.delay  = function(t,f,...) local a={...}; spawn(function() wait(t or 0); f(table.unpack(a)) end) end end
if not task.defer  then task.defer  = task.spawn end
if not task.cancel then task.cancel = function() end end
print("[SH]   task.* stubbed")

if not setfenv then setfenv = function() end end
if not getfenv then getfenv = function() return getgenv and getgenv() or _G end end

local HAS_DRAWING_G = pcall(function() return Drawing end)
if not HAS_DRAWING_G then Drawing = nil; print("[SH]   Drawing API NOT available")
else print("[SH]   Drawing API available") end

if not setclipboard then setclipboard = function() end end
if not getclipboard then getclipboard = function() return "" end end
if not writefile  then writefile  = function() end end
if not readfile   then readfile   = function() return "" end end
if not isfile     then isfile     = function() return false end end
if not isfolder   then isfolder   = function() return false end end
if not makefolder then makefolder = function() end end
if not listfiles  then listfiles  = function() return {} end end
if not delfile    then delfile    = function() end end

print("[SH] Compatibility done")

-- ═══ CONFIG ═══
local OWNER  = "idkgorapeme"
local REPO   = "RobloxRape"
local BRANCH = "arena/019fafdf-robloxrape"
local BASE   = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)
local CACHE  = tostring(os.time())
print("[SH] " .. OWNER .. "/" .. REPO .. " @" .. BRANCH)

-- ═══ MODULE LOADER ═══
local loaded = {}
local function mod(path)
    local url = BASE .. path .. "?v=" .. CACHE
    print("[SH] Load: " .. path)
    if loaded[path] then print("[SH]   cached"); return loaded[path] end
    local ok, result = pcall(function()
        local raw = game:HttpGet(url)
        print("[SH]   HTTP " .. #raw .. " bytes")
        local fn, err = loadstring(raw)
        if not fn then error("loadstring: " .. tostring(err)) end
        print("[SH]   compile OK, running...")
        return fn()
    end)
    if not ok then print("[SH]   FAIL: " .. tostring(result)); return nil, tostring(result) end
    print("[SH]   -> loaded")
    loaded[path] = result
    return result
end

-- ═══ CORE ═══
print("[SH] --- Core ---")
local Cleanup   = mod("src/Core/Cleanup.lua")
local State     = mod("src/Core/State.lua")
local UILibrary = mod("src/Core/UILibrary.lua")

if not Cleanup or not State or not UILibrary then
    print("[SH] FATAL: core load failed")
    pcall(function()
        local g = Instance.new("ScreenGui"); g.Name="SH_Err"
        g.Parent = pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local l = Instance.new("TextLabel"); l.Size=UDim2.new(0,400,0,50); l.Position=UDim2.new(0.5,-200,0.5,-25)
        l.BackgroundColor3=Color3.new(0.05,0.05,0.05); l.TextColor3=Color3.new(1,0.3,0.3)
        l.Text="ScriptHub: load failed\nCheck console\nAuto-close 10s..."; l.Font=Enum.Font.SourceSans or Enum.Font.Legacy or 0; l.TextSize=14; l.TextWrapped=true
        l.Parent=g
    end)
    wait(10); return
end

-- ═══ BUILD UI ═══
print("[SH] Building UI...")
local ui; local uiOk, uiErr = pcall(function() ui = UILibrary.new("Script Hub") end)
if not uiOk or not ui then print("[SH] UI BUILD FAILED: "..tostring(uiErr)); return end
print("[SH] UI OK")

local mc = Cleanup.new()
local ss = State.new()

ui.OnClose = function() mc:Clean() end

-- ═══ TABS ═══
print("[SH] Creating tabs...")
local function mkT(name)
    local ok, t = pcall(function() return ui:CreateTab(name) end)
    if ok and t then print("[SH]   "..name.." OK") else print("[SH]   "..name.." FAIL: "..tostring(t)) end
    return t
end
local t1=mkT("Universal"); local t2=mkT("Executor"); local t3=mkT("Exec.Viewport")
local t4=mkT("Prompt Gen"); local t5=mkT("Save/Load")

-- ═══ TAB MODULES ═══
print("[SH] --- Tab modules ---")
local vpApi, exApi

do local m=mod("src/Tabs/ExecutorViewport.lua"); if m and t3 then
    local ok,r=pcall(function() return m.Build(t3,ui,ss,mc) end)
    if ok then vpApi=r; print("[SH]   Viewport OK") else print("[SH]   Viewport ERR: "..tostring(r)) end
else print("[SH]   Viewport: not loaded") end end

do local m=mod("src/Tabs/Executor.lua"); if m and t2 then
    local ok,r=pcall(function() return m.Build(t2,ui,ss,mc,vpApi) end)
    if ok then exApi=r; print("[SH]   Executor OK") else print("[SH]   Executor ERR: "..tostring(r)) end
else print("[SH]   Executor: not loaded") end end

do local m=mod("src/Tabs/Universal.lua"); if m and t1 then
    local ok,r=pcall(function() return m.Build(t1,ui,ss,mc) end)
    if ok then print("[SH]   Universal OK") else print("[SH]   Universal ERR: "..tostring(r)) end
else print("[SH]   Universal: not loaded") end end

do local m=mod("src/Tabs/PromptGenerator.lua"); if m and t4 then
    local ok,r=pcall(function() return m.Build(t4,ui,ss,mc) end)
    if ok then print("[SH]   PromptGen OK") else print("[SH]   PromptGen ERR: "..tostring(r)) end
else print("[SH]   PromptGen: not loaded") end end

do local m=mod("src/Tabs/SaveLoad.lua"); if m and t5 then
    local ok,r=pcall(function() return m.Build(t5,ui,ss,mc,exApi) end)
    if ok then print("[SH]   SaveLoad OK") else print("[SH]   SaveLoad ERR: "..tostring(r)) end
else print("[SH]   SaveLoad: not loaded") end end

print("[SH] === Init done ===")
pcall(function() ui:Notify("Ready","All modules loaded.",4,"success") end)
