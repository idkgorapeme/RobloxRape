-- Noctis Advanced Hub – V15 (Special Key Farm Upgraded)
-- Changes: SpecialKeyFarm now iterates all keys, added TP/Flight mode switch

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

print("Noctis Hub – Starting...")

-- ==================== CLEANUP SYSTEM ====================
local hubDestroyed = false
local activeThreads = {}
local activeConnections = {}

local function safeSpawn(f)
    local thread = task.spawn(pcall, f)
    table.insert(activeThreads, thread)
    return thread
end

local function safeConnect(signal, handler)
    local conn
    pcall(function()
        conn = signal:Connect(handler)
        table.insert(activeConnections, conn)
    end)
    return conn
end

local function cleanupAll()
    hubDestroyed = true
    for _, t in ipairs(activeThreads) do pcall(task.cancel, t) end
    for _, c in ipairs(activeConnections) do pcall(function() c:Disconnect() end) end
    activeThreads, activeConnections = {}, {}
    pcall(function() Workspace.World2HelpFolder:Destroy() end)
    pcall(function() Workspace.TempNoctisGlidePlatform:Destroy() end)
    local folder = Workspace:FindFirstChild("SpecialKeys")
    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            pcall(function() obj.SpecialKeyHighlight:Destroy() end)
        end
    end
    -- Cleanup builder parts
    for _, p in ipairs(platformParts) do p:Destroy() end
    for _, p in ipairs(slopeParts) do p:Destroy() end
    platformParts = {}
    slopeParts = {}
end

-- ==================== GLOBAL HELPERS ====================
local SAVE_FILE = "MacroHub_Configs.json"
local recordInterval = 0.02   -- 50 FPS recording

local function roundNum(num) return math.floor(num * 1000 + 0.5) / 1000 end

local function fireUpdateSpeedEvent()
    pcall(function()
        local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local Event = Remotes and Remotes:FindFirstChild("UpdateSpeed")
        if Event then
            if Event:IsA("RemoteEvent") then Event:FireServer() elseif Event:IsA("RemoteFunction") then Event:InvokeServer() end
        end
    end)
end

local function setMobileControlsEnabled(enabled)
    pcall(function()
        local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
        if playerScripts then
            local playerModule = playerScripts:FindFirstChild("PlayerModule")
            if playerModule then
                local controls = require(playerModule):GetControls()
                if enabled then controls:Enable() else controls:Disable() end
            end
        end
    end)
end

-- Mobile Jump Tracking
local mobileJumpActive = false
local function bindMobileJumpTracker(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then safeConnect(hum.Jumping, function(isActive) mobileJumpActive = isActive end) end
end
if localPlayer.Character then bindMobileJumpTracker(localPlayer.Character) end
safeConnect(localPlayer.CharacterAdded, bindMobileJumpTracker)

-- Smooth tween glide helper
local currentTween = nil
local function tweenGlideTo(targetPos, speed)
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    if currentTween then pcall(currentTween.Cancel, currentTween); currentTween = nil end
    local dist = (targetPos - hrp.Position).Magnitude
    if dist < 0.5 then return true end
    local duration = math.max(0.1, dist / speed)
    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    currentTween = tween
    tween:Play()
    local completed = false
    tween.Completed:Connect(function() completed = true; currentTween = nil end)
    while not completed do
        if hubDestroyed or not hrp.Parent then pcall(tween.Cancel, tween); currentTween = nil; return false end
        task.wait()
    end
    return true
end

-- Platform/Slope builder helper
local function makePlatformBetween(p1, p2, width, height)
    width = width or 40
    height = height or 1
    local mid = (p1 + p2) / 2
    local dist = (p2 - p1).Magnitude
    return {
        CFrame = CFrame.lookAt(mid, p2),
        Size = Vector3.new(width, height, dist)
    }
end

-- ==================== MOBILE SCALING ====================
local isMobile = UserInputService.TouchEnabled
local SCALE = isMobile and 1.2 or 1.0

-- ==================== SCREEN GUI & MAINFRAME ====================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NoctisAdvancedHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, math.floor(500 * SCALE), 0, math.floor(560 * SCALE))
mainFrame.Position = UDim2.new(0.5, -math.floor(250 * SCALE), 0.5, -math.floor(280 * SCALE))
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, math.floor(14 * SCALE))
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(65, 65, 95)
mainStroke.Thickness = math.max(1, math.floor(1.5 * SCALE))
mainStroke.Parent = mainFrame

local topGlow = Instance.new("Frame")
topGlow.Size = UDim2.new(1, 0, 0, math.floor(3 * SCALE))
topGlow.BackgroundColor3 = Color3.fromRGB(0, 190, 255)
topGlow.BorderSizePixel = 0
topGlow.Parent = mainFrame

-- Header (draggable)
local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, 0, 0, math.floor(42 * SCALE))
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100 * SCALE, 1, 0)
titleLabel.Position = UDim2.new(0, math.floor(16 * SCALE), 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "NOCTIS HUB"
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
titleLabel.TextSize = math.floor(15 * SCALE)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

-- Destroy (X) & Minimize
local destroyBtn = Instance.new("TextButton")
destroyBtn.Size = UDim2.new(0, math.floor(28 * SCALE), 0, math.floor(28 * SCALE))
destroyBtn.Position = UDim2.new(1, -36 * SCALE, 0, 7 * SCALE)
destroyBtn.BackgroundColor3 = Color3.fromRGB(230, 50, 50)
destroyBtn.Text = "✕"
destroyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
destroyBtn.TextSize = math.floor(13 * SCALE)
destroyBtn.Font = Enum.Font.GothamBold
destroyBtn.Parent = headerFrame
local destroyCorner = Instance.new("UICorner")
destroyCorner.CornerRadius = UDim.new(0, math.floor(8 * SCALE))
destroyCorner.Parent = destroyBtn

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, math.floor(28 * SCALE), 0, math.floor(28 * SCALE))
minimizeBtn.Position = UDim2.new(1, -70 * SCALE, 0, 7 * SCALE)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextSize = math.floor(13 * SCALE)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = headerFrame
local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, math.floor(8 * SCALE))
minimizeCorner.Parent = minimizeBtn

local miniBtn = Instance.new("TextButton")
miniBtn.Size = UDim2.new(0, math.floor(120 * SCALE), 0, math.floor(40 * SCALE))
miniBtn.Position = UDim2.new(0.02, 0, 0.85, 0)
miniBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
miniBtn.Text = "Open Noctis"
miniBtn.TextColor3 = Color3.fromRGB(0, 190, 255)
miniBtn.TextSize = math.floor(14 * SCALE)
miniBtn.Font = Enum.Font.GothamBold
miniBtn.Visible = false
miniBtn.Parent = screenGui
local miniCorner = Instance.new("UICorner")
miniCorner.CornerRadius = UDim.new(0, math.floor(10 * SCALE))
miniCorner.Parent = miniBtn

-- Dragging
local function makeDraggable(dragHandle, targetFrame)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    local function update(input)
        local delta = input.Position - dragStart
        targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = targetFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)
end
makeDraggable(headerFrame, mainFrame)
makeDraggable(miniBtn, miniBtn)

minimizeBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; miniBtn.Visible = true end)
miniBtn.MouseButton1Click:Connect(function() miniBtn.Visible = false; mainFrame.Visible = true end)
destroyBtn.MouseButton1Click:Connect(function() cleanupAll(); screenGui:Destroy() end)

-- ==================== TAB NAVIGATION ====================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24 * SCALE, 0, math.floor(36 * SCALE))
tabBar.Position = UDim2.new(0, 12 * SCALE, 0, 44 * SCALE)
tabBar.BackgroundTransparency = 1
tabBar.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.Parent = tabBar
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 6 * SCALE)

local pagesContainer = Instance.new("Frame")
pagesContainer.Size = UDim2.new(1, -24 * SCALE, 1, -92 * SCALE)
pagesContainer.Position = UDim2.new(0, 12 * SCALE, 0, 84 * SCALE)
pagesContainer.BackgroundTransparency = 1
pagesContainer.Parent = mainFrame

local tabs = {}

local function createTab(tabName, displayName)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(0.14, -4 * SCALE, 1, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    tabBtn.Text = displayName
    tabBtn.TextColor3 = Color3.fromRGB(170, 170, 190)
    tabBtn.TextSize = math.floor(11 * SCALE)
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.Parent = tabBar
    local btnCorner = Instance.new("UICorner"); btnCorner.CornerRadius = UDim.new(0, math.floor(8 * SCALE)); btnCorner.Parent = tabBtn
    local btnStroke = Instance.new("UIStroke"); btnStroke.Color = Color3.fromRGB(45, 45, 60); btnStroke.Thickness = math.max(1, math.floor(1 * SCALE)); btnStroke.Parent = tabBtn

    local pageFrame = Instance.new("ScrollingFrame")
    pageFrame.Size = UDim2.new(1, 0, 1, 0)
    pageFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    pageFrame.BackgroundTransparency = 0.3
    pageFrame.BorderSizePixel = 0
    pageFrame.ScrollBarThickness = math.floor(5 * SCALE)
    pageFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 170, 255)
    pageFrame.Visible = false
    pageFrame.Parent = pagesContainer
    local pageCorner = Instance.new("UICorner"); pageCorner.CornerRadius = UDim.new(0, math.floor(10 * SCALE)); pageCorner.Parent = pageFrame
    local listLayout = Instance.new("UIListLayout"); listLayout.Parent = pageFrame; listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Padding = UDim.new(0, math.floor(8 * SCALE))
    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, 10 * SCALE); listPadding.PaddingLeft = UDim.new(0, 10 * SCALE); listPadding.PaddingRight = UDim.new(0, 10 * SCALE); listPadding.PaddingBottom = UDim.new(0, 10 * SCALE)
    listPadding.Parent = pageFrame
    pageFrame.CanvasSize = UDim2.new(0, 0, 0, 500)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        pageFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20 * SCALE)
    end)

    tabBtn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabs) do
            t.Page.Visible = false; t.Button.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
            t.Button.TextColor3 = Color3.fromRGB(170, 170, 190); t.Stroke.Color = Color3.fromRGB(45, 45, 60)
        end
        pageFrame.Visible = true; tabBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 210)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255); btnStroke.Color = Color3.fromRGB(0, 190, 255)
    end)
    tabs[tabName] = { Button = tabBtn, Page = pageFrame, Stroke = btnStroke }
    return pageFrame
