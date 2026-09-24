local AttackUI = {}

function AttackUI.create(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AttackControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local button = Instance.new("TextButton")
	button.Name = "AttackButton"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -28, 1, -118)
	button.Size = UDim2.fromOffset(72, 72)
	button.BackgroundColor3 = Color3.fromRGB(28, 32, 36)
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Text = "ATAQUE"
	button.TextColor3 = Color3.fromRGB(245, 247, 248)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Parent = gui

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = button

	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(58, 58)
	size.MaxSize = Vector2.new(76, 76)
	size.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(73, 82, 88)
	stroke.Transparency = 0.25
	stroke.Thickness = 1.5
	stroke.Parent = button

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.16, 0)
	padding.PaddingRight = UDim.new(0.16, 0)
	padding.Parent = button

	return {gui = gui, button = button}
end

return AttackUI
