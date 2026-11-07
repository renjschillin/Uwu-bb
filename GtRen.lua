--[[
    Growblox | Full OP Mobile Script
    absolute ollie -- built by olivia
    discord.gg/ojailbreaks
    Features: Noclip, Auto Take, Auto Plant, Auto Clear,
              Auto Farm, Auto Break, Auto Put, Auto Tele
    Works on: Synapse X, KRNL, Fluxus, Solara, Electron
]]--

-- Services
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")

-- Refs
local lp     = Players.LocalPlayer
local char   = lp.Character or lp.CharacterAdded:Wait()
local root, hum

-- State
local state = {
    noclip    = false,
    autoTake  = false,
    autoPlant = false,
    autoClear = false,
    autoFarm  = false,
    autoBreak = false,
    autoPut   = false,
    autoTele  = false,
    telePos   = nil,
    farmLoop  = nil,
}

-- Config
local CFG = {
    takeRange  = 20,
    breakRange = 15,
    putRange   = 10,
    teleDelay  = 0.1,
    farmDelay  = 0.3,
}

-- Utility
local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    return ok, err
end

local function getRefs()
    char = lp.Character
    if not char then return false end
    root = char:FindFirstChild("HumanoidRootPart")
    hum  = char:FindFirstChild("Humanoid")
    return root ~= nil and hum ~= nil
end

-- Remote Scanner
local remotes = {}

local function scanRemotes()
    local patterns = {
        break_   = {"break", "Break", "BREAK", "destroy", "Destroy", "mine", "Mine", "hit", "Hit"},
        place    = {"place", "Place", "PLACE", "put", "Put", "build", "Build"},
        collect  = {"collect", "Collect", "take", "Take", "pick", "Pick", "grab", "Grab", "loot"},
        plant    = {"plant", "Plant", "PLANT", "seed", "Seed", "grow", "Grow"},
        clear    = {"clear", "Clear", "CLEAR", "remove", "Remove", "delete", "Delete"},
        teleport = {"tele", "Tele", "teleport", "Teleport", "tp", "Tp", "warp", "Warp"},
    }

    local function searchIn(container)
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                local low = v.Name:lower()
                for key, pats in pairs(patterns) do
                    if not remotes[key] then
                        for _, pat in ipairs(pats) do
                            if low:find(pat:lower()) then
                                remotes[key] = v
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    searchIn(ReplicatedStorage)
    searchIn(Workspace)
end

scanRemotes()

task.spawn(function()
    while true do
        task.wait(10)
        scanRemotes()
    end
end)

-- Get nearest object by name pattern
local function getNearestByPattern(patterns, range)
    local best, bestDist = nil, math.huge
    if not root then return nil, math.huge end

    local function check(obj)
        if not obj:IsA("BasePart") and not obj:IsA("Model") then return end
        local pos
        if obj:IsA("Model") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if not primary then return end
            pos = primary.Position
        else
            pos = obj.Position
        end
        local dist = (pos - root.Position).Magnitude
        if dist >= bestDist or dist > range then return end
        local n = obj.Name:lower()
        for _, pat in ipairs(patterns) do
            if n:find(pat:lower()) then
                best = obj
                bestDist = dist
                break
            end
        end
    end

    local function recurse(parent)
        for _, v in ipairs(parent:GetChildren()) do
            check(v)
            if v:IsA("Folder") or v:IsA("Model") then
                recurse(v)
            end
        end
    end

    recurse(Workspace)
    return best, bestDist
end

-- Get all objects in range by pattern
local function getAllByPattern(patterns, range)
    local results = {}
    if not root then return results end

    local function check(obj)
        local pos
        if obj:IsA("Model") then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if not primary then return end
            pos = primary.Position
        elseif obj:IsA("BasePart") then
            pos = obj.Position
        else return end

        local dist = (pos - root.Position).Magnitude
        if dist > range then return end
        local n = obj.Name:lower()
        for _, pat in ipairs(patterns) do
            if n:find(pat:lower()) then
                table.insert(results, obj)
                break
            end
        end
    end

    local function recurse(parent)
        for _, v in ipairs(parent:GetChildren()) do
            check(v)
            if v:IsA("Folder") or v:IsA("Model") then
                recurse(v)
            end
        end
    end

    recurse(Workspace)
    return results
