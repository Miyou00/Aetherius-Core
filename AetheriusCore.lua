local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- Global Hook Bypass Switch
_G.IgnoreAutoHooks = false

-- Profile Configuration
local PROFILE_FILENAME = "BigFroot_AutoProfile_" .. game.PlaceId .. ".json"

-- Cleanup existing GUI instances
pcall(function()
    local old = player.PlayerGui:FindFirstChild("BigFrootIntelSuitev48")
    if old then old:Destroy() end
end)

-- Core GUI Window Construction (Compact 364x259)
local gui = Instance.new("ScreenGui")
gui.Name = "BigFrootIntelSuitev48"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(364, 259)
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
title.Text = "⚡ BigFroot Intel Suite [v4.8+ Hardened Engine]"
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
local tabAutoBtn = createTab("DNA/Auto", 304, 54)

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
output.Text = "Spy active (Hardened Metamorphic Mode). Tap logs to inspect.\n\n"

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
autoEmptyText.Text = "[HARDENED ENGINE ACTIVE]\nTrigger actions to self-build behavior DNA..."

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

-- Hardened Core Functions: Dynamic Resolution & Sanitization
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

local function sanitizeArguments(args)
    local sanitized = {}
    for _, arg in ipairs(args) do
        if type(arg) == "table" then
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

-- Metamorphic State & Heuristic Database
local learnedActions = {}
local actionCards = {}
local ActiveSchedulerQueue = {}
local SchedulerRunning = false

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

