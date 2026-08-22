local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildCatalog = require(ReplicatedStorage.Shared.BuildCatalog)

local BuildService = {}
local dataService
local worldService
local museumService
local started = false
local roots = {}
local actionLocks = {}

local function snap(value)
	local grid = BuildCatalog.GridSize
	return math.floor((tonumber(value) or 0) / grid + 0.5) * grid
end

local function normalizeRotation(value)
	local rotation = math.floor(tonumber(value) or 0)
	rotation = math.floor((rotation + 45) / 90) * 90
	rotation %= 360
	if rotation < 0 then
		rotation += 360
	end
	return rotation
end

local function rotatedFootprint(size, rotation)
	if rotation == 90 or rotation == 270 then
		return Vector3.new(size.Z, size.Y, size.X)
	end
	return size
end

local function descriptor(item, piece)
	local rotation = normalizeRotation(piece.Rotation)
	local size = rotatedFootprint(item.Size, rotation)
	local floor = math.max(1, math.floor(tonumber(piece.Floor) or 1))
	local y = (floor - 1) * BuildCatalog.FloorHeight + item.YOffset
	return {
		Id = piece.Id,
		Layer = item.Layer,
		ItemId = item.Id,
		X = snap(piece.X),
		Y = y,
		Z = snap(piece.Z),
		HalfX = size.X * 0.5,
		HalfY = size.Y * 0.5,
		HalfZ = size.Z * 0.5,
	}
end

local function overlaps(a, b)
	local epsilon = 0.04
	return math.abs(a.X - b.X) < (a.HalfX + b.HalfX - epsilon)
		and math.abs(a.Y - b.Y) < (a.HalfY + b.HalfY - epsilon)
		and math.abs(a.Z - b.Z) < (a.HalfZ + b.HalfZ - epsilon)
end

local function conflicts(a, b)
	if not overlaps(a, b) then
		return false
	end
	-- Floors, ceilings and landscaping are support surfaces. Structural and
	-- fixture pieces are intentionally allowed to occupy their vertical span.
	if a.Layer == "Surface" and b.Layer ~= "Surface" then
		return false
	end
	if b.Layer == "Surface" and a.Layer ~= "Surface" then
		return false
	end
	return true
end

local function insidePlot(desc)
	return math.abs(desc.X) + desc.HalfX <= BuildCatalog.PlotHalfWidth
		and math.abs(desc.Z) + desc.HalfZ <= BuildCatalog.PlotHalfDepth
end

local function profilePieces(profile)
	profile.Museum.BuildPieces = profile.Museum.BuildPieces or {}
	return profile.Museum.BuildPieces
end

local function findPiece(profile, id)
	for index, piece in ipairs(profilePieces(profile)) do
		if piece.Id == id then
			return piece, index
		end
	end
	return nil
end

