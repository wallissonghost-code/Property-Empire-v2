local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("CommerceExpansionConfig"))

local CommerceExpansionController = {}
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local openRemote = remotes:WaitForChild("OpenCommerceExpansion")
local getStateRemote = remotes:WaitForChild("GetCommerceExpansionState")
local actionRemote = remotes:WaitForChild("CommerceExpansionAction")

local gui
local panel
local titleLabel
local subtitleLabel
local statusLabel
local content
local currentLotId
local currentState
local selectedFactoryIndex = 1
local selectedTargetIndex = 1
local busy = false

local function formatMoney(value)
	local text = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	while true do
		local replaced, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1.%2")
		text = replaced
		if count == 0 then break end
	end
	return "$" .. text
end

local function corner(parent, radius)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function stroke(parent)
	local value = Instance.new("UIStroke")
	value.Color = Color3.fromRGB(68, 81, 94)
	value.Thickness = 1
	value.Transparency = 0.12
	value.Parent = parent
end

local function label(parent, text, height, bold, color)
	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -4, 0, height or 28)
	value.BackgroundTransparency = 1
	value.Text = text
	value.TextColor3 = color or Color3.fromRGB(229, 234, 240)
	value.TextSize = bold and 14 or 13
	value.TextWrapped = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Center
	value.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	value.Parent = parent
	return value
end

local function button(parent, text, callback, height, color)
	local value = Instance.new("TextButton")
	value.Size = UDim2.new(1, -4, 0, height or 38)
	value.BackgroundColor3 = color or Color3.fromRGB(47, 75, 100)
	value.Text = text
	value.TextColor3 = Color3.fromRGB(247, 249, 251)
	value.TextSize = 13
	value.TextWrapped = true
	value.Font = Enum.Font.GothamSemibold
	value.AutoButtonColor = true
	value.Parent = parent
	corner(value, 9)
	stroke(value)
	value.Activated:Connect(callback)
	return value
end

local function section(text)
	local value = label(content, text, 30, true, Color3.fromRGB(115, 204, 187))
	value.TextSize = 12
	return value
end

local function setStatus(text, isError)
	if not statusLabel then return end
	statusLabel.Text = text or ""
	statusLabel.TextColor3 = isError and Color3.fromRGB(255, 153, 153) or Color3.fromRGB(154, 224, 182)
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
	gui.Name = "PropertyEmpireCommerceExpansionGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "CommerceExpansionPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Size = UDim2.new(0.92, 0, 0.88, 0)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(20, 25, 31)
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(310, 430)
	sizeConstraint.MaxSize = Vector2.new(570, 700)
	sizeConstraint.Parent = panel

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -96, 0, 32)
	titleLabel.Position = UDim2.fromOffset(18, 14)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "COMÉRCIO"
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
	subtitleLabel.TextColor3 = Color3.fromRGB(146, 158, 170)
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
	corner(closeButton, 8)
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
	statusLabel.TextColor3 = Color3.fromRGB(154, 224, 182)
	statusLabel.TextSize = 12
	statusLabel.TextWrapped = true
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = panel
	corner(statusLabel, 8)

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
	corner(content, 10)

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
	if busy or not currentLotId then return end
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

local function renderCash(state)
	section("CAIXA DA EMPRESA")
	label(content, string.format("Empresa: %s   ·   pessoal: %s", formatMoney(state.Economy.BusinessCash), formatMoney(state.PersonalCash)), 32, true)
	button(content, "DEPOSITAR $10.000", function()
		perform({ Action = "Deposit", LotId = currentLotId, Amount = 10000 })
	end)
	button(content, "SACAR $10.000", function()
		perform({ Action = "Withdraw", LotId = currentLotId, Amount = 10000 })
	end)
end

