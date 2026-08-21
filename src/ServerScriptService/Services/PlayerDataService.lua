local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local PlayerDataTemplate = require(Shared.PlayerDataTemplate)

local PlayerDataService = {}
local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local profiles = {}

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

function PlayerDataService:Get(player)
	return profiles[player]
end

function PlayerDataService:Load(player)
	local success, stored = pcall(function()
		return store:GetAsync(dataKey(player))
	end)
	if not success then
		return nil
	end
	local data = type(stored) == "table" and stored or deepCopy(PlayerDataTemplate)
	reconcile(data, PlayerDataTemplate)
	data.SchemaVersion = GameConfig.SchemaVersion
	data.Meta.CreatedAt = data.Meta.CreatedAt ~= 0 and data.Meta.CreatedAt or os.time()
	data.Meta.LastSeenAt = os.time()
	profiles[player] = data
	return data
end

function PlayerDataService:Save(player)
	local data = profiles[player]
	if not data then
		return true
	end
	data.Meta.LastSeenAt = os.time()
	local snapshot = deepCopy(data)
	local success = pcall(function()
		store:SetAsync(dataKey(player), snapshot)
	end)
	return success
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(function(player)
		if not self:Load(player) then
			player:Kick("Falha ao carregar seus dados. Tente novamente.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Save(player)
		profiles[player] = nil
	end)
end

return PlayerDataService
