-- Build A Boat For Treasure (BABFT)
-- Copy Build script reconstructed from the supplied source + video.
-- The video ends while the original dropdown definition is truncated,
-- so the dropdown/copy controls below are completed from the surrounding code.

local players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local player = players.LocalPlayer
local character
local humanoid
local HRP

local function refreshCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    HRP = character:WaitForChild("HumanoidRootPart")
end

refreshCharacter()

player.CharacterAdded:Connect(function()
    task.wait()
    refreshCharacter()
end)

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Build A Boat For Treasure",
    Icon = 0,
    LoadingTitle = "Rayfield Interface Suite",
    LoadingSubtitle = "Copy Build",
    Theme = "Default",
    ToggleUIKeybind = "G",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BABFT",
        FileName = "Build A Boat Config"
    },
})

local blockData = player:WaitForChild("Data")
local blocksFolder = workspace:WaitForChild("Blocks")
local ignoreAnchored = true
local rescaleClick = false
local selectedPlayer = nil
local usedList = {}

local function equipTool(toolName)
    if not character or not humanoid then
        refreshCharacter()
    end

    local tool = character:FindFirstChild(toolName)
    if tool then return tool end

    local backpack = player:FindFirstChildOfClass("Backpack")
    local backpackTool = backpack and backpack:FindFirstChild(toolName)
    if not backpackTool then
        warn("[BABFT] Tool not found: " .. toolName)
        return nil
    end

    local ok, err = pcall(function()
        humanoid:EquipTool(backpackTool)
    end)
    if not ok then
        warn("[BABFT] Equip failed: " .. tostring(err))
        return nil
    end

    for _ = 1, 20 do
        tool = character:FindFirstChild(toolName)
        if tool then return tool end
        task.wait(0.05)
    end

    warn("[BABFT] Tool did not enter Character: " .. toolName)
    return nil
end

local function getBlockID(name)
    local value = blockData:FindFirstChild(name)
    return value and value.Value or 9
end

local function getPlayerZone(playerInstance)
    if not playerInstance then return nil end

    local teamColor = playerInstance.TeamColor
    for _, v in pairs(workspace:GetChildren()) do
        local tc = v:FindFirstChild("TeamColor")
        if tc and tc.Value == teamColor then
            return v
        end
    end

    warn("Base Not Found for player: " .. playerInstance.Name)
    return nil
end

local function setTransparency(transparencyWanted, block)
    if not block or not block:FindFirstChild("PPart") then return end
    if block.PPart.Transparency == transparencyWanted then return end

    local tool = equipTool("PropertiesTool")
    if not tool or not tool:FindFirstChild("SetPropertieRF") then return end

    local calls = math.max(1, math.floor(transparencyWanted / 0.25))
    local args = {"Transparency", {block}}

    task.spawn(function()
        for _ = 1, calls do
            local ok, err = pcall(function()
                tool.SetPropertieRF:InvokeServer(unpack(args))
            end)
            if not ok then
                warn("[BABFT] Transparency failed: " .. tostring(err))
                break
            end
            task.wait(0.03)
        end
    end)
end

local function setAnchored(block)
    if not block then return end

    local tool = equipTool("PropertiesTool")
    if not tool or not tool:FindFirstChild("SetPropertieRF") then return end

    local ok, err = pcall(function()
        tool.SetPropertieRF:InvokeServer("Anchored", {block})
    end)
    if not ok then
        warn("[BABFT] Anchored failed: " .. tostring(err))
    end
end

local function rescaleBlock(block, newPos, newSize)
    if not block then return end

    local tool = equipTool("ScalingTool")
    if not tool or not tool:FindFirstChild("RF") then return end

    local ok, err = pcall(function()
        tool.RF:InvokeServer(block, newSize, newPos)
    end)
    if not ok then
        warn("[BABFT] Rescale failed: " .. tostring(err))
    end
end

