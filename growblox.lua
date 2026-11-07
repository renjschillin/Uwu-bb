--[[
    Growblox | Delta Mobile Build
    absolute ollie -- built by olivia
    discord.gg/ojailbreaks

    STEP 1: Execute this script in Delta
    STEP 2: Tap the green GB button to open
    STEP 3: Tap SPY REMOTES — read output in Delta console
    STEP 4: Edit CFG.remoteNames with the real names you see
    STEP 5: Re-execute and use features

    Built specifically for Delta executor on mobile.
    No unsupported functions used.
]]--

-- ───────────────────────────────────────────────
-- SERVICES
-- ───────────────────────────────────────────────
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local RS             = game:GetService("ReplicatedStorage")
local UIS            = game:GetService("UserInputService")
local WS             = workspace

-- ───────────────────────────────────────────────
-- PLAYER REFS
-- ───────────────────────────────────────────────
local lp   = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local root, hum

local function getChar()
    char = lp.Character
    if not char then return false end
    root = char:FindFirstChild("HumanoidRootPart")
    hum  = char:FindFirstChild("Humanoid")
    return root ~= nil and hum ~= nil
end
getChar()

-- ───────────────────────────────────────────────
-- REMOTE NAMES — EDIT THESE after running Spy
-- ───────────────────────────────────────────────
local CFG = {
    remoteNames = {
        break_  = "Break",
        place   = "Place",
        collect = "Collect",
        plant   = "Plant",
    },
    breakRange = 20,
    takeRange  = 25,
    plantRange = 15,
    farmDelay  = 0.5,
}

-- ───────────────────────────────────────────────
-- STATE
-- ───────────────────────────────────────────────
local S = {
    noclip    = false,
    autoTake  = false,
    autoBreak = false,
    autoPlant = false,
    autoPut   = false,
    autoClear = false,
    autoFarm  = false,
    autoTele  = false,
    telePos   = nil,
    lastFarm  = 0,
}

-- ───────────────────────────────────────────────
-- SAFE CALL — delta crashes on unprotected errors
-- ───────────────────────────────────────────────
local function safe(fn, ...)
    local ok, e = pcall(fn, ...)
    return ok
end

-- ───────────────────────────────────────────────
-- REMOTE REGISTRY
-- ───────────────────────────────────────────────
local R = {}

local function bindRemotes()
    for key, name in pairs(CFG.remoteNames) do
        R[key] = nil
        -- search ReplicatedStorage
        for _, v in ipairs(RS:GetDescendants()) do
            if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
            and v.Name:lower():find(name:lower()) then
                R[key] = v
                break
            end
        end
        -- search workspace if not found
        if not R[key] then
            for _, v in ipairs(WS:GetDescendants()) do
                if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
                and v.Name:lower():find(name:lower()) then
                    R[key] = v
                    break
                end
            end
        end
    end
end

bindRemotes()

-- re-bind every 6 seconds
task.spawn(function()
    while true do
        task.wait(6)
        bindRemotes()
    end
end)

