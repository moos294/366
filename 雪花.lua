local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Config = {
    Action = "PushUp", Interval = 0.1,
    AutoRebirth = false, AutoRebirthDelay = 3, AntiAfk = true,
    AutoReset = false, AutoResetInterval = 300,
    Notifications = true, TotalReps = 0,
    Fly = false, FlySpeed = 50, WalkSpeed = 16, JumpPower = 50,
    AutoRebirthCount = 0, AutoRebirthDone = 0,
    FastMode = false, HideFloatingText = false, HidePets = false,
    UseAllActions = false, MaxActionsPerRound = 5,
    TargetRebirthCount = 5, StopAtTargetRebirth = false,
    AntiKick = true, KeepAlive = true, BlockDisconnect = true,
    AutoClickTrain = false, AutoClickInterval = 0.15,
    InfiniteJump = false, Fullbright = false, NoFog = false,
    NoFallDamage = false, ShowFPS = true, ESP = false,
    ClickTeleport = false, AutoCollect = false, AutoCollectInterval = 5,
}

local ActionNames = { PushUp = "俯卧撑", SitUp = "仰卧起坐", PullUp = "引体向上", Squat = "深蹲" }
local ALL_ACTIONS = {
    "PushUp", "Dumbbell", "ShoulderPress_1", "TrendMill_1", "FlatBench_1",
    "Rock_1", "Rock_2", "Rock_3", "BarbellRack_L1", "BenchPress_L1",
    "Red slime", "FlatBench_L1", "BarbellRack_S1", "BarbellRack_1",
    "BarbellRack_2", "BenchPress_1", "BenchPress_2", "ShoulderPress_2",
    "ShoulderPress_3", "SkySlime", "FlatBench_K1"
}

local STAT_DEFS = {
    { key = "Strength", label = "力量", code = "力", color = Color3.fromRGB(212, 175, 55),
      names = { "Strength", "Power", "Str", "StrengthValue", "力量", "TotalStrength", "CrownStrength" } },
    { key = "Rebirth", label = "重生", code = "轮", color = Color3.fromRGB(200, 22, 30),
      names = { "Rebirth", "Rebirths", "RebirthCount", "RebirthLevel", "重生", "RebirthValue" } },
    { key = "Gems", label = "宝石", code = "玉", color = Color3.fromRGB(80, 200, 140),
      names = { "Gems", "Gem", "GemCount", "Diamonds", "Crystal", "宝石", "Diamond" } },
    { key = "Agility", label = "敏捷", code = "速", color = Color3.fromRGB(60, 220, 240),
      names = { "Agility", "Speed", "Agil", "AgilityValue", "敏捷", "SpeedValue" } },
}

local CONFIG_FILE = "CrownStrength_config.json"
local REBIRTH_TIMEOUT = 15
local MIN_LOOP_WAIT = 0.05
local BTN_H = 44

local function safeWait(t) task.wait(math.max(MIN_LOOP_WAIT, tonumber(t) or MIN_LOOP_WAIT)) end

-- ============================================
-- 🔴 FIX #1：独立 FPS 计数器（不再阻塞主循环）
-- ============================================
local _frameCount = 0
local _fpsTimer = tick()
local currentFps = 60
local lastPing = 0
RunService.RenderStepped:Connect(function()
    _frameCount = _frameCount + 1
    local now = tick()
    if now - _fpsTimer >= 1 then
        currentFps = math.floor(_frameCount / (now - _fpsTimer))
        _frameCount = 0
        _fpsTimer = now
        pcall(function()
            local p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            if p then lastPing = math.floor(p) end
        end)
    end
end)

-- ============================================
-- 防踢
-- ============================================
local AntiKick = { kickBlocked = 0, disconnectBlocked = 0, hooksActive = false }
local _antiKickSetup = false
local _disconnectSetup = false

local function setupAntiKick()
    if _antiKickSetup then return end
    _antiKickSetup = true
    pcall(function()
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if getnamecallmethod() == "Kick" then
                if self == LocalPlayer or self == Players then
                    AntiKick.kickBlocked = AntiKick.kickBlocked + 1
                    return
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
        AntiKick.hooksActive = true
    end)
end

local function setupDisconnectBlocker()
    if _disconnectSetup then return end
    _disconnectSetup = true
    pcall(function()
        local nc = game:GetService("NetworkClient")
        if nc then
            nc.Disconnect = newcclosure(function(self, ...)
                AntiKick.disconnectBlocked = AntiKick.disconnectBlocked + 1
            end)
        end
    end)
end

setupAntiKick(); setupDisconnectBlocker()

-- ============================================
-- 数据读取
-- ============================================
local function getCurrentStrength()
    local str = 0
    pcall(function()
        local a = LocalPlayer:GetAttribute("Strength")
        if a then str = a; return end
        if LocalPlayer.leaderstats then
            local ls = LocalPlayer.leaderstats
            if ls:FindFirstChild("Strength") then str = ls.Strength.Value; return end
            if ls:FindFirstChild("Power") then str = ls.Power.Value; return end
        end
    end)
    return str
end

local function getCurrentRebirths()
    local c = 0
    pcall(function()
        local a = LocalPlayer:GetAttribute("Rebirths") or LocalPlayer:GetAttribute("Rebirth") or LocalPlayer:GetAttribute("RebirthCount")
        if a then c = a; return end
        if LocalPlayer.leaderstats then
            for _, n in ipairs({"Rebirths","Rebirth","RebirthCount","Prestige","Reborn"}) do
                local v = LocalPlayer.leaderstats:FindFirstChild(n)
                if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then c = v.Value; return end
            end
        end
    end)
    return c
end

local statSources = {}
for _, d in ipairs(STAT_DEFS) do statSources[d.key] = { src = nil, attr = nil } end
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
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then s.src = v; return true end
        end
    end
    for _, n in ipairs(def.names) do
        local v = LocalPlayer:GetAttribute(n)
        if type(v) == "number" then s.attr = n; return true end
    end
    return false
end
local function getStat(key)
    local s = statSources[key]
    if s.src and s.src.Parent then return tonumber(s.src.Value) or 0 end
    if s.attr then return tonumber(LocalPlayer:GetAttribute(s.attr)) or 0 end
    return 0
end
local function refreshAllStats() for _, d in ipairs(STAT_DEFS) do findStat(d.key) end end

local function findRemote(name, alt)
    local list = { ReplicatedStorage, ReplicatedStorage:FindFirstChild("Remotes") }
    for _, p in ipairs(list) do
        if p then
            local r = p:FindFirstChild(name) or (alt and p:FindFirstChild(alt))
            if r then return r end
        end
    end
end
local TrainEvent = findRemote("TrainEvent", "Train")
local RebirthEvent = findRemote("RebirthEvent", "Rebirth")

local function saveConfig()
    if type(writefile) ~= "function" then return end
    pcall(function()
        local d = {}
        for k, v in pairs(Config) do
            if type(v) ~= "table" and type(v) ~= "function" then d[k] = v end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(d))
    end)
end
local function loadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(CONFIG_FILE) then return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if Config[k] ~= nil and type(Config[k]) == type(v) then Config[k] = v end
        end
    end
end
loadConfig()

