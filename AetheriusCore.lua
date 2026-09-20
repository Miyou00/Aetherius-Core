local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Hardened LocalPlayer Resolution
local player = Players.LocalPlayer
while not player do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    player = Players.LocalPlayer
end
if not player then return end

-- Prevent duplicate hooks and clean up previous instances safely
if _G.AetheriusCoreCleanup then
    pcall(_G.AetheriusCoreCleanup)
end

-- Global Hook Controls & Engine State
_G.IgnoreAutoHooks = false
local isEngineClosed = false
local hookStatusMessage = "Spy active (Hardened Engine Mode)."

-- Profile Configuration
local PROFILE_FILENAME = "AetheriusCore_Profile_" .. game.PlaceId .. ".json"

-- Trackers for Cleanup
local activeConnections = {}
local logConnections = {}
local scheduledTaskDelays = {}

-- State Storage
local learnedActions = {}
local actionCards = {}
local ActiveSchedulerQueue = {}
local activeConfigSig = nil
local rawLogs = {}
local logRows = {}

-- Scheduler State & Thread Control
local SchedulerRunning = true
local activeTaskThreads = {}
local activeRemoteCalls = {}
local originalNamecall

-- Global Cleanup Callback
_G.AetheriusCoreCleanup = function()
    isEngineClosed = true
    SchedulerRunning = false
    _G.IgnoreAutoHooks = false
    table.clear(activeRemoteCalls)

    -- Cancel all scheduler threads
    for sig, thread in pairs(activeTaskThreads) do
        pcall(function() task.cancel(thread) end)
    end
    table.clear(activeTaskThreads)

    -- Cancel all delayed UI callbacks
    for _, delayThread in ipairs(scheduledTaskDelays) do
        pcall(function() task.cancel(delayThread) end)
    end
    table.clear(scheduledTaskDelays)

    -- Disconnect events
    for _, conn in ipairs(activeConnections) do pcall(function() conn:Disconnect() end) end
    for _, conn in ipairs(logConnections) do pcall(function() conn:Disconnect() end) end

    -- Restore Hook Metamethod safely
    pcall(function()
        if _G._AetheriusOriginalNamecall_v6 and hookmetamethod then
            hookmetamethod(game, "__namecall", _G._AetheriusOriginalNamecall_v6)
            _G._AetheriusOriginalNamecall_v6 = nil
        end
    end)

    -- Clear state dictionaries completely
    table.clear(learnedActions)
    table.clear(actionCards)
    table.clear(ActiveSchedulerQueue)
    table.clear(rawLogs)
    table.clear(logRows)

    -- Destroy UI
    local playerGui = player and player:FindFirstChild("PlayerGui")
    local oldGui = playerGui and playerGui:FindFirstChild("AetheriusCoreEngine")
    if oldGui then oldGui:Destroy() end
end

-- UI Initialization
local gui = Instance.new("ScreenGui")
gui.Name = "AetheriusCoreEngine"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(364, 280)
frame.Position = UDim2.new(0.15, 0, 0.15, 60)
frame.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
frame.BorderSizePixel = 0
frame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 5)
frameCorner.Parent = frame

-- Header Bar
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 20)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
bar.BorderSizePixel = 0
bar.Parent = frame

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 5)
barCorner.Parent = bar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -65, 1, 0)
title.Position = UDim2.fromOffset(6, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ Aetherius Core [v6.5 - Fully Hardened Execution]"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.TextSize = 8
title.Font = Enum.Font.Code
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local emergencyStopBtn = Instance.new("TextButton")
emergencyStopBtn.Size = UDim2.fromOffset(32, 14)
emergencyStopBtn.Position = UDim2.new(1, -62, 0, 3)
emergencyStopBtn.Text = "🛑 STOP"
emergencyStopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
emergencyStopBtn.TextSize = 6
emergencyStopBtn.Font = Enum.Font.Code
emergencyStopBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 30)
emergencyStopBtn.BorderSizePixel = 0
emergencyStopBtn.Parent = bar

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 3)
stopCorner.Parent = emergencyStopBtn

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 14)
closeBtn.Position = UDim2.new(1, -28, 0, 3)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 8
closeBtn.Font = Enum.Font.Code
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = bar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 3)
closeCorner.Parent = closeBtn

local function triggerEmergencyStop()
    SchedulerRunning = not SchedulerRunning
    if SchedulerRunning then
        emergencyStopBtn.Text = "🛑 STOP"
        emergencyStopBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 30)
    else
        emergencyStopBtn.Text = "▶ RESUME"
        emergencyStopBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
    end
end

table.insert(activeConnections, emergencyStopBtn.MouseButton1Click:Connect(triggerEmergencyStop))
table.insert(activeConnections, closeBtn.MouseButton1Click:Connect(function()
    if _G.AetheriusCoreCleanup then _G.AetheriusCoreCleanup() end
end))

-- Navigation System
local function createTab(text, xPos, width)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(width or 48, 16)
    btn.Position = UDim2.fromOffset(xPos, 22)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(140, 140, 150)
    btn.TextSize = 7
    btn.Font = Enum.Font.Code
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    btn.BorderSizePixel = 0
    btn.Parent = frame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = btn
    return btn
end

local tabSpyBtn = createTab("Spy", 4, 44)
local tabMacroBtn = createTab("Macro", 50, 48)
local tabAnalyzeBtn = createTab("Analyze", 100, 50)
local tabDumpBtn = createTab("Dumper", 152, 48)
local tabDecompBtn = createTab("Modules", 202, 50)
local tabMonitorBtn = createTab("Monitor", 254, 48)
local tabAutoBtn = createTab("DNA/Cognitive", 304, 54)

local function createContainer()
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 1, -40)
    container.Position = UDim2.fromOffset(0, 40)
    container.BackgroundTransparency = 1

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.fromOffset(6, 2)
    scroll.Size = UDim2.new(1, -12, 1, -26)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
    scroll.ScrollingDirection = Enum.ScrollingDirection.XY
    scroll.Parent = container

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.Parent = scroll

    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 3)
    scrollCorner.Parent = scroll

    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1, -12, 0, 20)
    footer.Position = UDim2.new(0, 6, 1, -22)
    footer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    footer.BorderSizePixel = 0
    footer.Parent = container

    local footerCorner = Instance.new("UICorner")
    footerCorner.CornerRadius = UDim.new(0, 3)
    footerCorner.Parent = footer

    table.insert(activeConnections, layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X, 0, layout.AbsoluteContentSize.Y + 10)
    end))

    return container, scroll, footer, layout
