local Workspace = game:GetService("Workspace")

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

	local mine = Instance.new("Folder")
	mine.Name = "MineNodes"
	mine.Parent = world
	part(mine, "MineGround", Vector3.new(240,2,170), CFrame.new(0,0,390), Color3.fromRGB(78,72,67), Enum.Material.Rock)
	for i, x in ipairs({-55,0,55}) do
		local rock = part(mine, "MineNode" .. i, Vector3.new(24,18,22), CFrame.new(x,9,390), Color3.fromRGB(82,76,72), Enum.Material.Slate)
		rock.Shape = Enum.PartType.Ball
	end

	print("[Museum Empire] Clean world generated")
end

function WorldService:GetWorld() return world end
function WorldService:GetSlots() return slots end
function WorldService:GetMineNodes()
	return world and world:FindFirstChild("MineNodes")
end

return WorldService
