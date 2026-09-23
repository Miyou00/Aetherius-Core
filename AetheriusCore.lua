--[[
    CLIENT GAME INTELLIGENCE ANALYZER
    ==================================

    PHASE 1 - STRUCTURE / ATTRIBUTE SCANNER

    Features:
    • Compact mobile-first UI
    • Tabbed interface
    • Incremental workspace scanning
    • Instance discovery
    • Attribute scanning
    • CollectionService tag scanning
    • ValueBase scanning
    • Useful property scanning
    • Search
    • Pause / Resume
    • Rescan
    • Scan progress
    • Compact status panel
    • Draggable window
    • Floating open button
    • High DisplayOrder / Global ZIndex
    • Live statistics

    PHASE 1 DOES NOT:
    • Access server-only data
    • Bypass Roblox security
    • Perform arbitrary remote probing
    • Automatically fire unknown remotes
    • Extract protected code
    • Attempt anti-detection behavior

    Intended for client-visible analysis in experiences
    you own or are authorized to test.
]]

--// SERVICES
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// CONFIGURATION
local CONFIG = {
	BATCH_SIZE = 100,
	YIELD_TIME = 0.03,

	MAX_RESULTS = 50000,
	MAX_ATTRIBUTES_PER_OBJECT = 100,
	MAX_TAGS_PER_OBJECT = 50,

	MAX_VISIBLE_RESULTS = 100,

	AUTO_SCAN = true,

	SCREEN_GUI_NAME = "ClientGameAnalyzer",

	DISPLAY_ORDER = 2147483647,
	BASE_ZINDEX = 100000,
}

--// STATE
local State = {
	Scanning = false,
	Paused = false,
	ScanComplete = false,

	CurrentIndex = 0,
	TotalInstances = 0,

	Objects = {},
	ObjectCount = 0,
	AttributeCount = 0,
	TagCount = 0,
	ValueCount = 0,

	CurrentTab = "Overview",
	SearchText = "",

	Status = {
		Structure = "WAITING",
		Attributes = "WAITING",
		Tags = "WAITING",
		Values = "WAITING",
	},

	ScanToken = 0,
}

--// CLEAN UP OLD GUI
local OldGui = PlayerGui:FindFirstChild(CONFIG.SCREEN_GUI_NAME)

if OldGui then
	OldGui:Destroy()
end

--//========================================================
--// GUI CREATION
--//========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.SCREEN_GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = CONFIG.DISPLAY_ORDER
ScreenGui.Parent = PlayerGui

--// ZINDEX HELPER
local function SetZIndexRecursive(object, zIndex)
	for _, child in ipairs(object:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.ZIndex = zIndex
		end
	end

	if object:IsA("GuiObject") then
		object.ZIndex = zIndex
	end
end

--// COLORS
local COLORS = {
	Background = Color3.fromRGB(18, 20, 24),
	Panel = Color3.fromRGB(25, 28, 34),
	Panel2 = Color3.fromRGB(31, 35, 42),

	Border = Color3.fromRGB(55, 61, 72),

	Text = Color3.fromRGB(235, 238, 243),
	SubText = Color3.fromRGB(160, 168, 180),

	Blue = Color3.fromRGB(45, 125, 255),
	Green = Color3.fromRGB(45, 200, 120),
	Yellow = Color3.fromRGB(235, 190, 60),
	Red = Color3.fromRGB(235, 75, 75),

	Tab = Color3.fromRGB(32, 36, 44),
	TabActive = Color3.fromRGB(45, 125, 255),
}

--//========================================================
--// MAIN WINDOW
--//========================================================

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 300, 0, 255)
Main.Position = UDim2.new(0.5, -150, 0.5, -127)
Main.BackgroundColor3 = COLORS.Background
Main.BorderSizePixel = 0
Main.ZIndex = CONFIG.BASE_ZINDEX
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = COLORS.Border
MainStroke.Thickness = 1
MainStroke.Parent = Main

--//========================================================
--// TITLE BAR
--//========================================================

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = COLORS.Panel
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = CONFIG.BASE_ZINDEX + 1
TitleBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -72, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Client Analyzer"
Title.TextColor3 = COLORS.Text
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = CONFIG.BASE_ZINDEX + 2
Title.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Position = UDim2.new(1, -64, 0, 2)
MinimizeButton.BackgroundColor3 = COLORS.Tab
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Text = "—"
MinimizeButton.TextColor3 = COLORS.Text
MinimizeButton.TextSize = 15
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.ZIndex = CONFIG.BASE_ZINDEX + 2
MinimizeButton.Parent = TitleBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 5)
MinCorner.Parent = MinimizeButton

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -32, 0, 2)
CloseButton.BackgroundColor3 = COLORS.Tab
CloseButton.BorderSizePixel = 0
CloseButton.Text = "×"
CloseButton.TextColor3 = COLORS.Text
CloseButton.TextSize = 17
CloseButton.Font = Enum.Font.GothamBold
CloseButton.ZIndex = CONFIG.BASE_ZINDEX + 2
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 5)
CloseCorner.Parent = CloseButton

