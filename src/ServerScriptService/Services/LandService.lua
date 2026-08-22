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
		label.Text = string.format("%s · PROPRIETÁRIO #%d", part.Name, record.OwnerUserId)
	elseif isPendingActive(record) then
		label.Text = string.format("%s · PROCESSANDO", part.Name)
	else
		label.Text = string.format("%s · %s", part.Name, formatMoney(record.Price))
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
	billboard.Size = UDim2.fromOffset(190, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, part.Size.Z / 2 - 6)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 42
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "StatusLabel"
	label.BackgroundTransparency = 0.18
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 29)
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = label
end

local function createPrompt(part, lotId)
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAttachment"
	attachment.Position = Vector3.new(0, 3, part.Size.Z / 2 - 7)
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

local function createFlatPart(parent, name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createAreaMarker(parent, name, displayName, position)
	local anchor = Instance.new("Part")
	anchor.Name = name .. "Marker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(0, 8, 0)
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(210, 38)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 260
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(25, 30, 36)
	label.BackgroundTransparency = 0.15
	label.Text = displayName
	label.TextColor3 = Color3.fromRGB(245, 247, 250)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function createRoadNetwork(world)
	local roadsFolder = Instance.new("Folder")
	roadsFolder.Name = "Roads"
	roadsFolder.Parent = world

	for _, road in ipairs(LandConfig.Roads) do
		createFlatPart(
			roadsFolder,
			road.Name,
			road.Size,
			road.Position,
			Color3.fromRGB(48, 51, 54),
			Enum.Material.Concrete
		)
	end
end

local function createReservedZones(world)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "ReservedZones"
	zonesFolder.Parent = world

	for _, zone in ipairs(LandConfig.ReservedZones) do
		local pad = createFlatPart(zonesFolder, zone.Name, zone.Size, zone.Center, zone.Color, zone.Material)
		pad:SetAttribute("ZoneName", zone.Name)
		pad:SetAttribute("ReservedForFutureSystems", true)

		local markerPosition = Vector3.new(
			zone.Center.X,
			0,
			zone.Center.Z - zone.Size.Z / 2 + 28
		)
		createAreaMarker(zonesFolder, zone.Name, zone.DisplayName, markerPosition)
	end
end

local function createDistrictLots(world, lotsFolder, district)
	local lotSize = district.LotSize
	local width = district.Columns * lotSize.X + (district.Columns - 1) * district.Spacing
	local depth = district.Rows * lotSize.Z + (district.Rows - 1) * district.Spacing
	local startX = district.Origin.X - width / 2 + lotSize.X / 2
	local startZ = district.Origin.Z - depth / 2 + lotSize.Z / 2
	local localIndex = 0

	for row = 1, district.Rows do
		for column = 1, district.Columns do
			localIndex += 1
			local index = district.FirstLotIndex + localIndex - 1
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
			lot:SetAttribute("DistrictName", district.Name)
			lot.Parent = lotsFolder
			lotParts[lotId] = lot

			createBillboard(lot)
			createPrompt(lot, lotId)
			applyRecordToPart(lot, makeAvailableRecord(lotId))
		end
	end

	createAreaMarker(world, district.Name, district.DisplayName, district.Origin + district.MarkerOffset)
end

local function createWorld()
	local previous = Workspace:FindFirstChild("PropertyEmpireV2World")
	if previous then
		previous:Destroy()
	end
	table.clear(lotParts)

	local world = Instance.new("Folder")
	world.Name = "PropertyEmpireV2World"
	world:SetAttribute("WorldVersion", 2)
	world.Parent = Workspace

	local worldConfig = LandConfig.World
	createFlatPart(
		world,
		"Ground",
		worldConfig.Size,
		Vector3.new(0, -1.5, 0),
		worldConfig.GroundColor,
		worldConfig.GroundMaterial
	)

	createRoadNetwork(world)
	createReservedZones(world)

	local plaza = createFlatPart(
		world,
		"CivicPlaza",
		Vector3.new(150, 1, 78),
		Vector3.new(0, -0.45, 145),
		Color3.fromRGB(157, 158, 154),
		Enum.Material.Concrete
	)
	plaza:SetAttribute("CivicArea", true)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.Position = worldConfig.SpawnPosition
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = Color3.fromRGB(85, 170, 255)
	spawn.Parent = world

	local lotsFolder = Instance.new("Folder")
	lotsFolder.Name = "Lots"
	lotsFolder.Parent = world

	for _, district in ipairs(LandConfig.Districts) do
		createDistrictLots(world, lotsFolder, district)
	end
end

local function loadPersistentOwners()
	local lotIds = {}
	for lotId in pairs(lotParts) do
		table.insert(lotIds, lotId)
	end
	table.sort(lotIds)

	for index, lotId in ipairs(lotIds) do
		local part = lotParts[lotId]
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

		-- Avoid hammering the DataStore budget as the city gains more lots.
		if index % 4 == 0 then
			task.wait(0.08)
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

	local lotCount = 0
	for _ in pairs(lotParts) do
		lotCount += 1
	end
	print(string.format("[Property Empire v2] LandService started with %d lots across expanded city districts", lotCount))
end

return LandService
