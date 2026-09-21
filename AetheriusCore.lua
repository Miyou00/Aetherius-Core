-- =====================================================================
-- ADVANCED TELEMETRY & REVERSE-ENGINEERING ENGINE (v4.9 UI-SYNCHRONIZED)
-- =====================================================================

local rawGame = game
local rawGetService = rawGame.GetService
local function getServiceCloned(serviceName)
    local success, service = pcall(function()
        local s = rawGetService(rawGame, serviceName)
        if cloneref then
            return cloneref(s)
        end
        return s
    end)
    return success and service or nil
end

local _math = math
local _floor = _math.floor
local _random = _math.random
local _tinsert = table.insert
local _tpack = table.pack
local _pcall = pcall
local _tick = tick
local _osclock = os.clock

local HttpService = getServiceCloned("HttpService") or game:GetService("HttpService")
local Players = getServiceCloned("Players") or game:GetService("Players")
local CoreGui = getServiceCloned("CoreGui") or game:GetService("CoreGui")
local Workspace = getServiceCloned("Workspace") or game:GetService("Workspace")
local ReplicatedStorage = getServiceCloned("ReplicatedStorage") or game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

-- Global Environment Cleanup
local runtimeEnv = (getgenv and getgenv()) or _G
local panelName = "TelemetryEnterpriseProduction"

local function findExistingPanel()
    local found
    _pcall(function()
        local target = (gethui and gethui()) or CoreGui
        found = target:FindFirstChild(panelName)
    end)
    return found
end

local existingPanel = runtimeEnv.TelemetryProductionScreenGui or findExistingPanel()
if existingPanel and existingPanel.Parent then
    warn("[Telemetry Engine] An instance is already running.")
    return
end

runtimeEnv.TelemetryProductionRunning = true
runtimeEnv.TelemetryProductionScreenGui = nil

-- Limits & Configuration
local SESSION_FOLDER = "GameTelemetryLogs"
local SESSION_FILE = SESSION_FOLDER .. "/game_analysis_" .. _floor(_tick()) .. "_" .. _random(1000, 9999) .. ".json"
local eventBuffer = {}
local BUFFER_FLUSH_COUNT = 20
local MAX_EVENT_STRING_LENGTH = 1024
local MAX_TABLE_ENTRIES = 50
local MAX_BUFFER_EVENTS = 500
local MAX_EVENTS_PER_SECOND = 40
local STATE_SNAPSHOT_INTERVAL = 2.5
local DEDUPE_WINDOW = 0.35

-- Capacity Caps for Long Sessions
local MAX_SCHEMAS = 200
local MAX_UI_CAUSALITY_ENTRIES = 200
local MAX_WORLD_STATE_ENTRIES = 150
local MAX_STATE_MUTATION_KEYS = 300
local MAX_UPVALUE_SCRIPTS = 50
local MAX_UPVALUES_PER_SCRIPT = 15
local MAX_MODULE_KEYS = 20

local SESSION_VERSION = "4.9-ProductionHardened"

-- Engine Storage
local ExtractedSchemas = {}
local schemaCount = 0
local UICausalityMap = {}
local causalityCount = 0
local WorldStateModel = {}
local worldStateCount = 0
local StateMutationTracker = {}
local mutationCount = 0
local LocalScriptUpvalueStore = {}
local upvalueScriptCount = 0

local HookedInboundRemotes = {}
local HookingInboundRemotes = {}
local DisabledOriginalConnections = {}
local HookedPlayerGuis = {}

local CAPTURE_STATE_DELTAS = true
local ENABLE_NETWORK_HOOK = true
local AUTO_INTERACT_CONFIRMATION = true
local isLoggingActive = true

local totalEventsCaptured = 0
local totalEventsSuppressed = 0
local totalEncodeFailures = 0
local totalFlushFailures = 0
local isMinimized = false
local jsonHasRecords = false
local jsonFinalized = false
local isShuttingDown = false
local previousStateSnapshot = nil

local statusStates = {
    NamecallHook = "Active",
    UIClickTracker = "Active",
    StateSniffer = "Active",
    DiskWriter = "Active",
    InboundSniffer = "Pending",
    UpvalueScanner = "Active"
}

local uiConnections = {}
local shutdownConnections = {}
local connectedButtons = setmetatable({}, {__mode = "k"})
local recentEventTimes = {}
local lastEventSignature = nil
local lastEventTime = 0
local lastEventObj = nil
local lastClickedUI = "None"
local lastClickTime = 0

local originalNamecall = nil
local rawMetatable = nil

local noiseBlacklist = {
    ["mouse"] = true, ["updatepos"] = true, ["heartbeat"] = true,
    ["camera"] = true, ["ping"] = true
}

-- Storage Setup (Modifies statusStates before UI is instantiated)
local storageReady = false
local storageSuccess = _pcall(function()
    if not writefile or not makefolder or not appendfile or not isfolder then
        error("File APIs unavailable")
    end
    if not isfolder(SESSION_FOLDER) then
        makefolder(SESSION_FOLDER)
    end
    local metadata = {
        SessionStarted = true,
        Version = SESSION_VERSION,
        StartedAt = _tick(),
        PlaceId = tostring(rawGame.PlaceId),
        JobId = "[Redacted]"
    }
    local success, encodedMetadata = _pcall(function()
        return HttpService:JSONEncode(metadata)
    end)
    if not success then
        totalEncodeFailures = totalEncodeFailures + 1
        error("Metadata Encode Failed")
    end
    writefile(SESSION_FILE, "[\n  " .. encodedMetadata .. "\n")
    jsonHasRecords = true
    storageReady = true
end)