--//========================================================
--// STATUS HEADER
--//========================================================

local StatusHeader = Instance.new("Frame")
StatusHeader.Name = "StatusHeader"
StatusHeader.Size = UDim2.new(1, -12, 0, 30)
StatusHeader.Position = UDim2.new(0, 6, 0, 39)
StatusHeader.BackgroundColor3 = COLORS.Panel2
StatusHeader.BorderSizePixel = 0
StatusHeader.ZIndex = CONFIG.BASE_ZINDEX + 1
StatusHeader.Parent = Main

local StatusHeaderCorner = Instance.new("UICorner")
StatusHeaderCorner.CornerRadius = UDim.new(0, 5)
StatusHeaderCorner.Parent = StatusHeader

local StatusDot = Instance.new("TextLabel")
StatusDot.Name = "StatusDot"
StatusDot.Size = UDim2.new(0, 20, 1, 0)
StatusDot.Position = UDim2.new(0, 5, 0, 0)
StatusDot.BackgroundTransparency = 1
StatusDot.Text = "●"
StatusDot.TextColor3 = COLORS.Yellow
StatusDot.TextSize = 12
StatusDot.Font = Enum.Font.GothamBold
StatusDot.ZIndex = CONFIG.BASE_ZINDEX + 2
StatusDot.Parent = StatusHeader

local OverallStatus = Instance.new("TextLabel")
OverallStatus.Name = "OverallStatus"
OverallStatus.Size = UDim2.new(1, -90, 1, 0)
OverallStatus.Position = UDim2.new(0, 24, 0, 0)
OverallStatus.BackgroundTransparency = 1
OverallStatus.Text = "WAITING"
OverallStatus.TextColor3 = COLORS.Text
OverallStatus.TextSize = 11
OverallStatus.Font = Enum.Font.GothamBold
OverallStatus.TextXAlignment = Enum.TextXAlignment.Left
OverallStatus.ZIndex = CONFIG.BASE_ZINDEX + 2
OverallStatus.Parent = StatusHeader

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Name = "ProgressLabel"
ProgressLabel.Size = UDim2.new(0, 55, 1, 0)
ProgressLabel.Position = UDim2.new(1, -82, 0, 0)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "0%"
ProgressLabel.TextColor3 = COLORS.SubText
ProgressLabel.TextSize = 10
ProgressLabel.Font = Enum.Font.GothamBold
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Right
ProgressLabel.ZIndex = CONFIG.BASE_ZINDEX + 2
ProgressLabel.Parent = StatusHeader

local StatusExpandButton = Instance.new("TextButton")
StatusExpandButton.Name = "StatusExpandButton"
StatusExpandButton.Size = UDim2.new(0, 25, 1, 0)
StatusExpandButton.Position = UDim2.new(1, -28, 0, 0)
StatusExpandButton.BackgroundTransparency = 1
StatusExpandButton.Text = "▼"
StatusExpandButton.TextColor3 = COLORS.SubText
StatusExpandButton.TextSize = 10
StatusExpandButton.Font = Enum.Font.GothamBold
StatusExpandButton.ZIndex = CONFIG.BASE_ZINDEX + 2
StatusExpandButton.Parent = StatusHeader

--//========================================================
--// STATUS DETAILS
--//========================================================

local StatusDetails = Instance.new("Frame")
StatusDetails.Name = "StatusDetails"
StatusDetails.Size = UDim2.new(1, -12, 0, 76)
StatusDetails.Position = UDim2.new(0, 6, 0, 73)
StatusDetails.BackgroundColor3 = COLORS.Panel
StatusDetails.BorderSizePixel = 0
StatusDetails.Visible = false
StatusDetails.ZIndex = CONFIG.BASE_ZINDEX + 1
StatusDetails.Parent = Main

local StatusDetailsCorner = Instance.new("UICorner")
StatusDetailsCorner.CornerRadius = UDim.new(0, 5)
StatusDetailsCorner.Parent = StatusDetails

local StatusRows = {}

local function CreateStatusRow(name, y)
	local Row = Instance.new("Frame")
	Row.Name = name .. "Row"
	Row.Size = UDim2.new(1, -8, 0, 17)
	Row.Position = UDim2.new(0, 4, 0, y)
	Row.BackgroundTransparency = 1
	Row.ZIndex = CONFIG.BASE_ZINDEX + 2
	Row.Parent = StatusDetails

	local NameLabel = Instance.new("TextLabel")
	NameLabel.Size = UDim2.new(0.6, 0, 1, 0)
	NameLabel.BackgroundTransparency = 1
	NameLabel.Text = name
	NameLabel.TextColor3 = COLORS.SubText
	NameLabel.TextSize = 10
	NameLabel.Font = Enum.Font.Gotham
	NameLabel.TextXAlignment = Enum.TextXAlignment.Left
	NameLabel.ZIndex = CONFIG.BASE_ZINDEX + 3
	NameLabel.Parent = Row

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Size = UDim2.new(0.4, 0, 1, 0)
	ValueLabel.Position = UDim2.new(0.6, 0, 0, 0)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.Text = "WAITING"
	ValueLabel.TextColor3 = COLORS.Yellow
	ValueLabel.TextSize = 10
	ValueLabel.Font = Enum.Font.GothamBold
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.ZIndex = CONFIG.BASE_ZINDEX + 3
	ValueLabel.Parent = Row

	StatusRows[name] = ValueLabel
