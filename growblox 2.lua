--[[
    Growblox | OP Enhanced Build
    absolute ollie -- built by olivia
    discord.gg/ojailbreaks

    Features:
      Anti-Lava / Anti-Spike / Anti-Damage tiles
      Auto Teleport (set + go)
      Auto Farm (break + collect loop)
      Auto Break / Auto Take / Auto Plant
      Noclip / Fly
      Health Lock (immortal)
      WorldRemote auto-detect

    Delta / Mobile compatible.
    GUI button: TOP-RIGHT corner, green GB.
]]--

-- ───────────────────────────────────────────────
-- SERVICES
-- ───────────────────────────────────────────────
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS         = game:GetService("ReplicatedStorage")
local WS         = workspace

-- ───────────────────────────────────────────────
-- REFS
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
-- CONFIG
-- ───────────────────────────────────────────────
local CFG = {
    -- remote names (auto-detected, override here if needed)
    worldRemote  = "WorldRemote",
    breakRemote  = "Break",
    collectRemote= "Collect",
    plantRemote  = "Plant",
    placeRemote  = "Place",

    -- ranges
    breakRange   = 20,
    takeRange    = 25,
    plantRange   = 15,
    dangerRange  = 8,     -- how close to lava/spike before teleport away

    -- farm
    farmDelay    = 0.4,

    -- anti-damage tile names (partial match, lowercase)
    dangerTiles  = {
        "lava","lava_block","lavabrick",
        "spike","spikes","thorn","thorns",
        "cactus","acid","poison","fire",
        "magma","void","instakill","kill",
        "trap","blade","saw","hazard",
    },

    -- safe Y offset when escaping danger (teleport up)
    escapeOffset = Vector3.new(0, 8, 0),
}

-- ───────────────────────────────────────────────
-- STATE
-- ───────────────────────────────────────────────
local S = {
    noclip      = false,
    fly         = false,
    immortal    = false,
    antiDanger  = true,   -- anti-lava/spike ON by default
    autoTake    = false,
    autoBreak   = false,
    autoPlant   = false,
    autoPut     = false,
    autoFarm    = false,
    autoTele    = false,
    telePos     = nil,
    lastFarm    = 0,
    lastDanger  = 0,
    flyBV       = nil,    -- BodyVelocity ref for fly
}

-- ───────────────────────────────────────────────
-- SAFE CALL
-- ───────────────────────────────────────────────
local function safe(fn, ...)
    local ok, e = pcall(fn, ...)
    if not ok then
        print("[GB err] " .. tostring(e))
    end
    return ok
end

-- ───────────────────────────────────────────────
-- REMOTE REGISTRY
-- ───────────────────────────────────────────────
local R = {}