end

local mainPage = createTab("Main", "Main")
local world2Page = createTab("World2", "W2&Keys")
local eventsPage = createTab("Events", "Events")
local playerPage = createTab("Player", "Player")
local configPage = createTab("Config", "Config")
local macroPage = createTab("Macro", "Macro")
local settingsPage = createTab("Settings", "Set")

tabs["Main"].Page.Visible = true
tabs["Main"].Button.BackgroundColor3 = Color3.fromRGB(0, 140, 210)
tabs["Main"].Button.TextColor3 = Color3.fromRGB(255, 255, 255)
tabs["Main"].Stroke.Color = Color3.fromRGB(0, 190, 255)

-- Helper UI functions
local function createButton(parentPage, name, text, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, math.floor(36 * SCALE))
    btn.BackgroundColor3 = color or Color3.fromRGB(25, 25, 35)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(225, 225, 235)
    btn.TextSize = math.floor(12 * SCALE)
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = parentPage
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, math.floor(8 * SCALE)); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(50, 50, 70); stroke.Thickness = math.max(1, math.floor(1 * SCALE)); stroke.Parent = btn
    return btn
end

local function createTextBox(parentPage, name, placeholder, defaultText, widthScale)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(widthScale, -4 * SCALE, 0, math.floor(36 * SCALE))
    box.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    box.PlaceholderText = placeholder
    box.Text = defaultText
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.TextSize = math.floor(12 * SCALE)
    box.Font = Enum.Font.GothamMedium
    box.Parent = parentPage
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, math.floor(8 * SCALE)); corner.Parent = box
    local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(50, 50, 70); stroke.Thickness = math.max(1, math.floor(1 * SCALE)); stroke.Parent = box
    return box
end

-- ==================== TAB 1: MAIN (unchanged) ====================
-- Auto Win
local autoWinEnabled = false
local autoWinSpeed = 65
local autoWinBtn = createButton(mainPage, "AutoWinBtn", "Auto Win: OFF")
local autoWinSpeedBox = createTextBox(mainPage, "AutoWinSpeed", "Speed", tostring(autoWinSpeed), 1)
autoWinSpeedBox.FocusLost:Connect(function()
    local num = tonumber(autoWinSpeedBox.Text)
    if num and num > 0 then autoWinSpeed = num else autoWinSpeedBox.Text = tostring(autoWinSpeed) end
end)

safeSpawn(function()
    while not hubDestroyed do
        if autoWinEnabled then
            pcall(function()
                local char = localPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local winBlock = Workspace:FindFirstChild("Winblocks") and Workspace.Winblocks:FindFirstChild("WinBlock16")
                if hrp and winBlock then
                    local targetPos = (winBlock:IsA("BasePart") and winBlock.CFrame or winBlock:GetPivot()).Position + Vector3.new(0, 7, 0)
                    tweenGlideTo(targetPos, autoWinSpeed)
                end
            end)
        end
        task.wait(0.1)
    end
end)

autoWinBtn.MouseButton1Click:Connect(function()
    autoWinEnabled = not autoWinEnabled
    autoWinBtn.Text = autoWinEnabled and "Auto Win: ON" or "Auto Win: OFF"
    autoWinBtn.BackgroundColor3 = autoWinEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
end)

-- Auto Treadmill
local autoTreadmaleEnabled = false
local autoTreadmaleBtn = createButton(mainPage, "AutoTreadmaleBtn", "Auto treadmill: OFF")
safeSpawn(function()
    while not hubDestroyed do
        if autoTreadmaleEnabled then
            pcall(function()
                local char = localPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local treadmill = Workspace:FindFirstChild("HourlyTreadmill_Active") and Workspace.HourlyTreadmill_Active:FindFirstChild("Conveyor")
                if hrp and treadmill then treadmill.CFrame = hrp.CFrame - Vector3.new(0, 3.5, 0) end
            end)
        end
        task.wait(0.05)
    end
end)
autoTreadmaleBtn.MouseButton1Click:Connect(function()
    autoTreadmaleEnabled = not autoTreadmaleEnabled
    autoTreadmaleBtn.Text = autoTreadmaleEnabled and "Auto treadmill: ON" or "Auto treadmill: OFF"
    autoTreadmaleBtn.BackgroundColor3 = autoTreadmaleEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
end)

-- Auto Buy System (unchanged)
local autoBuyHeader = Instance.new("TextLabel")
autoBuyHeader.Size = UDim2.new(1, 0, 0, math.floor(22 * SCALE))
autoBuyHeader.BackgroundTransparency = 1
autoBuyHeader.Text = "— Auto Buy System —"
autoBuyHeader.TextColor3 = Color3.fromRGB(0, 190, 255)
autoBuyHeader.TextSize = math.floor(13 * SCALE)
autoBuyHeader.Font = Enum.Font.GothamBold
autoBuyHeader.Parent = mainPage

local autoBuyMainEnabled = false
local autoBuyRunning = false
local autoBuySelectedItems = { Mysterious = true, Rare = true, Uncommon = true, Common = true }
local AUTOBUY_CONFIG = { REPEAT_COUNT = 5, DELAY_BETWEEN_FIRES = 0.2, DELAY_BETWEEN_ITEMS = 1.0, ITEMS_ORDER = {"Mysterious","Rare","Uncommon","Common"} }

local ShopUpdateEvent = nil
local BuyWinsEvent = nil
pcall(function()
    local remoPackage = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("littensy_remo@1.5.3"):WaitForChild("remo"):WaitForChild("container")
    if remoPackage then
        ShopUpdateEvent = remoPackage:FindFirstChild("ShopUpdate")
        BuyWinsEvent = remoPackage:FindFirstChild("BuyWins")
    end
end)

local function fireBuyRemote(itemName)
    if not BuyWinsEvent then return end
    pcall(function()
        if typeof(BuyWinsEvent) == "table" and type(BuyWinsEvent.fire) == "function" then
            BuyWinsEvent:fire(itemName)
        elseif typeof(BuyWinsEvent) == "Instance" and BuyWinsEvent:IsA("RemoteEvent") then
            BuyWinsEvent:FireServer(itemName)
        end
    end)
end

local function runAutoBuySequence()
    if autoBuyRunning or not autoBuyMainEnabled then return end
    autoBuyRunning = true
    pcall(function()
        for _, itemName in ipairs(AUTOBUY_CONFIG.ITEMS_ORDER) do
            if not autoBuyMainEnabled then break end
            if autoBuySelectedItems[itemName] then
                for i = 1, AUTOBUY_CONFIG.REPEAT_COUNT do
                    if not autoBuyMainEnabled then break end
                    fireBuyRemote(itemName)
                    task.wait(AUTOBUY_CONFIG.DELAY_BETWEEN_FIRES)
                end
                task.wait(AUTOBUY_CONFIG.DELAY_BETWEEN_ITEMS)
            end
        end
    end)
    autoBuyRunning = false
end

if ShopUpdateEvent then
    pcall(function()
        if typeof(ShopUpdateEvent) == "table" then
            if type(ShopUpdateEvent.connect) == "function" then
                ShopUpdateEvent:connect(function() if autoBuyMainEnabled then safeSpawn(runAutoBuySequence) end end)
            elseif type(ShopUpdateEvent.listen) == "function" then
                ShopUpdateEvent:listen(function() if autoBuyMainEnabled then safeSpawn(runAutoBuySequence) end end)
            end
        elseif typeof(ShopUpdateEvent) == "Instance" and ShopUpdateEvent:IsA("RemoteEvent") then
            safeConnect(ShopUpdateEvent.OnClientEvent, function() if autoBuyMainEnabled then safeSpawn(runAutoBuySequence) end end)
        end
    end)
end

local autoBuyMainBtn = createButton(mainPage, "AutoBuyMainBtn", "Auto Buy: OFF")
autoBuyMainBtn.MouseButton1Click:Connect(function()
    autoBuyMainEnabled = not autoBuyMainEnabled
    autoBuyMainBtn.Text = autoBuyMainEnabled and "Auto Buy: ON" or "Auto Buy: OFF"
    autoBuyMainBtn.BackgroundColor3 = autoBuyMainEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
end)

local itemGridFrame = Instance.new("Frame")
itemGridFrame.Size = UDim2.new(1, 0, 0, math.floor(76 * SCALE))
itemGridFrame.BackgroundTransparency = 1
itemGridFrame.Parent = mainPage
local itemGridLayout = Instance.new("UIGridLayout")
itemGridLayout.Parent = itemGridFrame
itemGridLayout.CellSize = UDim2.new(0.5, -4 * SCALE, 0, math.floor(34 * SCALE))
itemGridLayout.CellPadding = UDim2.new(0, 6 * SCALE, 0, 6 * SCALE)

