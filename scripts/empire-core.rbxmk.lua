local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)
local serverScriptService = place:GetService("ServerScriptService")
local starterPlayer = place:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

local starterGui = place:GetService("StarterGui")
local lighting = place:GetService("Lighting")
lighting.Brightness = 2
lighting.ClockTime = 14
lighting.Ambient = Color3.fromRGB(105, 112, 125)
lighting.OutdoorAmbient = Color3.fromRGB(135, 145, 158)

local colorFx = lighting:FindFirstChild("MiningEmpireColor")
if not colorFx then
	colorFx = Instance.new("ColorCorrectionEffect")
	colorFx.Name = "MiningEmpireColor"
	colorFx.Parent = lighting
end
colorFx.Brightness = 0.02
colorFx.Contrast = 0.06
colorFx.Saturation = -0.04

local removeNames = {
	MiningEmpireMuseumBootstrap = true,
	MiningEmpireVisitorService = true,
	MiningEmpireDirectEntry = true,
	MiningEmpireSafeHUD = true,
	MiningEmpireTravelUI = true,
	MiningEmpireMuseumEconomyUI = true,
	MiningEmpireCoreServer = true,
	MiningEmpireCoreClient = true,
}
for _, instance in ipairs(serverScriptService:GetChildren()) do
	if removeNames[instance.Name] then instance:Destroy() end
end
for _, instance in ipairs(starterPlayerScripts:GetChildren()) do
	if removeNames[instance.Name] then instance:Destroy() end
end

-- Remove the old loading UI at build time. Other legacy interfaces are hidden by the new client.
for _, child in ipairs(starterGui:GetChildren()) do
	local n = string.lower(child.Name or "")
	if n == "loadgui" or n == "loadinggui" then child:Destroy() end
end

local server = Instance.new("Script")
server.Name = "MiningEmpireCoreServer"
server.Source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")

local STORE = DataStoreService:GetDataStore("MiningEmpireCore_v2")
local MINE_ORIGIN = Vector3.new(0, 28, -500)
local MUSEUM_ORIGIN = Vector3.new(-520, 24, -1500)
local PLOT_SPACING = 190
local MAX_PLOTS_PER_ROW = 4

local ARTIFACTS = {
	FossilShard={Name="Fragmento Fóssil",Rarity="Comum",Prestige=3,Color=Color3.fromRGB(154,126,94),Shape=Enum.PartType.Block},
	AncientCoin={Name="Moeda Antiga",Rarity="Comum",Prestige=5,Color=Color3.fromRGB(196,159,70),Shape=Enum.PartType.Cylinder},
	CrystalCore={Name="Núcleo de Cristal",Rarity="Raro",Prestige=12,Color=Color3.fromRGB(75,181,225),Shape=Enum.PartType.Ball},
	DinoRelic={Name="Relíquia Pré-Histórica",Rarity="Raro",Prestige=18,Color=Color3.fromRGB(128,166,92),Shape=Enum.PartType.Block},
	RoyalGem={Name="Joia Real",Rarity="Épico",Prestige=35,Color=Color3.fromRGB(163,94,226),Shape=Enum.PartType.Ball},
	MeteorFragment={Name="Fragmento de Meteorito",Rarity="Épico",Prestige=50,Color=Color3.fromRGB(88,98,120),Shape=Enum.PartType.Block},
	GoldenIdol={Name="Ídolo Dourado",Rarity="Lendário",Prestige=100,Color=Color3.fromRGB(247,199,67),Shape=Enum.PartType.Block},
	VoidCrystal={Name="Cristal do Vazio",Rarity="Mítico",Prestige=200,Color=Color3.fromRGB(88,47,142),Shape=Enum.PartType.Ball},
}

local ORES = {
	Stone={Name="Rocha",HP=2,Cash=20,Chance=.06,Color=Color3.fromRGB(105,105,108),Material=Enum.Material.Slate,Artifacts={"FossilShard","AncientCoin"}},
	Copper={Name="Cobre",HP=3,Cash=45,Chance=.09,Color=Color3.fromRGB(180,103,67),Material=Enum.Material.Metal,Artifacts={"AncientCoin","FossilShard","CrystalCore"}},
	Iron={Name="Ferro",HP=4,Cash=80,Chance=.13,Color=Color3.fromRGB(118,124,132),Material=Enum.Material.Metal,Artifacts={"CrystalCore","DinoRelic","MeteorFragment"}},
	Crystal={Name="Cristal",HP=5,Cash=145,Chance=.20,Color=Color3.fromRGB(65,176,221),Material=Enum.Material.Neon,Artifacts={"CrystalCore","RoyalGem","MeteorFragment"}},
	Ancient={Name="Veio Antigo",HP=7,Cash=260,Chance=.30,Color=Color3.fromRGB(121,85,151),Material=Enum.Material.Neon,Artifacts={"DinoRelic","RoyalGem","GoldenIdol","VoidCrystal"}},
}

