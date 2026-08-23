local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage.Shared.ExpansionConfig)

local ExpansionService = {}
local started = false
local dataService
local museumService
local remotes
local staffModels = {}
local rankingStore = DataStoreService:GetOrderedDataStore("MuseumEmpirePrestige_v1")
local rng = Random.new()

local function ensureRemote(className, name)
	local existing = remotes:FindFirstChild(name)
	if existing and existing.ClassName == className then return existing end
	if existing then existing:Destroy() end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local function createRig(roleId, cf, parent)
	local role = Config.StaffRoles[roleId]
	if not role then return nil end
	local description = Instance.new("HumanoidDescription")
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil end
	model.Name = "Staff_" .. roleId
	model:SetAttribute("MuseumStaff", true)
	model:SetAttribute("StaffRole", roleId)
	model.Parent = parent
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if p.Name:find("Torso") then p.Color = role.Color end
			p.CanCollide = false
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.WalkSpeed = 8
	end
	model:PivotTo(cf)
	local head = model:FindFirstChild("Head")
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(140, 30)
		gui.StudsOffset = Vector3.new(0, 2.4, 0)
		gui.MaxDistance = 40
		gui.AlwaysOnTop = true
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1,1)
		label.BackgroundTransparency = .25
		label.BackgroundColor3 = Color3.fromRGB(25,29,35)
		label.TextColor3 = Color3.fromRGB(245,247,250)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.Text = role.Name
		label.Parent = gui
		Instance.new("UICorner", label).CornerRadius = UDim.new(0,8)
	end
	return model
end

local function clearStaff(player)
	if staffModels[player] then staffModels[player]:Destroy() staffModels[player] = nil end
end

local function renderStaff(player)
	clearStaff(player)
	local profile = dataService:Get(player)
	local info = museumService:GetMuseumInfo(player)
	if not profile or not info or not info.Model then return end
	local folder = Instance.new("Folder")
	folder.Name = "StaffNPCs"
	folder.Parent = info.Model
	staffModels[player] = folder
	local floor = info.Model:FindFirstChild("Floor")
	if not floor then return end
	local roles = {"Reception","Security","Cleaning","Shop","Guide"}
	local slots = {
		Reception = Vector3.new(-floor.Size.X*.28, 2.8, floor.Size.Z*.25),
		Security = Vector3.new(floor.Size.X*.28, 2.8, floor.Size.Z*.28),
		Cleaning = Vector3.new(-floor.Size.X*.22, 2.8, -floor.Size.Z*.1),
		Shop = Vector3.new(floor.Size.X*.22, 2.8, -floor.Size.Z*.12),
		Guide = Vector3.new(0, 2.8, -floor.Size.Z*.22),
	}
	for _, roleId in ipairs(roles) do
		local level = profile.Museum.Operations.Staff[roleId] or 0
		if level > 0 then
			local model = createRig(roleId, floor.CFrame * CFrame.new(slots[roleId]), folder)
			if model then model:SetAttribute("StaffLevel", level) end
		end
	end
end

local function missionState(profile)
	profile.Progress = profile.Progress or { ClaimedMissions = {}, Achievements = {} }
	profile.Progress.ClaimedMissions = profile.Progress.ClaimedMissions or {}
	profile.Progress.Achievements = profile.Progress.Achievements or {}
	return profile.Progress
end

local function getMissionValue(profile, mission)
	return tonumber(profile.Stats[mission.Stat]) or 0
end

local function checkAchievements(player)
	local profile = dataService:Get(player)
	if not profile then return end
	local progress = missionState(profile)
	local prestige = player:GetAttribute("Prestige") or museumService:GetScore(player)
	for _, a in ipairs(Config.Achievements) do
		if not progress.Achievements[a.Id] then
			local value = 0
			if a.Kind == "Level" then value = profile.Museum.Level
			elseif a.Kind == "Prestige" then value = prestige
			else value = profile.Stats[a.Kind] or 0 end
			if value >= a.Goal then
				progress.Achievements[a.Id] = os.time()
				local toast = remotes:FindFirstChild("MuseumToast")
				if toast then toast:FireClient(player, "🏆 Conquista desbloqueada: " .. a.Name) end
			end
		end
	end
end

local function getState(player)
	local profile = dataService:Get(player)
	if not profile then return {Ok=false, Error="Carregando"} end
	local progress = missionState(profile)
	local missions = {}
	for _, m in ipairs(Config.Missions) do
		table.insert(missions, {
			Id=m.Id, Name=m.Name, Description=m.Description, Goal=m.Goal, Reward=m.Reward,
			Value=getMissionValue(profile,m), Claimed=progress.ClaimedMissions[m.Id] == true,
		})
	end
	local achievements = {}
	for _, a in ipairs(Config.Achievements) do
		table.insert(achievements,{Id=a.Id,Name=a.Name,Unlocked=progress.Achievements[a.Id] ~= nil})
	end
	return {Ok=true, Missions=missions, Achievements=achievements, Stats=profile.Stats}
end