for _, itemName in ipairs(AUTOBUY_CONFIG.ITEMS_ORDER) do
    local btn = createButton(itemGridFrame, "Buy_"..itemName, "Buy "..itemName..": ON", Color3.fromRGB(0, 120, 80))
    btn.MouseButton1Click:Connect(function()
        autoBuySelectedItems[itemName] = not autoBuySelectedItems[itemName]
        btn.Text = "Buy "..itemName..": "..(autoBuySelectedItems[itemName] and "ON" or "OFF")
        btn.BackgroundColor3 = autoBuySelectedItems[itemName] and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(35, 35, 45)
    end)
end

-- ==================== TAB 2: WORLD 2 & KEYS (with upgraded Special Key Farm) ====================
local slope1 = { CFrame = CFrame.lookAt((Vector3.new(3282,593,3852)+Vector3.new(3390,670,3904))/2, Vector3.new(3390,670,3904)), Size = Vector3.new(40,1,(Vector3.new(3390,670,3904)-Vector3.new(3282,593,3852)).Magnitude) }
local blue1  = { CFrame = CFrame.lookAt((Vector3.new(3390,600,3904)+Vector3.new(3295,600,5191))/2, Vector3.new(3295,600,5191)), Size = Vector3.new(40,1,(Vector3.new(3295,600,5191)-Vector3.new(3390,600,3904)).Magnitude) }
local blue2  = { CFrame = CFrame.lookAt((Vector3.new(3295,648,5191)+Vector3.new(4560,648,5097))/2, Vector3.new(4560,648,5097)), Size = Vector3.new(40,1,(Vector3.new(4560,648,5097)-Vector3.new(3295,648,5191)).Magnitude) }
local slope2 = { CFrame = CFrame.lookAt((Vector3.new(4722,568,5120)+Vector3.new(4996,686,5205))/2, Vector3.new(4996,686,5205)), Size = Vector3.new(40,1,(Vector3.new(4996,686,5205)-Vector3.new(4722,568,5120)).Magnitude) }
local slope3 = { CFrame = CFrame.lookAt((Vector3.new(5139,557,5100)+Vector3.new(5739,556,5187))/2, Vector3.new(5739,556,5187)), Size = Vector3.new(40,1,(Vector3.new(5739,556,5187)-Vector3.new(5139,557,5100)).Magnitude) }

local platformsData = {
    { Name="BluePlatform1", Position=Vector3.new(574.5,622,3869), Size=Vector3.new(1225,1,84) },
    { Name="BluePlatform2", Position=Vector3.new(-394.5,497,73.5), Size=Vector3.new(51,1,197) },
    { Name="BluePlatform3", Position=Vector3.new(-401.5,607.5,726), Size=Vector3.new(45,1,198) },
    { Name="BluePlatform4", Position=Vector3.new(-402,608,1380.5), Size=Vector3.new(42,1,97) },
    { Name="BluePlatform5", Position=Vector3.new(-363,605,1649), Size=Vector3.new(20,1,90) },
    { Name="BluePlatform6", Position=Vector3.new(-401.5,606,2002.5), Size=Vector3.new(41,1,425) },
    { Name="BluePlatform7", Position=Vector3.new(-402,618.5,2342), Size=Vector3.new(42,1,46) },
    { Name="BluePlatform8", Position=Vector3.new(-399,552.5,522), Size=Vector3.new(80,105,86) },
    { Name="BluePlatform9", Position=Vector3.new(1840.5,626,3870), Size=Vector3.new(1083,4,50) },
    { Name="BluePlatform10", Position=Vector3.new(2605.5,637.5,3872.5), Size=Vector3.new(107,5,41) },
    { Name="BluePlatform11", Position=Vector3.new(3131,592,3872), Size=Vector3.new(164,1,40) },
    { Name="BlueSlope1", CFrame=slope1.CFrame, Size=slope1.Size },
    { Name="BlueSlope2", CFrame=slope2.CFrame, Size=slope2.Size },
    { Name="BlueSlope3", CFrame=slope3.CFrame, Size=slope3.Size },
    { Name="BluePlatform12", CFrame=blue1.CFrame, Size=blue1.Size },
    { Name="BluePlatform13", CFrame=blue2.CFrame, Size=blue2.Size },
}

local world2HelpEnabled = false
local world2HelpButton = createButton(world2Page, "World2HelpBtn", "World 2 Help: OFF")
world2HelpButton.MouseButton1Click:Connect(function()
    world2HelpEnabled = not world2HelpEnabled
    local folder = Workspace:FindFirstChild("World2HelpFolder")
    if world2HelpEnabled then
        if not folder then folder = Instance.new("Folder"); folder.Name = "World2HelpFolder"; folder.Parent = Workspace end
        for _, data in ipairs(platformsData) do
            if not folder:FindFirstChild(data.Name) then
                local part = Instance.new("Part")
                part.Name = data.Name; part.Size = data.Size
                if data.CFrame then part.CFrame = data.CFrame else part.Position = data.Position end
                part.Anchored = true; part.CanCollide = true; part.Transparency = 0.4
                part.Color = Color3.fromRGB(0,162,255); part.Material = Enum.Material.Neon; part.Parent = folder
            end
        end
        world2HelpButton.Text = "World 2 Help: ON"; world2HelpButton.BackgroundColor3 = Color3.fromRGB(0,140,90)
    else
        if folder then folder:Destroy() end
        world2HelpButton.Text = "World 2 Help: OFF"; world2HelpButton.BackgroundColor3 = Color3.fromRGB(25,25,35)
    end
end)

local world2DestroyEnabled = false
local world2Button = createButton(world2Page, "World2DestroyBtn", "World 2 Destroy: OFF")
local function destroySpecificObjects()
    pcall(function() Workspace["WORLD 2"].Stage2.MovingWalls:Destroy() end)
    pcall(function() Workspace["WORLD 2"].Stage2:GetChildren()[7]:Destroy() end)
    pcall(function() Workspace["Pieges & Lava"].Lava_Stage3.LavaPart:Destroy() end)
    pcall(function() Workspace.NPC_MacaronMonster:Destroy() end)
    pcall(function() Workspace["Pieges & Lava"].Twomps:Destroy() end)
    pcall(function() Workspace.Winblocks.NPC_MacaronMonster:Destroy() end)
    pcall(function() Workspace["WORLD 2"].Stage8.Ventilateurs:Destroy() end)
    pcall(function() Workspace["Pieges & Lava"].FanEffects:Destroy() end)
    pcall(function() Workspace.NPC9:Destroy() end)
    pcall(function() Workspace["WORLD 2"].Stage10.DoorWall1:Destroy() end)
    pcall(function() Workspace["WORLD 2"].Stage10.DoorWall2:Destroy() end)
    pcall(function() Workspace["WORLD 2"].Stage10.DoorWall3:Destroy() end)
    pcall(function() Workspace.NPC15_World2:Destroy() end)
    pcall(function() Workspace["WORLD 2"].Stage15.Levels.MovingWalls.MovingWalls:Destroy() end)
end
safeSpawn(function() while not hubDestroyed do if world2DestroyEnabled then destroySpecificObjects() end task.wait(0.5) end end)
world2Button.MouseButton1Click:Connect(function()
    world2DestroyEnabled = not world2DestroyEnabled
    world2Button.Text = world2DestroyEnabled and "World 2 Destroy: ON" or "World 2 Destroy: OFF"
    world2Button.BackgroundColor3 = world2DestroyEnabled and Color3.fromRGB(0,140,90) or Color3.fromRGB(25,25,35)
    if world2DestroyEnabled then destroySpecificObjects() end
end)

-- Special Key Highlight (unchanged)
local specialKeyHighlightEnabled = false
local specialKeyHighlightBtn = createButton(world2Page, "SpecialKeyHighlightBtn", "Special Key Highlight: OFF")
specialKeyHighlightBtn.MouseButton1Click:Connect(function()
    specialKeyHighlightEnabled = not specialKeyHighlightEnabled
    local folder = Workspace:FindFirstChild("SpecialKeys")
    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            if specialKeyHighlightEnabled then
                if not obj:FindFirstChild("SpecialKeyHighlight") then
                    local hl = Instance.new("Highlight"); hl.Name = "SpecialKeyHighlight"
                    hl.FillColor = Color3.fromRGB(255,215,0); hl.OutlineColor = Color3.fromRGB(255,255,255)
                    hl.FillTransparency = 0.3; hl.Adornee = obj; hl.Parent = obj
                end
            else obj:FindFirstChild("SpecialKeyHighlight"):Destroy() end
        end
    end
    specialKeyHighlightBtn.Text = specialKeyHighlightEnabled and "Special Key Highlight: ON" or "Special Key Highlight: OFF"
    specialKeyHighlightBtn.BackgroundColor3 = specialKeyHighlightEnabled and Color3.fromRGB(0,140,90) or Color3.fromRGB(25,25,35)
end)

-- ==================== UPGRADED SPECIAL KEY FARM ====================
local specialKeyFarmEnabled = false
local specialKeyFarmMode = "TP"   -- "TP" or "Flight"
local specialKeyFarmSpeed = 100   -- speed for flight mode (can be adjusted)