if not storageSuccess or not storageReady then
    statusStates.DiskWriter = "Failed"
end

local flushBuffer
local captureLocalEvent
local takeStateSnapshot
local computeStateDeltas
local statusLabels = {}

local function setStatus(name, state, color)
    statusStates[name] = state
    local label = statusLabels[name]
    if label and label.Parent then
        label.Text = "• " .. name .. ": " .. state
        label.TextColor3 = color or (state == "Active" and Color3.fromRGB(0, 255, 128) or Color3.fromRGB(255, 165, 0))
    end
end

local function setDiskError(text, color)
    setStatus("DiskWriter", text, color or Color3.fromRGB(255, 69, 0))
end

-- =====================================================================
-- UI CREATION
-- =====================================================================
local parentTarget = (gethui and gethui()) or CoreGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name = panelName
screenGui.ResetOnSpawn = false
screenGui.Parent = parentTarget
runtimeEnv.TelemetryProductionScreenGui = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 260)
mainFrame.Position = UDim2.new(0, 20, 0, 50)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 28)
topBar.BackgroundTransparency = 1
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Delta Telemetry Engine"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize, titleLabel.Font = 13, Enum.Font.SourceSansBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(1, -24, 0, 4)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize, closeBtn.Font = 11, Enum.Font.SourceSansBold
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 20, 0, 20)
minBtn.Position = UDim2.new(1, -48, 0, 4)
minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextSize, minBtn.Font = 13, Enum.Font.SourceSansBold
minBtn.Parent = topBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, -28)
container.Position = UDim2.new(0, 0, 0, 28)
container.BackgroundTransparency = 1
container.Parent = mainFrame

local counterLabel = Instance.new("TextLabel")
counterLabel.Size = UDim2.new(0.5, -10, 0, 20)
counterLabel.Position = UDim2.new(0, 8, 0, 2)
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "Captured: 0"
counterLabel.TextColor3 = Color3.fromRGB(0, 255, 128)
counterLabel.TextSize, counterLabel.Font = 12, Enum.Font.SourceSansBold
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.Parent = container

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.5, -10, 0, 20)
toggleBtn.Position = UDim2.new(0.5, 2, 0, 2)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
toggleBtn.Text = "Status: ACTIVE"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.TextSize, toggleBtn.Font = 11, Enum.Font.SourceSansBold
toggleBtn.Parent = container
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 5)

local subCard = Instance.new("Frame")
subCard.Size = UDim2.new(1, -16, 0, 78)
subCard.Position = UDim2.new(0, 8, 0, 26)
subCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
subCard.BorderSizePixel = 0
subCard.Parent = container
Instance.new("UICorner", subCard).CornerRadius = UDim.new(0, 6)

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(1, -10, 0, 14)
subTitle.Position = UDim2.new(0, 6, 0, 2)
subTitle.BackgroundTransparency = 1
subTitle.Text = "Subsystem Health"
subTitle.TextColor3 = Color3.fromRGB(160, 160, 175)
subTitle.TextSize, subTitle.Font = 10, Enum.Font.SourceSansBold
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.Parent = subCard

