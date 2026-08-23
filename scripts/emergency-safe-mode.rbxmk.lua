local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)
local players = place:GetService("Players")
local sss = place:GetService("ServerScriptService")
local starterGui = place:GetService("StarterGui")
local starterPlayer = place:GetService("StarterPlayer")
local starterPack = place:GetService("StarterPack")
local replicatedFirst = place:GetService("ReplicatedFirst")
local workspace = place:GetService("Workspace")

players.CharacterAutoLoads = true

-- Absolute diagnostic boot: no legacy/gameplay code is allowed to execute.
for _, child in ipairs(sss:GetChildren()) do child:Destroy() end
for _, child in ipairs(starterGui:GetChildren()) do child:Destroy() end
for _, child in ipairs(starterPack:GetChildren()) do child:Destroy() end
for _, child in ipairs(replicatedFirst:GetChildren()) do child:Destroy() end

local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
    starterPlayerScripts = Instance.new("StarterPlayerScripts")
    starterPlayerScripts.Name = "StarterPlayerScripts"
    starterPlayerScripts.Parent = starterPlayer
end
for _, child in ipairs(starterPlayerScripts:GetChildren()) do child:Destroy() end

local starterCharacterScripts = starterPlayer:FindFirstChild("StarterCharacterScripts")
if starterCharacterScripts then
    for _, child in ipairs(starterCharacterScripts:GetChildren()) do child:Destroy() end
end

for _, inst in ipairs(workspace:GetDescendants()) do
    if inst:IsA("Script") or inst:IsA("LocalScript") then
        inst:Destroy()
    end
end

local oldSpawn = workspace:FindFirstChild("MiningEmpireEmergencySpawn")
if oldSpawn then oldSpawn:Destroy() end
local oldPlatform = workspace:FindFirstChild("MiningEmpireEmergencyPlatform")
if oldPlatform then oldPlatform:Destroy() end

local platform = Instance.new("Part")
platform.Name = "MiningEmpireEmergencyPlatform"
platform.Anchored = true
platform.Size = Vector3.new(120, 3, 120)
platform.Position = Vector3.new(0, 30, 0)
platform.Color = Color3.fromRGB(45, 52, 62)
platform.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "MiningEmpireEmergencySpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Enabled = true
spawn.Size = Vector3.new(14, 1, 14)
spawn.Position = Vector3.new(0, 32, 0)
spawn.Transparency = 0.15
spawn.Color = Color3.fromRGB(40, 190, 100)
spawn.Parent = workspace

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireEmergencyClient"
client.Source = [=[
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local BUILD = "SAFE MODE 18:34"

local function addMarker()
    if gui:FindFirstChild("MiningEmpireEmergencyUI") then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "MiningEmpireEmergencyUI"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 9999
    sg.Parent = gui

    local label = Instance.new("TextLabel")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0, 12)
    label.Size = UDim2.fromOffset(260, 42)
    label.BackgroundColor3 = Color3.fromRGB(25, 145, 80)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
    label.Text = "MINING EMPIRE · " .. BUILD
    label.Parent = sg

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = label
end

local function unlock(character)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
    local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
    if humanoid then
        humanoid.WalkSpeed = 16
        local camera = workspace.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = humanoid
        end
    end
    if root then character:PivotTo(CFrame.new(0, 36, 0)) end
end

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
addMarker()

task.spawn(function()
    local character = player.Character or player.CharacterAdded:Wait()
    task.wait(0.2)
    unlock(character)
    addMarker()
end)

player.CharacterAdded:Connect(function(character)
    task.wait(0.2)
    unlock(character)
    addMarker()
end)

print("[Mining Empire] emergency safe mode client active")
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] emergency SAFE MODE applied")
