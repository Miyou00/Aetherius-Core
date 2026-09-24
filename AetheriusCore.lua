--[[
    Client Game Intelligence Analyzer
    ---------------------------------
    Phase 1

    Features:
    • Mobile-first compact UI
    • 15% larger analyzer panel
    • Compact buttons and tabs
    • Incremental instance scanning
    • Attribute scanning
    • CollectionService tag scanning
    • ValueBase scanning
    • Relevant property scanning
    • Object structure storage
    • Player information
    • Compact live status system
    • Pause / Resume
    • Rescan
    • Minimize
    • Draggable analyzer window
    • Draggable floating button
    • High-priority UI layering

    Phase 2.1

    Features:
    • Object classification
    • Classification signal tracking
    • Classification-based object organization
    • Object classification UI
    • Stored classification data
    • Incremental classification for newly detected objects
    • Classification progress monitoring
    • Phase 1 scan data integration

    Phase 2.2

    Features:
    • Object family / group detection
    • Structural family grouping
    • Name-pattern family grouping
    • Family membership tracking
    • Family count tracking
    • Family summary UI
    • Incremental family assignment for newly detected objects
    • Phase 2.1 classification integration
    • Adaptive workload yielding
    • Classification and family lookup caching
    • Debounced intelligence UI updates

    Optimization notes:
    • Uses adaptive time-budgeted batches to reduce frame spikes
    • Uses larger work batches with short yields for better throughput
    • Caches repeated hierarchy and family-name lookups
    • Throttles scan/classification UI refreshes to reduce UI overhead
    • Preserves generation-safe scanning and classification

    Intended for games you own or are authorized to analyze.

    This does NOT:
    • bypass Roblox security
    • access server-only data
    • bypass replication
    • perform arbitrary remote probing
    • perform anti-detection
]]

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local BATCH_SIZE = 300
local YIELD_TIME = 0.015
local SCAN_TIME_BUDGET = 0.012
local SCAN_UI_INTERVAL = 0.12

local MAX_RESULTS = 50000
local MAX_ATTRIBUTES_PER_OBJECT = 100
local MAX_TAGS_PER_OBJECT = 50

local AUTO_SCAN = true

local DISPLAY_ORDER = 2147483647
local BASE_ZINDEX = 100000

--------------------------------------------------
-- REMOVE OLD GUI
--------------------------------------------------

local oldGui = PlayerGui:FindFirstChild("ClientGameAnalyzer")

if oldGui then
	oldGui:Destroy()
end

--------------------------------------------------
-- COLORS
--------------------------------------------------

local COLORS = {
	Background = Color3.fromRGB(18, 20, 27),
	Panel = Color3.fromRGB(27, 30, 40),
	Panel2 = Color3.fromRGB(32, 35, 46),
	Panel3 = Color3.fromRGB(38, 42, 54),

	Accent = Color3.fromRGB(70, 130, 255),
	AccentDark = Color3.fromRGB(52, 103, 210),

	Text = Color3.fromRGB(240, 243, 250),
	Muted = Color3.fromRGB(155, 162, 178),

	Success = Color3.fromRGB(70, 205, 125),
	Warning = Color3.fromRGB(245, 180, 70),
	Error = Color3.fromRGB(235, 85, 85),

	Border = Color3.fromRGB(55, 59, 73)
}

--------------------------------------------------
-- GUI
--------------------------------------------------

local Gui = Instance.new("ScreenGui")

Gui.Name = "ClientGameAnalyzer"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
Gui.DisplayOrder = DISPLAY_ORDER
Gui.Parent = PlayerGui

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function Corner(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
	return corner
end

local function Stroke(object, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.25
	stroke.Parent = object
	return stroke
end

local function MakeText(parent, text, size, color, font)
	local label = Instance.new("TextLabel")

	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or COLORS.Text
	label.TextSize = size or 13
	label.Font = font or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	return label
end

local function MakeButton(parent, text, size)
	local button = Instance.new("TextButton")

	button.AutoButtonColor = true
	button.BackgroundColor3 = COLORS.Panel3
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = COLORS.Text
	button.TextSize = size or 11
	button.Font = Enum.Font.GothamMedium
	button.Parent = parent

	Corner(button, 5)

	return button
end

--------------------------------------------------
-- DATA STORAGE
--------------------------------------------------

local ScanData = {}

local ObjectCount = 0
local AttributeCount = 0
local TagCount = 0
local ValueCount = 0

local ScanPaused = false
local ScanRunning = false
local CurrentScan = 0
local ScanProgress = 0
local ClassificationProgress = 0
local ClassificationScheduled = false
local ClassificationUIUpdateScheduled = false
local LastClassificationUIUpdate = 0

local Statuses = {
	Structure = "WAITING",
	Attributes = "WAITING",
	Tags = "WAITING",
	Values = "WAITING"
}


--------------------------------------------------
-- PHASE 2.1 -- OBJECT CLASSIFICATION
--------------------------------------------------

local CLASSIFICATION_BATCH_SIZE = 350
local PENDING_CLASSIFICATION_BATCH_SIZE = 150
local CLASSIFICATION_YIELD_TIME = 0.015
local CLASSIFICATION_TIME_BUDGET = 0.012
local CLASSIFICATION_UI_INTERVAL = 0.12

local ClassificationData = {}

-- Phase 2.2 family/group intelligence. Each classification record can be
-- assigned to a structural or name-based family for higher-level organization.
local FamilyData = {}
local FamilyCounts = {}
local FamilyCategories = {}
local FamilyOrder = {}

local ClassificationCounts = {
	Character = 0,
	NPC = 0,
	Player = 0,
	Tool = 0,
	UI = 0,
	Interactive = 0,
	Item = 0,
	Container = 0,
	World = 0,
	Effect = 0,
	ValueData = 0,
	System = 0,
	Unknown = 0
}

local ClassificationRunning = false
local ClassificationComplete = false

local PendingInstances = {}
local PendingClassification = {}
local ScannedInstances = {}
local ScanTruncated = false

-- Runtime caches reduce repeated ancestor/name work during classification
-- and family detection. They are cleared for every new scan generation.
local HumanoidAncestorCache = {}
local FamilyRootCache = {}
local NormalizedFamilyNameCache = {}
local BackpackCache = nil

local ResetClassification

local ClassificationOrder = {
	"Character",
	"NPC",
	"Player",
	"Tool",
	"UI",
	"Interactive",
	"Item",
	"Container",
	"World",
	"Effect",
	"ValueData",
	"System",
	"Unknown"
}

--------------------------------------------------
-- SCAN DATA
--------------------------------------------------

local function ClearScanData()
	table.clear(ScanData)
	table.clear(PendingInstances)
	table.clear(PendingClassification)
	table.clear(ScannedInstances)
	table.clear(HumanoidAncestorCache)
	table.clear(FamilyRootCache)
	table.clear(NormalizedFamilyNameCache)
	BackpackCache = nil

	ObjectCount = 0
	AttributeCount = 0
	TagCount = 0
	ValueCount = 0
	ScanTruncated = false

	ResetClassification()
end

local function SafeFullName(instance)
	local success, result = pcall(function()
		return instance:GetFullName()
	end)

	if success then
		return result
	end

	return instance.Name
end

local function SafeAttributes(instance)
	local success, attributes = pcall(function()
		return instance:GetAttributes()
	end)

	if not success or type(attributes) ~= "table" then
		return {}
	end

	return attributes
end

local function SafeTags(instance)
	local success, tags = pcall(function()
		return CollectionService:GetTags(instance)
	end)

	if not success or type(tags) ~= "table" then
		return {}
	end

	return tags
end

--------------------------------------------------
-- RELEVANT PROPERTIES
--------------------------------------------------

local function GetRelevantProperties(instance)

	local properties = {}

	pcall(function()

		if instance:IsA("BasePart") then
			properties.Size = tostring(instance.Size)
			properties.Position = tostring(instance.Position)
			properties.Anchored = instance.Anchored
			properties.CanCollide = instance.CanCollide
			properties.Transparency = instance.Transparency
		end

		if instance:IsA("Humanoid") then
			properties.Health = instance.Health
			properties.MaxHealth = instance.MaxHealth
			properties.WalkSpeed = instance.WalkSpeed
			properties.JumpPower = instance.JumpPower
			properties.HipHeight = instance.HipHeight
		end

		if instance:IsA("Tool") then
			properties.Enabled = instance.Enabled
			properties.ToolTip = instance.ToolTip
		end

		if instance:IsA("TextLabel")
			or instance:IsA("TextButton")
			or instance:IsA("TextBox") then

			properties.Text = instance.Text
			properties.Visible = instance.Visible
		end

		if instance:IsA("ImageLabel")
			or instance:IsA("ImageButton") then

			properties.Image = instance.Image
			properties.Visible = instance.Visible
		end

		if instance:IsA("ProximityPrompt") then
			properties.ActionText = instance.ActionText
			properties.ObjectText = instance.ObjectText
			properties.HoldDuration = instance.HoldDuration
			properties.MaxActivationDistance = instance.MaxActivationDistance
			properties.Enabled = instance.Enabled
		end

	end)

	return properties
end

--------------------------------------------------
-- VALUE
--------------------------------------------------

local function GetValue(instance, isValueBase)
	if not isValueBase then
		return nil
	end

	local success, value = pcall(function()
		return instance.Value
	end)

	if success then
		return value
	end

	return nil
end

--------------------------------------------------
-- STATUS
--------------------------------------------------

local StatusHeader
local StatusDetails

local StatusLabels = {}

local function SetStatus(name, status)

	Statuses[name] = status

	local label = StatusLabels[name]

	if not label then
		return
	end

	label.Text = name .. "    " .. status

	if status == "COMPLETE" then
		label.TextColor3 = COLORS.Success

	elseif status == "RUNNING"
		or status == "PROCESSING" then

		label.TextColor3 = COLORS.Accent

	elseif status == "ERROR" then
		label.TextColor3 = COLORS.Error

	elseif status == "LIMIT" then
		label.TextColor3 = COLORS.Warning

	elseif status == "PAUSED" then
		label.TextColor3 = COLORS.Warning

	else
		label.TextColor3 = COLORS.Muted
	end
end

--------------------------------------------------
-- MAIN WINDOW
--------------------------------------------------

local Main = Instance.new("Frame")

Main.Name = "MainWindow"
Main.Size = UDim2.fromOffset(345, 293)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = COLORS.Background
Main.BorderSizePixel = 0
Main.ZIndex = BASE_ZINDEX
Main.Parent = Gui

Corner(Main, 9)
Stroke(Main, COLORS.Border, 1)

--------------------------------------------------
-- TITLE BAR
--------------------------------------------------

local TitleBar = Instance.new("Frame")

TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 32)
TitleBar.BackgroundColor3 = COLORS.Panel
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = BASE_ZINDEX + 1
TitleBar.Parent = Main

Corner(TitleBar, 9)

local Title = MakeText(
	TitleBar,
	"Client Game Analyzer",
	12,
	COLORS.Text,
	Enum.Font.GothamBold
)

Title.Position = UDim2.fromOffset(12, 0)
Title.Size = UDim2.new(1, -75, 1, 0)
Title.ZIndex = BASE_ZINDEX + 2

local MinimizeButton = MakeButton(
	TitleBar,
	"−",
	15
)

MinimizeButton.Size = UDim2.fromOffset(24, 24)
MinimizeButton.Position = UDim2.new(1, -57, 0.5, -12)
MinimizeButton.BackgroundColor3 = COLORS.Panel3
MinimizeButton.ZIndex = BASE_ZINDEX + 2

local CloseButton = MakeButton(
	TitleBar,
	"×",
	15
)

CloseButton.Size = UDim2.fromOffset(24, 24)
CloseButton.Position = UDim2.new(1, -29, 0.5, -12)
CloseButton.BackgroundColor3 = COLORS.Panel3
CloseButton.ZIndex = BASE_ZINDEX + 2

--------------------------------------------------
-- STATUS HEADER
--------------------------------------------------

StatusHeader = Instance.new("Frame")

StatusHeader.Name = "StatusHeader"
StatusHeader.Size = UDim2.new(1, -16, 0, 27)
StatusHeader.Position = UDim2.fromOffset(8, 36)
StatusHeader.BackgroundColor3 = COLORS.Panel2
StatusHeader.BorderSizePixel = 0
StatusHeader.ZIndex = BASE_ZINDEX + 1
StatusHeader.Parent = Main

Corner(StatusHeader, 6)

local OverallStatus = MakeText(
	StatusHeader,
	"● READY",
	9,
	COLORS.Success,
	Enum.Font.GothamBold
)

OverallStatus.Position = UDim2.fromOffset(9, 0)
OverallStatus.Size = UDim2.new(1, -100, 1, 0)
OverallStatus.ZIndex = BASE_ZINDEX + 3

local ProgressLabel = MakeText(
	StatusHeader,
	"0%",
	10,
	COLORS.Muted,
	Enum.Font.GothamMedium
)

ProgressLabel.Size = UDim2.fromOffset(58, 27)
ProgressLabel.Position = UDim2.new(1, -86, 0, 0)
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Right
ProgressLabel.ZIndex = BASE_ZINDEX + 3

local StatusExpand = MakeButton(
	StatusHeader,
	"▼",
	9
)

StatusExpand.Size = UDim2.fromOffset(20, 20)
StatusExpand.Position = UDim2.new(1, -26, 0.5, -10)
StatusExpand.BackgroundTransparency = 1
StatusExpand.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- STATUS DETAILS
--------------------------------------------------

StatusDetails = Instance.new("Frame")

StatusDetails.Name = "StatusDetails"
StatusDetails.Size = UDim2.new(1, -16, 0, 0)
StatusDetails.Position = UDim2.fromOffset(8, 79)
StatusDetails.BackgroundColor3 = COLORS.Panel2
StatusDetails.BorderSizePixel = 0
StatusDetails.ClipsDescendants = true
StatusDetails.Visible = false
StatusDetails.ZIndex = BASE_ZINDEX + 1
StatusDetails.Parent = Main

Corner(StatusDetails, 6)

local statusNames = {
	"Structure",
	"Attributes",
	"Tags",
	"Values"
}

for i, name in ipairs(statusNames) do

	local label = MakeText(
		StatusDetails,
		name .. "    WAITING",
		10,
		COLORS.Muted,
		Enum.Font.GothamMedium
	)

	label.Position = UDim2.fromOffset(
		10,
		(i - 1) * 21
	)

	label.Size = UDim2.new(1, -20, 0, 20)
	label.ZIndex = BASE_ZINDEX + 3

	StatusLabels[name] = label
end

--------------------------------------------------
-- TAB BAR
--------------------------------------------------

local TabBar = Instance.new("Frame")

TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -16, 0, 22)
TabBar.Position = UDim2.fromOffset(8, 65)
TabBar.BackgroundTransparency = 1
TabBar.ZIndex = BASE_ZINDEX + 2
TabBar.Parent = Main