-- ───────────────────────────────────────────────
-- REMOTE SPY — prints everything to Delta console
-- ───────────────────────────────────────────────
local function spyRemotes()
    print("\n===== GROWBLOX REMOTE SPY =====")
    local count = 0
    local function scan(obj, depth)
        depth = depth or 0
        for _, v in ipairs(obj:GetChildren()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("BindableEvent") then
                print("[" .. v.ClassName .. "] " .. v:GetFullName())
                count = count + 1
            end
            -- only go 4 levels deep to avoid lag
            if depth < 4 then
                safe(function() scan(v, depth + 1) end)
            end
        end
    end
    safe(function() scan(RS) end)
    safe(function() scan(WS) end)
    print("===== FOUND: " .. count .. " remotes =====\n")
end

-- ───────────────────────────────────────────────
-- WORLD HELPERS
-- ───────────────────────────────────────────────
local BLOCK_PATS = {
    "block","tile","wall","wood","stone","rock","ore",
    "tree","bush","crop","plant","dirt","grass","log",
    "sand","leaf","gem","chest","barrel","object"
}

local SOIL_PATS = {
    "soil","dirt","plot","empty","farm","bed","ground","patch"
}

local function getPartsNear(pats, range)
    local out = {}
    if not root then return out end
    for _, v in ipairs(WS:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(char) then
            if (v.Position - root.Position).Magnitude <= range then
                local n = v.Name:lower()
                for _, p in ipairs(pats) do
                    if n:find(p) then
                        table.insert(out, v)
                        break
                    end
                end
            end
        end
    end
    return out
end

local function getAllNear(range)
    local out = {}
    if not root then return out end
    for _, v in ipairs(WS:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(char) and not v.Locked then
            if (v.Position - root.Position).Magnitude <= range then
                table.insert(out, v)
            end
        end
    end
    return out
end

local function getDrops(range)
    local out = {}
    if not root then return out end
    for _, v in ipairs(WS:GetDescendants()) do
        local pos = nil
        if v:IsA("BasePart") and not v:IsDescendantOf(char) then
            pos = v.Position
        elseif v:IsA("Model") and not v:IsDescendantOf(char) then
            local pp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if pp then pos = pp.Position end
        end
        if pos and (pos - root.Position).Magnitude <= range then
            local hasTag = v:FindFirstChildWhichIsA("BillboardGui")
                        or v:FindFirstChildWhichIsA("Highlight")
                        or v:FindFirstChildWhichIsA("SelectionBox")
            local n = v.Name:lower()
            if hasTag or n:find("drop") or n:find("gem") or n:find("seed")
            or n:find("loot") or n:find("fruit") or n:find("item")
            or n:find("pickup") or n:find("coin") or n:find("orb") then
                table.insert(out, v)
            end
        end
    end
    return out
end

-- ───────────────────────────────────────────────
-- NOCLIP
-- ───────────────────────────────────────────────
RunService.Stepped:Connect(function()
    if not S.noclip then return end
    if not getChar() then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = false
        end
    end
end)

-- ───────────────────────────────────────────────
-- AUTO TAKE
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoTake then return end
    if not getChar() then return end
    local drops = getDrops(CFG.takeRange)
    for _, item in ipairs(drops) do
        local pos
        if item:IsA("Model") then
            local pp = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if pp then pos = pp.Position end
        else
            pos = item.Position
        end
        if pos then
            safe(function()
                root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
            end)
            if R.collect then
                safe(function() R.collect:FireServer(item) end)
            end
        end
        task.wait(0.06)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO BREAK
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoBreak then return end
    if not getChar() then return end
    local blocks = getPartsNear(BLOCK_PATS, CFG.breakRange)
    for _, b in ipairs(blocks) do
        if R.break_ then
            safe(function() R.break_:FireServer(b) end)
        end
        task.wait(0.09)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO PLANT
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoPlant then return end
    if not getChar() then return end
    local spots = getPartsNear(SOIL_PATS, CFG.plantRange)
    for _, s in ipairs(spots) do
        if R.plant then
            safe(function() R.plant:FireServer(s) end)
        end
        task.wait(0.14)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO PUT
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoPut then return end
    if not getChar() then return end
    if not R.place then return end
    safe(function() R.place:FireServer(root.CFrame) end)
    task.wait(0.3)
end)

-- ───────────────────────────────────────────────
-- AUTO CLEAR
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoClear then return end
    if not getChar() then return end
    local all = getAllNear(CFG.breakRange)
    for _, obj in ipairs(all) do
        if R.break_ then
            safe(function() R.break_:FireServer(obj) end)
        end
        task.wait(0.05)
    end
end)

-- ───────────────────────────────────────────────
-- AUTO TELE
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoTele then return end
    if not getChar() then return end
    if not S.telePos then return end
    safe(function()
        root.CFrame = CFrame.new(S.telePos)
    end)
end)