local function placeBlock(name, pos, relativeTo, anchored)
    local tool = equipTool("BuildingTool")
    if not tool or not tool:FindFirstChild("RF") then return end

    if not relativeTo then
        relativeTo = getPlayerZone(player)
    end

    local args = {
        name,
        getBlockID(name),
        relativeTo,
        relativeTo and relativeTo.CFrame:ToObjectSpace(pos) or CFrame.new(),
        ignoreAnchored and true or anchored,
        pos,
        false,
    }

    local ok, err = pcall(function()
        tool.RF:InvokeServer(unpack(args))
    end)
    if not ok then
        warn("[BABFT] Place failed: " .. tostring(err))
    end
end

local function paintBlock(block, color)
    if not block or not block:FindFirstChild("PPart") then return end
    if block.PPart.Color == color then return end

    local tool = equipTool("PaintingTool")
    if not tool or not tool:FindFirstChild("RF") then return end

    local ok, err = pcall(function()
        tool.RF:InvokeServer({{block, color}})
    end)
    if not ok then
        warn("[BABFT] Paint failed: " .. tostring(err))
    end
end

local function getJoint(model)
    if not model or not model:FindFirstChild("PPart") then
        return getPlayerZone(player)
    end

    for _, v in pairs(model.PPart:GetChildren()) do
        if v:IsA("Snap") or v:IsA("Weld") then
            if v.Part1 and v.Part1.Parent ~= model then
                return v.Part1
            end
        end
    end

    return getPlayerZone(player)
end

local function getNewBlockPos(hisBase, block, myBase)
    if not block or not block:FindFirstChild("PPart") then
        return CFrame.new()
    end

    if not hisBase or not myBase then
        return block.PPart.CFrame
    end

    local offset = hisBase.CFrame:ToObjectSpace(block.PPart.CFrame)
    return myBase.CFrame * offset
end

local function copyBuild(blocks)
    local t = {}
    local myBase = getPlayerZone(player)
    local sourcePlayer = players:FindFirstChild(blocks.Name)
    local hisBase = sourcePlayer and getPlayerZone(sourcePlayer)

    if not myBase then
        warn("Your base was not found")
        return t
    end

    usedList = {}

    for _, block in ipairs(blocks:GetChildren()) do
        if block:FindFirstChild("PPart") then
            local blockID = getBlockID(block.Name)

            if blockID ~= 0 and (usedList[block.Name] or 0) < blockID then
                usedList[block.Name] = (usedList[block.Name] or 0) + 1

                table.insert(t, {
                    Name = block.Name,
                    Pos = getNewBlockPos(hisBase, block, myBase),
                    Relative = myBase,
                    Transparency = block.PPart.Transparency,
                    Anchored = block.PPart.Anchored,
                    Size = block.PPart.Size,
                    Color = block.PPart.Color,
                })
            end
        end
    end

    return t
end

local function getMissingBlocks(expectedList, createdList)
    local missing = {}

    for i, v in ipairs(expectedList) do
        local found = false
        for _, b in ipairs(createdList) do
            if b and b:FindFirstChild("PPart") and b.Name == v.Name then
                found = true
                break
            end
        end
        if not found then
            table.insert(missing, {Index = i, Name = v.Name, Pos = v.Pos})
        end
    end

    return missing
end

local function getBlock(expected, createdList)
    local best = nil
    local bestDist = math.huge

    for _, b in ipairs(createdList) do
        if b and b:IsA("Model") and b.Name == expected.Name then
            local ppart = b:FindFirstChild("PPart")
            if ppart and ppart:IsA("BasePart") then
                local dist = (ppart.Position - expected.Pos.Position).Magnitude
                if dist < bestDist then
                    best = b
                    bestDist = dist
                end
            end
        end
    end

    return best, bestDist
end

local function getPlayers()
    local result = {}
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= player then
            table.insert(result, p.DisplayName)
        end
    end
    return result
end

local function getRealName(displayName)
    for _, v in pairs(players:GetPlayers()) do
        if v.DisplayName == displayName then
            return v.Name
        end
    end
    return nil
end

local function getSourceFolder(p)
    if not p then return nil end
    return blocksFolder:FindFirstChild(p.Name)
