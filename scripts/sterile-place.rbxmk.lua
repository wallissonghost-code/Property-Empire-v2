local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)

local players = place:GetService("Players")
local workspace = place:GetService("Workspace")
local starterGui = place:GetService("StarterGui")
local starterPlayer = place:GetService("StarterPlayer")
local serverScriptService = place:GetService("ServerScriptService")
local replicatedStorage = place:GetService("ReplicatedStorage")
local replicatedFirst = place:GetService("ReplicatedFirst")
local lighting = place:GetService("Lighting")
local teams = place:GetService("Teams")

players.CharacterAutoLoads = true

local function clear(service)
	for _, child in ipairs(service:GetChildren()) do
		child:Destroy()
	end
end

clear(workspace)
clear(starterGui)
clear(serverScriptService)
clear(replicatedStorage)
clear(replicatedFirst)
clear(teams)

local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
else
	clear(starterPlayerScripts)
end

local starterCharacterScripts = starterPlayer:FindFirstChild("StarterCharacterScripts")
if not starterCharacterScripts then
	starterCharacterScripts = Instance.new("StarterCharacterScripts")
	starterCharacterScripts.Name = "StarterCharacterScripts"
	starterCharacterScripts.Parent = starterPlayer
else
	clear(starterCharacterScripts)
end

lighting.Brightness = 2
lighting.ClockTime = 14
lighting.Ambient = Color3.fromRGB(120, 120, 120)
lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)

local floor = Instance.new("Part")
floor.Name = "SterileFloor"
floor.Anchored = true
floor.Size = Vector3.new(180, 2, 180)
floor.Position = Vector3.new(0, 0, 0)
floor.Material = "SmoothPlastic"
floor.Color = Color3.fromRGB(72, 78, 88)
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SterileSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 3, 0)
spawn.Transparency = 0.15
spawn.Material = "Neon"
spawn.Color = Color3.fromRGB(56, 180, 92)
spawn.Parent = workspace

local client = Instance.new("LocalScript")
client.Name = "SterileBootMarker"
client.Source = [=[
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "SterileBootUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5000
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5,0)
label.Position = UDim2.new(0.5,0,0,12)
label.Size = UDim2.fromOffset(260,42)
label.BackgroundColor3 = Color3.fromRGB(18,22,28)
label.TextColor3 = Color3.fromRGB(255,255,255)
label.Font = Enum.Font.GothamBold
label.TextSize = 14
label.Text = "STERILE BOOT 18:54"
label.Parent = gui
Instance.new("UICorner", label).CornerRadius = UDim.new(0,10)

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
if humanoid and workspace.CurrentCamera then
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	workspace.CurrentCamera.CameraSubject = humanoid
end
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] sterile diagnostic place prepared")
