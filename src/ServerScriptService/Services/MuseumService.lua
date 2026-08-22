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

local function makePart(parent,name,size,cf,color,material,transparency)
	local p = Instance.new("Part")
	p.Name=name p.Size=size p.CFrame=cf p.Anchored=true p.Color=color p.Material=material or Enum.Material.SmoothPlastic p.Transparency=transparency or 0 p.Parent=parent
	p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
	return p
end

local function findArtifact(profile, uid)
	for i,a in ipairs(profile.Artifacts) do if a.Uid == uid then return a,i end end
end

local function capacity(profile)
	return MuseumConfig.DisplaySlots[profile.Museum.Level] or 4
end

local function occupied(profile)
	local used = {}
	for _,a in ipairs(profile.Artifacts) do if a.Location == "Display" and a.Slot then used[a.Slot]=true end end
	return used
end

local function dto(a)
	local spec = Catalog.Get(a.CatalogId)
	return {
		Uid=a.Uid, CatalogId=a.CatalogId, Name=spec.Name, Rarity=spec.Rarity, BaseValue=spec.Value, Prestige=spec.Prestige,
		Location=a.Location or "Inventory", Slot=a.Slot, ForSale=a.ForSale==true, Price=math.floor(tonumber(a.Price) or spec.Value), AcquiredAt=a.AcquiredAt or 0,
	}
end

function MuseumService:GetScore(player)
	local p = dataService:Get(player)
	if not p then return 0 end
	local score = MuseumConfig.LevelScore[p.Museum.Level] or 0
	for _,a in ipairs(p.Artifacts) do
		if a.Location == "Display" then local s=Catalog.Get(a.CatalogId) if s then score += s.Prestige end end
	end
	return score
end

local function assignSlot(player)
	if playerSlots[player] then return playerSlots[player] end
	for i=1,#worldService:GetSlots() do
		if not slotOwners[i] then slotOwners[i]=player playerSlots[player]=i return i end
	end
end

local function addBillboard(part, text, size)
	local gui=Instance.new("BillboardGui") gui.Size=UDim2.fromOffset(size or 230,60) gui.StudsOffset=Vector3.new(0,3,0) gui.AlwaysOnTop=false gui.MaxDistance=80 gui.Parent=part
	local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=0.2 label.BackgroundColor3=Color3.fromRGB(18,20,24) label.TextColor3=Color3.new(1,1,1) label.TextWrapped=true label.TextScaled=true label.Font=Enum.Font.GothamBold label.Text=text label.Parent=gui
	return label
end

function MuseumService:Render(player)
	local profile=dataService:Get(player) if not profile then return end
	local slot=assignSlot(player) if not slot then return end
	if models[player] then models[player]:Destroy() end
	local base=worldService:GetSlots()[slot]
	local model=Instance.new("Model") model.Name="Museum_"..player.UserId model.Parent=worldService:GetWorld() models[player]=model
	local level=profile.Museum.Level
	local width=54+level*9 local depth=42+level*7
	makePart(model,"Floor",Vector3.new(width,1,depth),base*CFrame.new(0,0.6,0),Color3.fromRGB(214,211,202),Enum.Material.Marble)
	makePart(model,"BackWall",Vector3.new(width,14,1),base*CFrame.new(0,7,-depth/2),Color3.fromRGB(235,233,226),Enum.Material.SmoothPlastic)
	makePart(model,"LeftWall",Vector3.new(1,14,depth),base*CFrame.new(-width/2,7,0),Color3.fromRGB(235,233,226),Enum.Material.SmoothPlastic)
	makePart(model,"RightWall",Vector3.new(1,14,depth),base*CFrame.new(width/2,7,0),Color3.fromRGB(235,233,226),Enum.Material.SmoothPlastic)
	local sign=makePart(model,"MuseumSign",Vector3.new(18,4,1),base*CFrame.new(0,5,depth/2-1),Color3.fromRGB(28,31,37),Enum.Material.Metal)
	addBillboard(sign,string.format("%s\nMUSEU · NÍVEL %d · PRESTÍGIO %d",player.DisplayName,level,self:GetScore(player)),280)
	local terminal=makePart(model,"Terminal",Vector3.new(4,4,2),base*CFrame.new(0,2.5,depth/2+3),Color3.fromRGB(51,93,100),Enum.Material.Metal)
	local terminalPrompt=Instance.new("ProximityPrompt") terminalPrompt.ActionText="Gerenciar museu" terminalPrompt.ObjectText=player.DisplayName terminalPrompt.MaxActivationDistance=10 terminalPrompt.HoldDuration=0.15 terminalPrompt.Parent=terminal
	terminalPrompt.Triggered:Connect(function(who) remotes.OpenMuseumUI:FireClient(who,player.UserId) end)

	local cap=capacity(profile)
	local cols=math.ceil(math.sqrt(cap))
	local spacingX=math.min(12,(width-12)/math.max(1,cols-1))
	local rows=math.ceil(cap/cols)
	local spacingZ=math.min(11,(depth-12)/math.max(1,rows))
	for i=1,cap do
		local col=(i-1)%cols local row=math.floor((i-1)/cols)
		local x=(col-(cols-1)/2)*spacingX local z=-depth/2+7+row*spacingZ
		local stand=makePart(model,"DisplayStand"..i,Vector3.new(5,2,5),base*CFrame.new(x,1.5,z),Color3.fromRGB(50,53,58),Enum.Material.Metal)
		local artifact
		for _,a in ipairs(profile.Artifacts) do if a.Location=="Display" and a.Slot==i then artifact=a break end end
		if artifact then
			local spec=Catalog.Get(artifact.CatalogId)
			local item=makePart(model,"Artifact_"..artifact.Uid,Vector3.new(2.2,2.2,2.2),stand.CFrame*CFrame.new(0,2.1,0),spec.Color,spec.Material)
			item.Shape=Enum.PartType.Ball
			local sale=artifact.ForSale and string.format("À VENDA · $%d",artifact.Price or spec.Value) or "BLOQUEADO"
			addBillboard(item,string.format("%s\n%s · PRESTÍGIO %d\n%s",spec.Name,spec.Rarity,spec.Prestige,sale),220)
			local prompt=Instance.new("ProximityPrompt") prompt.ActionText=artifact.ForSale and "Ver oferta" or "Ver peça" prompt.ObjectText=spec.Name prompt.MaxActivationDistance=9 prompt.HoldDuration=0.1 prompt.Parent=stand
			prompt.Triggered:Connect(function(who) remotes.OpenMuseumUI:FireClient(who,player.UserId,artifact.Uid) end)
		end
	end
