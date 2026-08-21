local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildConfig = require(Shared.BuildConfig)

local BuildService = {}
local buildStore = DataStoreService:GetDataStore(BuildConfig.DataStoreName)
local playerDataService = nil
local started = false
local lotBuilds = {}
local lastPlacementAt = {}
local lastRemovalAt = {}
local lastPlacedByPlayer = {}
local buildsFolder = nil

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

local function buildKey(lotId)
	return "build_" .. lotId
end

local function getWorld()
	return Workspace:FindFirstChild("PropertyEmpireV2World")
end

local function getLotPart(lotId)
	local world = getWorld()
	local lots = world and world:FindFirstChild("Lots")
	local lot = lots and lots:FindFirstChild(lotId)
	if lot and lot:IsA("BasePart") then
		return lot
	end
	return nil
end

local function getLotBuildFolder(lotId)
	return buildsFolder and buildsFolder:FindFirstChild(lotId)
end

local function getOwnedLots(player)
	local data = playerDataService and playerDataService:Get(player)
	if not data or type(data.OwnedLots) ~= "table" then
		return {}
	end
	return deepCopy(data.OwnedLots)
end

local function playerOwnsLot(player, lotId)
	local data = playerDataService and playerDataService:Get(player)
	if not data or type(data.OwnedLots) ~= "table" then
		return false
	end

	local lot = getLotPart(lotId)
	if not lot or lot:GetAttribute("OwnerUserId") ~= player.UserId then
		return false
	end

	return table.find(data.OwnedLots, lotId) ~= nil
end

local function isInteger(value)
	return type(value) == "number" and value == math.floor(value)
end

local function normalizedRotation(value)
	if not isInteger(value) then
		return nil
	end
	return value % 4
end

local function getRotatedFootprint(spec, rotation)
	if rotation % 2 == 1 then
		return spec.Size.Z, spec.Size.X
	end
	return spec.Size.X, spec.Size.Z
end

local function isPlacementInsideLot(lot, spec, gridX, gridZ, level, rotation)
	if not isInteger(gridX) or not isInteger(gridZ) then
		return false
	end
	if not isInteger(level) or level < 0 or level >= BuildConfig.MaxLevels then
		return false
	end

	local normalized = normalizedRotation(rotation)
	if normalized == nil then
		return false
	end

	local sizeX, sizeZ = getRotatedFootprint(spec, normalized)
	local centerX = gridX * BuildConfig.GridSize
	local centerZ = gridZ * BuildConfig.GridSize
	local maxX = lot.Size.X / 2 - BuildConfig.BoundaryMargin
	local maxZ = lot.Size.Z / 2 - BuildConfig.BoundaryMargin

	return math.abs(centerX) + sizeX / 2 <= maxX and math.abs(centerZ) + sizeZ / 2 <= maxZ
end

local function getPieceCFrame(lot, spec, gridX, gridZ, level, rotation)
	local localY = lot.Size.Y / 2 + level * BuildConfig.LevelHeight + spec.Size.Y / 2
	return lot.CFrame
		* CFrame.new(gridX * BuildConfig.GridSize, localY, gridZ * BuildConfig.GridSize)
		* CFrame.Angles(0, math.rad(rotation * 90), 0)
end

local function setCommonPartProperties(part, spec)
	part.Anchored = true
	part.Material = spec.Material
	part.Color = spec.Color
	part.Transparency = tonumber(spec.Transparency) or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createPart(parent, name, size, cframe, spec)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	setCommonPartProperties(part, spec)
	part.Parent = parent
	return part
end

local function setPieceAttributes(root, entry)
	root:SetAttribute("BuildPieceId", entry.Id)
	root:SetAttribute("PieceType", entry.Type)
	root:SetAttribute("GridX", entry.GridX)
	root:SetAttribute("GridZ", entry.GridZ)
	root:SetAttribute("Level", entry.Level)
	root:SetAttribute("Rotation", entry.Rotation)
	root:SetAttribute("CreatedBy", entry.CreatedBy or 0)
	root:SetAttribute("PricePaid", entry.PricePaid or 0)
end