local function findRemote(name)
    -- search RS
    for _, v in ipairs(RS:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
        and v.Name:lower():find(name:lower()) then
            return v
        end
    end
    -- search WS
    for _, v in ipairs(WS:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
        and v.Name:lower():find(name:lower()) then
            return v
        end
    end
    -- search game-wide
    for _, v in ipairs(game:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
        and v.Name:lower():find(name:lower()) then
            return v
        end
    end
    return nil
end

local function bindRemotes()
    R.world   = findRemote(CFG.worldRemote)
    R.break_  = findRemote(CFG.breakRemote)  or R.world
    R.collect = findRemote(CFG.collectRemote) or R.world
    R.plant   = findRemote(CFG.plantRemote)  or R.world
    R.place   = findRemote(CFG.placeRemote)  or R.world
end

bindRemotes()
task.spawn(function()
    while true do task.wait(6) bindRemotes() end
end)

-- spy all remotes to Delta console
local function spyRemotes()
    print("\n===== GROWBLOX REMOTE SPY =====")
    local n = 0
    local seen = {}
    local function scan(obj, d)
        d = d or 0
        if d > 6 then return end
        for _, v in ipairs(obj:GetChildren()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("BindableEvent") then
                local path = v:GetFullName()
                if not seen[path] then
                    seen[path] = true
                    print("[" .. v.ClassName .. "]  " .. path)
                    n = n + 1
                end
            end
            safe(function() scan(v, d+1) end)
        end
    end
    safe(function() scan(RS) end)
    safe(function() scan(WS) end)
    print("===== TOTAL: " .. n .. " =====\n")
end

-- ───────────────────────────────────────────────
-- WORLD HELPERS
-- ───────────────────────────────────────────────
local BPATS = {
    "block","tile","wall","wood","stone","rock","ore",
    "tree","bush","crop","plant","dirt","grass","log",
    "sand","gem","chest","barrel","object","brick"
}
local SPATS = {"soil","dirt","plot","empty","farm","bed","ground","patch"}

local function getNear(pats, range)
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

local function getDrops(range)
    local out = {}
    if not root then return out end
    for _, v in ipairs(WS:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsDescendantOf(char) then
            if (v.Position - root.Position).Magnitude <= range then
                local hasTag = v:FindFirstChildWhichIsA("BillboardGui")
                           or v:FindFirstChildWhichIsA("Highlight")
                local n = v.Name:lower()
                if hasTag or n:find("drop") or n:find("gem") or n:find("seed")
                or n:find("loot") or n:find("fruit") or n:find("item")
                or n:find("pickup") or n:find("coin") then
                    table.insert(out, v)
                end
            end
        end
        -- also check Models with BillboardGui
        if v:IsA("Model") and not v:IsDescendantOf(char) then
            local pp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if pp then
                local dist = (pp.Position - root.Position).Magnitude
                if dist <= range then
                    local hasGui = v:FindFirstChildWhichIsA("BillboardGui")
                               or v:FindFirstChildWhichIsA("Highlight")
                    if hasGui then
                        table.insert(out, v)
                    end
                end
            end
        end
    end
    return out
end

-- get nearest danger tile (lava / spike / etc)
local function getNearestDanger()
    if not root then return nil, math.huge end
    local best, bestDist = nil, math.huge
    for _, v in ipairs(WS:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            local isDanger = false
            for _, dp in ipairs(CFG.dangerTiles) do
                if n:find(dp) then isDanger = true break end
            end
            if isDanger then
                local dist = (v.Position - root.Position).Magnitude
                if dist < bestDist then
                    best = v
                    bestDist = dist
                end
            end
        end
    end
    return best, bestDist
end

-- ───────────────────────────────────────────────
-- ANTI-LAVA / ANTI-SPIKE / ANTI-DANGER
-- Detects danger tiles + server damage events
-- ───────────────────────────────────────────────

-- safe position cache — last known non-danger position
local safePos = nil
local lastSafeSave = 0

-- intercept Humanoid health drop = server tried to damage us
local function hookHealthDrop()
    if not hum then return end
    hum:GetPropertyChangedSignal("Health"):Connect(function()
        if not S.immortal and not S.antiDanger then return end
        if not getChar() then return end
        if hum.Health < hum.MaxHealth * 0.98 then
            -- health dropped — escape
            if safePos and S.antiDanger then
                safe(function()
                    root.CFrame = CFrame.new(safePos + CFG.escapeOffset)
                end)
            end
            if S.immortal then
                safe(function()
                    hum.Health = hum.MaxHealth
                end)
            end
        end
    end)
end

-- main danger check loop
RunService.Heartbeat:Connect(function()
    if not getChar() then return end

    -- save safe position every 2s (not on danger tile)
    local now = tick()
    if (now - lastSafeSave) >= 2 then
        local _, dangerDist = getNearestDanger()
        if dangerDist > CFG.dangerRange then
            safePos = root.Position
        end
        lastSafeSave = now
    end

    -- anti-danger tile teleport
    if S.antiDanger then
        if (now - S.lastDanger) >= 0.3 then
            local dangerTile, dangerDist = getNearestDanger()
            if dangerTile and dangerDist <= CFG.dangerRange then
                S.lastDanger = now
                safe(function()
                    if safePos then
                        root.CFrame = CFrame.new(safePos + CFG.escapeOffset)
                    else
                        -- no safe pos yet — just jump up
                        root.CFrame = root.CFrame + CFG.escapeOffset * 2
                    end
                end)
                -- also restore health
                safe(function()
                    if hum then hum.Health = hum.MaxHealth end
                end)
            end
        end
    end

    -- immortal loop
    if S.immortal then
        if hum and hum.Health < hum.MaxHealth then
            safe(function() hum.Health = hum.MaxHealth end)
        end
    end
end)

-- ───────────────────────────────────────────────
-- NOCLIP
-- ───────────────────────────────────────────────
RunService.Stepped:Connect(function()
    if not S.noclip then return end
    if not getChar() then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

-- ───────────────────────────────────────────────
-- FLY
-- ───────────────────────────────────────────────
local function enableFly()
    if not getChar() then return end
    -- remove gravity via BodyVelocity
    safe(function()
        local existing = root:FindFirstChild("GBFlyVel")
        if existing then existing:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.Name           = "GBFlyVel"
        bv.Velocity       = Vector3.new(0, 0, 0)
        bv.MaxForce       = Vector3.new(0, 1e5, 0)
        bv.Parent         = root
        S.flyBV           = bv
        hum.PlatformStand = false
    end)
end

local function disableFly()
    safe(function()
        local bv = root and root:FindFirstChild("GBFlyVel")
        if bv then bv:Destroy() end
        S.flyBV = nil
        if hum then hum.PlatformStand = false end
    end)
end

RunService.Heartbeat:Connect(function()
    if not S.fly then return end
    if not getChar() then return end
    if not S.flyBV then enableFly() end
    -- keep hover — zero out fall
    safe(function()
        if S.flyBV then
            S.flyBV.Velocity = Vector3.new(
                root.AssemblyLinearVelocity.X,
                0,
                root.AssemblyLinearVelocity.Z
            )
        end
    end)
end)

-- ───────────────────────────────────────────────
-- AUTO TAKE
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoTake then return end
    if not getChar() then return end
    for _, item in ipairs(getDrops(CFG.takeRange)) do
        local pos
        if item:IsA("Model") then
            local pp = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if pp then pos = pp.Position end
        else pos = item.Position end
        if pos then
            safe(function() root.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) end)
            if R.collect then
                safe(function() R.collect:FireServer(item) end)
            elseif R.world then
                safe(function() R.world:FireServer({kind = "collect", target = item}) end)
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
    for _, b in ipairs(getNear(BPATS, CFG.breakRange)) do
        if R.break_ then
            safe(function() R.break_:FireServer(b) end)
        elseif R.world then
            safe(function() R.world:FireServer({kind = "break", target = b}) end)
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
    for _, s in ipairs(getNear(SPATS, CFG.plantRange)) do
        if R.plant then
            safe(function() R.plant:FireServer(s) end)
        elseif R.world then
            safe(function() R.world:FireServer({kind = "plant", target = s}) end)
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
    if R.place then
        safe(function() R.place:FireServer(root.CFrame) end)
    elseif R.world then
        safe(function() R.world:FireServer({kind = "place", cf = root.CFrame}) end)
    end
    task.wait(0.3)
end)

-- ───────────────────────────────────────────────
-- AUTO TELE
-- ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    if not S.autoTele then return end
    if not getChar() then return end
    if not S.telePos then return end
    safe(function() root.CFrame = CFrame.new(S.telePos) end)
end)

-- ───────────────────────────────────────────────
-- AUTO FARM (break + collect loop)
-- ───────────────────────────────────────────────
local function farmCycle()
    if not getChar() then return end
    for _, b in ipairs(getNear(BPATS, CFG.breakRange)) do
        if R.break_ then
            safe(function() R.break_:FireServer(b) end)
        elseif R.world then
            safe(function() R.world:FireServer({kind="break",target=b}) end)
        end
        task.wait(0.08)
    end
    task.wait(0.2)
    for _, item in ipairs(getDrops(CFG.takeRange)) do
        local pos
        if item:IsA("Model") then
            local pp = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
            if pp then pos = pp.Position end
        else pos = item.Position end
        if pos then
            safe(function() root.CFrame = CFrame.new(pos + Vector3.new(0,2.5,0)) end)
            if R.collect then safe(function() R.collect:FireServer(item) end)
            elseif R.world then safe(function() R.world:FireServer({kind="collect",target=item}) end) end
        end
        task.wait(0.06)
    end
    task.wait(0.2)
    if R.plant then
        for _, s in ipairs(getNear(SPATS, CFG.plantRange)) do
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
-- RESPAWN HANDLER
-- ───────────────────────────────────────────────
lp.CharacterAdded:Connect(function(c)
    char = c
    root = c:WaitForChild("HumanoidRootPart")
    hum  = c:WaitForChild("Humanoid")
    task.wait(0.4)
    bindRemotes()
    hookHealthDrop()
    if S.fly then
        task.wait(0.2)
        enableFly()
    end
end)

hookHealthDrop()

-- ───────────────────────────────────────────────
-- GUI — CoreGui first, PlayerGui fallback
-- Button: TOP-RIGHT, below Roblox topbar
-- ───────────────────────────────────────────────
for _, p in ipairs({game.CoreGui, lp.PlayerGui}) do
    safe(function()
        local o = p:FindFirstChild("GrowbloxHub")
        if o then o:Destroy() end
    end)
end

local guiParent = lp.PlayerGui
safe(function()
    local t = Instance.new("ScreenGui")
    t.Name   = "_GBtest"
    t.Parent = game.CoreGui
    t:Destroy()
    guiParent = game.CoreGui
end)

local sg = Instance.new("ScreenGui")
sg.Name           = "GrowbloxHub"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = false
sg.DisplayOrder   = 999
sg.Parent         = guiParent

print("[GB] gui -> " .. guiParent.Name)

-- drag
local function drag(frame, handle)
    handle = handle or frame
    local d, sp, sf = false, nil, nil
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            d = true
            sp = Vector2.new(inp.Position.X, inp.Position.Y)
            sf = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            d = false
        end
    end)
    handle.InputChanged:Connect(function(inp)
        if not d or not sp then return end
        if inp.UserInputType == Enum.UserInputType.Touch
        or inp.UserInputType == Enum.UserInputType.MouseMovement then
            local dv = Vector2.new(inp.Position.X, inp.Position.Y) - sp
            frame.Position = UDim2.new(sf.X.Scale, sf.X.Offset+dv.X, sf.Y.Scale, sf.Y.Offset+dv.Y)
        end
    end)
end

-- open button — top right
local openBtn = Instance.new("TextButton")
openBtn.Size             = UDim2.new(0, 60, 0, 60)
openBtn.Position         = UDim2.new(1, -75, 0, 80)
openBtn.BackgroundColor3 = Color3.fromRGB(22, 185, 85)
openBtn.BorderSizePixel  = 0
openBtn.Text             = "GB"
openBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
openBtn.TextSize         = 18
openBtn.Font             = Enum.Font.GothamBold
openBtn.ZIndex           = 100
openBtn.Active           = true
openBtn.Parent           = sg
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
local openStroke = Instance.new("UIStroke")
openStroke.Color     = Color3.fromRGB(255, 255, 255)
openStroke.Thickness = 2
openStroke.Parent    = openBtn
drag(openBtn)

-- panel glow
local glow = Instance.new("Frame")
glow.Size             = UDim2.new(0, 316, 0, 650)
glow.Position         = UDim2.new(0.5, -158, 0.5, -325)
glow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
glow.BorderSizePixel  = 0
glow.ZIndex           = 98
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

-- main panel
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 312, 0, 646)
panel.Position         = UDim2.new(0.5, -156, 0.5, -323)
panel.BackgroundColor3 = Color3.fromRGB(10, 13, 20)
panel.BorderSizePixel  = 0
panel.ZIndex           = 99
panel.Visible          = false
panel.Active           = true
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 20, 32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 18)),
})
panelGrad.Rotation = 130
panelGrad.Parent   = panel

