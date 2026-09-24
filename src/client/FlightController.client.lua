local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FlightUI = require(script.Parent.FlightUI)
local player = Players.LocalPlayer
local view = FlightUI.create(player:WaitForChild("PlayerGui"))

local flying = false
local connection
local attachment
local velocity
local orientation
local SPEED = 42
local CAMERA_VERTICAL_DEADZONE = 0.18
local COLLISION_PADDING = 0.2
local BODY_BOX_SIZE = Vector3.new(4.2, 5.6, 2.4)

local function stopFlight()
	flying = false
	if connection then connection:Disconnect() connection = nil end
	if velocity then velocity:Destroy() velocity = nil end
	if orientation then orientation:Destroy() orientation = nil end
	if attachment then attachment:Destroy() attachment = nil end
	FlightUI.setActive(view, false)
end

local function cameraVertical(lookY)
	local magnitude = math.abs(lookY)
	if magnitude <= CAMERA_VERTICAL_DEADZONE then
		return 0
	end
	local normalized = (magnitude - CAMERA_VERTICAL_DEADZONE) / (1 - CAMERA_VERTICAL_DEADZONE)
	return math.sign(lookY) * math.clamp(normalized, 0, 1)
end

local function safeFlightVelocity(character, root, desiredVelocity, dt)
	if desiredVelocity.Magnitude <= 0.01 then return Vector3.zero end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}
	params.IgnoreWater = false

	local displacement = desiredVelocity * math.max(dt, 1 / 120)
	local direction = displacement.Unit
	local distance = displacement.Magnitude + COLLISION_PADDING
	local cast = workspace:Blockcast(root.CFrame, BODY_BOX_SIZE, direction * distance, params)
	if not cast then return desiredVelocity end

	local allowedDistance = math.max(0, cast.Distance - COLLISION_PADDING)
	local scale = displacement.Magnitude > 0 and math.clamp(allowedDistance / displacement.Magnitude, 0, 1) or 0
	return desiredVelocity * scale
end

local function startFlight()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end

	flying = true
	attachment = Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
	attachment.Parent = root

	velocity = Instance.new("LinearVelocity")
	velocity.Name = "FlightVelocity"
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	orientation = Instance.new("AlignOrientation")
	orientation.Name = "FlightOrientation"
	orientation.Attachment0 = attachment
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Responsiveness = 18
	orientation.MaxTorque = math.huge
	orientation.Parent = root

	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	FlightUI.setActive(view, true)

	connection = RunService.RenderStepped:Connect(function(dt)
		if not flying or not root.Parent or humanoid.Health <= 0 then
			stopFlight()
			return
		end

		local camera = workspace.CurrentCamera
		if not camera then return end

		local move = humanoid.MoveDirection
		local horizontalMagnitude = math.min(Vector3.new(move.X, 0, move.Z).Magnitude, 1)
		local vertical = cameraVertical(camera.CFrame.LookVector.Y) * horizontalMagnitude

		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			vertical = 1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			vertical = -1
		end

		local direction = Vector3.new(move.X, vertical, move.Z)
		if direction.Magnitude > 1 then direction = direction.Unit end
		local desiredVelocity = direction * SPEED
		velocity.VectorVelocity = safeFlightVelocity(character, root, desiredVelocity, dt)

		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then
			orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook.Unit)
		end
	end)
end

local function toggleFlight()
	if flying then stopFlight() else startFlight() end
end

view.button.Activated:Connect(toggleFlight)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.ButtonL2 then
		toggleFlight()
	end
end)

player.CharacterAdded:Connect(stopFlight)