local function createDoorway(parent, entry, spec, baseCFrame)
	local model = Instance.new("Model")
	model.Name = entry.Id
	setPieceAttributes(model, entry)

	createPart(model, "Left", Vector3.new(2, 8, 1), baseCFrame * CFrame.new(-3, 0, 0), spec)
	createPart(model, "Right", Vector3.new(2, 8, 1), baseCFrame * CFrame.new(3, 0, 0), spec)
	createPart(model, "Lintel", Vector3.new(4, 2, 1), baseCFrame * CFrame.new(0, 3, 0), spec)

	model.Parent = parent
	return model
end

local function createWindow(parent, entry, spec, baseCFrame)
	local model = Instance.new("Model")
	model.Name = entry.Id
	setPieceAttributes(model, entry)

	createPart(model, "Left", Vector3.new(1, 8, 1), baseCFrame * CFrame.new(-3.5, 0, 0), spec)
	createPart(model, "Right", Vector3.new(1, 8, 1), baseCFrame * CFrame.new(3.5, 0, 0), spec)
	createPart(model, "Top", Vector3.new(6, 1, 1), baseCFrame * CFrame.new(0, 3.5, 0), spec)
	createPart(model, "Bottom", Vector3.new(6, 1, 1), baseCFrame * CFrame.new(0, -3.5, 0), spec)

	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Anchored = true
	glass.Size = Vector3.new(6, 6, 0.3)
	glass.CFrame = baseCFrame
	glass.Material = Enum.Material.Glass
	glass.Color = Color3.fromRGB(164, 213, 230)
	glass.Transparency = 0.35
	glass.TopSurface = Enum.SurfaceType.Smooth
	glass.BottomSurface = Enum.SurfaceType.Smooth
	glass.Parent = model

	model.Parent = parent
	return model
end

local function createStair(parent, entry, spec, baseCFrame)
	local model = Instance.new("Model")
	model.Name = entry.Id
	setPieceAttributes(model, entry)

	for index = 1, 8 do
		local y = -3.5 + (index - 1)
		local z = 7 - (index - 1) * 2
		createPart(
			model,
			string.format("Step%02d", index),
			Vector3.new(8, 1, 2),
			baseCFrame * CFrame.new(0, y, z),
			spec
		)
	end

	model.Parent = parent
	return model
end

local function createPieceInstance(lotId, entry)
	local spec = BuildConfig.Catalog[entry.Type]
	local lot = getLotPart(lotId)
	local lotFolder = getLotBuildFolder(lotId)
	if not spec or not lot or not lotFolder then
		return nil
	end

	if not isPlacementInsideLot(lot, spec, entry.GridX, entry.GridZ, entry.Level, entry.Rotation) then
		return nil
	end

	local baseCFrame = getPieceCFrame(lot, spec, entry.GridX, entry.GridZ, entry.Level, entry.Rotation)

	if entry.Type == "Doorway" then
		return createDoorway(lotFolder, entry, spec, baseCFrame)
	elseif entry.Type == "Window" then
		return createWindow(lotFolder, entry, spec, baseCFrame)
	elseif entry.Type == "Stair" then
		return createStair(lotFolder, entry, spec, baseCFrame)
	end

	local part = createPart(lotFolder, entry.Id, spec.Size, baseCFrame, spec)
	setPieceAttributes(part, entry)
	return part
end

local function destroyPieceInstance(lotId, pieceId)
	local lotFolder = getLotBuildFolder(lotId)
	local instance = lotFolder and lotFolder:FindFirstChild(pieceId)
	if instance then
		instance:Destroy()
	end
end

local function normalizeStoredPieces(lot, stored)
	local pieces = {}
	if type(stored) ~= "table" or type(stored.Pieces) ~= "table" then
		return pieces
	end

	for _, raw in ipairs(stored.Pieces) do
		if type(raw) == "table" then
			local spec = BuildConfig.Catalog[raw.Type]
			local rotation = normalizedRotation(raw.Rotation)
			if spec
				and type(raw.Id) == "string"
				and #raw.Id <= 64
				and isInteger(raw.GridX)
				and isInteger(raw.GridZ)
				and isInteger(raw.Level)
				and rotation ~= nil
				and isPlacementInsideLot(lot, spec, raw.GridX, raw.GridZ, raw.Level, rotation)
			then
				table.insert(pieces, {
					Id = raw.Id,
					Type = raw.Type,
					GridX = raw.GridX,
					GridZ = raw.GridZ,
					Level = raw.Level,
					Rotation = rotation,
					CreatedBy = tonumber(raw.CreatedBy) or 0,
					CreatedAt = tonumber(raw.CreatedAt) or 0,
					PricePaid = math.max(0, math.floor(tonumber(raw.PricePaid) or 0)),
				})
			end
		end

		if #pieces >= BuildConfig.MaxPiecesPerLot then
			break
		end
	end

	return pieces
