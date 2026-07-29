--[=[
  ScriptHub — Pure local, fully self-contained.
  No external modules. No typeof/task/Drawing/fancy fonts.
  Only basic Roblox APIs that work on EVERY executor.
]=]

local plr   = game:GetService("Players").LocalPlayer
local uis   = game:GetService("UserInputService")
local run   = game:GetService("RunService")
local twe   = game:GetService("TweenService")
local cam   = workspace.CurrentCamera

-- ====== SAFE HELPERS ======
local function safe(fn) pcall(fn) end
local function corner(f, r)
    safe(function() Instance.new("UICorner", f).CornerRadius = r or UDim2.new(0,6) end)
end
local function tryFont(name)
    local ok,v = pcall(function() return Enum.Font[name] end)
    return (ok and v) and v or 0
end
local F = tryFont("Gotham")
local FB = tryFont("GothamBold")
if FB == F then FB = F end
local FC = tryFont("Code")
if FC == F then FC = F end

-- Color palette
local C = {
    Bg    = Color3.new(0.05,0.05,0.06),
    Surf  = Color3.new(0.09,0.09,0.11),
    Surf2 = Color3.new(0.12,0.12,0.15),
    Acc   = Color3.new(0.45,0.35,0.90),
    Acc2  = Color3.new(0.35,0.25,0.80),
    Txt   = Color3.new(0.90,0.90,0.93),
    Txt2  = Color3.new(0.55,0.55,0.60),
    Txt3  = Color3.new(0.30,0.30,0.35),
    Grn   = Color3.new(0.25,0.75,0.40),
    Red   = Color3.new(0.90,0.25,0.25),
    Yel   = Color3.new(0.90,0.75,0.25),
    Wht   = Color3.new(1,1,1),
}
local H = 34 -- control height

-- ====== PARENT SETUP ======
local function getSafeParent()
    local ok = pcall(function()
        local p = game:GetService("CoreGui")
        local f = Instance.new("Frame"); f.Parent = p; f:Destroy()
    end)
    if ok then return game:GetService("CoreGui") end
    return plr:WaitForChild("PlayerGui")
end

local parent = getSafeParent()

-- Destroy old instances
for _, name in ipairs({"ScriptHubUI","ExecutorOutputGui"}) do
    local old = parent:FindFirstChild(name)
    if old then safe(function() old:Destroy() end) end
end

print("[SH] === Starting ===")

-- ====== JANITOR ======
local function janitor()
    local j = {i={}, c={}, t={}, f={}}
    function j:add(thing)
        if type(thing) == "userdata" then
            table.insert(j.i, thing)
        elseif type(thing) == "function" then
            table.insert(j.f, thing)
        elseif type(thing) == "thread" then
            table.insert(j.t, thing)
        end
    end
    function j:clean()
        for _,x in ipairs(j.c) do safe(function() x:Disconnect() end) end; j.c={}
        for _,x in ipairs(j.t) do safe(function() coroutine.close and coroutine.close(x) end) end; j.t={}
        for _,x in ipairs(j.i) do safe(function() x:Destroy() end) end; j.i={}
        for _,x in ipairs(j.f) do safe(x) end; j.f={}
    end
    j.addConn = function(self, conn) table.insert(self.c, conn) end
    return j
end

local mainJanitor = janitor()

