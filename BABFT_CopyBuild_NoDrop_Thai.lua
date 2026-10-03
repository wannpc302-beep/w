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

local function findPlacedBlock(folder, expected, tolerance)
    if not folder then return nil, math.huge end

    local best, bestDist = nil, math.huge
    for _, b in ipairs(folder:GetChildren()) do
        if b:IsA("Model") and b.Name == expected.Name then
            local pp = b:FindFirstChild("PPart")
            if pp and pp:IsA("BasePart") then
                local d = (pp.Position - expected.Pos.Position).Magnitude
                if d < bestDist then
                    best, bestDist = b, d
                end
            end
        end
    end

    if best and bestDist <= (tolerance or 6) then
        return best, bestDist
    end

    return nil, bestDist
end

local function placeAndVerify(expected, destinationFolder)
    local maxAttempts = 4

    for attempt = 1, maxAttempts do
        -- Give the server a little more time on later attempts.
        if attempt > 1 then
            task.wait(0.15 * attempt)
        end

        -- วางทุกบล็อกให้ Anchor ไว้ก่อน เพื่อไม่ให้บล็อกตก
        -- จะคืนค่า Anchored จริงของแต่ละบล็อกหลังสร้างครบทั้งหมด
        placeBlock(expected.Name, expected.Pos, expected.Relative, true)

        -- Wait for replication and verify by position + block name.
        local deadline = os.clock() + (0.9 + attempt * 0.25)
        repeat
            local b, dist = findPlacedBlock(destinationFolder, expected, 6)
            if b then
                return b
            end
            task.wait(0.08)
        until os.clock() >= deadline
    end

    return nil
end


-- Copy status UI
local copyStatus = {
    total = 0,
    placed = 0,
    missing = 0,
    percent = 0,
    running = false
}

local statusFrame
local statusTitle
local statusText
local progressBar
local progressFill

local function createCopyStatusUI()
    if statusFrame and statusFrame.Parent then
        return
    end

    statusFrame = Instance.new("Frame")
    statusFrame.Name = "CopyBuildStatus"
    statusFrame.Size = UDim2.new(0, 310, 0, 145)
    statusFrame.Position = UDim2.new(0.5, -155, 0, 80)
    statusFrame.BackgroundTransparency = 0.08
    statusFrame.Parent = Rayfield.Main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = statusFrame

    statusTitle = Instance.new("TextLabel")
    statusTitle.Size = UDim2.new(1, -20, 0, 30)
    statusTitle.Position = UDim2.new(0, 10, 0, 8)
    statusTitle.BackgroundTransparency = 1
    statusTitle.Text = "คัดลอกสิ่งก่อสร้าง"
    statusTitle.TextSize = 18
    statusTitle.Font = Enum.Font.GothamBold
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.Parent = statusFrame

    statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -20, 0, 55)
    statusText.Position = UDim2.new(0, 10, 0, 40)
    statusText.BackgroundTransparency = 1
    statusText.Text = "พร้อมใช้งาน"
    statusText.TextSize = 14
    statusText.Font = Enum.Font.Gotham
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextYAlignment = Enum.TextYAlignment.Top
    statusText.Parent = statusFrame

    local bar = Instance.new("Frame")
    bar.Name = "ProgressBar"
    bar.Size = UDim2.new(1, -20, 0, 14)
    bar.Position = UDim2.new(0, 10, 1, -25)
    bar.BackgroundTransparency = 0.35
    bar.Parent = statusFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 7)
    barCorner.Parent = bar

    progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundTransparency = 0
    progressFill.Parent = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 7)
    fillCorner.Parent = progressFill
end

local function updateCopyStatus(total, placed, missing, running)
    createCopyStatusUI()

    copyStatus.total = total or 0
    copyStatus.placed = placed or 0
    copyStatus.missing = missing or 0
    copyStatus.running = running == true

    if copyStatus.total > 0 then
        copyStatus.percent = math.floor((copyStatus.placed / copyStatus.total) * 100 + 0.5)
    else
        copyStatus.percent = 0
    end

    statusText.Text = ("ทั้งหมด: %d\nวางสำเร็จ: %d\nขาด: %d\nความคืบหน้า: %d%%"):format(
        copyStatus.total,
        copyStatus.placed,
        copyStatus.missing,
        copyStatus.percent
    )

    progressFill.Size = UDim2.new(
        math.clamp(copyStatus.percent / 100, 0, 1),
        0, 1, 0
    )
end

createCopyStatusUI()
updateCopyStatus(0, 0, 0, false)

