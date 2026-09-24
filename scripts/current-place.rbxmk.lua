local outputPath = ...
assert(type(outputPath) == "string" and outputPath ~= "", "missing output path")

local place = Instance.new("DataModel")
place.Name = "Cidade de Investidores"
local workspace = place:GetService("Workspace")
local lighting = place:GetService("Lighting")
local players = place:GetService("Players")
local serverScripts = place:GetService("ServerScriptService")
local starterPlayer = place:GetService("StarterPlayer")
players.CharacterAutoLoads = true
lighting.Brightness, lighting.ClockTime = 2.5, 13.5
lighting.Ambient = Color3.fromRGB(145, 160, 185)
lighting.OutdoorAmbient = Color3.fromRGB(165, 175, 195)

local function part(name, size, position, color, material, parent)
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.Size, p.Position, p.Color = name, true, size, position, color
    p.Material, p.TopSurface, p.BottomSurface = material or "SmoothPlastic", "Smooth", "Smooth"
    p.Parent = parent or workspace
    return p
end

local world = Instance.new("Folder") world.Name = "InvestorCity" world.Parent = workspace
part("Ground", Vector3.new(520,2,520), Vector3.new(0,-1,0), Color3.fromRGB(82,151,77), "Grass", world)
part("MainRoad", Vector3.new(64,.6,500), Vector3.new(0,.2,0), Color3.fromRGB(48,51,57), "Asphalt", world)
part("CrossRoad", Vector3.new(500,.6,64), Vector3.new(0,.22,0), Color3.fromRGB(48,51,57), "Asphalt", world)
for _, x in ipairs({-38,38}) do part("Sidewalk",Vector3.new(11,1,500),Vector3.new(x,.5,0),Color3.fromRGB(188,191,195),"Concrete",world) end
for _, z in ipairs({-38,38}) do part("Sidewalk",Vector3.new(500,1,11),Vector3.new(0,.52,z),Color3.fromRGB(188,191,195),"Concrete",world) end
for n=-210,210,30 do
    part("LaneMark",Vector3.new(1.2,.08,13),Vector3.new(0,.55,n),Color3.fromRGB(245,205,65),"Neon",world)
    part("LaneMark",Vector3.new(13,.08,1.2),Vector3.new(n,.57,0),Color3.fromRGB(245,205,65),"Neon",world)
end

local spawn = Instance.new("SpawnLocation")
spawn.Name, spawn.Anchored, spawn.Neutral = "CitySpawn", true, true
spawn.Size, spawn.Position, spawn.Material, spawn.Color = Vector3.new(14,1,14), Vector3.new(0,1.2,55), "Neon", Color3.fromRGB(63,205,125)
spawn.Parent = world

local board = part("CityBoard",Vector3.new(46,13,2),Vector3.new(0,12,78),Color3.fromRGB(20,31,48),"SmoothPlastic",world)
local sg=Instance.new("SurfaceGui") sg.Face="Front" sg.CanvasSize=Vector2.new(1000,300) sg.Parent=board
local st=Instance.new("TextLabel") st.Size=UDim2.fromScale(1,1) st.BackgroundTransparency=1 st.Text="CIDADE DE INVESTIDORES\nCOMPRE • MELHORE • LUCRE" st.TextColor3=Color3.new(1,1,1) st.Font="GothamBlack" st.TextScaled=true st.Parent=sg

local folder=Instance.new("Folder") folder.Name="Properties" folder.Parent=world
local data={
    {"Casa Inicial",-115,105,500,25,Color3.fromRGB(82,175,235)},
    {"Loja de Bairro",115,105,1400,70,Color3.fromRGB(245,166,64)},
    {"Prédio Residencial",-115,-105,4200,210,Color3.fromRGB(170,116,235)},
    {"Supermercado",115,-105,9500,475,Color3.fromRGB(64,190,120)},
    {"Hotel Central",-205,0,24000,1200,Color3.fromRGB(238,205,91)},
    {"Arranha-céu",205,0,65000,3250,Color3.fromRGB(64,145,220)},
}

