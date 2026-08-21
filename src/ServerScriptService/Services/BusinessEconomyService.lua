local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessConfig = require(Shared.BusinessConfig)
local EconomyConfig = require(Shared.BusinessEconomyConfig)

local BusinessEconomyService = {}
local economyStore = DataStoreService:GetDataStore(EconomyConfig.DataStoreName)

local playerDataService = nil
local started = false
local records = {}
local lotLocks = {}
local lastActionAt = {}
local openRemote = nil

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local result = {}
	for key, child in pairs(value) do
		result[key] = deepCopy(child)
	end
	return result
end

local function getWorld()
	return Workspace:FindFirstChild("PropertyEmpireV2World")
end

local function getLot(lotId)
	local world = getWorld()
	local lots = world and world:FindFirstChild("Lots")
	local lot = lots and lots:FindFirstChild(lotId)
	if lot and lot:IsA("BasePart") then
		return lot
	end
	return nil
end

local function getActiveBusiness(lotId)
	local lot = getLot(lotId)
	if not lot then
		return nil
	end

	local businessType = lot:GetAttribute("BusinessType")
	local ownerUserId = tonumber(lot:GetAttribute("BusinessOwnerUserId")) or 0
	if ownerUserId <= 0 or type(businessType) ~= "string" or not BusinessConfig.Types[businessType] then
		return nil
	end

	return {
		Lot = lot,
		LotId = lotId,
		OwnerUserId = ownerUserId,
		BusinessType = businessType,
	}
end

local function economyKey(lotId)
	return "economy_" .. lotId
end

local function makeDefaultRecord(active)
	local inventory = {}
	for itemId in pairs(EconomyConfig.Items) do
		inventory[itemId] = 0
	end

	local prices = {}
	for _, itemId in ipairs(EconomyConfig.FarmItemOrder) do
		prices[itemId] = EconomyConfig.Items[itemId].DefaultFarmPrice
	end

	return {
		Version = EconomyConfig.DataVersion,
		LotId = active.LotId,
		OwnerUserId = active.OwnerUserId,
		BusinessType = active.BusinessType,
		BusinessCash = 0,
		Inventory = inventory,
		Prices = prices,
		ProductionReadyAt = 0,
		ServeReadyAt = 0,
		Stats = {
			Produced = 0,
			SoldToPlayers = 0,
			PurchasedFromPlayers = 0,
			CitySales = 0,
		},
	}
end

local function normalizeRecord(active, record)
	if type(record) ~= "table"
		or tonumber(record.OwnerUserId) ~= active.OwnerUserId
		or record.BusinessType ~= active.BusinessType
	then
		return makeDefaultRecord(active)
	end

	record.Version = EconomyConfig.DataVersion
	record.LotId = active.LotId
	record.OwnerUserId = active.OwnerUserId
	record.BusinessType = active.BusinessType
	record.BusinessCash = math.max(0, math.floor(tonumber(record.BusinessCash) or 0))
	record.ProductionReadyAt = math.max(0, math.floor(tonumber(record.ProductionReadyAt) or 0))
	record.ServeReadyAt = math.max(0, math.floor(tonumber(record.ServeReadyAt) or 0))

	if type(record.Inventory) ~= "table" then
		record.Inventory = {}
	end
	for itemId in pairs(EconomyConfig.Items) do
		record.Inventory[itemId] = math.clamp(
			math.floor(tonumber(record.Inventory[itemId]) or 0),
			0,
			EconomyConfig.MaxInventoryPerItem
		)
	end

	if type(record.Prices) ~= "table" then
		record.Prices = {}
	end
	for _, itemId in ipairs(EconomyConfig.FarmItemOrder) do
		local defaultPrice = EconomyConfig.Items[itemId].DefaultFarmPrice
		record.Prices[itemId] = math.clamp(
			math.floor(tonumber(record.Prices[itemId]) or defaultPrice),
			EconomyConfig.MinSalePrice,
			EconomyConfig.MaxSalePrice
		)
	end

	if type(record.Stats) ~= "table" then
		record.Stats = {}
	end
	for _, key in ipairs({ "Produced", "SoldToPlayers", "PurchasedFromPlayers", "CitySales" }) do
		record.Stats[key] = math.max(0, math.floor(tonumber(record.Stats[key]) or 0))
	end

	return record
end

