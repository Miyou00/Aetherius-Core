-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (v0.11.9 Analysis Reliability and Error Recovery)
-- Passive inspection/logging for development and testing in experiences you own.
-- Executor APIs are optional and executor-specific. Remote calls are never
-- modified, blocked, replayed, or supplied with altered arguments.
-- ==============================================================================

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local SCRIPT_VERSION = "0.11.9"
local GUI_NAME = "AetheriusCoreUI"
local MAX_HISTORY = 30
local MAX_EXPLORER_ROWS = 250
local MAX_RELATIONSHIPS = 5000
local ANALYSIS_BATCH_SIZE = 50
local SCAN_BATCH_SIZE = 100
local SCAN_YIELD_SECONDS = 0.02

-- Stop a previous UI instance and invalidate its worker before creating another.
local env = (type(getgenv) == "function" and getgenv()) or _G
if env.AetheriusCoreState then
    local previous = env.AetheriusCoreState
    previous.alive = false
    if previous.connections then
        for _, connection in ipairs(previous.connections) do
            pcall(function() connection:Disconnect() end)
        end
    end
    if previous.gui then pcall(function() previous.gui:Destroy() end) end
end

local State = {
    alive = true,
    connections = {},
    gui = nil,
    scanGeneration = 0,
    runtimePaused = false,
    runtimeHistory = {},
    hookInstalled = false,
    analysisRecords = {},
    relationshipEdges = {},
    scanComplete = false,
    scanErrors = 0,
}
env.AetheriusCoreState = State

local function track(connection)
    table.insert(State.connections, connection)
    return connection
end

local function safeDisconnectAll()
    for _, connection in ipairs(State.connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(State.connections)
end

-- Consistent, lightweight hover/press feedback for interactive controls.
local function styleButton(button, getBaseColor, hoverColor, pressedColor)
    button.AutoButtonColor = false
    button.Selectable = true
    local function setColor(color)
        if button and button.Parent and color then
            button.BackgroundColor3 = color
        end
    end
    button.MouseEnter:Connect(function()
        setColor(hoverColor)
    end)
    button.MouseLeave:Connect(function()
        setColor(getBaseColor())
    end)
    button.MouseButton1Down:Connect(function()
        setColor(pressedColor or hoverColor)
    end)
    button.MouseButton1Up:Connect(function()
        setColor(hoverColor)
    end)
end

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return false, "API unavailable" end
    return pcall(fn, ...)
end

-- Executor-specific UI parent selection.
local rootParent = CoreGui
if type(syn) == "table" and type(syn.protect_gui) == "function" then
    pcall(function() syn.protect_gui(rootParent) end)
elseif type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then rootParent = result end
end

pcall(function()
    local existing = rootParent:FindFirstChild(GUI_NAME)
    if existing then existing:Destroy() end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 10000
ScreenGui.Parent = rootParent
State.gui = ScreenGui

local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.Size = UDim2.fromOffset(345, 293)
MainWindow.Position = UDim2.new(0.5, -172, 0.5, -146)
MainWindow.BackgroundColor3 = Color3.fromRGB(18, 20, 27)
MainWindow.BorderSizePixel = 0
MainWindow.Parent = ScreenGui
Instance.new("UICorner", MainWindow).CornerRadius = UDim.new(0, 9)
local windowStroke = Instance.new("UIStroke")
windowStroke.Color = Color3.fromRGB(55, 59, 73)
windowStroke.Thickness = 1
windowStroke.Transparency = 0.15
windowStroke.Parent = MainWindow

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = Color3.fromRGB(27, 30, 40)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainWindow
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 9)
local headerAccent = Instance.new("Frame")
headerAccent.Size = UDim2.new(1, -20, 0, 1)
headerAccent.Position = UDim2.new(0, 10, 1, -2)
headerAccent.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
headerAccent.BorderSizePixel = 0
headerAccent.Parent = TitleBar
Instance.new("UICorner", headerAccent).CornerRadius = UDim.new(1, 0)

-- Compact live status strip, matching the supplied reference layout.
local StatusHeader = Instance.new("Frame")
StatusHeader.Name = "StatusHeader"
StatusHeader.Size = UDim2.new(1, -16, 0, 27)
StatusHeader.Position = UDim2.fromOffset(8, 36)
StatusHeader.BackgroundColor3 = Color3.fromRGB(32, 35, 46)
StatusHeader.BorderSizePixel = 0
StatusHeader.Parent = MainWindow
Instance.new("UICorner", StatusHeader).CornerRadius = UDim.new(0, 6)

local StatusText = Instance.new("TextLabel")
StatusText.Name = "OverallStatus"
StatusText.Size = UDim2.new(1, -38, 1, 0)
StatusText.Position = UDim2.fromOffset(9, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "● STARTING"
StatusText.TextColor3 = Color3.fromRGB(70, 205, 125)
StatusText.TextSize = 9
StatusText.Font = Enum.Font.GothamBold
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.TextTruncate = Enum.TextTruncate.AtEnd
StatusText.Parent = StatusHeader

local StatusExpand = Instance.new("TextButton")
StatusExpand.Name = "StatusExpand"
StatusExpand.Size = UDim2.fromOffset(20, 20)
StatusExpand.Position = UDim2.new(1, -26, 0.5, -10)
StatusExpand.BackgroundTransparency = 0
StatusExpand.BackgroundColor3 = Color3.fromRGB(43, 46, 58)
StatusExpand.Text = "▼"
StatusExpand.TextColor3 = Color3.fromRGB(155, 162, 178)
StatusExpand.TextSize = 9
StatusExpand.Font = Enum.Font.GothamBold
StatusExpand.Parent = StatusHeader
Instance.new("UICorner", StatusExpand).CornerRadius = UDim.new(0, 5)
styleButton(StatusExpand, function() return Color3.fromRGB(43, 46, 58) end, Color3.fromRGB(58, 64, 82), Color3.fromRGB(38, 43, 57))

local StatusDetails = Instance.new("Frame")
StatusDetails.Name = "StatusDetails"
StatusDetails.Size = UDim2.new(1, -16, 0, 58)
StatusDetails.Position = UDim2.fromOffset(8, 66)
StatusDetails.BackgroundColor3 = Color3.fromRGB(32, 35, 46)
StatusDetails.BorderSizePixel = 0
StatusDetails.ClipsDescendants = true
StatusDetails.Visible = false
StatusDetails.Parent = MainWindow
Instance.new("UICorner", StatusDetails).CornerRadius = UDim.new(0, 6)

local StatusDetailText = Instance.new("TextLabel")
StatusDetailText.Name = "StatusDetailText"
StatusDetailText.Size = UDim2.new(1, -18, 1, -8)
StatusDetailText.Position = UDim2.fromOffset(9, 4)
StatusDetailText.BackgroundTransparency = 1
StatusDetailText.Text = "Scan scope: Workspace + ReplicatedStorage\nRemote observer: Initializing\nLive updates: Enabled"
StatusDetailText.TextColor3 = Color3.fromRGB(155, 162, 178)
StatusDetailText.TextSize = 9
StatusDetailText.Font = Enum.Font.GothamMedium
StatusDetailText.TextXAlignment = Enum.TextXAlignment.Left
StatusDetailText.TextYAlignment = Enum.TextYAlignment.Center
StatusDetailText.Parent = StatusDetails

local statusDetailsExpanded = false

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -70, 1, 0)
Title.Position = UDim2.fromOffset(12, 0)
Title.BackgroundTransparency = 1
Title.Text = "AetheriusCore v" .. SCRIPT_VERSION .. "  [Starting]"
Title.TextColor3 = Color3.fromRGB(235, 238, 245)
Title.TextSize = 10
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local function makeTitleButton(text, xOffset, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(28, 30)
    button.Position = UDim2.new(1, xOffset, 0, 0)
    button.BackgroundTransparency = 1
    button.Text = text
    button.TextColor3 = color
    button.TextSize = 13
    button.Font = Enum.Font.GothamBold
    button.ZIndex = 3
    button.Parent = TitleBar
    return button
end

local MinimizeBtn = makeTitleButton("−", -54, Color3.fromRGB(230, 205, 120))
MinimizeBtn.Size = UDim2.fromOffset(20, 20)
MinimizeBtn.Position = UDim2.new(1, -55, 0, 6)
MinimizeBtn.BackgroundTransparency = 0
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(43, 44, 48)
MinimizeBtn.AutoButtonColor = false
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)
styleButton(MinimizeBtn, function() return Color3.fromRGB(43, 44, 48) end, Color3.fromRGB(65, 67, 75), Color3.fromRGB(34, 36, 42))

local CloseBtn = makeTitleButton("×", -25, Color3.fromRGB(235, 115, 115))
CloseBtn.Size = UDim2.fromOffset(24, 24)
CloseBtn.Position = UDim2.new(1, -29, 0, 4)
CloseBtn.BackgroundTransparency = 0
CloseBtn.BackgroundColor3 = Color3.fromRGB(53, 37, 43)
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 5)
styleButton(CloseBtn, function() return Color3.fromRGB(53, 37, 43) end, Color3.fromRGB(100, 48, 57), Color3.fromRGB(72, 35, 43))

