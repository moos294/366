local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting   = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui", 10)

local UIParent = PlayerGui
pcall(function()
    if gethui then UIParent = gethui() end
end)

local SafeInset = 60

local Config = {
    Action = "PushUp", Interval = 0.1,
    AutoRebirth = false, AntiAfk = true,
    Fly = false, FlySpeed = 50,
    WalkSpeed = 16, JumpPower = 50,
    FastMode = false, UseAllActions = false,
    TargetRebirthCount = 5, StopAtTargetRebirth = false,
    InfiniteJump = false, Fullbright = false, NoFog = false,
    NoFallDamage = false,
}

local ALL_ACTIONS = {
    "PushUp","Dumbbell","ShoulderPress_1","TrendMill_1","FlatBench_1",
    "Rock_1","Rock_2","Rock_3","BarbellRack_L1","BenchPress_L1",
    "Red slime","FlatBench_L1","BarbellRack_S1","BarbellRack_1",
    "BarbellRack_2","BenchPress_1","BenchPress_2","ShoulderPress_2",
    "ShoulderPress_3","SkySlime","FlatBench_K1"
}

local STAT_DEFS = {
    {key="Strength",label="力量",color=Color3.fromRGB(212,175,55),
        names={"Strength","Power","Str","StrengthValue","力量","TotalStrength","CrownStrength"}},
    {key="Rebirth",label="重生",color=Color3.fromRGB(220,60,60),
        names={"Rebirth","Rebirths","RebirthCount","RebirthLevel","重生","RebirthValue"}},
    {key="Gems",label="宝石",color=Color3.fromRGB(90,190,160),
        names={"Gems","Gem","GemCount","Diamonds","Crystal","宝石","Diamond"}},
    {key="Agility",label="敏捷",color=Color3.fromRGB(80,200,220),
        names={"Agility","Speed","Agil","AgilityValue","敏捷","SpeedValue"}},
}

local REBIRTH_TIMEOUT = 15

local T = {
    BgDeep   = Color3.fromRGB(5,8,10),
    BgCard   = Color3.fromRGB(14,22,28),
    BgCard2  = Color3.fromRGB(20,32,40),
    Bronze   = Color3.fromRGB(175,145,90),
    BronzeDeep = Color3.fromRGB(110,90,55),
    BronzeLight= Color3.fromRGB(220,190,130),
    CyanDeep = Color3.fromRGB(40,120,140),
    Jade     = Color3.fromRGB(96,180,150),
    JadeDeep = Color3.fromRGB(56,120,100),
    Red      = Color3.fromRGB(210,70,70),
    RedDeep  = Color3.fromRGB(150,40,40),
    Text     = Color3.fromRGB(230,235,238),
    TextDim  = Color3.fromRGB(140,160,170),
    TextGold = Color3.fromRGB(215,185,130),
    TextCyan = Color3.fromRGB(160,220,230),
    FB = Enum.Font.GothamBold,
    FM = Enum.Font.GothamMedium,
    FN = Enum.Font.Code,
}