local function loadRecord(lotId)
	local active = getActiveBusiness(lotId)
	if not active then
		records[lotId] = nil
		return nil
	end

	local cached = records[lotId]
	if cached and cached.OwnerUserId == active.OwnerUserId and cached.BusinessType == active.BusinessType then
		return cached
	end

	local success, stored = pcall(function()
		return economyStore:GetAsync(economyKey(lotId))
	end)
	if not success then
		warn(string.format("[BusinessEconomyService] Failed to load economy for %s", lotId))
		return nil
	end

	local record = normalizeRecord(active, stored)
	records[lotId] = record
	return record
end

local function saveRecord(lotId)
	local record = records[lotId]
	if not record then
		return false
	end

	local snapshot = deepCopy(record)
	local success, errorMessage = pcall(function()
		economyStore:SetAsync(economyKey(lotId), snapshot)
	end)
	if not success then
		warn(string.format("[BusinessEconomyService] Failed to save %s: %s", lotId, tostring(errorMessage)))
	end
	return success
end

local function acquireLots(lotIds)
	local unique = {}
	for _, lotId in ipairs(lotIds) do
		if not unique[lotId] then
			unique[lotId] = true
		end
	end

	local ordered = {}
	for lotId in pairs(unique) do
		table.insert(ordered, lotId)
	end
	table.sort(ordered)

	for _, lotId in ipairs(ordered) do
		if lotLocks[lotId] then
			return nil
		end
	end
	for _, lotId in ipairs(ordered) do
		lotLocks[lotId] = true
	end
	return ordered
end

local function releaseLots(ordered)
	if not ordered then
		return
	end
	for _, lotId in ipairs(ordered) do
		lotLocks[lotId] = nil
	end
end

local function playerOwnsBusiness(player, lotId, requiredType)
	local active = getActiveBusiness(lotId)
	if not active or active.OwnerUserId ~= player.UserId then
		return false
	end
	if requiredType and active.BusinessType ~= requiredType then
		return false
	end
	return true
end

local function getOwnedPizzerias(player)
	local data = playerDataService and playerDataService:Get(player)
	local result = {}
	if not data or type(data.OwnedLots) ~= "table" then
		return result
	end

	for _, lotId in ipairs(data.OwnedLots) do
		local active = getActiveBusiness(lotId)
		if active and active.OwnerUserId == player.UserId and active.BusinessType == "Pizzeria" then
			local record = loadRecord(lotId)
			if record then
				table.insert(result, {
					LotId = lotId,
					BusinessCash = record.BusinessCash,
				})
			end
		end
	end

	return result
end

local function getState(player, targetLotId)
	if type(targetLotId) ~= "string" or #targetLotId > 32 then
		return { Ok = false, Error = "Empresa inválida" }
	end

	local active = getActiveBusiness(targetLotId)
	if not active then
		return { Ok = false, Error = "Este lote não possui uma empresa ativa" }
	end

	local record = loadRecord(targetLotId)
	if not record then
		return { Ok = false, Error = "Não foi possível carregar o caixa desta empresa" }
	end

	local spec = BusinessConfig.Types[active.BusinessType]
	local ownerPlayer = Players:GetPlayerByUserId(active.OwnerUserId)
	return {
		Ok = true,
		ServerTime = os.time(),
		Target = {
			LotId = targetLotId,
			OwnerUserId = active.OwnerUserId,
			BusinessType = active.BusinessType,
			DisplayName = spec.DisplayName,
			IsOwner = active.OwnerUserId == player.UserId,
			OwnerOnline = ownerPlayer ~= nil,
		},
		PersonalCash = player:GetAttribute("Cash") or 0,
		Economy = {
			BusinessCash = record.BusinessCash,
			Inventory = deepCopy(record.Inventory),
			Prices = deepCopy(record.Prices),
			ProductionReadyIn = math.max(0, record.ProductionReadyAt - os.time()),
			ServeReadyIn = math.max(0, record.ServeReadyAt - os.time()),
			Stats = deepCopy(record.Stats),
		},
		BuyerPizzerias = getOwnedPizzerias(player),
	}
end

local function depositCash(player, lotId, amount)
	if not playerOwnsBusiness(player, lotId) then
		return { Ok = false, Error = "Você não controla esta empresa" }
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount < EconomyConfig.MinimumCashTransfer or amount > EconomyConfig.MaximumCashTransfer then
		return { Ok = false, Error = "Valor de depósito inválido" }
	end

	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O caixa desta empresa está ocupado" }
	end

	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar a empresa" }
	end
	local before = deepCopy(record)

	local charged = playerDataService:AdjustCash(player, -amount)
	if not charged then
		releaseLots(locked)
		return { Ok = false, Error = "Seu saldo pessoal é insuficiente" }
	end
	if not playerDataService:Save(player) then
		playerDataService:AdjustCash(player, amount)
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível salvar o depósito" }
	end

	record.BusinessCash += amount
	if not saveRecord(lotId) then
		records[lotId] = before
		playerDataService:AdjustCash(player, amount)
		playerDataService:Save(player)
		releaseLots(locked)
		return { Ok = false, Error = "O depósito falhou; o dinheiro foi devolvido" }
	end

	releaseLots(locked)
	return { Ok = true, Message = string.format("$%d depositados no caixa da empresa", amount) }
