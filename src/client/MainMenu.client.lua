local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("OpenMainMenu")

local gui = Instance.new("ScreenGui")
gui.Name = "CidadeProsperaMenu"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 14)
overlay.BackgroundTransparency = 0.18
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.86, 0, 0, 300)
panel.BackgroundColor3 = Color3.fromRGB(24, 27, 30)
panel.Parent = overlay

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 24, 0, 22)
title.Size = UDim2.new(1, -80, 0, 42)
title.Font = Enum.Font.GothamBold
title.Text = "CIDADE PROSPERA"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 25
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 24, 0, 70)
subtitle.Size = UDim2.new(1, -48, 0, 50)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Menu principal"
subtitle.TextColor3 = Color3.fromRGB(170, 175, 180)
subtitle.TextSize = 17
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = panel

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -18, 0, 18)
close.Size = UDim2.fromOffset(44, 44)
close.BackgroundColor3 = Color3.fromRGB(40, 44, 48)
close.Text = "×"
close.TextColor3 = Color3.new(1, 1, 1)
close.TextSize = 28
close.Font = Enum.Font.GothamBold
close.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = close

close.Activated:Connect(function()
	gui.Enabled = false
end)

remote.OnClientEvent:Connect(function()
	gui.Enabled = true
end)
