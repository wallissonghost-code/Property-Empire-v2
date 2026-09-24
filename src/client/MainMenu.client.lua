local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MenuUI = require(script.Parent.MenuUI)
local remote = ReplicatedStorage:WaitForChild("MainMenuState")
local purchaseRemote = ReplicatedStorage:WaitForChild("SkillPurchaseRequest")
local stateRemote = ReplicatedStorage:WaitForChild("SkillState")
local view = MenuUI.create(Players.LocalPlayer:WaitForChild("PlayerGui"))

local function hide()
	view.gui.Enabled = false
end

local function show()
	if view.gui.Enabled then return end
	view.gui.Enabled = true
	view.panel.Position = UDim2.fromScale(0.5, 0.525)
	view.panel.BackgroundTransparency = 0.08
	TweenService:Create(view.panel, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0,
	}):Play()
end

view.close.Activated:Connect(hide)
view.buyLaserEyes.Activated:Connect(function()
	purchaseRemote:FireServer("LaserEyes")
end)

stateRemote.OnClientEvent:Connect(function(state)
	if state.laserEyes then
		view.buyLaserEyes.Text = "COMPRADO"
		view.buyLaserEyes.Active = false
		view.buyLaserEyes.BackgroundColor3 = Color3.fromRGB(36, 96, 67)
		view.buyLaserEyes.TextColor3 = Color3.fromRGB(220, 240, 228)
	end
end)

remote.OnClientEvent:Connect(function(isOpen)
	if isOpen then
		show()
	else
		hide()
	end
end)