end

CreateStatusRow("Structure", 4)
CreateStatusRow("Attributes", 21)
CreateStatusRow("Tags", 38)
CreateStatusRow("Values", 55)

--//========================================================
--// TABS
--//========================================================

local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -12, 0, 31)
TabBar.Position = UDim2.new(0, 6, 0, 73)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.ZIndex = CONFIG.BASE_ZINDEX + 1
TabBar.Parent = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 4)
TabLayout.Parent = TabBar

local TabNames = {
	"Overview",
	"Objects",
	"Player",
	"Relations",
	"Behavior",
	"Remotes",
	"Data",
}

local TabButtons = {}

--//========================================================
--// CONTENT AREA
--//========================================================

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -12, 0, 105)
Content.Position = UDim2.new(0, 6, 0, 108)
Content.BackgroundColor3 = COLORS.Panel
Content.BorderSizePixel = 0
Content.ZIndex = CONFIG.BASE_ZINDEX + 1
Content.Parent = Main

local ContentCorner = Instance.new("UICorner")
ContentCorner.CornerRadius = UDim.new(0, 6)
ContentCorner.Parent = Content

--//========================================================
--// OVERVIEW TAB
--//========================================================

local OverviewFrame = Instance.new("Frame")
OverviewFrame.Name = "Overview"
OverviewFrame.Size = UDim2.new(1, 0, 1, 0)
OverviewFrame.BackgroundTransparency = 1
OverviewFrame.ZIndex = CONFIG.BASE_ZINDEX + 2
OverviewFrame.Parent = Content

local StatsLabel = Instance.new("TextLabel")
StatsLabel.Name = "Stats"
StatsLabel.Size = UDim2.new(1, -16, 0, 60)
StatsLabel.Position = UDim2.new(0, 8, 0, 7)
StatsLabel.BackgroundTransparency = 1
StatsLabel.Text = "Objects       0\nAttributes    0\nTags          0\nValues        0"
StatsLabel.TextColor3 = COLORS.Text
StatsLabel.TextSize = 11
StatsLabel.Font = Enum.Font.Gotham
StatsLabel.TextXAlignment = Enum.TextXAlignment.Left
StatsLabel.TextYAlignment = Enum.TextYAlignment.Top
StatsLabel.ZIndex = CONFIG.BASE_ZINDEX + 3
StatsLabel.Parent = OverviewFrame

local OverviewInfo = Instance.new("TextLabel")
OverviewInfo.Name = "Info"
OverviewInfo.Size = UDim2.new(1, -16, 0, 30)
OverviewInfo.Position = UDim2.new(0, 8, 0, 70)
OverviewInfo.BackgroundTransparency = 1
OverviewInfo.Text = "Phase 1: client-visible structure scanner"
OverviewInfo.TextColor3 = COLORS.SubText
OverviewInfo.TextSize = 10
OverviewInfo.Font = Enum.Font.Gotham
OverviewInfo.TextXAlignment = Enum.TextXAlignment.Left
OverviewInfo.ZIndex = CONFIG.BASE_ZINDEX + 3
OverviewInfo.Parent = OverviewFrame

--//========================================================
--// OBJECTS TAB
--//========================================================

local ObjectsFrame = Instance.new("Frame")
ObjectsFrame.Name = "Objects"
ObjectsFrame.Size = UDim2.new(1, 0, 1, 0)
ObjectsFrame.BackgroundTransparency = 1
ObjectsFrame.Visible = false
ObjectsFrame.ZIndex = CONFIG.BASE_ZINDEX + 2
ObjectsFrame.Parent = Content

local SearchBox = Instance.new("TextBox")
SearchBox.Name = "SearchBox"
SearchBox.Size = UDim2.new(1, -16, 0, 27)
SearchBox.Position = UDim2.new(0, 8, 0, 7)
SearchBox.BackgroundColor3 = COLORS.Panel2
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Search objects..."
SearchBox.PlaceholderColor3 = COLORS.SubText
SearchBox.Text = ""
SearchBox.TextColor3 = COLORS.Text
SearchBox.TextSize = 10
SearchBox.Font = Enum.Font.Gotham
SearchBox.ClearTextOnFocus = false
SearchBox.ZIndex = CONFIG.BASE_ZINDEX + 3
SearchBox.Parent = ObjectsFrame

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 5)
SearchCorner.Parent = SearchBox