for index,d in ipairs(data) do
    local name,x,z,price,income,color=table.unpack(d)
    local model=Instance.new("Model") model.Name="Property"..index model.Parent=folder
    model:SetAttribute("Index",index) model:SetAttribute("DisplayName",name) model:SetAttribute("Price",price)
    model:SetAttribute("BaseIncome",income) model:SetAttribute("OwnerUserId",0) model:SetAttribute("Level",0)
    part("Plot",Vector3.new(68,1,68),Vector3.new(x,.6,z),Color3.fromRGB(111,183,98),"Grass",model)
    local height=12+index*5
    part("Building",Vector3.new(40,height,34),Vector3.new(x,1.1+height/2,z),color,"Concrete",model)
    part("Roof",Vector3.new(44,2,38),Vector3.new(x,2.1+height,z),Color3.fromRGB(42,50,64),"Metal",model)
    for floorIndex=1,math.max(1,math.floor(height/7)) do
        for _,dx in ipairs({-13,0,13}) do
            local w=part("Window",Vector3.new(7,3.5,.4),Vector3.new(x+dx,3+floorIndex*6,z+17.2),Color3.fromRGB(155,225,255),"Glass",model)
            w.Transparency=.18 w.CanCollide=false
        end
    end
    local pad=part("ActionPad",Vector3.new(15,1,15),Vector3.new(x,1.2,z+27),Color3.fromRGB(48,210,112),"Neon",model)
    local function prompt(promptName, action, object, key, duration)
        local p=Instance.new("ProximityPrompt") p.Name=promptName p.ActionText=action p.ObjectText=object
        p.KeyboardKeyCode=key p.HoldDuration=duration p.MaxActivationDistance=14 p.RequiresLineOfSight=false p.Parent=pad
        return p
    end
    prompt("BuyPrompt","Comprar imóvel",name.." · $"..price,"E",.35)
    local up=prompt("UpgradePrompt","Melhorar imóvel","Nível 1","R",.35) up.Enabled=false
    local sell=prompt("SellPrompt","Vender imóvel","Receber 70%","T",1.2) sell.Enabled=false
    local bg=Instance.new("BillboardGui") bg.Name="PropertyBillboard" bg.Size=UDim2.fromOffset(280,88) bg.StudsOffset=Vector3.new(0,5.5,0) bg.AlwaysOnTop=true bg.Parent=pad
    local label=Instance.new("TextLabel") label.Name="Label" label.Size=UDim2.fromScale(1,1) label.BackgroundColor3=Color3.fromRGB(17,24,36) label.BackgroundTransparency=.08
    label.TextColor3=Color3.new(1,1,1) label.Text=name.."\n$"..price.." • +$"..income.."/10s" label.Font="GothamBold" label.TextScaled=true label.TextWrapped=true label.Parent=bg
    local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,12) c.Parent=label
end

