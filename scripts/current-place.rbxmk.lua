local outputPath = ...
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = Instance.new("DataModel")
place.Name = "Museu Empire"

local players = place:GetService("Players")
local workspace = place:GetService("Workspace")
local lighting = place:GetService("Lighting")
local starterPlayer = place:GetService("StarterPlayer")
local serverScriptService = place:GetService("ServerScriptService")

players.CharacterAutoLoads = true
lighting.Brightness = 2.2
lighting.ClockTime = 14
lighting.Ambient = Color3.fromRGB(130, 130, 140)
lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

local function part(name, size, position, color, material, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Color = color
    p.Material = material or "SmoothPlastic"
    p.Parent = parent or workspace
    return p
end

local world = Instance.new("Folder")
world.Name = "MuseuEmpireWorld"
world.Parent = workspace

local ground = part("Ground", Vector3.new(320, 2, 320), Vector3.new(0, 0, 0), Color3.fromRGB(74, 88, 74), "Grass", world)

local museum = Instance.new("Model")
museum.Name = "StarterMuseum"
museum.Parent = world

local floor = part("MuseumFloor", Vector3.new(110, 2, 90), Vector3.new(0, 1, -20), Color3.fromRGB(225, 222, 215), "Marble", museum)
local back = part("BackWall", Vector3.new(110, 24, 2), Vector3.new(0, 13, -64), Color3.fromRGB(238, 236, 230), "Concrete", museum)
local left = part("LeftWall", Vector3.new(2, 24, 90), Vector3.new(-54, 13, -20), Color3.fromRGB(238, 236, 230), "Concrete", museum)
local right = part("RightWall", Vector3.new(2, 24, 90), Vector3.new(54, 13, -20), Color3.fromRGB(238, 236, 230), "Concrete", museum)
local frontLeft = part("FrontLeft", Vector3.new(42, 24, 2), Vector3.new(-34, 13, 24), Color3.fromRGB(238, 236, 230), "Concrete", museum)
local frontRight = part("FrontRight", Vector3.new(42, 24, 2), Vector3.new(34, 13, 24), Color3.fromRGB(238, 236, 230), "Concrete", museum)
local header = part("FrontHeader", Vector3.new(26, 7, 2), Vector3.new(0, 21.5, 24), Color3.fromRGB(30, 33, 42), "SmoothPlastic", museum)

local signGui = Instance.new("SurfaceGui")
signGui.Face = "Front"
signGui.CanvasSize = Vector2.new(900, 240)
signGui.Parent = header
local signText = Instance.new("TextLabel")
signText.Size = UDim2.new(1, 0, 1, 0)
signText.BackgroundTransparency = 1
signText.Text = "MUSEU EMPIRE"
signText.TextColor3 = Color3.fromRGB(245, 208, 108)
signText.Font = "GothamBlack"
signText.TextScaled = true
signText.Parent = signGui

local carpet = part("EntranceCarpet", Vector3.new(18, 0.4, 40), Vector3.new(0, 2.2, 16), Color3.fromRGB(110, 24, 32), "Fabric", museum)
local reception = part("Reception", Vector3.new(24, 5, 6), Vector3.new(0, 4.5, -2), Color3.fromRGB(83, 60, 44), "Wood", museum)

local displayBase = part("FirstDisplayBase", Vector3.new(12, 2, 12), Vector3.new(0, 3, -30), Color3.fromRGB(44, 46, 52), "Marble", museum)
local pedestal = part("FirstPedestal", Vector3.new(5, 7, 5), Vector3.new(0, 7.5, -30), Color3.fromRGB(230, 230, 228), "Marble", museum)

local artifact = part("AncientRelic", Vector3.new(3.2, 5, 3.2), Vector3.new(0, 13.5, -30), Color3.fromRGB(214, 168, 70), "Metal", museum)
artifact.Shape = "Ball"
artifact.Transparency = 1
artifact.CanCollide = false
artifact:SetAttribute("Purchased", false)

local purchasePad = part("BuyFirstRelic", Vector3.new(10, 1, 10), Vector3.new(18, 2.5, -30), Color3.fromRGB(50, 180, 95), "Neon", museum)
purchasePad:SetAttribute("Price", 100)

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "BuyPrompt"
prompt.ActionText = "Comprar relíquia"
prompt.ObjectText = "$100 · +$5/5s"
prompt.HoldDuration = 0.25
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.Parent = purchasePad

local padGui = Instance.new("BillboardGui")
padGui.Name = "PriceBillboard"
padGui.Size = UDim2.fromOffset(190, 60)
padGui.StudsOffset = Vector3.new(0, 3.5, 0)
padGui.AlwaysOnTop = true
padGui.Parent = purchasePad
local padText = Instance.new("TextLabel")
padText.Size = UDim2.new(1, 0, 1, 0)
padText.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
padText.BackgroundTransparency = 0.12
padText.TextColor3 = Color3.fromRGB(255, 255, 255)
padText.Text = "PRIMEIRA RELÍQUIA\n$100"
padText.Font = "GothamBold"
padText.TextScaled = true
padText.Parent = padGui
local padCorner = Instance.new("UICorner")
padCorner.CornerRadius = UDim.new(0, 10)
padCorner.Parent = padText

local spawn = Instance.new("SpawnLocation")
spawn.Name = "MuseumSpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.Position = Vector3.new(0, 3, 48)
spawn.Material = "Neon"
spawn.Color = Color3.fromRGB(70, 200, 120)
spawn.Parent = world

local server = Instance.new("Script")
server.Name = "MuseumGameServer"
server.Source = [=[
local Players = game:GetService("Players")
local workspace = game:GetService("Workspace")

local museum = workspace:WaitForChild("MuseuEmpireWorld"):WaitForChild("StarterMuseum")
local artifact = museum:WaitForChild("AncientRelic")
local pad = museum:WaitForChild("BuyFirstRelic")
local prompt = pad:WaitForChild("BuyPrompt")

local ownerUserId = 0
local incomePerTick = 0

local function setupPlayer(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local cash = Instance.new("IntValue")
    cash.Name = "Cash"
    cash.Value = 250
    cash.Parent = leaderstats

    local prestige = Instance.new("IntValue")
    prestige.Name = "Prestige"
    prestige.Value = 0
    prestige.Parent = leaderstats
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

prompt.Triggered:Connect(function(player)
    if artifact:GetAttribute("Purchased") then return end
    if ownerUserId ~= 0 and ownerUserId ~= player.UserId then return end

    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Cash")
    if not cash then return end

    local price = pad:GetAttribute("Price") or 100
    if cash.Value < price then return end

    cash.Value -= price
    ownerUserId = player.UserId
    artifact:SetAttribute("Purchased", true)
    artifact.Transparency = 0
    artifact.CanCollide = true
    pad.Transparency = 0.55
    pad.Color = Color3.fromRGB(80, 80, 80)
    prompt.Enabled = false
    incomePerTick = 5
end)

task.spawn(function()
    while true do
        task.wait(5)
        if ownerUserId ~= 0 and incomePerTick > 0 then
            local owner = Players:GetPlayerByUserId(ownerUserId)
            if owner then
                local stats = owner:FindFirstChild("leaderstats")
                local cash = stats and stats:FindFirstChild("Cash")
                if cash then
                    cash.Value += incomePerTick
                end
            end
        end
    end
end)
]=]
server.Parent = serverScriptService

local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
    starterPlayerScripts = Instance.new("StarterPlayerScripts")
    starterPlayerScripts.Name = "StarterPlayerScripts"
    starterPlayerScripts.Parent = starterPlayer
end

local client = Instance.new("LocalScript")
client.Name = "MuseuEmpireUI"
client.Source = [=[
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "MuseuEmpireHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(14, 14)
panel.Size = UDim2.fromOffset(250, 92)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
panel.BackgroundTransparency = 0.08
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -28, 0, 24)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "MUSEU EMPIRE"
title.TextColor3 = Color3.fromRGB(245, 208, 108)
title.Font = Enum.Font.GothamBlack
title.TextSize = 17
title.Parent = panel

local money = Instance.new("TextLabel")
money.Position = UDim2.fromOffset(14, 34)
money.Size = UDim2.new(1, -28, 0, 22)
money.BackgroundTransparency = 1
money.TextXAlignment = Enum.TextXAlignment.Left
money.TextColor3 = Color3.fromRGB(120, 240, 150)
money.Font = Enum.Font.GothamBold
money.TextSize = 16
money.Parent = panel

local prestige = Instance.new("TextLabel")
prestige.Position = UDim2.fromOffset(14, 58)
prestige.Size = UDim2.new(1, -28, 0, 20)
prestige.BackgroundTransparency = 1
prestige.TextXAlignment = Enum.TextXAlignment.Left
prestige.TextColor3 = Color3.fromRGB(220, 220, 225)
prestige.Font = Enum.Font.Gotham
prestige.TextSize = 14
prestige.Parent = panel

local objective = Instance.new("TextLabel")
objective.AnchorPoint = Vector2.new(0.5, 1)
objective.Position = UDim2.new(0.5, 0, 1, -22)
objective.Size = UDim2.new(0.9, 0, 0, 54)
objective.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
objective.BackgroundTransparency = 0.1
objective.TextColor3 = Color3.fromRGB(255, 255, 255)
objective.Font = Enum.Font.GothamBold
objective.TextSize = 15
objective.TextWrapped = true
objective.Text = "OBJETIVO: entre no museu e compre sua primeira relíquia por $100."
objective.Parent = gui
local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 14)
objectiveCorner.Parent = objective

local stats = player:WaitForChild("leaderstats")
local cash = stats:WaitForChild("Cash")
local prestigeValue = stats:WaitForChild("Prestige")

local function update()
    money.Text = "$ " .. tostring(cash.Value)
    prestige.Text = "Prestígio: " .. tostring(prestigeValue.Value)
end
cash:GetPropertyChangedSignal("Value"):Connect(update)
prestigeValue:GetPropertyChangedSignal("Value"):Connect(update)
update()
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Museu Empire] first playable loop prepared")
