local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)

local function replaceBrand(text)
	if type(text) ~= "string" then return text, false end
	local original = text
	text = text:gsub("Miner's Haven", "Mining Empire")
	text = text:gsub("Miners Haven", "Mining Empire")
	text = text:gsub("Miner’s Haven", "Mining Empire")
	text = text:gsub("MINER'S HAVEN", "MINING EMPIRE")
	text = text:gsub("MINERS HAVEN", "MINING EMPIRE")
	return text, text ~= original
end

local renamedText = 0
local removedLegacy = 0

for _, instance in ipairs(place:GetDescendants()) do
	local className = instance.ClassName
	if className == "TextLabel" or className == "TextButton" or className == "TextBox" then
		local text = instance.Text
		if type(text) == "string" then
			local nextText, changed = replaceBrand(text)
			if changed then
				instance.Text = nextText
				renamedText = renamedText + 1
			end
		end
	end
end

local serverScriptService = place:GetService("ServerScriptService")
local starterPlayer = place:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

-- Remove obvious legacy telemetry/advertising scripts while leaving gameplay systems intact.
for _, instance in ipairs(serverScriptService:GetDescendants()) do
	local n = string.lower(instance.Name or "")
	if n == "analytics" or n == "gameanalytics" or n == "chatads" or n == "adminhunter" then
		instance:Destroy()
		removedLegacy = removedLegacy + 1
	end
end

local oldServer = serverScriptService:FindFirstChild("MiningEmpireMuseumBootstrap")
if oldServer then oldServer:Destroy() end
local oldClient = starterPlayerScripts:FindFirstChild("MiningEmpireTravelUI")
if oldClient then oldClient:Destroy() end

local server = Instance.new("Script")
server.Name = "MiningEmpireMuseumBootstrap"
server.Source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("MiningEmpireRemotes") or Instance.new("Folder")
remotes.Name = "MiningEmpireRemotes"
remotes.Parent = ReplicatedStorage

local travel = remotes:FindFirstChild("Travel") or Instance.new("RemoteEvent")
travel.Name = "Travel"
travel.Parent = remotes

local DISTRICT_ORIGIN = Vector3.new(0, 22, -1500)
local previousPositions = {}

local old = workspace:FindFirstChild("MiningEmpireMuseumDistrict")
if old then old:Destroy() end

local museum = Instance.new("Model")
museum.Name = "MiningEmpireMuseumDistrict"
museum.Parent = workspace

local function part(name, size, cf, material, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color or Color3.fromRGB(220, 224, 230)
	p.Parent = museum
	return p
end

part("MuseumFloor", Vector3.new(140, 2, 96), CFrame.new(DISTRICT_ORIGIN), Enum.Material.Marble, Color3.fromRGB(225, 225, 220))
part("BackWall", Vector3.new(140, 28, 2), CFrame.new(DISTRICT_ORIGIN + Vector3.new(0, 15, -47)), Enum.Material.Concrete, Color3.fromRGB(32, 38, 48))
part("LeftWall", Vector3.new(2, 28, 96), CFrame.new(DISTRICT_ORIGIN + Vector3.new(-69, 15, 0)), Enum.Material.Concrete, Color3.fromRGB(32, 38, 48))
part("RightWall", Vector3.new(2, 28, 96), CFrame.new(DISTRICT_ORIGIN + Vector3.new(69, 15, 0)), Enum.Material.Concrete, Color3.fromRGB(32, 38, 48))

local sign = part("MuseumSign", Vector3.new(48, 8, 2), CFrame.new(DISTRICT_ORIGIN + Vector3.new(0, 18, 46)), Enum.Material.Metal, Color3.fromRGB(24, 30, 40))
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Front
surface.Parent = sign
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "MINING EMPIRE · MUSEU"
label.TextColor3 = Color3.fromRGB(245, 205, 92)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Parent = surface

for i = 1, 8 do
	local col = ((i - 1) % 4) - 1.5
	local row = math.floor((i - 1) / 4)
	local pedestal = part("ArtifactPedestal_" .. i, Vector3.new(10, 4, 10), CFrame.new(DISTRICT_ORIGIN + Vector3.new(col * 27, 3, -8 + row * 28)), Enum.Material.Marble, Color3.fromRGB(242, 242, 238))
	pedestal:SetAttribute("ArtifactSlot", i)
	pedestal:SetAttribute("Empty", true)
end

local arrival = part("ArrivalPad", Vector3.new(18, 1, 12), CFrame.new(DISTRICT_ORIGIN + Vector3.new(0, 2, 36)), Enum.Material.Neon, Color3.fromRGB(64, 142, 222))
arrival.CanCollide = true

travel.OnServerEvent:Connect(function(player, destination)
	local character = player.Character
	if not character then return end
	if destination == "Museum" then
		previousPositions[player.UserId] = character:GetPivot()
		character:PivotTo(CFrame.new(DISTRICT_ORIGIN + Vector3.new(0, 6, 32)))
	elseif destination == "Mine" then
		local previous = previousPositions[player.UserId]
		if previous then
			character:PivotTo(previous)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	previousPositions[player.UserId] = nil
end)

print("[Mining Empire] Museum district online")
]=]
server.Parent = serverScriptService

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireTravelUI"
client.Source = [=[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local travel = ReplicatedStorage:WaitForChild("MiningEmpireRemotes"):WaitForChild("Travel")

local gui = Instance.new("ScreenGui")
gui.Name = "MiningEmpireTravelUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0, 12)
frame.Size = UDim2.fromOffset(250, 46)
frame.BackgroundColor3 = Color3.fromRGB(18, 23, 31)
frame.BackgroundTransparency = 0.08
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 13)

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = frame

local function button(text, destination, color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(116, 36)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = text
	b.Parent = frame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	b.Activated:Connect(function()
		travel:FireServer(destination)
	end)
end

button("⛏ MINA", "Mine", Color3.fromRGB(91, 72, 49))
button("🏛 MUSEU", "Museum", Color3.fromRGB(48, 83, 122))
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print(string.format("[Mining Empire] customized place: text=%d legacy_removed=%d", renamedText, removedLegacy))
