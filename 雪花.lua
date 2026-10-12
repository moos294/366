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

local ActionNames = {
    PushUp = "俯卧撑",
    SitUp = "仰卧起坐",
    PullUp = "引体向上",
    Squat = "深蹲"
}

local ALL_ACTIONS = {
    "PushUp", "Dumbbell", "ShoulderPress_1", "TrendMill_1", "FlatBench_1",
    "Rock_1", "Rock_2", "Rock_3", "BarbellRack_L1", "BenchPress_L1",
    "Red slime", "FlatBench_L1", "BarbellRack_S1", "BarbellRack_1",
    "BarbellRack_2", "BenchPress_1", "BenchPress_2", "ShoulderPress_2",
    "ShoulderPress_3", "SkySlime", "FlatBench_K1"
}

local STAT_DEFS = {
    { key = "Strength", label = "力量", code = "力", color = Color3.fromRGB(212, 175, 55), names = { "Strength", "Power", "Str", "StrengthValue", "力量", "TotalStrength", "CrownStrength" } },
    { key = "Rebirth", label = "重生", code = "轮", color = Color3.fromRGB(220, 60, 60), names = { "Rebirth", "Rebirths", "RebirthCount", "RebirthLevel", "重生", "RebirthValue" } },
    { key = "Gems", label = "宝石", code = "玉", color = Color3.fromRGB(90, 190, 160), names = { "Gems", "Gem", "GemCount", "Diamonds", "Crystal", "宝石", "Diamond" } },
    { key = "Agility", label = "敏捷", code = "速", color = Color3.fromRGB(80, 200, 220), names = { "Agility", "Speed", "Agil", "AgilityValue", "敏捷", "SpeedValue" } },
}

local CONFIG_FILE = "CrownStrength_config.json"
local REBIRTH_TIMEOUT = 15
local MIN_LOOP_WAIT = 0.05
local BTN_H = 44

local isTraining, trainThread = false, nil
local trainCount, totalCount = 0, tonumber(Config.TotalReps) or 0
local sessionStartStrength = nil
local flying, flyBV, flyBG = false, nil, nil
local flySpeed = Config.FlySpeed or 50
local pendingRebirth = false, pendingRebirthStart = 0, pendingRebirthLastValue = 0
local infiniteJumpConn = nil
local espCache = {}
local _origFog = { End = Lighting.FogEnd, Start = Lighting.FogStart }
local antiAfkConn = nil
local joyValue = Vector2.new(0,0)
local joyActive = false
local flyUp, flyDown = false, false

local function safeWait(t)
    task.wait(math.max(MIN_LOOP_WAIT, tonumber(t) or MIN_LOOP_WAIT))
end

