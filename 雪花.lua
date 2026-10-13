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
    LogEnabled = true,
    LogMaxLines = 200,
    LogPanelOpen = false,
    StatsPanelOpen = false,
    HistoryPanelOpen = false,
    HistorySampleRate = 5,
    HistoryMaxPoints = 720,
    TrainMultiplier = 1,
    AutoSwitchAction = false,
    AutoSwitchEvery = 100,
    TargetStrength = 0,
    TargetStrengthStop = false,
    SessionTimeLimit = 0,
    SessionTimeLimitStop = false,
    Theme = "Cyber",
    UIScale = 1,
    LoopMode = false,
    LoopTrainTime = 30,
    LoopRebirthTime = 5,
    AutoFollow = false,
    FollowTarget = "",
    NoClip = false,
    TeleportPoints = {},
    QuickTP = "",
}

local Actions = { "PushUp", "SitUp", "PullUp", "Squat" }
local ActionNames = { PushUp = "俯卧撑", SitUp = "仰卧起坐", PullUp = "引体向上", Squat = "深蹲" }
local CONFIG_FILE = "CrownStrength_config.json"
local MIN_INTERVAL, MAX_INTERVAL = 0.08, 10
local MIN_W, MIN_H, MAX_W, MAX_H = 260, 260, 420, 600
local COLLAPSED = 44
local IS_TOUCH = UserInputService.TouchEnabled
local REBIRTH_TIMEOUT = 15

local Themes = {
    Cyber = {
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
    },
    Dark = {
        BgDeep   = Color3.fromRGB(8, 8, 10),
        BgPanel  = Color3.fromRGB(18, 18, 22),
        BgPanel2 = Color3.fromRGB(28, 28, 34),
        BgPanelHi= Color3.fromRGB(40, 40, 48),
        Grid     = Color3.fromRGB(35, 35, 42),
        Stroke   = Color3.fromRGB(60, 60, 70),
        Neon     = Color3.fromRGB(120, 180, 255),
        Neon2    = Color3.fromRGB(200, 120, 255),
        NeonDim  = Color3.fromRGB(60, 90, 140),
        Green    = Color3.fromRGB(80, 220, 140),
        GreenDim = Color3.fromRGB(40, 140, 90),
        Red      = Color3.fromRGB(240, 80, 100),
        RedDim   = Color3.fromRGB(150, 40, 60),
        Yellow   = Color3.fromRGB(240, 210, 100),
        Purple   = Color3.fromRGB(170, 130, 240),
        Text     = Color3.fromRGB(230, 230, 240),
        TextDim  = Color3.fromRGB(140, 140, 160),
        TextSub  = Color3.fromRGB(90, 90, 110),
    },
    Light = {
        BgDeep   = Color3.fromRGB(240, 244, 250),
        BgPanel  = Color3.fromRGB(255, 255, 255),
        BgPanel2 = Color3.fromRGB(235, 240, 248),
        BgPanelHi= Color3.fromRGB(220, 228, 240),
        Grid     = Color3.fromRGB(210, 218, 230),
        Stroke   = Color3.fromRGB(180, 190, 205),
        Neon     = Color3.fromRGB(0, 130, 200),
        Neon2    = Color3.fromRGB(200, 60, 140),
        NeonDim  = Color3.fromRGB(100, 160, 200),
        Green    = Color3.fromRGB(0, 170, 110),
        GreenDim = Color3.fromRGB(0, 120, 80),
        Red      = Color3.fromRGB(220, 50, 70),
        RedDim   = Color3.fromRGB(160, 30, 50),
        Yellow   = Color3.fromRGB(200, 160, 20),
        Purple   = Color3.fromRGB(130, 80, 200),
        Text     = Color3.fromRGB(30, 40, 55),
        TextDim  = Color3.fromRGB(90, 105, 125),
        TextSub  = Color3.fromRGB(140, 155, 175),
    },
}

local T = {}
for k, v in pairs(Themes.Cyber) do T[k] = v end
T.F  = Enum.Font.GothamMedium
T.FB = Enum.Font.GothamBold
T.FM = Enum.Font.Code

local function applyTheme(name)
    local th = Themes[name]
    if not th then return end
    for k, v in pairs(th) do T[k] = v end
end
applyTheme(Config.Theme or "Cyber")

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
            if type(v) ~= "function" then d[k] = v end
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
        if type(data.TeleportPoints) == "table" then
            Config.TeleportPoints = data.TeleportPoints
        end
    end
end
loadConfig()
applyTheme(Config.Theme or "Cyber")

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
    for _, c in ipairs(list) do table.insert(cs, ColorSequenceKeypoint.new(c[1], c[2])) end
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

