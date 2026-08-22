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

local function addSurfaceText(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function addWarmLight(part, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 224, 176)
	light.Brightness = brightness or 1.5
	light.Range = range or 18
	light.Shadows = true
	light.Parent = part
end

local function addFrontIdentity(parent, origin)
	local navy = Color3.fromRGB(30, 48, 70)
	local gold = Color3.fromRGB(205, 169, 88)
	local white = Color3.fromRGB(244, 246, 248)

	local sign = createPart(
		parent,
		"FacadeIdentity",
		Vector3.new(28, 3.2, 0.45),
		origin * CFrame.new(0, 13.7, 20.25),
		navy,
		Enum.Material.SmoothPlastic
	)
	sign.CanCollide = false
	addSurfaceText(sign, Enum.NormalId.Front, "PREFEITURA · PROPERTY EMPIRE", white)

	local seal = createPart(
		parent,
		"CivicSeal",
		Vector3.new(4.4, 4.4, 0.55),
		origin * CFrame.new(0, 17.2, 20.2),
		gold,
		Enum.Material.Metal
	)
	seal.CanCollide = false
end

local function addSideDirectory(parent, origin)
	-- The old floating locator sat directly in the entrance sightline. The new
	-- directory lives beside the building and is intentionally non-collidable.
	local post = createPart(
		parent,
		"DirectoryPost",
		Vector3.new(1.2, 5, 1.2),
		origin * CFrame.new(-39, 2.5, 22),
		Color3.fromRGB(48, 55, 64),
		Enum.Material.Metal
	)
	post.CanCollide = false

	local board = createPart(
		parent,
		"DirectoryBoard",
		Vector3.new(13, 5.5, 0.6),
		origin * CFrame.new(-39, 5.6, 22),
		Color3.fromRGB(30, 48, 70),
		Enum.Material.SmoothPlastic
	)
	board.CanCollide = false
	addSurfaceText(board, Enum.NormalId.Front, "PREFEITURA\nLICENÇAS", Color3.fromRGB(245, 247, 250))
end

local function buildCityHall(world, spawn, openRemote)
	local existing = world:FindFirstChild(CITY_HALL_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = CITY_HALL_NAME
	model:SetAttribute("BootstrapVersion", 3)
	model:SetAttribute("PremiumFacade", true)
	model.Parent = world

	-- Move the building farther south of the original lots. With the 180-degree
	-- rotation the entrance faces back toward the spawn/civic plaza.
	local basePosition = Vector3.new(spawn.Position.X + 80, 0.5, spawn.Position.Z + 58)
	local origin = CFrame.new(basePosition) * CFrame.Angles(0, math.rad(180), 0)

	local ivory = Color3.fromRGB(226, 224, 217)
	local marble = Color3.fromRGB(237, 237, 232)
	local navy = Color3.fromRGB(39, 61, 84)
	local dark = Color3.fromRGB(42, 47, 54)
	local glass = Color3.fromRGB(144, 194, 218)
	local gold = Color3.fromRGB(202, 169, 92)

	-- Forecourt and three shallow steps create a clear, wide arrival path.
	createPart(model, "Forecourt", Vector3.new(82, 0.6, 22), origin * CFrame.new(0, -0.2, 29), ivory, Enum.Material.Concrete)
	createPart(model, "StepLow", Vector3.new(24, 0.35, 5), origin * CFrame.new(0, 0.05, 23.5), marble, Enum.Material.Marble)
	createPart(model, "StepMid", Vector3.new(21, 0.35, 4), origin * CFrame.new(0, 0.3, 21), marble, Enum.Material.Marble)
	createPart(model, "StepHigh", Vector3.new(18, 0.35, 3), origin * CFrame.new(0, 0.55, 18.8), marble, Enum.Material.Marble)

	createPart(model, "Foundation", Vector3.new(70, 1, 40), origin, marble, Enum.Material.Marble)
	createPart(model, "LobbyFloor", Vector3.new(64, 0.35, 34), origin * CFrame.new(0, 0.65, 0), dark, Enum.Material.Marble)

	-- Main shell: taller and wider than the prototype, with a 14-stud clear entrance.
	createPart(model, "BackWall", Vector3.new(70, 16, 1), origin * CFrame.new(0, 8, -19.5), ivory, Enum.Material.Concrete)
	createPart(model, "LeftWall", Vector3.new(1, 16, 40), origin * CFrame.new(-34.5, 8, 0), ivory, Enum.Material.Concrete)
	createPart(model, "RightWall", Vector3.new(1, 16, 40), origin * CFrame.new(34.5, 8, 0), ivory, Enum.Material.Concrete)
	createPart(model, "FrontLeft", Vector3.new(25, 16, 1), origin * CFrame.new(-22.5, 8, 19.5), ivory, Enum.Material.Concrete)
	createPart(model, "FrontRight", Vector3.new(25, 16, 1), origin * CFrame.new(22.5, 8, 19.5), ivory, Enum.Material.Concrete)
	createPart(model, "EntryLintel", Vector3.new(20, 5, 1), origin * CFrame.new(0, 13.5, 19.5), navy, Enum.Material.Marble)

	-- Premium glass facade sections.
	for _, x in ipairs({ -23, -13, 13, 23 }) do
		local window = createPart(
			model,
			"FrontWindow" .. tostring(x),
			Vector3.new(8, 9, 0.35),
			origin * CFrame.new(x, 8, 19.15),
			glass,
			Enum.Material.Glass
		)
		window.Transparency = 0.28
	end

	for _, z in ipairs({ -10, 3, 14 }) do
		local leftWindow = createPart(
			model,
			"LeftWindow" .. tostring(z),
			Vector3.new(0.35, 8, 8),
			origin * CFrame.new(-34.15, 8, z),
			glass,
			Enum.Material.Glass
		)
		leftWindow.Transparency = 0.3

		local rightWindow = createPart(
			model,
			"RightWindow" .. tostring(z),
			Vector3.new(0.35, 8, 8),
			origin * CFrame.new(34.15, 8, z),
			glass,
			Enum.Material.Glass
		)
		rightWindow.Transparency = 0.3
	end

	-- Double glass doors are decorative/non-collidable so the entrance can never
	-- be blocked by the facade itself.
	for _, x in ipairs({ -3.4, 3.4 }) do
		local door = createPart(
			model,
			"GlassDoor" .. tostring(x),
			Vector3.new(6.2, 9, 0.3),
			origin * CFrame.new(x, 5.2, 19.25),
			glass,
			Enum.Material.Glass
		)
		door.Transparency = 0.45
		door.CanCollide = false
		door.CanTouch = false
	end

	-- Marble portico and layered roof/cornice.
	createPart(model, "ColumnLeftOuter", Vector3.new(2.4, 15, 2.4), origin * CFrame.new(-10, 7.5, 20.4), marble, Enum.Material.Marble)
	createPart(model, "ColumnLeftInner", Vector3.new(1.8, 13, 1.8), origin * CFrame.new(-7, 6.5, 20.1), marble, Enum.Material.Marble)
	createPart(model, "ColumnRightInner", Vector3.new(1.8, 13, 1.8), origin * CFrame.new(7, 6.5, 20.1), marble, Enum.Material.Marble)
	createPart(model, "ColumnRightOuter", Vector3.new(2.4, 15, 2.4), origin * CFrame.new(10, 7.5, 20.4), marble, Enum.Material.Marble)
	createPart(model, "PorticoBeam", Vector3.new(25, 2, 3), origin * CFrame.new(0, 15.7, 20.3), marble, Enum.Material.Marble)
	createPart(model, "Roof", Vector3.new(74, 1.2, 44), origin * CFrame.new(0, 16.6, 0), navy, Enum.Material.Slate)
	createPart(model, "Cornice", Vector3.new(78, 0.7, 48), origin * CFrame.new(0, 17.4, 0), marble, Enum.Material.Marble)
	createPart(model, "RoofCrown", Vector3.new(30, 2, 8), origin * CFrame.new(0, 18.5, 3), navy, Enum.Material.Slate)

	-- Reception interior, positioned well behind the entrance corridor.
	local desk = createPart(
		model,
		"LicensingDesk",
		Vector3.new(14, 3.6, 5),
		origin * CFrame.new(0, 2.55, -8),
		dark,
		Enum.Material.WoodPlanks
	)
	createPart(model, "DeskAccent", Vector3.new(10, 0.5, 5.15), origin * CFrame.new(0, 4.45, -8), gold, Enum.Material.Metal)
	createPart(model, "ReceptionBackdrop", Vector3.new(22, 8, 0.5), origin * CFrame.new(0, 5, -18.8), navy, Enum.Material.Marble)

	local backdropText = createPart(
		model,
		"ReceptionText",
		Vector3.new(14, 2.2, 0.2),
		origin * CFrame.new(0, 6, -18.45),
		gold,
		Enum.Material.Metal
	)
	backdropText.CanCollide = false
	addSurfaceText(backdropText, Enum.NormalId.Back, "LICENÇAS EMPRESARIAIS", Color3.fromRGB(250, 244, 224))

	local attachment = Instance.new("Attachment")
	attachment.Name = "LicensePromptAttachment"
	attachment.Position = Vector3.new(0, 2.7, 0)
	attachment.Parent = desk

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Solicitar licença"
	prompt.ObjectText = "Prefeitura"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachment
	prompt.Triggered:Connect(function(player)
		openRemote:FireClient(player)
	end)

	-- Warm architectural lighting instead of a floating locator over the doorway.
	for _, x in ipairs({ -15, 15 }) do
		local sconce = createPart(
			model,
			"Sconce" .. tostring(x),
			Vector3.new(0.8, 1.6, 0.8),
			origin * CFrame.new(x, 9, 20.1),
			gold,
			Enum.Material.Neon
		)
		sconce.CanCollide = false
		addWarmLight(sconce, 1.8, 20)
	end

	addFrontIdentity(model, origin)
	addSideDirectory(model, origin)

	print(string.format(
		"[Property Empire v2] Premium City Hall created at %.1f, %.1f, %.1f",
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