-- Dynamically reflects actual initial state from statusStates
local function createStatusLabel(name, posY)
    local initialState = statusStates[name] or "Active"
    local initialColor = (initialState == "Active" and Color3.fromRGB(0, 255, 128))
        or (initialState == "Failed" and Color3.fromRGB(255, 69, 0))
        or Color3.fromRGB(255, 165, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 0, 11)
    lbl.Position = UDim2.new(0, 6, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Text = "• " .. name .. ": " .. initialState
    lbl.TextColor3 = initialColor
    lbl.TextSize, lbl.Font = 9, Enum.Font.SourceSans
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = subCard
    return lbl
end

statusLabels.NamecallHook = createStatusLabel("NamecallHook", 15)
statusLabels.UIClickTracker = createStatusLabel("UIClickTracker", 26)
statusLabels.StateSniffer = createStatusLabel("StateSniffer", 37)
statusLabels.InboundSniffer = createStatusLabel("InboundSniffer", 48)
statusLabels.UpvalueScanner = createStatusLabel("UpvalueScanner", 59)
statusLabels.DiskWriter = createStatusLabel("DiskWriter", 70)

local feedCard = Instance.new("Frame")
feedCard.Size = UDim2.new(1, -16, 0, 58)
feedCard.Position = UDim2.new(0, 8, 0, 108)
feedCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
feedCard.BorderSizePixel = 0
feedCard.Parent = container
Instance.new("UICorner", feedCard).CornerRadius = UDim.new(0, 6)

local inspectorTitle = Instance.new("TextLabel")
inspectorTitle.Size = UDim2.new(1, -10, 0, 14)
inspectorTitle.Position = UDim2.new(0, 6, 0, 2)
inspectorTitle.BackgroundTransparency = 1
inspectorTitle.Text = "Live Feed Inspector"
inspectorTitle.TextColor3 = Color3.fromRGB(160, 160, 175)
inspectorTitle.TextSize, inspectorTitle.Font = 10, Enum.Font.SourceSansBold
inspectorTitle.TextXAlignment = Enum.TextXAlignment.Left
inspectorTitle.Parent = feedCard

local inspectorLines = {}
for i = 1, 3 do
    local line = Instance.new("TextLabel")
    line.Size = UDim2.new(1, -12, 0, 12)
    line.Position = UDim2.new(0, 6, 0, 16 + ((i - 1) * 13))
    line.BackgroundTransparency = 1
    line.Text = "• [Idle]"
    line.TextColor3 = Color3.fromRGB(130, 130, 145)
    line.TextSize, line.Font = 9, Enum.Font.Code
    line.TextXAlignment = Enum.TextXAlignment.Left
    line.Parent = feedCard
    _tinsert(inspectorLines, line)
end

local function pushLiveFeed(text)
    if isShuttingDown then return end
    for i = 3, 2, -1 do
        inspectorLines[i].Text = inspectorLines[i - 1].Text
        inspectorLines[i].TextColor3 = inspectorLines[i - 1].TextColor3
    end
    inspectorLines[1].Text = "• " .. text
    inspectorLines[1].TextColor3 = Color3.fromRGB(100, 220, 255)
end

local function refreshCounterUI()
    if isShuttingDown or not counterLabel.Parent or not titleLabel.Parent then return end
    counterLabel.Text = "Captured: " .. totalEventsCaptured
    titleLabel.Text = isMinimized and ("Delta Engine (" .. totalEventsCaptured .. ")") or "Delta Telemetry Engine"
end

local function eventSignature(event)
    return tostring(event.EventType or "") .. "|" .. tostring(event.Path or (event.Details and event.Details.Path) or "") .. "|" .. tostring(event.RemotePath or "")
end

local function underRateLimit()
    local now = _osclock()
    for i = #recentEventTimes, 1, -1 do
        if now - recentEventTimes[i] > 1 then
            table.remove(recentEventTimes, i)
        end
    end
    if #recentEventTimes >= MAX_EVENTS_PER_SECOND then return false end
    _tinsert(recentEventTimes, now)
    return true
end

local function enqueueEvent(event)
    if not isLoggingActive or isShuttingDown or jsonFinalized then return false end
    if not underRateLimit() or #eventBuffer >= MAX_BUFFER_EVENTS then
        totalEventsSuppressed = totalEventsSuppressed + 1
        return false
    end

    local signature = eventSignature(event)
    local now = _osclock()
    if signature == lastEventSignature and now - lastEventTime <= DEDUPE_WINDOW then
        if lastEventObj then lastEventObj.RepeatCount = (lastEventObj.RepeatCount or 1) + 1 end
        return true
    end

    _tinsert(eventBuffer, event)
    lastEventSignature, lastEventTime, lastEventObj = signature, now, event
    totalEventsCaptured = totalEventsCaptured + 1
    refreshCounterUI()
    pushLiveFeed(event.FeedText or event.EventType or event.Method or "Event")

    if #eventBuffer >= BUFFER_FLUSH_COUNT then
        _pcall(flushBuffer)
    end
    return true
end

captureLocalEvent = function(eventType, details)
    enqueueEvent({
        Timestamp = _tick(),
        EventType = eventType,
        FeedText = eventType,
        Details = details or {},
        RepeatCount = 1
    })
end

local scanInteractablesBtn = Instance.new("TextButton")
scanInteractablesBtn.Size = UDim2.new(0.5, -10, 0, 22)
scanInteractablesBtn.Position = UDim2.new(0, 8, 0, 172)
scanInteractablesBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 210)
scanInteractablesBtn.Text = "Trigger Interactables"
scanInteractablesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
scanInteractablesBtn.TextSize, scanInteractablesBtn.Font = 10, Enum.Font.SourceSansBold
scanInteractablesBtn.Parent = container
Instance.new("UICorner", scanInteractablesBtn).CornerRadius = UDim.new(0, 5)

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(0.5, -10, 0, 22)
saveBtn.Position = UDim2.new(0.5, 2, 0, 172)
saveBtn.BackgroundColor3 = Color3.fromRGB(45, 110, 210)
saveBtn.Text = "Force Save"
saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
saveBtn.TextSize, saveBtn.Font = 10, Enum.Font.SourceSansBold
saveBtn.Parent = container
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 5)

-- =====================================================================
-- EXACT SENSITIVE KEY REDACTION & SAFE SERIALIZATION
-- =====================================================================
local function isSensitiveKeyStrict(key)
    local str = string.lower(tostring(key))
    if str == "token" or str == "password" or str == "secret" or str == "auth"
       or str == "authorization" or str == "session" or str == "credential"
       or str == "authtoken" or str == "accesstoken" or str == "passwordhash"
       or str == "session_id" or str == "sessionid" or str == "apikey" or str == "api_key"
       or str:find("_token$") or str:find("^token_")
       or str:find("_key$") or str:find("^key_")
       or str:find("pass_") or str:find("_pass") then
        return true
    end
    return false
end

local function truncateString(value)
    value = tostring(value)
    if #value > MAX_EVENT_STRING_LENGTH then
        return value:sub(1, MAX_EVENT_STRING_LENGTH) .. "...[Truncated]"
    end
    return value
end

local function safeGetInstancePath(inst)
    if isShuttingDown then return "[Engine Teardown]" end
    local path = "[Destroyed Instance]"
    _pcall(function()
        if inst and typeof(inst) == "Instance" and inst.Parent then
            path = inst:GetFullName()
        else
            path = tostring(inst)
        end
    end)
    return truncateString(path)
end

local function sanitizeValue(val)
    local vType = typeof(val)
    if vType == "nil" then
        return nil
    elseif vType == "boolean" then
        return val
    elseif vType == "number" then
        if val ~= val then return "NaN" end
        if val == math.huge then return "Infinity" end
        if val == -math.huge then return "-Infinity" end
        return val
    elseif vType == "string" then
        return truncateString(val)
    elseif vType == "Instance" then
        return safeGetInstancePath(val)
    elseif vType == "Vector3" or vType == "CFrame" or vType == "Color3" or vType == "UDim2" or vType == "EnumItem" then
        return tostring(val)
    else
        return "[" .. vType .. "]"
    end
