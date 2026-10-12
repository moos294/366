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
    Notifications = true, MinimizeOnStart = false, TotalReps = 0,
    Fly = false, FlySpeed = 50, WalkSpeed = 16,
    AutoRebirthCount = 0, AutoRebirthDone = 0,
    DataPanelOpen = false,
    EggMaxBackpack = 256, EggStopWhenFull = true,
    SkyEggAuto = false, SkyEggInterval = 1, SkyEggTotal = 0,
    LavaEggAuto = false, LavaEggInterval = 1, LavaEggTotal = 0,
    SandEggAuto = false, SandEggInterval = 1, SandEggTotal = 0,
    JungleEggAuto = false, JungleEggInterval = 1, JungleEggTotal = 0,
}

local Actions = { "PushUp", "SitUp", "PullUp", "Squat" }
local ActionNames = { PushUp = "俯卧撑", SitUp = "仰卧起坐", PullUp = "引体向上", Squat = "深蹲" }
local CONFIG_FILE = "CrownStrength_config.json"
local MIN_INTERVAL, MAX_INTERVAL = 0.08, 10
local MIN_W, MIN_H, MAX_W, MAX_H = 260, 260, 420, 600
local COLLAPSED = 44
local IS_TOUCH = UserInputService.TouchEnabled
local REBIRTH_TIMEOUT = 15

-- ✅ FIX: 最小循环间隔改为 0.05，与 MIN_INTERVAL=0.08 保持一致
local MIN_LOOP_WAIT = 0.05
local function safeWait(t)
    task.wait(math.max(MIN_LOOP_WAIT, tonumber(t) or MIN_LOOP_WAIT))
end

local EGG_DEFS = {
    sky    = { name = "SkyPetEgg",    count = 5, currency = "Gem", label = "天空蛋" },
    lava   = { name = "LavaPetEgg",   count = 5, currency = "Gem", label = "岩浆蛋" },
    sand   = { name = "SandPetEgg",   count = 5, currency = "Gem", label = "沙漠蛋" },
    jungle = { name = "JunglePetEgg", count = 5, currency = "Gem", label = "主岛蛋" },
}

local EGG_KEYS = { "SkyEggAuto", "LavaEggAuto", "SandEggAuto", "JungleEggAuto" }

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
local StoreEvent = findRemote("StoreEvent", "Store")

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

local function clampConfig()
    Config.Interval          = math.clamp(tonumber(Config.Interval)          or 0.1,  MIN_INTERVAL, MAX_INTERVAL)
    Config.SkyEggInterval    = math.clamp(tonumber(Config.SkyEggInterval)    or 1,    0.1, 30)
    Config.LavaEggInterval   = math.clamp(tonumber(Config.LavaEggInterval)   or 1,    0.1, 30)
    Config.SandEggInterval   = math.clamp(tonumber(Config.SandEggInterval)   or 1,    0.1, 30)
    Config.JungleEggInterval = math.clamp(tonumber(Config.JungleEggInterval) or 1,    0.1, 30)
    Config.AutoRebirthDelay  = math.clamp(tonumber(Config.AutoRebirthDelay)  or 3,    0.5, 600)
    Config.AutoResetInterval = math.clamp(tonumber(Config.AutoResetInterval) or 300,  10, 86400)
    Config.WalkSpeed         = math.clamp(tonumber(Config.WalkSpeed)         or 16,   16, 500)
    Config.FlySpeed          = math.clamp(tonumber(Config.FlySpeed)          or 50,   10, 500)
    Config.EggMaxBackpack    = math.clamp(tonumber(Config.EggMaxBackpack)    or 256,  1, 99999)
    Config.AutoRebirthCount  = math.clamp(tonumber(Config.AutoRebirthCount)  or 0,    0, 99999)
    Config.AutoRebirthDone   = math.clamp(tonumber(Config.AutoRebirthDone)   or 0,    0, 99999)
    Config.TotalReps         = math.max(0, tonumber(Config.TotalReps) or 0)
    Config.SkyEggTotal       = math.max(0, tonumber(Config.SkyEggTotal) or 0)
    Config.LavaEggTotal      = math.max(0, tonumber(Config.LavaEggTotal) or 0)
    Config.SandEggTotal      = math.max(0, tonumber(Config.SandEggTotal) or 0)
    Config.JungleEggTotal    = math.max(0, tonumber(Config.JungleEggTotal) or 0)
end
clampConfig()

do
    local firstOn = nil
    for _, k in ipairs(EGG_KEYS) do
        if Config[k] then
            if firstOn == nil then
                firstOn = k
            else
                Config[k] = false
            end
        end
    end
end

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
    Orange   = Color3.fromRGB(255, 140, 60),
    Sky      = Color3.fromRGB(96, 200, 255),
    SkyDark  = Color3.fromRGB(40, 130, 200),
    Lava     = Color3.fromRGB(255, 90, 50),
    LavaDark = Color3.fromRGB(180, 40, 20),
    Sand     = Color3.fromRGB(240, 200, 120),
    SandDark = Color3.fromRGB(180, 130, 40),
    Jungle   = Color3.fromRGB(120, 220, 130),
    JungleDark = Color3.fromRGB(60, 150, 80),
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

local function gradient(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2); g.Rotation = rot or 90; g.Parent = p; return g
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

-- ✅ FIX: 重写 cornerBrackets，4 个角的 8 条线段位置现在全部正确
local function cornerBrackets(parent, color, size, thickness)
    color = color or T.Neon
    size = size or 8
    thickness = thickness or 2

    local function makeFrame(pos, sz)
        local f = Instance.new("Frame")
        f.Position = pos
        f.Size = sz
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0
        f.ZIndex = 10
        f.Parent = parent
        return f
    end

    -- 左上角
    makeFrame(UDim2.new(0, 0, 0, 0),               UDim2.new(0, size, 0, thickness))
    makeFrame(UDim2.new(0, 0, 0, 0),               UDim2.new(0, thickness, 0, size))
    -- 右上角
    makeFrame(UDim2.new(1, -size, 0, 0),           UDim2.new(0, size, 0, thickness))
    makeFrame(UDim2.new(1, -thickness, 0, 0),      UDim2.new(0, thickness, 0, size))
    -- 左下角
    makeFrame(UDim2.new(0, 0, 1, -thickness),      UDim2.new(0, size, 0, thickness))
    makeFrame(UDim2.new(0, 0, 1, -size),           UDim2.new(0, thickness, 0, size))
    -- 右下角
    makeFrame(UDim2.new(1, -size, 1, -thickness),  UDim2.new(0, size, 0, thickness))
    makeFrame(UDim2.new(1, -thickness, 1, -size),  UDim2.new(0, thickness, 0, size))
end

local function addGrid(parent, maxX, maxY)
    maxX = maxX or 40
    maxY = maxY or 30
    local g = Instance.new("Frame")
    g.Size = UDim2.new(1, 0, 1, 0)
    g.BackgroundTransparency = 1
    g.ZIndex = 1
    g.Parent = parent
    for i = 0, maxX do
        local v = Instance.new("Frame")
        v.Size = UDim2.new(0, 1, 1, 0)
        v.Position = UDim2.new(0, i * 16, 0, 0)
        v.BackgroundColor3 = T.Grid
        v.BackgroundTransparency = 0.85
        v.BorderSizePixel = 0
        v.ZIndex = 1
        v.Parent = g
    end
    for i = 0, maxY do
        local h = Instance.new("Frame")
        h.Size = UDim2.new(1, 0, 0, 1)
        h.Position = UDim2.new(0, 0, 0, i * 16)
        h.BackgroundColor3 = T.Grid
        h.BackgroundTransparency = 0.85
        h.BorderSizePixel = 0
        h.ZIndex = 1
        h.Parent = g
    end
end

local isTraining, trainThread = false, nil
local trainCount, totalCount = 0, tonumber(Config.TotalReps) or 0
local startTime, isCollapsed, savedSize = 0, false, nil
local sessionStartStrength = nil
local flying, flyBV, flyBG = false, nil, nil
local flySpeed = Config.FlySpeed or 50
local skyEggTotal = tonumber(Config.SkyEggTotal) or 0
local lavaEggTotal = tonumber(Config.LavaEggTotal) or 0
local sandEggTotal = tonumber(Config.SandEggTotal) or 0
local jungleEggTotal = tonumber(Config.JungleEggTotal) or 0
local startAutoTrain, stopAutoTrain, updateStatus, updateStartBtn, collapse, expand
local startFly, stopFly, applyWalkSpeed
local updateRebirthDisplay
local DataPanelOpen = Config.DataPanelOpen or false

local pendingRebirth = false
local pendingRebirthStart = 0
local pendingRebirthLastValue = 0

local EggToggleRefs = {}

local function closeOtherEggs(keepKey)
    for _, k in ipairs(EGG_KEYS) do
        if k ~= keepKey and Config[k] then
            Config[k] = false
            local ref = EggToggleRefs[k]
            if ref and ref.refresh then
                ref.refresh()
            end
        end
    end
    saveConfig()
end

local MobileInput = { Forward = false, Back = false, Left = false, Right = false, Up = false, Down = false }

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
    for _, d in ipairs(STAT_DEFS) do
        if d.key == key then def = d break end
    end
    if not def then return false end

    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, n in ipairs(def.names) do
            local v = ls:FindFirstChild(n)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                s.src, s.attr = v, nil
                return true
            end
        end
    end
    for _, n in ipairs(def.names) do
        local v = LocalPlayer:GetAttribute(n)
        if type(v) == "number" then
            s.src, s.attr = nil, n
            return true
        end
    end
    for _, n in ipairs(def.names) do
        local direct = LocalPlayer:FindFirstChild(n)
        if direct and (direct:IsA("IntValue") or direct:IsA("NumberValue")) then
            s.src, s.attr = direct, nil
            return true
        end
    end
    return false
