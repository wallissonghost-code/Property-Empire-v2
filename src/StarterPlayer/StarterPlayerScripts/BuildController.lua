local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared:WaitForChild("BuildConfig"))
local BuildCollision = require(Shared:WaitForChild("BuildCollision"))
local BuildSnap = require(Shared:WaitForChild("BuildSnap"))

local BuildController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getBuildState = remotes:WaitForChild("GetBuildState")
local placeBuildPiece = remotes:WaitForChild("PlaceBuildPiece")
local removeBuildPiece = remotes:WaitForChild("RemoveBuildPiece")
local undoBuildPiece = remotes:WaitForChild("UndoBuildPiece")

local buildMode = false
local removeMode = false
local selectedPieceType = "Floor"
local selectedLot = nil
local currentLevel = 0
local currentRotation = 0
local preview = nil
local previewValid = false
local previewGridX = 0
local previewGridZ = 0
local previewBlockedReason = ""
local currentConnectionKind = "Grid"
local placing = false
local removing = false
local ownedLots = {}
local removalTarget = nil
local removalTargetId = nil
local visualsFolder = nil
local levelGuide = nil
local removalHighlight = nil
local previewHighlight = nil
local previewBillboard = nil
local previewBillboardLabel = nil

local gui = nil
local panel = nil
local panelScale = nil
local toggleButton = nil
local statusLabel = nil
local levelLabel = nil
local cashLabel = nil
local modeLabel = nil
local snapBadge = nil
local selectedLabel = nil
local placeButton = nil
local removeModeButton = nil
local selectionButtons = {}
local catalogTab = "Basic"

local cachedEntries = {}
local cachedEntriesLotId = nil
local cachedEntriesAt = 0
local ENTRY_CACHE_SECONDS = 0.10

local COLORS = {
	Panel = Color3.fromRGB(18, 22, 29),
	PanelRaised = Color3.fromRGB(27, 33, 42),
	PanelSoft = Color3.fromRGB(34, 41, 51),
	Stroke = Color3.fromRGB(74, 87, 104),
	Text = Color3.fromRGB(244, 247, 250),
	Muted = Color3.fromRGB(152, 166, 182),
	Green = Color3.fromRGB(75, 214, 137),
	GreenDark = Color3.fromRGB(38, 122, 78),
	Red = Color3.fromRGB(235, 86, 94),
	RedDark = Color3.fromRGB(125, 54, 59),
	Blue = Color3.fromRGB(70, 139, 220),
	Gold = Color3.fromRGB(220, 176, 78),
	GoldDark = Color3.fromRGB(98, 76, 36),
}

local function formatMoney(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	local formatted = text
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1.%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return "$" .. formatted
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.Stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function makePadding(parent, left, right, top, bottom)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left or 0)
	padding.PaddingRight = UDim.new(0, right or 0)
	padding.PaddingTop = UDim.new(0, top or 0)
	padding.PaddingBottom = UDim.new(0, bottom or 0)
	padding.Parent = parent
	return padding
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = COLORS.PanelSoft
	button.TextColor3 = COLORS.Text
	button.Text = text
	button.TextSize = 14
	button.TextWrapped = true
	button.Font = Enum.Font.GothamSemibold
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = parent
	makeCorner(button, 10)
	makeStroke(button, COLORS.Stroke, 1, 0.25)
	return button
end

