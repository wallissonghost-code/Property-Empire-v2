local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local WorldGameplayService = {}
local started = false
local rankingStore = DataStoreService:GetOrderedDataStore("MuseumEmpirePrestigeV1")

local function ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild("MuseumWorldRemotes") or Instance.new("Folder")
	folder.Name = "MuseumWorldRemotes" folder.Parent = ReplicatedStorage
	local state = folder:FindFirstChild("GetWorldState") or Instance.new("RemoteFunction")
	state.Name = "GetWorldState" state.Parent = folder
	local action = folder:FindFirstChild("WorldAction") or Instance.new("RemoteFunction")
	action.Name = "WorldAction" action.Parent = folder
	return state, action
end

local function makePart(parent,name,size,cf,color,material)
	local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Anchored=true p.CanCollide=true
	p.Color=color p.Material=material or Enum.Material.SmoothPlastic p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent
	return p
end

local function sign(part,text)
	local gui=Instance.new("SurfaceGui") gui.Face=Enum.NormalId.Front gui.CanvasSize=Vector2.new(700,350) gui.Parent=part
	local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundColor3=Color3.fromRGB(19,23,29) l.BackgroundTransparency=.08
	l.TextColor3=Color3.new(1,1,1) l.TextWrapped=true l.TextScaled=true l.Font=Enum.Font.GothamBold l.Text=text l.Parent=gui
end

local function physicalZones(museum)
	if museum:FindFirstChild("GameplayZones") then return end
	local floor=museum:FindFirstChild("Floor") if not floor then return end
	local folder=Instance.new("Folder") folder.Name="GameplayZones" folder.Parent=museum
	local base=floor.CFrame*CFrame.new(0,-.5,0)
	local w,d=floor.Size.X,floor.Size.Z
	local reception=makePart(folder,"ReceptionDesk",Vector3.new(10,3,2.5),base*CFrame.new(-w*.26,1.5,d*.28),Color3.fromRGB(42,48,57),Enum.Material.Metal)
	sign(reception,"RECEPÇÃO")
	local shop=makePart(folder,"MuseumShop",Vector3.new(12,3,4),base*CFrame.new(w*.24,1.5,d*.25),Color3.fromRGB(70,54,43),Enum.Material.WoodPlanks)
	sign(shop,"LOJA DO MUSEU")
	for i=1,4 do
		local q=makePart(folder,"QueueSpot"..i,Vector3.new(3,.15,3),base*CFrame.new(-w*.26,.08,d*.28+4+i*3),Color3.fromRGB(79,119,140),Enum.Material.Neon)
		q.CanCollide=false q.Transparency=.65
	end
end

local function createRankingBoard(world)
	if world:FindFirstChild("PrestigeRankingBoard") then return end
	local board=makePart(world,"PrestigeRankingBoard",Vector3.new(18,12,1),CFrame.new(0,7,-22),Color3.fromRGB(27,31,38),Enum.Material.Metal)
	local gui=Instance.new("SurfaceGui") gui.Face=Enum.NormalId.Front gui.CanvasSize=Vector2.new(850,600) gui.Parent=board
	local label=Instance.new("TextLabel") label.Name="RankingText" label.Size=UDim2.fromScale(1,1) label.BackgroundColor3=Color3.fromRGB(15,19,25)
	label.TextColor3=Color3.fromRGB(245,247,250) label.Font=Enum.Font.GothamBold label.TextSize=38 label.TextWrapped=true label.TextYAlignment=Enum.TextYAlignment.Top label.Parent=gui
	label.Text="🏆 RANKING DE PRESTÍGIO\nCarregando..."
end

local function updateRanking(world,museumService)
	for _,p in ipairs(Players:GetPlayers()) do pcall(function() rankingStore:SetAsync(tostring(p.UserId),museumService:GetScore(p)) end) end
	local board=world:FindFirstChild("PrestigeRankingBoard")
	local label=board and board:FindFirstChildOfClass("SurfaceGui") and board:FindFirstChildOfClass("SurfaceGui"):FindFirstChild("RankingText")
	if not label then return end
	local ok,pages=pcall(function() return rankingStore:GetSortedAsync(false,10) end)
	if not ok then label.Text="🏆 RANKING DE PRESTÍGIO\nIndisponível agora" return end
	local lines={"🏆 RANKING DE PRESTÍGIO",""}
	for rank,item in ipairs(pages:GetCurrentPage()) do
		local uid=tonumber(item.key) local name="Jogador"
		pcall(function() name=Players:GetNameFromUserIdAsync(uid) end)
		table.insert(lines,string.format("%dº  %s  ·  %d",rank,name,math.floor(item.value)))
	end
	label.Text=table.concat(lines,"\n")