local function claimMission(player, id)
	local profile = dataService:Get(player)
	if not profile then return {Ok=false,Error="Carregando"} end
	local progress = missionState(profile)
	for _, m in ipairs(Config.Missions) do
		if m.Id == id then
			if progress.ClaimedMissions[id] then return {Ok=false,Error="Recompensa já coletada"} end
			if getMissionValue(profile,m) < m.Goal then return {Ok=false,Error="Missão ainda incompleta"} end
			progress.ClaimedMissions[id] = true
			dataService:AdjustCash(player, m.Reward)
			return {Ok=true,Message="Missão concluída! +$"..m.Reward}
		end
	end
	return {Ok=false,Error="Missão inválida"}
end

local function shopTick(player)
	local profile = dataService:Get(player)
	if not profile then return end
	local staff = profile.Museum.Operations.Staff
	local level = staff.Shop or 0
	if level <= 0 then return end
	local visits = profile.Stats.Visits or 0
	local revenue = math.max(10, math.floor((25 + visits * .08) * level * rng:NextNumber(.7,1.3)))
	dataService:AdjustCash(player, revenue)
	profile.Stats.ShopRevenue = (profile.Stats.ShopRevenue or 0) + revenue
end

local function incidentTick(player)
	local profile = dataService:Get(player)
	if not profile then return end
	local ops = profile.Museum.Operations
	local securityLevel = ops.Staff.Security or 0
	local security = math.clamp((ops.Security or 50) + securityLevel*8,0,100)
	local chance = math.clamp(Config.RobberyBaseChance + (100-security)/400, Config.RobberyBaseChance, Config.RobberyMaxChance)
	if rng:NextNumber() < chance then
		profile.Stats.RobberyAttempts = (profile.Stats.RobberyAttempts or 0) + 1
		local toast = remotes:FindFirstChild("MuseumToast")
		local blockedChance = math.clamp(.15 + security/120, .15, .95)
		if rng:NextNumber() < blockedChance then
			profile.Stats.RobberiesStopped = (profile.Stats.RobberiesStopped or 0) + 1
			if toast then toast:FireClient(player,"🛡️ Segurança impediu uma tentativa de roubo") end
		else
			local loss = rng:NextInteger(Config.RobberyLossMin, Config.RobberyLossMax)
			loss = math.min(loss, profile.Cash or loss)
			if loss > 0 then dataService:AdjustCash(player,-loss) end
			profile.Stats.RobberyLosses = (profile.Stats.RobberyLosses or 0) + loss
			ops.Security = math.max(0,(ops.Security or 50)-8)
			if toast then toast:FireClient(player,"🚨 Roubo! Prejuízo de $"..loss) end
		end
	end
end

local function randomEventTick(player)
	local profile = dataService:Get(player)
	if not profile then return end
	local ops = profile.Museum.Operations
	if ops.ActiveEvent and (ops.EventEndsAt or 0) > os.time() then return end
	if rng:NextNumber() > .32 then return end
	local event = Config.RandomEvents[rng:NextInteger(1,#Config.RandomEvents)]
	ops.ActiveEvent = event.Id
	ops.EventEndsAt = os.time() + event.Duration
	profile.Stats.RandomEvents = (profile.Stats.RandomEvents or 0) + 1
	local toast = remotes:FindFirstChild("MuseumToast")
	if toast then toast:FireClient(player,"✨ Evento aleatório: "..event.Name) end
end

function ExpansionService:Start(ds, ms)
	if started then return end
	started=true dataService=ds museumService=ms
	remotes = ReplicatedStorage:FindFirstChild("MuseumExpansionRemotes") or Instance.new("Folder")
	remotes.Name="MuseumExpansionRemotes" remotes.Parent=ReplicatedStorage
	local getExpansionState=ensureRemote("RemoteFunction","GetExpansionState")
	local expansionAction=ensureRemote("RemoteFunction","ExpansionAction")
	getExpansionState.OnServerInvoke=function(player) return getState(player) end
	expansionAction.OnServerInvoke=function(player,payload)
		if type(payload)~="table" then return {Ok=false,Error="Ação inválida"} end
		if payload.Action=="ClaimMission" then return claimMission(player,payload.Id) end
		return {Ok=false,Error="Ação inválida"}
	end

	local function setup(player)
		task.spawn(function()
			if not dataService:Wait(player,15) then return end
			task.wait(1)
			renderStaff(player)
			while player.Parent do
				checkAchievements(player)
				pcall(function() rankingStore:SetAsync(tostring(player.UserId), museumService:GetScore(player)) end)
				task.wait(30)
			end
		end)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player) clearStaff(player) end)
	for _,p in ipairs(Players:GetPlayers()) do setup(p) end

	task.spawn(function() while task.wait(Config.ShopTick) do for _,p in ipairs(Players:GetPlayers()) do shopTick(p) end end end)
	task.spawn(function() while task.wait(Config.IncidentTick) do for _,p in ipairs(Players:GetPlayers()) do incidentTick(p) end end end)
	task.spawn(function() while task.wait(Config.RandomEventTick) do for _,p in ipairs(Players:GetPlayers()) do randomEventTick(p) end end end)
	task.spawn(function()
		while task.wait(8) do
			for _,p in ipairs(Players:GetPlayers()) do
				local profile=dataService:Get(p)
				local folder=staffModels[p]
				local expected=profile and profile.Museum and profile.Museum.Operations and profile.Museum.Operations.Staff or nil
				if expected and not folder then renderStaff(p) end
			end
		end
	end)
	print("[Museum Empire] ExpansionService started — physical staff, shop, incidents, missions, achievements, ranking")
end

return ExpansionService