-- ============================================
-- 配色
-- ============================================
local T = {
    Bg = Color3.fromRGB(6,8,12), BgDeep = Color3.fromRGB(3,4,8),
    Card = Color3.fromRGB(14,18,26), Card2 = Color3.fromRGB(22,28,38),
    Gold = Color3.fromRGB(212,175,55), GoldDim = Color3.fromRGB(140,115,35),
    GoldBright = Color3.fromRGB(255,215,90),
    Red = Color3.fromRGB(200,22,30), RedBright = Color3.fromRGB(255,60,70),
    Jade = Color3.fromRGB(80,200,140), JadeDim = Color3.fromRGB(50,130,90),
    Cyan = Color3.fromRGB(60,220,240), CyanDim = Color3.fromRGB(30,130,160),
    Purple = Color3.fromRGB(180,120,255), Orange = Color3.fromRGB(255,140,60),
    Text = Color3.fromRGB(240,235,220), TextDim = Color3.fromRGB(160,150,130),
    TextGold = Color3.fromRGB(220,190,120),
    FB = Enum.Font.GothamBold, FM = Enum.Font.GothamMedium, FN = Enum.Font.Code,
}

local function corner(p,r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,r or 8); c.Parent = p; return c end
local function stroke(p,c,t,tr) local s = Instance.new("UIStroke"); s.Color = c or T.Gold; s.Thickness = t or 1; s.Transparency = tr or 0.3; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s end
local function fmtShort(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n/1e12) end
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fK", n/1e3) end
    return tostring(math.floor(n))
end

local function huawenCorners(parent, color)
    color = color or T.Gold
    local sz, tk = 10, 2
    for _, p in ipairs({
        {UDim2.new(0,0,0,0), UDim2.new(0,sz,0,tk)},
        {UDim2.new(1,-sz,0,0), UDim2.new(0,sz,0,tk)},
        {UDim2.new(0,0,1,-tk), UDim2.new(0,sz,0,tk)},
        {UDim2.new(1,-sz,1,-tk), UDim2.new(0,sz,0,tk)},
    }) do
        local f = Instance.new("Frame"); f.Position = p[1]; f.Size = p[2]
        f.BackgroundColor3 = color; f.BorderSizePixel = 0; f.ZIndex = 10; f.Parent = parent
    end
    for _, p in ipairs({
        {UDim2.new(0,0,0,0), UDim2.new(0,tk,0,sz)},
        {UDim2.new(1,-tk,0,0), UDim2.new(0,tk,0,sz)},
        {UDim2.new(0,0,1,-sz), UDim2.new(0,tk,0,sz)},
        {UDim2.new(1,-tk,1,-sz), UDim2.new(0,tk,0,sz)},
    }) do
        local f = Instance.new("Frame"); f.Position = p[1]; f.Size = p[2]
        f.BackgroundColor3 = color; f.BorderSizePixel = 0; f.ZIndex = 10; f.Parent = parent
    end
end

-- ============================================
-- 状态
-- ============================================
local isTraining, trainThread = false, nil
local trainCount, totalCount = 0, tonumber(Config.TotalReps) or 0
local startTime = 0
local sessionStartStrength = nil
local flying, flyBV, flyBG = false, nil, nil
local flySpeed = Config.FlySpeed or 50
local pendingRebirth = false, pendingRebirthStart = 0, pendingRebirthLastValue = 0
local infiniteJumpConn = nil
local espCache = {}
-- 🟡 FIX #3：保存原始雾效
local _origFog = { End = Lighting.FogEnd, Start = Lighting.FogStart }

-- ============================================
-- 创建 UI
-- ============================================
local parentGui
pcall(function() if type(gethui) == "function" then parentGui = gethui() end end)
if not parentGui then parentGui = PlayerGui end
local old = parentGui:FindFirstChild("CrownMobileUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CrownMobileUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Enabled = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = parentGui

local vp = workspace.CurrentCamera.ViewportSize
local PANEL_W = math.min(vp.X * 0.92, 380)
local PANEL_H = math.min(vp.Y * 0.85, 640)

-- 摇杆
local JoyFrame = Instance.new("Frame")
JoyFrame.Size = UDim2.new(0,140,0,140)
JoyFrame.Position = UDim2.new(0,24,1,-180)
JoyFrame.BackgroundColor3 = T.Card; JoyFrame.BackgroundTransparency = 0.4
JoyFrame.BorderSizePixel = 0; JoyFrame.Visible = false; JoyFrame.ZIndex = 50
JoyFrame.Parent = ScreenGui
corner(JoyFrame, 70); stroke(JoyFrame, T.Gold, 2, 0.3); huawenCorners(JoyFrame, T.Gold)

local JoyKnob = Instance.new("Frame")
JoyKnob.Size = UDim2.new(0,60,0,60); JoyKnob.Position = UDim2.new(0.5,-30,0.5,-30)
JoyKnob.BackgroundColor3 = T.Gold; JoyKnob.BackgroundTransparency = 0.15
JoyKnob.BorderSizePixel = 0; JoyKnob.ZIndex = 53; JoyKnob.Parent = JoyFrame
corner(JoyKnob, 30); stroke(JoyKnob, T.GoldBright, 2, 0)

local UpBtn = Instance.new("TextButton")
UpBtn.Size = UDim2.new(0,56,0,56); UpBtn.Position = UDim2.new(1,-80,0.5,-120)
UpBtn.BackgroundColor3 = T.Card; UpBtn.BackgroundTransparency = 0.3
UpBtn.Text = "升"; UpBtn.TextColor3 = T.Jade; UpBtn.Font = T.FB; UpBtn.TextSize = 20
UpBtn.AutoButtonColor = false; UpBtn.BorderSizePixel = 0; UpBtn.Visible = false
UpBtn.ZIndex = 50; UpBtn.Parent = ScreenGui
corner(UpBtn, 28); stroke(UpBtn, T.Jade, 2, 0.3)

local DownBtn = Instance.new("TextButton")
DownBtn.Size = UDim2.new(0,56,0,56); DownBtn.Position = UDim2.new(1,-80,0.5,-20)
DownBtn.BackgroundColor3 = T.Card; DownBtn.BackgroundTransparency = 0.3
DownBtn.Text = "降"; DownBtn.TextColor3 = T.Red; DownBtn.Font = T.FB; DownBtn.TextSize = 20
DownBtn.AutoButtonColor = false; DownBtn.BorderSizePixel = 0; DownBtn.Visible = false
DownBtn.ZIndex = 50; DownBtn.Parent = ScreenGui
corner(DownBtn, 28); stroke(DownBtn, T.Red, 2, 0.3)

local joyValue = Vector2.new(0,0)
local joyActive = false
local flyUp, flyDown = false, false

JoyFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then joyActive = true end
end)
UserInputService.InputChanged:Connect(function(i)
    if not joyActive then return end
    if i.UserInputType ~= Enum.UserInputType.Touch and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local cx = JoyFrame.AbsolutePosition.X + JoyFrame.AbsoluteSize.X/2
    local cy = JoyFrame.AbsolutePosition.Y + JoyFrame.AbsoluteSize.Y/2
    local dx, dy = i.Position.X - cx, i.Position.Y - cy
    local R = JoyFrame.AbsoluteSize.X/2 - 30
    local len = math.sqrt(dx*dx + dy*dy)
    if len > R then dx = dx/len*R; dy = dy/len*R end
    joyValue = Vector2.new(dx/R, dy/R)
    JoyKnob.Position = UDim2.new(0.5, dx-30, 0.5, dy-30)
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        if joyActive then joyActive = false; joyValue = Vector2.new(0,0); JoyKnob.Position = UDim2.new(0.5,-30,0.5,-30) end
    end
end)
UpBtn.MouseButton1Down:Connect(function() flyUp = true end); UpBtn.MouseButton1Up:Connect(function() flyUp = false end); UpBtn.MouseLeave:Connect(function() flyUp = false end)
DownBtn.MouseButton1Down:Connect(function() flyDown = true end); DownBtn.MouseButton1Up:Connect(function() flyDown = false end); DownBtn.MouseLeave:Connect(function() flyDown = false end)