end

local function displayedArtifacts(profile)
	local result={}
	for _,artifact in ipairs(profile.Artifacts or {}) do
		if artifact.Location=="Display" and type(artifact.Uid)=="string" then
			table.insert(result,artifact)
		end
	end
	return result
end

local function artifactPart(info,artifact)
	if not info or not info.Model or not artifact then return nil end
	return info.Model:FindFirstChild("Artifact_"..artifact.Uid,true)
end

local function applyDamageVisual(info,artifact)
	local part=artifactPart(info,artifact)
	if not part or not part:IsA("BasePart") then return end
	local damage=math.clamp(math.floor(tonumber(artifact.Damage) or 0),0,100)
	part:SetAttribute("Damage",damage)
	part:SetAttribute("Condition",100-damage)
	if part:GetAttribute("OriginalColorR")==nil then
		part:SetAttribute("OriginalColorR",part.Color.R)
		part:SetAttribute("OriginalColorG",part.Color.G)
		part:SetAttribute("OriginalColorB",part.Color.B)
	end
	local r=tonumber(part:GetAttribute("OriginalColorR")) or part.Color.R
	local g=tonumber(part:GetAttribute("OriginalColorG")) or part.Color.G
	local b=tonumber(part:GetAttribute("OriginalColorB")) or part.Color.B
	local factor=1-(damage/100)*.45
	part.Color=Color3.new(math.clamp(r*factor,0,1),math.clamp(g*factor,0,1),math.clamp(b*factor,0,1))
	local old=part:FindFirstChild("DamageHighlight")
	local tag=part:FindFirstChild("DamageTag")
	if damage<=0 then
		if old then old:Destroy() end
		if tag then tag:Destroy() end
		return
	end
	local h=old or Instance.new("Highlight")
	h.Name="DamageHighlight" h.Adornee=part h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
	h.FillTransparency=.9 h.OutlineTransparency=.22 h.OutlineColor=Color3.fromRGB(188,69,69) h.Parent=part
	if not tag then
		tag=Instance.new("BillboardGui") tag.Name="DamageTag" tag.Size=UDim2.fromOffset(150,36) tag.StudsOffset=Vector3.new(0,2.6,0) tag.AlwaysOnTop=true tag.MaxDistance=45 tag.Parent=part
		local label=Instance.new("TextLabel") label.Name="Text" label.Size=UDim2.fromScale(1,1) label.BackgroundColor3=Color3.fromRGB(55,20,23) label.BackgroundTransparency=.12
		label.TextColor3=Color3.fromRGB(255,225,225) label.Font=Enum.Font.GothamBold label.TextSize=12 label.Parent=tag
		Instance.new("UICorner",label).CornerRadius=UDim.new(0,8)
	end
	local label=tag:FindFirstChild("Text")
	if label then label.Text="⚠ DANIFICADO · "..damage.."%" end
end

local function applyAllDamageVisuals(info,profile)
	for _,artifact in ipairs(profile.Artifacts or {}) do
		if artifact.Location=="Display" and (tonumber(artifact.Damage) or 0)>0 then
			applyDamageVisual(info,artifact)
		end
	end
end

