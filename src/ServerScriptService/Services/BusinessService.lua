local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessConfig = require(Shared.BusinessConfig)
local BuildConfig = require(Shared.BuildConfig)

local BusinessService = {}
local businessStore = DataStoreService:GetDataStore(BusinessConfig.DataStoreName)
local playerDataService = nil
local started = false
local lotLocks = {}
local businessRecords = {}
local businessSignsFolder = nil

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

local function businessKey(lotId)
	return "business_" .. lotId
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

local function makeAvailableRecord(lotId)
	return {
		Version = BusinessConfig.DataVersion,
		LotId = lotId,
		Status = "Available",
		OwnerUserId = 0,
		BusinessType = "",
		ReservedBy = 0,
		ReservationExpiresAt = 0,
	}
end

local function normalizeRecord(lotId, record)
	if type(record) ~= "table" then
		return makeAvailableRecord(lotId)
	end

	record.Version = BusinessConfig.DataVersion
	record.LotId = lotId
	record.OwnerUserId = math.max(0, math.floor(tonumber(record.OwnerUserId) or 0))
	record.BusinessType = type(record.BusinessType) == "string" and record.BusinessType or ""
	record.ReservedBy = math.max(0, math.floor(tonumber(record.ReservedBy) or 0))
	record.ReservationExpiresAt = math.max(0, math.floor(tonumber(record.ReservationExpiresAt) or 0))
	record.Reputation = math.max(0, math.floor(tonumber(record.Reputation) or BusinessConfig.InitialReputation))

	if record.OwnerUserId > 0 and BusinessConfig.Types[record.BusinessType] then
		record.Status = "Active"
	elseif record.Status == "Pending" and record.ReservationExpiresAt > os.time() and BusinessConfig.Types[record.BusinessType] then
		record.Status = "Pending"
	else
		return makeAvailableRecord(lotId)
	end

	return record
end

local function playerOwnsLot(player, lotId)
	local data = playerDataService and playerDataService:Get(player)
	if not data or type(data.OwnedLots) ~= "table" or table.find(data.OwnedLots, lotId) == nil then
		return false
	end

	local lot = getLot(lotId)
	return lot ~= nil and lot:GetAttribute("OwnerUserId") == player.UserId
end

local function getBuildStatus(lotId)
	local world = getWorld()
	local builds = world and world:FindFirstChild("Builds")
	local lotFolder = builds and builds:FindFirstChild(lotId)

	local pieces = 0
	local floors = 0
	local walls = 0

	if lotFolder then
		for _, root in ipairs(lotFolder:GetChildren()) do
			local pieceType = root:GetAttribute("PieceType")
			local spec = type(pieceType) == "string" and BuildConfig.Catalog[pieceType] or nil
			if spec then
				pieces += 1
				if spec.Slot == "Floor" then
					floors += 1
				elseif spec.Slot == "Wall" then
					walls += 1
				end
			end
		end
	end

	local ready = pieces >= BusinessConfig.MinimumBuildPieces
		and floors >= BusinessConfig.MinimumFloorPieces
		and walls >= BusinessConfig.MinimumWallPieces

	return {
		Ready = ready,
		Pieces = pieces,
		Floors = floors,
		Walls = walls,
		MinimumPieces = BusinessConfig.MinimumBuildPieces,
		MinimumFloors = BusinessConfig.MinimumFloorPieces,
		MinimumWalls = BusinessConfig.MinimumWallPieces,
	}
end

local function reserveLicense(lotId, userId, businessType)
	local now = os.time()
	local success, result = pcall(function()
		return businessStore:UpdateAsync(businessKey(lotId), function(current)
			current = normalizeRecord(lotId, current)

			if current.Status == "Active" then
				return current
			end

			if current.Status == "Pending" and current.ReservationExpiresAt > now and current.ReservedBy ~= userId then
				return current
			end

			current.Status = "Pending"
			current.OwnerUserId = 0
			current.BusinessType = businessType
			current.ReservedBy = userId
			current.ReservationExpiresAt = now + BusinessConfig.ReservationSeconds
			return current
		end)
	end)

	if not success then
		return false, nil
	end

	result = normalizeRecord(lotId, result)
	return result.Status == "Pending" and result.ReservedBy == userId and result.BusinessType == businessType, result
end

local function releaseReservation(lotId, userId)
	pcall(function()
		businessStore:UpdateAsync(businessKey(lotId), function(current)
			current = normalizeRecord(lotId, current)
			if current.Status == "Pending" and current.ReservedBy == userId then
				return makeAvailableRecord(lotId)
			end
			return current
		end)
	end)