-- ───────────────────────────────────────────────
-- AUTO FARM
-- ───────────────────────────────────────────────
local function farmCycle()
    if not getChar() then return end
    -- break
    if R.break_ then
        for _, b in ipairs(getPartsNear(BLOCK_PATS, CFG.breakRange)) do
            safe(function() R.break_:FireServer(b) end)
            task.wait(0.08)
        end
    end
    task.wait(0.2)
    -- collect
    for _, item in ipairs(getDrops(CFG.takeRange)) do
        local pos
        if item:IsA("Model") then
            local pp = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if pp then pos = pp.Position end
        else pos = item.Position end
        if pos then
            safe(function() root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) end)
            if R.collect then safe(function() R.collect:FireServer(item) end) end
        end
        task.wait(0.06)
    end
    task.wait(0.2)
    -- plant
    if R.plant then
        for _, s in ipairs(getPartsNear(SOIL_PATS, CFG.plantRange)) do
            safe(function() R.plant:FireServer(s) end)
            task.wait(0.12)
        end
    end
end

RunService.Heartbeat:Connect(function()
    if not S.autoFarm then return end
    local now = tick()
    if (now - S.lastFarm) >= CFG.farmDelay then
        S.lastFarm = now
        task.spawn(farmCycle)
    end
end)

-- ───────────────────────────────────────────────
-- RESPAWN
-- ───────────────────────────────────────────────
lp.CharacterAdded:Connect(function(c)
    char = c
    root = c:WaitForChild("HumanoidRootPart")
    hum  = c:WaitForChild("Humanoid")
    task.wait(0.4)
    bindRemotes()
end)

-- ───────────────────────────────────────────────
-- GUI — Delta safe: lp.PlayerGui parent
-- ───────────────────────────────────────────────
safe(function()
    local old = lp.PlayerGui:FindFirstChild("GrowbloxHub")
    if old then old:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name           = "GrowbloxHub"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent         = lp.PlayerGui      -- Delta-safe parent

-- ── drag helper (touch + mouse)
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging   = false
    local dragStart  = Vector2.new()
    local frameStart = UDim2.new()

    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging   = true
            dragStart  = Vector2.new(inp.Position.X, inp.Position.Y)
            frameStart = frame.Position
        end
    end)

    handle.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    handle.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d = Vector2.new(inp.Position.X, inp.Position.Y) - dragStart
            frame.Position = UDim2.new(
                frameStart.X.Scale,  frameStart.X.Offset + d.X,
                frameStart.Y.Scale,  frameStart.Y.Offset + d.Y
            )
        end
    end)
end

-- ── floating open button
local openBtn = Instance.new("TextButton")
openBtn.Size             = UDim2.new(0, 56, 0, 56)
openBtn.Position         = UDim2.new(0, 10, 0.5, -28)
openBtn.BackgroundColor3 = Color3.fromRGB(22, 180, 85)
openBtn.BorderSizePixel  = 0
openBtn.Text             = "GB"
openBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
openBtn.TextSize         = 15
openBtn.Font             = Enum.Font.GothamBold
openBtn.ZIndex           = 20
openBtn.Active           = true
openBtn.Parent           = sg
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
makeDraggable(openBtn)

-- ── glow border
local glow = Instance.new("Frame")
glow.Size             = UDim2.new(0, 308, 0, 574)
glow.Position         = UDim2.new(0.5, -154, 0.5, -287)
glow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
glow.BorderSizePixel  = 0
glow.ZIndex           = 9
glow.Visible          = false
glow.Parent           = sg
Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 18)

local glowGrad = Instance.new("UIGradient")
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(22, 200, 85)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 110, 48)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(22, 200, 85)),
})
glowGrad.Rotation = 135
glowGrad.Parent   = glow

-- ── main panel
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 304, 0, 570)
panel.Position         = UDim2.new(0.5, -152, 0.5, -285)
panel.BackgroundColor3 = Color3.fromRGB(10, 13, 20)
panel.BorderSizePixel  = 0
panel.ZIndex           = 10
panel.Visible          = false
panel.Active           = true
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 20, 32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8,  11, 18)),
})
panelGrad.Rotation = 130
panelGrad.Parent   = panel

makeDraggable(panel)

openBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    glow.Visible  = panel.Visible
end)