local function corner(p,r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p; return c
end

local function stroke(p,c,t,tr)
    local s=Instance.new("UIStroke"); s.Color=c or T.Bronze; s.Thickness=t or 1
    s.Transparency=tr or 0.4; s.Parent=p; return s
end

local function fmt(n)
    n=tonumber(n)or 0
    if n>=1e12 then return string.format("%.2fT",n/1e12)end
    if n>=1e9  then return string.format("%.2fB",n/1e9) end
    if n>=1e6  then return string.format("%.2fM",n/1e6) end
    if n>=1e3  then return string.format("%.1fK",n/1e3) end
    return tostring(math.floor(n))
end

local isTraining = false
local trainCount = 0
local sessionStart = nil
local flying = false
local flyBV, flyBG = nil, nil
local flyUp, flyDown = false, false
local joyValue = Vector2.new(0,0)
local joyActive = false
local pendingRebirth = false
local pendingRebirthStart = 0
local pendingRebirthLast = 0
local infiniteJumpConn = nil
local antiAfkConn = nil
local _origFogEnd = Lighting.FogEnd
local _origFogStart = Lighting.FogStart
local _origBrightness = Lighting.Brightness
local _origAmbient = Lighting.Ambient

local function getStrength()
    local str = 0
    local a = LocalPlayer:GetAttribute("Strength")
    if a then str = a end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local v = ls:FindFirstChild("Strength") or ls:FindFirstChild("Power")
        if v then str = v.Value end
    end
    return str
end

local function getRebirths()
    local c = 0
    local a = LocalPlayer:GetAttribute("Rebirths")
        or LocalPlayer:GetAttribute("Rebirth")
        or LocalPlayer:GetAttribute("RebirthCount")
    if a then c = a end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _,n in ipairs({"Rebirths","Rebirth","RebirthCount","Prestige","Reborn"}) do
            local v = ls:FindFirstChild(n)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                c = v.Value; break
            end
        end
    end
    return c
end

local statSrc = {}
for _,d in ipairs(STAT_DEFS) do statSrc[d.key] = {src=nil, attr=nil} end

local function findStat(key)
    local s = statSrc[key]
    if s.src and s.src.Parent then return true end
    s.src, s.attr = nil, nil
    local def
    for _,d in ipairs(STAT_DEFS) do if d.key==key then def=d break end end
    if not def then return false end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _,n in ipairs(def.names) do
            local v = ls:FindFirstChild(n)
            if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                s.src = v; return true
            end
        end
    end
    for _,n in ipairs(def.names) do
        local v = LocalPlayer:GetAttribute(n)
        if type(v)=="number" then s.attr = n; return true end
    end
    return false
end

local function getStat(key)
    local s = statSrc[key]
    if s.src and s.src.Parent then return tonumber(s.src.Value) or 0 end
    if s.attr then return tonumber(LocalPlayer:GetAttribute(s.attr)) or 0 end
    return 0
end

local function refreshStats()
    for _,d in ipairs(STAT_DEFS) do findStat(d.key) end
end

local function findRemote(name, alt)
    local r = RS:FindFirstChild(name) or (alt and RS:FindFirstChild(alt))
    if r then return r end
    local remotes = RS:FindFirstChild("Remotes")
    if remotes then
        r = remotes:FindFirstChild(name) or (alt and remotes:FindFirstChild(alt))
        if r then return r end
    end
    return nil
end

local TrainEvent   = findRemote("TrainEvent","Train")
local RebirthEvent = findRemote("RebirthEvent","Rebirth")

local old = UIParent:FindFirstChild("CrownMobileUI")
if old then old:Destroy() end
if PlayerGui ~= UIParent then
    local old2 = PlayerGui:FindFirstChild("CrownMobileUI")
    if old2 then old2:Destroy() end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CrownMobileUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = UIParent

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
local PW = math.min(vp.X*0.92, 380)
local PH = math.min(vp.Y*0.85, 640)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainPanel"
MainFrame.Size = UDim2.new(0,PW,0,PH)
MainFrame.Position = UDim2.new(0.5,-PW/2,0.5,-PH/2 + 10)
MainFrame.BackgroundColor3 = T.BgDeep
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 100
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
corner(MainFrame,12); stroke(MainFrame,T.Bronze,2,0.3)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1,-28,0,28)
TitleLabel.Position = UDim2.new(0,14,0,8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "力量之冠 · 雪花脚本"
TitleLabel.Font = T.FB; TitleLabel.TextSize = 18
TitleLabel.TextColor3 = T.TextGold; TitleLabel.ZIndex = 103
TitleLabel.Parent = MainFrame

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(1,-28,0,18)
SubTitle.Position = UDim2.new(0,14,0,36)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "忍者注入器专用版"
SubTitle.Font = T.FM; SubTitle.TextSize = 11
SubTitle.TextColor3 = T.TextCyan; SubTitle.ZIndex = 103
SubTitle.Parent = MainFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,34,0,26)
CloseBtn.Position = UDim2.new(1,-42,0,10)
CloseBtn.BackgroundColor3 = T.BgCard
CloseBtn.Text = "关"; CloseBtn.Font = T.FB; CloseBtn.TextSize = 14
CloseBtn.TextColor3 = T.TextGold; CloseBtn.BorderSizePixel = 0
CloseBtn.ZIndex = 110; CloseBtn.Parent = MainFrame
corner(CloseBtn,8); stroke(CloseBtn,T.Bronze,1,0.4)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(1,-24,0,72)
StatsFrame.Position = UDim2.new(0,12,0,62)
StatsFrame.BackgroundColor3 = T.BgCard
StatsFrame.BorderSizePixel = 0; StatsFrame.ZIndex = 102
StatsFrame.Parent = MainFrame
corner(StatsFrame,8); stroke(StatsFrame,T.CyanDeep,1,0.5)