local function makeLabel(parent, text, size, position, textSize, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = COLORS.Text
	label.TextSize = textSize or 13
	label.Font = font or Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function isTouchDevice()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function setStatus(text, isError)
	if not statusLabel then
		return
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = isError and Color3.fromRGB(255, 151, 151) or Color3.fromRGB(205, 216, 228)
end

local function updateCashLabel()
	if cashLabel then
		cashLabel.Text = "SALDO  " .. formatMoney(player:GetAttribute("Cash") or 0)
	end
end

local function updateLevelLabel()
	if levelLabel then
		levelLabel.Text = string.format("ANDAR %d  ·  %d STUDS", currentLevel + 1, currentLevel * BuildConfig.LevelHeight)
	end
end

local function updateModeVisuals()
	if modeLabel then
		modeLabel.Text = removeMode and "MODO REMOÇÃO" or "MODO CONSTRUÇÃO"
		modeLabel.TextColor3 = removeMode and Color3.fromRGB(255, 170, 170) or Color3.fromRGB(146, 225, 180)
	end

	if removeModeButton then
		if isTouchDevice() then
			removeModeButton.Text = removeMode and "VOLTAR A CONSTRUIR" or "REMOVER PEÇA"
		else
			removeModeButton.Text = removeMode and "VOLTAR A CONSTRUIR [X]" or "REMOVER PEÇA [X]"
		end
		removeModeButton.BackgroundColor3 = removeMode and Color3.fromRGB(142, 60, 66) or Color3.fromRGB(74, 48, 52)
	end
end

local function setCatalogTab(tabName)
	catalogTab = tabName
	for pieceType, button in pairs(selectionButtons) do
		local spec = BuildConfig.Catalog[pieceType]
		button.Visible = spec ~= nil and spec.Category == catalogTab
	end

	local basicTab = panel and panel:FindFirstChild("BasicTab", true)
	local premiumTab = panel and panel:FindFirstChild("PremiumTab", true)
	if basicTab and basicTab:IsA("TextButton") then
		basicTab.BackgroundColor3 = catalogTab == "Basic" and COLORS.Blue or COLORS.PanelSoft
	end
	if premiumTab and premiumTab:IsA("TextButton") then
		premiumTab.BackgroundColor3 = catalogTab == "Premium" and COLORS.GoldDark or COLORS.PanelSoft
	end
end

local function updateSelectionVisuals()
	for pieceType, button in pairs(selectionButtons) do
		local spec = BuildConfig.Catalog[pieceType]
		if pieceType == selectedPieceType and not removeMode then
			if spec and spec.Category == "Premium" then
				button.BackgroundColor3 = COLORS.GoldDark
			else
				button.BackgroundColor3 = Color3.fromRGB(53, 107, 164)
			end
		elseif spec and spec.Category == "Premium" then
			button.BackgroundColor3 = Color3.fromRGB(58, 49, 33)
		else
			button.BackgroundColor3 = COLORS.PanelSoft
		end
	end
end

local function selectPiece(pieceType)
	local spec = BuildConfig.Catalog[pieceType]
	if not spec then
		return
	end

	selectedPieceType = pieceType
	removeMode = false
	catalogTab = spec.Category
	setCatalogTab(catalogTab)
	updateModeVisuals()
	updateSelectionVisuals()

	local priceText = (spec.Price or 0) > 0 and formatMoney(spec.Price) or "GRÁTIS"
	if selectedLabel then
		selectedLabel.Text = string.format("%s   ·   %s", string.upper(spec.DisplayName), priceText)
	end
	setStatus("Mova a peça até o ponto desejado. O encaixe magnético cuida do alinhamento.", false)

	if preview then
		preview:Destroy()
		preview = nil
	end
end

local function updateResponsiveScale()
	if not panelScale then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local widthScale = math.max(0.62, math.min(1, (viewport.X - 20) / 420))
	local heightScale = math.max(0.62, math.min(1, (viewport.Y - 20) / 620))
	panelScale.Scale = math.min(widthScale, heightScale)
end

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PropertyEmpireBuildGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 25
	gui.Parent = player:WaitForChild("PlayerGui")

	toggleButton = makeButton(gui, "CONSTRUIR", UDim2.fromOffset(184, 50), UDim2.new(1, -198, 1, -68))
	toggleButton.AnchorPoint = Vector2.new(0, 0)
	toggleButton.BackgroundColor3 = Color3.fromRGB(46, 111, 170)
	toggleButton.TextSize = 15

	local toggleGradient = Instance.new("UIGradient")
	toggleGradient.Rotation = 90
	toggleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(61, 139, 204)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(39, 91, 145)),
	})
	toggleGradient.Parent = toggleButton

	panel = Instance.new("Frame")
	panel.Name = "BuildPanel"
	panel.Size = UDim2.fromOffset(420, 620)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -10, 0.5, 0)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	makeCorner(panel, 16)
	makeStroke(panel, Color3.fromRGB(86, 102, 122), 1.2, 0.08)

	panelScale = Instance.new("UIScale")
	panelScale.Scale = 1
	panelScale.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 68)
	header.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
	header.BorderSizePixel = 0
	header.Parent = panel
	makeCorner(header, 16)

	local headerMask = Instance.new("Frame")
	headerMask.Size = UDim2.new(1, 0, 0, 18)
	headerMask.Position = UDim2.new(0, 0, 1, -18)
	headerMask.BackgroundColor3 = header.BackgroundColor3
	headerMask.BorderSizePixel = 0
	headerMask.Parent = header

	makeLabel(header, "CONSTRUÇÃO PREMIUM", UDim2.fromOffset(230, 28), UDim2.fromOffset(18, 10), 18, Enum.Font.GothamBold)
	local subtitle = makeLabel(header, "SMART SNAP · V3", UDim2.fromOffset(180, 18), UDim2.fromOffset(18, 39), 10, Enum.Font.GothamBold)
	subtitle.TextColor3 = Color3.fromRGB(115, 203, 157)

	cashLabel = makeLabel(header, "", UDim2.fromOffset(155, 28), UDim2.new(1, -173, 0, 10), 12, Enum.Font.GothamBold)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.TextColor3 = Color3.fromRGB(125, 229, 165)

	modeLabel = makeLabel(panel, "MODO CONSTRUÇÃO", UDim2.fromOffset(190, 22), UDim2.fromOffset(18, 78), 11, Enum.Font.GothamBold)
	snapBadge = makeLabel(panel, "SMART SNAP", UDim2.fromOffset(180, 24), UDim2.new(1, -198, 0, 77), 11, Enum.Font.GothamBold)
	snapBadge.TextXAlignment = Enum.TextXAlignment.Right
	snapBadge.TextColor3 = Color3.fromRGB(124, 217, 164)

	statusLabel = makeLabel(panel, "Selecione uma peça", UDim2.new(1, -36, 0, 44), UDim2.fromOffset(18, 103), 12, Enum.Font.Gotham)
	statusLabel.TextWrapped = true
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top

	selectedLabel = makeLabel(panel, "PISO   ·   GRÁTIS", UDim2.new(1, -36, 0, 30), UDim2.fromOffset(18, 146), 12, Enum.Font.GothamBold)
	selectedLabel.TextColor3 = Color3.fromRGB(226, 232, 240)

	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -36, 0, 38)
	tabs.Position = UDim2.fromOffset(18, 181)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel

	local basicTab = makeButton(tabs, "BÁSICO", UDim2.new(0.5, -5, 1, 0), UDim2.new(0, 0, 0, 0))
	basicTab.Name = "BasicTab"
	basicTab.BackgroundColor3 = COLORS.Blue
	basicTab.TextSize = 12

	local premiumTab = makeButton(tabs, "★ PREMIUM", UDim2.new(0.5, -5, 1, 0), UDim2.new(0.5, 5, 0, 0))
	premiumTab.Name = "PremiumTab"
	premiumTab.BackgroundColor3 = COLORS.PanelSoft
	premiumTab.TextColor3 = Color3.fromRGB(250, 224, 164)
	premiumTab.TextSize = 12

	local catalog = Instance.new("ScrollingFrame")
	catalog.Name = "Catalog"
	catalog.Size = UDim2.new(1, -36, 0, 196)
	catalog.Position = UDim2.fromOffset(18, 227)
	catalog.BackgroundColor3 = Color3.fromRGB(22, 28, 36)
	catalog.BorderSizePixel = 0
	catalog.ScrollBarThickness = 4
	catalog.ScrollBarImageColor3 = Color3.fromRGB(96, 112, 132)
	catalog.AutomaticCanvasSize = Enum.AutomaticSize.Y
	catalog.CanvasSize = UDim2.new()
	catalog.Parent = panel
	makeCorner(catalog, 12)
	makeStroke(catalog, Color3.fromRGB(60, 72, 88), 1, 0.35)
	makePadding(catalog, 8, 8, 8, 8)

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -5, 0, 58)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = catalog

	for order, pieceType in ipairs(BuildConfig.CatalogOrder) do
		local spec = BuildConfig.Catalog[pieceType]
		if spec then
			local priceText = (spec.Price or 0) > 0 and formatMoney(spec.Price) or "GRÁTIS"
			local prefix = spec.Category == "Premium" and "★ " or ""
			local button = makeButton(catalog, prefix .. spec.DisplayName .. "\n" .. priceText, UDim2.new(), UDim2.new())
			button.LayoutOrder = order
			button.TextSize = 12
			selectionButtons[pieceType] = button
			button.Activated:Connect(function()
				selectPiece(pieceType)
			end)
		end
	end

	basicTab.Activated:Connect(function()
		setCatalogTab("Basic")
	end)
	premiumTab.Activated:Connect(function()
		setCatalogTab("Premium")
	end)

	local levelRow = Instance.new("Frame")
	levelRow.Size = UDim2.new(1, -36, 0, 42)
	levelRow.Position = UDim2.fromOffset(18, 432)
	levelRow.BackgroundTransparency = 1
	levelRow.Parent = panel

	local downText = isTouchDevice() and "− ANDAR" or "− ANDAR [Q]"
	local upText = isTouchDevice() and "+ ANDAR" or "+ ANDAR [E]"
	local downButton = makeButton(levelRow, downText, UDim2.fromOffset(100, 42), UDim2.new())
	local upButton = makeButton(levelRow, upText, UDim2.fromOffset(100, 42), UDim2.new(1, -100, 0, 0))

	levelLabel = makeLabel(levelRow, "", UDim2.new(1, -216, 1, 0), UDim2.fromOffset(108, 0), 11, Enum.Font.GothamBold)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center

	local rotateText = isTouchDevice() and "ROTACIONAR 90°" or "ROTACIONAR 90° [R]"
	local rotateButton = makeButton(panel, rotateText, UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 482))

	removeModeButton = makeButton(
		panel,
		isTouchDevice() and "REMOVER PEÇA" or "REMOVER PEÇA [X]",
		UDim2.new(0.5, -23, 0, 42),
		UDim2.fromOffset(18, 532)
	)
	removeModeButton.BackgroundColor3 = Color3.fromRGB(74, 48, 52)

	local undoText = isTouchDevice() and "DESFAZER" or "DESFAZER [Z]"
	local undoButton = makeButton(
		panel,
		undoText,
		UDim2.new(0.5, -23, 0, 42),
		UDim2.new(0.5, 5, 0, 532)
	)

	placeButton = makeButton(panel, "COLOCAR PEÇA", UDim2.new(1, -36, 0, 38), UDim2.fromOffset(18, 578))
	placeButton.BackgroundColor3 = COLORS.GreenDark
	placeButton.TextSize = 13

	local placeGradient = Instance.new("UIGradient")
	placeGradient.Name = "PlaceGradient"
	placeGradient.Rotation = 90
	placeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(64, 163, 107)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 116, 78)),
	})
	placeGradient.Parent = placeButton

	downButton.Activated:Connect(function()
		currentLevel = math.max(0, currentLevel - 1)
		updateLevelLabel()
	end)
	upButton.Activated:Connect(function()
		currentLevel = math.min(BuildConfig.MaxLevels - 1, currentLevel + 1)
		updateLevelLabel()
	end)
	rotateButton.Activated:Connect(function()
		currentRotation = (currentRotation + 1) % 4
	end)
	removeModeButton.Activated:Connect(function()
		removeMode = not removeMode
		updateModeVisuals()
		updateSelectionVisuals()
		setStatus(removeMode and "Aponte para uma peça do seu lote e confirme a remoção." or "Construção reativada.", false)
	end)
	undoButton.Activated:Connect(function()
		BuildController:UndoLastPlacement()
	end)
	placeButton.Activated:Connect(function()
		if removeMode then
			BuildController:RemoveCurrentTarget()
		else
			BuildController:PlaceCurrentPreview()
		end
	end)

	updateCashLabel()
	updateSelectionVisuals()
	updateLevelLabel()
	updateModeVisuals()
	setCatalogTab("Basic")
	updateResponsiveScale()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveScale)
	end