local ResultsFrame = Instance.new("ScrollingFrame")
ResultsFrame.Name = "Results"
ResultsFrame.Size = UDim2.new(1, -16, 0, 63)
ResultsFrame.Position = UDim2.new(0, 8, 0, 38)
ResultsFrame.BackgroundTransparency = 1
ResultsFrame.BorderSizePixel = 0
ResultsFrame.ScrollBarThickness = 3
ResultsFrame.ScrollBarImageColor3 = COLORS.Border
ResultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ResultsFrame.ZIndex = CONFIG.BASE_ZINDEX + 3
ResultsFrame.Parent = ObjectsFrame

local ResultsLayout = Instance.new("UIListLayout")
ResultsLayout.Padding = UDim.new(0, 2)
ResultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ResultsLayout.Parent = ResultsFrame

local ResultPadding = Instance.new("UIPadding")
ResultPadding.PaddingRight = UDim.new(0, 3)
ResultPadding.Parent = ResultsFrame

--//========================================================
--// PLAYER TAB
--//========================================================

local PlayerFrame = Instance.new("Frame")
PlayerFrame.Name = "Player"
PlayerFrame.Size = UDim2.new(1, 0, 1, 0)
PlayerFrame.BackgroundTransparency = 1
PlayerFrame.Visible = false
PlayerFrame.ZIndex = CONFIG.BASE_ZINDEX + 2
PlayerFrame.Parent = Content

local PlayerInfo = Instance.new("TextLabel")
PlayerInfo.Name = "PlayerInfo"
PlayerInfo.Size = UDim2.new(1, -16, 1, -12)
PlayerInfo.Position = UDim2.new(0, 8, 0, 6)
PlayerInfo.BackgroundTransparency = 1
PlayerInfo.Text = "Player information\n\nLoading..."
PlayerInfo.TextColor3 = COLORS.Text
PlayerInfo.TextSize = 11
PlayerInfo.Font = Enum.Font.Gotham
PlayerInfo.TextXAlignment = Enum.TextXAlignment.Left
PlayerInfo.TextYAlignment = Enum.TextYAlignment.Top
PlayerInfo.ZIndex = CONFIG.BASE_ZINDEX + 3
PlayerInfo.Parent = PlayerFrame

--//========================================================
--// PLACEHOLDER TAB CREATOR
--//========================================================

local function CreatePlaceholderTab(name, message)
	local Frame = Instance.new("Frame")
	Frame.Name = name
	Frame.Size = UDim2.new(1, 0, 1, 0)
	Frame.BackgroundTransparency = 1
	Frame.Visible = false
	Frame.ZIndex = CONFIG.BASE_ZINDEX + 2
	Frame.Parent = Content

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -16, 1, -12)
	Label.Position = UDim2.new(0, 8, 0, 6)
	Label.BackgroundTransparency = 1
	Label.Text = message
	Label.TextColor3 = COLORS.SubText
	Label.TextSize = 11
	Label.Font = Enum.Font.Gotham
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Top
	Label.ZIndex = CONFIG.BASE_ZINDEX + 3
	Label.Parent = Frame

	return Frame
end

local RelationsFrame = CreatePlaceholderTab(
	"Relations",
	"RELATIONS\n\nPhase 1 foundation ready.\nRelationship mapping will be populated by a later analyzer phase."
)

local BehaviorFrame = CreatePlaceholderTab(
	"Behavior",
	"BEHAVIOR\n\nPhase 1 currently performs static scanning.\nDynamic state and player-action monitoring will be added later."
)

local RemotesFrame = CreatePlaceholderTab(
	"Remotes",
	"REMOTES\n\nPhase 1 does not actively test or fire remotes.\nAuthorized remote observation/testing will be added in a later phase."
)

local DataFrame = CreatePlaceholderTab(
	"Data",
	"DATA\n\nPhase 1 stores the discovered scan data in memory.\nStructured export and session data tools will be added later."
)

--//========================================================
--// BOTTOM CONTROLS
--//========================================================

local BottomBar = Instance.new("Frame")
BottomBar.Name = "BottomBar"
BottomBar.Size = UDim2.new(1, -12, 0, 34)
BottomBar.Position = UDim2.new(0, 6, 1, -40)
BottomBar.BackgroundTransparency = 1
BottomBar.ZIndex = CONFIG.BASE_ZINDEX + 2
BottomBar.Parent = Main

local PauseButton = Instance.new("TextButton")
PauseButton.Name = "PauseButton"
PauseButton.Size = UDim2.new(0.31, -4, 1, 0)
PauseButton.Position = UDim2.new(0, 0, 0, 0)
PauseButton.BackgroundColor3 = COLORS.Tab
PauseButton.BorderSizePixel = 0
PauseButton.Text = "Pause"
PauseButton.TextColor3 = COLORS.Text
PauseButton.TextSize = 10
PauseButton.Font = Enum.Font.GothamBold
PauseButton.ZIndex = CONFIG.BASE_ZINDEX + 3
PauseButton.Parent = BottomBar

