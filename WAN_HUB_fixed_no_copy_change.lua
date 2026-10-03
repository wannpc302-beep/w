-- ============================================================
-- 0. SERVICES & INITIALIZATION
-- ============================================================
local players = game:GetService("Players")
local workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

local player = players.LocalPlayer
local character
local humanoid
local HRP
local viewEnabled = false

local function refreshCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    HRP = character:WaitForChild("HumanoidRootPart")
end

refreshCharacter()

-- COLOR PALETTE CONSTANTS (Milky Blue & Mint Theme)
local COLORS = {
    Main = Color3.fromRGB(184, 242, 230),      -- #B8F2E6
    Mint = Color3.fromRGB(101, 214, 176),      -- #65D6B0
    LightBlue = Color3.fromRGB(142, 216, 232), -- #8ED8E8
    Soft = Color3.fromRGB(217, 245, 242),      -- #D9F5F2
    Working = Color3.fromRGB(245, 215, 122),   -- #F5D77A
    Error = Color3.fromRGB(233, 139, 139),     -- #E98B8B
    Text = Color3.fromRGB(36, 67, 77)          -- #24434D
}


-- ============================================================
-- 1. STATE / LOCK SYSTEM
-- ============================================================
local copyBusy = false
local updateBusy = false
local copySystemEnabled = false
local knownBlocks = {}


local function canStartTask()
    return not copyBusy and not updateBusy
end


-- ============================================================
-- 2. NOTIFICATION SYSTEM (Bottom-Right, Strict Max 3 Cards)
-- ============================================================
local MAX_NOTIFICATIONS = 3
local activeNotifications = {}
local notificationHolder = nil
local notificationCounter = 0

local function createNotificationHolder()
    if notificationHolder and notificationHolder.Parent then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BABFT_NotificationHolder"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player:WaitForChild("PlayerGui")

    notificationHolder = Instance.new("Frame")
    notificationHolder.Name = "Holder"
    notificationHolder.AnchorPoint = Vector2.new(1, 1)
    notificationHolder.Size = UDim2.new(0, 340, 0, 280)
    notificationHolder.Position = UDim2.new(1, -18, 1, -18)
    notificationHolder.BackgroundTransparency = 1
    notificationHolder.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = notificationHolder
end

local function notifyCustom(title, content, duration, icon)
    createNotificationHolder()

    duration = duration or 3
    icon = icon or "ℹ️"

    -- FIFO Queue: ลบกล่องที่เก่าที่สุดทันทีเมื่อเกิน 3 กล่อง
    if #activeNotifications >= MAX_NOTIFICATIONS then
        local oldest = table.remove(activeNotifications, 1)
        if oldest and oldest.Frame and oldest.Frame.Parent then
            task.spawn(function()
                local tweenOut = TweenService:Create(
                    oldest.Frame,
                    TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1, Size = UDim2.new(0, 330, 0, 0) }
                )
                tweenOut:Play()
                tweenOut.Completed:Wait()
                if oldest.Frame then oldest.Frame:Destroy() end
            end)
        end
    end

    notificationCounter += 1

    local card = Instance.new("Frame")
    card.Name = "Notif_" .. tostring(notificationCounter)
    card.Size = UDim2.new(0, 330, 0, 75)
    card.BackgroundColor3 = COLORS.Soft
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.LayoutOrder = notificationCounter

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.Mint
    stroke.Thickness = 1.2
    stroke.Transparency = 0.2
    stroke.Parent = card

    local iconLbl = Instance.new("TextLabel")
    iconLbl.BackgroundTransparency = 1
    iconLbl.Position = UDim2.new(0, 10, 0, 10)
    iconLbl.Size = UDim2.new(0, 35, 0, 35)
    iconLbl.Font = Enum.Font.GothamBold
    iconLbl.TextSize = 22
    iconLbl.Text = icon
    iconLbl.TextColor3 = COLORS.Text
    iconLbl.Parent = card

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Position = UDim2.new(0, 50, 0, 8)
    titleLbl.Size = UDim2.new(1, -60, 0, 22)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title
    titleLbl.TextColor3 = COLORS.Text
    titleLbl.Parent = card

    local contentLbl = Instance.new("TextLabel")
    contentLbl.BackgroundTransparency = 1
    contentLbl.Position = UDim2.new(0, 50, 0, 30)
    contentLbl.Size = UDim2.new(1, -60, 0, 38)
    contentLbl.Font = Enum.Font.Gotham
    contentLbl.TextSize = 12
    contentLbl.TextWrapped = true
    contentLbl.TextXAlignment = Enum.TextXAlignment.Left
    contentLbl.TextYAlignment = Enum.TextYAlignment.Top
    contentLbl.Text = content
    contentLbl.TextColor3 = COLORS.Text
    contentLbl.Parent = card

    card.Parent = notificationHolder

    local notifObj = { Frame = card }
    table.insert(activeNotifications, notifObj)

    -- Tween In
    card.Size = UDim2.new(0, 0, 0, 75)
    local tweenIn = TweenService:Create(
        card,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 330, 0, 75) }
    )
    tweenIn:Play()

    -- Auto Dismiss
    task.delay(duration, function()
        if card and card.Parent then
            for idx, item in ipairs(activeNotifications) do
                if item.Frame == card then
                    table.remove(activeNotifications, idx)
                    break
                end
            end
            local tweenExit = TweenService:Create(
                card,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { BackgroundTransparency = 1, Size = UDim2.new(0, 330, 0, 0) }
            )
            tweenExit:Play()
            tweenExit.Completed:Wait()
            card:Destroy()
        end
    end)
end


-- ============================================================
-- 3. COPY SYSTEM (SOURCE OF TRUTH - UNMODIFIED ORIGINAL LOGIC)
-- ============================================================
local blockData = player:FindFirstChild("Data") or player:WaitForChild("Data", 15)
local blocksFolder = workspace:FindFirstChild("Blocks") or workspace:WaitForChild("Blocks", 15)