local function spawnThief(info, owner, dataService)
	local profile=dataService:Get(owner)
	if not profile then return end
	local targets=displayedArtifacts(profile)
	if #targets==0 then return end
	local target=targets[math.random(1,#targets)]
	local targetPart=artifactPart(info,target)
	if not targetPart then return end

	local desc=Instance.new("HumanoidDescription")
	local ok,model=pcall(function() return Players:CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R15) end)
	if not ok or not model then return end
	model.Name="MuseumThief" model:SetAttribute("ThiefNPC",true) model:SetAttribute("TargetArtifactUid",target.Uid)
	model.Parent=info.Model.Parent model:PivotTo(info.Entrance*CFrame.new(5,0,0))
	for _,p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Color=Color3.fromRGB(35,35,40) p.CanCollide=false end end
	local h=model:FindFirstChildOfClass("Humanoid")
	if h then
		h.WalkSpeed=18
		h:MoveTo(targetPart.Position)
		task.wait(3)
		profile=dataService:Get(owner)
		if profile then
			local ops=profile.Museum and profile.Museum.Operations or {}
			local securityStaff=ops.Staff and (ops.Staff.Security or 0) or 0
			local security=math.clamp((ops.Security or 50)+securityStaff*8,0,100)
			profile.Stats.RobberyAttempts=(profile.Stats.RobberyAttempts or 0)+1
			local toast=ReplicatedStorage:FindFirstChild("MuseumRemotes") and ReplicatedStorage.MuseumRemotes:FindFirstChild("MuseumToast")
			local blockedChance=math.clamp(.18+security/115,.18,.96)
			if math.random()<blockedChance then
				profile.Stats.RobberiesStopped=(profile.Stats.RobberiesStopped or 0)+1
				if toast then toast:FireClient(owner,"🛡️ Segurança protegeu uma peça da exposição") end
			else
				local damage=math.random(20,40)
				target.Damage=math.clamp(math.floor(tonumber(target.Damage) or 0)+damage,0,100)
				target.LastDamagedAt=os.time()
				profile.Stats.ArtifactDamageIncidents=(profile.Stats.ArtifactDamageIncidents or 0)+1
				profile.Stats.ArtifactDamagePoints=(profile.Stats.ArtifactDamagePoints or 0)+damage
				applyDamageVisual(info,target)
				if toast then toast:FireClient(owner,"🚨 Ladrão danificou uma peça da exposição · "..target.Damage.."% de dano") end
			end
			dataService:Sync(owner)
		end
		h:MoveTo(info.Exit.Position)
	end
	task.delay(5,function() if model and model.Parent then model:Destroy() end end)
end

local function dailyKey() return os.date("!%Y-%j") end
local function dailyProgress(profile)
	local target=25
	local progress=math.min(target,profile.Stats.Visits or 0)
	return progress,target
end

function WorldGameplayService:Start(dataService,museumService,worldService)
	if started then return end started=true
	local getState,action=ensureRemotes()
	local world=worldService:GetWorld()
	createRankingBoard(world)

	local function setup(player)
		task.spawn(function()
			local profile=dataService:Wait(player,15) if not profile then return end
			if profile.Progress.DailyKey~=dailyKey() then profile.Progress.DailyKey=dailyKey() profile.Progress.DailyClaimed=false dataService:Sync(player) end
			task.wait(2)
			local info=museumService:GetMuseumInfo(player)
			if info and info.Model then physicalZones(info.Model) applyAllDamageVisuals(info,profile) end
		end)
	end
	Players.PlayerAdded:Connect(setup) for _,p in ipairs(Players:GetPlayers()) do setup(p) end

	getState.OnServerInvoke=function(player)
		local profile=dataService:Get(player) if not profile then return {Ok=false,Error="Carregando"} end
		local progress,target=dailyProgress(profile)
		return {Ok=true,TutorialStep=profile.Progress.TutorialStep,TutorialDone=profile.Progress.TutorialDone,DailyProgress=progress,DailyTarget=target,DailyClaimed=profile.Progress.DailyClaimed,DailyReward=5000}
	end
	action.OnServerInvoke=function(player,payload)
		local profile=dataService:Get(player) if not profile then return {Ok=false,Error="Carregando"} end
		local a=type(payload)=="table" and payload.Action or ""
		if a=="AdvanceTutorial" and not profile.Progress.TutorialDone then
			profile.Progress.TutorialStep+=1
			if profile.Progress.TutorialStep>=6 then profile.Progress.TutorialStep=6 profile.Progress.TutorialDone=true dataService:AdjustCash(player,2500) end
			dataService:Sync(player) return {Ok=true,Message=profile.Progress.TutorialDone and "Tutorial concluído · +$2.500" or "Etapa concluída"}
		elseif a=="ClaimDaily" then
			local progress,target=dailyProgress(profile)
			if profile.Progress.DailyClaimed then return {Ok=false,Error="Objetivo diário já resgatado"} end
			if progress<target then return {Ok=false,Error="Objetivo diário incompleto"} end
			profile.Progress.DailyClaimed=true dataService:AdjustCash(player,5000) dataService:Sync(player)
			return {Ok=true,Message="Objetivo diário concluído · +$5.000"}
		end
		return {Ok=false,Error="Ação inválida"}
	end

	task.spawn(function()
		while task.wait(20) do
			for _,owner in ipairs(museumService:GetOwners()) do
				local info=museumService:GetMuseumInfo(owner)
				local profile=dataService:Get(owner)
				if info and info.Model then physicalZones(info.Model) if profile then applyAllDamageVisuals(info,profile) end end
			end
		end
	end)
	task.spawn(function() while task.wait(75) do updateRanking(world,museumService) end end)
	task.spawn(function()
		while task.wait(55) do
			for _,owner in ipairs(museumService:GetOwners()) do
				local info=museumService:GetMuseumInfo(owner)
				if info and math.random()<.18 then task.spawn(spawnThief,info,owner,dataService) end
			end
		end
	end)
	print("[Museum Empire] WorldGameplayService started — thieves now target and damage displayed artifacts")
end

return WorldGameplayService
