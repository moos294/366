local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
    Action = "PushUp", Interval = 0.1, AutoStart = false,
    AutoRebirth = false, AutoRebirthDelay = 3, AntiAfk = true,
    AutoReset = false, AutoResetInterval = 300, SaveSettings = true,
    Notifications = true, TotalReps = 0,
    Fly = false, FlySpeed = 50, WalkSpeed = 16,
    AutoRebirthCount = 0, AutoRebirthDone = 0,
    DataPanelOpen = false,
    FastMode = false,
    HideFloatingText = false,
    HidePets = false,
    UseAllActions = false,
    MaxActionsPerRound = 5,
    TargetRebirthCount = 5,
    StopAtTargetRebirth = false,
}

local Actions = { "PushUp", "SitUp", "PullUp", "Squat" }
local ActionNames = { PushUp = "俯卧撑", SitUp = "仰卧起坐", PullUp = "引体向上", Squat = "深蹲" }

local ALL_ACTIONS = {
    "PushUp", "Dumbbell", "ShoulderPress_1", "TrendMill_1", "FlatBench_1",
    "Rock_1", "Rock_2", "Rock_3", "BarbellRack_L1", "BenchPress_L1",
    "Red slime", "FlatBench_L1", "BarbellRack_S1", "BarbellRack_1",
    "BarbellRack_2", "BenchPress_1", "BenchPress_2", "ShoulderPress_2",
    "ShoulderPress_3", "SkySlime", "FlatBench_K1"
}

local CONFIG_FILE = "CrownStrength_config.json"
local MIN_INTERVAL, MAX_INTERVAL = 0.08, 10
local IS_TOUCH = UserInputService.TouchEnabled
local REBIRTH_TIMEOUT = 15
local MIN_LOOP_WAIT = 0.05

local function safeWait(t)
    task.wait(math.max(MIN_LOOP_WAIT, tonumber(t) or MIN_LOOP_WAIT))
end

local function getCurrentStrength()
    local str = 0
    pcall(function()
        local attr = LocalPlayer:GetAttribute("Strength")
        if attr then str = attr; return end
        if LocalPlayer.leaderstats then
            local ls = LocalPlayer.leaderstats
            if ls:FindFirstChild("Strength") then str = ls.Strength.Value; return end
            if ls:FindFirstChild("Power") then str = ls.Power.Value; return end
        end
        if LocalPlayer:FindFirstChild("Strength") then str = LocalPlayer.Strength.Value end
    end)
    return str
end

local function getCurrentRebirths()
    local count = 0
    pcall(function()
        local attr = LocalPlayer:GetAttribute("Rebirths")
            or LocalPlayer:GetAttribute("Rebirth")
            or LocalPlayer:GetAttribute("RebirthCount")
        if attr then count = attr; return end

        if LocalPlayer.leaderstats then
            local ls = LocalPlayer.leaderstats
            local names = {"Rebirths", "Rebirth", "RebirthCount", "Prestige", "Reborn"}
            for _, n in ipairs(names) do
                if ls:FindFirstChild(n) and (ls[n]:IsA("IntValue") or ls[n]:IsA("NumberValue")) then
                    count = ls[n].Value
                    return
                end
            end
        end

        local names = {"Rebirths", "Rebirth", "RebirthCount"}
        for _, n in ipairs(names) do
            if LocalPlayer:FindFirstChild(n) and (LocalPlayer[n]:IsA("IntValue") or LocalPlayer[n]:IsA("NumberValue")) then
                count = LocalPlayer[n].Value
                return
            end
        end
    end)
    return count
end

local function findRemote(name, alt)
    local list = { ReplicatedStorage }
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    if folder then table.insert(list, folder) end
    for _, p in ipairs(list) do
        local r = p:FindFirstChild(name) or (alt and p:FindFirstChild(alt))
        if r then return r end
    end
end

local TrainEvent = findRemote("TrainEvent", "Train")
local RebirthEvent = findRemote("RebirthEvent", "Rebirth")

local function saveConfig()
    if not Config.SaveSettings or type(writefile) ~= "function" then return end
    pcall(function()
        local d = {}
        for k, v in pairs(Config) do
            if type(v) ~= "table" and type(v) ~= "function" then d[k] = v end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(d))
    end)
end