-- 悬浮球
local BallRing = Instance.new("Frame")
BallRing.Size = UDim2.new(0,66,0,66); BallRing.Position = UDim2.new(1,-81,0.4,-5)
BallRing.BackgroundTransparency = 1; BallRing.BorderSizePixel = 0; BallRing.ZIndex = 5
BallRing.Parent = ScreenGui
corner(BallRing, 33); stroke(BallRing, T.Gold, 2, 0.3)

local BallBtn = Instance.new("TextButton")
BallBtn.Size = UDim2.new(0,56,0,56); BallBtn.Position = UDim2.new(1,-76,0.4,0)
BallBtn.BackgroundColor3 = T.Red; BallBtn.Text = "冠"; BallBtn.TextColor3 = T.GoldBright
BallBtn.Font = T.FB; BallBtn.TextSize = 26; BallBtn.AutoButtonColor = false
BallBtn.BorderSizePixel = 0; BallBtn.Active = true; BallBtn.ZIndex = 6
BallBtn.Parent = ScreenGui
corner(BallBtn, 28); stroke(BallBtn, T.Gold, 2, 0.1)

-- 主面板
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0,PANEL_W,0,PANEL_H)
Main.Position = UDim2.new(0.5,-PANEL_W/2,0.5,-PANEL_H/2)
Main.BackgroundColor3 = T.Bg; Main.BorderSizePixel = 0; Main.Active = true
Main.ClipsDescendants = true; Main.Visible = false; Main.Parent = ScreenGui
corner(Main, 14); stroke(Main, T.Gold, 2, 0.15); huawenCorners(Main, T.Gold)

local BgGrid = Instance.new("Frame")
BgGrid.Size = UDim2.new(1,0,1,0); BgGrid.BackgroundTransparency = 1
BgGrid.ZIndex = 0; BgGrid.Parent = Main
for i = 1, 20 do
    local v = Instance.new("Frame"); v.Size = UDim2.new(0,1,1,0); v.Position = UDim2.new(0,i*24,0,0)
    v.BackgroundColor3 = T.GoldDim; v.BackgroundTransparency = 0.94; v.BorderSizePixel = 0; v.ZIndex = 0; v.Parent = BgGrid
end
for i = 1, 30 do
    local h = Instance.new("Frame"); h.Size = UDim2.new(1,0,0,1); h.Position = UDim2.new(0,0,0,i*24)
    h.BackgroundColor3 = T.GoldDim; h.BackgroundTransparency = 0.94; h.BorderSizePixel = 0; h.ZIndex = 0; h.Parent = BgGrid
end

-- 顶栏
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1,0,0,52); Header.BackgroundColor3 = T.Card
Header.BorderSizePixel = 0; Header.ZIndex = 3; Header.Parent = Main
corner(Header, 14)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1,0,0,2); topBar.BackgroundColor3 = T.Gold
topBar.BorderSizePixel = 0; topBar.ZIndex = 8; topBar.Parent = Header
local tbg = Instance.new("UIGradient")
tbg.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,T.Gold),ColorSequenceKeypoint.new(0.5,T.Red),ColorSequenceKeypoint.new(1,T.Gold)})
tbg.Parent = topBar

local Logo = Instance.new("Frame")
Logo.Size = UDim2.new(0,28,0,28); Logo.Position = UDim2.new(0,12,0.5,-14)
Logo.BackgroundColor3 = T.Red; Logo.BorderSizePixel = 0; Logo.ZIndex = 5; Logo.Parent = Header
corner(Logo, 4); stroke(Logo, T.GoldBright, 1.5, 0.2)

local LogoText = Instance.new("TextLabel")
LogoText.Size = UDim2.new(1,0,1,0); LogoText.BackgroundTransparency = 1
LogoText.Text = "冠"; LogoText.TextColor3 = T.GoldBright; LogoText.Font = T.FB
LogoText.TextSize = 16; LogoText.ZIndex = 6; LogoText.Parent = Logo

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,-130,0,20); Title.Position = UDim2.new(0,48,0,8)
Title.BackgroundTransparency = 1; Title.Text = "力量之冠 · 全能"
Title.TextColor3 = T.GoldBright; Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = T.FB; Title.TextSize = 14; Title.ZIndex = 5; Title.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1,-130,0,14); SubTitle.Position = UDim2.new(0,48,0,28)
SubTitle.BackgroundTransparency = 1; SubTitle.Text = "v6.0 · 修复版"
SubTitle.TextColor3 = T.TextDim; SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.Font = T.FN; SubTitle.TextSize = 10; SubTitle.ZIndex = 5; SubTitle.Parent = Header

local ShieldIcon = Instance.new("TextLabel")
ShieldIcon.Size = UDim2.new(0,22,0,22); ShieldIcon.Position = UDim2.new(1,-130,0.5,-11)
ShieldIcon.BackgroundTransparency = 1; ShieldIcon.Text = "护"
ShieldIcon.TextColor3 = T.Jade; ShieldIcon.Font = T.FB; ShieldIcon.TextSize = 16
ShieldIcon.ZIndex = 5; ShieldIcon.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,36,0,36); CloseBtn.Position = UDim2.new(1,-46,0.5,-18)
CloseBtn.BackgroundColor3 = T.Red; CloseBtn.BackgroundTransparency = 0.15
CloseBtn.Text = "×"; CloseBtn.TextColor3 = T.GoldBright; CloseBtn.Font = T.FB
CloseBtn.TextSize = 20; CloseBtn.AutoButtonColor = false; CloseBtn.BorderSizePixel = 0
CloseBtn.ZIndex = 5; CloseBtn.Parent = Header
corner(CloseBtn, 18); stroke(CloseBtn, T.Gold, 1.5, 0.2)

-- 状态栏
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1,-24,0,40); StatusBar.Position = UDim2.new(0,12,0,60)
StatusBar.BackgroundColor3 = T.Card; StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 2; StatusBar.Parent = Main
corner(StatusBar, 8); stroke(StatusBar, T.GoldDim, 1.5, 0.4)

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0,8,0,8); StatusDot.Position = UDim2.new(0,16,0.5,-4)
StatusDot.BackgroundColor3 = T.Red; StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 5; StatusDot.Parent = StatusBar
corner(StatusDot, 4)

local StatusLbl = Instance.new("TextLabel")
StatusLbl.Size = UDim2.new(1,-80,1,0); StatusLbl.Position = UDim2.new(0,34,0,0)
StatusLbl.BackgroundTransparency = 1; StatusLbl.Text = "· 静 待 ·"
StatusLbl.TextColor3 = T.TextGold; StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Font = T.FB; StatusLbl.TextSize = 13; StatusLbl.ZIndex = 5; StatusLbl.Parent = StatusBar

