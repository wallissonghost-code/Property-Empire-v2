local AltitudeUI = {}

function AltitudeUI.create(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AltitudeHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "AltitudeMeter"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 16)
	frame.Size = UDim2.fromOffset(116, 34)
	frame.BackgroundColor3 = Color3.fromRGB(16, 19, 22)
	frame.BackgroundTransparency = 0.22
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.72
	stroke.Thickness = 1
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Value"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "ALT 000"
	label.TextColor3 = Color3.fromRGB(245, 247, 248)
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 17
	label.Parent = frame

	return {gui = gui, label = label}
end

function AltitudeUI.setAltitude(view, altitude)
	view.label.Text = string.format("ALT %03d", math.max(0, math.floor(altitude + 0.5)))
end

return AltitudeUI
