local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local COLORS = {
	Panel = Color3.fromRGB(18, 23, 31),
	Card = Color3.fromRGB(29, 36, 47),
	Stroke = Color3.fromRGB(74, 101, 128),
	Text = Color3.fromRGB(245, 247, 250),
	Accent = Color3.fromRGB(54, 142, 234),
	Purple = Color3.fromRGB(105, 82, 164),
	BlueGray = Color3.fromRGB(58, 82, 105),
	Home = Color3.fromRGB(35, 69, 108),
}

local hudGui
local hud
local cashText
local levelText
local prestigeText
local ratingText
local starsText
local topToggle
local topCollapsed = false
local dailyCollapsed = true
local topTween

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

local function addStroke(obj, transparency)
	local s = obj:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = COLORS.Stroke
	s.Transparency = transparency or 0.55
	s.Thickness = 1
	s.Parent = obj
end

local function formatMoney(value)
	local s = tostring(math.floor(tonumber(value) or 0))
	repeat
		local n, count = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
		s = n
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

local function makeChip(parent, width, name)
	local frame = Instance.new("Frame")
	frame.Name = name
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

local function setTopState(animated)
	if not hud or not topToggle then return end

	local camera = Workspace.CurrentCamera
	local width = camera and camera.ViewportSize.X or 800
	local cashChip = hud:FindFirstChild("CashChip")
	local levelChip = hud:FindFirstChild("LevelChip")
	local prestigeChip = hud:FindFirstChild("PrestigeChip")
	local ratingChip = hud:FindFirstChild("RatingChip")
	local starsChip = hud:FindFirstChild("StarsChip")

	if topCollapsed then
		if cashChip then cashChip.Visible = true cashChip.Size = UDim2.new(0.66, 0, 1, -8) end
		if levelChip then levelChip.Visible = false end
		if prestigeChip then prestigeChip.Visible = false end
		if ratingChip then ratingChip.Visible = false end
		if starsChip then starsChip.Visible = true starsChip.Size = UDim2.new(0.28, 0, 1, -8) end
		topToggle.Text = "‹"
		topToggle.TextSize = 23
	else
		if cashChip then cashChip.Visible = true cashChip.Size = UDim2.new(0.29, 0, 1, -8) end
		if levelChip then levelChip.Visible = true levelChip.Size = UDim2.new(0.16, 0, 1, -8) end
		if prestigeChip then prestigeChip.Visible = true prestigeChip.Size = UDim2.new(0.19, 0, 1, -8) end
		if ratingChip then ratingChip.Visible = true ratingChip.Size = UDim2.new(0.17, 0, 1, -8) end
		if starsChip then starsChip.Visible = true starsChip.Size = UDim2.new(0.16, 0, 1, -8) end
		topToggle.Text = "›"
		topToggle.TextSize = 23
	end

	local targetSize
	local targetPosition
	if topCollapsed then
		targetSize = UDim2.fromOffset(220, 44)
		targetPosition = UDim2.new(1, -52, 0, 8)
	elseif width < 760 then
		targetSize = UDim2.new(0.70, 0, 0, 44)
		targetPosition = UDim2.new(1, -48, 0, 6)
	else
		targetSize = UDim2.fromOffset(460, 48)
		targetPosition = UDim2.new(1, -52, 0, 8)
	end

	if topTween then topTween:Cancel() topTween = nil end
	if animated then
		topTween = TweenService:Create(hud, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = targetSize,
			Position = targetPosition,
		})
		topTween:Play()
	else
		hud.Size = targetSize
		hud.Position = targetPosition
	end
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
	hud.Position = UDim2.new(1, -52, 0, 8)
	hud.Size = UDim2.fromOffset(460, 48)
	hud.BackgroundColor3 = COLORS.Panel
	hud.BackgroundTransparency = 0.05
	hud.Parent = hudGui
	corner(hud, 14)
	addStroke(hud, 0.5)

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

	cashText = makeChipLabel(makeChip(hud, 0.29, "CashChip"))
	levelText = makeChipLabel(makeChip(hud, 0.16, "LevelChip"))
	prestigeText = makeChipLabel(makeChip(hud, 0.19, "PrestigeChip"))
	ratingText = makeChipLabel(makeChip(hud, 0.17, "RatingChip"))
	starsText = makeChipLabel(makeChip(hud, 0.16, "StarsChip"))

	topToggle = Instance.new("TextButton")
	topToggle.Name = "TopCollapseButton"
	topToggle.AnchorPoint = Vector2.new(1, 0)
	topToggle.Position = UDim2.new(1, -10, 0, 14)
	topToggle.Size = UDim2.fromOffset(34, 34)
	topToggle.BackgroundColor3 = COLORS.Card
	topToggle.BackgroundTransparency = 0.03
	topToggle.TextColor3 = COLORS.Text
	topToggle.Font = Enum.Font.GothamBold
	topToggle.Text = "›"
	topToggle.TextSize = 23
	topToggle.ZIndex = 35
	topToggle.Parent = hudGui
	corner(topToggle, 10)
	addStroke(topToggle, 0.55)

	topToggle.Activated:Connect(function()
		topCollapsed = not topCollapsed
		setTopState(true)
	end)