end

local function loadLot(lot)
	local success, stored = pcall(function()
		return buildStore:GetAsync(buildKey(lot.Name))
	end)

	if not success then
		warn(string.format("[BuildService] Failed to load build for %s", lot.Name))
		lotBuilds[lot.Name] = {
			Available = false,
			Pieces = {},
			Dirty = false,
			Revision = 0,
			SaveScheduled = false,
		}
		return
	end

	local record = {
		Available = true,
		Pieces = normalizeStoredPieces(lot, stored),
		Dirty = false,
		Revision = 0,
		SaveScheduled = false,
	}
	lotBuilds[lot.Name] = record

	for _, entry in ipairs(record.Pieces) do
		createPieceInstance(lot.Name, entry)
	end
end

local function saveLot(lotId)
	local record = lotBuilds[lotId]
	if not record or not record.Available or not record.Dirty then
		return true
	end

	local revision = record.Revision
	local snapshot = {
		Version = BuildConfig.DataVersion,
		Pieces = deepCopy(record.Pieces),
		UpdatedAt = os.time(),
	}

	local success, errorMessage = pcall(function()
		buildStore:SetAsync(buildKey(lotId), snapshot)
	end)

	if not success then
		warn(string.format("[BuildService] Failed to save build for %s: %s", lotId, tostring(errorMessage)))
		return false
	end

	if record.Revision == revision then
		record.Dirty = false
	end
	return true
end

local function markDirty(lotId)
	local record = lotBuilds[lotId]
	if not record then
		return
	end
	record.Revision += 1
	record.Dirty = true
end

local function scheduleSave(lotId)
	local record = lotBuilds[lotId]
	if not record or record.SaveScheduled then
		return
	end

	record.SaveScheduled = true
	task.delay(BuildConfig.SaveDebounceSeconds, function()
		local current = lotBuilds[lotId]
		if not current then
			return
		end
		current.SaveScheduled = false
		saveLot(lotId)
		if current.Dirty then
			scheduleSave(lotId)
		end
	end)
end

local function findPieceIndex(record, pieceId)
	for index, entry in ipairs(record.Pieces) do
		if entry.Id == pieceId then
			return index, entry
		end
	end
	return nil, nil
end

local function hasPlacementConflict(record, pieceType, gridX, gridZ, level, rotation)
	local spec = BuildConfig.Catalog[pieceType]
	if not spec then
		return true
	end

	for _, entry in ipairs(record.Pieces) do
		if entry.GridX == gridX and entry.GridZ == gridZ and entry.Level == level then
			local otherSpec = BuildConfig.Catalog[entry.Type]
			if otherSpec and otherSpec.Slot == spec.Slot then
				if spec.Slot == "Wall" then
					if entry.Rotation % 2 == rotation % 2 then
						return true
					end
				elseif spec.Slot == "Floor" then
					return true
				elseif spec.Slot == "Stair" and entry.Rotation == rotation then
					return true
				end
			end
		end
	end
	return false
end

local function rollbackPlacedEntry(player, lotId, entry, chargedAmount)
	local record = lotBuilds[lotId]
	if record then
		local index = findPieceIndex(record, entry.Id)
		if index then
			table.remove(record.Pieces, index)
			markDirty(lotId)
		end
	end
	destroyPieceInstance(lotId, entry.Id)

	if chargedAmount > 0 then
		playerDataService:AdjustCash(player, chargedAmount)
	end
end