local T = {
    Bg         = Color3.fromRGB(10, 14, 18),
    BgDeep     = Color3.fromRGB(5, 8, 10),
    BgCard     = Color3.fromRGB(14, 22, 28),
    BgCard2    = Color3.fromRGB(20, 32, 40),
    Bronze     = Color3.fromRGB(175, 145, 90),
    BronzeDeep = Color3.fromRGB(110, 90, 55),
    BronzeLight = Color3.fromRGB(220, 190, 130),
    CyanDeep   = Color3.fromRGB(40, 120, 140),
    Cyan       = Color3.fromRGB(72, 190, 200),
    CyanGlow   = Color3.fromRGB(120, 230, 240),
    Jade       = Color3.fromRGB(96, 180, 150),
    JadeDeep   = Color3.fromRGB(56, 120, 100),
    Red        = Color3.fromRGB(210, 70, 70),
    RedDeep    = Color3.fromRGB(150, 40, 40),
    Purple     = Color3.fromRGB(140, 120, 200),
    Text       = Color3.fromRGB(230, 235, 238),
    TextDim    = Color3.fromRGB(140, 160, 170),
    TextGold   = Color3.fromRGB(215, 185, 130),
    TextCyan   = Color3.fromRGB(160, 220, 230),
    FB = Enum.Font.GothamBold,
    FM = Enum.Font.GothamMedium,
    FN = Enum.Font.Code,
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
    return c
end

local function stroke(p, c, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = c or T.Bronze
    s.Thickness = t or 1
    s.Transparency = tr or 0.4
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = p
    return s
end

local function fmtShort(n)
    n = tonumber(n) or 0
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

local function huiwenBorder(parent, color, thickness)
    color = color or T.Bronze
    thickness = thickness or 2
    local top = Instance.new("Frame")
    top.Name = "HuiwenTop"
    top.Size = UDim2.new(1, -16, 0, thickness)
    top.Position = UDim2.new(0, 8, 0, 0)
    top.BackgroundColor3 = color
    top.BorderSizePixel = 0
    top.ZIndex = 11
    top.Parent = parent
    local bottom = Instance.new("Frame")
    bottom.Name = "HuiwenBottom"
    bottom.Size = UDim2.new(1, -16, 0, thickness)
    bottom.Position = UDim2.new(0, 8, 1, -thickness)
    bottom.BackgroundColor3 = color
    bottom.BorderSizePixel = 0
    bottom.ZIndex = 11
    bottom.Parent = parent
    local left = Instance.new("Frame")
    left.Name = "HuiwenLeft"
    left.Size = UDim2.new(0, thickness, 1, -16)
    left.Position = UDim2.new(0, 0, 0, 8)
    left.BackgroundColor3 = color
    left.BorderSizePixel = 0
    left.ZIndex = 11
    left.Parent = parent
    local right = Instance.new("Frame")
    right.Name = "HuiwenRight"
    right.Size = UDim2.new(0, thickness, 1, -16)
    right.Position = UDim2.new(1, -thickness, 0, 8)
    right.BackgroundColor3 = color
    right.BorderSizePixel = 0
    right.ZIndex = 11
    right.Parent = parent
end

local function chineseCorners(parent, color, size)
    color = color or T.Bronze
    size = size or 10
    local corners = {
        { UDim2.new(0, 0, 0, 0), UDim2.new(0, size, 0, 2) },
        { UDim2.new(1, -size, 0, 0), UDim2.new(0, size, 0, 2) },
        { UDim2.new(0, 0, 1, -2), UDim2.new(0, size, 0, 2) },
        { UDim2.new(1, -size, 1, -2), UDim2.new(0, size, 0, 2) },
        { UDim2.new(0, 0, 0, 0), UDim2.new(0, 2, 0, size) },
        { UDim2.new(1, -2, 0, 0), UDim2.new(0, 2, 0, size) },
        { UDim2.new(0, 0, 1, -size), UDim2.new(0, 2, 0, size) },
        { UDim2.new(1, -2, 1, -size), UDim2.new(0, 2, 0, size) },
    }
    for _, p in ipairs(corners) do
        local f = Instance.new("Frame")
        f.Name = "ChineseCorner"
        f.Position = p[1]
        f.Size = p[2]
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0
        f.ZIndex = 12
        f.Parent = parent
    end
end

local function cloudStripe(parent, color)
    color = color or T.Cyan
    local f = Instance.new("Frame")
    f.Name = "CloudStripe"
    f.Size = UDim2.new(1, -20, 0, 4)
    f.Position = UDim2.new(0, 10, 1, -12)
    f.BackgroundColor3 = color
    f.BackgroundTransparency = 0.7
    f.BorderSizePixel = 0
    f.ZIndex = 11
    f.Parent = parent
    local uig = Instance.new("UIGradient")
    uig.Rotation = 0
    uig.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 0.7)
    })
    uig.Color = ColorSequence.new(color)
    uig.Parent = f
end

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

local AntiKick = { kickBlocked = 0, disconnectBlocked = 0, hooksActive = false }
local _antiKickSetup = false
local _disconnectSetup = false

local function setupAntiKick()
    if _antiKickSetup then return end
    _antiKickSetup = true
    if type(getrawmetatable) ~= "function" or type(newcclosure) ~= "function" or type(setreadonly) ~= "function" then
        AntiKick.hooksActive = false
        return
    end
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
    if type(newcclosure) ~= "function" then return end
    pcall(function()
        local nc = game:GetService("NetworkClient")
        if nc then
            nc.Disconnect = newcclosure(function(self, ...)
                AntiKick.disconnectBlocked = AntiKick.disconnectBlocked + 1
            end)
        end
    end)
end

setupAntiKick()
setupDisconnectBlocker()

local function getCurrentStrength()
    local str = 0
    pcall(function()
        local a = LocalPlayer:GetAttribute("Strength")
        if a then str = a; return end
        if LocalPlayer.leaderstats then
            if LocalPlayer.leaderstats:FindFirstChild("Strength") then
                str = LocalPlayer.leaderstats.Strength.Value
                return
            end
            if LocalPlayer.leaderstats:FindFirstChild("Power") then
                str = LocalPlayer.leaderstats.Power.Value
                return
            end
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
            for _, n in ipairs({ "Rebirths", "Rebirth", "RebirthCount", "Prestige", "Reborn" }) do
                local v = LocalPlayer.leaderstats:FindFirstChild(n)
                if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                    c = v.Value
                    return
                end
            end
        end
    end)
    return c
