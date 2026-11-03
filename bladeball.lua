--[[
    Blade Ball | OP Build | absolute ollie built by olivia
    discord.gg/ojailbreaks
    Works on: Synapse X, KRNL, Fluxus, Solara, Electron
]]--

-- Services
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Refs
local lp   = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local root, hum

-- Config
local CFG = {
    PARRY_BASE   = 0.015,
    PARRY_SPREAD = 0.010,
    REACT_BASE   = 0.005,
    REACT_SPREAD = 0.003,
    PARRY_RANGE  = 85,
}

-- State
local state = {
    autoParry  = true,
    immortal   = true,
    lastParry  = 0,
    metaHooked = false,
    parryCount = 0,
}

-- Utility
local function jitter(base, spread)
    return base + (math.random() * spread * 2 - spread)
end

local function safeCall(fn, ...)
    local ok = pcall(fn, ...)
    return ok
end

local function getRefs()
    char = lp.Character
    if not char then return false end
    root = char:FindFirstChild("HumanoidRootPart")
    hum  = char:FindFirstChild("Humanoid")
    return root ~= nil and hum ~= nil and hum.Health > 0
end

-- Remote Hunt
local parryRemote

local function huntRemote()
    local patterns = {
        "parry", "Parry", "PARRY",
        "block", "Block", "deflect",
        "swing", "hit", "reflect", "skill"
    }

    for _, pat in ipairs(patterns) do
        local r = ReplicatedStorage:FindFirstChild(pat, true)
        if r and r:IsA("RemoteEvent") then
            parryRemote = r
            return
        end
    end

    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local low = v.Name:lower()
            for _, pat in ipairs(patterns) do
                if low:find(pat:lower()) then
                    parryRemote = v
                    return
                end
            end
        end
    end

    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            local low = v.Name:lower()
            if low:find("parry") or low:find("block") or low:find("deflect") then
                parryRemote = v
                return
            end
        end
    end
end

huntRemote()

task.spawn(function()
    while true do
        task.wait(8)
        if not parryRemote then huntRemote() end
    end
end)

-- Immortal
local function setMaxHealth()
    safeCall(function()
        if not hum then return end
        hum.MaxHealth = math.huge
        hum.Health    = math.huge
    end)
    safeCall(function()
        if hum and (hum.MaxHealth ~= hum.MaxHealth or hum.MaxHealth < 1e9) then
            hum.MaxHealth = 1e9
            hum.Health    = 1e9
        end
    end)
end

local function hookImmortal()
    if not hum or state.metaHooked then return end
    if not hookmetamethod then return end
    safeCall(function()
        local oldNI = getrawmetatable(hum).__newindex
        hookmetamethod(hum, "__newindex", function(self, key, value)
            if self == hum and key == "Health" and state.immortal then
                rawset(self, key, self.MaxHealth)
                return
            end
            return pcall(oldNI, self, key, value)
        end)
        state.metaHooked = true
    end)
end

-- Immortal heartbeat fallback
RunService.Heartbeat:Connect(function()
    if not state.immortal then return end
    if not getRefs() then return end
    if hum.Health < hum.MaxHealth then
        task.delay(jitter(0, 0.008), function()
            if hum and state.immortal then
                safeCall(function()
                    hum.Health = hum.MaxHealth
                end)
            end
        end)
    end
end)

-- Blade Detection
local function getNearestThreat()
    local closest, closestDist = nil, math.huge
    if not root then return nil, math.huge end

    local function checkObj(obj)
        if not (obj:IsA("BasePart") or obj:IsA("MeshPart")) then return end
        local n = obj.Name:lower()
        if not (
            n:find("ball")  or n:find("blade") or
            n:find("orb")   or n:find("proj")  or
            n:find("skill")
        ) then return end
        local dist = (obj.Position - root.Position).Magnitude
        if dist >= closestDist then return end
        local toPlayer = (root.Position - obj.Position).Unit
        local vel      = obj.AssemblyLinearVelocity
        local incoming = vel.Magnitude < 1 or vel.Unit:Dot(toPlayer) > 0.25
        if incoming then
            closest     = obj
            closestDist = dist
        end
    end

    local function recurse(parent)
        for _, v in ipairs(parent:GetChildren()) do
            checkObj(v)
            if v:IsA("Folder") or v:IsA("Model") then
                recurse(v)
            end
        end
    end

    recurse(workspace)
    return closest, closestDist
