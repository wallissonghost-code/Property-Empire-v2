local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("MiningMuseumConfig"))

local MiningMuseumController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openRemote = remotes:WaitForChild("OpenMiningMuseum")
local getStateRemote = remotes:WaitForChild("GetMiningMuseumState")
local actionRemote = remotes:WaitForChild("MiningMuseumAction")

local gui = nil
local panel = nil
local titleLabel = nil
local subtitleLabel = nil
local statusLabel = nil
local content = nil
local currentLotId = nil
local currentState = nil
local selectedMuseumIndex = 1
local busy = false

local RARITY_COLORS = {
	Common = Color3.fromRGB(187, 197, 207),
	Uncommon = Color3.fromRGB(111, 214, 145),
	Rare = Color3.fromRGB(94, 164, 255),
	Epic = Color3.fromRGB(186, 111, 255),
	Legendary = Color3.fromRGB(255, 190, 82),
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
end

local function makeStroke(parent, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(64, 75, 88)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = parent
end

local function makeLabel(parent, text, height, bold, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -4, 0, height or 28)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(228, 233, 239)
	label.TextSize = bold and 14 or 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.Parent = parent
	return label
end

local function makeButton(parent, text, callback, height, accent)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -4, 0, height or 38)
	button.BackgroundColor3 = accent or Color3.fromRGB(45, 72, 96)
	button.TextColor3 = Color3.fromRGB(246, 248, 250)
	button.Text = text
	button.TextSize = 13
	button.TextWrapped = true
	button.Font = Enum.Font.GothamSemibold
	button.AutoButtonColor = true
	button.Parent = parent
	makeCorner(button, 9)
	makeStroke(button)
	button.Activated:Connect(callback)
	return button
end

local function makeSection(parent, text)
	local label = makeLabel(parent, text, 30, true, Color3.fromRGB(111, 207, 177))
	label.TextSize = 12
	return label
end

local function setStatus(text, isError)
	if not statusLabel then
		return
	end
	statusLabel.Text = text or ""
	statusLabel.TextColor3 = isError and Color3.fromRGB(255, 154, 154) or Color3.fromRGB(151, 224, 180)
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
	gui.Name = "PropertyEmpireMiningMuseumGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "MiningMuseumPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.88, 0)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(20, 25, 31)
	panel.Visible = false
	panel.Parent = gui
	makeCorner(panel, 14)
	makeStroke(panel, Color3.fromRGB(73, 111, 105))

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(310, 430)
	sizeConstraint.MaxSize = Vector2.new(570, 700)
	sizeConstraint.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -96, 0, 32)
	titleLabel.Position = UDim2.fromOffset(18, 14)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "MINERAÇÃO & MUSEU"
	titleLabel.TextColor3 = Color3.fromRGB(248, 249, 251)
	titleLabel.TextSize = 19
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = panel

	subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, -96, 0, 22)
	subtitleLabel.Position = UDim2.fromOffset(18, 47)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = ""
	subtitleLabel.TextColor3 = Color3.fromRGB(145, 157, 169)
	subtitleLabel.TextSize = 12
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(54, 36)
	closeButton.Position = UDim2.new(1, -72, 0, 16)
	closeButton.BackgroundColor3 = Color3.fromRGB(69, 45, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(250, 231, 233)
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
	statusLabel.Size = UDim2.new(1, -36, 0, 44)
	statusLabel.Position = UDim2.fromOffset(18, 76)
	statusLabel.BackgroundColor3 = Color3.fromRGB(29, 36, 43)
	statusLabel.BackgroundTransparency = 0.12
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(151, 224, 180)
	statusLabel.TextSize = 12
	statusLabel.TextWrapped = true
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = panel
	makeCorner(statusLabel, 8)

	content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -36, 1, -140)
	content.Position = UDim2.fromOffset(18, 128)
	content.BackgroundColor3 = Color3.fromRGB(25, 31, 38)
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = panel
	makeCorner(content, 10)

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
		string.format("Empresa: %s   ·   Pessoal: %s", formatMoney(state.Economy.BusinessCash), formatMoney(state.PersonalCash)),
		32,
		true
	)
	makeButton(content, "DEPOSITAR $10.000", function()
		perform({ Action = "Deposit", LotId = currentLotId, Amount = 10000 })
	end)
	makeButton(content, "SACAR $10.000", function()
		perform({ Action = "Withdraw", LotId = currentLotId, Amount = 10000 })
	end)
end

local function appraisalText(specimen)
	if not specimen.Appraised then
		return "NÃO AVALIADO"
	end
	if specimen.Appraisal == "Authentic" then
		return "AUTÊNTICO ✓"
	end
	return "FALSO ✕"
end

