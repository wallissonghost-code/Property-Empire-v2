local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MOB_CONFIG = {
	{name = "Mob_100HP", health = 100, position = Vector3.new(-10, 3.5, -28)},
	{name = "Mob_1000HP", health = 1000, position = Vector3.new(0, 3.5, -28)},
	{name = "Mob_10000HP", health = 10000, position = Vector3.new(10, 3.5, -28)},
}

local CHASE_RANGE = 120
local WALK_SPEED = 10
local STOP_DISTANCE = 3.5
local EDGE_LOOKAHEAD = 4
local GROUND_PROBE_HEIGHT = 4
local GROUND_PROBE_DEPTH = 12
local VOID_Y = -20
local RESPAWN_DELAY = 4
local mobs = {}

local function createPart(model, name, size, position, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = false
	part.CanCollide = false
	part.Color = color
	part.Transparency = transparency or 0
	part.Material = Enum.Material.SmoothPlastic
	part.Massless = name ~= "HumanoidRootPart"
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
	root.RootPriority = 127
	root.CanCollide = true
	local torso = createPart(model, "Torso", Vector3.new(3, 4, 2), config.position, Color3.fromRGB(55, 60, 64))
	local head = createPart(model, "Head", Vector3.new(2.4, 2.4, 2.4), config.position + Vector3.new(0, 3.2, 0), Color3.fromRGB(75, 80, 84))

	weld(root, torso)
	weld(root, head)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.AutoRotate = true
	humanoid.DisplayName = string.format("%d HP", config.health)
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60
	humanoid.Parent = model

	local function updateHealthDisplay()
		humanoid.DisplayName = string.format("%d HP", math.max(0, math.ceil(humanoid.Health)))
	end
	humanoid.HealthChanged:Connect(updateHealthDisplay)
	updateHealthDisplay()

	model.PrimaryPart = root
	model.Parent = workspace
	if _G.AssignMobCollisionGroup then
		_G.AssignMobCollisionGroup(model)
	else
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then descendant.CollisionGroup = "Mobs" end
		end
	end
	root:SetNetworkOwner(nil)

	table.insert(mobs, {
		model = model,
		humanoid = humanoid,
		root = root,
		spawnCFrame = CFrame.new(config.position),
		config = config,
		dead = false,
	})
end

local function nearestPlayer(position)
	local bestRoot
	local bestDistance = CHASE_RANGE
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local offset = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
			local distance = offset.Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestRoot = root
			end
		end
	end
	return bestRoot, bestDistance
end

local function hasGroundAt(mob, position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {mob.model}
	params.IgnoreWater = false
	local origin = position + Vector3.new(0, GROUND_PROBE_HEIGHT, 0)
	return workspace:Raycast(origin, Vector3.new(0, -GROUND_PROBE_DEPTH, 0), params) ~= nil
end

local function recoverMob(mob)
	mob.humanoid:Move(Vector3.zero)
	mob.root.AssemblyLinearVelocity = Vector3.zero
	mob.root.AssemblyAngularVelocity = Vector3.zero
	mob.model:PivotTo(mob.spawnCFrame)
	mob.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function chase(mob, targetRoot, distance)
	if distance <= STOP_DISTANCE then
		mob.humanoid:Move(Vector3.zero)
		return
	end

	local delta = Vector3.new(
		targetRoot.Position.X - mob.root.Position.X,
		0,
		targetRoot.Position.Z - mob.root.Position.Z
	)
	if delta.Magnitude <= 0.01 then
		mob.humanoid:Move(Vector3.zero)
		return
	end

	local direction = delta.Unit
	local probePosition = mob.root.Position + direction * EDGE_LOOKAHEAD
	if not hasGroundAt(mob, probePosition) then
		mob.humanoid:Move(Vector3.zero)
		return
	end

	-- Humanoid:Move expects a direction vector. Supplying the direction toward
	-- the player directly removes waypoint ambiguity and keeps the mob facing/chasing the target.
	mob.humanoid:Move(direction, false)
end

for _, config in MOB_CONFIG do
	createMob(config)
end

local function scheduleRespawn(mob)
	if mob.dead then return end
	mob.dead = true
	mob.humanoid:Move(Vector3.zero)
	local config = mob.config
	local oldModel = mob.model
	task.delay(RESPAWN_DELAY, function()
		if oldModel.Parent then oldModel:Destroy() end
		createMob(config)
	end)
end

RunService.Heartbeat:Connect(function()
	for _, mob in mobs do
		if mob.model.Parent and not mob.dead then
			if mob.humanoid.Health <= 0 then
				scheduleRespawn(mob)
			else
			if mob.root.Position.Y < VOID_Y then
				recoverMob(mob)
			elseif not hasGroundAt(mob, mob.root.Position) then
				recoverMob(mob)
			else
				local targetRoot, distance = nearestPlayer(mob.root.Position)
				if targetRoot then
					chase(mob, targetRoot, distance)
				else
					mob.humanoid:Move(Vector3.zero)
				end
			end
			end
		end
	end
end)