local statLabels = {}
for i,def in ipairs(STAT_DEFS) do
    local col = (i-1)%2
    local row = math.floor((i-1)/2)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0,155,0,22)
    card.Position = UDim2.new(0,10+col*165,0,8+row*28)
    card.BackgroundColor3 = T.BgCard2
    card.BorderSizePixel = 0; card.ZIndex = 103
    card.Parent = StatsFrame
    corner(card,5); stroke(card,def.color,1,0.5)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0,40,1,0)
    nameLabel.Position = UDim2.new(0,6,0,0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = def.label
    nameLabel.Font = T.FM; nameLabel.TextSize = 11
    nameLabel.TextColor3 = def.color; nameLabel.ZIndex = 104
    nameLabel.Parent = card

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(1,-52,1,0)
    valLabel.Position = UDim2.new(0,46,0,0)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = "0"
    valLabel.Font = T.FB; valLabel.TextSize = 12
    valLabel.TextColor3 = T.Text
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.ZIndex = 104
    valLabel.Parent = card
    statLabels[def.key] = valLabel
end

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1,-24,1,-160)
Scroll.Position = UDim2.new(0,12,0,144)
Scroll.BackgroundColor3 = T.BgCard
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarColor3 = T.Bronze
Scroll.ScrollBarTransparency = 0.5
Scroll.ZIndex = 102
Scroll.Parent = MainFrame
corner(Scroll,8); stroke(Scroll,T.BronzeDeep,1,0.5)

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0,8)
Layout.FillDirection = Enum.FillDirection.Vertical
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.Parent = Scroll

local function section(text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-16,0,22)
    l.BackgroundTransparency = 1
    l.Text = "◆ "..text.." ◆"
    l.Font = T.FB; l.TextSize = 13
    l.TextColor3 = T.TextGold; l.ZIndex = 103
    l.Parent = Scroll
end

local function makeSwitch(title, key, cb)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,0,0,44)
    card.BackgroundColor3 = T.BgCard
    card.BorderSizePixel = 0; card.ZIndex = 108
    card.Parent = Scroll
    corner(card,8); stroke(card,T.Bronze,1,0.4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-72,1,0)
    lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = T.FM; lbl.TextSize = 13
    lbl.TextColor3 = T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 109; lbl.Parent = card

    local tg = Instance.new("TextButton")
    tg.Size = UDim2.new(0,36,0,22)
    tg.Position = UDim2.new(1,-44,0.5,-11)
    tg.BackgroundColor3 = Config[key] and T.JadeDeep or T.BgDeep
    tg.Text = Config[key] and "启" or "闭"
    tg.Font = T.FB; tg.TextSize = 12
    tg.TextColor3 = Config[key] and T.Jade or T.TextDim
    tg.BorderSizePixel = 0; tg.ZIndex = 110
    tg.Parent = card
    corner(tg,6); stroke(tg, Config[key] and T.Jade or T.BronzeDeep,1,0)

    tg.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        tg.Text = Config[key] and "启" or "闭"
        tg.TextColor3 = Config[key] and T.Jade or T.TextDim
        tg.BackgroundColor3 = Config[key] and T.JadeDeep or T.BgDeep
        tg.UIStroke.Color = Config[key] and T.Jade or T.BronzeDeep
        if cb then task.spawn(cb, Config[key]) end
    end)
