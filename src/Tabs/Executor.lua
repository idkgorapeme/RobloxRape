-- Executor.lua -- Tab 2
print("[Executor] Loading...")

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- font fallback
local FG = Enum.Font.Gotham  or 0
local FB = Enum.Font.GothamBold or FG
local FC = Enum.Font.Code or FG

local C = {
	Bg=Color3.new(0.07,0.07,0.086), Surf=Color3.new(0.086,0.086,0.102),
	Surf2=Color3.new(0.118,0.118,0.141), Accent=Color3.new(0.51,0.43,0.94),
	Accent2=Color3.new(0.39,0.31,0.86), Text=Color3.new(0.92,0.92,0.94),
	Text2=Color3.new(0.59,0.59,0.63), Text3=Color3.new(0.35,0.35,0.39),
	Red=Color3.new(0.94,0.27,0.27), Green=Color3.new(0.31,0.78,0.47),
	Yellow=Color3.new(0.94,0.78,0.27), White=Color3.new(1,1,1),
}

local function corner(f,r)
	pcall(function() Instance.new("UICorner",f).CornerRadius=r or UDim2.new(0,6) end)
end

local Executor = {}

function Executor.Build(tab, ui, state, cleanup, viewportApi)
	print("[Executor] Build start")

	ui:Section(tab, "Code Input")

	local cf = Instance.new("Frame")
	cf.Size=UDim2.new(1,-20,0,150); cf.BackgroundColor3=C.Bg; cf.BorderSizePixel=0
	cf.Parent=tab.container; corner(cf,UDim2.new(0,6))

	local ci = Instance.new("TextBox")
	ci.Size=UDim2.new(1,-12,1,-12); ci.Position=UDim2.new(0,6,0,6)
	ci.BackgroundTransparency=1; ci.TextColor3=C.Text
	ci.PlaceholderText="Enter Lua code..."; ci.PlaceholderColor3=C.Text3
	ci.Text="-- Type Lua code here...\n-- ExecutorGui = parent GUI elements\n-- RegisterCleanup(fn) = register teardown\n-- print/warn/error are captured"
	ci.Font=FC; ci.TextSize=12
	ci.TextXAlignment=Enum.TextXAlignment.Left; ci.TextYAlignment=Enum.TextYAlignment.Top
	ci.MultiLine=true; ci.ClearTextOnFocus=false
	ci.Parent=cf

	-- Buttons
	local br = Instance.new("Frame")
	br.Size=UDim2.new(1,-20,0,36); br.BackgroundTransparency=1; br.Parent=tab.container

	local eB = ui:Button(tab, "Execute", function() end)
	eB.Frame.Size=UDim2.new(0.32,-3,0,34); eB.Frame.Parent=br

	local cB = ui:Button(tab, "Clear Output", function() end)
	cB.Frame.Size=UDim2.new(0.32,-3,0,34); cB.Frame.Position=UDim2.new(0.34,1,0,0)
	cB.Frame.BackgroundColor3=C.Surf2; cB.Frame.Parent=br

	local sB = ui:Button(tab, "Stop Script", function() end)
	sB.Frame.Size=UDim2.new(0.3,0,0,34); sB.Frame.Position=UDim2.new(0.68,2,0,0)
	sB.Frame.BackgroundColor3=Color3.new(0.7,0.2,0.2); sB.Frame.Parent=br

	-- Output
	ui:Section(tab, "Output")

	local of = Instance.new("ScrollingFrame")
	of.Size=UDim2.new(1,-20,0,140); of.BackgroundColor3=C.Bg; of.BorderSizePixel=0
	of.ScrollBarThickness=3; of.ScrollBarImageColor3=Color3.new(0.23,0.23,0.27)
	of.CanvasSize=UDim2.new(0,0,0,5000); of.Parent=tab.container
	corner(of,UDim2.new(0,6))
	pcall(function() of.AutomaticCanvasSize=Enum.AutomaticSize.Y end)

	Instance.new("UIListLayout",of).SortOrder=Enum.SortOrder.LayoutOrder
	local pad = Instance.new("UIPadding",of)
	pad.PaddingLeft=UDim2.new(0,6); pad.PaddingRight=UDim2.new(0,6); pad.PaddingTop=UDim2.new(0,4)

	local outLines = {}
	local function addLine(txt,clr)
		local lb=Instance.new("TextLabel")
		lb.Size=UDim2.new(1,0,0,16); lb.BackgroundTransparency=1
		lb.Text=txt; lb.TextColor3=clr or C.Text; lb.Font=FC; lb.TextSize=11
		lb.TextXAlignment=Enum.TextXAlignment.Left; lb.TextWrapped=true
		lb.Parent=of; table.insert(outLines,lb)
		if #outLines>300 then pcall(function() table.remove(outLines,1):Destroy() end) end
		of.CanvasPosition=Vector2.new(0,99999)
	end
	local function clearOut()
		for _,l in ipairs(outLines) do pcall(function() l:Destroy() end) end
		outLines={}
	end

	-- Execution engine
	local function execute()
		local code=ci.Text
		if not code or code:match("^%s*$") then addLine("[!] No code.",C.Yellow); return end
		clearOut(); addLine("[>] Executing...",C.Accent)

		if not viewportApi or not viewportApi.NewExecSession then
			addLine("[ERROR] Viewport API missing",C.Red); return
		end

		local j = viewportApi.NewExecSession()
		local eg = viewportApi.OutputGui

		-- Auto-track task.* threads
		local sT={}
		for k,v in pairs(task or {spawn=coroutine.wrap,wait=wait}) do
			if k=="spawn" then sT[k]=function(fn,...) local a={...}; local th=task.spawn(function() fn(unpack(a)) end); j:Add(th); return th end
			elseif k=="delay" then sT[k]=function(t,fn,...) local a={...}; local th=task.delay(t,function() fn(unpack(a)) end); j:Add(th); return th end
			elseif k=="defer" then sT[k]=function(fn,...) local a={...}; local th=(task.defer or task.spawn)(function() fn(unpack(a)) end); j:Add(th); return th end
			else sT[k]=v end
		end

		local env = {
			game=game,workspace=workspace,
			Instance=Instance,Vector2=Vector2,Vector3=Vector3,CFrame=CFrame,Color3=Color3,UDim2=UDim2,
			TweenInfo=TweenInfo,Enum=Enum,Rect=Rect,Ray=Ray,
			task=sT,pcall=pcall,xpcall=xpcall,
			math=math,string=string,table=table,coroutine=coroutine,bit32=bit32,
			rawget=rawget,rawset=rawset,rawequal=rawequal,rawlen=rawlen,
			next=next,ipairs=ipairs,pairs=pairs,select=select,unpack=unpack,
			type=type,tonumber=tonumber,tostring=tostring,assert=assert,
			wait=wait,tick=tick,time=time,
			spawn=function(fn,...) local a={...}; local th=task.spawn(function() fn(unpack(a)) end); j:Add(th); return th end,
			delay=function(t,fn,...) local a={...}; local th=task.delay(t or 0,function() fn(unpack(a)) end); j:Add(th); return th end,
			TweenService=TweenService,UserInputService=UserInputService,Players=Players,RunService=RunService,
			ReplicatedStorage=game:GetService("ReplicatedStorage"),
			Lighting=game:GetService("Lighting"),
			HttpService=game:GetService("HttpService"),
			StarterGui=game:GetService("StarterGui"),
			SoundService=game:GetService("SoundService"),
			MarketplaceService=game:GetService("MarketplaceService"),
			TextService=game:GetService("TextService"),
			-- stubs
			identifyexecutor=type(identifyexecutor)=="function" and identifyexecutor or function() return "ScriptHub" end,
			getgenv=type(getgenv)=="function" and getgenv or function() return {} end,
			getrenv=type(getrenv)=="function" and getrenv or function() return {} end,
			hookfunction=type(hookfunction)=="function" and hookfunction or function() end,
			getrawmetatable=type(getrawmetatable)=="function" and getrawmetatable or function() end,
			setreadonly=type(setreadonly)=="function" and setreadonly or function() end,
			newcclosure=type(newcclosure)=="function" and newcclosure or function(f) return f end,
			setclipboard=type(setclipboard)=="function" and setclipboard or function() end,
			getclipboard=type(getclipboard)=="function" and getclipboard or function() return "" end,
			writefile=type(writefile)=="function" and writefile or function() end,
			readfile=type(readfile)=="function" and readfile or function() return "" end,
			makefolder=type(makefolder)=="function" and makefolder or function() end,
			isfile=type(isfile)=="function" and isfile or function() return false end,
			listfiles=type(listfiles)=="function" and listfiles or function() return {} end,
			delfile=type(delfile)=="function" and delfile or function() end,
			loadstring=type(loadstring)=="function" and loadstring or function(s) return nil,"unavailable" end,
			typeof=type(typeof)=="function" and typeof or type,
			Drawing=type(Drawing)=="table" and Drawing or nil,
			-- hub globals
			ExecutorGui=eg,
			RegisterCleanup=function(fn) if type(fn)=="function" then j:Add(fn) end end,
			print=function(...) local p={}; for i=1,select("#",...) do p[i]=tostring(select(i,...)) end; addLine("[PRINT] "..table.concat(p,"\t"),C.Text2) end,
			warn=function(...) local p={}; for i=1,select("#",...) do p[i]=tostring(select(i,...)) end; addLine("[WARN] "..table.concat(p,"\t"),C.Yellow) end,
			error=function(msg,lvl) addLine("[ERROR] "..tostring(msg),C.Red); error(msg,(lvl or 1)+1) end,
		}

		local fn, cerr = loadstring(code,"ExecutorScript")
		if not fn then addLine("[COMPILE] "..tostring(cerr),C.Red); if viewportApi.SetStatus then viewportApi.SetStatus("Compile error") end; return end

		pcall(function() if setfenv then setfenv(fn,env) end end)
		pcall(function() if getfenv then local e=getfenv(fn); for k,v in pairs(env) do e[k]=v end end end)

		if viewportApi.SetStatus then viewportApi.SetStatus("Running...") end
		local ok,res = pcall(fn)
		if not ok then addLine("[RUNTIME] "..tostring(res),C.Red); if viewportApi.SetStatus then viewportApi.SetStatus("Error") end
		else if res~=nil then addLine("[RETURN] "..tostring(res),C.Green) end; addLine("[OK] Done.",C.Green); if viewportApi.SetStatus then viewportApi.SetStatus("Done") end end
	end

	eB.Button.MouseButton1Click:Connect(execute)
	cB.Button.MouseButton1Click:Connect(function() clearOut(); addLine("[>] Output cleared.",C.Text2) end)
	sB.Button.MouseButton1Click:Connect(function()
		if viewportApi and viewportApi.ClearAll then viewportApi.ClearAll() end
		clearOut(); addLine("[!] Stopped + viewport cleared.",C.Yellow)
		if viewportApi.SetStatus then viewportApi.SetStatus("No script executing.") end
	end)

	print("[Executor] Build complete")
	return {GetCode=function() return ci.Text end, SetCode=function(c) ci.Text=c; tab._ui:SwitchTab(2) end}
end
return Executor