end

local spyContainer, spyScroll, spyFooter = createContainer()
spyContainer.Parent = frame

local macroContainer, macroScroll, macroFooter = createContainer()
macroContainer.Visible = false
macroContainer.Parent = frame

local analyzeContainer, analyzeScroll, analyzeFooter = createContainer()
analyzeContainer.Visible = false
analyzeContainer.Parent = frame

local dumpContainer, dumpScroll, dumpFooter = createContainer()
dumpContainer.Visible = false
dumpContainer.Parent = frame

local decompContainer, decompScroll, decompFooter = createContainer()
decompContainer.Visible = false
decompContainer.Parent = frame

local monitorContainer, monitorScroll, monitorFooter = createContainer()
monitorContainer.Visible = false
monitorContainer.Parent = frame

local autoContainer, autoScroll, autoFooter, autoLayout = createContainer()
autoContainer.Visible = false
autoContainer.Parent = frame

-- Configuration Panel Sub-UI
local configSubPanel = Instance.new("Frame")
configSubPanel.Size = UDim2.new(1, 0, 1, -40)
configSubPanel.Position = UDim2.fromOffset(0, 40)
configSubPanel.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
configSubPanel.BorderSizePixel = 0
configSubPanel.Visible = false
configSubPanel.Parent = frame

local panelHeader = Instance.new("TextLabel")
panelHeader.Size = UDim2.new(1, -12, 0, 36)
panelHeader.Position = UDim2.fromOffset(6, 6)
panelHeader.BackgroundTransparency = 1
panelHeader.TextColor3 = Color3.fromRGB(240, 240, 250)
panelHeader.TextSize = 8
panelHeader.Font = Enum.Font.Code
panelHeader.TextXAlignment = Enum.TextXAlignment.Left
panelHeader.TextYAlignment = Enum.TextYAlignment.Top
panelHeader.TextWrapped = true
panelHeader.Text = "Config Panel: Select a script to configure. Status: " .. hookStatusMessage
panelHeader.Parent = configSubPanel

local configArg1Btn = Instance.new("TextButton")
configArg1Btn.Size = UDim2.new(1, -12, 0, 26)
configArg1Btn.Position = UDim2.fromOffset(6, 50)
configArg1Btn.Text = "Argument #1: [None Captured]"
configArg1Btn.TextColor3 = Color3.new(1, 1, 1)
configArg1Btn.TextSize = 7
configArg1Btn.Font = Enum.Font.Code
configArg1Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
configArg1Btn.BorderSizePixel = 0
configArg1Btn.Parent = configSubPanel

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 4)
tCorner.Parent = configArg1Btn

local configLoopBtn = Instance.new("TextButton")
configLoopBtn.Size = UDim2.new(1, -12, 0, 26)
configLoopBtn.Position = UDim2.fromOffset(6, 82)
configLoopBtn.Text = "Loop Execution: OFF"
configLoopBtn.TextColor3 = Color3.new(1, 1, 1)
configLoopBtn.TextSize = 7
configLoopBtn.Font = Enum.Font.Code
configLoopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
configLoopBtn.BorderSizePixel = 0
configLoopBtn.Parent = configSubPanel

local lCorner = Instance.new("UICorner")
lCorner.CornerRadius = UDim.new(0, 4)
lCorner.Parent = configLoopBtn

local configTeleportOptBtn = Instance.new("TextButton")
configTeleportOptBtn.Size = UDim2.new(1, -12, 0, 26)
configTeleportOptBtn.Position = UDim2.fromOffset(6, 114)
configTeleportOptBtn.Text = "Opt-In Spatial Teleport: OFF"
configTeleportOptBtn.TextColor3 = Color3.new(1, 1, 1)
configTeleportOptBtn.TextSize = 7
configTeleportOptBtn.Font = Enum.Font.Code
configTeleportOptBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
configTeleportOptBtn.BorderSizePixel = 0
configTeleportOptBtn.Parent = configSubPanel

local toCorner = Instance.new("UICorner")
toCorner.CornerRadius = UDim.new(0, 4)
toCorner.Parent = configTeleportOptBtn

local backToListBtn = Instance.new("TextButton")
backToListBtn.Size = UDim2.new(1, -12, 0, 26)
backToListBtn.Position = UDim2.fromOffset(6, 146)
backToListBtn.Text = "⬅ Return to Script List"
backToListBtn.TextColor3 = Color3.new(1, 1, 1)
backToListBtn.TextSize = 7
backToListBtn.Font = Enum.Font.Code
backToListBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 70)
backToListBtn.BorderSizePixel = 0
backToListBtn.Parent = configSubPanel

local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(0, 4)
bCorner.Parent = backToListBtn

local function createOutput(parent, color)
    local out = Instance.new("TextLabel")
    out.Size = UDim2.new(1, 0, 0, 0)
    out.AutomaticSize = Enum.AutomaticSize.XY
    out.BackgroundTransparency = 1
    out.TextColor3 = color
    out.TextSize = 8
    out.Font = Enum.Font.Code
    out.TextXAlignment = Enum.TextXAlignment.Left
    out.TextYAlignment = Enum.TextYAlignment.Top
    out.Parent = parent
    return out
end

-- Clear UI Indicators for Non-Functional Features
local macroOutput = createOutput(macroScroll, Color3.fromRGB(255, 180, 100))
macroOutput.Text = "[STATUS]: Macro Recorder Engine - INACTIVE (Placeholder UI)\n"

local analyzeOutput = createOutput(analyzeScroll, Color3.fromRGB(200, 150, 255))
analyzeOutput.Text = "Select a log from Spy to inspect.\n\n"

local dumpOutput = createOutput(dumpScroll, Color3.fromRGB(255, 200, 80))
dumpOutput.Text = "[STATUS]: Garbage Collection Dumper - INACTIVE (Placeholder UI)\n"

local decompOutput = createOutput(decompScroll, Color3.fromRGB(100, 200, 255))
decompOutput.Text = "[STATUS]: Module Scanner Engine - INACTIVE (Placeholder UI)\n"

