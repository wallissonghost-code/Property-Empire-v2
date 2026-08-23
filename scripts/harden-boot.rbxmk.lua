local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)
local players = place:GetService("Players")
local sss = place:GetService("ServerScriptService")
local starterGui = place:GetService("StarterGui")
local starterPlayer = place:GetService("StarterPlayer")
local workspace = place:GetService("Workspace")

players.CharacterAutoLoads = true

-- Remove every legacy auto-running server initializer. Keep only Mining Empire services injected by earlier stages.
local keepServer = {
	MiningEmpireMuseumBootstrap = true,
	MiningEmpireVisitorService = true,
}
for _, child in ipairs(sss:GetChildren()) do
	if not keepServer[child.Name] then
		child:Destroy()
	end
end

-- Remove all legacy StarterGui content so no old cover/loading/menu can block the viewport.
for _, child in ipairs(starterGui:GetChildren()) do
	child:Destroy()
end

local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

local keepClient = {
	MiningEmpireTravelUI = true,
	MiningEmpireMuseumEconomyUI = true,
	MiningEmpireSafeHUDV2 = true,
}
for _, child in ipairs(starterPlayerScripts:GetChildren()) do
	if not keepClient[child.Name] then
		child:Destroy()
	end
end

local starterCharacterScripts = starterPlayer:FindFirstChild("StarterCharacterScripts")
if starterCharacterScripts then
	for _, child in ipairs(starterCharacterScripts:GetChildren()) do
		child:Destroy()
	end
end

-- Disable legacy scripts embedded in the old map/models. Assets remain available as scenery.
for _, inst in ipairs(workspace:GetDescendants()) do
	if inst:IsA("Script") or inst:IsA("LocalScript") then
		inst.Disabled = true
	end
end

-- Guaranteed safe spawn and platform, independent of legacy tycoon/save state.
local oldSpawn = workspace:FindFirstChild("MiningEmpireSafeSpawn")
if oldSpawn then oldSpawn:Destroy() end
local platform = workspace:FindFirstChild("MiningEmpireBootPlatform")
if platform then platform:Destroy() end

platform = Instance.new("Part")
platform.Name = "MiningEmpireBootPlatform"
platform.Anchored = true
platform.Size = Vector3.new(90, 2, 90)
platform.Position = Vector3.new(0, 18, -500)
platform.Material = "Slate"
platform.Color = Color3.fromRGB(55, 62, 72)
platform.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "MiningEmpireSafeSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 20, -500)
spawn.Transparency = 0.25
spawn.Material = "Neon"
spawn.Color = Color3.fromRGB(44, 164, 96)
spawn.Parent = workspace

local boot = Instance.new("LocalScript")
boot.Name = "MiningEmpireBootGuard"
boot.Source = [=[
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SAFE = CFrame.new(0, 24, -500)
local BUILD = "BOOT CLEAN 18:25"

local function marker()
	local gui = playerGui:FindFirstChild("MiningEmpireBootMarker")
	if gui then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "MiningEmpireBootMarker"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2000
	gui.Parent = playerGui
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(1,1)
	t.Position = UDim2.new(1,-8,1,-8)
	t.Size = UDim2.fromOffset(150,30)
	t.BackgroundColor3 = Color3.fromRGB(30,145,82)
	t.TextColor3 = Color3.new(1,1,1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 11
	t.Text = BUILD
	t.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0,8)
	c.Parent = t
end

local function cleanPlayerGui()
	for _, gui in ipairs(playerGui:GetChildren()) do
		local n = gui.Name
		if gui:IsA("ScreenGui") and n ~= "MiningEmpireTravelUI" and n ~= "MiningEmpireMuseumEconomyUI" and n ~= "MiningEmpireBootMarker" then
			if string.find(n, "MiningEmpire", 1, true) == nil then
				gui:Destroy()
			end
		end
	end
end

local function unlock(character, force)
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 8)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
	local camera = workspace.CurrentCamera
	if humanoid then
		humanoid.WalkSpeed = 16
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end
	if force and root then character:PivotTo(SAFE) end
end

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
cleanPlayerGui()
marker()

task.spawn(function()
	local character = player.Character or player.CharacterAdded:Wait()
	unlock(character, true)
	for _ = 1, 16 do
		task.wait(0.25)
		cleanPlayerGui()
		marker()
		unlock(player.Character, false)
	end
end)

player.CharacterAdded:Connect(function(character)
	task.wait(0.2)
	unlock(character, true)
	cleanPlayerGui()
	marker()
end)

playerGui.ChildAdded:Connect(function()
	task.delay(0.05, cleanPlayerGui)
end)

print("[Mining Empire] clean boot guard active: " .. BUILD)
]=]
boot.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] hard boot isolation applied")