end

local function runCopyBuild(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then
        Rayfield:Notify({
            Title = "Copy Build",
            Content = "เลือกผู้เล่นก่อน",
            Duration = 3
        })
        return
    end

    local sourceFolder = getSourceFolder(targetPlayer)
    if not sourceFolder then
        Rayfield:Notify({
            Title = "Copy Build",
            Content = "ไม่พบ Blocks ของผู้เล่นนี้",
            Duration = 4
        })
        return
    end

    local build = copyBuild(sourceFolder)
    if #build == 0 then
        Rayfield:Notify({
            Title = "Copy Build",
            Content = "ไม่พบบล็อกที่สามารถก็อปได้",
            Duration = 4
        })
        return
    end

    local total = #build
    local placed = 0

    Rayfield:Notify({
        Title = "Copy Build",
        Content = "กำลังวาง " .. total .. " บล็อก...",
        Duration = 3
    })

    for i, v in ipairs(build) do
        placeBlock(v.Name, v.Pos, v.Relative, v.Anchored)
        placed += 1

        if i % 5 == 0 then
            task.wait(0.15)
        else
            task.wait(0.05)
        end
    end

    task.wait(1)

    local myBase = getPlayerZone(player)
    if not myBase then
        Rayfield:Notify({
            Title = "Copy Build",
            Content = "วางแล้ว แต่หา Base ของเราไม่เจอสำหรับแก้สี/ขนาด",
            Duration = 5
        })
        return
    end

    local created = myBase:GetChildren()
    local edited = 0

    for i, v in ipairs(build) do
        local b, dist = getBlock(v, created)

        if b and dist <= 8 then
            rescaleBlock(b, v.Pos, v.Size)
            task.wait(0.03)
            paintBlock(b, v.Color)
            task.wait(0.03)

            if v.Transparency > 0 then
                setTransparency(v.Transparency, b)
            end

            if v.Anchored then
                setAnchored(b)
            end

            edited += 1
        end

        if i % 10 == 0 then
            task.wait(0.1)
        end
    end

    Rayfield:Notify({
        Title = "Copy Build",
        Content = "เสร็จ: วาง " .. placed .. "/" .. total ..
            " | ปรับแต่งได้ " .. edited .. "/" .. total,
        Duration = 6
    })
end

local autoBuildTab = Window:CreateTab("Building", "rewind")

autoBuildTab:CreateButton({
    Name = "Place Wood Block",
    Callback = function()
        placeBlock("WoodBlock", HRP.CFrame, nil, true)
    end,
})

autoBuildTab:CreateToggle({
    Name = "Rescale Block (click block)",
    Callback = function(value)
        rescaleClick = value
    end,
})

local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
    if not rescaleClick or not mouse.Target then return end

    local ppart = mouse.Target
    local model = ppart.Parent
    if model and model:IsA("Model") and model:FindFirstChild("PPart") then
        rescaleBlock(model, ppart.CFrame, Vector3.new(4, 4, 4))
    end
end)

local playerDropdown = autoBuildTab:CreateDropdown({
    Name = "Choose Player",
    Options = getPlayers(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local displayName = type(option) == "table" and option[1] or option
        if type(displayName) == "string" then
            local realName = getRealName(displayName)
            selectedPlayer = realName and players:FindFirstChild(realName) or nil
        end
    end,
})

autoBuildTab:CreateButton({
    Name = "Refresh Player List",
    Callback = function()
        playerDropdown:Refresh(getPlayers())
    end,
})

autoBuildTab:CreateButton({
    Name = "COPY BUILD",
    Callback = function()
        runCopyBuild(selectedPlayer)
    end,
})

players.PlayerAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        playerDropdown:Refresh(getPlayers())
    end)
end)

players.PlayerRemoving:Connect(function()
    task.wait(0.2)
    pcall(function()
        playerDropdown:Refresh(getPlayers())
    end)
end)

Rayfield:Notify({
    Title = "BABFT Copy Build",
    Content = "โหลดสคริปต์แล้ว",
    Duration = 4,
})
