local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AttackUI = require(script.Parent.AttackUI)
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("AttackRequest")
local view = AttackUI.create(player:WaitForChild("PlayerGui"))

local ready = true
local COOLDOWN = 0.45

local function attack()
	if not ready then return end
	ready = false
	remote:FireServer()
	task.delay(COOLDOWN, function()
		ready = true
	end)
end

view.button.Activated:Connect(attack)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		attack()
	end
end)
