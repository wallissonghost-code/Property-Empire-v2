local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local remote = Instance.new("RemoteEvent")
remote.Name = "AttackRequest"
remote.Parent = ReplicatedStorage

local COOLDOWN = 0.45
local MELEE_RANGE = 6
local LASER_RANGE = 55
local MELEE_DAMAGE = 10
local LASER_DAMAGE = 10
local TARGET_CONE_DOT = 0.15
local lastAttack = {}

local function findTarget(character, range)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil, nil end

	local bestHumanoid
	local bestRoot
	local bestScore = math.huge

	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("Humanoid") and descendant.Health > 0 and descendant.Parent ~= character then
			local model = descendant.Parent
			local targetRoot = model and model:FindFirstChild("HumanoidRootPart")
			if targetRoot and targetRoot:IsA("BasePart") then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance > 0 and distance <= range then
					local facing = root.CFrame.LookVector:Dot(offset.Unit)
					if facing >= TARGET_CONE_DOT then
						-- Favor the target closest to the center of the player's view,
						-- then distance. Works for players and NPC Humanoids alike.
						local score = (1 - facing) * range + distance * 0.15
						if score < bestScore then
							bestScore = score
							bestHumanoid = descendant
							bestRoot = targetRoot
						end
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

local function damageTarget(target, amount)
	if not target or target.Health <= 0 then return false end
	local before = target.Health
	target:TakeDamage(amount)
	return target.Health < before
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
	local target, targetRoot = findTarget(character, range)
	if not target then return end

	if hasLaser then
		if damageTarget(target, LASER_DAMAGE) then
			showLaser(character, targetRoot)
		end
	else
		damageTarget(target, MELEE_DAMAGE)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
