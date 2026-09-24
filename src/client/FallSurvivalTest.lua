local FallSurvivalTest = {}

local LETHAL_SPEED = 300
local FLIGHT_RECOVERY_RATE = 2.8
local GRAVITY = workspace.Gravity
local STEP = 1 / 60
local MAX_SIMULATION_TIME = 8

function FallSurvivalTest.predict(altitude, verticalVelocity)
	if altitude <= 0 or verticalVelocity >= 0 then
		return nil
	end

	local height = altitude
	local velocity = verticalVelocity
	local elapsed = 0

	while height > 0 and elapsed < MAX_SIMULATION_TIME do
		local recoveryAlpha = 1 - math.exp(-FLIGHT_RECOVERY_RATE * STEP)
		velocity += (0 - velocity) * recoveryAlpha
		height += velocity * STEP
		elapsed += STEP
	end

	local impactSpeed = math.max(0, -velocity)
	return {
		survives = impactSpeed < LETHAL_SPEED,
		estimatedImpactSpeed = impactSpeed,
	}
end

return FallSurvivalTest