-- ── header
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
header.BorderSizePixel  = 0
header.ZIndex           = 11
header.Parent           = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local hGrad = Instance.new("UIGradient")
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(16, 155, 68)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 95,  44)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(16, 155, 68)),
})
hGrad.Rotation = 90
hGrad.Parent   = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(0.72, 0, 1, 0)
titleLbl.Position               = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = " GROWBLOX HUB"
titleLbl.TextColor3             = Color3.fromRGB(215, 255, 215)
titleLbl.TextSize               = 16
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 12
titleLbl.Parent                 = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 36, 0, 36)
closeBtn.Position         = UDim2.new(1, -44, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(185, 48, 48)
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize         = 13
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.BorderSizePixel  = 0
closeBtn.ZIndex           = 13
closeBtn.Parent           = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
    glow.Visible  = false
end)

-- subtitle
local subLbl = Instance.new("TextLabel")
subLbl.Size                   = UDim2.new(1, 0, 0, 16)
subLbl.Position               = UDim2.new(0, 0, 0, 52)
subLbl.BackgroundTransparency = 1
subLbl.Text                   = "absolute ollie  built by olivia  discord.gg/ojailbreaks"
subLbl.TextColor3             = Color3.fromRGB(38, 145, 68)
subLbl.TextSize               = 9
subLbl.Font                   = Enum.Font.Gotham
subLbl.ZIndex                 = 11
subLbl.Parent                 = panel

-- spy button
local spyBtn = Instance.new("TextButton")
spyBtn.Size             = UDim2.new(1, -18, 0, 38)
spyBtn.Position         = UDim2.new(0, 9, 0, 72)
spyBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
spyBtn.Text             = "SPY REMOTES  (check Delta console)"
spyBtn.TextColor3       = Color3.fromRGB(255, 210, 55)
spyBtn.TextSize         = 12
spyBtn.Font             = Enum.Font.GothamSemibold
spyBtn.BorderSizePixel  = 0
spyBtn.ZIndex           = 11
spyBtn.Parent           = panel
Instance.new("UICorner", spyBtn).CornerRadius = UDim.new(0, 10)

local spyGrad = Instance.new("UIGradient")
spyGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(75, 60, 8)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 38, 5)),
})
spyGrad.Rotation = 90
spyGrad.Parent   = spyBtn

spyBtn.MouseButton1Click:Connect(function()
    spyBtn.Text = "Spying..."
    task.spawn(function()
        spyRemotes()
        task.wait(1.2)
        spyBtn.Text = "SPY REMOTES  (check Delta console)"
    end)
end)

-- remote status
local remoteLbl = Instance.new("TextLabel")
remoteLbl.Size                   = UDim2.new(1, -18, 0, 18)
remoteLbl.Position               = UDim2.new(0, 9, 0, 115)
remoteLbl.BackgroundTransparency = 1
remoteLbl.Text                   = "remotes: scanning..."
remoteLbl.TextColor3             = Color3.fromRGB(180, 180, 60)
remoteLbl.TextSize               = 10
remoteLbl.Font                   = Enum.Font.Gotham
remoteLbl.TextXAlignment         = Enum.TextXAlignment.Left
remoteLbl.ZIndex                 = 11
remoteLbl.Parent                 = panel

-- ── scroll
local scroll = Instance.new("ScrollingFrame")
scroll.Size                   = UDim2.new(1, -14, 1, -178)
scroll.Position               = UDim2.new(0, 7, 0, 138)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = Color3.fromRGB(22, 180, 85)
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.ZIndex                 = 11
scroll.Parent                 = panel

local listL = Instance.new("UIListLayout")
listL.Padding   = UDim.new(0, 7)
listL.SortOrder = Enum.SortOrder.LayoutOrder
listL.Parent    = scroll

local listP = Instance.new("UIPadding")
listP.PaddingLeft   = UDim.new(0, 2)
listP.PaddingRight  = UDim.new(0, 2)
listP.PaddingTop    = UDim.new(0, 3)
listP.PaddingBottom = UDim.new(0, 6)
listP.Parent        = scroll

