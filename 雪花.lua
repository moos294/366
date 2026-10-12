local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local sg = Instance.new("ScreenGui")
sg.Name = "TestRed"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999999
sg.Parent = pg
local f = Instance.new("Frame")
f.Size = UDim2.new(0, 200, 0, 200)
f.Position = UDim2.new(0.5, -100, 0.5, -100)
f.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
f.BorderSizePixel = 0
f.Parent = sg
print("红方块已创建:", f.AbsoluteSize)