local TabLayout = Instance.new("UIListLayout")

TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0, 2)
TabLayout.Parent = TabBar

--------------------------------------------------
-- CONTENT
--------------------------------------------------

local Content = Instance.new("Frame")

Content.Name = "Content"

-- Bottom of Content is deliberately kept above BottomBar.
Content.Size = UDim2.new(1, -16, 0, 158)
Content.Position = UDim2.fromOffset(8, 91)

Content.BackgroundColor3 = COLORS.Panel
Content.BorderSizePixel = 0
Content.ZIndex = BASE_ZINDEX + 1
Content.Parent = Main

Corner(Content, 6)

--------------------------------------------------
-- BOTTOM BAR
--------------------------------------------------

local BottomBar = Instance.new("Frame")

BottomBar.Name = "BottomBar"

-- Dedicated area for the controls.
BottomBar.Size = UDim2.new(1, -16, 0, 27)
BottomBar.Position = UDim2.new(0, 8, 1, -34)

BottomBar.BackgroundTransparency = 1
BottomBar.ZIndex = BASE_ZINDEX + 5
BottomBar.Parent = Main

--------------------------------------------------
-- TABS
--------------------------------------------------

local TabButtons = {}
local Pages = {}

local TabNames = {
	"Overview",
	"Objects",
	"Player",
	"Relations",
	"Behavior",
	"Remotes",
	"Data"
}

local function CreatePage(name)

	local page = Instance.new("Frame")

	page.Name = name .. "Page"
	page.Size = UDim2.new(1, -12, 1, -12)
	page.Position = UDim2.fromOffset(6, 6)

	page.BackgroundTransparency = 1
	page.Visible = false

	page.ZIndex = BASE_ZINDEX + 2
	page.Parent = Content

	Pages[name] = page

	return page
end

for _, name in ipairs(TabNames) do

	local button = MakeButton(
		TabBar,
		name,
		7
	)

	button.Size = UDim2.new(
		1 / #TabNames,
		-2,
		0,
		20
	)

	button.BackgroundColor3 = COLORS.Panel3
	button.ZIndex = BASE_ZINDEX + 3

	TabButtons[name] = button

	CreatePage(name)
end

--------------------------------------------------
-- PAGE SWITCHING
--------------------------------------------------

local function ShowPage(name)

	for pageName, page in pairs(Pages) do
		page.Visible = pageName == name
	end

	for buttonName, button in pairs(TabButtons) do

		if buttonName == name then
			button.BackgroundColor3 = COLORS.Accent
		else
			button.BackgroundColor3 = COLORS.Panel3
		end

	end
end

for name, button in pairs(TabButtons) do

	button.MouseButton1Click:Connect(function()
		ShowPage(name)
	end)

end

--------------------------------------------------
-- OVERVIEW PAGE
--------------------------------------------------

local OverviewPage = Pages.Overview

local OverviewTitle = MakeText(
	OverviewPage,
	"Scan Overview",
	13,
	COLORS.Text,
	Enum.Font.GothamBold
)

OverviewTitle.Size = UDim2.new(1, 0, 0, 24)
OverviewTitle.ZIndex = BASE_ZINDEX + 3

local OverviewHint = MakeText(
	OverviewPage,
	"Client-visible data collected during the scan.",
	10,
	COLORS.Muted
)

OverviewHint.Position = UDim2.fromOffset(0, 24)
OverviewHint.Size = UDim2.new(1, 0, 0, 20)
OverviewHint.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- STAT CARDS
--------------------------------------------------

local StatContainer = Instance.new("Frame")

StatContainer.Name = "StatContainer"

-- IMPORTANT:
-- The cards are now restricted to a smaller area.
-- This keeps their bottom edge above Pause/Rescan.
StatContainer.Size = UDim2.new(1, 0, 0, 78)
StatContainer.Position = UDim2.fromOffset(0, 50)

