local Services = script.Parent:WaitForChild("Services")

local PlayerDataService = require(Services.PlayerDataService)
local LandService = require(Services.LandService)
local BuildService = require(Services.BuildService)
local BuildPlacementGuard = require(Services.BuildPlacementGuard)

local started = false

local function startServer()
	if started then
		return
	end
	started = true

	PlayerDataService:Start()
	LandService:Start(PlayerDataService)
	BuildService:Start(PlayerDataService)
	BuildPlacementGuard:Start()
	print("[Property Empire v2] Server started")
end

startServer()