local monitorOutput = createOutput(monitorScroll, Color3.fromRGB(255, 140, 100))
monitorOutput.Text = "[STATUS]: Attribute Monitor - INACTIVE (Placeholder UI)\n\n"

local autoEmptyText = createOutput(autoScroll, Color3.fromRGB(120, 220, 255))
autoEmptyText.Text = "[COGNITIVE ENGINE ACTIVE]\nTrigger actions to self-build panels..."

local function createButton(parent, text, width, xOffset, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(width, 16)
    btn.Position = UDim2.fromOffset(xOffset, 2)
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 8
    btn.Font = Enum.Font.Code
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 3)
    corner.Parent = btn
    return btn
end

local exportBtn = createButton(spyFooter, "Copy All", 75, 3, Color3.fromRGB(35, 35, 45))
local clearBtn = createButton(spyFooter, "Clear Logs", 55, 81, Color3.fromRGB(70, 30, 30))

local recordMacroBtn = createButton(macroFooter, "Start Rec", 75, 3, Color3.fromRGB(40, 80, 40))
local copyMacroBtn = createButton(macroFooter, "Copy Macro", 75, 81, Color3.fromRGB(40, 50, 80))
local clearMacroBtn = createButton(macroFooter, "Clear", 50, 159, Color3.fromRGB(70, 30, 30))

local genFuncBtn = createButton(analyzeFooter, "Copy Function", 95, 3, Color3.fromRGB(50, 35, 75))
local clearMonitorBtn = createButton(monitorFooter, "Clear Monitor", 80, 3, Color3.fromRGB(70, 30, 30))

local saveDnaBtn = createButton(autoFooter, "Save DNA", 65, 3, Color3.fromRGB(40, 90, 50))
local loadDnaBtn = createButton(autoFooter, "Load DNA", 65, 71, Color3.fromRGB(40, 60, 100))
local clearAutoBtn = createButton(autoFooter, "Reset", 50, 139, Color3.fromRGB(70, 30, 30))

-- Robust Clipboard Handler
local function safeCopy(str, button, successMsg)
    if isEngineClosed then return false end
    
    if not setclipboard then
        local origText = button.Text
        button.Text = "No Clipboard API"
        local handle
        handle = task.delay(2, function()
            if not isEngineClosed and button and button.Parent then button.Text = origText end
            for idx, th in ipairs(scheduledTaskDelays) do
                if th == handle then table.remove(scheduledTaskDelays, idx) break end
            end
        end)
        table.insert(scheduledTaskDelays, handle)
        return false
    end

        local success = pcall(setclipboard, str)
    local origText = button.Text
    button.Text = success and (successMsg or "Copied!") or "Failed"
    
    local handle
    handle = task.delay(2, function()
        if not isEngineClosed and button and button.Parent then button.Text = origText end
        for idx, th in ipairs(scheduledTaskDelays) do
            if th == handle then table.remove(scheduledTaskDelays, idx) break end
        end
    end)
    table.insert(scheduledTaskDelays, handle)
    return success
end

local function switchTab(activeTab)
    configSubPanel.Visible = false
    spyContainer.Visible = (activeTab == "spy")
    macroContainer.Visible = (activeTab == "macro")
    analyzeContainer.Visible = (activeTab == "analyze")
    dumpContainer.Visible = (activeTab == "dump")
    decompContainer.Visible = (activeTab == "decomp")
    monitorContainer.Visible = (activeTab == "monitor")
    autoContainer.Visible = (activeTab == "auto")

    local tabs = { 
        {tabSpyBtn, "spy"},
        {tabMacroBtn, "macro"},
        {tabAnalyzeBtn, "analyze"}, 
        {tabDumpBtn, "dump"}, 
        {tabDecompBtn, "decomp"},
        {tabMonitorBtn, "monitor"},
        {tabAutoBtn, "auto"}
    }
    for _, t in ipairs(tabs) do
        local active = (t[2] == activeTab)
        t[1].BackgroundColor3 = active and Color3.fromRGB(45, 45, 55) or Color3.fromRGB(22, 22, 26)
        t[1].TextColor3 = active and Color3.new(1, 1, 1) or Color3.fromRGB(140, 140, 150)
    end
end

switchTab("spy")

table.insert(activeConnections, tabSpyBtn.MouseButton1Click:Connect(function() switchTab("spy") end))
table.insert(activeConnections, tabMacroBtn.MouseButton1Click:Connect(function() switchTab("macro") end))
table.insert(activeConnections, tabAnalyzeBtn.MouseButton1Click:Connect(function() switchTab("analyze") end))
table.insert(activeConnections, tabDumpBtn.MouseButton1Click:Connect(function() switchTab("dump") end))
table.insert(activeConnections, tabDecompBtn.MouseButton1Click:Connect(function() switchTab("decomp") end))
table.insert(activeConnections, tabMonitorBtn.MouseButton1Click:Connect(function() switchTab("monitor") end))
table.insert(activeConnections, tabAutoBtn.MouseButton1Click:Connect(function() switchTab("auto") end))