local TabBar = Instance.new("Frame")
TabBar.Position = UDim2.fromOffset(8, 65)
TabBar.Size = UDim2.new(1, -16, 0, 22)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.Parent = MainWindow

local ContentArea = Instance.new("Frame")
ContentArea.Position = UDim2.fromOffset(8, 91)
ContentArea.Size = UDim2.new(1, -16, 1, -100)
ContentArea.BackgroundColor3 = Color3.fromRGB(27, 30, 40)
ContentArea.BorderSizePixel = 0
ContentArea.Parent = MainWindow
Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 6)

StatusExpand.MouseButton1Click:Connect(function()
    statusDetailsExpanded = not statusDetailsExpanded
    StatusDetails.Visible = statusDetailsExpanded
    StatusExpand.Text = statusDetailsExpanded and "▲" or "▼"
    TabBar.Position = UDim2.fromOffset(8, statusDetailsExpanded and 128 or 65)
    ContentArea.Position = UDim2.fromOffset(8, statusDetailsExpanded and 154 or 91)
    ContentArea.Size = UDim2.new(1, -16, 1, statusDetailsExpanded and -163 or -100)
end)

local tabs = {"Overview", "Explorer", "Runtime", "Data"}
local panels, tabButtons, tabIndicators = {}, {}, {}
local activeTab = "Overview"

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabs, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(32, 35, 46)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.TextColor3 = Color3.fromRGB(155, 162, 178)
    btn.Text = tabName
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    tabButtons[tabName] = btn
    styleButton(btn, function()
        return tabName == activeTab and Color3.fromRGB(38, 42, 54) or Color3.fromRGB(32, 35, 46)
    end, Color3.fromRGB(47, 53, 69), Color3.fromRGB(34, 39, 52))

    local indicator = Instance.new("Frame")
    indicator.Name = "ActiveIndicator"
    indicator.AnchorPoint = Vector2.new(0.5, 1)
    indicator.Position = UDim2.new(0.5, 0, 1, 0)
    indicator.Size = UDim2.new(0.58, 0, 0, 2)
    indicator.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
    indicator.BorderSizePixel = 0
    indicator.Visible = tabName == activeTab
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)
    tabIndicators[tabName] = indicator

    local panel = Instance.new("ScrollingFrame")
    panel.Name = tabName .. "Panel"
    panel.Size = UDim2.new(1, -12, 1, -12)
    panel.Position = UDim2.fromOffset(6, 6)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel = 0
    panel.ScrollBarThickness = 4
    panel.CanvasSize = UDim2.new()
    panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    panel.ScrollBarImageColor3 = Color3.fromRGB(55, 59, 73)
    panel.Visible = tabName == activeTab
    panel.Parent = ContentArea
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    -- Overview uses fixed-position metric tiles; other tabs use vertical lists.
    if tabName ~= "Overview" then
        layout.Parent = panel
    end
    panels[tabName] = panel
    if tabName == activeTab then
        btn.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
        btn.TextColor3 = Color3.fromRGB(242, 246, 255)
    end

    track(btn.MouseButton1Click:Connect(function()
        if not State.alive then return end
        activeTab = tabName
        for name, p in pairs(panels) do
            p.Visible = name == activeTab
            tabButtons[name].BackgroundColor3 = name == activeTab
                and Color3.fromRGB(38, 42, 54) or Color3.fromRGB(32, 35, 46)
            tabButtons[name].TextColor3 = name == activeTab
                and Color3.fromRGB(242, 246, 255) or Color3.fromRGB(155, 162, 178)
            tabIndicators[name].Visible = name == activeTab
        end
    end))
end

local function makeLabel(parent, text, height, size, color)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -8, 0, height)
    label.BackgroundColor3 = Color3.fromRGB(32, 35, 46)
    label.BackgroundTransparency = 0
    label.TextColor3 = color or Color3.fromRGB(220, 224, 233)
    label.TextSize = size or 10
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = true
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 7)
    local labelPadding = Instance.new("UIPadding")
    labelPadding.PaddingLeft = UDim.new(0, 9)
    labelPadding.PaddingTop = UDim.new(0, 6)
    labelPadding.PaddingRight = UDim.new(0, 7)
    labelPadding.Parent = label
    -- Keep a subtle inset border on information cards.
    local labelStroke = Instance.new("UIStroke")
    labelStroke.Color = Color3.fromRGB(55, 59, 73)
    labelStroke.Transparency = 0.45
    labelStroke.Thickness = 1
    labelStroke.Parent = label
    label.Text = text
    label.Parent = parent
    return label