local function loadConfig()
    if not Config.SaveSettings or type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(CONFIG_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if Config[k] ~= nil and type(Config[k]) == type(v) then Config[k] = v end
        end
    end
end
loadConfig()

local T = {
    BgDeep   = Color3.fromRGB(4, 7, 12),
    BgPanel  = Color3.fromRGB(10, 16, 24),
    BgPanel2 = Color3.fromRGB(16, 24, 36),
    BgPanelHi= Color3.fromRGB(24, 36, 52),
    Grid     = Color3.fromRGB(30, 50, 80),
    Stroke   = Color3.fromRGB(40, 70, 110),
    Neon     = Color3.fromRGB(0, 229, 255),
    Neon2    = Color3.fromRGB(255, 60, 180),
    NeonDim  = Color3.fromRGB(0, 130, 170),
    Green    = Color3.fromRGB(0, 255, 160),
    GreenDim = Color3.fromRGB(0, 160, 100),
    Red      = Color3.fromRGB(255, 60, 90),
    RedDim   = Color3.fromRGB(180, 30, 60),
    Yellow   = Color3.fromRGB(255, 220, 80),
    Purple   = Color3.fromRGB(180, 120, 255),
    Text     = Color3.fromRGB(220, 235, 255),
    TextDim  = Color3.fromRGB(110, 140, 180),
    TextSub  = Color3.fromRGB(70, 95, 130),
    F  = Enum.Font.GothamMedium,
    FB = Enum.Font.GothamBold,
    FM = Enum.Font.Code,
}

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 4); c.Parent = p; return c
end

local function stroke(p, c, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = c or T.Stroke; s.Thickness = t or 1
    s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end

local function paddingSides(p, l, r, t, b)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, t)
    pad.PaddingBottom = UDim.new(0, b)
    pad.PaddingLeft = UDim.new(0, l)
    pad.PaddingRight = UDim.new(0, r)
    pad.Parent = p; return pad
end

local function gradientMulti(p, list, rot)
    local g = Instance.new("UIGradient")
    local cs = {}
    for _, c in ipairs(list) do
        table.insert(cs, ColorSequenceKeypoint.new(c[1], c[2]))
    end
    g.Color = ColorSequence.new(cs)
    g.Rotation = rot or 90
    g.Parent = p
    return g
end

local function tween(o, props, dur, style, dir)
    local tw = TweenService:Create(
        o,
        TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play(); return tw
end

local function fmt(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return out
end

local function cornerBrackets(parent, color, size, thickness)
    color = color or T.Neon
    size = size or 8
    thickness = thickness or 2
    local function mk(pos, sz)
        local f = Instance.new("Frame")
        f.Position = pos; f.Size = sz
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0; f.ZIndex = 10
        f.Parent = parent
    end
    mk(UDim2.new(0, 0, 0, 0), UDim2.new(0, size, 0, thickness))
    mk(UDim2.new(0, 0, 0, 0), UDim2.new(0, thickness, 0, size))
    mk(UDim2.new(1, -size, 0, 0), UDim2.new(0, size, 0, thickness))
    mk(UDim2.new(1, -thickness, 0, 0), UDim2.new(0, thickness, 0, size))
    mk(UDim2.new(0, 0, 1, -thickness), UDim2.new(0, size, 0, thickness))
    mk(UDim2.new(0, 0, 1, -size), UDim2.new(0, thickness, 0, size))
    mk(UDim2.new(1, -size, 1, -thickness), UDim2.new(0, size, 0, thickness))
    mk(UDim2.new(1, -thickness, 1, -size), UDim2.new(0, thickness, 0, size))
end

local function addGrid(parent, maxX, maxY)
    maxX = maxX or 40; maxY = maxY or 30
    local g = Instance.new("Frame")
    g.Size = UDim2.new(1, 0, 1, 0)
    g.BackgroundTransparency = 1; g.ZIndex = 1
    g.Parent = parent
    for i = 0, maxX do
        local v = Instance.new("Frame")
        v.Size = UDim2.new(0, 1, 1, 0)
        v.Position = UDim2.new(0, i * 16, 0, 0)
        v.BackgroundColor3 = T.Grid
        v.BackgroundTransparency = 0.85
        v.BorderSizePixel = 0; v.ZIndex = 1
        v.Parent = g
    end
    for i = 0, maxY do
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 1)
        h.Position = UDim2.new(0, 0, 0, i * 16)
        h.BackgroundColor3 = T.Grid
        h.BackgroundTransparency = 0.85
        h.BorderSizePixel = 0; h.ZIndex = 1
        h.Parent = g
    end
end

local isTraining, trainThread = false, nil
local trainCount, totalCount = 0, tonumber(Config.TotalReps) or 0
local startTime = 0
local sessionStartStrength = nil
local flying, flyBV, flyBG = false, nil, nil
local flySpeed = Config.FlySpeed or 50
local startAutoTrain, stopAutoTrain, updateStatus, updateStartBtn
local startFly, stopFly, applyWalkSpeed
local updateRebirthDisplay
local pendingRebirth = false
local pendingRebirthStart = 0
local pendingRebirthLastValue = 0

local STAT_DEFS = {
    { key = "Strength", label = "力量", color = T.Neon,
      names = { "Strength", "Power", "Str", "StrengthValue", "力量", "TotalStrength", "CrownStrength" } },
    { key = "Rebirth", label = "重生", color = T.Purple,
      names = { "Rebirth", "Rebirths", "RebirthCount", "RebirthLevel", "重生", "RebirthValue" } },
    { key = "Gems", label = "宝石", color = T.Green,
      names = { "Gems", "Gem", "GemCount", "Diamonds", "Crystal", "宝石", "Diamond" } },
    { key = "Agility", label = "敏捷", color = T.Yellow,
      names = { "Agility", "Speed", "Agil", "AgilityValue", "敏捷", "SpeedValue" } },
}

local statSources = {}
for _, def in ipairs(STAT_DEFS) do
    statSources[def.key] = { src = nil, attr = nil }
end

local function findStat(key)
    local s = statSources[key]
    if s.src and s.src.Parent then return true end
    local def
    for _, d in ipairs(STAT_DEFS) do if d.key == key then def = d break end end
    if not def then return false end

    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs(def.names) do
            local v = ls:FindFirstChild(n)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                s.src, s.attr = v, nil; return true
            end
        end
    end
    for _, n in ipairs(def.names) do
        local v = LocalPlayer:GetAttribute(n)
        if type(v) == "number" then s.src, s.attr = nil, n; return true end
    end
    for _, n in ipairs(def.names) do
        local direct = LocalPlayer:FindFirstChild(n)
        if direct and (direct:IsA("IntValue") or direct:IsA("NumberValue")) then
            s.src, s.attr = direct, nil; return true
        end
    end
    return false
end

local function getStat(key)
    local s = statSources[key]
    if s.src and s.src.Parent then return tonumber(s.src.Value) or 0 end
    if s.attr then return tonumber(LocalPlayer:GetAttribute(s.attr)) or 0 end
    return 0
end

local function hasStatSource(key)
    local s = statSources[key]
    if s.src and s.src.Parent then return true end
    if s.attr and type(LocalPlayer:GetAttribute(s.attr)) == "number" then return true end
    return false
end

local function refreshAllStats()
    for _, def in ipairs(STAT_DEFS) do findStat(def.key) end
end

local parentGui
pcall(function()
    if type(gethui) == "function" then parentGui = gethui() end
end)
if not parentGui then parentGui = PlayerGui end

local old = parentGui:FindFirstChild("CrownStrengthUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CrownStrengthUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Enabled = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentGui

local W, H = 280, 320

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, W, 0, H)
Main.Position = UDim2.new(0, 30, 0.5, -H / 2)
Main.BackgroundColor3 = T.BgDeep
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
corner(Main, 6)
stroke(Main, T.Neon, 1.2, 0.35)

gradientMulti(Main, {
    {0, T.BgPanel}, {0.5, T.BgDeep}, {1, Color3.fromRGB(6, 12, 20)},
}, 135)

addGrid(Main)
cornerBrackets(Main, T.Neon, 8, 2)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 2)
accentBar.BackgroundColor3 = T.Neon
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 8
accentBar.Parent = Main
gradientMulti(accentBar, {{0, T.Neon}, {0.35, T.Purple}, {0.7, T.Neon2}, {1, T.Neon}}, 0)

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 36)
Header.BackgroundColor3 = T.BgPanel
Header.BackgroundTransparency = 0.1
Header.BorderSizePixel = 0
Header.ZIndex = 3
Header.Parent = Main

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = T.Neon
HeaderLine.BackgroundTransparency = 0.4
HeaderLine.BorderSizePixel = 0
HeaderLine.ZIndex = 4
HeaderLine.Parent = Header
gradientMulti(HeaderLine, {{0, T.Neon}, {0.5, T.Neon2}, {1, T.Neon}}, 0)