end

local function clearEntriesCache()
	cachedEntries = {}
	cachedEntriesLotId = nil
	cachedEntriesAt = 0
end

local function ensureVisualsFolder()
	if visualsFolder then
		return
	end

	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "PropertyEmpireLocalBuildVisuals"
	visualsFolder.Parent = workspace

	levelGuide = Instance.new("Part")
	levelGuide.Name = "LevelGuide"
	levelGuide.Anchored = true
	levelGuide.CanCollide = false
	levelGuide.CanTouch = false
	levelGuide.CanQuery = false
	levelGuide.Material = Enum.Material.Neon
	levelGuide.Color = Color3.fromRGB(67, 153, 217)
	levelGuide.Transparency = 0.95
	levelGuide.CastShadow = false
	levelGuide.Parent = visualsFolder

	removalHighlight = Instance.new("Highlight")
	removalHighlight.Name = "RemovalHighlight"
	removalHighlight.FillColor = Color3.fromRGB(235, 72, 72)
	removalHighlight.FillTransparency = 0.60
	removalHighlight.OutlineColor = Color3.fromRGB(255, 214, 214)
	removalHighlight.OutlineTransparency = 0
	removalHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	removalHighlight.Enabled = false
	removalHighlight.Parent = visualsFolder

	previewHighlight = Instance.new("Highlight")
	previewHighlight.Name = "PremiumPreviewHighlight"
	previewHighlight.FillTransparency = 1
	previewHighlight.OutlineTransparency = 0
	previewHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	previewHighlight.Enabled = false
	previewHighlight.Parent = visualsFolder

	mouse.TargetFilter = visualsFolder