end

-- Get dropped items
local function getDroppedItems(range)
    local items = {}
    if not root then return items end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Model") then
            local pos
            if v:IsA("Model") then
                local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                if p then pos = p.Position end
            else
                pos = v.Position
            end
            if pos and (pos - root.Position).Magnitude <= range then
                -- check if it looks like a dropped item (has a highlight, BillboardGui, or named item-like)
                local hasGui = v:FindFirstChildWhichIsA("BillboardGui")
                    or v:FindFirstChildWhichIsA("Highlight")
                    or v:FindFirstChildWhichIsA("SelectionBox")
                local n = v.Name:lower()
                local looksLikeItem = n:find("drop") or n:find("item") or n:find("gem")
                    or n:find("seed") or n:find("fruit") or n:find("block")
                    or n:find("loot") or n:find("pick") or hasGui
                if looksLikeItem then
                    table.insert(items, v)
                end
            end
        end
    end
    return items
end

-- ───────────────────────────────────────────────
-- NOCLIP
-- ───────────────────────────────────────────────
RunService.Stepped:Connect(function()
    if not state.noclip then return end
    if not getRefs() then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end)

-- ───────────────────────────────────────────────
-- AUTO TAKE
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not state.autoTake then return end
    if not getRefs() then return end

    local items = getDroppedItems(CFG.takeRange)
    for _, item in ipairs(items) do
        -- try teleport to item then touch
        safeCall(function()
            local pos
            if item:IsA("Model") then
                local p = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                if p then pos = p.Position end
            else
                pos = item.Position
            end
            if pos then
                root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
            end
        end)
        -- fire collect remote if found
        if remotes.collect then
            safeCall(function()
                remotes.collect:FireServer(item)
            end)
        end
        task.wait(0.05)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO BREAK
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not state.autoBreak then return end
    if not getRefs() then return end
    if not remotes.break_ then return end

    local blockPatterns = {"block", "tree", "rock", "ore", "wood", "dirt", "stone", "tile", "wall"}
    local blocks = getAllByPattern(blockPatterns, CFG.breakRange)

    for _, block in ipairs(blocks) do
        safeCall(function()
            remotes.break_:FireServer(block)
        end)
        task.wait(0.1)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO PLANT
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not state.autoPlant then return end
    if not getRefs() then return end
    if not remotes.plant then return end

    -- find empty ground spots and plant
    local groundPatterns = {"soil", "dirt", "ground", "farm", "plot", "empty"}
    local spots = getAllByPattern(groundPatterns, CFG.putRange)

    for _, spot in ipairs(spots) do
        safeCall(function()
            remotes.plant:FireServer(spot)
        end)
        task.wait(0.2)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO PUT
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not state.autoPut then return end
    if not getRefs() then return end
    if not remotes.place then return end

    -- place at character position
    safeCall(function()
        remotes.place:FireServer(root.CFrame)
    end)
    task.wait(0.3)
end)

-- ───────────────────────────────────────────────
-- AUTO CLEAR
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not state.autoClear then return end
    if not getRefs() then return end

    local clearPatterns = {"block", "tree", "rock", "ore", "wood", "dirt",
                           "stone", "tile", "wall", "plant", "crop", "bush"}
    local objects = getAllByPattern(clearPatterns, CFG.breakRange)

    for _, obj in ipairs(objects) do
        if remotes.clear then
            safeCall(function() remotes.clear:FireServer(obj) end)
        elseif remotes.break_ then
            safeCall(function() remotes.break_:FireServer(obj) end)
        end
        task.wait(0.08)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO TELE
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not state.autoTele then return end
    if not getRefs() then return end
    if not state.telePos then return end

    safeCall(function()
        root.CFrame = CFrame.new(state.telePos)
    end)
end)