end

local function sanitizeArg(value, seen, depth)
    seen = seen or {}
    depth = depth or 0
    if depth > 3 then return "[Max Depth Reached]" end

    local vType = typeof(value)
    if value == nil then
        return nil
    elseif vType == "boolean" then
        return value
    elseif vType == "number" then
        return sanitizeValue(value)
    elseif vType == "string" then
        return truncateString(value)
    elseif vType == "Instance" then
        return {__Type = "Instance", __Value = safeGetInstancePath(value)}
    elseif vType == "table" then
        if seen[value] then return "{Circular Reference}" end
        seen[value] = true
        local sanitized, count = {}, 0
        for k, v in pairs(value) do
            count = count + 1
            if count > MAX_TABLE_ENTRIES then
                sanitized.__Truncated = true
                break
            end
            local kType = typeof(k)
            local rawKeyStr = tostring(k)
            local keyStr = kType == "string" and rawKeyStr or ("[" .. kType .. "]" .. rawKeyStr)
            
            if isSensitiveKeyStrict(rawKeyStr) then
                sanitized[keyStr] = "[Redacted]"
            else
                sanitized[keyStr] = sanitizeArg(v, seen, depth + 1)
            end
        end
        seen[value] = nil
        return sanitized
    elseif vType == "Vector3" or vType == "CFrame" or vType == "Color3" or vType == "UDim2" or vType == "EnumItem" then
        return {__Type = vType, __Value = tostring(value)}
    else
        return "[" .. vType .. "]"
    end
end

local function updateRemoteSchema(remotePath, method, args, direction)
    local key = (direction or "Outbound") .. ":" .. remotePath
    if not ExtractedSchemas[key] then
        if schemaCount >= MAX_SCHEMAS then return end
        ExtractedSchemas[key] = {
            Path = remotePath,
            Direction = direction or "Outbound",
            Method = method,
            CallCount = 0,
            ArgumentTypes = {}
        }
        schemaCount = schemaCount + 1
    end

    local schema = ExtractedSchemas[key]
    schema.CallCount = schema.CallCount + 1

    local argCount = args.n or #args
    for i = 1, argCount do
        local val = args[i]
        local vType = typeof(val)

        if not schema.ArgumentTypes[i] then
            schema.ArgumentTypes[i] = {Type = vType, Samples = {}}
        end

        local argInfo = schema.ArgumentTypes[i]
        if #argInfo.Samples < 5 then
            _tinsert(argInfo.Samples, sanitizeArg(val))
        end
    end
end

local function updateUICausality(remotePath, args, currentTime)
    if lastClickedUI ~= "None" and (currentTime - lastClickTime < 0.25) then
        if causalityCount >= MAX_UI_CAUSALITY_ENTRIES then return end
        if not UICausalityMap[lastClickedUI] then
            UICausalityMap[lastClickedUI] = {}
            causalityCount = causalityCount + 1
        end

        if #UICausalityMap[lastClickedUI] < 10 then
            _tinsert(UICausalityMap[lastClickedUI], {
                TargetRemote = remotePath,
                TimeOffsetMs = _floor((currentTime - lastClickTime) * 1000),
                SampleArguments = sanitizeArg(args)
            })
        end
    end
end

local function isSystemRemote(path)
    if path == "" then return true end
    local lower = string.lower(path)
    if string.find(lower, "chat") or string.find(lower, "voice") or string.find(lower, "analytics") then
        return true
    end
    for keyword in pairs(noiseBlacklist) do
        if string.find(lower, keyword) then return true end
    end
    return false
end

-- =====================================================================
-- DYNAMIC RETRYING UI CLICK TRACKER
-- =====================================================================
local function attachButtonTracker(btn)
    if connectedButtons[btn] then return end
    connectedButtons[btn] = true

    local conn = btn.InputBegan:Connect(function(input)
        if isShuttingDown then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            lastClickedUI = safeGetInstancePath(btn)
            lastClickTime = _tick()
            captureLocalEvent("UIClick", {Target = lastClickedUI})
        end
    end)
    _tinsert(uiConnections, conn)
end

local function scanPlayerGuiContainer(pGui)
    if HookedPlayerGuis[pGui] then return end
    HookedPlayerGuis[pGui] = true

    _pcall(function()
        for _, desc in ipairs(pGui:GetDescendants()) do
            if desc:IsA("GuiButton") then
                attachButtonTracker(desc)
            end
        end
    end)

    local addedConn = pGui.DescendantAdded:Connect(function(desc)
        if isShuttingDown then return end
        if desc:IsA("GuiButton") then
            attachButtonTracker(desc)
        end
    end)
    _tinsert(uiConnections, addedConn)
end

local function scanAndHookUI()
    task.spawn(function()
        while not isShuttingDown do
            local pGui = localPlayer:FindFirstChildOfClass("PlayerGui")
            if pGui then
                scanPlayerGuiContainer(pGui)
                setStatus("UIClickTracker", "Active")
                break
            else
                setStatus("UIClickTracker", "Pending")
            end
            task.wait(1)
        end
    end)
end

scanAndHookUI()

local playerGuiRespawnConn = localPlayer.ChildAdded:Connect(function(child)
    if child:IsA("PlayerGui") then
        scanPlayerGuiContainer(child)
    end
end)
_tinsert(uiConnections, playerGuiRespawnConn)