local StatusTime = Instance.new("TextLabel")
StatusTime.Size = UDim2.new(0,70,1,0); StatusTime.Position = UDim2.new(1,-78,0,0)
StatusTime.BackgroundTransparency = 1; StatusTime.Text = "00:00"
StatusTime.TextColor3 = T.TextDim; StatusTime.TextXAlignment = Enum.TextXAlignment.Right
StatusTime.Font = T.FN; StatusTime.TextSize = 11; StatusTime.ZIndex = 5; StatusTime.Parent = StatusBar

-- 内容
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1,-24,1,-160); Content.Position = UDim2.new(0,12,0,108)
Content.BackgroundTransparency = 1; Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3; Content.ScrollBarImageColor3 = T.Gold
Content.ScrollBarImageTransparency = 0.5; Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.CanvasSize = UDim2.new(0,0,0,0); Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.ZIndex = 2; Content.Parent = Main

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.FillDirection = Enum.FillDirection.Vertical
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.Padding = UDim.new(0,10)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = Content

-- 底部
local BottomBar = Instance.new("Frame")
BottomBar.Size = UDim2.new(1,-24,0,60); BottomBar.Position = UDim2.new(0,12,1,-72)
BottomBar.BackgroundTransparency = 1; BottomBar.ZIndex = 3; BottomBar.Parent = Main

local StartBtn = Instance.new("TextButton")
StartBtn.Size = UDim2.new(1,0,1,0); StartBtn.BackgroundColor3 = T.Gold
StartBtn.Text = "◈  开始修行  ◈"; StartBtn.TextColor3 = T.BgDeep
StartBtn.Font = T.FB; StartBtn.TextSize = 16; StartBtn.AutoButtonColor = false
StartBtn.BorderSizePixel = 0; StartBtn.ZIndex = 3; StartBtn.Parent = BottomBar
corner(StartBtn, 12); stroke(StartBtn, T.GoldBright, 2, 0.1); huawenCorners(StartBtn, T.BgDeep)

local StartGlow = Instance.new("Frame")
StartGlow.Size = UDim2.new(1,0,0,4); StartGlow.Position = UDim2.new(0,0,0,0)
StartGlow.BackgroundColor3 = T.GoldBright; StartGlow.BackgroundTransparency = 0.5
StartGlow.BorderSizePixel = 0; StartGlow.ZIndex = 4; StartGlow.Parent = StartBtn
corner(StartGlow, 2)

local function updateStartBtn()
    if isTraining then
        StartBtn.Text = "◈  停止修行  ◈"; StartBtn.BackgroundColor3 = T.Red
        StartBtn.TextColor3 = T.GoldBright; StartGlow.BackgroundColor3 = T.RedBright
    else
        StartBtn.Text = "◈  开始修行  ◈"; StartBtn.BackgroundColor3 = T.Gold
        StartBtn.TextColor3 = T.BgDeep; StartGlow.BackgroundColor3 = T.GoldBright
    end
end

local function makeCard(title, code, color)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,0,0,0); card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = T.Card; card.BorderSizePixel = 0; card.ZIndex = 2
    card.Parent = Content
    corner(card, 10); stroke(card, color, 1.5, 0.4)
    local sideBar = Instance.new("Frame")
    sideBar.Size = UDim2.new(0,3,0,20); sideBar.Position = UDim2.new(0,0,0,10)
    sideBar.BackgroundColor3 = color; sideBar.BorderSizePixel = 0; sideBar.ZIndex = 5
    sideBar.Parent = card
    corner(sideBar, 2)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,-60,0,20); t.Position = UDim2.new(0,14,0,8)
    t.BackgroundTransparency = 1; t.Text = title; t.TextColor3 = color
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Font = T.FB; t.TextSize = 13
    t.ZIndex = 3; t.Parent = card
    if code then
        local c = Instance.new("TextLabel")
        c.Size = UDim2.new(0,24,0,24); c.Position = UDim2.new(1,-34,0,6)
        c.BackgroundColor3 = color; c.BackgroundTransparency = 0.15; c.Text = code
        c.TextColor3 = T.BgDeep; c.TextXAlignment = Enum.TextXAlignment.Center
        c.Font = T.FB; c.TextSize = 12; c.ZIndex = 3; c.Parent = card
        corner(c, 4)
    end
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1,-20,0,1); sep.Position = UDim2.new(0,10,0,34)
    sep.BackgroundColor3 = color; sep.BackgroundTransparency = 0.7
    sep.BorderSizePixel = 0; sep.ZIndex = 3; sep.Parent = card
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1,-24,0,0); body.Position = UDim2.new(0,12,0,44)
    body.BackgroundTransparency = 1; body.AutomaticSize = Enum.AutomaticSize.Y
    body.ZIndex = 3; body.Parent = card
    local pad = Instance.new("UIPadding"); pad.PaddingBottom = UDim.new(0,14); pad.Parent = body
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0,8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = body
    return body
end

local function makeSwitch(parent, label, key, onToggle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,0,BTN_H)
    btn.BackgroundColor3 = Config[key] and T.Jade or T.Card2
    btn.Text = ""; btn.AutoButtonColor = false; btn.BorderSizePixel = 0
    btn.ZIndex = 3; btn.Parent = parent
    corner(btn, 8); stroke(btn, Config[key] and T.Jade or T.GoldDim, 1.5, Config[key] and 0.2 or 0.5)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-80,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = Config[key] and T.BgDeep or T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FB; lbl.TextSize = 13; lbl.ZIndex = 4; lbl.Parent = btn
    local state = Instance.new("TextLabel")
    state.Size = UDim2.new(0,60,1,0); state.Position = UDim2.new(1,-70,0,0)
    state.BackgroundTransparency = 1; state.Text = Config[key] and "启" or "止"
    state.TextColor3 = Config[key] and T.BgDeep or T.TextDim
    state.Font = T.FB; state.TextSize = 14; state.ZIndex = 4; state.Parent = btn
    local function refresh()
        local on = Config[key]
        btn.BackgroundColor3 = on and T.Jade or T.Card2
        stroke(btn, on and T.Jade or T.GoldDim, 1.5, on and 0.2 or 0.5)
        lbl.TextColor3 = on and T.BgDeep or T.Text
        state.Text = on and "启" or "止"
        state.TextColor3 = on and T.BgDeep or T.TextDim
    end
    btn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        if key == "AutoRebirth" and Config[key] and not RebirthEvent then Config[key] = false end
        refresh()
        if onToggle then onToggle(Config[key]) end
        saveConfig()
    end)
end

local function makeNumber(parent, label, key, minV, maxV, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,BTN_H); row.BackgroundColor3 = T.Card2
    row.BorderSizePixel = 0; row.ZIndex = 3; row.Parent = parent
    corner(row, 8); stroke(row, T.GoldDim, 1, 0.5)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5,-14,1,0); lbl.Position = UDim2.new(0,14,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = label; lbl.TextColor3 = T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = T.FB; lbl.TextSize = 13; lbl.ZIndex = 4; lbl.Parent = row
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5,-14,0,BTN_H-12); box.Position = UDim2.new(0.5,0,0,6)
    box.BackgroundColor3 = T.BgDeep; box.Text = tostring(Config[key])
    box.TextColor3 = T.GoldBright; box.Font = T.FN; box.TextSize = 15
    box.ClearTextOnFocus = false; box.BorderSizePixel = 0
    box.ZIndex = 4; box.Parent = row
    corner(box, 6); stroke(box, T.GoldDim, 1, 0.4)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n and n >= minV and n <= maxV then
            box.Text = tostring(n); Config[key] = n
            if onChange then onChange(n) end
            saveConfig()
        else box.Text = tostring(Config[key]) end
    end)