StatContainer.BackgroundTransparency = 1
StatContainer.ZIndex = BASE_ZINDEX + 2
StatContainer.Parent = OverviewPage

local StatLayout = Instance.new("UIGridLayout")

StatLayout.CellSize = UDim2.new(
	0.5,
	-4,
	0,
	35
)

StatLayout.CellPadding = UDim2.fromOffset(
	8,
	6
)

StatLayout.Parent = StatContainer

local StatLabels = {}

local function CreateStat(name, initial)

	local frame = Instance.new("Frame")

	frame.BackgroundColor3 = COLORS.Panel2
	frame.BorderSizePixel = 0
	frame.ZIndex = BASE_ZINDEX + 2
	frame.Parent = StatContainer

	Corner(frame, 5)

	local nameLabel = MakeText(
		frame,
		name,
		9,
		COLORS.Muted
	)

	nameLabel.Position = UDim2.fromOffset(8, 2)
	nameLabel.Size = UDim2.new(
		1,
		-16,
		0,
		13
	)

	nameLabel.ZIndex = BASE_ZINDEX + 3

	local valueLabel = MakeText(
		frame,
		tostring(initial),
		12,
		COLORS.Text,
		Enum.Font.GothamBold
	)

	valueLabel.Position = UDim2.fromOffset(8, 15)
	valueLabel.Size = UDim2.new(
		1,
		-16,
		0,
		17
	)

	valueLabel.ZIndex = BASE_ZINDEX + 3

	StatLabels[name] = valueLabel

	return frame
end

CreateStat("Objects", 0)
CreateStat("Attributes", 0)
CreateStat("Tags", 0)
CreateStat("Values", 0)

--------------------------------------------------
-- OBJECTS PAGE
--------------------------------------------------

local ObjectsPage = Pages.Objects

local ObjectsTitle = MakeText(
	ObjectsPage,
	"Object Intelligence",
	10,
	COLORS.Text,
	Enum.Font.GothamBold
)

ObjectsTitle.Size = UDim2.new(1, 0, 0, 17)
ObjectsTitle.ZIndex = BASE_ZINDEX + 3

local ObjectsSummary = MakeText(
	ObjectsPage,
	"Phase 1 + Phase 2.1 classification + Phase 2.2 families.",
	8,
	COLORS.Muted
)

ObjectsSummary.Position = UDim2.fromOffset(0, 16)
ObjectsSummary.Size = UDim2.new(1, 0, 0, 12)
ObjectsSummary.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- OBJECT VIEW SWITCH
--------------------------------------------------

local ClassificationModeButton = MakeButton(
	ObjectsPage,
	"Classification",
	9
)

ClassificationModeButton.Name = "ClassificationModeButton"
ClassificationModeButton.Size = UDim2.new(1 / 3, -3, 0, 18)
ClassificationModeButton.Position = UDim2.fromOffset(0, 30)
ClassificationModeButton.ZIndex = BASE_ZINDEX + 10

local StructureModeButton = MakeButton(
	ObjectsPage,
	"Structure",
	9
)

StructureModeButton.Name = "StructureModeButton"
StructureModeButton.Size = UDim2.new(1 / 3, -3, 0, 18)
StructureModeButton.Position = UDim2.new(1 / 3, 1, 0, 30)
StructureModeButton.ZIndex = BASE_ZINDEX + 10

local FamilyModeButton = MakeButton(
	ObjectsPage,
	"Families",
	9
)

FamilyModeButton.Name = "FamilyModeButton"
FamilyModeButton.Size = UDim2.new(1 / 3, -3, 0, 18)
FamilyModeButton.Position = UDim2.new(2 / 3, 2, 0, 30)
FamilyModeButton.ZIndex = BASE_ZINDEX + 10

--------------------------------------------------
-- STRUCTURE VIEW
--------------------------------------------------

local StructureFrame = Instance.new("Frame")
StructureFrame.Name = "StructureFrame"
StructureFrame.Size = UDim2.new(1, 0, 1, -52)
StructureFrame.Position = UDim2.fromOffset(0, 52)
StructureFrame.BackgroundColor3 = COLORS.Panel2
StructureFrame.BorderSizePixel = 0
StructureFrame.ZIndex = BASE_ZINDEX + 2
StructureFrame.Parent = ObjectsPage
Corner(StructureFrame, 5)

local StructureLabel = MakeText(
	StructureFrame,
	"Structure summary",
	9,
	COLORS.Text,
	Enum.Font.GothamBold
)

StructureLabel.Position = UDim2.fromOffset(9, 6)
StructureLabel.Size = UDim2.new(1, -18, 0, 20)
StructureLabel.ZIndex = BASE_ZINDEX + 3

local StructureInfo = MakeText(
	StructureFrame,
	"Waiting for scan...",
	8,
	COLORS.Muted
)

StructureInfo.Position = UDim2.fromOffset(9, 30)
StructureInfo.Size = UDim2.new(1, -18, 1, -36)
StructureInfo.TextYAlignment = Enum.TextYAlignment.Top
StructureInfo.TextWrapped = true
StructureInfo.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- CLASSIFICATION VIEW
--------------------------------------------------

local ClassificationFrame = Instance.new("Frame")

ClassificationFrame.Name = "ClassificationFrame"
ClassificationFrame.Size = UDim2.new(1, 0, 1, -52)
ClassificationFrame.Position = UDim2.fromOffset(0, 52)
ClassificationFrame.BackgroundColor3 = COLORS.Panel2
ClassificationFrame.BorderSizePixel = 0
ClassificationFrame.ZIndex = BASE_ZINDEX + 2
ClassificationFrame.Parent = ObjectsPage

Corner(ClassificationFrame, 5)

-- Use the full available area for the classification list.
local ClassificationScroll = Instance.new("ScrollingFrame")
ClassificationScroll.Name = "ClassificationScroll"
ClassificationScroll.Size = UDim2.new(1, -8, 1, -8)
ClassificationScroll.Position = UDim2.fromOffset(4, 4)
ClassificationScroll.BackgroundTransparency = 1
ClassificationScroll.BorderSizePixel = 0
ClassificationScroll.ScrollBarThickness = 3
ClassificationScroll.CanvasSize = UDim2.fromOffset(0, 0)
ClassificationScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ClassificationScroll.ZIndex = BASE_ZINDEX + 2
ClassificationScroll.Parent = ClassificationFrame

--------------------------------------------------
-- FAMILY VIEW
--------------------------------------------------

local FamilyFrame = Instance.new("Frame")
FamilyFrame.Name = "FamilyFrame"
FamilyFrame.Size = UDim2.new(1, 0, 1, -52)
FamilyFrame.Position = UDim2.fromOffset(0, 52)
FamilyFrame.BackgroundColor3 = COLORS.Panel2
FamilyFrame.BorderSizePixel = 0
FamilyFrame.ZIndex = BASE_ZINDEX + 2
FamilyFrame.Parent = ObjectsPage
Corner(FamilyFrame, 5)

local FamilyScroll = Instance.new("ScrollingFrame")
FamilyScroll.Name = "FamilyScroll"
FamilyScroll.Size = UDim2.new(1, -8, 1, -8)
FamilyScroll.Position = UDim2.fromOffset(4, 4)
FamilyScroll.BackgroundTransparency = 1
FamilyScroll.BorderSizePixel = 0
FamilyScroll.ScrollBarThickness = 3
FamilyScroll.CanvasSize = UDim2.fromOffset(0, 0)
FamilyScroll.ScrollingDirection = Enum.ScrollingDirection.Y
FamilyScroll.ZIndex = BASE_ZINDEX + 2
FamilyScroll.Parent = FamilyFrame

-- Rows are positioned manually so the compact mobile layout
-- remains visible reliably on all screen sizes.
local ClassificationRowHeight = 16
local ClassificationRowGap = 2
local ClassificationColumnGap = 4

local ObjectsPageMode = "Classification"

local function UpdateObjectsPageMode()
	local showingClassification = ObjectsPageMode == "Classification"
	local showingStructure = ObjectsPageMode == "Structure"
	local showingFamilies = ObjectsPageMode == "Families"

	ClassificationFrame.Visible = showingClassification
	StructureFrame.Visible = showingStructure
	FamilyFrame.Visible = showingFamilies

	ClassificationModeButton.BackgroundColor3 = showingClassification and COLORS.Accent or COLORS.Panel3
	ClassificationModeButton.TextColor3 = showingClassification and Color3.new(1, 1, 1) or COLORS.Text

	StructureModeButton.BackgroundColor3 = showingStructure and COLORS.Accent or COLORS.Panel3
	StructureModeButton.TextColor3 = showingStructure and Color3.new(1, 1, 1) or COLORS.Text

	FamilyModeButton.BackgroundColor3 = showingFamilies and COLORS.Accent or COLORS.Panel3
	FamilyModeButton.TextColor3 = showingFamilies and Color3.new(1, 1, 1) or COLORS.Text
end

ClassificationModeButton.MouseButton1Click:Connect(function()
	ObjectsPageMode = "Classification"
	UpdateObjectsPageMode()
end)

StructureModeButton.MouseButton1Click:Connect(function()
	ObjectsPageMode = "Structure"
	UpdateObjectsPageMode()
end)

FamilyModeButton.MouseButton1Click:Connect(function()
	ObjectsPageMode = "Families"
	UpdateObjectsPageMode()
end)