end

-- Overview uses the reference layout: heading, hint, and compact stat tiles.
local overviewPanel = panels.Overview
local overviewTitle = Instance.new("TextLabel")
overviewTitle.Name = "OverviewTitle"
overviewTitle.Size = UDim2.new(1, 0, 0, 24)
overviewTitle.BackgroundTransparency = 1
overviewTitle.Text = "Scan Overview"
overviewTitle.TextColor3 = Color3.fromRGB(240, 243, 250)
overviewTitle.TextSize = 13
overviewTitle.Font = Enum.Font.GothamBold
overviewTitle.TextXAlignment = Enum.TextXAlignment.Left
overviewTitle.Parent = overviewPanel

local overviewHint = Instance.new("TextLabel")
overviewHint.Name = "OverviewHint"
overviewHint.Position = UDim2.fromOffset(0, 24)
overviewHint.Size = UDim2.new(1, 0, 0, 20)
overviewHint.BackgroundTransparency = 1
overviewHint.Text = "Client-visible data collected during the scan."
overviewHint.TextColor3 = Color3.fromRGB(155, 162, 178)
overviewHint.TextSize = 10
overviewHint.Font = Enum.Font.GothamMedium
overviewHint.TextXAlignment = Enum.TextXAlignment.Left
overviewHint.Parent = overviewPanel

local statContainer = Instance.new("Frame")
statContainer.Name = "StatContainer"
statContainer.Position = UDim2.fromOffset(0, 50)
statContainer.Size = UDim2.new(1, 0, 0, 117)
statContainer.BackgroundTransparency = 1
statContainer.Parent = overviewPanel

local statLayout = Instance.new("UIGridLayout")
statLayout.CellSize = UDim2.new(0.5, -4, 0, 35)
statLayout.CellPadding = UDim2.fromOffset(8, 6)
statLayout.SortOrder = Enum.SortOrder.LayoutOrder
statLayout.Parent = statContainer

local overviewStatLabels = {}
local function createOverviewStat(name, order)
    local tile = Instance.new("Frame")
    tile.Name = name:gsub("%s+", "") .. "Stat"
    tile.BackgroundColor3 = Color3.fromRGB(32, 35, 46)
    tile.BorderSizePixel = 0
    tile.LayoutOrder = order
    tile.Parent = statContainer
    Instance.new("UICorner", tile).CornerRadius = UDim.new(0, 5)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 0, 13)
    label.Position = UDim2.fromOffset(8, 2)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(155, 162, 178)
    label.TextSize = 9
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = tile

    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(1, -16, 0, 17)
    value.Position = UDim2.fromOffset(8, 15)
    value.BackgroundTransparency = 1
    value.Text = "0"
    value.TextColor3 = Color3.fromRGB(240, 243, 250)
    value.TextSize = 12
    value.Font = Enum.Font.GothamBold
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.Parent = tile
    overviewStatLabels[name] = value
end

createOverviewStat("Objects", 1)
createOverviewStat("Remotes", 2)
createOverviewStat("Values", 3)
createOverviewStat("Tools", 4)
createOverviewStat("Humanoid Models", 5)

local explorerPanel = panels.Explorer
local runtimePanel = panels.Runtime
local dataPanel = panels.Data

local runtimePaused = false
local runtimeTextRows = {}
local pauseBtn = Instance.new("TextButton")
pauseBtn.Size = UDim2.new(1, -8, 0, 31)
pauseBtn.BackgroundColor3 = Color3.fromRGB(38, 42, 54)
pauseBtn.TextColor3 = Color3.fromRGB(255, 210, 125)
pauseBtn.Text = "Pause Log Stream"
pauseBtn.TextSize = 11
pauseBtn.Font = Enum.Font.GothamBold
pauseBtn.LayoutOrder = 0
pauseBtn.Parent = runtimePanel
pauseBtn.AutoButtonColor = false
Instance.new("UICorner", pauseBtn).CornerRadius = UDim.new(0, 7)
styleButton(pauseBtn, function() return Color3.fromRGB(38, 42, 54) end, Color3.fromRGB(49, 55, 71), Color3.fromRGB(31, 35, 46))
local pauseStroke = Instance.new("UIStroke")
pauseStroke.Color = Color3.fromRGB(55, 59, 73)
pauseStroke.Transparency = 0.35
pauseStroke.Parent = pauseBtn

local function renderRuntime()
    for _, row in ipairs(runtimeTextRows) do
        pcall(function() row:Destroy() end)
    end
    table.clear(runtimeTextRows)
    for i, entry in ipairs(State.runtimeHistory) do
        local row = makeLabel(runtimePanel, entry, 25, 8, Color3.fromRGB(245, 220, 155))
        row.LayoutOrder = i
        table.insert(runtimeTextRows, row)
    end
end

local function logRuntime(message)
    if not State.alive or State.runtimePaused then return end
    table.insert(State.runtimeHistory, 1, string.format("[%s] %s", os.date("%H:%M:%S"), tostring(message)))
    while #State.runtimeHistory > MAX_HISTORY do
        table.remove(State.runtimeHistory)
    end
    if runtimePanel.Visible then renderRuntime() end
end

track(pauseBtn.MouseButton1Click:Connect(function()
    State.runtimePaused = not State.runtimePaused
    pauseBtn.Text = State.runtimePaused and "Resume Log Stream" or "Pause Log Stream"
    pauseBtn.TextColor3 = State.runtimePaused
        and Color3.fromRGB(255, 145, 145) or Color3.fromRGB(255, 210, 125)
end))