end

local function destroyPreview()
	if preview then
		preview:Destroy()
		preview = nil
	end
	if previewHighlight then
		previewHighlight.Enabled = false
		previewHighlight.Adornee = nil
	end
	previewBillboard = nil
	previewBillboardLabel = nil
end

local function destroyVisuals()
	preview = nil
	levelGuide = nil
	removalHighlight = nil
	previewHighlight = nil
	previewBillboard = nil
	previewBillboardLabel = nil
	if visualsFolder then
		visualsFolder:Destroy()
		visualsFolder = nil
	end
	mouse.TargetFilter = nil
	removalTarget = nil
	removalTargetId = nil
	clearEntriesCache()
end

local function createPreview()
	destroyPreview()
	ensureVisualsFolder()

	local spec = BuildConfig.Catalog[selectedPieceType]
	if not spec then
		return
	end

	preview = Instance.new("Part")
	preview.Name = "BuildPreview"
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanTouch = false
	preview.CanQuery = false
	preview.Size = spec.Size
	preview.Material = Enum.Material.ForceField
	preview.Transparency = 0.42
	preview.CastShadow = false
	preview.Parent = visualsFolder

	previewHighlight.Adornee = preview
	previewHighlight.Enabled = true

	previewBillboard = Instance.new("BillboardGui")
	previewBillboard.Name = "SnapStatus"
	previewBillboard.Size = UDim2.fromOffset(150, 34)
	previewBillboard.StudsOffset = Vector3.new(0, spec.Size.Y / 2 + 1.5, 0)
	previewBillboard.AlwaysOnTop = true
	previewBillboard.LightInfluence = 0
	previewBillboard.Parent = preview

	previewBillboardLabel = Instance.new("TextLabel")
	previewBillboardLabel.Size = UDim2.fromScale(1, 1)
	previewBillboardLabel.BackgroundColor3 = Color3.fromRGB(17, 22, 28)
	previewBillboardLabel.BackgroundTransparency = 0.12
	previewBillboardLabel.TextColor3 = Color3.fromRGB(236, 243, 248)
	previewBillboardLabel.Text = "SMART SNAP"
	previewBillboardLabel.TextSize = 11
	previewBillboardLabel.Font = Enum.Font.GothamBold
	previewBillboardLabel.Parent = previewBillboard
	makeCorner(previewBillboardLabel, 8)
	makeStroke(previewBillboardLabel, Color3.fromRGB(92, 112, 134), 1, 0.15)