end

local function finalizeLicense(lotId, userId, businessType)
	local success, result = pcall(function()
		return businessStore:UpdateAsync(businessKey(lotId), function(current)
			current = normalizeRecord(lotId, current)
			if current.Status == "Pending"
				and current.ReservedBy == userId
				and current.BusinessType == businessType
			then
				current.Status = "Active"
				current.OwnerUserId = userId
				current.ReservedBy = 0
				current.ReservationExpiresAt = 0
				current.LicenseIssuedAt = os.time()
				current.Reputation = BusinessConfig.InitialReputation
			end
			return current
		end)
	end)

	if not success then
		return false, nil
	end

	result = normalizeRecord(lotId, result)
	local finalized = result.Status == "Active"
		and result.OwnerUserId == userId
		and result.BusinessType == businessType
	return finalized, result
end

local function makeSurfaceLabel(sign, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.AlwaysOnTop = false
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(29, 35, 43)
	label.BackgroundTransparency = 0.08
	label.TextColor3 = Color3.fromRGB(244, 246, 248)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = label
end

local function removeBusinessSign(lotId)
	if not businessSignsFolder then
		return
	end
	local existing = businessSignsFolder:FindFirstChild(lotId)
	if existing then
		existing:Destroy()
	end
end

local function applyBusinessToLot(lotId, record)
	local lot = getLot(lotId)
	if not lot then
		return
	end

	removeBusinessSign(lotId)
	lot:SetAttribute("BusinessType", "")
	lot:SetAttribute("BusinessOwnerUserId", 0)

	if not record or record.Status ~= "Active" then
		return
	end

	local spec = BusinessConfig.Types[record.BusinessType]
	if not spec then
		return
	end

	lot:SetAttribute("BusinessType", record.BusinessType)
	lot:SetAttribute("BusinessOwnerUserId", record.OwnerUserId)

	local sign = Instance.new("Part")
	sign.Name = lotId
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.CanQuery = false
	sign.Size = Vector3.new(10, 4, 0.45)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(42, 50, 61)
	sign.CFrame = lot.CFrame
		* CFrame.new(lot.Size.X / 2 - 7, lot.Size.Y / 2 + 2.15, lot.Size.Z / 2 - 2)
	sign.Parent = businessSignsFolder

	local text = string.format("%s\nLICENCIADA", string.upper(spec.DisplayName))
	makeSurfaceLabel(sign, Enum.NormalId.Front, text)
	makeSurfaceLabel(sign, Enum.NormalId.Back, text)
end

local function loadBusinessRecord(lotId)
	local success, stored = pcall(function()
		return businessStore:GetAsync(businessKey(lotId))
	end)
	if not success then
		warn(string.format("[BusinessService] Failed to load business for %s", lotId))
		return makeAvailableRecord(lotId)
	end
	return normalizeRecord(lotId, stored)
end

local function loadPersistentBusinesses()
	local world = getWorld()
	local lots = world and world:FindFirstChild("Lots")
	if not lots then
		return
	end

	for _, lot in ipairs(lots:GetChildren()) do
		if lot:IsA("BasePart") then
			local record = loadBusinessRecord(lot.Name)
			businessRecords[lot.Name] = record
			applyBusinessToLot(lot.Name, record)
		end
	end
end

local function createWorldPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createCityHall(openRemote)
	local world = getWorld()
	local spawn = world and world:FindFirstChild("MainSpawn")
	if not world or not spawn or not spawn:IsA("BasePart") then
		warn("[BusinessService] World or MainSpawn missing; City Hall was not created")
		return
	end

	local previous = world:FindFirstChild("CityHall")
	if previous then
		previous:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "CityHall"
	model.Parent = world

	local origin = CFrame.new(spawn.Position + Vector3.new(58, 0, 0))
	local stone = Color3.fromRGB(215, 211, 198)
	local trim = Color3.fromRGB(69, 91, 116)
	local dark = Color3.fromRGB(47, 55, 66)

	createWorldPart(model, "Floor", Vector3.new(64, 1, 36), origin * CFrame.new(0, 0, 0), stone, Enum.Material.Concrete)
	createWorldPart(model, "NorthWall", Vector3.new(64, 11, 1), origin * CFrame.new(0, 5.5, -17.5), stone, Enum.Material.Concrete)
	createWorldPart(model, "SouthWall", Vector3.new(64, 11, 1), origin * CFrame.new(0, 5.5, 17.5), stone, Enum.Material.Concrete)
	createWorldPart(model, "EastWall", Vector3.new(1, 11, 36), origin * CFrame.new(31.5, 5.5, 0), stone, Enum.Material.Concrete)
	createWorldPart(model, "WestWallNorth", Vector3.new(1, 11, 12), origin * CFrame.new(-31.5, 5.5, -12), stone, Enum.Material.Concrete)
	createWorldPart(model, "WestWallSouth", Vector3.new(1, 11, 12), origin * CFrame.new(-31.5, 5.5, 12), stone, Enum.Material.Concrete)
	createWorldPart(model, "WestLintel", Vector3.new(1, 3, 12), origin * CFrame.new(-31.5, 9.5, 0), trim, Enum.Material.Concrete)
	createWorldPart(model, "Roof", Vector3.new(68, 1, 40), origin * CFrame.new(0, 11.5, 0), trim, Enum.Material.Slate)
	createWorldPart(model, "Steps", Vector3.new(8, 1, 12), origin * CFrame.new(-35, 0, 0), stone, Enum.Material.Concrete)
	createWorldPart(model, "ColumnNorth", Vector3.new(2, 10, 2), origin * CFrame.new(-33, 5, -7), trim, Enum.Material.Marble)
	createWorldPart(model, "ColumnSouth", Vector3.new(2, 10, 2), origin * CFrame.new(-33, 5, 7), trim, Enum.Material.Marble)

	local desk = createWorldPart(model, "LicensingDesk", Vector3.new(9, 3.5, 5), origin * CFrame.new(-21, 1.75, 0), dark, Enum.Material.WoodPlanks)
	local attachment = Instance.new("Attachment")
	attachment.Name = "LicensePromptAttachment"
	attachment.Position = Vector3.new(0, 2.7, 0)
	attachment.Parent = desk

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Solicitar licença"
	prompt.ObjectText = "Prefeitura"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment
	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player)
	end)

	local signPart = createWorldPart(model, "CityHallSign", Vector3.new(0.5, 5, 18), origin * CFrame.new(-32.05, 7.5, 0), trim, Enum.Material.SmoothPlastic)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Left
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 45
	signGui.Parent = signPart

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "PREFEITURA\nLICENÇAS EMPRESARIAIS"
	signLabel.TextColor3 = Color3.fromRGB(245, 246, 248)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui
end

local function getBusinessState(player)
	local data = playerDataService:Get(player)
	if not data then
		return { Ok = false, Error = "Seus dados ainda não estão disponíveis" }
	end

	local lots = {}
	for _, lotId in ipairs(data.OwnedLots) do
		local record = businessRecords[lotId]
		local activeBusiness = nil
		if record and record.Status == "Active" and record.OwnerUserId == player.UserId then
			activeBusiness = {
				BusinessType = record.BusinessType,
				Reputation = record.Reputation,
				LicenseIssuedAt = record.LicenseIssuedAt,
			}
		end

		table.insert(lots, {
			LotId = lotId,
			Build = getBuildStatus(lotId),
			Business = activeBusiness,
		})
	end

	return {
		Ok = true,
		Cash = data.Cash,
		LicenseFee = BusinessConfig.LicenseFee,
		Lots = lots,
	}
end

local function licenseBusiness(player, payload)
	if type(payload) ~= "table" then
		return { Ok = false, Error = "Solicitação inválida" }
	end

	local lotId = payload.LotId
	local businessType = payload.BusinessType
	if type(lotId) ~= "string" or #lotId > 32 or type(businessType) ~= "string" then
		return { Ok = false, Error = "Dados da licença inválidos" }
	end

	local businessSpec = BusinessConfig.Types[businessType]
	if not businessSpec then
		return { Ok = false, Error = "Tipo de empresa inválido" }
	end

	if lotLocks[lotId] then
		return { Ok = false, Error = "Este lote já tem uma solicitação em processamento" }
	end
	lotLocks[lotId] = true

	local function finish(response)
		lotLocks[lotId] = nil
		return response
	end

	if not playerOwnsLot(player, lotId) then
		return finish({ Ok = false, Error = "Você não é proprietário deste lote" })
	end

	local current = businessRecords[lotId]
	if current and current.Status == "Active" then
		return finish({ Ok = false, Error = "Este lote já possui uma empresa licenciada" })
	end

	local buildStatus = getBuildStatus(lotId)
	if not buildStatus.Ready then
		return finish({
			Ok = false,
			Error = string.format(
				"Construa mais antes de licenciar: %d/%d peças, %d/%d pisos e %d/%d paredes",
				buildStatus.Pieces,
				buildStatus.MinimumPieces,
				buildStatus.Floors,
				buildStatus.MinimumFloors,
				buildStatus.Walls,
				buildStatus.MinimumWalls
			),
		})
	end

	local data = playerDataService:Get(player)
	if not data then
		return finish({ Ok = false, Error = "Seus dados ainda não estão disponíveis" })
	end
	if data.Cash < BusinessConfig.LicenseFee then
		return finish({ Ok = false, Error = string.format("Você precisa de $%d para a licença", BusinessConfig.LicenseFee) })
	end

	local reserved, reservationRecord = reserveLicense(lotId, player.UserId, businessType)
	if not reserved then
		if reservationRecord and reservationRecord.Status == "Active" then
			businessRecords[lotId] = reservationRecord
			applyBusinessToLot(lotId, reservationRecord)
		end
		return finish({ Ok = false, Error = "Este lote não está disponível para uma nova licença" })
	end

	local charged = playerDataService:AdjustCash(player, -BusinessConfig.LicenseFee)
	if not charged then
		releaseReservation(lotId, player.UserId)
		return finish({ Ok = false, Error = "Saldo insuficiente" })
	end

	local playerRecord = {
		LotId = lotId,
		BusinessType = businessType,
		Status = "Active",
		Reputation = BusinessConfig.InitialReputation,
		LicenseIssuedAt = os.time(),
	}

	local attached = playerDataService:SetBusiness(player, lotId, playerRecord)
	local saved = attached and playerDataService:Save(player)
	if not saved then
		if attached then
			playerDataService:RemoveBusiness(player, lotId)
		end
		playerDataService:AdjustCash(player, BusinessConfig.LicenseFee)
		playerDataService:Save(player)
		releaseReservation(lotId, player.UserId)
		return finish({ Ok = false, Error = "Não foi possível salvar a licença; o valor foi devolvido" })
	end

	local finalized, finalRecord = finalizeLicense(lotId, player.UserId, businessType)
	if not finalized then
		playerDataService:RemoveBusiness(player, lotId)
		playerDataService:AdjustCash(player, BusinessConfig.LicenseFee)
		playerDataService:Save(player)
		releaseReservation(lotId, player.UserId)
		return finish({ Ok = false, Error = "A Prefeitura não conseguiu concluir a licença; o valor foi devolvido" })
	end

	businessRecords[lotId] = finalRecord
	applyBusinessToLot(lotId, finalRecord)
	player:SetAttribute("LastLicensedBusinessLot", lotId)

	return finish({
		Ok = true,
		LotId = lotId,
		BusinessType = businessType,
		DisplayName = businessSpec.DisplayName,
		LicenseFee = BusinessConfig.LicenseFee,
		Reputation = finalRecord.Reputation,
		Cash = playerDataService:Get(player).Cash,
	})