local function renderSpecimenHeader(specimen)
	local rarityColor = RARITY_COLORS[specimen.Rarity] or Color3.fromRGB(220, 225, 230)
	local suffix = specimen.Displayed and " · EM EXPOSIÇÃO" or ""
	makeLabel(
		content,
		string.format("[%s] %s%s", string.upper(specimen.RarityLabel or specimen.Rarity), specimen.DisplayName, suffix),
		30,
		true,
		rarityColor
	)
	local details = string.format("%s · oferta %s", appraisalText(specimen), formatMoney(specimen.AskingPrice))
	if specimen.Appraised and specimen.Appraisal == "Authentic" then
		details ..= string.format(" · avaliação ~%s", formatMoney(specimen.EstimatedValue or 0))
	end
	makeLabel(content, details, 28, false)
end

local function getSelectedMuseum()
	local buyers = currentState and currentState.BuyerMuseums or {}
	if #buyers == 0 then
		return nil
	end
	selectedMuseumIndex = math.clamp(selectedMuseumIndex, 1, #buyers)
	return buyers[selectedMuseumIndex]
end

local function renderMiningOwner(state)
	makeSection(content, "EXTRAÇÃO")
	local readyIn = state.Economy.MiningReadyIn or 0
	local buttonText = readyIn > 0 and string.format("NOVA FRENTE EM %ds", readyIn) or "EXTRAIR NOVO ACHADO"
	makeButton(content, buttonText, function()
		perform({ Action = "MineSpecimen", LotId = currentLotId })
	end, 42, Color3.fromRGB(105, 78, 44))
	makeLabel(content, "Quartzo, ouro, esmeraldas, diamantes e fósseis podem aparecer. Algumas raridades podem ser falsificações e a Mineradora não sabe antes da avaliação.", 58, false)

	makeSection(content, "COFRE DE ACHADOS")
	local specimens = state.Economy.Specimens or {}
	if #specimens == 0 then
		makeLabel(content, "Nenhum achado ainda. Abra uma nova frente de extração.", 38, false)
		return
	end
	for _, specimen in ipairs(specimens) do
		renderSpecimenHeader(specimen)
		makeButton(content, string.format("PREÇO -%s", formatMoney(Config.SpecimenPriceStep)), function()
			perform({ Action = "SetSpecimenPrice", LotId = currentLotId, SpecimenId = specimen.Id, Delta = -Config.SpecimenPriceStep })
		end, 32)
		makeButton(content, string.format("PREÇO +%s", formatMoney(Config.SpecimenPriceStep)), function()
			perform({ Action = "SetSpecimenPrice", LotId = currentLotId, SpecimenId = specimen.Id, Delta = Config.SpecimenPriceStep })
		end, 32)
	end
end

local function renderMiningMarket(state)
	makeSection(content, "MERCADO DE ACHADOS")
	local museums = state.BuyerMuseums or {}
	if #museums == 0 then
		makeLabel(content, "Você precisa ter um Museu licenciado para comprar peças desta Mineradora.", 48, false)
		return
	end
	local selected = getSelectedMuseum()
	makeButton(content, string.format("MUSEU COMPRADOR: %s · CAIXA %s", selected.LotId, formatMoney(selected.BusinessCash)), function()
		selectedMuseumIndex += 1
		if selectedMuseumIndex > #museums then
			selectedMuseumIndex = 1
		end
		refresh(false)
	end)
	if not state.Target.OwnerOnline then
		makeLabel(content, "O dono desta Mineradora precisa estar neste servidor para concluir a negociação.", 48, false)
		return
	end

	local specimens = state.Economy.Specimens or {}
	if #specimens == 0 then
		makeLabel(content, "Esta Mineradora não possui achados à venda.", 36, false)
		return
	end
	for _, specimen in ipairs(specimens) do
		renderSpecimenHeader(specimen)
		makeButton(content, string.format("COMPRAR PARA %s · %s", selected.LotId, formatMoney(specimen.AskingPrice)), function()
			local buyer = getSelectedMuseum()
			if buyer then
				perform({ Action = "BuySpecimen", SellerLotId = currentLotId, BuyerLotId = buyer.LotId, SpecimenId = specimen.Id })
			end
		end, 38, Color3.fromRGB(55, 102, 77))
	end
end

local function renderMuseumOwner(state)
	makeSection(content, "PRESTÍGIO DO MUSEU")
	makeLabel(
		content,
		string.format("Prestígio: %d   ·   exposição: %d/%d", state.Economy.Prestige or 0, state.Economy.DisplayedCount or 0, Config.MaxDisplayedSpecimens),
		34,
		true,
		Color3.fromRGB(238, 198, 109)
	)
	local readyIn = state.Economy.MuseumReadyIn or 0
	local openText = readyIn > 0 and string.format("NOVO GRUPO EM %ds", readyIn) or "ABRIR PARA VISITANTES"
	makeButton(content, openText, function()
		perform({ Action = "OpenMuseum", LotId = currentLotId })
	end, 42, Color3.fromRGB(74, 81, 121))
	makeLabel(content, "A receita de visitantes cresce com o prestígio das peças autênticas que estiverem em exposição.", 44, false)

	makeSection(content, "RESERVA TÉCNICA E EXPOSIÇÃO")
	local specimens = state.Economy.Specimens or {}
	if #specimens == 0 then
		makeLabel(content, "Coleção vazia. Visite uma Mineradora de outro jogador para adquirir achados.", 48, false)
		return
	end
	for _, specimen in ipairs(specimens) do
		renderSpecimenHeader(specimen)
		if not specimen.Appraised then
			makeButton(content, string.format("AVALIAR · %s", formatMoney(Config.AppraisalFee)), function()
				perform({ Action = "AppraiseSpecimen", LotId = currentLotId, SpecimenId = specimen.Id })
			end, 36, Color3.fromRGB(78, 69, 104))
		elseif specimen.Appraisal == "Authentic" then
			makeButton(content, specimen.Displayed and "RETIRAR DA EXPOSIÇÃO" or "COLOCAR EM EXPOSIÇÃO", function()
				perform({ Action = "ToggleDisplay", LotId = currentLotId, SpecimenId = specimen.Id })
			end, 36, specimen.Displayed and Color3.fromRGB(77, 62, 67) or Color3.fromRGB(62, 102, 80))
		else
			makeButton(content, "DESCARTAR FALSIFICAÇÃO", function()
				perform({ Action = "DiscardFake", LotId = currentLotId, SpecimenId = specimen.Id })
			end, 36, Color3.fromRGB(98, 55, 59))
		end
	end
end

local function renderMuseumVisitor(state)
	makeSection(content, "EXPOSIÇÃO ATUAL")
	makeLabel(content, string.format("Prestígio público: %d", state.Economy.Prestige or 0), 32, true, Color3.fromRGB(238, 198, 109))
	local specimens = state.Economy.Specimens or {}
	if #specimens == 0 then
		makeLabel(content, "Este Museu ainda não possui peças autênticas em exposição.", 42, false)
		return
	end
	for _, specimen in ipairs(specimens) do
		renderSpecimenHeader(specimen)
	end
end

local function renderStats(state)
	makeSection(content, "INDICADORES")
	local stats = state.Economy.Stats or {}
	if state.Target.BusinessType == "MiningCompany" then
		makeLabel(content, string.format("Extraídos: %d · vendidos: %d", stats.Mined or 0, stats.Sold or 0), 32, false)
	else
		makeLabel(
			content,
			string.format("Comprados: %d · avaliados: %d · falsos: %d · visitantes: %d · receita: %s", stats.Purchased or 0, stats.Appraised or 0, stats.FakesFound or 0, stats.CityVisitors or 0, formatMoney(stats.CityRevenue or 0)),
			52,
			false
		)
	end
	makeButton(content, "ATUALIZAR DADOS", function()
		refresh(true)
	end)
end

local function renderState(state)
	clearContent()
	currentState = state
	titleLabel.Text = string.upper(state.Target.DisplayName)
	subtitleLabel.Text = string.format("%s · proprietário #%d", state.Target.LotId, state.Target.OwnerUserId)

	if state.Target.IsOwner then
		renderCashControls(state)
	end

	if state.Target.BusinessType == "MiningCompany" then
		if state.Target.IsOwner then
			renderMiningOwner(state)
			-- Owners may also operate a Museum. Keep the market visible so a
			-- single player can move finds between their own licensed companies.
			if type(state.BuyerMuseums) == "table" and #state.BuyerMuseums > 0 then
				renderMiningMarket(state)
			end
		else
			renderMiningMarket(state)
		end
	elseif state.Target.BusinessType == "Museum" then
		if state.Target.IsOwner then
			renderMuseumOwner(state)
		else
			renderMuseumVisitor(state)
		end
	end
	renderStats(state)
end

refresh = function(showStatus)
	if busy or not currentLotId then
		return
	end
	busy = true
	if showStatus then
		setStatus("Atualizando...", false)
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
	if type(state.BuyerMuseums) == "table" and #state.BuyerMuseums > 0 then
		selectedMuseumIndex = math.clamp(selectedMuseumIndex, 1, #state.BuyerMuseums)
	else
		selectedMuseumIndex = 1
	end
	renderState(state)
	if showStatus then
		setStatus("Dados atualizados", false)
	end
end

function MiningMuseumController:Start()
	createGui()
	openRemote.OnClientEvent:Connect(function(lotId)
		if type(lotId) ~= "string" then
			return
		end
		currentLotId = lotId
		selectedMuseumIndex = 1
		panel.Visible = true
		setStatus("Carregando cadeia de raridades...", false)
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

	print("[Property Empire v2] MiningMuseumController started")
end

return MiningMuseumController
