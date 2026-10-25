-- SYI HUB — lightweight mobile-friendly GUI template
-- UI-only starter for your own Roblox experience.
-- This template does not spoof devices, hook Roblox internals, or automate gameplay.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("SyiHubUI")
if oldGui then
    oldGui:Destroy()
end

local COLORS = {
    Background = Color3.fromRGB(18, 18, 24),
    Panel = Color3.fromRGB(27, 27, 36),
    Panel2 = Color3.fromRGB(36, 36, 47),
    Accent = Color3.fromRGB(255, 105, 180),
    Text = Color3.fromRGB(245, 245, 250),
    Muted = Color3.fromRGB(165, 165, 180),
    Off = Color3.fromRGB(70, 70, 84),
}

local function corner(instance, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 12)
    c.Parent = instance
    return c
end

local function stroke(instance, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or COLORS.Accent
    s.Transparency = transparency or 0.5
    s.Thickness = 1
    s.Parent = instance
    return s
end

local function tween(instance, duration, properties)
    local info = TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local t = TweenService:Create(instance, info, properties)
    t:Play()
    return t
end

local gui = Instance.new("ScreenGui")
gui.Name = "SyiHubUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local scale = Instance.new("UIScale")
scale.Scale = 1
scale.Parent = gui

local root = Instance.new("Frame")
root.Name = "Window"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.new(0.88, 0, 0, 390)
root.BackgroundColor3 = COLORS.Background
root.BorderSizePixel = 0
root.Parent = gui
corner(root, 16)
stroke(root, COLORS.Accent, 0.35)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(280, 320)
sizeConstraint.MaxSize = Vector2.new(440, 520)
sizeConstraint.Parent = root

local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, 0, 0, 58)
top.BackgroundColor3 = COLORS.Panel
top.BorderSizePixel = 0
top.Parent = root
corner(top, 16)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 18, 0, 7)
title.Size = UDim2.new(1, -76, 0, 25)
title.Font = Enum.Font.GothamBold
title.Text = "SYI HUB"
title.TextSize = 20
title.TextColor3 = COLORS.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = top

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 19, 0, 31)
subtitle.Size = UDim2.new(1, -80, 0, 17)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Clean • Lightweight • Mobile ready"
subtitle.TextSize = 10
subtitle.TextColor3 = COLORS.Muted
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = top

local minimize = Instance.new("TextButton")
minimize.Name = "Minimize"
minimize.AnchorPoint = Vector2.new(1, 0.5)
minimize.Position = UDim2.new(1, -13, 0.5, 0)
minimize.Size = UDim2.fromOffset(34, 34)
minimize.BackgroundColor3 = COLORS.Panel2
minimize.BorderSizePixel = 0
minimize.Text = "—"
minimize.TextColor3 = COLORS.Text
minimize.TextSize = 18
minimize.Font = Enum.Font.GothamBold
minimize.AutoButtonColor = false
minimize.Parent = top
corner(minimize, 10)

local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.new(0, 12, 0, 70)
body.Size = UDim2.new(1, -24, 1, -82)
body.BackgroundTransparency = 1
body.Parent = root

local nav = Instance.new("Frame")
nav.Size = UDim2.new(1, 0, 0, 38)
nav.BackgroundTransparency = 1
nav.Parent = body

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.Padding = UDim.new(0, 8)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = nav

local content = Instance.new("ScrollingFrame")
content.Name = "Content"
content.Position = UDim2.new(0, 0, 0, 48)
content.Size = UDim2.new(1, 0, 1, -48)
content.BackgroundColor3 = COLORS.Panel
content.BorderSizePixel = 0
content.ScrollBarThickness = 3
content.ScrollBarImageColor3 = COLORS.Accent
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = body
corner(content, 12)

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = content

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 9)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = content

local function clearContent()
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") and child ~= padding and child ~= list then
            child:Destroy()
        end
    end
end