local VISITOR_TYPES = {
	{Name="Turista",Min=0,Mult=1.0,Color=Color3.fromRGB(80,155,225)},
	{Name="Estudante",Min=40,Mult=1.15,Color=Color3.fromRGB(81,184,119)},
	{Name="Colecionador",Min=110,Mult=1.55,Color=Color3.fromRGB(169,104,219)},
	{Name="VIP",Min=260,Mult=2.2,Color=Color3.fromRGB(238,190,72)},
}
local UPGRADE_COST = {[1]=2500,[2]=8000,[3]=22000,[4]=60000}

local remotes = ReplicatedStorage:FindFirstChild("MiningEmpireCore") or Instance.new("Folder")
remotes.Name = "MiningEmpireCore"
remotes.Parent = ReplicatedStorage
local Travel = remotes:FindFirstChild("Travel") or Instance.new("RemoteEvent") Travel.Name="Travel" Travel.Parent=remotes
local Toast = remotes:FindFirstChild("Toast") or Instance.new("RemoteEvent") Toast.Name="Toast" Toast.Parent=remotes
local State = remotes:FindFirstChild("State") or Instance.new("RemoteFunction") State.Name="State" State.Parent=remotes

local world = workspace:FindFirstChild("MiningEmpireWorld")
if world then world:Destroy() end
world = Instance.new("Folder") world.Name="MiningEmpireWorld" world.Parent=workspace
local mineFolder = Instance.new("Model") mineFolder.Name="MineDistrict" mineFolder.Parent=world
local museumFolder = Instance.new("Folder") museumFolder.Name="PlayerMuseums" museumFolder.Parent=world

local profiles = {}
local plots = {}
local nextPlot = 0
local museumModels = {}
local mineCooldown = {}

local function defaultProfile()
	return {Cash=2500,Level=1,Inventory={},Display={},Visits=0,Revenue=0,Mined=0,Discoveries=0,BestVisit=0,Missions={}}
end
local function reconcile(d)
	if type(d)~="table" then d=defaultProfile() end
	d.Cash=tonumber(d.Cash) or 2500 d.Level=math.clamp(tonumber(d.Level) or 1,1,5)
	if type(d.Inventory)~="table" then d.Inventory={} end
	if type(d.Display)~="table" then d.Display={} end
	if type(d.Missions)~="table" then d.Missions={} end
	d.Visits=tonumber(d.Visits) or 0 d.Revenue=tonumber(d.Revenue) or 0 d.Mined=tonumber(d.Mined) or 0 d.Discoveries=tonumber(d.Discoveries) or 0 d.BestVisit=tonumber(d.BestVisit) or 0
	return d
end
local function save(player)
	local d=profiles[player] if not d then return end
	pcall(function() STORE:SetAsync("u"..player.UserId,d) end)
end
local function allocPlot(player)
	local idx=nextPlot nextPlot+=1 plots[player]=idx
	local col=idx%MAX_PLOTS_PER_ROW local row=math.floor(idx/MAX_PLOTS_PER_ROW)
	return MUSEUM_ORIGIN+Vector3.new(col*PLOT_SPACING,0,row*PLOT_SPACING)
end
local function plotOrigin(player)
	local idx=plots[player] or 0 local col=idx%MAX_PLOTS_PER_ROW local row=math.floor(idx/MAX_PLOTS_PER_ROW)
	return MUSEUM_ORIGIN+Vector3.new(col*PLOT_SPACING,0,row*PLOT_SPACING)
end
local function part(parent,name,size,cf,color,material)
	local p=Instance.new("Part") p.Name=name p.Anchored=true p.Size=size p.CFrame=cf p.Color=color or Color3.fromRGB(220,220,220) p.Material=material or Enum.Material.SmoothPlastic p.Parent=parent return p
end
local function displayCount(d)
	local n=0 for _,id in pairs(d.Display) do if ARTIFACTS[id] then n+=1 end end return n
end
local function prestige(d)
	local p=d.Level*12
	for _,id in pairs(d.Display) do local a=ARTIFACTS[id] if a then p+=a.Prestige end end
	return p
end
local function starsFor(p)
	if p>=500 then return 5 elseif p>=300 then return 4 elseif p>=150 then return 3 elseif p>=60 then return 2 elseif p>=20 then return 1 else return 0 end