end

local function makeInfo(parent, label, code, color)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,38); row.BackgroundColor3 = T.Card2
    row.BorderSizePixel = 0; row.ZIndex = 3; row.Parent = parent
    corner(row, 6); stroke(row, color, 1, 0.6)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6,-14,1,0); l.Position = UDim2.new(0,14,0,0)
    l.BackgroundTransparency = 1
    l.Text = code and (code .. " · " .. label) or label
    l.TextColor3 = T.TextDim; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = T.FB; l.TextSize = 12; l.ZIndex = 4; l.Parent = row
    local v = Instance.new("TextLabel")
    v.Size = UDim2.new(0.4,-14,1,0); v.Position = UDim2.new(0.6,0,0,0)
    v.BackgroundTransparency = 1; v.Text = "—"; v.TextColor3 = color or T.Text
    v.TextXAlignment = Enum.TextXAlignment.Right; v.Font = T.FB
    v.TextSize = 16; v.ZIndex = 4; v.Parent = row
    return v
end

-- ============================================
-- 卡片
-- ============================================
local cardShield = makeCard("护体金刚", "金", T.Jade)
local kickBlockedLbl = makeInfo(cardShield, "已拦截踢出", "拦", T.Jade)
local disconnectBlockedLbl = makeInfo(cardShield, "已拦截断开", "断", T.Jade)
local shieldStatusLbl = makeInfo(cardShield, "护盾状态", "御", T.Jade)

local statCard = makeCard("天机属性", "天", T.Gold)
local statRefs = {}
for _, def in ipairs(STAT_DEFS) do statRefs[def.key] = makeInfo(statCard, def.label, def.code, def.color) end

local cardPower = makeCard("修行记", "记", T.Gold)
local rowStrength = makeInfo(cardPower, "当前力量", "力", T.Gold)
local rowSession  = makeInfo(cardPower, "本次增长", "长", T.Jade)
local rowPerRep   = makeInfo(cardPower, "每次增量", "增", T.Purple)

local card21 = makeCard("廿一秘法", "廿", T.Red)
makeSwitch(card21, "⚔️ 开启廿一秘法(自动修炼)", "UseAllActions", function(on)
    if on then
        if not isTraining then startAutoTrain(); updateStartBtn(); updateStatus() end
    else
        if isTraining then stopAutoTrain(); updateStartBtn(); updateStatus() end
    end
end)
makeNumber(card21, "每轮秘法数", "MaxActionsPerRound", 1, 21)
makeNumber(card21, "间隔(秒)", "Interval", 0.05, 10)

local cardTrain = makeCard("修炼控制", "修", T.Jade)
makeSwitch(cardTrain, "御风极速", "FastMode")

local cardAutoClick = makeCard("无为妙法", "无", T.Orange)
makeSwitch(cardAutoClick, "👆 自动点击(道法自然)", "AutoClickTrain")
makeNumber(cardAutoClick, "点击间隔(秒)", "AutoClickInterval", 0.05, 5)
local clickCountLbl = makeInfo(cardAutoClick, "已点击次数", "数", T.Orange)
local clickStatusLbl = makeInfo(cardAutoClick, "按钮状态", "寻", T.Orange)

local cardMove = makeCard("御风飞行", "御", T.Cyan)
makeSwitch(cardMove, "🕹️ 开启御风(轮盘)", "Fly", function(on)
    if on then
        startFly()
        JoyFrame.Visible = true; UpBtn.Visible = true; DownBtn.Visible = true
    else
        stopFly()
        JoyFrame.Visible = false; UpBtn.Visible = false; DownBtn.Visible = false
    end
end)
makeSwitch(cardMove, "🦘 无限跳跃", "InfiniteJump", function(on)
    if on then
        if not infiniteJumpConn then
            infiniteJumpConn = UserInputService.JumpRequest:Connect(function()
                if Config.InfiniteJump then
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end
            end)
        end
    else
        if infiniteJumpConn then pcall(function() infiniteJumpConn:Disconnect() end); infiniteJumpConn = nil end
    end
end)
makeSwitch(cardMove, "🖱️ 点击瞬移", "ClickTeleport")
makeNumber(cardMove, "步行速度", "WalkSpeed", 16, 500, function(v) Config.WalkSpeed = v; applyWalkSpeed() end)
makeNumber(cardMove, "跳跃力", "JumpPower", 50, 500, function(v)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.JumpPower = v; hum.UseJumpPower = true end
end)
makeNumber(cardMove, "飞行速度", "FlySpeed", 10, 500, function(v) flySpeed = v end)

-- 视觉
local _fullbrightOriginal = nil
local cardVisual = makeCard("玄光术", "玄", T.Cyan)
makeSwitch(cardVisual, "☀️ 全亮模式", "Fullbright", function(on)
    if on then
        if not _fullbrightOriginal then
            _fullbrightOriginal = {
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
            }
        end
        Lighting.Ambient = Color3.fromRGB(200,200,200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200,200,200)
        Lighting.Brightness = 3
    else
        if _fullbrightOriginal then
            Lighting.Ambient = _fullbrightOriginal.Ambient
            Lighting.OutdoorAmbient = _fullbrightOriginal.OutdoorAmbient
            Lighting.Brightness = _fullbrightOriginal.Brightness
            _fullbrightOriginal = nil
        end
    end
end)

-- 🟡 FIX #3：去雾关闭时恢复原始值
makeSwitch(cardVisual, "🌫️ 去雾", "NoFog", function(on)
    if on then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    else
        Lighting.FogEnd = _origFog.End
        Lighting.FogStart = _origFog.Start
    end
end)

makeSwitch(cardVisual, "👁️ 玩家透视(ESP)", "ESP")
makeSwitch(cardVisual, "隐去浮字", "HideFloatingText")
makeSwitch(cardVisual, "隐去宠物", "HidePets")

-- 玩家
local cardPlayers = makeCard("江湖人物", "人", T.Gold)
local playerCountLbl = makeInfo(cardPlayers, "在线人数", "数", T.Gold)
local serverInfoLbl = makeInfo(cardPlayers, "服务器", "服", T.Gold)

-- 重生
local cardRebirth = makeCard("轮回重生", "轮", T.Purple)
makeSwitch(cardRebirth, "自动重生", "AutoRebirth")
makeSwitch(cardRebirth, "达标自动停止", "StopAtTargetRebirth")
makeNumber(cardRebirth, "目标重生数", "TargetRebirthCount", 0, 99999)
local gameRebirthLbl = makeInfo(cardRebirth, "游戏内重生数", "游", T.Purple)
local doneLbl = makeInfo(cardRebirth, "已成功重生", "成", T.Jade)

-- 自动领取
local cardAuto = makeCard("天赐福缘", "缘", T.Orange)
makeSwitch(cardAuto, "🎁 自动领取奖励", "AutoCollect")
makeNumber(cardAuto, "领取间隔(秒)", "AutoCollectInterval", 1, 60)
local collectCountLbl = makeInfo(cardAuto, "已领取次数", "领", T.Orange)

