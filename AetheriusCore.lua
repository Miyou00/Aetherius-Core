local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- Global Hook Bypass Switch
_G.IgnoreAutoHooks = false

-- Profile Configuration
local PROFILE_FILENAME = "AetheriusCore_Profile_" .. game.PlaceId .. ".json"

-- Cleanup existing GUI instances safely
pcall(function()
    local old = player.PlayerGui:FindFirstChild("AetheriusCoreEngine")
    if old then old:Destroy() end
end)

-- Core GUI Window Construction (Compact 364x280)
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
title.Size = UDim2.new(1, -35, 1, 0)
title.Position = UDim2.fromOffset(6, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ Aetherius Core [v5.0 - Dedicated Panel Mode]"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.TextSize = 8
title.Font = Enum.Font.Code
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

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

-- Forward declare hook variable for safe cleanup
local originalNamecall
local SchedulerRunning = false

-- Guaranteed Close Binding (Registered instantly)
closeBtn.MouseButton1Click:Connect(function()
    SchedulerRunning = false
    pcall(function()
        if originalNamecall and hookmetamethod then
            hookmetamethod(game, "__namecall", originalNamecall)
        end
    end)
    gui:Destroy()
end)

-- Navigation Tab Buttons
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

-- Dynamic Container Engine
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
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    return container, scroll, footer, layout
end

local spyContainer, scroll, spyFooter = createContainer()
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

-- Dedicated Script Configuration Sub-Panel (Standalone window pane)
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
panelHeader.Text = "Config Panel: Select a script to configure."
panelHeader.Parent = configSubPanel

local configTargetBtn = Instance.new("TextButton")
configTargetBtn.Size = UDim2.new(1, -12, 0, 26)
configTargetBtn.Position = UDim2.fromOffset(6, 50)
configTargetBtn.Text = "Arg 1 Target: [Default / Scanned]"
configTargetBtn.TextColor3 = Color3.new(1, 1, 1)
configTargetBtn.TextSize = 7
configTargetBtn.Font = Enum.Font.Code
configTargetBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
configTargetBtn.BorderSizePixel = 0
configTargetBtn.Parent = configSubPanel

local tCorner = Instance.new("UICorner")
tCorner.CornerRadius = UDim.new(0, 4)
tCorner.Parent = configTargetBtn

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

local backToListBtn = Instance.new("TextButton")
backToListBtn.Size = UDim2.new(1, -12, 0, 26)
backToListBtn.Position = UDim2.fromOffset(6, 118)
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
    out.TextWrapped = false
    out.Parent = parent
    return out
end

local output = createOutput(scroll, Color3.fromRGB(100, 255, 120))
output.Text = "Spy active (Cognitive Engine Mode). Tap logs to inspect.\n\n"

local macroOutput = createOutput(macroScroll, Color3.fromRGB(255, 180, 100))
macroOutput.Text = "Macro Recorder Standby.\n\n"

local analyzeOutput = createOutput(analyzeScroll, Color3.fromRGB(200, 150, 255))
analyzeOutput.Text = "Select a log from Spy to inspect.\n\n"

local dumpOutput = createOutput(dumpScroll, Color3.fromRGB(255, 200, 80))
dumpOutput.Text = "Scanning GC memory...\n"

local decompOutput = createOutput(decompScroll, Color3.fromRGB(100, 200, 255))
decompOutput.Text = "Mapping modules...\n"

local monitorOutput = createOutput(monitorScroll, Color3.fromRGB(255, 140, 100))
monitorOutput.Text = "World & Attribute Monitor active.\n\n"

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

local function safeCopy(str, button, successMsg)
    if setclipboard then
        local ok = pcall(setclipboard, str)
        if ok then
            local origText = button.Text
            button.Text = successMsg or "Copied!"
            task.delay(2, function()
                if button.Parent then button.Text = origText end
            end)
            return
        end
    end
    local origText = button.Text
    button.Text = "Error"
    task.delay(2, function()
        if button.Parent then button.Text = origText end
    end)
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

tabSpyBtn.MouseButton1Click:Connect(function() switchTab("spy") end)
tabMacroBtn.MouseButton1Click:Connect(function() switchTab("macro") end)
tabAnalyzeBtn.MouseButton1Click:Connect(function() switchTab("analyze") end)
tabDumpBtn.MouseButton1Click:Connect(function() switchTab("dump") end)
tabDecompBtn.MouseButton1Click:Connect(function() switchTab("decomp") end)
tabMonitorBtn.MouseButton1Click:Connect(function() switchTab("monitor") end)
tabAutoBtn.MouseButton1Click:Connect(function() switchTab("auto") end)

-- Non-blocking Background Client Data Scanner
local availableClientConfigs = {"DefaultItem", "CommonEgg", "RareEgg", "EpicEgg", "LegendaryEgg"}
task.spawn(function()
    pcall(function()
        local scannedOptions = {}
        for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
            if child:IsA("ModuleScript") then
                local ok, data = pcall(require, child)
                if ok and type(data) == "table" then
                    for k, v in pairs(data) do
                        if type(k) == "string" and (type(v) == "table" or type(v) == "string") then
                            table.insert(scannedOptions, k)
                        end
                    end
                end
            end
        end
        if #scannedOptions > 0 then
            availableClientConfigs = scannedOptions
        end
    end)
end)

-- Core Functions
local function resolveRemote(remoteName, fallbackPath)
    local found = ReplicatedStorage:FindFirstChild(remoteName, true) 
        or workspace:FindFirstChild(remoteName, true)
        or game:FindFirstChild(remoteName, true)
        
    if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction")) then
        return found
    end
    
    local success, instance = pcall(function()
        return loadstring("return " .. fallbackPath)()
    end)
    if success and instance then return instance end
    return nil
end

local function sanitizeArguments(args, customOverrides)
    if not customOverrides or next(customOverrides) == nil then
        return args
    end
    local sanitized = {}
    for i, arg in ipairs(args) do
        if customOverrides and customOverrides[i] then
            table.insert(sanitized, customOverrides[i])
        elseif type(arg) == "table" then
            local newTable = {}
            for k, v in pairs(arg) do
                if string.match(string.lower(tostring(k)), "token") 
                    or string.match(string.lower(tostring(k)), "nonce") 
                    or string.match(string.lower(tostring(k)), "time") then
                    newTable[k] = tick()
                else
                    newTable[k] = v
                end
            end
            table.insert(sanitized, newTable)
        else
            table.insert(sanitized, arg)
        end
    end
    return sanitized
end

local learnedActions = {}
local actionCards = {}
local ActiveSchedulerQueue = {}
local activeConfigSig = nil

local ignoredRemotePatterns = { "Analytics", "ClientKit", "Telemetry", "Fps", "Ping", "Heartbeat" }

local function shouldIgnoreRemote(remotePath)
    for _, pattern in ipairs(ignoredRemotePatterns) do
        if string.find(remotePath, pattern) then return true end
    end
    return false
end

local function serializeValue(val, depth)
    depth = depth or 0
    if depth > 3 then return "{... Max Depth}" end
    local t = typeof(val)
    if t == "string" then 
        return string.format("%q", val)
    elseif t == "Instance" then
        return val:GetFullName()
    elseif t == "Vector3" then
        return string.format("Vector3.new(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        return string.format("CFrame.new(%.2f, %.2f, %.2f)", val.Position.X, val.Position.Y, val.Position.Z)
    elseif t == "number" then
        if val > 1600000000 and val < 2000000000 then return "tick()" end
        return tostring(val)
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 20 then table.insert(parts, "...and more") break end
            table.insert(parts, string.format("[%s] = %s", tostring(k), serializeValue(v, depth + 1)))
        end
        return "{\n" .. string.rep("  ", depth + 1) .. table.concat(parts, ",\n" .. string.rep("  ", depth + 1)) .. "\n" .. string.rep("  ", depth) .. "}"
    else 
        return tostring(val) 
    end
end

local function classifySignature(args)
    if #args == 0 then return "SignalTrigger" end
    local primaryArg = args[1]
    local argType = typeof(primaryArg)
    if argType == "string" then
        return "CommandOrInventory"
    elseif argType == "number" then
        return "ResourceTransaction"
    elseif argType == "table" then
        if type(primaryArg) == "table" then return "StructuredPayload" end
    elseif argType == "Instance" then
        return "TargetInteraction"
    end
    return "GenericAction"
end

-- Centralized Scheduler
local function startCentralizedScheduler()
    if SchedulerRunning then return end
    SchedulerRunning = true

    task.spawn(function()
        local actionCycleCount = 0
        while SchedulerRunning do
            for signature, taskData in pairs(ActiveSchedulerQueue) do
                if not SchedulerRunning then break end
                if taskData.enabled then
                    local remoteInst = resolveRemote(taskData.name, taskData.fullPath)
                    if remoteInst then
                        local shouldSkip = false
                        if taskData.filterRule and taskData.filterRule.enabled then
                            local val = taskData.overrides and taskData.overrides[taskData.filterRule.argIndex] or taskData.args[taskData.filterRule.argIndex]
                            if val and tostring(val) ~= taskData.filterRule.targetVal then
                                shouldSkip = true
                            end
                        end

                        if not shouldSkip then
                            local char = player.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if taskData.cframe and hrp then
                                local targetCF = typeof(taskData.cframe) == "CFrame" and taskData.cframe or CFrame.new()
                                if (hrp.Position - targetCF.Position).Magnitude > 8 then
                                    hrp.CFrame = targetCF
                                    task.wait(0.05)
                                end
                            end

                            _G.IgnoreAutoHooks = true
                            local liveArgs = sanitizeArguments(taskData.args, taskData.overrides)
                            local ok = pcall(function()
                                if remoteInst:IsA("RemoteEvent") then
                                    remoteInst:FireServer(table.unpack(liveArgs))
                                elseif remoteInst:IsA("RemoteFunction") then
                                    remoteInst:InvokeServer(table.unpack(liveArgs))
                                end
                            end)
                            _G.IgnoreAutoHooks = false

                            if not ok then
                                taskData.errors = (taskData.errors or 0) + 1
                                task.wait(math.min(6.0, 0.65 * (2 ^ taskData.errors)))
                            else
                                taskData.errors = 0
                                actionCycleCount = actionCycleCount + 1
                                
                                if actionCycleCount >= 25 then
                                    actionCycleCount = 0
                                    task.wait(math.random(3.5, 7.0))
                                else
                                    local jitter = math.random() * 0.25 + (math.random() * 0.1)
                                    task.wait(0.65 + jitter)
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)
end
startCentralizedScheduler()

-- JSON Profile Serialization
local function exportProfileToJSON()
    local exportTable = {}
    for sig, action in pairs(learnedActions) do
        exportTable[sig] = {
            signature = action.signature,
            name = action.name,
            fullPath = action.fullPath,
            method = action.method,
            category = action.category,
            count = action.count,
            cframePos = action.cframe and {action.cframe.Position.X, action.cframe.Position.Y, action.cframe.Position.Z} or nil
        }
    end
    local success, encoded = pcall(function() return HttpService:JSONEncode(exportTable) end)
    if success and writefile then
        writefile(PROFILE_FILENAME, encoded)
        safeCopy(PROFILE_FILENAME, saveDnaBtn, "Saved DNA!")
    else
        safeCopy("Error", saveDnaBtn, "Failed")
    end
end

local redrawAutoTab -- Forward declaration

local function importProfileFromJSON()
    if readfile then
        local ok, raw = pcall(function() return readfile(PROFILE_FILENAME) end)
        if ok and raw then
            local decodedOk, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if decodedOk and type(decoded) == "table" then
                for sig, data in pairs(decoded) do
                    local targetInstance = resolveRemote(data.name, data.fullPath)
                    
                    learnedActions[sig] = {
                        signature = data.signature,
                        name = data.name,
                        instance = targetInstance,
                        fullPath = data.fullPath,
                        method = data.method,
                        args = {},
                        cframe = data.cframePos and CFrame.new(table.unpack(data.cframePos)) or nil,
                        count = data.count,
                        category = data.category
                    }
                end
                if redrawAutoTab then redrawAutoTab() end
                safeCopy("Loaded", loadDnaBtn, "Loaded DNA!")
                return
            end
        end
    end
    safeCopy("None", loadDnaBtn, "No Profile")
end

function redrawAutoTab()
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

            -- Button that opens the separate Configuration Panel for this script
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

            openConfigPanelBtn.MouseButton1Click:Connect(function()
                activeConfigSig = sig
                panelHeader.Text = string.format("Configuring:\n[%s] (%s)", action.name, action.method)
                
                -- Sync values to sub-panel controls
                local queueData = ActiveSchedulerQueue[sig]
                local isLooping = queueData and queueData.enabled or false
                configLoopBtn.Text = isLooping and "Loop Execution: ON" or "Loop Execution: OFF"
                configLoopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)

                autoContainer.Visible = false
                configSubPanel.Visible = true
            end)

            actionCards[sig] = { card = card, label = label }
        end

        actionCards[sig].label.Text = string.format("⚡ [%s] (%s) | Type: %s (%dx)\nPath: %s", 
            action.name, action.method, action.category, action.count, action.fullPath)
    end

    task.defer(function()
        autoScroll.CanvasSize = UDim2.new(0, autoLayout.AbsoluteContentSize.X + 10, 0, autoLayout.AbsoluteContentSize.Y + 10)
    end)
end

-- Sub-panel interactive controls logic
local configIndex = 1
configTargetBtn.MouseButton1Click:Connect(function()
    if not activeConfigSig or not learnedActions[activeConfigSig] then return end
    configIndex = (configIndex % #availableClientConfigs) + 1
    local selectedVal = availableClientConfigs[configIndex]
    configTargetBtn.Text = "Arg 1 Target: " .. tostring(selectedVal)
    
    local action = learnedActions[activeConfigSig]
    if not ActiveSchedulerQueue[activeConfigSig] then
        ActiveSchedulerQueue[activeConfigSig] = { enabled = false, name = action.name, fullPath = action.fullPath, args = action.args, cframe = action.cframe, overrides = {} }
    end
    ActiveSchedulerQueue[activeConfigSig].overrides = ActiveSchedulerQueue[activeConfigSig].overrides or {}
    ActiveSchedulerQueue[activeConfigSig].overrides[1] = selectedVal
end)

configLoopBtn.MouseButton1Click:Connect(function()
    if not activeConfigSig or not learnedActions[activeConfigSig] then return end
    local action = learnedActions[activeConfigSig]
    
    if not ActiveSchedulerQueue[activeConfigSig] then
        ActiveSchedulerQueue[activeConfigSig] = { enabled = false, name = action.name, fullPath = action.fullPath, args = action.args, cframe = action.cframe, overrides = {} }
    end
    
    local queueData = ActiveSchedulerQueue[activeConfigSig]
    queueData.enabled = not queueData.enabled
    
    configLoopBtn.Text = queueData.enabled and "Loop Execution: ON" or "Loop Execution: OFF"
    configLoopBtn.BackgroundColor3 = queueData.enabled and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)
end)

backToListBtn.MouseButton1Click:Connect(function()
    configSubPanel.Visible = false
    autoContainer.Visible = true
end)

local function processLearnedRemote(self, method, args, callingScript, currentCFrame)
    local fullPath = "game." .. self:GetFullName()
    if shouldIgnoreRemote(fullPath) then return end

    local signature = fullPath .. ":" .. method
    local now = tick()
    local category = classifySignature(args)
    if currentCFrame then category = "SpatialStateSequence" end

    if learnedActions[signature] then
        local entry = learnedActions[signature]
        entry.count = entry.count + 1
        entry.lastSeen = now
        entry.args = args
        if currentCFrame then entry.cframe = currentCFrame end
    else
        learnedActions[signature] = {
            signature = signature,
            name = self.Name,
            instance = self,
            fullPath = fullPath,
            method = method,
            args = args,
            callingScript = callingScript,
            cframe = currentCFrame,
            count = 1,
            firstSeen = now,
            lastSeen = now,
            category = category
        }
    end
    redrawAutoTab()
end

saveDnaBtn.MouseButton1Click:Connect(exportProfileToJSON)
loadDnaBtn.MouseButton1Click:Connect(importProfileFromJSON)

clearAutoBtn.MouseButton1Click:Connect(function()
    ActiveSchedulerQueue = {}
    learnedActions = {}
    for _, cardObj in pairs(actionCards) do cardObj.card:Destroy() end
    actionCards = {}
    configSubPanel.Visible = false
    autoContainer.Visible = true
    redrawAutoTab()
end)

-- Hook Engine
local rawLogs = {}
local ignoredRemotes = { ["Heartbeat"] = true, ["Ping"] = true, ["AnalyticsEvent"] = true }
local callCooldowns = {}
local isHookingCall = false

local function redrawLogs()
    local filteredDisplay = {}
    for _, entry in ipairs(rawLogs) do table.insert(filteredDisplay, entry.text) end
    output.Text = table.concat(filteredDisplay, "\n\n--------------------\n\n")
end

local function captureLog(self, method, args)
    if _G.IgnoreAutoHooks then return end
    local fullPath = "game." .. self:GetFullName()
    if shouldIgnoreRemote(fullPath) then return end

    local now = tick()
    if callCooldowns[self] and (now - callCooldowns[self]) < 0.05 then return end
    callCooldowns[self] = now

    local callingScript = getcallingscript and getcallingscript() or nil
    local currentCFrame = nil
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local pos = player.Character.HumanoidRootPart.Position
        currentCFrame = CFrame.new(pos)
    end

    processLearnedRemote(self, method, args, callingScript, currentCFrame)

    local serializedArgs = {}
    for _, arg in ipairs(args) do table.insert(serializedArgs, serializeValue(arg)) end
    
    local snippet = string.format("%s:%s(%s)", fullPath, method, table.concat(serializedArgs, ", "))
    local entryText = string.format("[%s] (%s) (Tap to Inspect)\n%s", self.Name, method, snippet)
    
    table.insert(rawLogs, { text = entryText, snippet = snippet, name = self.Name, method = method, args = args, fullPath = fullPath, callingScript = callingScript, cframe = currentCFrame })
    if #rawLogs > 15 then table.remove(rawLogs, 1) end
    redrawLogs()
end

if hookmetamethod and newcclosure then
    pcall(function()
        originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if not isHookingCall and typeof(self) == "Instance" and not ignoredRemotes[self.Name] then
                local method = getnamecallmethod()
                if (method == "FireServer" or method == "InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                    isHookingCall = true
                    captureLog(self, method, {...})
                    isHookingCall = false
                end
            end
            return originalNamecall(self, ...)
        end))
    end)
end

output.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if #rawLogs > 0 then
            local logEntry = rawLogs[#rawLogs]
            local lines = {
                string.format("=== INTEL: %s (%s) ===", logEntry.name, logEntry.method),
                string.format("[i] Path: %s", logEntry.fullPath or "Unknown"),
                string.format("[i] Script: %s", logEntry.callingScript and logEntry.callingScript:GetFullName() or "Unknown"),
                "\n[1] Arguments Captured:"
            }
            for i, arg in ipairs(logEntry.args) do
                table.insert(lines, string.format("  Arg #%d [%s] =\n%s", i, typeof(arg), serializeValue(arg)))
            end
            analyzeOutput.Text = table.concat(lines, "\n")
            switchTab("analyze")
        end
    end
end)

clearBtn.MouseButton1Click:Connect(function() rawLogs = {} redrawLogs() end)
exportBtn.MouseButton1Click:Connect(function()
    if #rawLogs == 0 then return end
    local snippets = {}
    for _, log in ipairs(rawLogs) do table.insert(snippets, log.snippet) end
    safeCopy(table.concat(snippets, "\n"), exportBtn, "Copied!")
end)

-- Window Dragging
local dragging, dragStart, startPos
bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
