-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (v0.8 Advanced Update)
-- ==============================================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

print("[AetheriusCore]: Initializing Advanced Intelligence Suite...")

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
MainWindow.Size = UDim2.new(0, 380, 0, 340)
MainWindow.Position = UDim2.new(0.5, -190, 0.5, -170)
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
TitleBar.Text = "  AetheriusCore v0.8 (Advanced Analyzer)"
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

-- Tab Container Bar (6 Tabs: Overview, Objects, Remotes, Spy, Behavior, Data)
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

local tabs = {"Overview", "Objects", "Remotes", "Spy", "Behavior", "Data"}
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

-- Panel UI Setup
local overviewText = Instance.new("TextLabel")
overviewText.Size = UDim2.new(1, 0, 0, 150)
overviewText.BackgroundTransparency = 1
overviewText.TextColor3 = Color3.fromRGB(220, 220, 220)
overviewText.TextSize = 11
overviewText.Font = Enum.Font.Code
overviewText.TextXAlignment = Enum.TextXAlignment.Left
overviewText.TextYAlignment = Enum.TextYAlignment.Top
overviewText.LayoutOrder = 1
overviewText.Parent = panels["Overview"]
overviewText.Text = "Status: Scanning Containers & Values..."

local spyText = Instance.new("TextLabel")
spyText.Size = UDim2.new(1, 0, 0, 300)
spyText.BackgroundTransparency = 1
spyText.TextColor3 = Color3.fromRGB(255, 220, 150)
spyText.TextSize = 10
spyText.Font = Enum.Font.Code
spyText.TextXAlignment = Enum.TextXAlignment.Left
spyText.TextYAlignment = Enum.TextYAlignment.Top
spyText.LayoutOrder = 1
spyText.Parent = panels["Spy"]
spyText.Text = "Remote Spy Active...\nIntercepting client calls..."

local behaviorText = Instance.new("TextLabel")
behaviorText.Size = UDim2.new(1, 0, 0, 300)
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
exportStatusLabel.Text = "Export Path: workspace/AetheriusCore/AdvancedScan.json\nStatus: Pending First Export"
exportStatusLabel.Parent = panels["Data"]

local clearLogsBtn = Instance.new("TextButton")
clearLogsBtn.Size = UDim2.new(1, 0, 0, 32)
clearLogsBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 30)
clearLogsBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
clearLogsBtn.TextSize = 11
clearLogsBtn.Font = Enum.Font.GothamBold
clearLogsBtn.Text = "Clear Log History"
clearLogsBtn.LayoutOrder = 2
clearLogsBtn.Parent = panels["Data"]

panels["Data"].CanvasSize = UDim2.new(0, 0, 0, 100)

-- Helper function to generate clean path strings for clipboard copy
local function getFullPath(instance)
    local name = instance.Name
    local parent = instance.Parent
    if parent == Workspace then return 'game:GetService("Workspace").' .. name
    elseif parent == ReplicatedStorage then return 'game:GetService("ReplicatedStorage").' .. name
    else return instance:GetFullName() end
end

-- 3. ADVANCED SCANNING & EXTRACTION ENGINE
local function classifyInstance(instance)
    if instance:IsA("Model") and instance:FindFirstChild("Humanoid") then
        if instance == LocalPlayer.Character then return "LocalPlayer" else return "Character/NPC" end
    elseif instance:IsA("Tool") then return "Tool"
    elseif instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then return "NetworkRemote"
    elseif instance:IsA("ValueBase") then return "DataValue"
    end
    return instance.ClassName
end

local eventHistory = {}
local spyHistory = {}
local maxHistorySize = 15

local function logEvent(targetText, historyBuffer, entry)
    table.insert(historyBuffer, 1, entry)
    if #historyBuffer > maxHistorySize then table.remove(historyBuffer) end
    targetText.Text = table.concat(historyBuffer, "\n")
end

clearLogsBtn.MouseButton1Click:Connect(function()
    table.clear(eventHistory)
    table.clear(spyHistory)
    behaviorText.Text = "Behavior history cleared."
    spyText.Text = "Spy history cleared."
end)