-- 防踢
local cardAntiKick = makeCard("护道秘术", "护", T.Jade)
makeSwitch(cardAntiKick, "🛡 防踢保护", "AntiKick")
makeSwitch(cardAntiKick, "💓 保活心跳", "KeepAlive")
makeSwitch(cardAntiKick, "🔒 阻止断开", "BlockDisconnect")

-- 系统
local cardOther = makeCard("道枢设置", "道", T.TextDim)
makeSwitch(cardOther, "反挂机", "AntiAfk")
makeSwitch(cardOther, "自动重置", "AutoReset")
makeSwitch(cardOther, "通知提示", "Notifications")

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1,0,0,14); hintLbl.Position = UDim2.new(0,0,0,-16)
hintLbl.BackgroundTransparency = 1; hintLbl.Text = "⟨ 拖顶栏移面板 · 点印章展开 ⟩"
hintLbl.TextColor3 = T.GoldDim; hintLbl.TextXAlignment = Enum.TextXAlignment.Center
hintLbl.Font = T.FN; hintLbl.TextSize = 10; hintLbl.ZIndex = 4; hintLbl.Parent = Main

-- ============================================
-- 拖动
-- ============================================
local draggingHeader, headerDragStart, headerStartPos = false, nil, nil
local draggingBall, ballDragStart, ballStartPos, ballMoved = false, nil, nil, false
local ballRingStartPos = BallRing.Position

Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        draggingHeader = true; headerDragStart = i.Position; headerStartPos = Main.Position
    end
end)
BallBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        draggingBall = true; ballMoved = false
        ballDragStart = i.Position; ballStartPos = BallBtn.Position; ballRingStartPos = BallRing.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
    if draggingHeader then
        local delta = i.Position - headerDragStart
        Main.Position = UDim2.new(headerStartPos.X.Scale, headerStartPos.X.Offset+delta.X, headerStartPos.Y.Scale, headerStartPos.Y.Offset+delta.Y)
    elseif draggingBall then
        local delta = i.Position - ballDragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then ballMoved = true end
        BallBtn.Position = UDim2.new(ballStartPos.X.Scale, ballStartPos.X.Offset+delta.X, ballStartPos.Y.Scale, ballStartPos.Y.Offset+delta.Y)
        BallRing.Position = UDim2.new(ballRingStartPos.X.Scale, ballRingStartPos.X.Offset+delta.X, ballRingStartPos.Y.Scale, ballRingStartPos.Y.Offset+delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
    if draggingHeader then draggingHeader = false end
    if draggingBall then
        draggingBall = false
        if not ballMoved then
            BallBtn.Visible = false; BallRing.Visible = false; Main.Visible = true
        end
    end
end)
CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false; BallBtn.Visible = true; BallRing.Visible = true
end)

-- ============================================
-- 状态更新
-- ============================================
local lastStatus = ""
local function updateStatus()
    local s = isTraining and ("run:" .. (Config.UseAllActions and "all" or Config.Action)) or "idle"
    if s == lastStatus then return end
    lastStatus = s
    if isTraining then
        StatusDot.BackgroundColor3 = T.Jade
        StatusLbl.Text = "· 修 行 中 · " .. (Config.UseAllActions and "廿一秘法" or (ActionNames[Config.Action] or Config.Action))
        StatusLbl.TextColor3 = T.Jade
    else
        StatusDot.BackgroundColor3 = T.Red
        StatusLbl.Text = "· 静 待 ·"
        StatusLbl.TextColor3 = T.TextGold
    end
end

function applyWalkSpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    end
end

function startFly()
    if flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5,1e5,1e5); flyBV.Velocity = Vector3.zero; flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); flyBG.P = 3000; flyBG.D = 500; flyBG.Parent = hrp
    flying = true
end

function stopFly()
    if not flying then return end
    flying = false
    joyValue = Vector2.new(0,0); flyUp = false; flyDown = false
    JoyKnob.Position = UDim2.new(0.5,-30,0.5,-30)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    applyWalkSpeed()
end

local actionIndices = {}
for i = 1, #ALL_ACTIONS do table.insert(actionIndices, i) end
local function shuffleActions()
    local s = table.clone(actionIndices)
    for i = #s, 2, -1 do local j = math.random(i); s[i],s[j] = s[j],s[i] end
    return s
end

function startAutoTrain()
    if isTraining then return end
    if not TrainEvent then return end
    isTraining = true; trainCount = 0; startTime = tick()
    if LocalPlayer.leaderstats and LocalPlayer.leaderstats:FindFirstChild("Strength") then
        sessionStartStrength = LocalPlayer.leaderstats.Strength.Value
    end
    trainThread = task.spawn(function()
        while isTraining and ScreenGui.Parent do
            local interval = math.max(0.05, Config.Interval)
            if Config.UseAllActions then
                local sh = shuffleActions()
                local count = math.min(Config.MaxActionsPerRound, #sh)
                for i = 1, count do
                    if not isTraining then break end
                    pcall(function() TrainEvent:FireServer(ALL_ACTIONS[sh[i]]) end)
                    trainCount = trainCount + 1; totalCount = totalCount + 1
                    task.wait(Config.FastMode and 0.01 or 0.03)
                end
            else
                pcall(function() TrainEvent:FireServer(Config.Action) end)
                trainCount = trainCount + 1; totalCount = totalCount + 1
            end
            Config.TotalReps = totalCount
            safeWait(interval)
        end
        if isTraining then isTraining = false end
    end)
    updateStatus()
end

function stopAutoTrain()
    if not isTraining then return end
    isTraining = false
    if trainThread then pcall(task.cancel, trainThread); trainThread = nil end
    saveConfig(); updateStatus()
end

StartBtn.MouseButton1Click:Connect(function()
    if isTraining then stopAutoTrain() else startAutoTrain() end
    updateStartBtn(); updateStatus()
end)

-- ============================================
-- 自动点击
-- ============================================
local autoClickCount = 0
local cachedButton = nil
local lastScanTime = 0
local TRAIN_KEYWORDS = { "train","workout","exercise","pushup","situp","pullup","squat","dumbbell","bench","trendmill" }

local function matchButton(obj)
    if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
    if not obj.Visible then return false end
    local nameLower = string.lower(obj.Name)
    local textLower = ""
    if obj:IsA("TextButton") then textLower = string.lower(obj.Text or "") end
    for _, kw in ipairs(TRAIN_KEYWORDS) do
        if string.find(nameLower, kw, 1, true) then return true end
        if textLower ~= "" and string.find(textLower, kw, 1, true) then return true end
    end
    for _, action in ipairs(ALL_ACTIONS) do
        local a = string.lower(action)
        if nameLower == a or textLower == a then return true end
    end
    return false
end

local function findTrainButton()
    local now = tick()
    if cachedButton and cachedButton.Parent and cachedButton.Visible and (now - lastScanTime) < 2 then return cachedButton end
    lastScanTime = now
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, obj in ipairs(pg:GetDescendants()) do
        if matchButton(obj) then
            local ap = obj.AbsolutePosition; local as = obj.AbsoluteSize
            if ap and as and as.X > 0 and as.Y > 0 then cachedButton = obj; return obj end
        end
    end
    cachedButton = nil; return nil
end

local function clickButton(btn)
    if not btn or not btn.Parent then return false end
    local ap = btn.AbsolutePosition; local as = btn.AbsoluteSize
    if not ap or not as or as.X <= 0 then return false end
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(ap.X + as.X/2, ap.Y + as.Y/2, 0, true, game, 1)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(ap.X + as.X/2, ap.Y + as.Y/2, 0, false, game, 1)
    end)
    return true