local specialKeyFarmBtn = createButton(world2Page, "SpecialKeyFarmBtn", "Special key Farm: OFF")
local specialKeyFarmModeBtn = createButton(world2Page, "SpecialKeyFarmModeBtn", "Mode: TP")
local specialKeyFarmSpeedBox = createTextBox(world2Page, "SpecialKeyFarmSpeed", "Flight Speed", "100", 1)

specialKeyFarmSpeedBox.FocusLost:Connect(function()
    local num = tonumber(specialKeyFarmSpeedBox.Text)
    if num and num > 0 then specialKeyFarmSpeed = num else specialKeyFarmSpeedBox.Text = tostring(specialKeyFarmSpeed) end
end)

specialKeyFarmModeBtn.MouseButton1Click:Connect(function()
    if specialKeyFarmMode == "TP" then
        specialKeyFarmMode = "Flight"
        specialKeyFarmModeBtn.Text = "Mode: Flight"
    else
        specialKeyFarmMode = "TP"
        specialKeyFarmModeBtn.Text = "Mode: TP"
    end
end)

-- The farming loop – iterates over all keys in the folder
safeSpawn(function()
    while not hubDestroyed do
        if specialKeyFarmEnabled then
            pcall(function()
                local char = localPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local folder = Workspace:FindFirstChild("SpecialKeys")
                if hrp and folder then
                    local keys = folder:GetChildren()
                    for _, key in ipairs(keys) do
                        if not specialKeyFarmEnabled then break end
                        if key:IsA("BasePart") then
                            local keyPos = key.Position
                            if specialKeyFarmMode == "TP" then
                                hrp.CFrame = CFrame.new(keyPos + Vector3.new(0, 8, 0))
                                task.wait(1)   -- 1-second delay between keys
                            elseif specialKeyFarmMode == "Flight" then
                                -- Fly directly to the key (no vertical offset)
                                tweenGlideTo(keyPos, specialKeyFarmSpeed)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.5)   -- small cooldown before next sweep
    end
end)

specialKeyFarmBtn.MouseButton1Click:Connect(function()
    specialKeyFarmEnabled = not specialKeyFarmEnabled
    specialKeyFarmBtn.Text = specialKeyFarmEnabled and "Special key Farm: ON" or "Special key Farm: OFF"
    specialKeyFarmBtn.BackgroundColor3 = specialKeyFarmEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
end)

-- ==================== TAB 3: EVENTS (Coin + Platform Builder) ====================
local folderPathBox = createTextBox(eventsPage, "FolderPath", "Folder path (e.g. CoinBattleCoinsLocal)", "CoinBattleCoinsLocal", 1)

local function getTargetFolder()
    local path = folderPathBox.Text
    if path == "" then return nil end
    local current = Workspace
    for part in string.gmatch(path, "[^.]+") do
        current = current:FindFirstChild(part)
        if not current then return nil end
    end
    return current
end

-- Coin Auto Event
local autoCoinEnabled = false
local autoCoinMode = "TP"
local autoCoinFlightSpeed = 120
local autoCoinToggle = createButton(eventsPage, "AutoCoinBtn", "Auto Coin: OFF")
local autoCoinModeBtn = createButton(eventsPage, "AutoCoinModeBtn", "Mode: TP")
local autoCoinSpeedBox = createTextBox(eventsPage, "AutoCoinSpeed", "Flight Speed", "120", 1)
autoCoinSpeedBox.FocusLost:Connect(function()
    local num = tonumber(autoCoinSpeedBox.Text)
    if num and num > 0 then autoCoinFlightSpeed = num else autoCoinSpeedBox.Text = tostring(autoCoinFlightSpeed) end
end)
autoCoinModeBtn.MouseButton1Click:Connect(function()
    if autoCoinMode == "TP" then autoCoinMode = "Flight"; autoCoinModeBtn.Text = "Mode: Flight"
    else autoCoinMode = "TP"; autoCoinModeBtn.Text = "Mode: TP" end
end)
safeSpawn(function()
    while not hubDestroyed do
        if autoCoinEnabled then
            pcall(function()
                local folder = getTargetFolder()
                if folder and folder:IsA("Folder") then
                    local coins = folder:GetChildren()
                    for _, coin in ipairs(coins) do
                        if not autoCoinEnabled then break end
                        if coin:IsA("BasePart") then
                            if autoCoinMode == "TP" then
                                local char = localPlayer.Character
                                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                if hrp then hrp.CFrame = CFrame.new(coin.Position + Vector3.new(0, 8, 0)) end
                                task.wait(1)
                            elseif autoCoinMode == "Flight" then
                                tweenGlideTo(coin.Position, autoCoinFlightSpeed)
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.1)
    end
end)
autoCoinToggle.MouseButton1Click:Connect(function()
    autoCoinEnabled = not autoCoinEnabled
    autoCoinToggle.Text = autoCoinEnabled and "Auto Coin: ON" or "Auto Coin: OFF"
    autoCoinToggle.BackgroundColor3 = autoCoinEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
end)

local tpCoinsBtn = createButton(eventsPage, "TPCoinsBtn", "TP Coins to front", Color3.fromRGB(100, 50, 200))
tpCoinsBtn.MouseButton1Click:Connect(function()
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local folder = getTargetFolder()
    if folder and folder:IsA("Folder") then
        local offsetCF = hrp.CFrame * CFrame.new(0, 0, -20)
        for _, coin in ipairs(folder:GetChildren()) do
            if coin:IsA("BasePart") then coin.CFrame = offsetCF end
        end
    end
end)

-- Platform Builder (unchanged)
local platformPointA = nil
local platformPointB = nil
local platformParts = {}
local slopePointA = nil
local slopePointB = nil
local slopeParts = {}

local platHeader = Instance.new("TextLabel")
platHeader.Size = UDim2.new(1, 0, 0, math.floor(22 * SCALE))
platHeader.BackgroundTransparency = 1
platHeader.Text = "— Platform Builder —"
platHeader.TextColor3 = Color3.fromRGB(0, 190, 255)
platHeader.TextSize = math.floor(13 * SCALE)
platHeader.Font = Enum.Font.GothamBold
platHeader.Parent = eventsPage

local platformLabel = Instance.new("TextLabel")
platformLabel.Size = UDim2.new(1, 0, 0, math.floor(18 * SCALE))
platformLabel.BackgroundTransparency = 1
platformLabel.Text = "Flat Platforms"
platformLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
platformLabel.TextSize = math.floor(12 * SCALE)
platformLabel.Font = Enum.Font.GothamBold
platformLabel.Parent = eventsPage

local platSetA = createButton(eventsPage, "PlatSetA", "Set Point A", Color3.fromRGB(70,70,120))
local platSetB = createButton(eventsPage, "PlatSetB", "Set Point B", Color3.fromRGB(70,70,120))
local platCreate = createButton(eventsPage, "PlatCreate", "Create Platform", Color3.fromRGB(0,140,90))
local platUndo = createButton(eventsPage, "PlatUndo", "Undo Last Platform", Color3.fromRGB(200,100,50))
local platClear = createButton(eventsPage, "PlatClear", "Clear All Platforms", Color3.fromRGB(200,50,50))

platSetA.MouseButton1Click:Connect(function()
    local pos = getPlayerPosition()
    if pos then platformPointA = pos end
end)
platSetB.MouseButton1Click:Connect(function()
    local pos = getPlayerPosition()
    if pos then platformPointB = pos end
end)
platCreate.MouseButton1Click:Connect(function()
    if not platformPointA or not platformPointB then return end
    local data = makePlatformBetween(platformPointA, platformPointB, 40, 1)
    local part = Instance.new("Part")
    part.Name = "BuilderPlatform_" .. #platformParts + 1
    part.Size = data.Size
    part.CFrame = data.CFrame
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 0.4
    part.Color = Color3.fromRGB(0, 255, 100)
    part.Material = Enum.Material.Neon
    part.Parent = Workspace
    table.insert(platformParts, part)
end)
platUndo.MouseButton1Click:Connect(function()
    local last = table.remove(platformParts)
    if last then last:Destroy() end
end)
platClear.MouseButton1Click:Connect(function()
    for _, p in ipairs(platformParts) do p:Destroy() end
    platformParts = {}
end)

local slopeLabel = Instance.new("TextLabel")
slopeLabel.Size = UDim2.new(1, 0, 0, math.floor(18 * SCALE))
slopeLabel.BackgroundTransparency = 1
slopeLabel.Text = "Angled Slopes"
slopeLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
slopeLabel.TextSize = math.floor(12 * SCALE)
slopeLabel.Font = Enum.Font.GothamBold
slopeLabel.Parent = eventsPage

local slopeSetA = createButton(eventsPage, "SlopeSetA", "Set Point A", Color3.fromRGB(120,70,70))
local slopeSetB = createButton(eventsPage, "SlopeSetB", "Set Point B", Color3.fromRGB(120,70,70))
local slopeCreate = createButton(eventsPage, "SlopeCreate", "Create Slope", Color3.fromRGB(0,140,90))
local slopeUndo = createButton(eventsPage, "SlopeUndo", "Undo Last Slope", Color3.fromRGB(200,100,50))
local slopeClear = createButton(eventsPage, "SlopeClear", "Clear All Slopes", Color3.fromRGB(200,50,50))

