local FlightUI = {}

local function makeButton(parent, name, text, position)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = position
	button.Size = UDim2.fromOffset(64, 64)
	button.BackgroundColor3 = Color3.fromRGB(28, 32, 36)
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = Color3.fromRGB(245, 247, 248)
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.Visible = false
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(73, 82, 88)
	stroke.Transparency = 0.25
	stroke.Thickness = 1.5
	stroke.Parent = button

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 13
	limit.MaxTextSize = 18
	limit.Parent = button
	return button
end

function FlightUI.create(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "FlightControls"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local toggle = makeButton(gui, "FlyButton", "VOAR", UDim2.new(1, -112, 1, -118))
	toggle.Size = UDim2.fromOffset(72, 72)
	toggle.Visible = true

	return {gui = gui, button = toggle}
end

function FlightUI.setActive(view, active)
	view.button.Text = active and "POUSAR" or "VOAR"
	view.button.BackgroundColor3 = active and Color3.fromRGB(36, 96, 67) or Color3.fromRGB(28, 32, 36)
end

return FlightUI
