local outputPath = ...
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = Instance.new("DataModel")
place.Name = "Museu Empire"

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
floor.Name = "MuseumFloor"
floor.Anchored = true
floor.Size = Vector3.new(220, 2, 220)
floor.Position = Vector3.new(0, 0, 0)
floor.Material = "SmoothPlastic"
floor.Color = Color3.fromRGB(78, 82, 90)
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "MuseumSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 3, 0)
spawn.Material = "Neon"
spawn.Color = Color3.fromRGB(70, 200, 120)
spawn.Parent = workspace

local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
    starterPlayerScripts = Instance.new("StarterPlayerScripts")
    starterPlayerScripts.Name = "StarterPlayerScripts"
    starterPlayerScripts.Parent = starterPlayer
end

local client = Instance.new("LocalScript")
client.Name = "MuseuEmpireBoot"
client.Source = [=[
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MuseuEmpireUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 12)
label.Size = UDim2.fromOffset(300, 44)
label.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.Font = Enum.Font.GothamBold
label.TextSize = 15
label.Text = "MUSEU EMPIRE · BUILD LIMPO"
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
print("[Museu Empire] clean DataModel prepared")