if not blockData then
    warn("[BABFT] Data folder was not found; block limits will use defaults.")
end
if not blocksFolder then
    warn("[BABFT] Blocks folder was not found; Copy/Update will be unavailable until it exists.")
end
local ignoreAnchored = true
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
    local value = blockData and blockData:FindFirstChild(name)
    return value and tonumber(value.Value) or 9
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
                tool.SetPropertieRF:InvokeServer(table.unpack(args))
            end)
            if not ok then
                warn("[BABFT] Transparency failed: " .. tostring(err))
                break
            end
            task.wait(0.03)
        end
    end)
end

-- Anchored/Gravity:
-- ถ้าบล็อกเชื่อมกับบล็อกอื่นแล้ว ให้ใช้ไขควงตั้ง Anchored ได้ตั้งแต่ช่วงต้น
-- ถ้าบล็อกยังลอยเดี่ยว/ยังไม่เชื่อม จะเลื่อนไปตั้ง Anchored ในขั้นตอนสุดท้าย
-- เพื่อไม่ให้บล็อกลอยถูกล็อกเร็วเกินไป
local function setAnchored(block)
    if not block then return false end

    local tool = equipTool("PropertiesTool")
    if not tool or not tool:FindFirstChild("SetPropertieRF") then return false end

    local ok, err = pcall(function()
        tool.SetPropertieRF:InvokeServer("Anchored", {block})
    end)
    if not ok then
        warn("[BABFT] Anchored failed: " .. tostring(err))
        return false
    end

    return true
end

-- ตรวจว่าบล็อกนี้ต่อกับ "บล็อกอื่น" ในโฟลเดอร์ปลายทางแล้วหรือยัง
-- ถ้าต่อแล้ว สามารถใช้แรงโน้มถ่วง/Anchored ได้ตั้งแต่ช่วงต้น
-- ถ้ายังลอยเดี่ยว จะถูกเลื่อนไปทำใน final pass เท่านั้น
local function isConnectedToOtherBlock(block, destinationFolder)
    if not block or not destinationFolder then return false end

    local ppart = block:FindFirstChild("PPart")
    if not ppart or not ppart:IsA("BasePart") then return false end

    local ok, connectedParts = pcall(function()
        return ppart:GetConnectedParts(true)
    end)
    if not ok or type(connectedParts) ~= "table" then
        return false
    end

    for _, part in ipairs(connectedParts) do
        if part ~= ppart and part:IsA("BasePart") then
            local otherModel = part:FindFirstAncestorOfClass("Model")
            if otherModel and otherModel ~= block and otherModel.Parent == destinationFolder then
                return true
            end
        end
    end

    return false
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
        tool.RF:InvokeServer(table.unpack(args))
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

local function getBlock(expected, createdList, usedInstances)
    local best = nil
    local bestDist = math.huge

    for _, b in ipairs(createdList) do
        if b and not (usedInstances and usedInstances[b]) and b:IsA("Model") and b.Name == expected.Name then
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
    local folder = blocksFolder or workspace:FindFirstChild("Blocks")
    return folder and folder:FindFirstChild(p.Name) or nil
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
        if attempt > 1 then
            task.wait(0.15 * attempt)
        end

        -- ห้ามตั้ง Anchored ตอนวาง เพราะบล็อกที่ยังลอยต้องรอขั้นตอนสุดท้าย
        placeBlock(expected.Name, expected.Pos, expected.Relative, false)

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

-- Helper key generator using Name + Position + Size for precise deduplication
local function makeBlockKey(name, posCFrame, sizeVector)
    if not posCFrame or not sizeVector then return nil end
    local p = posCFrame.Position
    return string.format(
        "%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f",
        tostring(name),
        p.X, p.Y, p.Z,
        sizeVector.X, sizeVector.Y, sizeVector.Z
    )
end

-- Copy Status Window UI
local copyStatus = {
    total = 0,
    placed = 0,
    missing = 0,
    percent = 0,
    running = false
}

local statusFrame, statusTitle, statusText, progressFill

