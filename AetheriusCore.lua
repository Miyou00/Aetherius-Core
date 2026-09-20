--[[
    ⚡ AETHERIUS CORE v10.0 [AUTONOMOUS INTELLIGENCE ENGINE]
    -------------------------------------------------------
    Phase 1: Dynamic UI Engine & Panel Generator (Centered Layout)
    Phase 2: Target Memory Pool, Attribute Scraper & Visualizer
    Phase 3: Outgoing Remote Interceptor & Hash Synthesizer
    Phase 4: Crowdsourced Player Learning, Confidence Scoring & Safety
    + Boot-Time Immediate Environment Auto-Discovery
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Global State & Execution Protection
_G.IgnoreAutoHooks = false
_G.AutoSynthesizeRemotes = true
_G.AutoEnableDiscoveredModules = false

-- Clean existing UI instances
pcall(function()
    local old = LocalPlayer.PlayerGui:FindFirstChild("AetheriusCoreEngine")
    if old then old:Destroy() end
end)

--------------------------------------------------------------------------------
-- PHASE 1: CORE FRAMEWORK & UI ENGINE
--------------------------------------------------------------------------------
local EngineUI = {}
local ModulesRegistry = {}
local ModuleSignatures = {}
local ActiveTargetPool = {}
local ObservedPlayerActions = {}

-- Main ScreenGui Setup
local gui = Instance.new("ScreenGui")
gui.Name = "AetheriusCoreEngine"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Centered & Draggable Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(450, 310)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 15)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = mainFrame

-- Top Bar Header
local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 22)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
bar.BorderSizePixel = 0
bar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -35, 1, 0)
title.Position = UDim2.fromOffset(6, 0)
title.BackgroundTransparency = 1
title.Text = "⚡ AETHERIUS CORE [v10.0 Autonomous Engine]"
title.TextColor3 = Color3.fromRGB(0, 255, 127)
title.TextSize = 9
title.Font = Enum.Font.Code
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(20, 16)
closeBtn.Position = UDim2.new(1, -23, 0, 3)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 9
closeBtn.Font = Enum.Font.Code
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = bar
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 3)
closeCorner.Parent = closeBtn

-- Window Dragging Functionality (AnchorPoint-aware)
local dragging, dragStart, startPos
bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Navigation Bar & Tabs
local navBar = Instance.new("Frame")
navBar.Size = UDim2.new(1, -12, 0, 20)
navBar.Position = UDim2.fromOffset(6, 26)
navBar.BackgroundTransparency = 1
navBar.Parent = mainFrame

local function createTabButton(text, xPos, width)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(width, 20)
    btn.Position = UDim2.fromOffset(xPos, 0)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(160, 160, 170)
    btn.TextSize = 8
    btn.Font = Enum.Font.Code
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    btn.BorderSizePixel = 0
    btn.Parent = navBar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    return btn
end

local tabSpyBtn = createTabButton("📡 Live Spy", 0, 75)
local tabModulesBtn = createTabButton("⚡ Auto Modules", 80, 95)
local tabPanelBtn = createTabButton("🎛️ Panel Controls", 180, 105)

-- Container Generator
local function createContainer()
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -12, 1, -54)
    container.Position = UDim2.fromOffset(6, 48)
    container.BackgroundTransparency = 1
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 127)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = container
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = scroll
    
    return container, scroll
end

local spyContainer, spyScroll = createContainer()
spyContainer.Parent = mainFrame

local modulesContainer, modulesScroll = createContainer()
modulesContainer.Visible = false
modulesContainer.Parent = mainFrame

local panelContainer, panelScroll = createContainer()
panelContainer.Visible = false
panelContainer.Parent = mainFrame

local function switchTab(tab)
    spyContainer.Visible = (tab == "spy")
    modulesContainer.Visible = (tab == "modules")
    panelContainer.Visible = (tab == "panel")
    tabSpyBtn.TextColor3 = (tab == "spy") and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(160, 160, 170)
    tabModulesBtn.TextColor3 = (tab == "modules") and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(160, 160, 170)
    tabPanelBtn.TextColor3 = (tab == "panel") and Color3.fromRGB(0, 255, 127) or Color3.fromRGB(160, 160, 170)
end

tabSpyBtn.MouseButton1Click:Connect(function() switchTab("spy") end)
tabModulesBtn.MouseButton1Click:Connect(function() switchTab("modules") end)
tabPanelBtn.MouseButton1Click:Connect(function() switchTab("panel") end)

--------------------------------------------------------------------------------
-- PHASE 2: TARGET SCANNER, MEMORY POOL & VISUALIZER
--------------------------------------------------------------------------------
local TargetScanner = {}
local activeHighlight = Instance.new("Highlight")
activeHighlight.FillColor = Color3.fromRGB(0, 255, 127)
activeHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
activeHighlight.FillTransparency = 0.4

