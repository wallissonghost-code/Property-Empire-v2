local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local PlayerDataTemplate = require(Shared.PlayerDataTemplate)

local PlayerDataService = {}
local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local profiles = {}
local testOriginalCash = {}
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

local function countDictionaryEntries(value)
	if type(value) ~= "table" then
		return 0
	end

	local count = 0
	for _ in pairs(value) do
		count += 1
	end
	return count
end

local function isUnlimitedCashTester(player)
	if not GameConfig.TestUnlimitedCashEnabled then
		return false
	end

	if GameConfig.TestUnlimitedCashCreatorAccess
		and game.CreatorType == Enum.CreatorType.User
		and player.UserId == game.CreatorId
	then
		return true
	end

	local usernames = GameConfig.TestUnlimitedCashUsernames
	if type(usernames) == "table" then
		for _, username in ipairs(usernames) do
			if type(username) == "string" and string.lower(player.Name) == string.lower(username) then
				return true
			end
		end
	end

	return false
end

local function enableUnlimitedCashForSession(player, data)
	if not isUnlimitedCashTester(player) then
		player:SetAttribute("UnlimitedTestCash", false)
		return
	end

	-- Keep the real balance separately so test money never pollutes persistence.
	testOriginalCash[player] = math.max(0, math.floor(tonumber(data.Cash) or 0))
	data.Cash = math.max(1, math.floor(tonumber(GameConfig.TestUnlimitedCash) or 999999999))
	player:SetAttribute("UnlimitedTestCash", true)
end

local function syncPublicAttributes(player, data)
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("OwnedLotCount", #data.OwnedLots)
	player:SetAttribute("BusinessCount", countDictionaryEntries(data.Businesses))
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
	enableUnlimitedCashForSession(player, data)
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
	local originalCash = testOriginalCash[player]
	if originalCash ~= nil then
		snapshot.Cash = originalCash
	end

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

	if testOriginalCash[player] ~= nil then
		data.Cash = math.max(1, math.floor(tonumber(GameConfig.TestUnlimitedCash) or 999999999))
		player:SetAttribute("Cash", data.Cash)
		return true, data.Cash
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

function PlayerDataService:SetBusiness(player, lotId, businessRecord)
	local data = profiles[player]
	if not data or type(lotId) ~= "string" or type(businessRecord) ~= "table" then
		return false
	end

	if type(data.Businesses) ~= "table" then
		data.Businesses = {}
	end
	data.Businesses[lotId] = deepCopy(businessRecord)
	player:SetAttribute("BusinessCount", countDictionaryEntries(data.Businesses))
	return true
end

function PlayerDataService:RemoveBusiness(player, lotId)
	local data = profiles[player]
	if not data or type(data.Businesses) ~= "table" then
		return false
	end

	data.Businesses[lotId] = nil
	player:SetAttribute("BusinessCount", countDictionaryEntries(data.Businesses))
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
		testOriginalCash[player] = nil
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
