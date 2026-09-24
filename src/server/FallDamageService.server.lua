local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SAFE_FALL_SPEED = 70
local LETHAL_FALL_SPEED = 300
local MAX_NONLETHAL_FRACTION = 0.95

local function calculateDamage(humanoid, impactSpeed)
	if impactSpeed <= SAFE_FALL_SPEED then
		return 0
	end
	if impactSpeed >= LETHAL_FALL_SPEED then
		return humanoid.MaxHealth
	end

	local severity = (impactSpeed - SAFE_FALL_SPEED) / (LETHAL_FALL_SPEED - SAFE_FALL_SPEED)
	local fraction = severity ^ 1.45 * MAX_NONLETHAL_FRACTION
	return humanoid.MaxHealth * fraction
end

local function monitorCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	local root = character:WaitForChild("HumanoidRootPart")
	local falling = false
	local peakDownwardSpeed = 0

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not character.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			return
		end

		local state = humanoid:GetState()
		local downwardSpeed = math.max(0, -root.AssemblyLinearVelocity.Y)
		local airborne = state == Enum.HumanoidStateType.Freefall
			or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Jumping

		if airborne then
			falling = true
			peakDownwardSpeed = math.max(peakDownwardSpeed, downwardSpeed)
		elseif falling and (state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.RunningNoPhysics) then
			local damage = calculateDamage(humanoid, peakDownwardSpeed)
			falling = false
			peakDownwardSpeed = 0
			if damage > 0 then
				humanoid:TakeDamage(damage)
			end
		elseif not airborne then
			falling = false
			peakDownwardSpeed = 0
		end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(monitorCharacter)
	if player.Character then
		task.spawn(monitorCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
