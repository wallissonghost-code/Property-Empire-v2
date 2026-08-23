local PremiumMuseumService = {}
local started = false

local PRESETS = {
	[1] = {Name="Galeria Boutique", Wall=Color3.fromRGB(240,239,234), Accent=Color3.fromRGB(39,45,53), Glass=Color3.fromRGB(169,216,231), Stone=Color3.fromRGB(205,202,194), Columns=2, Dividers=1},
	[2] = {Name="Museu Metropolitano", Wall=Color3.fromRGB(233,232,227), Accent=Color3.fromRGB(34,42,52), Glass=Color3.fromRGB(154,207,226), Stone=Color3.fromRGB(194,192,186), Columns=4, Dividers=2},
	[3] = {Name="Museu Prestige", Wall=Color3.fromRGB(244,241,232), Accent=Color3.fromRGB(91,73,43), Glass=Color3.fromRGB(178,220,229), Stone=Color3.fromRGB(218,211,194), Columns=4, Dividers=3},
	[4] = {Name="Grand Museum", Wall=Color3.fromRGB(227,226,222), Accent=Color3.fromRGB(31,34,39), Glass=Color3.fromRGB(144,194,214), Stone=Color3.fromRGB(188,187,181), Columns=6, Dividers=4},
	[5] = {Name="Museum Empire", Wall=Color3.fromRGB(237,235,230), Accent=Color3.fromRGB(19,22,27), Glass=Color3.fromRGB(128,188,214), Stone=Color3.fromRGB(202,199,190), Columns=8, Dividers=5},
}

local function make(parent,name,size,cf,color,material,transparency,itemId)
	local p=Instance.new("Part")
	p.Name=name p.Size=size p.CFrame=cf p.Anchored=true p.CanCollide=true
	p.Color=color p.Material=material or Enum.Material.SmoothPlastic p.Transparency=transparency or 0
	p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
	p:SetAttribute("PremiumPreset",true) p:SetAttribute("PresetEditable",true)
	if itemId then p:SetAttribute("BuildItemId",itemId) end
	p.Parent=parent return p
end

local function lamp(parent,cf)
	local p=make(parent,"PremiumLight",Vector3.new(1.4,.35,1.4),cf,Color3.fromRGB(48,51,57),Enum.Material.Metal,0,"InteriorLamp")
	p.CanCollide=false local l=Instance.new("PointLight") l.Brightness=1.8 l.Range=17 l.Color=Color3.fromRGB(255,242,211) l.Parent=p
end