UpdateObjectsPageMode()

--------------------------------------------------
-- PLAYER PAGE
--------------------------------------------------

local PlayerPage = Pages.Player

local PlayerTitle = MakeText(
	PlayerPage,
	"Player State",
	13,
	COLORS.Text,
	Enum.Font.GothamBold
)

PlayerTitle.Size = UDim2.new(1, 0, 0, 24)
PlayerTitle.ZIndex = BASE_ZINDEX + 3

local PlayerInfo = MakeText(
	PlayerPage,
	"",
	10,
	COLORS.Muted
)

PlayerInfo.Position = UDim2.fromOffset(0, 28)
PlayerInfo.Size = UDim2.new(1, 0, 1, -28)
PlayerInfo.TextYAlignment = Enum.TextYAlignment.Top
PlayerInfo.TextWrapped = true
PlayerInfo.ZIndex = BASE_ZINDEX + 3

local function UpdatePlayerInfo()

	local character = LocalPlayer.Character

	local humanoid =
		character
		and character:FindFirstChildOfClass("Humanoid")

	local lines = {}

	table.insert(
		lines,
		"Name: " .. LocalPlayer.Name
	)

	table.insert(
		lines,
		"UserId: " .. tostring(LocalPlayer.UserId)
	)

	table.insert(
		lines,
		"Character: "
			.. (character and character.Name or "None")
	)

	if humanoid then

		table.insert(lines, "")

		table.insert(
			lines,
			"Health: "
				.. tostring(humanoid.Health)
		)

		table.insert(
			lines,
			"MaxHealth: "
				.. tostring(humanoid.MaxHealth)
		)

		table.insert(
			lines,
			"WalkSpeed: "
				.. tostring(humanoid.WalkSpeed)
		)

		table.insert(
			lines,
			"JumpPower: "
				.. tostring(humanoid.JumpPower)
		)

	end

	PlayerInfo.Text =
		table.concat(lines, "\n")
end

UpdatePlayerInfo()

--------------------------------------------------
-- RELATIONS PAGE
--------------------------------------------------

local RelationsPage = Pages.Relations

local RelationsTitle = MakeText(
	RelationsPage,
	"Relations",
	13,
	COLORS.Text,
	Enum.Font.GothamBold
)

RelationsTitle.Size = UDim2.new(1, 0, 0, 24)
RelationsTitle.ZIndex = BASE_ZINDEX + 3

local RelationsInfo = MakeText(
	RelationsPage,
	"Relationship detection will be added in a later phase.",
	10,
	COLORS.Muted
)

RelationsInfo.Position = UDim2.fromOffset(0, 28)
RelationsInfo.Size = UDim2.new(1, 0, 0, 40)
RelationsInfo.TextWrapped = true
RelationsInfo.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- BEHAVIOR PAGE
--------------------------------------------------

local BehaviorPage = Pages.Behavior

local BehaviorTitle = MakeText(
	BehaviorPage,
	"Behavior",
	13,
	COLORS.Text,
	Enum.Font.GothamBold
)

BehaviorTitle.Size = UDim2.new(1, 0, 0, 24)
BehaviorTitle.ZIndex = BASE_ZINDEX + 3

local BehaviorInfo = MakeText(
	BehaviorPage,
	"Dynamic state monitoring will be added in a later phase.",
	10,
	COLORS.Muted
)

BehaviorInfo.Position = UDim2.fromOffset(0, 28)
BehaviorInfo.Size = UDim2.new(1, 0, 0, 40)
BehaviorInfo.TextWrapped = true
BehaviorInfo.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- REMOTES PAGE
--------------------------------------------------

local RemotesPage = Pages.Remotes

local RemotesTitle = MakeText(
	RemotesPage,
	"Remotes",
	13,
	COLORS.Text,
	Enum.Font.GothamBold
)

RemotesTitle.Size = UDim2.new(1, 0, 0, 24)
RemotesTitle.ZIndex = BASE_ZINDEX + 3

local RemotesInfo = MakeText(
	RemotesPage,
	"Remote observation will be added in a later phase.",
	10,
	COLORS.Muted
)

RemotesInfo.Position = UDim2.fromOffset(0, 28)
RemotesInfo.Size = UDim2.new(1, 0, 0, 40)
RemotesInfo.TextWrapped = true
RemotesInfo.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- DATA PAGE
--------------------------------------------------

local DataPage = Pages.Data

local DataTitle = MakeText(
	DataPage,
	"Stored Data",
	13,
	COLORS.Text,
	Enum.Font.GothamBold
)

DataTitle.Size = UDim2.new(1, 0, 0, 24)
DataTitle.ZIndex = BASE_ZINDEX + 3

local DataInfo = MakeText(
	DataPage,
	"",
	10,
	COLORS.Muted
)

DataInfo.Position = UDim2.fromOffset(0, 28)
DataInfo.Size = UDim2.new(1, 0, 1, -28)
DataInfo.TextYAlignment = Enum.TextYAlignment.Top
DataInfo.TextWrapped = true
DataInfo.ZIndex = BASE_ZINDEX + 3

--------------------------------------------------
-- BOTTOM CONTROLS
--------------------------------------------------

local PauseButton = MakeButton(
	BottomBar,
	"Pause",
	10
)

PauseButton.Size = UDim2.fromOffset(62, 27)

-- Bottom-right
PauseButton.Position = UDim2.new(
	1,
	-134,
	0,
	2
)

PauseButton.ZIndex = BASE_ZINDEX + 10

local RescanButton = MakeButton(
	BottomBar,
	"Rescan",
	10
)

RescanButton.Size = UDim2.fromOffset(62, 27)

-- Bottom-right
RescanButton.Position = UDim2.new(
	1,
	-66,
	0,
	2
)

RescanButton.ZIndex = BASE_ZINDEX + 10

--------------------------------------------------
-- FLOATING BUTTON
--------------------------------------------------

local OpenButton = MakeButton(
	Gui,
	"AI",
	12
)

OpenButton.Name = "AnalyzerOpenButton"

OpenButton.Size =
	UDim2.fromOffset(46, 46)

OpenButton.Position =
	UDim2.new(
		1,
		-65,
		0.5,
		-23
	)

OpenButton.BackgroundColor3 =
	COLORS.Accent

OpenButton.TextColor3 =
	Color3.new(1, 1, 1)

OpenButton.Font =
	Enum.Font.GothamBold

OpenButton.ZIndex =
	BASE_ZINDEX + 50

OpenButton.Parent = Gui

Corner(OpenButton, 23)

--------------------------------------------------
-- DRAGGING
--------------------------------------------------

local function MakeDraggable(object, handle)

	local dragging = false
	local dragStart
	local startPosition

	handle = handle or object

	handle.InputBegan:Connect(function(input)

		if input.UserInputType ==
			Enum.UserInputType.MouseButton1
			or input.UserInputType ==
			Enum.UserInputType.Touch then

			dragging = true
			dragStart = input.Position
			startPosition = object.Position

			input.Changed:Connect(function()

				if input.UserInputState ==
					Enum.UserInputState.End then

					dragging = false
				end

			end)
		end
	end)

	handle.InputChanged:Connect(function(input)

		if not dragging then
			return
		end

		if input.UserInputType ~=
			Enum.UserInputType.MouseMovement
			and input.UserInputType ~=
			Enum.UserInputType.Touch then

			return
		end

		local delta =
			input.Position - dragStart

		object.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)
end

MakeDraggable(Main, TitleBar)
MakeDraggable(OpenButton, OpenButton)

--------------------------------------------------
-- STATUS EXPANSION
--------------------------------------------------

local StatusExpanded = false
local UpdateMainWidth

local function UpdateStatusLayout()

	if StatusExpanded then

		StatusDetails.Visible = true

		StatusDetails.Size =
			UDim2.new(
				1,
				-16,
				0,
				84
			)

		TabBar.Position =
			UDim2.fromOffset(
				8,
				165
			)

		-- Expanded status details use extra vertical space while leaving
		-- a clear gap above the BottomBar controls.
		Content.Position =
			UDim2.fromOffset(
				8,
				195
			)

		Content.Size =
			UDim2.new(
				1,
				-16,
				0,
				138
			)

		BottomBar.Position = UDim2.new(0, 8, 1, -34)

		StatusExpand.Text = "▲"

		if UpdateMainWidth then
			UpdateMainWidth()
		end

	else

		StatusDetails.Visible = false

		StatusDetails.Size =
			UDim2.new(
				1,
				-16,
				0,
				0
			)

		TabBar.Position =
			UDim2.fromOffset(
				8,
				65
			)

		Content.Position =
			UDim2.fromOffset(
				8,
				91
			)

		Content.Size =
			UDim2.new(
				1,
				-16,
				0,
				158
			)

		StatusExpand.Text = "▼"

		if UpdateMainWidth then
			UpdateMainWidth()
		end
	end
end

StatusExpand.MouseButton1Click:Connect(function()

	StatusExpanded =
		not StatusExpanded

	UpdateStatusLayout()

end)

--------------------------------------------------
-- OVERALL STATUS
--------------------------------------------------