drag(panel)

openBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
    glow.Visible  = panel.Visible
end)

-- header
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
header.BorderSizePixel  = 0
header.ZIndex           = 100
header.Parent           = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 16)

local hGrad = Instance.new("UIGradient")
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(16, 155, 68)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 95, 44)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(16, 155, 68)),
})
hGrad.Rotation = 90
hGrad.Parent   = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(0.72, 0, 1, 0)
titleLbl.Position               = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "GROWBLOX HUB"
titleLbl.TextColor3             = Color3.fromRGB(215, 255, 215)
titleLbl.TextSize               = 16
titleLbl.Font                   = Enum.Font.GothamBold
titleLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleLbl.ZIndex                 = 101
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
closeBtn.ZIndex           = 102
closeBtn.Parent           = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
    glow.Visible  = false
end)

local subLbl = Instance.new("TextLabel")
subLbl.Size                   = UDim2.new(1, 0, 0, 16)
subLbl.Position               = UDim2.new(0, 0, 0, 52)
subLbl.BackgroundTransparency = 1
subLbl.Text                   = "absolute ollie  built by olivia  discord.gg/ojailbreaks"
subLbl.TextColor3             = Color3.fromRGB(38, 145, 68)
subLbl.TextSize               = 9
subLbl.Font                   = Enum.Font.Gotham
subLbl.ZIndex                 = 100
subLbl.Parent                 = panel

