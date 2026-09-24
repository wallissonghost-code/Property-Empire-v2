local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "OpenMainMenu"
remote.Parent = ReplicatedStorage

local trigger = Instance.new("Part")
trigger.Name = "MenuPlatform"
trigger.Anchored = true
trigger.Size = Vector3.new(14, 1, 14)
trigger.Position = Vector3.new(0, 0.75, -18)
trigger.Material = Enum.Material.Neon
trigger.Color = Color3.fromRGB(45, 210, 105)
trigger.TopSurface = Enum.SurfaceType.Smooth
trigger.BottomSurface = Enum.SurfaceType.Smooth
trigger.Parent = workspace

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "OpenMenuPrompt"
prompt.ActionText = "Abrir menu"
prompt.ObjectText = "CIDADE PROSPERA"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
prompt.Parent = trigger

prompt.Triggered:Connect(function(player)
	remote:FireClient(player)
end)
