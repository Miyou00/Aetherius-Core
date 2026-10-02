-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (v0.10.4 Ultra-Compact)
-- ==============================================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

print("[AetheriusCore]: Initializing Ultra-Compact Suite...")

-- 1. ROBUST UI CONTAINER SETUP
local rootParent = CoreGui
if syn and syn.protect_gui then
    local suc, protected = pcall(syn.protect_gui)
    if suc and protected then rootParent = protected end
elseif gethui then
    local suc, res = pcall(gethui)
    if suc and res then rootParent = res end
end

if rootParent:FindFirstChild("AetheriusCoreUI") then
    rootParent.AetheriusCoreUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AetheriusCoreUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = rootParent

-- 2. MAIN WINDOW UI LAYOUT (Reduced by 30%: 240x185)
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 240, 0, 185)
MainWindow.Position = UDim2.new(0.5, -120, 0.5, -92)
MainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainWindow.BorderSizePixel = 0
MainWindow.Visible = true 
MainWindow.Parent = ScreenGui

local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 6)
cornerMain.Parent = MainWindow

-- Title Bar (20px height)
local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 20)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.Text = " AetheriusCore v0.10.4"
TitleBar.TextSize = 9
TitleBar.Font = Enum.Font.GothamBold
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.Parent = MainWindow

-- Dragging Functionality for Mobile/PC
local dragging, dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainWindow.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 20, 0, 20)
CloseBtn.Position = UDim2.new(1, -20, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.TextColor3 = Color3.fromRGB(200, 80, 80)
CloseBtn.Text = "X"
CloseBtn.TextSize = 10
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Minimize Button (-)
local minimized = false
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 20, 0, 20)
MinimizeBtn.Position = UDim2.new(1, -40, 0, 0)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 100)
MinimizeBtn.Text = "-"
MinimizeBtn.TextSize = 12
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = TitleBar

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, 0, 1, -40)
ContentArea.Position = UDim2.new(0, 0, 0, 40)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainWindow

MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    ContentArea.Visible = not minimized
    MainWindow.Size = minimized and UDim2.new(0, 240, 0, 20) or UDim2.new(0, 240, 0, 185)
    MinimizeBtn.Text = minimized and "+" or "-"
end)

-- 4 Streamlined Tabs (20px height)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 20)
TabBar.Position = UDim2.new(0, 0, 0, 20)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainWindow

local tabs = {"Overview", "Explorer", "Runtime", "Data"}
local panels = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = tabName
    btn.TextSize = 9
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabBar

    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, -4, 1, -4)
    panel.Position = UDim2.new(0, 2, 0, 2)
    panel.BackgroundTransparency = 1
    panel.Visible = (tabName == "Overview")
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.ScrollBarThickness = 2
    panel.Parent = ContentArea
    
    local uiList = Instance.new("UIListLayout")
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Padding = UDim.new(0, 2)
    uiList.Parent = panel
    
    panels[tabName] = panel
    
    btn.MouseButton1Click:Connect(function()
        local selectedPanel = panel
        for _, p in pairs(panels) do p.Visible = false end
        selectedPanel.Visible = true
    end)
end

-- Panel UI Setup (Ultra-Compact elements)
local overviewText = Instance.new("TextLabel")
overviewText.Size = UDim2.new(1, 0, 0, 120)
overviewText.BackgroundTransparency = 1
overviewText.TextColor3 = Color3.fromRGB(220, 220, 220)
overviewText.TextSize = 9
overviewText.Font = Enum.Font.Code
overviewText.TextXAlignment = Enum.TextXAlignment.Left
overviewText.TextYAlignment = Enum.TextYAlignment.Top
overviewText.LayoutOrder = 1
overviewText.Parent = panels["Overview"]
overviewText.Text = "Status: Preparing scanner..."

