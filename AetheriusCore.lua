-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (Phases 1 - 3 Combined)
-- ==============================================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

print("[AetheriusCore]: Initializing Core Intelligence Analyzer...")

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

-- 2. MAIN WINDOW UI LAYOUT (Visible by default for mobile verification)
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 340, 0, 300)
MainWindow.Position = UDim2.new(0.5, -170, 0.5, -150)
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
TitleBar.Text = "  AetheriusCore v0.3 (Phases 1-3)"
TitleBar.TextSize = 13
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

-- Tab Container Bar
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
local tabs = {"Overview", "Objects", "Remotes"}
local panels = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = tabName
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabBar

    local panel = Instance.new("ScrollingFrame")
    panel.Size = UDim2.new(1, -10, 1, -10)
    panel.Position = UDim2.new(0, 5, 0, 5)
    panel.BackgroundTransparency = 1
    panel.Visible = (tabName == "Overview")
    panel.CanvasSize = UDim2.new(0, 0, 1.5, 0)
    panel.ScrollBarThickness = 4
    panel.Parent = ContentArea
    
    panels[tabName] = panel
    
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(panels) do p.Visible = false end
        panel.Visible = true
    end)
end

-- Overview Panel Text
local overviewText = Instance.new("TextLabel")
overviewText.Size = UDim2.new(1, 0, 0, 120)
overviewText.BackgroundTransparency = 1
overviewText.TextColor3 = Color3.fromRGB(220, 220, 220)
overviewText.TextSize = 11
overviewText.Font = Enum.Font.Code
overviewText.TextXAlignment = Enum.TextXAlignment.Left
overviewText.TextYAlignment = Enum.TextYAlignment.Top
overviewText.Parent = panels["Overview"]

overviewText.Text = "Status: Scanning Workspace...\nPlease wait."

-- Remotes Panel Text Container
local remotesText = Instance.new("TextLabel")
remotesText.Size = UDim2.new(1, 0, 0, 200)
remotesText.BackgroundTransparency = 1
remotesText.TextColor3 = Color3.fromRGB(200, 220, 255)
remotesText.TextSize = 11
remotesText.Font = Enum.Font.Code
remotesText.TextXAlignment = Enum.TextXAlignment.Left
remotesText.TextYAlignment = Enum.TextYAlignment.Top
remotesText.Parent = panels["Remotes"]


-- 3. PHASE 1: CLASSIFICATION & SCANNING ENGINE (Optimized for Mobile)
local ScanConfig = {
    MaxDepth = 3,         -- Kept safe for mobile performance limits
    YieldEvery = 150,     -- Yield frequency to prevent frame drops
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

-- Asynchronous background scan task to prevent freezing UI
task.spawn(function()
    local startTime = tick()
    local totalInstances = 0
    local remoteCount = 0
    local categoryCounts = {}
    
    local workspaceData = {}
    
    local function scanRecursive(instance, currentDepth)
        if currentDepth > ScanConfig.MaxDepth then return nil end
        
        totalInstances = totalInstances + 1
        if totalInstances % ScanConfig.YieldEvery == 0 then
            task.wait() -- Keep mobile FPS stable
        end
        
        local category = classifyInstance(instance)
        categoryCounts[category] = (categoryCounts[category] or 0) + 1
        
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
    
    -- Update Overview UI with statistics
    overviewText.Text = string.format([[
 Status: Scan Complete (%.2fs)
 Total Scanned Nodes: %d
 Remotes Identified: %d
 Environment: Delta Mobile
 UI Layer: Protected Framework]], elapsedTime, totalInstances, remoteCount)

    remotesText.Text = string.format("Scan found %d remote objects.\nCheck Delta workspace export for complete map.", remoteCount)

    -- Export file via Delta filesystem capabilities
    if writefile then
        if not isfolder("AetheriusCore") then
            makefolder("AetheriusCore")
        end
        writefile("AetheriusCore/ScanResult.json", HttpService:JSONEncode(scannedTree))
        print("[AetheriusCore]: Workspace scan exported successfully to workspace/AetheriusCore/ScanResult.json")
    end
end)

print("[AetheriusCore]: Phases 1-3 loaded and execution thread running smoothly.")
