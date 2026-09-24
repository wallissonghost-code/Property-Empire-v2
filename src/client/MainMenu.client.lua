local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MenuUI = require(script.Parent.MenuUI)
local remote = ReplicatedStorage:WaitForChild("MainMenuState")
local view = MenuUI.create(Players.LocalPlayer:WaitForChild("PlayerGui"))

local function hide()
	view.gui.Enabled = false
end

local function show()
	view.gui.Enabled = true
	view.panel.Position = UDim2.fromScale(0.5, 0.525)
	view.panel.BackgroundTransparency = 0.08
	TweenService:Create(view.panel, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0,
	}):Play()
end

view.close.Activated:Connect(hide)
remote.OnClientEvent:Connect(function(isOpen)\n\tif isOpen then show() else hide() end\nend)
