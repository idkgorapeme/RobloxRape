-- UILibrary.lua -- defensive modern UI framework
-- print() for errors, try() for cosmetics, direct assignment for essentials.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
-- font fallback
local FONT_MAIN = Enum.Font.Gotham  or 0
local FONT_BOLD = Enum.Font.GothamBold or FONT_MAIN
local FONT_MONO = Enum.Font.Code or FONT_MAIN

local function try(fn)
	pcall(fn)
end

-- safest possible parent for ScreenGui
local function safeParent()
	-- try CoreGui first
	local ok, probe = pcall(function()
		local p = game:GetService("CoreGui")
		-- actual test: can we create/destroy a child?
		local f = Instance.new("Frame")
		f.Parent = p
		f:Destroy()
		return p
	end)
	if ok and probe then return probe end

	-- fallback to PlayerGui
	return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- theme
local C = {
	Bg       = Color3.fromRGB(12, 12, 14),
	Surface  = Color3.fromRGB(22, 22, 26),
	Surface2 = Color3.fromRGB(30, 30, 36),
	Border   = Color3.fromRGB(38, 38, 44),
	Accent   = Color3.fromRGB(130, 110, 240),
	Accent2  = Color3.fromRGB(100, 80, 220),
	Text     = Color3.fromRGB(235, 235, 240),
	Text2    = Color3.fromRGB(150, 150, 160),
	Text3    = Color3.fromRGB(90, 90, 100),
	Green    = Color3.fromRGB(80, 200, 120),
	Red      = Color3.fromRGB(240, 70, 70),
	Yellow   = Color3.fromRGB(240, 200, 70),
	White    = Color3.fromRGB(255, 255, 255),
	TabOn    = Color3.fromRGB(34, 34, 42),
	TabOff   = Color3.fromRGB(22, 22, 26),
}

local function corner(f, r)
	try(function()
		Instance.new("UICorner", f).CornerRadius = r or UDim2.new(0, 6)
	end)
end

local function stroke(f, clr)
	try(function()
		local s = Instance.new("UIStroke")
		s.Color = clr or C.Border
		s.Thickness = 1
		s.Parent = f
	end)
end

local function label(parent, txt, col, fnt, sz)
	local lb = Instance.new("TextLabel")
	lb.BackgroundTransparency = 1
	lb.Text = txt
	lb.TextColor3 = col or C.Text
	lb.Font = fnt or FONT_MAIN
	lb.TextSize = sz or 14
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.Parent = parent
	return lb
end

-- notify storage
local notifs = {}

-- =====================================================================
-- UILibrary
-- =====================================================================

local UILibrary = {}
UILibrary.__index = UILibrary