-- ====== NOTIFICATIONS ======
local notifs = {}
local function notify(title, msg, dur, ntype)
    dur = dur or 4
    local col = ({info=C.Acc,error=C.Red,success=C.Grn,warning=C.Yel})[ntype or "info"] or C.Acc
    local nf = Instance.new("Frame")
    nf.Size = UDim2.new(0,240,0,54); nf.Position = UDim2.new(1,10,1,-(#notifs*62+16))
    nf.BackgroundColor3 = C.Surf; nf.BorderSizePixel = 0; nf.Parent = notifLayer
    corner(nf)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0,3,1,0); bar.BackgroundColor3 = col; bar.BorderSizePixel = 0; bar.Parent = nf
    corner(bar,UDim2.new(0,3))
    local tl = Instance.new("TextLabel")
    tl.Size=UDim2.new(1,-28,0,20); tl.Position=UDim2.new(0,12,0,6)
    tl.BackgroundTransparency=1; tl.Text=title or "Note"; tl.TextColor3=C.Txt
    tl.Font=FB; tl.TextSize=13; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=nf
    local ml = Instance.new("TextLabel")
    ml.Size=UDim2.new(1,-28,0,16); ml.Position=UDim2.new(0,12,0,30)
    ml.BackgroundTransparency=1; ml.Text=msg or ""; ml.TextColor3=C.Txt2
    ml.Font=F; ml.TextSize=10; ml.TextXAlignment=Enum.TextXAlignment.Left; ml.Parent=nf
    table.insert(notifs,{f=nf})
    safe(function()
        twe:Create(nf, TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            {Position=UDim2.new(1,-260,1,-(#notifs*62+16))}):Play()
    end)
    spawn(function()
        wait(dur)
        safe(function()
            nf:Destroy()
            for i,n in ipairs(notifs) do if n.f==nf then table.remove(notifs,i); break end end
            for i,n in ipairs(notifs) do safe(function()
                twe:Create(n.f,TweenInfo.new(0.2),{Position=UDim2.new(1,-260,1,-(i*62+16))}):Play()
            end) end
        end)
    end)
end

-- ====== SCREENGUI ======
local sg = Instance.new("ScreenGui")
sg.Name = "ScriptHubUI"; sg.ResetOnSpawn = false; sg.Parent = parent
safe(function() sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
mainJanitor:add(sg)

-- Notif layer
local notifLayer = Instance.new("Frame")
notifLayer.Size=UDim2.new(1,0,1,0); notifLayer.BackgroundTransparency=1; notifLayer.Parent=sg

-- ====== DRAG SYSTEM ======
local dragOn, ds, sp

-- ====== MAIN WINDOW ======
local win = Instance.new("Frame")
win.Size=UDim2.new(0,620,0,460); win.Position=UDim2.new(0.5,-310,0.5,-230)
win.BackgroundColor3=C.Bg; win.BorderSizePixel=0; win.Parent=sg
corner(win,UDim2.new(0,10))

-- Title bar
local tb = Instance.new("Frame")
tb.Size=UDim2.new(1,0,0,38); tb.BackgroundColor3=C.Surf; tb.BorderSizePixel=0; tb.Parent=win
corner(tb,UDim2.new(0,10))
local tc = Instance.new("Frame")
tc.Size=UDim2.new(1,0,0,10); tc.Position=UDim2.new(0,0,1,-10)
tc.BackgroundColor3=C.Surf; tc.BorderSizePixel=0; tc.Parent=tb

-- Title label
local tt = Instance.new("TextLabel")
tt.Position=UDim2.new(0,0,0,0); tt.Size=UDim2.new(0.6,0,1,0)
tt.BackgroundTransparency=1; tt.Text="  Script Hub"; tt.TextColor3=C.Txt2
tt.Font=FB; tt.TextSize=13; tt.TextYAlignment=Enum.TextYAlignment.Center
tt.TextXAlignment=Enum.TextXAlignment.Left; tt.Parent=tb

-- Close button
local cb = Instance.new("TextButton")
cb.Size=UDim2.new(0,30,0,28); cb.Position=UDim2.new(1,-38,0,5)
cb.BackgroundColor3=C.Red; cb.Text="X"; cb.TextColor3=C.Wht
cb.Font=FB; cb.TextSize=18; cb.BorderSizePixel=0; cb.Parent=tb
corner(cb,UDim2.new(0,6))
cb.MouseButton1Click:Connect(function()
    mainJanitor:clean(); sg:Destroy()
end)

-- Minimise button
local mb = Instance.new("TextButton")
mb.Size=UDim2.new(0,30,0,28); mb.Position=UDim2.new(1,-74,0,5)
mb.BackgroundColor3=C.Surf2; mb.Text="_"; mb.TextColor3=C.Txt2
mb.Font=FB; mb.TextSize=18; mb.BorderSizePixel=0; mb.Parent=tb
corner(mb,UDim2.new(0,6))
local minimised = false
mb.MouseButton1Click:Connect(function()
    minimised = not minimised
    if body then body.Visible = not minimised end
    safe(function()
        twe:Create(win,TweenInfo.new(0.2,Enum.EasingStyle.Quad),
            {Size=minimised and UDim2.new(0,620,0,38) or UDim2.new(0,620,0,460)}):Play()
    end)
end)

-- Dragging
tb.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragOn=true; ds=inp.Position; sp=win.Position
    end
end)
tb.InputChanged:Connect(function(inp)
    if dragOn and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d=inp.Position-ds
        win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
    end
end)
uis.InputEnded:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragOn=false end
end)

-- ====== BODY ======
local body = Instance.new("Frame")
body.Name="Body"; body.Size=UDim2.new(1,0,1,-38); body.Position=UDim2.new(0,0,0,38)
body.BackgroundTransparency=1; body.BorderSizePixel=0; body.Parent=win
safe(function() body.ClipsDescendants=true end)

-- Tab bar
local tbar = Instance.new("Frame")
tbar.Size=UDim2.new(1,0,0,32); tbar.BackgroundColor3=C.Surf; tbar.BorderSizePixel=0; tbar.Parent=body

-- Tab content area
local tcontent = Instance.new("Frame")
tcontent.Size=UDim2.new(1,0,1,-32); tcontent.Position=UDim2.new(0,0,0,32)
tcontent.BackgroundColor3=C.Bg; tcontent.BorderSizePixel=0; tcontent.Parent=body

-- ====== TAB SYSTEM ======
local tabs = {}
local activeTab = nil

local function switchTab(id)
    for _,t in ipairs(tabs) do
        if t.id == id then
            t.btn.BackgroundColor3 = Color3.new(0.13,0.13,0.17)
            t.btn.TextColor3 = C.Txt
            t.scroll.Visible = true
            activeTab = id
        else
            t.btn.BackgroundColor3 = C.Surf
            t.btn.TextColor3 = C.Txt3
            t.scroll.Visible = false
        end
    end
end

local function createTab(name)
    local id = #tabs + 1
    local tw = 0.2

    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(tw,-2,1,0); btn.Position=UDim2.new((id-1)*tw,0,0,0)
    btn.BackgroundColor3=C.Surf; btn.Text=name; btn.TextColor3=C.Txt3
    btn.Font=FB; btn.TextSize=13; btn.BorderSizePixel=0; btn.Parent=tbar

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,0,1,0); scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
    scroll.Visible=false; scroll.ScrollBarThickness=3
    scroll.ScrollBarImageColor3=Color3.new(0.18,0.18,0.20); scroll.ScrollBarImageTransparency=0
    scroll.CanvasSize=UDim2.new(0,0,0,4000); scroll.Parent=tcontent
    safe(function() scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y end)

    local lay = Instance.new("UIListLayout")
    lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=scroll
    safe(function() lay.Padding=UDim2.new(0,6) end)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft=UDim2.new(0,10); pad.PaddingRight=UDim2.new(0,10)
    pad.PaddingTop=UDim2.new(0,8); pad.PaddingBottom=UDim2.new(0,12)
    pad.Parent=scroll

    btn.MouseButton1Click:Connect(function() switchTab(id) end)

    local tab = {id=id, name=name, btn=btn, scroll=scroll}
    table.insert(tabs, tab)
    if id == 1 then switchTab(1) end
    return tab
end

-- ====== UI CONTROLS ======
local function section(tab, title)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,26); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))
    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(1,0,1,0); lb.Position=UDim2.new(0,8,0,0)
    lb.BackgroundTransparency=1; lb.Text="  "..title:upper(); lb.TextColor3=C.Acc
    lb.Font=FB; lb.TextSize=10; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f
    return f
end

local function toggle(tab, label, def, cb)
    def = def or false
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,H); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(0.7,0,1,0); lb.Position=UDim2.new(0,10,0,0)
    lb.BackgroundTransparency=1; lb.Text=label; lb.TextColor3=C.Txt
    lb.Font=F; lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f

    local tf = Instance.new("Frame")
    tf.Size=UDim2.new(0,40,0,20); tf.Position=UDim2.new(1,-50,0.5,-10)
    tf.BackgroundColor3=C.Surf2; tf.BorderSizePixel=0; tf.Parent=f
    corner(tf,UDim2.new(0,10))

    local kn = Instance.new("Frame")
    kn.Size=UDim2.new(0,16,0,16); kn.Position=UDim2.new(0,2,0.5,-8)
    kn.BackgroundColor3=C.Txt3; kn.BorderSizePixel=0; kn.Parent=tf
    corner(kn,UDim2.new(0,8))

    local on = def
    local function paint()
        tf.BackgroundColor3 = on and C.Acc or C.Surf2
        kn.Position = on and UDim2.new(0,22,0.5,-8) or UDim2.new(0,2,0.5,-8)
        kn.BackgroundColor3 = on and C.Wht or C.Txt3
    end
    local function flip() on=not on; paint(); cb(on) end

    tf.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then flip() end
    end)
    kn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then flip() end
    end)

    if def then spawn(function() on=def; paint() end) end
    return {Set=function(v) on=v; paint(); cb(v) end, Get=function() return on end, Frame=f}
end

local function slider(tab, label, min, max, def, step, cb)
    min=min or 0; max=max or 100; def=def or min; step=step or 1
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,50); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local row = Instance.new("Frame")
    row.Size=UDim2.new(1,-20,0,20); row.Position=UDim2.new(0,10,0,4)
    row.BackgroundTransparency=1; row.Parent=f

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(0.5,0,1,0); lb.BackgroundTransparency=1
    lb.Text=label; lb.TextColor3=C.Txt; lb.Font=F; lb.TextSize=13
    lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=row

    local vl = Instance.new("TextLabel")
    vl.Size=UDim2.new(0.5,0,1,0); vl.Position=UDim2.new(0.5,0,0,0)
    vl.BackgroundTransparency=1; vl.Text=tostring(def); vl.TextColor3=C.Acc
    vl.Font=FB; vl.TextSize=13; vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=row

    local tr = Instance.new("Frame")
    tr.Size=UDim2.new(1,-20,0,5); tr.Position=UDim2.new(0,10,0,30)
    tr.BackgroundColor3=C.Surf2; tr.BorderSizePixel=0; tr.Parent=f
    corner(tr,UDim2.new(0,3))

    local fl = Instance.new("Frame")
    fl.Size=UDim2.new((def-min)/(max-min),0,1,0); fl.BackgroundColor3=C.Acc
    fl.BorderSizePixel=0; fl.Parent=tr; corner(fl,UDim2.new(0,3))

    local cur = def; local drag = false
    local function set(inp)
        local rx = (inp.Position.X - tr.AbsolutePosition.X) / tr.AbsoluteSize.X
        rx = rx < 0 and 0 or rx > 1 and 1 or rx
        local v = min + (max-min)*rx
        v = math.floor(v/step+0.5)*step
        if v < min then v = min elseif v > max then v = max end
        cur=v; fl.Size=UDim2.new((v-min)/(max-min),0,1,0); vl.Text=tostring(v); cb(v)
    end
    tr.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; set(i) end
    end)
    uis.InputChanged:Connect(function(i)
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then set(i) end
    end)
    uis.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)

    return {
        Set=function(v)
            if v < min then v=min elseif v > max then v=max end
            v=math.floor(v/step+0.5)*step; cur=v
            fl.Size=UDim2.new((v-min)/(max-min),0,1,0); vl.Text=tostring(v); cb(v)
        end,
        Get=function() return cur end, Frame=f
    }