local function decorate(model)
	if not model:IsA("Model") or not model.Name:match("^Museum_%d+$") or model:GetAttribute("PremiumDecorated") then return end
	local floor=model:WaitForChild("Floor",5) if not floor then return end
	local level=math.clamp(math.floor(((floor.Size.X-40)/8)+1.5),1,5)
	local preset=PRESETS[level]
	local base=floor.CFrame*CFrame.new(0,-.6,0)
	local w,d=floor.Size.X,floor.Size.Z local h=8 local front=d/2 local back=-d/2 local door=level>=4 and 12 or 8
	model:SetAttribute("PremiumDecorated",true) model:SetAttribute("PremiumTemplateLevel",level) model:SetAttribute("PremiumTemplateName",preset.Name)
	for _,n in ipairs({"BackWall","LeftWall","RightWall"}) do local old=model:FindFirstChild(n) if old then old:Destroy() end end
	floor.Material=level>=3 and Enum.Material.Marble or Enum.Material.Slate floor.Color=level>=3 and Color3.fromRGB(222,219,210) or Color3.fromRGB(207,205,198)
	floor:SetAttribute("PremiumPreset",true) floor:SetAttribute("PresetEditable",true) floor:SetAttribute("BuildItemId","Floor")
	make(model,"PremiumBackWall",Vector3.new(w,h,1),base*CFrame.new(0,h/2,back),preset.Wall,nil,0,"Wall")
	make(model,"PremiumLeftWall",Vector3.new(1,h,d),base*CFrame.new(-w/2,h/2,0),preset.Wall,nil,0,"Wall")
	make(model,"PremiumRightWall",Vector3.new(1,h,d),base*CFrame.new(w/2,h/2,0),preset.Wall,nil,0,"Wall")
	local side=(w-door)/2
	make(model,"FrontWallL",Vector3.new(side,h,1),base*CFrame.new(-(door+side)/2,h/2,front),preset.Wall,nil,0,"Wall")
	make(model,"FrontWallR",Vector3.new(side,h,1),base*CFrame.new((door+side)/2,h/2,front),preset.Wall,nil,0,"Wall")
	local glass=make(model,"EntranceGlass",Vector3.new(door-1,6.4,.25),base*CFrame.new(0,3.2,front+.08),preset.Glass,Enum.Material.Glass,.42,"Window") glass.CanCollide=false
	make(model,"Canopy",Vector3.new(door+6,.55,6),base*CFrame.new(0,7.4,front+2.4),preset.Accent,Enum.Material.Metal,0,"Beam")
	make(model,"FrontTrim",Vector3.new(w,.5,1.4),base*CFrame.new(0,8.1,front),preset.Accent,Enum.Material.Metal,0,"Beam")
	local span=math.min(w-8,44+level*4)
	for i=1,preset.Columns do local a=preset.Columns==1 and .5 or (i-1)/(preset.Columns-1) local x=-span/2+span*a if math.abs(x)>5 then make(model,"FacadeColumn"..i,Vector3.new(level>=4 and 1.4 or 1,8,1.4),base*CFrame.new(x,4,front+1.25),preset.Stone,Enum.Material.Marble,0,"Pillar") end end
	for i=1,preset.Dividers do local x=-w/2+(w/(preset.Dividers+1))*i if math.abs(x)>4 then make(model,"GalleryDivider"..i,Vector3.new(1,6,math.max(8,d*.38)),base*CFrame.new(x,3,-d*.14),preset.Wall,nil,0,"Wall") end end
	local lights=math.clamp(4+level*2,6,14) local cols=math.ceil(lights/2)
	for i=1,lights do local c=(i-1)%cols local r=math.floor((i-1)/cols) local x=-w*.36+c*(w*.72/math.max(1,cols-1)) local z=r==0 and -d*.2 or d*.18 lamp(model,base*CFrame.new(x,7.55,z)) end
	if level>=3 then make(model,"CenterFeature",Vector3.new(5,.8,5),base*CFrame.new(0,1,-d*.18),preset.Accent,Enum.Material.Marble,0,"Pedestal") end
	if level>=4 then make(model,"UpperGallery",Vector3.new(w*.44,.7,d*.25),base*CFrame.new(0,7.6,-d*.28),preset.Stone,Enum.Material.Marble,0,"Floor") end
	if level>=5 then make(model,"EmpirePortal",Vector3.new(16,1,1.5),base*CFrame.new(0,6.8,back+3),preset.Accent,Enum.Material.Metal,0,"Beam") end
	local sign=model:FindFirstChild("MuseumSign") if sign then sign.Size=Vector3.new(math.min(22,w*.48),3.2,.8) sign.CFrame=base*CFrame.new(0,6.2,front-.45) sign.Color=preset.Accent sign.Material=Enum.Material.Metal end
	local terminal=model:FindFirstChild("Terminal") if terminal then terminal.CFrame=base*CFrame.new(-w/2+4,2.5,front+4) terminal.Color=preset.Accent end
end

function PremiumMuseumService:GetPresets() return PRESETS end
function PremiumMuseumService:Start(worldService)
	if started then return end started=true local world=worldService:GetWorld()
	for _,child in ipairs(world:GetChildren()) do task.defer(decorate,child) end
	world.ChildAdded:Connect(function(child) task.defer(decorate,child) end)
	print("[Museum Empire] 5 premium museum presets ready")
end
return PremiumMuseumService