slopeSetA.MouseButton1Click:Connect(function()
    local pos = getPlayerPosition()
    if pos then slopePointA = pos end
end)
slopeSetB.MouseButton1Click:Connect(function()
    local pos = getPlayerPosition()
    if pos then slopePointB = pos end
end)
slopeCreate.MouseButton1Click:Connect(function()
    if not slopePointA or not slopePointB then return end
    local data = makePlatformBetween(slopePointA, slopePointB, 40, 1)
    local part = Instance.new("Part")
    part.Name = "BuilderSlope_" .. #slopeParts + 1
    part.Size = data.Size
    part.CFrame = data.CFrame
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 0.4
    part.Color = Color3.fromRGB(255, 100, 0)
    part.Material = Enum.Material.Neon
    part.Parent = Workspace
    table.insert(slopeParts, part)
end)
slopeUndo.MouseButton1Click:Connect(function()
    local last = table.remove(slopeParts)
    if last then last:Destroy() end
end)
slopeClear.MouseButton1Click:Connect(function()
    for _, p in ipairs(slopeParts) do p:Destroy() end
    slopeParts = {}
end)

-- ==================== TAB 4: PLAYER (unchanged) ====================
local flightEnabled = false
local flightSpeed = 50
local flightBodyPos, flightBodyGyro
local flightHeartbeat

local function stopFlight()
    flightEnabled = false
    if flightHeartbeat then flightHeartbeat:Disconnect(); flightHeartbeat = nil end
    if flightBodyPos then flightBodyPos:Destroy(); flightBodyPos = nil end
    if flightBodyGyro then flightBodyGyro:Destroy(); flightBodyGyro = nil end
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

local function startFlight()
    if flightEnabled then return end
    flightEnabled = true
    flightHeartbeat = RunService.Heartbeat:Connect(function()
        if not flightEnabled then return end
        local char = localPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        if not flightBodyPos or not flightBodyPos.Parent then
            flightBodyPos = Instance.new("BodyPosition")
            flightBodyPos.MaxForce = Vector3.new(1e5,1e5,1e5)
            flightBodyPos.D = 500
            flightBodyPos.P = 5000
            flightBodyPos.Parent = hrp
        end
        if not flightBodyGyro or not flightBodyGyro.Parent then
            flightBodyGyro = Instance.new("BodyGyro")
            flightBodyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5)
            flightBodyGyro.D = 100
            flightBodyGyro.P = 3000
            flightBodyGyro.Parent = hrp
        end
        hum.PlatformStand = true
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += workspace.CurrentCamera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= workspace.CurrentCamera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= workspace.CurrentCamera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += workspace.CurrentCamera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0,1,0) end
        local targetPos = hrp.Position + moveDir * flightSpeed * 0.1
        flightBodyPos.Position = targetPos
        flightBodyGyro.CFrame = workspace.CurrentCamera.CFrame
    end)
end

local infJumpEnabled = false
local infJumpHeartbeat

local function stopInfJump()
    infJumpEnabled = false
    if infJumpHeartbeat then infJumpHeartbeat:Disconnect(); infJumpHeartbeat = nil end
end

local function startInfJump()
    if infJumpEnabled then return end
    infJumpEnabled = true
    infJumpHeartbeat = RunService.Heartbeat:Connect(function()
        if not infJumpEnabled then return end
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum.Jump = true
        end
    end)
end

local noclipEnabled = false
local function applyNoclip(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not noclipEnabled
        end
    end
end

local walkSpeedValue = 16
local jumpPowerValue = 50
local gravityValue = 196.2

local function applyMovementSettings(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = walkSpeedValue
        hum.JumpPower = jumpPowerValue
    end
end

localPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    applyMovementSettings(char)
    if noclipEnabled then applyNoclip(char) end
end)

local flightToggle = createButton(playerPage, "FlightToggle", "Flight: OFF")
local flightSpeedBox = createTextBox(playerPage, "FlightSpeed", "Flight Speed", "50", 1)
flightSpeedBox.FocusLost:Connect(function()
    local num = tonumber(flightSpeedBox.Text)
    if num and num > 0 then flightSpeed = num else flightSpeedBox.Text = tostring(flightSpeed) end
end)

local infJumpToggle = createButton(playerPage, "InfJumpToggle", "Infinite Jump: OFF")
local noclipToggle = createButton(playerPage, "NoclipToggle", "Noclip: OFF")
local walkSpeedBox = createTextBox(playerPage, "WalkSpeed", "Walk Speed", "16", 1)
walkSpeedBox.FocusLost:Connect(function()
    local num = tonumber(walkSpeedBox.Text)
    if num and num > 0 then
        walkSpeedValue = num
        local char = localPlayer.Character
        if char then applyMovementSettings(char) end
    else
        walkSpeedBox.Text = tostring(walkSpeedValue)
    end
end)
local jumpPowerBox = createTextBox(playerPage, "JumpPower", "Jump Power", "50", 1)
jumpPowerBox.FocusLost:Connect(function()
    local num = tonumber(jumpPowerBox.Text)
    if num and num > 0 then
        jumpPowerValue = num
        local char = localPlayer.Character
        if char then applyMovementSettings(char) end
    else
        jumpPowerBox.Text = tostring(jumpPowerValue)
    end
end)
local gravityBox = createTextBox(playerPage, "Gravity", "Gravity", "196.2", 1)
gravityBox.FocusLost:Connect(function()
    local num = tonumber(gravityBox.Text)
    if num then
        gravityValue = num
        Workspace.Gravity = num
    else
        gravityBox.Text = tostring(gravityValue)
    end
end)

flightToggle.MouseButton1Click:Connect(function()
    flightEnabled = not flightEnabled
    flightToggle.Text = flightEnabled and "Flight: ON" or "Flight: OFF"
    flightToggle.BackgroundColor3 = flightEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    if flightEnabled then startFlight() else stopFlight() end
end)

infJumpToggle.MouseButton1Click:Connect(function()
    infJumpEnabled = not infJumpEnabled
    infJumpToggle.Text = infJumpEnabled and "Infinite Jump: ON" or "Infinite Jump: OFF"
    infJumpToggle.BackgroundColor3 = infJumpEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    if infJumpEnabled then startInfJump() else stopInfJump() end
end)

noclipToggle.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    noclipToggle.Text = noclipEnabled and "Noclip: ON" or "Noclip: OFF"
    noclipToggle.BackgroundColor3 = noclipEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    local char = localPlayer.Character
    if char then applyNoclip(char) end
end)

-- ==================== TAB 5: CONFIG (unchanged) ====================
local function collectSettings()
    return {
        autoWinEnabled = autoWinEnabled,
        autoWinSpeed = autoWinSpeed,
        autoTreadmaleEnabled = autoTreadmaleEnabled,
        autoBuyMainEnabled = autoBuyMainEnabled,
        autoBuySelectedItems = {Mysterious = autoBuySelectedItems.Mysterious, Rare = autoBuySelectedItems.Rare, Uncommon = autoBuySelectedItems.Uncommon, Common = autoBuySelectedItems.Common},
        coinFolderPath = folderPathBox.Text,
        autoCoinEnabled = autoCoinEnabled,
        autoCoinMode = autoCoinMode,
        autoCoinFlightSpeed = autoCoinFlightSpeed,
        flightEnabled = flightEnabled,
        flightSpeed = flightSpeed,
        infJumpEnabled = infJumpEnabled,
        noclipEnabled = noclipEnabled,
        walkSpeedValue = walkSpeedValue,
        jumpPowerValue = jumpPowerValue,
        gravityValue = gravityValue,
        world2HelpEnabled = world2HelpEnabled,
        world2DestroyEnabled = world2DestroyEnabled,
        specialKeyHighlightEnabled = specialKeyHighlightEnabled,
        specialKeyFarmEnabled = specialKeyFarmEnabled,
        specialKeyFarmMode = specialKeyFarmMode,
        specialKeyFarmSpeed = specialKeyFarmSpeed
    }
end