local server=Instance.new("Script") server.Name="InvestorCityServer"
server.Source=[=[
local Players=game:GetService("Players")
local DSS=game:GetService("DataStoreService")
local store=DSS:GetDataStore("InvestorCity_v1")
local models=workspace:WaitForChild("InvestorCity").Properties:GetChildren()
table.sort(models,function(a,b)return a:GetAttribute("Index")<b:GetAttribute("Index")end)
local profiles={}

local function stats(p)local s=p:FindFirstChild("leaderstats") return s,s and s:FindFirstChild("Cash"),s and s:FindFirstChild("Patrimonio"),s and s:FindFirstChild("Imoveis")end
local function refresh(m)
 local uid,level=m:GetAttribute("OwnerUserId") or 0,m:GetAttribute("Level") or 0
 local price,income=m:GetAttribute("Price"),m:GetAttribute("BaseIncome")
 local pad=m.ActionPad local buy,up,sell=pad.BuyPrompt,pad.UpgradePrompt,pad.SellPrompt
 buy.Enabled=uid==0 up.Enabled=uid~=0 and level<5 sell.Enabled=uid~=0
 if uid==0 then pad.Color=Color3.fromRGB(48,210,112) pad.PropertyBillboard.Label.Text=m:GetAttribute("DisplayName").."\n$"..price.." • +$"..income.."/10s"
 else local owner=Players:GetPlayerByUserId(uid) pad.Color=Color3.fromRGB(64,145,235)
  up.ObjectText="Nível "..level.." → "..(level+1).." · $"..math.floor(price*(.55+level*.25))
  pad.PropertyBillboard.Label.Text=m:GetAttribute("DisplayName").." · Nível "..level.."\nDono: "..(owner and owner.DisplayName or "Investidor").." • +$"..income*(level+1).."/10s" end
end
local function recalc(p)
 local profile=profiles[p] local _,_,worth,count=stats(p) if not profile or not worth then return end
 local total,owned,income=0,0,0
 for _,m in ipairs(models)do if m:GetAttribute("OwnerUserId")==p.UserId then local l=m:GetAttribute("Level") or 0 local price=m:GetAttribute("Price") total+=price+math.floor(price*.55*l) income+=m:GetAttribute("BaseIncome")*(l+1) owned+=1 end end
 profile.income=income worth.Value=total count.Value=owned p:SetAttribute("IncomePerCycle",income)
end
local function load(p)
 local profile={cash=1500,owned={}} local ok,saved=pcall(function()return store:GetAsync("p_"..p.UserId)end) if ok and type(saved)=="table"then profile=saved end
 profile.cash=tonumber(profile.cash)or 1500 profile.owned=type(profile.owned)=="table"and profile.owned or{} profiles[p]=profile
 local s=Instance.new("Folder")s.Name="leaderstats"s.Parent=p
 local cash=Instance.new("IntValue")cash.Name="Cash"cash.Value=profile.cash cash.Parent=s
 local worth=Instance.new("IntValue")worth.Name="Patrimonio"worth.Parent=s
 local count=Instance.new("IntValue")count.Name="Imoveis"count.Parent=s
 for text,l in pairs(profile.owned)do local m=models[tonumber(text)] if m and m:GetAttribute("OwnerUserId")==0 then m:SetAttribute("OwnerUserId",p.UserId)m:SetAttribute("Level",math.clamp(tonumber(l)or 0,0,5))refresh(m)end end recalc(p)
end
local function save(p)
 local profile=profiles[p] local _,cash=stats(p) if not profile or not cash then return end local owned={}
 for i,m in ipairs(models)do if m:GetAttribute("OwnerUserId")==p.UserId then owned[tostring(i)]=m:GetAttribute("Level")or 0 end end
 pcall(function()store:SetAsync("p_"..p.UserId,{cash=cash.Value,owned=owned})end)
end
Players.PlayerAdded:Connect(load) for _,p in ipairs(Players:GetPlayers())do task.spawn(load,p)end
for _,m in ipairs(models)do local pad=m.ActionPad
 pad.BuyPrompt.Triggered:Connect(function(p)if m:GetAttribute("OwnerUserId")~=0 then return end local _,cash=stats(p)local price=m:GetAttribute("Price")if not cash or cash.Value<price then p:SetAttribute("LastNotice","Dinheiro insuficiente")return end cash.Value-=price m:SetAttribute("OwnerUserId",p.UserId)refresh(m)recalc(p)p:SetAttribute("LastNotice","Imóvel comprado!")end)
 pad.UpgradePrompt.Triggered:Connect(function(p)if m:GetAttribute("OwnerUserId")~=p.UserId then p:SetAttribute("LastNotice","Este imóvel tem outro dono")return end local l=m:GetAttribute("Level")or 0 if l>=5 then return end local cost=math.floor(m:GetAttribute("Price")*(.55+l*.25))local _,cash=stats(p)if not cash or cash.Value<cost then p:SetAttribute("LastNotice","Dinheiro insuficiente")return end cash.Value-=cost m:SetAttribute("Level",l+1)refresh(m)recalc(p)p:SetAttribute("LastNotice","Imóvel melhorado!")end)
 pad.SellPrompt.Triggered:Connect(function(p)if m:GetAttribute("OwnerUserId")~=p.UserId then return end local l=m:GetAttribute("Level")or 0 local price=m:GetAttribute("Price")local refund=math.floor((price+price*.55*l)*.7)local _,cash=stats(p)cash.Value+=refund m:SetAttribute("OwnerUserId",0)m:SetAttribute("Level",0)refresh(m)recalc(p)p:SetAttribute("LastNotice","Vendido por $"..refund)end) refresh(m)
end
task.spawn(function()while true do task.wait(10)for p,profile in pairs(profiles)do local _,cash=stats(p)if cash and profile.income>0 then cash.Value+=profile.income end end end end)
Players.PlayerRemoving:Connect(function(p)save(p)for _,m in ipairs(models)do if m:GetAttribute("OwnerUserId")==p.UserId then m:SetAttribute("OwnerUserId",0)m:SetAttribute("Level",0)refresh(m)end end profiles[p]=nil end)
game:BindToClose(function()for p in pairs(profiles)do task.spawn(save,p)end task.wait(2)end)
]=] server.Parent=serverScripts