end

local function withdrawCash(player, lotId, amount)
	if not playerOwnsBusiness(player, lotId) then
		return { Ok = false, Error = "Você não controla esta empresa" }
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount < EconomyConfig.MinimumCashTransfer or amount > EconomyConfig.MaximumCashTransfer then
		return { Ok = false, Error = "Valor de saque inválido" }
	end

	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O caixa desta empresa está ocupado" }
	end

	local record = loadRecord(lotId)
	if not record or record.BusinessCash < amount then
		releaseLots(locked)
		return { Ok = false, Error = "O caixa da empresa não possui esse valor" }
	end
	local before = deepCopy(record)

	record.BusinessCash -= amount
	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível salvar o saque" }
	end

	local credited = playerDataService:AdjustCash(player, amount)
	local profileSaved = credited and playerDataService:Save(player)
	if not profileSaved then
		if credited then
			playerDataService:AdjustCash(player, -amount)
		end
		records[lotId] = before
		saveRecord(lotId)
		releaseLots(locked)
		return { Ok = false, Error = "O saque falhou e foi revertido" }
	end

	releaseLots(locked)
	return { Ok = true, Message = string.format("$%d transferidos para seu saldo pessoal", amount) }
end

local function produceFarm(player, lotId)
	if not playerOwnsBusiness(player, lotId, "Farm") then
		return { Ok = false, Error = "Você precisa controlar esta Fazenda" }
	end

	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A produção já está sendo atualizada" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar a Fazenda" }
	end

	local now = os.time()
	if record.ProductionReadyAt > now then
		local remaining = record.ProductionReadyAt - now
		releaseLots(locked)
		return { Ok = false, Error = string.format("Novo lote disponível em %ds", remaining) }
	end

	local before = deepCopy(record)
	for itemId, quantity in pairs(EconomyConfig.FarmYield) do
		if record.Inventory[itemId] + quantity > EconomyConfig.MaxInventoryPerItem then
			releaseLots(locked)
			return { Ok = false, Error = "O estoque da Fazenda está cheio" }
		end
		record.Inventory[itemId] += quantity
		record.Stats.Produced += quantity
	end
	record.ProductionReadyAt = now + EconomyConfig.FarmProductionCooldown

	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "A produção não pôde ser salva" }
	end

	releaseLots(locked)
	return { Ok = true, Message = "Lote produzido: +5 farinha, +3 queijo, +4 tomate" }
end

local function setFarmPrice(player, lotId, itemId, delta)
	if not playerOwnsBusiness(player, lotId, "Farm") then
		return { Ok = false, Error = "Você precisa controlar esta Fazenda" }
	end
	if not table.find(EconomyConfig.FarmItemOrder, itemId) then
		return { Ok = false, Error = "Produto inválido" }
	end
	delta = math.clamp(math.floor(tonumber(delta) or 0), -25, 25)
	if delta == 0 then
		return { Ok = false, Error = "Alteração de preço inválida" }
	end

	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A tabela de preços está ocupada" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar a Fazenda" }
	end

	record.Prices[itemId] = math.clamp(
		record.Prices[itemId] + delta,
		EconomyConfig.MinSalePrice,
		EconomyConfig.MaxSalePrice
	)
	if not saveRecord(lotId) then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível salvar o novo preço" }
	end

	local price = record.Prices[itemId]
	releaseLots(locked)
	return { Ok = true, Message = string.format("Novo preço: $%d por unidade", price) }
end