end

local function getStat(key)
    local s = statSources[key]
    if s.src and s.src.Parent then
        return tonumber(s.src.Value) or 0
    end
    if s.attr then
        return tonumber(LocalPlayer:GetAttribute(s.attr)) or 0
    end
    return 0
end

local function hasStatSource(key)
    local s = statSources[key]
    if s.src and s.src.Parent then return true end
    if s.attr and type(LocalPlayer:GetAttribute(s.attr)) == "number" then return true end
    return false
end

local function refreshAllStats()
    for _, def in ipairs(STAT_DEFS) do
        findStat(def.key)
    end
end

local function getBackpackCount()
    local count = 0
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        count = count + #backpack:GetChildren()
    end
    local char = LocalPlayer.Character
    if char then
        local charCount = 0
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then charCount = charCount + 1 end
        end
        count = count + charCount
    end
    return count
end

local function isBackpackFull()
    if not Config.EggStopWhenFull then return false end
    local maxCap = Config.EggMaxBackpack
    if not maxCap or maxCap <= 0 then return false end
    return getBackpackCount() >= maxCap
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
ScreenGui.Parent = parentGui

local W, H = 280, 300

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, W, 0, H)
Main.Position = UDim2.new(0, 30, 0.5, -H / 2)
Main.BackgroundColor3 = T.BgDeep
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local mainCorner = corner(Main, 6)
local mainStroke = stroke(Main, T.Neon, 1.2, 0.35)

local bgGrad = gradientMulti(Main, {
    {0, T.BgPanel},
    {0.5, T.BgDeep},
    {1, Color3.fromRGB(6, 12, 20)},
}, 135)

addGrid(Main)
cornerBrackets(Main, T.Neon, 8, 2)

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 2)
accentBar.BackgroundColor3 = T.Neon
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 8
accentBar.Parent = Main
gradientMulti(accentBar, {
    {0, T.Neon}, {0.35, T.Purple}, {0.7, T.Neon2}, {1, T.Neon},
}, 0)

local accentGlow = Instance.new("Frame")
accentGlow.Size = UDim2.new(1, 0, 0, 6)
accentGlow.Position = UDim2.new(0, 0, 0, 0)
accentGlow.BackgroundColor3 = T.Neon
accentGlow.BackgroundTransparency = 0.7
accentGlow.BorderSizePixel = 0
accentGlow.ZIndex = 7
accentGlow.Parent = Main
gradientMulti(accentGlow, {{0, T.Neon}, {1, T.BgDeep}}, 90)

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
stroke(Logo, T.Neon, 1.2, 0.2)

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
SubTitle.Text = "// v4.0"
SubTitle.TextColor3 = T.Neon
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = T.FM
SubTitle.TextSize = 7
SubTitle.ZIndex = 5
SubTitle.Parent = Header

local HeaderDotGlow = Instance.new("Frame")
HeaderDotGlow.Size = UDim2.new(0, 10, 0, 10)
HeaderDotGlow.Position = UDim2.new(1, -102, 0.5, -5)
HeaderDotGlow.BackgroundColor3 = T.Red
HeaderDotGlow.BackgroundTransparency = 0.65
HeaderDotGlow.BorderSizePixel = 0
HeaderDotGlow.ZIndex = 4
HeaderDotGlow.Parent = Header
corner(HeaderDotGlow, 5)

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 5, 0, 5)
HeaderDot.Position = UDim2.new(1, -99.5, 0.5, -2.5)
HeaderDot.BackgroundColor3 = T.Red
HeaderDot.BorderSizePixel = 0
HeaderDot.ZIndex = 5
HeaderDot.Parent = Header
corner(HeaderDot, 3)

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
    corner(b, 3)
    stroke(b, base, 1, 0.3)
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
local DataBtn = headerButton("▤", T.NeonDim, -76, T.Neon)

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
ContentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
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
    corner(card, 4)
    stroke(card, accentColor or T.Neon, 1, 0.4)

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 0)
    cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
    cardLayout.Parent = card

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

    local barGlow = Instance.new("Frame")
    barGlow.Size = UDim2.new(0, 6, 0, 10)
    barGlow.Position = UDim2.new(0, 8.5, 0.5, -5)
    barGlow.BackgroundColor3 = accentColor
    barGlow.BackgroundTransparency = 0.6
    barGlow.BorderSizePixel = 0
    barGlow.Parent = header
    corner(barGlow, 3)

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

    local bodyPad = Instance.new("UIPadding")
    bodyPad.PaddingLeft = UDim.new(0, 8)
    bodyPad.PaddingRight = UDim.new(0, 8)
    bodyPad.PaddingBottom = UDim.new(0, 8)
    bodyPad.PaddingTop = UDim.new(0, 0)
    bodyPad.Parent = body

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 4)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

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
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.BorderSizePixel = 0
    switch.Parent = row
    corner(switch, 3)
    stroke(switch, Config[key] and T.Green or T.Stroke, 1, 0.3)

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
        if (key == "SkyEggAuto" or key == "LavaEggAuto" or key == "SandEggAuto" or key == "JungleEggAuto")
            and Config[key] and not StoreEvent then
            Config[key] = false
            notify("未找到开蛋事件", T.Red)
        end

        refresh()

        if (key == "SkyEggAuto" or key == "LavaEggAuto" or key == "SandEggAuto" or key == "JungleEggAuto") then
            if Config[key] then
                closeOtherEggs(key)
            end
        end

        if onToggle then onToggle(Config[key]) end
        saveConfig()
    end)

    return { switch = switch, refresh = refresh }
end

local function numberInput(parent, labelText, key, minV, maxV, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 58, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.F
    lbl.TextSize = 9
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -58, 1, 0)
    box.Position = UDim2.new(0, 58, 0, 0)
    box.BackgroundColor3 = T.BgPanel2
    box.Text = tostring(Config[key])
    box.TextColor3 = T.Neon
    box.PlaceholderColor3 = T.TextDim
    box.Font = T.FM
    box.TextSize = 10
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = row
    corner(box, 3)
    stroke(box, T.Stroke, 1, 0.3)

    box.Focused:Connect(function()
        tween(box, { BackgroundColor3 = T.BgPanelHi }, 0.15)
    end)
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

local function floatInput(parent, labelText, key, minV, maxV, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 58, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = T.TextDim
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.F
    lbl.TextSize = 9
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -58, 1, 0)
    box.Position = UDim2.new(0, 58, 0, 0)
    box.BackgroundColor3 = T.BgPanel2
    box.Text = tostring(Config[key])
    box.TextColor3 = T.Neon
    box.PlaceholderColor3 = T.TextDim
    box.Font = T.FM
    box.TextSize = 10
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0
    box.Parent = row
    corner(box, 3)
    stroke(box, T.Stroke, 1, 0.3)

    box.Focused:Connect(function()
        tween(box, { BackgroundColor3 = T.BgPanelHi }, 0.15)
    end)
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
            notify(string.format("范围 %.2f ~ %.2f", minV, maxV), T.Red)
        end
    end)
end

local function infoRow(parent, label, color)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 20)
    r.BackgroundColor3 = T.BgPanel2
    r.BackgroundTransparency = 0.4
    r.Parent = parent
    corner(r, 3)
    stroke(r, T.Stroke, 1, 0.6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.55, -8, 1, 0)
    l.Position = UDim2.new(0, 6, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = T.TextDim
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.F
    l.TextSize = 9
    l.Parent = r

    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.45, -8, 1, 0)
    v.Position = UDim2.new(0.55, 0, 0, 0)
    v.BackgroundTransparency = 1
    v.Text = "—"
    v.TextColor3 = color or T.Text
    v.TextXAlignment = Enum.TextXAlignment.Right
    v.Font = T.FM
    v.TextSize = 10
    v.Parent = r
    return v
end

local FlyControls = Instance.new("Frame")
FlyControls.Size = UDim2.new(0, 170, 0, 104)
FlyControls.Position = UDim2.new(0.5, -85, 1, -120)
FlyControls.BackgroundColor3 = T.BgPanel
FlyControls.BackgroundTransparency = 0.2
FlyControls.Visible = false
FlyControls.ZIndex = 30
FlyControls.Parent = ScreenGui
corner(FlyControls, 6)
stroke(FlyControls, T.Neon, 1.2, 0.3)
cornerBrackets(FlyControls, T.Neon, 6, 2)

local function flyButton(text, x, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 34, 0, 34)
    b.Position = UDim2.new(0, x, 0, y)
    b.BackgroundColor3 = T.BgPanel2
    b.BackgroundTransparency = 0.1
    b.Text = text
    b.TextColor3 = color or T.Neon
    b.Font = T.FB
    b.TextSize = 14
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = FlyControls
    corner(b, 4)
    stroke(b, color or T.Neon, 1.2, 0.3)
    return b
end

local BtnUp    = flyButton("▲", 42, 4, T.Neon)
local BtnDown  = flyButton("▼", 42, 66, T.Purple)
local BtnLeft  = flyButton("◀", 4, 35, T.Neon)
local BtnRight = flyButton("▶", 80, 35, T.Neon)
local BtnRise  = flyButton("＋", 118, 4, T.Green)
local BtnFall  = flyButton("－", 118, 66, T.Red)

local function bindHold(btn, key)
    local function set(v)
        MobileInput[key] = v
        tween(btn, { BackgroundTransparency = v and 0.6 or 0.1 }, 0.1)
    end
    btn.MouseButton1Down:Connect(function() set(true) end)
    btn.MouseButton1Up:Connect(function() set(false) end)
    btn.MouseLeave:Connect(function() set(false) end)
end