local function placePiece(player, payload)
	if type(payload) ~= "table" then
		return { Ok = false, Error = "Solicitação inválida" }
	end

	local now = os.clock()
	local last = lastPlacementAt[player] or 0
	if now - last < BuildConfig.PlacementCooldown then
		return { Ok = false, Error = "Construção rápida demais" }
	end
	lastPlacementAt[player] = now

	local lotId = payload.LotId
	local pieceType = payload.PieceType
	local gridX = payload.GridX
	local gridZ = payload.GridZ
	local level = payload.Level
	local rotation = normalizedRotation(payload.Rotation)

	if type(lotId) ~= "string" or #lotId > 32 or type(pieceType) ~= "string" then
		return { Ok = false, Error = "Dados inválidos" }
	end

	local spec = BuildConfig.Catalog[pieceType]
	local lot = getLotPart(lotId)
	local record = lotBuilds[lotId]
	if not spec or not lot or not record or not record.Available then
		return { Ok = false, Error = "Lote ou peça indisponível" }
	end

	if not playerOwnsLot(player, lotId) then
		return { Ok = false, Error = "Você não é proprietário deste lote" }
	end

	if rotation == nil or not isPlacementInsideLot(lot, spec, gridX, gridZ, level, rotation) then
		return { Ok = false, Error = "A peça precisa ficar dentro do lote" }
	end

	if #record.Pieces >= BuildConfig.MaxPiecesPerLot then
		return { Ok = false, Error = "Limite de peças deste lote atingido" }
	end

	if hasPlacementConflict(record, pieceType, gridX, gridZ, level, rotation) then
		return { Ok = false, Error = "Já existe uma peça ocupando esta posição" }
	end

	local price = math.max(0, math.floor(tonumber(spec.Price) or 0))
	local data = playerDataService:Get(player)
	if not data then
		return { Ok = false, Error = "Seus dados ainda não estão disponíveis" }
	end
	if price > 0 and data.Cash < price then
		return { Ok = false, Error = string.format("Você precisa de $%d", price) }
	end

	if price > 0 then
		local charged = playerDataService:AdjustCash(player, -price)
		if not charged then
			return { Ok = false, Error = "Saldo insuficiente" }
		end
	end

	local entry = {
		Id = HttpService:GenerateGUID(false),
		Type = pieceType,
		GridX = gridX,
		GridZ = gridZ,
		Level = level,
		Rotation = rotation,
		CreatedBy = player.UserId,
		CreatedAt = os.time(),
		PricePaid = price,
	}

	local instance = createPieceInstance(lotId, entry)
	if not instance then
		if price > 0 then
			playerDataService:AdjustCash(player, price)
		end
		return { Ok = false, Error = "Não foi possível criar a peça" }
	end

	table.insert(record.Pieces, entry)
	markDirty(lotId)

	if price > 0 then
		if not playerDataService:Save(player) then
			rollbackPlacedEntry(player, lotId, entry, price)
			return { Ok = false, Error = "Não foi possível confirmar o pagamento" }
		end

		if not saveLot(lotId) then
			rollbackPlacedEntry(player, lotId, entry, price)
			playerDataService:Save(player)
			return { Ok = false, Error = "Não foi possível salvar a construção; valor devolvido" }
		end
	else
		scheduleSave(lotId)
	end

	lastPlacedByPlayer[player] = {
		LotId = lotId,
		PieceId = entry.Id,
	}

	return {
		Ok = true,
		PieceId = entry.Id,
		PieceCount = #record.Pieces,
		PricePaid = price,
		Cash = player:GetAttribute("Cash") or data.Cash,
	}
end

local function removePieceById(player, lotId, pieceId, refundRate)
	if type(lotId) ~= "string" or #lotId > 32 or type(pieceId) ~= "string" or #pieceId > 64 then
		return { Ok = false, Error = "Dados inválidos" }
	end

	local record = lotBuilds[lotId]
	if not record or not record.Available then
		return { Ok = false, Error = "Construção indisponível" }
	end
	if not playerOwnsLot(player, lotId) then
		return { Ok = false, Error = "Você não é proprietário deste lote" }
	end

	local index, entry = findPieceIndex(record, pieceId)
	if not index or not entry then
		return { Ok = false, Error = "Peça não encontrada" }
	end

	local refund = math.floor(math.max(0, entry.PricePaid or 0) * refundRate)
	table.remove(record.Pieces, index)
	destroyPieceInstance(lotId, pieceId)
	markDirty(lotId)

	if refund > 0 then
		local adjusted = playerDataService:AdjustCash(player, refund)
		if not adjusted or not playerDataService:Save(player) then
			if adjusted then
				playerDataService:AdjustCash(player, -refund)
			end
			table.insert(record.Pieces, index, entry)
			createPieceInstance(lotId, entry)
			markDirty(lotId)
			return { Ok = false, Error = "Não foi possível confirmar o reembolso" }
		end
	end

	if not saveLot(lotId) then
		table.insert(record.Pieces, index, entry)
		createPieceInstance(lotId, entry)
		markDirty(lotId)
		if refund > 0 then
			playerDataService:AdjustCash(player, -refund)
			playerDataService:Save(player)
		end
		return { Ok = false, Error = "Não foi possível salvar a remoção" }
	end

	local lastPlaced = lastPlacedByPlayer[player]
	if lastPlaced and lastPlaced.LotId == lotId and lastPlaced.PieceId == pieceId then
		lastPlacedByPlayer[player] = nil
	end

	return {
		Ok = true,
		PieceCount = #record.Pieces,
		Refund = refund,
		Cash = player:GetAttribute("Cash"),
	}
