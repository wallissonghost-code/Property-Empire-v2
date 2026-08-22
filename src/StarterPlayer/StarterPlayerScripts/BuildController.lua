local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared:WaitForChild("BuildConfig"))
local BuildCollision = require(Shared:WaitForChild("BuildCollision"))

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
local previewBlockReason = nil
local previewGridX = 0
local previewGridZ = 0
local placing = false
local removing = false
local ownedLots = {}
local removalTarget = nil
local removalTargetId = nil
local visualsFolder = nil
local levelGuide = nil
local removalHighlight = nil

local gui = nil
local panel = nil
local toggleButton = nil
local statusLabel = nil
local levelLabel = nil
local cashLabel = nil
local modeLabel = nil
local removeModeButton = nil
local selectionButtons = {}

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
end

local function makeStroke(parent)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(71, 79, 91)
	stroke.Thickness = 1
	stroke.Parent = parent
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(39, 45, 54)
	button.TextColor3 = Color3.fromRGB(243, 245, 247)
	button.Text = text
	button.TextSize = 14
	button.TextWrapped = true
	button.Font = Enum.Font.GothamSemibold
	button.AutoButtonColor = true
	button.Parent = parent
	makeCorner(button, 8)
	makeStroke(button)
	return button
end

local function setStatus(text, isError)
	if not statusLabel then
		return
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = isError and Color3.fromRGB(255, 151, 151) or Color3.fromRGB(203, 211, 221)
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
		modeLabel.Text = removeMode and "MODO: REMOVER" or "MODO: CONSTRUIR"
		modeLabel.TextColor3 = removeMode and Color3.fromRGB(255, 165, 165) or Color3.fromRGB(142, 211, 171)
	end
	if removeModeButton then
		removeModeButton.Text = removeMode and "VOLTAR A CONSTRUIR [X]" or "REMOVER PEÇA [X]"
		removeModeButton.BackgroundColor3 = removeMode and Color3.fromRGB(138, 59, 59) or Color3.fromRGB(81, 55, 55)
	end
end

local function updateSelectionVisuals()
	for pieceType, button in pairs(selectionButtons) do
		local spec = BuildConfig.Catalog[pieceType]
		if pieceType == selectedPieceType and not removeMode then
			button.BackgroundColor3 = Color3.fromRGB(58, 118, 174)
		elseif spec and spec.Category == "Premium" then
			button.BackgroundColor3 = Color3.fromRGB(91, 72, 42)
		else
			button.BackgroundColor3 = Color3.fromRGB(39, 45, 54)
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
	updateModeVisuals()
	updateSelectionVisuals()
	local priceText = (spec.Price or 0) > 0 and (" · " .. formatMoney(spec.Price)) or " · GRÁTIS"
	setStatus(spec.DisplayName .. priceText, false)