-- Strict Segment-Based Instance Resolution Engine
local function resolveInstance(fullPath)
    if not fullPath or type(fullPath) ~= "string" then return nil end
    
    local pathSegments = {}
    if string.sub(fullPath, 1, 5) == "game." then
        fullPath = string.sub(fullPath, 6)
    end
    
    for segment in string.gmatch(fullPath, "[^%.]+") do
        table.insert(pathSegments, segment)
    end
    
    if #pathSegments == 0 then return nil end
    
        local current = game
    local index = 1
    while index <= #pathSegments do
        local matchedChild = nil
        local matchedLength = 0
        local children = current:GetChildren()

        for _, child in ipairs(children) do
            local childSegments = {}
            for segmentIndex = index, #pathSegments do
                childSegments[#childSegments + 1] = pathSegments[segmentIndex]
                if table.concat(childSegments, ".") == child.Name then
                    matchedChild = child
                    matchedLength = segmentIndex - index + 1
                end
            end
        end

        if not matchedChild then return nil end
        current = matchedChild
        index = index + matchedLength
    end
    return current
end

local function resolveRemote(remoteName, fullPath)
    local inst = resolveInstance(fullPath)
    if inst and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
        return inst
    end

    if remoteName and type(remoteName) == "string" then
        local found = ReplicatedStorage:FindFirstChild(remoteName, true) or workspace:FindFirstChild(remoteName, true)
        if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction")) then
            return found
        end
    end
    return nil
end

-- Sparse Array Sanitation Engine
local function sanitizeArguments(argsPacked, customOverrides)
    local count = argsPacked.n or #argsPacked
    local sanitized = { n = count }

    local function sanitizeValue(val, visited)
        visited = visited or {}
        local t = type(val)
        if t == "table" then
            if visited[val] then return "{Cyclic Table}" end
            visited[val] = true
            local newTable = {}
            for k, v in pairs(val) do
                local lk = string.lower(tostring(k))
                if (string.match(lk, "token") or string.match(lk, "nonce") or string.match(lk, "time") or string.match(lk, "stamp")) and type(v) == "number" then
                    newTable[k] = os.clock()
                else
                    newTable[k] = sanitizeValue(v, visited)
                end
            end
            visited[val] = nil
            return newTable
        else
            return val
        end
    end

    for i = 1, count do
                -- Use a presence map so false and explicit nil overrides are preserved.
        local val
        if customOverrides and customOverrides._present and customOverrides._present[i] then
            val = customOverrides[i]
        else
            val = argsPacked[i]
        end
        sanitized[i] = sanitizeValue(val)
    end
    return sanitized
end

local ignoredRemotePatterns = { "Analytics", "ClientKit", "Telemetry", "Fps", "Ping", "Heartbeat" }

-- FIX 7: Case-insensitive ignored pattern matching
local function shouldIgnoreRemote(remotePath)
    local lowerPath = string.lower(remotePath)
    for _, pattern in ipairs(ignoredRemotePatterns) do
        if string.find(lowerPath, string.lower(pattern), 1, true) then return true end
    end
    return false
end

local function serializeValue(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 3 then return "{... Max Depth}" end
    if val == nil then return "nil" end

    local t = typeof(val)
    if t == "string" then 
        return string.format("%q", val)
    elseif t == "Instance" then
        return val:GetFullName()
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        local comps = {val:GetComponents()}
        for i, c in ipairs(comps) do comps[i] = string.format("%.2f", c) end
        return string.format("CFrame.new(%s)", table.concat(comps, ", "))
    elseif t == "number" then
        if val > 1600000000 and val < 2000000000 then return "os.clock()" end
        return tostring(val)
    elseif t == "table" then
        if visited[val] then return "{Cyclic Table}" end
        visited[val] = true
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 20 then table.insert(parts, "...and more") break end
            table.insert(parts, string.format("[%s] = %s", tostring(k), serializeValue(v, depth + 1, visited)))
        end
        visited[val] = nil
        return "{\n" .. string.rep("  ", depth + 1) .. table.concat(parts, ",\n" .. string.rep("  ", depth + 1)) .. "\n" .. string.rep("  ", depth) .. "}"
    else 
        return tostring(val) 
    end
end

local function encodeArgument(val, depth, visited)
    depth = depth or 0
    visited = visited or {}
    if depth > 4 then return {type = "string", val = "{Max Depth}"} end
    if val == nil then return {type = "nil", val = "nil"} end

    local t = typeof(val)
    if t == "string" or t == "number" or t == "boolean" then
        return {type = t, val = val}
    elseif t == "Vector3" then
        return {type = "Vector3", val = {val.X, val.Y, val.Z}}
    elseif t == "CFrame" then
        return {type = "CFrame", val = {val:GetComponents()}}
    elseif t == "Instance" then
        return {type = "Instance", val = val:GetFullName()}
    elseif t == "table" then
        if visited[val] then return {type = "string", val = "{Cyclic Table}"} end
        visited[val] = true
        local encodedTable = {}
        for k, v in pairs(val) do
            table.insert(encodedTable, {key = encodeArgument(k, depth + 1, visited), value = encodeArgument(v, depth + 1, visited)})
        end
        visited[val] = nil
        return {type = "table", val = encodedTable}
    else
        return {type = "string", val = tostring(val)}
    end
end

local function decodeArgument(data)
    if not data or type(data) ~= "table" then return nil, false end
    local t = data.type
    local v = data.val
    if t == "nil" then return nil, true end
    if t == "string" and type(v) == "string" then return v, true end
    if t == "number" and type(v) == "number" then return v, true end
    if t == "boolean" and type(v) == "boolean" then return v, true end
    
    if t == "Vector3" and type(v) == "table" and #v >= 3 then
        if type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number" then
            return Vector3.new(v[1], v[2], v[3]), true
        end
    end
    
    if t == "CFrame" and type(v) == "table" and #v >= 12 then
        local valid = true
        for i = 1, 12 do
            if type(v[i]) ~= "number" then valid = false break end
        end
        if valid then
            return CFrame.new(table.unpack(v, 1, 12)), true
        end
    end
    
    -- FIX 3: Return inst ~= nil so unresolvable Instances are treated as invalid
    if t == "Instance" and type(v) == "string" then
        local inst = resolveInstance(v)
        return inst, inst ~= nil
    end
    
    if t == "table" and type(v) == "table" then
        local tbl = {}
        for _, pair in ipairs(v) do
            if type(pair) == "table" and pair.key and pair.value then
                local decKey, kValid = decodeArgument(pair.key)
                local decVal, vValid = decodeArgument(pair.value)
                if kValid and vValid and decKey ~= nil then
                    tbl[decKey] = decVal
                end
            end
        end
        return tbl, true
    end
    return nil, false
end

local function updateTaskScheduler(signature, taskData)
    local existingThread = activeTaskThreads[signature]
    if existingThread then
        local status = coroutine.status(existingThread)
        if status ~= "dead" then return end
        activeTaskThreads[signature] = nil
    end

    activeTaskThreads[signature] = task.spawn(function()
        local actionCycleCount = 0
        while not isEngineClosed do
            if not SchedulerRunning or not taskData.enabled or (taskData.errors or 0) >= 5 then
                task.wait(0.2)
            else
                local remoteInst = resolveRemote(taskData.name, taskData.fullPath)
                local liveAction = learnedActions[signature]
                
                if remoteInst and liveAction and not liveAction.isUnavailable then
                    local currentArgs = liveAction.args or { n = 0 }
                    local liveArgs = sanitizeArguments(currentArgs, taskData.overrides)
                    
                    local char = player.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if taskData.optInTeleport and taskData.cframe and hrp then
                        local targetCF = typeof(taskData.cframe) == "CFrame" and taskData.cframe or CFrame.new()
                        if (hrp.Position - targetCF.Position).Magnitude > 8 then
                            hrp.CFrame = targetCF
                            task.wait(0.05)
                        end
                    end

                                        local ok = false
                    _G.IgnoreAutoHooks = true
                    local protectedCallOk, protectedCallResult = xpcall(function()
                        if remoteInst:IsA("RemoteEvent") then
                            return pcall(function()
                                remoteInst:FireServer(table.unpack(liveArgs, 1, liveArgs.n or #liveArgs))
                            end)
                        elseif remoteInst:IsA("RemoteFunction") then
                            if activeRemoteCalls[signature] then return false end
                            activeRemoteCalls[signature] = true

                            local callSuccess = false
                            local invThread = task.spawn(function()
                                callSuccess = pcall(function()
                                    remoteInst:InvokeServer(table.unpack(liveArgs, 1, liveArgs.n or #liveArgs))
                                end)
                                activeRemoteCalls[signature] = nil
                            end)

                            local elapsed = 0
                            while elapsed < 3.0 and coroutine.status(invThread) ~= "dead" do
                                task.wait(0.1)
                                elapsed = elapsed + 0.1
                            end

                            if coroutine.status(invThread) ~= "dead" then
                                pcall(function() task.cancel(invThread) end)
                                activeRemoteCalls[signature] = nil
                                return false
                            end
                            return callSuccess
                        end
                        return false
                    end, function()
                        return false
                    end)
                    _G.IgnoreAutoHooks = false
                    if protectedCallOk then ok = protectedCallResult end

                    if not ok then
                        taskData.errors = (taskData.errors or 0) + 1
                        if taskData.errors >= 5 then
                            taskData.enabled = false
                            taskData.pausedEnabled = false
                            
                            if activeConfigSig == signature then
                                configLoopBtn.Text = "Loop Execution: OFF (MAX ERRORS)"
                                configLoopBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
                            end
                        end
                        task.wait(math.min(6.0, 0.65 * (2 ^ taskData.errors)))
                    else
                        taskData.errors = 0
                        actionCycleCount = actionCycleCount + 1
                        if actionCycleCount >= 25 then
                            actionCycleCount = 0
                            task.wait(3.5 + math.random() * 3.5)
                        else
                            task.wait(0.65 + (math.random() * 0.25))
                        end
                    end
                                else
                    task.wait(1.0)
                end
            end
        end

        if activeTaskThreads[signature] == coroutine.running() then
            activeTaskThreads[signature] = nil
        end
    end)
end

-- Profile Export/Import Pipeline
local function exportProfileToJSON()
    local exportTable = {}
    for sig, action in pairs(learnedActions) do
        local encodedArgs = {}
        local argsCount = action.args and action.args.n or 0
        for i = 1, argsCount do
            table.insert(encodedArgs, encodeArgument(action.args[i]))
        end
        exportTable[sig] = {
            signature = action.signature,
            name = action.name,
            fullPath = action.fullPath,
            method = action.method,
            category = action.category,
            count = action.count,
            args = encodedArgs,
            argsCount = argsCount,
            cframePos = action.cframe and {action.cframe:GetComponents()} or nil
        }
    end
    
    local success, encoded = pcall(function() return HttpService:JSONEncode(exportTable) end)
    if success and writefile then
        local writeSuccess = pcall(function() writefile(PROFILE_FILENAME, encoded) end)
        if writeSuccess then
            safeCopy(PROFILE_FILENAME, saveDnaBtn, "Saved DNA!")
            return
        end
    end
    safeCopy("Error", saveDnaBtn, "Failed")
end

local redrawAutoTab

local function importProfileFromJSON()
    if not readfile then safeCopy("None", loadDnaBtn, "Import Failed"); return end
    
    local ok, raw = pcall(function() return readfile(PROFILE_FILENAME) end)
    if not ok or not raw then safeCopy("None", loadDnaBtn, "Import Failed"); return end

    local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decodedOk or type(decoded) ~= "table" then safeCopy("None", loadDnaBtn, "Import Failed"); return end

        -- Validate that the profile contains at least one structurally valid entry
    local hasValidEntry = false
    for _, data in pairs(decoded) do
        if type(data) == "table" and type(data.name) == "string" and type(data.fullPath) == "string" and type(data.method) == "string" then
            hasValidEntry = true
            break
        end
    end
    if not hasValidEntry then
        safeCopy("None", loadDnaBtn, "Import Failed")
        return
    end

    -- Replace current state only after the profile has passed basic validation
    for sig, thread in pairs(activeTaskThreads) do pcall(function() task.cancel(thread) end) end
    table.clear(activeTaskThreads)
    table.clear(ActiveSchedulerQueue)
    table.clear(learnedActions)

    for _, cardObj in pairs(actionCards) do
        if cardObj.conn then pcall(function() cardObj.conn:Disconnect() end) end
        if cardObj.card then cardObj.card:Destroy() end
    end
    table.clear(actionCards)

    local loadedEntriesCount = 0

    for sig, data in pairs(decoded) do
        if type(data) == "table" and type(data.name) == "string" and type(data.fullPath) == "string" and type(data.method) == "string" then
            local targetInstance = resolveRemote(data.name, data.fullPath)
            
            -- FIX 4: Clamp fallback argument counts to prevent unbounded arrays
            local rawArgsCount = tonumber(data.argsCount)
            local parsedArgsCount
            if rawArgsCount and rawArgsCount >= 0 then
                parsedArgsCount = math.clamp(math.floor(rawArgsCount), 0, 256)
            else
                local fallbackLength = (type(data.args) == "table" and #data.args or 0)
                parsedArgsCount = math.clamp(fallbackLength, 0, 256)
            end

            local restoredArgs = { n = parsedArgsCount }
            
            if type(data.args) == "table" then
                for i = 1, parsedArgsCount do
                    local encArg = data.args[i]
                    if encArg then
                        local decArg, argValid = decodeArgument(encArg)
                        -- FIX 5: Distinguish valid nil from malformed arguments
                        if argValid then
                            restoredArgs[i] = decArg
                        elseif encArg.type == "nil" then
                            restoredArgs[i] = nil
                        end
                    end
                end
            end

            -- Validated CFrame components
            local resolvedCFrame = nil
            if type(data.cframePos) == "table" and #data.cframePos >= 12 then
                local validCF = true
                for i = 1, 12 do
                    if type(data.cframePos[i]) ~= "number" then validCF = false break end
                end
                if validCF then
                    resolvedCFrame = CFrame.new(table.unpack(data.cframePos, 1, 12))
                end
            end

            local validCount = (type(data.count) == "number" and data.count > 0) and math.clamp(math.floor(data.count), 1, 1000000) or 1
            local validCategories = { MovementAction = true, InstanceAction = true, StructuredAction = true, StringAction = true, GenericAction = true }
            local validCategory = (type(data.category) == "string" and validCategories[data.category]) and data.category or "GenericAction"

            learnedActions[sig] = {
                signature = data.signature or sig,
                name = data.name,
                instance = targetInstance,
                fullPath = data.fullPath,
                method = data.method,
                args = restoredArgs,
                cframe = resolvedCFrame,
                count = validCount,
                category = validCategory,
                isUnavailable = (targetInstance == nil)
            }

            ActiveSchedulerQueue[sig] = {
                enabled = false,
                pausedEnabled = false,
                optInTeleport = false,
                name = data.name,
                fullPath = data.fullPath,
                args = restoredArgs,
                cframe = resolvedCFrame,
                                overrides = {},
                _present = {}
            }
            
            updateTaskScheduler(sig, ActiveSchedulerQueue[sig])
            loadedEntriesCount = loadedEntriesCount + 1
        end
    end

    if loadedEntriesCount > 0 then
        if redrawAutoTab then redrawAutoTab() end
        safeCopy("Loaded", loadDnaBtn, "Loaded (" .. loadedEntriesCount .. ")!")
    else
        safeCopy("None", loadDnaBtn, "Import Failed")
    end
end

-- Precise Movement Classification Engine
local function classifySignature(argsPacked, isMovementRelated)
    if isMovementRelated then return "MovementAction" end

    local count = argsPacked.n or #argsPacked
    for i = 1, count do
        local arg = argsPacked[i]
        local valueType = typeof(arg)
        if valueType == "Instance" then
            return "InstanceAction"
        elseif valueType == "table" then
            return "StructuredAction"
        elseif valueType == "string" then
            return "StringAction"
        end
    end

    return "GenericAction"
end

redrawAutoTab = function()
    local count = 0
    for _ in pairs(learnedActions) do count = count + 1 end
    autoEmptyText.Visible = (count == 0)

    for sig, action in pairs(learnedActions) do
        if not actionCards[sig] then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -8, 0, 52)
            card.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
            card.BorderSizePixel = 0
            card.Parent = autoScroll

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 4)
            cardCorner.Parent = card

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -12, 0, 24)
            label.Position = UDim2.fromOffset(6, 4)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(220, 220, 230)
            label.TextSize = 7
            label.Font = Enum.Font.Code
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextYAlignment = Enum.TextYAlignment.Top
            label.TextWrapped = true
            label.Parent = card

            local openConfigPanelBtn = Instance.new("TextButton")
            openConfigPanelBtn.Size = UDim2.new(1, -12, 0, 18)
            openConfigPanelBtn.Position = UDim2.fromOffset(6, 28)
            openConfigPanelBtn.Text = "⚙ Open Configuration Panel"
            openConfigPanelBtn.TextColor3 = Color3.new(1, 1, 1)
            openConfigPanelBtn.TextSize = 7
            openConfigPanelBtn.Font = Enum.Font.Code
            openConfigPanelBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
            openConfigPanelBtn.BorderSizePixel = 0
            openConfigPanelBtn.Parent = card

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 3)
            btnCorner.Parent = openConfigPanelBtn

            local cardConn = openConfigPanelBtn.MouseButton1Click:Connect(function()
                activeConfigSig = sig
                local currentAction = learnedActions[sig]
                if not currentAction then return end
                panelHeader.Text = string.format("Configuring:\n[%s] (%s)", currentAction.name, currentAction.method)

                local queueData = ActiveSchedulerQueue[sig]
                local isLooping = queueData and queueData.enabled or false
                local isOptInTeleport = queueData and queueData.optInTeleport or false

                if queueData and (queueData.errors or 0) >= 5 then
                    configLoopBtn.Text = "Loop Execution: OFF (MAX ERRORS)"
                    configLoopBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
                else
                    configLoopBtn.Text = isLooping and "Loop Execution: ON" or "Loop Execution: OFF"
                    configLoopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)
                end

                configTeleportOptBtn.Text = isOptInTeleport and "Opt-In Spatial Teleport: ON" or "Opt-In Spatial Teleport: OFF"
                configTeleportOptBtn.BackgroundColor3 = isOptInTeleport and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)

                local argsCount = currentAction.args and currentAction.args.n or 0
                if argsCount > 0 then
                    -- FIX 1: Explicit nil check so false/nil overrides render correctly
                    local currentVal
                                        if queueData and queueData._present and queueData._present[1] then
                        currentVal = queueData.overrides[1]
                    else
                        currentVal = currentAction.args[1]
                    end
                    configArg1Btn.Text = "Arg #1: " .. serializeValue(currentVal)
                    configArg1Btn.Visible = true
                else
                    configArg1Btn.Text = "Arg #1: [No Arguments Captured]"
                    configArg1Btn.Visible = false
                end

                autoContainer.Visible = false
                configSubPanel.Visible = true
            end)

            actionCards[sig] = { card = card, label = label, conn = cardConn }
        end

        local statusTag = action.isUnavailable and " [UNAVAILABLE / BROKEN]" or ""
        actionCards[sig].label.Text = string.format("⚡ [%s] (%s)%s | Type: %s (%dx)\nPath: %s", 
            action.name, action.method, statusTag, action.category, action.count, action.fullPath)
    end

    task.defer(function()
        autoScroll.CanvasSize = UDim2.new(0, autoLayout.AbsoluteContentSize.X + 10, 0, autoLayout.AbsoluteContentSize.Y + 10)
    end)
end

table.insert(activeConnections, configArg1Btn.MouseButton1Click:Connect(function()
    if not activeConfigSig or not learnedActions[activeConfigSig] then return end
    local action = learnedActions[activeConfigSig]
    if not action.args or (action.args.n or 0) == 0 then return end

        if not ActiveSchedulerQueue[activeConfigSig] then
        ActiveSchedulerQueue[activeConfigSig] = { enabled = false, pausedEnabled = false, optInTeleport = false, name = action.name, fullPath = action.fullPath, args = action.args, cframe = action.cframe, overrides = {}, _present = {} }
        updateTaskScheduler(activeConfigSig, ActiveSchedulerQueue[activeConfigSig])
    end

    local queueData = ActiveSchedulerQueue[activeConfigSig]
    queueData.overrides = queueData.overrides or {}
    queueData._present = queueData._present or {}

        local originalVal = action.args[1]
    local currentVal
    if queueData._present[1] then
        currentVal = queueData.overrides[1]
    else
        currentVal = originalVal
    end

        if typeof(originalVal) == "number" then
        queueData.overrides[1] = currentVal + 1
    elseif typeof(originalVal) == "boolean" then
        queueData.overrides[1] = not currentVal
    else
        if currentVal == originalVal then queueData.overrides[1] = tostring(originalVal) .. "_Modified"
        else queueData.overrides[1] = originalVal end
    end
    queueData._present[1] = true

    configArg1Btn.Text = "Arg #1: " .. serializeValue(queueData.overrides[1])
end))

table.insert(activeConnections, configLoopBtn.MouseButton1Click:Connect(function()
    if not activeConfigSig or not learnedActions[activeConfigSig] then return end
    local action = learnedActions[activeConfigSig]
    if action.isUnavailable then return end

    if not ActiveSchedulerQueue[activeConfigSig] then
                    ActiveSchedulerQueue[activeConfigSig] = { enabled = false, pausedEnabled = false, optInTeleport = false, name = action.name, fullPath = action.fullPath, args = action.args, cframe = action.cframe, overrides = {}, _present = {} }
        updateTaskScheduler(activeConfigSig, ActiveSchedulerQueue[activeConfigSig])
    end

    local queueData = ActiveSchedulerQueue[activeConfigSig]
    queueData.enabled = not queueData.enabled
    queueData.pausedEnabled = queueData.enabled
    queueData.errors = 0

    configLoopBtn.Text = queueData.enabled and "Loop Execution: ON" or "Loop Execution: OFF"
    configLoopBtn.BackgroundColor3 = queueData.enabled and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)
end))

