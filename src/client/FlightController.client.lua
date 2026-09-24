local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FlightUI = require(script.Parent.FlightUI)
local player = Players.LocalPlayer
local view = FlightUI.create(player:WaitForChild("PlayerGui"))

local flying = false
local verticalInput = 0
local connection
local attachment
local velocity
local orientation
local SPEED = 42

local function stopFlight()
	flying = false
	verticalInput = 0
	if connection then connection:Disconnect() connection = nil end
	if velocity then velocity:Destroy() velocity = nil end
	if orientation then orientation:Destroy() orientation = nil end
	if attachment then attachment:Destroy() attachment = nil end
	FlightUI.setActive(view, false)
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

	connection = RunService.RenderStepped:Connect(function()
		if not flying or not root.Parent or humanoid.Health <= 0 then
			stopFlight()
			return
		end

		local move = humanoid.MoveDirection
		local keyboardVertical = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then keyboardVertical += 1 end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then keyboardVertical -= 1 end
		local vertical = math.clamp(verticalInput + keyboardVertical, -1, 1)

		local direction = Vector3.new(move.X, vertical, move.Z)
		if direction.Magnitude > 1 then direction = direction.Unit end
		velocity.VectorVelocity = direction * SPEED

		local camera = workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0.01 then
				orientation.CFrame = CFrame.lookAt(Vector3.zero, flatLook.Unit)
			end
		end
	end)
end

local function toggleFlight()
	if flying then stopFlight() else startFlight() end
end

local function bindHold(button, value)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			verticalInput = value
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if verticalInput == value then verticalInput = 0 end
		end
	end)
end

view.button.Activated:Connect(toggleFlight)
bindHold(view.up, 1)
bindHold(view.down, -1)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.ButtonL2 then
		toggleFlight()
	end
end)

player.CharacterAdded:Connect(stopFlight)