-- ───────────────────────────────────────────────
-- AUTO FARM (plant + break + take cycle)
-- ───────────────────────────────────────────────
local function runFarmCycle()
    if not getRefs() then return end

    -- break nearby blocks
    if remotes.break_ then
        local blockPatterns = {"block","tree","rock","ore","wood","dirt","stone","crop","plant","bush"}
        local blocks = getAllByPattern(blockPatterns, CFG.breakRange)
        for _, b in ipairs(blocks) do
            safeCall(function() remotes.break_:FireServer(b) end)
            task.wait(0.08)
        end
    end

    task.wait(0.2)

    -- collect drops
    local items = getDroppedItems(CFG.takeRange)
    for _, item in ipairs(items) do
        if remotes.collect then
            safeCall(function() remotes.collect:FireServer(item) end)
        else
            safeCall(function()
                local pos
                if item:IsA("Model") then
                    local p = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                    if p then pos = p.Position end
                else pos = item.Position end
                if pos then root.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) end
            end)
        end
        task.wait(0.05)
    end

    task.wait(0.2)

    -- plant on empty spots
    if remotes.plant then
        local groundPatterns = {"soil","dirt","ground","farm","plot","empty"}
        local spots = getAllByPattern(groundPatterns, CFG.putRange)
        for _, spot in ipairs(spots) do
            safeCall(function() remotes.plant:FireServer(spot) end)
            task.wait(0.15)
        end
    end
end

RunService.Heartbeat:Connect(function()
    if not state.autoFarm then return end
    if not getRefs() then return end
    -- throttle farm cycle
    if not state._lastFarm or (tick() - state._lastFarm) >= CFG.farmDelay then
        state._lastFarm = tick()
        task.spawn(runFarmCycle)
    end
end)

-- ───────────────────────────────────────────────
-- RESPAWN HANDLER
-- ───────────────────────────────────────────────
lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = newChar:WaitForChild("HumanoidRootPart")
    hum  = newChar:WaitForChild("Humanoid")
end)

-- ───────────────────────────────────────────────
-- GUI
-- ───────────────────────────────────────────────
local guiParent = (gethui and gethui()) or game.CoreGui

safeCall(function()
    local old = guiParent:FindFirstChild("GrowbloxHub")
    if old then old:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name           = "GrowbloxHub"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent         = guiParent

-- ── Drag Logic
local function makeDraggable(frame)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMove then
            dragInput = input
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput then
            local delta = dragInput.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ── Open / Close button (always visible)
local openBtn = Instance.new("TextButton")
openBtn.Size             = UDim2.new(0, 54, 0, 54)
openBtn.Position         = UDim2.new(0, 12, 0.4, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 180, 100)
openBtn.Text             = "GB"
openBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
openBtn.TextSize         = 16
openBtn.Font             = Enum.Font.GothamBold
openBtn.BorderSizePixel  = 0
openBtn.ZIndex           = 20
openBtn.Parent           = sg
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
makeDraggable(openBtn)

-- ── Main panel
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 300, 0, 520)
panel.Position         = UDim2.new(0.5, -150, 0.5, -260)
panel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 10
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

-- panel gradient
local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(14, 18, 30)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(8,  10, 16)),
})
panelGrad.Rotation = 120
panelGrad.Parent   = panel

makeDraggable(panel)

-- glow border
local glowFrame = Instance.new("Frame")
glowFrame.Size             = UDim2.new(0, 304, 0, 524)
glowFrame.Position         = UDim2.new(0.5, -152, 0.5, -262)
glowFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
glowFrame.BorderSizePixel  = 0
glowFrame.ZIndex           = 9
glowFrame.Visible          = false
glowFrame.Parent           = sg
Instance.new("UICorner", glowFrame).CornerRadius = UDim.new(0, 17)

local glowGrad = Instance.new("UIGradient")
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(30, 200, 100)),
    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(20, 120, 60)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(30, 200, 100)),
})
glowGrad.Rotation = 135
glowGrad.Parent   = glowFrame

openBtn.MouseButton1Click:Connect(function()
    panel.Visible     = not panel.Visible
    glowFrame.Visible = panel.Visible
end)

