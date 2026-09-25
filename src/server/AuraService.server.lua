local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local remote=Instance.new("RemoteEvent"); remote.Name="AuraSelect"; remote.Parent=ReplicatedStorage
local VALID={Guardian=true}
local active={}

local function fxPart(parent,name,size,color,transparency)
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Transparency=transparency or 0
 p.Material=Enum.Material.Neon; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false; p.Parent=parent; return p
end
local function light(parent,color,range,brightness)
 local l=Instance.new("PointLight"); l.Color=color; l.Range=range; l.Brightness=brightness; l.Shadows=false; l.Parent=parent; return l
end
local function clear(player)
 local s=active[player]; if s and s.folder and s.folder.Parent then s.folder:Destroy() end; active[player]=nil
 local ch=player.Character; if ch then local f=ch:FindFirstChild("SelectedAuraFX"); if f then f:Destroy() end end
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
 setupGuardian(s)
 player:SetAttribute("SelectedAura",name)
end
remote.OnServerEvent:Connect(function(player,name) if name=="None" or VALID[name] then apply(player,name) end end)
RunService.Heartbeat:Connect(function(dt)
 for player,s in pairs(active) do
  local root=s.root; if not root or not root.Parent then clear(player) continue end
  s.t+=dt; local t=s.t; local cf=root.CFrame
  if s.name=="Guardian" then
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
