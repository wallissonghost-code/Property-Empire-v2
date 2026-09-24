local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "AttackRequest"
remote.Parent = ReplicatedStorage

local COOLDOWN = 0.45
local RANGE = 6
local DAMAGE = 10
local lastAttack = {}

local function getTarget(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local bestHumanoid
	local bestDistance = RANGE + 1
	for _, model in workspace:GetChildren() do
		if model ~= character and model:IsA("Model") then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot and humanoid.Health > 0 then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= RANGE and distance < bestDistance and distance > 0 then
					local facing = root.CFrame.LookVector:Dot(offset.Unit)
					if facing >= 0.35 then
						bestHumanoid = humanoid
						bestDistance = distance
					end
				end
			end
		end
	end
	return bestHumanoid
end

remote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < COOLDOWN then return end
	lastAttack[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local target = getTarget(character)
	if target then
		target:TakeDamage(DAMAGE)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