local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0, 22, 0, 22)
Logo.Position = UDim2.new(0, 10, 0.5, -11)
Logo.BackgroundColor3 = T.Neon
Logo.BorderSizePixel = 0
Logo.ZIndex = 5
Logo.Parent = Header
corner(Logo, 5)
gradientMulti(Logo, {{0, T.Neon}, {1, T.NeonDim}}, 135)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.BackgroundTransparency = 1
LogoText.Text = "力"
LogoText.TextColor3 = T.BgDeep
LogoText.Font = T.FB
LogoText.TextSize = 11
LogoText.ZIndex = 6
LogoText.Parent = Logo

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 100, 0, 12)
TitleLbl.Position = UDim2.new(0, 38, 0, 6)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "力量之冠"
TitleLbl.TextColor3 = T.Text
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Font = T.FB
TitleLbl.TextSize = 10
TitleLbl.ZIndex = 5
TitleLbl.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 100, 0, 10)
SubTitle.Position = UDim2.new(0, 38, 0, 19)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "// v5.0"
SubTitle.TextColor3 = T.Neon
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = T.FM
SubTitle.TextSize = 7
SubTitle.ZIndex = 5
SubTitle.Parent = Header

local function headerButton(text, base, xOff, hoverColor)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 20, 0, 20)
    b.Position = UDim2.new(1, xOff, 0.5, -10)
    b.BackgroundColor3 = base
    b.BackgroundTransparency = 0.4
    b.Text = text
    b.TextColor3 = T.Text
    b.Font = T.FB
    b.TextSize = 11
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.ZIndex = 5
    b.Parent = Header
    corner(b, 3); stroke(b, base, 1, 0.3)
    b.MouseEnter:Connect(function()
        tween(b, { BackgroundTransparency = 0.1, TextColor3 = hoverColor or T.Neon }, 0.15)
    end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundTransparency = 0.4, TextColor3 = T.Text }, 0.15)
    end)
    return b
