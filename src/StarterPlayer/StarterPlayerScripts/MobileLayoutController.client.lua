local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
	Panel = Color3.fromRGB(18, 23, 31),
	Card = Color3.fromRGB(29, 36, 47),
	Card2 = Color3.fromRGB(36, 45, 58),
	Stroke = Color3.fromRGB(74, 101, 128),
	Text = Color3.fromRGB(245, 247, 250),
	Muted = Color3.fromRGB(164, 178, 195),
	Accent = Color3.fromRGB(54, 142, 234),
	Purple = Color3.fromRGB(105, 82, 164),
	Green = Color3.fromRGB(63, 137, 96),
}

local hudGui
local hud
local cashText
local levelText
local prestigeText
local ratingText
local starsText
local menuGui
local menuToggle
local homeButton
local tabDock
local dailyCollapsed = true

local function isMobile()
	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 9999
	return UserInputService.TouchEnabled or width <= 1100
end

local function corner(obj, radius)
	local c = obj:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = obj
end

local function stroke(obj, transparency)
	local s = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = COLORS.Stroke
	s.Transparency = transparency or 0.45
	s.Thickness = 1
	s.Parent = obj
end

local function formatMoney(value)
	local s = tostring(math.floor(tonumber(value) or 0))
	repeat
		local nextValue, count = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
		s = nextValue
	until count == 0
	return "$" .. s
end

local function hideLegacyTopHud()
	local foundation = playerGui:FindFirstChild("MuseumFoundationHUD")
	if foundation then foundation.Enabled = false end

	local empire = playerGui:FindFirstChild("MuseumEmpireUI")
	if empire then
		for _, child in ipairs(empire:GetChildren()) do
			if child:IsA("TextLabel") and string.find(child.Text or "", "$", 1, true) then
				child.Visible = false
			end
		end
	end
end

local function makeChip(parent, width)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(width, 0, 1, -8)
	frame.BackgroundColor3 = COLORS.Card
	frame.BackgroundTransparency = 0.05
	frame.Parent = parent
	corner(frame, 11)
	return frame
end

local function makeChipLabel(parent)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = COLORS.Text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function ensurePremiumHud()
	if hudGui and hudGui.Parent then return end
	local old = playerGui:FindFirstChild("MuseumMobilePremiumHUD")
	if old then old:Destroy() end

	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "MuseumMobilePremiumHUD"
	hudGui.ResetOnSpawn = false
	hudGui.IgnoreGuiInset = false
	hudGui.DisplayOrder = 20
	hudGui.Parent = playerGui

	hud = Instance.new("Frame")
	hud.Name = "PremiumTopHud"
	hud.AnchorPoint = Vector2.new(1, 0)
	hud.Position = UDim2.new(1, -12, 0, 8)
	hud.Size = UDim2.fromOffset(460, 48)
	hud.BackgroundColor3 = COLORS.Panel
	hud.BackgroundTransparency = 0.05
	hud.Parent = hudGui
	corner(hud, 14)
	stroke(hud, 0.5)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 5)
	layout.Parent = hud
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = hud

	cashText = makeChipLabel(makeChip(hud, 0.29))
	levelText = makeChipLabel(makeChip(hud, 0.16))
	prestigeText = makeChipLabel(makeChip(hud, 0.19))
	ratingText = makeChipLabel(makeChip(hud, 0.17))
	starsText = makeChipLabel(makeChip(hud, 0.16))
end

local function refreshPremiumHud()
	if not isMobile() then return end
	ensurePremiumHud()
	cashText.Text = "💰 " .. formatMoney(player:GetAttribute("Cash") or 0)
	levelText.Text = "MUSEU\nN" .. tostring(player:GetAttribute("MuseumLevel") or 1)
	prestigeText.Text = "PRESTÍGIO\n" .. tostring(player:GetAttribute("Prestige") or 0)
	local rating = tonumber(player:GetAttribute("MuseumRating")) or 0
	ratingText.Text = string.format("NOTA\n%.1f", rating)
	local stars = math.clamp(math.floor(tonumber(player:GetAttribute("MuseumStars")) or 1), 1, 5)
	starsText.Text = string.rep("★", stars) .. string.rep("☆", 5 - stars)

	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 800
	if width < 760 then
		hud.Size = UDim2.new(0.70, 0, 0, 44)
		hud.Position = UDim2.new(1, -8, 0, 6)
	else
		hud.Size = UDim2.fromOffset(460, 48)
		hud.Position = UDim2.new(1, -12, 0, 8)
	end
end