end

local statSources = {}
for _, d in ipairs(STAT_DEFS) do
    statSources[d.key] = { src = nil, attr = nil }
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
                s.src = v
                return true
            end
        end
    end
    for _, n in ipairs(def.names) do
        local v = LocalPlayer:GetAttribute(n)
        if type(v) == "number" then
            s.attr = n
            return true
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

local function refreshAllStats()
    for _, d in ipairs(STAT_DEFS) do
        findStat(d.key)
    end
end

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
            if type(v) ~= "table" and type(v) ~= "function" then
                d[k] = v
            end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(d))
    end)
end

local function loadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    if not isfile(CONFIG_FILE) then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if Config[k] ~= nil and type(Config[k]) == type(v) then
                Config[k] = v
            end
        end
    end
end

loadConfig()

local function updateStatus() end
local function updateStartBtn() end
local function startAutoTrain() end
local function stopAutoTrain() end
local function restartTrain() end
local function startFly() end
local function stopFly() end
local function applyWalkSpeed() end
local function fireAntiAfk() end
local function startHidePets() end
local function stopHidePets() end
local function hookAllPlayers() end
local function clearAllESP() end

local parentGui
pcall(function()
    if type(gethui) == "function" then
        parentGui = gethui()
    end
end)
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

local connections = {}
local function safeConnect(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(connections, conn)
    return conn
end

local vp = workspace.CurrentCamera.ViewportSize
local PANEL_W = math.min(vp.X * 0.92, 380)
local PANEL_H = math.min(vp.Y * 0.85, 640)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
MainFrame.Position = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2)
MainFrame.BackgroundColor3 = T.BgDeep
MainFrame.BackgroundTransparency = 0.35
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 10
MainFrame.Active = true
MainFrame.Parent = ScreenGui

corner(MainFrame, 12)
stroke(MainFrame, T.Bronze, 2, 0.3)
huiwenBorder(MainFrame, T.Bronze, 2)
chineseCorners(MainFrame, T.BronzeLight, 14)
cloudStripe(MainFrame, T.Cyan)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Text = "力量之冠 · 雪花脚本"
TitleLabel.Font = T.FB
TitleLabel.TextSize = 18
TitleLabel.TextColor3 = T.TextGold
TitleLabel.TextStrokeTransparency = 0.7
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 14, 0, 8)
TitleLabel.Size = UDim2.new(1, -28, 0, 28)
TitleLabel.ZIndex = 13
TitleLabel.Parent = MainFrame

local SubTitle = Instance.new("TextLabel")
SubTitle.Name = "SubTitle"
SubTitle.Text = "东方玄脉 · 自动修行"
SubTitle.Font = T.FM
SubTitle.TextSize = 11
SubTitle.TextColor3 = T.TextCyan
SubTitle.BackgroundTransparency = 1
SubTitle.Position = UDim2.new(0, 14, 0, 36)
SubTitle.Size = UDim2.new(1, -28, 0, 18)
SubTitle.ZIndex = 13
SubTitle.Parent = MainFrame

local function makeChineseButton(name, text, parent, onClick)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Text = text
    btn.Font = T.FB
    btn.TextSize = 14
    btn.TextColor3 = T.Text
    btn.TextStrokeTransparency = 0.8
    btn.BackgroundColor3 = T.BgCard
    btn.BorderSizePixel = 0
    btn.AutoLocalize = false
    btn.ZIndex = 20
    btn.Parent = parent
    corner(btn, 6)
    stroke(btn, T.Bronze, 1, 0.4)
    huiwenBorder(btn, T.BronzeDeep, 1)
    chineseCorners(btn, T.BronzeLight, 8)
    local hover = TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
        BackgroundColor3 = T.BgCard2,
        TextColor3 = T.TextGold
    })
    btn.MouseEnter:Connect(function() hover:Play() end)
    btn.MouseLeave:Connect(function() hover:Cancel(); btn.BackgroundColor3 = T.BgCard; btn.TextColor3 = T.Text end)
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

local CloseBtn = makeChineseButton("CloseBtn", "关", MainFrame, function()
    MainFrame.Visible = not MainFrame.Visible
end)
CloseBtn.Size = UDim2.new(0, 34, 0, 26)
CloseBtn.Position = UDim2.new(1, -42, 0, 10)