local function createCopyStatusUI()
    if statusFrame and statusFrame.Parent then return end

    statusFrame = Instance.new("Frame")
    statusFrame.Name = "CopyBuildStatus"
    statusFrame.Size = UDim2.new(0, 310, 0, 145)
    statusFrame.Position = UDim2.new(0.5, -155, 0, 80)
    statusFrame.BackgroundTransparency = 0.08
    statusFrame.BackgroundColor3 = COLORS.LightBlue
    statusFrame.Parent = player:WaitForChild("PlayerGui")

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
    statusTitle.TextColor3 = COLORS.Text
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.Parent = statusFrame

    statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -20, 0, 55)
    statusText.Position = UDim2.new(0, 10, 0, 40)
    statusText.BackgroundTransparency = 1
    statusText.Text = "พร้อมใช้งาน"
    statusText.TextSize = 14
    statusText.Font = Enum.Font.Gotham
    statusText.TextColor3 = COLORS.Text
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.TextYAlignment = Enum.TextYAlignment.Top
    statusText.Parent = statusFrame

    local bar = Instance.new("Frame")
    bar.Name = "ProgressBar"
    bar.Size = UDim2.new(1, -20, 0, 14)
    bar.Position = UDim2.new(0, 10, 1, -25)
    bar.BackgroundTransparency = 0.35
    bar.BackgroundColor3 = COLORS.Soft
    bar.Parent = statusFrame

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 7)
    barCorner.Parent = bar

    progressFill = Instance.new("Frame")
    progressFill.Name = "Fill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = COLORS.Mint
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

    statusText.Text = ("ทั้งหมด: %d | วางแล้ว: %d | ขาด: %d\nความคืบหน้า: %d%%"):format(
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
    if not copySystemEnabled then
        notifyCustom("ระบบ Copy", "⛔ ระบบ Copy ถูกปิดอยู่ กรุณาเปิดสวิตช์ก่อน", 3, "⛔")
        return
    end

    if not canStartTask() then
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ มีงาน Copy/Update กำลังทำงานอยู่", 3, "⚠️")
        return
    end

    if not targetPlayer or not targetPlayer.Parent then
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ กรุณาเลือกผู้เล่นก่อน", 3, "⚠️")
        return
    end

    local sourceFolder = getSourceFolder(targetPlayer)
    if not sourceFolder then
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ ไม่พบบล็อกของผู้เล่นนี้", 4, "⚠️")
        return
    end

    copyBusy = true

    local ok, err = pcall(function()
        local build = copyBuild(sourceFolder)
        if #build == 0 then
            notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ ไม่พบบล็อกที่สามารถคัดลอกได้", 4, "⚠️")
            return
        end

        local currentBlocksFolder = blocksFolder or workspace:FindFirstChild("Blocks")
        local destinationFolder = currentBlocksFolder and currentBlocksFolder:FindFirstChild(player.Name)
        if not destinationFolder then
            notifyCustom("คัดลอกสิ่งก่อสร้าง", "⚠️ ไม่พบโฟลเดอร์สิ่งก่อสร้างของเรา", 4, "⚠️")
            return
        end

        table.clear(knownBlocks)

        local total = #build
        local placed = 0
        local failed = {}
        local earlyAnchored = {}

        updateCopyStatus(total, 0, total, true)
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "🔍 กำลังอ่านและวาง " .. total .. " บล็อก...", 4, "🏗️")

        for i, expected in ipairs(build) do
            local b = placeAndVerify(expected, destinationFolder)

            if b then
                placed += 1

                -- ถ้าต่อกับบล็อกอื่นแล้ว ให้ตั้ง Anchored ได้ตั้งแต่ช่วงต้น
                -- ถ้ายังลอยเดี่ยว จะรอ final pass ด้านล่าง
                if expected.Anchored and isConnectedToOtherBlock(b, destinationFolder) then
                    if setAnchored(b) then
                        earlyAnchored[b] = true
                    end
                    task.wait(0.03)
                end

                local key = makeBlockKey(expected.Name, expected.Pos, expected.Size)
                if key then knownBlocks[key] = true end
            else
                table.insert(failed, i)
            end

            updateCopyStatus(total, placed, total - placed, true)

            if i % 10 == 0 or i == total then
                notifyCustom("คัดลอกสิ่งก่อสร้าง", ("🏗️ วางแล้ว %d/%d | ขาด %d"):format(
                    placed, total, #failed
                ), 2, "📊")
            end
        end

        -- Retry Phase for Failed Blocks
        if #failed > 0 then
            local retry = failed
            failed = {}
            task.wait(0.8)

            for _, index in ipairs(retry) do
                local b = placeAndVerify(build[index], destinationFolder)
                if b then
                    placed += 1

                    if build[index].Anchored and isConnectedToOtherBlock(b, destinationFolder) then
                        if setAnchored(b) then
                            earlyAnchored[b] = true
                        end
                        task.wait(0.03)
                    end

                    local key = makeBlockKey(build[index].Name, build[index].Pos, build[index].Size)
                    if key then knownBlocks[key] = true end
                else
                    table.insert(failed, index)
                end
                updateCopyStatus(total, placed, total - placed, true)
                task.wait(0.1)
            end
        end

        -- Scaling, Painting & Properties Customization
        task.wait(0.4)
        local created = destinationFolder:GetChildren()
        local edited = 0
        local usedCreatedBlocks = {}

        for i, v in ipairs(build) do
            local b, dist = getBlock(v, created, usedCreatedBlocks)

            if b and dist <= 8 then
                usedCreatedBlocks[b] = true
                rescaleBlock(b, v.Pos, v.Size)
                task.wait(0.03)

                paintBlock(b, v.Color)
                task.wait(0.03)

                if v.Transparency > 0 then
                    setTransparency(v.Transparency, b)
                    task.wait(0.03)
                end

                -- Anchored จะถูกตั้งในขั้นตอนสุดท้าย หลังปรับแต่งทุกอย่างครบแล้ว

                edited += 1
            end

            if i % 15 == 0 then
                task.wait(0.1)
            end
        end

        -- ขั้นตอนสุดท้าย: ใช้ไขควงเฉพาะบล็อกที่ยังไม่ได้ Anchored ตั้งแต่ต้น
        -- ซึ่งส่วนใหญ่คือบล็อกที่ตอนวางยังลอย/ยังไม่เชื่อมกับบล็อกอื่น
        task.wait(0.15)
        local finalCreated = destinationFolder:GetChildren()
        local usedFinalBlocks = {}
        for _, v in ipairs(build) do
            if v.Anchored then
                local b, dist = getBlock(v, finalCreated, usedFinalBlocks)
                if b and dist <= 8 then
                    usedFinalBlocks[b] = true
                    if not earlyAnchored[b] then
                        setAnchored(b)
                        task.wait(0.03)
                    end
                end
            end
        end

        local finalMissing = #failed
        updateCopyStatus(total, placed, finalMissing, false)

        local msg = finalMissing == 0 
            and ("✅ เสร็จสมบูรณ์ %d/%d บล็อก (ปรับแต่ง %d)"):format(placed, total, edited)
            or ("⚠️ วางสำเร็จ %d/%d | ขาด %d บล็อก"):format(placed, total, finalMissing)

        notifyCustom("คัดลอกสิ่งก่อสร้าง", msg, 5, "✅")
    end)

    copyBusy = false

    if not ok then
        warn("[BABFT Copy Error]", err)
        notifyCustom("คัดลอกสิ่งก่อสร้าง", "❌ เกิดข้อผิดพลาดขณะคัดลอก", 4, "❌")
    end
end