end

local function dropdown(tab, label, opts, def, cb)
    opts=opts or {}; def=def or (opts[1] or "")
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,H); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(0.35,0,1,0); lb.Position=UDim2.new(0,10,0,0)
    lb.BackgroundTransparency=1; lb.Text=label; lb.TextColor3=C.Txt
    lb.Font=F; lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f

    local sl = Instance.new("TextLabel")
    sl.Size=UDim2.new(0.5,0,1,0); sl.Position=UDim2.new(0.35,0,0,0)
    sl.BackgroundTransparency=1; sl.Text=tostring(def); sl.TextColor3=C.Acc
    sl.Font=F; sl.TextSize=13; sl.TextXAlignment=Enum.TextXAlignment.Right; sl.Parent=f

    local dl = Instance.new("Frame")
    dl.Size=UDim2.new(1,0,0,0); dl.BackgroundColor3=C.Surf2; dl.BorderSizePixel=0
    dl.Visible=false; dl.Parent=tab.scroll; corner(dl,UDim2.new(0,5))
    local lay2 = Instance.new("UIListLayout"); lay2.Parent=dl

    local open = false
    local function build()
        for _,c in ipairs(dl:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for _,o in ipairs(opts) do
            local ob = Instance.new("TextButton")
            ob.Size=UDim2.new(1,0,0,26); ob.BackgroundTransparency=1; ob.Text=tostring(o)
            ob.TextColor3=C.Txt; ob.Font=F; ob.TextSize=13; ob.Parent=dl
            ob.MouseButton1Click:Connect(function()
                sl.Text=tostring(o); open=false; dl.Visible=false; cb(o)
            end)
        end
        dl.Size=UDim2.new(1,0,0,#opts*26)
    end
    build()

    f.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then open=not open; dl.Visible=open end
    end)
    return {SetOptions=function(o) opts=o; build() end, Set=function(v) sl.Text=tostring(v); cb(v) end, Get=function() return sl.Text end, Frame=f}
end

local function textbox(tab, label, ph, def, cb)
    ph=ph or ""; def=def or ""
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,H); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(0,70,1,0); lb.Position=UDim2.new(0,10,0,0)
    lb.BackgroundTransparency=1; lb.Text=label; lb.TextColor3=C.Txt
    lb.Font=F; lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f

    local inp = Instance.new("TextBox")
    inp.Size=UDim2.new(1,-90,0,24); inp.Position=UDim2.new(0,80,0.5,-12)
    inp.BackgroundColor3=C.Surf2; inp.TextColor3=C.Txt
    inp.PlaceholderText=ph; inp.PlaceholderColor3=C.Txt3
    inp.Text=def; inp.Font=F; inp.TextSize=13
    inp.TextXAlignment=Enum.TextXAlignment.Left; inp.BorderSizePixel=0; inp.Parent=f
    corner(inp,UDim2.new(0,4))

    inp.FocusLost:Connect(function(ep) cb(inp.Text,ep) end)
    return {Set=function(v) inp.Text=v end, Get=function() return inp.Text end, Frame=f, Input=inp}
end

local function keybind(tab, label, dk, cb)
    dk = dk or Enum.KeyCode.Unknown
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,H); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(0.5,0,1,0); lb.Position=UDim2.new(0,10,0,0)
    lb.BackgroundTransparency=1; lb.Text=label; lb.TextColor3=C.Txt
    lb.Font=F; lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f

    local kb = Instance.new("TextButton")
    kb.Size=UDim2.new(0,90,0,24); kb.Position=UDim2.new(1,-100,0.5,-12)
    kb.BackgroundColor3=C.Surf2; kb.Text="[ ... ]"; kb.TextColor3=C.Txt3
    kb.Font=FC; kb.TextSize=10; kb.BorderSizePixel=0; kb.Parent=f
    corner(kb,UDim2.new(0,4))

    local bk = dk; local waiting = false
    if dk ~= Enum.KeyCode.Unknown then kb.Text = "["..dk.Name.."]" end

    kb.MouseButton1Click:Connect(function()
        waiting=true; kb.Text="[ ... ]"; kb.TextColor3=C.Yel
        local cn; cn = uis.InputBegan:Connect(function(i,gp)
            if waiting and i.UserInputType==Enum.UserInputType.Keyboard then
                waiting=false; bk=i.KeyCode; kb.TextColor3=C.Txt
                kb.Text="["..bk.Name.."]"; cn:Disconnect(); cb(bk)
            end
        end)
    end)
    return {Set=function(k) bk=k; kb.Text="["..k.Name.."]" end, Get=function() return bk end, Frame=f}
end

local function button(tab, label, cb)
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,H); f.BackgroundColor3=C.Acc; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local bt = Instance.new("TextButton")
    bt.Size=UDim2.new(1,0,1,0); bt.BackgroundTransparency=1
    bt.Text=label; bt.TextColor3=C.Wht; bt.Font=FB; bt.TextSize=13
    bt.BorderSizePixel=0; bt.Parent=f; bt.MouseButton1Click:Connect(cb)

    return {Frame=f, Btn=bt}
end