-- =====================================================================
-- INBOUND NETWORK SNIFFER WITH FAILSAFE CONNECTION HANDLING
-- =====================================================================
local function hookInboundRemote(remote)
    if isShuttingDown or HookedInboundRemotes[remote] or HookingInboundRemotes[remote] then return end
    HookingInboundRemotes[remote] = true

    if remote:IsA("RemoteEvent") and getconnections then
        local connSuccess, conns = _pcall(getconnections, remote.OnClientEvent)
        if connSuccess and conns then
            HookedInboundRemotes[remote] = true
            HookingInboundRemotes[remote] = nil

            for _, connection in ipairs(conns) do
                if connection.Function then
                    local oldFunc = connection.Function
                    local wasDisabled = false

                    local canManipulate = connection.Disable and connection.Enable
                    if canManipulate then
                        local disableSuccess = _pcall(function() connection:Disable() end)
                        if disableSuccess then
                            wasDisabled = true
                            _tinsert(DisabledOriginalConnections, connection)
                        end
                    end

                    local wrapperFunc = function(...)
                        local args = _tpack(...)
                        if isLoggingActive and not isShuttingDown then
                            local path = safeGetInstancePath(remote)
                            if not isSystemRemote(path) then
                                task.defer(function()
                                    if isShuttingDown then return end
                                    updateRemoteSchema(path, "OnClientEvent", args, "Inbound")
                                    local sanitized = {Count = args.n, Values = {}}
                                    for i = 1, args.n do
                                        sanitized.Values[i] = sanitizeArg(args[i])
                                    end
                                    enqueueEvent({
                                        Timestamp = _tick(),
                                        RemotePath = path,
                                        Direction = "Inbound",
                                        EventType = "OnClientEvent",
                                        FeedText = "Inbound: " .. remote.Name,
                                        Arguments = sanitized,
                                        RepeatCount = 1
                                    })
                                end)
                            end
                        end

                        if wasDisabled then
                            return oldFunc(...)
                        end
                    end

                    local safeWrapper = newcclosure and newcclosure(wrapperFunc) or wrapperFunc
                    local newConn = remote.OnClientEvent:Connect(safeWrapper)
                    _tinsert(shutdownConnections, newConn)
                end
            end
            setStatus("InboundSniffer", "Active")
        else
            HookingInboundRemotes[remote] = nil
        end
    elseif remote:IsA("RemoteFunction") then
        HookedInboundRemotes[remote] = {
            InboundStatus = "Unsupported",
            Reason = "Client-side RemoteFunction callback interception is unavailable"
        }
        HookingInboundRemotes[remote] = nil
    else
        HookingInboundRemotes[remote] = nil
    end
end

local function scanInboundContainer(containerObj)
    _pcall(function()
        for _, desc in ipairs(containerObj:GetDescendants()) do
            _pcall(function()
                if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                    hookInboundRemote(desc)
                end
            end)
        end
    end)
end

local function bindDynamicInboundSniffer()
    if not getconnections then
        setStatus("InboundSniffer", "Unsupported")
        return
    end

    local containersToScan = {ReplicatedStorage, Workspace, Players}
    for _, cont in ipairs(containersToScan) do
        scanInboundContainer(cont)
        local conn = cont.DescendantAdded:Connect(function(desc)
            if isShuttingDown then return end
            _pcall(function()
                if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                    hookInboundRemote(desc)
                end
            end)
        end)
        _tinsert(uiConnections, conn)
    end
end

bindDynamicInboundSniffer()

-- =====================================================================
-- MEMORY-BOUNDED & YIELDABLE LOCAL SCRIPT UPVALUE INSPECTOR
-- =====================================================================
local function resolveScriptOwner(fn)
    local scriptObj = nil
    _pcall(function()
        if getfenv then
            local env = getfenv(fn)
            if env and env.script then
                scriptObj = env.script
            end
        end
    end)
    if scriptObj then return safeGetInstancePath(scriptObj) end

    _pcall(function()
        if getscriptfromthread then
            local th = coroutine.running()
            scriptObj = getscriptfromthread(th)
        end
    end)
    if scriptObj then return safeGetInstancePath(scriptObj) end

    return "Anonymous_GC_Closure"
end

local function scanGarbageCollectionUpvalues()
    if not getgc or not debug or not debug.getupvalues then
        setStatus("UpvalueScanner", "Unsupported")
        return
    end

    task.spawn(function()
        local gcObjects
        local success = pcall(function() gcObjects = getgc(true) end)
        if not success or type(gcObjects) ~= "table" then
            setStatus("UpvalueScanner", "Failed")
            return
        end

        local processedCount = 0
        local BATCH_SIZE = 250

        for _, obj in ipairs(gcObjects) do
            if isShuttingDown or upvalueScriptCount >= MAX_UPVALUE_SCRIPTS then break end

            processedCount = processedCount + 1
            if processedCount % BATCH_SIZE == 0 then
                task.wait()
            end

            if type(obj) == "function" and (not islclosure or islclosure(obj)) then
                if not (checkcaller and checkcaller()) then
                    local ownerName = resolveScriptOwner(obj)
                    if not LocalScriptUpvalueStore[ownerName] then
                        if upvalueScriptCount >= MAX_UPVALUE_SCRIPTS then continue end
                        LocalScriptUpvalueStore[ownerName] = {}
                        upvalueScriptCount = upvalueScriptCount + 1
                    end

                    if #LocalScriptUpvalueStore[ownerName] < MAX_UPVALUES_PER_SCRIPT then
                        local upvalSuccess, upvalues = _pcall(debug.getupvalues, obj)
                        if upvalSuccess and type(upvalues) == "table" and next(upvalues) ~= nil then
                            _tinsert(LocalScriptUpvalueStore[ownerName], sanitizeArg(upvalues))
                        end
                    end
                end
            end
        end
    end)
