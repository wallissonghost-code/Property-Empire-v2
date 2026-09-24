local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local remote = Instance.new("RemoteEvent")
remote.Name = "AttackRequest"
remote.Parent = ReplicatedStorage

local COOLDOWN = 0.45
local MELEE_RANGE = 6
local LASER_RANGE = 55
local DAMAGE = 10
local lastAttack = {}

local function getTarget(character, range)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end

	local bestHumanoid
	local bestRoot
	local bestDistance = range + 1
	for _, model in workspace:GetChildren() do
		if model ~= character and model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot and humanoid.Health > 0 then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= range and distance < bestDistance and distance > 0 then
					local facing = root.CFrame.LookVector:Dot(offset.Unit)
					if facing >= 0.35 then
						bestHumanoid = humanoid
						bestRoot = targetRoot
						bestDistance = distance
					end
				end
			end
		end
	end
	return bestHumanoid, bestRoot
end

local function laserOrigin(character)
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	return head.Position + head.CFrame.LookVector * (head.Size.Z * 0.5 + 0.1)
end

local function showLaser(character, targetRoot)
	local origin = laserOrigin(character)
	if not origin then return end
	local destination = targetRoot.Position
	local distance = (destination - origin).Magnitude
	if distance <= 0.05 then return end

	local beam = Instance.new("Part")
	beam.Name = "LaserEyesEffect"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 35, 35)
	beam.Size = Vector3.new(0.16, 0.16, distance)
	beam.CFrame = CFrame.lookAt(origin, destination) * CFrame.new(0, 0, -distance * 0.5)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.12)
end

remote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < COOLDOWN then return end
	lastAttack[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local hasLaser = player:GetAttribute("Skill_LaserEyes") == true
	local range = hasLaser and LASER_RANGE or MELEE_RANGE
	local target, targetRoot = getTarget(character, range)
	if not target then return end

	if hasLaser then
		showLaser(character, targetRoot)
	end
	target:TakeDamage(DAMAGE)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