end

local CloseBtn = headerButton("×", T.RedDim, -28, T.Red)
local MinBtn = headerButton("◆", T.NeonDim, -52, T.Neon)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -72)
Content.Position = UDim2.new(0, 0, 0, 36)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 2
Content.ScrollBarImageColor3 = T.Neon
Content.ScrollBarImageTransparency = 0.4
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.ZIndex = 2
Content.Parent = Main
paddingSides(Content, 8, 8, 8, 8)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.FillDirection = Enum.FillDirection.Vertical
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Content

local function notify(text, color)
    if not Config.Notifications or not ScreenGui.Parent then return end
    color = color or T.Neon

    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 200, 0, 32)
    toast.Position = UDim2.new(0.5, -100, 0, -40)
    toast.BackgroundColor3 = T.BgPanel
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = ScreenGui
    corner(toast, 4)
    stroke(toast, color, 1.2, 0.2)
    cornerBrackets(toast, color, 6, 2)

    local acc = Instance.new("Frame")
    acc.Size = UDim2.new(0, 3, 0, 18)
    acc.Position = UDim2.new(0, 8, 0.5, -9)
    acc.BackgroundColor3 = color
    acc.BorderSizePixel = 0
    acc.Parent = toast
    corner(acc, 2)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -22, 1, 0)
    lbl.Position = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = T.Text
    lbl.Font = T.F
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = toast

    tween(toast, { BackgroundTransparency = 0, Position = UDim2.new(0.5, -100, 0, 20) }, 0.3, Enum.EasingStyle.Back)
    task.delay(2.6, function()
        if not toast.Parent then return end
        tween(toast, { BackgroundTransparency = 1, Position = UDim2.new(0.5, -100, 0, -40) }, 0.3)
        task.wait(0.4)
        if toast.Parent then toast:Destroy() end
    end)
end

local function accordionCard(title, accentColor, defaultOpen)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = T.BgPanel
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = Content
    corner(card, 4); stroke(card, accentColor or T.Neon, 1, 0.4)

    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 0); cl.SortOrder = Enum.SortOrder.LayoutOrder; cl.Parent = card

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.LayoutOrder = 1
    header.Parent = card

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 10)
    bar.Position = UDim2.new(0, 10, 0.5, -5)
    bar.BackgroundColor3 = accentColor
    bar.BorderSizePixel = 0
    bar.Parent = header
    corner(bar, 2)

    local prefix = Instance.new("TextLabel")
    prefix.Size = UDim2.new(0, 14, 1, 0)
    prefix.Position = UDim2.new(0, 16, 0, 0)
    prefix.BackgroundTransparency = 1
    prefix.Text = "›"
    prefix.TextColor3 = accentColor
    prefix.TextXAlignment = Enum.TextXAlignment.Left
    prefix.Font = T.FB
    prefix.TextSize = 11
    prefix.Parent = header

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 28, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.TextColor3 = accentColor
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FB
    lbl.TextSize = 9
    lbl.Parent = header

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.Position = UDim2.new(1, -22, 0.5, -8)
    arrow.BackgroundTransparency = 1
    arrow.Text = defaultOpen and "▾" or "▸"
    arrow.TextColor3 = accentColor
    arrow.Font = T.FB
    arrow.TextSize = 10
    arrow.Parent = header

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.Visible = defaultOpen
    body.LayoutOrder = 2
    body.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.Parent = body

    local bl = Instance.new("UIListLayout")
    bl.Padding = UDim.new(0, 4); bl.SortOrder = Enum.SortOrder.LayoutOrder; bl.Parent = body

    header.MouseButton1Click:Connect(function()
        local open = not body.Visible
        body.Visible = open
        arrow.Text = open and "▾" or "▸"
    end)

    return body
end

local function toggleRow(parent, labelText, key, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.F
    lbl.TextSize = 10
    lbl.Parent = row

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 34, 0, 18)
    switch.Position = UDim2.new(1, -34, 0.5, -9)
    switch.BackgroundColor3 = Config[key] and T.Green or T.BgPanel2
    switch.Text = ""; switch.AutoButtonColor = false
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 3); stroke(switch, Config[key] and T.Green or T.Stroke, 1, 0.3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 13, 0, 13)
    knob.Position = Config[key] and UDim2.new(1, -15, 0.5, -6.5) or UDim2.new(0, 2, 0.5, -6.5)
    knob.BackgroundColor3 = Config[key] and T.BgDeep or T.TextDim
    knob.BorderSizePixel = 0
    knob.Parent = switch
    corner(knob, 2)

    local function refresh()
        local on = Config[key]
        tween(switch, { BackgroundColor3 = on and T.Green or T.BgPanel2 }, 0.2)
        tween(knob, {
            Position = on and UDim2.new(1, -15, 0.5, -6.5) or UDim2.new(0, 2, 0.5, -6.5),
            BackgroundColor3 = on and T.BgDeep or T.TextDim,
        }, 0.2)
    end

    switch.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        if key == "AutoRebirth" and Config[key] and not RebirthEvent then
            Config[key] = false
            notify("未找到重生事件", T.Red)
        end
        refresh()
        if onToggle then onToggle(Config[key]) end
        saveConfig()
    end)
