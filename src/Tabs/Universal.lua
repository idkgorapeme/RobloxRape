-- Universal.lua -- Tab 1: Fly, Speed, Jump, ESP, Aimlock
print("[Universal] Loading...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local WS = game:GetService("Workspace")
local Cam = WS.CurrentCamera
local LP = Players.LocalPlayer

-- Feature detects
local HAS_DRAWING = pcall(function() return Drawing end)
local HAS_BODY = pcall(function() local p=Instance.new("BodyVelocity"); p:Destroy() end)

local function getChar() return LP.Character end
local function getHum() local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP() local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ═══════════════════════════════════════════════════════════
-- FLY
-- ═══════════════════════════════════════════════════════════
local Fly={}
Fly.__index=Fly
function Fly.new(cl,s)
	return setmetatable({_on=false,_spd=50,_bv=nil,_bg=nil,_loop=nil,_chars={},_cleanup=cl},Fly)
end
function Fly:Enable()
	if self._on or not HAS_BODY then return end; self._on=true
	local c=getChar(); if not c then self._on=false; return end
	local hrp=getHRP(); if not hrp then self._on=false; return end
	local hum=getHum(); if hum then hum.PlatformStand=true end
	local bv=Instance.new("BodyVelocity")
	bv.Name="FV"; bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(1e6,1e6,1e6); bv.P=1250; bv.Parent=hrp
	self._bv=bv; self._cleanup:Add(bv)
	local bg=Instance.new("BodyGyro")
	bg.Name="FG"; bg.CFrame=hrp.CFrame; bg.MaxTorque=Vector3.new(1e6,1e6,1e6); bg.P=30000; bg.D=100; bg.Parent=hrp
	self._bg=bg; self._cleanup:Add(bg)
	self._loop=RunService.RenderStepped:Connect(function()
		if not self._on then return end
		local chr=getChar(); if not chr or chr~=c then self:Disable(); return end
		local r=getHRP(); if not r then self:Disable(); return end
		local cam=Cam; if not cam then return end
		local mv=Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then mv=mv+cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then mv=mv-cam.CFrame.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then mv=mv-cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then mv=mv+cam.CFrame.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv=mv-Vector3.new(0,1,0) end
		if mv.Magnitude>0 then mv=mv.Unit*self._spd end
		if bv and bv.Parent then bv.Velocity=mv end
		if bg and bg.Parent then bg.CFrame=cam.CFrame end
	end)
	self._cleanup:Add(self._loop)
	local ca=LP.CharacterAdded:Connect(function() self:Disable() end)
	self._cleanup:Add(ca); table.insert(self._chars,ca)
end
function Fly:Disable()
	self._on=false
	if self._loop then pcall(function() self._loop:Disconnect() end); self._loop=nil end
	for _,c in ipairs(self._chars) do pcall(function() c:Disconnect() end) end; self._chars={}
	if self._bv then pcall(function() self._bv:Destroy() end); self._bv=nil end
	if self._bg then pcall(function() self._bg:Destroy() end); self._bg=nil end
	local hum=getHum(); if hum then hum.PlatformStand=false end
end
function Fly:SetSpeed(s) self._spd=s end

-- ═══════════════════════════════════════════════════════════
-- SPEED
-- ═══════════════════════════════════════════════════════════
local Spd={}
Spd.__index=Spd
function Spd.new(cl,s)
	local self=setmetatable({_on=false,_val=16,_def=16,_cleanup=cl},Spd)
	local ca=LP.CharacterAdded:Connect(function(ch)
		if self._on then wait(0.5); local h=ch:FindFirstChildOfClass("Humanoid"); if h then self._def=h.WalkSpeed; h.WalkSpeed=self._val end end
	end)
	cl:Add(ca); return self
end
function Spd:Enable() self._on=true; local h=getHum(); if h then self._def=h.WalkSpeed; h.WalkSpeed=self._val end end
function Spd:Disable() self._on=false; local h=getHum(); if h then h.WalkSpeed=self._def end end
function Spd:Set(v) self._val=v; if self._on then local h=getHum(); if h then h.WalkSpeed=v end end end

-- ═══════════════════════════════════════════════════════════
-- JUMP
-- ═══════════════════════════════════════════════════════════
local Jmp={}
Jmp.__index=Jmp
function Jmp.new(cl,s)
	local self=setmetatable({_on=false,_val=50,_def=50,_cleanup=cl},Jmp)
	local ca=LP.CharacterAdded:Connect(function(ch)
		if self._on then wait(0.5); local h=ch:FindFirstChildOfClass("Humanoid"); if h then self._def=h.JumpPower or 50; h.JumpPower=self._val; pcall(function() h.UseJumpPower=true; h.JumpHeight=self._val end) end end
	end)
	cl:Add(ca); return self
end
function Jmp:Enable() self._on=true; local h=getHum(); if h then self._def=h.JumpPower or 50; h.JumpPower=self._val; pcall(function() h.UseJumpPower=true; h.JumpHeight=self._val end) end end
function Jmp:Disable() self._on=false; local h=getHum(); if h then h.JumpPower=self._def; pcall(function() h.UseJumpPower=false end) end end
function Jmp:Set(v) self._val=v; if self._on then local h=getHum(); if h then h.JumpPower=v; pcall(function() h.UseJumpPower=true; h.JumpHeight=v end) end end end

-- ═══════════════════════════════════════════════════════════
-- ESP (safe: no crash if Drawing unavailable)
-- ═══════════════════════════════════════════════════════════
local Esp={}
Esp.__index=Esp
function Esp.new(cl,s)
	return setmetatable({
		_on=false,_boxes=true,_names=true,_dist=true,_tracers=true,_team=false,
		_bc=Color3.new(1,0,0),_tc=Color3.new(1,1,1),_md=500,_data={},_loop=nil,_cleanup=cl,
	},Esp)
end
function Esp:Enable()
	if self._on then return end; self._on=true; print("[ESP] Enabled")
	for _,p in ipairs(Players:GetPlayers()) do if p~=LP then self:_add(p) end end
	self._cleanup:Add(Players.PlayerAdded:Connect(function(p) if self._on and p~=LP then self:_add(p) end end))
	self._cleanup:Add(Players.PlayerRemoving:Connect(function(p) self:_del(p) end))
	self._loop=RunService.RenderStepped:Connect(function() self:_tick() end)
	self._cleanup:Add(self._loop)
end
function Esp:Disable()
	self._on=false; print("[ESP] Disabled")
	if self._loop then pcall(function() self._loop:Disconnect() end); self._loop=nil end
	for p,d in pairs(self._data) do self:_del(p) end; self._data={}
end
function Esp:_add(player)
	if self._data[player] then return end
	local d={lines={},nameBb=nil,distBb=nil,tracer=nil,ca=nil}
	if HAS_DRAWING then
		for i=1,4 do
			local ok,l=pcall(function() return Drawing.new("Line") end)
			if ok and l then l.Visible=false; l.Color=self._bc; l.Thickness=1.5; table.insert(d.lines,l) end
		end
	end
	local bb=Instance.new("BillboardGui")
	bb.AlwaysOnTop=true; bb.Size=UDim2.new(0,200,0,20); bb.StudsOffset=Vector3.new(0,2.5,0); bb.MaxDistance=self._md
	local nl=Instance.new("TextLabel")
	nl.BackgroundTransparency=1; nl.Size=UDim2.new(1,0,1,0); nl.Text=player.Name
	nl.TextColor3=Color3.new(1,1,1); nl.Font=Enum.Font.GothamBold or Enum.Font.SourceSansBold ; nl.TextSize=13
	nl.TextStrokeTransparency=0; nl.TextStrokeColor3=Color3.new(0,0,0); nl.Parent=bb
	d.nameBb=bb; self._cleanup:Add(bb)
	local db=Instance.new("BillboardGui")
	db.AlwaysOnTop=true; db.Size=UDim2.new(0,200,0,20); db.StudsOffset=Vector3.new(0,-0.5,0); db.MaxDistance=self._md
	local dl=Instance.new("TextLabel")
	dl.BackgroundTransparency=1; dl.Size=UDim2.new(1,0,1,0); dl.Text="0m"
	dl.TextColor3=Color3.new(0.78,0.78,0.78); dl.Font=Enum.Font.SourceSans or Enum.Font.Gotham; dl.TextSize=12
	dl.TextStrokeTransparency=0; dl.TextStrokeColor3=Color3.new(0,0,0); dl.Parent=db
	d.distBb=db; self._cleanup:Add(db)
	if HAS_DRAWING then
		local ok,tr=pcall(function() return Drawing.new("Line") end)
		if ok and tr then tr.Visible=false; tr.Color=self._tc; tr.Thickness=1; d.tracer=tr end
	end
	local function attach(ch)
		local hd=ch:FindFirstChild("Head") or ch:FindFirstChild("HumanoidRootPart")
		if hd then bb.Adornee=hd; db.Adornee=hd end
	end
	if player.Character then attach(player.Character) end
	d.ca=player.CharacterAdded:Connect(attach); self._cleanup:Add(d.ca)
	self._data[player]=d
end
function Esp:_del(player)
	local d=self._data[player]; if not d then return end
	for _,l in ipairs(d.lines) do pcall(function() l:Remove() end) end
	if d.tracer then pcall(function() d.tracer:Remove() end) end
	if d.nameBb then pcall(function() d.nameBb:Destroy() end) end
	if d.distBb then pcall(function() d.distBb:Destroy() end) end
	if d.ca then pcall(function() d.ca:Disconnect() end) end
	self._data[player]=nil
end
function Esp:_hide(d)
	for _,l in ipairs(d.lines) do l.Visible=false end
	d.nameBb.Enabled=false; d.distBb.Enabled=false
	if d.tracer then d.tracer.Visible=false end
end
function Esp:_tick()
	if not self._on then return end
	local mt=self._team and LP.Team; local cam=Cam; if not cam then return end; local vs=cam.ViewportSize
	for player,d in pairs(self._data) do
		local ch=player.Character
		if not ch then self:_hide(d); goto nxt end
		if mt and player.Team==mt then self:_hide(d); goto nxt end
		local hd=ch:FindFirstChild("Head"); local hrp=ch:FindFirstChild("HumanoidRootPart")
		if not hd or not hrp then self:_hide(d); goto nxt end
		local pos=hd.Position; local sp,onScr=cam:WorldToViewportPoint(pos)
		local myC=getChar(); local dist=0
		if myC and myC:FindFirstChild("HumanoidRootPart") then dist=(myC.HumanoidRootPart.Position-pos).Magnitude end
		if dist>self._md then self:_hide(d); goto nxt end

		if self._boxes and onScr and #d.lines==4 then
			local sz=Vector2.new(2000/sp.Z,4000/sp.Z)
			local tl=Vector2.new(sp.X-sz.X/2,sp.Y-sz.Y); local tr=Vector2.new(sp.X+sz.X/2,sp.Y-sz.Y)
			local bl=Vector2.new(sp.X-sz.X/2,sp.Y); local br=Vector2.new(sp.X+sz.X/2,sp.Y)
			d.lines[1].From=tl; d.lines[1].To=tr; d.lines[1].Visible=true; d.lines[1].Color=self._bc
			d.lines[2].From=tr; d.lines[2].To=br; d.lines[2].Visible=true; d.lines[2].Color=self._bc
			d.lines[3].From=br; d.lines[3].To=bl; d.lines[3].Visible=true; d.lines[3].Color=self._bc
			d.lines[4].From=bl; d.lines[4].To=tl; d.lines[4].Visible=true; d.lines[4].Color=self._bc
		else for _,l in ipairs(d.lines) do l.Visible=false end end

		d.nameBb.Enabled=self._names and onScr; d.nameBb.MaxDistance=self._md
		d.distBb.Enabled=self._dist and onScr; d.distBb.MaxDistance=self._md
		if self._dist then pcall(function() d.distBb:FindFirstChildOfClass("TextLabel").Text=string.format("%.0fm", dist) end) end
		if d.tracer then
			if self._tracers and onScr then d.tracer.Visible=true; d.tracer.From=Vector2.new(vs.X/2,vs.Y); d.tracer.To=Vector2.new(sp.X,sp.Y); d.tracer.Color=self._tc
			else d.tracer.Visible=false end
		end
		::nxt::
	end
end

-- ═══════════════════════════════════════════════════════════
-- AIMLOCK
-- ═══════════════════════════════════════════════════════════
local Aim={}
Aim.__index=Aim
function Aim.new(cl,s)
	return setmetatable({_on=false,_tog=false,_held=false,_tm="crosshair",_fov=200,_part="Head",_smooth=5,_team=false,_loop=nil,_circle=nil,_cleanup=cl},Aim)
end
function Aim:Enable()
	if self._on then return end; self._on=true; print("[Aimlock] Enabled")
	if HAS_DRAWING then
		self._circle=Drawing.new("Circle")
		self._circle.Visible=false; self._circle.Radius=self._fov
		self._circle.Color=Color3.new(1,1,1); self._circle.Transparency=0.8; self._circle.Thickness=1; self._circle.Filled=false
	end
	self._loop=RunService.RenderStepped:Connect(function() self:_tick() end)
	self._cleanup:Add(self._loop)
end
function Aim:Disable()
	self._on=false; self._held=false; print("[Aimlock] Disabled")
	if self._loop then pcall(function() self._loop:Disconnect() end); self._loop=nil end
	if self._circle then pcall(function() self._circle:Remove() end); self._circle=nil end
end
function Aim:KeyDown() if self._tog then self._held=not self._held else self._held=true end end
function Aim:KeyUp() if not self._tog then self._held=false end end
function Aim:_tick()
	if not self._on then return end
	local cam=Cam; if not cam then return end
	if self._circle then self._circle.Visible=self._on; self._circle.Position=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2); self._circle.Radius=self._fov end
	if not self._held then return end
	local mt=self._team and LP.Team; local best,bestSc=nil,math.huge; local myC=getChar()
	for _,p in ipairs(Players:GetPlayers()) do
		if p==LP then continue end
		local ch=p.Character; if not ch then continue end
		if mt and p.Team==mt then continue end
		local tp=ch:FindFirstChild(self._part); if not tp then continue end
		local sp,onScr=cam:WorldToViewportPoint(tp.Position); if not onScr then continue end
		local ctr=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
		local dc=(Vector2.new(sp.X,sp.Y)-ctr).Magnitude; if dc>self._fov then continue end
		local sc=self._tm=="crosshair" and dc or (myC and myC:FindFirstChild("HumanoidRootPart") and (myC.HumanoidRootPart.Position-tp.Position).Magnitude or dc)
		if sc<bestSc then bestSc=sc; best=tp end
	end
	if best then local look=CFrame.lookAt(cam.CFrame.Position,best.Position); cam.CFrame=self._smooth>0.01 and cam.CFrame:Lerp(look,self._smooth/10) or look end