local dataText = makeLabel(dataPanel, "Scan data will appear here.", 75, 9)
local exportText = makeLabel(dataPanel, "Export: waiting", 35, 9, Color3.fromRGB(180, 205, 220))
local rescanBtn = Instance.new("TextButton")
rescanBtn.Size = UDim2.new(1, -8, 0, 31)
rescanBtn.BackgroundColor3 = Color3.fromRGB(52, 103, 210)
rescanBtn.TextColor3 = Color3.fromRGB(235, 240, 250)
rescanBtn.Text = "Rescan"
rescanBtn.TextSize = 11
rescanBtn.Font = Enum.Font.GothamBold
rescanBtn.Parent = dataPanel
rescanBtn.AutoButtonColor = false
Instance.new("UICorner", rescanBtn).CornerRadius = UDim.new(0, 7)
styleButton(rescanBtn, function() return Color3.fromRGB(52, 103, 210) end, Color3.fromRGB(67, 123, 235), Color3.fromRGB(40, 83, 174))
local rescanStroke = Instance.new("UIStroke")
rescanStroke.Color = Color3.fromRGB(70, 130, 255)
rescanStroke.Transparency = 0.35
rescanStroke.Parent = rescanBtn

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(1, -8, 0, 31)
clearBtn.BackgroundColor3 = Color3.fromRGB(65, 39, 45)
clearBtn.TextColor3 = Color3.fromRGB(255, 165, 165)
clearBtn.Text = "Clear Runtime History"
clearBtn.TextSize = 11
clearBtn.Font = Enum.Font.GothamBold
clearBtn.Parent = dataPanel
clearBtn.AutoButtonColor = false
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 7)
styleButton(clearBtn, function() return Color3.fromRGB(65, 39, 45) end, Color3.fromRGB(91, 48, 57), Color3.fromRGB(51, 31, 37))
local clearStroke = Instance.new("UIStroke")
clearStroke.Color = Color3.fromRGB(117, 66, 75)
clearStroke.Transparency = 0.4
clearStroke.Parent = clearBtn

track(clearBtn.MouseButton1Click:Connect(function()
    table.clear(State.runtimeHistory)
    renderRuntime()
end))

local stats = {nodes = 0, remotes = 0, values = 0, tools = 0, models = 0}
local explorerRows = {}
local seenInstances = setmetatable({}, {__mode = "k"})
local entryByInstance = setmetatable({}, {__mode = "k"})
local instanceByRecord = setmetatable({}, {__mode = "k"})
local rowByInstance = setmetatable({}, {__mode = "k"})
local humanoidModelCounted = setmetatable({}, {__mode = "k"})
local nameChangeConnections = setmetatable({}, {__mode = "k"})
local valueChangeConnections = setmetatable({}, {__mode = "k"})
local ancestorNameConnections = setmetatable({}, {__mode = "k"})
local refreshTrackedPaths
local scheduleRelationshipRefresh
local queueLiveUiRefresh
local scanStarted = 0

local function clearExplorer()
    for _, row in ipairs(explorerRows) do
        pcall(function() row:Destroy() end)
    end
    table.clear(explorerRows)
    table.clear(rowByInstance)
end

local function fullPath(instance)
    local ok, result = pcall(function() return instance:GetFullName() end)
    return ok and result or instance.Name
end

local function isRelevant(instance)
    return instance:IsA("RemoteEvent")
        or instance:IsA("RemoteFunction")
        or instance:IsA("ValueBase")
        or instance:IsA("Tool")
        or (instance:IsA("Model") and instance:FindFirstChildWhichIsA("Humanoid", true) ~= nil)
end

local function addExplorerRow(instance, order, category)
    if #explorerRows >= MAX_EXPLORER_ROWS then return end
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -8, 0, 27)
    row.BackgroundColor3 = Color3.fromRGB(32, 35, 46)
    row.BorderSizePixel = 0
    local isRemote = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction")
    row.TextColor3 = isRemote and Color3.fromRGB(150, 195, 255)
        or Color3.fromRGB(215, 220, 230)
    row.TextSize = 9
    row.Font = Enum.Font.Code
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextTruncate = Enum.TextTruncate.AtEnd
    local record = entryByInstance[instance]
    local relevanceText = record and string.format(" R:%d", record.RelevanceScore or 0) or ""
    local info = string.format("  [%s%s] %s", category or instance.ClassName, relevanceText, fullPath(instance))
    if instance:IsA("ValueBase") then
        info ..= " = " .. tostring(instance.Value)
    end
    row.Text = info
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = Color3.fromRGB(55, 59, 73)
    rowStroke.Transparency = 0.55
    rowStroke.Thickness = 1
    rowStroke.Parent = row
    row.LayoutOrder = order
    row.Parent = explorerPanel
    styleButton(row, function() return Color3.fromRGB(32, 35, 46) end,
        Color3.fromRGB(43, 49, 64), Color3.fromRGB(36, 42, 56))
    table.insert(explorerRows, row)
    rowByInstance[instance] = row
    track(row.MouseButton1Click:Connect(function()
        if not State.alive then return end
        if type(setclipboard) == "function" then
            local ok = pcall(setclipboard, fullPath(instance))
            if ok then
                row.Text = "  Copied path: " .. instance.Name
                task.delay(1, function()
                    if State.alive and row.Parent then row.Text = info end
                end)
            else
                row.Text = "  Clipboard unavailable"
            end
        else
            row.Text = "  " .. fullPath(instance)
        end
    end))
end

-- Classify only relevant instances to keep analysis overhead bounded.
-- This is descriptive metadata from client-visible instances, not a claim
-- about server-side behavior or intent.
local function classifyRelevant(instance)
    if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
        return "Remote"
    elseif instance:IsA("ValueBase") then
        return "Value"
    elseif instance:IsA("Tool") then
        return "Tool"
    elseif instance:IsA("Model") then
        return "Humanoid Model"
    end
    return "Other"
end

local function familyName(instance)
    local cursor = instance
    local rootName = instance.Name
    while cursor and cursor ~= Workspace and cursor ~= ReplicatedStorage do
        rootName = cursor.Name
        cursor = cursor.Parent
    end
    return rootName
end

-- Refresh paths only when a tracked name/ancestor changes; normal scans do not
-- repeatedly walk every record. One listener is shared per ancestor instance.
refreshTrackedPaths = function()
    if not State.alive then return end
    for instance, record in pairs(entryByInstance) do
        if instance and record then
            record.Name = instance.Name
            record.Path = fullPath(instance)
            record.Family = familyName(instance)
            record.ParentPath = instance.Parent and fullPath(instance.Parent) or ""
            local row = rowByInstance[instance]
            if row and row.Parent then
                local relevanceText = string.format(" R:%d", record.RelevanceScore or 0)
                local valueText = instance:IsA("ValueBase") and (" = " .. tostring(instance.Value)) or ""
                row.Text = string.format("  [%s%s] %s%s", record.Category or instance.ClassName, relevanceText, record.Path, valueText)
            end
        end
    end
    if State.scanComplete and scheduleRelationshipRefresh then scheduleRelationshipRefresh() end
    queueLiveUiRefresh()
end

local function registerAncestorNameWatch(instance)
    local cursor = instance.Parent
    while cursor and cursor ~= Workspace and cursor ~= ReplicatedStorage do
        if not ancestorNameConnections[cursor] then
            local ancestor = cursor
            local ok, connection = pcall(function()
                return ancestor:GetPropertyChangedSignal("Name"):Connect(function()
                    refreshTrackedPaths()
                end)
            end)
            if ok and connection then ancestorNameConnections[ancestor] = connection end
        end
        cursor = cursor.Parent
    end