end

-- =====================================================================
-- MEMORY-BOUNDED MODULE ENVIRONMENT HARVESTER
-- =====================================================================
local function harvestModuleEnvironments()
    if not getloadedmodules or not getsenv then return end

    _pcall(function()
        local modules = getloadedmodules()
        for _, mod in ipairs(modules) do
            if isShuttingDown or worldStateCount >= MAX_WORLD_STATE_ENTRIES then break end
            _pcall(function()
                if mod:IsA("ModuleScript") then
                    local envSuccess, env = _pcall(getsenv, mod)
                    if envSuccess and type(env) == "table" then
                        local modPath = safeGetInstancePath(mod)
                        if not WorldStateModel[modPath] then
                            local truncatedEnv = {}
                            local keyCount = 0

                            for k, v in pairs(env) do
                                keyCount = keyCount + 1
                                if keyCount > MAX_MODULE_KEYS then
                                    truncatedEnv.__Truncated = true
                                    break
                                end
                                local kStr = tostring(k)
                                if isSensitiveKeyStrict(kStr) then
                                    truncatedEnv[kStr] = "[Redacted]"
                                else
                                    truncatedEnv[kStr] = sanitizeValue(v)
                                end
                            end

                            WorldStateModel[modPath] = {
                                Type = "ModuleEnvironment",
                                ExportedKeys = truncatedEnv
                            }
                            worldStateCount = worldStateCount + 1
                        end
                    end
                end
            end)
        end
    end)
end

-- =====================================================================
-- AUTOMATED INTERACTION ENGINE WITH SAFETY GATES
-- =====================================================================
local function triggerNearbyInteractables()
    if isShuttingDown or not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    if AUTO_INTERACT_CONFIRMATION then
        scanInteractablesBtn.Text = "Confirm Trigger?"
        scanInteractablesBtn.BackgroundColor3 = Color3.fromRGB(210, 130, 45)
        AUTO_INTERACT_CONFIRMATION = false
        task.delay(3, function()
            if not AUTO_INTERACT_CONFIRMATION and scanInteractablesBtn.Parent then
                scanInteractablesBtn.Text = "Trigger Interactables"
                scanInteractablesBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 210)
                AUTO_INTERACT_CONFIRMATION = true
            end
        end)
        return
    end

    AUTO_INTERACT_CONFIRMATION = true
    scanInteractablesBtn.Text = "Trigger Interactables"
    scanInteractablesBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 210)

    local rootPos = localPlayer.Character.HumanoidRootPart.Position
    pushLiveFeed("Scanning interactables...")

    _pcall(function()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if isShuttingDown then break end
            _pcall(function()
                if desc:IsA("ProximityPrompt") and fireproximityprompt then
                    local parentPart = desc.Parent
                    if parentPart and parentPart:IsA("BasePart") and (parentPart.Position - rootPos).Magnitude <= 15 then
                        fireproximityprompt(desc)
                        captureLocalEvent("AutoInteract", {Type = "ProximityPrompt", Target = safeGetInstancePath(desc)})
                    end
                elseif desc:IsA("ClickDetector") and fireclickdetector then
                    local parentPart = desc.Parent
                    if parentPart and parentPart:IsA("BasePart") and (parentPart.Position - rootPos).Magnitude <= 15 then
                        fireclickdetector(desc)
                        captureLocalEvent("AutoInteract", {Type = "ClickDetector", Target = safeGetInstancePath(desc)})
                    end
                elseif desc:IsA("TouchTransmitter") and firetouchinterest and localPlayer.Character:FindFirstChild("Head") then
                    local parentPart = desc.Parent
                    if parentPart and parentPart:IsA("BasePart") and (parentPart.Position - rootPos).Magnitude <= 15 then
                        firetouchinterest(localPlayer.Character.Head, parentPart, 0)
                        task.wait(0.05)
                        firetouchinterest(localPlayer.Character.Head, parentPart, 1)
                        captureLocalEvent("AutoInteract", {Type = "TouchInterest", Target = safeGetInstancePath(parentPart)})
                    end
                end
            end)
        end
    end)
end

scanInteractablesBtn.MouseButton1Click:Connect(triggerNearbyInteractables)

-- =====================================================================
-- METATABLE HOOK WITH RESILIENT STATE VALIDATION
-- =====================================================================
local isHookActive = runtimeEnv.TelemetryProductionHookInstalled and type(originalNamecall) == "function"