table.insert(activeConnections, configTeleportOptBtn.MouseButton1Click:Connect(function()
    if not activeConfigSig then return end
    if not ActiveSchedulerQueue[activeConfigSig] then return end
    local queueData = ActiveSchedulerQueue[activeConfigSig]
    queueData.optInTeleport = not queueData.optInTeleport
    configTeleportOptBtn.Text = queueData.optInTeleport and "Opt-In Spatial Teleport: ON" or "Opt-In Spatial Teleport: OFF"
    configTeleportOptBtn.BackgroundColor3 = queueData.optInTeleport and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)
end))

table.insert(activeConnections, backToListBtn.MouseButton1Click:Connect(function()
    configSubPanel.Visible = false
    autoContainer.Visible = true
end))

-- Learned Remote Pipeline
local function argumentsHaveSameShape(previousArgs, currentArgs)
    if not previousArgs or not currentArgs then return false end
    local previousCount = previousArgs.n or #previousArgs
    local currentCount = currentArgs.n or #currentArgs
    if previousCount ~= currentCount then return false end

    for i = 1, currentCount do
        local previousType = typeof(previousArgs[i])
        local currentType = typeof(currentArgs[i])
        if previousType ~= currentType then return false end
    end
    return true
end

local function processLearnedRemote(self, method, argsPacked, callingScript, currentCFrame, isMovementRelated)
    local fullPath = "game." .. self:GetFullName()
    if shouldIgnoreRemote(fullPath) then return end

    local signature = fullPath .. ":" .. method
    local now = os.clock()
    local category = classifySignature(argsPacked, isMovementRelated)

    if learnedActions[signature] then
                local entry = learnedActions[signature]
        local shapeChanged = not argumentsHaveSameShape(entry.args, argsPacked)
        entry.count = entry.count + 1
        entry.lastSeen = now
        entry.args = argsPacked
        entry.isUnavailable = false
        if shapeChanged and ActiveSchedulerQueue[signature] then
            ActiveSchedulerQueue[signature].overrides = {}
            ActiveSchedulerQueue[signature]._present = {}
        end
        if isMovementRelated and currentCFrame then
            entry.cframe = currentCFrame
            if ActiveSchedulerQueue[signature] then ActiveSchedulerQueue[signature].cframe = currentCFrame end
        end
    else
        learnedActions[signature] = {
            signature = signature,
            name = self.Name,
            instance = self,
            fullPath = fullPath,
            method = method,
            args = argsPacked,
            callingScript = callingScript,
            cframe = isMovementRelated and currentCFrame or nil,
            count = 1,
            firstSeen = now,
            lastSeen = now,
            category = category,
            isUnavailable = false
        }
    end

    if not ActiveSchedulerQueue[signature] then
                ActiveSchedulerQueue[signature] = {
            enabled = false,
            pausedEnabled = false,
            optInTeleport = false,
            name = self.Name,
            fullPath = fullPath,
            args = argsPacked,
            cframe = learnedActions[signature].cframe,
            overrides = {},
            _present = {}
        }
        updateTaskScheduler(signature, ActiveSchedulerQueue[signature])
    else
        ActiveSchedulerQueue[signature].args = argsPacked
    end

    redrawAutoTab()
