-- ==============================================================================
-- AetheriusCore: Client Game Intelligence Analyzer (v0.11.3 Overview UI)
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
local SCRIPT_VERSION = "0.11.3"
local GUI_NAME = "AetheriusCoreUI"
local MAX_HISTORY = 30
local MAX_EXPLORER_ROWS = 250
local SCAN_BATCH_SIZE = 250
local SCAN_YIELD_SECONDS = 0.03

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
StatusExpand.BackgroundTransparency = 1
StatusExpand.Text = "▼"
StatusExpand.TextColor3 = Color3.fromRGB(155, 162, 178)
StatusExpand.TextSize = 9
StatusExpand.Font = Enum.Font.GothamBold
StatusExpand.Parent = StatusHeader

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
    button.Parent = TitleBar
    return button
end

local MinimizeBtn = makeTitleButton("−", -54, Color3.fromRGB(230, 205, 120))
MinimizeBtn.Size = UDim2.fromOffset(20, 20)
MinimizeBtn.Position = UDim2.new(1, -55, 0, 6)
MinimizeBtn.BackgroundTransparency = 0
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(43, 44, 48)
MinimizeBtn.AutoButtonColor = true
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 5)

local CloseBtn = makeTitleButton("×", -25, Color3.fromRGB(235, 115, 115))
CloseBtn.Size = UDim2.fromOffset(24, 24)
CloseBtn.Position = UDim2.new(1, -29, 0, 4)

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
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = TabBar
    tabButtons[tabName] = btn

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
local scanStarted = 0

local function clearExplorer()
    for _, row in ipairs(explorerRows) do
        pcall(function() row:Destroy() end)
    end
    table.clear(explorerRows)
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

local function addExplorerRow(instance, order)
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
    local info = string.format("  [%s] %s", instance.ClassName, fullPath(instance))
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
    table.insert(explorerRows, row)
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

local function updateStatus(status, containerName)
    if not State.alive then return end
    Title.Text = "AetheriusCore v" .. SCRIPT_VERSION
    StatusText.Text = "● " .. string.upper(tostring(status)) .. "  •  " .. tostring(containerName or "CLIENT SCAN")
    StatusText.TextColor3 = (string.find(string.upper(tostring(status)), "ERROR", 1, true) and Color3.fromRGB(235, 85, 85))
        or (string.find(string.upper(tostring(status)), "PAUS", 1, true) and Color3.fromRGB(245, 180, 70))
        or Color3.fromRGB(70, 205, 125)
    StatusDetailText.Text = "Scan scope: Workspace + ReplicatedStorage\nRemote observer: "
        .. (State.hookInstalled and "Active (passive)" or "Unavailable / initializing")
        .. "\nLive updates: Enabled"

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

local function scan()
    if not State.alive then return end
    State.scanGeneration += 1
    local generation = State.scanGeneration
    table.clear(stats)
    stats.nodes, stats.remotes, stats.values, stats.tools, stats.models = 0, 0, 0, 0, 0
    State.scanEntries = {}
    clearExplorer()
    exportText.Text = "Export: scanning..."
    scanStarted = os.clock()
    updateStatus("Scanning", "Workspace")

    task.spawn(function()
        local containers = {
            {"Workspace", Workspace},
            {"ReplicatedStorage", ReplicatedStorage},
        }
        local displayCount = 0
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
                stats.nodes += 1

                if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
                    stats.remotes += 1
                end
                if instance:IsA("ValueBase") then stats.values += 1 end
                if instance:IsA("Tool") then stats.tools += 1 end
                if instance:IsA("Model") and instance:FindFirstChildWhichIsA("Humanoid", true) then
                    stats.models += 1
                end

                if isRelevant(instance) then
                    displayCount += 1
                    local record = {
                        Class = instance.ClassName,
                        Name = instance.Name,
                        Path = fullPath(instance),
                    }
                    if instance:IsA("ValueBase") then record.Value = tostring(instance.Value) end
                    table.insert(State.scanEntries, record)
                    addExplorerRow(instance, displayCount)
                end

                if index % SCAN_BATCH_SIZE == 0 then
                    updateStatus("Scanning", containerName)
                    task.wait(SCAN_YIELD_SECONDS)
                end
            end
        end

        if not State.alive or generation ~= State.scanGeneration then return end
        local elapsed = os.clock() - scanStarted
        updateStatus(string.format("Ready (%.2fs)", elapsed), "Complete")
        dataText.Text = string.format(
            "Scan complete: %.2fs\nNodes: %d\nRemotes: %d\nValues: %d\nTools: %d\nHumanoid Models: %d\nExplorer rows: %d / %d",
            elapsed, stats.nodes, stats.remotes, stats.values, stats.tools, stats.models,
            #explorerRows, MAX_EXPLORER_ROWS
        )
        if displayCount > MAX_EXPLORER_ROWS then
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

-- Live top-level additions/removals are logged, without duplicating scan rows.
track(Workspace.ChildAdded:Connect(function(child)
    logRuntime("[Workspace +] " .. child.Name)
end))
track(Workspace.ChildRemoved:Connect(function(child)
    logRuntime("[Workspace -] " .. child.Name)
end))
track(ReplicatedStorage.ChildAdded:Connect(function(child)
    logRuntime("[ReplicatedStorage +] " .. child.Name)
end))
track(ReplicatedStorage.ChildRemoved:Connect(function(child)
    logRuntime("[ReplicatedStorage -] " .. child.Name)
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