-- ============================================================
-- 4. UPDATE SYSTEM (Name + Position + Size Deduplication)
-- ============================================================
local function runUpdateBuild()
    if not copySystemEnabled then
        notifyCustom("ระบบ Copy", "⛔ ระบบ Copy/Update ถูกปิดอยู่ กรุณาเปิดสวิตช์ก่อน", 3, "⛔")
        return
    end

    if not canStartTask() then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ มีงาน Copy/Update กำลังทำงานอยู่", 3, "⚠️")
        return
    end

    if not selectedPlayer or not selectedPlayer.Parent then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ ไม่สามารถอ่านสิ่งก่อสร้างล่าสุดได้ เพราะผู้เล่นออกจากเกมแล้ว", 4, "⚠️")
        return
    end

    if next(knownBlocks) == nil then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ กรุณาก็อปปี้สิ่งก่อสร้างก่อน จึงจะใช้อัปเดตได้", 4, "⚠️")
        return
    end

    local sourceFolder = getSourceFolder(selectedPlayer)
    if not sourceFolder then
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ ไม่พบบล็อกของผู้เล่นนี้ในเซิร์ฟเวอร์", 4, "⚠️")
        return
    end

    updateBusy = true

    local success, err = pcall(function()
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "🔍 กำลังตรวจหาบล็อกใหม่...", 2, "🔍")

        local build = copyBuild(sourceFolder)
        if #build == 0 then
            notifyCustom("อัปเดตสิ่งก่อสร้าง", "ℹ️ ไม่พบบล็อกใหม่", 3, "ℹ️")
            return
        end

        local currentBlocksFolder = blocksFolder or workspace:FindFirstChild("Blocks")
        local destinationFolder = currentBlocksFolder and currentBlocksFolder:FindFirstChild(player.Name)
        if not destinationFolder then
            notifyCustom("อัปเดตสิ่งก่อสร้าง", "⚠️ ไม่พบโฟลเดอร์สิ่งก่อสร้างของเรา", 4, "⚠️")
            return
        end

        local newBlocksToPlace = {}
        for _, b in ipairs(build) do
            local key = makeBlockKey(b.Name, b.Pos, b.Size)
            if key and not knownBlocks[key] then
                table.insert(newBlocksToPlace, { data = b, key = key })
            end
        end

        if #newBlocksToPlace == 0 then
            notifyCustom("อัปเดตสิ่งก่อสร้าง", "ℹ️ ไม่พบบล็อกใหม่", 3, "ℹ️")
            return
        end

        notifyCustom("อัปเดตสิ่งก่อสร้าง", ("🏗️ พบบล็อกใหม่ %d บล็อก กำลังสร้าง..."):format(#newBlocksToPlace), 3, "🏗️")

        local placedCount = 0
        local newlyPlacedInstances = {}

        local earlyAnchoredUpdate = {}

        for _, item in ipairs(newBlocksToPlace) do
            local b = placeAndVerify(item.data, destinationFolder)
            if b then
                -- ถ้าบล็อกใหม่เชื่อมกับบล็อกอื่นแล้ว ให้ใช้แรงโน้มถ่วงได้ทันที
                if item.data.Anchored and isConnectedToOtherBlock(b, destinationFolder) then
                    if setAnchored(b) then
                        earlyAnchoredUpdate[b] = true
                    end
                    task.wait(0.03)
                end

                -- เพิ่มเข้า knownBlocks เมื่อวางสำเร็จจริงเท่านั้น
                knownBlocks[item.key] = true
                placedCount += 1
                table.insert(newlyPlacedInstances, { instance = b, data = item.data })
            end
            task.wait(0.04)
        end

        -- Customize newly created blocks (ยังไม่ตั้ง Anchored)
        for _, item in ipairs(newlyPlacedInstances) do
            rescaleBlock(item.instance, item.data.Pos, item.data.Size)
            paintBlock(item.instance, item.data.Color)
            if item.data.Transparency > 0 then
                setTransparency(item.data.Transparency, item.instance)
            end
        end

        -- ขั้นตอนสุดท้าย: ใช้ไขควงตั้ง Anchored/แรงโน้มถ่วง
        -- ทำหลังจากบล็อกใหม่ทุกก้อนถูกวางและปรับแต่งเสร็จแล้ว
        task.wait(0.15)
        for _, item in ipairs(newlyPlacedInstances) do
            if item.data.Anchored and not earlyAnchoredUpdate[item.instance] then
                setAnchored(item.instance)
                task.wait(0.03)
            end
        end

        notifyCustom("อัปเดตสิ่งก่อสร้าง", ("✅ อัปเดตสำเร็จ %d/%d บล็อก"):format(placedCount, #newBlocksToPlace), 4, "✅")
    end)

    updateBusy = false

    if not success then
        warn("[BABFT Update Error]", err)
        notifyCustom("อัปเดตสิ่งก่อสร้าง", "❌ Update เกิดข้อผิดพลาด", 4, "❌")
    end
end


-- ============================================================
-- 5. FARM SYSTEM
-- ============================================================
local farmRunning = false
local farmThread = nil
local farmSpeed = 80
local farmMode = "วาร์ป"

-- พิกัดจากข้อมูลที่ให้ไว้ก่อนหน้า; ปรับได้จากตัวแปรนี้ภายหลัง
local STAGE_WAYPOINTS = {
    Vector3.new(-80, 50, 610),
    Vector3.new(-81.7, 50, 1369),
    Vector3.new(-95.9, 50, 2137),
    Vector3.new(-85.2, 50, 2908),
    Vector3.new(-82.0, 50, 3680),
    Vector3.new(-81.7, 50, 4450),
    Vector3.new(-58.0, 50, 5221),
    Vector3.new(-75.8, 50, 5985),
    Vector3.new(-64.1, 50, 6761),
    Vector3.new(-88.4, 50, 7517),
    Vector3.new(-33.3, 50, 8300),
}
local CHEST_POS = Vector3.new(0, -360, 9490)

local function setCharacterCollision(enabled)
    if not character or not character.Parent then return end
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = enabled
        end
    end
end

local function moveToPosition(position, speed)
    if not HRP or not HRP.Parent then
        refreshCharacter()
    end
    if not HRP then return false end

    local start = HRP.Position
    local distance = (position - start).Magnitude
    local duration = math.max(0.08, distance / math.max(1, speed))
    local started = os.clock()

    while farmRunning and HRP and HRP.Parent do
        local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
        HRP.CFrame = CFrame.new(start:Lerp(position, alpha))
        if alpha >= 1 then
            return true
        end
        RunService.Heartbeat:Wait()
    end

    return false
end

local function startFarm()
    if farmRunning then return end

    if not HRP or not HRP.Parent then
        refreshCharacter()
    end
    if not HRP then
        notifyCustom("ฟังก์ชันฟาร์ม", "⚠️ ไม่พบตัวละคร", 3, "⚠️")
        return
    end

    farmRunning = true
    notifyCustom("ฟังก์ชันฟาร์ม", "🪙 เริ่มเดินทางผ่านด่าน", 3, "🪙")

    farmThread = task.spawn(function()
        while farmRunning do
            refreshCharacter()

            -- Farm ใช้การเคลื่อนที่แบบไม่ชน เพื่อไม่ให้ตัวละครติดสิ่งกีดขวาง
            for _, waypoint in ipairs(STAGE_WAYPOINTS) do
                if not farmRunning then break end
                setCharacterCollision(false)
                if farmMode == "วาร์ป" then
                    if HRP and HRP.Parent then
                        HRP.CFrame = CFrame.new(waypoint)
                    end
                else
                    moveToPosition(waypoint, farmSpeed)
                end
                task.wait(0.08)
            end

            if farmRunning then
                setCharacterCollision(false)
                if farmMode == "วาร์ป" then
                    if HRP and HRP.Parent then
                        HRP.CFrame = CFrame.new(CHEST_POS)
                    end
                else
                    moveToPosition(CHEST_POS, farmSpeed)
                end
                task.wait(2)
            end

            if farmRunning then
                notifyCustom("ฟังก์ชันฟาร์ม", "🔁 จบรอบแล้ว กำลังเริ่มรอบใหม่", 2, "🔁")
            end
        end
    end)
end

local function stopFarm()
    local wasRunning = farmRunning
    farmRunning = false

    if farmThread then
        task.cancel(farmThread)
        farmThread = nil
    end

    if wasRunning then
        notifyCustom("ฟังก์ชันฟาร์ม", "⏹️ หยุดการฟาร์มแล้ว", 3, "⏹️")
    end
end


-- ============================================================
-- 6. AFK SYSTEM
-- ============================================================
local afkEnabled = false
local afkConnection = nil

local function startAFK()
    if afkEnabled then return end

    afkEnabled = true
    afkConnection = player.Idled:Connect(function()
        if not afkEnabled then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)

    notifyCustom("ฟังก์ชัน AFK", "💤 เปิดระบบป้องกัน AFK", 3, "💤")
end

local function stopAFK()
    if not afkEnabled and not afkConnection then return end

    afkEnabled = false
    if afkConnection then
        afkConnection:Disconnect()
        afkConnection = nil
    end

    notifyCustom("ฟังก์ชัน AFK", "⏹️ ปิดระบบ AFK", 3, "⏹️")
end


-- ============================================================
-- 7. NOCLIP SYSTEM — เก็บและคืนค่า CanCollide เดิม
-- ============================================================
local noclipEnabled = false
local originalCanCollide = {}

local function rememberCollisionState()
    if not character then return end

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") and originalCanCollide[obj] == nil then
            originalCanCollide[obj] = obj.CanCollide
        end
    end
end

local function applyNoclip()
    if not character then return end

    rememberCollisionState()

    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.CanCollide = false
        end
    end
end

local function restoreCollision()
    for part, oldValue in pairs(originalCanCollide) do
        if part and part.Parent then
            part.CanCollide = oldValue
        end
    end
    table.clear(originalCanCollide)
end

local function setNoclip(enabled)
    noclipEnabled = enabled == true

    if noclipEnabled then
        applyNoclip()
        notifyCustom("Noclip", "👻 เปิดทะลุแล้ว", 2, "👻")
    else
        restoreCollision()
        notifyCustom("Noclip", "↩️ ปิดทะลุและคืนค่าเดิมแล้ว", 2, "↩️")
    end
end

local noclipConnection = RunService.Stepped:Connect(function()
    if noclipEnabled then
        applyNoclip()
    end
end)


-- ============================================================
-- 8. TRAVEL SYSTEM
-- ============================================================
local travelRunning = false
local travelThread = nil
local selectedBaseColor = "White"
local selectedBaseType = "เปิดเผย"
local travelMode = "วาร์ป"
local travelSpeed = 80

-- พิกัดฐานอ้างอิงจากตำแหน่ง Team Zone ของแมพ
-- White ใช้เป็นจุดกึ่งกลาง/จุดอ้างอิงหลัก
local WHITE_BASE_POSITION = Vector3.new(-53.5637512, -9.89999294, -345.507538)

-- ตำแหน่งจริงของฐานแต่ละสีที่สัมพันธ์กับ White
-- Purple ใน UI ใช้ตำแหน่ง Magenta ของเกม
local BASE_POSITIONS = {
    White = WHITE_BASE_POSITION,
    Red = Vector3.new(221.835068, -9.89999294, -68.7047195),
    Purple = Vector3.new(221.835083, -9.89999294, 647.695251),
    Green = Vector3.new(-328.966553, -9.89999294, 285.890778),
    Blue = Vector3.new(221.835587, -9.89999294, 289.496735),
    Yellow = Vector3.new(-328.942108, -9.89999294, 643.876709),
    Black = Vector3.new(-328.943665, -9.89999294, -72.1218643),
}

local function getTravelCFrame()
    local position = BASE_POSITIONS[selectedBaseColor]
    if not position then return nil end

    -- ประเภทจุดหมายใช้เป็น offset ความสูงเท่านั้น
    local yOffset = selectedBaseType == "ไม่เปิดเผย" and 75 or 5
    local target = position + Vector3.new(0, yOffset, 0)
    return CFrame.new(target)
end

local function startTravel()
    if travelRunning then return end

    local destination = getTravelCFrame()
    if not destination then
        notifyCustom("การเดินทาง", "⚠️ ไม่พบจุดหมาย", 3, "⚠️")
        return
    end

    if not HRP or not HRP.Parent then
        refreshCharacter()
    end
    if not HRP then return end

    if travelMode == "วาร์ป" then
        HRP.CFrame = destination
        notifyCustom(
            "การเดินทาง",
            "✅ ไปฐาน " .. selectedBaseColor .. " (" .. selectedBaseType .. ") แล้ว",
            3,
            "🚤"
        )
        return
    end

    travelRunning = true
    notifyCustom("การเดินทาง", "🚤 กำลังบินไป " .. selectedBaseColor, 3, "🚤")

    travelThread = task.spawn(function()
        local start = HRP.Position
        local goal = destination.Position
        local distance = (goal - start).Magnitude
        local duration = math.max(0.1, distance / math.max(1, travelSpeed))
        local began = os.clock()

        while travelRunning and HRP and HRP.Parent do
            local alpha = math.clamp((os.clock() - began) / duration, 0, 1)
            HRP.CFrame = CFrame.new(start:Lerp(goal, alpha))

            if alpha >= 1 then break end
            RunService.Heartbeat:Wait()
        end

        if travelRunning and HRP and HRP.Parent then
            HRP.CFrame = destination
            notifyCustom("การเดินทาง", "✅ ถึงฐาน " .. selectedBaseColor .. " แล้ว", 3, "✅")
        end

        travelRunning = false
        travelThread = nil
    end)
end

local function stopTravel()
    if not travelRunning and not travelThread then return end

    travelRunning = false
    if travelThread then
        task.cancel(travelThread)
        travelThread = nil
    end

    notifyCustom("การเดินทาง", "⏹️ หยุดการเดินทางแล้ว", 3, "⏹️")
end


-- ============================================================
-- 9. VIEW SYSTEM
-- ============================================================
local viewSelectedPlayer = nil
local viewDropdown = nil

local function restoreOwnCamera()
    local camera = workspace.CurrentCamera
    local ownCharacter = player.Character
    local ownHumanoid = ownCharacter and ownCharacter:FindFirstChildOfClass("Humanoid")

    if camera and ownHumanoid then
        camera.CameraSubject = ownHumanoid
    end
end

local function refreshViewTarget()
    if not viewEnabled then return end

    local camera = workspace.CurrentCamera
    local targetCharacter = viewSelectedPlayer and viewSelectedPlayer.Character
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")

    if camera and targetHumanoid and targetHumanoid.Health > 0 then
        camera.CameraSubject = targetHumanoid
    else
        viewEnabled = false
        restoreOwnCamera()
        notifyCustom("View", "⚠️ เป้าหมายไม่มีตัวละครที่ใช้งานได้", 3, "⚠️")
    end
end

local function setViewEnabled(enabled)
    if not enabled then
        viewEnabled = false
        restoreOwnCamera()
        notifyCustom("View", "⏹️ ปิดการดูผู้เล่นแล้ว", 3, "⏹️")
        return
    end

    if not viewSelectedPlayer or not viewSelectedPlayer.Parent then
        viewEnabled = false
        notifyCustom("View", "⚠️ กรุณาเลือกผู้เล่นก่อน", 3, "⚠️")
        return
    end

    viewEnabled = true
    refreshViewTarget()

    if viewEnabled then
        notifyCustom("View", "👁️ กำลังดู " .. viewSelectedPlayer.DisplayName, 3, "👁️")
    end
end


-- ============================================================
-- 10. SETTINGS / UI HELPERS
-- ============================================================
local uiScaleValue = 100
local uiScaleObjects = {}

local function findRayfieldScaleTargets()
    local targets = {}
    local seen = {}

    local function scan(root)
        if not root then return end
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ScreenGui") then
                local name = string.lower(obj.Name)
                if string.find(name, "rayfield", 1, true) then
                    if not seen[obj] then
                        seen[obj] = true
                        table.insert(targets, obj)
                    end
                end
            end
        end
    end

    local okCore, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if okCore then scan(coreGui) end

    local okPlayer, playerGui = pcall(function()
        return players.LocalPlayer and players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)
    if okPlayer then scan(playerGui) end

    return targets
end

local function setUIScalePercent(value)
    uiScaleValue = math.clamp(math.floor(tonumber(value) or 100), 75, 125)
    local scale = uiScaleValue / 100

    -- Rayfield ไม่มี API Scale สาธารณะ จึงใช้ UIScale ที่ ScreenGui ของ Rayfield โดยตรง
    local targets = findRayfieldScaleTargets()
    uiScaleObjects = {}

    for _, screenGui in ipairs(targets) do
        local scaleObject = screenGui:FindFirstChild("WANHubUIScale")
        if not scaleObject then
            scaleObject = Instance.new("UIScale")
            scaleObject.Name = "WANHubUIScale"
            scaleObject.Parent = screenGui
        end
        scaleObject.Scale = scale
        table.insert(uiScaleObjects, scaleObject)
    end

    notifyCustom(
        "Settings",
        ("UI Scale %d%% (%s)"):format(uiScaleValue, #targets > 0 and "ใช้งานแล้ว" or "กำลังรอ Rayfield UI"),
        2,
        "⚙️"
    )
end


-- ============================================================
-- 11. CHARACTER / CLEANUP
-- ============================================================
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid", 10)
    HRP = newCharacter:WaitForChild("HumanoidRootPart", 10)

    -- ตัวละครใหม่ไม่ควรนำค่า collision ของตัวเก่ามาคืน
    table.clear(originalCanCollide)

    if noclipEnabled then
        task.wait(0.1)
        applyNoclip()
    end

    if not viewEnabled and humanoid then
        local camera = workspace.CurrentCamera
        if camera then
            camera.CameraSubject = humanoid
        end
    end
end)


-- ============================================================
-- 12. UI SYSTEM
-- ============================================================
local Rayfield
do
    local ok, result = pcall(function()
        if type(loadstring) ~= "function" then
            error("loadstring is not available in this executor")
        end
        local source = game:HttpGet("https://sirius.menu/rayfield")
        if type(source) ~= "string" or source == "" then
            error("Rayfield source could not be downloaded")
        end
        local chunk, compileErr = loadstring(source)
        if not chunk then
            error(compileErr or "Rayfield source failed to compile")
        end
        return chunk()
    end)

    if not ok or type(result) ~= "table" then
        warn("[WAN HUB] Rayfield failed to load: " .. tostring(result))
        notifyCustom("WAN HUB", "❌ โหลด Rayfield ไม่สำเร็จ กรุณาใช้ executor ที่รองรับ loadstring + HttpGet", 8, "❌")
        error("[WAN HUB] Rayfield failed to load: " .. tostring(result))
    end

    Rayfield = result
end

local Window = Rayfield:CreateWindow({
    Name = "WAN HUB — Build A Boat",
    Icon = 0,
    LoadingTitle = "WAN HUB",
    LoadingSubtitle = "Copy & Management System",
    Theme = "Ocean",
    ToggleUIKeybind = "G",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BABFT",
        FileName = "BuildABoatConfig"
    },
})

-- Rayfield อาจสร้าง ScreenGui หลัง CreateWindow เล็กน้อย จึงลองผูก UIScale อีกครั้ง
setUIScalePercent(uiScaleValue)
task.delay(0.5, function()
    if Window then
        setUIScalePercent(uiScaleValue)
    end
end)

-- COPY TAB: ใช้ฟังก์ชัน Copy/Update เดิมด้านบนโดยไม่แก้ logic
local copyTab = Window:CreateTab("📋 Copy", "rewind")

copyTab:CreateToggle({
    Name = "📋 เปิด/ปิด ระบบ Copy/Update",
    CurrentValue = false,
    Callback = function(value)
        copySystemEnabled = value == true
        if copySystemEnabled then
            notifyCustom("ระบบ Copy", "✅ เปิดใช้งาน Copy/Update แล้ว", 3, "✅")
        else
            notifyCustom("ระบบ Copy", "⛔ ปิดใช้งาน Copy/Update แล้ว", 3, "⛔")
        end
    end,
})

local playerDropdown = copyTab:CreateDropdown({
    Name = "👤 เลือกผู้เล่น",
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

copyTab:CreateButton({
    Name = "🔄 รีเฟรชรายชื่อผู้เล่น",
    Callback = function()
        playerDropdown:Refresh(getPlayers())
        notifyCustom("ผู้เล่น", "🔄 อัปเดตรายชื่อแล้ว", 2, "🔄")
    end,
})

copyTab:CreateButton({
    Name = "📋 ก็อปปี้สิ่งก่อสร้าง",
    Callback = function()
        runCopyBuild(selectedPlayer)
    end,
})

copyTab:CreateButton({
    Name = "➖ อัปเดตสิ่งก่อสร้าง",
    Callback = function()
        runUpdateBuild()
    end,
})

copyTab:CreateButton({
    Name = "📊 สถานะสิ่งก่อสร้าง",
    Callback = function()
        -- ใช้จำนวน key จริงแทน #knownBlocks เฉพาะส่วนแสดงผล
        local count = 0
        for _ in pairs(knownBlocks) do
            count += 1
        end

        notifyCustom(
            "สถานะสิ่งก่อสร้าง",
            ("วางสำเร็จ: %d | บล็อกที่บันทึก: %d"):format(copyStatus.placed, count),
            4,
            "📊"
        )
    end,
})


-- FARM TAB
local farmTab = Window:CreateTab("🪙 Farm", "dollar-sign")

farmTab:CreateToggle({
    Name = "🪙 เปิด/ปิด Auto Farm",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startFarm()
        else
            stopFarm()
        end
    end,
})

farmTab:CreateDropdown({
    Name = "🧭 วิธีฟาร์ม",
    Options = {"วาร์ป", "บิน"},
    CurrentOption = {"วาร์ป"},
    MultipleOptions = false,
    Callback = function(option)
        farmMode = type(option) == "table" and option[1] or option
    end,
})

farmTab:CreateSlider({
    Name = "🚀 ความเร็ว Farm",
    Range = {1, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = 80,
    Callback = function(value)
        farmSpeed = math.clamp(tonumber(value) or 80, 1, 200)
    end,
})

farmTab:CreateButton({
    Name = "⏹️ หยุด Farm",
    Callback = function()
        stopFarm()
    end,
})

farmTab:CreateButton({
    Name = "📊 สถานะ Farm",
    Callback = function()
        notifyCustom(
            "สถานะ Farm",
            farmRunning and "🟢 กำลังทำงาน" or "🔴 หยุดอยู่",
            3,
            "📊"
        )
    end,
})


-- TRAVEL TAB
local travelTab = Window:CreateTab("🚤 Travel", "compass")

travelTab:CreateDropdown({
    Name = "🎨 เลือกสีฐาน",
    Options = {"White", "Red", "Purple", "Green", "Blue", "Yellow", "Black"},
    CurrentOption = {"White"},
    MultipleOptions = false,
    Callback = function(option)
        selectedBaseColor = type(option) == "table" and option[1] or option
    end,
})

travelTab:CreateDropdown({
    Name = "📍 ประเภทจุดหมาย",
    Options = {"เปิดเผย", "ไม่เปิดเผย"},
    CurrentOption = {"เปิดเผย"},
    MultipleOptions = false,
    Callback = function(option)
        selectedBaseType = type(option) == "table" and option[1] or option
    end,
})

travelTab:CreateDropdown({
    Name = "🧭 วิธีเดินทาง",
    Options = {"วาร์ป", "บิน"},
    CurrentOption = {"วาร์ป"},
    MultipleOptions = false,
    Callback = function(option)
        travelMode = type(option) == "table" and option[1] or option
    end,
})

travelTab:CreateSlider({
    Name = "🚀 ความเร็วบิน",
    Range = {1, 200},
    Increment = 1,
    Suffix = "",
    CurrentValue = 80,
    Callback = function(value)
        travelSpeed = math.clamp(tonumber(value) or 80, 1, 200)
    end,
})

travelTab:CreateButton({
    Name = "🚤 เริ่มเดินทาง",
    Callback = function()
        startTravel()
    end,
})

travelTab:CreateButton({
    Name = "⏹️ หยุดเดินทาง",
    Callback = function()
        stopTravel()
    end,
})

travelTab:CreateButton({
    Name = "📍 ตรวจสอบจุดหมาย",
    Callback = function()
        local destination = getTravelCFrame()
        if destination then
            notifyCustom(
                "Travel",
                ("📍 %s / %s\nX %.0f  Y %.0f  Z %.0f"):format(
                    selectedBaseColor,
                    selectedBaseType,
                    destination.Position.X,
                    destination.Position.Y,
                    destination.Position.Z
                ),
                4,
                "📍"
            )
        end
    end,
})


-- VIEW TAB
local viewTab = Window:CreateTab("👁️ View", "eye")

viewDropdown = viewTab:CreateDropdown({
    Name = "👤 เลือกผู้เล่น",
    Options = getPlayers(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(option)
        local displayName = type(option) == "table" and option[1] or option
        if type(displayName) == "string" then
            local realName = getRealName(displayName)
            viewSelectedPlayer = realName and players:FindFirstChild(realName) or nil
            if viewEnabled then
                refreshViewTarget()
            end
        end
    end,
})

viewTab:CreateButton({
    Name = "🔄 รีเฟรชรายชื่อผู้เล่น",
    Callback = function()
        viewDropdown:Refresh(getPlayers())
        notifyCustom("View", "🔄 อัปเดตรายชื่อแล้ว", 2, "🔄")
    end,
})

viewTab:CreateToggle({
    Name = "👁️ เปิด/ปิด View",
    CurrentValue = false,
    Callback = function(value)
        setViewEnabled(value)
    end,
})


-- AFK TAB
local afkTab = Window:CreateTab("💤 AFK", "moon")

afkTab:CreateToggle({
    Name = "💤 เปิด/ปิด Anti-AFK",
    CurrentValue = false,
    Callback = function(value)
        if value then
            startAFK()
        else
            stopAFK()
        end
    end,
})

afkTab:CreateButton({
    Name = "⏹️ หยุด AFK",
    Callback = function()
        stopAFK()
    end,
})


-- NOCLIP TAB
local noclipTab = Window:CreateTab("👻 Noclip", "ghost")

noclipTab:CreateToggle({
    Name = "👻 เปิด/ปิด Noclip",
    CurrentValue = false,
    Callback = function(value)
        setNoclip(value)
    end,
})

noclipTab:CreateButton({
    Name = "↩️ คืนค่า Collision เดิม",
    Callback = function()
        noclipEnabled = false
        restoreCollision()
        notifyCustom("Noclip", "↩️ คืนค่า CanCollide เดิมแล้ว", 3, "↩️")
    end,
})


-- SETTINGS TAB
local settingsTab = Window:CreateTab("⚙️ Settings", "settings")

settingsTab:CreateSlider({
    Name = "📐 UI Scale",
    Range = {75, 125},
    Increment = 5,
    Suffix = "%",
    CurrentValue = 100,
    Callback = function(value)
        setUIScalePercent(value)
    end,
})

settingsTab:CreateButton({
    Name = "↩️ Reset UI Scale",
    Callback = function()
        setUIScalePercent(100)
    end,
})

settingsTab:CreateButton({
    Name = "🔄 รีเซ็ตการทำงาน",
    Callback = function()
        stopFarm()
        stopTravel()
        stopAFK()
        if noclipEnabled then
            setNoclip(false)
        else
            restoreCollision()
        end
        if viewEnabled then
            setViewEnabled(false)
        end
        notifyCustom("Settings", "↩️ รีเซ็ตสถานะระบบแล้ว", 3, "🔄")
    end,
})


-- ============================================================
-- 13. PLAYER LISTENERS
-- ============================================================

local function refreshPlayerLists()
    pcall(function()
        if playerDropdown then
            playerDropdown:Refresh(getPlayers())
        end
        if viewDropdown then
            viewDropdown:Refresh(getPlayers())
        end
    end)
end

players.PlayerAdded:Connect(function(joinedPlayer)
    joinedPlayer.CharacterAdded:Connect(function()
        task.wait(0.15)
        if viewEnabled and viewSelectedPlayer == joinedPlayer then
            refreshViewTarget()
        end
    end)

    task.wait(0.5)
    refreshPlayerLists()
end)

for _, existingPlayer in ipairs(players:GetPlayers()) do
    if existingPlayer ~= player then
        existingPlayer.CharacterAdded:Connect(function()
            task.wait(0.15)
            if viewEnabled and viewSelectedPlayer == existingPlayer then
                refreshViewTarget()
            end
        end)
    end
end

players.PlayerRemoving:Connect(function(leavingPlayer)
    if selectedPlayer == leavingPlayer then
        selectedPlayer = nil
        notifyCustom("ระบบผู้เล่น", "⚠️ ผู้เล่นต้นทางออกจากเกมแล้ว", 3, "⚠️")
    end

    if viewSelectedPlayer == leavingPlayer then
        viewSelectedPlayer = nil
        if viewEnabled then
            setViewEnabled(false)
        end
    end

    task.delay(0.2, refreshPlayerLists)
end)


-- ============================================================
-- 14. FINAL STATUS
-- ============================================================
notifyCustom(
    "WAN HUB",
    "✅ โหลดระบบเรียบร้อย | Copy/Update เดิมถูกเก็บไว้",
    4,
    "🚀"
)
