local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessConfig = require(Shared.BusinessConfig)
local Config = require(Shared.MiningMuseumConfig)

local MiningMuseumService = {}
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local rng = Random.new()

local playerDataService = nil
local records = {}
local lotLocks = {}
local lastActionAt = {}
local started = false
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

local function isSupportedBusinessType(businessType)
	return businessType == "MiningCompany" or businessType == "Museum"
end

local function findSpec(kind)
	for _, spec in ipairs(Config.Finds) do
		if spec.Id == kind then
			return spec
		end
	end
	return nil
end

local function recordKey(lotId)
	return "rare_economy_" .. lotId
end

local function makeDefaultRecord(active)
	return {
		Version = Config.DataVersion,
		LotId = active.LotId,
		OwnerUserId = active.OwnerUserId,
		BusinessType = active.BusinessType,
		BusinessCash = 0,
		Specimens = {},
		MiningReadyAt = 0,
		MuseumReadyAt = 0,
		Stats = {
			Mined = 0,
			Purchased = 0,
			Sold = 0,
			Appraised = 0,
			FakesFound = 0,
			CityVisitors = 0,
			CityRevenue = 0,
		},
	}
end

local function normalizeSpecimen(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local spec = findSpec(raw.Kind)
	if not spec then
		return nil
	end
	local id = type(raw.Id) == "string" and raw.Id or ""
	if id == "" or #id > 80 then
		return nil
	end

	return {
		Id = id,
		Kind = spec.Id,
		Rarity = spec.Rarity,
		Authentic = raw.Authentic == true,
		Appraised = raw.Appraised == true,
		Displayed = raw.Displayed == true,
		AskingPrice = math.clamp(
			math.floor(tonumber(raw.AskingPrice) or spec.BaseValue),
			Config.MinSpecimenPrice,
			Config.MaxSpecimenPrice
		),
		SourceLotId = type(raw.SourceLotId) == "string" and string.sub(raw.SourceLotId, 1, 32) or "",
		CreatedAt = math.max(0, math.floor(tonumber(raw.CreatedAt) or os.time())),
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
	record.MiningReadyAt = math.max(0, math.floor(tonumber(record.MiningReadyAt) or 0))
	record.MuseumReadyAt = math.max(0, math.floor(tonumber(record.MuseumReadyAt) or 0))

	local cleanSpecimens = {}
	if type(record.Specimens) == "table" then
		for _, raw in ipairs(record.Specimens) do
			if #cleanSpecimens >= Config.MaxSpecimensPerBusiness then
				break
			end
			local specimen = normalizeSpecimen(raw)
			if specimen then
				if active.BusinessType ~= "Museum" then
					specimen.Displayed = false
				end
				table.insert(cleanSpecimens, specimen)
			end
		end
	end
	record.Specimens = cleanSpecimens

	if type(record.Stats) ~= "table" then
		record.Stats = {}
	end
	for _, key in ipairs({ "Mined", "Purchased", "Sold", "Appraised", "FakesFound", "CityVisitors", "CityRevenue" }) do
		record.Stats[key] = math.max(0, math.floor(tonumber(record.Stats[key]) or 0))
	end

	return record
end

local function loadRecord(lotId)
	local active = getActiveBusiness(lotId)
	if not active or not isSupportedBusinessType(active.BusinessType) then
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
		warn(string.format("[MiningMuseumService] Failed to load %s", lotId))
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
		warn(string.format("[MiningMuseumService] Failed to save %s: %s", lotId, tostring(errorMessage)))
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

local function findSpecimenIndex(record, specimenId)
	if not record or type(specimenId) ~= "string" then
		return nil
	end
	for index, specimen in ipairs(record.Specimens) do
		if specimen.Id == specimenId then
			return index
		end
	end
	return nil
end

local function computeMuseumPrestige(record)
	local prestige = 0
	local displayedCount = 0
	for _, specimen in ipairs(record.Specimens) do
		if specimen.Displayed and specimen.Appraised and specimen.Authentic then
			prestige += Config.RarityPrestige[specimen.Rarity] or 0
			displayedCount += 1
		end
	end
	return prestige, displayedCount
end

local function sanitizeSpecimen(specimen)
	local spec = findSpec(specimen.Kind)
	local authenticResult = nil
	local estimatedValue = nil
	if specimen.Appraised then
		authenticResult = specimen.Authentic and "Authentic" or "Fake"
		estimatedValue = specimen.Authentic and spec.BaseValue or 0
	end
	return {
		Id = specimen.Id,
		Kind = specimen.Kind,
		DisplayName = spec.DisplayName,
		Rarity = specimen.Rarity,
		RarityLabel = Config.RarityLabels[specimen.Rarity] or specimen.Rarity,
		AskingPrice = specimen.AskingPrice,
		Appraised = specimen.Appraised,
		Appraisal = authenticResult,
		EstimatedValue = estimatedValue,
		Displayed = specimen.Displayed,
		SourceLotId = specimen.SourceLotId,
		CreatedAt = specimen.CreatedAt,
	}
end

local function sanitizedSpecimens(record, isOwner)
	local result = {}
	for _, specimen in ipairs(record.Specimens) do
		if record.BusinessType ~= "Museum" or isOwner or specimen.Displayed then
			table.insert(result, sanitizeSpecimen(specimen))
		end
	end
	table.sort(result, function(a, b)
		if a.Displayed ~= b.Displayed then
			return a.Displayed
		end
		return a.CreatedAt > b.CreatedAt
	end)
	return result
end

local function getOwnedMuseums(player)
	local data = playerDataService and playerDataService:Get(player)
	local result = {}
	if not data or type(data.OwnedLots) ~= "table" then
		return result
	end
	for _, lotId in ipairs(data.OwnedLots) do
		local active = getActiveBusiness(lotId)
		if active and active.OwnerUserId == player.UserId and active.BusinessType == "Museum" then
			local record = loadRecord(lotId)
			if record then
				local prestige, displayedCount = computeMuseumPrestige(record)
				table.insert(result, {
					LotId = lotId,
					BusinessCash = record.BusinessCash,
					Prestige = prestige,
					DisplayedCount = displayedCount,
				})
			end
		end
	end
	table.sort(result, function(a, b)
		return a.LotId < b.LotId
	end)
	return result
end

local function getState(player, lotId)
	if type(lotId) ~= "string" or #lotId > 32 then
		return { Ok = false, Error = "Empresa inválida" }
	end
	local active = getActiveBusiness(lotId)
	if not active or not isSupportedBusinessType(active.BusinessType) then
		return { Ok = false, Error = "Esta empresa não participa da cadeia de mineração e museu" }
	end
	local record = loadRecord(lotId)
	if not record then
		return { Ok = false, Error = "Não foi possível carregar a empresa" }
	end

	local isOwner = active.OwnerUserId == player.UserId
	local prestige, displayedCount = computeMuseumPrestige(record)
	return {
		Ok = true,
		ServerTime = os.time(),
		Target = {
			LotId = lotId,
			OwnerUserId = active.OwnerUserId,
			BusinessType = active.BusinessType,
			DisplayName = BusinessConfig.Types[active.BusinessType].DisplayName,
			IsOwner = isOwner,
			OwnerOnline = Players:GetPlayerByUserId(active.OwnerUserId) ~= nil,
		},
		PersonalCash = player:GetAttribute("Cash") or 0,
		Economy = {
			BusinessCash = record.BusinessCash,
			MiningReadyIn = math.max(0, record.MiningReadyAt - os.time()),
			MuseumReadyIn = math.max(0, record.MuseumReadyAt - os.time()),
			Prestige = prestige,
			DisplayedCount = displayedCount,
			Specimens = sanitizedSpecimens(record, isOwner),
			Stats = deepCopy(record.Stats),
		},
		BuyerMuseums = getOwnedMuseums(player),
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
		return { Ok = false, Error = "O depósito falhou e foi revertido" }
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
		return { Ok = false, Error = "O caixa desta empresa está ocupado" }
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

local function chooseMiningFind()
	local totalWeight = 0
	for _, spec in ipairs(Config.Finds) do
		totalWeight += spec.Weight
	end
	local roll = rng:NextNumber(0, totalWeight)
	local cursor = 0
	for _, spec in ipairs(Config.Finds) do
		cursor += spec.Weight
		if roll <= cursor then
			return spec
		end
	end
	return Config.Finds[#Config.Finds]
end

local function mineSpecimen(player, lotId)
	if not playerOwnsBusiness(player, lotId, "MiningCompany") then
		return { Ok = false, Error = "Você precisa controlar esta Mineradora" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A extração já está sendo atualizada" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar a Mineradora" }
	end
	local now = os.time()
	if record.MiningReadyAt > now then
		local remaining = record.MiningReadyAt - now
		releaseLots(locked)
		return { Ok = false, Error = string.format("A próxima frente abre em %ds", remaining) }
	end
	if #record.Specimens >= Config.MaxSpecimensPerBusiness then
		releaseLots(locked)
		return { Ok = false, Error = "O cofre de achados da Mineradora está cheio" }
	end

	local before = deepCopy(record)
	local spec = chooseMiningFind()
	local authentic = rng:NextNumber() >= spec.FakeChance
	local marketFactor = rng:NextNumber(0.85, 1.25)
	local askingPrice = math.clamp(
		math.floor(spec.BaseValue * marketFactor),
		Config.MinSpecimenPrice,
		Config.MaxSpecimenPrice
	)
	local specimen = {
		Id = HttpService:GenerateGUID(false),
		Kind = spec.Id,
		Rarity = spec.Rarity,
		Authentic = authentic,
		Appraised = false,
		Displayed = false,
		AskingPrice = askingPrice,
		SourceLotId = lotId,
		CreatedAt = now,
	}
	table.insert(record.Specimens, specimen)
	record.MiningReadyAt = now + Config.MiningCooldown
	record.Stats.Mined += 1

	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "O achado não pôde ser salvo" }
	end

	releaseLots(locked)
	return {
		Ok = true,
		Message = string.format("Achado: %s · %s · autenticidade desconhecida", spec.DisplayName, Config.RarityLabels[spec.Rarity]),
	}
end

local function setSpecimenPrice(player, lotId, specimenId, delta)
	if not playerOwnsBusiness(player, lotId, "MiningCompany") then
		return { Ok = false, Error = "Você precisa controlar esta Mineradora" }
	end
	delta = math.floor(tonumber(delta) or 0)
	if delta ~= Config.SpecimenPriceStep and delta ~= -Config.SpecimenPriceStep then
		return { Ok = false, Error = "Alteração de preço inválida" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A tabela de ofertas está ocupada" }
	end
	local record = loadRecord(lotId)
	local index = record and findSpecimenIndex(record, specimenId)
	if not index then
		releaseLots(locked)
		return { Ok = false, Error = "Achado não encontrado" }
	end
	record.Specimens[index].AskingPrice = math.clamp(
		record.Specimens[index].AskingPrice + delta,
		Config.MinSpecimenPrice,
		Config.MaxSpecimenPrice
	)
	if not saveRecord(lotId) then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível salvar o preço" }
	end
	local price = record.Specimens[index].AskingPrice
	releaseLots(locked)
	return { Ok = true, Message = string.format("Novo preço do achado: $%d", price) }
end

local function buySpecimen(player, sellerLotId, buyerLotId, specimenId)
	if not playerOwnsBusiness(player, buyerLotId, "Museum") then
		return { Ok = false, Error = "A compra precisa ser feita por um Museu seu" }
	end
	local seller = getActiveBusiness(sellerLotId)
	if not seller or seller.BusinessType ~= "MiningCompany" then
		return { Ok = false, Error = "O vendedor não é uma Mineradora ativa" }
	end
	if not Players:GetPlayerByUserId(seller.OwnerUserId) then
		return { Ok = false, Error = "O dono da Mineradora precisa estar neste servidor" }
	end
	if sellerLotId == buyerLotId then
		return { Ok = false, Error = "Empresas inválidas para esta negociação" }
	end

	local locked = acquireLots({ sellerLotId, buyerLotId })
	if not locked then
		return { Ok = false, Error = "Uma das empresas está concluindo outra operação" }
	end
	local sellerRecord = loadRecord(sellerLotId)
	local buyerRecord = loadRecord(buyerLotId)
	local index = sellerRecord and findSpecimenIndex(sellerRecord, specimenId)
	if not sellerRecord or not buyerRecord or not index then
		releaseLots(locked)
		return { Ok = false, Error = "O achado não está mais disponível" }
	end
	if #buyerRecord.Specimens >= Config.MaxSpecimensPerBusiness then
		releaseLots(locked)
		return { Ok = false, Error = "A reserva técnica do Museu está cheia" }
	end

	local specimen = sellerRecord.Specimens[index]
	local price = specimen.AskingPrice
	if buyerRecord.BusinessCash < price then
		releaseLots(locked)
		return { Ok = false, Error = string.format("O Museu precisa de $%d no caixa", price) }
	end

	local sellerBefore = deepCopy(sellerRecord)
	local buyerBefore = deepCopy(buyerRecord)
	table.remove(sellerRecord.Specimens, index)
	specimen.Displayed = false
	table.insert(buyerRecord.Specimens, specimen)
	sellerRecord.BusinessCash += price
	buyerRecord.BusinessCash -= price
	sellerRecord.Stats.Sold += 1
	buyerRecord.Stats.Purchased += 1

	local sellerSaved = saveRecord(sellerLotId)
	local buyerSaved = sellerSaved and saveRecord(buyerLotId)
	if not buyerSaved then
		records[sellerLotId] = sellerBefore
		records[buyerLotId] = buyerBefore
		saveRecord(sellerLotId)
		saveRecord(buyerLotId)
		releaseLots(locked)
		return { Ok = false, Error = "A compra falhou e foi revertida" }
	end

	local spec = findSpec(specimen.Kind)
	releaseLots(locked)
	return { Ok = true, Message = string.format("Museu comprou %s por $%d · autenticidade ainda desconhecida", spec.DisplayName, price) }
end

local function appraiseSpecimen(player, lotId, specimenId)
	if not playerOwnsBusiness(player, lotId, "Museum") then
		return { Ok = false, Error = "Você precisa controlar este Museu" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O laboratório de avaliação está ocupado" }
	end
	local record = loadRecord(lotId)
	local index = record and findSpecimenIndex(record, specimenId)
	if not index then
		releaseLots(locked)
		return { Ok = false, Error = "Peça não encontrada" }
	end
	local specimen = record.Specimens[index]
	if specimen.Appraised then
		releaseLots(locked)
		return { Ok = false, Error = "Esta peça já foi avaliada" }
	end
	if record.BusinessCash < Config.AppraisalFee then
		releaseLots(locked)
		return { Ok = false, Error = string.format("O Museu precisa de $%d para a avaliação", Config.AppraisalFee) }
	end

	local before = deepCopy(record)
	record.BusinessCash -= Config.AppraisalFee
	specimen.Appraised = true
	record.Stats.Appraised += 1
	if not specimen.Authentic then
		record.Stats.FakesFound += 1
	end
	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "A avaliação não pôde ser salva" }
	end

	local spec = findSpec(specimen.Kind)
	local message = specimen.Authentic
		and string.format("AUTÊNTICO ✓ · %s avaliado em cerca de $%d", spec.DisplayName, spec.BaseValue)
		or string.format("FALSIFICAÇÃO ✕ · %s não gera prestígio", spec.DisplayName)
	releaseLots(locked)
	return { Ok = true, Message = message }
end

local function toggleDisplay(player, lotId, specimenId)
	if not playerOwnsBusiness(player, lotId, "Museum") then
		return { Ok = false, Error = "Você precisa controlar este Museu" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A exposição está sendo atualizada" }
	end
	local record = loadRecord(lotId)
	local index = record and findSpecimenIndex(record, specimenId)
	if not index then
		releaseLots(locked)
		return { Ok = false, Error = "Peça não encontrada" }
	end
	local specimen = record.Specimens[index]
	if not specimen.Appraised or not specimen.Authentic then
		releaseLots(locked)
		return { Ok = false, Error = "Somente peças autênticas e avaliadas podem ser expostas" }
	end
	if not specimen.Displayed then
		local _, displayedCount = computeMuseumPrestige(record)
		if displayedCount >= Config.MaxDisplayedSpecimens then
			releaseLots(locked)
			return { Ok = false, Error = "A exposição principal está lotada" }
		end
	end
	specimen.Displayed = not specimen.Displayed
	if not saveRecord(lotId) then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível atualizar a exposição" }
	end
	local spec = findSpec(specimen.Kind)
	local message = specimen.Displayed and (spec.DisplayName .. " colocado em exposição") or (spec.DisplayName .. " movido para a reserva técnica")
	releaseLots(locked)
	return { Ok = true, Message = message }
end

local function discardFake(player, lotId, specimenId)
	if not playerOwnsBusiness(player, lotId, "Museum") then
		return { Ok = false, Error = "Você precisa controlar este Museu" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "A reserva técnica está ocupada" }
	end
	local record = loadRecord(lotId)
	local index = record and findSpecimenIndex(record, specimenId)
	if not index then
		releaseLots(locked)
		return { Ok = false, Error = "Peça não encontrada" }
	end
	local specimen = record.Specimens[index]
	if not specimen.Appraised or specimen.Authentic then
		releaseLots(locked)
		return { Ok = false, Error = "Somente falsificações avaliadas podem ser descartadas" }
	end
	local spec = findSpec(specimen.Kind)
	table.remove(record.Specimens, index)
	if not saveRecord(lotId) then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível atualizar a reserva técnica" }
	end
	releaseLots(locked)
	return { Ok = true, Message = spec.DisplayName .. " falso removido da coleção" }
end

local function openMuseum(player, lotId)
	if not playerOwnsBusiness(player, lotId, "Museum") then
		return { Ok = false, Error = "Você precisa controlar este Museu" }
	end
	local locked = acquireLots({ lotId })
	if not locked then
		return { Ok = false, Error = "O Museu já está atendendo visitantes" }
	end
	local record = loadRecord(lotId)
	if not record then
		releaseLots(locked)
		return { Ok = false, Error = "Não foi possível carregar o Museu" }
	end
	local now = os.time()
	if record.MuseumReadyAt > now then
		local remaining = record.MuseumReadyAt - now
		releaseLots(locked)
		return { Ok = false, Error = string.format("Novo grupo chega em %ds", remaining) }
	end
	local prestige, displayedCount = computeMuseumPrestige(record)
	if displayedCount <= 0 or prestige <= 0 then
		releaseLots(locked)
		return { Ok = false, Error = "Coloque ao menos uma peça autêntica em exposição" }
	end

	local before = deepCopy(record)
	local revenue = math.min(Config.MuseumMaxRevenue, Config.MuseumBaseRevenue + prestige * Config.MuseumRevenuePerPrestige)
	local visitors = math.max(1, math.floor(5 + prestige * 0.6))
	record.BusinessCash += revenue
	record.MuseumReadyAt = now + Config.MuseumOpenCooldown
	record.Stats.CityVisitors += visitors
	record.Stats.CityRevenue += revenue
	if not saveRecord(lotId) then
		records[lotId] = before
		releaseLots(locked)
		return { Ok = false, Error = "A visitação não pôde ser salva" }
	end

	releaseLots(locked)
	return { Ok = true, Message = string.format("%d visitantes · prestígio %d · receita $%d", visitors, prestige, revenue) }
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
	elseif action == "MineSpecimen" then
		return mineSpecimen(player, payload.LotId)
	elseif action == "SetSpecimenPrice" then
		return setSpecimenPrice(player, payload.LotId, payload.SpecimenId, payload.Delta)
	elseif action == "BuySpecimen" then
		return buySpecimen(player, payload.SellerLotId, payload.BuyerLotId, payload.SpecimenId)
	elseif action == "AppraiseSpecimen" then
		return appraiseSpecimen(player, payload.LotId, payload.SpecimenId)
	elseif action == "ToggleDisplay" then
		return toggleDisplay(player, payload.LotId, payload.SpecimenId)
	elseif action == "DiscardFake" then
		return discardFake(player, payload.LotId, payload.SpecimenId)
	elseif action == "OpenMuseum" then
		return openMuseum(player, payload.LotId)
	end
	return { Ok = false, Error = "Ação desconhecida" }
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
	openRemote = createRemote(remotes, "RemoteEvent", "OpenMiningMuseum")
	local getStateRemote = createRemote(remotes, "RemoteFunction", "GetMiningMuseumState")
	local actionRemote = createRemote(remotes, "RemoteFunction", "MiningMuseumAction")
	getStateRemote.OnServerInvoke = getState
	actionRemote.OnServerInvoke = economyAction
end

local function removeLegacyPrompt(sign)
	local legacy = sign:FindFirstChild("EconomyPromptAttachment")
	if legacy then
		legacy:Destroy()
	end
end

local function attachPromptToSign(sign)
	if not sign:IsA("BasePart") then
		return
	end

	if not sign:GetAttribute("MiningMuseumPromptBound") then
		sign:SetAttribute("MiningMuseumPromptBound", true)
		sign.ChildAdded:Connect(function(child)
			if child.Name == "EconomyPromptAttachment" then
				task.defer(function()
					if child.Parent == sign then
						child:Destroy()
					end
				end)
			end
		end)
	end

	task.defer(function()
		local active = getActiveBusiness(sign.Name)
		if not active or not isSupportedBusinessType(active.BusinessType) or not openRemote then
			return
		end
		removeLegacyPrompt(sign)
		if sign:FindFirstChild("MiningMuseumPromptAttachment") then
			return
		end
		loadRecord(sign.Name)

		local attachment = Instance.new("Attachment")
		attachment.Name = "MiningMuseumPromptAttachment"
		attachment.Parent = sign

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "MiningMuseumPrompt"
		prompt.ActionText = active.BusinessType == "MiningCompany" and "Ver achados" or "Visitar coleção"
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
	if not signs then
		warn("[MiningMuseumService] BusinessSigns folder is missing")
		return
	end
	for _, sign in ipairs(signs:GetChildren()) do
		attachPromptToSign(sign)
	end
	signs.ChildAdded:Connect(attachPromptToSign)

	-- BusinessEconomyService attaches its generic prompt with task.defer. Sweep
	-- once more after startup so Mining/Museum signs only expose this terminal.
	task.delay(1, function()
		for _, sign in ipairs(signs:GetChildren()) do
			local active = getActiveBusiness(sign.Name)
			if active and isSupportedBusinessType(active.BusinessType) then
				removeLegacyPrompt(sign)
				attachPromptToSign(sign)
			end
		end
	end)
end

function MiningMuseumService:Start(dataService)
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

	print("[Property Empire v2] MiningMuseumService started: Mining -> Appraisal -> Museum")
end

return MiningMuseumService