end

-- Auto Parry
local function fireParry()
    if not parryRemote then return end
    safeCall(function() parryRemote:FireServer() end)
    state.parryCount = state.parryCount + 1
end

RunService.Heartbeat:Connect(function()
    if not state.autoParry or not parryRemote then return end
    if not getRefs() then return end
    local blade, dist = getNearestThreat()
    local now         = tick()
    local cooldown    = jitter(CFG.PARRY_BASE, CFG.PARRY_SPREAD)
    if blade and dist <= CFG.PARRY_RANGE and (now - state.lastParry) >= cooldown then
        state.lastParry = now
        task.delay(jitter(CFG.REACT_BASE, CFG.REACT_SPREAD), function()
            if state.autoParry then fireParry() end
        end)
    end
end)

-- Anti-Kick
safeCall(function()
    if not hookmetamethod then return end
    hookmetamethod(lp, "__namecall", function(self, ...)
        local method = getnamecallmethod and getnamecallmethod() or ""
        if self == lp and method:lower() == "kick" then return end
        return (getrawmetatable(lp).__namecall)(self, ...)
    end)
end)

-- Respawn Handler
lp.CharacterAdded:Connect(function(newChar)
    char = newChar
    root = newChar:WaitForChild("HumanoidRootPart")
    hum  = newChar:WaitForChild("Humanoid")
    task.wait(0.3)
    setMaxHealth()
    state.metaHooked = false
    hookImmortal()
    if not parryRemote then huntRemote() end
end)

-- Init
setMaxHealth()
hookImmortal()

-- GUI Parent — gethui() first, CoreGui fallback
local guiParent = (gethui and gethui()) or game.CoreGui

safeCall(function()
    local old = guiParent:FindFirstChild("OllieHub")
    if old then old:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name           = "OllieHub"
sg.ResetOnSpawn   = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent         = guiParent

-- Glow border frame
local glowFrame = Instance.new("Frame")
glowFrame.Size            = UDim2.new(0, 244, 0, 224)
glowFrame.Position        = UDim2.new(0.5, -122, 0.02, -2)
glowFrame.BorderSizePixel = 0
glowFrame.Parent          = sg
Instance.new("UICorner", glowFrame).CornerRadius = UDim.new(0, 13)

local glowGrad = Instance.new("UIGradient")
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(140, 60, 255)),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(80,  30, 180)),
    ColorSequenceKeypoint.new(0.65, Color3.fromRGB(80,  30, 180)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(140, 60, 255)),
})
glowGrad.Rotation = 135
glowGrad.Parent   = glowFrame

-- Main Frame
local frame = Instance.new("Frame")
frame.Size             = UDim2.new(0, 240, 0, 220)
frame.Position         = UDim2.new(0.5, -120, 0.02, 0)
frame.BackgroundColor3 = Color3.fromRGB(8, 8, 16)
frame.BorderSizePixel  = 0
frame.Active           = true
frame.Draggable        = true
frame.Parent           = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

-- Header
local header = Instance.new("Frame")
header.Size            = UDim2.new(1, 0, 0, 48)
header.Position        = UDim2.new(0, 0, 0, 0)
header.BorderSizePixel = 0
header.Parent          = frame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(60,  20, 120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 40, 200)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(60,  20, 120)),
})
headerGrad.Rotation = 90
headerGrad.Parent   = header

local htitle = Instance.new("TextLabel")
htitle.Size                   = UDim2.new(1, 0, 1, 0)
htitle.BackgroundTransparency = 1
htitle.Text                   = "BLADE BALL  |  OLLIE"
htitle.TextColor3             = Color3.fromRGB(220, 180, 255)
htitle.TextSize               = 14
htitle.Font                   = Enum.Font.GothamBold
htitle.Parent                 = header

-- Subtitle bar
local subBar = Instance.new("Frame")
subBar.Size            = UDim2.new(1, 0, 0, 18)
subBar.Position        = UDim2.new(0, 0, 0, 48)
subBar.BorderSizePixel = 0
subBar.Parent          = frame