local PauseCorner = Instance.new("UICorner")
PauseCorner.CornerRadius = UDim.new(0, 5)
PauseCorner.Parent = PauseButton

local ScanButton = Instance.new("TextButton")
ScanButton.Name = "ScanButton"
ScanButton.Size = UDim2.new(0.31, -4, 1, 0)
ScanButton.Position = UDim2.new(0.345, 0, 0, 0)
ScanButton.BackgroundColor3 = COLORS.Blue
ScanButton.BorderSizePixel = 0
ScanButton.Text = "Rescan"
ScanButton.TextColor3 = Color3.new(1, 1, 1)
ScanButton.TextSize = 10
ScanButton.Font = Enum.Font.GothamBold
ScanButton.ZIndex = CONFIG.BASE_ZINDEX + 3
ScanButton.Parent = BottomBar

local ScanCorner = Instance.new("UICorner")
ScanCorner.CornerRadius = UDim.new(0, 5)
ScanCorner.Parent = ScanButton

local HideButton = Instance.new("TextButton")
HideButton.Name = "HideButton"
HideButton.Size = UDim2.new(0.31, -4, 1, 0)
HideButton.Position = UDim2.new(0.69, 0, 0, 0)
HideButton.BackgroundColor3 = COLORS.Tab
HideButton.BorderSizePixel = 0
HideButton.Text = "Hide"
HideButton.TextColor3 = COLORS.Text
HideButton.TextSize = 10
HideButton.Font = Enum.Font.GothamBold
HideButton.ZIndex = CONFIG.BASE_ZINDEX + 3
HideButton.Parent = BottomBar

local HideCorner = Instance.new("UICorner")
HideCorner.CornerRadius = UDim.new(0, 5)
HideCorner.Parent = HideButton

--//========================================================
--// FLOATING OPEN BUTTON
--//========================================================

local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenButton"
OpenButton.Size = UDim2.new(0, 46, 0, 46)
OpenButton.Position = UDim2.new(0, 15, 0.5, -23)
OpenButton.BackgroundColor3 = COLORS.Blue
OpenButton.BorderSizePixel = 0
OpenButton.Text = "AI"
OpenButton.TextColor3 = Color3.new(1, 1, 1)
OpenButton.TextSize = 13
OpenButton.Font = Enum.Font.GothamBold
OpenButton.Visible = false
OpenButton.ZIndex = CONFIG.BASE_ZINDEX + 20
OpenButton.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(1, 0)
OpenCorner.Parent = OpenButton

local OpenStroke = Instance.new("UIStroke")
OpenStroke.Color = Color3.fromRGB(100, 160, 255)
OpenStroke.Thickness = 1
OpenStroke.Parent = OpenButton

--//========================================================
--// TAB MANAGEMENT
--//========================================================

local TabFrames = {
	Overview = OverviewFrame,
	Objects = ObjectsFrame,
	Player = PlayerFrame,
	Relations = RelationsFrame,
	Behavior = BehaviorFrame,
	Remotes = RemotesFrame,
	Data = DataFrame,
}

local function UpdateTabButtons()
	for name, button in pairs(TabButtons) do
		if name == State.CurrentTab then
			button.BackgroundColor3 = COLORS.TabActive
			button.TextColor3 = Color3.new(1, 1, 1)
		else
			button.BackgroundColor3 = COLORS.Tab
			button.TextColor3 = COLORS.SubText
		end
	end
end

local function ShowTab(tabName)
	if not TabFrames[tabName] then
		return
	end

	State.CurrentTab = tabName

	for name, frame in pairs(TabFrames) do
		frame.Visible = (name == tabName)
	end

	UpdateTabButtons()
end

for index, name in ipairs(TabNames) do
	local Button = Instance.new("TextButton")
	Button.Name = name .. "Tab"
	Button.Size = UDim2.new(0, 76, 0, 27)
	Button.BackgroundColor3 = COLORS.Tab
	Button.BorderSizePixel = 0
	Button.Text = name
	Button.TextColor3 = COLORS.SubText
	Button.TextSize = 9
	Button.Font = Enum.Font.GothamBold
	Button.LayoutOrder = index
	Button.ZIndex = CONFIG.BASE_ZINDEX + 3
	Button.Parent = TabBar

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 5)
	Corner.Parent = Button

	TabButtons[name] = Button

	Button.MouseButton1Click:Connect(function()
		ShowTab(name)
	end)
end

-- Update scrolling canvas
local function UpdateTabCanvas()
	task.defer(function()
		TabBar.CanvasSize = UDim2.new(
			0,
			TabLayout.AbsoluteContentSize.X + 5,
			0,
			0
		)
	end)
end

TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateTabCanvas)

ShowTab("Overview")

--//========================================================
--// STATUS MANAGEMENT
--//========================================================