local function findButton(gui, name, needle)
	if not gui then return nil end
	if name then
		local found = gui:FindFirstChild(name, true)
		if found and found:IsA("GuiButton") then return found end
	end
	if needle then
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("TextButton") and string.find(string.upper(d.Text or ""), string.upper(needle), 1, true) then
				return d
			end
		end
	end
	return nil
end

local function findMainPanel(gui, preferredName)
	if not gui then return nil end
	if preferredName then
		local named = gui:FindFirstChild(preferredName, true)
		if named and named:IsA("Frame") then return named end
	end
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("Frame") then return child end
	end
	return nil
end

local function styleContentPanel(panel)
	if not panel then return end
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.49)
	panel.Size = UDim2.new(0.90, 0, 0.70, 0)
	panel.ZIndex = math.max(panel.ZIndex, 45)
	corner(panel, 16)
	stroke(panel, 0.55)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MinSize = Vector2.new(300, 300)
		limit.MaxSize = Vector2.new(760, 520)
	end
end

local function styleTab(button, color, label)
	if not button then return end
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.new()
	button.Size = UDim2.new(1/3, -5, 1, 0)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.04
	button.Text = label
	button.TextColor3 = COLORS.Text
	button.TextSize = 11
	button.TextWrapped = false
	button.Font = Enum.Font.GothamBold
	button.ZIndex = 62
	corner(button, 11)
end

local function closeOtherPanels(exceptPanel)
	local buildPanel = findMainPanel(playerGui:FindFirstChild("MuseumBuildUI"), "BuildPanel")
	local opsPanel = findMainPanel(playerGui:FindFirstChild("MuseumOperationsUI"))
	local missionsPanel = findMainPanel(playerGui:FindFirstChild("MuseumExpansionUI"))
	for _, panel in ipairs({buildPanel, opsPanel, missionsPanel}) do
		if panel and panel ~= exceptPanel then panel.Visible = false end
	end
end

local function ensureUnifiedMenu()
	if menuGui and menuGui.Parent then return end
	local old = playerGui:FindFirstChild("MuseumMobileHub")
	if old then old:Destroy() end

	menuGui = Instance.new("ScreenGui")
	menuGui.Name = "MuseumMobileHub"
	menuGui.ResetOnSpawn = false
	menuGui.IgnoreGuiInset = false
	menuGui.DisplayOrder = 60
	menuGui.Parent = playerGui

	menuToggle = Instance.new("TextButton")
	menuToggle.Name = "MainMenu"
	menuToggle.AnchorPoint = Vector2.new(0.5, 1)
	menuToggle.Position = UDim2.new(0.5, -60, 1, -12)
	menuToggle.Size = UDim2.fromOffset(116, 48)
	menuToggle.BackgroundColor3 = COLORS.Accent
	menuToggle.TextColor3 = COLORS.Text
	menuToggle.Font = Enum.Font.GothamBold
	menuToggle.TextSize = 12
	menuToggle.Text = "☰  MENU"
	menuToggle.Parent = menuGui
	corner(menuToggle, 13)
	stroke(menuToggle, 0.65)

	homeButton = findButton(playerGui:FindFirstChild("MuseumHomeButton"), "ReturnHome", nil)
	if homeButton then
		homeButton.Parent = menuGui
		homeButton.AnchorPoint = Vector2.new(0.5, 1)
		homeButton.Position = UDim2.new(0.5, 60, 1, -12)
		homeButton.Size = UDim2.fromOffset(116, 48)
		homeButton.BackgroundColor3 = Color3.fromRGB(35, 69, 108)
		homeButton.Text = "⌂  MUSEU"
		homeButton.TextSize = 12
		homeButton.ZIndex = 62
		corner(homeButton, 13)
	end

	tabDock = Instance.new("Frame")
	tabDock.Name = "TabDock"
	tabDock.AnchorPoint = Vector2.new(0.5, 1)
	tabDock.Position = UDim2.new(0.5, 0, 1, -66)
	tabDock.Size = UDim2.fromOffset(330, 44)
	tabDock.BackgroundColor3 = COLORS.Panel
	tabDock.BackgroundTransparency = 0.04
	tabDock.Visible = false
	tabDock.Parent = menuGui
	corner(tabDock, 14)
	stroke(tabDock, 0.5)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 5)
	layout.Parent = tabDock
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = tabDock

	local buildGui = playerGui:FindFirstChild("MuseumBuildUI")
	local opsGui = playerGui:FindFirstChild("MuseumOperationsUI")
	local missionsGui = playerGui:FindFirstChild("MuseumExpansionUI")
	local buildButton = findButton(buildGui, "OpenBuild", nil)
	local opsButton = findButton(opsGui, nil, "GESTÃO")
	local missionsButton = findButton(missionsGui, nil, "MISSÕES")

	if buildButton then buildButton.Parent = tabDock styleTab(buildButton, COLORS.Accent, "🔨 CONSTRUIR") end
	if opsButton then opsButton.Parent = tabDock styleTab(opsButton, Color3.fromRGB(58, 82, 105), "⚙ GESTÃO") end
	if missionsButton then missionsButton.Parent = tabDock styleTab(missionsButton, COLORS.Purple, "🎯 MISSÕES") end

	local buildPanel = findMainPanel(buildGui, "BuildPanel")
	local opsPanel = findMainPanel(opsGui)
	local missionsPanel = findMainPanel(missionsGui)
	styleContentPanel(buildPanel)
	styleContentPanel(opsPanel)
	styleContentPanel(missionsPanel)

	if buildButton then buildButton.Activated:Connect(function() task.defer(function() closeOtherPanels(buildPanel) tabDock.Visible = false end) end) end
	if opsButton then opsButton.Activated:Connect(function() task.defer(function() closeOtherPanels(opsPanel) tabDock.Visible = false end) end) end
	if missionsButton then missionsButton.Activated:Connect(function() task.defer(function() closeOtherPanels(missionsPanel) tabDock.Visible = false end) end) end

	menuToggle.Activated:Connect(function()
		tabDock.Visible = not tabDock.Visible
		if tabDock.Visible then closeOtherPanels(nil) end
	end)