function UILibrary.new(title)
	title = title or "Script Hub"
	print("[UI] Creating UILibrary: " .. title)

	local self = setmetatable({
		_title     = title,
		_tabs      = {},
		_activeTab = nil,
		_screenGui = nil,
		_mainFrame = nil,
		_notifs    = nil,
		_tabContent = nil,
	}, UILibrary)

	-- ScreenGui
	print("[UI] Creating ScreenGui...")
	local sg = Instance.new("ScreenGui")
	sg.Name = "ScriptHubUI"
	sg.ResetOnSpawn = false
	sg.Parent = safeParent()
	try(function() sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling end)
	self._screenGui = sg
	print("[UI] ScreenGui parented OK")

	-- Notif layer
	self._notifs = Instance.new("Frame")
	self._notifs.Size = UDim2.new(1, 0, 1, 0)
	self._notifs.BackgroundTransparency = 1
	self._notifs.Parent = sg

	-- Main window
	local win = Instance.new("Frame")
	win.Size = UDim2.new(0, 620, 0, 460)
	win.Position = UDim2.new(0.5, -310, 0.5, -230)
	win.BackgroundColor3 = C.Bg
	win.BorderSizePixel = 0
	win.Parent = sg
	self._mainFrame = win
	corner(win, UDim2.new(0, 10))
	stroke(win, C.Border)
	print("[UI] Main window created")

	-- Title bar
	local tbar = Instance.new("Frame")
	tbar.Size = UDim2.new(1, 0, 0, 38)
	tbar.BackgroundColor3 = C.Surface
	tbar.BorderSizePixel = 0
	tbar.Parent = win
	corner(tbar, UDim2.new(0, 10))
	-- corner cover
	local tc = Instance.new("Frame")
	tc.Size = UDim2.new(1, 0, 0, 10)
	tc.Position = UDim2.new(0, 0, 1, -10)
	tc.BackgroundColor3 = C.Surface
	tc.BorderSizePixel = 0
	tc.Parent = tbar

	label(tbar, "  " .. title, C.Text2, FONT_BOLD, 13)
		.Position = UDim2.new(0, 0, 0, 0)
		.Size = UDim2.new(0.6, 0, 1, 0)
		.TextYAlignment = Enum.TextYAlignment.Center

	-- Close btn
	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 30, 0, 28)
	close.Position = UDim2.new(1, -38, 0, 5)
	close.BackgroundColor3 = C.Red
	close.Text = "X"
	close.TextColor3 = C.White
	close.Font = FONT_BOLD
	close.TextSize = 18
	close.BorderSizePixel = 0
	close.Parent = tbar
	corner(close, UDim2.new(0, 6))
	close.MouseButton1Click:Connect(function()
		if self.OnClose then self.OnClose() end
		sg:Destroy()
	end)

	-- Minimise btn
	local min = Instance.new("TextButton")
	min.Size = UDim2.new(0, 30, 0, 28)
	min.Position = UDim2.new(1, -74, 0, 5)
	min.BackgroundColor3 = C.Surface2
	min.Text = "_"
	min.TextColor3 = C.Text2
	min.Font = FONT_BOLD
	min.TextSize = 18
	min.BorderSizePixel = 0
	min.Parent = tbar
	corner(min, UDim2.new(0, 6))
	min.MouseButton1Click:Connect(function()
		self._minimised = not self._minimised
		local body = win:FindFirstChild("Body")
		if body then body.Visible = not self._minimised end
		try(function()
			local sz = self._minimised and UDim2.new(0,620,0,38) or UDim2.new(0,620,0,460)
			TweenService:Create(win, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size=sz}):Play()
		end)
	end)

	-- Drag
	local dragOn, ds, sp
	tbar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragOn = true; ds = inp.Position; sp = win.Position
		end
	end)
	tbar.InputChanged:Connect(function(inp)
		if dragOn and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local d = inp.Position - ds
			win.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragOn = false end
	end)

	-- Body
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 1, -38)
	body.Position = UDim2.new(0, 0, 0, 38)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = win

	-- Tab bar
	self._tabBar = Instance.new("Frame")
	self._tabBar.Size = UDim2.new(1, 0, 0, 32)
	self._tabBar.BackgroundColor3 = C.Surface
	self._tabBar.BorderSizePixel = 0
	self._tabBar.Parent = body

	-- Tab content area
	self._tabContent = Instance.new("Frame")
	self._tabContent.Size = UDim2.new(1, 0, 1, -32)
	self._tabContent.Position = UDim2.new(0, 0, 0, 32)
	self._tabContent.BackgroundColor3 = C.Bg
	self._tabContent.BorderSizePixel = 0
	self._tabContent.Parent = body
	try(function() self._tabContent.ClipsDescendants = true end)

	print("[UI] Constructor done")
	return self
end

-- =====================================================================
-- TABS
-- =====================================================================
function UILibrary:CreateTab(name)
	print("[UI] CreateTab: " .. name)
	local id = #self._tabs + 1
	local tw = 0.2

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(tw, -2, 1, 0)
	btn.Position = UDim2.new((id-1)*tw, 0, 0, 0)
	btn.BackgroundColor3 = C.TabOff
	btn.Text = name
	btn.TextColor3 = C.Text3
	btn.Font = FONT_BOLD
	btn.TextSize = 13
	btn.BorderSizePixel = 0
	btn.Parent = self._tabBar

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Visible = false
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 56)
	scroll.ScrollBarImageTransparency = 0
	scroll.CanvasSize = UDim2.new(0, 0, 0, 4000)
	scroll.Parent = self._tabContent
	try(function() scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y end)

	local lay = Instance.new("UIListLayout")
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = scroll
	try(function() lay.Padding = UDim2.new(0, 6) end)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim2.new(0, 10)
	pad.PaddingRight  = UDim2.new(0, 10)
	pad.PaddingTop    = UDim2.new(0, 8)
	pad.PaddingBottom = UDim2.new(0, 12)
	pad.Parent = scroll

	btn.MouseButton1Click:Connect(function()
		self:SwitchTab(id)
	end)

	local tab = { id = id, name = name, button = btn, container = scroll, _ui = self }
	table.insert(self._tabs, tab)
	if id == 1 then self:SwitchTab(1) end
	print("[UI]   done")
	return tab
