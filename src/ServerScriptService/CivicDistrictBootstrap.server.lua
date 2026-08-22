local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LandConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LandConfig"))
local WORLD_NAME = "PropertyEmpireV2World"
local DISTRICT_NAME = "CivicDistrict"

local function makePart(parent, name, size, position, color, material, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = canCollide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addMarker(parent, config)
	local anchor = makePart(
		parent,
		"DistrictMarker",
		Vector3.new(1, 1, 1),
		config.MarkerPosition + Vector3.new(0, 9, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		false
	)
	anchor.Transparency = 1
	anchor.CanTouch = false
	anchor.CanQuery = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(230, 42)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 260
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(27, 37, 50)
	label.BackgroundTransparency = 0.12
	label.Text = config.DisplayName
	label.TextColor3 = Color3.fromRGB(247, 248, 250)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = label
end

local function createTree(parent, position, index)
	local trunk = makePart(
		parent,
		"TreeTrunk" .. index,
		Vector3.new(1.6, 8, 1.6),
		position + Vector3.new(0, 4, 0),
		Color3.fromRGB(91, 65, 43),
		Enum.Material.Wood,
		true
	)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Orientation = Vector3.new(0, 0, 90)

	local crown = makePart(
		parent,
		"TreeCrown" .. index,
		Vector3.new(9, 9, 9),
		position + Vector3.new(0, 10, 0),
		Color3.fromRGB(65, 116, 67),
		Enum.Material.Grass,
		false
	)
	crown.Shape = Enum.PartType.Ball
	crown.CanTouch = false
	crown.CanQuery = false
end

local function createLamp(parent, position, index)
	local pole = makePart(
		parent,
		"LampPole" .. index,
		Vector3.new(0.65, 8, 0.65),
		position + Vector3.new(0, 4, 0),
		Color3.fromRGB(45, 49, 55),
		Enum.Material.Metal,
		true
	)

	local bulb = makePart(
		parent,
		"Lamp" .. index,
		Vector3.new(1.25, 1.25, 1.25),
		position + Vector3.new(0, 8.2, 0),
		Color3.fromRGB(255, 224, 163),
		Enum.Material.Neon,
		false
	)
	bulb.CanTouch = false
	bulb.CanQuery = false

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 20
	light.Color = Color3.fromRGB(255, 226, 176)
	light.Parent = bulb
end

local function createBench(parent, position, index)
	local seat = makePart(
		parent,
		"BenchSeat" .. index,
		Vector3.new(8, 0.6, 2.3),
		position + Vector3.new(0, 1.5, 0),
		Color3.fromRGB(105, 75, 48),
		Enum.Material.WoodPlanks,
		true
	)
	makePart(parent, "BenchBack" .. index, Vector3.new(8, 2.2, 0.5), position + Vector3.new(0, 2.7, 0.9), seat.Color, Enum.Material.WoodPlanks, true)
	makePart(parent, "BenchLegA" .. index, Vector3.new(0.5, 1.5, 1.8), position + Vector3.new(-2.8, 0.75, 0), Color3.fromRGB(48, 50, 53), Enum.Material.Metal, true)
	makePart(parent, "BenchLegB" .. index, Vector3.new(0.5, 1.5, 1.8), position + Vector3.new(2.8, 0.75, 0), Color3.fromRGB(48, 50, 53), Enum.Material.Metal, true)
end

local function buildDistrict(world)
	local config = LandConfig.CivicDistrict
	if type(config) ~= "table" then
		warn("[CivicDistrict] CivicDistrict config missing")
		return
	end

	local legacyPlaza = world:FindFirstChild("CivicPlaza")
	if legacyPlaza then
		legacyPlaza:Destroy()
	end

	local previous = world:FindFirstChild(DISTRICT_NAME)
	if previous then
		previous:Destroy()
	end

	local district = Instance.new("Folder")
	district.Name = DISTRICT_NAME
	district:SetAttribute("PublicArea", true)
	district:SetAttribute("PurchasableLots", 0)
	district:SetAttribute("DistrictVersion", 1)
	district.Parent = world

	local civicGround = makePart(
		district,
		"CivicGround",
		config.Size,
		config.Center,
		Color3.fromRGB(83, 113, 76),
		Enum.Material.Grass,
		true
	)
	civicGround:SetAttribute("PublicArea", true)

	local plaza = makePart(
		district,
		"GrandPlaza",
		config.PlazaSize,
		config.PlazaCenter,
		Color3.fromRGB(204, 205, 201),
		Enum.Material.Marble,
		true
	)
	plaza:SetAttribute("PublicArea", true)

	makePart(district, "CeremonialWalk", Vector3.new(34, 1.05, 42), Vector3.new(0, -0.38, -294), Color3.fromRGB(211, 212, 209), Enum.Material.Marble, true)
	makePart(district, "PlazaBorderNorth", Vector3.new(236, 0.45, 3), Vector3.new(0, 0.2, -315), Color3.fromRGB(56, 74, 91), Enum.Material.Slate, true)
	makePart(district, "PlazaBorderSouth", Vector3.new(236, 0.45, 3), Vector3.new(0, 0.2, -469), Color3.fromRGB(56, 74, 91), Enum.Material.Slate, true)

	local pool = makePart(
		district,
		"ReflectingPool",
		Vector3.new(54, 0.5, 20),
		Vector3.new(0, 0.15, -354),
		Color3.fromRGB(69, 151, 190),
		Enum.Material.Glass,
		false
	)
	pool.Transparency = 0.18
	pool.CanTouch = false
	pool.CanQuery = false
	makePart(district, "PoolBase", Vector3.new(58, 0.6, 24), Vector3.new(0, -0.12, -354), Color3.fromRGB(48, 73, 88), Enum.Material.Slate, true)

	local treePositions = {
		Vector3.new(-118, 0, -326), Vector3.new(118, 0, -326),
		Vector3.new(-118, 0, -386), Vector3.new(118, 0, -386),
		Vector3.new(-118, 0, -448), Vector3.new(118, 0, -448),
	}
	for index, position in ipairs(treePositions) do
		createTree(district, position, index)
	end

	local lampPositions = {
		Vector3.new(-48, 0, -320), Vector3.new(48, 0, -320),
		Vector3.new(-48, 0, -382), Vector3.new(48, 0, -382),
		Vector3.new(-48, 0, -430), Vector3.new(48, 0, -430),
	}
	for index, position in ipairs(lampPositions) do
		createLamp(district, position, index)
	end

	createBench(district, Vector3.new(-82, 0, -365), 1)
	createBench(district, Vector3.new(82, 0, -365), 2)
	createBench(district, Vector3.new(-82, 0, -420), 3)
	createBench(district, Vector3.new(82, 0, -420), 4)

	addMarker(district, config)

	local spawn = world:FindFirstChild("MainSpawn")
	if spawn and spawn:IsA("BasePart") then
		spawn.Position = LandConfig.World.SpawnPosition
	end

	local lots = world:FindFirstChild("Lots")
	if lots then
		for _, lot in ipairs(lots:GetChildren()) do
			if lot:IsA("BasePart") then
				local dx = math.abs(lot.Position.X - config.Center.X)
				local dz = math.abs(lot.Position.Z - config.Center.Z)
				local overlapsX = dx < (lot.Size.X + config.Size.X) / 2
				local overlapsZ = dz < (lot.Size.Z + config.Size.Z) / 2
				if overlapsX and overlapsZ then
					warn(string.format("[CivicDistrict] Unexpected lot overlap: %s", lot.Name))
				end
			end
		end
	end

	print("[Property Empire v2] Exclusive civic district created with zero purchasable lots")
end

local world = Workspace:WaitForChild(WORLD_NAME, 30)
if not world then
	warn("[CivicDistrict] World not found")
	return
end

task.wait(1)
buildDistrict(world)
