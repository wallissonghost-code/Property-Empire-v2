local MenuUI = {}

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
	return item
end

function MenuUI.create(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(5, 7, 9)
	overlay.BackgroundTransparency = 0.42
	overlay.BorderSizePixel = 0
	overlay.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.78, 0, 0.58, 0)
	panel.BackgroundColor3 = Color3.fromRGB(14, 17, 20)
	panel.BorderSizePixel = 0
	panel.Parent = overlay
	corner(panel, 20)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.72
	aspect.AspectType = Enum.AspectType.ScaleWithParentSize
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = panel

	local limits = Instance.new("UISizeConstraint")
	limits.MinSize = Vector2.new(280, 230)
	limits.MaxSize = Vector2.new(620, 400)
	limits.Parent = panel

		local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(20, 24, 27), Color3.fromRGB(12, 15, 18))
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
	corner(accent, 4)

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
	close.Name = "Close"
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
	corner(close, 19)

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

	return {gui = gui, panel = panel, close = close, content = content}
end

return MenuUI