local function makePart(parent, name, size, cframe, item, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = item.Material
	part.Color = item.Color
	part.Transparency = transparency == nil and (item.Transparency or 0) or transparency
	part.Parent = parent
	return part
end

local function renderDoorway(parent, cf, item)
	makePart(parent, "DoorLeft", Vector3.new(2, 8, 1), cf * CFrame.new(-3, 0, 0), item)
	makePart(parent, "DoorRight", Vector3.new(2, 8, 1), cf * CFrame.new(3, 0, 0), item)
	makePart(parent, "DoorTop", Vector3.new(4, 2, 1), cf * CFrame.new(0, 3, 0), item)
end

local function renderWindow(parent, cf, item)
	makePart(parent, "WindowLeft", Vector3.new(1.2, 8, 1), cf * CFrame.new(-3.4, 0, 0), item)
	makePart(parent, "WindowRight", Vector3.new(1.2, 8, 1), cf * CFrame.new(3.4, 0, 0), item)
	makePart(parent, "WindowTop", Vector3.new(5.6, 1.2, 1), cf * CFrame.new(0, 3.4, 0), item)
	makePart(parent, "WindowBottom", Vector3.new(5.6, 1.2, 1), cf * CFrame.new(0, -3.4, 0), item)
	local glassItem = {
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(157, 211, 229),
		Transparency = 0.42,
	}
	local glass = makePart(parent, "Glass", Vector3.new(5.6, 5.6, 0.35), cf, glassItem)
	glass.CanCollide = false
end

local function renderStair(parent, cf, item)
	local steps = 8
	local depth = item.Size.Z / steps
	for i = 1, steps do
		local height = i
		local z = -item.Size.Z * 0.5 + depth * (i - 0.5)
		local y = -item.Size.Y * 0.5 + height * 0.5
		makePart(parent, "Step" .. i, Vector3.new(item.Size.X, height, depth), cf * CFrame.new(0, y, z), item)
	end
end

local function renderPiece(parent, base, piece)
	local item = BuildCatalog.Get(piece.ItemId)
	if not item then
		return
	end
	local floor = math.max(1, math.floor(tonumber(piece.Floor) or 1))
	local rotation = normalizeRotation(piece.Rotation)
	local cf = base
		* CFrame.new(snap(piece.X), (floor - 1) * BuildCatalog.FloorHeight + item.YOffset, snap(piece.Z))
		* CFrame.Angles(0, math.rad(rotation), 0)

	local model = Instance.new("Model")
	model.Name = "BuildPiece_" .. tostring(piece.Id)
	model:SetAttribute("BuildPieceId", piece.Id)
	model:SetAttribute("ItemId", piece.ItemId)
	model:SetAttribute("Price", item.Price)
	model.Parent = parent

	if item.Composite == "Doorway" then
		renderDoorway(model, cf, item)
	elseif item.Composite == "Window" then
		renderWindow(model, cf, item)
	elseif item.Composite == "Stair" then
		renderStair(model, cf, item)
	else
		local part = makePart(model, item.Name, item.Size, cf, item)
		if item.Id == "Spotlight" then
			local light = Instance.new("SpotLight")
			light.Angle = 75
			light.Brightness = 4
			light.Range = 18
			light.Face = Enum.NormalId.Bottom
			light.Parent = part
		elseif item.Id == "InteriorLamp" then
			local light = Instance.new("PointLight")
			light.Brightness = 2.5
			light.Range = 16
			light.Parent = part
		end
	end
end

function BuildService:Render(player)
	local profile = dataService:Get(player)
	if not profile then
		return
	end
	local base = museumService:GetPlotCFrame(player)
	if not base then
		return
	end
	if roots[player] then
		roots[player]:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "CustomBuild_" .. player.UserId
	root.Parent = worldService:GetWorld()
	roots[player] = root
	for _, piece in ipairs(profilePieces(profile)) do
		renderPiece(root, base, piece)
	end
end

function BuildService:GetState(player)
	local profile = dataService:Get(player)
	if not profile then
		return { Ok = false, Error = "Dados carregando" }
	end
	local pieces = {}
	for _, piece in ipairs(profilePieces(profile)) do
		table.insert(pieces, {
			Id = piece.Id,
			ItemId = piece.ItemId,
			X = piece.X,
			Z = piece.Z,
			Floor = piece.Floor,
			Rotation = piece.Rotation,
		})
	end
	return {
		Ok = true,
		Cash = player:GetAttribute("Cash") or 0,
		MuseumLevel = profile.Museum.Level,
		Prestige = museumService:GetScore(player),
		PieceCount = #pieces,
		MaxPieces = BuildCatalog.MaxPieces,
		Pieces = pieces,
	}
end

local function validatePlacement(player, profile, payload)
	local item = BuildCatalog.Get(payload.ItemId)
	if not item then
		return nil, "Item de construção inválido"
	end
	local floor = math.floor(tonumber(payload.Floor) or 1)
	if floor < 1 or floor > profile.Museum.Level then
		return nil, "Este andar ainda não está liberado"
	end
	local prestige = museumService:GetScore(player)
	if profile.Museum.Level < item.MinLevel then
		return nil, string.format("Requer museu nível %d", item.MinLevel)
	end
	if prestige < item.MinPrestige then
		return nil, string.format("Requer prestígio %d", item.MinPrestige)
	end
	if #profilePieces(profile) >= BuildCatalog.MaxPieces then
		return nil, "Limite de peças atingido"
	end

	local piece = {
		Id = HttpService:GenerateGUID(false),
		ItemId = item.Id,
		X = snap(payload.X),
		Z = snap(payload.Z),
		Floor = floor,
		Rotation = normalizeRotation(payload.Rotation),
		CreatedAt = os.time(),
	}
	local desc = descriptor(item, piece)
	if not insidePlot(desc) then
		return nil, "A peça precisa ficar dentro do seu terreno"
	end
	for _, existing in ipairs(profilePieces(profile)) do
		local existingItem = BuildCatalog.Get(existing.ItemId)
		if existingItem and conflicts(desc, descriptor(existingItem, existing)) then
			return nil, "Já existe uma construção ocupando este espaço"
		end
	end
	return piece, nil, item
end

function BuildService:Action(player, payload)
	if type(payload) ~= "table" then
		return { Ok = false, Error = "Ação inválida" }
	end
	if actionLocks[player] then
		return { Ok = false, Error = "Aguarde a construção anterior terminar" }
	end
	actionLocks[player] = true
	local function finish(result)
		actionLocks[player] = nil
		return result
	end

	local profile = dataService:Get(player)
	if not profile then
		return finish({ Ok = false, Error = "Dados carregando" })
	end

	if payload.Action == "Place" then
		local piece, errorMessage, item = validatePlacement(player, profile, payload)
		if not piece then
			return finish({ Ok = false, Error = errorMessage })
		end
		local cashBefore = profile.Cash
		if not dataService:AdjustCash(player, -item.Price) then
			return finish({ Ok = false, Error = "Dinheiro insuficiente" })
		end
		table.insert(profilePieces(profile), piece)
		if not dataService:Save(player) then
			table.remove(profilePieces(profile), #profilePieces(profile))
			local refund = cashBefore - profile.Cash
			if refund > 0 then
				dataService:AdjustCash(player, refund)
			end
			return finish({ Ok = false, Error = "Falha ao salvar; compra revertida" })
		end
		self:Render(player)
		return finish({
			Ok = true,
			Message = string.format("%s comprado e construído por $%d", item.Name, item.Price),
			PieceId = piece.Id,
		})
	elseif payload.Action == "Remove" then
		local piece, index = findPiece(profile, payload.PieceId)
		if not piece or not index then
			return finish({ Ok = false, Error = "Peça não encontrada" })
		end
		local item = BuildCatalog.Get(piece.ItemId)
		if not item then
			return finish({ Ok = false, Error = "Peça inválida" })
		end
		local refund = math.floor(item.Price * BuildCatalog.RefundRate)
		table.remove(profilePieces(profile), index)
		dataService:AdjustCash(player, refund)
		if not dataService:Save(player) then
			dataService:AdjustCash(player, -refund)
			table.insert(profilePieces(profile), index, piece)
			return finish({ Ok = false, Error = "Falha ao salvar; remoção revertida" })
		end
		self:Render(player)
		return finish({ Ok = true, Message = string.format("Peça removida · reembolso $%d", refund) })
	end

	return finish({ Ok = false, Error = "Ação desconhecida" })
end

function BuildService:Start(ds, ws, ms)
	if started then
		return
	end
	started = true
	dataService = ds
	worldService = ws
	museumService = ms

	local remotes = ReplicatedStorage:FindFirstChild("MuseumBuildRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "MuseumBuildRemotes"
		remotes.Parent = ReplicatedStorage
	end
	local getState = remotes:FindFirstChild("GetBuildState") or Instance.new("RemoteFunction")
	getState.Name = "GetBuildState"
	getState.Parent = remotes
	getState.OnServerInvoke = function(player)
		return self:GetState(player)
	end
	local action = remotes:FindFirstChild("BuildAction") or Instance.new("RemoteFunction")
	action.Name = "BuildAction"
	action.Parent = remotes
	action.OnServerInvoke = function(player, payload)
		return self:Action(player, payload)
	end

	local function setup(player)
		task.spawn(function()
			if ds:Wait(player, 15) then
				task.wait(0.4)
				self:Render(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		actionLocks[player] = nil
		if roots[player] then
			roots[player]:Destroy()
			roots[player] = nil
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end

	print("[Museum Empire] BuildService started — paid modular construction v1")
end

return BuildService
