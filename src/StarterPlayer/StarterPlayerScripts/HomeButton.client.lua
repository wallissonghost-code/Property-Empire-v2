local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MuseumRemotes")
local returnRemote = remotes:WaitForChild("ReturnToMuseum")

local gui = Instance.new("ScreenGui")
gui.Name = "MuseumHomeButton"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "ReturnHome"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -18, 1, -22)
button.Size = UDim2.fromOffset(188, 48)
button.BackgroundColor3 = Color3.fromRGB(31, 42, 50)
button.BackgroundTransparency = 0.08
button.Text = "⌂  VOLTAR AO MEU MUSEU"
button.TextColor3 = Color3.fromRGB(245, 247, 249)
button.Font = Enum.Font.GothamBold
button.TextSize = 13
button.TextWrapped = true
button.AutoButtonColor = true
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(93, 124, 132)
stroke.Transparency = 0.25
stroke.Thickness = 1
stroke.Parent = button

local busy = false
button.Activated:Connect(function()
	if busy then return end
	busy = true
	local old = button.Text
	button.Text = "VOLTANDO..."
	local ok, success, message = pcall(function()
		return returnRemote:InvokeServer()
	end)
	if not ok or not success then
		button.Text = message or "MUSEU INDISPONÍVEL"
		task.wait(1.4)
	end
	button.Text = old
	busy = false
end)