local function colorPicker(tab, label, dc, cb)
    dc = dc or Color3.new(1,1,1)
    local col = dc
    local f = Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,H); f.BackgroundColor3=C.Surf; f.BorderSizePixel=0
    f.Parent=tab.scroll; corner(f,UDim2.new(0,5))

    local lb = Instance.new("TextLabel")
    lb.Size=UDim2.new(0.5,0,1,0); lb.Position=UDim2.new(0,10,0,0)
    lb.BackgroundTransparency=1; lb.Text=label; lb.TextColor3=C.Txt
    lb.Font=F; lb.TextSize=13; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.Parent=f

    local pv = Instance.new("Frame")
    pv.Size=UDim2.new(0,22,0,22); pv.Position=UDim2.new(1,-34,0.5,-11)
    pv.BackgroundColor3=dc; pv.BorderSizePixel=0; pv.Parent=f
    corner(pv,UDim2.new(0,4))

    local ep = Instance.new("Frame")
    ep.Size=UDim2.new(1,0,0,0); ep.BackgroundColor3=C.Surf; ep.BorderSizePixel=0
    ep.Visible=false; ep.Parent=tab.scroll; corner(ep,UDim2.new(0,5))

    local expanded = false
    local function mkChan(ch, nm)
        local s = Instance.new("Frame")
        s.Size=UDim2.new(1,0,0,36); s.BackgroundTransparency=1; s.Parent=ep
        local ll=Instance.new("TextLabel")
        ll.Size=UDim2.new(0,16,1,0); ll.Position=UDim2.new(0,4,0,0)
        ll.BackgroundTransparency=1; ll.Text=nm; ll.TextColor3=C.Txt2
        ll.Font=FB; ll.TextSize=10; ll.TextXAlignment=Enum.TextXAlignment.Left; ll.Parent=s
        local t=Instance.new("Frame")
        t.Size=UDim2.new(1,-80,0,5); t.Position=UDim2.new(0,24,0.5,-3)
        t.BackgroundColor3=C.Surf2; t.BorderSizePixel=0; t.Parent=s; corner(t,UDim2.new(0,3))
        local fl=Instance.new("Frame")
        fl.Size=UDim2.new(col[ch]/255,0,1,0); fl.BorderSizePixel=0; fl.Parent=t; corner(fl,UDim2.new(0,3))
        fl.BackgroundColor3=Color3.new(nm=="R"and 1 or 0,nm=="G"and 1 or 0,nm=="B"and 1 or 0)
        local vl=Instance.new("TextLabel")
        vl.Size=UDim2.new(0,40,1,0); vl.Position=UDim2.new(1,-44,0,0); vl.BackgroundTransparency=1
        vl.Text=tostring(math.floor(col[ch])); vl.TextColor3=C.Txt2; vl.Font=F; vl.TextSize=10
        vl.TextXAlignment=Enum.TextXAlignment.Right; vl.Parent=s
        local d=false
        t.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then d=true
                local rx=(i.Position.X-t.AbsolutePosition.X)/t.AbsoluteSize.X
                rx=rx<0 and 0 or rx>1 and 1 or rx
                local v=math.floor(rx*255); local r,g,b=col.R,col.G,col.B
                if nm=="R" then r=v elseif nm=="G" then g=v elseif nm=="B" then b=v end
                col=Color3.new(r/255,g/255,b/255); fl.Size=UDim2.new(v/255,0,1,0)
                vl.Text=tostring(v); pv.BackgroundColor3=col; cb(col)
            end
        end)
        uis.InputChanged:Connect(function(i)
            if d and i.UserInputType==Enum.UserInputType.MouseMovement then
                local rx=(i.Position.X-t.AbsolutePosition.X)/t.AbsoluteSize.X
                rx=rx<0 and 0 or rx>1 and 1 or rx
                local v=math.floor(rx*255); local r,g,b=col.R,col.G,col.B
                if nm=="R" then r=v elseif nm=="G" then g=v elseif nm=="B" then b=v end
                col=Color3.new(r/255,g/255,b/255); fl.Size=UDim2.new(v/255,0,1,0)
                vl.Text=tostring(v); pv.BackgroundColor3=col; cb(col)
            end
        end)
        uis.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end
        end)
        return fl,vl
    end
    local rf,rv=mkChan("R","R"); local gf,gv=mkChan("G","G"); local bf,bv=mkChan("B","B")
    f.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            expanded=not expanded
            if expanded then ep.Size=UDim2.new(1,0,0,108); ep.Visible=true else ep.Visible=false end
        end
    end)
    return {
        Set=function(c) col=c; pv.BackgroundColor3=c
            rf.Size=UDim2.new(c.R/255,0,1,0); gf.Size=UDim2.new(c.G/255,0,1,0)
            bf.Size=UDim2.new(c.B/255,0,1,0); rv.Text=tostring(math.floor(c.R))
            gv.Text=tostring(math.floor(c.G)); bv.Text=tostring(math.floor(c.B)) end,
        Get=function() return col end, Frame=f,
    }
end

-- ====== CREATE 5 TABS ======
local uTab = createTab("Universal")
local eTab = createTab("Executor")
local vTab = createTab("Viewport")
local pTab = createTab("Prompt Gen")
local sTab = createTab("Save/Load")

print("[SH] Tabs created")

-- Shared code-input bridge (declared here, assigned in Executor tab)
local codeInput
notify("Script Hub", "Ready. All in one file, no external deps.", 4, "success")

-- ====== STORAGE ======
local store = {} -- {key=value} in-memory
local function getStore(k, d) return store[k] ~= nil and store[k] or d end
local function setStore(k, v) store[k] = v end

-- =============================================
-- TAB CONTENT BELOW — everything self-contained
-- =============================================

