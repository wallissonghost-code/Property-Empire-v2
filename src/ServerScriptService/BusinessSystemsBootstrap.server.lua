local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Services = script.Parent:WaitForChild("Services")
local PlayerDataService = require(Services.PlayerDataService)
local BusinessService = require(Services.BusinessService)
local BusinessEconomyService = require(Services.BusinessEconomyService)
local MiningMuseumService = require(Services.MiningMuseumService)

local WORLD_NAME = "PropertyEmpireV2World"

-- Business systems depend on the generated world and lots. Starting them from
-- ServerMain created a race on live servers: the City Hall prompt could exist
-- while the licensing RemoteFunctions never came online.
PlayerDataService:Start()

local world = Workspace:WaitForChild(WORLD_NAME, 30)
if not world then
	warn("[Property Empire v2] Business bootstrap could not find the world")
	return
end

local lots = world:WaitForChild("Lots", 30)
local builds = world:WaitForChild("Builds", 30)
if not lots or not builds then
	warn("[Property Empire v2] Business bootstrap could not find Lots/Builds")
	return
end

BusinessService:Start(PlayerDataService)

local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local getBusinessState = remotes and remotes:WaitForChild("GetBusinessState", 10)
local licenseBusiness = remotes and remotes:WaitForChild("LicenseBusiness", 10)
if not getBusinessState or not licenseBusiness then
	warn("[Property Empire v2] Business licensing remotes were not created")
	return
end

BusinessEconomyService:Start(PlayerDataService)
MiningMuseumService:Start(PlayerDataService)
print("[Property Empire v2] Business systems bootstrap ready")
