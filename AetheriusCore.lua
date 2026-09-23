--[[
    CLIENT GAME INTELLIGENCE ANALYZER
    ==================================

    PHASE 1
    --------
    • Compact mobile UI
    • Incremental instance scanner
    • Attribute scanner
    • CollectionService tag scanner
    • ValueObject detection
    • Basic useful property collection
    • Search
    • Live feature status
    • Progress tracking
    • Pause / Resume
    • Rescan
    • Mobile-friendly yielding

    This is designed for client-visible data in an experience
    you own or are authorized to test.

    Later phases can add:
    • GUI analysis
    • Behavior monitoring
    • Relationship mapping
    • State-change tracking
    • Action correlation
    • Object-family detection
    • Remote observation
    • Authorized active testing
    • JSON export
]]

--==================================================
-- SERVICES
--==================================================

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--==================================================
-- CONFIGURATION
--==================================================

local CONFIG = {
    -- Objects processed per batch.
    -- Lower values are smoother on mobile.
    BATCH_SIZE = 100,

    -- Small delay between batches.
    YIELD_TIME = 0.03,

    -- Maximum stored results.
    MAX_RESULTS = 50000,

    -- Maximum attributes stored per object.
    MAX_ATTRIBUTES_PER_OBJECT = 100,

    -- Maximum tags stored per object.
    MAX_TAGS_PER_OBJECT = 50,

    -- Automatically scan when loaded.
    AUTO_SCAN = true,
}

--==================================================
-- STATE
--==================================================

local State = {
    Scanning = false,
    Paused = false,
    CurrentIndex = 0,
    TotalObjects = 0,

    ObjectsScanned = 0,
    AttributesFound = 0,
    TagsFound = 0,
    ValueObjectsFound = 0,

    Results = {},
    ResultByInstance = {},

    ScanStarted = 0,
    ScanFinished = 0,
}

--==================================================
-- FEATURE STATUS
--==================================================

local FeatureStatus = {
    Structure = "WAITING",
    Attributes = "WAITING",
    Tags = "WAITING",
    Values = "WAITING",
}

local StatusOrder = {
    "Structure",
    "Attributes",
    "Tags",
    "Values",
}

--==================================================
-- UI
--==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ClientGameAnalyzer"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

--==================================================
-- MAIN WINDOW
--==================================================

local Main = Instance.new("Frame")
Main.Name = "AnalyzerWindow"
Main.Size = UDim2.new(0.92, 0, 0, 430)
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
Main.BorderSizePixel = 0
Main.ZIndex = 50
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 66, 80)
MainStroke.Thickness = 1
MainStroke.Parent = Main

--==================================================
-- TITLE BAR
--==================================================

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(27, 31, 40)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 51
TitleBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Client Analyzer"
Title.TextColor3 = Color3.fromRGB(240, 243, 248)
Title.TextSize = 16
Title.Font = Enum.Font.GothamSemibold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 52
Title.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 38, 0, 32)
MinimizeButton.Position = UDim2.new(1, -82, 0, 5)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(45, 50, 62)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Text = "−"
MinimizeButton.TextColor3 = Color3.fromRGB(230, 233, 240)
MinimizeButton.TextSize = 20
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.ZIndex = 52
MinimizeButton.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 7)
MinCorner.Parent = MinimizeButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 38, 0, 32)
CloseButton.Position = UDim2.new(1, -42, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(65, 45, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(255, 220, 225)
CloseButton.TextSize = 20
CloseButton.Font = Enum.Font.GothamBold
CloseButton.ZIndex = 52
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 7)
CloseCorner.Parent = CloseButton

--==================================================
-- STATUS SUMMARY
--==================================================

local StatusHeader = Instance.new("TextButton")
StatusHeader.Name = "StatusHeader"
StatusHeader.Size = UDim2.new(1, -20, 0, 34)
StatusHeader.Position = UDim2.new(0, 10, 0, 50)
StatusHeader.BackgroundColor3 = Color3.fromRGB(29, 34, 43)
StatusHeader.BorderSizePixel = 0
StatusHeader.Text = ""
StatusHeader.ZIndex = 51
StatusHeader.Parent = Main

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 8)
StatusCorner.Parent = StatusHeader