-- spy button
local spyBtn = Instance.new("TextButton")
spyBtn.Size             = UDim2.new(1, -18, 0, 36)
spyBtn.Position         = UDim2.new(0, 9, 0, 72)
spyBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
spyBtn.Text             = "SPY REMOTES  (check Delta console)"
spyBtn.TextColor3       = Color3.fromRGB(255, 210, 55)
spyBtn.TextSize         = 11
spyBtn.Font             = Enum.Font.GothamSemibold
spyBtn.BorderSizePixel  = 0
spyBtn.ZIndex           = 100
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

local remoteLbl = Instance.new("TextLabel")
remoteLbl.Size                   = UDim2.new(1, -18, 0, 16)
remoteLbl.Position               = UDim2.new(0, 9, 0, 112)
remoteLbl.BackgroundTransparency = 1
remoteLbl.Text                   = "remotes: scanning..."
remoteLbl.TextColor3             = Color3.fromRGB(180, 180, 60)
remoteLbl.TextSize               = 10
remoteLbl.Font                   = Enum.Font.Gotham
remoteLbl.TextXAlignment         = Enum.TextXAlignment.Left
remoteLbl.ZIndex                 = 100
remoteLbl.Parent                 = panel

-- scroll
local scroll = Instance.new("ScrollingFrame")
scroll.Size                   = UDim2.new(1, -14, 1, -194)
scroll.Position               = UDim2.new(0, 7, 0, 134)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = Color3.fromRGB(22, 180, 85)
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.ZIndex                 = 100
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

