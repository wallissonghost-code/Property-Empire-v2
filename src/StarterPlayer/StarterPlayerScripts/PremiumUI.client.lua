local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BuildCatalog = require(ReplicatedStorage.Shared.BuildCatalog)

local COLORS = {
	Panel = Color3.fromRGB(20, 24, 31),
	Card = Color3.fromRGB(29, 35, 44),
	Card2 = Color3.fromRGB(35, 43, 54),
	Stroke = Color3.fromRGB(74, 92, 112),
	Accent = Color3.fromRGB(71, 172, 255),
	Accent2 = Color3.fromRGB(68, 221, 157),
	Text = Color3.fromRGB(244, 247, 250),
	Muted = Color3.fromRGB(158, 172, 190),
	Danger = Color3.fromRGB(210, 82, 92),
	Gold = Color3.fromRGB(241, 194, 92),
}

local function corner(obj, radius)
	if not obj:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, radius or 12)
		c.Parent = obj
	end
end

local function stroke(obj, color, thickness, transparency)
	local s = obj:FindFirstChild("PremiumStroke") or Instance.new("UIStroke")
	s.Name = "PremiumStroke"
	s.Color = color or COLORS.Stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0.35
	s.Parent = obj
end

local function gradient(obj, a, b, rotation)
	local g = obj:FindFirstChild("PremiumGradient") or Instance.new("UIGradient")
	g.Name = "PremiumGradient"
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = obj
end

local function styleButton(button, accent)
	if not button:IsA("TextButton") then return end
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = COLORS.Text
	button.BackgroundColor3 = accent or COLORS.Card2
	corner(button, 11)
	stroke(button, accent or COLORS.Stroke, 1, 0.35)
end

local function stylePanel(frame)
	if not frame:IsA("Frame") then return end
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = 0.04
	corner(frame, 16)
	stroke(frame, COLORS.Stroke, 1.2, 0.28)
end