local function addInfoCard(heading, description)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 76)
    card.BackgroundColor3 = COLORS.Panel2
    card.BorderSizePixel = 0
    card.Parent = content
    corner(card, 10)

    local h = Instance.new("TextLabel")
    h.BackgroundTransparency = 1
    h.Position = UDim2.new(0, 12, 0, 10)
    h.Size = UDim2.new(1, -24, 0, 20)
    h.Font = Enum.Font.GothamSemibold
    h.Text = heading
    h.TextSize = 13
    h.TextColor3 = COLORS.Text
    h.TextXAlignment = Enum.TextXAlignment.Left
    h.Parent = card

    local d = Instance.new("TextLabel")
    d.BackgroundTransparency = 1
    d.Position = UDim2.new(0, 12, 0, 32)
    d.Size = UDim2.new(1, -24, 0, 32)
    d.Font = Enum.Font.Gotham
    d.Text = description
    d.TextSize = 11
    d.TextColor3 = COLORS.Muted
    d.TextWrapped = true
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.TextYAlignment = Enum.TextYAlignment.Top
    d.Parent = card
end

local function addToggle(labelText, defaultValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = COLORS.Panel2
    row.BorderSizePixel = 0
    row.Parent = content
    corner(row, 10)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -82, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = labelText
    label.TextSize = 12
    label.TextColor3 = COLORS.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -12, 0.5, 0)
    track.Size = UDim2.fromOffset(46, 26)
    track.BackgroundColor3 = defaultValue and COLORS.Accent or COLORS.Off
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    corner(track, 13)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(20, 20)
    knob.Position = defaultValue and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 10)

    local enabled = defaultValue
    track.Activated:Connect(function()
        enabled = not enabled
        tween(track, 0.16, {BackgroundColor3 = enabled and COLORS.Accent or COLORS.Off})
        tween(knob, 0.16, {
            Position = enabled and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        })
        if callback then
            task.spawn(function()
                local ok, err = pcall(callback, enabled)
                if not ok then warn("[Syi Hub] Toggle callback error:", err) end
            end)
        end
    end)
end

local pages = {}

local function showPage(pageName)
    clearContent()
    if pageName == "Home" then
        addInfoCard("Welcome to Syi Hub", "A refreshed, responsive interface designed to stay lightweight on mobile.")
        addInfoCard("Performance", "Uses short tweens, a single scrolling content area, and avoids continuous render loops.")
        addInfoCard("Tip", "Connect your own safe settings to the toggle callbacks below.")
    elseif pageName == "Settings" then
        addInfoCard("Interface", "Customize your own experience using these example settings.")
        addToggle("Example setting", false, function(value)
            print("Example setting:", value)
        end)
        addToggle("Example notification", true, function(value)
            print("Example notification:", value)
        end)
    elseif pageName == "About" then
        addInfoCard("SYI HUB", "UI template • Dark theme • Pink accent")
        addInfoCard("Compatibility", "Made as a LocalScript UI template for experiences you own or are authorized to develop.")
    end
end

local selectedTab
for index, pageName in ipairs({"Home", "Settings", "About"}) do
    local button = Instance.new("TextButton")
    button.Name = pageName .. "Tab"
    button.Size = UDim2.new(1/3, -6, 1, 0)
    button.BackgroundColor3 = pageName == "Home" and COLORS.Accent or COLORS.Panel
    button.BorderSizePixel = 0
    button.Text = pageName
    button.TextColor3 = COLORS.Text
    button.TextSize = 11
    button.Font = Enum.Font.GothamSemibold
    button.AutoButtonColor = false
    button.LayoutOrder = index
    button.Parent = nav
    corner(button, 10)

    button.Activated:Connect(function()
        selectedTab = pageName
        for _, other in ipairs(nav:GetChildren()) do
            if other:IsA("TextButton") then
                tween(other, 0.14, {
                    BackgroundColor3 = other == button and COLORS.Accent or COLORS.Panel
                })
            end
        end
        showPage(pageName)
    end)
end

showPage("Home")

local minimized = false
minimize.Activated:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    tween(root, 0.18, {
        Size = minimized and UDim2.new(0.78, 0, 0, 58) or UDim2.new(0.88, 0, 0, 390)
    })
    minimize.Text = minimized and "+" or "—"
end)

-- Drag support for mouse and touch.
local dragging = false
local dragStart
local startPosition
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = root.Position
    end
end)

top.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Keep the interface comfortable on smaller phone screens.
local function updateScale()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    scale.Scale = math.clamp(math.min(viewport.X / 390, viewport.Y / 700), 0.78, 1)
end

updateScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
