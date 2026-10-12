local LP = game:GetService("Players").LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local sg = PG:FindFirstChild("CrownMobileUI")
if sg then
    -- 找到主面板
    local main = nil
    for _, v in ipairs(sg:GetChildren()) do
        if v:IsA("Frame") and v.Size.Y.Offset > 400 then
            main = v
            break
        end
    end
    if main then
        print("主面板尺寸:", main.Size)
        -- 遍历主面板所有子对象
        for _, v in ipairs(main:GetDescendants()) do
            if v:IsA("ScrollingFrame") then
                print("找到 ScrollingFrame")
                v.Visible = true
                v.Position = UDim2.new(0,12,0,144)
                v.Size = UDim2.new(1,-24,1,-160)
                v.CanvasSize = UDim2.new(0,0,0,#v:GetChildren()*52)
                print("  子对象数:", #v:GetChildren())
                for _, c in ipairs(v:GetChildren()) do
                    print("    -", c.ClassName, c.Name, "Visible="..tostring(c.Visible))
                end
            elseif v:IsA("TextButton") then
                print("找到按钮:", v.Text, "位置:", v.Position)
                v.Visible = true
            end
        end
    end
end