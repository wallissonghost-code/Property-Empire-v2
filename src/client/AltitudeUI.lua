local AltitudeUI = {}

local function styleMeter(frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.72
	stroke.Thickness = 1
	stroke.Parent = frame
end

local function makeLabel(parent, text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 247, 248)
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 17
	label.Parent = parent
	return label
end

function AltitudeUI.create(playerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AltitudeHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = playerGui

	local group = Instance.new("Frame")
	group.Name = "FlightTelemetry"
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.new(0.5, 0, 0, 16)
	group.Size = UDim2.fromOffset(240, 34)
	group.BackgroundTransparency = 1
	group.Parent = gui

	local altitudeFrame = Instance.new("Frame")
	altitudeFrame.Name = "AltitudeMeter"
	altitudeFrame.Size = UDim2.fromOffset(116, 34)
	altitudeFrame.BackgroundColor3 = Color3.fromRGB(16, 19, 22)
	altitudeFrame.BackgroundTransparency = 0.22
	altitudeFrame.Parent = group
	styleMeter(altitudeFrame)
	local altitudeLabel = makeLabel(altitudeFrame, "ALT 000")
	altitudeLabel.Name = "Value"

	local speedFrame = Instance.new("Frame")
	speedFrame.Name = "SpeedMeter"
	speedFrame.Position = UDim2.fromOffset(124, 0)
	speedFrame.Size = UDim2.fromOffset(116, 34)
	speedFrame.BackgroundColor3 = Color3.fromRGB(16, 19, 22)
	speedFrame.BackgroundTransparency = 0.22
	speedFrame.Parent = group
	styleMeter(speedFrame)
	local speedLabel = makeLabel(speedFrame, "VEL 000")
	speedLabel.Name = "Value"

	return {gui = gui, altitude = altitudeLabel, speed = speedLabel}
end

function AltitudeUI.setAltitude(view, altitude)
	view.altitude.Text = string.format("ALT %03d", math.max(0, math.floor(altitude + 0.5)))
end

function AltitudeUI.setSpeed(view, speed)
	view.speed.Text = string.format("VEL %03d", math.max(0, math.floor(speed + 0.5)))
end

return AltitudeUI