bindHold(BtnUp, "Forward")
bindHold(BtnDown, "Back")
bindHold(BtnLeft, "Left")
bindHold(BtnRight, "Right")
bindHold(BtnRise, "Up")
bindHold(BtnFall, "Down")

local function clearMobileInput()
    for k in pairs(MobileInput) do MobileInput[k] = false end
    for _, b in ipairs({ BtnUp, BtnDown, BtnLeft, BtnRight, BtnRise, BtnFall }) do
        tween(b, { BackgroundTransparency = 0.1 }, 0.1)
    end
end

local powerCard = accordionCard("◆ 力量数据", T.Neon, true)

local rowStrength = infoRow(powerCard, "当前力量", T.Neon)
local rowSession  = infoRow(powerCard, "本次增长", T.Green)
local rowBefore   = infoRow(powerCard, "训练前", T.Yellow)
local rowPerRep   = infoRow(powerCard, "每次增量", T.Purple)

local trainCard = accordionCard("◆ 训练", T.Green, true)

local actionRow = Instance.new("Frame")
actionRow.Size = UDim2.new(1, 0, 0, 22)
actionRow.BackgroundTransparency = 1
actionRow.Parent = trainCard

local actionLbl = Instance.new("TextLabel")
actionLbl.Size = UDim2.new(0, 46, 1, 0)
actionLbl.BackgroundTransparency = 1
actionLbl.Text = "动作"
actionLbl.TextColor3 = T.TextDim
actionLbl.TextXAlignment = Enum.TextXAlignment.Left
actionLbl.Font = T.F
actionLbl.TextSize = 9
actionLbl.Parent = actionRow

local actionBtn = Instance.new("TextButton")
actionBtn.Size = UDim2.new(1, -46, 1, 0)
actionBtn.Position = UDim2.new(0, 46, 0, 0)
actionBtn.BackgroundColor3 = T.BgPanel2
actionBtn.Text = ActionNames[Config.Action] or Config.Action
actionBtn.TextColor3 = T.Neon
actionBtn.Font = T.F
actionBtn.TextSize = 10
actionBtn.AutoButtonColor = false
actionBtn.BorderSizePixel = 0
actionBtn.Parent = actionRow
corner(actionBtn, 3)
stroke(actionBtn, T.Stroke, 1, 0.3)

actionBtn.MouseEnter:Connect(function()
    tween(actionBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15)
end)
actionBtn.MouseLeave:Connect(function()
    tween(actionBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15)
end)

local actionIndex = 1
for i, v in ipairs(Actions) do
    if v == Config.Action then actionIndex = i break end
end

actionBtn.MouseButton1Click:Connect(function()
    actionIndex = actionIndex % #Actions + 1
    Config.Action = Actions[actionIndex]
    actionBtn.Text = ActionNames[Config.Action] or Config.Action
    saveConfig()
    updateStatus()
end)

local intervalRow = Instance.new("Frame")
intervalRow.Size = UDim2.new(1, 0, 0, 22)
intervalRow.BackgroundTransparency = 1
intervalRow.Parent = trainCard

local intervalLbl = Instance.new("TextLabel")
intervalLbl.Size = UDim2.new(0, 46, 1, 0)
intervalLbl.BackgroundTransparency = 1
intervalLbl.Text = "间隔"
intervalLbl.TextColor3 = T.TextDim
intervalLbl.TextXAlignment = Enum.TextXAlignment.Left
intervalLbl.Font = T.F
intervalLbl.TextSize = 9
intervalLbl.Parent = intervalRow

local intervalBox = Instance.new("TextBox")
intervalBox.Size = UDim2.new(1, -46, 1, 0)
intervalBox.Position = UDim2.new(0, 46, 0, 0)
intervalBox.BackgroundColor3 = T.BgPanel2
intervalBox.Text = tostring(Config.Interval)
intervalBox.TextColor3 = T.Neon
intervalBox.PlaceholderText = "0.1"
intervalBox.PlaceholderColor3 = T.TextDim
intervalBox.Font = T.FM
intervalBox.TextSize = 10
intervalBox.ClearTextOnFocus = false
intervalBox.BorderSizePixel = 0
intervalBox.Parent = intervalRow
corner(intervalBox, 3)
stroke(intervalBox, T.Stroke, 1, 0.3)

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
        startGrad.Color = ColorSequence.new(
            Color3.fromRGB(255, 100, 130),
            Color3.fromRGB(180, 30, 60)
        )
        startStroke.Color = T.Red
    else
        startBtn.Text = "▶  开始训练"
        startBtn.TextColor3 = T.BgDeep
        startGrad.Color = ColorSequence.new(
            Color3.fromRGB(0, 255, 180),
            Color3.fromRGB(0, 150, 100)
        )
        startStroke.Color = T.Green
    end
end

