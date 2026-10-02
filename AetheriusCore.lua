-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (Fixed Panels)
-- ==============================================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

print("[AetheriusCore]: Initializing Fixed Analyzer...")

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

-- 2. MAIN WINDOW UI LAYOUT
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 360, 0, 320)
MainWindow.Position = UDim2.new(0.5, -180, 0.5, -160)
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
TitleBar.Text = "  AetheriusCore v0.7 (Fixed Inspector)"
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

-- Tab Container Bar (5 Tabs)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 30)
TabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
TabBar.BorderSizePixel = 0
TabBar.Parent = MainWindow

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, 0, 1, -58)
ContentArea.Position = UDim2.new(0, 0, 0, 58)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainWindow

local tabs = {"Overview", "Objects", "Remotes", "Behavior", "Data"}
local panels = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = tabName
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabBar

    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, -10, 1, -10)
    panel.Position = UDim2.new(0, 5, 0, 5)
    panel.BackgroundTransparency = 1
    panel.Visible = (tabName == "Overview")
    panel.CanvasSize = UDim2.new(0, 0, 0, 0)
    panel.ScrollBarThickness = 4
    panel.Parent = ContentArea
    
    local uiList = Instance.new("UIListLayout")
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Padding = UDim.new(0, 4)
    uiList.Parent = panel
    
    panels[tabName] = panel
    
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(panels) do p.Visible = false end
        panel.Visible = true
    end)
end

-- Panel UI Elements Setup
local overviewText = Instance.new("TextLabel")
overviewText.Size = UDim2.new(1, 0, 0, 140)
overviewText.BackgroundTransparency = 1
overviewText.TextColor3 = Color3.fromRGB(220, 220, 220)
overviewText.TextSize = 11
overviewText.Font = Enum.Font.Code
overviewText.TextXAlignment = Enum.TextXAlignment.Left
overviewText.TextYAlignment = Enum.TextYAlignment.Top
overviewText.LayoutOrder = 1
overviewText.Parent = panels["Overview"]
overviewText.Text = "Status: Scanning Containers..."

local behaviorText = Instance.new("TextLabel")
behaviorText.Size = UDim2.new(1, 0, 0, 250)
behaviorText.BackgroundTransparency = 1
behaviorText.TextColor3 = Color3.fromRGB(180, 255, 180)
behaviorText.TextSize = 10
behaviorText.Font = Enum.Font.Code
behaviorText.TextXAlignment = Enum.TextXAlignment.Left
behaviorText.TextYAlignment = Enum.TextYAlignment.Top
behaviorText.LayoutOrder = 1
behaviorText.Parent = panels["Behavior"]
behaviorText.Text = "Behavior Monitor Active...\nWaiting for runtime events..."

local exportStatusLabel = Instance.new("TextLabel")
exportStatusLabel.Size = UDim2.new(1, 0, 0, 50)
exportStatusLabel.BackgroundTransparency = 1
exportStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
exportStatusLabel.TextSize = 11
exportStatusLabel.Font = Enum.Font.Code
exportStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
exportStatusLabel.LayoutOrder = 1
exportStatusLabel.Text = "Export Path: workspace/AetheriusCore/ScanResult.json\nStatus: Pending First Export"
exportStatusLabel.Parent = panels["Data"]

local clearLogsBtn = Instance.new("TextButton")
clearLogsBtn.Size = UDim2.new(1, 0, 0, 32)
clearLogsBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 30)
clearLogsBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
clearLogsBtn.TextSize = 11
clearLogsBtn.Font = Enum.Font.GothamBold
clearLogsBtn.Text = "Clear Behavior Log History"
clearLogsBtn.LayoutOrder = 2
clearLogsBtn.Parent = panels["Data"]

panels["Data"].CanvasSize = UDim2.new(0, 0, 0, 100)

-- 3. EXPANDED SCANNING ENGINE (Workspace + ReplicatedStorage)
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