local TI = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- section label
local function makeSection(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "  " .. text
    lbl.TextColor3             = Color3.fromRGB(55, 160, 75)
    lbl.TextSize               = 10
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.LayoutOrder            = order
    lbl.ZIndex                 = 100
    lbl.Parent                 = scroll
end

-- toggle row
local function makeToggle(tag, label, desc, key, order, onCol, onToggle)
    onCol = onCol or Color3.fromRGB(22, 190, 85)

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 62)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 101
    row.Parent           = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

    local rg = Instance.new("UIGradient")
    rg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 23, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 15, 24)),
    })
    rg.Rotation = 90
    rg.Parent   = row

    local acc = Instance.new("Frame")
    acc.Size             = UDim2.new(0, 3, 0.6, 0)
    acc.Position         = UDim2.new(0, 0, 0.2, 0)
    acc.BackgroundColor3 = Color3.fromRGB(48, 52, 72)
    acc.BorderSizePixel  = 0
    acc.ZIndex           = 102
    acc.Parent           = row
    Instance.new("UICorner", acc).CornerRadius = UDim.new(1, 0)

    local bubble = Instance.new("TextLabel")
    bubble.Size             = UDim2.new(0, 36, 0, 36)
    bubble.Position         = UDim2.new(0, 10, 0.5, -18)
    bubble.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bubble.Text             = tag
    bubble.TextSize         = 11
    bubble.Font             = Enum.Font.GothamBold
    bubble.TextColor3       = Color3.fromRGB(200, 220, 200)
    bubble.BorderSizePixel  = 0
    bubble.ZIndex           = 102
    bubble.Parent           = row
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 9)
    local bg2 = Instance.new("UIGradient")
    bg2.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 26, 42)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 17, 28)),
    })
    bg2.Rotation = 90
    bg2.Parent   = bubble

    local mainL = Instance.new("TextLabel")
    mainL.Size                   = UDim2.new(0.57, 0, 0, 20)
    mainL.Position               = UDim2.new(0, 54, 0, 10)
    mainL.BackgroundTransparency = 1
    mainL.Text                   = label
    mainL.TextColor3             = Color3.fromRGB(225, 242, 225)
    mainL.TextSize               = 13
    mainL.Font                   = Enum.Font.GothamBold
    mainL.TextXAlignment         = Enum.TextXAlignment.Left
    mainL.ZIndex                 = 102
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
    descL.ZIndex                 = 102
    descL.Parent                 = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, 50, 0, 26)
    track.Position         = UDim2.new(1, -58, 0.5, -13)
    track.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
    track.BorderSizePixel  = 0
    track.ZIndex           = 102
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 20, 0, 20)
    dot.Position         = UDim2.new(0, 3, 0.5, -10)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 103
    dot.Parent           = track
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size                   = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                   = ""
    btn.ZIndex                 = 104
    btn.Parent                 = row

    local function refresh()
        local on = S[key]
        TweenService:Create(track, TI, {
            BackgroundColor3 = on and onCol or Color3.fromRGB(36, 42, 58)
        }):Play()
        TweenService:Create(dot, TI, {
            Position = on and UDim2.new(0,27,0.5,-10) or UDim2.new(0,3,0.5,-10)
        }):Play()
        acc.BackgroundColor3 = on and onCol or Color3.fromRGB(48, 52, 72)
    end
    refresh()

    btn.MouseButton1Click:Connect(function()
        S[key] = not S[key]
        refresh()
        if onToggle then onToggle(S[key]) end
    end)