local function applySettings(settings)
    if not settings then return end
    autoWinEnabled = settings.autoWinEnabled
    autoWinBtn.Text = autoWinEnabled and "Auto Win: ON" or "Auto Win: OFF"
    autoWinBtn.BackgroundColor3 = autoWinEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    autoWinSpeed = settings.autoWinSpeed or 65
    autoWinSpeedBox.Text = tostring(autoWinSpeed)

    autoTreadmaleEnabled = settings.autoTreadmaleEnabled
    autoTreadmaleBtn.Text = autoTreadmaleEnabled and "Auto treadmill: ON" or "Auto treadmill: OFF"
    autoTreadmaleBtn.BackgroundColor3 = autoTreadmaleEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)

    autoBuyMainEnabled = settings.autoBuyMainEnabled
    autoBuyMainBtn.Text = autoBuyMainEnabled and "Auto Buy: ON" or "Auto Buy: OFF"
    autoBuyMainBtn.BackgroundColor3 = autoBuyMainEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    if settings.autoBuySelectedItems then
        autoBuySelectedItems = settings.autoBuySelectedItems
        for _, itemName in ipairs(AUTOBUY_CONFIG.ITEMS_ORDER) do
            local btnName = "Buy_"..itemName
            local btn = itemGridFrame:FindFirstChild(btnName)
            if btn then
                local isOn = autoBuySelectedItems[itemName]
                btn.Text = "Buy "..itemName..": "..(isOn and "ON" or "OFF")
                btn.BackgroundColor3 = isOn and Color3.fromRGB(0, 120, 80) or Color3.fromRGB(35, 35, 45)
            end
        end
    end

    folderPathBox.Text = settings.coinFolderPath or "CoinBattleCoinsLocal"
    autoCoinEnabled = settings.autoCoinEnabled
    autoCoinToggle.Text = autoCoinEnabled and "Auto Coin: ON" or "Auto Coin: OFF"
    autoCoinToggle.BackgroundColor3 = autoCoinEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    autoCoinMode = settings.autoCoinMode or "TP"
    autoCoinModeBtn.Text = "Mode: "..autoCoinMode
    autoCoinFlightSpeed = settings.autoCoinFlightSpeed or 120
    autoCoinSpeedBox.Text = tostring(autoCoinFlightSpeed)

    flightEnabled = settings.flightEnabled
    flightToggle.Text = flightEnabled and "Flight: ON" or "Flight: OFF"
    flightToggle.BackgroundColor3 = flightEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    if flightEnabled then startFlight() else stopFlight() end
    flightSpeed = settings.flightSpeed or 50
    flightSpeedBox.Text = tostring(flightSpeed)

    infJumpEnabled = settings.infJumpEnabled
    infJumpToggle.Text = infJumpEnabled and "Infinite Jump: ON" or "Infinite Jump: OFF"
    infJumpToggle.BackgroundColor3 = infJumpEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    if infJumpEnabled then startInfJump() else stopInfJump() end

    noclipEnabled = settings.noclipEnabled
    noclipToggle.Text = noclipEnabled and "Noclip: ON" or "Noclip: OFF"
    noclipToggle.BackgroundColor3 = noclipEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    local char = localPlayer.Character; if char then applyNoclip(char) end

    walkSpeedValue = settings.walkSpeedValue or 16
    walkSpeedBox.Text = tostring(walkSpeedValue)
    if char then applyMovementSettings(char) end
    jumpPowerValue = settings.jumpPowerValue or 50
    jumpPowerBox.Text = tostring(jumpPowerValue)
    if char then applyMovementSettings(char) end
    gravityValue = settings.gravityValue or 196.2
    gravityBox.Text = tostring(gravityValue)
    Workspace.Gravity = gravityValue

    world2HelpEnabled = settings.world2HelpEnabled
    world2HelpButton.Text = world2HelpEnabled and "World 2 Help: ON" or "World 2 Help: OFF"
    world2HelpButton.BackgroundColor3 = world2HelpEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    world2DestroyEnabled = settings.world2DestroyEnabled
    world2Button.Text = world2DestroyEnabled and "World 2 Destroy: ON" or "World 2 Destroy: OFF"
    world2Button.BackgroundColor3 = world2DestroyEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)

    specialKeyHighlightEnabled = settings.specialKeyHighlightEnabled
    specialKeyHighlightBtn.Text = specialKeyHighlightEnabled and "Special Key Highlight: ON" or "Special Key Highlight: OFF"
    specialKeyHighlightBtn.BackgroundColor3 = specialKeyHighlightEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)

    specialKeyFarmEnabled = settings.specialKeyFarmEnabled
    specialKeyFarmBtn.Text = specialKeyFarmEnabled and "Special key Farm: ON" or "Special key Farm: OFF"
    specialKeyFarmBtn.BackgroundColor3 = specialKeyFarmEnabled and Color3.fromRGB(0, 140, 90) or Color3.fromRGB(25, 25, 35)
    specialKeyFarmMode = settings.specialKeyFarmMode or "TP"
    specialKeyFarmModeBtn.Text = "Mode: "..specialKeyFarmMode
    specialKeyFarmSpeed = settings.specialKeyFarmSpeed or 100
    specialKeyFarmSpeedBox.Text = tostring(specialKeyFarmSpeed)
end

local function serializeMacros()
    local allMacros = {}
    for i = 1, MACRO_SLOTS do
        local slot = macroSlots[i]
        local dataArray = {}
        for _, frame in ipairs(slot.data) do
            if slot.mode == 1 then
                local comps = {frame.cframe:GetComponents()}
                local rounded = {}; for _,v in ipairs(comps) do table.insert(rounded, roundNum(v)) end
                table.insert(dataArray, {cframe=rounded, dt=roundNum(frame.dt)})
            elseif slot.mode == 2 then
                table.insert(dataArray, {moveDir={roundNum(frame.moveDir.X), roundNum(frame.moveDir.Y), roundNum(frame.moveDir.Z)}, jumping=frame.jumping, dt=roundNum(frame.dt)})
            elseif slot.mode == 3 then
                table.insert(dataArray, {moveVector={roundNum(frame.moveVector.X), roundNum(frame.moveVector.Y), roundNum(frame.moveVector.Z)}, jumping=frame.jumping, dt=roundNum(frame.dt)})
            end
        end
        local startCf = nil
        if slot.startCFrame then
            local raw = {slot.startCFrame:GetComponents()}
            startCf = {}; for _,v in ipairs(raw) do table.insert(startCf, roundNum(v)) end
        end
        allMacros[i] = {mode=slot.mode, startCFrame=startCf, data=dataArray}
    end
    return allMacros
end

local function deserializeMacros(allMacros)
    for i = 1, MACRO_SLOTS do
        macroSlots[i].data = {}
        local saved = allMacros[i]
        if saved then
            macroSlots[i].mode = saved.mode or 1
            macroSlots[i].startCFrame = saved.startCFrame and CFrame.new(unpack(saved.startCFrame))
            for _, frame in ipairs(saved.data or {}) do
                if saved.mode == 1 then
                    table.insert(macroSlots[i].data, {cframe=CFrame.new(unpack(frame.cframe)), dt=frame.dt})
                elseif saved.mode == 2 then
                    table.insert(macroSlots[i].data, {moveDir=Vector3.new(unpack(frame.moveDir)), jumping=frame.jumping, dt=frame.dt})
                elseif saved.mode == 3 then
                    table.insert(macroSlots[i].data, {moveVector=Vector3.new(unpack(frame.moveVector)), jumping=frame.jumping, dt=frame.dt})
                end
            end
        else
            macroSlots[i].mode = 1
            macroSlots[i].startCFrame = nil
            macroSlots[i].data = {}
        end
    end
    updateSlotDisplay()
end

local function loadConfigsFromFile()
    local success, data = pcall(function()
        if readfile and isfile and isfile(SAVE_FILE) then
            return HttpService:JSONDecode(readfile(SAVE_FILE))
        end
        return {}
    end)
    return success and data or {}
end

local function saveConfigsToFile(configs)
    pcall(function()
        if writefile then writefile(SAVE_FILE, HttpService:JSONEncode(configs)) end
    end)
end

local configList = loadConfigsFromFile()
local configNameBox = createTextBox(configPage, "ConfigName", "Config Name", "", 1)
local configDropdown = Instance.new("TextButton")
configDropdown.Size = UDim2.new(1, 0, 0, math.floor(36 * SCALE))
configDropdown.BackgroundColor3 = Color3.fromRGB(35,35,45)
configDropdown.Text = "Select Config..."
configDropdown.TextColor3 = Color3.fromRGB(225, 225, 235)
configDropdown.TextSize = math.floor(12 * SCALE)
configDropdown.Font = Enum.Font.GothamMedium
configDropdown.Parent = configPage
local configDropdownCorner = Instance.new("UICorner"); configDropdownCorner.CornerRadius = UDim.new(0, math.floor(8 * SCALE)); configDropdownCorner.Parent = configDropdown
local configDropdownStroke = Instance.new("UIStroke"); configDropdownStroke.Color = Color3.fromRGB(50,50,70); configDropdownStroke.Thickness = math.max(1, math.floor(1 * SCALE)); configDropdownStroke.Parent = configDropdown

local selectedConfigName = nil
local function updateDropdownText()
    configDropdown.Text = selectedConfigName or "Select Config..."
end

local configKeys = {}
local function refreshConfigKeys()
    configKeys = {}
    for name, _ in pairs(configList) do
        table.insert(configKeys, name)
    end
end
refreshConfigKeys()

