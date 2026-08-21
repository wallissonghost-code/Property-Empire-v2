local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LandConfig = require(Shared.LandConfig)

local LandService = {}
local lotStore = DataStoreService:GetDataStore(LandConfig.DataStoreName)
local purchaseLocks = {}
local lotParts = {}
local playerDataService = nil
local started = false

local COLORS = {
	Available = Color3.fromRGB(103, 180, 103),
	Owned = Color3.fromRGB(230, 190, 92),
	Pending = Color3.fromRGB(236, 143, 73),
	Unavailable = Color3.fromRGB(115, 115, 115),
}

local function formatMoney(value)
	local text = tostring(math.floor(value))
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

local function lotKey(lotId)
	return "lot_" .. lotId
end

local function isPendingActive(record)
	return record
		and record.State == "Pending"
		and type(record.ReservationExpiresAt) == "number"
		and record.ReservationExpiresAt > os.time()
end

local function makeAvailableRecord(lotId)
	return {
		LotId = lotId,
		State = "Available",
		OwnerUserId = 0,
		ReservedBy = 0,
		ReservationExpiresAt = 0,
		Price = LandConfig.StarterPrice,
	}
end

local function normalizeRecord(lotId, record)
	if type(record) ~= "table" then
		return makeAvailableRecord(lotId)
	end

	record.LotId = lotId
	record.Price = tonumber(record.Price) or LandConfig.StarterPrice
	record.OwnerUserId = tonumber(record.OwnerUserId) or 0
	record.ReservedBy = tonumber(record.ReservedBy) or 0
	record.ReservationExpiresAt = tonumber(record.ReservationExpiresAt) or 0

	if record.OwnerUserId > 0 then
		record.State = "Owned"
	elseif record.State == "Pending" and record.ReservationExpiresAt <= os.time() then
		record.State = "Available"
		record.ReservedBy = 0
		record.ReservationExpiresAt = 0
	elseif record.State ~= "Pending" then
		record.State = "Available"
	end

	return record
end

local function setLabelText(part, record)
	local billboard = part:FindFirstChild("StatusBillboard")
	local label = billboard and billboard:FindFirstChild("StatusLabel")
	if not label then
		return
	end

	if record.State == "Owned" then
		label.Text = string.format("%s\nPROPRIEDADE DE #%d", part.Name, record.OwnerUserId)
	elseif isPendingActive(record) then
		label.Text = string.format("%s\nCOMPRA EM PROCESSAMENTO", part.Name)
	else
		label.Text = string.format("%s\nDISPONÍVEL · %s", part.Name, formatMoney(record.Price))
	end
end

local function applyRecordToPart(part, record)
	record = normalizeRecord(part.Name, record)
	part:SetAttribute("LotId", part.Name)
	part:SetAttribute("OwnerUserId", record.OwnerUserId)
	part:SetAttribute("Price", record.Price)
	part:SetAttribute("State", record.State)

	local promptAttachment = part:FindFirstChild("PromptAttachment")
	local prompt = promptAttachment and promptAttachment:FindFirstChildOfClass("ProximityPrompt")

	if record.State == "Owned" then
		part.Color = COLORS.Owned
		if prompt then
			prompt.Enabled = false
		end
	elseif isPendingActive(record) then
		part.Color = COLORS.Pending
		if prompt then
			prompt.Enabled = false
		end
	else
		part.Color = COLORS.Available
		if prompt then
			prompt.ActionText = "Comprar lote"
			prompt.ObjectText = string.format("%s · %s", part.Name, formatMoney(record.Price))
			prompt.Enabled = true
		end
	end

	setLabelText(part, record)
end

local function loadLotRecord(lotId)
	local success, result = pcall(function()
		return lotStore:GetAsync(lotKey(lotId))
	end)

	if not success then
		warn(string.format("[LandService] Failed to load %s", lotId))
		return nil
	end

	return normalizeRecord(lotId, result)
end

local function releaseReservation(lotId, userId)
	pcall(function()
		lotStore:UpdateAsync(lotKey(lotId), function(current)
			current = normalizeRecord(lotId, current)
			if current.State == "Pending" and current.ReservedBy == userId then
				return makeAvailableRecord(lotId)
			end
			return current
		end)
	end)
end

local function reserveLot(lotId, userId)
	local now = os.time()
	local success, result = pcall(function()
		return lotStore:UpdateAsync(lotKey(lotId), function(current)
			current = normalizeRecord(lotId, current)

			if current.State == "Owned" then
				return current
		end

			if isPendingActive(current) and current.ReservedBy ~= userId then
				return current
			end

			current.State = "Pending"
			current.OwnerUserId = 0
			current.ReservedBy = userId
			current.ReservationExpiresAt = now + LandConfig.ReservationSeconds
			current.Price = LandConfig.StarterPrice
			return current
		end)
	end)

	if not success then
		return false, nil
	end

	result = normalizeRecord(lotId, result)
	local reserved = result.State == "Pending" and result.ReservedBy == userId
	return reserved, result
end

local function finalizeLot(lotId, userId)
	local success, result = pcall(function()
		return lotStore:UpdateAsync(lotKey(lotId), function(current)
			current = normalizeRecord(lotId, current)
			if current.State == "Pending" and current.ReservedBy == userId then
				current.State = "Owned"
				current.OwnerUserId = userId
				current.ReservedBy = 0
				current.ReservationExpiresAt = 0
				current.PurchasedAt = os.time()
				return current
			end
			return current
		end)
	end)

	if not success then
		return false, nil
	end

	result = normalizeRecord(lotId, result)
	return result.State == "Owned" and result.OwnerUserId == userId, result