local function buyFromFarm(player, sellerLotId, buyerLotId, itemId, quantity)
	if not playerOwnsBusiness(player, buyerLotId, "Pizzeria") then
		return { Ok = false, Error = "A compra precisa ser feita por uma Pizzaria sua" }
	end
	local seller = getActiveBusiness(sellerLotId)
	if not seller or seller.BusinessType ~= "Farm" then
		return { Ok = false, Error = "O fornecedor não é uma Fazenda ativa" }
	end
	if not Players:GetPlayerByUserId(seller.OwnerUserId) then
		return { Ok = false, Error = "O dono desta Fazenda precisa estar neste servidor para negociar" }
	end
	if not table.find(EconomyConfig.FarmItemOrder, itemId) then
		return { Ok = false, Error = "Ingrediente inválido" }
	end
	quantity = math.floor(tonumber(quantity) or 0)
	if quantity ~= 1 and quantity ~= 5 then
		return { Ok = false, Error = "Quantidade inválida" }
	end

	local locked = acquireLots({ sellerLotId, buyerLotId })
	if not locked then
		return { Ok = false, Error = "Uma das empresas está concluindo outra operação" }
	end

	local sellerRecord = loadRecord(sellerLotId)
	local buyerRecord = loadRecord(buyerLotId)
	if not sellerRecord or not buyerRecord then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar as empresas" }
	end

	local unitPrice = sellerRecord.Prices[itemId]
	local total = unitPrice * quantity
	if sellerRecord.Inventory[itemId] < quantity then
		releaseLots(locked)
		return { Ok = false, Error = "O fornecedor não possui essa quantidade em estoque" }
	end
	if buyerRecord.BusinessCash < total then
		releaseLots(locked)
		return { Ok = false, Error = string.format("A Pizzaria precisa de $%d no caixa", total) }
	end
	if buyerRecord.Inventory[itemId] + quantity > EconomyConfig.MaxInventoryPerItem then
		releaseLots(locked)
		return { Ok = false, Error = "O estoque da Pizzaria está cheio" }
	end

	local sellerBefore = deepCopy(sellerRecord)
	local buyerBefore = deepCopy(buyerRecord)

	sellerRecord.Inventory[itemId] -= quantity
	sellerRecord.BusinessCash += total
	sellerRecord.Stats.SoldToPlayers += quantity
	buyerRecord.Inventory[itemId] += quantity
	buyerRecord.BusinessCash -= total
	buyerRecord.Stats.PurchasedFromPlayers += quantity

	local sellerSaved = saveRecord(sellerLotId)
	local buyerSaved = sellerSaved and saveRecord(buyerLotId)
	if not buyerSaved then
		records[sellerLotId] = sellerBefore
		records[buyerLotId] = buyerBefore
		saveRecord(sellerLotId)
		saveRecord(buyerLotId)
		releaseLots(locked)
		return { Ok = false, Error = "A compra não pôde ser concluída e foi revertida" }
	end

	local itemName = EconomyConfig.Items[itemId].DisplayName
	releaseLots(locked)
	return {
		Ok = true,
		Message = string.format("Comprou %dx %s por $%d de %s", quantity, itemName, total, sellerLotId),
	}
end

local function bakePizza(player, lotId, quantity)
	if not playerOwnsBusiness(player, lotId, "Pizzeria") then
		return { Ok = false, Error = "Você precisa controlar esta Pizzaria" }
	end
	quantity = math.floor(tonumber(quantity) or 0)
	if quantity ~= 1 and quantity ~= 5 then
		return { Ok = false, Error = "Quantidade inválida" }
	end

	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A cozinha está ocupada" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar a Pizzaria" }
	end

	for itemId, amountPerPizza in pairs(EconomyConfig.PizzeriaRecipe.Inputs) do
		local required = amountPerPizza * quantity
		if record.Inventory[itemId] < required then
			local itemName = EconomyConfig.Items[itemId].DisplayName
			releaseLots(locked)
			return { Ok = false, Error = string.format("Faltam ingredientes: precisa de %d %s", required, itemName) }
		end
	end

	local pizzasToCreate = EconomyConfig.PizzeriaRecipe.OutputQuantity * quantity
	if record.Inventory.Pizza + pizzasToCreate > EconomyConfig.MaxInventoryPerItem then
		releaseLots(locked)
		return { Ok = false, Error = "O estoque de pizzas está cheio" }
	end

	local before = deepCopy(record)
	for itemId, amountPerPizza in pairs(EconomyConfig.PizzeriaRecipe.Inputs) do
		record.Inventory[itemId] -= amountPerPizza * quantity
	end
	record.Inventory.Pizza += pizzasToCreate
	record.Stats.Produced += pizzasToCreate

	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "A produção das pizzas não pôde ser salva" }
	end

	releaseLots(locked)
	return { Ok = true, Message = string.format("%d pizza(s) preparada(s)", pizzasToCreate) }
end