local function SetStatus(name, status)
	State.Status[name] = status

	if StatusRows[name] then
		StatusRows[name].Text = status

		if status == "COMPLETE" then
			StatusRows[name].TextColor3 = COLORS.Green
		elseif status == "RUNNING" or status == "PROCESSING" then
			StatusRows[name].TextColor3 = COLORS.Blue
		elseif status == "ERROR" then
			StatusRows[name].TextColor3 = COLORS.Red
		elseif status == "PAUSED" then
			StatusRows[name].TextColor3 = COLORS.Yellow
		else
			StatusRows[name].TextColor3 = COLORS.Yellow
		end
	end
end

local function UpdateOverallStatus()
	if State.Paused then
		OverallStatus.Text = "PAUSED"
		StatusDot.TextColor3 = COLORS.Yellow
		return
	end

	if State.Scanning then
		OverallStatus.Text = "ANALYZING"
		StatusDot.TextColor3 = COLORS.Blue
		return
	end

	if State.ScanComplete then
		OverallStatus.Text = "COMPLETE"
		StatusDot.TextColor3 = COLORS.Green
		return
	end

	OverallStatus.Text = "WAITING"
	StatusDot.TextColor3 = COLORS.Yellow
end

--//========================================================
--// STATS
--//========================================================

local function UpdateStats()
	StatsLabel.Text =
		"Objects       " .. tostring(State.ObjectCount) ..
		"\nAttributes    " .. tostring(State.AttributeCount) ..
		"\nTags          " .. tostring(State.TagCount) ..
		"\nValues        " .. tostring(State.ValueCount)

	PlayerInfo.Text =
		"Player information\n\n" ..
		"Name: " .. LocalPlayer.Name ..
		"\nDisplay Name: " .. LocalPlayer.DisplayName ..
		"\nUserId: " .. tostring(LocalPlayer.UserId) ..
		"\nCharacter: " .. (LocalPlayer.Character and LocalPlayer.Character.Name or "None")

	OverviewInfo.Text =
		"Phase 1 scanner • " ..
		tostring(State.ObjectCount) ..
		" objects discovered"
end

--//========================================================
--// PROPERTY COLLECTION
--//========================================================

local function CollectProperties(instance)
	local properties = {}

	pcall(function()
		if instance:IsA("BasePart") then
			properties.Size = tostring(instance.Size)
			properties.Position = tostring(instance.Position)
			properties.Anchored = instance.Anchored
			properties.CanCollide = instance.CanCollide
			properties.Transparency = instance.Transparency
		end
	end)

	pcall(function()
		if instance:IsA("Humanoid") then
			properties.Health = instance.Health
			properties.MaxHealth = instance.MaxHealth
			properties.WalkSpeed = instance.WalkSpeed
			properties.JumpPower = instance.JumpPower
			properties.HipHeight = instance.HipHeight
		end
	end)

	pcall(function()
		if instance:IsA("Tool") then
			properties.Enabled = instance.Enabled
			properties.ToolTip = instance.ToolTip
		end
	end)

	pcall(function()
		if instance:IsA("TextLabel")
			or instance:IsA("TextButton")
			or instance:IsA("TextBox") then

			properties.Text = instance.Text
			properties.Visible = instance.Visible
		end
	end)

	pcall(function()
		if instance:IsA("ImageLabel")
			or instance:IsA("ImageButton") then

			properties.Image = instance.Image
			properties.Visible = instance.Visible
		end
	end)

	pcall(function()
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

--//========================================================
--// SEARCH
--//========================================================

local function StringContains(text, search)
	text = string.lower(tostring(text or ""))
	search = string.lower(tostring(search or ""))

	return string.find(text, search, 1, true) ~= nil
end

local function ObjectMatchesSearch(data, search)
	if search == "" then
		return true
	end

	if StringContains(data.Name, search) then
		return true
	end

	if StringContains(data.ClassName, search) then
		return true
	end

	if StringContains(data.FullName, search) then
		return true
	end

	for key, value in pairs(data.Attributes or {}) do
		if StringContains(key, search) or StringContains(value, search) then
			return true
		end
	end

	for _, tag in ipairs(data.Tags or {}) do
		if StringContains(tag, search) then
			return true
		end
	end

	for key, value in pairs(data.Properties or {}) do
		if StringContains(key, search) or StringContains(value, search) then
			return true
		end
	end

	if data.Value ~= nil then
		if StringContains(data.Value, search) then
			return true
		end
	end

	return false
end

--//========================================================
--// RENDER SEARCH RESULTS
--//========================================================

local function ClearResults()
	for _, child in ipairs(ResultsFrame:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function RenderResults()
	ClearResults()

	local search = State.SearchText
	local shown = 0

	for _, data in ipairs(State.Objects) do
		if shown >= CONFIG.MAX_VISIBLE_RESULTS then
			break
		end

		if ObjectMatchesSearch(data, search) then
			shown += 1

			local Result = Instance.new("TextButton")
			Result.Name = "Result"
			Result.Size = UDim2.new(1, -4, 0, 22)
			Result.BackgroundColor3 = COLORS.Panel2
			Result.BorderSizePixel = 0
			Result.Text =
				data.Name ..
				"  [" ..
				data.ClassName ..
				"]"

			Result.TextColor3 = COLORS.Text
			Result.TextSize = 9
			Result.Font = Enum.Font.Gotham
			Result.TextXAlignment = Enum.TextXAlignment.Left
			Result.TextTruncate = Enum.TextTruncate.AtEnd
			Result.ZIndex = CONFIG.BASE_ZINDEX + 4
			Result.Parent = ResultsFrame

			local Padding = Instance.new("UIPadding")
			Padding.PaddingLeft = UDim.new(0, 6)
			Padding.PaddingRight = UDim.new(0, 4)
			Padding.Parent = Result

			local Corner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(0, 4)
			Corner.Parent = Result

			Result.MouseButton1Click:Connect(function()
				local detail =
					"Name: " .. data.Name ..
					"\nClass: " .. data.ClassName ..
					"\nPath: " .. data.FullName

				if next(data.Attributes) then
					detail = detail .. "\nAttributes: " .. tostring(#(function()
						local t = {}
						for key in pairs(data.Attributes) do
							table.insert(t, key)
						end
						return t
					end)())
				end

				Result.Text = data.Name .. "  [" .. data.ClassName .. "]"
			end)
		end
	end

	task.defer(function()
		ResultsFrame.CanvasSize = UDim2.new(
			0,
			0,
			0,
			ResultsLayout.AbsoluteContentSize.Y + 5
		)
	end)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	State.SearchText = SearchBox.Text
	RenderResults()
end)

