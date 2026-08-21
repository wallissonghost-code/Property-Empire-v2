local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WORLD_NAME = "PropertyEmpireV2World"
local CITY_HALL_NAME = "CityHall"

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function ensureOpenRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild("OpenCityHall")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "OpenCityHall"
		remote.Parent = remotes
	end

	return remote
end

local function addFrontSign(parent, origin)
	local sign = createPart(
		parent,
		"FrontSign",
		Vector3.new(20, 4, 0.6),
		origin * CFrame.new(0, 10.5, 15.35),
		Color3.fromRGB(38, 57, 78),
		Enum.Material.SmoothPlastic
	)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PREFEITURA\nLICENÇAS"
	label.TextColor3 = Color3.fromRGB(245, 248, 252)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function addLocator(parent, origin)
	local anchor = createPart(
		parent,
		"Locator",
		Vector3.new(1, 1, 1),
		origin * CFrame.new(0, 17, 0),
		Color3.fromRGB(70, 140, 220),
		Enum.Material.Neon
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CityHallLocator"
	billboard.Size = UDim2.fromOffset(210, 46)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 39, 52)
	label.BackgroundTransparency = 0.18
	label.Text = "PREFEITURA"
	label.TextColor3 = Color3.fromRGB(245, 248, 252)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function buildCityHall(world, spawn, openRemote)
	local existing = world:FindFirstChild(CITY_HALL_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = CITY_HALL_NAME
	model:SetAttribute("BootstrapVersion", 2)
	model.Parent = world

	-- Fixed, visible location in the open plaza to the right of the main spawn.
	local basePosition = Vector3.new(spawn.Position.X + 72, 0.5, spawn.Position.Z - 12)
	local origin = CFrame.new(basePosition) * CFrame.Angles(0, math.rad(180), 0)

	local stone = Color3.fromRGB(218, 216, 207)
	local trim = Color3.fromRGB(52, 78, 105)
	local glass = Color3.fromRGB(149, 196, 218)
	local dark = Color3.fromRGB(45, 52, 61)

	createPart(model, "Foundation", Vector3.new(58, 1, 30), origin, stone, Enum.Material.Concrete)
	createPart(model, "BackWall", Vector3.new(58, 12, 1), origin * CFrame.new(0, 6, -14.5), stone, Enum.Material.Concrete)
	createPart(model, "LeftWall", Vector3.new(1, 12, 30), origin * CFrame.new(-28.5, 6, 0), stone, Enum.Material.Concrete)
	createPart(model, "RightWall", Vector3.new(1, 12, 30), origin * CFrame.new(28.5, 6, 0), stone, Enum.Material.Concrete)

	createPart(model, "FrontLeft", Vector3.new(20, 12, 1), origin * CFrame.new(-19, 6, 14.5), stone, Enum.Material.Concrete)
	createPart(model, "FrontRight", Vector3.new(20, 12, 1), origin * CFrame.new(19, 6, 14.5), stone, Enum.Material.Concrete)
	createPart(model, "FrontLintel", Vector3.new(18, 4, 1), origin * CFrame.new(0, 10, 14.5), trim, Enum.Material.Concrete)
	createPart(model, "DoorTop", Vector3.new(10, 2, 0.35), origin * CFrame.new(0, 9, 14.2), glass, Enum.Material.Glass)

	createPart(model, "WindowLeft", Vector3.new(11, 6, 0.35), origin * CFrame.new(-19, 6, 14.2), glass, Enum.Material.Glass)
	createPart(model, "WindowRight", Vector3.new(11, 6, 0.35), origin * CFrame.new(19, 6, 14.2), glass, Enum.Material.Glass)

	createPart(model, "Roof", Vector3.new(62, 1, 34), origin * CFrame.new(0, 12.5, 0), trim, Enum.Material.Slate)
	createPart(model, "Steps", Vector3.new(14, 1, 8), origin * CFrame.new(0, 0, 18.5), stone, Enum.Material.Concrete)
	createPart(model, "ColumnLeft", Vector3.new(2, 11, 2), origin * CFrame.new(-8, 5.5, 15.5), trim, Enum.Material.Marble)
	createPart(model, "ColumnRight", Vector3.new(2, 11, 2), origin * CFrame.new(8, 5.5, 15.5), trim, Enum.Material.Marble)

	local desk = createPart(
		model,
		"LicensingDesk",
		Vector3.new(10, 3.5, 5),
		origin * CFrame.new(0, 2.25, -5),
		dark,
		Enum.Material.WoodPlanks
	)

	local attachment = Instance.new("Attachment")
	attachment.Name = "LicensePromptAttachment"
	attachment.Position = Vector3.new(0, 2.6, 0)
	attachment.Parent = desk

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Solicitar licença"
	prompt.ObjectText = "Prefeitura"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment
	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player)
	end)

	addFrontSign(model, origin)
	addLocator(model, origin)

	print(string.format(
		"[Property Empire v2] City Hall bootstrap created at %.1f, %.1f, %.1f",
		basePosition.X,
		basePosition.Y,
		basePosition.Z
	))
end

local world = Workspace:WaitForChild(WORLD_NAME, 30)
if not world then
	warn("[Property Empire v2] City Hall bootstrap could not find the world")
	return
end

local spawn = world:WaitForChild("MainSpawn", 30)
if not spawn or not spawn:IsA("BasePart") then
	warn("[Property Empire v2] City Hall bootstrap could not find MainSpawn")
	return
end

local openRemote = ensureOpenRemote()

-- Let the main services initialize first, then guarantee the final City Hall instance.
task.wait(2)
buildCityHall(world, spawn, openRemote)