local function serveCity(player, lotId)
	if not playerOwnsBusiness(player, lotId, "Pizzeria") then
		return { Ok = false, Error = "Você precisa controlar esta Pizzaria" }
	end

	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O atendimento já está em andamento" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar a Pizzaria" }
	end

	local now = os.time()
	if record.ServeReadyAt > now then
		local remaining = record.ServeReadyAt - now
		releaseLots(locked)
		return { Ok = false, Error = string.format("Novos clientes chegam em %ds", remaining) }
	end

	local sold = math.min(record.Inventory.Pizza, EconomyConfig.MaxCitySalePerAction)
	if sold <= 0 then
		releaseLots(locked)
		return { Ok = false, Error = "Prepare pizzas antes de atender clientes" }
	end

	local before = deepCopy(record)
	local revenue = sold * EconomyConfig.CityPizzaPrice
	record.Inventory.Pizza -= sold
	record.BusinessCash += revenue
	record.ServeReadyAt = now + EconomyConfig.PizzeriaServeCooldown
	record.Stats.CitySales += sold

	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "A venda não pôde ser salva" }
	end

	releaseLots(locked)
	return { Ok = true, Message = string.format("Vendeu %d pizza(s) à cidade e recebeu $%d", sold, revenue) }
end

local function economyAction(player, payload)
	if type(payload) ~= "table" then
		return { Ok = false, Error = "Operação inválida" }
	end

	local nowClock = os.clock()
	if lastActionAt[player] and nowClock - lastActionAt[player] < 0.12 then
		return { Ok = false, Error = "Aguarde um instante" }
	end
	lastActionAt[player] = nowClock

	local action = payload.Action
	if action == "Deposit" then
		return depositCash(player, payload.LotId, payload.Amount)
	elseif action == "Withdraw" then
		return withdrawCash(player, payload.LotId, payload.Amount)
	elseif action == "FarmProduce" then
		return produceFarm(player, payload.LotId)
	elseif action == "SetFarmPrice" then
		return setFarmPrice(player, payload.LotId, payload.ItemId, payload.Delta)
	elseif action == "BuyFromFarm" then
		return buyFromFarm(player, payload.SellerLotId, payload.BuyerLotId, payload.ItemId, payload.Quantity)
	elseif action == "BakePizza" then
		return bakePizza(player, payload.LotId, payload.Quantity)
	elseif action == "ServeCity" then
		return serveCity(player, payload.LotId)
	end

	return { Ok = false, Error = "Ação empresarial desconhecida" }
end

local function createRemote(parent, className, name)
	local remote = parent:FindFirstChild(name)
	if remote then
		return remote
	end
	remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function setupRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	openRemote = createRemote(remotes, "RemoteEvent", "OpenBusinessEconomy")
	local getStateRemote = createRemote(remotes, "RemoteFunction", "GetBusinessEconomyState")
	local actionRemote = createRemote(remotes, "RemoteFunction", "BusinessEconomyAction")

	getStateRemote.OnServerInvoke = getState
	actionRemote.OnServerInvoke = economyAction
end

local function attachPromptToSign(sign)
	if not sign:IsA("BasePart") then
		return
	end

	task.defer(function()
		local lotId = sign.Name
		local active = getActiveBusiness(lotId)
		if not active or not openRemote or sign:FindFirstChild("EconomyPromptAttachment") then
			return
		end

		loadRecord(lotId)

		local attachment = Instance.new("Attachment")
		attachment.Name = "EconomyPromptAttachment"
		attachment.Position = Vector3.new(0, 0, 0)
		attachment.Parent = sign

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EconomyPrompt"
		prompt.ActionText = "Abrir empresa"
		prompt.ObjectText = BusinessConfig.Types[active.BusinessType].DisplayName
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = attachment
		prompt.Triggered:Connect(function(player)
			openRemote:FireClient(player, lotId)
		end)
	end)
end

local function setupBusinessSigns()
	local world = getWorld()
	local signs = world and world:FindFirstChild("BusinessSigns")
	if not signs then
		warn("[BusinessEconomyService] BusinessSigns folder is missing")
		return
	end

	for _, sign in ipairs(signs:GetChildren()) do
		attachPromptToSign(sign)
	end
	signs.ChildAdded:Connect(attachPromptToSign)
end

function BusinessEconomyService:Start(dataService)
	if started then
		return
	end
	started = true
	playerDataService = dataService

	setupRemotes()
	setupBusinessSigns()

	Players.PlayerRemoving:Connect(function(player)
		lastActionAt[player] = nil
	end)

	game:BindToClose(function()
		for lotId in pairs(records) do
			saveRecord(lotId)
		end
	end)

	print("[Property Empire v2] BusinessEconomyService started: Farm -> Pizzeria")
end

return BusinessEconomyService