local eventHistory = {}
local maxHistorySize = 20

local function logBehaviorEvent(eventType, itemName, itemClass)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] %s: %s (%s)", timestamp, eventType, itemName, itemClass)
    table.insert(eventHistory, 1, entry)
    if #eventHistory > maxHistorySize then table.remove(eventHistory) end
    behaviorText.Text = table.concat(eventHistory, "\n")
end

clearLogsBtn.MouseButton1Click:Connect(function()
    table.clear(eventHistory)
    behaviorText.Text = "Behavior log history cleared."
end)

-- Background Scanning & Panel Population Task
task.spawn(function()
    local startTime = tick()
    local totalInstances = 0
    local remoteCount = 0
    local objectCount = 0

    local function processContainer(container)
        for _, descendant in ipairs(container:GetDescendants()) do
            totalInstances = totalInstances + 1
            if totalInstances % 200 == 0 then task.wait() end
            
            local category = classifyInstance(descendant)
            
            -- Populate Remotes Tab
            if category == "NetworkRemote" then
                remoteCount = remoteCount + 1
                local remoteLabel = Instance.new("TextLabel")
                remoteLabel.Size = UDim2.new(1, 0, 0, 22)
                remoteLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                remoteLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
                remoteLabel.TextSize = 10
                remoteLabel.Font = Enum.Font.Code
                remoteLabel.Text = string.format(" [%s] %s (%s)", descendant.ClassName, descendant.Name, descendant.Parent.Name)
                remoteLabel.TextXAlignment = Enum.TextXAlignment.Left
                remoteLabel.Parent = panels["Remotes"]
                panels["Remotes"].CanvasSize = UDim2.new(0, 0, 0, remoteCount * 26)
            end
            
            -- Populate Objects Tab (Filtering for major items to avoid UI clutter)
            if category == "Character/NPC" or category == "Tool" or descendant:IsA("Model") or descendant:IsA("Folder") then
                objectCount = objectCount + 1
                local objLabel = Instance.new("TextLabel")
                objLabel.Size = UDim2.new(1, 0, 0, 22)
                objLabel.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
                objLabel.TextColor3 = Color3.fromRGB(220, 220, 150)
                objLabel.TextSize = 10
                objLabel.Font = Enum.Font.Code
                objLabel.Text = string.format(" [%s] %s", descendant.ClassName, descendant.Name)
                objLabel.TextXAlignment = Enum.TextXAlignment.Left
                objLabel.Parent = panels["Objects"]
                panels["Objects"].CanvasSize = UDim2.new(0, 0, 0, objectCount * 26)
            end
        end
    end

    -- Scan both Workspace and ReplicatedStorage where game data actually lives!
    processContainer(Workspace)
    processContainer(ReplicatedStorage)

    local elapsedTime = tick() - startTime
    
    overviewText.Text = string.format([[
 Status: Scan Complete (%.2fs)
 Total Nodes Checked: %d
 Remotes Found: %d
 Key Objects Mapped: %d
 Environment: Delta Mobile]], elapsedTime, totalInstances, remoteCount, objectCount)

    -- Runtime Behavior Listeners
    Workspace.ChildAdded:Connect(function(child)
        logBehaviorEvent("SPAWN", child.Name, child.ClassName)
    end)
    Workspace.ChildRemoved:Connect(function(child)
        logBehaviorEvent("REMOVE", child.Name, child.ClassName)
    end)

    if writefile then
        if not isfolder("AetheriusCore") then makefolder("AetheriusCore") end
        writefile("AetheriusCore/ScanSummary.json", HttpService:JSONEncode({Remotes = remoteCount, Objects = objectCount}))
        exportStatusLabel.Text = "Export Path: workspace/AetheriusCore/ScanSummary.json\nStatus: Exported Successfully!"
    end
end)

print("[AetheriusCore]: Fixed inspector running successfully.")