end

local function numberInput(parent, labelText, key, minV, maxV, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 78, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.F
    lbl.TextSize = 9
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -78, 1, 0)
    box.Position = UDim2.new(0, 78, 0, 0)
    box.BackgroundColor3 = T.BgPanel2
    box.Text = tostring(Config[key])
    box.TextColor3 = T.Neon
    box.Font = T.FM
    box.TextSize = 10
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = row
    corner(box, 3); stroke(box, T.Stroke, 1, 0.3)

    box.Focused:Connect(function() tween(box, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
    box.FocusLost:Connect(function()
        tween(box, { BackgroundColor3 = T.BgPanel2 }, 0.15)
        local n = tonumber(box.Text)
        if n and n >= minV and n <= maxV then
            box.Text = tostring(n)
            Config[key] = n
            if onChange then onChange(n) end
            saveConfig()
        else
            box.Text = tostring(Config[key])
            notify(string.format("范围 %d ~ %d", minV, maxV), T.Red)
        end
    end)
end

local function infoRow(parent, label, color)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 20)
    r.BackgroundColor3 = T.BgPanel2
    r.BackgroundTransparency = 0.4
    r.Parent = parent
    corner(r, 3); stroke(r, T.Stroke, 1, 0.6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.55, -8, 1, 0)
    l.Position = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = T.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.F; l.TextSize = 9
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.45, -8, 1, 0)
    v.Position = UDim2.new(0.55, 0, 0, 0)
    v.BackgroundTransparency = 1
    v.Text = "—"
    v.TextColor3 = color or T.Text
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Font = T.FM; v.TextSize = 10
    v.Parent = r
    return v
end

local powerCard = accordionCard("◆ 力量数据", T.Neon, true)
local rowStrength = infoRow(powerCard, "当前力量", T.Neon)
local rowSession  = infoRow(powerCard, "本次增长", T.Green)
local rowBefore   = infoRow(powerCard, "训练前", T.Yellow)
local rowPerRep   = infoRow(powerCard, "每次增量", T.Purple)

local trainCard = accordionCard("◆ 训练", T.Green, true)

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, 0, 0, 30)
startBtn.BackgroundColor3 = T.Green
startBtn.Text = "▶  开始训练"
startBtn.TextColor3 = T.BgDeep
startBtn.Font = T.FB
startBtn.TextSize = 11
startBtn.AutoButtonColor = false
startBtn.BorderSizePixel = 0
startBtn.Parent = trainCard
corner(startBtn, 4)
local startGrad = gradientMulti(startBtn, {
    {0, Color3.fromRGB(0, 255, 180)},
    {1, Color3.fromRGB(0, 150, 100)},
}, 90)
local startStroke = stroke(startBtn, T.Green, 1.5, 0.2)

updateStartBtn = function()
    if isTraining then
        startBtn.Text = "■  停止训练"
        startBtn.TextColor3 = Color3.fromRGB(40, 5, 15)
        startGrad.Color = ColorSequence.new(Color3.fromRGB(255, 100, 130), Color3.fromRGB(180, 30, 60))
        startStroke.Color = T.Red
    else
        startBtn.Text = "▶  开始训练"
        startBtn.TextColor3 = T.BgDeep
        startGrad.Color = ColorSequence.new(Color3.fromRGB(0, 255, 180), Color3.fromRGB(0, 150, 100))
        startStroke.Color = T.Green
    end
end

toggleRow(trainCard, "🎯 使用全部21动作", "UseAllActions", function(on)
    notify(on and "已切换：21 动作全模式" or "已切换：4 基础动作", T.Neon)
end)

toggleRow(trainCard, "🚀 快速模式", "FastMode", function(on)
    notify(on and "快速模式已开启" or "已恢复安全模式", on and T.Yellow or T.Green)
end)

numberInput(trainCard, "每轮动作数", "MaxActionsPerRound", 1, 21)

local intervalRow = Instance.new("Frame")
intervalRow.Size = UDim2.new(1, 0, 0, 22)
intervalRow.BackgroundTransparency = 1
intervalRow.Parent = trainCard

local intervalLbl = Instance.new("TextLabel")
intervalLbl.Size = UDim2.new(0, 60, 1, 0)
intervalLbl.BackgroundTransparency = 1
intervalLbl.Text = "间隔(秒)"
intervalLbl.TextColor3 = T.TextDim
intervalLbl.TextXAlignment = Enum.TextXAlignment.Left
intervalLbl.Font = T.F
intervalLbl.TextSize = 9
intervalLbl.Parent = intervalRow

