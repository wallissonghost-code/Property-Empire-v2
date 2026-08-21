local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local BuildController = require(script.Parent:WaitForChild("BuildController"))
local BusinessController = require(script.Parent:WaitForChild("BusinessController"))
local BusinessEconomyController = require(script.Parent:WaitForChild("BusinessEconomyController"))

BuildController:Start()
BusinessController:Start()
BusinessEconomyController:Start()
print(string.format("[Property Empire v2] Client started for %s", localPlayer.Name))