end

local function makeNumber(title, key, min, max)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,44)
    row.BackgroundColor3 = T.BgCard
    row.BorderSizePixel = 0; row.ZIndex = 108
    row.Parent = Scroll
    corner(row,8); stroke(row,T.Bronze,1,0.4)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5,-12,1,0)
    lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = T.FM; lbl.TextSize = 13
    lbl.TextColor3 = T.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 109; lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5,-12,0,32)
    box.Position = UDim2.new(0.5,0,0,6)
    box.BackgroundColor3 = T.BgDeep
    box.Text = tostring(Config[key])
    box.Font = T.FN; box.TextSize = 13
    box.TextColor3 = T.TextGold
    box.ClearTextOnFocus = false
    box.BorderSizePixel = 0; box.ZIndex = 110
    box.Parent = row
    corner(box,6); stroke(box,T.BronzeDeep,1,0.4)

    box.FocusLost:Connect(function()
        local v = tonumber(box.Text)
        if v and v>=min and v<=max then Config[key] = v end
        box.Text = tostring(Config[key])
    end)
end

local StartBtn
local StatusLabel
local SessionLabel
local FpsLabel
local JoyFrame
local JoyKnob
local UpBtn
local DownBtn

local function updateStatus()
    if not StatusLabel then return end
    if isTraining then
        StatusLabel.Text = "修行中..."
        StatusLabel.TextColor3 = T.Jade
    else
        StatusLabel.Text = "待机"
        StatusLabel.TextColor3 = T.TextDim
    end
end

local function updateStartBtn()
    if not StartBtn then return end
    if isTraining then
        StartBtn.Text = "停止修行"
        StartBtn.TextColor3 = T.Red
        StartBtn.BackgroundColor3 = T.RedDeep
        StartBtn.UIStroke.Color = T.Red
    else
        StartBtn.Text = "开始修行"
        StartBtn.TextColor3 = T.Jade
        StartBtn.BackgroundColor3 = T.JadeDeep
        StartBtn.UIStroke.Color = T.Jade
    end
end

local function applyMoveStats()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Config.WalkSpeed or 16
        hum.JumpPower = Config.JumpPower or 50
        hum.UseJumpPower = true
    end
end