local function fmtRate(n)
    n = tonumber(n) or 0
    if math.abs(n) >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if math.abs(n) >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if math.abs(n) >= 1e3 then return string.format("%.2fK", n / 1e3) end
    return string.format("%.2f", n)
end

local function fmtDuration(sec)
    sec = math.floor(tonumber(sec) or 0)
    if sec < 60 then return sec .. "s" end
    if sec < 3600 then return string.format("%dm%ds", math.floor(sec / 60), sec % 60) end
    if sec < 86400 then
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        return string.format("%dh%dm", h, m)
    end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    return string.format("%dd%dh", d, h)
end

local function cornerBrackets(parent, color, size, thickness)
    color = color or T.Neon
    size = size or 8
    thickness = thickness or 2
    local data = {
        {0, 0, 1, 0, 0, 0}, {1, -size, 0, 0, 1, 0},
        {0, 0, 0, 1, 0, 0}, {1, -size, 1, -size, 0, 1},
    }
    for _, d in ipairs(data) do
        local h = Instance.new("Frame")
        h.Size = UDim2.new(0, size, 0, thickness)
        h.Position = UDim2.new(d[1], d[2], d[3], d[4])
        h.BackgroundColor3 = color
        h.BorderSizePixel = 0
        h.ZIndex = 10
        h.Parent = parent
    end
    for _, d in ipairs(data) do
        local v = Instance.new("Frame")
        v.Size = UDim2.new(0, thickness, 0, size)
        v.Position = UDim2.new(d[5], d[6], d[3], d[4])
        v.BackgroundColor3 = color
        v.BorderSizePixel = 0
        v.ZIndex = 10
        v.Parent = parent
    end
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
local startAutoTrain, stopAutoTrain, updateStatus, updateStartBtn, collapse, expand
local startFly, stopFly, applyWalkSpeed
local updateRebirthDisplay
local DataPanelOpen = Config.DataPanelOpen or false

local pendingRebirth = false
local pendingRebirthStart = 0
local pendingRebirthLastValue = 0

local MobileInput = { Forward = false, Back = false, Left = false, Right = false, Up = false, Down = false }

local _lastSwitchAt = nil
local loopThread = nil
local loopActive = false
local followThread = nil
local noclipConn = nil
local sessionLimitThread = nil

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
        if d.key == key then
            def = d
            break
        end
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

local Logs = {}
local LogListeners = {}

local function addLog(text, color, tag)
    if not Config.LogEnabled then return end
    local entry = {
        text = tostring(text),
        color = color or T.Text,
        tag = tag or "SYS",
        time = os.date("%H:%M:%S"),
        tick = tick(),
    }
    table.insert(Logs, entry)
    if #Logs > Config.LogMaxLines then
        table.remove(Logs, 1)
    end
    for _, fn in ipairs(LogListeners) do
        pcall(fn, entry)
    end
end

local function onLog(fn)
    table.insert(LogListeners, fn)
    return function()
        for i, f in ipairs(LogListeners) do
            if f == fn then table.remove(LogListeners, i) break end
        end
    end
end

local function clearLogs()
    Logs = {}
    for _, fn in ipairs(LogListeners) do pcall(fn, nil) end
end

local function getLogs()
    return Logs
end

local History = {
    strength = {},
    rebirth = {},
    gems = {},
    agility = {},
    sessionStart = tick(),
    lastSample = 0,
}

local function pushHistory(key, value)
    local list = History[key]
    if not list then return end
    table.insert(list, { t = tick(), v = value })
    if #list > Config.HistoryMaxPoints then
        table.remove(list, 1)
    end
end

local function sampleHistory()
    local now = tick()
    if now - History.lastSample < Config.HistorySampleRate then return end
    History.lastSample = now
    refreshAllStats()
    for _, def in ipairs(STAT_DEFS) do
        if hasStatSource(def.key) then
            pushHistory(def.key, getStat(def.key))
        end
    end
end

local function getHistory(key)
    return History[key] or {}
end