end

function MuseumService:GetState(requester,targetUserId)
	local target=Players:GetPlayerByUserId(tonumber(targetUserId) or requester.UserId)
	if not target then return {Ok=false,Error="O dono deste museu não está neste servidor"} end
	local p=dataService:Get(target) if not p then return {Ok=false,Error="Museu carregando"} end
	local isOwner=target==requester
	local items={}
	for _,a in ipairs(p.Artifacts) do if isOwner or a.Location=="Display" then table.insert(items,dto(a)) end end
	table.sort(items,function(a,b) if a.Location~=b.Location then return a.Location=="Display" end return a.BaseValue>b.BaseValue end)
	return {Ok=true,IsOwner=isOwner,OwnerUserId=target.UserId,OwnerName=target.DisplayName,Cash=requester:GetAttribute("Cash") or 0,Level=p.Museum.Level,Capacity=capacity(p),Score=self:GetScore(target),Artifacts=items,Stats=p.Stats,UpgradeCost=MuseumConfig.UpgradeCosts[p.Museum.Level+1]}
end

function MuseumService:AddArtifact(player,catalogId)
	local p=dataService:Get(player) if not p or #p.Artifacts>=GameConfig.MaxArtifacts then return false,"Inventário cheio" end
	local spec=Catalog.Get(catalogId) if not spec then return false,"Item inválido" end
	table.insert(p.Artifacts,{Uid=HttpService:GenerateGUID(false),CatalogId=catalogId,Location="Inventory",ForSale=false,Price=spec.Value,AcquiredAt=os.time()})
	return true
end

function MuseumService:AwardVisit(player,revenue)
	local p=dataService:Get(player) if not p then return end
	dataService:AdjustCash(player,revenue) p.Stats.Visits+=1 p.Stats.VisitorRevenue+=revenue
end

function MuseumService:GetMuseumInfo(player)
	local model=models[player] local p=dataService:Get(player) if not model or not p then return nil end
	local floor=model:FindFirstChild("Floor") if not floor then return nil end
	return {Model=model,Score=self:GetScore(player),Level=p.Museum.Level,Entrance=floor.CFrame*CFrame.new(0,2,floor.Size.Z/2+8),Inside=floor.CFrame*CFrame.new(0,2,0),Exit=floor.CFrame*CFrame.new(0,2,floor.Size.Z/2+14)}
end

function MuseumService:GetOwners()
	local result={} for p in pairs(models) do if p.Parent then table.insert(result,p) end end return result
end