local OverallStatus = Instance.new("TextLabel")
OverallStatus.Size = UDim2.new(1, -80, 1, 0)
OverallStatus.Position = UDim2.new(0, 10, 0, 0)
OverallStatus.BackgroundTransparency = 1
OverallStatus.Text = "● READY"
OverallStatus.TextColor3 = Color3.fromRGB(180, 190, 205)
OverallStatus.TextSize = 13
OverallStatus.Font = Enum.Font.GothamSemibold
OverallStatus.TextXAlignment = Enum.TextXAlignment.Left
OverallStatus.ZIndex = 52
OverallStatus.Parent = StatusHeader

local ProgressText = Instance.new("TextLabel")
ProgressText.Size = UDim2.new(0, 60, 1, 0)
ProgressText.Position = UDim2.new(1, -70, 0, 0)
ProgressText.BackgroundTransparency = 1
ProgressText.Text = "0%"
ProgressText.TextColor3 = Color3.fromRGB(190, 200, 215)
ProgressText.TextSize = 12
ProgressText.Font = Enum.Font.Gotham
ProgressText.TextXAlignment = Enum.TextXAlignment.Right
ProgressText.ZIndex = 52
ProgressText.Parent = StatusHeader

local StatusArrow = Instance.new("TextLabel")
StatusArrow.Size = UDim2.new(0, 20, 1, 0)
StatusArrow.Position = UDim2.new(1, -22, 0, 0)
StatusArrow.BackgroundTransparency = 1
StatusArrow.Text = "▲"
StatusArrow.TextColor3 = Color3.fromRGB(160, 170, 185)
StatusArrow.TextSize = 11
StatusArrow.Font = Enum.Font.GothamBold
StatusArrow.ZIndex = 52
StatusArrow.Parent = StatusHeader

--==================================================
-- STATUS LIST
--==================================================

local StatusFrame = Instance.new("Frame")
StatusFrame.Name = "StatusList"
StatusFrame.Size = UDim2.new(1, -20, 0, 115)
StatusFrame.Position = UDim2.new(0, 10, 0, 88)
StatusFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
StatusFrame.BorderSizePixel = 0
StatusFrame.ZIndex = 51
StatusFrame.Parent = Main

local StatusFrameCorner = Instance.new("UICorner")
StatusFrameCorner.CornerRadius = UDim.new(0, 8)
StatusFrameCorner.Parent = StatusFrame

local StatusRows = {}

local function createStatusRow(index, featureName)
    local Row = Instance.new("TextLabel")

    Row.Size = UDim2.new(1, -16, 0, 25)
    Row.Position = UDim2.new(0, 8, 0, (index - 1) * 27 + 5)
    Row.BackgroundTransparency = 1
    Row.Text = "◷  " .. featureName .. "    WAITING"
    Row.TextColor3 = Color3.fromRGB(165, 175, 190)
    Row.TextSize = 12
    Row.Font = Enum.Font.Gotham
    Row.TextXAlignment = Enum.TextXAlignment.Left
    Row.ZIndex = 52
    Row.Parent = StatusFrame

    StatusRows[featureName] = Row
end

for index, featureName in ipairs(StatusOrder) do
    createStatusRow(index, featureName)
end

--==================================================
-- STATISTICS
--==================================================

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Name = "Stats"
StatsLabel.Size = UDim2.new(1, -20, 0, 42)
StatsLabel.Position = UDim2.new(0, 10, 0, 210)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "Objects: 0   Attributes: 0   Tags: 0\nValues: 0"
StatsLabel.TextColor3 = Color3.fromRGB(155, 165, 180)
StatsLabel.TextSize = 11
StatsLabel.Font = Enum.Font.Gotham
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.TextYAlignment = Enum.TextYAlignment.Center
StatsLabel.ZIndex = 51
StatsLabel.Parent = Main