local function getHistoryDelta(key, seconds)
    local list = History[key]
    if not list or #list < 2 then return 0, 0 end
    local now = tick()
    local cutoff = now - (seconds or 60)
    local oldest = nil
    local newest = list[#list]
    for i = #list, 1, -1 do
        if list[i].t <= cutoff then
            oldest = list[i]
            break
        end
    end
    if not oldest then oldest = list[1] end
    local delta = newest.v - oldest.v
    local dt = newest.t - oldest.t
    return delta, dt
end

local function clearHistory()
    for k in pairs(History) do
        if type(History[k]) == "table" then History[k] = {} end
    end
    History.lastSample = 0
end

local function getSessionStats()
    local elapsed = tick() - History.sessionStart
    local stats = {
        elapsed = elapsed,
        reps = trainCount or 0,
        strengthGain = 0,
        rebirthGain = 0,
        gemsGain = 0,
        agilityGain = 0,
    }
    for _, def in ipairs(STAT_DEFS) do
        local delta = getHistoryDelta(def.key, elapsed)
        stats[def.key .. "Gain"] = delta
    end
    return stats
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

local uiScaleObj = Instance.new("UIScale")
uiScaleObj.Scale = Config.UIScale or 1
uiScaleObj.Parent = ScreenGui

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
TitleLbl.Text = "力量之冠 v2.0"
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
SubTitle.Text = "// modular"
SubTitle.TextColor3 = T.Neon
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = T.FM
SubTitle.TextSize = 7
SubTitle.ZIndex = 5
SubTitle.Parent = Header

local HeaderDotGlow = Instance.new("Frame")
HeaderDotGlow.Size = UDim2.new(0, 10, 0, 10)
HeaderDotGlow.Position = UDim2.new(1, -124, 0.5, -5)
HeaderDotGlow.BackgroundColor3 = T.Red
HeaderDotGlow.BackgroundTransparency = 0.65
HeaderDotGlow.BorderSizePixel = 0
HeaderDotGlow.ZIndex = 4
HeaderDotGlow.Parent = Header
corner(HeaderDotGlow, 5)

local HeaderDot = Instance.new("Frame")
HeaderDot.Size = UDim2.new(0, 5, 0, 5)
HeaderDot.Position = UDim2.new(1, -121.5, 0.5, -2.5)
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
local LogBtn = headerButton("≡", T.NeonDim, -100, T.Neon)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -36 - 36)
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

local notify
notify = function(text, color)
    addLog(text, color, "NTF")
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
        refresh()
        if onToggle then onToggle(Config[key]) end
        saveConfig()
    end)

    return refresh
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
            notify(string.format("范围 %s ~ %s", tostring(minV), tostring(maxV)), T.Red)
        end
    end)
    return box
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

local function smallBtn(parent, text, color, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 20)
    b.BackgroundColor3 = T.BgPanel2
    b.Text = text
    b.TextColor3 = color or T.Neon
    b.Font = T.FM
    b.TextSize = 9
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = parent
    corner(b, 3)
    stroke(b, color or T.Stroke, 1, 0.4)
    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = T.BgPanelHi }, 0.15) end)
    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = T.BgPanel2 }, 0.15) end)
    if onClick then b.MouseButton1Click:Connect(onClick) end
    return b
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
    if v == Config.Action then
        actionIndex = i
        break
    end
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

local advTrainCard = accordionCard("◆ 训练增强", T.Neon, false)

numberInput(advTrainCard, "训练倍率", "TrainMultiplier", 1, 50, function(v)
    Config.TrainMultiplier = v
end)

local autoSwitchRefresh = toggleRow(advTrainCard, "自动切换动作", "AutoSwitchAction")
numberInput(advTrainCard, "切换间隔", "AutoSwitchEvery", 10, 99999)

numberInput(advTrainCard, "目标力量", "TargetStrength", 0, 1e12, function(v)
    Config.TargetStrength = v
end)
toggleRow(advTrainCard, "达标自动停", "TargetStrengthStop")

numberInput(advTrainCard, "时限(秒)", "SessionTimeLimit", 0, 86400, function(v)
    Config.SessionTimeLimit = v
end)
toggleRow(advTrainCard, "时限自动停", "SessionTimeLimitStop")

local autoCard = accordionCard("◆ 自动重生", T.Purple, false)

local arRefresh = toggleRow(autoCard, "自动重生", "AutoRebirth")
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
local barGrad = gradient(barFill, T.Green, T.Neon, 0)

updateRebirthDisplay = function()
    doneLbl.Text = tostring(Config.AutoRebirthDone)
    if Config.AutoRebirthCount == 0 then
        targetLbl.Text = "∞"
        targetLbl.TextColor3 = T.Purple
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barGrad.Color = ColorSequence.new(T.Purple, T.Purple)
    else
        targetLbl.Text = tostring(Config.AutoRebirthCount)
        targetLbl.TextColor3 = T.Purple
        local pct = math.clamp(Config.AutoRebirthDone / Config.AutoRebirthCount, 0, 1)
        barFill.Size = UDim2.new(pct, 0, 1, 0)
        if pct >= 1 then
            barGrad.Color = ColorSequence.new(T.Green, T.Green)
        elseif pct >= 0.5 then
            barGrad.Color = ColorSequence.new(T.Neon, T.Neon)
        else
            barGrad.Color = ColorSequence.new(T.Purple, T.Purple)
        end
    end
