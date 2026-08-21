local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local BuildController = require(script.Parent:WaitForChild("BuildController"))

BuildController:Start()
print(string.format("[Property Empire v2] Client started for %s", localPlayer.Name))
