-- ExecutorViewport.lua -- Tab 3
print("[ExecutorViewport] Loading...")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local FG = Enum.Font.Gotham or Enum.Font.SourceSans or Enum.Font.Legacy
local FC = Enum.Font.Code or FG

-- simple janitor (no typeof dependency)
local function janitor()
	local j = {i={}, c={}, t={}, f={}}
	function j:add(thing)
		if type(thing)=="userdata" then
			local ok,cls = pcall(function() return thing.ClassName end)
			if ok and cls then table.insert(j.i, thing)
			else table.insert(j.i, thing) end
		elseif type(thing)=="function" then table.insert(j.f, thing)
		elseif type(thing)=="thread" then table.insert(j.t, thing)
		end
	end
	function j:clean()
		for _,x in ipairs(j.c) do pcall(function() x:Disconnect() end) end; j.c={}
		for _,x in ipairs(j.t) do pcall(function() if task and task.cancel then task.cancel(x) end end) end; j.t={}
		for _,x in ipairs(j.i) do pcall(function() x:Destroy() end) end; j.i={}
		for _,x in ipairs(j.f) do pcall(x) end; j.f={}
	end
	return j
end

local C = {
	Surf=Color3.new(0.086,0.086,0.102), Bg=Color3.new(0.07,0.07,0.086),
	Text=Color3.new(0.92,0.92,0.94), Text2=Color3.new(0.59,0.59,0.63),
	Text3=Color3.new(0.35,0.35,0.39),
}

local function corner(f,r)
	pcall(function() Instance.new("UICorner",f).CornerRadius=r or UDim2.new(0,6) end)
end

local ExecutorViewport = {}

function ExecutorViewport.Build(tab, ui, state, cleanup)
	print("[ExecutorViewport] Build start")

	-- parent
	local parent = game:GetService("CoreGui")
	local ok = pcall(function() local p=Instance.new("Frame"); p.Parent=parent; p:Destroy() end)
	if not ok then parent = LP:WaitForChild("PlayerGui") end

	-- destroy old
	pcall(function() parent:FindFirstChild("ExecutorOutputGui"):Destroy() end)

	local og = Instance.new("ScreenGui")
	og.Name="ExecutorOutputGui"; og.ResetOnSpawn=false; og.Parent=parent
	cleanup:Add(og)
	pcall(function() og.ZIndexBehavior=Enum.ZIndexBehavior.Sibling end)

	local ej -- current exec janitor

	-- Status
	local sf = Instance.new("Frame")
	sf.Size=UDim2.new(1,-20,0,52); sf.BackgroundColor3=C.Surf; sf.BorderSizePixel=0
	sf.Parent=tab.container; corner(sf,UDim2.new(0,6))

	local sl = Instance.new("TextLabel")
	sl.Size=UDim2.new(1,-20,1,0); sl.Position=UDim2.new(0,10,0,0)
	sl.BackgroundTransparency=1; sl.Text="No script is currently executing."
	sl.TextColor3=C.Text2; sl.Font=FG; sl.TextSize=12
	sl.TextXAlignment=Enum.TextXAlignment.Left; sl.TextYAlignment=Enum.TextYAlignment.Center
	sl.TextWrapped=true; sl.Parent=sf

	-- Mounted list
	local mf = Instance.new("ScrollingFrame")
	mf.Size=UDim2.new(1,-20,0,120); mf.BackgroundColor3=C.Bg; mf.BorderSizePixel=0
	mf.ScrollBarThickness=3; mf.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
	mf.CanvasSize=UDim2.new(0,0,0,3000); mf.Parent=tab.container
	corner(mf,UDim2.new(0,6))
	pcall(function() mf.AutomaticCanvasSize=Enum.AutomaticSize.Y end)

	local lay = Instance.new("UIListLayout")
	lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=mf

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft=UDim2.new(0,8); pad.PaddingRight=UDim2.new(0,8)
	pad.PaddingTop=UDim2.new(0,6); pad.Parent=mf

	local function refresh()
		for _,c in ipairs(mf:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
		local kids = {}
		for _,c in ipairs(og:GetChildren()) do if c:IsA("GuiObject") then table.insert(kids,c) end end
		if #kids==0 then
			local el=Instance.new("TextLabel")
			el.Size=UDim2.new(1,0,0,18); el.BackgroundTransparency=1; el.Text="  (empty)"
			el.TextColor3=C.Text3; el.Font=FC; el.TextSize=11; el.TextXAlignment=Enum.TextXAlignment.Left
			el.Parent=mf
		else
			for _,c in ipairs(kids) do
				local en=Instance.new("TextLabel")
				en.Size=UDim2.new(1,0,0,16); en.BackgroundTransparency=1
				en.Text="  "..c.ClassName..": "..c.Name
				en.TextColor3=Color3.new(0.67,0.82,0.67); en.Font=FC; en.TextSize=11
				en.TextXAlignment=Enum.TextXAlignment.Left; en.Parent=mf
			end
		end
	end

	local rc = RunService.Heartbeat:Connect(refresh)
	cleanup:Add(rc)

	local function ClearAll()
		if ej then ej:clean(); ej=nil end
		for _,c in ipairs(og:GetChildren()) do pcall(function() c:Destroy() end) end
		sl.Text="No script is currently executing."
		refresh()
	end

	local function NewSession()
		ClearAll()
		ej=janitor()
		sl.Text="Script is now running..."
		return ej
	end

	print("[ExecutorViewport] Build complete")
	return {OutputGui=og, ClearAll=ClearAll, NewExecSession=NewSession, SetStatus=function(m) sl.Text=m end}
end
return ExecutorViewport