end

local function chooseNearestOwnedLot()
	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local lotsFolder = world and world:FindFirstChild("Lots")
	if not lotsFolder then
		selectedLot = nil
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local best = nil
	local bestDistance = math.huge

	for _, lotId in ipairs(ownedLots) do
		local lot = lotsFolder:FindFirstChild(lotId)
		if lot and lot:IsA("BasePart") and lot:GetAttribute("OwnerUserId") == player.UserId then
			local distance = root and (root.Position - lot.Position).Magnitude or 0
			if distance < bestDistance then
				best = lot
				bestDistance = distance
			end
		end
	end

	selectedLot = best
	clearEntriesCache()
end

local function refreshState()
	local success, state = pcall(function()
		return getBuildState:InvokeServer()
	end)

	if not success or type(state) ~= "table" then
		ownedLots = {}
		selectedLot = nil
		setStatus("Não foi possível carregar seus lotes.", true)
		return false
	end

	ownedLots = type(state.OwnedLots) == "table" and state.OwnedLots or {}
	chooseNearestOwnedLot()
	updateCashLabel()

	if not selectedLot then
		setStatus("Compre um lote antes de construir.", true)
		return false
	end

	setStatus(string.format("Construindo em %s · Smart Snap ativo.", selectedLot.Name), false)
	return true
end

