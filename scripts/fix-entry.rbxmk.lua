local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)
local starterGui = place:GetService("StarterGui")
local starterPlayer = place:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

-- Remove legacy loaders that can wait forever on old save calls.
for _, child in ipairs(starterGui:GetChildren()) do
	local n = string.lower(child.Name or "")
	if n == "loadgui" or n == "loadinggui" then
		child:Destroy()
	end
end

-- Hide visible legacy creator branding at build time.
for _, instance in ipairs(place:GetDescendants()) do
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		local text = string.lower(instance.Text or "")
		if string.find(text, "berezaa", 1, true) or string.find(text, "twitch.tv/bereza", 1, true) then
			instance.Visible = false
		end
	end
end

local old = starterPlayerScripts:FindFirstChild("MiningEmpireDirectEntry")
if old then old:Destroy() end

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireDirectEntry"
client.Source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SAFE_SPAWN = CFrame.new(0, 40, -500)
local BUILD = "HOTFIX 18:20"

local function clearLegacyLoaders()
	for _, gui in ipairs(playerGui:GetChildren()) do
		local n = string.lower(gui.Name or "")
		if n == "loadgui" or n == "loadinggui" then
			gui:Destroy()
		end
	end
end

local function hideLegacyCovers()
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local cover = gui:FindFirstChild("Cover", true)
			if cover and cover:IsA("GuiObject") then
				cover.Visible = false
			end
		end
	end
end

local function unlockCharacterCamera(forcePosition)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if humanoid then
		humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, 16)
		humanoid.JumpPower = math.max(humanoid.JumpPower, 50)
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end
	if forcePosition and root then
		character:PivotTo(SAFE_SPAWN)
	end
end

local function ensureMainGui()
	local existing = playerGui:FindFirstChild("GUI")
	if existing then return existing end
	local template = ReplicatedStorage:FindFirstChild("GUI")
	if template then
		local clone = template:Clone()
		clone.Parent = playerGui
		return clone
	end
	return nil
end

local function ensureBuildMarker()
	local gui = playerGui:FindFirstChild("MiningEmpireBuildMarker")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "MiningEmpireBuildMarker"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.DisplayOrder = 1000
		gui.Parent = playerGui
		local label = Instance.new("TextLabel")
		label.Name = "Marker"
		label.AnchorPoint = Vector2.new(1,1)
		label.Position = UDim2.new(1,-8,1,-8)
		label.Size = UDim2.fromOffset(132,28)
		label.BackgroundColor3 = Color3.fromRGB(26,140,78)
		label.BackgroundTransparency = 0.08
		label.TextColor3 = Color3.new(1,1,1)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 11
		label.Text = BUILD
		label.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0,8)
		corner.Parent = label
	end
end

local function apply(forcePosition)
	clearLegacyLoaders()
	hideLegacyCovers()
	ensureMainGui()
	unlockCharacterCamera(forcePosition)
	ensureBuildMarker()
end

apply(false)

-- Force a playable character location after spawn; do not depend on legacy save loading.
task.spawn(function()
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart", 8)
	task.wait(0.35)
	apply(true)
	task.wait(1.5)
	apply(false)
end)

player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart", 8)
	task.wait(0.25)
	apply(true)
end)

playerGui.ChildAdded:Connect(function()
	task.delay(0.05, function() apply(false) end)
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.delay(0.05, function() unlockCharacterCamera(false) end)
end)

-- Never call QuickLoad here. The legacy save stack may hang; compatibility will be reintroduced later behind a timeout-safe adapter.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
end)

-- Reinforce entry for the first seconds while delayed legacy scripts finish.
task.spawn(function()
	for i = 1, 20 do
		task.wait(0.25)
		apply(false)
	end
end)

print("[Mining Empire] Forced direct-entry hotfix active: " .. BUILD)
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] forced-entry hotfix injected")
