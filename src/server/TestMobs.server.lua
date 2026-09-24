local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local R15_DUMMY_ASSET_ID = 11235072353
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
local r15Template

local function stripScripts(instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
end

local function findRig(container)
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("Model")
			and descendant:FindFirstChildOfClass("Humanoid")
			and descendant:FindFirstChild("HumanoidRootPart") then
			return descendant
		end
	end
	return nil
end

local function loadR15Template()
	local success, container = pcall(AssetService.LoadAssetAsync, AssetService, R15_DUMMY_ASSET_ID)
	if not success or not container then
		warn("R15 Dummy asset could not be loaded:", container)
		return nil
	end

	stripScripts(container)
	local rig = findRig(container)
	if not rig then
		warn("R15 Dummy asset does not contain a Humanoid rig")
		container:Destroy()
		return nil
	end

	rig.Parent = nil
	container:Destroy()
	return rig
end

local function createFallbackRig(config)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = true
	root.Anchored = false
	root.Position = config.position
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(3, 4, 2)
	torso.Position = config.position
	torso.CanCollide = false
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 2.4, 2.4)
	head.Position = config.position + Vector3.new(0, 3.2, 0)
	head.CanCollide = false
	head.Parent = model

	for _, part in {torso, head} do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function prepareRig(config)
	local model = r15Template and r15Template:Clone() or createFallbackRig(config)
	model.Name = config.name
	stripScripts(model)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return nil
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = descendant == root
		end
	end
	root.Transparency = 1
	root.RootPriority = 127

	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60

	local function updateHealthDisplay()
		humanoid.DisplayName = string.format("%d HP", math.max(0, math.ceil(humanoid.Health)))
	end
	humanoid.HealthChanged:Connect(updateHealthDisplay)
	updateHealthDisplay()

	model.PrimaryPart = root
	model.Parent = workspace
	model:PivotTo(CFrame.new(config.position))

	if _G.AssignMobCollisionGroup then
		_G.AssignMobCollisionGroup(model)
	else
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then descendant.CollisionGroup = "Mobs" end
		end
	end
	root:SetNetworkOwner(nil)
	return model, humanoid, root
end

local function createMob(config)
	local model, humanoid, root = prepareRig(config)
	if not model then return end
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
	local delta = Vector3.new(targetRoot.Position.X - mob.root.Position.X, 0, targetRoot.Position.Z - mob.root.Position.Z)
	if delta.Magnitude <= 0.01 then
		mob.humanoid:Move(Vector3.zero)
		return
	end
	local direction = delta.Unit
	if not hasGroundAt(mob, mob.root.Position + direction * EDGE_LOOKAHEAD) then
		mob.humanoid:Move(Vector3.zero)
		return
	end
	mob.humanoid:Move(direction, false)
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

r15Template = loadR15Template()
if not r15Template then
	warn("Using fallback test rig. Enable third-party asset loading or make the R15 Dummy available to the experience.")
end

for _, config in MOB_CONFIG do
	createMob(config)
end

RunService.Heartbeat:Connect(function()
	for _, mob in mobs do
		if mob.model.Parent and not mob.dead then
			if mob.humanoid.Health <= 0 then
				scheduleRespawn(mob)
			elseif mob.root.Position.Y < VOID_Y or not hasGroundAt(mob, mob.root.Position) then
				recoverMob(mob)
			else
				local targetRoot, distance = nearestPlayer(mob.root.Position)
				if targetRoot then chase(mob, targetRoot, distance) else mob.humanoid:Move(Vector3.zero) end
			end
		end
	end
end)
