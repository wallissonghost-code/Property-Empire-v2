local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("OpenMainMenu")

local gui = Instance.new("ScreenGui")
gui.Name = "MainMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(7, 9, 11)
overlay.BackgroundTransparency = 0.28
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.Size = UDim2.new(0.88, 0, 0.72, 0)
panel.BackgroundColor3 = Color3.fromRGB(16, 19, 22)
panel.BorderSizePixel = 0
panel.Parent = overlay

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 300)
sizeConstraint.MaxSize = Vector2.new(760, 560)
sizeConstraint.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(54, 61, 66)
stroke.Transparency = 0.35
stroke.Thickness = 1
stroke.Parent = panel

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Position = UDim2.fromOffset(24, 24)
accent.Size = UDim2.fromOffset(38, 4)
accent.BackgroundColor3 = Color3.fromRGB(54, 230, 125)
accent.BorderSizePixel = 0
accent.Parent = panel
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 40)
title.Size = UDim2.new(1, -96, 0, 52)
title.Font = Enum.Font.GothamBold
title.Text = "MENU"
title.TextColor3 = Color3.fromRGB(245, 247, 248)
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local divider = Instance.new("Frame")
divider.Position = UDim2.new(0, 24, 0, 100)
divider.Size = UDim2.new(1, -48, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(49, 55, 60)
divider.BackgroundTransparency = 0.35
divider.BorderSizePixel = 0
divider.Parent = panel

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(24, 120)
content.Size = UDim2.new(1, -48, 1, -144)
content.Parent = panel

local placeholder = Instance.new("TextLabel")
placeholder.Name = "Placeholder"
placeholder.BackgroundTransparency = 1
placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
placeholder.Position = UDim2.fromScale(0.5, 0.5)
placeholder.Size = UDim2.new(1, -30, 0, 40)
placeholder.Font = Enum.Font.GothamMedium
placeholder.Text = "Selecione uma opção"
placeholder.TextColor3 = Color3.fromRGB(119, 127, 133)
placeholder.TextSize = 15
placeholder.Parent = content

local close = Instance.new("TextButton")
close.Name = "Close"
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -20, 0, 20)
close.Size = UDim2.fromOffset(46, 46)
close.BackgroundColor3 = Color3.fromRGB(29, 33, 37)
close.AutoButtonColor = false
close.Text = "×"
close.TextColor3 = Color3.fromRGB(220, 224, 227)
close.TextSize = 27
close.Font = Enum.Font.GothamMedium
close.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = close

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(62, 69, 74)
closeStroke.Transparency = 0.45
closeStroke.Parent = close

local function hideMenu()
	gui.Enabled = false
end

local function showMenu()
	gui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.54)
	panel.BackgroundTransparency = 0.08
	TweenService:Create(
		panel,
		TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Position = UDim2.fromScale(0.5, 0.52), BackgroundTransparency = 0}
	):Play()
end

close.Activated:Connect(hideMenu)
remote.OnClientEvent:Connect(showMenu)