function TargetScanner:Highlight(instance)
    if instance and instance:IsA("PVInstance") then
        activeHighlight.Adornee = instance
        activeHighlight.Parent = instance
    else
        activeHighlight.Parent = nil
    end
end

function TargetScanner:ExtractAttributeValues(container, attributeName)
    local found = { "All" }
    if not container then return found end

    for _, child in ipairs(container:GetChildren()) do
        local attrVal = child:GetAttribute(attributeName) or (child:FindFirstChild(attributeName) and child[attributeName].Value)
        if attrVal then
            local strVal = tostring(attrVal)
            if not table.find(found, strVal) then
                table.insert(found, strVal)
            end
        end
    end
    return found
end

function TargetScanner:CalculateServerOdds(container)
    if not container then return "N/A" end
    local total = #container:GetChildren()
    if total == 0 then return "Empty Container" end

    local counts = {}
    for _, child in ipairs(container:GetChildren()) do
        local key = child:GetAttribute("Rarity") or child.Name
        counts[key] = (counts[key] or 0) + 1
    end

    local result = ""
    for name, count in pairs(counts) do
        local pct = math.floor((count / total) * 100 + 0.5)
        result = result .. tostring(name) .. " (" .. tostring(pct) .. "%) | "
    end
    return string.sub(result, 1, #result - 3)
end

--------------------------------------------------------------------------------
-- PHASE 3 & 4: MODULE SYNTHESIS, CONFIDENCE & SAFETY ENGINE
--------------------------------------------------------------------------------
local function RenderModuleCard(moduleData)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, 48)
    card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    card.Parent = modulesScroll

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 4)
    cardCorner.Parent = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -140, 0, 16)
    nameLbl.Position = UDim2.fromOffset(6, 3)
    nameLbl.Text = "⚡ " .. moduleData.Name
    nameLbl.TextColor3 = Color3.fromRGB(0, 229, 255)
    nameLbl.TextSize = 8
    nameLbl.Font = Enum.Font.Code
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = card

    local provLbl = Instance.new("TextLabel")
    provLbl.Size = UDim2.new(1, -140, 0, 14)
    provLbl.Position = UDim2.fromOffset(6, 18)
    provLbl.Text = moduleData.SourceTag .. " | Confidence: " .. tostring(moduleData.ConfidenceScore) .. "%"
    provLbl.TextColor3 = Color3.fromRGB(130, 130, 140)
    provLbl.TextSize = 7
    provLbl.Font = Enum.Font.Code
    provLbl.TextXAlignment = Enum.TextXAlignment.Left
    provLbl.Parent = card

    local oddsLbl = Instance.new("TextLabel")
    oddsLbl.Size = UDim2.new(1, -140, 0, 14)
    oddsLbl.Position = UDim2.fromOffset(6, 31)
    oddsLbl.Text = "Odds: " .. TargetScanner:CalculateServerOdds(moduleData.TargetContainer)
    oddsLbl.TextColor3 = Color3.fromRGB(0, 255, 127)
    oddsLbl.TextSize = 6
    oddsLbl.Font = Enum.Font.Code
    oddsLbl.TextXAlignment = Enum.TextXAlignment.Left
    oddsLbl.Parent = card

    -- Action Control Buttons
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.fromOffset(42, 18)
    toggleBtn.Position = UDim2.new(1, -132, 0, 15)
    toggleBtn.Text = moduleData.Enabled and "ON" or "OFF"
    toggleBtn.BackgroundColor3 = moduleData.Enabled and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(50, 50, 60)
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.TextSize = 7
    toggleBtn.Font = Enum.Font.Code
    toggleBtn.Parent = card

    local panelBtn = Instance.new("TextButton")
    panelBtn.Size = UDim2.fromOffset(42, 18)
    panelBtn.Position = UDim2.new(1, -86, 0, 15)
    panelBtn.Text = "Panel"
    panelBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 140)
    panelBtn.TextColor3 = Color3.new(1, 1, 1)
    panelBtn.TextSize = 7
    panelBtn.Font = Enum.Font.Code
    panelBtn.Parent = card

    local deleteBtn = Instance.new("TextButton")
    deleteBtn.Size = UDim2.fromOffset(36, 18)
    deleteBtn.Position = UDim2.new(1, -40, 0, 15)
    deleteBtn.Text = "🗑️"
    deleteBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    deleteBtn.TextColor3 = Color3.new(1, 1, 1)
    deleteBtn.TextSize = 7
    deleteBtn.Font = Enum.Font.Code
    deleteBtn.Parent = card

    -- Loop Controller Task
    local function startExecutionLoop()
        task.spawn(function()
            while moduleData.Enabled do
                -- Phase 4 Safety Watchdog Check
                local char = LocalPlayer.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                local safeToRun = true

                if humanoid and moduleData.Settings.AutoPauseHealth then
                    if (humanoid.Health / humanoid.MaxHealth) * 100 < moduleData.Settings.AutoPauseHealth then
                        safeToRun = false
                    end
                end

                if safeToRun and moduleData.TargetContainer then
                    local validTargets = {}
                    for _, child in ipairs(moduleData.TargetContainer:GetChildren()) do
                        local attrRarity = child:GetAttribute("Rarity") or (child:FindFirstChild("Rarity") and child.Rarity.Value)
                        if moduleData.Settings.RarityFilter == "All" or tostring(attrRarity) == moduleData.Settings.RarityFilter then
                            table.insert(validTargets, child)
                        end
                    end

                    if #validTargets > 0 then
                        local chosen = validTargets[1]
                        if moduleData.Settings.HighlightTarget == "ON" then
                            TargetScanner:Highlight(chosen)
                        end

                        _G.IgnoreAutoHooks = true
                        if moduleData.RemoteInstance:IsA("RemoteEvent") then
                            moduleData.RemoteInstance:FireServer(chosen)
                        elseif moduleData.RemoteInstance:IsA("RemoteFunction") then
                            moduleData.RemoteInstance:InvokeServer(chosen)
                        end
                        _G.IgnoreAutoHooks = false
                    end
                end

                task.wait(moduleData.Settings.LoopInterval or 0.8)
            end
            TargetScanner:Highlight(nil)
        end)
    end

    toggleBtn.MouseButton1Click:Connect(function()
        moduleData.Enabled = not moduleData.Enabled
        toggleBtn.Text = moduleData.Enabled and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = moduleData.Enabled and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(50, 50, 60)
        if moduleData.Enabled then startExecutionLoop() end
    end)

    deleteBtn.MouseButton1Click:Connect(function()
        ModulesRegistry[moduleData.Id] = nil
        card:Destroy()
    end)

    -- Build Phase 1 Panel Controls dynamically
    panelBtn.MouseButton1Click:Connect(function()
        for _, child in ipairs(panelScroll:GetChildren()) do
            if not child:IsA("UIListLayout") then child:Destroy() end
        end

        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 20)
        header.Text = "=== [ Panel Controls: " .. moduleData.Name .. " ] ==="
        header.TextColor3 = Color3.fromRGB(0, 229, 255)
        header.TextSize = 8
        header.Font = Enum.Font.Code
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = panelScroll

        -- Render Configuration Options
        for settingKey, settingVal in pairs(moduleData.Settings) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -8, 0, 22)
            row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
            row.Parent = panelScroll

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0.5, 0, 1, 0)
            label.Position = UDim2.fromOffset(4, 0)
            label.Text = settingKey
            label.TextColor3 = Color3.fromRGB(200, 200, 210)
            label.TextSize = 7
            label.Font = Enum.Font.Code
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = row

            if moduleData.Controls[settingKey] then
                local ctrlDef = moduleData.Controls[settingKey]
                if ctrlDef.Type == "Cycle" then
                    local cycleBtn = Instance.new("TextButton")
                    cycleBtn.Size = UDim2.new(0.45, 0, 0.8, 0)
                    cycleBtn.Position = UDim2.new(0.52, 0, 0.1, 0)
                    cycleBtn.Text = tostring(moduleData.Settings[settingKey])
                    cycleBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
                    cycleBtn.TextColor3 = Color3.fromRGB(0, 255, 127)
                    cycleBtn.TextSize = 7
                    cycleBtn.Font = Enum.Font.Code
                    cycleBtn.Parent = row

                    cycleBtn.MouseButton1Click:Connect(function()
                        local opts = ctrlDef.Options
                        local idx = table.find(opts, moduleData.Settings[settingKey]) or 1
                        local nextVal = opts[(idx % #opts) + 1]
                        moduleData.Settings[settingKey] = nextVal
                        cycleBtn.Text = tostring(nextVal)
                    end)
                end
            end
        end

        switchTab("panel")
    end)
end

-- Phase 3: Outgoing Remote Interception & Auto Synthesizer Engine
local function RegisterOrUpdateModule(remoteInstance, targetInstance, provenanceUser)
    if not targetInstance or not targetInstance.Parent then return end

    local parentContainer = targetInstance.Parent
    local signatureHash = remoteInstance:GetFullName() .. "_" .. parentContainer:GetFullName()

    if ModuleSignatures[signatureHash] then
        -- Update existing confidence score and observation count
        local modId = ModuleSignatures[signatureHash]
        if ModulesRegistry[modId] then
            ModulesRegistry[modId].Observations = ModulesRegistry[modId].Observations + 1
            if ModulesRegistry[modId].Observations >= 3 then
                ModulesRegistry[modId].ConfidenceScore = 98
            end
        end
        return
    end

    local moduleId = "Mod_" .. remoteInstance.Name .. "_" .. parentContainer.Name
    ModuleSignatures[signatureHash] = moduleId

    local rarityOptions = TargetScanner:ExtractAttributeValues(parentContainer, "Rarity")

    local newModule = {
        Id = moduleId,
        Name = remoteInstance.Name .. " [" .. parentContainer.Name .. "]",
        RemoteInstance = remoteInstance,
        TargetContainer = parentContainer,
        SourceTag = provenanceUser and ("Discovered via Player: " .. provenanceUser) or "Discovered via Local Action",
        ConfidenceScore = provenanceUser and 85 or 99,
        Observations = 1,
        Enabled = _G.AutoEnableDiscoveredModules or false,
        Settings = {
            RarityFilter = rarityOptions[1] or "All",
            HighlightTarget = "ON",
            LoopInterval = 0.8,
            AutoPauseHealth = 20
        },
        Controls = {
            RarityFilter = { Type = "Cycle", Options = rarityOptions },
            HighlightTarget = { Type = "Cycle", Options = { "ON", "OFF" } }
        }
    }

    ModulesRegistry[moduleId] = newModule
    RenderModuleCard(newModule)
end

-- Interceptor Hook for Outgoing Remote Calls
local function InterceptRemoteCall(remote, args)
    if _G.IgnoreAutoHooks or not _G.AutoSynthesizeRemotes then return end

    -- Log to Live Spy
    local logCard = Instance.new("Frame")
    logCard.Size = UDim2.new(1, -8, 0, 16)
    logCard.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    logCard.Parent = spyScroll

    local logLbl = Instance.new("TextLabel")
    logLbl.Size = UDim2.new(1, 0, 1, 0)
    logLbl.Position = UDim2.fromOffset(4, 0)
    logLbl.Text = "[Captured] " .. remote.Name .. " | Args: " .. tostring(#args)
    logLbl.TextColor3 = Color3.fromRGB(0, 255, 127)
    logLbl.TextSize = 7
    logLbl.Font = Enum.Font.Code
    logLbl.TextXAlignment = Enum.TextXAlignment.Left
    logLbl.Parent = logCard

    -- Extract Workspace Target Slot
    local targetInstance = nil
    for _, arg in ipairs(args) do
        if typeof(arg) == "Instance" and arg:IsDescendantOf(workspace) then
            targetInstance = arg
            break
        end
    end

    if targetInstance then
        RegisterOrUpdateModule(remote, targetInstance, nil)
    end
end

-- Hook Remote Event / Function Meta-methods
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not _G.IgnoreAutoHooks and (method == "FireServer" or method == "InvokeServer") then
        task.spawn(function()
            InterceptRemoteCall(self, args)
        end)
    end

    return oldNamecall(self, ...)
end)

-- Boot-Time Immediate Environment Auto-Discovery Subsystem
local function AutoScanEnvironmentOnBoot()
    local commonKeywords = {"mine", "collect", "gather", "interact", "open", "farm", "harvest", "egg", "ore", "chest"}
    
    for _, folder in ipairs(workspace:GetChildren()) do
        if #folder:GetChildren() > 0 and not Players:GetPlayerFromCharacter(folder) then
            local folderNameLower = folder.Name:lower()
            
            for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local remoteNameLower = remote.Name:lower()
                    
                    for _, keyword in ipairs(commonKeywords) do
                        if string.find(remoteNameLower, keyword) or string.find(folderNameLower, keyword) then
                            if #folder:GetChildren() > 0 then
                                local sampleTarget = folder:GetChildren()[1]
                                RegisterOrUpdateModule(remote, sampleTarget, "Auto-Discovered Environment")
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end

-- Run immediate scan on execution
task.spawn(AutoScanEnvironmentOnBoot)

-- Phase 4: Crowdsourced Other-Player Interaction Watchdog
task.spawn(function()
    while task.wait(1.5) do
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                -- Scan surrounding objects within 8 studs of other active players
                for _, descendant in ipairs(workspace:GetDescendants()) do
                    if descendant:IsA("BasePart") and not descendant:IsDescendantOf(player.Character) then
                        if (descendant.Position - hrp.Position).Magnitude < 8 then
                            -- Check if object belongs to a valid target container
                            if descendant.Parent and descendant.Parent ~= workspace then
                                -- Match potential remotes in ReplicatedStorage
                                for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
                                    if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                                        if string.find(remote.Name:lower(), "mine") or string.find(remote.Name:lower(), "collect") or string.find(remote.Name:lower(), "gather") or string.find(remote.Name:lower(), "interact") then
                                            RegisterOrUpdateModule(remote, descendant, player.Name)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