end

function UILibrary:SwitchTab(id)
	for _, t in ipairs(self._tabs) do
		if t.id == id then
			t.button.BackgroundColor3 = C.TabOn
			t.button.TextColor3 = C.Text
			t.container.Visible = true
			self._activeTab = id
		else
			t.button.BackgroundColor3 = C.TabOff
			t.button.TextColor3 = C.Text3
			t.container.Visible = false
		end
	end
end

-- =====================================================================
-- CONTROLS
-- =====================================================================
local H = 34

function UILibrary:Section(tab, title)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 26)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))
	label(f, "  " .. title:upper(), C.Accent, FONT_BOLD, 10)
		.Size = UDim2.new(1, 0, 1, 0)
	return f
end

function UILibrary:Toggle(tab, labelText, def, cb)
	def = def or false
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, H)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	label(f, "  " .. labelText, C.Text, FONT_MAIN, 13)
		.Size = UDim2.new(0.7, 0, 1, 0)

	local tf = Instance.new("Frame")
	tf.Size = UDim2.new(0, 40, 0, 20)
	tf.Position = UDim2.new(1, -50, 0.5, -10)
	tf.BackgroundColor3 = C.Surface2
	tf.BorderSizePixel = 0
	tf.Parent = f
	corner(tf, UDim2.new(0, 10))

	local kn = Instance.new("Frame")
	kn.Size = UDim2.new(0, 16, 0, 16)
	kn.Position = UDim2.new(0, 2, 0.5, -8)
	kn.BackgroundColor3 = C.Text3
	kn.BorderSizePixel = 0
	kn.Parent = tf
	corner(kn, UDim2.new(0, 8))

	local on = def
	local function paint()
		tf.BackgroundColor3 = on and C.Accent or C.Surface2
		kn.Position = on and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		kn.BackgroundColor3 = on and C.White or C.Text3
	end
	local function flip() on = not on; paint(); cb(on) end

	tf.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then flip() end
	end)
	kn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then flip() end
	end)

	if def then task.spawn(function() on=def; paint() end) end
	return { SetValue=function(v) on=v; paint(); cb(v) end, GetValue=function() return on end, Frame=f }
end

function UILibrary:Slider(tab, labelText, min, max, def, step, cb)
	min=min or 0; max=max or 100; def=def or min; step=step or 1
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 50)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 20)
	row.Position = UDim2.new(0, 10, 0, 4)
	row.BackgroundTransparency = 1
	row.Parent = f

	label(row, labelText, C.Text, FONT_MAIN, 13)
		.Size = UDim2.new(0.5, 0, 1, 0)

	local vl = label(row, tostring(def), C.Accent, FONT_BOLD, 13)
	vl.Size = UDim2.new(0.5, 0, 1, 0)
	vl.Position = UDim2.new(0.5, 0, 0, 0)
	vl.TextXAlignment = Enum.TextXAlignment.Right

	local tr = Instance.new("Frame")
	tr.Size = UDim2.new(1, -20, 0, 5)
	tr.Position = UDim2.new(0, 10, 0, 30)
	tr.BackgroundColor3 = C.Surface2
	tr.BorderSizePixel = 0
	tr.Parent = f
	corner(tr, UDim2.new(0, 3))

	local fl = Instance.new("Frame")
	fl.Size = UDim2.new((def-min)/(max-min), 0, 1, 0)
	fl.BackgroundColor3 = C.Accent
	fl.BorderSizePixel = 0
	fl.Parent = tr
	corner(fl, UDim2.new(0, 3))

	local cur = def
	local drag = false
	local function set(inp)
		local rx = math.clamp((inp.Position.X-tr.AbsolutePosition.X)/tr.AbsoluteSize.X, 0, 1)
		local v = min + (max-min)*rx
		v = math.floor(v/step+0.5)*step
		v = math.clamp(v, min, max)
		cur = v; fl.Size = UDim2.new((v-min)/(max-min), 0, 1, 0); vl.Text = tostring(v); cb(v)
	end
	tr.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=true; set(i) end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if drag and i.UserInputType == Enum.UserInputType.MouseMovement then set(i) end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
	end)

	return {
		SetValue=function(v) cur=math.clamp(v,min,max); cur=math.floor(cur/step+0.5)*step
			fl.Size=UDim2.new((cur-min)/(max-min),0,1,0); vl.Text=tostring(cur); cb(cur) end,
		GetValue=function() return cur end, Frame=f
	}
