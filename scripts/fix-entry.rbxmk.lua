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

-- Remove the legacy save-slot/loading screen that can hang forever on old data calls.
for _, child in ipairs(starterGui:GetChildren()) do
	local n = string.lower(child.Name or "")
	if n == "loadgui" or n == "loadinggui" then
		child:Destroy()
	end
end

-- Hide old creator/social branding that is not part of Mining Empire's identity.
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
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function clearLegacyLoaders()
	for _, gui in ipairs(playerGui:GetChildren()) do
		local n = string.lower(gui.Name or "")
		if n == "loadgui" or n == "loadinggui" then
			gui:Destroy()
		end
	end
end

local function unlockCharacterCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
		humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, 16)
	end
end

local function ensureMainGui()
	local existing = playerGui:FindFirstChild("GUI")
	if existing then
		local cover = existing:FindFirstChild("Cover", true)
		if cover and cover:IsA("GuiObject") then cover.Visible = false end
		return existing
	end
	local template = ReplicatedStorage:FindFirstChild("GUI")
	if template then
		local clone = template:Clone()
		clone.Parent = playerGui
		local cover = clone:FindFirstChild("Cover", true)
		if cover and cover:IsA("GuiObject") then cover.Visible = false end
		return clone
	end
	return nil
end

clearLegacyLoaders()
task.defer(unlockCharacterCamera)

-- Give the original Main server script a moment to move GUI into ReplicatedStorage.
task.spawn(function()
	for _ = 1, 50 do
		if ensureMainGui() then break end
		task.wait(0.1)
	end
	clearLegacyLoaders()
	unlockCharacterCamera()
end)

-- Attempt slot 1 in the background for compatibility with legacy tycoon systems.
-- This must never block entry into Mining Empire.
task.spawn(function()
	local quickLoad = ReplicatedStorage:FindFirstChild("QuickLoad") or ReplicatedStorage:WaitForChild("QuickLoad", 8)
	if quickLoad and quickLoad:IsA("RemoteFunction") then
		pcall(function()
			quickLoad:InvokeServer(1)
		end)
	end
end)

-- Keep old covers/loaders from reappearing after respawn or delayed scripts.
playerGui.ChildAdded:Connect(function(child)
	task.defer(function()
		local n = string.lower(child.Name or "")
		if n == "loadgui" or n == "loadinggui" then
			child:Destroy()
			return
		end
		local cover = child:FindFirstChild("Cover", true)
		if cover and cover:IsA("GuiObject") then cover.Visible = false end
	end)
end)

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	clearLegacyLoaders()
	unlockCharacterCamera()
	ensureMainGui()
end)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
end)

print("[Mining Empire] Direct-entry compatibility mode enabled")
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] legacy loading screen removed; direct entry injected")