-- ── toggle row builder
local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function makeToggle(tag, label, desc, key, order, onCol)
    onCol = onCol or Color3.fromRGB(22, 190, 85)

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 62)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 12
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rg = Instance.new("UIGradient")
    rg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 23, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 15, 24)),
    })
    rg.Rotation = 90
    rg.Parent   = row

    -- left accent
    local acc = Instance.new("Frame")
    acc.Size             = UDim2.new(0, 3, 0.6, 0)
    acc.Position         = UDim2.new(0, 0, 0.2, 0)
    acc.BackgroundColor3 = Color3.fromRGB(48, 52, 72)
    acc.BorderSizePixel  = 0
    acc.ZIndex           = 13
    acc.Parent           = row
    Instance.new("UICorner", acc).CornerRadius = UDim.new(1, 0)

    -- tag bubble
    local bubble = Instance.new("TextLabel")
    bubble.Size             = UDim2.new(0, 36, 0, 36)
    bubble.Position         = UDim2.new(0, 10, 0.5, -18)
    bubble.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bubble.Text             = tag
    bubble.TextSize         = 12
    bubble.Font             = Enum.Font.GothamBold
    bubble.TextColor3       = Color3.fromRGB(200, 220, 200)
    bubble.BorderSizePixel  = 0
    bubble.ZIndex           = 13
    bubble.Parent           = row
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 9)

    local bg = Instance.new("UIGradient")
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 26, 42)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 17, 28)),
    })
    bg.Rotation = 90
    bg.Parent   = bubble

    local mainL = Instance.new("TextLabel")
    mainL.Size                   = UDim2.new(0.58, 0, 0, 20)
    mainL.Position               = UDim2.new(0, 54, 0, 10)
    mainL.BackgroundTransparency = 1
    mainL.Text                   = label
    mainL.TextColor3             = Color3.fromRGB(225, 242, 225)
    mainL.TextSize               = 13
    mainL.Font                   = Enum.Font.GothamBold
    mainL.TextXAlignment         = Enum.TextXAlignment.Left
    mainL.ZIndex                 = 13
    mainL.Parent                 = row

    local descL = Instance.new("TextLabel")
    descL.Size                   = UDim2.new(0.6, 0, 0, 15)
    descL.Position               = UDim2.new(0, 54, 0, 32)
    descL.BackgroundTransparency = 1
    descL.Text                   = desc
    descL.TextColor3             = Color3.fromRGB(70, 120, 80)
    descL.TextSize               = 10
    descL.Font                   = Enum.Font.Gotham
    descL.TextXAlignment         = Enum.TextXAlignment.Left
    descL.ZIndex                 = 13
    descL.Parent                 = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, 50, 0, 26)
    track.Position         = UDim2.new(1, -58, 0.5, -13)
    track.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
    track.BorderSizePixel  = 0
    track.ZIndex           = 13
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 20, 0, 20)
    dot.Position         = UDim2.new(0, 3, 0.5, -10)
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
        local on = S[key]
        TweenService:Create(track, TI, {
            BackgroundColor3 = on and onCol or Color3.fromRGB(36, 42, 58)
        }):Play()
        TweenService:Create(dot, TI, {
            Position = on
                and UDim2.new(0, 27, 0.5, -10)
                or  UDim2.new(0, 3,  0.5, -10)
        }):Play()
        acc.BackgroundColor3 = on and onCol or Color3.fromRGB(48, 52, 72)
    end

    refresh()
    btn.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        refresh()
    end)
end