local function readPlacedEntries(forceRefresh)
	if not selectedLot then
		return {}
	end

	local now = os.clock()
	if not forceRefresh
		and cachedEntriesLotId == selectedLot.Name
		and now - cachedEntriesAt < ENTRY_CACHE_SECONDS
	then
		return cachedEntries
	end

	local entries = {}
	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local builds = world and world:FindFirstChild("Builds")
	local folder = builds and builds:FindFirstChild(selectedLot.Name)
	if folder then
		for _, root in ipairs(folder:GetChildren()) do
			local pieceType = root:GetAttribute("PieceType")
			local gridX = root:GetAttribute("GridX")
			local gridZ = root:GetAttribute("GridZ")
			local level = root:GetAttribute("Level")
			local rotation = root:GetAttribute("Rotation")
			if type(pieceType) == "string"
				and type(gridX) == "number"
				and type(gridZ) == "number"
				and type(level) == "number"
				and type(rotation) == "number"
			then
				table.insert(entries, {
					Type = pieceType,
					GridX = gridX,
					GridZ = gridZ,
					Level = level,
					Rotation = rotation,
				})
			end
		end
	end

	cachedEntries = entries
	cachedEntriesLotId = selectedLot.Name
	cachedEntriesAt = now
	return entries
end

local function updateLevelGuide()
	if not levelGuide or not selectedLot then
		return
	end
	levelGuide.Size = Vector3.new(selectedLot.Size.X, 0.12, selectedLot.Size.Z)
	levelGuide.CFrame = selectedLot.CFrame
		* CFrame.new(0, selectedLot.Size.Y / 2 + currentLevel * BuildConfig.LevelHeight + 0.08, 0)
	levelGuide.Transparency = currentLevel == 0 and 0.96 or 0.90
end

local function findBuildRoot(target)
	if not target or not selectedLot then
		return nil
	end

	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local builds = world and world:FindFirstChild("Builds")
	local lotFolder = builds and builds:FindFirstChild(selectedLot.Name)
	if not lotFolder or not target:IsDescendantOf(lotFolder) then
		return nil
	end

	local cursor = target
	while cursor and cursor ~= lotFolder do
		local pieceId = cursor:GetAttribute("BuildPieceId")
		if type(pieceId) == "string" and pieceId ~= "" then
			return cursor
		end
		cursor = cursor.Parent
	end
	return nil
end

local function updateRemovalTarget()
	if not removalHighlight then
		return
	end

	if not buildMode or not removeMode or not selectedLot then
		removalTarget = nil
		removalTargetId = nil
		removalHighlight.Enabled = false
		removalHighlight.Adornee = nil
		return
	end

	local root = findBuildRoot(mouse.Target)
	removalTarget = root
	removalTargetId = root and root:GetAttribute("BuildPieceId") or nil
	removalHighlight.Adornee = root
	removalHighlight.Enabled = root ~= nil
end

local function setPreviewVisual(valid, connectionKind, reason)
	if not preview then
		return
	end

	local magnetic = connectionKind ~= nil and connectionKind ~= "Grid"
	local goodColor = magnetic and Color3.fromRGB(74, 222, 163) or Color3.fromRGB(76, 190, 232)
	local color = valid and goodColor or COLORS.Red

	preview.Color = color
	preview.Transparency = valid and 0.38 or 0.55

	if previewHighlight then
		previewHighlight.OutlineColor = color
		previewHighlight.FillColor = color
		previewHighlight.FillTransparency = valid and 0.86 or 0.80
	end

	if previewBillboardLabel then
		if not valid then
			previewBillboardLabel.Text = "BLOQUEADO"
			previewBillboardLabel.TextColor3 = Color3.fromRGB(255, 181, 181)
			previewBillboardLabel.BackgroundColor3 = Color3.fromRGB(73, 31, 35)
		elseif magnetic then
			previewBillboardLabel.Text = "ENCAIXE MAGNÉTICO ✓"
			previewBillboardLabel.TextColor3 = Color3.fromRGB(190, 255, 219)
			previewBillboardLabel.BackgroundColor3 = Color3.fromRGB(25, 69, 49)
		else
			previewBillboardLabel.Text = "GRADE DE CONSTRUÇÃO"
			previewBillboardLabel.TextColor3 = Color3.fromRGB(204, 232, 255)
			previewBillboardLabel.BackgroundColor3 = Color3.fromRGB(28, 53, 75)
		end
	end

	if snapBadge then
		if not valid then
			snapBadge.Text = reason ~= "" and string.upper(reason) or "BLOQUEADO"
			snapBadge.TextColor3 = Color3.fromRGB(255, 151, 151)
		elseif magnetic then
			snapBadge.Text = "ENCAIXE MAGNÉTICO"
			snapBadge.TextColor3 = Color3.fromRGB(124, 230, 173)
		else
			snapBadge.Text = "GRADE INTELIGENTE"
			snapBadge.TextColor3 = Color3.fromRGB(131, 202, 247)
		end
	end

	if placeButton then
		placeButton.BackgroundColor3 = valid and COLORS.GreenDark or COLORS.RedDark
		placeButton.Text = valid and "COLOCAR PEÇA" or "POSIÇÃO BLOQUEADA"
	end
