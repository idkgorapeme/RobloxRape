-- SaveLoad.lua -- Tab 5
print("[SaveLoad] Loading...")

local HttpService = game:GetService("HttpService")

local FG = Enum.Font.Gotham  or 0
local FB = Enum.Font.GothamBold or FG
local FC = Enum.Font.Code or FG

local SAVE_DIR = "ScriptHub/SavedScripts"
local INDEX_FILE = SAVE_DIR .. "/index.json"

local C = {
	Accent=Color3.new(0.51,0.43,0.94), Surf=Color3.new(0.086,0.086,0.102),
	Surf2=Color3.new(0.118,0.118,0.141), Bg=Color3.new(0.07,0.07,0.086),
	EntryBg=Color3.new(0.11,0.11,0.133), Text=Color3.new(0.92,0.92,0.94),
	Text2=Color3.new(0.59,0.59,0.63), Text3=Color3.new(0.35,0.35,0.39),
	White=Color3.new(1,1,1), Red=Color3.new(0.94,0.27,0.27),
	Green=Color3.new(0.31,0.78,0.47), Yellow=Color3.new(0.94,0.78,0.27),
}

local function corner(f,r)
	pcall(function() Instance.new("UICorner",f).CornerRadius=r or UDim2.new(0,6) end)
end

local SaveLoad = {}

