local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local remote=Instance.new("RemoteEvent"); remote.Name="AuraSelect"; remote.Parent=ReplicatedStorage
local VALID={Lightning=true,BlackHole=true,FireRing=true,Guardian=true}
local active={}

local function fxPart(parent,name,size,color,transparency)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Transparency=transparency or 0
 p.Material=Enum.Material.Neon; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Parent=parent; return p
end
local function sphere(parent,name,size,color,transparency)
 local p=fxPart(parent,name,Vector3.new(size,size,size),color,transparency); p.Shape=Enum.PartType.Ball; return p
end
local function light(parent,color,range,brightness)
 local l=Instance.new("PointLight"); l.Color=color; l.Range=range; l.Brightness=brightness; l.Shadows=false; l.Parent=parent; return l
end
local function emitter(parent,texture,color,rate,lifetime,speed,size)
 local e=Instance.new("ParticleEmitter"); e.Texture=texture; e.Color=color; e.Rate=rate; e.Lifetime=lifetime; e.Speed=speed
 e.Size=size; e.LightEmission=.85; e.SpreadAngle=Vector2.new(180,180); e.Rotation=NumberRange.new(0,360); e.RotSpeed=NumberRange.new(-90,90); e.Parent=parent; return e
end
local function clear(player)
 local s=active[player]; if s and s.folder and s.folder.Parent then s.folder:Destroy() end; active[player]=nil
 local ch=player.Character; if ch then local f=ch:FindFirstChild("SelectedAuraFX"); if f then f:Destroy() end end
end
local function setupLightning(s)
 s.nodes={}; s.arcs={}
 for i=1,8 do
  local n=sphere(s.folder,"ElectricNode",.16,Color3.fromRGB(150,225,255),.08); table.insert(s.nodes,n)
 end
 for i=1,4 do
  local a0=Instance.new("Attachment"); local a1=Instance.new("Attachment"); a0.Parent=s.root; a1.Parent=s.root
  local b=Instance.new("Beam"); b.Attachment0=a0; b.Attachment1=a1; b.FaceCamera=true; b.Width0=.12; b.Width1=.035
  b.Color=ColorSequence.new(Color3.fromRGB(225,250,255),Color3.fromRGB(40,125,255)); b.LightEmission=1
  b.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),NumberSequenceKeypoint.new(.7,.2),NumberSequenceKeypoint.new(1,.8)}); b.Parent=s.root
  table.insert(s.arcs,{a0,a1,b})
 end
 s.glow=light(s.root,Color3.fromRGB(65,165,255),14,1.7)
end
local function setupBlackHole(s)
 s.core=sphere(s.folder,"Singularity",2.25,Color3.fromRGB(0,0,0),0)
 s.shell=sphere(s.folder,"EventHorizon",3.05,Color3.fromRGB(95,15,180),.72)
 s.orbit={}
 for i=1,10 do table.insert(s.orbit,sphere(s.folder,"Accretion",.18+(i%3)*.06,Color3.fromRGB(205,70,255),.08)) end
 s.glow=light(s.shell,Color3.fromRGB(125,35,255),17,2.2)
end
local function setupFire(s)
 s.flames={}
 for i=1,16 do
  local p=sphere(s.folder,"InfernalCore",.28,Color3.fromRGB(255,105,10),.1)
  emitter(p,"rbxasset://textures/particles/fire_main.dds",ColorSequence.new(Color3.fromRGB(255,235,90),Color3.fromRGB(255,35,0)),8,NumberRange.new(.25,.55),NumberRange.new(.5,2),NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,0)}))
  table.insert(s.flames,p)
 end
 s.center=Instance.new("Attachment"); s.center.Position=Vector3.new(0,-2.6,0); s.center.Parent=s.root
 emitter(s.center,"rbxasset://textures/particles/smoke_main.dds",ColorSequence.new(Color3.fromRGB(80,35,20),Color3.fromRGB(10,10,10)),10,NumberRange.new(.5,1.1),NumberRange.new(.3,1.4),NumberSequence.new({NumberSequenceKeypoint.new(0,.7),NumberSequenceKeypoint.new(1,1.5)}))
 s.glow=light(s.root,Color3.fromRGB(255,85,20),13,1.8)
