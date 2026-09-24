local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MOB_CONFIG = {
	{name = "Mob_100HP", health = 100, position = Vector3.new(-10, 3.5, -28)},
	{name = "Mob_1000HP", health = 1000, position = Vector3.new(0, 3.5, -28)},
	{name = "Mob_10000HP", health = 10000, position = Vector3.new(10, 3.5, -28)},
}

local CHASE_RANGE = 120
local WALK_SPEED = 10
local UPDATE_INTERVAL = 0.15
local mobs = {}

local function createPart(model, name, size, position, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = false
	part.CanCollide = name ~= "HumanoidRootPart"
	part.Color = color
	part.Transparency = transparency or 0
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

local function weld(root, part)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = root
	joint.Part1 = part
	joint.Parent = root
end

local function createMob(config)
	local model = Instance.new("Model")
	model.Name = config.name

	local root = createPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), config.position, Color3.fromRGB(42, 45, 48), 1)
	local torso = createPart(model, "Torso", Vector3.new(3, 4, 2), config.position, Color3.fromRGB(55, 60, 64))
	local head = createPart(model, "Head", Vector3.new(2.4, 2.4, 2.4), config.position + Vector3.new(0, 3.2, 0), Color3.fromRGB(75, 80, 84))

	weld(root, torso)
	weld(root, head)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.DisplayName = string.format("%s HP", config.health)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = workspace
	root:SetNetworkOwner(nil)

	table.insert(mobs, {model = model, humanoid = humanoid, root = root})
end

local function nearestPlayer(position)
	local bestRoot
	local bestDistance = CHASE_RANGE
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestRoot = root
			end
		end
	end
	return bestRoot
end

for _, config in MOB_CONFIG do
	createMob(config)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < UPDATE_INTERVAL then return end
	elapsed = 0

	for _, mob in mobs do
		if mob.model.Parent and mob.humanoid.Health > 0 then
			local targetRoot = nearestPlayer(mob.root.Position)
			if targetRoot then
				mob.humanoid:MoveTo(targetRoot.Position)
			end
		end
	end
end)