end

local function purchaseLot(player, lotId)
	if purchaseLocks[lotId] then
		return
	end
	purchaseLocks[lotId] = true

	local part = lotParts[lotId]
	local data = playerDataService:Get(player)
	if not part or not data then
		purchaseLocks[lotId] = nil
		return
	end

	if table.find(data.OwnedLots, lotId) then
		purchaseLocks[lotId] = nil
		return
	end

	if data.Cash < LandConfig.StarterPrice then
		player:SetAttribute("LastLandPurchaseError", "Dinheiro insuficiente")
		purchaseLocks[lotId] = nil
		return
	end

	local reserved, reservationRecord = reserveLot(lotId, player.UserId)
	if not reserved then
		if reservationRecord then
			applyRecordToPart(part, reservationRecord)
		end
		player:SetAttribute("LastLandPurchaseError", "Este lote não está mais disponível")
		purchaseLocks[lotId] = nil
		return
	end

	applyRecordToPart(part, reservationRecord)

	local adjusted = playerDataService:AdjustCash(player, -LandConfig.StarterPrice)
	local added = adjusted and playerDataService:AddOwnedLot(player, lotId)
	local saved = added and playerDataService:Save(player)

	if not saved then
		if added then
			playerDataService:RemoveOwnedLot(player, lotId)
		end
		if adjusted then
			playerDataService:AdjustCash(player, LandConfig.StarterPrice)
		end
		releaseReservation(lotId, player.UserId)
		applyRecordToPart(part, makeAvailableRecord(lotId))
		player:SetAttribute("LastLandPurchaseError", "Não foi possível salvar a compra")
		purchaseLocks[lotId] = nil
		return
	end

	local finalized, finalRecord = finalizeLot(lotId, player.UserId)
	if not finalized then
		playerDataService:RemoveOwnedLot(player, lotId)
		playerDataService:AdjustCash(player, LandConfig.StarterPrice)
		playerDataService:Save(player)
		releaseReservation(lotId, player.UserId)
		applyRecordToPart(part, finalRecord or makeAvailableRecord(lotId))
		player:SetAttribute("LastLandPurchaseError", "A compra não pôde ser concluída")
		purchaseLocks[lotId] = nil
		return
	end

	applyRecordToPart(part, finalRecord)
	player:SetAttribute("LastLandPurchaseError", "")
	player:SetAttribute("LastPurchasedLot", lotId)
	purchaseLocks[lotId] = nil
end

local function createBillboard(part)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StatusBillboard"
	billboard.Size = UDim2.fromOffset(260, 64)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 29)
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function createPrompt(part, lotId)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAttachment"
	attachment.Position = Vector3.new(0, 3, 0)
	attachment.Parent = part

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Comprar lote"
	prompt.ObjectText = lotId
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment
	prompt.Triggered:Connect(function(player)
		purchaseLot(player, lotId)
	end)
end

local function createWorld()
	local previous = Workspace:FindFirstChild("PropertyEmpireV2World")
	if previous then
		previous:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "PropertyEmpireV2World"
	world.Parent = Workspace

	local district = LandConfig.StarterDistrict
	local lotSize = district.LotSize
	local width = district.Columns * lotSize.X + (district.Columns - 1) * district.Spacing
	local depth = district.Rows * lotSize.Z + (district.Rows - 1) * district.Spacing

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(width + district.GroundPadding * 2, 2, depth + district.GroundPadding * 2)
	ground.Position = Vector3.new(0, -1.5, 0)
	ground.Material = Enum.Material.Concrete
	ground.Color = Color3.fromRGB(86, 91, 94)
	ground.Parent = world

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.Position = Vector3.new(0, 0.5, depth / 2 + 24)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(85, 170, 255)
	spawn.Parent = world

	local lotsFolder = Instance.new("Folder")
	lotsFolder.Name = "Lots"
	lotsFolder.Parent = world

	local startX = -width / 2 + lotSize.X / 2
	local startZ = -depth / 2 + lotSize.Z / 2
	local index = 0

	for row = 1, district.Rows do
		for column = 1, district.Columns do
			index += 1
			local lotId = string.format("LOT-%02d", index)
			local lot = Instance.new("Part")
			lot.Name = lotId
			lot.Anchored = true
			lot.Size = lotSize
			lot.Position = Vector3.new(
				startX + (column - 1) * (lotSize.X + district.Spacing),
				0,
				startZ + (row - 1) * (lotSize.Z + district.Spacing)
			)
			lot.Material = Enum.Material.Grass
			lot.TopSurface = Enum.SurfaceType.Smooth
			lot.BottomSurface = Enum.SurfaceType.Smooth
			lot.Parent = lotsFolder
			lotParts[lotId] = lot

			createBillboard(lot)
			createPrompt(lot, lotId)
			applyRecordToPart(lot, makeAvailableRecord(lotId))
		end
	end
end

local function loadPersistentOwners()
	for lotId, part in pairs(lotParts) do
		local record = loadLotRecord(lotId)
		if record then
			applyRecordToPart(part, record)
		else
			part.Color = COLORS.Unavailable
			part:SetAttribute("State", "Unavailable")
			local attachment = part:FindFirstChild("PromptAttachment")
			local prompt = attachment and attachment:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = false
			end
		end
	end
end

function LandService:Start(dataService)
	if started then
		return
	end
	started = true
	playerDataService = dataService

	createWorld()
	loadPersistentOwners()
	print("[Property Empire v2] LandService started with 12 starter lots")
end

return LandService