--//========================================================
--// SCANNER
--//========================================================

local function ResetScanData()
	State.Objects = {}

	State.ObjectCount = 0
	State.AttributeCount = 0
	State.TagCount = 0
	State.ValueCount = 0

	State.CurrentIndex = 0
	State.TotalInstances = 0

	State.ScanComplete = false

	SetStatus("Structure", "WAITING")
	SetStatus("Attributes", "WAITING")
	SetStatus("Tags", "WAITING")
	SetStatus("Values", "WAITING")

	UpdateStats()
	ClearResults()
end

local function ScanInstance(instance)
	if State.ObjectCount >= CONFIG.MAX_RESULTS then
		return
	end

	local data = {
		Instance = instance,
		Name = instance.Name,
		ClassName = instance.ClassName,
		FullName = "",
		Attributes = {},
		Tags = {},
		Properties = {},
		Value = nil,
	}

	pcall(function()
		data.FullName = instance:GetFullName()
	end)

	--// ATTRIBUTES
	SetStatus("Attributes", "RUNNING")

	local attributeCount = 0

	local success, attributes = pcall(function()
		return instance:GetAttributes()
	end)

	if success and attributes then
		for key, value in pairs(attributes) do
			if attributeCount >= CONFIG.MAX_ATTRIBUTES_PER_OBJECT then
				break
			end

			data.Attributes[key] = value
			attributeCount += 1
			State.AttributeCount += 1
		end
	end

	SetStatus("Attributes", "PROCESSING")

	--// TAGS
	SetStatus("Tags", "RUNNING")

	local successTags, tags = pcall(function()
		return CollectionService:GetTags(instance)
	end)

	if successTags and tags then
		for index, tag in ipairs(tags) do
			if index > CONFIG.MAX_TAGS_PER_OBJECT then
				break
			end

			table.insert(data.Tags, tag)
			State.TagCount += 1
		end
	end

	SetStatus("Tags", "PROCESSING")

	--// VALUE OBJECTS
	SetStatus("Values", "RUNNING")

	if instance:IsA("ValueBase") then
		local successValue, value = pcall(function()
			return instance.Value
		end)

		if successValue then
			data.Value = value
			State.ValueCount += 1
		end
	end

	--// USEFUL PROPERTIES
	data.Properties = CollectProperties(instance)

	table.insert(State.Objects, data)

	State.ObjectCount += 1
end

local function StartScan()
	if State.Scanning then
		return
	end

	State.ScanToken += 1

	local scanToken = State.ScanToken

	ResetScanData()

	State.Scanning = true
	State.Paused = false

	UpdateOverallStatus()

	SetStatus("Structure", "RUNNING")

	local instances = workspace:GetDescendants()

	State.TotalInstances = #instances

	for index, instance in ipairs(instances) do
		if scanToken ~= State.ScanToken then
			return
		end

		while State.Paused do
			SetStatus("Structure", "PAUSED")
			SetStatus("Attributes", "PAUSED")
			SetStatus("Tags", "PAUSED")
			SetStatus("Values", "PAUSED")

			UpdateOverallStatus()

			task.wait(0.1)

			if scanToken ~= State.ScanToken then
				return
			end
		end

		if not State.Paused then
			SetStatus("Structure", "RUNNING")
			SetStatus("Attributes", "PROCESSING")
			SetStatus("Tags", "PROCESSING")
			SetStatus("Values", "PROCESSING")
		end

		State.CurrentIndex = index

		ScanInstance(instance)

		local progress = 0

		if State.TotalInstances > 0 then
			progress = math.floor(
				(index / State.TotalInstances) * 100
			)
		end

		ProgressLabel.Text = tostring(progress) .. "%"

		UpdateOverallStatus()
		UpdateStats()

		if index % CONFIG.BATCH_SIZE == 0 then
			RenderResults()
			task.wait(CONFIG.YIELD_TIME)
		end
	end

	if scanToken ~= State.ScanToken then
		return
	end

	State.Scanning = false
	State.Paused = false
	State.ScanComplete = true

	ProgressLabel.Text = "100%"

	SetStatus("Structure", "COMPLETE")
	SetStatus("Attributes", "COMPLETE")
	SetStatus("Tags", "COMPLETE")
	SetStatus("Values", "COMPLETE")

	UpdateOverallStatus()
	UpdateStats()
	RenderResults()