-- ═══════ TAB 1: UNIVERSAL ═══════
do
    local function getChar() return plr.Character end
    local function getHum() local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
    local function getHRP() local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

    -- FLY
    do
        local flyOn, flySpd, bv, bg, loop = false, 50, nil, nil, nil

        local function en()
            if flyOn then return end; flyOn=true; print("[Fly] ON")
            local c=getChar(); if not c then flyOn=false; return end
            local hrp=getHRP(); if not hrp then flyOn=false; return end
            local hum=getHum(); if hum then hum.PlatformStand=true end
            bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.new(); bv.MaxForce=Vector3.new(1e6,1e6,1e6); bv.P=1250; bv.Parent=hrp
            bg=Instance.new("BodyGyro"); bg.CFrame=hrp.CFrame; bg.MaxTorque=Vector3.new(1e6,1e6,1e6); bg.P=30000; bg.D=100; bg.Parent=hrp
            mainJanitor:add(bv); mainJanitor:add(bg)
            loop=run.RenderStepped:Connect(function()
                if not flyOn then return end
                local chr=getChar(); if not chr or chr~=c then dis(); return end
                local r=getHRP(); if not r then dis(); return end
                local ca=cam; if not ca then return end; local mv=Vector3.new()
                if uis:IsKeyDown(Enum.KeyCode.W) then mv=mv+ca.CFrame.LookVector end
                if uis:IsKeyDown(Enum.KeyCode.S) then mv=mv-ca.CFrame.LookVector end
                if uis:IsKeyDown(Enum.KeyCode.A) then mv=mv-ca.CFrame.RightVector end
                if uis:IsKeyDown(Enum.KeyCode.D) then mv=mv+ca.CFrame.RightVector end
                if uis:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
                if uis:IsKeyDown(Enum.KeyCode.LeftShift) then mv=mv-Vector3.new(0,1,0) end
                if mv.Magnitude>0 then mv=mv.Unit*flySpd end
                if bv and bv.Parent then bv.Velocity=mv end
                if bg and bg.Parent then bg.CFrame=ca.CFrame end
            end)
            mainJanitor:addConn(loop)
            mainJanitor:addConn(plr.CharacterAdded:Connect(function() dis() end))
        end
        local function dis()
            flyOn=false; print("[Fly] OFF")
            if loop then safe(function() loop:Disconnect() end); loop=nil end
            if bv then safe(function() bv:Destroy() end); bv=nil end
            if bg then safe(function() bg:Destroy() end); bg=nil end
            local hum=getHum(); if hum then hum.PlatformStand=false end
        end

        section(uTab, "Fly")
        local ft = toggle(uTab, "Enable Fly", getStore("fly_on",false), function(v)
            setStore("fly_on",v); if v then en() else dis() end
        end)
        slider(uTab, "Fly Speed", 10, 500, getStore("fly_spd",50), 5, function(v)
            setStore("fly_spd",v); flySpd=v
        end)
        keybind(uTab, "Fly Key", getStore("fly_key",Enum.KeyCode.F), function(k) setStore("fly_key",k) end)

        if getStore("fly_on",false) then flySpd=getStore("fly_spd",50); en(); ft:Set(true) end
    end

    -- SPEED
    do
        local on,val,def = false,16,16
        plr.CharacterAdded:Connect(function(ch)
            if on then wait(0.5); local h=ch:FindFirstChildOfClass("Humanoid"); if h then def=h.WalkSpeed; h.WalkSpeed=val end end
        end)
        section(uTab, "Movement")
        toggle(uTab, "Speed Hack", getStore("spd_on",false), function(v)
            setStore("spd_on",v); on=v
            local h=getHum()
            if v then if h then def=h.WalkSpeed; h.WalkSpeed=val end
            elseif h then h.WalkSpeed=def end
        end)
        slider(uTab, "WalkSpeed", 16, 200, getStore("spd_val",16), 1, function(v)
            setStore("spd_val",v); val=v; if on then local h=getHum(); if h then h.WalkSpeed=v end end
        end)
    end

    -- JUMP
    do
        local on,val,def = false,50,50
        plr.CharacterAdded:Connect(function(ch)
            if on then wait(0.5); local h=ch:FindFirstChildOfClass("Humanoid"); if h then def=h.JumpPower or 50; h.JumpPower=val; safe(function() h.UseJumpPower=true; h.JumpHeight=val end) end end
        end)
        toggle(uTab, "Jump Power", getStore("jmp_on",false), function(v)
            setStore("jmp_on",v); on=v
            local h=getHum()
            if v then if h then def=h.JumpPower or 50; h.JumpPower=val; safe(function() h.UseJumpPower=true; h.JumpHeight=val end) end
            elseif h then h.JumpPower=def; safe(function() h.UseJumpPower=false end) end
        end)
        slider(uTab, "Jump Power", 0, 300, getStore("jmp_val",50), 5, function(v)
            setStore("jmp_val",v); val=v; if on then local h=getHum(); if h then h.JumpPower=v; safe(function() h.UseJumpPower=true; h.JumpHeight=v end) end end
        end)
    end

    -- ESP
    do
        local on,bxs,nms,dst,trc,tm,bc,tc,md = false,true,true,true,true,false,Color3.new(1,0,0),Color3.new(1,1,1),500
        local data,loop = {},{}

        local function add(p)
            if data[p] then return end
            local d = {bb=nil,db=nil}
            local bb=Instance.new("BillboardGui")
            bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,200,0,20); bb.StudsOffset=Vector3.new(0,2.5,0); bb.MaxDistance=md
            local nl=Instance.new("TextLabel")
            nl.BackgroundTransparency=1; nl.Size=UDim2.new(1,0,1,0); nl.Text=p.Name
            nl.TextColor3=Color3.new(1,1,1); nl.Font=F; nl.TextSize=13; nl.Parent=bb
            d.bb=bb; mainJanitor:add(bb)
            local db2=Instance.new("BillboardGui")
            db2.AlwaysOnTop=true; db2.Size=UDim2.new(0,200,0,20); db2.StudsOffset=Vector3.new(0,-0.5,0); db2.MaxDistance=md
            local dl=Instance.new("TextLabel")
            dl.BackgroundTransparency=1; dl.Size=UDim2.new(1,0,1,0); dl.Text="0m"
            dl.TextColor3=Color3.new(0.78,0.78,0.78); dl.Font=F; dl.TextSize=12; dl.Parent=db2
            d.db=db2; mainJanitor:add(db2)
            local function att(ch)
                local hd=ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
                if hd then bb.Adornee=hd; db2.Adornee=hd end
            end
            if p.Character then att(p.Character) end
            d.ca=p.CharacterAdded:Connect(att); mainJanitor:addConn(d.ca)
            data[p]=d
        end
        local function del(p)
            local d=data[p]; if not d then return end
            if d.bb then safe(function() d.bb:Destroy() end) end
            if d.db then safe(function() d.db:Destroy() end) end
            if d.ca then safe(function() d.ca:Disconnect() end) end
            data[p]=nil
        end
        local function hide(d)
            d.bb.Enabled=false; d.db.Enabled=false
        end
        local function tick()
            if not on then return end
            local mt=tm and plr.Team; local ca=cam; if not ca then return end; local vs=ca.ViewportSize
            for p,d in pairs(data) do
                local ch=p.Character
                if not ch then hide(d); goto nxt end
                if mt and p.Team==mt then hide(d); goto nxt end
                local hd=ch:FindFirstChild("Head"); local hrp=ch:FindFirstChild("HumanoidRootPart")
                if not hd or not hrp then hide(d); goto nxt end
                local pos=hd.Position; local sp,onScr=ca:WorldToViewportPoint(pos)
                local myC=getChar(); local dist=0
                if myC and myC:FindFirstChild("HumanoidRootPart") then dist=(myC.HumanoidRootPart.Position-pos).Magnitude end
                if dist>md then hide(d); goto nxt end
                d.bb.Enabled=nms and onScr; d.bb.MaxDistance=md
                d.db.Enabled=dst and onScr; d.db.MaxDistance=md
                if dst then safe(function() d.db:FindFirstChildOfClass("TextLabel").Text=string.format("%.0fm",dist) end) end
                ::nxt::
            end
        end
        local function en()
            if on then return end; on=true; print("[ESP] ON")
            for _,p in ipairs(game:GetService("Players"):GetPlayers()) do if p~=plr then add(p) end end
            mainJanitor:addConn(game:GetService("Players").PlayerAdded:Connect(function(p) if on and p~=plr then add(p) end end))
            mainJanitor:addConn(game:GetService("Players").PlayerRemoving:Connect(function(p) del(p) end))
            loop=run.RenderStepped:Connect(tick); mainJanitor:addConn(loop)
        end
        local function dis()
            on=false; print("[ESP] OFF")
            if loop then safe(function() loop:Disconnect() end); loop=nil end
            for p,d in pairs(data) do del(p) end; data={}
        end

        section(uTab, "ESP")
        toggle(uTab, "Enable ESP", getStore("esp_on",false), function(v)
            setStore("esp_on",v); if v then en() else dis() end
        end)
        toggle(uTab, "Show Names", getStore("esp_nms",true), function(v) setStore("esp_nms",v); nms=v end)
        toggle(uTab, "Show Distance", getStore("esp_dst",true), function(v) setStore("esp_dst",v); dst=v end)
        toggle(uTab, "Team Check", getStore("esp_tm",false), function(v) setStore("esp_tm",v); tm=v end)
        slider(uTab, "Max Distance", 50, 2000, getStore("esp_md",500), 50, function(v) setStore("esp_md",v); md=v end)

        if getStore("esp_on",false) then
            nms=getStore("esp_nms",true); dst=getStore("esp_dst",true)
            tm=getStore("esp_tm",false); md=getStore("esp_md",500)
            en()
        end
    end

    -- AIMLOCK
    do
        local on,tog,held,tm,fov,part,smooth,tmCk = false,false,false,"crosshair",200,"Head",5,false
        local loop

        local function en()
            if on then return end; on=true; print("[Aim] ON")
            loop=run.RenderStepped:Connect(function()
                if not on then return end
                local ca=cam; if not ca then return end
                if not held then return end
                local mt=tmCk and plr.Team; local best,bestSc=nil,math.huge; local myC=getChar()
                for _,p in ipairs(game:GetService("Players"):GetPlayers()) do
                    if p==plr then goto n end
                    local ch=p.Character; if not ch then goto n end
                    if mt and p.Team==mt then goto n end
                    local tp=ch:FindFirstChild(part); if not tp then goto n end
                    local sp,onScr=ca:WorldToViewportPoint(tp.Position); if not onScr then goto n end
                    local ctr=Vector2.new(ca.ViewportSize.X/2,ca.ViewportSize.Y/2)
                    local dc=(Vector2.new(sp.X,sp.Y)-ctr).Magnitude; if dc>fov then goto n end
                    local sc=tm=="crosshair" and dc or (myC and myC:FindFirstChild("HumanoidRootPart") and (myC.HumanoidRootPart.Position-tp.Position).Magnitude or dc)
                    if sc<bestSc then bestSc=sc; best=tp end
                    ::n::
                end
                if best then local look=CFrame.lookAt(ca.CFrame.Position,best.Position); ca.CFrame=smooth>0.01 and ca.CFrame:Lerp(look,smooth/10) or look end
            end)
            mainJanitor:addConn(loop)
        end
        local function dis()
            on=false; held=false; print("[Aim] OFF")
            if loop then safe(function() loop:Disconnect() end); loop=nil end
        end

        section(uTab, "Aimlock")
        toggle(uTab, "Enable Aimlock", getStore("aim_on",false), function(v)
            setStore("aim_on",v); if v then en() else dis() end
        end)
        dropdown(uTab, "Mode", {"hold","toggle"}, getStore("aim_mode","hold"), function(v) setStore("aim_mode",v); tog=(v=="toggle") end)
        dropdown(uTab, "Target Part", {"Head","HumanoidRootPart","UpperTorso"}, getStore("aim_part","Head"), function(v) setStore("aim_part",v); part=v end)
        slider(uTab, "FOV Radius", 30, 800, getStore("aim_fov",200), 5, function(v) setStore("aim_fov",v); fov=v end)
        slider(uTab, "Smoothness", 1, 20, getStore("aim_smooth",5), 1, function(v) setStore("aim_smooth",v); smooth=v end)
        toggle(uTab, "Team Check", getStore("aim_tm",false), function(v) setStore("aim_tm",v); tmCk=v end)
        local ak = keybind(uTab, "Aim Key", getStore("aim_key",Enum.KeyCode.E), function(k) setStore("aim_key",k) end)

        uis.InputBegan:Connect(function(i,gp)
            if i.KeyCode==getStore("aim_key",Enum.KeyCode.E) then
                if tog then held=not held else held=true end
            end
        end)
        uis.InputEnded:Connect(function(i)
            if i.KeyCode==getStore("aim_key",Enum.KeyCode.E) then
                if not tog then held=false end
            end
        end)

        if getStore("aim_on",false) then
            tog=(getStore("aim_mode","hold")=="toggle"); part=getStore("aim_part","Head")
            fov=getStore("aim_fov",200); smooth=getStore("aim_smooth",5)
            tmCk=getStore("aim_tm",false); en()
        end
    end

    print("[SH] Universal tab done")