local intervalBox = Instance.new("TextBox")
intervalBox.Size = UDim2.new(1, -60, 1, 0)
intervalBox.Position = UDim2.new(0, 60, 0, 0)
intervalBox.BackgroundColor3 = T.BgPanel2
intervalBox.Text = tostring(Config.Interval)
intervalBox.TextColor3 = T.Neon
intervalBox.Font = T.FM
intervalBox.TextSize = 10
intervalBox.ClearTextOnFocus = false
intervalBox.BorderSizePixel = 0
intervalBox.Parent = intervalRow
corner(intervalBox, 3); stroke(intervalBox, T.Stroke, 1, 0.3)

intervalBox.Focused:Connect(function() tween(intervalBox, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
intervalBox.FocusLost:Connect(function()
    tween(intervalBox, { BackgroundColor3 = T.BgPanel2 }, 0.15)
    local n = tonumber(intervalBox.Text)
    if n and n >= MIN_INTERVAL and n <= MAX_INTERVAL then
        Config.Interval = n
        intervalBox.Text = tostring(n)
        saveConfig()
    else
        intervalBox.Text = tostring(Config.Interval)
        notify(string.format("范围 %.2f ~ %d", MIN_INTERVAL, MAX_INTERVAL), T.Red)
    end
end)

local visualCard = accordionCard("◆ 视觉优化", T.Yellow, false)
toggleRow(visualCard, "👁️ 屏蔽浮动数字", "HideFloatingText", function(on)
    notify(on and "已屏蔽浮动数字" or "已恢复浮动数字", T.Neon)
end)
toggleRow(visualCard, "🐾 隐藏宠物模型", "HidePets", function(on)
    notify(on and "已隐藏宠物" or "已恢复宠物", T.Neon)
end)

local autoCard = accordionCard("◆ 自动重生", T.Purple, false)
toggleRow(autoCard, "自动重生", "AutoRebirth")
toggleRow(autoCard, "反挂机", "AntiAfk")
toggleRow(autoCard, "自动重置", "AutoReset")
toggleRow(autoCard, "通知提示", "Notifications")
numberInput(autoCard, "目标重生数", "TargetRebirthCount", 0, 99999)
toggleRow(autoCard, "🎯 达标自动停止", "StopAtTargetRebirth", function(on)
    notify(on and "已开启：达到目标后自动停" or "已关闭", on and T.Green or T.Red)
end)

local gameRebirthLbl = infoRow(autoCard, "游戏内重生数", T.Purple)

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, 0, 0, 24)
statsRow.BackgroundColor3 = T.BgPanel2
statsRow.BackgroundTransparency = 0.4
statsRow.Parent = autoCard
corner(statsRow, 3); stroke(statsRow, T.Purple, 1, 0.4)

local doneLbl = Instance.new("TextLabel")
doneLbl.Size = UDim2.new(0.5, 0, 1, 0)
doneLbl.BackgroundTransparency = 1
doneLbl.Text = "0"
doneLbl.TextColor3 = T.Green
doneLbl.Font = T.FB
doneLbl.TextSize = 12
doneLbl.Parent = statsRow

local targetLbl = Instance.new("TextLabel")
targetLbl.Size = UDim2.new(0.5, 0, 1, 0)
targetLbl.Position = UDim2.new(0.5, 0, 0, 0)
targetLbl.BackgroundTransparency = 1
targetLbl.Text = "∞"
targetLbl.TextColor3 = T.Purple
targetLbl.Font = T.FB
targetLbl.TextSize = 12
targetLbl.Parent = statsRow

updateRebirthDisplay = function()
    doneLbl.Text = tostring(Config.AutoRebirthDone)
    if Config.AutoRebirthCount == 0 then
        targetLbl.Text = "∞"
    else
        targetLbl.Text = tostring(Config.AutoRebirthCount)
    end
end
updateRebirthDisplay()

local moveCard = accordionCard("◆ 移动", T.Neon, false)

applyWalkSpeed = function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = Config.WalkSpeed end
end

startFly = function()
    if flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBG.P = 3000; flyBG.D = 500
    flyBG.Parent = hrp
    flying = true
end

stopFly = function()
    if not flying then return end
    flying = false
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    applyWalkSpeed()
end

RunService.RenderStepped:Connect(function()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then stopFly() return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not flyBV or not flyBG then return end

    local cam = workspace.CurrentCamera
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
    if dir.Magnitude > 0 then dir = dir.Unit * flySpeed end
    flyBV.Velocity = dir
    flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    applyWalkSpeed()
    if flying then
        flying = false
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        if Config.Fly then startFly() end
    end
end)

toggleRow(moveCard, "飞行模式", "Fly", function(on)
    if on then startFly(); notify("飞行开启 — 空格/左Ctrl", T.Neon)
    else stopFly(); notify("飞行关闭", T.Red) end
end)

numberInput(moveCard, "步行速度", "WalkSpeed", 16, 500, function(v)
    Config.WalkSpeed = v; applyWalkSpeed()
end)

numberInput(moveCard, "飞行速度", "FlySpeed", 10, 500, function(v)
    flySpeed = v
end)

local Bottom = Instance.new("Frame")
Bottom.Size = UDim2.new(1, 0, 0, 36)
Bottom.Position = UDim2.new(0, 0, 1, -36)
Bottom.BackgroundColor3 = T.BgPanel
Bottom.BackgroundTransparency = 0.1
Bottom.BorderSizePixel = 0
Bottom.ZIndex = 3
Bottom.Parent = Main

local bottomLine = Instance.new("Frame")
bottomLine.Size = UDim2.new(1, 0, 0, 1)
bottomLine.BackgroundColor3 = T.Neon
bottomLine.BackgroundTransparency = 0.5
bottomLine.BorderSizePixel = 0
bottomLine.ZIndex = 4
bottomLine.Parent = Bottom
gradientMulti(bottomLine, {{0, T.Neon}, {0.5, T.Neon2}, {1, T.Neon}}, 0)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 5, 0, 5)
statusDot.Position = UDim2.new(0, 12.5, 0, 10.5)
statusDot.BackgroundColor3 = T.Red
statusDot.BorderSizePixel = 0
statusDot.ZIndex = 5
statusDot.Parent = Bottom
corner(statusDot, 3)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -36, 0, 11)
statusLbl.Position = UDim2.new(0, 26, 0, 6)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "待机中"
statusLbl.TextColor3 = T.Text
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Font = T.FM
statusLbl.TextSize = 9
statusLbl.ZIndex = 5
statusLbl.Parent = Bottom

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1, -36, 0, 11)
hintLbl.Position = UDim2.new(0, 26, 0, 18)
hintLbl.BackgroundTransparency = 1
hintLbl.Text = "// Insert隐藏 · RS训练"
hintLbl.TextColor3 = T.TextSub
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Font = T.FM
hintLbl.TextSize = 7
hintLbl.ZIndex = 5
hintLbl.Parent = Bottom

