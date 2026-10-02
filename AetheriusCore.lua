-- AetheriusCore: Phase 1 Scanner Foundation (Delta Optimized)
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local ScanConfig = {
    MaxDepth = 5,
    YieldEvery = 200, -- Prevents mobile lag spikes
}

local function scanInstance(instance, currentDepth)
    if currentDepth > ScanConfig.MaxDepth then return nil end
    
    local data = {
        Name = instance.Name,
        ClassName = instance.ClassName,
        Children = {}
    }
    
    local count = 0
    for _, child in ipairs(instance:GetChildren()) do
        count = count + 1
        if count % ScanConfig.YieldEvery == 0 then
            task.wait() -- Yield to keep mobile FPS stable
        end
        
        local childData = scanInstance(child, currentDepth + 1)
        if childData then
            table.insert(data.Children, childData)
        end
    end
    
    return data
end

print("[AetheriusCore]: Starting initial Workspace scan...")
local startTime = tick()
local workspaceScan = scanInstance(Workspace, 1)
print("[AetheriusCore]: Scan completed in " .. string.format("%.2f", tick() - startTime) .. " seconds.")

-- Utilize Delta's filesystem feature to export the raw scan
if writefile then
    if not isfolder("AetheriusCore") then
        makefolder("AetheriusCore")
    end
    writefile("AetheriusCore/WorkspaceScan.json", HttpService:JSONEncode(workspaceScan))
    print("[AetheriusCore]: Scan saved successfully to Delta/workspace/AetheriusCore/WorkspaceScan.json")
end