end

local function inScanScope(instance)
    local ok, result = pcall(function()
        return instance:IsDescendantOf(Workspace) or instance:IsDescendantOf(ReplicatedStorage)
    end)
    return ok and result
end

local function removeExplorerEntry(instance)
    local row = rowByInstance[instance]
    if row then
        pcall(function() row:Destroy() end)
        rowByInstance[instance] = nil
        for i = #explorerRows, 1, -1 do
            if explorerRows[i] == row then
                table.remove(explorerRows, i)
                break
            end
        end
    end

    local entry = entryByInstance[instance]
    if entry then
        for i = #State.scanEntries, 1, -1 do
            if State.scanEntries[i] == entry then
                table.remove(State.scanEntries, i)
                break
            end
        end
        entryByInstance[instance] = nil
    end
    if entry then instanceByRecord[entry] = nil end
    State.analysisRecords[instance] = nil
end

-- Relevance is a transparent, rule-based priority for review, not a prediction
-- of gameplay importance. Scores are intentionally inexpensive to calculate.
local function calculateRelevance(instance, category)
    local score = 25
    if category == "Remote" then
        score = 90
    elseif category == "Humanoid Model" then
        score = 80
    elseif category == "Tool" then
        score = 70
    elseif category == "Value" then
        score = 60
    end

    if instance:IsDescendantOf(ReplicatedStorage) then
        score += 5
    elseif instance:IsDescendantOf(Workspace) then
        score += 3
    end
    if instance:IsA("ValueBase") then
        local ok, value = pcall(function() return instance.Value end)
        if ok and value ~= nil and tostring(value) ~= "" then score += 5 end
    end
    return math.clamp(score, 0, 100)
end

local function relevanceLabel(score)
    if score >= 85 then return "High" end
    if score >= 65 then return "Medium" end
    return "Low"
end