local StatsFrame = Instance.new("Frame")
StatsFrame.Name = "StatsFrame"
StatsFrame.BackgroundColor3 = T.BgCard
StatsFrame.BackgroundTransparency = 0.4
StatsFrame.BorderSizePixel = 0
StatsFrame.Position = UDim2.new(0, 12, 0, 62)
StatsFrame.Size = UDim2.new(1, -24, 0, 72)
StatsFrame.ZIndex = 12
StatsFrame.Parent = MainFrame

corner(StatsFrame, 8)
stroke(StatsFrame, T.CyanDeep, 1, 0.5)
chineseCorners(StatsFrame, T.Cyan, 8)

local statLabels = {}
for i, def in ipairs(STAT_DEFS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local card = Instance.new("Frame")
    card.Name = def.key .. "StatCard"
    card.BackgroundColor3 = T.BgCard2
    card.BackgroundTransparency = 0.5
    card.BorderSizePixel = 0
    card.Position = UDim2.new(0, 10 + col * 165, 0, 8 + row * 28)
    card.Size = UDim2.new(0, 155, 0, 22)
    card.ZIndex = 13
    card.Parent = StatsFrame
    corner(card, 5)
    stroke(card, def.color, 1, 0.5)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Text = def.label
    nameLabel.Font = T.FM
    nameLabel.TextSize = 11
    nameLabel.TextColor3 = def.color
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0, 6, 0, 0)
    nameLabel.Size = UDim2.new(0, 40, 1, 0)
    nameLabel.ZIndex = 14
    nameLabel.Parent = card
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Text = "0"
    valueLabel.Font = T.FB
    valueLabel.TextSize = 12
    valueLabel.TextColor3 = T.Text
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(0, 46, 0, 0)
    valueLabel.Size = UDim2.new(1, -52, 1, 0)
    valueLabel.ZIndex = 14
    valueLabel.Parent = card
    statLabels[def.key] = valueLabel
end

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Name = "ScrollingFrame"
ScrollingFrame.BackgroundColor3 = T.BgCard
ScrollingFrame.BackgroundTransparency = 0.5
ScrollingFrame.BorderSizePixel = 0
ScrollingFrame.Position = UDim2.new(0, 12, 0, 144)
ScrollingFrame.Size = UDim2.new(1, -24, 1, -160)
ScrollingFrame.ScrollBarThickness = 4
ScrollingFrame.ScrollBarColor3 = T.Bronze
ScrollingFrame.ScrollBarTransparency = 0.5
ScrollingFrame.ZIndex = 12
ScrollingFrame.Parent = MainFrame

corner(ScrollingFrame, 8)
stroke(ScrollingFrame, T.BronzeDeep, 1, 0.5)

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.FillDirection = Enum.FillDirection.Vertical
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.VerticalAlignment = Enum.VerticalAlignment.Top
Layout.Parent = ScrollingFrame

local function addSectionTitle(text)
    local label = Instance.new("TextLabel")
    label.Name = "SectionTitle"
    label.Text = "◆ " .. text .. " ◆"
    label.Font = T.FB
    label.TextSize = 13
    label.TextColor3 = T.TextGold
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -16, 0, 22)
    label.ZIndex = 13
    label.Parent = ScrollingFrame
end

local function makeSwitch(frame, title, key, callback)
    local card = Instance.new("Frame")
    card.Name = key .. "Card"
    card.BackgroundColor3 = T.BgCard
    card.BackgroundTransparency = 0.3
    card.BorderSizePixel = 0
    card.ZIndex = 18
    card.Parent = frame
    corner(card, 8)
    stroke(card, T.Bronze, 1, 0.4)
    chineseCorners(card, T.BronzeDeep, 8)
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Text = title
    titleLabel.Font = T.FM
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = T.Text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Size = UDim2.new(1, -72, 1, 0)
    titleLabel.ZIndex = 19
    titleLabel.Parent = card
    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.Text = Config[key] and "启" or "闭"
    toggle.Font = T.FB
    toggle.TextSize = 12
    toggle.TextColor3 = Config[key] and T.Jade or T.TextDim
    toggle.BackgroundColor3 = Config[key] and T.JadeDeep or T.BgDeep
    toggle.BorderSizePixel = 0
    toggle.Size = UDim2.new(0, 36, 0, 22)
    toggle.Position = UDim2.new(1, -44, 0.5, -11)
    toggle.ZIndex = 20
    toggle.Parent = card
    corner(toggle, 6)
    stroke(toggle, Config[key] and T.Jade or T.BronzeDeep, 1, 0)
    local function update()
        if Config[key] then
            toggle.Text = "启"
            toggle.TextColor3 = T.Jade
            toggle.BackgroundColor3 = T.JadeDeep
        else
            toggle.Text = "闭"
            toggle.TextColor3 = T.TextDim
            toggle.BackgroundColor3 = T.BgDeep
        end
    end
    toggle.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        update()
        saveConfig()
        if callback then task.spawn(callback, Config[key]) end
    end)
    return card, update
