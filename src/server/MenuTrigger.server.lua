local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remote = Instance.new("RemoteEvent")
remote.Name = "MainMenuState"
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

local active = {}
local halfX = trigger.Size.X * 0.5
local halfZ = trigger.Size.Z * 0.5

local function isStandingOnPlatform(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local localPosition = trigger.CFrame:PointToObjectSpace(root.Position)
	local insideX = math.abs(localPosition.X) <= halfX
	local insideZ = math.abs(localPosition.Z) <= halfZ
	local above = localPosition.Y >= 0 and localPosition.Y <= 6
	return insideX and insideZ and above
end

RunService.Heartbeat:Connect(function()
	for _, player in Players:GetPlayers() do
		local standing = isStandingOnPlatform(player.Character)
		if active[player] ~= standing then
			active[player] = standing
			remote:FireClient(player, standing)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	active[player] = nil
end)