end
updateRebirthDisplay()

local resetRebirthBtn = smallBtn(autoCard, "⟲  重置计数", T.Red, function()
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
    FlyControls.Visible = false
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

toggleRow(moveCard, "无碰撞", "NoClip", function(on)
    if on then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end)

local tpCard = accordionCard("◆ 传送", T.Neon2, false)

local function getCharHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function tpTo(pos)
    local hrp = getCharHRP()
    if hrp then
        hrp.CFrame = CFrame.new(pos)
        notify("已传送", T.Neon)
    end
end

local tpNameBox = Instance.new("TextBox")
tpNameBox.Size = UDim2.new(1, 0, 0, 20)
tpNameBox.BackgroundColor3 = T.BgPanel2
tpNameBox.Text = ""
tpNameBox.PlaceholderText = "传送点名称"
tpNameBox.PlaceholderColor3 = T.TextDim
tpNameBox.TextColor3 = T.Text
tpNameBox.Font = T.FM
tpNameBox.TextSize = 9
tpNameBox.ClearTextOnFocus = false
tpNameBox.BorderSizePixel = 0
tpNameBox.Parent = tpCard
corner(tpNameBox, 3)
stroke(tpNameBox, T.Stroke, 1, 0.3)

smallBtn(tpCard, "＋ 保存当前位置", T.Green, function()
    local name = tpNameBox.Text
    if name == "" then
        notify("请输入名称", T.Red)
        return
    end
    local hrp = getCharHRP()
    if not hrp then
        notify("角色未加载", T.Red)
        return
    end
    Config.TeleportPoints[name] = {
        x = hrp.Position.X,
        y = hrp.Position.Y,
        z = hrp.Position.Z,
    }
    saveConfig()
    notify("已保存 " .. name, T.Green)
end)

local tpListFrame = Instance.new("Frame")
tpListFrame.Size = UDim2.new(1, 0, 0, 0)
tpListFrame.AutomaticSize = Enum.AutomaticSize.Y
tpListFrame.BackgroundTransparency = 1
tpListFrame.Parent = tpCard

local tpListLayout = Instance.new("UIListLayout")
tpListLayout.Padding = UDim.new(0, 4)
tpListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tpListLayout.Parent = tpListFrame

local function refreshTpList()
    for _, child in ipairs(tpListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for name, pos in pairs(Config.TeleportPoints) do
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, 0, 0, 20)
        r.BackgroundColor3 = T.BgPanel2
        r.BackgroundTransparency = 0.4
        r.Parent = tpListFrame
        corner(r, 3)
        stroke(r, T.Stroke, 1, 0.5)

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -50, 1, 0)
        l.Position = UDim2.new(0, 6, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = name
        l.TextColor3 = T.Text
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Font = T.F
        l.TextSize = 9
        l.Parent = r

        local go = Instance.new("TextButton")
        go.Size = UDim2.new(0, 22, 0, 16)
        go.Position = UDim2.new(1, -46, 0.5, -8)
        go.BackgroundColor3 = T.GreenDim
        go.Text = "→"
        go.TextColor3 = T.Green
        go.Font = T.FB
        go.TextSize = 10
        go.AutoButtonColor = false
        go.BorderSizePixel = 0
        go.Parent = r
        corner(go, 3)

        local del = Instance.new("TextButton")
        del.Size = UDim2.new(0, 22, 0, 16)
        del.Position = UDim2.new(1, -22, 0.5, -8)
        del.BackgroundColor3 = T.RedDim
        del.Text = "×"
        del.TextColor3 = T.Red
        del.Font = T.FB
        del.TextSize = 10
        del.AutoButtonColor = false
        del.BorderSizePixel = 0
        del.Parent = r
        corner(del, 3)

        go.MouseButton1Click:Connect(function()
            tpTo(Vector3.new(pos.x, pos.y, pos.z))
        end)
        del.MouseButton1Click:Connect(function()
            Config.TeleportPoints[name] = nil
            saveConfig()
            refreshTpList()
        end)
    end
end
refreshTpList()

smallBtn(tpCard, "＋ 刷新列表", T.Neon, refreshTpList)
smallBtn(tpCard, "✕ 清空全部", T.Red, function()
    Config.TeleportPoints = {}
    saveConfig()
    refreshTpList()
    notify("已清空传送点", T.Red)
end)

local followCard = accordionCard("◆ 跟随", T.Yellow, false)

local followNameBox = Instance.new("TextBox")
followNameBox.Size = UDim2.new(1, 0, 0, 20)
followNameBox.BackgroundColor3 = T.BgPanel2
followNameBox.Text = Config.FollowTarget
followNameBox.PlaceholderText = "玩家名"
followNameBox.PlaceholderColor3 = T.TextDim
followNameBox.TextColor3 = T.Text
followNameBox.Font = T.FM
followNameBox.TextSize = 9
followNameBox.ClearTextOnFocus = false
followNameBox.BorderSizePixel = 0
followNameBox.Parent = followCard
corner(followNameBox, 3)
stroke(followNameBox, T.Stroke, 1, 0.3)

followNameBox.FocusLost:Connect(function()
    Config.FollowTarget = followNameBox.Text
    saveConfig()
end)

toggleRow(followCard, "自动跟随", "AutoFollow", function(on)
    if on then
        if followThread then task.cancel(followThread) end
        followThread = task.spawn(function()
            while Config.AutoFollow and ScreenGui.Parent do
                local target = Players:FindFirstChild(Config.FollowTarget)
                if target and target.Character then
                    local thrp = target.Character:FindFirstChild("HumanoidRootPart")
                    local hrp = getCharHRP()
                    if thrp and hrp then
                        local diff = thrp.Position - hrp.Position
                        if diff.Magnitude > 6 then
                            hrp.CFrame = CFrame.new(hrp.Position + diff.Unit * math.min(diff.Magnitude, 3))
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
        notify("开始跟随 " .. Config.FollowTarget, T.Green)
    else
        if followThread then
            task.cancel(followThread)
            followThread = nil
        end
        notify("停止跟随", T.Red)
    end
end)

local loopCard = accordionCard("◆ 循环挂机", T.Green, false)

toggleRow(loopCard, "启用循环", "LoopMode", function(on)
    loopActive = on
    if on then
        if loopThread then task.cancel(loopThread) end
        loopThread = task.spawn(function()
            while loopActive and ScreenGui.Parent do
                local loopStarted = false
                if not isTraining then
                    startAutoTrain()
                    loopStarted = true
                end
                updateStartBtn()
                updateStatus()
                task.wait(Config.LoopTrainTime)

                if RebirthEvent then
                    pcall(function() RebirthEvent:FireServer("Start") end)
                    task.wait(0.5)
                    pcall(function() RebirthEvent:FireServer("Update") end)
                end

                if loopStarted and isTraining then
                    stopAutoTrain()
                end
                updateStartBtn()
                updateStatus()
                task.wait(Config.LoopRebirthTime)
            end
        end)
        notify("循环挂机已开启", T.Green)
    else
        if loopThread then
            task.cancel(loopThread)
            loopThread = nil
        end
        updateStartBtn()
        updateStatus()
        notify("循环挂机已关闭", T.Red)
    end
end)

numberInput(loopCard, "训练时长", "LoopTrainTime", 5, 3600, function(v)
    Config.LoopTrainTime = v
end)

numberInput(loopCard, "重生间隔", "LoopRebirthTime", 1, 600, function(v)
    Config.LoopRebirthTime = v
end)

local themeCard = accordionCard("◆ 主题", T.Neon2, false)

local themeRow = Instance.new("Frame")
themeRow.Size = UDim2.new(1, 0, 0, 24)
themeRow.BackgroundTransparency = 1
themeRow.Parent = themeCard

local themeNames = { "Cyber", "Dark", "Light" }
local themeLabels = { Cyber = "赛博", Dark = "暗黑", Light = "明亮" }

local themeBtns = {}
for i, tname in ipairs(themeNames) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 78, 1, 0)
    b.Position = UDim2.new(0, (i - 1) * 82, 0, 0)
    b.BackgroundColor3 = Config.Theme == tname and T.Neon or T.BgPanel2
    b.Text = themeLabels[tname]
    b.TextColor3 = Config.Theme == tname and T.BgDeep or T.Text
    b.Font = T.FB
    b.TextSize = 9
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.Parent = themeRow
    corner(b, 3)
    stroke(b, T.Stroke, 1, 0.4)
    themeBtns[tname] = b

    b.MouseButton1Click:Connect(function()
        Config.Theme = tname
        saveConfig()
        notify("主题已切换 — 重启生效", T.Yellow)
    end)
end

numberInput(themeCard, "UI缩放", "UIScale", 0.5, 2, function(v)
    Config.UIScale = v
    if uiScaleObj then uiScaleObj.Scale = v end
end)

local statCard = accordionCard("◆ 统计", T.Yellow, false)
local statSession = infoRow(statCard, "本次训练", T.Text)
local statTotal = infoRow(statCard, "累计训练", T.Text)
local statRate = infoRow(statCard, "每秒平均", T.Text)
local statStrGain = infoRow(statCard, "力量增长", T.Neon)
local statStrRate = infoRow(statCard, "力量/秒", T.Green)
local statStrDay = infoRow(statCard, "预计/天", T.Purple)
local statElapsed = infoRow(statCard, "会话时长", T.TextDim)

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

local LogPanel = Instance.new("Frame")
LogPanel.Size = UDim2.new(0, 260, 0, 320)
LogPanel.Position = UDim2.new(1, -290, 0.5, -160)
LogPanel.BackgroundColor3 = T.BgDeep
LogPanel.BorderSizePixel = 0
LogPanel.Active = true
LogPanel.ClipsDescendants = true
LogPanel.Visible = false
LogPanel.ZIndex = 40
LogPanel.Parent = ScreenGui
corner(LogPanel, 6)
stroke(LogPanel, T.Green, 1.2, 0.35)
gradientMulti(LogPanel, {
    {0, T.BgPanel},
    {0.5, T.BgDeep},
    {1, Color3.fromRGB(6, 12, 20)},
}, 135)
cornerBrackets(LogPanel, T.Green, 8, 2)

local LogHeader = Instance.new("Frame")
LogHeader.Size = UDim2.new(1, 0, 0, 32)
LogHeader.BackgroundColor3 = T.BgPanel
LogHeader.BackgroundTransparency = 0.1
LogHeader.BorderSizePixel = 0
LogHeader.ZIndex = 3
LogHeader.Parent = LogPanel

local LogTitle = Instance.new("TextLabel")
LogTitle.Size = UDim2.new(1, -60, 1, 0)
LogTitle.Position = UDim2.new(0, 12, 0, 0)
LogTitle.BackgroundTransparency = 1
LogTitle.Text = "◆ 日志"
LogTitle.TextColor3 = T.Green
LogTitle.TextXAlignment = Enum.TextXAlignment.Left
LogTitle.Font = T.FB
LogTitle.TextSize = 10
LogTitle.ZIndex = 5
LogTitle.Parent = LogHeader

local LogClearBtn = Instance.new("TextButton")
LogClearBtn.Size = UDim2.new(0, 20, 0, 20)
LogClearBtn.Position = UDim2.new(1, -48, 0.5, -10)
LogClearBtn.BackgroundColor3 = T.RedDim
LogClearBtn.BackgroundTransparency = 0.4
LogClearBtn.Text = "⟲"
LogClearBtn.TextColor3 = T.Text
LogClearBtn.Font = T.FB
LogClearBtn.TextSize = 11
LogClearBtn.AutoButtonColor = false
LogClearBtn.BorderSizePixel = 0
LogClearBtn.ZIndex = 5
LogClearBtn.Parent = LogHeader
corner(LogClearBtn, 3)

local LogCloseBtn = Instance.new("TextButton")
LogCloseBtn.Size = UDim2.new(0, 20, 0, 20)
LogCloseBtn.Position = UDim2.new(1, -24, 0.5, -10)
LogCloseBtn.BackgroundColor3 = T.RedDim
LogCloseBtn.BackgroundTransparency = 0.4
LogCloseBtn.Text = "×"
LogCloseBtn.TextColor3 = T.Text
LogCloseBtn.Font = T.FB
LogCloseBtn.TextSize = 12
LogCloseBtn.AutoButtonColor = false
LogCloseBtn.BorderSizePixel = 0
LogCloseBtn.ZIndex = 5
LogCloseBtn.Parent = LogHeader
corner(LogCloseBtn, 3)

local LogContent = Instance.new("ScrollingFrame")
LogContent.Size = UDim2.new(1, 0, 1, -32)
LogContent.Position = UDim2.new(0, 0, 0, 32)
LogContent.BackgroundTransparency = 1
LogContent.BorderSizePixel = 0
LogContent.ScrollBarThickness = 2
LogContent.ScrollBarImageColor3 = T.Green
LogContent.ScrollBarImageTransparency = 0.4
LogContent.ScrollingDirection = Enum.ScrollingDirection.Y
LogContent.CanvasSize = UDim2.new(0, 0, 0, 0)
LogContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogContent.ZIndex = 2
LogContent.Parent = LogPanel
paddingSides(LogContent, 8, 8, 8, 8)

local LogLayout = Instance.new("UIListLayout")
LogLayout.Padding = UDim.new(0, 3)
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.Parent = LogContent

local logEntryCount = 0
local function rebuildLogUI()
    for _, c in ipairs(LogContent:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    logEntryCount = 0
    for _, e in ipairs(getLogs()) do
        local r = Instance.new("Frame")
        r.Size = UDim2.new(1, 0, 0, 0)
        r.AutomaticSize = Enum.AutomaticSize.Y
        r.BackgroundColor3 = T.BgPanel2
        r.BackgroundTransparency = 0.5
        r.Parent = LogContent
        corner(r, 3)

        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.new(0, 32, 0, 14)
        tag.Position = UDim2.new(0, 4, 0, 2)
        tag.BackgroundColor3 = e.color
        tag.BackgroundTransparency = 0.7
        tag.Text = e.tag
        tag.TextColor3 = e.color
        tag.Font = T.FM
        tag.TextSize = 8
        tag.Parent = r
        corner(tag, 2)

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, -46, 0, 0)
        txt.Position = UDim2.new(0, 40, 0, 2)
        txt.AutomaticSize = Enum.AutomaticSize.Y
        txt.BackgroundTransparency = 1
        txt.Text = "[" .. e.time .. "] " .. e.text
        txt.TextColor3 = T.Text
        txt.TextXAlignment = Enum.TextXAlignment.Left
        txt.TextYAlignment = Enum.TextYAlignment.Top
        txt.Font = T.F
        txt.TextSize = 9
        txt.TextWrapped = true
        txt.Parent = r

        local pad = Instance.new("UIPadding")
        pad.PaddingBottom = UDim.new(0, 3)
        pad.Parent = r
    end
end

local function appendLogUI(entry)
    if not entry then
        rebuildLogUI()
        return
    end
    logEntryCount = logEntryCount + 1

    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 0)
    r.AutomaticSize = Enum.AutomaticSize.Y
    r.BackgroundColor3 = T.BgPanel2
    r.BackgroundTransparency = 0.5
    r.Parent = LogContent
    corner(r, 3)

    local tag = Instance.new("TextLabel")
    tag.Size = UDim2.new(0, 32, 0, 14)
    tag.Position = UDim2.new(0, 4, 0, 2)
    tag.BackgroundColor3 = entry.color
    tag.BackgroundTransparency = 0.7
    tag.Text = entry.tag
    tag.TextColor3 = entry.color
    tag.Font = T.FM
    tag.TextSize = 8
    tag.Parent = r
    corner(tag, 2)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -46, 0, 0)
    txt.Position = UDim2.new(0, 40, 0, 2)
    txt.AutomaticSize = Enum.AutomaticSize.Y
    txt.BackgroundTransparency = 1
    txt.Text = "[" .. entry.time .. "] " .. entry.text
    txt.TextColor3 = T.Text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.Font = T.F
    txt.TextSize = 9
    txt.TextWrapped = true
    txt.Parent = r

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 3)
    pad.Parent = r

    task.defer(function()
        LogContent.CanvasPosition = Vector2.new(0, LogContent.AbsoluteCanvasSize.Y)
    end)

    if logEntryCount > 300 then
        rebuildLogUI()
    end
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