end

table.insert(activeConnections, clearAutoBtn.MouseButton1Click:Connect(function()
    for sig, thread in pairs(activeTaskThreads) do pcall(function() task.cancel(thread) end) end
    table.clear(activeTaskThreads)
    table.clear(ActiveSchedulerQueue)
    table.clear(learnedActions)

    for _, cardObj in pairs(actionCards) do
        if cardObj.conn then pcall(function() cardObj.conn:Disconnect() end) end
        if cardObj.card then cardObj.card:Destroy() end
    end
    table.clear(actionCards)

    activeConfigSig = nil
    configSubPanel.Visible = false
    autoContainer.Visible = true
    redrawAutoTab()
end))

-- Hook Engine with Redraw Leak Protection
local ignoredRemotes = { ["Heartbeat"] = true, ["Ping"] = true, ["AnalyticsEvent"] = true }
local callCooldowns = {}
local isHookingCall = false

local function redrawLogs()
    for _, conn in ipairs(logConnections) do pcall(function() conn:Disconnect() end) end
    table.clear(logConnections)

    for _, row in ipairs(logRows) do row:Destroy() end
    table.clear(logRows)

    for _, logEntry in ipairs(rawLogs) do
        local rowBtn = Instance.new("TextButton")
        rowBtn.Size = UDim2.new(1, 0, 0, 36)
        rowBtn.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
        rowBtn.BorderSizePixel = 0
        rowBtn.Text = ""
        rowBtn.Parent = spyScroll

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = rowBtn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 1, 0)
        lbl.Position = UDim2.fromOffset(4, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(100, 255, 120)
        lbl.TextSize = 8
        lbl.Font = Enum.Font.Code
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.TextWrapped = true
        lbl.Text = logEntry.text
        lbl.Parent = rowBtn

        local rowConn = rowBtn.MouseButton1Click:Connect(function()
            local lines = {
                string.format("=== INTEL: %s (%s) ===", logEntry.name, logEntry.method),
                string.format("[i] Path: %s", logEntry.fullPath or "Unknown"),
                string.format("[i] Script: %s", logEntry.callingScript and logEntry.callingScript:GetFullName() or "Unknown"),
                "\n[1] Arguments Captured:"
            }
            local count = logEntry.args.n or #logEntry.args
            for i = 1, count do
                local arg = logEntry.args[i]
                table.insert(lines, string.format("  Arg #%d [%s] =\n%s", i, typeof(arg), serializeValue(arg)))
            end
            analyzeOutput.Text = table.concat(lines, "\n")
            switchTab("analyze")
        end)
        table.insert(logConnections, rowConn)
        table.insert(logRows, rowBtn)
    end
end

local function captureLog(self, method, ...)
    if isEngineClosed or _G.IgnoreAutoHooks or isHookingCall then return end
    local fullPath = "game." .. self:GetFullName()
    if shouldIgnoreRemote(fullPath) then return end

    local now = os.clock()
    if callCooldowns[self] and (now - callCooldowns[self]) < 0.05 then return end
    callCooldowns[self] = now

    isHookingCall = true
    xpcall(function(...)
        local argsPacked = table.pack(...)
        local callingScript = getcallingscript and getcallingscript() or nil
        local currentCFrame = nil
        local isMovementRelated = false

        -- Precise Movement Heuristics: Explicit patterns prevent false positives
        local lowName = string.lower(self.Name)
        if string.match(lowName, "^move_") or string.match(lowName, "_pos$") or string.match(lowName, "^teleport") or string.match(lowName, "updateposition") or string.match(lowName, "walkto") then
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                isMovementRelated = true
                currentCFrame = player.Character.HumanoidRootPart.CFrame
            end
        end

        processLearnedRemote(self, method, argsPacked, callingScript, currentCFrame, isMovementRelated)

        local serializedArgs = {}
        for i = 1, argsPacked.n do
            table.insert(serializedArgs, serializeValue(argsPacked[i]))
        end

        local snippet = string.format("%s:%s(%s)", fullPath, method, table.concat(serializedArgs, ", "))
        local entryText = string.format("[%s] (%s)\n%s", self.Name, method, snippet)

        local logObj = { 
            text = entryText, 
            snippet = snippet, 
            name = self.Name, 
            method = method, 
            args = argsPacked, 
            fullPath = fullPath, 
            callingScript = callingScript, 
            cframe = currentCFrame 
        }
        table.insert(rawLogs, logObj)
        if #rawLogs > 15 then table.remove(rawLogs, 1) end
        redrawLogs()
    end, function(e)
        warn("Aetherius Core Log Capture Error:", e)
    end, ...)
    isHookingCall = false
end

-- Isolated Metamethod Hook Installation
if hookmetamethod and newcclosure then
    local success, err = pcall(function()
        originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if not isEngineClosed and not isHookingCall and typeof(self) == "Instance" and not ignoredRemotes[self.Name] then
                local method = getnamecallmethod()
                if (method == "FireServer" or method == "InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                    captureLog(self, method, ...)
                end
            end
            return originalNamecall(self, ...)
        end))
        if not _G._AetheriusOriginalNamecall_v6 then
            _G._AetheriusOriginalNamecall_v6 = originalNamecall
        end
    end)
    if not success then
        hookStatusMessage = "[!] Warning: Hook engine installation failed (" .. tostring(err) .. ")"
        warn(hookStatusMessage)
    end
