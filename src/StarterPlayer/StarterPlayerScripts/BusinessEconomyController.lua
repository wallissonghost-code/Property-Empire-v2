local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("BusinessEconomyConfig"))

local BusinessEconomyController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openRemote = remotes:WaitForChild("OpenBusinessEconomy")
local getStateRemote = remotes:WaitForChild("GetBusinessEconomyState")
local actionRemote = remotes:WaitForChild("BusinessEconomyAction")

local gui = nil
local panel = nil
local titleLabel = nil
local subtitleLabel = nil
local statusLabel = nil
local content = nil
local currentLotId = nil
local currentState = nil
local selectedBuyerIndex = 1
local busy = false

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
	stroke.Color = Color3.fromRGB(65, 75, 88)
	stroke.Thickness = 1
	stroke.Parent = parent
end

local function makeLabel(parent, text, height, bold)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -4, 0, height or 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(225, 231, 237)
	label.TextSize = bold and 14 or 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Parent = parent
	return label
end

local function makeButton(parent, text, callback, height)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -4, 0, height or 38)
	button.BackgroundColor3 = Color3.fromRGB(45, 72, 96)
	button.TextColor3 = Color3.fromRGB(246, 248, 250)
	button.Text = text
	button.TextSize = 13
	button.TextWrapped = true
	button.Font = Enum.Font.GothamSemibold
	button.AutoButtonColor = true
	button.Parent = parent
	makeCorner(button, 8)
	makeStroke(button)
	button.Activated:Connect(callback)
	return button
end

local function makeSection(parent, text)
	local label = makeLabel(parent, text, 28, true)
	label.TextColor3 = Color3.fromRGB(139, 194, 232)
	return label
end

local function setStatus(text, isError)
	if not statusLabel then
		return
	end
	statusLabel.Text = text or ""
	statusLabel.TextColor3 = isError and Color3.fromRGB(255, 151, 151) or Color3.fromRGB(154, 220, 174)
end

local function clearContent()
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function createGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "PropertyEmpireBusinessEconomyGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "BusinessPanel"
	panel.Size = UDim2.fromOffset(520, 650)
	panel.Position = UDim2.new(0.5, -260, 0.5, -325)
	panel.BackgroundColor3 = Color3.fromRGB(23, 28, 34)
	panel.Visible = false
	panel.Parent = gui
	makeCorner(panel, 12)
	makeStroke(panel)

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -96, 0, 32)
	titleLabel.Position = UDim2.fromOffset(18, 14)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "EMPRESA"
	titleLabel.TextColor3 = Color3.fromRGB(247, 248, 250)
	titleLabel.TextSize = 20
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = panel

	subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, -96, 0, 22)
	subtitleLabel.Position = UDim2.fromOffset(18, 47)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = Color3.fromRGB(145, 156, 169)
	subtitleLabel.TextSize = 12
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(54, 36)
	closeButton.Position = UDim2.new(1, -72, 0, 16)
	closeButton.BackgroundColor3 = Color3.fromRGB(68, 47, 51)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(250, 230, 232)
	closeButton.TextSize = 15
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = panel
	makeCorner(closeButton, 8)
	closeButton.Activated:Connect(function()
		panel.Visible = false
		currentLotId = nil
		currentState = nil
	end)

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -36, 0, 42)
	statusLabel.Position = UDim2.fromOffset(18, 74)
	statusLabel.BackgroundColor3 = Color3.fromRGB(30, 36, 44)
	statusLabel.BackgroundTransparency = 0.2
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(154, 220, 174)
	statusLabel.TextSize = 12
	statusLabel.TextWrapped = true
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = panel
	makeCorner(statusLabel, 7)

	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -36, 1, -136)
	content.Position = UDim2.fromOffset(18, 124)
	content.BackgroundColor3 = Color3.fromRGB(28, 33, 40)
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = panel
	makeCorner(content, 9)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
end

