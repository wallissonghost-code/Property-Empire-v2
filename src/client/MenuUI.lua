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

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.78, 0, 0.58, 0)
	panel.BackgroundColor3 = Color3.fromRGB(14, 17, 20)
	panel.BorderSizePixel = 0
	panel.Parent = gui
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

	local skillTitle = Instance.new("TextLabel")
	skillTitle.BackgroundTransparency = 1
	skillTitle.Size = UDim2.new(1, 0, 0, 30)
	skillTitle.Font = Enum.Font.GothamBold
	skillTitle.Text = "Skill"
	skillTitle.TextColor3 = Color3.fromRGB(247, 249, 250)
	skillTitle.TextSize = 20
	skillTitle.TextXAlignment = Enum.TextXAlignment.Left
	skillTitle.Parent = content

	local skillCard = Instance.new("Frame")
	skillCard.Position = UDim2.fromOffset(0, 40)
	skillCard.Size = UDim2.new(1, 0, 0, 82)
	skillCard.BackgroundColor3 = Color3.fromRGB(24, 29, 33)
	skillCard.BorderSizePixel = 0
	skillCard.Parent = content
	corner(skillCard, 12)

	local skillName = Instance.new("TextLabel")
	skillName.BackgroundTransparency = 1
	skillName.Position = UDim2.fromOffset(14, 10)
	skillName.Size = UDim2.new(1, -150, 0, 26)
	skillName.Font = Enum.Font.GothamBold
	skillName.Text = "Olho de Laser"
	skillName.TextColor3 = Color3.fromRGB(245, 247, 248)
	skillName.TextSize = 16
	skillName.TextXAlignment = Enum.TextXAlignment.Left
	skillName.Parent = skillCard

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromOffset(14, 40)
	price.Size = UDim2.new(1, -150, 0, 22)
	price.Font = Enum.Font.GothamMedium
	price.Text = "Valor: R$0"
	price.TextColor3 = Color3.fromRGB(151, 160, 166)
	price.TextSize = 14
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.Parent = skillCard

	local buy = Instance.new("TextButton")
	buy.Name = "BuyLaserEyes"
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
	buy.Size = UDim2.fromOffset(112, 42)
	buy.BackgroundColor3 = Color3.fromRGB(45, 210, 105)
	buy.AutoButtonColor = false
	buy.Text = "COMPRAR"
	buy.TextColor3 = Color3.fromRGB(8, 20, 13)
	buy.Font = Enum.Font.GothamBold
	buy.TextSize = 13
	buy.Parent = skillCard
	corner(buy, 10)

	local empty = Instance.new("TextLabel")
	empty.BackgroundTransparency = 1
	empty.AnchorPoint = Vector2.new(0.5, 0.5)
	empty.Position = UDim2.fromScale(0.5, 0.5)
	empty.Size = UDim2.new(0.8, 0, 0, 32)
	empty.Font = Enum.Font.GothamMedium
	empty.Text = "Selecione uma opção"
	empty.TextColor3 = Color3.fromRGB(121, 130, 136)
	empty.TextScaled = true
	empty.Visible = false
	empty.Parent = content
	local emptyLimit = Instance.new("UITextSizeConstraint")
	emptyLimit.MinTextSize = 12
	emptyLimit.MaxTextSize = 15
	emptyLimit.Parent = empty

	return {gui = gui, panel = panel, close = close, content = content, buyLaserEyes = buy}
end

return MenuUI
