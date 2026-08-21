local Services = script.Parent:WaitForChild("Services")

local PlayerDataService = require(Services.PlayerDataService)

local started = false

local function startServer()
	if started then
		return
	end
	started = true

	PlayerDataService:Start()
	print("[Property Empire v2] Server started")
end

startServer()
