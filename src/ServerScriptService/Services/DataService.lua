local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)

local DataService = {}
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {}
local started = false

local function defaultProfile()
	return {
		SchemaVersion = Config.SchemaVersion,
		Cash = Config.StartingCash,
		Museum = {
			Level = 1,
			BuildPieces = {},
			RatingXP = 0,
			Operations = {
				Staff = { Reception = 0, Security = 0, Cleaning = 0, Shop = 0, Guide = 0 },
				Cleanliness = 100,
				Security = 50,
				Rating = 50,
				ActiveEvent = nil,
				EventEndsAt = 0,
			},
		},
		Artifacts = {},
		Stats = {
			Mined = 0,
			Visits = 0,
			VisitorRevenue = 0,
			VIPVisits = 0,
			CollectorVisits = 0,
			BestVisitRevenue = 0,
			Sales = 0,
			Purchases = 0,
			ShopRevenue = 0,
			EventRevenue = 0,
			EventsHosted = 0,
			MaintenancePaid = 0,
		},
	}
end

local function reconcile(p)
	local d = defaultProfile()
	if type(p) ~= "table" then return d end
	p.Cash = math.max(0, math.floor(tonumber(p.Cash) or d.Cash))
	if type(p.Museum) ~= "table" then p.Museum = d.Museum end
	p.Museum.Level = math.clamp(math.floor(tonumber(p.Museum.Level) or 1), 1, 5)
	p.Museum.RatingXP = math.max(0, math.floor(tonumber(p.Museum.RatingXP) or 0))
	if type(p.Museum.BuildPieces) ~= "table" then p.Museum.BuildPieces = {} end
	if type(p.Museum.Operations) ~= "table" then p.Museum.Operations = d.Museum.Operations end
	local ops = p.Museum.Operations
	if type(ops.Staff) ~= "table" then ops.Staff = d.Museum.Operations.Staff end
	for role, value in pairs(d.Museum.Operations.Staff) do ops.Staff[role] = math.clamp(math.floor(tonumber(ops.Staff[role]) or value), 0, 5) end
	ops.Cleanliness = math.clamp(math.floor(tonumber(ops.Cleanliness) or 100), 0, 100)
	ops.Security = math.clamp(math.floor(tonumber(ops.Security) or 50), 0, 100)
	ops.Rating = math.clamp(math.floor(tonumber(ops.Rating) or 50), 0, 100)
	if type(ops.ActiveEvent) ~= "string" then ops.ActiveEvent = nil end
	ops.EventEndsAt = math.max(0, math.floor(tonumber(ops.EventEndsAt) or 0))

	local cleanPieces = {}
	for _, piece in ipairs(p.Museum.BuildPieces) do
		if type(piece) == "table" and type(piece.Id) == "string" and type(piece.ItemId) == "string" and tonumber(piece.X) and tonumber(piece.Z) then
			table.insert(cleanPieces, {
				Id = piece.Id, ItemId = piece.ItemId, X = tonumber(piece.X), Z = tonumber(piece.Z),
				Floor = math.clamp(math.floor(tonumber(piece.Floor) or 1), 1, 5),
				Rotation = math.floor(tonumber(piece.Rotation) or 0), CreatedAt = math.max(0, math.floor(tonumber(piece.CreatedAt) or 0)),
			})
		end
		if #cleanPieces >= 500 then break end
	end
	p.Museum.BuildPieces = cleanPieces
	if type(p.Artifacts) ~= "table" then p.Artifacts = {} end
	if type(p.Stats) ~= "table" then p.Stats = d.Stats end
	for k, v in pairs(d.Stats) do p.Stats[k] = math.max(0, math.floor(tonumber(p.Stats[k]) or v)) end
	p.SchemaVersion = Config.SchemaVersion
	return p
end

local function tester(player)
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function sync(player)
	local p = profiles[player]
	if not p then return end
	local cash = tester(player) and Config.TesterCash or p.Cash
	player:SetAttribute("Cash", cash)
	player:SetAttribute("MuseumLevel", p.Museum.Level)
	player:SetAttribute("MuseumVisits", p.Stats.Visits or 0)
	player:SetAttribute("MuseumRevenue", p.Stats.VisitorRevenue or 0)
	local ops = p.Museum.Operations
	player:SetAttribute("MuseumRating", ops.Rating or 50)
	player:SetAttribute("MuseumCleanliness", ops.Cleanliness or 100)
	player:SetAttribute("MuseumSecurity", ops.Security or 50)
	player:SetAttribute("MuseumEvent", ops.ActiveEvent or "")
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashValue then cashValue.Value = math.min(cash, 2147483647) end
end

function DataService:Load(player)
	local ok, raw = pcall(function() return store:GetAsync("player_" .. player.UserId) end)
	profiles[player] = reconcile(ok and raw or nil)
	local leaderstats = Instance.new("Folder") leaderstats.Name = "leaderstats" leaderstats.Parent = player
	local cash = Instance.new("IntValue") cash.Name = "Cash" cash.Parent = leaderstats
	sync(player)
end

function DataService:Get(player) return profiles[player] end
function DataService:IsTester(player) return tester(player) end
function DataService:Sync(player) sync(player) end
function DataService:Wait(player, seconds)
	local deadline = os.clock() + (seconds or 10)
	while player.Parent and not profiles[player] and os.clock() < deadline do task.wait() end
	return profiles[player]
end

function DataService:AdjustCash(player, delta)
	local p = profiles[player]
	if not p then return false end
	delta = math.floor(tonumber(delta) or 0)
	if delta < 0 and tester(player) then sync(player) return true end
	if p.Cash + delta < 0 then return false end
	p.Cash += delta sync(player) return true
end

function DataService:Save(player)
	local p = profiles[player]
	if not p then return false end
	return pcall(function() store:SetAsync("player_" .. player.UserId, p) end)
end

function DataService:Start()
	if started then return end started = true
	Players.PlayerAdded:Connect(function(p) self:Load(p) end)
	Players.PlayerRemoving:Connect(function(p) self:Save(p) profiles[p] = nil end)
	for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() self:Load(p) end) end
	task.spawn(function() while task.wait(Config.AutosaveSeconds) do for p in pairs(profiles) do task.spawn(function() self:Save(p) end) end end end)
	game:BindToClose(function() for p in pairs(profiles) do self:Save(p) end end)
	print("[Museum Empire] DataService started")
end

return DataService
