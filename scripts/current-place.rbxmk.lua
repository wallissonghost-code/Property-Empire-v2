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

part("Ground", Vector3.new(320, 2, 320), Vector3.new(0, 0, 0), Color3.fromRGB(74, 88, 74), "Grass", world)

local museum = Instance.new("Model")
museum.Name = "StarterMuseum"
museum.Parent = world

part("MuseumFloor", Vector3.new(110, 2, 90), Vector3.new(0, 1, -20), Color3.fromRGB(225, 222, 215), "Marble", museum)
part("BackWall", Vector3.new(110, 24, 2), Vector3.new(0, 13, -64), Color3.fromRGB(238, 236, 230), "Concrete", museum)
part("LeftWall", Vector3.new(2, 24, 90), Vector3.new(-54, 13, -20), Color3.fromRGB(238, 236, 230), "Concrete", museum)
part("RightWall", Vector3.new(2, 24, 90), Vector3.new(54, 13, -20), Color3.fromRGB(238, 236, 230), "Concrete", museum)
part("FrontLeft", Vector3.new(42, 24, 2), Vector3.new(-34, 13, 24), Color3.fromRGB(238, 236, 230), "Concrete", museum)
part("FrontRight", Vector3.new(42, 24, 2), Vector3.new(34, 13, 24), Color3.fromRGB(238, 236, 230), "Concrete", museum)
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

part("EntranceCarpet", Vector3.new(18, 0.4, 40), Vector3.new(0, 2.2, 16), Color3.fromRGB(110, 24, 32), "Fabric", museum)
part("Reception", Vector3.new(24, 5, 6), Vector3.new(0, 4.5, -2), Color3.fromRGB(83, 60, 44), "Wood", museum)

local exhibitions = Instance.new("Folder")
exhibitions.Name = "Exhibitions"
exhibitions.Parent = museum

local function createExhibition(index, name, x, z, price, income, prestigeReward, artifactColor, artifactShape)
    local model = Instance.new("Model")
    model.Name = "Exhibition" .. tostring(index)
    model:SetAttribute("Index", index)
    model:SetAttribute("Price", price)
    model:SetAttribute("Income", income)
    model:SetAttribute("PrestigeReward", prestigeReward)
    model:SetAttribute("Purchased", false)
    model.Parent = exhibitions

    part("DisplayBase", Vector3.new(12, 2, 12), Vector3.new(x, 3, z), Color3.fromRGB(44, 46, 52), "Marble", model)
    part("Pedestal", Vector3.new(5, 7, 5), Vector3.new(x, 7.5, z), Color3.fromRGB(230, 230, 228), "Marble", model)

    local artifact = part("Artifact", Vector3.new(3.2, 5, 3.2), Vector3.new(x, 13.5, z), artifactColor, "Metal", model)
    artifact.Shape = artifactShape or "Ball"
    artifact.Transparency = 1
    artifact.CanCollide = false

    local pad = part("PurchasePad", Vector3.new(10, 1, 10), Vector3.new(x + 14, 2.5, z), Color3.fromRGB(50, 180, 95), "Neon", model)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "BuyPrompt"
    prompt.ActionText = "Comprar exposição"
    prompt.ObjectText = name .. " · $" .. tostring(price)
    prompt.HoldDuration = 0.2
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Enabled = index == 1
    prompt.Parent = pad

    local gui = Instance.new("BillboardGui")
    gui.Name = "PriceBillboard"
    gui.Size = UDim2.fromOffset(210, 66)
    gui.StudsOffset = Vector3.new(0, 3.8, 0)
    gui.AlwaysOnTop = true
    gui.Parent = pad
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
    label.BackgroundTransparency = 0.1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = name .. "\n$" .. tostring(price) .. " · +$" .. tostring(income) .. "/5s"
    label.Font = "GothamBold"
    label.TextScaled = true
    label.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = label
end

createExhibition(1, "Relíquia Antiga", -30, -30, 100, 5, 1, Color3.fromRGB(214, 168, 70), "Ball")
createExhibition(2, "Cristal Imperial", 0, -30, 350, 15, 2, Color3.fromRGB(104, 174, 255), "Block")
createExhibition(3, "Coroa Dourada", 30, -30, 900, 40, 4, Color3.fromRGB(246, 205, 65), "Ball")

local progressSign = part("ProgressBoard", Vector3.new(26, 10, 1), Vector3.new(0, 10, -62.7), Color3.fromRGB(28, 31, 39), "SmoothPlastic", museum)
local progressGui = Instance.new("SurfaceGui")
progressGui.Face = "Front"
progressGui.CanvasSize = Vector2.new(700, 260)
progressGui.Parent = progressSign
local progressText = Instance.new("TextLabel")
progressText.Size = UDim2.new(1, -30, 1, -30)
progressText.Position = UDim2.fromOffset(15, 15)
progressText.BackgroundTransparency = 1
progressText.TextColor3 = Color3.fromRGB(255, 255, 255)
progressText.Text = "EXPANDA SEU MUSEU\n1★ Relíquia  •  3★ Cristal  •  7★ Coroa"
progressText.Font = "GothamBold"
progressText.TextScaled = true
progressText.TextWrapped = true
progressText.Parent = progressGui

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
local exhibitions = museum:WaitForChild("Exhibitions")

