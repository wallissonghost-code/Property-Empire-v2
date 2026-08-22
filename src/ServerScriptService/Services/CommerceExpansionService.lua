local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessConfig = require(Shared.BusinessConfig)
local Config = require(Shared.CommerceExpansionConfig)

local CommerceExpansionService = {}
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local marketingStore = DataStoreService:GetDataStore(Config.MarketingDataStoreName)

local playerDataService = nil
local started = false
local records = {}
local marketingRecords = {}
local lotLocks = {}
local marketingLocks = {}
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

local function isSupportedType(businessType)
	return businessType == "LumberCompany"
		or businessType == "FurnitureFactory"
		or businessType == "MarketingAgency"
end

local function recordKey(lotId)
	return "commerce_" .. lotId
end

local function marketingKey(lotId)
	return "marketing_" .. lotId
end

local function makeDefaultRecord(active)
	return {
		Version = Config.DataVersion,
		LotId = active.LotId,
		OwnerUserId = active.OwnerUserId,
		BusinessType = active.BusinessType,
		BusinessCash = 0,
		Inventory = {
			Wood = 0,
			Chair = 0,
			Table = 0,
			Sofa = 0,
		},
		WoodPrice = Config.DefaultWoodPrice,
		CampaignPrice = Config.DefaultCampaignPrice,
		ProductionReadyAt = 0,
		ServeReadyAt = 0,
		Stats = {
			Produced = 0,
			SoldToPlayers = 0,
			PurchasedFromPlayers = 0,
			CitySales = 0,
			CityRevenue = 0,
			CampaignsSold = 0,
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

	record.Version = Config.DataVersion
	record.LotId = active.LotId
	record.OwnerUserId = active.OwnerUserId
	record.BusinessType = active.BusinessType
	record.BusinessCash = math.max(0, math.floor(tonumber(record.BusinessCash) or 0))
	record.WoodPrice = math.clamp(
		math.floor(tonumber(record.WoodPrice) or Config.DefaultWoodPrice),
		Config.MinWoodPrice,
		Config.MaxWoodPrice
	)
	record.CampaignPrice = math.clamp(
		math.floor(tonumber(record.CampaignPrice) or Config.DefaultCampaignPrice),
		Config.MinCampaignPrice,
		Config.MaxCampaignPrice
	)
	record.ProductionReadyAt = math.max(0, math.floor(tonumber(record.ProductionReadyAt) or 0))
	record.ServeReadyAt = math.max(0, math.floor(tonumber(record.ServeReadyAt) or 0))

	if type(record.Inventory) ~= "table" then
		record.Inventory = {}
	end
	for itemId in pairs(Config.Items) do
		record.Inventory[itemId] = math.clamp(
			math.floor(tonumber(record.Inventory[itemId]) or 0),
			0,
			Config.MaxInventoryPerItem
		)
	end

	if type(record.Stats) ~= "table" then
		record.Stats = {}
	end
	for _, key in ipairs({ "Produced", "SoldToPlayers", "PurchasedFromPlayers", "CitySales", "CityRevenue", "CampaignsSold" }) do
		record.Stats[key] = math.max(0, math.floor(tonumber(record.Stats[key]) or 0))
	end
	return record
end

local function loadRecord(lotId)
	local active = getActiveBusiness(lotId)
	if not active or not isSupportedType(active.BusinessType) then
		records[lotId] = nil
		return nil
	end
	local cached = records[lotId]
	if cached and cached.OwnerUserId == active.OwnerUserId and cached.BusinessType == active.BusinessType then
		return cached
	end
	local success, stored = pcall(function()
		return store:GetAsync(recordKey(lotId))
	end)
	if not success then
		warn(string.format("[CommerceExpansionService] Failed to load %s", lotId))
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
		store:SetAsync(recordKey(lotId), snapshot)
	end)
	if not success then
		warn(string.format("[CommerceExpansionService] Failed to save %s: %s", lotId, tostring(errorMessage)))
	end
	return success
end

local function normalizeMarketing(lotId, raw)
	if type(raw) ~= "table" then
		raw = {}
	end
	return {
		Version = Config.DataVersion,
		LotId = lotId,
		Reputation = math.clamp(
			math.floor(tonumber(raw.Reputation) or 0),
			0,
			Config.MaxMarketingReputation
		),
		BoostUntil = math.max(0, math.floor(tonumber(raw.BoostUntil) or 0)),
		Campaigns = math.max(0, math.floor(tonumber(raw.Campaigns) or 0)),
	}
end

local function syncMarketingAttributes(lotId, state)
	local lot = getLot(lotId)
	if not lot or not state then
		return
	end
	local activeBoost = state.BoostUntil > os.time() and Config.CampaignDemandBoost or 0
	lot:SetAttribute("MarketingDemandBoost", activeBoost)
	lot:SetAttribute("MarketingBoostUntil", state.BoostUntil)
	lot:SetAttribute("MarketingReputation", state.Reputation)
end

local function loadMarketing(lotId)
	if type(lotId) ~= "string" then
		return nil
	end
	local cached = marketingRecords[lotId]
	if cached then
		syncMarketingAttributes(lotId, cached)
		return cached
	end
	local success, stored = pcall(function()
		return marketingStore:GetAsync(marketingKey(lotId))
	end)
	if not success then
		warn(string.format("[CommerceExpansionService] Failed to load marketing for %s", lotId))
		return nil
	end
	local state = normalizeMarketing(lotId, stored)
	marketingRecords[lotId] = state
	syncMarketingAttributes(lotId, state)
	return state
end

local function saveMarketing(lotId)
	local state = marketingRecords[lotId]
	if not state then
		return false
	end
	local snapshot = deepCopy(state)
	local success, errorMessage = pcall(function()
		marketingStore:SetAsync(marketingKey(lotId), snapshot)
	end)
	if not success then
		warn(string.format("[CommerceExpansionService] Failed to save marketing %s: %s", lotId, tostring(errorMessage)))
	end
	if success then
		syncMarketingAttributes(lotId, state)
	end
	return success
end

local function acquireLots(lotIds)
	local unique = {}
	for _, lotId in ipairs(lotIds) do
		if type(lotId) == "string" then
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
	return active ~= nil
		and active.OwnerUserId == player.UserId
		and (requiredType == nil or active.BusinessType == requiredType)
end

local function getOwnedFactories(player)
	local data = playerDataService and playerDataService:Get(player)
	local result = {}
	if not data or type(data.OwnedLots) ~= "table" then
		return result
	end
	for _, lotId in ipairs(data.OwnedLots) do
		local active = getActiveBusiness(lotId)
		if active and active.OwnerUserId == player.UserId and active.BusinessType == "FurnitureFactory" then
			local record = loadRecord(lotId)
			if record then
				table.insert(result, { LotId = lotId, BusinessCash = record.BusinessCash })
			end
		end
	end
	table.sort(result, function(a, b) return a.LotId < b.LotId end)
	return result
end

local function getOwnedMarketingTargets(player, agencyLotId)
	local data = playerDataService and playerDataService:Get(player)
	local result = {}
	if not data or type(data.OwnedLots) ~= "table" then
		return result
	end
	for _, lotId in ipairs(data.OwnedLots) do
		if lotId ~= agencyLotId then
			local active = getActiveBusiness(lotId)
			if active and active.OwnerUserId == player.UserId then
				local marketing = loadMarketing(lotId)
				if marketing then
					table.insert(result, {
						LotId = lotId,
						BusinessType = active.BusinessType,
						DisplayName = BusinessConfig.Types[active.BusinessType].DisplayName,
						Reputation = marketing.Reputation,
						BoostReadyIn = math.max(0, marketing.BoostUntil - os.time()),
					})
				end
			end
		end
	end
	table.sort(result, function(a, b) return a.LotId < b.LotId end)
	return result
end

local function getState(player, lotId)
	if type(lotId) ~= "string" or #lotId > 32 then
		return { Ok = false, Error = "Empresa inválida" }
	end
	local active = getActiveBusiness(lotId)
	if not active or not isSupportedType(active.BusinessType) then
		return { Ok = false, Error = "Esta empresa não participa desta cadeia comercial" }
	end
	local record = loadRecord(lotId)
	if not record then
		return { Ok = false, Error = "Não foi possível carregar a empresa" }
	end
	local marketing = loadMarketing(lotId) or normalizeMarketing(lotId, nil)
	return {
		Ok = true,
		ServerTime = os.time(),
		Target = {
			LotId = lotId,
			OwnerUserId = active.OwnerUserId,
			BusinessType = active.BusinessType,
			DisplayName = BusinessConfig.Types[active.BusinessType].DisplayName,
			IsOwner = active.OwnerUserId == player.UserId,
			OwnerOnline = Players:GetPlayerByUserId(active.OwnerUserId) ~= nil,
		},
		PersonalCash = player:GetAttribute("Cash") or 0,
		Economy = {
			BusinessCash = record.BusinessCash,
			Inventory = deepCopy(record.Inventory),
			WoodPrice = record.WoodPrice,
			CampaignPrice = record.CampaignPrice,
			ProductionReadyIn = math.max(0, record.ProductionReadyAt - os.time()),
			ServeReadyIn = math.max(0, record.ServeReadyAt - os.time()),
			Stats = deepCopy(record.Stats),
			MarketingReputation = marketing.Reputation,
			MarketingBoostReadyIn = math.max(0, marketing.BoostUntil - os.time()),
		},
		BuyerFactories = getOwnedFactories(player),
		MarketingTargets = getOwnedMarketingTargets(player, lotId),
	}
end

local function depositCash(player, lotId, amount)
	if not playerOwnsBusiness(player, lotId) then
		return { Ok = false, Error = "Você não controla esta empresa" }
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount < Config.MinimumCashTransfer or amount > Config.MaximumCashTransfer then
		return { Ok = false, Error = "Valor de depósito inválido" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O caixa está ocupado" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Empresa indisponível" }
	end
	local before = deepCopy(record)
	local charged = playerDataService:AdjustCash(player, -amount)
	if not charged then
		releaseLots(locked)
		return { Ok = false, Error = "Saldo pessoal insuficiente" }
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
		return { Ok = false, Error = "Depósito revertido" }
	end
	releaseLots(locked)
	return { Ok = true, Message = string.format("$%d depositados na empresa", amount) }
end

local function withdrawCash(player, lotId, amount)
	if not playerOwnsBusiness(player, lotId) then
		return { Ok = false, Error = "Você não controla esta empresa" }
	end
	amount = math.floor(tonumber(amount) or 0)
	if amount < Config.MinimumCashTransfer or amount > Config.MaximumCashTransfer then
		return { Ok = false, Error = "Valor de saque inválido" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O caixa está ocupado" }
	end
	local record = loadRecord(lotId)
	if not record or record.BusinessCash < amount then
		releaseLots(locked)
		return { Ok = false, Error = "Caixa empresarial insuficiente" }
	end
	local before = deepCopy(record)
	record.BusinessCash -= amount
	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível salvar o saque" }
	end
	local credited = playerDataService:AdjustCash(player, amount)
	if not credited or not playerDataService:Save(player) then
		if credited then playerDataService:AdjustCash(player, -amount) end
		records[lotId] = before
		saveRecord(lotId)
		releaseLots(locked)
		return { Ok = false, Error = "Saque revertido" }
	end
	releaseLots(locked)
	return { Ok = true, Message = string.format("$%d transferidos para seu saldo pessoal", amount) }
end

local function produceLumber(player, lotId)
	if not playerOwnsBusiness(player, lotId, "LumberCompany") then
		return { Ok = false, Error = "Você precisa controlar esta Madeireira" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "Produção ocupada" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Madeireira indisponível" }
	end
	local now = os.time()
	if record.ProductionReadyAt > now then
		local remaining = record.ProductionReadyAt - now
		releaseLots(locked)
		return { Ok = false, Error = string.format("Novo lote em %ds", remaining) }
	end
	if record.Inventory.Wood + Config.LumberYield > Config.MaxInventoryPerItem then
		releaseLots(locked)
		return { Ok = false, Error = "Estoque de madeira cheio" }
	end
	local before = deepCopy(record)
	record.Inventory.Wood += Config.LumberYield
	record.ProductionReadyAt = now + Config.LumberProductionCooldown
	record.Stats.Produced += Config.LumberYield
	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "Produção não pôde ser salva" }
	end
	releaseLots(locked)
	return { Ok = true, Message = string.format("Lote serrado: +%d madeira", Config.LumberYield) }
end

local function setWoodPrice(player, lotId, delta)
	if not playerOwnsBusiness(player, lotId, "LumberCompany") then
		return { Ok = false, Error = "Você precisa controlar esta Madeireira" }
	end
	delta = math.floor(tonumber(delta) or 0)
	if delta ~= Config.WoodPriceStep and delta ~= -Config.WoodPriceStep then
		return { Ok = false, Error = "Alteração de preço inválida" }
	end
	local locked = acquireLots({ lotId })
	if not locked then return { Ok = false, Error = "Preço ocupado" } end
	local record = loadRecord(lotId)
	if not record then releaseLots(locked) return { Ok = false, Error = "Madeireira indisponível" } end
	record.WoodPrice = math.clamp(record.WoodPrice + delta, Config.MinWoodPrice, Config.MaxWoodPrice)
	if not saveRecord(lotId) then releaseLots(locked) return { Ok = false, Error = "Preço não pôde ser salvo" } end
	local price = record.WoodPrice
	releaseLots(locked)
	return { Ok = true, Message = string.format("Madeira agora custa $%d/unidade", price) }
end

local function buyWood(player, sellerLotId, buyerLotId, quantity)
	if not playerOwnsBusiness(player, buyerLotId, "FurnitureFactory") then
		return { Ok = false, Error = "A compra precisa ser feita por uma Fábrica de Móveis sua" }
	end
	local seller = getActiveBusiness(sellerLotId)
	if not seller or seller.BusinessType ~= "LumberCompany" then
		return { Ok = false, Error = "Fornecedor não é uma Madeireira ativa" }
	end
	if not Players:GetPlayerByUserId(seller.OwnerUserId) then
		return { Ok = false, Error = "O dono da Madeireira precisa estar neste servidor" }
	end
	quantity = math.floor(tonumber(quantity) or 0)
	if quantity ~= 1 and quantity ~= 5 and quantity ~= 10 then
		return { Ok = false, Error = "Quantidade inválida" }
	end
	local locked = acquireLots({ sellerLotId, buyerLotId })
	if not locked then return { Ok = false, Error = "Uma das empresas está ocupada" } end
	local sellerRecord = loadRecord(sellerLotId)
	local buyerRecord = loadRecord(buyerLotId)
	if not sellerRecord or not buyerRecord then releaseLots(locked) return { Ok = false, Error = "Empresas indisponíveis" } end
	local total = sellerRecord.WoodPrice * quantity
	if sellerRecord.Inventory.Wood < quantity then releaseLots(locked) return { Ok = false, Error = "Fornecedor sem madeira suficiente" } end
	if buyerRecord.BusinessCash < total then releaseLots(locked) return { Ok = false, Error = string.format("A fábrica precisa de $%d no caixa", total) } end
	if buyerRecord.Inventory.Wood + quantity > Config.MaxInventoryPerItem then releaseLots(locked) return { Ok = false, Error = "Estoque da fábrica cheio" } end
	local sellerBefore = deepCopy(sellerRecord)
	local buyerBefore = deepCopy(buyerRecord)
	sellerRecord.Inventory.Wood -= quantity
	sellerRecord.BusinessCash += total
	sellerRecord.Stats.SoldToPlayers += quantity
	buyerRecord.Inventory.Wood += quantity
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
		return { Ok = false, Error = "Compra revertida" }
	end
	releaseLots(locked)
	return { Ok = true, Message = string.format("Comprou %d madeira por $%d", quantity, total) }
end

local function craftFurniture(player, lotId, itemId, quantity)
	if not playerOwnsBusiness(player, lotId, "FurnitureFactory") then
		return { Ok = false, Error = "Você precisa controlar esta Fábrica de Móveis" }
	end
	local recipe = Config.FurnitureRecipes[itemId]
	if not recipe then return { Ok = false, Error = "Móvel inválido" } end
	quantity = math.floor(tonumber(quantity) or 0)
	if quantity ~= 1 and quantity ~= 5 then return { Ok = false, Error = "Quantidade inválida" } end
	local locked = acquireLots({ lotId })
	if not locked then return { Ok = false, Error = "Linha de produção ocupada" } end
	local record = loadRecord(lotId)
	if not record then releaseLots(locked) return { Ok = false, Error = "Fábrica indisponível" } end
	local requiredWood = recipe.Wood * quantity
	local output = recipe.Output * quantity
	if record.Inventory.Wood < requiredWood then releaseLots(locked) return { Ok = false, Error = string.format("Precisa de %d madeira", requiredWood) } end
	if record.Inventory[itemId] + output > Config.MaxInventoryPerItem then releaseLots(locked) return { Ok = false, Error = "Estoque de móveis cheio" } end
	local before = deepCopy(record)
	record.Inventory.Wood -= requiredWood
	record.Inventory[itemId] += output
	record.Stats.Produced += output
	if not saveRecord(lotId) then records[lotId] = before releaseLots(locked) return { Ok = false, Error = "Produção não pôde ser salva" } end
	releaseLots(locked)
	return { Ok = true, Message = string.format("Produziu %d %s", output, Config.Items[itemId].DisplayName) }
end

local function sellFurnitureCity(player, lotId, itemId)
	if not playerOwnsBusiness(player, lotId, "FurnitureFactory") then
		return { Ok = false, Error = "Você precisa controlar esta Fábrica de Móveis" }
	end
	if not Config.FurnitureCityPrices[itemId] then return { Ok = false, Error = "Móvel inválido" } end
	local locked = acquireLots({ lotId })
	if not locked then return { Ok = false, Error = "Atendimento ocupado" } end
	local record = loadRecord(lotId)
	if not record then releaseLots(locked) return { Ok = false, Error = "Fábrica indisponível" } end
	local now = os.time()
	if record.ServeReadyAt > now then
		local remaining = record.ServeReadyAt - now
		releaseLots(locked)
		return { Ok = false, Error = string.format("Novos pedidos em %ds", remaining) }
	end
	local lot = getLot(lotId)
	local boost = lot and math.max(0, tonumber(lot:GetAttribute("MarketingDemandBoost")) or 0) or 0
	local maxSale = math.max(1, math.floor(Config.MaxFurnitureCitySalePerAction * (1 + boost) + 0.5))
	local sold = math.min(record.Inventory[itemId], maxSale)
	if sold <= 0 then releaseLots(locked) return { Ok = false, Error = "Produza este móvel antes de vender" } end
	local before = deepCopy(record)
	local revenue = sold * Config.FurnitureCityPrices[itemId]
	record.Inventory[itemId] -= sold
	record.BusinessCash += revenue
	record.ServeReadyAt = now + Config.FurnitureServeCooldown
	record.Stats.CitySales += sold
	record.Stats.CityRevenue += revenue
	if not saveRecord(lotId) then records[lotId] = before releaseLots(locked) return { Ok = false, Error = "Venda não pôde ser salva" } end
	releaseLots(locked)
	local marketingText = boost > 0 and " · campanha ativa" or ""
	return { Ok = true, Message = string.format("Vendeu %d %s por $%d%s", sold, Config.Items[itemId].DisplayName, revenue, marketingText) }
end

local function setCampaignPrice(player, lotId, delta)
	if not playerOwnsBusiness(player, lotId, "MarketingAgency") then
		return { Ok = false, Error = "Você precisa controlar esta Agência de Marketing" }
	end
	delta = math.floor(tonumber(delta) or 0)
	if delta ~= Config.CampaignPriceStep and delta ~= -Config.CampaignPriceStep then return { Ok = false, Error = "Alteração de preço inválida" } end
	local locked = acquireLots({ lotId })
	if not locked then return { Ok = false, Error = "Tabela de preços ocupada" } end
	local record = loadRecord(lotId)
	if not record then releaseLots(locked) return { Ok = false, Error = "Agência indisponível" } end
	record.CampaignPrice = math.clamp(record.CampaignPrice + delta, Config.MinCampaignPrice, Config.MaxCampaignPrice)
	if not saveRecord(lotId) then releaseLots(locked) return { Ok = false, Error = "Preço não pôde ser salvo" } end
	local price = record.CampaignPrice
	releaseLots(locked)
	return { Ok = true, Message = string.format("Campanha agora custa $%d", price) }
end

local function buyCampaign(player, agencyLotId, targetLotId)
	local agency = getActiveBusiness(agencyLotId)
	if not agency or agency.BusinessType ~= "MarketingAgency" then return { Ok = false, Error = "Agência inválida" } end
	if not Players:GetPlayerByUserId(agency.OwnerUserId) then return { Ok = false, Error = "O dono da Agência precisa estar neste servidor" } end
	if not playerOwnsBusiness(player, targetLotId) then return { Ok = false, Error = "Você só pode anunciar uma empresa sua" } end
	if targetLotId == agencyLotId then return { Ok = false, Error = "Escolha outra empresa para a campanha" } end
	if marketingLocks[targetLotId] then return { Ok = false, Error = "Esta empresa já está recebendo outra campanha" } end
	marketingLocks[targetLotId] = true
	local locked = acquireLots({ agencyLotId })
	if not locked then marketingLocks[targetLotId] = nil return { Ok = false, Error = "Agência ocupada" } end
	local agencyRecord = loadRecord(agencyLotId)
	local marketing = loadMarketing(targetLotId)
	if not agencyRecord or not marketing then releaseLots(locked) marketingLocks[targetLotId] = nil return { Ok = false, Error = "Não foi possível carregar a campanha" } end
	local price = agencyRecord.CampaignPrice
	local agencyBefore = deepCopy(agencyRecord)
	local marketingBefore = deepCopy(marketing)
	local charged = playerDataService:AdjustCash(player, -price)
	if not charged then releaseLots(locked) marketingLocks[targetLotId] = nil return { Ok = false, Error = "Saldo pessoal insuficiente para a campanha" } end
	if not playerDataService:Save(player) then
		playerDataService:AdjustCash(player, price)
		releaseLots(locked)
		marketingLocks[targetLotId] = nil
		return { Ok = false, Error = "Pagamento não pôde ser salvo" }
	end
	agencyRecord.BusinessCash += price
	agencyRecord.Stats.CampaignsSold += 1
	marketing.BoostUntil = math.max(os.time(), marketing.BoostUntil) + Config.CampaignDurationSeconds
	marketing.Reputation = math.min(Config.MaxMarketingReputation, marketing.Reputation + Config.CampaignReputationGain)
	marketing.Campaigns += 1
	local agencySaved = saveRecord(agencyLotId)
	local marketingSaved = agencySaved and saveMarketing(targetLotId)
	if not marketingSaved then
		records[agencyLotId] = agencyBefore
		marketingRecords[targetLotId] = marketingBefore
		saveRecord(agencyLotId)
		saveMarketing(targetLotId)
		playerDataService:AdjustCash(player, price)
		playerDataService:Save(player)
		releaseLots(locked)
		marketingLocks[targetLotId] = nil
		return { Ok = false, Error = "Campanha falhou e o pagamento foi devolvido" }
	end
	releaseLots(locked)
	marketingLocks[targetLotId] = nil
	return { Ok = true, Message = string.format("Campanha ativada por %ds · demanda +%d%% · reputação +%d", Config.CampaignDurationSeconds, math.floor(Config.CampaignDemandBoost * 100), Config.CampaignReputationGain) }
end

local function economyAction(player, payload)
	if type(payload) ~= "table" then return { Ok = false, Error = "Operação inválida" } end
	local nowClock = os.clock()
	if lastActionAt[player] and nowClock - lastActionAt[player] < 0.12 then return { Ok = false, Error = "Aguarde um instante" } end
	lastActionAt[player] = nowClock
	local action = payload.Action
	if action == "Deposit" then return depositCash(player, payload.LotId, payload.Amount)
	elseif action == "Withdraw" then return withdrawCash(player, payload.LotId, payload.Amount)
	elseif action == "ProduceLumber" then return produceLumber(player, payload.LotId)
	elseif action == "SetWoodPrice" then return setWoodPrice(player, payload.LotId, payload.Delta)
	elseif action == "BuyWood" then return buyWood(player, payload.SellerLotId, payload.BuyerLotId, payload.Quantity)
	elseif action == "CraftFurniture" then return craftFurniture(player, payload.LotId, payload.ItemId, payload.Quantity)
	elseif action == "SellFurnitureCity" then return sellFurnitureCity(player, payload.LotId, payload.ItemId)
	elseif action == "SetCampaignPrice" then return setCampaignPrice(player, payload.LotId, payload.Delta)
	elseif action == "BuyCampaign" then return buyCampaign(player, payload.AgencyLotId, payload.TargetLotId)
	end
	return { Ok = false, Error = "Ação comercial desconhecida" }
end

local function createRemote(parent, className, name)
	local remote = parent:FindFirstChild(name)
	if remote then return remote end
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
	openRemote = createRemote(remotes, "RemoteEvent", "OpenCommerceExpansion")
	local getStateRemote = createRemote(remotes, "RemoteFunction", "GetCommerceExpansionState")
	local actionRemote = createRemote(remotes, "RemoteFunction", "CommerceExpansionAction")
	getStateRemote.OnServerInvoke = getState
	actionRemote.OnServerInvoke = economyAction
end

local function removeGenericPrompt(sign)
	local generic = sign:FindFirstChild("EconomyPromptAttachment")
	if generic then generic:Destroy() end
end

local function attachPromptToSign(sign)
	if not sign:IsA("BasePart") then return end
	local initialActive = getActiveBusiness(sign.Name)
	if not initialActive or not isSupportedType(initialActive.BusinessType) then return end
	if not sign:GetAttribute("CommerceExpansionPromptBound") then
		sign:SetAttribute("CommerceExpansionPromptBound", true)
		sign.ChildAdded:Connect(function(child)
			if child.Name == "EconomyPromptAttachment" then
				task.defer(function()
					if child.Parent == sign then child:Destroy() end
				end)
			end
		end)
	end
	task.defer(function()
		local active = getActiveBusiness(sign.Name)
		if not active or not isSupportedType(active.BusinessType) or not openRemote then return end
		removeGenericPrompt(sign)
		if sign:FindFirstChild("CommerceExpansionPromptAttachment") then return end
		loadRecord(sign.Name)
		loadMarketing(sign.Name)
		local attachment = Instance.new("Attachment")
		attachment.Name = "CommerceExpansionPromptAttachment"
		attachment.Parent = sign
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CommerceExpansionPrompt"
		if active.BusinessType == "LumberCompany" then
			prompt.ActionText = "Abrir madeireira"
		elseif active.BusinessType == "FurnitureFactory" then
			prompt.ActionText = "Abrir fábrica"
		else
			prompt.ActionText = "Ver campanhas"
		end
		prompt.ObjectText = BusinessConfig.Types[active.BusinessType].DisplayName
		prompt.HoldDuration = 0.20
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = attachment
		prompt.Triggered:Connect(function(player)
			openRemote:FireClient(player, sign.Name)
		end)
	end)
end

local function setupBusinessSigns()
	local world = getWorld()
	local signs = world and world:FindFirstChild("BusinessSigns")
	if not signs then warn("[CommerceExpansionService] BusinessSigns folder is missing") return end
	for _, sign in ipairs(signs:GetChildren()) do attachPromptToSign(sign) end
	signs.ChildAdded:Connect(attachPromptToSign)
	task.delay(1, function()
		for _, sign in ipairs(signs:GetChildren()) do
			local active = getActiveBusiness(sign.Name)
			if active and isSupportedType(active.BusinessType) then
				removeGenericPrompt(sign)
				attachPromptToSign(sign)
			end
		end
	end)
end

local function hydrateMarketingAttributes()
	local world = getWorld()
	local lots = world and world:FindFirstChild("Lots")
	if not lots then return end
	for _, lot in ipairs(lots:GetChildren()) do
		if lot:IsA("BasePart") and tonumber(lot:GetAttribute("BusinessOwnerUserId")) and (tonumber(lot:GetAttribute("BusinessOwnerUserId")) or 0) > 0 then
			loadMarketing(lot.Name)
		end
	end
end

function CommerceExpansionService:Start(dataService)
	if started then return end
	started = true
	playerDataService = dataService
	setupRemotes()
	setupBusinessSigns()
	task.spawn(hydrateMarketingAttributes)
	task.spawn(function()
		while started do
			task.wait(10)
			for lotId, state in pairs(marketingRecords) do
				syncMarketingAttributes(lotId, state)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) lastActionAt[player] = nil end)
	game:BindToClose(function()
		for lotId in pairs(records) do saveRecord(lotId) end
		for lotId in pairs(marketingRecords) do saveMarketing(lotId) end
	end)
	print("[Property Empire v2] CommerceExpansionService started: Lumber -> Furniture + Marketing")
end

return CommerceExpansionService