end

local function updatePreview()
	if not buildMode or not selectedLot then
		previewValid = false
		if preview then
			preview.Transparency = 1
		end
		return
	end

	ensureVisualsFolder()
	updateLevelGuide()
	updateRemovalTarget()

	if removeMode then
		previewValid = false
		if preview then
			preview.Transparency = 1
		end
		if previewHighlight then
			previewHighlight.Enabled = false
		end
		if placeButton then
			placeButton.Text = removalTarget and "REMOVER SELECIONADA" or "APONTE PARA UMA PEÇA"
			placeButton.BackgroundColor3 = COLORS.RedDark
		end
		return
	end

	local spec = BuildConfig.Catalog[selectedPieceType]
	if not spec then
		return
	end

	if not preview or preview.Size ~= spec.Size then
		createPreview()
	end
	if previewHighlight then
		previewHighlight.Enabled = true
	end

	local localHit = selectedLot.CFrame:PointToObjectSpace(mouse.Hit.Position)
	local rawGridX = math.round(localHit.X / BuildConfig.GridSize)
	local rawGridZ = math.round(localHit.Z / BuildConfig.GridSize)
	local rawLocalX = rawGridX * BuildConfig.GridSize
	local rawLocalZ = rawGridZ * BuildConfig.GridSize

	local entries = readPlacedEntries(false)
	local snapped = BuildSnap.SnapLocalPosition(
		BuildConfig,
		selectedPieceType,
		currentRotation,
		rawLocalX,
		rawLocalZ,
		entries,
		currentLevel
	)

	if not snapped then
		previewValid = false
		previewBlockedReason = "Posição inválida"
		setPreviewVisual(false, "Grid", previewBlockedReason)
		return
	end

	previewGridX = snapped.GridX
	previewGridZ = snapped.GridZ
	currentConnectionKind = snapped.ConnectionKind or "Grid"

	local localY = selectedLot.Size.Y / 2 + currentLevel * BuildConfig.LevelHeight + spec.Size.Y / 2
	preview.CFrame = selectedLot.CFrame
		* CFrame.new(snapped.LocalX, localY, snapped.LocalZ)
		* CFrame.Angles(0, math.rad(currentRotation * 90), 0)

	local candidate = BuildCollision.MakeDescriptor(
		BuildConfig,
		selectedPieceType,
		previewGridX,
		previewGridZ,
		currentLevel,
		currentRotation
	)

	previewValid = candidate ~= nil and BuildCollision.IsInsideLot(BuildConfig, selectedLot, candidate)
	previewBlockedReason = ""
	if not previewValid then
		previewBlockedReason = "Fora do lote"
	else
		local conflict = BuildCollision.HasConflict(BuildConfig, candidate, entries)
		if conflict then
			previewValid = false
			previewBlockedReason = "Espaço ocupado"
		end
	end

	preview:SetAttribute("SnapGridX", previewGridX)
	preview:SetAttribute("SnapGridZ", previewGridZ)
	preview:SetAttribute("SnapBlocked", not previewValid)
	preview:SetAttribute("SnapConnectionKind", currentConnectionKind)
	setPreviewVisual(previewValid, currentConnectionKind, previewBlockedReason)
end