end

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PropertyEmpireBuildGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	toggleButton = makeButton(gui, "CONSTRUIR", UDim2.fromOffset(170, 46), UDim2.new(1, -190, 1, -66))
	toggleButton.BackgroundColor3 = Color3.fromRGB(45, 104, 157)

	panel = Instance.new("Frame")
	panel.Name = "BuildPanel"
	panel.Size = UDim2.fromOffset(370, 560)
	panel.Position = UDim2.new(1, -390, 0.5, -280)
	panel.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
	panel.Visible = false
	panel.Parent = gui
	makeCorner(panel, 12)
	makeStroke(panel)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 32)
	title.Position = UDim2.fromOffset(16, 10)
	title.BackgroundTransparency = 1
	title.Text = "MODO CONSTRUÇÃO"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(247, 248, 250)
	title.TextSize = 19
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	cashLabel = Instance.new("TextLabel")
	cashLabel.Size = UDim2.fromOffset(150, 28)
	cashLabel.Position = UDim2.new(1, -166, 0, 12)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.TextColor3 = Color3.fromRGB(126, 222, 155)
	cashLabel.TextSize = 13
	cashLabel.Font = Enum.Font.GothamBold
	cashLabel.Parent = panel

	modeLabel = Instance.new("TextLabel")
	modeLabel.Size = UDim2.new(1, -32, 0, 20)
	modeLabel.Position = UDim2.fromOffset(16, 43)
	modeLabel.BackgroundTransparency = 1
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.TextSize = 12
	modeLabel.Font = Enum.Font.GothamBold
	modeLabel.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -32, 0, 42)
	statusLabel.Position = UDim2.fromOffset(16, 64)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Selecione uma peça"
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(203, 211, 221)
	statusLabel.TextSize = 13
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = panel

	local catalogTitle = Instance.new("TextLabel")
	catalogTitle.Size = UDim2.new(1, -32, 0, 20)
	catalogTitle.Position = UDim2.fromOffset(16, 108)
	catalogTitle.BackgroundTransparency = 1
	catalogTitle.Text = "CATÁLOGO  ·  ★ PREMIUM USA DINHEIRO DO JOGO"
	catalogTitle.TextXAlignment = Enum.TextXAlignment.Left
	catalogTitle.TextColor3 = Color3.fromRGB(139, 151, 166)
	catalogTitle.TextSize = 10
	catalogTitle.Font = Enum.Font.GothamBold
	catalogTitle.Parent = panel

	local catalog = Instance.new("ScrollingFrame")
	catalog.Name = "Catalog"
	catalog.Size = UDim2.fromOffset(338, 228)
	catalog.Position = UDim2.fromOffset(16, 132)
	catalog.BackgroundColor3 = Color3.fromRGB(29, 34, 41)
	catalog.BorderSizePixel = 0
	catalog.ScrollBarThickness = 5
	catalog.AutomaticCanvasSize = Enum.AutomaticSize.Y
	catalog.CanvasSize = UDim2.new()
	catalog.Parent = panel
	makeCorner(catalog, 8)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = catalog

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(155, 54)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = catalog

	for order, pieceType in ipairs(BuildConfig.CatalogOrder) do
		local spec = BuildConfig.Catalog[pieceType]
		if spec then
			local priceText = (spec.Price or 0) > 0 and formatMoney(spec.Price) or "GRÁTIS"
			local prefix = spec.Category == "Premium" and "★ " or ""
			local button = makeButton(catalog, prefix .. spec.DisplayName .. "\n" .. priceText, UDim2.fromOffset(155, 54), UDim2.new())
			button.LayoutOrder = order
			button.TextSize = 12
			selectionButtons[pieceType] = button
			button.Activated:Connect(function()
				selectPiece(pieceType)
			end)
		end
	end

	levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.fromOffset(150, 36)
	levelLabel.Position = UDim2.fromOffset(110, 370)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(231, 235, 240)
	levelLabel.TextSize = 12
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = panel

	local downButton = makeButton(panel, "− ANDAR [Q]", UDim2.fromOffset(92, 38), UDim2.fromOffset(16, 370))
	local upButton = makeButton(panel, "+ ANDAR [E]", UDim2.fromOffset(92, 38), UDim2.fromOffset(262, 370))
	local rotateButton = makeButton(panel, "ROTACIONAR 90° [R]", UDim2.fromOffset(338, 38), UDim2.fromOffset(16, 416))
	removeModeButton = makeButton(panel, "REMOVER PEÇA [X]", UDim2.fromOffset(165, 40), UDim2.fromOffset(16, 462))
	local undoButton = makeButton(panel, "DESFAZER [Z]", UDim2.fromOffset(165, 40), UDim2.fromOffset(189, 462))
	local placeButton = makeButton(panel, "COLOCAR PEÇA", UDim2.fromOffset(338, 42), UDim2.fromOffset(16, 510))
	placeButton.BackgroundColor3 = Color3.fromRGB(52, 132, 89)

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
		setStatus(removeMode and "Clique em uma peça do seu lote para remover" or "Modo construção ativado", false)
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
	levelGuide.Color = Color3.fromRGB(76, 171, 224)
	levelGuide.Transparency = 0.9
	levelGuide.CastShadow = false
	levelGuide.Parent = visualsFolder

	removalHighlight = Instance.new("Highlight")
	removalHighlight.Name = "RemovalHighlight"
	removalHighlight.FillColor = Color3.fromRGB(235, 72, 72)
	removalHighlight.FillTransparency = 0.55
	removalHighlight.OutlineColor = Color3.fromRGB(255, 214, 214)
	removalHighlight.OutlineTransparency = 0
	removalHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	removalHighlight.Enabled = false
	removalHighlight.Parent = visualsFolder

	mouse.TargetFilter = visualsFolder
end

local function destroyPreview()
	if preview then
		preview:Destroy()
		preview = nil
	end
end

local function destroyVisuals()
	preview = nil
	levelGuide = nil
	removalHighlight = nil
	if visualsFolder then
		visualsFolder:Destroy()
		visualsFolder = nil
	end
	mouse.TargetFilter = nil
	removalTarget = nil
	removalTargetId = nil
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
	preview.Transparency = 0.5
	preview.CastShadow = false
	preview.Parent = visualsFolder
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
end

local function refreshState()
	local success, state = pcall(function()
		return getBuildState:InvokeServer()
	end)

	if not success or type(state) ~= "table" then
		ownedLots = {}
		selectedLot = nil
		setStatus("Não foi possível carregar seus lotes", true)
		return false
	end

	ownedLots = type(state.OwnedLots) == "table" and state.OwnedLots or {}
	chooseNearestOwnedLot()
	updateCashLabel()
	if not selectedLot then
		setStatus("Compre um lote antes de construir", true)
		return false
	end

	setStatus(string.format("Construindo em %s", selectedLot.Name), false)
	return true
end

local function rotatedFootprint(spec)
	if currentRotation % 2 == 1 then
		return spec.Size.Z, spec.Size.X
	end
	return spec.Size.X, spec.Size.Z
end

