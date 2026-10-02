-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (Phases 1 - 4 Combined)
-- ==============================================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

print("[AetheriusCore]: Initializing Core Intelligence Analyzer (Phase 4)...")

-- 1. ROBUST UI CONTAINER SETUP (Delta & gethui compatibility)
local rootParent = CoreGui
if syn and syn.protect_gui then
    local suc, protected = pcall(syn.protect_gui)
    if suc and protected then rootParent = protected end
elseif gethui then
    local suc, res = pcall(gethui)
    if suc and res then rootParent = res end
end

-- Cleanup previous instance if it exists
if rootParent:FindFirstChild("AetheriusCoreUI") then
    rootParent.AetheriusCoreUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AetheriusCoreUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = rootParent

-- 2. MAIN WINDOW UI LAYOUT
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 350, 0, 310)
MainWindow.Position = UDim2.new(0.5, -175, 0.5, -155)
MainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainWindow.BorderSizePixel = 0
MainWindow.Visible = true 
MainWindow.Parent = ScreenGui

local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 10)
cornerMain.Parent = MainWindow

-- Title Bar
local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.Text = "  AetheriusCore v0.4 (Phase 4: Behavior)"
TitleBar.TextSize = 12
TitleBar.Font = Enum.Font.GothamBold
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.Parent = MainWindow

-- Close Button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.TextColor3 = Color3.fromRGB(200, 80, 80)
CloseBtn.Text = "X"
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Tab Container Bar (Expanded to 4 Tabs)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 30)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainWindow

-- Content Area Frame
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, 0, 1, -58)
ContentArea.Position = UDim2.new(0, 0, 0, 58)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainWindow

-- Tabs & Panels Setup
local tabs = {"Overview", "Objects", "Remotes", "Behavior"}
local panels = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = tabName
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabBar

    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, -10, 1, -10)
    panel.Position = UDim2.new(0, 5, 0, 5)
    panel.BackgroundTransparency = 1
    panel.Visible = (tabName == "Overview")
    panel.CanvasSize = UDim2.new(0, 0, 2, 0)
    panel.ScrollBarThickness = 4
    panel.Parent = ContentArea
    
    panels[tabName] = panel
    
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(panels) do p.Visible = false end
        panel.Visible = true
    end)
end

-- Panel Text Containers
local overviewText = Instance.new("TextLabel")
overviewText.Size = UDim2.new(1, 0, 0, 140)
overviewText.BackgroundTransparency = 1
overviewText.TextColor3 = Color3.fromRGB(220, 220, 220)
overviewText.TextSize = 11
overviewText.Font = Enum.Font.Code
overviewText.TextXAlignment = Enum.TextXAlignment.Left
overviewText.TextYAlignment = Enum.TextYAlignment.Top
overviewText.Parent = panels["Overview"]
overviewText.Text = "Status: Scanning Workspace & Initializing Behavior Tracker..."

local remotesText = Instance.new("TextLabel")
remotesText.Size = UDim2.new(1, 0, 0, 200)
remotesText.BackgroundTransparency = 1
remotesText.TextColor3 = Color3.fromRGB(200, 220, 255)
remotesText.TextSize = 11
remotesText.Font = Enum.Font.Code
remotesText.TextXAlignment = Enum.TextXAlignment.Left
remotesText.TextYAlignment = Enum.TextYAlignment.Top
remotesText.Parent = panels["Remotes"]

local behaviorText = Instance.new("TextLabel")
behaviorText.Size = UDim2.new(1, 0, 0, 300)
behaviorText.BackgroundTransparency = 1
behaviorText.TextColor3 = Color3.fromRGB(180, 255, 180)
behaviorText.TextSize = 10
behaviorText.Font = Enum.Font.Code
behaviorText.TextXAlignment = Enum.TextXAlignment.Left
behaviorText.TextYAlignment = Enum.TextYAlignment.Top
behaviorText.Parent = panels["Behavior"]
behaviorText.Text = "Behavior Monitor Active...\nWaiting for runtime events (spawns/despawns)..."


-- 3. PHASE 1 & 4: SCANNING ENGINE + BEHAVIOR MONITOR
local ScanConfig = {
    MaxDepth = 3,
    YieldEvery = 150,
}

local function classifyInstance(instance)
    if instance:IsA("Model") and instance:FindFirstChild("Humanoid") then
        if instance == LocalPlayer.Character then
            return "LocalPlayer"
        else
            return "Character/NPC"
        end
    elseif instance:IsA("Tool") then
        return "Tool"
    elseif instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
        return "NetworkRemote"
    end
    return instance.ClassName
end

-- Runtime Event History Buffer (Phase 4)
local eventHistory = {}
local maxHistorySize = 25

local function logBehaviorEvent(eventType, itemName, itemClass)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] %s: %s (%s)", timestamp, eventType, itemName, itemClass)
    
    table.insert(eventHistory, 1, entry) -- Insert at top
    if #eventHistory > maxHistorySize then
        table.remove(eventHistory) -- Drop oldest to save mobile RAM
    end
    
    behaviorText.Text = table.concat(eventHistory, "\n")
end

-- Background Scan Task
task.spawn(function()
    local startTime = tick()
    local totalInstances = 0
    local remoteCount = 0
    local workspaceData = {}
    
    local function scanRecursive(instance, currentDepth)
        if currentDepth > ScanConfig.MaxDepth then return nil end
        
        totalInstances = totalInstances + 1
        if totalInstances % ScanConfig.YieldEvery == 0 then
            task.wait()
        end
        
        local category = classifyInstance(instance)
        if category == "NetworkRemote" then
            remoteCount = remoteCount + 1
        end
        
        local data = {
            Name = instance.Name,
            Class = category,
            Children = {}
        }
        
        for _, child in ipairs(instance:GetChildren()) do
            local childData = scanRecursive(child, currentDepth + 1)
            if childData then
                table.insert(data.Children, childData)
            end
        end
        
        return data
    end
    
    local scannedTree = scanRecursive(Workspace, 1)
    local elapsedTime = tick() - startTime
    
    overviewText.Text = string.format([[
 Status: Active & Monitoring (%.2fs)
 Scanned Nodes: %d
 Remotes Identified: %d
 Environment: Delta Mobile
 Behavior Feed: Active (Capped @ %d)]], elapsedTime, totalInstances, remoteCount, maxHistorySize)

    remotesText.Text = string.format("Detected %d remote objects in client hierarchy.", remoteCount)

    -- Hook up Phase 4 Runtime Listeners (Workspace changes)
    Workspace.ChildAdded:Connect(function(child)
        logBehaviorEvent("SPAWN", child.Name, child.ClassName)
    end)

    Workspace.ChildRemoved:Connect(function(child)
        logBehaviorEvent("REMOVE", child.Name, child.ClassName)
    end)

    -- Export file via Delta filesystem
    if writefile then
        if not isfolder("AetheriusCore") then
            makefolder("AetheriusCore")
        end
        writefile("AetheriusCore/ScanResult.json", HttpService:JSONEncode(scannedTree))
        print("[AetheriusCore]: Workspace scan exported successfully to workspace/AetheriusCore/ScanResult.json")
    end
end)

print("[AetheriusCore]: Phases 1-4 loaded successfully.")