end

addSectionTitle("核心修行")
local card1, updateUseAll = makeSwitch(ScrollingFrame, "廿一秘法 · 全 Action", "UseAllActions", function(on)
    if on then
        if not isTraining then
            startAutoTrain()
        else
            restartTrain()
        end
        updateStartBtn()
        updateStatus()
    else
        if isTraining then
            restartTrain()
        end
        updateStartBtn()
        updateStatus()
    end
end)
local card2, updateFastMode = makeSwitch(ScrollingFrame, "极速模式", "FastMode", function()
    if isTraining then restartTrain() end
end)
local card3, updateAutoRebirth = makeSwitch(ScrollingFrame, "自动重生", "AutoRebirth", function(on)
    if on then
        local rebirths = getCurrentRebirths()
        if Config.StopAtTargetRebirth and Config.TargetRebirthCount > 0 and rebirths >= Config.TargetRebirthCount then
            Config.AutoRebirth = false
            updateAutoRebirth()
            saveConfig()
        end
    end
end)
local card4, updateAntiAfk = makeSwitch(ScrollingFrame, "反挂机", "AntiAfk", function(on)
    if on then
        if not antiAfkConn then
            antiAfkConn = safeConnect(LocalPlayer.Idled, fireAntiAfk)
        end
    else
        if antiAfkConn then
            antiAfkConn:Disconnect()
            antiAfkConn = nil
        end
    end
end)

addSectionTitle("飞行与移动")
local card5, updateFly = makeSwitch(ScrollingFrame, "御风飞行", "Fly", function(on)
    if on then startFly() else stopFly() end
end)
local card6, updateInfiniteJump = makeSwitch(ScrollingFrame, "无量跳跃", "InfiniteJump", function(on)
    if on then
        if not infiniteJumpConn then
            infiniteJumpConn = safeConnect(UserInputService.JumpRequest, function()
                if Config.InfiniteJump then
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                end
            end)
        end
    else
        if infiniteJumpConn then
            infiniteJumpConn:Disconnect()
            infiniteJumpConn = nil
        end
    end
end)

addSectionTitle("视觉与防护")
local card8, updateESP = makeSwitch(ScrollingFrame, "透视显示", "ESP", function(on)
    if on then hookAllPlayers() else clearAllESP() end
end)
local card9, updateFullbright = makeSwitch(ScrollingFrame, "纯阳照明", "Fullbright", function(on)
    if on then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.new(1,1,1)
    else
        Lighting.Brightness = 1
        Lighting.Ambient = Color3.new(0.5,0.5,0.5)
    end
end)
local card10, updateNoFog = makeSwitch(ScrollingFrame, "云雾消散", "NoFog", function(on)
    if on then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = _origFog.End
        Lighting.FogStart = _origFog.Start
    end
end)
local card11, updateHidePets = makeSwitch(ScrollingFrame, "隐宠匿形", "HidePets", function(on)
    if on then startHidePets() else stopHidePets() end
end)

addSectionTitle("辅助功能")
makeSwitch(ScrollingFrame, "玄龟护体", "AntiKick", function() end)
makeSwitch(ScrollingFrame, "续命长生", "KeepAlive", function() end)
makeSwitch(ScrollingFrame, "隔绝断连", "BlockDisconnect", function() end)

local StartBtn = Instance.new("TextButton")
StartBtn.Name = "StartBtn"
StartBtn.Text = "开始修行"
StartBtn.Font = T.FB
StartBtn.TextSize = 15
StartBtn.TextColor3 = T.Jade
StartBtn.BackgroundColor3 = T.JadeDeep
StartBtn.BorderSizePixel = 0
StartBtn.Size = UDim2.new(1, -24, 0, 40)
StartBtn.Position = UDim2.new(0, 12, 1, -140)
StartBtn.ZIndex = 14
StartBtn.Parent = MainFrame

