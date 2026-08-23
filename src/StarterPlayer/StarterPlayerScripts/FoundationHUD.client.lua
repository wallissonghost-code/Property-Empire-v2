local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MuseumFoundationHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 16)
bar.Size = UDim2.fromOffset(520, 52)
bar.BackgroundColor3 = Color3.fromRGB(19, 24, 31)
bar.BackgroundTransparency = 0.08
bar.Parent = gui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(75, 101, 124)
stroke.Transparency = 0.35
stroke.Parent = bar

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = bar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = bar

local function stat(name, width)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(width, 38)
	frame.BackgroundColor3 = Color3.fromRGB(29, 36, 46)
	frame.Parent = bar
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(242, 245, 248)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextWrapped = true
	label.Parent = frame
	return label
end

local levelLabel = stat("Level", 96)
local starLabel = stat("Stars", 112)
local prestigeLabel = stat("Prestige", 130)
local ratingLabel = stat("Rating", 118)

local function refresh()
	local level = player:GetAttribute("MuseumLevel") or 1
	local stars = player:GetAttribute("MuseumStars") or 1
	local prestige = player:GetAttribute("Prestige") or 0
	local rating = player:GetAttribute("MuseumRating") or 1
	levelLabel.Text = "MUSEU\nNÍVEL " .. tostring(level)
	starLabel.Text = string.rep("★", stars) .. string.rep("☆", math.max(0, 5-stars))
	prestigeLabel.Text = "PRESTÍGIO\n" .. tostring(prestige)
	ratingLabel.Text = string.format("AVALIAÇÃO\n%.1f/5", rating)
end

for _, attr in ipairs({"MuseumLevel","MuseumStars","Prestige","MuseumRating"}) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end
refresh()

local function fitMobile()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local w = camera.ViewportSize.X
	if w < 700 then
		bar.Size = UDim2.new(0.92, 0, 0, 48)
		levelLabel.Parent.Size = UDim2.fromOffset(74, 34)
		starLabel.Parent.Size = UDim2.fromOffset(92, 34)
		prestigeLabel.Parent.Size = UDim2.fromOffset(104, 34)
		ratingLabel.Parent.Size = UDim2.fromOffset(92, 34)
	else
		bar.Size = UDim2.fromOffset(520, 52)
	end
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fitMobile)
task.defer(fitMobile)
