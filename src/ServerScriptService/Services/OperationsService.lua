local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.OperationsConfig)

local OperationsService = {}
local started = false
local dataService

local function ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild("MuseumOperationsRemotes") or Instance.new("Folder")
	folder.Name = "MuseumOperationsRemotes"
	folder.Parent = ReplicatedStorage
	local state = folder:FindFirstChild("GetOperationsState") or Instance.new("RemoteFunction")
	state.Name = "GetOperationsState" state.Parent = folder
	local action = folder:FindFirstChild("OperationsAction") or Instance.new("RemoteFunction")
	action.Name = "OperationsAction" action.Parent = folder
	return state, action
end

local function normalizeEvent(profile)
	local ops = profile.Museum.Operations
	if ops.ActiveEvent and os.time() >= (ops.EventEndsAt or 0) then
		ops.ActiveEvent = nil
		ops.EventEndsAt = 0
	end
end

function OperationsService:GetState(player)
	local profile = dataService:Get(player)
	if not profile then return {Ok=false, Error="Dados carregando"} end
	normalizeEvent(profile)
	local ops = profile.Museum.Operations
	local staff = {}
	for roleId, spec in pairs(Config.Roles) do
		local level = ops.Staff[roleId] or 0
		staff[roleId] = {Id=roleId, Name=spec.Name, Level=level, MaxLevel=Config.MaxStaffLevel, NextCost=level < Config.MaxStaffLevel and Config.NextStaffCost(roleId, level) or nil}
	end
	return {
		Ok=true, Cash=player:GetAttribute("Cash") or 0, Rating=ops.Rating, Cleanliness=ops.Cleanliness, Security=ops.Security,
		Staff=staff, ActiveEvent=ops.ActiveEvent, EventEndsAt=ops.EventEndsAt, Events=Config.Events,
	}
end

function OperationsService:Action(player, payload)
	if type(payload) ~= "table" then return {Ok=false, Error="Ação inválida"} end
	local profile = dataService:Get(player)
	if not profile then return {Ok=false, Error="Dados carregando"} end
	local ops = profile.Museum.Operations
	normalizeEvent(profile)

	if payload.Action == "Hire" then
		local roleId = tostring(payload.Role or "")
		local role = Config.Roles[roleId]
		if not role then return {Ok=false, Error="Cargo inválido"} end
		local level = ops.Staff[roleId] or 0
		if level >= Config.MaxStaffLevel then return {Ok=false, Error="Equipe já está no nível máximo"} end
		local cost = Config.NextStaffCost(roleId, level)
		if not dataService:AdjustCash(player, -cost) then return {Ok=false, Error="Dinheiro insuficiente"} end
		ops.Staff[roleId] = level + 1
		dataService:Sync(player)
		dataService:Save(player)
		return {Ok=true, Message=role.Name .. " evoluiu para nível " .. (level + 1)}
	elseif payload.Action == "StartEvent" then
		if ops.ActiveEvent then return {Ok=false, Error="Já existe um evento ativo"} end
		local eventId = tostring(payload.EventId or "")
		local event = Config.Events[eventId]
		if not event then return {Ok=false, Error="Evento inválido"} end
		local prestige = player:GetAttribute("MuseumPrestige") or 0
		if event.MinPrestige and prestige < event.MinPrestige then return {Ok=false, Error="Prestígio insuficiente"} end
		if not dataService:AdjustCash(player, -event.Cost) then return {Ok=false, Error="Dinheiro insuficiente"} end
		ops.ActiveEvent = eventId
		ops.EventEndsAt = os.time() + Config.EventDurationSeconds
		profile.Stats.EventsHosted += 1
		ops.Rating = math.clamp(ops.Rating + (event.RatingBonus or 0), 0, 100)
		dataService:Sync(player)
		dataService:Save(player)
		return {Ok=true, Message=event.Name .. " começou"}
	end
	return {Ok=false, Error="Ação desconhecida"}
end

function OperationsService:Start(ds)
	if started then return end started = true dataService = ds
	local getState, action = ensureRemotes()
	getState.OnServerInvoke = function(player) return self:GetState(player) end
	action.OnServerInvoke = function(player, payload) return self:Action(player, payload) end

	task.spawn(function()
		while task.wait(Config.TickSeconds) do
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = dataService:Get(player)
				if profile then
					normalizeEvent(profile)
					local ops = profile.Museum.Operations
					local staff = ops.Staff
					ops.Cleanliness = math.clamp(ops.Cleanliness - 2 + (staff.Cleaning or 0) * 4, 0, 100)
					ops.Security = math.clamp(35 + (staff.Security or 0) * 13, 0, 100)
					local passive = (staff.Reception or 0) * 35 + (staff.Shop or 0) * 75 + (staff.Guide or 0) * 45
					if passive > 0 then
						dataService:AdjustCash(player, passive)
						profile.Stats.ShopRevenue += passive
					end
					local staffRating = (staff.Reception or 0)*2 + (staff.Cleaning or 0)*2 + (staff.Guide or 0)*2 + (staff.Security or 0)
					ops.Rating = math.clamp(math.floor((ops.Cleanliness + ops.Security)/4 + 35 + staffRating), 0, 100)
					dataService:Sync(player)
				end
			end
		end
	end)
	print("[Museum Empire] OperationsService started — staff, maintenance, shop, security and events")
end

return OperationsService
