local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldService = {}
local started = false
local world
local slots = {}

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function addTravelator(parent, name, z)
	local belt = part(parent, name, Vector3.new(690, 0.45, 10), CFrame.new(0, 0.4, z), Color3.fromRGB(52, 86, 92), Enum.Material.Metal)
	belt:SetAttribute("Travelator", true)
	belt:SetAttribute("BoostWalkSpeed", 28)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 18
	gui.Parent = belt
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "»  »  »  MUSEUM WALK  »  »  »  MUSEUM WALK  »  »  »  MUSEUM WALK  »  »  »"
	label.TextColor3 = Color3.fromRGB(211, 238, 238)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	local active = {}
	belt.Touched:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid or active[humanoid] then return end
		active[humanoid] = humanoid.WalkSpeed
		humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, 28)
	end)
	belt.TouchEnded:Connect(function(hit)
		if hit.Name ~= "HumanoidRootPart" then return end
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid or active[humanoid] == nil then return end
		local original = active[humanoid]
		active[humanoid] = nil
		if humanoid.Parent and humanoid.WalkSpeed <= 28 then humanoid.WalkSpeed = original end
	end)
	return belt
end

local function setupReturnRemote()
	local remotes = ReplicatedStorage:FindFirstChild("MuseumRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "MuseumRemotes"
		remotes.Parent = ReplicatedStorage
	end
	local remote = remotes:FindFirstChild("ReturnToMuseum")
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = "ReturnToMuseum"
		remote.Parent = remotes
	end
	remote.OnServerInvoke = function(player)
		if not world then return false, "Cidade carregando" end
		local museum = world:FindFirstChild("Museum_" .. player.UserId)
		local floor = museum and museum:FindFirstChild("Floor")
		local character = player.Character
		if not floor or not character then return false, "Seu museu ainda está carregando" end
		character:PivotTo(floor.CFrame * CFrame.new(0, 4, floor.Size.Z / 2 + 8))
		return true, "Você voltou ao seu museu"
	end
end

function WorldService:Start()
	if started then return end
	started = true
	local old = Workspace:FindFirstChild("MuseumWorld")
	if old then old:Destroy() end
	world = Instance.new("Folder")
	world.Name = "MuseumWorld"
	world.Parent = Workspace

	part(world, "Ground", Vector3.new(1100, 2, 900), CFrame.new(0,-1,0), Color3.fromRGB(72,106,73), Enum.Material.Grass)
	part(world, "MainRoad", Vector3.new(100, 1, 760), CFrame.new(0,0.05,-20), Color3.fromRGB(43,46,50), Enum.Material.Asphalt)
	part(world, "Plaza", Vector3.new(180, 1, 110), CFrame.new(0,0.1,-340), Color3.fromRGB(175,175,168), Enum.Material.Concrete)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CitySpawn"
	spawn.Size = Vector3.new(12,1,12)
	spawn.CFrame = CFrame.new(0,2,-340)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 0.25
	spawn.Parent = world

	local index = 0
	for _, x in ipairs({-280,-150,150,280}) do
		for _, z in ipairs({-180,70,300}) do
			index += 1
			slots[index] = CFrame.new(x,0,z)
			local pad = part(world, "MuseumPlot" .. index, Vector3.new(118,1,94), CFrame.new(x,0.05,z), Color3.fromRGB(132,126,111), Enum.Material.Concrete)
			pad:SetAttribute("SlotIndex", index)
		end
	end

	local travelators = Instance.new("Folder")
	travelators.Name = "MuseumTravelators"
	travelators.Parent = world
	addTravelator(travelators, "TravelatorRow1", -128)
	addTravelator(travelators, "TravelatorRow2", 122)
	addTravelator(travelators, "TravelatorRow3", 352)

	local mine = Instance.new("Folder")
	mine.Name = "MineNodes"
	mine.Parent = world
	part(mine, "MineGround", Vector3.new(240,2,170), CFrame.new(0,0,390), Color3.fromRGB(78,72,67), Enum.Material.Rock)
	for i, x in ipairs({-55,0,55}) do
		local rock = part(mine, "MineNode" .. i, Vector3.new(24,18,22), CFrame.new(x,9,390), Color3.fromRGB(82,76,72), Enum.Material.Slate)
		rock.Shape = Enum.PartType.Ball
	end

	setupReturnRemote()
	print("[Museum Empire] World generated with museum travelators")
end

function WorldService:GetWorld() return world end
function WorldService:GetSlots() return slots end
function WorldService:GetMineNodes() return world and world:FindFirstChild("MineNodes") end

return WorldService