-- Centralized CPU-Optimized Scheduler Engine with Jitter & Micro-Breaks
local function startCentralizedScheduler()
    if SchedulerRunning then return end
    SchedulerRunning = true

    task.spawn(function()
        local actionCycleCount = 0
        while SchedulerRunning do
            for signature, taskData in pairs(ActiveSchedulerQueue) do
                if taskData.enabled then
                    local remoteInst = resolveRemote(taskData.name, taskData.fullPath)
                    if remoteInst then
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if taskData.cframe and hrp then
                            if (hrp.Position - taskData.cframe.Position).Magnitude > 8 then
                                hrp.CFrame = taskData.cframe
                                task.wait(0.05)
                            end
                        end

                        _G.IgnoreAutoHooks = true
                        local liveArgs = sanitizeArguments(taskData.args)
                        local ok = pcall(function()
                            if remoteInst:IsA("RemoteEvent") then
                                remoteInst:FireServer(unpack(liveArgs))
                            elseif remoteInst:IsA("RemoteFunction") then
                                remoteInst:InvokeServer(unpack(liveArgs))
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
                                task.wait(math.random(3.5, 7.0)) -- Simulated AFK / Inventory look
                            else
                                local jitter = math.random() * 0.25 + (math.random() * 0.1)
                                task.wait(0.65 + jitter)
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

-- JSON Profile Serialization Management
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

local function importProfileFromJSON()
    if readfile and listfiles then
        local found = false
        for _, file in ipairs(listfiles("")) do
            if file:match(PROFILE_FILENAME) then found = true break end
        end
        if found then
            local ok, raw = pcall(function() return readfile(PROFILE_FILENAME) end)
            if ok then
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
                            cframe = data.cframePos and CFrame.new(unpack(data.cframePos)) or nil,
                            count = data.count,
                            category = data.category
                        }
                    end
                    redrawAutoTab()
                    safeCopy("Loaded", loadDnaBtn, "Loaded DNA!")
                    return
                end
            end
        end
    end
    safeCopy("None", loadDnaBtn, "No Profile")
end

-- Standalone Hardened State Script Generator
local function generateStateScript(actionData)
    local serializedArgs = {}
    for _, arg in ipairs(actionData.args) do table.insert(serializedArgs, serializeValue(arg)) end
    local argStr = table.concat(serializedArgs, ", ")

    return string.format([[
-- ====================================================
-- HARDENED METAMORPHIC RUNNER SCRIPT
-- ====================================================
-- Category : %s
-- Remote   : %s
-- ====================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local function resolveRemote(remoteName, fallbackPath)
    local found = ReplicatedStorage:FindFirstChild(remoteName, true) 
        or workspace:FindFirstChild(remoteName, true)
        or game:FindFirstChild(remoteName, true)
    if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction")) then return found end
    local ok, inst = pcall(function() return loadstring("return " .. fallbackPath)() end)
    return ok and inst or nil
end

local function sanitizeArguments(args)
    local sanitized = {}
    for _, arg in ipairs(args) do
        if type(arg) == "table" then
            local newTable = {}
            for k, v in pairs(arg) do
                if string.match(string.lower(tostring(k)), "token") or string.match(string.lower(tostring(k)), "nonce") or string.match(string.lower(tostring(k)), "time") then
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

_G.IgnoreAutoHooks = true

task.spawn(function()
    local errors = 0
    while true do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local remoteInst = resolveRemote(%q, %q)
        
        if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and remoteInst then
            %s
            local liveArgs = sanitizeArguments({%s})
            local success = pcall(function()
                if remoteInst:IsA("RemoteEvent") then
                    remoteInst:FireServer(unpack(liveArgs))
                elseif remoteInst:IsA("RemoteFunction") then
                    remoteInst:InvokeServer(unpack(liveArgs))
                end
            end)
            
            if not success then
                errors = errors + 1
                task.wait(math.min(6.0, 0.65 * (2 ^ errors)))
            else
                errors = 0
                task.wait(0.65 + math.random() * 0.25)
            end
        else
            task.wait(1.0)
        end
    end
end)
]], actionData.category, actionData.name, actionData.name, actionData.fullPath, 
    actionData.cframe and string.format([[local targetCF = CFrame.new(%f, %f, %f)
            if hrp and (hrp.Position - targetCF.Position).Magnitude > 8 then
                hrp.CFrame = targetCF
                task.wait(0.05)
            end]], actionData.cframe.Position.X, actionData.cframe.Position.Y, actionData.cframe.Position.Z) or "", 
    argStr)
end

local function previewWaypoint(cframe)
    if not cframe then return end
    pcall(function()
        local marker = Instance.new("Part")
        marker.Size = Vector3.new(2, 4, 2)
        marker.Position = cframe.Position + Vector3.new(0, 2, 0)
        marker.Anchored = true
        marker.CanCollide = false
        marker.Transparency = 0.4
        marker.Color = Color3.fromRGB(100, 255, 150)
        marker.Material = Enum.Material.Neon
        marker.Parent = workspace
        task.delay(3, function() if marker then marker:Destroy() end end)
    end)
end

function redrawAutoTab()
    local count = 0
    for _ in pairs(learnedActions) do count = count + 1 end
    autoEmptyText.Visible = (count == 0)

    for sig, action in pairs(learnedActions) do
        if not actionCards[sig] then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -8, 0, 54)
            card.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
            card.BorderSizePixel = 0
            card.Parent = autoScroll

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 4)
            cardCorner.Parent = card

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -125, 1, -4)
            label.Position = UDim2.fromOffset(4, 2)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(220, 220, 230)
            label.TextSize = 7
            label.Font = Enum.Font.Code
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextYAlignment = Enum.TextYAlignment.Top
            label.TextWrapped = true
            label.Parent = card

            local copyBtn = Instance.new("TextButton")
            copyBtn.Size = UDim2.fromOffset(55, 16)
            copyBtn.Position = UDim2.new(1, -59, 0, 4)
            copyBtn.Text = "State Script"
            copyBtn.TextColor3 = Color3.new(1, 1, 1)
            copyBtn.TextSize = 6
            copyBtn.Font = Enum.Font.Code
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 120)
            copyBtn.BorderSizePixel = 0
            copyBtn.Parent = card

            local copyCorner = Instance.new("UICorner")
            copyCorner.CornerRadius = UDim.new(0, 3)
            copyCorner.Parent = copyBtn

            local loopBtn = Instance.new("TextButton")
            loopBtn.Size = UDim2.fromOffset(55, 16)
            loopBtn.Position = UDim2.new(1, -59, 0, 22)
            loopBtn.Text = "Loop: OFF"
            loopBtn.TextColor3 = Color3.new(1, 1, 1)
            loopBtn.TextSize = 6
            loopBtn.Font = Enum.Font.Code
            loopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            loopBtn.BorderSizePixel = 0
            loopBtn.Parent = card

            local loopCorner = Instance.new("UICorner")
            loopCorner.CornerRadius = UDim.new(0, 3)
            loopCorner.Parent = loopBtn

            local previewBtn = Instance.new("TextButton")
            previewBtn.Size = UDim2.fromOffset(55, 12)
            previewBtn.Position = UDim2.new(1, -59, 0, 40)
            previewBtn.Text = action.cframe and "Preview" or "No Pos"
            previewBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
            previewBtn.TextSize = 6
            previewBtn.Font = Enum.Font.Code
            previewBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
            previewBtn.BorderSizePixel = 0
            previewBtn.Parent = card

            local previewCorner = Instance.new("UICorner")
            previewCorner.CornerRadius = UDim.new(0, 2)
            previewCorner.Parent = previewBtn

            local isLooping = false

            copyBtn.MouseButton1Click:Connect(function()
                safeCopy(generateStateScript(action), copyBtn, "Copied!")
            end)

            previewBtn.MouseButton1Click:Connect(function()
                if action.cframe then previewWaypoint(action.cframe) end
            end)

            loopBtn.MouseButton1Click:Connect(function()
                isLooping = not isLooping
                loopBtn.Text = isLooping and "Loop: ON" or "Loop: OFF"
                loopBtn.BackgroundColor3 = isLooping and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(60, 60, 70)

                ActiveSchedulerQueue[sig] = {
                    enabled = isLooping,
                    name = action.name,
                    fullPath = action.fullPath,
                    args = action.args,
                    cframe = action.cframe,
                    errors = 0
                }
            end)

            actionCards[sig] = { card = card, label = label }
        end

        actionCards[sig].label.Text = string.format("⚡ [%s] (%s)\nType: %s (%dx Calls)\nPath: %s", 
            action.name, action.method, action.category, action.count, action.fullPath)
    end

    task.defer(function()
        autoScroll.CanvasSize = UDim2.new(0, autoLayout.AbsoluteContentSize.X + 10, 0, autoLayout.AbsoluteContentSize.Y + 10)
    end)
end

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
    redrawAutoTab()
end)

-- Hook Engine
local rawLogs = {}
local macroSequence = {}
local isRecordingMacro = false
local lastMacroTime = 0
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

-- Metatable Hooking Engine with Cloaking
local originalNamecall
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

-- Window Dragging & Cleanup
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

closeBtn.MouseButton1Click:Connect(function()
    SchedulerRunning = false
    if originalNamecall and hookmetamethod then
        pcall(function() hookmetamethod(game, "__namecall", originalNamecall) end)
    end
    gui:Destroy()
end)