corner(StartBtn, 8)
stroke(StartBtn, T.Jade, 2, 0)
huiwenBorder(StartBtn, T.Jade, 1)
chineseCorners(StartBtn, T.Jade, 10)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Text = "待机"
StatusLabel.Font = T.FM
StatusLabel.TextSize = 12
StatusLabel.TextColor3 = T.TextDim
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 12, 1, -100)
StatusLabel.Size = UDim2.new(1, -24, 0, 20)
StatusLabel.ZIndex = 13
StatusLabel.Parent = MainFrame

local SessionLabel = Instance.new("TextLabel")
SessionLabel.Name = "SessionLabel"
SessionLabel.Text = "本层: 0 次 | 力量: 0"
SessionLabel.Font = T.FM
SessionLabel.TextSize = 11
SessionLabel.TextColor3 = T.TextCyan
SessionLabel.BackgroundTransparency = 1
SessionLabel.Position = UDim2.new(0, 12, 1, -80)
SessionLabel.Size = UDim2.new(1, -24, 0, 20)
SessionLabel.ZIndex = 13
SessionLabel.Parent = MainFrame

local JoyFrame = Instance.new("Frame")
JoyFrame.Name = "JoyFrame"
JoyFrame.Size = UDim2.new(0, 130, 0, 130)
JoyFrame.Position = UDim2.new(0, 20, 1, -160)
JoyFrame.BackgroundColor3 = T.BgCard
JoyFrame.BackgroundTransparency = 0.4
JoyFrame.BorderSizePixel = 0
JoyFrame.Visible = false
JoyFrame.ZIndex = 50
JoyFrame.Parent = ScreenGui

corner(JoyFrame, 65)
stroke(JoyFrame, T.Bronze, 2, 0.3)
huiwenBorder(JoyFrame, T.Bronze, 1)
chineseCorners(JoyFrame, T.BronzeLight, 12)

local JoyKnob = Instance.new("Frame")
JoyKnob.Name = "JoyKnob"
JoyKnob.Size = UDim2.new(0, 54, 0, 54)
JoyKnob.Position = UDim2.new(0.5, -27, 0.5, -27)
JoyKnob.BackgroundColor3 = T.Bronze
JoyKnob.BackgroundTransparency = 0.2
JoyKnob.BorderSizePixel = 0
JoyKnob.ZIndex = 53
JoyKnob.Parent = JoyFrame

corner(JoyKnob, 27)
stroke(JoyKnob, T.BronzeLight, 2, 0)

local UpBtn = Instance.new("TextButton")
UpBtn.Name = "UpBtn"
UpBtn.Text = "升"
UpBtn.Font = T.FB
UpBtn.TextSize = 14
UpBtn.TextColor3 = T.Jade
UpBtn.BackgroundColor3 = T.BgCard
UpBtn.BorderSizePixel = 0
UpBtn.Size = UDim2.new(0, 50, 0, 50)
UpBtn.Position = UDim2.new(1, -72, 0.5, -110)
UpBtn.ZIndex = 52
UpBtn.Parent = ScreenGui

corner(UpBtn, 10)
stroke(UpBtn, T.Jade, 1, 0.4)
chineseCorners(UpBtn, T.Jade, 8)

local DownBtn = Instance.new("TextButton")
DownBtn.Name = "DownBtn"
DownBtn.Text = "降"
DownBtn.Font = T.FB
DownBtn.TextSize = 14
DownBtn.TextColor3 = T.Red
DownBtn.BackgroundColor3 = T.BgCard
DownBtn.BorderSizePixel = 0
DownBtn.Size = UDim2.new(0, 50, 0, 50)
DownBtn.Position = UDim2.new(1, -72, 0.5, 60)
DownBtn.ZIndex = 52
DownBtn.Parent = ScreenGui

corner(DownBtn, 10)
stroke(DownBtn, T.Red, 1, 0.4)
chineseCorners(DownBtn, T.Red, 8)

local BallBtn = Instance.new("TextButton")
BallBtn.Name = "BallBtn"
BallBtn.Text = "玄"
BallBtn.Font = T.FB
BallBtn.TextSize = 16
BallBtn.TextColor3 = T.TextGold
BallBtn.BackgroundColor3 = T.BgCard
BallBtn.BorderSizePixel = 0
BallBtn.Size = UDim2.new(0, 56, 0, 56)
BallBtn.Position = UDim2.new(1, -80, 1, -80)
BallBtn.ZIndex = 14
BallBtn.Parent = ScreenGui

corner(BallBtn, 28)
stroke(BallBtn, T.Bronze, 2, 0.3)
huiwenBorder(BallBtn, T.Bronze, 1)
chineseCorners(BallBtn, T.BronzeLight, 10)