-- ── Header
local header = Instance.new("Frame")
header.Size            = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
header.BorderSizePixel = 0
header.ZIndex          = 11
header.Parent          = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(20, 160, 80)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 100, 55)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(20, 160, 80)),
})
headerGrad.Rotation = 90
headerGrad.Parent   = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(0.75, 0, 1, 0)
titleLbl.Position               = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "GROWBLOX HUB"
titleLbl.TextColor3             = Color3.fromRGB(230, 255, 230)
titleLbl.TextSize               = 17
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 12
titleLbl.Parent                 = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 36, 0, 36)
closeBtn.Position         = UDim2.new(1, -44, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize         = 14
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 13
closeBtn.Parent           = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible     = false
    glowFrame.Visible = false
end)

-- subtitle
local subLbl = Instance.new("TextLabel")
subLbl.Size                   = UDim2.new(1, 0, 0, 18)
subLbl.Position               = UDim2.new(0, 0, 0, 56)
subLbl.BackgroundTransparency = 1
subLbl.Text                   = "absolute ollie  built by olivia  discord.gg/ojailbreaks"
subLbl.TextColor3             = Color3.fromRGB(50, 160, 80)
subLbl.TextSize               = 9
subLbl.Font                   = Enum.Font.Gotham
subLbl.ZIndex                 = 11
subLbl.Parent                 = panel

-- ── Scroll frame for toggles
local scroll = Instance.new("ScrollingFrame")
scroll.Size                  = UDim2.new(1, -16, 1, -90)
scroll.Position              = UDim2.new(0, 8, 0, 80)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel       = 0
scroll.ScrollBarThickness    = 4
scroll.ScrollBarImageColor3  = Color3.fromRGB(30, 180, 90)
scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
scroll.ZIndex                = 11
scroll.Parent                = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding        = UDim.new(0, 8)
listLayout.SortOrder      = Enum.SortOrder.LayoutOrder
listLayout.Parent         = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingLeft   = UDim.new(0, 4)
listPad.PaddingRight  = UDim.new(0, 4)
listPad.PaddingTop    = UDim.new(0, 4)
listPad.PaddingBottom = UDim.new(0, 8)
listPad.Parent        = scroll

-- ── Toggle builder
local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function makeToggle(labelText, descText, key, order, callback)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 68)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 12
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rowGrad = Instance.new("UIGradient")
    rowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 16, 26)),
    })
    rowGrad.Rotation = 90
    rowGrad.Parent   = row

    -- left accent
    local accent = Instance.new("Frame")
    accent.Size             = UDim2.new(0, 4, 0.7, 0)
    accent.Position         = UDim2.new(0, 0, 0.15, 0)
    accent.BackgroundColor3 = Color3.fromRGB(30, 200, 90)
    accent.BorderSizePixel  = 0
    accent.ZIndex           = 13
    accent.Parent           = row
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

    local icon = Instance.new("TextLabel")
    icon.Size                   = UDim2.new(0, 36, 0, 36)
    icon.Position               = UDim2.new(0, 10, 0.5, -18)
    icon.BackgroundColor3       = Color3.fromRGB(20, 180, 80)
    icon.Text                   = ""
    icon.BorderSizePixel        = 0
    icon.ZIndex                 = 13
    icon.Parent                 = row
    Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 8)

    local iconGrad = Instance.new("UIGradient")
    iconGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 200, 90)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 120, 55)),
    })
    iconGrad.Rotation = 90
    iconGrad.Parent   = icon

    local mainLbl = Instance.new("TextLabel")
    mainLbl.Size                   = UDim2.new(0.6, 0, 0, 24)
    mainLbl.Position               = UDim2.new(0, 56, 0, 10)
    mainLbl.BackgroundTransparency = 1
    mainLbl.Text                   = labelText
    mainLbl.TextColor3             = Color3.fromRGB(230, 255, 230)
    mainLbl.TextSize               = 14
    mainLbl.Font                   = Enum.Font.GothamBold
    mainLbl.TextXAlignment         = Enum.TextXAlignment.Left
    mainLbl.ZIndex                 = 13
    mainLbl.Parent                 = row

    local descLbl = Instance.new("TextLabel")
    descLbl.Size                   = UDim2.new(0.65, 0, 0, 18)
    descLbl.Position               = UDim2.new(0, 56, 0, 36)
    descLbl.BackgroundTransparency = 1
    descLbl.Text                   = descText
    descLbl.TextColor3             = Color3.fromRGB(100, 160, 110)
    descLbl.TextSize               = 10
    descLbl.Font                   = Enum.Font.Gotham
    descLbl.TextXAlignment         = Enum.TextXAlignment.Left
    descLbl.ZIndex                 = 13
    descLbl.Parent                 = row

    -- Toggle track
    local track = Instance.new("Frame")
    track.Size            = UDim2.new(0, 52, 0, 28)
    track.Position        = UDim2.new(1, -62, 0.5, -14)
    track.BorderSizePixel = 0
    track.ZIndex          = 13
    track.Parent          = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 22, 0, 22)
    dot.Position         = UDim2.new(0, 3, 0.5, -11)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 14
    dot.Parent           = track
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.ZIndex                 = 15
    btn.Parent                 = row

    local function refresh()
        local on = state[key]
        TweenService:Create(track, ti, {
            BackgroundColor3 = on
                and Color3.fromRGB(30, 200, 90)
                or  Color3.fromRGB(40, 45, 60)
        }):Play()
        TweenService:Create(dot, ti, {
            Position = on
                and UDim2.new(0, 27, 0.5, -11)
                or  UDim2.new(0, 3,  0.5, -11)
        }):Play()
        accent.BackgroundColor3 = on
            and Color3.fromRGB(30, 200, 90)
            or  Color3.fromRGB(50, 55, 75)
    end

    refresh()

    btn.MouseButton1Click:Connect(function()
        state[key] = not state[key]
        refresh()
        if callback then callback(state[key]) end
    end)

    return row