local function openLogPanel()
    Config.LogPanelOpen = true
    LogPanel.Visible = true
    rebuildLogUI()
    saveConfig()
end

local function closeLogPanel()
    Config.LogPanelOpen = false
    LogPanel.Visible = false
    saveConfig()
end

DataBtn.MouseButton1Click:Connect(function()
    if DataPanelOpen then closeDataPanel() else openDataPanel() end
end)
DataCloseBtn.MouseButton1Click:Connect(closeDataPanel)

LogBtn.MouseButton1Click:Connect(function()
    if Config.LogPanelOpen then closeLogPanel() else openLogPanel() end
end)
LogCloseBtn.MouseButton1Click:Connect(closeLogPanel)
LogClearBtn.MouseButton1Click:Connect(function()
    clearLogs()
    rebuildLogUI()
end)

onLog(appendLogUI)

if Config.DataPanelOpen then
    DataPanel.Visible = true
    DataPanelOpen = true
end
if Config.LogPanelOpen then
    LogPanel.Visible = true
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(DataHeader, DataPanel)
makeDraggable(LogHeader, LogPanel)

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
    _lastSwitchAt = nil
    startTime = tick()
    History.sessionStart = tick()
    History.lastSample = 0
    refreshAllStats()
    if hasStatSource("Strength") then
        sessionStartStrength = getStat("Strength")
    end

    if sessionLimitThread then task.cancel(sessionLimitThread) end
    sessionLimitThread = task.spawn(function()
        while isTraining and ScreenGui.Parent do
            task.wait(1)
            local elapsed = tick() - startTime

            if Config.AutoSwitchAction and trainCount > 0 then
                if not _lastSwitchAt or trainCount - _lastSwitchAt >= Config.AutoSwitchEvery then
                    _lastSwitchAt = trainCount
                    actionIndex = actionIndex % #Actions + 1
                    Config.Action = Actions[actionIndex]
                    actionBtn.Text = ActionNames[Config.Action] or Config.Action
                end
            end

            if Config.TargetStrengthStop and Config.TargetStrength > 0 then
                local cur = getStat("Strength")
                if cur >= Config.TargetStrength then
                    notify("已达目标力量 " .. fmt(Config.TargetStrength), T.Green)
                    stopAutoTrain()
                    updateStartBtn()
                    updateStatus()
                    break
                end
            end

            if Config.SessionTimeLimitStop and Config.SessionTimeLimit > 0 then
                if elapsed >= Config.SessionTimeLimit then
                    notify("已达时限 " .. Config.SessionTimeLimit .. "s", T.Yellow)
                    stopAutoTrain()
                    updateStartBtn()
                    updateStatus()
                    break
                end
            end
        end
    end)

    trainThread = task.spawn(function()
        while isTraining and ScreenGui.Parent do
            local mult = math.max(1, math.floor(Config.TrainMultiplier or 1))
            for _ = 1, mult do
                local ok = pcall(function() TrainEvent:FireServer(Config.Action) end)
                if ok then
                    trainCount = trainCount + 1
                    totalCount = totalCount + 1
                    Config.TotalReps = totalCount
                end
            end
            if trainCount % 100 == 0 and trainCount > 0 then
                addLog("已完成 " .. trainCount .. " 次 " .. (ActionNames[Config.Action] or Config.Action), T.GreenDim, "TRN")
            end
            task.wait(Config.Interval)
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
    if sessionLimitThread then
        pcall(task.cancel, sessionLimitThread)
        sessionLimitThread = nil
    end
    saveConfig()
    updateStatus()
    addLog("本次训练 " .. fmtDuration(tick() - startTime) .. " · " .. trainCount .. " 次", T.Neon, "TRN")
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
    if loopThread then pcall(task.cancel, loopThread) end
    if followThread then pcall(task.cancel, followThread) end
    if sessionLimitThread then pcall(task.cancel, sessionLimitThread) end
    saveConfig()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    tween(Main, { Size = UDim2.new(0, W, 0, 0), BackgroundTransparency = 1 }, 0.3)
    tween(DataPanel, { BackgroundTransparency = 1 }, 0.3)
    tween(LogPanel, { BackgroundTransparency = 1 }, 0.3)
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

        statStrGain.Text = (gain >= 0 and "+" or "") .. fmt(gain)
        if elapsed > 0 and gain > 0 then
            local perSec = gain / elapsed
            statStrRate.Text = fmtRate(perSec) .. "/s"
            statStrDay.Text = fmtRate(perSec * 86400)
        else
            statStrRate.Text = "—"
            statStrDay.Text = "—"
        end
        statElapsed.Text = fmtDuration(elapsed)

        sampleHistory()

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
                                row.est.Text = "≈ +" .. fmtRate(perSec * 86400) .. " / 天"
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
                            row.est.Text = "≈ +" .. fmtRate(perDay) .. " / 天"
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
    addLog("触发反挂机", T.Yellow, "AFK")

    local ok1 = pcall(function()
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, true, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, false, false, game)
    end)

    if not ok1 then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end

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
                    addLog("重生成功 · 总计 " .. Config.AutoRebirthDone, T.Purple, "RBT")
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
        task.wait(Config.AutoRebirthDelay)
        if Config.AutoRebirth and RebirthEvent and not pendingRebirth then
            local target = Config.AutoRebirthCount
            local done = Config.AutoRebirthDone

            if target > 0 and done >= target then
                if Config.AutoRebirth then
                    Config.AutoRebirth = false
                    saveConfig()
                    if arRefresh then arRefresh() end
                    notify("已达成目标 " .. target .. " 次", T.Green)
                    addLog("自动重生达标停止", T.Purple, "RBT")
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
    elseif input.KeyCode == Enum.KeyCode.End then
        if Config.LogPanelOpen then closeLogPanel() else openLogPanel() end
    end
end))

updateStartBtn()
updateStatus()
refreshAllStats()
applyWalkSpeed()

addLog("系统启动 v2.0", T.Neon, "SYS")
addLog("日志上限 " .. Config.LogMaxLines .. " 条", T.TextDim, "SYS")
addLog("采样间隔 " .. Config.HistorySampleRate .. "s", T.TextDim, "SYS")

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

notify("力量之冠 v2.0 — 已启动", T.Neon)