startBtn.MouseEnter:Connect(function() tween(startBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
startBtn.MouseLeave:Connect(function() tween(startBtn, { BackgroundTransparency = 0 }, 0.15) end)

local skyEggCard = accordionCard("◆ 天空蛋 X5 抽取", T.Sky, false)

local skyParamRow = Instance.new("Frame")
skyParamRow.Size = UDim2.new(1, 0, 0, 28)
skyParamRow.BackgroundColor3 = T.BgPanel2
skyParamRow.BackgroundTransparency = 0.4
skyParamRow.Parent = skyEggCard
corner(skyParamRow, 4)
stroke(skyParamRow, T.Sky, 1.2, 0.3)

local skyParamIcon = Instance.new("TextLabel")
skyParamIcon.Size = UDim2.new(0, 24, 1, 0)
skyParamIcon.Position = UDim2.new(0, 6, 0, 0)
skyParamIcon.BackgroundTransparency = 1
skyParamIcon.Text = "🥚"
skyParamIcon.TextColor3 = T.Sky
skyParamIcon.Font = T.FB
skyParamIcon.TextSize = 14
skyParamIcon.Parent = skyParamRow

local skyParamLbl = Instance.new("TextLabel")
skyParamLbl.Size = UDim2.new(1, -36, 1, 0)
skyParamLbl.Position = UDim2.new(0, 30, 0, 0)
skyParamLbl.BackgroundTransparency = 1
skyParamLbl.Text = "SkyPetEgg × 5  ·  货币: Gem"
skyParamLbl.TextColor3 = T.Sky
skyParamLbl.TextXAlignment = Enum.TextXAlignment.Left
skyParamLbl.Font = T.FM
skyParamLbl.TextSize = 10
skyParamLbl.Parent = skyParamRow

EggToggleRefs.SkyEggAuto = toggleRow(skyEggCard, "自动开蛋", "SkyEggAuto")
floatInput(skyEggCard, "间隔(秒)", "SkyEggInterval", 0.1, 30)

local skyEggTotalLbl = infoRow(skyEggCard, "累计开蛋", T.Sky)

local skyEggOpenBtn = Instance.new("TextButton")
skyEggOpenBtn.Size = UDim2.new(1, 0, 0, 26)
skyEggOpenBtn.BackgroundColor3 = T.Sky
skyEggOpenBtn.Text = "🥚  立即抽取一次 (× 5)"
skyEggOpenBtn.TextColor3 = T.BgDeep
skyEggOpenBtn.Font = T.FB
skyEggOpenBtn.TextSize = 11
skyEggOpenBtn.AutoButtonColor = false
skyEggOpenBtn.BorderSizePixel = 0
skyEggOpenBtn.Parent = skyEggCard
corner(skyEggOpenBtn, 4)
gradientMulti(skyEggOpenBtn, {
    {0, Color3.fromRGB(150, 220, 255)},
    {1, T.SkyDark},
}, 90)
stroke(skyEggOpenBtn, T.Sky, 1.2, 0.2)

skyEggOpenBtn.MouseEnter:Connect(function() tween(skyEggOpenBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
skyEggOpenBtn.MouseLeave:Connect(function() tween(skyEggOpenBtn, { BackgroundTransparency = 0 }, 0.15) end)

local skyEggResetBtn = Instance.new("TextButton")
skyEggResetBtn.Size = UDim2.new(1, 0, 0, 20)
skyEggResetBtn.BackgroundColor3 = T.BgPanel2
skyEggResetBtn.Text = "⟲  重置开蛋计数"
skyEggResetBtn.TextColor3 = T.Red
skyEggResetBtn.Font = T.FM
skyEggResetBtn.TextSize = 9
skyEggResetBtn.AutoButtonColor = false
skyEggResetBtn.BorderSizePixel = 0
skyEggResetBtn.Parent = skyEggCard
corner(skyEggResetBtn, 3)
stroke(skyEggResetBtn, T.Red, 1, 0.4)

skyEggResetBtn.MouseEnter:Connect(function() tween(skyEggResetBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
skyEggResetBtn.MouseLeave:Connect(function() tween(skyEggResetBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)

skyEggResetBtn.MouseButton1Click:Connect(function()
    skyEggTotal = 0
    Config.SkyEggTotal = 0
    saveConfig()
    skyEggTotalLbl.Text = "0"
    notify("天空蛋计数已重置", T.Neon)
end)

skyEggTotalLbl.Text = tostring(skyEggTotal)

local function fireSkyEgg(silent)
    if not StoreEvent then
        if not silent then notify("未找到开蛋事件", T.Red) end
        return false
    end
    if isBackpackFull() then
        if not silent then notify("背包已满，无法开蛋", T.Red) end
        return false
    end
    local ok = pcall(function()
        StoreEvent:FireServer("Egg", EGG_DEFS.sky.count, EGG_DEFS.sky.currency, EGG_DEFS.sky.name)
    end)
    if ok then
        skyEggTotal = skyEggTotal + EGG_DEFS.sky.count
        Config.SkyEggTotal = skyEggTotal
        skyEggTotalLbl.Text = tostring(skyEggTotal)
        saveConfig()
    end
    return ok
end

skyEggOpenBtn.MouseButton1Click:Connect(function()
    if fireSkyEgg() then
        notify("已抽取天空蛋 × " .. EGG_DEFS.sky.count, T.Sky)
    end
end)

local bpDivider = Instance.new("Frame")
bpDivider.Size = UDim2.new(1, 0, 0, 1)
bpDivider.BackgroundColor3 = T.Sky
bpDivider.BackgroundTransparency = 0.7
bpDivider.BorderSizePixel = 0
bpDivider.Parent = skyEggCard

local bpTitle = Instance.new("TextLabel")
bpTitle.Size = UDim2.new(1, 0, 0, 12)
bpTitle.BackgroundTransparency = 1
bpTitle.Text = "› 背包共享设置"
bpTitle.TextColor3 = T.Sky
bpTitle.TextXAlignment = Enum.TextXAlignment.Left
bpTitle.Font = T.FB
bpTitle.TextSize = 8
bpTitle.Parent = skyEggCard

toggleRow(skyEggCard, "背包满自动停", "EggStopWhenFull")
numberInput(skyEggCard, "背包上限", "EggMaxBackpack", 1, 99999)

local backpackLbl = infoRow(skyEggCard, "背包占用", T.Green)

local lavaEggCard = accordionCard("◆ 岩浆蛋 X5 抽取", T.Lava, false)

local lavaParamRow = Instance.new("Frame")
lavaParamRow.Size = UDim2.new(1, 0, 0, 28)
lavaParamRow.BackgroundColor3 = T.BgPanel2
lavaParamRow.BackgroundTransparency = 0.4
lavaParamRow.Parent = lavaEggCard
corner(lavaParamRow, 4)
stroke(lavaParamRow, T.Lava, 1.2, 0.3)

local lavaParamIcon = Instance.new("TextLabel")
lavaParamIcon.Size = UDim2.new(0, 24, 1, 0)
lavaParamIcon.Position = UDim2.new(0, 6, 0, 0)
lavaParamIcon.BackgroundTransparency = 1
lavaParamIcon.Text = "🌋"
lavaParamIcon.TextColor3 = T.Lava
lavaParamIcon.Font = T.FB
lavaParamIcon.TextSize = 14
lavaParamIcon.Parent = lavaParamRow

local lavaParamLbl = Instance.new("TextLabel")
lavaParamLbl.Size = UDim2.new(1, -36, 1, 0)
lavaParamLbl.Position = UDim2.new(0, 30, 0, 0)
lavaParamLbl.BackgroundTransparency = 1
lavaParamLbl.Text = "LavaPetEgg × 5  ·  货币: Gem"
lavaParamLbl.TextColor3 = T.Lava
lavaParamLbl.TextXAlignment = Enum.TextXAlignment.Left
lavaParamLbl.Font = T.FM
lavaParamLbl.TextSize = 10
lavaParamLbl.Parent = lavaParamRow

EggToggleRefs.LavaEggAuto = toggleRow(lavaEggCard, "自动开蛋", "LavaEggAuto")
floatInput(lavaEggCard, "间隔(秒)", "LavaEggInterval", 0.1, 30)

local lavaEggTotalLbl = infoRow(lavaEggCard, "累计开蛋", T.Lava)

local lavaEggOpenBtn = Instance.new("TextButton")
lavaEggOpenBtn.Size = UDim2.new(1, 0, 0, 26)
lavaEggOpenBtn.BackgroundColor3 = T.Lava
lavaEggOpenBtn.Text = "🌋  立即抽取一次 (× 5)"
lavaEggOpenBtn.TextColor3 = T.BgDeep
lavaEggOpenBtn.Font = T.FB
lavaEggOpenBtn.TextSize = 11
lavaEggOpenBtn.AutoButtonColor = false
lavaEggOpenBtn.BorderSizePixel = 0
lavaEggOpenBtn.Parent = lavaEggCard
corner(lavaEggOpenBtn, 4)
gradientMulti(lavaEggOpenBtn, {
    {0, Color3.fromRGB(255, 150, 100)},
    {1, T.LavaDark},
}, 90)
stroke(lavaEggOpenBtn, T.Lava, 1.2, 0.2)

lavaEggOpenBtn.MouseEnter:Connect(function() tween(lavaEggOpenBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
lavaEggOpenBtn.MouseLeave:Connect(function() tween(lavaEggOpenBtn, { BackgroundTransparency = 0 }, 0.15) end)

local lavaEggResetBtn = Instance.new("TextButton")
lavaEggResetBtn.Size = UDim2.new(1, 0, 0, 20)
lavaEggResetBtn.BackgroundColor3 = T.BgPanel2
lavaEggResetBtn.Text = "⟲  重置开蛋计数"
lavaEggResetBtn.TextColor3 = T.Red
lavaEggResetBtn.Font = T.FM
lavaEggResetBtn.TextSize = 9
lavaEggResetBtn.AutoButtonColor = false
lavaEggResetBtn.BorderSizePixel = 0
lavaEggResetBtn.Parent = lavaEggCard
corner(lavaEggResetBtn, 3)
stroke(lavaEggResetBtn, T.Red, 1, 0.4)

lavaEggResetBtn.MouseEnter:Connect(function() tween(lavaEggResetBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
lavaEggResetBtn.MouseLeave:Connect(function() tween(lavaEggResetBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)

lavaEggResetBtn.MouseButton1Click:Connect(function()
    lavaEggTotal = 0
    Config.LavaEggTotal = 0
    saveConfig()
    lavaEggTotalLbl.Text = "0"
    notify("岩浆蛋计数已重置", T.Neon)
end)

lavaEggTotalLbl.Text = tostring(lavaEggTotal)

local function fireLavaEgg(silent)
    if not StoreEvent then
        if not silent then notify("未找到开蛋事件", T.Red) end
        return false
    end
    if isBackpackFull() then
        if not silent then notify("背包已满，无法开蛋", T.Red) end
        return false
    end
    local ok = pcall(function()
        StoreEvent:FireServer("Egg", EGG_DEFS.lava.count, EGG_DEFS.lava.currency, EGG_DEFS.lava.name)
    end)
    if ok then
        lavaEggTotal = lavaEggTotal + EGG_DEFS.lava.count
        Config.LavaEggTotal = lavaEggTotal
        lavaEggTotalLbl.Text = tostring(lavaEggTotal)
        saveConfig()
    end
    return ok
end

lavaEggOpenBtn.MouseButton1Click:Connect(function()
    if fireLavaEgg() then
        notify("已抽取岩浆蛋 × " .. EGG_DEFS.lava.count, T.Lava)
    end
end)

local sandEggCard = accordionCard("◆ 沙漠蛋 X5 抽取", T.Sand, false)

local sandParamRow = Instance.new("Frame")
sandParamRow.Size = UDim2.new(1, 0, 0, 28)
sandParamRow.BackgroundColor3 = T.BgPanel2
sandParamRow.BackgroundTransparency = 0.4
sandParamRow.Parent = sandEggCard
corner(sandParamRow, 4)
stroke(sandParamRow, T.Sand, 1.2, 0.3)

local sandParamIcon = Instance.new("TextLabel")
sandParamIcon.Size = UDim2.new(0, 24, 1, 0)
sandParamIcon.Position = UDim2.new(0, 6, 0, 0)
sandParamIcon.BackgroundTransparency = 1
sandParamIcon.Text = "🏜️"
sandParamIcon.TextColor3 = T.Sand
sandParamIcon.Font = T.FB
sandParamIcon.TextSize = 14
sandParamIcon.Parent = sandParamRow

local sandParamLbl = Instance.new("TextLabel")
sandParamLbl.Size = UDim2.new(1, -36, 1, 0)
sandParamLbl.Position = UDim2.new(0, 30, 0, 0)
sandParamLbl.BackgroundTransparency = 1
sandParamLbl.Text = "SandPetEgg × 5  ·  货币: Gem"
sandParamLbl.TextColor3 = T.Sand
sandParamLbl.TextXAlignment = Enum.TextXAlignment.Left
sandParamLbl.Font = T.FM
sandParamLbl.TextSize = 10
sandParamLbl.Parent = sandParamRow

EggToggleRefs.SandEggAuto = toggleRow(sandEggCard, "自动开蛋", "SandEggAuto")
floatInput(sandEggCard, "间隔(秒)", "SandEggInterval", 0.1, 30)

local sandEggTotalLbl = infoRow(sandEggCard, "累计开蛋", T.Sand)

local sandEggOpenBtn = Instance.new("TextButton")
sandEggOpenBtn.Size = UDim2.new(1, 0, 0, 26)
sandEggOpenBtn.BackgroundColor3 = T.Sand
sandEggOpenBtn.Text = "🏜️  立即抽取一次 (× 5)"
sandEggOpenBtn.TextColor3 = T.BgDeep
sandEggOpenBtn.Font = T.FB
sandEggOpenBtn.TextSize = 11
sandEggOpenBtn.AutoButtonColor = false
sandEggOpenBtn.BorderSizePixel = 0
sandEggOpenBtn.Parent = sandEggCard
corner(sandEggOpenBtn, 4)
gradientMulti(sandEggOpenBtn, {
    {0, Color3.fromRGB(255, 225, 160)},
    {1, T.SandDark},
}, 90)
stroke(sandEggOpenBtn, T.Sand, 1.2, 0.2)

sandEggOpenBtn.MouseEnter:Connect(function() tween(sandEggOpenBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
sandEggOpenBtn.MouseLeave:Connect(function() tween(sandEggOpenBtn, { BackgroundTransparency = 0 }, 0.15) end)

local sandEggResetBtn = Instance.new("TextButton")
sandEggResetBtn.Size = UDim2.new(1, 0, 0, 20)
sandEggResetBtn.BackgroundColor3 = T.BgPanel2
sandEggResetBtn.Text = "⟲  重置开蛋计数"
sandEggResetBtn.TextColor3 = T.Red
sandEggResetBtn.Font = T.FM
sandEggResetBtn.TextSize = 9
sandEggResetBtn.AutoButtonColor = false
sandEggResetBtn.BorderSizePixel = 0
sandEggResetBtn.Parent = sandEggCard
corner(sandEggResetBtn, 3)
stroke(sandEggResetBtn, T.Red, 1, 0.4)

sandEggResetBtn.MouseEnter:Connect(function() tween(sandEggResetBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
sandEggResetBtn.MouseLeave:Connect(function() tween(sandEggResetBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)

sandEggResetBtn.MouseButton1Click:Connect(function()
    sandEggTotal = 0
    Config.SandEggTotal = 0
    saveConfig()
    sandEggTotalLbl.Text = "0"
    notify("沙漠蛋计数已重置", T.Neon)
end)

sandEggTotalLbl.Text = tostring(sandEggTotal)

local function fireSandEgg(silent)
    if not StoreEvent then
        if not silent then notify("未找到开蛋事件", T.Red) end
        return false
    end
    if isBackpackFull() then
        if not silent then notify("背包已满，无法开蛋", T.Red) end
        return false
    end
    local ok = pcall(function()
        StoreEvent:FireServer("Egg", EGG_DEFS.sand.count, EGG_DEFS.sand.currency, EGG_DEFS.sand.name)
    end)
    if ok then
        sandEggTotal = sandEggTotal + EGG_DEFS.sand.count
        Config.SandEggTotal = sandEggTotal
        sandEggTotalLbl.Text = tostring(sandEggTotal)
        saveConfig()
    end
    return ok
end

sandEggOpenBtn.MouseButton1Click:Connect(function()
    if fireSandEgg() then
        notify("已抽取沙漠蛋 × " .. EGG_DEFS.sand.count, T.Sand)
    end
end)

local jungleEggCard = accordionCard("◆ 主岛蛋 X5 抽取", T.Jungle, false)

local jParamRow = Instance.new("Frame")
jParamRow.Size = UDim2.new(1, 0, 0, 28)
jParamRow.BackgroundColor3 = T.BgPanel2
jParamRow.BackgroundTransparency = 0.4
jParamRow.Parent = jungleEggCard
corner(jParamRow, 4)
stroke(jParamRow, T.Jungle, 1.2, 0.3)

local jParamIcon = Instance.new("TextLabel")
jParamIcon.Size = UDim2.new(0, 24, 1, 0)
jParamIcon.Position = UDim2.new(0, 6, 0, 0)
jParamIcon.BackgroundTransparency = 1
jParamIcon.Text = "🌴"
jParamIcon.TextColor3 = T.Jungle
jParamIcon.Font = T.FB
jParamIcon.TextSize = 14
jParamIcon.Parent = jParamRow

local jParamLbl = Instance.new("TextLabel")
jParamLbl.Size = UDim2.new(1, -36, 1, 0)
jParamLbl.Position = UDim2.new(0, 30, 0, 0)
jParamLbl.BackgroundTransparency = 1
jParamLbl.Text = "JunglePetEgg × 5  ·  货币: Gem"
jParamLbl.TextColor3 = T.Jungle
jParamLbl.TextXAlignment = Enum.TextXAlignment.Left
jParamLbl.Font = T.FM
jParamLbl.TextSize = 10
jParamLbl.Parent = jParamRow

EggToggleRefs.JungleEggAuto = toggleRow(jungleEggCard, "自动开蛋", "JungleEggAuto")
floatInput(jungleEggCard, "间隔(秒)", "JungleEggInterval", 0.1, 30)

local jungleEggTotalLbl = infoRow(jungleEggCard, "累计开蛋", T.Jungle)

local jungleEggOpenBtn = Instance.new("TextButton")
jungleEggOpenBtn.Size = UDim2.new(1, 0, 0, 26)
jungleEggOpenBtn.BackgroundColor3 = T.Jungle
jungleEggOpenBtn.Text = "🌴  立即抽取一次 (× 5)"
jungleEggOpenBtn.TextColor3 = T.BgDeep
jungleEggOpenBtn.Font = T.FB
jungleEggOpenBtn.TextSize = 11
jungleEggOpenBtn.AutoButtonColor = false
jungleEggOpenBtn.BorderSizePixel = 0
jungleEggOpenBtn.Parent = jungleEggCard
corner(jungleEggOpenBtn, 4)
gradientMulti(jungleEggOpenBtn, {
    {0, Color3.fromRGB(170, 245, 175)},
    {1, T.JungleDark},
}, 90)
stroke(jungleEggOpenBtn, T.Jungle, 1.2, 0.2)

jungleEggOpenBtn.MouseEnter:Connect(function() tween(jungleEggOpenBtn, { BackgroundTransparency = 0.15 }, 0.15) end)
jungleEggOpenBtn.MouseLeave:Connect(function() tween(jungleEggOpenBtn, { BackgroundTransparency = 0 }, 0.15) end)

local jungleEggResetBtn = Instance.new("TextButton")
jungleEggResetBtn.Size = UDim2.new(1, 0, 0, 20)
jungleEggResetBtn.BackgroundColor3 = T.BgPanel2
jungleEggResetBtn.Text = "⟲  重置开蛋计数"
jungleEggResetBtn.TextColor3 = T.Red
jungleEggResetBtn.Font = T.FM
jungleEggResetBtn.TextSize = 9
jungleEggResetBtn.AutoButtonColor = false
jungleEggResetBtn.BorderSizePixel = 0
jungleEggResetBtn.Parent = jungleEggCard
corner(jungleEggResetBtn, 3)
stroke(jungleEggResetBtn, T.Red, 1, 0.4)

jungleEggResetBtn.MouseEnter:Connect(function() tween(jungleEggResetBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
jungleEggResetBtn.MouseLeave:Connect(function() tween(jungleEggResetBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)

jungleEggResetBtn.MouseButton1Click:Connect(function()
    jungleEggTotal = 0
    Config.JungleEggTotal = 0
    saveConfig()
    jungleEggTotalLbl.Text = "0"
    notify("主岛蛋计数已重置", T.Neon)
end)

jungleEggTotalLbl.Text = tostring(jungleEggTotal)

local function fireJungleEgg(silent)
    if not StoreEvent then
        if not silent then notify("未找到开蛋事件", T.Red) end
        return false
    end
    if isBackpackFull() then
        if not silent then notify("背包已满，无法开蛋", T.Red) end
        return false
    end
    local ok = pcall(function()
        StoreEvent:FireServer("Egg", EGG_DEFS.jungle.count, EGG_DEFS.jungle.currency, EGG_DEFS.jungle.name)
    end)
    if ok then
        jungleEggTotal = jungleEggTotal + EGG_DEFS.jungle.count
        Config.JungleEggTotal = jungleEggTotal
        jungleEggTotalLbl.Text = tostring(jungleEggTotal)
        saveConfig()
    end
    return ok
end

jungleEggOpenBtn.MouseButton1Click:Connect(function()
    if fireJungleEgg() then
        notify("已抽取主岛蛋 × " .. EGG_DEFS.jungle.count, T.Jungle)
    end
end)

local autoCard = accordionCard("◆ 自动重生", T.Purple, false)

toggleRow(autoCard, "自动重生", "AutoRebirth")
toggleRow(autoCard, "反挂机", "AntiAfk")
toggleRow(autoCard, "自动重置", "AutoReset")
toggleRow(autoCard, "通知提示", "Notifications")

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = T.Purple
divider.BackgroundTransparency = 0.7
divider.BorderSizePixel = 0
divider.Parent = autoCard

local titleRow = Instance.new("Frame")
titleRow.Size = UDim2.new(1, 0, 0, 12)
titleRow.BackgroundTransparency = 1
titleRow.Parent = autoCard

local titleTxt = Instance.new("TextLabel")
titleTxt.Size = UDim2.new(1, 0, 1, 0)
titleTxt.BackgroundTransparency = 1
titleTxt.Text = "› 自定义重生次数"
titleTxt.TextColor3 = T.Purple
titleTxt.TextXAlignment = Enum.TextXAlignment.Left
titleTxt.Font = T.FB
titleTxt.TextSize = 8
titleTxt.Parent = titleRow

local countRow = Instance.new("Frame")
countRow.Size = UDim2.new(1, 0, 0, 24)
countRow.BackgroundTransparency = 1
countRow.Parent = autoCard

local minusBtn = Instance.new("TextButton")
minusBtn.Size = UDim2.new(0, 24, 1, 0)
minusBtn.BackgroundColor3 = T.BgPanel2
minusBtn.Text = "−"
minusBtn.TextColor3 = T.Red
minusBtn.Font = T.FB
minusBtn.TextSize = 13
minusBtn.AutoButtonColor = false
minusBtn.BorderSizePixel = 0
minusBtn.Parent = countRow
corner(minusBtn, 3)
stroke(minusBtn, T.Red, 1, 0.3)

local countBox = Instance.new("TextBox")
countBox.Size = UDim2.new(1, -56, 1, 0)
countBox.Position = UDim2.new(0, 28, 0, 0)
countBox.BackgroundColor3 = T.BgPanel2
countBox.Text = tostring(Config.AutoRebirthCount)
countBox.TextColor3 = T.Purple
countBox.Font = T.FM
countBox.TextSize = 11
countBox.ClearTextOnFocus = false
countBox.BorderSizePixel = 0
countBox.Parent = countRow
corner(countBox, 3)
stroke(countBox, T.Purple, 1.2, 0.3)

local plusBtn = Instance.new("TextButton")
plusBtn.Size = UDim2.new(0, 24, 1, 0)
plusBtn.Position = UDim2.new(1, -24, 0, 0)
plusBtn.BackgroundColor3 = T.BgPanel2
plusBtn.Text = "+"
plusBtn.TextColor3 = T.Green
plusBtn.Font = T.FB
plusBtn.TextSize = 13
plusBtn.AutoButtonColor = false
plusBtn.BorderSizePixel = 0
plusBtn.Parent = countRow
corner(plusBtn, 3)
stroke(plusBtn, T.Green, 1, 0.3)

local function commitCount(n)
    n = math.clamp(math.floor(tonumber(n) or 0), 0, 99999)
    Config.AutoRebirthCount = n
    countBox.Text = tostring(n)
    saveConfig()
    if updateRebirthDisplay then updateRebirthDisplay() end
end

minusBtn.MouseButton1Click:Connect(function()
    local step = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 10 or 1
    commitCount(Config.AutoRebirthCount - step)
end)

plusBtn.MouseButton1Click:Connect(function()
    local step = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 10 or 1
    commitCount(Config.AutoRebirthCount + step)
end)

countBox.FocusLost:Connect(function()
    local n = tonumber(countBox.Text)
    if n and n >= 0 and n <= 99999 then
        commitCount(n)
    else
        countBox.Text = tostring(Config.AutoRebirthCount)
        notify("范围 0 ~ 99999", T.Red)
    end
end)

minusBtn.MouseEnter:Connect(function() tween(minusBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
minusBtn.MouseLeave:Connect(function() tween(minusBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)
plusBtn.MouseEnter:Connect(function() tween(plusBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
plusBtn.MouseLeave:Connect(function() tween(plusBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)

local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, 0, 0, 24)
statsRow.BackgroundColor3 = T.BgPanel2
statsRow.BackgroundTransparency = 0.4
statsRow.Parent = autoCard
corner(statsRow, 3)
stroke(statsRow, T.Purple, 1, 0.4)

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

local slash = Instance.new("TextLabel")
slash.Size = UDim2.new(0, 10, 1, 0)
slash.Position = UDim2.new(0.5, -5, 0, 0)
slash.BackgroundTransparency = 1
slash.Text = "/"
slash.TextColor3 = T.TextSub
slash.Font = T.FB
slash.TextSize = 10
slash.Parent = statsRow

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, 0, 0, 4)
barBg.BackgroundColor3 = T.BgPanel2
barBg.BorderSizePixel = 0
barBg.Parent = autoCard
corner(barBg, 3)
stroke(barBg, T.Stroke, 1, 0.5)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = T.Green
barFill.BorderSizePixel = 0
barFill.Parent = barBg
corner(barFill, 3)
gradient(barFill, T.Green, T.Neon, 0)

updateRebirthDisplay = function()
    doneLbl.Text = tostring(Config.AutoRebirthDone)
    if Config.AutoRebirthCount == 0 then
        targetLbl.Text = "∞"
        targetLbl.TextColor3 = T.Purple
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = T.Purple
    else
        targetLbl.Text = tostring(Config.AutoRebirthCount)
        targetLbl.TextColor3 = T.Purple
        local pct = math.clamp(Config.AutoRebirthDone / Config.AutoRebirthCount, 0, 1)
        barFill.Size = UDim2.new(pct, 0, 1, 0)
        if pct >= 1 then
            barFill.BackgroundColor3 = T.Green
        elseif pct >= 0.5 then
            barFill.BackgroundColor3 = T.Neon
        else
            barFill.BackgroundColor3 = T.Purple
        end
    end
end
updateRebirthDisplay()

local resetRebirthBtn = Instance.new("TextButton")
resetRebirthBtn.Size = UDim2.new(1, 0, 0, 20)
resetRebirthBtn.BackgroundColor3 = T.BgPanel2
resetRebirthBtn.Text = "⟲  重置计数"
resetRebirthBtn.TextColor3 = T.Red
resetRebirthBtn.Font = T.FM
resetRebirthBtn.TextSize = 9
resetRebirthBtn.AutoButtonColor = false
resetRebirthBtn.BorderSizePixel = 0
resetRebirthBtn.Parent = autoCard
corner(resetRebirthBtn, 3)
stroke(resetRebirthBtn, T.Red, 1, 0.4)

resetRebirthBtn.MouseEnter:Connect(function()
    tween(resetRebirthBtn, { BackgroundColor3 = T.BgPanelHi }, 0.15)
end)
resetRebirthBtn.MouseLeave:Connect(function()
    tween(resetRebirthBtn, { BackgroundColor3 = T.BgPanel2 }, 0.15)
end)

resetRebirthBtn.MouseButton1Click:Connect(function()
    Config.AutoRebirthDone = 0
    saveConfig()
    updateRebirthDisplay()
    notify("计数已重置", T.Neon)
end)

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
    flyBG.P = 3000
    flyBG.D = 500
    flyBG.Parent = hrp

    flying = true
end

stopFly = function()
    if not flying then return end
    flying = false
    clearMobileInput()
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

    local fwd = UserInputService:IsKeyDown(Enum.KeyCode.W) or MobileInput.Forward
    local bck = UserInputService:IsKeyDown(Enum.KeyCode.S) or MobileInput.Back
    local lft = UserInputService:IsKeyDown(Enum.KeyCode.A) or MobileInput.Left
    local rgt = UserInputService:IsKeyDown(Enum.KeyCode.D) or MobileInput.Right
    local up  = UserInputService:IsKeyDown(Enum.KeyCode.Space) or MobileInput.Up
    local dn  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or MobileInput.Down

    if fwd then dir = dir + cam.CFrame.LookVector end
    if bck then dir = dir - cam.CFrame.LookVector end
    if lft then dir = dir - cam.CFrame.RightVector end
    if rgt then dir = dir + cam.CFrame.RightVector end
    if up  then dir = dir + Vector3.new(0, 1, 0) end
    if dn  then dir = dir - Vector3.new(0, 1, 0) end

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
    if on then
        startFly()
        if IS_TOUCH then FlyControls.Visible = true end
        if IS_TOUCH then
            notify("飞行开启 — 方向键", T.Neon)
        else
            notify("飞行开启 — 空格/左Ctrl", T.Neon)
        end
    else
        stopFly()
        FlyControls.Visible = false
        notify("飞行关闭", T.Red)
    end
end)

numberInput(moveCard, "步行速度", "WalkSpeed", 16, 500, function(v)
    Config.WalkSpeed = v
    applyWalkSpeed()
end)

numberInput(moveCard, "飞行速度", "FlySpeed", 10, 500, function(v)
    flySpeed = v
end)

local statCard = accordionCard("◆ 统计", T.Yellow, false)

local statSession = infoRow(statCard, "本次训练", T.Text)
local statTotal = infoRow(statCard, "累计训练", T.Text)
local statRate = infoRow(statCard, "每秒平均", T.Text)

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

local statusDotGlow = Instance.new("Frame")
statusDotGlow.Size = UDim2.new(0, 10, 0, 10)
statusDotGlow.Position = UDim2.new(0, 10, 0, 8)
statusDotGlow.BackgroundColor3 = T.Red
statusDotGlow.BackgroundTransparency = 0.6
statusDotGlow.BorderSizePixel = 0
statusDotGlow.ZIndex = 4
statusDotGlow.Parent = Bottom
corner(statusDotGlow, 5)

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
hintLbl.Text = IS_TOUCH and "// 点标题折叠" or "// 点标题 · RS 开关"
hintLbl.TextColor3 = T.TextSub
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Font = T.FM
hintLbl.TextSize = 7
hintLbl.ZIndex = 5
hintLbl.Parent = Bottom

local ResizeGrip = Instance.new("Frame")
ResizeGrip.Size = UDim2.new(0, 12, 0, 12)
ResizeGrip.Position = UDim2.new(1, -16, 1, -16)
ResizeGrip.BackgroundTransparency = 1
ResizeGrip.ZIndex = 20
ResizeGrip.Parent = Main

for i = 1, 3 do
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 2, 0, 2)
    dot.Position = UDim2.new(0, 9 - i * 3, 0, 9 - i * 3)
    dot.BackgroundColor3 = T.Neon
    dot.BorderSizePixel = 0
    dot.Parent = ResizeGrip
    corner(dot, 1)
end

local ResizeBtn = Instance.new("TextButton")
ResizeBtn.Size = UDim2.new(1, 0, 1, 0)
ResizeBtn.BackgroundTransparency = 1
ResizeBtn.Text = ""
ResizeBtn.AutoButtonColor = false
ResizeBtn.Parent = ResizeGrip

local BallBtn = Instance.new("TextButton")
BallBtn.Size = UDim2.new(1, 0, 1, 0)
BallBtn.BackgroundTransparency = 1
BallBtn.Text = "力"
BallBtn.TextColor3 = T.BgDeep
BallBtn.Font = T.FB
BallBtn.TextSize = 18
BallBtn.AutoButtonColor = false
BallBtn.Visible = false
BallBtn.ZIndex = 25
BallBtn.Parent = Main

local DataPanel = Instance.new("Frame")
DataPanel.Size = UDim2.new(0, 220, 0, 290)
DataPanel.Position = UDim2.new(0, 330, 0.5, -145)
DataPanel.BackgroundColor3 = T.BgDeep
DataPanel.BorderSizePixel = 0
DataPanel.Active = true
DataPanel.ClipsDescendants = true
DataPanel.Visible = false
DataPanel.ZIndex = 40
DataPanel.Parent = ScreenGui
corner(DataPanel, 6)
stroke(DataPanel, T.Neon, 1.2, 0.35)
gradientMulti(DataPanel, {
    {0, T.BgPanel},
    {0.5, T.BgDeep},
    {1, Color3.fromRGB(6, 12, 20)},
}, 135)
addGrid(DataPanel, 30, 30)
cornerBrackets(DataPanel, T.Neon, 8, 2)

local DataPanelAccent = Instance.new("Frame")
DataPanelAccent.Size = UDim2.new(1, 0, 0, 2)
DataPanelAccent.BackgroundColor3 = T.Neon
DataPanelAccent.BorderSizePixel = 0
DataPanelAccent.ZIndex = 8
DataPanelAccent.Parent = DataPanel
gradientMulti(DataPanelAccent, {
    {0, T.Neon}, {0.35, T.Purple}, {0.7, T.Neon2}, {1, T.Neon},
}, 0)

local DataHeader = Instance.new("Frame")
DataHeader.Size = UDim2.new(1, 0, 0, 32)
DataHeader.BackgroundColor3 = T.BgPanel
DataHeader.BackgroundTransparency = 0.1
DataHeader.BorderSizePixel = 0
DataHeader.ZIndex = 3
DataHeader.Parent = DataPanel

local DataHeaderLine = Instance.new("Frame")
DataHeaderLine.Size = UDim2.new(1, 0, 0, 1)
DataHeaderLine.Position = UDim2.new(0, 0, 1, -1)
DataHeaderLine.BackgroundColor3 = T.Neon
DataHeaderLine.BackgroundTransparency = 0.4
DataHeaderLine.BorderSizePixel = 0
DataHeaderLine.ZIndex = 4
DataHeaderLine.Parent = DataHeader
gradientMulti(DataHeaderLine, {{0, T.Neon}, {0.5, T.Neon2}, {1, T.Neon}}, 0)

local DataTitle = Instance.new("TextLabel")
DataTitle.Size = UDim2.new(1, -60, 1, 0)
DataTitle.Position = UDim2.new(0, 12, 0, 0)
DataTitle.BackgroundTransparency = 1
DataTitle.Text = "◆ 数据面板"
DataTitle.TextColor3 = T.Neon
DataTitle.TextXAlignment = Enum.TextXAlignment.Left
DataTitle.Font = T.FB
DataTitle.TextSize = 10
DataTitle.ZIndex = 5
DataTitle.Parent = DataHeader

local DataCloseBtn = Instance.new("TextButton")
DataCloseBtn.Size = UDim2.new(0, 20, 0, 20)
DataCloseBtn.Position = UDim2.new(1, -24, 0.5, -10)
DataCloseBtn.BackgroundColor3 = T.RedDim
DataCloseBtn.BackgroundTransparency = 0.4
DataCloseBtn.Text = "×"
DataCloseBtn.TextColor3 = T.Text
DataCloseBtn.Font = T.FB
DataCloseBtn.TextSize = 12
DataCloseBtn.AutoButtonColor = false
DataCloseBtn.BorderSizePixel = 0
DataCloseBtn.ZIndex = 5
DataCloseBtn.Parent = DataHeader
corner(DataCloseBtn, 3)
stroke(DataCloseBtn, T.Red, 1, 0.3)
DataCloseBtn.MouseEnter:Connect(function()
    tween(DataCloseBtn, { BackgroundTransparency = 0.1, TextColor3 = T.Red }, 0.15)
end)
DataCloseBtn.MouseLeave:Connect(function()
    tween(DataCloseBtn, { BackgroundTransparency = 0.4, TextColor3 = T.Text }, 0.15)
end)

local DataContent = Instance.new("ScrollingFrame")
DataContent.Size = UDim2.new(1, 0, 1, -32)
DataContent.Position = UDim2.new(0, 0, 0, 32)
DataContent.BackgroundTransparency = 1
DataContent.BorderSizePixel = 0
DataContent.ScrollBarThickness = 2
DataContent.ScrollBarImageColor3 = T.Neon
DataContent.ScrollBarImageTransparency = 0.4
DataContent.ScrollingDirection = Enum.ScrollingDirection.Y
DataContent.CanvasSize = UDim2.new(0, 0, 0, 0)
DataContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
DataContent.ZIndex = 2
DataContent.Parent = DataPanel
paddingSides(DataContent, 8, 8, 8, 8)

local DataContentLayout = Instance.new("UIListLayout")
DataContentLayout.FillDirection = Enum.FillDirection.Vertical
DataContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
DataContentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
DataContentLayout.Padding = UDim.new(0, 6)
DataContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
DataContentLayout.Parent = DataContent

local DataRows = {}
for _, def in ipairs(STAT_DEFS) do
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 44)
    card.BackgroundColor3 = T.BgPanel
    card.BackgroundTransparency = 0.15
    card.BorderSizePixel = 0
    card.Parent = DataContent
    corner(card, 4)
    stroke(card, def.color, 1, 0.4)

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 1.5)
    topBar.BackgroundColor3 = def.color
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 3
    topBar.Parent = card
    gradient(topBar, def.color, Color3.fromRGB(
        math.floor(def.color.R * 255 * 0.5),
        math.floor(def.color.G * 255 * 0.5),
        math.floor(def.color.B * 255 * 0.5)
    ), 0)

    local leftBar = Instance.new("Frame")
    leftBar.Size = UDim2.new(0, 2, 0, 14)
    leftBar.Position = UDim2.new(0, 8, 0, 8)
    leftBar.BackgroundColor3 = def.color
    leftBar.BorderSizePixel = 0
    leftBar.ZIndex = 3
    leftBar.Parent = card
    corner(leftBar, 2)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.5, -16, 0, 14)
    nameLbl.Position = UDim2.new(0, 16, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = def.label
    nameLbl.TextColor3 = def.color
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Font = T.FB
    nameLbl.TextSize = 10
    nameLbl.ZIndex = 3
    nameLbl.Parent = card

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(1, -16, 0, 18)
    valueLbl.Position = UDim2.new(0, 16, 0, 20)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = "—"
    valueLbl.TextColor3 = T.Text
    valueLbl.TextXAlignment = Enum.TextXAlignment.Left
    valueLbl.Font = T.FM
    valueLbl.TextSize = 13
    valueLbl.ZIndex = 3
    valueLbl.Parent = card

    local estLbl = Instance.new("TextLabel")
    estLbl.Size = UDim2.new(0.5, -12, 0, 12)
    estLbl.Position = UDim2.new(0.5, 4, 0, 26)
    estLbl.BackgroundTransparency = 1
    estLbl.Text = ""
    estLbl.TextColor3 = T.TextDim
    estLbl.TextXAlignment = Enum.TextXAlignment.Right
    estLbl.Font = T.FM
    estLbl.TextSize = 8
    estLbl.ZIndex = 3
    estLbl.Parent = card

    DataRows[def.key] = { value = valueLbl, est = estLbl, def = def }
end

local function openDataPanel()
    DataPanelOpen = true
    Config.DataPanelOpen = true
    DataPanel.Visible = true
    saveConfig()
    notify("数据面板已开启", T.Neon)
end

local function closeDataPanel()
    DataPanelOpen = false
    Config.DataPanelOpen = false
    DataPanel.Visible = false
    saveConfig()
    notify("数据面板已关闭", T.Red)
end

DataBtn.MouseButton1Click:Connect(function()
    if DataPanelOpen then
        closeDataPanel()
    else
        openDataPanel()
    end
end)

DataCloseBtn.MouseButton1Click:Connect(closeDataPanel)

if Config.DataPanelOpen then
    DataPanel.Visible = true
    DataPanelOpen = true
end

do
    local dragging, dragStart, startPos = false, nil, nil
    DataHeader.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = DataPanel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            DataPanel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

updateStatus = function()
    if isTraining then
        statusDot.BackgroundColor3 = T.Green
        statusDotGlow.BackgroundColor3 = T.Green
        HeaderDot.BackgroundColor3 = T.Green
        HeaderDotGlow.BackgroundColor3 = T.Green
        statusLbl.Text = "运行中  ·  " .. (ActionNames[Config.Action] or Config.Action)
        statusLbl.TextColor3 = T.Green
        if isCollapsed then Main.BackgroundColor3 = T.Green end
    else
        statusDot.BackgroundColor3 = T.Red
        statusDotGlow.BackgroundColor3 = T.Red
        HeaderDot.BackgroundColor3 = T.Red
        HeaderDotGlow.BackgroundColor3 = T.Red
        statusLbl.Text = "待机中"
        statusLbl.TextColor3 = T.Text
        if isCollapsed then Main.BackgroundColor3 = T.Red end
    end
end

collapse = function()
    if isCollapsed then return end
    savedSize = Main.Size
    isCollapsed = true
    accentBar.Visible = false
    accentGlow.Visible = false
    Header.Visible = false
    Content.Visible = false
    Bottom.Visible = false
    ResizeGrip.Visible = false
    mainCorner.CornerRadius = UDim.new(1, 0)
    mainStroke.Transparency = 0.2
    bgGrad.Color = ColorSequence.new(
        isTraining and T.Green or T.Red,
        isTraining and T.GreenDim or T.RedDim
    )
    tween(Main, {
        Size = UDim2.new(0, COLLAPSED, 0, COLLAPSED),
        BackgroundColor3 = isTraining and T.Green or T.Red,
    }, 0.3, Enum.EasingStyle.Back)
    BallBtn.Visible = true
end

expand = function()
    if not isCollapsed then return end
    isCollapsed = false
    mainCorner.CornerRadius = UDim.new(0, 6)
    mainStroke.Transparency = 0.35
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, T.BgPanel),
        ColorSequenceKeypoint.new(0.5, T.BgDeep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 12, 20)),
    })
    tween(Main, {
        Size = savedSize or UDim2.new(0, W, 0, H),
        BackgroundColor3 = T.BgDeep,
    }, 0.3, Enum.EasingStyle.Back)
    accentBar.Visible = true
    accentGlow.Visible = true
    Header.Visible = true
    Content.Visible = true
    Bottom.Visible = true
    ResizeGrip.Visible = true
    BallBtn.Visible = false
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
            local ok = pcall(function() TrainEvent:FireServer(Config.Action) end)
            if ok then
                trainCount = trainCount + 1
                totalCount = totalCount + 1
                Config.TotalReps = totalCount
            end
            safeWait(Config.Interval)
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

do
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    BallBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if not moved then expand() end
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then moved = true end
            Main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

do
    local resizing = false
    local resizeStart, startSize
    ResizeBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = input.Position
            startSize = Main.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - resizeStart
            local nw = math.clamp(startSize.X + delta.X, MIN_W, MAX_W)
            local nh = math.clamp(startSize.Y + delta.Y, MIN_H, MAX_H)
            Main.Size = UDim2.new(0, nw, 0, nh)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if resizing then
                resizing = false
                savedSize = Main.Size
            end
        end
    end)
end

MinBtn.MouseButton1Click:Connect(function() collapse() end)

local Connections = {}
local function track(c)
    if c then table.insert(Connections, c) end
    return c
end

CloseBtn.MouseButton1Click:Connect(function()
    stopAutoTrain()
    stopFly()
    saveConfig()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    tween(Main, { Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1 }, 0.3)
    tween(DataPanel, { BackgroundTransparency = 1 }, 0.3)
    task.wait(0.35)
    if ScreenGui.Parent then ScreenGui:Destroy() end
end)

task.spawn(function()
    while ScreenGui.Parent do
        local elapsed = isTraining and (tick() - startTime) or 0
        local aps = elapsed > 0 and (trainCount / elapsed) or 0
        statSession.Text = tostring(trainCount)
        statTotal.Text = tostring(totalCount)
        statRate.Text = string.format("%.2f", aps)

        refreshAllStats()
        local curStrength = getStat("Strength")
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

        local bpCount = getBackpackCount()
        local bpMax = Config.EggMaxBackpack
        backpackLbl.Text = tostring(bpCount) .. " / " .. tostring(bpMax)
        if bpCount >= bpMax then
            backpackLbl.TextColor3 = T.Red
        elseif bpCount >= bpMax * 0.85 then
            backpackLbl.TextColor3 = T.Yellow
        else
            backpackLbl.TextColor3 = T.Green
        end

        if DataPanelOpen then
            for _, def in ipairs(STAT_DEFS) do
                local row = DataRows[def.key]
                if row then
                    local val = getStat(def.key)
                    row.value.Text = fmt(val)

                    if def.key == "Strength" then
                        if isTraining and elapsed > 0 and sessionStartStrength then
                            local perSec = (val - sessionStartStrength) / elapsed
                            if perSec > 0 then
                                row.est.Text = "≈ +" .. fmt(perSec * 86400) .. " / 天"
                                row.est.TextColor3 = T.Green
                            else
                                row.est.Text = "—"
                                row.est.TextColor3 = T.TextDim
                            end
                        else
                            row.est.Text = "—"
                            row.est.TextColor3 = T.TextDim
                        end
                    elseif def.key == "Rebirth" then
                        if Config.AutoRebirth and Config.AutoRebirthDelay > 0 then
                            local perDay = 86400 / Config.AutoRebirthDelay
                            row.est.Text = "≈ +" .. fmt(perDay) .. " / 天"
                            row.est.TextColor3 = T.Green
                        else
                            row.est.Text = "—"
                            row.est.TextColor3 = T.TextDim
                        end
                    else
                        row.est.Text = ""
                    end
                end
            end
        end

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
    if pcall(function()
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, true, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, false, false, game)
    end) then return end
    if pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end) then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

track(LocalPlayer.Idled:Connect(fireAntiAfk))

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
            if hasStatSource("Rebirth") then
                local cur = getStat("Rebirth")
                if cur > pendingRebirthLastValue then
                    pendingRebirth = false
                    Config.AutoRebirthDone = Config.AutoRebirthDone + 1
                    saveConfig()
                    if updateRebirthDisplay then updateRebirthDisplay() end
                elseif tick() - pendingRebirthStart > REBIRTH_TIMEOUT then
                    pendingRebirth = false
                    notify("重生超时（未检测到）", T.Red)
                end
            else
                pendingRebirth = false
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        safeWait(Config.AutoRebirthDelay)
        if Config.AutoRebirth and RebirthEvent and not pendingRebirth then
            local target = Config.AutoRebirthCount
            local done = Config.AutoRebirthDone

            if target > 0 and done >= target then
                if Config.AutoRebirth then
                    Config.AutoRebirth = false
                    saveConfig()
                    notify("已达成目标 " .. target .. " 次", T.Green)
                end
            else
                refreshAllStats()
                local hasRebirthStat = hasStatSource("Rebirth")

                if hasRebirthStat then
                    pendingRebirthLastValue = getStat("Rebirth")
                    pendingRebirth = true
                    pendingRebirthStart = tick()
                end

                pcall(function() RebirthEvent:FireServer("Start") end)
                task.wait(0.5)
                pcall(function() RebirthEvent:FireServer("Update") end)

                if not hasRebirthStat then
                    Config.AutoRebirthDone = done + 1
                    saveConfig()
                    if updateRebirthDisplay then updateRebirthDisplay() end
                end
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        safeWait(Config.SkyEggInterval)
        if Config.SkyEggAuto and StoreEvent then
            if isBackpackFull() then
                Config.SkyEggAuto = false
                saveConfig()
                if EggToggleRefs.SkyEggAuto and EggToggleRefs.SkyEggAuto.refresh then
                    EggToggleRefs.SkyEggAuto.refresh()
                end
                notify("背包已满 " .. getBackpackCount() .. "/" .. Config.EggMaxBackpack .. " — 天空蛋自动抽取已停止", T.Red)
            else
                pcall(function()
                    StoreEvent:FireServer("Egg", EGG_DEFS.sky.count, EGG_DEFS.sky.currency, EGG_DEFS.sky.name)
                end)
                skyEggTotal = skyEggTotal + EGG_DEFS.sky.count
                Config.SkyEggTotal = skyEggTotal
                skyEggTotalLbl.Text = tostring(skyEggTotal)
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        safeWait(Config.LavaEggInterval)
        if Config.LavaEggAuto and StoreEvent then
            if isBackpackFull() then
                Config.LavaEggAuto = false
                saveConfig()
                if EggToggleRefs.LavaEggAuto and EggToggleRefs.LavaEggAuto.refresh then
                    EggToggleRefs.LavaEggAuto.refresh()
                end
                notify("背包已满 " .. getBackpackCount() .. "/" .. Config.EggMaxBackpack .. " — 岩浆蛋自动抽取已停止", T.Red)
            else
                pcall(function()
                    StoreEvent:FireServer("Egg", EGG_DEFS.lava.count, EGG_DEFS.lava.currency, EGG_DEFS.lava.name)
                end)
                lavaEggTotal = lavaEggTotal + EGG_DEFS.lava.count
                Config.LavaEggTotal = lavaEggTotal
                lavaEggTotalLbl.Text = tostring(lavaEggTotal)
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        safeWait(Config.SandEggInterval)
        if Config.SandEggAuto and StoreEvent then
            if isBackpackFull() then
                Config.SandEggAuto = false
                saveConfig()
                if EggToggleRefs.SandEggAuto and EggToggleRefs.SandEggAuto.refresh then
                    EggToggleRefs.SandEggAuto.refresh()
                end
                notify("背包已满 " .. getBackpackCount() .. "/" .. Config.EggMaxBackpack .. " — 沙漠蛋自动抽取已停止", T.Red)
            else
                pcall(function()
                    StoreEvent:FireServer("Egg", EGG_DEFS.sand.count, EGG_DEFS.sand.currency, EGG_DEFS.sand.name)
                end)
                sandEggTotal = sandEggTotal + EGG_DEFS.sand.count
                Config.SandEggTotal = sandEggTotal
                sandEggTotalLbl.Text = tostring(sandEggTotal)
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        safeWait(Config.JungleEggInterval)
        if Config.JungleEggAuto and StoreEvent then
            if isBackpackFull() then
                Config.JungleEggAuto = false
                saveConfig()
                if EggToggleRefs.JungleEggAuto and EggToggleRefs.JungleEggAuto.refresh then
                    EggToggleRefs.JungleEggAuto.refresh()
                end
                notify("背包已满 " .. getBackpackCount() .. "/" .. Config.EggMaxBackpack .. " — 主岛蛋自动抽取已停止", T.Red)
            else
                pcall(function()
                    StoreEvent:FireServer("Egg", EGG_DEFS.jungle.count, EGG_DEFS.jungle.currency, EGG_DEFS.jungle.name)
                end)
                jungleEggTotal = jungleEggTotal + EGG_DEFS.jungle.count
                Config.JungleEggTotal = jungleEggTotal
                jungleEggTotalLbl.Text = tostring(jungleEggTotal)
            end
        end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        safeWait(Config.AutoResetInterval)
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

track(UserInputService.InputBegan:Connect(function(input, processed)
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
    elseif input.KeyCode == Enum.KeyCode.Delete then
        if DataPanelOpen then closeDataPanel() else openDataPanel() end
    end
end))

updateStartBtn()
updateStatus()
refreshAllStats()
applyWalkSpeed()

if Config.AutoStart then
    startAutoTrain()
    updateStartBtn()
    updateStatus()
end

if Config.Fly then
    task.defer(function()
        startFly()
        if IS_TOUCH then FlyControls.Visible = true end
    end)
end

if Config.MinimizeOnStart then
    task.defer(collapse)
end

notify("力量之冠 v4.0 — 已启动", T.Neon)