end

local function refreshPremiumHud()
	if not isMobile() then return end
	ensurePremiumHud()
	cashText.Text = "💰 " .. formatMoney(player:GetAttribute("Cash") or 0)
	levelText.Text = "MUSEU\nN" .. tostring(player:GetAttribute("MuseumLevel") or 1)
	prestigeText.Text = "PRESTÍGIO\n" .. tostring(player:GetAttribute("Prestige") or 0)
	ratingText.Text = string.format("NOTA\n%.1f", tonumber(player:GetAttribute("MuseumRating")) or 0)
	local stars = math.clamp(math.floor(tonumber(player:GetAttribute("MuseumStars")) or 1), 1, 5)
	starsText.Text = string.rep("★", stars) .. string.rep("☆", 5 - stars)
	setTopState(false)
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

local function styleBottomButton(button, slot, label, color)
	if not button then return end
	local buttonWidth = 82
	local gap = 6
	local total = buttonWidth * 4 + gap * 3
	local left = -total / 2
	local x = left + (slot - 1) * (buttonWidth + gap) + buttonWidth / 2

	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, x, 1, -12)
	button.Size = UDim2.fromOffset(buttonWidth, 46)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.04
	button.Text = label
	button.TextColor3 = COLORS.Text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextWrapped = false
	button.ZIndex = 60
	corner(button, 12)
	addStroke(button, 0.7)
end

local function findMainPanel(gui, preferredName)
	if not gui then return nil end
	if preferredName then
		local p = gui:FindFirstChild(preferredName, true)
		if p and p:IsA("Frame") then return p end
	end
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("Frame") then return child end
	end
	return nil
end

local function stylePanel(panel)
	if not panel then return end
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.49)
	panel.Size = UDim2.new(0.90, 0, 0.70, 0)
	panel.ZIndex = math.max(panel.ZIndex, 45)
	corner(panel, 16)
	addStroke(panel, 0.55)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MinSize = Vector2.new(300, 300)
		limit.MaxSize = Vector2.new(760, 520)
	end
end

local function styleBottomBar()
	local buildGui = playerGui:FindFirstChild("MuseumBuildUI")
	local opsGui = playerGui:FindFirstChild("MuseumOperationsUI")
	local missionsGui = playerGui:FindFirstChild("MuseumExpansionUI")
	local homeGui = playerGui:FindFirstChild("MuseumHomeButton")

	styleBottomButton(findButton(buildGui, "OpenBuild", nil), 1, "🔨 CONSTRUIR", COLORS.Accent)
	styleBottomButton(findButton(opsGui, nil, "GESTÃO"), 2, "⚙ GESTÃO", COLORS.BlueGray)
	styleBottomButton(findButton(missionsGui, nil, "MISSÕES"), 3, "🎯 MISSÕES", COLORS.Purple)
	styleBottomButton(findButton(homeGui, "ReturnHome", nil), 4, "⌂ MUSEU", COLORS.Home)

	stylePanel(findMainPanel(buildGui, "BuildPanel"))
	stylePanel(findMainPanel(opsGui))
	stylePanel(findMainPanel(missionsGui))
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
	addStroke(daily, 0.6)

	local toggle = daily:FindFirstChild("MobileCollapse")
	if not toggle then
		toggle = Instance.new("TextButton")
		toggle.Name = "MobileCollapse"
		toggle.AnchorPoint = Vector2.new(1, 0)
		toggle.Position = UDim2.new(1, -5, 0, 5)
		toggle.Size = UDim2.fromOffset(34, 34)
		toggle.BackgroundColor3 = COLORS.Card
		toggle.TextColor3 = COLORS.Text
		toggle.Font = Enum.Font.GothamBold
		toggle.TextSize = 15
		toggle.ZIndex = 40
		toggle.Parent = daily
		corner(toggle, 9)
		toggle.Activated:Connect(function()
			dailyCollapsed = not dailyCollapsed
			for _, child in ipairs(daily:GetChildren()) do
				if child:IsA("GuiObject") and child ~= toggle then
					child.Visible = not dailyCollapsed
				end
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

local function removeObsoleteHub()
	local hub = playerGui:FindFirstChild("MuseumMobileHub")
	if hub then hub:Destroy() end
end

local function applyMobile()
	removeObsoleteHub()
	hideLegacyTopHud()
	refreshPremiumHud()
	styleBottomBar()
	collapseDailyCard()
end

for _, attr in ipairs({"Cash", "MuseumLevel", "Prestige", "MuseumRating", "MuseumStars"}) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		task.defer(refreshPremiumHud)
	end)
end

playerGui.ChildAdded:Connect(function()
	task.delay(0.1, function()
		if isMobile() then applyMobile() end
	end)
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(function()
		if isMobile() then applyMobile() end
	end)
end)

task.spawn(function()
	while task.wait(1.5) do
		if isMobile() then applyMobile() end
	end
end)

task.defer(function()
	if isMobile() then applyMobile() end
end)

print("[Museum Empire] MobileLayoutController ready — retractable top HUD + four-button toolbar")