--==================================================
-- SEARCH
--==================================================

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "Search"
SearchBox.Size = UDim2.new(1, -20, 0, 36)
SearchBox.Position = UDim2.new(0, 10, 0, 254)
SearchBox.BackgroundColor3 = Color3.fromRGB(30, 35, 44)
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Search scanned objects..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(105, 115, 130)
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(230, 235, 242)
SearchBox.TextSize = 12
SearchBox.Font = Enum.Font.Gotham
SearchBox.ClearTextOnFocus = false
SearchBox.ZIndex = 51
SearchBox.Parent = Main

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 8)
SearchCorner.Parent = SearchBox

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 10)
SearchPadding.PaddingRight = UDim.new(0, 10)
SearchPadding.Parent = SearchBox

--==================================================
-- RESULTS
--==================================================

local ResultsFrame = Instance.new("ScrollingFrame")
ResultsFrame.Name = "Results"
ResultsFrame.Size = UDim2.new(1, -20, 0, 78)
ResultsFrame.Position = UDim2.new(0, 10, 0, 296)
ResultsFrame.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
ResultsFrame.BorderSizePixel = 0
ResultsFrame.ScrollBarThickness = 4
ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsFrame.ZIndex = 51
ResultsFrame.Parent = Main

local ResultsCorner = Instance.new("UICorner")
ResultsCorner.CornerRadius = UDim.new(0, 8)
ResultsCorner.Parent = ResultsFrame

local ResultsLayout = Instance.new("UIListLayout")
ResultsLayout.Padding = UDim.new(0, 2)
ResultsLayout.Parent = ResultsFrame

--==================================================
-- BUTTONS
--==================================================

local PauseButton = Instance.new("TextButton")
PauseButton.Size = UDim2.new(0.31, -5, 0, 34)
PauseButton.Position = UDim2.new(0, 10, 1, -44)
PauseButton.BackgroundColor3 = Color3.fromRGB(45, 52, 64)
PauseButton.BorderSizePixel = 0
PauseButton.Text = "Pause"
PauseButton.TextColor3 = Color3.fromRGB(225, 230, 238)
PauseButton.TextSize = 12
PauseButton.Font = Enum.Font.GothamSemibold
PauseButton.ZIndex = 51
PauseButton.Parent = Main

local PauseCorner = Instance.new("UICorner")
PauseCorner.CornerRadius = UDim.new(0, 7)
PauseCorner.Parent = PauseButton

local RescanButton = Instance.new("TextButton")
RescanButton.Size = UDim2.new(0.31, -5, 0, 34)
RescanButton.Position = UDim2.new(0.345, 0, 1, -44)
RescanButton.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
RescanButton.BorderSizePixel = 0
RescanButton.Text = "Rescan"
RescanButton.TextColor3 = Color3.fromRGB(245, 248, 255)
RescanButton.TextSize = 12
RescanButton.Font = Enum.Font.GothamSemibold
RescanButton.ZIndex = 51
RescanButton.Parent = Main

local RescanCorner = Instance.new("UICorner")
RescanCorner.CornerRadius = UDim.new(0, 7)
RescanCorner.Parent = RescanButton

local HideButton = Instance.new("TextButton")
HideButton.Size = UDim2.new(0.31, -5, 0, 34)
HideButton.Position = UDim2.new(0.69, 0, 1, -44)
HideButton.BackgroundColor3 = Color3.fromRGB(45, 52, 64)
HideButton.BorderSizePixel = 0
HideButton.Text = "Hide"
HideButton.TextColor3 = Color3.fromRGB(225, 230, 238)
HideButton.TextSize = 12
HideButton.Font = Enum.Font.GothamSemibold
HideButton.ZIndex = 51
HideButton.Parent = Main

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 7)
HideCorner.Parent = HideButton

--==================================================
-- FLOATING OPEN BUTTON
--==================================================

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenAnalyzer"
OpenButton.Size = UDim2.new(0, 52, 0, 52)
OpenButton.Position = UDim2.new(1, -68, 0.5, 0)
OpenButton.AnchorPoint = Vector2.new(0, 0.5)
OpenButton.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
OpenButton.BorderSizePixel = 0
OpenButton.Text = "AI"
OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenButton.TextSize = 16
OpenButton.Font = Enum.Font.GothamBold
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(1, 0)
OpenCorner.Parent = OpenButton

