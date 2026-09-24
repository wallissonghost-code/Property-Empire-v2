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
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(5, 7, 9)
overlay.BackgroundTransparency = 0.42
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.78, 0, 0.58, 0)
panel.BackgroundColor3 = Color3.fromRGB(14, 17, 20)
panel.BorderSizePixel = 0
panel.Parent = overlay

local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1.72
aspect.AspectType = Enum.AspectType.ScaleWithParentSize
aspect.DominantAxis = Enum.DominantAxis.Width
aspect.Parent = panel

local limits = Instance.new("UISizeConstraint")
limits.MinSize = Vector2.new(280, 230)
limits.MaxSize = Vector2.new(620, 400)
limits.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 20)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(67, 74, 79)
stroke.Transparency = 0.45
stroke.Thickness = 1
stroke.Parent = panel

local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 24, 27)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 15, 18)),
})
gradient.Parent = panel

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(22, 18)
header.Size = UDim2.new(1, -44, 0, 52)
header.Parent = panel

local accent = Instance.new("Frame")
accent.AnchorPoint = Vector2.new(0, 0.5)
accent.Position = UDim2.new(0, 0, 0.5, 0)
accent.Size = UDim2.fromOffset(4, 27)
accent.BackgroundColor3 = Color3.fromRGB(52, 232, 127)
accent.BorderSizePixel = 0
accent.Parent = header
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(15, 0)
title.Size = UDim2.new(1, -70, 1, 0)
title.Font = Enum.Font.GothamBold
title.Text = "MENU"
title.TextColor3 = Color3.fromRGB(247, 249, 250)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local titleLimit = Instance.new("UITextSizeConstraint")
titleLimit.MinTextSize = 20
titleLimit.MaxTextSize = 26
titleLimit.Parent = title

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, 0, 0.5, 0)
close.Size = UDim2.fromOffset(38, 38)
close.BackgroundColor3 = Color3.fromRGB(28, 33, 37)
close.AutoButtonColor = false
close.Text = "×"
close.TextColor3 = Color3.fromRGB(224, 228, 231)
close.TextSize = 24
close.Font = Enum.Font.GothamMedium
close.Parent = header
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = close
local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(72, 79, 84)
closeStroke.Transparency = 0.5
closeStroke.Parent = close

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(22, 78)
divider.Size = UDim2.new(1, -44, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(60, 67, 72)
divider.BackgroundTransparency = 0.55
divider.BorderSizePixel = 0
divider.Parent = panel

local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(22, 94)
content.Size = UDim2.new(1, -44, 1, -116)
content.Parent = panel

local empty = Instance.new("TextLabel")
empty.BackgroundTransparency = 1
empty.AnchorPoint = Vector2.new(0.5, 0.5)
empty.Position = UDim2.fromScale(0.5, 0.5)
empty.Size = UDim2.new(0.8, 0, 0, 32)
empty.Font = Enum.Font.GothamMedium
empty.Text = "Selecione uma opção"
empty.TextColor3 = Color3.fromRGB(121, 130, 136)
empty.TextScaled = true
empty.Parent = content
local emptyLimit = Instance.new("UITextSizeConstraint")
emptyLimit.MinTextSize = 12
emptyLimit.MaxTextSize = 15
emptyLimit.Parent = empty

local function hideMenu()
	gui.Enabled = false
end

local function showMenu()
	gui.Enabled = true
	panel.Position = UDim2.fromScale(0.5, 0.525)
	panel.BackgroundTransparency = 0.08
	TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0,
	}):Play()
end

close.Activated:Connect(hideMenu)
remote.OnClientEvent:Connect(showMenu)