local subGrad = Instance.new("UIGradient")
subGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(25, 12, 55)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 20, 90)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(25, 12, 55)),
})
subGrad.Rotation = 90
subGrad.Parent   = subBar

local sub = Instance.new("TextLabel")
sub.Size                   = UDim2.new(1, 0, 1, 0)
sub.BackgroundTransparency = 1
sub.Text                   = "absolute ollie  built by olivia  discord.gg/ojailbreaks"
sub.TextColor3             = Color3.fromRGB(130, 90, 200)
sub.TextSize               = 9
sub.Font                   = Enum.Font.Gotham
sub.Parent                 = subBar

-- Toggle Factory
local function makeToggle(label, yOff, key)
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -20, 0, 40)
    btn.Position         = UDim2.new(0, 10, 0, yOff)
    btn.BorderSizePixel  = 0
    btn.Text             = ""
    btn.Parent           = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)

    local btnGrad = Instance.new("UIGradient")
    btnGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 12, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 16, 70)),
    })
    btnGrad.Rotation = 90
    btnGrad.Parent   = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(0.72, 0, 1, 0)
    lbl.Position               = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = label
    lbl.TextColor3             = Color3.fromRGB(220, 205, 255)
    lbl.TextSize               = 13
    lbl.Font                   = Enum.Font.GothamSemibold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Parent                 = btn

    local track = Instance.new("Frame")
    track.Size            = UDim2.new(0, 44, 0, 22)
    track.Position        = UDim2.new(1, -54, 0.5, -11)
    track.BorderSizePixel = 0
    track.Parent          = btn
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 18, 0, 18)
    dot.Position         = UDim2.new(0, 2, 0.5, -9)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel  = 0
    dot.Parent           = track
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function refresh()
        local on = state[key]
        TweenService:Create(track, ti, {
            BackgroundColor3 = on
                and Color3.fromRGB(120, 55, 240)
                or  Color3.fromRGB(38,  28, 65)
        }):Play()
        TweenService:Create(dot, ti, {
            Position = on
                and UDim2.new(0, 24, 0.5, -9)
                or  UDim2.new(0, 2,  0.5, -9)
        }):Play()
    end

    refresh()
    btn.MouseButton1Click:Connect(function()
        state[key] = not state[key]
        if key == "immortal" and state.immortal then setMaxHealth() end
        refresh()
    end)
end

makeToggle("Auto Parry  [15ms / bypass]", 70,  "autoParry")
makeToggle("Immortal  [meta-locked]",     120, "immortal")

-- Status line
local statusLine = Instance.new("TextLabel")
statusLine.Size                   = UDim2.new(1, -20, 0, 16)
statusLine.Position               = UDim2.new(0, 10, 0, 172)
statusLine.BackgroundTransparency = 1
statusLine.Text                   = "remote: scanning..."
statusLine.TextColor3             = Color3.fromRGB(90, 60, 150)
statusLine.TextSize               = 10
statusLine.Font                   = Enum.Font.Gotham
statusLine.TextXAlignment         = Enum.TextXAlignment.Left
statusLine.Parent                 = frame

-- Parry counter
local parryLabel = Instance.new("TextLabel")
parryLabel.Size                   = UDim2.new(1, -20, 0, 16)
parryLabel.Position               = UDim2.new(0, 10, 0, 190)
parryLabel.BackgroundTransparency = 1
parryLabel.Text                   = "parries: 0"
parryLabel.TextColor3             = Color3.fromRGB(90, 60, 150)
parryLabel.TextSize               = 10
parryLabel.Font                   = Enum.Font.Gotham
parryLabel.TextXAlignment         = Enum.TextXAlignment.Left
parryLabel.Parent                 = frame

-- Ticker
task.spawn(function()
    while true do
        task.wait(0.5)
        parryLabel.Text = "parries: " .. tostring(state.parryCount)
        if parryRemote then
            statusLine.Text       = "remote: " .. parryRemote.Name .. "  [OK]"
            statusLine.TextColor3 = Color3.fromRGB(90, 210, 120)
        else
            statusLine.Text       = "remote: hunting..."
            statusLine.TextColor3 = Color3.fromRGB(210, 95, 55)
        end
    end
end)

print("[ollie] loaded — discord.gg/ojailbreaks")