end
local function slotCount(level) return math.min(24,8+(level-1)*4) end
local function setAttributes(player)
	local d=profiles[player] if not d then return end
	local pr=prestige(d)
	player:SetAttribute("EmpireCash",math.floor(d.Cash)) player:SetAttribute("MuseumLevel",d.Level) player:SetAttribute("MuseumPrestige",pr)
	player:SetAttribute("MuseumStars",starsFor(pr)) player:SetAttribute("MuseumVisits",d.Visits) player:SetAttribute("MuseumRevenue",math.floor(d.Revenue))
	player:SetAttribute("Mined",d.Mined) player:SetAttribute("ArtifactCount",#d.Inventory+displayCount(d)) player:SetAttribute("DisplayCount",displayCount(d))
end
local function addCash(player,amount)
	local d=profiles[player] if not d then return end d.Cash+=amount setAttributes(player)
end
local function missionCheck(player)
	local d=profiles[player] if not d then return end
	local awards={}
	if d.Mined>=10 and not d.Missions.Mine10 then d.Missions.Mine10=true d.Cash+=500 table.insert(awards,"Missão: 10 minérios · +$500") end
	if displayCount(d)>=3 and not d.Missions.Display3 then d.Missions.Display3=true d.Cash+=750 table.insert(awards,"Missão: 3 exposições · +$750") end
	if d.Revenue>=5000 and not d.Missions.Revenue5K then d.Missions.Revenue5K=true d.Cash+=1500 table.insert(awards,"Missão: $5.000 no museu · +$1.500") end
	setAttributes(player)
	for _,msg in ipairs(awards) do Toast:FireClient(player,msg,"Mission") end
end
local function publicState(player)
	local d=profiles[player] or defaultProfile() local inv={}
	for i,id in ipairs(d.Inventory) do local a=ARTIFACTS[id] if a then inv[i]={Id=id,Name=a.Name,Rarity=a.Rarity,Prestige=a.Prestige} end end
	return {Cash=d.Cash,Level=d.Level,Prestige=prestige(d),Stars=starsFor(prestige(d)),Inventory=inv,DisplayCount=displayCount(d),Slots=slotCount(d.Level),Visits=d.Visits,Revenue=d.Revenue,Mined=d.Mined,Discoveries=d.Discoveries,UpgradeCost=UPGRADE_COST[d.Level],Missions=d.Missions}
end
State.OnServerInvoke=function(player) return publicState(player) end

local function artifactVisual(parent,id,cf)
	local a=ARTIFACTS[id] if not a then return end
	local p=part(parent,"Artifact",Vector3.new(3.8,3.8,3.8),cf,a.Color,(a.Rarity=="Lendário" or a.Rarity=="Mítico") and Enum.Material.Neon or Enum.Material.SmoothPlastic)
	p.CanCollide=false p.Shape=a.Shape
	local gui=Instance.new("BillboardGui") gui.Size=UDim2.fromOffset(150,38) gui.StudsOffset=Vector3.new(0,3,0) gui.AlwaysOnTop=true gui.Parent=p
	local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundColor3=Color3.fromRGB(15,19,25) t.BackgroundTransparency=.15 t.TextColor3=Color3.new(1,1,1) t.Font=Enum.Font.GothamBold t.TextScaled=true t.Text=a.Name.." · "..a.Rarity t.Parent=gui
end
local function rebuildMuseum(player)
	local d=profiles[player] if not d then return end
	local old=museumModels[player] if old then old:Destroy() end
	local origin=plotOrigin(player)
	local m=Instance.new("Model") m.Name="Museum_"..player.UserId m.Parent=museumFolder museumModels[player]=m
	local level=d.Level local width=92+(level-1)*12 local depth=72+(level-1)*10
	part(m,"Floor",Vector3.new(width,2,depth),CFrame.new(origin),Color3.fromRGB(226,226,222),Enum.Material.Marble)
	part(m,"Back",Vector3.new(width,22,2),CFrame.new(origin+Vector3.new(0,11,-depth/2)),Color3.fromRGB(28,34,43),Enum.Material.Concrete)
	part(m,"Left",Vector3.new(2,22,depth),CFrame.new(origin+Vector3.new(-width/2,11,0)),Color3.fromRGB(28,34,43),Enum.Material.Concrete)
	part(m,"Right",Vector3.new(2,22,depth),CFrame.new(origin+Vector3.new(width/2,11,0)),Color3.fromRGB(28,34,43),Enum.Material.Concrete)
	local sign=part(m,"Sign",Vector3.new(42,7,2),CFrame.new(origin+Vector3.new(0,15,depth/2)),Color3.fromRGB(19,24,32),Enum.Material.Metal)
	local sg=Instance.new("SurfaceGui") sg.Face=Enum.NormalId.Front sg.Parent=sign local tx=Instance.new("TextLabel") tx.Size=UDim2.fromScale(1,1) tx.BackgroundTransparency=1 tx.TextColor3=Color3.fromRGB(245,202,83) tx.Font=Enum.Font.GothamBold tx.TextScaled=true tx.Text=player.DisplayName.." · MUSEU N"..level tx.Parent=sg
	local slots=slotCount(level)
	for i=1,slots do
		local cols=math.min(6,math.ceil(slots/2)) local row=math.floor((i-1)/cols) local col=(i-1)%cols local span=(cols-1)*13
		local pos=origin+Vector3.new(-span/2+col*13,3,-12+row*28)
		local ped=part(m,"Pedestal_"..i,Vector3.new(8,4,8),CFrame.new(pos),Color3.fromRGB(242,242,238),Enum.Material.Marble)
		local prompt=Instance.new("ProximityPrompt") prompt.ActionText=d.Display[tostring(i)] and "GUARDAR" or "EXPOR" prompt.ObjectText="Vitrine "..i prompt.HoldDuration=.15 prompt.MaxActivationDistance=10 prompt.Parent=ped
		if d.Display[tostring(i)] then artifactVisual(m,d.Display[tostring(i)],CFrame.new(pos+Vector3.new(0,4,0))) end
		prompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer~=player then return end local key=tostring(i)
			if d.Display[key] then table.insert(d.Inventory,d.Display[key]) d.Display[key]=nil Toast:FireClient(player,"Artefato guardado","Museum")
			elseif #d.Inventory>0 then d.Display[key]=table.remove(d.Inventory,1) Toast:FireClient(player,"Artefato colocado em exposição","Museum") else Toast:FireClient(player,"Seu inventário de artefatos está vazio","Warn") return end
			setAttributes(player) missionCheck(player) rebuildMuseum(player)
		end)
	end
	local terminal=part(m,"UpgradeTerminal",Vector3.new(9,6,9),CFrame.new(origin+Vector3.new(width/2-10,4,depth/2-11)),Color3.fromRGB(47,103,159),Enum.Material.Metal)
	local up=Instance.new("ProximityPrompt") up.ActionText=level<5 and "MELHORAR" or "MÁXIMO" up.ObjectText=level<5 and ("Museu · $"..tostring(UPGRADE_COST[level])) or "Museu N5" up.MaxActivationDistance=10 up.Parent=terminal
	up.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer~=player or level>=5 then return end local cost=UPGRADE_COST[d.Level] or math.huge
		if d.Cash<cost then Toast:FireClient(player,"Dinheiro insuficiente para melhorar o museu","Warn") return end
		d.Cash-=cost d.Level+=1 setAttributes(player) Toast:FireClient(player,"Museu evoluiu para N"..d.Level,"Upgrade") rebuildMuseum(player)
	end)
	local arrival=part(m,"Arrival",Vector3.new(14,1,10),CFrame.new(origin+Vector3.new(0,2,depth/2-12)),Color3.fromRGB(57,132,210),Enum.Material.Neon) arrival.CanCollide=true