-- ── tele row
local function makeTeleRow(order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 62)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 12
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rg = Instance.new("UIGradient")
    rg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 20, 38)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 14, 26)),
    })
    rg.Rotation = 90
    rg.Parent   = row

    local acc = Instance.new("Frame")
    acc.Size             = UDim2.new(0, 3, 0.6, 0)
    acc.Position         = UDim2.new(0, 0, 0.2, 0)
    acc.BackgroundColor3 = Color3.fromRGB(48, 52, 72)
    acc.BorderSizePixel  = 0
    acc.ZIndex           = 13
    acc.Parent           = row
    Instance.new("UICorner", acc).CornerRadius = UDim.new(1, 0)

    local bubble = Instance.new("TextLabel")
    bubble.Size             = UDim2.new(0, 36, 0, 36)
    bubble.Position         = UDim2.new(0, 10, 0.5, -18)
    bubble.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bubble.Text             = "TP"
    bubble.TextSize         = 12
    bubble.Font             = Enum.Font.GothamBold
    bubble.TextColor3       = Color3.fromRGB(160, 195, 255)
    bubble.BorderSizePixel  = 0
    bubble.ZIndex           = 13
    bubble.Parent           = row
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 9)

    local bg = Instance.new("UIGradient")
    bg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 24, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 16, 32)),
    })
    bg.Rotation = 90
    bg.Parent   = bubble

    local mainL = Instance.new("TextLabel")
    mainL.Size                   = UDim2.new(0.4, 0, 0, 20)
    mainL.Position               = UDim2.new(0, 54, 0, 8)
    mainL.BackgroundTransparency = 1
    mainL.Text                   = "Auto Tele"
    mainL.TextColor3             = Color3.fromRGB(160, 195, 255)
    mainL.TextSize               = 13
    mainL.Font                   = Enum.Font.GothamBold
    mainL.TextXAlignment         = Enum.TextXAlignment.Left
    mainL.ZIndex                 = 13
    mainL.Parent                 = row

    local coordL = Instance.new("TextLabel")
    coordL.Size                   = UDim2.new(0.5, 0, 0, 15)
    coordL.Position               = UDim2.new(0, 54, 0, 32)
    coordL.BackgroundTransparency = 1
    coordL.Text                   = "tap Set to lock position"
    coordL.TextColor3             = Color3.fromRGB(70, 100, 155)
    coordL.TextSize               = 9
    coordL.Font                   = Enum.Font.Gotham
    coordL.TextXAlignment         = Enum.TextXAlignment.Left
    coordL.ZIndex                 = 13
    coordL.Parent                 = row

    local setBtn = Instance.new("TextButton")
    setBtn.Size             = UDim2.new(0, 44, 0, 24)
    setBtn.Position         = UDim2.new(1, -108, 0.5, -12)
    setBtn.BackgroundColor3 = Color3.fromRGB(45, 85, 195)
    setBtn.Text             = "Set"
    setBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    setBtn.TextSize         = 11
    setBtn.Font             = Enum.Font.GothamSemibold
    setBtn.BorderSizePixel  = 0
    setBtn.ZIndex           = 14
    setBtn.Parent           = row
    Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 7)

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, 50, 0, 26)
    track.Position         = UDim2.new(1, -58, 0.5, -13)
    track.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
    track.BorderSizePixel  = 0
    track.ZIndex           = 13
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 20, 0, 20)
    dot.Position         = UDim2.new(0, 3, 0.5, -10)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 14
    dot.Parent           = track
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size                   = UDim2.new(0, 50, 0, 26)
    toggleBtn.Position               = UDim2.new(1, -58, 0.5, -13)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text                   = ""
    toggleBtn.ZIndex                 = 16
    toggleBtn.Parent                 = row

    local teleOnCol = Color3.fromRGB(80, 125, 255)

    local function refreshTele()
        local on = S.autoTele
        TweenService:Create(track, TI, {
            BackgroundColor3 = on and teleOnCol or Color3.fromRGB(36, 42, 58)
        }):Play()
        TweenService:Create(dot, TI, {
            Position = on
                and UDim2.new(0, 27, 0.5, -10)
                or  UDim2.new(0, 3,  0.5, -10)
        }):Play()
        acc.BackgroundColor3 = on and teleOnCol or Color3.fromRGB(48, 52, 72)
    end

    setBtn.MouseButton1Click:Connect(function()
        if getChar() then
            S.telePos  = root.Position
            coordL.Text = string.format("%.0f / %.0f / %.0f",
                root.Position.X, root.Position.Y, root.Position.Z)
            setBtn.BackgroundColor3 = Color3.fromRGB(22, 175, 80)
            task.delay(0.7, function()
                setBtn.BackgroundColor3 = Color3.fromRGB(45, 85, 195)
            end)
        end
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        S.autoTele = not S.autoTele
        refreshTele()
    end)

    refreshTele()
