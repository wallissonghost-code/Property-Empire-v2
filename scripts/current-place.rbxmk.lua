local outputPath = ...
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

-- Build a brand-new DataModel. Do not read or inherit any previous .rbxl.
local place = Instance.new("DataModel")
place.Name = "Mining Empire"

local players = place:GetService("Players")
local workspace = place:GetService("Workspace")
local lighting = place:GetService("Lighting")
local starterPlayer = place:GetService("StarterPlayer")

players.CharacterAutoLoads = true

lighting.Brightness = 2
lighting.ClockTime = 14
lighting.Ambient = Color3.fromRGB(120, 120, 120)
lighting.OutdoorAmbient = Color3.fromRGB(145, 145, 145)

local floor = Instance.new("Part")
floor.Name = "CurrentFloor"
floor.Anchored = true
floor.Size = Vector3.new(200, 2, 200)
floor.Position = Vector3.new(0, 0, 0)
floor.Material = "SmoothPlastic"
floor.Color = Color3.fromRGB(70, 76, 86)
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "CurrentSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 3, 0)
spawn.Transparency = 0.1
spawn.Material = "Neon"
spawn.Color = Color3.fromRGB(50, 180, 95)
spawn.Parent = workspace

local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
    starterPlayerScripts = Instance.new("StarterPlayerScripts")
    starterPlayerScripts.Name = "StarterPlayerScripts"
    starterPlayerScripts.Parent = starterPlayer
end

local client = Instance.new("LocalScript")
client.Name = "CurrentBoot"
client.Source = [=[
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MiningEmpireCurrentUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 12)
label.Size = UDim2.fromOffset(280, 42)
label.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Font = Enum.Font.GothamBold
label.TextSize = 14
label.Text = "MINING EMPIRE · CURRENT BUILD"
label.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
if humanoid and workspace.CurrentCamera then
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    workspace.CurrentCamera.CameraSubject = humanoid
end
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] brand-new current DataModel prepared from scratch")