function MuseumService:Action(player,payload)
	if type(payload)~="table" then return {Ok=false,Error="Ação inválida"} end
	local profile=dataService:Get(player) if not profile then return {Ok=false,Error="Dados carregando"} end
	local action=payload.Action
	if action=="Place" then
		local a=findArtifact(profile,payload.Uid) if not a or a.Location~="Inventory" then return {Ok=false,Error="Peça indisponível"} end
		local used=occupied(profile) local slot for i=1,capacity(profile) do if not used[i] then slot=i break end end
		if not slot then return {Ok=false,Error="Museu sem vitrines livres"} end
		a.Location="Display" a.Slot=slot a.ForSale=false self:Render(player)
	elseif action=="Store" then
		local a=findArtifact(profile,payload.Uid) if not a or a.Location~="Display" then return {Ok=false,Error="Peça indisponível"} end
		a.Location="Inventory" a.Slot=nil a.ForSale=false self:Render(player)
	elseif action=="ToggleSale" then
		local a=findArtifact(profile,payload.Uid) if not a or a.Location~="Display" then return {Ok=false,Error="A peça precisa estar exposta"} end
		a.ForSale=not a.ForSale self:Render(player)
	elseif action=="SetPrice" then
		local a=findArtifact(profile,payload.Uid) if not a or a.Location~="Display" then return {Ok=false,Error="Peça indisponível"} end
		a.Price=math.clamp(math.floor(tonumber(payload.Price) or a.Price or 1),GameConfig.SalePriceMin,GameConfig.SalePriceMax) self:Render(player)
	elseif action=="Upgrade" then
		if profile.Museum.Level>=MuseumConfig.MaxLevel then return {Ok=false,Error="Museu já está no nível máximo"} end
		local cost=MuseumConfig.UpgradeCosts[profile.Museum.Level+1] or 0
		if not dataService:AdjustCash(player,-cost) then return {Ok=false,Error="Dinheiro insuficiente"} end
		profile.Museum.Level+=1 self:Render(player)
	elseif action=="Buy" then
		local seller=Players:GetPlayerByUserId(tonumber(payload.SellerUserId) or 0)
		if not seller or seller==player then return {Ok=false,Error="Venda inválida"} end
		local sellerProfile=dataService:Get(seller) if not sellerProfile then return {Ok=false,Error="Vendedor indisponível"} end
		local item,index=findArtifact(sellerProfile,payload.Uid)
		if not item or item.Location~="Display" or not item.ForSale then return {Ok=false,Error="Esta peça não está à venda"} end
		if #profile.Artifacts>=GameConfig.MaxArtifacts then return {Ok=false,Error="Seu inventário está cheio"} end
		local price=math.clamp(math.floor(tonumber(item.Price) or 1),GameConfig.SalePriceMin,GameConfig.SalePriceMax)
		if not dataService:AdjustCash(player,-price) then return {Ok=false,Error="Dinheiro insuficiente"} end
		dataService:AdjustCash(seller,price)
		table.remove(sellerProfile.Artifacts,index) item.Location="Inventory" item.Slot=nil item.ForSale=false item.Price=Catalog.Get(item.CatalogId).Value table.insert(profile.Artifacts,item)
		profile.Stats.Purchases+=1 sellerProfile.Stats.Sales+=1
		self:Render(seller)
		local ok1=dataService:Save(seller) local ok2=dataService:Save(player)
		if not ok1 or not ok2 then warn("[Museum Empire] P2P save warning; in-memory transaction remains authoritative this session") end
		remotes.MuseumToast:FireClient(seller,string.format("%s comprou uma peça por $%d",player.DisplayName,price))
		return {Ok=true,Message="Peça comprada e enviada ao seu inventário"}
	else return {Ok=false,Error="Ação desconhecida"} end
	dataService:Save(player)
	return {Ok=true,Message="Museu atualizado"}
end

function MuseumService:Start(ds,ws)
	if started then return end started=true dataService=ds worldService=ws
	remotes=ReplicatedStorage:FindFirstChild("MuseumRemotes") or Instance.new("Folder") remotes.Name="MuseumRemotes" remotes.Parent=ReplicatedStorage
	local function remote(class,name) local r=remotes:FindFirstChild(name) or Instance.new(class) r.Name=name r.Parent=remotes remotes[name]=r return r end
	remote("RemoteEvent","OpenMuseumUI") remote("RemoteEvent","MuseumToast")
	local get=remote("RemoteFunction","GetMuseumState") get.OnServerInvoke=function(p,target) return self:GetState(p,target) end
	local act=remote("RemoteFunction","MuseumAction") act.OnServerInvoke=function(p,payload) return self:Action(p,payload) end
	local function setup(p) task.spawn(function() if ds:Wait(p,15) then self:Render(p) end end) end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(p) if models[p] then models[p]:Destroy() models[p]=nil end local s=playerSlots[p] if s then slotOwners[s]=nil playerSlots[p]=nil end end)
	for _,p in ipairs(Players:GetPlayers()) do setup(p) end
	print("[Museum Empire] MuseumService started")
end

return MuseumService