end

-- ═══════════════════════════════════════════════════════════
-- BUILD
-- ═══════════════════════════════════════════════════════════
local Universal = {}

function Universal.Build(tab, ui, state, cleanup)
	print("[Universal] Building tab...")

	-- Fly
	ui:Section(tab, "Fly")
	local fly=Fly.new(cleanup,state)
	local ft=ui:Toggle(tab, "Enable Fly", state:Get("fly_on",false), function(v) state:Set("fly_on",v); if v then fly:Enable() else fly:Disable() end end)
	ui:Slider(tab, "Fly Speed", 10, 500, state:Get("fly_spd",50), 5, function(v) state:Set("fly_spd",v); fly:SetSpeed(v) end)
	ui:Keybind(tab, "Fly Keybind", state:Get("fly_key",Enum.KeyCode.F), function(k) state:Set("fly_key",k) end)

	-- Movement
	ui:Section(tab, "Movement")
	local spd=Spd.new(cleanup,state)
	ui:Toggle(tab, "Speed Hack", state:Get("spd_on",false), function(v) state:Set("spd_on",v); if v then spd:Enable() else spd:Disable() end end)
	ui:Slider(tab, "WalkSpeed", 16, 200, state:Get("spd_val",16), 1, function(v) state:Set("spd_val",v); spd:Set(v) end)
	local jmp=Jmp.new(cleanup,state)
	ui:Toggle(tab, "Jump Power", state:Get("jmp_on",false), function(v) state:Set("jmp_on",v); if v then jmp:Enable() else jmp:Disable() end end)
	ui:Slider(tab, "Jump Power", 0, 300, state:Get("jmp_val",50), 5, function(v) state:Set("jmp_val",v); jmp:Set(v) end)

	-- ESP
	ui:Section(tab, "ESP")
	local esp=Esp.new(cleanup,state)
	ui:Toggle(tab, "Enable ESP", state:Get("esp_on",false), function(v) state:Set("esp_on",v); if v then esp:Enable() else esp:Disable() end end)
	ui:Toggle(tab, "Show Boxes", state:Get("esp_boxes",true), function(v) state:Set("esp_boxes",v); esp._boxes=v end)
	ui:Toggle(tab, "Show Names", state:Get("esp_names",true), function(v) state:Set("esp_names",v); esp._names=v end)
	ui:Toggle(tab, "Show Distance", state:Get("esp_dist",true), function(v) state:Set("esp_dist",v); esp._dist=v end)
	ui:Toggle(tab, "Show Tracers", state:Get("esp_tracers",true), function(v) state:Set("esp_tracers",v); esp._tracers=v end)
	ui:Toggle(tab, "Team Check", state:Get("esp_team",false), function(v) state:Set("esp_team",v); esp._team=v end)
	ui:ColorPicker(tab, "Box Color", state:Get("esp_bc",Color3.new(1,0,0)), function(c) state:Set("esp_bc",c); esp._bc=c end)
	ui:ColorPicker(tab, "Tracer Color", state:Get("esp_tc",Color3.new(1,1,1)), function(c) state:Set("esp_tc",c); esp._tc=c end)
	ui:Slider(tab, "Max Distance", 50, 2000, state:Get("esp_md",500), 50, function(v) state:Set("esp_md",v); esp._md=v end)

	-- Aimlock
	ui:Section(tab, "Aimlock")
	local aim=Aim.new(cleanup,state)
	ui:Toggle(tab, "Enable Aimlock", state:Get("aim_on",false), function(v) state:Set("aim_on",v); if v then aim:Enable() else aim:Disable() end end)
	ui:Dropdown(tab, "Mode", {"hold","toggle"}, state:Get("aim_mode","hold"), function(v) state:Set("aim_mode",v); aim._tog=(v=="toggle") end)
	ui:Dropdown(tab, "Target Mode", {"crosshair","distance"}, state:Get("aim_tm","crosshair"), function(v) state:Set("aim_tm",v); aim._tm=v end)
	ui:Dropdown(tab, "Target Part", {"Head","HumanoidRootPart","UpperTorso"}, state:Get("aim_part","Head"), function(v) state:Set("aim_part",v); aim._part=v end)
	ui:Slider(tab, "FOV Radius", 30, 800, state:Get("aim_fov",200), 5, function(v) state:Set("aim_fov",v); aim._fov=v end)
	ui:Slider(tab, "Smoothness", 1, 20, state:Get("aim_smooth",5), 1, function(v) state:Set("aim_smooth",v); aim._smooth=v end)
	ui:Toggle(tab, "Team Check", state:Get("aim_team",false), function(v) state:Set("aim_team",v); aim._team=v end)
	ui:Keybind(tab, "Aimlock Key", state:Get("aim_key",Enum.KeyCode.E), function(k) state:Set("aim_key",k) end)

	-- global key listener
	UIS.InputBegan:Connect(function(i,gp)
		if i.KeyCode==state:Get("aim_key",Enum.KeyCode.E) then aim:KeyDown() end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.KeyCode==state:Get("aim_key",Enum.KeyCode.E) then aim:KeyUp() end
	end)

	-- restore persisted
	if state:Get("fly_on",false) then fly._spd=state:Get("fly_spd",50); fly:Enable(); ft:SetValue(true) end
	if state:Get("spd_on",false) then spd._val=state:Get("spd_val",16); spd:Enable() end
	if state:Get("jmp_on",false) then jmp._val=state:Get("jmp_val",50); jmp:Enable() end
	if state:Get("esp_on",false) then
		esp._boxes=state:Get("esp_boxes",true); esp._names=state:Get("esp_names",true)
		esp._dist=state:Get("esp_dist",true); esp._tracers=state:Get("esp_tracers",true)
		esp._team=state:Get("esp_team",false)
		esp._bc=state:Get("esp_bc",esp._bc); esp._tc=state:Get("esp_tc",esp._tc)
		esp._md=state:Get("esp_md",500); esp:Enable()
	end
	if state:Get("aim_on",false) then
		aim._tog=(state:Get("aim_mode","hold")=="toggle")
		aim._tm=state:Get("aim_tm","crosshair"); aim._part=state:Get("aim_part","Head")
		aim._fov=state:Get("aim_fov",200); aim._smooth=state:Get("aim_smooth",5)
		aim._team=state:Get("aim_team",false); aim:Enable()
	end

	cleanup:AddCallback(function() fly:Disable(); spd:Disable(); jmp:Disable(); esp:Disable(); aim:Disable() end)
	print("[Universal] Build complete")
end
return Universal