end

function UILibrary:Dropdown(tab, labelText, opts, def, cb)
	opts=opts or {}; def=def or (opts[1] or "")
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, H)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	label(f, labelText, C.Text, FONT_MAIN, 13)
		.Size = UDim2.new(0.35, 0, 1, 0)
		.Position = UDim2.new(0, 10, 0, 0)

	local sl = label(f, tostring(def), C.Accent, FONT_MAIN, 13)
	sl.Size = UDim2.new(0.5, 0, 1, 0)
	sl.Position = UDim2.new(0.35, 0, 0, 0)
	sl.TextXAlignment = Enum.TextXAlignment.Right

	local dl = Instance.new("Frame")
	dl.Size = UDim2.new(1, 0, 0, 0)
	dl.BackgroundColor3 = C.Surface2
	dl.BorderSizePixel = 0
	dl.Visible = false
	dl.Parent = tab.container
	corner(dl, UDim2.new(0, 5))
	stroke(dl)
	Instance.new("UIListLayout", dl)

	local open = false
	local function rebuild()
		for _,c in ipairs(dl:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		for _,o in ipairs(opts) do
			local ob = Instance.new("TextButton")
			ob.Size=UDim2.new(1,0,0,26); ob.BackgroundTransparency=1; ob.Text=tostring(o)
			ob.TextColor3=C.Text; ob.Font=FONT_MAIN; ob.TextSize=13; ob.Parent=dl
			ob.MouseButton1Click:Connect(function()
				sl.Text=tostring(o); open=false; dl.Visible=false; cb(o)
			end)
		end
		dl.Size = UDim2.new(1, 0, 0, #opts*26)
	end
	rebuild()

	f.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then open=not open; dl.Visible=open end
	end)
	return { SetOptions=function(o) opts=o; rebuild() end, SetValue=function(v) sl.Text=tostring(v); cb(v) end, GetValue=function() return sl.Text end, Frame=f }
end

function UILibrary:TextBox(tab, labelText, ph, def, cb)
	ph=ph or ""; def=def or ""
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, H)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	label(f, labelText, C.Text, FONT_MAIN, 13)
		.Size = UDim2.new(0, 70, 1, 0)
		.Position = UDim2.new(0, 10, 0, 0)

	local inp = Instance.new("TextBox")
	inp.Size = UDim2.new(1, -90, 0, 24)
	inp.Position = UDim2.new(0, 80, 0.5, -12)
	inp.BackgroundColor3 = C.Surface2
	inp.TextColor3 = C.Text
	inp.PlaceholderText = ph
	inp.PlaceholderColor3 = C.Text3
	inp.Text = def
	inp.Font = FONT_MAIN
	inp.TextSize = 13
	inp.TextXAlignment = Enum.TextXAlignment.Left
	inp.BorderSizePixel = 0
	inp.Parent = f
	corner(inp, UDim2.new(0, 4))
	try(function() inp.ClearTextOnFocus = false end)

	inp.FocusLost:Connect(function(ep) cb(inp.Text, ep) end)
	return { SetValue=function(v) inp.Text=v end, GetValue=function() return inp.Text end, Frame=f, Input=inp }
end