end

local function ensureRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local openRemote = remotes:FindFirstChild("OpenCityHall")
	if not openRemote then
		openRemote = Instance.new("RemoteEvent")
		openRemote.Name = "OpenCityHall"
		openRemote.Parent = remotes
	end

	local getState = remotes:FindFirstChild("GetBusinessState")
	if not getState then
		getState = Instance.new("RemoteFunction")
		getState.Name = "GetBusinessState"
		getState.Parent = remotes
	end

	local licenseRemote = remotes:FindFirstChild("LicenseBusiness")
	if not licenseRemote then
		licenseRemote = Instance.new("RemoteFunction")
		licenseRemote.Name = "LicenseBusiness"
		licenseRemote.Parent = remotes
	end

	getState.OnServerInvoke = getBusinessState
	licenseRemote.OnServerInvoke = licenseBusiness
	return openRemote
end

function BusinessService:Start(dataService)
	if started then
		return
	end
	started = true
	playerDataService = dataService

	local world = getWorld()
	if not world then
		warn("[BusinessService] PropertyEmpireV2World is missing")
		return
	end

	businessSignsFolder = world:FindFirstChild("BusinessSigns")
	if not businessSignsFolder then
		businessSignsFolder = Instance.new("Folder")
		businessSignsFolder.Name = "BusinessSigns"
		businessSignsFolder.Parent = world
	end

	local openRemote = ensureRemotes()
	createCityHall(openRemote)
	loadPersistentBusinesses()
	print("[Property Empire v2] BusinessService started with City Hall licensing")
end

return BusinessService
