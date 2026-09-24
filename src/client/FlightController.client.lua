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
local BODY_HALF_HEIGHT = BODY_BOX_SIZE.Y * 0.5
local CONTACT_PROBE = 0.55
local FLIGHT_FOV = 78
local MAX_BODY_PITCH = math.rad(28)
local MAX_BODY_ROLL = math.rad(18)
local MAX_CAMERA_ROLL = math.rad(4)
local VISUAL_RESPONSE = 7
local defaultFov = 70
local visualPitch = 0
local visualRoll = 0
local cameraRoll = 0
local preservedMomentum = Vector3.zero
local lastSafeCFrame

local function stopFlight(preserveMomentum)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and preserveMomentum ~= false then
		preservedMomentum = root.AssemblyLinearVelocity
	elseif preserveMomentum == false then
		preservedMomentum = Vector3.zero
	end
	flying = false
	visualPitch = 0
	visualRoll = 0
	cameraRoll = 0
	local camera = workspace.CurrentCamera
	if camera then camera.FieldOfView = defaultFov end
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

	-- Keep the collision volume upright. The character may visually bank/pitch,
	-- but the safety hull must continue covering head, torso, arms and legs.
	local collisionFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
	local cast = workspace:Blockcast(collisionFrame, BODY_BOX_SIZE, direction * distance, params)
	if cast then
		local normal = cast.Normal
		local intoSurface = desiredVelocity:Dot(normal)
		if intoSurface < 0 then
			-- Remove only the velocity pushing into the surface. Tangential movement
			-- remains available so walls do not pin or rotate the character.
			return desiredVelocity - normal * intoSurface
		end
		return desiredVelocity
	end

	-- A short upright overlap/proximity sweep catches side contacts where the
	-- physical rig is already touching a wall before the next movement sweep.
	local contactCast = workspace:Blockcast(collisionFrame, BODY_BOX_SIZE, direction * CONTACT_PROBE, params)
	if contactCast then
		local normal = contactCast.Normal
		local intoSurface = desiredVelocity:Dot(normal)
		if intoSurface < 0 then
			return desiredVelocity - normal * intoSurface
		end
	end

	-- Extra vertical probes protect thin floors/ceilings when the rig is already
	-- very close to a surface and a sweep starts near contact.
	if desiredVelocity.Y < 0 then
		local origin = root.Position - Vector3.new(0, BODY_HALF_HEIGHT - 0.25, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, -(math.abs(displacement.Y) + COLLISION_PADDING + 0.35), 0), params)
		if hit then return Vector3.new(desiredVelocity.X, 0, desiredVelocity.Z) end
	elseif desiredVelocity.Y > 0 then
		local origin = root.Position + Vector3.new(0, BODY_HALF_HEIGHT - 0.25, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, math.abs(displacement.Y) + COLLISION_PADDING + 0.35, 0), params)
		if hit then return Vector3.new(desiredVelocity.X, 0, desiredVelocity.Z) end
	end

	return desiredVelocity
end

local function startFlight()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end

	local camera = workspace.CurrentCamera
	if camera then defaultFov = camera.FieldOfView end

	local entryVelocity = root.AssemblyLinearVelocity
	if preservedMomentum.Magnitude > entryVelocity.Magnitude then
		entryVelocity = preservedMomentum
	end
	preservedMomentum = Vector3.zero

	flying = true
	lastSafeCFrame = root.CFrame
	attachment = Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
	attachment.Parent = root

	velocity = Instance.new("LinearVelocity")
	velocity.Name = "FlightVelocity"
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = entryVelocity
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
		local currentVelocity = root.AssemblyLinearVelocity
		local controlStrength = math.clamp(direction.Magnitude, 0, 1)
		local recoveryRate = 2.8 + (5.2 * controlStrength)
		local alphaVelocity = 1 - math.exp(-recoveryRate * dt)
		local commandedVelocity = currentVelocity:Lerp(desiredVelocity, alphaVelocity)
		local safeVelocity = safeFlightVelocity(character, root, commandedVelocity, dt)
		velocity.VectorVelocity = safeVelocity
		if safeVelocity.Magnitude > 0.01 then
			lastSafeCFrame = root.CFrame
		end

		local look = camera.CFrame.LookVector
		local flatLook = Vector3.new(look.X, 0, look.Z)
		if flatLook.Magnitude > 0.01 then
			local cameraRight = camera.CFrame.RightVector
			local sideInput = move:Dot(Vector3.new(cameraRight.X, 0, cameraRight.Z).Unit)
			local forwardInput = move:Dot(flatLook.Unit)
			local alpha = 1 - math.exp(-VISUAL_RESPONSE * dt)
			visualPitch += ((-MAX_BODY_PITCH * math.max(forwardInput, 0)) - visualPitch) * alpha
			visualRoll += ((-MAX_BODY_ROLL * sideInput) - visualRoll) * alpha
			cameraRoll += ((-MAX_CAMERA_ROLL * sideInput) - cameraRoll) * alpha
			-- Keep the physical HumanoidRootPart upright. Banking/pitching the root
			-- changes the collision assembly and caused the rig to wedge into walls.
			orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook.Unit)
			camera.FieldOfView += ((FLIGHT_FOV - camera.FieldOfView) * alpha)
			camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, cameraRoll)
		end
	end)
end

local function toggleFlight()
	if flying then stopFlight(true) else startFlight() end
end

view.button.Activated:Connect(toggleFlight)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.ButtonL2 then
		toggleFlight()
	end
end)

player.CharacterAdded:Connect(function()
	lastSafeCFrame = nil
	stopFlight(false)
end)