local ownerUserId = 0
local totalIncome = 0
local purchasedCount = 0

local ordered = {}
for _, model in ipairs(exhibitions:GetChildren()) do
    table.insert(ordered, model)
end
table.sort(ordered, function(a, b)
    return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
end)

local function setupPlayer(player)
    if player:FindFirstChild("leaderstats") then return end
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

    local exhibits = Instance.new("IntValue")
    exhibits.Name = "Exhibits"
    exhibits.Value = 0
    exhibits.Parent = leaderstats
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end

local function unlockNext(index)
    local nextModel = ordered[index + 1]
    if not nextModel then return end
    local pad = nextModel:FindFirstChild("PurchasePad")
    local prompt = pad and pad:FindFirstChild("BuyPrompt")
    if prompt then prompt.Enabled = true end
end

for index, model in ipairs(ordered) do
    local pad = model:WaitForChild("PurchasePad")
    local prompt = pad:WaitForChild("BuyPrompt")
    local artifact = model:WaitForChild("Artifact")

    prompt.Triggered:Connect(function(player)
        if model:GetAttribute("Purchased") then return end
        if ownerUserId ~= 0 and ownerUserId ~= player.UserId then return end
        if index > 1 and not ordered[index - 1]:GetAttribute("Purchased") then return end

        local stats = player:FindFirstChild("leaderstats")
        local cash = stats and stats:FindFirstChild("Cash")
        local prestige = stats and stats:FindFirstChild("Prestige")
        local exhibits = stats and stats:FindFirstChild("Exhibits")
        if not cash or not prestige or not exhibits then return end

        local price = model:GetAttribute("Price") or 0
        if cash.Value < price then return end

        cash.Value -= price
        ownerUserId = player.UserId
        model:SetAttribute("Purchased", true)
        artifact.Transparency = 0
        artifact.CanCollide = true
        pad.Transparency = 0.6
        pad.Color = Color3.fromRGB(80, 80, 80)
        prompt.Enabled = false

        totalIncome += model:GetAttribute("Income") or 0
        purchasedCount += 1
        exhibits.Value = purchasedCount
        prestige.Value += model:GetAttribute("PrestigeReward") or 0
        unlockNext(index)
    end)
end

task.spawn(function()
    while true do
        task.wait(5)
        if ownerUserId ~= 0 and totalIncome > 0 then
            local owner = Players:GetPlayerByUserId(ownerUserId)
            local stats = owner and owner:FindFirstChild("leaderstats")
            local cash = stats and stats:FindFirstChild("Cash")
            if cash then cash.Value += totalIncome end
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
panel.Size = UDim2.fromOffset(260, 116)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
panel.BackgroundTransparency = 0.08
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local function label(y, height, textSize, color)
    local item = Instance.new("TextLabel")
    item.Position = UDim2.fromOffset(14, y)
    item.Size = UDim2.new(1, -28, 0, height)
    item.BackgroundTransparency = 1
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextColor3 = color
    item.Font = Enum.Font.GothamBold
    item.TextSize = textSize
    item.Parent = panel
    return item
end

local title = label(8, 24, 17, Color3.fromRGB(245, 208, 108))
title.Text = "MUSEU EMPIRE"
local money = label(36, 22, 16, Color3.fromRGB(120, 240, 150))
local prestige = label(60, 20, 14, Color3.fromRGB(245, 208, 108))
local exhibits = label(82, 20, 14, Color3.fromRGB(220, 220, 225))

local objective = Instance.new("TextLabel")
objective.AnchorPoint = Vector2.new(0.5, 1)
objective.Position = UDim2.new(0.5, 0, 1, -22)
objective.Size = UDim2.new(0.9, 0, 0, 58)
objective.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
objective.BackgroundTransparency = 0.1
objective.TextColor3 = Color3.fromRGB(255, 255, 255)
objective.Font = Enum.Font.GothamBold
objective.TextSize = 15
objective.TextWrapped = true
objective.Parent = gui
local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 14)
objectiveCorner.Parent = objective

local stats = player:WaitForChild("leaderstats")
local cash = stats:WaitForChild("Cash")
local prestigeValue = stats:WaitForChild("Prestige")
local exhibitsValue = stats:WaitForChild("Exhibits")

local objectives = {
    [0] = "OBJETIVO: compre a Relíquia Antiga por $100.",
    [1] = "OBJETIVO: junte $350 e compre o Cristal Imperial.",
    [2] = "OBJETIVO: expanda até a Coroa Dourada por $900.",
    [3] = "MUSEU INICIAL COMPLETO! Próximo passo: visitantes e expansão."
}

local function update()
    money.Text = "$ " .. tostring(cash.Value)
    prestige.Text = "★ Prestígio: " .. tostring(prestigeValue.Value)
    exhibits.Text = "Exposições: " .. tostring(exhibitsValue.Value) .. "/3"
    objective.Text = objectives[exhibitsValue.Value] or objectives[3]
end

cash:GetPropertyChangedSignal("Value"):Connect(update)
prestigeValue:GetPropertyChangedSignal("Value"):Connect(update)
exhibitsValue:GetPropertyChangedSignal("Value"):Connect(update)
update()
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Museu Empire] exhibition progression prepared")
