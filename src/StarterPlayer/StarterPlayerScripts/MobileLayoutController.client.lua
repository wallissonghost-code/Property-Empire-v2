local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MOBILE_MAX_WIDTH = 1100
local TOOLBAR_BOTTOM = 12
local TOOLBAR_BUTTON_WIDTH = 82
local TOOLBAR_BUTTON_HEIGHT = 46
local TOOLBAR_GAP = 6

local function round(guiObject, radius)
	local corner = guiObject:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = guiObject
end

local function findButton(screenGui, name, textNeedle)
	if not screenGui then return nil end
	if name then
		local named = screenGui:FindFirstChild(name, true)
		if named and named:IsA("GuiButton") then return named end
	end
	if textNeedle then
		for _, d in ipairs(screenGui:GetDescendants()) do
			if d:IsA("TextButton") and string.find(string.upper(d.Text or ""), string.upper(textNeedle), 1, true) then
				return d
			end
		end
	end
	return nil
end

local function styleToolbarButton(button, slot, text)
	if not button then return end
	local totalWidth = TOOLBAR_BUTTON_WIDTH * 4 + TOOLBAR_GAP * 3
	local startX = -totalWidth / 2
	local x = startX + (slot - 1) * (TOOLBAR_BUTTON_WIDTH + TOOLBAR_GAP)
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, x + TOOLBAR_BUTTON_WIDTH / 2, 1, -TOOLBAR_BOTTOM)
	button.Size = UDim2.fromOffset(TOOLBAR_BUTTON_WIDTH, TOOLBAR_BUTTON_HEIGHT)
	button.Text = text
	button.TextSize = 11
	button.TextWrapped = false
	button.ZIndex = 30
	round(button, 12)
end

local function stylePanel(panel)
	if not panel or not panel:IsA("GuiObject") then return end
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.new(0.88, 0, 0.78, 0)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MinSize = Vector2.new(280, 300)
		limit.MaxSize = Vector2.new(680, 560)
	end
end

local function compactFoundationHud()
	local gui = playerGui:FindFirstChild("MuseumFoundationHUD")
	if not gui then return end
	local bar = gui:FindFirstChildWhichIsA("Frame")
	if not bar then return end
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 8)
	bar.Size = UDim2.new(0.72, 0, 0, 42)
	bar.ZIndex = 20

	local layout = bar:FindFirstChildOfClass("UIListLayout")
	if layout then layout.Padding = UDim.new(0, 5) end

	local order = {"Level", "Stars", "Prestige", "Rating"}
	local widths = {0.20, 0.25, 0.26, 0.25}
	for i, name in ipairs(order) do
		local card = bar:FindFirstChild(name)
		if card and card:IsA("Frame") then
			card.Size = UDim2.new(widths[i], -4, 0, 32)
			local label = card:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.TextSize = 10
				label.TextWrapped = true
			end
		end
	end
end

local function compactTopCash()
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Name ~= "MuseumFoundationHUD" then
			for _, d in ipairs(gui:GetDescendants()) do
				if d:IsA("TextLabel") and string.find(d.Text or "", "$", 1, true) then
					local parent = d.Parent
					if parent and parent:IsA("GuiObject") and parent.AbsoluteSize.X > 180 then
						parent.Size = UDim2.fromOffset(150, 40)
						parent.Position = UDim2.new(0, 12, 0, 8)
						d.TextSize = 12
						return
					end
				end
			end
		end
	end
end

local function setupDailyCard()
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
			if daily then break end
		end
	end
	if not daily then return end

	daily.AnchorPoint = Vector2.new(1, 0)
	daily.Position = UDim2.new(1, -12, 0, 8)
	daily.Size = UDim2.fromOffset(220, 82)
	daily.ZIndex = 25

	local toggle = daily:FindFirstChild("MobileCollapse")
	if not toggle then
		toggle = Instance.new("TextButton")
		toggle.Name = "MobileCollapse"
		toggle.AnchorPoint = Vector2.new(1, 0)
		toggle.Position = UDim2.new(1, -6, 0, 6)
		toggle.Size = UDim2.fromOffset(28, 28)
		toggle.BackgroundColor3 = Color3.fromRGB(39, 48, 60)
		toggle.TextColor3 = Color3.new(1, 1, 1)
		toggle.Font = Enum.Font.GothamBold
		toggle.TextSize = 14
		toggle.Text = "−"
		toggle.ZIndex = 40
		toggle.Parent = daily
		round(toggle, 8)

		local expanded = true
		toggle.Activated:Connect(function()
			expanded = not expanded
			for _, child in ipairs(daily:GetChildren()) do
				if child:IsA("GuiObject") and child ~= toggle then
					child.Visible = expanded
				end
			end
			if expanded then
				daily.Size = UDim2.fromOffset(220, 82)
				toggle.Text = "−"
			else
				daily.Size = UDim2.fromOffset(42, 42)
				toggle.Text = "🎯"
			end
		end)
	end

	for _, d in ipairs(daily:GetDescendants()) do
		if d:IsA("TextLabel") then d.TextSize = math.min(d.TextSize, 11) end
		if d:IsA("TextButton") and d ~= toggle then
			d.TextSize = math.min(d.TextSize, 10)
			d.Size = UDim2.new(1, -20, 0, 24)
		end
	end
end

local function applyMobile()
	local buildGui = playerGui:FindFirstChild("MuseumBuildUI")
	local opsGui = playerGui:FindFirstChild("MuseumOperationsUI")
	local missionsGui = playerGui:FindFirstChild("MuseumExpansionUI")
	local homeGui = playerGui:FindFirstChild("MuseumHomeButton")

	styleToolbarButton(findButton(buildGui, "OpenBuild", nil), 1, "🔨 CONSTRUIR")
	styleToolbarButton(findButton(opsGui, nil, "GESTÃO"), 2, "⚙ GESTÃO")
	styleToolbarButton(findButton(missionsGui, nil, "MISSÕES"), 3, "🎯 MISSÕES")
	styleToolbarButton(findButton(homeGui, "ReturnHome", nil), 4, "⌂ MUSEU")

	if buildGui then stylePanel(buildGui:FindFirstChild("BuildPanel", true)) end
	if opsGui then
		for _, d in ipairs(opsGui:GetChildren()) do
			if d:IsA("Frame") and d.Visible ~= nil then stylePanel(d) end
		end
	end
	if missionsGui then
		for _, d in ipairs(missionsGui:GetChildren()) do
			if d:IsA("Frame") then stylePanel(d) end
		end
	end

	compactFoundationHud()
	compactTopCash()
	setupDailyCard()
end

local function applyDesktop()
	-- Existing desktop scripts remain authoritative. This controller only overrides mobile layouts.
end

local function refreshLayout()
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if camera.ViewportSize.X <= MOBILE_MAX_WIDTH then
		applyMobile()
	else
		applyDesktop()
	end
end

playerGui.ChildAdded:Connect(function()
	task.defer(refreshLayout)
end)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.defer(refreshLayout)
end)

task.spawn(function()
	while task.wait(1.5) do
		refreshLayout()
	end
end)

task.defer(refreshLayout)
print("[Museum Empire] MobileLayoutController ready")
