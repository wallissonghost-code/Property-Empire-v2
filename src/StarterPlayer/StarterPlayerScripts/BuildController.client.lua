local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BuildCatalog = require(ReplicatedStorage.Shared.BuildCatalog)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MuseumBuildRemotes")
local getBuildState = remotes:WaitForChild("GetBuildState")
local buildAction = remotes:WaitForChild("BuildAction")

local gui = Instance.new("ScreenGui")
gui.Name = "MuseumBuildUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local openButton = Instance.new("TextButton")
openButton.Name = "OpenBuild"
openButton.Size = UDim2.fromOffset(170, 48)
openButton.Position = UDim2.new(0, 16, 1, -68)
openButton.BackgroundColor3 = Color3.fromRGB(40, 77, 83)
openButton.TextColor3 = Color3.new(1, 1, 1)
openButton.Text = "🔨 CONSTRUIR"
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 15
openButton.Parent = gui
Instance.new("UICorner", openButton).CornerRadius = UDim.new(0, 10)

local panel = Instance.new("Frame")
panel.Name = "BuildPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -16, 0.5, 0)
panel.Size = UDim2.new(0.38, 0, 0.86, 0)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local panelLimit = Instance.new("UISizeConstraint")
panelLimit.MinSize = Vector2.new(300, 470)
panelLimit.MaxSize = Vector2.new(430, 720)
panelLimit.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -78, 0, 34)
title.Position = UDim2.fromOffset(16, 12)
title.BackgroundTransparency = 1
title.Text = "CONSTRUÇÃO DO MUSEU"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -32, 0, 40)
subtitle.Position = UDim2.fromOffset(16, 44)
subtitle.BackgroundTransparency = 1
subtitle.TextColor3 = Color3.fromRGB(151, 164, 178)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextWrapped = true
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(46, 34)
close.Position = UDim2.new(1, -60, 0, 12)
close.BackgroundColor3 = Color3.fromRGB(76, 44, 48)
close.TextColor3 = Color3.new(1, 1, 1)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.Parent = panel
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)

local categoryButton = Instance.new("TextButton")
categoryButton.Size = UDim2.new(1, -32, 0, 38)
categoryButton.Position = UDim2.fromOffset(16, 88)
categoryButton.BackgroundColor3 = Color3.fromRGB(35, 47, 58)
categoryButton.TextColor3 = Color3.fromRGB(238, 241, 245)
categoryButton.Font = Enum.Font.GothamSemibold
categoryButton.TextSize = 13
categoryButton.Parent = panel
Instance.new("UICorner", categoryButton).CornerRadius = UDim.new(0, 8)

local catalogFrame = Instance.new("ScrollingFrame")
catalogFrame.Position = UDim2.fromOffset(16, 134)
catalogFrame.Size = UDim2.new(1, -32, 1, -330)
catalogFrame.BackgroundColor3 = Color3.fromRGB(24, 29, 36)
catalogFrame.BorderSizePixel = 0
catalogFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
catalogFrame.CanvasSize = UDim2.new()
catalogFrame.ScrollBarThickness = 5
catalogFrame.Parent = panel
Instance.new("UICorner", catalogFrame).CornerRadius = UDim.new(0, 9)
local catalogPadding = Instance.new("UIPadding")
catalogPadding.PaddingLeft = UDim.new(0, 8)
catalogPadding.PaddingRight = UDim.new(0, 8)
catalogPadding.PaddingTop = UDim.new(0, 8)
catalogPadding.PaddingBottom = UDim.new(0, 8)
catalogPadding.Parent = catalogFrame
local catalogLayout = Instance.new("UIListLayout")
catalogLayout.Padding = UDim.new(0, 6)
catalogLayout.Parent = catalogFrame

