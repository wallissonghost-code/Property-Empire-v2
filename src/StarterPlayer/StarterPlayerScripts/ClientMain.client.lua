local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local function startController(moduleName)
	task.spawn(function()
		local moduleScript = script.Parent:WaitForChild(moduleName, 30)
		if not moduleScript then
			warn(string.format("[Property Empire v2] Client module %s was not found", moduleName))
			return
		end

		local requireOk, controller = pcall(require, moduleScript)
		if not requireOk then
			warn(string.format("[Property Empire v2] Failed to require %s: %s", moduleName, tostring(controller)))
			return
		end

		local startOk, startError = pcall(function()
			controller:Start()
		end)
		if not startOk then
			warn(string.format("[Property Empire v2] Failed to start %s: %s", moduleName, tostring(startError)))
		end
	end)
end

startController("BuildController")
startController("BuildPolishController")
startController("BusinessController")
startController("BusinessEconomyController")
startController("MiningMuseumController")

print(string.format("[Property Empire v2] Client bootstrap started for %s", localPlayer.Name))