end

local function autoClickTick()
    if not Config.AutoClickTrain then
        clickStatusLbl.Text = "止"; clickStatusLbl.TextColor3 = T.TextDim; return
    end
    local btn = findTrainButton()
    if btn then
        clickStatusLbl.Text = "寻得"; clickStatusLbl.TextColor3 = T.Jade
        if clickButton(btn) then
            autoClickCount = autoClickCount + 1
            trainCount = trainCount + 1; totalCount = totalCount + 1
            Config.TotalReps = totalCount
        end
    else
        clickStatusLbl.Text = "未寻"; clickStatusLbl.TextColor3 = T.Red
    end
end

-- ============================================
-- 🟡 FIX #2：ESP 全生命周期管理
-- ============================================
local function clearESPFor(player)
    local hl = espCache[player]
    if hl then
        pcall(function() hl:Destroy() end)
        espCache[player] = nil
    end
end

local function updateESP()
    if not Config.ESP then
        for p, obj in pairs(espCache) do
            pcall(function() obj:Destroy() end)
        end
        espCache = {}
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local hl = espCache[p]
                    if not hl or not hl.Parent then
                        hl = Instance.new("Highlight")
                        hl.Name = "CrownESP"
                        hl.FillColor = T.GoldBright
                        hl.OutlineColor = T.Red
                        hl.FillTransparency = 0.6
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = p.Character
                        espCache[p] = hl
                    end
                end
            else
                clearESPFor(p)
            end
        end
    end
    -- 清理已离开的玩家
    for p in pairs(espCache) do
        if not p.Parent then clearESPFor(p) end
    end
end

-- 玩家离开时清理 ESP
Players.PlayerRemoving:Connect(function(p) clearESPFor(p) end)

-- 玩家角色重生时重建
local function hookPlayerChar(p)
    p.CharacterAdded:Connect(function()
        if Config.ESP then
            task.wait(0.5)
            clearESPFor(p)
            updateESP()
        end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then hookPlayerChar(p) end
end
Players.PlayerAdded:Connect(hookPlayerChar)

-- 点击瞬移
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if not Config.ClickTeleport then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local camera = workspace.CurrentCamera
        local mousePos = input.Position
        local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        local ray = Ray.new(unitRay.Origin, unitRay.Direction * 1000)
        local ignoreList = { LocalPlayer.Character }
        local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
        if pos then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
        end
    end
end)

-- ============================================
-- 后台
-- ============================================
local lastStrengthText, lastSessionText, lastPerRepText
local lastGameRebirthText, lastDoneText, lastClickCountText, lastCollectText
local lastStatText = {}

local function fireAntiAfk()
    if not Config.AntiAfk then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, true, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space, false, false, game)
    end)
end
LocalPlayer.Idled:Connect(fireAntiAfk)

local function handleFloatingText()
    if not Config.HideFloatingText then return end
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local tg = pg and pg:FindFirstChild("TweenGui")
        if tg then
            for _, v in ipairs(tg:GetDescendants()) do
                if (v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("ImageLabel")) and v.Visible then v.Visible = false end
            end
        end
    end)
end

local function handlePets()
    local char = LocalPlayer.Character
    for _, v in ipairs(workspace:GetChildren()) do
        if v ~= char and (v:IsA("Model") or v:IsA("Folder")) then
            local ln = string.lower(v.Name)
            local isPet = string.find(ln, "pet") or string.find(ln, "slime") or string.find(ln, "egg")
            if not isPet and v.Parent then isPet = string.find(string.lower(v.Parent.Name), "pet") end
            if isPet then
                for _, part in ipairs(v:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if Config.HidePets then part.LocalTransparencyModifier = 1; part.CanCollide = false
                        else part.LocalTransparencyModifier = 0; part.CanCollide = true end
                    end
                end
            end
        end
    end
end

local function handleAutoReset()
    if not Config.AutoReset then return end
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 else char:BreakJoints() end
        end
    end)
end

local collectCount = 0
local function handleAutoCollect()
    if not Config.AutoCollect then return end
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, obj in ipairs(pg:GetDescendants()) do
            if obj.Visible and (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
                local nameLower = string.lower(obj.Name)
                local textLower = ""
                if obj:IsA("TextButton") then textLower = string.lower(obj.Text or "") end
                if string.find(nameLower, "claim") or string.find(textLower, "claim")
                    or string.find(nameLower, "collect") or string.find(textLower, "collect")
                    or string.find(nameLower, "reward") or string.find(textLower, "reward")
                    or string.find(nameLower, "领取") or string.find(textLower, "领取") then
                    local ap = obj.AbsolutePosition; local as = obj.AbsoluteSize
                    if ap and as and as.X > 0 then
                        pcall(function()
                            VirtualInputManager:SendMouseButtonEvent(ap.X + as.X/2, ap.Y + as.Y/2, 0, true, game, 1)
                            task.wait(0.02)
                            VirtualInputManager:SendMouseButtonEvent(ap.X + as.X/2, ap.Y + as.Y/2, 0, false, game, 1)
                        end)
                        collectCount = collectCount + 1
                    end
                end
            end
        end
    end)
end

local function checkRebirth()
    if not pendingRebirth then return end
    local g = getCurrentRebirths()
    if g > pendingRebirthLastValue then
        pendingRebirth = false
        Config.AutoRebirthDone = Config.AutoRebirthDone + 1
        saveConfig()
        if Config.StopAtTargetRebirth and Config.TargetRebirthCount > 0 and g >= Config.TargetRebirthCount then
            Config.AutoRebirth = false; saveConfig()
        end
    elseif tick() - pendingRebirthStart > REBIRTH_TIMEOUT then
        pendingRebirth = false
    end
end

local function tryRebirth()
    if not Config.AutoRebirth or not RebirthEvent or pendingRebirth then return end
    local g = getCurrentRebirths()
    if Config.StopAtTargetRebirth and Config.TargetRebirthCount > 0 and g >= Config.TargetRebirthCount then
        Config.AutoRebirth = false; saveConfig()
    else
        pendingRebirthLastValue = g; pendingRebirth = true; pendingRebirthStart = tick()
        pcall(function() RebirthEvent:FireServer("Start") end)
        task.wait(0.5)
        pcall(function() RebirthEvent:FireServer("Update") end)
    end
end

