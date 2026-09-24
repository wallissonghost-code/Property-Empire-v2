local MOB_CONFIG = {
	{name = "Mob_100HP", health = 100, position = Vector3.new(-10, 3.5, -28)},
	{name = "Mob_1000HP", health = 1000, position = Vector3.new(0, 3.5, -28)},
	{name = "Mob_10000HP", health = 10000, position = Vector3.new(10, 3.5, -28)},
}

local function createPart(model, name, size, position, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
	return part
end

local function createMob(config)
	local model = Instance.new("Model")
	model.Name = config.name

	local root = createPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), config.position, Color3.fromRGB(42, 45, 48))
	root.Transparency = 1
	root.CanCollide = false

	local torso = createPart(model, "Torso", Vector3.new(3, 4, 2), config.position, Color3.fromRGB(55, 60, 64))
	local head = createPart(model, "Head", Vector3.new(2.4, 2.4, 2.4), config.position + Vector3.new(0, 3.2, 0), Color3.fromRGB(75, 80, 84))

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.DisplayName = string.format("%s HP", config.health)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = workspace

	-- Test dummies are intentionally static. They exist only to validate combat damage.
	torso.Anchored = true
	head.Anchored = true
end

for _, config in MOB_CONFIG do
	createMob(config)
end