function SaveLoad.Build(tab, ui, state, cleanup, execApi)
	print("[SaveLoad] Build start")

	-- Feature-detect file I/O
	local hasIO = false
	pcall(function() if type(readfile)=="function" and type(writefile)=="function" then hasIO=true end end)
	if hasIO then pcall(function() if not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end end) end

	if not hasIO then
		local wf = Instance.new("Frame")
		wf.Size=UDim2.new(1,-20,0,26); wf.BackgroundColor3=Color3.new(0.16,0.12,0.06)
		wf.BorderSizePixel=0; wf.Parent=tab.container; corner(wf,UDim2.new(0,5))
		local wl = Instance.new("TextLabel")
		wl.Size=UDim2.new(1,-16,1,0); wl.Position=UDim2.new(0,8,0,0); wl.BackgroundTransparency=1
		wl.Text="[!] File I/O unavailable -- scripts saved for this session only."
		wl.TextColor3=C.Yellow; wl.Font=FB; wl.TextSize=11; wl.TextXAlignment=Enum.TextXAlignment.Left
		wl.Parent=wf
	end

	local scripts = {} -- {name, timestamp, code, file}

	local function loadDisk()
		if not hasIO then return end
		pcall(function()
			if isfile(INDEX_FILE) then
				local idx = HttpService:JSONDecode(readfile(INDEX_FILE))
				for _,e in ipairs(idx) do
					local pth = SAVE_DIR.."/"..e.file
					if isfile(pth) then table.insert(scripts,{name=e.name,timestamp=e.timestamp,code=readfile(pth),file=e.file}) end
				end
			end
		end)
	end

	local function saveDisk()
		if not hasIO then return end
		pcall(function()
			local idx = {}
			for _,s in ipairs(scripts) do
				local fn = s.file or ("s_"..HttpService:GenerateGUID(false):gsub("-","")..".lua")
				s.file = fn
				writefile(SAVE_DIR.."/"..fn, s.code)
				table.insert(idx, {name=s.name, timestamp=s.timestamp, file=fn})
			end
			writefile(INDEX_FILE, HttpService:JSONEncode(idx))
		end)
	end

	loadDisk()

	-- Save section
	ui:Section(tab, "Save Current Script")
	local nameTb = ui:TextBox(tab, "Name", "My Script", "", function() end)
	local saveBtn = ui:Button(tab, "Save Current", function() end)

	-- Script list
	ui:Section(tab, "Saved Scripts")
	local lst = Instance.new("ScrollingFrame")
	lst.Size=UDim2.new(1,-20,0,150); lst.BackgroundColor3=C.Bg; lst.BorderSizePixel=0
	lst.ScrollBarThickness=3; lst.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
	lst.CanvasSize=UDim2.new(0,0,0,3000); lst.Parent=tab.container
	corner(lst,UDim2.new(0,6))
	pcall(function() lst.AutomaticCanvasSize=Enum.AutomaticSize.Y end)

	local lay = Instance.new("UIListLayout")
	lay.SortOrder=Enum.SortOrder.LayoutOrder; lay.Parent=lst
	pcall(function() lay.Padding=UDim2.new(0,3) end)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft=UDim2.new(0,6); pad.PaddingRight=UDim2.new(0,6)
	pad.PaddingTop=UDim2.new(0,6); pad.Parent=lst

	-- Import/Export
	local ie = Instance.new("Frame")
	ie.Size=UDim2.new(1,-20,0,36); ie.BackgroundTransparency=1; ie.Parent=tab.container

	local expB = ui:Button(tab, "Export All", function() end)
	expB.Frame.Size=UDim2.new(0.48,-2,0,34); expB.Frame.BackgroundColor3=C.Surf2; expB.Frame.Parent=ie

	local impB = ui:Button(tab, "Import", function() end)
	impB.Frame.Size=UDim2.new(0.48,-2,0,34); impB.Frame.Position=UDim2.new(0.52,2,0,0)
	impB.Frame.BackgroundColor3=Color3.new(0.2,0.39,0.27); impB.Frame.Parent=ie

	local function refresh()
		for _,c in ipairs(lst:GetChildren()) do if c:IsA("Frame") and c.Name=="Entry" then c:Destroy() end end
		if #scripts==0 then
			local el=Instance.new("TextLabel")
			el.Size=UDim2.new(1,0,0,20); el.BackgroundTransparency=1; el.Text="  (no saved scripts)"
			el.TextColor3=C.Text3; el.Font=FC; el.TextSize=11; el.TextXAlignment=Enum.TextXAlignment.Left
			el.Parent=lst; return
		end
		for i,s in ipairs(scripts) do
			local en=Instance.new("Frame"); en.Name="Entry"
			en.Size=UDim2.new(1,0,0,32); en.BackgroundColor3=C.EntryBg; en.Parent=lst
			corner(en,UDim2.new(0,4))

			local nl=Instance.new("TextLabel")
			nl.Size=UDim2.new(0.4,0,1,0); nl.Position=UDim2.new(0,8,0,0); nl.BackgroundTransparency=1
			nl.Text=s.name; nl.TextColor3=C.Text; nl.Font=FB; nl.TextSize=12
			nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=en

			local tl=Instance.new("TextLabel")
			tl.Size=UDim2.new(0.3,0,1,0); tl.Position=UDim2.new(0.4,0,0,0); tl.BackgroundTransparency=1
			tl.Text=s.timestamp or ""; tl.TextColor3=C.Text2; tl.Font=FG; tl.TextSize=10
			tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=en

			local lb=Instance.new("TextButton")
			lb.Size=UDim2.new(0,44,0,22); lb.Position=UDim2.new(1,-98,0.5,-11)
			lb.BackgroundColor3=C.Accent; lb.Text="Load"; lb.TextColor3=C.White
			lb.Font=FB; lb.TextSize=11; lb.BorderSizePixel=0; lb.Parent=en
			corner(lb,UDim2.new(0,3))
			lb.MouseButton1Click:Connect(function()
				if execApi and execApi.SetCode then execApi.SetCode(s.code); ui:Notify("Loaded","Script loaded.",2,"success") end
			end)

			local db=Instance.new("TextButton")
			db.Size=UDim2.new(0,44,0,22); db.Position=UDim2.new(1,-50,0.5,-11)
			db.BackgroundColor3=C.Red; db.Text="Del"; db.TextColor3=C.White
			db.Font=FB; db.TextSize=11; db.BorderSizePixel=0; db.Parent=en
			corner(db,UDim2.new(0,3))

			local ref = s
			db.MouseButton1Click:Connect(function()
				for j,scr in ipairs(scripts) do if scr==ref then table.remove(scripts,j); break end end
				saveDisk(); refresh()
			end)
		end
	end

	saveBtn.Button.MouseButton1Click:Connect(function()
		local nm = nameTb.GetValue(); if not nm or nm=="" then nm="Untitled" end
		local code = execApi and execApi.GetCode and execApi.GetCode() or ""
		if not code or code:match("^%s*$") then ui:Notify("Nothing","Executor empty.",3,"warning"); return end
		table.insert(scripts,{name=nm,timestamp=os.date("%Y-%m-%d %H:%M:%S"),code=code})
		saveDisk(); refresh(); ui:Notify("Saved","Script saved.",3,"success")
	end)

	expB.Button.MouseButton1Click:Connect(function()
		if #scripts==0 then ui:Notify("Nothing","No scripts.",3,"warning"); return end
		local txt = "-- Exported\n\n"
		for _,s in ipairs(scripts) do txt=txt.."-- "..s.name.." | "..s.timestamp.."\n"..s.code.."\n\n" end
		local ok = pcall(function() if type(setclipboard)=="function" then setclipboard(txt) end end)
		if ok then ui:Notify("Exported","Copied to clipboard.",3,"success")
		else ui:Notify("Export","Cannot access clipboard.",5,"warning") end
	end)

	impB.Button.MouseButton1Click:Connect(function()
		local ok,txt = pcall(function() return type(getclipboard)=="function" and getclipboard() or "" end)
		if ok and txt and #txt>0 then
			table.insert(scripts,{name="Imported "..os.date("%H:%M"),timestamp=os.date("%Y-%m-%d %H:%M:%S"),code=txt})
			saveDisk(); refresh(); ui:Notify("Imported","Import OK.",3,"success")
		else ui:Notify("Failed","Cannot read clipboard.",5,"warning") end
	end)

	refresh()
	print("[SaveLoad] Build complete")
	return {Refresh=refresh, GetScripts=function() return scripts end}
end
return SaveLoad