-- Runtime Tab with Pause Toggle
local runtimePaused = false
local pauseToggleBtn = Instance.new("TextButton")
pauseToggleBtn.Size = UDim2.new(1, 0, 0, 20)
pauseToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
pauseToggleBtn.TextColor3 = Color3.fromRGB(255, 200, 100)
pauseToggleBtn.TextSize = 9
pauseToggleBtn.Font = Enum.Font.GothamBold
pauseToggleBtn.Text = "⏸ Pause Log Stream"
pauseToggleBtn.LayoutOrder = 1
pauseToggleBtn.Parent = panels["Runtime"]

pauseToggleBtn.MouseButton1Click:Connect(function()
    runtimePaused = not runtimePaused
    pauseToggleBtn.BackgroundColor3 = runtimePaused and Color3.fromRGB(45, 35, 30) or Color3.fromRGB(35, 35, 45)
    pauseToggleBtn.TextColor3 = runtimePaused and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 200, 100)
    pauseToggleBtn.Text = runtimePaused and "▶ Resume Log Stream" or "⏸ Pause Log Stream"
end)

local runtimeText = Instance.new("TextLabel")
runtimeText.Size = UDim2.new(1, 0, 0, 120)
runtimeText.BackgroundTransparency = 1
runtimeText.TextColor3 = Color3.fromRGB(255, 230, 150)
runtimeText.TextSize = 8
runtimeText.Font = Enum.Font.Code
runtimeText.TextXAlignment = Enum.TextXAlignment.Left
runtimeText.TextYAlignment = Enum.TextYAlignment.Top
runtimeText.LayoutOrder = 2
runtimeText.Parent = panels["Runtime"]
runtimeText.Text = "Runtime Activity Stream Active..."

local exportStatusLabel = Instance.new("TextLabel")
exportStatusLabel.Size = UDim2.new(1, 0, 0, 35)
exportStatusLabel.BackgroundTransparency = 1
exportStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
exportStatusLabel.TextSize = 9
exportStatusLabel.Font = Enum.Font.Code
exportStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
exportStatusLabel.LayoutOrder = 1
exportStatusLabel.Text = "Export Path: workspace/AetheriusCore/\nStatus: Pending"
exportStatusLabel.Parent = panels["Data"]

local clearLogsBtn = Instance.new("TextButton")
clearLogsBtn.Size = UDim2.new(1, 0, 0, 24)
clearLogsBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 30)
clearLogsBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
clearLogsBtn.TextSize = 9
clearLogsBtn.Font = Enum.Font.GothamBold
clearLogsBtn.Text = "Clear Log History"
clearLogsBtn.LayoutOrder = 2
clearLogsBtn.Parent = panels["Data"]

panels["Data"].CanvasSize = UDim2.new(0, 0, 0, 60)

-- Helper: Get Clean Path
local function getFullPath(instance)
    local name = instance.Name
    local parent = instance.Parent
    if parent == Workspace then return 'game:GetService("Workspace").' .. name
    elseif parent == ReplicatedStorage then return 'game:GetService("ReplicatedStorage").' .. name
    else return instance:GetFullName() end
end

-- 3. CORE LOGGING & HOOKING ENGINE
local runtimeHistory = {}
local maxHistorySize = 15

local function logRuntimeEvent(entry)
    if runtimePaused then return end
    table.insert(runtimeHistory, 1, entry)
    if #runtimeHistory > maxHistorySize then table.remove(runtimeHistory) end
    runtimeText.Text = table.concat(runtimeHistory, "\n\n")
end

clearLogsBtn.MouseButton1Click:Connect(function()
    table.clear(runtimeHistory)
    runtimeText.Text = "History cleared."
end)

-- Universal NameCall Hook
if hookmetamethod and getnamecallmethod then
    local oldNameCall
    oldNameCall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if (method == "FireServer" or method == "InvokeServer") and self:IsA("Instance") then
            logRuntimeEvent(string.format("[%s] [%s] %s", os.date("%H:%M:%S"), method, self.Name))
        end
        return oldNameCall(self, ...)
    end)
end