end

local function collapseDailyCard()
	local gui = playerGui:FindFirstChild("MuseumWorldGameplayUI")
	if not gui then return end
	local daily
	for _, frame in ipairs(gui:GetChildren()) do
		if frame:IsA("Frame") then
			for _, d in ipairs(frame:GetDescendants()) do
				if d:IsA("TextLabel") and string.find(string.upper(d.Text or ""), "OBJETIVO DIÁRIO", 1, true) then
					daily = frame
					break
				end
			end
		end
		if daily then break end
	end
	if not daily then return end

	daily.AnchorPoint = Vector2.new(1, 0)
	daily.Position = UDim2.new(1, -12, 0, 62)
	daily.ZIndex = 31
	corner(daily, 12)
	stroke(daily, 0.6)

	local toggle = daily:FindFirstChild("MobileCollapse")
	if not toggle then
		toggle = Instance.new("TextButton")
		toggle.Name = "MobileCollapse"
		toggle.AnchorPoint = Vector2.new(1, 0)
		toggle.Position = UDim2.new(1, -5, 0, 5)
		toggle.Size = UDim2.fromOffset(34, 34)
		toggle.BackgroundColor3 = COLORS.Card2
		toggle.TextColor3 = COLORS.Text
		toggle.Font = Enum.Font.GothamBold
		toggle.TextSize = 15
		toggle.ZIndex = 40
		toggle.Parent = daily
		corner(toggle, 9)
		toggle.Activated:Connect(function()
			dailyCollapsed = not dailyCollapsed
			for _, child in ipairs(daily:GetChildren()) do
				if child:IsA("GuiObject") and child ~= toggle then child.Visible = not dailyCollapsed end
			end
			daily.Size = dailyCollapsed and UDim2.fromOffset(44, 44) or UDim2.fromOffset(238, 94)
			toggle.Text = dailyCollapsed and "🎯" or "−"
		end)
	end

	for _, child in ipairs(daily:GetChildren()) do
		if child:IsA("GuiObject") and child ~= toggle then child.Visible = not dailyCollapsed end
	end
	daily.Size = dailyCollapsed and UDim2.fromOffset(44, 44) or UDim2.fromOffset(238, 94)
	toggle.Text = dailyCollapsed and "🎯" or "−"
end

local function styleMuseumPanel()
	local empire = playerGui:FindFirstChild("MuseumEmpireUI")
	if not empire then return end
	for _, child in ipairs(empire:GetChildren()) do
		if child:IsA("Frame") then
			styleContentPanel(child)
		end
	end
end

local function applyMobile()
	hideLegacyTopHud()
	refreshPremiumHud()
	ensureUnifiedMenu()
	collapseDailyCard()
	styleMuseumPanel()
end

local function refresh()
	if not isMobile() then return end
	applyMobile()
end

for _, attr in ipairs({"Cash", "MuseumLevel", "Prestige", "MuseumRating", "MuseumStars"}) do
	player:GetAttributeChangedSignal(attr):Connect(function() task.defer(refreshPremiumHud) end)
end

playerGui.ChildAdded:Connect(function() task.delay(0.1, refresh) end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.defer(refresh) end)

task.spawn(function()
	while task.wait(2) do refresh() end
end)

task.defer(refresh)
print("[Museum Empire] Premium mobile HUD + unified tabbed menu ready")