local BallRing = Instance.new("Frame")
BallRing.Name = "BallRing"
BallRing.BackgroundColor3 = T.Bronze
BallRing.BackgroundTransparency = 0.8
BallRing.BorderSizePixel = 0
BallRing.Size = UDim2.new(0, 76, 0, 76)
BallRing.Position = BallBtn.Position - UDim2.new(0, 10, 0, 10)
BallRing.ZIndex = 13
BallRing.Parent = ScreenGui

corner(BallRing, 38)
stroke(BallRing, T.BronzeLight, 1, 0.5)

local ballRingTween = nil
task.spawn(function()
    while ScreenGui.Parent do
        if BallBtn.Visible then
            if ballRingTween then ballRingTween:Cancel() end
            ballRingTween = TweenService:Create(BallRing, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                Size = UDim2.new(0, 86, 0, 86),
                Position = BallBtn.Position - UDim2.new(0, 15, 0, 15)
            })
            ballRingTween:Play()
            task.wait(1)
            if ballRingTween then ballRingTween:Cancel() end
            BallRing.Size = UDim2.new(0, 76, 0, 76)
            BallRing.Position = BallBtn.Position - UDim2.new(0, 10, 0, 10)
        end
        task.wait(1.2)
    end
end)

BallBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

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
    JoyKnob.Position = UDim2.new(0.5, dx-27, 0.5, dy-27)
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType.MouseButton1 then
        if joyActive then joyActive = false; joyValue = Vector2.new(0,0); JoyKnob.Position = UDim2.new(0.5,-27,0.5,-27) end
    end
end)
UpBtn.MouseButton1Down:Connect(function() flyUp = true end)
UpBtn.MouseButton1Up:Connect(function() flyUp = false end)
UpBtn.MouseLeave:Connect(function() flyUp = false end)
DownBtn.MouseButton1Down:Connect(function() flyDown = true end)
DownBtn.MouseButton1Up:Connect(function() flyDown = false end)
DownBtn.MouseLeave:Connect(function() flyDown = false end)

StartBtn.MouseButton1Click:Connect(function()
    if isTraining then stopAutoTrain() else startAutoTrain() end
end)

-- 业务逻辑实现
function updateStatus()
    if isTraining then
        StatusLabel.Text = "修行中..."
        StatusLabel.TextColor3 = T.Jade
    else
        StatusLabel.Text = "待机"
        StatusLabel.TextColor3 = T.TextDim
    end
end

function updateStartBtn()
    if isTraining then
        StartBtn.Text = "停止修行"
        StartBtn.TextColor3 = T.Red
        StartBtn.BackgroundColor3 = T.RedDeep
    else
        StartBtn.Text = "开始修行"
        StartBtn.TextColor3 = T.Jade
        StartBtn.BackgroundColor3 = T.JadeDeep
    end
end

function startAutoTrain()
    if isTraining then return end
    isTraining = true
    trainCount = 0
    sessionStartStrength = getCurrentStrength()
    trainThread = task.spawn(function()
        while isTraining do
            if not TrainEvent then task.wait(1) continue end
            local action = Config.Action
            if Config.UseAllActions then
                action = ALL_ACTIONS[(trainCount % #ALL_ACTIONS) + 1]
            end
            pcall(function() TrainEvent:FireServer(action) end)
            trainCount = trainCount + 1
            local interval = Config.FastMode and 0.05 or Config.Interval
            task.wait(interval)
        end
    end)
    updateStartBtn()
    updateStatus()
end

function stopAutoTrain()
    isTraining = false
    if trainThread then task.cancel(trainThread) trainThread = nil end
    updateStartBtn()
    updateStatus()
end

function restartTrain()
    if isTraining then
        stopAutoTrain()
        task.wait(0.1)
        startAutoTrain()
    end
end

local function tryRebirth()
    if pendingRebirth then return end
    if not RebirthEvent then return end
    local rebirths = getCurrentRebirths()
    if Config.StopAtTargetRebirth and Config.TargetRebirthCount > 0 and rebirths >= Config.TargetRebirthCount then
        Config.AutoRebirth = false
        saveConfig()
        return
    end
    pendingRebirth = true
    pendingRebirthStart = tick()
    pendingRebirthLastValue = rebirths
    pcall(function() RebirthEvent:FireServer("Start") end)
    task.wait(0.5)
    pcall(function() RebirthEvent:FireServer("Update") end)
end

local function checkRebirth()
    if not pendingRebirth then return end
    local now = tick()
    local rebirths = getCurrentRebirths()
    if rebirths > pendingRebirthLastValue then
        pendingRebirth = false
        Config.AutoRebirthDone = Config.AutoRebirthDone + 1
        saveConfig()
        return
    end
    if now - pendingRebirthStart > REBIRTH_TIMEOUT then
        pendingRebirth = false
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        if Config.AutoRebirth then
            checkRebirth()
            if not pendingRebirth then tryRebirth() end
        end
    end
end)

function startFly()
    if flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
    flyBG.P = 3000
    flyBG.D = 500
    flyBG.Parent = hrp
    flying = true
    JoyFrame.Visible = true
    UpBtn.Visible = true
    DownBtn.Visible = true
end

function stopFly()
    if not flying then return end
    flying = false
    joyValue = Vector2.new(0,0)
    flyUp = false
    flyDown = false
    JoyKnob.Position = UDim2.new(0.5,-27,0.5,-27)
    JoyFrame.Visible = false
    UpBtn.Visible = false
    DownBtn.Visible = false
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
        JoyFrame.Visible = false
        UpBtn.Visible = false
        DownBtn.Visible = false
        if Config.Fly then startFly() end
    end
end)

function applyWalkSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Config.WalkSpeed or 16
        hum.JumpPower = Config.JumpPower
        hum.UseJumpPower = true
    end
end

RunService.Heartbeat:Connect(function()
    if not Config.NoFallDamage then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health>0 then
        pcall(function()
            hum.FallDamagePerFoot = 0
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false)
        end)
    end
end)

function fireAntiAfk()
    if not Config.AntiAfk then return end
    pcall(function()
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space,true,false,game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(Enum.KeyCode.Space,false,false,game)
    end)
end

local function startHidePets()
    for _,v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("Model") or v:IsA("Folder")) and v~=LocalPlayer.Character then
            for _,part in ipairs(v:GetDescendants()) do
                if part:IsA("BasePart") then part.LocalTransparencyModifier=1 end
            end
        end
    end
end

local function stopHidePets()
    for _,v in ipairs(workspace:GetDescendants()) do
        if (v:IsA("Model") or v:IsA("Folder")) then
            for _,part in ipairs(v:GetDescendants()) do
                if part:IsA("BasePart") then part.LocalTransparencyModifier=0 end
            end
        end
    end
end

espCache = {}
local function clearESPFor(p)
    if espCache[p] then
        if espCache[p].hl then espCache[p].hl:Destroy() end
        espCache[p]=nil
    end
end

local function clearAllESP()
    for p,_ in pairs(espCache) do clearESPFor(p) end
end

local function updateESP()
    if not Config.ESP then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            if not espCache[p] then
                local hl=Instance.new("Highlight")
                hl.FillColor=T.Cyan
                hl.OutlineColor=T.Bronze
                hl.FillTransparency=0.5
                hl.OutlineTransparency=0
                hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent=p.Character
                espCache[p]={hl=hl}
            end
        end
    end
end

local function hookPlayerChar(p)
    if p==LocalPlayer then return end
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        if Config.ESP then clearESPFor(p); updateESP() end
    end)
end

function hookAllPlayers()
    for _,p in ipairs(Players:GetPlayers()) do hookPlayerChar(p) end
    Players.PlayerAdded:Connect(hookPlayerChar)
    updateESP()
end

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.2)
        refreshAllStats()
        for _,def in ipairs(STAT_DEFS) do
            local v=getStat(def.key)
            if statLabels[def.key] then statLabels[def.key].Text=fmtShort(v) end
        end
        if isTraining and sessionStartStrength then
            local now=getCurrentStrength()
            SessionLabel.Text=string.format("本层: %d 次 | 力量: %s",trainCount,fmtShort(now-sessionStartStrength))
        end
    end
end)

ScreenGui.Destroying:Connect(function()
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    if infiniteJumpConn then pcall(function() infiniteJumpConn:Disconnect() end); infiniteJumpConn=nil end
    if antiAfkConn then pcall(function() antiAfkConn:Disconnect() end); antiAfkConn=nil end
    if ballRingTween then pcall(function() ballRingTween:Cancel() end) end
    stopAutoTrain()
    stopFly()
    clearAllESP()
end)

updateStartBtn()
updateStatus()
applyWalkSpeed()
if Config.Fly then task.defer(startFly) end
if Config.UseAllActions and TrainEvent then task.defer(startAutoTrain) end
