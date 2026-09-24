local outputPath = ...
assert(type(outputPath) == "string" and outputPath ~= "", "missing output path")

local place = Instance.new("DataModel")
place.Name = "Clean Base"

local workspace = place:GetService("Workspace")
local lighting = place:GetService("Lighting")
local players = place:GetService("Players")
local starterPlayer = place:GetService("StarterPlayer")
local serverScripts = place:GetService("ServerScriptService")
players.CharacterAutoLoads = true
starterPlayer.CharacterWalkSpeed = 16
starterPlayer.CharacterJumpPower = 50

lighting.Brightness = 2
lighting.ClockTime = 14

local base = Instance.new("Part")
base.Name = "Baseplate"
base.Anchored = true
base.Size = Vector3.new(512, 1, 512)
base.Position = Vector3.new(0, 0, 0)
base.Color = Color3.fromRGB(99, 95, 98)
base.Material = "SmoothPlastic"
base.TopSurface = "Smooth"
base.BottomSurface = "Smooth"
base.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "SpawnLocation"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 1, 0)
spawn.Parent = workspace

fs.write(outputPath, place)
print("[Clean Base] flat place prepared")
