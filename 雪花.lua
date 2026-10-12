local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

pcall(function()
    local old = PG:FindFirstChild("SnowUI")
    if old then old:Destroy() end
    local old2 = PG:FindFirstChild("TestRed")
    if old2 then old2:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name = "SnowUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.IgnoreGuiInset = true
sg.Parent = PG

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 480)
main.Position = UDim2.new(0.5, -160, 0.5, -240)
main.BackgroundColor3 = Color3.fromRGB(10, 14, 18)
main.BorderSizePixel = 0
main.Visible = true
main.Parent = sg

pcall(function()
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = main
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 30)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Text = "力量之冠 · 雪花脚本"
title.TextColor3 = Color3.fromRGB(215, 185, 130)
title.TextSize = 16
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local strLabel = Instance.new("TextLabel")
strLabel.Size = UDim2.new(1, -20, 0, 24)
strLabel.Position = UDim2.new(0, 10, 0, 44)
strLabel.BackgroundColor3 = Color3.fromRGB(20, 32, 40)
strLabel.Text = "力量: 0"
strLabel.TextColor3 = Color3.fromRGB(212, 175, 55)
strLabel.TextSize = 13
strLabel.Font = Enum.Font.GothamBold
strLabel.BorderSizePixel = 0
strLabel.Parent = main

local rebLabel = Instance.new("TextLabel")
rebLabel.Size = UDim2.new(1, -20, 0, 24)
rebLabel.Position = UDim2.new(0, 10, 0, 72)
rebLabel.BackgroundColor3 = Color3.fromRGB(20, 32, 40)
rebLabel.Text = "重生: 0"
rebLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
rebLabel.TextSize = 13
rebLabel.Font = Enum.Font.GothamBold
rebLabel.BorderSizePixel = 0
rebLabel.Parent = main

local function makeBtn(y, label, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = color or Color3.fromRGB(20, 32, 40)
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(230, 235, 238)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.Parent = main
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = btn
    end)
    btn.MouseButton1Click:Connect(function()
        local ok, err = pcall(onClick)
        if not ok then
            print("[雪花] 按钮出错:", err)
        end
    end)
    return btn
end

local isTraining = false
local isFlying = false
local autoReb = false
local speedHigh = false
local flyBV, flyBG = nil, nil
local trainEvent = nil

for _, name in ipairs({"TrainEvent","Train","WorkoutEvent","Workout","Exercise","DoRep","GainMuscle","Rep","TrainRemote","Action","PushUp"}) do
    local r = RS:FindFirstChild(name)
    if not r then
        local remotes = RS:FindFirstChild("Remotes")
        if remotes then r = remotes:FindFirstChild(name) end
    end
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
        trainEvent = r
        break
    end
end

if not trainEvent then
    for _, v in ipairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") then
            trainEvent = v
            break
        end
    end
end

local trainBtn = makeBtn(108, "开始修行", Color3.fromRGB(56, 120, 100), function()
    isTraining = not isTraining
    if isTraining then
        trainBtn.Text = "停止修行 (运行中)"
        trainBtn.TextColor3 = Color3.fromRGB(96, 180, 150)
    else
        trainBtn.Text = "开始修行"
        trainBtn.TextColor3 = Color3.fromRGB(230, 235, 238)
    end
end)

task.spawn(function()
    while sg.Parent do
        task.wait(0.1)
        if isTraining and trainEvent then
            pcall(function()
                trainEvent:FireServer("PushUp")
            end)
        end
    end
end)

local rebBtn = makeBtn(156, "自动重生: 关", nil, function()
    autoReb = not autoReb
    rebBtn.Text = autoReb and "自动重生: 开" or "自动重生: 关"
    rebBtn.TextColor3 = autoReb and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(230, 235, 238)
end)

task.spawn(function()
    while sg.Parent do
        task.wait(2)
        if autoReb then
            local reb = RS:FindFirstChild("RebirthEvent") or RS:FindFirstChild("Rebirth") or RS:FindFirstChild("RebirthRemote")
            if reb then
                pcall(function() reb:FireServer("Start") end)
                task.wait(0.5)
                pcall(function() reb:FireServer("Update") end)
            end
        end
    end
end)

local spdBtn = makeBtn(204, "速度: 16", nil, function()
    speedHigh = not speedHigh
    local char = LP.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = speedHigh and 100 or 16
            spdBtn.Text = "速度: " .. hum.WalkSpeed
        end
    end
end)

local flyBtn = makeBtn(252, "飞行: 关", nil, function()
    if isFlying then
        isFlying = false
        flyBtn.Text = "飞行: 关"
        flyBtn.TextColor3 = Color3.fromRGB(230, 235, 238)
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    else
        local char = LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp then
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
                isFlying = true
                flyBtn.Text = "飞行: 开"
                flyBtn.TextColor3 = Color3.fromRGB(96, 180, 150)
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    if not isFlying then return end
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not flyBV or not flyBG then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    flyBV.Velocity = cam.CFrame.LookVector * 50
    flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + cam.CFrame.LookVector)
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 26)
closeBtn.Position = UDim2.new(1, -50, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
closeBtn.Text = "关"
closeBtn.TextColor3 = Color3.fromRGB(215, 185, 130)
closeBtn.TextSize = 13
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = main
pcall(function()
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = closeBtn
end)
closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)

task.spawn(function()
    while sg.Parent do
        task.wait(0.3)
        local str = 0
        local ls = LP:FindFirstChild("leaderstats")
        if ls then
            local v = ls:FindFirstChild("Strength") or ls:FindFirstChild("Power") or ls:FindFirstChild("力量")
            if v then str = v.Value end
        end
        local a = LP:GetAttribute("Strength")
        if a then str = a end
        strLabel.Text = "力量: " .. tostring(str)

        local reb = 0
        if ls then
            local v = ls:FindFirstChild("Rebirths") or ls:FindFirstChild("Rebirth") or ls:FindFirstChild("重生")
            if v then reb = v.Value end
        end
        rebLabel.Text = "重生: " .. tostring(reb)
    end
end)

print("[雪花] 已加载")