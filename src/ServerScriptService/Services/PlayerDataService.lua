local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local PlayerDataTemplate = require(Shared.PlayerDataTemplate)

local PlayerDataService = {}
local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local profiles = {}
local started = false

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

local function reconcile(target, template)
	for key, defaultValue in pairs(template) do
		if target[key] == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(target[key]) == "table" then
			reconcile(target[key], defaultValue)
		end
	end
end

local function dataKey(player)
	return "player_" .. tostring(player.UserId)
end

local function syncPublicAttributes(player, data)
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("OwnedLotCount", #data.OwnedLots)
end

function PlayerDataService:Get(player)
	return profiles[player]
end

function PlayerDataService:Load(player)
	local success, stored = pcall(function()
		return store:GetAsync(dataKey(player))
	end)

	if not success then
		warn(string.format("[PlayerDataService] Failed to load data for %s", player.Name))
		return nil
	end

	local data = type(stored) == "table" and stored or deepCopy(PlayerDataTemplate)
	reconcile(data, PlayerDataTemplate)
	data.SchemaVersion = GameConfig.SchemaVersion
	data.Meta.CreatedAt = data.Meta.CreatedAt ~= 0 and data.Meta.CreatedAt or os.time()
	data.Meta.LastSeenAt = os.time()
	profiles[player] = data
	syncPublicAttributes(player, data)
	return data
end

function PlayerDataService:Save(player)
	local data = profiles[player]
	if not data then
		return true
	end

	data.Meta.LastSeenAt = os.time()
	local snapshot = deepCopy(data)
	local success, errorMessage = pcall(function()
		store:SetAsync(dataKey(player), snapshot)
	end)

	if not success then
		warn(string.format("[PlayerDataService] Failed to save %s: %s", player.Name, tostring(errorMessage)))
	end

	return success
end

function PlayerDataService:AdjustCash(player, delta)
	local data = profiles[player]
	if not data or type(delta) ~= "number" or delta ~= delta then
		return false, nil
	end

	local nextCash = data.Cash + delta
	if nextCash < 0 then
		return false, data.Cash
	end

	data.Cash = math.floor(nextCash)
	player:SetAttribute("Cash", data.Cash)
	return true, data.Cash
end

function PlayerDataService:AddOwnedLot(player, lotId)
	local data = profiles[player]
	if not data or type(lotId) ~= "string" then
		return false
	end

	if table.find(data.OwnedLots, lotId) then
		return true
	end

	table.insert(data.OwnedLots, lotId)
	player:SetAttribute("OwnedLotCount", #data.OwnedLots)
	return true
end

function PlayerDataService:RemoveOwnedLot(player, lotId)
	local data = profiles[player]
	if not data then
		return false
	end

	local index = table.find(data.OwnedLots, lotId)
	if not index then
		return false
	end

	table.remove(data.OwnedLots, index)
	player:SetAttribute("OwnedLotCount", #data.OwnedLots)
	return true
end

local function loadPlayer(player)
	player:SetAttribute("DataLoaded", false)
	if not PlayerDataService:Load(player) then
		player:Kick("Falha ao carregar seus dados. Tente novamente.")
	end
end

function PlayerDataService:Start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		profiles[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	task.spawn(function()
		while started do
			task.wait(GameConfig.AutoSaveInterval)
			for _, player in Players:GetPlayers() do
				self:Save(player)
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			self:Save(player)
		end
	end)
end

return PlayerDataService