end

-- build all rows
makeToggle("NC", "Noclip",     "Walk through walls/blocks",     "noclip",    1, Color3.fromRGB(230, 95,  45))
makeToggle("TK", "Auto Take",  "Collect nearby drops",          "autoTake",  2, Color3.fromRGB(22,  195, 85))
makeToggle("BK", "Auto Break", "Break nearby blocks",           "autoBreak", 3, Color3.fromRGB(220, 75,  55))
makeToggle("PL", "Auto Plant", "Plant on empty soil",           "autoPlant", 4, Color3.fromRGB(75,  205, 75))
makeToggle("PT", "Auto Put",   "Place blocks at your spot",     "autoPut",   5, Color3.fromRGB(75,  155, 230))
makeToggle("CL", "Auto Clear", "Clear everything nearby",       "autoClear", 6, Color3.fromRGB(195, 75,  200))
makeToggle("FM", "Auto Farm",  "Full break+collect+plant loop", "autoFarm",  7, Color3.fromRGB(220, 175, 38))
makeTeleRow(8)

-- ── status bar
local sBar = Instance.new("Frame")
sBar.Size             = UDim2.new(1, 0, 0, 30)
sBar.Position         = UDim2.new(0, 0, 1, -30)
sBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sBar.BorderSizePixel  = 0
sBar.ZIndex           = 11
sBar.Parent           = panel
Instance.new("UICorner", sBar).CornerRadius = UDim.new(0, 16)

local sbG = Instance.new("UIGradient")
sbG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(9,  68, 32)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(13, 90, 44)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(9,  68, 32)),
})
sbG.Rotation = 90
sbG.Parent   = sBar

local sLbl = Instance.new("TextLabel")
sLbl.Size                   = UDim2.new(1, -10, 1, 0)
sLbl.Position               = UDim2.new(0, 10, 0, 0)
sLbl.BackgroundTransparency = 1
sLbl.Text                   = "ready"
sLbl.TextColor3             = Color3.fromRGB(55, 195, 95)
sLbl.TextSize               = 10
sLbl.Font                   = Enum.Font.Gotham
sLbl.TextXAlignment         = Enum.TextXAlignment.Left
sLbl.ZIndex                 = 12
sLbl.Parent                 = sBar

-- ── ticker
task.spawn(function()
    while true do
        task.wait(0.8)
        -- remote count
        local rc = 0
        for _ in pairs(R) do rc = rc + 1 end
        if rc > 0 then
            remoteLbl.Text       = "remotes locked: " .. rc .. "/4   OK"
            remoteLbl.TextColor3 = Color3.fromRGB(55, 200, 95)
        else
            remoteLbl.Text       = "no remotes — tap SPY first"
            remoteLbl.TextColor3 = Color3.fromRGB(220, 155, 45)
        end
        -- active features
        local a = {}
        if S.noclip    then table.insert(a, "NC")  end
        if S.autoTake  then table.insert(a, "TK")  end
        if S.autoBreak then table.insert(a, "BK")  end
        if S.autoPlant then table.insert(a, "PL")  end
        if S.autoPut   then table.insert(a, "PT")  end
        if S.autoClear then table.insert(a, "CL")  end
        if S.autoFarm  then table.insert(a, "FM")  end
        if S.autoTele  then table.insert(a, "TP")  end

        if #a > 0 then
            sLbl.Text       = "on: " .. table.concat(a, " ")
            sLbl.TextColor3 = Color3.fromRGB(55, 195, 95)
        else
            sLbl.Text       = "all off"
            sLbl.TextColor3 = Color3.fromRGB(85, 95, 115)
        end
    end
end)

-- auto spy on load
task.spawn(function()
    task.wait(2.5)
    spyRemotes()
    bindRemotes()
end)

print("[growblox] delta build loaded -- discord.gg/ojailbreaks")