local scripts=starterPlayer:FindFirstChild("StarterPlayerScripts")or Instance.new("StarterPlayerScripts") scripts.Name="StarterPlayerScripts" scripts.Parent=starterPlayer
local client=Instance.new("LocalScript") client.Name="InvestorCityHUD"
client.Source=[=[
local Players=game:GetService("Players")local TweenService=game:GetService("TweenService")local p=Players.LocalPlayer
local gui=Instance.new("ScreenGui")gui.Name="InvestorCityHUD"gui.ResetOnSpawn=false gui.Parent=p:WaitForChild("PlayerGui")
local panel=Instance.new("Frame")panel.Position=UDim2.fromOffset(14,14)panel.Size=UDim2.fromOffset(300,142)panel.BackgroundColor3=Color3.fromRGB(15,24,38)panel.BackgroundTransparency=.05 panel.Parent=gui
local corner=Instance.new("UICorner")corner.CornerRadius=UDim.new(0,16)corner.Parent=panel
local function label(y,h,size,color)local x=Instance.new("TextLabel")x.Position=UDim2.fromOffset(16,y)x.Size=UDim2.new(1,-32,0,h)x.BackgroundTransparency=1 x.TextXAlignment="Left"x.Font="GothamBold"x.TextSize=size x.TextColor3=color x.Parent=panel return x end
local title=label(9,25,18,Color3.fromRGB(105,184,255))title.Text="CIDADE DE INVESTIDORES"
local money=label(40,27,21,Color3.fromRGB(92,235,145))local income=label(70,20,15,Color3.fromRGB(150,220,175))local assets=label(94,20,14,Color3.fromRGB(230,235,245))local owned=label(116,18,14,Color3.fromRGB(230,235,245))
local objective=Instance.new("TextLabel")objective.AnchorPoint=Vector2.new(.5,1)objective.Position=UDim2.new(.5,0,1,-18)objective.Size=UDim2.new(.88,0,0,54)objective.BackgroundColor3=Color3.fromRGB(15,24,38)objective.BackgroundTransparency=.06 objective.TextColor3=Color3.new(1,1,1)objective.Font="GothamBold"objective.TextSize=15 objective.TextWrapped=true objective.Text="Comece comprando a Casa Inicial. A renda entra a cada 10 segundos."objective.Parent=gui
local oc=Instance.new("UICorner")oc.CornerRadius=UDim.new(0,14)oc.Parent=objective
local notice=Instance.new("TextLabel")notice.AnchorPoint=Vector2.new(.5,0)notice.Position=UDim2.new(.5,0,0,18)notice.Size=UDim2.new(.7,0,0,48)notice.BackgroundColor3=Color3.fromRGB(25,37,56)notice.BackgroundTransparency=1 notice.TextTransparency=1 notice.TextColor3=Color3.new(1,1,1)notice.Font="GothamBold"notice.TextSize=16 notice.Parent=gui
local nc=Instance.new("UICorner")nc.CornerRadius=UDim.new(0,14)nc.Parent=notice
local s=p:WaitForChild("leaderstats")local cash=s:WaitForChild("Cash")local worth=s:WaitForChild("Patrimonio")local count=s:WaitForChild("Imoveis")
local function update()money.Text="$ "..cash.Value income.Text="+$"..(p:GetAttribute("IncomePerCycle")or 0).." a cada 10s"assets.Text="Patrimônio: $"..worth.Value owned.Text="Imóveis: "..count.Value.."/6"end
for _,v in ipairs({cash,worth,count})do v:GetPropertyChangedSignal("Value"):Connect(update)end p:GetAttributeChangedSignal("IncomePerCycle"):Connect(update)
p:GetAttributeChangedSignal("LastNotice"):Connect(function()notice.Text=p:GetAttribute("LastNotice")or""TweenService:Create(notice,TweenInfo.new(.2),{BackgroundTransparency=.08,TextTransparency=0}):Play()task.wait(2.4)TweenService:Create(notice,TweenInfo.new(.35),{BackgroundTransparency=1,TextTransparency=1}):Play()end)update()
]=] client.Parent=scripts

fs.write(outputPath,place)
print("[Cidade de Investidores] playable city prepared")