local function selectedFactory()
	local factories = currentState and currentState.BuyerFactories or {}
	if #factories == 0 then return nil end
	selectedFactoryIndex = math.clamp(selectedFactoryIndex, 1, #factories)
	return factories[selectedFactoryIndex]
end

local function selectedTarget()
	local targets = currentState and currentState.MarketingTargets or {}
	if #targets == 0 then return nil end
	selectedTargetIndex = math.clamp(selectedTargetIndex, 1, #targets)
	return targets[selectedTargetIndex]
end

local function renderLumberOwner(state)
	section("PRODUÇÃO DE MADEIRA")
	local ready = state.Economy.ProductionReadyIn or 0
	button(content, ready > 0 and string.format("NOVO LOTE EM %ds", ready) or "SERRAR NOVO LOTE", function()
		perform({ Action = "ProduceLumber", LotId = currentLotId })
	end, 42, Color3.fromRGB(104, 75, 43))
	label(content, string.format("Estoque: %d madeira · preço: %s/unidade", state.Economy.Inventory.Wood or 0, formatMoney(state.Economy.WoodPrice)), 34, true)
	button(content, string.format("PREÇO -%s", formatMoney(Config.WoodPriceStep)), function()
		perform({ Action = "SetWoodPrice", LotId = currentLotId, Delta = -Config.WoodPriceStep })
	end, 32)
	button(content, string.format("PREÇO +%s", formatMoney(Config.WoodPriceStep)), function()
		perform({ Action = "SetWoodPrice", LotId = currentLotId, Delta = Config.WoodPriceStep })
	end, 32)
end

local function renderLumberMarket(state)
	section("COMPRAR MADEIRA")
	local factories = state.BuyerFactories or {}
	if #factories == 0 then
		label(content, "Você precisa ter uma Fábrica de Móveis licenciada para comprar madeira como empresa.", 48, false)
		return
	end
	local factory = selectedFactory()
	button(content, string.format("FÁBRICA: %s · CAIXA %s", factory.LotId, formatMoney(factory.BusinessCash)), function()
		selectedFactoryIndex += 1
		if selectedFactoryIndex > #factories then selectedFactoryIndex = 1 end
		refresh(false)
	end)
	if not state.Target.OwnerOnline then
		label(content, "O dono da Madeireira precisa estar neste servidor para negociar.", 42, false)
		return
	end
	local unitPrice = state.Economy.WoodPrice or 0
	label(content, string.format("Fornecedor: %d madeira · %s/unidade", state.Economy.Inventory.Wood or 0, formatMoney(unitPrice)), 32, true)
	for _, quantity in ipairs({ 1, 5, 10 }) do
		button(content, string.format("COMPRAR %d · %s", quantity, formatMoney(unitPrice * quantity)), function()
			local target = selectedFactory()
			if target then
				perform({ Action = "BuyWood", SellerLotId = currentLotId, BuyerLotId = target.LotId, Quantity = quantity })
			end
		end, 34, Color3.fromRGB(58, 98, 77))
	end
end

local function renderFurniture(state)
	section("ESTOQUE E PRODUÇÃO")
	label(content, string.format("Madeira disponível: %d", state.Economy.Inventory.Wood or 0), 30, true)
	for _, itemId in ipairs(Config.FurnitureOrder) do
		local recipe = Config.FurnitureRecipes[itemId]
		local item = Config.Items[itemId]
		label(content, string.format("%s: %d · receita: %d madeira", item.DisplayName, state.Economy.Inventory[itemId] or 0, recipe.Wood), 30, true)
		button(content, "PRODUZIR 1 " .. string.upper(item.DisplayName), function()
			perform({ Action = "CraftFurniture", LotId = currentLotId, ItemId = itemId, Quantity = 1 })
		end, 34)
		button(content, "PRODUZIR 5 " .. string.upper(item.DisplayName), function()
			perform({ Action = "CraftFurniture", LotId = currentLotId, ItemId = itemId, Quantity = 5 })
		end, 34)
	end

	section("PEDIDOS DA CIDADE")
	local ready = state.Economy.ServeReadyIn or 0
	if ready > 0 then label(content, string.format("Novos pedidos em %ds", ready), 30, true) end
	local boost = state.Economy.MarketingBoostReadyIn or 0
	if boost > 0 then
		label(content, string.format("Campanha ativa por mais %ds · demanda +%d%%", boost, math.floor(Config.CampaignDemandBoost * 100)), 34, true, Color3.fromRGB(238, 198, 109))
	end
	for _, itemId in ipairs(Config.FurnitureOrder) do
		local item = Config.Items[itemId]
		button(content, string.format("VENDER %s · %s CADA", string.upper(item.DisplayName), formatMoney(Config.FurnitureCityPrices[itemId])), function()
			perform({ Action = "SellFurnitureCity", LotId = currentLotId, ItemId = itemId })
		end, 38, Color3.fromRGB(66, 87, 122))
	end
	label(content, "Para obter madeira, abra o terminal de uma Madeireira. Marketing aumenta temporariamente a quantidade de pedidos atendidos.", 48, false)
end

local function renderAgencyOwner(state)
	section("PACOTE DE CAMPANHA")
	label(content, string.format("Preço atual: %s · campanhas vendidas: %d", formatMoney(state.Economy.CampaignPrice), (state.Economy.Stats or {}).CampaignsSold or 0), 34, true)
	button(content, string.format("PREÇO -%s", formatMoney(Config.CampaignPriceStep)), function()
		perform({ Action = "SetCampaignPrice", LotId = currentLotId, Delta = -Config.CampaignPriceStep })
	end, 32)
	button(content, string.format("PREÇO +%s", formatMoney(Config.CampaignPriceStep)), function()
		perform({ Action = "SetCampaignPrice", LotId = currentLotId, Delta = Config.CampaignPriceStep })
	end, 32)
	label(content, string.format("Cada campanha dura %ds, aumenta a demanda em %d%% e acrescenta %d pontos de reputação de marketing.", Config.CampaignDurationSeconds, math.floor(Config.CampaignDemandBoost * 100), Config.CampaignReputationGain), 54, false)
end

local function renderCampaignMarket(state)
	section("CONTRATAR CAMPANHA")
	local targets = state.MarketingTargets or {}
	if #targets == 0 then
		label(content, "Você precisa ter outra empresa licenciada para anunciar.", 42, false)
		return
	end
	local target = selectedTarget()
	button(content, string.format("ANUNCIAR: %s · %s", target.LotId, target.DisplayName), function()
		selectedTargetIndex += 1
		if selectedTargetIndex > #targets then selectedTargetIndex = 1 end
		refresh(false)
	end)
	label(content, string.format("Reputação: %d · campanha restante: %ds", target.Reputation or 0, target.BoostReadyIn or 0), 32, true)
	if not state.Target.OwnerOnline then
		label(content, "O dono desta Agência precisa estar neste servidor para contratar o serviço.", 42, false)
		return
	end
	button(content, string.format("CONTRATAR · %s", formatMoney(state.Economy.CampaignPrice)), function()
		local selected = selectedTarget()
		if selected then
			perform({ Action = "BuyCampaign", AgencyLotId = currentLotId, TargetLotId = selected.LotId })
		end
	end, 42, Color3.fromRGB(89, 67, 116))
end

local function renderStats(state)
	section("INDICADORES")
	local stats = state.Economy.Stats or {}
	if state.Target.BusinessType == "LumberCompany" then
		label(content, string.format("Produzido: %d · vendido a fábricas: %d", stats.Produced or 0, stats.SoldToPlayers or 0), 32, false)
	elseif state.Target.BusinessType == "FurnitureFactory" then
		label(content, string.format("Produzido: %d · madeira comprada: %d · vendas cidade: %d · receita: %s", stats.Produced or 0, stats.PurchasedFromPlayers or 0, stats.CitySales or 0, formatMoney(stats.CityRevenue or 0)), 48, false)
	else
		label(content, string.format("Campanhas vendidas: %d", stats.CampaignsSold or 0), 30, false)
	end
	button(content, "ATUALIZAR DADOS", function() refresh(true) end)
end

local function renderState(state)
	clearContent()
	currentState = state
	titleLabel.Text = string.upper(state.Target.DisplayName)
	subtitleLabel.Text = string.format("%s · proprietário #%d", state.Target.LotId, state.Target.OwnerUserId)
	if state.Target.IsOwner then renderCash(state) end

	if state.Target.BusinessType == "LumberCompany" then
		if state.Target.IsOwner then renderLumberOwner(state) end
		if not state.Target.IsOwner or #(state.BuyerFactories or {}) > 0 then renderLumberMarket(state) end
	elseif state.Target.BusinessType == "FurnitureFactory" then
		if state.Target.IsOwner then
			renderFurniture(state)
		else
			section("FÁBRICA DE MÓVEIS")
			label(content, "Esta fábrica transforma madeira em móveis e vende para a cidade. Comércio direto de móveis entre jogadores entra no próximo polimento.", 54, false)
		end
	elseif state.Target.BusinessType == "MarketingAgency" then
		if state.Target.IsOwner then renderAgencyOwner(state) end
		renderCampaignMarket(state)
	end
	renderStats(state)
end

refresh = function(showStatus)
	if busy or not currentLotId then return end
	busy = true
	if showStatus then setStatus("Atualizando...", false) end
	local success, state = pcall(function()
		return getStateRemote:InvokeServer(currentLotId)
	end)
	busy = false
	if not success or type(state) ~= "table" then setStatus("Não foi possível carregar esta empresa", true) return end
	if not state.Ok then setStatus(state.Error or "Empresa indisponível", true) return end
	selectedFactoryIndex = math.clamp(selectedFactoryIndex, 1, math.max(1, #(state.BuyerFactories or {})))
	selectedTargetIndex = math.clamp(selectedTargetIndex, 1, math.max(1, #(state.MarketingTargets or {})))
	renderState(state)
	if showStatus then setStatus("Dados atualizados", false) end
end

function CommerceExpansionController:Start()
	createGui()
	openRemote.OnClientEvent:Connect(function(lotId)
		if type(lotId) ~= "string" then return end
		currentLotId = lotId
		selectedFactoryIndex = 1
		selectedTargetIndex = 1
		panel.Visible = true
		setStatus("Carregando operação...", false)
		refresh(false)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not panel.Visible then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			panel.Visible = false
			currentLotId = nil
			currentState = nil
		end
	end)
	print("[Property Empire v2] CommerceExpansionController started")
end

return CommerceExpansionController