local function startTrain()
    if isTraining then return end
    isTraining = true
    trainCount = 0
    sessionStart = getStrength()

    task.spawn(function()
        while isTraining do
            if TrainEvent then
                local action = Config.Action
                if Config.UseAllActions then
                    action = ALL_ACTIONS[(trainCount % #ALL_ACTIONS) + 1]
                end
                pcall(function() TrainEvent:FireServer(action) end)
                trainCount = trainCount + 1
            end
            task.wait(Config.FastMode and 0.05 or Config.Interval)
        end
    end)

    updateStartBtn(); updateStatus()
end

local function stopTrain()
    isTraining = false
    updateStartBtn(); updateStatus()
end

local function restartTrain()
    if not isTraining then return end
    stopTrain()
    task.wait(0.1)
    startTrain()
end

section("核心修行")
makeSwitch("廿一秘法 · 全 Action", "UseAllActions", function(on)
    if on then
        if not isTraining then startTrain() else restartTrain() end
    else
        if isTraining then restartTrain() end
    end
    updateStartBtn(); updateStatus()
end)
makeSwitch("极速模式", "FastMode", function()
    if isTraining then restartTrain() end
end)
makeSwitch("自动重生", "AutoRebirth", function() end)
makeSwitch("反挂机", "AntiAfk", function(on)
    if on then
        if not antiAfkConn then
            antiAfkConn = LocalPlayer.Idled:Connect(function()
                if not Config.AntiAfk then return end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    else
        if antiAfkConn then antiAfkConn:Disconnect(); antiAfkConn = nil end
    end
end)

section("轮回重生")
makeNumber("目标重生数", "TargetRebirthCount", 0, 99999)
makeSwitch("到达目标停止", "StopAtTargetRebirth", function() end)

section("飞行与移动")
makeSwitch("御风飞行", "Fly", function(on)
    if on then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp and not flying then
                if hum then hum.PlatformStand = true end
                flyBV = Instance.new("BodyVelocity")
                flyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
                flyBV.Velocity = Vector3.zero
                flyBV.Parent = hrp
                flyBG = Instance.new("BodyGyro")
                flyBG.MaxTorque = Vector3.new(1e5,1e5,1e5)
                flyBG.P = 3000; flyBG.D = 500
                flyBG.Parent = hrp
                flying = true
                if JoyFrame then JoyFrame.Visible = true end
                if UpBtn then UpBtn.Visible = true end
                if DownBtn then DownBtn.Visible = true end
            end
        end
    else
        if flying then
            flying = false
            joyValue = Vector2.new(0,0)
            flyUp = false; flyDown = false
            if JoyKnob then JoyKnob.Position = UDim2.new(0.5,-27,0.5,-27) end
            if JoyFrame then JoyFrame.Visible = false end
            if UpBtn then UpBtn.Visible = false end
            if DownBtn then DownBtn.Visible = false end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = false end
            end
            if flyBV then flyBV:Destroy(); flyBV = nil end
            if flyBG then flyBG:Destroy(); flyBG = nil end
            applyMoveStats()
        end
    end
end)
makeNumber("行走速度", "WalkSpeed", 1, 500)
makeNumber("跳跃力", "JumpPower", 1, 500)
makeSwitch("无量跳跃", "InfiniteJump", function(on)
    if on then
        if not infiniteJumpConn then
            infiniteJumpConn = UIS.JumpRequest:Connect(function()
                if not Config.InfiniteJump then return end
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end)
        end
    else
        if infiniteJumpConn then infiniteJumpConn:Disconnect(); infiniteJumpConn = nil end
    end
end)

section("视觉与防护")
makeSwitch("纯阳照明", "Fullbright", function(on)
    if on then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.new(1,1,1)
    else
        Lighting.Brightness = _origBrightness
        Lighting.Ambient = _origAmbient
    end
end)
makeSwitch("云雾消散", "NoFog", function(on)
    if on then
        Lighting.FogEnd = 100000; Lighting.FogStart = 0
    else
        Lighting.FogEnd = _origFogEnd; Lighting.FogStart = _origFogStart
    end
end)
makeSwitch("无坠落伤害", "NoFallDamage", function() end)

StartBtn = Instance.new("TextButton")
StartBtn.Size = UDim2.new(1,-24,0,40)
StartBtn.Position = UDim2.new(0,12,1,-140)
StartBtn.BackgroundColor3 = T.JadeDeep
StartBtn.Text = "开始修行"
StartBtn.Font = T.FB; StartBtn.TextSize = 15
StartBtn.TextColor3 = T.Jade; StartBtn.BorderSizePixel = 0
StartBtn.ZIndex = 104; StartBtn.Parent = MainFrame
corner(StartBtn,8); stroke(StartBtn,T.Jade,2,0)
StartBtn.MouseButton1Click:Connect(function()
    if isTraining then stopTrain() else startTrain() end
end)

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1,-24,0,20)
StatusLabel.Position = UDim2.new(0,12,1,-100)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "待机"
StatusLabel.Font = T.FM; StatusLabel.TextSize = 12
StatusLabel.TextColor3 = T.TextDim; StatusLabel.ZIndex = 103
StatusLabel.Parent = MainFrame

SessionLabel = Instance.new("TextLabel")
SessionLabel.Size = UDim2.new(1,-24,0,20)
SessionLabel.Position = UDim2.new(0,12,1,-80)
SessionLabel.BackgroundTransparency = 1
SessionLabel.Text = "本层: 0 次 | 力量: 0"
SessionLabel.Font = T.FM; SessionLabel.TextSize = 11
SessionLabel.TextColor3 = T.TextCyan; SessionLabel.ZIndex = 103
SessionLabel.Parent = MainFrame

FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(1,-24,0,16)
FpsLabel.Position = UDim2.new(0,12,1,-60)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Text = "FPS: --"
FpsLabel.Font = T.FN; FpsLabel.TextSize = 11
FpsLabel.TextColor3 = T.TextDim; FpsLabel.ZIndex = 103
FpsLabel.Parent = MainFrame

JoyFrame = Instance.new("Frame")
JoyFrame.Size = UDim2.new(0,120,0,120)
JoyFrame.Position = UDim2.new(0, SafeInset, 1, -(120 + SafeInset))
JoyFrame.BackgroundColor3 = T.BgCard
JoyFrame.BorderSizePixel = 0
JoyFrame.Visible = false
JoyFrame.ZIndex = 150
JoyFrame.Parent = ScreenGui
corner(JoyFrame,60); stroke(JoyFrame,T.Bronze,2,0.3)

JoyKnob = Instance.new("Frame")
JoyKnob.Size = UDim2.new(0,54,0,54)
JoyKnob.Position = UDim2.new(0.5,-27,0.5,-27)
JoyKnob.BackgroundColor3 = T.Bronze
JoyKnob.BorderSizePixel = 0
JoyKnob.ZIndex = 153
JoyKnob.Parent = JoyFrame
corner(JoyKnob,27); stroke(JoyKnob,T.BronzeLight,2,0)

UpBtn = Instance.new("TextButton")
UpBtn.Size = UDim2.new(0,50,0,50)
UpBtn.Position = UDim2.new(1, -(50 + SafeInset), 0.5, -110)
UpBtn.BackgroundColor3 = T.BgCard
UpBtn.Text = "升"
UpBtn.Font = T.FB; UpBtn.TextSize = 14
UpBtn.TextColor3 = T.Jade; UpBtn.BorderSizePixel = 0
UpBtn.ZIndex = 152; UpBtn.Visible = false
UpBtn.Parent = ScreenGui
corner(UpBtn,10); stroke(UpBtn,T.Jade,1,0.4)

DownBtn = Instance.new("TextButton")
DownBtn.Size = UDim2.new(0,50,0,50)
DownBtn.Position = UDim2.new(1, -(50 + SafeInset), 0.5, 60)
DownBtn.BackgroundColor3 = T.BgCard
DownBtn.Text = "降"
DownBtn.Font = T.FB; DownBtn.TextSize = 14
DownBtn.TextColor3 = T.Red; DownBtn.BorderSizePixel = 0
DownBtn.ZIndex = 152; DownBtn.Visible = false
DownBtn.Parent = ScreenGui
corner(DownBtn,10); stroke(DownBtn,T.Red,1,0.4)

local function joyBegin(i)
    if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
        joyActive = true
    end
end
JoyFrame.InputBegan:Connect(joyBegin)
JoyKnob.InputBegan:Connect(joyBegin)

UIS.InputChanged:Connect(function(i)
    if not joyActive then return end
    if i.UserInputType ~= Enum.UserInputType.Touch
        and i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local cx = JoyFrame.AbsolutePosition.X + JoyFrame.AbsoluteSize.X/2
    local cy = JoyFrame.AbsolutePosition.Y + JoyFrame.AbsoluteSize.Y/2
    local dx = i.Position.X - cx
    local dy = i.Position.Y - cy
    local R = JoyFrame.AbsoluteSize.X/2 - 30
    local len = math.sqrt(dx*dx + dy*dy)
    if len > R then dx = dx/len*R; dy = dy/len*R end
    joyValue = Vector2.new(dx/R, dy/R)
    JoyKnob.Position = UDim2.new(0.5, dx-27, 0.5, dy-27)
end)

UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
        if joyActive then
            joyActive = false
            joyValue = Vector2.new(0,0)
            JoyKnob.Position = UDim2.new(0.5,-27,0.5,-27)
        end
    end
end)

UpBtn.MouseButton1Down:Connect(function() flyUp = true end)
UpBtn.MouseButton1Up:Connect(function() flyUp = false end)
UpBtn.MouseLeave:Connect(function() flyUp = false end)
DownBtn.MouseButton1Down:Connect(function() flyDown = true end)
DownBtn.MouseButton1Up:Connect(function() flyDown = false end)
DownBtn.MouseLeave:Connect(function() flyDown = false end)

local function tryRebirth()
    if pendingRebirth or not RebirthEvent then return end
    local rebirths = getRebirths()
    if Config.StopAtTargetRebirth and Config.TargetRebirthCount > 0
        and rebirths >= Config.TargetRebirthCount then
        Config.AutoRebirth = false
        return
    end
    pendingRebirth = true
    pendingRebirthStart = tick()
    pendingRebirthLast = rebirths
    pcall(function() RebirthEvent:FireServer("Start") end)
    task.wait(0.5)
    pcall(function() RebirthEvent:FireServer("Update") end)
end

local function checkRebirth()
    if not pendingRebirth then return end
    if getRebirths() > pendingRebirthLast then
        pendingRebirth = false
        return
    end
    if tick() - pendingRebirthStart > REBIRTH_TIMEOUT then
        pendingRebirth = false
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(1)
        if Config.AutoRebirth then
            checkRebirth()
            if not pendingRebirth then tryRebirth() end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not flying then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not flyBV or not flyBG then return end
    local cam2 = workspace.CurrentCamera
    if not cam2 then return end

    local dir = Vector3.zero
    if joyValue.Magnitude > 0.1 then
        dir = cam2.CFrame.LookVector * (-joyValue.Y) + cam2.CFrame.RightVector * joyValue.X
    end
    if flyUp then dir = dir + Vector3.new(0,1,0) end
    if flyDown then dir = dir - Vector3.new(0,1,0) end
    if dir.Magnitude > 0 then
        local speed = Config.FlySpeed or 50
        local st = math.min(joyValue.Magnitude, 1)
        if st < 0.1 then st = 1 end
        dir = dir.Unit * speed * st
    end
    flyBV.Velocity = dir
    flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam2.CFrame.LookVector)
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    applyMoveStats()
end)

local frameCount = 0
local fpsTimer = tick()
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    if now - fpsTimer >= 1 then
        local fps = math.floor(frameCount / (now - fpsTimer))
        frameCount = 0
        fpsTimer = now
        if FpsLabel then FpsLabel.Text = "FPS: " .. fps end
    end
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(0.2)
        refreshStats()
        for _,def in ipairs(STAT_DEFS) do
            if statLabels[def.key] then
                statLabels[def.key].Text = fmt(getStat(def.key))
            end
        end
        if isTraining and sessionStart and SessionLabel then
            local now = getStrength()
            SessionLabel.Text = string.format("本层: %d 次 | 力量: %s", trainCount, fmt(now - sessionStart))
        end
    end
end)

ScreenGui.Destroying:Connect(function()
    isTraining = false
    if infiniteJumpConn then infiniteJumpConn:Disconnect() end
    if antiAfkConn then antiAfkConn:Disconnect() end
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
end)

updateStartBtn()
updateStatus()
applyMoveStats()
if Config.UseAllActions and TrainEvent then task.defer(startTrain) end