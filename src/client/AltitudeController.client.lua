local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AltitudeUI = require(script.Parent.AltitudeUI)
local player = Players.LocalPlayer
local view = AltitudeUI.create(player:WaitForChild("PlayerGui"))

local UPDATE_INTERVAL = 0.08
local FEET_OFFSET = 3
local elapsed = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < UPDATE_INTERVAL then return end
	elapsed = 0

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		AltitudeUI.setAltitude(view, 0)
		return
	end

	rayParams.FilterDescendantsInstances = {character}
	local result = workspace:Raycast(root.Position, Vector3.new(0, -4096, 0), rayParams)
	local altitude = result and math.max(0, root.Position.Y - result.Position.Y - FEET_OFFSET) or math.max(0, root.Position.Y - FEET_OFFSET)
	AltitudeUI.setAltitude(view, altitude)
end)