function BuildController:PlaceCurrentPreview()
	if not buildMode or removeMode or placing then
		return
	end
	if not selectedLot then
		setStatus("Nenhum lote seu foi encontrado.", true)
		return
	end
	if not previewValid then
		setStatus(previewBlockedReason ~= "" and previewBlockedReason or "Essa posição não pode receber a peça.", true)
		return
	end

	local spec = BuildConfig.Catalog[selectedPieceType]
	placing = true
	if placeButton then
		placeButton.Text = "CONFIRMANDO..."
	end

	local success, response = pcall(function()
		return placeBuildPiece:InvokeServer({
			LotId = selectedLot.Name,
			PieceType = selectedPieceType,
			GridX = previewGridX,
			GridZ = previewGridZ,
			Level = currentLevel,
			Rotation = currentRotation,
		})
	end)

	placing = false
	clearEntriesCache()

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação ao construir.", true)
		return
	end
	if not response.Ok then
		setStatus(response.Error or "Construção recusada.", true)
		return
	end

	local paid = response.PricePaid or 0
	local suffix = paid > 0 and (" · pago " .. formatMoney(paid)) or ""
	local snapSuffix = currentConnectionKind ~= "Grid" and " · encaixe perfeito" or ""
	setStatus(
		string.format(
			"%s colocado%s%s · %d/%d",
			spec.DisplayName,
			suffix,
			snapSuffix,
			response.PieceCount or 0,
			BuildConfig.MaxPiecesPerLot
		),
		false
	)
	updateCashLabel()
end

function BuildController:RemoveCurrentTarget()
	if not buildMode or not removeMode or removing then
		return
	end
	if not selectedLot or not removalTargetId then
		setStatus("Aponte para uma peça do seu lote.", true)
		return
	end

	removing = true
	local success, response = pcall(function()
		return removeBuildPiece:InvokeServer({
			LotId = selectedLot.Name,
			PieceId = removalTargetId,
		})
	end)
	removing = false
	clearEntriesCache()

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação ao remover.", true)
		return
	end
	if not response.Ok then
		setStatus(response.Error or "Remoção recusada.", true)
		return
	end

	local refund = response.Refund or 0
	setStatus(
		refund > 0 and ("Peça removida · reembolso " .. formatMoney(refund)) or "Peça removida.",
		false
	)
	removalTarget = nil
	removalTargetId = nil
	updateCashLabel()
end

function BuildController:UndoLastPlacement()
	if not buildMode or removing or not selectedLot then
		return
	end

	removing = true
	local success, response = pcall(function()
		return undoBuildPiece:InvokeServer({ LotId = selectedLot.Name })
	end)
	removing = false
	clearEntriesCache()

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação ao desfazer.", true)
		return
	end
	if not response.Ok then
		setStatus(response.Error or "Nada para desfazer.", true)
		return
	end

	local refund = response.Refund or 0
	setStatus(
		refund > 0 and ("Última peça desfeita · " .. formatMoney(refund) .. " devolvidos") or "Última peça desfeita.",
		false
	)
	updateCashLabel()
end

local function setBuildMode(enabled)
	buildMode = enabled
	toggleButton.Text = enabled and "FECHAR CONSTRUÇÃO" or "CONSTRUIR"

	if enabled then
		if not refreshState() then
			buildMode = false
			panel.Visible = false
			toggleButton.Text = "CONSTRUIR"
			destroyVisuals()
			return
		end

		removeMode = false
		updateModeVisuals()
		updateSelectionVisuals()
		ensureVisualsFolder()
		createPreview()

		panel.Visible = true
		panel.Position = UDim2.new(1, 24, 0.5, 0)
		TweenService:Create(
			panel,
			TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -10, 0.5, 0) }
		):Play()
	else
		removeMode = false
		panel.Visible = false
		destroyVisuals()
	end
end

function BuildController:Start()
	createGui()

	toggleButton.Activated:Connect(function()
		setBuildMode(not buildMode)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not buildMode then
			return
		end

		if input.KeyCode == Enum.KeyCode.R and not removeMode then
			currentRotation = (currentRotation + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.E then
			currentLevel = math.min(BuildConfig.MaxLevels - 1, currentLevel + 1)
			updateLevelLabel()
		elseif input.KeyCode == Enum.KeyCode.Q then
			currentLevel = math.max(0, currentLevel - 1)
			updateLevelLabel()
		elseif input.KeyCode == Enum.KeyCode.X then
			removeMode = not removeMode
			updateModeVisuals()
			updateSelectionVisuals()
			setStatus(removeMode and "Aponte para uma peça do seu lote." or "Construção reativada.", false)
		elseif input.KeyCode == Enum.KeyCode.Z then
			self:UndoLastPlacement()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if removeMode then
				self:RemoveCurrentTarget()
			else
				self:PlaceCurrentPreview()
			end
		end
	end)

	player:GetAttributeChangedSignal("LastPurchasedLot"):Connect(function()
		if buildMode then
			refreshState()
		end
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(updateCashLabel)

	RunService.RenderStepped:Connect(updatePreview)
	print("[Property Empire v2] Premium BuildController v3 started")
end

return BuildController
