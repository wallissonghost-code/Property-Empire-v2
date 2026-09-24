local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local MOB_CONFIG = {
	{name = "Mob_100HP", health = 100, position = Vector3.new(-10, 3.5, -28)},
	{name = "Mob_1000HP", health = 1000, position = Vector3.new(0, 3.5, -28)},
	{name = "Mob_10000HP", health = 10000, position = Vector3.new(10, 3.5, -28)},
}

local CHASE_RANGE = 120
local WALK_SPEED = 10
local PATH_REFRESH = 0.65
local VOID_Y = -20
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

	table.insert(mobs, {
		model = model,
		humanoid = humanoid,
		root = root,
		spawnCFrame = CFrame.new(config.position),
		nextPathAt = 0,
	})
end

local function nearestGroundedPlayer(position)
	local bestRoot
	local bestDistance = CHASE_RANGE
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 and humanoid.FloorMaterial ~= Enum.Material.Air then
			local flatOffset = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
			local distance = flatOffset.Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestRoot = root
			end
		end
	end
	return bestRoot
end

local function groundBelow(mob, position)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {mob.model}
	params.IgnoreWater = false
	return workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), params)
end

local function recoverMob(mob)
	mob.root.AssemblyLinearVelocity = Vector3.zero
	mob.root.AssemblyAngularVelocity = Vector3.zero
	mob.model:PivotTo(mob.spawnCFrame)
	mob.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

local function chase(mob, targetRoot)
	if os.clock() < mob.nextPathAt then return end
	mob.nextPathAt = os.clock() + PATH_REFRESH

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 6,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})

	local success = pcall(function()
		path:ComputeAsync(mob.root.Position, targetRoot.Position)
	end)
	if not success or path.Status ~= Enum.PathStatus.Success then
		return
	end

	local waypoints = path:GetWaypoints()
	local nextWaypoint = waypoints[2]
	if nextWaypoint and groundBelow(mob, nextWaypoint.Position) then
		mob.humanoid:MoveTo(nextWaypoint.Position)
	end
end

for _, config in MOB_CONFIG do
	createMob(config)
end

RunService.Heartbeat:Connect(function()
	for _, mob in mobs do
		if mob.model.Parent and mob.humanoid.Health > 0 then
			if mob.root.Position.Y < VOID_Y or not groundBelow(mob, mob.root.Position) then
				recoverMob(mob)
			else
				local targetRoot = nearestGroundedPlayer(mob.root.Position)
				if targetRoot then
					chase(mob, targetRoot)
				else
					mob.humanoid:Move(Vector3.zero)
				end
			end
		end
	end
end)
