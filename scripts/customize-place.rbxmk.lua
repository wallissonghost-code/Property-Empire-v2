local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)

local function replaceBrand(text)
	if type(text) ~= "string" then return text, false end
	local original = text
	text = text:gsub("Miner's Haven", "Mining Empire")
	text = text:gsub("Miners Haven", "Mining Empire")
	text = text:gsub("Miner’s Haven", "Mining Empire")
	text = text:gsub("MINER'S HAVEN", "MINING EMPIRE")
	text = text:gsub("MINERS HAVEN", "MINING EMPIRE")
	return text, text ~= original
end

local renamedText = 0
local removedLegacy = 0
for _, instance in ipairs(place:GetDescendants()) do
	local className = instance.ClassName
	if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
		local text = instance.Text
		if type(text) == "string" then
			local nextText, changed = replaceBrand(text)
			if changed then
				instance.Text = nextText
				renamedText = renamedText + 1
			end
		end
	end
end

local serverScriptService = place:GetService("ServerScriptService")
local starterPlayer = place:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

for _, instance in ipairs(serverScriptService:GetDescendants()) do
	local n = string.lower(instance.Name or "")
	if n == "analytics" or n == "gameanalytics" or n == "chatads" or n == "adminhunter" then
		instance:Destroy()
		removedLegacy = removedLegacy + 1
	end
end

local oldServer = serverScriptService:FindFirstChild("MiningEmpireMuseumBootstrap")
if oldServer then oldServer:Destroy() end
local oldClient = starterPlayerScripts:FindFirstChild("MiningEmpireTravelUI")
if oldClient then oldClient:Destroy() end

local server = Instance.new("Script")
server.Name = "MiningEmpireMuseumBootstrap"
server.Source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local STORE = DataStoreService:GetDataStore("MiningEmpireArtifacts_v1")
local DISTRICT_ORIGIN = Vector3.new(0, 22, -1500)
local MAX_INVENTORY = 50
local DISCOVERY_INTERVAL = 30
local DISCOVERY_CHANCE = 0.42

local ARTIFACTS = {
	{Id="FossilShard", Name="Fragmento Fóssil", Rarity="Comum", Weight=36, Prestige=2, Color=Color3.fromRGB(151,123,91), Shape=Enum.PartType.Block},
	{Id="AncientCoin", Name="Moeda Antiga", Rarity="Comum", Weight=26, Prestige=3, Color=Color3.fromRGB(194,158,72), Shape=Enum.PartType.Cylinder},
	{Id="CrystalCore", Name="Núcleo de Cristal", Rarity="Raro", Weight=17, Prestige=8, Color=Color3.fromRGB(82,178,220), Shape=Enum.PartType.Ball},
	{Id="DinoRelic", Name="Relíquia Pré-Histórica", Rarity="Raro", Weight=10, Prestige=12, Color=Color3.fromRGB(126,164,91), Shape=Enum.PartType.Block},
	{Id="RoyalGem", Name="Joia Real", Rarity="Épico", Weight=6, Prestige=25, Color=Color3.fromRGB(158,91,220), Shape=Enum.PartType.Ball},
	{Id="MeteorFragment", Name="Fragmento de Meteorito", Rarity="Épico", Weight=3, Prestige=35, Color=Color3.fromRGB(91,101,122), Shape=Enum.PartType.Block},
	{Id="GoldenIdol", Name="Ídolo Dourado", Rarity="Lendário", Weight=1.5, Prestige=70, Color=Color3.fromRGB(245,197,66), Shape=Enum.PartType.Block},
	{Id="VoidCrystal", Name="Cristal do Vazio", Rarity="Mítico", Weight=0.5, Prestige=140, Color=Color3.fromRGB(71,41,111), Shape=Enum.PartType.Ball},
}
local byId = {}
for _, a in ipairs(ARTIFACTS) do byId[a.Id] = a end

local remotes = ReplicatedStorage:FindFirstChild("MiningEmpireRemotes") or Instance.new("Folder")
remotes.Name = "MiningEmpireRemotes"
remotes.Parent = ReplicatedStorage
local travel = remotes:FindFirstChild("Travel") or Instance.new("RemoteEvent")
travel.Name = "Travel" travel.Parent = remotes
local foundEvent = remotes:FindFirstChild("ArtifactFound") or Instance.new("RemoteEvent")
foundEvent.Name = "ArtifactFound" foundEvent.Parent = remotes
local stateFn = remotes:FindFirstChild("ArtifactState") or Instance.new("RemoteFunction")
stateFn.Name = "ArtifactState" stateFn.Parent = remotes