end
local function setupGuardian(s)
 s.wings={}
 for side=-1,1,2 do
  local wing={}
  for i=1,4 do
   local feather=fxPart(s.folder,"EnergyFeather",Vector3.new(.12,2.8-i*.25,.55),Color3.fromRGB(215,245,255),.18+i*.05)
   table.insert(wing,feather)
  end
  table.insert(s.wings,{side=side,parts=wing})
 end
 s.halo=fxPart(s.folder,"Halo",Vector3.new(.12,2.2,2.2),Color3.fromRGB(255,245,180),.1); s.halo.Shape=Enum.PartType.Cylinder
 s.glow=light(s.root,Color3.fromRGB(150,220,255),14,1.5)
end
local function apply(player,name)
 clear(player); if name=="None" then player:SetAttribute("SelectedAura","None"); return end
 if not VALID[name] then return end
 local ch=player.Character; local root=ch and ch:FindFirstChild("HumanoidRootPart"); if not root then return end
 local folder=Instance.new("Folder"); folder.Name="SelectedAuraFX"; folder.Parent=ch
 local s={name=name,folder=folder,root=root,t=0}; active[player]=s
 if name=="Lightning" then setupLightning(s) elseif name=="BlackHole" then setupBlackHole(s) elseif name=="FireRing" then setupFire(s) else setupGuardian(s) end
 player:SetAttribute("SelectedAura",name)
end
remote.OnServerEvent:Connect(function(player,name) if name=="None" or VALID[name] then apply(player,name) end end)
RunService.Heartbeat:Connect(function(dt)
 for player,s in pairs(active) do
  local root=s.root; if not root or not root.Parent then clear(player) continue end
  s.t+=dt; local t=s.t; local cf=root.CFrame
  if s.name=="Lightning" then
   for i,p in ipairs(s.nodes) do local a=t*2.8+i*.79; local r=2.15+.35*math.sin(t*2+i); local y=.3+math.sin(t*4+i*1.4)*2.25; p.CFrame=CFrame.new(root.Position+Vector3.new(math.cos(a)*r,y,math.sin(a)*r)) end
   for i,a in ipairs(s.arcs) do local n1=s.nodes[((i*2-1)-1)%#s.nodes+1]; local n2=s.nodes[((i*2)-1)%#s.nodes+1]; a[1].WorldPosition=n1.Position; a[2].WorldPosition=n2.Position; a[3].CurveSize0=math.sin(t*12+i)*.55; a[3].CurveSize1=-a[3].CurveSize0 end
   s.glow.Brightness=1.2+math.abs(math.sin(t*9))*1.6
  elseif s.name=="BlackHole" then
   local center=root.Position+Vector3.new(0,4.15,0); s.core.CFrame=CFrame.new(center); local pulse=3.05+math.sin(t*2.4)*.18; s.shell.Size=Vector3.new(pulse,pulse,pulse); s.shell.CFrame=CFrame.new(center)
   for i,p in ipairs(s.orbit) do local a=t*(1.5+(i%3)*.22)+i*.63; local r=2.25+(i%4)*.34; local tilt=(i%2==0) and .55 or -.55; p.CFrame=CFrame.new(center+Vector3.new(math.cos(a)*r,math.sin(a*1.7)*tilt,math.sin(a)*r)) end
  elseif s.name=="FireRing" then
   for i,p in ipairs(s.flames) do local a=t*1.45+(i/#s.flames)*math.pi*2; local r=2.75+.22*math.sin(t*3+i); p.CFrame=CFrame.new(root.Position+Vector3.new(math.cos(a)*r,-2.55+.15*math.sin(t*5+i),math.sin(a)*r)) end
   s.glow.Brightness=1.4+math.abs(math.sin(t*5))*.9
  elseif s.name=="Guardian" then
   local flap=.18+math.sin(t*2.4)*.1
   for _,wing in ipairs(s.wings) do for i,p in ipairs(wing.parts) do local side=wing.side; local x=side*(1.05+i*.55); local y=1.25+(i-1)*.34; local z=.75+(i-1)*.15; p.CFrame=cf*CFrame.new(x,y,z)*CFrame.Angles(math.rad(-12-i*3),0,side*(-.3-flap-i*.055)) end end
   s.halo.CFrame=cf*CFrame.new(0,3.65,0)*CFrame.Angles(0,0,math.rad(90)); s.glow.Brightness=1.25+math.sin(t*2)*.25
  end
 end
end)
local function onPlayer(p)
 p:SetAttribute("SelectedAura","None")
 p.CharacterRemoving:Connect(function() clear(p) end)
end
Players.PlayerAdded:Connect(onPlayer); for _,p in Players:GetPlayers() do onPlayer(p) end
Players.PlayerRemoving:Connect(function(p) clear(p) end)
