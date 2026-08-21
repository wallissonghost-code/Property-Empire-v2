local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BuildConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BuildConfig"))

local BuildController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getBuildState = remotes:WaitForChild("GetBuildState")
local placeBuildPiece = remotes:WaitForChild("PlaceBuildPiece")

local buildMode = false
local selectedPieceType = "Floor"
local selectedLot = nil
local currentLevel = 0
local currentRotation = 0
local preview = nil
local previewValid = false
local previewGridX = 0
local previewGridZ = 0
local placing = false
local ownedLots = {}

local gui = nil
local panel = nil
local toggleButton = nil
local statusLabel = nil
local levelLabel = nil
local selectionButtons = {}

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
	button.TextSize = 16
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

local function updateLevelLabel()
	if levelLabel then
		levelLabel.Text = string.format("ANDAR %d", currentLevel + 1)
	end
end

local function updateSelectionVisuals()
	for pieceType, button in pairs(selectionButtons) do
		if pieceType == selectedPieceType then
			button.BackgroundColor3 = Color3.fromRGB(58, 118, 174)
		else
			button.BackgroundColor3 = Color3.fromRGB(39, 45, 54)
		end
	end
end

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PropertyEmpireBuildGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	toggleButton = makeButton(gui, "CONSTRUIR", UDim2.fromOffset(150, 46), UDim2.new(1, -170, 1, -66))
	toggleButton.BackgroundColor3 = Color3.fromRGB(45, 104, 157)

	panel = Instance.new("Frame")
	panel.Name = "BuildPanel"
	panel.Size = UDim2.fromOffset(330, 420)
	panel.Position = UDim2.new(1, -350, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
	panel.Visible = false
	panel.Parent = gui
	makeCorner(panel, 12)
	makeStroke(panel)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -32, 0, 38)
	title.Position = UDim2.fromOffset(16, 12)
	title.BackgroundTransparency = 1
	title.Text = "MODO CONSTRUÇÃO"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(247, 248, 250)
	title.TextSize = 19
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -32, 0, 42)
	statusLabel.Position = UDim2.fromOffset(16, 50)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Selecione uma peça"
	statusLabel.TextWrapped = true
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextColor3 = Color3.fromRGB(203, 211, 221)
	statusLabel.TextSize = 13
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = panel

	local catalogTitle = Instance.new("TextLabel")
	catalogTitle.Size = UDim2.new(1, -32, 0, 24)
	catalogTitle.Position = UDim2.fromOffset(16, 98)
	catalogTitle.BackgroundTransparency = 1
	catalogTitle.Text = "PEÇAS BÁSICAS"
	catalogTitle.TextXAlignment = Enum.TextXAlignment.Left
	catalogTitle.TextColor3 = Color3.fromRGB(139, 151, 166)
	catalogTitle.TextSize = 12
	catalogTitle.Font = Enum.Font.GothamBold
	catalogTitle.Parent = panel

	local orderedPieces = { "Floor", "Wall", "Doorway", "Window" }
	for index, pieceType in ipairs(orderedPieces) do
		local spec = BuildConfig.Catalog[pieceType]
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local button = makeButton(
			panel,
			spec.DisplayName,
			UDim2.fromOffset(143, 48),
			UDim2.fromOffset(16 + column * 155, 128 + row * 58)
		)
		selectionButtons[pieceType] = button
		button.Activated:Connect(function()
			selectedPieceType = pieceType
			updateSelectionVisuals()
			setStatus(string.format("%s selecionado", spec.DisplayName), false)
		end)
	end

	levelLabel = Instance.new("TextLabel")
	levelLabel.Size = UDim2.fromOffset(110, 40)
	levelLabel.Position = UDim2.fromOffset(110, 254)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(231, 235, 240)
	levelLabel.TextSize = 14
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Parent = panel

	local downButton = makeButton(panel, "− ANDAR", UDim2.fromOffset(92, 40), UDim2.fromOffset(16, 254))
	local upButton = makeButton(panel, "+ ANDAR", UDim2.fromOffset(92, 40), UDim2.fromOffset(222, 254))
	local rotateButton = makeButton(panel, "ROTACIONAR 90°", UDim2.fromOffset(298, 42), UDim2.fromOffset(16, 302))
	local placeButton = makeButton(panel, "COLOCAR PEÇA", UDim2.fromOffset(298, 50), UDim2.fromOffset(16, 354))
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

	placeButton.Activated:Connect(function()
		BuildController:PlaceCurrentPreview()
	end)

	updateSelectionVisuals()
	updateLevelLabel()
end

local function destroyPreview()
	if preview then
		preview:Destroy()
		preview = nil
	end
	mouse.TargetFilter = nil
end

local function createPreview()
	destroyPreview()
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
	preview.Parent = workspace
	mouse.TargetFilter = preview
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

local function updatePreview()
	if not buildMode or not selectedLot then
		previewValid = false
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

	preview.Transparency = 0.5
	preview.Color = previewValid and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(235, 84, 84)
end

function BuildController:PlaceCurrentPreview()
	if not buildMode or placing then
		return
	end
	if not selectedLot then
		setStatus("Nenhum lote seu foi encontrado", true)
		return
	end
	if not previewValid then
		setStatus("A peça precisa ficar dentro do lote", true)
		return
	end

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

	setStatus(string.format("Peça colocada · %d/%d", response.PieceCount or 0, BuildConfig.MaxPiecesPerLot), false)
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
			destroyPreview()
			return
		end
		createPreview()
	else
		destroyPreview()
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

		if input.KeyCode == Enum.KeyCode.R then
			currentRotation = (currentRotation + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.PageUp then
			currentLevel = math.min(BuildConfig.MaxLevels - 1, currentLevel + 1)
			updateLevelLabel()
		elseif input.KeyCode == Enum.KeyCode.PageDown then
			currentLevel = math.max(0, currentLevel - 1)
			updateLevelLabel()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:PlaceCurrentPreview()
		end
	end)

	player:GetAttributeChangedSignal("LastPurchasedLot"):Connect(function()
		if buildMode then
			refreshState()
		end
	end)

	RunService.RenderStepped:Connect(updatePreview)
	print("[Property Empire v2] BuildController started")
end

return BuildController
