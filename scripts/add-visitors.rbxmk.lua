local inputPath, outputPath = ...
assert(type(inputPath) == "string" and inputPath ~= "", "missing input place path")
assert(type(outputPath) == "string" and outputPath ~= "", "missing output place path")

local place = fs.read(inputPath)
local serverScriptService = place:GetService("ServerScriptService")
local starterPlayer = place:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if not starterPlayerScripts then
	starterPlayerScripts = Instance.new("StarterPlayerScripts")
	starterPlayerScripts.Name = "StarterPlayerScripts"
	starterPlayerScripts.Parent = starterPlayer
end

local oldServer = serverScriptService:FindFirstChild("MiningEmpireVisitorService")
if oldServer then oldServer:Destroy() end
local oldClient = starterPlayerScripts:FindFirstChild("MiningEmpireMuseumEconomyUI")
if oldClient then oldClient:Destroy() end

local server = Instance.new("Script")
server.Name = "MiningEmpireVisitorService"
server.Source = [=[
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local STORE = DataStoreService:GetDataStore("MiningEmpireMuseumEconomy_v1")
local DISTRICT_ORIGIN = Vector3.new(0, 22, -1500)
local VISITOR_INTERVAL_MIN = 10
local VISITOR_INTERVAL_MAX = 17
local MAX_VISITORS = 12

local economy = {}
local visitorFolder

local function getFolder()
	local museum = workspace:WaitForChild("MiningEmpireMuseumDistrict", 60)
	if not museum then return nil end
	visitorFolder = museum:FindFirstChild("Visitors") or Instance.new("Folder")
	visitorFolder.Name = "Visitors"
	visitorFolder.Parent = museum
	return visitorFolder
end

local function defaultData()
	return {Visits = 0, Revenue = 0, BestVisit = 0}
end

local function load(player)
	local data
	pcall(function() data = STORE:GetAsync("u" .. player.UserId) end)
	if type(data) ~= "table" then data = defaultData() end
	data.Visits = tonumber(data.Visits) or 0
	data.Revenue = tonumber(data.Revenue) or 0
	data.BestVisit = tonumber(data.BestVisit) or 0
	economy[player] = data
	player:SetAttribute("MuseumVisits", data.Visits)
	player:SetAttribute("MuseumRevenue", data.Revenue)
	player:SetAttribute("BestMuseumVisit", data.BestVisit)
end

local function save(player)
	local data = economy[player]
	if not data then return end
	pcall(function() STORE:SetAsync("u" .. player.UserId, data) end)
end

local function addGameMoney(player, amount)
	local storage = ServerStorage:FindFirstChild("MoneyStorage")
	local money = storage and storage:FindFirstChild(player.Name)
	if money and money:IsA("ValueBase") then
		money.Value = money.Value + amount
		return true
	end
	return false
end

local function visitValue(player)
	local prestige = math.max(0, tonumber(player:GetAttribute("MuseumPrestige")) or 0)
	local artifacts = math.max(0, tonumber(player:GetAttribute("ArtifactCount")) or 0)
	local base = 40
	local prestigeBonus = prestige * 3
	local collectionBonus = math.min(artifacts, 50) * 7
	local variance = math.random(90, 115) / 100
	return math.max(25, math.floor((base + prestigeBonus + collectionBonus) * variance))
end

local function makeVisitor()
	local folder = visitorFolder or getFolder()
	if not folder or #folder:GetChildren() >= MAX_VISITORS then return nil end

	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(math.random(160, 235), math.random(125, 205), math.random(95, 180))
	description.TorsoColor = Color3.fromRGB(math.random(55, 210), math.random(55, 210), math.random(55, 210))
	description.LeftArmColor = description.HeadColor
	description.RightArmColor = description.HeadColor
	description.LeftLegColor = Color3.fromRGB(math.random(25, 100), math.random(25, 100), math.random(25, 100))
	description.RightLegColor = description.LeftLegColor

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not ok or not rig then return nil end

	rig.Name = "MuseumVisitor"
	rig.Parent = folder
	local root = rig:FindFirstChild("HumanoidRootPart")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then rig:Destroy() return nil end

	rig:PivotTo(CFrame.new(DISTRICT_ORIGIN + Vector3.new(math.random(-18,18), 4, 40)))
	for _, p in ipairs(rig:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "VisitorTag"
	tag.Size = UDim2.fromOffset(120, 24)
	tag.StudsOffset = Vector3.new(0, 3.1, 0)
	tag.AlwaysOnTop = true
	tag.Parent = root
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1,1)
	text.BackgroundTransparency = 1
	text.Text = "VISITANTE"
	text.TextColor3 = Color3.fromRGB(235,239,245)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Parent = tag

	return rig, humanoid
end

local function walkVisitor(rig, humanoid)
	local stops = {
		DISTRICT_ORIGIN + Vector3.new(-38,4,18),
		DISTRICT_ORIGIN + Vector3.new(38,4,18),
		DISTRICT_ORIGIN + Vector3.new(-38,4,-10),
		DISTRICT_ORIGIN + Vector3.new(38,4,-10),
		DISTRICT_ORIGIN + Vector3.new(0,4,-24),
	}
	for i = 1, math.random(3,5) do
		if not rig.Parent then return end
		local target = stops[math.random(1,#stops)] + Vector3.new(math.random(-5,5),0,math.random(-5,5))
		humanoid:MoveTo(target)
		humanoid.MoveToFinished:Wait()
		task.wait(math.random(1,3))
	end
	if rig.Parent then
		humanoid:MoveTo(DISTRICT_ORIGIN + Vector3.new(0,4,45))
		task.wait(4)
		rig:Destroy()
	end
end

local function rewardPlayer(player)
	local data = economy[player]
	if not data then return end
	local prestige = tonumber(player:GetAttribute("MuseumPrestige")) or 0
	if prestige <= 0 then return end
	local amount = visitValue(player)
	data.Visits += 1
	data.Revenue += amount
	data.BestVisit = math.max(data.BestVisit, amount)
	player:SetAttribute("MuseumVisits", data.Visits)
	player:SetAttribute("MuseumRevenue", data.Revenue)
	player:SetAttribute("BestMuseumVisit", data.BestVisit)
	player:SetAttribute("LastMuseumIncome", amount)
	addGameMoney(player, amount)
end

Players.PlayerAdded:Connect(load)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(load, player) end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	economy[player] = nil
end)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do save(player) end
end)

task.spawn(function()
	getFolder()
	while task.wait(math.random(VISITOR_INTERVAL_MIN, VISITOR_INTERVAL_MAX)) do
		local eligible = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if (tonumber(player:GetAttribute("MuseumPrestige")) or 0) > 0 then
				table.insert(eligible, player)
			end
		end
		if #eligible > 0 then
			local owner = eligible[math.random(1,#eligible)]
			local rig, humanoid = makeVisitor()
			if rig and humanoid then
				rewardPlayer(owner)
				task.spawn(walkVisitor, rig, humanoid)
			end
		end
	end
end)

print("[Mining Empire] Visitor economy online")
]=]
server.Parent = serverScriptService

local client = Instance.new("LocalScript")
client.Name = "MiningEmpireMuseumEconomyUI"
client.Source = [=[
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "MiningEmpireMuseumEconomyUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 16
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1,0)
panel.Position = UDim2.new(1,-14,0,68)
panel.Size = UDim2.fromOffset(190,72)
panel.BackgroundColor3 = Color3.fromRGB(18,23,31)
panel.BackgroundTransparency = 0.08
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,12)

local visits = Instance.new("TextLabel")
visits.Position = UDim2.fromOffset(10,7)
visits.Size = UDim2.new(1,-20,0,24)
visits.BackgroundTransparency = 1
visits.TextColor3 = Color3.fromRGB(235,239,245)
visits.Font = Enum.Font.GothamBold
visits.TextSize = 12
visits.TextXAlignment = Enum.TextXAlignment.Left
visits.Parent = panel

local revenue = visits:Clone()
revenue.Position = UDim2.fromOffset(10,35)
revenue.TextColor3 = Color3.fromRGB(120,220,154)
revenue.Parent = panel

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(.5,0)
toast.Position = UDim2.new(.5,0,0,72)
toast.Size = UDim2.fromOffset(250,38)
toast.BackgroundColor3 = Color3.fromRGB(35,91,58)
toast.TextColor3 = Color3.new(1,1,1)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 13
toast.Visible = false
toast.Parent = gui
Instance.new("UICorner",toast).CornerRadius = UDim.new(0,11)

local function money(n)
	local s=tostring(math.floor(tonumber(n) or 0))
	repeat local n2,k=s:gsub("^(-?%d+)(%d%d%d)","%1.%2") s=n2 until k==0
	return "$"..s
end
local function refresh()
	visits.Text = "👥 VISITAS  "..tostring(player:GetAttribute("MuseumVisits") or 0)
	revenue.Text = "💵 MUSEU  "..money(player:GetAttribute("MuseumRevenue") or 0)
end
local last = tonumber(player:GetAttribute("LastMuseumIncome")) or 0
player:GetAttributeChangedSignal("LastMuseumIncome"):Connect(function()
	local now=tonumber(player:GetAttribute("LastMuseumIncome")) or 0
	if now>0 and now~=last then
		last=now
		toast.Text="+"..money(now).." · novo visitante"
		toast.Visible=true
		toast.BackgroundTransparency=0.05
		TweenService:Create(toast,TweenInfo.new(.18),{Position=UDim2.new(.5,0,0,116)}):Play()
		task.delay(2.2,function()
			TweenService:Create(toast,TweenInfo.new(.2),{BackgroundTransparency=1}):Play()
			task.wait(.22)
			toast.Visible=false
			toast.Position=UDim2.new(.5,0,0,72)
		end)
	end
	refresh()
end)
player:GetAttributeChangedSignal("MuseumVisits"):Connect(refresh)
player:GetAttributeChangedSignal("MuseumRevenue"):Connect(refresh)
refresh()
]=]
client.Parent = starterPlayerScripts

fs.write(outputPath, place)
print("[Mining Empire] visitors + museum revenue injected")