local function getSelectedBuyerLot()
	if not currentState or type(currentState.BuyerPizzerias) ~= "table" or #currentState.BuyerPizzerias == 0 then
		return nil
	end
	selectedBuyerIndex = math.clamp(selectedBuyerIndex, 1, #currentState.BuyerPizzerias)
	return currentState.BuyerPizzerias[selectedBuyerIndex]
end

local refresh

local function perform(payload)
	if busy or not currentLotId then
		return
	end
	busy = true
	setStatus("Processando...", false)

	local success, response = pcall(function()
		return actionRemote:InvokeServer(payload)
	end)
	busy = false

	if not success or type(response) ~= "table" then
		setStatus("Falha de comunicação com o servidor", true)
		return
	end

	local message = response.Message or response.Error or "Operação concluída"
	local isError = not response.Ok
	refresh(false)
	setStatus(message, isError)
end

local function renderCashControls(state)
	makeSection(content, "CAIXA DA EMPRESA")
	makeLabel(
		content,
		string.format("Caixa empresarial: %s   ·   Saldo pessoal: %s", formatMoney(state.Economy.BusinessCash), formatMoney(state.PersonalCash)),
		32,
		true
	)
	makeButton(content, "DEPOSITAR $1.000", function()
		perform({ Action = "Deposit", LotId = currentLotId, Amount = 1000 })
	end)
	makeButton(content, "SACAR $1.000", function()
		perform({ Action = "Withdraw", LotId = currentLotId, Amount = 1000 })
	end)
end

local function renderFarmStock(state)
	makeSection(content, "ESTOQUE E PREÇOS")
	for _, itemId in ipairs(EconomyConfig.FarmItemOrder) do
		local item = EconomyConfig.Items[itemId]
		local quantity = state.Economy.Inventory[itemId] or 0
		local price = state.Economy.Prices[itemId] or 0
		makeLabel(content, string.format("%s: %d unidades   ·   %s/unidade", item.DisplayName, quantity, formatMoney(price)), 30, true)
	end
end

local function renderFarmManagement(state)
	makeSection(content, "PRODUÇÃO DA FAZENDA")
	local readyIn = state.Economy.ProductionReadyIn or 0
	local productionText = readyIn > 0 and string.format("PRODUÇÃO DISPONÍVEL EM %ds", readyIn) or "PRODUZIR NOVO LOTE"
	makeButton(content, productionText, function()
		perform({ Action = "FarmProduce", LotId = currentLotId })
	end)
	makeLabel(content, "Cada lote rende 5 farinha, 3 queijo e 4 tomate. Não há penalidade por ficar offline.", 42, false)

	renderFarmStock(state)
	makeSection(content, "AJUSTAR PREÇOS")
	for _, itemId in ipairs(EconomyConfig.FarmItemOrder) do
		local item = EconomyConfig.Items[itemId]
		makeLabel(content, item.DisplayName, 24, true)
		makeButton(content, "- $1 NO PREÇO", function()
			perform({ Action = "SetFarmPrice", LotId = currentLotId, ItemId = itemId, Delta = -1 })
		end, 32)
		makeButton(content, "+ $1 NO PREÇO", function()
			perform({ Action = "SetFarmPrice", LotId = currentLotId, ItemId = itemId, Delta = 1 })
		end, 32)
	end
end

local function renderFarmPurchasing(state)
	local buyers = state.BuyerPizzerias or {}
	if #buyers == 0 then
		if not state.Target.IsOwner then
			makeSection(content, "COMPRAR DESTA FAZENDA")
			makeLabel(content, "Você precisa ter uma Pizzaria licenciada para comprar estes ingredientes como empresa.", 48, false)
		end
		return
	end

	makeSection(content, "COMPRAR PARA SUA PIZZARIA")
	local selected = getSelectedBuyerLot()
	makeButton(content, string.format("PIZZARIA COMPRADORA: %s · CAIXA %s", selected.LotId, formatMoney(selected.BusinessCash)), function()
		selectedBuyerIndex += 1
		if selectedBuyerIndex > #buyers then
			selectedBuyerIndex = 1
		end
		refresh(false)
	end)

	if not state.Target.OwnerOnline then
		makeLabel(content, "O dono desta Fazenda não está neste servidor. As compras entre jogadores ficam pausadas até ele entrar.", 52, false)
		return
	end

	for _, itemId in ipairs(EconomyConfig.FarmItemOrder) do
		local item = EconomyConfig.Items[itemId]
		local price = state.Economy.Prices[itemId] or 0
		local stock = state.Economy.Inventory[itemId] or 0
		makeLabel(content, string.format("%s · estoque %d · %s cada", item.DisplayName, stock, formatMoney(price)), 28, true)
		makeButton(content, string.format("COMPRAR 1 · %s", formatMoney(price)), function()
			perform({
				Action = "BuyFromFarm",
				SellerLotId = currentLotId,
				BuyerLotId = getSelectedBuyerLot().LotId,
				ItemId = itemId,
				Quantity = 1,
			})
		end, 34)
		makeButton(content, string.format("COMPRAR 5 · %s", formatMoney(price * 5)), function()
			perform({
				Action = "BuyFromFarm",
				SellerLotId = currentLotId,
				BuyerLotId = getSelectedBuyerLot().LotId,
				ItemId = itemId,
				Quantity = 5,
			})
		end, 34)
	end
end

local function renderPizzeria(state)
	makeSection(content, "ESTOQUE DA PIZZARIA")
	for _, itemId in ipairs(EconomyConfig.InventoryOrder) do
		local item = EconomyConfig.Items[itemId]
		makeLabel(content, string.format("%s: %d", item.DisplayName, state.Economy.Inventory[itemId] or 0), 25, itemId == "Pizza")
	end

	makeSection(content, "COZINHA")
	makeLabel(content, "Receita: 2 farinha + 1 queijo + 1 tomate = 1 pizza.", 36, false)
	makeButton(content, "ASSAR 1 PIZZA", function()
		perform({ Action = "BakePizza", LotId = currentLotId, Quantity = 1 })
	end)
	makeButton(content, "ASSAR 5 PIZZAS", function()
		perform({ Action = "BakePizza", LotId = currentLotId, Quantity = 5 })
	end)

	makeSection(content, "CLIENTES DA CIDADE")
	local readyIn = state.Economy.ServeReadyIn or 0
	local serveText = readyIn > 0
		and string.format("NOVOS CLIENTES EM %ds", readyIn)
		or string.format("ATENDER CLIENTES · ATÉ 5 PIZZAS A %s", formatMoney(EconomyConfig.CityPizzaPrice))
	makeButton(content, serveText, function()
		perform({ Action = "ServeCity", LotId = currentLotId })
	end)
	makeLabel(content, "Para reabastecer ingredientes, visite a placa de uma Fazenda de outro jogador que esteja neste servidor.", 48, false)
end

local function renderState(state)
	clearContent()
	currentState = state

	titleLabel.Text = string.upper(state.Target.DisplayName)
	subtitleLabel.Text = string.format("%s · proprietário #%d", state.Target.LotId, state.Target.OwnerUserId)

	if state.Target.IsOwner then
		renderCashControls(state)
	end

	if state.Target.BusinessType == "Farm" then
		if state.Target.IsOwner then
			renderFarmManagement(state)
		else
			renderFarmStock(state)
		end
		renderFarmPurchasing(state)
	elseif state.Target.BusinessType == "Pizzeria" then
		if state.Target.IsOwner then
			renderPizzeria(state)
		else
			makeSection(content, "PIZZARIA")
			makeLabel(content, "Esta Pizzaria é administrada por outro jogador. Compras de clientes entre jogadores entram em uma etapa futura.", 55, false)
		end
	else
		makeSection(content, "OPERAÇÃO")
		makeLabel(content, "A licença desta empresa já é válida, mas o módulo operacional deste setor será conectado nas próximas cadeias econômicas.", 60, false)
	end

	makeSection(content, "INDICADORES")
	local stats = state.Economy.Stats or {}
	makeLabel(
		content,
		string.format(
			"Produzido: %d · vendido a jogadores: %d · comprado de jogadores: %d · vendas à cidade: %d",
			stats.Produced or 0,
			stats.SoldToPlayers or 0,
			stats.PurchasedFromPlayers or 0,
			stats.CitySales or 0
		),
		48,
		false
	)
	makeButton(content, "ATUALIZAR DADOS", function()
		refresh(true)
	end)
end

refresh = function(showStatus)
	if busy or not currentLotId then
		return
	end
	busy = true
	if showStatus then
		setStatus("Atualizando empresa...", false)
	end

	local success, state = pcall(function()
		return getStateRemote:InvokeServer(currentLotId)
	end)
	busy = false

	if not success or type(state) ~= "table" then
		setStatus("Não foi possível carregar esta empresa", true)
		return
	end
	if not state.Ok then
		setStatus(state.Error or "Empresa indisponível", true)
		return
	end

	if type(state.BuyerPizzerias) == "table" and #state.BuyerPizzerias > 0 then
		selectedBuyerIndex = math.clamp(selectedBuyerIndex, 1, #state.BuyerPizzerias)
	else
		selectedBuyerIndex = 1
	end
	renderState(state)
	if showStatus then
		setStatus("Dados atualizados", false)
	end
end

function BusinessEconomyController:Start()
	createGui()

	openRemote.OnClientEvent:Connect(function(lotId)
		if type(lotId) ~= "string" then
			return
		end
		currentLotId = lotId
		selectedBuyerIndex = 1
		panel.Visible = true
		setStatus("Carregando empresa...", false)
		refresh(false)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not panel.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			panel.Visible = false
			currentLotId = nil
			currentState = nil
		end
	end)

	print("[Property Empire v2] BusinessEconomyController started")
end

return BusinessEconomyController