do
    local dragging, dragStart, startPos = false, nil, nil
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

updateStatus = function()
    if isTraining then
        statusDot.BackgroundColor3 = T.Green
        statusLbl.Text = "运行中 · " .. (Config.UseAllActions and "21动作全模式" or (ActionNames[Config.Action] or Config.Action))
        statusLbl.TextColor3 = T.Green
    else
        statusDot.BackgroundColor3 = T.Red
        statusLbl.Text = "待机中"
        statusLbl.TextColor3 = T.Text
    end
end

local actionIndices = {}
for i = 1, #ALL_ACTIONS do table.insert(actionIndices, i) end

local function shuffleActions()
    local shuffled = table.clone(actionIndices)
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

startAutoTrain = function()
    if isTraining then return end
    if not TrainEvent then notify("未找到训练事件", T.Red) return end
    isTraining = true
    trainCount = 0
    startTime = tick()
    refreshAllStats()
    if hasStatSource("Strength") then
        sessionStartStrength = getStat("Strength")
    end
    trainThread = task.spawn(function()
        while isTraining and ScreenGui.Parent do
            local randomOffset = math.random(-3, 3) / 100
            local interval = math.max(0.05, Config.Interval + randomOffset)

            if Config.UseAllActions then
                local shuffled = shuffleActions()
                local count = math.min(Config.MaxActionsPerRound, #shuffled)
                for i = 1, count do
                    if not isTraining then break end
                    pcall(function() TrainEvent:FireServer(ALL_ACTIONS[shuffled[i]]) end)
                    trainCount = trainCount + 1
                    totalCount = totalCount + 1
                    if not Config.FastMode then task.wait(0.03) else task.wait(0.01) end
                end
            else
                pcall(function() TrainEvent:FireServer(Config.Action) end)
                trainCount = trainCount + 1
                totalCount = totalCount + 1
            end
            Config.TotalReps = totalCount
            safeWait(interval)
        end
        if isTraining then isTraining = false end
    end)
    updateStatus()
end

stopAutoTrain = function()
    if not isTraining then return end
    isTraining = false
    if trainThread then
        pcall(task.cancel, trainThread)
        trainThread = nil
    end
    saveConfig()
    updateStatus()
end

startBtn.MouseButton1Click:Connect(function()
    if isTraining then
        stopAutoTrain()
        notify("训练已停止", T.Red)
    else
        startAutoTrain()
        if isTraining then notify("训练已开始", T.Green) end
    end
    updateStartBtn()
    updateStatus()
end)

startBtn.MouseEnter:Connect(function() tween(startBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
startBtn.MouseLeave:Connect(function() tween(startBtn, { BackgroundTransparency = 0 }, 0.15) end)

MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    notify("面板已隐藏 · 按 Insert 显示", T.Yellow)
end)

CloseBtn.MouseButton1Click:Connect(function()
    stopAutoTrain()
    stopFly()
    saveConfig()
    if ScreenGui.Parent then ScreenGui:Destroy() end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.2)
        if Config.HideFloatingText then
            pcall(function()
                local pg = LocalPlayer:FindFirstChild("PlayerGui")
                if pg then
                    local tweenGui = pg:FindFirstChild("TweenGui")
                    if tweenGui then
                        for _, v in ipairs(tweenGui:GetDescendants()) do
                            if v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel") then
                                v.Visible = false
                            end
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1.0)
        if Config.HidePets then
            pcall(function()
                local char = LocalPlayer.Character
                for _, v in ipairs(workspace:GetChildren()) do
                    if v ~= char and (v:IsA("Model") or v:IsA("Folder")) then
                        local lowerName = string.lower(v.Name)
                        local isPet = string.find(lowerName, "pet")
                            or string.find(lowerName, "slime")
                            or string.find(lowerName, "egg")
                        if not isPet and v.Parent then
                            isPet = string.find(string.lower(v.Parent.Name), "pet")
                        end
                        if isPet then
                            for _, part in ipairs(v:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.LocalTransparencyModifier = 1
                                    part.Collide = false
                                end
                            end
                        end
                    end
                end
            end)
        else
            pcall(function()
                for _, v in ipairs(workspace:GetChildren()) do
                    local lowerName = string.lower(v.Name)
                    local isPet = string.find(lowerName, "pet")
                        or string.find(lowerName, "slime")
                        or string.find(lowerName, "egg")
                    if isPet then
                        for _, part in ipairs(v:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.LocalTransparencyModifier = 0
                            end
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        refreshAllStats()
        local curStrength = getStat("Strength")
        if curStrength == 0 then curStrength = getCurrentStrength() end
        if sessionStartStrength == nil then sessionStartStrength = curStrength end
        local gain = curStrength - sessionStartStrength

        rowStrength.Text = fmt(curStrength)
        rowSession.Text = (gain >= 0 and "+" or "") .. fmt(gain)
        rowBefore.Text = fmt(sessionStartStrength)
        rowSession.TextColor3 = gain > 0 and T.Green or (gain < 0 and T.Red or T.Text)

        if trainCount > 0 and gain > 0 then
            rowPerRep.Text = string.format("%.2f", gain / trainCount)
        else
            rowPerRep.Text = "—"
        end

        gameRebirthLbl.Text = tostring(getCurrentRebirths())

        task.wait(0.5)
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        updateStatus()
        task.wait(1)
    end
end)

local function fireAntiAfk()
    if not Config.AntiAfk then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, true, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, false, false, game)
    end)
end

LocalPlayer.Idled:Connect(fireAntiAfk)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(60)
        if Config.AntiAfk then fireAntiAfk() end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.5)
        if pendingRebirth then
            refreshAllStats()
            local gameRebirth = getCurrentRebirths()
            if gameRebirth > pendingRebirthLastValue then
                pendingRebirth = false
                Config.AutoRebirthDone = Config.AutoRebirthDone + 1
                saveConfig()
                if updateRebirthDisplay then updateRebirthDisplay() end
                notify("重生成功！当前 " .. gameRebirth, T.Green)

                if Config.StopAtTargetRebirth
                    and Config.TargetRebirthCount > 0
                    and gameRebirth >= Config.TargetRebirthCount then
                    Config.AutoRebirth = false
                    saveConfig()
                    notify("已达成目标重生数 " .. Config.TargetRebirthCount, T.Yellow)
                end
            elseif tick() - pendingRebirthStart > REBIRTH_TIMEOUT then
                pendingRebirth = false
                notify("重生超时（未检测到）", T.Red)
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(Config.AutoRebirthDelay)
        if Config.AutoRebirth and RebirthEvent and not pendingRebirth then
            local gameRebirth = getCurrentRebirths()

            if Config.StopAtTargetRebirth
                and Config.TargetRebirthCount > 0
                and gameRebirth >= Config.TargetRebirthCount then
                Config.AutoRebirth = false
                saveConfig()
                notify("已达标 " .. Config.TargetRebirthCount, T.Yellow)
            else
                pendingRebirthLastValue = gameRebirth
                pendingRebirth = true
                pendingRebirthStart = tick()

                pcall(function() RebirthEvent:FireServer("Start") end)
                task.wait(0.5)
                pcall(function() RebirthEvent:FireServer("Update") end)
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(Config.AutoResetInterval)
        if Config.AutoReset then
            pcall(function()
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.Health = 0 else char:BreakJoints() end
                end
            end)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        Main.Visible = not Main.Visible
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        if isTraining then
            stopAutoTrain()
            notify("训练已停止", T.Red)
        else
            startAutoTrain()
            if isTraining then notify("训练已开始", T.Green) end
        end
        updateStartBtn()
        updateStatus()
    end
end)

updateStartBtn()
updateStatus()
refreshAllStats()
applyWalkSpeed()

if Config.AutoStart then
    startAutoTrain()
    updateStartBtn()
    updateStatus()
end

notify("力量之冠 v5.0 — 已启动", T.Neon)