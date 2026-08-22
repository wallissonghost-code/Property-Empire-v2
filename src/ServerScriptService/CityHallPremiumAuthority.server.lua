local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WORLD_NAME = "PropertyEmpireV2World"
local CITY_HALL_NAME = "CityHall"
local AUTHORITY_VERSION = 1

local rebuilding = false

local function makePart(parent, name, size, cframe, color, material, transparency, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.CanCollide = canCollide ~= false
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

local function addSurfaceText(part, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(246, 247, 250)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function buildPremiumCityHall(world, spawn, openRemote)
	if rebuilding then
		return
	end
	rebuilding = true

	local existing = world:FindFirstChild(CITY_HALL_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = CITY_HALL_NAME
	model:SetAttribute("PremiumAuthorityVersion", AUTHORITY_VERSION)
	model.Parent = world

	local basePosition = Vector3.new(spawn.Position.X + 118, 0.5, spawn.Position.Z - 52)
	local origin = CFrame.new(basePosition) * CFrame.Angles(0, math.rad(180), 0)

	local ivory = Color3.fromRGB(232, 230, 221)
	local marble = Color3.fromRGB(220, 222, 224)
	local navy = Color3.fromRGB(35, 55, 78)
	local charcoal = Color3.fromRGB(31, 36, 44)
	local glass = Color3.fromRGB(132, 190, 216)
	local gold = Color3.fromRGB(190, 151, 70)

	makePart(model, "CivicPlaza", Vector3.new(108, 1, 70), origin * CFrame.new(0, -0.3, 10), marble, Enum.Material.Marble)
	makePart(model, "Foundation", Vector3.new(82, 1, 46), origin, ivory, Enum.Material.Marble)
	makePart(model, "BackWall", Vector3.new(82, 16, 1), origin * CFrame.new(0, 8, -22.5), ivory, Enum.Material.Concrete)
	makePart(model, "LeftWall", Vector3.new(1, 16, 46), origin * CFrame.new(-40.5, 8, 0), ivory, Enum.Material.Concrete)
	makePart(model, "RightWall", Vector3.new(1, 16, 46), origin * CFrame.new(40.5, 8, 0), ivory, Enum.Material.Concrete)
	makePart(model, "FrontLeft", Vector3.new(27, 16, 1), origin * CFrame.new(-27, 8, 22.5), ivory, Enum.Material.Concrete)
	makePart(model, "FrontRight", Vector3.new(27, 16, 1), origin * CFrame.new(27, 8, 22.5), ivory, Enum.Material.Concrete)
	makePart(model, "EntranceLintel", Vector3.new(28, 5, 1), origin * CFrame.new(0, 13.5, 22.5), navy, Enum.Material.Marble)

	makePart(model, "GlassLeft", Vector3.new(9, 10, 0.35), origin * CFrame.new(-9.5, 6, 22.1), glass, Enum.Material.Glass, 0.25, false)
	makePart(model, "GlassRight", Vector3.new(9, 10, 0.35), origin * CFrame.new(9.5, 6, 22.1), glass, Enum.Material.Glass, 0.25, false)
	makePart(model, "DoorLeft", Vector3.new(5, 9, 0.3), origin * CFrame.new(-2.7, 4.8, 22.0), glass, Enum.Material.Glass, 0.18, false)
	makePart(model, "DoorRight", Vector3.new(5, 9, 0.3), origin * CFrame.new(2.7, 4.8, 22.0), glass, Enum.Material.Glass, 0.18, false)

	makePart(model, "Roof", Vector3.new(88, 1.2, 52), origin * CFrame.new(0, 16.6, 0), navy, Enum.Material.Slate)
	makePart(model, "Cornice", Vector3.new(92, 1.2, 2), origin * CFrame.new(0, 15.8, 24.3), gold, Enum.Material.Metal)
	makePart(model, "Canopy", Vector3.new(34, 1, 10), origin * CFrame.new(0, 11.6, 26.8), navy, Enum.Material.Metal)

	for _, x in ipairs({ -15, -8, 8, 15 }) do
		makePart(model, "Column" .. tostring(x), Vector3.new(2.2, 14, 2.2), origin * CFrame.new(x, 7, 24.5), marble, Enum.Material.Marble)
	end

	makePart(model, "Step01", Vector3.new(34, 0.7, 6), origin * CFrame.new(0, 0.2, 27), marble, Enum.Material.Marble)
	makePart(model, "Step02", Vector3.new(30, 0.7, 4), origin * CFrame.new(0, 0.55, 31.5), marble, Enum.Material.Marble)

	local sign = makePart(model, "MainSign", Vector3.new(30, 4.5, 0.6), origin * CFrame.new(0, 13.2, 23.2), navy, Enum.Material.Metal)
	addSurfaceText(sign, Enum.NormalId.Front, "PREFEITURA\nPROPERTY EMPIRE")

	local reception = makePart(model, "LicensingDesk", Vector3.new(16, 3.6, 6), origin * CFrame.new(0, 2.3, -8), charcoal, Enum.Material.WoodPlanks)
	local deskTrim = makePart(model, "DeskTrim", Vector3.new(16.4, 0.35, 6.4), origin * CFrame.new(0, 4.15, -8), gold, Enum.Material.Metal)
	deskTrim.CanCollide = false

	local attachment = Instance.new("Attachment")
	attachment.Name = "LicensePromptAttachment"
	attachment.Position = Vector3.new(0, 2.8, 2.8)
	attachment.Parent = reception

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Solicitar licença"
	prompt.ObjectText = "Prefeitura"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment
	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player)
	end)

	for _, x in ipairs({ -30, -18, 18, 30 }) do
		local lightPart = makePart(model, "FacadeLight" .. tostring(x), Vector3.new(0.8, 0.8, 0.8), origin * CFrame.new(x, 7, 23.2), gold, Enum.Material.Neon, 0, false)
		local light = Instance.new("PointLight")
		light.Brightness = 1.4
		light.Range = 18
		light.Color = Color3.fromRGB(255, 226, 170)
		light.Parent = lightPart
	end

	rebuilding = false
	print("[Property Empire v2] Premium City Hall authority active")
end

local world = Workspace:WaitForChild(WORLD_NAME, 30)
if not world then
	warn("[CityHallPremiumAuthority] World not found")
	return
end

local spawn = world:WaitForChild("MainSpawn", 30)
if not spawn or not spawn:IsA("BasePart") then
	warn("[CityHallPremiumAuthority] MainSpawn not found")
	return
end

local openRemote = ensureOpenRemote()

task.delay(3, function()
	buildPremiumCityHall(world, spawn, openRemote)
end)

world.ChildAdded:Connect(function(child)
	if child.Name ~= CITY_HALL_NAME then
		return
	end
	if child:GetAttribute("PremiumAuthorityVersion") == AUTHORITY_VERSION then
		return
	end
	task.delay(1.5, function()
		if child.Parent == world and child:GetAttribute("PremiumAuthorityVersion") ~= AUTHORITY_VERSION then
			buildPremiumCityHall(world, spawn, openRemote)
		end
	end)
end)