function UILibrary:Keybind(tab, labelText, dk, cb)
	dk = dk or Enum.KeyCode.Unknown
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, H)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	label(f, labelText, C.Text, FONT_MAIN, 13)
		.Size = UDim2.new(0.5, 0, 1, 0)
		.Position = UDim2.new(0, 10, 0, 0)

	local kb = Instance.new("TextButton")
	kb.Size = UDim2.new(0, 90, 0, 24)
	kb.Position = UDim2.new(1, -100, 0.5, -12)
	kb.BackgroundColor3 = C.Surface2
	kb.Text = "[ ... ]"
	kb.TextColor3 = C.Text3
	kb.Font = FONT_MONO
	kb.TextSize = 10
	kb.BorderSizePixel = 0
	kb.Parent = f
	corner(kb, UDim2.new(0, 4))

	local bk = dk; local wait = false
	if dk ~= Enum.KeyCode.Unknown then kb.Text = "[" .. dk.Name .. "]" end

	kb.MouseButton1Click:Connect(function()
		wait=true; kb.Text="[ ... ]"; kb.TextColor3=C.Yellow
		local cn; cn = UserInputService.InputBegan:Connect(function(i,gp)
			if wait and i.UserInputType == Enum.UserInputType.Keyboard then
				wait=false; bk=i.KeyCode; kb.TextColor3=C.Text
				kb.Text="["..bk.Name.."]"; cn:Disconnect(); cb(bk)
			end
		end)
	end)
	return { SetKey=function(k) bk=k; kb.Text="["..k.Name.."]" end, GetKey=function() return bk end, Frame=f }
end

function UILibrary:Button(tab, labelText, cb)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, H)
	f.BackgroundColor3 = C.Accent
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	local bt = Instance.new("TextButton")
	bt.Size = UDim2.new(1, 0, 1, 0)
	bt.BackgroundTransparency = 1
	bt.Text = labelText
	bt.TextColor3 = C.White
	bt.Font = FONT_BOLD
	bt.TextSize = 13
	bt.BorderSizePixel = 0
	bt.Parent = f
	bt.MouseButton1Click:Connect(cb)

	bt.MouseEnter:Connect(function()
		try(function() TweenService:Create(f, TweenInfo.new(0.12), {BackgroundColor3=C.Accent2}):Play() end)
	end)
	bt.MouseLeave:Connect(function()
		try(function() TweenService:Create(f, TweenInfo.new(0.12), {BackgroundColor3=C.Accent}):Play() end)
	end)
	return { Frame=f, Button=bt }
end

function UILibrary:ColorPicker(tab, labelText, dc, cb)
	dc = dc or Color3.fromRGB(255,255,255)
	local col = dc
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, H)
	f.BackgroundColor3 = C.Surface
	f.BorderSizePixel = 0
	f.Parent = tab.container
	corner(f, UDim2.new(0, 5))

	label(f, labelText, C.Text, FONT_MAIN, 13)
		.Size = UDim2.new(0.5, 0, 1, 0)
		.Position = UDim2.new(0, 10, 0, 0)

	local pv = Instance.new("Frame")
	pv.Size = UDim2.new(0, 22, 0, 22)
	pv.Position = UDim2.new(1, -34, 0.5, -11)
	pv.BackgroundColor3 = dc
	pv.BorderSizePixel = 0
	pv.Parent = f
	corner(pv, UDim2.new(0, 4))

	local ep = Instance.new("Frame")
	ep.Size = UDim2.new(1, 0, 0, 0)
	ep.BackgroundColor3 = C.Surface
	ep.BorderSizePixel = 0
	ep.Visible = false
	ep.Parent = tab.container
	corner(ep, UDim2.new(0, 5))

	local expanded = false

	local function mkChan(ch, nm)
		local s = Instance.new("Frame")
		s.Size=UDim2.new(1,0,0,36); s.BackgroundTransparency=1; s.Parent=ep
		label(s, nm, C.Text2, FONT_BOLD, 10)
			.Size=UDim2.new(0,16,1,0).Position=UDim2.new(0,4,0,0)
		local t=Instance.new("Frame")
		t.Size=UDim2.new(1,-80,0,5); t.Position=UDim2.new(0,24,0.5,-3)
		t.BackgroundColor3=C.Surface2; t.BorderSizePixel=0; t.Parent=s; corner(t,UDim2.new(0,3))
		local fl=Instance.new("Frame")
		fl.Size=UDim2.new(col[ch]/255,0,1,0); fl.BorderSizePixel=0; fl.Parent=t; corner(fl,UDim2.new(0,3))
		fl.BackgroundColor3=Color3.fromRGB(nm=="R"and 255 or 0,nm=="G"and 255 or 0,nm=="B"and 255 or 0)
		local vl=label(s, tostring(math.floor(col[ch])), C.Text2, FONT_MAIN, 10)
		vl.Size=UDim2.new(0,40,1,0); vl.Position=UDim2.new(1,-44,0,0); vl.TextXAlignment=Enum.TextXAlignment.Right
		local d=false
		t.InputBegan:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 then d=true
				local rx=math.clamp((i.Position.X-t.AbsolutePosition.X)/t.AbsoluteSize.X,0,1)
				local v=math.floor(rx*255); local r,g,b=col.R,col.G,col.B
				if nm=="R" then r=v elseif nm=="G" then g=v elseif nm=="B" then b=v end
				col=Color3.fromRGB(r,g,b); fl.Size=UDim2.new(v/255,0,1,0); vl.Text=tostring(v)
				pv.BackgroundColor3=col; cb(col)
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if d and i.UserInputType==Enum.UserInputType.MouseMovement then
				local rx=math.clamp((i.Position.X-t.AbsolutePosition.X)/t.AbsoluteSize.X,0,1)
				local v=math.floor(rx*255); local r,g,b=col.R,col.G,col.B
				if nm=="R" then r=v elseif nm=="G" then g=v elseif nm=="B" then b=v end
				col=Color3.fromRGB(r,g,b); fl.Size=UDim2.new(v/255,0,1,0); vl.Text=tostring(v)
				pv.BackgroundColor3=col; cb(col)
			end
		end)
		UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 then d=false end
		end)
		return fl, vl
	end

	local rf,rv=mkChan("R","R"); local gf,gv=mkChan("G","G"); local bf,bv=mkChan("B","B")
	f.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			expanded=not expanded
			if expanded then ep.Size=UDim2.new(1,0,0,108); ep.Visible=true else ep.Visible=false end
		end
	end)
	return {
		SetValue=function(c) col=c; pv.BackgroundColor3=c
			rf.Size=UDim2.new(c.R/255,0,1,0); gf.Size=UDim2.new(c.G/255,0,1,0)
			bf.Size=UDim2.new(c.B/255,0,1,0)
			rv.Text=tostring(math.floor(c.R)); gv.Text=tostring(math.floor(c.G))
			bv.Text=tostring(math.floor(c.B)) end,
		GetValue=function() return col end, Frame=f,
	}