end

-- ═══════ TAB 2: EXECUTOR ═══════
do
    print("[SH] Building Executor tab...")
    local outLines = {}

    section(eTab, "Code Input")
    local cf = Instance.new("Frame")
    cf.Size=UDim2.new(1,-20,0,150); cf.BackgroundColor3=Color3.new(0.04,0.04,0.05)
    cf.BorderSizePixel=0; cf.Parent=eTab.scroll; corner(cf,UDim2.new(0,6))

    codeInput = Instance.new("TextBox")
    codeInput.Size=UDim2.new(1,-12,1,-12); codeInput.Position=UDim2.new(0,6,0,6)
    codeInput.BackgroundTransparency=1; codeInput.TextColor3=C.Txt
    codeInput.PlaceholderText="Enter Lua code..."; codeInput.PlaceholderColor3=C.Txt3
    codeInput.Text="print('Hello from Executor!')"
    codeInput.Font=FC; codeInput.TextSize=12
    codeInput.TextXAlignment=Enum.TextXAlignment.Left; codeInput.TextYAlignment=Enum.TextYAlignment.Top
    codeInput.MultiLine=true; codeInput.ClearTextOnFocus=false; codeInput.Parent=cf

    local br = Instance.new("Frame")
    br.Size=UDim2.new(1,-20,0,36); br.BackgroundTransparency=1; br.Parent=eTab.scroll

    local exB = button(eTab, "Execute", function() end)
    exB.Frame.Size=UDim2.new(0.32,-3,0,34); exB.Frame.Parent=br

    local clB = button(eTab, "Clear Output", function() end)
    clB.Frame.Size=UDim2.new(0.32,-3,0,34); clB.Frame.Position=UDim2.new(0.34,1,0,0)
    clB.Frame.BackgroundColor3=C.Surf2; clB.Frame.Parent=br

    local stB = button(eTab, "Stop Script", function() end)
    stB.Frame.Size=UDim2.new(0.32,0,0,34); stB.Frame.Position=UDim2.new(0.68,2,0,0)
    stB.Frame.BackgroundColor3=Color3.new(0.7,0.2,0.2); stB.Frame.Parent=br

    section(eTab, "Output")
    local of = Instance.new("ScrollingFrame")
    of.Size=UDim2.new(1,-20,0,140); of.BackgroundColor3=Color3.new(0.04,0.04,0.05)
    of.BorderSizePixel=0; of.ScrollBarThickness=3
    of.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
    of.CanvasSize=UDim2.new(0,0,0,5000); of.Parent=eTab.scroll
    corner(of,UDim2.new(0,6))
    safe(function() of.AutomaticCanvasSize=Enum.AutomaticSize.Y end)
    Instance.new("UIListLayout",of).SortOrder=Enum.SortOrder.LayoutOrder
    local opad=Instance.new("UIPadding",of)
    opad.PaddingLeft=UDim2.new(0,6); opad.PaddingRight=UDim2.new(0,6); opad.PaddingTop=UDim2.new(0,4)

    -- Viewport setup (ScreenGui for executed scripts)
    local outGui
    do
        local op = getSafeParent()
        local old = op:FindFirstChild("ExecutorOutputGui")
        if old then safe(function() old:Destroy() end) end
        outGui = Instance.new("ScreenGui")
        outGui.Name="ExecutorOutputGui"; outGui.ResetOnSpawn=false; outGui.Parent=op
        mainJanitor:add(outGui)
        safe(function() outGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling end)
    end

    local execJanitor

    local function addLine(txt,clr)
        local lb=Instance.new("TextLabel")
        lb.Size=UDim2.new(1,0,0,16); lb.BackgroundTransparency=1
        lb.Text=txt; lb.TextColor3=clr or C.Txt; lb.Font=FC; lb.TextSize=11
        lb.TextXAlignment=Enum.TextXAlignment.Left; lb.TextWrapped=true
        lb.Parent=of; table.insert(outLines,lb)
        if #outLines>300 then safe(function() table.remove(outLines,1):Destroy() end) end
        of.CanvasPosition=Vector2.new(0,99999)
    end
    local function clearOut()
        for _,l in ipairs(outLines) do safe(function() l:Destroy() end) end
        outLines={}
    end

    local function clearViewport()
        if execJanitor then execJanitor:clean(); execJanitor=nil end
        for _,c in ipairs(outGui:GetChildren()) do safe(function() c:Destroy() end) end
    end

    local function execute()
        local code = codeInput.Text
        if not code or code:match("^%s*$") then addLine("[!] No code.",C.Yel); return end
        clearOut(); addLine("[>] Executing...",C.Acc)
        clearViewport()
        execJanitor = janitor()

        local sTask = {}
        for k,v in pairs({spawn=spawn,wait=wait,delay=delay}) do
            if k=="spawn" then sTask[k]=function(fn,...) local a={...}; local th=spawn(function() fn(unpack(a)) end); execJanitor:add(th); return th end
            else sTask[k]=v end
        end

        local env = {
            game=game,workspace=workspace,Instance=Instance,
            Vector2=Vector2,Vector3=Vector3,CFrame=CFrame,Color3=Color3,UDim2=UDim2,
            TweenInfo=TweenInfo,Enum=Enum,Rect=Rect,Ray=Ray,
            task=sTask,pcall=pcall,xpcall=xpcall,
            math=math,string=string,table=table,coroutine=coroutine,
            next=next,ipairs=ipairs,pairs=pairs,select=select,unpack=unpack,
            type=type,tonumber=tonumber,tostring=tostring,assert=assert,
            wait=wait,tick=tick,time=time,spawn=spawn,
            TweenService=twe,UserInputService=uis,Players=game:GetService("Players"),RunService=run,
            ReplicatedStorage=game:GetService("ReplicatedStorage"),
            StarterGui=game:GetService("StarterGui"),
            SoundService=game:GetService("SoundService"),
            ExecutorGui=outGui,
            RegisterCleanup=function(fn) if type(fn)=="function" then execJanitor:add(fn) end end,
            print=function(...) local p={}; for i=1,select("#",...) do p[i]=tostring(select(i,...)) end; addLine("[PRINT] "..table.concat(p,"\t"),C.Txt2) end,
            warn=function(...) local p={}; for i=1,select("#",...) do p[i]=tostring(select(i,...)) end; addLine("[WARN] "..table.concat(p,"\t"),C.Yel) end,
            error=function(msg,lvl) addLine("[ERROR] "..tostring(msg),C.Red); error(msg,(lvl or 1)+1) end,
        }

        local fn, cerr = loadstring(code,"Executor")
        if not fn then addLine("[COMPILE] "..tostring(cerr),C.Red); return end

        safe(function() if setfenv then setfenv(fn,env) end end)
        safe(function() if getfenv then local e=getfenv(fn); for k,v in pairs(env) do e[k]=v end end end)

        addLine("[>] Running...",C.Acc)
        local ok,res = pcall(fn)
        if not ok then addLine("[RUNTIME] "..tostring(res),C.Red)
        else if res~=nil then addLine("[RETURN] "..tostring(res),C.Grn) end; addLine("[OK] Done.",C.Grn) end
    end

    exB.Btn.MouseButton1Click:Connect(execute)
    clB.Btn.MouseButton1Click:Connect(function() clearOut(); addLine("[>] Cleared.",C.Txt2) end)
    stB.Btn.MouseButton1Click:Connect(function() clearViewport(); clearOut(); addLine("[!] Stopped + cleared.",C.Yel) end)

    print("[SH] Executor tab done")