local function updateLevelGuide()
	if not levelGuide or not selectedLot then
		return
	end
	levelGuide.Size = Vector3.new(selectedLot.Size.X, 0.12, selectedLot.Size.Z)
	levelGuide.CFrame = selectedLot.CFrame
		* CFrame.new(0, selectedLot.Size.Y / 2 + currentLevel * BuildConfig.LevelHeight + 0.08, 0)
	levelGuide.Transparency = currentLevel == 0 and 0.94 or 0.88
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

local function readPlacedEntries()
	local entries = {}
	if not selectedLot then
		return entries
	end

	local world = workspace:FindFirstChild("PropertyEmpireV2World")
	local builds = world and world:FindFirstChild("Builds")
	local lotFolder = builds and builds:FindFirstChild(selectedLot.Name)
	if not lotFolder then
		return entries
	end

	for _, root in ipairs(lotFolder:GetChildren()) do
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

	return entries
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

local function updatePreview()
	if not buildMode or not selectedLot then
		previewValid = false
		previewBlockReason = nil
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
		previewBlockReason = nil
		if preview then
			preview.Transparency = 1
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

	local localHit = selectedLot.CFrame:PointToObjectSpace(mouse.Hit.Position)
	previewGridX = math.round(localHit.X / BuildConfig.GridSize)
	previewGridZ = math.round(localHit.Z / BuildConfig.GridSize)

	local localY = selectedLot.Size.Y / 2 + currentLevel * BuildConfig.LevelHeight + spec.Size.Y / 2
	preview.CFrame = selectedLot.CFrame
		* CFrame.new(previewGridX * BuildConfig.GridSize, localY, previewGridZ * BuildConfig.GridSize)
		* CFrame.Angles(0, math.rad(currentRotation * 90), 0)

	local sizeX, sizeZ = rotatedFootprint(spec)
	local centerX = previewGridX * BuildConfig.GridSize
	local centerZ = previewGridZ * BuildConfig.GridSize
	local maxX = selectedLot.Size.X / 2 - BuildConfig.BoundaryMargin
	local maxZ = selectedLot.Size.Z / 2 - BuildConfig.BoundaryMargin
	previewValid = math.abs(centerX) + sizeX / 2 <= maxX and math.abs(centerZ) + sizeZ / 2 <= maxZ
	previewBlockReason = previewValid and nil or "A peça precisa ficar dentro do lote"

	if previewValid then
		local candidate = BuildCollision.MakeDescriptor(
			BuildConfig,
			selectedPieceType,
			previewGridX,
			previewGridZ,
			currentLevel,
			currentRotation
		)
		local hasConflict = candidate and BuildCollision.HasConflict(BuildConfig, candidate, readPlacedEntries()) or true
		if hasConflict then
			previewValid = false
			previewBlockReason = "Outra peça já ocupa esse espaço"
		end
	end

	preview.Transparency = 0.5
	preview.Color = previewValid and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(235, 84, 84)
end

function BuildController:PlaceCurrentPreview()
	if not buildMode or removeMode or placing then
		return
	end
	if not selectedLot then
		setStatus("Nenhum lote seu foi encontrado", true)
		return
	end
	if not previewValid then
		setStatus(previewBlockReason or "A posição da peça é inválida", true)
		return
	end

	local spec = BuildConfig.Catalog[selectedPieceType]
	placing = true
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

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação ao construir", true)
		return
	end
	if not response.Ok then
		setStatus(response.Error or "Construção recusada", true)
		return
	end

	local paid = response.PricePaid or 0
	local suffix = paid > 0 and (" · pago " .. formatMoney(paid)) or ""
	setStatus(
		string.format("%s colocado%s · %d/%d", spec.DisplayName, suffix, response.PieceCount or 0, BuildConfig.MaxPiecesPerLot),
		false
	)
	updateCashLabel()
end

function BuildController:RemoveCurrentTarget()
	if not buildMode or not removeMode or removing then
		return
	end
	if not selectedLot or not removalTargetId then
		setStatus("Aponte para uma peça do seu lote", true)
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

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação ao remover", true)
		return
	end
	if not response.Ok then
		setStatus(response.Error or "Remoção recusada", true)
		return
	end

	local refund = response.Refund or 0
	setStatus(
		refund > 0 and ("Peça removida · reembolso " .. formatMoney(refund)) or "Peça removida",
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

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação ao desfazer", true)
		return
	end
	if not response.Ok then
		setStatus(response.Error or "Nada para desfazer", true)
		return
	end

	local refund = response.Refund or 0
	setStatus(refund > 0 and ("Última peça desfeita · " .. formatMoney(refund) .. " devolvidos") or "Última peça desfeita", false)
	updateCashLabel()
end

local function setBuildMode(enabled)
	buildMode = enabled
	panel.Visible = enabled
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
	else
		removeMode = false
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
			setStatus(removeMode and "Clique em uma peça do seu lote para remover" or "Modo construção ativado", false)
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
	print("[Property Empire v2] BuildController v3 started")
end

return BuildController