local function UpdateOverallStatus(status, progress)
	progress = math.clamp(tonumber(progress) or 0, 0, 100)

	if status == "ANALYZING" or status == "PROCESSING" then
		ScanProgress = progress
	elseif status == "CLASSIFYING" then
		ClassificationProgress = progress
	elseif status == "PAUSED" then
		-- The caller provides the active phase progress when pausing.
		if ClassificationRunning or ClassificationScheduled then
			ClassificationProgress = progress
		else
			ScanProgress = progress
		end
	end

	OverallStatus.Text = "● " .. status

	local displayProgress = progress
	if status == "ANALYZING" or status == "PROCESSING" then
		displayProgress = ScanProgress
	elseif status == "CLASSIFYING" then
		displayProgress = ClassificationProgress
	elseif status == "PAUSED" then
		displayProgress = (ClassificationRunning or ClassificationScheduled) and ClassificationProgress or ScanProgress
	end

	local progressText = tostring(math.floor(displayProgress)) .. "%"

	if status == "ANALYZING" or status == "PROCESSING" then
		progressText = "SCAN " .. progressText
	elseif status == "CLASSIFYING" then
		progressText = "CLASS " .. progressText
	elseif status == "COMPLETE" then
		progressText = "DONE"
	elseif status == "PAUSED" then
		progressText = "PAUSED " .. progressText
	end

	ProgressLabel.Text = progressText

	if status == "COMPLETE" then
		OverallStatus.TextColor3 = COLORS.Success
	elseif status == "ANALYZING"
		or status == "PROCESSING"
		or status == "CLASSIFYING" then
		OverallStatus.TextColor3 = COLORS.Accent
	elseif status == "PAUSED" then
		OverallStatus.TextColor3 = COLORS.Warning
	elseif status == "ERROR" then
		OverallStatus.TextColor3 = COLORS.Error
	elseif status == "LIMIT" then
		OverallStatus.TextColor3 = COLORS.Warning
	else
		OverallStatus.TextColor3 = COLORS.Muted
	end
end
--------------------------------------------------
-- UPDATE COUNTERS
--------------------------------------------------

