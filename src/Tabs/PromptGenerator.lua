-- PromptGenerator.lua -- Tab 4
print("[PromptGenerator] Loading...")

local FG = Enum.Font.Gotham  or 0
local FC = Enum.Font.Code or FG

local PROMPT = [[You are writing a Roblox Lua script that will be run through a custom LocalScript "Executor" tab.

Rules:
1. Do not use RemoteEvents, RemoteFunctions, or any server-side code. This is a pure client-side LocalScript sandbox.
2. If your script creates any GUI, parent ALL GUI Instances to the global variable `ExecutorGui` that is provided in scope. Do not create your own ScreenGui and parent it to PlayerGui or CoreGui directly.
3. If you create any RBXScriptConnections, RenderStepped/Heartbeat bindings, or task.spawn loops, register a cleanup callback using the provided global function `RegisterCleanup(function() ... end)` so they can be disconnected/cancelled automatically when the script is replaced.
4. Use `print`, `warn`, and `error` normally — they are captured and shown in the Executor's output log.
5. Keep the entire script self-contained in one code block with no external dependencies beyond what a normal Roblox client LocalScript can access.
6. Wrap risky operations in pcall.

Now write a script that does the following: <DESCRIBE WHAT YOU WANT HERE>]]

local C = {
	Bg=Color3.new(0.07,0.07,0.086), Text=Color3.new(0.92,0.92,0.94),
	Text2=Color3.new(0.59,0.59,0.63), Accent=Color3.new(0.51,0.43,0.94),
	Accent2=Color3.new(0.39,0.31,0.86), White=Color3.new(1,1,1),
}

local function corner(f,r)
	pcall(function() Instance.new("UICorner",f).CornerRadius=r or UDim2.new(0,6) end)
end

local PromptGenerator = {}

function PromptGenerator.Build(tab, ui, state, cleanup)
	print("[PromptGenerator] Build start")

	-- Description
	local df = Instance.new("Frame")
	df.Size=UDim2.new(1,-20,0,32); df.BackgroundTransparency=1; df.Parent=tab.container
	local dl = Instance.new("TextLabel")
	dl.Size=UDim2.new(1,0,1,0); dl.BackgroundTransparency=1
	dl.Text="Copy this prompt into any AI chat to generate Tab-2/Executor-compatible scripts."
	dl.TextColor3=C.Text2; dl.Font=FG; dl.TextSize=11
	dl.TextXAlignment=Enum.TextXAlignment.Left; dl.TextWrapped=true
	dl.Parent=df

	-- Prompt text
	local pf = Instance.new("ScrollingFrame")
	pf.Size=UDim2.new(1,-20,0,240); pf.BackgroundColor3=C.Bg; pf.BorderSizePixel=0
	pf.ScrollBarThickness=3; pf.ScrollBarImageColor3=Color3.new(0.2,0.2,0.22)
	pf.CanvasSize=UDim2.new(0,0,0,600); pf.Parent=tab.container
	corner(pf,UDim2.new(0,6))

	local pl = Instance.new("TextLabel")
	pl.Size=UDim2.new(1,-16,0,580); pl.Position=UDim2.new(0,8,0,8)
	pl.BackgroundTransparency=1; pl.Text=PROMPT; pl.TextColor3=C.Text
	pl.Font=FC; pl.TextSize=11
	pl.TextXAlignment=Enum.TextXAlignment.Left; pl.TextYAlignment=Enum.TextYAlignment.Top
	pl.TextWrapped=true; pl.TextEditable=false; pl.Selectable=true
	pl.Parent=pf

	-- Buttons
	local br = Instance.new("Frame")
	br.Size=UDim2.new(1,-20,0,36); br.BackgroundTransparency=1; br.Parent=tab.container

	local cp = ui:Button(tab, "Copy to Clipboard", function() end)
	cp.Frame.Size=UDim2.new(0.48,-2,0,34); cp.Frame.Parent=br

	local sa = ui:Button(tab, "Select All Text", function() end)
	sa.Frame.Size=UDim2.new(0.48,-2,0,34); sa.Frame.Position=UDim2.new(0.52,2,0,0)
	sa.Frame.BackgroundColor3=C.Accent2; sa.Frame.Parent=br

	cp.Button.MouseButton1Click:Connect(function()
		local ok = pcall(function()
			if type(setclipboard)=="function" then setclipboard(PROMPT) else error() end
		end)
		if ok then ui:Notify("Copied!", "Prompt copied to clipboard.", 3, "success")
		else ui:Notify("Cannot Copy", "setclipboard not available. Please select + Ctrl+C the text above.", 5, "warning") end
	end)

	sa.Button.MouseButton1Click:Connect(function()
		pcall(function() pl.SelectionStart=0 end)
	end)

	print("[PromptGenerator] Build complete")
end
return PromptGenerator
