local outputPath = ...
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = Instance.new("DataModel")
place.Name = "Museu Empire Diagnostic"

local players = place:GetService("Players")
local workspace = place:GetService("Workspace")
local lighting = place:GetService("Lighting")

players.CharacterAutoLoads = true
lighting.Brightness = 2
lighting.ClockTime = 14

local floor = Instance.new("Part")
floor.Name = "DiagnosticFloor"
floor.Anchored = true
floor.Size = Vector3.new(160, 2, 160)
floor.Position = Vector3.new(0, 0, 0)
floor.Color = Color3.fromRGB(95, 95, 95)
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "DiagnosticSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 3, 0)
spawn.Color = Color3.fromRGB(50, 200, 100)
spawn.Parent = workspace

fs.write(outputPath, place)
print("[Museu Empire] diagnostic place prepared")
