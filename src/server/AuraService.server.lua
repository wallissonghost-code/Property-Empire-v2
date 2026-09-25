local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local remote=Instance.new("RemoteEvent"); remote.Name="AuraSelect"; remote.Parent=ReplicatedStorage
local VALID={Lightning=true,BlackHole=true,FireRing=true,Guardian=true}
local active={}

local function part(parent,name,size,color,material)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Material=material or Enum.Material.Neon
 p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Parent=parent; return p
end
local function clear(player)
 local state=active[player]; if state and state.folder then state.folder:Destroy() end; active[player]=nil
 if player.Character then local f=player.Character:FindFirstChild("SelectedAuraFX"); if f then f:Destroy() end end
end
local function beam(a,b,color,width)
 local x=Instance.new("Beam"); x.Attachment0=a; x.Attachment1=b; x.FaceCamera=true; x.Width0=width; x.Width1=width*.35
 x.Color=ColorSequence.new(color); x.LightEmission=1; x.Transparency=NumberSequence.new(0.08,0.8); x.Parent=a; return x
end
local function apply(player,name)
 clear(player); if not VALID[name] then player:SetAttribute("SelectedAura","None"); return end
 local ch=player.Character; local root=ch and ch:FindFirstChild("HumanoidRootPart"); if not root then return end
 local folder=Instance.new("Folder"); folder.Name="SelectedAuraFX"; folder.Parent=ch
 local state={name=name,folder=folder,root=root,t=0,parts={}}; active[player]=state
 if name=="Lightning" then
  for i=1,7 do local p=part(folder,"BoltNode",Vector3.new(.12,.12,.12),Color3.fromRGB(80,190,255)); p.Shape=Enum.PartType.Ball; table.insert(state.parts,p) end
 elseif name=="BlackHole" then
  local core=part(folder,"BlackHole",Vector3.new(2.8,2.8,2.8),Color3.fromRGB(5,5,8)); core.Shape=Enum.PartType.Ball; table.insert(state.parts,core)
  for i=1,3 do local ring=part(folder,"OrbitRing",Vector3.new(.18,.18,.18),Color3.fromRGB(180,60,255)); ring.Shape=Enum.PartType.Ball; table.insert(state.parts,ring) end
  local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(145,45,255); light.Range=15; light.Brightness=2.5; light.Parent=core
 elseif name=="FireRing" then
  for i=1,14 do local orb=part(folder,"Flame",Vector3.new(.45,.45,.45),Color3.fromRGB(255,95,15)); orb.Shape=Enum.PartType.Ball; table.insert(state.parts,orb)
   local pe=Instance.new("ParticleEmitter"); pe.Texture="rbxasset://textures/particles/fire_main.dds"; pe.Rate=10; pe.Lifetime=NumberRange.new(.25,.5); pe.Speed=NumberRange.new(.2,1); pe.Color=ColorSequence.new(Color3.fromRGB(255,210,35),Color3.fromRGB(255,45,5)); pe.Size=NumberSequence.new(.45,0); pe.Parent=orb end
 elseif name=="Guardian" then
  for i=1,2 do
   local wing=part(folder,"EnergyWing",Vector3.new(.18,3.8,1.15),Color3.fromRGB(220,245,255)); wing.Transparency=.18; table.insert(state.parts,wing)
   local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(100,205,255); light.Range=10; light.Brightness=1.5; light.Parent=wing
  end
 end
 player:SetAttribute("SelectedAura",name)
end
remote.OnServerEvent:Connect(function(player,name) if name=="None" or VALID[name] then apply(player,name) end end)
RunService.Heartbeat:Connect(function(dt)
 for player,s in pairs(active) do
  local root=s.root; if not root.Parent then clear(player) continue end
  s.t+=dt; local cf=root.CFrame
  if s.name=="Lightning" then
   for i,p in ipairs(s.parts) do
    local a=s.t*3+i*1.7; local radius=2.3+(i%2)*.55; local y=math.sin(s.t*5+i)*2.2
    p.CFrame=CFrame.new(root.Position+Vector3.new(math.cos(a)*radius,y,math.sin(a)*radius))
   end
  elseif s.name=="BlackHole" then
   s.parts[1].CFrame=CFrame.new(root.Position+Vector3.new(0,3.7,0))
   for i=2,#s.parts do local a=s.t*(1.8+i*.35)+i*2.1; local r=2.1+(i-2)*.55; s.parts[i].CFrame=CFrame.new(root.Position+Vector3.new(math.cos(a)*r,3.7+math.sin(a*2)*.35,math.sin(a)*r)) end
  elseif s.name=="FireRing" then
   for i,p in ipairs(s.parts) do local a=(i/#s.parts)*math.pi*2+s.t*1.7; p.CFrame=CFrame.new(root.Position+Vector3.new(math.cos(a)*3,.15+math.sin(s.t*4+i)*.25,math.sin(a)*3)) end
  elseif s.name=="Guardian" then
   local flap=.35+math.sin(s.t*3)*.12
   s.parts[1].CFrame=cf*CFrame.new(-1.7,1.3,1)*CFrame.Angles(0,0,-flap)
   s.parts[2].CFrame=cf*CFrame.new(1.7,1.3,1)*CFrame.Angles(0,0,flap)
  end
 end
end)
Players.PlayerAdded:Connect(function(p) p:SetAttribute("SelectedAura","None"); p.CharacterRemoving:Connect(function() clear(p) end) end)
Players.PlayerRemoving:Connect(function(p) clear(p) end)