end

-- tele row (special)
local function makeTeleRow(order)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 72)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = order
    row.ZIndex           = 101
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
    acc.ZIndex           = 102
    acc.Parent           = row
    Instance.new("UICorner", acc).CornerRadius = UDim.new(1, 0)

    local bubble = Instance.new("TextLabel")
    bubble.Size             = UDim2.new(0, 36, 0, 36)
    bubble.Position         = UDim2.new(0, 10, 0.5, -18)
    bubble.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bubble.Text             = "TP"
    bubble.TextSize         = 11
    bubble.Font             = Enum.Font.GothamBold
    bubble.TextColor3       = Color3.fromRGB(160, 195, 255)
    bubble.BorderSizePixel  = 0
    bubble.ZIndex           = 102
    bubble.Parent           = row
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 9)

    local mainL = Instance.new("TextLabel")
    mainL.Size                   = UDim2.new(0.42, 0, 0, 20)
    mainL.Position               = UDim2.new(0, 54, 0, 6)
    mainL.BackgroundTransparency = 1
    mainL.Text                   = "Teleport"
    mainL.TextColor3             = Color3.fromRGB(160, 195, 255)
    mainL.TextSize               = 13
    mainL.Font                   = Enum.Font.GothamBold
    mainL.TextXAlignment         = Enum.TextXAlignment.Left
    mainL.ZIndex                 = 102
    mainL.Parent                 = row

    local coordL = Instance.new("TextLabel")
    coordL.Size                   = UDim2.new(0.52, 0, 0, 14)
    coordL.Position               = UDim2.new(0, 54, 0, 28)
    coordL.BackgroundTransparency = 1
    coordL.Text                   = "tap Set to lock coords"
    coordL.TextColor3             = Color3.fromRGB(70, 100, 155)
    coordL.TextSize               = 9
    coordL.Font                   = Enum.Font.Gotham
    coordL.TextXAlignment         = Enum.TextXAlignment.Left
    coordL.ZIndex                 = 102
    coordL.Parent                 = row

    -- Set + Go buttons
    local setBtn = Instance.new("TextButton")
    setBtn.Size             = UDim2.new(0, 44, 0, 24)
    setBtn.Position         = UDim2.new(0, 54, 0, 44)
    setBtn.BackgroundColor3 = Color3.fromRGB(45, 85, 195)
    setBtn.Text             = "Set"
    setBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    setBtn.TextSize         = 11
    setBtn.Font             = Enum.Font.GothamSemibold
    setBtn.BorderSizePixel  = 0
    setBtn.ZIndex           = 103
    setBtn.Parent           = row
    Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 7)

    local goBtn = Instance.new("TextButton")
    goBtn.Size             = UDim2.new(0, 44, 0, 24)
    goBtn.Position         = UDim2.new(0, 102, 0, 44)
    goBtn.BackgroundColor3 = Color3.fromRGB(22, 180, 85)
    goBtn.Text             = "Go"
    goBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    goBtn.TextSize         = 11
    goBtn.Font             = Enum.Font.GothamSemibold
    goBtn.BorderSizePixel  = 0
    goBtn.ZIndex           = 103
    goBtn.Parent           = row
    Instance.new("UICorner", goBtn).CornerRadius = UDim.new(0, 7)

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(0, 50, 0, 26)
    track.Position         = UDim2.new(1, -58, 0.5, -13)
    track.BackgroundColor3 = Color3.fromRGB(36, 42, 58)
    track.BorderSizePixel  = 0
    track.ZIndex           = 102
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 20, 0, 20)
    dot.Position         = UDim2.new(0, 3, 0.5, -10)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 103
    dot.Parent           = track
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size                   = UDim2.new(0, 50, 0, 26)
    toggleBtn.Position               = UDim2.new(1, -58, 0.5, -13)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text                   = ""
    toggleBtn.ZIndex                 = 105
    toggleBtn.Parent                 = row

    local teleOnCol = Color3.fromRGB(80, 125, 255)
    local function refreshTele()
        local on = S.autoTele
        TweenService:Create(track, TI, {
            BackgroundColor3 = on and teleOnCol or Color3.fromRGB(36, 42, 58)
        }):Play()
        TweenService:Create(dot, TI, {
            Position = on and UDim2.new(0,27,0.5,-10) or UDim2.new(0,3,0.5,-10)
        }):Play()
        acc.BackgroundColor3 = on and teleOnCol or Color3.fromRGB(48, 52, 72)
    end

    setBtn.MouseButton1Click:Connect(function()
        if getChar() then
            S.telePos   = root.Position
            coordL.Text = string.format("X%.0f Y%.0f Z%.0f",
                root.Position.X, root.Position.Y, root.Position.Z)
            setBtn.BackgroundColor3 = Color3.fromRGB(22, 175, 80)
            task.delay(0.6, function() setBtn.BackgroundColor3 = Color3.fromRGB(45, 85, 195) end)
        end
    end)

    goBtn.MouseButton1Click:Connect(function()
        if getChar() and S.telePos then
            safe(function() root.CFrame = CFrame.new(S.telePos) end)
            goBtn.BackgroundColor3 = Color3.fromRGB(180, 220, 60)
            task.delay(0.4, function() goBtn.BackgroundColor3 = Color3.fromRGB(22, 180, 85) end)
        end
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        S.autoTele = not S.autoTele
        refreshTele()
    end)
    refreshTele()