--==================================================
-- DRAGGING
--==================================================

local function makeDraggable(handle, object)
    local dragging = false
    local dragStart
    local startPosition

    local function update(input)
        local delta = input.Position - dragStart

        object.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = object.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            update(input)
        end
    end)
end

makeDraggable(TitleBar, Main)
makeDraggable(OpenButton, OpenButton)

--==================================================
-- STATUS HELPERS
--==================================================

local function statusSymbol(status)
    if status == "COMPLETE" then
        return "✓"
    elseif status == "RUNNING" then
        return "●"
    elseif status == "PROCESSING" then
        return "●"
    elseif status == "PAUSED" then
        return "Ⅱ"
    elseif status == "ERROR" then
        return "!"
    elseif status == "READY" then
        return "○"
    else
        return "◷"
    end
end

local function statusColor(status)
    if status == "COMPLETE" then
        return Color3.fromRGB(100, 210, 140)
    elseif status == "RUNNING" or status == "PROCESSING" then
        return Color3.fromRGB(90, 170, 255)
    elseif status == "ERROR" then
        return Color3.fromRGB(255, 100, 100)
    elseif status == "PAUSED" then
        return Color3.fromRGB(240, 190, 80)
    else
        return Color3.fromRGB(150, 160, 175)
    end
end

local function updateStatus(feature, status)
    FeatureStatus[feature] = status

    local row = StatusRows[feature]

    if row then
        row.Text = statusSymbol(status) .. "  " .. feature .. "    " .. status
        row.TextColor3 = statusColor(status)
    end
end

local function updateStats()
    StatsLabel.Text =
        "Objects: " .. tostring(State.ObjectsScanned)
        .. "   Attributes: " .. tostring(State.AttributesFound)
        .. "   Tags: " .. tostring(State.TagsFound)
        .. "\nValues: " .. tostring(State.ValueObjectsFound)
end

local function getProgress()
    if State.TotalObjects <= 0 then
        return 0
    end

    return math.clamp(
        State.ObjectsScanned / State.TotalObjects,
        0,
        1
    )
end

local function updateProgress()
    local progress = getProgress()
    local percent = math.floor(progress * 100)

    ProgressText.Text = tostring(percent) .. "%"

    if State.Scanning then
        OverallStatus.Text = "● ANALYZING"
        OverallStatus.TextColor3 = Color3.fromRGB(90, 170, 255)
    elseif State.Paused then
        OverallStatus.Text = "Ⅱ PAUSED"
        OverallStatus.TextColor3 = Color3.fromRGB(240, 190, 80)
    elseif State.ScanFinished > 0 then
        OverallStatus.Text = "✓ ANALYSIS COMPLETE"
        OverallStatus.TextColor3 = Color3.fromRGB(100, 210, 140)
    else
        OverallStatus.Text = "● READY"
        OverallStatus.TextColor3 = Color3.fromRGB(180, 190, 205)
    end
end

--==================================================
-- PROPERTY COLLECTION
--==================================================

local function safeProperty(instance, property)
    local success, value = pcall(function()
        return instance[property]
    end)

    if success then
        return value
    end

    return nil
end