else
    hookStatusMessage = "[!] Warning: hookmetamethod/newcclosure unsupported in current environment."
    warn(hookStatusMessage)
end

-- Event Listeners & Drag Engine
table.insert(activeConnections, clearBtn.MouseButton1Click:Connect(function() table.clear(rawLogs) redrawLogs() end))
table.insert(activeConnections, exportBtn.MouseButton1Click:Connect(function()
    if #rawLogs == 0 then return end
    local snippets = {}
    for _, log in ipairs(rawLogs) do table.insert(snippets, log.snippet) end
    safeCopy(table.concat(snippets, "\n"), exportBtn, "Copied!")
end))

table.insert(activeConnections, recordMacroBtn.MouseButton1Click:Connect(function() safeCopy("Inactive", recordMacroBtn, "Inactive") end))
table.insert(activeConnections, copyMacroBtn.MouseButton1Click:Connect(function() safeCopy("-- Placeholder Macro Buffer", copyMacroBtn, "Copied") end))
table.insert(activeConnections, clearMacroBtn.MouseButton1Click:Connect(function() macroOutput.Text = "[STATUS]: Macro Recorder Engine - INACTIVE (Placeholder UI)\n" end))
table.insert(activeConnections, genFuncBtn.MouseButton1Click:Connect(function() safeCopy("-- Placeholder Analysis Output", genFuncBtn, "Copied") end))
table.insert(activeConnections, clearMonitorBtn.MouseButton1Click:Connect(function() monitorOutput.Text = "[STATUS]: Attribute Monitor - INACTIVE (Placeholder UI)\n\n" end))
table.insert(activeConnections, saveDnaBtn.MouseButton1Click:Connect(exportProfileToJSON))
table.insert(activeConnections, loadDnaBtn.MouseButton1Click:Connect(importProfileFromJSON))

local dragging, dragStart, startPos
table.insert(activeConnections, bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end))

table.insert(activeConnections, UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

table.insert(activeConnections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))