local function processInstance(instance)
    if not State.alive or not inScanScope(instance) or seenInstances[instance] then
        return false
    end

    seenInstances[instance] = true
    stats.nodes += 1

    local isRemote = instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction")
    local isValue = instance:IsA("ValueBase")
    local isTool = instance:IsA("Tool")
    local isHumanoidModel = instance:IsA("Model")
        and instance:FindFirstChildWhichIsA("Humanoid", true) ~= nil

    if isRemote then stats.remotes += 1 end
    if isValue then stats.values += 1 end
    if isTool then stats.tools += 1 end
    if isHumanoidModel then
        stats.models += 1
        humanoidModelCounted[instance] = true
    end

    if isRelevant(instance) then
        local record = {
            Class = instance.ClassName,
            Name = instance.Name,
            Path = fullPath(instance),
            Category = classifyRelevant(instance),
            Family = familyName(instance),
            RelevanceScore = 0,
            Relevance = "Low",
            ParentPath = instance.Parent and fullPath(instance.Parent) or "",
            NearestRelevantAncestor = "",
            ChildCount = 0,
        }
        record.RelevanceScore = calculateRelevance(instance, record.Category)
        record.Relevance = relevanceLabel(record.RelevanceScore)
        if isValue then record.Value = tostring(instance.Value) end
        State.analysisRecords[instance] = record
        entryByInstance[instance] = record
        instanceByRecord[record] = instance
        table.insert(State.scanEntries, record)
        addExplorerRow(instance, #State.scanEntries, record.Category)
        if not nameChangeConnections[instance] then
            nameChangeConnections[instance] = instance:GetPropertyChangedSignal("Name"):Connect(refreshTrackedPaths)
        end
        registerAncestorNameWatch(instance)
        if isValue and not valueChangeConnections[instance] then
            valueChangeConnections[instance] = instance:GetPropertyChangedSignal("Value"):Connect(function()
                if not State.alive then return end
                local current = entryByInstance[instance]
                if not current then return end
                current.Value = tostring(instance.Value)
                current.RelevanceScore = calculateRelevance(instance, current.Category)
                current.Relevance = relevanceLabel(current.RelevanceScore)
                local row = rowByInstance[instance]
                if row and row.Parent then
                    row.Text = string.format("  [%s R:%d] %s = %s", current.Category or instance.ClassName,
                        current.RelevanceScore or 0, current.Path or fullPath(instance), current.Value)
                end
                if State.scanComplete and scheduleRelationshipRefresh then scheduleRelationshipRefresh() end
                queueLiveUiRefresh()
            end)
        end
    end

    return true
end

local function updateHumanoidModel(model)
    if not seenInstances[model] or not model:IsA("Model") then return end
    local ok, hasHumanoid = pcall(function()
        return model:FindFirstChildWhichIsA("Humanoid", true) ~= nil
    end)
    if not ok then return end

    local wasCounted = humanoidModelCounted[model] == true
    if hasHumanoid and not wasCounted then
        humanoidModelCounted[model] = true
        stats.models += 1
        if not entryByInstance[model] then
            local record = {
                Class = model.ClassName,
                Name = model.Name,
                Path = fullPath(model),
                Category = "Humanoid Model",
                Family = familyName(model),
                RelevanceScore = calculateRelevance(model, "Humanoid Model"),
                Relevance = "Medium",
                ParentPath = model.Parent and fullPath(model.Parent) or "",
                NearestRelevantAncestor = "",
                ChildCount = 0,
            }
            record.Relevance = relevanceLabel(record.RelevanceScore)
            State.analysisRecords[model] = record
            entryByInstance[model] = record
            instanceByRecord[record] = model
            table.insert(State.scanEntries, record)
            addExplorerRow(model, #State.scanEntries, record.Category)
            if not nameChangeConnections[model] then
                nameChangeConnections[model] = model:GetPropertyChangedSignal("Name"):Connect(refreshTrackedPaths)
            end
            registerAncestorNameWatch(model)
        end
    elseif not hasHumanoid and wasCounted then
        humanoidModelCounted[model] = nil
        stats.models = math.max(0, stats.models - 1)
        removeExplorerEntry(model)
    end
end

local function refreshHumanoidAncestors(instance)
    local cursor = instance.Parent
    while cursor and cursor ~= Workspace and cursor ~= ReplicatedStorage do
        if cursor:IsA("Model") then
            updateHumanoidModel(cursor)
        end
        cursor = cursor.Parent
    end
end

local function unprocessInstance(instance)
    if not seenInstances[instance] then return false end
    seenInstances[instance] = nil
    stats.nodes = math.max(0, stats.nodes - 1)

    if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
        stats.remotes = math.max(0, stats.remotes - 1)
    end
    if instance:IsA("ValueBase") then
        stats.values = math.max(0, stats.values - 1)
    end
    if instance:IsA("Tool") then
        stats.tools = math.max(0, stats.tools - 1)
    end
    if humanoidModelCounted[instance] then
        humanoidModelCounted[instance] = nil
        stats.models = math.max(0, stats.models - 1)
    end

    local nameConnection = nameChangeConnections[instance]
    if nameConnection then
        pcall(function() nameConnection:Disconnect() end)
        nameChangeConnections[instance] = nil
    end
    local valueConnection = valueChangeConnections[instance]
    if valueConnection then
        pcall(function() valueConnection:Disconnect() end)
        valueChangeConnections[instance] = nil
    end
    removeExplorerEntry(instance)
    return true
end

local function updateStatus(status, containerName)
    if not State.alive then return end
    Title.Text = "AetheriusCore v" .. SCRIPT_VERSION
    StatusText.Text = "● " .. string.upper(tostring(status)) .. "  •  " .. tostring(containerName or "CLIENT SCAN")
    StatusText.TextColor3 = (string.find(string.upper(tostring(status)), "ERROR", 1, true) and Color3.fromRGB(235, 85, 85))
        or (string.find(string.upper(tostring(status)), "PAUS", 1, true) and Color3.fromRGB(245, 180, 70))
        or Color3.fromRGB(70, 205, 125)
    StatusDetailText.Text = "Scan scope: Workspace + ReplicatedStorage\nRemote observer: "
        .. (State.hookInstalled and "Active (passive)" or "Unavailable / initializing")
        .. "\nLive updates: add/remove, names, ancestor paths, and ValueBase values"

    overviewStatLabels.Objects.Text = tostring(stats.nodes)
    overviewStatLabels.Remotes.Text = tostring(stats.remotes)
    overviewStatLabels.Values.Text = tostring(stats.values)
    overviewStatLabels.Tools.Text = tostring(stats.tools)
    overviewStatLabels["Humanoid Models"].Text = tostring(stats.models)
end

local function exportData()
    if type(writefile) ~= "function" then
        exportText.Text = "Export: writefile unavailable in this executor"
        return
    end
    local ok, err = pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("AetheriusCore") then makefolder("AetheriusCore") end
        elseif type(makefolder) == "function" then
            pcall(makefolder, "AetheriusCore")
        end
        local payload = {
            Version = SCRIPT_VERSION,
            Timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            Stats = stats,
            RelationshipCount = #State.relationshipEdges,
            Relationships = State.relationshipEdges,
            Entries = {},
        }
        for _, instance in ipairs(explorerRows) do
            if instance and instance.Parent then
                -- UI rows are not game instances; detailed records are stored separately below.
            end
        end
        for _, item in ipairs(State.scanEntries or {}) do
            table.insert(payload.Entries, item)
        end
        writefile("AetheriusCore/CoreData.json", HttpService:JSONEncode(payload))
    end)
    exportText.Text = ok and "Export: successful (AetheriusCore/CoreData.json)"
        or ("Export: failed - " .. tostring(err))
end

-- Build a capped, deduplicated hierarchy map after the instance scan. Each
-- relevant object links only to its nearest relevant ancestor, preventing the
-- all-pairs relationship explosion that caused duplicate-heavy output.
local function analyzeRelationships(generation)
    -- Build a temporary result and commit only if this generation finishes.
    -- Initialize counts separately so each parent's count is independent of
    -- iteration order and a failed refresh cannot publish partial edges.
    local nextEdges = {}
    local nextRecordState = {}
    local processed = 0
    local entries = State.scanEntries or {}

    for _, record in ipairs(entries) do
        nextRecordState[record] = {NearestRelevantAncestor = "", ChildCount = 0}
    end

    for _, record in ipairs(entries) do
        if not State.alive or generation ~= State.scanGeneration then return false end
        local instance = instanceByRecord[record]
        if instance then
            local cursor = instance.Parent
            while cursor and cursor ~= Workspace and cursor ~= ReplicatedStorage do
                local parentRecord = entryByInstance[cursor]
                if parentRecord and parentRecord ~= record then
                    local parentState = nextRecordState[parentRecord]
                    local recordState = nextRecordState[record]
                    if parentState and recordState then
                        recordState.NearestRelevantAncestor = parentRecord.Path or ""
                        if #nextEdges < MAX_RELATIONSHIPS then
                            parentState.ChildCount += 1
                            table.insert(nextEdges, {
                                Parent = parentRecord.Path or "",
                                Child = record.Path or "",
                                Type = "Relevant ancestor",
                            })
                        end
                    end
                    break
                end
                cursor = cursor.Parent
            end
        end
        processed += 1
        if processed % ANALYSIS_BATCH_SIZE == 0 then
            updateStatus("Analyzing relationships " .. tostring(processed) .. "/" .. tostring(#entries), "Analysis")
            task.wait(SCAN_YIELD_SECONDS)
        end
    end

    if not State.alive or generation ~= State.scanGeneration then return false end
    for record, values in pairs(nextRecordState) do
        record.NearestRelevantAncestor = values.NearestRelevantAncestor
        record.ChildCount = values.ChildCount
    end
    State.relationshipEdges = nextEdges
    return true
end

-- Lightweight integrity validation runs once after the initial relationship
-- pass. It checks record uniqueness/mappings and category totals without
-- rescanning the full game hierarchy.
local function validateAnalysisSnapshot()
    local warnings = 0
    local counts = {Remote = 0, Value = 0, Tool = 0, ["Humanoid Model"] = 0}
    local uniqueRecords = {}

    for _, record in ipairs(State.scanEntries or {}) do
        if uniqueRecords[record] then
            warnings += 1
        else
            uniqueRecords[record] = true
        end
        local instance = instanceByRecord[record]
        if not instance or entryByInstance[instance] ~= record then
            warnings += 1
        end
        if counts[record.Category] ~= nil then
            counts[record.Category] += 1
        end
    end

    if counts.Remote ~= stats.remotes then warnings += 1 end
    if counts.Value ~= stats.values then warnings += 1 end
    if counts.Tool ~= stats.tools then warnings += 1 end
    if counts["Humanoid Model"] ~= stats.models then warnings += 1 end
    if #State.relationshipEdges > MAX_RELATIONSHIPS then warnings += 1 end

    return warnings
end

-- Coalesce bursts of live changes into one asynchronous relationship refresh.
-- A pending request is remembered if changes arrive while a refresh is running.
local relationshipRefreshRunning = false
local relationshipRefreshRequested = false
scheduleRelationshipRefresh = function()
    if not State.alive or not State.scanComplete then return end
    relationshipRefreshRequested = true
    if relationshipRefreshRunning then return end
    relationshipRefreshRunning = true
    task.spawn(function()
        while State.alive and relationshipRefreshRequested do
            relationshipRefreshRequested = false
            local generation = State.scanGeneration
            local ok, result = pcall(analyzeRelationships, generation)
            if not ok then
                relationshipRefreshRequested = false
                logRuntime("Relationship refresh failed: " .. tostring(result))
                break
            end
            if not result or generation ~= State.scanGeneration then break end
            if State.scanComplete then
                dataText.Text = string.format(
                    "Live analysis refreshed\nNodes: %d\nRemotes: %d\nValues: %d\nTools: %d\nHumanoid Models: %d\nClassified records: %d\nRelationships: %d / %d",
                    stats.nodes, stats.remotes, stats.values, stats.tools, stats.models,
                    #State.scanEntries, #State.relationshipEdges, MAX_RELATIONSHIPS
                )
                exportText.Text = "Live analysis refreshed; export to save current data."
            end
        end
        relationshipRefreshRunning = false
        if State.alive and relationshipRefreshRequested then
            scheduleRelationshipRefresh()
        end
    end)
end

local function scan()
    if not State.alive then return end
    State.scanGeneration += 1
    local generation = State.scanGeneration
    table.clear(stats)
    stats.nodes, stats.remotes, stats.values, stats.tools, stats.models = 0, 0, 0, 0, 0
    table.clear(seenInstances)
    table.clear(entryByInstance)
    table.clear(instanceByRecord)
    table.clear(humanoidModelCounted)
    for instance, connection in pairs(nameChangeConnections) do
        pcall(function() connection:Disconnect() end)
        nameChangeConnections[instance] = nil
    end
    for instance, connection in pairs(valueChangeConnections) do
        pcall(function() connection:Disconnect() end)
        valueChangeConnections[instance] = nil
    end
    for instance, connection in pairs(ancestorNameConnections) do
        pcall(function() connection:Disconnect() end)
        ancestorNameConnections[instance] = nil
    end
    table.clear(State.analysisRecords)
    table.clear(State.relationshipEdges)
    State.scanEntries = {}
    clearExplorer()
    exportText.Text = "Export: scanning..."
    scanStarted = os.clock()
    State.scanComplete = false
    State.scanErrors = 0
    updateStatus("Scanning", "Workspace")

    task.spawn(function()
        local containers = {
            {"Workspace", Workspace},
            {"ReplicatedStorage", ReplicatedStorage},
        }
        for _, pair in ipairs(containers) do
            local containerName, container = pair[1], pair[2]
            if not State.alive or generation ~= State.scanGeneration then return end
            updateStatus("Scanning", containerName)

            local ok, descendants = pcall(function() return container:GetDescendants() end)
            if not ok then
                logRuntime("Could not read " .. containerName .. ": " .. tostring(descendants))
                continue
            end

            for index, instance in ipairs(descendants) do
                if not State.alive or generation ~= State.scanGeneration then return end
                local processOk, processResult = pcall(processInstance, instance)
                if not processOk then
                    State.scanErrors += 1
                    if State.scanErrors <= 10 then
                        logRuntime("Instance processing failed: " .. tostring(processResult))
                    end
                end

                if index % SCAN_BATCH_SIZE == 0 then
                    updateStatus("Scanning", containerName)
                    task.wait(SCAN_YIELD_SECONDS)
                end
            end
        end

        if not State.alive or generation ~= State.scanGeneration then return end
        local relationshipCallOk, analysisOk = pcall(analyzeRelationships, generation)
        if not relationshipCallOk then
            State.scanErrors += 1
            logRuntime("Initial relationship analysis failed: " .. tostring(analysisOk))
            analysisOk = false
        end
        if not analysisOk or not State.alive or generation ~= State.scanGeneration then
            if State.alive and generation == State.scanGeneration then
                updateStatus("Analysis error; rescan recommended", "Validation")
                exportText.Text = "Analysis incomplete; rescan to retry."
            end
            return
        end
        local integrityWarnings = validateAnalysisSnapshot()
        State.scanErrors += integrityWarnings
        if integrityWarnings > 0 then
            logRuntime("Snapshot validation found " .. tostring(integrityWarnings) .. " warning(s)")
        end
        local elapsed = os.clock() - scanStarted
        State.scanComplete = true
        local completionStatus = State.scanErrors > 0
            and string.format("Ready with %d warning(s) (%.2fs)", State.scanErrors, elapsed)
            or string.format("Ready (%.2fs)", elapsed)
        updateStatus(completionStatus, State.scanErrors > 0 and "Validation" or "Complete")
        dataText.Text = string.format(
            "Scan complete: %.2fs\nNodes: %d\nRemotes: %d\nValues: %d\nTools: %d\nHumanoid Models: %d\nClassified: %d\nRelationships: %d / %d\nRelevance: rule-based 0-100\nExplorer rows: %d / %d\nProcessing warnings: %d",
            elapsed, stats.nodes, stats.remotes, stats.values, stats.tools, stats.models,
            #State.scanEntries, #State.relationshipEdges, MAX_RELATIONSHIPS, #explorerRows, MAX_EXPLORER_ROWS, State.scanErrors
        )
        if #State.scanEntries > MAX_EXPLORER_ROWS then
            exportText.Text = string.format("Explorer capped at %d rows; export includes %d records.", MAX_EXPLORER_ROWS, #State.scanEntries)
        else
            exportText.Text = "Scan complete. Export available."
        end
        exportData()
        logRuntime("Scan completed: " .. tostring(stats.nodes) .. " nodes")
    end)
end

track(rescanBtn.MouseButton1Click:Connect(scan))

-- Passive remote-call observation. Arguments and return values are intentionally
-- not inspected or changed. Calls are forwarded unchanged to the prior method.
-- The hook is process-wide in executor environments and cannot be disconnected;
-- the callback checks State.alive so a closed UI stops receiving log updates.
local function installPassiveRemoteLogger()
    if State.hookInstalled then return end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        logRuntime("Remote interception APIs unavailable; passive log disabled")
        return
    end
    local oldNamecall
    local ok, result = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if State.alive and (method == "FireServer" or method == "InvokeServer") then
                local isInstance = typeof(self) == "Instance"
                if isInstance and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                    logRuntime(method .. " -> " .. self:GetFullName())
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
    if ok and type(oldNamecall) == "function" then
        State.hookInstalled = true
        logRuntime("Passive remote-call logger installed")
    else
        logRuntime("Remote logger setup failed: " .. tostring(result))
    end
end

-- Live descendant updates are deduplicated against the initial scan snapshot.
-- UI refreshes are coalesced to avoid redrawing for every instance in a burst.
local liveUiRefreshQueued = false
queueLiveUiRefresh = function()
    if liveUiRefreshQueued then return end
    liveUiRefreshQueued = true
    task.delay(0.1, function()
        liveUiRefreshQueued = false
        if not State.alive then return end
        overviewStatLabels.Objects.Text = tostring(stats.nodes)
        overviewStatLabels.Remotes.Text = tostring(stats.remotes)
        overviewStatLabels.Values.Text = tostring(stats.values)
        overviewStatLabels.Tools.Text = tostring(stats.tools)
        overviewStatLabels["Humanoid Models"].Text = tostring(stats.models)
        if State.scanComplete then
            dataText.Text = string.format(
                "Live data updated\nNodes: %d\nRemotes: %d\nValues: %d\nTools: %d\nHumanoid Models: %d\nClassified records: %d",
                stats.nodes, stats.remotes, stats.values, stats.tools, stats.models, #State.scanEntries
            )
            exportText.Text = "Live changes detected; rescan to refresh export."
        end
    end)
end

local function onDescendantAdded(instance, containerName)
    if not State.alive then return end
    if processInstance(instance) then
        if isRelevant(instance) and instance.Parent ~= Workspace and instance.Parent ~= ReplicatedStorage then
            logRuntime("[" .. containerName .. " +] " .. instance.Name .. " (" .. instance.ClassName .. ")")
        end
        refreshHumanoidAncestors(instance)
        if State.scanComplete and scheduleRelationshipRefresh then
            scheduleRelationshipRefresh()
        end
        queueLiveUiRefresh()
    end
end

local function onDescendantRemoving(instance, containerName)
    if not State.alive then return end
    local affectedModels = {}
    local cursor = instance.Parent
    while cursor and cursor ~= Workspace and cursor ~= ReplicatedStorage do
        if cursor:IsA("Model") then
            table.insert(affectedModels, cursor)
        end
        cursor = cursor.Parent
    end

    if unprocessInstance(instance) then
        if isRelevant(instance) and instance.Parent ~= Workspace and instance.Parent ~= ReplicatedStorage then
            logRuntime("[" .. containerName .. " -] " .. instance.Name .. " (" .. instance.ClassName .. ")")
        end
        task.defer(function()
            if not State.alive then return end
            for _, model in ipairs(affectedModels) do
                updateHumanoidModel(model)
            end
            if State.scanComplete and scheduleRelationshipRefresh then
                scheduleRelationshipRefresh()
            end
            queueLiveUiRefresh()
        end)
    end
end

track(Workspace.DescendantAdded:Connect(function(instance)
    onDescendantAdded(instance, "Workspace")
end))
track(Workspace.DescendantRemoving:Connect(function(instance)
    onDescendantRemoving(instance, "Workspace")
end))
track(ReplicatedStorage.DescendantAdded:Connect(function(instance)
    onDescendantAdded(instance, "ReplicatedStorage")
end))
track(ReplicatedStorage.DescendantRemoving:Connect(function(instance)
    onDescendantRemoving(instance, "ReplicatedStorage")
end))

-- Keep concise top-level lifecycle messages for continuity with prior behavior.
track(Workspace.ChildAdded:Connect(function(child)
    logRuntime("[Workspace root +] " .. child.Name)
end))
track(Workspace.ChildRemoved:Connect(function(child)
    logRuntime("[Workspace root -] " .. child.Name)
end))
track(ReplicatedStorage.ChildAdded:Connect(function(child)
    logRuntime("[ReplicatedStorage root +] " .. child.Name)
end))
track(ReplicatedStorage.ChildRemoved:Connect(function(child)
    logRuntime("[ReplicatedStorage root -] " .. child.Name)
end))

-- Dragging supports mouse and touch. Global input connection is tracked for cleanup.
local dragging, dragStart, startPosition, dragInput
track(TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = MainWindow.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end))
track(TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput and State.alive then
        local delta = input.Position - dragStart
        MainWindow.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

local minimized = false
track(MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized

    if minimized then
        -- Collapse the full panel into a compact floating square button.
        ContentArea.Visible = false
        TabBar.Visible = false
        StatusHeader.Visible = false
        StatusDetails.Visible = false
        Title.Visible = false
        CloseBtn.Visible = false
        headerAccent.Visible = false

        MainWindow.Size = UDim2.fromOffset(36, 36)
        TitleBar.Size = UDim2.fromOffset(36, 36)
        MinimizeBtn.Size = UDim2.fromOffset(24, 24)
        MinimizeBtn.Position = UDim2.fromOffset(6, 6)
        MinimizeBtn.Text = "+"
    else
        -- Restore the original panel layout and controls.
        MainWindow.Size = UDim2.fromOffset(345, 293)
        TitleBar.Size = UDim2.new(1, 0, 0, 32)
        ContentArea.Visible = true
        TabBar.Visible = true
        StatusHeader.Visible = true
        StatusDetails.Visible = statusDetailsExpanded
        TabBar.Position = UDim2.fromOffset(8, statusDetailsExpanded and 128 or 65)
        ContentArea.Position = UDim2.fromOffset(8, statusDetailsExpanded and 154 or 91)
        ContentArea.Size = UDim2.new(1, -16, 1, statusDetailsExpanded and -163 or -100)
        Title.Visible = true
        CloseBtn.Visible = true
        headerAccent.Visible = true

        MinimizeBtn.Size = UDim2.fromOffset(20, 20)
        MinimizeBtn.Position = UDim2.new(1, -55, 0, 6)
        MinimizeBtn.Text = "−"
    end
end))

track(CloseBtn.MouseButton1Click:Connect(function()
    if not State.alive then return end
    State.alive = false
    State.scanGeneration += 1 -- invalidate an in-progress scan
    safeDisconnectAll()
    for instance, connection in pairs(nameChangeConnections) do
        pcall(function() connection:Disconnect() end)
        nameChangeConnections[instance] = nil
    end
    for instance, connection in pairs(valueChangeConnections) do
        pcall(function() connection:Disconnect() end)
        valueChangeConnections[instance] = nil
    end
    for instance, connection in pairs(ancestorNameConnections) do
        pcall(function() connection:Disconnect() end)
        ancestorNameConnections[instance] = nil
    end
    pcall(function() ScreenGui:Destroy() end)
    if env.AetheriusCoreState == State then env.AetheriusCoreState = nil end
end))

-- Keep the panel within the viewport after initial placement and resolution changes.
local function constrainWindow()
    if not State.alive then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local size = MainWindow.AbsoluteSize
    local x = math.clamp(MainWindow.AbsolutePosition.X, 0, math.max(0, viewport.X - size.X))
    local y = math.clamp(MainWindow.AbsolutePosition.Y, 0, math.max(0, viewport.Y - size.Y))
    MainWindow.Position = UDim2.fromOffset(x, y)
end
if Workspace.CurrentCamera then
    track(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(constrainWindow))
end

installPassiveRemoteLogger()
scan()
print("[AetheriusCore] v" .. SCRIPT_VERSION .. " initialized")