local function collectUsefulProperties(instance)
    local properties = {}

    local className = instance.ClassName

    if className == "BasePart" then
        properties.Size = safeProperty(instance, "Size")
        properties.Position = safeProperty(instance, "Position")
        properties.Anchored = safeProperty(instance, "Anchored")
        properties.CanCollide = safeProperty(instance, "CanCollide")
        properties.Transparency = safeProperty(instance, "Transparency")
    elseif className == "Humanoid" then
        properties.Health = safeProperty(instance, "Health")
        properties.MaxHealth = safeProperty(instance, "MaxHealth")
        properties.WalkSpeed = safeProperty(instance, "WalkSpeed")
        properties.JumpPower = safeProperty(instance, "JumpPower")
        properties.HipHeight = safeProperty(instance, "HipHeight")
    elseif className == "Tool" then
        properties.Enabled = safeProperty(instance, "Enabled")
        properties.ToolTip = safeProperty(instance, "ToolTip")
    elseif className == "TextLabel"
        or className == "TextButton"
        or className == "TextBox" then

        properties.Text = safeProperty(instance, "Text")
        properties.Visible = safeProperty(instance, "Visible")
    elseif className == "ImageLabel"
        or className == "ImageButton" then

        properties.Image = safeProperty(instance, "Image")
        properties.Visible = safeProperty(instance, "Visible")
    elseif className == "ProximityPrompt" then
        properties.ActionText = safeProperty(instance, "ActionText")
        properties.ObjectText = safeProperty(instance, "ObjectText")
        properties.HoldDuration = safeProperty(instance, "HoldDuration")
        properties.MaxActivationDistance =
            safeProperty(instance, "MaxActivationDistance")
        properties.Enabled = safeProperty(instance, "Enabled")
    end

    return properties
end

--==================================================
-- INSTANCE ANALYSIS
--==================================================

local function analyzeInstance(instance)
    if #State.Results >= CONFIG.MAX_RESULTS then
        return
    end

    if not instance or not instance.Parent then
        return
    end

    local data = {
        Instance = instance,
        Name = instance.Name,
        ClassName = instance.ClassName,
        FullName = instance:GetFullName(),
        Attributes = {},
        Tags = {},
        Properties = {},
    }

    -- Attributes

    local attributes = instance:GetAttributes()

    local attributeCount = 0

    for name, value in pairs(attributes) do
        attributeCount += 1

        if attributeCount <= CONFIG.MAX_ATTRIBUTES_PER_OBJECT then
            data.Attributes[name] = value
            State.AttributesFound += 1
        end
    end

    -- Tags

    local tags = CollectionService:GetTags(instance)

    for index, tag in ipairs(tags) do
        if index <= CONFIG.MAX_TAGS_PER_OBJECT then
            table.insert(data.Tags, tag)
            State.TagsFound += 1
        end
    end

    -- ValueObjects

    if instance:IsA("ValueBase") then
        State.ValueObjectsFound += 1

        local success, value = pcall(function()
            return instance.Value
        end)

        if success then
            data.Value = value
        end
    end

    -- Useful properties

    data.Properties = collectUsefulProperties(instance)

    table.insert(State.Results, data)

    State.ResultByInstance[instance] = data
end

--==================================================
-- RESULT RENDERING
--==================================================

local function clearResults()
    for _, child in ipairs(ResultsFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function renderResults(searchText)
    clearResults()

    searchText = string.lower(searchText or "")

    local shown = 0

    for _, data in ipairs(State.Results) do
        local searchable =
            string.lower(data.Name .. " " .. data.ClassName .. " " .. data.FullName)

        if searchText == "" or string.find(searchable, searchText, 1, true) then
            local row = Instance.new("TextButton")

            row.Size = UDim2.new(1, -8, 0, 28)
            row.BackgroundColor3 = Color3.fromRGB(31, 36, 45)
            row.BorderSizePixel = 0
            row.Text =
                data.Name
                .. "  [" .. data.ClassName .. "]"
            row.TextColor3 = Color3.fromRGB(215, 222, 232)
            row.TextSize = 11
            row.Font = Enum.Font.Gotham
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.AutoButtonColor = true
            row.ZIndex = 52
            row.Parent = ResultsFrame

            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 8)
            padding.Parent = row

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 5)
            corner.Parent = row

            shown += 1

            if shown >= 100 then
                break
            end
        end
    end

    ResultsFrame.CanvasSize = UDim2.new(
        0,
        0,
        0,
        math.max(0, shown * 30)
    )
end

--==================================================
-- SCAN PREPARATION
--==================================================