local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, -32, 0, 42)
selectedLabel.Position = UDim2.new(0, 16, 1, -188)
selectedLabel.BackgroundColor3 = Color3.fromRGB(25, 31, 38)
selectedLabel.TextColor3 = Color3.fromRGB(232, 235, 239)
selectedLabel.TextWrapped = true
selectedLabel.Font = Enum.Font.GothamSemibold
selectedLabel.TextSize = 12
selectedLabel.Parent = panel
Instance.new("UICorner", selectedLabel).CornerRadius = UDim.new(0, 8)

local floorButton = Instance.new("TextButton")
floorButton.Size = UDim2.new(0.48, -4, 0, 36)
floorButton.Position = UDim2.new(0, 16, 1, -138)
floorButton.BackgroundColor3 = Color3.fromRGB(47, 64, 78)
floorButton.TextColor3 = Color3.new(1, 1, 1)
floorButton.Font = Enum.Font.GothamSemibold
floorButton.TextSize = 12
floorButton.Parent = panel
Instance.new("UICorner", floorButton).CornerRadius = UDim.new(0, 8)

local rotateButton = Instance.new("TextButton")
rotateButton.Size = UDim2.new(0.48, -4, 0, 36)
rotateButton.Position = UDim2.new(0.52, 0, 1, -138)
rotateButton.BackgroundColor3 = Color3.fromRGB(47, 64, 78)
rotateButton.TextColor3 = Color3.new(1, 1, 1)
rotateButton.Font = Enum.Font.GothamSemibold
rotateButton.TextSize = 12
rotateButton.Parent = panel
Instance.new("UICorner", rotateButton).CornerRadius = UDim.new(0, 8)

local placeButton = Instance.new("TextButton")
placeButton.Size = UDim2.new(0.64, -4, 0, 44)
placeButton.Position = UDim2.new(0, 16, 1, -94)
placeButton.BackgroundColor3 = Color3.fromRGB(52, 105, 77)
placeButton.TextColor3 = Color3.new(1, 1, 1)
placeButton.Text = "COMPRAR E CONSTRUIR"
placeButton.Font = Enum.Font.GothamBold
placeButton.TextSize = 12
placeButton.TextWrapped = true
placeButton.Parent = panel
Instance.new("UICorner", placeButton).CornerRadius = UDim.new(0, 9)

local removeButton = Instance.new("TextButton")
removeButton.Size = UDim2.new(0.36, -4, 0, 44)
removeButton.Position = UDim2.new(0.64, 4, 1, -94)
removeButton.BackgroundColor3 = Color3.fromRGB(91, 54, 57)
removeButton.TextColor3 = Color3.new(1, 1, 1)
removeButton.Text = "REMOVER\n50%"
removeButton.Font = Enum.Font.GothamBold
removeButton.TextSize = 11
removeButton.TextWrapped = true
removeButton.Parent = panel
Instance.new("UICorner", removeButton).CornerRadius = UDim.new(0, 9)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -32, 0, 36)
status.Position = UDim2.new(0, 16, 1, -44)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(145, 218, 176)
status.TextWrapped = true
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = panel

local preview = Instance.new("Part")
preview.Name = "MuseumBuildPreview"
preview.Anchored = true
preview.CanCollide = false
preview.CanQuery = false
preview.CanTouch = false
preview.Material = Enum.Material.ForceField
preview.Transparency = 0.45
preview.Color = Color3.fromRGB(87, 208, 137)
preview.Parent = Workspace

local highlight = Instance.new("Highlight")
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.FillTransparency = 0.78
highlight.OutlineTransparency = 0.1
highlight.Adornee = preview
highlight.Parent = preview

local currentState
local selectedItemId = "Floor"
local categoryIndex = 1
local floor = 1
local rotation = 0
local previewX = 0
local previewZ = 0
local previewValid = false
local busy = false
local removeTargetId

