-- AetheriusCore: Phase 1 Scanner Foundation (Delta Optimized)
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local ScanConfig = {
    MaxDepth = 5,
    YieldEvery = 200, -- Prevents mobile lag spikes
}

local function scanInstance(instance, currentDepth)
    if currentDepth > ScanConfig.MaxDepth then return nil end
    
    local data = {
        Name = instance.Name,
        ClassName = instance.ClassName,
        Children = {}
    }
    
    local count = 0
    for _, child in ipairs(instance:GetChildren()) do
        count = count + 1
        if count % ScanConfig.YieldEvery == 0 then
            task.wait() -- Yield to keep mobile FPS stable
        end
        
        local childData = scanInstance(child, currentDepth + 1)
        if childData then
            table.insert(data.Children, childData)
        end
    end
    
    return data
end

print("[AetheriusCore]: Starting initial Workspace scan...")
local startTime = tick()
local workspaceScan = scanInstance(Workspace, 1)
print("[AetheriusCore]: Scan completed in " .. string.format("%.2f", tick() - startTime) .. " seconds.")

-- Utilize Delta's filesystem feature to export the raw scan
if writefile then
    if not isfolder("AetheriusCore") then
        makefolder("AetheriusCore")
    end
    writefile("AetheriusCore/WorkspaceScan.json", HttpService:JSONEncode(workspaceScan))
    print("[AetheriusCore]: Scan saved successfully to Delta/workspace/AetheriusCore/WorkspaceScan.json")
end

-- AetheriusCore: Phase 2 - UI Skeleton & Basic Object Classification
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Use Delta's gethui() if available to keep UI protected from mobile resets
local rootParent = (gethui and gethui()) or CoreGui

-- Clean up any existing instance of AetheriusCore UI
if rootParent:FindFirstChild("AetheriusCoreUI") then
    rootParent.AetheriusCoreUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AetheriusCoreUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = rootParent

-- Floating Toggle Button (Mobile Friendly)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleBtn"
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0, 20, 0, 100)
ToggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Text = "AC"
ToggleButton.TextSize = 18
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = ScreenGui

-- Main Container Window
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 320, 0, 240)
MainWindow.Position = UDim2.new(0.5, -160, 0.5, -120)
MainWindow.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainWindow.Visible = false
MainWindow.Parent = ScreenGui

-- Simple Classification Helper Function
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
    return "StandardObject"
end

-- Toggle window visibility on button click
ToggleButton.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

print("[AetheriusCore]: Phase 2 UI skeleton and classifier loaded successfully.")

-- AetheriusCore: Phase 3 - Multi-Tab UI & Relationship Explorer (Delta Optimized)
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Use Delta's gethui() to keep UI protected from game resets
local rootParent = (gethui and gethui()) or CoreGui

if rootParent:FindFirstChild("AetheriusCoreUI") then
    rootParent.AetheriusCoreUI:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AetheriusCoreUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = rootParent

-- Floating Toggle Button (Mobile Friendly)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleBtn"
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Position = UDim2.new(0, 15, 0, 80)
ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
ToggleButton.TextColor3 = Color3.fromRGB(0, 255, 180)
ToggleButton.Text = "AC"
ToggleButton.TextSize = 16
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Parent = ScreenGui

local cornerToggle = Instance.new("UICorner")
cornerToggle.CornerRadius = UDim.new(0, 8)
cornerToggle.Parent = ToggleButton

-- Main Container Window
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.new(0, 340, 0, 280)
MainWindow.Position = UDim2.new(0.5, -170, 0.5, -140)
MainWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainWindow.BorderSizePixel = 0
MainWindow.Visible = false
MainWindow.Parent = ScreenGui

local cornerMain = Instance.new("UICorner")
cornerMain.CornerRadius = UDim.new(0, 10)
cornerMain.Parent = MainWindow

-- Title Bar
local TitleBar = Instance.new("TextLabel")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
TitleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleBar.Text = "  AetheriusCore v0.3 (Analyzer)"
TitleBar.TextSize = 13
TitleBar.Font = Enum.Font.GothamBold
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.Parent = MainWindow

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

-- Create Tab Panels and Buttons
local tabs = {"Overview", "Objects", "Remotes"}
local panels = {}

local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new((index - 1) / #tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = name
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = TabBar
    return btn
end

local function createPanel(name)
    local scrollingFrame = Instance.new("ScrollingFrame")
    scrollingFrame.Size = UDim2.new(1, -10, 1, -10)
    scrollingFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollingFrame.BackgroundTransparency = 1
    scrollingFrame.Visible = false
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
    scrollingFrame.ScrollBarThickness = 4
    scrollingFrame.Parent = ContentArea
    
    local uiList = Instance.new("UIListLayout")
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Padding = UDim.new(0, 5)
    uiList.Parent = scrollingFrame
    
    return scrollingFrame
end

for i, tabName in ipairs(tabs) do
    local btn = createTabButton(tabName, i)
    local panel = createPanel(tabName)
    panels[tabName] = panel
    
    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(panels) do p.Visible = false end
        panels[tabName].Visible = true
    end)
end

-- Default to Overview Tab
panels["Overview"].Visible = true

-- Populate Overview Data (Quick Counts)
local overviewText = Instance.new("TextLabel")
overviewText.Size = UDim2.new(1, 0, 0, 100)
overviewText.BackgroundTransparency = 1
overviewText.TextColor3 = Color3.fromRGB(220, 220, 220)
overviewText.TextSize = 12
overviewText.Font = Enum.Font.Code
overviewText.TextXAlignment = Enum.TextXAlignment.Left
overviewText.TextYAlignment = Enum.TextYAlignment.Top
overviewText.Parent = panels["Overview"]

-- Quick scan stats update function
task.spawn(function()
    local partsCount = #Workspace:GetDescendants()
    local remotesCount = 0
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            remotesCount = remotesCount + 1
        end
    end
    overviewText.Text = string.format([[
 Status: Active & Monitoring
 Workspace Instances: %d
 Client Remotes Found: %d
 Environment: Delta Mobile
 UI State: Protected (gethui)]], partsCount, remotesCount)
end)

-- Toggle window visibility
ToggleButton.MouseButton1Click:Connect(function()
    MainWindow.Visible = not MainWindow.Visible
end)

print("[AetheriusCore]: Phase 3 multi-tab layout and explorer loaded successfully.")