end

--//========================================================
--// PAUSE / RESUME
--//========================================================

PauseButton.MouseButton1Click:Connect(function()
	if not State.Scanning then
		return
	end

	State.Paused = not State.Paused

	if State.Paused then
		PauseButton.Text = "Resume"
	else
		PauseButton.Text = "Pause"
	end

	UpdateOverallStatus()
end)

--//========================================================
--// RESCAN
--//========================================================

ScanButton.MouseButton1Click:Connect(function()
	State.ScanToken += 1

	task.spawn(function()
		StartScan()
	end)
end)

--//========================================================
--// STATUS EXPAND / COLLAPSE
--//========================================================

local StatusExpanded = false

local function UpdateStatusLayout()
	if StatusExpanded then
		StatusDetails.Visible = true

		TabBar.Position = UDim2.new(0, 6, 0, 153)
		Content.Position = UDim2.new(0, 6, 0, 188)
		Content.Size = UDim2.new(1, -12, 0, 105)

		StatusExpandButton.Text = "▲"
	else
		StatusDetails.Visible = false

		TabBar.Position = UDim2.new(0, 6, 0, 73)
		Content.Position = UDim2.new(0, 6, 0, 108)
		Content.Size = UDim2.new(1, -12, 0, 105)

		StatusExpandButton.Text = "▼"
	end
end

StatusExpandButton.MouseButton1Click:Connect(function()
	StatusExpanded = not StatusExpanded
	UpdateStatusLayout()
end)

UpdateStatusLayout()

--//========================================================
--// MINIMIZE / HIDE
--//========================================================

MinimizeButton.MouseButton1Click:Connect(function()
	Main.Visible = false
	OpenButton.Visible = true
end)

HideButton.MouseButton1Click:Connect(function()
	Main.Visible = false
	OpenButton.Visible = true
end)

CloseButton.MouseButton1Click:Connect(function()
	Main.Visible = false
	OpenButton.Visible = true
end)

OpenButton.MouseButton1Click:Connect(function()
	Main.Visible = true
	OpenButton.Visible = false
end)

--//========================================================
--// DRAGGING
--//========================================================

local function MakeDraggable(frame, dragHandle)
	local dragging = false
	local dragStart
	local startPosition

	local function Update(input)
		local delta = input.Position - dragStart

		frame.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then

			dragging = true
			dragStart = input.Position
			startPosition = frame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then

			UserInputService.InputChanged:Connect(function(changedInput)
				if dragging and changedInput == input then
					Update(changedInput)
				end
			end)
		end
	end)
end

MakeDraggable(Main, TitleBar)
MakeDraggable(OpenButton, OpenButton)

--//========================================================
--// RESPAWN HANDLING
--//========================================================

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)

	if not ScreenGui.Parent then
		ScreenGui.Parent = PlayerGui
	end

	ScreenGui.DisplayOrder = CONFIG.DISPLAY_ORDER
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
end)

--//========================================================
--// ENSURE HIGH ZINDEX
--//========================================================

SetZIndexRecursive(Main, CONFIG.BASE_ZINDEX)
SetZIndexRecursive(OpenButton, CONFIG.BASE_ZINDEX + 20)

-- Restore specific higher-level layering
TitleBar.ZIndex = CONFIG.BASE_ZINDEX + 1
StatusHeader.ZIndex = CONFIG.BASE_ZINDEX + 1
StatusDetails.ZIndex = CONFIG.BASE_ZINDEX + 1
TabBar.ZIndex = CONFIG.BASE_ZINDEX + 1
Content.ZIndex = CONFIG.BASE_ZINDEX + 1
BottomBar.ZIndex = CONFIG.BASE_ZINDEX + 2
OpenButton.ZIndex = CONFIG.BASE_ZINDEX + 20

--//========================================================
--// INITIAL STATE
--//========================================================

UpdateStats()
UpdateOverallStatus()
UpdateTabCanvas()

--//========================================================
--// AUTO SCAN
--//========================================================

if CONFIG.AUTO_SCAN then
	task.spawn(function()
		task.wait(0.5)
		StartScan()
	end)
end