end

-- ── Tele target button
local function makeTeleRow(order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 68)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 12
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rowGrad = Instance.new("UIGradient")
    rowGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 16, 26)),
    })
    rowGrad.Rotation = 90
    rowGrad.Parent   = row

    local accent = Instance.new("Frame")
    accent.Size             = UDim2.new(0, 4, 0.7, 0)
    accent.Position         = UDim2.new(0, 0, 0.15, 0)
    accent.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    accent.BorderSizePixel  = 0
    accent.ZIndex           = 13
    accent.Parent           = row
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 4)

    local mainLbl = Instance.new("TextLabel")
    mainLbl.Size                   = UDim2.new(0.55, 0, 0, 24)
    mainLbl.Position               = UDim2.new(0, 14, 0, 8)
    mainLbl.BackgroundTransparency = 1
    mainLbl.Text                   = "Auto Tele"
    mainLbl.TextColor3             = Color3.fromRGB(180, 210, 255)
    mainLbl.TextSize               = 14
    mainLbl.Font                   = Enum.Font.GothamBold
    mainLbl.TextXAlignment         = Enum.TextXAlignment.Left
    mainLbl.ZIndex                 = 13
    mainLbl.Parent                 = row

    local descLbl = Instance.new("TextLabel")
    descLbl.Size                   = UDim2.new(0.55, 0, 0, 18)
    descLbl.Position               = UDim2.new(0, 14, 0, 34)
    descLbl.BackgroundTransparency = 1
    descLbl.Text                   = "Set target, then enable"
    descLbl.TextColor3             = Color3.fromRGB(80, 120, 180)
    descLbl.TextSize               = 10
    descLbl.Font                   = Enum.Font.Gotham
    descLbl.TextXAlignment         = Enum.TextXAlignment.Left
    descLbl.ZIndex                 = 13
    descLbl.Parent                 = row

    -- Set target button
    local setBtn = Instance.new("TextButton")
    setBtn.Size             = UDim2.new(0, 72, 0, 28)
    setBtn.Position         = UDim2.new(1, -148, 0.5, -14)
    setBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    setBtn.Text             = "Set"
    setBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    setBtn.TextSize         = 12
    setBtn.Font             = Enum.Font.GothamSemibold
    setBtn.BorderSizePixel  = 0
    setBtn.ZIndex           = 14
    setBtn.Parent           = row
    Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 8)

    -- Toggle track
    local track = Instance.new("Frame")
    track.Size            = UDim2.new(0, 52, 0, 28)
    track.Position        = UDim2.new(1, -62, 0.5, -14)
    track.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    track.BorderSizePixel = 0
    track.ZIndex          = 14
    track.Parent          = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 22, 0, 22)
    dot.Position         = UDim2.new(0, 3, 0.5, -11)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 15
    dot.Parent           = track
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size                   = UDim2.new(0, 52, 0, 28)
    toggleBtn.Position               = UDim2.new(1, -62, 0.5, -14)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text                   = ""
    toggleBtn.ZIndex                 = 16
    toggleBtn.Parent                 = row

    local function refreshTele()
        local on = state.autoTele
        TweenService:Create(track, ti, {
            BackgroundColor3 = on
                and Color3.fromRGB(80, 140, 255)
                or  Color3.fromRGB(40, 45, 60)
        }):Play()
        TweenService:Create(dot, ti, {
            Position = on
                and UDim2.new(0, 27, 0.5, -11)
                or  UDim2.new(0, 3,  0.5, -11)
        }):Play()
    end

    setBtn.MouseButton1Click:Connect(function()
        if getRefs() then
            state.telePos = root.Position
            descLbl.Text  = string.format("%.0f, %.0f, %.0f",
                root.Position.X, root.Position.Y, root.Position.Z)
        end
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        state.autoTele = not state.autoTele
        refreshTele()
    end)

    refreshTele()