-- Background Unified Scanner Task with Real-time Feedback
task.spawn(function()
    local startTime = tick()
    local totalInstances = 0
    local remoteCount = 0
    local objectCount = 0
    local valueCount = 0
    local explorerEntries = 0

    TitleBar.Text = " AetheriusCore [Scanning...]"
    overviewText.Text = "Status: Scanning Workspace..."

    local function processContainer(containerName, container)
        TitleBar.Text = string.format(" AetheriusCore [%s...]", containerName)
        overviewText.Text = string.format("Status: Scanning %s...\nNodes: %d", containerName, totalInstances)

        for _, descendant in ipairs(container:GetDescendants()) do
            totalInstances = totalInstances + 1
            if totalInstances % 300 == 0 then 
                task.wait() 
                overviewText.Text = string.format("Status: Scanning %s...\nNodes: %d | Remotes: %d", containerName, totalInstances, remoteCount)
            end
            
            local isRemote = descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")
            local isValue = descendant:IsA("ValueBase")
            local isKeyObj = descendant:IsA("Tool") or (descendant:IsA("Model") and descendant:FindFirstChild("Humanoid"))
            
            if isRemote or isValue or isKeyObj then
                explorerEntries = explorerEntries + 1
                if isRemote then remoteCount = remoteCount + 1 end
                if isValue then valueCount = valueCount + 1 end
                if isKeyObj then objectCount = objectCount + 1 end
                
                local itemBtn = Instance.new("TextButton")
                itemBtn.Size = UDim2.new(1, 0, 0, 20)
                itemBtn.BackgroundColor3 = isRemote and Color3.fromRGB(30, 30, 45) or (isValue and Color3.fromRGB(25, 40, 30) or Color3.fromRGB(35, 35, 35))
                itemBtn.TextColor3 = isRemote and Color3.fromRGB(150, 200, 255) or (isValue and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(220, 220, 150))
                itemBtn.TextSize = 8
                itemBtn.Font = Enum.Font.Code
                itemBtn.LayoutOrder = explorerEntries
                
                local displayInfo = isValue and string.format(" [%s] %s=%s", descendant.ClassName, descendant.Name, tostring(descendant.Value)) or string.format(" [%s] %s", descendant.ClassName, descendant.Name)
                itemBtn.Text = displayInfo
                itemBtn.TextXAlignment = Enum.TextXAlignment.Left
                itemBtn.Parent = panels["Explorer"]
                panels["Explorer"].CanvasSize = UDim2.new(0, 0, 0, explorerEntries * 22)
                
                itemBtn.MouseButton1Click:Connect(function()
                    if setclipboard then
                        setclipboard(getFullPath(descendant))
                        itemBtn.Text = " Copied!"
                        task.wait(1)
                        itemBtn.Text = displayInfo
                    end
                end)
            end
        end
    end

    processContainer("Workspace", Workspace)
    processContainer("ReplicatedStorage", ReplicatedStorage)

    TitleBar.Text = " AetheriusCore [Exporting...]"
    overviewText.Text = "Status: Writing data files..."

    local elapsedTime = tick() - startTime
    
    if writefile then
        if not isfolder("AetheriusCore") then makefolder("AetheriusCore") end
        writefile("AetheriusCore/CoreData.json", HttpService:JSONEncode({Remotes = remoteCount, Values = valueCount, Objects = objectCount}))
        exportStatusLabel.Text = "Export Path: workspace/AetheriusCore/\nStatus: Success!"
    end

    TitleBar.Text = " AetheriusCore v0.10.4 [Ready]"
    overviewText.Text = string.format([[
 Scan Complete (%.2fs)
 Nodes: %d | Remotes: %d
 Values: %d | Objects: %d
 Size: Ultra-Compact (240x185)]], elapsedTime, totalInstances, remoteCount, valueCount, objectCount)

    Workspace.ChildAdded:Connect(function(child)
        logRuntimeEvent(string.format("[%s] [+] %s", os.date("%H:%M:%S"), child.Name))
    end)
    Workspace.ChildRemoved:Connect(function(child)
        logRuntimeEvent(string.format("[%s] [-] %s", os.date("%H:%M:%S"), child.Name))
    end)
end)

print("[AetheriusCore]: Ultra-Compact Suite active.")