-- Background Scanning & Inspector Task
task.spawn(function()
    local startTime = tick()
    local totalInstances = 0
    local remoteCount = 0
    local objectCount = 0
    local valueCount = 0

    local function processContainer(container)
        for _, descendant in ipairs(container:GetDescendants()) do
            totalInstances = totalInstances + 1
            if totalInstances % 200 == 0 then task.wait() end
            
            local category = classifyInstance(descendant)
            
            -- Remotes Tab + Hook Spy Interceptor
            if category == "NetworkRemote" then
                remoteCount = remoteCount + 1
                
                -- Tap-to-Copy Remote Button
                local remoteBtn = Instance.new("TextButton")
                remoteBtn.Size = UDim2.new(1, 0, 0, 24)
                remoteBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
                remoteBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
                remoteBtn.TextSize = 10
                remoteBtn.Font = Enum.Font.Code
                remoteBtn.Text = string.format(" [%s] %s (Tap to Copy)", descendant.ClassName, descendant.Name)
                remoteBtn.TextXAlignment = Enum.TextXAlignment.Left
                remoteBtn.Parent = panels["Remotes"]
                panels["Remotes"].CanvasSize = UDim2.new(0, 0, 0, remoteCount * 28)
                
                remoteBtn.MouseButton1Click:Connect(function()
                    if setclipboard then
                        setclipboard(getFullPath(descendant))
                        remoteBtn.Text = " Copied Path to Clipboard!"
                        task.wait(1)
                        remoteBtn.Text = string.format(" [%s] %s (Tap to Copy)", descendant.ClassName, descendant.Name)
                    end
                end)

                -- Phase 8 Extra: Hook NameCall / FireServer/InvokeServer logging
                if descendant:IsA("RemoteEvent") then
                    local originalFire
                    originalFire = hookfunction(descendant.FireServer, function(self, ...)
                        if self == descendant then
                            local args = {...}
                            logEvent(spyText, spyHistory, string.format("[Fire] %s | Args: %s", descendant.Name, table.concat({tostringall(...)}, ", ")))
                        end
                        return originalFire(self, ...)
                    end)
                end

            -- Objects Tab (Models, Tools, Values)
            elseif category == "Character/NPC" or category == "Tool" or category == "DataValue" then
                objectCount = objectCount + 1
                if category == "DataValue" then valueCount = valueCount + 1 end
                
                local objBtn = Instance.new("TextButton")
                objBtn.Size = UDim2.new(1, 0, 0, 24)
                objBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
                objBtn.TextColor3 = category == "DataValue" and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(220, 220, 150)
                objBtn.TextSize = 10
                objBtn.Font = Enum.Font.Code
                local displayVal = (category == "DataValue") and tostring(descendant.Value) or descendant.Name
                objBtn.Text = string.format(" [%s] %s = %s", descendant.ClassName, descendant.Name, displayVal)
                objBtn.TextXAlignment = Enum.TextXAlignment.Left
                objBtn.Parent = panels["Objects"]
                panels["Objects"].CanvasSize = UDim2.new(0, 0, 0, objectCount * 28)
                
                objBtn.MouseButton1Click:Connect(function()
                    if setclipboard then
                        setclipboard(getFullPath(descendant))
                        objBtn.Text = " Copied Path!"
                        task.wait(1)
                        objBtn.Text = string.format(" [%s] %s = %s", descendant.ClassName, descendant.Name, displayVal)
                    end
                end)
            end
        end
    end

    processContainer(Workspace)
    processContainer(ReplicatedStorage)

    local elapsedTime = tick() - startTime
    
    overviewText.Text = string.format([[
 Status: Scan Complete (%.2fs)
 Total Nodes Checked: %d
 Remotes Mapped: %d
 ValueBases/Configs: %d
 Key Objects Mapped: %d]], elapsedTime, totalInstances, remoteCount, valueCount, objectCount)

    -- Runtime Behavior Listeners
    Workspace.ChildAdded:Connect(function(child)
        logEvent(behaviorText, eventHistory, string.format("[%s] SPAWN: %s", os.date("%H:%M:%S"), child.Name))
    end)
    Workspace.ChildRemoved:Connect(function(child)
        logEvent(behaviorText, eventHistory, string.format("[%s] REMOVE: %s", os.date("%H:%M:%S"), child.Name))
    end)

    if writefile then
        if not isfolder("AetheriusCore") then makefolder("AetheriusCore") end
        writefile("AetheriusCore/AdvancedScan.json", HttpService:JSONEncode({Remotes = remoteCount, Values = valueCount}))
        exportStatusLabel.Text = "Export Path: workspace/AetheriusCore/AdvancedScan.json\nStatus: Exported Successfully!"
    end
end)

print("[AetheriusCore]: Advanced intelligence suite running smoothly.")
