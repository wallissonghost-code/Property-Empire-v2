local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Catalog = require(ReplicatedStorage.Shared.ArtifactCatalog)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local MuseumConfig = require(ReplicatedStorage.Shared.MuseumConfig)

local MuseumService = {}

local dataService
local worldService
local remotes
local models = {}
local slotOwners = {}
local playerSlots = {}
local started = false

local function makePart(parent, name, size, cf, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addBillboard(part, text, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 230, 60)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextWrapped = true
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return label
end

local function findArtifact(profile, uid)
	for index, artifact in ipairs(profile.Artifacts) do
		if artifact.Uid == uid then
			return artifact, index
		end
	end
	return nil
end

local function capacity(profile)
	return MuseumConfig.DisplaySlots[profile.Museum.Level] or 4
end

local function occupied(profile)
	local used = {}
	for _, artifact in ipairs(profile.Artifacts) do
		if artifact.Location == "Display" and artifact.Slot then
			used[artifact.Slot] = true
		end
	end
	return used
end

local function artifactDto(artifact)
	local spec = Catalog.Get(artifact.CatalogId)
	if not spec then
		return nil
	end
	return {
		Uid = artifact.Uid,
		CatalogId = artifact.CatalogId,
		Name = spec.Name,
		Rarity = spec.Rarity,
		BaseValue = spec.Value,
		Prestige = spec.Prestige,
		Location = artifact.Location or "Inventory",
		Slot = artifact.Slot,
		ForSale = artifact.ForSale == true,
		Price = math.floor(tonumber(artifact.Price) or spec.Value),
		AcquiredAt = artifact.AcquiredAt or 0,
	}
end

local function assignSlot(player)
	if playerSlots[player] then
		return playerSlots[player]
	end
	for index = 1, #worldService:GetSlots() do
		if not slotOwners[index] then
			slotOwners[index] = player
			playerSlots[player] = index
			return index
		end
	end
	return nil
end

local function ensureRemote(className, name)
	local existing = remotes:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

function MuseumService:GetScore(player)
	local profile = dataService and dataService:Get(player)
	if not profile then
		return 0
	end
	local score = MuseumConfig.LevelScore[profile.Museum.Level] or 0
	for _, artifact in ipairs(profile.Artifacts) do
		if artifact.Location == "Display" then
			local spec = Catalog.Get(artifact.CatalogId)
			if spec then
				score += spec.Prestige
			end
		end
	end
	return score
end

function MuseumService:GetPlotCFrame(player)
	if not worldService then
		return nil
	end
	local slot = assignSlot(player)
	if not slot then
		return nil
	end
	return worldService:GetSlots()[slot]
end

function MuseumService:Render(player)
	local profile = dataService and dataService:Get(player)
	if not profile then
		return
	end
	local base = self:GetPlotCFrame(player)
	if not base then
		return
	end

	if models[player] then
		models[player]:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "Museum_" .. player.UserId
	model.Parent = worldService:GetWorld()
	models[player] = model

	local level = profile.Museum.Level
	local width = 54 + level * 9
	local depth = 42 + level * 7

	makePart(model, "Floor", Vector3.new(width, 1, depth), base * CFrame.new(0, 0.6, 0), Color3.fromRGB(214, 211, 202), Enum.Material.Marble)
	makePart(model, "BackWall", Vector3.new(width, 14, 1), base * CFrame.new(0, 7, -depth / 2), Color3.fromRGB(235, 233, 226))
	makePart(model, "LeftWall", Vector3.new(1, 14, depth), base * CFrame.new(-width / 2, 7, 0), Color3.fromRGB(235, 233, 226))
	makePart(model, "RightWall", Vector3.new(1, 14, depth), base * CFrame.new(width / 2, 7, 0), Color3.fromRGB(235, 233, 226))

	local sign = makePart(model, "MuseumSign", Vector3.new(18, 4, 1), base * CFrame.new(0, 5, depth / 2 - 1), Color3.fromRGB(28, 31, 37), Enum.Material.Metal)
	addBillboard(sign, string.format("%s\nMUSEU · NÍVEL %d · PRESTÍGIO %d", player.DisplayName, level, self:GetScore(player)), 280)

	local terminal = makePart(model, "Terminal", Vector3.new(4, 4, 2), base * CFrame.new(0, 2.5, depth / 2 + 3), Color3.fromRGB(51, 93, 100), Enum.Material.Metal)
	local terminalPrompt = Instance.new("ProximityPrompt")
	terminalPrompt.ActionText = "Gerenciar museu"
	terminalPrompt.ObjectText = player.DisplayName
	terminalPrompt.MaxActivationDistance = 10
	terminalPrompt.HoldDuration = 0.15
	terminalPrompt.Parent = terminal
	terminalPrompt.Triggered:Connect(function(who)
		local openUi = remotes and remotes:FindFirstChild("OpenMuseumUI")
		if openUi then
			openUi:FireClient(who, player.UserId)
		end
	end)

	local cap = capacity(profile)
	local cols = math.ceil(math.sqrt(cap))
	local rows = math.ceil(cap / cols)
	local spacingX = math.min(12, (width - 12) / math.max(1, cols - 1))
	local spacingZ = math.min(11, (depth - 12) / math.max(1, rows))

	for slot = 1, cap do
		local col = (slot - 1) % cols
		local row = math.floor((slot - 1) / cols)
		local x = (col - (cols - 1) / 2) * spacingX
		local z = -depth / 2 + 7 + row * spacingZ
		local stand = makePart(model, "DisplayStand" .. slot, Vector3.new(5, 2, 5), base * CFrame.new(x, 1.5, z), Color3.fromRGB(50, 53, 58), Enum.Material.Metal)

		local displayed
		for _, artifact in ipairs(profile.Artifacts) do
			if artifact.Location == "Display" and artifact.Slot == slot then
				displayed = artifact
				break
			end
		end

		if displayed then
			local spec = Catalog.Get(displayed.CatalogId)
			if spec then
				local item = makePart(model, "Artifact_" .. displayed.Uid, Vector3.new(2.2, 2.2, 2.2), stand.CFrame * CFrame.new(0, 2.1, 0), spec.Color, spec.Material)
				item.Shape = Enum.PartType.Ball
				local saleText = displayed.ForSale and string.format("À VENDA · $%d", displayed.Price or spec.Value) or "BLOQUEADO"
				addBillboard(item, string.format("%s\n%s · PRESTÍGIO %d\n%s", spec.Name, spec.Rarity, spec.Prestige, saleText), 220)

				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = displayed.ForSale and "Ver oferta" or "Ver peça"
				prompt.ObjectText = spec.Name
				prompt.MaxActivationDistance = 9
				prompt.HoldDuration = 0.1
				prompt.Parent = stand
				prompt.Triggered:Connect(function(who)
					local openUi = remotes and remotes:FindFirstChild("OpenMuseumUI")
					if openUi then
						openUi:FireClient(who, player.UserId, displayed.Uid)
					end
				end)
			end
		end
	end
end

function MuseumService:GetState(requester, targetUserId)
	local target = Players:GetPlayerByUserId(tonumber(targetUserId) or requester.UserId)
	if not target then
		return { Ok = false, Error = "O dono deste museu não está neste servidor" }
	end
	local profile = dataService:Get(target)
	if not profile then
		return { Ok = false, Error = "Museu carregando" }
	end

	local isOwner = target == requester
	local items = {}
	for _, artifact in ipairs(profile.Artifacts) do
		if isOwner or artifact.Location == "Display" then
			local dto = artifactDto(artifact)
			if dto then
				table.insert(items, dto)
			end
		end
	end
	table.sort(items, function(a, b)
		if a.Location ~= b.Location then
			return a.Location == "Display"
		end
		return a.BaseValue > b.BaseValue
	end)

	return {
		Ok = true,
		IsOwner = isOwner,
		OwnerUserId = target.UserId,
		OwnerName = target.DisplayName,
		Cash = requester:GetAttribute("Cash") or 0,
		Level = profile.Museum.Level,
		Capacity = capacity(profile),
		Score = self:GetScore(target),
		Artifacts = items,
		Stats = profile.Stats,
		UpgradeCost = MuseumConfig.UpgradeCosts[profile.Museum.Level + 1],
	}
end

function MuseumService:AddArtifact(player, catalogId)
	local profile = dataService:Get(player)
	if not profile or #profile.Artifacts >= GameConfig.MaxArtifacts then
		return false, "Inventário cheio"
	end
	local spec = Catalog.Get(catalogId)
	if not spec then
		return false, "Item inválido"
	end
	table.insert(profile.Artifacts, {
		Uid = HttpService:GenerateGUID(false),
		CatalogId = catalogId,
		Location = "Inventory",
		ForSale = false,
		Price = spec.Value,
		AcquiredAt = os.time(),
	})
	return true
end

function MuseumService:AwardVisit(player, revenue)
	local profile = dataService:Get(player)
	if not profile then
		return
	end
	dataService:AdjustCash(player, revenue)
	profile.Stats.Visits += 1
	profile.Stats.VisitorRevenue += revenue
end

function MuseumService:GetMuseumInfo(player)
	local model = models[player]
	local profile = dataService:Get(player)
	if not model or not profile then
		return nil
	end
	local floor = model:FindFirstChild("Floor")
	if not floor then
		return nil
	end
	return {
		Model = model,
		Score = self:GetScore(player),
		Level = profile.Museum.Level,
		Entrance = floor.CFrame * CFrame.new(0, 2, floor.Size.Z / 2 + 8),
		Inside = floor.CFrame * CFrame.new(0, 2, 0),
		Exit = floor.CFrame * CFrame.new(0, 2, floor.Size.Z / 2 + 14),
	}
end

function MuseumService:GetOwners()
	local result = {}
	for player in pairs(models) do
		if player.Parent then
			table.insert(result, player)
		end
	end
	return result
end

function MuseumService:Action(player, payload)
	if type(payload) ~= "table" then
		return { Ok = false, Error = "Ação inválida" }
	end
	local profile = dataService:Get(player)
	if not profile then
		return { Ok = false, Error = "Dados carregando" }
	end

	local action = payload.Action
	if action == "Place" then
		local artifact = findArtifact(profile, payload.Uid)
		if not artifact or artifact.Location ~= "Inventory" then
			return { Ok = false, Error = "Peça indisponível" }
		end
		local used = occupied(profile)
		local freeSlot
		for slot = 1, capacity(profile) do
			if not used[slot] then
				freeSlot = slot
				break
			end
		end
		if not freeSlot then
			return { Ok = false, Error = "Museu sem vitrines livres" }
		end
		artifact.Location = "Display"
		artifact.Slot = freeSlot
		artifact.ForSale = false
		self:Render(player)
	elseif action == "Store" then
		local artifact = findArtifact(profile, payload.Uid)
		if not artifact or artifact.Location ~= "Display" then
			return { Ok = false, Error = "Peça indisponível" }
		end
		artifact.Location = "Inventory"
		artifact.Slot = nil
		artifact.ForSale = false
		self:Render(player)
	elseif action == "ToggleSale" then
		local artifact = findArtifact(profile, payload.Uid)
		if not artifact or artifact.Location ~= "Display" then
			return { Ok = false, Error = "A peça precisa estar exposta" }
		end
		artifact.ForSale = not artifact.ForSale
		self:Render(player)
	elseif action == "SetPrice" then
		local artifact = findArtifact(profile, payload.Uid)
		if not artifact or artifact.Location ~= "Display" then
			return { Ok = false, Error = "Peça indisponível" }
		end
		artifact.Price = math.clamp(math.floor(tonumber(payload.Price) or artifact.Price or 1), GameConfig.SalePriceMin, GameConfig.SalePriceMax)
		self:Render(player)
	elseif action == "Upgrade" then
		if profile.Museum.Level >= MuseumConfig.MaxLevel then
			return { Ok = false, Error = "Museu já está no nível máximo" }
		end
		local cost = MuseumConfig.UpgradeCosts[profile.Museum.Level + 1] or 0
		if not dataService:AdjustCash(player, -cost) then
			return { Ok = false, Error = "Dinheiro insuficiente" }
		end
		profile.Museum.Level += 1
		self:Render(player)
	elseif action == "Buy" then
		local seller = Players:GetPlayerByUserId(tonumber(payload.SellerUserId) or 0)
		if not seller or seller == player then
			return { Ok = false, Error = "Venda inválida" }
		end
		local sellerProfile = dataService:Get(seller)
		if not sellerProfile then
			return { Ok = false, Error = "Vendedor indisponível" }
		end
		local item, index = findArtifact(sellerProfile, payload.Uid)
		if not item or item.Location ~= "Display" or not item.ForSale then
			return { Ok = false, Error = "Esta peça não está à venda" }
		end
		if #profile.Artifacts >= GameConfig.MaxArtifacts then
			return { Ok = false, Error = "Seu inventário está cheio" }
		end
		local price = math.clamp(math.floor(tonumber(item.Price) or 1), GameConfig.SalePriceMin, GameConfig.SalePriceMax)
		if not dataService:AdjustCash(player, -price) then
			return { Ok = false, Error = "Dinheiro insuficiente" }
		end
		dataService:AdjustCash(seller, price)
		table.remove(sellerProfile.Artifacts, index)
		item.Location = "Inventory"
		item.Slot = nil
		item.ForSale = false
		local itemSpec = Catalog.Get(item.CatalogId)
		if itemSpec then
			item.Price = itemSpec.Value
		end
		table.insert(profile.Artifacts, item)
		profile.Stats.Purchases += 1
		sellerProfile.Stats.Sales += 1
		self:Render(seller)
		dataService:Save(seller)
		dataService:Save(player)
		local toast = remotes and remotes:FindFirstChild("MuseumToast")
		if toast then
			toast:FireClient(seller, string.format("%s comprou uma peça por $%d", player.DisplayName, price))
		end
		return { Ok = true, Message = "Peça comprada e enviada ao seu inventário" }
	else
		return { Ok = false, Error = "Ação desconhecida" }
	end

	dataService:Save(player)
	return { Ok = true, Message = "Museu atualizado" }
end

function MuseumService:Start(ds, ws)
	if started then
		return
	end
	started = true
	dataService = ds
	worldService = ws

	remotes = ReplicatedStorage:FindFirstChild("MuseumRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "MuseumRemotes"
		remotes.Parent = ReplicatedStorage
	end

	local openUi = ensureRemote("RemoteEvent", "OpenMuseumUI")
	local toast = ensureRemote("RemoteEvent", "MuseumToast")
	local getState = ensureRemote("RemoteFunction", "GetMuseumState")
	local action = ensureRemote("RemoteFunction", "MuseumAction")
	assert(openUi and toast, "Museum remotes failed to initialize")

	getState.OnServerInvoke = function(player, target)
		return self:GetState(player, target)
	end
	action.OnServerInvoke = function(player, payload)
		return self:Action(player, payload)
	end

	local function setup(player)
		task.spawn(function()
			if ds:Wait(player, 15) then
				self:Render(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		if models[player] then
			models[player]:Destroy()
			models[player] = nil
		end
		local slot = playerSlots[player]
		if slot then
			slotOwners[slot] = nil
			playerSlots[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end

	print("[Museum Empire] MuseumService started — runtime remotes healthy")
end

return MuseumService