end

local function rollArtifact(ore)
	if math.random()>ore.Chance then return nil end return ore.Artifacts[math.random(1,#ore.Artifacts)]
end
local function spawnOre(index,oreKey,pos)
	local ore=ORES[oreKey] local node=part(mineFolder,"Ore_"..index,Vector3.new(7,7,7),CFrame.new(pos),ore.Color,ore.Material)
	node:SetAttribute("OreKey",oreKey) node:SetAttribute("HP",ore.HP) node:SetAttribute("MaxHP",ore.HP)
	local prompt=Instance.new("ProximityPrompt") prompt.ActionText="MINERAR" prompt.ObjectText=ore.Name prompt.HoldDuration=.18 prompt.MaxActivationDistance=11 prompt.Parent=node
	prompt.Triggered:Connect(function(player)
		local now=os.clock() local last=mineCooldown[player] or 0 if now-last<.22 then return end mineCooldown[player]=now
		local hp=(node:GetAttribute("HP") or ore.HP)-1 node:SetAttribute("HP",hp)
		Toast:FireClient(player,ore.Name.." · "..math.max(0,hp).." HP","Mine")
		if hp<=0 then
			local d=profiles[player] if d then d.Mined+=1 addCash(player,ore.Cash) local artifact=rollArtifact(ore)
				if artifact then table.insert(d.Inventory,artifact) d.Discoveries+=1 local a=ARTIFACTS[artifact] Toast:FireClient(player,"🏺 "..a.Name.." encontrado · "..a.Rarity,"Artifact") end
				setAttributes(player) missionCheck(player)
			end
			node.Transparency=1 node.CanCollide=false prompt.Enabled=false
			task.delay(math.random(7,12),function() if node.Parent then node:SetAttribute("HP",ore.HP) node.Transparency=0 node.CanCollide=true prompt.Enabled=true end end)
		end
	end)
end

-- Dedicated mine district: mining now happens on actual breakable ore nodes, not a timer.
part(mineFolder,"MineGround",Vector3.new(150,3,120),CFrame.new(MINE_ORIGIN),Color3.fromRGB(66,65,62),Enum.Material.Rock)
local mineSign=part(mineFolder,"MineSign",Vector3.new(34,8,2),CFrame.new(MINE_ORIGIN+Vector3.new(0,12,54)),Color3.fromRGB(32,27,23),Enum.Material.WoodPlanks)
local msg=Instance.new("SurfaceGui") msg.Face=Enum.NormalId.Front msg.Parent=mineSign local mt=Instance.new("TextLabel") mt.Size=UDim2.fromScale(1,1) mt.BackgroundTransparency=1 mt.Text="⛏ MINING EMPIRE · MINA" mt.TextColor3=Color3.fromRGB(244,201,90) mt.Font=Enum.Font.GothamBold mt.TextScaled=true mt.Parent=msg
local oreOrder={"Stone","Stone","Copper","Stone","Iron","Copper","Crystal","Iron","Stone","Ancient","Copper","Crystal","Iron","Stone","Ancient","Copper","Iron","Crystal","Stone","Ancient"}
for i,key in ipairs(oreOrder) do local col=(i-1)%5 local row=math.floor((i-1)/5) spawnOre(i,key,MINE_ORIGIN+Vector3.new(-48+col*24,6,-36+row*24)) end
local spawn=Instance.new("SpawnLocation") spawn.Name="MiningEmpireSpawn" spawn.Anchored=true spawn.Neutral=true spawn.Size=Vector3.new(12,1,12) spawn.CFrame=CFrame.new(MINE_ORIGIN+Vector3.new(0,4,48)) spawn.Color=Color3.fromRGB(66,139,218) spawn.Material=Enum.Material.Neon spawn.Parent=mineFolder

local function chooseVisitor(pr)
	local options={} for _,v in ipairs(VISITOR_TYPES) do if pr>=v.Min then table.insert(options,v) end end return options[math.random(1,#options)]
end
local function spawnVisitor(player)
	local d=profiles[player] local m=museumModels[player] if not d or not m or displayCount(d)==0 then return end
	local pr=prestige(d) local kind=chooseVisitor(pr) local origin=plotOrigin(player)
	local desc=Instance.new("HumanoidDescription") desc.HeadColor=Color3.fromRGB(210,170,135) desc.TorsoColor=kind.Color desc.LeftArmColor=desc.HeadColor desc.RightArmColor=desc.HeadColor desc.LeftLegColor=Color3.fromRGB(45,50,60) desc.RightLegColor=desc.LeftLegColor
	local ok,rig=pcall(function() return Players:CreateHumanoidModelFromDescription(desc,Enum.HumanoidRigType.R15) end) desc:Destroy() if not ok or not rig then return end
	rig.Name=kind.Name rig.Parent=m local hum=rig:FindFirstChildOfClass("Humanoid") if not hum then rig:Destroy() return end
	rig:PivotTo(CFrame.new(origin+Vector3.new(math.random(-18,18),4,30))) for _,bp in ipairs(rig:GetDescendants()) do if bp:IsA("BasePart") then bp.CanCollide=false end end
	local value=math.max(25,math.floor((45+pr*2.2+displayCount(d)*8)*kind.Mult*(math.random(90,115)/100))) d.Visits+=1 d.Revenue+=value d.BestVisit=math.max(d.BestVisit,value) d.Cash+=value setAttributes(player) missionCheck(player) Toast:FireClient(player,"👤 "..kind.Name.." visitou · +$"..value,"Income")
	task.spawn(function()
		local stops={origin+Vector3.new(-26,4,0),origin+Vector3.new(25,4,-10),origin+Vector3.new(0,4,-24)}
		for _,target in ipairs(stops) do if not rig.Parent then return end hum:MoveTo(target+Vector3.new(math.random(-4,4),0,math.random(-4,4))) hum.MoveToFinished:Wait() task.wait(math.random(1,2)) end
		if rig.Parent then hum:MoveTo(origin+Vector3.new(0,4,34)) task.wait(3) rig:Destroy() end
	end)
end

Travel.OnServerEvent:Connect(function(player,dest)
	local ch=player.Character if not ch then return end
	if dest=="Mine" then ch:PivotTo(CFrame.new(MINE_ORIGIN+Vector3.new(0,7,46))) elseif dest=="Museum" then local o=plotOrigin(player) ch:PivotTo(CFrame.new(o+Vector3.new(0,7,28))) end
end)

Players.PlayerAdded:Connect(function(player)
	allocPlot(player) local data pcall(function() data=STORE:GetAsync("u"..player.UserId) end) profiles[player]=reconcile(data) setAttributes(player) rebuildMuseum(player)
	player.CharacterAdded:Connect(function(ch) task.wait(.4) ch:PivotTo(CFrame.new(MINE_ORIGIN+Vector3.new(0,7,46))) end)
	if player.Character then task.delay(.5,function() if player.Character then player.Character:PivotTo(CFrame.new(MINE_ORIGIN+Vector3.new(0,7,46))) end end) end
	Toast:FireClient(player,"Bem-vindo ao Mining Empire · mine, descubra e exponha relíquias","Welcome")
end)
Players.PlayerRemoving:Connect(function(player) save(player) profiles[player]=nil mineCooldown[player]=nil plots[player]=nil if museumModels[player] then museumModels[player]:Destroy() end museumModels[player]=nil end)
game:BindToClose(function() for _,p in ipairs(Players:GetPlayers()) do save(p) end end)

task.spawn(function() while task.wait(11) do for _,p in ipairs(Players:GetPlayers()) do if profiles[p] and displayCount(profiles[p])>0 then spawnVisitor(p) end end end end)
task.spawn(function() while task.wait(60) do for _,p in ipairs(Players:GetPlayers()) do save(p) end end end)
print("[Mining Empire] Core v2 online: real mining, personal museums, visitors, unified economy, stars and missions")
]=]
server.Parent = serverScriptService

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireCoreClient"
client.Source = [=[
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer local playerGui=player:WaitForChild("PlayerGui")
local remotes=ReplicatedStorage:WaitForChild("MiningEmpireCore") local Travel=remotes:WaitForChild("Travel") local Toast=remotes:WaitForChild("Toast") local State=remotes:WaitForChild("State")

local function suppressLegacy(gui)
	if not gui:IsA("ScreenGui") or gui.Name=="MiningEmpireCoreUI" then return end
	local n=string.lower(gui.Name or "")
	if n=="gui" or n=="oldgui" or n=="loadgui" or n=="loadinggui" or not string.find(gui.Name,"MiningEmpire",1,true) then gui.Enabled=false end
end
for _,g in ipairs(playerGui:GetChildren()) do suppressLegacy(g) end
playerGui.ChildAdded:Connect(function(g) task.defer(function() suppressLegacy(g) end) end)

local gui=Instance.new("ScreenGui") gui.Name="MiningEmpireCoreUI" gui.ResetOnSpawn=false gui.IgnoreGuiInset=false gui.DisplayOrder=100 gui.Parent=playerGui
local function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 12) c.Parent=o end
local function stroke(o) local s=Instance.new("UIStroke") s.Color=Color3.fromRGB(72,88,108) s.Transparency=.35 s.Thickness=1 s.Parent=o end
local panelColor=Color3.fromRGB(18,23,31) local cardColor=Color3.fromRGB(29,37,48) local textColor=Color3.fromRGB(242,245,249) local muted=Color3.fromRGB(170,182,198)

local intro=Instance.new("Frame") intro.Size=UDim2.fromScale(1,1) intro.BackgroundColor3=Color3.fromRGB(12,16,22) intro.ZIndex=200 intro.Parent=gui
local it=Instance.new("TextLabel") it.AnchorPoint=Vector2.new(.5,.5) it.Position=UDim2.fromScale(.5,.47) it.Size=UDim2.fromOffset(520,80) it.BackgroundTransparency=1 it.Text="MINING EMPIRE" it.TextColor3=Color3.fromRGB(244,202,83) it.Font=Enum.Font.GothamBlack it.TextScaled=true it.ZIndex=201 it.Parent=intro
local is=it:Clone() is.Position=UDim2.fromScale(.5,.56) is.Size=UDim2.fromOffset(420,34) is.Text="MINE · DESCUBRA · EXPONHA · EVOLUA" is.TextColor3=muted is.Font=Enum.Font.GothamBold is.Parent=intro
task.delay(1.3,function() TweenService:Create(intro,TweenInfo.new(.35),{BackgroundTransparency=1}):Play() TweenService:Create(it,TweenInfo.new(.25),{TextTransparency=1}):Play() TweenService:Create(is,TweenInfo.new(.25),{TextTransparency=1}):Play() task.wait(.4) intro:Destroy() end)

local top=Instance.new("Frame") top.AnchorPoint=Vector2.new(.5,0) top.Position=UDim2.new(.5,0,0,8) top.Size=UDim2.fromOffset(610,50) top.BackgroundColor3=panelColor top.Parent=gui corner(top,14) stroke(top)
local layout=Instance.new("UIListLayout") layout.FillDirection=Enum.FillDirection.Horizontal layout.VerticalAlignment=Enum.VerticalAlignment.Center layout.HorizontalAlignment=Enum.HorizontalAlignment.Center layout.Padding=UDim.new(0,5) layout.Parent=top
local labels={}
local function chip(key,w)
	local f=Instance.new("Frame") f.Size=UDim2.fromOffset(w,40) f.BackgroundColor3=cardColor f.Parent=top corner(f,10)
	local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1 l.TextColor3=textColor l.Font=Enum.Font.GothamBold l.TextSize=12 l.TextWrapped=true l.Parent=f labels[key]=l return l
end
chip("cash",145) chip("level",90) chip("prestige",110) chip("stars",105) chip("visits",125)
local function fmt(n) n=math.floor(tonumber(n) or 0) local s=tostring(n) repeat local k s,k=s:gsub("^(-?%d+)(%d%d%d)","%1.%2") until k==0 return s end
local function refreshTop()
	labels.cash.Text="💰 $"..fmt(player:GetAttribute("EmpireCash")) labels.level.Text="MUSEU\nN"..tostring(player:GetAttribute("MuseumLevel") or 1)
	labels.prestige.Text="PRESTÍGIO\n"..fmt(player:GetAttribute("MuseumPrestige")) local st=player:GetAttribute("MuseumStars") or 0 labels.stars.Text=string.rep("★",st)..string.rep("☆",5-st)
	labels.visits.Text="👥 "..fmt(player:GetAttribute("MuseumVisits")).."  ·  💵 $"..fmt(player:GetAttribute("MuseumRevenue"))
end
for _,a in ipairs({"EmpireCash","MuseumLevel","MuseumPrestige","MuseumStars","MuseumVisits","MuseumRevenue"}) do player:GetAttributeChangedSignal(a):Connect(refreshTop) end refreshTop()

local dock=Instance.new("Frame") dock.AnchorPoint=Vector2.new(.5,1) dock.Position=UDim2.new(.5,0,1,-12) dock.Size=UDim2.fromOffset(500,54) dock.BackgroundColor3=panelColor dock.Parent=gui corner(dock,15) stroke(dock)
local dl=Instance.new("UIListLayout") dl.FillDirection=Enum.FillDirection.Horizontal dl.HorizontalAlignment=Enum.HorizontalAlignment.Center dl.VerticalAlignment=Enum.VerticalAlignment.Center dl.Padding=UDim.new(0,6) dl.Parent=dock
local function btn(text,color)
	local b=Instance.new("TextButton") b.Size=UDim2.fromOffset(116,44) b.BackgroundColor3=color b.TextColor3=Color3.new(1,1,1) b.Font=Enum.Font.GothamBold b.TextSize=12 b.Text=text b.Parent=dock corner(b,11) return b
end
local mineBtn=btn("⛏ MINA",Color3.fromRGB(105,77,48)) local museumBtn=btn("🏛 MUSEU",Color3.fromRGB(48,91,137)) local collectionBtn=btn("🎒 COLEÇÃO",Color3.fromRGB(82,66,135)) local progressBtn=btn("⭐ PROGRESSO",Color3.fromRGB(48,118,88))
mineBtn.Activated:Connect(function() Travel:FireServer("Mine") end) museumBtn.Activated:Connect(function() Travel:FireServer("Museum") end)

local modal=Instance.new("Frame") modal.AnchorPoint=Vector2.new(.5,.5) modal.Position=UDim2.fromScale(.5,.52) modal.Size=UDim2.fromOffset(500,330) modal.BackgroundColor3=panelColor modal.Visible=false modal.ZIndex=120 modal.Parent=gui corner(modal,16) stroke(modal)
local title=Instance.new("TextLabel") title.Position=UDim2.fromOffset(18,12) title.Size=UDim2.new(1,-70,0,34) title.BackgroundTransparency=1 title.TextColor3=textColor title.Font=Enum.Font.GothamBold title.TextSize=20 title.TextXAlignment=Enum.TextXAlignment.Left title.ZIndex=121 title.Parent=modal
local close=Instance.new("TextButton") close.AnchorPoint=Vector2.new(1,0) close.Position=UDim2.new(1,-12,0,10) close.Size=UDim2.fromOffset(36,36) close.BackgroundColor3=cardColor close.Text="×" close.TextColor3=textColor close.TextSize=24 close.Font=Enum.Font.GothamBold close.ZIndex=121 close.Parent=modal corner(close,10) close.Activated:Connect(function() modal.Visible=false end)
local body=Instance.new("ScrollingFrame") body.Position=UDim2.fromOffset(16,58) body.Size=UDim2.new(1,-32,1,-74) body.BackgroundTransparency=1 body.BorderSizePixel=0 body.ScrollBarThickness=4 body.CanvasSize=UDim2.new() body.ZIndex=121 body.Parent=modal
local bl=Instance.new("UIListLayout") bl.Padding=UDim.new(0,7) bl.Parent=body bl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() body.CanvasSize=UDim2.fromOffset(0,bl.AbsoluteContentSize.Y+10) end)
local function clearBody() for _,x in ipairs(body:GetChildren()) do if x~=bl then x:Destroy() end end end
local function line(text,accent)
	local l=Instance.new("TextLabel") l.Size=UDim2.new(1,-4,0,42) l.BackgroundColor3=cardColor l.TextColor3=accent or textColor l.Font=Enum.Font.GothamMedium l.TextSize=13 l.TextXAlignment=Enum.TextXAlignment.Left l.TextWrapped=true l.Text="  "..text l.ZIndex=122 l.Parent=body corner(l,9)
end
collectionBtn.Activated:Connect(function()
	modal.Visible=true title.Text="🎒 COLEÇÃO DE ARTEFATOS" clearBody() local ok,s=pcall(function() return State:InvokeServer() end) if not ok or not s then line("Não foi possível carregar a coleção.") return end
	line("Inventário: "..#s.Inventory.."  ·  Em exposição: "..s.DisplayCount.."/"..s.Slots.."  ·  Descobertas: "..s.Discoveries,Color3.fromRGB(244,202,83))
	if #s.Inventory==0 then line("Nenhum artefato guardado. Minere nós de minério para encontrar relíquias.",muted) else for _,a in ipairs(s.Inventory) do line(a.Name.." · "..a.Rarity.." · +"..a.Prestige.." prestígio") end end
end)
progressBtn.Activated:Connect(function()
	modal.Visible=true title.Text="⭐ PROGRESSO DO IMPÉRIO" clearBody() local ok,s=pcall(function() return State:InvokeServer() end) if not ok or not s then return end
	line("Museu N"..s.Level.." · "..s.Stars.."★ · Prestígio "..s.Prestige,Color3.fromRGB(244,202,83)) line("Minérios quebrados: "..s.Mined.." · Visitas: "..s.Visits.." · Receita: $"..fmt(s.Revenue))
	if s.UpgradeCost then line("Próximo nível do museu: $"..fmt(s.UpgradeCost).." · use o terminal azul dentro do museu",Color3.fromRGB(105,180,240)) else line("Museu no nível máximo!",Color3.fromRGB(105,220,145)) end
	line((s.Missions.Mine10 and "✅" or "⬜").." Minere 10 minérios · recompensa $500") line((s.Missions.Display3 and "✅" or "⬜").." Exponha 3 artefatos · recompensa $750") line((s.Missions.Revenue5K and "✅" or "⬜").." Ganhe $5.000 no museu · recompensa $1.500")
end)

local toast=Instance.new("TextLabel") toast.AnchorPoint=Vector2.new(.5,0) toast.Position=UDim2.new(.5,0,0,68) toast.Size=UDim2.fromOffset(420,42) toast.BackgroundColor3=Color3.fromRGB(31,65,92) toast.TextColor3=Color3.new(1,1,1) toast.Font=Enum.Font.GothamBold toast.TextSize=13 toast.Visible=false toast.ZIndex=150 toast.Parent=gui corner(toast,11)
local toastId=0 Toast.OnClientEvent:Connect(function(message,kind) toastId+=1 local id=toastId toast.Text=tostring(message) toast.BackgroundTransparency=.04 toast.Visible=true if kind=="Warn" then toast.BackgroundColor3=Color3.fromRGB(122,61,55) elseif kind=="Artifact" then toast.BackgroundColor3=Color3.fromRGB(94,62,132) elseif kind=="Income" or kind=="Mission" then toast.BackgroundColor3=Color3.fromRGB(42,105,71) else toast.BackgroundColor3=Color3.fromRGB(31,65,92) end task.delay(2.5,function() if id~=toastId then return end TweenService:Create(toast,TweenInfo.new(.2),{BackgroundTransparency=1}):Play() task.wait(.22) if id==toastId then toast.Visible=false end end) end)

local function responsive()
	local cam=Workspace.CurrentCamera local w=cam and cam.ViewportSize.X or 900
	if w<760 then top.Size=UDim2.new(.94,0,0,46) dock.Size=UDim2.new(.96,0,0,50) for _,b in ipairs({mineBtn,museumBtn,collectionBtn,progressBtn}) do b.Size=UDim2.new(.24,-5,0,40) b.TextSize=10 end modal.Size=UDim2.new(.92,0,.64,0) else top.Size=UDim2.fromOffset(610,50) dock.Size=UDim2.fromOffset(500,54) modal.Size=UDim2.fromOffset(500,330) end
end
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(responsive) end Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.delay(.1,responsive) end) responsive()
print("[Mining Empire] Custom mobile-first UI online")
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] complete gameplay layer injected")