end

-- build all rows
makeSection("PROTECTION", 1)
makeToggle("AD", "Anti-Lava/Spike", "Auto-escape danger tiles",   "antiDanger", 2,  Color3.fromRGB(230, 90,  40))
makeToggle("HP", "Immortal",        "Lock health at max",          "immortal",   3,  Color3.fromRGB(220, 60,  60))
makeSection("MOVEMENT", 4)
makeToggle("NC", "Noclip",          "Walk through everything",     "noclip",     5,  Color3.fromRGB(230, 95,  45))
makeToggle("FY", "Fly",             "Float / no fall damage",      "fly",        6,  Color3.fromRGB(80, 160,  240),
    function(on)
        if on then enableFly() else disableFly() end
    end
)
makeTeleRow(7)
makeSection("FARMING", 8)
makeToggle("TK", "Auto Take",       "Collect nearby drops",        "autoTake",   9,  Color3.fromRGB(22,  195, 85))
makeToggle("BK", "Auto Break",      "Break nearby blocks",         "autoBreak",  10, Color3.fromRGB(220, 75,  55))
makeToggle("PL", "Auto Plant",      "Plant on empty soil",         "autoPlant",  11, Color3.fromRGB(75,  205, 75))
makeToggle("PT", "Auto Put",        "Place block at your spot",    "autoPut",    12, Color3.fromRGB(75,  155, 230))
makeToggle("FM", "Auto Farm",       "Full break+collect+plant",    "autoFarm",   13, Color3.fromRGB(220, 175, 38))