local function resetScanState()
    State.Scanning = false
    State.Paused = false
    State.CurrentIndex = 0
    State.TotalObjects = 0

    State.ObjectsScanned = 0
    State.AttributesFound = 0
    State.TagsFound = 0
    State.ValueObjectsFound = 0

    State.Results = {}
    State.ResultByInstance = {}

    State.ScanStarted = 0
    State.ScanFinished = 0

    for _, feature in ipairs(StatusOrder) do
        updateStatus(feature, "WAITING")
    end

    updateStats()
    updateProgress()
    renderResults("")
end

--==================================================
-- SCAN
--==================================================

local function scan()
    if State.Scanning then
        return
    end

    resetScanState()

    State.Scanning = true
    State.ScanStarted = os.clock()

    updateStatus("Structure", "RUNNING")
    updateStatus("Attributes", "RUNNING")
    updateStatus("Tags", "RUNNING")
    updateStatus("Values", "RUNNING")

    local descendants = workspace:GetDescendants()

    State.TotalObjects = #descendants

    task.spawn(function()
        for index, instance in ipairs(descendants) do
            while State.Paused do
                task.wait(0.1)
            end

            if not State.Scanning then
                break
            end

            State.CurrentIndex = index

            analyzeInstance(instance)

            State.ObjectsScanned += 1

            if index % CONFIG.BATCH_SIZE == 0 then
                updateStats()
                updateProgress()

                task.wait(CONFIG.YIELD_TIME)
            end
        end

        if State.Scanning then
            State.Scanning = false
            State.ScanFinished = os.clock()

            updateStatus("Structure", "COMPLETE")
            updateStatus("Attributes", "COMPLETE")
            updateStatus("Tags", "COMPLETE")
            updateStatus("Values", "COMPLETE")

            updateStats()
            updateProgress()

            renderResults(SearchBox.Text)
        end
    end)
end

--==================================================
-- PAUSE / RESUME
--==================================================

PauseButton.MouseButton1Click:Connect(function()
    if not State.Scanning and not State.Paused then
        return
    end

    State.Paused = not State.Paused

    if State.Paused then
        PauseButton.Text = "Resume"

        for _, feature in ipairs(StatusOrder) do
            if FeatureStatus[feature] == "RUNNING" then
                updateStatus(feature, "PAUSED")
            end
        end
    else
        PauseButton.Text = "Pause"

        for _, feature in ipairs(StatusOrder) do
            if FeatureStatus[feature] == "PAUSED" then
                updateStatus(feature, "RUNNING")
            end
        end
    end

    updateProgress()
end)

--==================================================
-- RESCAN
--==================================================

RescanButton.MouseButton1Click:Connect(function()
    PauseButton.Text = "Pause"
    scan()
end)

--==================================================
-- SEARCH
--==================================================

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    renderResults(SearchBox.Text)
end)

--==================================================
-- COLLAPSE STATUS
--==================================================

local statusExpanded = true

StatusHeader.MouseButton1Click:Connect(function()
    statusExpanded = not statusExpanded

    if statusExpanded then
        StatusFrame.Visible = true
        StatusArrow.Text = "▲"

        StatsLabel.Position = UDim2.new(0, 10, 0, 210)
        SearchBox.Position = UDim2.new(0, 10, 0, 254)
        ResultsFrame.Position = UDim2.new(0, 10, 0, 296)
    else
        StatusFrame.Visible = false
        StatusArrow.Text = "▼"

        StatsLabel.Position = UDim2.new(0, 10, 0, 94)
        SearchBox.Position = UDim2.new(0, 10, 0, 138)
        ResultsFrame.Position = UDim2.new(0, 10, 0, 180)
    end
end)

--==================================================
-- HIDE / SHOW
--==================================================

HideButton.MouseButton1Click:Connect(function()
    Main.Visible = false
    OpenButton.Visible = true
end)

OpenButton.MouseButton1Click:Connect(function()
    Main.Visible = true
    OpenButton.Visible = false
end)

CloseButton.MouseButton1Click:Connect(function()
    Main.Visible = false
    OpenButton.Visible = true
end)

--==================================================
-- INITIALIZATION
--==================================================

OpenButton.Visible = false
Main.Visible = true

updateStats()
updateProgress()

if CONFIG.AUTO_SCAN then
    task.defer(scan)
end