local function money(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	repeat
		local formatted, count = text:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
		text = formatted
		if count == 0 then break end
	until false
	return "$" .. text
end

local function getMuseumFloor()
	local world = Workspace:FindFirstChild("MuseumWorld")
	local museum = world and world:FindFirstChild("Museum_" .. player.UserId)
	return museum and museum:FindFirstChild("Floor")
end

local function canUse(item)
	if not currentState then return false end
	return currentState.MuseumLevel >= item.MinLevel and currentState.Prestige >= item.MinPrestige
end

local function refreshControls()
	local item = BuildCatalog.Get(selectedItemId)
	if not item then return end
	selectedLabel.Text = string.format("%s · %s · %s\nNível %d · prestígio %d", item.Name, money(item.Price), item.Category, item.MinLevel, item.MinPrestige)
	floor = math.clamp(floor, 1, math.max(1, currentState and currentState.MuseumLevel or 1))
	floorButton.Text = "ANDAR " .. floor
	rotateButton.Text = "GIRAR · " .. rotation .. "°"
	categoryButton.Text = "CATEGORIA: " .. BuildCatalog.CategoryOrder[categoryIndex] .. "  ›"
end

local function clearCatalog()
	for _, child in ipairs(catalogFrame:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function renderCatalog()
	clearCatalog()
	local category = BuildCatalog.CategoryOrder[categoryIndex]
	for _, item in ipairs(BuildCatalog.GetOrderedItems()) do
		if item.Category == category then
			local unlocked = canUse(item)
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(1, -2, 0, 48)
			button.BackgroundColor3 = selectedItemId == item.Id and Color3.fromRGB(53, 91, 96) or (unlocked and Color3.fromRGB(38, 47, 57) or Color3.fromRGB(42, 39, 43))
			button.TextColor3 = unlocked and Color3.fromRGB(240, 242, 245) or Color3.fromRGB(159, 149, 153)
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.TextWrapped = true
			button.Text = string.format("  %s · %s%s", item.Name, money(item.Price), unlocked and "" or string.format("  🔒 N%d/P%d", item.MinLevel, item.MinPrestige))
			button.Font = Enum.Font.GothamSemibold
			button.TextSize = 12
			button.Parent = catalogFrame
			Instance.new("UICorner", button).CornerRadius = UDim.new(0, 7)
			button.Activated:Connect(function()
				selectedItemId = item.Id
				refreshControls()
				renderCatalog()
			end)
		end
	end
end

local function refreshState()
	local ok, state = pcall(function()
		return getBuildState:InvokeServer()
	end)
	if not ok or type(state) ~= "table" or not state.Ok then
		status.TextColor3 = Color3.fromRGB(245, 144, 144)
		status.Text = type(state) == "table" and state.Error or "Não foi possível carregar a construção"
		return false
	end
	currentState = state
	subtitle.Text = string.format("Caixa %s · nível %d · prestígio %d · peças %d/%d", money(state.Cash), state.MuseumLevel, state.Prestige, state.PieceCount, state.MaxPieces)
	refreshControls()
	renderCatalog()
	return true
end

local function screenPoint()
	local camera = Workspace.CurrentCamera
	if not camera then return nil end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local viewport = camera.ViewportSize
		return Vector2.new(viewport.X * 0.5, viewport.Y * 0.52)
	end
	return UserInputService:GetMouseLocation()
end

local function worldHit()
	local camera = Workspace.CurrentCamera
	local point = screenPoint()
	if not camera or not point then return nil, nil end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { preview }
	if player.Character then table.insert(exclude, player.Character) end
	params.FilterDescendantsInstances = exclude
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	return result and result.Position or nil, result and result.Instance or nil
end

local function snap(value)
	local grid = BuildCatalog.GridSize
	return math.floor(value / grid + 0.5) * grid
end

local function updatePreview()
	preview.Transparency = panel.Visible and 0.45 or 1
	if not panel.Visible then return end
	local item = BuildCatalog.Get(selectedItemId)
	local museumFloor = getMuseumFloor()
	local hit, target = worldHit()
	if not item or not museumFloor or not hit then
		previewValid = false
		preview.Color = Color3.fromRGB(220, 82, 82)
		return
	end
	local localPos = museumFloor.CFrame:PointToObjectSpace(hit)
	previewX = snap(localPos.X)
	previewZ = snap(localPos.Z)
	local floorOffset = (floor - 1) * BuildCatalog.FloorHeight
	preview.Size = item.Size
	preview.CFrame = museumFloor.CFrame
		* CFrame.new(previewX, floorOffset + item.YOffset - 0.5, previewZ)
		* CFrame.Angles(0, math.rad(rotation), 0)

	local rotated = (rotation == 90 or rotation == 270) and Vector3.new(item.Size.Z, item.Size.Y, item.Size.X) or item.Size
	previewValid = canUse(item)
		and math.abs(previewX) + rotated.X * 0.5 <= BuildCatalog.PlotHalfWidth
		and math.abs(previewZ) + rotated.Z * 0.5 <= BuildCatalog.PlotHalfDepth
	preview.Color = previewValid and Color3.fromRGB(87, 208, 137) or Color3.fromRGB(220, 82, 82)

	removeTargetId = nil
	local model = target and target:FindFirstAncestorOfClass("Model")
	if model then
		removeTargetId = model:GetAttribute("BuildPieceId")
	end
end

local function perform(payload)
	if busy then return end
	busy = true
	status.TextColor3 = Color3.fromRGB(181, 197, 213)
	status.Text = "Processando..."
	local ok, result = pcall(function()
		return buildAction:InvokeServer(payload)
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		status.TextColor3 = Color3.fromRGB(245, 144, 144)
		status.Text = "Falha de comunicação com o servidor"
		return
	end
	status.TextColor3 = result.Ok and Color3.fromRGB(145, 218, 176) or Color3.fromRGB(245, 144, 144)
	status.Text = result.Message or result.Error or "Concluído"
	refreshState()
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	preview.Transparency = panel.Visible and 0.45 or 1
	if panel.Visible then
		refreshState()
	end
end)

close.Activated:Connect(function()
	panel.Visible = false
	preview.Transparency = 1
end)

categoryButton.Activated:Connect(function()
	categoryIndex += 1
	if categoryIndex > #BuildCatalog.CategoryOrder then categoryIndex = 1 end
	refreshControls()
	renderCatalog()
end)

floorButton.Activated:Connect(function()
	local maxFloor = math.max(1, currentState and currentState.MuseumLevel or 1)
	floor += 1
	if floor > maxFloor then floor = 1 end
	refreshControls()
end)

rotateButton.Activated:Connect(function()
	rotation = (rotation + 90) % 360
	refreshControls()
end)

placeButton.Activated:Connect(function()
	if not previewValid then
		status.TextColor3 = Color3.fromRGB(245, 144, 144)
		status.Text = "Posição ou item ainda bloqueado"
		return
	end
	perform({
		Action = "Place",
		ItemId = selectedItemId,
		X = previewX,
		Z = previewZ,
		Floor = floor,
		Rotation = rotation,
	})
end)

removeButton.Activated:Connect(function()
	if not removeTargetId then
		status.TextColor3 = Color3.fromRGB(245, 144, 144)
		status.Text = "Aponte para uma peça construída para remover"
		return
	end
	perform({ Action = "Remove", PieceId = removeTargetId })
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not panel.Visible then return end
	if input.KeyCode == Enum.KeyCode.R then
		rotation = (rotation + 90) % 360
		refreshControls()
	elseif input.KeyCode == Enum.KeyCode.Q then
		floor = math.max(1, floor - 1)
		refreshControls()
	elseif input.KeyCode == Enum.KeyCode.E then
		local maxFloor = math.max(1, currentState and currentState.MuseumLevel or 1)
		floor = math.min(maxFloor, floor + 1)
		refreshControls()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		panel.Visible = false
		preview.Transparency = 1
	end
end)

RunService.RenderStepped:Connect(updatePreview)
refreshControls()
preview.Transparency = 1
print("[Museum Empire] BuildController ready — modular paid construction")