-- status bar
local sBar = Instance.new("Frame")
sBar.Size             = UDim2.new(1, 0, 0, 30)
sBar.Position         = UDim2.new(0, 0, 1, -30)
sBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sBar.BorderSizePixel  = 0
sBar.ZIndex           = 100
sBar.Parent           = panel
Instance.new("UICorner", sBar).CornerRadius = UDim.new(0, 16)
local sbG = Instance.new("UIGradient")
sbG.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(9, 68, 32)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(13, 90, 44)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(9, 68, 32)),
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
sLbl.ZIndex                 = 101
sLbl.Parent                 = sBar

-- ticker
task.spawn(function()
    while true do
        task.wait(0.8)
        local rc = 0
        for _ in pairs(R) do rc = rc + 1 end
        if rc > 0 then
            remoteLbl.Text       = "remotes: " .. rc .. " locked  OK"
            remoteLbl.TextColor3 = Color3.fromRGB(55, 200, 95)
        else
            remoteLbl.Text       = "no remotes — tap SPY first"
            remoteLbl.TextColor3 = Color3.fromRGB(220, 155, 45)
        end
        local a = {}
        if S.antiDanger then table.insert(a, "AD") end
        if S.immortal   then table.insert(a, "HP") end
        if S.noclip     then table.insert(a, "NC") end
        if S.fly        then table.insert(a, "FY") end
        if S.autoTake   then table.insert(a, "TK") end
        if S.autoBreak  then table.insert(a, "BK") end
        if S.autoPlant  then table.insert(a, "PL") end
        if S.autoPut    then table.insert(a, "PT") end
        if S.autoFarm   then table.insert(a, "FM") end
        if S.autoTele   then table.insert(a, "TP") end
        sLbl.Text       = #a > 0 and ("on: "..table.concat(a," ")) or "all off"
        sLbl.TextColor3 = #a > 0
            and Color3.fromRGB(55, 195, 95)
            or  Color3.fromRGB(85, 95, 115)
    end
end)

-- auto spy + bind on load
task.spawn(function()
    task.wait(2.5)
    spyRemotes()
    bindRemotes()
end)

print("[GB] loaded -- anti-lava, anti-spike, tele, farm -- discord.gg/ojailbreaks")