local function money(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	repeat
		local formatted, count = text:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
		text = formatted
		if count == 0 then break end
	until false
	return "$" .. text
end

local function previewPart(parent, name, size, cf, item, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.Material = item.Material or Enum.Material.SmoothPlastic
	p.Color = item.Color or Color3.new(1,1,1)
	p.Transparency = transparency == nil and (item.Transparency or 0) or transparency
	p.Parent = parent
	return p
end

local function buildPreviewModel(item)
	local model = Instance.new("WorldModel")
	local root = CFrame.new()
	if item.Composite == "Doorway" then
		previewPart(model,"L",Vector3.new(2,8,1),root*CFrame.new(-3,0,0),item)
		previewPart(model,"R",Vector3.new(2,8,1),root*CFrame.new(3,0,0),item)
		previewPart(model,"T",Vector3.new(4,2,1),root*CFrame.new(0,3,0),item)
	elseif item.Composite == "Window" then
		previewPart(model,"L",Vector3.new(1.2,8,1),root*CFrame.new(-3.4,0,0),item)
		previewPart(model,"R",Vector3.new(1.2,8,1),root*CFrame.new(3.4,0,0),item)
		previewPart(model,"T",Vector3.new(5.6,1.2,1),root*CFrame.new(0,3.4,0),item)
		previewPart(model,"B",Vector3.new(5.6,1.2,1),root*CFrame.new(0,-3.4,0),item)
		local glassItem={Material=Enum.Material.Glass,Color=Color3.fromRGB(157,211,229),Transparency=.35}
		previewPart(model,"Glass",Vector3.new(5.6,5.6,.35),root,glassItem)
	elseif item.Composite == "Stair" then
		for i=1,6 do
			previewPart(model,"Step"..i,Vector3.new(8,i,2),root*CFrame.new(0,-4+i/2,-7+i*2.2),item)
		end
	else
		previewPart(model,item.Name,item.Size,root,item)
	end
	return model
end

local function makeViewport(parent, item)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "ItemPreview"
	vp.BackgroundColor3 = Color3.fromRGB(22, 27, 34)
	vp.BackgroundTransparency = 0
	vp.BorderSizePixel = 0
	vp.Size = UDim2.fromOffset(92, 74)
	vp.Position = UDim2.fromOffset(8, 8)
	vp.Ambient = Color3.fromRGB(190, 195, 205)
	vp.LightColor = Color3.fromRGB(255, 246, 225)
	vp.LightDirection = Vector3.new(-1,-1,-1)
	vp.Parent = parent
	corner(vp, 9)

	local world = buildPreviewModel(item)
	world.Parent = vp
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(Vector3.new(11,9,14), Vector3.new(0,0,0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

local function findCatalogItem(text)
	for _, item in ipairs(BuildCatalog.GetOrderedItems()) do
		if string.find(text, item.Name, 1, true) then return item end
	end
	return nil
end

local function decorateCatalogButton(button)
	if not button:IsA("TextButton") or button:GetAttribute("PremiumDecorated") then return end
	local item = findCatalogItem(button.Text)
	if not item then return end
	button:SetAttribute("PremiumDecorated", true)
	button.Size = UDim2.new(1, -2, 0, 94)
	button.BackgroundColor3 = COLORS.Card
	button.TextTransparency = 1
	corner(button, 12)
	stroke(button, COLORS.Stroke, 1, 0.38)
	makeViewport(button, item)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(110, 10)
	name.Size = UDim2.new(1, -118, 0, 26)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = COLORS.Text
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = item.Name
	name.Parent = button

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromOffset(110, 37)
	price.Size = UDim2.new(1, -118, 0, 20)
	price.Font = Enum.Font.GothamBold
	price.TextSize = 12
	price.TextColor3 = COLORS.Accent2
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.Text = money(item.Price)
	price.Parent = button

	local req = Instance.new("TextLabel")
	req.BackgroundTransparency = 1
	req.Position = UDim2.fromOffset(110, 58)
	req.Size = UDim2.new(1, -118, 0, 26)
	req.Font = Enum.Font.Gotham
	req.TextSize = 10
	req.TextColor3 = COLORS.Muted
	req.TextXAlignment = Enum.TextXAlignment.Left
	req.TextWrapped = true
	req.Text = string.format("Nível %d  •  Prestígio %d", item.MinLevel, item.MinPrestige)
	req.Parent = button
end

local function decorateBuildUi(gui)
	if gui:GetAttribute("PremiumStyled") then return end
	gui:SetAttribute("PremiumStyled", true)
	local panel = gui:WaitForChild("BuildPanel", 8)
	if not panel then return end
	stylePanel(panel)
	panel.Size = UDim2.new(0.43, 0, 0.9, 0)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then limit.MinSize=Vector2.new(320,500) limit.MaxSize=Vector2.new(500,760) end

	for _, d in ipairs(panel:GetDescendants()) do
		if d:IsA("TextLabel") then
			d.Font = d.Font == Enum.Font.GothamBold and Enum.Font.GothamBold or Enum.Font.GothamMedium
			if d.TextColor3.R > .75 then d.TextColor3 = COLORS.Text end
		elseif d:IsA("TextButton") then
			styleButton(d)
		elseif d:IsA("ScrollingFrame") then
			d.BackgroundColor3 = Color3.fromRGB(24,29,37)
			d.ScrollBarImageColor3 = COLORS.Accent
			corner(d, 12)
		end
	end

	local open = gui:FindFirstChild("OpenBuild")
	if open then
		open.Size = UDim2.fromOffset(188, 54)
		open.BackgroundColor3 = COLORS.Accent
		styleButton(open, COLORS.Accent)
		gradient(open, Color3.fromRGB(69,160,255), Color3.fromRGB(71,210,205), 0)
	end

	local catalog
	for _, c in ipairs(panel:GetChildren()) do if c:IsA("ScrollingFrame") then catalog=c break end end
	if catalog then
		for _, child in ipairs(catalog:GetChildren()) do decorateCatalogButton(child) end
		catalog.ChildAdded:Connect(function(child) task.defer(decorateCatalogButton, child) end)
	end
end

local function decorateMuseumUi(gui)
	if gui:GetAttribute("PremiumStyled") then return end
	gui:SetAttribute("PremiumStyled", true)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("Frame") then stylePanel(d)
		elseif d:IsA("TextButton") then styleButton(d)
		elseif d:IsA("TextLabel") then
			d.Font = d.Font == Enum.Font.GothamBold and Enum.Font.GothamBold or Enum.Font.GothamMedium
			if d.BackgroundTransparency < .95 then corner(d, 12) stroke(d, COLORS.Stroke,1,.4) end
		elseif d:IsA("ScrollingFrame") then
			d.BackgroundColor3=Color3.fromRGB(24,29,37)
			d.ScrollBarImageColor3=COLORS.Accent
			corner(d,12)
		end
	end
	local cash = gui:FindFirstChildWhichIsA("TextLabel")
	if cash then gradient(cash,Color3.fromRGB(26,32,42),Color3.fromRGB(34,51,66),0) end
end

local function decorateHomeUi(gui)
	if gui:GetAttribute("PremiumStyled") then return end
	gui:SetAttribute("PremiumStyled", true)
	local button = gui:FindFirstChild("ReturnHome")
	if not button then return end
	button.Size = UDim2.fromOffset(204,54)
	button.BackgroundColor3 = Color3.fromRGB(32,43,57)
	styleButton(button, COLORS.Accent)
	gradient(button,Color3.fromRGB(34,47,62),Color3.fromRGB(47,78,96),0)
end

local function decorate(gui)
	if gui.Name == "MuseumBuildUI" then decorateBuildUi(gui)
	elseif gui.Name == "MuseumEmpireUI" then decorateMuseumUi(gui)
	elseif gui.Name == "MuseumHomeButton" then decorateHomeUi(gui) end
end

for _, gui in ipairs(playerGui:GetChildren()) do task.defer(decorate, gui) end
playerGui.ChildAdded:Connect(function(gui) task.defer(decorate, gui) end)

print("[Museum Empire] Premium Roblox-style UI + 3D catalog previews enabled")