configDropdown.MouseButton1Click:Connect(function()
    refreshConfigKeys()
    if #configKeys == 0 then
        configDropdown.Text = "No configs found"
        selectedConfigName = nil
        return
    end
    local currentIdx = table.find(configKeys, selectedConfigName) or 0
    local nextIdx = (currentIdx % #configKeys) + 1
    selectedConfigName = configKeys[nextIdx]
    configDropdown.Text = selectedConfigName
end)

local saveConfigBtn = createButton(configPage, "SaveConfigBtn", "Save Config", Color3.fromRGB(0,120,80))
local loadConfigBtn = createButton(configPage, "LoadConfigBtn", "Load Config", Color3.fromRGB(0,100,160))
local deleteConfigBtn = createButton(configPage, "DeleteConfigBtn", "Delete Config", Color3.fromRGB(200,50,50))
local shareConfigBtn = createButton(configPage, "ShareConfigBtn", "Share Config (Copy)", Color3.fromRGB(110,70,0))
local importConfigBtn = createButton(configPage, "ImportConfigBtn", "Import Config (Paste)", Color3.fromRGB(90,0,130))

saveConfigBtn.MouseButton1Click:Connect(function()
    local name = configNameBox.Text
    if name == "" then return end
    local settings = collectSettings()
    local macros = serializeMacros()
    configList[name] = { settings = settings, macros = macros }
    saveConfigsToFile(configList)
    refreshConfigKeys()
    selectedConfigName = name
    updateDropdownText()
    macroStatusLabel.Text = "Config '"..name.."' saved."
end)

loadConfigBtn.MouseButton1Click:Connect(function()
    if not selectedConfigName then return end
    local config = configList[selectedConfigName]
    if not config then return end
    applySettings(config.settings)
    deserializeMacros(config.macros)
    macroStatusLabel.Text = "Config '"..selectedConfigName.."' loaded."
end)

deleteConfigBtn.MouseButton1Click:Connect(function()
    if not selectedConfigName then return end
    configList[selectedConfigName] = nil
    saveConfigsToFile(configList)
    refreshConfigKeys()
    selectedConfigName = nil
    updateDropdownText()
    macroStatusLabel.Text = "Config deleted."
end)

shareConfigBtn.MouseButton1Click:Connect(function()
    if not selectedConfigName then return end
    local config = configList[selectedConfigName]
    if not config then return end
    local jsonString = HttpService:JSONEncode(config)
    impExpBox.Text = jsonString
    pcall(function() if setclipboard then setclipboard(jsonString) end end)
    macroStatusLabel.Text = "Config '"..selectedConfigName.."' copied to clipboard."
end)

importConfigBtn.MouseButton1Click:Connect(function()
    local text = impExpBox.Text
    if text == "" then return end
    local success, config = pcall(function() return HttpService:JSONDecode(text) end)
    if not success or not config.settings or not config.macros then
        macroStatusLabel.Text = "Invalid config string!"
        return
    end
    local name = configNameBox.Text
    if name == "" then
        macroStatusLabel.Text = "Enter a name for the imported config!"
        return
    end
    configList[name] = config
    saveConfigsToFile(configList)
    refreshConfigKeys()
    selectedConfigName = name
    updateDropdownText()
    macroStatusLabel.Text = "Config '"..name.."' imported."
end)

-- ==================== TAB 6: MACRO ENGINE (5 SLOTS) ====================
local MACRO_SLOTS = 5
local macroSlots = {}
for i = 1, MACRO_SLOTS do macroSlots[i] = { data = {}, mode = 1, startCFrame = nil } end
local currentSlot = 1
local isRecording = false
local isPlaying = false
local isLooping = false
local playbackSpeed = 1
local recordHeartbeatConn = nil

local macroStatusLabel = Instance.new("TextLabel")
macroStatusLabel.Size = UDim2.new(1, 0, 0, math.floor(22 * SCALE))
macroStatusLabel.BackgroundTransparency = 1
macroStatusLabel.Text = "Status: Idle | Slot 1"
macroStatusLabel.TextColor3 = Color3.fromRGB(0, 190, 255)
macroStatusLabel.TextSize = math.floor(12 * SCALE)
macroStatusLabel.Font = Enum.Font.GothamBold
macroStatusLabel.Parent = macroPage

local slotSelectFrame = Instance.new("Frame")
slotSelectFrame.Size = UDim2.new(1, 0, 0, math.floor(36 * SCALE))
slotSelectFrame.BackgroundTransparency = 1
slotSelectFrame.Parent = macroPage
local slotLayout = Instance.new("UIListLayout")
slotLayout.Parent = slotSelectFrame; slotLayout.FillDirection = Enum.FillDirection.Horizontal; slotLayout.Padding = UDim.new(0, 4 * SCALE)
local slotButtons = {}
for i = 1, MACRO_SLOTS do
    local btn = createButton(slotSelectFrame, "Slot"..i, "Slot "..i, Color3.fromRGB(35,35,45))
    btn.Size = UDim2.new(0.2, -4 * SCALE, 1, 0)
    if i == 1 then btn.BackgroundColor3 = Color3.fromRGB(0,140,210); btn.TextColor3 = Color3.fromRGB(255,255,255) end
    btn.MouseButton1Click:Connect(function()
        if isRecording or isPlaying then return end
        for j = 1, MACRO_SLOTS do slotButtons[j].BackgroundColor3 = Color3.fromRGB(35,35,45); slotButtons[j].TextColor3 = Color3.fromRGB(225,225,235) end
        currentSlot = i
        btn.BackgroundColor3 = Color3.fromRGB(0,140,210); btn.TextColor3 = Color3.fromRGB(255,255,255)
        updateSlotDisplay()
    end)
    slotButtons[i] = btn
end

local function updateSlotDisplay()
    local slot = macroSlots[currentSlot]
    modeBtn.Text = ({ "Mode 1: CFrame", "Mode 2: Mobile Joystick", "Mode 3: PC WASD" })[slot.mode]
    macroStatusLabel.Text = string.format("Status: Idle | Slot %d (%d frames)", currentSlot, #slot.data)
end

local modeBtn = createButton(macroPage, "ModeBtn", "Mode 1: CFrame", Color3.fromRGB(40,40,58))
local speedBtn = createButton(macroPage, "SpeedBtn", "Playback Speed: 1x")
local recordBtn = createButton(macroPage, "RecordBtn", "Start Recording")
local playBtn = createButton(macroPage, "PlayBtn", "Play Macro", Color3.fromRGB(0,120,180))
local stopBtn = createButton(macroPage, "StopBtn", "Stop Macro (Instant)", Color3.fromRGB(180,40,40))
local loopBtn = createButton(macroPage, "LoopBtn", "Loop Macro: OFF")

local function updateModeBtnText()
    local slot = macroSlots[currentSlot]
    modeBtn.Text = ({ "Mode 1: CFrame Teleport", "Mode 2: Mobile Joystick", "Mode 3: PC WASD (Keyboard)" })[slot.mode]
end

modeBtn.MouseButton1Click:Connect(function()
    if isRecording or isPlaying then return end
    local slot = macroSlots[currentSlot]
    slot.mode = (slot.mode % 3) + 1; slot.data = {}
    updateModeBtnText(); macroStatusLabel.Text = "Mode switched. Data cleared."
end)

speedBtn.MouseButton1Click:Connect(function()
    playbackSpeed = playbackSpeed + 0.5
    if playbackSpeed > 10 then playbackSpeed = 0.5 end
    speedBtn.Text = "Playback Speed: "..tostring(playbackSpeed).."x"
end)

recordBtn.MouseButton1Click:Connect(function()
    if isPlaying then return end
    isRecording = not isRecording
    if isRecording then
        local slot = macroSlots[currentSlot]; slot.data = {}
        local char = localPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then slot.startCFrame = hrp.CFrame end
        recordBtn.Text = "Stop Recording"; recordBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
        local accum = 0
        recordHeartbeatConn = RunService.Heartbeat:Connect(function(dt)
            if not isRecording then return end
            accum = accum + dt
            if accum >= recordInterval then
                accum = accum - recordInterval
                local character = localPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hrp and hum then
                    local newFrame
                    if slot.mode == 1 then
                        newFrame = { cframe = hrp.CFrame, dt = recordInterval }
                    elseif slot.mode == 2 then
                        local isJumping = mobileJumpActive or hum.Jump or (hum:GetState() == Enum.HumanoidStateType.Jumping)
                        newFrame = { moveDir = hum.MoveDirection, jumping = isJumping, dt = recordInterval }
                    elseif slot.mode == 3 then
                        local moveVec = Vector3.zero
                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec = moveVec + Vector3.new(0,0,-1) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec = moveVec + Vector3.new(0,0,1) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec = moveVec + Vector3.new(-1,0,0) end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec = moveVec + Vector3.new(1,0,0) end
                        local isJumping = UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump
                        newFrame = { moveVector = moveVec, jumping = isJumping, dt = recordInterval }
                    end
                    if newFrame then table.insert(slot.data, newFrame) end
                    macroStatusLabel.Text = string.format("Recording Slot %d... (%d Frames)", currentSlot, #slot.data)
                end
            end
        end)
    else
        if recordHeartbeatConn then recordHeartbeatConn:Disconnect(); recordHeartbeatConn = nil end
        recordBtn.Text = "Start Recording"; recordBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
        macroStatusLabel.Text = string.format("Recorded %d Frames in Slot %d. Save config to keep.", #macroSlots[currentSlot].data, currentSlot)
    end
end)

local function runMacroPlayback(slotIndex)
    local slot = macroSlots[slotIndex]
    if #slot.data == 0 then macroStatusLabel.Text = "Error: No recorded data in Slot "..slotIndex; return end
    isPlaying = true; playBtn.Text = "Playing..."; playBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
    repeat
        local char = localPlayer.Character; local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if char and hrp and hum then
            if slot.startCFrame then
                hrp.CFrame = slot.startCFrame; hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
                if slot.mode == 1 then fireUpdateSpeedEvent() end
            end
            task.wait(0.15)
            if slot.mode == 1 then
                for _, frame in ipairs(slot.data) do
                    if not isPlaying then break end
                    hrp.CFrame = frame.cframe; hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
                    fireUpdateSpeedEvent()
                    local target = frame.dt / playbackSpeed; local elapsed = 0
                    while elapsed < target and isPlaying do elapsed += RunService.RenderStepped:Wait() end
                end
            elseif slot.mode == 2 then
                setMobileControlsEnabled(false)
                for _, frame in ipairs(slot.data) do
                    if not isPlaying then break end
                    local target = frame.dt / playbackSpeed; local elapsed = 0
                    while elapsed < target and isPlaying do
                        hum:Move(frame.moveDir, false); if frame.jumping then hum.Jump = true end
                        elapsed += RunService.RenderStepped:Wait()
                    end
                end
                setMobileControlsEnabled(true)
            elseif slot.mode == 3 then
                for _, frame in ipairs(slot.data) do
                    if not isPlaying then break end
                    local target = frame.dt / playbackSpeed; local elapsed = 0
                    while elapsed < target and isPlaying do
                        hum:Move(frame.moveVector, true); if frame.jumping then hum.Jump = true end
                        elapsed += RunService.RenderStepped:Wait()
                    end
                end
            end
        end
    until not isLooping or not isPlaying
    setMobileControlsEnabled(true)
    isPlaying = false; playBtn.Text = "Play Macro"; playBtn.BackgroundColor3 = Color3.fromRGB(0,120,180)
    if not isLooping then macroStatusLabel.Text = "Status: Idle | Slot "..currentSlot end
end

playBtn.MouseButton1Click:Connect(function()
    if isRecording or isPlaying then return end
    safeSpawn(function() runMacroPlayback(currentSlot) end)
end)

stopBtn.MouseButton1Click:Connect(function()
    isRecording = false; isPlaying = false; isLooping = false
    if recordHeartbeatConn then recordHeartbeatConn:Disconnect(); recordHeartbeatConn = nil end
    recordBtn.Text = "Start Recording"; recordBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    playBtn.Text = "Play Macro"; playBtn.BackgroundColor3 = Color3.fromRGB(0,120,180)
    loopBtn.Text = "Loop Macro: OFF"; loopBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    setMobileControlsEnabled(true)
    macroStatusLabel.Text = "Status: Instantly Stopped!"
end)

loopBtn.MouseButton1Click:Connect(function()
    isLooping = not isLooping
    loopBtn.Text = "Loop Macro: "..(isLooping and "ON" or "OFF")
    loopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(0,140,90) or Color3.fromRGB(25,25,35)
    if isLooping and not isPlaying and not isRecording then safeSpawn(function() runMacroPlayback(currentSlot) end) end
end)

-- Per‑slot import/export
local impExpBox = Instance.new("TextBox")
impExpBox.Size = UDim2.new(1, 0, 0, math.floor(50 * SCALE))
impExpBox.BackgroundColor3 = Color3.fromRGB(20,20,30)
impExpBox.PlaceholderText = "Paste Macro Code here to Import, or click Export..."
impExpBox.Text = ""
impExpBox.TextColor3 = Color3.fromRGB(220,220,245)
impExpBox.TextSize = math.floor(11 * SCALE)
impExpBox.Font = Enum.Font.Code
impExpBox.ClearTextOnFocus = false; impExpBox.TextWrapped = true; impExpBox.MultiLine = true; impExpBox.Parent = macroPage
local exportSlotBtn = createButton(macroPage, "ExportSlotBtn", "Export Slot to String", Color3.fromRGB(110,70,0))
local importSlotBtn = createButton(macroPage, "ImportSlotBtn", "Import String to Slot", Color3.fromRGB(90,0,130))

exportSlotBtn.MouseButton1Click:Connect(function()
    local slot = macroSlots[currentSlot]
    if #slot.data == 0 then macroStatusLabel.Text = "Export Error: No macro recorded!"; return end
    local dataArray = {}
    for _, frame in ipairs(slot.data) do
        if slot.mode == 1 then
            local comps = {frame.cframe:GetComponents()}; local rounded = {}; for _,v in ipairs(comps) do table.insert(rounded, roundNum(v)) end
            table.insert(dataArray, {cframe=rounded, dt=roundNum(frame.dt)})
        elseif slot.mode == 2 then
            table.insert(dataArray, {moveDir={roundNum(frame.moveDir.X), roundNum(frame.moveDir.Y), roundNum(frame.moveDir.Z)}, jumping=frame.jumping, dt=roundNum(frame.dt)})
        elseif slot.mode == 3 then
            table.insert(dataArray, {moveVector={roundNum(frame.moveVector.X), roundNum(frame.moveVector.Y), roundNum(frame.moveVector.Z)}, jumping=frame.jumping, dt=roundNum(frame.dt)})
        end
    end
    local startCf = nil
    if slot.startCFrame then
        local raw = {slot.startCFrame:GetComponents()}; startCf = {}; for _,v in ipairs(raw) do table.insert(startCf, roundNum(v)) end
    end
    local exportData = {mode=slot.mode, startCFrame=startCf, data=dataArray}
    local jsonString = HttpService:JSONEncode(exportData)
    impExpBox.Text = jsonString
    pcall(function() if setclipboard then setclipboard(jsonString) end end)
    macroStatusLabel.Text = "Exported to text box & copied to clipboard!"
end)

importSlotBtn.MouseButton1Click:Connect(function()
    local text = impExpBox.Text; if text == "" then macroStatusLabel.Text = "Import Error: Textbox is empty!"; return end
    local success, decoded = pcall(function() return HttpService:JSONDecode(text) end)
    if success then
        local slot = macroSlots[currentSlot]
        slot.mode = decoded.mode or 1; slot.startCFrame = decoded.startCFrame and CFrame.new(unpack(decoded.startCFrame))
        slot.data = {}
        for _, frame in ipairs(decoded.data or {}) do
            if decoded.mode == 1 then table.insert(slot.data, {cframe=CFrame.new(unpack(frame.cframe)), dt=frame.dt})
            elseif decoded.mode == 2 then table.insert(slot.data, {moveDir=Vector3.new(unpack(frame.moveDir)), jumping=frame.jumping, dt=frame.dt})
            elseif decoded.mode == 3 then table.insert(slot.data, {moveVector=Vector3.new(unpack(frame.moveVector)), jumping=frame.jumping, dt=frame.dt}) end
        end
        updateSlotDisplay()
        macroStatusLabel.Text = "Imported macro into Slot "..currentSlot.." ("..#slot.data.." Frames)!"
    else
        macroStatusLabel.Text = "Import Error: Invalid macro string!"
    end
end)

-- Initial macro data load from first config if any
if next(configList) then
    local first = next(configList)
    selectedConfigName = first
    updateDropdownText()
    local config = configList[first]
    if config.settings then applySettings(config.settings) end
    if config.macros then deserializeMacros(config.macros) end
end

updateSlotDisplay()

-- ==================== TAB 7: SETTINGS ====================
local antiAfkEnabled = false
local antiAfkBtn = createButton(settingsPage, "AntiAfkBtn", "Anti AFK (PC & Mobile): OFF")
safeConnect(localPlayer.Idled, function()
    if antiAfkEnabled then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
end)
safeSpawn(function()
    while not hubDestroyed do
        if antiAfkEnabled then
            pcall(function()
                local char = localPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
        task.wait(60)
    end
end)
antiAfkBtn.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    antiAfkBtn.Text = antiAfkEnabled and "Anti AFK (PC & Mobile): ON" or "Anti AFK (PC & Mobile): OFF"
    antiAfkBtn.BackgroundColor3 = antiAfkEnabled and Color3.fromRGB(0,140,90) or Color3.fromRGB(25,25,35)
end)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, math.floor(60 * SCALE))
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Press 'F1' to PANIC STOP all features.\nPress 'C' to close/destroy entire Noctis Hub.\nDrag top header to move GUI around screen."
infoLabel.TextColor3 = Color3.fromRGB(150,150,170); infoLabel.TextSize = math.floor(12 * SCALE)
infoLabel.Font = Enum.Font.GothamMedium; infoLabel.TextWrapped = true; infoLabel.Parent = settingsPage

local function stopAllFeatures()
    autoWinEnabled = false; autoWinBtn.Text = "Auto Win: OFF"; autoWinBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    autoTreadmaleEnabled = false; autoTreadmaleBtn.Text = "Auto treadmill: OFF"; autoTreadmaleBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    autoCoinEnabled = false; autoCoinToggle.Text = "Auto Coin: OFF"; autoCoinToggle.BackgroundColor3 = Color3.fromRGB(25,25,35)
    autoBuyMainEnabled = false; autoBuyMainBtn.Text = "Auto Buy: OFF"; autoBuyMainBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    world2DestroyEnabled = false; world2Button.Text = "World 2 Destroy: OFF"; world2Button.BackgroundColor3 = Color3.fromRGB(25,25,35)
    specialKeyFarmEnabled = false; specialKeyFarmBtn.Text = "Special key Farm: OFF"; specialKeyFarmBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    flightEnabled = false; stopFlight(); flightToggle.Text = "Flight: OFF"; flightToggle.BackgroundColor3 = Color3.fromRGB(25,25,35)
    infJumpEnabled = false; stopInfJump(); infJumpToggle.Text = "Infinite Jump: OFF"; infJumpToggle.BackgroundColor3 = Color3.fromRGB(25,25,35)
    noclipEnabled = false; noclipToggle.Text = "Noclip: OFF"; noclipToggle.BackgroundColor3 = Color3.fromRGB(25,25,35)
    local char = localPlayer.Character; if char then applyNoclip(char) end
    isRecording = false; isPlaying = false; isLooping = false
    if recordHeartbeatConn then recordHeartbeatConn:Disconnect(); recordHeartbeatConn = nil end
    recordBtn.Text = "Start Recording"; recordBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    playBtn.Text = "Play Macro"; playBtn.BackgroundColor3 = Color3.fromRGB(0,120,180)
    loopBtn.Text = "Loop Macro: OFF"; loopBtn.BackgroundColor3 = Color3.fromRGB(25,25,35)
    setMobileControlsEnabled(true)
end

safeConnect(UserInputService.InputBegan, function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.C then cleanupAll(); screenGui:Destroy()
    elseif input.KeyCode == Enum.KeyCode.F1 then stopAllFeatures() end
end)

print("Noctis Hub – Fully Loaded!")