local function runCopyBuild(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then
        Rayfield:Notify({
            Title = "คัดลอกสิ่งก่อสร้าง",
            Content = "กรุณาเลือกผู้เล่นก่อน",
            Duration = 3
        })
        return
    end

    local sourceFolder = getSourceFolder(targetPlayer)
    if not sourceFolder then
        Rayfield:Notify({
            Title = "คัดลอกสิ่งก่อสร้าง",
            Content = "ไม่พบบล็อกของผู้เล่นนี้",
            Duration = 4
        })
        return
    end

    local build = copyBuild(sourceFolder)
    if #build == 0 then
        Rayfield:Notify({
            Title = "คัดลอกสิ่งก่อสร้าง",
            Content = "ไม่พบบล็อกที่สามารถคัดลอกได้",
            Duration = 4
        })
        return
    end

    local destinationFolder = blocksFolder:FindFirstChild(player.Name)
    if not destinationFolder then
        Rayfield:Notify({
            Title = "คัดลอกสิ่งก่อสร้าง",
            Content = "ไม่พบโฟลเดอร์สิ่งก่อสร้างของเรา",
            Duration = 4
        })
        return
    end

    local total = #build
    local placed = 0
    local failed = {}

    updateCopyStatus(total, 0, total, true)

    Rayfield:Notify({
        Title = "คัดลอกสิ่งก่อสร้าง",
        Content = "กำลังสร้าง " .. total .. " บล็อกโดยยึดไว้ไม่ให้ตก...",
        Duration = 4
    })

    -- Place one block, verify it replicated, then continue.
    -- This is slower but prevents server-side throttling from silently
    -- dropping blocks.
    for i, expected in ipairs(build) do
        local b = placeAndVerify(expected, destinationFolder)

        if b then
            placed += 1
        else
            table.insert(failed, i)
        end

        updateCopyStatus(total, placed, total - placed, true)

        if i % 10 == 0 then
            Rayfield:Notify({
                Title = "คัดลอกสิ่งก่อสร้าง",
                Content = ("ความคืบหน้า %d/%d | ขาด %d"):format(
                    placed, total, #failed
                ),
                Duration = 2
            })
        end
    end

    -- One final retry pass for anything that was rejected/throttled.
    if #failed > 0 then
        local retry = failed
        failed = {}

        task.wait(1)

        for _, index in ipairs(retry) do
            local b = placeAndVerify(build[index], destinationFolder)
            if b then
                placed += 1
            else
                table.insert(failed, index)
            end

            updateCopyStatus(total, placed, total - placed, true)
            task.wait(0.12)
        end
    end

    -- สำคัญ: สร้างบล็อกทั้งหมดก่อน แล้วค่อยใช้เครื่องมือปรับแต่ง
    -- เพื่อไม่ให้บล็อกตก/ถูกแก้ทีละบล็อกระหว่างการสร้าง
    task.wait(1.5)

    local created = destinationFolder:GetChildren()
    local edited = 0

    -- ขั้นที่ 2: ปรับขนาด/สี/ความโปร่งใส หลังสร้างครบแล้ว
    for i, v in ipairs(build) do
        local b, dist = getBlock(v, created)

        if b and dist <= 8 then
            rescaleBlock(b, v.Pos, v.Size)
            task.wait(0.04)

            paintBlock(b, v.Color)
            task.wait(0.04)

            if v.Transparency > 0 then
                setTransparency(v.Transparency, b)
                task.wait(0.04)
            end

            edited += 1
        end

        if i % 15 == 0 then
            task.wait(0.12)
        end
    end

    -- ขั้นที่ 3: ห้ามปล่อย Anchor ระหว่าง/หลังการสร้าง
    -- บล็อกทั้งหมดจะคงอยู่กับที่ เพื่อไม่ให้ตกทีละบล็อก
    -- การใช้ไขควง/PropertiesTool จะเกิดเฉพาะในขั้นปรับแต่งด้านบน
    -- หลังจากสร้างครบแล้วเท่านั้น

    local finalMissing = #failed
    updateCopyStatus(total, placed, finalMissing, false)

    local message
    if finalMissing == 0 then
        message = ("เสร็จครบ %d/%d บล็อก | ปรับแต่ง %d/%d"):format(
            placed, total, edited, total
        )
    else
        message = ("วางได้ %d/%d | ขาด %d บล็อก"):format(
            placed, total, finalMissing
        )
        warn("[BABFT] Failed block indexes: " .. table.concat(failed, ", "))
    end

    Rayfield:Notify({
        Title = "คัดลอกสิ่งก่อสร้าง",
        Content = message,
        Duration = 7
    })
end

local autoBuildTab = Window:CreateTab("Building", "rewind")

autoBuildTab:CreateButton({
    Name = "วางบล็อกไม้",
    Callback = function()
        placeBlock("WoodBlock", HRP.CFrame, nil, true)
    end,
})

autoBuildTab:CreateToggle({
    Name = "ปรับขนาดบล็อก (คลิกบล็อก)",
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
    Name = "เลือกผู้เล่น",
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
    Name = "รีเฟรชรายชื่อผู้เล่น",
    Callback = function()
        playerDropdown:Refresh(getPlayers())
    end,
})

autoBuildTab:CreateButton({
    Name = "คัดลอกสิ่งก่อสร้าง",
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
    Title = "คัดลอกสิ่งก่อสร้าง BABFT",
    Content = "โหลดสคริปต์เรียบร้อยแล้ว",
    Duration = 4,
})