local function UpdateCounters()

	StatLabels.Objects.Text =
		tostring(ObjectCount)

	StatLabels.Attributes.Text =
		tostring(AttributeCount)

	StatLabels.Tags.Text =
		tostring(TagCount)

	StatLabels.Values.Text =
		tostring(ValueCount)

	StructureInfo.Text =
		"Objects: "
		.. tostring(ObjectCount)
		.. "\n"
		.. "Attributes: "
		.. tostring(AttributeCount)
		.. "\n"
		.. "Tags: "
		.. tostring(TagCount)
		.. "\n"
		.. "Value objects: "
		.. tostring(ValueCount)

	DataInfo.Text =
		"Objects stored: "
		.. tostring(ObjectCount)
		.. "\n"
		.. "Attributes scanned: "
		.. tostring(AttributeCount)
		.. "\n"
		.. "Tags scanned: "
		.. tostring(TagCount)
		.. "\n"
		.. "Values detected: "
		.. tostring(ValueCount)
		.. "\n\n"
		.. "Classification: "
		.. (ClassificationComplete and "COMPLETE" or "WAITING")
		.. "\n"
		.. "Stored object limit: "
		.. tostring(MAX_RESULTS)
		.. "\n"
		.. "Families detected: "
		.. tostring(#FamilyOrder)
		.. "\n"
		.. "Scan limit status: "
		.. (ScanTruncated and "TRUNCATED" or "FULL")
end

--------------------------------------------------
-- SCAN ONE INSTANCE
--------------------------------------------------

local function ScanInstance(instance)

	if not instance or not instance.Parent then
		return nil
	end

	if not instance:IsDescendantOf(workspace) then
		return nil
	end

	if ScannedInstances[instance] then
		return ScannedInstances[instance]
	end

	if #ScanData >= MAX_RESULTS then
		ScanTruncated = true
		return nil
	end

	local attributes =
		SafeAttributes(instance)

	local tags =
		SafeTags(instance)

	local properties =
		GetRelevantProperties(instance)

	local isValueBase = instance:IsA("ValueBase")
	local value =
		GetValue(instance, isValueBase)

	local attributeCountForObject = 0

	local limitedAttributes = {}

	for name, attributeValue
		in pairs(attributes) do

		attributeCountForObject += 1

		if attributeCountForObject
			<= MAX_ATTRIBUTES_PER_OBJECT then

			limitedAttributes[name] =
				attributeValue
		end
	end

	local tagCountForObject = 0
	local limitedTags = {}

	for _, tag in ipairs(tags) do

		tagCountForObject += 1

		if tagCountForObject
			<= MAX_TAGS_PER_OBJECT then

			limitedTags[tagCountForObject] = tag
		end
	end

	local record = {

		Instance = instance,

		Name = instance.Name,

		ClassName = instance.ClassName,

		FullName =
			SafeFullName(instance),

		Parent =
			instance.Parent,

		ParentName =
			instance.Parent
			and instance.Parent.Name
			or nil,

		Attributes =
			limitedAttributes,

		Tags =
			limitedTags,

		Properties =
			properties,

		Value =
			value
	}

	table.insert(
		ScanData,
		record
	)

	ObjectCount += 1

	AttributeCount +=
		attributeCountForObject

	TagCount +=
		tagCountForObject

	if isValueBase then
		ValueCount += 1
	end

	ScannedInstances[instance] = record
	return record
end

--------------------------------------------------
-- PHASE 2.1 -- CLASSIFICATION HELPERS
--------------------------------------------------

ResetClassification = function()
	table.clear(ClassificationData)
	table.clear(FamilyData)
	table.clear(FamilyCounts)
	table.clear(FamilyCategories)
	table.clear(FamilyOrder)

	for category in pairs(ClassificationCounts) do
		ClassificationCounts[category] = 0
	end

	ClassificationComplete = false
end

local function AddClassificationSignal(signals, text)
	if not table.find(signals, text) then
		table.insert(signals, text)
	end
end

local function IsLocalPlayerCharacter(instance)
	local character = LocalPlayer.Character

	if not character then
		return false
	end

	return instance == character or instance:IsDescendantOf(character)
end

local function HasHumanoidAncestor(instance)
	if HumanoidAncestorCache[instance] ~= nil then
		return HumanoidAncestorCache[instance]
	end

	local current = instance
	local found = false
	local visited = {}

	while current and current ~= workspace do
		local cached = HumanoidAncestorCache[current]
		if cached ~= nil then
			found = cached
			break
		end

		table.insert(visited, current)

		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			found = true
			break
		end

		current = current.Parent
	end

	for _, visitedInstance in ipairs(visited) do
		HumanoidAncestorCache[visitedInstance] = found
	end

	HumanoidAncestorCache[instance] = found
	return found
end

local function NameContainsAny(instance, words)
	local name = string.lower(instance.Name)

	for _, word in ipairs(words) do
		if string.find(name, word, 1, true) then
			return true
		end
	end

	return false
end

local function ClassifyObject(record)
	local instance = record.Instance
	local signals = {}

	if not instance or not instance.Parent then
		return "Unknown", {"Instance unavailable"}
	end

	-- Keep Player for the character model itself. Specific descendants retain
	-- their more useful categories.
	if IsLocalPlayerCharacter(instance) then
		local character = LocalPlayer.Character
		if instance == character then
			AddClassificationSignal(signals, "LocalPlayer character")
			return "Player", signals
		end
		if instance:IsA("Tool") then
			AddClassificationSignal(signals, "Tool inside local character")
			return "Tool", signals
		end
		if instance:IsA("GuiObject") or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui") then
			AddClassificationSignal(signals, "UI inside local character")
			return "UI", signals
		end
		if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
			or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles")
			or instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight")
			or instance:IsA("Sound") then
			AddClassificationSignal(signals, "Effect inside local character")
			return "Effect", signals
		end
		AddClassificationSignal(signals, "Inside local player character")
		return "Character", signals
	end

	-- Humanoid itself.
	if instance:IsA("Humanoid") then
		AddClassificationSignal(signals, "Humanoid")
		return "Character", signals
	end

	-- Character/NPC models.
	if instance:IsA("Model") then
		local humanoid = instance:FindFirstChildOfClass("Humanoid")

		if humanoid then
			AddClassificationSignal(signals, "Model contains Humanoid")
			AddClassificationSignal(signals, "Character-like model")
			return "NPC", signals
		end
	end

	if HasHumanoidAncestor(instance) then
		AddClassificationSignal(signals, "Inside character hierarchy")
		return "Character", signals
	end

	-- Tools.
	if instance:IsA("Tool") then
		AddClassificationSignal(signals, "Tool instance")
		return "Tool", signals
	end

	if not BackpackCache then
		BackpackCache = LocalPlayer:FindFirstChildOfClass("Backpack")
	end

	local backpack = BackpackCache

	if backpack and instance:IsDescendantOf(backpack) then
		AddClassificationSignal(signals, "Inside local Backpack")
		return "Tool", signals
	end

	-- UI.
	if instance:IsA("GuiObject")
		or instance:IsA("ScreenGui")
		or instance:IsA("BillboardGui")
		or instance:IsA("SurfaceGui") then

		AddClassificationSignal(signals, "GUI object")
		return "UI", signals
	end

	-- Interactive objects.
	if instance:IsA("ProximityPrompt")
		or instance:IsA("ClickDetector")
		or instance:IsA("Seat")
		or instance:IsA("VehicleSeat") then

		AddClassificationSignal(signals, "Interaction-capable instance")
		return "Interactive", signals
	end

	-- Effects.
	if instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Beam")
		or instance:IsA("Smoke")
		or instance:IsA("Fire")
		or instance:IsA("Sparkles")
		or instance:IsA("PointLight")
		or instance:IsA("SpotLight")
		or instance:IsA("SurfaceLight")
		or instance:IsA("Sound") then

		AddClassificationSignal(signals, "Visual/audio effect")
		return "Effect", signals
	end

	-- Value/data objects.
	if instance:IsA("ValueBase") then
		AddClassificationSignal(signals, "ValueBase")
		return "ValueData", signals
	end

	if next(record.Attributes or {}) then
		AddClassificationSignal(signals, "Has attributes")
	end

	-- Item-like objects.
	if NameContainsAny(instance, {
		"item",
		"weapon",
		"sword",
		"gun",
		"armor",
		"gear",
		"pet",
		"egg",
		"coin",
		"gem",
		"drop",
		"loot"
	}) then
		AddClassificationSignal(signals, "Item-like name")

		if instance:IsA("Model") or instance:IsA("BasePart") then
			return "Item", signals
		end
	end

	-- System-like objects.
	if NameContainsAny(instance, {
		"system",
		"manager",
		"controller",
		"service",
		"module",
		"handler",
		"config",
		"settings"
	}) then
		AddClassificationSignal(signals, "System-like name")

		if instance:IsA("Folder")
			or instance:IsA("ModuleScript")
			or instance:IsA("Configuration") then

			return "System", signals
		end
	end

	-- Containers.
	if instance:IsA("Folder")
		or instance:IsA("Configuration")
		or instance:IsA("Model") then

		AddClassificationSignal(signals, "Container-like instance")
		return "Container", signals
	end

	-- World geometry.
	if instance:IsA("BasePart")
		or instance:IsA("Terrain") then

		AddClassificationSignal(signals, "World geometry")
		return "World", signals
	end

	AddClassificationSignal(signals, "No strong classification signal")

	return "Unknown", signals
end

local function NormalizeFamilyName(name)
	name = tostring(name or "")
	local cached = NormalizedFamilyNameCache[name]
	if cached then
		return cached
	end

	local normalized = name
	normalized = string.gsub(normalized, "[%d_%-]+$", "")
	normalized = string.gsub(normalized, "(%s+)(%d+)$", "")
	normalized = string.gsub(normalized, "[%[%]%(%){}]", "")
	normalized = string.gsub(normalized, "%s+", " ")
	normalized = string.gsub(normalized, "^%s+", "")
	normalized = string.gsub(normalized, "%s+$", "")

	if normalized == "" then
		normalized = "Unnamed"
	end

	NormalizedFamilyNameCache[name] = normalized
	return normalized
end

local function GetFamilyRoot(instance, category)
	if not instance then
		return nil
	end

	local cached = FamilyRootCache[instance]
	if cached ~= nil then
		return cached or nil
	end

	local character = LocalPlayer.Character
	if character and instance:IsDescendantOf(character) then
		FamilyRootCache[instance] = character
		return character
	end

	local tool = instance:FindFirstAncestorOfClass("Tool")
	if tool then
		FamilyRootCache[instance] = tool
		return tool
	end

	if category == "UI" then
		local screenGui = instance:FindFirstAncestorOfClass("ScreenGui")
		if screenGui then
			FamilyRootCache[instance] = screenGui
			return screenGui
		end
	end

	if category == "NPC" and instance:IsA("Model") then
		FamilyRootCache[instance] = instance
		return instance
	end

	local current = instance
	local candidate = nil

	while current and current ~= workspace do
		if current:IsA("Model") or current:IsA("Folder") or current:IsA("Configuration") then
			candidate = current
		end
		current = current.Parent
	end

	FamilyRootCache[instance] = candidate or false
	return candidate
end

local function DetermineFamily(record, category)
	local instance = record and record.Instance
	if not instance then
		return "Unknown Family", "No instance"
	end

	local root = GetFamilyRoot(instance, category)

	if root then
		local familyName = NormalizeFamilyName(root.Name)
		local rootPath = SafeFullName(root)
		return category .. " / " .. familyName, rootPath
	end

	-- When no meaningful structural container exists, group similar names
	-- inside the same classification instead of treating every object as a
	-- separate family.
	local normalized = NormalizeFamilyName(instance.Name)
	return category .. " / " .. normalized, SafeFullName(instance)
end

local function BuildFamilyData(classificationData)
	local familyData = {}
	local familyCounts = {}
	local familyCategories = {}

	for index, record in pairs(classificationData) do
		local family, rootPath = DetermineFamily(record, record.Category)

		familyData[index] = {
			Instance = record.Instance,
			Name = record.Name,
			ClassName = record.ClassName,
			FullName = record.FullName,
			Category = record.Category,
			Family = family,
			Root = rootPath
		}

		familyCounts[family] = (familyCounts[family] or 0) + 1
		familyCategories[family] = familyCategories[family] or record.Category
	end

	local familyOrder = {}
	for family in pairs(familyCounts) do
		table.insert(familyOrder, family)
	end

	table.sort(familyOrder, function(a, b)
		local countA = familyCounts[a] or 0
		local countB = familyCounts[b] or 0
		if countA == countB then
			return a < b
		end
		return countA > countB
	end)

	return familyData, familyCounts, familyCategories, familyOrder
end

local function CommitFamilyData(classificationData)
	local familyData, familyCounts, familyCategories, familyOrder = BuildFamilyData(classificationData)

	table.clear(FamilyData)
	table.clear(FamilyCounts)
	table.clear(FamilyCategories)
	table.clear(FamilyOrder)

	for index, data in pairs(familyData) do
		FamilyData[index] = data
	end
	for family, count in pairs(familyCounts) do
		FamilyCounts[family] = count
	end
	for family, category in pairs(familyCategories) do
		FamilyCategories[family] = category
	end
	for index, family in ipairs(familyOrder) do
		FamilyOrder[index] = family
	end
end

local function CreateFamilyRow(family, count, category, order)
	local row = Instance.new("Frame")
	row.Name = "FamilyRow" .. order
	row.Size = UDim2.new(1, -2, 0, 28)
	row.Position = UDim2.fromOffset(0, (order - 1) * 30)
	row.BackgroundColor3 = COLORS.Panel3
	row.BorderSizePixel = 0
	row.ZIndex = BASE_ZINDEX + 3
	row.Parent = FamilyScroll
	Corner(row, 4)

	local familyLabel = MakeText(row, family, 8, COLORS.Text, Enum.Font.GothamMedium)
	familyLabel.Position = UDim2.fromOffset(7, 2)
	familyLabel.Size = UDim2.new(1, -48, 0, 13)
	familyLabel.TextTruncate = Enum.TextTruncate.AtEnd
	familyLabel.ZIndex = BASE_ZINDEX + 4

	local categoryLabel = MakeText(row, category, 7, COLORS.Muted)
	categoryLabel.Position = UDim2.fromOffset(7, 14)
	categoryLabel.Size = UDim2.new(1, -48, 0, 11)
	categoryLabel.TextTruncate = Enum.TextTruncate.AtEnd
	categoryLabel.ZIndex = BASE_ZINDEX + 4

	local countLabel = MakeText(row, tostring(count), 10, COLORS.Text, Enum.Font.GothamBold)
	countLabel.Position = UDim2.new(1, -39, 0, 0)
	countLabel.Size = UDim2.fromOffset(33, 28)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = BASE_ZINDEX + 4
end

local function UpdateFamilyUI()
	if #FamilyOrder == 0 then
		ObjectsSummary.Text = "No object families detected yet."
	else
		ObjectsSummary.Text = tostring(#FamilyOrder) .. " object families / groups detected."
	end

	for _, child in ipairs(FamilyScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for order, family in ipairs(FamilyOrder) do
		CreateFamilyRow(
			family,
			FamilyCounts[family] or 0,
			FamilyCategories[family] or "Unknown",
			order
		)
	end

	FamilyScroll.CanvasSize = UDim2.fromOffset(
		0,
		#FamilyOrder * 30
	)
end

local FamilyUIUpdateScheduled = false

local function RequestFamilyUIUpdate()
	if FamilyUIUpdateScheduled then
		return
	end

	FamilyUIUpdateScheduled = true

	task.defer(function()
		FamilyUIUpdateScheduled = false
		UpdateFamilyUI()
	end)
end

local function CreateClassificationRow(category, count, order)
	local row = Instance.new("Frame")

	row.Name = category .. "Row"
	row.Size = UDim2.new(0.5, -2, 0, ClassificationRowHeight)
	row.BackgroundColor3 = COLORS.Panel3
	row.BorderSizePixel = 0
	row.ZIndex = BASE_ZINDEX + 3
	row.Parent = ClassificationScroll

	local column = (order - 1) % 2
	local rowIndex = math.floor((order - 1) / 2)

	row.Position = UDim2.new(
		column * 0.5,
		column == 0 and 0 or ClassificationColumnGap / 2,
		0,
		rowIndex * (ClassificationRowHeight + ClassificationRowGap)
	)

	Corner(row, 3)

	local categoryLabel = MakeText(
		row,
		category,
		8,
		COLORS.Text,
		Enum.Font.GothamMedium
	)

	categoryLabel.Position = UDim2.fromOffset(6, 0)
	categoryLabel.Size = UDim2.new(1, -34, 1, 0)
	categoryLabel.TextYAlignment = Enum.TextYAlignment.Center
	categoryLabel.ZIndex = BASE_ZINDEX + 4

	local countLabel = MakeText(
		row,
		tostring(count),
		8,
		COLORS.Muted,
		Enum.Font.GothamBold
	)

	countLabel.Position = UDim2.new(1, -29, 0, 0)
	countLabel.Size = UDim2.fromOffset(25, ClassificationRowHeight)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.TextYAlignment = Enum.TextYAlignment.Center
	countLabel.ZIndex = BASE_ZINDEX + 4
end

local function UpdateClassificationUI()
	if ClassificationComplete then
		ObjectsSummary.Text = "Classification complete. Tap Structure to view Phase 1 data."
	elseif ClassificationRunning then
		ObjectsSummary.Text = "Classifying scanned objects..."
	else
		ObjectsSummary.Text = "Phase 1 structure + Phase 2 classification."
	end

	for _, child in ipairs(ClassificationScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for order, category in ipairs(ClassificationOrder) do
		CreateClassificationRow(
			category,
			ClassificationCounts[category] or 0,
			order
		)
	end

	local rows = math.ceil(#ClassificationOrder / 2)

	ClassificationScroll.CanvasSize = UDim2.fromOffset(
		0,
		rows * (ClassificationRowHeight + ClassificationRowGap)
	)
end

local function RequestClassificationUIUpdate(force)
	local now = os.clock()

	if not force and now - LastClassificationUIUpdate < CLASSIFICATION_UI_INTERVAL then
		return
	end

	if ClassificationUIUpdateScheduled then
		return
	end

	ClassificationUIUpdateScheduled = true

	task.defer(function()
		ClassificationUIUpdateScheduled = false
		LastClassificationUIUpdate = os.clock()
		UpdateClassificationUI()
	end)
end

local function RunClassification(scanGeneration)
	-- Only the task that owns this generation may change classification state.
	if scanGeneration ~= CurrentScan then
		return
	end

	ClassificationScheduled = false

	if ClassificationRunning then
		return
	end

	ClassificationRunning = true
	ClassificationComplete = false
	ClassificationProgress = 0

	-- Build into generation-local tables. An old task can therefore never
	-- write partial classification data into a newer scan's tables.
	local localData = {}
	local classifiedInstances = {}
	local localCounts = {}
	for _, category in ipairs(ClassificationOrder) do
		localCounts[category] = 0
	end

	local success, err = pcall(function()
		local snapshot = table.clone(ScanData)
		local total = #snapshot

		if total == 0 then
			-- There may still be live objects waiting in PendingClassification.
			-- Do not exit early; allow the pending-drain loop below to run.
			ClassificationProgress = 90
			UpdateOverallStatus("CLASSIFYING", ClassificationProgress)
		end

		local classificationBatchStart = os.clock()

		for index, record in ipairs(snapshot) do
			if scanGeneration ~= CurrentScan then
				return
			end

			while ScanPaused and scanGeneration == CurrentScan do
				UpdateOverallStatus("PAUSED", ClassificationProgress)
				task.wait(0.1)
			end

			if scanGeneration ~= CurrentScan then
				return
			end

			local category, signals = ClassifyObject(record)
			localData[index] = {
				Instance = record.Instance,
				Name = record.Name,
				ClassName = record.ClassName,
				FullName = record.FullName,
				Category = category,
				Signals = signals
			}
			classifiedInstances[record.Instance] = true
			localCounts[category] = (localCounts[category] or 0) + 1

			if index % CLASSIFICATION_BATCH_SIZE == 0 or index == total or os.clock() - classificationBatchStart >= CLASSIFICATION_TIME_BUDGET then
				ClassificationProgress = total > 0 and (index / total) * 90 or 100
				UpdateOverallStatus("CLASSIFYING", ClassificationProgress)
				RequestClassificationUIUpdate()
				classificationBatchStart = os.clock()
				task.wait(CLASSIFICATION_YIELD_TIME)
			end
		end

		-- Include objects added while classification was running. The pending
		-- table can change while this task is processing it, so take a fresh
		-- snapshot repeatedly until there is no pending work left. This closes
		-- the race where an object is added after the first pending snapshot.
		local pendingStartProgress = 90

		while next(PendingClassification) do
			if scanGeneration ~= CurrentScan then
				return
			end

			while ScanPaused and scanGeneration == CurrentScan do
				UpdateOverallStatus("PAUSED", ClassificationProgress)
				task.wait(0.1)
			end

			if scanGeneration ~= CurrentScan then
				return
			end

			local pendingSnapshot = table.clone(PendingClassification)
			local pendingTotal = 0
			for _ in pairs(pendingSnapshot) do
				pendingTotal += 1
			end

			local pendingBatchProcessed = 0

			for instance, record in pairs(pendingSnapshot) do
				if scanGeneration ~= CurrentScan then
					return
				end

				while ScanPaused and scanGeneration == CurrentScan do
					UpdateOverallStatus("PAUSED", ClassificationProgress)
					task.wait(0.1)
				end

				if scanGeneration ~= CurrentScan then
					return
				end

				if not classifiedInstances[instance]
					and record
					and record.Instance == instance
					and instance.Parent
					and instance:IsDescendantOf(workspace) then
					local category, signals = ClassifyObject(record)
					localData[#localData + 1] = {
						Instance = record.Instance,
						Name = record.Name,
						ClassName = record.ClassName,
						FullName = record.FullName,
						Category = category,
						Signals = signals
					}
					classifiedInstances[instance] = true
					localCounts[category] = (localCounts[category] or 0) + 1
				end

				PendingClassification[instance] = nil
				pendingBatchProcessed += 1

				if pendingBatchProcessed % PENDING_CLASSIFICATION_BATCH_SIZE == 0 then
					-- Reserve the final 10% for draining newly-arriving pending work.
					-- The progress can reach 100% only after PendingClassification is empty.
					local progress = pendingStartProgress
					if pendingTotal > 0 then
						progress += math.min(9, (pendingBatchProcessed / pendingTotal) * 9)
					end
					ClassificationProgress = math.min(99, progress)
					UpdateOverallStatus("CLASSIFYING", ClassificationProgress)
					RequestClassificationUIUpdate()
					task.wait(CLASSIFICATION_YIELD_TIME)
				end
			end

			-- If new objects arrived while this snapshot was being processed,
			-- the outer while loop takes another snapshot and drains them too.
			ClassificationProgress = math.min(99, math.max(ClassificationProgress, pendingStartProgress))
			UpdateOverallStatus("CLASSIFYING", ClassificationProgress)
			RequestClassificationUIUpdate()
			task.wait(CLASSIFICATION_YIELD_TIME)
		end

		-- Only report 100% after the pending table has actually drained.
		ClassificationProgress = 100
		UpdateOverallStatus("CLASSIFYING", ClassificationProgress)
	end)

	-- A cancelled generation must not touch state belonging to the new one.
	if scanGeneration ~= CurrentScan then
		return
	end

	if not success then
		ClassificationRunning = false
		ClassificationScheduled = false
		ClassificationComplete = false
		ClassificationProgress = 0
		UpdateClassificationUI()
		UpdateOverallStatus("ERROR", 0)
		warn("[Client Game Intelligence Analyzer] Classification error:", err)
		return
	end

	-- Commit only after the entire generation completed successfully.
	table.clear(ClassificationData)
	for index, data in pairs(localData) do
		ClassificationData[index] = data
	end

	-- Build Phase 2.2 family intelligence only after classification has fully
	-- succeeded, keeping the same generation-safe commit model.
	CommitFamilyData(ClassificationData)

	for category in pairs(ClassificationCounts) do
		ClassificationCounts[category] = localCounts[category] or 0
	end

	ClassificationRunning = false
	ClassificationScheduled = false
	ClassificationComplete = true
	ClassificationProgress = 100
	RequestClassificationUIUpdate(true)
	UpdateFamilyUI()
	UpdateOverallStatus("COMPLETE", 100)
end

--------------------------------------------------
-- SCAN UI THROTTLING
--------------------------------------------------

local LastScanUIUpdate = 0

local function UpdateScanProgressUI(force)
	local now = os.clock()

	if not force and now - LastScanUIUpdate < SCAN_UI_INTERVAL then
		return
	end

	LastScanUIUpdate = now
	UpdateOverallStatus("ANALYZING", ScanProgress)
	UpdateCounters()
	SetStatus("Structure", "PROCESSING")
	SetStatus("Attributes", "PROCESSING")
	SetStatus("Tags", "PROCESSING")
	SetStatus("Values", "PROCESSING")
end

--------------------------------------------------
-- RUN SCAN
--------------------------------------------------

local function RunScan()
	if ScanRunning then
		return
	end

	ScanRunning = true
	ScanPaused = false
	CurrentScan += 1
	local thisScan = CurrentScan
	ScanProgress = 0
	ClassificationProgress = 0
	LastScanUIUpdate = 0
	LastClassificationUIUpdate = 0
	ClassificationScheduled = false
	ClassificationRunning = false
	ClassificationComplete = false
	ClearScanData()

	UpdateCounters()
	SetStatus("Structure", "RUNNING")
	SetStatus("Attributes", "RUNNING")
	SetStatus("Tags", "RUNNING")
	SetStatus("Values", "RUNNING")
	UpdateOverallStatus("ANALYZING", 0)
	PauseButton.Text = "Pause"

	local success, err = pcall(function()
		local descendants = workspace:GetDescendants()
		local total = #descendants

		local batchStart = os.clock()

		for index, instance in ipairs(descendants) do
			if thisScan ~= CurrentScan then return end
			while ScanPaused and thisScan == CurrentScan do
				UpdateOverallStatus("PAUSED", ScanProgress)
				task.wait(0.1)
			end
			if thisScan ~= CurrentScan then return end

			if instance.Parent and instance:IsDescendantOf(workspace) then
				ScanInstance(instance)
			end

			if index % BATCH_SIZE == 0 or index == total or os.clock() - batchStart >= SCAN_TIME_BUDGET then
				ScanProgress = total > 0 and (index / total) * 100 or 100
				UpdateScanProgressUI(index == total)
				batchStart = os.clock()
				task.wait(YIELD_TIME)
			end

			if #ScanData >= MAX_RESULTS then
				ScanTruncated = index < total or #descendants > MAX_RESULTS
				break
			end
		end

		for instance in pairs(PendingInstances) do
			if thisScan ~= CurrentScan then return end
			while ScanPaused and thisScan == CurrentScan do
				UpdateOverallStatus("PAUSED", ScanProgress)
				task.wait(0.1)
			end
			if thisScan ~= CurrentScan then return end
			if instance.Parent and instance:IsDescendantOf(workspace) then
				ScanInstance(instance)
			end
			PendingInstances[instance] = nil
			if #ScanData >= MAX_RESULTS then
				ScanTruncated = true
				break
			end
		end
	end)

	if thisScan ~= CurrentScan then
		-- This task was cancelled by a newer generation. It must never touch
		-- ScanRunning or classification flags owned by that newer generation.
		return
	end

	ScanRunning = false
	if not success then
		SetStatus("Structure", "ERROR")
		SetStatus("Attributes", "ERROR")
		SetStatus("Tags", "ERROR")
		SetStatus("Values", "ERROR")
		UpdateOverallStatus("ERROR", 0)
		warn("[Client Game Intelligence Analyzer] Scan error:", err)
		return
	end

	ScanProgress = 100
	UpdateScanProgressUI(true)
	SetStatus("Structure", ScanTruncated and "LIMIT" or "COMPLETE")
	SetStatus("Attributes", "COMPLETE")
	SetStatus("Tags", "COMPLETE")
	SetStatus("Values", "COMPLETE")
	UpdateOverallStatus("COMPLETE", 100)

	-- Mark classification as scheduled before yielding to task.spawn so a
	-- DescendantAdded event cannot fall into the gap between scan and start.
	ClassificationScheduled = true
	ClassificationProgress = 0
	task.spawn(function()
		RunClassification(thisScan)
	end)
end

--------------------------------------------------
-- PAUSE
--------------------------------------------------

PauseButton.MouseButton1Click:Connect(function()
	if not ScanRunning and not ClassificationRunning and not ClassificationScheduled then
		return
	end

	ScanPaused = not ScanPaused

	if ScanPaused then
		PauseButton.Text = "Resume"
		if ClassificationRunning or ClassificationScheduled then
			UpdateOverallStatus("PAUSED", ClassificationProgress)
		else
			UpdateOverallStatus("PAUSED", ScanProgress)
		end
	else
		PauseButton.Text = "Pause"
		if ClassificationRunning or ClassificationScheduled then
			UpdateOverallStatus("CLASSIFYING", ClassificationProgress)
		else
			UpdateOverallStatus("ANALYZING", ScanProgress)
		end
	end
end)

--------------------------------------------------
-- RESCAN
--------------------------------------------------

RescanButton.MouseButton1Click:Connect(function()
	-- Invalidate every task currently running. Old tasks may remain alive until
	-- their next yield, but their generation no longer matches CurrentScan and
	-- therefore they cannot modify current-operation flags or data.
	CurrentScan += 1
	ScanRunning = false
	ClassificationRunning = false
	ClassificationScheduled = false
	ClassificationComplete = false
	ScanPaused = false
	ScanProgress = 0
	ClassificationProgress = 0

	table.clear(PendingInstances)
	table.clear(PendingClassification)

	PauseButton.Text = "Pause"
	UpdateOverallStatus("ANALYZING", 0)

	task.defer(RunScan)
end)

--------------------------------------------------
-- MINIMIZE
--------------------------------------------------

local Minimized = false

MinimizeButton.MouseButton1Click:Connect(function()

	Minimized =
		not Minimized

	if Minimized then

		UpdateMainWidth()

		StatusHeader.Visible = false
		StatusDetails.Visible = false
		TabBar.Visible = false
		Content.Visible = false
		BottomBar.Visible = false

		MinimizeButton.Text =
			"+"

	else

		UpdateMainWidth()

		StatusHeader.Visible = true
		TabBar.Visible = true
		Content.Visible = true
		BottomBar.Visible = true

		if StatusExpanded then
			StatusDetails.Visible = true
		end

		MinimizeButton.Text =
			"−"
	end
end)

--------------------------------------------------
-- CLOSE
--------------------------------------------------

CloseButton.MouseButton1Click:Connect(function()

	Main.Visible = false
	OpenButton.Visible = true

end)

--------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------

OpenButton.MouseButton1Click:Connect(function()

	Main.Visible = true
	OpenButton.Visible = false

end)

--------------------------------------------------
-- LIVE DESCENDANT DETECTION
--------------------------------------------------

workspace.DescendantAdded:Connect(function(instance)
	local eventScan = CurrentScan
	task.defer(function()
		-- A delayed event belongs to the generation that existed when the
		-- event was received. It must not modify a newer scan.
		if eventScan ~= CurrentScan then
			return
		end

		if not instance or not instance.Parent or not instance:IsDescendantOf(workspace) then
			return
		end

		if ScanRunning then
			PendingInstances[instance] = true
			return
		end

		if ScannedInstances[instance] then
			return
		end

		if #ScanData >= MAX_RESULTS then
			ScanTruncated = true
			UpdateCounters()
			return
		end

		local record = ScanInstance(instance)
		if not record then
			return
		end
		UpdateCounters()

		-- Classification is considered active from the moment it is scheduled,
		-- eliminating the scan-to-classification startup race.
		if ClassificationRunning or ClassificationScheduled then
			PendingClassification[instance] = record
			ClassificationComplete = false
			RequestClassificationUIUpdate()
		elseif ClassificationComplete then
			local category, signals = ClassifyObject(record)
			local classificationIndex = #ClassificationData + 1
			ClassificationData[classificationIndex] = {
				Instance = record.Instance,
				Name = record.Name,
				ClassName = record.ClassName,
				FullName = record.FullName,
				Category = category,
				Signals = signals
			}
			ClassificationCounts[category] = (ClassificationCounts[category] or 0) + 1

			local family, rootPath = DetermineFamily(record, category)
			local familyIndex = #ClassificationData
			FamilyData[familyIndex] = {
				Instance = record.Instance,
				Name = record.Name,
				ClassName = record.ClassName,
				FullName = record.FullName,
				Category = category,
				Family = family,
				Root = rootPath
			}
			FamilyCounts[family] = (FamilyCounts[family] or 0) + 1
			FamilyCategories[family] = FamilyCategories[family] or category
			if not table.find(FamilyOrder, family) then
				table.insert(FamilyOrder, family)
			end
			table.sort(FamilyOrder, function(a, b)
				local countA = FamilyCounts[a] or 0
				local countB = FamilyCounts[b] or 0
				if countA == countB then
					return a < b
				end
				return countA > countB
			end)

			RequestClassificationUIUpdate()
			RequestFamilyUIUpdate()
		else
			ClassificationComplete = false
			RequestClassificationUIUpdate()
		end
	end)
end)

--------------------------------------------------
-- PLAYER UPDATES
--------------------------------------------------

LocalPlayer.CharacterAdded:Connect(function()

	task.wait(0.5)

	UpdatePlayerInfo()

end)

task.spawn(function()

	while Gui.Parent do

		if LocalPlayer.Character then
			UpdatePlayerInfo()
		end

		task.wait(1)
	end
end)

--------------------------------------------------
-- RESPONSIVE MAIN WIDTH
--------------------------------------------------

local function GetMainWidth()
	local camera = workspace.CurrentCamera
	local viewportWidth = camera and camera.ViewportSize.X or 390
	return math.max(280, math.min(345, viewportWidth - 20))
end

UpdateMainWidth = function()
	local height
	if Minimized then
		height = 38
	elseif StatusExpanded then
		height = 377
	else
		height = 293
	end
	Main.Size = UDim2.fromOffset(GetMainWidth(), height)
end

local ViewportConnection
local CameraConnection

local function ConnectViewportSize()
	if ViewportConnection then
		ViewportConnection:Disconnect()
		ViewportConnection = nil
	end

	local camera = workspace.CurrentCamera
	if camera then
		ViewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateMainWidth)
	end

	UpdateMainWidth()
end

CameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ConnectViewportSize)
ConnectViewportSize()

--------------------------------------------------
-- INITIAL STATE
--------------------------------------------------

ShowPage("Overview")

UpdateStatusLayout()
UpdateMainWidth()

UpdateCounters()
UpdateClassificationUI()
UpdateFamilyUI()

Main.Visible = true
OpenButton.Visible = false

--------------------------------------------------
-- AUTO SCAN
--------------------------------------------------

if AUTO_SCAN then

	task.spawn(function()

		task.wait(0.5)

		RunScan()

	end)
end