local profiles = {}
local previousPositions = {}
local inMine = {}

local function defaultProfile()
	return {Inventory={}, Display={}, Discoveries=0}
end
local function reconcile(data)
	if type(data) ~= "table" then data = defaultProfile() end
	if type(data.Inventory) ~= "table" then data.Inventory = {} end
	if type(data.Display) ~= "table" then data.Display = {} end
	data.Discoveries = tonumber(data.Discoveries) or 0
	return data
end
local function save(player)
	local data = profiles[player]
	if not data then return end
	pcall(function() STORE:SetAsync("u"..player.UserId, data) end)
end
local function load(player)
	local data
	pcall(function() data = STORE:GetAsync("u"..player.UserId) end)
	profiles[player] = reconcile(data)
	inMine[player] = true
end
local function totalPrestige(data)
	local total = 0
	for _, id in pairs(data.Display) do
		local a = byId[id]
		if a then total += a.Prestige end
	end
	return total
end
local function countDisplay(data)
	local n=0 for _,id in pairs(data.Display) do if id then n+=1 end end return n
end
local function publicState(player)
	local d=profiles[player] or defaultProfile()
	local inv={}
	for _,id in ipairs(d.Inventory) do
		local a=byId[id]
		if a then table.insert(inv,{Id=a.Id,Name=a.Name,Rarity=a.Rarity,Prestige=a.Prestige}) end
	end
	return {Inventory=inv, InventoryCount=#d.Inventory, DisplayCount=countDisplay(d), Prestige=totalPrestige(d), Discoveries=d.Discoveries}
end
stateFn.OnServerInvoke=function(player) return publicState(player) end

local function rollArtifact()
	local total=0 for _,a in ipairs(ARTIFACTS) do total+=a.Weight end
	local r=math.random()*total
	local c=0
	for _,a in ipairs(ARTIFACTS) do c+=a.Weight if r<=c then return a end end
	return ARTIFACTS[1]
end
local function discover(player)
	local d=profiles[player]
	if not d or #d.Inventory>=MAX_INVENTORY then return end
	local a=rollArtifact()
	table.insert(d.Inventory,a.Id)
	d.Discoveries+=1
	player:SetAttribute("MuseumPrestige",totalPrestige(d))
	player:SetAttribute("ArtifactCount",#d.Inventory+countDisplay(d))
	foundEvent:FireClient(player,{Name=a.Name,Rarity=a.Rarity,Prestige=a.Prestige})
end

local old = workspace:FindFirstChild("MiningEmpireMuseumDistrict")
if old then old:Destroy() end
local museum = Instance.new("Model") museum.Name="MiningEmpireMuseumDistrict" museum.Parent=workspace
local function part(name,size,cf,material,color)
	local p=Instance.new("Part") p.Name=name p.Anchored=true p.Size=size p.CFrame=cf p.Material=material or Enum.Material.SmoothPlastic p.Color=color or Color3.fromRGB(220,224,230) p.Parent=museum return p
end
part("MuseumFloor",Vector3.new(140,2,96),CFrame.new(DISTRICT_ORIGIN),Enum.Material.Marble,Color3.fromRGB(225,225,220))
part("BackWall",Vector3.new(140,28,2),CFrame.new(DISTRICT_ORIGIN+Vector3.new(0,15,-47)),Enum.Material.Concrete,Color3.fromRGB(32,38,48))
part("LeftWall",Vector3.new(2,28,96),CFrame.new(DISTRICT_ORIGIN+Vector3.new(-69,15,0)),Enum.Material.Concrete,Color3.fromRGB(32,38,48))
part("RightWall",Vector3.new(2,28,96),CFrame.new(DISTRICT_ORIGIN+Vector3.new(69,15,0)),Enum.Material.Concrete,Color3.fromRGB(32,38,48))
local sign=part("MuseumSign",Vector3.new(48,8,2),CFrame.new(DISTRICT_ORIGIN+Vector3.new(0,18,46)),Enum.Material.Metal,Color3.fromRGB(24,30,40))
local sg=Instance.new("SurfaceGui") sg.Face=Enum.NormalId.Front sg.Parent=sign
local sl=Instance.new("TextLabel") sl.Size=UDim2.fromScale(1,1) sl.BackgroundTransparency=1 sl.Text="MINING EMPIRE · MUSEU" sl.TextColor3=Color3.fromRGB(245,205,92) sl.Font=Enum.Font.GothamBold sl.TextScaled=true sl.Parent=sg
local arrival=part("ArrivalPad",Vector3.new(18,1,12),CFrame.new(DISTRICT_ORIGIN+Vector3.new(0,2,36)),Enum.Material.Neon,Color3.fromRGB(64,142,222))

local pedestals={}
local function renderSlot(player,slot)
	local pedestal=pedestals[slot]
	if not pedestal then return end
	local existing=pedestal:FindFirstChild("DisplayedArtifact") if existing then existing:Destroy() end
	local prompt=pedestal:FindFirstChildOfClass("ProximityPrompt")
	local d=profiles[player]
	local id=d and d.Display[tostring(slot)]
	if id then
		local a=byId[id]
		if a then
			local obj=Instance.new("Part") obj.Name="DisplayedArtifact" obj.Anchored=true obj.CanCollide=false obj.Shape=a.Shape obj.Size=Vector3.new(4,4,4) obj.Color=a.Color obj.Material=(a.Rarity=="Lendário" or a.Rarity=="Mítico") and Enum.Material.Neon or Enum.Material.SmoothPlastic obj.CFrame=pedestal.CFrame*CFrame.new(0,4,0) obj.Parent=pedestal
			local bill=Instance.new("BillboardGui") bill.Size=UDim2.fromOffset(180,44) bill.StudsOffset=Vector3.new(0,3.5,0) bill.AlwaysOnTop=true bill.Parent=obj
			local t=Instance.new("TextLabel") t.Size=UDim2.fromScale(1,1) t.BackgroundTransparency=.25 t.BackgroundColor3=Color3.fromRGB(15,18,24) t.TextColor3=Color3.new(1,1,1) t.Font=Enum.Font.GothamBold t.TextScaled=true t.Text=a.Name.." · "..a.Rarity t.Parent=bill
			if prompt then prompt.ActionText="GUARDAR" prompt.ObjectText=a.Name end
		end
	else
		if prompt then prompt.ActionText="EXPOR" prompt.ObjectText="Vitrine vazia" end
	end
end
for i=1,8 do
	local col=((i-1)%4)-1.5 local row=math.floor((i-1)/4)
	local p=part("ArtifactPedestal_"..i,Vector3.new(10,4,10),CFrame.new(DISTRICT_ORIGIN+Vector3.new(col*27,3,-8+row*28)),Enum.Material.Marble,Color3.fromRGB(242,242,238))
	pedestals[i]=p
	local prompt=Instance.new("ProximityPrompt") prompt.MaxActivationDistance=10 prompt.HoldDuration=.25 prompt.ActionText="EXPOR" prompt.ObjectText="Vitrine vazia" prompt.Parent=p
	prompt.Triggered:Connect(function(player)
		local d=profiles[player] if not d then return end
		local key=tostring(i)
		if d.Display[key] then
			table.insert(d.Inventory,d.Display[key]) d.Display[key]=nil
		elseif #d.Inventory>0 then
			d.Display[key]=table.remove(d.Inventory,1)
		else return end
		player:SetAttribute("MuseumPrestige",totalPrestige(d))
		player:SetAttribute("ArtifactCount",#d.Inventory+countDisplay(d))
		renderSlot(player,i)
	end)
end

travel.OnServerEvent:Connect(function(player,destination)
	local character=player.Character if not character then return end
	if destination=="Museum" then
		previousPositions[player.UserId]=character:GetPivot() inMine[player]=false
		character:PivotTo(CFrame.new(DISTRICT_ORIGIN+Vector3.new(0,6,32)))
		for i=1,8 do renderSlot(player,i) end
	elseif destination=="Mine" then
		inMine[player]=true local previous=previousPositions[player.UserId]
		if previous then character:PivotTo(previous) end
	end
end)

Players.PlayerAdded:Connect(function(player)
	load(player)
	local d=profiles[player]
	player:SetAttribute("MuseumPrestige",totalPrestige(d))
	player:SetAttribute("ArtifactCount",#d.Inventory+countDisplay(d))
end)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(load,p) end
Players.PlayerRemoving:Connect(function(player) save(player) profiles[player]=nil inMine[player]=nil previousPositions[player.UserId]=nil end)
game:BindToClose(function() for _,p in ipairs(Players:GetPlayers()) do save(p) end end)

task.spawn(function()
	while task.wait(DISCOVERY_INTERVAL) do
		for _,player in ipairs(Players:GetPlayers()) do
			if inMine[player] and math.random()<DISCOVERY_CHANCE then discover(player) end
		end
	end
end)
print("[Mining Empire] Mining -> artifacts -> museum loop online")
]=]
server.Parent = serverScriptService

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireTravelUI"
client.Source = [=[
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local remotes=ReplicatedStorage:WaitForChild("MiningEmpireRemotes")
local travel=remotes:WaitForChild("Travel")
local found=remotes:WaitForChild("ArtifactFound")
local getState=remotes:WaitForChild("ArtifactState")
local gui=Instance.new("ScreenGui") gui.Name="MiningEmpireTravelUI" gui.ResetOnSpawn=false gui.DisplayOrder=15 gui.Parent=player:WaitForChild("PlayerGui")
local frame=Instance.new("Frame") frame.AnchorPoint=Vector2.new(.5,0) frame.Position=UDim2.new(.5,0,0,12) frame.Size=UDim2.fromOffset(370,46) frame.BackgroundColor3=Color3.fromRGB(18,23,31) frame.BackgroundTransparency=.08 frame.Parent=gui Instance.new("UICorner",frame).CornerRadius=UDim.new(0,13)
local layout=Instance.new("UIListLayout") layout.FillDirection=Enum.FillDirection.Horizontal layout.HorizontalAlignment=Enum.HorizontalAlignment.Center layout.VerticalAlignment=Enum.VerticalAlignment.Center layout.Padding=UDim.new(0,6) layout.Parent=frame
local function button(text,destination,color)
	local b=Instance.new("TextButton") b.Size=UDim2.fromOffset(92,36) b.BackgroundColor3=color b.TextColor3=Color3.new(1,1,1) b.Font=Enum.Font.GothamBold b.TextSize=11 b.Text=text b.Parent=frame Instance.new("UICorner",b).CornerRadius=UDim.new(0,10) b.Activated:Connect(function() travel:FireServer(destination) end)
end
button("⛏ MINA","Mine",Color3.fromRGB(91,72,49)) button("🏛 MUSEU","Museum",Color3.fromRGB(48,83,122))
local status=Instance.new("TextLabel") status.Size=UDim2.fromOffset(168,36) status.BackgroundTransparency=1 status.TextColor3=Color3.fromRGB(240,215,128) status.Font=Enum.Font.GothamBold status.TextSize=10 status.TextWrapped=true status.Parent=frame
local function refresh()
	local ok,s=pcall(function() return getState:InvokeServer() end)
	if ok and s then status.Text=string.format("🎒 %d  🏺 %d  ★ %d",s.InventoryCount or 0,s.DisplayCount or 0,s.Prestige or 0) end
end
local toast=Instance.new("TextLabel") toast.AnchorPoint=Vector2.new(.5,0) toast.Position=UDim2.new(.5,0,0,66) toast.Size=UDim2.fromOffset(330,48) toast.BackgroundColor3=Color3.fromRGB(21,27,36) toast.BackgroundTransparency=.05 toast.TextColor3=Color3.new(1,1,1) toast.Font=Enum.Font.GothamBold toast.TextSize=13 toast.Visible=false toast.Parent=gui Instance.new("UICorner",toast).CornerRadius=UDim.new(0,12)
found.OnClientEvent:Connect(function(a) toast.Text="⛏ RELÍQUIA ENCONTRADA: "..a.Name.." ["..a.Rarity.."]  +"..a.Prestige.." prestígio" toast.Visible=true refresh() task.delay(4,function() toast.Visible=false end) end)
player:GetAttributeChangedSignal("MuseumPrestige"):Connect(refresh) player:GetAttributeChangedSignal("ArtifactCount"):Connect(refresh)
task.defer(refresh)
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print(string.format("[Mining Empire] customized place: text=%d legacy_removed=%d", renamedText, removedLegacy))