if ENABLE_NETWORK_HOOK and not isHookActive then
    if hookmetamethod then
        local hookSuccess = _pcall(function()
            rawMetatable = getrawmetatable(rawGame)
            local function namecallCallback(self, ...)
                local method = getnamecallmethod and getnamecallmethod()

                if checkcaller and checkcaller() then
                    return originalNamecall(self, ...)
                end

                if not isLoggingActive or isShuttingDown then
                    return originalNamecall(self, ...)
                end

                if typeof(self) ~= "Instance" then
                    return originalNamecall(self, ...)
                end

                if not (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                    return originalNamecall(self, ...)
                end

                if (method ~= "FireServer" and method ~= "InvokeServer") then
                    return originalNamecall(self, ...)
                end

                local remotePath = safeGetInstancePath(self)
                if isSystemRemote(remotePath) then
                    return originalNamecall(self, ...)
                end

                local args = _tpack(...)
                local currentTime = _tick()

                task.defer(function()
                    if isShuttingDown or jsonFinalized then return end
                    updateRemoteSchema(remotePath, method, args, "Outbound")
                    updateUICausality(remotePath, args, currentTime)

                    local sanitizedArgs = {Count = args.n, Values = {}}
                    for i = 1, args.n do sanitizedArgs.Values[i] = sanitizeArg(args[i]) end

                    enqueueEvent({
                        Timestamp = currentTime,
                        RemotePath = remotePath,
                        Direction = "Outbound",
                        Method = method,
                        FeedText = method .. ": " .. (remotePath:match("[^%.]+$") or remotePath),
                        TriggeredByUI = (currentTime - lastClickTime < 0.25) and lastClickedUI or "None",
                        Arguments = sanitizedArgs,
                        RepeatCount = 1
                    })
                end)

                return originalNamecall(self, ...)
            end

            local safeCallback = newcclosure and newcclosure(namecallCallback) or namecallCallback
            originalNamecall = hookmetamethod(rawGame, "__namecall", safeCallback)
        end)

        if hookSuccess then
            runtimeEnv.TelemetryProductionHookInstalled = true
            setStatus("NamecallHook", "Active")
        else
            runtimeEnv.TelemetryProductionHookInstalled = false
            setStatus("NamecallHook", "Failed", Color3.fromRGB(255, 69, 0))
        end
    else
        setStatus("NamecallHook", "Unsupported")
    end
end

-- =====================================================================
-- DIFFERENTIAL STATE ENGINE WITH REDACTION
-- =====================================================================
takeStateSnapshot = function()
    local state = {Attributes = {}, Leaderstats = {}, Backpack = {}}
    if isShuttingDown then return state end

    _pcall(function()
        for k, v in pairs(localPlayer:GetAttributes()) do 
            local kStr = tostring(k)
            if isSensitiveKeyStrict(kStr) then
                state.Attributes[kStr] = "[Redacted]"
            else
                state.Attributes[kStr] = sanitizeValue(v)
            end
        end
        local ls = localPlayer:FindFirstChild("leaderstats")
        if ls then 
            for _, stat in ipairs(ls:GetChildren()) do 
                local kStr = stat.Name
                if isSensitiveKeyStrict(kStr) then
                    state.Leaderstats[kStr] = "[Redacted]"
                else
                    state.Leaderstats[kStr] = sanitizeValue(stat.Value)
                end
            end 
        end
        local backpack = localPlayer:FindFirstChild("Backpack")
        if backpack then 
            for _, item in ipairs(backpack:GetChildren()) do 
                state.Backpack[item.Name] = (state.Backpack[item.Name] or 0) + 1 
            end 
        end
    end)
    return state
end

computeStateDeltas = function(oldState, newState)
    if not oldState or not newState or isShuttingDown then return end
    local deltas = {}

    for k, v in pairs(newState.Attributes) do
        if oldState.Attributes[k] ~= v then
            deltas["Attribute:" .. k] = {Old = oldState.Attributes[k], New = v}
        end
    end
    for k, v in pairs(oldState.Attributes) do
        if newState.Attributes[k] == nil then
            deltas["Attribute:" .. k] = {Old = v, New = "[Removed]"}
        end
    end

    for k, v in pairs(newState.Leaderstats) do
        if oldState.Leaderstats[k] ~= v then
            deltas["Leaderstat:" .. k] = {Old = oldState.Leaderstats[k], New = v}
        end
    end
    for k, v in pairs(oldState.Leaderstats) do
        if newState.Leaderstats[k] == nil then
            deltas["Leaderstat:" .. k] = {Old = v, New = "[Removed]"}
        end
    end

    for k, v in pairs(newState.Backpack) do
        if oldState.Backpack[k] ~= v then
            deltas["BackpackItem:" .. k] = {Old = oldState.Backpack[k] or 0, New = v}
        end
    end
    for k, v in pairs(oldState.Backpack) do
        if newState.Backpack[k] == nil then
            deltas["BackpackItem:" .. k] = {Old = v, New = 0}
        end
    end

    if next(deltas) ~= nil and mutationCount < MAX_STATE_MUTATION_KEYS then
        local timestampKey = tostring(_tick())
        StateMutationTracker[timestampKey] = deltas
        mutationCount = mutationCount + 1
        captureLocalEvent("StateDelta", {Mutations = deltas})
    end
end

-- =====================================================================
-- DISK FLUSH ENGINE
-- =====================================================================
flushBuffer = function()
    if #eventBuffer == 0 or not storageReady or jsonFinalized then return true end

    local encodedEvents = {}
    local remainingEvents = {}

    for _, event in ipairs(eventBuffer) do
        local success, encoded = _pcall(function() return HttpService:JSONEncode(event) end)
        if success then 
            _tinsert(encodedEvents, encoded) 
        else
            totalEncodeFailures = totalEncodeFailures + 1
            _tinsert(remainingEvents, event)
        end
    end

    if #encodedEvents == 0 then
        eventBuffer = remainingEvents
        return #eventBuffer == 0
    end

    local prefix = jsonHasRecords and ",\n" or ""
    local chunk = prefix .. "  " .. table.concat(encodedEvents, ",\n  ")
    local success = _pcall(function() appendfile(SESSION_FILE, chunk) end)

    if success then
        setStatus("DiskWriter", "Active")
        jsonHasRecords = true
        eventBuffer = remainingEvents
        return #eventBuffer == 0
    end

    totalFlushFailures = totalFlushFailures + 1
    setDiskError("Error")
    return false
end

local function finalizeJsonFile()
    if jsonFinalized or not storageReady then return false end

    local flushOk = flushBuffer()
    if not flushOk or #eventBuffer > 0 then
        setDiskError("Flush Partial")
        return false
    end

    local analysisSections = {
        ExtractedSchemas = ExtractedSchemas,
        UICausalityMap = UICausalityMap,
        WorldStateModel = WorldStateModel,
        StateMutationTracker = StateMutationTracker,
        LocalScriptUpvalues = LocalScriptUpvalueStore
    }

    local serializedSections = {}
    for sectionKey, sectionData in pairs(analysisSections) do
        local encSuccess, encodedSection = _pcall(function()
            return HttpService:JSONEncode(sectionData)
        end)
        if encSuccess then
            serializedSections[sectionKey] = encodedSection
        else
            totalEncodeFailures = totalEncodeFailures + 1
            serializedSections[sectionKey] = '"[Section Omitted: Exceeded Encoding Size Limit]"'
        end
    end

    local sectionEntries = {}
    for key, jsonStr in pairs(serializedSections) do
        _tinsert(sectionEntries, '      "' .. key .. '": ' .. jsonStr)
    end
    local preformattedAnalysisJson = "{\n" .. table.concat(sectionEntries, ",\n") .. "\n    }"

    local endingRecordHeader = "  {\n" ..
        '    "SessionEnded": true,\n' ..
        '    "EndedAt": ' .. tostring(_tick()) .. ',\n' ..
        '    "TotalCaptured": ' .. tostring(totalEventsCaptured) .. ',\n' ..
        '    "TotalSuppressed": ' .. tostring(totalEventsSuppressed) .. ',\n' ..
        '    "EncodeFailures": ' .. tostring(totalEncodeFailures) .. ',\n' ..
        '    "FlushFailures": ' .. tostring(totalFlushFailures) .. ',\n' ..
        '    "GameAnalysis": ' .. preformattedAnalysisJson .. '\n' ..
        "  }\n]\n"

    local prefix = jsonHasRecords and ",\n" or ""
    local appendSuccess = _pcall(function()
        appendfile(SESSION_FILE, prefix .. endingRecordHeader)
    end)

    if appendSuccess then
        jsonFinalized = true
        return true
    end

    totalFlushFailures = totalFlushFailures + 1
    setDiskError("Finalize Fail")
    return false
end

-- =====================================================================
-- COMPLETE ENGINE TEARDOWN
-- =====================================================================
local function unloadEngine()
    isShuttingDown = true
    isLoggingActive = false

    -- Restore Original Metatable Hook
    if originalNamecall and hookmetamethod and rawGame then
        _pcall(function()
            hookmetamethod(rawGame, "__namecall", originalNamecall)
        end)
        originalNamecall = nil
    end
    runtimeEnv.TelemetryProductionHookInstalled = false

    -- Re-enable Original Inbound Connections
    for _, originalConn in ipairs(DisabledOriginalConnections) do
        if originalConn then
            local enableSuccess = _pcall(function()
                if originalConn.Enable then
                    originalConn:Enable()
                elseif originalConn.EnableConnection then
                    originalConn:EnableConnection()
                end
            end)
            if not enableSuccess then
                warn("[Telemetry Engine Warning] Failed to restore disabled inbound connection on teardown.")
            end
        end
    end
    DisabledOriginalConnections = {}

    -- Disconnect Internal Wrappers
    for _, conn in ipairs(shutdownConnections) do
        _pcall(function() conn:Disconnect() end)
    end
    shutdownConnections = {}

    -- Disconnect UI Listeners
    for _, conn in ipairs(uiConnections) do
        _pcall(function() conn:Disconnect() end)
    end
    uiConnections = {}

    -- Flush Remaining Data & Seal File
    finalizeJsonFile()

    -- Clear Global Keys
    runtimeEnv.TelemetryProductionRunning = nil
    runtimeEnv.TelemetryProductionScreenGui = nil

    if screenGui then
        screenGui:Destroy()
    end
    print("[Telemetry Engine] Shutdown complete. All connections and hooks restored.")
end

-- =====================================================================
-- MAIN WORKER LOOP
-- =====================================================================
task.spawn(function()
    previousStateSnapshot = takeStateSnapshot()
    harvestModuleEnvironments()
    scanGarbageCollectionUpvalues()

    while not isShuttingDown do
        task.wait(STATE_SNAPSHOT_INTERVAL + _random() * 0.5)
        if not isShuttingDown then
            _pcall(function()
                if CAPTURE_STATE_DELTAS and isLoggingActive then
                    local currentSnapshot = takeStateSnapshot()
                    computeStateDeltas(previousStateSnapshot, currentSnapshot)
                    previousStateSnapshot = currentSnapshot
                end

                if #eventBuffer > 0 then
                    flushBuffer()
                end
            end)
        end
    end
end)

-- UI Interaction Bindings
minBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    container.Visible = not isMinimized
    mainFrame.Size = isMinimized and UDim2.new(0, 180, 0, 28) or UDim2.new(0, 250, 0, 260)
    minBtn.Text = isMinimized and "+" or "-"
    refreshCounterUI()
end)

closeBtn.MouseButton1Click:Connect(function()
    if isShuttingDown then return end
    unloadEngine()
end)

toggleBtn.MouseButton1Click:Connect(function()
    if isShuttingDown or jsonFinalized then return end
    isLoggingActive = not isLoggingActive
    toggleBtn.BackgroundColor3 = isLoggingActive and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    toggleBtn.Text = isLoggingActive and "Status: ACTIVE" or "Status: PAUSED"
end)

saveBtn.MouseButton1Click:Connect(function()
    local saved = #eventBuffer == 0 or flushBuffer()
    counterLabel.Text = saved and "Saved!" or "Save failed"
    task.delay(1.5, refreshCounterUI)
end)

print("[Delta Telemetry Engine] Engine Ready.")