local function updateStats()
    refreshAllStats()
    for _, def in ipairs(STAT_DEFS) do
        local val = getStat(def.key)
        local newText = fmtShort(val)
        if lastStatText[def.key] ~= newText then
            lastStatText[def.key] = newText
            local ref = statRefs[def.key]; if ref then ref.Text = newText end
        end
    end
    local curStrength = getStat("Strength")
    if curStrength == 0 then curStrength = getCurrentStrength() end
    if sessionStartStrength == nil then sessionStartStrength = curStrength end
    local gain = curStrength - sessionStartStrength
    local st = fmtShort(curStrength)
    if lastStrengthText ~= st then lastStrengthText = st; rowStrength.Text = st end
    local ss = (gain >= 0 and "+" or "") .. fmtShort(gain)
    if lastSessionText ~= ss then
        lastSessionText = ss; rowSession.Text = ss
        rowSession.TextColor3 = gain > 0 and T.Jade or (gain < 0 and T.Red or T.Text)
    end
    local pr = (trainCount > 0 and gain > 0) and string.format("%.2f", gain/trainCount) or "—"
    if lastPerRepText ~= pr then lastPerRepText = pr; rowPerRep.Text = pr end
    local gt = tostring(getCurrentRebirths())
    if lastGameRebirthText ~= gt then lastGameRebirthText = gt; gameRebirthLbl.Text = gt end
    local dt = tostring(Config.AutoRebirthDone)
    if lastDoneText ~= dt then lastDoneText = dt; doneLbl.Text = dt end
    local ct = tostring(autoClickCount)
    if lastClickCountText ~= ct then lastClickCountText = ct; clickCountLbl.Text = ct end
    local co = tostring(collectCount)
    if lastCollectText ~= co then lastCollectText = co; collectCountLbl.Text = co end
    kickBlockedLbl.Text = tostring(AntiKick.kickBlocked)
    disconnectBlockedLbl.Text = tostring(AntiKick.disconnectBlocked)
    if AntiKick.hooksActive then
        shieldStatusLbl.Text = "全御"; shieldStatusLbl.TextColor3 = T.Jade
    elseif Config.AntiKick then
        shieldStatusLbl.Text = "半御"; shieldStatusLbl.TextColor3 = T.Gold
    else
        shieldStatusLbl.Text = "未御"; shieldStatusLbl.TextColor3 = T.Red
    end
    playerCountLbl.Text = tostring(#Players:GetPlayers())
    serverInfoLbl.Text = "P:" .. game.PlaceId
end

local lastClock = ""
local function updateClock()
    if not isTraining and not Config.AutoClickTrain then
        if lastClock ~= "00:00" then lastClock = "00:00"; StatusTime.Text = "00:00" end
        return
    end
    if not startTime or startTime == 0 then startTime = tick() end
    local e = math.floor(tick() - startTime)
    local txt = string.format("%02d:%02d", math.floor(e/60), e%60)
    if lastClock ~= txt then lastClock = txt; StatusTime.Text = txt end
end

-- FPS 显示
local FpsDisplay = Instance.new("TextLabel")
FpsDisplay.Size = UDim2.new(0,110,0,22)
FpsDisplay.Position = UDim2.new(1,-130,0,4)
FpsDisplay.BackgroundColor3 = T.Card
FpsDisplay.BackgroundTransparency = 0.3
FpsDisplay.Text = "FPS:60 | 0ms"
FpsDisplay.TextColor3 = T.GoldBright
FpsDisplay.Font = T.FN
FpsDisplay.TextSize = 12
FpsDisplay.BorderSizePixel = 0
FpsDisplay.Visible = false
FpsDisplay.ZIndex = 20
FpsDisplay.Parent = ScreenGui
corner(FpsDisplay, 6)
stroke(FpsDisplay, T.GoldDim, 1, 0.4)

local lastFpsText = ""
local function updateFpsDisplay()
    FpsDisplay.Visible = Config.ShowFPS
    if not Config.ShowFPS then return end
    local txt = string.format("FPS:%d | %dms", currentFps, lastPing)
    if lastFpsText ~= txt then
        lastFpsText = txt
        FpsDisplay.Text = txt
    end
end

-- 无摔落伤害
RunService.Heartbeat:Connect(function()
    if not Config.NoFallDamage then return end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
        end
    end
end)

-- ============================================
-- 主调度
-- ============================================
task.spawn(function()
    local S = { stat=0, status=0, rebirth=0, visual=0, pets=0, anti=0, autoReset=0, autoRebirth=0, clock=0, click=0, esp=0, fps=0, collect=0 }
    while ScreenGui.Parent do
        local now = tick()
        if now - S.stat >= 0.8 then S.stat = now; updateStats() end
        if now - S.status >= 1 then S.status = now; updateStatus() end
        if now - S.clock >= 0.5 then S.clock = now; updateClock() end
        if now - S.rebirth >= 0.5 then S.rebirth = now; checkRebirth() end
        if now - S.visual >= 0.3 then S.visual = now; handleFloatingText() end
        if now - S.pets >= 1.0 then S.pets = now; handlePets() end
        if now - S.anti >= 60 then S.anti = now; fireAntiAfk() end
        if now - S.autoReset >= Config.AutoResetInterval then S.autoReset = now; handleAutoReset() end
        if now - S.autoRebirth >= Config.AutoRebirthDelay then S.autoRebirth = now; tryRebirth() end
        if now - S.click >= Config.AutoClickInterval then S.click = now; autoClickTick() end
        if now - S.esp >= 0.3 then S.esp = now; updateESP() end
        if now - S.fps >= 0.5 then S.fps = now; updateFpsDisplay() end
        if now - S.collect >= Config.AutoCollectInterval then S.collect = now; handleAutoCollect() end
        task.wait(0.05)
    end
end)

-- 印章脉冲
task.spawn(function()
    while ScreenGui.Parent do
        if BallBtn.Visible then
            local tw = TweenService:Create(BallRing, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                Size = UDim2.new(0,76,0,76), Position = BallBtn.Position - UDim2.new(0,10,0,10)
            })
            tw:Play(); task.wait(1)
            if not BallBtn.Visible then break end
            BallRing.Size = UDim2.new(0,66,0,66)
            BallRing.Position = BallBtn.Position - UDim2.new(0,5,0,5)
            task.wait(1)
        else task.wait(0.5) end
    end
end)

-- 飞行循环
RunService.RenderStepped:Connect(function()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then stopFly() return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not flyBV or not flyBG then return end
    -- 🟢 FIX #4：动态获取当前 Camera
    local cam = workspace.CurrentCamera
    if not cam then return end
    local dir = Vector3.zero
    if joyValue.Magnitude > 0.1 then
        dir = cam.CFrame.LookVector * (-joyValue.Y) + cam.CFrame.RightVector * joyValue.X
    end
    if flyUp then dir = dir + Vector3.new(0,1,0) end
    if flyDown then dir = dir - Vector3.new(0,1,0) end
    if dir.Magnitude > 0 then
        dir = dir.Unit * flySpeed
        local st = math.min(joyValue.Magnitude, 1)
        if st < 0.1 then st = 1 end
        dir = dir * st
    end
    flyBV.Velocity = dir
    flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyWalkSpeed()
    if flying then
        flying = false
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        if Config.Fly then startFly() end
    end
end)

updateStartBtn(); updateStatus(); applyWalkSpeed()

if Config.Fly then task.defer(function()
    startFly(); JoyFrame.Visible = true; UpBtn.Visible = true; DownBtn.Visible = true
end) end

if Config.UseAllActions and TrainEvent then
    task.defer(function() startAutoTrain(); updateStartBtn(); updateStatus() end)
end

-- 🟢 FIX #4：使用 workspace.CurrentCamera 动态监听
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            local v = cam.ViewportSize
            Main.Size = UDim2.new(0, math.min(v.X * 0.92, 380), 0, math.min(v.Y * 0.85, 640))
        end)
    end
end)

local currentCam = workspace.CurrentCamera
if currentCam then
    currentCam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local v = currentCam.ViewportSize
        Main.Size = UDim2.new(0, math.min(v.X * 0.92, 380), 0, math.min(v.Y * 0.85, 640))
    end)
end