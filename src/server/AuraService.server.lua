local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "AuraSelect"
remote.Parent = ReplicatedStorage

local AURAS = {
	NeonStorm = {primary=Color3.fromRGB(0,255,170), secondary=Color3.fromRGB(80,140,255), rate=42},
	Inferno = {primary=Color3.fromRGB(255,55,20), secondary=Color3.fromRGB(255,190,25), rate=52},
	Void = {primary=Color3.fromRGB(155,45,255), secondary=Color3.fromRGB(25,0,45), rate=38},
	Celestial = {primary=Color3.fromRGB(245,245,255), secondary=Color3.fromRGB(70,190,255), rate=34},
}

local function clearAura(character)
	local old=character:FindFirstChild("SelectedAuraFX")
	if old then old:Destroy() end
end

local function applyAura(player, name)
	local character=player.Character
	local cfg=AURAS[name]
	if not character or not cfg then return end
	local root=character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	clearAura(character)
	local folder=Instance.new("Folder"); folder.Name="SelectedAuraFX"; folder.Parent=character
	local attachment=Instance.new("Attachment"); attachment.Name="AuraCore"; attachment.Parent=root; attachment.Parent=folder
	-- Folder cannot own an Attachment while keeping it attached to root, so use tagged instances directly.
	attachment.Parent=root
	local marker=Instance.new("ObjectValue"); marker.Name="AuraAttachment"; marker.Value=attachment; marker.Parent=folder
	local emitter=Instance.new("ParticleEmitter")
	emitter.Name="AuraParticles"; emitter.Texture="rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color=ColorSequence.new(cfg.primary,cfg.secondary); emitter.LightEmission=0.9
	emitter.Rate=cfg.rate; emitter.Lifetime=NumberRange.new(0.55,1.15); emitter.Speed=NumberRange.new(1.5,4)
	emitter.SpreadAngle=Vector2.new(180,180); emitter.Rotation=NumberRange.new(0,360); emitter.RotSpeed=NumberRange.new(-120,120)
	emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.45,0.55),NumberSequenceKeypoint.new(1,0)})
	emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.7,0.35),NumberSequenceKeypoint.new(1,1)})
	emitter.Parent=attachment
	local light=Instance.new("PointLight"); light.Color=cfg.primary; light.Range=12; light.Brightness=1.8; light.Parent=root
	light.Name="AuraLight"; local lm=Instance.new("ObjectValue"); lm.Name="AuraLight"; lm.Value=light; lm.Parent=folder
	player:SetAttribute("SelectedAura",name)
end

local function cleanupReferences(character)
	local folder=character:FindFirstChild("SelectedAuraFX")
	if not folder then return end
	for _,v in folder:GetChildren() do if v:IsA("ObjectValue") and v.Value then v.Value:Destroy() end end
	folder:Destroy()
end

remote.OnServerEvent:Connect(function(player,name)
	if name=="None" then cleanupReferences(player.Character); player:SetAttribute("SelectedAura","None"); return end
	if AURAS[name] then cleanupReferences(player.Character); applyAura(player,name) end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("SelectedAura","None")
	player.CharacterAdded:Connect(function() player:SetAttribute("SelectedAura","None") end)
end)
