local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "OpenMainMenu"
remote.Parent = ReplicatedStorage

local trigger = Instance.new("Part")
trigger.Name = "MenuPlatform"
trigger.Anchored = true
trigger.Size = Vector3.new(5, 0.5, 5)
trigger.Position = Vector3.new(0, 0.75, -12)
trigger.Material = Enum.Material.Neon
trigger.Color = Color3.fromRGB(45, 210, 105)
trigger.TopSurface = Enum.SurfaceType.Smooth
trigger.BottomSurface = Enum.SurfaceType.Smooth
trigger.Parent = workspace

local debounce = {}

trigger.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player or debounce[player] then return end

	debounce[player] = true
	remote:FireClient(player)
	task.delay(1, function()
		debounce[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	debounce[player] = nil
end)