end

-- ═══════ TAB 3: VIEWPORT ═══════
do
    print("[SH] Building Viewport tab...")
    local outGui = parent:FindFirstChild("ExecutorOutputGui")
    if not outGui then
        outGui = Instance.new("ScreenGui")
        outGui.Name="ExecutorOutputGui"; outGui.ResetOnSpawn=false; outGui.Parent=getSafeParent()
        mainJanitor:add(outGui)
        safe(function() outGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling end)
    end

    local sf = Instance.new("Frame")
    sf.Size=UDim2.new(1,-20,0,52); sf.BackgroundColor3=C.Surf; sf.BorderSizePixel=0
    sf.Parent=vTab.scroll; corner(sf,UDim2.new(0,6))

    local sl = Instance.new("TextLabel")
    sl.Size=UDim2.new(1,-20,1,0); sl.Position=UDim2.new(0,10,0,0)
    sl.BackgroundTransparency=1; sl.Text="No script is executing."
    sl.TextColor3=C.Txt2; sl.Font=F; sl.TextSize=12
    sl.TextXAlignment=Enum.TextXAlignment.Left; sl.TextYAlignment=Enum.TextYAlignment.Center
    sl.TextWrapped=true; sl.Parent=sf

    local mf = Instance.new("ScrollingFrame")
    mf.Size=UDim2.new(1,-20,0,120); mf.BackgroundColor3=Color3.new(0.04,0.04,0.05)
    mf.BorderSizePixel=0; mf.ScrollBarThickness=3
    mf.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
    mf.CanvasSize=UDim2.new(0,0,0,3000); mf.Parent=vTab.scroll
    corner(mf,UDim2.new(0,6))
    safe(function() mf.AutomaticCanvasSize=Enum.AutomaticSize.Y end)
    Instance.new("UIListLayout",mf).SortOrder=Enum.SortOrder.LayoutOrder
    local vpad = Instance.new("UIPadding",mf)
    vpad.PaddingLeft=UDim2.new(0,8); vpad.PaddingRight=UDim2.new(0,8); vpad.PaddingTop=UDim2.new(0,6)

    local function refresh()
        for _,c in ipairs(mf:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
        local kids={}
        for _,c in ipairs(outGui:GetChildren()) do if c:IsA("GuiObject") then table.insert(kids,c) end end
        if #kids==0 then
            local el=Instance.new("TextLabel")
            el.Size=UDim2.new(1,0,0,18); el.BackgroundTransparency=1; el.Text="  (empty)"
            el.TextColor3=C.Txt3; el.Font=FC; el.TextSize=11; el.TextXAlignment=Enum.TextXAlignment.Left
            el.Parent=mf
        else
            sl.Text=tostring(#kids).." GUI element(s) mounted."
            for _,c in ipairs(kids) do
                local en=Instance.new("TextLabel")
                en.Size=UDim2.new(1,0,0,16); en.BackgroundTransparency=1
                en.Text="  "..c.ClassName..": "..c.Name
                en.TextColor3=Color3.new(0.67,0.82,0.67); en.Font=FC; en.TextSize=11
                en.TextXAlignment=Enum.TextXAlignment.Left; en.Parent=mf
            end
        end
    end

    run.Heartbeat:Connect(refresh)
    print("[SH] Viewport tab done")
end

-- ═══════ TAB 4: PROMPT GENERATOR ═══════
do
    local prompt = [[You are writing a Roblox Lua script that will be run through a custom LocalScript "Executor" tab.

Rules:
1. Do not use RemoteEvents, RemoteFunctions, or any server-side code. This is a pure client-side LocalScript sandbox.
2. If your script creates any GUI, parent ALL GUI Instances to the global variable `ExecutorGui` that is provided in scope. Do not create your own ScreenGui and parent it to PlayerGui or CoreGui directly.
3. If you create any RBXScriptConnections, RenderStepped/Heartbeat bindings, or task.spawn loops, register a cleanup callback using the provided global function `RegisterCleanup(function() ... end)` so they can be disconnected/cancelled automatically when the script is replaced.
4. Use `print`, `warn`, and `error` normally — they are captured and shown in the Executor's output log.
5. Keep the entire script self-contained in one code block with no external dependencies beyond what a normal Roblox client LocalScript can access.
6. Wrap risky operations in pcall.

Now write a script that does the following: <DESCRIBE WHAT YOU WANT HERE>]]

    local df = Instance.new("Frame")
    df.Size=UDim2.new(1,-20,0,32); df.BackgroundTransparency=1; df.Parent=pTab.scroll
    local dl = Instance.new("TextLabel")
    dl.Size=UDim2.new(1,0,1,0); dl.BackgroundTransparency=1
    dl.Text="Copy this prompt into any AI chat to generate Executor scripts."
    dl.TextColor3=C.Txt2; dl.Font=F; dl.TextSize=11
    dl.TextXAlignment=Enum.TextXAlignment.Left; dl.TextWrapped=true; dl.Parent=df

    local pf = Instance.new("ScrollingFrame")
    pf.Size=UDim2.new(1,-20,0,240); pf.BackgroundColor3=Color3.new(0.04,0.04,0.05)
    pf.BorderSizePixel=0; pf.ScrollBarThickness=3
    pf.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
    pf.CanvasSize=UDim2.new(0,0,0,600); pf.Parent=pTab.scroll
    corner(pf,UDim2.new(0,6))

    local pl = Instance.new("TextLabel")
    pl.Size=UDim2.new(1,-16,0,580); pl.Position=UDim2.new(0,8,0,8)
    pl.BackgroundTransparency=1; pl.Text=prompt; pl.TextColor3=C.Txt
    pl.Font=FC; pl.TextSize=11
    pl.TextXAlignment=Enum.TextXAlignment.Left; pl.TextYAlignment=Enum.TextYAlignment.Top
    pl.TextWrapped=true; pl.TextEditable=false; pl.Selectable=true; pl.Parent=pf

    local br2 = Instance.new("Frame")
    br2.Size=UDim2.new(1,-20,0,36); br2.BackgroundTransparency=1; br2.Parent=pTab.scroll

    local cp = button(pTab, "Copy to Clipboard", function()
        local ok = pcall(function() if setclipboard then setclipboard(prompt) end end)
        if ok then notify("Copied","Prompt copied.",3,"success")
        else notify("Copy failed","setclipboard not available.",4,"warning") end
    end)
    cp.Frame.Size=UDim2.new(0.48,-2,0,34); cp.Frame.Parent=br2

    local sa = button(pTab, "Select All Text", function()
        safe(function() pl.SelectionStart=0 end)
    end)
    sa.Frame.Size=UDim2.new(0.48,-2,0,34); sa.Frame.Position=UDim2.new(0.52,2,0,0)
    sa.Frame.BackgroundColor3=C.Acc2; sa.Frame.Parent=br2

    print("[SH] Prompt tab done")
end

-- ═══════ TAB 5: SAVE/LOAD ═══════
do
    local scripts = {} -- {name,timestamp,code}

    section(sTab, "Save Current Script")
    local nmTb = textbox(sTab, "Name", "My Script", "", function() end)
    local svB = button(sTab, "Save Current", function()
        local nm = nmTb.Get(); if not nm or nm=="" then nm="Untitled" end
        local code = codeInput.Text
        if not code or code:match("^%s*$") then notify("Empty","Enter code in Executor tab first.",3,"warning"); return end
        table.insert(scripts,{name=nm,timestamp=os.date("%Y-%m-%d %H:%M:%S"),code=code})
        refreshSaves()
        notify("Saved","Script saved.",3,"success")
    end)

    section(sTab, "Saved Scripts")
    local lst = Instance.new("ScrollingFrame")
    lst.Size=UDim2.new(1,-20,0,160); lst.BackgroundColor3=Color3.new(0.04,0.04,0.05)
    lst.BorderSizePixel=0; lst.ScrollBarThickness=3
    lst.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
    lst.CanvasSize=UDim2.new(0,0,0,3000); lst.Parent=sTab.scroll
    corner(lst,UDim2.new(0,6))
    safe(function() lst.AutomaticCanvasSize=Enum.AutomaticSize.Y end)
    Instance.new("UIListLayout",lst).SortOrder=Enum.SortOrder.LayoutOrder
    local spad=Instance.new("UIPadding",lst)
    spad.PaddingLeft=UDim2.new(0,6); spad.PaddingRight=UDim2.new(0,6); spad.PaddingTop=UDim2.new(0,6)

    local function refreshSaves()
        for _,c in ipairs(lst:GetChildren()) do if c:IsA("Frame") and c.Name=="Entry" then c:Destroy() end end
        if #scripts==0 then
            local el=Instance.new("TextLabel")
            el.Size=UDim2.new(1,0,0,20); el.BackgroundTransparency=1; el.Text="  (no saved scripts)"
            el.TextColor3=C.Txt3; el.Font=FC; el.TextSize=11; el.TextXAlignment=Enum.TextXAlignment.Left
            el.Parent=lst; return
        end
        for i,s in ipairs(scripts) do
            local en=Instance.new("Frame"); en.Name="Entry"
            en.Size=UDim2.new(1,0,0,32); en.BackgroundColor3=C.Surf2; en.Parent=lst
            corner(en,UDim2.new(0,4))

            local nl=Instance.new("TextLabel")
            nl.Size=UDim2.new(0.4,0,1,0); nl.Position=UDim2.new(0,8,0,0); nl.BackgroundTransparency=1
            nl.Text=s.name; nl.TextColor3=C.Txt; nl.Font=FB; nl.TextSize=12
            nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=en

            local tl=Instance.new("TextLabel")
            tl.Size=UDim2.new(0.3,0,1,0); tl.Position=UDim2.new(0.4,0,0,0); tl.BackgroundTransparency=1
            tl.Text=s.timestamp or ""; tl.TextColor3=C.Txt2; tl.Font=F; tl.TextSize=10
            tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=en

            local lb=Instance.new("TextButton")
            lb.Size=UDim2.new(0,44,0,22); lb.Position=UDim2.new(1,-98,0.5,-11)
            lb.BackgroundColor3=C.Acc; lb.Text="Load"; lb.TextColor3=C.Wht
            lb.Font=FB; lb.TextSize=11; lb.BorderSizePixel=0; lb.Parent=en
            corner(lb,UDim2.new(0,3))
            lb.MouseButton1Click:Connect(function()
                codeInput.Text = s.code
                switchTab(2) -- switch to Executor tab
                notify("Loaded","Script loaded into Executor.",2,"success")
            end)

            local db=Instance.new("TextButton")
            db.Size=UDim2.new(0,44,0,22); db.Position=UDim2.new(1,-50,0.5,-11)
            db.BackgroundColor3=C.Red; db.Text="Del"; db.TextColor3=C.Wht
            db.Font=FB; db.TextSize=11; db.BorderSizePixel=0; db.Parent=en
            corner(db,UDim2.new(0,3))

            local ref=s
            db.MouseButton1Click:Connect(function()
                for j,scr in ipairs(scripts) do if scr==ref then table.remove(scripts,j); break end end
                refreshSaves()
            end)
        end
    end
    refreshSaves()

    print("[SH] SaveLoad tab done")
end

-- ====== DONE ======
print("[SH] ======================")
print("[SH] All tabs built. Ready!")
print("[SH] ======================")