end

local function removePiece(player, payload)
	local now = os.clock()
	local last = lastRemovalAt[player] or 0
	if now - last < BuildConfig.RemovalCooldown then
		return { Ok = false, Error = "Remoção rápida demais" }
	end
	lastRemovalAt[player] = now

	if type(payload) ~= "table" then
		return { Ok = false, Error = "Solicitação inválida" }
	end

	return removePieceById(
		player,
		payload.LotId,
		payload.PieceId,
		BuildConfig.RemovalRefundRate
	)
end

local function undoLastPiece(player, payload)
	if type(payload) ~= "table" or type(payload.LotId) ~= "string" then
		return { Ok = false, Error = "Solicitação inválida" }
	end

	local lastPlaced = lastPlacedByPlayer[player]
	if not lastPlaced or lastPlaced.LotId ~= payload.LotId then
		return { Ok = false, Error = "Não há uma colocação recente para desfazer" }
	end

	local response = removePieceById(player, lastPlaced.LotId, lastPlaced.PieceId, 1)
	if response.Ok then
		lastPlacedByPlayer[player] = nil
	end
	return response
end

local function createRemoteFunction(folder, name)
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function setupRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local getState = createRemoteFunction(remotes, "GetBuildState")
	getState.OnServerInvoke = function(player)
		return {
			OwnedLots = getOwnedLots(player),
			GridSize = BuildConfig.GridSize,
			LevelHeight = BuildConfig.LevelHeight,
			MaxLevels = BuildConfig.MaxLevels,
			Cash = player:GetAttribute("Cash") or 0,
		}
	end

	local place = createRemoteFunction(remotes, "PlaceBuildPiece")
	place.OnServerInvoke = placePiece

	local remove = createRemoteFunction(remotes, "RemoveBuildPiece")
	remove.OnServerInvoke = removePiece

	local undo = createRemoteFunction(remotes, "UndoBuildPiece")
	undo.OnServerInvoke = undoLastPiece
end

local function initializeBuildFolders()
	local world = getWorld()
	local lots = world and world:FindFirstChild("Lots")
	if not world or not lots then
		error("[BuildService] World or Lots folder is missing")
	end

	local previous = world:FindFirstChild("Builds")
	if previous then
		previous:Destroy()
	end

	buildsFolder = Instance.new("Folder")
	buildsFolder.Name = "Builds"
	buildsFolder.Parent = world

	for _, lot in ipairs(lots:GetChildren()) do
		if lot:IsA("BasePart") then
			local folder = Instance.new("Folder")
			folder.Name = lot.Name
			folder.Parent = buildsFolder
		end
	end

	for _, lot in ipairs(lots:GetChildren()) do
		if lot:IsA("BasePart") then
			loadLot(lot)
		end
	end
end

function BuildService:Start(dataService)
	if started then
		return
	end
	started = true
	playerDataService = dataService

	initializeBuildFolders()
	setupRemotes()

	Players.PlayerRemoving:Connect(function(player)
		lastPlacementAt[player] = nil
		lastRemovalAt[player] = nil
		lastPlacedByPlayer[player] = nil
	end)

	game:BindToClose(function()
		for lotId, record in pairs(lotBuilds) do
			if record.Dirty then
				saveLot(lotId)
			end
		end
	end)

	print("[Property Empire v2] BuildService v2 started")
end

return BuildService