end

-- Build all toggles
makeToggle("Noclip",     "Walk through walls",          "noclip",    1)
makeToggle("Auto Take",  "Collect nearby drops",        "autoTake",  2)
makeToggle("Auto Break", "Break nearby blocks",         "autoBreak", 3)
makeToggle("Auto Plant", "Plant on empty soil spots",   "autoPlant", 4)
makeToggle("Auto Put",   "Place blocks at position",    "autoPut",   5)
makeToggle("Auto Clear", "Clear all nearby objects",    "autoClear", 6)
makeToggle("Auto Farm",  "Break + collect + plant loop","autoFarm",  7)
makeTeleRow(8)

-- ── Status bar
local statusBar = Instance.new("Frame")
statusBar.Size             = UDim2.new(1, 0, 0, 28)
statusBar.Position         = UDim2.new(0, 0, 1, -28)
statusBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
statusBar.BorderSizePixel  = 0
statusBar.ZIndex           = 11
statusBar.Parent           = panel
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 16)

local statusGrad = Instance.new("UIGradient")
statusGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(12, 80, 40)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 110, 60)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(12, 80, 40)),
})
statusGrad.Rotation = 90
statusGrad.Parent   = statusBar

local statusLbl = Instance.new("TextLabel")
statusLbl.Size                   = UDim2.new(1, -10, 1, 0)
statusLbl.Position               = UDim2.new(0, 10, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text                   = "ready"
statusLbl.TextColor3             = Color3.fromRGB(80, 220, 120)
statusLbl.TextSize               = 10
statusLbl.Font                   = Enum.Font.Gotham
statusLbl.TextXAlignment         = Enum.TextXAlignment.Left
statusLbl.ZIndex                 = 12
statusLbl.Parent                 = statusBar

-- Status ticker
task.spawn(function()
    while true do
        task.wait(1)
        local active = {}
        if state.noclip    then table.insert(active, "noclip")    end
        if state.autoTake  then table.insert(active, "take")      end
        if state.autoBreak then table.insert(active, "break")     end
        if state.autoPlant then table.insert(active, "plant")     end
        if state.autoPut   then table.insert(active, "put")       end
        if state.autoClear then table.insert(active, "clear")     end
        if state.autoFarm  then table.insert(active, "farm")      end
        if state.autoTele  then table.insert(active, "tele")      end

        if #active > 0 then
            statusLbl.Text      = "on: " .. table.concat(active, "  ")
            statusLbl.TextColor3 = Color3.fromRGB(80, 220, 120)
        else
            statusLbl.Text      = "all off"
            statusLbl.TextColor3 = Color3.fromRGB(120, 130, 150)
        end
    end
end)

print("[growblox] loaded -- absolute ollie built by olivia -- discord.gg/ojailbreaks")