end

-- =====================================================================
-- NOTIFICATIONS
-- =====================================================================
function UILibrary:Notify(title, msg, dur, ntype)
	dur = dur or 4
	ntype = ntype or "info"
	local col = C.Accent
	if ntype=="error" then col=C.Red elseif ntype=="success" then col=C.Green elseif ntype=="warning" then col=C.Yellow end

	local nf = Instance.new("Frame")
	nf.Size = UDim2.new(0, 240, 0, 54)
	nf.Position = UDim2.new(1, 10, 1, -(#notifs*62+16))
	nf.BackgroundColor3 = C.Surface
	nf.BorderSizePixel = 0
	nf.Parent = self._notifs
	corner(nf, UDim2.new(0, 6))
	stroke(nf)

	local bar = Instance.new("Frame")
	bar.Size=UDim2.new(0,3,1,0); bar.BackgroundColor3=col; bar.BorderSizePixel=0; bar.Parent=nf
	corner(bar, UDim2.new(0, 3))

	label(nf, title or "Note", C.Text, FONT_BOLD, 13)
		.Size=UDim2.new(1,-28,0,20).Position=UDim2.new(0,12,0,6)
	label(nf, msg or "", C.Text2, FONT_MAIN, 10)
		.Size=UDim2.new(1,-28,0,16).Position=UDim2.new(0,12,0,30)

	table.insert(notifs, {f=nf})
	try(function()
		TweenService:Create(nf, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Position=UDim2.new(1,-260,1,-(#notifs*62+16))}):Play()
	end)

	task.delay(dur, function()
		try(function()
			nf:Destroy()
			for i,n in ipairs(notifs) do if n.f==nf then table.remove(notifs,i); break end end
			for i,n in ipairs(notifs) do
				try(function()
					TweenService:Create(n.f, TweenInfo.new(0.2),
						{Position=UDim2.new(1,-260,1,-(i*62+16))}):Play()
				end)
			end
		end)
	end)
	return nf
end

function UILibrary:Destroy()
	pcall(function() self._screenGui:Destroy() end)
end

return UILibrary
